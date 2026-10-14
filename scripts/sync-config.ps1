[CmdletBinding()]
param(
    [string]$ConfigDir = '',
    [string]$BaseUrl = '',
    [string]$RequestId = '',
    [int]$TimeoutSeconds = 30
)

if ([string]::IsNullOrWhiteSpace($ConfigDir)) { $ConfigDir = Join-Path $PSScriptRoot '..\config' }
$ErrorActionPreference = 'Stop'
$ExitNetwork = 13
$ExitInterface = 14
$Separator = '=.==.='
$Placeholder = [string][char]0x65E0
$resolvedConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)
$clientFile = Join-Path $resolvedConfigDir 'client.conf'
$respDir = Join-Path $PSScriptRoot '..\config\data\res'

function Result([string]$Status, [string]$Reason = '') {
    [Console]::Out.WriteLine("SYNC_STATUS=$Status")
    if (-not [string]::IsNullOrWhiteSpace($Reason)) { [Console]::Error.WriteLine("SYNC_REASON=$Reason") }
    if (-not [string]::IsNullOrWhiteSpace($RequestId)) {
        [Console]::Out.WriteLine("SYNC_REQUEST_ID=$RequestId")
        [Console]::Out.WriteLine("SYNC_RESPONSE_FILE=$(Join-Path $respDir ($RequestId + '.response'))")
    }
}
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

try {
    if (-not (Test-Path -LiteralPath $resolvedConfigDir -PathType Container)) { New-Item -ItemType Directory -Path $resolvedConfigDir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $respDir -PathType Container)) { New-Item -ItemType Directory -Path $respDir -Force | Out-Null }
    $localId = ConfigValue 'LOCAL_CLIENT_ID'
    $localVersion = ConfigValue 'LOCAL_CONFIG_VERSION'
    $lastSyncDate = ConfigValue 'LOCAL_LAST_SYNC_DATE'
    $today = Get-Date -Format 'yyyy-MM-dd'

    if (-not [string]::IsNullOrWhiteSpace($localId) -and $lastSyncDate -eq $today) {
        Result 'UNCHANGED'
        exit 0
    }

    $origin = $BaseUrl
    if ([string]::IsNullOrWhiteSpace($origin)) { $origin = $env:OFFER_SKILL_BASE_URL }
    if ([string]::IsNullOrWhiteSpace($origin)) { $origin = ConfigValue 'API_BASE_URL' }
    $configUrl = ConfigValue 'API_CONFIG_URL'
    if ([string]::IsNullOrWhiteSpace($configUrl)) {
        $configPath = ConfigValue 'API_CONFIG_PATH'
        if ([string]::IsNullOrWhiteSpace($configPath)) { $configPath = '/api/offer/config' }
        $configUrl = JoinEndpoint $origin $configPath
    }
    if ([string]::IsNullOrWhiteSpace($configUrl)) {
        Result 'UNCHANGED' 'NO_ENDPOINT'
        exit $ExitNetwork
    }

    if ([string]::IsNullOrWhiteSpace($RequestId)) { $RequestId = 'sync-' + (Get-Date -Format 'yyyyMMddHHmmss') + '-' + $PID }
    $responseFile = Join-Path $respDir ($RequestId + '.response')
    $request = @{ clientId = $localId; configVersion = $localVersion } | ConvertTo-Json -Compress
    $requestFile = Join-Path ([System.IO.Path]::GetTempPath()) ('offer-skill-config-request-' + [guid]::NewGuid().ToString('N') + '.json')
    WriteUtf8NoBom $requestFile $request
    $apiScript = Join-Path $PSScriptRoot 'api-call.ps1'
    $apiExit = 0
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $apiScript -Method POST -Url $configUrl -DataFile $requestFile -RequestId $RequestId -OutputFile $responseFile -TimeoutSeconds $TimeoutSeconds -RetryCount 3 2>$null | Out-Null
        $apiExit = $LASTEXITCODE
    } catch {
        $apiExit = $ExitNetwork
    } finally {
        Remove-Item -LiteralPath $requestFile -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath $responseFile -PathType Leaf)) {
        Result 'UNCHANGED' 'NETWORK_UNAVAILABLE'
        exit $ExitNetwork
    }
    $responseText = [System.IO.File]::ReadAllText($responseFile, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($responseText)) {
        Result 'UNCHANGED' 'NETWORK_UNAVAILABLE'
        exit $ExitNetwork
    }

    $parts = @($responseText -split [regex]::Escape($Separator) | ForEach-Object { TrimEnvelope $_ })
    if ($parts.Count -ne 7) {
        Result 'UNCHANGED' 'INVALID_RESPONSE'
        exit $ExitInterface
    }
    $code = $parts[0]
    $responseId = $parts[5]
    $responseVersion = $parts[6]
    if ($code -ne 'S000000') {
        Result 'UNCHANGED' 'INTERFACE_ERROR'
        if ($apiExit -eq $ExitNetwork) { exit $ExitNetwork }
        exit $ExitInterface
    }
    if ([string]::IsNullOrWhiteSpace($responseId) -or $responseId -eq $Placeholder) {
        Result 'UNCHANGED' 'CLIENT_ID_MISSING'
        exit $ExitInterface
    }

    $finalVersion = $localVersion
    if (-not [string]::IsNullOrWhiteSpace($responseVersion) -and $responseVersion -ne $Placeholder) { $finalVersion = $responseVersion }
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

    if ($localVersion -eq $finalVersion -and -not [string]::IsNullOrWhiteSpace($localId)) { Result 'UNCHANGED' } else { Result 'CHANGED' }
    exit 0
} catch {
    Result 'UNCHANGED' 'CONFIG_WRITE_FAILED'
    exit $ExitInterface
}
