# v2 系统基础设置模块

## 目标

本计划面向 v2 默认模块重构中的系统基础设置工作单元。系统基础设置在用户体验中作为一组连续流程展示，源码仍拆分为 `hostname`、`timezone` 和 `swap` 三个模块，便于分别校验边界和幂等行为。

目标是让低风险的主机名与时区设置保持默认启用，并新增中风险的 swap 候选能力。所有模块都必须在 prompt 阶段只读取状态、询问用户和登记计划，真实系统修改只能在 apply 阶段发生。

## 范围

包含：

- 细化 `hostname` 的保留、修改、非法输入拦截和重复运行跳过逻辑。
- 细化 `timezone` 的默认建议、自定义输入、跳过和 apply 前复查逻辑。
- 新增 `swap` 模块，检测已有 swap、内存和根分区可用空间，并可选创建单个 `/swapfile`。
- 为 swap 补充 runtime/system 探测函数；swapfile 创建属于该模块私有的一次性流程，执行逻辑留在 `modules/swap/apply.sh`。

不包含：

- 不修改 `/etc/hosts` 映射策略。
- 不处理 NTP、chrony 或时间同步策略。
- 不处理 swap 分区、zram、云厂商特殊 swap 或自动删除已有 swap。

## 文件职责与拆分原因

- `modules/hostname/` 只负责系统 hostname。
- `modules/timezone/` 只负责系统 IANA 时区。
- `modules/swap/` 只负责单个 swapfile 的规划和创建。
- `runtime/system/checks.sh` 负责只读探测和输入校验。
- `modules/swap/apply.sh` 直接负责 swapfile 创建、权限、`mkswap`、`swapon` 和 `/etc/fstab` 幂等追加，并复用 `yatta_run_command` 支持 dry-run。

这样拆分可以让 UI 上的“系统基础设置”保持连续，同时避免把不同风险级别和执行方式混在一个 Bash 文件里。

## 大致流程

1. 运行时模块选择后，系统基础设置组按 `hostname`、`timezone`、`swap` 顺序进入 prompt。
2. `hostname` 和 `timezone` 读取当前值并询问是否修改。
3. `swap` 读取当前 swap、内存和根分区空间；已有 swap 时默认跳过，无 swap 时建议保守大小。
4. 所有模块登记执行计划。
5. 用户确认完整计划后，apply 阶段重新检测现状并执行必要修改。

## 实现步骤

- 保留并微调 `hostname`、`timezone` 的现有 v2 元数据和幂等逻辑。
- 新增 `modules/swap/module.yaml`、`prompts.sh`、`apply.sh`。
- 新增 swap 状态、内存、磁盘空间和 swap 大小校验函数。
- 在 `modules/swap/apply.sh` 内实现创建、权限、`mkswap`、`swapon` 和 `/etc/fstab` 幂等追加，不为单个模块新增 adapter 函数。
- 重新构建 `dist/yatta.sh`。

## 验收标准

- `hostname` 保留当前值时不执行 `hostnamectl`。
- 非法 hostname 不进入执行计划。
- `timezone` 跳过时不执行 `timedatectl`。
- 不存在的时区不能进入执行计划。
- 已有 swap 时不会重复创建。
- dry-run 能展示将创建的 swapfile 路径、大小和 fstab 变更。
- `go run ./cmd/yatta validate`、`go run ./cmd/yatta build` 和 `bash -n dist/yatta.sh` 通过。

## 进度记录

- 已根据 v2 蓝图确认系统基础设置包含 `hostname`、`timezone` 和 `swap`。
- 已新增 `swap` 模块，默认进入 `system-basics` 组，风险等级为 medium。
- 已补充 swap 探测、推荐大小、磁盘空间校验，并将创建逻辑保留在 swap 模块内。
- 已重新生成 `dist/yatta.sh`，生成脚本包含 7 个模块。

## 复盘与后续

- 本轮只支持单个 `/swapfile`，不处理 swap 分区、zram 或删除已有 swap。
- 后续如果要支持自定义 swap 路径，应先补充单独计划并确认路径安全规则。
