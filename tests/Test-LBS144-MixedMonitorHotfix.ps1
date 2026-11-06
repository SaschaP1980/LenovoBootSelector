#requires -version 5.1
# LBS-144 v1.1.14.5 P1/P2/P3 native Windows regression.
# Exercise WinForms layout and visible HWNDs without boot or TaskBroker calls.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
. (Join-Path $root 'src\UI\DpiWindowDiagnostics.ps1')
$script:passed=0
function Assert-Lbs144Hotfix([string]$Name,[bool]$Ok) {
  if (-not $Ok) { throw "LBS-144 P123 RED: $Name" }
  $script:passed++; Write-Host "PASS LBS144 P123 $Name"
}
# P2: WinForms menu-item Height at 240 DPI is not a 96-DPI baseline.
Assert-Lbs144Hotfix 'Explicit unscaled menu row design basis available' ($null -ne (Get-Command Get-LenovoMenuDesignItemHeight -ErrorAction SilentlyContinue))
$menu=New-Object System.Windows.Forms.ContextMenuStrip
$menu.Padding=[System.Windows.Forms.Padding]::new(0,2,0,2)
$item=New-Object System.Windows.Forms.ToolStripMenuItem('Open')
$item.Padding=[System.Windows.Forms.Padding]::new(18,4,32,4)
$sep=New-Object System.Windows.Forms.ToolStripSeparator
[void]$menu.Items.Add($item)
[void]$menu.Items.Add($sep)
try {
  # Simulate the oversized intrinsic font-driven row captured at 240 DPI.
  $item.AutoSize=$false
  $item.Height=60
  Assert-Lbs144Hotfix 'Unscaled row is independent of native host font DPI' ((Get-LenovoMenuDesignItemHeight -Item $item) -eq 24)
  Assert-Lbs144Hotfix 'Unscaled separator is a stable design unit' ((Get-LenovoMenuDesignItemHeight -Item $sep) -eq 6)
  foreach ($scale in @(1.0,1.25,1.5,2.0,2.5,3.0)) {
    [void](Set-LenovoMenuDpiLayout -Menu $menu -Scale ([double]$scale))
    $wanted=[int][Math]::Round(24*$scale)
    Assert-Lbs144Hotfix ("Menu row at scale {0} must not compound" -f $scale) ($item.Height -eq $wanted)
    Assert-Lbs144Hotfix ("Separator at scale {0} scales once" -f $scale) ($sep.Height -eq [int][Math]::Round(6*$scale))
  }
  Assert-Lbs144Hotfix 'Menu size is idempotent on repeated 250% layout' (([void](Set-LenovoMenuDpiLayout -Menu $menu -Scale 2.5)) -eq $null -and $item.Height -eq 60)
} finally { $menu.Dispose() }

# P1: ownerless topmost modal must be fully reachable on negative-origin
# external left of a 250%-scaled laptop primary. No actual secondary monitor
# is required for these exact numerical WinForms geometry contracts.
Assert-Lbs144Hotfix 'Post-show modal recovery function defined' ($null -ne (Get-Command Register-LenovoDialogVisibilityCorrection -ErrorAction SilentlyContinue))
Assert-Lbs144Hotfix 'Pure monitor-work-area clamp is defined' ($null -ne (Get-Command Get-LenovoVisibleDialogLocation -ErrorAction SilentlyContinue))
$left=[Drawing.Rectangle]::new(-1920,0,1920,1032)
$right=[Drawing.Rectangle]::new(0,0,3840,2280)
$size=[Drawing.Size]::new(1175,613)
$leftPos=Get-LenovoVisibleDialogLocation -WorkingArea $left -WindowSize $size
Assert-Lbs144Hotfix 'Left external negative-origin dialog stays fully visible' ($leftPos.X -ge $left.Left -and $leftPos.X+$size.Width -le $left.Right -and $leftPos.Y -ge 0 -and $leftPos.Y+$size.Height -le $left.Bottom)
$rightPos=Get-LenovoVisibleDialogLocation -WorkingArea $right -WindowSize $size
Assert-Lbs144Hotfix 'Right main laptop dialog stays fully visible' ($rightPos.X -ge $right.Left -and $rightPos.X+$size.Width -le $right.Right -and $rightPos.Y+$size.Height -le $right.Bottom)
$actual=[System.Windows.Forms.Screen]::PrimaryScreen
$f=New-Object System.Windows.Forms.Form
try {
  $f.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None
  $f.StartPosition=[System.Windows.Forms.FormStartPosition]::Manual
  $f.ShowInTaskbar=$false
  $f.TopMost=$true
  $f.Size=[Drawing.Size]::new(390,220)
  $f.Location=[Drawing.Point]::new(-30000,-30000)
  Register-LenovoDialogVisibilityCorrection -Form $f -Screen $actual
  $f.Show()
  [System.Windows.Forms.Application]::DoEvents()
  $work=$actual.WorkingArea
  Assert-Lbs144Hotfix 'Actual topmost modal HWND stays visible after Shown' ($f.IsHandleCreated -and $f.Left -ge $work.Left -and $f.Top -ge $work.Top -and $f.Right -le $work.Right -and $f.Bottom -le $work.Bottom)
} finally { $f.Dispose() }
$dialogs=[IO.File]::ReadAllText((Join-Path $root 'src\UI\Dialogs.ps1'))
Assert-Lbs144Hotfix 'All regular modals register post-HWND visibility correction' ($dialogs.Contains('Register-LenovoDialogVisibilityCorrection -Form $Form -Screen $screen'))
Assert-Lbs144Hotfix 'Ownerless modal falls back to stable primary display' ($dialogs.Contains('[System.Windows.Forms.Screen]::PrimaryScreen'))

# P3: include the entire actual monitor topology, not just one selected
# Screen.Primary flag and the selected target window.
Assert-Lbs144Hotfix 'Full monitor topology collector is defined' ($null -ne (Get-Command Get-LenovoMonitorTopologySnapshot -ErrorAction SilentlyContinue))
$all=@(Get-LenovoMonitorTopologySnapshot)
Assert-Lbs144Hotfix 'Topology count equals the real WinForms AllScreens count' ($all.Count -eq @([System.Windows.Forms.Screen]::AllScreens).Count)
Assert-Lbs144Hotfix 'Each topology entry exposes device, origin, working bounds and primary status' (@($all | Where-Object { -not $_.Contains('deviceName') -or -not $_.Contains('boundsLeft') -or -not $_.Contains('workLeft') -or -not $_.Contains('isPrimary') }).Count -eq 0)
$diag=[IO.File]::ReadAllText((Join-Path $root 'src\UI\DpiWindowDiagnostics.ps1'))
$app=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
Assert-Lbs144Hotfix 'Topological snapshots are logged read-only for diagnostic recovery' ($diag.Contains("MONITOR_TOPOLOGY_SNAPSHOT") -and $app.Contains('Write-LenovoMonitorTopologyEvent'))
Write-Host "LBS144 P123 TOTAL $script:passed/27"
if ($script:passed -ne 27) { throw "Expected exactly 27 native mixed-monitor checks, saw $script:passed" }
