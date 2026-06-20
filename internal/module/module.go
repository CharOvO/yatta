package module

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// 这里的 module 包负责提供 Yatta 模块元数据的只读视图。完整校验位于
// 校验包 internal/validate；本包只负责读取、解析和排序，并把读取失败直接返回给调用方。

type Supports struct {
	Distros []string `yaml:"distros"`
}

type Metadata struct {
	ID             string   `yaml:"id"`
	Name           string   `yaml:"name"`
	Description    string   `yaml:"description"`
	DefaultEnabled bool     `yaml:"default_enabled"`
	RuntimeDefault bool     `yaml:"runtime_default"`
	Risk           string   `yaml:"risk"`
	Group          string   `yaml:"group"`
	Locked         bool     `yaml:"locked"`
	Stage          string   `yaml:"stage"`
	Order          int      `yaml:"order"`
	Requires       []string `yaml:"requires"`
	Before         []string `yaml:"before"`
	After          []string `yaml:"after"`
	Conflicts      []string `yaml:"conflicts"`
	Supports       Supports `yaml:"supports"`
}

type Module struct {
	Dir           string
	PromptsPath   string
	PreApplyPath  string
	ApplyPath     string
	PostApplyPath string
	MetadataPath  string
	Metadata      Metadata
}

func LoadAll(root string) ([]Module, error) {
	modulesDir := filepath.Join(root, "modules")
	entries, err := os.ReadDir(modulesDir)
	if err != nil {
		return nil, fmt.Errorf("read modules directory: %w", err)
	}

	var modules []Module
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		dir := filepath.Join(modulesDir, entry.Name())
		metaPath := filepath.Join(dir, "module.yaml")
		meta, err := LoadMetadata(metaPath)
		if err != nil {
			return nil, err
		}
		modules = append(modules, Module{
			Dir:           dir,
			PromptsPath:   filepath.Join(dir, "prompts.sh"),
			PreApplyPath:  filepath.Join(dir, "pre_apply.sh"),
			ApplyPath:     filepath.Join(dir, "apply.sh"),
			PostApplyPath: filepath.Join(dir, "post_apply.sh"),
			MetadataPath:  metaPath,
			Metadata:      meta,
		})
	}

	if err := Sort(modules); err != nil {
		return nil, err
	}
	return modules, nil
}

func LoadEnabled(root string) ([]Module, error) {
	modules, err := LoadAll(root)
	if err != nil {
		return nil, err
	}
	enabled := modules[:0]
	for _, mod := range modules {
		if mod.Metadata.DefaultEnabled {
			enabled = append(enabled, mod)
		}
	}
	return enabled, nil
}

func FilterByIDs(modules []Module, ids []string) ([]Module, error) {
	selected := map[string]bool{}
	for _, id := range ids {
		selected[id] = true
	}
	var filtered []Module
	for _, mod := range modules {
		if selected[mod.Metadata.ID] {
			filtered = append(filtered, mod)
			delete(selected, mod.Metadata.ID)
		}
	}
	if len(selected) > 0 {
		var missing []string
		for id := range selected {
			missing = append(missing, id)
		}
		sort.Strings(missing)
		return nil, fmt.Errorf("selected modules are missing: %s", strings.Join(missing, ", "))
	}
	return filtered, nil
}

func LoadMetadata(path string) (Metadata, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return Metadata{}, fmt.Errorf("read %s: %w", filepath.ToSlash(path), err)
	}
	var meta Metadata
	if err := yaml.Unmarshal(content, &meta); err != nil {
		return Metadata{}, fmt.Errorf("parse %s: %w", filepath.ToSlash(path), err)
	}
	return meta, nil
}

func Sort(modules []Module) error {
	ordered, err := OrderedIDs(metadataSlice(modules))
	if err != nil {
		return err
	}
	positions := map[string]int{}
	for index, id := range ordered {
		positions[id] = index
	}
	sort.SliceStable(modules, func(i, j int) bool {
		return positions[modules[i].Metadata.ID] < positions[modules[j].Metadata.ID]
	})
	return nil
}

func FunctionID(id string) string {
	return strings.ReplaceAll(id, "-", "_")
}

func metadataSlice(modules []Module) []Metadata {
	values := make([]Metadata, 0, len(modules))
	for _, mod := range modules {
		values = append(values, mod.Metadata)
	}
	return values
}

var stageRanks = map[string]int{
	"preflight":     0,
	"system":        1,
	"account":       2,
	"packages":      3,
	"remote-access": 4,
	"services":      5,
	"security":      6,
	"firewall":      7,
	"post":          8,
}

func KnownStages() []string {
	return []string{"preflight", "system", "account", "packages", "remote-access", "services", "security", "firewall", "post"}
}

func StageRank(meta Metadata) int {
	if rank, ok := stageRanks[meta.Stage]; ok {
		return rank
	}
	return stageRankFromOrder(meta.Order)
}

func stageRankFromOrder(order int) int {
	switch {
	case order < 100:
		return stageRanks["preflight"]
	case order < 200:
		return stageRanks["system"]
	case order < 300:
		return stageRanks["packages"]
	case order < 600:
		return stageRanks["services"]
	case order < 800:
		return stageRanks["remote-access"]
	case order < 900:
		return stageRanks["security"]
	default:
		return stageRanks["firewall"]
	}
}

func StageName(meta Metadata) string {
	if meta.Stage != "" {
		return meta.Stage
	}
	for name, rank := range stageRanks {
		if rank == StageRank(meta) {
			return name
		}
	}
	return "unknown"
}

func ValidStage(stage string) bool {
	_, ok := stageRanks[stage]
	return ok
}

func OrderedIDs(modules []Metadata) ([]string, error) {
	byID := map[string]Metadata{}
	for _, meta := range modules {
		byID[meta.ID] = meta
	}

	graph := map[string]map[string]bool{}
	indegree := map[string]int{}
	for _, meta := range modules {
		graph[meta.ID] = map[string]bool{}
		indegree[meta.ID] = 0
	}
	addEdge := func(from, to string) {
		if from == "" || to == "" || from == to {
			return
		}
		if _, ok := byID[from]; !ok {
			return
		}
		if _, ok := byID[to]; !ok {
			return
		}
		if graph[from][to] {
			return
		}
		graph[from][to] = true
		indegree[to]++
	}

	for _, left := range modules {
		for _, right := range modules {
			if StageRank(left) < StageRank(right) {
				addEdge(left.ID, right.ID)
			}
		}
		for _, required := range left.Requires {
			addEdge(required, left.ID)
		}
		for _, after := range left.After {
			addEdge(after, left.ID)
		}
		for _, before := range left.Before {
			addEdge(left.ID, before)
		}
	}

	ready := make([]Metadata, 0, len(modules))
	for _, meta := range modules {
		if indegree[meta.ID] == 0 {
			ready = append(ready, meta)
		}
	}
	sortMetadata(ready)

	var ordered []string
	for len(ready) > 0 {
		current := ready[0]
		ready = ready[1:]
		ordered = append(ordered, current.ID)
		var next []Metadata
		for target := range graph[current.ID] {
			indegree[target]--
			if indegree[target] == 0 {
				next = append(next, byID[target])
			}
		}
		ready = append(ready, next...)
		sortMetadata(ready)
	}
	if len(ordered) != len(modules) {
		return nil, fmt.Errorf("module ordering contains a cycle")
	}
	return ordered, nil
}

func sortMetadata(values []Metadata) {
	sort.Slice(values, func(i, j int) bool {
		left := values[i]
		right := values[j]
		if StageRank(left) != StageRank(right) {
			return StageRank(left) < StageRank(right)
		}
		if left.Order != right.Order {
			return left.Order < right.Order
		}
		return left.ID < right.ID
	})
}
