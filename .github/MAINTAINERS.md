# 仓库自动化与发布说明

本仓库通过 GitHub Actions 在发布前执行 Agent Skills 元数据、发行脚本和包边界校验。CI 只负责验证，不下载远程配置、不写入数据库，也不替代 Skill 运行时。

## Release 清单

1. 更新 `CHANGELOG.md` 和 `docs/releases/` 下的版本说明。
2. 执行 `tools/release/check.ps1|sh`，验证仓库元数据、平台入口、脚本语法和运行时数据边界。
3. 按平台实际发现方式使用 GitHub 分支或 Tag 验收；WorkBuddy ZIP、npm `.tgz` 和 GitHub Release 附件作为后续可选渠道。
4. 将版本说明、CI 结果和平台验收证据记录到 GitHub Release 或验收文档。

建议仓库 Topics：`agent-skills`、`mastercard`、`credit-card`、`offers`、`cursor`、`claude-code`、`openclaw`、`workbuddy`。Topics 属于 GitHub 远端仓库设置，不由本地 CI 自动修改。
