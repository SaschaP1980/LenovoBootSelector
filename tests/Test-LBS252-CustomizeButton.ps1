#requires -version 5.1
# LBS-252: actual main-popup header and capability-driven native Button state.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Application\SystemCapabilities.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\ManageEntries.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:ColorHeader=[Drawing.Color]::Black
$script:ColorBackground=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorSecondary=[Drawing.Color]::FromArgb(184,184,184)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(44,25,24)
$script:IsManageEntriesMode=$false
$script:ManageCalls=0
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-CurrentSystemFunctionsCapabilities {
    Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $script:SessionReady -MaintenanceBusy $false -DriftDetected $false -EntryCount 1
}
# Fixture isolates unrelated actions and label creation; the target button
# and its Enabled transition are created and owned by production functions.
function New-Label {
    param($Text,$Font,$ForeColor,$X,$Y,$Width,$Height)
    $label=[Windows.Forms.Label]::new()
    $label.Text=$Text; $label.Font=$Font; $label.ForeColor=$ForeColor
    $label.Bounds=[Drawing.Rectangle]::new($X,$Y,$Width,$Height)
    return $label
}
function Update-RefreshButtonVisual {}
function Start-ManageEntriesMode { $script:ManageCalls++ }
function Get-VisibleInk([Windows.Forms.Button]$Button) {
    $Button.Refresh()
    [Windows.Forms.Application]::DoEvents()
    $bm=[Drawing.Bitmap]::new($Button.Width,$Button.Height)
    $g=[Drawing.Graphics]::FromImage($bm)
    try {
        $g.CopyFromScreen($Button.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$Button.ClientSize)
        if ($bm.GetPixel(2,2).ToArgb() -ne $Button.BackColor.ToArgb()) { throw 'LBS252 fixture background not visible' }
        $peak=0; $bright=0
        # Ignore perimeter: native default/focus frame is not text ink.
        for ($y=4;$y -lt $bm.Height-4;$y++) {
            for ($x=4;$x -lt $bm.Width-4;$x++) {
                $p=$bm.GetPixel($x,$y)
                $v=[int][Math]::Round(0.2126*$p.R+0.7152*$p.G+0.0722*$p.B)
                $peak=[Math]::Max($peak,$v)
                if ($v -ge 120) { $bright++ }
            }
        }
        return [pscustomobject]@{Peak=$peak;Bright=$bright}
    } finally { $g.Dispose(); $bm.Dispose() }
}
$failures=[Collections.Generic.List[string]]::new()
$checks=0
foreach ($locale in @('de-DE','en-US')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $script:SessionReady=$null
        $form=[Windows.Forms.Form]::new()
        $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
        $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
        $form.Location=[Drawing.Point]::new(0,0)
        $form.TopMost=$true
        $script:Popup=$form
        try {
            Initialize-PopupDpiLayout -Form $form
            $form.ClientSize=[Drawing.Size]::new(390,100)
            $panel=[Windows.Forms.Panel]::new()
            $panel.Size=$form.ClientSize
            $panel.BackColor=$script:ColorBackground
            $form.Controls.Add($panel)
            Add-PopupHeaderSection -Root $panel
            $button=$script:ManageEntriesButton
            Complete-PopupDpiLayout -Form $form -Scale $scale
            Update-ManageEntriesUiState
            $form.Show()
            $form.Activate()
            [Windows.Forms.Cursor]::Position=$form.PointToScreen([Drawing.Point]::new(5,5))
            [Windows.Forms.Application]::DoEvents()
            if ($button.Enabled -or $button.CanSelect -or $button.Text -ne (Get-LocalizedString -Key 'Popup.Customize')) { throw 'LBS252 fixture invalid Checking gate or localized label' }
            $before=$script:ManageCalls
            $button.PerformClick()
            if ($script:ManageCalls -ne $before) { throw 'LBS252 disabled action dispatched' }
            $disabled=Get-VisibleInk $button
            $script:SessionReady=$true
            Update-ManageEntriesUiState
            $form.ActiveControl=$script:RefreshButton
            [Windows.Forms.Application]::DoEvents()
            $enabled=Get-VisibleInk $button
            if (-not $button.Enabled -or -not $button.CanSelect -or $enabled.Peak -lt 160 -or $enabled.Bright -lt 10) { throw 'LBS252 fixture invalid Ready gate or visible text' }
            $button.PerformClick()
            if ($script:ManageCalls -ne $before+1) { throw 'LBS252 enabled native dispatch lost' }
            Write-Host "LBS252 RASTER locale=$locale scale=$scale disabledPeak=$($disabled.Peak) disabledBright=$($disabled.Bright) enabledPeak=$($enabled.Peak) enabledBright=$($enabled.Bright)"
            if ($disabled.Peak -ge 120 -and $disabled.Peak -lt $enabled.Peak -and $disabled.Bright -ge 10) {
                $checks++
                Write-Host "PASS LBS252 $locale $scale disabled ink legible and subdued"
            } else { $failures.Add("$locale $scale") }
        } finally { $form.Dispose(); $script:Popup=$null; $script:ManageEntriesButton=$null; $script:RefreshButton=$null }
    }
}
Write-Host "LBS252 CUSTOMIZE TOTAL $checks/4"
if ($failures.Count) { throw ("LBS252 RED: disabled ink contrast: " + ($failures -join ', ')) }
