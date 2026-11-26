#requires -version 5.1
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
foreach ($rel in @('src\Core\EntryPreferences.ps1','src\Core\Localization.ps1','src\UI\BootEntryList.ps1','src\UI\PopupDpiLayout.ps1','src\UI\PopupComposition.ps1','src\UI\ManageEntriesState.ps1','src\UI\ManageEntries.ps1')) {. (Join-Path $root $rel)}
$script:checks=0
function Assert-Undo([bool]$Pass,[string]$Name) {
    if (-not $Pass) {throw "LBS179 RED: $Name"}
    $script:checks++
    Write-Host "PASS LBS179 $Name"
}
$script:Locale='de-DE'
function Get-LocalizedString {param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values}
function Get-CurrentSystemFunctionsCapabilities {return [pscustomobject]@{CanManageEntries=$true}}
function Reset-ManageDragPreview {$script:ManageActiveDragGuid=$null}
function Update-PopupRows {param([string]$Reason) Update-ManageEntriesUiState;Update-ManageSaveButtonState}
function Save-AppSettings {$script:saveCalls++}
$script:saveCalls=0
$script:ColorSurface=[Drawing.Color]::FromArgb(32,32,32)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorAccent=[Drawing.Color]::Red
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(42,42,42)
$script:AppVersion='1.7.0.0'
$a='{aaaaaaaa-1111-1111-1111-111111111111}'
$b='{bbbbbbbb-2222-2222-2222-222222222222}'
$c='{cccccccc-3333-3333-3333-333333333333}'
$d='{dddddddd-4444-4444-4444-444444444444}'
$all=@([pscustomobject]@{Guid=$a},[pscustomobject]@{Guid=$b},[pscustomobject]@{Guid=$c})
$script:CurrentEntries=$all
$script:EntryOrder=@($a,$b,$c)
$script:HiddenEntryGuids=@($d)
$script:EntryAliases=@{$a='First';$d='Retained'}
$script:IsManageEntriesMode=$false
$script:ManageUndoHistory=$null
$copy=New-ManageDraftSnapshotCore -Order $script:EntryOrder -Hidden $script:HiddenEntryGuids -Aliases $script:EntryAliases
$mutated=New-ManageDraftSnapshotCore -Order $copy.Order -Hidden $copy.Hidden -Aliases $copy.Aliases
$mutated.Order[0]=$c;$mutated.Aliases[$a]='first'
Assert-Undo ($copy.Order[0] -eq $a -and $copy.Aliases[$a] -ceq 'First' -and -not (Test-ManageDraftSnapshotEqualCore $copy $mutated)) 'Detached core snapshot'
$form=[Windows.Forms.Form]::new()
try {
    $script:Popup=$form
    Initialize-PopupDpiLayout -Form $form
    $form.ClientSize=[Drawing.Size]::new(390,672)
    $panel=[Windows.Forms.Panel]::new();$panel.Name='PopupRoot';$panel.Size=$form.ClientSize
    $form.Controls.Add($panel)
    Add-PopupManageEntriesSection -Root $panel
    Complete-PopupDpiLayout -Form $form -Scale 1.0
    $form.Show();[Windows.Forms.Application]::DoEvents()
    $undo=$panel.Controls.Find('ManageUndoButton',$true)[0]
    $save=$panel.Controls.Find('ManageSaveButton',$true)[0]
    $cancel=$panel.Controls.Find('ManageCancelButton',$true)[0]
    Start-ManageEntriesMode
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and -not $undo.Enabled -and -not $save.Enabled -and $undo.Text -ceq 'Rückgängig') 'Empty session, localized native Undo'
    Assert-Undo ($panel.Controls['ManageEntriesPanel'].Controls.Count -eq 5 -and $undo.AccessibleName -ceq $undo.Text) 'Single extra control'
    [void](Set-ManageEntryAliasDraft -Guid $a -Alias 'First')
    Move-ManageEntry -MovedGuid $a -TargetGuid $b
    Update-PopupRows
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and -not $undo.Enabled) 'No-op alias and drop'
    [void](Set-ManageEntryAliasDraft -Guid $a -Alias 'first')
    Toggle-ManageEntryVisibility -Guid $b
    Move-ManageEntry -MovedGuid $c -TargetGuid $a
    Update-PopupRows
    Assert-Undo ($script:ManageUndoHistory.Count -eq 3 -and $undo.Enabled -and $save.Enabled -and $script:ManageEntryOrder[0] -eq $c) 'Mixed committed operations'
    $undo.PerformClick()
    Assert-Undo ($script:ManageUndoHistory.Count -eq 2 -and $script:ManageEntryOrder[0] -eq $a -and (Test-ManageEntryHidden $b) -and $script:ManageEntryAliases[$a] -ceq 'first') 'Undo reorder retains preceding edits'
    $undo.PerformClick()
    Assert-Undo ($script:ManageUndoHistory.Count -eq 1 -and -not (Test-ManageEntryHidden $b) -and $script:ManageEntryAliases[$a] -ceq 'first') 'Undo visibility retains preceding alias'
    [void]$undo.Focus();$focused=$undo.Focused
    $undo.PerformClick()
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and $script:ManageEntryAliases[$a] -ceq 'First' -and -not $undo.Enabled -and -not $save.Enabled -and $script:saveCalls -eq 0) 'Baseline restored without save'
    Assert-Undo (-not $focused -or $cancel.Focused) 'Final undo focus fallback'
    Move-ManageEntry -MovedGuid $b -TargetGuid $a
    [void](Set-ManageEntryAliasDraft -Guid $a -Alias 'Changed')
    Update-PopupRows
    $undo.PerformClick()
    Assert-Undo ($script:ManageEntryOrder[0] -eq $b -and $script:ManageEntryAliases[$a] -ceq 'First' -and $script:ManageUndoHistory.Count -eq 1) 'Undo alias retains preceding reorder'
    $editor=[Windows.Forms.TextBox]::new();$editor.Name='AliasEditor';$editor.Tag=$a
    $panel.Controls.Add($editor);$script:ManageAliasEditGuid=$a
    $editor.Text='F';$editor.Text='Fo';$editor.Text='Final'
    Update-PopupRows
    Assert-Undo ($script:ManageUndoHistory.Count -eq 1 -and -not $undo.Enabled -and $save.Enabled) 'Unfinished typing not recorded'
    [void](Commit-ActiveManageAliasEditor)
    $panel.Controls.Remove($editor);$editor.Dispose()
    Update-PopupRows
    Assert-Undo ($script:ManageUndoHistory.Count -eq 2 -and $script:ManageEntryAliases[$a] -ceq 'Final' -and $undo.Enabled) 'Alias commit grouped'
    $script:ManageActiveDragGuid=$b;Update-ManageUndoButtonState
    Undo-ManageEntryDraft
    Assert-Undo ($script:ManageUndoHistory.Count -eq 2 -and -not $undo.Enabled) 'Active drag gate'
    Reset-ManageDragPreview;Update-PopupRows
    Assert-Undo ($script:ManageUndoHistory.Count -eq 2 -and $undo.Enabled) 'Canceled drag'
    $script:CurrentEntries=@($all[2],$all[1],$all[0]);Update-PopupRows -Reason 'firmware-state'
    Assert-Undo ($script:ManageUndoHistory.Count -eq 2 -and $undo.Enabled) 'Unchanged GUID set preserves history'
    $script:Locale='en-US';$undo.Text=Get-LocalizedString -Key 'Manage.Undo';Update-PopupRows -Reason 'language-change'
    Assert-Undo ($undo.Text -ceq 'Undo' -and $undo.AccessibleName -ceq 'Undo' -and $script:ManageUndoHistory.Count -eq 2) 'Language change'
    $script:CurrentEntries=@($all[0],$all[1]);Update-PopupRows -Reason 'firmware-state'
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and -not $undo.Enabled -and $script:ManageEntryAliases[$a] -ceq 'Final' -and $script:LastStatusText -ceq (Get-LocalizedString -Key 'Manage.UndoInventoryChanged')) 'Changed inventory invalidates only history'
    $script:CurrentEntries=$all;Update-PopupRows -Reason 'firmware-state';Undo-ManageEntryDraft
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and $script:ManageEntryAliases[$a] -ceq 'Final' -and -not $undo.Enabled) 'No stale restoration on reappearance'
    Toggle-ManageEntryVisibility -Guid $c;Update-PopupRows;$undo.PerformClick()
    Assert-Undo (-not (Test-ManageEntryHidden $c) -and $script:ManageEntryAliases[$d] -ceq 'Retained' -and (Test-ManageEntryHidden $d)) 'New history preserves unavailable local metadata'
    $script:ManageAliasEditGuid=$c
    $script:CurrentEntries=@($all[0],$all[1]);Update-PopupRows -Reason 'firmware-state'
    Assert-Undo (-not $script:ManageAliasEditGuid -and $script:ManageUndoHistory.Count -eq 0 -and $script:LastStatusText -ceq (Get-LocalizedString -Key 'Manage.UndoTargetUnavailable') -and $script:ManageEntryAliases[$a] -ceq 'Final') 'Disappearing active editor is discarded without unrelated draft loss'
    $script:CurrentEntries=$all;Update-PopupRows -Reason 'firmware-state'
    $cancel.PerformClick()
    Assert-Undo (-not $script:IsManageEntriesMode -and $null -eq $script:ManageUndoHistory -and $script:EntryAliases[$a] -ceq 'First' -and $script:saveCalls -eq 0) 'Cancel discards draft and history'
    Start-ManageEntriesMode
    [void](Set-ManageEntryAliasDraft -Guid $a -Alias 'Saved')
    Toggle-ManageEntryVisibility -Guid $b;Update-PopupRows;$undo.PerformClick();$save.PerformClick()
    Assert-Undo (-not $script:IsManageEntriesMode -and $null -eq $script:ManageUndoHistory -and $script:saveCalls -eq 1 -and $script:EntryAliases[$a] -ceq 'Saved' -and $b -notin $script:HiddenEntryGuids) 'Save only remaining draft through existing owner'
    Start-ManageEntriesMode
    Assert-Undo ($script:ManageUndoHistory.Count -eq 0 -and -not $undo.Enabled -and -not $save.Enabled) 'Fresh session'
    foreach ($locale in @('en-US','de-DE')) {
        $script:Locale=$locale
        $undo.Text=Get-LocalizedString -Key 'Manage.Undo'
        $cancel.Text=Get-LocalizedString -Key 'Common.Cancel'
        $save.Text=Get-LocalizedString -Key 'Manage.Save'
        foreach ($scale in @(1.0,2.5)) {
            [void](Set-PopupDpiLayoutScale -Form $form -Scale $scale)
            $bitmap=[Drawing.Bitmap]::new(8,8)
            try {
                $bitmap.SetResolution([single](96*$scale),[single](96*$scale))
                $g=[Drawing.Graphics]::FromImage($bitmap)
                try {
                    $fit=($undo.Right -lt $cancel.Left -and $cancel.Right -lt $save.Left)
                    foreach ($btn in @($undo,$cancel,$save)) {
                        $measured=$g.MeasureString($btn.Text,$btn.Font).Width
                        Write-Host ("LBS179 FIT {0}/{1} {2} measured={3:F1} width={4}" -f $locale,$scale,$btn.Name,$measured,$btn.Width)
                        $fit=$fit -and $btn.Parent.ClientRectangle.Contains($btn.Bounds) -and $measured -le ($btn.Width-4)
                    }
                    Assert-Undo $fit "$locale/$scale localized action row fit"
                } finally {$g.Dispose()}
            } finally {$bitmap.Dispose()}
        }
    }
    Stop-ManageEntriesMode
} finally {$form.Dispose();$script:Popup=$null}
Write-Host "LBS179 UNDO TOTAL $script:checks/27"
if ($script:checks -ne 27) {throw "LBS179 count mismatch: $script:checks"}
