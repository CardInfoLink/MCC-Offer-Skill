# 分页能力

处理“更多 / 下一页 / 再来一些”。场景路由已由 `SKILL.md` 完成，本能力只使用会话里保存的首次条件。

## 依赖

进入本能力后，在同一轮里一次性并行读完：`common.md`（脚本调用、响应判定、会话状态、清理）、`references/api-offer-more.md`（请求与响应语义）、`result.md`（列表展示）、`config/client.conf`（接口地址）。同会话已读过且没变的不用重读。

## 处理流程

1. 从会话状态取 `queryCacheId`，目标页 = `currentPage + 1`。
2. 带上首次的全部条件：查询场景带原来的 `searchInfo` 或 `intentTags` 和 `filters`，推荐场景带 `baseOfferId`；用不到的字段传空值。不能只传 `queryCacheId` 和 `page`。
3. 按 `common.md` 的“调用模板”调用，请求 ID 前缀 `more`。
4. 读取 `RESPONSE_FILE`，按 `common.md` 判定响应。
5. 按下表处理，并用响应里的 `queryCacheId`、`currentPage`、`totalPages`、`hasMore` 更新会话状态。

| 响应 | 做法 |
|---|---|
| 正常的下一页（`isDefault=false`，页号相符） | 按列表展示；`hasMore=true` 时结尾问是否继续 |
| 缓存过期，服务端重新匹配（`isDefault=false`，请求 `page>1` 却返回 `currentPage=1`） | 当作第 1 页展示，换用新的 `queryCacheId`；不要让用户重新描述需求，也不提页号 |
| `isDefault=true`（没有更多了） | 说明没有更多符合条件的权益，展示参考推荐；不再提供“更多”，会话里的 `hasMore` 置为 `false` |

## 不允许

- 不传 `pageSize`。
- 不继续使用已被替换的旧 `queryCacheId`。
- 不因缓存过期就提示用户重新开始查询。
- 不把用户后来新说的条件混进分页请求：分页冻结首次条件；新条件走新的 query（见 `query.md` 的“条件继承”）。
- 会话里没有 `queryCacheId` 时不调用本接口，回到 `query.md`。
