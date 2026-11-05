#requires -version 5.1
# LBS-144: high-DPI glyph-pixel regression. This is a 240-DPI font
# measurement, not an assertion on Font.Size point units alone.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
$script:checks = 0
function Assert-Lbs144FontFit {
    param([string]$Name,[bool]$Condition)
    if (-not $Condition) { throw "LBS-144 PHYSICAL-FONT RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS-144 PHYSICAL-FONT $Name"
}
function Assert-TextHeightFit {
    param([string]$Name,[System.Drawing.Font]$Font,[int]$MaxPixels,[single]$Dpi)
    $pixels = [double]$Font.GetHeight($Dpi)
    Write-Host ("LBS144_FONT_METRIC name={0} dpi={1} pointSize={2:F2} measuredPixels={3:F2} allottedPixels={4}" -f $Name,$Dpi,$Font.Size,$pixels,$MaxPixels)
    Assert-Lbs144FontFit -Name $Name -Condition ($pixels -le [double]$MaxPixels)
}
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
try {
    Initialize-PopupDpiLayout -Form $form
    $form.ClientSize = [Drawing.Size]::new(390,672)
    $rootPanel = New-Object System.Windows.Forms.Panel
    $rootPanel.Name = 'PopupRoot'
    $rootPanel.Size = [Drawing.Size]::new(390,672)
    $form.Controls.Add($rootPanel)
    $header = New-Object System.Windows.Forms.Label
    $header.Name = 'HeaderTitleLabel'
    $header.Location = [Drawing.Point]::new(16,19)
    $header.Size = [Drawing.Size]::new(285,22)
    $header.Font = New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)
    $rootPanel.Controls.Add($header)
    Complete-PopupDpiLayout -Form $form -Scale 1.0
    Assert-TextHeightFit -Name '96 DPI header line fits design label' -Font $header.Font -MaxPixels $header.Height -Dpi ([single]96)
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 2.5)
    Assert-Lbs144FontFit '240 DPI popup geometry scaled' ($form.ClientSize.Width -eq 975 -and $header.Height -eq 55)
    Assert-TextHeightFit -Name '240 DPI header line fits 55px label' -Font $header.Font -MaxPixels $header.Height -Dpi ([single]240)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = [Drawing.Size]::new(390,60)
    $title = New-Object System.Windows.Forms.Label
    $title.Name = 'BootTitleLabel'
    $title.Location = [Drawing.Point]::new(58,6)
    $title.Size = [Drawing.Size]::new(284,21)
    $title.Font = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $row.Controls.Add($title)
    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.Location = [Drawing.Point]::new(58,27)
    $subtitle.Size = [Drawing.Size]::new(284,27)
    $subtitle.Font = New-Object Drawing.Font('Segoe UI',8.3,[Drawing.FontStyle]::Regular)
    $row.Controls.Add($subtitle)
    $rowHeight = Set-PopupBootRowDpiLayout -Row $row -Scale 2.5 -Y 225
    Assert-Lbs144FontFit '240 DPI boot row geometry' ($rowHeight -eq 150)
    Assert-TextHeightFit -Name '240 DPI boot title fits label' -Font $title.Font -MaxPixels $title.Height -Dpi ([single]240)
    Assert-TextHeightFit -Name '240 DPI boot subtitle fits label' -Font $subtitle.Font -MaxPixels $subtitle.Height -Dpi ([single]240)
    $row.Dispose()
}
finally { $form.Dispose() }
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Font = New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Regular)
$item = New-Object System.Windows.Forms.ToolStripMenuItem('Open')
$item.Padding = [System.Windows.Forms.Padding]::new(18,4,32,4)
[void]$menu.Items.Add($item)
try {
    [void](Set-LenovoMenuDpiLayout -Menu $menu -Scale 2.5)
    Assert-Lbs144FontFit '240 DPI root menu row scaled' ($item.Height -ge 40)
    Assert-TextHeightFit -Name '240 DPI menu text fits item row' -Font $item.Font -MaxPixels $item.Height -Dpi ([single]240)
}
finally { $menu.Dispose() }
Write-Host "LBS-144 PHYSICAL-FONT TOTAL $script:checks/8"
if ($script:checks -ne 8) { throw 'LBS-144 expected eight physical-font checks.' }
Write-Output 8
