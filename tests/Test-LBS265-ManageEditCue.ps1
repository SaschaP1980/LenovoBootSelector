#requires -version 5.1
# LBS-262: actual WinForms pointer/keyboard focus regression; no real writes.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$template=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix='Add-Type -TypeDefinition @"'
$begin=$template.IndexOf($prefix,[StringComparison]::Ordinal)+$prefix.Length
$end=$template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($begin -lt $prefix.Length -or $end -lt $begin) {throw 'Missing canonical WinForms types'}
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
foreach ($rel in @('src\Core\EntryPreferences.ps1','src\Core\Localization.ps1','src\Core\BootNextSelectionState.ps1','src\UI\BootEntryList.ps1','src\UI\BootEntryRows.ps1','src\UI\PopupDpiLayout.ps1','src\UI\PopupComposition.ps1','src\UI\ManageEntriesState.ps1','src\UI\ManageEntries.ps1')) {. (Join-Path $root $rel)}
$script:checks=0
function Check([string]$Name,[bool]$Pass) {
    if (-not $Pass) {throw "LBS265 FAIL: $Name"}
    $script:checks++
    Write-Host "PASS LBS265 $Name"
}
function Get-LocalizedString {param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values}
function Get-CurrentSystemFunctionsCapabilities { [pscustomobject]@{State='Ready';CanManageEntries=$script:manageAllowed;CanSetBootNext=$true;CanSetDefaultTarget=$true} }
function Test-MaintenanceBusy { return $false }
function Test-BootTargetDriftDetected { return $false }
function Show-ConfigurationPopup {param($Owner) $script:configurationCalls++;$script:configurationOwner=$Owner}
function Show-DefaultTargetMenu {param($Owner) $script:defaultCalls++}
function Get-EntryAlias {param([string]$Guid,[switch]$UseManageDraft)
    $map=if ($UseManageDraft) {$script:ManageEntryAliases} else {$script:EntryAliases}
    if ($map -and $map.ContainsKey($Guid)) {return [string]$map[$Guid]}
    return ''
}
function Get-EntryDisplayTitle {param($Entry,[switch]$UseManageDraft)
    $alias=Get-EntryAlias -Guid ([string]$Entry.Guid) -UseManageDraft:$UseManageDraft
    if ($alias) {return $alias}
    return [string]$Entry.Title
}
function Update-DefaultUi {}
function Update-RestartTargetUi {}
function Update-MaintenanceUi {}
function Update-RefreshButtonVisual {}
function Save-AppSettings {$script:saveCalls++}
function Start-BootNextSelection {param([string]$Guid) $script:bootCalls++;$script:bootGuid=$Guid}
function Get-EntryByGuid {param([string]$Guid) $script:CurrentEntries | Where-Object Guid -eq $Guid | Select-Object -First 1}
function Get-Row([string]$Guid) {
    $script:Popup.Controls.Find('BootRow',$true) | Where-Object { [string]$_.Tag -eq $Guid } | Select-Object -First 1
}
function Dispatch-Key($Control,[Windows.Forms.Keys]$Key,[string]$Phase) {
    $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
    $method=$Control.GetType().GetMethod("OnKey$Phase",$flags)
    $event=[Windows.Forms.KeyEventArgs]::new($Key)
    [void]$method.Invoke($Control,[object[]]@($event))
    [Windows.Forms.Application]::DoEvents()
}
function Press-Key($Control,[Windows.Forms.Keys]$Key) {
    Dispatch-Key $Control $Key Down
    if (-not $Control.IsDisposed) {Dispatch-Key $Control $Key Up}
}
function Test-RowCuePaint($Row) {
    $bmp=[Drawing.Bitmap]::new($Row.Width,$Row.Height)
    $g=[Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear($Row.BackColor)
        $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        $paint=$Row.GetType().GetMethod('OnPaint',$flags)
        [void]$paint.Invoke($Row,[object[]]@([Windows.Forms.PaintEventArgs]::new($g,$Row.ClientRectangle)))
        $pixel=$bmp.GetPixel(3,[int]($Row.Height/2))
        return ($pixel.ToArgb() -ne $Row.BackColor.ToArgb())
    } finally {$g.Dispose();$bmp.Dispose()}
}
function Press-Tab($Control,[switch]$Reverse) {
    $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
    $key=[Windows.Forms.Keys]::Tab
    if ($Reverse) {$key=$key -bor [Windows.Forms.Keys]::Shift}
    [void]$Control.GetType().GetMethod('ProcessDialogKey',$flags).Invoke($Control,[object[]]@($key))
    [Windows.Forms.Application]::DoEvents()
}
function Test-RowOrder([string]$Expected) {
    $rendered=@($script:Popup.Controls.Find('BootRow',$true) | Sort-Object Top)
    return (($rendered.Tag -join ',') -ceq $Expected -and ($script:ManageEntryOrder -join ',') -ceq $Expected)
}
function Get-ArrowPaint($Row) {
    $bmp=[Drawing.Bitmap]::new($Row.Width,$Row.Height)
    $g=[Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear($Row.BackColor)
        $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        [void]$Row.GetType().GetMethod('OnPaint',$flags).Invoke($Row,[object[]]@([Windows.Forms.PaintEventArgs]::new($g,$Row.ClientRectangle)))
        $cx=[int]($Row.Width/2)
        $up=$false;$down=$false
        for ($x=$cx-2;$x -le $cx+2;$x++) {
            $top=$bmp.GetPixel($x,1)
            if ($top.R -ge 175 -and $top.G -ge 190 -and $top.B -ge 205) {$up=$true}
            $bottom=$bmp.GetPixel($x,$Row.Height-2)
            if ($bottom.R -ge 175 -and $bottom.G -ge 190 -and $bottom.B -ge 205) {$down=$true}
        }
        return [pscustomobject]@{Up=$up;Down=$down}
    } finally {$g.Dispose();$bmp.Dispose()}
}
function Test-Cue($Row,[bool]$Up,[bool]$Down) {
    $paint=Get-ArrowPaint $Row
    return ($Row.Focused -and $Row.ManageEditCueActive -and $Row.ManageMoveUp -eq $Up -and $Row.ManageMoveDown -eq $Down -and $paint.Up -eq $Up -and $paint.Down -eq $Down)
}
function Test-IdleCue($Row) {
    $paint=Get-ArrowPaint $Row
    return (-not $Row.ManageEditCueActive -and -not $Row.ManageMoveUp -and -not $Row.ManageMoveDown -and -not $paint.Up -and -not $paint.Down)
}
# Distinguish the existing neutral drag frame (155/155/155) from the
# keyboard outline (181/196/212); do not count another renderer's border.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs265Native {
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@
$script:ColorRow=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorHeader=[Drawing.Color]::FromArgb(24,24,24)
$script:ColorSurface=[Drawing.Color]::FromArgb(32,32,32)
$script:ColorBackground=[Drawing.Color]::FromArgb(29,29,29)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::FromArgb(175,175,175)
$script:ColorAccent=[Drawing.Color]::Red
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(64,31,29)
$script:ColorHover=[Drawing.Color]::FromArgb(42,42,42)
$script:ColorWarning=[Drawing.Color]::Orange
$script:AppVersion='1.9.1.0'
$script:BootTypeToolTip=$null
$ctrlUp=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Up
$ctrlDown=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Down
$ctrlE=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::E
foreach ($locale in @('de-DE','en-US')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $script:saveCalls=0;$script:manageAllowed=$true
        $script:bootCalls=0;$script:configurationCalls=0;$script:defaultCalls=0
        $script:SelectedGuid='';$script:BootNextPendingGuid='';$script:DefaultInteractionEnabled=$true
        $script:IsManageEntriesMode=$false
        $script:ManageUndoHistory=$null
        $script:ManageLastDragUtc=[datetime]::MinValue
        $script:EntryOrder=@(0..9 | ForEach-Object {"boot-$_"})
        $originalOrder=$script:EntryOrder -join ','
        $script:HiddenEntryGuids=@('boot-1')
        $script:EntryAliases=@{}
        $script:CurrentEntries=@(0..9 | ForEach-Object {
            [pscustomobject]@{Guid="boot-$_";Title="Target $_";Subtitle="Description $_";RawDescription="Target $_";Symbol='*';Accent=[Drawing.Color]::Red;TypeTooltip=''}
        })
        $form=[Windows.Forms.Form]::new()
        try {
            $script:Popup=$form
            $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
            $form.Location=[Drawing.Point]::new(5,5)
            $form.ClientSize=[Drawing.Size]::new(390,672)
            Initialize-PopupDpiLayout -Form $form
            $panel=[Windows.Forms.Panel]::new();$panel.Name='PopupRoot';$panel.Size=$form.ClientSize
            $form.Controls.Add($panel)
            Add-PopupHeaderSection -Root $panel
            Add-PopupBootEntryListSection -Root $panel
            Add-PopupSettingsSection -Root $panel
            Add-PopupManageEntriesSection -Root $panel
            Complete-PopupDpiLayout -Form $form -Scale $scale
            $form.Show()
            [Windows.Forms.Application]::DoEvents()
            Start-ManageEntriesMode
            $first=Get-Row 'boot-0';$second=Get-Row 'boot-1'
            $cancel=$form.Controls.Find('ManageCancelButton',$true)[0]
            $undo=$form.Controls.Find('ManageUndoButton',$true)[0]
            $ctrl=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::ControlKey
            $release=[Windows.Forms.Keys]::ControlKey
            $ctrlEnd=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End
            $ctrlHome=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home
            $gripIdle=[Drawing.Color]::FromArgb(145,145,145)
            $gripHover=[Drawing.Color]::FromArgb(220,220,220)
            $penIdle=[Drawing.Color]::FromArgb(190,190,190)
            $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
            $bounds=$first.Bounds
            Check "$locale/$scale initial ordinary focus" ($first.Focused -and (Test-IdleCue $first) -and $first.KeyboardCueVisible)
            [void][Lbs265Native]::SendMessage($first.Handle,0x100,[IntPtr]0x11,[IntPtr]1)
            [Windows.Forms.Application]::DoEvents()
            $grip=$first.Controls['ManageReorderGrip'];$pencil=$first.Controls['AliasEditButton']
            Check "$locale/$scale first only down arrow painted" (Test-Cue $first $false $true)
            Check "$locale/$scale existing hover inks without background or geometry" ($grip.ForeColor -eq $gripHover -and $pencil.ForeColor -eq $script:ColorAccent -and $grip.BackColor -eq [Drawing.Color]::Transparent -and $first.Bounds -eq $bounds -and -not $grip.ManagePointerHovered -and -not $pencil.ManagePointerHovered)
            Check "$locale/$scale Ctrl alone leaves order and history unchanged" ((Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0 -and $script:saveCalls -eq 0 -and $script:bootCalls -eq 0 -and (Test-IdleCue $second))
            Dispatch-Key $first $ctrlDown Down
            $moved=Get-Row 'boot-0'
            Check "$locale/$scale middle both arrows and one atomic move" ((Test-Cue $moved $true $true) -and $script:ManageEntryOrder[1] -eq 'boot-0' -and $script:ManageUndoHistory.Count -eq 1)
            Dispatch-Key $moved $ctrlEnd Down
            $moved=Get-Row 'boot-0'
            Check "$locale/$scale last only up arrow and stable GUID" ((Test-Cue $moved $true $false) -and $script:ManageEntryOrder[-1] -eq 'boot-0' -and $script:ManageUndoHistory.Count -eq 2)
            Dispatch-Key $moved $ctrlHome Down
            $moved=Get-Row 'boot-0'
            Check "$locale/$scale first direction updates after endpoint move" ((Test-Cue $moved $false $true) -and $script:ManageEntryOrder[0] -eq 'boot-0' -and $script:ManageUndoHistory.Count -eq 3)
            Dispatch-Key $moved $ctrlUp Down
            Check "$locale/$scale boundary no-op retains cue and history" ((Test-Cue $moved $false $true) -and $script:ManageUndoHistory.Count -eq 3)
            $grip=$moved.Controls['ManageReorderGrip'];$pencil=$moved.Controls['AliasEditButton']
            [void]$grip.GetType().GetMethod('OnMouseEnter',$flags).Invoke($grip,[object[]]@([EventArgs]::Empty))
            [void][Lbs265Native]::SendMessage($moved.Handle,0x101,[IntPtr]0x11,[IntPtr]::Zero)
            [Windows.Forms.Application]::DoEvents()
            Check "$locale/$scale release preserves real grip hover only" ((Test-IdleCue $moved) -and $grip.ForeColor -eq $gripHover -and $pencil.ForeColor -eq $penIdle -and $moved.KeyboardCueVisible)
            [void]$grip.GetType().GetMethod('OnMouseLeave',$flags).Invoke($grip,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale pointer leave restores idle grip" ($grip.ForeColor -eq $gripIdle)
            Dispatch-Key $moved $ctrl Down
            [void]$pencil.GetType().GetMethod('OnMouseEnter',$flags).Invoke($pencil,[object[]]@([EventArgs]::Empty))
            [void]$pencil.GetType().GetMethod('OnMouseLeave',$flags).Invoke($pencil,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale real pencil leave retains keyboard ink" ($pencil.ForeColor -eq $script:ColorAccent -and $moved.ManageEditCueActive)
            [void]$undo.Focus()
            Check "$locale/$scale focus loss clears cues and inks" ((Test-IdleCue $moved) -and $grip.ForeColor -eq $gripIdle -and $pencil.ForeColor -eq $penIdle)
            1..3 | ForEach-Object {$undo.PerformClick()}
            Check "$locale/$scale Undo restores original order" ((Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0)
            $second=Get-Row 'boot-1';[void]$second.Focus()
            Dispatch-Key $second $ctrl Down
            Check "$locale/$scale hidden middle row admits both directions" (Test-Cue $second $true $true)
            # A keyed replacement (visibility changes signature) retains the
            # same focused GUID and modifier presentation, not the old HWND.
            Invoke-ManageRowVisibility -Guid 'boot-1'
            $second=Get-Row 'boot-1'
            Check "$locale/$scale reconciliation restores focused cue" (Test-Cue $second $true $true)
            Dispatch-Key $second $ctrlE Down
            $editor=$form.Controls.Find('AliasEditor',$true)[0]
            Check "$locale/$scale alias editor receives focus without any row cues" ($editor.Focused -and @($form.Controls.Find('BootRow',$true) | Where-Object {$_.PSObject.Properties['ManageEditCueActive'] -and $_.ManageEditCueActive}).Count -eq 0)
            Press-Key $editor ([Windows.Forms.Keys]::Escape)
            $second=Get-Row 'boot-1'
            Dispatch-Key $second $ctrl Down
            $script:ManageActiveDragGuid='boot-1'
            Update-ManageKeyboardEditCue -Row $second -Active:$true
            Check "$locale/$scale drag gate clears cue" (Test-IdleCue $second)
            $script:ManageActiveDragGuid=$null
            $cancel.PerformClick()
            $script:CurrentEntries=@($script:CurrentEntries | Select-Object -First 1)
            Update-PopupRows -Reason 'single'
            Start-ManageEntriesMode
            $single=Get-Row 'boot-0';Dispatch-Key $single $ctrl Down
            $singleGrip=$single.Controls['ManageReorderGrip']
            Check "$locale/$scale single entry no arrows but hover ink" ((Test-Cue $single $false $false) -and $singleGrip.ForeColor -eq $gripHover)
            $script:manageAllowed=$false
            Update-PopupRows -Reason 'capability'
            Check "$locale/$scale unavailable row loses cue" ((Test-IdleCue $single) -and $singleGrip.ForeColor -eq $gripIdle)
            $script:manageAllowed=$true
            $cancel.PerformClick()
            $normal=Get-Row 'boot-0';[void]$normal.Focus();Dispatch-Key $normal $ctrl Down
            Check "$locale/$scale normal mode unchanged and no writes" ((Test-IdleCue $normal) -and $script:saveCalls -eq 0 -and $script:bootCalls -eq 0)
        } finally {$form.Dispose();$script:Popup=$null}
    }
}
Write-Host "LBS265 EDIT CUE TOTAL $script:checks/80"
if ($script:checks -ne 80) {throw "Unexpected LBS265 check count $script:checks"}
