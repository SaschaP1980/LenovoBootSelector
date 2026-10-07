#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$HideConsole,
    [switch]$BackgroundRefresh,
    [string]$BackgroundResultPath,
    [switch]$BackgroundRefreshStorage,
    [switch]$BackgroundRefreshFirmware,
    [switch]$UpdateCheck,
    [switch]$UpdatePrepare,
    [string]$UpdateResultPath,
    [string]$UpdateManifestPath,
    [string]$RuntimeSessionId
)

$ErrorActionPreference = 'Stop'

function Start-LenovoBootSelectorHidden {
    $launcherPath = Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs'
    if (-not (Test-Path -LiteralPath $launcherPath)) { return $false }

    try {
        $wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $wscriptPath
        $psi.Arguments = ('"{0}"' -f $launcherPath)
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($psi)
        return $true
    }
    catch {
        return $false
    }
}

# LBS-17: pure localization is loaded before startup recovery so duplicate-instance
# and fatal-startup UI can honor the persisted locale safely.
# Lenovo Boot Selector - Functional Core: localization
# Pure/deterministic functions only. No script state, WinForms, filesystem, registry,
# network, process starts, Scheduled Tasks, or privileged broker access.

function Get-SupportedLocaleIdsCore {
    return @('en-US', 'de-DE')
}

function Resolve-LocaleIdCore {
    param([string]$Locale)

    $value = ([string]$Locale).Trim()
    foreach ($supported in @(Get-SupportedLocaleIdsCore)) {
        if ($value -and $value.Equals($supported, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $supported
        }
    }
    return 'en-US'
}

function Get-LocalizationCatalogCore {
    return [ordered]@{
        'en-US' = [ordered]@{
            'Common.OK' = 'OK'
            'Common.Cancel' = 'Cancel'
            'Common.Close' = 'Close'
            'Common.TryAgain' = 'Please try again.'
            'Settings.Language' = 'Language'
            'Language.English' = 'English'
            'Language.German' = 'Deutsch'
            'Language.MigrationTitle' = 'Choose app language'
            'Language.MigrationHeading' = 'Confirm your language'
            'Language.MigrationMessage' = 'Version 0.8.0.0 may have selected German automatically during an upgrade. Choose the language you want Lenovo Boot Selector to use. This choice is saved and will not be changed automatically.'
            'Language.MigrationUseEnglish' = 'Use English'
            'Language.MigrationKeepGerman' = 'Use German'
            'Progress.StepOf' = 'Step {0} of {1}'
            'Storage.InternalSsdModel' = 'Internal SSD: {Model}'
            'Popup.HeaderUpdateAccessible' = 'Opens the dialog for the available app version.'
            'Status.BootTargetsRefreshing' = 'Boot targets are being refreshed in the background…'
            'Action.RefreshBootTargets' = 'Refresh boot targets'
            'Popup.NextBootSection' = 'NEXT BOOT'
            'Popup.Customize' = 'CUSTOMIZE'
            'Status.ScrollPositionFailed' = 'The scroll position could not be updated.'
            'Settings.Title' = 'SETTINGS'
            'Settings.Autostart' = 'Start with Windows'
            'Settings.DefaultTarget' = 'Default boot target'
            'Settings.NoDefaultTarget' = 'No default target'
            'Settings.DefaultTargetUnavailable' = 'Boot target unavailable'
            'Status.Checking' = 'Checking …'
            'Action.RestartWindows' = 'Restart Windows'
            'Status.NextTargetDefaultOrder' = 'Next target: default order'
            'Manage.Section' = 'ADJUST BOOT TARGETS'
            'Manage.Title' = 'CHANGES'
            'Manage.Hint' = 'Drag to sort · Click to show/hide'
            'Manage.SubHint' = 'Pencil to rename · Leave empty = original name'
            'Manage.Save' = 'Save changes'
            'Manage.StatusEditing' = 'Customize boot targets · Drag to sort · Click to show/hide · Pencil for display name'
            'Manage.StatusSaved' = 'Boot-target changes were saved.'
            'Manage.StatusDiscarded' = 'Changes were discarded.'
            'Autostart.Enabled' = 'Autostart is enabled.'
            'Autostart.Disabled' = 'Autostart is disabled.'
            'Autostart.ErrorHeading' = 'The setting could not be changed.'
            'Default.SaveErrorHeading' = 'The default boot target could not be saved.'
            'Default.SaveErrorMessage' = 'Please try again. If the problem persists, open Maintenance → Repair system functions.'
            'Status.NewBootTargetDetected' = 'New boot target detected · Reinitialize system functions.'
            'Status.BootTargetsChanged' = 'Boot targets changed · Reinitialize system functions.'
            'Status.SystemFunctionsRepairRequired' = 'System functions need to be repaired.'
            'Status.SystemFunctionsSetupRequired' = 'System functions need to be set up.'
            'Header.Refreshing' = 'Updating boot targets…'
            'Update.Available' = 'New app version available'
            'Tray.Open' = 'Open Lenovo Boot Selector'
            'Tray.Maintenance' = 'Maintenance'
            'Maintenance.Setup' = 'Set up system functions…'
            'Maintenance.Remove' = 'Remove system functions…'
            'Update.Check' = 'Check for new version…'
            'Update.Install' = 'Update app…'
            'Diagnostics.Save' = 'Save diagnostics…'
            'Boot.OtherTarget' = 'Other boot target'
            'Boot.OtherTargetTooltip' = 'Gray: other boot target'
            'Boot.MenuTitle' = 'Lenovo Boot Menu'
            'Boot.MenuSubtitle' = 'Open the boot menu on the next startup'
            'Boot.MenuTooltip' = 'Red: Lenovo Boot Menu'
            'Boot.Nvme1Title' = 'NVMe SSD 1'
            'Boot.Nvme2Title' = 'NVMe SSD 2'
            'Boot.NoDrive' = 'No drive detected'
            'Boot.InternalSsd' = 'Internal SSD'
            'Boot.SecondInternalSsd' = 'Second internal SSD'
            'Boot.InternalSsdTooltip' = 'Blue: internal SSD'
            'Boot.UsbTooltip' = 'Yellow: USB drive'
            'Boot.UsbChecking' = 'Checking USB drives …'
            'Boot.UsbCheckFailed' = 'USB drives could not be checked'
            'Boot.UsbBootMedium' = 'USB boot medium: {Model}'
            'Boot.UsbMultipleBoot' = 'Multiple possible USB boot media detected'
            'Boot.UsbNonBoot' = '{Model} detected · not detected as boot medium'
            'Boot.UsbMultipleNoBoot' = 'USB drives detected · no boot medium found'
            'Boot.UsbNone' = 'No USB drive connected'
            'Boot.UsbFddTitle' = 'USB floppy drive'
            'Boot.UsbFddSubtitle' = 'Boot from a USB floppy drive'
            'Boot.UsbCdTitle' = 'USB CD/DVD drive'
            'Boot.UsbCdSubtitle' = 'Boot from an optical USB drive'
            'Boot.PxeTitle' = 'Network boot'
            'Boot.PxeSubtitle' = 'Boot over the local network'
            'Boot.PxeTooltip' = 'Purple: network boot'
            'Boot.LenovoRecoveryTitle' = 'Lenovo recovery'
            'Boot.LenovoRecoverySubtitle' = 'Recovery over the network'
            'Boot.CyanTooltip' = 'Cyan: Lenovo or corporate network'
            'Boot.CorporateTitle' = 'Corporate network boot'
            'Boot.CorporateSubtitle' = 'Boot over the corporate network'
            'Boot.OtherDriveTitle' = 'Other drive'
            'Boot.OtherDriveSubtitle' = 'Other detected drive'
            'Boot.OtherDriveTooltip' = 'Gray: other drive'
            'Boot.OtherCdTitle' = 'Other CD/DVD drive'
            'Boot.OtherCdSubtitle' = 'Other optical boot drive'
            'Status.NextBootTarget' = 'Next boot: {Title}'
            'Status.NextBootSet' = 'Next boot target was set.'
            'Boot.ChangeErrorTitle' = 'Boot target could not be changed'
            'Boot.ChangeErrorHeading' = 'The selection was not applied.'
            'Boot.ChangeErrorMessage' = 'Please try again. If the problem persists, open Maintenance → Repair system functions.'
            'Manage.OrderChanged' = 'Order changed · Save applies the change.'
            'Manage.OriginalName' = 'Original name: {Name}'
            'Boot.MenuManageSubtitle' = 'Selection menu for the next boot target'
            'Manage.AliasRemoved' = 'Display name removed · Save applies the change.'
            'Manage.AliasChanged' = 'Display name changed · Save applies the change.'
            'Manage.AliasDiscarded' = 'Display-name change discarded.'
            'Common.Apply' = 'Apply'
            'Manage.OriginalNameHint' = 'Leave empty = original name'
            'Manage.EditAliasAccessible' = 'Change display name'
            'Manage.EditAliasStatus' = 'Edit display name · Enter applies · Esc discards · empty = original name'
            'Maintenance.Dialog.RemoveTitle' = 'Remove system functions'
            'Maintenance.Dialog.RemoveHeading' = 'Remove system functions?'
            'Maintenance.Dialog.RemoveBody' = "After this, Lenovo Boot Selector cannot change boot targets until setup is completed again.`r`n`r`nThe saved default boot target will be reset.`r`n`r`nYour existing boot targets, personal app settings, and autostart setting will be kept."
            'Maintenance.Action.Remove' = 'Remove'
            'Maintenance.Dialog.RepairTitle' = 'Repair system functions'
            'Maintenance.Dialog.RepairHeading' = 'System functions are already set up.'
            'Maintenance.Dialog.RepairBody' = 'Set them up again and repair them? Your boot targets and personal settings will be kept.'
            'Maintenance.Action.Repair' = 'Repair'
            'Maintenance.Dialog.MigrateHeading' = 'The setup needs to be updated.'
            'Maintenance.Dialog.MigrateBody' = 'An older or incomplete setup was found. Repair it so boot targets can be changed reliably again.'
            'Maintenance.Dialog.ReinitializeTitle' = 'Reinitialize system functions'
            'Maintenance.Dialog.ReinitializeHeading' = 'New boot target detected'
            'Maintenance.Dialog.ReinitializeBody' = 'Lenovo Boot Selector detected a change to the available boot targets. Reinitialize the system functions so the new boot target can be used safely. Your personal settings will be kept.'
            'Maintenance.Action.Reinitialize' = 'Reinitialize'
            'Maintenance.Dialog.SetupTitle' = 'Set up system functions'
            'Maintenance.Dialog.SetupHeading' = 'One-time setup required'
            'Maintenance.Dialog.SetupBody' = 'Lenovo Boot Selector requires a one-time Windows confirmation before it can change boot targets. After that, you can select boot targets without further confirmation.'
            'Maintenance.Action.Setup' = 'Set up'
            'Restart.DialogTitle' = 'Restart Windows'
            'Restart.Question' = 'Restart Windows now?'
            'Restart.NextTarget' = 'NEXT TARGET'
            'Restart.Action' = 'Restart'
            'Maintenance.Busy.Remove' = 'Removing system functions…'
            'Maintenance.Busy.Reinitialize' = 'Reinitializing system functions…'
            'Maintenance.Busy.Repair' = 'Repairing system functions…'
            'Maintenance.Busy.Setup' = 'Setting up system functions…'
            'Maintenance.Caption' = 'SYSTEM FUNCTIONS'
            'Maintenance.Panel.SetupHeading' = 'Set up system functions'
            'Maintenance.Panel.SetupMessage' = 'A one-time Windows confirmation is required before Lenovo Boot Selector can change boot targets.'
            'Maintenance.Panel.SetupHint' = 'Afterward, you can select boot targets without further confirmation.'
            'Maintenance.Panel.RepairHeading' = 'Repair system functions'
            'Maintenance.Panel.RepairMessage' = 'The existing setup is incomplete or needs to be updated.'
            'Maintenance.Panel.RepairHint' = 'Your personal settings will be kept.'
            'Maintenance.Panel.NewTargetHeading' = 'New boot target detected'
            'Maintenance.Panel.NewTargetMessage' = 'Lenovo Boot Selector detected a new boot target. Reinitialize the system functions so it can be used safely.'
            'Maintenance.Panel.TargetsChangedHeading' = 'Boot targets changed'
            'Maintenance.Panel.TargetsChangedMessage' = 'The available boot targets have changed. Reinitialize the system functions so the selection is complete again.'
            'Maintenance.Panel.BusyRemoveMessage' = 'The system functions are being removed safely. Please wait a moment.'
            'Maintenance.Panel.BusyReinitializeMessage' = 'Windows is setting up the system functions again for the changed boot targets. Please wait a moment.'
            'Maintenance.Panel.BusySetupMessage' = 'Windows is setting up the required system functions. Please wait a moment.'
            'Maintenance.Panel.BusyHint' = 'The app updates automatically when the operation is complete.'
            'Maintenance.SuccessRemovedTitle' = 'System functions removed'
            'Maintenance.SuccessRemovedHeading' = 'System functions were removed.'
            'Maintenance.SuccessRemovedMessage' = 'Boot targets can be changed again after you set up the system functions again.'
            'Maintenance.SuccessReinitializedTitle' = 'Reinitialized'
            'Maintenance.SuccessReinitializedHeading' = 'System functions were reinitialized.'
            'Maintenance.SuccessReinitializedMessage' = 'The detected boot target can now be used safely.'
            'Maintenance.SuccessReadyTitle' = 'System functions ready'
            'Maintenance.SuccessReadyHeading' = 'System functions are ready.'
            'Maintenance.SuccessReadyMessage' = 'Lenovo Boot Selector can now change boot targets.'
            'Update.SuccessTitle' = 'Update successful'
            'Update.SuccessHeading' = 'Lenovo Boot Selector v{Version} is installed.'
            'Update.FailureTitle' = 'Update failed'
            'Update.RestartFailureHeading' = 'The app could not be updated successfully.'
            'Update.AvailableHeading' = 'Lenovo Boot Selector v{Version} is available.'
            'Update.AvailableMessage' = 'You can install the new version now. You can also find the update later in the tray menu under Maintenance → Update app…'
            'Update.InstallNow' = 'Update now'
            'Update.CheckNoResult' = 'The update check did not return a result.'
            'Update.AvailableStatus' = 'New app version available: v{Version}'
            'Update.CurrentStatus' = 'Lenovo Boot Selector is up to date · v{Version}'
            'Update.NoNewTitle' = 'No new version'
            'Update.CurrentHeading' = 'Lenovo Boot Selector v{Version} is up to date.'
            'Update.NoNewMessage' = 'No newer version is currently available.'
            'Update.CheckFailedStatus' = 'Update check failed.'
            'Update.CheckFailedHeading' = 'Checking for a new version failed.'
            'Update.CheckStartFailed' = 'The update check could not be started.'
            'Update.CheckingStatus' = 'Checking for a new version…'
            'Update.InstallerStartFailed' = 'The update installer could not be started.'
            'Update.PrepareNoResult' = 'Update preparation did not return a result.'
            'Update.PrepareFailedHeading' = 'The app could not be updated.'
            'Update.NotPossibleTitle' = 'Update not possible'
            'Update.DirectoryNotWritableHeading' = 'The app folder is not writable.'
            'Update.DirectoryNotWritableMessage' = 'Move Lenovo Boot Selector to a folder that your user account can modify, then try again.'
            'Update.PrepareStartFailed' = 'Update preparation could not be started.'
            'Update.PreparingStatus' = 'Preparing update to v{Version}…'
            'Diagnostics.SavedTitle' = 'Diagnostics saved'
            'Diagnostics.SavedHeading' = 'The diagnostic package was created.'
            'Diagnostics.Location' = "Location:`r`n{Path}"
            'Diagnostics.ShowFolder' = 'Show in folder'
            'Diagnostics.NotSavedTitle' = 'Diagnostics not saved'
            'Diagnostics.NotSavedHeading' = 'The diagnostic package could not be created.'
            'Startup.AlreadyRunningTitle' = 'Lenovo Boot Selector is already running'
            'Startup.FailedTitle' = 'Lenovo Boot Selector could not be started'
            'Startup.AlreadyRunningBody' = 'The app is already open. Close this window and use the existing tray icon.'
            'Startup.FailedSavedBody' = "A problem occurred during startup.`r`nA diagnostic file was saved. You can restart the app or open the diagnostics."
            'Startup.FailedNoDiagnosticBody' = "A problem occurred during startup.`r`nThe diagnostic file could not be saved. You can restart the app."
            'Startup.DiagnosticFile' = 'Diagnostics: {Name}'
            'Startup.NoDiagnosticFile' = 'No diagnostic file is available.'
            'Startup.OpenDiagnostics' = 'Open diagnostics'
            'Startup.Retry' = 'Restart app'
            'Startup.FallbackError' = 'Lenovo Boot Selector could not be started.'
            'Startup.AlreadyRunningMessage' = 'Lenovo Boot Selector is already running.'
            'Status.Ready' = 'Ready.'
            'Default.SystemSavedStatus' = 'System default saved: {Name} · applied 30 s after the next Windows system startup.'
            'Default.SystemDisabledStatus' = 'Automatic system-wide default boot target is disabled.'
            'Status.NextTargetLabel' = 'Next target: {Title}'
            'Boot.DefaultOrder' = 'Default order'
            'Restart.FailedTitle' = 'Restart not possible'
            'Restart.FailedHeading' = 'Windows could not be restarted.'
            'Restart.FailedMessage' = 'Please try again or restart Windows from the Start menu.'
            'Maintenance.Menu.Generic' = 'System functions…'
            'Maintenance.Menu.Reinitializing' = 'Reinitializing system functions…'
            'Maintenance.Menu.Repairing' = 'Repairing system functions…'
            'Maintenance.Menu.SettingUp' = 'Setting up system functions…'
            'Maintenance.Menu.Reinitialize' = 'Reinitialize system functions…'
            'Maintenance.Menu.Repair' = 'Repair system functions…'
            'Status.SystemFunctionsInstalled' = 'System functions are set up.'
            'Status.SetupCompleteRefreshing' = 'Setup complete · refreshing boot targets.'
            'Status.SystemFunctionsNotInstalled' = 'System functions are not set up.'
            'Maintenance.SetupIncompleteTitle' = 'Setup not completed'
            'Maintenance.SetupIncompleteHeading' = 'The system functions could not be set up.'
            'Maintenance.SetupIncompleteMessage' = 'Try the setup again. If the problem persists, diagnostics were saved for further investigation.'
            'Maintenance.FileMissingTitle' = 'Setup not possible'
            'Maintenance.FileMissingHeading' = 'A required app file is missing.'
            'Maintenance.FileMissingMessage' = 'Install or extract Lenovo Boot Selector again, then try once more.'
            'Maintenance.SetupCancelledStatus' = 'Setup was cancelled.'
            'Maintenance.SetupStartFailedStatus' = 'Setup could not be started.'
            'Maintenance.SetupNotStartedTitle' = 'Setup not started'
            'Maintenance.ConfirmationFailedHeading' = 'The Windows confirmation could not be opened.'
            'Status.SystemFunctionsRemoved' = 'System functions were removed.'
            'Status.SystemFunctionsRemoveIncomplete' = 'System functions could not be removed completely.'
            'Maintenance.RemoveIncompleteTitle' = 'Removal not completed'
            'Maintenance.RemoveIncompleteHeading' = 'The system functions could not be removed completely.'
            'Maintenance.RemoveIncompleteMessage' = 'Please try again. Your boot targets and personal app settings will be kept.'
            'Maintenance.RemoveNotPossibleTitle' = 'Removal not possible'
            'Maintenance.RemoveCancelledStatus' = 'Removal was cancelled.'
            'Maintenance.RemoveFailedStatus' = 'System functions could not be removed.'
            'Maintenance.RemoveNotStartedTitle' = 'Removal not started'
            'Status.OneTimeNextBootSet' = 'A one-time next boot target is set.'
            'Status.NoOneTimeNextBoot' = 'No one-time next boot target is set.'
            'Status.BootTargetsReadFailed' = 'Boot targets could not be read.'
            'Status.BootTargetsRefreshFailed' = 'Boot targets could not be refreshed.'
            'Status.RefreshStartFailed' = 'Refresh could not be started.'
            'Manage.EntryHiddenStatus' = 'Entry will be hidden.'
            'Manage.EntryVisibleStatus' = 'Entry will be shown.'
            'Manage.HiddenAccessible' = 'Hidden – click to show'
            'Manage.VisibleAccessible' = 'Visible – click to hide'
            'Update.CheckFailureMessage' = 'The update check could not be completed. Technical details were saved to diagnostics.'
            'Update.PrepareFailureMessage' = 'The update could not be prepared. Technical details were saved to diagnostics.'
            'Update.RestartSuccessMessage' = 'The update completed successfully.'
            'Update.RestartRollbackMessage' = 'The update could not be completed. The previous version was restored.'
            'Update.RestartMismatchMessage' = 'The expected target version v{TargetVersion} was not detected after restart. Currently running v{RunningVersion}.'
            'Update.RestartFailureMessage' = 'The update could not be completed.'
            'Update.HelperFailurePrefix' = 'Update failed:'
            'Update.HelperManualRestart' = 'The app could not be restarted automatically. Please start Lenovo Boot Selector manually.'
            'Tray.Exit' = 'Exit'
        }
        'de-DE' = [ordered]@{
            'Common.OK' = 'OK'
            'Common.Cancel' = 'Abbrechen'
            'Common.Close' = 'Schließen'
            'Common.TryAgain' = 'Bitte versuche es erneut.'
            'Settings.Language' = 'Sprache'
            'Language.English' = 'English'
            'Language.German' = 'Deutsch'
            'Language.MigrationTitle' = 'App-Sprache auswählen'
            'Language.MigrationHeading' = 'Sprache bestätigen'
            'Language.MigrationMessage' = 'Version 0.8.0.0 kann bei einer Aktualisierung automatisch Deutsch ausgewählt haben. Wähle die Sprache, die Lenovo Boot Selector verwenden soll. Diese Auswahl wird gespeichert und nicht automatisch geändert.'
            'Language.MigrationUseEnglish' = 'English verwenden'
            'Language.MigrationKeepGerman' = 'Deutsch verwenden'
            'Progress.StepOf' = 'Schritt {0} von {1}'
            'Storage.InternalSsdModel' = 'Interne SSD: {Model}'
            'Popup.HeaderUpdateAccessible' = 'Öffnet den Dialog zur verfügbaren App-Version.'
            'Status.BootTargetsRefreshing' = 'Startziele werden im Hintergrund aktualisiert…'
            'Action.RefreshBootTargets' = 'Startziele aktualisieren'
            'Popup.NextBootSection' = 'NÄCHSTER START'
            'Popup.Customize' = 'ANPASSEN'
            'Status.ScrollPositionFailed' = 'Scrollposition konnte nicht aktualisiert werden.'
            'Settings.Title' = 'EINSTELLUNGEN'
            'Settings.Autostart' = 'Mit Windows starten'
            'Settings.DefaultTarget' = 'Standard-Startziel'
            'Settings.NoDefaultTarget' = 'Kein Standardziel'
            'Settings.DefaultTargetUnavailable' = 'Nicht verfügbares Startziel'
            'Status.Checking' = 'Wird geprüft …'
            'Action.RestartWindows' = 'Windows neu starten'
            'Status.NextTargetDefaultOrder' = 'Nächstes Ziel: Standardreihenfolge'
            'Manage.Section' = 'STARTZIELE ANPASSEN'
            'Manage.Title' = 'ÄNDERUNGEN'
            'Manage.Hint' = 'Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden'
            'Manage.SubHint' = 'Stift zum Umbenennen · Leer lassen = Originalname'
            'Manage.Save' = 'Änderungen speichern'
            'Manage.StatusEditing' = 'Startziele anpassen · Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden · Stift für Anzeigename'
            'Manage.StatusSaved' = 'Änderungen an den Startzielen wurden gespeichert.'
            'Manage.StatusDiscarded' = 'Änderungen wurden verworfen.'
            'Autostart.Enabled' = 'Autostart ist aktiviert.'
            'Autostart.Disabled' = 'Autostart ist deaktiviert.'
            'Autostart.ErrorHeading' = 'Die Einstellung konnte nicht geändert werden.'
            'Default.SaveErrorHeading' = 'Das Standard-Startziel konnte nicht gespeichert werden.'
            'Default.SaveErrorMessage' = 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.'
            'Status.NewBootTargetDetected' = 'Neues Startziel erkannt · Systemfunktionen neu initialisieren.'
            'Status.BootTargetsChanged' = 'Startziele geändert · Systemfunktionen neu initialisieren.'
            'Status.SystemFunctionsRepairRequired' = 'Systemfunktionen müssen repariert werden.'
            'Status.SystemFunctionsSetupRequired' = 'Systemfunktionen müssen eingerichtet werden.'
            'Header.Refreshing' = 'Aktualisiere Bootziele…'
            'Update.Available' = 'Neue App-Version verfügbar'
            'Tray.Open' = 'Lenovo Boot Selector öffnen'
            'Tray.Maintenance' = 'Wartung'
            'Maintenance.Setup' = 'Systemfunktionen einrichten…'
            'Maintenance.Remove' = 'Systemfunktionen entfernen…'
            'Update.Check' = 'Auf neue Version prüfen…'
            'Update.Install' = 'App aktualisieren…'
            'Diagnostics.Save' = 'Diagnose speichern…'
            'Boot.OtherTarget' = 'Weiteres Startziel'
            'Boot.OtherTargetTooltip' = 'Grau: weiteres Startziel'
            'Boot.MenuTitle' = 'Lenovo Boot-Menü'
            'Boot.MenuSubtitle' = 'Beim nächsten Start das Boot-Menü öffnen'
            'Boot.MenuTooltip' = 'Rot: Lenovo Boot-Menü'
            'Boot.Nvme1Title' = 'NVMe-SSD 1'
            'Boot.Nvme2Title' = 'NVMe-SSD 2'
            'Boot.NoDrive' = 'Kein Laufwerk erkannt'
            'Boot.InternalSsd' = 'Interne SSD'
            'Boot.SecondInternalSsd' = 'Zweite interne SSD'
            'Boot.InternalSsdTooltip' = 'Blau: interne SSD'
            'Boot.UsbTooltip' = 'Gelb: USB-Laufwerk'
            'Boot.UsbChecking' = 'USB-Laufwerke werden geprüft …'
            'Boot.UsbCheckFailed' = 'USB-Laufwerke konnten nicht geprüft werden'
            'Boot.UsbBootMedium' = 'USB-Startmedium: {Model}'
            'Boot.UsbMultipleBoot' = 'Mehrere mögliche USB-Startmedien erkannt'
            'Boot.UsbNonBoot' = '{Model} erkannt · nicht als Startmedium erkannt'
            'Boot.UsbMultipleNoBoot' = 'USB-Laufwerke erkannt · kein Startmedium gefunden'
            'Boot.UsbNone' = 'Kein USB-Laufwerk angeschlossen'
            'Boot.UsbFddTitle' = 'USB-Diskettenlaufwerk'
            'Boot.UsbFddSubtitle' = 'Start von einem USB-Floppy-Laufwerk'
            'Boot.UsbCdTitle' = 'USB-CD/DVD-Laufwerk'
            'Boot.UsbCdSubtitle' = 'Start von einem optischen USB-Laufwerk'
            'Boot.PxeTitle' = 'Netzwerkstart'
            'Boot.PxeSubtitle' = 'Start über das lokale Netzwerk'
            'Boot.PxeTooltip' = 'Violett: Netzwerkstart'
            'Boot.LenovoRecoveryTitle' = 'Lenovo Wiederherstellung'
            'Boot.LenovoRecoverySubtitle' = 'Wiederherstellung über das Netzwerk'
            'Boot.CyanTooltip' = 'Cyan: Lenovo- oder Firmen-Netzwerk'
            'Boot.CorporateTitle' = 'Firmen-Netzwerkstart'
            'Boot.CorporateSubtitle' = 'Start über das Firmennetzwerk'
            'Boot.OtherDriveTitle' = 'Weiteres Laufwerk'
            'Boot.OtherDriveSubtitle' = 'Weiteres erkanntes Laufwerk'
            'Boot.OtherDriveTooltip' = 'Grau: weiteres Laufwerk'
            'Boot.OtherCdTitle' = 'Weiteres CD/DVD-Laufwerk'
            'Boot.OtherCdSubtitle' = 'Anderes optisches Startlaufwerk'
            'Status.NextBootTarget' = 'Nächster Start: {Title}'
            'Status.NextBootSet' = 'Nächstes Startziel wurde gesetzt.'
            'Boot.ChangeErrorTitle' = 'Startziel konnte nicht geändert werden'
            'Boot.ChangeErrorHeading' = 'Die Auswahl wurde nicht übernommen.'
            'Boot.ChangeErrorMessage' = 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.'
            'Manage.OrderChanged' = 'Reihenfolge geändert · Speichern übernimmt die Änderung.'
            'Manage.OriginalName' = 'Originalname: {Name}'
            'Boot.MenuManageSubtitle' = 'Auswahlmenü für das nächste Startziel'
            'Manage.AliasRemoved' = 'Anzeigename entfernt · Speichern übernimmt die Änderung.'
            'Manage.AliasChanged' = 'Anzeigename geändert · Speichern übernimmt die Änderung.'
            'Manage.AliasDiscarded' = 'Änderung am Anzeigenamen verworfen.'
            'Common.Apply' = 'Übernehmen'
            'Manage.OriginalNameHint' = 'Leer lassen = Originalname'
            'Manage.EditAliasAccessible' = 'Anzeigename ändern'
            'Manage.EditAliasStatus' = 'Anzeigename bearbeiten · Enter übernimmt · Esc verwirft · leer = Originalname'
            'Maintenance.Dialog.RemoveTitle' = 'Systemfunktionen entfernen'
            'Maintenance.Dialog.RemoveHeading' = 'Systemfunktionen wirklich entfernen?'
            'Maintenance.Dialog.RemoveBody' = "Danach kann Lenovo Boot Selector keine Startziele mehr ändern, bis die Einrichtung erneut durchgeführt wird.`r`n`r`nDas gespeicherte Standard-Startziel wird zurückgesetzt.`r`n`r`nErhalten bleiben deine vorhandenen Startziele, persönlichen App-Einstellungen und die Autostart-Einstellung."
            'Maintenance.Action.Remove' = 'Entfernen'
            'Maintenance.Dialog.RepairTitle' = 'Systemfunktionen reparieren'
            'Maintenance.Dialog.RepairHeading' = 'Die Systemfunktionen sind bereits eingerichtet.'
            'Maintenance.Dialog.RepairBody' = 'Möchtest du sie erneut einrichten und reparieren? Deine Startziele und persönlichen Einstellungen bleiben dabei erhalten.'
            'Maintenance.Action.Repair' = 'Reparieren'
            'Maintenance.Dialog.MigrateHeading' = 'Die Einrichtung muss aktualisiert werden.'
            'Maintenance.Dialog.MigrateBody' = 'Eine ältere oder unvollständige Einrichtung wurde gefunden. Repariere sie, damit Startziele wieder zuverlässig geändert werden können.'
            'Maintenance.Dialog.ReinitializeTitle' = 'Systemfunktionen neu initialisieren'
            'Maintenance.Dialog.ReinitializeHeading' = 'Neues Startziel erkannt'
            'Maintenance.Dialog.ReinitializeBody' = 'Lenovo Boot Selector hat eine Änderung an den verfügbaren Startzielen erkannt. Initialisiere die Systemfunktionen neu, damit das neue Startziel sicher verwendet werden kann. Deine persönlichen Einstellungen bleiben erhalten.'
            'Maintenance.Action.Reinitialize' = 'Neu initialisieren'
            'Maintenance.Dialog.SetupTitle' = 'Systemfunktionen einrichten'
            'Maintenance.Dialog.SetupHeading' = 'Einmalige Einrichtung erforderlich'
            'Maintenance.Dialog.SetupBody' = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich. Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
            'Maintenance.Action.Setup' = 'Einrichten'
            'Restart.DialogTitle' = 'Windows neu starten'
            'Restart.Question' = 'Windows jetzt neu starten?'
            'Restart.NextTarget' = 'NÄCHSTES ZIEL'
            'Restart.Action' = 'Neu starten'
            'Maintenance.Busy.Remove' = 'Systemfunktionen werden entfernt…'
            'Maintenance.Busy.Reinitialize' = 'Systemfunktionen werden neu initialisiert…'
            'Maintenance.Busy.Repair' = 'Systemfunktionen werden repariert…'
            'Maintenance.Busy.Setup' = 'Systemfunktionen werden eingerichtet…'
            'Maintenance.Caption' = 'SYSTEMFUNKTIONEN'
            'Maintenance.Panel.SetupHeading' = 'Systemfunktionen einrichten'
            'Maintenance.Panel.SetupMessage' = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich.'
            'Maintenance.Panel.SetupHint' = 'Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
            'Maintenance.Panel.RepairHeading' = 'Systemfunktionen reparieren'
            'Maintenance.Panel.RepairMessage' = 'Die vorhandene Einrichtung ist unvollständig oder muss aktualisiert werden.'
            'Maintenance.Panel.RepairHint' = 'Deine persönlichen Einstellungen bleiben dabei erhalten.'
            'Maintenance.Panel.NewTargetHeading' = 'Neues Startziel erkannt'
            'Maintenance.Panel.NewTargetMessage' = 'Lenovo Boot Selector hat ein neues Startziel erkannt. Initialisiere die Systemfunktionen neu, damit es sicher verwendet werden kann.'
            'Maintenance.Panel.TargetsChangedHeading' = 'Startziele wurden geändert'
            'Maintenance.Panel.TargetsChangedMessage' = 'Die verfügbaren Startziele haben sich geändert. Initialisiere die Systemfunktionen neu, damit die Auswahl wieder vollständig passt.'
            'Maintenance.Panel.BusyRemoveMessage' = 'Die Systemfunktionen werden sicher entfernt. Bitte warte einen Moment.'
            'Maintenance.Panel.BusyReinitializeMessage' = 'Windows richtet die Systemfunktionen für die geänderten Startziele neu ein. Bitte warte einen Moment.'
            'Maintenance.Panel.BusySetupMessage' = 'Windows richtet die benötigten Systemfunktionen ein. Bitte warte einen Moment.'
            'Maintenance.Panel.BusyHint' = 'Die App wird nach Abschluss automatisch aktualisiert.'
            'Maintenance.SuccessRemovedTitle' = 'Systemfunktionen entfernt'
            'Maintenance.SuccessRemovedHeading' = 'Systemfunktionen wurden entfernt.'
            'Maintenance.SuccessRemovedMessage' = 'Startziele können wieder geändert werden, nachdem du die Systemfunktionen erneut eingerichtet hast.'
            'Maintenance.SuccessReinitializedTitle' = 'Neu initialisiert'
            'Maintenance.SuccessReinitializedHeading' = 'Systemfunktionen wurden neu initialisiert.'
            'Maintenance.SuccessReinitializedMessage' = 'Das erkannte Startziel kann jetzt sicher verwendet werden.'
            'Maintenance.SuccessReadyTitle' = 'Systemfunktionen bereit'
            'Maintenance.SuccessReadyHeading' = 'Systemfunktionen sind bereit.'
            'Maintenance.SuccessReadyMessage' = 'Lenovo Boot Selector kann jetzt Startziele ändern.'
            'Update.SuccessTitle' = 'Update erfolgreich'
            'Update.SuccessHeading' = 'Lenovo Boot Selector v{Version} ist installiert.'
            'Update.FailureTitle' = 'Update fehlgeschlagen'
            'Update.RestartFailureHeading' = 'Die App konnte nicht erfolgreich aktualisiert werden.'
            'Update.AvailableHeading' = 'Lenovo Boot Selector v{Version} ist verfügbar.'
            'Update.AvailableMessage' = 'Du kannst die neue Version jetzt direkt installieren. Später findest du die Aktualisierung im Tray-Menü unter Wartung → App aktualisieren…'
            'Update.InstallNow' = 'Jetzt aktualisieren'
            'Update.CheckNoResult' = 'Die Update-Prüfung hat kein Ergebnis geliefert.'
            'Update.AvailableStatus' = 'Neue App-Version verfügbar: v{Version}'
            'Update.CurrentStatus' = 'Lenovo Boot Selector ist aktuell · v{Version}'
            'Update.NoNewTitle' = 'Keine neue Version'
            'Update.CurrentHeading' = 'Lenovo Boot Selector v{Version} ist aktuell.'
            'Update.NoNewMessage' = 'Es ist derzeit keine neuere Version verfügbar.'
            'Update.CheckFailedStatus' = 'Update-Prüfung fehlgeschlagen.'
            'Update.CheckFailedHeading' = 'Die Prüfung auf eine neue Version ist fehlgeschlagen.'
            'Update.CheckStartFailed' = 'Die Update-Prüfung konnte nicht gestartet werden.'
            'Update.CheckingStatus' = 'Auf neue Version wird geprüft…'
            'Update.InstallerStartFailed' = 'Update-Installer konnte nicht gestartet werden.'
            'Update.PrepareNoResult' = 'Die Update-Vorbereitung hat kein Ergebnis geliefert.'
            'Update.PrepareFailedHeading' = 'Die App konnte nicht aktualisiert werden.'
            'Update.NotPossibleTitle' = 'Update nicht möglich'
            'Update.DirectoryNotWritableHeading' = 'Der App-Ordner ist nicht beschreibbar.'
            'Update.DirectoryNotWritableMessage' = 'Verschiebe Lenovo Boot Selector in einen Ordner, den dein Benutzerkonto ändern darf, und versuche es erneut.'
            'Update.PrepareStartFailed' = 'Update-Vorbereitung konnte nicht gestartet werden.'
            'Update.PreparingStatus' = 'Update auf v{Version} wird vorbereitet…'
            'Diagnostics.SavedTitle' = 'Diagnose gespeichert'
            'Diagnostics.SavedHeading' = 'Das Diagnosepaket wurde erstellt.'
            'Diagnostics.Location' = "Speicherort:`r`n{Path}"
            'Diagnostics.ShowFolder' = 'Im Ordner anzeigen'
            'Diagnostics.NotSavedTitle' = 'Diagnose nicht gespeichert'
            'Diagnostics.NotSavedHeading' = 'Das Diagnosepaket konnte nicht erstellt werden.'
            'Startup.AlreadyRunningTitle' = 'Lenovo Boot Selector läuft bereits'
            'Startup.FailedTitle' = 'Lenovo Boot Selector konnte nicht gestartet werden'
            'Startup.AlreadyRunningBody' = 'Die App ist bereits geöffnet. Schließe dieses Fenster und verwende das vorhandene Tray-Symbol.'
            'Startup.FailedSavedBody' = "Beim Start ist ein Problem aufgetreten.`r`nEine Diagnose wurde gespeichert. Du kannst die App erneut starten oder die Diagnose öffnen."
            'Startup.FailedNoDiagnosticBody' = "Beim Start ist ein Problem aufgetreten.`r`nDie Diagnose konnte nicht gespeichert werden. Du kannst die App erneut starten."
            'Startup.DiagnosticFile' = 'Diagnose: {Name}'
            'Startup.NoDiagnosticFile' = 'Keine Diagnose-Datei verfügbar.'
            'Startup.OpenDiagnostics' = 'Diagnose öffnen'
            'Startup.Retry' = 'Erneut starten'
            'Startup.FallbackError' = 'Lenovo Boot Selector konnte nicht gestartet werden.'
            'Startup.AlreadyRunningMessage' = 'Lenovo Boot Selector läuft bereits.'
            'Status.Ready' = 'Bereit.'
            'Default.SystemSavedStatus' = 'Systemstandard gespeichert: {Name} · wird 30 s nach dem nächsten Windows-Systemstart gesetzt.'
            'Default.SystemDisabledStatus' = 'Automatisches systemweites Standard-Startziel ist deaktiviert.'
            'Status.NextTargetLabel' = 'Nächstes Ziel: {Title}'
            'Boot.DefaultOrder' = 'Standardreihenfolge'
            'Restart.FailedTitle' = 'Neustart nicht möglich'
            'Restart.FailedHeading' = 'Windows konnte nicht neu gestartet werden.'
            'Restart.FailedMessage' = 'Bitte versuche es erneut oder starte Windows über das Startmenü neu.'
            'Maintenance.Menu.Generic' = 'Systemfunktionen…'
            'Maintenance.Menu.Reinitializing' = 'Systemfunktionen werden neu initialisiert…'
            'Maintenance.Menu.Repairing' = 'Systemfunktionen werden repariert…'
            'Maintenance.Menu.SettingUp' = 'Systemfunktionen werden eingerichtet…'
            'Maintenance.Menu.Reinitialize' = 'Systemfunktionen neu initialisieren…'
            'Maintenance.Menu.Repair' = 'Systemfunktionen reparieren…'
            'Status.SystemFunctionsInstalled' = 'Systemfunktionen sind eingerichtet.'
            'Status.SetupCompleteRefreshing' = 'Einrichtung abgeschlossen · Startziele werden erneut aktualisiert.'
            'Status.SystemFunctionsNotInstalled' = 'Systemfunktionen sind nicht eingerichtet.'
            'Maintenance.SetupIncompleteTitle' = 'Einrichtung nicht abgeschlossen'
            'Maintenance.SetupIncompleteHeading' = 'Die Systemfunktionen konnten nicht eingerichtet werden.'
            'Maintenance.SetupIncompleteMessage' = 'Bitte versuche die Einrichtung erneut. Falls das Problem bestehen bleibt, wurde eine Diagnose für die weitere Prüfung gespeichert.'
            'Maintenance.FileMissingTitle' = 'Einrichtung nicht möglich'
            'Maintenance.FileMissingHeading' = 'Eine benötigte App-Datei fehlt.'
            'Maintenance.FileMissingMessage' = 'Bitte installiere oder entpacke Lenovo Boot Selector erneut und versuche es danach noch einmal.'
            'Maintenance.SetupCancelledStatus' = 'Einrichtung wurde abgebrochen.'
            'Maintenance.SetupStartFailedStatus' = 'Einrichtung konnte nicht gestartet werden.'
            'Maintenance.SetupNotStartedTitle' = 'Einrichtung nicht gestartet'
            'Maintenance.ConfirmationFailedHeading' = 'Die Windows-Bestätigung konnte nicht geöffnet werden.'
            'Status.SystemFunctionsRemoved' = 'Systemfunktionen wurden entfernt.'
            'Status.SystemFunctionsRemoveIncomplete' = 'Systemfunktionen konnten nicht vollständig entfernt werden.'
            'Maintenance.RemoveIncompleteTitle' = 'Entfernen nicht abgeschlossen'
            'Maintenance.RemoveIncompleteHeading' = 'Die Systemfunktionen konnten nicht vollständig entfernt werden.'
            'Maintenance.RemoveIncompleteMessage' = 'Bitte versuche es erneut. Deine Startziele und persönlichen App-Einstellungen bleiben erhalten.'
            'Maintenance.RemoveNotPossibleTitle' = 'Entfernen nicht möglich'
            'Maintenance.RemoveCancelledStatus' = 'Entfernen wurde abgebrochen.'
            'Maintenance.RemoveFailedStatus' = 'Systemfunktionen konnten nicht entfernt werden.'
            'Maintenance.RemoveNotStartedTitle' = 'Entfernen nicht gestartet'
            'Status.OneTimeNextBootSet' = 'Ein einmaliges Startziel ist gesetzt.'
            'Status.NoOneTimeNextBoot' = 'Kein einmaliges Startziel gesetzt.'
            'Status.BootTargetsReadFailed' = 'Startziele konnten nicht gelesen werden.'
            'Status.BootTargetsRefreshFailed' = 'Startziele konnten nicht aktualisiert werden.'
            'Status.RefreshStartFailed' = 'Aktualisierung konnte nicht gestartet werden.'
            'Manage.EntryHiddenStatus' = 'Eintrag wird ausgeblendet.'
            'Manage.EntryVisibleStatus' = 'Eintrag wird angezeigt.'
            'Manage.HiddenAccessible' = 'Verborgen – klicken zum Einblenden'
            'Manage.VisibleAccessible' = 'Sichtbar – klicken zum Ausblenden'
            'Update.CheckFailureMessage' = 'Die Update-Prüfung konnte nicht abgeschlossen werden. Technische Details wurden in der Diagnose gespeichert.'
            'Update.PrepareFailureMessage' = 'Das Update konnte nicht vorbereitet werden. Technische Details wurden in der Diagnose gespeichert.'
            'Update.RestartSuccessMessage' = 'Die Aktualisierung wurde erfolgreich abgeschlossen.'
            'Update.RestartRollbackMessage' = 'Die Aktualisierung konnte nicht abgeschlossen werden. Die vorherige Version wurde wiederhergestellt.'
            'Update.RestartMismatchMessage' = 'Die erwartete Zielversion v{TargetVersion} wurde nach dem Neustart nicht erkannt. Aktuell läuft v{RunningVersion}.'
            'Update.RestartFailureMessage' = 'Die Aktualisierung konnte nicht abgeschlossen werden.'
            'Update.HelperFailurePrefix' = 'Update fehlgeschlagen:'
            'Update.HelperManualRestart' = 'Die App konnte nicht automatisch neu gestartet werden. Bitte starte Lenovo Boot Selector manuell.'
            'Tray.Exit' = 'Beenden'
        }
    }
}

function Get-LocalizationKeySetCore {
    param([string]$Locale = 'en-US')

    $resolved = Resolve-LocaleIdCore -Locale $Locale
    $catalogs = Get-LocalizationCatalogCore
    return @($catalogs[$resolved].Keys | ForEach-Object { [string]$_ } | Sort-Object)
}

function Test-LocalizationCatalogParityCore {
    $reference = @(Get-LocalizationKeySetCore -Locale 'en-US')
    foreach ($locale in @(Get-SupportedLocaleIdsCore)) {
        $keys = @(Get-LocalizationKeySetCore -Locale $locale)
        if ($keys.Count -ne $reference.Count) { return $false }
        for ($i = 0; $i -lt $reference.Count; $i++) {
            if ($keys[$i] -ne $reference[$i]) { return $false }
        }
    }
    return $true
}

function Get-LocalizedStringCore {
    param(
        [Parameter(Mandatory=$true)][string]$Key,
        [string]$Locale = 'en-US',
        [object[]]$Arguments,
        [System.Collections.IDictionary]$Values
    )

    $resolved = Resolve-LocaleIdCore -Locale $Locale
    $catalogs = Get-LocalizationCatalogCore
    $active = $catalogs[$resolved]
    $english = $catalogs['en-US']

    if ($active.Contains($Key)) {
        $text = [string]$active[$Key]
    }
    elseif ($english.Contains($Key)) {
        $text = [string]$english[$Key]
    }
    else {
        return $Key
    }

    if ($Values) {
        foreach ($name in @($Values.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
            $text = $text.Replace(('{' + $name + '}'), [string]$Values[$name])
        }
    }

    if ($null -ne $Arguments -and @($Arguments).Count -gt 0) {
        try { $text = $text -f @($Arguments) } catch { }
    }
    return $text
}

# Lenovo Boot Selector v0.4.1 - Functional Core: entry preferences/settings normalization
# Pure/deterministic functions only. No global script state, WinForms, filesystem, registry,
# Scheduled Tasks, process starts, or privileged broker access are permitted in this file.

function Convert-EntryAliasesToHashtable {
    param($Source)

    $result = @{}
    if (-not $Source) { return $result }

    if ($Source -is [System.Collections.IDictionary]) {
        foreach ($key in @($Source.Keys)) {
            if (-not $key) { continue }
            $normalized = ([string]$key).ToLowerInvariant()
            $value = ([string]$Source[$key]).Trim()
            if ($value) { $result[$normalized] = $value }
        }
        return $result
    }

    foreach ($property in @($Source.PSObject.Properties)) {
        if (-not $property.Name) { continue }
        $normalized = ([string]$property.Name).ToLowerInvariant()
        $value = ([string]$property.Value).Trim()
        if ($value) { $result[$normalized] = $value }
    }
    return $result
}
function Copy-EntryAliasMap {
    param($Source)
    $copy = @{}
    if (-not $Source) { return $copy }
    foreach ($key in @($Source.Keys)) {
        $value = ([string]$Source[$key]).Trim()
        if ($key -and $value) { $copy[([string]$key).ToLowerInvariant()] = $value }
    }
    return $copy
}
function Test-StringSequenceEqual {
    param([object[]]$Left, [object[]]$Right, [switch]$Sort)
    $a = @($Left | ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } })
    $b = @($Right | ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } })
    if ($Sort) { $a = @($a | Sort-Object -Unique); $b = @($b | Sort-Object -Unique) }
    if ($a.Count -ne $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) {
        if ($a[$i] -ne $b[$i]) { return $false }
    }
    return $true
}
function Test-EntryAliasMapsEqual {
    param($Left, $Right)
    $a = Copy-EntryAliasMap $Left
    $b = Copy-EntryAliasMap $Right
    $aKeys = @($a.Keys | Sort-Object)
    $bKeys = @($b.Keys | Sort-Object)
    if (-not (Test-StringSequenceEqual -Left $aKeys -Right $bKeys)) { return $false }
    foreach ($key in $aKeys) {
        if (([string]$a[$key]).Trim() -ne ([string]$b[$key]).Trim()) { return $false }
    }
    return $true
}
function Test-GuidInList {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [object[]]$List
    )
    $normalized = $Guid.ToLowerInvariant()
    foreach ($item in @($List)) {
        if ([string]$item -and ([string]$item).ToLowerInvariant() -eq $normalized) { return $true }
    }
    return $false
}
function Get-AppSettingsSourcePropertyCore {
    param(
        $Source,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if (-not $Source) {
        return [pscustomobject]@{ HasValue = $false; Value = $null }
    }

    if ($Source -is [System.Collections.IDictionary]) {
        foreach ($key in @($Source.Keys)) {
            if ([string]$key -and ([string]$key).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return [pscustomobject]@{ HasValue = $true; Value = $Source[$key] }
            }
        }
        return [pscustomobject]@{ HasValue = $false; Value = $null }
    }

    $property = $Source.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return [pscustomobject]@{ HasValue = $true; Value = $property.Value }
    }
    return [pscustomobject]@{ HasValue = $false; Value = $null }
}

function Get-AppSettingsLocalePreferenceSourceCore {
    param(
        $Source,
        [int]$SourceSchemaVersion
    )

    if (-not $Source) { return 'default' }

    $sourceProperty = Get-AppSettingsSourcePropertyCore -Source $Source -Name 'localePreferenceSource'
    if ($sourceProperty.HasValue) {
        $value = ([string]$sourceProperty.Value).Trim().ToLowerInvariant()
        if ($value -in @('default','user','migration-pending')) { return $value }
    }

    # v0.8.0.0 persisted schema 5 with locale=de-DE both for the incorrect
    # automatic migration and for a possible explicit user choice. Without
    # additional metadata those states are indistinguishable, so preserve the
    # current locale temporarily and require one explicit choice.
    if ($SourceSchemaVersion -eq 5) {
        $localeProperty = Get-AppSettingsSourcePropertyCore -Source $Source -Name 'locale'
        if ($localeProperty.HasValue -and (Resolve-LocaleIdCore -Locale ([string]$localeProperty.Value)) -eq 'de-DE') {
            return 'migration-pending'
        }
    }

    return 'default'
}

function Get-AppSettingsLocaleCore {
    param(
        $Source,
        [int]$SourceSchemaVersion
    )

    if (-not $Source) { return 'en-US' }

    $preferenceSource = Get-AppSettingsLocalePreferenceSourceCore -Source $Source -SourceSchemaVersion $SourceSchemaVersion
    if ($preferenceSource -in @('user','migration-pending')) {
        $localeProperty = Get-AppSettingsSourcePropertyCore -Source $Source -Name 'locale'
        if ($localeProperty.HasValue) {
            return Resolve-LocaleIdCore -Locale ([string]$localeProperty.Value)
        }
    }

    # English is the canonical default whenever there is no demonstrable
    # explicit user preference.
    return 'en-US'
}

function Test-AppSettingsLocaleConfirmationRequiredCore {
    param(
        $Source,
        [int]$SourceSchemaVersion
    )

    return ((Get-AppSettingsLocalePreferenceSourceCore -Source $Source -SourceSchemaVersion $SourceSchemaVersion) -eq 'migration-pending')
}

function New-DefaultAppSettingsCore {
    return [pscustomobject]@{
        schemaVersion = 6
        locale = 'en-US'
        localePreferenceSource = 'default'
        localePreferenceNeedsConfirmation = $false
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = @{}
    }
}

function ConvertTo-NormalizedAppSettingsCore {
    param($Source)

    if (-not $Source) { return New-DefaultAppSettingsCore }

    $sourceSchemaVersion = if ($Source.schemaVersion) { [int]$Source.schemaVersion } else { 1 }
    $preferenceSource = Get-AppSettingsLocalePreferenceSourceCore -Source $Source -SourceSchemaVersion $sourceSchemaVersion

    return [pscustomobject]@{
        schemaVersion = 6
        locale = Get-AppSettingsLocaleCore -Source $Source -SourceSchemaVersion $sourceSchemaVersion
        localePreferenceSource = $preferenceSource
        localePreferenceNeedsConfirmation = ($preferenceSource -eq 'migration-pending')
        # defaultGuid is retained only as an upgrade/migration input from
        # v0.2.21 and earlier. v0.2.22 stores the live default system-wide.
        defaultGuid = if ($Source.defaultGuid) { ([string]$Source.defaultGuid).ToLowerInvariant() } else { $null }
        entryOrder = @(
            @($Source.entryOrder) |
                ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } } |
                Select-Object -Unique
        )
        hiddenEntryGuids = @(
            @($Source.hiddenEntryGuids) |
                ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } } |
                Select-Object -Unique
        )
        entryAliases = Convert-EntryAliasesToHashtable $Source.entryAliases
    }
}

function Get-OrderedEntriesCore {
    param(
        [object[]]$Source,
        [object[]]$Order,
        [object[]]$Hidden,
        [switch]$IncludeHidden
    )

    $sourceItems = @($Source)
    if ($sourceItems.Count -eq 0) { return @() }

    $result = New-Object System.Collections.Generic.List[object]
    $added = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($guid in @($Order)) {
        if (-not $guid) { continue }
        $entry = $sourceItems | Where-Object { $_.Guid -eq ([string]$guid).ToLowerInvariant() } | Select-Object -First 1
        if ($entry -and $added.Add([string]$entry.Guid)) {
            if ($IncludeHidden -or -not (Test-GuidInList -Guid $entry.Guid -List $Hidden)) {
                [void]$result.Add($entry)
            }
        }
    }

    foreach ($entry in $sourceItems) {
        if ($added.Add([string]$entry.Guid)) {
            if ($IncludeHidden -or -not (Test-GuidInList -Guid $entry.Guid -List $Hidden)) {
                [void]$result.Add($entry)
            }
        }
    }

    return @($result.ToArray())
}

function Get-StartupRecoveryLocale {
    try {
        $settingsPath = Join-Path (Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray') 'settings.json'
        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return 'en-US' }
        $source = ([System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
        $sourceSchema = if ($source.schemaVersion) { [int]$source.schemaVersion } else { 1 }
        return (Get-AppSettingsLocaleCore -Source $source -SourceSchemaVersion $sourceSchema)
    }
    catch { }
    return 'en-US'
}

function Show-FatalMessage([string]$Message, [bool]$AllowRestart = $true) {
    $diagnosticSaved = $false
    $diagDir = $null
    $diagPath = $null
    try {
        $diagDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
        if (-not (Test-Path -LiteralPath $diagDir)) { [void](New-Item -ItemType Directory -Path $diagDir -Force) }
        $diagPath = Join-Path $diagDir ("RuntimeError-{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        $diagText = "Lenovo Boot Selector runtime error`r`nTime: $([datetime]::Now.ToString('o'))`r`n`r`n$Message"
        [System.IO.File]::WriteAllText($diagPath, $diagText, [System.Text.Encoding]::UTF8)
        $diagnosticSaved = $true
    } catch { }

    try {
        $locale = Get-StartupRecoveryLocale
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $isAlreadyRunning = (-not $AllowRestart)
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Lenovo Boot Selector'
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.ShowInTaskbar = $false
        $form.ShowIcon = $true
        $form.TopMost = $true
        $form.ClientSize = New-Object System.Drawing.Size(560, 242)
        $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
        $form.ForeColor = [System.Drawing.Color]::FromArgb(238, 238, 238)
        $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
        $form.Tag = 'close'

        $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
        if (Test-Path -LiteralPath $iconPath) {
            try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch { }
        }

        $accent = New-Object System.Windows.Forms.Panel
        $accent.Location = New-Object System.Drawing.Point(0, 0)
        $accent.Size = New-Object System.Drawing.Size(5, 242)
        $accent.BackColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $form.Controls.Add($accent)

        $badge = New-Object System.Windows.Forms.Label
        $badge.Text = '!'
        $badge.Location = New-Object System.Drawing.Point(24, 28)
        $badge.Size = New-Object System.Drawing.Size(38, 38)
        $badge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $badge.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18.0, [System.Drawing.FontStyle]::Bold)
        $badge.ForeColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $badge.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $form.Controls.Add($badge)

        $title = New-Object System.Windows.Forms.Label
        $title.Location = New-Object System.Drawing.Point(78, 24)
        $title.Size = New-Object System.Drawing.Size(452, 28)
        $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11.0, [System.Drawing.FontStyle]::Bold)
        $title.ForeColor = [System.Drawing.Color]::White
        $title.Text = $(if ($isAlreadyRunning) { Get-LocalizedStringCore -Key 'Startup.AlreadyRunningTitle' -Locale $locale } else { Get-LocalizedStringCore -Key 'Startup.FailedTitle' -Locale $locale })
        $form.Controls.Add($title)

        $body = New-Object System.Windows.Forms.Label
        $body.Location = New-Object System.Drawing.Point(78, 60)
        $body.Size = New-Object System.Drawing.Size(452, 70)
        $body.Font = New-Object System.Drawing.Font('Segoe UI', 9.0, [System.Drawing.FontStyle]::Regular)
        $body.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
        if ($isAlreadyRunning) {
            $body.Text = Get-LocalizedStringCore -Key 'Startup.AlreadyRunningBody' -Locale $locale
        }
        elseif ($diagnosticSaved) {
            $body.Text = Get-LocalizedStringCore -Key 'Startup.FailedSavedBody' -Locale $locale
        }
        else {
            $body.Text = Get-LocalizedStringCore -Key 'Startup.FailedNoDiagnosticBody' -Locale $locale
        }
        $form.Controls.Add($body)

        $diagLabel = New-Object System.Windows.Forms.Label
        $diagLabel.Location = New-Object System.Drawing.Point(78, 136)
        $diagLabel.Size = New-Object System.Drawing.Size(452, 24)
        $diagLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8.0, [System.Drawing.FontStyle]::Regular)
        $diagLabel.ForeColor = [System.Drawing.Color]::FromArgb(145, 145, 145)
        if ($diagnosticSaved -and $diagPath) {
            $diagLabel.Text = Get-LocalizedStringCore -Key 'Startup.DiagnosticFile' -Locale $locale -Values @{ Name=(Split-Path -Leaf $diagPath) }
        }
        elseif (-not $isAlreadyRunning) {
            $diagLabel.Text = Get-LocalizedStringCore -Key 'Startup.NoDiagnosticFile' -Locale $locale
        }
        $form.Controls.Add($diagLabel)

        $buttonBar = New-Object System.Windows.Forms.Panel
        $buttonBar.Location = New-Object System.Drawing.Point(5, 178)
        $buttonBar.Size = New-Object System.Drawing.Size(555, 64)
        $buttonBar.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 31)
        $form.Controls.Add($buttonBar)

        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = Get-LocalizedStringCore -Key 'Common.Close' -Locale $locale
        $closeButton.Location = New-Object System.Drawing.Point(433, 16)
        $closeButton.Size = New-Object System.Drawing.Size(100, 32)
        $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $closeButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $closeButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $closeButton.ForeColor = [System.Drawing.Color]::White
        $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $closeButton.Add_Click({ $form.Tag = 'close'; $form.Close() })
        $buttonBar.Controls.Add($closeButton)
        $form.CancelButton = $closeButton

        $diagnosticButton = New-Object System.Windows.Forms.Button
        $diagnosticButton.Text = Get-LocalizedStringCore -Key 'Startup.OpenDiagnostics' -Locale $locale
        $diagnosticButton.Location = New-Object System.Drawing.Point(279, 16)
        $diagnosticButton.Size = New-Object System.Drawing.Size(142, 32)
        $diagnosticButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $diagnosticButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $diagnosticButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $diagnosticButton.ForeColor = [System.Drawing.Color]::White
        $diagnosticButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $diagnosticButton.Enabled = [bool]($diagnosticSaved -and $diagDir)
        $diagnosticButton.Add_Click({
            try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $diagDir) | Out-Null } catch { }
        })
        $buttonBar.Controls.Add($diagnosticButton)

        $retryButton = New-Object System.Windows.Forms.Button
        $retryButton.Text = Get-LocalizedStringCore -Key 'Startup.Retry' -Locale $locale
        $retryButton.Location = New-Object System.Drawing.Point(125, 16)
        $retryButton.Size = New-Object System.Drawing.Size(142, 32)
        $retryButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $retryButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $retryButton.BackColor = [System.Drawing.Color]::FromArgb(64, 31, 29)
        $retryButton.ForeColor = [System.Drawing.Color]::White
        $retryButton.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.0, [System.Drawing.FontStyle]::Bold)
        $launcherAvailable = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
        $retryButton.Enabled = [bool]($AllowRestart -and -not $isAlreadyRunning -and $launcherAvailable)
        $retryButton.Add_Click({ $form.Tag = 'retry'; $form.Close() })
        $buttonBar.Controls.Add($retryButton)

        if ($retryButton.Enabled) { $form.AcceptButton = $retryButton } else { $form.AcceptButton = $closeButton }
        [void]$form.ShowDialog()
        $action = [string]$form.Tag
        $form.Dispose()
        return $action
    }
    catch {
        # Fallback remains owner-bound and taskbar-silent. If WinForms itself is
        # unavailable, fall back to stderr without creating a visible console.
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $owner = New-Object System.Windows.Forms.Form
            $owner.ShowInTaskbar = $false
            $owner.Opacity = 0
            $owner.Size = New-Object System.Drawing.Size(1, 1)
            $owner.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $owner.Location = New-Object System.Drawing.Point(-32000, -32000)
            $owner.Show()
            [System.Windows.Forms.MessageBox]::Show(
                $owner,
                (Get-LocalizedStringCore -Key 'Startup.FallbackError' -Locale $locale),
                'Lenovo Boot Selector',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            $owner.Close()
            $owner.Dispose()
        }
        catch {
            Write-Error $Message
        }
        return 'close'
    }
}


# v0.2.18: The tray intentionally runs unelevated. Privileged firmware operations
# are delegated to fixed, pre-authorized Windows Scheduled Tasks. No custom EXE
# runs under SYSTEM.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# v0.3.3: item-local ToolStrip renderer coordinate hotfix; v0.2.22 TaskBroker security architecture remains unchanged.
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class LenovoMenuColorTable : ProfessionalColorTable
{
    private readonly Color accent = Color.FromArgb(225, 37, 27);
    private readonly Color bg = Color.FromArgb(22, 22, 22);
    private readonly Color selected = Color.FromArgb(64, 31, 29);

    public LenovoMenuColorTable() { UseSystemColors = false; }
    public override Color ToolStripDropDownBackground { get { return bg; } }
    public override Color ImageMarginGradientBegin { get { return bg; } }
    public override Color ImageMarginGradientMiddle { get { return bg; } }
    public override Color ImageMarginGradientEnd { get { return bg; } }
    public override Color ImageMarginRevealedGradientBegin { get { return bg; } }
    public override Color ImageMarginRevealedGradientMiddle { get { return bg; } }
    public override Color ImageMarginRevealedGradientEnd { get { return bg; } }
    public override Color MenuBorder { get { return bg; } }
    public override Color MenuItemBorder { get { return selected; } }
    public override Color MenuItemSelected { get { return selected; } }
    public override Color MenuItemSelectedGradientBegin { get { return selected; } }
    public override Color MenuItemSelectedGradientEnd { get { return selected; } }
    public override Color MenuItemPressedGradientBegin { get { return selected; } }
    public override Color MenuItemPressedGradientMiddle { get { return selected; } }
    public override Color MenuItemPressedGradientEnd { get { return selected; } }
    public override Color SeparatorDark { get { return accent; } }
    public override Color SeparatorLight { get { return bg; } }
    public override Color CheckBackground { get { return bg; } }
    public override Color CheckSelectedBackground { get { return selected; } }
    public override Color CheckPressedBackground { get { return selected; } }
    public override Color ButtonSelectedHighlight { get { return selected; } }
    public override Color ButtonSelectedHighlightBorder { get { return selected; } }
    public override Color ToolStripBorder { get { return bg; } }
    public override Color ToolStripGradientBegin { get { return bg; } }
    public override Color ToolStripGradientMiddle { get { return bg; } }
    public override Color ToolStripGradientEnd { get { return bg; } }
}

public sealed class LenovoMenuRenderer : ToolStripProfessionalRenderer
{
    private readonly Color accent = Color.FromArgb(225, 37, 27);
    private readonly Color rootBg = Color.FromArgb(22, 22, 22);
    private readonly Color submenuBg = Color.FromArgb(32, 32, 32);
    private readonly Color submenuEdge = Color.FromArgb(68, 68, 68);
    private readonly Color selected = Color.FromArgb(64, 31, 29);
    private readonly Color arrow = Color.FromArgb(214, 214, 214);
    private readonly Color disabled = Color.FromArgb(105, 105, 105);

    public LenovoMenuRenderer() : base(new LenovoMenuColorTable()) { }

    private static bool IsSubmenu(ToolStrip strip)
    {
        ToolStripDropDown dd = strip as ToolStripDropDown;
        return dd != null && dd.OwnerItem != null;
    }

    private static Rectangle FullRowBounds(ToolStripDropDown menu, ToolStripItem item)
    {
        int inset = IsSubmenu(menu) ? 1 : 0;

        // ToolStrip item render callbacks use an item-local Graphics origin.
        // Convert the DropDown client edges into that local coordinate system
        // instead of applying the item offset a second time.
        int left = inset - item.Bounds.Left;
        int right = menu.ClientRectangle.Right - inset - item.Bounds.Left;
        int width = Math.Max(1, right - left);
        return new Rectangle(left, 0, width, Math.Max(1, item.Height));
    }

    private void DrawRightCheck(Graphics g, Rectangle row, bool enabled)
    {
        int size = 14;
        int x = Math.Max(row.Left + 2, row.Right - 24);
        int y = row.Top + Math.Max(1, (row.Height - size) / 2);
        Rectangle box = new Rectangle(x, y, size, size);
        SmoothingMode oldMode = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (Brush brush = new SolidBrush(enabled ? accent : disabled))
            g.FillRectangle(brush, box);
        using (Pen pen = new Pen(Color.White, 1.8f))
        {
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            g.DrawLines(pen, new Point[] {
                new Point(box.Left + 3, box.Top + 7),
                new Point(box.Left + 6, box.Top + 10),
                new Point(box.Left + 11, box.Top + 4)
            });
        }
        g.SmoothingMode = oldMode;
    }

    private void DrawRightArrow(Graphics g, Rectangle row, bool enabled)
    {
        int cx = row.Right - 15;
        int cy = row.Top + (row.Height / 2);
        Color c = enabled ? arrow : disabled;
        using (Brush brush = new SolidBrush(c))
        {
            Point[] points = new Point[] {
                new Point(cx - 2, cy - 4),
                new Point(cx + 2, cy),
                new Point(cx - 2, cy + 4)
            };
            g.FillPolygon(brush, points);
        }
    }

    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        if (dropDown == null)
        {
            base.OnRenderToolStripBackground(e);
            return;
        }

        bool submenu = IsSubmenu(dropDown);
        GraphicsState ownerState = e.Graphics.Save();
        e.Graphics.ResetClip();
        using (Brush bgBrush = new SolidBrush(submenu ? submenuBg : rootBg))
            e.Graphics.FillRectangle(bgBrush, new Rectangle(Point.Empty, dropDown.ClientRectangle.Size));

        // v0.3.4: Paint the active row in ToolStrip owner coordinates.
        // Per-item renderer Graphics instances are clipped by WinForms to the
        // item/content area and cannot reliably cover the reserved right-side
        // padding/grip region. The ToolStrip background renderer owns the full
        // client surface, so the highlight can extend to the true client edge.
        ToolStripMenuItem hotItem = LenovoMenuLayout.GetVisualHotItem(dropDown);
        if (hotItem != null && hotItem.Enabled)
        {
            int inset = submenu ? 1 : 0;
            int left = dropDown.ClientRectangle.Left + inset;
            int right = dropDown.ClientRectangle.Right - inset;
            int top = Math.Max(dropDown.ClientRectangle.Top, hotItem.Bounds.Top);
            int bottom = Math.Min(dropDown.ClientRectangle.Bottom, hotItem.Bounds.Bottom);
            if (right > left && bottom > top)
            {
                using (Brush selectionBrush = new SolidBrush(selected))
                    e.Graphics.FillRectangle(selectionBrush, new Rectangle(left, top, right - left, bottom - top));
            }
        }

        // Submenus remain visually distinct without any red outer border.
        if (submenu && dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            using (Pen edgePen = new Pen(submenuEdge, 1f))
                e.Graphics.DrawRectangle(edgePen, 0, 0, dropDown.ClientSize.Width - 1, dropDown.ClientSize.Height - 1);
        }
        e.Graphics.Restore(ownerState);
    }

    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
    {
        if (e.ToolStrip is ToolStripDropDown) return;
        base.OnRenderToolStripBorder(e);
    }

    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        if (dropDown == null)
        {
            base.OnRenderSeparator(e);
            return;
        }

        bool submenu = IsSubmenu(dropDown);
        int inset = submenu ? 1 : 0;

        // Separator render callbacks are item-local as well. Translate only
        // the horizontal DropDown client edges; Y starts at this item.
        int left = inset - e.Item.Bounds.Left;
        int right = dropDown.ClientRectangle.Right - 1 - inset - e.Item.Bounds.Left;
        int y = Math.Max(0, e.Item.Height / 2);
        GraphicsState state = e.Graphics.Save();
        e.Graphics.ResetClip();
        using (Pen pen = new Pen(accent, 1f))
            e.Graphics.DrawLine(pen, left, y, Math.Max(left + 1, right), y);
        e.Graphics.Restore(state);
    }

    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        ToolStripMenuItem item = e.Item as ToolStripMenuItem;
        if (dropDown == null || item == null)
        {
            base.OnRenderMenuItemBackground(e);
            return;
        }

        Rectangle row = FullRowBounds(dropDown, item);
        GraphicsState state = e.Graphics.Save();
        e.Graphics.ResetClip();

        // v0.3.4: The full-width selection background is painted once in
        // OnRenderToolStripBackground, where the Graphics surface spans the
        // actual DropDown client area. Keep this item-local pass for indicators
        // only; drawing the highlight here reintroduces the right-edge clipping.

        // Indicators remain item-local and are painted after the background.
        if (item.HasDropDownItems)
            DrawRightArrow(e.Graphics, row, item.Enabled);
        else if (item.Checked)
            DrawRightCheck(e.Graphics, row, item.Enabled);

        e.Graphics.Restore(state);
    }

    protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
    {
        // Checked state is rendered centrally by OnRenderMenuItemBackground.
    }

    protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
    {
        // Submenu arrows are rendered centrally by OnRenderMenuItemBackground.
    }
}

public static class LenovoMenuLayout
{
    public static ToolStripItem HitTestRow(ToolStripDropDown menu, Point clientPoint)
    {
        if (menu == null || menu.IsDisposed || !menu.ClientRectangle.Contains(clientPoint)) return null;
        foreach (ToolStripItem item in menu.Items)
        {
            if (item == null || !item.Available || !(item is ToolStripMenuItem)) continue;
            Rectangle bounds = item.Bounds;
            if (clientPoint.Y >= bounds.Top && clientPoint.Y < bounds.Bottom)
                return item;
        }
        return null;
    }

    public static ToolStripMenuItem GetVisualHotItem(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return null;
        try
        {
            Point point = menu.PointToClient(Control.MousePosition);
            if (menu.ClientRectangle.Contains(point))
            {
                ToolStripMenuItem hit = HitTestRow(menu, point) as ToolStripMenuItem;
                if (hit != null && hit.Available) return hit;
                return null;
            }
        }
        catch { }

        // Keyboard navigation and a parent item with an open child submenu use
        // the native Selected/Pressed state while the pointer is outside.
        foreach (ToolStripItem candidate in menu.Items)
        {
            ToolStripMenuItem menuItem = candidate as ToolStripMenuItem;
            if (menuItem == null || !menuItem.Available) continue;
            if (menuItem.Pressed || menuItem.Selected) return menuItem;
        }
        return null;
    }

    public static void StretchItems(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return;
        int width = Math.Max(1, menu.ClientSize.Width - menu.Padding.Horizontal);
        foreach (ToolStripItem item in menu.Items)
        {
            if (item == null || !item.Available) continue;
            item.Margin = Padding.Empty;
            int height = Math.Max(1, item.Height);
            if (height <= 1)
                height = Math.Max(1, item.GetPreferredSize(Size.Empty).Height);
            item.AutoSize = false;
            if (item.Width != width || item.Height != height)
                item.Size = new Size(width, height);
        }
    }

    public static void PrepareItems(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return;
        StretchItems(menu);
        InvalidateWholeMenu(menu);
    }

    public static void InvalidateWholeMenu(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed || !menu.IsHandleCreated) return;
        try
        {
            menu.Invalidate(new Rectangle(Point.Empty, menu.ClientSize), false);
            menu.Update();
        }
        catch { }
    }
}

public sealed class LenovoContextMenuStrip : ContextMenuStrip
{
    public int TargetWidth { get; set; }
    public LenovoContextMenuStrip()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    public override Size GetPreferredSize(Size constrainingSize)
    {
        Size size = base.GetPreferredSize(constrainingSize);
        if (size.Width < TargetWidth) size.Width = TargetWidth;
        return size;
    }

    protected override void OnLayout(LayoutEventArgs e)
    {
        base.OnLayout(e);
        LenovoMenuLayout.StretchItems(this);
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }
}

public sealed class LenovoDropDownMenu : ToolStripDropDownMenu
{
    public int TargetWidth { get; set; }
    public LenovoDropDownMenu()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    public override Size GetPreferredSize(Size constrainingSize)
    {
        Size size = base.GetPreferredSize(constrainingSize);
        if (size.Width < TargetWidth) size.Width = TargetWidth;
        return size;
    }

    protected override void OnLayout(LayoutEventArgs e)
    {
        base.OnLayout(e);
        LenovoMenuLayout.StretchItems(this);
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }
}

public static class LenovoMenuChrome
{
    private const int GWL_STYLE = -16;
    private const int GWL_EXSTYLE = -20;

    private const long WS_BORDER = 0x00800000L;
    private const long WS_DLGFRAME = 0x00400000L;
    private const long WS_THICKFRAME = 0x00040000L;
    private const long WS_EX_DLGMODALFRAME = 0x00000001L;
    private const long WS_EX_WINDOWEDGE = 0x00000100L;
    private const long WS_EX_CLIENTEDGE = 0x00000200L;
    private const long WS_EX_STATICEDGE = 0x00020000L;

    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;

    private const int DWMWA_NCRENDERING_POLICY = 2;
    private const int DWMNCRP_DISABLED = 1;
    private const int DWMWA_BORDER_COLOR = 34;
    private const uint DWMWA_COLOR_NONE = 0xFFFFFFFEu;

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    private static extern IntPtr SetWindowLong32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);
    [DllImport("dwmapi.dll", EntryPoint = "DwmSetWindowAttribute")]
    private static extern int DwmSetWindowAttributeUInt(IntPtr hwnd, int dwAttribute, ref uint pvAttribute, int cbAttribute);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLong32(hWnd, nIndex);
    }

    private static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr value)
    {
        return IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, nIndex, value) : SetWindowLong32(hWnd, nIndex, value);
    }

    public static void Apply(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed || !menu.IsHandleCreated) return;

        IntPtr hwnd = menu.Handle;
        long style = GetWindowLongPtr(hwnd, GWL_STYLE).ToInt64();
        long exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();

        style &= ~(WS_BORDER | WS_DLGFRAME | WS_THICKFRAME);
        exStyle &= ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE);

        SetWindowLongPtr(hwnd, GWL_STYLE, new IntPtr(style));
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, new IntPtr(exStyle));

        try
        {
            int policy = DWMNCRP_DISABLED;
            DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, ref policy, sizeof(int));
        }
        catch { }

        // Windows 11 can draw a DWM frame border even for popup/tool windows.
        // Explicitly suppress that system border; the client renderer owns all visible menu chrome.
        try
        {
            uint noBorder = DWMWA_COLOR_NONE;
            DwmSetWindowAttributeUInt(hwnd, DWMWA_BORDER_COLOR, ref noBorder, sizeof(uint));
        }
        catch { }

        SetWindowPos(
            hwnd,
            IntPtr.Zero,
            0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
        );
    }
}

public sealed class LenovoCheckBox : CheckBox
{
    public Color AccentColor { get; set; }
    public Color BoxBackColor { get; set; }
    public Color BoxBorderColor { get; set; }
    public Color HoverColor { get; set; }
    private bool hovering;

    public LenovoCheckBox()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        AccentColor = Color.FromArgb(225, 37, 27);
        BoxBackColor = Color.FromArgb(30, 30, 30);
        BoxBorderColor = Color.FromArgb(82, 82, 82);
        HoverColor = Color.FromArgb(242, 59, 49);
        Cursor = Cursors.Hand;
        AutoSize = false;
    }

    protected override void OnMouseEnter(EventArgs e) { hovering = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovering = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle box = new Rectangle(1, Math.Max(1, (Height - 15) / 2), 14, 14);
        Color fill = Checked ? (hovering ? HoverColor : AccentColor) : BoxBackColor;
        using (Brush b = new SolidBrush(fill)) e.Graphics.FillRectangle(b, box);
        using (Pen p = new Pen(Checked ? AccentColor : BoxBorderColor, 1f)) e.Graphics.DrawRectangle(p, box);
        if (Checked)
        {
            using (Pen p = new Pen(Color.White, 1.8f))
            {
                p.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                p.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                e.Graphics.DrawLines(p, new Point[] { new Point(4, box.Top + 7), new Point(7, box.Top + 10), new Point(12, box.Top + 4) });
            }
        }
        TextRenderer.DrawText(e.Graphics, Text, Font, new Rectangle(23, 0, Math.Max(0, Width - 23), Height), Enabled ? ForeColor : Color.FromArgb(105,105,105), TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
    }
}


public sealed class LenovoVerticalScrollBar : Control
{
    private int minimum = 0;
    private int maximum = 0;
    private int value = 0;
    private int largeChange = 100;
    private int smallChange = 32;
    private bool dragging = false;
    private bool hoverThumb = false;
    private int dragOffset = 0;

    public event EventHandler ValueChanged;

    public Color TrackColor { get; set; }
    public Color ThumbColor { get; set; }
    public Color ThumbHoverColor { get; set; }

    public LenovoVerticalScrollBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        TrackColor = Color.FromArgb(18, 18, 18);
        ThumbColor = Color.FromArgb(225, 37, 27);
        ThumbHoverColor = Color.FromArgb(242, 59, 49);
        Width = 12;
        Cursor = Cursors.Hand;
        TabStop = false;
    }

    public int Minimum
    {
        get { return minimum; }
        set { minimum = value; if (maximum < minimum) maximum = minimum; Value = this.value; Invalidate(); }
    }

    public int Maximum
    {
        get { return maximum; }
        set { maximum = Math.Max(minimum, value); Value = this.value; Invalidate(); }
    }

    public int LargeChange
    {
        get { return largeChange; }
        set { largeChange = Math.Max(1, value); Invalidate(); }
    }

    public int SmallChange
    {
        get { return smallChange; }
        set { smallChange = Math.Max(1, value); }
    }

    public int Value
    {
        get { return value; }
        set
        {
            int next = Math.Max(minimum, Math.Min(maximum, value));
            if (next == this.value) return;
            this.value = next;
            Invalidate();
            if (ValueChanged != null) ValueChanged(this, EventArgs.Empty);
        }
    }

    private Rectangle GetThumbRectangle()
    {
        if (Height <= 0 || maximum <= minimum) return Rectangle.Empty;
        int logicalRange = Math.Max(1, maximum - minimum);
        int thumbHeight = (int)Math.Round((double)Height * largeChange / (logicalRange + largeChange));
        thumbHeight = Math.Max(34, Math.Min(Height, thumbHeight));
        int travel = Math.Max(0, Height - thumbHeight);
        int top = travel == 0 ? 0 : (int)Math.Round((double)(value - minimum) / logicalRange * travel);
        return new Rectangle(2, top, Math.Max(3, Width - 4), thumbHeight);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(TrackColor);
        Rectangle thumb = GetThumbRectangle();
        if (!thumb.IsEmpty)
        {
            using (Brush b = new SolidBrush(hoverThumb || dragging ? ThumbHoverColor : ThumbColor))
                e.Graphics.FillRectangle(b, thumb);
        }
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        Rectangle thumb = GetThumbRectangle();
        if (thumb.Contains(e.Location))
        {
            dragging = true;
            dragOffset = e.Y - thumb.Top;
            Capture = true;
        }
        else if (e.Y < thumb.Top) Value -= largeChange;
        else Value += largeChange;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        Rectangle thumb = GetThumbRectangle();
        bool nextHover = thumb.Contains(e.Location);
        if (nextHover != hoverThumb) { hoverThumb = nextHover; Invalidate(); }
        if (!dragging || thumb.IsEmpty) return;
        int travel = Math.Max(1, Height - thumb.Height);
        int top = Math.Max(0, Math.Min(travel, e.Y - dragOffset));
        int logicalRange = Math.Max(1, maximum - minimum);
        Value = minimum + (int)Math.Round((double)top / travel * logicalRange);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        dragging = false;
        Capture = false;
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        if (!dragging) { hoverThumb = false; Invalidate(); }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

if ($HideConsole) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LenovoBootSelectorConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $consoleHandle = [LenovoBootSelectorConsoleWindow]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
        [LenovoBootSelectorConsoleWindow]::ShowWindow($consoleHandle, 0) | Out-Null
    }
}

# Prevent duplicate tray instances. Internal background-refresh workers deliberately
# skip the tray mutex because they do not create UI or a NotifyIcon. Ownership is
# tested explicitly: an existing-but-free named mutex is not an active instance.
$mutex = $null
$mutexOwned = $false
$singleInstanceMutexState = 'not-applicable'
$singleInstanceGraceMs = 500
if (-not $BackgroundRefresh -and -not $UpdateCheck -and -not $UpdatePrepare) {
    $singleInstanceMutexState = 'busy'
    $mutex = [System.Threading.Mutex]::new($false, 'Local\LenovoBootMenuTray')
    try {
        try {
            $mutexOwned = $mutex.WaitOne(0, $false)
            if ($mutexOwned) { $singleInstanceMutexState = 'acquired' }
        }
        catch [System.Threading.AbandonedMutexException] {
            # WaitOne transfers ownership to this thread before throwing.
            $mutexOwned = $true
            $singleInstanceMutexState = 'abandoned-recovered'
        }

        # A short grace retry only affects a competing launch. It allows a process
        # that is already shutting down to release the mutex without delaying the
        # normal first-instance startup path.
        if (-not $mutexOwned) {
            try {
                $mutexOwned = $mutex.WaitOne($singleInstanceGraceMs, $false)
                if ($mutexOwned) { $singleInstanceMutexState = 'acquired-after-grace' }
            }
            catch [System.Threading.AbandonedMutexException] {
                $mutexOwned = $true
                $singleInstanceMutexState = 'abandoned-recovered'
            }
        }
    }
    catch {
        try { $mutex.Dispose() } catch { }
        $mutex = $null
        throw
    }

    if (-not $mutexOwned) {
        try { $mutex.Dispose() } catch { }
        $mutex = $null
        $startupLocale = Get-StartupRecoveryLocale
        Show-FatalMessage (Get-LocalizedStringCore -Key 'Startup.AlreadyRunningMessage' -Locale $startupLocale) -AllowRestart $false | Out-Null
        exit 0
    }
}

$script:AppVersion = '0.10.2.0'
$script:Popup = $null
$script:TrayIcon = $null
$script:CurrentEntries = @()
$script:SelectedGuid = $null
$script:LastStatusText = ''
$script:ExitRequested = $false
$script:StorageContext = $null
$script:AutostartCheckbox = $null
$script:AutostartTextLabel = $null
$script:AutostartMenuItem = $null
$script:UpdatingAutostartUi = $false
$script:ScriptPath = $PSCommandPath
if (-not $script:ScriptPath) { $script:ScriptPath = $MyInvocation.MyCommand.Path }

$script:RuntimeDiagnosticsRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics\Runtime'
# Preserve the command-line parent-session input before active diagnostics state
# reuses the RuntimeSessionId name in script scope.
$script:InheritedRuntimeSessionId = [string]$RuntimeSessionId
$script:RuntimeSessionId = $null
$script:RuntimeSessionDir = $null
$script:RuntimeEventsPath = $null
$script:RuntimeSessionStartedUtc = [datetime]::UtcNow
$script:RuntimeDiagnosticsAvailable = $false
$script:RuntimeDiagnosticsErrorCount = 0
$script:LastRuntimeDiagnosticPackage = $null
$script:RuntimeDiagnosticMenuItem = $null

$script:SupportedTaskBrokerVersions = @('0.2.14')
$script:TaskBrokerStateDir = Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'
$script:TaskBrokerMetadataPath = Join-Path $script:TaskBrokerStateDir 'task-broker.json'
$script:LegacyTaskBrokerStateDir = Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'
$script:LegacyTaskBrokerMetadataPath = Join-Path $script:LegacyTaskBrokerStateDir 'task-broker.json'
$script:TaskBrokerInstallScript = Join-Path $PSScriptRoot 'Install-LenovoBootMenuTasks.ps1'
$script:TaskBrokerUninstallScript = Join-Path $PSScriptRoot 'Uninstall-LenovoBootMenuTasks.ps1'
$script:TaskBrokerLocalDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\TaskBroker'
$script:TaskBrokerTimeoutMs = 10000
$script:TaskBrokerMetadata = $null
$script:TaskBrokerInstallProcess = $null
$script:TaskBrokerInstallTimer = $null
$script:TaskBrokerSetupMenuItem = $null
$script:TaskBrokerRemoveMenuItem = $null
$script:TaskBrokerInstallInProgress = $false
$script:TaskBrokerInstallDiagnosticStartedUtc = $null
$script:TaskBrokerRemoveInProgress = $false
$script:TaskBrokerRemoveDiagnosticStartedUtc = $null
$script:TaskBrokerRemoveProcess = $null
$script:TaskBrokerRemoveTimer = $null
$script:ManagerCacheText = $null
$script:ManagerCacheUtc = [datetime]::MinValue
$script:FirmwareCacheText = $null
$script:FirmwareCacheUtc = [datetime]::MinValue
$script:TaskBrokerReadyCached = $null
$script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
$script:BackgroundRefreshState = $null
$script:MaintenanceState = $null
$script:BootTargetDriftState = $null
$script:UpdateState = $null
$script:UpdateCheckMenuItem = $null
$script:UpdateInstallMenuItem = $null
$script:TrayOpenMenuItem = $null
$script:LanguageMenuRoot = $null
$script:LanguageEnglishMenuItem = $null
$script:LanguageGermanMenuItem = $null
$script:MaintenanceRootMenuItem = $null
$script:TrayExitMenuItem = $null
$script:RefreshButton = $null
$script:RefreshButtonHovered = $false
$script:HeaderTitleLabel = $null
$script:HeaderStatusLabel = $null
$script:LegacyAutostartTaskName = 'Lenovo Boot Menu Tray Autostart'
$script:AutostartRunValueName = 'Lenovo Boot Selector'
$script:LegacyAutostartRunValueName = 'Lenovo Boot Menu Tray'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:UiLocale = 'en-US'
$script:LocalePreferenceSource = 'default'
$script:LocalePreferenceNeedsConfirmation = $false
$script:DefaultGuid = $null
$script:LegacyDefaultGuid = $null
$script:DefaultButton = $null
$script:DefaultValueLabel = $null
$script:DefaultArrowLabel = $null
$script:DefaultInteractionEnabled = $false
$script:RestartTargetLabel = $null
$script:DefaultContextMenu = $null
$script:DefaultContextRoot = $null
$script:LegacySessionRestoreRegistryPath = 'HKCU:\Volatile Environment'
$script:LegacySessionRestoreValueName = 'LenovoBootMenuTrayDefaultRestoreProcessed'
$script:RestartMenuItem = $null
$script:EntryOrder = @()
$script:HiddenEntryGuids = @()
$script:EntryAliases = @{}
$script:IsManageEntriesMode = $false
$script:ManageEntryOrder = @()
$script:ManageHiddenEntryGuids = @()
$script:ManageEntryAliases = @{}
$script:ManageBaselineEntryOrder = @()
$script:ManageBaselineHiddenEntryGuids = @()
$script:ManageBaselineEntryAliases = @{}
$script:ManageSaveButton = $null
$script:ManageAliasEditGuid = $null
$script:ManageDragGuid = $null
$script:ManageDragStartX = 0
$script:ManageDragStartY = 0
$script:ManageLastDragUtc = [datetime]::MinValue
$script:ManageEntriesButton = $null
$script:ManageEntriesMenuItem = $null

# Reference palette from the supplied visual example.
$script:ColorHeader = [Drawing.Color]::FromArgb(0, 0, 0)        # #000000
$script:ColorBackground = [Drawing.Color]::FromArgb(31, 31, 31) # #1F1F1F
$script:ColorRow = [Drawing.Color]::FromArgb(31, 31, 31)
$script:ColorHover = [Drawing.Color]::FromArgb(41, 41, 41)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(44, 25, 24)
$script:ColorSurface = [Drawing.Color]::FromArgb(25, 25, 25)
$script:ColorPrimary = [Drawing.Color]::FromArgb(252, 252, 252)
$script:ColorSecondary = [Drawing.Color]::FromArgb(184, 184, 184)
$script:ColorAccent = [Drawing.Color]::FromArgb(225, 37, 27)    # Lenovo Red from supplied reference #E1251B
$script:ColorWarning = [Drawing.Color]::FromArgb(247, 179, 43)
$script:ColorBlue = [Drawing.Color]::FromArgb(78, 168, 222)
$script:ColorPurple = [Drawing.Color]::FromArgb(161, 103, 218)
$script:ColorCyan = [Drawing.Color]::FromArgb(70, 205, 207)
$script:MenuRenderer = New-Object LenovoMenuRenderer

function New-MaintenanceRuntimeState {
    [pscustomobject]@{
        Busy = $false
        Mode = ''
        StartedUtc = $null
    }
}

function Set-MaintenanceRuntimeActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    $State.Busy = $true
    $State.Mode = $Mode
    $State.StartedUtc = $NowUtc
    return $State
}

function Clear-MaintenanceRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Busy = $false
    $State.Mode = ''
    $State.StartedUtc = $null
    return $State
}

function Test-MaintenanceRuntimeBusy {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Busy)
}

function Get-MaintenanceRuntimeMode {
    param([AllowNull()]$State)
    if (-not $State -or -not $State.Busy) { return '' }
    return [string]$State.Mode
}

# Lenovo Boot Selector v0.5.0 - Application state for read-only firmware-target drift.
# No UI, IO, Scheduled Tasks or global script state.

function New-BootTargetDriftRuntimeState {
    [pscustomobject]@{
        Evaluated = $false
        HasDrift = $false
        HasNewTargets = $false
        AddedGuids = @()
        RemovedGuids = @()
        CurrentGuids = @()
        InstalledGuids = @()
        CheckedUtc = $null
        NotificationShown = $false
    }
}

function Set-BootTargetDriftRuntimeState {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Drift,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $oldFingerprint = ((@($State.AddedGuids) + @('|') + @($State.RemovedGuids)) -join ',')
    $newFingerprint = ((@($Drift.AddedGuids) + @('|') + @($Drift.RemovedGuids)) -join ',')
    if (-not $State.Evaluated -or $oldFingerprint -ne $newFingerprint) {
        $State.NotificationShown = $false
    }

    $State.Evaluated = $true
    $State.HasDrift = [bool]$Drift.HasDrift
    $State.HasNewTargets = [bool]$Drift.HasNewTargets
    $State.AddedGuids = @($Drift.AddedGuids)
    $State.RemovedGuids = @($Drift.RemovedGuids)
    $State.CurrentGuids = @($Drift.CurrentGuids)
    $State.InstalledGuids = @($Drift.InstalledGuids)
    $State.CheckedUtc = $NowUtc
    if (-not $State.HasDrift) { $State.NotificationShown = $false }
    return $State
}

function Clear-BootTargetDriftRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Evaluated = $false
    $State.HasDrift = $false
    $State.HasNewTargets = $false
    $State.AddedGuids = @()
    $State.RemovedGuids = @()
    $State.CurrentGuids = @()
    $State.InstalledGuids = @()
    $State.CheckedUtc = $null
    $State.NotificationShown = $false
    return $State
}

function Test-BootTargetDriftRuntimeDetected {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift)
}

function Test-BootTargetDriftRuntimeHasNewTargets {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift -and $State.HasNewTargets)
}

function Set-BootTargetDriftNotificationShown {
    param([Parameter(Mandatory=$true)]$State)
    $State.NotificationShown = $true
    return $State
}

function ConvertTo-LenovoVersionCore {
    param([Parameter(Mandatory=$true)][string]$Version)
    $value = ([string]$Version).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') { return $null }
    if ($value -match '^\d+\.\d+\.\d+$') { $value += '.0' }
    try { return [version]$value } catch { return $null }
}

function Compare-LenovoAppVersionCore {
    param(
        [Parameter(Mandatory=$true)][string]$Current,
        [Parameter(Mandatory=$true)][string]$Candidate
    )
    $currentVersion = ConvertTo-LenovoVersionCore -Version $Current
    $candidateVersion = ConvertTo-LenovoVersionCore -Version $Candidate
    if (-not $currentVersion -or -not $candidateVersion) { throw 'Ungültiges Versionsformat.' }
    return $candidateVersion.CompareTo($currentVersion)
}

function Resolve-LenovoUpdateRestartResultCore {
    param(
        [AllowNull()]$Result,
        [Parameter(Mandatory=$true)][string]$RunningVersion
    )

    $running = ([string]$RunningVersion).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $running)) { throw 'Ungültige laufende App-Version.' }

    $status = ''
    $sourceVersion = ''
    $targetVersion = ''
    $storedMessage = ''
    $resultUtc = ''
    $rollbackAttempted = $false
    $rollbackSucceeded = $false
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $legacySuccessProperty = $null
    if ($Result) {
        $status = ([string]$Result.status).Trim().ToLowerInvariant()
        $sourceVersion = ([string]$Result.sourceVersion).Trim()
        $targetVersion = ([string]$Result.targetVersion).Trim()
        $storedMessage = ([string]$Result.message).Trim()
        $resultUtc = [string]$Result.utc
        $rollbackAttempted = [bool]$Result.rollbackAttempted
        $rollbackSucceeded = [bool]$Result.rollbackSucceeded
        $failureCategory = ([string]$Result.failureCategory).Trim().ToLowerInvariant()
        $failureStage = ([string]$Result.failureStage).Trim()
        $errorClass = ([string]$Result.errorClass).Trim()
        $legacySuccessProperty = $Result.PSObject.Properties['success']
    }

    # v0.5.7.2 and older updater helpers persisted { utc, success, message }.
    # Treat that shape as legacy only when status is absent and success is a real Boolean.
    # If a status exists, the v0.5.8.x status contract always wins.
    $isLegacyResult = (-not $status -and $null -ne $legacySuccessProperty -and ($legacySuccessProperty.Value -is [bool]))
    $resultFormat = $(if ($status) { 'status' } elseif ($isLegacyResult) { 'legacy-success' } else { 'unknown' })
    $legacySuccess = $null
    $success = $false
    $message = $storedMessage
    $displayVersion = $targetVersion

    if ($status -eq 'pending-verification') {
        try {
            if (-not $targetVersion) { throw 'Die erwartete Zielversion fehlt im Update-Ergebnis.' }
            $comparison = Compare-LenovoAppVersionCore -Current $running -Candidate $targetVersion
            $success = ($comparison -eq 0)
            if ($success) {
                $message = ('Lenovo Boot Selector wurde erfolgreich auf v{0} aktualisiert.' -f $targetVersion)
            }
            else {
                $message = ('Die erwartete Zielversion v{0} wurde nach dem Neustart nicht erkannt. Aktuell läuft v{1}.' -f $targetVersion,$running)
            }
        }
        catch {
            $success = $false
            $message = $_.Exception.Message
        }
    }
    elseif ($status -eq 'failed') {
        $success = $false
        if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.' }
        if ($rollbackAttempted -and $rollbackSucceeded) {
            $message = "Die Aktualisierung konnte nicht abgeschlossen werden. Die vorherige Version wurde wiederhergestellt.`r`n`r`nUrsache: $message"
        }
    }
    elseif ($isLegacyResult) {
        $legacySuccess = [bool]$legacySuccessProperty.Value
        $success = $legacySuccess
        if ($success) {
            # Legacy records carry no trustworthy targetVersion. Report only the version
            # that is demonstrably running and leave TargetVersion empty in diagnostics.
            $displayVersion = $running
            $message = ('Lenovo Boot Selector wurde erfolgreich aktualisiert. Aktuell läuft v{0}.' -f $running)
        }
        elseif ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.'
        }
    }
    else {
        $success = $false
        $message = ('Unbekannter Update-Ergebnisstatus: {0}' -f $(if ($status) { $status } else { '<leer>' }))
    }

    return [pscustomobject][ordered]@{
        Success = $success
        Message = $message
        DisplayVersion = $displayVersion
        ResultFormat = $resultFormat
        LegacySuccess = $legacySuccess
        ResultUtc = $resultUtc
        ResultStatus = $status
        SourceVersion = $sourceVersion
        TargetVersion = $targetVersion
        RunningVersion = $running
        RollbackAttempted = $rollbackAttempted
        RollbackSucceeded = $rollbackSucceeded
        FailureCategory = $failureCategory
        FailureStage = $failureStage
        ErrorClass = $errorClass
        StoredMessage = $storedMessage
    }
}

function Test-LenovoUpdateManifestCore {
    param([AllowNull()]$Manifest)

    $result = [ordered]@{
        IsValid = $false
        Error = ''
        SchemaVersion = 1
        Version = ''
        File = ''
        Sha256 = ''
        Size = 0
        Tag = ''
        PackageFiles = @()
    }

    if (-not $Manifest) { $result.Error = 'Update-Manifest fehlt.'; return [pscustomobject]$result }
    if ([int]$Manifest.schemaVersion -ne 1) { $result.Error = 'Update-Manifest-Schema wird nicht unterstützt.'; return [pscustomobject]$result }

    $version = ([string]$Manifest.version).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $version)) { $result.Error = 'Update-Version ist ungültig.'; return [pscustomobject]$result }

    $expectedFile = ('LenovoBootMenuTray-v{0}.zip' -f $version)
    $file = ([string]$Manifest.file).Trim()
    if ($file -ne $expectedFile) { $result.Error = 'Update-Dateiname passt nicht zur Version.'; return [pscustomobject]$result }

    $sha = ([string]$Manifest.sha256).Trim().ToLowerInvariant()
    if ($sha -notmatch '^[0-9a-fA-F]{64}$') { $result.Error = 'Update-SHA-256 ist ungültig.'; return [pscustomobject]$result }

    $size = 0L
    try { $size = [int64]$Manifest.size } catch { $size = 0L }
    if ($size -le 0) { $result.Error = 'Update-Dateigröße ist ungültig.'; return [pscustomobject]$result }

    $tag = ([string]$Manifest.tag).Trim()
    if ($tag -ne ('v{0}' -f $version)) { $result.Error = 'Update-Tag passt nicht zur Version.'; return [pscustomobject]$result }

    $packageFiles = @($Manifest.packageFiles)
    if ($packageFiles.Count -lt 1) { $result.Error = 'Update-Paketdateien fehlen.'; return [pscustomobject]$result }
    $seen = @{}
    $normalizedFiles = @()
    foreach ($item in $packageFiles) {
        $name = ([string]$item).Trim()
        if (-not $name -or $name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            $result.Error = 'Update-Paket enthält einen ungültigen Dateinamen.'; return [pscustomobject]$result
        }
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { $result.Error = 'Update-Paket enthält doppelte Dateinamen.'; return [pscustomobject]$result }
        $seen[$key] = $true
        $normalizedFiles += $name
    }
    foreach ($required in @('LenovoBootMenuTray.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1')) {
        if (-not $seen.ContainsKey($required.ToLowerInvariant())) {
            $result.Error = 'Update-Paket ist unvollständig.'; return [pscustomobject]$result
        }
    }

    $result.IsValid = $true
    $result.Version = $version
    $result.File = $file
    $result.Sha256 = $sha
    $result.Size = $size
    $result.Tag = $tag
    $result.PackageFiles = @($normalizedFiles)
    return [pscustomobject]$result
}

function New-UpdateRuntimeState {
    [pscustomobject]@{
        Status = 'Idle'
        AvailableManifest = $null
        LastError = ''
        CheckProcess = $null
        CheckTimer = $null
        CheckResultPath = $null
        CheckMode = ''
        PrepareProcess = $null
        PrepareTimer = $null
        PrepareResultPath = $null
        ManifestPath = $null
    }
}

function Set-UpdateRuntimeChecking {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Checking'
    $State.AvailableManifest = $null
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeIdle {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Idle'
    return $State
}

function Set-UpdateRuntimeAvailable {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)]$Manifest)
    $State.Status = 'UpdateAvailable'
    $State.AvailableManifest = $Manifest
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimePreparing {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Preparing'
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeReadyToInstall {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'ReadyToInstall'
    return $State
}

function Set-UpdateRuntimeFailed {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$Message)
    $State.Status = 'Failed'
    $State.LastError = $Message
    return $State
}

function Test-UpdateRuntimeBusy {
    param([AllowNull()]$State)
    if (-not $State) { return $false }
    return @('Checking','Preparing','ReadyToInstall') -contains [string]$State.Status
}


$script:MaintenanceState = New-MaintenanceRuntimeState
$script:BootTargetDriftState = New-BootTargetDriftRuntimeState
$script:UpdateState = New-UpdateRuntimeState

function Initialize-LenovoMenuAppearance {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [int]$Radius = 0
    )
    if ($Menu.Tag -eq '__LenovoFlatMenu') { return }
    $Menu.Tag = '__LenovoFlatMenu'
    $isSubmenu = ($null -ne $Menu.OwnerItem)
    $Menu.BackColor = if ($isSubmenu) { [Drawing.Color]::FromArgb(32, 32, 32) } else { [Drawing.Color]::FromArgb(22, 22, 22) }
    $Menu.ForeColor = $script:ColorPrimary
    $Menu.Renderer = $script:MenuRenderer
    # v0.2.32: square, borderless root menu with no native check/image gutter.
    # Submenus use a lighter panel plus neutral edge. Selection, separators,
    # checks and arrows are painted centrally in owner coordinates.
    $Menu.DropShadowEnabled = $false
    if ($Menu -is [System.Windows.Forms.ToolStripDropDownMenu]) {
        $Menu.ShowCheckMargin = $false
        $Menu.ShowImageMargin = $false
    }
    $Menu.Padding = if ($isSubmenu) {
        New-Object System.Windows.Forms.Padding(1, 2, 1, 2)
    }
    else {
        New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    }
    $Menu.Add_Opening({
        try {
            $this.Region = $null
            [LenovoMenuLayout]::PrepareItems($this)
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    $Menu.Add_Opened({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
            [LenovoMenuLayout]::PrepareItems($this)
        } catch { }
    })
    $Menu.Add_SizeChanged({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    # v0.3.2: Full-menu hover invalidation is implemented directly by the
    # custom drop-down classes. No delayed BeginInvoke/tail-paint workaround.
}

function Ensure-DarkActionTooltip {
    if (-not $script:DarkActionTooltip) {
        $script:DarkActionTooltipFont = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.OwnerDraw = $true
        $tip.ShowAlways = $true
        $tip.UseAnimation = $false
        $tip.UseFading = $false
        $tip.InitialDelay = 0
        $tip.ReshowDelay = 0
        $tip.AutoPopDelay = 3500
        $tip.BackColor = [Drawing.Color]::FromArgb(28,28,28)
        $tip.ForeColor = [Drawing.Color]::FromArgb(238,238,238)
        $tip.Add_Popup({
            param($sender,$eventArgs)
            $text = [string]$script:DarkActionTooltipText
            if ([string]::IsNullOrWhiteSpace($text)) { return }
            $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
                $text,
                $script:DarkActionTooltipFont,
                (New-Object Drawing.Size(320,0)),
                ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
            )
            $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
            $height = [Math]::Max(30, $measured.Height + 12)
            $eventArgs.ToolTipSize = New-Object Drawing.Size($width,$height)
        })
        $tip.Add_Draw({
            param($sender,$eventArgs)
            $bounds = $eventArgs.Bounds
            $bg = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(28,28,28))
            $border = New-Object Drawing.Pen([Drawing.Color]::FromArgb(76,76,76),1)
            try {
                $eventArgs.Graphics.FillRectangle($bg, $bounds)
                $eventArgs.Graphics.DrawRectangle($border, 0, 0, [Math]::Max(0,$bounds.Width-1), [Math]::Max(0,$bounds.Height-1))
                $textRect = New-Object Drawing.Rectangle(9, 0, [Math]::Max(1,$bounds.Width-18), $bounds.Height)
                [System.Windows.Forms.TextRenderer]::DrawText(
                    $eventArgs.Graphics,
                    [string]$script:DarkActionTooltipText,
                    $script:DarkActionTooltipFont,
                    $textRect,
                    [Drawing.Color]::FromArgb(238,238,238),
                    ([System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
                )
            }
            finally {
                $border.Dispose()
                $bg.Dispose()
            }
        })
        $script:DarkActionTooltip = $tip
    }
    return $script:DarkActionTooltip
}

function Show-DarkActionTooltip {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Owner,
        [Parameter(Mandatory=$true)][string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text) -or -not $Owner -or $Owner.IsDisposed) { return }
    $tip = Ensure-DarkActionTooltip
    $script:DarkActionTooltipText = $Text
    $script:DarkActionTooltipOwner = $Owner

    $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text,
        $script:DarkActionTooltipFont,
        (New-Object Drawing.Size(320,0)),
        ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
    )
    $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
    $height = [Math]::Max(30, $measured.Height + 12)
    $work = [System.Windows.Forms.Screen]::FromControl($Owner).WorkingArea
    $ownerTopLeft = $Owner.PointToScreen([System.Drawing.Point]::Empty)
    $x = $ownerTopLeft.X + $Owner.Width + 8
    if (($x + $width) -gt $work.Right) { $x = $ownerTopLeft.X - $width - 8 }
    if ($x -lt $work.Left) { $x = [Math]::Max($work.Left, [Math]::Min($work.Right - $width, $ownerTopLeft.X)) }
    $y = $ownerTopLeft.Y + [int](($Owner.Height - $height) / 2)
    if ($y -lt $work.Top) { $y = $work.Top }
    if (($y + $height) -gt $work.Bottom) { $y = $work.Bottom - $height }
    $clientPoint = $Owner.PointToClient((New-Object Drawing.Point($x,$y)))

    try { $tip.Hide($Owner) } catch { }
    $tip.Show($Text, $Owner, $clientPoint.X, $clientPoint.Y, 3500)
}

function Hide-DarkActionTooltip {
    if ($script:DarkActionTooltip -and $script:DarkActionTooltipOwner) {
        try { $script:DarkActionTooltip.Hide($script:DarkActionTooltipOwner) } catch { }
    }
    $script:DarkActionTooltipOwner = $null
    $script:DarkActionTooltipText = $null
}


function Update-HeaderStatusInteractionVisual {
    if (-not $script:HeaderStatusLabel -or $script:HeaderStatusLabel.IsDisposed) { return }
    $interactive = [bool]$script:HeaderUpdateInteractionEnabled
    $highlight = ($interactive -and ([bool]$script:HeaderStatusHovered -or $script:HeaderStatusLabel.Focused))
    $script:HeaderStatusLabel.ForeColor = if ($highlight) { $script:ColorAccent } else { $script:ColorSecondary }
    $script:HeaderStatusLabel.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    $script:HeaderStatusLabel.TabStop = $interactive
}

function Set-HeaderUpdateInteractionState {
    param([Parameter(Mandatory=$true)][bool]$Enabled)
    $script:HeaderUpdateInteractionEnabled = $Enabled
    Update-HeaderStatusInteractionVisual
}

function Update-HeaderRefreshStatus {
    if (Test-MaintenanceBusy) {
        if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) { $script:HeaderTitleLabel.Location = New-Object Drawing.Point(16, 10) }
        if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
            $script:HeaderStatusLabel.Text = Get-MaintenanceBusyStatusText
            $script:HeaderStatusLabel.Visible = $true
        }
        Set-HeaderUpdateInteractionState -Enabled $false
        return
    }

    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $updateAvailable = $false
    try {
        $updateAvailable = ($script:UpdateState -and [string]$script:UpdateState.Status -eq 'UpdateAvailable' -and $null -ne $script:UpdateState.AvailableManifest)
    } catch { }
    $showStatus = ($active -or $updateAvailable)

    if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) {
        $script:HeaderTitleLabel.Location = if ($showStatus) {
            New-Object Drawing.Point(16, 10)
        }
        else {
            New-Object Drawing.Point(16, 19)
        }
    }

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($active) {
            Get-LocalizedString -Key 'Header.Refreshing'
        }
        elseif ($updateAvailable) {
            Get-LocalizedString -Key 'Update.Available'
        }
        else {
            ''
        }
        $script:HeaderStatusLabel.Visible = $showStatus
    }
    Set-HeaderUpdateInteractionState -Enabled (-not $active -and $updateAvailable)
}

function Update-RefreshButtonVisual {
    if (-not $script:RefreshButton -or $script:RefreshButton.IsDisposed) {
        Update-HeaderRefreshStatus
        return
    }
    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $script:RefreshButton.Enabled = ((Get-SystemFunctionsPresentationState) -eq 'Ready')
    $script:RefreshButton.ForeColor = if ($active -or $script:RefreshButtonHovered) { $script:ColorAccent } else { $script:ColorSecondary }
    Update-HeaderRefreshStatus
}


function Get-RuntimeDiagnosticRole {
    if ($BackgroundRefresh) { return 'background-refresh' }
    if ($UpdateCheck) { return 'update-check' }
    if ($UpdatePrepare) { return 'update-prepare' }
    return 'tray'
}

function ConvertTo-RuntimeDiagnosticText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $result = [string]$Text
    $pairs = @(
        @([string]$env:LOCALAPPDATA, '%LOCALAPPDATA%'),
        @([string]$env:USERPROFILE, '%USERPROFILE%'),
        @([string]$env:USERNAME, '<user>'),
        @([string]$env:COMPUTERNAME, '<computer>')
    )
    foreach ($pair in $pairs) {
        if (-not [string]$pair[0]) { continue }
        $result = [regex]::Replace($result, [regex]::Escape([string]$pair[0]), [string]$pair[1], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $result
}

function New-RuntimeDiagnosticData {
    param([hashtable]$Values)
    $result = [ordered]@{}
    if (-not $Values) { return $result }
    foreach ($key in @($Values.Keys)) {
        if (-not $key) { continue }
        $value = $Values[$key]
        if ($null -eq $value) { continue }
        if ($value -is [string]) { $value = ConvertTo-RuntimeDiagnosticText -Text $value }
        $result[[string]$key] = $value
    }
    return $result
}

function Initialize-RuntimeDiagnostics {
    try {
        $candidate = ([string]$script:InheritedRuntimeSessionId).Trim()
        if ($candidate) { $candidate = ($candidate -replace '[^A-Za-z0-9-]', '') }
        $hasParentSession = [bool]$candidate
        if (-not $candidate) { $candidate = [guid]::NewGuid().ToString('D') }

        $script:RuntimeSessionId = $candidate
        $script:RuntimeSessionStartedUtc = [datetime]::UtcNow
        $script:RuntimeSessionDir = Join-Path $script:RuntimeDiagnosticsRoot $candidate
        $script:RuntimeEventsPath = Join-Path $script:RuntimeSessionDir 'runtime.jsonl'
        if (-not (Test-Path -LiteralPath $script:RuntimeSessionDir)) {
            [void](New-Item -ItemType Directory -Path $script:RuntimeSessionDir -Force)
        }
        $script:RuntimeDiagnosticsAvailable = $true

        # Retention is deliberately conservative and best-effort. A diagnosis must
        # never prevent the tray from starting or a boot action from completing.
        try {
            $cutoff = [datetime]::UtcNow.AddDays(-30)
            foreach ($dir in @(Get-ChildItem -LiteralPath $script:RuntimeDiagnosticsRoot -Directory -ErrorAction SilentlyContinue)) {
                if ($dir.FullName -eq $script:RuntimeSessionDir) { continue }
                if ($dir.LastWriteTimeUtc -lt $cutoff) {
                    Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } catch { }

        Write-RuntimeDiagnosticEvent -Event $(if ($BackgroundRefresh) { 'BACKGROUND_WORKER_STARTED' } elseif ($UpdateCheck) { 'UPDATE_CHECK_WORKER_STARTED' } elseif ($UpdatePrepare) { 'UPDATE_PREPARE_WORKER_STARTED' } else { 'SESSION_STARTED' }) -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{
            role = (Get-RuntimeDiagnosticRole)
            parentSession = $hasParentSession
        })
    }
    catch {
        $script:RuntimeDiagnosticsAvailable = $false
    }
}

function Write-RuntimeDiagnosticEvent {
    param(
        [Parameter(Mandatory=$true)][string]$Event,
        [string]$Stage = '',
        [AllowNull()][object]$Success = $null,
        [AllowNull()][object]$DurationMs = $null,
        [AllowNull()]$ErrorRecord = $null,
        [AllowNull()]$Data = $null,
        [ValidateSet('info','warning','error')][string]$Level = 'info'
    )

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeEventsPath) { return }
    try {
        $record = [ordered]@{
            utc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            appVersion = $script:AppVersion
            processId = $PID
            role = (Get-RuntimeDiagnosticRole)
            event = $Event
            stage = $Stage
            level = $Level
        }
        if ($null -ne $Success) { $record.success = [bool]$Success }
        if ($null -ne $DurationMs) { $record.durationMs = [int64]$DurationMs }

        if ($ErrorRecord) {
            $exception = $null
            if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $exception = $ErrorRecord.Exception }
            elseif ($ErrorRecord -is [System.Exception]) { $exception = $ErrorRecord }
            elseif ($ErrorRecord.Exception) { $exception = $ErrorRecord.Exception }
            if ($exception) {
                $record.errorClass = $exception.GetType().FullName
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$exception.Message)
            }
            else {
                $record.errorClass = 'UnknownError'
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$ErrorRecord)
            }
            $script:RuntimeDiagnosticsErrorCount++
        }

        if ($Data) { $record.data = $Data }
        $json = $record | ConvertTo-Json -Depth 10 -Compress

        # FileShare.ReadWrite allows the tray and its hidden refresh child to append
        # to the same session log. Logging is single-attempt/best-effort: diagnostics
        # must never introduce retry delays into a boot or task action.
        try {
            $stream = [System.IO.FileStream]::new($script:RuntimeEventsPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
            try {
                $writer = [System.IO.StreamWriter]::new($stream, (New-Object System.Text.UTF8Encoding($false)))
                try { $writer.WriteLine($json); $writer.Flush() }
                finally { $writer.Dispose() }
            }
            finally { if ($stream) { $stream.Dispose() } }
        }
        catch { }
    }
    catch { }
}


function Get-RuntimeDiagnosticBrokerSummary {
    $present = [bool](Test-TaskBrokerInstallationPresent)
    if (-not $present) {
        return [ordered]@{
            present = $false
            metadataReadable = $false
            compatible = $false
        }
    }

    $meta = $null
    try {
        $text = [System.IO.File]::ReadAllText($script:TaskBrokerMetadataPath,[System.Text.Encoding]::UTF8)
        $meta = $text | ConvertFrom-Json
    }
    catch {
        return [ordered]@{
            present = $true
            metadataReadable = $false
            compatible = $false
        }
    }

    $compatible = [bool](Test-TaskBrokerMetadataCompatible)
    $targets = @()
    foreach ($target in @($meta.targets)) {
        $targets += [ordered]@{
            guid = [string]$target.guid
            taskName = [string]$target.taskName
            defaultTaskName = [string]$target.defaultTaskName
        }
    }
    return [ordered]@{
        present = $true
        metadataReadable = $true
        compatible = $compatible
        version = [string]$meta.version
        boundaryContract = [string]$meta.boundaryContract
        installedUtc = [string]$meta.installedUtc
        managerRefreshTask = [string]$meta.managerRefreshTask
        firmwareRefreshTask = [string]$meta.firmwareRefreshTask
        defaultClearTask = [string]$meta.defaultClearTask
        defaultRestoreTask = [string]$meta.defaultRestoreTask
        defaultRestoreDelaySeconds = $meta.defaultRestoreDelaySeconds
        targetCount = @($targets).Count
        targets = @($targets)
    }
}
function Export-RuntimeDiagnosticPackage {
    param([string]$Reason = 'manual')

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeSessionId) {
        throw 'Für diese Sitzung sind keine Runtime-Diagnosedaten verfügbar.'
    }

    $exportRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
    if (-not (Test-Path -LiteralPath $exportRoot)) { [void](New-Item -ItemType Directory -Path $exportRoot -Force) }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $shortSession = if ($script:RuntimeSessionId.Length -ge 8) { $script:RuntimeSessionId.Substring(0,8) } else { $script:RuntimeSessionId }
    $zipPath = Join-Path $exportRoot ("Lenovo-Boot-Selector-Diagnostics-{0}-{1}.zip" -f $stamp,$shortSession)
    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("LenovoBootSelectorDiag-{0}" -f ([guid]::NewGuid().ToString('N')))

    Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_REQUESTED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason; outputName = [System.IO.Path]::GetFileName($zipPath) })

    try {
        [void](New-Item -ItemType Directory -Path $stage -Force)
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            Copy-Item -LiteralPath $script:RuntimeEventsPath -Destination (Join-Path $stage 'runtime.jsonl') -Force
        }
        else {
            [System.IO.File]::WriteAllText((Join-Path $stage 'runtime.jsonl'), '', (New-Object System.Text.UTF8Encoding($false)))
        }

        $environment = [ordered]@{
            exportedUtc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            sessionStartedUtc = $script:RuntimeSessionStartedUtc.ToString('o')
            appVersion = $script:AppVersion
            taskBrokerSchemaSupported = @($script:SupportedTaskBrokerVersions)
            osVersion = [Environment]::OSVersion.VersionString
            os64Bit = [Environment]::Is64BitOperatingSystem
            process64Bit = [Environment]::Is64BitProcess
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            clrVersion = [Environment]::Version.ToString()
            role = (Get-RuntimeDiagnosticRole)
            lastBackgroundRefreshTiming = $(if ($script:BackgroundRefreshState) { $script:BackgroundRefreshState.LastTiming } else { $null })
        }
        [System.IO.File]::WriteAllText((Join-Path $stage 'environment.json'), ($environment | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $broker = Get-RuntimeDiagnosticBrokerSummary
        [System.IO.File]::WriteAllText((Join-Path $stage 'task-broker-summary.json'), ($broker | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $eventCount = 0
        $errorCount = 0
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            foreach ($line in @([System.IO.File]::ReadAllLines($script:RuntimeEventsPath, [System.Text.Encoding]::UTF8))) {
                if (-not $line) { continue }
                $eventCount++
                if ($line -match '"level":"error"') { $errorCount++ }
            }
        }
        $summary = @(
            'Lenovo Boot Selector – Runtime-Diagnose',
            "App-Version: $($script:AppVersion)",
            "Session: $($script:RuntimeSessionId)",
            "Sitzungsstart (UTC): $($script:RuntimeSessionStartedUtc.ToString('o'))",
            "Export (UTC): $([datetime]::UtcNow.ToString('o'))",
            "Grund: $Reason",
            "Events: $eventCount",
            "Fehler-Events: $errorCount",
            '',
            'Enthalten sind ausschließlich die aktuelle Runtime-Sitzung sowie technische Environment-/TaskBroker-Metadaten.',
            'Benutzername, Rechnername und TaskBroker-userSid werden nicht exportiert.'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText((Join-Path $stage 'summary.txt'), $summary, (New-Object System.Text.UTF8Encoding($false)))

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        $script:LastRuntimeDiagnosticPackage = $zipPath
        return $zipPath
    }
    finally {
        try { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } } catch { }
    }
}

function Show-DiagnosticPackageInExplorer {
    param([Parameter(Mandatory=$true)][string]$Path)

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Das Diagnosepaket ist nicht mehr vorhanden.' }
        $explorer = Join-Path $env:WINDIR 'explorer.exe'
        if (-not (Test-Path -LiteralPath $explorer -PathType Leaf)) { $explorer = 'explorer.exe' }
        $safePath = $Path.Replace('"','')
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $explorer
        $psi.Arguments = ('/select,"{0}"' -f $safePath)
        $psi.UseShellExecute = $true
        [void][System.Diagnostics.Process]::Start($psi)
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) })
        return $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) }) -Level warning
        return $false
    }
}

function Get-LenovoUpdateManifestBaseUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json'
}

function Get-LenovoUpdateManifestUri {
    $cacheBuster = [guid]::NewGuid().ToString('N')
    return ('{0}?cb={1}' -f (Get-LenovoUpdateManifestBaseUri),$cacheBuster)
}

function Get-LenovoUpdateDownloadBaseUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/'
}

function Enable-LenovoUpdateTls12 {
    try {
        $current = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $current -bor [System.Net.SecurityProtocolType]::Tls12
    } catch { }
}

function New-LenovoWebClient {
    Enable-LenovoUpdateTls12
    $client = New-Object System.Net.WebClient
    $client.Headers['User-Agent'] = 'LenovoBootSelector/' + $script:AppVersion
    $client.Headers['Cache-Control'] = 'no-cache'
    return $client
}

function New-LenovoUpdateFailureException {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('network','manifest','package','hash','install','restart','runtime')][string]$Category,
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][string]$Message,
        [AllowNull()][System.Exception]$InnerException = $null
    )
    $exception = if ($InnerException) { [System.InvalidOperationException]::new($Message,$InnerException) } else { [System.InvalidOperationException]::new($Message) }
    $exception.Data['LenovoUpdateCategory'] = $Category
    $exception.Data['LenovoUpdateStage'] = $Stage
    return $exception
}

function Get-LenovoUpdateFailureInfo {
    param(
        [AllowNull()]$ErrorRecord,
        [ValidateSet('network','manifest','package','hash','install','restart','runtime')][string]$DefaultCategory = 'runtime',
        [string]$DefaultStage = 'update'
    )
    $exception = $null
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $exception = $ErrorRecord.Exception }
    elseif ($ErrorRecord -is [System.Exception]) { $exception = $ErrorRecord }
    elseif ($ErrorRecord -and $ErrorRecord.Exception) { $exception = $ErrorRecord.Exception }
    $category = $DefaultCategory
    $stage = $DefaultStage
    $errorClass = ''
    $networkStatus = ''
    $message = [string]$ErrorRecord
    if ($exception) {
        $message = [string]$exception.Message
        $errorClass = $exception.GetType().FullName
        $hasStructuredCategory = $exception.Data.Contains('LenovoUpdateCategory')
        if ($hasStructuredCategory) { $category = [string]$exception.Data['LenovoUpdateCategory'] }
        if ($exception.Data.Contains('LenovoUpdateStage')) { $stage = [string]$exception.Data['LenovoUpdateStage'] }
        $probe = $exception
        while ($probe) {
            if ($probe -is [System.Net.WebException]) {
                if (-not $hasStructuredCategory) { $category = 'network' }
                $networkStatus = [string]$probe.Status
                $errorClass = $probe.GetType().FullName
                break
            }
            $probe = $probe.InnerException
        }
    }
    return [pscustomobject][ordered]@{ Category=$category; Stage=$stage; ErrorClass=$errorClass; NetworkStatus=$networkStatus; Message=$message }
}

function Invoke-LenovoUpdateTextDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri)
    $client = New-LenovoWebClient
    try { return $client.DownloadString($Uri) }
    catch { throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'manifest-download' -Message ('Update-Manifest konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    finally { $client.Dispose() }
}

function Invoke-LenovoUpdateFileDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri,[Parameter(Mandatory=$true)][string]$DestinationPath)
    $client = New-LenovoWebClient
    try { $client.DownloadFile($Uri,$DestinationPath) }
    catch { throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'package-download' -Message ('Update-Paket konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    finally { $client.Dispose() }
}

function Get-LenovoUpdateResultPath {
    $root = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    return (Join-Path $root 'last-update-result.json')
}

function Read-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $json = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($json)) { return $null }
        return ($json | ConvertFrom-Json)
    }
    catch {
        return [pscustomobject]@{
            schemaVersion = 1
            status = 'failed'
            sourceVersion = ''
            targetVersion = ''
            utc = [datetime]::UtcNow.ToString('o')
            message = ('Update-Ergebnis konnte nicht gelesen werden: ' + $_.Exception.Message)
            rollbackAttempted = $false
            rollbackSucceeded = $false
        }
    }
}

function Remove-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    try {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    } catch { }
}


function Get-LenovoUpdateManifestRemote {
    $json = Invoke-LenovoUpdateTextDownload -Uri (Get-LenovoUpdateManifestUri)
    if ([string]::IsNullOrWhiteSpace($json)) { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-content' -Message 'Update-Manifest ist leer.') }
    try { return ($json | ConvertFrom-Json) }
    catch { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-parse' -Message ('Update-Manifest ist kein gültiges JSON: ' + $_.Exception.Message) -InnerException $_.Exception) }
}
function Get-LenovoSha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try { $hash = $sha.ComputeHash($stream) }
        finally { $stream.Dispose() }
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally { $sha.Dispose() }
}

function Write-LenovoUpdateWorkerResult {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path,$json,(New-Object System.Text.UTF8Encoding($false)))
}


function Invoke-UpdateCheckWorker {
    $result = [ordered]@{ Success=$false; UpdateAvailable=$false; Manifest=$null; Error=''; ErrorCategory=''; FailureStage=''; ErrorClass=''; NetworkStatus='' }
    $manifestVersion = ''
    $manifestPublishedUtc = ''
    try {
        $raw = Get-LenovoUpdateManifestRemote
        $manifestVersion = ([string]$raw.version).Trim()
        $manifestPublishedUtc = ([string]$raw.publishedUtc).Trim()
        $validated = Test-LenovoUpdateManifestCore -Manifest $raw
        if (-not $validated.IsValid) { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-validation' -Message $validated.Error) }
        $comparison = Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version
        $result.Success = $true; $result.UpdateAvailable = ($comparison -gt 0); $result.Manifest = $validated
    }
    catch {
        $failure = Get-LenovoUpdateFailureInfo -ErrorRecord $_ -DefaultCategory 'runtime' -DefaultStage 'update-check'
        $result.Error=$failure.Message; $result.ErrorCategory=$failure.Category; $result.FailureStage=$failure.Stage; $result.ErrorClass=$failure.ErrorClass; $result.NetworkStatus=$failure.NetworkStatus
    }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_WORKER_COMPLETED' -Stage $(if ($result.FailureStage) { [string]$result.FailureStage } else { 'update-check' }) -Success ([bool]$result.Success) -Data (New-RuntimeDiagnosticData @{ runningVersion=[string]$script:AppVersion; manifestVersion=[string]$manifestVersion; manifestPublishedUtc=[string]$manifestPublishedUtc; updateAvailable=[bool]$result.UpdateAvailable; errorCategory=[string]$result.ErrorCategory; failureStage=[string]$result.FailureStage; errorClass=[string]$result.ErrorClass; networkStatus=[string]$result.NetworkStatus; workerError=[string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'warning' })
    if ($UpdateResultPath) { Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result) }
    return $(if ($result.Success) { 0 } else { 1 })
}
function Start-UpdateCheckWorkerProcess {
    param([Parameter(Mandatory=$true)][string]$ResultPath,[string]$RuntimeSessionId)
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdateCheck','-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}


function Test-LenovoUpdatePackageZip {
    param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)]$Manifest)
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try { $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath) }
    catch { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message ('Update-ZIP konnte nicht geöffnet werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    try {
        $names=@()
        foreach($entry in @($archive.Entries)) {
            $name=[string]$entry.FullName
            if ([string]::IsNullOrWhiteSpace($name)) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen leeren Pfad.') }
            if ($name.Contains('..') -or $name.Contains('/') -or $name.Contains('\')) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen unzulässigen Pfad.') }
            if ($entry.Length -lt 0) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen ungültigen Eintrag.') }
            $names+=$name
        }
        $expected=@($Manifest.PackageFiles|Sort-Object); $actual=@($names|Sort-Object)
        if ($expected.Count -ne $actual.Count) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält nicht die erwartete Anzahl Dateien.') }
        for($i=0;$i -lt $expected.Count;$i++){ if([string]$expected[$i] -ne [string]$actual[$i]){ throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP-Dateiliste stimmt nicht mit dem Manifest überein.') } }
    } finally { $archive.Dispose() }
}

function Prepare-LenovoUpdatePackage {
    param([Parameter(Mandatory=$true)]$Manifest)
    $updateRoot=Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    try {
        if(-not(Test-Path -LiteralPath $updateRoot)){[void](New-Item -ItemType Directory -Path $updateRoot -Force)}
        $work=Join-Path $updateRoot (('{0}-{1}' -f $Manifest.Version,([guid]::NewGuid().ToString('N')))); $payload=Join-Path $work 'payload'
        [void](New-Item -ItemType Directory -Path $payload -Force); $zipPath=Join-Path $work ([string]$Manifest.File); $manifestPath=Join-Path $work 'manifest.json'
        [System.IO.File]::WriteAllText($manifestPath,($Manifest|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    } catch { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-workspace' -Message ('Update-Arbeitsverzeichnis konnte nicht vorbereitet werden: '+$_.Exception.Message) -InnerException $_.Exception) }
    $uri=(Get-LenovoUpdateDownloadBaseUri)+[Uri]::EscapeDataString([string]$Manifest.File); Invoke-LenovoUpdateFileDownload -Uri $uri -DestinationPath $zipPath
    $length=(Get-Item -LiteralPath $zipPath).Length
    if([int64]$length -ne [int64]$Manifest.Size){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-size' -Message 'Update-Dateigröße stimmt nicht mit dem Manifest überein.')}
    try{$actualSha=Get-LenovoSha256Hex -Path $zipPath}catch{throw (New-LenovoUpdateFailureException -Category 'hash' -Stage 'package-hash' -Message ('Update-SHA-256 konnte nicht berechnet werden: '+$_.Exception.Message) -InnerException $_.Exception)}
    if($actualSha -ne ([string]$Manifest.Sha256).ToLowerInvariant()){throw (New-LenovoUpdateFailureException -Category 'hash' -Stage 'package-hash' -Message 'Update-SHA-256 stimmt nicht mit dem Manifest überein.')}
    Test-LenovoUpdatePackageZip -ZipPath $zipPath -Manifest $Manifest
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try{[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$payload)}catch{throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-extract' -Message ('Update-ZIP konnte nicht entpackt werden: '+$_.Exception.Message) -InnerException $_.Exception)}
    $runtimePath=Join-Path $payload 'LenovoBootMenuTray.ps1'
    if(-not(Test-Path -LiteralPath $runtimePath -PathType Leaf)){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-runtime' -Message 'Update-Runtime fehlt im Paket.')}
    $runtimeText=[System.IO.File]::ReadAllText($runtimePath,[System.Text.Encoding]::UTF8); $versionNeedle=('$script:AppVersion = ''{0}''' -f [string]$Manifest.Version)
    if(-not $runtimeText.Contains($versionNeedle)){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-runtime' -Message 'Update-Runtime-Version stimmt nicht mit dem Manifest überein.')}
    return [pscustomobject]@{WorkDir=$work;PayloadDir=$payload;ManifestPath=$manifestPath;Version=[string]$Manifest.Version}
}

function Invoke-UpdatePrepareWorker {
    $result=[ordered]@{Success=$false;WorkDir='';PayloadDir='';ManifestPath='';Version='';Error='';ErrorCategory='';FailureStage='';ErrorClass='';NetworkStatus=''}
    try {
        if(-not $UpdateManifestPath -or -not(Test-Path -LiteralPath $UpdateManifestPath -PathType Leaf)){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-input' -Message 'Update-Manifestdatei fehlt.')}
        try{$manifestJson=[System.IO.File]::ReadAllText($UpdateManifestPath,[System.Text.Encoding]::UTF8)}catch{throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-input' -Message ('Update-Manifestdatei konnte nicht gelesen werden: '+$_.Exception.Message) -InnerException $_.Exception)}
        try{$raw=$manifestJson|ConvertFrom-Json}catch{throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-parse' -Message ('Update-Manifest ist kein gültiges JSON: '+$_.Exception.Message) -InnerException $_.Exception)}
        $validated=Test-LenovoUpdateManifestCore -Manifest $raw
        if(-not $validated.IsValid){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-validation' -Message $validated.Error)}
        if((Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version) -le 0){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'version-eligibility' -Message 'Es liegt keine neuere Version vor.')}
        $prepared=Prepare-LenovoUpdatePackage -Manifest $validated; $result.Success=$true; $result.WorkDir=$prepared.WorkDir; $result.PayloadDir=$prepared.PayloadDir; $result.ManifestPath=$prepared.ManifestPath; $result.Version=$prepared.Version
    } catch {
        $failure=Get-LenovoUpdateFailureInfo -ErrorRecord $_ -DefaultCategory 'runtime' -DefaultStage 'update-prepare'
        $result.Error=$failure.Message; $result.ErrorCategory=$failure.Category; $result.FailureStage=$failure.Stage; $result.ErrorClass=$failure.ErrorClass; $result.NetworkStatus=$failure.NetworkStatus
    }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_WORKER_COMPLETED' -Stage $(if($result.FailureStage){[string]$result.FailureStage}else{'update-prepare'}) -Success ([bool]$result.Success) -Data (New-RuntimeDiagnosticData @{version=[string]$result.Version;errorCategory=[string]$result.ErrorCategory;failureStage=[string]$result.FailureStage;errorClass=[string]$result.ErrorClass;networkStatus=[string]$result.NetworkStatus;workerError=[string]$result.Error}) -Level $(if($result.Success){'info'}else{'error'})
    if($UpdateResultPath){Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result)}
    return $(if($result.Success){0}else{1})
}
function Start-UpdatePrepareWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [string]$RuntimeSessionId
    )
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdatePrepare','-UpdateManifestPath',('"{0}"' -f $ManifestPath),'-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}

function Test-UpdateInstallDirectoryWritable {
    $probe = Join-Path $PSScriptRoot ('.lbs-update-write-{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllText($probe,'probe',(New-Object System.Text.UTF8Encoding($false)))
        return $true
    }
    catch { return $false }
    finally { try { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force } } catch { } }
}

function New-LenovoUpdateInstallerHelper {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helperPath = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelectorUpdate-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
    $scriptText = @'
param(
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$InstallDir,
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [Parameter(Mandatory=$true)][string]$SourceVersion,
    [Parameter(Mandatory=$true)][string]$FailurePrefixBase64,
    [Parameter(Mandatory=$true)][string]$ManualRestartBase64
)
$ErrorActionPreference = 'Stop'
$backup = Join-Path $WorkDir 'backup'
$payload = Join-Path $WorkDir 'payload'
$manifestPath = Join-Path $WorkDir 'manifest.json'
$resultPath = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates\last-update-result.json'
$targetVersion = ''
$rollbackAttempted = $false
$rollbackSucceeded = $false
$failureCategory = ''
$failureStage = ''
$errorClass = ''
$failurePrefix = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FailurePrefixBase64))
$manualRestartMessage = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ManualRestartBase64))
function Write-Result([string]$Status,[string]$Message) {
    $parent = Split-Path -Parent $resultPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $obj=[ordered]@{
        schemaVersion=1
        utc=[datetime]::UtcNow.ToString('o')
        status=$Status
        sourceVersion=$SourceVersion
        targetVersion=$targetVersion
        message=$Message
        rollbackAttempted=[bool]$rollbackAttempted
        rollbackSucceeded=[bool]$rollbackSucceeded
        failureCategory=[string]$failureCategory
        failureStage=[string]$failureStage
        errorClass=[string]$errorClass
    }
    [System.IO.File]::WriteAllText($resultPath,($obj|ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding($false)))
}
function Restart-InstalledApp {
    $launcher=Join-Path $InstallDir 'Start-LenovoBootMenuTray.vbs'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw 'Launcher fehlt nach dem Update.' }
    $wscript=Join-Path $env:SystemRoot 'System32\wscript.exe'
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName=$wscript
    $psi.Arguments=('"{0}"' -f $launcher)
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    return [System.Diagnostics.Process]::Start($psi)
}
function Show-UpdateError([string]$Message) {
    try { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($Message,'Lenovo Boot Selector – Update',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) } catch { }
}
try {
    $failureCategory='manifest'; $failureStage='install-manifest'; $errorClass=''
    try { $parent=[System.Diagnostics.Process]::GetProcessById($ParentPid); [void]$parent.WaitForExit(30000) } catch { }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest fehlt.' }
    $manifest=[System.IO.File]::ReadAllText($manifestPath,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
    $targetVersion=[string]$manifest.version
    $files=@($manifest.packageFiles)
    if ($files.Count -lt 1) { throw 'Paketdateien fehlen.' }
    $failureCategory='install'; $failureStage='backup'; $errorClass=''
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $backup -Force)
    $existing=@{}
    foreach($name in $files) {
        $source=Join-Path $payload ([string]$name)
        $target=Join-Path $InstallDir ([string]$name)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Paketdatei fehlt: $name" }
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $existing[[string]$name]=$true
            Copy-Item -LiteralPath $target -Destination (Join-Path $backup ([string]$name)) -Force
        }
        else { $existing[[string]$name]=$false }
    }
    try {
        $failureCategory='install'; $failureStage='install-files'; $errorClass=''
        foreach($name in $files) {
            Copy-Item -LiteralPath (Join-Path $payload ([string]$name)) -Destination (Join-Path $InstallDir ([string]$name)) -Force
        }
        # Success is intentionally not declared here. The restarted tray must prove
        # that the expected target version is actually running before showing success.
        $failureCategory=''; $failureStage=''; $errorClass=''
        Write-Result 'pending-verification' ('Update auf v' + $targetVersion + ' installiert; Neustart-Verifikation ausstehend.')
        $failureCategory='restart'; $failureStage='restart-after-install'; $errorClass=''
        $started = Restart-InstalledApp
        if (-not $started) { throw 'Lenovo Boot Selector konnte nach dem Update nicht neu gestartet werden.' }
        try { $started.Dispose() } catch { }
    }
    catch {
        $installError=$_.Exception.Message
        $primaryFailureCategory=$failureCategory
        $primaryFailureStage=$failureStage
        $primaryErrorClass=$_.Exception.GetType().FullName
        # ROLLBACK: restore every previous managed file and remove newly introduced files.
        $rollbackAttempted=$true
        $failureCategory='install'; $failureStage='rollback'; $errorClass=''
        try {
            foreach($name in $files) {
                $target=Join-Path $InstallDir ([string]$name)
                $saved=Join-Path $backup ([string]$name)
                if ($existing[[string]$name] -and (Test-Path -LiteralPath $saved -PathType Leaf)) {
                    Copy-Item -LiteralPath $saved -Destination $target -Force
                }
                elseif (-not $existing[[string]$name] -and (Test-Path -LiteralPath $target -PathType Leaf)) {
                    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
                }
            }
            $rollbackSucceeded=$true
        }
        catch {
            $rollbackSucceeded=$false
            throw ($installError + ' | Rollback fehlgeschlagen: ' + $_.Exception.Message)
        }
        $failureCategory=$primaryFailureCategory
        $failureStage=$primaryFailureStage
        $errorClass=$primaryErrorClass
        throw $installError
    }
    try { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
catch {
    $failureMessage=$_.Exception.Message
    if (-not $errorClass) { $errorClass=$_.Exception.GetType().FullName }
    if (-not $failureCategory) { $failureCategory='install' }
    if (-not $failureStage) { $failureStage='install' }
    Write-Result 'failed' $failureMessage
    try {
        $restart = Restart-InstalledApp
        if ($restart) { try { $restart.Dispose() } catch { } }
        else { throw 'Lenovo Boot Selector konnte nach dem fehlgeschlagenen Update nicht neu gestartet werden.' }
    }
    catch {
        Show-UpdateError ($failurePrefix + "`r`n`r`n" + $manualRestartMessage)
    }
}
finally {
    try { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue } catch { }
}
'@
    [System.IO.File]::WriteAllText($helperPath,$scriptText,(New-Object System.Text.UTF8Encoding($true)))
    return $helperPath
}

function Start-LenovoUpdateInstallerHelper {
    param(
        [Parameter(Mandatory=$true)][string]$WorkDir,
        [Parameter(Mandatory=$true)][string]$SourceVersion,
        [Parameter(Mandatory=$true)][string]$FailurePrefix,
        [Parameter(Mandatory=$true)][string]$ManualRestartMessage
    )
    $helper = New-LenovoUpdateInstallerHelper -WorkDir $WorkDir
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $failurePrefixBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($FailurePrefix))
    $manualRestartBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ManualRestartMessage))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -ParentPid {1} -InstallDir "{2}" -WorkDir "{3}" -SourceVersion "{4}" -FailurePrefixBase64 "{5}" -ManualRestartBase64 "{6}"' -f $helper,$PID,$PSScriptRoot,$WorkDir,$SourceVersion,$failurePrefixBase64,$manualRestartBase64)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}


function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.SavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.SavedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.Location' -Values @{ Path=$path }) -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.ShowFolder') -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.NotSavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.NotSavedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
    }
}

function Get-LocalizedUpdateRestartMessage {
    param([Parameter(Mandatory=$true)]$Resolved)

    if ([bool]$Resolved.Success) {
        return (Get-LocalizedString -Key 'Update.RestartSuccessMessage')
    }
    if ([bool]$Resolved.RollbackAttempted -and [bool]$Resolved.RollbackSucceeded) {
        return (Get-LocalizedString -Key 'Update.RestartRollbackMessage')
    }
    if ([string]$Resolved.TargetVersion -and [string]$Resolved.RunningVersion -and ([string]$Resolved.TargetVersion -ne [string]$Resolved.RunningVersion)) {
        return (Get-LocalizedString -Key 'Update.RestartMismatchMessage' -Values @{
            TargetVersion = [string]$Resolved.TargetVersion
            RunningVersion = [string]$Resolved.RunningVersion
        })
    }
    return (Get-LocalizedString -Key 'Update.RestartFailureMessage')
}

function Show-PendingUpdateResultOnStartup {
    $result = Read-LenovoUpdateResult
    if (-not $result) { return $false }

    $resolved = Resolve-LenovoUpdateRestartResultCore -Result $result -RunningVersion $script:AppVersion

    Write-RuntimeDiagnosticEvent -Event 'UPDATE_RESTART_RESULT' -Stage 'update-restart' -Success $resolved.Success -Data (New-RuntimeDiagnosticData @{
        resultUtc = $resolved.ResultUtc
        resultStatus = $resolved.ResultStatus
        resultFormat = $resolved.ResultFormat
        legacySuccess = $resolved.LegacySuccess
        sourceVersion = $resolved.SourceVersion
        targetVersion = $resolved.TargetVersion
        runningVersion = $resolved.RunningVersion
        rollbackAttempted = $resolved.RollbackAttempted
        rollbackSucceeded = $resolved.RollbackSucceeded
        failureCategory = $resolved.FailureCategory
        failureStage = $resolved.FailureStage
        errorClass = $resolved.ErrorClass
        resultMessage = $resolved.StoredMessage
    }) -Level $(if ($resolved.Success) { 'info' } else { 'error' })

    # Consume before showing the modal dialog so this result is shown at most once,
    # even if the process is terminated while the dialog is open.
    Remove-LenovoUpdateResult

    if ($resolved.Success) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.SuccessTitle') -Heading (Get-LocalizedString -Key 'Update.SuccessHeading' -Values @{ Version=$resolved.DisplayVersion }) -Message (Get-LocalizedUpdateRestartMessage -Resolved $resolved) -Kind Info
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.RestartFailureHeading') -Message (Get-LocalizedUpdateRestartMessage -Resolved $resolved) -Kind Error
    }
    return $true
}

function Update-UpdateMenuState {
    # Automatic read-only checks are triggered by popup-open transitions. There is no periodic polling.
    if (-not $script:UpdateState) { return }
    $busy = Test-UpdateRuntimeBusy -State $script:UpdateState
    if ($script:UpdateCheckMenuItem) { $script:UpdateCheckMenuItem.Enabled = -not $busy }
    if ($script:UpdateInstallMenuItem) {
        $script:UpdateInstallMenuItem.Text = Get-LocalizedString -Key 'Update.Install'
        $script:UpdateInstallMenuItem.Enabled = (-not $busy -and $null -ne $script:UpdateState.AvailableManifest)
    }
}

function Show-AvailableUpdateDialog {
    if (-not $script:UpdateState -or [string]$script:UpdateState.Status -ne 'UpdateAvailable' -or $null -eq $script:UpdateState.AvailableManifest) {
        return $false
    }
    $manifest = $script:UpdateState.AvailableManifest
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.Available') -Heading (Get-LocalizedString -Key 'Update.AvailableHeading' -Values @{ Version=$manifest.Version }) -Message (Get-LocalizedString -Key 'Update.AvailableMessage') -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Update.InstallNow') -SecondaryAction { Start-ManualAppUpdate }
    return $true
}

function Stop-UpdateCheckUiWorker {
    if ($script:UpdateState.CheckTimer) { try { $script:UpdateState.CheckTimer.Stop() } catch { }; try { $script:UpdateState.CheckTimer.Dispose() } catch { }; $script:UpdateState.CheckTimer=$null }
    if ($script:UpdateState.CheckProcess) { try { $script:UpdateState.CheckProcess.Dispose() } catch { }; $script:UpdateState.CheckProcess=$null }
}


function Complete-UpdateCheck {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)
    Stop-UpdateCheckUiWorker
    $path=[string]$script:UpdateState.CheckResultPath
    $isPopup = ($Mode -eq 'Popup')
    $failureCategory=''; $failureStage=''; $errorClass=''; $networkStatus=''
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { $failureCategory='runtime'; $failureStage='check-result'; throw (Get-LocalizedString -Key 'Update.CheckNoResult') }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) {
            $failureCategory=([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage=([string]$result.FailureStage).Trim()
            $errorClass=([string]$result.ErrorClass).Trim()
            $networkStatus=([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }
        if ($result.UpdateAvailable) {
            $validated=Test-LenovoUpdateManifestCore -Manifest $result.Manifest
            if (-not $validated.IsValid) { $failureCategory='manifest'; $failureStage='result-manifest-validation'; throw $validated.Error }
            [void](Set-UpdateRuntimeAvailable -State $script:UpdateState -Manifest $validated)
            $script:LastStatusText = Get-LocalizedString -Key 'Update.AvailableStatus' -Values @{ Version=$validated.Version }
            if (-not $isPopup) {
                [void](Show-AvailableUpdateDialog)
            }
            Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$true; availableVersion=$validated.Version; mode=$Mode })
        }
        else {
            $script:UpdateState.AvailableManifest=$null
            [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
            if (-not $isPopup) {
                $script:LastStatusText = Get-LocalizedString -Key 'Update.CurrentStatus' -Values @{ Version=$script:AppVersion }
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NoNewTitle') -Heading (Get-LocalizedString -Key 'Update.CurrentHeading' -Values @{ Version=$script:AppVersion }) -Message (Get-LocalizedString -Key 'Update.NoNewMessage') -Kind Info
            }
            Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$false; mode=$Mode })
        }
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        if (-not $isPopup) {
            $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckFailedStatus'
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckFailedHeading') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
        }
        Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage $(if ($failureStage) { $failureStage } else { 'update-check' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode; errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level warning
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.CheckResultPath=$null
        $script:UpdateState.CheckMode=''
        if ($script:UpdateState.Status -eq 'Failed') { [void](Set-UpdateRuntimeIdle -State $script:UpdateState) }
        Update-UpdateMenuState
        Update-HeaderRefreshStatus
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}
function Complete-ManualUpdateCheck {
    Complete-UpdateCheck -Mode 'Manual'
}

function Complete-PopupUpdateCheck {
    Complete-UpdateCheck -Mode 'Popup'
}

function Start-UpdateCheckUiWorker {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)

    if (Test-UpdateRuntimeBusy -State $script:UpdateState) { return $false }
    [void](Set-UpdateRuntimeChecking -State $script:UpdateState)
    $script:UpdateState.CheckMode=$Mode
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateCheck-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $script:UpdateState.CheckResultPath=$resultPath
    try {
        $proc=Start-UpdateCheckWorkerProcess -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw (Get-LocalizedString -Key 'Update.CheckStartFailed') }
        $script:UpdateState.CheckProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.CheckProcess) { return }
                $script:UpdateState.CheckProcess.Refresh()
                if ($script:UpdateState.CheckProcess.HasExited) {
                    if ([string]$script:UpdateState.CheckMode -eq 'Popup') { Complete-PopupUpdateCheck }
                    else { Complete-ManualUpdateCheck }
                }
            }
            catch {
                if ([string]$script:UpdateState.CheckMode -eq 'Popup') { Complete-PopupUpdateCheck }
                else { Complete-ManualUpdateCheck }
            }
        })
        $script:UpdateState.CheckTimer=$timer; $timer.Start()
        return $true
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Stop-UpdateCheckUiWorker
        $script:UpdateState.CheckResultPath=$null
        $script:UpdateState.CheckMode=''
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
        throw
    }
}

function Start-ManualUpdateCheck {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    try {
        if (-not (Start-UpdateCheckUiWorker -Mode 'Manual')) { return }
        $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckingStatus'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode='Manual' })
    }
    catch {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckStartFailed') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode='Manual' }) -Level warning
    }
    Update-UpdateMenuState
}

function Start-PopupUpdateCheck {
    if (-not $script:UpdateState -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return $false }
    try {
        if (-not (Start-UpdateCheckUiWorker -Mode 'Popup')) { return $false }
        Write-RuntimeDiagnosticEvent -Event 'POPUP_UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode='Popup' })
        Update-UpdateMenuState
        return $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'POPUP_UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode='Popup' }) -Level warning
        Update-UpdateMenuState
        return $false
    }
}

function Stop-UpdatePrepareUiWorker {
    if ($script:UpdateState.PrepareTimer) { try { $script:UpdateState.PrepareTimer.Stop() } catch { }; try { $script:UpdateState.PrepareTimer.Dispose() } catch { }; $script:UpdateState.PrepareTimer=$null }
    if ($script:UpdateState.PrepareProcess) { try { $script:UpdateState.PrepareProcess.Dispose() } catch { }; $script:UpdateState.PrepareProcess=$null }
}

function Exit-TrayForPreparedUpdate {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helper=Start-LenovoUpdateInstallerHelper `
        -WorkDir $WorkDir `
        -SourceVersion $script:AppVersion `
        -FailurePrefix (Get-LocalizedString -Key 'Update.HelperFailurePrefix') `
        -ManualRestartMessage (Get-LocalizedString -Key 'Update.HelperManualRestart')
    if (-not $helper) { throw (Get-LocalizedString -Key 'Update.InstallerStartFailed') }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_INSTALL_HELPER_STARTED' -Stage 'update-install' -Success $true -Data (New-RuntimeDiagnosticData @{ processId=$helper.Id; version=$script:UpdateState.AvailableManifest.Version })
    try { $helper.Dispose() } catch { }
    $script:ExitRequested=$true
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible=$false } } catch { }
    try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
    [System.Windows.Forms.Application]::ExitThread()
}


function Complete-ManualAppUpdatePrepare {
    Stop-UpdatePrepareUiWorker
    $path=[string]$script:UpdateState.PrepareResultPath
    $failureCategory=''; $failureStage=''; $errorClass=''; $networkStatus=''
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { $failureCategory='runtime'; $failureStage='prepare-result'; throw (Get-LocalizedString -Key 'Update.PrepareNoResult') }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) {
            $failureCategory=([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage=([string]$result.FailureStage).Trim()
            $errorClass=([string]$result.ErrorClass).Trim()
            $networkStatus=([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }
        [void](Set-UpdateRuntimeReadyToInstall -State $script:UpdateState)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$result.Version })
        Exit-TrayForPreparedUpdate -WorkDir ([string]$result.WorkDir)
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage $(if ($failureStage) { $failureStage } else { 'update-prepare' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        try { if ($script:UpdateState.ManifestPath -and (Test-Path -LiteralPath $script:UpdateState.ManifestPath)) { Remove-Item -LiteralPath $script:UpdateState.ManifestPath -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.PrepareResultPath=$null; $script:UpdateState.ManifestPath=$null
        Update-UpdateMenuState
    }
}
function Start-ManualAppUpdate {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    $manifest=$script:UpdateState.AvailableManifest
    if (-not $manifest) { return }
    if (-not (Test-UpdateInstallDirectoryWritable)) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NotPossibleTitle') -Heading (Get-LocalizedString -Key 'Update.DirectoryNotWritableHeading') -Message (Get-LocalizedString -Key 'Update.DirectoryNotWritableMessage') -Kind Error
        return
    }
    [void](Set-UpdateRuntimePreparing -State $script:UpdateState)
    $manifestPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateManifest-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdatePrepare-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    $script:UpdateState.ManifestPath=$manifestPath; $script:UpdateState.PrepareResultPath=$resultPath
    try {
        $proc=Start-UpdatePrepareWorkerProcess -ManifestPath $manifestPath -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw (Get-LocalizedString -Key 'Update.PrepareStartFailed') }
        $script:UpdateState.PrepareProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.PrepareProcess) { return }
                $script:UpdateState.PrepareProcess.Refresh()
                if ($script:UpdateState.PrepareProcess.HasExited) { Complete-ManualAppUpdatePrepare }
            } catch { Complete-ManualAppUpdatePrepare }
        })
        $script:UpdateState.PrepareTimer=$timer; $timer.Start()
        $script:LastStatusText = Get-LocalizedString -Key 'Update.PreparingStatus' -Values @{ Version=$manifest.Version }
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$manifest.Version })
    }
    catch {
        Stop-UpdatePrepareUiWorker
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
}


function Get-LegacyAutostartInfo {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $root = $service.GetFolder('\')
        $task = $root.GetTask("\$($script:LegacyAutostartTaskName)")
        if (-not $task) { return [pscustomobject]@{ Enabled = $false } }
        return [pscustomobject]@{ Enabled = [bool]$task.Enabled }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false }
    }
}

function Get-AutostartLauncherPath {
    return (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
}

function Get-AutostartCommand {
    $launcher = Get-AutostartLauncherPath
    if (-not (Test-Path -LiteralPath $launcher)) { return $null }
    $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
    return ('"{0}" //B //NoLogo "{1}"' -f $wscript, $launcher)
}

function Get-AutostartRunValue {
    param([Parameter(Mandatory=$true)][string]$Name)

    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $props = Get-ItemProperty -Path $runKey -Name $Name -ErrorAction SilentlyContinue
        if (-not $props) { return '' }
        return [string]$props.($Name)
    }
    catch {
        return ''
    }
}

function Get-AutostartInfo {
    try {
        $canonicalValue = Get-AutostartRunValue -Name $script:AutostartRunValueName
        $legacyValue = Get-AutostartRunValue -Name $script:LegacyAutostartRunValueName
        $usesLegacyValue = (-not $canonicalValue -and [bool]$legacyValue)
        $value = if ($canonicalValue) { $canonicalValue } else { $legacyValue }
        if (-not $value) {
            return [pscustomobject]@{ Enabled = $false; CurrentPath = $false; UsesHiddenLauncher = $false; UsesLegacyValue = $false }
        }
        $launcher = Get-AutostartLauncherPath
        $currentPath = (($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) -or
            ($script:ScriptPath -and ($value.IndexOf($script:ScriptPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)))
        $usesHiddenLauncher = ($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
        return [pscustomobject]@{
            Enabled = $true
            CurrentPath = $currentPath
            UsesHiddenLauncher = $usesHiddenLauncher
            UsesLegacyValue = $usesLegacyValue
        }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false; CurrentPath = $false; UsesHiddenLauncher = $false; UsesLegacyValue = $false }
    }
}

function Set-AutostartEnabled([bool]$Enabled) {
    if (-not $script:ScriptPath) {
        throw 'Der Pfad der Anwendung konnte nicht ermittelt werden.'
    }

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if ($Enabled) {
        if (-not (Test-Path $runKey)) { [void](New-Item -Path $runKey -Force) }
        $command = Get-AutostartCommand
        if (-not $command) { throw 'Der versteckte Autostart-Launcher wurde nicht gefunden.' }

        # LBS-19 migration is deliberately ordered: establish the canonical value
        # first, then remove the exact legacy value. A failed canonical write leaves
        # the working legacy registration untouched and retryable.
        Set-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -Type String -Value $command
        if ($script:LegacyAutostartRunValueName -and $script:LegacyAutostartRunValueName -ne $script:AutostartRunValueName) {
            Remove-ItemProperty -Path $runKey -Name $script:LegacyAutostartRunValueName -ErrorAction SilentlyContinue
        }
    }
    else {
        Remove-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -ErrorAction SilentlyContinue
        if ($script:LegacyAutostartRunValueName -and $script:LegacyAutostartRunValueName -ne $script:AutostartRunValueName) {
            Remove-ItemProperty -Path $runKey -Name $script:LegacyAutostartRunValueName -ErrorAction SilentlyContinue
        }
    }
}

function Repair-AutostartLauncherIfNeeded {
    try {
        $info = Get-AutostartInfo
        if ($info.Enabled) {
            # The Run value belongs exclusively to this app. Always migrate it to
            # the currently launched package and the hidden WScript/VBS launcher.
            # This also fixes upgrades from older versions that started PowerShell
            # directly and could leave a visible console window at logon.
            Set-AutostartEnabled -Enabled:$true
        }
    }
    catch { }
}


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


function Get-ActiveLocale {
    return (Resolve-LocaleIdCore -Locale $script:UiLocale)
}

function Set-ActiveLocale {
    param(
        [Parameter(Mandatory=$true)][string]$Locale,
        [switch]$Persist
    )

    $resolved = Resolve-LocaleIdCore -Locale $Locale
    $changed = ([string]$script:UiLocale) -ne $resolved
    $script:UiLocale = $resolved

    if ($Persist) {
        # An explicit UI/API language action is evidence of user intent even
        # when the selected locale already matches the current locale.
        $script:LocalePreferenceSource = 'user'
        $script:LocalePreferenceNeedsConfirmation = $false
        Save-AppSettings
    }
    return $resolved
}

function Get-LocalizedString {
    param(
        [Parameter(Mandatory=$true)][string]$Key,
        [object[]]$Arguments,
        [System.Collections.IDictionary]$Values
    )

    return Get-LocalizedStringCore -Key $Key -Locale (Get-ActiveLocale) -Arguments $Arguments -Values $Values
}






function Test-ManageEntriesDirty {
    if (-not $script:IsManageEntriesMode) { return $false }
    if (-not (Test-StringSequenceEqual -Left $script:ManageEntryOrder -Right $script:ManageBaselineEntryOrder)) { return $true }
    if (-not (Test-StringSequenceEqual -Left $script:ManageHiddenEntryGuids -Right $script:ManageBaselineHiddenEntryGuids -Sort)) { return $true }
    if (-not (Test-EntryAliasMapsEqual -Left $script:ManageEntryAliases -Right $script:ManageBaselineEntryAliases)) { return $true }

    # A still-open alias editor is part of the draft. Reflect its current text
    # immediately so the global save button responds before Enter/Übernehmen.
    if ($script:ManageAliasEditGuid -and $script:Popup -and -not $script:Popup.IsDisposed) {
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor -and [string]$editor.Tag) {
            $guid = ([string]$editor.Tag).ToLowerInvariant()
            $current = ([string]$editor.Text).Trim()
            $draft = ''
            if ($script:ManageEntryAliases.ContainsKey($guid)) { $draft = ([string]$script:ManageEntryAliases[$guid]).Trim() }
            if ($current -ne $draft) { return $true }
        }
    }
    return $false
}

function Update-ManageSaveButtonState {
    $button = $script:ManageSaveButton
    if (-not $button -or $button.IsDisposed) { return }
    $dirty = Test-ManageEntriesDirty
    $button.Enabled = $dirty
    if ($dirty) {
        $button.ForeColor = $script:ColorPrimary
        $button.BackColor = $script:ColorAccent
        $button.FlatAppearance.BorderColor = $script:ColorAccent
        $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    else {
        $button.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
        $button.BackColor = [Drawing.Color]::FromArgb(35,35,35)
        $button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
        $button.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}


function Read-AppSettingsRepository {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Write-AppSettingsRepository {
    param(
        [Parameter(Mandatory=$true)][string]$Directory,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Payload
    )

    [void](New-Item -ItemType Directory -Path $Directory -Force)
    $json = $Payload | ConvertTo-Json -Depth 6
    $tmp = $Path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Remove-LegacySessionRestoreMarker {
    param(
        [Parameter(Mandatory=$true)][string]$RegistryPath,
        [Parameter(Mandatory=$true)][string]$ValueName
    )

    try {
        Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
    }
    catch { }
}


function Get-AppSettings {
    try {
        $obj = Read-AppSettingsRepository -Path $script:SettingsPath
        if ($null -eq $obj) {
            return New-DefaultAppSettingsCore
        }
        return ConvertTo-NormalizedAppSettingsCore -Source $obj
    }
    catch {
        return New-DefaultAppSettingsCore
    }
}

function Save-AppSettings {
    $aliases = [ordered]@{}
    foreach ($key in @($script:EntryAliases.Keys | Sort-Object)) {
        $value = ([string]$script:EntryAliases[$key]).Trim()
        if ($key -and $value) { $aliases[[string]$key] = $value }
    }

    $preferenceSource = ([string]$script:LocalePreferenceSource).Trim().ToLowerInvariant()
    if ($preferenceSource -notin @('default','user','migration-pending')) { $preferenceSource = 'default' }

    $payload = [ordered]@{
        schemaVersion = 6
        locale = Resolve-LocaleIdCore -Locale $script:UiLocale
        localePreferenceSource = $preferenceSource
        # Keep an unmigrated legacy default only until the new SYSTEM-backed
        # default architecture has been installed successfully.
        defaultGuid = $script:LegacyDefaultGuid
        entryOrder = @($script:EntryOrder)
        hiddenEntryGuids = @($script:HiddenEntryGuids)
        # v0.2.27: aliases are user-interface metadata only. Keys are stable
        # firmware GUIDs; no privileged task identity is ever changed.
        entryAliases = $aliases
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $payload
}

function Load-AppSettings {
    $settings = Get-AppSettings
    $script:UiLocale = Resolve-LocaleIdCore -Locale ([string]$settings.locale)
    $script:LocalePreferenceSource = [string]$settings.localePreferenceSource
    $script:LocalePreferenceNeedsConfirmation = [bool]$settings.localePreferenceNeedsConfirmation
    $script:LegacyDefaultGuid = if ($settings.defaultGuid) { ([string]$settings.defaultGuid).ToLowerInvariant() } else { $null }
    $script:DefaultGuid = $null
    $script:EntryOrder = @($settings.entryOrder)
    $script:HiddenEntryGuids = @($settings.hiddenEntryGuids)
    $script:EntryAliases = Convert-EntryAliasesToHashtable $settings.entryAliases

    # v0.2.21 and earlier used an HKCU Volatile Environment marker for a
    # login-time restore. v0.2.22 no longer uses that mechanism.
    Remove-LegacySessionRestoreMarker -RegistryPath $script:LegacySessionRestoreRegistryPath -ValueName $script:LegacySessionRestoreValueName
}

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


function Get-EntryAlias {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [switch]$UseManageDraft
    )
    $normalized = $Guid.ToLowerInvariant()
    $map = if ($UseManageDraft) { $script:ManageEntryAliases } else { $script:EntryAliases }
    if ($map -and $map.ContainsKey($normalized)) {
        $value = ([string]$map[$normalized]).Trim()
        if ($value) { return $value }
    }
    return $null
}

function Get-EntryDisplayTitle {
    param(
        [Parameter(Mandatory=$true)]$Entry,
        [switch]$UseManageDraft
    )
    $alias = Get-EntryAlias -Guid ([string]$Entry.Guid) -UseManageDraft:$UseManageDraft
    if ($alias) { return $alias }
    return [string]$Entry.Title
}

function Set-ManageEntryAliasDraft {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [AllowEmptyString()][string]$Alias
    )
    $normalized = $Guid.ToLowerInvariant()
    $value = if ($null -eq $Alias) { '' } else { ([string]$Alias).Trim() }
    if ($value) {
        $script:ManageEntryAliases[$normalized] = $value
    }
    else {
        [void]$script:ManageEntryAliases.Remove($normalized)
    }
}

function Commit-ActiveManageAliasEditor {
    if (-not $script:ManageAliasEditGuid) { return }
    try {
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
            if ($editor -and [string]$editor.Tag) {
                Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
            }
        }
    }
    finally {
        $script:ManageAliasEditGuid = $null
    }
}


function Get-OrderedEntriesForUi {
    param(
        [switch]$IncludeHidden,
        [switch]$UseManageDraft
    )

    $order = if ($UseManageDraft) { @($script:ManageEntryOrder) } else { @($script:EntryOrder) }
    $hidden = if ($UseManageDraft) { @($script:ManageHiddenEntryGuids) } else { @($script:HiddenEntryGuids) }
    return @(Get-OrderedEntriesCore -Source @($script:CurrentEntries) -Order $order -Hidden $hidden -IncludeHidden:$IncludeHidden)
}


function Test-ManageEntryHidden {
    param([Parameter(Mandatory=$true)][string]$Guid)
    return (Test-GuidInList -Guid $Guid -List $script:ManageHiddenEntryGuids)
}

function Toggle-ManageEntryVisibility {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $normalized = $Guid.ToLowerInvariant()
    if (Test-ManageEntryHidden -Guid $normalized) {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids | Where-Object { ([string]$_).ToLowerInvariant() -ne $normalized })
    }
    else {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids) + $normalized
    }
}

function Move-ManageEntry {
    param(
        [Parameter(Mandatory=$true)][string]$MovedGuid,
        [Parameter(Mandatory=$true)][string]$TargetGuid,
        [bool]$After = $false
    )

    $moved = $MovedGuid.ToLowerInvariant()
    $target = $TargetGuid.ToLowerInvariant()
    if ($moved -eq $target) { return }

    $list = New-Object System.Collections.ArrayList
    foreach ($guid in @($script:ManageEntryOrder)) {
        if ([string]$guid -and ([string]$guid).ToLowerInvariant() -ne $moved) {
            [void]$list.Add(([string]$guid).ToLowerInvariant())
        }
    }

    $targetIndex = $list.IndexOf($target)
    if ($targetIndex -lt 0) {
        [void]$list.Add($moved)
    }
    else {
        $insertIndex = $targetIndex + $(if ($After) { 1 } else { 0 })
        if ($insertIndex -gt $list.Count) { $insertIndex = $list.Count }
        $list.Insert($insertIndex, $moved)
    }
    $script:ManageEntryOrder = @($list)
}

function Update-ManageEntriesUiState {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $sectionLabel = $script:Popup.Controls.Find('SectionLabel', $true) | Select-Object -First 1
    $manageButton = $script:Popup.Controls.Find('ManageEntriesButton', $true) | Select-Object -First 1
    $managePanel = $script:Popup.Controls.Find('ManageEntriesPanel', $true) | Select-Object -First 1
    $configSectionPanel = $script:Popup.Controls.Find('ConfigSectionPanel', $true) | Select-Object -First 1
    $settingsPanel = $script:Popup.Controls.Find('SettingsPanel', $true) | Select-Object -First 1
    $defaultPanel = $script:Popup.Controls.Find('DefaultPanel', $true) | Select-Object -First 1
    $settingsDivider = $script:Popup.Controls.Find('SettingsDivider', $true) | Select-Object -First 1
    $restartPanel = $script:Popup.Controls.Find('RestartPanel', $true) | Select-Object -First 1
    $footerPanel = $script:Popup.Controls.Find('FooterPanel', $true) | Select-Object -First 1

    if ($sectionLabel) { $sectionLabel.Text = if ($script:IsManageEntriesMode) { Get-LocalizedString -Key 'Manage.Section' } else { Get-LocalizedString -Key 'Popup.NextBootSection' } }
    if ($manageButton) {
        $manageButton.Visible = -not $script:IsManageEntriesMode
        $manageButton.Enabled = (-not $script:IsManageEntriesMode -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
    }
    if ($managePanel) {
        $managePanel.Visible = $script:IsManageEntriesMode
        if ($script:IsManageEntriesMode) { $managePanel.BringToFront() }
    }
    foreach ($control in @($configSectionPanel,$settingsPanel,$defaultPanel,$settingsDivider,$restartPanel,$footerPanel)) {
        if ($control) { $control.Visible = -not $script:IsManageEntriesMode }
    }

    if ($script:ManageEntriesMenuItem) {
        $script:ManageEntriesMenuItem.Enabled = (-not $script:IsManageEntriesMode -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
    }
}

function Start-ManageEntriesMode {
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    if ($script:IsManageEntriesMode) { return }
    if ($script:CurrentEntries.Count -eq 0) { return }

    $script:ManageEntryOrder = @((Get-OrderedEntriesForUi -IncludeHidden) | ForEach-Object { $_.Guid })
    $script:ManageHiddenEntryGuids = @($script:HiddenEntryGuids)
    $script:ManageEntryAliases = Copy-EntryAliasMap $script:EntryAliases
    $script:ManageBaselineEntryOrder = @($script:ManageEntryOrder)
    $script:ManageBaselineHiddenEntryGuids = @($script:ManageHiddenEntryGuids)
    $script:ManageBaselineEntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
    $script:ManageAliasEditGuid = $null
    $script:IsManageEntriesMode = $true
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusEditing'
    Update-ManageEntriesUiState
    Update-PopupRows
    Update-ManageSaveButtonState
}

function Stop-ManageEntriesMode {
    param([switch]$Save)
    if (-not $script:IsManageEntriesMode) { return }

    if ($Save) {
        Commit-ActiveManageAliasEditor
        $script:EntryOrder = @($script:ManageEntryOrder)
        $script:HiddenEntryGuids = @($script:ManageHiddenEntryGuids | Select-Object -Unique)
        $script:EntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
        Save-AppSettings
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusSaved'
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusDiscarded'
    }

    $script:IsManageEntriesMode = $false
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageBaselineEntryOrder = @()
    $script:ManageBaselineHiddenEntryGuids = @()
    $script:ManageBaselineEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    Update-ManageEntriesUiState
    Update-PopupRows
}


function Get-DefaultEntryTitle {
    if (-not $script:DefaultGuid) { return (Get-LocalizedString -Key 'Settings.NoDefaultTarget') }
    $entry = Get-EntryByGuid $script:DefaultGuid
    if ($entry) { return (Get-EntryDisplayTitle -Entry $entry) }
    return (Get-LocalizedString -Key 'Settings.DefaultTargetUnavailable')
}

function Update-DefaultUi {
    if ($script:DefaultButton -and -not $script:DefaultButton.IsDisposed) {
        $meta = Get-TaskBrokerMetadata
        $schemaReady = ($meta -and ($script:SupportedTaskBrokerVersions -contains [string]$meta.version))
        $checking = ($schemaReady -and $null -eq $script:TaskBrokerReadyCached)
        $sessionReady = ($script:TaskBrokerReadyCached -eq $true)
        $enabled = ($schemaReady -and $sessionReady -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
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


function Refresh-SystemDefaultState {
    $script:DefaultGuid = $null
    try {
        $script:DefaultGuid = Get-TaskBrokerDefaultTargetGuid
    }
    catch {
        $script:DefaultGuid = $null
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_STATE_READ' -Stage 'default-read' -Success $false -ErrorRecord $_ -Level warning
    }

    Update-DefaultUi
    return $script:DefaultGuid
}

function Complete-LegacyDefaultMigration {
    if (-not $script:LegacyDefaultGuid) { return }
    $script:LegacyDefaultGuid = $null
    try { Save-AppSettings } catch { }
}

function Set-DefaultGuid {
    param([AllowNull()][string]$Guid)
    if (Test-MaintenanceBusy) { throw 'Während der Wartung kann das Standard-Startziel nicht geändert werden.' }
    if (Test-BootTargetDriftDetected) { throw 'Nach einer Änderung der Startziele müssen die Systemfunktionen zuerst neu initialisiert werden.' }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $operation = if ($Guid) { 'set' } else { 'clear' }
    try {
        if (-not (Test-TaskBrokerReady)) {
            throw 'Das Standard-Startziel ist erst nach Einrichtung der Systemfunktionen verfügbar.'
        }

        if ($Guid) {
            $normalized = $Guid.ToLowerInvariant()
            Set-TaskBrokerDefaultTarget -Guid $normalized
            [void](Refresh-SystemDefaultState)
            if (-not $script:DefaultGuid -or $script:DefaultGuid -ne $normalized) {
                throw 'Das systemweite Standardziel konnte nach der Aufgaben-Ausführung nicht verifiziert werden.'
            }

            $entry = Get-EntryByGuid $normalized
            $name = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { $normalized }
            $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemSavedStatus' -Values @{ Name=$name }
        }
        else {
            Clear-TaskBrokerDefaultTarget
            [void](Refresh-SystemDefaultState)
            if ($script:DefaultGuid) { throw 'Das systemweite Standardziel konnte nicht deaktiviert werden.' }
            $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemDisabledStatus'
        }

        Complete-LegacyDefaultMigration
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) }) -Level error
        throw
    }
}

function New-DefaultTargetMenu {
    $menu = New-Object LenovoContextMenuStrip
    $menu.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $menu.ForeColor = $script:ColorPrimary
    $menu.Renderer = $script:MenuRenderer
    $menu.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $menu.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $menu.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $menu

    $none = New-Object System.Windows.Forms.ToolStripMenuItem((Get-LocalizedString -Key 'Settings.NoDefaultTarget'))
    $none.Checked = -not [bool]$script:DefaultGuid
    $none.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
    $none.Add_Click({
        try { Set-DefaultGuid -Guid $null }
        catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
    })
    [void]$menu.Items.Add($none)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    foreach ($entry in @(Get-OrderedEntriesForUi)) {
        $item = New-Object System.Windows.Forms.ToolStripMenuItem((Get-EntryDisplayTitle -Entry $entry))
        $item.Tag = $entry.Guid
        $item.Checked = ($script:DefaultGuid -and $entry.Guid -eq $script:DefaultGuid)
        $item.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
        $item.Add_Click({
            try { Set-DefaultGuid -Guid ([string]$this.Tag) }
            catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
        })
        [void]$menu.Items.Add($item)
    }
    return $menu
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    try {
        if ($script:DefaultContextMenu) { $script:DefaultContextMenu.Dispose() }
    } catch { }
    $script:DefaultContextMenu = New-DefaultTargetMenu
    $script:DefaultContextMenu.Show($Owner, (New-Object Drawing.Point(0, $Owner.Height)))
}


function Show-LenovoNoticeDialog {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Heading,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Kind = 'Info',
        [string]$SecondaryButtonText,
        [scriptblock]$SecondaryAction
    )

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(470, 245)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $titleLabel = New-Label -Text $Title -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 420 -Height 24
    $root.Controls.Add($titleLabel)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(434,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyphText = if ($Kind -eq 'Error') { '×' } elseif ($Kind -eq 'Warning') { '!' } else { 'i' }
    $glyphColor = if ($Kind -eq 'Error') { $script:ColorAccent } elseif ($Kind -eq 'Warning') { $script:ColorWarning } else { $script:ColorCyan }
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $headingLabel = New-Label -Text $Heading -Font (New-Object Drawing.Font('Segoe UI', 9.6, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 380 -Height 24
    $root.Controls.Add($headingLabel)
    $messageLabel = New-Label -Text $Message -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 88 -Width 380 -Height 78
    $messageLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($messageLabel)

    if (-not [string]::IsNullOrWhiteSpace($SecondaryButtonText) -and $SecondaryAction) {
        $secondary = New-Object System.Windows.Forms.Button
        $secondary.Text = $SecondaryButtonText
        $secondary.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
        $secondary.ForeColor = $script:ColorPrimary
        $secondary.BackColor = [Drawing.Color]::FromArgb(34,34,34)
        $secondary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $secondary.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
        $secondary.FlatAppearance.BorderSize = 1
        $secondary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
        $secondary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(38,38,38)
        $secondary.Location = New-Object Drawing.Point(184,190)
        $secondary.Size = New-Object Drawing.Size(146,34)
        $secondary.Cursor = [System.Windows.Forms.Cursors]::Hand
        $secondaryActionLocal = $SecondaryAction
        $dialogLocal = $form
        $secondary.Add_Click({
            param($sender,$eventArgs)
            try {
                $result = & $secondaryActionLocal
                if ($result -ne $false) {
                    $dialogLocal.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $dialogLocal.Close()
                }
            } catch { }
        }.GetNewClosure())
        $root.Controls.Add($secondary)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = Get-LocalizedString -Key 'Common.OK'
    $ok.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $ok.ForeColor = [Drawing.Color]::White
    $ok.BackColor = $script:ColorAccent
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderSize = 0
    $ok.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $ok.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $ok.Location = New-Object Drawing.Point(342,190)
    $ok.Size = New-Object Drawing.Size(110,34)
    $ok.Cursor = [System.Windows.Forms.Cursors]::Hand
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $root.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $ok
    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { [void]$form.ShowDialog($owner) } else { [void]$form.ShowDialog() }
    }
    finally { $form.Dispose() }
}

function Show-LocaleMigrationDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, 260)
    $form.KeyPreview = $true
    $form.Tag = $null

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $title = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationTitle') -Font (New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $heading = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationHeading') -Font (New-Object Drawing.Font('Segoe UI',9.6,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 28 -Y 62 -Width 440 -Height 24
    $root.Controls.Add($heading)
    $message = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationMessage') -Font (New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 28 -Y 92 -Width 440 -Height 92
    $message.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($message)

    $german = New-Object System.Windows.Forms.Button
    $german.Text = Get-LocalizedString -Key 'Language.MigrationKeepGerman'
    $german.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)
    $german.ForeColor = $script:ColorPrimary
    $german.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $german.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $german.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $german.FlatAppearance.BorderSize = 1
    $german.Location = New-Object Drawing.Point(196,204)
    $german.Size = New-Object Drawing.Size(136,34)
    $german.Cursor = [System.Windows.Forms.Cursors]::Hand
    $german.Add_Click({ $form.Tag = 'de-DE'; $form.Close() })
    $root.Controls.Add($german)

    $english = New-Object System.Windows.Forms.Button
    $english.Text = Get-LocalizedString -Key 'Language.MigrationUseEnglish'
    $english.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Bold)
    $english.ForeColor = [Drawing.Color]::White
    $english.BackColor = $script:ColorAccent
    $english.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $english.FlatAppearance.BorderSize = 0
    $english.Location = New-Object Drawing.Point(344,204)
    $english.Size = New-Object Drawing.Size(136,34)
    $english.Cursor = [System.Windows.Forms.Cursors]::Hand
    $english.Add_Click({ $form.Tag = 'en-US'; $form.Close() })
    $root.Controls.Add($english)
    $form.AcceptButton = $english

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { [void]$form.ShowDialog($owner) } else { [void]$form.ShowDialog() }
        return [string]$form.Tag
    }
    finally { $form.Dispose() }
}

function Show-LenovoSystemFunctionsDialog {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)

    $isRemove = ($Mode -eq 'Remove')
    $height = if ($isRemove) { 330 } else { 270 }
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, $height)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    if ($Mode -eq 'Remove') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Remove'
        $glyphText = '!'
        $glyphColor = $script:ColorWarning
    }
    elseif ($Mode -eq 'Repair') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Repair'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Migrate') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.MigrateHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.MigrateBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Repair'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Reinitialize') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Reinitialize'
        $glyphText = '+'
        $glyphColor = $script:ColorCyan
    }
    else {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Setup'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }

    $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI',15.0,[Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)
    $heading = New-Label -Text $headingText -Font (New-Object Drawing.Font('Segoe UI',9.6,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 410 -Height 24
    $root.Controls.Add($heading)
    $bodyHeight = if ($isRemove) { 145 } else { 90 }
    $body = New-Label -Text $bodyText -Font (New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 90 -Width 410 -Height $bodyHeight
    $body.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($body)

    $buttonY = $height - 54
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.Location = New-Object Drawing.Point(272,$buttonY)
    $cancel.Size = New-Object Drawing.Size(100,34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $primary = New-Object System.Windows.Forms.Button
    $primary.Text = $primaryText
    $primary.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Bold)
    $primary.ForeColor = [Drawing.Color]::White
    $primary.BackColor = $script:ColorAccent
    $primary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $primary.FlatAppearance.BorderSize = 0
    $primary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $primary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $primary.Location = New-Object Drawing.Point(382,$buttonY)
    $primary.Size = New-Object Drawing.Size(100,34)
    $primary.Cursor = [System.Windows.Forms.Cursors]::Hand
    $primary.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($primary)
    $form.AcceptButton = $primary
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally { $form.Dispose() }
}

function Show-LenovoRestartDialog {
    param([Parameter(Mandatory=$true)][string]$TargetName)

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.ClientSize = New-Object Drawing.Size(430, 240)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'RestartDialogRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(430, 240)
    $root.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.Controls.Add($root)

    $title = New-Label -Text (Get-LocalizedString -Key 'Restart.DialogTitle') -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 330 -Height 24
    $root.Controls.Add($title)

    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18, 43)
    $divider.Size = New-Object Drawing.Size(390, 1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyph = New-Label -Text '!' -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorWarning -X 18 -Y 58 -Width 26 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $question = New-Label -Text (Get-LocalizedString -Key 'Restart.Question') -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 58 -Width 340 -Height 24
    $root.Controls.Add($question)

    $targetCaption = New-Label -Text (Get-LocalizedString -Key 'Restart.NextTarget') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 54 -Y 92 -Width 330 -Height 18
    $root.Controls.Add($targetCaption)

    $target = New-Label -Text $TargetName -Font (New-Object Drawing.Font('Segoe UI', 9.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 109 -Width 342 -Height 24
    $target.AutoEllipsis = $true
    $root.Controls.Add($target)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(28,28,28)
    $cancel.Location = New-Object Drawing.Point(206, 180)
    $cancel.Size = New-Object Drawing.Size(96, 34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $restart = New-Object System.Windows.Forms.Button
    $restart.Text = Get-LocalizedString -Key 'Restart.Action'
    $restart.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $restart.ForeColor = [Drawing.Color]::White
    $restart.BackColor = $script:ColorAccent
    $restart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restart.FlatAppearance.BorderColor = $script:ColorAccent
    $restart.FlatAppearance.BorderSize = 1
    $restart.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $restart.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $restart.Location = New-Object Drawing.Point(312, 180)
    $restart.Size = New-Object Drawing.Size(96, 34)
    $restart.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restart.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($restart)

    $form.AcceptButton = $restart
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally {
        $form.Dispose()
    }
}


function Test-MaintenanceBusy {
    return (Test-MaintenanceRuntimeBusy -State $script:MaintenanceState)
}

function Get-MaintenanceMode {
    return (Get-MaintenanceRuntimeMode -State $script:MaintenanceState)
}

function Get-SystemFunctionsPresentationState {
    if (Test-MaintenanceBusy) {
        return ('Busy-' + (Get-MaintenanceMode))
    }
    if (Get-TaskBrokerInteractiveReady) {
        if (Test-BootTargetDriftDetected) { return 'ReinitializeRequired' }
        return 'Ready'
    }
    if (Test-TaskBrokerInstallationPresent) { return 'RepairRequired' }
    return 'SetupRequired'
}

function Get-MaintenanceBusyStatusText {
    $mode = Get-MaintenanceMode
    if ($mode -eq 'Remove') { return (Get-LocalizedString -Key 'Maintenance.Busy.Remove') }
    if ($mode -eq 'Reinitialize') { return (Get-LocalizedString -Key 'Maintenance.Busy.Reinitialize') }
    if ($mode -eq 'Repair' -or $mode -eq 'Migrate') { return (Get-LocalizedString -Key 'Maintenance.Busy.Repair') }
    return (Get-LocalizedString -Key 'Maintenance.Busy.Setup')
}

function New-MaintenanceStatePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Name = 'MaintenanceStatePanel'
    $panel.Location = New-Object Drawing.Point(0, 60)
    $panel.Size = New-Object Drawing.Size(390, 592)
    $panel.BackColor = $script:ColorBackground
    $panel.Visible = $false

    $caption = New-Label -Text (Get-LocalizedString -Key 'Maintenance.Caption') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 106 -Width 358 -Height 18
    $caption.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($caption)

    $glyph = New-Label -Text '⚙' -Font (New-Object Drawing.Font('Segoe UI Symbol', 24.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorAccent -X 166 -Y 134 -Width 58 -Height 58
    $glyph.Name = 'MaintenanceGlyph'
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($glyph)

    $heading = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 11.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 32 -Y 204 -Width 326 -Height 30
    $heading.Name = 'MaintenanceHeading'
    $heading.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($heading)

    $message = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 42 -Y 244 -Width 306 -Height 72
    $message.Name = 'MaintenanceMessage'
    $message.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($message)

    $action = New-Object System.Windows.Forms.Button
    $action.Name = 'MaintenancePrimaryButton'
    $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
    $action.Font = New-Object Drawing.Font('Segoe UI', 8.7, [Drawing.FontStyle]::Bold)
    $action.ForeColor = [Drawing.Color]::White
    $action.BackColor = $script:ColorAccent
    $action.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $action.FlatAppearance.BorderSize = 0
    $action.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $action.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $action.Location = New-Object Drawing.Point(55, 334)
    $action.Size = New-Object Drawing.Size(280, 38)
    $action.Cursor = [System.Windows.Forms.Cursors]::Hand
    $action.Add_Click({
        if (Test-MaintenanceBusy) { return }
        if ((Get-SystemFunctionsPresentationState) -eq 'ReinitializeRequired') {
            Prompt-TaskBrokerReinitialize
            return
        }
        Prompt-TaskBrokerInstall
    })
    $panel.Controls.Add($action)

    $hint = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 7.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 42 -Y 388 -Width 306 -Height 52
    $hint.Name = 'MaintenanceHint'
    $hint.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($hint)

    return $panel
}

function Update-MaintenanceUi {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $state = Get-SystemFunctionsPresentationState
    $busy = $state.StartsWith('Busy-')
    $ready = ($state -eq 'Ready')

    $panelMatches = $script:Popup.Controls.Find('MaintenanceStatePanel', $true)
    $panel = if ($panelMatches.Count -gt 0) { $panelMatches[0] } else { $null }
    if ($panel) {
        $heading = $panel.Controls['MaintenanceHeading']
        $message = $panel.Controls['MaintenanceMessage']
        $action = $panel.Controls['MaintenancePrimaryButton']
        $hint = $panel.Controls['MaintenanceHint']
        $glyph = $panel.Controls['MaintenanceGlyph']

        if ($ready) {
            $panel.Visible = $false
        }
        else {
            $panel.Visible = $true
            $panel.BringToFront()
            if ($state -eq 'SetupRequired') {
                $glyph.Text = '⚙'
                $glyph.ForeColor = $script:ColorAccent
                $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
                $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupMessage'
                $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHint'
            }
            elseif ($state -eq 'RepairRequired') {
                $glyph.Text = '!'
                $glyph.ForeColor = $script:ColorWarning
                $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairMessage'
                $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHint'
            }
            elseif ($state -eq 'ReinitializeRequired') {
                $glyph.Text = '+'
                $glyph.ForeColor = $script:ColorCyan
                if (Test-BootTargetDriftHasNewTargets) {
                    $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.NewTargetHeading'
                    $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.NewTargetMessage'
                }
                else {
                    $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.TargetsChangedHeading'
                    $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.TargetsChangedMessage'
                }
                $action.Text = Get-LocalizedString -Key 'Maintenance.Action.Reinitialize'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHint'
            }
            else {
                $mode = Get-MaintenanceMode
                $glyph.Text = '…'
                $glyph.ForeColor = $script:ColorCyan
                $heading.Text = Get-MaintenanceBusyStatusText
                $message.Text = if ($mode -eq 'Remove') { Get-LocalizedString -Key 'Maintenance.Panel.BusyRemoveMessage' } elseif ($mode -eq 'Reinitialize') { Get-LocalizedString -Key 'Maintenance.Panel.BusyReinitializeMessage' } else { Get-LocalizedString -Key 'Maintenance.Panel.BusySetupMessage' }
                $action.Visible = $false
                $action.Enabled = $false
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.BusyHint'
            }
        }
    }

    if ($script:RefreshButton -and -not $script:RefreshButton.IsDisposed) {
        $script:RefreshButton.Enabled = ($ready -and -not $busy)
        $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    }
    if ($script:ManageEntriesButton -and -not $script:ManageEntriesButton.IsDisposed) {
        $script:ManageEntriesButton.Enabled = ($ready -and -not $busy)
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = ($ready -and -not $busy) }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = -not $busy }

    Update-HeaderRefreshStatus
}

function Show-MaintenanceSuccessDialog {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    if ($Mode -eq 'Remove') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessRemovedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessRemovedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessRemovedMessage') -Kind Info
        return
    }
    if ($Mode -eq 'Reinitialize') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedMessage') -Kind Info
        return
    }
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReadyTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReadyHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReadyMessage') -Kind Info
}


function Get-NextBootTargetDisplayName {
    if ($script:SelectedGuid) {
        $selectedEntry = Get-EntryByGuid $script:SelectedGuid
        if ($selectedEntry) { return [string](Get-EntryDisplayTitle -Entry $selectedEntry) }
    }
    return (Get-LocalizedString -Key 'Boot.DefaultOrder')
}

function Update-RestartTargetUi {
    if ($script:RestartTargetLabel -and -not $script:RestartTargetLabel.IsDisposed) {
        $script:RestartTargetLabel.Text = Get-LocalizedString -Key 'Status.NextTargetLabel' -Values @{ Title=(Get-NextBootTargetDisplayName) }
    }
}

function Restart-Windows {
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    $targetName = Get-NextBootTargetDisplayName
    $choice = Show-LenovoRestartDialog -TargetName $targetName
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $true -Data (New-RuntimeDiagnosticData @{ confirmed = $false; targetGuid = $script:SelectedGuid })
        return
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Join-Path $env:SystemRoot 'System32\shutdown.exe')
        $psi.Arguments = '/r /t 0'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($psi)
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ confirmed = $true; targetGuid = $script:SelectedGuid })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ confirmed = $true; targetGuid = $script:SelectedGuid }) -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.FailedHeading') -Message (Get-LocalizedString -Key 'Restart.FailedMessage') -Kind Error
    }
}

function Normalize-TaskBrokerGuid {
    param([AllowNull()][string]$Guid)
    if ([string]::IsNullOrWhiteSpace($Guid)) { return $null }
    $candidate = $Guid.Trim().ToLowerInvariant()
    if ($candidate -notmatch '^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$') { return $null }
    return $candidate
}

function Get-TaskBrokerExpectedTargetTaskName {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [switch]$DefaultTarget
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { return $null }
    $compact = $normalized.Trim('{}').Replace('-','')
    if ($DefaultTarget) { return ('LenovoBootSelector-Default-Set-' + $compact) }
    return ('LenovoBootSelector-Set-' + $compact)
}

function Test-TaskBrokerMetadataContract {
    param([Parameter(Mandatory=$true)]$Metadata)
    try {
        if ($script:SupportedTaskBrokerVersions -notcontains [string]$Metadata.version) { return $false }
        if ([string]$Metadata.boundaryContract -ne 'fixed-task-v2') { return $false }
        if ([string]$Metadata.managerRefreshTask -ne 'LenovoBootSelector-RefreshManager') { return $false }
        if ([string]$Metadata.firmwareRefreshTask -ne 'LenovoBootSelector-RefreshFirmware') { return $false }
        if ([string]$Metadata.defaultClearTask -ne 'LenovoBootSelector-Default-Clear') { return $false }
        if ([string]$Metadata.defaultRestoreTask -ne 'LenovoBootSelector-Default-Restore') { return $false }

        $expectedManagerFile = Join-Path $script:TaskBrokerStateDir 'fwbootmgr.txt'
        $expectedFirmwareFile = Join-Path $script:TaskBrokerStateDir 'firmware.txt'
        $expectedDefaultFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'default-guid.txt'
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.managerFile),[System.IO.Path]::GetFullPath($expectedManagerFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.firmwareFile),[System.IO.Path]::GetFullPath($expectedFirmwareFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.defaultFile),[System.IO.Path]::GetFullPath($expectedDefaultFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }

        $targets = @($Metadata.targets)
        if ($targets.Count -lt 1) { return $false }
        $seenGuids = @{}
        $seenTaskNames = @{}
        foreach ($target in $targets) {
            $normalized = Normalize-TaskBrokerGuid -Guid ([string]$target.guid)
            if (-not $normalized -or [string]$target.guid -ne $normalized) { return $false }
            $expectedBoot = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            $expectedDefault = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
            if ([string]$target.taskName -ne $expectedBoot) { return $false }
            if ([string]$target.defaultTaskName -ne $expectedDefault) { return $false }
            if ($seenGuids.ContainsKey($normalized)) { return $false }
            $bootKey = $expectedBoot.ToLowerInvariant()
            $defaultKey = $expectedDefault.ToLowerInvariant()
            if ($seenTaskNames.ContainsKey($bootKey) -or $seenTaskNames.ContainsKey($defaultKey)) { return $false }
            $seenGuids[$normalized] = $true
            $seenTaskNames[$bootKey] = $true
            $seenTaskNames[$defaultKey] = $true
        }
        return $true
    }
    catch { return $false }
}


function Get-TaskBrokerMetadata {
    if ($script:TaskBrokerMetadata) {
        if (Test-TaskBrokerMetadataContract -Metadata $script:TaskBrokerMetadata) { return $script:TaskBrokerMetadata }
        $script:TaskBrokerMetadata = $null
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerMetadataPath)) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText($script:TaskBrokerMetadataPath, [System.Text.Encoding]::UTF8)
        $meta = $text | ConvertFrom-Json
        if (-not (Test-TaskBrokerMetadataContract -Metadata $meta)) { return $null }
        $script:TaskBrokerMetadata = $meta
        return $meta
    }
    catch { return $null }
}

function Get-TaskBrokerTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return $null }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { return $null }
    foreach ($target in @($meta.targets)) {
        if ([string]$target.guid -eq $normalized) { return $target }
    }
    return $null
}
function Resolve-TaskBrokerAuthorizedTaskName {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]
        [string]$Operation,
        [AllowNull()][string]$Guid
    )

    if (-not (Test-TaskBrokerMetadataCompatible)) {
        throw 'Die TaskBroker-Metadaten erfüllen den festen Privilege-Boundary-Vertrag nicht.'
    }

    switch ($Operation) {
        'ManagerRefresh' { return 'LenovoBootSelector-RefreshManager' }
        'FirmwareRefresh' { return 'LenovoBootSelector-RefreshFirmware' }
        'DefaultClear' { return 'LenovoBootSelector-Default-Clear' }
        'BootNext' {
            $normalized = Normalize-TaskBrokerGuid -Guid $Guid
            if (-not $normalized) { throw 'Ungültiges BootNext-Ziel.' }
            $target = Get-TaskBrokerTarget -Guid $normalized
            if (-not $target) { throw 'Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden.' }
            $expected = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            if ([string]$target.taskName -ne $expected) { throw 'BootNext-Aufgabenname verletzt den festen TaskBroker-Vertrag.' }
            return $expected
        }
        'DefaultSet' {
            $normalized = Normalize-TaskBrokerGuid -Guid $Guid
            if (-not $normalized) { throw 'Ungültiges Standardziel.' }
            $target = Get-TaskBrokerTarget -Guid $normalized
            if (-not $target) { throw 'Für dieses Firmware-Ziel ist keine autorisierte Standardziel-Aufgabe vorhanden.' }
            $expected = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
            if ([string]$target.defaultTaskName -ne $expected) { throw 'Standardziel-Aufgabenname verletzt den festen TaskBroker-Vertrag.' }
            return $expected
        }
    }
    throw 'Nicht unterstützte TaskBroker-Operation.'
}


function Invoke-AuthorizedTask {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]
        [string]$Operation,
        [AllowNull()][string]$Guid,
        [int]$TimeoutMs = $script:TaskBrokerTimeoutMs
    )

    $started = [datetime]::Now
    $diagSw = [System.Diagnostics.Stopwatch]::StartNew()
    $taskName = ''
    $normalizedGuid = Normalize-TaskBrokerGuid -Guid $Guid
    try {
        $taskName = Resolve-TaskBrokerAuthorizedTaskName -Operation $Operation -Guid $normalizedGuid

        # IMPORTANT: exact-task access is retained; root enumeration is deliberately avoided.
        try {
            $scheduleService = New-Object -ComObject 'Schedule.Service'
            $scheduleService.Connect()
            $taskFolder = $scheduleService.GetFolder('\')
            $registeredTask = $taskFolder.GetTask("\$taskName")
            if (-not $registeredTask) { throw 'Aufgabe nicht gefunden.' }
        }
        catch {
            throw "Die autorisierte Windows-Aufgabe '$taskName' ist für den aktuellen Benutzer nicht lesbar: $($_.Exception.Message)"
        }

        try { Start-ScheduledTask -TaskName $taskName -ErrorAction Stop }
        catch { throw "Die autorisierte Windows-Aufgabe '$taskName' konnte nicht gestartet werden: $($_.Exception.Message)" }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds 75
            try {
                $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
                $registeredTask = $taskFolder.GetTask("\$taskName")
                $state = [int]$registeredTask.State
            }
            catch {
                throw "Der Status der autorisierten Windows-Aufgabe '$taskName' konnte nicht gelesen werden: $($_.Exception.Message)"
            }

            $recent = ($info.LastRunTime -ge $started.AddSeconds(-2))
            $result = [uint32]$info.LastTaskResult
            $isTransientResult = ($result -eq 0x00041301 -or $result -eq 0x00041325)
            if ($recent -and ($state -eq 4 -or $isTransientResult)) { continue }

            if ($recent -and $state -ne 4) {
                if ($result -ne 0) {
                    throw ("Die autorisierte Windows-Aufgabe '{0}' ist mit 0x{1:X8} ({2}) fehlgeschlagen." -f $taskName,$result,$result)
                }
                $diagSw.Stop()
                Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $true -DurationMs $diagSw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ operation = $Operation; taskName = $taskName; targetGuid = $normalizedGuid; lastTaskResult = [uint32]$result; state = $state })
                return $info
            }
        } while ($sw.ElapsedMilliseconds -lt $TimeoutMs)

        throw "Zeitüberschreitung beim Warten auf die autorisierte Windows-Aufgabe '$taskName'."
    }
    catch {
        $diagSw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $false -DurationMs $diagSw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $Operation; taskName = $taskName; targetGuid = $normalizedGuid; timeoutMs = $TimeoutMs }) -Level error
        throw
    }
}
function Read-TaskBrokerTextFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Statusdatei fehlt: $Path"
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Refresh-ManagerCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:ManagerCacheText -and (([datetime]::UtcNow - $script:ManagerCacheUtc).TotalMilliseconds -lt 750)) {
        return $script:ManagerCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -Operation 'ManagerRefresh' | Out-Null
        $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
        $script:ManagerCacheUtc = [datetime]::UtcNow
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:ManagerCacheText.Length })
        return $script:ManagerCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}

function Refresh-FirmwareCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:FirmwareCacheText -and (([datetime]::UtcNow - $script:FirmwareCacheUtc).TotalSeconds -lt 30)) {
        return $script:FirmwareCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -Operation 'FirmwareRefresh' | Out-Null
        $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
        $script:FirmwareCacheUtc = [datetime]::UtcNow
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:FirmwareCacheText.Length })
        return $script:FirmwareCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}


function Test-TaskBrokerMetadataCompatible {
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { return $false }
        if (-not (Test-TaskBrokerMetadataContract -Metadata $meta)) { return $false }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { return $false }
        return $true
    }
    catch { return $false }
}
function Get-TaskBrokerInteractiveReady {
    if ($null -ne $script:TaskBrokerReadyCached) { return [bool]$script:TaskBrokerReadyCached }
    return (Test-TaskBrokerMetadataCompatible)
}

function Reset-TaskBrokerReadyCache {
    $script:TaskBrokerReadyCached = $null
    $script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
}


function Test-TaskBrokerReady {
    param([switch]$Force)

    if (-not $Force -and $null -ne $script:TaskBrokerReadyCached) {
        return [bool]$script:TaskBrokerReadyCached
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    $failure = $null
    $requiredCount = 0
    $failedTask = $null
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta -or -not (Test-TaskBrokerMetadataContract -Metadata $meta)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { throw 'TaskBroker ist nicht für den aktuellen Benutzer autorisiert.' }

        $required = @(
            'LenovoBootSelector-RefreshManager',
            'LenovoBootSelector-RefreshFirmware',
            'LenovoBootSelector-Default-Clear',
            'LenovoBootSelector-Default-Restore'
        )
        foreach ($target in @($meta.targets)) {
            $normalized = Normalize-TaskBrokerGuid -Guid ([string]$target.guid)
            if (-not $normalized) { throw 'TaskBroker-Zielmetadaten enthalten eine ungültige GUID.' }
            $required += Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            $required += Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
        }
        $required = @($required | Select-Object -Unique)
        $requiredCount = $required.Count
        foreach ($name in $required) {
            if (-not $name) { throw 'Taskname fehlt.' }
            $failedTask = $name
            [void](Get-ScheduledTaskInfo -TaskName $name -ErrorAction Stop)
        }
        $failedTask = $null
        $ready = $true
    }
    catch {
        $failure = $_
        $ready = $false
    }

    $sw.Stop()
    Write-RuntimeDiagnosticEvent -Event 'TASKBROKER_READY_CHECK' -Stage 'ready' -Success $ready -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $failure -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; requiredTaskCount = $requiredCount; failedTask = $failedTask; brokerPresent = [bool](Test-TaskBrokerInstallationPresent) }) -Level $(if ($ready) { 'info' } else { 'error' })
    $script:TaskBrokerReadyCached = $ready
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    return $ready
}
function Test-TaskBrokerInstallationPresent {
    if (Test-Path -LiteralPath $script:TaskBrokerMetadataPath) { return $true }
    if ($script:LegacyTaskBrokerMetadataPath -and (Test-Path -LiteralPath $script:LegacyTaskBrokerMetadataPath)) { return $true }
    return $false
}

function Get-LatestTaskBrokerDiagnosticPath {
    $diagPointer = Join-Path $script:TaskBrokerLocalDir 'latest-install-diagnostic.txt'
    if (Test-Path -LiteralPath $diagPointer) {
        try { return ([System.IO.File]::ReadAllText($diagPointer)).Trim() } catch { }
    }
    return ''
}

function Get-TaskBrokerFirmwareManagerText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:ManagerCacheText) {
            $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
            try { $script:ManagerCacheUtc = (Get-Item -LiteralPath ([string]$meta.managerFile)).LastWriteTimeUtc } catch { }
        }
        return $script:ManagerCacheText
    }

    return (Refresh-ManagerCache -Force:$Force)
}

function Get-TaskBrokerFirmwareEntriesText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:FirmwareCacheText) {
            $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
            try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc } catch { }
        }
        return $script:FirmwareCacheText
    }

    return (Refresh-FirmwareCache -Force:$Force)
}

function Sync-TaskBrokerFirmwareCachesFromFiles {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'TaskBroker-Metadaten fehlen nach dem Hintergrund-Refresh.' }

    $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
    $script:ManagerCacheUtc = [datetime]::UtcNow
    $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
    try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc }
    catch { $script:FirmwareCacheUtc = [datetime]::UtcNow }

    [pscustomobject]@{
        ManagerText = $script:ManagerCacheText
        FirmwareText = $script:FirmwareCacheText
    }
}

function Get-TaskBrokerDefaultTargetGuid {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not [string]$meta.defaultFile) { return $null }

    $path = [string]$meta.defaultFile
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    $candidate = ([System.IO.File]::ReadAllText($path)).Trim().ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $candidate
    if ($target) { return $candidate }
    return $null
}


function Set-TaskBrokerBootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Firmware-Ziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw "Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden: $normalized"
    }

    Invoke-AuthorizedTask -Operation 'BootNext' -Guid $normalized | Out-Null
    return (Get-TaskBrokerFirmwareManagerText -Force)
}

function Set-TaskBrokerDefaultTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Standardziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'Für dieses Firmwareziel existiert keine autorisierte Standardziel-Aufgabe.'
    }

    Invoke-AuthorizedTask -Operation 'DefaultSet' -Guid $normalized | Out-Null
}

function Clear-TaskBrokerDefaultTarget {
    if (-not (Test-TaskBrokerMetadataCompatible)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
    Invoke-AuthorizedTask -Operation 'DefaultClear' | Out-Null
}


function Test-BootTargetDriftDetected {
    return (Test-BootTargetDriftRuntimeDetected -State $script:BootTargetDriftState)
}

function Test-BootTargetDriftHasNewTargets {
    return (Test-BootTargetDriftRuntimeHasNewTargets -State $script:BootTargetDriftState)
}

function Update-BootTargetDriftState {
    if (Test-MaintenanceBusy) { return $false }
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) {
        [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)
        return $false
    }

    try {
        $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache
        $firmwareText = Get-TaskBrokerFirmwareEntriesText -UseExistingCache
        $manager = ConvertFrom-FirmwareManagerText -Text $managerText
        $descriptions = ConvertFrom-FirmwareEntriesText -Text $firmwareText
        $drift = Compare-BootTargetDriftCore -InstalledTargets @($meta.targets) -Descriptions $descriptions -DisplayOrder @($manager.DisplayOrder)
        [void](Set-BootTargetDriftRuntimeState -State $script:BootTargetDriftState -Drift $drift)
        Write-RuntimeDiagnosticEvent -Event 'BOOT_TARGET_DRIFT_CHECK' -Stage 'drift' -Success $true -Data (New-RuntimeDiagnosticData @{
            hasDrift = [bool]$drift.HasDrift
            hasNewTargets = [bool]$drift.HasNewTargets
            addedCount = @($drift.AddedGuids).Count
            removedCount = @($drift.RemovedGuids).Count
            addedGuids = @($drift.AddedGuids)
            removedGuids = @($drift.RemovedGuids)
        }) -Level $(if ($drift.HasDrift) { 'warning' } else { 'info' })
        return [bool]$drift.HasDrift
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOT_TARGET_DRIFT_CHECK' -Stage 'drift' -Success $false -ErrorRecord $_ -Level warning
        return $false
    }
}

function Show-BootTargetDriftNotificationIfNeeded {
    if (-not (Test-BootTargetDriftDetected)) { return }
    if ($script:BootTargetDriftState.NotificationShown) { return }
    [void](Set-BootTargetDriftNotificationShown -State $script:BootTargetDriftState)
    if (-not $script:Popup -or $script:Popup.IsDisposed) { $script:Popup = New-PopupForm }
    Update-MaintenanceUi
    Update-PopupRows
    if (-not $script:Popup.Visible) {
        Position-Popup
        $script:Popup.Show()
        $script:Popup.Activate()
    }
}


function Update-TaskBrokerUiState {
    param([switch]$Fast)
    $busy = Test-MaintenanceBusy
    $ready = if ($busy) {
        $false
    }
    elseif ($Fast) {
        if ($null -ne $script:TaskBrokerReadyCached) { [bool]$script:TaskBrokerReadyCached } else { $false }
    }
    else {
        Test-TaskBrokerReady
    }
    $present = Test-TaskBrokerInstallationPresent
    $drift = [bool]($ready -and (Test-BootTargetDriftDetected))
    $interactiveReady = [bool]($ready -and -not $drift)

    if ($script:TaskBrokerSetupMenuItem) {
        $script:TaskBrokerSetupMenuItem.Enabled = -not $busy
        if ($busy) {
            $mode = Get-MaintenanceMode
            $script:TaskBrokerSetupMenuItem.Text = if ($mode -eq 'Remove') { Get-LocalizedString -Key 'Maintenance.Menu.Generic' } elseif ($mode -eq 'Reinitialize') { Get-LocalizedString -Key 'Maintenance.Menu.Reinitializing' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { Get-LocalizedString -Key 'Maintenance.Menu.Repairing' } else { Get-LocalizedString -Key 'Maintenance.Menu.SettingUp' }
        }
        elseif ($drift) {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Reinitialize'
        }
        elseif ($ready -or $present) {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Repair'
        }
        else {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Setup'
        }
    }

    if ($script:TaskBrokerRemoveMenuItem) {
        # Cleanup is intentionally available even when metadata is already gone;
        # it also knows historical/probe task names from pre-TaskBroker builds.
        $script:TaskBrokerRemoveMenuItem.Enabled = -not $busy
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = ($interactiveReady -and -not $busy) }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = (-not $busy -and -not $drift) }
    Update-MaintenanceUi
    return $interactiveReady
}

function Enter-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    [void](Set-MaintenanceRuntimeActive -State $script:MaintenanceState -Mode $Mode)
    $script:IsManageEntriesMode = $false
    $script:ManageAliasEditGuid = $null
    Stop-BackgroundBootRefreshForMaintenance -Reason $Mode
    $script:LastStatusText = Get-MaintenanceBusyStatusText
    Update-PopupRows
    Update-TaskBrokerUiState -Fast | Out-Null
    Write-RuntimeDiagnosticEvent -Event 'MAINTENANCE_UI_STATE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ state = 'busy'; mode = $Mode })
}

function Exit-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][string]$Reason)
    $mode = Get-MaintenanceMode
    [void](Clear-MaintenanceRuntimeState -State $script:MaintenanceState)
    Write-RuntimeDiagnosticEvent -Event 'MAINTENANCE_UI_STATE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ state = 'idle'; mode = $mode; reason = $Reason })
    Update-TaskBrokerUiState -Fast | Out-Null
    Update-PopupRows
}

function Complete-TaskBrokerInstall {
    param([int]$ExitCode)
    $diagStarted = $script:TaskBrokerInstallDiagnosticStartedUtc
    $completedMode = Get-MaintenanceMode
    if (-not $completedMode) { $completedMode = 'Setup' }

    $script:TaskBrokerInstallInProgress = $false
    if ($script:TaskBrokerInstallTimer) {
        try { $script:TaskBrokerInstallTimer.Stop() } catch { }
        try { $script:TaskBrokerInstallTimer.Dispose() } catch { }
        $script:TaskBrokerInstallTimer = $null
    }
    $script:TaskBrokerInstallProcess = $null
    $script:TaskBrokerMetadata = $null
    Reset-TaskBrokerReadyCache
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)

    $setupSuccess = ($ExitCode -eq 0 -and (Test-TaskBrokerReady))
    if ($setupSuccess) {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsInstalled'
        try {
            Refresh-BootState -RefreshStorage
            [void](Refresh-SystemDefaultState)
            Complete-LegacyDefaultMigration
        } catch {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SetupCompleteRefreshing'
        }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsNotInstalled'
    }

    $durationMs = $null
    if ($diagStarted) { $durationMs = [int64](([datetime]::UtcNow - $diagStarted).TotalMilliseconds) }
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_COMPLETED' -Stage 'maintenance' -Success $setupSuccess -DurationMs $durationMs -Data (New-RuntimeDiagnosticData @{ exitCode = $ExitCode; mode = $completedMode; installerDiagnostic = [System.IO.Path]::GetFileName((Get-LatestTaskBrokerDiagnosticPath)) }) -Level $(if ($setupSuccess) { 'info' } else { 'error' })

    Exit-SystemFunctionsMaintenance -Reason $(if ($setupSuccess) { 'completed' } else { 'failed' })
    Update-DefaultUi
    if ($setupSuccess) {
        Show-MaintenanceSuccessDialog -Mode $completedMode
    }
    else {
        # Technical details remain in the installer diagnostic; the UI stays user-facing.
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SetupIncompleteTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SetupIncompleteHeading') -Message (Get-LocalizedString -Key 'Maintenance.SetupIncompleteMessage') -Kind Error
    }
}

function Start-TaskBrokerInstall {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize')][string]$Mode = 'Setup')
    if ($script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerInstallDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_STARTED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ mode = $Mode })
    if (-not (Test-Path -LiteralPath $script:TaskBrokerInstallScript)) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.FileMissingTitle') -Heading (Get-LocalizedString -Key 'Maintenance.FileMissingHeading') -Message (Get-LocalizedString -Key 'Maintenance.FileMissingMessage') -Kind Error
        return
    }

    $legacyAutostart = (Get-LegacyAutostartInfo).Enabled
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }

    Enter-SystemFunctionsMaintenance -Mode $Mode

    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $legacyDefaultArg = if ($script:LegacyDefaultGuid) { [string]$script:LegacyDefaultGuid } else { '' }
    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $script:TaskBrokerInstallScript),
        '-StateDir', ('"{0}"' -f $script:TaskBrokerStateDir),
        '-UserStateDir', ('"{0}"' -f $script:TaskBrokerLocalDir),
        '-UserSid', ('"{0}"' -f $sid),
        '-LegacyDefaultGuid', ('"{0}"' -f $legacyDefaultArg)
    )

    try {
        $proc = Start-Process -FilePath $ps -ArgumentList ($args -join ' ') -Verb RunAs -WindowStyle Hidden -PassThru
    }
    catch {
        $cancelled = ($_.Exception.Message -match 'canceled|cancelled|abgebrochen|1223')
        $script:LastStatusText = if ($cancelled) { Get-LocalizedString -Key 'Maintenance.SetupCancelledStatus' } else { Get-LocalizedString -Key 'Maintenance.SetupStartFailedStatus' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode = $Mode }) -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SetupNotStartedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.ConfirmationFailedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
        }
        return
    }

    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_LAUNCH' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $proc.Id; mode = $Mode })
    $script:TaskBrokerInstallProcess = $proc
    $script:TaskBrokerInstallInProgress = $true
    Update-MaintenanceUi
    Update-TaskBrokerUiState -Fast | Out-Null

    if ($legacyAutostart) { try { Set-AutostartEnabled -Enabled:$true } catch { } }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        try {
            if (-not $script:TaskBrokerInstallProcess) { return }
            $script:TaskBrokerInstallProcess.Refresh()
            if ($script:TaskBrokerInstallProcess.HasExited) {
                $code = $script:TaskBrokerInstallProcess.ExitCode
                Complete-TaskBrokerInstall -ExitCode $code
            }
        }
        catch {
            Complete-TaskBrokerInstall -ExitCode 1
        }
    })
    $script:TaskBrokerInstallTimer = $timer
    $timer.Start()
}

function Prompt-TaskBrokerInstall {
    if (Test-MaintenanceBusy) { return }
    $mode = if (Test-BootTargetDriftDetected) { 'Reinitialize' } elseif (Test-TaskBrokerReady) { 'Repair' } elseif (Test-TaskBrokerInstallationPresent) { 'Migrate' } else { 'Setup' }
    $choice = Show-LenovoSystemFunctionsDialog -Mode $mode
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode $mode }
}

function Prompt-TaskBrokerReinitialize {
    if (Test-MaintenanceBusy -or -not (Test-BootTargetDriftDetected)) { return }
    $choice = Show-LenovoSystemFunctionsDialog -Mode 'Reinitialize'
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode 'Reinitialize' }
}

function Complete-TaskBrokerRemove {
    param([int]$ExitCode)
    $diagStarted = $script:TaskBrokerRemoveDiagnosticStartedUtc

    $script:TaskBrokerRemoveInProgress = $false
    if ($script:TaskBrokerRemoveTimer) {
        try { $script:TaskBrokerRemoveTimer.Stop() } catch { }
        try { $script:TaskBrokerRemoveTimer.Dispose() } catch { }
        $script:TaskBrokerRemoveTimer = $null
    }
    $script:TaskBrokerRemoveProcess = $null
    $script:TaskBrokerMetadata = $null
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    $script:DefaultGuid = $null
    $script:IsManageEntriesMode = $false
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)

    $removeSuccess = ($ExitCode -eq 0 -and -not (Test-TaskBrokerInstallationPresent))
    if ($removeSuccess) {
        $script:TaskBrokerReadyCached = $false
        $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
        $script:CurrentEntries = @()
        $script:SelectedGuid = $null
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRemoved'
    }
    else {
        Reset-TaskBrokerReadyCache
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRemoveIncomplete'
    }

    $durationMs = $null
    if ($diagStarted) { $durationMs = [int64](([datetime]::UtcNow - $diagStarted).TotalMilliseconds) }
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_COMPLETED' -Stage 'maintenance' -Success $removeSuccess -DurationMs $durationMs -Data (New-RuntimeDiagnosticData @{ exitCode = $ExitCode }) -Level $(if ($removeSuccess) { 'info' } else { 'error' })

    Exit-SystemFunctionsMaintenance -Reason $(if ($removeSuccess) { 'completed' } else { 'failed' })
    Update-ManageEntriesUiState
    Update-DefaultUi
    if ($removeSuccess) {
        Show-MaintenanceSuccessDialog -Mode 'Remove'
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteTitle') -Heading (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteHeading') -Message (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteMessage') -Kind Error
    }
}

function Start-TaskBrokerRemove {
    if ($script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerRemoveDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_STARTED' -Stage 'maintenance' -Success $true
    if (-not (Test-Path -LiteralPath $script:TaskBrokerUninstallScript)) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveNotPossibleTitle') -Heading (Get-LocalizedString -Key 'Maintenance.FileMissingHeading') -Message (Get-LocalizedString -Key 'Maintenance.FileMissingMessage') -Kind Error
        return
    }

    Enter-SystemFunctionsMaintenance -Mode 'Remove'

    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"{0}"' -f $script:TaskBrokerUninstallScript))
    try {
        $proc = Start-Process -FilePath $ps -ArgumentList ($args -join ' ') -Verb RunAs -WindowStyle Hidden -PassThru
    }
    catch {
        $cancelled = ($_.Exception.Message -match 'canceled|cancelled|abgebrochen|1223')
        $script:LastStatusText = if ($cancelled) { Get-LocalizedString -Key 'Maintenance.RemoveCancelledStatus' } else { Get-LocalizedString -Key 'Maintenance.RemoveFailedStatus' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveNotStartedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.ConfirmationFailedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
        }
        return
    }

    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_LAUNCH' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $proc.Id })
    $script:TaskBrokerRemoveProcess = $proc
    $script:TaskBrokerRemoveInProgress = $true
    Update-MaintenanceUi
    Update-TaskBrokerUiState -Fast | Out-Null

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        try {
            if (-not $script:TaskBrokerRemoveProcess) { return }
            $script:TaskBrokerRemoveProcess.Refresh()
            if ($script:TaskBrokerRemoveProcess.HasExited) {
                $code = $script:TaskBrokerRemoveProcess.ExitCode
                Complete-TaskBrokerRemove -ExitCode $code
            }
        }
        catch { Complete-TaskBrokerRemove -ExitCode 1 }
    })
    $script:TaskBrokerRemoveTimer = $timer
    $timer.Start()
}

function Prompt-TaskBrokerRemove {
    if (Test-MaintenanceBusy) { return }
    $choice = Show-LenovoSystemFunctionsDialog -Mode 'Remove'
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerRemove }
}

# Lenovo Boot Selector - pure storage-resolution model.
# No Windows storage cmdlets or hardware IO belong in this module.

function Resolve-PartitionBootStructureCore {
    param(
        [Parameter(Mandatory=$true)]$Disk,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Partitions
    )

    $hasEfiSystemPartition = $false
    $hasActiveFatPartition = $false

    foreach ($partition in @($Partitions)) {
        $gptType = ([string]$partition.GptType).Trim().Trim([char[]]'{}').ToLowerInvariant()
        if ($gptType -eq 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b') {
            $hasEfiSystemPartition = $true
        }

        if (([string]$Disk.PartitionStyle -eq 'MBR') -and ($partition.IsActive -eq $true)) {
            $partitionType = [string]$partition.Type
            $mbrType = [string]$partition.MbrType
            if (($partitionType -match '(?i)FAT32') -or ($mbrType -eq '11') -or ($mbrType -eq '12')) {
                $hasActiveFatPartition = $true
            }
        }
    }

    return [pscustomobject]@{
        HasEfiSystemPartition = $hasEfiSystemPartition
        HasActiveFatPartition = $hasActiveFatPartition
        HasBootStructure = ($hasEfiSystemPartition -or $hasActiveFatPartition)
    }
}

function Resolve-StorageContextCore {
    param($Snapshot)

    if (-not $Snapshot -or $Snapshot.Available -ne $true) {
        return [pscustomobject]@{
            Disks = @()
            UsbDisks = @()
            UsbBootCandidates = @()
            ResolvedUsbHdd = $null
            UsbResolution = 'Unavailable'
            UsbResolutionReason = 'Speichergeräte konnten nicht gelesen werden.'
        }
    }

    $inventory = @()
    foreach ($disk in @($Snapshot.Disks)) {
        $partitions = @($disk.Partitions)
        $bootStructure = Resolve-PartitionBootStructureCore -Disk $disk -Partitions $partitions

        $model = ([string]$disk.Model).Trim()
        if (-not $model) { $model = "Datenträger $($disk.Number)" }

        $inventory += [pscustomobject]@{
            Number = $disk.Number
            Model = $model
            SerialNumber = ([string]$disk.SerialNumber).Trim()
            BusType = [string]$disk.BusType
            PartitionStyle = [string]$disk.PartitionStyle
            Path = [string]$disk.Path
            IsBootCandidate = [bool]$bootStructure.HasBootStructure
            HasEfiSystemPartition = [bool]$bootStructure.HasEfiSystemPartition
            HasActiveFatPartition = [bool]$bootStructure.HasActiveFatPartition
            PnpInstanceId = $null
            PnpParent = $null
            PnpLocationPaths = @()
        }
    }

    $usbDisks = @($inventory | Where-Object { $_.BusType -eq 'USB' })
    $usbBootCandidates = @($usbDisks | Where-Object { $_.IsBootCandidate })
    $resolvedUsbHdd = $null
    $resolution = 'Ambiguous'
    $reason = 'Mehrere mögliche USB-Laufwerke erkannt.'

    if ($usbBootCandidates.Count -eq 1) {
        $resolvedUsbHdd = $usbBootCandidates[0]
        $resolution = 'Candidate'
        $reason = 'Genau ein aktuelles USB-Laufwerk besitzt eine erkannte Bootstruktur. Der Lenovo-Eintrag USB HDD ist jedoch generisch; die physische Zuordnung wird erst durch den Boottest bestätigt.'
    }
    elseif ($usbBootCandidates.Count -gt 1) {
        $resolution = 'Ambiguous'
        $reason = "$($usbBootCandidates.Count) USB-Laufwerke besitzen eine erkannte Bootstruktur."
    }
    elseif ($usbDisks.Count -eq 1) {
        $resolvedUsbHdd = $usbDisks[0]
        $resolution = 'Medium'
        $reason = 'Nur ein aktuelles USB-Laufwerk ist angeschlossen; eine Bootstruktur konnte jedoch nicht bestätigt werden.'
    }
    elseif ($usbDisks.Count -eq 0) {
        $resolution = 'None'
        $reason = 'Kein aktuelles USB-Speicherlaufwerk erkannt.'
    }

    return [pscustomobject]@{
        Disks = @($inventory)
        UsbDisks = @($usbDisks)
        UsbBootCandidates = @($usbBootCandidates)
        ResolvedUsbHdd = $resolvedUsbHdd
        UsbResolution = $resolution
        UsbResolutionReason = $reason
    }
}

# Windows-specific storage acquisition and normalization.
# Classification and product-facing storage resolution live in Core/StorageResolution.ps1.

function ConvertTo-WindowsStorageDiskSnapshot {
    param(
        [Parameter(Mandatory=$true)]$Disk,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Partitions
    )

    $normalizedPartitions = @(
        foreach ($partition in @($Partitions)) {
            [pscustomobject]@{
                GptType = [string]$partition.GptType
                IsActive = [bool]$partition.IsActive
                Type = [string]$partition.Type
                MbrType = [string]$partition.MbrType
            }
        }
    )

    return [pscustomobject]@{
        Number = $Disk.Number
        Model = ([string]$Disk.FriendlyName).Trim()
        SerialNumber = ([string]$Disk.SerialNumber).Trim()
        BusType = [string]$Disk.BusType
        PartitionStyle = [string]$Disk.PartitionStyle
        Path = [string]$Disk.Path
        Partitions = @($normalizedPartitions)
    }
}

function Get-WindowsStorageSnapshot {
    # Performance-critical Windows IO path. PnP enrichment remains intentionally
    # excluded from interactive refresh; only Get-Disk/Get-Partition are queried.
    try {
        $disks = @(Get-Disk -ErrorAction Stop)
    }
    catch {
        return [pscustomobject]@{
            Available = $false
            Disks = @()
        }
    }

    $inventory = @()
    foreach ($disk in $disks) {
        $partitions = @()
        try {
            $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction Stop)
        }
        catch { }

        $inventory += ConvertTo-WindowsStorageDiskSnapshot -Disk $disk -Partitions $partitions
    }

    return [pscustomobject]@{
        Available = $true
        Disks = @($inventory)
    }
}

function Get-StorageContext {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $snapshot = Get-WindowsStorageSnapshot
        $result = Resolve-StorageContextCore -Snapshot $snapshot
        $sw.Stop()
        $storageSuccess = ([string]$result.UsbResolution -ne 'Unavailable')
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $storageSuccess -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            diskCount = @($result.Disks).Count
            usbDiskCount = @($result.UsbDisks).Count
            usbBootCandidateCount = @($result.UsbBootCandidates).Count
            resolution = [string]$result.UsbResolution
        }) -Level $(if ($storageSuccess) { 'info' } else { 'warning' })
        return $result
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Level error
        throw
    }
}


# Lenovo Boot Selector v0.4.1 - Functional Core: friendly boot-target model
# Presentation-neutral: returns an AccentRole token instead of a UI-specific color object.

function Get-FriendlyBootEntryCore {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext,
        [string]$Locale = 'en-US'
    )

    $localeId = Resolve-LocaleIdCore -Locale $Locale
    $description = if ($RawDescription) { $RawDescription.Trim() } else { Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId }
    $title = $description
    $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId
    $accentRole = 'Secondary'
    $symbol = '●'
    $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherTargetTooltip' -Locale $localeId

    # The current target ThinkPad has NVMe0 confirmed as the populated internal slot.
    # A single read-only NVMe disk can therefore enrich NVMe0 and implies an empty NVMe1.
    # Do not guess NVMe0/NVMe1 physical mapping when multiple NVMe disks are present.
    $nvmeDisks = @()
    if ($StorageContext -and $null -ne $StorageContext.Disks) {
        $nvmeDisks = @($StorageContext.Disks | Where-Object { [string]$_.BusType -eq 'NVMe' })
    }

    switch -Regex ($description) {
        '^Boot Menu$' {
            $title = Get-LocalizedStringCore -Key 'Boot.MenuTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.MenuSubtitle' -Locale $localeId
            $accentRole = 'Accent'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.MenuTooltip' -Locale $localeId
            break
        }
        '^NVMe0$' {
            $title = Get-LocalizedStringCore -Key 'Boot.Nvme1Title' -Locale $localeId
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale $localeId -Values @{ Model=[string]$nvmeDisks[0].Model }
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.InternalSsd' -Locale $localeId
            }
            $accentRole = 'Blue'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.InternalSsdTooltip' -Locale $localeId
            break
        }
        '^NVMe1$' {
            $title = Get-LocalizedStringCore -Key 'Boot.Nvme2Title' -Locale $localeId
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.SecondInternalSsd' -Locale $localeId
            }
            $accentRole = 'Blue'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.InternalSsdTooltip' -Locale $localeId
            break
        }
        '^USB HDD$' {
            # USB HDD is the actual firmware target. Physical storage identity is
            # presented only as read-only context and must never replace the target title.
            $title = 'USB HDD'
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId

            if (-not $StorageContext) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbChecking' -Locale $localeId
            }
            elseif ($StorageContext.UsbResolution -eq 'Unavailable') {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCheckFailed' -Locale $localeId
            }
            elseif ($StorageContext.UsbBootCandidates.Count -eq 1) {
                $candidate = $StorageContext.UsbBootCandidates[0]
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbBootMedium' -Locale $localeId -Values @{ Model=[string]$candidate.Model }
            }
            elseif ($StorageContext.UsbBootCandidates.Count -gt 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbMultipleBoot' -Locale $localeId
            }
            elseif ($StorageContext.UsbDisks.Count -eq 1) {
                $medium = $StorageContext.UsbDisks[0]
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbNonBoot' -Locale $localeId -Values @{ Model=[string]$medium.Model }
            }
            elseif ($StorageContext.UsbDisks.Count -gt 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbMultipleNoBoot' -Locale $localeId
            }
            elseif ($StorageContext.UsbDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbNone' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCheckFailed' -Locale $localeId
            }
            break
        }
        '^USB FDD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.UsbFddTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbFddSubtitle' -Locale $localeId
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId
            break
        }
        '^USB CD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.UsbCdTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCdSubtitle' -Locale $localeId
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId
            break
        }
        '^PXE BOOT$' {
            $title = Get-LocalizedStringCore -Key 'Boot.PxeTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.PxeSubtitle' -Locale $localeId
            $accentRole = 'Purple'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.PxeTooltip' -Locale $localeId
            break
        }
        '^LENOVO CLOUD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.LenovoRecoveryTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.LenovoRecoverySubtitle' -Locale $localeId
            $accentRole = 'Cyan'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.CyanTooltip' -Locale $localeId
            break
        }
        '^ON-PREMISE$' {
            $title = Get-LocalizedStringCore -Key 'Boot.CorporateTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.CorporateSubtitle' -Locale $localeId
            $accentRole = 'Cyan'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.CyanTooltip' -Locale $localeId
            break
        }
        '^Other HDD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.OtherDriveTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherDriveSubtitle' -Locale $localeId
            $accentRole = 'Secondary'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherDriveTooltip' -Locale $localeId
            break
        }
        '^Other CD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.OtherCdTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherCdSubtitle' -Locale $localeId
            $accentRole = 'Secondary'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherTargetTooltip' -Locale $localeId
            break
        }
        default {
            # Preserve unknown firmware descriptions rather than inventing a meaning.
            $title = $description
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId
            $accentRole = 'Secondary'
        }
    }

    return [pscustomobject]@{
        Guid = $Guid.ToLowerInvariant()
        Title = $title
        Subtitle = $subtitle
        RawDescription = $description
        AccentRole = $accentRole
        Symbol = $symbol
        TypeTooltip = $typeTooltip
        Resolution = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolution } else { $null }
        ResolutionReason = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolutionReason } else { $null }
    }
}


function Get-FriendlyBootEntry {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext
    )

    $model = Get-FriendlyBootEntryCore -Guid $Guid -RawDescription $RawDescription -StorageContext $StorageContext -Locale (Get-ActiveLocale)
    $accent = switch ([string]$model.AccentRole) {
        'Accent' { $script:ColorAccent; break }
        'Blue' { $script:ColorBlue; break }
        'Warning' { $script:ColorWarning; break }
        'Purple' { $script:ColorPurple; break }
        'Cyan' { $script:ColorCyan; break }
        default { $script:ColorSecondary; break }
    }

    [pscustomobject]@{
        Guid = [string]$model.Guid
        Title = [string]$model.Title
        Subtitle = [string]$model.Subtitle
        RawDescription = [string]$model.RawDescription
        Accent = $accent
        Symbol = [string]$model.Symbol
        TypeTooltip = [string]$model.TypeTooltip
        Resolution = $model.Resolution
        ResolutionReason = $model.ResolutionReason
    }
}


# Lenovo Boot Selector v0.4.1 - Functional Core: firmware text parsing
# Pure/deterministic functions only. Input is text; output is normalized data.

function Parse-GuidFromLine([string]$Line) {
    if ($Line -match '(\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\})') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}
function ConvertFrom-FirmwareEntriesText {
    param([AllowEmptyString()][string]$Text)

    # Map GUID -> firmware description. Support English and German field labels.
    $descriptions = @{}
    $currentGuid = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*(identifier|Bezeichner)\s+') {
            $currentGuid = Parse-GuidFromLine $line
            continue
        }

        if ($currentGuid -and $line -match '^\s*(description|Beschreibung)\s+(.+?)\s*$') {
            $descriptions[$currentGuid] = $Matches[2].Trim()
        }
    }
    return $descriptions
}

function ConvertFrom-FirmwareManagerText {
    param([AllowEmptyString()][string]$Text)

    $displayOrder = New-Object System.Collections.Generic.List[string]
    $selectedGuid = $null
    $readingDisplayOrder = $false

    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*displayorder\s+') {
            $guid = Parse-GuidFromLine $line
            if ($guid) { $displayOrder.Add($guid) }
            $readingDisplayOrder = $true
            continue
        }

        if ($readingDisplayOrder) {
            $continuedGuid = Parse-GuidFromLine $line
            if ($continuedGuid -and $line -match '^\s+\{') {
                $displayOrder.Add($continuedGuid)
                continue
            }
            $readingDisplayOrder = $false
        }

        if ($line -match '^\s*bootsequence\s+') {
            $selectedGuid = Parse-GuidFromLine $line
        }
    }

    return [pscustomobject]@{
        DisplayOrder = @($displayOrder.ToArray())
        SelectedGuid = $selectedGuid
    }
}

# Lenovo Boot Selector v0.5.0 - Functional Core: firmware target drift comparison
# Pure/deterministic functions only. No UI, IO, Task Scheduler or global script state.

function Compare-BootTargetDriftCore {
    param(
        [AllowNull()]$InstalledTargets,
        [AllowNull()]$Descriptions,
        [AllowNull()][string[]]$DisplayOrder
    )

    $installed = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($InstalledTargets)) {
        $guid = [string]$target.guid
        if (-not $guid) { continue }
        $normalized = $guid.Trim().ToLowerInvariant()
        if ($normalized -and -not $installed.Contains($normalized)) { $installed.Add($normalized) }
    }

    $current = New-Object System.Collections.Generic.List[string]
    $bootMenuGuid = $null
    if ($Descriptions) {
        foreach ($key in @($Descriptions.Keys)) {
            if ([string]$Descriptions[$key] -eq 'Boot Menu') {
                $bootMenuGuid = ([string]$key).Trim().ToLowerInvariant()
                break
            }
        }
    }
    if ($bootMenuGuid -and -not $current.Contains($bootMenuGuid)) { $current.Add($bootMenuGuid) }

    foreach ($guid in @($DisplayOrder)) {
        if (-not $guid) { continue }
        $normalized = ([string]$guid).Trim().ToLowerInvariant()
        if ($normalized -and -not $current.Contains($normalized)) { $current.Add($normalized) }
    }

    $added = @($current | Where-Object { -not $installed.Contains($_) })
    $removed = @($installed | Where-Object { -not $current.Contains($_) })

    [pscustomobject]@{
        HasDrift = [bool]($added.Count -gt 0 -or $removed.Count -gt 0)
        HasNewTargets = [bool]($added.Count -gt 0)
        AddedGuids = @($added)
        RemovedGuids = @($removed)
        CurrentGuids = @($current.ToArray())
        InstalledGuids = @($installed.ToArray())
        BootMenuGuid = $bootMenuGuid
    }
}


function Get-BootServiceFirmwareSnapshot {
    param([switch]$UseExistingCache)

    $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache:$UseExistingCache
    $firmwareText = Get-TaskBrokerFirmwareEntriesText -UseExistingCache:$UseExistingCache

    [pscustomobject]@{
        Descriptions = ConvertFrom-FirmwareEntriesText -Text ([string]$firmwareText)
        ManagerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    }
}

function Set-BootNextTargetService {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = $Guid.ToLowerInvariant()
    $managerText = Set-TaskBrokerBootNextTarget -Guid $normalized
    if ($managerText -notmatch [regex]::Escape($normalized)) {
        throw "BCDEdit wurde ausgeführt, aber das gewünschte Ziel konnte im Firmware Boot Manager nicht nachgewiesen werden: $normalized"
    }

    $managerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    if (-not $managerState.SelectedGuid -or $managerState.SelectedGuid -ne $normalized) {
        throw "Das gewünschte BootNext-Ziel wurde nach dem Schreiben nicht als bootsequence zurückgelesen: $normalized"
    }

    [pscustomobject]@{
        ExitCode = 0
        Guid = $normalized
        ManagerText = $managerText
    }
}

function Start-BackgroundRefreshWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [AllowNull()][string]$RuntimeSessionId
    )

    $powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-BackgroundRefresh',
        '-BackgroundResultPath', ('"{0}"' -f $ResultPath)
    )
    if ($RefreshStorage) { $args += '-BackgroundRefreshStorage' }
    if ($RefreshFirmware) { $args += '-BackgroundRefreshFirmware' }
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershellExe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process = [System.Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Hintergrundprozess konnte nicht gestartet werden.' }
    return $process
}

function Read-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw 'Der Hintergrund-Refresh hat kein Ergebnis geliefert.'
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Remove-BackgroundRefreshResultFile {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return }
    try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch { }
}

function New-BackgroundRefreshRequest {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware
    )

    [pscustomobject]@{
        RefreshStorage  = [bool]$RefreshStorage
        RefreshFirmware = [bool]$RefreshFirmware
    }
}

function New-BackgroundRefreshRuntimeState {
    [pscustomobject]@{
        Process        = $null
        Timer          = $null
        ResultPath     = $null
        ActiveRequest  = $null
        PendingRequest = $null
        LastTiming     = $null
    }
}

function Test-BackgroundRefreshActive {
    param([Parameter(Mandatory=$true)]$State)
    return ($null -ne $State.Process)
}

function Test-BackgroundRefreshNeedsFirmware {
    param(
        [bool]$RefreshStorage,
        [AllowNull()][string]$FirmwareCacheText,
        [datetime]$FirmwareCacheUtc,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if ($RefreshStorage) { return $true }
    if (-not $FirmwareCacheText) { return $true }
    return (($NowUtc - $FirmwareCacheUtc).TotalSeconds -ge 30)
}

function Test-BackgroundRefreshRequestEscalation {
    param(
        [AllowNull()]$ActiveRequest,
        [Parameter(Mandatory=$true)]$Requested
    )

    if (-not $ActiveRequest) { return $true }
    if ($Requested.RefreshStorage -and -not $ActiveRequest.RefreshStorage) { return $true }
    if ($Requested.RefreshFirmware -and -not $ActiveRequest.RefreshFirmware) { return $true }
    return $false
}

function Add-BackgroundRefreshPendingRequest {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Request
    )

    if (-not $State.PendingRequest) {
        $State.PendingRequest = New-BackgroundRefreshRequest -RefreshStorage:$Request.RefreshStorage -RefreshFirmware:$Request.RefreshFirmware
        return $State.PendingRequest
    }

    if ($Request.RefreshStorage) { $State.PendingRequest.RefreshStorage = $true }
    if ($Request.RefreshFirmware) { $State.PendingRequest.RefreshFirmware = $true }
    return $State.PendingRequest
}

function Set-BackgroundRefreshActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Process,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)]$Request
    )

    $State.Process = $Process
    $State.ResultPath = $ResultPath
    $State.ActiveRequest = $Request
}

function Set-BackgroundRefreshTimer {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timer
    )
    $State.Timer = $Timer
}

function Take-BackgroundRefreshCompletionContext {
    param([Parameter(Mandatory=$true)]$State)

    if (-not $State.Process) { return $null }

    $context = [pscustomobject]@{
        Process    = $State.Process
        Timer      = $State.Timer
        ResultPath = $State.ResultPath
        Request    = $State.ActiveRequest
    }

    $State.Process = $null
    $State.Timer = $null
    $State.ResultPath = $null
    $State.ActiveRequest = $null
    return $context
}

function Take-BackgroundRefreshPendingRequest {
    param([Parameter(Mandatory=$true)]$State)
    $pending = $State.PendingRequest
    $State.PendingRequest = $null
    return $pending
}

function Set-BackgroundRefreshLastTiming {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timing
    )
    $State.LastTiming = $Timing
}

function ConvertFrom-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Der Hintergrund-Refresh hat ein leeres Ergebnis geliefert.'
    }
    return ($Text | ConvertFrom-Json)
}


$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState


function Get-FirmwareBootState {
    param(
        [switch]$RefreshStorage,
        [switch]$UseExistingCache
    )

    $snapshot = Get-BootServiceFirmwareSnapshot -UseExistingCache:$UseExistingCache
    $descriptions = $snapshot.Descriptions
    $managerState = $snapshot.ManagerState
    $displayOrder = @($managerState.DisplayOrder)
    $selectedGuid = $managerState.SelectedGuid

    # Find Lenovo's actual firmware "Boot Menu" application dynamically.
    $bootMenuGuid = $null
    foreach ($key in $descriptions.Keys) {
        if ($descriptions[$key] -eq 'Boot Menu') {
            $bootMenuGuid = $key
            break
        }
    }

    $orderedGuids = New-Object System.Collections.Generic.List[string]
    if ($bootMenuGuid) { $orderedGuids.Add($bootMenuGuid) }
    foreach ($guid in $displayOrder) {
        if (-not $orderedGuids.Contains($guid)) { $orderedGuids.Add($guid) }
    }

    # If the active BootSequence points at an entry not in the display order, keep it visible.
    if ($selectedGuid -and -not $orderedGuids.Contains($selectedGuid)) {
        $orderedGuids.Insert(0, $selectedGuid)
    }

    if ($RefreshStorage -or ((-not $UseExistingCache) -and -not $script:StorageContext)) {
        $script:StorageContext = Get-StorageContext
    }
    $storageContext = $script:StorageContext

    $entries = @()
    foreach ($guid in $orderedGuids) {
        $raw = if ($descriptions.ContainsKey($guid)) { [string]$descriptions[$guid] } else { '' }
        $entries += Get-FriendlyBootEntry -Guid $guid -RawDescription $raw -StorageContext $storageContext
    }

    [pscustomobject]@{
        Entries = $entries
        SelectedGuid = $selectedGuid
        BootMenuGuid = $bootMenuGuid
        StorageContext = $storageContext
    }
}

function Set-BootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = Set-BootNextTargetService -Guid $Guid
        if ($result.ExitCode -ne 0) { throw 'Das Startziel konnte nicht gesetzt werden.' }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ guid = $Guid.ToLowerInvariant(); exitCode = $result.ExitCode })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ guid = $Guid.ToLowerInvariant() }) -Level error
        throw
    }
}

function Get-EntryByGuid([string]$Guid) {
    if (-not $Guid) { return $null }
    return $script:CurrentEntries | Where-Object { $_.Guid -eq $Guid.ToLowerInvariant() } | Select-Object -First 1
}

# Lenovo Boot Selector - boot-entry row presentation helpers.
# LBS-29 separates row rendering and interaction responsibilities from list refresh orchestration.

function New-BootEntryInteractionHandlers {
    $clickHandler = {
        param($sender, $eventArgs)
        if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
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
            Set-BootNextTarget -Guid $guid
            $script:SelectedGuid = $guid.ToLowerInvariant()
            $script:LastStatusText = if ($entry) { Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $entry) } } else { Get-LocalizedString -Key 'Status.NextBootSet' }
            Update-PopupRows
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
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) } catch { }
    }
    $dragEnterHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode -and $eventArgs.Data.GetDataPresent([string])) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
        else {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    }
    $dragDropHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $eventArgs.Data.GetDataPresent([string])) { return }
        $movedGuid = [string]$eventArgs.Data.GetData([string])
        $targetRow = Get-BootRowFromControl $sender
        if (-not $targetRow) { return }
        $point = $targetRow.PointToClient((New-Object Drawing.Point($eventArgs.X, $eventArgs.Y)))
        $after = ($point.Y -gt ($targetRow.Height / 2))
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
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
    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen($color, 1.6)
    $pupil = New-Object Drawing.SolidBrush($color)
    try {
        $eye = New-Object Drawing.Rectangle(7, 11, 18, 11)
        $eventArgs.Graphics.DrawEllipse($pen, $eye)
        $eventArgs.Graphics.FillEllipse($pupil, 14, 14, 4, 4)
        if ($hidden) {
            $slash = New-Object Drawing.Pen($color, 1.8)
            try { $eventArgs.Graphics.DrawLine($slash, 6, 24, 26, 9) } finally { $slash.Dispose() }
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

$editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 12.0, [Drawing.FontStyle]::Regular)) `
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

$grip = New-Label -Text '≡' -Font (New-Object Drawing.Font('Segoe UI Symbol', 13, [Drawing.FontStyle]::Regular)) `
    -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 350 -Y 12 -Width 26 -Height 34
$grip.Tag = $entry.Guid
$grip.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$grip.AllowDrop = $true
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

    $checkText = if ($isSelected) { '✓' } else { '' }
    $check = New-Label -Text $checkText `
        -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 354 -Y 12 -Width 24 -Height 34
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
        $control.Add_DragDrop($dragDropHandler)
    }
}
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

$isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
$isSelected = (-not $script:IsManageEntriesMode) -and $script:SelectedGuid -and ($entry.Guid -eq $script:SelectedGuid)
if ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

$marker = New-Object System.Windows.Forms.Panel
$marker.Location = New-Object Drawing.Point(0, 0)
$marker.Size = New-Object Drawing.Size(3, $rowHeight)
$marker.BackColor = $script:ColorRow
if ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
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
$displayTitle = if ($script:IsManageEntriesMode) {
    Get-EntryDisplayTitle -Entry $entry -UseManageDraft
}
else {
    Get-EntryDisplayTitle -Entry $entry
}

$titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
$titleText = if ($aliasEditActive) { [string]$entry.Title } else { $displayTitle }
$title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
    -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
$title.Tag = $entry.Guid
$title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
$row.Controls.Add($title)

$subtitle = $null
if (-not $aliasEditActive) {
    $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
    $subtitleText = if ($script:IsManageEntriesMode -and $alias) {
        Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name=[string]$entry.Title }
    }
    elseif ($script:IsManageEntriesMode -and ([string]$entry.RawDescription -eq 'Boot Menu')) {
        Get-LocalizedString -Key 'Boot.MenuManageSubtitle'
    }
    else {
        [string]$entry.Subtitle
    }
    $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 8.3, [Drawing.FontStyle]::Regular)) `
        -ForeColor $subtitleColor -X 58 -Y 27 -Width $subtitleWidth -Height 27
    $subtitle.AutoEllipsis = $false
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
$ContentPanel.Size = New-Object Drawing.Size(390, $contentHeight)
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
function New-Label {
    param(
        [string]$Text,
        [Drawing.Font]$Font,
        [Drawing.Color]$ForeColor,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.BackColor = [Drawing.Color]::Transparent
    $label.Location = New-Object Drawing.Point($X, $Y)
    $label.Size = New-Object Drawing.Size($Width, $Height)
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function Get-BootRowFromControl($Control) {
    $current = $Control
    while ($current) {
        if (($current -is [System.Windows.Forms.Panel]) -and $current.Name -eq 'BootRow') { return $current }
        $current = $current.Parent
    }
    return $null
}

function Set-RowHoverState($Control, [bool]$Hover) {
    $row = Get-BootRowFromControl $Control
    if (-not $row) { return }

    $rowGuid = [string]$row.Tag
    if ($script:IsManageEntriesMode) {
        $hidden = Test-ManageEntryHidden -Guid $rowGuid
        if ($hidden) {
            $row.BackColor = if ($Hover) { [Drawing.Color]::FromArgb(37,37,37) } else { [Drawing.Color]::FromArgb(27,27,27) }
        }
        else {
            $row.BackColor = if ($Hover) { $script:ColorHover } else { $script:ColorRow }
        }
        $row.Invalidate($true)
        return
    }

    $isSelected = $script:SelectedGuid -and ($rowGuid -eq $script:SelectedGuid)
    if ($isSelected) {
        $row.BackColor = $script:ColorSelectedRow
    }
    elseif ($Hover) {
        $row.BackColor = $script:ColorHover
    }
    else {
        $row.BackColor = $script:ColorRow
    }
    $row.Invalidate($true)
}

function Update-PopupRows {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }

    $listMatches = $script:Popup.Controls.Find('EntryList', $true)
    $listPanel = if ($listMatches.Count -gt 0) { $listMatches[0] } else { $null }
    $contentPanel = if ($listPanel) { $listPanel.Controls['EntryContent'] } else { $null }
    $scrollBar = if ($listPanel) { $listPanel.Controls['EntryScroll'] } else { $null }
    $statusMatches = $script:Popup.Controls.Find('StatusLabel', $true)
    $statusLabel = if ($statusMatches.Count -gt 0) { $statusMatches[0] } else { $null }
    if (-not $listPanel -or -not $contentPanel) { return }

    $contentPanel.SuspendLayout()
    $contentPanel.Controls.Clear()

    $baseRowHeight = 60
    $rowGap = 4
    $y = 0
    $displayEntries = if ($script:IsManageEntriesMode) {
        @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)
    }
    else {
        @(Get-OrderedEntriesForUi)
    }
    $handlers = New-BootEntryInteractionHandlers
    $contentPanel.AllowDrop = $false

    foreach ($entry in $displayEntries) {
        $rendered = New-BootEntryRow -Entry $entry -Y $y -BaseRowHeight $baseRowHeight -Handlers $handlers
        $contentPanel.Controls.Add($rendered.Row)
        $y += ([int]$rendered.Height + $rowGap)
    }

    Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $y -BaseRowHeight $baseRowHeight -RowGap $rowGap

    if ($statusLabel) { $statusLabel.Text = $script:LastStatusText }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-ManageEntriesUiState
    Update-ManageSaveButtonState
    $contentPanel.ResumeLayout()
    Update-MaintenanceUi
}



function Apply-FirmwareBootState {
    param([Parameter(Mandatory=$true)]$State)

    $script:CurrentEntries = @($State.Entries)
    $script:SelectedGuid = if ($State.SelectedGuid) { $State.SelectedGuid.ToLowerInvariant() } else { $null }

    if ($script:SelectedGuid) {
        $selected = Get-EntryByGuid $script:SelectedGuid
        $script:LastStatusText = if ($selected) { Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $selected) } } else { Get-LocalizedString -Key 'Status.OneTimeNextBootSet' }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.NoOneTimeNextBoot'
    }

    if (Get-TaskBrokerInteractiveReady) { [void](Refresh-SystemDefaultState) }
    Update-PopupRows
}

function Refresh-BootState {
    param([switch]$RefreshStorage)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($RefreshStorage) {
        $script:ManagerCacheText = $null
        $script:FirmwareCacheText = $null
    }
    try {
        $state = Get-FirmwareBootState -RefreshStorage:$RefreshStorage
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage; entryCount = @($state.Entries).Count; selectedGuid = $state.SelectedGuid })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsReadFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        throw
    }
}

function Load-BootStateFromExistingCache {
    try {
        $state = Get-FirmwareBootState -UseExistingCache
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state
        return $true
    }
    catch {
        return $false
    }
}

function Get-BackgroundRefreshResult {
    param([Parameter(Mandatory=$true)][string]$ResultPath)
    $text = Read-BackgroundRefreshResultText -Path $ResultPath
    return (ConvertFrom-BackgroundRefreshResultText -Text $text)
}

function Apply-BackgroundRefreshResult {
    param(
        [Parameter(Mandatory=$true)]$Result,
        [Parameter(Mandatory=$true)]$Request
    )

    $requestedStorage = [bool]$Request.RefreshStorage
    if (-not $Result.Success) {
        if (Test-MaintenanceBusy) {
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_RESULT_IGNORED' -Stage 'maintenance' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); workerStage = [string]$Result.Stage; workerError = [string]$Result.Error })
            return $false
        }
        if ([string]$Result.Stage -eq 'ready') {
            $script:TaskBrokerReadyCached = $false
            $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
            if (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
            Update-TaskBrokerUiState -Fast | Out-Null
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'ready' -Success $false -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ workerError = [string]$Result.Error }) -Level error
            if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
            return $false
        }
        throw ("Hintergrund-Refresh ({0}) fehlgeschlagen: {1}" -f ([string]$Result.Stage), ([string]$Result.Error))
    }

    $script:TaskBrokerReadyCached = $true
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    Set-BackgroundRefreshLastTiming -State $script:BackgroundRefreshState -Timing $Result.Timings
    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ requestedStorage = $requestedStorage; readyMs = $Result.Timings.ReadyMs; managerMs = $Result.Timings.ManagerMs; firmwareMs = $Result.Timings.FirmwareMs; storageMs = $Result.Timings.StorageMs })

    [void](Sync-TaskBrokerFirmwareCachesFromFiles)
    [void](Update-BootTargetDriftState)

    if ($requestedStorage -and $Result.StorageContext) {
        $script:StorageContext = $Result.StorageContext
    }

    $state = Get-FirmwareBootState -UseExistingCache
    Apply-FirmwareBootState -State $state
    Update-TaskBrokerUiState -Fast | Out-Null
    Show-BootTargetDriftNotificationIfNeeded
    return $true
}

function Stop-BackgroundBootRefreshForMaintenance {
    param([Parameter(Mandatory=$true)][string]$Reason)
    if (-not $script:BackgroundRefreshState) { return }

    $context = $null
    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    }
    [void](Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState)
    if ($context) {
        if ($context.Timer) {
            try { $context.Timer.Stop() } catch { }
            try { $context.Timer.Dispose() } catch { }
        }
        if ($context.Process) {
            try {
                $context.Process.Refresh()
                if (-not $context.Process.HasExited) { $context.Process.Kill() }
            } catch { }
        }
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_CANCELLED_FOR_MAINTENANCE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason })
    }
    Update-RefreshButtonVisual
}

function Complete-BackgroundBootRefresh {
    if (Test-MaintenanceBusy) {
        Stop-BackgroundBootRefreshForMaintenance -Reason (Get-MaintenanceMode)
        return
    }
    if (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) { return }

    $process = $script:BackgroundRefreshState.Process
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) { return }

    $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    if (-not $context) { return }

    if ($context.Timer) {
        try { $context.Timer.Stop() } catch { }
        try { $context.Timer.Dispose() } catch { }
    }
    Update-RefreshButtonVisual

    $continuePending = $true
    try {
        $result = Get-BackgroundRefreshResult -ResultPath ([string]$context.ResultPath)
        $continuePending = Apply-BackgroundRefreshResult -Result $result -Request $context.Request
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ requestedStorage = [bool]$context.Request.RefreshStorage }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
    finally {
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
    }

    if (-not $continuePending) { return }

    $pending = Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState
    if ($pending) {
        if ($pending.RefreshFirmware) { $script:FirmwareCacheUtc = [datetime]::MinValue }
        $pendingStorage = [bool]$pending.RefreshStorage
        Start-BackgroundBootRefresh -RefreshStorage:$pendingStorage
    }
}

function Start-BackgroundBootRefresh {
    param([switch]$RefreshStorage)

    if (Test-MaintenanceBusy) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_SUPPRESSED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); refreshStorage = [bool]$RefreshStorage })
        return
    }

    $refreshFirmware = Test-BackgroundRefreshNeedsFirmware `
        -RefreshStorage ([bool]$RefreshStorage) `
        -FirmwareCacheText $script:FirmwareCacheText `
        -FirmwareCacheUtc $script:FirmwareCacheUtc
    $request = New-BackgroundRefreshRequest -RefreshStorage ([bool]$RefreshStorage) -RefreshFirmware ([bool]$refreshFirmware)

    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        try {
            $script:BackgroundRefreshState.Process.Refresh()
            if (-not $script:BackgroundRefreshState.Process.HasExited) {
                # Popup opens while startup refresh is active must not queue a duplicate.
                # Only a request that adds storage or firmware work is coalesced as pending.
                if (Test-BackgroundRefreshRequestEscalation -ActiveRequest $script:BackgroundRefreshState.ActiveRequest -Requested $request) {
                    [void](Add-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState -Request $request)
                }
                return
            }
        }
        catch { }
        Complete-BackgroundBootRefresh
    }

    if (-not $script:ScriptPath -or -not (Test-Path -LiteralPath $script:ScriptPath)) { return }
    if (-not (Get-TaskBrokerInteractiveReady)) { return }

    try {
        if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir)) {
            New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force | Out-Null
        }
        $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-refresh-{0}.json" -f ([guid]::NewGuid().ToString('N')))
        $process = Start-BackgroundRefreshWorkerProcess `
            -ScriptPath $script:ScriptPath `
            -ResultPath $resultPath `
            -RefreshStorage ([bool]$request.RefreshStorage) `
            -RefreshFirmware ([bool]$request.RefreshFirmware) `
            -RuntimeSessionId $script:RuntimeSessionId

        Set-BackgroundRefreshActive -State $script:BackgroundRefreshState -Process $process -ResultPath $resultPath -Request $request
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $process.Id; refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware })
        Update-RefreshButtonVisual

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 100
        $timer.Add_Tick({ Complete-BackgroundBootRefresh })
        Set-BackgroundRefreshTimer -State $script:BackgroundRefreshState -Timer $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.RefreshStartFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}

function Invoke-BackgroundRefreshWorker {
    $total = [System.Diagnostics.Stopwatch]::StartNew()
    $timings = [ordered]@{ ReadyMs = 0; ManagerMs = 0; FirmwareMs = 0; StorageMs = 0; TotalMs = 0 }
    $result = [ordered]@{ Success = $false; Error = $null; Stage = 'ready'; StorageContext = $null; Timings = $timings }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if (-not (Test-TaskBrokerReady -Force)) { throw 'Die Systemfunktionen sind nicht vollständig verfügbar.' }
        $sw.Stop(); $timings.ReadyMs = $sw.ElapsedMilliseconds

        $result.Stage = 'manager'
        $sw.Restart(); [void](Get-TaskBrokerFirmwareManagerText -Force); $sw.Stop(); $timings.ManagerMs = $sw.ElapsedMilliseconds
        if ($BackgroundRefreshFirmware) {
            $result.Stage = 'firmware'
            $sw.Restart(); [void](Get-TaskBrokerFirmwareEntriesText -Force); $sw.Stop(); $timings.FirmwareMs = $sw.ElapsedMilliseconds
        }

        if ($BackgroundRefreshStorage) {
            $result.Stage = 'storage'
            $sw.Restart(); $result.StorageContext = Get-StorageContext; $sw.Stop(); $timings.StorageMs = $sw.ElapsedMilliseconds
        }
        $result.Stage = 'complete'
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    finally {
        $total.Stop(); $timings.TotalMs = $total.ElapsedMilliseconds
        if ($BackgroundResultPath) {
            try {
                $parent = Split-Path -Parent $BackgroundResultPath
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                $json = $result | ConvertTo-Json -Depth 8
                [System.IO.File]::WriteAllText($BackgroundResultPath, $json, (New-Object System.Text.UTF8Encoding($false)))
            }
            catch { }
        }
    }

    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $timings.TotalMs -Data (New-RuntimeDiagnosticData @{ readyMs = $timings.ReadyMs; managerMs = $timings.ManagerMs; firmwareMs = $timings.FirmwareMs; storageMs = $timings.StorageMs; workerError = [string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    if ($result.Success) { return 0 }
    return 1
}

# Lenovo Boot Selector - popup section composition.
# Domain-specific WinForms builders extracted from New-PopupForm by LBS-29.

function Add-PopupHeaderSection {
    param([Parameter(Mandatory=$true)]$Root)

    # v0.2.29: compact brand header. No decorative status dot and no permanent
    # subtitle. A status line appears only while the background refresh is active.
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size(390, 60)
    $header.BackColor = $script:ColorHeader

    $headerTitle = New-Label -Text 'Lenovo Boot Selector' -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 16 -Y 19 -Width 285 -Height 22
    $headerTitle.Name = 'HeaderTitleLabel'
    $script:HeaderTitleLabel = $headerTitle
    $header.Controls.Add($headerTitle)

    # LBS-14: a real flat Button keeps the status visually label-like while
    # providing native Enter/Space activation and keyboard focus semantics.
    $headerSub = New-Object System.Windows.Forms.Button
    $headerSub.Text = ''
    $headerSub.Font = New-Object Drawing.Font('Segoe UI', 7.8, [Drawing.FontStyle]::Regular)
    $headerSub.ForeColor = $script:ColorSecondary
    $headerSub.BackColor = $script:ColorHeader
    $headerSub.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $headerSub.FlatAppearance.BorderSize = 0
    $headerSub.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $headerSub.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $headerSub.UseVisualStyleBackColor = $false
    $headerSub.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $headerSub.Padding = New-Object System.Windows.Forms.Padding(0)
    $headerSub.Location = New-Object Drawing.Point(13, 28)
    $headerSub.Size = New-Object Drawing.Size(300, 21)
    $headerSub.TabStop = $false
    $headerSub.Cursor = [System.Windows.Forms.Cursors]::Default
    $headerSub.Name = 'HeaderStatusLabel'
    $headerSub.Visible = $false
    $headerSub.AccessibleDescription = Get-LocalizedString -Key 'Popup.HeaderUpdateAccessible'
    $headerSub.Add_MouseEnter({
        $script:HeaderStatusHovered = $true
        Update-HeaderStatusInteractionVisual
    })
    $headerSub.Add_MouseLeave({
        $script:HeaderStatusHovered = $false
        Update-HeaderStatusInteractionVisual
    })
    $headerSub.Add_Enter({ Update-HeaderStatusInteractionVisual })
    $headerSub.Add_Leave({ Update-HeaderStatusInteractionVisual })
    $headerSub.Add_Click({
        if (-not $script:HeaderUpdateInteractionEnabled) { return }
        [void](Show-AvailableUpdateDialog)
    })
    $script:HeaderStatusLabel = $headerSub
    $header.Controls.Add($headerSub)

    $refresh = New-Object System.Windows.Forms.Button
    $refresh.Text = '↻'
    $refresh.Font = New-Object Drawing.Font('Segoe UI Symbol', 11.5, [Drawing.FontStyle]::Regular)
    $refresh.ForeColor = $script:ColorSecondary
    $refresh.BackColor = $script:ColorHeader
    $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $refresh.FlatAppearance.BorderSize = 0
    $refresh.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    $refresh.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $refresh.Location = New-Object Drawing.Point(340, 12)
    $refresh.Size = New-Object Drawing.Size(34, 34)
    $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:RefreshButton = $refresh
    $refresh.Add_MouseEnter({
        $script:RefreshButtonHovered = $true
        Update-RefreshButtonVisual
    })
    $refresh.Add_MouseLeave({
        $script:RefreshButtonHovered = $false
        Update-RefreshButtonVisual
    })
    $refresh.Add_Click({
        if (Test-MaintenanceBusy) { return }
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshing'
        Update-PopupRows
        Start-BackgroundBootRefresh -RefreshStorage
        Update-RefreshButtonVisual
    })
    $header.Controls.Add($refresh)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($refresh, (Get-LocalizedString -Key 'Action.RefreshBootTargets')) }
    Update-RefreshButtonVisual
    $Root.Controls.Add($header)

    $headerDivider = New-Object System.Windows.Forms.Panel
    $headerDivider.Location = New-Object Drawing.Point(0, 59)
    $headerDivider.Size = New-Object Drawing.Size(390, 1)
    $headerDivider.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
    $Root.Controls.Add($headerDivider)

    $section = New-Object System.Windows.Forms.Panel
    $section.Location = New-Object Drawing.Point(0, 60)
    $section.Size = New-Object Drawing.Size(390, 28)
    $section.BackColor = $script:ColorBackground

    $sectionLabel = New-Label -Text (Get-LocalizedString -Key 'Popup.NextBootSection') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 4 -Width 200 -Height 20
    $sectionLabel.Name = 'SectionLabel'
    $section.Controls.Add($sectionLabel)

    $manageButton = New-Object System.Windows.Forms.Button
    $manageButton.Name = 'ManageEntriesButton'
    $manageButton.Text = Get-LocalizedString -Key 'Popup.Customize'
    $manageButton.Font = New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)
    $manageButton.ForeColor = $script:ColorSecondary
    $manageButton.BackColor = $script:ColorBackground
    $manageButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $manageButton.FlatAppearance.BorderSize = 0
    $manageButton.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38, 38, 38)
    $manageButton.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $manageButton.Location = New-Object Drawing.Point(268, 1)
    $manageButton.Size = New-Object Drawing.Size(104, 25)
    $manageButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $manageButton.Add_Click({ Start-ManageEntriesMode })
    $script:ManageEntriesButton = $manageButton
    $section.Controls.Add($manageButton)
    $Root.Controls.Add($section)
}

function Add-PopupBootEntryListSection {
    param([Parameter(Mandatory=$true)]$Root)

    $listPanel = New-Object System.Windows.Forms.Panel
    $listPanel.Name = 'EntryList'
    $listPanel.Location = New-Object Drawing.Point(0, 88)
    $listPanel.Size = New-Object Drawing.Size(390, 402)
    $listPanel.BackColor = $script:ColorBackground
    $listPanel.AutoScroll = $false
    $listPanel.TabStop = $true

    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Name = 'EntryContent'
    $contentPanel.Location = New-Object Drawing.Point(0, 0)
    $contentPanel.Size = New-Object Drawing.Size(390, 402)
    $contentPanel.BackColor = $script:ColorBackground
    $listPanel.Controls.Add($contentPanel)

    $entryScroll = New-Object LenovoVerticalScrollBar
    $entryScroll.Name = 'EntryScroll'
    $entryScroll.Location = New-Object Drawing.Point(382, 0)
    $entryScroll.Size = New-Object Drawing.Size(8, 402)
    $entryScroll.TrackColor = [Drawing.Color]::FromArgb(23, 23, 23)
    $entryScroll.ThumbColor = $script:ColorAccent
    $entryScroll.ThumbHoverColor = [Drawing.Color]::FromArgb(242, 59, 49)
    $entryScroll.Visible = $false
    $entryScroll.Add_ValueChanged({
        try {
            $scrollContainer = $this.Parent
            if ($scrollContainer) {
                $content = $scrollContainer.Controls['EntryContent']
                if ($content) { $content.Top = -1 * $this.Value }
            }
        }
        catch {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.ScrollPositionFailed'
        }
    })
    $listPanel.Controls.Add($entryScroll)
    $entryScroll.BringToFront()

    $listPanel.Add_MouseWheel({
        param($sender, $eventArgs)
        $bar = $sender.Controls['EntryScroll']
        if ($bar -and $bar.Visible) {
            $direction = if ($eventArgs.Delta -gt 0) { -1 } else { 1 }
            $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
        }
    })
    $listPanel.Add_MouseEnter({ $this.Focus() })
    $Root.Controls.Add($listPanel)
}

function Add-PopupSettingsSection {
    param([Parameter(Mandatory=$true)]$Root)

    # v0.2.31: compact lower third with two aligned configuration rows and one
    # action area. The selected next-boot target is shown directly with Restart,
    # so the former duplicate status/footer block is no longer needed.
    $configSection = New-Object System.Windows.Forms.Panel
    $configSection.Name = 'ConfigSectionPanel'
    $configSection.Location = New-Object Drawing.Point(0, 490)
    $configSection.Size = New-Object Drawing.Size(390, 20)
    $configSection.BackColor = $script:ColorSurface

    $configLabel = New-Label -Text (Get-LocalizedString -Key 'Settings.Title') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 2 -Width 220 -Height 17
    $configSection.Controls.Add($configLabel)
    $Root.Controls.Add($configSection)

    $settings = New-Object System.Windows.Forms.Panel
    $settings.Name = 'SettingsPanel'
    $settings.Location = New-Object Drawing.Point(0, 510)
    $settings.Size = New-Object Drawing.Size(390, 38)
    $settings.BackColor = $script:ColorSurface

    $autostartText = New-Label -Text (Get-LocalizedString -Key 'Settings.Autostart') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 280 -Height 22
    $autostartText.Cursor = [System.Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($autostartText)
    $script:AutostartTextLabel = $autostartText

    $autostart = New-Object LenovoCheckBox
    $autostart.Name = 'AutostartCheckbox'
    $autostart.Text = ''
    $autostart.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $autostart.ForeColor = $script:ColorPrimary
    $autostart.BackColor = $script:ColorSurface
    $autostart.AccentColor = $script:ColorAccent
    $autostart.Location = New-Object Drawing.Point(348, 7)
    $autostart.Size = New-Object Drawing.Size(26, 24)
    $autostart.Add_CheckedChanged({
        if (-not $script:UpdatingAutostartUi) {
            Set-AutostartFromUi -Enabled:$this.Checked
        }
    })
    $autostartText.Add_Click({ if ($script:AutostartCheckbox) { $script:AutostartCheckbox.Checked = -not $script:AutostartCheckbox.Checked } })
    $script:AutostartCheckbox = $autostart
    $settings.Controls.Add($autostart)
    $Root.Controls.Add($settings)

    $defaultPanel = New-Object System.Windows.Forms.Panel
    $defaultPanel.Name = 'DefaultPanel'
    $defaultPanel.Location = New-Object Drawing.Point(0, 548)
    $defaultPanel.Size = New-Object Drawing.Size(390, 38)
    $defaultPanel.BackColor = $script:ColorSurface
    $defaultPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $defaultName = New-Label -Text (Get-LocalizedString -Key 'Settings.DefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 150 -Height 22
    $defaultName.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultName)

    $defaultValue = New-Label -Text (Get-LocalizedString -Key 'Settings.NoDefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 164 -Y 8 -Width 184 -Height 22
    $defaultValue.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $defaultValue.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultValue.Name = 'DefaultTargetValueLabel'
    $defaultPanel.Controls.Add($defaultValue)
    $script:DefaultValueLabel = $defaultValue

    $defaultArrow = New-Label -Text '›' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $defaultArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $defaultArrow.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultArrow.Name = 'DefaultTargetArrowLabel'
    $defaultPanel.Controls.Add($defaultArrow)
    $script:DefaultArrowLabel = $defaultArrow

    $defaultRowEnter = {
        if ($script:DefaultInteractionEnabled -and $script:DefaultButton) { $script:DefaultButton.BackColor = [Drawing.Color]::FromArgb(38,38,38) }
    }
    $defaultRowLeave = {
        if ($script:DefaultButton) { $script:DefaultButton.BackColor = $script:ColorSurface }
    }
    $defaultRowClick = {
        if ($script:DefaultInteractionEnabled -and $script:DefaultButton) { Show-DefaultTargetMenu -Owner $script:DefaultButton }
    }
    foreach ($control in @($defaultPanel,$defaultName,$defaultValue,$defaultArrow)) {
        $control.Add_MouseEnter($defaultRowEnter)
        $control.Add_MouseLeave($defaultRowLeave)
        $control.Add_Click($defaultRowClick)
    }
    $script:DefaultButton = $defaultPanel
    $Root.Controls.Add($defaultPanel)

    $settingsDivider = New-Object System.Windows.Forms.Panel
    $settingsDivider.Name = 'SettingsDivider'
    $settingsDivider.Location = New-Object Drawing.Point(16, 586)
    $settingsDivider.Size = New-Object Drawing.Size(358, 1)
    $settingsDivider.BackColor = $script:ColorAccent
    $Root.Controls.Add($settingsDivider)
}

function Add-PopupRestartSection {
    param([Parameter(Mandatory=$true)]$Root)

    $restartPanel = New-Object System.Windows.Forms.Panel
    $restartPanel.Name = 'RestartPanel'
    $restartPanel.Location = New-Object Drawing.Point(0, 587)
    $restartPanel.Size = New-Object Drawing.Size(390, 65)
    $restartPanel.BackColor = $script:ColorSurface

    $restartButton = New-Object System.Windows.Forms.Button
    $restartButton.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartButton.Font = New-Object Drawing.Font('Segoe UI', 8.6, [Drawing.FontStyle]::Bold)
    $restartButton.ForeColor = $script:ColorPrimary
    $restartButton.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
    $restartButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restartButton.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68, 68, 68)
    $restartButton.FlatAppearance.BorderSize = 1
    $restartButton.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $restartButton.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58, 27, 25)
    $restartButton.Location = New-Object Drawing.Point(16, 6)
    $restartButton.Size = New-Object Drawing.Size(358, 31)
    $restartButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restartButton.Add_Click({ Restart-Windows })
    $restartPanel.Controls.Add($restartButton)

    $restartTarget = New-Label -Text (Get-LocalizedString -Key 'Status.NextTargetDefaultOrder') -Font (New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 16 -Y 39 -Width 358 -Height 18
    $restartTarget.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $restartTarget.Name = 'RestartTargetLabel'
    $restartPanel.Controls.Add($restartTarget)
    $script:RestartTargetLabel = $restartTarget
    $Root.Controls.Add($restartPanel)

    # Dedicated footer height prevents Segoe UI/DPI clipping at the bottom edge.
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Name = 'FooterPanel'
    $footerPanel.Location = New-Object Drawing.Point(0, 652)
    $footerPanel.Size = New-Object Drawing.Size(390, 20)
    $footerPanel.BackColor = $script:ColorSurface
    $versionLabel = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(115,115,115)) -X 316 -Y 0 -Width 58 -Height 18
    $versionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $footerPanel.Controls.Add($versionLabel)
    $Root.Controls.Add($footerPanel)
}

function Add-PopupManageEntriesSection {
    param([Parameter(Mandatory=$true)]$Root)

    # Entry-management overlay. It temporarily replaces the normal settings/footer
    # while the same boot list switches into edit mode.
    $managePanel = New-Object System.Windows.Forms.Panel
    $managePanel.Name = 'ManageEntriesPanel'
    $managePanel.Location = New-Object Drawing.Point(0, 490)
    $managePanel.Size = New-Object Drawing.Size(390, 182)
    $managePanel.BackColor = $script:ColorSurface
    $managePanel.Visible = $false

    $manageDivider = New-Object System.Windows.Forms.Panel
    $manageDivider.Location = New-Object Drawing.Point(16, 0)
    $manageDivider.Size = New-Object Drawing.Size(358, 1)
    $manageDivider.BackColor = [Drawing.Color]::FromArgb(54,54,54)
    $managePanel.Controls.Add($manageDivider)

    $manageTitle = New-Label -Text (Get-LocalizedString -Key 'Manage.Title') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 8 -Width 350 -Height 18
    $managePanel.Controls.Add($manageTitle)

    $manageHint = New-Label -Text (Get-LocalizedString -Key 'Manage.Hint') -Font (New-Object Drawing.Font('Segoe UI', 7.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 29 -Width 358 -Height 17
    $managePanel.Controls.Add($manageHint)

    $manageSubHint = New-Label -Text (Get-LocalizedString -Key 'Manage.SubHint') -Font (New-Object Drawing.Font('Segoe UI', 7.2, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 46 -Width 358 -Height 17
    $managePanel.Controls.Add($manageSubHint)

    $cancelManage = New-Object System.Windows.Forms.Button
    $cancelManage.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $cancelManage.ForeColor = $script:ColorPrimary
    $cancelManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $cancelManage.FlatAppearance.BorderSize = 1
    $cancelManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $cancelManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58,27,25)
    $cancelManage.Location = New-Object Drawing.Point(16, 78)
    $cancelManage.Size = New-Object Drawing.Size(126, 34)
    $cancelManage.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelManage.Add_Click({ Stop-ManageEntriesMode })
    $managePanel.Controls.Add($cancelManage)

    $saveManage = New-Object System.Windows.Forms.Button
    $saveManage.Text = Get-LocalizedString -Key 'Manage.Save'
    $saveManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Bold)
    $saveManage.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
    $saveManage.BackColor = [Drawing.Color]::FromArgb(35,35,35)
    $saveManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
    $saveManage.FlatAppearance.BorderSize = 1
    $saveManage.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $saveManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $saveManage.Location = New-Object Drawing.Point(150, 78)
    $saveManage.Size = New-Object Drawing.Size(224, 34)
    $saveManage.Enabled = $false
    $saveManage.Cursor = [System.Windows.Forms.Cursors]::Default
    $saveManage.Add_Click({ Stop-ManageEntriesMode -Save })
    $managePanel.Controls.Add($saveManage)
    $script:ManageSaveButton = $saveManage

    $manageFooter = New-Object System.Windows.Forms.Panel
    $manageFooter.Location = New-Object Drawing.Point(0, 150)
    $manageFooter.Size = New-Object Drawing.Size(390, 32)
    $manageFooter.BackColor = $script:ColorSurface
    $manageVersion = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(120,120,120)) -X 316 -Y 7 -Width 58 -Height 18
    $manageVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $manageFooter.Controls.Add($manageVersion)
    $managePanel.Controls.Add($manageFooter)
    $Root.Controls.Add($managePanel)
}
function New-PopupForm {
    if (-not $script:BootTypeToolTip) {
        $script:BootTypeToolTip = New-Object System.Windows.Forms.ToolTip
        $script:BootTypeToolTip.InitialDelay = 350
        $script:BootTypeToolTip.ReshowDelay = 100
        $script:BootTypeToolTip.AutoPopDelay = 8000
        $script:BootTypeToolTip.ShowAlways = $true
        $script:BootTypeToolTip.UseAnimation = $true
        $script:BootTypeToolTip.UseFading = $true
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Name = 'LenovoBootSelectorPopup'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    # v0.2.28: plain square utility panel, intentionally without an outer
    # Lenovo-red frame or rounded clipping. Red remains an interaction accent.
    $form.BackColor = $script:ColorBackground
    $form.Width = 390
    $form.Height = 672

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'PopupRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(390, 672)
    $root.BackColor = $script:ColorBackground
    $form.Controls.Add($root)

    Add-PopupHeaderSection -Root $root
    Add-PopupBootEntryListSection -Root $root
    Add-PopupSettingsSection -Root $root
    Add-PopupRestartSection -Root $root
    Add-PopupManageEntriesSection -Root $root
    $maintenancePanel = New-MaintenanceStatePanel
    $root.Controls.Add($maintenancePanel)

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_Deactivate({
        if (-not $script:ExitRequested -and -not (Test-MaintenanceBusy)) { $this.Hide() }
    })

    return $form
}
function Position-Popup {
    if (-not $script:Popup) { return }
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
    $wa = $screen.WorkingArea
    $x = $wa.Right - $script:Popup.Width - 10
    $y = $wa.Bottom - $script:Popup.Height - 10
    if ($x -lt $wa.Left) { $x = $wa.Left + 5 }
    if ($y -lt $wa.Top) { $y = $wa.Top + 5 }
    $script:Popup.Location = New-Object Drawing.Point($x, $y)
}

function Show-OrTogglePopup {
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $script:Popup = New-PopupForm
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $maintenanceBusy = Test-MaintenanceBusy
    $brokerReady = if ($maintenanceBusy) { $false } else { ((Get-SystemFunctionsPresentationState) -eq 'Ready') }
    if ($brokerReady) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if (Test-BootTargetDriftDetected) {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { Get-LocalizedString -Key 'Status.NewBootTargetDetected' } else { Get-LocalizedString -Key 'Status.BootTargetsChanged' }
            }
            elseif (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup
    $script:Popup.Show()
    $script:Popup.Activate()

    # LBS-21: opening the visible UI is the automatic read-only update-check trigger.
    # The update worker has its own busy gate and can overlap the independent boot-target worker.
    [void](Start-PopupUpdateCheck)

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($brokerReady -and -not $maintenanceBusy) {
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext)
    }
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}


Initialize-RuntimeDiagnostics
if (-not $BackgroundRefresh) {
    if ($singleInstanceMutexState -eq 'abandoned-recovered') {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs }) -Level warning
    }
    elseif ($mutexOwned) {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ACQUIRED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs })
    }
}

if ($BackgroundRefresh) {
    $exitCode = Invoke-BackgroundRefreshWorker
    exit $exitCode
}
if ($UpdateCheck) {
    $exitCode = Invoke-UpdateCheckWorker
    exit $exitCode
}
if ($UpdatePrepare) {
    $exitCode = Invoke-UpdatePrepareWorker
    exit $exitCode
}

try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    try {
        [System.Windows.Forms.Application]::add_ThreadException({
            param($sender,$eventArgs)
            Write-RuntimeDiagnosticEvent -Event 'UI_THREAD_EXCEPTION' -Stage 'ui' -Success $false -ErrorRecord $eventArgs.Exception -Level error
        })
    } catch { }
    try {
        [AppDomain]::CurrentDomain.add_UnhandledException({
            param($sender,$eventArgs)
            Write-RuntimeDiagnosticEvent -Event 'APPDOMAIN_UNHANDLED_EXCEPTION' -Stage 'runtime' -Success $false -ErrorRecord $eventArgs.ExceptionObject -Level error
        })
    } catch { }
    Write-RuntimeDiagnosticEvent -Event 'TRAY_STARTUP' -Stage 'startup' -Success $true
    Load-AppSettings
    [void](Resolve-PendingLocalePreference)
    $script:LastStatusText = Get-LocalizedString -Key 'Status.Ready'
    Repair-AutostartLauncherIfNeeded

    $script:Popup = New-PopupForm
    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayIcon.Icon = Load-TrayIcon
    $script:TrayIcon.Text = 'Lenovo Boot Selector'
    $script:TrayIcon.Visible = $true

    $context = New-Object LenovoContextMenuStrip
    $context.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $context.ForeColor = $script:ColorPrimary
    $context.Renderer = $script:MenuRenderer
    $context.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $context.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $context.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $context

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $openItem.Text = Get-LocalizedString -Key 'Tray.Open'
    $script:TrayOpenMenuItem = $openItem
    $openItem.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $openItem.ForeColor = $script:ColorAccent
    $openItem.Add_Click({ Show-OrTogglePopup })
    [void]$context.Items.Add($openItem)

    # v0.2.32: Refresh and Standard-Startziel remain in the main popup only.
    # The tray menu is intentionally reduced to quick actions and maintenance.
    $autostartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $autostartItem.Text = Get-LocalizedString -Key 'Settings.Autostart'
    $autostartItem.Add_Click({
        $desired = -not (Get-AutostartInfo).Enabled
        Set-AutostartFromUi -Enabled:$desired
    })
    $script:AutostartMenuItem = $autostartItem
    [void]$context.Items.Add($autostartItem)

    $languageRoot = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageRoot.Text = Get-LocalizedString -Key 'Settings.Language'
    $languageRoot.DropDown = New-Object LenovoDropDownMenu
    $languageRoot.DropDown.TargetWidth = 220
    Initialize-LenovoMenuAppearance -Menu $languageRoot.DropDown
    $languageRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })
    $script:LanguageMenuRoot = $languageRoot

    $languageEnglish = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageEnglish.Text = Get-LocalizedString -Key 'Language.English'
    $languageEnglish.Padding = New-Object System.Windows.Forms.Padding(18, 4, 32, 4)
    $languageEnglish.Add_Click({ [void](Set-LanguageFromUi -Locale 'en-US') })
    $script:LanguageEnglishMenuItem = $languageEnglish
    [void]$languageRoot.DropDownItems.Add($languageEnglish)

    $languageGerman = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageGerman.Text = Get-LocalizedString -Key 'Language.German'
    $languageGerman.Padding = New-Object System.Windows.Forms.Padding(18, 4, 32, 4)
    $languageGerman.Add_Click({ [void](Set-LanguageFromUi -Locale 'de-DE') })
    $script:LanguageGermanMenuItem = $languageGerman
    [void]$languageRoot.DropDownItems.Add($languageGerman)

    Update-LanguageMenuState
    [void]$context.Items.Add($languageRoot)

    $script:DefaultContextRoot = $null
    $script:ManageEntriesMenuItem = $null

    $maintenanceRoot = New-Object System.Windows.Forms.ToolStripMenuItem
    $maintenanceRoot.Text = Get-LocalizedString -Key 'Tray.Maintenance'
    $script:MaintenanceRootMenuItem = $maintenanceRoot
    $maintenanceRoot.DropDown = New-Object LenovoDropDownMenu
    $maintenanceRoot.DropDown.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $maintenanceRoot.DropDown
    $maintenanceRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })

    $setupItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $setupItem.Text = Get-LocalizedString -Key 'Maintenance.Setup'
    $setupItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $setupItem.Add_Click({ Prompt-TaskBrokerInstall })
    $script:TaskBrokerSetupMenuItem = $setupItem
    [void]$maintenanceRoot.DropDownItems.Add($setupItem)

    $removeTasksItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $removeTasksItem.Text = Get-LocalizedString -Key 'Maintenance.Remove'
    $removeTasksItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $removeTasksItem.Add_Click({ Prompt-TaskBrokerRemove })
    $script:TaskBrokerRemoveMenuItem = $removeTasksItem
    [void]$maintenanceRoot.DropDownItems.Add($removeTasksItem)

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $updateCheckItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateCheckItem.Text = Get-LocalizedString -Key 'Update.Check'
    $updateCheckItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $updateCheckItem.Add_Click({ Start-ManualUpdateCheck })
    $script:UpdateCheckMenuItem = $updateCheckItem
    [void]$maintenanceRoot.DropDownItems.Add($updateCheckItem)

    $updateInstallItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateInstallItem.Text = Get-LocalizedString -Key 'Update.Install'
    $updateInstallItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $updateInstallItem.Enabled = $false
    $updateInstallItem.Add_Click({ Start-ManualAppUpdate })
    $script:UpdateInstallMenuItem = $updateInstallItem
    [void]$maintenanceRoot.DropDownItems.Add($updateInstallItem)
    Update-UpdateMenuState

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $diagnosticItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagnosticItem.Text = Get-LocalizedString -Key 'Diagnostics.Save'
    $diagnosticItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $diagnosticItem.Add_Click({ Save-RuntimeDiagnosticsFromUi })
    $script:RuntimeDiagnosticMenuItem = $diagnosticItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)

    [void]$context.Items.Add($maintenanceRoot)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $restartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $restartItem.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartItem.Add_Click({ Restart-Windows })
    $script:RestartMenuItem = $restartItem
    [void]$context.Items.Add($restartItem)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = Get-LocalizedString -Key 'Tray.Exit'
    $script:TrayExitMenuItem = $exitItem
    $exitItem.Add_Click({
        $script:ExitRequested = $true
        try { $context.Close() } catch { }
        try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
        try {
            if ($script:TrayIcon) {
                $script:TrayIcon.Visible = $false
                $script:TrayIcon.Dispose()
            }
        } catch { }
        [System.Windows.Forms.Application]::ExitThread()
    })
    [void]$context.Items.Add($exitItem)

    foreach ($menuItem in $context.Items) {
        if ($menuItem -is [System.Windows.Forms.ToolStripMenuItem]) {
            $menuItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 32, 4)
        }
    }

    $script:TrayIcon.ContextMenuStrip = $context
    [void](Show-PendingUpdateResultOnStartup)
    $script:TrayIcon.Add_MouseClick({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-OrTogglePopup
        }
    })

    # v0.2.26 startup fast path: only inspect local metadata synchronously. Exact
    # Scheduled-Task validation and fresh firmware/storage reads are delegated to
    # the background worker so the tray event loop can become responsive first.
    $metadataCompatible = Test-TaskBrokerMetadataCompatible
    Write-RuntimeDiagnosticEvent -Event 'TASKBROKER_METADATA_COMPATIBILITY' -Stage 'startup' -Success $metadataCompatible -Data (New-RuntimeDiagnosticData @{ brokerPresent = [bool](Test-TaskBrokerInstallationPresent) }) -Level $(if ($metadataCompatible) { 'info' } else { 'warning' })
    if (-not $metadataCompatible) {
        $script:TaskBrokerReadyCached = $false
        $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
        if (Test-TaskBrokerInstallationPresent) {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
        }
        else {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
        }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshing'
    }
    Update-TaskBrokerUiState -Fast | Out-Null
    Update-ManageEntriesUiState
    Update-PopupRows
    if (-not $metadataCompatible) {
        # First-run / incomplete-install UX: expose the central setup/repair CTA
        # immediately without launching UAC until the user explicitly confirms.
        Show-OrTogglePopup
    }

    try {
        if ($metadataCompatible) {
            [void](Load-BootStateFromExistingCache)
            [void](Refresh-SystemDefaultState)
            Complete-LegacyDefaultMigration
            Start-BackgroundBootRefresh -RefreshStorage
        }
    } catch { }
    try { Update-AutostartUi | Out-Null } catch { }
    try { Update-DefaultUi } catch { }

    [System.Windows.Forms.Application]::Run()
}
catch {
    Write-RuntimeDiagnosticEvent -Event 'FATAL_RUNTIME_ERROR' -Stage 'runtime' -Success $false -ErrorRecord $_ -Level error
    $script:RestartAfterFatal = ((Show-FatalMessage $_.Exception.Message) -eq 'retry')
}
finally {
    Write-RuntimeDiagnosticEvent -Event 'SESSION_ENDED' -Stage 'shutdown' -Success $true -Data (New-RuntimeDiagnosticData @{ exitRequested = [bool]$script:ExitRequested; errorEvents = $script:RuntimeDiagnosticsErrorCount })
    if ($script:TaskBrokerInstallTimer) {
        try { $script:TaskBrokerInstallTimer.Stop() } catch { }
        try { $script:TaskBrokerInstallTimer.Dispose() } catch { }
    }
    if ($script:TaskBrokerRemoveTimer) {
        try { $script:TaskBrokerRemoveTimer.Stop() } catch { }
        try { $script:TaskBrokerRemoveTimer.Dispose() } catch { }
    }
    if ($script:UpdateState) {
        try { Stop-UpdateCheckUiWorker } catch { }
        try { Stop-UpdatePrepareUiWorker } catch { }
    }
    $backgroundRefreshContext = $null
    if ($script:BackgroundRefreshState) {
        $backgroundRefreshContext = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
        [void](Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState)
    }
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Timer) {
        try { $backgroundRefreshContext.Timer.Stop() } catch { }
        try { $backgroundRefreshContext.Timer.Dispose() } catch { }
    }
    if ($script:DarkActionTooltip) {
        try { Hide-DarkActionTooltip } catch { }
        try { $script:DarkActionTooltip.Dispose() } catch { }
    }
    if ($script:DarkActionTooltipFont) {
        try { $script:DarkActionTooltipFont.Dispose() } catch { }
    }
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Process) {
        try { $backgroundRefreshContext.Process.Refresh() } catch { }
        try { if (-not $backgroundRefreshContext.Process.HasExited) { $backgroundRefreshContext.Process.Kill() } } catch { }
        try { $backgroundRefreshContext.Process.Dispose() } catch { }
    }
    if ($backgroundRefreshContext) {
        Remove-BackgroundRefreshResultFile -Path ([string]$backgroundRefreshContext.ResultPath)
    }
    if ($script:TrayIcon) {
        $script:TrayIcon.Visible = $false
        $script:TrayIcon.Dispose()
    }
    if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Dispose() }
    if ($mutex) {
        if ($mutexOwned) {
            try { $mutex.ReleaseMutex() } catch { }
            $mutexOwned = $false
        }
        try { $mutex.Dispose() } catch { }
        $mutex = $null
    }
    if ($script:RestartAfterFatal) {
        [void](Start-LenovoBootSelectorHidden)
    }
}
