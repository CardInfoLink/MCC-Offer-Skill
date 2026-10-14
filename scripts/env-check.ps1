[CmdletBinding()]
param(
    [string]$ConfigDir = '',
    [string]$CheckUrl = ''
)

if ([string]::IsNullOrWhiteSpace($ConfigDir)) { $ConfigDir = Join-Path $PSScriptRoot '..\config' }
$ErrorActionPreference = 'Stop'

function Fail([int]$Code, [string]$Reason, [string]$Suggestion) {
    [Console]::Error.WriteLine('STATUS=FAILED')
    [Console]::Error.WriteLine("REASON=$Reason")
    [Console]::Error.WriteLine("SUGGESTION=$Suggestion")
    exit $Code
}

try {
    $resolvedConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)
} catch {
    Fail 12 'CONFIG_DIR_UNAVAILABLE' 'INVALID_CONFIG_PATH'
}

if (-not (Test-Path -LiteralPath $resolvedConfigDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $resolvedConfigDir -Force | Out-Null
    } catch {
        Fail 12 'CONFIG_DIR_UNAVAILABLE' 'CREATE_WRITABLE_CONFIG_DIR'
    }
}

$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($null -eq $curl) {
    Fail 11 'CURL_MISSING' 'INSTALL_CURL_OR_USE_SUPPORTED_ENVIRONMENT'
}

$writeTest = Join-Path $resolvedConfigDir ('.write-test.' + [guid]::NewGuid().ToString('N'))
try {
    [System.IO.File]::WriteAllText($writeTest, '')
    Remove-Item -LiteralPath $writeTest -Force
} catch {
    if (Test-Path -LiteralPath $writeTest) { Remove-Item -LiteralPath $writeTest -Force -ErrorAction SilentlyContinue }
    Fail 12 'CONFIG_DIR_NOT_WRITABLE' 'GRANT_CONFIG_WRITE_PERMISSION'
}

$network = 'NOT_CHECKED'
if (-not [string]::IsNullOrWhiteSpace($CheckUrl)) {
    $statusText = ''
    try {
        $statusText = (& curl.exe -sS --connect-timeout 5 --max-time 10 -o NUL -w '%{http_code}' $CheckUrl 2>$null | Out-String).Trim()
    } catch {
        Fail 13 'NETWORK_UNAVAILABLE' 'CHECK_NETWORK_AND_RETRY'
    }
    if ($LASTEXITCODE -ne 0 -or $statusText -eq '000' -or [string]::IsNullOrWhiteSpace($statusText)) {
        Fail 13 'NETWORK_UNAVAILABLE' 'CHECK_NETWORK_AND_RETRY'
    }
    $network = 'AVAILABLE'
}

[Console]::Out.WriteLine('STATUS=OK')
[Console]::Out.WriteLine('SHELL=POWERSHELL')
[Console]::Out.WriteLine('OS=Windows')
[Console]::Out.WriteLine('CURL=curl.exe')
[Console]::Out.WriteLine("CONFIG_DIR=$resolvedConfigDir")
[Console]::Out.WriteLine("NETWORK=$network")
exit 0
