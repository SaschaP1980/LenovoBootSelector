function Get-DefaultEntryTitle {
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
        $interactive = ($enabled -and -not [bool]$script:BootNextPendingGuid)
        $mutedInk = [Drawing.Color]::FromArgb(146,146,146)
        $script:DefaultInteractionEnabled = $interactive
        if (-not $interactive) { $script:DefaultButton.BackColor = $script:ColorSurface }
        $script:DefaultButton.Enabled = $visualEnabled
        $script:DefaultButton.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }

        if ($script:DefaultValueLabel -and -not $script:DefaultValueLabel.IsDisposed) {
            $script:DefaultValueLabel.Text = if ($checking) { Get-LocalizedString -Key 'Status.Checking' } else { Get-DefaultEntryTitle }
            $script:DefaultValueLabel.AccessibleDescription = [string]$script:DefaultValueLabel.Text
            if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:DefaultValueLabel, [string]$script:DefaultValueLabel.Text) }
            $script:DefaultValueLabel.ForeColor = if ($interactive) { $script:ColorPrimary } else { $mutedInk }
        }
        if ($script:DefaultArrowLabel -and -not $script:DefaultArrowLabel.IsDisposed) {
            $script:DefaultArrowLabel.Visible = -not $checking
        }
        foreach ($child in $script:DefaultButton.Controls) {
            try {
                $child.Enabled = $visualEnabled
                $child.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
                if ($child -eq $script:DefaultArrowLabel) {
                    $child.ForeColor = if ($interactive) { $script:ColorSecondary } else { $mutedInk }
                }
                elseif ($child -is [System.Windows.Forms.Label]) {
                    $child.ForeColor = if ($interactive) { $script:ColorPrimary } else { $mutedInk }
                }
            } catch { }
        }
    }
}
