# Offer 分页接口

获取查询或相似推荐的下一页。缓存失效时服务端用请求里携带的原始条件重新匹配并返回第 1 页，不需要用户重新表达需求。

## 调用契约

- Method：`POST`　Content-Type：`application/json`
- 路径键：`API_MORE_PATH`（默认 `/api/offer/more`）
- 脚本：按 `../common.md` 的"调用模板"，请求 ID 前缀 `more`
- 每页固定 5 条，**不能传 `pageSize`**。

## 请求

必须带上首次请求的全部条件，**不能只传 `queryCacheId` 和 `page`**。用不到的字段传空串、空数组或 `null`：

| 首次是 | `searchInfo` | `intentTags` | `filters` | `baseOfferId` |
|---|---|---|---|---|
| 查询词查询 | 原词 | `[]` | 原条件 | `""` |
| 标签查询 | `""` | 原标签 | 原条件 | `""` |
| 无主题查询 | `""` | `[]` | 原条件 | `""` |
| 相似推荐 | `""` | `[]` | `null` | 基准 `offerId` |

```json
{
  "queryCacheId":"cache_123456",
  "page":2,
  "searchInfo":"星巴克",
  "intentTags":[],
  "filters":{"regions":["香港"]},
  "baseOfferId":""
}
```

## 响应与处理

| 返回 | 含义 | 怎么做 |
|---|---|---|
| `isDefault=false`，`currentPage` 等于请求的 `page` | 正常的下一页 | 展示，更新状态 |
| `isDefault=false`，`currentPage=1` 而请求 `page>1` | 缓存过期，服务端已重新匹配 | 按第 1 页展示，**换用新的 `queryCacheId`**，不要说页号 |
| `isDefault=true` | 没有更多符合条件的权益（页号越界，或重新匹配后没有结果） | 返回 ≤3 条参考推荐，无 `queryCacheId`，不再提供"更多"；说明见 `../result.md` |

以响应里的 `queryCacheId`、`currentPage`、`totalPages`、`hasMore` 更新会话状态；条件不丢，推荐场景的 `baseOfferId` 也不丢。
