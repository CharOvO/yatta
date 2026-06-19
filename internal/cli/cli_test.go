package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunHelp(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := Run(nil, &stdout, &stderr)
	if code != ExitOK {
		t.Fatalf("expected exit 0, got %d", code)
	}
	if !strings.Contains(stdout.String(), "Usage:") {
		t.Fatalf("help output missing usage: %q", stdout.String())
	}
	if stderr.Len() != 0 {
		t.Fatalf("expected empty stderr, got %q", stderr.String())
	}
}

func TestRunUnknownCommand(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := Run([]string{"nope"}, &stdout, &stderr)
	if code != ExitUsage {
		t.Fatalf("expected exit %d, got %d", ExitUsage, code)
	}
	if !strings.Contains(stderr.String(), "unknown command") {
		t.Fatalf("stderr missing unknown command: %q", stderr.String())
	}
}

func TestRunValidateAndListModules(t *testing.T) {
	withWorkingDir(t, filepath.Join("..", "validate", "testdata", "valid"), func() {
		var stdout, stderr bytes.Buffer
		code := Run([]string{"validate"}, &stdout, &stderr)
		if code != ExitOK {
			t.Fatalf("validate exit = %d stderr=%q", code, stderr.String())
		}
		if !strings.Contains(stdout.String(), "OK yatta validate passed") {
			t.Fatalf("stdout missing success: %q", stdout.String())
		}

		stdout.Reset()
		stderr.Reset()
		code = Run([]string{"list-modules"}, &stdout, &stderr)
		if code != ExitOK {
			t.Fatalf("list-modules exit = %d stderr=%q", code, stderr.String())
		}
		if !strings.Contains(stdout.String(), "ID") || !strings.Contains(stdout.String(), "alpha") {
			t.Fatalf("list output missing expected table: %q", stdout.String())
		}
	})
}

func withWorkingDir(t *testing.T, dir string, fn func()) {
	t.Helper()
	original, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir %s: %v", dir, err)
	}
	defer func() {
		if err := os.Chdir(original); err != nil {
			t.Fatalf("restore cwd: %v", err)
		}
	}()
	fn()
}
