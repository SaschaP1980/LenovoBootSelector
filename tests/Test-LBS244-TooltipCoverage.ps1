#requires -version 5.1
# Focused binding regression: native pointer visibility is independently tested.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$popup = [IO.File]::ReadAllText((Join-Path $root 'src/UI/PopupComposition.ps1'))
$picker = [IO.File]::ReadAllText((Join-Path $root 'src/UI/DefaultTargetMenu.ps1'))
$rows = [IO.File]::ReadAllText((Join-Path $root 'src/UI/BootEntryRows.ps1'))
$locale = [IO.File]::ReadAllText((Join-Path $root 'src/Core/Localization.ps1'))
$checks = 0
$failures = @()
function Assert-Coverage([string]$Name,[bool]$Condition) {
    if ($Condition) { $script:checks++; Write-Host "PASS $Name" }
    else { $script:failures += $Name; Write-Host "FAIL $Name" }
}
Assert-Coverage 'F02 customize action hint' ($popup -match 'Tooltip\.Customize')
Assert-Coverage 'F03 settings navigation hint' ($popup -match 'Tooltip\.Settings' -and $popup -match 'Tooltip\.DefaultNavigation')
Assert-Coverage 'F04 restart action hint' ($popup -match 'Tooltip\.Restart')
Assert-Coverage 'F05 configuration action hints' ($popup -match 'Tooltip\.Configuration\.' -and $popup -match 'Tooltip\.Configuration\.autostart')
Assert-Coverage 'F06 context-specific close hint and hand cursor' ($popup -match '\$close\.Cursor\s*=\s*\[Windows\.Forms\.Cursors\]::Hand' -and $popup -match 'Tooltip\.ClosePicker' -and $popup -match 'Tooltip\.CloseSettings')
Assert-Coverage 'F07 one-time row action hints' ($rows -match 'Tooltip\.NextBoot' -and $rows -match 'Tooltip\.NextBootPending')
Assert-Coverage 'F08 hidden type context and localized category' ($rows -match 'Tooltip\.HiddenType' -and $locale -match 'Startzieltyp:')
Assert-Coverage 'F09 persistent picker action hints' ($picker -match 'Tooltip\.SetDefault' -and $picker -match 'Tooltip\.ClearDefault')
Write-Host "LBS244 COVERAGE TOTAL $checks/8"
if ($failures.Count) { throw ('LBS244 RED: ' + ($failures -join '; ')) }
