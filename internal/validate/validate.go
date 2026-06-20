package validate

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/CharOvO/yatta/internal/buildconfig"
	"github.com/CharOvO/yatta/internal/module"
	"github.com/CharOvO/yatta/internal/version"
	"gopkg.in/yaml.v3"
)

// 这里的 validate 包是 Yatta 源码树的体检器。它会尽量收集可操作的诊断，
// 让贡献者能一次性修复模块和构建输入问题，再重新运行 yatta build。

var moduleIDPattern = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)

type moduleInfo struct {
	id             string
	name           string
	stage          string
	order          int
	defaultEnabled bool
	runtimeDefault bool
	risk           string
	group          string
	locked         bool
	requires       []string
	before         []string
	after          []string
	conflicts      []string
	distros        []string
	dirName        string
	path           string
	validMetadata  bool
}

func Run(root string) Report {
	var report Report
	checkProject(root, &report)
	checkVersion(root, &report)
	checkRuntime(root, &report)
	checkLocale(root, &report)
	modules := checkModules(root, &report)
	checkRelations(modules, &report)
	checkBuildConfig(root, modules, &report)
	return report
}

func checkVersion(root string, report *Report) {
	if _, err := version.Read(root); err != nil {
		report.add(Error, "version", "VERSION", err.Error())
	}
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
	requiredDirs := []string{
		filepath.Join("runtime", "core"),
		filepath.Join("runtime", "ui"),
		filepath.Join("runtime", "system"),
		filepath.Join("runtime", "adapter"),
	}
	for _, dir := range requiredDirs {
		path := filepath.Join(root, dir)
		info, err := os.Stat(path)
		if err != nil {
			report.add(Error, "runtime", slash(dir), "required directory is missing")
			continue
		}
		if !info.IsDir() {
			report.add(Error, "runtime", slash(dir), "must be a directory")
		}
	}
	checkNonEmptyFile(filepath.Join(root, "runtime", "core", "main.sh"), "runtime", "runtime/core/main.sh", report)
	checkRuntimeShellFiles(root, report)
}

func checkRuntimeShellFiles(root string, report *Report) {
	runtimeRoot := filepath.Join(root, "runtime")
	_ = filepath.WalkDir(runtimeRoot, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".sh" {
			return nil
		}
		rel, relErr := filepath.Rel(root, path)
		if relErr != nil {
			rel = path
		}
		checkNonEmptyFile(path, "runtime", slash(rel), report)
		return nil
	})
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
	checkOptionalNonEmptyFile(filepath.Join(modulePath, "pre_apply.sh"), "modules", slash(filepath.Join(relDir, "pre_apply.sh")), report)
	checkNonEmptyFile(filepath.Join(modulePath, "apply.sh"), "modules", slash(filepath.Join(relDir, "apply.sh")), report)
	checkOptionalNonEmptyFile(filepath.Join(modulePath, "post_apply.sh"), "modules", slash(filepath.Join(relDir, "post_apply.sh")), report)

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
		"runtime_default": true,
		"risk":            true,
		"group":           true,
		"locked":          true,
		"stage":           true,
		"order":           true,
		"requires":        true,
		"before":          true,
		"after":           true,
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
	info.defaultEnabled = optionalBool(rootMap, "default_enabled", relMeta, report)
	info.runtimeDefault = requireBool(rootMap, "runtime_default", relMeta, report)
	info.risk = requireRisk(rootMap, relMeta, report)
	info.group = requireString(rootMap, "group", relMeta, report)
	info.locked = optionalBool(rootMap, "locked", relMeta, report)
	info.stage = optionalStage(rootMap, "stage", relMeta, report)
	info.order = optionalNonNegativeInt(rootMap, "order", relMeta, report)
	if info.stage == "" {
		if _, ok := rootMap["order"]; !ok {
			report.add(Error, "modules", relMeta, "must define stage or legacy order")
		}
	}
	info.requires = requireStringArray(rootMap, "requires", relMeta, report)
	info.before = optionalStringArray(rootMap, "before", relMeta, report)
	info.after = optionalStringArray(rootMap, "after", relMeta, report)
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
			_, ok := byID[required]
			if required == mod.id {
				report.add(Error, "relations", mod.path, fmt.Sprintf("module %q cannot require itself", mod.id))
				continue
			}
			if !ok {
				report.add(Error, "relations", mod.path, fmt.Sprintf("requires missing module %q", required))
				continue
			}
		}
		for _, conflict := range mod.conflicts {
			_, ok := byID[conflict]
			if conflict == mod.id {
				report.add(Error, "relations", mod.path, fmt.Sprintf("module %q cannot conflict with itself", mod.id))
				continue
			}
			if !ok {
				report.add(Error, "relations", mod.path, fmt.Sprintf("conflicts with missing module %q", conflict))
				continue
			}
		}
		checkOrderingTargets(mod, "before", mod.before, byID, report)
		checkOrderingTargets(mod, "after", mod.after, byID, report)
	}

	if _, err := module.OrderedIDs(toMetadata(modules)); err != nil {
		report.add(Error, "relations", "modules", err.Error())
	}
}

func checkOrderingTargets(mod moduleInfo, field string, values []string, byID map[string]moduleInfo, report *Report) {
	for _, targetID := range values {
		if targetID == mod.id {
			report.add(Error, "relations", mod.path, fmt.Sprintf("module %q cannot reference itself in %s", mod.id, field))
			continue
		}
		if _, ok := byID[targetID]; !ok {
			report.add(Error, "relations", mod.path, fmt.Sprintf("%s references missing module %q", field, targetID))
		}
	}
}

func checkBuildConfig(root string, modules []moduleInfo, report *Report) {
	rel := buildconfig.FileName
	content, ok := checkReadableFile(filepath.Join(root, rel), "build", rel, report)
	if !ok {
		return
	}

	var node yaml.Node
	if err := yaml.Unmarshal(content, &node); err != nil {
		report.add(Error, "build", rel, fmt.Sprintf("invalid YAML: %v", err))
		return
	}
	if len(node.Content) == 0 || node.Content[0].Kind != yaml.MappingNode {
		report.add(Error, "build", rel, "must be a YAML mapping")
		return
	}
	rootMap := mapping(node.Content[0])
	for key := range rootMap {
		if key != "default_profile" && key != "profiles" {
			report.add(Warn, "build", rel, fmt.Sprintf("unknown field %q", key))
		}
	}

	defaultProfile := requireBuildString(rootMap, "default_profile", rel, report)
	profilesNode, ok := rootMap["profiles"]
	if !ok {
		report.add(Error, "build", rel, "missing required field: profiles")
		return
	}
	if profilesNode.Kind != yaml.MappingNode {
		report.add(Error, "build", rel, "field profiles must be a mapping")
		return
	}
	profileNames := map[string]bool{}
	for i := 0; i+1 < len(profilesNode.Content); i += 2 {
		nameNode := profilesNode.Content[i]
		profileNode := profilesNode.Content[i+1]
		if nameNode.Kind != yaml.ScalarNode || nameNode.Tag != "!!str" || strings.TrimSpace(nameNode.Value) == "" {
			report.add(Error, "build", rel, "profile names must be non-empty strings")
			continue
		}
		name := nameNode.Value
		if profileNames[name] {
			report.add(Error, "build", rel, fmt.Sprintf("duplicate profile %q", name))
			continue
		}
		profileNames[name] = true
		checkProfileNode(name, profileNode, rel, report)
	}
	if defaultProfile != "" && !profileNames[defaultProfile] {
		report.add(Error, "build", rel, fmt.Sprintf("default_profile %q is not defined", defaultProfile))
	}

	config, err := buildconfig.Load(root)
	if err != nil {
		report.add(Error, "build", rel, err.Error())
		return
	}
	allIDs := moduleIDs(modules)
	for profileName := range config.Profiles {
		selectedIDs, err := buildconfig.Resolve(config, profileName, allIDs)
		if err != nil {
			report.add(Error, "build", rel, err.Error())
			continue
		}
		checkProfileRelations(profileName, selectedIDs, modules, report)
	}
}

func checkProfileNode(name string, node *yaml.Node, path string, report *Report) {
	if node.Kind != yaml.MappingNode {
		report.add(Error, "build", path, fmt.Sprintf("profile %q must be a mapping", name))
		return
	}
	fields := mapping(node)
	for key := range fields {
		if key != "include" && key != "exclude" {
			report.add(Warn, "build", path, fmt.Sprintf("profile %q has unknown field %q", name, key))
		}
	}
	if _, ok := fields["include"]; !ok {
		report.add(Error, "build", path, fmt.Sprintf("profile %q missing required field: include", name))
	} else {
		_ = requireBuildStringArray(fields, "include", path, report)
	}
	if _, ok := fields["exclude"]; ok {
		_ = requireBuildStringArray(fields, "exclude", path, report)
	}
}

func checkProfileRelations(profileName string, selectedIDs []string, modules []moduleInfo, report *Report) {
	byID := map[string]moduleInfo{}
	for _, mod := range modules {
		byID[mod.id] = mod
	}
	selected := map[string]bool{}
	var selectedMetadata []module.Metadata
	for _, id := range selectedIDs {
		selected[id] = true
		mod := byID[id]
		selectedMetadata = append(selectedMetadata, module.Metadata{
			ID:        mod.id,
			Stage:     mod.stage,
			Order:     mod.order,
			Requires:  mod.requires,
			Before:    mod.before,
			After:     mod.after,
			Conflicts: mod.conflicts,
		})
	}
	for _, mod := range selectedMetadata {
		for _, required := range mod.Requires {
			if !selected[required] {
				report.add(Error, "build", buildconfig.FileName, fmt.Sprintf("profile %q selects module %q but misses required module %q", profileName, mod.ID, required))
			}
		}
		for _, before := range mod.Before {
			if !selected[before] {
				report.add(Error, "build", buildconfig.FileName, fmt.Sprintf("profile %q selects module %q but misses before target %q", profileName, mod.ID, before))
			}
		}
		for _, after := range mod.After {
			if !selected[after] {
				report.add(Error, "build", buildconfig.FileName, fmt.Sprintf("profile %q selects module %q but misses after target %q", profileName, mod.ID, after))
			}
		}
		for _, conflict := range mod.Conflicts {
			if selected[conflict] {
				report.add(Error, "build", buildconfig.FileName, fmt.Sprintf("profile %q selects conflicting modules %q and %q", profileName, mod.ID, conflict))
			}
		}
	}
	if _, err := module.OrderedIDs(selectedMetadata); err != nil {
		report.add(Error, "build", buildconfig.FileName, fmt.Sprintf("profile %q: %v", profileName, err))
	}
}

func moduleIDs(modules []moduleInfo) []string {
	ids := make([]string, 0, len(modules))
	for _, mod := range modules {
		ids = append(ids, mod.id)
	}
	sort.Strings(ids)
	return ids
}

func toMetadata(modules []moduleInfo) []module.Metadata {
	values := make([]module.Metadata, 0, len(modules))
	for _, mod := range modules {
		values = append(values, module.Metadata{
			ID:       mod.id,
			Stage:    mod.stage,
			Order:    mod.order,
			Requires: mod.requires,
			Before:   mod.before,
			After:    mod.after,
		})
	}
	return values
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

func checkOptionalNonEmptyFile(path, area, rel string, report *Report) {
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return
		}
		report.add(Error, area, rel, fmt.Sprintf("cannot inspect file: %v", err))
		return
	}
	checkNonEmptyFile(path, area, rel, report)
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

func optionalBool(fields map[string]*yaml.Node, key, path string, report *Report) bool {
	if _, ok := fields[key]; !ok {
		return false
	}
	return requireBool(fields, key, path, report)
}

func requireRisk(fields map[string]*yaml.Node, path string, report *Report) string {
	value := requireString(fields, "risk", path, report)
	switch value {
	case "low", "medium", "high":
		return value
	case "":
		return ""
	default:
		report.add(Error, "modules", path, fmt.Sprintf("field risk has unknown value %q", value))
		return value
	}
}

func requireBuildString(fields map[string]*yaml.Node, key, path string, report *Report) string {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "build", path, fmt.Sprintf("missing required field: %s", key))
		return ""
	}
	if node.Kind != yaml.ScalarNode || node.Tag != "!!str" || strings.TrimSpace(node.Value) == "" {
		report.add(Error, "build", path, fmt.Sprintf("field %s must be a non-empty string", key))
		return ""
	}
	return node.Value
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

func optionalNonNegativeInt(fields map[string]*yaml.Node, key, path string, report *Report) int {
	if _, ok := fields[key]; !ok {
		return 0
	}
	return requireNonNegativeInt(fields, key, path, report)
}

func optionalStage(fields map[string]*yaml.Node, key, path string, report *Report) string {
	node, ok := fields[key]
	if !ok {
		return ""
	}
	if node.Kind != yaml.ScalarNode || node.Tag != "!!str" || strings.TrimSpace(node.Value) == "" {
		report.add(Error, "modules", path, fmt.Sprintf("field %s must be a known stage string", key))
		return ""
	}
	if !module.ValidStage(node.Value) {
		report.add(Error, "modules", path, fmt.Sprintf("field %s has unknown stage %q", key, node.Value))
	}
	return node.Value
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

func requireBuildStringArray(fields map[string]*yaml.Node, key, path string, report *Report) []string {
	node, ok := fields[key]
	if !ok {
		report.add(Error, "build", path, fmt.Sprintf("missing required field: %s", key))
		return nil
	}
	if node.Kind != yaml.SequenceNode {
		report.add(Error, "build", path, fmt.Sprintf("field %s must be an array of non-empty strings", key))
		return nil
	}
	seen := map[string]bool{}
	var values []string
	for _, item := range node.Content {
		if item.Kind != yaml.ScalarNode || item.Tag != "!!str" || strings.TrimSpace(item.Value) == "" {
			report.add(Error, "build", path, fmt.Sprintf("field %s must contain only non-empty strings", key))
			continue
		}
		if item.Value == "*" && key != "include" {
			report.add(Error, "build", path, "wildcard * is only allowed in include")
			continue
		}
		if seen[item.Value] {
			report.add(Error, "build", path, fmt.Sprintf("field %s contains duplicate value %q", key, item.Value))
			continue
		}
		seen[item.Value] = true
		values = append(values, item.Value)
	}
	return values
}

func optionalStringArray(fields map[string]*yaml.Node, key, path string, report *Report) []string {
	if _, ok := fields[key]; !ok {
		return nil
	}
	return requireStringArray(fields, key, path, report)
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
