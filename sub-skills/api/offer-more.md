# Offer 分页接口

## 能力用途

获取查询或相似推荐的下一页。缓存失效时服务端会使用原始条件重新匹配，并返回第 1 页，不要求用户重新表达需求。

## 调用契约

- Method: `POST`
- Path key: `API_MORE_PATH`
- Default path: `/api/offer/more`
- Content-Type: `application/json`
- pageSize 固定为 10，不能传 `pageSize`。

## 请求

查询场景：

```json
{
  "queryCacheId":"cache_123456",
  "page":2,
  "intentTags":[{"tagName":"温泉度假","matchScore":85}],
  "filters":{"banks":["ABC"],"regions":["香港"]},
  "baseOfferId":""
}
```

推荐场景：

```json
{
  "queryCacheId":"cache_123456",
  "page":2,
  "intentTags":[],
  "filters":null,
  "baseOfferId":"507f1f77bcf86cd799439011"
}
```

## 通过脚本调用

POSIX：

```sh
REQUEST_JSON='{"queryCacheId":"cache_123456","page":2,"intentTags":[{"tagName":"温泉度假","matchScore":85}],"filters":null,"baseOfferId":""}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_MORE_PATH。
API_BASE_URL='<API_BASE_URL from client.conf>'
API_PATH='<API_MORE_PATH from client.conf>'

sh scripts/api-call.sh \
  --method POST \
  --url "${API_BASE_URL}${API_PATH}" \
  --data "$REQUEST_JSON" \
  --request-id "more-$(date +%Y%m%d%H%M%S)-$$"
```

PowerShell：

```powershell
$requestJson = '{"queryCacheId":"cache_123456","page":2,"intentTags":[{"tagName":"温泉度假","matchScore":85}],"filters":null,"baseOfferId":""}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_MORE_PATH。
$apiBaseUrl = '<API_BASE_URL from client.conf>'
$apiPath = '<API_MORE_PATH from client.conf>'

$requestId = 'more-' + (Get-Date).ToString('yyyyMMddHHmmss') + '-' + $PID

& .\scripts\api-call.ps1 `
  -Method POST `
  -Url ($apiBaseUrl + $apiPath) `
  -Data $requestJson `
  -RequestId $requestId
```

调用完成后，读取脚本标准输出中的 `RESPONSE_FILE`，再解析其中的原始响应。

## 状态和响应
- 以响应的 `queryCacheId`、`currentPage`、`totalPages`、`hasMore` 为准。
- 缓存过期重匹配时，`currentPage` 通常为 1，必须替换旧的缓存 ID。
- 保存首次查询的 `intentTags`/`filters`，推荐场景保存 `baseOfferId`；不能只保存 queryCacheId。
