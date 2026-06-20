# v2 user 模块

## 目标

本计划面向 v2 `user` 模块重构。模块目标是创建或确认一个非 root sudo 用户，并把账户初始化常见能力集中到同一流程：sudo 组成员关系、可选 sudo 免密、可选 SSH 公钥导入和可选多余普通用户清理。

模块保持中风险、默认启用。所有可能破坏访问路径或删除账户的操作必须默认关闭，并在执行前进入完整计划。

## 范围

包含：

- 创建或确认非 root sudo 用户。
- 已存在用户可补充加入 sudo 组。
- 可选写入目标用户专属 sudoers drop-in，实现 sudo 免密。
- 可选向目标用户 `authorized_keys` 幂等追加 SSH 公钥。
- 可选逐个确认删除多余普通用户，默认保留 home。

不包含：

- 不保存、不打印、不登记明文密码。
- 不修改 sshd 配置。
- 不调整 SSH 端口、root 登录、密码登录或密钥登录策略。
- 不自动删除 root、目标用户、当前 sudo 来源用户或系统账户。
- 本轮不支持删除用户 home。

## 文件职责与拆分原因

- `modules/user/prompts.sh` 负责询问目标用户、sudo 免密、公钥导入和用户清理选择。
- `modules/user/apply.sh` 负责在确认后调用 adapter 执行系统修改。
- `runtime/system/checks.sh` 提供用户名、公钥、普通用户列表和保护名单判断。
- `runtime/adapter/ubuntu.sh` 封装 `adduser`、`usermod`、sudoers drop-in、`authorized_keys` 和用户删除命令。

这样可以保持模块脚本只表达业务流程，把容易复用或需要 dry-run 的系统动作集中到 adapter。

## 大致流程

1. prompt 阶段询问是否创建或确认 sudo 用户。
2. 如果启用，校验用户名并登记用户创建或 sudo 组计划。
3. 询问是否设置 sudo 免密，默认否。
4. 询问是否导入 SSH 公钥，默认否；接受多行粘贴并过滤非法或重复公钥。
5. 列出候选普通用户，询问是否逐个确认删除，默认否。
6. apply 阶段重新校验并按顺序执行：用户与 sudo 组、sudoers、公钥、用户删除。

## 实现步骤

- 重写 `modules/user/prompts.sh`，增加 sudo 免密、公钥导入和多余用户清理计划。
- 重写 `modules/user/apply.sh`，按确认结果调用 adapter。
- 新增或补充账户相关 runtime/system 与 adapter 函数。
- 重新构建生成脚本。

## 验收标准

- 用户名为 `root` 或非法格式时不能进入执行。
- 已存在且已在 sudo 组时不重复修改。
- 不在变量、日志或执行计划里保存明文密码。
- sudoers drop-in 校验失败时不得启用免密配置。
- 重复执行不会重复写入相同 SSH 公钥。
- 多余用户删除必须逐个确认，保护名单用户不能删除。
- dry-run 下所有系统修改仅输出命令或计划，不真实写入。

## 进度记录

- 已根据 v2 蓝图确认 SSH 公钥导入属于 `user`，SSH 服务加固仍独立为高风险模块。
- 已扩展 prompt 流程：sudo 免密、公钥导入和多余普通用户清理均默认关闭并进入计划。
- 已扩展 apply 流程：sudoers drop-in、`authorized_keys` 和用户删除都通过 adapter 执行。
- 已用 dry-run 覆盖默认路径和增强路径，计划摘要不会打印 SSH 公钥正文。

## 复盘与后续

- 本轮删除用户默认保留 home，且只删除逐个确认的普通用户。
- 后续如果要支持删除 home 或迁移 home，应先单独规划风险提示和备份策略。
