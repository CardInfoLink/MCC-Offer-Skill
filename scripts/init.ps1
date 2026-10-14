# Offer Skill startup entry: environment check + config sync in one step. Run once at the start of a session; read READY only.
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI).
#
# Stdout, one KEY=VALUE per line:
#   ENV_STATUS=OK | FAILED         FAILED also prints REASON= and SUGGESTION=
#   SYNC_STATUS=CHANGED | UNCHANGED
#   SYNC_REASON=...                only when the sync failed (NETWORK_UNAVAILABLE / INVALID_RESPONSE / INTERFACE_ERROR ...)
#   DICT=OK | MISSING              regions / banks / tags dictionaries present and non-empty
#   DICT_MISSING=a.txt,b.txt       only when DICT=MISSING
#   CONFIG_VERSION=...             local config version (may be empty)
#   READY=YES | NO                 may the caller go on and send business requests?
#   NOT_READY_REASON=...           only when READY=NO: ENV_FAILED / FIRST_SYNC_FAILED / DICT_MISSING
#
# READY=NO has three causes; the exit code is non-zero and the caller MUST stop (no business requests):
#   ENV_FAILED          environment check failed, exit 11 (curl missing) / 12 (config dir unavailable or not writable)
#   FIRST_SYNC_FAILED   first install (no client id yet) and the sync did not succeed, exit 13 (network) / 14 (interface).
#                       A first install must sync successfully; the failure is not recorded as "synced today",
#                       so the next call retries.
#   DICT_MISSING        regions / banks / tags dictionary missing or empty, exit 14
# An already-installed client whose sync fails does NOT block (local dictionaries are kept, READY=YES).
#
# Config sync is special: it leaves NO request/response files. The request body is built on the fly from
# client.conf (LOCAL_CLIENT_ID, LOCAL_CONFIG_VERSION); the response is parsed in memory and the documents under
# config/ are updated directly. One attempt, 10 second timeout.
# With a client id, sync is attempted at most once per day: LOCAL_LAST_SYNC_DATE == today means no network;
# a failed attempt also records today.
[CmdletBinding()]
param(
    [string]$ConfigDir = '',
    [string]$BaseUrl = ''
)

if ([string]::IsNullOrWhiteSpace($ConfigDir)) { $ConfigDir = Join-Path $PSScriptRoot '..\config' }
$ErrorActionPreference = 'Stop'
$ExitNetwork = 13
$ExitInterface = 14
$TimeoutSeconds = 10
$Separator = '=.==.='
$Placeholder = [string][char]0x65E0

function Out-Line([string]$Text) { [Console]::Out.WriteLine($Text) }

# ============================== 1) Environment check: stop on failure ==============================
function Env-Fail([int]$Code, [string]$Reason, [string]$Suggestion) {
    Out-Line 'ENV_STATUS=FAILED'
    Out-Line "REASON=$Reason"
    Out-Line "SUGGESTION=$Suggestion"
    Out-Line 'READY=NO'
    Out-Line 'NOT_READY_REASON=ENV_FAILED'
    exit $Code
}

try {
    $resolvedConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)
} catch {
    Env-Fail 12 'CONFIG_DIR_UNAVAILABLE' 'INVALID_CONFIG_PATH'
}
if (-not (Test-Path -LiteralPath $resolvedConfigDir -PathType Container)) {
    try { New-Item -ItemType Directory -Path $resolvedConfigDir -Force | Out-Null } catch { Env-Fail 12 'CONFIG_DIR_UNAVAILABLE' 'CREATE_WRITABLE_CONFIG_DIR' }
}
if ($null -eq (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Env-Fail 11 'CURL_MISSING' 'INSTALL_CURL_OR_USE_SUPPORTED_ENVIRONMENT'
}
$writeTest = Join-Path $resolvedConfigDir ('.write-test.' + [guid]::NewGuid().ToString('N'))
try {
    [System.IO.File]::WriteAllText($writeTest, '')
    Remove-Item -LiteralPath $writeTest -Force
} catch {
    if (Test-Path -LiteralPath $writeTest) { Remove-Item -LiteralPath $writeTest -Force -ErrorAction SilentlyContinue }
    Env-Fail 12 'CONFIG_DIR_NOT_WRITABLE' 'GRANT_CONFIG_WRITE_PERMISSION'
}
Out-Line 'ENV_STATUS=OK'

# ============================== 2) Config sync ==============================
$clientFile = Join-Path $resolvedConfigDir 'client.conf'

function ConfigValue([string]$Key) {
    if (-not (Test-Path -LiteralPath $clientFile -PathType Leaf)) { return '' }
    foreach ($line in [System.IO.File]::ReadAllLines($clientFile)) {
        if ($line.StartsWith($Key + '=', [System.StringComparison]::Ordinal)) { return $line.Substring($Key.Length + 1) }
    }
    return ''
}
function TrimEnvelope([string]$Value) {
    if ($null -eq $Value) { return '' }
    return $Value.Trim([char[]]"`r`n")
}
function WriteUtf8NoBom([string]$Path, [string]$Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}
function JoinEndpoint([string]$Origin, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Origin)) { return '' }
    return $Origin.TrimEnd('/') + '/' + $Path.TrimStart('/')
}
function JsonEscape([string]$Value) {
    if ($null -eq $Value) { return '' }
    return $Value.Replace('\', '\\').Replace('"', '\"')
}
function SyncDone([string]$Status, [string]$Reason, [int]$Code) {
    return @{ Status = $Status; Reason = $Reason; Code = $Code }
}
# On failure (network error, bad response, server error) record today as the attempt day so it is not retried today.
# First install (no client id) is NOT recorded: sync must succeed, so the next call retries.
# Only the LOCAL_LAST_SYNC_DATE line is touched; other fields and dictionaries stay as they are. No client.conf: do nothing.
function MarkAttempt([string]$Today, [string]$ClientId) {
    if ([string]::IsNullOrWhiteSpace($ClientId)) { return }
    if (-not (Test-Path -LiteralPath $clientFile -PathType Leaf)) { return }
    $out = New-Object System.Collections.Generic.List[string]
    $seen = $false
    foreach ($line in [System.IO.File]::ReadAllLines($clientFile)) {
        if ($line.StartsWith('LOCAL_LAST_SYNC_DATE=', [System.StringComparison]::Ordinal)) { $out.Add("LOCAL_LAST_SYNC_DATE=$Today"); $seen = $true } else { $out.Add($line) }
    }
    if (-not $seen) { $out.Add("LOCAL_LAST_SYNC_DATE=$Today") }
    $pending = Join-Path $resolvedConfigDir ('.client.conf.pending.' + [guid]::NewGuid().ToString('N'))
    WriteUtf8NoBom $pending (($out -join "`n") + "`n")
    Move-Item -LiteralPath $pending -Destination $clientFile -Force
}
# POST the JSON body through stdin and return the response body as text; no files are created.
function Post-Json([string]$Url, [string]$Json, [int]$Timeout) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'curl.exe'
    $psi.Arguments = '-sS -L -X POST -H "Content-Type: application/json" --connect-timeout 5 --max-time ' + $Timeout + ' --data-binary @- "' + $Url + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($Json)
    $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $proc.StandardInput.Close()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $text = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { return '' }
    return $text
}

# The sync flow returns @{ Status; Reason; Code }; it never exits the script by itself.
function Invoke-Sync {
    $localId = ConfigValue 'LOCAL_CLIENT_ID'
    $localVersion = ConfigValue 'LOCAL_CONFIG_VERSION'
    $lastSyncDate = ConfigValue 'LOCAL_LAST_SYNC_DATE'
    $today = Get-Date -Format 'yyyy-MM-dd'

    # Has a client id and already attempted today (success or failure): no network, return at once.
    # First install (no client id) never skips: it must sync successfully.
    if (-not [string]::IsNullOrWhiteSpace($localId) -and $lastSyncDate -eq $today) { return SyncDone 'UNCHANGED' '' 0 }

    $origin = $BaseUrl
    if ([string]::IsNullOrWhiteSpace($origin)) { $origin = $env:OFFER_SKILL_BASE_URL }
    if ([string]::IsNullOrWhiteSpace($origin)) { $origin = ConfigValue 'API_BASE_URL' }
    $configUrl = ConfigValue 'API_CONFIG_URL'
    if ([string]::IsNullOrWhiteSpace($configUrl)) {
        $configPath = ConfigValue 'API_CONFIG_PATH'
        if ([string]::IsNullOrWhiteSpace($configPath)) { $configPath = '/api/offer/config' }
        $configUrl = JoinEndpoint $origin $configPath
    }
    if ([string]::IsNullOrWhiteSpace($configUrl)) { return SyncDone 'UNCHANGED' 'NO_ENDPOINT' $ExitNetwork }

    # One attempt only, 10 second timeout; the response stays in memory.
    $request = '{"clientId":"' + (JsonEscape $localId) + '","configVersion":"' + (JsonEscape $localVersion) + '"}'
    $responseText = ''
    try { $responseText = Post-Json $configUrl $request $TimeoutSeconds } catch { $responseText = '' }
    if ([string]::IsNullOrWhiteSpace($responseText)) {
        MarkAttempt $today $localId
        return SyncDone 'UNCHANGED' 'NETWORK_UNAVAILABLE' $ExitNetwork
    }

    $parts = @($responseText -split [regex]::Escape($Separator) | ForEach-Object { TrimEnvelope $_ })
    if ($parts.Count -ne 7) {
        MarkAttempt $today $localId
        return SyncDone 'UNCHANGED' 'INVALID_RESPONSE' $ExitInterface
    }
    $code = $parts[0]
    $responseId = $parts[5]
    $responseVersion = $parts[6]
    if ($code -ne 'S000000') {
        MarkAttempt $today $localId
        return SyncDone 'UNCHANGED' 'INTERFACE_ERROR' $ExitInterface
    }
    if ([string]::IsNullOrWhiteSpace($responseId) -or $responseId -eq $Placeholder) {
        MarkAttempt $today $localId
        return SyncDone 'UNCHANGED' 'CLIENT_ID_MISSING' $ExitInterface
    }

    $finalVersion = $localVersion
    if (-not [string]::IsNullOrWhiteSpace($responseVersion) -and $responseVersion -ne $Placeholder) { $finalVersion = $responseVersion }
    # Dictionaries: stage all pending files first, then rename them together.
    $pendingFiles = @()
    $payloads = @(
        @{ Value = $parts[2]; Name = 'regions.txt' },
        @{ Value = $parts[3]; Name = 'banks.txt' },
        @{ Value = $parts[4]; Name = 'tags.txt' }
    )
    foreach ($payload in $payloads) {
        if (-not [string]::IsNullOrWhiteSpace($payload.Value) -and $payload.Value -ne $Placeholder) {
            $pending = Join-Path $resolvedConfigDir ('.' + $payload.Name + '.pending.' + [guid]::NewGuid().ToString('N'))
            WriteUtf8NoBom $pending ($payload.Value + "`n")
            $pendingFiles += @{ Temp = $pending; Target = (Join-Path $resolvedConfigDir $payload.Name) }
        }
    }
    foreach ($pending in $pendingFiles) { Move-Item -LiteralPath $pending.Temp -Destination $pending.Target -Force }

    $lines = @()
    if (Test-Path -LiteralPath $clientFile -PathType Leaf) { $lines = [System.IO.File]::ReadAllLines($clientFile) }
    $newLines = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($line in $lines) {
        if ($line.StartsWith('LOCAL_CLIENT_ID=', [System.StringComparison]::Ordinal)) { $newLines.Add("LOCAL_CLIENT_ID=$responseId"); $seen['LOCAL_CLIENT_ID'] = $true; continue }
        if ($line.StartsWith('LOCAL_CONFIG_VERSION=', [System.StringComparison]::Ordinal)) { $newLines.Add("LOCAL_CONFIG_VERSION=$finalVersion"); $seen['LOCAL_CONFIG_VERSION'] = $true; continue }
        if ($line.StartsWith('LOCAL_LAST_SYNC_DATE=', [System.StringComparison]::Ordinal)) { $newLines.Add("LOCAL_LAST_SYNC_DATE=$today"); $seen['LOCAL_LAST_SYNC_DATE'] = $true; continue }
        if (-not [string]::IsNullOrWhiteSpace($BaseUrl) -and $line.StartsWith('API_BASE_URL=', [System.StringComparison]::Ordinal)) { $newLines.Add("API_BASE_URL=$BaseUrl"); $seen['API_BASE_URL'] = $true; continue }
        $newLines.Add($line)
    }
    if (-not $seen.ContainsKey('LOCAL_CLIENT_ID')) { $newLines.Add("LOCAL_CLIENT_ID=$responseId") }
    if (-not $seen.ContainsKey('LOCAL_CONFIG_VERSION')) { $newLines.Add("LOCAL_CONFIG_VERSION=$finalVersion") }
    if (-not $seen.ContainsKey('LOCAL_LAST_SYNC_DATE')) { $newLines.Add("LOCAL_LAST_SYNC_DATE=$today") }
    if ($lines.Count -eq 0) {
        $newLines.Insert(0, "API_BASE_URL=$BaseUrl")
        $newLines.Insert(1, 'API_CONFIG_PATH=/api/offer/config')
        $newLines.Insert(2, 'API_QUERY_PATH=/api/offer/query')
        $newLines.Insert(3, 'API_DETAIL_PATH=/api/offer/detail')
        $newLines.Insert(4, 'API_RECOMMEND_PATH=/api/offer/recommend')
        $newLines.Insert(5, 'API_MORE_PATH=/api/offer/more')
        $newLines.Insert(6, "API_TIMEOUT_SECONDS=$TimeoutSeconds")
    }
    $clientPending = Join-Path $resolvedConfigDir ('.client.conf.pending.' + [guid]::NewGuid().ToString('N'))
    WriteUtf8NoBom $clientPending (($newLines -join "`n") + "`n")
    Move-Item -LiteralPath $clientPending -Destination $clientFile -Force

    if ($localVersion -eq $finalVersion -and -not [string]::IsNullOrWhiteSpace($localId)) { return SyncDone 'UNCHANGED' '' 0 }
    return SyncDone 'CHANGED' '' 0
}

try {
    $sync = @(Invoke-Sync)[-1]   # take the last value only so stray output cannot leak into the result
} catch {
    $sync = SyncDone 'UNCHANGED' 'CONFIG_WRITE_FAILED' $ExitInterface
}
Out-Line ('SYNC_STATUS=' + $sync.Status)
if ($sync.Reason) { Out-Line ('SYNC_REASON=' + $sync.Reason) }

# ============================== 3) Dictionaries usable? ==============================
$missing = @()
foreach ($name in 'regions', 'banks', 'tags') {
    $f = Join-Path $resolvedConfigDir ($name + '.txt')
    if (-not (Test-Path -LiteralPath $f -PathType Leaf) -or (Get-Item -LiteralPath $f).Length -eq 0) { $missing += ($name + '.txt') }
}
if ($missing.Count -eq 0) {
    Out-Line 'DICT=OK'
} else {
    Out-Line 'DICT=MISSING'
    Out-Line ('DICT_MISSING=' + ($missing -join ','))
}

# ============================== 4) Current local config version ==============================
Out-Line ('CONFIG_VERSION=' + (ConfigValue 'LOCAL_CONFIG_VERSION'))

# ============================== 5) May the caller go on? ==============================
# A first install whose sync failed, or missing dictionaries, must stop here.
$nowClientId = (ConfigValue 'LOCAL_CLIENT_ID').Trim()
$notReady = ''
$readyExit = 0
if ([string]::IsNullOrWhiteSpace($nowClientId)) {
    $notReady = 'FIRST_SYNC_FAILED'
    $readyExit = $ExitInterface
    if ($sync.Code -eq $ExitNetwork -or $sync.Code -eq $ExitInterface) { $readyExit = $sync.Code }
} elseif ($missing.Count -gt 0) {
    $notReady = 'DICT_MISSING'
    $readyExit = $ExitInterface
}
if ($notReady) {
    Out-Line 'READY=NO'
    Out-Line "NOT_READY_REASON=$notReady"
    exit $readyExit
}
Out-Line 'READY=YES'
exit 0
