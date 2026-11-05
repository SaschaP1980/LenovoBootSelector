#requires -version 5.1
# LBS-144 focused, real-WinForms RED/GREEN. Design pixels at 96 DPI.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
function Assert-DpiPhysical([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS-144 RED: $Name" }
    Write-Host "PASS LBS-144 $Name"
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
    $header.Text = 'Lenovo Boot Selector'
    $header.Location = [Drawing.Point]::new(16,19)
    $header.Size = [Drawing.Size]::new(285,22)
    $header.Font = New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)
    $rootPanel.Controls.Add($header)
    $baseFontSize = [double]$header.Font.Size
    Complete-PopupDpiLayout -Form $form -Scale 1.0
    Assert-DpiPhysical '96 DPI initial geometry' ($form.ClientSize.Width -eq 390 -and $header.Width -eq 285)
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 2.5)
    Assert-DpiPhysical '240 DPI physical popup width and height' ($form.ClientSize.Width -eq 975 -and $form.ClientSize.Height -eq 1680)
    Assert-DpiPhysical '240 DPI physical header bounds' ($header.Left -eq 40 -and $header.Width -ge 712 -and $header.Height -ge 55)
    Assert-DpiPhysical '240 DPI header font scales with bounds' ($header.Font.Size -ge ($baseFontSize * 2.45))
    Assert-DpiPhysical '240 DPI dynamic row scale reported' ([Math]::Abs((Get-PopupDpiLayoutScale -Popup $form)-2.5) -lt .001)
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = [Drawing.Size]::new(390,60)
    $title = New-Object System.Windows.Forms.Label
    $title.Name = 'BootTitleLabel'
    $title.Text = 'Gaming Windows'
    $title.Location = [Drawing.Point]::new(58,6)
    $title.Size = [Drawing.Size]::new(284,21)
    $title.Font = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $row.Controls.Add($title)
    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.Text = 'USB startup device'
    $subtitle.Location = [Drawing.Point]::new(58,27)
    $subtitle.Size = [Drawing.Size]::new(284,27)
    $subtitle.Font = New-Object Drawing.Font('Segoe UI',8.3,[Drawing.FontStyle]::Regular)
    $row.Controls.Add($subtitle)
    $h = Set-PopupBootRowDpiLayout -Row $row -Scale (Get-PopupDpiLayoutScale -Popup $form) -Y 225
    Assert-DpiPhysical '240 DPI row width and height' ($row.Width -eq 975 -and $h -eq 150)
    Assert-DpiPhysical '240 DPI row typography and layout' ($title.Font.Size -gt 20 -and $subtitle.Font.Size -gt 16 -and $title.Bottom -le $subtitle.Top)
    $row.Dispose()
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 1.0)
    Assert-DpiPhysical 'Return to 96 DPI recovers design geometry' ($form.ClientSize.Width -eq 390 -and $header.Width -eq 285 -and [Math]::Abs($header.Font.Size - $baseFontSize) -lt 0.1)
}
finally { $form.Dispose() }
Write-Host 'LBS-144 FOCUSED NATIVE DPI RESULT=PASS'
Write-Output 8
