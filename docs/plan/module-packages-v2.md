# v2 packages 模块

## 目标

本计划面向 v2 `packages` 模块重构。模块目标是保持保守的软件包基线：检测基础工具包，按用户确认安装缺失项，统一执行必要的 `apt update`，并把可选 `apt upgrade` 放到 post apply 收尾阶段。

模块保持中风险、默认启用。

## 范围

包含：

- 检测基础工具包是否缺失。
- 用户确认后安装缺失基础包。
- 安装或 upgrade 需要 apt 索引时，在 pre apply 阶段执行 `apt update`。
- 用户明确确认后，在 post apply 阶段执行 `apt upgrade`。

不包含：

- 不安装 `ufw`。
- 不为服务类模块决定依赖包、第三方包源或运行时版本。
- 不引入配置文件模式。

## 文件职责与拆分原因

- `modules/packages/prompts.sh` 负责检测缺失包、询问安装和 upgrade。
- `modules/packages/pre_apply.sh` 负责统一刷新 apt 索引。
- `modules/packages/apply.sh` 负责重新计算缺失包并安装。
- `modules/packages/post_apply.sh` 负责用户确认后的 `apt upgrade`。
- `runtime/adapter/ubuntu.sh` 负责封装 apt 命令。

拆分 pre/apply/post 可以让 apt update 作为前置准备执行，也能把风险更高的 upgrade 放到所有模块之后。

## 大致流程

1. prompt 阶段检测基础包缺失情况。
2. 缺失时询问是否安装，确认后登记安装计划和 apt update 需求。
3. 询问是否在最后执行 apt upgrade，默认否。
4. pre apply 阶段按需执行 apt update。
5. apply 阶段重新检测缺失包并安装。
6. post apply 阶段仅在用户明确确认时执行 apt upgrade。

## 实现步骤

- 保留当前基础包清单：`curl wget git vim unzip ca-certificates gnupg lsb-release`。
- 明确 `ufw` 仍由 `ufw` 模块自行负责。
- 检查现有脚本是否符合 v2 蓝图，必要时只做小幅文案和注释调整。
- 重新构建生成脚本。

## 验收标准

- 无缺失包时不执行安装。
- 用户拒绝安装时只登记 warn 计划。
- `apt update` 只在安装或 upgrade 需要时执行。
- `apt upgrade` 必须清晰提示可能升级大量系统包。
- `go run ./cmd/yatta validate`、`go run ./cmd/yatta build` 和 `bash -n dist/yatta.sh` 通过。

## 进度记录

- 已确认 packages 不承载服务类依赖和防火墙包安装职责。
- 已复核当前 `packages` 的 pre/apply/post 拆分，符合 v2 蓝图，无需扩大基础包清单。

## 复盘与后续

- 后续服务模块需要依赖包时，应在对应服务模块计划中单独声明，不塞回 packages 基线。
