# Offer 相似推荐接口

根据已确定的 Offer ID 查找相似权益。服务端用基准 Offer 的标签推荐，**结果和兜底都排除基准 Offer 自身**。

## 调用契约

- Method：`POST`　Content-Type：`application/json`
- 路径键：`API_RECOMMEND_PATH`（默认 `/api/offer/recommend`）
- 脚本：按 `../common.md` 的"调用模板"，请求 ID 前缀 `recommend`

## 请求

```json
{"baseOfferId":"507f1f77bcf86cd799439011"}
```

`baseOfferId` 必须来自当前对话里的详情或列表，不让用户输入无法确认的任意 ID 后直接调用。只传这一个字段，不传 `intentTags`、`searchInfo` 或 `filters`。

## 响应与处理

响应字段与查询接口相同：`offers`、`totalCount`、`queryCacheId`、`currentPage`、`totalPages`、`hasMore`、`isDefault`。

- 正常：按服务端顺序展示；保存 `queryCacheId`、当前页和 `baseOfferId`，后续"更多"转 `more.md`。
- `isDefault=true`：基准 Offer 不存在、已删除、已过期，或没有相似项。服务端不报错，返回 ≤3 条默认推荐，无 `queryCacheId`；按 `../result.md` 的场景表说明。
