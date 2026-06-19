package validate

import (
	"fmt"
	"io"
	"sort"
)

type Severity string

const (
	Error Severity = "ERROR"
	Warn  Severity = "WARN"
)

type Diagnostic struct {
	Severity Severity
	Area     string
	Path     string
	Message  string
}

type Report struct {
	Diagnostics []Diagnostic
	ModuleCount int
}

func (r Report) ErrorCount() int {
	count := 0
	for _, diag := range r.Diagnostics {
		if diag.Severity == Error {
			count++
		}
	}
	return count
}

func (r Report) WarningCount() int {
	count := 0
	for _, diag := range r.Diagnostics {
		if diag.Severity == Warn {
			count++
		}
	}
	return count
}

func (r Report) HasErrors() bool {
	return r.ErrorCount() > 0
}

func (r Report) WriteDiagnostics(w io.Writer) {
	diagnostics := append([]Diagnostic(nil), r.Diagnostics...)
	sortDiagnostics(diagnostics)
	for _, diag := range diagnostics {
		fmt.Fprintf(w, "%s %s: %s\n", diag.Severity, diag.Path, diag.Message)
	}
}

func (r Report) WriteSuccess(w io.Writer) {
	fmt.Fprintf(w, "OK yatta validate passed: %d modules, %d warnings\n", r.ModuleCount, r.WarningCount())
}

var areaOrder = map[string]int{
	"project":   0,
	"runtime":   1,
	"locale":    2,
	"modules":   3,
	"relations": 4,
}

func sortDiagnostics(diagnostics []Diagnostic) {
	sort.SliceStable(diagnostics, func(i, j int) bool {
		leftArea := areaOrder[diagnostics[i].Area]
		rightArea := areaOrder[diagnostics[j].Area]
		if leftArea != rightArea {
			return leftArea < rightArea
		}
		if diagnostics[i].Path != diagnostics[j].Path {
			return diagnostics[i].Path < diagnostics[j].Path
		}
		if diagnostics[i].Severity != diagnostics[j].Severity {
			return diagnostics[i].Severity < diagnostics[j].Severity
		}
		return diagnostics[i].Message < diagnostics[j].Message
	})
}
