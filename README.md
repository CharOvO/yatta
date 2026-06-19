# Yatta
![yatta](https://socialify.git.ci/CharOvO/yatta/image?custom_language=Go&description=1&font=JetBrains+Mono&forks=1&issues=1&language=1&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Light)
Yatta 是一个面向 Ubuntu 服务器的初始化工具。它的目标是把一台新的 Ubuntu 服务器配置成可日常使用的基础状态，同时把实现过程拆成清晰、可学习、可复盘的小阶段。

项目当前处于 **Phase 0：项目骨架与开发文档**。这一阶段只建立项目骨架、开发规则和计划文档，不实现实际的 Go 构建器、Bash runtime 或默认模块逻辑。

## 项目目标

Yatta v1 会包含两个交付层：

- 开发层：使用 Go 构建器维护源码、模块、校验逻辑、locale 和脚本生成流程。
- 用户层：交付一个零外部依赖的 Bash 单文件脚本，默认产物为 `dist/yatta.sh`。

普通用户未来只需要运行生成后的 `dist/yatta.sh`。高级用户可以调整模块、runtime 或 locale 后重新构建，生成定制脚本。

## 当前状态

当前仓库只完成 Phase 0 的项目骨架：

- 已建立 Go module，module path 为 `github.com/CharOvO/yatta`。
- 已建立 v1 目标目录树。
- 已建立 `docs/plan/` 计划目录。
- 已添加第一份阶段计划 `docs/plan/project-skeleton.md`。

尚未实现：

- `yatta build`
- `yatta validate`
- `yatta list-modules`
- Bash runtime
- 默认模块
- `dist/yatta.sh`

## 目录说明

```text
yatta/
├── cmd/yatta/          # Go CLI 入口，未来只负责解析命令并调用 internal/*
├── internal/           # Go 构建器、模块读取、locale 和校验逻辑
├── runtime/            # 未来会被拼接进最终脚本的 Bash 标准库
├── modules/            # 服务器初始化模块
├── locales/            # 脚本文案源文件
├── dist/               # yatta build 生成产物目录
├── docs/plan/          # 功能级、模块级、实现级计划文档
├── DEVELOPMENT.md      # 项目级开发总手册
└── go.mod              # Go module 定义
```

暂时为空的目录使用 `.gitkeep` 保留。后续对应阶段加入真实文件后，可以删除相应占位文件。

## 开发流程

Yatta 的开发遵守轻量但留痕的流程：

1. 先记录需求或想法。
2. 在 `docs/plan/<feature>.md` 写计划。
3. 根据计划实现。
4. 按影响范围执行验证。
5. 回到同一份计划文档更新验收结果、遗留问题和复盘。

任何功能级、模块级、实现级工作都应该先有计划文档，再进入实现。

## 重要文档

- `DEVELOPMENT.md`：项目定位、阶段划分、目录职责、模块规范、验证规则和发布约束。
- `docs/plan/project-skeleton.md`：Phase 0 项目骨架工作单元计划。

## 后续方向

Phase 0 完成后，下一步应进入 Phase 1，优先规划并实现 Go CLI 最小入口和手写子命令分发，为后续 `yatta build`、`yatta validate` 和 `yatta list-modules` 打基础。
