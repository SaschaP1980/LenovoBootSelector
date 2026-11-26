# LBS-229: persistent-default selection deliberately uses a separate
# presentation row, never the normal BootNext row's action handler.
function Test-DefaultPickerInteraction {
    if ($script:IsManageEntriesMode -or $script:DefaultTargetChangePending -or $script:BootNextPendingGuid -or (Test-MaintenanceBusy) -or (Test-BootTargetDriftDetected)) { return $false }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    return [bool]([string]$capabilities.State -eq 'Ready' -and $capabilities.CanSetDefaultTarget)
}

function Get-DefaultPickerSnapshot {
    $guids = @(Get-OrderedEntriesForUi | ForEach-Object { [string]$_.Guid })
    return ('{0}|{1}|{2}' -f [string]$script:DefaultGuid,[bool]$script:DefaultTargetReadUncertain,($guids -join ','))
}

function Set-DefaultPickerHover {
    param([System.Windows.Forms.Control]$Control,[bool]$Hover)
    $row = $Control
    while ($row -and $row.Name -ne 'DefaultPickerRow') { $row = $row.Parent }
    if (-not $row) { return }
    if (-not $Hover -and $row.ClientRectangle.Contains($row.PointToClient([Windows.Forms.Cursor]::Position))) { return }
    $hot = $Hover -and $row.Enabled -and -not $script:DefaultTargetChangePending -and -not $script:BootNextPendingGuid
    $row.BackColor = if ($row.Tag.Selected) { $script:ColorSelectedRow } elseif ($hot) { $script:ColorHover } else { $script:ColorRow }
    $title=$row.Controls['DefaultPickerTitle']
    if ($title) { $title.ForeColor=if ($hot -and -not [Windows.Forms.SystemInformation]::HighContrast) { [LenovoInteractionPalette]::Hover } else { $script:ColorPrimary } }
}

function Invoke-DefaultPickerRow {
    param([System.Windows.Forms.Control]$Control)
    $row = $Control
    while ($row -and $row.Name -ne 'DefaultPickerRow') { $row = $row.Parent }
    if (-not $row -or -not $row.Enabled -or -not (Test-DefaultPickerInteraction)) { return }
    $form = $row.FindForm()
    if ($form.Tag.DefaultSnapshot -ne (Get-DefaultPickerSnapshot)) { $form.DialogResult = [Windows.Forms.DialogResult]::Cancel; return }
    $form.Tag.Choice = [pscustomobject]@{ Guid=$row.Tag.Guid }
    $form.DialogResult = [Windows.Forms.DialogResult]::OK
}

function Add-DefaultPickerRow {
    param($Form,$Entry,[int]$Y)
    Initialize-NormalBootKeyboardRow
    $guid = if ($Entry) { [string]$Entry.Guid } else { $null }
    $titleText = if ($Entry) { Get-EntryDisplayTitle -Entry $Entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
    $subtitleText = if ($Entry) { [string]$Entry.Subtitle } else { Get-LocalizedString -Key 'Settings.DefaultPickerNoneHint' }
    $selected = (-not $script:DefaultTargetReadUncertain -and [string]$script:DefaultGuid -eq [string]$guid)
    $row = New-Object LenovoNormalBootKeyboardRow
    $row.Name = 'DefaultPickerRow'
    $row.Tag = [pscustomobject]@{ Guid=$guid; Selected=$selected }
    $row.Location = [Drawing.Point]::new(0,$Y)
    $row.Size = [Drawing.Size]::new(370,60)
    $row.BackColor = if ($selected) { $script:ColorSelectedRow } else { $script:ColorRow }
    $row.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $row.AccessibleName = [string]$titleText
    $row.AccessibleDescription = if ($selected) { ((Get-LocalizedString -Key 'Settings.DefaultPickerSelected') + '. ' + $subtitleText) } else { $subtitleText }
    $row.Cursor = [Windows.Forms.Cursors]::Hand
    $marker = New-Object Windows.Forms.Panel
    $marker.Size = [Drawing.Size]::new(3,60)
    $marker.BackColor = if ($selected) { $script:ColorAccent } else { $script:ColorRow }
    $row.Controls.Add($marker)
    $symbol = if ($Entry) { [string]$Entry.Symbol } else { '○' }
    $accent = if ($Entry) { $Entry.Accent } else { $script:ColorSecondary }
    $icon = New-Label -Text $symbol -Font $Form.Tag.Symbol -ForeColor $accent -X 22 -Y 7 -Width 28 -Height 44
    $row.Controls.Add($icon)
    $title = New-Label -Text $titleText -Font $Form.Tag.Bold -ForeColor $script:ColorPrimary -X 58 -Y 6 -Width 270 -Height 21
    $title.Name = 'DefaultPickerTitle'
    $title.AccessibleDescription = $titleText
    $row.Controls.Add($title)
    $subtitle = New-Label -Text $subtitleText -Font $Form.Tag.Regular -ForeColor $script:ColorSecondary -X 58 -Y 28 -Width 270 -Height 26
    $subtitle.Name = 'DefaultPickerSubtitle'
    $subtitle.AccessibleDescription = $subtitleText
    $row.Controls.Add($subtitle)
    if ($selected) {
        $check = New-Label -Text '✓' -Font $Form.Tag.Symbol -ForeColor ([Drawing.Color]::FromArgb(255,110,102)) -X 334 -Y 7 -Width 30 -Height 44
        $check.Name = 'DefaultPickerSelected'
        $check.AccessibleName = Get-LocalizedString -Key 'Settings.DefaultPickerSelected'
        $row.Controls.Add($check)
    }
    $hint = if ($selected) { Get-LocalizedString -Key 'Tooltip.CurrentDefault' }
        elseif ($Entry) { Get-LocalizedString -Key 'Tooltip.SetDefault' -Values @{ Target=$titleText } }
        else { Get-LocalizedString -Key 'Tooltip.ClearDefault' }
    $hint += [Environment]::NewLine + $titleText + [Environment]::NewLine + $subtitleText
    foreach ($control in @($row)+@($row.Controls)) {
        $control.Cursor = [Windows.Forms.Cursors]::Hand
        $controlHint = $hint
        if ($control -eq $icon -and $Entry -and $Entry.TypeTooltip) { $controlHint = [string]$Entry.TypeTooltip + [Environment]::NewLine + $hint }
        $Form.Tag.Tip.SetToolTip($control,$controlHint)
        $control.Add_MouseDown({
            param($sender,$eventArgs)
            if ($eventArgs.Button -ne [Windows.Forms.MouseButtons]::Left -or -not (Test-DefaultPickerInteraction)) { return }
            $target = $sender
            while ($target -and $target.Name -ne 'DefaultPickerRow') { $target = $target.Parent }
            Set-LenovoPointerFocus -Control $target
        })
        $control.Add_Click({ param($sender,$eventArgs) Invoke-DefaultPickerRow -Control $sender })
        $control.Add_MouseEnter({ param($sender,$eventArgs) Set-DefaultPickerHover -Control $sender -Hover $true })
        $control.Add_MouseLeave({ param($sender,$eventArgs) Set-DefaultPickerHover -Control $sender -Hover $false })
    }
    $row.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.Modifiers -ne [Windows.Forms.Keys]::None) { return }
        $key = $eventArgs.KeyCode
        if ($key -in @([Windows.Forms.Keys]::Enter,[Windows.Forms.Keys]::Space)) {
            $eventArgs.SuppressKeyPress = $true
            Invoke-DefaultPickerRow -Control $sender
        }
        elseif ($key -in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End)) {
            $eventArgs.SuppressKeyPress = $true
            $rows = @($sender.Parent.Controls | Where-Object { $_.Name -eq 'DefaultPickerRow' -and $_.Enabled } | Sort-Object Top)
            $index = [array]::IndexOf($rows,$sender)
            if ($rows.Count -eq 0 -or $index -lt 0) { return }
            $target = if ($key -eq [Windows.Forms.Keys]::Home) { 0 }
                elseif ($key -eq [Windows.Forms.Keys]::End) { $rows.Count-1 }
                elseif ($key -eq [Windows.Forms.Keys]::Up) { [Math]::Max(0,$index-1) }
                else { [Math]::Min($rows.Count-1,$index+1) }
            [void]$rows[$target].Focus()
            Set-AuxiliaryPopupControlVisible -Control $rows[$target]
        }
    })
    $Form.Tag.Body.Controls.Add($row)
}

function New-DefaultTargetPicker {
    $entries = @(Get-OrderedEntriesForUi)
    $subtitle = Get-LocalizedString -Key 'Settings.DefaultPickerCurrent' -Values @{ Target=(Get-DefaultEntryTitle) }
    $form = New-AuxiliaryPopupForm -Name 'LenovoDefaultTargetPicker' -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Subtitle $subtitle -ContentHeight (60+60*$entries.Count)
    Add-DefaultPickerRow -Form $form -Entry $null -Y 0
    $y = 60
    foreach ($entry in $entries) {
        Add-DefaultPickerRow -Form $form -Entry $entry -Y $y
        $y += 60
    }
    $form.Tag.DefaultSnapshot = Get-DefaultPickerSnapshot
    # If an independently completing refresh changes the selection inventory or
    # the verified default while the modal picker is open, dismiss stale choices.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        $active = $script:ActiveAuxiliaryPopup
        if ($active -and $active.Name -eq 'LenovoDefaultTargetPicker' -and
            (-not (Test-DefaultPickerInteraction) -or $active.Tag.DefaultSnapshot -ne (Get-DefaultPickerSnapshot))) {
            $active.DialogResult = [Windows.Forms.DialogResult]::Cancel
        }
    })
    $form.Tag.Timer = $timer
    $form.Add_Shown({ $this.Tag.Timer.Start() })
    return $form
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or -not (Test-DefaultPickerInteraction)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    $choice = Show-OwnedAuxiliaryPopup -Form (New-DefaultTargetPicker) -Owner $Owner
    if (-not $choice -or -not (Test-DefaultPickerInteraction)) { return }
    # The canonical asynchronous controller rechecks capability, current GUID
    # and allowlist before any write. Close and focus alone are read-only.
    try {
        if ($choice.Guid) { Start-DefaultTargetChange -Guid ([string]$choice.Guid) }
        else { Start-DefaultTargetChange -Guid $null }
    }
    catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
}
