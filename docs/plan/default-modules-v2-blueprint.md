# v2 默认模块与构建配置蓝图

## 目标

规划 Yatta v2 的默认模块重构路线：先迭代框架能力，再逐个模块商讨、设计、实现和验收。

v2 不保留 v1 模块兼容副本。当前 v1 模块会在进入对应模块工作单元时直接重写，但每个模块都必须先有单独计划，不一次性把全部模块改完。

## 范围

包含：

- 构建模块集合改为通过根目录构建配置文件控制。
- `validate` 检查构建配置文件内引用的模块名是否存在、重复、冲突或破坏依赖关系。
- `builder` 根据构建配置文件选择要拼接进 `dist/yatta.sh` 的模块。
- runtime 增加“本次启用模块”选择流程。
- v2 模块按阶段分组展示，并支持风险等级和默认勾选状态。
- 后续模块按独立计划逐个重写。

不包含：

- 本计划初始阶段不直接重写具体业务模块。
- 不在同一个工作单元内重写所有默认模块。
- 不把 SSH hardening、swap、fail2ban、Docker 等能力倒回 v1 默认流程。

## 文件职责与拆分原因

`yatta.build.yaml` 作为 v2 构建模块集合的唯一权威来源。它描述 profile、默认 profile、包含模块和排除模块。

`modules/*/module.yaml` 只描述模块自身属性，例如 id、name、stage、依赖、冲突、运行时默认状态、风险等级和展示分组，不再决定普通构建是否包含该模块。

`internal/validate` 负责同时校验模块元数据和构建配置文件，确保 profile 中所有模块名都真实存在并且关系合法。

`internal/builder` 只读取已通过校验的默认 profile，并按模块排序结果拼接生成脚本。

`runtime/core` 负责在 preflight 后、prompt 前展示运行时模块选择，并让未启用模块完全跳过 prompt、pre_apply、apply、post_apply。

## 大致流程

v2 先做框架迭代：

1. 新增 `yatta.build.yaml` 设计与校验。
2. 让 builder 使用默认 profile 选择编译模块。
3. 扩展模块元数据，加入运行时默认状态、风险等级和展示分组。
4. 在生成脚本中增加运行时模块选择界面。
5. 验证未启用模块不会执行任何阶段函数。

框架稳定后，再按模块逐个商讨：

1. 先讨论模块目标、风险、默认状态和交互流程。
2. 写入对应 `docs/plan/<module>.md`。
3. 实现该模块。
4. 单独验收并回填计划文档。
5. 再进入下一个模块。

## 实现步骤

第一阶段：构建配置框架。

- 新增 `yatta.build.yaml` 草案。
- 默认 profile 使用 `basic`。
- `basic` 编译全部内置模块。
- 支持 `include: ["*"]` 表示包含所有 `modules/` 下的模块。
- `exclude` 可从 profile 中移除指定模块。
- `validate` 检查 profile 引用的模块名必须存在。
- `validate` 检查 profile 内不允许重复模块。
- `validate` 检查 profile 不允许同时包含互相冲突的模块。
- `validate` 检查 profile 选中模块必须满足 `requires`、`before`、`after`。

第二阶段：模块元数据重构。

- 废弃 `default_enabled` 的构建选择职责。
- 新增 `runtime_default`，表示生成脚本运行时是否默认勾选。
- 新增 `risk`，取值为 `low`、`medium`、`high`。
- 新增 `group`，用于运行时模块选择界面分组。
- 可选新增 `locked`，用于 `system-check` 这类不可取消模块。

第三阶段：运行时选择框架。

- preflight 通过后注册已编译模块。
- prompt 前展示“本次启用模块”界面。
- 模块按阶段/分组展示。
- `runtime_default: true` 默认勾选。
- `risk: high` 默认不勾选，并显示高风险提示。
- 未勾选模块完全跳过所有阶段函数。

第四阶段：逐个模块重写。

- v2 直接重写现有 v1 模块源码，不复制 v1 目录。
- `hostname` 和 `timezone` 保持独立源码模块，但在 UI 中归为“系统基础设置”。
- `user` 作为完整账户初始化模块，覆盖创建/确认 sudo 用户、sudo 免密、公钥导入和多余用户清理询问。
- `packages` 重新讨论基础包、可选包清单和 profile 关系。
- `ufw` 继续作为端口计划统一执行者。
- 模块私有、非复用的一次性实现不强制进入 runtime/adapter，避免高级开发者新增普通模块时必须修改框架。
- SSH hardening、swap、fail2ban、Docker、Node.js、Python、Go、Nginx 等作为后续可选模块逐个规划。

## v2 模块重构总览

v2 默认采用保守基线：低风险和必要的中风险基础模块默认启用，高风险模块和服务类模块默认关闭。构建是否包含模块只由 `yatta.build.yaml` 决定；`runtime_default` 只表示模块被编译进脚本后，运行时是否默认勾选。

高风险模块即使未来误设为 `runtime_default: true`，runtime 也应默认关闭；当前模块元数据应直接把高风险模块设置为 `runtime_default: false`，避免给用户造成“默认安全”的错觉。

| 模块 ID | UI 分组 | stage | risk | runtime_default | locked | 职责 | 规划状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `system-check` | `preflight` | `preflight` | `low` | `true` | `true` | 展示环境摘要并登记前置检查计划 | 现有模块细化 |
| `hostname` | `system-basics` | `system` | `low` | `true` | `false` | 保留或设置主机名 | 现有模块细化 |
| `timezone` | `system-basics` | `system` | `low` | `true` | `false` | 设置、修改或跳过时区 | 现有模块细化 |
| `swap` | `system-basics` | `system` | `medium` | `true` | `false` | 检测并可选创建 swap | 新增详细规划 |
| `user` | `account` | `account` | `medium` | `true` | `false` | 创建 sudo 用户、sudo 免密、公钥导入、多余用户清理询问 | 现有模块细化 |
| `packages` | `packages` | `packages` | `medium` | `true` | `false` | 基础包、apt update、可选 apt upgrade | 现有模块细化 |
| `ssh-hardening` | `remote-access` | `remote-access` | `high` | `false` | `false` | 调整 SSH 服务安全策略 | 新增候选规格 |
| `docker` | `services` | `services` | `medium` | `false` | `false` | 安装 Docker 运行环境 | 新增候选规格 |
| `nodejs` | `services` | `services` | `medium` | `false` | `false` | 安装 Node.js 运行环境 | 新增候选规格 |
| `python` | `services` | `services` | `medium` | `false` | `false` | 安装 Python 开发/运行环境 | 新增候选规格 |
| `go` | `services` | `services` | `medium` | `false` | `false` | 安装 Go 开发/运行环境 | 新增候选规格 |
| `nginx` | `services` | `services` | `high` | `false` | `false` | 安装并准备 Nginx 服务入口 | 新增候选规格 |
| `fail2ban` | `security` | `security` | `medium` | `false` | `false` | 提供基础 SSH 防爆破保护 | 新增候选规格 |
| `ufw` | `firewall` | `firewall` | `high` | `false` | `false` | 统一确认并执行端口计划 | 现有模块细化 |

默认启用集合为 `system-check`、`hostname`、`timezone`、`swap`、`user`、`packages`。其中 `swap` 只有在模块实现后才进入默认启用集合。默认关闭集合为 `ufw`、`ssh-hardening`、`fail2ban` 和全部 `services` 模块。不可取消模块仅允许 `system-check`。

## 分模块规格

### system-check

目标：

- 继续作为 locked 的前置模块，负责把当前环境状态展示给用户。
- 只登记比 runtime 硬检查更完整的前置检查计划。
- 保持低风险、默认启用、不可取消。

边界：

- runtime 负责 Bash、root、Ubuntu、apt、systemd 等硬阻断。
- `system-check` 不重复实现硬阻断逻辑，只复用 runtime/system 探测函数。
- 网络检查失败只登记风险，是否阻断由后续依赖网络的模块自行处理。

交互与执行：

- prompt 阶段展示 Ubuntu、root、Bash、apt、systemd、network 摘要。
- apply 阶段做执行前最终检查，并输出网络风险提示。
- 不写入系统文件，不安装软件包。

验收：

- 非 Ubuntu、非 root、缺少 apt/systemd 时仍由 runtime 阻断。
- 在 `YATTA_TEST_MODE=1` 下可以稳定输出环境摘要。
- locked 模块不能在运行时模块选择界面被取消。

### 系统基础设置：hostname、timezone、swap

`hostname`、`timezone`、`swap` 在用户体验中归为“系统基础设置”，但源码模块保持独立。这样用户看到的是一个连续的本机基础配置区，源码上仍能让每个模块保持清晰边界和独立验收。

#### hostname

目标：

- 支持保留当前主机名。
- 支持设置新的主机名。
- 保持低风险、默认启用。

边界：

- 只处理系统 hostname，不处理 `/etc/hosts` 扩展映射策略。
- 主机名校验使用 runtime/system 的规则。
- apply 阶段只通过 adapter 调用 `hostnamectl`。

交互与执行：

- prompt 阶段读取当前主机名，询问保留或修改。
- 用户输入非法主机名时循环提示，不进入 apply。
- apply 阶段重新读取当前值，已满足时直接跳过。

验收：

- 保留当前主机名时不执行系统修改。
- 目标值等于当前值时登记 ok 计划并跳过 `hostnamectl`。
- 非法主机名不会进入执行计划。

#### timezone

目标：

- 默认建议 `Asia/Shanghai`。
- 支持输入其他 IANA 时区。
- 支持跳过时区设置。
- 保持低风险、默认启用。

边界：

- 只处理系统时区，不处理 NTP、chrony 或时间同步策略。
- 时区可用性校验优先复用 `/usr/share/zoneinfo` 或 `timedatectl list-timezones`。
- apply 阶段只通过 adapter 调用 `timedatectl`。

交互与执行：

- prompt 阶段读取当前时区，提供默认、手动输入、跳过三种路径。
- apply 阶段重新检查目标时区是否可用。
- 当前值已满足时不执行修改。

验收：

- 默认路径能登记 `Asia/Shanghai` 计划。
- 跳过路径不会执行 `timedatectl`。
- 不存在的时区不能进入执行计划。

#### swap

目标：

- 检测当前 swap 状态，并给出是否需要创建 swap 的建议。
- 支持跳过、使用推荐大小、输入自定义大小。
- 采用中风险、默认启用候选；实现前不进入实际模块集合。

边界：

- 只规划单个 swapfile，不处理 swap 分区、zram、云厂商特殊 swap 策略。
- 不自动移除已有 swap。
- 不在 prompt 阶段写文件或修改 `/etc/fstab`。

交互与执行：

- prompt 阶段读取内存大小、已有 swap、根分区可用空间。
- 已有 swap 时默认跳过，只登记当前状态。
- 无 swap 时建议保守大小，并允许用户跳过或自定义。
- apply 阶段创建 swapfile、设置权限、格式化、启用，并幂等写入 `/etc/fstab`。

验收：

- 已有 swap 时不会重复创建。
- 磁盘空间不足时给出清晰原因并停止该模块。
- dry-run 下能展示将创建的路径、大小和 fstab 变更。

### user

目标：

- 创建或确认一个非 root sudo 用户。
- 已存在用户可补充加入 sudo 组。
- 询问是否为该用户设置 sudo 免密。
- 询问是否向该用户导入 SSH 公钥。
- 询问是否删除多余的普通用户(选择的形式)。
- 保持中风险、默认启用。

边界：

- 不保存、不打印、不登记明文密码。
- 密码交给系统 `adduser` 交互处理。
- SSH 公钥导入只维护目标用户的 `~/.ssh/authorized_keys`，不修改 sshd 配置。
- sudo 免密只为目标用户写入独立 sudoers drop-in，不直接改 `/etc/sudoers` 主文件。
- 删除多余用户只处理人工确认的普通用户，不自动删除 root、目标用户、当前 sudo 来源用户和系统账户。
- SSH 服务端口、root 登录、密码登录、密钥登录策略仍归 `ssh-hardening`。

交互与执行：

- prompt 阶段询问是否创建或确认 sudo 用户。
- 用户名必须符合 Ubuntu 本地用户命名规则。
- prompt 阶段询问是否设置 sudo 免密；默认不强制开启，用户确认后登记计划。
- prompt 阶段询问是否导入 SSH 公钥；支持粘贴单个或多个公钥，重复公钥不重复写入。
- prompt 阶段列出可疑普通用户，询问是否删除多余用户；删除操作必须逐个确认，默认不删除。
- apply 阶段调用 adapter 创建用户或确保 sudo 组成员关系。
- apply 阶段按确认结果写入 sudoers drop-in，并用 `visudo -cf` 或等价 adapter 校验后生效。
- apply 阶段创建 `.ssh` 目录、设置权限、幂等追加公钥到 `authorized_keys`。
- apply 阶段删除用户前二次校验保护名单，默认保留用户 home，除非后续单独计划明确支持删除 home。

验收：

- 跳过用户创建时计划明确提示风险。
- 已存在且已在 sudo 组时不重复修改。
- 用户名为 `root` 或非法格式时不能进入执行。
- 重复执行不会重复写入相同公钥。
- 文件和目录权限符合 SSH 常规要求。
- sudoers drop-in 校验失败时不得写入或启用免密配置。
- 多余用户删除必须逐个确认，且保护名单用户永远不能被删除。

### packages

目标：

- 检测并可选安装基础工具包。
- 统一执行需要的 `apt update`。
- 可选把 `apt upgrade` 放到 post apply 收尾阶段。
- 保持中风险、默认启用。

边界：

- 基础包清单保持保守，不包含 `ufw`。
- 服务类依赖包由对应服务模块自己规划。
- 不决定服务运行时版本，不引入第三方包源策略。

交互与执行：

- prompt 阶段检测缺失基础包并询问是否安装。
- 用户确认安装或确认 upgrade 时，pre apply 执行 `apt update`。
- apply 阶段重新计算缺失包并安装。
- post apply 阶段仅在用户明确确认后执行 `apt upgrade`。

验收：

- 无缺失包时不执行安装。
- 用户拒绝安装时只登记 warn 计划。
- `apt upgrade` 必须清晰提示可能升级大量系统包。

### ssh-hardening

目标：

- 管理 SSH 服务高风险安全选项。
- 支持规划 SSH 端口、root 登录、密码登录、密钥登录等策略。
- 采用高风险、默认关闭。

边界：

- 不导入用户公钥，公钥归 `user` 模块的账户初始化流程。
- 不直接操作防火墙，只登记 SSH 端口计划。
- 修改 sshd 配置前必须备份文件。

交互与执行：

- prompt 阶段读取当前有效 sshd 配置。
- 所有可能影响远程连接的变更必须明确展示风险。
- 如果修改 SSH 端口，必须调用端口计划登记新端口。
- prompt 阶段在主进程登记最终敏感操作；最终操作在所有模块和收尾任务完成后写入独立 drop-in 配置，校验 sshd 配置后重载服务。

验收：

- main apply 阶段不写入 sshd 配置，避免 `apt upgrade` 或服务变更提前应用新端口。
- 配置校验失败时不重载 sshd。
- 修改端口后 UFW 模块能看到端口计划。
- 禁用密码登录前必须提示确认已有可用密钥路径。

### 服务类模块：docker、nodejs、python、go、nginx

服务类模块本轮只写候选规格，不决定 apt、官方仓库、版本管理器或安装源。进入实现前，每个服务模块必须单独补充计划。

共同规则：

- 默认关闭，用户按需启用。
- 不在 prompt 阶段安装软件或启动服务。
- 需要开放端口时只登记端口计划。
- 安装源、版本选择和升级策略必须在对应模块计划中单独确认。

候选规格：

- `docker`：安装容器运行环境，可选把目标用户加入 docker 组；不默认启动业务容器。
- `nodejs`：安装 Node.js 运行环境；暂不决定 apt、NodeSource、nvm 或其他安装源。
- `python`：安装 Python 开发/运行环境；默认关注系统 Python、venv、pip 基础能力，不替换系统 Python。
- `go`：安装 Go 开发/运行环境；暂不决定系统包或官方 tarball。
- `nginx`：安装并准备 Nginx 服务入口；属于高风险服务模块，若开放 80/443 必须登记端口计划。

验收：

- 未启用时完全跳过 prompt、pre_apply、apply、post_apply。
- dry-run 能展示安装目标和可能的端口计划。
- 启用后不会隐式修改 UFW。

### fail2ban

目标：

- 提供基础 SSH 防爆破保护。
- 采用中风险、默认关闭。
- 依赖 `packages` 或自行确保所需包安装前置。

边界：

- 第一版只规划 SSH jail。
- 不处理复杂通知、邮件、集中日志或自定义业务 jail。
- 不替代 `ssh-hardening`。

交互与执行：

- prompt 阶段展示当前 SSH 端口和基础 jail 策略。
- apply 阶段安装 fail2ban，写入本项目管理的 jail 配置，并启用服务。
- 配置写入前必须备份可能覆盖的文件。

验收：

- SSH 端口变化时 jail 配置使用最新确认端口。
- 配置语法或服务启动失败时给出明确日志。
- 重复运行不重复写入相同配置块。

### ufw

目标：

- 继续作为防火墙和端口计划的统一确认、执行者。
- 采用高风险、默认关闭。
- 启用前必须保护 SSH 连接。

边界：

- 其他模块不得直接执行 UFW 命令。
- `ufw` 可以安装 `ufw` 软件包，但 `packages` 不负责安装它。
- SSH 服务加固不归 `ufw`，只消费 SSH 端口计划。

交互与执行：

- prompt 阶段识别当前 SSH 端口，无法识别时默认 22 并要求确认。
- 启用 UFW 前固定展示 `deny incoming` 和 `allow outgoing` 策略。
- 汇总所有端口计划并二次确认。
- apply 阶段先安装或确认 `ufw`，再设置默认策略，先放行 SSH，最后启用 UFW。

验收：

- 未确认 SSH 端口时不得启用 UFW。
- 未确认端口计划时跳过 UFW 配置。
- 启用 UFW 前必须放行确认后的 SSH 端口。

## 验收标准

文档阶段：

- `DEVELOPMENT.md` 明确 v2 先做框架迭代，再逐个模块计划和实现。
- 本计划明确 `yatta.build.yaml` 是构建模块集合的唯一权威。
- 本计划明确 v2 模块源码可直接重写，不保留 v1 兼容副本。
- 本计划包含 v2 模块矩阵、默认启用策略、分组策略和分模块边界。

后续实现阶段：

- `gofmt -l .` 无输出。
- `go test ./...` 通过。
- `go vet ./...` 通过。
- `go run ./cmd/yatta validate` 通过。
- 非法 profile 能被 validate 拦截。
- `go run ./cmd/yatta build` 使用默认 profile 生成脚本。
- `bash -n dist/yatta.sh` 通过。
- `YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 bash dist/yatta.sh` 能覆盖模块选择流程。
- 未启用模块不会执行 prompt、pre_apply、apply、post_apply。

## 进度记录

- 已确认 v2 不立即进入代码重构。
- 已确认当前工作只补充计划文档和开发文档。
- 已确认 v2 路线为：先框架迭代，再逐个模块商讨和实现。
- 已确认构建包含模块应通过文件实现，而不是主要依赖命令行参数。
- 已确认 `validate` 需要检查构建配置文件中所有模块名是否存在和正确。
- 已确认 `basic` profile 默认编译全部内置模块。
- 已确认高风险模块可以被编译进脚本，但运行时默认不启用。
- 已确认 v2 可以直接重写当前 v1 模块源码。
- 已新增根目录 `yatta.build.yaml`，默认 profile 为 `basic`，并使用 `include: ["*"]` 编译全部内置模块。
- 已新增 `internal/buildconfig`，负责读取和展开构建 profile。
- 已让 `builder` 使用默认 profile 选择拼接进 `dist/yatta.sh` 的模块，不再依赖 `default_enabled` 决定构建集合。
- 已扩展 `module.yaml` 元数据：`runtime_default`、`risk`、`group`、可选 `locked`。
- 已让 `validate` 校验 profile 引用、重复项、缺失模块、冲突关系、`requires`、`before`、`after` 和模块排序。
- 已在 runtime 中加入“本次启用模块”选择流程；未启用模块会跳过 prompt、pre_apply、apply、post_apply。
- 已把 `system-check` 标记为 locked，把 `ufw` 标记为 high risk 且运行时默认不启用。
- 已重新生成 `dist/yatta.sh`。
- 已完成框架验收：`gofmt -l .` 无输出，`go test ./...`、`go vet ./...`、`go run ./cmd/yatta validate`、`go run ./cmd/yatta build`、`bash -n dist/yatta.sh` 均通过。
- 已用 `YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 YATTA_TEST_MODULES=system-check bash dist/yatta.sh` 验证未启用模块会跳过所有阶段。
- 已补充 v2 模块矩阵与分模块规格，确认保守基线默认启用、账户初始化能力归入 `user`、SSH hardening 独立为高风险远程访问模块、服务类模块默认关闭且暂不决定安装源细节。
- 已进入首批业务模块重构：新增 `docs/plan/module-system-basics-v2.md`、`docs/plan/module-user-v2.md`、`docs/plan/module-packages-v2.md`。
- 已新增 `swap` 模块并归入 `system-basics` 组；`hostname`、`timezone` 继续保持独立模块。
- 已扩展 `user` 模块，覆盖 sudo 免密、SSH 公钥导入和多余普通用户清理的保守交互路径。
- 已复核 `packages` 模块的 pre/apply/post 拆分，保持基础包清单保守且不接管服务依赖。
- 已新增 `docs/plan/module-ssh-hardening-v2.md`，确认第一版 SSH 加固只覆盖基础 sshd 策略；端口不提供建议值，禁用密码登录与完全禁用 root 登录必须具备密钥证据，修改端口时旧端口仅登记为 UFW 临时保底放行。
- 已调整 SSH 加固生效时机：prompt 在主进程登记最终敏感操作，main apply 不写配置，写入 drop-in、校验和 reload 排在 `apt upgrade` 与全部 post apply 之后，降低端口切换中断后续流程的风险。

## 复盘与后续

“v2 构建配置与运行时模块选择框架”工作单元已完成。首批业务模块已经开始按独立计划落地，当前覆盖系统基础设置、账户初始化和基础软件包。

下一步继续按模块逐个进入计划和实现，优先顺序建议为 SSH hardening、UFW、安全与服务类候选模块。涉及远程连接或删除数据的能力仍必须单独确认风险边界。
