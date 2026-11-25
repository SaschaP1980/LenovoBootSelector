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
    if ($script:PreferencesMenuRoot) { $script:PreferencesMenuRoot.Text = Get-LocalizedString -Key 'Preferences.Menu' }
    if ($script:PreferencesExportMenuItem) { $script:PreferencesExportMenuItem.Text = Get-LocalizedString -Key 'Preferences.Export' }
    if ($script:PreferencesImportMenuItem) { $script:PreferencesImportMenuItem.Text = Get-LocalizedString -Key 'Preferences.Import' }
    if ($script:MaintenanceRootMenuItem) { $script:MaintenanceRootMenuItem.Text = Get-LocalizedString -Key 'Tray.Maintenance' }
    if ($script:TaskBrokerSetupMenuItem) { $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Setup' }
    if ($script:TaskBrokerRemoveMenuItem) { $script:TaskBrokerRemoveMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Remove' }
    if ($script:UpdateCheckMenuItem) { $script:UpdateCheckMenuItem.Text = Get-LocalizedString -Key 'Update.Check' }
    if ($script:UpdateInstallMenuItem) { $script:UpdateInstallMenuItem.Text = Get-LocalizedString -Key 'Update.Install' }
    if ($script:RuntimeDiagnosticMenuItem) { $script:RuntimeDiagnosticMenuItem.Text = Get-LocalizedString -Key 'Diagnostics.Save' }
    if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Text = Get-LocalizedString -Key 'Diagnostics.Upload' }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Text = Get-LocalizedString -Key 'Action.RestartWindows' }
    if ($script:TrayExitMenuItem) { $script:TrayExitMenuItem.Text = Get-LocalizedString -Key 'Tray.Exit' }
    Update-LanguageMenuState
}

# Retain the native window, DPI, scroll position and modal ownership.
function Update-PopupLocalePresentation {
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $script:Popup = New-PopupForm
    }
    $textKeys = [ordered]@{
        SectionLabel='Popup.NextBootSection'
        ManageEntriesButton='Popup.Customize'
        ConfigurationSectionLabel='Settings.Title'
        MoreSettingsButton='Settings.More'
        DefaultTargetNameLabel='Settings.DefaultTarget'
        RestartActionButton='Action.RestartWindows'
        RestartUseDefaultButton='BootNext.UseDefaultOnce'
        ManageUndoButton='Manage.Undo'
        ManageCancelButton='Common.Cancel'
        ManageSaveButton='Manage.Save'
    }
    if ($script:Popup.Controls) {
        foreach ($name in $textKeys.Keys) {
            foreach ($control in $script:Popup.Controls.Find($name,$true)) {
                $control.Text = Get-LocalizedString -Key $textKeys[$name]
            }
        }
        foreach ($row in $script:Popup.Controls.Find('SettingsPanel',$true)) {
            $row.AccessibleName = Get-LocalizedString -Key 'Settings.More'
        }
        if ($script:HeaderStatusLabel) { $script:HeaderStatusLabel.AccessibleDescription = Get-LocalizedString -Key 'Popup.HeaderUpdateAccessible' }
        if ($script:RestartUseDefaultButton) { $script:RestartUseDefaultButton.AccessibleName = $script:RestartUseDefaultButton.Text }
        if ($script:BootTypeToolTip) {
            if ($script:RefreshButton) { $script:BootTypeToolTip.SetToolTip($script:RefreshButton,(Get-LocalizedString -Key 'Action.RefreshBootTargets')) }
            foreach ($name in @('ManageEntriesButton','RestartActionButton','SettingsPanel','DefaultPanel')) {
                $key = switch ($name) {
                    'ManageEntriesButton' { 'Tooltip.Customize' }
                    'RestartActionButton' { 'Tooltip.Restart' }
                    'SettingsPanel' { 'Tooltip.Settings' }
                    'DefaultPanel' { 'Tooltip.DefaultNavigation' }
                }
                foreach ($control in $script:Popup.Controls.Find($name,$true)) {
                    $hint = Get-LocalizedString -Key $key
                    $script:BootTypeToolTip.SetToolTip($control,$hint)
                    foreach ($child in $control.Controls) { $script:BootTypeToolTip.SetToolTip($child,$hint) }
                }
            }
        }
    }
    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Update-ManageEntriesUiState
    Update-PopupRows -Reason 'language-change'
    if ($script:ActiveAuxiliaryPopup -and -not $script:ActiveAuxiliaryPopup.IsDisposed -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoConfigurationPopup') {
        Update-ConfigurationPopupLocale -Form $script:ActiveAuxiliaryPopup
    }
}

function Update-CachedBootEntryLocalization {
    # Project the same firmware identity and already observed storage facts.
    # Do not read hardware or use a newer global storage snapshot which may
    # belong to a refresh deferred while a BootNext selection is pending.
    $script:CurrentEntries = @(foreach ($entry in $script:CurrentEntries) {
        Get-FriendlyBootEntry -Guid ([string]$entry.Guid) -RawDescription ([string]$entry.LocalizationRawDescription) -StorageContext $entry.LocalizationStorageContext
    })
}

function Set-LanguageFromUi {
    param([Parameter(Mandatory=$true)][ValidateSet('en-US','de-DE')][string]$Locale)

    $before = Get-ActiveLocale
    $after = Set-ActiveLocale -Locale $Locale -Persist
    Update-TrayLocalizedText

    if ($after -ne $before) {
        Update-CachedBootEntryLocalization
        Update-PopupLocalePresentation
    }
    return $after
}
