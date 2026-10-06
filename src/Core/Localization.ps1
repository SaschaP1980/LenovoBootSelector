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
