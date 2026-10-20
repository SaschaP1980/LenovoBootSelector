#requires -version 5.1
# LBS-144 correction: real WinForms form, nested header/footer and boot row
# geometry. Earlier synthetic mock widths did not test the visible form.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$rootPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $rootPath 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
function Assert-PopupDpi([string]$Name, [bool]$Ok) {
    if (-not $Ok) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS $Name"
}
$currentDisplayScale = Get-PopupMonitorDpiScale -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
Assert-PopupDpi 'Actual monitor scale API/fallback returns a bounded percentage' ($currentDisplayScale.Factor -ge 1.0 -and $currentDisplayScale.Factor -le 5.0 -and $currentDisplayScale.Percent -ge 100)
foreach ($percent in @(100,125,150,200,250)) {
    $factor = Resolve-PopupDpiScale -Percent $percent
    Assert-PopupDpi ("Monitor scale {0}%" -f $percent) ([Math]::Abs($factor - $percent / 100.0) -lt 0.001)
}
foreach ($invalid in @(0,501)) {
    $rejected = $false
    try { [void](Resolve-PopupDpiScale -Percent $invalid) } catch { $rejected = $true }
    Assert-PopupDpi ("Invalid percent {0} is rejected" -f $invalid) $rejected
}
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
try {
    Initialize-PopupDpiLayout -Form $form
    Assert-PopupDpi 'Avoid conflicting WinForms autoscale pass' ($form.AutoScaleMode -eq [System.Windows.Forms.AutoScaleMode]::None)
    $form.ClientSize = [Drawing.Size]::new(390,672)
    $rootPanel = New-Object System.Windows.Forms.Panel
    $rootPanel.Size = [Drawing.Size]::new(390,672)
    $rootPanel.Name = 'PopupRoot'
    $form.Controls.Add($rootPanel)
    $header = New-Object System.Windows.Forms.Label
    $header.Name = 'HeaderTitleLabel'
    $header.Text = 'Lenovo Boot Selector'
    $header.Location = [Drawing.Point]::new(16,19)
    $header.Size = [Drawing.Size]::new(285,22)
    $header.Font = New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)
    $rootPanel.Controls.Add($header)
    $restart = New-Object System.Windows.Forms.Button
    $restart.Text = 'Windows neu starten'
    $restart.Location = [Drawing.Point]::new(16,593)
    $restart.Size = [Drawing.Size]::new(358,31)
    $rootPanel.Controls.Add($restart)
    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = 'v1.1.11.0'
    $footer.Location = [Drawing.Point]::new(316,652)
    $footer.Size = [Drawing.Size]::new(58,18)
    $rootPanel.Controls.Add($footer)
    Complete-PopupDpiLayout -Form $form -Scale 1
    Assert-PopupDpi '100% form is 390px' ($form.ClientSize.Width -eq 390)
    Assert-PopupDpi '100% root tracks form width' ($rootPanel.Width -eq 390)
    Assert-PopupDpi '100% header fits within root' ($header.Right -le $rootPanel.Width)
    $changed = Set-PopupDpiLayoutScale -Form $form -Scale 2.5
    Assert-PopupDpi '250% explicitly scales completed form' $changed
    Assert-PopupDpi '250% physical form width near 975px' ($form.ClientSize.Width -ge 970 -and $form.ClientSize.Width -le 980)
    Assert-PopupDpi '250% physical form height near 1680px' ($form.ClientSize.Height -ge 1675 -and $form.ClientSize.Height -le 1685)
    Assert-PopupDpi '250% root matches form client width' ([Math]::Abs($rootPanel.Width-$form.ClientSize.Width) -le 2)
    Assert-PopupDpi '250% root also matches exact form client height' ([Math]::Abs($rootPanel.Height-$form.ClientSize.Height) -le 2)
    Assert-PopupDpi '250% header width scales with parent' ($header.Width -ge 710 -and $header.Width -le 715)
    Assert-PopupDpi '250% header height is sufficient for enlarged font' ($header.Height -ge 54)
    Assert-PopupDpi '250% restart control remains inside form' ($restart.Bottom -le $rootPanel.Height)
    Assert-PopupDpi '250% version footer remains inside form' ($footer.Bottom -le $rootPanel.Height)
    $largeFont = New-Object Drawing.Font('Segoe UI',25.5,[Drawing.FontStyle]::Bold)
    try {
        $measure = [System.Windows.Forms.TextRenderer]::MeasureText($header.Text,$largeFont)
        Assert-PopupDpi 'High-DPI 25.5pt header fits height' ($header.Height -ge $measure.Height)
        Assert-PopupDpi 'High-DPI 25.5pt header fits width' ($header.Width -ge $measure.Width)
    }
    finally { $largeFont.Dispose() }
    Assert-PopupDpi 'Live window factor reads actual 250%' ([Math]::Abs((Get-PopupDpiLayoutScale -Popup $form)-2.5) -lt 0.02)
    Assert-PopupDpi 'Reposition on same monitor never double-scales' (-not (Set-PopupDpiLayoutScale -Form $form -Scale 2.5))
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 1.25)
    Assert-PopupDpi '125% monitor move scales completed form again' ($form.ClientSize.Width -ge 485 -and $form.ClientSize.Width -le 490)
    Assert-PopupDpi '125% header remains inside new root' ($header.Right -le $rootPanel.Width)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = [Drawing.Size]::new(390,60)
    $title = New-Object System.Windows.Forms.Label
    $title.Name = 'BootTitleLabel'
    $title.Text = 'Windows Gaming'
    $title.Location = [Drawing.Point]::new(58,6)
    $title.Size = [Drawing.Size]::new(284,21)
    $row.Controls.Add($title)
    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.Text = 'USB-Startmedium'
    $subtitle.Location = [Drawing.Point]::new(58,27)
    $subtitle.Size = [Drawing.Size]::new(284,27)
    $row.Controls.Add($subtitle)
    $height = Set-PopupBootRowDpiLayout -Row $row -Scale 2.5 -Y 166
    Assert-PopupDpi 'Dynamic row physical width scales' ($row.Width -ge 973)
    Assert-PopupDpi 'Dynamic row physical height scales' ($height -eq 150)
    Assert-PopupDpi 'Dynamic title and subtitle never overlap' ($title.Bottom -le $subtitle.Top)
    Assert-PopupDpi 'Dynamic subtitle fits inside row' ($subtitle.Bottom -le $row.Height)
    Assert-PopupDpi 'Dynamic row full text remains present' ($title.Text -eq 'Windows Gaming' -and $subtitle.Text -eq 'USB-Startmedium')
    Assert-PopupDpi 'Dynamic row scroll top uses physical pixels' ($row.Top -eq 166)
    $row.Dispose()
}
finally { $form.Dispose() }
Write-Host "POPUP DPI TOTAL $script:checks/33"
if ($script:checks -ne 33) { throw "Expected 33 popup DPI checks, got $script:checks" }
