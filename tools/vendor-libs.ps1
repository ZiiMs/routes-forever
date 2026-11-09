#Requires -Version 5.1
<#
.SYNOPSIS
    Stage the embedded libraries Routes needs into .\Libs.

.DESCRIPTION
    Routes ships without its libraries in source control.  This script copies
    known-compatible copies from addons that are already installed in the WoW
    Forever client.  It fails loudly rather than producing a package that is
    missing a file listed in Routes.toc.

    The local sources are:
      * GatherMate2\Libs          Ace3 components and HereBeDragons
      * NaowhUI\Libs\AceHook-3.0  AceHook, which GatherMate2 does not embed

    HereBeDragons must be 2.18 or newer because that is the first release with
    WOW_PROJECT_CAMELOT/Forever map data.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Copy-LibraryDirectory([string]$Source, [string]$DestinationRoot) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Required library source is missing: $Source"
    }
    $destination = Join-Path $DestinationRoot (Split-Path $Source -Leaf)
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $DestinationRoot -Recurse -Force
}

$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$addonsDir = Find-AddOnsDirectory $sourceRoot
$gatherMateLibs = Join-Path $addonsDir 'GatherMate2\Libs'
$naowhLibs = Join-Path $addonsDir 'NaowhUI\Libs'
$libsRoot = Join-Path $sourceRoot 'Libs'

if (-not (Test-Path -LiteralPath $gatherMateLibs -PathType Container)) {
    throw "GatherMate2 libraries not found at '$gatherMateLibs'. Install GatherMate2 first."
}
if (-not (Test-Path -LiteralPath $naowhLibs -PathType Container)) {
    throw "NaowhUI libraries not found at '$naowhLibs'. Install NaowhUI first, or copy AceHook-3.0 there."
}

# Verify HereBeDragons 2.18+ before copying.  The installed release is
# 2.18-release; older releases have no Forever map data.
$hbdSource = Join-Path $gatherMateLibs 'HereBeDragons'
$hbdToc = Join-Path $hbdSource 'HereBeDragons.toc'
if (-not (Test-Path -LiteralPath $hbdToc)) {
    throw "HereBeDragons.toc not found at '$hbdToc'."
}
$hbdVersionLine = Select-String -LiteralPath $hbdToc -Pattern '^##\s*Version:\s*(.+)$' | Select-Object -First 1
if (-not $hbdVersionLine) {
    throw "Could not read the HereBeDragons version from '$hbdToc'."
}
$hbdVersionText = $hbdVersionLine.Matches[0].Groups[1].Value.Trim()
$hbdVersionMatch = [regex]::Match($hbdVersionText, '(\d+)\.(\d+)')
if (-not $hbdVersionMatch.Success) {
    throw "Unrecognised HereBeDragons version '$hbdVersionText'."
}
$hbdVersion = [version]("{0}.{1}" -f $hbdVersionMatch.Groups[1].Value, $hbdVersionMatch.Groups[2].Value)
if ($hbdVersion -lt [version]'2.18') {
    throw "HereBeDragons $hbdVersionText is too old; 2.18 or newer is required for WoW Forever."
}

New-Item -ItemType Directory -Path $libsRoot -Force | Out-Null

$aceLibraries = @(
    'LibStub',
    'CallbackHandler-1.0',
    'AceAddon-3.0',
    'AceConfig-3.0',
    'AceConsole-3.0',
    'AceDB-3.0',
    'AceEvent-3.0',
    'AceGUI-3.0',
    'AceLocale-3.0'
)

foreach ($library in $aceLibraries) {
    Copy-LibraryDirectory (Join-Path $gatherMateLibs $library) $libsRoot
}

Copy-LibraryDirectory (Join-Path $naowhLibs 'AceHook-3.0') $libsRoot
Copy-LibraryDirectory $hbdSource $libsRoot

Write-Host "Staged libraries in $libsRoot" -ForegroundColor Green
Write-Host "  Ace3 from $gatherMateLibs"
Write-Host "  AceHook-3.0 from $naowhLibs"
Write-Host "  HereBeDragons $hbdVersionText from $hbdSource"
