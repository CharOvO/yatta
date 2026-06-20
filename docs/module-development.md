# Yatta 模块开发手册

本文面向高级用户和开发者，说明如何调整默认模块或新增模块。

## 模块结构

每个模块必须放在 `modules/<module-id>/` 下，并包含：

```text
module.yaml
prompts.sh
pre_apply.sh（可选）
apply.sh
post_apply.sh（可选）
```

`module.yaml` 描述模块元数据，`prompts.sh` 负责收集配置和登记计划，`apply.sh` 负责在用户确认后执行系统修改。

## module.yaml 字段

示例：

```yaml
id: hostname
name: Hostname
description: Configure system hostname
default_enabled: true
stage: system
order: 110
requires: []
before: []
after: []
conflicts: []
supports:
  distros: [ubuntu]
```

字段规则：

- `id` 使用短横线小写命名，且必须与目录名一致。
- `name` 是人类可读名称。
- `description` 描述模块效果。
- `default_enabled` 决定默认构建是否包含模块。
- `stage` 决定模块所属执行阶段，新模块优先使用。
- `order` 是兼容字段，可用于同阶段内辅助排序。
- `requires` 声明硬依赖模块 ID。
- `before` 声明当前模块必须早于哪些模块。
- `after` 声明当前模块必须晚于哪些模块。
- `conflicts` 声明冲突模块 ID。
- `supports.distros` 在 v1 中必须是 `[ubuntu]`。

## stage 阶段

推荐使用以下阶段，方便后续模块插入：

- `preflight`：前置检查与环境摘要，例如 `system-check`。
- `system`：主机名、时区、swap 等本机基础设置。
- `account`：用户、sudo、SSH 公钥、无用账户清理。
- `packages`：apt update、基础包、包管理准备。
- `remote-access`：sshd 配置。
- `services`：Docker、Node.js、Python、Go、Nginx 等服务或运行时。
- `security`：Fail2Ban、安全巡检等。
- `firewall`：UFW 与最终端口策略。
- `post`：apt upgrade、收尾摘要、重启提醒。

构建器会先按固定 stage 顺序分组，再根据 `requires`、`before`、`after` 做拓扑排序。循环依赖、缺失目标和自引用会由 `yatta validate` 报错。

## prompt/apply 边界

`prompts.sh` 只能：

- 读取现状。
- 询问用户。
- 保存运行期变量。
- 调用 `yatta_plan_add` 登记执行计划。

`prompts.sh` 禁止修改系统。

`pre_apply.sh`、`apply.sh`、`post_apply.sh` 只能在用户确认完整执行计划后运行。系统修改应优先调用 runtime 或 adapter 函数，例如：

- `yatta_set_hostname`
- `yatta_set_timezone`
- `yatta_apt_update`
- `yatta_apt_install_missing`
- `yatta_ensure_package_installed`
- `yatta_ufw_allow_port`
- `yatta_add_sudo_user`

## 端口计划

需要开放端口的模块应调用 runtime 统一登记端口需求：

```bash
yatta_port_plan_add "module-id" "tcp" "8080" "业务说明"
```

UFW 模块会统一展示、确认并放行端口计划。其他模块不应直接散落 UFW 命令。

## 构建与校验

常用命令：

```text
go run ./cmd/yatta validate
go run ./cmd/yatta list-modules
go run ./cmd/yatta build
```

生成后检查 Bash 语法：

```text
bash -n dist/yatta.sh
```

在开发环境中可以使用隐藏变量走非破坏性路径：

```text
YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 bash dist/yatta.sh
```

这些变量只用于开发验收，不是 v1 面向普通用户的配置模式。

## 注释和文档约定

源码、脚本、测试夹具和生成模板中的注释使用中文。注释应解释意图、边界、流程和风险，不重复代码表面含义。

新增功能级、模块级、实现级工作应先写入 `docs/plan/*.md`，实现后回填验收结果和复盘。
