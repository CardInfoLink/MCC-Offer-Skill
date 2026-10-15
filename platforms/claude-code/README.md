# Claude Code / Agent Skills 适配说明

发行包根目录：

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

仓库根目录现在提供 Claude Code 的 `.claude-plugin/` 元数据；发行包会额外生成 `skills/mcc-offer-skill/`，用于本地 `--plugin-dir` 插件加载。Marketplace 条目使用 GitHub `git-subdir` source 指向仓库根目录，并显式声明 `skills: ["./"]`，因此 GitHub/官方目录发现和本地发行包加载分别验收。

```text
仓库根目录（Marketplace source）
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
└── SKILL.md

发行包目录（本地插件）
├── .claude-plugin/
└── skills/mcc-offer-skill/SKILL.md
```

构建插件包：

```powershell
powershell -NoProfile -File tools\release\package.ps1 -Profile testing -Platform claude-plugin -Version 0.1.0-rc.1
```

```sh
sh tools/release/package.sh --profile testing --platform claude-plugin --version 0.1.0-rc.1
```

本地安装时将发行包根目录作为 Claude Code 插件目录；Marketplace 清单中的插件来源是当前目录。插件入口为 `skills/mcc-offer-skill/SKILL.md`，Skill 标识、目录名和 frontmatter 的 `name` 保持一致。不要发布运行结果、`config/data/` 下的临时文件或任何本地凭据。
