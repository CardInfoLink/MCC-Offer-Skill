# 脚本调用约定

本文件是业务接口的公共脚本调用说明。各接口文件只定义自己的请求方法、路径和请求正文，不重复解释脚本通用参数。

## api-call 参数

| POSIX | PowerShell | 含义 |
|---|---|---|
| `--method` | `-Method` | `GET`/`POST`/`PUT`/`PATCH`/`DELETE` |
| `--url` | `-Url` | 完整接口地址 |
| `--data` | `-Data` | JSON 字符串，与 `--data-file` 二选一 |
| `--data-file` | `-DataFile` | JSON 文件路径，与 `data` 二选一 |
| `--request-id` | `-RequestId` | 本次调用事件 ID，必须显式传入 |
| `--output-file` | `-OutputFile` | 原始响应保存位置，不传则写入 `config/data/res/{事件ID}.response` |
| `cleanup-data.sh` | `cleanup-data.ps1` | 处理完成后按事件 ID删除对应请求/响应临时文件 |
| `--timeout` | `-TimeoutSeconds` | 单次请求超时，默认 30 秒 |
| `--retry` | `-RetryCount` | 最大尝试次数，默认 3 |

脚本自动设置 `Content-Type: application/json`。标准输出只返回：

```text
REQUEST_ID=...
REQUEST_FILE=...
RESPONSE_FILE=...
HTTP_STATUS=...
EXIT_CODE=...
```

AI 必须读取 `REQUEST_FILE` 和 `RESPONSE_FILE`，不得把标准输出中的定位信息当作接口正文。

## 数据文件

每次调用只保留一对文件：

```text
config/data/req/{事件ID}.request
config/data/res/{事件ID}.response
```

请求文件保存实际发送的请求体，响应文件保存服务端原始正文。运行结果被 `.gitignore` 忽略，不能提交。

## 退出码

- `0`：HTTP 2xx；读取 `RESPONSE_FILE` 并按接口契约处理。
- `13`：网络或传输失败；读取请求/响应文件后提示稍后重试。
- `14`：HTTP 非 2xx 或参数/协议错误；不能把响应当作成功数据。

## POSIX 调用模板

```sh
REQUEST_JSON='{"example":"value"}'
REQUEST_ID="query-$(date +%Y%m%d%H%M%S)-$$"
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_QUERY_PATH。
API_BASE_URL='<API_BASE_URL from config/client.conf>'
API_PATH='<API_QUERY_PATH from config/client.conf>'

sh scripts/api-call.sh \
  --method POST \
  --url "${API_BASE_URL}${API_PATH}" \
  --data "$REQUEST_JSON" \
  --request-id "$REQUEST_ID"
```

## PowerShell 调用模板

```powershell
$requestJson = '{"example":"value"}'
$requestId = 'query-' + [guid]::NewGuid().ToString('N')
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_QUERY_PATH。
$apiBaseUrl = '<API_BASE_URL from client.conf>'
$apiPath = '<API_QUERY_PATH from client.conf>'

& .\scripts\api-call.ps1 `
  -Method POST `
  -Url ($apiBaseUrl + $apiPath) `
  -Data $requestJson `
  -RequestId $requestId
```

## 响应处理

脚本只负责请求、保存请求体和保存单一响应文件。能力子 SKILL 负责：

1. 保存并关联事件 ID；
2. 读取 `REQUEST_FILE` 和 `RESPONSE_FILE` 原文；
3. 判断脚本退出码和顶层 `code`；
4. 按目标接口文件解释 `data`；
5. 按 `result-template.md` 的展示建议组织用户可读结果。
