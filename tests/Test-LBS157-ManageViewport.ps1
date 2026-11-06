#requires -version 5.1
# LBS-157: native WinForms Manage Entries viewport and mixed-DPI layout regression.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$rootPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $rootPath 'src\UI\BootEntryList.ps1')
. (Join-Path $rootPath 'src\UI\BootEntryRows.ps1')
. (Join-Path $rootPath 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $rootPath 'src\UI\PopupComposition.ps1')
. (Join-Path $rootPath 'src\UI\ManageEntries.ps1')

$script:checks = 0
function Assert-Lbs157([string]$Name, [bool]$Pass) {
    if (-not $Pass) { throw "LBS157 VIEWPORT RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS157 VIEWPORT $Name"
}
function Get-LocalizedString { param([string]$Key, $Values) return $Key }
function Get-CurrentSystemFunctionsCapabilities {
    return [pscustomobject]@{ CanManageEntries = $true }
}
function Stop-ManageEntriesMode { param([switch]$Save) }
$script:ColorSurface = [Drawing.Color]::FromArgb(32,32,32)
$script:ColorBackground = [Drawing.Color]::FromArgb(29,29,29)
$script:ColorPrimary = [Drawing.Color]::FromArgb(230,230,230)
$script:ColorSecondary = [Drawing.Color]::FromArgb(170,170,170)
$script:ColorAccent = [Drawing.Color]::Red
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(42,42,42)
$script:AppVersion = '1.1.15.0'

$form = New-Object System.Windows.Forms.Form
try {
    $script:Popup = $form
    Initialize-PopupDpiLayout -Form $form
    $form.ClientSize = [Drawing.Size]::new(390,672)
    $rootPanel = New-Object System.Windows.Forms.Panel
    $rootPanel.Name = 'PopupRoot'
    $rootPanel.Size = [Drawing.Size]::new(390,672)
    $form.Controls.Add($rootPanel)
    $listPanel = New-Object System.Windows.Forms.Panel
    $listPanel.Name = 'EntryList'
    $listPanel.Location = [Drawing.Point]::new(0,88)
    $listPanel.Size = [Drawing.Size]::new(390,402)
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Name = 'EntryContent'
    $contentPanel.Size = [Drawing.Size]::new(390,402)
    $listPanel.Controls.Add($contentPanel)
    $bar = New-Object System.Windows.Forms.VScrollBar
    $bar.Name = 'EntryScroll'
    $bar.Location = [Drawing.Point]::new(382,0)
    $bar.Size = [Drawing.Size]::new(8,402)
    $listPanel.Controls.Add($bar)
    $rootPanel.Controls.Add($listPanel)
    $normalFooter = New-Object System.Windows.Forms.Panel
    $normalFooter.Name = 'FooterPanel'
    $normalFooter.Location = [Drawing.Point]::new(0,652)
    $normalFooter.Size = [Drawing.Size]::new(390,20)
    $rootPanel.Controls.Add($normalFooter)
    Add-PopupManageEntriesSection -Root $rootPanel
    $manage = $rootPanel.Controls['ManageEntriesPanel']
    Assert-Lbs157 'Real composition creates Manage Entries panel' ($null -ne $manage)
    Complete-PopupDpiLayout -Form $form -Scale 1.0

    foreach ($factor in @(1.0,1.25,1.5,2.0,2.5,3.0)) {
        [void](Set-PopupDpiLayoutScale -Form $form -Scale $factor)
        $script:IsManageEntriesMode = $true
        Update-ManageEntriesUiState
        $expanded = [int][Math]::Round(436 * $factor)
        $normal = [int][Math]::Round(402 * $factor)
        $manageY = [int][Math]::Round(524 * $factor)
        $buttons = @($manage.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] })
        $footer = @($manage.Controls | Where-Object { $_ -is [System.Windows.Forms.Panel] -and $_.Height -gt [int][Math]::Round(20*$factor) -and $_.Top -gt 0 } | Select-Object -First 1)
        Assert-Lbs157 ("{0}% Manage viewport gains 34 design pixels" -f ($factor*100)) ($listPanel.Height -eq $expanded -and $listPanel.Height -gt $normal)
        Assert-Lbs157 ("{0}% custom scrollbar follows viewport" -f ($factor*100)) ($bar.Height -eq $expanded)
        Assert-Lbs157 ("{0}% list and controls meet without overlap" -f ($factor*100)) ($listPanel.Bottom -eq $manage.Top -and $manage.Top -eq $manageY)
        Assert-Lbs157 ("{0}% Manage panel stays inside popup" -f ($factor*100)) ($manage.Bottom -eq $rootPanel.Height)
        Assert-Lbs157 ("{0}% cancel/save and footer preserve clearance" -f ($factor*100)) (
            $buttons.Count -eq 2 -and $footer.Count -eq 1 -and
            $buttons[0].Bottom -le $footer[0].Top -and $buttons[1].Bottom -le $footer[0].Top -and
            $footer[0].Bottom -eq $manage.Height
        )
        $modelBar = [pscustomobject]@{ LargeChange=0; SmallChange=0; Maximum=0; Visible=$false; Value=0 }
        $total = [int][Math]::Round(500*$factor)
        Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $modelBar -ContentBottom $total -BaseRowHeight ([int][Math]::Round(60*$factor)) -RowGap ([int][Math]::Round(4*$factor))
        Assert-Lbs157 ("{0}% scroll range uses expanded viewport" -f ($factor*100)) (
            $modelBar.Maximum -eq ($total-$expanded) -and $modelBar.LargeChange -eq $expanded
        )
        $script:IsManageEntriesMode = $false
        Update-ManageEntriesUiState
        Assert-Lbs157 ("{0}% normal viewport is restored" -f ($factor*100)) ($listPanel.Height -eq $normal -and $bar.Height -eq $normal)
        Assert-Lbs157 ("{0}% normal settings remain separated" -f ($factor*100)) ($listPanel.Bottom -eq [int][Math]::Round(490*$factor) -and $normalFooter.Bottom -eq $rootPanel.Height)
    }

    [void](Set-PopupDpiLayoutScale -Form $form -Scale 2.5)
    [void](Set-PopupViewportForWorkingArea -Form $form -WorkingArea ([Drawing.Rectangle]::new(0,0,3840,1100)))
    Assert-Lbs157 'Short display caps popup and exposes root scrolling' ($form.ClientSize.Height -eq 1088 -and $rootPanel.AutoScroll)
    [void](Set-PopupViewportForWorkingArea -Form $form -WorkingArea ([Drawing.Rectangle]::new(0,0,3840,2400)))
    Assert-Lbs157 'Tall display restores full viewport without root scrolling' ($form.ClientSize.Height -eq 1680 -and -not $rootPanel.AutoScroll)
}
finally {
    $form.Dispose()
    $script:Popup = $null
}
if ($script:checks -ne 51) { throw "LBS157 VIEWPORT count mismatch: $script:checks expected=51" }
Write-Host "LBS157 VIEWPORT TOTAL $script:checks/51"
