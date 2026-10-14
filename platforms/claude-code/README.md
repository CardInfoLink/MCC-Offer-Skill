# Claude Code / Agent Skills 适配说明

使用仓库根目录作为 Skill 包。平台入口是 `SKILL.md`，`sub-skills/`、`scripts/` 和 `config/` 与入口文件保持同级。激活时根据宿主 Shell 选择 POSIX `.sh` 脚本或 Windows PowerShell `.ps1` 脚本。

不要发布运行结果、`config/data/req/`、`config/data/res/` 下的临时文件或任何本地凭据。
