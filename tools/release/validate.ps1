[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDir
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Reason) { throw "VALIDATION_FAILED=$Reason" }

foreach ($path in @('SKILL.md', 'LICENSE', 'config\client.conf', 'scripts', 'sub-skills')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageDir $path))) { Fail "MISSING_$path" }
}
$skill = [System.IO.File]::ReadAllText((Join-Path $PackageDir 'SKILL.md'), [System.Text.Encoding]::UTF8)
if ([regex]::Match($skill, '(?m)^name:\s*(\S+)').Groups[1].Value -ne 'mcc-offer-skill') { Fail 'SKILL_NAME_INVALID' }
$client = [System.IO.File]::ReadAllText((Join-Path $PackageDir 'config\client.conf'), [System.Text.Encoding]::UTF8)
if ($client -match '(?m)^LOCAL_CLIENT_ID=.+$|^LOCAL_CONFIG_VERSION=.+$|^LOCAL_LAST_SYNC_DATE=.+$') { Fail 'LOCAL_STATE_NOT_EMPTY' }
foreach ($path in @('test', '.git', '.kiro', '.idea', 'config\data')) {
    if (Test-Path -LiteralPath (Join-Path $PackageDir $path)) { Fail "FORBIDDEN_PATH_$path" }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PackageDir 'scripts') -Filter '*.ps1' -File) {
    $null = [scriptblock]::Create([System.IO.File]::ReadAllText($file.FullName))
}
[Console]::Out.WriteLine('VALIDATION=PASS')
exit 0
