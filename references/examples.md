# MCC-Offer-Skill API 技术示例

本文档提供 MCC-Offer-Skill API 调用的技术参考示例，展示请求/响应的结构和数据格式。

**注意**：所有示例中的商户名称、优惠金额、有效期等为模拟数据，仅用于展示 API 契约。真实数据由服务端返回。

## 基础信息

- **Base URL** (生产)：`https://offercent.azpromotion.com`
- **Base URL** (测试)：`https://offercent.ipay.so`
- **Content-Type**：`application/json`

---

## 示例 1：查询接口 - 使用意图标签

**请求**

```
POST {BASE_URL}/api/offer/query
Content-Type: application/json
```

```json
{
  "searchInfo": "",
  "intentTags": [
    {
      "tagName": "dining",
      "matchScore": 85
    }
  ],
  "filters": {
    "regions": ["香港"]
  }
}
```

**响应**

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offers": [
      {
        "offerId": "507f1f77bcf86cd799439011",
        "title": "权益名称示例 1",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439011"
      },
      {
        "offerId": "507f1f77bcf86cd799439012",
        "title": "权益名称示例 2",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439012"
      }
    ],
    "totalCount": 47,
    "queryCacheId": "cache_dining_20261016",
    "currentPage": 1,
    "totalPages": 10,
    "hasMore": true,
    "isDefault": false
  }
}
```

---

## 示例 2：查询接口 - 使用查询词

**请求**

```json
{
  "searchInfo": "品牌或商户关键词",
  "intentTags": [],
  "filters": {
    "regions": ["香港"]
  }
}
```

**响应**

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offers": [
      {
        "offerId": "507f1f77bcf86cd799439011",
        "title": "权益名称示例",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439011"
      }
    ],
    "totalCount": 1,
    "queryCacheId": "cache_search_20261016",
    "currentPage": 1,
    "totalPages": 1,
    "hasMore": false,
    "isDefault": false
  }
}
```

---

## 示例 3：详情接口

**请求**

```
GET {BASE_URL}/api/offer/detail/507f1f77bcf86cd799439011
```

**响应**

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offerId": "507f1f77bcf86cd799439011",
    "title": "权益名称",
    "description": "简短描述",
    "offerSummary": "权益摘要信息",
    "merchantName": "商户名称",
    "benefitType": "discount",
    "banks": ["Mastercard"],
    "regions": ["香港"],
    "startTime": "2026-01-01T00:00:00Z",
    "endTime": "2026-12-31T23:59:59Z",
    "eligibilityRequirement": "资格要求说明",
    "tags": [
      {
        "tagName": "dining",
        "relevanceScore": 92
      },
      {
        "tagName": "cashback",
        "relevanceScore": 88
      }
    ],
    "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439011"
  }
}
```

---

## 示例 4：详情接口 - 错误响应

**请求**

```
GET {BASE_URL}/api/offer/detail/invalid-offer-id
```

**响应** (HTTP 200 with error code)

```json
{
  "code": "F080104",
  "msg": "Offer not found",
  "data": null
}
```

---

## 示例 5：分页接口 - 获取下一页

**请求**

```
POST {BASE_URL}/api/offer/more
Content-Type: application/json
```

```json
{
  "queryCacheId": "cache_dining_20261016",
  "page": 2,
  "searchInfo": "",
  "intentTags": [
    {
      "tagName": "dining",
      "matchScore": 85
    }
  ],
  "filters": {
    "regions": ["香港"]
  }
}
```

**响应**

返回格式同查询接口，`currentPage` 更新为 2。

---

## 示例 6：推荐接口

**请求**

```
POST {BASE_URL}/api/offer/recommend
Content-Type: application/json
```

```json
{
  "baseOfferId": "507f1f77bcf86cd799439011"
}
```

**响应**

返回格式同查询接口，包含基于基准 Offer 的相似权益列表。

---

## 示例 7：查询接口 - 无匹配结果时的默认推荐

**请求**

```json
{
  "searchInfo": "",
  "intentTags": [
    {
      "tagName": "nonexistent-tag",
      "matchScore": 50
    }
  ],
  "filters": {
    "regions": ["香港"]
  }
}
```

**响应**

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offers": [
      {
        "offerId": "507f1f77bcf86cd799439020",
        "title": "默认推荐权益 1",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439020"
      },
      {
        "offerId": "507f1f77bcf86cd799439021",
        "title": "默认推荐权益 2",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439021"
      },
      {
        "offerId": "507f1f77bcf86cd799439022",
        "title": "默认推荐权益 3",
        "description": "权益描述",
        "merchantName": "商户名称",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439022"
      }
    ],
    "totalCount": 3,
    "queryCacheId": "",
    "currentPage": 1,
    "totalPages": 1,
    "hasMore": false,
    "isDefault": true
  }
}
```

---

## 标签参考

常见意图标签（来自 `config/tags.txt`）：

| 标签 | 含义 |
|------|------|
| `cashback` | 返现 |
| `discount` | 折扣 |
| `dining` | 餐饮 |
| `shopping` | 购物 |
| `travel` | 出行 |
| `accommodation` | 住宿 |
| `entertainment` | 娱乐 |
| `fuel` | 加油 |

---

## 地区值参考

地区过滤值直接使用 `config/regions.txt` 中的中文地区名称，不使用地区代码。

| 地区值 | 说明 |
|------|------|
| `香港` | 当前配置示例 |
| `台湾` | 当前配置示例 |
| `新加坡` | 当前配置示例 |
| 更多 | 见 `config/regions.txt` |

---

## 银行代码参考

| 代码 | 银行 |
|------|------|
| `ICBC` | 中国工商银行 |
| `ABC` | 中国农业银行 |
| `CCB` | 中国建设银行 |
| `BOC` | 中国银行 |
| 更多 | 见 `config/banks.txt` |
