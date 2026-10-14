# 万事达信用卡权益 Skill

本仓库是由万事达（Mastercard）提供、面向中国大陆用户的信用卡权益 Offer Skill。主 `SKILL.md` 只负责启动和场景路由；具体能力、接口契约、请求留痕和脚本调用示例位于 `sub-skills/`。

## 目录

- `SKILL.md`：启动前置和 query/detail/recommend/more 场景路由。
- `sub-skills/_shared.md`：所有能力共用的配置、脚本、响应和状态依赖。
- `sub-skills/request-tracking.md`：请求 ID、响应文件和 AI 读取规则。
- `sub-skills/query.md`：标准查询能力和本地查询解析流程。
- `sub-skills/detail.md`：详情能力流程。
- `sub-skills/recommend.md`：相似推荐能力流程。
- `sub-skills/more.md`：分页能力流程。
- `sub-skills/result-template.md`：所有接口共用的响应处理和展示建议。
- `sub-skills/api/`：按接口拆分的请求/响应契约和脚本调用示例。
- `scripts/`：POSIX Shell、Windows PowerShell 双实现的运行时脚本，包括环境检测、配置同步、接口调用和临时数据清理。
- `config/data/req/`：运行时请求体目录，按事件 ID保存请求文件，不提交 Git。
- `config/data/res/`：运行时响应体目录，按事件 ID保存响应文件，不提交 Git。
- `config/`：API 地址/路径、本地状态和纯数据字典；`client.conf` 随 Skill 提供，首次同步前部分值为空。
- `test/`：验证脚本，不属于正式运行时脚本目录。

## 调用示例位置

接口级调用示例统一放在 `sub-skills/api/`：

- `api/config-sync.md`：调用 `sync-config.sh` / `sync-config.ps1`。
- `api/offer-query.md`：查询接口的 POSIX/PowerShell 示例。
- `api/offer-detail.md`：详情接口示例。
- `api/offer-recommend.md`：相似推荐接口示例。
- `api/offer-more.md`：分页接口示例。
- `api/script-contract.md`：脚本公共参数、请求 ID和响应文件说明。

能力子 SKILL 只加载当前场景需要的接口文档，避免重复加载全部示例和字段。

## 快速开始

POSIX/Git Bash：

```sh
sh scripts/env-check.sh
sh scripts/sync-config.sh --base-url https://offer.example.com
sh test/verify-posix.sh
```

Windows PowerShell：

```powershell
powershell -NoProfile -File scripts\env-check.ps1
powershell -NoProfile -File scripts\sync-config.ps1 -BaseUrl https://offer.example.com
```

首次同步后，AI 编程工具按 `SKILL.md` 路由到能力子 SKILL；能力子 SKILL 再加载对应接口契约，通过 `api-call` 脚本请求服务端，并根据事件 ID从 `config/data/req/` 和 `config/data/res/` 读取请求/响应原文。解析并保存上下文、完成回复后，调用对应的 `cleanup-data` 脚本删除本次临时文件。

## 服务端接口

服务端参考实现为 `EverySkill`：配置同步是 `POST /api/offer/config`，业务接口为 `POST /api/offer/query`、`GET /api/offer/detail/{id}`、`POST /api/offer/recommend` 和 `POST /api/offer/more`。业务接口返回 `code/msg/data` 结构。

## 安全边界

脚本只把调用方已经组装好的 JSON 原样交给 curl，不执行远程脚本，不下载或覆盖 `scripts/` 与 `sub-skills/`，也不保存密钥。同步失败时保留本地缓存并返回统一失败分类。接口协议和 AI 解释随 Skill 版本发布，运行时配置只同步纯数据和接口运行参数。
