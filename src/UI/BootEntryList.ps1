function New-Label {
    param(
        [string]$Text,
        [Drawing.Font]$Font,
        [Drawing.Color]$ForeColor,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.BackColor = [Drawing.Color]::Transparent
    $label.Location = New-Object Drawing.Point($X, $Y)
    $label.Size = New-Object Drawing.Size($Width, $Height)
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function Get-BootRowFromControl($Control) {
    $current = $Control
    while ($current) {
        if (($current -is [System.Windows.Forms.Panel]) -and $current.Name -eq 'BootRow') { return $current }
        $current = $current.Parent
    }
    return $null
}

function Set-RowHoverState($Control, [bool]$Hover) {
    $row = Get-BootRowFromControl $Control
    if (-not $row) { return }

    $rowGuid = [string]$row.Tag
    if ($script:IsManageEntriesMode) {
        $hidden = Test-ManageEntryHidden -Guid $rowGuid
        if ($hidden) {
            $row.BackColor = if ($Hover) { [Drawing.Color]::FromArgb(37,37,37) } else { [Drawing.Color]::FromArgb(27,27,27) }
        }
        else {
            $row.BackColor = if ($Hover) { $script:ColorHover } else { $script:ColorRow }
        }
        $row.Invalidate($true)
        return
    }

    $isSelected = $script:SelectedGuid -and ($rowGuid -eq $script:SelectedGuid)
    if ($isSelected) {
        $row.BackColor = $script:ColorSelectedRow
    }
    elseif ($Hover) {
        $row.BackColor = $script:ColorHover
    }
    else {
        $row.BackColor = $script:ColorRow
    }
    $row.Invalidate($true)
}

function Update-PopupRows {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }

    $listMatches = $script:Popup.Controls.Find('EntryList', $true)
    $listPanel = if ($listMatches.Count -gt 0) { $listMatches[0] } else { $null }
    $contentPanel = if ($listPanel) { $listPanel.Controls['EntryContent'] } else { $null }
    $scrollBar = if ($listPanel) { $listPanel.Controls['EntryScroll'] } else { $null }
    $statusMatches = $script:Popup.Controls.Find('StatusLabel', $true)
    $statusLabel = if ($statusMatches.Count -gt 0) { $statusMatches[0] } else { $null }
    if (-not $listPanel -or -not $contentPanel) { return }

    $contentPanel.SuspendLayout()
    $contentPanel.Controls.Clear()

    $baseRowHeight = 60
    $rowGap = 4
    $y = 0
    $displayEntries = if ($script:IsManageEntriesMode) {
        @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)
    }
    else {
        @(Get-OrderedEntriesForUi)
    }
    $handlers = New-BootEntryInteractionHandlers
    $contentPanel.AllowDrop = $false

    foreach ($entry in $displayEntries) {
        $rendered = New-BootEntryRow -Entry $entry -Y $y -BaseRowHeight $baseRowHeight -Handlers $handlers
        $contentPanel.Controls.Add($rendered.Row)
        $y += ([int]$rendered.Height + $rowGap)
    }

    Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $y -BaseRowHeight $baseRowHeight -RowGap $rowGap

    if ($statusLabel) { $statusLabel.Text = $script:LastStatusText }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-ManageEntriesUiState
    Update-ManageSaveButtonState
    $contentPanel.ResumeLayout()
    Update-MaintenanceUi
}
