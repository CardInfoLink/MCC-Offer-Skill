param()

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent $PSScriptRoot
$PackageDir = Join-Path $SourceRoot 'dist'

# 清空 dist 避免残留
if (Test-Path -LiteralPath $PackageDir) {
    Remove-Item -LiteralPath $PackageDir -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $PackageDir -Force

function Fail([string]$Reason) { throw "ERROR=$Reason" }

function Extract-FrontmatterValue {
    param([string]$Key, [string]$FilePath)
    $lines = @(Get-Content -LiteralPath $FilePath -Encoding UTF8)
    $inFrontmatter = $false
    $fmCount = 0
    $inMetadata = $false
    $metadataIndent = 0
    
    foreach ($line in $lines) {
        if ($line -match '^\s*---\s*$') {
            $fmCount++
            if ($fmCount -eq 1) {
                $inFrontmatter = $true
                continue
            } elseif ($fmCount -eq 2) {
                break
            }
        }
        
        if (-not $inFrontmatter) { continue }
        
        # 检查 metadata: 块开始
        if ($line -match '^\s*metadata:\s*$') {
            $inMetadata = $true
            $metadataIndent = ($line.Length - $line.TrimStart().Length)
            continue
        }
        
        # 如果在 metadata 块中
        if ($inMetadata) {
            $currentIndent = $line.Length - $line.TrimStart().Length
            $trimmed = $line.Trim()
            
            # 检查块结束（同级或更小缩进的非空行）
            if ($trimmed -ne '' -and $currentIndent -le $metadataIndent -and -not $line.StartsWith(' ')) {
                $inMetadata = $false
            }
            
            # 在 metadata 块内查找键值
            if ($trimmed -match "^$Key`:\s*(.+)$") {
                return $matches[1].Trim()
            }
        }
        
        # 在顶层查找键值（非 metadata 块）
        if (-not $inMetadata -and $line -match "^$Key`:\s*(.+)$") {
            return $matches[1].Trim()
        }
    }
    return $null
}

function WriteUtf8File([string]$Path, [string]$Content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$SkillMdPath = Join-Path $SourceRoot 'SKILL.md'
if (-not (Test-Path -LiteralPath $SkillMdPath)) { Fail 'MISSING_SKILL.md' }

# Extract all metadata from SKILL.md
$NameId = Extract-FrontmatterValue 'name' $SkillMdPath
$DisplayName = Extract-FrontmatterValue 'display_name' $SkillMdPath
$Version = Extract-FrontmatterValue 'version' $SkillMdPath
$Description = Extract-FrontmatterValue 'description' $SkillMdPath
$License = Extract-FrontmatterValue 'license' $SkillMdPath
$Author = Extract-FrontmatterValue 'author' $SkillMdPath
$Homepage = Extract-FrontmatterValue 'homepage' $SkillMdPath
$Category = Extract-FrontmatterValue 'category' $SkillMdPath
$Slug = Extract-FrontmatterValue 'slug' $SkillMdPath

# 使用 NameId 作为 slug（如果没有明确提供）
if (-not $Slug) {
    $Slug = $NameId
}

# DisplayName 作为最终的显示名称（若未提供则用 NameId）
if (-not $DisplayName) {
    $DisplayName = $NameId
}

if (-not $NameId) { Fail 'MISSING_name' }
if (-not $Version) { Fail 'MISSING_version' }
if (-not $Description) { Fail 'MISSING_description' }

$licenseVal = if ($License) { $License } else { "MIT" }

# 自动更新 .claude-plugin 目录
$claudePluginDir = Join-Path $SourceRoot '.claude-plugin'
if (Test-Path -LiteralPath $claudePluginDir) {
    Remove-Item -LiteralPath $claudePluginDir -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $claudePluginDir -Force

# Create plugin.json
$pluginObj = [ordered]@{
    name = $Slug
    version = $Version
    description = $Description
    author = [ordered]@{ name = $Author }
    homepage = $Homepage
    repository = "https://github.com/CardInfoLink/MCC-Offer-Skill"
    license = $licenseVal
    keywords = @("agent-skills", "mastercard", "credit-card", "offers")
}

function FormatJsonWith2Spaces([string]$JsonStr) {
    $lines = $JsonStr -split "`n"
    $result = @()
    $indentLevel = 0
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '') { continue }
        
        if ($trimmed -match '^\}' -or $trimmed -match '^\]') {
            $indentLevel = [Math]::Max(0, $indentLevel - 1)
        }
        
        $indent = ' ' * ($indentLevel * 2)
        $result += $indent + $trimmed
        
        if ($trimmed -match '[{\[]$' -and -not ($trimmed -match '\{\s*\}' -or $trimmed -match '\[\s*\]')) {
            $indentLevel++
        }
    }
    
    return $result -join "`n"
}

$pluginJsonStr = $pluginObj | ConvertTo-Json -Depth 10
$pluginJsonStr = FormatJsonWith2Spaces $pluginJsonStr
WriteUtf8File (Join-Path $claudePluginDir 'plugin.json') $pluginJsonStr

# Create marketplace.json
$marketplaceObj = [ordered]@{
    name = "$Slug-marketplace"
    description = "$DisplayName 插件目录。"
    owner = [ordered]@{ name = $Author }
    plugins = @(
        [ordered]@{
            name = $Slug
            description = $Description
            author = [ordered]@{ name = $Author }
            category = $Category
            source = "."
            strict = $false
            homepage = $Homepage
        }
    )
}
$marketplaceJsonStr = $marketplaceObj | ConvertTo-Json -Depth 10
$marketplaceJsonStr = FormatJsonWith2Spaces $marketplaceJsonStr
WriteUtf8File (Join-Path $claudePluginDir 'marketplace.json') $marketplaceJsonStr

# 自动更新 .cursor-plugin 目录
$cursorPluginDir = Join-Path $SourceRoot '.cursor-plugin'
if (Test-Path -LiteralPath $cursorPluginDir) {
    Remove-Item -LiteralPath $cursorPluginDir -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $cursorPluginDir -Force

# Cursor Plugin：根目录已有 SKILL.md，未指定 skills 字段时按 Cursor 单 Skill 插件处理
$cursorDescription = ($Description -replace '（如.*?）', '').Trim()
$cursorPluginObj = [ordered]@{
    name = $Slug
    description = $cursorDescription
    version = $Version
    author = [ordered]@{ name = $Author }
    homepage = $Homepage
    repository = "https://github.com/CardInfoLink/MCC-Offer-Skill"
    license = $licenseVal
    keywords = @("agent-skills", "mastercard", "credit-card", "offers")
    skills = "."
}
$cursorPluginJsonStr = $cursorPluginObj | ConvertTo-Json -Depth 10
$cursorPluginJsonStr = FormatJsonWith2Spaces $cursorPluginJsonStr
WriteUtf8File (Join-Path $cursorPluginDir 'plugin.json') $cursorPluginJsonStr

# Cursor Marketplace：保持手写版本结构，source 指向仓库根目录
$cursorMarketplaceObj = [ordered]@{
    name = "$Slug-marketplace"
    owner = [ordered]@{ name = $Author }
    plugins = @(
        [ordered]@{
            name = $Slug
            source = "."
            description = $cursorDescription
            version = $Version
            author = [ordered]@{ name = $Author }
            homepage = $Homepage
            repository = "https://github.com/CardInfoLink/MCC-Offer-Skill"
            license = $licenseVal
            keywords = @("agent-skills", "mastercard", "credit-card", "offers")
            skills = "."
        }
    )
}
$cursorMarketplaceJsonStr = $cursorMarketplaceObj | ConvertTo-Json -Depth 10
$cursorMarketplaceJsonStr = FormatJsonWith2Spaces $cursorMarketplaceJsonStr
WriteUtf8File (Join-Path $cursorPluginDir 'marketplace.json') $cursorMarketplaceJsonStr

# 从源复制 2 个生产目录：workbuddy、doubaowork
foreach ($platform in @('workbuddy', 'doubaowork')) {
    $DirName = "mcc-offer-skill-$platform"
    $TargetDir = Join-Path $PackageDir $DirName
    $null = New-Item -ItemType Directory -Path $TargetDir -Force

    # 复制源目录的所有子目录
    foreach ($dir in @('scripts', 'sub-skills', 'config', 'references')) {
        $src = Join-Path $SourceRoot $dir
        $dst = Join-Path $TargetDir $dir
        if (Test-Path -LiteralPath $src -PathType Container) {
            $null = New-Item -ItemType Directory -Path $dst -Force
            Get-ChildItem -LiteralPath $src -Force | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $dst -Recurse -Force
            }
        }
    }

    # ===== SKILL.md 处理 =====
    if ($platform -eq 'workbuddy') {
        # WorkBuddy：做 frontmatter 映射
        $skillContent = Get-Content -LiteralPath $SkillMdPath -Raw -Encoding UTF8
        $lines = $skillContent -split "`n"
        $fmCount = 0
        $bodyStartIdx = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*---\s*$') {
                $fmCount++
                if ($fmCount -eq 2) {
                    $bodyStartIdx = $i + 1
                    break
                }
            }
        }
        $body = if ($bodyStartIdx -gt 0 -and $bodyStartIdx -lt $lines.Count) {
            ($lines[$bodyStartIdx..($lines.Count-1)] -join "`n")
        } else {
            ""
        }

        $skillFrontmatter = @"
---
name: $Slug
display_name: $DisplayName
description: $Description
category: $Category
version: $Version
author: $Author
---
"@

        $skillMdContent = $skillFrontmatter + $body
    } else {
        # DouBaoWork：SKILL.md 保持原始，直接复制
        $skillMdContent = Get-Content -LiteralPath $SkillMdPath -Raw -Encoding UTF8
    }

    $skillMdDst = Join-Path $TargetDir 'SKILL.md'
    WriteUtf8File $skillMdDst $skillMdContent

    # ===== 打包生产 ZIP =====
    $ZipFileName = "mcc-offer-skill-$platform.zip"
    $ZipPath = Join-Path $PackageDir $ZipFileName

    Push-Location $TargetDir
    try {
        $items = Get-ChildItem -LiteralPath $TargetDir -Force
        Compress-Archive -Path $items -DestinationPath $ZipPath -Force
    } finally {
        Pop-Location
    }

    $PlatformLabel = if ($platform -eq 'workbuddy') { "WorkBuddy" } else { "DouBaoWork" }
    Write-Host "$PlatformLabel PRODUCTION PACKAGE: $ZipFileName"
}

Write-Host ""
Write-Host "SUMMARY:"
Write-Host ("NAME_ID=" + $NameId)
Write-Host ("DISPLAY_NAME=" + $DisplayName)
Write-Host ("VERSION=" + $Version)
Write-Host ("SLUG=" + $Slug)
Write-Host ("CATEGORY=" + $Category)
Write-Host ("WORKBUDDY_PRODUCTION_DIR=" + (Join-Path $PackageDir "mcc-offer-skill-workbuddy"))
Write-Host ("WORKBUDDY_PRODUCTION_ZIP=" + (Join-Path $PackageDir "mcc-offer-skill-workbuddy.zip"))
Write-Host ("DOUBAOWORK_PRODUCTION_DIR=" + (Join-Path $PackageDir "mcc-offer-skill-doubaowork"))
Write-Host ("DOUBAOWORK_PRODUCTION_ZIP=" + (Join-Path $PackageDir "mcc-offer-skill-doubaowork.zip"))
Write-Host ("CLAUDE_PLUGIN=" + $claudePluginDir)
Write-Host ("CURSOR_PLUGIN=" + $cursorPluginDir)
Write-Host "PACKAGE=SUCCESS"
