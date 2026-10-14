# 相似推荐能力

处理“还有类似的吗”。场景路由已由 `SKILL.md` 完成，本能力直接使用已确认的 `baseOfferId`。

## 依赖

进入本能力后，在同一轮里一次性并行读完：`common.md`（脚本调用、响应判定、会话状态、清理）、`api/offer-recommend.md`（请求与响应）、`result.md`（列表展示）、`config/client.conf`（接口地址）。同会话已读过且没变的不用重读。

## 处理流程

1. **确定 `baseOfferId`**：优先用当前正在看的详情；否则按用户的指代从最近展示的列表里解析（规则同 `detail.md`）。对应不上就请用户选一个，不猜。
2. 请求体只有 `{"baseOfferId":"..."}`，不重新解析标签，不发送 `intentTags`、`searchInfo`、`filters`。
3. 按 `common.md` 的“调用模板”调用，请求 ID 前缀 `recommend`。
4. 读取 `RESPONSE_FILE`，按 `common.md` 判定响应后按下表处理。
5. 保存 `queryCacheId`、当前页和 `baseOfferId`；后续“更多”转 `more.md`。

| 响应 | 做法 |
|---|---|
| `isDefault=false` | 按服务端顺序展示相似权益；`hasMore=true` 时结尾问是否继续 |
| `isDefault=true`（基准 Offer 已失效，或没有相似项） | 按 `result.md` 的场景表说明是通用推荐；不提供“更多” |

## 不允许

- 不把基准 Offer 自己放进结果（服务端已排除，客户端也不要补）。
- 不自行补造相似权益。
- 不丢弃 `baseOfferId`，否则缓存失效后无法重新匹配。
