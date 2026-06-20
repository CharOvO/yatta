# Phase 3 默认模块实现

## 目标

完成 Yatta v1 默认模块的真实交互、计划登记和系统修改逻辑，让 `hostname`、`user`、`timezone`、`packages`、`ufw` 从占位逻辑升级为可执行模块。除脚本继续运行必需的前置条件外，默认行为需要在 prompt 阶段询问用户；启用 UFW 的固定安全基线需要提前提示，并通过“是否启用 UFW”整体确认。

## 范围

包含默认模块脚本、少量 runtime/system 只读检测、必要的 runtime/adapter Ubuntu 通用操作封装、`list-modules` 的 `ORDER` 列、模块 order 分段规则和重新生成的 `dist/yatta.sh`。

不包含 SSH 安全加固、Docker、swap、fail2ban、unattended-upgrades、非 Ubuntu 适配、公开配置文件模式或正式 dry-run 模式。

## 文件职责与拆分原因

`modules/*/prompts.sh` 只负责读取现状、询问用户、保存运行期变量和登记执行计划。

`modules/*/apply.sh` 只负责在用户确认完整执行计划后执行真实系统修改，并优先复用已有 runtime 或 adapter。模块私有、非复用的一次性流程可以留在模块内，避免为单个模块扩张框架。

`runtime/system/checks.sh` 放置可复用的只读检测，避免模块重复散落系统探测。

`runtime/adapter/ubuntu.sh` 放置通用 Ubuntu 修改命令封装，便于 dry-run 和后续发行版适配；不要求每个模块的一次性实现都搬进 adapter。

## 大致流程

脚本启动后先通过 runtime preflight，再运行所有模块的 prompt 阶段，展示完整执行计划，用户确认后才按 order 顺序执行 apply 阶段。

默认顺序分段为：`0-99` 前置检查，`100-199` 本机基础设置，`200-299` 基础软件包，`300-599` 服务模块预留，`600-799` 远程访问和安全加固预留，`900-999` 防火墙和最终网络收尾。

## 实现步骤

1. 调整默认模块 order，并让 `list-modules` 显示 `ORDER`。
2. 补充 runtime 检测函数和 Ubuntu adapter 封装。
3. 实现 hostname、timezone、user、packages、ufw 的 prompt/apply 逻辑。
4. 重新生成 `dist/yatta.sh`。
5. 执行分层验收命令，并回填结果。

## 验收标准

- `gofmt -l .` 无输出。
- `go test ./...` 通过。
- `go vet ./...` 通过。
- `go run ./cmd/yatta validate` 通过。
- `go run ./cmd/yatta list-modules` 显示 `ORDER` 列，且 UFW 位于 `900`。
- `go run ./cmd/yatta build` 成功生成 `dist/yatta.sh`。
- `bash -n dist/yatta.sh` 通过。
- `YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 bash dist/yatta.sh` 能完成配置收集、计划展示、确认执行和 dry-run apply。
- user 模块的变量、日志、计划摘要中不出现明文密码。
- ufw 模块的计划中必须先出现 SSH 放行，再出现启用 UFW。

## 进度记录

- 已确认 Phase 2 完成，除 `system-check` 外的默认模块仍为占位逻辑。
- 已调整默认模块 order：`system-check=10`、`hostname=110`、`timezone=120`、`user=130`、`packages=210`、`ufw=900`。
- 已让 `list-modules` 显示 `ORDER` 列。
- 已在 `DEVELOPMENT.md` 记录 order 分段规则。
- 已补充 runtime 只读检测和 Ubuntu adapter 封装。
- 已实现 hostname、timezone、user、packages、ufw 的 prompt/apply 逻辑。
- 已调整 packages 和 ufw：基础包安装、ufw 自动安装需要用户确认；启用 UFW 时固定设置默认入站/出站策略，并在 prompt 阶段提前提示。
- 已确认 UFW 模块支持询问是否开放 HTTP/HTTPS 常用端口 `80/tcp`、`443/tcp`，确认后写入执行计划并在 apply 阶段放行。
- 已重新生成 `dist/yatta.sh`。
- 已运行 `gofmt -l .`，结果无输出。
- 已运行 `go test ./...`，通过。
- 已运行 `go vet ./...`，通过。
- 已运行 `go run ./cmd/yatta validate`，通过，输出 `OK yatta validate passed: 6 modules, 0 warnings`。
- 已运行 `go run ./cmd/yatta list-modules`，通过，UFW order 为 `900`。
- 已运行 `go run ./cmd/yatta build`，通过，生成 `dist/yatta.sh`。
- 本机默认 `bash` 仍指向未配置发行版的 WSL stub，无法用于语法检查；已使用 `C:\Program Files\Git\bin\bash.exe -n dist/yatta.sh` 完成 Bash 语法检查，通过。
- 已运行 `YATTA_TEST_MODE=1 YATTA_DRY_RUN=1` 的完整 dry-run 路径，能完成配置收集、计划展示、确认执行和 dry-run apply。

## 复盘与后续

Phase 3 已完成默认模块实现。后续 Phase 4 需要在 Docker Ubuntu 和真实 VM/VPS 中验证完整流程，尤其是 UFW、systemd 和真实 SSH 防锁门行为。
