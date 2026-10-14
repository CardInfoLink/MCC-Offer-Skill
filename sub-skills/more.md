# 分页能力

## 能力定位

处理用户要求“更多/下一页/再来一些”的分页链路。主 `SKILL.md` 已完成场景路由，本能力只使用会话中已经保存的首次条件。

## 依赖

按顺序读取：

1. `_shared.md`：脚本、配置、公共响应和会话状态。
2. `api/offer-more.md`：分页请求、缓存失效语义和脚本示例。
3. `result-template.md`：列表分页展示规则。

## 处理流程

1. 读取 `queryCacheId` 和目标 `page`。
2. 查询场景原样带上首次 `intentTags`、`filters`；推荐场景原样带上 `baseOfferId`。
3. 按 `api/offer-more.md` 生成带 `more-` 前缀的请求 ID，通过 `api-call` 调用接口；不能只传 queryCacheId 和 page。
4. 根据脚本返回的 `RESPONSE_FILE` 读取原始响应，再检查退出码、顶层 `code` 和 `data.currentPage`。
5. 以响应中的 `queryCacheId`、`currentPage`、`totalPages`、`hasMore` 更新会话状态。
6. 如果缓存过期导致服务端重新匹配，按返回的第 1 页展示，不要求用户重新描述需求。

## 不允许

- 不传 `pageSize`。
- 不把旧缓存 ID 强行用于下一次翻页。
- 不因缓存过期直接提示用户重新开始查询。
