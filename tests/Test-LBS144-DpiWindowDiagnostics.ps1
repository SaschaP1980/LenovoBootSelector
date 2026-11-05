#requires -version 5.1
# LBS-144: read-only native Win32/DWM window DPI geometry contract.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$path = Join-Path $root 'src\UI\DpiWindowDiagnostics.ps1'
if (-not (Test-Path -LiteralPath $path)) { throw 'LBS-144 DPI WINDOW RED: runtime probe module is missing' }
. $path
$script:checks=0
function Assert-DpiWindow([string]$title,[bool]$condition) {
 if(-not $condition){ throw "LBS-144 DPI WINDOW RED: $title" }
 $script:checks++; Write-Host "PASS LBS144 DPI WINDOW $title"
}
$values=@(100,110,125,135,150,175,200,225,250,275,300,350,400,500)
foreach($percent in $values){
 $dpi=[double](96.0 * $percent / 100.0)
 $ratio=ConvertTo-LenovoDpiScale -Dpi $dpi
 Assert-DpiWindow "Arbitrary $percent percent DPI scale measured from numeric DPI" ([Math]::Abs($ratio - ($percent / 100.0)) -lt 0.000001)
}
$form=New-Object System.Windows.Forms.Form
$form.StartPosition=[System.Windows.Forms.FormStartPosition]::Manual
$form.ClientSize=[Drawing.Size]::new(440,240)
try {
 $before=Get-LenovoDpiWindowMetrics -Control $form -Role 'test-form' -Phase 'before-show'
 Assert-DpiWindow 'Pre-show snapshot does not create an HWND' (-not $form.IsHandleCreated -and $before.hwndPresent -eq $false)
 Assert-DpiWindow 'Pre-show snapshot includes WinForms client geometry' ($before.clientWidth -eq 440 -and $before.clientHeight -eq 240)
 $form.Show()
 [System.Windows.Forms.Application]::DoEvents()
 $shown=Get-LenovoDpiWindowMetrics -Control $form -Role 'test-form' -Phase 'shown'
 Assert-DpiWindow 'Shown native HWND exists' ($shown.hwndPresent -and $form.IsHandleCreated)
 Assert-DpiWindow 'Win32 GetWindowRect has positive dimensions' ($shown.windowRectWidth -gt 0 -and $shown.windowRectHeight -gt 0)
 Assert-DpiWindow 'GetDpiForWindow reports valid measured DPI' ($shown.windowDpi -ge 96)
 Assert-DpiWindow 'DPI ratio comes from measured DPI rather than a fixed display preset' ([Math]::Abs($shown.windowDpiScale - ($shown.windowDpi/96.0)) -lt .000001)
 Assert-DpiWindow 'Native awareness and DWM-physical probe status is explicit' ($null -ne $shown.windowAwareness -and $null -ne $shown.dwmPhysicalAvailable)
 Assert-DpiWindow 'Native snapshot identifies monitor and its work area' ($shown.screenWorkWidth -gt 0 -and $shown.screenWorkHeight -gt 0)
}
finally {$form.Dispose()}
$menu=New-Object System.Windows.Forms.ContextMenuStrip
try {
 $menu.Items.Add('Harmless') | Out-Null
 $uns=Get-LenovoDpiWindowMetrics -Control $menu -Role 'test-menu' -Phase 'before-first-show'
 Assert-DpiWindow 'Measuring unopened menu does not materialize its HWND' (-not $menu.IsHandleCreated -and -not $uns.hwndPresent)
}
finally {$menu.Dispose()}
$menuSource=[IO.File]::ReadAllText((Join-Path $root 'src\UI\MenuAppearance.ps1'))
$dialogSource=[IO.File]::ReadAllText((Join-Path $root 'src\UI\Dialogs.ps1'))
$appSource=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
Assert-DpiWindow 'Menu events instrument both Opening and Opened' ($menuSource.Contains('Write-LenovoDpiWindowEvent -Control $this') -and $menuSource.Contains("Phase 'opening'") -and $menuSource.Contains("Phase 'opened'"))
Assert-DpiWindow 'All regular dialog types use shared post-show probe' ($dialogSource.Contains('Register-LenovoDialogDpiWindowDiagnostics -Form $Form') -and ([regex]::Matches($dialogSource,'Prepare-LenovoDialogDpiLayout -Form \$form -Owner \$owner -Role').Count -eq 4))
Assert-DpiWindow 'First root tray Show logs actual native window result' ($appSource.Contains('Write-LenovoDpiWindowEvent -Control $script:TrayContextMenu'))
Assert-DpiWindow 'Process awareness captured in the shown HWND snapshot' ($shown.processAwareness -ne $null -and $shown.hwndPresent)
Write-Host "LBS144 DPI WINDOW TOTAL $script:checks/27"
if ($script:checks -ne 27){throw "Expected 27 native DPI window contracts, got $script:checks"}
