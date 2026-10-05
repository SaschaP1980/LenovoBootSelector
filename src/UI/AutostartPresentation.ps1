function Update-AutostartUi {
    $info = Get-AutostartInfo

    $script:UpdatingAutostartUi = $true
    try {
        if ($script:AutostartCheckbox -and -not $script:AutostartCheckbox.IsDisposed) {
            $script:AutostartCheckbox.Checked = [bool]$info.Enabled
            $script:AutostartCheckbox.Text = ''
        }
        if ($script:AutostartTextLabel -and -not $script:AutostartTextLabel.IsDisposed) {
            $script:AutostartTextLabel.Text = 'Mit Windows starten'
        }
        if ($script:AutostartMenuItem) {
            $script:AutostartMenuItem.Checked = [bool]$info.Enabled
            if ($info.Enabled -and -not $info.CurrentPath) {
                $script:AutostartMenuItem.Text = 'Mit Windows starten'
            }
            else {
                $script:AutostartMenuItem.Text = 'Mit Windows starten'
            }
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
        if ($Enabled) { $script:LastStatusText = 'Autostart ist aktiviert.' }
        else { $script:LastStatusText = 'Autostart ist deaktiviert.' }

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
        Show-LenovoNoticeDialog -Title 'Mit Windows starten' -Heading 'Die Einstellung konnte nicht geändert werden.' -Message 'Bitte versuche es erneut.' -Kind Error
    }
}
