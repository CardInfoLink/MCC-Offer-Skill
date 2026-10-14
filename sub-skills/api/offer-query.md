# Offer 查询接口

## 能力用途

根据本地 AI 解析出的受控意图标签和事实过滤条件，查询排序后的权益列表。服务端不做自然语言理解、银行别名转换或标签纠错。

## 调用契约

- Method: `POST`
- Path key: `API_QUERY_PATH`
- Default path: `/api/offer/query`
- Content-Type: `application/json`

## 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `intentTags` | array | 否 | 本地解析出的受控标签 |
| `intentTags[].tagName` | string | 是 | 必须来自 `config/tags.txt` |
| `intentTags[].matchScore` | integer | 是 | 1~100，用户意图强度，不是 Offer 得分 |
| `filters` | object/null | 否 | 事实过滤条件；无条件时使用 null |
| `filters.banks` | string[] | 否 | `config/banks.txt` 中的标准银行名 |
| `filters.regions` | string[] | 否 | 用户提到的地区 |
| `filters.timeRange` | object | 否 | 日期范围 |
| `filters.timeRange.start` | string | 否 | `yyyy-MM-dd` |
| `filters.timeRange.end` | string | 否 | `yyyy-MM-dd` |

## 请求示例

```json
{
  "intentTags": [
    {"tagName":"温泉度假","matchScore":85},
    {"tagName":"亲子","matchScore":60}
  ],
  "filters": {
    "banks":["ABC"],
    "regions":["香港"],
    "timeRange":{"start":"2026-10-01","end":"2026-12-31"}
  }
}
```

## 通过脚本调用

POSIX：

```sh
REQUEST_JSON='{"intentTags":[{"tagName":"温泉度假","matchScore":85}],"filters":null}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_QUERY_PATH。
API_BASE_URL='<API_BASE_URL from config/client.conf>'
API_PATH='<API_QUERY_PATH from config/client.conf>'

sh scripts/api-call.sh \
  --method POST \
  --url "${API_BASE_URL}${API_PATH}" \
  --data "$REQUEST_JSON" \
  --request-id "query-$(date +%Y%m%d%H%M%S)-$$"
```

PowerShell：

```powershell
$requestJson = '{"intentTags":[{"tagName":"温泉度假","matchScore":85}],"filters":null}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_QUERY_PATH。
$apiBaseUrl = '<API_BASE_URL from client.conf>'
$apiPath = '<API_QUERY_PATH from client.conf>'

$requestId = 'query-' + (Get-Date).ToString('yyyyMMddHHmmss') + '-' + $PID

& .\scripts\api-call.ps1 `
  -Method POST `
  -Url ($apiBaseUrl + $apiPath) `
  -Data $requestJson `
  -RequestId $requestId
```

调用完成后，读取脚本标准输出中的 `RESPONSE_FILE`，再解析其中的原始响应。

## 响应

| 字段 | 说明 |
|---|---|
| `offers` | 当前页权益，服务端已按匹配顺序排列 |
| `totalCount` | 全部命中数量 |
| `queryCacheId` | 分页缓存 ID |
| `currentPage` | 当前页，首页为 1 |
| `totalPages` | 总页数 |
| `hasMore` | 是否还有下一页 |
| `isDefault` | 是否为默认推荐兜底 |

`offers[]` 字段为 `offerId`、`title`、`description`、`merchantName`、`offerUrl`。

## 能力处理规则

1. `S000000` 才进入结果格式化。
2. 按服务端返回顺序展示，不展示内部命中得分。
3. 保存 `queryCacheId`、`intentTags`、`filters`，供 `more.md` 使用。
4. `isDefault=true` 时说明这是通用推荐，不是精确意图匹配。
5. `F010001`/`F010002`/`F010003` 按 `result-template.md` 的错误规则处理。
