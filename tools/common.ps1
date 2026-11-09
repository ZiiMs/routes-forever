# Shared helpers for the Routes development scripts.

$RoutesAddonEntries = @(
    'Routes.toc',
    'Routes.lua',
    'Routes.xml',
    'TSP.lua',
    'Bindings.xml',
    'line.tga',
    'Locales',
    'Modules',
    'Plugins',
    'Libs'
)

function Find-AddOnsDirectory([string]$Path) {
    $current = (Resolve-Path -LiteralPath $Path).Path
    while ($current) {
        if ((Split-Path $current -Leaf) -eq 'AddOns') { return $current }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    throw "Could not find an Interface\AddOns directory above '$Path'."
}

function Get-RoutesVersion([string]$SourceRoot) {
    try {
        $gitVersion = & git -C $SourceRoot describe --tags --always --dirty 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) { return $gitVersion.Trim() }
    } catch {
        # git is optional; 'dev' is a valid development version.
    }
    return 'dev'
}

function Set-RoutesTocVersion([string]$AddonRoot, [string]$Version) {
    $tocPath = Join-Path $AddonRoot 'Routes.toc'
    $tocText = Get-Content -LiteralPath $tocPath -Raw
    $tocText = $tocText -replace '@project-version@', $Version
    Set-Content -LiteralPath $tocPath -Value $tocText -NoNewline
}

function Assert-RoutesTocFiles([string]$AddonRoot) {
    $tocPath = Join-Path $AddonRoot 'Routes.toc'
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content -LiteralPath $tocPath) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $relative = $trimmed.Replace('\', '/')
        if (-not (Test-Path -LiteralPath (Join-Path $AddonRoot $relative))) {
            $missing.Add($relative)
        }
    }
    if ($missing.Count -gt 0) {
        throw ("Addon is missing TOC files:`n  " + ($missing -join "`n  "))
    }
}
