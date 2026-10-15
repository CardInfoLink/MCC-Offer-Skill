# OpenClaw / ArkClaw 分发适配

发行包中的入口目录为 `skills/mcc-offer-skill/SKILL.md`。将整个 `skills/mcc-offer-skill/` 目录放入 OpenClaw 配置的 Skills 根目录即可发现。

## 安装与优先级

1. 优先使用用户配置目录中的本地 Skill；项目级目录用于项目随附版本。
2. 保持目录名 `mcc-offer-skill` 与 `SKILL.md` frontmatter 的 `name` 一致。
3. 本地覆盖只覆盖同名发行包，不能把测试数据或运行时响应目录加入 Skill 根目录。
4. 发行包不包含 `test/`、`.kiro/`、`config/data/` 和本地状态；升级时用新版本目录替换旧版本目录。

OpenClaw 集成复用核心 `SKILL.md` 与双 Shell 脚本，不复制或修改业务逻辑。
