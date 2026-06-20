package builder

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildGeneratesScript(t *testing.T) {
	root := copyFixture(t, filepath.Join("..", "validate", "testdata", "valid"))
	result, report, err := Build(root)
	if err != nil {
		t.Fatalf("Build returned error: %v", err)
	}
	if report.HasErrors() {
		t.Fatalf("expected valid fixture, got diagnostics")
	}
	content, err := os.ReadFile(result.Path)
	if err != nil {
		t.Fatalf("读取生成脚本失败: %v", err)
	}
	text := string(content)
	for _, want := range []string{
		"#!/usr/bin/env bash\n",
		"此文件由 yatta build 生成，请勿手写修改。",
		"# Yatta version: 9.9.9-test",
		"YATTA_VERSION='9.9.9-test'",
		"fixture_runtime_prelude()",
		"fixture runtime",
		"fixture_runtime_ui()",
		"fixture_runtime_system()",
		"fixture_runtime_adapter()",
		"yatta_module_alpha_prompt()",
		"yatta_module_alpha_pre_apply()",
		"yatta_module_alpha_apply()",
		"yatta_module_alpha_post_apply()",
		"yatta_module_beta_prompt()",
		"yatta_register_generated_modules()",
		"yatta_module_register 'alpha' 'Alpha' 'system' 'fixture' 'low' true false 'yatta_module_alpha_prompt' 'yatta_module_alpha_pre_apply' 'yatta_module_alpha_apply' 'yatta_module_alpha_post_apply'",
		"yatta_module_register 'beta' 'Beta' 'system' 'fixture' 'medium' false false 'yatta_module_beta_prompt' 'yatta_module_beta_pre_apply' 'yatta_module_beta_apply' 'yatta_module_beta_post_apply'",
		"yatta_main \"$@\"",
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("生成脚本缺少 %q:\n%s", want, text)
		}
	}
	if strings.Index(text, "fixture_runtime_prelude()") > strings.Index(text, "fixture runtime") {
		t.Fatalf("runtime core 前置文件应先于 main.sh 拼接:\n%s", text)
	}
}

func copyFixture(t *testing.T, src string) string {
	t.Helper()
	dst := t.TempDir()
	copyDir(t, src, dst)
	return dst
}

func copyDir(t *testing.T, src, dst string) {
	t.Helper()
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", dst, err)
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		t.Fatalf("read dir %s: %v", src, err)
	}
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		if entry.IsDir() {
			copyDir(t, srcPath, dstPath)
			continue
		}
		content, err := os.ReadFile(srcPath)
		if err != nil {
			t.Fatalf("read %s: %v", srcPath, err)
		}
		if err := os.WriteFile(dstPath, content, 0o644); err != nil {
			t.Fatalf("write %s: %v", dstPath, err)
		}
	}
}
