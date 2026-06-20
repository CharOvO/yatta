package version

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// 这里集中读取 Yatta 的版本号。Go CLI 和 Bash 构建产物都从同一个 VERSION
// 文件取值，避免不同入口显示出不同版本。

const fileName = "VERSION"

func Read(root string) (string, error) {
	content, err := os.ReadFile(filepath.Join(root, fileName))
	if err != nil {
		return "", fmt.Errorf("read %s: %w", fileName, err)
	}
	value := strings.TrimSpace(string(content))
	if value == "" {
		return "", fmt.Errorf("%s must not be empty", fileName)
	}
	return value, nil
}
