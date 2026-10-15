# MCC Offer Skill

本仓库是 [CardInfoLink/MCC-Offer-Skill](https://github.com/CardInfoLink/MCC-Offer-Skill)，提供由万事达（Mastercard）提供、面向中国大陆用户的信用卡权益 Offer Skill。标准 Skill 标识为 `mcc-offer-skill`，平台发行包统一使用 `mcc-offer-skill/` 作为包目录。

## 目录

- `SKILL.md`：启动前置和 query/detail/recommend/more 场景路由。
- `sub-skills/common.md`：所有能力共用的运行约定：脚本、调用模板与参数、请求 ID 与临时文件、响应判定、会话状态、清理。
- `sub-skills/query.md`：事实条件提取、主题判定（查询词 / 意图标签 / 无主题）和请求组装。
- `sub-skills/detail.md`：详情能力流程（含详情展示，不依赖 `result.md`）。
- `sub-skills/recommend.md`：相似推荐能力流程。
- `sub-skills/more.md`：分页能力流程。
- `sub-skills/result.md`：查询、分页、相似推荐共用的列表展示规则。
- `sub-skills/api/`：按接口拆分的请求/响应字段契约；脚本调用模板统一在 `common.md`。
- `scripts/`：POSIX Shell、Windows PowerShell 双实现的运行时脚本，只有三个：`init`（启动入口，环境检查 + 配置同步）、`call`（接口调用）、`clean`（临时数据清理）；配置同步不留请求/响应文件。
- `config/data/req/`：运行时请求体目录，按请求 ID 保存请求文件，不提交 Git。
- `config/data/res/`：运行时响应体目录，按请求 ID 保存响应文件，不提交 Git。
- `config/`：API 地址/路径、本地状态和纯数据字典；`client.conf` 随 Skill 提供，首次同步前部分值为空。
- `test/`：验证脚本，不属于正式运行时脚本目录。

## 接口文档位置

接口级的请求/响应字段统一放在 `sub-skills/api/`：

- `api/offer-query.md`：查询接口。
- `api/offer-detail.md`：详情接口。
- `api/offer-recommend.md`：相似推荐接口。
- `api/offer-more.md`：分页接口。

脚本调用模板（POSIX / PowerShell）、参数、退出码都在 `sub-skills/common.md`；启动入口 `init` 的输出和 `READY` 判定在 `SKILL.md` 的“启动前置”。能力子 SKILL 进入时一次性读取 `common.md` 和自己对应的接口文档，不加载其他场景的文档。

## 快速开始

POSIX/Git Bash：

```sh
sh scripts/init.sh --base-url https://offer.example.com
sh test/verify-posix.sh
```

Windows PowerShell：

```powershell
powershell -NoProfile -File scripts\init.ps1 -BaseUrl https://offer.example.com
```

首次同步后，AI 编程工具按 `SKILL.md` 路由到能力子 SKILL；能力子 SKILL 再加载对应接口契约，通过 `call` 脚本请求服务端，并根据请求 ID 从 `config/data/req/` 和 `config/data/res/` 读取请求/响应原文。解析并保存上下文、完成回复后，调用 `clean` 脚本删除本次临时文件。

## 服务端接口

服务端参考实现为 `EverySkill`：配置同步是 `POST /api/offer/config`，业务接口为 `POST /api/offer/query`、`GET /api/offer/detail/{id}`、`POST /api/offer/recommend` 和 `POST /api/offer/more`。业务接口返回 `code/msg/data` 结构。

## 安全边界

脚本只把调用方已经组装好的 JSON 原样交给 curl，不执行远程脚本，不下载或覆盖 `scripts/` 与 `sub-skills/`，也不保存密钥。已安装的客户端同步失败时保留本地缓存；首次安装必须同步成功，否则 `init` 返回 `READY=NO` 并停止。接口协议和 AI 解释随 Skill 版本发布，运行时配置只同步纯数据和接口运行参数。

## 平台发行构建

源码仓库只维护一份核心 Skill；平台包由发行脚本从核心目录生成，不在各平台目录复制业务逻辑。所有平台包都排除测试数据、运行时请求/响应、`.kiro/` 和本地状态。

通用 Agent Skills 包：

```bash
sh tools/release/package.sh --profile testing --platform agent-skill --version 0.1.0-rc.1
sh tools/release/validate.sh dist/mcc-offer-skill-testing-0.1.0-rc.1
```

平台包可单独构建，也可以使用 `--platform all` 一次生成：

```powershell
powershell -NoProfile -File tools\release\package.ps1 -Profile testing -Platform all -Version 0.1.0-rc.1
```

```sh
sh tools/release/package.sh --profile testing --platform all --version 0.1.0-rc.1
```

平台包结构和发现入口：

| 平台 | 发行包入口 | 适配说明 |
| --- | --- | --- |
| Claude Code | `.claude-plugin/`、`skills/mcc-offer-skill/SKILL.md` | `platforms/claude-code/README.md` |
| Cursor | `.cursor/skills/mcc-offer-skill/SKILL.md` | `platforms/cursor/README.md` |
| OpenClaw | `skills/mcc-offer-skill/SKILL.md` | `platforms/openclaw/README.md` |
| WorkBuddy | `manifest.yaml`、`SKILL.md` | `platforms/workbuddy/manifest.yaml` |
| npm | 包根 `package.json`、`SKILL.md` | `platforms/npm/package.json` |

PowerShell 发行脚本会在 npm 平台包可用时额外执行 `npm pack`；POSIX 脚本同样会在检测到 npm 时生成 `.tgz`。npm 仅执行打包，不会自动发布到远端 registry。GitHub Release、CHANGELOG、Issue/PR 模板和 CI 校验位于 `.github/` 与 `docs/releases/`，仓库 Topics 需在 GitHub 仓库设置中维护。

`package` 只读取 `config/client.testing` 或 `config/client.product`，在 `dist/` 中生成独立包目录和 ZIP；不会清空或覆盖源码仓库。
