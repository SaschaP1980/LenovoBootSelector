function Resolve-PendingLocalePreference {
    if (-not $script:LocalePreferenceNeedsConfirmation) { return $false }

    $choice = Show-LocaleMigrationDialog
    if ([string]::IsNullOrWhiteSpace([string]$choice)) { return $false }

    [void](Set-ActiveLocale -Locale $choice -Persist)
    return $true
}

function Update-LanguageMenuState {
    $locale = Get-ActiveLocale
    if ($script:LanguageMenuRoot) { $script:LanguageMenuRoot.Text = Get-LocalizedString -Key 'Settings.Language' }
    if ($script:LanguageEnglishMenuItem) {
        $script:LanguageEnglishMenuItem.Text = Get-LocalizedString -Key 'Language.English'
        $script:LanguageEnglishMenuItem.Checked = ($locale -eq 'en-US')
    }
    if ($script:LanguageGermanMenuItem) {
        $script:LanguageGermanMenuItem.Text = Get-LocalizedString -Key 'Language.German'
        $script:LanguageGermanMenuItem.Checked = ($locale -eq 'de-DE')
    }
}

function Update-TrayLocalizedText {
    if ($script:TrayOpenMenuItem) { $script:TrayOpenMenuItem.Text = Get-LocalizedString -Key 'Tray.Open' }
    if ($script:AutostartMenuItem) { $script:AutostartMenuItem.Text = Get-LocalizedString -Key 'Settings.Autostart' }
    if ($script:MaintenanceRootMenuItem) { $script:MaintenanceRootMenuItem.Text = Get-LocalizedString -Key 'Tray.Maintenance' }
    if ($script:TaskBrokerSetupMenuItem) { $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Setup' }
    if ($script:TaskBrokerRemoveMenuItem) { $script:TaskBrokerRemoveMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Remove' }
    if ($script:UpdateCheckMenuItem) { $script:UpdateCheckMenuItem.Text = Get-LocalizedString -Key 'Update.Check' }
    if ($script:UpdateInstallMenuItem) { $script:UpdateInstallMenuItem.Text = Get-LocalizedString -Key 'Update.Install' }
    if ($script:RuntimeDiagnosticMenuItem) { $script:RuntimeDiagnosticMenuItem.Text = Get-LocalizedString -Key 'Diagnostics.Save' }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Text = Get-LocalizedString -Key 'Action.RestartWindows' }
    if ($script:TrayExitMenuItem) { $script:TrayExitMenuItem.Text = Get-LocalizedString -Key 'Tray.Exit' }
    Update-LanguageMenuState
}

function Rebuild-PopupForLocale {
    $wasVisible = ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible)
    try {
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $script:Popup.Hide()
            $script:Popup.Dispose()
        }
    } catch { }

    $script:Popup = New-PopupForm
    try { Update-AutostartUi | Out-Null } catch { }
    try { Update-MaintenanceUi } catch { }
    try { Update-ManageEntriesUiState } catch { }
    try { Update-PopupRows } catch { }

    if ($wasVisible) {
        Position-Popup
        $script:Popup.Show()
        $script:Popup.Activate()
    }
}

function Set-LanguageFromUi {
    param([Parameter(Mandatory=$true)][ValidateSet('en-US','de-DE')][string]$Locale)

    $before = Get-ActiveLocale
    $after = Set-ActiveLocale -Locale $Locale -Persist
    Update-TrayLocalizedText

    if ($after -ne $before) {
        Rebuild-PopupForLocale
    }
    return $after
}
