[CmdletBinding()]
param(
    [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
    [string]$Method = 'GET',
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [string]$Data = '',
    [string]$DataFile = '',
    [string]$RequestId = '',
    [string]$OutputFile = '',
    [int]$TimeoutSeconds = 30,
    [int]$RetryCount = 3
)

$ErrorActionPreference = 'Stop'
$ExitNetwork = 13
$ExitHttp = 14
if ([string]::IsNullOrWhiteSpace($RequestId)) {
    [Console]::Error.WriteLine('REQUEST_ID_REQUIRED')
    exit $ExitHttp
}
if (-not [string]::IsNullOrWhiteSpace($Data) -and -not [string]::IsNullOrWhiteSpace($DataFile)) {
    [Console]::Error.WriteLine('REQUEST_BODY_CONFLICT')
    exit $ExitHttp
}
if ($RetryCount -lt 1) { $RetryCount = 1 }
if ($TimeoutSeconds -lt 1) { $TimeoutSeconds = 1 }
$dataRoot = Join-Path $PSScriptRoot '..\config\data'
$requestDir = Join-Path $dataRoot 'req'
$responseDir = Join-Path $dataRoot 'res'
if ([string]::IsNullOrWhiteSpace($OutputFile)) { $OutputFile = Join-Path $responseDir ($RequestId + '.response') }
$requestFile = Join-Path $requestDir ($RequestId + '.request')
$outputDir = Split-Path -Parent $OutputFile

function Write-FileAtomic([string]$Source, [string]$Target) {
    $targetDir = Split-Path -Parent $Target
    if (-not [string]::IsNullOrWhiteSpace($targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    $pending = $Target + '.pending.' + $PID + '.' + [guid]::NewGuid().ToString('N')
    Copy-Item -LiteralPath $Source -Destination $pending -Force
    Move-Item -LiteralPath $pending -Destination $Target -Force
}
function Write-TextAtomic([string]$Content, [string]$Target) {
    $targetDir = Split-Path -Parent $Target
    if (-not [string]::IsNullOrWhiteSpace($targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    $pending = $Target + '.pending.' + $PID + '.' + [guid]::NewGuid().ToString('N')
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($pending, $Content, $utf8)
    Move-Item -LiteralPath $pending -Destination $Target -Force
}
function Emit-Result([string]$HttpStatus, [int]$ExitCode) {
    [Console]::Out.WriteLine("REQUEST_ID=$RequestId")
    [Console]::Out.WriteLine("REQUEST_FILE=$requestFile")
    [Console]::Out.WriteLine("RESPONSE_FILE=$OutputFile")
    [Console]::Out.WriteLine("HTTP_STATUS=$HttpStatus")
    [Console]::Out.WriteLine("EXIT_CODE=$ExitCode")
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('offer-skill-api-call-' + [guid]::NewGuid().ToString('N'))
$responseTemp = Join-Path $tempDir 'response'
$errorTemp = Join-Path $tempDir 'error'
$httpStatus = '000'
$curlExit = 1
$resultCode = $ExitNetwork
try {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    New-Item -ItemType Directory -Path $requestDir -Force | Out-Null
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($DataFile)) {
        Write-FileAtomic $DataFile $requestFile
    } elseif (-not [string]::IsNullOrWhiteSpace($Data)) {
        Write-TextAtomic $Data $requestFile
    } else {
        Write-TextAtomic '' $requestFile
    }

    $attempt = 1
    while ($attempt -le $RetryCount) {
        if (Test-Path -LiteralPath $responseTemp) { Remove-Item -LiteralPath $responseTemp -Force }
        if (Test-Path -LiteralPath $errorTemp) { Remove-Item -LiteralPath $errorTemp -Force }
        $curlArgs = @(
            '-sS', '-L', '-X', $Method,
            '-H', 'Content-Type: application/json',
            '--connect-timeout', '5', '--max-time', [string]$TimeoutSeconds
        )
        if (-not [string]::IsNullOrWhiteSpace($DataFile) -or -not [string]::IsNullOrWhiteSpace($Data)) {
            $curlArgs += @('--data-binary', "@$requestFile")
        }
        $curlArgs += @('-o', $responseTemp, '-w', '%{http_code}', $Url)
        $statusOutput = (& curl.exe @curlArgs 2> $errorTemp | Out-String).Trim()
        $curlExit = $LASTEXITCODE
        if (-not [string]::IsNullOrWhiteSpace($statusOutput)) { $httpStatus = $statusOutput }
        if ($curlExit -eq 0 -and $httpStatus -match '^2\d\d$') { break }
        if ($attempt -lt $RetryCount -and ($curlExit -ne 0 -or $httpStatus -eq '000' -or $httpStatus -match '^5\d\d$')) {
            Start-Sleep -Seconds 1
            $attempt++
            continue
        }
        break
    }

    if ($curlExit -ne 0 -or $httpStatus -eq '000' -or [string]::IsNullOrWhiteSpace($httpStatus)) {
        $resultCode = $ExitNetwork
    } elseif ($httpStatus -notmatch '^2\d\d$') {
        $resultCode = $ExitHttp
    } else {
        $resultCode = 0
    }

    if (-not (Test-Path -LiteralPath $responseTemp)) { [System.IO.File]::WriteAllText($responseTemp, '') }
    Write-FileAtomic $responseTemp $OutputFile
    Emit-Result $httpStatus $resultCode
    if ($resultCode -eq $ExitNetwork) { [Console]::Error.WriteLine('NETWORK_REQUEST_FAILED'); exit $ExitNetwork }
    if ($resultCode -eq $ExitHttp) { [Console]::Error.WriteLine("HTTP_NON_SUCCESS_$httpStatus"); exit $ExitHttp }
    exit 0
} catch {
    try {
        if (-not (Test-Path -LiteralPath $responseTemp)) { [System.IO.File]::WriteAllText($responseTemp, '') }
        Write-FileAtomic $responseTemp $OutputFile
        Emit-Result $httpStatus $ExitNetwork
    } catch { }
    [Console]::Error.WriteLine('REQUEST_EXECUTION_FAILED')
    exit $ExitNetwork
} finally {
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
