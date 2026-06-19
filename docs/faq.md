# Yatta 常见问题

## Yatta 支持哪些系统？

v1 只支持 Ubuntu，并要求可用的 apt 和 systemd 环境。

## 为什么必须使用 root？

Yatta 会修改 hostname、timezone、用户、软件包和防火墙配置，这些操作都需要 root 权限。请使用：

```text
sudo bash dist/yatta.sh
```

## 脚本什么时候会真正修改系统？

只有在所有模块完成配置收集、显示完整执行计划，并且你确认执行后，脚本才会进入 apply 阶段修改系统。

## Yatta 会保存用户密码吗？

不会。`user` 模块不在变量、日志或计划摘要中保存明文密码。创建新用户时，密码由系统 `adduser` 工具交互处理。

## 为什么 UFW 要先确认 SSH 端口？

防火墙配置错误可能导致 SSH 连接中断。Yatta 会先确认 SSH 端口，并在启用 UFW 前放行该端口。

## SSH 端口是如何识别的？

Yatta 优先使用 `sshd -T` 读取 OpenSSH 的有效配置；失败时解析 `/etc/ssh/sshd_config` 和 `/etc/ssh/sshd_config.d/*.conf`。如果没有显式端口配置，会回落到 OpenSSH 默认端口 `22`。

## UFW 默认会做什么？

如果你选择启用 UFW，Yatta 会固定执行：

```text
ufw default deny incoming
ufw default allow outgoing
```

执行前会在 UFW 配置阶段提示，并在执行计划中列出。SSH 端口会在启用前放行，`80/443` 会单独询问。

## 可以安装 Docker、swap、fail2ban 吗？

v1 默认脚本不包含 Docker、swap、fail2ban、unattended-upgrades 或 SSH 安全加固。这些能力可以作为后续可选模块设计。

## 可以重复运行吗？

可以。模块按保守幂等策略实现，会尽量先检查现状，再决定是否执行变更。

## 为什么不要手写修改 dist/yatta.sh？

`dist/yatta.sh` 是 `yatta build` 生成的单文件脚本。手写修改会让产物和源码不一致。高级用户应修改 `runtime/`、`modules/` 或 `locales/` 后重新构建。
