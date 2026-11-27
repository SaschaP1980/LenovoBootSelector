# LBS-179: the undo history is local to one Manage session and contains no UI controls.
function Update-ManageUndoInventory {
    if ($null -eq $script:ManageUndoHistory) { return }
    if (-not $script:IsManageEntriesMode) {
        $script:ManageUndoHistory = $null
        $script:ManageUndoInventory = @()
        return
    }
    $current = @($script:CurrentEntries | ForEach-Object { $_.Guid })
    if (-not (Test-StringSequenceEqual -Left $current -Right $script:ManageUndoInventory -Sort)) {
        $hadHistory = $script:ManageUndoHistory.Count -gt 0
        $script:ManageUndoHistory.Clear()
        $script:ManageUndoInventory = @($current)
        if ($script:ManageAliasEditGuid -and -not (Test-GuidInList -Guid $script:ManageAliasEditGuid -List $current)) {
            # The editor's GUID disappeared; never commit its unfinished text.
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoTargetUnavailable'
        }
        elseif ($hadHistory) { $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoInventoryChanged' }
    }
}

function Get-ManageDraftSnapshot {
    return (New-ManageDraftSnapshotCore -Order $script:ManageEntryOrder -Hidden $script:ManageHiddenEntryGuids -Aliases $script:ManageEntryAliases)
}

function Get-ManageUndoBefore {
    if ($null -eq $script:ManageUndoHistory -or -not $script:IsManageEntriesMode) { return }
    Update-ManageUndoInventory
    return (Get-ManageDraftSnapshot)
}

function Add-ManageUndoCheckpoint {
    param($Before)
    if ($null -eq $Before -or $null -eq $script:ManageUndoHistory) { return }
    if (-not (Test-ManageDraftSnapshotEqualCore -Left $Before -Right (Get-ManageDraftSnapshot))) {
        $script:ManageUndoHistory.Add($Before)
    }
}

function Update-ManageUndoButtonState {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $button = $script:Popup.Controls.Find('ManageUndoButton',$true) | Select-Object -First 1
    if (-not $button) { return }
    $button.Enabled = ($script:IsManageEntriesMode -and $null -ne $script:ManageUndoHistory -and
        $script:ManageUndoHistory.Count -gt 0 -and -not $script:ManageAliasEditGuid -and -not $script:ManageActiveDragGuid)
    $button.AccessibleName = $button.Text
    $button.ForeColor = if ($button.Enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(146,146,146) }
    $button.Cursor = if ($button.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
}

function Undo-ManageEntryDraft {
    if (-not $script:IsManageEntriesMode -or $script:ManageAliasEditGuid -or $script:ManageActiveDragGuid -or $null -eq $script:ManageUndoHistory) { return }
    Update-ManageUndoInventory
    if ($script:ManageUndoHistory.Count -eq 0) {
        Update-PopupRows -Reason 'manage-undo-empty'
        return
    }
    $visualCommit = Start-PopupVisualCommit -Reason 'manage-undo'
    try {
        $index = $script:ManageUndoHistory.Count - 1
        $previous = $script:ManageUndoHistory[$index]
        $script:ManageUndoHistory.RemoveAt($index)
        # Copy again so subsequent edits cannot mutate retained snapshots.
        $restored = New-ManageDraftSnapshotCore -Order $previous.Order -Hidden $previous.Hidden -Aliases $previous.Aliases
        $script:ManageEntryOrder = @($restored.Order)
        $script:ManageHiddenEntryGuids = @($restored.Hidden)
        $script:ManageEntryAliases = $restored.Aliases
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoDone'
        $undo = if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Controls.Find('ManageUndoButton',$true) | Select-Object -First 1 }
        $hadFocus = $undo -and $undo.Focused
        Update-PopupRows -Reason 'manage-undo'
        if ($hadFocus -and -not $undo.Enabled) {
            $cancel = $script:Popup.Controls.Find('ManageCancelButton',$true) | Select-Object -First 1
            if ($cancel -and $cancel.CanFocus) { [void]$cancel.Focus() }
        }
    }
    finally { Stop-PopupVisualCommit -Commit $visualCommit }
}

function Set-ManageEntryAliasDraft {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [AllowEmptyString()][string]$Alias
    )
    $normalized = $Guid.ToLowerInvariant()
    $value = if ($null -eq $Alias) { '' } else { ([string]$Alias).Trim() }
    $previous = [string]$script:ManageEntryAliases[$normalized]
    if (-not (Test-EntryAliasChangeCore -Value $value -Previous $previous)) { return $false }
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $normalized -List $script:ManageUndoInventory)) { return $false }
    }
    if ($value -ceq $previous) { return $true }
    $before = Get-ManageUndoBefore
    if ($value) {
        $script:ManageEntryAliases[$normalized] = $value
    }
    else {
        [void]$script:ManageEntryAliases.Remove($normalized)
    }
    Add-ManageUndoCheckpoint -Before $before
    return $true
}

function Commit-ActiveManageAliasEditor {
    if (-not $script:ManageAliasEditGuid) { return $true }
    if ($script:Popup -and -not $script:Popup.IsDisposed) {
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor -and [string]$editor.Tag) {
            if (-not (Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text))) {
                Show-ManageAliasLimitFeedback -Editor $editor
                return $false
            }
        }
    }
    $script:ManageAliasEditGuid = $null
    return $true
}


function Get-OrderedEntriesForUi {
    param(
        [switch]$IncludeHidden,
        [switch]$UseManageDraft
    )

    $order = if ($UseManageDraft) { @($script:ManageEntryOrder) } else { @($script:EntryOrder) }
    $hidden = if ($UseManageDraft) { @($script:ManageHiddenEntryGuids) } else { @($script:HiddenEntryGuids) }
    return @(Get-OrderedEntriesCore -Source @($script:CurrentEntries) -Order $order -Hidden $hidden -IncludeHidden:$IncludeHidden)
}


function Test-ManageEntryHidden {
    param([Parameter(Mandatory=$true)][string]$Guid)
    return (Test-GuidInList -Guid $Guid -List $script:ManageHiddenEntryGuids)
}

function Toggle-ManageEntryVisibility {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $normalized = $Guid.ToLowerInvariant()
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $normalized -List $script:ManageUndoInventory)) { return }
    }
    $before = Get-ManageUndoBefore
    if (Test-ManageEntryHidden -Guid $normalized) {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids | Where-Object { ([string]$_).ToLowerInvariant() -ne $normalized })
    }
    else {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids) + $normalized
    }
    Add-ManageUndoCheckpoint -Before $before
}

function Move-ManageEntry {
    param(
        [Parameter(Mandatory=$true)][string]$MovedGuid,
        [Parameter(Mandatory=$true)][string]$TargetGuid,
        [bool]$After = $false
    )

    $moved = $MovedGuid.ToLowerInvariant()
    $target = $TargetGuid.ToLowerInvariant()
    if ($moved -eq $target) { return }
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $moved -List $script:ManageUndoInventory) -or
            -not (Test-GuidInList -Guid $target -List $script:ManageUndoInventory)) { return }
    }
    $liveOrder = @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft | ForEach-Object { ([string]$_.Guid).ToLowerInvariant() })
    $movedIndex = [Array]::IndexOf($liveOrder,$moved)
    $targetIndexLive = [Array]::IndexOf($liveOrder,$target)
    if ($movedIndex -ge 0 -and $targetIndexLive -ge 0 -and
        (($After -and $movedIndex -eq ($targetIndexLive+1)) -or
        (-not $After -and $movedIndex -eq ($targetIndexLive-1)))) { return }
    $before = Get-ManageUndoBefore

    # A newly discovered current entry may be displayed before it is explicit
    # in the draft order. Materialize the displayed order for either input path,
    # retaining existing unavailable GUIDs and recording only the actual move.
    $order = @($script:ManageEntryOrder)
    foreach ($entry in @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)) {
        if (-not (Test-GuidInList -Guid ([string]$entry.Guid) -List $order)) { $order += [string]$entry.Guid }
    }
    $list = New-Object System.Collections.ArrayList
    foreach ($guid in $order) {
        if ([string]$guid -and ([string]$guid).ToLowerInvariant() -ne $moved) {
            [void]$list.Add(([string]$guid).ToLowerInvariant())
        }
    }

    $targetIndex = $list.IndexOf($target)
    if ($targetIndex -lt 0) {
        [void]$list.Add($moved)
    }
    else {
        $insertIndex = $targetIndex + $(if ($After) { 1 } else { 0 })
        if ($insertIndex -gt $list.Count) { $insertIndex = $list.Count }
        $list.Insert($insertIndex, $moved)
    }
    $script:ManageEntryOrder = @($list)
    Add-ManageUndoCheckpoint -Before $before
}

function Update-ManageEntriesUiState {
    Update-ManageUndoInventory
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $sectionLabel = $script:Popup.Controls.Find('SectionLabel', $true) | Select-Object -First 1
    $manageButton = $script:Popup.Controls.Find('ManageEntriesButton', $true) | Select-Object -First 1
    $managePanel = $script:Popup.Controls.Find('ManageEntriesPanel', $true) | Select-Object -First 1
    $configSectionPanel = $script:Popup.Controls.Find('ConfigSectionPanel', $true) | Select-Object -First 1
    $settingsPanel = $script:Popup.Controls.Find('SettingsPanel', $true) | Select-Object -First 1
    $defaultPanel = $script:Popup.Controls.Find('DefaultPanel', $true) | Select-Object -First 1
    $settingsDivider = $script:Popup.Controls.Find('SettingsDivider', $true) | Select-Object -First 1
    $restartPanel = $script:Popup.Controls.Find('RestartPanel', $true) | Select-Object -First 1
    $footerPanel = $script:Popup.Controls.Find('FooterPanel', $true) | Select-Object -First 1

    # LBS-157/LBS-231: manage mode claims 106 additional design pixels,
    # including the removed instructional footer. Reapply after every DPI
    # rescale, before Update-BootEntryScrollLayout calculates the scroll range.
    $entryList = $script:Popup.Controls.Find('EntryList', $true) | Select-Object -First 1
    if ($entryList) {
        $scale = Get-PopupDpiLayoutScale -Popup $script:Popup
        $designHeight = if ($script:IsManageEntriesMode) { 508 } else { 402 }
        $height = [Math]::Max(1,[int][Math]::Round($designHeight * $scale))
        if ($entryList.Height -ne $height) { $entryList.Height = $height }
        $scrollBar = $entryList.Controls['EntryScroll']
        if ($scrollBar -and $scrollBar.Height -ne $height) { $scrollBar.Height = $height }
    }

    if ($sectionLabel) { $sectionLabel.Text = if ($script:IsManageEntriesMode) { Get-LocalizedString -Key 'Manage.Section' } else { Get-LocalizedString -Key 'Popup.NextBootSection' } }
    $keyboardHint = $script:Popup.Controls.Find('ManageKeyboardHint',$true) | Select-Object -First 1
    if ($keyboardHint) {
        $keyboardHint.Visible = $script:IsManageEntriesMode
        $keyboardHint.Text = Get-LocalizedString -Key 'Manage.KeyboardHint'
    }
    if ($manageButton) {
        $manageButton.Visible = -not $script:IsManageEntriesMode
        $manageButton.Enabled = (-not $script:IsManageEntriesMode -and [bool]$capabilities.CanManageEntries)
    }
    if ($managePanel) {
        $managePanel.Visible = $script:IsManageEntriesMode
        if ($script:IsManageEntriesMode) { $managePanel.BringToFront() }
    }
    foreach ($control in @($configSectionPanel,$settingsPanel,$defaultPanel,$settingsDivider,$restartPanel,$footerPanel)) {
        if ($control) { $control.Visible = -not $script:IsManageEntriesMode }
    }

    if ($script:ManageEntriesMenuItem) {
        $script:ManageEntriesMenuItem.Enabled = (-not $script:IsManageEntriesMode -and [bool]$capabilities.CanManageEntries)
    }
    Update-ManageUndoButtonState
}

function Start-ManageEntriesMode {
    param([switch]$PointerActivation)
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if (-not $capabilities.CanManageEntries) { return }
    if ($script:IsManageEntriesMode) { return }

    $visualCommit = Start-PopupVisualCommit -Reason 'manage-enter'
    try {
        $script:ManageEntryOrder = @((Get-OrderedEntriesForUi -IncludeHidden) | ForEach-Object { $_.Guid })
        $script:ManageHiddenEntryGuids = @($script:HiddenEntryGuids)
        $script:ManageEntryAliases = Copy-EntryAliasMap $script:EntryAliases
        $script:ManageBaselineEntryOrder = @($script:ManageEntryOrder)
        $script:ManageBaselineHiddenEntryGuids = @($script:ManageHiddenEntryGuids)
        $script:ManageBaselineEntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
        $script:ManageAliasEditGuid = $null
        $script:ManageDropPreview = $null
        $script:ManageActiveDragGuid = $null
        $script:IsManageEntriesMode = $true
        $script:ManageUndoHistory = [System.Collections.Generic.List[object]]::new()
        $script:ManageUndoInventory = @($script:CurrentEntries | ForEach-Object { $_.Guid })
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusEditing'
        Update-ManageEntriesUiState
        Update-PopupRows -Reason 'manage-enter'
        Update-ManageSaveButtonState
        # Only explicit mode entry acquires the primary list focus. Ordinary
        # reconciliation remains responsible for preserving the current owner.
        if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) {
            $anchor = $script:Popup.Controls.Find('BootRow',$true) | Where-Object {
                $_.TabStop -and $_.CanFocus -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode
            } | Sort-Object Top | Select-Object -First 1
            if ($anchor) { Restore-ManageRowFocus -Guid ([string]$anchor.Tag) -KeyboardCue:(-not $PointerActivation.IsPresent) }
        }
    }
    finally { Stop-PopupVisualCommit -Commit $visualCommit }
}

function Stop-ManageEntriesMode {
    param([switch]$Save)
    if (-not $script:IsManageEntriesMode) { return }
    # Explicit mode exit supersedes any deferred in-mode presentation refresh.
    $script:PopupRowsRefreshPending = $false
    Reset-ManageDragPreview

    if ($Save) {
        if (-not (Commit-ActiveManageAliasEditor)) { return }
        $script:EntryOrder = @($script:ManageEntryOrder)
        $script:HiddenEntryGuids = @($script:ManageHiddenEntryGuids | Select-Object -Unique)
        $script:EntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
        Save-AppSettings
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusSaved'
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusDiscarded'
    }

    $visualCommit = Start-PopupVisualCommit -Reason 'manage-exit'
    try {
        $script:IsManageEntriesMode = $false
        $script:ManageUndoHistory = $null
        $script:ManageUndoInventory = @()
        $script:ManageEntryOrder = @()
        $script:ManageHiddenEntryGuids = @()
        $script:ManageEntryAliases = @{}
        $script:ManageBaselineEntryOrder = @()
        $script:ManageBaselineHiddenEntryGuids = @()
        $script:ManageBaselineEntryAliases = @{}
        $script:ManageAliasEditGuid = $null
        Update-ManageEntriesUiState
        Update-PopupRows -Reason 'manage-exit'
    }
    finally { Stop-PopupVisualCommit -Commit $visualCommit }
}
