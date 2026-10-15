# 仓库自动化与发布说明

本仓库通过 GitHub Actions 在发布前执行 Agent Skills 元数据、发行脚本和包边界校验。CI 只负责验证，不下载远程配置、不写入数据库，也不替代 Skill 运行时。

## Release 清单

1. 更新 `CHANGELOG.md` 和 `docs/releases/` 下的版本说明。
2. 使用 `tools/release/package.ps1|sh --platform all` 构建隔离发行包。
3. 对通用包执行 `tools/release/validate.ps1|sh`，并对 npm 包执行 `npm pack --dry-run`。
4. 将对应 ZIP、npm `.tgz`（如需要）和变更说明上传到 GitHub Release。

建议仓库 Topics：`agent-skills`、`mastercard`、`credit-card`、`offers`、`cursor`、`claude-code`、`openclaw`、`workbuddy`。Topics 属于 GitHub 远端仓库设置，不由本地 CI 自动修改。
