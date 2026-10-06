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
