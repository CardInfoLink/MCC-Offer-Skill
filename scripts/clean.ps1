[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RequestId) -or $RequestId -notmatch '^[A-Za-z0-9._-]+$') {
    [Console]::Error.WriteLine('REQUEST_ID_INVALID')
    exit 14
}

$dataRoot = Join-Path $PSScriptRoot '..\config\data'
$files = @(
    (Join-Path $dataRoot ('req\' + $RequestId + '.request')),
    (Join-Path $dataRoot ('res\' + $RequestId + '.response'))
)
$removed = 0
foreach ($file in $files) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        Remove-Item -LiteralPath $file -Force
        $removed++
    }
}
[Console]::Out.WriteLine("CLEANUP_REQUEST_ID=$RequestId")
[Console]::Out.WriteLine("CLEANUP_STATUS=$(if ($removed -gt 0) { 'REMOVED' } else { 'NOT_FOUND' })")
[Console]::Out.WriteLine("CLEANUP_FILES=$removed")
exit 0
