# 仓库发布说明

本仓库以 GitHub 分支、Tag 和 Marketplace 作为主要发现与分发入口，不启动额外 CI 检查服务，也不要求提交前执行本地验证脚本。

## 发布清单

1. 更新 `CHANGELOG.md` 和 `docs/releases/` 下的版本说明。
2. 确认根 `.claude-plugin/marketplace.json`、Skill 入口和平台说明与目标 Git Ref 一致。
3. 推送目标分支或 Tag 到 GitHub。
4. 按平台实际入口进行安装和使用；WorkBuddy ZIP、npm 包和 GitHub Release 附件作为后续可选渠道。

建议仓库 Topics：`agent-skills`、`mastercard`、`credit-card`、`offers`、`cursor`、`claude-code`、`openclaw`、`workbuddy`。Topics 属于 GitHub 远端仓库设置，不由本地自动修改。
