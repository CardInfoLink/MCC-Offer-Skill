# Claude Code / Agent Skills 适配说明

## 仓库根目录（GitHub Marketplace 直接发现）

```text
<repository-root>/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── SKILL.md
```

## 发行包根目录（本地 `--plugin-dir` 加载）

```text
<package-root>/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── skills/
    └── mcc-offer-skill/
        ├── SKILL.md
        ├── scripts/
        └── sub-skills/
```

## 发现与加载

Claude Code、Cursor、OpenClaw 等平台直接从 GitHub 分支或 Tag 发现仓库根目录的 `.claude-plugin/` 和根 `SKILL.md`；无需本地检查脚本或提前生成发行包。

本地 `--plugin-dir` 加载时，将发行包根目录作为插件目录入口。发行包会重组为 `skills/mcc-offer-skill/` 结构，便于同一发行包包含多个 Skill 时的标准化管理；但当前单 Skill 仓库仍可直接以根 `SKILL.md` 加载。

Skill 标识、目录名、frontmatter `name` 和 `.claude-plugin/marketplace.json` 中的 `name` 保持一致为 `mcc-offer-skill`。

## 发行范围

不发布运行结果、`config/data/` 下的临时文件、`.kiro/` 或任何本地凭据。WorkBuddy ZIP、npm 包和 GitHub Release 资产属于后续可选分发渠道。
