# Yatta

![yatta](https://socialify.git.ci/CharOvO/yatta/image?custom_language=Go&description=1&font=JetBrains+Mono&forks=1&issues=1&language=1&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Light)

Yatta 是一个面向 Ubuntu 服务器的初始化工具。它把一台新的 Ubuntu 服务器整理成适合日常使用的基础状态，并在真正修改系统前展示完整执行计划。

当前项目已完成 v1 默认流程，并已在真实 Ubuntu 服务器上完成一次可用性验收。

## 普通用户

如果你只想初始化一台 Ubuntu 服务器，通常只需要运行生成好的脚本：

```text
sudo bash dist/yatta.sh
```

查看生成脚本版本：

```text
bash dist/yatta.sh --version
```

脚本会依次检查环境、收集配置、展示执行计划，并在你确认后才开始修改系统。v1 默认包含：

- 环境检查：Ubuntu、root、Bash、apt、systemd、基础网络状态。
- 主机名：保留当前 hostname 或设置新 hostname。
- 时区：默认建议 `Asia/Shanghai`，也可以自定义或跳过。
- 用户：创建或确认一个非 root sudo 用户，密码交给系统 `adduser` 处理。
- 基础软件包：检测缺失包后询问是否安装。
- UFW：确认 SSH 端口，启用前提示固定默认策略，可选开放 HTTP/HTTPS 端口 `80/443`。

更多使用说明见 [用户使用指南](docs/user-guide.md) 和 [常见问题](docs/faq.md)。

## 高级用户与开发者

如果你想调整默认模块、修改文案、重新构建脚本或新增模块，可以使用 Go 构建器：

```text
go run ./cmd/yatta validate
go run ./cmd/yatta list-modules
go run ./cmd/yatta build
go run ./cmd/yatta --version
```

`dist/yatta.sh` 是构建产物，不应手写修改。源码入口包括：

- `modules/`：服务器初始化模块，每个模块包含 `module.yaml`、`prompts.sh`、`apply.sh`。
- `runtime/`：会被拼接进最终脚本的 Bash 标准库。
- `internal/`：Go 构建器、模块读取、locale 和校验逻辑。
- `locales/`：脚本文案源文件。

模块编排使用 `stage + requires + before + after`，旧 `order` 字段仅作为兼容和同阶段辅助排序。需要开放端口的模块应登记端口计划，由 UFW 模块统一确认和执行。

模块开发规则见 [模块开发手册](docs/module-development.md)。验收流程见 [Smoke Test 与验收说明](docs/smoke-test.md)。项目级开发约束见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 文档导航

- [用户使用指南](docs/user-guide.md)：面向普通用户的运行教程和模块说明。
- [常见问题](docs/faq.md)：root、Ubuntu、SSH、UFW、用户创建等常见问题。
- [模块开发手册](docs/module-development.md)：面向高级用户和开发者的模块结构、order 分段、prompt/apply 边界。
- [Smoke Test 与验收说明](docs/smoke-test.md)：发布前的基础验证和真实服务器验收记录。
- [DEVELOPMENT.md](DEVELOPMENT.md)：项目阶段、架构、规范和开发流程总手册。

## 当前状态

- 已完成 Phase 0：项目骨架与开发文档。
- 已完成 Phase 1：Go 构建器与模块校验。
- 已完成 Phase 2：Bash runtime 与 TUI 基础能力。
- 已完成 Phase 3：默认模块实现。
- Phase 4 正在收尾：真实 Ubuntu 服务器验收已通过，后续可继续补充 Docker Ubuntu 验收记录。
