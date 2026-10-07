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
        $script:DefaultInteractionEnabled = $enabled
        $script:DefaultButton.Enabled = $visualEnabled
        $script:DefaultButton.Cursor = if ($enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }

        if ($script:DefaultValueLabel -and -not $script:DefaultValueLabel.IsDisposed) {
            $script:DefaultValueLabel.Text = if ($checking) { Get-LocalizedString -Key 'Status.Checking' } else { Get-DefaultEntryTitle }
            $script:DefaultValueLabel.ForeColor = if ($visualEnabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(110,110,110) }
        }
        if ($script:DefaultArrowLabel -and -not $script:DefaultArrowLabel.IsDisposed) {
            $script:DefaultArrowLabel.Visible = -not $checking
        }
        foreach ($child in $script:DefaultButton.Controls) {
            try {
                $child.Enabled = $visualEnabled
                $child.Cursor = if ($enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
            } catch { }
        }
    }
}
