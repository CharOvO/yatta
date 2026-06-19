package validate

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// 这里的 validate 包是 Yatta 源码树的体检器。它会尽量收集可操作的诊断，
// 让贡献者能一次性修复模块和构建输入问题，再重新运行 yatta build。

var moduleIDPattern = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)

type moduleInfo struct {
	id             string
	name           string
	order          int
	defaultEnabled bool
	requires       []string
	conflicts      []string
	distros        []string
	dirName        string
	path           string
	validMetadata  bool
}

func Run(root string) Report {
	var report Report
	checkProject(root, &report)
	checkRuntime(root, &report)
	checkLocale(root, &report)
	modules := checkModules(root, &report)
	checkRelations(modules, &report)
	return report
}

func checkProject(root string, report *Report) {
	requiredDirs := []string{
		"cmd",
		"internal",
		"runtime",
		"modules",
		"locales",
		"dist",
		filepath.Join("docs", "plan"),
	}
	for _, dir := range requiredDirs {
		path := filepath.Join(root, dir)
		info, err := os.Stat(path)
		if err != nil {
			report.add(Error, "project", slash(dir), "required directory is missing")
			continue
		}
		if !info.IsDir() {
			report.add(Error, "project", slash(dir), "must be a directory")
		}
	}
}

func checkRuntime(root string, report *Report) {
	checkNonEmptyFile(filepath.Join(root, "runtime", "core", "main.sh"), "runtime", "runtime/core/main.sh", report)
}

func checkLocale(root string, report *Report) {
	rel := "locales/zh-CN.json"
	path := filepath.Join(root, rel)
	content, ok := checkReadableFile(path, "locale", rel, report)
	if !ok {
		return
	}
	var value map[string]any
	if err := json.Unmarshal(content, &value); err != nil {
		report.add(Error, "locale", rel, fmt.Sprintf("invalid JSON: %v", err))
		return
	}
	if len(value) == 0 {
		report.add(Error, "locale", rel, "must be a non-empty JSON object")
	}
}

func checkModules(root string, report *Report) []moduleInfo {
	modulesDir := filepath.Join(root, "modules")
	entries, err := os.ReadDir(modulesDir)
	if err != nil {
		return nil
	}

	var modules []moduleInfo
	ids := map[string][]string{}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		dirName := entry.Name()
		modulePath := filepath.Join(modulesDir, dirName)
		relMeta := slash(filepath.Join("modules", dirName, "module.yaml"))
		info := checkModule(root, modulePath, dirName, report)
		if info.validMetadata {
			report.ModuleCount++
			ids[info.id] = append(ids[info.id], relMeta)
			modules = append(modules, info)
		}
	}

	for id, paths := range ids {
		if id == "" || len(paths) < 2 {
			continue
		}
		sort.Strings(paths)
		for _, path := range paths {
			report.add(Error, "modules", path, fmt.Sprintf("duplicate module id %q", id))
		}
	}

	sort.Slice(modules, func(i, j int) bool {
		if modules[i].order != modules[j].order {
			return modules[i].order < modules[j].order
		}
		return modules[i].id < modules[j].id
	})
	return modules
}

func checkModule(root, modulePath, dirName string, report *Report) moduleInfo {
	relDir := slash(filepath.Join("modules", dirName))
	relMeta := slash(filepath.Join(relDir, "module.yaml"))
	info := moduleInfo{dirName: dirName, path: relMeta}

	checkNonEmptyFile(filepath.Join(modulePath, "prompts.sh"), "modules", slash(filepath.Join(relDir, "prompts.sh")), report)
	checkNonEmptyFile(filepath.Join(modulePath, "apply.sh"), "modules", slash(filepath.Join(relDir, "apply.sh")), report)

	content, ok := checkReadableFile(filepath.Join(root, relMeta), "modules", relMeta, report)
	if !ok {
		return info
	}

	var node yaml.Node
	if err := yaml.Unmarshal(content, &node); err != nil {
		report.add(Error, "modules", relMeta, fmt.Sprintf("invalid YAML: %v", err))
		return info
	}
	if len(node.Content) == 0 || node.Content[0].Kind != yaml.MappingNode {
		report.add(Error, "modules", relMeta, "must be a YAML mapping")
		return info
	}

	rootMap := mapping(node.Content[0])
	allowed := map[string]bool{
		"id":              true,
		"name":            true,
		"description":     true,
		"default_enabled": true,
		"order":           true,
		"requires":        true,
		"conflicts":       true,
		"supports":        true,
	}
	for key := range rootMap {
		if !allowed[key] {
			report.add(Warn, "modules", relMeta, fmt.Sprintf("unknown field %q", key))
		}
	}

	info.id = requireString(rootMap, "id", relMeta, report)
	info.name = requireString(rootMap, "name", relMeta, report)
	_ = requireString(rootMap, "description", relMeta, report)
	info.defaultEnabled = requireBool(rootMap, "default_enabled", relMeta, report)
	info.order = requireNonNegativeInt(rootMap, "order", relMeta, report)
	info.requires = requireStringArray(rootMap, "requires", relMeta, report)
	info.conflicts = requireStringArray(rootMap, "conflicts", relMeta, report)
	info.distros = requireDistros(rootMap, relMeta, report)

	if info.id != "" {
		if !moduleIDPattern.MatchString(info.id) {
			report.add(Error, "modules", relMeta, fmt.Sprintf("id %q must use lower-case kebab-case", info.id))
		}
		if info.id != dirName {
			report.add(Error, "modules", relMeta, fmt.Sprintf("id %q must match directory name %q", info.id, dirName))
		}
	}

	info.validMetadata = true
	return info
}

func checkRelations(modules []moduleInfo, report *Report) {
	byID := map[string]moduleInfo{}
	for _, mod := range modules {
		if mod.id == "" {
			continue
		}
		byID[mod.id] = mod
	}

	for _, mod := range modules {
		if mod.id == "" {
			continue
		}
		for _, required := range mod.requires {
			target, ok := byID[required]
			if required == mod.id {
				report.add(Error, "relations", mod.path, fmt.Sprintf("module %q cannot require itself", mod.id))
				continue
			}
			if !ok {
				report.add(Error, "relations", mod.path, fmt.Sprintf("requires missing module %q", required))
				continue
			}
			if mod.defaultEnabled && !target.defaultEnabled {
				report.add(Error, "relations", mod.path, fmt.Sprintf("default-enabled module %q requires disabled module %q", mod.id, required))
			}
		}
		for _, conflict := range mod.conflicts {
			target, ok := byID[conflict]
			if conflict == mod.id {
				report.add(Error, "relations", mod.path, fmt.Sprintf("module %q cannot conflict with itself", mod.id))
				continue
			}
			if !ok {
				report.add(Error, "relations", mod.path, fmt.Sprintf("conflicts with missing module %q", conflict))
				continue
			}
			if mod.defaultEnabled && target.defaultEnabled {
				report.add(Error, "relations", mod.path, fmt.Sprintf("default-enabled module %q conflicts with default-enabled module %q", mod.id, conflict))
			}
		}
	}
}

func checkReadableFile(path, area, rel string, report *Report) ([]byte, bool) {
	info, err := os.Stat(path)
	if err != nil {
		report.add(Error, area, rel, "required file is missing")
		return nil, false
	}
	if info.IsDir() {
		report.add(Error, area, rel, "must be a file")
		return nil, false
	}
	content, err := os.ReadFile(path)
	if err != nil {
		report.add(Error, area, rel, fmt.Sprintf("cannot read file: %v", err))
		return nil, false
	}
	return content, true
}

func checkNonEmptyFile(path, area, rel string, report *Report) {
	content, ok := checkReadableFile(path, area, rel, report)
	if !ok {
		return
	}
	if strings.TrimSpace(string(content)) == "" {
		report.add(Error, area, rel, "must be non-empty")
	}
}

func mapping(node *yaml.Node) map[string]*yaml.Node {
	values := map[string]*yaml.Node{}
	for i := 0; i+1 < len(node.Content); i += 2 {
		values[node.Content[i].Value] = node.Content[i+1]
	}
	return values
}

func requireString(fields map[string]*yaml.Node, key, path string, report *Report) string {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "modules", path, fmt.Sprintf("missing required field: %s", key))
		return ""
	}
	if node.Kind != yaml.ScalarNode || node.Tag != "!!str" || strings.TrimSpace(node.Value) == "" {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be a non-empty string", key))
		return ""
	}
	return node.Value
}

func requireBool(fields map[string]*yaml.Node, key, path string, report *Report) bool {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "modules", path, fmt.Sprintf("missing required field: %s", key))
		return false
	}
	if node.Kind != yaml.ScalarNode || node.Tag != "!!bool" {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be a bool", key))
		return false
	}
	return node.Value == "true"
}

func requireNonNegativeInt(fields map[string]*yaml.Node, key, path string, report *Report) int {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "modules", path, fmt.Sprintf("missing required field: %s", key))
		return 0
	}
	if node.Kind != yaml.ScalarNode || node.Tag != "!!int" {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be a non-negative integer", key))
		return 0
	}
	var value int
	if err := node.Decode(&value); err != nil || value < 0 {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be a non-negative integer", key))
		return 0
	}
	return value
}

func requireStringArray(fields map[string]*yaml.Node, key, path string, report *Report) []string {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "modules", path, fmt.Sprintf("missing required field: %s", key))
		return nil
	}
	if node.Kind != yaml.SequenceNode {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be an array of non-empty strings", key))
		return nil
	}
	seen := map[string]bool{}
	var values []string
	for _, item := range node.Content {
		if item.Kind != yaml.ScalarNode || item.Tag != "!!str" || strings.TrimSpace(item.Value) == "" {
			report.add(Error, "modules", path, fmt.Sprintf("field %s must contain only non-empty strings", key))
			continue
		}
		if seen[item.Value] {
			report.add(Error, "modules", path, fmt.Sprintf("field %s contains duplicate value %q", key, item.Value))
			continue
		}
		seen[item.Value] = true
		values = append(values, item.Value)
	}
	return values
}

func requireDistros(fields map[string]*yaml.Node, path string, report *Report) []string {
	node, ok := fields["supports"]
	if !ok {
		report.add(Error, "modules", path, "missing required field: supports")
		return nil
	}
	if node.Kind != yaml.MappingNode {
		report.add(Error, "modules", path, "field supports must be a mapping")
		return nil
	}
	supports := mapping(node)
	distrosNode, ok := supports["distros"]
	if !ok {
		report.add(Error, "modules", path, "missing required field: supports.distros")
		return nil
	}
	values := requireStringArray(map[string]*yaml.Node{"supports.distros": distrosNode}, "supports.distros", path, report)
	if len(values) != 1 || values[0] != "ubuntu" {
		report.add(Error, "modules", path, "supports.distros must be exactly [ubuntu]")
	}
	return values
}

func (r *Report) add(severity Severity, area, path, message string) {
	r.Diagnostics = append(r.Diagnostics, Diagnostic{
		Severity: severity,
		Area:     area,
		Path:     slash(path),
		Message:  message,
	})
}

func slash(path string) string {
	return filepath.ToSlash(path)
}
