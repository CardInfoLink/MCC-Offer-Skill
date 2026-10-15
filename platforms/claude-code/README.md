# Claude Code / Agent Skills 适配说明

仓库根目录可直接作为 Agent Skills 源码使用；Claude Code 插件发行包则使用以下结构：

```text
.claude-plugin/
├── plugin.json
└── marketplace.json
└── skills/
    └── mcc-offer-skill/
        ├── SKILL.md
        ├── scripts/
        └── sub-skills/
```

构建插件包：

```powershell
powershell -NoProfile -File tools\release\package.ps1 -Profile testing -Platform claude-plugin -Version 0.1.0-rc.1
```

```sh
sh tools/release/package.sh --profile testing --platform claude-plugin --version 0.1.0-rc.1
```

本地安装时将发行包根目录作为 Claude Code 插件目录；Marketplace 清单中的插件来源是当前目录。插件入口为 `skills/mcc-offer-skill/SKILL.md`，Skill 标识、目录名和 frontmatter 的 `name` 保持一致。不要发布运行结果、`config/data/` 下的临时文件或任何本地凭据。
