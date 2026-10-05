function Test-ManageEntriesDirty {
    if (-not $script:IsManageEntriesMode) { return $false }
    if (-not (Test-StringSequenceEqual -Left $script:ManageEntryOrder -Right $script:ManageBaselineEntryOrder)) { return $true }
    if (-not (Test-StringSequenceEqual -Left $script:ManageHiddenEntryGuids -Right $script:ManageBaselineHiddenEntryGuids -Sort)) { return $true }
    if (-not (Test-EntryAliasMapsEqual -Left $script:ManageEntryAliases -Right $script:ManageBaselineEntryAliases)) { return $true }

    # A still-open alias editor is part of the draft. Reflect its current text
    # immediately so the global save button responds before Enter/Übernehmen.
    if ($script:ManageAliasEditGuid -and $script:Popup -and -not $script:Popup.IsDisposed) {
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor -and [string]$editor.Tag) {
            $guid = ([string]$editor.Tag).ToLowerInvariant()
            $current = ([string]$editor.Text).Trim()
            $draft = ''
            if ($script:ManageEntryAliases.ContainsKey($guid)) { $draft = ([string]$script:ManageEntryAliases[$guid]).Trim() }
            if ($current -ne $draft) { return $true }
        }
    }
    return $false
}

function Update-ManageSaveButtonState {
    $button = $script:ManageSaveButton
    if (-not $button -or $button.IsDisposed) { return }
    $dirty = Test-ManageEntriesDirty
    $button.Enabled = $dirty
    if ($dirty) {
        $button.ForeColor = $script:ColorPrimary
        $button.BackColor = $script:ColorAccent
        $button.FlatAppearance.BorderColor = $script:ColorAccent
        $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    else {
        $button.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
        $button.BackColor = [Drawing.Color]::FromArgb(35,35,35)
        $button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
        $button.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}
