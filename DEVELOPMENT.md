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
- 所有源码、脚本、测试夹具和生成模板中的注释必须使用中文；shebang 等机器解释器指令不属于注释，可按工具要求保留原格式。
- 可以接受阶段性不完美，但必须把 TODO、明确假设、遗留问题或后续计划写清楚。
- 新增复杂规则前，优先确认它是否真的帮助学习和维护；不能只为了显得工程化而增加负担。

## 3. v1 基础约束

- Go module path 必须使用 `github.com/CharOvO/yatta`。
- 项目版本号必须以根目录 `VERSION` 为唯一来源。
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
- 核心代码必须保留发行版适配层来承载跨模块复用、平台差异明显或高风险公共操作。模块私有的一次性流程可以在模块内直接调用系统命令，但必须保持 prompt/apply 边界、dry-run、幂等和清晰注释。

## 4. v1 目标项目结构

项目采用标准小型 Go 布局。v1 目标目录结构如下。结构调整必须先更新本文档或对应计划文档，再进入实现。

```text
yatta/
├── go.mod
├── VERSION
├── DEVELOPMENT.md
├── cmd/
│   └── yatta/
│       └── main.go
├── internal/
│   ├── cli/
│   ├── builder/
│   ├── module/
│   ├── locale/
│   ├── version/
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
- `internal/version/`：读取项目版本，并供 CLI 与构建器共用。
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

- [x] 新贡献者能够通过本文档理解项目目标、结构、开发顺序和约束。
- [x] 所有新计划都放在 `docs/plan/*.md`。
- [x] 文件命名、目录命名和文档规则保持一致。

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

- [x] `gofmt -l .` 无未格式化 Go 文件。
- [x] `go test ./...` 通过。
- [x] `go vet ./...` 通过。
- [x] `yatta validate` 能发现缺失字段、重复模块 ID、依赖缺失和冲突模块。
- [x] `yatta build` 能生成带 shebang 的 `dist/yatta.sh`。
- [x] `dist/yatta.sh` 由构建器生成，没有手写修改。

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

- [x] 生成脚本通过 `bash -n dist/yatta.sh`。
- [x] 脚本能在不执行系统变更的路径中完成交互收集和计划展示。
- [x] 非 root 运行时必须停止。
- [x] 非 Ubuntu 环境必须给出清晰提示并停止。
- [x] runtime 入口硬检查与 `system-check` 模块职责边界清晰。

阶段说明：

- Phase 2 已建立 `runtime/core`、`runtime/ui`、`runtime/system`、`runtime/adapter` 的基础 Bash 标准库。
- 当前 `system-check` 已能展示环境摘要表格并登记前置检查计划。
- `hostname`、`user`、`timezone`、`packages`、`ufw` 已在 Phase 3 实现真实交互、计划登记和 apply 阶段系统修改逻辑。
- `YATTA_TEST_MODE=1` 和 `YATTA_DRY_RUN=1` 仅用于开发验收，不属于 v1 面向普通用户的配置模式。

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

- [x] 每个模块都有完整 `module.yaml`。
- [x] 每个模块都能登记执行计划。
- [x] 每个模块重复运行时尽量保持幂等。
- [x] `user` 模块不在变量、日志或计划摘要中保存明文密码。
- [x] `ufw` 模块必须先确认 SSH 放行策略，再启用 UFW。

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
- [x] VM/VPS 中验证 UFW、systemd、真实 SSH 防锁门行为。
- [x] 发布产物包含源码和由 `yatta build` 生成的 `dist/yatta.sh`。
- [x] 发布说明能解释普通用户和高级用户分别如何使用。

## 7. Go 构建器规范

v1 Go 构建器必须标准库优先，不引入第三方 CLI 框架。CLI 命令使用手写子命令分发。

必须实现的命令：

```text
yatta build
yatta validate
yatta list-modules
yatta version
```

命令契约：

- `yatta build`：读取 runtime、modules、locale，生成 `dist/yatta.sh`。
- `yatta validate`：校验项目结构、模块字段、模块依赖、模块冲突、locale 文件和 runtime 文件。
- `yatta list-modules`：按执行顺序列出模块 ID、名称、启用状态和支持发行版。
- `yatta -v`、`yatta --version`、`yatta version`：输出当前 Yatta 版本。

后续即使迁移到 Cobra 等 CLI 框架，也不得破坏以上命令接口和默认行为。

## 8. 版本系统规范

Yatta 的版本号必须由根目录 `VERSION` 文件提供。Go CLI、构建器和生成后的 Bash 脚本都必须读取或注入同一个版本值，避免多个入口显示不一致。

版本展示规则：

- `go run ./cmd/yatta -v` 输出当前版本。
- `go run ./cmd/yatta --version` 输出当前版本。
- `go run ./cmd/yatta version` 输出当前版本。
- `yatta build` 必须把版本写入 `dist/yatta.sh` 文件头注释。
- `dist/yatta.sh` 必须包含 `YATTA_VERSION` 变量。
- `bash dist/yatta.sh --version` 直接输出版本并退出，不进入交互流程。
- Bash 品牌启动区必须展示当前框架版本。

当前版本：

```text
1.0.0
```

## 9. Bash Runtime 规范

Bash runtime 是最终脚本中的标准库。模块必须复用 runtime 的 UI、日志、执行计划、入口探测和通用安全工具。只有跨模块复用、平台差异明显或需要统一 dry-run 的系统操作才应抽到 adapter；模块私有的一次性流程可以留在模块内。

runtime 必须包含以下能力：

- UI：标题、阶段、选择器、输入框、确认框、spinner、日志。
- 系统探测：Ubuntu 版本、root 状态、Bash 版本、apt、systemd、基础网络状态。
- 执行框架：收集配置、登记计划、展示摘要、确认执行、顺序执行。
- 安全工具：文件备份、幂等写入、命令存在检查、失败处理。
- Ubuntu adapter：封装 `apt`、`ufw`、`timedatectl`、`hostnamectl`、`adduser`、`usermod`。
- 端口计划：模块可登记需要开放的端口，由防火墙模块统一展示、确认和执行。

runtime 负责脚本入口硬检查和通用能力，例如 Bash、root、Ubuntu、基础命令存在性。`system-check` 模块负责向用户展示更完整的环境摘要，并登记更细的前置检查计划。两者不得重复实现彼此的职责。

执行模型：

1. 启动脚本。
2. 检查 Bash、root、Ubuntu。
3. 加载 runtime 和模块函数。
4. 运行所有模块的 prompt 阶段。
5. 展示完整执行计划。
6. 用户确认。
7. 按模块顺序执行 pre apply 前置阶段。
8. 按模块顺序执行 main apply 主阶段。
9. 按模块顺序执行 post apply 收尾阶段。
10. 执行 runtime 登记的最终敏感操作。
11. 输出结果摘要。

三段 apply 模型用于表达“开始前准备”和“最后收尾”这类跨模块需求。例如 packages 模块可以在 pre apply 中执行 `apt update`，在 post apply 中按用户确认执行 `apt upgrade`。

最终敏感操作队列用于处理可能中断当前远程连接、但又必须等所有常规模块完成后才生效的动作，例如 SSH 端口切换后的配置写入、校验和 reload。模块不得把普通系统修改滥用为最终敏感操作；只有确实会影响脚本继续执行或远程连接稳定性的动作才应登记到该队列。

## 10. 交互与 Locale 规范

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

## 11. 模块规范

模块必须使用以下结构：

```text
modules/<module-id>/
  module.yaml
  prompts.sh
  pre_apply.sh
  apply.sh
  post_apply.sh
```

`module.yaml` v1 必须包含以下字段：

```yaml
id: hostname
name: Hostname
description: Configure system hostname
default_enabled: true
stage: system
order: 20
requires: []
before: []
after: []
conflicts: []
supports:
  distros: [ubuntu]
```

字段规则：

- `id` 必须唯一，使用短横线小写命名。
- `name` 必须是人类可读名称。
- `description` 必须描述模块效果。
- `default_enabled` 决定默认脚本是否包含该模块。
- `stage` 决定模块所属执行阶段，新模块应优先使用。
- `order` 是兼容字段，用于旧模块和同阶段内的辅助排序，不再作为主要扩展方式。
- `requires` 声明依赖模块 ID。
- `before` 声明当前模块必须早于哪些模块执行。
- `after` 声明当前模块必须晚于哪些模块执行。
- `conflicts` 声明冲突模块 ID。
- `supports.distros` 声明支持的发行版，v1 默认只允许 `ubuntu`。

`stage` 阶段规则：

- `preflight`：前置检查与环境摘要，例如 `system-check`。
- `system`：主机名、时区、swap 等本机基础设置。
- `account`：用户、sudo、SSH 公钥、无用账户清理。
- `packages`：`apt update`、基础包、包管理准备。
- `remote-access`：sshd 配置。
- `services`：Docker、Node.js、Python、Go、Nginx 等服务或运行时。
- `security`：Fail2Ban、安全巡检、Rootkit、Cron、登录分析等。
- `firewall`：UFW 与最终端口策略。
- `post`：`apt upgrade`、收尾摘要、重启提醒。

排序规则：

- 构建器先按固定 `stage` 顺序分组。
- 再根据 `requires`、`before`、`after` 做拓扑排序。
- 无关系模块按 `order` 和模块 ID 稳定排序。
- 循环依赖、缺失目标、自引用必须由 `yatta validate` 报错。
- 旧模块可以暂时只使用 `order`，但新模块应补充 `stage`。

脚本职责：

- `prompts.sh` 只允许询问用户、保存变量、登记执行计划。
- `prompts.sh` 禁止执行任何系统变更。
- `pre_apply.sh` 可选，只允许在用户确认后执行前置准备，例如 `apt update`。
- `apply.sh` 只允许在用户确认后执行真实系统变更。
- `post_apply.sh` 可选，只允许执行收尾任务，例如用户确认后的 `apt upgrade`。
- 可能影响当前远程连接并导致后续流程无法继续的动作，应在 prompt 阶段确认风险并登记 runtime 最终敏感操作，由 runtime 在所有 post apply 之后执行；apply 阶段不得依赖 TTY spinner 子进程去修改这类 runtime 队列。
- `apply.sh` 中的系统操作应优先复用已有 runtime 或 adapter。如果是模块私有、非复用的一次性流程，可以在模块内直接调用命令，但必须使用清晰的检测、幂等和 dry-run 处理。
- 模块必须按保守幂等策略实现。

端口计划规则：

- 需要开放端口的模块应调用 `yatta_port_plan_add <module> <protocol> <port> <purpose>` 登记需求。
- 第一版端口计划只支持 `tcp` 和 `udp`。
- 模块不得各自散落 UFW 操作。
- UFW 模块负责统一展示端口计划、二次确认，并在 apply 阶段统一放行。

## 12. v1 默认模块

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

必须支持检测并询问是否安装基础工具包：

```text
curl wget git vim unzip ca-certificates gnupg lsb-release
```

当用户确认安装且存在缺失包时，packages 模块必须在 pre apply 阶段通过 apt adapter 执行 `apt update`，避免模块直接散落 apt 命令。packages 模块不得安装 `ufw`，防火墙工具由 `ufw` 模块自行负责。

packages 模块可以询问是否执行 `apt upgrade`，但必须清晰提示该操作可能升级大量系统包，并且会在常规模块完成后作为 post apply 收尾任务执行；远程访问类最终敏感操作可以排在它之后。

### ufw

必须支持询问并执行以下策略：

- 是否自动安装 `ufw` 软件包。
- 启用 UFW 时固定执行 `ufw default deny incoming`，并在 prompt 阶段提前提示用户。
- 启用 UFW 时固定执行 `ufw default allow outgoing`，并在 prompt 阶段提前提示用户。
- 识别当前 sshd 配置中的 SSH 端口。
- 无法识别时默认使用 22 并提示用户确认。
- 启用 UFW 前必须放行确认后的 SSH 端口。
- 询问是否开放 HTTP/HTTPS 常用端口 80/443。
- 汇总 runtime 端口计划并二次确认。

SSH 安全加固不进入 v1 默认模块。后续 SSH 模块的执行优先级必须高于 UFW 模块。

## 13. v2 默认模块与构建配置蓝图

v2 的默认模块整改不一次性重写全部模块。正确顺序是先迭代框架，再按模块逐个商讨、计划、实现和验收。

详细计划见：

```text
docs/plan/default-modules-v2-blueprint.md
```

v2 框架方向：

- 新增根目录 `yatta.build.yaml`，作为构建模块集合的唯一权威来源。
- `validate` 必须检查构建配置文件中的 profile、模块名、重复项、冲突关系和依赖排序。
- `builder` 默认读取 `yatta.build.yaml` 中的 `basic` profile 生成 `dist/yatta.sh`。
- `basic` profile 默认编译全部内置模块。
- 生成脚本运行时先展示“本次启用模块”选择界面。
- 高风险模块可以被编译进脚本，但运行时默认不启用。
- 未启用模块必须完全跳过 prompt、pre_apply、apply、post_apply。

当前框架状态：

- `yatta.build.yaml`、profile 校验、builder 按默认 profile 拼接、运行时模块选择与未启用模块跳过机制已经落地。
- 框架迭代已经完成；具体业务模块正按计划逐个重写，当前已进入系统基础设置、`user` 和 `packages` 工作单元。
- 后续仍必须按模块逐个商讨、补充计划、实现和验收。

v2 模块元数据方向：

- `module.yaml` 不再负责决定普通构建是否包含该模块。
- `default_enabled` 的构建选择职责在 v2 中废弃。
- 新增 `runtime_default`，表示运行时是否默认勾选。
- 新增 `risk`，取值为 `low`、`medium`、`high`。
- 新增 `group`，用于运行时模块选择界面分组。
- 可选新增 `locked`，用于 `system-check` 等不可取消模块。

v2 模块重写规则：

- 当前 v1 模块在 v2 中可以直接重写，不保留 v1 兼容副本。
- 每个模块重写前必须先单独商讨，并写入对应 `docs/plan/<module>.md`。
- `hostname` 和 `timezone` 源码模块保持独立，但在用户体验中归为“系统基础设置”。
- SSH 公钥导入与 SSH 服务加固应拆开规划：前者偏账户能力，后者属于高风险远程访问加固。
- `ufw` 继续作为端口计划的统一确认和执行者。
- 模块私有、非复用的一次性实现不强制进入 runtime/adapter，避免高级开发者新增普通模块时必须修改框架。

后续可选模块方向：

- 系统基础：swap、其他本机基础信息整理。
- 账户：SSH 公钥导入、sudo 策略、无用账户处理。
- 远程访问：SSH 端口、root 登录、密码登录、密钥登录。
- 安全：Fail2Ban、安全巡检。
- 服务：Docker、Node.js、Python、Go、Nginx。

## 14. v1 禁止进入默认脚本的能力

以下能力不得进入 v1 默认脚本：

- SSH 安全加固。
- Docker。
- swap。
- fail2ban。
- unattended-upgrades。
- 非 Ubuntu 发行版适配。

这些能力归入后续可选模块设计。

## 15. 开发验证

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
yatta --version
bash -n dist/yatta.sh
```

Bash 验证要求：

- 生成脚本必须通过 `bash -n dist/yatta.sh`。
- 生成脚本必须支持 `bash dist/yatta.sh --version`。
- smoke test 必须覆盖启动、系统检查失败路径、prompt 阶段、执行计划展示和取消执行路径。
- Windows 本地 Bash 不作为 Ubuntu 脚本行为的可信验收环境。

集成测试环境：

- Bash 脚本真实测试默认使用 Docker Ubuntu。
- UFW、systemd、真实 SSH 防锁门行为必须在 Ubuntu VM 或 VPS 中验收。

## 16. 构建产物与发布

v1 发布产物必须包含：

- 项目源码。
- `dist/yatta.sh`。

`dist/yatta.sh` 只能由 `yatta build` 生成，不允许手写修改。发布时可以包含 `dist/yatta.sh`，但源码、模块、runtime 和 locale 必须是它的唯一来源。

普通用户入口是 `dist/yatta.sh`。高级用户入口是 Go 构建器和模块目录。

## 17. 文档、注释与计划规则

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
- 所有源码、脚本、测试夹具和生成模板中的注释必须使用中文；shebang 等机器解释器指令不属于注释，可按工具要求保留原格式。
- 计划执行完后，必须在对应计划文档中更新验收结果、遗留问题和复盘。

## 18. 轻量 Git 规则

Yatta 不强制 feature 分支、PR 或复杂发布流程。Git 记录只需要服务于学习、回溯和恢复现场。

- 提交前必须完成对应影响范围的分层验证。
- 提交信息必须说明改动意图和影响范围。
- 不得把手写修改后的 `dist/yatta.sh` 作为真实来源提交。
- 如果一次提交跳过了某项验证，必须在提交说明或计划文档中写明原因。
- `docs/plan/*.md` 可作为本地计划与复盘草稿保存；若仓库忽略该目录，提交时只提交对应源码、文档总则和验收结果摘要。

## 19. 开发验收总则

- 新贡献者必须能够通过本文档理解 Yatta 的目标、架构、开发步骤和约束。
- 新计划必须放入 `docs/plan/*.md`。
- 新模块必须遵守 `module.yaml + prompts.sh + apply.sh` 结构。
- 新系统能力如果会被多个模块复用、涉及平台差异或属于公共安全边界，应进入 runtime 或发行版适配层；模块私有的一次性实现可以留在模块内，避免为了单个模块强迫高级开发者修改框架。
- v1 默认脚本必须保持 Bash 零外部依赖。
- v1 默认脚本必须在执行前展示完整计划并等待用户确认。
- v1 默认脚本必须采用保守幂等策略。
- v1 默认脚本必须优先保护 SSH 可连接性，尤其是在启用 UFW 前。
- 每个阶段必须完成对应检查清单后，才默认进入下一阶段。
