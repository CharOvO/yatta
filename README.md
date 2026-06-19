# Yatta
![yatta](https://socialify.git.ci/CharOvO/yatta/image?custom_language=Go&description=1&font=JetBrains+Mono&forks=1&issues=1&language=1&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Light)
Yatta 是一个面向 Ubuntu 服务器的初始化工具。它的目标是把一台新的 Ubuntu 服务器配置成可日常使用的基础状态，同时把实现过程拆成清晰、可学习、可复盘的小阶段。

项目当前已完成 **Phase 2：Bash runtime 与 TUI 基础能力**。仓库已经具备 Go 构建器、模块校验、单文件脚本生成、零依赖 Bash runtime、基础 TUI、入口硬检查、执行计划展示和 `system-check` 环境摘要。

下一步是 **Phase 3：默认模块实现**，会补齐 hostname、user、timezone、packages、ufw 的真实交互和系统修改逻辑。

## 项目目标

Yatta v1 会包含两个交付层：

- 开发层：使用 Go 构建器维护源码、模块、校验逻辑、locale 和脚本生成流程。
- 用户层：交付一个零外部依赖的 Bash 单文件脚本，默认产物为 `dist/yatta.sh`。

普通用户未来只需要运行生成后的 `dist/yatta.sh`。高级用户可以调整模块、runtime 或 locale 后重新构建，生成定制脚本。

## 当前状态

当前仓库已完成 Phase 0、Phase 1 和 Phase 2：

- 已建立 Go module，module path 为 `github.com/CharOvO/yatta`。
- 已建立 v1 目标目录树。
- 已实现 `yatta validate`。
- 已实现 `yatta list-modules`。
- 已实现 `yatta build`。
- 已实现多文件 Bash runtime：`core`、`ui`、`system`、`adapter`。
- 已实现入口硬检查：Bash、root、Ubuntu、apt、systemd。
- 已实现零依赖 TUI、日志、执行计划、确认执行和 dry-run 开发验收能力。
- 已实现 `system-check` 环境摘要表格。
- 已生成 `dist/yatta.sh`。

尚未实现：

- `hostname`、`user`、`timezone`、`packages`、`ufw` 的真实系统修改逻辑。
- Docker、VM/VPS 集成验收。

## 目录说明

```text
yatta/
├── cmd/yatta/          # Go CLI 入口，未来只负责解析命令并调用 internal/*
├── internal/           # Go 构建器、模块读取、locale 和校验逻辑
├── runtime/            # 会被拼接进最终脚本的 Bash 标准库
├── modules/            # 服务器初始化模块
├── locales/            # 脚本文案源文件
├── dist/               # yatta build 生成产物目录
├── docs/plan/          # 功能级、模块级、实现级计划文档
├── DEVELOPMENT.md      # 项目级开发总手册
└── go.mod              # Go module 定义
```

`dist/yatta.sh` 是由 `yatta build` 生成的产物，不应手写修改。

## 开发流程

Yatta 的开发遵守轻量但留痕的流程：

1. 先记录需求或想法。
2. 在 `docs/plan/<feature>.md` 写计划。
3. 根据计划实现。
4. 按影响范围执行验证。
5. 回到同一份计划文档更新验收结果、遗留问题和复盘。

任何功能级、模块级、实现级工作都应该先有计划文档，再进入实现。当前仓库会忽略 `docs/plan/*.md`，计划文档可作为本地草稿与复盘记录保存。

## 常用命令

```text
go run ./cmd/yatta validate
go run ./cmd/yatta list-modules
go run ./cmd/yatta build
```

构建后可用 Bash 做语法检查：

```text
bash -n dist/yatta.sh
```

在开发验收中，可以使用隐藏环境变量走非破坏性路径：

```text
YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 bash dist/yatta.sh
```

## 重要文档

- `DEVELOPMENT.md`：项目定位、阶段划分、目录职责、模块规范、验证规则和发布约束。
- `docs/plan/*.md`：本地功能计划、验收记录和复盘草稿。

## 后续方向

下一步应进入 Phase 3，实现默认模块的真实服务器初始化逻辑，并保持 prompt 阶段只登记计划、apply 阶段才修改系统的边界。
