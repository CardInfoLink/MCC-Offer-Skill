# 相似推荐能力

## 能力定位

处理“还有类似的吗”的相似推荐链路。主 `SKILL.md` 已完成场景路由，本能力直接使用已确认的 `baseOfferId`。

## 依赖

按顺序读取：

1. `_shared.md`：脚本、配置、公共响应和状态保存。
2. `api/offer-recommend.md`：推荐请求、响应和脚本示例。
3. `result-template.md`：列表展示规则。

## 处理流程

1. 从当前详情或列表上下文确认 `baseOfferId`。
2. 不重新解析用户自然语言标签，不向服务端发送 `intentTags`。
3. 按 `api/offer-recommend.md` 构造 `{baseOfferId}`，生成带 `recommend-` 前缀的请求 ID，通过 `api-call` 调用接口。
4. 根据脚本返回的 `RESPONSE_FILE` 读取原始响应，再检查退出码和顶层 `code`。
5. 按服务端顺序展示推荐列表；`isDefault=true` 时说明是通用推荐。
6. 保存 `queryCacheId`、当前页和 `baseOfferId`，后续更多转到 `more.md`。

## 不允许

- 不把基准 Offer 自己添加到结果中。
- 不自行补造相似权益。
- 不丢弃 `baseOfferId`，否则缓存失效时无法重新匹配。
