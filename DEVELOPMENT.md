# Yatta Development Guide

本文档是 Yatta 项目的开发总手册。所有项目结构、实现计划、模块设计、构建流程、测试验收、默认行为和文档规则都必须遵守本文档。

功能级、模块级、实现级计划必须放入 `docs/plan/*.md`。任何进入实现阶段的工作都必须先有明确计划，不得只依赖临时口头约定。

## 1. 项目定位

Yatta 是一个服务器初始化工具，用于把一台新的 Ubuntu 服务器配置成可日常使用的基础状态。

Yatta 包含两个交付层：

- 开发层：使用 Go 构建器维护源码、模块、校验逻辑、locale 和脚本生成流程。
- 用户层：交付一个零外部依赖的 Bash 单文件脚本，默认产物为 `dist/yatta.sh`。

普通用户只需要执行生成后的脚本。高级用户通过调整模块和 locale 后重新构建，生成定制脚本。

## 2. 练手项目原则

Yatta 是个人练手项目。项目优先服务学习、理解和复盘，而不是一开始就追求复杂的正式团队流程。

开发时必须遵守以下原则：

- 每个功能都要能解释为什么需要、为什么这样拆分、完成后如何验收。
- 每个文档和源码文件都要有足够注释，说明这个文件是干什么的、为什么要单独分出这个文件、职责边界是什么、大致流程是什么。
- 注释重点解释意图、边界和流程，不重复代码表面含义。
- 可以接受阶段性不完美，但必须把 TODO、明确假设、遗留问题或后续计划写清楚。
- 新增复杂规则前，优先确认它是否真的帮助学习和维护；不能只为了显得工程化而增加负担。

## 3. v1 基础约束

- Go module path 必须使用 `github.com/CharOvO/yatta`。
- 最终脚本必须使用 `.sh` 文件名。
- 最终脚本 shebang 必须为 `#!/usr/bin/env bash`。
- v1 只支持 Ubuntu。
- v1 脚本必须以 root 身份运行。
- 非 root 运行时，脚本必须停止并提示使用 `sudo bash yatta.sh`。
- 生成后的脚本禁止依赖 `gum`、`fzf`、`dialog` 等外部 TUI 工具。
- v1 只支持交互式运行，不实现配置文件模式。
- 用户输入必须先保存为运行期变量，不得边询问边修改系统。
- 模块的询问阶段只能登记配置和执行计划，禁止修改系统。
- 只有在用户确认完整执行计划后，脚本才允许修改系统。
- 系统修改必须采用保守幂等策略：先检测现状，再决定是否变更。
- 核心代码必须保留发行版适配层，不得把 Ubuntu 逻辑散落在所有模块里。

## 4. v1 目标项目结构

项目采用标准小型 Go 布局。v1 目标目录结构如下。结构调整必须先更新本文档或对应计划文档，再进入实现。

```text
yatta/
├── go.mod
├── DEVELOPMENT.md
├── cmd/
│   └── yatta/
│       └── main.go
├── internal/
│   ├── cli/
│   ├── builder/
│   ├── module/
│   ├── locale/
│   └── validate/
├── runtime/
│   ├── core/
│   ├── ui/
│   ├── system/
│   └── adapter/
├── modules/
│   ├── system-check/
│   │   ├── module.yaml
│   │   ├── prompts.sh
│   │   └── apply.sh
│   ├── hostname/
│   │   ├── module.yaml
│   │   ├── prompts.sh
│   │   └── apply.sh
│   ├── user/
│   │   ├── module.yaml
│   │   ├── prompts.sh
│   │   └── apply.sh
│   ├── timezone/
│   │   ├── module.yaml
│   │   ├── prompts.sh
│   │   └── apply.sh
│   ├── packages/
│   │   ├── module.yaml
│   │   ├── prompts.sh
│   │   └── apply.sh
│   └── ufw/
│       ├── module.yaml
│       ├── prompts.sh
│       └── apply.sh
├── locales/
│   └── zh-CN.json
├── dist/
│   └── yatta.sh
└── docs/
    └── plan/
```

目录职责如下：

- `cmd/yatta/`：Go CLI 入口，只负责解析命令并调用 `internal/*`。
- `internal/cli/`：手写子命令分发、参数解析和 help 文案。
- `internal/builder/`：生成 `dist/yatta.sh`。
- `internal/module/`：读取模块、排序模块、解析模块元数据。
- `internal/locale/`：读取 JSON locale，并把文案内联进生成脚本。
- `internal/validate/`：校验项目结构、模块字段、依赖、冲突和生成前置条件。
- `runtime/`：最终脚本中会被拼接进去的 Bash 标准库。
- `modules/`：服务器初始化模块。
- `locales/`：脚本文案源文件。
- `dist/`：构建产物目录，只存放 `yatta build` 生成的结果。
- `docs/plan/`：所有功能级、模块级、实现级计划文档都存放在这里。

## 5. 日常开发流程

Yatta 的日常开发采用轻量但留痕的流程。一个工作单元以一个功能或一个模块为主，例如 Go 构建器、runtime UI、默认模块或某个验证能力。

每个工作单元按以下顺序推进：

1. 记录想法或需求。
2. 在 `docs/plan/<feature>.md` 写计划。
3. 根据计划实现。
4. 按影响范围执行分层验证。
5. 在同一份计划文档中更新验收结果、遗留问题和复盘。
6. 检查当前 Phase 完成清单，再决定是否进入下一项或下一阶段。

默认不得跳过计划直接实现。若只是修正文案、错别字、路径命名这类极小改动，可以在提交说明中写清原因，但不应借此绕过功能级或模块级计划。

## 6. 开发阶段

Yatta v1 按 5 个阶段开发。只有当前阶段的完成检查清单满足后，才默认进入下一阶段。确实需要并行推进时，必须在对应计划文档中记录原因、依赖和风险。

### Phase 0: 项目骨架与开发文档

目标：

- 初始化 Go module。
- 建立 v1 目标目录结构。
- 完成 `DEVELOPMENT.md`。
- 建立 `docs/plan/*.md` 计划文档规则。

交付物：

- `go.mod`，module path 为 `github.com/CharOvO/yatta`。
- v1 目标目录树。
- `docs/plan/*.md` 中的阶段计划。

完成检查清单：

- [ ] 新贡献者能够通过本文档理解项目目标、结构、开发顺序和约束。
- [ ] 所有新计划都放在 `docs/plan/*.md`。
- [ ] 文件命名、目录命名和文档规则保持一致。

### Phase 1: Go 构建器与模块校验

目标：

- 实现 `yatta build`。
- 实现 `yatta validate`。
- 实现 `yatta list-modules`。
- 能读取模块、locale 和 runtime，并生成单文件脚本。

交付物：

- Go CLI 子命令。
- 模块读取和排序逻辑。
- 模块字段校验、依赖校验、冲突校验。
- `dist/yatta.sh` 生成流程。

完成检查清单：

- [ ] `gofmt -l .` 无未格式化 Go 文件。
- [ ] `go test ./...` 通过。
- [ ] `go vet ./...` 通过。
- [ ] `yatta validate` 能发现缺失字段、重复模块 ID、依赖缺失和冲突模块。
- [ ] `yatta build` 能生成带 shebang 的 `dist/yatta.sh`。
- [ ] `dist/yatta.sh` 由构建器生成，没有手写修改。

### Phase 2: Bash runtime 与 TUI 基础能力

目标：

- 建立 Bash runtime 标准库。
- 实现零依赖 TUI。
- 实现系统探测、执行计划、日志和安全工具。

交付物：

- UI 函数：品牌启动区、阶段标题、选择器、输入框、确认框、spinner、日志。
- 系统探测函数：Ubuntu、root、Bash、apt、systemd、基础网络状态。
- 执行框架：收集配置、登记计划、展示摘要、确认执行、顺序执行。
- 安全工具：文件备份、幂等写入、命令存在检查、失败处理。
- Ubuntu adapter：封装 `apt`、`ufw`、`timedatectl`、`hostnamectl`、`adduser`、`usermod` 等操作。

完成检查清单：

- [ ] 生成脚本通过 `bash -n dist/yatta.sh`。
- [ ] 脚本能在不执行系统变更的路径中完成交互收集和计划展示。
- [ ] 非 root 运行时必须停止。
- [ ] 非 Ubuntu 环境必须给出清晰提示并停止。
- [ ] runtime 入口硬检查与 `system-check` 模块职责边界清晰。

### Phase 3: 默认模块实现

目标：

- 实现 v1 默认模块。
- 确保每个模块遵守 `prompts.sh` 和 `apply.sh` 的职责边界。

交付物：

- `system-check`
- `hostname`
- `user`
- `timezone`
- `packages`
- `ufw`

完成检查清单：

- [ ] 每个模块都有完整 `module.yaml`。
- [ ] 每个模块都能登记执行计划。
- [ ] 每个模块重复运行时尽量保持幂等。
- [ ] `user` 模块不在变量、日志或计划摘要中保存明文密码。
- [ ] `ufw` 模块必须先确认 SSH 放行策略，再启用 UFW。

### Phase 4: 集成验收与发布准备

目标：

- 验证生成脚本在 Ubuntu 环境中的完整流程。
- 固定 v1 发布产物。

交付物：

- `dist/yatta.sh`
- 基础 smoke test 说明。
- VM/VPS 验收记录。

完成检查清单：

- [ ] Docker Ubuntu 中完成基础非破坏性验证。
- [ ] VM/VPS 中验证 UFW、systemd、真实 SSH 防锁门行为。
- [ ] 发布产物包含源码和由 `yatta build` 生成的 `dist/yatta.sh`。
- [ ] 发布说明能解释普通用户和高级用户分别如何使用。

## 7. Go 构建器规范

v1 Go 构建器必须标准库优先，不引入第三方 CLI 框架。CLI 命令使用手写子命令分发。

必须实现的命令：

```text
yatta build
yatta validate
yatta list-modules
```

命令契约：

- `yatta build`：读取 runtime、modules、locale，生成 `dist/yatta.sh`。
- `yatta validate`：校验项目结构、模块字段、模块依赖、模块冲突、locale 文件和 runtime 文件。
- `yatta list-modules`：按执行顺序列出模块 ID、名称、启用状态和支持发行版。

后续即使迁移到 Cobra 等 CLI 框架，也不得破坏以上命令接口和默认行为。

## 8. Bash Runtime 规范

Bash runtime 是最终脚本中的标准库。模块必须优先调用 runtime 函数，不得各自重复实现 UI、日志、系统探测和基础系统操作。

runtime 必须包含以下能力：

- UI：标题、阶段、选择器、输入框、确认框、spinner、日志。
- 系统探测：Ubuntu 版本、root 状态、Bash 版本、apt、systemd、基础网络状态。
- 执行框架：收集配置、登记计划、展示摘要、确认执行、顺序执行。
- 安全工具：文件备份、幂等写入、命令存在检查、失败处理。
- Ubuntu adapter：封装 `apt`、`ufw`、`timedatectl`、`hostnamectl`、`adduser`、`usermod`。

runtime 负责脚本入口硬检查和通用能力，例如 Bash、root、Ubuntu、基础命令存在性。`system-check` 模块负责向用户展示更完整的环境摘要，并登记更细的前置检查计划。两者不得重复实现彼此的职责。

执行模型：

1. 启动脚本。
2. 检查 Bash、root、Ubuntu。
3. 加载 runtime 和模块函数。
4. 运行所有模块的 prompt 阶段。
5. 展示完整执行计划。
6. 用户确认。
7. 按模块顺序执行 apply 阶段。
8. 输出结果摘要。

## 9. 交互与 Locale 规范

v1 脚本文案通过 locale 文件生成。locale 文件使用 JSON。

v1 必须提供：

```text
locales/zh-CN.json
```

v1 只内联 `zh-CN` 文案到生成脚本。后续添加 `en-US.json` 时，不得改变模块逻辑。

交互界面规则：

- 界面必须保持零外部依赖。
- 品牌启动区使用 `Yatta! server init` 或 locale 中对应文案。
- 阶段标题必须明确当前流程。
- 选项式交互必须支持默认值和当前选项高亮。
- 执行前摘要必须列出全部系统变更。
- 执行阶段必须显示 spinner 和当前任务。
- 日志等级必须统一为 `info`、`ok`、`warn`、`error`。

v1 spinner 使用 ASCII 动画：

```text
\ | / -
```

UTF-8 spinner 属于增强样式，必须保留 ASCII fallback。

文案风格允许轻微可爱。涉及 root 权限、防火墙、SSH、用户创建、失败原因时，文案必须准确、直接、可操作。

## 10. 模块规范

模块必须使用以下结构：

```text
modules/<module-id>/
  module.yaml
  prompts.sh
  apply.sh
```

`module.yaml` v1 必须包含以下字段：

```yaml
id: hostname
name: Hostname
description: Configure system hostname
default_enabled: true
order: 20
requires: []
conflicts: []
supports:
  distros: [ubuntu]
```

字段规则：

- `id` 必须唯一，使用短横线小写命名。
- `name` 必须是人类可读名称。
- `description` 必须描述模块效果。
- `default_enabled` 决定默认脚本是否包含该模块。
- `order` 决定执行顺序，数值小的先执行。
- `requires` 声明依赖模块 ID。
- `conflicts` 声明冲突模块 ID。
- `supports.distros` 声明支持的发行版，v1 默认只允许 `ubuntu`。

脚本职责：

- `prompts.sh` 只允许询问用户、保存变量、登记执行计划。
- `prompts.sh` 禁止执行任何系统变更。
- `apply.sh` 只允许在用户确认后执行真实系统变更。
- `apply.sh` 中的系统操作必须优先调用 runtime 或 adapter。
- 模块必须按保守幂等策略实现。

## 11. v1 默认模块

v1 默认模块保持保守，只覆盖服务器初始化基础路径。

### system-check

`system-check` 模块负责向用户展示环境摘要，并登记比 runtime 入口硬检查更细的前置检查计划。runtime 已经完成的硬性阻断逻辑不得在模块内重复散落实现。

必须检查：

- Ubuntu。
- Bash。
- root。
- apt。
- systemd。
- 基础网络状态。

失败时必须清晰说明原因并停止执行。

### hostname

必须支持：

- 保留当前 hostname。
- 设置新 hostname。

实际修改必须通过 runtime/adapter 调用 `hostnamectl`。

### user

必须支持：

- 创建非 root 用户。
- 使用 Ubuntu `adduser` 封装进行用户创建。
- 创建后使用 `usermod -aG sudo` 加入 `sudo` 组。

模块不得在脚本变量、日志或执行计划摘要中保存明文密码。密码必须交给系统交互工具或系统命令处理。

### timezone

必须支持：

- 默认值 `Asia/Shanghai`。
- 用户修改时区。
- 跳过时区设置。

实际修改必须通过 `timedatectl` adapter。

### packages

必须安装基础工具包：

```text
curl wget git vim unzip ca-certificates gnupg lsb-release
```

安装前必须通过 apt adapter 更新必要状态，避免模块直接散落 apt 命令。

### ufw

必须执行以下策略：

- 默认设置 `deny incoming`。
- 默认设置 `allow outgoing`。
- 识别当前 sshd 配置中的 SSH 端口。
- 无法识别时默认使用 22 并提示用户确认。
- 启用 UFW 前必须放行确认后的 SSH 端口。
- 询问是否开放 80/443。

SSH 安全加固不进入 v1 默认模块。后续 SSH 模块的执行优先级必须高于 UFW 模块。

## 12. v1 禁止进入默认脚本的能力

以下能力不得进入 v1 默认脚本：

- SSH 安全加固。
- Docker。
- swap。
- fail2ban。
- unattended-upgrades。
- 非 Ubuntu 发行版适配。

这些能力归入后续可选模块设计。

## 13. 开发验证

验证按影响范围分层执行。不要为了文档改动强制跑系统级测试，也不要在改动脚本拼接或系统行为后只做人工通读。

文档改动：

- 人工通读相关段落。
- 检查路径、命名和规则是否一致。

Go 改动：

```text
gofmt -l .
go test ./...
go vet ./...
```

构建器、runtime 拼接或生成脚本相关改动：

```text
yatta validate
yatta build
bash -n dist/yatta.sh
```

Bash 验证要求：

- 生成脚本必须通过 `bash -n dist/yatta.sh`。
- smoke test 必须覆盖启动、系统检查失败路径、prompt 阶段、执行计划展示和取消执行路径。
- Windows 本地 Bash 不作为 Ubuntu 脚本行为的可信验收环境。

集成测试环境：

- Bash 脚本真实测试默认使用 Docker Ubuntu。
- UFW、systemd、真实 SSH 防锁门行为必须在 Ubuntu VM 或 VPS 中验收。

## 14. 构建产物与发布

v1 发布产物必须包含：

- 项目源码。
- `dist/yatta.sh`。

`dist/yatta.sh` 只能由 `yatta build` 生成，不允许手写修改。发布时可以包含 `dist/yatta.sh`，但源码、模块、runtime 和 locale 必须是它的唯一来源。

普通用户入口是 `dist/yatta.sh`。高级用户入口是 Go 构建器和模块目录。

## 15. 文档、注释与计划规则

所有 plan 文档必须放在：

```text
docs/plan/*.md
```

计划文档命名必须使用短横线小写形式，例如：

```text
docs/plan/module-system.md
docs/plan/bash-runtime.md
docs/plan/default-modules.md
```

计划文档必须使用以下简洁模板：

```markdown
# <Feature Or Module Name>

## 目标

## 范围

## 文件职责与拆分原因

## 大致流程

## 实现步骤

## 验收标准

## 进度记录

## 复盘与后续
```

`DEVELOPMENT.md` 只记录项目级开发规范。功能级、模块级、实现级计划必须拆分到 `docs/plan/*.md`。

文档和源码注释必须遵守：

- Markdown 文档必须说明用途、读者、范围、关键流程和验收方式。
- 新增源码文件时，必须在文件顶部或关键类型、函数附近说明文件职责、拆分原因和主要执行流程。
- 注释用于解释意图、边界、流程或风险，不用于重复代码字面含义。
- 计划执行完后，必须在对应计划文档中更新验收结果、遗留问题和复盘。

## 16. 轻量 Git 规则

Yatta 不强制 feature 分支、PR 或复杂发布流程。Git 记录只需要服务于学习、回溯和恢复现场。

- 提交前必须完成对应影响范围的分层验证。
- 提交信息必须说明改动意图和影响范围。
- 不得把手写修改后的 `dist/yatta.sh` 作为真实来源提交。
- 如果一次提交跳过了某项验证，必须在提交说明或计划文档中写明原因。

## 17. 开发验收总则

- 新贡献者必须能够通过本文档理解 Yatta 的目标、架构、开发步骤和约束。
- 新计划必须放入 `docs/plan/*.md`。
- 新模块必须遵守 `module.yaml + prompts.sh + apply.sh` 结构。
- 新系统能力必须优先进入 runtime 或发行版适配层，不得在模块中重复散落。
- v1 默认脚本必须保持 Bash 零外部依赖。
- v1 默认脚本必须在执行前展示完整计划并等待用户确认。
- v1 默认脚本必须采用保守幂等策略。
- v1 默认脚本必须优先保护 SSH 可连接性，尤其是在启用 UFW 前。
- 每个阶段必须完成对应检查清单后，才默认进入下一阶段。
