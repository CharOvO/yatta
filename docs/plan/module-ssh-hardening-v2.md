# v2 ssh-hardening 模块

## 目标

本计划面向 v2 `ssh-hardening` 模块。模块目标是在用户显式启用高风险远程访问模块后，安全调整 OpenSSH 服务端策略：SSH 端口、root 登录、密码登录、键盘交互登录、密钥登录、空密码、认证重试次数、登录宽限时间和 X11 转发。

模块保持高风险、默认关闭。所有可能影响远程连接的变更必须先进入执行计划，并延后到所有模块和收尾任务完成后的最终敏感操作中执行；只有通过 `sshd -t` 和有效配置校验后才允许 reload SSH 服务。

## 范围

包含：
- 读取当前有效 sshd 配置并展示摘要。
- 允许保持当前端口或手动输入新端口，不提供建议端口值。
- 修改端口时登记新端口和旧端口的 UFW 端口计划；旧端口只作为临时保底放行提示。
- 提供 root 登录策略：完全禁用、仅禁止 root 密码登录、保持当前。
- 默认推荐禁用密码登录和键盘交互登录，但必须先确认有可用密钥证据。
- 默认推荐启用密钥登录、禁用空密码、限制认证次数、缩短登录宽限时间并关闭 X11 转发。
- 写入独立 sshd drop-in，校验失败时回滚并停止。

不包含：
- 不导入 SSH 公钥，公钥导入仍归 `user` 模块。
- 不直接执行 UFW 命令，只登记端口计划。
- 不处理 `AllowUsers`、`AllowGroups`、`AllowTcpForwarding`、`AllowAgentForwarding`、`PermitTunnel`、`ClientAliveInterval` 等高级策略。
- 不自动清理旧端口；旧端口只作为 UFW 临时放行计划提示。

## 文件职责与拆分原因

- `modules/ssh-hardening/prompts.sh` 负责读取当前 SSH 配置、确认目标用户和密钥证据、询问策略、登记计划，并在主进程登记最终敏感操作。
- `modules/ssh-hardening/apply.sh` 负责提示 SSH 加固已经延后；不写入 sshd 配置，不 reload 服务。
- `runtime/core` 提供最终敏感操作队列，确保 SSH 生效动作排在所有模块 main apply、post apply 和 `apt upgrade` 之后。
- `runtime/system/checks.sh` 提供 sshd 有效值读取、目标用户 `authorized_keys` 检测和 test mode 模拟。
- `runtime/adapter/ubuntu.sh` 提供 drop-in 写入、`sshd -t` 校验、有效值校验、失败回滚和 SSH 服务 reload。

这样拆分可以把高风险系统动作集中在 adapter 中，模块脚本只表达业务流程和风险闸门。

## 大致流程

1. prompt 阶段读取当前 SSH 端口和关键 sshd 有效配置。
2. 优先使用 `user` 模块目标用户作为安全闸门用户；否则允许选择已有普通 sudo 用户。
3. 检查目标用户是否具备密钥证据：本轮 `user` 模块导入公钥，或已有有效 `authorized_keys`。
4. 询问端口策略：保持当前或手动输入新端口。
5. 询问 root 登录、密码/键盘交互登录、密钥登录和其他基础加固项。
6. 若缺少密钥证据，阻止禁用密码登录和完全禁用 root 登录。
7. prompt 阶段在主进程登记最终敏感操作，避免 TTY spinner 子进程丢失状态。
8. apply 阶段不写 sshd 配置，只提示已经延后，避免后续 `apt upgrade` 提前触发新配置。
9. 所有模块 main apply 和 post apply 完成后，最终敏感操作写入 `/etc/ssh/sshd_config.d/00-yatta-hardening.conf`。
10. 执行 `sshd -t`；失败时回滚，不 reload。
11. 使用 `sshd -T` 校验目标值是否生效；失败时回滚，不 reload。
12. 校验通过后 reload SSH 服务，不 restart；如果修改端口，当前连接可能断开，用户应使用新端口重新连接。

## 实现步骤

- 新增 `ssh-hardening` 模块元数据，标记为 `remote-access`、高风险、运行时默认关闭，并声明早于 `ufw`、晚于 `user`。
- 新增 prompt 流程，覆盖端口、目标用户、密钥证据和基础加固策略。
- 新增 runtime 最终敏感操作队列，排在所有 post apply 之后执行。
- 新增 prompt 阶段最终操作登记；最终操作生成独立 drop-in，并把校验、回滚和 reload 委托给 adapter。
- 调整 apply 流程，只提示 SSH 加固已延后，不在 spinner 子进程中修改 runtime 队列。
- 补充 runtime/system 的 sshd 有效配置和用户密钥检测函数。
- 补充 runtime/adapter 的 sshd drop-in 安全写入函数。
- 重新构建生成脚本。

## 验收标准

- `ssh-hardening` 未启用时完全跳过 prompt 和 apply。
- 端口不提供建议值；用户只能保持当前或手动输入。
- 修改端口后，端口计划包含新端口和旧端口，且明确提示旧端口只是 UFW 临时放行。
- 无密钥证据时，不允许禁用密码登录或完全禁用 root 登录。
- 有本轮导入公钥或已有 `authorized_keys` 时，允许禁用密码登录。
- main apply 阶段不写入 sshd drop-in、不 reload SSH 服务。
- 最终敏感操作排在 packages 的 `apt upgrade` 之后。
- `sshd -t` 失败时回滚 drop-in 且不 reload。
- `sshd -T` 有效值校验失败时回滚 drop-in 且不 reload。
- reload 使用 reload，不使用 restart。
- `go run ./cmd/yatta validate`、`go run ./cmd/yatta build` 和 `bash -n dist/yatta.sh` 通过。

## 进度记录

- 已确认第一版只做基础 SSH 加固，不进入高级访问控制和转发策略。
- 已确认端口不提供建议值。
- 已确认禁用密码登录和完全禁用 root 登录必须具备密钥证据。
- 已确认修改端口时 sshd 只监听新端口，旧端口仅登记为 UFW 临时保底放行。
- 已确认 SSH 配置写入、校验和 reload 延后为最终敏感操作，排在 `apt upgrade` 和全部 post apply 之后，避免端口切换中断后续流程。

## 复盘与后续

- 后续如需支持 `AllowUsers`、`AllowGroups` 或 SSH 转发策略，应单独规划高级模式和锁门风险提示。
- 后续如需自动清理旧端口，应由 `ssh-hardening` 与 `ufw` 的端口计划机制进一步协作，而不是在第一版隐式删除。
