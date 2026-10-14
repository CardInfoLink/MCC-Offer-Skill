# Offer 相似推荐接口

## 能力用途

根据当前已确定的 Offer ID 查找相似权益。服务端使用基准 Offer 的标签进行推荐，并排除基准 Offer 自身。

## 调用契约

- Method: `POST`
- Path key: `API_RECOMMEND_PATH`
- Default path: `/api/offer/recommend`
- Content-Type: `application/json`

## 请求

```json
{"baseOfferId":"507f1f77bcf86cd799439011"}
```

`baseOfferId` 必须来自当前对话中的详情或列表结果，不要让用户输入无法确认的任意 ID 后直接调用。

## 通过脚本调用

POSIX：

```sh
REQUEST_JSON='{"baseOfferId":"507f1f77bcf86cd799439011"}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_RECOMMEND_PATH。
API_BASE_URL='<API_BASE_URL from client.conf>'
API_PATH='<API_RECOMMEND_PATH from client.conf>'

sh scripts/api-call.sh \
  --method POST \
  --url "${API_BASE_URL}${API_PATH}" \
  --data "$REQUEST_JSON" \
  --request-id "recommend-$(date +%Y%m%d%H%M%S)-$$"
```

PowerShell：

```powershell
$requestJson = '{"baseOfferId":"507f1f77bcf86cd799439011"}'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_RECOMMEND_PATH。
$apiBaseUrl = '<API_BASE_URL from client.conf>'
$apiPath = '<API_RECOMMEND_PATH from client.conf>'

$requestId = 'recommend-' + (Get-Date).ToString('yyyyMMddHHmmss') + '-' + $PID

& .\scripts\api-call.ps1 `
  -Method POST `
  -Url ($apiBaseUrl + $apiPath) `
  -Data $requestJson `
  -RequestId $requestId
```

调用完成后，读取脚本标准输出中的 `RESPONSE_FILE`，再解析其中的原始响应。

## 响应和状态`offers`、`totalCount`、`queryCacheId`、`currentPage`、`totalPages`、`hasMore`、`isDefault`。

- 保存 `queryCacheId`、当前页和 `baseOfferId`，供 `more.md` 使用。
- `isDefault=true` 时说明是通用推荐，不是精确相似匹配。
- `F010004` 表示基准 Offer 不存在、已删除或已过期。
