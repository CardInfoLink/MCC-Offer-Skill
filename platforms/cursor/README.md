# Cursor 分发适配

发行包中的入口目录为 `.cursor/skills/mcc-offer-skill/SKILL.md`，目录名与 Skill 的标准标识一致。

## 安装

- 项目级：将发行包内的 `.cursor/skills/mcc-offer-skill/` 复制到项目的 `.cursor/skills/mcc-offer-skill/`。
- 用户级：将同一目录复制到 Cursor 支持的用户 Skill 目录，并保持 `mcc-offer-skill` 目录名不变。
- 验证：打开 Cursor 的 Skills/Agent 能力列表，确认 `mcc-offer-skill` 可被发现；首次运行时按 `SKILL.md` 的启动前置执行同步。

不要复制 `test/`、`.kiro/`、`config/data/` 或本地运行状态；这些内容不属于发行包。
