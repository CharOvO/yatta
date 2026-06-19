package main

import (
	"os"

	"github.com/CharOvO/yatta/internal/cli"
)

// 这里的 main 刻意保持很薄：命令解析和行为都放在 internal/cli，
// 这样测试可以直接调用 CLI，而不必额外启动子进程。
func main() {
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr))
}
