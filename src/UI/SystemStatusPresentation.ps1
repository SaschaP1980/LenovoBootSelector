# LBS-182: project only existing in-memory observations; no broker/firmware calls.
function ConvertTo-SystemStatusObservedTime {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    try {
        $utc = ([datetime]$Value).ToUniversalTime()
        if ($utc.Year -lt 2000 -or $utc -gt [datetime]::UtcNow) { return $null }
        return $utc
    } catch { return $null }
}

function Format-SystemStatusObservedTime {
    param($Value)
    $utc = ConvertTo-SystemStatusObservedTime $Value
    if (-not $utc) { return (Get-LocalizedString -Key 'SystemStatus.TimeUnknown') }
    $minutes = [int][Math]::Floor(([datetime]::UtcNow-$utc).TotalMinutes)
    return (Get-LocalizedString -Key 'SystemStatus.Age' -Values @{ Time=$utc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'); Minutes=$minutes })
}

function Get-SystemStatusPresentation {
    $defaultEntry = if ($script:DefaultGuid) { Get-EntryByGuid $script:DefaultGuid }
    $nextEntry = if ($script:SelectedGuid) { Get-EntryByGuid $script:SelectedGuid }
    $defaultName = if ($defaultEntry) { Get-EntryDisplayTitle -Entry $defaultEntry } else { '' }
    $nextName = if ($nextEntry) { Get-EntryDisplayTitle -Entry $nextEntry } else { '' }
    $nextTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusNextObservedUtc
    $readinessTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusReadinessObservedUtc
    $entriesTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusEntriesObservedUtc
    $refreshing = [bool](Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)
    $pending = [bool]($script:BootNextPendingGuid -or $script:DefaultTargetChangePending)
    $model = Resolve-SystemStatusCore -Capabilities $script:SystemStatusCapabilities -DefaultEvidence $script:SystemStatusDefaultEvidence -DefaultName $defaultName -DefaultGuid $script:DefaultGuid -DefaultUncertain ([bool]($script:DefaultTargetReadUncertain -or $script:DefaultTargetChangePending)) -NextVerified ([bool]$script:NextBootFirmwareReadVerified) -NextName $nextName -NextGuid $script:SelectedGuid -NextTimeKnown ([bool]$nextTime) -Pending $pending -Refreshing $refreshing -LastRefresh $script:SystemStatusLastRefresh -Drift $script:BootTargetDriftState -DriftFailed ([bool]$script:SystemStatusDriftFailed) -ReadinessTimeKnown ([bool]$readinessTime) -EntriesTimeKnown ([bool]$entriesTime)
    return $model
}

function Update-SystemStatusPopupPresentation {
    param([Windows.Forms.Form]$Form)
    $model = Get-SystemStatusPresentation
    $default = if ($model.Default -eq 'Value') { $model.DefaultName } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Default) }
    $next = if ($model.Next -eq 'Value') {
        $model.NextName + [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Relation))
    } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Next) }
    $ready = Get-LocalizedString -Key ('SystemStatus.'+$model.Readiness)
    if ($model.Hint) { $ready += [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Hint)) }
    $summary = Get-LocalizedString -Key ('SystemStatus.'+$model.Summary)
    if ($model.Refresh) { $summary += [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Refresh)) }
    $freshness = @(
        (Get-LocalizedString -Key 'SystemStatus.ManagerTime' -Values @{Time=(Format-SystemStatusObservedTime $(if ($script:NextBootFirmwareReadVerified) { $script:SystemStatusNextObservedUtc } else { $null }))}),
        (Get-LocalizedString -Key 'SystemStatus.EntriesTime' -Values @{Time=(Format-SystemStatusObservedTime $script:SystemStatusEntriesObservedUtc)}),
        (Get-LocalizedString -Key 'SystemStatus.ReadinessTime' -Values @{Time=(Format-SystemStatusObservedTime $script:SystemStatusReadinessObservedUtc)})
    ) -join [Environment]::NewLine
    $values = @{Summary=$summary;Stored=$default;Next=$next;Readiness=$ready;Drift=(Get-LocalizedString -Key ('SystemStatus.'+$model.Drift));Freshness=$freshness}
    foreach ($key in $values.Keys) {
        $label = $Form.Tag.Body.Controls['SystemStatusValue-'+$key]
        if ($label -and $label.Text -cne $values[$key]) {
            $label.Text = $values[$key]
            $label.AccessibleName = $label.Text
            $label.AccessibleDescription = $label.Text
            $Form.Tag.Tip.SetToolTip($label,$label.Text)
        }
    }
    $label = $Form.Tag.Body.Controls['SystemStatusValue-Summary']
    $label.ForeColor = if ([Windows.Forms.SystemInformation]::HighContrast) { [Drawing.SystemColors]::WindowText } elseif ($model.Summary -in @('SummaryAttention','SummaryUnknown')) { [Drawing.Color]::FromArgb(234,182,94) } else { $script:ColorPrimary }
}

function Set-SystemStatusPopupWidth {
    param($Form,[double]$Scale)
    $margin = [int][Math]::Round(16*$Scale)
    foreach ($control in $Form.Tag.Body.Controls) {
        $control.Left = $margin
        $control.Width = [Math]::Max(1,$Form.Tag.Body.Width-2*$margin)
    }
}

function New-SystemStatusPopup {
    $form = New-AuxiliaryPopupForm -Name 'LenovoSystemStatusPopup' -Title (Get-LocalizedString -Key 'SystemStatus.Title') -Subtitle (Get-LocalizedString -Key 'SystemStatus.Subtitle') -ContentHeight 440
    $y = 8
    $highContrast = [Windows.Forms.SystemInformation]::HighContrast
    $surface = if ($highContrast) { [Drawing.SystemColors]::Window } else { [Drawing.Color]::FromArgb(37,37,37) }
    $valueInk = if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorPrimary }
    $headingInk = if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorSecondary }
    if ($highContrast) {
        $form.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Body.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Viewport.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Header.BackColor = [Drawing.SystemColors]::Control
        $form.Tag.Title.ForeColor = [Drawing.SystemColors]::ControlText
        $form.Tag.Subtitle.ForeColor = [Drawing.SystemColors]::ControlText
        $form.Tag.Close.BackColor = [Drawing.SystemColors]::Control
        $form.Tag.Close.ForeColor = [Drawing.SystemColors]::ControlText
    }
    foreach ($row in @(
        @{Key='Summary';Height=52},
        @{Key='Stored';Height=40},
        @{Key='Next';Height=48},
        @{Key='Readiness';Height=66},
        @{Key='Drift';Height=34},
        @{Key='Freshness';Height=64}
    )) {
        if ($row.Key -ne 'Summary') {
            $heading = New-Label -Text (Get-LocalizedString -Key ('SystemStatus.'+$row.Key)) -Font $form.Tag.Heading -ForeColor $headingInk -X 16 -Y $y -Width 358 -Height 20
            $heading.Name = 'SystemStatusHeading-'+$row.Key
            $form.Tag.Body.Controls.Add($heading)
            $y += 20
        }
        $label = New-Label -Text '' -Font $form.Tag.Regular -ForeColor $valueInk -X 16 -Y $y -Width 358 -Height $row.Height
        $label.Name = 'SystemStatusValue-'+$row.Key
        $label.BackColor = $surface
        $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $label.Padding = [Windows.Forms.Padding]::new(6,2,6,2)
        $label.AutoEllipsis = $true
        $label.AccessibleRole = [Windows.Forms.AccessibleRole]::StaticText
        $form.Tag.Body.Controls.Add($label)
        $y += $row.Height+4
    }
    Update-SystemStatusPopupPresentation -Form $form
    # Reflect only in-memory state; no extra refresh, readiness probe or hardware polling.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        if ($script:ActiveAuxiliaryPopup -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoSystemStatusPopup') {
            Update-SystemStatusPopupPresentation -Form $script:ActiveAuxiliaryPopup
        }
    })
    $form.Tag.Timer = $timer
    # The shared owned-surface lifecycle starts this timer only after its initial activation handler.
    $form.Add_KeyDown({
        param($sender,$eventArgs)
        $scroll = $sender.Tag.Scroll
        if (-not $scroll.Visible) { return }
        $delta = switch ($eventArgs.KeyCode) {
            'PageDown' { $scroll.LargeChange }
            'PageUp' { -$scroll.LargeChange }
            'Down' { $scroll.SmallChange }
            'Up' { -$scroll.SmallChange }
            default { 0 }
        }
        if ($delta) {
            $scroll.Value = [Math]::Max(0,[Math]::Min($scroll.Maximum,$scroll.Value+$delta))
            $eventArgs.Handled=$true
            $eventArgs.SuppressKeyPress=$true
        }
    })
    return $form
}

function Show-SystemStatusPopup {
    param([Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog -or -not $Owner -or -not $Owner.Enabled) { return }
    [void](Show-OwnedAuxiliaryPopup -Form (New-SystemStatusPopup) -Owner $Owner)
}
