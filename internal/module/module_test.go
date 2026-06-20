package module

import (
	"path/filepath"
	"testing"
)

func TestLoadAllSortsByStageAndRelations(t *testing.T) {
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

func TestOrderedIDsDetectsCycle(t *testing.T) {
	_, err := OrderedIDs([]Metadata{
		{ID: "alpha", Stage: "system", Before: []string{"beta"}},
		{ID: "beta", Stage: "system", Before: []string{"alpha"}},
	})
	if err == nil {
		t.Fatal("expected cycle error")
	}
}

func TestOrderedIDsSortsBeforeAfter(t *testing.T) {
	ordered, err := OrderedIDs([]Metadata{
		{ID: "firewall", Stage: "firewall"},
		{ID: "sshd", Stage: "remote-access", Before: []string{"fail2ban"}},
		{ID: "fail2ban", Stage: "security", After: []string{"sshd"}},
		{ID: "packages", Stage: "packages"},
	})
	if err != nil {
		t.Fatalf("OrderedIDs returned error: %v", err)
	}
	want := []string{"packages", "sshd", "fail2ban", "firewall"}
	for index, id := range want {
		if ordered[index] != id {
			t.Fatalf("ordered[%d] = %q, want %q in %v", index, ordered[index], id, ordered)
		}
	}
}

func TestFunctionID(t *testing.T) {
	if got := FunctionID("system-check"); got != "system_check" {
		t.Fatalf("FunctionID() = %q", got)
	}
}
