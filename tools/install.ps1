#Requires -Version 5.1
<#
.SYNOPSIS
    Install the Routes development tree into a WoW client's AddOns folder.

.DESCRIPTION
    Copies only addon files (never WTF/SavedVariables) into:
        <WoW>\\_forever_\\Interface\\AddOns\\Routes        (default)
        <WoW>\\_retail_\\Interface\\AddOns\\Routes
        <WoW>\\_classic_\\Interface\\AddOns\\Routes
        <WoW>\\_classic_era_\\Interface\\AddOns\\Routes

    The source tree is authoritative; the installed copy is replaced on every
    run so stale Lua files cannot survive a rename.  Libraries are staged from
    the installed client first unless -SkipVendor is supplied.

    After it finishes, type /reload in game (or restart the client).
#>
[CmdletBinding()]
param(
    [ValidateSet('forever', 'retail', 'classic', 'classic_era')]
    [string]$Flavor = 'forever',

    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),

    [switch]$SkipVendor
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$flavorFolders = @{
    forever     = '_forever_'
    retail      = '_retail_'
    classic     = '_classic_'
    classic_era = '_classic_era_'
}

$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sourceAddOns = Find-AddOnsDirectory $sourceRoot
$clientRoot = Split-Path (Split-Path $sourceAddOns -Parent) -Parent
$wowRoot = Split-Path $clientRoot -Parent
$targetAddOns = Join-Path $wowRoot (Join-Path $flavorFolders[$Flavor] 'Interface\AddOns')

if (-not (Test-Path -LiteralPath $targetAddOns -PathType Container)) {
    throw "Target addon folder does not exist: $targetAddOns"
}

if (-not $SkipVendor -or -not (Test-Path -LiteralPath (Join-Path $sourceRoot 'Libs'))) {
    & (Join-Path $PSScriptRoot 'vendor-libs.ps1') -SourceRoot $sourceRoot
}

$target = Join-Path $targetAddOns 'Routes'
if ((Split-Path $target -Leaf) -ne 'Routes') {
    throw "Refusing to install to unexpected path '$target'."
}

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}
New-Item -ItemType Directory -Path $target -Force | Out-Null

foreach ($entry in $RoutesAddonEntries) {
    $source = Join-Path $sourceRoot $entry
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Addon file is missing from the source tree: $source"
    }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}

# Give development installs a readable version instead of the packaging token.
$version = Get-RoutesVersion $sourceRoot
Set-RoutesTocVersion $target $version
Assert-RoutesTocFiles $target

Write-Host "Installed Routes $version to $target" -ForegroundColor Green
Write-Host 'SavedVariables under WTF were not touched.'
Write-Host 'In game: /console scriptErrors 1, then /reload. Run /routes selftest.'
