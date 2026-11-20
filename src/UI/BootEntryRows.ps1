# Lenovo Boot Selector - boot-entry row presentation helpers.
# LBS-29 separates row rendering and interaction responsibilities from list refresh orchestration.


# LBS-163: shared candidate resolver for preview and committed drop.
function Get-ManageDropDecision {
    param($Control,[Drawing.Point]$ScreenPoint,[string]$MovedGuid)
    if (-not $script:IsManageEntriesMode -or -not $MovedGuid) { return $null }
    $moved = $MovedGuid.ToLowerInvariant()
    $order = @($script:ManageEntryOrder | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $originalIndex = [array]::IndexOf($order,$moved)
    if ($originalIndex -lt 0) { return $null }

    $target = ''
    $after = $false
    # During live reflow the physical rows move. Resolve pointer coordinates
    # against immutable drag-start slots, never against their animated bounds.
    if ($script:ManageDragLayout -and $script:ManageDragContent -and -not $script:ManageDragContent.IsDisposed) {
        $point = $script:ManageDragContent.PointToClient($ScreenPoint)
        $slots = @($script:ManageDragLayout)
        if ($slots.Count -eq 0 -or $point.X -lt 0 -or $point.X -ge $script:ManageDragContent.ClientSize.Width) { return $null }
        if ($point.Y -lt $slots[0].Top -or $point.Y -ge ($slots[$slots.Count-1].Top + $slots[$slots.Count-1].Height)) { return $null }
        foreach ($slot in $slots) {
            $edge = $slot.Top + $slot.Height + [Math]::Floor($script:ManageDragRowGap / 2.0)
            if ($point.Y -lt $edge) {
                $target = $slot.Guid
                $after = ($point.Y -gt ($slot.Top + $slot.Height / 2.0))
                break
            }
        }
        if (-not $target) {
            $target = $slots[$slots.Count-1].Guid
            $after = $true
        }
    }
    else {
        $row = Get-BootRowFromControl $Control
        if (-not $row -or $row.IsDisposed -or -not $row.Parent -or $row.Parent.Name -ne 'EntryContent') { return $null }
        $point = $row.PointToClient($ScreenPoint)
        if ($point.X -lt 0 -or $point.X -ge $row.Width -or $point.Y -lt 0 -or $point.Y -ge $row.Height) { return $null }
        $target = ([string]$row.Tag).ToLowerInvariant()
        $after = ($point.Y -gt ($row.Height / 2.0))
    }
    $remaining = @($order | Where-Object { $_ -ne $moved })
    $targetIndex = [array]::IndexOf($remaining,$target)
    if (-not $target -or $target -eq $moved -or $targetIndex -lt 0) { return $null }
    $index = $targetIndex + $(if ($after) { 1 } else { 0 })
    if ($index -eq $originalIndex) { return $null }
    return [pscustomobject]@{ MovedGuid=$moved; TargetGuid=$target; After=[bool]$after; InsertIndex=[int]$index }
}
# LBS-163 iteration 2: animate existing WinForms rows; no rows are rebuilt in a drag.
# Slots are captured once, so the pointer decision never depends on animation frames.
function Start-ManageDragReflow {
    param($SourceRow)
    if (-not $SourceRow -or -not $SourceRow.Parent -or -not $script:IsManageEntriesMode) { return }
    Stop-ManageDragReflow
    $content = $SourceRow.Parent
    $rows = @($content.Controls | Where-Object { $_.Name -eq 'BootRow' } | Sort-Object Top)
    $slots = @()
    foreach ($row in $rows) {
        $slots += [pscustomobject]@{
            Guid=([string]$row.Tag).ToLowerInvariant()
            Row=$row
            Top=[int]$row.Top
            Height=[int]$row.Height
        }
    }
    if ($slots.Count -lt 2) { return }
    $script:ManageDragContent = $content
    $script:ManageDragLayout = $slots
    $script:ManageDragRowGap = [Math]::Max(0,$slots[1].Top - ($slots[0].Top+$slots[0].Height))
    $script:ManageDragRow = $SourceRow
    $script:ManageDragOriginalColor = $SourceRow.BackColor
    $grab = $SourceRow.PointToClient([System.Windows.Forms.Control]::MousePosition)
    $script:ManageDragGrabY = [Math]::Max(0,[Math]::Min($SourceRow.Height-1,$grab.Y))
    $shadow = New-Object System.Windows.Forms.Panel
    $shadow.Name = 'ManageDragShadow'
    $shadow.Size = $SourceRow.Size
    $shadow.BackColor = [Drawing.Color]::FromArgb(12,12,16)
    $shadow.Enabled = $false
    $content.Controls.Add($shadow)
    $script:ManageDragShadow = $shadow
    $placeholder = New-Object System.Windows.Forms.Panel
    $placeholder.Name = 'ManageDragPlaceholder'
    $placeholder.Size = $SourceRow.Size
    $placeholder.BackColor = [Drawing.Color]::FromArgb(34,36,41)
    $placeholder.Enabled = $false
    $placeholder.Visible = $false
    $placeholder.Add_Paint({
        param($sender,$eventArgs)
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(83,88,98),1.0)
        $pen.DashStyle = [Drawing.Drawing2D.DashStyle]::Dash
        try { $eventArgs.Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$sender.Width-3),[Math]::Max(1,$sender.Height-3)) }
        finally { $pen.Dispose() }
    })
    $content.Controls.Add($placeholder)
    $placeholder.SendToBack()
    $script:ManageDragPlaceholder = $placeholder
    $shadow.BringToFront()
    $SourceRow.BringToFront()
    $SourceRow.BackColor = [Drawing.Color]::FromArgb(48,48,54)
    $SourceRow.Invalidate($true)
    $script:ManageDragTargets = @{}
    $script:ManageDragStarts = @{}
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $timer.Add_Tick({ Advance-ManageDragReflow })
    $script:ManageDragTimer = $timer
    Set-ManageDragReflowTargets -Decision $null
    Set-ManageDragFloatLocation -ScreenPoint ([System.Windows.Forms.Control]::MousePosition)
}

function Set-ManageDragFloatLocation {
    param([Drawing.Point]$ScreenPoint)
    if (-not $script:ManageDragRow -or $script:ManageDragRow.IsDisposed -or
        -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    $point = $script:ManageDragContent.PointToClient($ScreenPoint)
    $y = [int]($point.Y - $script:ManageDragGrabY)
    if ($script:ManageDragRow.Top -ne $y) { $script:ManageDragRow.Top = $y }
    if ($script:ManageDragShadow -and -not $script:ManageDragShadow.IsDisposed) {
        $script:ManageDragShadow.Location = [Drawing.Point]::new($script:ManageDragRow.Left+4,$y+5)
    }
}

function Set-ManageDragReflowTargets {
    param($Decision)
    if (-not $script:ManageDragLayout) { return }
    $slots = @($script:ManageDragLayout)
    $moved = ([string]$script:ManageActiveDragGuid).ToLowerInvariant()
    $sequence = New-Object System.Collections.ArrayList
    foreach ($slot in $slots) {
        if ($slot.Guid -ne $moved) { [void]$sequence.Add($slot.Guid) }
    }
    if ($Decision) {
        $index = [Math]::Max(0,[Math]::Min($sequence.Count,[int]$Decision.InsertIndex))
        $sequence.Insert($index,$moved)
    }
    else {
        $original = [array]::IndexOf(@($slots | ForEach-Object { $_.Guid }),$moved)
        $sequence.Insert([Math]::Max(0,$original),$moved)
    }
    $targets = @{}
    $y = [int]$slots[0].Top
    foreach ($guid in $sequence) {
        $slot = $slots | Where-Object { $_.Guid -eq $guid } | Select-Object -First 1
        $targets[$guid] = $y
        $y += $slot.Height + $script:ManageDragRowGap
    }
    $script:ManageDragStarts = @{}
    foreach ($slot in $slots) {
        if ($slot.Guid -ne $moved -and -not $slot.Row.IsDisposed) {
            $script:ManageDragStarts[$slot.Guid] = [int]$slot.Row.Top
        }
    }
    $script:ManageDragTargets = $targets
    if ($script:ManageDragPlaceholder -and -not $script:ManageDragPlaceholder.IsDisposed) {
        $script:ManageDragPlaceholder.Top = [int]$targets[$moved]
        $script:ManageDragPlaceholder.Visible = ($null -ne $Decision)
        $script:ManageDragPlaceholder.SendToBack()
    }
    $script:ManageDragAnimationStartUtc = [datetime]::UtcNow
    if ($script:ManageDragTimer) { $script:ManageDragTimer.Start() }
}

function Advance-ManageDragReflow {
    param([double]$Progress = -1)
    if (-not $script:ManageDragLayout -or -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    $t = if ($Progress -ge 0) { [Math]::Min(1.0,[Math]::Max(0.0,$Progress)) }
         else { [Math]::Min(1.0,([datetime]::UtcNow-$script:ManageDragAnimationStartUtc).TotalMilliseconds/150.0) }
    $ease = 1.0 - [Math]::Pow(1.0-$t,3.0)
    $script:ManageDragContent.SuspendLayout()
    try {
        foreach ($slot in @($script:ManageDragLayout)) {
            if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
            $start = [int]$script:ManageDragStarts[$slot.Guid]
            $target = [int]$script:ManageDragTargets[$slot.Guid]
            $top = [int][Math]::Round($start + (($target-$start)*$ease))
            if ($slot.Row.Top -ne $top) { $slot.Row.Top = $top }
        }
    }
    finally { $script:ManageDragContent.ResumeLayout($false) }
    if ($t -ge 1.0 -and $script:ManageDragTimer) { $script:ManageDragTimer.Stop() }
}

function Stop-ManageDragReflow {
    param([switch]$KeepPositions)
    if ($script:ManageDragPlaceholder) {
        if (-not $script:ManageDragPlaceholder.IsDisposed) {
            if ($script:ManageDragPlaceholder.Parent) { $script:ManageDragPlaceholder.Parent.Controls.Remove($script:ManageDragPlaceholder) }
            $script:ManageDragPlaceholder.Dispose()
        }
        $script:ManageDragPlaceholder = $null
    }
    if ($script:ManageDragTimer) {
        $script:ManageDragTimer.Stop()
        $script:ManageDragTimer.Dispose()
        $script:ManageDragTimer = $null
    }
    if ($script:ManageDragShadow) {
        if (-not $script:ManageDragShadow.IsDisposed) {
            if ($script:ManageDragShadow.Parent) { $script:ManageDragShadow.Parent.Controls.Remove($script:ManageDragShadow) }
            $script:ManageDragShadow.Dispose()
        }
        $script:ManageDragShadow = $null
    }
    if ($script:ManageDragLayout -and -not $KeepPositions) {
        foreach ($slot in @($script:ManageDragLayout)) {
            if (-not $slot.Row.IsDisposed) { $slot.Row.Top = [int]$slot.Top }
        }
    }
    if ($script:ManageDragRow -and -not $script:ManageDragRow.IsDisposed) {
        $script:ManageDragRow.BackColor = $script:ManageDragOriginalColor
        $script:ManageDragRow.Invalidate($true)
    }
    $script:ManageDragLayout = $null
    $script:ManageDragContent = $null
    $script:ManageDragRow = $null
    $script:ManageDragTargets = $null
    $script:ManageDragStarts = $null
    $script:ManageDragOriginalColor = $null
    $script:ManageDragRowGap = 0
    $script:ManageDragGrabY = 0
}

function Set-ManageDropPreview {
    param($Decision)
    $prior = $script:ManageDropPreview
    if ($prior -and $Decision -and $prior.TargetGuid -eq $Decision.TargetGuid -and $prior.After -eq $Decision.After) { return }
    if (-not $prior -and -not $Decision) { return }
    $script:ManageDropPreview = $Decision
    if ($script:ManageDragLayout) { Set-ManageDragReflowTargets -Decision $Decision; return }
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) {
        if (($prior -and [string]$row.Tag -eq $prior.TargetGuid) -or
            ($Decision -and [string]$row.Tag -eq $Decision.TargetGuid)) { $row.Invalidate() }
    }
}
function Reset-ManageDragPreview {
    param([switch]$KeepPositions)
    Stop-ManageDragReflow -KeepPositions:$KeepPositions
    Set-ManageDropPreview -Decision $null
    $script:ManageActiveDragGuid = $null
    $script:ManageDragGuid = $null
    if ($script:Popup -and -not $script:Popup.IsDisposed) {
        foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) { $row.Invalidate() }
    }
    # Apply a real firmware/label change once DoDragDrop has released its rows.
    if ($script:PopupRowsRefreshPending -or $script:PopupRowsViewportPending) {
        Update-PopupRows -Reason 'drag-ended'
    }
}
# Lightweight row-painted cue: no extra WinForms controls intercept pointer events.
function Paint-ManageDropCue {
    param($Row,$Graphics)
    if (-not $script:IsManageEntriesMode) { return }
    $guid = ([string]$Row.Tag).ToLowerInvariant()
    if ($script:ManageActiveDragGuid -and $guid -eq $script:ManageActiveDragGuid) {
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(155,155,155),1.0)
        try { $Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$Row.Width-3),[Math]::Max(1,$Row.Height-3)) }
        finally { $pen.Dispose() }
    }
    if ($script:ManageDragLayout) { return } # Full-height gap replaces the old red line.
    $cue = $script:ManageDropPreview
    if (-not $cue -or $cue.TargetGuid -ne $guid) { return }
    $thickness = [Math]::Max(3,[int][Math]::Round($Row.Height/20.0))
    $y = if ($cue.After) { $Row.Height-$thickness } else { 0 }
    $brush = New-Object Drawing.SolidBrush($script:ColorAccent)
    try {
        $Graphics.FillRectangle($brush,0,$y,$Row.Width,$thickness)
        $Graphics.FillRectangle($brush,0,[Math]::Max(0,$y-$thickness),[Math]::Max(6,$thickness*2),[Math]::Min($Row.Height,$thickness*3))
    }
    finally { $brush.Dispose() }
}

function New-BootEntryInteractionHandlers {
    $clickHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode) {
            $capabilities = Get-CurrentSystemFunctionsCapabilities
            if (-not $capabilities.CanManageEntries) { return }
        }
        # BootNext controller owns both Ready and cold-start Checking admission.
        # Do not silently discard the first click before pending feedback.
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
            Start-BootNextSelection -Guid $guid
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
        $script:ManageActiveDragGuid = ([string]$guid).ToLowerInvariant()
        $sourceRow = Get-BootRowFromControl $sender
        if ($sourceRow) { Start-ManageDragReflow -SourceRow $sourceRow }
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) }
        catch { }
        finally { Reset-ManageDragPreview }
    }
    $dragOverHandler = {
        param($sender,$eventArgs)
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Set-ManageDropPreview -Decision $null; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Set-ManageDropPreview -Decision $null; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        Set-ManageDropPreview -Decision $decision
        if ($script:ManageDragLayout) { Set-ManageDragFloatLocation -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) }
        if ($decision) { $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move }
    }
    $dragEnterHandler = $dragOverHandler
    $dragLeaveHandler = {
        param($sender,$eventArgs)
        if (-not $script:Popup -or $script:Popup.IsDisposed) { Reset-ManageDragPreview; return }
        $matches = @($script:Popup.Controls.Find('EntryList',$true))
        if ($matches.Count -eq 0) { Set-ManageDropPreview -Decision $null; return }
        $point = $matches[0].PointToClient([System.Windows.Forms.Control]::MousePosition)
        if (-not $matches[0].ClientRectangle.Contains($point)) { Set-ManageDropPreview -Decision $null }
    }
    $dragDropHandler = {
        param($sender,$eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Reset-ManageDragPreview; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Reset-ManageDragPreview; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        if (-not $decision) { Reset-ManageDragPreview; return }
        $movedGuid = $decision.MovedGuid
        $targetRow = $null
        if ($script:ManageDragLayout) {
            $targetSlot = $script:ManageDragLayout | Where-Object { $_.Guid -eq $decision.TargetGuid } | Select-Object -First 1
            if ($targetSlot) { $targetRow = $targetSlot.Row }
        }
        else {
            $targetRow = Get-BootRowFromControl $sender
        }
        if (-not $targetRow -or $targetRow.IsDisposed -or ([string]$targetRow.Tag).ToLowerInvariant() -ne $decision.TargetGuid) {
            Reset-ManageDragPreview
            return
        }
        $after = $decision.After
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
        # The rows already occupy their preview positions; do not briefly snap
        # them back to the obsolete order before the committed render.
        Reset-ManageDragPreview -KeepPositions
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
        DragOver = $dragOverHandler
        DragLeave = $dragLeaveHandler
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

# LBS-144: calculate visibility-eye paint geometry from the graphics surface
# DPI, not from fixed pixels. The popup already scales the 32x34 design
# hit target; keep that unchanged and derive a single-scale glyph.
function Get-LenovoManageEyeGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Visibility glyph requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $eyeWidth = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(20.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $eyeHeight = [Math]::Min(
        [Math]::Max(1,$ClientSize.Height - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $left = [int][Math]::Floor(($ClientSize.Width - $eyeWidth) / 2.0)
    $top = [int][Math]::Floor(($ClientSize.Height - $eyeHeight) / 2.0)
    $eye = [Drawing.Rectangle]::new($left,$top,$eyeWidth,$eyeHeight)
    $pupilSide = [Math]::Min(
        [Math]::Max(1,$eyeHeight - 2),
        [Math]::Max(1,[int][Math]::Round(5.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $pupilSide = [Math]::Min($pupilSide,$eyeWidth)
    $pupil = [Drawing.Rectangle]::new(
        $left + [int][Math]::Floor(($eyeWidth - $pupilSide) / 2.0),
        $top + [int][Math]::Floor(($eyeHeight - $pupilSide) / 2.0),
        $pupilSide,$pupilSide)
    $extension = [Math]::Max(1,[int][Math]::Round(1.0 * $scale,[MidpointRounding]::AwayFromZero))
    return [pscustomobject]@{
        Eye = $eye
        Pupil = $pupil
        SlashStart = [Drawing.Point]::new(
            [Math]::Max(0,$eye.Left - $extension),
            [Math]::Min($ClientSize.Height-1,$eye.Bottom + $extension))
        SlashEnd = [Drawing.Point]::new(
            [Math]::Min($ClientSize.Width-1,$eye.Right + $extension),
            [Math]::Max(0,$eye.Top - $extension))
        Stroke = [single](1.6 * $scale)
        SlashStroke = [single](1.8 * $scale)
    }
}

# LBS-166: draw the reorder affordance at paint-surface DPI, not font size.
# Preserve its existing 26x34 design-unit hit area.
function Get-LenovoManageGripGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Reorder grip requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $width = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(18.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $stroke = [single][Math]::Min(2.4 * $scale,[double]$width)
    $span = [Math]::Min(
        [Math]::Max(0,$ClientSize.Height - 2 * $margin - [int][Math]::Ceiling($stroke)),
        [Math]::Max(0,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $centerX = ($ClientSize.Width - 1) / 2.0
    $centerY = ($ClientSize.Height - 1) / 2.0
    $halfLine = ($width - $stroke) / 2.0
    return [pscustomobject]@{
        Width = [int]$width
        Span = [int]$span
        Stroke = [single]$stroke
        StartX = [single]($centerX - $halfLine)
        EndX = [single]($centerX + $halfLine)
        TopY = [single]($centerY - $span / 2.0)
        MiddleY = [single]$centerY
        BottomY = [single]($centerY + $span / 2.0)
    }
}

function Paint-LenovoManageGripGlyph {
    param(
        [Parameter(Mandatory=$true)][Drawing.Graphics]$Graphics,
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][Drawing.Color]$Color
    )
    $geometry = Get-LenovoManageGripGlyphGeometry -ClientSize $ClientSize -Dpi $Graphics.DpiX
    $smoothing = $Graphics.SmoothingMode
    $pen = New-Object Drawing.Pen($Color,$geometry.Stroke)
    try {
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        foreach ($y in @($geometry.TopY,$geometry.MiddleY,$geometry.BottomY)) {
            $Graphics.DrawLine($pen,$geometry.StartX,[single]$y,$geometry.EndX,[single]$y)
        }
    }
    finally {
        $Graphics.SmoothingMode = $smoothing
        $pen.Dispose()
    }
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
    $geometry = Get-LenovoManageEyeGlyphGeometry -ClientSize $sender.ClientSize -Dpi $eventArgs.Graphics.DpiX
    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen($color, $geometry.Stroke)
    $pupil = New-Object Drawing.SolidBrush($color)
    try {
        $eventArgs.Graphics.DrawEllipse($pen, $geometry.Eye)
        $eventArgs.Graphics.FillEllipse($pupil, $geometry.Pupil)
        if ($hidden) {
            $slash = New-Object Drawing.Pen($color, $geometry.SlashStroke)
            try {
                $eventArgs.Graphics.DrawLine($slash, $geometry.SlashStart, $geometry.SlashEnd)
            } finally { $slash.Dispose() }
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

$editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 14.0, [Drawing.FontStyle]::Regular)) `
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

$grip = New-Object System.Windows.Forms.Panel
$grip.Name = 'ManageReorderGrip'
$grip.Tag = $entry.Guid
$grip.Location = New-Object Drawing.Point(350, 12)
$grip.Size = New-Object Drawing.Size(26, 34)
$grip.BackColor = [Drawing.Color]::Transparent
$grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$grip.AllowDrop = $true
$grip.Add_Paint({
    param($sender,$eventArgs)
    Paint-LenovoManageGripGlyph -Graphics $eventArgs.Graphics -ClientSize $sender.ClientSize -Color ([Drawing.Color]::FromArgb(145,145,145))
})
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

    $checkText = if ($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid)) { '…' } elseif ($isSelected) { '✓' } else { '' }
    $check = New-Label -Text $checkText `
        -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
        -ForeColor $(if ($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid)) { $script:ColorWarning } else { $script:ColorAccent }) -X 354 -Y 12 -Width 24 -Height 34
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
    $dragOverHandler = $Handlers.DragOver
    $dragLeaveHandler = $Handlers.DragLeave
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
        $control.Add_DragOver($dragOverHandler)
        $control.Add_DragLeave($dragLeaveHandler)
        $control.Add_DragDrop($dragDropHandler)
    }
}
}

# Initial construction and metadata-only refresh share one text/locale rule.
function Get-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Entry)
    $manage = [bool]$script:IsManageEntriesMode
    $guid = ([string]$Entry.Guid).ToLowerInvariant()
    $alias = Get-EntryAlias -Guid $guid -UseManageDraft:$manage
    $displayTitle = Get-EntryDisplayTitle -Entry $Entry -UseManageDraft:$manage
    $editing = $manage -and $script:ManageAliasEditGuid -and $guid -eq $script:ManageAliasEditGuid
    $pending = -not $manage -and (Resolve-BootNextRowDisplayCore -EntryGuid $guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid) -eq 'pending'
    $titleText = if ($editing) { [string]$Entry.Title } else { [string]$displayTitle }
    $subtitleText = if ($editing) { '' }
        elseif ($manage -and $alias) { Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name=[string]$Entry.Title } }
        elseif ($manage -and ([string]$Entry.RawDescription -eq 'Boot Menu')) { Get-LocalizedString -Key 'Boot.MenuManageSubtitle' }
        elseif ($pending) { Get-LocalizedString -Key 'BootNext.SelectionPending' }
        else { [string]$Entry.Subtitle }
    return [pscustomobject]@{ Title = [string]$titleText; Subtitle = [string]$subtitleText }
}

# The caller must first prove GUID/order/mode/DPI and structural-signature parity.
# Keep live WinForms controls, handlers and scroll context intact.
function Update-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Row,[Parameter(Mandatory=$true)]$Entry)
    $title = $Row.Controls['BootTitleLabel']
    $subtitle = $Row.Controls['BootSubtitleLabel']
    if (-not $title -or -not $subtitle -or $title.IsDisposed -or $subtitle.IsDisposed) {
        throw 'Metadata-only row update requires existing title and subtitle controls.'
    }
    $text = Get-BootEntryRowText -Entry $Entry
    $changed = $false
    if ([string]$title.Text -cne [string]$text.Title) {
        $title.Text = [string]$text.Title
        $title.AccessibleDescription = [string]$text.Title
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title,[string]$text.Title) }
        $changed = $true
    }
    if ([string]$subtitle.Text -cne [string]$text.Subtitle) {
        $subtitle.Text = [string]$text.Subtitle
        $subtitle.AccessibleDescription = [string]$text.Subtitle
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle,[string]$text.Subtitle) }
        $changed = $true
    }
    return [bool]$changed
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
if ($script:IsManageEntriesMode) { $row.Add_Paint({ param($sender,$eventArgs) Paint-ManageDropCue -Row $sender -Graphics $eventArgs.Graphics }) }

$isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
$rowDisplay = if ($script:IsManageEntriesMode) { 'idle' } else { Resolve-BootNextRowDisplayCore -EntryGuid $entry.Guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid }
$isSelected = ($rowDisplay -eq 'selected')
$isPending = ($rowDisplay -eq 'pending')
if ($isPending) { $row.BackColor = [Drawing.Color]::FromArgb(46,40,27) }
elseif ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

$marker = New-Object System.Windows.Forms.Panel
$marker.Location = New-Object Drawing.Point(0, 0)
$marker.Size = New-Object Drawing.Size(3, $rowHeight)
$marker.BackColor = $script:ColorRow
if ($isPending) { $marker.BackColor = $script:ColorWarning }
elseif ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
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
$rowText = Get-BootEntryRowText -Entry $entry
$titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
$titleText = [string]$rowText.Title
$title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
    -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
$title.Name = 'BootTitleLabel'
# At high DPI, WinForms AutoEllipsis can suppress the entire label if its
# vertical rectangle is considered insufficient. Keep text visible; the
# full name is also available in the tooltip and accessible description.
$title.AutoEllipsis = $false
$title.AccessibleDescription = [string]$titleText
if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title, [string]$titleText) }
$title.Tag = $entry.Guid
$title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
$row.Controls.Add($title)

$subtitle = $null
if (-not $aliasEditActive) {
    $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
    $subtitleText = [string]$rowText.Subtitle
    $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 8.3, [Drawing.FontStyle]::Regular)) `
        -ForeColor $subtitleColor -X 58 -Y 27 -Width $subtitleWidth -Height 27
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.AutoEllipsis = $false
    $subtitle.AccessibleDescription = [string]$subtitleText
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle, [string]$subtitleText) }
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
$ContentPanel.Size = New-Object Drawing.Size($ListPanel.ClientSize.Width, $contentHeight)
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
