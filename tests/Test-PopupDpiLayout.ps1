#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
function Assert-PopupDpi([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS $Name"
}
$form = New-Object System.Windows.Forms.Form
try {
    Initialize-PopupDpiLayout -Form $form
    Assert-PopupDpi 'DPI-aware form autoscaling selected' ($form.AutoScaleMode -eq [System.Windows.Forms.AutoScaleMode]::Dpi)
    Assert-PopupDpi '96-DPI design dimensions before layout' ([Math]::Abs($form.AutoScaleDimensions.Width - 96) -lt 0.1)
    $form.ClientSize = [Drawing.Size]::new(390, 672)
    Complete-PopupDpiLayout -Form $form
    foreach ($factor in @(1.0,1.25,1.5,2.0,2.5)) {
        $width = [int][Math]::Round(390 * $factor)
        $mock = New-Object System.Windows.Forms.Panel
        $mock.Size = [Drawing.Size]::new($width, 672)
        $actual = Get-PopupDpiLayoutScale -Popup $mock
        Assert-PopupDpi ("Width yields layout factor {0}" -f $factor) ([Math]::Abs($actual - $factor) -lt 0.003)
        $mock.Dispose()
    }
    $one = New-Object System.Windows.Forms.Panel
    $one.Size = [Drawing.Size]::new(390, 60)
    $oneTitle = New-Object System.Windows.Forms.Label
    $oneTitle.Location = [Drawing.Point]::new(58, 6)
    $oneTitle.Size = [Drawing.Size]::new(284, 21)
    $one.Controls.Add($oneTitle)
    $oneHeight = Set-PopupBootRowDpiLayout -Row $one -Scale 1 -Y 64
    Assert-PopupDpi '100% width unchanged' ($one.Width -eq 390)
    Assert-PopupDpi '100% height unchanged' ($oneHeight -eq 60)
    Assert-PopupDpi '100% row vertical list position' ($one.Top -eq 64)
    $scaled = New-Object System.Windows.Forms.Panel
    $scaled.Size = [Drawing.Size]::new(390, 60)
    $title = New-Object System.Windows.Forms.Label
    $title.Location = [Drawing.Point]::new(58,6)
    $title.Size = [Drawing.Size]::new(284,21)
    $scaled.Controls.Add($title)
    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Location = [Drawing.Point]::new(58,27)
    $subtitle.Size = [Drawing.Size]::new(284,27)
    $scaled.Controls.Add($subtitle)
    $height = Set-PopupBootRowDpiLayout -Row $scaled -Scale 2.5 -Y 166
    Assert-PopupDpi '250% row width 975 px' ($scaled.Width -eq 975)
    Assert-PopupDpi '250% row height 150 px' ($height -eq 150)
    Assert-PopupDpi '250% physical scroll position' ($scaled.Top -eq 166)
    Assert-PopupDpi '250% title padding' ($title.Left -ge 144 -and $title.Left -le 146)
    Assert-PopupDpi '250% title/subtitle nonoverlap' ($title.Bottom -le $subtitle.Top)
    Assert-PopupDpi '250% subtitle inside row' ($subtitle.Bottom -le $scaled.Height)
    $one.Dispose()
    $scaled.Dispose()
}
finally { $form.Dispose() }
Write-Host "POPUP DPI TOTAL $script:checks/16"
if ($script:checks -ne 16) { throw "Expected 16 popup DPI checks, got $script:checks" }
