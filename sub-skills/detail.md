# 详情能力

## 能力定位

处理用户查看确定 Offer 详情的链路。主 `SKILL.md` 已判断这是详情场景，本能力不再做意图解析。

## 依赖

按顺序读取：

1. `_shared.md`：脚本选择、公共响应和安全边界。
2. `api/offer-detail.md`：详情请求字段、URL 拼接和脚本示例。
3. `result-template.md`：通用字段展示规则。

## 处理流程

1. 从当前对话或已展示列表中取得确定的 `offerId`。
2. 按 `api/offer-detail.md` 使用 `GET` 调用 `api-call`，生成带 `detail-` 前缀的请求 ID；不要让脚本接收用户提供的任意目标 URL。
3. 根据脚本返回的 `RESPONSE_FILE` 读取原始响应，再检查退出码和顶层 `code`。
4. 成功时展示标题、描述、商户、摘要、权益类型、适用银行/地区、有效期、参与条件和标签。
5. 将服务端返回的 `offerUrl` 原样提供给用户。
6. 用户询问类似权益时，保存当前 `offerId` 作为 `baseOfferId` 并转到 `recommend.md`。

## 不允许

- 不重新走意图解析。
- 不自行拼接、改写或替换 `offerUrl`。
- 不把 `relevanceScore` 当作用户评价或优惠力度。
