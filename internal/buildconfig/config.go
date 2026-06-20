package buildconfig

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"gopkg.in/yaml.v3"
)

// 这里的 buildconfig 包只负责读取和展开根目录构建配置。它不理解模块脚本
// 的具体内容，调用方需要把已发现的模块 ID 传进来，再由这里按 profile
// 的 include/exclude 规则算出本次应该编译进生成脚本的模块集合。

const FileName = "yatta.build.yaml"

type Config struct {
	DefaultProfile string             `yaml:"default_profile"`
	Profiles       map[string]Profile `yaml:"profiles"`
}

type Profile struct {
	Include []string `yaml:"include"`
	Exclude []string `yaml:"exclude"`
}

func Load(root string) (Config, error) {
	path := filepath.Join(root, FileName)
	content, err := os.ReadFile(path)
	if err != nil {
		return Config{}, fmt.Errorf("read %s: %w", FileName, err)
	}
	var config Config
	if err := yaml.Unmarshal(content, &config); err != nil {
		return Config{}, fmt.Errorf("parse %s: %w", FileName, err)
	}
	return config, nil
}

func ResolveDefault(config Config, allIDs []string) ([]string, error) {
	if config.DefaultProfile == "" {
		return nil, fmt.Errorf("default_profile must be set")
	}
	return Resolve(config, config.DefaultProfile, allIDs)
}

func Resolve(config Config, profileName string, allIDs []string) ([]string, error) {
	profile, ok := config.Profiles[profileName]
	if !ok {
		return nil, fmt.Errorf("profile %q is not defined", profileName)
	}
	known := map[string]bool{}
	for _, id := range allIDs {
		known[id] = true
	}

	selected := map[string]bool{}
	for _, id := range profile.Include {
		if id == "*" {
			for _, knownID := range allIDs {
				selected[knownID] = true
			}
			continue
		}
		if !known[id] {
			return nil, fmt.Errorf("profile %q includes missing module %q", profileName, id)
		}
		selected[id] = true
	}
	for _, id := range profile.Exclude {
		if !known[id] {
			return nil, fmt.Errorf("profile %q excludes missing module %q", profileName, id)
		}
		delete(selected, id)
	}

	ids := make([]string, 0, len(selected))
	for id := range selected {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids, nil
}
