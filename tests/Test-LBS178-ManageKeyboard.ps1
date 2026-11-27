#requires -version 5.1
# LBS-178: actual WinForms row controls and keyed reconciliation; no real writes.
$ErrorActionPreference='Stop'
$VerbosePreference='Continue'
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
    if (-not $Pass) {throw "LBS178 FAIL: $Name"}
    $script:checks++
    Write-Host "PASS LBS178 $Name"
}
function Get-LocalizedString {param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values}
function Get-CurrentSystemFunctionsCapabilities { [pscustomobject]@{CanManageEntries=$true;CanSetBootNext=$true} }
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
function Start-BootNextSelection {throw 'Unexpected BootNext action'}
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
function Test-RowOrder([string]$Expected) {
    $rendered=@($script:Popup.Controls.Find('BootRow',$true) | Sort-Object Top)
    return (($rendered.Tag -join ',') -ceq $Expected -and ($script:ManageEntryOrder -join ',') -ceq $Expected)
}
# LBS-279: observe the actual native cover during real control mutations,
# not a mocked transaction or test-side redraw suppression.
function Get-VisualCommitCover {
    return ($script:Popup.OwnedForms | Where-Object { $_.Name -eq 'LenovoPopupVisualCommit' -and -not $_.IsDisposed } | Select-Object -First 1)
}
function Reset-VisualCommitProbe {
    $script:visualRowEvents=0
    $script:visualFooterEvents=0
    $script:visualUncoveredEvents=0
}
function Observe-VisualCommitMutation([string]$Kind) {
    if (-not $script:visualProbeActive) { return }
    if ($Kind -eq 'row') { $script:visualRowEvents++ }
    else { $script:visualFooterEvents++ }
    $cover=Get-VisualCommitCover
    $client=$script:Popup.Controls['PopupRoot']
    $expectedBounds=[Drawing.Rectangle]::Intersect($client.RectangleToScreen($client.ClientRectangle),$script:Popup.RectangleToScreen($script:Popup.ClientRectangle))
    $expectedBounds=[Drawing.Rectangle]::Intersect($expectedBounds,[Windows.Forms.SystemInformation]::VirtualScreen)
    if (-not $cover -or -not $cover.Visible -or $cover.FramePaintCount -le 0 -or
        $cover.ContainsFocus -or [object]::ReferenceEquals([Windows.Forms.Form]::ActiveForm,$cover) -or
        -not $client.Visible -or -not $script:Popup.Visible -or
        $cover.Bounds -ne $expectedBounds) {
        if ($script:visualUncoveredEvents -eq 0) {
            Write-Host "LBS279 COVER FAILURE kind=$Kind root=$($client.RectangleToScreen($client.ClientRectangle)) owner=$($script:Popup.RectangleToScreen($script:Popup.ClientRectangle)) expected=$expectedBounds actual=$($cover.Bounds) visible=$($cover.Visible) paints=$($cover.FramePaintCount) focus=$($cover.ContainsFocus) active=$([object]::ReferenceEquals([Windows.Forms.Form]::ActiveForm,$cover)) ownerVisible=$($script:Popup.Visible) rootVisible=$($client.Visible)"
        }
        $script:visualUncoveredEvents++
    }
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
            Add-PopupManageEntriesSection -Root $panel
            Complete-PopupDpiLayout -Form $form -Scale $scale
            $form.Show()
            [Windows.Forms.Application]::DoEvents()
            $script:visualProbeActive=$false
            Update-PopupRows -Reason 'LBS279-normal-fixture'
            [Windows.Forms.Application]::DoEvents()
            $content=$form.Controls.Find('EntryContent',$true)[0]
            $managePanel=$form.Controls.Find('ManageEntriesPanel',$true)[0]
            $content.Add_ControlAdded({
                param($sender,$eventArgs)
                if ($eventArgs.Control.Name -eq 'BootRow') { Observe-VisualCommitMutation 'row' }
            })
            $managePanel.Add_VisibleChanged({ Observe-VisualCommitMutation 'footer' })
            Reset-VisualCommitProbe
            $script:visualProbeActive=$true
            try { Start-ManageEntriesMode }
            finally { $script:visualProbeActive=$false }
            Check "$locale/$scale LBS279 mode entry covers actual row additions and footer visibility" ($script:visualRowEvents -gt 0 -and $script:visualFooterEvents -gt 0 -and $script:visualUncoveredEvents -eq 0)
            Check "$locale/$scale LBS279 entry cover disposed and normal owner remains visible" (-not (Get-VisualCommitCover) -and $form.Visible -and $panel.Visible)
            $first=Get-Row 'boot-0'
            $second=Get-Row 'boot-1'
            $hint=$form.Controls.Find('ManageKeyboardHint',$true)[0]
            $bar=$form.Controls.Find('EntryScroll',$true)[0]
            $list=$form.Controls.Find('EntryList',$true)[0]
            $undo=$form.Controls.Find('ManageUndoButton',$true)[0]
            $save=$form.Controls.Find('ManageSaveButton',$true)[0]
            $cancel=$form.Controls.Find('ManageCancelButton',$true)[0]
            Check "$locale/$scale rows and hidden row focusable" ($first.Focus() -and $first.Focused -and $first.TabStop -and -not $second.TabStop -and $second.CanFocus -and $first.AccessibleRole -eq [Windows.Forms.AccessibleRole]::ListItem)
            $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
            $inputMethod=$first.GetType().GetMethod('IsInputKey',$flags)
            Check "$locale/$scale native input routing" ([bool]$inputMethod.Invoke($first,[object[]]@($ctrlE)) -and [bool]$inputMethod.Invoke($first,[object[]]@($ctrlDown)) -and [bool]$inputMethod.Invoke($first,[object[]]@([Windows.Forms.Keys]::Space)))
            Check "$locale/$scale accessible position and visible hint" ($first.AccessibleDescription.Contains((Get-LocalizedString -Key 'Manage.KeyboardPosition' -Values @{Position=1;Count=10})) -and $hint.Visible -and $hint.Text.StartsWith('1/10'))
            $bmp=[Drawing.Bitmap]::new(8,8)
            try {
                $bmp.SetResolution([single](96*$scale),[single](96*$scale))
                $g=[Drawing.Graphics]::FromImage($bmp)
                try {Check "$locale/$scale header hint fits" ($g.MeasureString($hint.Text,$hint.Font).Width -le $hint.Width -and $hint.Right -le $hint.Parent.Width)} finally {$g.Dispose()}
            } finally {$bmp.Dispose()}
            $tab=$first.GetType().GetMethod('ProcessDialogKey',$flags)
            [void]$tab.Invoke($first,[object[]]@([Windows.Forms.Keys]::Tab))
            Check "$locale/$scale native Tab exits list to Cancel when Undo disabled" ($cancel.Focused)
            $reverseTab=$cancel.GetType().GetMethod('ProcessDialogKey',$flags)
            [void]$reverseTab.Invoke($cancel,[object[]]@([Windows.Forms.Keys]::Tab -bor [Windows.Forms.Keys]::Shift))
            Check "$locale/$scale native Shift Tab returns to last focused row" ($first.Focused)
            Press-Key $first ([Windows.Forms.Keys]::Down)
            Check "$locale/$scale navigation includes hidden entry" ($second.Focused -and $script:ManageUndoHistory.Count -eq 0)
            Press-Key $second ([Windows.Forms.Keys]::End)
            $last=Get-Row 'boot-9'
            Check "$locale/$scale End scrolls to last GUID" ($last.Focused -and $bar.Value -gt 0 -and $last.Bottom -le $bar.Value+$list.ClientSize.Height)
            Press-Key $last $ctrlDown
            Check "$locale/$scale last boundary no-op" ($last.Focused -and $script:ManageUndoHistory.Count -eq 0 -and (Test-RowOrder $originalOrder))
            Press-Key $last ([Windows.Forms.Keys]::Home)
            Check "$locale/$scale Home scrolls to first" ($first.Focused -and $bar.Value -eq 0)
            Press-Key $first $ctrlUp
            Check "$locale/$scale first boundary no-op" ($first.Focused -and $script:ManageUndoHistory.Count -eq 0)
            $firstActions=@('VisibilityGlyph','AliasEditButton','ManageReorderGrip' | ForEach-Object { $first.Controls[$_] })
            $first.Add_LocationChanged({ Observe-VisualCommitMutation 'row' })
            $second.Add_LocationChanged({ Observe-VisualCommitMutation 'row' })
            $save.Add_EnabledChanged({ Observe-VisualCommitMutation 'footer' })
            $undo.Add_EnabledChanged({ Observe-VisualCommitMutation 'footer' })
            Reset-VisualCommitProbe
            $script:visualProbeActive=$true
            try { Press-Key $first $ctrlDown }
            finally { $script:visualProbeActive=$false }
            Check "$locale/$scale LBS279 keyboard exchange covers actual row movement and action-state changes" ($script:visualRowEvents -ge 2 -and $script:visualFooterEvents -ge 1 -and $script:visualUncoveredEvents -eq 0)
            $currentFirst=Get-Row 'boot-0'
            Check "$locale/$scale LBS279 keyboard move retains row and all action identities" ([object]::ReferenceEquals($first,$currentFirst) -and [object]::ReferenceEquals($second,(Get-Row 'boot-1')) -and $firstActions.Count -eq 3 -and $null -ne $firstActions[0] -and $null -ne $firstActions[1] -and $null -ne $firstActions[2] -and [object]::ReferenceEquals($firstActions[0],$currentFirst.Controls['VisibilityGlyph']) -and [object]::ReferenceEquals($firstActions[1],$currentFirst.Controls['AliasEditButton']) -and [object]::ReferenceEquals($firstActions[2],$currentFirst.Controls['ManageReorderGrip']))
            Check "$locale/$scale LBS279 reorder releases cover before next input" (-not (Get-VisualCommitCover) -and $currentFirst.Focused -and $form.Visible)
            $movedOrder='boot-1,boot-0,boot-2,boot-3,boot-4,boot-5,boot-6,boot-7,boot-8,boot-9'
            Check "$locale/$scale Ctrl Down reorders and retains focus" ((Test-RowOrder $movedOrder) -and (Get-Row 'boot-0').Focused -and (Get-Row 'boot-0').TabIndex -eq 1 -and $script:ManageUndoHistory.Count -eq 1)
            $undo.PerformClick()
            Move-ManageEntry -MovedGuid 'boot-0' -TargetGuid 'boot-1' -After:$true
            Update-PopupRows
            Check "$locale/$scale pointer owner parity and shared Undo" ((Test-RowOrder $movedOrder) -and $script:ManageUndoHistory.Count -eq 1)
            $row=Get-Row 'boot-0';[void]$row.Focus()
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Up
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Down
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Down
            Check "$locale/$scale orphan release and repeat do not toggle" (-not (Test-ManageEntryHidden 'boot-0') -and $script:ManageUndoHistory.Count -eq 1)
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Up
            Check "$locale/$scale Space commits once and restores focus" ((Test-ManageEntryHidden 'boot-0') -and $script:ManageUndoHistory.Count -eq 2 -and (Get-Row 'boot-0').Focused)
            Press-Key (Get-Row 'boot-0') ([Windows.Forms.Keys]::Space)
            Check "$locale/$scale hidden row Space shows it again" (-not (Test-ManageEntryHidden 'boot-0') -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 3)
            $undo.PerformClick()
            [void](Get-Row 'boot-0').Focus()
            $script:ManageActiveDragGuid='boot-0'
            Press-Key (Get-Row 'boot-0') $ctrlUp
            Press-Key (Get-Row 'boot-0') ([Windows.Forms.Keys]::Space)
            Press-Key (Get-Row 'boot-0') $ctrlE
            Check "$locale/$scale active drag rejects all row actions" ((Test-RowOrder $movedOrder) -and (Test-ManageEntryHidden 'boot-0') -and -not $script:ManageAliasEditGuid -and $script:ManageUndoHistory.Count -eq 2)
            $script:ManageActiveDragGuid=$null
            Press-Key (Get-Row 'boot-0') $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0]
            Check "$locale/$scale Ctrl E opens native editor without history" ($editor -and $editor.Focused -and $script:ManageAliasEditGuid -eq 'boot-0' -and $script:ManageUndoHistory.Count -eq 2 -and -not $undo.Enabled)
            $editor.Text='Temporary'
            Press-Key $editor ([Windows.Forms.Keys]::Space)
            Press-Key $editor $ctrlUp
            Press-Key $editor $ctrlE
            Check "$locale/$scale editor retains native input scope" ($editor.Focused -and $script:ManageAliasEditGuid -eq 'boot-0' -and (Test-RowOrder $movedOrder) -and $script:ManageUndoHistory.Count -eq 2)
            Press-Key $editor ([Windows.Forms.Keys]::Escape)
            Check "$locale/$scale Escape discards alias and restores GUID focus" (-not $script:ManageAliasEditGuid -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 2)
            Press-Key (Get-Row 'boot-0') $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0];$editor.Text='Renamed'
            Press-Key $editor ([Windows.Forms.Keys]::Enter)
            Check "$locale/$scale Enter commits one alias and restores focus" ($script:ManageEntryAliases['boot-0'] -ceq 'Renamed' -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 3)
            Press-Key (Get-Row 'boot-0') $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0];$editor.Text='Applied'
            $form.Controls.Find('AliasApplyButton',$true)[0].PerformClick()
            Check "$locale/$scale Apply commits and restores row focus" ($script:ManageEntryAliases['boot-0'] -ceq 'Applied' -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 4)
            Press-Key (Get-Row 'boot-0') $ctrlE
            $editor=$form.Controls.Find('AliasEditor',$true)[0];$editor.Text='Discarded'
            $form.Controls.Find('AliasCancelButton',$true)[0].PerformClick()
            Check "$locale/$scale Cancel alias retains committed value and focus" ($script:ManageEntryAliases['boot-0'] -ceq 'Applied' -and (Get-Row 'boot-0').Focused -and $script:ManageUndoHistory.Count -eq 4)
            $undo.PerformClick();$undo.PerformClick();$undo.PerformClick();$undo.PerformClick()
            Check "$locale/$scale mixed history undo restores baseline" ((Test-RowOrder $originalOrder) -and -not (Test-ManageEntryHidden 'boot-0') -and -not $script:ManageEntryAliases.ContainsKey('boot-0') -and $script:saveCalls -eq 0)
            $row=Get-Row 'boot-0';[void]$row.Focus()
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Down
            [void]$cancel.Focus()
            Dispatch-Key $row ([Windows.Forms.Keys]::Space) Up
            Update-PopupRows
            Check "$locale/$scale focus loss disarms Space and no theft" ($cancel.Focused -and $script:ManageUndoHistory.Count -eq 0)
            $new=[pscustomobject]@{Guid='new';Title='New';Subtitle='New';RawDescription='New';Symbol='*';Accent=[Drawing.Color]::Red;TypeTooltip=''}
            $script:CurrentEntries+= $new;Update-PopupRows -Reason 'inventory'
            Move-ManageEntry -MovedGuid 'boot-9' -TargetGuid 'new'
            Check "$locale/$scale no-op on implicit inventory creates no history" ($script:ManageUndoHistory.Count -eq 0 -and 'new' -notin $script:ManageEntryOrder)
            $row=Get-Row 'new';[void]$row.Focus()
            Press-Key $row $ctrlUp
            Check "$locale/$scale new implicit inventory entry moves correctly" ($script:ManageEntryOrder[-2] -eq 'new' -and $script:ManageEntryOrder[-1] -eq 'boot-9' -and (Get-Row 'new').Focused)
            $script:CurrentEntries=@($script:CurrentEntries | Where-Object Guid -ne 'new')
            Press-Key (Get-Row 'new') $ctrlE
            Check "$locale/$scale stale focused target cannot open editor" (-not $script:ManageAliasEditGuid -and $script:ManageUndoHistory.Count -eq 1)
            Update-PopupRows -Reason 'inventory'
            Check "$locale/$scale removed GUID falls back without stale history" (-not (Get-Row 'new') -and (Get-Row 'boot-9').Focused -and $script:ManageUndoHistory.Count -eq 0)
            Reset-VisualCommitProbe
            $script:visualProbeActive=$true
            try { $cancel.PerformClick() }
            finally { $script:visualProbeActive=$false }
            Check "$locale/$scale LBS279 reverse transition covered and released" ($script:visualRowEvents -gt 0 -and $script:visualFooterEvents -gt 0 -and $script:visualUncoveredEvents -eq 0 -and -not (Get-VisualCommitCover))
            Check "$locale/$scale Cancel preserves persisted order" (-not $script:IsManageEntriesMode -and ($script:EntryOrder -join ',') -eq $originalOrder -and $script:saveCalls -eq 0)
            Start-ManageEntriesMode
            [void](Get-Row 'boot-0').Focus()
            Press-Key (Get-Row 'boot-0') $ctrlDown
            $save.PerformClick()
            Check "$locale/$scale Save commits once through existing owner" (-not $script:IsManageEntriesMode -and $script:saveCalls -eq 1 -and $script:EntryOrder[0] -eq 'boot-1')
            # Exercise multi-position and rapid repeated moves, boundary no-op,
            # scroll visibility, stable focus and exceptional cover disposal.
            Start-ManageEntriesMode
            $row=Get-Row 'boot-1';[void]$row.Focus()
            $savedOrder=$script:EntryOrder -join ','
            $ctrlEnd=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End
            $ctrlHome=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home
            $ctrlPageDown=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::PageDown
            Press-Key $row $ctrlEnd
            Check "$locale/$scale LBS279 multi-position move scrolls and retains focus" ($script:ManageEntryOrder[-1] -eq 'boot-1' -and $row.Focused -and $bar.Value -gt 0 -and -not (Get-VisualCommitCover))
            $history=$script:ManageUndoHistory.Count
            Press-Key $row $ctrlDown
            Check "$locale/$scale LBS279 boundary no-op neither moves nor leaks cover" ($script:ManageUndoHistory.Count -eq $history -and -not (Get-VisualCommitCover))
            Press-Key $row $ctrlHome
            Press-Key $row $ctrlPageDown
            Press-Key $row $ctrlHome
            Check "$locale/$scale LBS279 consecutive moves keep row identity draft and focus" ((Test-RowOrder $savedOrder) -and [object]::ReferenceEquals($row,(Get-Row 'boot-1')) -and $row.Focused -and $script:saveCalls -eq 1 -and -not (Get-VisualCommitCover))
            $fixtureCommit=Start-PopupVisualCommit -Reason 'LBS279-exception-fixture'
            try {
                Check "$locale/$scale LBS279 native cover is nonactivating and nested scope is no-op" ($fixtureCommit -and $fixtureCommit.Visible -and $fixtureCommit.FramePaintCount -gt 0 -and $row.Focused -and -not (Start-PopupVisualCommit -Reason 'LBS279-nested-fixture'))
                throw 'LBS279 controlled exception'
            }
            catch {
                if ($_.Exception.Message -ne 'LBS279 controlled exception') { throw }
            }
            finally { Stop-PopupVisualCommit -Commit $fixtureCommit }
            Check "$locale/$scale LBS279 exceptional cleanup releases snapshot and keeps native focus" ($fixtureCommit.IsDisposed -and -not (Get-VisualCommitCover) -and $row.Focused -and $form.Visible)
            $cancel.PerformClick()
            Check "$locale/$scale LBS279 subsequent exit retains persisted order and no cover" (-not $script:IsManageEntriesMode -and ($script:EntryOrder -join ',') -eq $savedOrder -and $script:saveCalls -eq 1 -and -not (Get-VisualCommitCover))
        } finally {$form.Dispose();$script:Popup=$null}
    }
}
Write-Host "LBS178 KEYBOARD TOTAL $script:checks/172"
if ($script:checks -ne 172) {throw "LBS178 total mismatch: $script:checks"}
