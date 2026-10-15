[CmdletBinding()]
param(
    [ValidateSet('testing', 'product')]
    [string]$Profile = 'testing',
    [string]$Version = '0.1.0',
    [string]$OutputRoot = '',
    [ValidateSet('agent-skill', 'claude-plugin', 'cursor', 'openclaw', 'workbuddy', 'npm', 'all')]
    [string]$Platform = 'agent-skill'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $sourceRoot 'dist' }
if ($Version -notmatch '^[A-Za-z0-9._-]+$') { throw 'VERSION_INVALID' }

$profileFile = Join-Path $sourceRoot "config\client.$Profile"
$required = @('SKILL.md', 'README.md', 'LICENSE', 'CHANGELOG.md', 'scripts', 'sub-skills', 'config\tags.txt', 'config\regions.txt', 'config\banks.txt', "config\client.$Profile")
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $item))) { throw "MISSING_SOURCE=$item" }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Copy-CoreTree([string]$Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Destination 'config') -Force | Out-Null

    foreach ($file in @('SKILL.md', 'README.md', 'LICENSE', 'CHANGELOG.md')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $file) -Destination (Join-Path $Destination $file) -Force
    }
    foreach ($file in @('tags.txt', 'regions.txt', 'banks.txt')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot "config\$file") -Destination (Join-Path $Destination "config\$file") -Force
    }

    $profileText = [System.IO.File]::ReadAllText($profileFile, [System.Text.Encoding]::UTF8)
    $profileText = [regex]::Replace($profileText, '(?m)^LOCAL_CLIENT_ID=.*$', 'LOCAL_CLIENT_ID=')
    $profileText = [regex]::Replace($profileText, '(?m)^LOCAL_CONFIG_VERSION=.*$', 'LOCAL_CONFIG_VERSION=')
    $profileText = [regex]::Replace($profileText, '(?m)^LOCAL_LAST_SYNC_DATE=.*$', 'LOCAL_LAST_SYNC_DATE=')
    Write-Utf8NoBom (Join-Path $Destination 'config\client.conf') $profileText

    foreach ($dir in @('scripts', 'sub-skills', 'references', 'assets', 'docs')) {
        $sourceDir = Join-Path $sourceRoot $dir
        if (Test-Path -LiteralPath $sourceDir) {
            $targetDir = Join-Path $Destination $dir
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Copy-Item -Path (Join-Path $sourceDir '*') -Destination $targetDir -Recurse -Force
        }
    }
}

function Remove-ExcludedContent([string]$PackageDir) {
    foreach ($dir in @('config\data', 'test', '.git', '.kiro', '.idea', 'dist')) {
        $path = Join-Path $PackageDir $dir
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
}

function New-Zip([string]$PackageDir, [string]$PackageName) {
    $archive = Join-Path $OutputRoot ($PackageName + '.zip')
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -Path $PackageDir -DestinationPath $archive -Force
    [Console]::Out.WriteLine("ARCHIVE=$archive")
}

function Build-Package([string]$Kind) {
    if ($Kind -eq 'agent-skill') {
        $packageName = "mcc-offer-skill-$Profile-$Version"
    } else {
        $packageName = "mcc-offer-skill-$Kind-$Profile-$Version"
    }
    $packageDir = Join-Path $OutputRoot $packageName
    if (Test-Path -LiteralPath $packageDir) { Remove-Item -LiteralPath $packageDir -Recurse -Force }
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

    switch ($Kind) {
        'agent-skill' {
            Copy-CoreTree $packageDir
        }
        'claude-plugin' {
            New-Item -ItemType Directory -Path (Join-Path $packageDir 'skills\mcc-offer-skill') -Force | Out-Null
            Copy-CoreTree (Join-Path $packageDir 'skills\mcc-offer-skill')
            Copy-Item -LiteralPath (Join-Path $sourceRoot 'platforms\claude-code\.claude-plugin') -Destination $packageDir -Recurse -Force
            foreach ($file in @('plugin.json', 'marketplace.json')) {
                $metadataPath = Join-Path $packageDir ".claude-plugin\$file"
                $content = [System.IO.File]::ReadAllText($metadataPath, [System.Text.Encoding]::UTF8)
                $content = $content.Replace('"version": "0.1.0"', ('"version": "' + $Version + '"'))
                Write-Utf8NoBom $metadataPath $content
            }
        }
        'cursor' {
            Copy-CoreTree (Join-Path $packageDir '.cursor\skills\mcc-offer-skill')
        }
        'openclaw' {
            Copy-CoreTree (Join-Path $packageDir 'skills\mcc-offer-skill')
        }
        'workbuddy' {
            Copy-CoreTree $packageDir
            Copy-Item -LiteralPath (Join-Path $sourceRoot 'platforms\workbuddy\manifest.yaml') -Destination (Join-Path $packageDir 'manifest.yaml') -Force
            $manifestPath = Join-Path $packageDir 'manifest.yaml'
            $manifest = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8)
            $manifest = [regex]::Replace($manifest, '(?m)^version:.*$', ('version: ' + $Version))
            Write-Utf8NoBom $manifestPath $manifest
        }
        'npm' {
            Copy-CoreTree $packageDir
            Copy-Item -LiteralPath (Join-Path $sourceRoot 'platforms\npm\package.json') -Destination (Join-Path $packageDir 'package.json') -Force
            $packageJsonPath = Join-Path $packageDir 'package.json'
            $packageJson = [System.IO.File]::ReadAllText($packageJsonPath, [System.Text.Encoding]::UTF8)
            $packageJson = [regex]::Replace($packageJson, '(?m)("version"\s*:\s*)"[^"]+"', ('$1"' + $Version + '"'), 1)
            Write-Utf8NoBom $packageJsonPath $packageJson
        }
    }

    Remove-ExcludedContent $packageDir
    New-Zip $packageDir $packageName
    if ($Kind -eq 'npm' -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Push-Location $packageDir
        try { & npm pack --ignore-scripts --pack-destination $OutputRoot | Out-Host }
        finally { Pop-Location }
    }
    [Console]::Out.WriteLine("PACKAGE_DIR=$packageDir")
    [Console]::Out.WriteLine("PROFILE=$Profile")
    [Console]::Out.WriteLine("VERSION=$Version")
    [Console]::Out.WriteLine("PLATFORM=$Kind")
}

$platforms = if ($Platform -eq 'all') { @('agent-skill', 'claude-plugin', 'cursor', 'openclaw', 'workbuddy', 'npm') } else { @($Platform) }
foreach ($kind in $platforms) { Build-Package $kind }
