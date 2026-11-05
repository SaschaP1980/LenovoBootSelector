#requires -version 5.1
# LBS-144: mixed-DPI regression on actual WinForms controls, not mock width.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\PopupPosition.ps1')
$script:checks = 0
function Assert-PopupDpi([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS $Name"
}
$reported = Get-PopupMonitorDpiScale -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
Assert-PopupDpi 'Windows monitor scale probe bounded' ($reported.Factor -ge 1 -and $reported.Factor -le 5)
foreach ($percent in @(100,125,150,200,250)) {
    $factor = Resolve-PopupDpiScale -Percent $percent
    Assert-PopupDpi ("Monitor report {0}%" -f $percent) ([Math]::Abs($factor - $percent/100.0) -lt 0.001)
}
foreach ($invalid in @(0,501)) {
    $rejected = $false
    try { [void](Resolve-PopupDpiScale -Percent $invalid) } catch { $rejected = $true }
    Assert-PopupDpi ("Invalid percent {0}" -f $invalid) $rejected
}
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
try {
    Initialize-PopupDpiLayout -Form $form
    Assert-PopupDpi 'Single logical WinForms scaling contract' ($form.AutoScaleMode -eq [System.Windows.Forms.AutoScaleMode]::None)
    $form.ClientSize = [Drawing.Size]::new(390,672)
    $rootPanel = New-Object System.Windows.Forms.Panel
    $rootPanel.Size = [Drawing.Size]::new(390,672)
    $rootPanel.Name = 'PopupRoot'
    $form.Controls.Add($rootPanel)
    $header = New-Object System.Windows.Forms.Label
    $header.Text = 'Lenovo Boot Selector'
    $header.Location = [Drawing.Point]::new(16,19)
    $header.Size = [Drawing.Size]::new(285,22)
    $header.Font = New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)
    $rootPanel.Controls.Add($header)
    $restart = New-Object System.Windows.Forms.Button
    $restart.Location = [Drawing.Point]::new(16,593)
    $restart.Size = [Drawing.Size]::new(358,31)
    $rootPanel.Controls.Add($restart)
    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = 'v1.1.12.0'
    $footer.Location = [Drawing.Point]::new(316,652)
    $footer.Size = [Drawing.Size]::new(58,18)
    $rootPanel.Controls.Add($footer)
    Complete-PopupDpiLayout -Form $form -Scale 1
    Assert-PopupDpi 'Logical form is 390x672' ($form.ClientSize.Width -eq 390 -and $form.ClientSize.Height -eq 672)
    Assert-PopupDpi 'Root has same logical geometry' ($rootPanel.Width -eq 390 -and $rootPanel.Height -eq 672)
    $fontHeight = $header.Font.Height
    Assert-PopupDpi 'Head text fits original label height' ($header.Height -ge $fontHeight)
    $changed = Set-PopupDpiLayoutScale -Form $form -Scale 2.5
    Assert-PopupDpi '100%-250% monitor transition observed' $changed
    Assert-PopupDpi 'Native 250% is diagnostic metadata' ([Math]::Abs([double]$form.Tag - 2.5) -lt .001)
    Assert-PopupDpi 'Native 250% never multiplies form size' ($form.ClientSize.Width -eq 390 -and $form.ClientSize.Height -eq 672)
    Assert-PopupDpi 'Native 250% never multiplies label size' ($header.Width -eq 285 -and $header.Height -eq 22)
    Assert-PopupDpi 'Native 250% preserves actual font' ($header.Font.Height -eq $fontHeight)
    Assert-PopupDpi 'New boot rows use the form coordinate system' ([Math]::Abs((Get-PopupDpiLayoutScale -Popup $form)-1.0) -lt .001)
    Assert-PopupDpi 'Same-monitor placement is idempotent' (-not (Set-PopupDpiLayoutScale -Form $form -Scale 2.5))
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 1.25)
    Assert-PopupDpi '125% switch cannot distort form/label font' ($form.ClientSize.Width -eq 390 -and $header.Font.Height -eq $fontHeight)
    $normal = [Drawing.Rectangle]::new(1920,0,1536,912)
    [void](Set-PopupViewportForWorkingArea -Form $form -WorkingArea $normal)
    Assert-PopupDpi '250% logical work area fits entire popup' ($form.ClientSize.Height -eq 672 -and $form.ClientSize.Width -eq 390)
    Assert-PopupDpi 'Normal work area has no scrollbars' (-not $rootPanel.AutoScroll)
    Assert-PopupDpi 'Restart and footer remain inside popup' ($restart.Bottom -le $rootPanel.Height -and $footer.Bottom -le $rootPanel.Height)
    $short = [Drawing.Rectangle]::new(1920,0,1536,520)
    [void](Set-PopupViewportForWorkingArea -Form $form -WorkingArea $short)
    Assert-PopupDpi 'Short screen caps popup viewport' ($form.ClientSize.Height -ge 500 -and $form.ClientSize.Height -le 508)
    Assert-PopupDpi 'Short screen exposes native scrolling' ($rootPanel.AutoScroll -and $rootPanel.AutoScrollMinSize.Height -eq 672)
    [void](Set-PopupViewportForWorkingArea -Form $form -WorkingArea $normal)
    Assert-PopupDpi 'Returning to tall screen restores full client height' ($form.ClientSize.Height -eq 672)
    Assert-PopupDpi 'Returning to tall screen disables native scrolling' (-not $rootPanel.AutoScroll)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = [Drawing.Size]::new(390,60)
    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Windows Gaming'
    $title.Location = [Drawing.Point]::new(58,6)
    $title.Size = [Drawing.Size]::new(284,21)
    $title.Font = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $row.Controls.Add($title)
    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'USB-Startmedium'
    $subtitle.Location = [Drawing.Point]::new(58,27)
    $subtitle.Size = [Drawing.Size]::new(284,27)
    $subtitle.Font = New-Object Drawing.Font('Segoe UI',8.3,[Drawing.FontStyle]::Regular)
    $row.Controls.Add($subtitle)
    $height = Set-PopupBootRowDpiLayout -Row $row -Scale (Get-PopupDpiLayoutScale -Popup $form) -Y 90
    Assert-PopupDpi 'Dynamic row remains 390x60 logical' ($row.Width -eq 390 -and $height -eq 60)
    Assert-PopupDpi 'Boot titles and descriptions do not overlap' ($title.Bottom -le $subtitle.Top)
    Assert-PopupDpi 'Boot row fonts fit labels' ($title.Font.Height -le $title.Height -and $subtitle.Font.Height -le $subtitle.Height)
    Assert-PopupDpi 'Boot row texts still visible in model' ($title.Text.Length -gt 0 -and $subtitle.Text.Length -gt 0)
    Assert-PopupDpi 'Boot row Y offset remains logical' ($row.Top -eq 90)
    $row.Dispose()
    $size = [Drawing.Size]::new(260,235)
    $a = [Drawing.Rectangle]::new(0,0,1920,1080)
    $aw = [Drawing.Rectangle]::new(0,0,1920,1040)
    $p = [Drawing.Point]::new(1840,1050)
    $menu = Get-TrayContextMenuLocation -ClickPoint $p -MenuSize $size -WorkingArea $aw -DisplayBounds $a
    Assert-PopupDpi '100% screen tray menu appears above click' ($menu.Y + $size.Height -lt $p.Y)
    Assert-PopupDpi '100% screen menu stays on same monitor' ($menu.X -ge $aw.Left -and ($menu.X + $size.Width) -le $aw.Right)
    $b = [Drawing.Rectangle]::new(1920,0,1536,960)
    $bw = [Drawing.Rectangle]::new(1920,0,1536,912)
    $q = [Drawing.Point]::new(3380,935)
    $otherMenu = Get-TrayContextMenuLocation -ClickPoint $q -MenuSize $size -WorkingArea $bw -DisplayBounds $b
    Assert-PopupDpi '250% logical screen tray menu stays on same monitor' ($otherMenu.X -ge $bw.Left -and $otherMenu.X + $size.Width -le $bw.Right)
    Assert-PopupDpi '250% logical screen tray menu appears above click' ($otherMenu.Y + $size.Height -lt $q.Y)
    $topWork = [Drawing.Rectangle]::new(0,48,1920,1032)
    $topMenu = Get-TrayContextMenuLocation -ClickPoint ([Drawing.Point]::new(800,20)) -MenuSize $size -WorkingArea $topWork -DisplayBounds $a
    Assert-PopupDpi 'Top dock menu is positioned below taskbar' ($topMenu.Y -ge $topWork.Top)
    $leftWork = [Drawing.Rectangle]::new(48,0,1872,1080)
    $leftMenu = Get-TrayContextMenuLocation -ClickPoint ([Drawing.Point]::new(25,530)) -MenuSize $size -WorkingArea $leftWork -DisplayBounds $a
    Assert-PopupDpi 'Left dock menu is positioned to its right' ($leftMenu.X -ge $leftWork.Left)
}
finally { $form.Dispose() }
Write-Host "POPUP DPI TOTAL $script:checks/38"
if ($script:checks -ne 38) { throw "Expected 38 popup DPI checks, got $script:checks" }
