package builder

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"

	"github.com/CharOvO/yatta/internal/locale"
	"github.com/CharOvO/yatta/internal/module"
	"github.com/CharOvO/yatta/internal/validate"
)

// 这里的 builder 包负责把已校验的 Yatta 源文件合成为普通用户运行的
// 单个 Bash 文件。第一阶段聚焦确定性的拼接流程，不提前实现最终交互式 runtime 行为。

type Result struct {
	Path        string
	ModuleCount int
}

func Build(root string) (Result, validate.Report, error) {
	report := validate.Run(root)
	if report.HasErrors() {
		return Result{}, report, nil
	}

	modules, err := module.LoadEnabled(root)
	if err != nil {
		return Result{}, report, err
	}
	if _, err := locale.LoadZhCN(root); err != nil {
		return Result{}, report, err
	}
	runtime, err := os.ReadFile(filepath.Join(root, "runtime", "core", "main.sh"))
	if err != nil {
		return Result{}, report, err
	}

	var out bytes.Buffer
	out.WriteString("#!/usr/bin/env bash\n")
	out.WriteString("# 此文件由 yatta build 生成，请勿手写修改。\n")
	out.WriteString("\n")
	out.WriteString(string(runtime))
	out.WriteString("\n\n")

	for _, mod := range modules {
		if err := writeModuleWrapper(&out, mod, "prompt", mod.PromptsPath); err != nil {
			return Result{}, report, err
		}
		if err := writeModuleWrapper(&out, mod, "apply", mod.ApplyPath); err != nil {
			return Result{}, report, err
		}
	}

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
