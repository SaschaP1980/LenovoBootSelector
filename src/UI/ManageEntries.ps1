function Set-ManageEntryAliasDraft {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [AllowEmptyString()][string]$Alias
    )
    $normalized = $Guid.ToLowerInvariant()
    $value = if ($null -eq $Alias) { '' } else { ([string]$Alias).Trim() }
    if ($value) {
        $script:ManageEntryAliases[$normalized] = $value
    }
    else {
        [void]$script:ManageEntryAliases.Remove($normalized)
    }
}

function Commit-ActiveManageAliasEditor {
    if (-not $script:ManageAliasEditGuid) { return }
    try {
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
            if ($editor -and [string]$editor.Tag) {
                Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
            }
        }
    }
    finally {
        $script:ManageAliasEditGuid = $null
    }
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
    if (Test-ManageEntryHidden -Guid $normalized) {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids | Where-Object { ([string]$_).ToLowerInvariant() -ne $normalized })
    }
    else {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids) + $normalized
    }
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

    $list = New-Object System.Collections.ArrayList
    foreach ($guid in @($script:ManageEntryOrder)) {
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
}

function Update-ManageEntriesUiState {
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

    if ($sectionLabel) { $sectionLabel.Text = if ($script:IsManageEntriesMode) { Get-LocalizedString -Key 'Manage.Section' } else { Get-LocalizedString -Key 'Popup.NextBootSection' } }
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
}

function Start-ManageEntriesMode {
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if (-not $capabilities.CanManageEntries) { return }
    if ($script:IsManageEntriesMode) { return }

    $script:ManageEntryOrder = @((Get-OrderedEntriesForUi -IncludeHidden) | ForEach-Object { $_.Guid })
    $script:ManageHiddenEntryGuids = @($script:HiddenEntryGuids)
    $script:ManageEntryAliases = Copy-EntryAliasMap $script:EntryAliases
    $script:ManageBaselineEntryOrder = @($script:ManageEntryOrder)
    $script:ManageBaselineHiddenEntryGuids = @($script:ManageHiddenEntryGuids)
    $script:ManageBaselineEntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
    $script:ManageAliasEditGuid = $null
    $script:IsManageEntriesMode = $true
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusEditing'
    Update-ManageEntriesUiState
    Update-PopupRows
    Update-ManageSaveButtonState
}

function Stop-ManageEntriesMode {
    param([switch]$Save)
    if (-not $script:IsManageEntriesMode) { return }

    if ($Save) {
        Commit-ActiveManageAliasEditor
        $script:EntryOrder = @($script:ManageEntryOrder)
        $script:HiddenEntryGuids = @($script:ManageHiddenEntryGuids | Select-Object -Unique)
        $script:EntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
        Save-AppSettings
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusSaved'
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusDiscarded'
    }

    $script:IsManageEntriesMode = $false
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageBaselineEntryOrder = @()
    $script:ManageBaselineHiddenEntryGuids = @()
    $script:ManageBaselineEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    Update-ManageEntriesUiState
    Update-PopupRows
}
