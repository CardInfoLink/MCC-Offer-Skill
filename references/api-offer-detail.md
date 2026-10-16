# Offer 详情接口

根据已确定的 Offer ID 获取完整详情信息。用户从列表中点击某个权益后，通过此接口获取该权益的所有细节（包括参与步骤、适用条件、有效期等）。

## 调用契约

- **Method**: `GET`
- **路径键**: `API_DETAIL_PATH`（默认 `/api/offer/detail`）
- **完整 URL**: `${API_BASE_URL}${API_DETAIL_PATH}/{offerId}`
- **请求 ID 前缀**: `detail`
- **安全约束**: URL 只能由配置中的基础地址和**已确认的** `offerId` 拼成，**不接受用户提供的任意目标 URL**

## 请求

```
GET {BASE_URL}/api/offer/detail/507f1f77bcf86cd799439011
```

参数在 URL 路径中，无请求体。

## 响应字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `code` | string | 状态码（`S000000` 成功，`F080104` 表示 Offer 不存在/已删除/已过期） |
| `msg` | string | 消息文本 |
| `data` | object | 响应数据 |
| `data.offerId` | string | 权益唯一标识 |
| `data.title` | string | 权益标题 |
| `data.description` | string | 简短描述 |
| `data.offerSummary` | string | 权益摘要（如适用人群、基本条件） |
| `data.merchantName` | string | 商户名称 |
| `data.benefitType` | string | 权益类型（如 `cashback`、`discount`） |
| `data.banks[]` | string[] | 适用银行列表 |
| `data.regions[]` | string[] | 适用地区列表 |
| `data.startTime` | string | 生效时间（ISO 8601） |
| `data.endTime` | string | 失效时间（ISO 8601） |
| `data.eligibilityRequirement` | string | 资格要求描述 |
| `data.tags[]` | array | 权益标签列表 |
| `data.tags[].tagName` | string | 标签名（如 `dining`、`cashback`） |
| `data.tags[].relevanceScore` | integer | 内部相关度评分（1-100，**不展示给用户**） |
| `data.offerUrl` | string | 权益详情页链接（原样提供，不自行拼接） |

## 响应示例

### 成功响应

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offerId": "507f1f77bcf86cd799439011",
    "title": "星巴克消费折扣",
    "description": "持万事达卡在香港星巴克消费享优惠",
    "offerSummary": "凡是持有有效万事达卡的客户，在香港所有星巴克门店消费均可享受优惠。",
    "merchantName": "Starbucks",
    "benefitType": "discount",
    "banks": ["Mastercard"],
    "regions": ["HK"],
    "startTime": "2026-01-01T00:00:00Z",
    "endTime": "2026-12-31T23:59:59Z",
    "eligibilityRequirement": "持有有效万事达卡，无特殊资格限制",
    "tags": [
      {
        "tagName": "cashback",
        "relevanceScore": 92
      },
      {
        "tagName": "dining",
        "relevanceScore": 88
      }
    ],
    "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439011"
  }
}
```

### 错误响应（Offer 不存在/已删除/已过期）

```json
{
  "code": "F080104",
  "msg": "Offer not found",
  "data": null
}
```

## 处理规则

1. **只有 `code=S000000` 时进入展示**；其他状态码表示错误或不可用。
2. **仅有一个业务错误码**: `F080104`（Offer 不存在、已删除或已过期）。其他错误由 HTTP 状态码表达。
3. **`offerUrl` 原样提供**，不自行拼接或替换，直接提供给用户或系统使用。
4. **`relevanceScore` 仅供内部参考**，不在用户界面展示。
5. **详情响应没有分页**，总是单个 Offer 的完整信息。
6. **时间字段使用 ISO 8601 格式**（UTC），前端需要本地化展示。

## 错误处理

| HTTP 状态 | 含义 | 说明 |
|---|---|---|
| 200 | 成功或业务错误 | 检查 `code` 字段判断是否成功（`S000000`） |
| 400 | 请求参数错误 | 通常是 URL 格式错误或 `offerId` 无效 |
| 401 | 认证失败 | 通常不会出现，API 一般无需认证 |
| 404 | 资源不存在 | Offer 已删除或 ID 不存在（也可能返回 `code=F080104`） |
| 500 | 服务器错误 | 服务端异常，建议稍后重试 |
| 503 | 服务不可用 | 服务暂时不可用，建议稍后重试 |
