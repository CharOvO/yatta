package locale

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// 这里的 locale 包在第一阶段刻意保持很小：这里只证明构建器能读取
// 文案源文件 zh-CN，不提前决定后续 runtime 的完整文案结构。

func LoadZhCN(root string) (map[string]any, error) {
	path := filepath.Join(root, "locales", "zh-CN.json")
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", filepath.ToSlash(path), err)
	}
	var values map[string]any
	if err := json.Unmarshal(content, &values); err != nil {
		return nil, fmt.Errorf("parse %s: %w", filepath.ToSlash(path), err)
	}
	if len(values) == 0 {
		return nil, fmt.Errorf("%s must be a non-empty JSON object", filepath.ToSlash(path))
	}
	return values, nil
}
