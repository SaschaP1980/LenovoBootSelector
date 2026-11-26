#requires -version 5.1
# LBS-215: native WinForms click-route regression; no real product, firmware or settings access.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks=0
function Assert-Lbs215([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "LBS215 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS215 $Name"
}
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,
        [int]$X,[int]$Y,[int]$Width,[int]$Height)
    $l=New-Object Windows.Forms.Label
    $l.Text=$Text; $l.Font=$Font; $l.ForeColor=$ForeColor
    $l.Location=[Drawing.Point]::new($X,$Y)
    $l.Size=[Drawing.Size]::new($Width,$Height)
    return $l
}
function Get-LocalizedString { param([string]$Key) return $Key }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{CanManageEntries=$true} }
function Test-ManageEntryHidden { param([string]$Guid) return [bool]$script:Hidden }
function Toggle-ManageEntryVisibility { param([string]$Guid) $script:VisibilityCalls++; $script:Hidden=-not $script:Hidden }
function Update-PopupRows { param([string]$Reason) $script:RefreshCalls++ }
function Invoke-NormalBootTargetSelection { param([string]$Guid) $script:BootSelectCalls++ }
function Save-AppSettings { $script:SettingsWrites++ }

$source=[IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
Assert-Lbs215 'Only grip Click is excluded from shared row click route' (
    $source.Contains('if ($control.Name -ne ''ManageReorderGrip'') { $control.Add_Click($clickHandler) }'))
Assert-Lbs215 'Grip remains in existing drag-capable row control collection' (
    $source.Contains('return @($row, $marker, $icon, $title, $subtitle, $state, $grip)') -and
    $source.Contains('$control.Add_MouseDown($mouseDownHandler)') -and
    $source.Contains('$control.Add_MouseMove($mouseMoveHandler)') -and
    $source.Contains('$control.Add_DragDrop($dragDropHandler)'))
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$click=[Windows.Forms.Control].GetMethod('OnClick',$flags)
$down=[Windows.Forms.Control].GetMethod('OnMouseDown',$flags)
$move=[Windows.Forms.Control].GetMethod('OnMouseMove',$flags)
if (-not $click -or -not $down -or -not $move) { throw 'Protected WinForms mouse methods missing.' }
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorRow=[Drawing.Color]::FromArgb(32,32,32)
$script:SettingsWrites=0; $script:BootSelectCalls=0
foreach ($factor in @(1.0,2.5)) {
    $dpi=[int][Math]::Round(96*$factor)
    $script:IsManageEntriesMode=$true
    $script:ManageAliasEditGuid=$null
    $script:ManageLastDragUtc=[datetime]::MinValue
    $script:ManageDragGuid=$null
    $script:ManageActiveDragGuid=$null
    $script:VisibilityCalls=0; $script:RefreshCalls=0; $script:Hidden=$false
    $script:BootSelectCalls=0
    $guid='12345678-1234-4234-8234-123456789abc'
    $entry=[pscustomobject]@{Guid=$guid}
    $script:Popup=New-Object Windows.Forms.Form
    $row=New-Object Windows.Forms.Panel
    $row.Name='BootRow'; $row.Tag=$guid
    $row.Size=[Drawing.Size]::new(390,60)
    $row.BackColor=$script:ColorRow
    try {
        $children=@()
        foreach ($name in @('Marker','BootTypeIcon','BootTitleLabel','BootSubtitleLabel')) {
            $label=New-Object Windows.Forms.Label
            $label.Name=$name; $label.Tag=$guid
            $label.Size=[Drawing.Size]::new(20,20)
            $row.Controls.Add($label)
            $children+= $label
        }
        $controls=@(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden $false -Marker $children[0] -Icon $children[1] -Title $children[2] -Subtitle $children[3])
        $grip=$row.Controls['ManageReorderGrip']
        $eye=$row.Controls['VisibilityGlyph']
        $pencil=$row.Controls['AliasEditButton']
        $script:Popup.Controls.Add($row)
        $handlers=New-BootEntryInteractionHandlers
        Connect-BootEntryRowInteractions -RowControls $controls -Handlers $handlers
        [void](Set-PopupBootRowDpiLayout -Row $row -Scale $factor -Y 0)
        Assert-Lbs215 "$dpi DPI controls keep original grip/eye/pencil identities and hit sizes" (
            $grip -is [Windows.Forms.Panel] -and $eye -is [Windows.Forms.Panel] -and
            $pencil -is [Windows.Forms.Label] -and
            $grip.Width -eq [int][Math]::Round(26*$factor))
        [void]$click.Invoke($grip,@([EventArgs]::Empty))
        Assert-Lbs215 "$dpi DPI grip click is a visibility no-op" (
            $script:VisibilityCalls -eq 0 -and -not $script:Hidden -and $script:RefreshCalls -eq 0)
        [void]$click.Invoke($eye,@([EventArgs]::Empty))
        Assert-Lbs215 "$dpi DPI eye click still toggles hidden state" ($script:VisibilityCalls -eq 1 -and $script:Hidden)
        [void]$click.Invoke($row,@([EventArgs]::Empty))
        Assert-Lbs215 "$dpi DPI row click still toggles hidden state" ($script:VisibilityCalls -eq 2 -and -not $script:Hidden)
        [void]$click.Invoke($children[0],@([EventArgs]::Empty))
        Assert-Lbs215 "$dpi DPI row child click still toggles" ($script:VisibilityCalls -eq 3 -and $script:Hidden)
        $x=[int][Math]::Round(13*$factor); $y=[int][Math]::Round(17*$factor)
        $args=[Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,$x,$y,0)
        [void]$down.Invoke($grip,@($args))
        Assert-Lbs215 "$dpi DPI grip MouseDown still starts drag admission" (
            $script:ManageDragGuid -eq $guid -and $script:ManageDragStartX -eq $x -and $script:ManageDragStartY -eq $y)
        $args=[Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,$x+2,$y+2,0)
        [void]$move.Invoke($grip,@($args))
        Assert-Lbs215 "$dpi DPI below-threshold drag move does not hide" (
            $script:ManageDragGuid -eq $guid -and $null -eq $script:ManageActiveDragGuid -and $script:VisibilityCalls -eq 3)
        [void]$click.Invoke($pencil,@([EventArgs]::Empty))
        Assert-Lbs215 "$dpi DPI pencil still opens its own alias editor without hiding" (
            $script:ManageAliasEditGuid -eq $guid -and $script:VisibilityCalls -eq 3)
        Assert-Lbs215 "$dpi DPI no settings writes or firmware-selection calls" (
            $script:SettingsWrites -eq 0 -and $script:BootSelectCalls -eq 0)
        $script:IsManageEntriesMode=$false
        [void]$click.Invoke($row,@([EventArgs]::Empty))
        $expected=1
        Assert-Lbs215 "$dpi DPI normal row click still uses existing boot selection gate" (
            $script:BootSelectCalls -eq $expected -and $script:VisibilityCalls -eq 3)
    }
    finally { $script:Popup.Dispose(); $script:Popup=$null }
}
Assert-Lbs215 'Isolated checks never write persistent settings' ($script:SettingsWrites -eq 0)
Write-Host "LBS215 GRIP CLICK TOTAL $script:checks/23"
if ($script:checks -ne 23) { throw "Expected 23 isolated native assertions, got $script:checks" }
