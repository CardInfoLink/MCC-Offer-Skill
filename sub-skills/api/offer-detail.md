# Offer 详情接口

## 能力用途

根据已经确定的 Offer ID 获取详情。该链路不经过意图解析。

## 调用契约

- Method: `GET`
- Path key: `API_DETAIL_PATH`
- Default path: `/api/offer/detail`
- URL: `${API_BASE_URL}${API_DETAIL_PATH}/{offerId}`

## 通过脚本调用

POSIX：

```sh
OFFER_ID='507f1f77bcf86cd799439011'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_DETAIL_PATH。
API_BASE_URL='<API_BASE_URL from client.conf>'
API_PATH='<API_DETAIL_PATH from client.conf>'

sh scripts/api-call.sh \
  --method GET \
  --url "${API_BASE_URL}${API_PATH}/${OFFER_ID}" \
  --request-id "detail-$(date +%Y%m%d%H%M%S)-$$"
```

PowerShell：

```powershell
$offerId = '507f1f77bcf86cd799439011'
# AI 已从 config/client.conf 读取 API_BASE_URL 和 API_DETAIL_PATH。
$apiBaseUrl = '<API_BASE_URL from client.conf>'
$apiPath = '<API_DETAIL_PATH from client.conf>'

$requestId = 'detail-' + (Get-Date).ToString('yyyyMMddHHmmss') + '-' + $PID

& .\scripts\api-call.ps1 `
  -Method GET `
  -Url ($apiBaseUrl + $apiPath + '/' + $offerId) `
  -RequestId $requestId
```

调用完成后，读取脚本标准输出中的 `RESPONSE_FILE`，再解析其中的原始响应。

## 响应字段

- `offerId`、`title`、`description`、`merchantName`
- `offerSummary`、`benefitType`
- `banks`、`regions`
- `startTime`、`endTime`
- `eligibilityRequirement`
- `tags[]: {tagName,relevanceScore}`
- `offerUrl`

## 能力处理规则

- `offerUrl` 必须原样提供，不能自行拼接或替换。
- `relevanceScore` 是内部相关度，不作为用户评价展示。
- `F010004` 表示 Offer 不存在、已删除或已过期。
- 详情展示规则使用 `result-template.md`，不读取查询列表的分页字段。
