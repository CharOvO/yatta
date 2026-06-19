package module

import (
	"path/filepath"
	"testing"
)

func TestLoadAllSortsByOrderThenID(t *testing.T) {
	modules, err := LoadAll(filepath.Join("..", "validate", "testdata", "valid"))
	if err != nil {
		t.Fatalf("LoadAll returned error: %v", err)
	}
	if len(modules) != 2 {
		t.Fatalf("expected 2 modules, got %d", len(modules))
	}
	if modules[0].Metadata.ID != "alpha" || modules[1].Metadata.ID != "beta" {
		t.Fatalf("expected stable alpha,beta order, got %q,%q", modules[0].Metadata.ID, modules[1].Metadata.ID)
	}
}

func TestFunctionID(t *testing.T) {
	if got := FunctionID("system-check"); got != "system_check" {
		t.Fatalf("FunctionID() = %q", got)
	}
}
