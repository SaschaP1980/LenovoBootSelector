function Update-AutostartUi {
    $info = Get-AutostartInfo

    $script:UpdatingAutostartUi = $true
    try {
        if ($script:AutostartCheckbox -and -not $script:AutostartCheckbox.IsDisposed) {
            $script:AutostartCheckbox.Checked = [bool]$info.Enabled
            $script:AutostartCheckbox.Text = ''
        }
        if ($script:AutostartTextLabel -and -not $script:AutostartTextLabel.IsDisposed) {
            $script:AutostartTextLabel.Text = Get-LocalizedString -Key 'Settings.Autostart'
        }
        if ($script:AutostartMenuItem) {
            $script:AutostartMenuItem.Checked = [bool]$info.Enabled
            $script:AutostartMenuItem.Text = Get-LocalizedString -Key 'Settings.Autostart'
        }
    }
    finally {
        $script:UpdatingAutostartUi = $false
    }

    return $info
}

function Set-AutostartFromUi([bool]$Enabled) {
    if ($script:UpdatingAutostartUi) { return }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Set-AutostartEnabled -Enabled:$Enabled
        $info = Update-AutostartUi
        if ($Enabled) { $script:LastStatusText = Get-LocalizedString -Key 'Autostart.Enabled' }
        else { $script:LastStatusText = Get-LocalizedString -Key 'Autostart.Disabled' }

        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTOSTART_CHANGE' -Stage 'autostart' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ enabled = $Enabled; currentPath = [bool]$info.CurrentPath; hiddenLauncher = [bool]$info.UsesHiddenLauncher })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTOSTART_CHANGE' -Stage 'autostart' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ enabled = $Enabled }) -Level error
        Update-AutostartUi | Out-Null
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.Autostart') -Heading (Get-LocalizedString -Key 'Autostart.ErrorHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
    }
}
