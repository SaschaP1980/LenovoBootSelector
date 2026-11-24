function Get-DefaultEntryTitle {
    if ($script:DefaultTargetReadUncertain) { return (Get-LocalizedString -Key 'Default.ChangeUnknown') }
    if (-not $script:DefaultGuid) { return (Get-LocalizedString -Key 'Settings.NoDefaultTarget') }
    $entry = Get-EntryByGuid $script:DefaultGuid
    if ($entry) { return (Get-EntryDisplayTitle -Entry $entry) }
    return (Get-LocalizedString -Key 'Settings.DefaultTargetUnavailable')
}

function Update-DefaultUi {
    if ($script:DefaultButton -and -not $script:DefaultButton.IsDisposed) {
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        $checking = [bool]$capabilities.IsChecking
        $enabled = [bool]$capabilities.CanSetDefaultTarget
        $visualEnabled = ($enabled -or $checking)
        # Keep the existing native readiness Enabled contract. While a one-shot
        # BootNext write is pending, its default-target command is already
        # rejected by Set-DefaultGuid; do not misleadingly advertise it as active.
        $pendingDefault = [bool]$script:DefaultTargetChangePending
        $interactive = ($enabled -and -not [bool]$script:BootNextPendingGuid -and -not $pendingDefault)
        $mutedInk = [Drawing.Color]::FromArgb(146,146,146)
        $script:DefaultInteractionEnabled = $interactive
        if (-not $interactive) { $script:DefaultButton.BackColor = $script:ColorSurface }
        $script:DefaultButton.Enabled = $visualEnabled
        $script:DefaultButton.TabStop = $interactive
        $script:DefaultButton.AccessibleName = Get-LocalizedString -Key 'Settings.DefaultTarget'
        $script:DefaultButton.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }

        if ($script:DefaultValueLabel -and -not $script:DefaultValueLabel.IsDisposed) {
            $target = Get-DefaultEntryTitle
            if ($pendingDefault) {
                $entry = if ($script:DefaultTargetChangeRequestedGuid) { Get-EntryByGuid ([string]$script:DefaultTargetChangeRequestedGuid) } else { $null }
                $target = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
            }
            $key = if ($script:DefaultTargetChangeStage -eq 'verifying') { 'Default.ChangeVerifying' } else { 'Default.ChangeSaving' }
            $script:DefaultValueLabel.Text = if ($pendingDefault) { Get-LocalizedString -Key $key } elseif ($checking) { Get-LocalizedString -Key 'Status.Checking' } else { $target }
            $description = if ($pendingDefault) {
                Get-LocalizedString -Key $(if ($script:DefaultTargetChangeStage -eq 'verifying') { 'Default.ChangeVerifyingFooter' } else { 'Default.ChangeSavingFooter' }) -Values @{ Target=$target }
            } else { [string]$script:DefaultValueLabel.Text }
            $script:DefaultValueLabel.AccessibleName = $description
            $script:DefaultValueLabel.AccessibleDescription = $description
            $script:DefaultButton.AccessibleDescription = $description
            if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:DefaultValueLabel,$description) }
            $script:DefaultValueLabel.ForeColor = if ($pendingDefault) { $script:ColorWarning } elseif ($interactive) { $script:ColorPrimary } else { $mutedInk }
        }
        if ($script:DefaultArrowLabel -and -not $script:DefaultArrowLabel.IsDisposed) {
            $script:DefaultArrowLabel.Visible = (-not $checking -and -not $pendingDefault)
            $script:DefaultArrowLabel.Text = '›'
        }
        foreach ($child in $script:DefaultButton.Controls) {
            try {
                $child.Enabled = $visualEnabled
                $child.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
                if ($child -eq $script:DefaultArrowLabel) {
                    $child.ForeColor = if ($pendingDefault) { $script:ColorWarning } elseif ($interactive) { $script:ColorSecondary } else { $mutedInk }
                }
                elseif ($child -is [System.Windows.Forms.Label] -and $child -ne $script:DefaultValueLabel) {
                    $child.ForeColor = if ($interactive) { $script:ColorPrimary } else { $mutedInk }
                }
            } catch { }
        }
    }
}
