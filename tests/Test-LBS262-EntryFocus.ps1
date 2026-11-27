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
foreach ($rel in @('src\Core\EntryPreferences.ps1','src\Core\Localization.ps1','src\Core\BootNextSelectionState.ps1','src\UI\BootEntryList.ps1','src\UI\BootEntryRows.ps1','src\UI\PopupDpiLayout.ps1','src\UI\PopupComposition.ps1','src\UI\ManageEntriesState.ps1','src\UI\ManageEntries.ps1','src\UI\MenuAppearance.ps1','src\UI\MaintenancePresentation.ps1','src\UI\Popup.ps1')) {. (Join-Path $root $rel)}
$script:checks=0
function Check([string]$Name,[bool]$Pass) {
    if (-not $Pass) {throw "LBS262Entry FAIL: $Name"}
    $script:checks++
    Write-Host "PASS LBS262Entry $Name"
}
function Get-LocalizedString {param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values}
function Get-CurrentSystemFunctionsCapabilities { [pscustomobject]@{State='Ready';CanManageEntries=$script:manageAllowed;CanSetBootNext=$true;CanSetDefaultTarget=$true} }
function Get-LenovoUiCoordinateScale {param($Screen) return [pscustomobject]@{Factor=$script:FixtureScale}}
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
$script:AppVersion='1.8.0.0'
$script:BootTypeToolTip=$null
$ctrlUp=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Up
$ctrlDown=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Down
$ctrlE=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::E
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs262EntryNative {
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
}
'@
# Use the actual native mouse-up path when the synthetic layout is on-screen.
# Offscreen synthetic 250% controls still exercise the real Click handler.
function Invoke-EntryPointerAction($Control) {
    $p=[Drawing.Point]::new([int]($Control.Width/2),[int]($Control.Height/2))
    $screenPoint=$Control.PointToScreen($p)
    if (-not [Windows.Forms.SystemInformation]::VirtualScreen.Contains($screenPoint) -or
        -not $script:Popup.RectangleToScreen($script:Popup.ClientRectangle).Contains($screenPoint)) {
        Write-Host "LBS279 clipped fixture action: $($Control.Name) PerformClick"
        $Control.PerformClick()
        return
    }
    [void]$Control.Focus()
    [Windows.Forms.Cursor]::Position=$screenPoint
    [Windows.Forms.Application]::DoEvents()
    $lp=[IntPtr](($p.Y -shl 16) -bor $p.X)
    [void][Lbs262EntryNative]::SendMessage($Control.Handle,0x201,[IntPtr]1,$lp)
    [void][Lbs262EntryNative]::SendMessage($Control.Handle,0x202,[IntPtr]0,$lp)
    [Windows.Forms.Application]::DoEvents()
    Write-Host "LBS279 native mouse action: $($Control.Name)"
}
foreach ($locale in @('de-DE','en-US')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $script:FixtureScale=$scale
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
        # LBS-279 corrective coverage: actual production constructor including
        # its TopMost, Deactivate/Hide, tooltip, settings and footer ownership.
        $form=New-PopupForm -TargetScale $scale -ScaleSource 'native-fixture'
        $savedCursor=[Windows.Forms.Cursor]::Position
        try {
            $script:Popup=$form
            $form.Location=[Drawing.Point]::new(5,5)
            $form.Show()
            [Windows.Forms.Application]::DoEvents()
            $form.Activate()
            Update-PopupRows -Reason 'initial-fixture'
            [Windows.Forms.Application]::DoEvents()
            $script:ownerDeactivateEvents=0; $script:ownerHiddenEvents=0; $script:ownerCoverSeen=0; $script:ownerCoverInvalid=0
            $form.Add_Deactivate({ $script:ownerDeactivateEvents++; Write-Host "LBS279 OWNER DEACTIVATE foreground=$([Lbs262EntryNative]::GetForegroundWindow()) visible=$($this.Visible)" })
            $form.Add_VisibleChanged({ if (-not $this.Visible) { $script:ownerHiddenEvents++; Write-Host 'LBS279 OWNER HIDDEN' } })
            $form.Add_ControlAdded({
                param($sender,$eventArgs)
                if ($eventArgs.Control.Name -ne 'LenovoPopupVisualCommit') { return }
                $eventArgs.Control.Add_VisibleChanged({
                    param($sender,$eventArgs)
                    if (-not $sender.Visible) { return }
                    $script:ownerCoverSeen++
                    if ($sender.CanSelect -or $sender.ContainsFocus -or $sender.Parent -ne $script:Popup -or
                        [Lbs262EntryNative]::GetAncestor($sender.Handle,2) -ne $script:Popup.Handle -or
                        [Lbs262EntryNative]::GetForegroundWindow() -ne $script:Popup.Handle -or
                        $script:Popup.OwnedForms.Count -ne 0) { $script:ownerCoverInvalid++ }
                })
            })
            $button=$form.Controls.Find('ManageEntriesButton',$true)[0]
            $cancel=$form.Controls.Find('ManageCancelButton',$true)[0]
            $undo=$form.Controls.Find('ManageUndoButton',$true)[0]
            $savedCursor=[Windows.Forms.Cursor]::Position
            $button.Focus() | Out-Null
            $p=[Drawing.Point]::new([int]($button.Width/2),[int]($button.Height/2))
            [Windows.Forms.Cursor]::Position=$button.PointToScreen($p)
            [Windows.Forms.Application]::DoEvents()
            $lp=[IntPtr](($p.Y -shl 16) -bor $p.X)
            [void][Lbs262EntryNative]::SendMessage($button.Handle,0x201,[IntPtr]1,$lp)
            [void][Lbs262EntryNative]::SendMessage($button.Handle,0x202,[IntPtr]0,$lp)
            [Windows.Forms.Application]::DoEvents()
            Check "$locale/$scale mouse Customize entered" $script:IsManageEntriesMode
            Check "$locale/$scale LBS279 production mouse Customize retains owner visibility and activation" ($form.Visible -and $form.TopMost -and $form.ContainsFocus -and $script:ownerDeactivateEvents -eq 0 -and $script:ownerHiddenEvents -eq 0 -and $script:ownerCoverSeen -gt 0 -and $script:ownerCoverInvalid -eq 0)
            $first=Get-Row 'boot-0'
            Write-Host "ENTRY FOCUS mouse focused=$($first.Focused) cue=$($first.KeyboardCueVisible)"
            Check "$locale/$scale initial mouse focus without Tab" ($first.Focused -and $first.TabStop)
            Check "$locale/$scale initial pointer cue absent" (-not $first.KeyboardCueVisible -and -not (Test-RowCuePaint $first))
            Check "$locale/$scale initial entry no draft mutation" ((Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0 -and $script:saveCalls -eq 0 -and $script:bootCalls -eq 0)
            Press-Key $first ([Windows.Forms.Keys]::Down)
            $second=Get-Row 'boot-1'
            Check "$locale/$scale immediate arrow shows next row cue" ($second.Focused -and $second.KeyboardCueVisible -and (Test-RowCuePaint $second))
            Press-Tab $second
            Check "$locale/$scale Tab exits to Cancel" $cancel.Focused
            Update-PopupRows -Reason 'refresh'
            Check "$locale/$scale refresh preserves action focus" $cancel.Focused
            Press-Tab $cancel -Reverse
            Check "$locale/$scale reverse Tab restores second row" ((Get-Row 'boot-1').Focused)
            Invoke-EntryPointerAction $cancel
            [Windows.Forms.Application]::DoEvents()
            Check "$locale/$scale LBS279 production Cancel retains owner visibility" ($form.Visible -and -not $script:IsManageEntriesMode -and $script:ownerDeactivateEvents -eq 0 -and $script:ownerHiddenEvents -eq 0 -and -not $form.Controls['LenovoPopupVisualCommit'])
            [Windows.Forms.Cursor]::Position=$form.PointToScreen([Drawing.Point]::new(5,5))
            [void]$button.Focus()
            [Windows.Forms.SendKeys]::SendWait(' ')
            [Windows.Forms.Application]::DoEvents()
            $first=Get-Row 'boot-0'
            Check "$locale/$scale keyboard Customize initial visible cue" ($script:IsManageEntriesMode -and $first.Focused -and $first.KeyboardCueVisible -and (Test-RowCuePaint $first))
            Press-Key $first $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0]
            Update-PopupRows -Reason 'refresh'
            Check "$locale/$scale refresh preserves alias editor" ($editor.Focused -and $script:ManageAliasEditGuid -eq 'boot-0')
            Press-Key $editor ([Windows.Forms.Keys]::Escape)
            $cancel.PerformClick()
            $beforeSave=$script:saveCalls
            $button.PerformClick()
            $row=Get-Row 'boot-0'
            [void]$row.Focus()
            Press-Key $row ([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Down)
            Check "$locale/$scale LBS279 production keyboard reorder retains owner focus and draft" ($form.Visible -and $row.Focused -and $script:ManageEntryOrder[0] -eq 'boot-1' -and $script:saveCalls -eq $beforeSave -and $script:ownerHiddenEvents -eq 0)
            Invoke-EntryPointerAction ($form.Controls.Find('ManageSaveButton',$true)[0])
            [Windows.Forms.Application]::DoEvents()
            Check "$locale/$scale LBS279 production Save retains owner and commits once" ($form.Visible -and -not $script:IsManageEntriesMode -and $script:saveCalls -eq ($beforeSave+1) -and $script:EntryOrder[0] -eq 'boot-1' -and $script:ownerDeactivateEvents -eq 0 -and $script:ownerHiddenEvents -eq 0)
            Check "$locale/$scale LBS279 every observed cover stays a nonselectable child" ($script:ownerCoverSeen -ge 5 -and $script:ownerCoverInvalid -eq 0 -and $form.OwnedForms.Count -eq 0 -and -not $form.Controls['LenovoPopupVisualCommit'])
            $script:manageAllowed=$false
            Update-ManageEntriesUiState
            $button.PerformClick()
            Check "$locale/$scale unavailable Customize blocked" (-not $script:IsManageEntriesMode -and -not $button.Enabled)
            $script:manageAllowed=$true
            # The preceding Save intentionally increments the fixture counter.
            # Empty inventory must not add another persistence or boot dispatch.
            $emptyBaselineSaveCalls=$script:saveCalls
            $emptyBaselineBootCalls=$script:bootCalls
            $script:CurrentEntries=@()
            Update-PopupRows -Reason 'empty-fixture'
            Update-ManageEntriesUiState
            Start-ManageEntriesMode
            Check "$locale/$scale empty entry has no row or mutation" ($script:IsManageEntriesMode -and $form.Visible -and @(Get-Row 'boot-0').Count -eq 0 -and $script:ManageUndoHistory.Count -eq 0 -and $script:saveCalls -eq $emptyBaselineSaveCalls -and $script:bootCalls -eq $emptyBaselineBootCalls -and $script:ownerHiddenEvents -eq 0)
            $cancel.PerformClick()
            # An unrelated foreground window must still invoke production dismissal.
            $outside=[Windows.Forms.Form]::new()
            try {
                $outside.StartPosition=[Windows.Forms.FormStartPosition]::Manual
                $outside.Location=[Drawing.Point]::new(20,20)
                $outside.Size=[Drawing.Size]::new(160,120)
                $outside.TopMost=$true
                $outside.Show()
                $outside.Activate()
                [Windows.Forms.Application]::DoEvents()
                Check "$locale/$scale LBS279 external activation still dismisses the actual popup" (-not $form.Visible -and $script:ownerDeactivateEvents -ge 1 -and $script:ownerHiddenEvents -ge 1 -and [Lbs262EntryNative]::GetForegroundWindow() -eq $outside.Handle)
            } finally { $outside.Dispose() }
        } finally {
            if ($savedCursor) { [Windows.Forms.Cursor]::Position=$savedCursor }
            $form.Dispose();$script:Popup=$null
        }
    }
}
Write-Host "LBS262 ENTRY FOCUS TOTAL $script:checks/72"
if ($script:checks -ne 72) {throw "Unexpected LBS262 Entry Focus count $script:checks"}
