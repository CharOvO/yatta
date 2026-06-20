# Smoke Test 与验收说明

本文记录 Yatta v1 发布前的基础验证方式和当前验收状态。

## 本地构建验证

Go 侧验证：

```text
gofmt -l .
go test ./...
go vet ./...
go run ./cmd/yatta validate
go run ./cmd/yatta list-modules
go run ./cmd/yatta build
```

Bash 语法验证：

```text
bash -n dist/yatta.sh
```

Windows 本地如果默认 `bash` 指向未配置发行版的 WSL stub，可以使用 Git Bash 的明确路径完成语法检查。

## 非破坏性流程验证

开发环境可以使用隐藏变量验证配置收集、计划展示、取消或 dry-run apply 路径：

```text
YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 bash dist/yatta.sh
```

v2 框架增加运行时模块选择后，可以用 `YATTA_TEST_MODULES` 限定本次启用模块，验证未启用模块会完全跳过 prompt、pre apply、apply 和 post apply：

```text
YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 YATTA_TEST_MODULES=system-check bash dist/yatta.sh
```

该模式只用于开发验收，不属于普通用户功能。

Git Bash 验证多行输入分支时，可以通过隐藏变量提供测试公钥：

```text
YATTA_TEST_MODE=1 YATTA_DRY_RUN=1 YATTA_TEST_MODULES=user YATTA_TEST_MULTILINE_INPUT="ssh-ed25519 AAAA... user@example" bash dist/yatta.sh
```

## 真实服务器验收记录

当前 Phase 4 已在真实 Ubuntu 服务器上运行 `dist/yatta.sh`，用户反馈流程可以正常使用。

已覆盖的真实路径：

- root/Ubuntu/systemd/apt 前置检查。
- 默认模块配置收集。
- 执行计划展示与确认。
- hostname、timezone、user、packages、ufw 默认模块流程。

仍建议后续补充：

- Docker Ubuntu 中的基础非破坏性验证记录。
- VM/VPS 中 UFW 与真实 SSH 防锁门专项记录。

## 发布产物要求

发布时应包含：

- 项目源码。
- 由 `go run ./cmd/yatta build` 生成的 `dist/yatta.sh`。
- 面向普通用户的使用说明。
- 面向高级用户和开发者的模块开发说明。
