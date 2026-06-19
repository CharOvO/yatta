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
	Order          int      `yaml:"order"`
	Requires       []string `yaml:"requires"`
	Conflicts      []string `yaml:"conflicts"`
	Supports       Supports `yaml:"supports"`
}

type Module struct {
	Dir          string
	PromptsPath  string
	ApplyPath    string
	MetadataPath string
	Metadata     Metadata
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
			Dir:          dir,
			PromptsPath:  filepath.Join(dir, "prompts.sh"),
			ApplyPath:    filepath.Join(dir, "apply.sh"),
			MetadataPath: metaPath,
			Metadata:     meta,
		})
	}

	Sort(modules)
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

func Sort(modules []Module) {
	sort.Slice(modules, func(i, j int) bool {
		if modules[i].Metadata.Order != modules[j].Metadata.Order {
			return modules[i].Metadata.Order < modules[j].Metadata.Order
		}
		return modules[i].Metadata.ID < modules[j].Metadata.ID
	})
}

func FunctionID(id string) string {
	return strings.ReplaceAll(id, "-", "_")
}
