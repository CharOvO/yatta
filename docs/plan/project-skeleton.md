# Project Skeleton

## 目标

本计划用于推进 Yatta v1 的 Phase 0：项目骨架与开发文档。

目标是把当前只有 `DEVELOPMENT.md` 的项目整理成符合 v1 目标结构的最小可开发状态，为后续 Phase 1 的 Go 构建器、模块校验和脚本生成流程提供稳定目录基础。

本工作单元同时初始化 Git 仓库、连接远程仓库并准备首次提交，但不实现任何 Phase 1 及之后的功能代码。

## 范围

包含：

- 初始化 `go.mod`。
- 建立 `DEVELOPMENT.md` 中定义的 v1 目标目录结构。
- 建立 `docs/plan/` 目录。
- 使用 `.gitkeep` 保留暂时为空的目录。
- 添加详细中文 `README.md`。
- 添加 `.gitignore`。
- 初始化 Git 仓库，默认分支为 `main`。
- 连接远程仓库 `https://github.com/CharOvO/yatta`。
- 在提交前让用户审核 commit message。
- 审核通过后提交并推送到远程 `main` 分支。

不包含：

- 实现 `yatta build`、`yatta validate`、`yatta list-modules`。
- 创建 `cmd/yatta/main.go`。
- 实现模块读取、排序、校验逻辑。
- 实现 Bash runtime。
- 实现默认模块。
- 创建 `locales/zh-CN.json`。
- 生成 `dist/yatta.sh`。
- 执行 Ubuntu、Docker、VM/VPS 集成验收。
- 引入第三方依赖或 CLI 框架。

## 文件职责与拆分原因

`go.mod` 声明 Go module，module path 固定为 `github.com/CharOvO/yatta`，Go 版本使用当前开发环境基线 `1.25`。

`README.md` 面向首次进入仓库的读者，说明项目是什么、当前处于哪个阶段、目录如何理解，以及后续从哪里继续。

`.gitignore` 用于忽略系统、编辑器、本地环境、日志和 Go 测试构建临时产物。`dist/` 不被整体忽略，因为 v1 发布产物允许包含由 `yatta build` 生成的 `dist/yatta.sh`。

`docs/plan/project-skeleton.md` 是 Phase 0 第一个工作单元计划，记录本次骨架初始化的目标、边界、执行步骤、验收方式和复盘。

`cmd/yatta/` 未来存放 Go CLI 入口，本阶段只保留目录，不创建 `main.go`，避免提前进入 Phase 1。

`internal/` 下各目录未来分别承载 CLI 分发、构建器、模块读取、locale 读取和校验逻辑。本阶段只保留目录结构。

`runtime/` 下各目录未来分别承载 Bash 标准库的核心流程、UI、系统工具和 Ubuntu adapter。本阶段只保留目录结构。

`modules/` 下各目录对应 v1 默认模块。本阶段不创建 `module.yaml`、`prompts.sh` 或 `apply.sh`，避免提前实现模块逻辑。

`locales/` 未来存放脚本文案源文件。本阶段不创建 `zh-CN.json`，因为 locale 字段和生成方式应在 Phase 1/2 的对应计划中确认。

`dist/` 未来只存放构建产物。本阶段不创建 `yatta.sh`，因为它必须由 `yatta build` 生成。

## 大致流程

1. 确认当前仓库仍然只有 `DEVELOPMENT.md`。
2. 创建 `docs/plan/` 并保存本计划。
3. 创建 `go.mod`。
4. 创建 README 和忽略规则。
5. 创建 v1 目标目录树。
6. 为暂时为空的目录添加 `.gitkeep`。
7. 检查当前结构是否满足 Phase 0 目标。
8. 初始化 Git 仓库并设置 `main` 分支。
9. 连接远程仓库。
10. 运行 Phase 0 范围内的验证。
11. 向用户展示最终 commit message 并等待审核。
12. 审核通过后提交并推送。
13. 更新本计划的验收结果、遗留问题和复盘。

## 实现步骤

1. 创建或确认以下目录：

   - `cmd/yatta/`
   - `internal/cli/`
   - `internal/builder/`
   - `internal/module/`
   - `internal/locale/`
   - `internal/validate/`
   - `runtime/core/`
   - `runtime/ui/`
   - `runtime/system/`
   - `runtime/adapter/`
   - `modules/system-check/`
   - `modules/hostname/`
   - `modules/user/`
   - `modules/timezone/`
   - `modules/packages/`
   - `modules/ufw/`
   - `locales/`
   - `dist/`
   - `docs/plan/`

2. 创建 `go.mod`：

   ```text
   module github.com/CharOvO/yatta

   go 1.25
   ```

3. 创建详细中文 `README.md`，说明项目定位、当前阶段、目录结构、开发流程和后续方向。

4. 创建 `.gitignore`，忽略常见本地噪声与 Go 临时产物，但不忽略 `dist/` 和 `docs/plan/`。

5. 在暂时为空的目录中添加 `.gitkeep`，使目录树可被 Git 记录。

6. 初始化 Git：

   ```text
   git init
   git branch -M main
   git remote add origin https://github.com/CharOvO/yatta
   ```

7. 验证结构和文档。

8. 提交前向用户展示 commit message：

   ```text
   feat: 初始化项目骨架
   ```

9. 用户审核通过后执行首次提交并推送。

## 验收标准

结构验收：

- `go.mod` 存在。
- `go.mod` 的 module path 为 `github.com/CharOvO/yatta`。
- `docs/plan/project-skeleton.md` 存在。
- v1 目标目录树已建立。
- 暂时为空的目录均有 `.gitkeep`。
- 没有创建 `cmd/yatta/main.go`。
- 没有创建 `locales/zh-CN.json`。
- 没有创建模块 `module.yaml`、`prompts.sh`、`apply.sh`。
- 没有创建 `dist/yatta.sh`。

文档验收：

- `README.md` 能说明项目定位、当前阶段、目录结构、开发流程和后续方向。
- 本计划符合 `DEVELOPMENT.md` 的计划模板。
- 路径、命名和阶段边界与 `DEVELOPMENT.md` 保持一致。

Go 验收：

- 运行 `go test ./...`。
- 如果因为当前没有 Go package 而提示无包可测，记录为 Phase 0 可接受结果。

Git 验收：

- 当前目录已是 Git 仓库。
- 当前分支为 `main`。
- remote `origin` 指向 `https://github.com/CharOvO/yatta`。
- 首次提交前用户已审核 commit message。
- 审核通过后提交并推送到远程 `main`。

## 进度记录

已确认：

- 初始项目根目录只有 `DEVELOPMENT.md`。
- 远程仓库 `https://github.com/CharOvO/yatta` 可访问，检查时未返回远程引用，按空仓库处理。
- 本机 Go 版本为 `go1.25.6 windows/amd64`。
- 本机 Git 可用。

执行记录：

- 已创建 `go.mod`、`README.md`、`.gitignore` 和 `docs/plan/project-skeleton.md`。
- 已创建 v1 目标目录树，并使用 `.gitkeep` 保留暂时为空的目录。
- 已确认未创建 `cmd/yatta/main.go`、`locales/zh-CN.json`、模块脚本或 `dist/yatta.sh`。
- 已运行 `go test ./...`，当前结果为没有 Go package 可测试；这符合 Phase 0 的预期边界。
- 已初始化 Git 仓库，当前分支为 `main`。
- 已设置远程仓库 `origin` 为 `https://github.com/CharOvO/yatta`。
- 首次提交信息已由用户审核为 `feat: 初始化仓库🎉`，随后执行提交和推送。

## 复盘与后续

阶段复盘：

- Phase 0 骨架已按 `DEVELOPMENT.md` 的 v1 目标结构建立。
- 本阶段刻意没有提前创建功能代码、locale 文件、模块文件或生成脚本，避免越界进入 Phase 1/2/3。
- 当前 Go 验证只有无包可测结果；等 Phase 1 创建 Go package 后，再执行完整 `go test ./...`、`go vet ./...`。
- Git 首次提交和推送使用用户审核后的提交信息 `feat: 初始化仓库🎉`。

建议的下一工作单元：

- Phase 1 第 1 个工作单元：Go CLI 最小入口与手写子命令分发。
- 计划文件建议命名为 `docs/plan/go-cli.md`。
- 该工作单元应先明确 `yatta build`、`yatta validate`、`yatta list-modules` 的命令行为、错误输出、help 文案和测试边界。
