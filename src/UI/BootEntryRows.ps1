# Lenovo Boot Selector - boot-entry row presentation helpers.
# LBS-29 separates row rendering and interaction responsibilities from list refresh orchestration.

function New-BootEntryInteractionHandlers {
    $clickHandler = {
        param($sender, $eventArgs)
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if ($script:IsManageEntriesMode) {
            if (-not $capabilities.CanManageEntries) { return }
        }
        elseif (-not $capabilities.CanSetBootNext) {
            return
        }
        $guid = [string]$sender.Tag
        if (-not $guid) {
            $row = Get-BootRowFromControl $sender
            if ($row) { $guid = [string]$row.Tag }
        }
        if (-not $guid) { return }

        if ($script:IsManageEntriesMode) {
            if (([datetime]::UtcNow - $script:ManageLastDragUtc).TotalMilliseconds -lt 350) { return }
            if ($script:ManageAliasEditGuid) { Commit-ActiveManageAliasEditor }
            Toggle-ManageEntryVisibility -Guid $guid
            $script:LastStatusText = if (Test-ManageEntryHidden -Guid $guid) { Get-LocalizedString -Key 'Manage.EntryHiddenStatus' } else { Get-LocalizedString -Key 'Manage.EntryVisibleStatus' }
            Update-PopupRows
            return
        }

        try {
            $entry = Get-EntryByGuid $guid
            Set-BootNextTarget -Guid $guid
            $script:SelectedGuid = $guid.ToLowerInvariant()
            $script:LastStatusText = if ($entry) { Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $entry) } } else { Get-LocalizedString -Key 'Status.NextBootSet' }
            Update-PopupRows
        }
        catch {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
        }
    }

    $enterHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $true }
    $leaveHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $false }
    $wheelHandler = {
        param($sender, $eventArgs)
        $panel = $null
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $panelMatches = $script:Popup.Controls.Find('EntryList', $true)
            if ($panelMatches.Count -gt 0) { $panel = $panelMatches[0] }
        }
        $bar = if ($panel) { $panel.Controls['EntryScroll'] } else { $null }
        if ($bar -and $bar.Visible) {
            $direction = if ($eventArgs.Delta -gt 0) { -1 } else { 1 }
            $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
        }
    }
    $mouseDownHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or $eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $guid = [string]$sender.Tag
        if (-not $guid) {
            $row = Get-BootRowFromControl $sender
            if ($row) { $guid = [string]$row.Tag }
        }
        $script:ManageDragGuid = $guid
        $script:ManageDragStartX = $eventArgs.X
        $script:ManageDragStartY = $eventArgs.Y
    }
    $mouseMoveHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $script:ManageDragGuid) { return }
        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $dx = [Math]::Abs($eventArgs.X - $script:ManageDragStartX)
        $dy = [Math]::Abs($eventArgs.Y - $script:ManageDragStartY)
        if ($dx -lt 5 -and $dy -lt 5) { return }
        $guid = $script:ManageDragGuid
        $script:ManageDragGuid = $null
        $script:ManageLastDragUtc = [datetime]::UtcNow
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) } catch { }
    }
    $dragEnterHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode -and $eventArgs.Data.GetDataPresent([string])) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
        else {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    }
    $dragDropHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $eventArgs.Data.GetDataPresent([string])) { return }
        $movedGuid = [string]$eventArgs.Data.GetData([string])
        $targetRow = Get-BootRowFromControl $sender
        if (-not $targetRow) { return }
        $point = $targetRow.PointToClient((New-Object Drawing.Point($eventArgs.X, $eventArgs.Y)))
        $after = ($point.Y -gt ($targetRow.Height / 2))
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
        $script:ManageLastDragUtc = [datetime]::UtcNow
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.OrderChanged'
        Update-PopupRows
    }

    return [pscustomobject]@{
        Click = $clickHandler
        Enter = $enterHandler
        Leave = $leaveHandler
        Wheel = $wheelHandler
        MouseDown = $mouseDownHandler
        MouseMove = $mouseMoveHandler
        DragEnter = $dragEnterHandler
        DragDrop = $dragDropHandler
    }
}

function Add-BootEntryAliasEditor {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [AllowNull()][string]$Alias
    )

    # v0.2.30: keep the expanded alias editor, but render it as a
    # flat edit line rather than a full focus rectangle. Only the
    # bottom rule turns Lenovo-red while the TextBox has focus.
    $editorFrame = New-Object System.Windows.Forms.Panel
    $editorFrame.Name = 'AliasEditorFrame'
    $editorFrame.Location = New-Object Drawing.Point(58, 32)
    $editorFrame.Size = New-Object Drawing.Size(318, 27)
    $editorFrame.BackColor = $script:ColorRow

    $aliasEditor = New-Object System.Windows.Forms.TextBox
    $aliasEditor.Name = 'AliasEditor'
    $aliasEditor.Tag = $entry.Guid
    $aliasEditor.Text = if ($alias) { [string]$alias } else { '' }
    $aliasEditor.Font = New-Object Drawing.Font('Segoe UI', 9.2, [Drawing.FontStyle]::Regular)
    $aliasEditor.ForeColor = $script:ColorPrimary
    $aliasEditor.BackColor = [Drawing.Color]::FromArgb(24,24,24)
    $aliasEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $aliasEditor.Location = New-Object Drawing.Point(0, 2)
    $aliasEditor.Size = New-Object Drawing.Size(288, 21)

    $aliasUnderline = New-Object System.Windows.Forms.Panel
    $aliasUnderline.Name = 'AliasEditorUnderline'
    $aliasUnderline.Location = New-Object Drawing.Point(0, 25)
    $aliasUnderline.Size = New-Object Drawing.Size(318, 1)
    $aliasUnderline.BackColor = [Drawing.Color]::FromArgb(72,72,72)
    $editorFrame.Controls.Add($aliasUnderline)


    $clearAlias = New-Object System.Windows.Forms.Button
    $clearAlias.Name = 'AliasClearButton'
    $clearAlias.Text = '×'
    $clearAlias.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
    $clearAlias.ForeColor = [Drawing.Color]::FromArgb(145,145,145)
    $clearAlias.BackColor = [Drawing.Color]::FromArgb(24,24,24)
    $clearAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $clearAlias.FlatAppearance.BorderSize = 0
    $clearAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38,38,38)
    $clearAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(45,30,29)
    $clearAlias.Location = New-Object Drawing.Point(292, 0)
    $clearAlias.Size = New-Object Drawing.Size(26, 23)
    $clearAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $clearAlias.Visible = -not [string]::IsNullOrEmpty([string]$aliasEditor.Text)
    $clearAlias.Add_MouseEnter({ $this.ForeColor = $script:ColorAccent })
    $clearAlias.Add_MouseLeave({ $this.ForeColor = [Drawing.Color]::FromArgb(145,145,145) })
    $clearAlias.Add_Click({
        $editor = $this.Parent.Controls.Find('AliasEditor', $false) | Select-Object -First 1
        if ($editor) {
            $editor.Text = ''
            $editor.Focus()
        }
    })
    $editorFrame.Controls.Add($clearAlias)

    $aliasEditor.Add_Enter({
        param($sender,$eventArgs)
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = $script:ColorAccent }
        } catch { }
    })
    $aliasEditor.Add_Leave({
        param($sender,$eventArgs)
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = [Drawing.Color]::FromArgb(72,72,72) }
        } catch { }
    })
    $aliasEditor.Add_TextChanged({
        param($sender,$eventArgs)
        try {
            $clear = $sender.Parent.Controls.Find('AliasClearButton', $false) | Select-Object -First 1
            if ($clear) { $clear.Visible = -not [string]::IsNullOrEmpty([string]$sender.Text) }
            Update-ManageSaveButtonState
        } catch { }
    })
    $aliasEditor.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            Set-ManageEntryAliasDraft -Guid ([string]$sender.Tag) -Alias ([string]$sender.Text)
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ([string]::IsNullOrWhiteSpace([string]$sender.Text)) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            $eventArgs.SuppressKeyPress = $true
            Update-PopupRows
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
            $eventArgs.SuppressKeyPress = $true
            Update-PopupRows
        }
    })
    $editorFrame.Controls.Add($aliasEditor)
    $row.Controls.Add($editorFrame)

    $applyAlias = New-Object System.Windows.Forms.Button
    $applyAlias.Name = 'AliasApplyButton'
    $applyAlias.Text = Get-LocalizedString -Key 'Common.Apply'
    $applyAlias.Tag = $entry.Guid
    $applyAlias.Font = New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Bold)
    $applyAlias.ForeColor = $script:ColorAccent
    $applyAlias.BackColor = $script:ColorRow
    $applyAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyAlias.FlatAppearance.BorderSize = 0
    $applyAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $applyAlias.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $applyAlias.Location = New-Object Drawing.Point(58, 62)
    $applyAlias.Size = New-Object Drawing.Size(104, 24)
    $applyAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $applyAlias.Add_Click({
        param($sender,$eventArgs)
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor) {
            Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
            $empty = [string]::IsNullOrWhiteSpace([string]$editor.Text)
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ($empty) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            Update-PopupRows
        }
    })
    $row.Controls.Add($applyAlias)

    $cancelAlias = New-Object System.Windows.Forms.Button
    $cancelAlias.Name = 'AliasCancelButton'
    $cancelAlias.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelAlias.Font = New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Regular)
    $cancelAlias.ForeColor = $script:ColorSecondary
    $cancelAlias.BackColor = $script:ColorRow
    $cancelAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelAlias.FlatAppearance.BorderSize = 0
    $cancelAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $cancelAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelAlias.Location = New-Object Drawing.Point(166, 62)
    $cancelAlias.Size = New-Object Drawing.Size(94, 24)
    $cancelAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelAlias.Add_Click({
        $script:ManageAliasEditGuid = $null
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
        Update-PopupRows
    })
    $row.Controls.Add($cancelAlias)

    $originalHint = New-Label -Text (Get-LocalizedString -Key 'Manage.OriginalNameHint') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(125,125,125)) -X 266 -Y 65 -Width 110 -Height 18
    $originalHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $row.Controls.Add($originalHint)
}

function Add-ManageBootEntryControls {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][bool]$IsHidden,
        [Parameter(Mandatory=$true)]$Marker,
        [Parameter(Mandatory=$true)]$Icon,
        [Parameter(Mandatory=$true)]$Title,
        $Subtitle
    )
$state = New-Object System.Windows.Forms.Panel
$state.Name = 'VisibilityGlyph'
$state.Tag = $entry.Guid
$state.AccessibleName = if ($isHidden) { 'hidden' } else { 'visible' }
$state.AccessibleDescription = if ($isHidden) { Get-LocalizedString -Key 'Manage.HiddenAccessible' } else { Get-LocalizedString -Key 'Manage.VisibleAccessible' }
$state.Location = New-Object Drawing.Point(286, 12)
$state.Size = New-Object Drawing.Size(32, 34)
$state.BackColor = [Drawing.Color]::Transparent
$state.Cursor = [System.Windows.Forms.Cursors]::Hand
$state.AllowDrop = $true
$state.Add_Paint({
    param($sender,$eventArgs)
    $hidden = ([string]$sender.AccessibleName -eq 'hidden')
    $color = if ($hidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen($color, 1.6)
    $pupil = New-Object Drawing.SolidBrush($color)
    try {
        $eye = New-Object Drawing.Rectangle(7, 11, 18, 11)
        $eventArgs.Graphics.DrawEllipse($pen, $eye)
        $eventArgs.Graphics.FillEllipse($pupil, 14, 14, 4, 4)
        if ($hidden) {
            $slash = New-Object Drawing.Pen($color, 1.8)
            try { $eventArgs.Graphics.DrawLine($slash, 6, 24, 26, 9) } finally { $slash.Dispose() }
        }
    }
    finally {
        $pen.Dispose()
        $pupil.Dispose()
    }
})
$state.Add_MouseEnter({
    param($sender,$eventArgs)
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$state.Add_MouseLeave({
    param($sender,$eventArgs)
    try { Hide-DarkActionTooltip } catch { }
})
$row.Controls.Add($state)

$editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 12.0, [Drawing.FontStyle]::Regular)) `
    -ForeColor ([Drawing.Color]::FromArgb(190,190,190)) -X 321 -Y 12 -Width 25 -Height 34
$editAlias.Name = 'AliasEditButton'
$editAlias.Tag = $entry.Guid
$editAlias.AccessibleDescription = Get-LocalizedString -Key 'Manage.EditAliasAccessible'
$editAlias.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$editAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
$editAlias.Add_MouseEnter({
    param($sender,$eventArgs)
    $sender.ForeColor = $script:ColorAccent
    Set-RowHoverState $sender $true
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$editAlias.Add_MouseLeave({
    param($sender,$eventArgs)
    $sender.ForeColor = [Drawing.Color]::FromArgb(190,190,190)
    Set-RowHoverState $sender $false
    try { Hide-DarkActionTooltip } catch { }
})
$editAlias.Add_Click({
    param($sender,$eventArgs)
    try { Hide-DarkActionTooltip } catch { }
    $guid = ([string]$sender.Tag).ToLowerInvariant()
    if ($script:ManageAliasEditGuid -and $script:ManageAliasEditGuid -ne $guid) {
        Commit-ActiveManageAliasEditor
    }
    $script:ManageAliasEditGuid = $guid
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.EditAliasStatus'
    Update-PopupRows
    $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($editor) {
        $editor.Focus()
        $editor.SelectAll()
    }
})
$row.Controls.Add($editAlias)

$grip = New-Label -Text '≡' -Font (New-Object Drawing.Font('Segoe UI Symbol', 13, [Drawing.FontStyle]::Regular)) `
    -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 350 -Y 12 -Width 26 -Height 34
$grip.Tag = $entry.Guid
$grip.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$grip.AllowDrop = $true
$row.Controls.Add($grip)

return @($row, $marker, $icon, $title, $subtitle, $state, $grip)
}

function Add-NormalBootEntryControls {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][bool]$IsSelected,
        [Parameter(Mandatory=$true)]$Marker,
        [Parameter(Mandatory=$true)]$Icon,
        [Parameter(Mandatory=$true)]$Title,
        $Subtitle
    )

    $checkText = if ($isSelected) { '✓' } else { '' }
    $check = New-Label -Text $checkText `
        -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 354 -Y 12 -Width 24 -Height 34
    $check.Tag = $entry.Guid
    $check.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $check.Cursor = [System.Windows.Forms.Cursors]::Hand
    $row.Controls.Add($check)
    return @($row, $marker, $icon, $title, $subtitle, $check)
}

function Connect-BootEntryRowInteractions {
    param(
        [Parameter(Mandatory=$true)][object[]]$RowControls,
        [Parameter(Mandatory=$true)]$Handlers
    )

    $clickHandler = $Handlers.Click
    $enterHandler = $Handlers.Enter
    $leaveHandler = $Handlers.Leave
    $wheelHandler = $Handlers.Wheel
    $mouseDownHandler = $Handlers.MouseDown
    $mouseMoveHandler = $Handlers.MouseMove
    $dragEnterHandler = $Handlers.DragEnter
    $dragDropHandler = $Handlers.DragDrop

foreach ($control in $RowControls) {
    $control.Add_Click($clickHandler)
    $control.Add_MouseEnter($enterHandler)
    $control.Add_MouseLeave($leaveHandler)
    $control.Add_MouseWheel($wheelHandler)
    if ($script:IsManageEntriesMode) {
        $control.Add_MouseDown($mouseDownHandler)
        $control.Add_MouseMove($mouseMoveHandler)
        $control.Add_DragEnter($dragEnterHandler)
        $control.Add_DragDrop($dragDropHandler)
    }
}
}

function New-BootEntryRow {
    param(
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][int]$Y,
        [Parameter(Mandatory=$true)][int]$BaseRowHeight,
        [Parameter(Mandatory=$true)]$Handlers
    )

$guidNormalized = ([string]$entry.Guid).ToLowerInvariant()
$aliasEditActive = $script:IsManageEntriesMode -and $script:ManageAliasEditGuid -and ($guidNormalized -eq $script:ManageAliasEditGuid)
$rowHeight = if ($aliasEditActive) { 92 } else { $baseRowHeight }

$row = New-Object System.Windows.Forms.Panel
$row.Name = 'BootRow'
$row.Tag = $entry.Guid
$row.Location = New-Object Drawing.Point(0, $y)
$row.Size = New-Object Drawing.Size(390, $rowHeight)
$row.BackColor = $script:ColorRow
$row.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$row.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)

$isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
$isSelected = (-not $script:IsManageEntriesMode) -and $script:SelectedGuid -and ($entry.Guid -eq $script:SelectedGuid)
if ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

$marker = New-Object System.Windows.Forms.Panel
$marker.Location = New-Object Drawing.Point(0, 0)
$marker.Size = New-Object Drawing.Size(3, $rowHeight)
$marker.BackColor = $script:ColorRow
if ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
elseif ($isHidden) { $marker.BackColor = [Drawing.Color]::FromArgb(70,70,70) }
$marker.Tag = $entry.Guid
$marker.AllowDrop = $script:IsManageEntriesMode
$row.Controls.Add($marker)

$iconColor = if ($isHidden) { [Drawing.Color]::FromArgb(105,105,105) } else { $entry.Accent }
$titleColor = if ($isHidden) { [Drawing.Color]::FromArgb(145,145,145) } else { $script:ColorPrimary }
$subtitleColor = if ($isHidden) { [Drawing.Color]::FromArgb(100,100,100) } else { $script:ColorSecondary }

$icon = New-Label -Text $entry.Symbol -Font (New-Object Drawing.Font('Segoe UI Symbol', 18, [Drawing.FontStyle]::Regular)) `
    -ForeColor $iconColor -X 22 -Y 7 -Width 28 -Height 44
$icon.Tag = $entry.Guid
$icon.Cursor = [System.Windows.Forms.Cursors]::Hand
$icon.AllowDrop = $script:IsManageEntriesMode
if ($script:BootTypeToolTip -and $entry.TypeTooltip) {
    $icon.AccessibleDescription = [string]$entry.TypeTooltip
    $script:BootTypeToolTip.SetToolTip($icon, [string]$entry.TypeTooltip)
    # Native SetToolTip proved unreliable on the transparent symbol label
    # on the target PC. MouseHover explicitly shows the same tooltip and
    # MouseLeave closes it, while the semantic text remains on the circle only.
    $icon.Add_MouseHover({
        param($sender, $eventArgs)
        try {
            $text = [string]$sender.AccessibleDescription
            if ($text) { $script:BootTypeToolTip.Show($text, $sender, 18, [Math]::Max(18, $sender.Height - 2), 8000) }
        } catch { }
    })
    $icon.Add_MouseLeave({ param($sender, $eventArgs) try { $script:BootTypeToolTip.Hide($sender) } catch { } })
}
$row.Controls.Add($icon)

$alias = if ($script:IsManageEntriesMode) {
    Get-EntryAlias -Guid ([string]$entry.Guid) -UseManageDraft
}
else {
    Get-EntryAlias -Guid ([string]$entry.Guid)
}
$displayTitle = if ($script:IsManageEntriesMode) {
    Get-EntryDisplayTitle -Entry $entry -UseManageDraft
}
else {
    Get-EntryDisplayTitle -Entry $entry
}

$titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
$titleText = if ($aliasEditActive) { [string]$entry.Title } else { $displayTitle }
$title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
    -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
$title.Tag = $entry.Guid
$title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
$row.Controls.Add($title)

$subtitle = $null
if (-not $aliasEditActive) {
    $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
    $subtitleText = if ($script:IsManageEntriesMode -and $alias) {
        Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name=[string]$entry.Title }
    }
    elseif ($script:IsManageEntriesMode -and ([string]$entry.RawDescription -eq 'Boot Menu')) {
        Get-LocalizedString -Key 'Boot.MenuManageSubtitle'
    }
    else {
        [string]$entry.Subtitle
    }
    $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 8.3, [Drawing.FontStyle]::Regular)) `
        -ForeColor $subtitleColor -X 58 -Y 27 -Width $subtitleWidth -Height 27
    $subtitle.AutoEllipsis = $false
    $subtitle.Tag = $entry.Guid
    $subtitle.Cursor = [System.Windows.Forms.Cursors]::Hand
    $subtitle.AllowDrop = $script:IsManageEntriesMode
    $row.Controls.Add($subtitle)
}

    if ($script:IsManageEntriesMode) {
        if ($aliasEditActive) {
            Add-BootEntryAliasEditor -Row $row -Entry $entry -Alias $alias
            $rowControls = @()
        }
        else {
            $rowControls = @(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden ([bool]$isHidden) -Marker $marker -Icon $icon -Title $title -Subtitle $subtitle)
        }
    }
    else {
        $rowControls = @(Add-NormalBootEntryControls -Row $row -Entry $entry -IsSelected ([bool]$isSelected) -Marker $marker -Icon $icon -Title $title -Subtitle $subtitle)
    }

    if ($rowControls.Count -gt 0) {
        Connect-BootEntryRowInteractions -RowControls $rowControls -Handlers $Handlers
    }

    return [pscustomobject]@{
        Row = $row
        Height = $rowHeight
    }
}

function Update-BootEntryScrollLayout {
    param(
        [Parameter(Mandatory=$true)]$ListPanel,
        [Parameter(Mandatory=$true)]$ContentPanel,
        $ScrollBar,
        [Parameter(Mandatory=$true)][int]$ContentBottom,
        [Parameter(Mandatory=$true)][int]$BaseRowHeight,
        [Parameter(Mandatory=$true)][int]$RowGap
    )

$viewportHeight = $ListPanel.ClientSize.Height
$contentHeight = [Math]::Max($viewportHeight, $ContentBottom)
$ContentPanel.Size = New-Object Drawing.Size(390, $contentHeight)
if ($ScrollBar) {
    $maxScroll = [Math]::Max(0, $contentHeight - $viewportHeight)
    $ScrollBar.LargeChange = [Math]::Max(1, $viewportHeight)
    $ScrollBar.SmallChange = $BaseRowHeight + $RowGap
    $ScrollBar.Maximum = $maxScroll
    $ScrollBar.Visible = ($maxScroll -gt 0)
    if (-not $ScrollBar.Visible) { $ScrollBar.Value = 0 }
    elseif ($ScrollBar.Value -gt $maxScroll) { $ScrollBar.Value = $maxScroll }
    $ContentPanel.Top = -1 * $ScrollBar.Value
}
}
