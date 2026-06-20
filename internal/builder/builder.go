package builder

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/CharOvO/yatta/internal/buildconfig"
	"github.com/CharOvO/yatta/internal/locale"
	"github.com/CharOvO/yatta/internal/module"
	"github.com/CharOvO/yatta/internal/validate"
	"github.com/CharOvO/yatta/internal/version"
)

// 这里的 builder 包负责把已校验的 Yatta 源文件合成为普通用户运行的
// 单个 Bash 文件。它只处理确定性的源码拼接和模块注册，不把交互流程散落到 Go 代码里。

type Result struct {
	Path        string
	ModuleCount int
}

func Build(root string) (Result, validate.Report, error) {
	report := validate.Run(root)
	if report.HasErrors() {
		return Result{}, report, nil
	}

	allModules, err := module.LoadAll(root)
	if err != nil {
		return Result{}, report, err
	}
	config, err := buildconfig.Load(root)
	if err != nil {
		return Result{}, report, err
	}
	selectedIDs, err := buildconfig.ResolveDefault(config, moduleIDs(allModules))
	if err != nil {
		return Result{}, report, err
	}
	modules, err := module.FilterByIDs(allModules, selectedIDs)
	if err != nil {
		return Result{}, report, err
	}
	if _, err := locale.LoadZhCN(root); err != nil {
		return Result{}, report, err
	}
	versionValue, err := version.Read(root)
	if err != nil {
		return Result{}, report, err
	}
	runtimeFiles, err := loadRuntimeFiles(root)
	if err != nil {
		return Result{}, report, err
	}

	var out bytes.Buffer
	out.WriteString("#!/usr/bin/env bash\n")
	out.WriteString("# 此文件由 yatta build 生成，请勿手写修改。\n")
	fmt.Fprintf(&out, "# Yatta version: %s\n", versionValue)
	fmt.Fprintf(&out, "YATTA_VERSION=%s\n", shellQuote(versionValue))
	out.WriteString("\n")
	for _, path := range runtimeFiles {
		content, err := os.ReadFile(path)
		if err != nil {
			return Result{}, report, err
		}
		fmt.Fprintf(&out, "# ===== %s =====\n", displayPath(root, path))
		out.Write(content)
		if len(content) == 0 || content[len(content)-1] != '\n' {
			out.WriteByte('\n')
		}
		out.WriteByte('\n')
	}

	for _, mod := range modules {
		if err := writeModuleWrapper(&out, mod, "prompt", mod.PromptsPath); err != nil {
			return Result{}, report, err
		}
		if err := writeOptionalModuleWrapper(&out, mod, "pre_apply", mod.PreApplyPath); err != nil {
			return Result{}, report, err
		}
		if err := writeModuleWrapper(&out, mod, "apply", mod.ApplyPath); err != nil {
			return Result{}, report, err
		}
		if err := writeOptionalModuleWrapper(&out, mod, "post_apply", mod.PostApplyPath); err != nil {
			return Result{}, report, err
		}
	}
	writeModuleRegistry(&out, modules)
	out.WriteString("yatta_main \"$@\"\n")

	distDir := filepath.Join(root, "dist")
	if err := os.MkdirAll(distDir, 0o755); err != nil {
		return Result{}, report, err
	}
	outputPath := filepath.Join(distDir, "yatta.sh")
	if err := os.WriteFile(outputPath, out.Bytes(), 0o755); err != nil {
		return Result{}, report, err
	}
	return Result{Path: outputPath, ModuleCount: len(modules)}, report, nil
}

func displayPath(root, path string) string {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return filepath.ToSlash(path)
	}
	return filepath.ToSlash(rel)
}

func loadRuntimeFiles(root string) ([]string, error) {
	runtimeRoot := filepath.Join(root, "runtime")
	var files []string
	groups := []struct {
		dir      string
		mainLast bool
	}{
		{dir: filepath.Join(runtimeRoot, "core"), mainLast: true},
		{dir: filepath.Join(runtimeRoot, "ui")},
		{dir: filepath.Join(runtimeRoot, "system")},
		{dir: filepath.Join(runtimeRoot, "adapter")},
	}
	for _, group := range groups {
		groupFiles, err := runtimeShellFiles(group.dir)
		if err != nil {
			return nil, err
		}
		if group.mainLast {
			var deferred []string
			kept := groupFiles[:0]
			for _, path := range groupFiles {
				if filepath.Base(path) == "main.sh" {
					deferred = append(deferred, path)
					continue
				}
				kept = append(kept, path)
			}
			groupFiles = append(kept, deferred...)
		}
		files = append(files, groupFiles...)
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("runtime must contain at least one .sh file")
	}
	return files, nil
}

func runtimeShellFiles(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read runtime directory %s: %w", filepath.ToSlash(dir), err)
	}
	var files []string
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".sh" {
			continue
		}
		files = append(files, filepath.Join(dir, entry.Name()))
	}
	sort.Strings(files)
	return files, nil
}

func writeModuleWrapper(out *bytes.Buffer, mod module.Module, phase, path string) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "yatta_module_%s_%s() {\n", module.FunctionID(mod.Metadata.ID), phase)
	out.Write(content)
	if len(content) == 0 || content[len(content)-1] != '\n' {
		out.WriteByte('\n')
	}
	out.WriteString("}\n\n")
	return nil
}

func writeOptionalModuleWrapper(out *bytes.Buffer, mod module.Module, phase, path string) error {
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintf(out, "yatta_module_%s_%s() {\n", module.FunctionID(mod.Metadata.ID), phase)
			out.WriteString("  return 0\n")
			out.WriteString("}\n\n")
			return nil
		}
		return err
	}
	return writeModuleWrapper(out, mod, phase, path)
}

func writeModuleRegistry(out *bytes.Buffer, modules []module.Module) {
	out.WriteString("yatta_register_generated_modules() {\n")
	for _, mod := range modules {
		fnID := module.FunctionID(mod.Metadata.ID)
		fmt.Fprintf(
			out,
			"  yatta_module_register %s %s %s %s %s %s %s %s %s %s %s\n",
			shellQuote(mod.Metadata.ID),
			shellQuote(mod.Metadata.Name),
			shellQuote(module.StageName(mod.Metadata)),
			shellQuote(mod.Metadata.Group),
			shellQuote(mod.Metadata.Risk),
			shellBool(mod.Metadata.RuntimeDefault),
			shellBool(mod.Metadata.Locked),
			shellQuote("yatta_module_"+fnID+"_prompt"),
			shellQuote("yatta_module_"+fnID+"_pre_apply"),
			shellQuote("yatta_module_"+fnID+"_apply"),
			shellQuote("yatta_module_"+fnID+"_post_apply"),
		)
	}
	out.WriteString("}\n\n")
}

func moduleIDs(modules []module.Module) []string {
	ids := make([]string, 0, len(modules))
	for _, mod := range modules {
		ids = append(ids, mod.Metadata.ID)
	}
	sort.Strings(ids)
	return ids
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func shellBool(value bool) string {
	if value {
		return "true"
	}
	return "false"
}
