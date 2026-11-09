#Requires -Version 5.1
<#
.SYNOPSIS
    Build a self-contained Routes zip for WoW Forever (or any supported client).

.DESCRIPTION
    Stages the addon files and freshly vendored libraries into dist\Routes and
    writes dist\Routes-<version>.zip.  The zip contains exactly the addon
    folder, so extracting it into Interface\AddOns is enough.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'),
    [switch]$SkipVendor
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path

if (-not $SkipVendor -or -not (Test-Path -LiteralPath (Join-Path $sourceRoot 'Libs'))) {
    & (Join-Path $PSScriptRoot 'vendor-libs.ps1') -SourceRoot $sourceRoot
}

$stageRoot = Join-Path $OutputDirectory 'staging'
$stageAddon = Join-Path $stageRoot 'Routes'
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stageAddon -Force | Out-Null

foreach ($entry in $RoutesAddonEntries) {
    $source = Join-Path $sourceRoot $entry
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Addon file is missing from the source tree: $source"
    }
    Copy-Item -LiteralPath $source -Destination $stageAddon -Recurse -Force
}

$version = Get-RoutesVersion $sourceRoot
Set-RoutesTocVersion $stageAddon $version
Assert-RoutesTocFiles $stageAddon

$safeVersion = $version -replace '[^A-Za-z0-9._-]', '-'
$zipPath = Join-Path $OutputDirectory ("Routes-{0}.zip" -f $safeVersion)
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path $stageAddon -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Packaged $zipPath" -ForegroundColor Green
Write-Host "Extract the Routes folder into Interface\AddOns, then /reload."
