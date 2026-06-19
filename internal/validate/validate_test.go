package validate

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunValidProject(t *testing.T) {
	report := Run(filepath.Join("testdata", "valid"))
	if report.HasErrors() {
		t.Fatalf("expected valid fixture, got diagnostics:\n%s", diagnosticsText(report))
	}
	if report.ModuleCount != 2 {
		t.Fatalf("expected 2 modules, got %d", report.ModuleCount)
	}
}

func TestRunWarnsOnUnknownField(t *testing.T) {
	root := copyValidFixture(t)
	appendFile(t, root, "modules/alpha/module.yaml", "\nfuture_field: kept-for-later\n")

	report := Run(root)
	if report.HasErrors() {
		t.Fatalf("expected warning-only report, got diagnostics:\n%s", diagnosticsText(report))
	}
	if report.WarningCount() != 1 {
		t.Fatalf("expected 1 warning, got %d:\n%s", report.WarningCount(), diagnosticsText(report))
	}
	assertDiagnosticsContain(t, report, "WARN modules/alpha/module.yaml: unknown field")
}

func TestRunValidationErrors(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(t *testing.T, root string)
		want   string
	}{
		{
			name: "missing required field",
			mutate: func(t *testing.T, root string) {
				writeFile(t, root, "modules/alpha/module.yaml", baseModuleYAML("alpha", "Alpha", "", "true", "20", "[]", "[]", "[ubuntu]"))
			},
			want: "missing required field: description",
		},
		{
			name: "field type error",
			mutate: func(t *testing.T, root string) {
				writeFile(t, root, "modules/alpha/module.yaml", baseModuleYAML("alpha", "Alpha", "Alpha fixture module", `"true"`, "20", "[]", "[]", "[ubuntu]"))
			},
			want: "field default_enabled must be a bool",
		},
		{
			name: "invalid id",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "id: alpha", "id: Bad_ID")
			},
			want: "must use lower-case kebab-case",
		},
		{
			name: "directory mismatch",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "id: alpha", "id: other")
			},
			want: `must match directory name "alpha"`,
		},
		{
			name: "duplicate id",
			mutate: func(t *testing.T, root string) {
				copyDir(t, filepath.Join(root, "modules", "alpha"), filepath.Join(root, "modules", "dupe"))
			},
			want: `duplicate module id "alpha"`,
		},
		{
			name: "missing module yaml",
			mutate: func(t *testing.T, root string) {
				removeFile(t, root, "modules/alpha/module.yaml")
			},
			want: "required file is missing",
		},
		{
			name: "missing prompt script",
			mutate: func(t *testing.T, root string) {
				removeFile(t, root, "modules/alpha/prompts.sh")
			},
			want: "modules/alpha/prompts.sh: required file is missing",
		},
		{
			name: "empty apply script",
			mutate: func(t *testing.T, root string) {
				writeFile(t, root, "modules/alpha/apply.sh", "   \n")
			},
			want: "modules/alpha/apply.sh: must be non-empty",
		},
		{
			name: "missing dependency",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "requires: []", "requires: [ghost]")
			},
			want: `requires missing module "ghost"`,
		},
		{
			name: "self dependency",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "requires: []", "requires: [alpha]")
			},
			want: `module "alpha" cannot require itself`,
		},
		{
			name: "enabled depends on disabled",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "requires: []", "requires: [beta]")
			},
			want: `default-enabled module "alpha" requires disabled module "beta"`,
		},
		{
			name: "missing conflict",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "conflicts: []", "conflicts: [ghost]")
			},
			want: `conflicts with missing module "ghost"`,
		},
		{
			name: "self conflict",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "conflicts: []", "conflicts: [alpha]")
			},
			want: `module "alpha" cannot conflict with itself`,
		},
		{
			name: "default conflict",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/beta/module.yaml", "default_enabled: false", "default_enabled: true")
				replaceFile(t, root, "modules/alpha/module.yaml", "conflicts: []", "conflicts: [beta]")
			},
			want: `default-enabled module "alpha" conflicts with default-enabled module "beta"`,
		},
		{
			name: "invalid distro",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "distros: [ubuntu]", "distros: [debian]")
			},
			want: "supports.distros must be exactly [ubuntu]",
		},
		{
			name: "duplicate array value",
			mutate: func(t *testing.T, root string) {
				replaceFile(t, root, "modules/alpha/module.yaml", "requires: []", "requires: [beta, beta]")
			},
			want: `field requires contains duplicate value "beta"`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			root := copyValidFixture(t)
			tt.mutate(t, root)
			report := Run(root)
			if !report.HasErrors() {
				t.Fatalf("expected errors, got none")
			}
			assertDiagnosticsContain(t, report, tt.want)
		})
	}
}

func copyValidFixture(t *testing.T) string {
	t.Helper()
	dst := t.TempDir()
	copyDir(t, filepath.Join("testdata", "valid"), dst)
	return dst
}

func diagnosticsText(report Report) string {
	var b strings.Builder
	report.WriteDiagnostics(&b)
	return b.String()
}

func assertDiagnosticsContain(t *testing.T, report Report, want string) {
	t.Helper()
	text := diagnosticsText(report)
	if !strings.Contains(text, want) {
		t.Fatalf("diagnostics did not contain %q:\n%s", want, text)
	}
}

func baseModuleYAML(id, name, description, enabled, order, requires, conflicts, distros string) string {
	var b strings.Builder
	b.WriteString("id: " + id + "\n")
	b.WriteString("name: " + name + "\n")
	if description != "" {
		b.WriteString("description: " + description + "\n")
	}
	b.WriteString("default_enabled: " + enabled + "\n")
	b.WriteString("order: " + order + "\n")
	b.WriteString("requires: " + requires + "\n")
	b.WriteString("conflicts: " + conflicts + "\n")
	b.WriteString("supports:\n")
	b.WriteString("  distros: " + distros + "\n")
	return b.String()
}

func appendFile(t *testing.T, root, rel, content string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(rel))
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatalf("open %s: %v", path, err)
	}
	defer f.Close()
	if _, err := f.WriteString(content); err != nil {
		t.Fatalf("append %s: %v", path, err)
	}
}

func replaceFile(t *testing.T, root, rel, old, new string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(rel))
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	text := strings.Replace(string(content), old, new, 1)
	if text == string(content) {
		t.Fatalf("replace target %q not found in %s", old, path)
	}
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func writeFile(t *testing.T, root, rel, content string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(rel))
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func removeFile(t *testing.T, root, rel string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(rel))
	if err := os.Remove(path); err != nil {
		t.Fatalf("remove %s: %v", path, err)
	}
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
