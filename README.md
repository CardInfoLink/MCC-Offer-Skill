# MCC Offer Skill

本仓库是 [CardInfoLink/MCC-Offer-Skill](https://github.com/CardInfoLink/MCC-Offer-Skill)，提供面向中国大陆用户的万事达信用卡权益 Offer Skill。标准 Skill 标识为 `mcc-offer-skill`。

本仓库当前为**测试版**，仅用于 Skill 发行验收，不代表生产版本发布。当前 Git 提交和默认配置面向测试环境，`config/client.conf` 默认使用：

```text
API_BASE_URL=https://offercent.ipay.so
```

当前不生成独立 Testing 包；WorkBuddy、DouBaoWork 的生产命名 ZIP 和 GitHub/Cursor/Claude Code 安装版本均仅用于测试验收。

## 核心结构

- `SKILL.md`：标准 Agent Skill 入口，负责范围判断、会话初始化、场景路由、脚本调用契约和安全边界。
- `sub-skills/common.md`：脚本参数、JSON 文件入参、请求 ID、响应判定、会话状态和清理。
- `sub-skills/query.md`：查询词/意图标签/无主题判定、事实条件提取和查询请求组装。
- `sub-skills/detail.md`：Offer 详情查询与展示。
- `sub-skills/recommend.md`：相似 Offer 推荐。
- `sub-skills/more.md`：分页查询和会话条件复用。
- `sub-skills/result.md`：查询、分页、相似推荐的列表展示规则。
- `references/`：按需读取的非可执行接口契约和参考资料，包括 `api-offer-query.md`、`api-offer-detail.md`、`api-offer-recommend.md`、`api-offer-more.md`。
- `scripts/`：POSIX Shell 和 Windows PowerShell 双实现，只有 `init`、`call`、`clean` 三类脚本。
- `config/`：接口地址、客户端状态和纯数据字典；`config/data/req/`、`config/data/res/` 用于运行时请求/响应临时文件。
- `.claude-plugin/`：Claude Code 插件和 Marketplace 元数据。
- `.cursor-plugin/`：Cursor 插件和 Marketplace 元数据；根目录 `SKILL.md` 自动作为单 Skill 发现。
- `package/`：生成 WorkBuddy、DouBaoWork 测试发行 ZIP 的脚本。
- `docs/`：安装和兼容环境说明。

## 平台安装入口

### Claude Code

通过仓库根目录 `.claude-plugin/` 的 Marketplace 元数据导入 GitHub 仓库。安装后由 Claude Code 加载根目录 `SKILL.md` 及其随版本分发的脚本、子 Skill 和参考资料。

### Cursor

在 Cursor Customize 中使用 **From GitHub Repository** 导入：

```text
https://github.com/CardInfoLink/MCC-Offer-Skill
```

安装 `mcc-offer-skill` 后，进入插件详情页确认显示 `Skills 1`，再到 `Customize → Skills` 确认 Skill 可用。仓库根目录 `.cursor-plugin/marketplace.json` 的插件来源为 `.`，`.cursor-plugin/plugin.json` 不声明 `skills` 字段，由 Cursor 按根目录 `SKILL.md` 发现单个 Skill。

### OpenClaw

将仓库作为 Skill 目录安装，保留根目录 `SKILL.md`、`sub-skills/`、`scripts/`、`config/` 和 `references/`。运行时按宿主环境选择 `scripts/init.sh` 或 `scripts/init.ps1`，不要调用不存在的查询脚本，也不要绕过 `call` 脚本直接请求接口。

### WorkBuddy / DouBaoWork

运行 `package/package.ps1` 或 `package/package.sh` 生成：

```text
dist/mcc-offer-skill-workbuddy.zip
dist/mcc-offer-skill-doubaowork.zip
```

两个包使用生产命名，但当前默认服务端指向测试环境，仅用于测试验收。

## 运行约定

POSIX/Git Bash/WSL：

```sh
sh scripts/init.sh
sh scripts/call.sh \
  --method POST \
  --url "${API_BASE_URL}${API_QUERY_PATH}" \
  --data-file "<UTF-8 无 BOM JSON 文件>" \
  --request-id "query-<唯一值>"
sh scripts/clean.sh --request-id "query-<唯一值>"
```

Windows PowerShell：

```powershell
& .\scripts\init.ps1
& .\scripts\call.ps1 `
  -Method POST `
  -Url ($apiBaseUrl + $apiPath) `
  -DataFile "<UTF-8 无 BOM JSON 文件>" `
  -RequestId "query-<唯一值>"
& .\scripts\clean.ps1 -RequestId "query-<唯一值>"
```

首次进入 Skill 会话必须先运行 `init` 并确认 `READY=YES`。业务请求必须使用 `call`，请求 JSON 必须写入 UTF-8 无 BOM 文件并通过 `--data-file`/`-DataFile`传入；禁止使用 `query.ps1`、`query.sh` 或直接调用 curl/API。脚本退出失败、响应文件不存在、响应无法解析或顶层 `code` 不是 `S000000` 时停止当前链路，不编造权益结果。`isDefault=true` 必须向用户说明为参考推荐，不是精确匹配。

## 配置和安全

`config/client.conf` 默认提供测试服务地址，首次同步后由脚本回写 `LOCAL_CLIENT_ID`、`LOCAL_CONFIG_VERSION` 和 `LOCAL_LAST_SYNC_DATE`。配置同步只处理 `config/` 下的纯数据；`SKILL.md`、`sub-skills/`、`scripts/` 和 `references/` 不由运行时远程覆盖。

脚本不保存密钥、Cookie、Bearer Token 或用户隐私，不下载或执行远程脚本/提示词，不把用户自然语言直接拼进命令。详细安装和兼容要求见：

- `docs/install.md`
- `docs/compatibility.md`
- `references/README.md`
