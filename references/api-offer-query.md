# Offer 查询接口

根据本地解析出的主题（意图标签或查询词）和事实条件，返回排好序的权益列表，每页 5 条。服务端负责匹配、排序和过滤，不做自然语言理解、银行别名转换或标签纠错。

## 调用契约

- **Method**: `POST`
- **Content-Type**: `application/json`
- **路径键**: `API_QUERY_PATH`（默认 `/api/offer/query`）
- **完整 URL**: `${API_BASE_URL}${API_QUERY_PATH}`
- **请求 ID 前缀**: `query`

## 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `searchInfo` | string | 否 | 查询词：精简的品牌、商户或优惠核心词，最长 20 字符。有值时服务端忽略 `intentTags`。不需要时不传 |
| `intentTags` | array | 否 | 受控标签数组；无主题时传空数组 `[]` |
| `intentTags[].tagName` | string | 是 | 标签名，**必须来自** `config/tags.txt`（如 `dining`、`shopping`） |
| `intentTags[].matchScore` | integer | 是 | 1-100，表示用户意图强度，**不是** Offer 排序得分 |
| `filters` | object / null | 否 | 事实条件对象；无条件时传 `null` |
| `filters.banks` | string[] | 否 | 银行代码数组，**必须来自** `config/banks.txt`（如 `["ICBC", "ABC"]`） |
| `filters.regions` | string[] | 否 | 地区名称数组，值应来自 `config/regions.txt`（如 `["香港", "台湾"]`） |
| `filters.timeRange` | object | 否 | 时间范围过滤 |
| `filters.timeRange.start` | string | 否 | 开始日期（`yyyy-MM-dd` 格式）；格式不对或起止颠倒时服务端忽略整段 |
| `filters.timeRange.end` | string | 否 | 结束日期（`yyyy-MM-dd` 格式） |

## 三种请求形态

### 形态 1：使用查询词（searchInfo）

```json
{
  "searchInfo": "星巴克",
  "intentTags": [],
  "filters": {
    "regions": ["香港"]
  }
}
```

### 形态 2：使用意图标签（intentTags）

```json
{
  "searchInfo": "",
  "intentTags": [
    {
      "tagName": "dining",
      "matchScore": 85
    },
    {
      "tagName": "cashback",
      "matchScore": 60
    }
  ],
  "filters": {
    "banks": ["ABC"],
    "regions": ["香港"],
    "timeRange": {
      "start": "2026-10-01",
      "end": "2026-12-31"
    }
  }
}
```

### 形态 3：无主题条件查询（仅过滤）

```json
{
  "searchInfo": "",
  "intentTags": [],
  "filters": {
    "regions": ["香港"]
  }
}
```

## 响应字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `code` | string | 状态码（`S000000` 成功；本接口**无业务错误码**） |
| `msg` | string | 消息文本 |
| `data` | object | 响应数据 |
| `data.offers[]` | array | 当前页权益列表，服务端已按相关度排好序 |
| `data.offers[].offerId` | string | 权益ID |
| `data.offers[].title` | string | 权益标题 |
| `data.offers[].description` | string | 简短描述 |
| `data.offers[].merchantName` | string | 商户名称 |
| `data.offers[].offerUrl` | string | 权益详情链接 |
| `data.totalCount` | integer | 全部命中的权益总数 |
| `data.queryCacheId` | string | 分页缓存 ID（用于后续翻页）；`isDefault=true` 时为空 |
| `data.currentPage` | integer | 当前页号（首页 = 1） |
| `data.totalPages` | integer | 总页数 |
| `data.hasMore` | boolean | 是否还有更多页 |
| `data.isDefault` | boolean | 是否为默认推荐兜底（检索失败时返回） |

## 响应示例

### 成功查询（有结果）

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offers": [
      {
        "offerId": "507f1f77bcf86cd799439011",
        "title": "星巴克消费折扣",
        "description": "持万事达卡在香港星巴克消费享优惠",
        "merchantName": "Starbucks",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439011"
      },
      {
        "offerId": "507f1f77bcf86cd799439012",
        "title": "米其林餐厅返现",
        "description": "万事达卡持卡人在米其林推荐餐厅消费享返现",
        "merchantName": "Michelin Restaurants",
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

### 无匹配结果（返回默认推荐）

```json
{
  "code": "S000000",
  "msg": "Success",
  "data": {
    "offers": [
      {
        "offerId": "507f1f77bcf86cd799439020",
        "title": "购物商城折扣",
        "description": "万事达卡在百货商城享优惠",
        "merchantName": "Shopping Mall",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439020"
      },
      {
        "offerId": "507f1f77bcf86cd799439021",
        "title": "电影票优惠",
        "description": "万事达卡观影享折扣",
        "merchantName": "Cinema",
        "offerUrl": "https://offer.example.com/offer-507f1f77bcf86cd799439021"
      },
      {
        "offerId": "507f1f77bcf86cd799439022",
        "title": "出行打车优惠",
        "description": "万事达卡打车享返现",
        "merchantName": "Ride Hailing",
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

## 处理规则

1. **仅 `code=S000000` 时展示结果**；本接口**无业务错误码**，参数不规范时服务端忽略问题部分或返回默认推荐。
2. **默认推荐兜底**：`isDefault=true` 时返回 ≤3 条随机参考推荐，无 `queryCacheId`、不分页。出现场景包括：查询词无结果、标签组合无命中、条件无符合权益、无主题等。
3. **排序由服务端完成**：客户端**不重排**，按返回顺序展示。
4. **每页 5 条固定**，不能修改 `pageSize`。

## 错误处理

| HTTP 状态 | 含义 |
|---|---|
| 200 | 成功（检查 `code=S000000`） |
| 400 | 请求参数格式错误 |
| 500 | 服务器错误 |
| 503 | 服务暂时不可用 |
