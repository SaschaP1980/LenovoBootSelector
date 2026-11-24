#requires -version 5.1
# LBS-244: focused source contract; native rendering is tested separately.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$paths = @('src/UI/Popup.ps1','src/UI/PopupComposition.ps1')
foreach ($path in $paths) {
    $source = [IO.File]::ReadAllText((Join-Path $root $path))
    if ($source -match '(?i)New-Object\s+(?:System\.)?Windows\.Forms\.ToolTip\b') {
        throw "LBS244_RED: unthemed ToolTip constructor in $path"
    }
    if ($source -notmatch 'New-LenovoDarkTooltip\b') {
        throw "LBS244_RED: shared dark tooltip factory missing in $path"
    }
    Write-Host "PASS LBS244 shared dark tooltip factory: $path"
}
Write-Host 'LBS244 SOURCE TOTAL 2/2'
