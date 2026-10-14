# 接口契约索引

接口契约已按接口拆分，本文件只作为兼容入口和索引，不再重复维护字段定义。

## 公共脚本契约

- `api/script-contract.md`：`api-call.sh`/`api-call.ps1` 参数、退出码、公共调用模板。
- `api/config-sync.md`：配置同步脚本和七段响应协议。

## 业务接口

| 场景 | 契约文件 | 调用脚本 |
|---|---|---|
| 标准查询 | `api/offer-query.md` | `api-call.sh` / `api-call.ps1` |
| 详情 | `api/offer-detail.md` | `api-call.sh` / `api-call.ps1` |
| 相似推荐 | `api/offer-recommend.md` | `api-call.sh` / `api-call.ps1` |
| 分页 | `api/offer-more.md` | `api-call.sh` / `api-call.ps1` |

## 读取规则

能力子 SKILL 只读取当前场景对应的契约文件，不要一次性加载所有接口文档：

- `query.md` → `api/offer-query.md`
- `detail.md` → `api/offer-detail.md`
- `recommend.md` → `api/offer-recommend.md`
- `more.md` → `api/offer-more.md`

所有接口返回后的通用展示原则见 `result-template.md`。
