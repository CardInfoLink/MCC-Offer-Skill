[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
function Fail([string]$Reason) { throw "CHECK_FAILED=$Reason" }

$required = @(
    'SKILL.md', 'README.md', 'LICENSE', 'CHANGELOG.md',
    'scripts\init.sh', 'scripts\call.sh', 'scripts\clean.sh',
    'scripts\init.ps1', 'scripts\call.ps1', 'scripts\clean.ps1',
    'sub-skills', 'config\client.conf', 'config\tags.txt', 'config\regions.txt', 'config\banks.txt',
    '.claude-plugin\plugin.json', '.claude-plugin\marketplace.json',
    'platforms\workbuddy\manifest.yaml', 'platforms\npm\package.json'
)
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $item))) { Fail "MISSING_SOURCE=$item" }
}

$skill = [System.IO.File]::ReadAllText((Join-Path $sourceRoot 'SKILL.md'), [System.Text.Encoding]::UTF8)
if ([regex]::Match($skill, '(?m)^name:\s*(\S+)').Groups[1].Value -ne 'mcc-offer-skill') { Fail 'SKILL_NAME_INVALID' }

$client = [System.IO.File]::ReadAllText((Join-Path $sourceRoot 'config\client.conf'), [System.Text.Encoding]::UTF8)
if ($client -match '(?m)^LOCAL_CLIENT_ID=.+$|^LOCAL_CONFIG_VERSION=.+$|^LOCAL_LAST_SYNC_DATE=.+$') { Fail 'CLIENT_CONFIG_LOCAL_STATE_NOT_EMPTY' }

foreach ($dataDir in @('config\data\req', 'config\data\res')) {
    $path = Join-Path $sourceRoot $dataDir
    if (Test-Path -LiteralPath $path) {
        $runtimeFiles = Get-ChildItem -LiteralPath $path -File -Recurse | Where-Object { $_.Name -ne '.gitkeep' }
        if ($runtimeFiles) { Fail "RUNTIME_DATA_PRESENT=$dataDir" }
    }
}

$plugin = [System.IO.File]::ReadAllText((Join-Path $sourceRoot '.claude-plugin\plugin.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$marketplace = [System.IO.File]::ReadAllText((Join-Path $sourceRoot '.claude-plugin\marketplace.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$npm = [System.IO.File]::ReadAllText((Join-Path $sourceRoot 'platforms\npm\package.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
if ($plugin.name -ne 'mcc-offer-skill') { Fail 'PLUGIN_NAME_INVALID' }
$entry = @($marketplace.plugins | Where-Object { $_.name -eq 'mcc-offer-skill' })[0]
if ($null -eq $entry -or $entry.source.source -ne 'git-subdir') { Fail 'MARKETPLACE_SOURCE_INVALID' }
if ($entry.source.path -ne '.') { Fail 'MARKETPLACE_PATH_INVALID' }
if (@($entry.skills) -notcontains './') { Fail 'MARKETPLACE_SKILL_PATH_INVALID' }
if ($npm.name -ne 'mcc-offer-skill' -or $npm.private -eq $true) { Fail 'NPM_METADATA_INVALID' }

$manifest = [System.IO.File]::ReadAllText((Join-Path $sourceRoot 'platforms\workbuddy\manifest.yaml'), [System.Text.Encoding]::UTF8)
if ($manifest -notmatch '(?m)^name:\s*mcc-offer-skill\s*$') { Fail 'WORKBUDDY_NAME_INVALID' }
if ($manifest -notmatch '(?m)^entry:\s*SKILL\.md\s*$') { Fail 'WORKBUDDY_ENTRY_INVALID' }

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'scripts') -Filter '*.ps1' -File) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) { Fail "POWERSHELL_SYNTAX_$($file.Name)" }
}
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'check.ps1'), [ref]$null, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { Fail 'POWERSHELL_SYNTAX_check.ps1' }

[Console]::Out.WriteLine('CHECK=PASS')
exit 0
