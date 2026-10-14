# Offer 查询接口

根据本地解析出的主题（意图标签或查询词）和事实条件，返回排好序的权益列表，每页 5 条。服务端不做自然语言理解、银行别名转换或标签纠错。主题怎么选、怎么生成见 `../query.md`。

## 调用契约

- Method：`POST`　Content-Type：`application/json`
- 路径键：`API_QUERY_PATH`（默认 `/api/offer/query`）
- 脚本：按 `../common.md` 的“调用模板”，请求 ID 前缀 `query`

## 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `searchInfo` | string | 否 | 查询词：精简的品牌、商户或优惠模式核心词，最长 20 字符（超出服务端截取）；有值时服务端忽略 `intentTags`；不需要时不传 |
| `intentTags` | array | 否 | 受控标签；无主题时传空数组 |
| `intentTags[].tagName` | string | 是 | 必须来自 `config/tags.txt` |
| `intentTags[].matchScore` | integer | 是 | 1~100，用户意图强度，不是 Offer 得分 |
| `filters` | object / null | 否 | 事实条件；无条件传 `null` |
| `filters.banks` | string[] | 否 | `banks.txt` 里的标准银行名 |
| `filters.regions` | string[] | 否 | 用户提到的地区 |
| `filters.timeRange.start` / `end` | string | 否 | `yyyy-MM-dd`，格式不对或起止颠倒时服务端整段忽略 |

三种请求形态（`searchInfo` 与 `intentTags` 二选一）：

```json
{"searchInfo":"星巴克","filters":{"regions":["香港"]}}
```

```json
{"intentTags":[{"tagName":"温泉度假","matchScore":85},{"tagName":"亲子","matchScore":60}],
 "filters":{"banks":["ABC"],"regions":["香港"],"timeRange":{"start":"2026-10-01","end":"2026-12-31"}}}
```

```json
{"intentTags":[],"filters":{"regions":["香港"]}}
```

## 响应

| 字段 | 说明 |
|---|---|
| `offers` | 当前页权益，服务端已按顺序排好；每项有 `offerId`、`title`、`description`、`merchantName`、`offerUrl` |
| `totalCount` | 全部命中数量 |
| `queryCacheId` | 分页缓存 ID（`isDefault=true` 时为空） |
| `currentPage` / `totalPages` / `hasMore` | 分页信息，首页 `currentPage=1` |
| `isDefault` | 是否为默认推荐兜底 |

## 处理规则

1. `S000000` 才进入展示；本接口**没有业务错误码**，参数不规范时服务端忽略问题部分或返回默认推荐。
2. 保存 `queryCacheId`、本次的 `searchInfo` 或 `intentTags`、`filters`，供 `more.md` 使用。
3. `isDefault=true`：随机 ≤3 条参考推荐，无 `queryCacheId`、不分页。以下情况都会出现：查询词没找到、标签或条件没有命中、无主题。按 `../result.md` 的场景表说明。
4. 排序、过滤全部在服务端完成，客户端不重排。
