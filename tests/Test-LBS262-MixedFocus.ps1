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
    if (-not $Pass) {throw "LBS262 FAIL: $Name"}
    $script:checks++
    Write-Host "PASS LBS262 $Name"
}
function Get-LocalizedString {param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values}
function Get-CurrentSystemFunctionsCapabilities { [pscustomobject]@{State='Ready';CanManageEntries=$true;CanSetBootNext=$true;CanSetDefaultTarget=$true} }
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
foreach ($locale in @('de-DE','en-US')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $script:saveCalls=0
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
            $first=Get-Row 'boot-0'
            $second=Get-Row 'boot-1'
            $hint=$form.Controls.Find('ManageKeyboardHint',$true)[0]
            $bar=$form.Controls.Find('EntryScroll',$true)[0]
            $list=$form.Controls.Find('EntryList',$true)[0]
            $undo=$form.Controls.Find('ManageUndoButton',$true)[0]
            $save=$form.Controls.Find('ManageSaveButton',$true)[0]
            $cancel=$form.Controls.Find('ManageCancelButton',$true)[0]
            $row2=Get-Row 'boot-1'
            $row6=Get-Row 'boot-5'
            [void]$row2.Focus()
            Check "$locale/$scale baseline keyboard focus row 2" $row2.Focused
            $eye=$row6.Controls['VisibilityGlyph']
            $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
            $mouse=[Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,5,5,0)
            [void]$eye.GetType().GetMethod('OnMouseDown',$flags).Invoke($eye,[object[]]@($mouse))
            [void]$eye.GetType().GetMethod('OnMouseUp',$flags).Invoke($eye,[object[]]@($mouse))
            [void]$eye.GetType().GetMethod('OnClick',$flags).Invoke($eye,[object[]]@([EventArgs]::Empty))
            [Windows.Forms.Application]::DoEvents()
            Check "$locale/$scale eye toggles row 6 only" ((Test-ManageEntryHidden 'boot-5') -and (Test-ManageEntryHidden 'boot-1') -and $script:ManageUndoHistory.Count -eq 1)
            $actual=@($form.Controls.Find('BootRow',$true) | Where-Object Focused)
            Write-Host "LBS262 native pointer focus actual=$($actual.Tag) expected=boot-5"
            Check "$locale/$scale pointer cue absent after keyed visibility rebuild" ($actual.Count -eq 1 -and -not $actual[0].KeyboardCueVisible -and -not (Test-RowCuePaint $actual[0]))
            if ($actual.Count -eq 1) { Press-Key $actual[0] $ctrlUp }
            $expected='boot-0,boot-1,boot-2,boot-3,boot-5,boot-4,boot-6,boot-7,boot-8,boot-9'
            Check "$locale/$scale mixed-input Ctrl Up moves clicked GUID" ((Test-RowOrder $expected) -and (Get-Row 'boot-5').Focused -and $script:ManageUndoHistory.Count -eq 2)
            $clicked=Get-Row 'boot-5'
            Check "$locale/$scale keyboard cue restored and painted" ($clicked.KeyboardCueVisible -and (Test-RowCuePaint $clicked))
            Check "$locale/$scale exactly one Manage tab anchor" (@($form.Controls.Find('BootRow',$true) | Where-Object TabStop).Count -eq 1 -and $clicked.TabStop)
            Press-Tab $clicked
            Check "$locale/$scale Tab exits to enabled Undo" ($undo.Focused)
            Press-Tab $undo -Reverse
            Check "$locale/$scale reverse Tab restores clicked GUID" ((Get-Row 'boot-5').Focused -and (Get-Row 'boot-5').KeyboardCueVisible)
            $undo.PerformClick();$undo.PerformClick()
            Check "$locale/$scale mixed pointer and keyboard Undo baseline" ((Test-RowOrder $originalOrder) -and -not (Test-ManageEntryHidden 'boot-5') -and $script:ManageUndoHistory.Count -eq 0)
            $first=Get-Row 'boot-0';[void]$first.Focus()
            Press-Tab $first
            Check "$locale/$scale Tab skips disabled Undo" ($cancel.Focused)
            Press-Tab $cancel -Reverse
            Check "$locale/$scale reverse Tab from Cancel restores first row" ($first.Focused)
            $step=[int][Math]::Floor([double]$bar.LargeChange / [double]$bar.SmallChange)
            Check "$locale/$scale page step multiple existing wheel units" ($step -gt 1 -and (Get-ManageKeyboardPageStep -Row $first) -eq $step)
            $pageDown=[Windows.Forms.Keys]::PageDown
            $pageUp=[Windows.Forms.Keys]::PageUp
            $ctrlPageDown=[Windows.Forms.Keys]::Control -bor $pageDown
            $ctrlPageUp=[Windows.Forms.Keys]::Control -bor $pageUp
            $ctrlHome=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home
            $ctrlEnd=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End
            Press-Key $first $pageDown
            $pageRow=Get-Row ("boot-"+[Math]::Min(9,$step))
            Check "$locale/$scale PageDown navigation scrolls without draft" ($pageRow.Focused -and $bar.Value -gt 0 -and (Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0)
            Press-Key $pageRow $pageUp
            Check "$locale/$scale PageUp navigation returns without draft" ($first.Focused -and $bar.Value -eq 0 -and $script:ManageUndoHistory.Count -eq 0)
            $hidden=Get-Row 'boot-1';[void]$hidden.Focus()
            Press-Key $hidden $ctrlPageDown
            $idx=[Math]::Min(9,1+$step)
            Check "$locale/$scale Ctrl PageDown moves hidden GUID one atomic step" ($script:ManageEntryOrder[$idx] -eq 'boot-1' -and (Get-Row 'boot-1').Focused -and (Test-ManageEntryHidden 'boot-1') -and $script:ManageUndoHistory.Count -eq 1 -and $bar.Value -gt 0)
            Press-Key (Get-Row 'boot-1') $ctrlPageUp
            Check "$locale/$scale Ctrl PageUp reverses step in one operation" ($script:ManageEntryOrder[1] -eq 'boot-1' -and (Get-Row 'boot-1').Focused -and $script:ManageUndoHistory.Count -eq 2)
            Press-Key (Get-Row 'boot-1') $ctrlEnd
            Check "$locale/$scale Ctrl End moves to last with reveal" ($script:ManageEntryOrder[-1] -eq 'boot-1' -and (Get-Row 'boot-1').Focused -and (Get-Row 'boot-1').Bottom -le $bar.Value+$list.ClientSize.Height -and $script:ManageUndoHistory.Count -eq 3)
            Press-Key (Get-Row 'boot-1') $ctrlPageDown
            Press-Key (Get-Row 'boot-1') $ctrlEnd
            Check "$locale/$scale upper index boundary produces no history" ($script:ManageEntryOrder[-1] -eq 'boot-1' -and $script:ManageUndoHistory.Count -eq 3)
            Press-Key (Get-Row 'boot-1') $ctrlHome
            Check "$locale/$scale Ctrl Home moves to first with reveal" ($script:ManageEntryOrder[0] -eq 'boot-1' -and (Get-Row 'boot-1').Focused -and $bar.Value -eq 0 -and $script:ManageUndoHistory.Count -eq 4)
            Press-Key (Get-Row 'boot-1') $ctrlPageUp
            Press-Key (Get-Row 'boot-1') $ctrlHome
            Check "$locale/$scale lower index boundary produces no history" ($script:ManageEntryOrder[0] -eq 'boot-1' -and $script:ManageUndoHistory.Count -eq 4)
            1..4 | ForEach-Object {$undo.PerformClick()}
            Check "$locale/$scale Undo atomic page and endpoint moves" ((Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0 -and $script:saveCalls -eq 0)
            $first=Get-Row 'boot-0';[void]$first.Focus()
            $hover=Get-Row 'boot-4'
            [void]$hover.GetType().GetMethod('OnMouseEnter',$flags).Invoke($hover,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale hover never steals focus" ($first.Focused)
            Press-Key $first $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0]
            Check "$locale/$scale native alias editor keeps focus" ($editor.Focused -and -not $undo.Enabled)
            Press-Key $editor $ctrlPageDown
            Check "$locale/$scale alias input does not reorder" ($editor.Focused -and (Test-RowOrder $originalOrder) -and $script:ManageUndoHistory.Count -eq 0)
            Press-Key $editor ([Windows.Forms.Keys]::Escape)
            Check "$locale/$scale editor Escape restores row keyboard cue" ((Get-Row 'boot-0').Focused -and (Get-Row 'boot-0').KeyboardCueVisible)
            # Native handled-wheel routing must not advance again on parent delivery.
            $wheel=[Windows.Forms.HandledMouseEventArgs]::new([Windows.Forms.MouseButtons]::None,0,0,0,-120)
            Invoke-BootEntryWheelScroll -ListPanel $list -EventArgs $wheel
            $once=$bar.Value
            Invoke-BootEntryWheelScroll -ListPanel $list -EventArgs $wheel
            Check "$locale/$scale wheel uses one row and is handled once" ($wheel.Handled -and $once -eq [Math]::Min($bar.Maximum,$bar.SmallChange) -and $bar.Value -eq $once -and (Get-Row 'boot-0').Focused)
            $cancel.PerformClick()
            Check "$locale/$scale final cancel preserves persisted baseline" (-not $script:IsManageEntriesMode -and ($script:EntryOrder -join ',') -eq $originalOrder -and $script:saveCalls -eq 0)
            Check "$locale/$scale Manage focus never dispatches boot or configuration" ($script:bootCalls -eq 0 -and $script:configurationCalls -eq 0 -and $script:defaultCalls -eq 0)
            $normalFirst=Get-Row 'boot-0';[void]$normalFirst.Focus()
            [void]$list.GetType().GetMethod('OnMouseEnter',$flags).Invoke($list,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale normal list hover preserves focus" ($normalFirst.Focused)
            $normalTarget=Get-Row 'boot-5';$title=$normalTarget.Controls['BootTitleLabel']
            [void]$title.GetType().GetMethod('OnMouseDown',$flags).Invoke($title,[object[]]@($mouse))
            Check "$locale/$scale normal pointer focus is silent and cue-free" ($normalTarget.Focused -and -not $normalTarget.KeyboardCueVisible -and -not (Test-RowCuePaint $normalTarget) -and $script:bootCalls -eq 0)
            [void]$title.GetType().GetMethod('OnClick',$flags).Invoke($title,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale normal Click alone dispatches once" ($script:bootCalls -eq 1 -and $script:bootGuid -eq 'boot-5')
            $script:SelectedGuid='boot-5';Update-PopupRows -Reason 'selection-refresh'
            $normalTarget=Get-Row 'boot-5'
            Check "$locale/$scale normal rebuild retains silent target" ($normalTarget.Focused -and -not $normalTarget.KeyboardCueVisible -and -not (Test-RowCuePaint $normalTarget))
            Press-Key $normalTarget ([Windows.Forms.Keys]::Down)
            Check "$locale/$scale normal keyboard navigation reveals next cue without dispatch" ((Get-Row 'boot-6').Focused -and (Get-Row 'boot-6').KeyboardCueVisible -and $script:bootCalls -eq 1)
            $settings=$panel.Controls['SettingsPanel']
            $settingsLabel=$settings.Controls['MoreSettingsButton']
            [void]$settingsLabel.GetType().GetMethod('OnMouseDown',$flags).Invoke($settingsLabel,[object[]]@($mouse))
            Check "$locale/$scale configuration row pointer owns silent native focus" ($settings.Focused -and -not $settings.KeyboardCueVisible -and -not (Test-RowCuePaint $settings) -and $script:configurationCalls -eq 0)
            [void]$settingsLabel.GetType().GetMethod('OnClick',$flags).Invoke($settingsLabel,[object[]]@([EventArgs]::Empty))
            Check "$locale/$scale configuration click alone delegates to existing owner" ($script:configurationCalls -eq 1 -and [object]::ReferenceEquals($script:configurationOwner,$settings))
            Press-Key $settings ([Windows.Forms.Keys]::Enter)
            Check "$locale/$scale configuration keyboard cue returns and dispatches exactly once" ($settings.Focused -and $settings.KeyboardCueVisible -and $script:configurationCalls -eq 2)
            $script:CurrentEntries=@($script:CurrentEntries | Select-Object -First 2)
            Update-PopupRows -Reason 'short-inventory'
            Start-ManageEntriesMode
            $shortFirst=Get-Row 'boot-0';[void]$shortFirst.Focus()
            Press-Key $shortFirst $ctrlPageDown
            Check "$locale/$scale short list page reorder clamps to last" ($script:ManageEntryOrder[-1] -eq 'boot-0' -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 1 -and -not $bar.Visible)
            Press-Key (Get-Row 'boot-0') $ctrlPageDown
            Check "$locale/$scale short list boundary no-op" ($script:ManageUndoHistory.Count -eq 1)
            Press-Key (Get-Row 'boot-0') $ctrlPageUp
            Check "$locale/$scale short list page reorder clamps to first" ($script:ManageEntryOrder[0] -eq 'boot-0' -and $script:ManageUndoHistory.Count -eq 2)
            $cancel.PerformClick()


        } finally {$form.Dispose();$script:Popup=$null}
    }
}
Write-Host "LBS262 MIXED FOCUS TOTAL $script:checks/156"
if ($script:checks -ne 156) { throw "LBS262 test total mismatch $script:checks" }
