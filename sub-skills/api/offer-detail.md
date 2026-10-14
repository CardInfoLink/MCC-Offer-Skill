# Offer 详情接口

根据已确定的 Offer ID 获取详情，不经过意图解析。

## 调用契约

- Method：`GET`
- 路径键：`API_DETAIL_PATH`（默认 `/api/offer/detail`），URL 为 `${API_BASE_URL}${API_DETAIL_PATH}/{offerId}`
- 脚本：按 `../common.md` 的 GET 模板，请求 ID 前缀 `detail`；URL 只能由配置里的地址和已确认的 `offerId` 拼成，不接受用户提供的任意目标 URL

## 响应字段

`offerId`、`title`、`description`、`merchantName`、`offerSummary`、`benefitType`、`banks`、`regions`、`startTime`、`endTime`、`eligibilityRequirement`、`tags[]`（`tagName`、`relevanceScore`）、`offerUrl`。

## 处理规则

- `offerUrl` 原样提供，不自行拼接或替换。
- `relevanceScore` 是内部相关度，不展示。
- `F080104`：Offer 不存在、已删除或已过期，这是本 Skill 里**唯一的业务错误码**。
- 展示规则见 `../detail.md`；详情响应没有分页字段。
