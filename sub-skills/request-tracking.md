# 请求留痕与生命周期能力

## 作用

每次脚本调用都生成事件 ID，并把请求体和服务端原始响应分别写入 `config/data/req/` 和 `config/data/res/`。AI 通过同一个事件 ID关联请求和响应，不依赖聊天窗口是否保留脚本输出。

## 文件约定

一次调用默认生成两个文件：

```text
config/data/req/{事件ID}.request
config/data/res/{事件ID}.response
```

文件内容：

- `.request`：实际发送给服务端的原始请求体；GET 或无请求体时为空文件。
- `.response`：服务端返回的原始正文，不改写、不截断。

## AI 读取流程

1. 从脚本标准输出读取 `REQUEST_ID`、`REQUEST_FILE`、`RESPONSE_FILE`、`HTTP_STATUS`、`EXIT_CODE`。
2. 使用同一个事件 ID关联请求文件和响应文件。
3. 读取 `RESPONSE_FILE`，按接口契约解析原始响应；请求文件只用于复盘本次实际发送的参数。
4. 在最终回复前，把后续对话需要的业务上下文保存到会话中，再清理本次事件的临时文件。

## 上下文保持规则

临时文件不是会话记忆。清理文件前，必须保存以下最小上下文：

### 标准查询

- 原始 `intentTags`；
- 原始 `filters`；
- `queryCacheId`；
- `currentPage`、`totalPages`、`hasMore`；
- `isDefault`；
- 已展示的 Offer ID 列表。

### 详情

- 当前 `offerId`；
- 用户正在追问的 Offer 基本事实；
- 如果用户要相似推荐，保留该 `offerId` 作为 `baseOfferId`。

### 相似推荐

- `baseOfferId`；
- `queryCacheId`；
- `currentPage`、`totalPages`、`hasMore`；
- 首次推荐是否为默认推荐。

### 配置同步

- `LOCAL_CLIENT_ID`；
- `LOCAL_CONFIG_VERSION`；
- 本次是否发生配置变化；
- 配置字典已经写入本地的事实。

## 清理时机

只有同时满足以下条件才清理：

1. 已读取并解析 `RESPONSE_FILE`；
2. 已保存分页、详情或推荐所需上下文；
3. 已完成本次用户回复，或已向用户说明失败原因。

清理命令：

POSIX：

```sh
sh scripts/cleanup-data.sh --request-id "$REQUEST_ID"
```

PowerShell：

```powershell
& .\scripts\cleanup-data.ps1 -RequestId $requestId
```

清理脚本只删除当前事件 ID对应的一个请求文件和一个响应文件，不扫描、不清空其他事件文件。用户明确要求排查问题时，可以暂留文件；排查结束后仍需清理。

## 事件 ID规则

- POSIX 必须显式传 `--request-id`，PowerShell 必须显式传 `-RequestId`。
- 事件 ID由上层能力生成并贯穿一次完整请求，例如 `query-...`、`detail-...`、`more-...`、`config-...`。
- 缺少事件 ID时，`api-call` 返回 `14`，不会自动生成。
- 同步脚本会先生成 `sync-...` 事件 ID，再显式传给 `api-call`。
- `config/data/req/` 和 `config/data/res/` 中的运行结果不提交 Git，`.gitkeep` 除外。

## 调用要求

每个能力子 SKILL 都必须保存并关联事件 ID、请求文件、响应文件和后续会话状态；不能只把接口正文打印到对话窗口后丢弃，也不能在解析前清理文件。
