# Yatta 用户使用指南

本文面向只想初始化 Ubuntu 服务器的普通用户。你不需要理解 Go 构建器或模块开发流程，只需要运行生成好的 `dist/yatta.sh`。

## 使用前准备

Yatta v1 只支持 Ubuntu，并要求使用 root 权限运行。

推荐命令：

```text
sudo bash dist/yatta.sh
```

如果不是 root，脚本会停止并提示使用 `sudo bash yatta.sh`。如果不是 Ubuntu 或缺少 systemd/apt，脚本也会停止。

## 基本流程

1. 显示启动信息。
2. 检查 Bash、root、Ubuntu、apt、systemd 和基础网络状态。
3. 选择本次要启用的模块。
4. 逐个启用模块收集配置。
5. 展示完整执行计划。
6. 等待你确认。
7. 只有确认后才修改系统。
8. 输出执行结果摘要。

## 默认模块

### system-check

展示当前环境摘要，并把检查结果写入执行计划。

### hostname

可以保留当前主机名，也可以输入新的 hostname。脚本会校验 hostname 格式，真正修改时通过 `hostnamectl` 执行。

### timezone

默认建议 `Asia/Shanghai`。你也可以输入其他 IANA 时区名称，或者跳过时区设置。

### swap

未检测到 swap 时，Yatta 会根据内存给出保守建议大小，并询问是否创建单个 `/swapfile`。已有 swap 时默认跳过，不会删除或替换已有策略。

### user

用于创建或确认一个非 root sudo 用户。Yatta 不会保存明文密码；新用户密码由系统 `adduser` 工具在执行阶段交互处理。

你也可以按需启用：

- sudo 免密：写入目标用户专属 sudoers drop-in，写入前会做校验。
- SSH 公钥导入：只追加到目标用户的 `authorized_keys`，不修改 sshd 配置。
- 多余普通用户清理：逐个确认删除，默认保留 home，并保护 root、目标用户和当前 sudo 来源用户。

### packages

检测以下基础软件包是否缺失，并询问是否安装：

```text
curl wget git vim unzip ca-certificates gnupg lsb-release
```

`ufw` 不属于 packages 模块，由 UFW 模块自行处理。

### ufw

UFW 是防火墙收尾模块。它会先确认 SSH 端口，启用前提示固定默认策略：

```text
ufw default deny incoming
ufw default allow outgoing
```

启用 UFW 前，脚本会先放行确认后的 SSH 端口。你也可以选择是否开放 HTTP/HTTPS 常用端口 `80/443`。

## 安全提示

- 执行计划出现后，请仔细确认再输入 `y`。
- 如果你通过 SSH 连接服务器，确认 SSH 端口非常重要。
- UFW 模块会优先保护 SSH 可连接性，但真实防锁门行为仍建议在 VM/VPS 中验证。
- 不要手写修改 `dist/yatta.sh`，它是由构建器生成的产物。
