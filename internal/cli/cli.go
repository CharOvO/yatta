package cli

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/CharOvO/yatta/internal/builder"
	"github.com/CharOvO/yatta/internal/module"
	"github.com/CharOvO/yatta/internal/validate"
)

const (
	ExitOK       = 0
	ExitValidate = 1
	ExitUsage    = 2
)

// 这里是 Run 函数，是 main 和测试共用的命令分发入口。这里不直接调用 os.Exit，
// 是为了让测试能验证输出和退出码，而不需要额外启动子进程。
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 || isHelp(args) {
		writeHelp(stdout)
		return ExitOK
	}

	command := args[0]
	if len(args) > 1 {
		fmt.Fprintf(stderr, "ERROR: %s does not accept arguments\n", command)
		return ExitUsage
	}

	root, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(stderr, "ERROR: cannot determine current directory: %v\n", err)
		return ExitUsage
	}

	switch command {
	case "validate":
		return runValidate(root, stdout, stderr)
	case "list-modules":
		return runListModules(root, stdout, stderr)
	case "build":
		return runBuild(root, stdout, stderr)
	default:
		fmt.Fprintf(stderr, "ERROR: unknown command %q\n", command)
		return ExitUsage
	}
}

func isHelp(args []string) bool {
	return len(args) == 1 && (args[0] == "-h" || args[0] == "--help")
}

func writeHelp(w io.Writer) {
	fmt.Fprint(w, `Yatta server init builder

Usage:
  yatta
  yatta validate
  yatta list-modules
  yatta build

Commands:
  validate      Check project structure, modules, runtime, and locale
  list-modules  List modules in execution order
  build         Generate dist/yatta.sh
`)
}

func runValidate(root string, stdout, stderr io.Writer) int {
	report := validate.Run(root)
	if len(report.Diagnostics) > 0 {
		report.WriteDiagnostics(stderr)
	}
	if report.HasErrors() {
		return ExitValidate
	}
	report.WriteSuccess(stdout)
	return ExitOK
}

func runListModules(root string, stdout, stderr io.Writer) int {
	modules, err := module.LoadAll(root)
	if err != nil {
		fmt.Fprintf(stderr, "ERROR: %v\n", err)
		return ExitUsage
	}
	writer := tabwriter.NewWriter(stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(writer, "ID\tNAME\tENABLED\tDISTROS")
	for _, mod := range modules {
		fmt.Fprintf(writer, "%s\t%s\t%t\t%s\n",
			mod.Metadata.ID,
			mod.Metadata.Name,
			mod.Metadata.DefaultEnabled,
			strings.Join(mod.Metadata.Supports.Distros, ","),
		)
	}
	writer.Flush()
	return ExitOK
}

func runBuild(root string, stdout, stderr io.Writer) int {
	result, report, err := builder.Build(root)
	if len(report.Diagnostics) > 0 {
		report.WriteDiagnostics(stderr)
	}
	if report.HasErrors() {
		return ExitValidate
	}
	if err != nil {
		fmt.Fprintf(stderr, "ERROR: %v\n", err)
		return ExitUsage
	}
	fmt.Fprintf(stdout, "OK yatta build generated %s with %d modules\n", filepath.ToSlash(result.Path), result.ModuleCount)
	return ExitOK
}
