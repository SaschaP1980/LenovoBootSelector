#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$HideConsole,
    [switch]$BackgroundRefresh,
    [switch]$BootNextWorker,
    [switch]$DefaultTargetWorker,
    [string]$DefaultTargetGuid,
    [switch]$DefaultTargetClear,
    [string]$DefaultTargetResultPath,
    [string]$DefaultTargetProgressPath,
    [string]$BootNextGuid,
    [string]$BootNextResultPath,
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
            'Action.RefreshBootTargets' = 'Refresh the available boot targets and current boot state.'
            'Tooltip.Customize' = 'Configure boot targets: change their order, visibility and display names.'
            'Tooltip.Settings' = 'Open settings for autostart, language, user preferences, maintenance, updates and diagnostics.'
            'Tooltip.DefaultNavigation' = 'Open the picker to set or clear the persistent default boot target.'
            'Tooltip.Restart' = 'Check the next boot target and open the Windows restart confirmation.'
            'Tooltip.ClosePicker' = 'Close the picker without changing the default boot target.'
            'Tooltip.CloseSettings' = 'Close settings. Actions already applied remain in effect.'
            'Tooltip.Configuration.autostart' = 'Enable or disable automatic startup of Lenovo Boot Selector with Windows.'
            'Tooltip.Configuration.language-de' = 'Switch the application language to German.'
            'Tooltip.Configuration.language-en' = 'Switch the application language to English.'
            'Tooltip.Configuration.system-setup' = 'Open the confirmation to set up, repair or reinitialize system functions.'
            'Tooltip.Configuration.system-remove' = 'Open the confirmation to remove system functions.'
            'Tooltip.Configuration.update-check' = 'Check whether a newer application version is available.'
            'Tooltip.Configuration.update-install' = 'Start the application update process for the available version.'
            'Tooltip.Configuration.diagnostics-save' = 'Save a local diagnostic package for troubleshooting.'
            'Tooltip.Configuration.diagnostics-upload' = 'Open the diagnostic upload workflow to send diagnostic data.'
            'Tooltip.Unavailable' = 'This action is currently unavailable.'
            'Tooltip.NextBoot' = 'Request “{Target}” as the one-time target for the next restart, when available. No immediate restart or persistent default change.'
            'Tooltip.NextBootMenu' = 'Request the Lenovo Boot Menu for the next restart, when available. No immediate restart or persistent default change.'
            'Tooltip.NextBootPending' = 'Selection is being checked or applied. Wait for confirmation before selecting another target.'
            'Tooltip.NextBootSelected' = 'This target is confirmed for the next restart. Selecting it does not restart Windows or change the persistent default.'
            'Tooltip.HiddenType' = 'Hidden — therefore shown in gray.'
            'Tooltip.SetDefault' = 'Set “{Target}” as the persistent default boot target. No immediate restart.'
            'Tooltip.ClearDefault' = 'Remove the persistent default boot target. No immediate restart.'
            'Tooltip.CurrentDefault' = 'Current confirmed persistent default. Selecting it requests the existing default again. No immediate restart.'
            'Popup.NextBootSection' = 'NEXT BOOT'
            'Popup.Customize' = 'CUSTOMIZE'
            'Status.ScrollPositionFailed' = 'The scroll position could not be updated.'
            'Settings.Title' = 'SETTINGS'
            'SystemStatus.Title' = 'System status'
            'SystemStatus.Subtitle' = 'Boot configuration and readiness'
            'SystemStatus.SummaryReady' = 'No action required in the last checks'
            'SystemStatus.SummaryAttention' = 'Action required'
            'SystemStatus.SummaryUnknown' = 'Status not fully verified'
            'SystemStatus.SummaryBusy' = 'Update or operation in progress'
            'SystemStatus.Stored' = 'SAVED DEFAULT TARGET'
            'SystemStatus.Next' = 'NEXT RESTART · FIRMWARE READBACK'
            'SystemStatus.Readiness' = 'SYSTEM FUNCTIONS'
            'SystemStatus.Drift' = 'BOOT TARGET COMPARISON'
            'SystemStatus.Freshness' = 'LAST READ / CHECK'
            'SystemStatus.Unknown' = 'Not verified'
            'SystemStatus.NoDefault' = 'No default configured'
            'SystemStatus.Unavailable' = 'Target unavailable'
            'SystemStatus.FirmwareOrder' = 'Firmware order · no one-time target'
            'SystemStatus.Matches' = 'Matches saved default'
            'SystemStatus.Differs' = 'Differs from saved default · allowed'
            'SystemStatus.Verified' = 'Last confirmed firmware read'
            'SystemStatus.Ready' = 'Ready · configuration checked'
            'SystemStatus.Checking' = 'Checking readiness …'
            'SystemStatus.SetupRequired' = 'Setup required'
            'SystemStatus.RepairRequired' = 'Repair required'
            'SystemStatus.ReinitializeRequired' = 'New setup required'
            'SystemStatus.Busy' = 'System functions are being maintained'
            'SystemStatus.SetupHint' = 'Open Further settings to set up system functions.'
            'SystemStatus.RepairHint' = 'Open Further settings to repair system functions.'
            'SystemStatus.ReinitializeHint' = 'Open Further settings to set up system functions again.'
            'SystemStatus.DriftNone' = 'No changes detected in last comparison'
            'SystemStatus.DriftChanged' = 'Changes detected in last comparison'
            'SystemStatus.RefreshFailed' = 'Last refresh failed · previous evidence only'
            'SystemStatus.RefreshRunning' = 'Refresh in progress'
            'SystemStatus.Pending' = 'Target change in progress · not yet confirmed'
            'SystemStatus.ManagerTime' = 'Next target: {Time}'
            'SystemStatus.EntriesTime' = 'Boot targets: {Time}'
            'SystemStatus.ReadinessTime' = 'System functions: {Time}'
            'SystemStatus.TimeUnknown' = 'unknown'
            'SystemStatus.Age' = '{Time} · {Minutes} min ago'
            'Settings.More' = 'Further settings'
            'Settings.General' = 'GENERAL'
            'Settings.MoreSubtitle' = 'Manage application and system functions'
            'Settings.LanguageSelected' = 'Selected language'
            'Settings.LanguageNotSelected' = 'Not selected'
            'Settings.Detail.autostart' = 'Start the application automatically'
            'Settings.Detail.system-setup' = 'Set up or restore system functions'
            'Settings.Detail.system-remove' = 'Uninstall system functions'
            'Settings.Detail.update-check' = 'Check for an available update'
            'Settings.Detail.update-install' = 'Install the available update'
            'Settings.Detail.diagnostics-save' = 'Create a local diagnostic package'
            'Settings.Detail.diagnostics-upload' = 'Send diagnostic data'
            'Settings.Updates' = 'UPDATES'
            'Settings.Diagnostics' = 'DIAGNOSTICS'
            'Preferences.Menu' = 'User preferences'
            'Preferences.ExportIntro' = 'Save personal preferences'
            'Preferences.ExportFormat' = 'Portable JSON file'
            'Preferences.ExportCountLabel' = 'Boot targets included'
            'Preferences.TargetCount' = '{Count} boot targets'
            'Preferences.UnchangedHeading' = 'The following settings remain unchanged'
            'Preferences.UnavailableCount' = 'Unavailable: {Count}'
            'Preferences.AliasSkippedCount' = 'Aliases skipped: {Count}'
            'Preferences.IncludedHeading' = 'INCLUDED PREFERENCES'
            'Preferences.IncludedLanguage' = 'Selected language'
            'Preferences.IncludedAliases' = 'Individual aliases'
            'Preferences.IncludedVisibility' = 'Boot target visibility'
            'Preferences.IncludedOrder' = 'Boot target order'
            'Preferences.IncludedScope' = 'Included: language, aliases, visibility and order of available entries.'
            'Preferences.ExcludedHeading' = 'Not included in the backup'
            'Preferences.ExcludedScope' = 'Windows autostart, default boot target, one-time boot target for the next restart, system configuration, privileged tasks and diagnostic data.'
            'Preferences.PrivacyHeading' = 'Local and private backup'
            'Preferences.PrivacyBody' = 'The file may contain personal aliases and GUIDs. No automatic upload takes place.'
            'Preferences.UnavailableNote' = 'Unavailable saved entries are not exported or restored; their local metadata remains unchanged.'
            'Preferences.MetricMatched' = 'Successfully matched'
            'Preferences.MetricChanged' = 'Changed'
            'Preferences.MetricSkipped' = 'No match'
            'Preferences.MetricLocalOnly' = 'Local only'
            'Preferences.NoChange' = 'No change'
            'Preferences.LanguageChanged' = 'Language will change'
            'Preferences.LanguageBefore' = 'Current language'
            'Preferences.LanguageAfter' = 'After import'
            'Preferences.ReconcileHeading' = 'Safe matching'
            'Preferences.SystemUnchanged' = 'System functions, the default boot target, BootNext and autostart remain unchanged.'
            'Preferences.EntriesHeading' = 'BOOT TARGETS'
            'Preferences.AdditionalCounts' = 'Unavailable: {Unavailable} · Alias skipped: {Aliases}'
            'Preferences.FilterAll' = 'All'
            'Preferences.FilterChanged' = 'Changed'
            'Preferences.FilterSkipped' = 'Skipped'
            'Preferences.FilterLocalOnly' = 'Local only'
            'Preferences.FilterUnavailable' = 'Unavailable'
            'Preferences.PageInfo' = 'Page {Page} of {Total} · {Count} entries'
            'Preferences.DetailPage' = 'Details · page {Page} of {Total}'
            'Preferences.Previous' = 'Previous'
            'Preferences.Next' = 'Next'
            'Preferences.NoRows' = 'No entries in this view.'
            'Preferences.RowChanged' = 'Matched · changed'
            'Preferences.RowUnchanged' = 'Matched · unchanged'
            'Preferences.UnavailableTitle' = 'Unavailable locally'
            'Preferences.UnmatchedTitle' = 'Unmatched incoming boot target'
            'Preferences.ShowDetails' = 'Show details'
            'Preferences.HideDetails' = 'Hide details'
            'Preferences.Heading' = 'USER PREFERENCES'
            'Preferences.Export' = 'Export preferences'
            'Preferences.Import' = 'Import preferences'
            'Settings.Detail.preferences-export' = 'Save personal settings as JSON'
            'Settings.Detail.preferences-import' = 'Preview and restore preferences'
            'Tooltip.Configuration.preferences-export' = 'Save language, aliases, visibility and order for currently available boot entries to a local JSON file. No system settings or diagnostics.'
            'Tooltip.Configuration.preferences-import' = 'Preview an exact-GUID match and explicitly restore personal settings. No firmware or system changes.'
            'Preferences.FileFilter' = 'Preference JSON files (*.json)|*.json'
            'Preferences.ChooseExport' = 'Choose export file'
            'Preferences.ChooseImport' = 'Choose import file'
            'Preferences.PreviewTitle' = 'Import preview'
            'Preferences.Apply' = 'Apply preferences'
            'Preferences.Scope' = 'Included: language, aliases, visibility and order for available entries. Excluded: autostart, default target, BootNext, privileged tasks, system and diagnostic data. GUIDs and aliases may contain identifying information. No automatic upload.'
            'Preferences.ExportSummary' = 'Entries included: {Count}. Unavailable saved entries are not exported.'
            'Preferences.ExportConfirm' = 'Choose file…'
            'Preferences.ReconcileWarning' = 'Only exact GUID matches are restored. Equal GUIDs are not proof of identical hardware. Check the current local targets and changes before applying. Unmatched entries are skipped. Local entries absent from the file are preserved.'
            'Preferences.PreviewLanguage' = 'Language: {Before} → {After}'
            'Preferences.PreviewCounts' = 'Matched: {Matched} · Unmatched: {Unmatched} · Local only: {Local}'
            'Preferences.Matched' = 'MATCHED'
            'Preferences.Unmatched' = 'SKIPPED — no exact local GUID match'
            'Preferences.LocalOnly' = 'LOCAL ONLY — unchanged'
            'Preferences.Unavailable' = 'Unavailable saved metadata (preserved locally, excluded from restore):'
            'Preferences.AliasChange' = 'Alias: {Before} → {After}'
            'Preferences.AliasSkipped' = 'Imported alias exceeds the current limit; existing alias preserved.'
            'Preferences.VisibilityChange' = 'Visibility: {Before} → {After}'
            'Preferences.OrderChange' = 'Position: {Before} → {After}'
            'Preferences.Visible' = 'visible'
            'Preferences.Hidden' = 'hidden'
            'Preferences.NoAlias' = '(no alias)'
            'Preferences.None' = '(none)'
            'Preferences.ErrorTitle' = 'Preferences unavailable'
            'Preferences.ErrorInvalid' = 'The file is invalid, unreadable, too large or uses an unsupported format. Choose a valid preference JSON file. No settings were changed.'
            'Preferences.ErrorLocal' = 'Local settings cannot be safely used. Resolve any damaged, changed or unsupported settings file, or confirm the pending language choice, then restart or reload the app. No settings were changed.'
            'Preferences.ErrorStale' = 'The local settings or boot-entry list changed after the preview. Open the workflow again and review a new preview. No settings were changed.'
            'Preferences.ErrorBusy' = 'Wait for boot-target refresh or other operations to finish, exit Manage Entries and check system readiness. No settings were changed.'
            'Preferences.ErrorDestination' = 'Select a JSON file outside the internal settings directory. An existing file must already be a valid preference export; other files will not be overwritten.'
            'Preferences.ErrorSave' = 'The file could not be saved. Check permissions, free space and open file handles, then try again. No new settings were applied.'
            'Preferences.ErrorUncertain' = 'The file operation could not be verified. Do not repeat the import until the local settings file has been checked and the app reloaded. Settings persistence is blocked after an uncertain import.'
            'Preferences.ExportUncertain' = 'The export file could not be verified. Check the chosen file before using it. Local application settings were not changed.'
            'Preferences.ErrorLayout' = 'The preview does not fit the available work area. Use a larger work area or lower display scaling and try again. No settings were changed.'
            'Preferences.Exported' = 'Preferences saved'
            'Preferences.ExportSuccess' = 'The preference JSON file was saved locally. Keep it private if it contains personal aliases or GUIDs.'
            'Preferences.Imported' = 'Preferences restored'
            'Preferences.ImportSuccess' = 'The confirmed presentation preferences were saved. System settings and boot targets were not changed.'
            'Preferences.RefreshWarning' = 'Preferences were saved, but the display could not be refreshed completely. Restart the application to see the saved settings.'
            'Settings.DefaultPickerCurrent' = 'Current default: {Target}'
            'Settings.DefaultPickerNoneHint' = 'Do not configure a persistent default'
            'Settings.DefaultPickerSelected' = 'Current persistent default'
            'Settings.Autostart' = 'Start with Windows'
            'Settings.DefaultTarget' = 'Default boot target'
            'Settings.NoDefaultTarget' = 'No default target'
            'Settings.DefaultTargetUnavailable' = 'Boot target unavailable'
            'BootNext.Unknown' = 'Next boot target unknown'
            'BootNext.UnknownLine' = 'Next restart: unknown · check before restarting'
            'BootNext.FirmwareOrderLine' = 'Next: firmware order · default: {Default}'
            'BootNext.AlignedLine' = 'Next: {Next} · matches default'
            'BootNext.DifferentLine' = 'Next: {Next} · default: {Default}'
            'BootNext.UnavailableLine' = 'Next boot target unavailable'
            'BootNext.UseDefaultHint' = 'Replaces the one-time next-boot target with the saved default “{Default}”. Does not restart the PC.'
            'BootNext.UseDefaultOnce' = 'Reset to default target'
            'BootNext.LayoutUnknown' = 'Next restart · unverified; check target'
            'BootNext.LayoutFirmwareOrder' = 'Verified · firmware order (no one-time target)'
            'BootNext.LayoutAligned' = 'Verified · matches default: {Next}'
            'BootNext.LayoutDifferent' = 'Verified · differs from default: {Next}'
            'BootNext.LayoutUnavailable' = 'Next restart · selected target unavailable'
            'BootNext.DefaultApplied' = 'Stored default selected for the next restart.'
            'BootNext.DefaultApplyFailed' = 'The next restart target could not be changed. Please check the actual target.'
            'BootNext.SelectionPending' = 'Setting next boot target…'
            'BootNext.RowPendingHint' = 'Setting next boot target · not yet confirmed'
            'BootNext.RowSelectedHint' = 'Confirmed next boot target'
            'BootNext.SelectionPendingFooter' = 'Setting {Target} · not yet verified'
            'BootNext.SelectionFailed' = 'Boot target was not confirmed. Please check the actual next boot.'
            'BootNext.CheckFailed' = 'The current firmware next-boot target could not be verified. No restart was started.'
            'Status.Checking' = 'Checking …'
            'Action.RestartWindows' = 'Restart Windows'
            'Status.NextTargetDefaultOrder' = 'Next target: default order'
            'Manage.Section' = 'ADJUST BOOT TARGETS'
            'Manage.Title' = 'CHANGES'
            'Manage.Hint' = 'Drag to sort · Click to show/hide'
            'Manage.SubHint' = 'Pencil to rename · Leave empty = original name'
            'Manage.Save' = 'Save changes'
            'Manage.Undo' = 'Undo'
            'Manage.UndoDone' = 'Last change undone.'
            'Manage.UndoTargetUnavailable' = 'A boot target disappeared. Its unfinished edit and Undo history were discarded; other draft edits remain.'
            'Manage.UndoInventoryChanged' = 'Boot targets changed. Undo history was cleared; current edits were retained.'
            'Manage.StatusEditing' = 'Customize boot targets · Drag to sort · Click to show/hide · Pencil for display name'
            'Manage.StatusSaved' = 'Boot-target changes were saved.'
            'Manage.StatusDiscarded' = 'Changes were discarded.'
            'Autostart.Enabled' = 'Autostart is enabled.'
            'Autostart.Disabled' = 'Autostart is disabled.'
            'Autostart.ErrorHeading' = 'The setting could not be changed.'
            'Default.SaveErrorHeading' = 'The default boot target could not be saved.'
            'Default.SaveErrorMessage' = 'Please try again. If the problem persists, open Maintenance → Repair system functions.'
            'Default.ChangeSaving' = 'Saving …'
            'Default.ChangeVerifying' = 'Verifying …'
            'Default.ChangeSavingFooter' = 'Saving default: {Target} · not yet confirmed'
            'Default.ChangeVerifyingFooter' = 'Verifying default and next boot: {Target} …'
            'Default.ChangePartialHeading' = 'Default saved; next boot not verified'
            'Default.ChangePartial' = 'The stored default was confirmed, but the next boot could not be verified. Check it before restarting.'
            'Default.ChangeUnknown' = 'Default target not verified'
            'Status.NewBootTargetDetected' = 'New boot target detected · Reinitialize system functions.'
            'Status.BootTargetsChanged' = 'Boot targets changed · Reinitialize system functions.'
            'Status.SystemFunctionsRepairRequired' = 'System functions need to be repaired.'
            'Status.SystemFunctionsSetupRequired' = 'System functions need to be set up.'
            'Header.Refreshing' = 'Updating boot targets…'
            'Header.InitializingApplication' = 'Initializing application …'
            'Header.RefreshingApplication' = 'Refreshing application state …'
            'Update.Available' = 'New app version available'
            'Tray.Open' = 'Open Lenovo Boot Selector'
            'Tray.Maintenance' = 'Maintenance'
            'Maintenance.Setup' = 'Set up system functions…'
            'Maintenance.Remove' = 'Remove system functions…'
            'Update.Check' = 'Check for new version…'
            'Update.Install' = 'Update app…'
            'Diagnostics.Save' = 'Save diagnostics…'
            'Diagnostics.Upload' = 'Upload diagnostics…'
            'Boot.OtherTarget' = 'Other boot target'
            'Boot.OtherTargetTooltip' = 'Boot target type: Other boot target · Type color: Gray'
            'Boot.MenuTitle' = 'Lenovo Boot Menu'
            'Boot.MenuSubtitle' = 'Open the boot menu on the next startup'
            'Boot.MenuTooltip' = 'Boot target type: Lenovo Boot Menu · Type color: Red'
            'Boot.Nvme1Title' = 'NVMe SSD 1'
            'Boot.Nvme2Title' = 'NVMe SSD 2'
            'Boot.NoDrive' = 'No drive detected'
            'Boot.InternalSsd' = 'Internal SSD'
            'Boot.SecondInternalSsd' = 'Second internal SSD'
            'Boot.InternalSsdTooltip' = 'Boot target type: Internal SSD · Type color: Blue'
            'Boot.UsbTooltip' = 'Boot target type: USB drive · Type color: Yellow'
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
            'Boot.PxeTooltip' = 'Boot target type: Network boot · Type color: Purple'
            'Boot.LenovoRecoveryTitle' = 'Lenovo recovery'
            'Boot.LenovoRecoverySubtitle' = 'Recovery over the network'
            'Boot.CyanTooltip' = 'Boot target type: Lenovo or corporate network · Type color: Cyan'
            'Boot.CorporateTitle' = 'Corporate network boot'
            'Boot.CorporateSubtitle' = 'Boot over the corporate network'
            'Boot.OtherDriveTitle' = 'Other drive'
            'Boot.OtherDriveSubtitle' = 'Other detected drive'
            'Boot.OtherDriveTooltip' = 'Boot target type: Other drive · Type color: Gray'
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
            'Manage.ReorderHint' = 'Drag to change the order'
            'Manage.KeyboardHint' = 'Ctrl+↑/↓ · Space · Ctrl+E'
            'Manage.KeyboardPositionHint' = '{Position}/{Count} · Ctrl+↑/↓ · Space · Ctrl+E'
            'Manage.KeyboardPosition' = 'Position {Position} of {Count}'
            'Manage.KeyboardInstructions' = 'Arrows and Page Up/Down navigate. Ctrl+arrows/Page Up/Page Down/Home/End reorder. Space shows or hides. Ctrl+E edits display name. Tab moves to actions.'
            'Manage.ClearAliasHint' = 'Clear display name'
            'Manage.AliasCue' = 'Use original name'
            'Manage.AliasFieldHint' = 'Empty: use original name'
            'Manage.AliasLimitExceeded' = 'Display name: maximum {Limit} characters'
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
            'Update.Later' = 'Later'
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
            'Diagnostics.Uploading' = 'Uploading diagnostics…'
            'Diagnostics.UploadedTitle' = 'Diagnostics uploaded'
            'Diagnostics.UploadedHeading' = 'The diagnostic package was transmitted.'
            'Diagnostics.UploadedMessage' = 'The ZIP was stored privately for troubleshooting.'
            'Diagnostics.UploadedWithId' = "The ZIP was stored privately.`r`nDiagnosis ID: {DiagnosisId}`r`nUse this ID in ChatGPT for analysis."
            'Diagnostics.CopyId' = 'Copy Diagnosis ID'
            'Diagnostics.Copied' = 'Copied ✓'
            'Diagnostics.CopyFailed' = 'Copy failed'
            'Diagnostics.UploadNoLocalPackageMessage' = 'The upload could not be started. A locally saved package could not be confirmed. Save diagnostics again before retrying.'
            'Diagnostics.IdCaption' = 'DIAGNOSIS ID'
            'Diagnostics.IdHint' = 'The ZIP was stored privately. Use this ID in ChatGPT for analysis.'
            'Diagnostics.PathCaption' = 'LOCATION'
            'Diagnostics.PathHint' = 'The diagnostic package is saved locally.'
            'Maintenance.Dialog.Changes' = 'WHAT CHANGES'
            'Maintenance.Dialog.Retained' = 'WHAT IS KEPT'
            'Diagnostics.ReferenceMissingTitle' = 'Upload accepted - ID unavailable'
            'Diagnostics.ReferenceMissingHeading' = 'The server accepted the upload.'
            'Diagnostics.ReferenceMissingMessage' = 'The reference could not be verified. The ZIP may be stored. Do not immediately upload again.'
            'Diagnostics.UploadFailedTitle' = 'Upload unsuccessful'
            'Diagnostics.UploadFailedHeading' = 'The diagnostics could not be uploaded.'
            'Diagnostics.UploadFailedMessage' = 'The package remains saved locally. Please try again later.'
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
            'Default.SystemSavedStatus' = 'System default saved: {Name} · restored at the next Windows system startup (no extra delay).'
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
            'Action.RefreshBootTargets' = 'Verfügbare Startziele und aktuellen Startzustand erneut ermitteln.'
            'Tooltip.Customize' = 'Startziele konfigurieren: Reihenfolge, Sichtbarkeit und Anzeigenamen ändern.'
            'Tooltip.Settings' = 'Einstellungen für Autostart, Sprache, Wartung, Updates und Diagnose öffnen.'
            'Tooltip.DefaultNavigation' = 'Auswahl öffnen, um das dauerhafte Standard-Startziel festzulegen oder zu entfernen.'
            'Tooltip.Restart' = 'Nächstes Startziel prüfen und die Bestätigung für den Windows-Neustart öffnen.'
            'Tooltip.ClosePicker' = 'Auswahl schließen, ohne das Standard-Startziel zu ändern.'
            'Tooltip.CloseSettings' = 'Einstellungen schließen. Bereits übernommene Änderungen bleiben wirksam.'
            'Tooltip.Configuration.autostart' = 'Automatischen Start von Lenovo Boot Selector mit Windows ein- oder ausschalten.'
            'Tooltip.Configuration.language-de' = 'Die Anwendungssprache auf Deutsch umstellen.'
            'Tooltip.Configuration.language-en' = 'Die Anwendungssprache auf Englisch umstellen.'
            'Tooltip.Configuration.system-setup' = 'Bestätigung zum Einrichten, Reparieren oder erneuten Initialisieren der Systemfunktionen öffnen.'
            'Tooltip.Configuration.system-remove' = 'Bestätigung zum Entfernen der Systemfunktionen öffnen.'
            'Tooltip.Configuration.update-check' = 'Prüfen, ob eine neuere Anwendungsversion verfügbar ist.'
            'Tooltip.Configuration.update-install' = 'Aktualisierung der Anwendung auf die verfügbare Version starten.'
            'Tooltip.Configuration.diagnostics-save' = 'Ein lokales Diagnosepaket zur Fehleranalyse speichern.'
            'Tooltip.Configuration.diagnostics-upload' = 'Diagnose-Upload öffnen, um Diagnosedaten zu übermitteln.'
            'Tooltip.Unavailable' = 'Diese Aktion ist derzeit nicht verfügbar.'
            'Tooltip.NextBoot' = '„{Target}“ einmalig für den nächsten Neustart auswählen, sofern verfügbar. Kein sofortiger Neustart und keine Änderung des dauerhaften Standardziels.'
            'Tooltip.NextBootMenu' = 'Das Lenovo Boot-Menü einmalig für den nächsten Neustart auswählen, sofern verfügbar. Kein sofortiger Neustart und keine Änderung des dauerhaften Standardziels.'
            'Tooltip.NextBootPending' = 'Auswahl wird geprüft oder übernommen. Vor einer weiteren Auswahl auf die Bestätigung warten.'
            'Tooltip.NextBootSelected' = 'Dieses Ziel ist für den nächsten Neustart bestätigt. Die Auswahl startet Windows nicht neu und ändert das dauerhafte Standardziel nicht.'
            'Tooltip.HiddenType' = 'Ausgeblendet – daher grau dargestellt.'
            'Tooltip.SetDefault' = '„{Target}“ als dauerhaftes Standard-Startziel festlegen. Kein sofortiger Neustart.'
            'Tooltip.ClearDefault' = 'Dauerhaftes Standard-Startziel entfernen. Kein sofortiger Neustart.'
            'Tooltip.CurrentDefault' = 'Aktuell bestätigtes dauerhaftes Standard-Startziel. Eine Auswahl fordert das bestehende Standardziel erneut an. Kein sofortiger Neustart.'
            'Popup.NextBootSection' = 'NÄCHSTER START'
            'Popup.Customize' = 'ANPASSEN'
            'Status.ScrollPositionFailed' = 'Scrollposition konnte nicht aktualisiert werden.'
            'Settings.Title' = 'EINSTELLUNGEN'
            'SystemStatus.Title' = 'Systemstatus'
            'SystemStatus.Subtitle' = 'Boot-Konfiguration und Einsatzbereitschaft'
            'SystemStatus.SummaryReady' = 'Bei letzter Prüfung kein Handlungsbedarf'
            'SystemStatus.SummaryAttention' = 'Handlungsbedarf'
            'SystemStatus.SummaryUnknown' = 'Status nicht vollständig bestätigt'
            'SystemStatus.SummaryBusy' = 'Aktualisierung oder Vorgang läuft'
            'SystemStatus.Stored' = 'GESPEICHERTES STANDARD-STARTZIEL'
            'SystemStatus.Next' = 'NÄCHSTER START · FIRMWARE-AUSLESUNG'
            'SystemStatus.Readiness' = 'SYSTEMFUNKTIONEN'
            'SystemStatus.Drift' = 'ABGLEICH DER BOOT-ZIELE'
            'SystemStatus.Freshness' = 'LETZTE AUSLESUNG / PRÜFUNG'
            'SystemStatus.Unknown' = 'Nicht bestätigt'
            'SystemStatus.NoDefault' = 'Kein Standard-Startziel festgelegt'
            'SystemStatus.Unavailable' = 'Ziel nicht verfügbar'
            'SystemStatus.FirmwareOrder' = 'Firmware-Reihenfolge · kein Einmalziel'
            'SystemStatus.Matches' = 'Entspricht dem Standard-Startziel'
            'SystemStatus.Differs' = 'Weicht vom Standard ab · zulässig'
            'SystemStatus.Verified' = 'Zuletzt aus Firmware bestätigt'
            'SystemStatus.Ready' = 'Bereit · Konfiguration geprüft'
            'SystemStatus.Checking' = 'Einsatzbereitschaft wird geprüft …'
            'SystemStatus.SetupRequired' = 'Einrichtung erforderlich'
            'SystemStatus.RepairRequired' = 'Reparatur erforderlich'
            'SystemStatus.ReinitializeRequired' = 'Neueinrichtung erforderlich'
            'SystemStatus.Busy' = 'Systemfunktionen werden bearbeitet'
            'SystemStatus.SetupHint' = 'Öffne „Weitere Einstellungen“, um die Systemfunktionen einzurichten.'
            'SystemStatus.RepairHint' = 'Öffne „Weitere Einstellungen“, um die Systemfunktionen zu reparieren.'
            'SystemStatus.ReinitializeHint' = 'Öffne „Weitere Einstellungen“, um die Systemfunktionen neu einzurichten.'
            'SystemStatus.DriftNone' = 'Beim letzten Abgleich keine Änderungen erkannt'
            'SystemStatus.DriftChanged' = 'Beim letzten Abgleich Änderungen erkannt'
            'SystemStatus.RefreshFailed' = 'Letzte Aktualisierung fehlgeschlagen · frühere Nachweise'
            'SystemStatus.RefreshRunning' = 'Aktualisierung läuft'
            'SystemStatus.Pending' = 'Startziel wird geändert · noch nicht bestätigt'
            'SystemStatus.ManagerTime' = 'Nächstes Startziel: {Time}'
            'SystemStatus.EntriesTime' = 'Boot-Ziele: {Time}'
            'SystemStatus.ReadinessTime' = 'Systemfunktionen: {Time}'
            'SystemStatus.TimeUnknown' = 'unbekannt'
            'SystemStatus.Age' = '{Time} · vor {Minutes} Min.'
            'Settings.More' = 'Weitere Einstellungen'
            'Settings.General' = 'ALLGEMEIN'
            'Settings.MoreSubtitle' = 'Anwendung und Systemfunktionen verwalten'
            'Settings.LanguageSelected' = 'Ausgewählte Sprache'
            'Settings.LanguageNotSelected' = 'Nicht ausgewählt'
            'Settings.Detail.autostart' = 'Anwendung automatisch starten'
            'Settings.Detail.system-setup' = 'Systemfunktionen einrichten oder reparieren'
            'Settings.Detail.system-remove' = 'Systemfunktionen deinstallieren'
            'Settings.Detail.update-check' = 'Verfügbarkeit eines Updates prüfen'
            'Settings.Detail.update-install' = 'Verfügbares Update installieren'
            'Settings.Detail.diagnostics-save' = 'Lokales Diagnosepaket erstellen'
            'Settings.Detail.diagnostics-upload' = 'Diagnosedaten übermitteln'
            'Settings.Updates' = 'UPDATES'
            'Settings.Diagnostics' = 'DIAGNOSE'
            'Preferences.Menu' = 'Benutzereinstellungen'
            'Preferences.ExportIntro' = 'Persönliche Einstellungen sichern'
            'Preferences.ExportFormat' = 'Portables JSON-Dateiformat'
            'Preferences.ExportCountLabel' = 'Enthaltene Startziele'
            'Preferences.TargetCount' = '{Count} Startziele'
            'Preferences.UnchangedHeading' = 'Folgende Einstellungen bleiben unverändert'
            'Preferences.UnavailableCount' = 'Nicht verfügbar: {Count}'
            'Preferences.AliasSkippedCount' = 'Übersprungene Aliase: {Count}'
            'Preferences.IncludedHeading' = 'ENTHALTENE EINSTELLUNGEN'
            'Preferences.IncludedLanguage' = 'Ausgewählte Sprache'
            'Preferences.IncludedAliases' = 'Individuelle Aliase'
            'Preferences.IncludedVisibility' = 'Sichtbarkeit der Startziele'
            'Preferences.IncludedOrder' = 'Reihenfolge der Startziele'
            'Preferences.IncludedScope' = 'Enthalten: Sprache, Aliase, Sichtbarkeit und Reihenfolge verfügbarer Startziele.'
            'Preferences.ExcludedHeading' = 'Nicht Bestandteil der Sicherung'
            'Preferences.ExcludedScope' = 'Windows-Autostart, Standard-Startziel, einmaliges Startziel für den nächsten Neustart, Systemkonfiguration, privilegierte Aufgaben und Diagnosedaten.'
            'Preferences.PrivacyHeading' = 'Lokale und private Sicherung'
            'Preferences.PrivacyBody' = 'Die Datei kann persönliche Aliase und GUIDs enthalten. Es erfolgt kein automatischer Upload.'
            'Preferences.UnavailableNote' = 'Nicht verfügbare gespeicherte Startziele werden nicht exportiert oder übernommen; ihre lokalen Metadaten bleiben erhalten.'
            'Preferences.MetricMatched' = 'Erfolgreich zugeordnet'
            'Preferences.MetricChanged' = 'Geändert'
            'Preferences.MetricSkipped' = 'Ohne Treffer'
            'Preferences.MetricLocalOnly' = 'Nur lokal'
            'Preferences.NoChange' = 'Keine Änderung'
            'Preferences.LanguageChanged' = 'Sprache wird geändert'
            'Preferences.LanguageBefore' = 'Aktuelle Sprache'
            'Preferences.LanguageAfter' = 'Nach dem Import'
            'Preferences.ReconcileHeading' = 'Sichere Zuordnung'
            'Preferences.SystemUnchanged' = 'Systemfunktionen, Standard-Startziel, BootNext und Autostart bleiben unverändert.'
            'Preferences.EntriesHeading' = 'STARTZIELE'
            'Preferences.AdditionalCounts' = 'Nicht verfügbar: {Unavailable} · Alias übersprungen: {Aliases}'
            'Preferences.FilterAll' = 'Alle'
            'Preferences.FilterChanged' = 'Geändert'
            'Preferences.FilterSkipped' = 'Übersprungen'
            'Preferences.FilterLocalOnly' = 'Nur lokal'
            'Preferences.FilterUnavailable' = 'Nicht verfügbar'
            'Preferences.PageInfo' = 'Seite {Page} von {Total} · {Count} Einträge'
            'Preferences.DetailPage' = 'Details · Seite {Page} von {Total}'
            'Preferences.Previous' = 'Zurück'
            'Preferences.Next' = 'Weiter'
            'Preferences.NoRows' = 'Keine Einträge in dieser Ansicht.'
            'Preferences.RowChanged' = 'Übereinstimmend · geändert'
            'Preferences.RowUnchanged' = 'Übereinstimmend · unverändert'
            'Preferences.UnavailableTitle' = 'Lokal nicht verfügbar'
            'Preferences.UnmatchedTitle' = 'Nicht zugeordnetes Startziel'
            'Preferences.ShowDetails' = 'Details anzeigen'
            'Preferences.HideDetails' = 'Details ausblenden'
            'Preferences.Heading' = 'BENUTZEREINSTELLUNGEN'
            'Preferences.Export' = 'Einstellungen exportieren'
            'Preferences.Import' = 'Einstellungen importieren'
            'Settings.Detail.preferences-export' = 'Persönliche Einstellungen sichern'
            'Settings.Detail.preferences-import' = 'Gesicherte Einstellungen wiederherstellen'
            'Tooltip.Configuration.preferences-export' = 'Sprache, Aliase, Sichtbarkeit und Reihenfolge verfügbarer Startziele lokal als JSON sichern. Keine Systemkonfiguration oder Diagnose.'
            'Tooltip.Configuration.preferences-import' = 'Exakte GUID-Zuordnung prüfen und persönliche Einstellungen nach Bestätigung wiederherstellen. Keine Firmware- oder Systemänderungen.'
            'Preferences.FileFilter' = 'Einstellungsdateien (*.json)|*.json'
            'Preferences.ChooseExport' = 'Exportdatei auswählen'
            'Preferences.ChooseImport' = 'Importdatei auswählen'
            'Preferences.PreviewTitle' = 'Importvorschau'
            'Preferences.Apply' = 'Einstellungen übernehmen'
            'Preferences.Scope' = 'Enthalten: Sprache, Aliase, Sichtbarkeit und Reihenfolge verfügbarer Einträge. Ausgeschlossen: Autostart, Standard-Startziel, BootNext, privilegierte Aufgaben, System- und Diagnosedaten. GUIDs und Aliase können identifizierende Angaben enthalten. Kein automatischer Upload.'
            'Preferences.ExportSummary' = 'Enthaltene Einträge: {Count}. Nicht verfügbare gespeicherte Einträge werden nicht exportiert.'
            'Preferences.ExportConfirm' = 'Datei auswählen…'
            'Preferences.ReconcileWarning' = 'Nur exakte GUID-Übereinstimmungen werden übernommen. Gleiche GUIDs beweisen keine identische Hardware. Prüfe die aktuellen lokalen Startziele und Änderungen vor dem Übernehmen. Nicht passende Einträge werden übersprungen. Lokale Einträge ohne Dateieintrag bleiben erhalten.'
            'Preferences.PreviewLanguage' = 'Sprache: {Before} → {After}'
            'Preferences.PreviewCounts' = 'Übereinstimmend: {Matched} · Ohne Treffer: {Unmatched} · Nur lokal: {Local}'
            'Preferences.Matched' = 'ÜBEREINSTIMMEND'
            'Preferences.Unmatched' = 'ÜBERSPRUNGEN — keine exakte lokale GUID'
            'Preferences.LocalOnly' = 'NUR LOKAL — unverändert'
            'Preferences.Unavailable' = 'Nicht verfügbare gespeicherte Metadaten (lokal erhalten, vom Import ausgeschlossen):'
            'Preferences.AliasChange' = 'Alias: {Before} → {After}'
            'Preferences.AliasSkipped' = 'Importierter Alias überschreitet die aktuelle Längengrenze; bisheriger Alias bleibt erhalten.'
            'Preferences.VisibilityChange' = 'Sichtbarkeit: {Before} → {After}'
            'Preferences.OrderChange' = 'Position: {Before} → {After}'
            'Preferences.Visible' = 'sichtbar'
            'Preferences.Hidden' = 'ausgeblendet'
            'Preferences.NoAlias' = '(kein Alias)'
            'Preferences.None' = '(keine)'
            'Preferences.ErrorTitle' = 'Einstellungen nicht verfügbar'
            'Preferences.ErrorInvalid' = 'Die Datei ist ungültig, nicht lesbar, zu groß oder verwendet ein nicht unterstütztes Format. Wähle eine gültige Einstellungsdatei. Keine Einstellungen wurden geändert.'
            'Preferences.ErrorLocal' = 'Die lokalen Einstellungen können nicht sicher verwendet werden. Behebe beschädigte, geänderte oder nicht unterstützte Einstellungen bzw. bestätige die ausstehende Sprachauswahl. Starte die Anwendung neu oder lade sie erneut. Keine Einstellungen wurden geändert.'
            'Preferences.ErrorStale' = 'Die lokalen Einstellungen oder Startziele haben sich nach der Vorschau geändert. Öffne den Vorgang erneut und prüfe die neue Vorschau. Keine Einstellungen wurden geändert.'
            'Preferences.ErrorBusy' = 'Warte auf das Ende der Startzielaktualisierung und anderer Vorgänge, verlasse die Eintragsverwaltung und prüfe die Systembereitschaft. Keine Einstellungen wurden geändert.'
            'Preferences.ErrorDestination' = 'Wähle eine JSON-Datei außerhalb des internen Einstellungsordners. Eine vorhandene Datei muss bereits ein gültiger Einstellungsexport sein; andere Dateien werden nicht überschrieben.'
            'Preferences.ErrorSave' = 'Die Datei konnte nicht gespeichert werden. Prüfe Berechtigungen, freien Speicher und geöffnete Dateizugriffe. Es wurden keine neuen Einstellungen übernommen.'
            'Preferences.ErrorUncertain' = 'Der Dateivorgang konnte nicht verifiziert werden. Wiederhole den Import erst, wenn die lokale Einstellungsdatei geprüft und die Anwendung neu geladen wurde. Nach einem unklaren Import ist die Einstellungsspeicherung gesperrt.'
            'Preferences.ExportUncertain' = 'Die Exportdatei konnte nicht verifiziert werden. Prüfe die gewählte Datei vor der Verwendung. Die lokalen Anwendungseinstellungen wurden nicht geändert.'
            'Preferences.ErrorLayout' = 'Die Vorschau passt nicht in den verfügbaren Arbeitsbereich. Nutze einen größeren Arbeitsbereich oder eine geringere Skalierung. Keine Einstellungen wurden geändert.'
            'Preferences.Exported' = 'Einstellungen gesichert'
            'Preferences.ExportSuccess' = 'Die Einstellungsdatei wurde lokal gespeichert. Bewahre sie vertraulich auf, wenn sie persönliche Aliase oder GUIDs enthält.'
            'Preferences.Imported' = 'Einstellungen wiederhergestellt'
            'Preferences.ImportSuccess' = 'Die bestätigten Darstellungseinstellungen wurden gespeichert. Systemkonfiguration und Startzielauswahl wurden nicht geändert.'
            'Preferences.RefreshWarning' = 'Die Einstellungen wurden gespeichert, die Anzeige konnte aber nicht vollständig aktualisiert werden. Starte die Anwendung neu, um die gespeicherten Einstellungen zu sehen.'
            'Settings.DefaultPickerCurrent' = 'Aktuelles Standardziel: {Target}'
            'Settings.DefaultPickerNoneHint' = 'Kein dauerhaftes Startziel festlegen'
            'Settings.DefaultPickerSelected' = 'Aktuelles dauerhaftes Standardziel'
            'Settings.Autostart' = 'Mit Windows starten'
            'Settings.DefaultTarget' = 'Standard-Startziel'
            'Settings.NoDefaultTarget' = 'Kein Standardziel'
            'Settings.DefaultTargetUnavailable' = 'Nicht verfügbares Startziel'
            'BootNext.Unknown' = 'Nächstes Startziel unbekannt'
            'BootNext.UnknownLine' = 'Nächster Neustart: unbekannt · bitte prüfen'
            'BootNext.FirmwareOrderLine' = 'Nächstes Ziel: Firmware-Reihenfolge · Standard: {Default}'
            'BootNext.AlignedLine' = 'Nächstes Ziel: {Next} · entspricht Standard'
            'BootNext.DifferentLine' = 'Nächstes Ziel: {Next} · Standard: {Default}'
            'BootNext.UnavailableLine' = 'Nächstes Startziel nicht verfügbar'
            'BootNext.UseDefaultHint' = 'Ersetzt das einmalige Startziel durch das gespeicherte Standardziel „{Default}“. Der Rechner wird nicht neu gestartet.'
            'BootNext.UseDefaultOnce' = 'Auf Standardziel zurücksetzen'
            'BootNext.LayoutUnknown' = 'Nächster Start · ungeprüft; Ziel prüfen'
            'BootNext.LayoutFirmwareOrder' = 'Geprüft · Firmware-Reihenfolge (kein Einmalziel)'
            'BootNext.LayoutAligned' = 'Bestätigt · wie Standard: {Next}'
            'BootNext.LayoutDifferent' = 'Bestätigt · abweichend vom Standard: {Next}'
            'BootNext.LayoutUnavailable' = 'Nächster Start · Ziel nicht verfügbar'
            'BootNext.DefaultApplied' = 'Standardziel wurde für den nächsten Neustart vorgemerkt.'
            'BootNext.DefaultApplyFailed' = 'Das nächste Startziel konnte nicht geändert werden. Bitte das tatsächliche Ziel prüfen.'
            'BootNext.SelectionPending' = 'Wird gesetzt …'
            'BootNext.RowPendingHint' = 'Startziel wird gesetzt · noch nicht bestätigt'
            'BootNext.RowSelectedHint' = 'Bestätigtes nächstes Startziel'
            'BootNext.SelectionPendingFooter' = '{Target} wird gesetzt · noch nicht bestätigt'
            'BootNext.SelectionFailed' = 'Bootziel nicht bestätigt. Bitte den tatsächlichen nächsten Start prüfen.'
            'BootNext.CheckFailed' = 'Das nächste Startziel der Firmware konnte nicht verifiziert werden. Es wurde kein Neustart ausgelöst.'
            'Status.Checking' = 'Wird geprüft …'
            'Action.RestartWindows' = 'Windows neu starten'
            'Status.NextTargetDefaultOrder' = 'Nächstes Ziel: Standardreihenfolge'
            'Manage.Section' = 'STARTZIELE ANPASSEN'
            'Manage.Title' = 'ÄNDERUNGEN'
            'Manage.Hint' = 'Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden'
            'Manage.SubHint' = 'Stift zum Umbenennen · Leer lassen = Originalname'
            'Manage.Save' = 'Änderungen speichern'
            'Manage.Undo' = 'Rückgängig'
            'Manage.UndoDone' = 'Letzte Änderung rückgängig gemacht.'
            'Manage.UndoTargetUnavailable' = 'Ein Startziel ist nicht mehr verfügbar. Seine unvollständige Bearbeitung und der Rückgängig-Verlauf wurden verworfen. Andere Änderungen bleiben erhalten.'
            'Manage.UndoInventoryChanged' = 'Startziele haben sich geändert. Rückgängig-Verlauf verworfen; aktuelle Änderungen bleiben erhalten.'
            'Manage.StatusEditing' = 'Startziele anpassen · Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden · Stift für Anzeigename'
            'Manage.StatusSaved' = 'Änderungen an den Startzielen wurden gespeichert.'
            'Manage.StatusDiscarded' = 'Änderungen wurden verworfen.'
            'Autostart.Enabled' = 'Autostart ist aktiviert.'
            'Autostart.Disabled' = 'Autostart ist deaktiviert.'
            'Autostart.ErrorHeading' = 'Die Einstellung konnte nicht geändert werden.'
            'Default.SaveErrorHeading' = 'Das Standard-Startziel konnte nicht gespeichert werden.'
            'Default.SaveErrorMessage' = 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.'
            'Default.ChangeSaving' = 'Speichern …'
            'Default.ChangeVerifying' = 'Prüfen …'
            'Default.ChangeSavingFooter' = 'Standardziel wird gespeichert: {Target} · noch nicht bestätigt'
            'Default.ChangeVerifyingFooter' = 'Standardziel und nächsten Start prüfen: {Target} …'
            'Default.ChangePartialHeading' = 'Standardziel gespeichert, nächster Start ungeprüft'
            'Default.ChangePartial' = 'Das gespeicherte Standardziel wurde bestätigt, aber der nächste Start konnte nicht geprüft werden. Bitte vor dem Neustart kontrollieren.'
            'Default.ChangeUnknown' = 'Standardziel nicht verifiziert'
            'Status.NewBootTargetDetected' = 'Neues Startziel erkannt · Systemfunktionen neu initialisieren.'
            'Status.BootTargetsChanged' = 'Startziele geändert · Systemfunktionen neu initialisieren.'
            'Status.SystemFunctionsRepairRequired' = 'Systemfunktionen müssen repariert werden.'
            'Status.SystemFunctionsSetupRequired' = 'Systemfunktionen müssen eingerichtet werden.'
            'Header.Refreshing' = 'Aktualisiere Bootziele…'
            'Header.InitializingApplication' = 'Initialisiere Anwendung …'
            'Header.RefreshingApplication' = 'Aktualisiere Anwendungsstatus …'
            'Update.Available' = 'Neue App-Version verfügbar'
            'Tray.Open' = 'Lenovo Boot Selector öffnen'
            'Tray.Maintenance' = 'Wartung'
            'Maintenance.Setup' = 'Systemfunktionen einrichten…'
            'Maintenance.Remove' = 'Systemfunktionen entfernen…'
            'Update.Check' = 'Auf neue Version prüfen…'
            'Update.Install' = 'App aktualisieren…'
            'Diagnostics.Save' = 'Diagnose speichern…'
            'Diagnostics.Upload' = 'Diagnose hochladen…'
            'Boot.OtherTarget' = 'Weiteres Startziel'
            'Boot.OtherTargetTooltip' = 'Startzieltyp: Weiteres Startziel · Typfarbe: Grau'
            'Boot.MenuTitle' = 'Lenovo Boot-Menü'
            'Boot.MenuSubtitle' = 'Beim nächsten Start das Boot-Menü öffnen'
            'Boot.MenuTooltip' = 'Startzieltyp: Lenovo Boot-Menü · Typfarbe: Rot'
            'Boot.Nvme1Title' = 'NVMe-SSD 1'
            'Boot.Nvme2Title' = 'NVMe-SSD 2'
            'Boot.NoDrive' = 'Kein Laufwerk erkannt'
            'Boot.InternalSsd' = 'Interne SSD'
            'Boot.SecondInternalSsd' = 'Zweite interne SSD'
            'Boot.InternalSsdTooltip' = 'Startzieltyp: Interne SSD · Typfarbe: Blau'
            'Boot.UsbTooltip' = 'Startzieltyp: USB-Laufwerk · Typfarbe: Gelb'
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
            'Boot.PxeTooltip' = 'Startzieltyp: Netzwerkstart · Typfarbe: Violett'
            'Boot.LenovoRecoveryTitle' = 'Lenovo Wiederherstellung'
            'Boot.LenovoRecoverySubtitle' = 'Wiederherstellung über das Netzwerk'
            'Boot.CyanTooltip' = 'Startzieltyp: Lenovo- oder Firmen-Netzwerk · Typfarbe: Cyan'
            'Boot.CorporateTitle' = 'Firmen-Netzwerkstart'
            'Boot.CorporateSubtitle' = 'Start über das Firmennetzwerk'
            'Boot.OtherDriveTitle' = 'Weiteres Laufwerk'
            'Boot.OtherDriveSubtitle' = 'Weiteres erkanntes Laufwerk'
            'Boot.OtherDriveTooltip' = 'Startzieltyp: Weiteres Laufwerk · Typfarbe: Grau'
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
            'Manage.ReorderHint' = 'Ziehen, um die Reihenfolge zu ändern'
            'Manage.KeyboardHint' = 'Strg+↑/↓ · Leer · Strg+E'
            'Manage.KeyboardPositionHint' = '{Position}/{Count} · Strg+↑/↓ · Leer · Strg+E'
            'Manage.KeyboardPosition' = 'Position {Position} von {Count}'
            'Manage.KeyboardInstructions' = 'Pfeil- und Bildtasten navigieren. Strg+Pfeil/Bild/Pos1/Ende sortiert. Leertaste blendet ein oder aus. Strg+E ändert den Anzeigenamen. Tab wechselt zu den Aktionen.'
            'Manage.ClearAliasHint' = 'Anzeigename leeren'
            'Manage.AliasCue' = 'Originalname verwenden'
            'Manage.AliasFieldHint' = 'Leer: Originalname verwenden'
            'Manage.AliasLimitExceeded' = 'Anzeigename: maximal {Limit} Zeichen'
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
            'Update.Later' = 'Später'
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
            'Diagnostics.Uploading' = 'Diagnose wird hochgeladen…'
            'Diagnostics.UploadedTitle' = 'Diagnose hochgeladen'
            'Diagnostics.UploadedHeading' = 'Das Diagnosepaket wurde übertragen.'
            'Diagnostics.UploadedMessage' = 'Das ZIP wurde privat zur Fehleranalyse gespeichert.'
            'Diagnostics.UploadedWithId' = "Das ZIP wurde privat gespeichert.`r`nDiagnose-ID: {DiagnosisId}`r`nDiese ID für die Analyse in ChatGPT verwenden."
            'Diagnostics.CopyId' = 'Diagnose-ID kopieren'
            'Diagnostics.Copied' = 'Kopiert ✓'
            'Diagnostics.CopyFailed' = 'Kopieren fehlgeschlagen'
            'Diagnostics.UploadNoLocalPackageMessage' = 'Der Upload konnte nicht gestartet werden. Ein lokal gespeichertes Paket konnte nicht bestätigt werden. Speichere die Diagnose vor einem erneuten Versuch.'
            'Diagnostics.IdCaption' = 'DIAGNOSE-ID'
            'Diagnostics.IdHint' = 'Das ZIP wurde privat gespeichert. Verwende diese ID zur Analyse in ChatGPT.'
            'Diagnostics.PathCaption' = 'SPEICHERORT'
            'Diagnostics.PathHint' = 'Das Diagnosepaket ist lokal gespeichert.'
            'Maintenance.Dialog.Changes' = 'WAS SICH ÄNDERT'
            'Maintenance.Dialog.Retained' = 'WAS ERHALTEN BLEIBT'
            'Diagnostics.ReferenceMissingTitle' = 'Upload bestätigt - ID fehlt'
            'Diagnostics.ReferenceMissingHeading' = 'Der Server hat den Upload angenommen.'
            'Diagnostics.ReferenceMissingMessage' = 'Die Referenz konnte nicht geprüft werden. Das ZIP könnte gespeichert sein. Bitte nicht sofort erneut hochladen.'
            'Diagnostics.UploadFailedTitle' = 'Hochladen fehlgeschlagen'
            'Diagnostics.UploadFailedHeading' = 'Die Diagnose konnte nicht hochgeladen werden.'
            'Diagnostics.UploadFailedMessage' = 'Das Paket bleibt lokal gespeichert. Bitte später erneut versuchen.'
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
            'Default.SystemSavedStatus' = 'Systemstandard gespeichert: {Name} · wird beim nächsten Windows-Systemstart ohne zusätzliche Wartezeit gesetzt.'
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

# The native EDIT limit counts UTF-16 code units. Preserve unchanged legacy
# aliases on edit/save; normalization of loaded settings must stay lossless.
function Get-EntryAliasMaxLengthCore { return 30 }

function Test-EntryAliasChangeCore {
    param([AllowEmptyString()][string]$Value,[AllowEmptyString()][string]$Previous)
    $normalized = ([string]$Value).Trim()
    return ($normalized.Length -le (Get-EntryAliasMaxLengthCore) -or
        [string]::Equals($normalized, ([string]$Previous).Trim(), [System.StringComparison]::Ordinal))
}

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
        if (([string]$a[$key]).Trim() -cne ([string]$b[$key]).Trim()) { return $false }
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

# LBS-179: detached snapshots contain only the three unprivileged draft fields.
function New-ManageDraftSnapshotCore {
    param([object[]]$Order,[object[]]$Hidden,$Aliases)
    return [pscustomobject]@{
        Order=@($Order | ForEach-Object { [string]$_ })
        Hidden=@($Hidden | ForEach-Object { [string]$_ })
        Aliases=(Copy-EntryAliasMap $Aliases)
    }
}

function Test-ManageDraftSnapshotEqualCore {
    param($Left,$Right)
    return ((Test-StringSequenceEqual -Left $Left.Order -Right $Right.Order) -and
        (Test-StringSequenceEqual -Left $Left.Hidden -Right $Right.Hidden -Sort) -and
        (Test-EntryAliasMapsEqual -Left $Left.Aliases -Right $Right.Aliases))
}

# Portable preference format v1. Pure data operations; no IO or action admission.
function Get-PortablePreferencesLimitCore { return 262144 }

function Read-PortableJsonTokenCore {
    param($Reader)
    $match = $Reader.Pattern.Match($Reader.Text,$Reader.Offset)
    if (-not $match.Success -or $match.Index -ne $Reader.Offset) { throw 'InvalidJson' }
    $Reader.Offset = $match.Index + $match.Length
    return $match.Groups['token'].Value
}

function ConvertFrom-PortableJsonStringCore {
    param([string]$Token)
    $value = [regex]::Replace($Token.Substring(1,$Token.Length-2),'\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4})',[System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        switch -CaseSensitive ($m.Value.Substring(1,1)) {
            '"' { return '"' }
            '\' { return '\' }
            '/' { return '/' }
            'b' { return [string][char]8 }
            'f' { return [string][char]12 }
            'n' { return [string][char]10 }
            'r' { return [string][char]13 }
            't' { return [string][char]9 }
            'u' { return [string][char][Convert]::ToInt32($m.Value.Substring(2),16) }
        }
    })
    [void]([System.Text.UTF8Encoding]::new($false,$true).GetByteCount($value))
    return $value
}

function Read-PortableJsonValueCore {
    param($Reader,[string]$Token,[int]$Depth)
    if ($Depth -gt 5) { throw 'InvalidDepth' }
    if ($Token -ceq '{') {
        $map = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::OrdinalIgnoreCase)
        $key = Read-PortableJsonTokenCore $Reader
        if ($key -ceq '}') { return [pscustomobject]@{Value=$map} }
        while ($true) {
            if (-not $key.StartsWith('"')) { throw 'InvalidJson' }
            $name = ConvertFrom-PortableJsonStringCore $key
            if ($map.Contains($name)) { throw 'DuplicateKey' }
            if ((Read-PortableJsonTokenCore $Reader) -cne ':') { throw 'InvalidJson' }
            $value = Read-PortableJsonValueCore $Reader (Read-PortableJsonTokenCore $Reader) ($Depth+1)
            $map.Add($name,$value.Value)
            if ($map.Count -gt 512) { throw 'InvalidShape' }
            $separator = Read-PortableJsonTokenCore $Reader
            if ($separator -ceq '}') { break }
            if ($separator -cne ',') { throw 'InvalidJson' }
            $key = Read-PortableJsonTokenCore $Reader
        }
        return [pscustomobject]@{Value=$map}
    }
    if ($Token -ceq '[') {
        $items = [System.Collections.Generic.List[object]]::new()
        $next = Read-PortableJsonTokenCore $Reader
        if ($next -cne ']') {
            while ($true) {
                $item = Read-PortableJsonValueCore $Reader $next ($Depth+1)
                $items.Add($item.Value)
                if ($items.Count -gt 512) { throw 'TooManyEntries' }
                $separator = Read-PortableJsonTokenCore $Reader
                if ($separator -ceq ']') { break }
                if ($separator -cne ',') { throw 'InvalidJson' }
                $next = Read-PortableJsonTokenCore $Reader
            }
        }
        return [pscustomobject]@{Value=$items.ToArray()}
    }
    if ($Token.StartsWith('"')) {
        $value = ConvertFrom-PortableJsonStringCore $Token
        return [pscustomobject]@{Value=$value}
    }
    switch -CaseSensitive ($Token) {
        'true' { return [pscustomobject]@{Value=$true} }
        'false' { return [pscustomobject]@{Value=$false} }
        'null' { return [pscustomobject]@{Value=$null} }
        default {
            if ($Token -cmatch '^(0|[1-9][0-9]*)$') {
                $number = 0
                if ([int]::TryParse($Token,[ref]$number)) { return [pscustomobject]@{Value=$number} }
            }
            throw 'InvalidScalar'
        }
    }
}

function Assert-PortableKeysCore {
    param($Map,[string[]]$Keys)
    if ($Map -isnot [System.Collections.IDictionary] -or $Map.Count -ne $Keys.Count) { throw 'InvalidShape' }
    foreach ($key in $Map.Keys) {
        if ($key -cnotin $Keys) { throw 'UnknownKey' }
    }
}

function ConvertTo-PortableGuidCore {
    param($Value)
    if ($Value -isnot [string] -or $Value -cnotmatch '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$') { throw 'InvalidIdentity' }
    return $Value.ToLowerInvariant()
}

function Read-BoundedPreferencesJsonCore {
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    $encoding = [System.Text.UTF8Encoding]::new($false,$true)
    if ($encoding.GetByteCount($Text) -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    # Narrow grammar for preference documents (integer versions, no floats).
    # Decode strings without date coercion; detect duplicate decoded keys.
    $reader = [pscustomobject]@{
        Text=$Text; Offset=0
        Pattern=[regex]::new('\G[ \t\r\n]*(?<token>"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"|[{}\[\]:,]|true|false|null|0|[1-9][0-9]*)',[System.Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(2))
    }
    $root = (Read-PortableJsonValueCore $reader (Read-PortableJsonTokenCore $reader) 0).Value
    if ($Text.Substring($reader.Offset) -cnotmatch '^[ \t\r\n]*$') { throw 'TrailingJson' }
    return [pscustomobject]@{Value=$root}
}

function ConvertFrom-PortablePreferencesCore {
    param([AllowEmptyString()][string]$Text)
    $root = (Read-BoundedPreferencesJsonCore $Text).Value
    $encoding = [System.Text.UTF8Encoding]::new($false,$true)
    Assert-PortableKeysCore $root @('format','version','locale','entries')
    if ($root.format -isnot [string] -or $root.format -cne 'LenovoBootSelector.Preferences' -or $root.version -isnot [int] -or $root.version -ne 1) { throw 'UnsupportedFormat' }
    if ($root.locale -isnot [string] -or $root.locale -cnotin @('de-DE','en-US')) { throw 'InvalidLocale' }
    if ($root.entries -isnot [array]) { throw 'InvalidEntries' }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $root.entries) {
        Assert-PortableKeysCore $row @('guid','alias','hidden')
        $guid = ConvertTo-PortableGuidCore $row.guid
        if (-not $seen.Add($guid)) { throw 'DuplicateIdentity' }
        if ($row.hidden -isnot [bool] -or $row.alias -isnot [string]) { throw 'InvalidEntry' }
        if ($row.alias.Length -gt 4096 -or $row.alias -match '[\x00-\x1f\x7f]' -or $row.alias -cne $row.alias.Trim()) { throw 'InvalidAlias' }
        [void]$encoding.GetByteCount($row.alias)
        $entries.Add([pscustomobject]@{guid=$guid;alias=$row.alias;hidden=$row.hidden})
    }
    return [pscustomobject]@{format=$root.format;version=1;locale=$root.locale;entries=$entries.ToArray()}
}

function New-PortablePreferencesCore {
    param($Settings,[object[]]$CurrentEntries)
    if ($Settings.localePreferenceNeedsConfirmation -or $Settings.localePreferenceSource -eq 'migration-pending') { throw 'LocaleMigrationPending' }
    $aliases = Convert-EntryAliasesToHashtable $Settings.entryAliases
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($CurrentEntries)) {
        if (-not $seen.Add((ConvertTo-PortableGuidCore $entry.Guid))) { throw 'DuplicateLocalIdentity' }
    }
    $rows = @(
        foreach ($entry in @(Get-OrderedEntriesCore -Source $CurrentEntries -Order $Settings.entryOrder -Hidden $Settings.hiddenEntryGuids -IncludeHidden)) {
            $guid = ConvertTo-PortableGuidCore $entry.Guid
            [ordered]@{guid=$guid;alias=[string]$aliases[$guid];hidden=(Test-GuidInList -Guid $guid -List $Settings.hiddenEntryGuids)}
        }
    )
    $payload = [ordered]@{format='LenovoBootSelector.Preferences';version=1;locale=[string]$Settings.locale;entries=$rows}
    $json = ConvertTo-Json -InputObject $payload -Depth 5
    # Self-validate before any file write; never emit an unsupported file.
    [void](ConvertFrom-PortablePreferencesCore $json)
    return $json
}

function New-PortablePreferencesPlanCore {
    param($Imported,$Settings,[object[]]$CurrentEntries)
    if ($Settings.localePreferenceNeedsConfirmation -or $Settings.localePreferenceSource -eq 'migration-pending') { throw 'LocaleMigrationPending' }
    $local = @{}
    foreach ($entry in @($CurrentEntries)) {
        $guid = ConvertTo-PortableGuidCore $entry.Guid
        if ($local.ContainsKey($guid)) { throw 'DuplicateLocalIdentity' }
        $local[$guid]=$entry
    }
    $aliases = Convert-EntryAliasesToHashtable $Settings.entryAliases
    $hidden = @($Settings.hiddenEntryGuids)
    $ordered = @(Get-OrderedEntriesCore -Source $CurrentEntries -Order $Settings.entryOrder -Hidden $hidden -IncludeHidden | ForEach-Object { [string]$_.Guid })
    # Preserve unavailable persisted order entries at their existing positions.
    $order = [System.Collections.Generic.List[string]]::new()
    $orderSeen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($guid in @($Settings.entryOrder)+$ordered) {
        if ($guid -and $orderSeen.Add([string]$guid)) { $order.Add([string]$guid) }
    }
    $matched = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $importOrder = [System.Collections.Generic.List[string]]::new()
    $preview = [System.Collections.Generic.List[object]]::new()
    foreach ($row in @($Imported.entries)) {
        $guid = $row.guid
        if (-not $local.ContainsKey($guid)) {
            $preview.Add([pscustomobject]@{Guid=$guid;Title='';Status='Unmatched';OldAlias='';NewAlias=$row.alias;OldHidden=$null;NewHidden=$row.hidden;OldPosition=$null;NewPosition=$null;AliasSkipped=$false})
            continue
        }
        $old = [string]$aliases[$guid]
        $skip = -not (Test-EntryAliasChangeCore -Value $row.alias -Previous $old)
        $new = if ($skip) {$old} else {$row.alias}
        $wasHidden = Test-GuidInList -Guid $guid -List $hidden
        if ($new) { $aliases[$guid]=$new } else { $aliases.Remove($guid) }
        if ($wasHidden -ne $row.hidden) {
            $hidden = @($hidden | Where-Object { $_ -ne $guid })
            if ($row.hidden) { $hidden += $guid }
        }
        [void]$matched.Add($guid)
        $importOrder.Add($guid)
        $preview.Add([pscustomobject]@{Guid=$guid;Title=[string]$local[$guid].Title;Status='Matched';OldAlias=$old;NewAlias=$new;OldHidden=$wasHidden;NewHidden=$row.hidden;OldPosition=([array]::IndexOf($ordered,$guid)+1);NewPosition=$null;AliasSkipped=$skip})
    }
    $index=0
    for ($i=0;$i -lt $order.Count;$i++) {
        if ($matched.Contains($order[$i])) { $order[$i]=$importOrder[$index]; $index++ }
    }
    $newOrdered = @($order | Where-Object { $local.ContainsKey($_) })
    foreach ($row in $preview) {
        if ($row.Status -eq 'Matched') { $row.NewPosition=[array]::IndexOf($newOrdered,$row.Guid)+1 }
    }
    foreach ($guid in $ordered) {
        if (-not $matched.Contains($guid)) {
            $preview.Add([pscustomobject]@{Guid=$guid;Title=[string]$local[$guid].Title;Status='LocalOnly';OldAlias=[string]$aliases[$guid];NewAlias=[string]$aliases[$guid];OldHidden=(Test-GuidInList -Guid $guid -List $hidden);NewHidden=(Test-GuidInList -Guid $guid -List $hidden);OldPosition=([array]::IndexOf($ordered,$guid)+1);NewPosition=([array]::IndexOf($newOrdered,$guid)+1);AliasSkipped=$false})
        }
    }
    $unavailable = @(@($Settings.entryOrder)+@($Settings.hiddenEntryGuids)+@($aliases.Keys) | Where-Object { $_ -and -not $local.ContainsKey($_) } | Sort-Object -Unique)
    $resultOrder = if (Test-StringSequenceEqual -Left $ordered -Right $newOrdered) { @($Settings.entryOrder) } else { $order.ToArray() }
    return [pscustomobject]@{Locale=$Imported.locale;OldLocale=$Settings.locale;EntryOrder=@($resultOrder);HiddenEntryGuids=@($hidden | Select-Object -Unique);EntryAliases=$aliases;Rows=$preview.ToArray();UnavailableLocal=$unavailable}
}

# LBS-143: pure, fail-closed boot ownership decision core.
# No firmware I/O, storage, system tasks, or process-local provenance assertions.
function Resolve-BootNextSynchronizationCore {
    param(
        [AllowNull()][string]$PreviousDefaultGuid,
        [AllowNull()][string]$NewDefaultGuid,
        [AllowNull()][string]$EffectiveNextGuid,
        [AllowNull()][string]$OriginGuid,
        [AllowNull()][string]$OriginBootId,
        [AllowNull()][string]$CurrentBootId,
        [AllowEmptyString()][string]$OriginKind = '',
        [bool]$FirmwareReadSucceeded = $false
    )
    $decision = 'Preserve'
    $reason = 'unknown-provenance'
    if (-not $NewDefaultGuid) {
        $reason = 'default-cleared'
    }
    elseif ($PreviousDefaultGuid -eq $NewDefaultGuid) {
        $reason = 'default-unchanged'
    }
    elseif (-not $FirmwareReadSucceeded) {
        $reason = 'firmware-unverified'
    }
    elseif (-not $EffectiveNextGuid) {
        $reason = 'firmware-default-order'
    }
    elseif ($OriginKind -eq 'manual' -or $OriginKind -eq 'pending-manual') {
        $reason = 'explicit-lfs-selection'
    }
    elseif ($OriginKind -eq 'auto' -and $OriginGuid -and $OriginBootId -and $CurrentBootId -and
            $OriginBootId -ceq $CurrentBootId -and $OriginGuid -eq $PreviousDefaultGuid -and
            $OriginGuid -eq $EffectiveNextGuid) {
        $decision = 'Synchronize'
        $reason = 'verified-lfs-auto-origin'
    }
    elseif ($OriginKind -eq 'auto' -and $OriginGuid -and $EffectiveNextGuid -and
            $OriginGuid -ne $EffectiveNextGuid) {
        $reason = 'observed-external-mismatch'
    }
    elseif ($OriginKind -eq 'pending-auto') {
        $reason = 'interrupted-auto-write'
    }
    elseif ($OriginBootId -and $CurrentBootId -and $OriginBootId -cne $CurrentBootId) {
        $reason = 'stale-boot-cycle'
    }
    [pscustomobject]@{
        Decision = $decision
        Reason = $reason
        RequiresExplicitSelection = ($decision -ne 'Synchronize' -and
            $NewDefaultGuid -and $PreviousDefaultGuid -ne $NewDefaultGuid -and
            $FirmwareReadSucceeded -and $EffectiveNextGuid -and $EffectiveNextGuid -ne $NewDefaultGuid)
    }
}

function Resolve-BootNextDisplayStateCore {
    param(
        [AllowNull()][string]$DefaultGuid,
        [AllowNull()][string]$EffectiveNextGuid,
        [bool]$FirmwareReadSucceeded,
        [bool]$Checking,
        [bool]$EffectiveTargetKnown = $true
    )
    if ($Checking) { return 'checking' }
    if (-not $FirmwareReadSucceeded) { return 'unknown' }
    if (-not $EffectiveNextGuid) { return 'firmware-order' }
    if (-not $EffectiveTargetKnown) { return 'unavailable' }
    if ($DefaultGuid -and $DefaultGuid -eq $EffectiveNextGuid) { return 'aligned' }
    return 'different'
}

# Pure BootNext selection display/verification contract.
# A pending user request must never be represented as an effective one-shot
# firmware selection until the protected writer and firmware readback succeed.
function Resolve-BootNextRowDisplayCore {
    param([AllowNull()][string]$EntryGuid,[AllowNull()][string]$ConfirmedGuid,[AllowNull()][string]$PendingGuid)
    if (-not $EntryGuid) { return 'idle' }
    if ($PendingGuid -and $EntryGuid -eq $PendingGuid) { return 'pending' }
    if ($ConfirmedGuid -and $EntryGuid -eq $ConfirmedGuid) { return 'selected' }
    return 'idle'
}

function Test-BootNextWorkerResultCore {
    param([AllowNull()][string]$RequestedGuid,[AllowNull()][string]$ReturnedGuid,[bool]$Success)
    return ([bool]$Success -and [bool]$RequestedGuid -and
        [bool]$ReturnedGuid -and $RequestedGuid -eq $ReturnedGuid)
}

# Distinguish a safe, visibly deferred cold-start intent from authorization
# to execute the fixed SYSTEM BootNext writer. This decision never mutates EFI.
function Resolve-BootNextSelectionAdmissionCore {
    param(
        [AllowEmptyString()][string]$CapabilityState,
        [bool]$CanSetBootNext,
        [bool]$CanUseCachedBootState,
        [bool]$RefreshActive,
        [bool]$TargetAllowlisted
    )
    if (-not $TargetAllowlisted) { return 'reject' }
    if ($CapabilityState -eq 'Ready' -and $CanSetBootNext) { return 'start' }
    if ($CapabilityState -eq 'Checking' -and $CanUseCachedBootState -and $RefreshActive) {
        return 'deferred'
    }
    return 'reject'
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

#requires -version 5.1
# LBS-140: single-instance activation channel. No device/firmware privileges.
function Get-LbsActivationName {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($sid -notmatch '^S-1-[0-9-]+$') { throw 'Invalid current user SID for activation channel.' }
    return ('Local\LenovoBootSelector-Activate-' + $sid)
}

function New-LbsActivationEvent {
    param([string]$Name = (Get-LbsActivationName))
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = New-Object System.Security.AccessControl.EventWaitHandleSecurity
    $rights = [System.Security.AccessControl.EventWaitHandleRights]::Synchronize -bor
              [System.Security.AccessControl.EventWaitHandleRights]::Modify
    $rule = [System.Security.AccessControl.EventWaitHandleAccessRule]::new(
        $sid,$rights,[System.Security.AccessControl.AccessControlType]::Allow)
    $security.AddAccessRule($rule)
    $created = $false
    $event = [System.Threading.EventWaitHandle]::new(
        $false,[System.Threading.EventResetMode]::AutoReset,$Name,[ref]$created,$security)
    if (-not $created) {
        $event.Dispose()
        throw 'Activation channel already exists; refusing to adopt an unknown owner.'
    }
    return $event
}

function Send-LbsActivationRequest {
    param([string]$Name = (Get-LbsActivationName),[int]$RetryMs = 3000)
    if ($RetryMs -lt 0 -or $RetryMs -gt 10000) { throw 'Invalid activation retry interval.' }
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    do {
        $event = $null
        try {
            $event = [System.Threading.EventWaitHandle]::OpenExisting(
                $Name,[System.Security.AccessControl.EventWaitHandleRights]::Modify)
            return [bool]$event.Set()
        }
        catch [System.Threading.WaitHandleCannotBeOpenedException] {
            # The mutex owner can still be setting up its signal channel.
        }
        catch [System.UnauthorizedAccessException] {
            # No cross-user/session control or broadened permissions.
            return $false
        }
        catch {
            return $false
        }
        finally {
            if ($event) { $event.Dispose() }
        }
        if ($deadline.ElapsedMilliseconds -ge $RetryMs) { return $false }
        Start-Sleep -Milliseconds 75
    } while ($true)
}

function Start-LbsActivationListener {
    param(
        [Parameter(Mandatory=$true)][System.Threading.EventWaitHandle]$Signal,
        [Parameter(Mandatory=$true)][scriptblock]$OnActivate
    )
    # The wait uses ThreadPool, not a polling timer. The callback executes on
    # the WinForms UI thread via BeginInvoke, never inside the thread-pool worker.
    if (-not ('LenovoBootSelectorActivationWaiter' -as [type])) {
        Add-Type -ReferencedAssemblies @('System.Windows.Forms.dll') -TypeDefinition @'
using System;
using System.Threading;
using System.Windows.Forms;
public sealed class LenovoBootSelectorActivationWaiter : IDisposable {
    private readonly Control host;
    private readonly Action onActivate;
    private readonly RegisteredWaitHandle registration;
    private bool disposed;
    public LenovoBootSelectorActivationWaiter(EventWaitHandle signal, Control control, Action action) {
        if (signal == null || control == null || action == null || !control.IsHandleCreated)
            throw new ArgumentException("Activation callback requires a live WinForms UI handle.");
        host = control; onActivate = action;
        registration = ThreadPool.RegisterWaitForSingleObject(signal,
            delegate(object state, bool timedOut) {
                if (disposed || host.IsDisposed || !host.IsHandleCreated) return;
                try { host.BeginInvoke(onActivate); }
                catch (ObjectDisposedException) { }
                catch (InvalidOperationException) { }
            }, null, Timeout.Infinite, false);
    }
    public void Dispose() {
        disposed = true;
        if (registration != null) registration.Unregister(null);
    }
}
'@
    }
    $hostControl = New-Object System.Windows.Forms.Control
    try {
        [void]$hostControl.Handle
        $callback = [System.Action]$OnActivate
        $waiter = [LenovoBootSelectorActivationWaiter]::new($Signal,$hostControl,$callback)
        return [pscustomobject]@{ Waiter = $waiter; Host = $hostControl }
    }
    catch {
        $hostControl.Dispose()
        throw
    }
}

function Stop-LbsActivationListener {
    param($Listener)
    if (-not $Listener) { return }
    try { $Listener.Waiter.Dispose() } finally { $Listener.Host.Dispose() }
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

// Small, deterministic country flags shared by the Language submenu and settings.
// Drawn locally at the active DPI; no emoji fonts, native image gutters or assets.
public static class LenovoLocaleFlags
{
    private const string MenuName = "LenovoLanguageDropDown";
    private static int Scale(int value, float dpi)
    {
        return Math.Max(1, (int)Math.Round(value * Math.Max(96f, dpi) / 96f));
    }

    // Graphics.DpiX is the native GDI pixel density of the paint surface.
    // Glyph dimensions use this density, not (font.SizeInPoints / 9), since
    // typographic point sizes must remain constant across monitor scales.

    public static string GetLocale(ToolStripItem item)
    {
        if (item == null || item.Owner == null || item.Owner.Name != MenuName)
            return null;
        if (item.Name == "LocaleFlag.en-US") return "en-US";
        if (item.Name == "LocaleFlag.de-DE") return "de-DE";
        return null;
    }

    public static Rectangle GetBounds(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return Rectangle.Empty;
        int width = Scale(16, dpi);
        int height = Scale(12, dpi);
        return new Rectangle(row.Left + Scale(10, dpi),
            row.Top + Math.Max(0, (row.Height - height) / 2), width, height);
    }

    public static int TextLeft(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return row.Left;
        return row.Left + Scale(34, dpi);
    }

    public static Rectangle GetTextBounds(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return Rectangle.Empty;
        int left = TextLeft(item, row, dpi);
        // Reserve the right-side checkmark independently of WinForms' original
        // TextRectangle. The native rectangle may be only a few pixels wide
        // because the menu deliberately suppresses the image/check gutters.
        int right = row.Right - Scale(32, dpi);
        return new Rectangle(left, row.Top, Math.Max(0, right - left), row.Height);
    }

    public static void Draw(Graphics g, ToolStripItem item, Rectangle row)
    {
        string locale = GetLocale(item);
        if (locale == null || g == null) return;
        DrawFlag(g, locale, GetBounds(item, row, g.DpiX));
    }

    public static void DrawFlag(Graphics g, string locale, Rectangle flag)
    {
        if (g == null || flag.Width <= 0 || flag.Height <= 0 ||
            (locale != "de-DE" && locale != "en-US")) return;
        GraphicsState saved = g.Save();
        try
        {
            g.SmoothingMode = SmoothingMode.None;
            g.SetClip(flag, CombineMode.Intersect);
            if (locale == "de-DE")
            {
                Color[] bands = { Color.Black, Color.FromArgb(221, 0, 0), Color.FromArgb(255, 206, 0) };
                for (int i = 0; i < bands.Length; i++)
                {
                    using (Brush brush = new SolidBrush(bands[i]))
                        g.FillRectangle(brush, new RectangleF(flag.Left, flag.Top + i * flag.Height / 3f,
                            flag.Width, flag.Height / 3f + 0.3f));
                }
            }
            else
            {
                using (Brush white = new SolidBrush(Color.White))
                    g.FillRectangle(white, flag);
                // Rasterize all thirteen official stripes onto the available pixels.
                // Pixel-center sampling keeps the first and last stripes red,
                // including at 16x12 where one logical stripe cannot get a row.
                using (Brush red = new SolidBrush(Color.FromArgb(178, 34, 52)))
                    for (int y = 0; y < flag.Height; y++)
                    {
                        int stripe = Math.Min(12, (int)Math.Floor((y + 0.5) * 13.0 / flag.Height));
                        if ((stripe % 2) == 0)
                            g.FillRectangle(red, flag.Left, flag.Top + y, flag.Width, 1);
                    }
                RectangleF canton = new RectangleF(flag.Left, flag.Top,
                    flag.Width * 0.47f, flag.Height * 7f / 13f);
                using (Brush blue = new SolidBrush(Color.FromArgb(60, 59, 110)))
                    g.FillRectangle(blue, canton);
                // At this icon size, light star dots are legible without tiny glyphs.
                using (Brush stars = new SolidBrush(Color.White))
                {
                    float dot = Math.Max(1f, g.DpiX / 96f);
                    for (int rowIndex = 0; rowIndex < 3; rowIndex++)
                        for (int col = 0; col < 3; col++)
                            g.FillRectangle(stars, canton.Left + (col + 0.5f) * canton.Width / 3f,
                                canton.Top + (rowIndex + 0.5f) * canton.Height / 3f, dot, dot);
                }
            }
        }
        finally { g.Restore(saved); }
    }
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

    private static int Ui(int value, float scale)
    {
        return Math.Max(1, (int)Math.Round(value * scale));
    }

    private void DrawRightCheck(Graphics g, Rectangle row, bool enabled, float dpi)
    {
        float scale = Math.Max(1f, dpi / 96f);
        int size = Ui(14, scale);
        int x = Math.Max(row.Left + Ui(2, scale), row.Right - Ui(24, scale));
        int y = row.Top + Math.Max(1, (row.Height - size) / 2);
        Rectangle box = new Rectangle(x, y, size, size);
        SmoothingMode oldMode = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (Brush brush = new SolidBrush(enabled ? accent : disabled))
            g.FillRectangle(brush, box);
        using (Pen pen = new Pen(Color.White, Math.Max(1f, 1.8f * scale)))
        {
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            g.DrawLines(pen, new Point[] {
                new Point(box.Left + Ui(3, scale), box.Top + Ui(7, scale)),
                new Point(box.Left + Ui(6, scale), box.Top + Ui(10, scale)),
                new Point(box.Left + Ui(11, scale), box.Top + Ui(4, scale))
            });
        }
        g.SmoothingMode = oldMode;
    }

    private void DrawRightArrow(Graphics g, Rectangle row, bool enabled, float dpi)
    {
        float scale = Math.Max(1f, dpi / 96f);
        int cx = row.Right - Ui(15, scale);
        int cy = row.Top + (row.Height / 2);
        Color c = enabled ? arrow : disabled;
        using (Brush brush = new SolidBrush(c))
        {
            Point[] points = new Point[] {
                new Point(cx - Ui(2, scale), cy - Ui(4, scale)),
                new Point(cx + Ui(2, scale), cy),
                new Point(cx - Ui(2, scale), cy + Ui(4, scale))
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

        // Submenus retain their original subdued edge. The standard-target
        // root dropdown alone needs a neutral contrast boundary against the
        // main popup's near-identical dark surfaces (#161616 vs #191919).
        if (submenu && dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            using (Pen edgePen = new Pen(submenuEdge, 1f))
                e.Graphics.DrawRectangle(edgePen, 0, 0, dropDown.ClientSize.Width - 1, dropDown.ClientSize.Height - 1);
        }
        if (!submenu &&
            String.Equals(dropDown.Name, "DefaultTargetContextMenu", StringComparison.Ordinal) &&
            dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            float edgeWidth = Math.Max(1f, (float)Math.Round(e.Graphics.DpiX / 96f));
            float offset = edgeWidth / 2f;
            using (Pen edgePen = new Pen(Color.FromArgb(108, 108, 108), edgeWidth))
                e.Graphics.DrawRectangle(edgePen, offset, offset,
                    Math.Max(0f, dropDown.ClientSize.Width - edgeWidth),
                    Math.Max(0f, dropDown.ClientSize.Height - edgeWidth));
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
            DrawRightArrow(e.Graphics, row, item.Enabled, e.Graphics.DpiX);
        else if (item.Checked)
            DrawRightCheck(e.Graphics, row, item.Enabled, e.Graphics.DpiX);

        LenovoLocaleFlags.Draw(e.Graphics, item, row);
        e.Graphics.Restore(state);
    }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        ToolStripDropDown owner = e.ToolStrip as ToolStripDropDown;
        if (owner == null || e.Item == null || e.Graphics == null)
        {
            base.OnRenderItemText(e);
            return;
        }
        // LBS-144 native 240-DPI raster RED: base.OnRenderItemText printed
        // a 12px glyph on both 96-DPI and 240-DPI GDI+ surfaces, whereas
        // Graphics.DrawString produces 12px and 30px respectively. Do not
        // multiply 9pt fonts: render typographic points on the target HDC.
        Rectangle row = FullRowBounds(owner, e.Item);
        Rectangle text;
        if (LenovoLocaleFlags.GetLocale(e.Item) != null)
        {
            // Preserve the full language label and dedicated, DPI-scaled flag.
            text = LenovoLocaleFlags.GetTextBounds(e.Item, row, e.Graphics.DpiX);
            // LBS-117: language labels expose their expanded text rectangle.
            e.TextRectangle = text;
        }
        else
        {
            // The native item TextRectangle may carry a stale 96-DPI height
            // or a hidden image gutter. Use full item-local row coordinates.
            int left = row.Left + Math.Max(0, e.Item.Padding.Left);
            int right = row.Right - Math.Max(0, e.Item.Padding.Right);
            text = new Rectangle(left, row.Top, Math.Max(0, right - left), row.Height);
        }
        if (text.Width <= 0 || text.Height <= 0) return;
        GraphicsState state = e.Graphics.Save();
        try
        {
            e.Graphics.ResetClip();
            using (StringFormat format = (StringFormat)StringFormat.GenericTypographic.Clone())
            using (Brush brush = new SolidBrush(e.TextColor))
            {
                format.Alignment = StringAlignment.Near;
                format.LineAlignment = StringAlignment.Center;
                format.FormatFlags |= StringFormatFlags.NoWrap;
                format.Trimming = StringTrimming.EllipsisCharacter;
                format.HotkeyPrefix = System.Drawing.Text.HotkeyPrefix.Show;
                Font font = e.TextFont ?? e.Item.Font;
                e.Graphics.DrawString(e.Text ?? String.Empty, font, brush, text, format);
            }
        }
        finally { e.Graphics.Restore(state); }
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
    // ToolStrip's default Down key may leave an unavailable or disabled menu
    // item selected. Navigate the visible enabled actions explicitly while
    // retaining native Right/Left/Enter/Escape handling and actual Click events.
    public static bool SelectEnabledArrowItem(ToolStripDropDown menu, Keys keyData)
    {
        Keys key = keyData & Keys.KeyCode;
        if (key != Keys.Up && key != Keys.Down) return false;
        if (menu == null || menu.IsDisposed) return true;
        int count = menu.Items.Count;
        if (count == 0) return true;
        int start = key == Keys.Up ? 0 : -1;
        for (int i = 0; i < count; i++)
            if (menu.Items[i].Selected) { start = i; break; }
        int direction = key == Keys.Up ? -1 : 1;
        for (int offset = 1; offset <= count; offset++)
        {
            int index = ((start + direction * offset) % count + count) % count;
            ToolStripMenuItem candidate = menu.Items[index] as ToolStripMenuItem;
            if (candidate == null || !candidate.Available || !candidate.Enabled) continue;
            candidate.Select();
            InvalidateWholeMenu(menu);
            return true;
        }
        return true;
    }

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
        // Native keyboard selection must outrank the last stationary pointer
        // position. WinForms also updates Selected during actual mouse hover,
        // retaining pointer behavior while keeping arrow focus visible.
        foreach (ToolStripItem candidate in menu.Items)
        {
            ToolStripMenuItem menuItem = candidate as ToolStripMenuItem;
            if (menuItem == null || !menuItem.Available) continue;
            if (menuItem.Pressed || menuItem.Selected) return menuItem;
        }
        try
        {
            Point point = menu.PointToClient(Control.MousePosition);
            if (menu.ClientRectangle.Contains(point))
            {
                ToolStripMenuItem hit = HitTestRow(menu, point) as ToolStripMenuItem;
                if (hit != null && hit.Available) return hit;
            }
        }
        catch { }
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
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    public int TargetWidth { get; set; }
    public LenovoContextMenuStrip()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    // NotifyIcon's native context-menu path establishes a foreground HWND.
    // This tray menu is manually positioned (mixed-DPI safety), so restore
    // native keyboard activation without touching its placement or handlers.
    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        if (Visible && AutoClose && IsHandleCreated)
        {
            SetForegroundWindow(Handle);
            Focus();
        }
    }

    protected override bool ProcessDialogKey(Keys keyData)
    {
        if (LenovoMenuLayout.SelectEnabledArrowItem(this, keyData)) return true;
        return base.ProcessDialogKey(keyData);
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

    protected override bool ProcessDialogKey(Keys keyData)
    {
        if (LenovoMenuLayout.SelectEnabledArrowItem(this, keyData)) return true;
        return base.ProcessDialogKey(keyData);
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

    // The popup scales the control bounds from immutable 96-DPI geometry.
    // Scale this owner-drawn glyph exactly once from its paint-surface DPI;
    // the Windows SystemAware host will map the resulting pixels to a 100%
    // secondary display. Neither OS display position nor Font.Size is scaled.
    public static Rectangle GetGlyphBounds(Size clientSize, float dpi)
    {
        if (clientSize.Width <= 0 || clientSize.Height <= 0) return Rectangle.Empty;
        float scale = dpi > 0f ? Math.Max(1f, Math.Min(5f, dpi / 96f)) : 1f;
        int designSide = (int)Math.Round(18f * scale, MidpointRounding.AwayFromZero);
        int availableSide = Math.Min(clientSize.Width - 2, clientSize.Height - 2);
        if (availableSide < 1) return Rectangle.Empty;
        int side = Math.Min(designSide, availableSide);
        return new Rectangle((clientSize.Width - side) / 2,
                             (clientSize.Height - side) / 2, side, side);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        float scale = e.Graphics.DpiX > 0f ? Math.Max(1f, Math.Min(5f, e.Graphics.DpiX / 96f)) : 1f;
        Rectangle box = GetGlyphBounds(ClientSize, e.Graphics.DpiX);
        if (!box.IsEmpty)
        {
            Color fill = Checked ? (hovering ? HoverColor : AccentColor) : BoxBackColor;
            using (Brush b = new SolidBrush(fill)) e.Graphics.FillRectangle(b, box);
            using (Pen p = new Pen(Checked ? AccentColor : BoxBorderColor, Math.Max(1f, scale)))
                e.Graphics.DrawRectangle(p, box);
            if (Checked)
            {
                using (Pen p = new Pen(Color.White, 1.8f * scale))
                {
                    p.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                    p.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                    e.Graphics.DrawLines(p, new PointF[] {
                        new PointF(box.Left + box.Width * 0.24f, box.Top + box.Height * 0.52f),
                        new PointF(box.Left + box.Width * 0.42f, box.Top + box.Height * 0.72f),
                        new PointF(box.Left + box.Width * 0.76f, box.Top + box.Height * 0.29f)
                    });
                }
            }
        }
        int textLeft = (int)Math.Round(24f * scale, MidpointRounding.AwayFromZero);
        if (!String.IsNullOrEmpty(Text))
            TextRenderer.DrawText(e.Graphics, Text, Font,
                new Rectangle(textLeft, 0, Math.Max(0, Width - textLeft), Height),
                Enabled ? ForeColor : Color.FromArgb(105,105,105),
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
    }
}


// Configuration-only drawing. Native Button and CheckBox retain input,
// enabled state, tab order and click semantics; painting does not dispatch.
public static class LenovoSettingsInk
{
    public static int Px(float dpi, int value)
    { return Math.Max(1, (int)Math.Round(value * Math.Max(96f, dpi) / 96f)); }

    public static Color Muted(bool enabled)
    { return SystemInformation.HighContrast ? (enabled ? SystemColors.ControlText : SystemColors.GrayText)
        : (enabled ? Color.FromArgb(184,184,184) : Color.FromArgb(146,146,146)); }

    public static void DrawIcon(Graphics g, string key, Rectangle bounds, Color ink)
    {
        if (bounds.Width <= 0 || bounds.Height <= 0) return;
        GraphicsState state = g.Save();
        try {
            g.TranslateTransform(bounds.X, bounds.Y);
            g.ScaleTransform(bounds.Width / 24f, bounds.Height / 24f);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (Pen p = new Pen(ink, 1.6f)) {
                p.StartCap = p.EndCap = LineCap.Round;
                p.LineJoin = LineJoin.Round;
                switch (key) {
                    case "autostart":
                        g.DrawArc(p, 4, 4, 16, 16, -55, 290);
                        g.DrawLine(p, 12, 2, 12, 11); break;
                    case "system-setup":
                        g.DrawLines(p, new Point[] { new Point(20,3), new Point(15,3), new Point(12,6), new Point(13,10), new Point(4,19), new Point(7,22), new Point(16,13), new Point(20,14), new Point(23,10), new Point(23,6), new Point(19,10), new Point(16,7), new Point(20,3) }); break;
                    case "system-remove":
                        g.DrawLine(p, 4, 6, 20, 6);
                        g.DrawLines(p,new Point[] { new Point(8,6),new Point(8,3),new Point(16,3),new Point(16,6) });
                        g.DrawLines(p,new Point[] { new Point(6,7),new Point(7,21),new Point(17,21),new Point(18,7) });
                        g.DrawLine(p,10,10,10,17); g.DrawLine(p,14,10,14,17); break;
                    case "update-check":
                        g.DrawArc(p,4,4,16,16,-75,310);
                        g.DrawLines(p,new Point[] { new Point(20,3),new Point(20,10),new Point(13,10) }); break;
                    case "update-install":
                    case "diagnostics-upload":
                        bool up = key == "diagnostics-upload";
                        g.DrawLine(p,12,3,12,16);
                        if (up) g.DrawLines(p,new Point[] { new Point(7,8),new Point(12,3),new Point(17,8) });
                        else g.DrawLines(p,new Point[] { new Point(7,11),new Point(12,16),new Point(17,11) });
                        g.DrawLines(p,new Point[] { new Point(4,15),new Point(4,21),new Point(20,21),new Point(20,15) }); break;
                    case "preferences-drive":
                        g.DrawRectangle(p,3,5,18,14); g.DrawLine(p,3,14,21,14); g.DrawEllipse(p,6,16,1,1); g.DrawLine(p,10,17,17,17); break;
                    case "preferences-json":
                        g.DrawLines(p,new Point[] {new Point(5,3),new Point(14,3),new Point(19,8),new Point(19,21),new Point(5,21),new Point(5,3)});
                        g.DrawLines(p,new Point[] {new Point(14,3),new Point(14,8),new Point(19,8)});
                        g.DrawLines(p,new Point[] {new Point(10,11),new Point(8,11),new Point(8,14),new Point(7,15),new Point(8,16),new Point(8,19),new Point(10,19)});
                        g.DrawLines(p,new Point[] {new Point(14,11),new Point(16,11),new Point(16,14),new Point(17,15),new Point(16,16),new Point(16,19),new Point(14,19)}); break;
                    case "preferences-language":
                        g.DrawEllipse(p,3,3,18,18); g.DrawEllipse(p,8,3,8,18); g.DrawLine(p,3,12,21,12); break;
                    case "preferences-alias":
                        g.DrawLines(p,new Point[] {new Point(4,6),new Point(13,6),new Point(21,14),new Point(14,21),new Point(4,11),new Point(4,6)}); g.DrawEllipse(p,7,8,2,2); break;
                    case "preferences-visible":
                        g.DrawArc(p,2,5,20,14,180,180); g.DrawArc(p,2,5,20,14,0,180); g.DrawEllipse(p,9,9,6,6); break;
                    case "preferences-order":
                        g.DrawLine(p,7,4,7,20); g.DrawLines(p,new Point[] {new Point(3,8),new Point(7,4),new Point(11,8)});
                        g.DrawLine(p,17,4,17,20); g.DrawLines(p,new Point[] {new Point(13,16),new Point(17,20),new Point(21,16)}); break;
                    case "preferences-shield":
                        g.DrawLines(p,new Point[] {new Point(12,3),new Point(21,6),new Point(20,15),new Point(12,22),new Point(4,15),new Point(3,6),new Point(12,3)});
                        g.DrawLines(p,new Point[] {new Point(8,12),new Point(11,15),new Point(16,9)}); break;
                    case "preferences-lock":
                        g.DrawArc(p,7,3,10,12,180,180); g.DrawRectangle(p,5,10,14,11); g.DrawLine(p,12,14,12,17); break;
                    case "preferences-export":
                    case "preferences-import":
                        g.DrawLines(p,new Point[] { new Point(4,3),new Point(13,3),new Point(18,8),new Point(18,21),new Point(4,21),new Point(4,3) });
                        g.DrawLines(p,new Point[] { new Point(13,3),new Point(13,8),new Point(18,8) });
                        if (key == "preferences-export") {
                            g.DrawLine(p,8,14,22,14);
                            g.DrawLines(p,new Point[] { new Point(18,10),new Point(22,14),new Point(18,18) });
                        } else {
                            g.DrawLine(p,22,14,8,14);
                            g.DrawLines(p,new Point[] { new Point(12,10),new Point(8,14),new Point(12,18) });
                        }
                        break;
                    case "diagnostics-save":
                        g.DrawLines(p,new Point[] { new Point(5,3),new Point(14,3),new Point(19,8),new Point(19,21),new Point(5,21),new Point(5,3) });
                        g.DrawLines(p,new Point[] { new Point(14,3),new Point(14,8),new Point(19,8) });
                        g.DrawLine(p,8,12,16,12); g.DrawLine(p,8,16,16,16); break;
                }
            }
        } finally { g.Restore(state); }
    }

    public static Rectangle TextBounds(Rectangle bounds, float dpi, bool language)
    {
        int left = Px(dpi, language ? 42 : 44), right = Px(dpi, language ? 9 : 12);
        return new Rectangle(left, 0, Math.Max(0, bounds.Width-left-right), bounds.Height);
    }

    public static void DrawTextPair(Graphics g, Rectangle bounds, Font titleFont, Font subtitleFont,
        string title, string subtitle, Color titleInk, Color secondaryInk)
    {
        int top = Px(g.DpiX,5);
        int h = Math.Max(1,(bounds.Height-top*2)/2);
        TextFormatFlags flags = TextFormatFlags.Left | TextFormatFlags.VerticalCenter |
            TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix |
            TextFormatFlags.PreserveGraphicsClipping;
        TextRenderer.DrawText(g,title ?? "",titleFont,new Rectangle(bounds.X,top,bounds.Width,h),titleInk,flags);
        TextRenderer.DrawText(g,subtitle ?? "",subtitleFont,new Rectangle(bounds.X,top+h,bounds.Width,h),secondaryInk,flags);
    }

    public static void DrawFocus(Graphics g, Rectangle bounds, Color fg, Color bg)
    {
        bounds.Inflate(-Px(g.DpiX,3),-Px(g.DpiX,3));
        if (bounds.Width > 0 && bounds.Height > 0) ControlPaint.DrawFocusRectangle(g,bounds,fg,bg);
    }
}

// LBS-252: the same glyph renderer and layout are used in every state.
// Header icon ink is independent of native disabled text rendering.
// Keep the native Button adapter, focus cues, and all input/admission semantics.
public sealed class LenovoHeaderIconButton : Button
{
    public bool InfoIcon { get; set; }
    public LenovoHeaderIconButton()
    {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnEnabledChanged(EventArgs e)
    { base.OnEnabledChanged(e); Invalidate(); }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        Color ink = SystemInformation.HighContrast
            ? (Enabled ? SystemColors.ControlText : SystemColors.GrayText)
            : (Enabled ? ForeColor : Color.FromArgb(119,119,119));
        if (SystemInformation.HighContrast) {
            Rectangle center = ClientRectangle;
            int inset = Math.Max(2, Math.Min(center.Width,center.Height)/7);
            center.Inflate(-inset,-inset);
            using (SolidBrush surface = new SolidBrush(SystemColors.Control))
                if (center.Width > 0 && center.Height > 0) e.Graphics.FillRectangle(surface,center);
        }
        float size = Math.Min(ClientSize.Width,ClientSize.Height) * 0.60f;
        if (size <= 0) return;
        GraphicsState saved = e.Graphics.Save();
        try {
            e.Graphics.TranslateTransform((ClientSize.Width-size)/2f,(ClientSize.Height-size)/2f);
            e.Graphics.ScaleTransform(size/24f,size/24f);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (Pen p = new Pen(ink,2.4f)) {
                p.StartCap = p.EndCap = LineCap.Round;
                p.LineJoin = LineJoin.Round;
                if (InfoIcon) {
                    e.Graphics.DrawEllipse(p,2.5f,2.5f,19f,19f);
                    e.Graphics.DrawLine(p,12f,11f,12f,17f);
                    using (SolidBrush dot = new SolidBrush(ink))
                        e.Graphics.FillEllipse(dot,10.7f,6.1f,2.6f,2.6f);
                } else {
                    e.Graphics.DrawArc(p,3f,3f,18f,18f,185f,153f);
                    e.Graphics.DrawLines(p,new PointF[] { new PointF(16f,8f),new PointF(21f,8f),new PointF(21f,3f) });
                    e.Graphics.DrawArc(p,3f,3f,18f,18f,5f,153f);
                    e.Graphics.DrawLines(p,new PointF[] { new PointF(8f,16f),new PointF(3f,16f),new PointF(3f,21f) });
                }
            }
        }
        finally { e.Graphics.Restore(saved); }
    }
}

// Button retains native input, accessibility, Enabled and Click semantics.
public sealed class LenovoCustomizeButton : Button
{
    private bool hovering, mousePressed, keyPressed;
    public bool PointerActivation { get; private set; }

    // Scope provenance to the native mouse-up dispatch, not hover or a stale press.
    // Keyboard/PerformClick activation retains the ordinary keyboard cue.
    protected override void WndProc(ref Message m)
    {
        if (m.Msg != 0x0202) { base.WndProc(ref m); return; } // WM_LBUTTONUP
        PointerActivation = true;
        try { base.WndProc(ref m); }
        finally { PointerActivation = false; }
    }

    public LenovoCustomizeButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    { base.OnMouseEnter(e); hovering = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e)
    { base.OnMouseLeave(e); hovering = false; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e)
    { mousePressed = e.Button == MouseButtons.Left; base.OnMouseDown(e); Invalidate(); }
    protected override void OnMouseUp(MouseEventArgs e)
    { mousePressed = false; base.OnMouseUp(e); Invalidate(); }
    protected override void OnMouseCaptureChanged(EventArgs e)
    { mousePressed = false; base.OnMouseCaptureChanged(e); Invalidate(); }
    protected override void OnKeyDown(KeyEventArgs e)
    { if (e.KeyCode == Keys.Space) keyPressed = true; base.OnKeyDown(e); Invalidate(); }
    protected override void OnKeyUp(KeyEventArgs e)
    { if (e.KeyCode == Keys.Space) keyPressed = false; base.OnKeyUp(e); Invalidate(); }
    protected override void OnGotFocus(EventArgs e)
    { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e)
    { keyPressed = false; base.OnLostFocus(e); Invalidate(); }
    protected override void OnEnabledChanged(EventArgs e)
    {
        mousePressed = keyPressed = false;
        hovering = Enabled && IsHandleCreated && Visible &&
            ClientRectangle.Contains(PointToClient(Cursor.Position));
        base.OnEnabledChanged(e);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        bool pressed = Enabled && (keyPressed || (mousePressed && hovering));
        Color bg = pressed ? FlatAppearance.MouseDownBackColor :
            Enabled && hovering ? FlatAppearance.MouseOverBackColor : BackColor;
        if (bg.IsEmpty) bg = BackColor;
        Color ink = Enabled ? ForeColor : Color.FromArgb(138,138,138);
        using (SolidBrush brush = new SolidBrush(bg))
            e.Graphics.FillRectangle(brush, ClientRectangle);
        TextRenderer.DrawText(e.Graphics, Text, Font, ClientRectangle, ink,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter |
            TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix |
            TextFormatFlags.PreserveGraphicsClipping);
        if (Enabled && Focused && ShowFocusCues) {
            Rectangle focus = ClientRectangle;
            focus.Inflate(-3,-3);
            if (focus.Width > 0 && focus.Height > 0)
                ControlPaint.DrawFocusRectangle(e.Graphics, focus, ink, bg);
        }
    }
}

public sealed class LenovoSettingsActionButton : Button
{
    public string ActionIcon { get; set; }
    public string LocaleCode { get; set; }
    public string Subtitle { get; set; }
    public Font TitleFont { get; set; }
    public Font SubtitleFont { get; set; }
    public Color HoverSurface { get; set; }
    public Color SelectedSurface { get; set; }
    public Color AccentColor { get; set; }
    public bool LanguageSelected { get; set; }
    public bool Destructive { get; set; }
    public bool Separator { get; set; }
    private bool hovering, pressed;

    public LenovoSettingsActionButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        HoverSurface = Color.FromArgb(41,41,41);
        SelectedSurface = Color.FromArgb(44,25,24);
        AccentColor = Color.FromArgb(225,37,27);
    }
    protected override void OnMouseEnter(EventArgs e) { hovering = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovering = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { pressed = e.Button == MouseButtons.Left; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnMouseCaptureChanged(EventArgs e) { pressed = false; Invalidate(); base.OnMouseCaptureChanged(e); }
    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }

    protected override AccessibleObject CreateAccessibilityInstance()
    {
        if (String.IsNullOrEmpty(LocaleCode)) return base.CreateAccessibilityInstance();
        return new LanguageAccessible(this);
    }
    private sealed class LanguageAccessible : Control.ControlAccessibleObject
    {
        private readonly LenovoSettingsActionButton button;
        public LanguageAccessible(LenovoSettingsActionButton owner) : base(owner) { button = owner; }
        public override AccessibleRole Role { get { return AccessibleRole.RadioButton; } }
        public override AccessibleStates State {
            get { return base.State | AccessibleStates.Selectable |
                (button.LanguageSelected ? AccessibleStates.Selected | AccessibleStates.Checked : AccessibleStates.None); }
        }
        public override void DoDefaultAction() { if (button.Enabled) button.PerformClick(); }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        bool language = !String.IsNullOrEmpty(LocaleCode);
        bool hc = SystemInformation.HighContrast;
        Color bg = hc ? (LanguageSelected ? SystemColors.Highlight : SystemColors.Control) :
            (Enabled && (LanguageSelected || pressed) ? SelectedSurface : Enabled && hovering ? HoverSurface : BackColor);
        Color fg = hc ? (Enabled ? (LanguageSelected ? SystemColors.HighlightText : SystemColors.ControlText) : SystemColors.GrayText) :
            (!Enabled ? LenovoSettingsInk.Muted(false) : Destructive ? Color.FromArgb(239,86,78) : ForeColor);
        g.Clear(bg);
        float dpi = g.DpiX;
        int px = LenovoSettingsInk.Px(dpi,1);
        Rectangle text = LenovoSettingsInk.TextBounds(ClientRectangle,dpi,language);
        if (language) {
            int fw = LenovoSettingsInk.Px(dpi,16), fh = LenovoSettingsInk.Px(dpi,12);
            LenovoLocaleFlags.DrawFlag(g,LocaleCode,new Rectangle(LenovoSettingsInk.Px(dpi,12),(Height-fh)/2,fw,fh));
            TextRenderer.DrawText(g,Text,Font,text,fg,TextFormatFlags.Left | TextFormatFlags.VerticalCenter |
                TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis);
            using (Pen border = new Pen(hc ? SystemColors.ControlText : LanguageSelected ? AccentColor : Color.FromArgb(68,68,68),px))
                g.DrawRectangle(border,px/2,px/2,Math.Max(0,Width-px-1),Math.Max(0,Height-px-1));
        } else {
            int side = LenovoSettingsInk.Px(dpi,22);
            LenovoSettingsInk.DrawIcon(g,ActionIcon,new Rectangle(LenovoSettingsInk.Px(dpi,11),(Height-side)/2,side,side),
                Destructive && Enabled ? fg : LenovoSettingsInk.Muted(Enabled));
            LenovoSettingsInk.DrawTextPair(g,text,TitleFont ?? Font,SubtitleFont ?? Font,Text,Subtitle,fg,LenovoSettingsInk.Muted(Enabled));
            if (Separator) using (Pen p = new Pen(hc ? SystemColors.ControlDark : Color.FromArgb(57,57,57),px))
                g.DrawLine(p,LenovoSettingsInk.Px(dpi,44),Height-px,Math.Max(0,Width-LenovoSettingsInk.Px(dpi,12)),Height-px);
        }
        if (Focused && ShowFocusCues) LenovoSettingsInk.DrawFocus(g,ClientRectangle,fg,bg);
    }
}

public sealed class LenovoSettingsAutostartLabel : Label
{
    public string Subtitle { get; set; }
    public Font TitleFont { get; set; }
    public Font SubtitleFont { get; set; }
    public Color HoverSurface { get; set; }
    internal bool TileHovered { get; set; }
    public LenovoSettingsAutostartLabel()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g=e.Graphics;
        bool hc=SystemInformation.HighContrast;
        g.Clear(hc ? SystemColors.Control : Enabled && TileHovered ? HoverSurface : BackColor);
        int side=LenovoSettingsInk.Px(g.DpiX,22), left=LenovoSettingsInk.Px(g.DpiX,44);
        Color fg=hc ? (Enabled ? SystemColors.ControlText : SystemColors.GrayText) :
            (Enabled ? ForeColor : LenovoSettingsInk.Muted(false));
        LenovoSettingsInk.DrawIcon(g,"autostart",new Rectangle(LenovoSettingsInk.Px(g.DpiX,11),(Height-side)/2,side,side),LenovoSettingsInk.Muted(Enabled));
        LenovoSettingsInk.DrawTextPair(g,new Rectangle(left,0,Math.Max(0,Width-left-LenovoSettingsInk.Px(g.DpiX,3)),Height),
            TitleFont ?? Font,SubtitleFont ?? Font,Text,Subtitle,fg,LenovoSettingsInk.Muted(Enabled));
    }
}

public sealed class LenovoSettingsToggle : CheckBox
{
    public Color AccentColor { get; set; }
    public Color HoverSurface { get; set; }
    internal bool TileHovered { get; set; }
    public LenovoSettingsToggle()
    {
        AutoCheck=false; AutoSize=false;
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw,true);
    }
    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g=e.Graphics;
        bool hc=SystemInformation.HighContrast;
        Color bg=hc ? SystemColors.Control : Enabled && TileHovered ? HoverSurface : BackColor;
        g.Clear(bg);
        int w=Math.Min(Math.Max(0,Width-4),LenovoSettingsInk.Px(g.DpiX,38));
        int h=Math.Min(Math.Max(0,Height-4),LenovoSettingsInk.Px(g.DpiX,22));
        if (w >= h && h >= 4) {
            Rectangle r=new Rectangle((Width-w)/2,(Height-h)/2,w,h);
            Color fill=hc ? (Checked ? SystemColors.Highlight : SystemColors.ControlDark) :
                (Checked && Enabled ? AccentColor : Color.FromArgb(85,85,85));
            g.SmoothingMode=SmoothingMode.AntiAlias;
            using (GraphicsPath path=new GraphicsPath()) {
                path.AddArc(r.Left,r.Top,h,h,90,180);
                path.AddArc(r.Right-h,r.Top,h,h,270,180);
                path.CloseFigure();
                using (Brush brush=new SolidBrush(fill)) g.FillPath(brush,path);
            }
            int pad=LenovoSettingsInk.Px(g.DpiX,3), d=Math.Max(1,h-2*pad);
            using (Brush brush=new SolidBrush(hc ? SystemColors.ControlText : Enabled ? Color.White : Color.FromArgb(155,155,155)))
                g.FillEllipse(brush,Checked ? r.Right-pad-d : r.Left+pad,r.Top+pad,d,d);
        }
        // The settings switch is the initial keyboard target even after a
        // mouse-open. Show its real focus immediately, without changing the
        // system's cue policy or the focus state of any other control.
        if (Enabled && Focused) LenovoSettingsInk.DrawFocus(g,ClientRectangle,SystemColors.ControlText,bg);
    }
}

// One hover owner for both native autostart hit areas. Screen coordinates
// preserve the highlight across sibling transitions and clipped scrolling.
// Settings input is independent of business actions. Native hit testing
// distinguishes a visible pointer target from keyboard focus, and the modal
// enable state rejects hover underneath a nested dialog.
public static class LenovoSettingsWindowInput
{
    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")]
    private static extern bool IsWindowEnabled(IntPtr window);
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    public static bool IsPointerOnSurface(Form form, Point pointer)
    {
        if (form == null || form.IsDisposed || !form.Visible ||
            !form.IsHandleCreated || !IsWindowEnabled(form.Handle)) return false;
        IntPtr hit = WindowFromPoint(pointer);
        return hit != IntPtr.Zero && GetAncestor(hit, 2) == form.Handle;
    }

    // Called once, at the end of the user-initiated settings Shown event
    // after the owner dimmer/connector has been shown. Respect OS foreground
    // restrictions; never use periodic activation or injected input.
    public static void ActivateInitialSurface(Form form)
    {
        if (form == null || form.IsDisposed || !form.Visible ||
            !form.IsHandleCreated || !IsWindowEnabled(form.Handle)) return;
        if (GetForegroundWindow() != form.Handle) SetForegroundWindow(form.Handle);
        if (!form.ContainsFocus) form.Activate();
    }
}

public sealed class LenovoSettingsAutostartHover
{
    private readonly LenovoSettingsAutostartLabel label;
    private readonly LenovoSettingsToggle toggle;
    private readonly Form form;

    public LenovoSettingsAutostartHover(LenovoSettingsAutostartLabel label, LenovoSettingsToggle toggle)
    {
        this.label = label;
        this.toggle = toggle;
        form = label.FindForm();
        foreach (Control control in new Control[] { label, toggle }) {
            control.MouseEnter += Refresh;
            control.MouseLeave += Refresh;
            control.MouseMove += Refresh;
            control.EnabledChanged += Refresh;
            control.VisibleChanged += Refresh;
            control.LocationChanged += Refresh;
            control.SizeChanged += Refresh;
        }
        for (Control parent = label.Parent; parent != null; parent = parent.Parent) {
            parent.LocationChanged += Refresh;
            parent.SizeChanged += Refresh;
        }
        if (form != null) {
            form.Activated += Refresh;
            form.Deactivate += Clear;
        }
    }

    private static bool ContainsVisiblePoint(Control control, Point screen)
    {
        for (Control current = control; current != null; current = current.Parent) {
            if (!current.Visible || !current.IsHandleCreated ||
                !current.RectangleToScreen(current.ClientRectangle).Contains(screen)) return false;
        }
        return true;
    }

    private void Refresh(object sender, EventArgs e)
    {
        if (label.IsDisposed || toggle.IsDisposed) return;
        Point pointer = Control.MousePosition;
        SetHovered(label.Enabled && toggle.Enabled && LenovoSettingsWindowInput.IsPointerOnSurface(form, pointer) &&
            (ContainsVisiblePoint(label, pointer) || ContainsVisiblePoint(toggle, pointer)));
    }

    private void Clear(object sender, EventArgs e) { SetHovered(false); }

    private void SetHovered(bool hovered)
    {
        if (label.IsDisposed || toggle.IsDisposed) return;
        if (label.TileHovered == hovered && toggle.TileHovered == hovered) return;
        label.TileHovered = toggle.TileHovered = hovered;
        label.Invalidate();
        toggle.Invalidate();
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
        if (!thumb.IsEmpty && e.Y >= thumb.Top && e.Y < thumb.Bottom)
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
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility

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
$activationEvent = $null
$activationListener = $null
$singleInstanceMutexState = 'not-applicable'
$singleInstanceGraceMs = 500
if (-not $BootNextWorker -and -not $BackgroundRefresh -and -not $UpdateCheck -and -not $UpdatePrepare -and -not $DefaultTargetWorker) {
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
        if (Send-LbsActivationRequest) { exit 0 }
        # A genuine failed handoff is not treated as a successful activation.
        $startupLocale = Get-StartupRecoveryLocale
        Show-FatalMessage (Get-LocalizedStringCore -Key 'Startup.AlreadyRunningMessage' -Locale $startupLocale) -AllowRestart $false | Out-Null
        exit 2
    }
    # Publish the signal immediately after mutex ownership. If the primary
    # instance is still initializing, the AutoReset event retains the request
    # until its UI listener is installed (no polling or second tray owner).
    $activationEvent = New-LbsActivationEvent
}

$script:AppVersion = '1.10.0.0'
$script:Popup = $null
$script:TrayIcon = $null
$script:CurrentEntries = @()
$script:SelectedGuid = $null
$script:BootNextPendingGuid = $null
$script:BootNextSelectionDeferred = $false
$script:BootNextSelectionStartedUtc = [datetime]::MinValue
$script:BootNextSelectionResultPath = $null
$script:BootNextSelectionProcess = $null
$script:BootNextSelectionTimer = $null
$script:RestartButton = $null
$script:NextBootFirmwareReadVerified = $false
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
$script:DiagnosticsUploadMenuItem = $null
$script:DiagnosticsUploadState = $null
$script:DiagnosticsUploadTimer = $null

$script:SupportedTaskBrokerVersions = @('0.2.16')
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
$script:PreferencesMenuRoot = $null
$script:PreferencesExportMenuItem = $null
$script:PreferencesImportMenuItem = $null
$script:PreferencesUiActive = $false
$script:TrayExitMenuItem = $null
$script:RefreshButton = $null
$script:SystemStatusButton = $null
$script:SystemStatusCapabilities = $null
$script:SystemStatusManagerObservedUtc = $null
$script:SystemStatusManagerObservedHash = $null
$script:SystemStatusEntriesObservedUtc = $null
$script:SystemStatusEntriesObservedHash = $null
$script:SystemStatusReadinessObservedUtc = $null
$script:SystemStatusNextObservedUtc = $null
$script:SystemStatusDefaultObservedUtc = $null
$script:SystemStatusDefaultEvidence = 'unknown'
$script:SystemStatusLastRefresh = 'unknown'
$script:SystemStatusDriftFailed = $false
$script:RefreshButtonHovered = $false
$script:HeaderTitleLabel = $null
$script:HeaderStatusLabel = $null
$script:LegacyAutostartTaskName = 'Lenovo Boot Menu Tray Autostart'
$script:AutostartRunValueName = 'Lenovo Boot Selector'
$script:LegacyAutostartRunValueName = 'Lenovo Boot Menu Tray'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:SettingsLoadState = $null
$script:UiLocale = 'en-US'
$script:LocalePreferenceSource = 'default'
$script:LocalePreferenceNeedsConfirmation = $false
$script:DefaultGuid = $null
$script:DefaultTargetReadUncertain = $false
$script:DefaultTargetChangePending = $false
$script:DefaultTargetChangeRequestedGuid = $null
$script:DefaultTargetChangeOperation = ''
$script:DefaultTargetChangeStage = ''
$script:DefaultTargetChangeWorkerStarted = $false
$script:DefaultTargetChangeStartedUtc = [datetime]::MinValue
$script:DefaultTargetChangeProcess = $null
$script:DefaultTargetChangeTimer = $null
$script:DefaultTargetChangeResultPath = $null
$script:DefaultTargetChangeProgressPath = $null
$script:LegacyDefaultGuid = $null
$script:DefaultButton = $null
$script:DefaultValueLabel = $null
$script:DefaultArrowLabel = $null
$script:DefaultInteractionEnabled = $false
$script:RestartTargetLabel = $null
$script:RestartUseDefaultButton = $null
$script:ActiveAuxiliaryPopup = $null
$script:ActiveOwnedDialog = $null
$script:DefaultContextRoot = $null
$script:LegacySessionRestoreRegistryPath = 'HKCU:\Volatile Environment'
$script:LegacySessionRestoreValueName = 'LenovoBootMenuTrayDefaultRestoreProcessed'
$script:RestartMenuItem = $null
$script:EntryOrder = @()
$script:HiddenEntryGuids = @()
$script:EntryAliases = @{}
$script:IsManageEntriesMode = $false
$script:ManageUndoHistory = $null
$script:ManageUndoInventory = @()
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

# LBS-144: read-only Win32 / DWM window DPI and coordinate-space telemetry.
# Screen/WinForms and GetWindowRect are caller-awareness dependent;
# DWM extended-frame bounds are physical desktop pixels. Never conflate them.
if (-not ('LenovoNativeDpiSnapshot' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class LenovoNativeDpiSnapshot
{
    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    private static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hwnd);
    [DllImport("user32.dll")]
    private static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")]
    private static extern int GetAwarenessFromDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")]
    private static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
    [DllImport("shcore.dll")]
    private static extern int GetProcessDpiAwareness(IntPtr process, out int awareness);
    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out RECT rect, int size);

    private static string Name(int n) {
        if (n == 0) return "Unaware";
        if (n == 1) return "SystemAware";
        if (n == 2) return "PerMonitorAware";
        return "Unknown";
    }
    public static Dictionary<string, object> Capture(IntPtr hwnd) {
        var result = new Dictionary<string, object>();
        result["hwndPresent"] = hwnd != IntPtr.Zero;
        result["windowDpi"] = 0;
        result["windowAwareness"] = "not-created";
        result["threadAwareness"] = "unavailable";
        result["processAwareness"] = "unavailable";
        result["windowRectAvailable"] = false;
        result["windowRectWidth"] = 0;
        result["windowRectHeight"] = 0;
        result["dwmPhysicalAvailable"] = false;
        result["dwmPhysicalWidth"] = 0;
        result["dwmPhysicalHeight"] = 0;
        try {
            int awareness;
            if (GetProcessDpiAwareness(IntPtr.Zero, out awareness) == 0)
                result["processAwareness"] = Name(awareness);
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            IntPtr thread = GetThreadDpiAwarenessContext();
            if (thread != IntPtr.Zero) {
                result["threadAwareness"] = Name(GetAwarenessFromDpiAwarenessContext(thread));
                result["threadPerMonitorV2"] = AreDpiAwarenessContextsEqual(thread, new IntPtr(-4));
            }
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        if (hwnd == IntPtr.Zero) return result;
        try { result["windowDpi"] = (int)GetDpiForWindow(hwnd); }
        catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            IntPtr ctx = GetWindowDpiAwarenessContext(hwnd);
            if (ctx != IntPtr.Zero) {
                result["windowAwareness"] = Name(GetAwarenessFromDpiAwarenessContext(ctx));
                result["windowPerMonitorV2"] = AreDpiAwarenessContextsEqual(ctx, new IntPtr(-4));
            } else result["windowAwareness"] = "unknown";
        } catch (EntryPointNotFoundException) { result["windowAwareness"] = "api-unavailable"; }
          catch (DllNotFoundException) { result["windowAwareness"] = "api-unavailable"; }
        try {
            RECT r;
            if (GetWindowRect(hwnd, out r)) {
                result["windowRectAvailable"] = true;
                result["windowRectLeft"] = r.Left;
                result["windowRectTop"] = r.Top;
                result["windowRectWidth"] = Math.Max(0,r.Right-r.Left);
                result["windowRectHeight"] = Math.Max(0,r.Bottom-r.Top);
            }
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            RECT r;
            int hr = DwmGetWindowAttribute(hwnd, 9, out r, Marshal.SizeOf(typeof(RECT)));
            if (hr == 0) {
                result["dwmPhysicalAvailable"] = true;
                result["dwmPhysicalLeft"] = r.Left;
                result["dwmPhysicalTop"] = r.Top;
                result["dwmPhysicalWidth"] = Math.Max(0,r.Right-r.Left);
                result["dwmPhysicalHeight"] = Math.Max(0,r.Bottom-r.Top);
            } else result["dwmHResult"] = hr;
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        return result;
    }
}
'@
}

function ConvertTo-LenovoDpiScale {
    param([Parameter(Mandatory=$true)][double]$Dpi)
    if ($Dpi -le 0) { throw 'DPI must be greater than zero.' }
    return [double]($Dpi / 96.0)
}

function Get-LenovoDpiWindowMetrics {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][string]$Role,
        [Parameter(Mandatory=$true)][string]$Phase,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0,
        [double]$PaintDpiX = 0.0,
        [double]$PaintDpiY = 0.0
    )
    # IMPORTANT: reading Control.Handle or Screen.FromControl on a pre-show
    # object may CREATE its HWND and mask the first-show bug under inspection.
    $created = [bool]$Control.IsHandleCreated
    $handle = if ($created) { $Control.Handle } else { [IntPtr]::Zero }
    $data = @{
        schemaVersion = 1
        role = $Role
        phase = $Phase
        controlType = $Control.GetType().Name
        visible = [bool]$Control.Visible
        winFormsLeft = [int]$Control.Left
        winFormsTop = [int]$Control.Top
        winFormsWidth = [int]$Control.Width
        winFormsHeight = [int]$Control.Height
        clientWidth = [int]$Control.ClientSize.Width
        clientHeight = [int]$Control.ClientSize.Height
    }
    $native = [LenovoNativeDpiSnapshot]::Capture($handle)
    foreach ($key in @($native.Keys)) { $data[$key] = $native[$key] }
    if ($data.windowDpi -gt 0) {
        $data.windowDpiScale = ConvertTo-LenovoDpiScale -Dpi ([double]$data.windowDpi)
        $data.windowDpiScalePercent = [Math]::Round(100 * $data.windowDpiScale,3)
    }
    if ($RequestedScale -gt 0) { $data.requestedScale = [double]$RequestedScale }
    if ($PaintDpiX -gt 0) { $data.paintDpiX = [double]$PaintDpiX }
    if ($PaintDpiY -gt 0) { $data.paintDpiY = [double]$PaintDpiY }
    if (-not $Screen) {
        $Screen = if ($created) {
            [System.Windows.Forms.Screen]::FromHandle($handle)
        } else {
            [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
        }
    }
    if ($Screen) {
        $data.screenPrimary = [bool]$Screen.Primary
        $data.screenBoundsLeft = [int]$Screen.Bounds.Left
        $data.screenBoundsTop = [int]$Screen.Bounds.Top
        $data.screenBoundsWidth = [int]$Screen.Bounds.Width
        $data.screenBoundsHeight = [int]$Screen.Bounds.Height
        $data.screenWorkLeft = [int]$Screen.WorkingArea.Left
        $data.screenWorkTop = [int]$Screen.WorkingArea.Top
        $data.screenWorkWidth = [int]$Screen.WorkingArea.Width
        $data.screenWorkHeight = [int]$Screen.WorkingArea.Height
        if (Get-Command Get-PopupMonitorDpiScale -CommandType Function -ErrorAction SilentlyContinue) {
            $reported = Get-PopupMonitorDpiScale -Screen $Screen
            if ($reported -and $reported.Factor -gt 0) {
                $data.monitorReportedScale = [double]$reported.Factor
                $data.monitorReportedScalePercent = [Math]::Round(100*[double]$reported.Factor,3)
            }
        }
    }
    if ($Control -is [System.Windows.Forms.Form]) {
        $data.autoScaleMode = [string]$Control.AutoScaleMode
    }
    # This is a theoretical font metric, NOT actual glyph raster height.
    if ($Control.Font -and $data.windowDpi -gt 0) {
        $data.controlFontPoints = [double]$Control.Font.SizeInPoints
        $data.fontLinePixelsAtWindowDpi = [Math]::Round(
            [double]$Control.Font.GetHeight([single]$data.windowDpi),2)
    }
    return $data
}

function Write-LenovoDpiWindowEvent {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][string]$Role,
        [Parameter(Mandatory=$true)][string]$Phase,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0,
        [double]$PaintDpiX = 0.0,
        [double]$PaintDpiY = 0.0
    )
    if (-not $script:RuntimeDiagnosticsAvailable) { return }
    try {
        $metrics = Get-LenovoDpiWindowMetrics -Control $Control -Role $Role -Phase $Phase -Screen $Screen -RequestedScale $RequestedScale -PaintDpiX $PaintDpiX -PaintDpiY $PaintDpiY
        Write-RuntimeDiagnosticEvent -Event 'DPI_WINDOW_SNAPSHOT' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData -Values $metrics)
    }
    catch { } # Read-only diagnostics never affect UI/boot execution.
}

function Register-LenovoDialogDpiWindowDiagnostics {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][string]$Role,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0
    )
    Write-LenovoDpiWindowEvent -Control $Form -Role $Role -Phase 'before-show' -Screen $Screen -RequestedScale $RequestedScale
    $roleCopy = [string]$Role
    $screenCopy = $Screen
    $scaleCopy = [double]$RequestedScale
    $Form.Add_Shown({
        Write-LenovoDpiWindowEvent -Control $this -Role $roleCopy -Phase 'shown' -Screen $screenCopy -RequestedScale $scaleCopy
    }.GetNewClosure())
    $paintRecorded = $false
    $Form.Add_Paint({
        param($sender,$paintArgs)
        if (-not $paintRecorded) {
            $paintRecorded = $true
            Write-LenovoDpiWindowEvent -Control $sender -Role $roleCopy -Phase 'paint' -Screen $screenCopy -RequestedScale $scaleCopy -PaintDpiX $paintArgs.Graphics.DpiX -PaintDpiY $paintArgs.Graphics.DpiY
        }
    }.GetNewClosure())
}

# LBS-144 P3: every active display, not just the selected monitor.
# Read-only; no display reconfiguration and no full device serial numbers.
function Get-LenovoMonitorTopologySnapshot {
    $items = @()
    foreach ($monitor in [System.Windows.Forms.Screen]::AllScreens) {
        $bounds = $monitor.Bounds
        $work = $monitor.WorkingArea
        $reportedPercent = 0
        $scaleSource = 'unavailable'
        if (Get-Command Get-PopupMonitorDpiScale -CommandType Function -ErrorAction SilentlyContinue) {
            try {
                $reported = Get-PopupMonitorDpiScale -Screen $monitor
                $reportedPercent = [int]$reported.Percent
                $scaleSource = [string]$reported.Source
            } catch { }
        }
        $items += [ordered]@{
            deviceName = [string]$monitor.DeviceName
            isPrimary = [bool]$monitor.Primary
            boundsLeft = [int]$bounds.Left
            boundsTop = [int]$bounds.Top
            boundsWidth = [int]$bounds.Width
            boundsHeight = [int]$bounds.Height
            workLeft = [int]$work.Left
            workTop = [int]$work.Top
            workWidth = [int]$work.Width
            workHeight = [int]$work.Height
            reportedScalePercent = [int]$reportedPercent
            scaleSource = [string]$scaleSource
        }
    }
    return $items
}

function Write-LenovoMonitorTopologyEvent {
    param(
        [Parameter(Mandatory=$true)][string]$Phase,
        [System.Windows.Forms.Screen]$Screen
    )
    if (-not $script:RuntimeDiagnosticsAvailable) { return }
    try {
        $monitors = @(Get-LenovoMonitorTopologySnapshot)
        $cursor = [System.Windows.Forms.Cursor]::Position
        $selectedName = if ($Screen) { [string]$Screen.DeviceName } else { '' }
        $awareness = if ('LenovoUiDpiAwarenessNative' -as [type]) {
            [LenovoUiDpiAwarenessNative]::ReadThreadAwareness()
        } else { 'unavailable' }
        $systemDpi = if ('LenovoUiDpiAwarenessNative' -as [type]) {
            [LenovoUiDpiAwarenessNative]::ReadSystemDpi()
        } else { 0 }
        Write-RuntimeDiagnosticEvent -Event 'MONITOR_TOPOLOGY_SNAPSHOT' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData -Values @{
            schemaVersion = 1
            phase = [string]$Phase
            screenCount = [int]$monitors.Count
            monitors = $monitors
            selectedDeviceName = $selectedName
            cursorX = [int]$cursor.X
            cursorY = [int]$cursor.Y
            threadAwareness = [string]$awareness
            systemDpi = [int]$systemDpi
        })
    } catch { } # Read-only telemetry cannot block UI or boot actions.
}

# LBS-144: independent, physical-pixel DPI layout for ToolStrip menus.
# A SystemAware PowerShell/WinForms host supplies the design 9pt text and
# fixed 260px menu independently of its 96/240 system DPI. Keep immutable
# geometry baselines; font point sizes stay at 9pt because GDI/WinForms
# converts points to pixels at its current DPI without further multiplication.
# Shared immutable 96-DPI action inset for flat action submenus.
function New-LenovoSubmenuActionPadding {
    return [System.Windows.Forms.Padding]::new(18,4,14,4)
}

function Get-LenovoScaledMenuPadding {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Padding]$Padding,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    return [System.Windows.Forms.Padding]::new(
        [int][Math]::Round($Padding.Left * $Scale),
        [int][Math]::Round($Padding.Top * $Scale),
        [int][Math]::Round($Padding.Right * $Scale),
        [int][Math]::Round($Padding.Bottom * $Scale))
}

# ToolStripItem.Height is already dependent on the host's current DPI.
# It is NOT a 96-DPI design value. The Lenovo menus contain only one-line
# items and separators; choose their immutable 96-DPI design heights here.
function Get-LenovoMenuDesignItemHeight {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripItem]$Item)
    if ($Item -is [System.Windows.Forms.ToolStripSeparator]) { return [int]6 }
    return [int]24
}

function Set-LenovoMenuDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid menu monitor scale.' }
    if (-not $script:LenovoMenuDesignBaselines) {
        $script:LenovoMenuDesignBaselines = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripDropDown,System.Object]'
    }
    if (-not $script:LenovoMenuDesignBaselines.ContainsKey($Menu)) {
        $widthProperty = $Menu.PSObject.Properties['TargetWidth']
        $width = if ($null -ne $widthProperty) { [int]$widthProperty.Value } else { 0 }
        $state = [pscustomobject]@{
            Width = $width
            Padding = $Menu.Padding
            ItemBases = (New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripItem,System.Object]')
            Scale = [double]0.0
        }
        $script:LenovoMenuDesignBaselines.Add($Menu,$state)
        $Menu.Add_Disposed({
            if ($script:LenovoMenuDesignBaselines) {
                [void]$script:LenovoMenuDesignBaselines.Remove($this)
            }
        })
    }
    $state = $script:LenovoMenuDesignBaselines[$Menu]
    foreach ($item in $Menu.Items) {
        if (-not $state.ItemBases.ContainsKey($item)) {
            $state.ItemBases.Add($item,[pscustomobject]@{
                Height = Get-LenovoMenuDesignItemHeight -Item $item
                Padding = $item.Padding
                FontStyle = $item.Font.Style
            })
        }
    }
    if ([Math]::Abs($state.Scale - $Scale) -lt 0.001) { return $false }
    $Menu.SuspendLayout()
    try {
        # Fonts remain 9pt: DPI affects the rendered pixel line height.
        # Submenus must not inherit any separately transformed parent font.
        $Menu.Font = [Drawing.Font]::new('Segoe UI',[single]9.0,[Drawing.FontStyle]::Regular)
        $Menu.Padding = Get-LenovoScaledMenuPadding -Padding $state.Padding -Scale $Scale
        if ($null -ne $Menu.PSObject.Properties['TargetWidth']) {
            $Menu.TargetWidth = [Math]::Max(1,[int][Math]::Round($state.Width * $Scale))
        }
        foreach ($item in $Menu.Items) {
            $base = $state.ItemBases[$item]
            $item.AutoSize = $false
            $item.Padding = Get-LenovoScaledMenuPadding -Padding $base.Padding -Scale $Scale
            $item.Font = [Drawing.Font]::new('Segoe UI',[single]9.0,[Drawing.FontStyle]$base.FontStyle)
            $item.Height = [Math]::Max(1,[int][Math]::Round($base.Height * $Scale))
        }
    }
    finally { $Menu.ResumeLayout($true) }
    $state.Scale = [double]$Scale
    return $true
}

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
    # Only one paint snapshot per opening, rather than every hover redraw.
    if (-not $script:LenovoDpiMenuPaintRecorded) {
        $script:LenovoDpiMenuPaintRecorded = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripDropDown,System.Boolean]'
    }
    $Menu.Add_Opening({
        try {
            $script:LenovoDpiMenuPaintRecorded[$this] = $false
            $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
            $factor = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
            [void](Set-LenovoMenuDpiLayout -Menu $this -Scale ([double]$factor))
            $this.Region = $null
            [LenovoMenuLayout]::PrepareItems($this)
            [LenovoMenuChrome]::Apply($this)
            Write-LenovoDpiWindowEvent -Control $this -Role $(if ($this.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'opening' -Screen $screen -RequestedScale ([double]$factor)
        } catch { }
    })
    $Menu.Add_Opened({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
            [LenovoMenuLayout]::PrepareItems($this)
            Write-LenovoDpiWindowEvent -Control $this -Role $(if ($this.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'opened'
        } catch { }
    })
    $Menu.Add_Paint({
        param($sender,$paintArgs)
        try {
            if ($sender.Visible -and -not $script:LenovoDpiMenuPaintRecorded[$sender]) {
                $script:LenovoDpiMenuPaintRecorded[$sender] = $true
                Write-LenovoDpiWindowEvent -Control $sender -Role $(if ($sender.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'paint' -PaintDpiX $paintArgs.Graphics.DpiX -PaintDpiY $paintArgs.Graphics.DpiY
            }
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

# LBS-244: common rendering, independent native ToolTip instances and timing.
function New-LenovoDarkTooltip {
    param([int]$InitialDelay = 350,[int]$ReshowDelay = 100,[int]$AutoPopDelay = 8000,[switch]$Animate)
    if (-not ('LenovoDarkTooltip' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;

public sealed class LenovoDarkTooltip : ToolTip {
    private readonly Func<Control, double> coordinateScale;
    private Control manualOwner;
    private Form manualForm;
    private string manualText;
    private static readonly Color Surface = Color.FromArgb(28,28,28);
    private static readonly Color Ink = Color.FromArgb(238,238,238);
    private static readonly Color Edge = Color.FromArgb(76,76,76);
    private const TextFormatFlags Flags = TextFormatFlags.WordBreak |
        TextFormatFlags.TextBoxControl | TextFormatFlags.NoPrefix |
        TextFormatFlags.NoPadding;

    public LenovoDarkTooltip(Func<Control, double> scale, int initial, int reshow, int duration, bool animate) {
        if (scale == null) throw new ArgumentNullException("scale");
        coordinateScale = scale;
        OwnerDraw = !SystemInformation.HighContrast;
        ShowAlways = true;
        UseAnimation = animate;
        UseFading = animate;
        InitialDelay = initial;
        ReshowDelay = reshow;
        AutoPopDelay = duration;
        StripAmpersands = false;
        if (OwnerDraw) {
            BackColor = Surface;
            ForeColor = Ink;
            Popup += OnHintPopup;
            Draw += OnHintDraw;
        }
    }

    private static double ValidScale(double scale) {
        if (Double.IsNaN(scale) || Double.IsInfinity(scale) || scale < 1 || scale > 5)
            throw new ArgumentOutOfRangeException("scale");
        return scale;
    }

    private static int Px(double n, double scale) {
        return Math.Max(1, (int)Math.Round(n * ValidScale(scale), MidpointRounding.AwayFromZero));
    }

    private static Font HintFont(double scale) {
        // Pixel units: the effective WinForms coordinate scale already
        // accounts for awareness/system DPI. Do not multiply point fonts.
        return new Font("Segoe UI", (float)(8.5 * 96.0 / 72.0 * ValidScale(scale)),
            FontStyle.Regular, GraphicsUnit.Pixel);
    }

    public static Size MeasureHint(string text, double scale, Rectangle work) {
        if (work.Width <= 0 || work.Height <= 0) throw new ArgumentException("Invalid work area.");
        int px = Px(10,scale), py = Px(6,scale);
        int maxWidth = Math.Min(work.Width, Px(340,scale));
        int textWidth = Math.Max(1,maxWidth - 2 * px);
        using (Font font = HintFont(scale)) {
            Size measured = TextRenderer.MeasureText(text ?? String.Empty, font,
                new Size(textWidth,32767), Flags);
            int width = Math.Min(maxWidth, Math.Max(Px(120,scale), measured.Width + 2 * px));
            int height = Math.Min(work.Height, Math.Max(Px(30,scale), measured.Height + 2 * py));
            return new Size(Math.Max(1,width), Math.Max(1,height));
        }
    }

    public static Point PlaceHint(Rectangle anchor, Size hint, Rectangle work, double scale) {
        int gap = Px(8,scale);
        int x = anchor.Right + gap;
        if ((long)x + hint.Width > work.Right) x = anchor.Left - hint.Width - gap;
        int y = anchor.Top + (anchor.Height - hint.Height)/2;
        x = Math.Max(work.Left,Math.Min(work.Right - hint.Width,x));
        y = Math.Max(work.Top,Math.Min(work.Bottom - hint.Height,y));
        return new Point(x,y);
    }

    public static void PaintHint(Graphics graphics, Rectangle bounds, string text, double scale) {
        int px = Px(10,scale), py = Px(6,scale);
        using (SolidBrush bg = new SolidBrush(Surface))
        using (Pen border = new Pen(Edge))
        using (Font font = HintFont(scale)) {
            graphics.FillRectangle(bg,bounds);
            graphics.DrawRectangle(border,bounds.X,bounds.Y,Math.Max(0,bounds.Width-1),Math.Max(0,bounds.Height-1));
            Rectangle body = new Rectangle(bounds.X+px,bounds.Y+py,
                Math.Max(1,bounds.Width-2*px),Math.Max(1,bounds.Height-2*py));
            TextRenderer.DrawText(graphics,text ?? String.Empty,font,body,Ink,Flags);
        }
    }

    private void OnHintPopup(object sender, PopupEventArgs e) {
        Control owner = e.AssociatedControl;
        if (owner == null || owner.IsDisposed) { e.Cancel = true; return; }
        string text = Object.ReferenceEquals(owner,manualOwner) ? manualText : GetToolTip(owner);
        if (String.IsNullOrWhiteSpace(text)) { e.Cancel = true; return; }
        e.ToolTipSize = MeasureHint(text,coordinateScale(owner),Screen.FromControl(owner).WorkingArea);
    }

    private void OnHintDraw(object sender, DrawToolTipEventArgs e) {
        Control owner = e.AssociatedControl;
        if (owner == null || owner.IsDisposed) return;
        PaintHint(e.Graphics,e.Bounds,e.ToolTipText,coordinateScale(owner));
    }

    public Control ManualOwner { get { return manualOwner; } }

    public void ShowManual(Control owner, string text) {
        if (owner == null || owner.IsDisposed || !owner.Visible || String.IsNullOrWhiteSpace(text)) return;
        HideManual();
        manualOwner = owner;
        manualText = text;
        manualForm = owner.FindForm();
        owner.VisibleChanged += OnManualOwnerVisibility;
        owner.HandleDestroyed += OnManualOwnerEnded;
        owner.Disposed += OnManualOwnerEnded;
        if (manualForm != null) manualForm.Deactivate += OnManualOwnerEnded;
        try {
            double scale = coordinateScale(owner);
            Rectangle work = Screen.FromControl(owner).WorkingArea;
            Rectangle anchor = new Rectangle(owner.PointToScreen(Point.Empty),owner.Size);
            Point client = owner.PointToClient(PlaceHint(anchor,MeasureHint(text,scale,work),work,scale));
            Show(text,owner,client.X,client.Y,AutoPopDelay);
        } catch {
            HideManual();
            throw;
        }
    }

    private void OnManualOwnerVisibility(object sender, EventArgs e) {
        if (manualOwner != null && !manualOwner.Visible) HideManual();
    }

    private void OnManualOwnerEnded(object sender, EventArgs e) { HideManual(); }

    public void HideManual() {
        Control owner = manualOwner;
        Form form = manualForm;
        manualOwner = null;
        manualForm = null;
        manualText = null;
        if (owner != null) {
            owner.VisibleChanged -= OnManualOwnerVisibility;
            owner.HandleDestroyed -= OnManualOwnerEnded;
            owner.Disposed -= OnManualOwnerEnded;
        }
        if (form != null) form.Deactivate -= OnManualOwnerEnded;
        if (owner != null && !owner.IsDisposed && owner.IsHandleCreated) Hide(owner);
    }

    protected override void Dispose(bool disposing) {
        if (disposing) HideManual();
        base.Dispose(disposing);
    }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
    }
    $scale = [Func[Windows.Forms.Control,double]]{
        param($owner)
        if (Get-Command Get-LenovoUiCoordinateScale -ErrorAction SilentlyContinue) {
            return [double](Get-LenovoUiCoordinateScale -Screen ([Windows.Forms.Screen]::FromControl($owner))).Factor
        }
        # Isolated native fixtures need not load the application's DPI provider.
        $graphics = $owner.CreateGraphics()
        try { return [Math]::Max(1.0,[Math]::Min(5.0,[double]$graphics.DpiX / 96.0)) }
        finally { $graphics.Dispose() }
    }
    return [LenovoDarkTooltip]::new($scale,$InitialDelay,$ReshowDelay,$AutoPopDelay,[bool]$Animate)
}

function Ensure-DarkActionTooltip {
    if (-not $script:DarkActionTooltip) {
        $script:DarkActionTooltip = New-LenovoDarkTooltip -InitialDelay 0 -ReshowDelay 0 -AutoPopDelay 3500
    }
    return $script:DarkActionTooltip
}

function Show-DarkActionTooltip {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Owner,
        [Parameter(Mandatory=$true)][string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text) -or $Owner.IsDisposed -or -not $Owner.Visible) { return }
    $tip = Ensure-DarkActionTooltip
    $tip.ShowManual($Owner,$Text)
    $script:DarkActionTooltipOwner = $tip.ManualOwner
}

function Hide-DarkActionTooltip {
    if ($script:DarkActionTooltip) { $script:DarkActionTooltip.HideManual() }
    $script:DarkActionTooltipOwner = $null
}


function Update-HeaderStatusInteractionVisual {
    if (-not $script:HeaderStatusLabel -or $script:HeaderStatusLabel.IsDisposed) { return }
    $interactive = [bool]$script:HeaderUpdateInteractionEnabled
    $highlight = ($interactive -and ([bool]$script:HeaderStatusHovered -or $script:HeaderStatusLabel.Focused))
    $script:HeaderStatusLabel.ForeColor = if ($highlight) { [Drawing.Color]::FromArgb(255,110,102) } else { $script:ColorSecondary }
    $script:HeaderStatusLabel.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    $script:HeaderStatusLabel.TabStop = $interactive
}

function Set-HeaderUpdateInteractionState {
    param([Parameter(Mandatory=$true)][bool]$Enabled)
    $script:HeaderUpdateInteractionEnabled = $Enabled
    Update-HeaderStatusInteractionVisual
}

function Update-HeaderRefreshStatus {
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $script:SystemStatusCapabilities = $capabilities
    if ([string]$capabilities.State -eq 'Busy') {
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
    # Active request provenance affects presentation only, never worker admission.
    # Initial readiness wins until it ends; a deliberate manual refresh wins
    # over coexisting read-only popup checks. Popup work can outlive boot work.
    $origin = if ($active) { [string]$script:BackgroundRefreshState.ActiveRequest.Origin } else { '' }
    $pendingOrigin = if ($active) { [string]$script:BackgroundRefreshState.PendingRequest.Origin } else { '' }
    $popupUpdateActive = ($script:UpdateState -and $script:UpdateState.CheckProcess -and [string]$script:UpdateState.CheckMode -eq 'Popup')
    $refreshKey = if ($active -and $origin -eq 'Startup') { 'Header.InitializingApplication' }
        elseif ($active -and ($origin -eq 'Manual' -or $pendingOrigin -eq 'Manual')) { 'Header.Refreshing' }
        elseif (($active -and ($origin -eq 'Popup' -or $pendingOrigin -eq 'Popup')) -or $popupUpdateActive) { 'Header.RefreshingApplication' }
        elseif ($active) { 'Header.Refreshing' }
        else { '' }
    $refreshVisible = -not [string]::IsNullOrEmpty($refreshKey)
    $showStatus = ($refreshVisible -or $updateAvailable)

    # LBS-174: status may appear/disappear, but title geometry belongs only
    # to Add-PopupHeaderSection and must not be mutated by refresh state.

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($refreshVisible) {
            if ($refreshKey -eq 'Header.Refreshing') { Get-LocalizedString -Key 'Header.Refreshing' }
            else { Get-LocalizedString -Key $refreshKey }
        }
        elseif ($updateAvailable) {
            Get-LocalizedString -Key 'Update.Available'
        }
        else {
            ''
        }
        $script:HeaderStatusLabel.Visible = $showStatus
    }
    Set-HeaderUpdateInteractionState -Enabled (-not $refreshVisible -and $updateAvailable)
}

function Update-RefreshButtonVisual {
    if (-not $script:RefreshButton -or $script:RefreshButton.IsDisposed) {
        Update-HeaderRefreshStatus
        return
    }
    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $script:RefreshButton.Enabled = [bool]$capabilities.CanRefresh
    $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
    $script:RefreshButton.ForeColor = if ($active -or $script:RefreshButtonHovered) { $script:ColorAccent } else { $script:ColorSecondary }
    $script:RefreshButton.Invalidate()
    Update-HeaderRefreshStatus
}

function New-BackgroundRefreshCompletionTimer {
    param([Parameter(Mandatory=$true)][scriptblock]$TickAction)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 100
    $timer.Add_Tick($TickAction)
    return $timer
}


# Persistent pseudonymous UUID for this Windows user's Lenovo Boot Selector
# installation. It is not a physical-device fingerprint or a runtime session ID.
function Test-DiagnosticsInstallationIdFormat {
    param([AllowNull()][string]$Value)
    return [bool]($Value -match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
}

function Get-DiagnosticsInstallationId {
    param([Parameter(Mandatory=$true)][string]$SettingsDirectory)

    $path = Join-Path $SettingsDirectory 'installation-id.txt'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $current = ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Trim().ToLowerInvariant()
        if (-not (Test-DiagnosticsInstallationIdFormat -Value $current)) {
            throw 'The persisted diagnostics installation UUID is invalid; it will not be silently replaced.'
        }
        return $current
    }

    if (-not (Test-Path -LiteralPath $SettingsDirectory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $SettingsDirectory -Force)
    }
    $newId = [guid]::NewGuid().ToString('D').ToLowerInvariant()
    $handle = $null
    try {
        # Atomic CreateNew prevents two competing initial launches overwriting
        # each other's IDs. An existing file is never overwritten by a reset.
        $handle = New-Object System.IO.FileStream($path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $content = [System.Text.Encoding]::UTF8.GetBytes($newId + "`r`n")
        $handle.Write($content, 0, $content.Length)
        $handle.Flush($true)
        return $newId
    }
    catch [System.IO.IOException] {
        # Another process may have created the file; await its final flush.
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw }
    }
    finally {
        if ($handle) { $handle.Dispose() }
    }
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        Start-Sleep -Milliseconds 25
        try {
            $read = ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Trim().ToLowerInvariant()
            if (Test-DiagnosticsInstallationIdFormat -Value $read) { return $read }
        } catch [System.IO.IOException] { }
    }
    throw 'The diagnostics installation UUID could not be persisted safely.'
}

# LBS-103: explicit manual upload only. This module never runs on startup.
# Never add GitHub write credentials or privileged TaskBroker operations here.
function Get-DiagnosticsUploadUri {
    return [uri]'https://lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev/v1/diagnostics'
}

# A valid HTTP 201 may store an archive even if the response body is malformed.
function Read-DiagnosticsUploadReceipt {
    param([Parameter(Mandatory=$true)]$Response)
    if ([int]$Response.StatusCode -ne 201 -or -not $Response.IsSuccessStatusCode -or -not $Response.Content) {
        throw 'The upload has no confirmed stored receipt.'
    }
    $body = [string]$Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if ([string]::IsNullOrWhiteSpace($body) -or $body.Length -gt 4096) {
        throw 'The upload receipt is missing or too large.'
    }
    try { $data = ConvertFrom-Json -InputObject $body -ErrorAction Stop }
    catch { throw 'The upload receipt is not valid JSON.' }
    $id = [string]$data.diagnosisId
    $key = [string]$data.key
    $sha = [string]$data.sha256
    if ([string]$data.status -cne 'stored' -or
        $id -cnotmatch '^LBS-(?:[0-9A-HJKMNP-TV-Z]{5}-){3}[0-9A-HJKMNP-TV-Z]{5}$' -or
        $key -cnotmatch '^Diagnose/LBS/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9]{8}T[0-9]{9}Z\.zip$' -or
        $sha -cnotmatch '^[0-9a-f]{64}$' -or
        -not ($data.sizeBytes -is [ValueType]) -or
        [long]$data.sizeBytes -le 0 -or [long]$data.sizeBytes -gt (2 * 1024 * 1024)) {
        throw 'The upload receipt is missing trusted archive fields.'
    }
    return [pscustomobject]@{ DiagnosisId=$id; Key=$key; Sha256=$sha; SizeBytes=[long]$data.sizeBytes }
}

function New-DiagnosticsUploadHttpHandler {
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    # Automatic 30x redirects could forward private ZIPs to a third-party host.
    # Pinning only the initial URI is not enough.
    $handler.AllowAutoRedirect = $false
    return $handler
}

function New-DiagnosticsUploadRequest {
    param(
        [Parameter(Mandatory=$true)][byte[]]$Bytes,
        [Parameter(Mandatory=$true)][string]$InstallationUuid,
        [Parameter(Mandatory=$true)][uri]$Uri
    )
    Add-Type -AssemblyName System.Net.Http
    $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Uri)
    try {
        $payload = New-Object System.Net.Http.ByteArrayContent(,$Bytes)
        $payload.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('application/zip')
        $request.Headers.Add('x-installation-uuid', $InstallationUuid)
        $request.Content = $payload
        return $request
    }
    catch {
        $request.Dispose()
        throw
    }
}

function Start-DiagnosticsUploadTransport {
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$InstallationUuid
    )

    if (-not (Test-DiagnosticsInstallationIdFormat -Value $InstallationUuid)) {
        throw 'The installation UUID is not valid.'
    }
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw 'The diagnostics ZIP does not exist.'
    }
    $maxBytes = 2 * 1024 * 1024
    $size = (Get-Item -LiteralPath $ZipPath).Length
    if ($size -le 0 -or $size -gt $maxBytes) {
        throw 'The diagnostics ZIP exceeds the 2 MB upload limit or is empty.'
    }

    $uri = Get-DiagnosticsUploadUri
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev' -or $uri.AbsolutePath -ne '/v1/diagnostics') {
        throw 'The diagnostics upload destination is not approved.'
    }
    try {
        $existing = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $existing -bor [System.Net.SecurityProtocolType]::Tls12
    } catch { }

    $httpHandler = New-DiagnosticsUploadHttpHandler
    try {
        $client = New-Object System.Net.Http.HttpClient -ArgumentList (,$httpHandler)
    } catch {
        $httpHandler.Dispose()
        throw
    }
    $client.Timeout = [TimeSpan]::FromSeconds(25)
    $content = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($ZipPath)
        if ($bytes.Length -ne $size) { throw 'The diagnostics ZIP changed during preparation.' }
        $request = New-DiagnosticsUploadRequest -Bytes $bytes -InstallationUuid $InstallationUuid -Uri $uri
        $content = $request.Content
        try {
            $task = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseContentRead)
            return [pscustomobject]@{ Client = $client; Task = $task; Content = $content; Request = $request; ZipPath = $ZipPath }
        }
        catch {
            $request.Dispose()
            throw
        }
    }
    catch {
        if ($content) { $content.Dispose() }
        $client.Dispose()
        throw
    }
}

function Dispose-DiagnosticsUploadTransport {
    param([AllowNull()]$Context)
    if (-not $Context) { return }
    try { if ($Context.Task -and $Context.Task.IsCompleted -and -not $Context.Task.IsFaulted) { $Context.Task.Result.Dispose() } } catch { }
    try { if ($Context.Request) { $Context.Request.Dispose() } } catch { }
    try { if ($Context.Content) { $Context.Content.Dispose() } } catch { }
    try { if ($Context.Client) { $Context.Client.Dispose() } } catch { }
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


function New-LenovoUpdateCheckResultPath {
    return (Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateCheck-{0}.json' -f ([guid]::NewGuid().ToString('N'))))
}

function Read-LenovoUpdateWorkerResult {
    param([AllowNull()][string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $json = [System.IO.File]::ReadAllText($Path,[System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($json)) { return $null }
    return ($json | ConvertFrom-Json)
}

function Remove-LenovoUpdateWorkflowFile {
    param([AllowNull()][string]$Path)

    if (-not $Path) { return }
    try {
        if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
    } catch { }
}

function New-LenovoUpdatePrepareInput {
    param([Parameter(Mandatory=$true)]$Manifest)

    $manifestPath = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateManifest-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $resultPath = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdatePrepare-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllText($manifestPath,($Manifest | ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
        return [pscustomobject]@{ ManifestPath=$manifestPath; ResultPath=$resultPath }
    }
    catch {
        Remove-LenovoUpdateWorkflowFile -Path $manifestPath
        throw
    }
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

# Update check/prepare application workflow.
# UI owns presentation and user commands; Infrastructure owns transport/process/filesystem/install mechanics.

function Stop-UpdateCheckWorkflow {
    param([Parameter(Mandatory=$true)]$State)

    if ($State.CheckTimer) {
        try { $State.CheckTimer.Stop() } catch { }
        try { $State.CheckTimer.Dispose() } catch { }
        $State.CheckTimer = $null
    }
    if ($State.CheckProcess) {
        try { $State.CheckProcess.Dispose() } catch { }
        $State.CheckProcess = $null
    }
}

function Start-UpdateCheckWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode,
        [AllowNull()][string]$RuntimeSessionId,
        [Parameter(Mandatory=$true)][scriptblock]$CompletionAction,
        [Parameter(Mandatory=$true)][scriptblock]$TimerFactory,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    if (Test-UpdateRuntimeBusy -State $State) {
        return [pscustomobject]@{ Started=$false; Reason='Busy'; Error='' }
    }

    [void](Set-UpdateRuntimeChecking -State $State)
    $State.CheckMode = $Mode
    $resultPath = New-LenovoUpdateCheckResultPath
    $State.CheckResultPath = $resultPath

    try {
        $process = Start-UpdateCheckWorkerProcess -ResultPath $resultPath -RuntimeSessionId $RuntimeSessionId
        if (-not $process) { throw $StartFailureMessage }
        $State.CheckProcess = $process

        $stateForTick = $State
        $completionForTick = $CompletionAction
        $tickAction = {
            try {
                if (-not $stateForTick.CheckProcess) { return }
                $stateForTick.CheckProcess.Refresh()
                if ($stateForTick.CheckProcess.HasExited) { & $completionForTick }
            }
            catch {
                & $completionForTick
            }
        }.GetNewClosure()

        $timer = & $TimerFactory $tickAction
        if (-not $timer) { throw $StartFailureMessage }
        $State.CheckTimer = $timer
        $timer.Start()

        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_STARTED' } else { 'UPDATE_CHECK_STARTED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode=$Mode })
        return [pscustomobject]@{ Started=$true; Reason='Started'; Error='' }
    }
    catch {
        $errorMessage = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $errorMessage)
        Stop-UpdateCheckWorkflow -State $State
        Remove-LenovoUpdateWorkflowFile -Path $resultPath
        $State.CheckResultPath = $null
        $State.CheckMode = ''
        [void](Set-UpdateRuntimeIdle -State $State)
        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_STARTED' } else { 'UPDATE_CHECK_STARTED' }) -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode }) -Level warning
        return [pscustomobject]@{ Started=$false; Reason='StartFailed'; Error=$errorMessage }
    }
}

function Complete-UpdateCheckWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode,
        [Parameter(Mandatory=$true)][string]$NoResultMessage
    )

    Stop-UpdateCheckWorkflow -State $State
    $path = [string]$State.CheckResultPath
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $networkStatus = ''
    $outcome = [ordered]@{
        Success = $false
        Mode = $Mode
        UpdateAvailable = $false
        Manifest = $null
        Error = ''
        ErrorCategory = ''
        FailureStage = ''
        ErrorClass = ''
        NetworkStatus = ''
    }

    try {
        $result = Read-LenovoUpdateWorkerResult -Path $path
        if ($null -eq $result) {
            $failureCategory = 'runtime'
            $failureStage = 'check-result'
            throw $NoResultMessage
        }
        if (-not [bool]$result.Success) {
            $failureCategory = ([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage = ([string]$result.FailureStage).Trim()
            $errorClass = ([string]$result.ErrorClass).Trim()
            $networkStatus = ([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }

        if ([bool]$result.UpdateAvailable) {
            $validated = Test-LenovoUpdateManifestCore -Manifest $result.Manifest
            if (-not $validated.IsValid) {
                $failureCategory = 'manifest'
                $failureStage = 'result-manifest-validation'
                throw $validated.Error
            }
            [void](Set-UpdateRuntimeAvailable -State $State -Manifest $validated)
            $outcome.Success = $true
            $outcome.UpdateAvailable = $true
            $outcome.Manifest = $validated
            Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$true; availableVersion=$validated.Version; mode=$Mode })
        }
        else {
            $State.AvailableManifest = $null
            [void](Set-UpdateRuntimeIdle -State $State)
            $outcome.Success = $true
            Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$false; mode=$Mode })
        }
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        $outcome.Error = $message
        $outcome.ErrorCategory = $failureCategory
        $outcome.FailureStage = $failureStage
        $outcome.ErrorClass = $errorClass
        $outcome.NetworkStatus = $networkStatus
        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage $(if ($failureStage) { $failureStage } else { 'update-check' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode; errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level warning
    }
    finally {
        Remove-LenovoUpdateWorkflowFile -Path $path
        $State.CheckResultPath = $null
        $State.CheckMode = ''
        if ($State.Status -eq 'Failed') { [void](Set-UpdateRuntimeIdle -State $State) }
    }

    return [pscustomobject]$outcome
}

function Stop-UpdatePrepareWorkflow {
    param([Parameter(Mandatory=$true)]$State)

    if ($State.PrepareTimer) {
        try { $State.PrepareTimer.Stop() } catch { }
        try { $State.PrepareTimer.Dispose() } catch { }
        $State.PrepareTimer = $null
    }
    if ($State.PrepareProcess) {
        try { $State.PrepareProcess.Dispose() } catch { }
        $State.PrepareProcess = $null
    }
}

function Start-UpdatePrepareWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Manifest,
        [AllowNull()][string]$RuntimeSessionId,
        [Parameter(Mandatory=$true)][scriptblock]$CompletionAction,
        [Parameter(Mandatory=$true)][scriptblock]$TimerFactory,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    if (Test-UpdateRuntimeBusy -State $State) {
        return [pscustomobject]@{ Started=$false; Reason='Busy'; Error=''; Version='' }
    }
    if ($null -eq $Manifest) {
        return [pscustomobject]@{ Started=$false; Reason='NoManifest'; Error=''; Version='' }
    }
    if (-not (Test-UpdateInstallDirectoryWritable)) {
        return [pscustomobject]@{ Started=$false; Reason='DirectoryNotWritable'; Error=''; Version=[string]$Manifest.Version }
    }

    [void](Set-UpdateRuntimePreparing -State $State)
    $input = $null
    try {
        $input = New-LenovoUpdatePrepareInput -Manifest $Manifest
        $State.ManifestPath = [string]$input.ManifestPath
        $State.PrepareResultPath = [string]$input.ResultPath

        $process = Start-UpdatePrepareWorkerProcess -ManifestPath $State.ManifestPath -ResultPath $State.PrepareResultPath -RuntimeSessionId $RuntimeSessionId
        if (-not $process) { throw $StartFailureMessage }
        $State.PrepareProcess = $process

        $stateForTick = $State
        $completionForTick = $CompletionAction
        $tickAction = {
            try {
                if (-not $stateForTick.PrepareProcess) { return }
                $stateForTick.PrepareProcess.Refresh()
                if ($stateForTick.PrepareProcess.HasExited) { & $completionForTick }
            }
            catch {
                & $completionForTick
            }
        }.GetNewClosure()

        $timer = & $TimerFactory $tickAction
        if (-not $timer) { throw $StartFailureMessage }
        $State.PrepareTimer = $timer
        $timer.Start()

        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=[string]$Manifest.Version })
        return [pscustomobject]@{ Started=$true; Reason='Started'; Error=''; Version=[string]$Manifest.Version }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Stop-UpdatePrepareWorkflow -State $State
        Remove-LenovoUpdateWorkflowFile -Path ([string]$State.PrepareResultPath)
        Remove-LenovoUpdateWorkflowFile -Path ([string]$State.ManifestPath)
        $State.PrepareResultPath = $null
        $State.ManifestPath = $null
        [void](Set-UpdateRuntimeIdle -State $State)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ version=[string]$Manifest.Version }) -Level warning
        return [pscustomobject]@{ Started=$false; Reason='StartFailed'; Error=$errorMessage; Version=[string]$Manifest.Version }
    }
}

function Complete-UpdatePrepareWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][string]$NoResultMessage
    )

    Stop-UpdatePrepareWorkflow -State $State
    $path = [string]$State.PrepareResultPath
    $manifestPath = [string]$State.ManifestPath
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $networkStatus = ''
    $outcome = [ordered]@{
        Success = $false
        WorkDir = ''
        Version = ''
        Error = ''
        ErrorCategory = ''
        FailureStage = ''
        ErrorClass = ''
        NetworkStatus = ''
    }

    try {
        $result = Read-LenovoUpdateWorkerResult -Path $path
        if ($null -eq $result) {
            $failureCategory = 'runtime'
            $failureStage = 'prepare-result'
            throw $NoResultMessage
        }
        if (-not [bool]$result.Success) {
            $failureCategory = ([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage = ([string]$result.FailureStage).Trim()
            $errorClass = ([string]$result.ErrorClass).Trim()
            $networkStatus = ([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }

        [void](Set-UpdateRuntimeReadyToInstall -State $State)
        $outcome.Success = $true
        $outcome.WorkDir = [string]$result.WorkDir
        $outcome.Version = [string]$result.Version
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=[string]$result.Version })
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        $outcome.Error = $message
        $outcome.ErrorCategory = $failureCategory
        $outcome.FailureStage = $failureStage
        $outcome.ErrorClass = $errorClass
        $outcome.NetworkStatus = $networkStatus
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage $(if ($failureStage) { $failureStage } else { 'update-prepare' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level error
        [void](Set-UpdateRuntimeIdle -State $State)
    }
    finally {
        Remove-LenovoUpdateWorkflowFile -Path $path
        Remove-LenovoUpdateWorkflowFile -Path $manifestPath
        $State.PrepareResultPath = $null
        $State.ManifestPath = $null
    }

    return [pscustomobject]$outcome
}

function Start-UpdateInstallerHandoff {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][string]$WorkDir,
        [Parameter(Mandatory=$true)][string]$SourceVersion,
        [Parameter(Mandatory=$true)][string]$FailurePrefix,
        [Parameter(Mandatory=$true)][string]$ManualRestartMessage,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    try {
        $helper = Start-LenovoUpdateInstallerHelper -WorkDir $WorkDir -SourceVersion $SourceVersion -FailurePrefix $FailurePrefix -ManualRestartMessage $ManualRestartMessage
        if (-not $helper) { throw $StartFailureMessage }
        $processId = $helper.Id
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_INSTALL_HELPER_STARTED' -Stage 'update-install' -Success $true -Data (New-RuntimeDiagnosticData @{ processId=$processId; version=[string]$State.AvailableManifest.Version })
        try { $helper.Dispose() } catch { }
        return [pscustomobject]@{ Success=$true; Error=''; ProcessId=$processId }
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory='runtime'; failureStage='update-install'; errorClass=$_.Exception.GetType().FullName; networkStatus='' }) -Level error
        [void](Set-UpdateRuntimeIdle -State $State)
        return [pscustomobject]@{ Success=$false; Error=$message; ProcessId=$null }
    }
}

function Get-PendingUpdateRestartWorkflowResult {
    param([Parameter(Mandatory=$true)][string]$RunningVersion)

    $result = Read-LenovoUpdateResult
    if (-not $result) { return $null }

    $resolved = Resolve-LenovoUpdateRestartResultCore -Result $result -RunningVersion $RunningVersion
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

    Remove-LenovoUpdateResult
    return $resolved
}


function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.SavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.SavedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.PathHint') -ValueCaption (Get-LocalizedString -Key 'Diagnostics.PathCaption') -ValueText $path -Kind Success -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.ShowFolder') -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.NotSavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.NotSavedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
    }
}

function Start-DiagnosticsUploadFromUi {
    # A deliberate menu click is the only upload trigger. Never call this
    # during startup, refresh, diagnostics export, or error handling.
    if ($script:DiagnosticsUploadState) { return }
    $path=$null
    try {
        $installationId = Get-DiagnosticsInstallationId -SettingsDirectory $script:SettingsDir
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-upload'
        $context = Start-DiagnosticsUploadTransport -ZipPath $path -InstallationUuid $installationId
        $script:DiagnosticsUploadState = $context
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $false }
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 180
        $timer.Add_Tick({ Complete-DiagnosticsUploadFromUi })
        $script:DiagnosticsUploadTimer = $timer
        $timer.Start()
        $script:LastStatusText = Get-LocalizedString -Key 'Diagnostics.Uploading'
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_STARTED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ outputName = [IO.Path]::GetFileName($path) })
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level warning
        if ($script:DiagnosticsUploadTimer) {
            try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
            $script:DiagnosticsUploadTimer = $null
        }
        if ($script:DiagnosticsUploadState) { Dispose-DiagnosticsUploadTransport -Context $script:DiagnosticsUploadState; $script:DiagnosticsUploadState = $null }
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $true }
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadFailedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadFailedHeading') -Message (Get-LocalizedString -Key $(if ($path) { 'Diagnostics.UploadFailedMessage' } else { 'Diagnostics.UploadNoLocalPackageMessage' })) -Kind Error
    }
}

function Complete-DiagnosticsUploadFromUi {
    $context = $script:DiagnosticsUploadState
    if (-not $context -or -not $context.Task -or -not $context.Task.IsCompleted) { return }
    $success = $false
    $receiptUncertain = $false
    $receipt = $null
    try {
        $response = $context.Task.GetAwaiter().GetResult()
        if ($response.IsSuccessStatusCode -and [int]$response.StatusCode -eq 201) {
            try {
                $receipt = Read-DiagnosticsUploadReceipt -Response $response
                $success = $true
            } catch {
                # HTTP 201 can mean the ZIP was stored even if its receipt is malformed.
                # Do not tell the user to re-upload blindly or invent an ID.
                $receiptUncertain = $true
                Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_RECEIPT_UNAVAILABLE' -Stage 'diagnostics' -Success $false -Level warning
            }
        }
        if (-not $success -and -not $receiptUncertain) {
            Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_HTTP_FAILURE' -Stage 'diagnostics' -Success $false -Level warning -Data (New-RuntimeDiagnosticData @{ statusCode = [int]$response.StatusCode })
        }
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level warning
    }
    finally {
        # Release timer and state before displaying any modal dialog; dialogs
        # pump Windows messages and could otherwise double-complete a request.
        if ($script:DiagnosticsUploadTimer) {
            try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
            $script:DiagnosticsUploadTimer = $null
        }
        $script:DiagnosticsUploadState = $null
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $true }
        Dispose-DiagnosticsUploadTransport -Context $context
    }
    if ($success) {
        $copyId = [string]$receipt.DiagnosisId
        $copyAction = { [System.Windows.Forms.Clipboard]::SetText($copyId); return $true }.GetNewClosure()
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_COMPLETED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ diagnosisId = $copyId })
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.IdHint') -ValueCaption (Get-LocalizedString -Key 'Diagnostics.IdCaption') -ValueText $copyId -Kind Success -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.CopyId') -SecondaryAction $copyAction -KeepOpenAfterSecondary
    }
    elseif ($receiptUncertain) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.ReferenceMissingTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.ReferenceMissingHeading') -Message (Get-LocalizedString -Key 'Diagnostics.ReferenceMissingMessage') -Kind Warning
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadFailedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadFailedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.UploadFailedMessage') -Kind Error
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
    $resolved = Get-PendingUpdateRestartWorkflowResult -RunningVersion $script:AppVersion
    if (-not $resolved) { return $false }

    if ($resolved.Success) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.SuccessTitle') -Heading (Get-LocalizedString -Key 'Update.SuccessHeading' -Values @{ Version=$resolved.DisplayVersion }) -Message (Get-LocalizedUpdateRestartMessage -Resolved $resolved) -Kind Success
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
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.Available') -Heading (Get-LocalizedString -Key 'Update.AvailableHeading' -Values @{ Version=$manifest.Version }) -Message (Get-LocalizedString -Key 'Update.AvailableMessage') -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Update.InstallNow') -SecondaryAction { Start-ManualAppUpdate } -PromoteSecondaryAction -DismissButtonText (Get-LocalizedString -Key 'Update.Later')
    return $true
}

function New-UpdateWorkflowCompletionTimer {
    param([Parameter(Mandatory=$true)][scriptblock]$TickAction)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $timer.Add_Tick($TickAction)
    return $timer
}

function Complete-UpdateCheckPresentation {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)

    $isPopup = ($Mode -eq 'Popup')
    $outcome = Complete-UpdateCheckWorkflow -State $script:UpdateState -Mode $Mode -NoResultMessage (Get-LocalizedString -Key 'Update.CheckNoResult')
    try {
        if ($outcome.Success) {
            if ($outcome.UpdateAvailable) {
                $script:LastStatusText = Get-LocalizedString -Key 'Update.AvailableStatus' -Values @{ Version=$outcome.Manifest.Version }
                if (-not $isPopup) { [void](Show-AvailableUpdateDialog) }
            }
            elseif (-not $isPopup) {
                $script:LastStatusText = Get-LocalizedString -Key 'Update.CurrentStatus' -Values @{ Version=$script:AppVersion }
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NoNewTitle') -Heading (Get-LocalizedString -Key 'Update.CurrentHeading' -Values @{ Version=$script:AppVersion }) -Message (Get-LocalizedString -Key 'Update.NoNewMessage') -Kind Success
            }
        }
        elseif (-not $isPopup) {
            $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckFailedStatus'
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckFailedHeading') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
        }
    }
    finally {
        Update-UpdateMenuState
        Update-HeaderRefreshStatus
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
    return $outcome
}

function Complete-ManualUpdateCheck {
    return (Complete-UpdateCheckPresentation -Mode 'Manual')
}

function Complete-PopupUpdateCheck {
    return (Complete-UpdateCheckPresentation -Mode 'Popup')
}

function Start-ManualUpdateCheck {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdateCheckWorkflow -State $script:UpdateState -Mode 'Manual' -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-ManualUpdateCheck } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.CheckStartFailed')
    if ($started.Started) {
        $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckingStatus'
    }
    elseif ($started.Reason -eq 'StartFailed') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckStartFailed') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
}

function Start-PopupUpdateCheck {
    if (-not $script:UpdateState -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return $false }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdateCheckWorkflow -State $script:UpdateState -Mode 'Popup' -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-PopupUpdateCheck } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.CheckStartFailed')
    Update-UpdateMenuState
    Update-HeaderRefreshStatus
    return [bool]$started.Started
}

function Exit-TrayForPreparedUpdate {
    $script:ExitRequested = $true
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible = $false } } catch { }
    try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
    [System.Windows.Forms.Application]::ExitThread()
}

function Complete-ManualAppUpdatePrepare {
    $outcome = Complete-UpdatePrepareWorkflow -State $script:UpdateState -NoResultMessage (Get-LocalizedString -Key 'Update.PrepareNoResult')
    if ($outcome.Success) {
        $handoff = Start-UpdateInstallerHandoff -State $script:UpdateState -WorkDir $outcome.WorkDir -SourceVersion $script:AppVersion -FailurePrefix (Get-LocalizedString -Key 'Update.HelperFailurePrefix') -ManualRestartMessage (Get-LocalizedString -Key 'Update.HelperManualRestart') -StartFailureMessage (Get-LocalizedString -Key 'Update.InstallerStartFailed')
        if ($handoff.Success) {
            Exit-TrayForPreparedUpdate
        }
        else {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
        }
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
    return $outcome
}

function Start-ManualAppUpdate {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    $manifest = $script:UpdateState.AvailableManifest
    if (-not $manifest) { return }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdatePrepareWorkflow -State $script:UpdateState -Manifest $manifest -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-ManualAppUpdatePrepare } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.PrepareStartFailed')
    if ($started.Started) {
        $script:LastStatusText = Get-LocalizedString -Key 'Update.PreparingStatus' -Values @{ Version=$manifest.Version }
    }
    elseif ($started.Reason -eq 'DirectoryNotWritable') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NotPossibleTitle') -Heading (Get-LocalizedString -Key 'Update.DirectoryNotWritableHeading') -Message (Get-LocalizedString -Key 'Update.DirectoryNotWritableMessage') -Kind Error
    }
    elseif ($started.Reason -eq 'StartFailed') {
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
            if ($current -cne $draft) { return $true }
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
        $button.ForeColor = [Drawing.Color]::FromArgb(146,146,146)
        $button.BackColor = [Drawing.Color]::FromArgb(35,35,35)
        $button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
        $button.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}


function Read-AppSettingsRepositoryResult {
    param([Parameter(Mandatory=$true)][string]$Path)

    # Distinguish an absent first-run file from a probe/read failure. No
    # user-authored contents or full local paths enter the result metadata.
    try {
        $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ Status='Unreadable'; FailureKind='ProbeFailure'; Source=$null }
    }
    if (-not $exists) {
        return [pscustomobject]@{ Status='Missing'; FailureKind='None'; Source=$null }
    }

    try {
        $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    }
    catch {
        return [pscustomobject]@{ Status='Unreadable'; FailureKind='ReadFailure'; Source=$null }
    }

    try {
        $source = ConvertFrom-Json -InputObject $text -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ Status='Invalid'; FailureKind='ParseFailure'; Source=$null }
    }
    if ($null -eq $source -or $source -isnot [pscustomobject]) {
        return [pscustomobject]@{ Status='Invalid'; FailureKind='InvalidRoot'; Source=$null }
    }
    return [pscustomobject]@{ Status='Loaded'; FailureKind='None'; Source=$source }
}

function Read-AppSettingsRepository {
    param([Parameter(Mandatory=$true)][string]$Path)

    $result = Read-AppSettingsRepositoryResult -Path $Path
    if ($result.Status -eq 'Missing') { return $null }
    if ($result.Status -eq 'Loaded') { return $result.Source }
    throw ("Unable to read settings: {0}/{1}" -f $result.Status, $result.FailureKind)
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

# Local, unelevated, bounded IO only. No firmware, registry, process or broker calls.
function Read-PreferencesFileSnapshot {
    param([Parameter(Mandatory=$true)][string]$Path,[switch]$AllowMissing)
    $stream=$null
    try {
        try { $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read) }
        catch [IO.FileNotFoundException] { if ($AllowMissing) { return [pscustomobject]@{Exists=$false;Token='missing';Text=''} }; throw }
        catch [IO.DirectoryNotFoundException] { if ($AllowMissing) { return [pscustomobject]@{Exists=$false;Token='missing';Text=''} }; throw }
        $length=$stream.Length
        if ($length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
        $bytes=[byte[]]::new([int]$length)
        $offset=0
        while ($offset -lt $bytes.Length) {
            $count=$stream.Read($bytes,$offset,$bytes.Length-$offset)
            if ($count -le 0) { throw 'ReadChanged' }
            $offset+=$count
        }
        if ($stream.ReadByte() -ne -1) { throw 'ReadChanged' }
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $token=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
        $start=0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $start=3 }
        $encoding=[Text.UTF8Encoding]::new($false,$true)
        $text=$encoding.GetString($bytes,$start,$bytes.Length-$start)
        return [pscustomobject]@{Exists=$true;Token=$token;Text=$text}
    }
    finally { if ($stream) { $stream.Dispose() } }
}

function Write-PreferencesFileAtomic {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Text,[Parameter(Mandatory=$true)][string]$ExpectedToken)
    $encoding=[Text.UTF8Encoding]::new($false,$true)
    $bytes=$encoding.GetBytes($Text)
    if ($bytes.Length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    $path=[IO.Path]::GetFullPath($Path)
    $directory=[IO.Path]::GetDirectoryName($path)
    $original=Read-PreferencesFileSnapshot -Path $path -AllowMissing
    if ($original.Token -cne $ExpectedToken) { throw 'StalePreview' }
    # A unique sibling temporary file permits an atomic same-volume rename.
    # File.Replace retains a rollback copy until the replacement succeeds.
    [void][IO.Directory]::CreateDirectory($directory)
    $nonce=[guid]::NewGuid().ToString('N')
    $temporary=[IO.Path]::Combine($directory,'.lbs-preferences-'+$nonce+'.tmp')
    $backup=[IO.Path]::Combine($directory,'.lbs-preferences-'+$nonce+'.bak')
    $committed=$false
    $replacementAttempted=$false
    try {
        $stream=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        $new=Read-PreferencesFileSnapshot -Path $temporary
        $latest=Read-PreferencesFileSnapshot -Path $path -AllowMissing
        if ($latest.Token -cne $ExpectedToken) { throw 'StalePreview' }
        $replacementAttempted=$true
        if ($original.Exists) { [IO.File]::Replace($temporary,$path,$backup) }
        else { [IO.File]::Move($temporary,$path) }
        $committed=$true
    }
    catch {
        if ($replacementAttempted) {
            try {
                $observed=Read-PreferencesFileSnapshot -Path $path -AllowMissing
                if ($observed.Token -cne $ExpectedToken) {
                    # Never overwrite an unrelated external writer's new data.
                    if ($original.Exists -and [IO.File]::Exists($backup) -and
                        (-not $observed.Exists -or $observed.Token -ceq $new.Token)) {
                        if ($observed.Exists) { [IO.File]::Replace($backup,$path,$null) }
                        else { [IO.File]::Move($backup,$path) }
                    }
                    elseif (-not $original.Exists -and $observed.Token -ceq $new.Token) { [IO.File]::Delete($path) }
                    else { throw 'CommitUncertain' }
                    if ((Read-PreferencesFileSnapshot -Path $path -AllowMissing).Token -cne $ExpectedToken) { throw 'CommitUncertain' }
                }
            }
            catch { throw 'CommitUncertain' }
        }
        throw
    }
    finally {
        try { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } } catch { }
        # Preserve an available rollback copy on uncertain failure.
        if ($committed) { try { if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) } } catch { } }
    }
}


function New-AppSettingsLoadResult {
    param(
        [ValidateSet('Missing','Loaded','Invalid','Unreadable')][string]$Status,
        $Settings,
        [string]$FailureKind = 'None'
    )
    return [pscustomobject]@{
        Status = $Status
        Settings = $Settings
        FailureKind = $FailureKind
        PersistenceBlocked = ($Status -in @('Invalid','Unreadable'))
    }
}

function Get-AppSettingsLoadResult {
    # Only this Application service owns the distinction between persisted
    # settings and safe in-memory defaults. Schema-6 normalization stays Core.
    try {
        $source = Read-AppSettingsRepositoryResult -Path $script:SettingsPath
    }
    catch {
        return New-AppSettingsLoadResult -Status 'Unreadable' -Settings (New-DefaultAppSettingsCore) -FailureKind 'RepositoryFailure'
    }

    switch ($source.Status) {
        'Missing' {
            return New-AppSettingsLoadResult -Status 'Missing' -Settings (New-DefaultAppSettingsCore)
        }
        'Invalid' {
            return New-AppSettingsLoadResult -Status 'Invalid' -Settings (New-DefaultAppSettingsCore) -FailureKind $source.FailureKind
        }
        'Unreadable' {
            return New-AppSettingsLoadResult -Status 'Unreadable' -Settings (New-DefaultAppSettingsCore) -FailureKind $source.FailureKind
        }
        'Loaded' {
            try {
                $settings = ConvertTo-NormalizedAppSettingsCore -Source $source.Source
                if ($null -eq $settings) { throw 'Unexpected empty normalized settings' }
                return New-AppSettingsLoadResult -Status 'Loaded' -Settings $settings
            }
            catch {
                return New-AppSettingsLoadResult -Status 'Invalid' -Settings (New-DefaultAppSettingsCore) -FailureKind 'NormalizeFailure'
            }
        }
        default {
            return New-AppSettingsLoadResult -Status 'Unreadable' -Settings (New-DefaultAppSettingsCore) -FailureKind 'RepositoryFailure'
        }
    }
}

function Write-AppSettingsStateDiagnostic {
    param(
        [Parameter(Mandatory=$true)][string]$Event,
        [Parameter(Mandatory=$true)]$Outcome
    )

    # Diagnostics are observational; avoid logging raw JSON, aliases, user
    # paths or parse error messages from a possibly corrupted settings file.
    if (-not (Get-Command Write-RuntimeDiagnosticEvent -ErrorAction SilentlyContinue)) { return }
    try {
        $data = [ordered]@{
            source = 'settings.json'
            status = [string]$Outcome.Status
            failureKind = [string]$Outcome.FailureKind
            persistenceBlocked = [bool]$Outcome.PersistenceBlocked
        }
        Write-RuntimeDiagnosticEvent -Event $Event -Stage 'settings' -Success $false -Level warning -Data $data
    }
    catch {
        # Diagnostics must never prevent a safe startup or block a boot action.
        return
    }
}

function Set-AppSettingsLoadState {
    param([Parameter(Mandatory=$true)]$Outcome)
    # Metadata only. Locale/order/hidden entries/aliases remain under their
    # existing narrow Application/UI owners; no global service locator.
    $script:SettingsLoadState = [pscustomobject]@{
        Status = [string]$Outcome.Status
        FailureKind = [string]$Outcome.FailureKind
        PersistenceBlocked = [bool]$Outcome.PersistenceBlocked
    }
}

function Get-AppSettings {
    $outcome = Get-AppSettingsLoadResult
    Set-AppSettingsLoadState -Outcome $outcome
    return $outcome.Settings
}

function Save-AppSettings {
    # Do not overwrite a previously corrupt/unreadable persisted state using
    # fallback defaults. A repair must be followed by an explicit clean reload.
    if ($script:SettingsLoadState -and $script:SettingsLoadState.PersistenceBlocked) {
        Write-AppSettingsStateDiagnostic -Event 'SETTINGS_SAVE_BLOCKED' -Outcome $script:SettingsLoadState
        throw 'Settings persistence is blocked until the damaged source is repaired and reloaded.'
    }

    # Catch corruption introduced after startup or before the first load.
    # Even a direct Save-AppSettings call may not silently replace bad data.
    $preflight = Get-AppSettingsLoadResult
    if ($preflight.PersistenceBlocked) {
        Set-AppSettingsLoadState -Outcome $preflight
        Write-AppSettingsStateDiagnostic -Event 'SETTINGS_SAVE_BLOCKED' -Outcome $preflight
        throw 'Settings persistence is blocked because the stored settings could not be loaded.'
    }

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
    Set-AppSettingsLoadState -Outcome (New-AppSettingsLoadResult -Status 'Loaded' -Settings $null)
}

function Load-AppSettings {
    $settings = Get-AppSettings
    if ($script:SettingsLoadState.PersistenceBlocked) {
        Write-AppSettingsStateDiagnostic -Event 'SETTINGS_LOAD_FALLBACK' -Outcome $script:SettingsLoadState
    }
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

# Application owner for the explicit preference import transaction.
function Test-PortablePreferencesAvailable {
    param([switch]$PresentationOnly)
    if ($script:IsManageEntriesMode -or $script:BootNextPendingGuid -or $script:DefaultTargetChangePending -or
        $script:LocalePreferenceNeedsConfirmation -or ($script:SettingsLoadState -and $script:SettingsLoadState.PersistenceBlocked) -or
        (Test-MaintenanceBusy) -or ($script:BackgroundRefreshState -and (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))) { return $false }
    if ($PresentationOnly) {
        # The existing settings timer only reflects cached presentation facts.
        # The action owner revalidates the complete current capability gate.
        return [bool]($script:TaskBrokerReadyCached -eq $true -and @($script:CurrentEntries).Count -gt 0 -and -not (Test-BootTargetDriftRuntimeDetected -State $script:BootTargetDriftState))
    }
    return [bool](Get-CurrentSystemFunctionsCapabilities).CanManageEntries
}

function ConvertTo-PreferencesSettingsPayload {
    param($Settings)
    $aliases=[ordered]@{}
    $map=Convert-EntryAliasesToHashtable $Settings.entryAliases
    foreach ($key in @($map.Keys | Sort-Object)) { $aliases[$key]=$map[$key] }
    return [ordered]@{
        schemaVersion=6
        locale=[string]$Settings.locale
        localePreferenceSource=[string]$Settings.localePreferenceSource
        defaultGuid=$Settings.defaultGuid
        entryOrder=@($Settings.entryOrder)
        hiddenEntryGuids=@($Settings.hiddenEntryGuids)
        entryAliases=$aliases
    }
}

function Get-PortablePreferencesContext {
    if (-not (Test-PortablePreferencesAvailable)) { throw 'PreferencesUnavailable' }
    try { $file=Read-PreferencesFileSnapshot -Path $script:SettingsPath -AllowMissing }
    catch { throw 'InvalidLocalSettings' }
    $raw=$null
    if ($file.Exists) {
        try { $raw=(Read-BoundedPreferencesJsonCore $file.Text).Value }
        catch { throw 'InvalidLocalSettings' }
        if ($raw -isnot [Collections.IDictionary]) { throw 'InvalidLocalSettings' }
        foreach ($key in $raw.Keys) {
            if ($key -cnotin @('schemaVersion','locale','localePreferenceSource','defaultGuid','entryOrder','hiddenEntryGuids','entryAliases')) { throw 'UnsupportedLocalSettings' }
        }
        if ($raw.Contains('schemaVersion') -and ($raw.schemaVersion -isnot [int] -or $raw.schemaVersion -lt 1 -or $raw.schemaVersion -gt 6)) { throw 'UnsupportedLocalSettings' }
        try {
            foreach ($field in @('locale','localePreferenceSource')) {
                if ($raw.Contains($field) -and $raw[$field] -isnot [string]) { throw 'InvalidLocalSettings' }
            }
            if ($raw.Contains('defaultGuid') -and $null -ne $raw.defaultGuid -and $raw.defaultGuid -ne '') { [void](ConvertTo-PortableGuidCore $raw.defaultGuid) }
            foreach ($field in @('entryOrder','hiddenEntryGuids')) {
                if (-not $raw.Contains($field)) { continue }
                if ($raw[$field] -isnot [array]) { throw 'InvalidLocalSettings' }
                $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($guid in $raw[$field]) {
                    if (-not $seen.Add((ConvertTo-PortableGuidCore $guid))) { throw 'InvalidLocalSettings' }
                }
            }
            if ($raw.Contains('entryAliases')) {
                if ($raw.entryAliases -isnot [Collections.IDictionary]) { throw 'InvalidLocalSettings' }
                foreach ($key in $raw.entryAliases.Keys) {
                    [void](ConvertTo-PortableGuidCore $key)
                    if ($raw.entryAliases[$key] -isnot [string]) { throw 'InvalidLocalSettings' }
                }
            }
        } catch { throw 'InvalidLocalSettings' }
    }
    $persisted=ConvertTo-NormalizedAppSettingsCore -Source $raw
    if ($persisted.localePreferenceNeedsConfirmation) { throw 'LocaleMigrationPending' }
    $runtime=[pscustomobject]@{
        locale=$script:UiLocale;localePreferenceSource=$script:LocalePreferenceSource
        localePreferenceNeedsConfirmation=$script:LocalePreferenceNeedsConfirmation
        defaultGuid=$script:LegacyDefaultGuid
        entryOrder=@($script:EntryOrder);hiddenEntryGuids=@($script:HiddenEntryGuids)
        entryAliases=(Copy-EntryAliasMap $script:EntryAliases)
    }
    $payload=ConvertTo-PreferencesSettingsPayload $runtime
    $serialized=ConvertTo-Json -InputObject $payload -Depth 6 -Compress
    if ($serialized -cne (ConvertTo-Json -InputObject (ConvertTo-PreferencesSettingsPayload $persisted) -Depth 6 -Compress)) { throw 'LocalSettingsChanged' }
    $entries=@(foreach ($entry in @($script:CurrentEntries)) { [pscustomobject]@{Guid=(ConvertTo-PortableGuidCore $entry.Guid);Title=[string]$entry.Title} })
    # Include displayed local identity/title/order and exact persisted bytes
    # so a changed refresh or settings write invalidates the preview.
    $entrySnapshot=ConvertTo-Json -InputObject $entries -Depth 3 -Compress
    return [pscustomobject]@{Settings=$runtime;Entries=$entries;Token=$file.Token;Runtime=$serialized;EntrySnapshot=$entrySnapshot}
}

function Assert-PortablePreferencesContextCurrent {
    param($Context)
    $now=Get-PortablePreferencesContext
    if ($now.Token -cne $Context.Token -or $now.Runtime -cne $Context.Runtime -or $now.EntrySnapshot -cne $Context.EntrySnapshot) { throw 'StalePreview' }
    return $now
}

function New-PortablePreferencesImport {
    param([string]$Path)
    $inputFile=Read-PreferencesFileSnapshot -Path $Path
    $document=ConvertFrom-PortablePreferencesCore $inputFile.Text
    $context=Get-PortablePreferencesContext
    return [pscustomobject]@{Document=$document;Context=$context;Plan=(New-PortablePreferencesPlanCore $document $context.Settings $context.Entries)}
}

function Save-PortablePreferencesExport {
    param([string]$Path,$Context)
    $current=Assert-PortablePreferencesContextCurrent $Context
    $full=[IO.Path]::GetFullPath($Path)
    $settingsRoot=[IO.Path]::GetFullPath($script:SettingsDir).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetExtension($full) -ine '.json' -or $full.StartsWith($settingsRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'InvalidDestination' }
    $existing=Read-PreferencesFileSnapshot -Path $full -AllowMissing
    # Never replace another JSON format (especially settings.json or diagnostics).
    if ($existing.Exists) {
        try { [void](ConvertFrom-PortablePreferencesCore $existing.Text) }
        catch { throw 'InvalidDestination' }
    }
    $json=New-PortablePreferencesCore $current.Settings $current.Entries
    Write-PreferencesFileAtomic -Path $full -Text $json -ExpectedToken $existing.Token
}

function Complete-PortablePreferencesImport {
    param($Import)
    $context=Assert-PortablePreferencesContextCurrent $Import.Context
    # Recompute from the validated document, not mutable preview controls.
    $plan=New-PortablePreferencesPlanCore $Import.Document $context.Settings $context.Entries
    $payload=ConvertTo-PreferencesSettingsPayload $context.Settings
    $payload.locale=$plan.Locale
    $payload.localePreferenceSource='user'
    $payload.entryOrder=@($plan.EntryOrder)
    $payload.hiddenEntryGuids=@($plan.HiddenEntryGuids)
    $aliases=[ordered]@{}
    foreach ($key in @($plan.EntryAliases.Keys | Sort-Object)) { $aliases[$key]=$plan.EntryAliases[$key] }
    $payload.entryAliases=$aliases
    $json=ConvertTo-Json -InputObject $payload -Depth 6
    try { Write-PreferencesFileAtomic -Path $script:SettingsPath -Text $json -ExpectedToken $context.Token }
    catch {
        if ($_.Exception.Message -eq 'CommitUncertain') {
            Set-AppSettingsLoadState -Outcome (New-AppSettingsLoadResult -Status 'Unreadable' -Settings $null -FailureKind 'ImportCommitUncertain')
        }
        throw
    }
    # Commit first; no mutable runtime preferences are changed on failed IO.
    $script:UiLocale=$plan.Locale
    $script:LocalePreferenceSource='user'
    $script:LocalePreferenceNeedsConfirmation=$false
    $script:EntryOrder=@($plan.EntryOrder)
    $script:HiddenEntryGuids=@($plan.HiddenEntryGuids)
    $script:EntryAliases=Copy-EntryAliasMap $plan.EntryAliases
    Set-AppSettingsLoadState -Outcome (New-AppSettingsLoadResult -Status 'Loaded' -Settings $null)
    return $plan
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
        if ($script:SystemStatusButton -and -not $script:SystemStatusButton.IsDisposed) {
            $script:SystemStatusButton.AccessibleName = Get-LocalizedString -Key 'SystemStatus.Title'
            $script:SystemStatusButton.AccessibleDescription = Get-LocalizedString -Key 'SystemStatus.Subtitle'
            if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:SystemStatusButton,$script:SystemStatusButton.AccessibleName) }
        }
        if ($script:RefreshButton) { $script:RefreshButton.AccessibleName = Get-LocalizedString -Key 'Action.RefreshBootTargets' }
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

# LBS-179: the undo history is local to one Manage session and contains no UI controls.
function Update-ManageUndoInventory {
    if ($null -eq $script:ManageUndoHistory) { return }
    if (-not $script:IsManageEntriesMode) {
        $script:ManageUndoHistory = $null
        $script:ManageUndoInventory = @()
        return
    }
    $current = @($script:CurrentEntries | ForEach-Object { $_.Guid })
    if (-not (Test-StringSequenceEqual -Left $current -Right $script:ManageUndoInventory -Sort)) {
        $hadHistory = $script:ManageUndoHistory.Count -gt 0
        $script:ManageUndoHistory.Clear()
        $script:ManageUndoInventory = @($current)
        if ($script:ManageAliasEditGuid -and -not (Test-GuidInList -Guid $script:ManageAliasEditGuid -List $current)) {
            # The editor's GUID disappeared; never commit its unfinished text.
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoTargetUnavailable'
        }
        elseif ($hadHistory) { $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoInventoryChanged' }
    }
}

function Get-ManageDraftSnapshot {
    return (New-ManageDraftSnapshotCore -Order $script:ManageEntryOrder -Hidden $script:ManageHiddenEntryGuids -Aliases $script:ManageEntryAliases)
}

function Get-ManageUndoBefore {
    if ($null -eq $script:ManageUndoHistory -or -not $script:IsManageEntriesMode) { return }
    Update-ManageUndoInventory
    return (Get-ManageDraftSnapshot)
}

function Add-ManageUndoCheckpoint {
    param($Before)
    if ($null -eq $Before -or $null -eq $script:ManageUndoHistory) { return }
    if (-not (Test-ManageDraftSnapshotEqualCore -Left $Before -Right (Get-ManageDraftSnapshot))) {
        $script:ManageUndoHistory.Add($Before)
    }
}

function Update-ManageUndoButtonState {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $button = $script:Popup.Controls.Find('ManageUndoButton',$true) | Select-Object -First 1
    if (-not $button) { return }
    $button.Enabled = ($script:IsManageEntriesMode -and $null -ne $script:ManageUndoHistory -and
        $script:ManageUndoHistory.Count -gt 0 -and -not $script:ManageAliasEditGuid -and -not $script:ManageActiveDragGuid)
    $button.AccessibleName = $button.Text
    $button.ForeColor = if ($button.Enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(146,146,146) }
    $button.Cursor = if ($button.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
}

function Undo-ManageEntryDraft {
    if (-not $script:IsManageEntriesMode -or $script:ManageAliasEditGuid -or $script:ManageActiveDragGuid -or $null -eq $script:ManageUndoHistory) { return }
    Update-ManageUndoInventory
    if ($script:ManageUndoHistory.Count -eq 0) {
        Update-PopupRows -Reason 'manage-undo-empty'
        return
    }
    $index = $script:ManageUndoHistory.Count - 1
    $previous = $script:ManageUndoHistory[$index]
    $script:ManageUndoHistory.RemoveAt($index)
    # Copy again so subsequent edits cannot mutate retained snapshots.
    $restored = New-ManageDraftSnapshotCore -Order $previous.Order -Hidden $previous.Hidden -Aliases $previous.Aliases
    $script:ManageEntryOrder = @($restored.Order)
    $script:ManageHiddenEntryGuids = @($restored.Hidden)
    $script:ManageEntryAliases = $restored.Aliases
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.UndoDone'
    $undo = if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Controls.Find('ManageUndoButton',$true) | Select-Object -First 1 }
    $hadFocus = $undo -and $undo.Focused
    Update-PopupRows -Reason 'manage-undo'
    if ($hadFocus -and -not $undo.Enabled) {
        $cancel = $script:Popup.Controls.Find('ManageCancelButton',$true) | Select-Object -First 1
        if ($cancel -and $cancel.CanFocus) { [void]$cancel.Focus() }
    }
}

function Set-ManageEntryAliasDraft {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [AllowEmptyString()][string]$Alias
    )
    $normalized = $Guid.ToLowerInvariant()
    $value = if ($null -eq $Alias) { '' } else { ([string]$Alias).Trim() }
    $previous = [string]$script:ManageEntryAliases[$normalized]
    if (-not (Test-EntryAliasChangeCore -Value $value -Previous $previous)) { return $false }
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $normalized -List $script:ManageUndoInventory)) { return $false }
    }
    if ($value -ceq $previous) { return $true }
    $before = Get-ManageUndoBefore
    if ($value) {
        $script:ManageEntryAliases[$normalized] = $value
    }
    else {
        [void]$script:ManageEntryAliases.Remove($normalized)
    }
    Add-ManageUndoCheckpoint -Before $before
    return $true
}

function Commit-ActiveManageAliasEditor {
    if (-not $script:ManageAliasEditGuid) { return $true }
    if ($script:Popup -and -not $script:Popup.IsDisposed) {
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor -and [string]$editor.Tag) {
            if (-not (Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text))) {
                Show-ManageAliasLimitFeedback -Editor $editor
                return $false
            }
        }
    }
    $script:ManageAliasEditGuid = $null
    return $true
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
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $normalized -List $script:ManageUndoInventory)) { return }
    }
    $before = Get-ManageUndoBefore
    if (Test-ManageEntryHidden -Guid $normalized) {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids | Where-Object { ([string]$_).ToLowerInvariant() -ne $normalized })
    }
    else {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids) + $normalized
    }
    Add-ManageUndoCheckpoint -Before $before
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
    if ($null -ne $script:ManageUndoHistory) {
        Update-ManageUndoInventory
        if (-not (Test-GuidInList -Guid $moved -List $script:ManageUndoInventory) -or
            -not (Test-GuidInList -Guid $target -List $script:ManageUndoInventory)) { return }
    }
    $liveOrder = @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft | ForEach-Object { ([string]$_.Guid).ToLowerInvariant() })
    $movedIndex = [Array]::IndexOf($liveOrder,$moved)
    $targetIndexLive = [Array]::IndexOf($liveOrder,$target)
    if ($movedIndex -ge 0 -and $targetIndexLive -ge 0 -and
        (($After -and $movedIndex -eq ($targetIndexLive+1)) -or
        (-not $After -and $movedIndex -eq ($targetIndexLive-1)))) { return }
    $before = Get-ManageUndoBefore

    # A newly discovered current entry may be displayed before it is explicit
    # in the draft order. Materialize the displayed order for either input path,
    # retaining existing unavailable GUIDs and recording only the actual move.
    $order = @($script:ManageEntryOrder)
    foreach ($entry in @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)) {
        if (-not (Test-GuidInList -Guid ([string]$entry.Guid) -List $order)) { $order += [string]$entry.Guid }
    }
    $list = New-Object System.Collections.ArrayList
    foreach ($guid in $order) {
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
    Add-ManageUndoCheckpoint -Before $before
}

function Update-ManageEntriesUiState {
    Update-ManageUndoInventory
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $sectionLabel = $script:Popup.Controls.Find('SectionLabel', $true) | Select-Object -First 1
    $manageButton = $script:Popup.Controls.Find('ManageEntriesButton', $true) | Select-Object -First 1
    $managePanel = $script:Popup.Controls.Find('ManageEntriesPanel', $true) | Select-Object -First 1
    $configSectionPanel = $script:Popup.Controls.Find('ConfigSectionPanel', $true) | Select-Object -First 1
    $settingsPanel = $script:Popup.Controls.Find('SettingsPanel', $true) | Select-Object -First 1
    $defaultPanel = $script:Popup.Controls.Find('DefaultPanel', $true) | Select-Object -First 1
    $settingsDivider = $script:Popup.Controls.Find('SettingsDivider', $true) | Select-Object -First 1
    $restartPanel = $script:Popup.Controls.Find('RestartPanel', $true) | Select-Object -First 1
    $footerPanel = $script:Popup.Controls.Find('FooterPanel', $true) | Select-Object -First 1

    # LBS-157/LBS-231: manage mode claims 106 additional design pixels,
    # including the removed instructional footer. Reapply after every DPI
    # rescale, before Update-BootEntryScrollLayout calculates the scroll range.
    $entryList = $script:Popup.Controls.Find('EntryList', $true) | Select-Object -First 1
    if ($entryList) {
        $scale = Get-PopupDpiLayoutScale -Popup $script:Popup
        $designHeight = if ($script:IsManageEntriesMode) { 508 } else { 402 }
        $height = [Math]::Max(1,[int][Math]::Round($designHeight * $scale))
        if ($entryList.Height -ne $height) { $entryList.Height = $height }
        $scrollBar = $entryList.Controls['EntryScroll']
        if ($scrollBar -and $scrollBar.Height -ne $height) { $scrollBar.Height = $height }
    }

    if ($sectionLabel) { $sectionLabel.Text = if ($script:IsManageEntriesMode) { Get-LocalizedString -Key 'Manage.Section' } else { Get-LocalizedString -Key 'Popup.NextBootSection' } }
    $keyboardHint = $script:Popup.Controls.Find('ManageKeyboardHint',$true) | Select-Object -First 1
    if ($keyboardHint) {
        $keyboardHint.Visible = $script:IsManageEntriesMode
        $keyboardHint.Text = Get-LocalizedString -Key 'Manage.KeyboardHint'
    }
    if ($manageButton) {
        $manageButton.Visible = -not $script:IsManageEntriesMode
        $manageButton.Enabled = (-not $script:IsManageEntriesMode -and [bool]$capabilities.CanManageEntries)
    }
    if ($managePanel) {
        $managePanel.Visible = $script:IsManageEntriesMode
        if ($script:IsManageEntriesMode) { $managePanel.BringToFront() }
    }
    foreach ($control in @($configSectionPanel,$settingsPanel,$defaultPanel,$settingsDivider,$restartPanel,$footerPanel)) {
        if ($control) { $control.Visible = -not $script:IsManageEntriesMode }
    }

    if ($script:ManageEntriesMenuItem) {
        $script:ManageEntriesMenuItem.Enabled = (-not $script:IsManageEntriesMode -and [bool]$capabilities.CanManageEntries)
    }
    Update-ManageUndoButtonState
}

function Start-ManageEntriesMode {
    param([switch]$PointerActivation)
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if (-not $capabilities.CanManageEntries) { return }
    if ($script:IsManageEntriesMode) { return }

    $script:ManageEntryOrder = @((Get-OrderedEntriesForUi -IncludeHidden) | ForEach-Object { $_.Guid })
    $script:ManageHiddenEntryGuids = @($script:HiddenEntryGuids)
    $script:ManageEntryAliases = Copy-EntryAliasMap $script:EntryAliases
    $script:ManageBaselineEntryOrder = @($script:ManageEntryOrder)
    $script:ManageBaselineHiddenEntryGuids = @($script:ManageHiddenEntryGuids)
    $script:ManageBaselineEntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
    $script:ManageAliasEditGuid = $null
    $script:ManageDropPreview = $null
    $script:ManageActiveDragGuid = $null
    $script:IsManageEntriesMode = $true
    $script:ManageUndoHistory = [System.Collections.Generic.List[object]]::new()
    $script:ManageUndoInventory = @($script:CurrentEntries | ForEach-Object { $_.Guid })
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.StatusEditing'
    Update-ManageEntriesUiState
    Update-PopupRows -Reason 'manage-enter'
    Update-ManageSaveButtonState
    # Only explicit mode entry acquires the primary list focus. Ordinary
    # reconciliation remains responsible for preserving the current owner.
    if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) {
        $anchor = $script:Popup.Controls.Find('BootRow',$true) | Where-Object {
            $_.TabStop -and $_.CanFocus -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode
        } | Sort-Object Top | Select-Object -First 1
        if ($anchor) { Restore-ManageRowFocus -Guid ([string]$anchor.Tag) -KeyboardCue:(-not $PointerActivation.IsPresent) }
    }
}

function Stop-ManageEntriesMode {
    param([switch]$Save)
    if (-not $script:IsManageEntriesMode) { return }
    # Explicit mode exit supersedes any deferred in-mode presentation refresh.
    $script:PopupRowsRefreshPending = $false
    Reset-ManageDragPreview

    if ($Save) {
        if (-not (Commit-ActiveManageAliasEditor)) { return }
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
    $script:ManageUndoHistory = $null
    $script:ManageUndoInventory = @()
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageBaselineEntryOrder = @()
    $script:ManageBaselineHiddenEntryGuids = @()
    $script:ManageBaselineEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    Update-ManageEntriesUiState
    Update-PopupRows -Reason 'manage-exit'
}


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
            if ($script:BootTypeToolTip) {
                $hint = Get-LocalizedString -Key 'Tooltip.DefaultNavigation'
                if (-not $interactive) { $hint = Get-LocalizedString -Key 'Tooltip.Unavailable' }
                foreach ($control in @($script:DefaultButton) + @($script:DefaultButton.Controls)) {
                    $controlHint = if ($control -eq $script:DefaultValueLabel) { $hint + [Environment]::NewLine + $description } else { $hint }
                    if ($script:BootTypeToolTip.GetToolTip($control) -cne $controlHint) { $script:BootTypeToolTip.SetToolTip($control,$controlHint) }
                }
            }
            $script:DefaultValueLabel.ForeColor = if ($pendingDefault) { $script:ColorWarning } elseif ($interactive) { $script:ColorPrimary } else { $mutedInk }
        }
        if ($script:DefaultArrowLabel -and -not $script:DefaultArrowLabel.IsDisposed) {
            $script:DefaultArrowLabel.Visible = (-not $checking -and -not $pendingDefault)
            $script:DefaultArrowLabel.Text = '‹'
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


function Refresh-SystemDefaultState {
    $script:DefaultGuid = $null
    $script:DefaultTargetReadUncertain = $true
    try {
        $script:DefaultGuid = Get-TaskBrokerDefaultTargetGuid
        $script:DefaultTargetReadUncertain = $false
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
    param([AllowNull()][string]$Guid, [AllowNull()][string]$ProgressPath)
    if ($script:DefaultTargetChangePending) { throw 'Ein Standardzielwechsel wird noch überprüft.' }
    if ($script:BootNextPendingGuid) { throw 'Eine manuelle BootNext-Auswahl wird noch verifiziert.' }
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if ([string]$capabilities.State -eq 'Busy') { throw 'Während der Wartung kann das Standard-Startziel nicht geändert werden.' }
    if ([string]$capabilities.State -eq 'ReinitializeRequired') { throw 'Nach einer Änderung der Startziele müssen die Systemfunktionen zuerst neu initialisiert werden.' }
    if (-not $capabilities.CanUseDefaultTarget) { throw 'Das Standard-Startziel ist erst nach Einrichtung der Systemfunktionen verfügbar.' }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $operation = if ($Guid) { 'set' } else { 'clear' }
    try {
        if ($Guid) {
            $normalized = $Guid.ToLowerInvariant()
            Set-TaskBrokerDefaultTarget -Guid $normalized
            if ($ProgressPath) {
                try { [IO.File]::WriteAllText($ProgressPath,'verifying',(New-Object Text.UTF8Encoding($false))) }
                catch { }
            }
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
            if ($ProgressPath) {
                try { [IO.File]::WriteAllText($ProgressPath,'verifying',(New-Object Text.UTF8Encoding($false))) }
                catch { }
            }
            [void](Refresh-SystemDefaultState)
            if ($script:DefaultGuid) { throw 'Das systemweite Standardziel konnte nicht deaktiviert werden.' }
            $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemDisabledStatus'
        }

        # DefaultSet may have synchronized the effective next-boot target inside
        # the privileged SYSTEM task. Re-read firmware before showing success.
        try { [void](Refresh-EffectiveNextBootState) }
        catch {
            $script:NextBootFirmwareReadVerified = $false
            Update-RestartTargetUi
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
        # Default persistence can succeed before a subsequent BootNext verification
        # fails. Reflect both authoritative states rather than claiming a rollback.
        try { [void](Refresh-SystemDefaultState) } catch { }
        try { [void](Refresh-EffectiveNextBootState) } catch { $script:NextBootFirmwareReadVerified = $false }
        Update-RestartTargetUi
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) }) -Level error
        throw
    }
}

# LBS-229: persistent-default selection deliberately uses a separate
# presentation row, never the normal BootNext row's action handler.
function Test-DefaultPickerInteraction {
    if ($script:IsManageEntriesMode -or $script:DefaultTargetChangePending -or $script:BootNextPendingGuid -or (Test-MaintenanceBusy) -or (Test-BootTargetDriftDetected)) { return $false }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    return [bool]([string]$capabilities.State -eq 'Ready' -and $capabilities.CanSetDefaultTarget)
}

function Get-DefaultPickerSnapshot {
    $guids = @(Get-OrderedEntriesForUi | ForEach-Object { [string]$_.Guid })
    return ('{0}|{1}|{2}' -f [string]$script:DefaultGuid,[bool]$script:DefaultTargetReadUncertain,($guids -join ','))
}

function Set-DefaultPickerHover {
    param([System.Windows.Forms.Control]$Control,[bool]$Hover)
    $row = $Control
    while ($row -and $row.Name -ne 'DefaultPickerRow') { $row = $row.Parent }
    if (-not $row) { return }
    if (-not $Hover -and $row.ClientRectangle.Contains($row.PointToClient([Windows.Forms.Cursor]::Position))) { return }
    $row.BackColor = if ($row.Tag.Selected) { $script:ColorSelectedRow } elseif ($Hover) { $script:ColorHover } else { $script:ColorRow }
}

function Invoke-DefaultPickerRow {
    param([System.Windows.Forms.Control]$Control)
    $row = $Control
    while ($row -and $row.Name -ne 'DefaultPickerRow') { $row = $row.Parent }
    if (-not $row -or -not $row.Enabled -or -not (Test-DefaultPickerInteraction)) { return }
    $form = $row.FindForm()
    if ($form.Tag.DefaultSnapshot -ne (Get-DefaultPickerSnapshot)) { $form.DialogResult = [Windows.Forms.DialogResult]::Cancel; return }
    $form.Tag.Choice = [pscustomobject]@{ Guid=$row.Tag.Guid }
    $form.DialogResult = [Windows.Forms.DialogResult]::OK
}

function Add-DefaultPickerRow {
    param($Form,$Entry,[int]$Y)
    Initialize-NormalBootKeyboardRow
    $guid = if ($Entry) { [string]$Entry.Guid } else { $null }
    $titleText = if ($Entry) { Get-EntryDisplayTitle -Entry $Entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
    $subtitleText = if ($Entry) { [string]$Entry.Subtitle } else { Get-LocalizedString -Key 'Settings.DefaultPickerNoneHint' }
    $selected = (-not $script:DefaultTargetReadUncertain -and [string]$script:DefaultGuid -eq [string]$guid)
    $row = New-Object LenovoNormalBootKeyboardRow
    $row.Name = 'DefaultPickerRow'
    $row.Tag = [pscustomobject]@{ Guid=$guid; Selected=$selected }
    $row.Location = [Drawing.Point]::new(0,$Y)
    $row.Size = [Drawing.Size]::new(370,60)
    $row.BackColor = if ($selected) { $script:ColorSelectedRow } else { $script:ColorRow }
    $row.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $row.AccessibleName = [string]$titleText
    $row.AccessibleDescription = if ($selected) { ((Get-LocalizedString -Key 'Settings.DefaultPickerSelected') + '. ' + $subtitleText) } else { $subtitleText }
    $row.Cursor = [Windows.Forms.Cursors]::Hand
    $marker = New-Object Windows.Forms.Panel
    $marker.Size = [Drawing.Size]::new(3,60)
    $marker.BackColor = if ($selected) { $script:ColorAccent } else { $script:ColorRow }
    $row.Controls.Add($marker)
    $symbol = if ($Entry) { [string]$Entry.Symbol } else { '○' }
    $accent = if ($Entry) { $Entry.Accent } else { $script:ColorSecondary }
    $icon = New-Label -Text $symbol -Font $Form.Tag.Symbol -ForeColor $accent -X 22 -Y 7 -Width 28 -Height 44
    $row.Controls.Add($icon)
    $title = New-Label -Text $titleText -Font $Form.Tag.Bold -ForeColor $script:ColorPrimary -X 58 -Y 6 -Width 270 -Height 21
    $title.Name = 'DefaultPickerTitle'
    $title.AccessibleDescription = $titleText
    $row.Controls.Add($title)
    $subtitle = New-Label -Text $subtitleText -Font $Form.Tag.Regular -ForeColor $script:ColorSecondary -X 58 -Y 28 -Width 270 -Height 26
    $subtitle.Name = 'DefaultPickerSubtitle'
    $subtitle.AccessibleDescription = $subtitleText
    $row.Controls.Add($subtitle)
    if ($selected) {
        $check = New-Label -Text '✓' -Font $Form.Tag.Symbol -ForeColor ([Drawing.Color]::FromArgb(255,110,102)) -X 334 -Y 7 -Width 30 -Height 44
        $check.Name = 'DefaultPickerSelected'
        $check.AccessibleName = Get-LocalizedString -Key 'Settings.DefaultPickerSelected'
        $row.Controls.Add($check)
    }
    $hint = if ($selected) { Get-LocalizedString -Key 'Tooltip.CurrentDefault' }
        elseif ($Entry) { Get-LocalizedString -Key 'Tooltip.SetDefault' -Values @{ Target=$titleText } }
        else { Get-LocalizedString -Key 'Tooltip.ClearDefault' }
    $hint += [Environment]::NewLine + $titleText + [Environment]::NewLine + $subtitleText
    foreach ($control in @($row)+@($row.Controls)) {
        $control.Cursor = [Windows.Forms.Cursors]::Hand
        $controlHint = $hint
        if ($control -eq $icon -and $Entry -and $Entry.TypeTooltip) { $controlHint = [string]$Entry.TypeTooltip + [Environment]::NewLine + $hint }
        $Form.Tag.Tip.SetToolTip($control,$controlHint)
        $control.Add_MouseDown({
            param($sender,$eventArgs)
            if ($eventArgs.Button -ne [Windows.Forms.MouseButtons]::Left -or -not (Test-DefaultPickerInteraction)) { return }
            $target = $sender
            while ($target -and $target.Name -ne 'DefaultPickerRow') { $target = $target.Parent }
            Set-LenovoPointerFocus -Control $target
        })
        $control.Add_Click({ param($sender,$eventArgs) Invoke-DefaultPickerRow -Control $sender })
        $control.Add_MouseEnter({ param($sender,$eventArgs) Set-DefaultPickerHover -Control $sender -Hover $true })
        $control.Add_MouseLeave({ param($sender,$eventArgs) Set-DefaultPickerHover -Control $sender -Hover $false })
    }
    $row.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.Modifiers -ne [Windows.Forms.Keys]::None) { return }
        $key = $eventArgs.KeyCode
        if ($key -in @([Windows.Forms.Keys]::Enter,[Windows.Forms.Keys]::Space)) {
            $eventArgs.SuppressKeyPress = $true
            Invoke-DefaultPickerRow -Control $sender
        }
        elseif ($key -in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End)) {
            $eventArgs.SuppressKeyPress = $true
            $rows = @($sender.Parent.Controls | Where-Object { $_.Name -eq 'DefaultPickerRow' -and $_.Enabled } | Sort-Object Top)
            $index = [array]::IndexOf($rows,$sender)
            if ($rows.Count -eq 0 -or $index -lt 0) { return }
            $target = if ($key -eq [Windows.Forms.Keys]::Home) { 0 }
                elseif ($key -eq [Windows.Forms.Keys]::End) { $rows.Count-1 }
                elseif ($key -eq [Windows.Forms.Keys]::Up) { [Math]::Max(0,$index-1) }
                else { [Math]::Min($rows.Count-1,$index+1) }
            [void]$rows[$target].Focus()
            Set-AuxiliaryPopupControlVisible -Control $rows[$target]
        }
    })
    $Form.Tag.Body.Controls.Add($row)
}

function New-DefaultTargetPicker {
    $entries = @(Get-OrderedEntriesForUi)
    $subtitle = Get-LocalizedString -Key 'Settings.DefaultPickerCurrent' -Values @{ Target=(Get-DefaultEntryTitle) }
    $form = New-AuxiliaryPopupForm -Name 'LenovoDefaultTargetPicker' -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Subtitle $subtitle -ContentHeight (60+60*$entries.Count)
    Add-DefaultPickerRow -Form $form -Entry $null -Y 0
    $y = 60
    foreach ($entry in $entries) {
        Add-DefaultPickerRow -Form $form -Entry $entry -Y $y
        $y += 60
    }
    $form.Tag.DefaultSnapshot = Get-DefaultPickerSnapshot
    # If an independently completing refresh changes the selection inventory or
    # the verified default while the modal picker is open, dismiss stale choices.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        $active = $script:ActiveAuxiliaryPopup
        if ($active -and $active.Name -eq 'LenovoDefaultTargetPicker' -and
            (-not (Test-DefaultPickerInteraction) -or $active.Tag.DefaultSnapshot -ne (Get-DefaultPickerSnapshot))) {
            $active.DialogResult = [Windows.Forms.DialogResult]::Cancel
        }
    })
    $form.Tag.Timer = $timer
    $form.Add_Shown({ $this.Tag.Timer.Start() })
    return $form
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or -not (Test-DefaultPickerInteraction)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    $choice = Show-OwnedAuxiliaryPopup -Form (New-DefaultTargetPicker) -Owner $Owner
    if (-not $choice -or -not (Test-DefaultPickerInteraction)) { return }
    # The canonical asynchronous controller rechecks capability, current GUID
    # and allowlist before any write. Close and focus alone are read-only.
    try {
        if ($choice.Guid) { Start-DefaultTargetChange -Guid ([string]$choice.Guid) }
        else { Start-DefaultTargetChange -Guid $null }
    }
    catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
}


# LBS-144: regular modal forms have 96-DPI *pixel* geometry but
# typographic point-unit fonts. Do not reuse the popup's script-global
# design metric cache and never multiply Font.Size by the monitor factor.
# All controls are new and scaled exactly once before ShowDialog().
# Calculate a visible top-left in the SAME WinForms coordinate space as the
# selected Screen.WorkingArea, including negative-origin external displays.
function Get-LenovoVisibleDialogLocation {
    param(
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea,
        [Parameter(Mandatory=$true)][Drawing.Size]$WindowSize
    )
    if ($WorkingArea.Width -le 0 -or $WorkingArea.Height -le 0 -or
        $WindowSize.Width -le 0 -or $WindowSize.Height -le 0) {
        throw 'Invalid dialog work-area or size.'
    }
    $centerX = [int][Math]::Floor($WorkingArea.Left + ($WorkingArea.Width - $WindowSize.Width) / 2.0)
    $centerY = [int][Math]::Floor($WorkingArea.Top + ($WorkingArea.Height - $WindowSize.Height) / 2.0)
    $maxX = [Math]::Max($WorkingArea.Left, $WorkingArea.Right - $WindowSize.Width)
    $maxY = [Math]::Max($WorkingArea.Top, $WorkingArea.Bottom - $WindowSize.Height)
    return [Drawing.Point]::new(
        [int][Math]::Min($maxX,[Math]::Max($WorkingArea.Left,$centerX)),
        [int][Math]::Min($maxY,[Math]::Max($WorkingArea.Top,$centerY)))
}

# The pre-Show WinForms size/position can change when the native HWND is
# created (host MaxWindowTrackSize, mixed-DPI and monitor selection).
# Clamp once again inside Shown, before the existing physical DWM snapshot.
function Register-LenovoDialogVisibilityCorrection {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][System.Windows.Forms.Screen]$Screen
    )
    $screenCopy = $Screen
    $Form.Add_Shown({
        if ($this.IsDisposed) { return }
        $this.Location = Get-LenovoVisibleDialogLocation -WorkingArea $screenCopy.WorkingArea -WindowSize $this.Size
        if ($this.Visible) { [void]$this.Activate() }
    }.GetNewClosure())
}

function Get-LenovoDialogScaledSize {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$DesignSize,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid dialog DPI scale.' }
    return [Drawing.Size]::new(
        [Math]::Max(1,[int][Math]::Round($DesignSize.Width * $Scale,[MidpointRounding]::AwayFromZero)),
        [Math]::Max(1,[int][Math]::Round($DesignSize.Height * $Scale,[MidpointRounding]::AwayFromZero)))
}

# Shared regular modal presentation; the form's Tag still belongs to its caller.
function Initialize-LenovoRegularDialog {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Panel]$Root,
        [Windows.Forms.Label]$Title,[Windows.Forms.Panel]$Divider,
        [Windows.Forms.Label]$Glyph,[Windows.Forms.Control[]]$Content,
        [Windows.Forms.Button[]]$Buttons)
    $Root.Dock=[Windows.Forms.DockStyle]::Fill
    $Root.BackColor = [Drawing.Color]::FromArgb(31,31,31)
    $Form.BackColor = $Root.BackColor
    $Form.Text = $Title.Text
    $Form.AccessibleName = $Title.Text
    $header = New-Object Windows.Forms.Panel
    $header.Name='DialogHeader'
    $header.BackColor=[Drawing.Color]::FromArgb(9,9,9)
    $Title.Name='DialogTitle'
    $Title.UseMnemonic=$false
    $Title.BackColor=$header.BackColor
    $header.Controls.Add($Title)
    $header.Controls.Add($Divider)
    $viewport = New-Object Windows.Forms.Panel
    $viewport.Name='DialogViewport'
    $viewport.BackColor=$Root.BackColor
    $body = New-Object Windows.Forms.Panel
    $body.Name='DialogBody'
    $body.BackColor=$Root.BackColor
    if ($Glyph) { $body.Controls.Add($Glyph); $Glyph.Name='DialogGlyph' }
    foreach ($control in $Content) {
        if ($control -is [Windows.Forms.Label]) { $control.UseMnemonic=$false }
        $body.Controls.Add($control)
    }
    $viewport.Controls.Add($body)
    $footer = New-Object Windows.Forms.Panel
    $footer.Name='DialogActions'
    $footer.BackColor=[Drawing.Color]::FromArgb(24,24,24)
    # Reparenting a button clears WinForms' accept/cancel reference. Preserve
    # the actual existing default actions after the new parent is attached.
    $accept=$Form.AcceptButton
    $cancel=$Form.CancelButton
    foreach ($button in $Buttons) { $footer.Controls.Add($button) }
    $Root.Controls.Add($header)
    $Root.Controls.Add($viewport)
    $Root.Controls.Add($footer)
    $Form.AcceptButton=$accept
    $Form.CancelButton=$cancel
    $scroll=$null
    # Production reuses the main/auxiliary red/dark scrollbar. Isolated hosts
    # without that control type retain a content-only native scroll fallback.
    if ('LenovoVerticalScrollBar' -as [type]) {
        $scroll=New-Object LenovoVerticalScrollBar
        $scroll.Name='DialogScroll'
        $scroll.TrackColor=[Drawing.Color]::FromArgb(23,23,23)
        $scroll.ThumbColor=$script:ColorAccent
        $scroll.ThumbHoverColor=[Drawing.Color]::FromArgb(242,59,49)
        $scroll.Visible=$false
        $viewport.Controls.Add($scroll)
        $scroll.Add_ValueChanged({ $body.Top=-$scroll.Value }.GetNewClosure())
        $wheel = {
            param($sender,$eventArgs)
            if (-not $scroll.Visible -or -not $eventArgs.Delta) { return }
            if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) {
                if ($eventArgs.Handled) { return }
                $eventArgs.Handled=$true
            }
            $scroll.Value -= [int]([Math]::Sign($eventArgs.Delta)*$scroll.SmallChange)
        }.GetNewClosure()
        $Form.Add_KeyDown({
            param($sender,$eventArgs)
            if (-not $scroll.Visible) { return }
            switch ($eventArgs.KeyCode) {
                ([Windows.Forms.Keys]::PageUp) { $scroll.Value -= $scroll.LargeChange }
                ([Windows.Forms.Keys]::PageDown) { $scroll.Value += $scroll.LargeChange }
                ([Windows.Forms.Keys]::Home) { if (-not $eventArgs.Control) { return }; $scroll.Value=0 }
                ([Windows.Forms.Keys]::End) { if (-not $eventArgs.Control) { return }; $scroll.Value=$scroll.Maximum }
                default { return }
            }
            $eventArgs.Handled=$true
            $eventArgs.SuppressKeyPress=$true
        }.GetNewClosure())
        foreach ($control in (@($viewport,$body,$Glyph)+@($Content))) {
            if ($control) { $control.Add_MouseWheel($wheel) }
        }
    }
    $Root.Tag=[pscustomobject]@{Kind='LenovoRegularDialog';Header=$header;Title=$Title;Divider=$Divider;Viewport=$viewport;Body=$body;Glyph=$Glyph;Content=$Content;Footer=$footer;Buttons=$Buttons;Scroll=$scroll}
}

function Set-LenovoRegularDialogDpiLayout {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Panel]$Root,[double]$Scale,[Drawing.Rectangle]$WorkingArea)
    $s=$Root.Tag
    function Px([double]$value) { [Math]::Max(1,[int][Math]::Round($value*$Scale)) }
    $Form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None
    $track=[Windows.Forms.SystemInformation]::MaxWindowTrackSize
    $maxWidth=[Math]::Min($WorkingArea.Width,$track.Width)
    $maxHeight=[Math]::Min($WorkingArea.Height,$track.Height)
    $width=[Math]::Min((Px 500),$maxWidth)
    $pad=Px 20
    $gap=Px 10
    $bitmap=New-Object Drawing.Bitmap(8,8)
    try {
        $bitmap.SetResolution([single](96*$Scale),[single](96*$Scale))
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            function LabelHeight($label,[int]$w) {
                $label.UseCompatibleTextRendering=$true
                $label.AutoEllipsis=$false
                $label.AutoSize=$false
                $measured=$graphics.MeasureString([string]$label.Text,$label.Font,[Math]::Max(1,$w))
                return [Math]::Max((Px 22),[int][Math]::Ceiling($measured.Height)+(Px 6))
            }
            $headerHeight=[Math]::Max((Px 49),((LabelHeight $s.Title ($width-2*$pad))+(Px 20)))
            $buttonHeight=Px 34
            $buttonWidths=@()
            foreach ($button in $s.Buttons) {
                $labels=@([string]$button.Text)
                if ($button.Tag -is [string[]]) { $labels+=@($button.Tag) }
                $maxText=0
                foreach ($label in $labels) { $maxText=[Math]::Max($maxText,[int][Math]::Ceiling($graphics.MeasureString($label,$button.Font).Width)) }
                $buttonWidths+= [Math]::Min(($width-2*$pad),[Math]::Max((Px 110),($maxText+(Px 24))))
            }
            $total=0
            foreach ($w in $buttonWidths) { $total+=$w }
            $total+=$gap*[Math]::Max(0,$s.Buttons.Count-1)
            $stacked=$total -gt ($width-2*$pad)
            $footerHeight=if ($stacked) { (Px 22)+$s.Buttons.Count*$buttonHeight+($s.Buttons.Count-1)*$gap } else { $buttonHeight+(Px 22) }
            $available=[Math]::Max(1,$maxHeight-$headerHeight-$footerHeight)
            $bodyWidth=$width
            $gutter=0
            $contentHeight=0
            for ($pass=0;$pass -lt 2;$pass++) {
                $bodyWidth=$width-$gutter
                $y=Px 16
                $first=$true
                foreach ($control in $s.Content) {
                    $left=$pad
                    if ($first -and $s.Glyph) { $left+=(Px 40) }
                    $cw=[Math]::Max(1,$bodyWidth-$left-$pad)
                    $ch=LabelHeight $control $cw
                    $control.Bounds=[Drawing.Rectangle]::new($left,$y,$cw,$ch)
                    if ($first -and $s.Glyph) {
                        $s.Glyph.Bounds=[Drawing.Rectangle]::new($pad,$y,(Px 30),(Px 34))
                        $ch=[Math]::Max($ch,(Px 34))
                    }
                    $y+=$ch+(Px 6)
                    $first=$false
                }
                $contentHeight=$y+(Px 10)
                if ($contentHeight -le $available -or $pass -eq 1) { break }
                $gutter=if ($s.Scroll) { Px 12 } else { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
            }
            $viewportHeight=[Math]::Min($available,$contentHeight)
            $Form.ClientSize=[Drawing.Size]::new($width,($headerHeight+$viewportHeight+$footerHeight))
            $s.Header.Bounds=[Drawing.Rectangle]::new(0,0,$width,$headerHeight)
            $s.Title.Bounds=[Drawing.Rectangle]::new($pad,(Px 9),($width-2*$pad),($headerHeight-(Px 19)))
            $s.Divider.Bounds=[Drawing.Rectangle]::new(0,($headerHeight-(Px 2)),$width,(Px 2))
            $s.Viewport.Bounds=[Drawing.Rectangle]::new(0,$headerHeight,$width,$viewportHeight)
            $s.Body.Bounds=[Drawing.Rectangle]::new(0,0,$bodyWidth,$contentHeight)
            $s.Footer.Bounds=[Drawing.Rectangle]::new(0,($headerHeight+$viewportHeight),$width,$footerHeight)
            if ($s.Scroll) {
                $s.Scroll.Bounds=[Drawing.Rectangle]::new(($width-(Px 10)),0,(Px 10),$viewportHeight)
                $s.Scroll.Maximum=[Math]::Max(0,$contentHeight-$viewportHeight)
                $s.Scroll.LargeChange=$viewportHeight
                $s.Scroll.SmallChange=Px 60
                $s.Scroll.Value=0
                $s.Scroll.Visible=$s.Scroll.Maximum -gt 0
                $s.Scroll.BringToFront()
            } else {
                $s.Viewport.AutoScroll=$contentHeight -gt $viewportHeight
                if ($s.Viewport.AutoScroll) { $s.Viewport.AutoScrollMinSize=[Drawing.Size]::new($bodyWidth,$contentHeight) }
            }
            $x=if ($stacked) { $pad } else { $width-$pad-$total }
            $y=Px 11
            for ($i=0;$i -lt $s.Buttons.Count;$i++) {
                $bw=if ($stacked) { $width-2*$pad } else { $buttonWidths[$i] }
                $s.Buttons[$i].Bounds=[Drawing.Rectangle]::new($x,$y,$bw,$buttonHeight)
                if ($stacked) { $y+=$buttonHeight+$gap } else { $x+=$bw+$gap }
            }
        } finally { $graphics.Dispose() }
    } finally { $bitmap.Dispose() }
    $Form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
    $Form.Location=Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
}

function Set-LenovoDialogDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid dialog DPI scale.' }
    if ($WorkingArea.Width -le 0 -or $WorkingArea.Height -le 0) { throw 'Invalid dialog work area.' }
    $regularRoot = $Form.Controls | Where-Object { $_ -is [Windows.Forms.Panel] -and $_.Tag -and $_.Tag.Kind -eq 'LenovoRegularDialog' } | Select-Object -First 1
    if ($regularRoot) {
        Set-LenovoRegularDialogDpiLayout -Form $Form -Root $regularRoot -Scale $Scale -WorkingArea $WorkingArea
        return
    }
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $baseline = $Form.ClientSize
    $pending = New-Object System.Collections.Stack
    $pending.Push($Form)
    $entries = New-Object 'System.Collections.Generic.List[object]'
    while ($pending.Count -gt 0) {
        $control = [System.Windows.Forms.Control]$pending.Pop()
        $entries.Add([pscustomobject]@{
            Control = $control
            Bounds = $control.Bounds
            Padding = $control.Padding
            Margin = $control.Margin
            Dock = $control.Dock
        })
        foreach ($child in $control.Controls) { $pending.Push($child) }
    }
    foreach ($entry in $entries) { $entry.Control.SuspendLayout() }
    try {
        foreach ($entry in $entries) {
            $control = [System.Windows.Forms.Control]$entry.Control
            if ([object]::ReferenceEquals($control, $Form)) { continue }
            if ($entry.Dock -eq [System.Windows.Forms.DockStyle]::None) {
                $r = $entry.Bounds
                $control.Bounds = [Drawing.Rectangle]::new(
                    [int][Math]::Round($r.Left * $Scale),
                    [int][Math]::Round($r.Top * $Scale),
                    [Math]::Max(1,[int][Math]::Round($r.Width * $Scale)),
                    [Math]::Max(1,[int][Math]::Round($r.Height * $Scale)))
            }
            $p = $entry.Padding
            $control.Padding = [System.Windows.Forms.Padding]::new(
                [int][Math]::Round($p.Left * $Scale),[int][Math]::Round($p.Top * $Scale),
                [int][Math]::Round($p.Right * $Scale),[int][Math]::Round($p.Bottom * $Scale))
            $m = $entry.Margin
            $control.Margin = [System.Windows.Forms.Padding]::new(
                [int][Math]::Round($m.Left * $Scale),[int][Math]::Round($m.Top * $Scale),
                [int][Math]::Round($m.Right * $Scale),[int][Math]::Round($m.Bottom * $Scale))
        }
        $desired = Get-LenovoDialogScaledSize -DesignSize $baseline -Scale $Scale
        $Form.ClientSize = $desired
        # WinForms may cap an unshown borderless form to the actual desktop
        # MaxWindowTrackSize (small CI displays). Preserve access to every
        # scaled control through the root panel's scrollable virtual client.
        foreach ($entry in $entries) {
            $control = [System.Windows.Forms.Control]$entry.Control
            if ([object]::ReferenceEquals($control.Parent, $Form) -and $control -is [System.Windows.Forms.Panel]) {
                $control.Dock = [System.Windows.Forms.DockStyle]::Fill
            }
        }
        $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $Form.Location = Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
    }
    finally {
        for ($i = $entries.Count - 1; $i -ge 0; $i--) {
            $entries[$i].Control.ResumeLayout($true)
        }
    }
    # An unshown WinForms form may only adopt the system's MaxWindowTrackSize
    # *after* ResumeLayout. Check the resulting client here, not before.
    if ($Form.ClientSize.Width -lt $desired.Width -or $Form.ClientSize.Height -lt $desired.Height) {
        foreach ($control in $Form.Controls) {
            if ($control -is [System.Windows.Forms.Panel]) {
                $control.AutoScroll = $true
                $control.AutoScrollMinSize = $desired
            }
        }
    }
}

function Prepare-LenovoDialogDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Form]$Owner,
        [string]$Role = 'regular-modal'
    )
    $screen = if ($Owner -and -not $Owner.IsDisposed -and $Owner.Visible) {
        [System.Windows.Forms.Screen]::FromControl($Owner)
    }
    # Without a visible owner, use the stable primary display rather than
    # a possibly DPI-virtualized cursor coordinate on a secondary monitor.
    else { [System.Windows.Forms.Screen]::PrimaryScreen }
    if (-not $screen) { $screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    $scale = Get-LenovoUiCoordinateScale -Screen $screen
    Set-LenovoDialogDpiLayout -Form $Form -Scale ([double]$scale.Factor) -WorkingArea $screen.WorkingArea
    Register-LenovoDialogVisibilityCorrection -Form $Form -Screen $screen
    Write-LenovoMonitorTopologyEvent -Phase ('before-' + $Role) -Screen $screen
    Register-LenovoDialogDpiWindowDiagnostics -Form $Form -Role $Role -Screen $screen -RequestedScale ([double]$scale.Factor)
}

# Resolve the deepest visible modal owner at display time, not at worker start.
# Closing settings during a worker does not reopen it or an abandoned main popup.
function Get-LenovoDialogOwner {
    foreach ($candidate in @($script:ActiveOwnedDialog,$script:ActiveAuxiliaryPopup,$script:Popup)) {
        if ($candidate -and -not $candidate.IsDisposed -and $candidate.Visible) { return $candidate }
    }
    return $null
}

function Show-LenovoOwnedDialog {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Form]$Owner)
    $previous = $script:ActiveOwnedDialog
    $dimmer = $null
    $auxiliaryOwner = $null
    $returnFocus = $null
    if ($Owner -and -not $Owner.IsDisposed -and [object]::ReferenceEquals($Owner,$script:ActiveAuxiliaryPopup)) {
        $auxiliaryOwner = $Owner
        $returnFocus = $Owner.Tag.Body.Controls | Where-Object { $_.Focused } | Select-Object -First 1
    }
    $script:ActiveOwnedDialog = $Form
    try {
        if ($Owner -and -not $Owner.IsDisposed -and $Owner.Visible) {
            # The main owner's existing scrim remains alive; dim the immediate
            # modal owner only, without a navigation cutout or connector.
            if ($script:ActiveAuxiliaryPopup) {
                if ($auxiliaryOwner) { $auxiliaryOwner.Tag.Close.Refresh() }
                Initialize-AuxiliaryOwnerDimmer
                $dimmer = [LenovoAuxiliaryOwnerDimmer]::new($Owner,$null,$Form,1.0,$script:ColorHover,$script:ColorAccent)
                $dimmer.Show($Owner)
            }
            return $Form.ShowDialog($Owner)
        }
        return $Form.ShowDialog()
    }
    finally {
        try { if ($dimmer) { $dimmer.Dispose() } }
        finally {
            $script:ActiveOwnedDialog = $previous
            if ($auxiliaryOwner -and -not $auxiliaryOwner.IsDisposed -and $auxiliaryOwner.Visible -and
                [object]::ReferenceEquals($auxiliaryOwner,$script:ActiveAuxiliaryPopup)) {
                if ($returnFocus -and -not $returnFocus.IsDisposed -and $returnFocus.CanFocus -and
                    $auxiliaryOwner.ContainsFocus) { [void]$returnFocus.Focus() }
                $auxiliaryOwner.Tag.Close.Refresh()
            }
        }
    }
}

function Show-LenovoNoticeDialog {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Heading,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error')][string]$Kind = 'Info',
        [string]$SecondaryButtonText,
        [scriptblock]$SecondaryAction,
        [switch]$PromoteSecondaryAction,
        [string]$DismissButtonText,
        [string]$ValueCaption,
        [string]$ValueText,
        [switch]$KeepOpenAfterSecondary
    )

    # Only the available-update notice promotes the optional action.
    # Require a named safe dismissal so Enter/Escape cannot install by default.
    if ($PromoteSecondaryAction -and
        ([string]::IsNullOrWhiteSpace($SecondaryButtonText) -or
         -not $SecondaryAction -or
         [string]::IsNullOrWhiteSpace($DismissButtonText))) {
        throw 'Promoted notice actions require explicit install and dismiss labels.'
    }

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

    $titleLabel = New-Label -Text $Title -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 420 -Height 24
    $root.Controls.Add($titleLabel)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(434,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyphText = if ($Kind -eq 'Success') { '✓' } elseif ($Kind -eq 'Error') { '×' } elseif ($Kind -eq 'Warning') { '!' } else { 'i' }
    $glyphColor = if ($Kind -eq 'Success') { [Drawing.Color]::FromArgb(104,206,141) } elseif ($Kind -eq 'Error') { $script:ColorAccent } elseif ($Kind -eq 'Warning') { $script:ColorWarning } else { $script:ColorCyan }
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $headingLabel = New-Label -Text $Heading -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 380 -Height 24
    $root.Controls.Add($headingLabel)
    $messageLabel = New-Label -Text $Message -Font (New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 88 -Width 380 -Height 78
    $messageLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($messageLabel)
    $headingLabel.Name='DialogHeading'
    $messageLabel.Name='DialogMessage'
    $content=@($headingLabel)
    if ($ValueCaption -and $ValueText) {
        $caption=New-Label -Text $ValueCaption -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorSecondary -X 20 -Y 0 -Width 460 -Height 24
        $caption.Name='DialogValueCaption'
        $caption.BackColor=[Drawing.Color]::FromArgb(21,21,21)
        $value=New-Label -Text $ValueText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 20 -Y 0 -Width 460 -Height 24
        $value.Name='DialogValue'
        $value.AccessibleName=$ValueCaption
        $value.AccessibleDescription=$ValueText
        $value.BackColor=$caption.BackColor
        $content+=@($caption,$value)
    }
    $content+=@($messageLabel)
    $secondary=$null

    if (-not [string]::IsNullOrWhiteSpace($SecondaryButtonText) -and $SecondaryAction) {
        $secondary = New-Object System.Windows.Forms.Button
        $secondary.Text = $SecondaryButtonText
        $secondary.Font = if ($PromoteSecondaryAction) {
            New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold)
        } else { New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular) }
        $secondary.ForeColor = if ($PromoteSecondaryAction) { [Drawing.Color]::White } else { $script:ColorPrimary }
        $secondary.BackColor = if ($PromoteSecondaryAction) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(34,34,34) }
        $secondary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $secondary.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
        $secondary.FlatAppearance.BorderSize = if ($PromoteSecondaryAction) { 0 } else { 1 }
        $secondary.FlatAppearance.MouseOverBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(242,59,49) } else { [Drawing.Color]::FromArgb(46,46,46) }
        $secondary.FlatAppearance.MouseDownBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(185,30,22) } else { [Drawing.Color]::FromArgb(38,38,38) }
        $secondary.Location = if ($PromoteSecondaryAction) { New-Object Drawing.Point(306,190) } else { New-Object Drawing.Point(184,190) }
        $secondary.Size = New-Object Drawing.Size(146,34)
        $secondary.TabIndex = if ($PromoteSecondaryAction) { 1 } else { 0 }
        $secondary.Cursor = [System.Windows.Forms.Cursors]::Hand
        $secondaryActionLocal = $SecondaryAction
        $dialogLocal = $form
        $keepOpenLocal=[bool]$KeepOpenAfterSecondary
        $copiedText=if ($keepOpenLocal) { Get-LocalizedString -Key 'Diagnostics.Copied' } else { '' }
        $copyFailedText=if ($keepOpenLocal) { Get-LocalizedString -Key 'Diagnostics.CopyFailed' } else { '' }
        $originalText=$secondary.Text
        $originalColor=$secondary.ForeColor
        if ($keepOpenLocal) {
            $secondary.Tag=[string[]]@($copiedText,$copyFailedText)
            $feedbackTimer=New-Object Windows.Forms.Timer
            $feedbackTimer.Interval=2000
            $copyButton=$secondary
            $feedbackTimer.Add_Tick({
                $feedbackTimer.Stop()
                if (-not $copyButton.IsDisposed) {
                    $copyButton.Text=$originalText
                    $copyButton.ForeColor=$originalColor
                    $copyButton.AccessibleDescription=''
                }
            }.GetNewClosure())
            $form.Add_Disposed({ $feedbackTimer.Stop(); $feedbackTimer.Dispose() }.GetNewClosure())
        }
        $secondary.Add_Click({
            param($sender,$eventArgs)
            try {
                $result = & $secondaryActionLocal
                if ($keepOpenLocal) {
                    $confirmed=($result -eq $true)
                    $sender.Text=if ($confirmed) { $copiedText } else { $copyFailedText }
                    $sender.ForeColor=if ($confirmed) { [Drawing.Color]::FromArgb(104,206,141) } else { [Drawing.Color]::FromArgb(236,191,68) }
                    $sender.AccessibleDescription=$sender.Text
                    $feedbackTimer.Stop()
                    $feedbackTimer.Start()
                } elseif ($result -ne $false) {
                    $dialogLocal.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $dialogLocal.Close()
                }
            } catch {
                if ($keepOpenLocal) {
                    $sender.Text=$copyFailedText
                    $sender.ForeColor=[Drawing.Color]::FromArgb(236,191,68)
                    $sender.AccessibleDescription=$copyFailedText
                    $feedbackTimer.Stop()
                    $feedbackTimer.Start()
                }
            }
        }.GetNewClosure())
        $root.Controls.Add($secondary)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = if ($PromoteSecondaryAction) { $DismissButtonText } else { Get-LocalizedString -Key 'Common.OK' }
    $ok.Font = if ($PromoteSecondaryAction) {
        New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
    } else { New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold) }
    $ok.ForeColor = if ($PromoteSecondaryAction) { $script:ColorPrimary } else { [Drawing.Color]::White }
    $ok.BackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(34,34,34) } else { $script:ColorAccent }
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $ok.FlatAppearance.BorderSize = if ($PromoteSecondaryAction) { 1 } else { 0 }
    $ok.FlatAppearance.MouseOverBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(46,46,46) } else { [Drawing.Color]::FromArgb(242,59,49) }
    $ok.FlatAppearance.MouseDownBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(38,38,38) } else { [Drawing.Color]::FromArgb(185,30,22) }
    $ok.Location = if ($PromoteSecondaryAction) { New-Object Drawing.Point(184,190) } else { New-Object Drawing.Point(342,190) }
    $ok.Size = New-Object Drawing.Size(110,34)
    $ok.TabIndex = if ($PromoteSecondaryAction) { 0 } else { 1 }
    $ok.Cursor = [System.Windows.Forms.Cursors]::Hand
    $ok.DialogResult = if ($PromoteSecondaryAction) { [System.Windows.Forms.DialogResult]::Cancel } else { [System.Windows.Forms.DialogResult]::OK }
    $root.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $ok
    $buttons=if ($secondary) {
        if ($PromoteSecondaryAction) { @($ok,$secondary) } else { @($secondary,$ok) }
    } else { @($ok) }
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $titleLabel -Divider $divider -Glyph $glyph -Content $content -Buttons $buttons
    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'notice'
        if ($PromoteSecondaryAction) {
            # Safe dismissal receives initial focus even if the native tab
            # traversal order or owner activation changes during ShowDialog.
            $dismissButtonLocal = $ok
            $form.Add_Shown({
                if (-not $dismissButtonLocal.IsDisposed -and $dismissButtonLocal.CanFocus) {
                    [void]$dismissButtonLocal.Focus()
                }
            }.GetNewClosure())
        }
        [void](Show-LenovoOwnedDialog -Form $form -Owner $owner)
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

    $title = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationTitle') -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $heading = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationHeading') -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 28 -Y 62 -Width 440 -Height 24
    $root.Controls.Add($heading)
    $message = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationMessage') -Font (New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 28 -Y 92 -Width 440 -Height 92
    $message.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($message)

    $german = New-Object System.Windows.Forms.Button
    $german.Text = Get-LocalizedString -Key 'Language.MigrationKeepGerman'
    $german.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)
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
    $english.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Bold)
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
    $heading.Name='DialogHeading'
    $message.Name='DialogMessage'
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Content @($heading,$message) -Buttons @($german,$english)

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'language-migration'
        [void](Show-LenovoOwnedDialog -Form $form -Owner $owner)
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

    $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI',15.0,[Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)
    $heading = New-Label -Text $headingText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 410 -Height 24
    $root.Controls.Add($heading)
    $bodyHeight = if ($isRemove) { 145 } else { 90 }
    $body = New-Label -Text $bodyText -Font (New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 90 -Width 410 -Height $bodyHeight
    $body.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($body)

    $buttonY = $height - 54
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)
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
    $primary.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Bold)
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
    $heading.Name='DialogHeading'
    $body.Name='DialogMessage'
    $content=@($heading,$body)
    if ($isRemove) {
        # Split the existing three localized paragraphs without losing their facts.
        $paragraphs=$bodyText -split '\r?\n\r?\n'
        if ($paragraphs.Count -eq 3) {
            $changes=New-Label -Text (Get-LocalizedString -Key 'Maintenance.Dialog.Changes') -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorWarning -X 20 -Y 0 -Width 460 -Height 24
            $changes.BackColor=[Drawing.Color]::FromArgb(48,40,29)
            $body.Text=$paragraphs[0]+[Environment]::NewLine+$paragraphs[1]
            $body.BackColor=$changes.BackColor
            $retained=New-Label -Text (Get-LocalizedString -Key 'Maintenance.Dialog.Retained') -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor ([Drawing.Color]::FromArgb(104,206,141)) -X 20 -Y 0 -Width 460 -Height 24
            $retained.BackColor=[Drawing.Color]::FromArgb(32,44,36)
            $retainedBody=New-Label -Text $paragraphs[2] -Font (New-Object Drawing.Font('Segoe UI',9.5)) -ForeColor $script:ColorSecondary -X 20 -Y 0 -Width 460 -Height 24
            $retainedBody.BackColor=$retained.BackColor
            $content=@($heading,$changes,$body,$retained,$retainedBody)
        }
    }
    $form.AcceptButton = $primary
    $form.CancelButton = $cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Glyph $glyph -Content $content -Buttons @($cancel,$primary)
    $form.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'system-functions'
        return (Show-LenovoOwnedDialog -Form $form -Owner $owner)
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

    $title = New-Label -Text (Get-LocalizedString -Key 'Restart.DialogTitle') -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) `
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

    $targetCaption = New-Label -Text (Get-LocalizedString -Key 'Restart.NextTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 54 -Y 92 -Width 330 -Height 18
    $root.Controls.Add($targetCaption)

    $target = New-Label -Text $TargetName -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 109 -Width 342 -Height 24
    $target.AutoEllipsis = $true
    $root.Controls.Add($target)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
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
    $restart.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold)
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

    $question.Name='DialogHeading'
    $targetCaption.Name='DialogValueCaption'
    $target.Name='DialogValue'
    $target.AccessibleDescription=$TargetName
    $target.AutoEllipsis=$false
    $targetCaption.BackColor=[Drawing.Color]::FromArgb(21,21,21)
    $target.BackColor=$targetCaption.BackColor
    $form.AcceptButton = $restart
    $form.CancelButton = $cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Glyph $glyph -Content @($question,$targetCaption,$target) -Buttons @($cancel,$restart)
    $form.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'restart-confirmation'
        return (Show-LenovoOwnedDialog -Form $form -Owner $owner)
    }
    finally {
        $form.Dispose()
    }
}

# Manual preference workflows. Imported text is data, never an action.
function Update-PortablePreferencesMenuState {
    $available=[bool](Test-PortablePreferencesAvailable -PresentationOnly)
    foreach ($item in @($script:PreferencesExportMenuItem,$script:PreferencesImportMenuItem)) {
        if ($item -and -not $item.IsDisposed) { $item.Enabled=$available }
    }
}

function Format-PreferencesPreviewValue {
    param([AllowEmptyString()][string]$Value)
    if (-not $Value) { return (Get-LocalizedString -Key 'Preferences.NoAlias') }
    # Escape invisible control/format characters so they cannot spoof a row.
    $literal=[regex]::Replace($Value.Replace('\','\\'),'[\p{Cc}\p{Cf}]',[System.Text.RegularExpressions.MatchEvaluator]{
        param($match) return ('\u{0:x4}' -f [int][char]$match.Value[0])
    })
    return ('"'+$literal.Replace('"','\"')+'"')
}

# Presentation projections never mutate the validated reconciliation plan.
function Get-PreferencesChangedFields {
    param($Row)
    if ($Row.Status -ne 'Matched') { return }
    if ($Row.OldAlias -cne $Row.NewAlias) { 'Alias' }
    if ($Row.OldHidden -ne $Row.NewHidden) { 'Visibility' }
    if ($Row.OldPosition -ne $Row.NewPosition) { 'Order' }
}

function New-PreferencesPreviewView {
    param($Plan)
    $rows=[Collections.Generic.List[object]]::new()
    foreach ($row in @($Plan.Rows)) {
        $fields=@(Get-PreferencesChangedFields $row)
        $rows.Add([pscustomobject]@{
            Id='Entry'+$rows.Count; Row=$row; Status=$row.Status
            Changed=($fields.Count -gt 0); Fields=$fields; AliasSkipped=[bool]$row.AliasSkipped
            Guid=[string]$row.Guid
        })
    }
    foreach ($guid in @($Plan.UnavailableLocal)) {
        $rows.Add([pscustomobject]@{Id='Entry'+$rows.Count;Row=$null;Status='Unavailable';Changed=$false;Fields=@();AliasSkipped=$false;Guid=[string]$guid})
    }
    return [pscustomobject]@{
        Rows=$rows.ToArray(); OldLocale=$Plan.OldLocale; Locale=$Plan.Locale
        Matched=@($rows | Where-Object Status -eq 'Matched').Count
        Changed=@($rows | Where-Object Changed).Count
        Skipped=@($rows | Where-Object Status -eq 'Unmatched').Count
        LocalOnly=@($rows | Where-Object Status -eq 'LocalOnly').Count
        Unavailable=@($rows | Where-Object Status -eq 'Unavailable').Count
        AliasSkipped=@($rows | Where-Object AliasSkipped).Count
    }
}

function Get-PreferencesFilteredRows {
    param($View,[string]$Filter)
    switch ($Filter) {
        'Changed' { $View.Rows | Where-Object Changed }
        'Skipped' { $View.Rows | Where-Object { $_.Status -eq 'Unmatched' -or $_.AliasSkipped } }
        'LocalOnly' { $View.Rows | Where-Object Status -eq 'LocalOnly' }
        'Unavailable' { $View.Rows | Where-Object Status -eq 'Unavailable' }
        default { $View.Rows }
    }
}

function Get-PreferencesFieldText {
    param($Row,[ValidateSet('Alias','Visibility','Order')][string]$Field)
    $unmatched=$Row.Status -eq 'Unmatched'
    switch ($Field) {
        'Alias' {
            $before=if ($unmatched) {'—'} else {Format-PreferencesPreviewValue $Row.OldAlias}
            $after=Format-PreferencesPreviewValue $Row.NewAlias
        }
        'Visibility' {
            $before=if ($unmatched) {'—'} else {Get-LocalizedString -Key $(if ($Row.OldHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})}
            $after=Get-LocalizedString -Key $(if ($Row.NewHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})
        }
        'Order' {
            $before=[string]$Row.OldPosition; $after=[string]$Row.NewPosition
        }
    }
    return (Get-LocalizedString -Key ('Preferences.'+$Field+'Change') -Values @{Before=$before;After=$after})
}

function Limit-PreferencesSummaryText {
    param([string]$Text)
    if ($Text.Length -le 120) {return $Text}
    $end=120
    if ([char]::IsHighSurrogate($Text[$end-1])) {$end--}
    return ($Text.Substring(0,$end)+'…')
}

function Get-PreferencesDetailSegments {
    param($Entry)
    $lines=[Collections.Generic.List[string]]::new()
    if ($Entry.Row -and $Entry.Row.Title) { $lines.Add((Format-PreferencesPreviewValue $Entry.Row.Title)) }
    $lines.Add('GUID: '+$Entry.Guid)
    if ($Entry.Row) {
        $lines.Add((Get-PreferencesFieldText $Entry.Row Alias))
        if ($Entry.AliasSkipped) {$lines.Add((Get-LocalizedString -Key 'Preferences.AliasSkipped'))}
        $lines.Add((Get-PreferencesFieldText $Entry.Row Visibility))
        if ($Entry.Status -ne 'Unmatched') {$lines.Add((Get-PreferencesFieldText $Entry.Row Order))}
    } else {$lines.Add((Get-LocalizedString -Key 'Preferences.Unavailable'))}
    # Bounded detail pages keep the native child geometry safe even with
    # legacy very long aliases. No content is discarded or silently clipped.
    foreach ($line in $lines) {
        for ($offset=0;$offset -lt $line.Length;) {
            $length=[Math]::Min(600,$line.Length-$offset)
            if ($offset+$length -lt $line.Length -and [char]::IsHighSurrogate($line[$offset+$length-1])) {$length--}
            $line.Substring($offset,$length)
            $offset+=$length
        }
    }
}

function New-PreferencesTextControl {
    param($Form,[string]$Name,[string]$Text,[string]$Role='Body')
    $label=[Windows.Forms.Label]::new()
    $label.Name=$Name
    $label.Text=$Text
    $label.AccessibleName=$Text
    $label.UseMnemonic=$false
    $label.UseCompatibleTextRendering=$true
    $label.AutoEllipsis=$false
    $label.AutoSize=$false
    $label.BackColor=[Drawing.Color]::Transparent
    $label.Font=switch ($Role) {
        'Count' {$Form.Tag.Fonts.Metric}
        'Heading' {$Form.Tag.Fonts.Heading}
        'Caption' {$Form.Tag.Fonts.Caption}
        default {$Form.Tag.Fonts.Body}
    }
    $label.ForeColor=switch ($Role) {
        'Caption' {[Drawing.Color]::FromArgb(184,184,184)}
        'Positive' {[Drawing.Color]::FromArgb(104,206,141)}
        'Warning' {[Drawing.Color]::FromArgb(233,182,92)}
        'Changed' {[Drawing.Color]::FromArgb(255,224,222)}
        default {$script:ColorPrimary}
    }
    return $label
}

function New-PreferencesViewButton {
    param($Form,[string]$Name,[string]$Text,[string]$Action,$Value,[switch]$Selected)
    $button=[Windows.Forms.Button]::new()
    $button.Name=$Name;$button.Text=$Text;$button.AccessibleName=$Text
    $button.UseMnemonic=$false;$button.UseVisualStyleBackColor=$false
    $button.FlatStyle='Flat';$button.Font=$Form.Tag.Fonts.Body
    $button.ForeColor=$script:ColorPrimary
    $button.BackColor=if ($Selected) {[Drawing.Color]::FromArgb(62,32,30)} else {[Drawing.Color]::FromArgb(37,37,37)}
    $button.FlatAppearance.BorderColor=if ($Selected) {$script:ColorAccent} else {[Drawing.Color]::FromArgb(72,72,72)}
    $button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(55,55,55)
    $button.Cursor=[Windows.Forms.Cursors]::Hand
    $button.Tag=[pscustomobject]@{Action=$Action;Value=$Value}
    $button.Add_Click({
        param($sender,$eventArgs)
        $f=$sender.FindForm()
        if (-not $f -or $f.IsDisposed) {return}
        $state=$f.Tag;$name=$sender.Name;$keep=$false
        switch ($sender.Tag.Action) {
            'Filter' {$state.Filter=[string]$sender.Tag.Value;$state.Page=0;$state.Expanded='';$state.DetailPage=0}
            'Page' {$state.Page=[int]$sender.Tag.Value;$state.Expanded='';$state.DetailPage=0}
            'Expand' {
                $state.Expanded=if ($state.Expanded -ceq $sender.Tag.Value) {''} else {[string]$sender.Tag.Value}
                $state.DetailPage=0;$keep=$true
            }
            'Detail' {$state.DetailPage=[int]$sender.Tag.Value;$keep=$true}
        }
        try {Update-PreferencesConfirmationBody -Form $f -FocusName $name -KeepScroll:$keep}
        catch {$state.LayoutFailed=$true;$f.DialogResult=[Windows.Forms.DialogResult]::Cancel}
    })
    $button.Add_Enter({
        param($sender,$eventArgs)
        $f=$sender.FindForm()
        if ($f -and $f.Visible) {Move-PreferencesFocusedControlIntoView -Form $f -Control $sender}
    })
    return $button
}

function New-PreferencesBlock {
    param([Windows.Forms.Control[]]$Controls,[string]$Kind='Stack',[switch]$Card)
    $panel=[Windows.Forms.Panel]::new()
    $panel.TabStop=$false
    $panel.BackColor=if ($Card) {[Drawing.Color]::FromArgb(37,37,37)} else {[Drawing.Color]::Transparent}
    # A card is a filled summary surface, not a framed box.
    $panel.Tag=[pscustomobject]@{Kind=$Kind;Card=[bool]$Card;Items=$Controls}
    for ($i=0;$i -lt $Controls.Count;$i++) {
        $Controls[$i].TabIndex=$i
        $panel.Controls.Add($Controls[$i])
    }
    return $panel
}

function Add-PreferencesBlock {
    param($Form,[Windows.Forms.Control[]]$Controls,[string]$Kind='Stack',[switch]$Card)
    $block=New-PreferencesBlock -Controls $Controls -Kind $Kind -Card:$Card
    $block.TabIndex=$Form.Tag.Blocks.Count
    $Form.Tag.Blocks.Add($block)
    $Form.Tag.Shell.Body.Controls.Add($block)
    # The shared regular dialog already owns viewport/body scrolling.
    # Add its nested labels/buttons to the same single scroll range.
    function AttachWheel($control) {
        $control.Add_MouseWheel({
            param($sender,$eventArgs)
            $f=$sender.FindForm()
            if (-not $f -or -not $f.Tag.Shell.Scroll -or -not $eventArgs.Delta) {return}
            $scroll=$f.Tag.Shell.Scroll
            if ($scroll.Maximum -le 0) {return}
            if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) {
                if ($eventArgs.Handled) {return}
                $eventArgs.Handled=$true
            }
            $scroll.Value-=[int]([Math]::Sign($eventArgs.Delta)*$scroll.SmallChange)
        })
        foreach ($child in $control.Controls) {AttachWheel $child}
    }
    AttachWheel $block
}

function Move-PreferencesFocusedControlIntoView {
    param($Form,$Control)
    $shell=$Form.Tag.Shell;$scroll=$shell.Scroll
    if (-not $scroll -or $scroll.Maximum -le 0 -or -not $Control.Visible) {return}
    $top=$shell.Body.PointToClient($Control.PointToScreen([Drawing.Point]::Empty)).Y
    if ($top -lt $scroll.Value) {$scroll.Value=$top}
    elseif ($top+$Control.Height -gt $scroll.Value+$shell.Viewport.Height) {
        $scroll.Value=$top+$Control.Height-$shell.Viewport.Height
    }
}

function New-PreferencesIcon {
    param([string]$Name,[string]$Key)
    $icon=[Windows.Forms.Panel]::new()
    $icon.Name=$Name;$icon.Tag=$Key;$icon.TabStop=$false
    $icon.BackColor=[Drawing.Color]::Transparent
    $icon.Add_Paint({
        param($sender,$eventArgs)
        [LenovoSettingsInk]::DrawIcon($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle,[Drawing.Color]::FromArgb(184,184,184))
    })
    return $icon
}

function New-PreferencesSeparator {
    $line=[Windows.Forms.Panel]::new()
    $line.Name='PreferencesSeparator';$line.TabStop=$false
    $line.BackColor=[Drawing.Color]::FromArgb(63,63,63)
    return $line
}

function New-PreferencesSummaryHead {
    param($Form,[string]$Name,[string]$Count,[string]$Caption)
    return (New-PreferencesBlock -Kind SummaryHead -Controls @(
        (New-PreferencesIcon ($Name+'DriveIcon') 'preferences-drive'),
        (New-PreferencesBlock -Controls @(
            (New-PreferencesTextControl $Form $Name $Count Count),
            (New-PreferencesTextControl $Form ($Name+'Label') $Caption Caption)
        )),
        (New-PreferencesIcon ($Name+'JsonIcon') 'preferences-json')
    ))
}

function New-PreferencesIconText {
    param($Form,[string]$Name,[string]$Key,[Windows.Forms.Control[]]$Controls)
    return (New-PreferencesBlock -Kind IconText -Controls @(
        (New-PreferencesIcon ($Name+'Icon') $Key),
        (New-PreferencesBlock -Controls $Controls)
    ))
}

function Add-PreferencesMetrics {
    param($Form,$View)
    $items=@()
    foreach ($key in @('Changed','Skipped','LocalOnly')) {
        $items+=,(New-PreferencesBlock -Controls @(
            (New-PreferencesTextControl $Form ('Metric'+$key) ([string]$View.$key) Heading),
            (New-PreferencesTextControl $Form ('MetricLabel'+$key) (Get-LocalizedString -Key ('Preferences.Metric'+$key)) Caption)
        ))
    }
    Add-PreferencesBlock $Form @(
        (New-PreferencesSummaryHead $Form 'MetricMatched' (Get-LocalizedString -Key 'Preferences.TargetCount' -Values @{Count=$View.Matched}) (Get-LocalizedString -Key 'Preferences.MetricMatched')),
        (New-PreferencesSeparator),
        (New-PreferencesBlock -Controls $items -Kind CompactMetrics)
    ) -Card
}

function New-PreferencesLanguageTile {
    param($Form,[string]$Name,[string]$Locale,[string]$CaptionKey)
    $flag=[Windows.Forms.Panel]::new()
    $flag.Name=$Name+'Flag';$flag.Tag=$Locale;$flag.TabStop=$false
    $flag.BackColor=[Drawing.Color]::Transparent
    $flag.Add_Paint({
        param($sender,$eventArgs)
        [LenovoLocaleFlags]::DrawFlag($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle)
    })
    $nameText=Get-LocalizedString -Key $(if ($Locale -ceq 'de-DE') {'Language.German'} else {'Language.English'})
    return (New-PreferencesBlock -Kind Language -Controls @(
        (New-PreferencesTextControl $Form ($Name+'Caption') (Get-LocalizedString -Key $CaptionKey) Caption),
        $flag,
        (New-PreferencesTextControl $Form ($Name+'Name') $nameText Heading)
    ))
}

function Add-PreferencesEntryCard {
    param($Form,$Entry)
    $s=$Form.Tag
    $title=if ($Entry.Row -and $Entry.Row.Title) {Format-PreferencesPreviewValue $Entry.Row.Title} elseif ($Entry.Status -eq 'Unavailable') {Get-LocalizedString -Key 'Preferences.UnavailableTitle'} else {Get-LocalizedString -Key 'Preferences.UnmatchedTitle'}
    $statusKey=switch ($Entry.Status) {
        'Matched' {if ($Entry.Changed) {'Preferences.RowChanged'} else {'Preferences.RowUnchanged'}}
        'LocalOnly' {'Preferences.LocalOnly'}
        'Unmatched' {'Preferences.Unmatched'}
        default {'Preferences.UnavailableTitle'}
    }
    $role=if ($Entry.Status -in @('Unmatched','Unavailable') -or $Entry.AliasSkipped) {'Warning'} elseif ($Entry.Changed) {'Changed'} elseif ($Entry.Status -eq 'Matched') {'Positive'} else {'Caption'}
    $items=@(
        (New-PreferencesTextControl $Form ($Entry.Id+'Title') (Limit-PreferencesSummaryText $title) Heading),
        (New-PreferencesTextControl $Form ($Entry.Id+'Status') (Get-LocalizedString -Key $statusKey) $role)
    )
    foreach ($field in @($Entry.Fields)) {
        $items+=,(New-PreferencesTextControl $Form ($Entry.Id+$field) (Limit-PreferencesSummaryText (Get-PreferencesFieldText $Entry.Row $field)) Changed)
    }
    if ($Entry.AliasSkipped) {$items+=,(New-PreferencesTextControl $Form ($Entry.Id+'AliasSkipped') (Get-LocalizedString -Key 'Preferences.AliasSkipped') Warning)}
    $expanded=$s.Expanded -ceq $Entry.Id
    $items+=,(New-PreferencesViewButton $Form ($Entry.Id+'Details') (Get-LocalizedString -Key $(if ($expanded) {'Preferences.HideDetails'} else {'Preferences.ShowDetails'})) Expand $Entry.Id -Selected:$expanded)
    if ($expanded) {
        $segments=@(Get-PreferencesDetailSegments $Entry)
        $pages=[Math]::Max(1,[int][Math]::Ceiling($segments.Count/6.0))
        $s.DetailPage=[Math]::Max(0,[Math]::Min($pages-1,$s.DetailPage))
        $items+=,(New-PreferencesTextControl $Form ($Entry.Id+'DetailHeader') (Get-LocalizedString -Key 'Preferences.DetailPage' -Values @{Page=($s.DetailPage+1);Total=$pages}) Caption)
        $i=0
        foreach ($segment in @($segments | Select-Object -Skip ($s.DetailPage*6) -First 6)) {
            $items+=,(New-PreferencesTextControl $Form ($Entry.Id+'Detail'+$i) $segment Body)
            $i++
        }
        if ($pages -gt 1) {
            $previous=New-PreferencesViewButton $Form ($Entry.Id+'DetailPrevious') (Get-LocalizedString -Key 'Preferences.Previous') Detail ($s.DetailPage-1)
            $previous.Enabled=$s.DetailPage -gt 0
            $next=New-PreferencesViewButton $Form ($Entry.Id+'DetailNext') (Get-LocalizedString -Key 'Preferences.Next') Detail ($s.DetailPage+1)
            $next.Enabled=$s.DetailPage -lt $pages-1
            $items+=,(New-PreferencesBlock -Controls @($previous,$next) -Kind Buttons)
        }
    }
    $items+=,(New-PreferencesSeparator)
    Add-PreferencesBlock $Form $items
}

function Update-PreferencesConfirmationBody {
    param($Form,[string]$FocusName,[switch]$KeepScroll)
    $s=$Form.Tag;$body=$s.Shell.Body
    $oldValue=if ($KeepScroll) {$s.Shell.Scroll.Value} else {0}
    $body.SuspendLayout()
    try {
        foreach ($control in @($body.Controls)) {$body.Controls.Remove($control);$control.Dispose()}
        $s.Blocks.Clear()
        if ($s.Mode -eq 'Export') {
            $included=@()
            $icons=@{Language='preferences-language';Aliases='preferences-alias';Visibility='preferences-visible';Order='preferences-order'}
            foreach ($key in @('Language','Aliases','Visibility','Order')) {
                $included+=,(New-PreferencesIconText $Form ('Included'+$key) $icons[$key] @(
                    (New-PreferencesTextControl $Form ('Included'+$key) (Get-LocalizedString -Key ('Preferences.Included'+$key)) Body)
                ))
            }
            Add-PreferencesBlock $Form @(
                (New-PreferencesSummaryHead $Form 'ExportCount' (Get-LocalizedString -Key 'Preferences.TargetCount' -Values @{Count=$s.ExportCount}) (Get-LocalizedString -Key 'Preferences.ExportIntro')),
                (New-PreferencesSeparator),
                (New-PreferencesBlock -Controls $included -Kind TwoColumns)
            ) -Card
        } else {
            Add-PreferencesMetrics $Form $s.View
            $languageTiles=New-PreferencesBlock -Kind TwoColumns -Controls @(
                (New-PreferencesLanguageTile $Form 'LanguageBefore' $s.View.OldLocale 'Preferences.LanguageBefore'),
                (New-PreferencesLanguageTile $Form 'LanguageAfter' $s.View.Locale 'Preferences.LanguageAfter')
            )
            Add-PreferencesBlock $Form @(
                (New-PreferencesTextControl $Form 'LanguageHeading' (Get-LocalizedString -Key 'Preferences.IncludedLanguage') Heading),
                $languageTiles,
                (New-PreferencesTextControl $Form 'LanguageStatus' (Get-LocalizedString -Key $(if ($s.View.OldLocale -ceq $s.View.Locale) {'Preferences.NoChange'} else {'Preferences.LanguageChanged'})) $(if ($s.View.OldLocale -cne $s.View.Locale) {'Changed'} else {'Caption'})),
                (New-PreferencesSeparator)
            )
            $entryIntro=@((New-PreferencesTextControl $Form 'EntryHeading' (Get-LocalizedString -Key 'Preferences.EntriesHeading') Heading))
            if ($s.View.Unavailable -gt 0) {
                $entryIntro+=,(New-PreferencesTextControl $Form 'UnavailableCount' (Get-LocalizedString -Key 'Preferences.UnavailableCount' -Values @{Count=$s.View.Unavailable}) Caption)
            }
            if ($s.View.AliasSkipped -gt 0) {
                $entryIntro+=,(New-PreferencesTextControl $Form 'AliasSkippedCount' (Get-LocalizedString -Key 'Preferences.AliasSkippedCount' -Values @{Count=$s.View.AliasSkipped}) Warning)
            }
            Add-PreferencesBlock $Form $entryIntro
            $filters=@()
            foreach ($key in @('All','Changed','Skipped','LocalOnly','Unavailable')) {
                $filters+=,(New-PreferencesViewButton $Form ('Filter'+$key) (Get-LocalizedString -Key ('Preferences.Filter'+$key)) Filter $key -Selected:($s.Filter -ceq $key))
            }
            Add-PreferencesBlock $Form $filters Buttons
        }
        if ($s.Mode -eq 'Import' -or $s.View.Unavailable -gt 0) {
            $rows=@(Get-PreferencesFilteredRows $s.View $s.Filter)
            $s.PageCount=[Math]::Max(1,[int][Math]::Ceiling($rows.Count/8.0))
            $s.Page=[Math]::Max(0,[Math]::Min($s.PageCount-1,$s.Page))
            $s.VisibleRows=@($rows | Select-Object -Skip ($s.Page*8) -First 8)
            if ($s.Mode -eq 'Export') {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'ExportUnavailable' (Get-LocalizedString -Key 'Preferences.Unavailable') Caption))
            }
            if ($rows.Count -gt 0) {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'PageInfo' (Get-LocalizedString -Key 'Preferences.PageInfo' -Values @{Page=($s.Page+1);Total=$s.PageCount;Count=$rows.Count}) Caption))
                if ($s.PageCount -gt 1) {
                    $previous=New-PreferencesViewButton $Form 'PagePrevious' (Get-LocalizedString -Key 'Preferences.Previous') Page ($s.Page-1)
                    $previous.Enabled=$s.Page -gt 0
                    $next=New-PreferencesViewButton $Form 'PageNext' (Get-LocalizedString -Key 'Preferences.Next') Page ($s.Page+1)
                    $next.Enabled=$s.Page -lt $s.PageCount-1
                    Add-PreferencesBlock $Form @($previous,$next) Buttons
                }
                foreach ($entry in $s.VisibleRows) {Add-PreferencesEntryCard $Form $entry}
            } else {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'NoRows' (Get-LocalizedString -Key 'Preferences.NoRows') Caption))
            }
        }
        if ($s.Mode -eq 'Import') {
            Add-PreferencesBlock $Form @(
                (New-PreferencesIconText $Form 'Reconcile' 'preferences-shield' @(
                    (New-PreferencesTextControl $Form 'ReconcileHeading' (Get-LocalizedString -Key 'Preferences.ReconcileHeading') Heading),
                    (New-PreferencesTextControl $Form 'ReconcileWarning' (Get-LocalizedString -Key 'Preferences.ReconcileWarning') Body),
                    (New-PreferencesTextControl $Form 'IncludedScope' (Get-LocalizedString -Key 'Preferences.IncludedScope') Caption)
                )),
                (New-PreferencesSeparator)
            )
        }
        $excludedHeading=if ($s.Mode -eq 'Import') {'Preferences.UnchangedHeading'} else {'Preferences.ExcludedHeading'}
        $excluded=@(
            (New-PreferencesTextControl $Form 'ExcludedHeading' (Get-LocalizedString -Key $excludedHeading) Heading),
            (New-PreferencesTextControl $Form 'ExcludedScope' (Get-LocalizedString -Key 'Preferences.ExcludedScope') Body)
        )
        if ($s.Mode -eq 'Import') {
            $excluded+=,(New-PreferencesTextControl $Form 'SystemUnchanged' (Get-LocalizedString -Key 'Preferences.SystemUnchanged') Caption)
        }
        Add-PreferencesBlock $Form @(
            (New-PreferencesIconText $Form 'Excluded' 'preferences-shield' $excluded),
            (New-PreferencesSeparator)
        )
        Add-PreferencesBlock $Form @(
            (New-PreferencesIconText $Form 'Privacy' 'preferences-lock' @(
                (New-PreferencesTextControl $Form 'PrivacyHeading' (Get-LocalizedString -Key 'Preferences.PrivacyHeading') Heading),
                (New-PreferencesTextControl $Form 'PrivacyBody' (Get-LocalizedString -Key 'Preferences.PrivacyBody') Caption),
                (New-PreferencesTextControl $Form 'UnavailableNote' (Get-LocalizedString -Key 'Preferences.UnavailableNote') Caption)
            ))
        )
    } finally {$body.ResumeLayout($false)}
    if ($s.Scale -gt 0) {
        Set-PreferencesConfirmationLayout -Form $Form -Scale $s.Scale -WorkingArea $s.WorkingArea
        $s.Shell.Scroll.Value=$oldValue
        if ($FocusName) {
            $target=$Form.Controls.Find($FocusName,$true) | Select-Object -First 1
            if ($target -and $target.CanFocus -and $target.Enabled) {[void]$target.Focus()}
            elseif ($s.Cancel.CanFocus) {[void]$s.Cancel.Focus()}
        }
    }
}

function New-PreferencesConfirmationForm {
    param([string]$Title,[string]$ConfirmText,$Plan,$ExportContext)
    if (($null -ne $Plan) -eq ($null -ne $ExportContext)) {throw 'InvalidPreviewLayout'}
    $form=[Windows.Forms.Form]::new()
    $form.Name='LenovoPreferencesConfirmation';$form.Text=$Title;$form.AccessibleName=$Title
    $form.FormBorderStyle='None';$form.AutoScaleMode='None';$form.ShowInTaskbar=$false;$form.TopMost=$true
    $form.StartPosition='Manual';$form.KeyPreview=$true;$form.BackColor=$script:ColorBackground
    $root=[Windows.Forms.Panel]::new();$root.Name='PreferencesRoot';$form.Controls.Add($root)
    $fonts=@{Title=[Drawing.Font]::new('Segoe UI',11,[Drawing.FontStyle]::Bold);Heading=[Drawing.Font]::new('Segoe UI',10,[Drawing.FontStyle]::Bold);Body=[Drawing.Font]::new('Segoe UI',9.5);Caption=[Drawing.Font]::new('Segoe UI',9);Metric=[Drawing.Font]::new('Segoe UI',19,[Drawing.FontStyle]::Bold)}
    $heading=[Windows.Forms.Label]::new();$heading.Text=$Title;$heading.Font=$fonts.Title;$heading.ForeColor=$script:ColorPrimary
    $divider=[Windows.Forms.Panel]::new();$divider.BackColor=$script:ColorAccent
    $cancel=[Windows.Forms.Button]::new();$cancel.Name='PreferencesCancel';$cancel.Text=Get-LocalizedString -Key 'Common.Cancel';$cancel.DialogResult='Cancel'
    $confirm=[Windows.Forms.Button]::new();$confirm.Name='PreferencesConfirm';$confirm.Text=$ConfirmText;$confirm.DialogResult='OK'
    foreach ($button in @($cancel,$confirm)) {
        $button.AccessibleName=$button.Text;$button.Font=$fonts.Body;$button.FlatStyle='Flat'
        $button.UseVisualStyleBackColor=$false;$button.UseMnemonic=$false;$button.Cursor=[Windows.Forms.Cursors]::Hand
        $button.ForeColor=$script:ColorPrimary
        $button.BackColor=if ($button -eq $confirm) {$script:ColorAccent} else {$script:ColorSurface}
        $button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(72,72,72)
        $button.FlatAppearance.MouseOverBackColor=if ($button -eq $confirm) {[Drawing.Color]::FromArgb(242,59,49)} else {[Drawing.Color]::FromArgb(45,45,45)}
    }
    $cancel.TabIndex=0;$confirm.TabIndex=1
    $form.AcceptButton=$cancel;$form.CancelButton=$cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $heading -Divider $divider -Content @() -Buttons @($cancel,$confirm)
    $icon=[Windows.Forms.Panel]::new();$icon.Name='PreferencesHeaderIcon';$icon.TabStop=$false
    $icon.Tag=if ($Plan) {'preferences-import'} else {'preferences-export'}
    $icon.BackColor=$root.Tag.Header.BackColor
    $icon.Add_Paint({
        param($sender,$eventArgs)
        [LenovoSettingsInk]::DrawIcon($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle,[Drawing.Color]::FromArgb(225,37,27))
    })
    $root.Tag.Header.Controls.Add($icon)
    $root.Tag.Footer.TabIndex=0;$root.Tag.Viewport.TabIndex=1;$root.Tag.Header.TabStop=$false
    $root.Tag.Body.TabIndex=0
    $mode=if ($Plan) {'Import'} else {'Export'}
    $view=if ($Plan) {New-PreferencesPreviewView $Plan} else {
        $unavailable=@(@($ExportContext.Settings.entryOrder)+@($ExportContext.Settings.hiddenEntryGuids)+@($ExportContext.Settings.entryAliases.Keys) | Where-Object { $_ -and $_ -notin $ExportContext.Entries.Guid } | Sort-Object -Unique)
        New-PreferencesPreviewView ([pscustomobject]@{Rows=@();UnavailableLocal=$unavailable})
    }
    $form.Tag=[pscustomobject]@{
        Mode=$mode;View=$view;ExportCount=@($ExportContext.Entries).Count
        Shell=$root.Tag;Root=$root;Cancel=$cancel;Confirm=$confirm;Fonts=$fonts;HeaderIcon=$icon;LayoutFailed=$false
        Blocks=[Collections.Generic.List[object]]::new();Filter='All';Page=0;PageCount=1;Expanded='';DetailPage=0;VisibleRows=@()
        Scale=0.0;WorkingArea=[Drawing.Rectangle]::Empty
    }
    $form.Add_Shown({if ($this.Tag.Cancel.CanFocus) {[void]$this.Tag.Cancel.Focus()}})
    $form.Add_Disposed({foreach ($font in $this.Tag.Fonts.Values) {$font.Dispose()}})
    if (-not $root.Tag.Scroll) {$form.Dispose();throw 'InvalidPreviewLayout'}
    try {Update-PreferencesConfirmationBody $form;return $form}
    catch {$form.Dispose();throw}
}

function Set-PreferencesBlockLayout {
    param($Block,[int]$Width,$Graphics,[double]$Scale)
    function Px([double]$n) {return [Math]::Max(1,[int][Math]::Round($n*$Scale))}
    $pad=if ($Block.Tag.Card) {Px 10} else {0}
    $gap=Px 5
    $available=[Math]::Max(1,$Width-2*$pad)
    $y=$pad;$x=$pad;$lineHeight=0
    if ($Block.Tag.Kind -in @('Metrics','TwoColumns','CompactMetrics')) {
        $columns=switch ($Block.Tag.Kind) {
            'TwoColumns' {if ($available -ge (Px 250)) {2} else {1}}
            'CompactMetrics' {if ($available -ge (Px 300)) {3} elseif ($available -ge (Px 200)) {2} else {1}}
            default {if ($available -ge (Px 620)) {4} elseif ($available -ge (Px 250)) {2} else {1}}
        }
        $columns=[Math]::Max(1,[Math]::Min($columns,$Block.Tag.Items.Count))
        $cell=[int][Math]::Floor(($available-($columns-1)*$gap)/$columns)
        $index=0
        foreach ($item in $Block.Tag.Items) {
            $col=$index%$columns
            if ($col -eq 0 -and $index -gt 0) {$y+=$lineHeight+$gap;$lineHeight=0}
            $h=Set-PreferencesBlockLayout $item $cell $Graphics $Scale
            $item.Bounds=[Drawing.Rectangle]::new(($pad+$col*($cell+$gap)),$y,$cell,$h)
            $lineHeight=[Math]::Max($lineHeight,$h);$index++
        }
        $y+=$lineHeight
    } elseif ($Block.Tag.Kind -in @('SummaryHead','IconText')) {
        $icon=$Block.Tag.Items[0];$content=$Block.Tag.Items[1]
        $summary=$Block.Tag.Kind -eq 'SummaryHead'
        $side=[Math]::Min((Px $(if ($summary) {38} else {20})),[Math]::Max(1,[int]($available/5)))
        $right=if ($summary) {$side+$gap} else {0}
        $cw=[Math]::Max(1,$available-$side-$gap-$right)
        $ch=Set-PreferencesBlockLayout $content $cw $Graphics $Scale
        $h=[Math]::Max($side,$ch)
        $icon.Bounds=[Drawing.Rectangle]::new($pad,($y+[int](($h-$side)/2)),$side,$side)
        $content.Bounds=[Drawing.Rectangle]::new(($pad+$side+$gap),$y,$cw,$ch)
        if ($summary) {
            $Block.Tag.Items[2].Bounds=[Drawing.Rectangle]::new(($pad+$available-$side),($y+[int](($h-$side)/2)),$side,$side)
        }
        $y+=$h
    } elseif ($Block.Tag.Kind -eq 'Language') {
        $caption=$Block.Tag.Items[0];$flag=$Block.Tag.Items[1];$name=$Block.Tag.Items[2]
        $h=[Math]::Max((Px 16),[int][Math]::Ceiling($Graphics.MeasureString($caption.Text,$caption.Font,$available).Height)+(Px 4))
        $caption.Bounds=[Drawing.Rectangle]::new($pad,$y,$available,$h)
        $y+=$h+$gap
        $fw=[Math]::Min((Px 28),[Math]::Max(1,$available-(Px 30)))
        $fh=[Math]::Max(1,[int][Math]::Round($fw*0.75))
        $nw=[Math]::Max(1,$available-$fw-$gap)
        $nh=[Math]::Max($fh,[int][Math]::Ceiling($Graphics.MeasureString($name.Text,$name.Font,$nw).Height)+(Px 4))
        $flag.Bounds=[Drawing.Rectangle]::new($pad,($y+[int](($nh-$fh)/2)),$fw,$fh)
        $name.Bounds=[Drawing.Rectangle]::new(($pad+$fw+$gap),$y,$nw,$nh)
        $y+=$nh
    } elseif ($Block.Tag.Kind -eq 'Buttons') {
        foreach ($item in $Block.Tag.Items) {
            $desired=[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font).Width)+(Px 22)
            $w=[Math]::Min($available,[Math]::Max((Px 70),$desired))
            $h=[Math]::Max((Px 30),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w-(Px 10))).Height)+(Px 8))
            if ($x -gt $pad -and $x+$w -gt $pad+$available) {$y+=$lineHeight+$gap;$x=$pad;$lineHeight=0}
            $item.Bounds=[Drawing.Rectangle]::new($x,$y,$w,$h)
            $x+=$w+$gap;$lineHeight=[Math]::Max($lineHeight,$h)
        }
        $y+=$lineHeight
    } else {
        foreach ($item in $Block.Tag.Items) {
            $w=$available
            if ($item.Name -ceq 'PreferencesSeparator') {
                $h=Px 1
            } elseif ($item -is [Windows.Forms.Panel]) {
                $h=Set-PreferencesBlockLayout $item $w $Graphics $Scale
            } elseif ($item -is [Windows.Forms.Button]) {
                $w=[Math]::Min($available,[Math]::Max((Px 100),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font).Width)+(Px 22)))
                $h=[Math]::Max((Px 30),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w-(Px 10))).Height)+(Px 8))
            } else {
                $h=[Math]::Max((Px 16),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w)).Height)+(Px 4))
            }
            $item.Bounds=[Drawing.Rectangle]::new($pad,$y,$w,$h)
            $y+=$h+$gap
        }
        $y-=$gap
    }
    return [int][Math]::Max(1,$y+$pad)
}

function Set-PreferencesConfirmationLayout {
    param([Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea)
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) {throw 'InvalidPreviewLayout'}
    function Px([double]$n) {return [Math]::Max(1,[int][Math]::Round($n*$Scale))}
    $s=$Form.Tag;$shell=$s.Shell
    $s.Scale=$Scale;$s.WorkingArea=$WorkingArea
    $track=[Windows.Forms.SystemInformation]::MaxWindowTrackSize
    $width=[Math]::Min((Px $(if ($s.Mode -eq 'Export') {500} else {780})),[Math]::Min($WorkingArea.Width,$track.Width))
    $maxHeight=[Math]::Min($WorkingArea.Height,$track.Height)
    if ($s.Mode -eq 'Import') {$maxHeight=[Math]::Min($maxHeight,(Px 650))}
    $pad=Px 18;$gap=Px 10
    $bitmap=[Drawing.Bitmap]::new(8,8)
    try {
        $bitmap.SetResolution([single](96*$Scale),[single](96*$Scale))
        $g=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $titleWidth=$width-2*$pad
            if ($titleWidth -lt (Px 80)) {throw 'InvalidPreviewLayout'}
            $shell.Title.UseCompatibleTextRendering=$true;$shell.Title.AutoSize=$false;$shell.Title.AutoEllipsis=$false
            $iconSize=Px 23
            $headingWidth=$titleWidth-$iconSize-$gap
            if ($headingWidth -lt (Px 40)) {throw 'InvalidPreviewLayout'}
            $headerHeight=[Math]::Max((Px 49),[int][Math]::Ceiling($g.MeasureString($shell.Title.Text,$shell.Title.Font,$headingWidth).Height)+(Px 20))
            $buttonWidths=@();$buttonHeight=Px 36
            foreach ($button in @($s.Cancel,$s.Confirm)) {
                $bw=[Math]::Min($titleWidth,[Math]::Max((Px 108),[int][Math]::Ceiling($g.MeasureString($button.Text,$button.Font).Width)+(Px 24)))
                $buttonWidths+=$bw
                $buttonHeight=[Math]::Max($buttonHeight,[int][Math]::Ceiling($g.MeasureString($button.Text,$button.Font,[Math]::Max(1,$bw-(Px 12))).Height)+(Px 10))
            }
            $total=$buttonWidths[0]+$buttonWidths[1]+$gap
            $stacked=$total -gt $titleWidth
            $footerHeight=if ($stacked) {2*$buttonHeight+3*$gap} else {$buttonHeight+2*$gap}
            $available=$maxHeight-$headerHeight-$footerHeight
            if ($available -lt (Px 50)) {throw 'InvalidPreviewLayout'}
            $gutter=0;$height=0
            for ($pass=0;$pass -lt 2;$pass++) {
                $bodyWidth=$width-$gutter
                $blockWidth=$bodyWidth-2*$pad
                if ($blockWidth -lt (Px 70)) {throw 'InvalidPreviewLayout'}
                $y=$pad
                foreach ($block in $s.Blocks) {
                    $h=Set-PreferencesBlockLayout $block $blockWidth $g $Scale
                    $block.Bounds=[Drawing.Rectangle]::new($pad,$y,$blockWidth,$h)
                    $y+=$h+$gap
                }
                $height=$y-$gap+$pad
                if ($height -le $available -or $pass -eq 1) {break}
                $gutter=Px 12
            }
            $viewportHeight=if ($s.Mode -eq 'Import') {$available} else {[Math]::Min($available,$height)}
            $Form.ClientSize=[Drawing.Size]::new($width,($headerHeight+$viewportHeight+$footerHeight))
            $shell.Header.Bounds=[Drawing.Rectangle]::new(0,0,$width,$headerHeight)
            $s.HeaderIcon.Bounds=[Drawing.Rectangle]::new($pad,[int](($headerHeight-$iconSize)/2),$iconSize,$iconSize)
            $shell.Title.Bounds=[Drawing.Rectangle]::new(($pad+$iconSize+$gap),(Px 8),$headingWidth,($headerHeight-(Px 18)))
            $shell.Divider.Bounds=[Drawing.Rectangle]::new(0,($headerHeight-(Px 2)),$width,(Px 2))
            $shell.Viewport.Bounds=[Drawing.Rectangle]::new(0,$headerHeight,$width,$viewportHeight)
            $shell.Body.Bounds=[Drawing.Rectangle]::new(0,0,$bodyWidth,$height)
            $shell.Footer.Bounds=[Drawing.Rectangle]::new(0,($headerHeight+$viewportHeight),$width,$footerHeight)
            $scroll=$shell.Scroll
            $scroll.Bounds=[Drawing.Rectangle]::new(($width-(Px 10)),0,(Px 10),$viewportHeight)
            $scroll.Value=0;$scroll.Maximum=[Math]::Max(0,$height-$viewportHeight)
            $scroll.LargeChange=$viewportHeight;$scroll.SmallChange=Px 60
            $scroll.Visible=$scroll.Maximum -gt 0;$scroll.BringToFront()
            $x=if ($stacked) {$pad} else {$width-$pad-$total}
            $y=$gap
            for ($i=0;$i -lt 2;$i++) {
                $button=@($s.Cancel,$s.Confirm)[$i]
                $bw=if ($stacked) {$titleWidth} else {$buttonWidths[$i]}
                $button.Bounds=[Drawing.Rectangle]::new($x,$y,$bw,$buttonHeight)
                if ($stacked) {$y+=$buttonHeight+$gap} else {$x+=$bw+$gap}
            }
        } finally {$g.Dispose()}
    } finally {$bitmap.Dispose()}
    $Form.Location=Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
}

function Show-PreferencesConfirmation {
    param([string]$Title,[string]$ConfirmText,$Plan,$ExportContext)
    $form=New-PreferencesConfirmationForm -Title $Title -ConfirmText $ConfirmText -Plan $Plan -ExportContext $ExportContext
    try {
        $owner=Get-LenovoDialogOwner
        $screen=if ($owner) {[Windows.Forms.Screen]::FromControl($owner)} else {[Windows.Forms.Screen]::PrimaryScreen}
        $scale=Get-LenovoUiCoordinateScale -Screen $screen
        Set-PreferencesConfirmationLayout -Form $form -Scale ([double]$scale.Factor) -WorkingArea $screen.WorkingArea
        Register-LenovoDialogVisibilityCorrection -Form $form -Screen $screen
        $result=Show-LenovoOwnedDialog -Form $form -Owner $owner
        if ($form.Tag.LayoutFailed) {throw 'InvalidPreviewLayout'}
        return ($result -eq [Windows.Forms.DialogResult]::OK)
    } finally {$form.Dispose()}
}

function New-PreferencesFileDialog {
    param([ValidateSet('Export','Import')][string]$Mode)
    if ($Mode -eq 'Export') {
        $dialog=New-Object Windows.Forms.SaveFileDialog
        $dialog.Title=Get-LocalizedString -Key 'Preferences.ChooseExport'
        $dialog.FileName='LenovoBootSelector-Preferences.json'
        $dialog.OverwritePrompt=$true
        $dialog.CreatePrompt=$false
    } else {
        $dialog=New-Object Windows.Forms.OpenFileDialog
        $dialog.Title=Get-LocalizedString -Key 'Preferences.ChooseImport'
        $dialog.CheckFileExists=$true
        $dialog.Multiselect=$false
    }
    $dialog.Filter=Get-LocalizedString -Key 'Preferences.FileFilter'
    $dialog.DefaultExt='json'
    $dialog.AddExtension=$true
    $dialog.CheckPathExists=$true
    $dialog.ValidateNames=$true
    $dialog.RestoreDirectory=$true
    return $dialog
}

function Select-PreferencesFile {
    param([ValidateSet('Export','Import')][string]$Mode)
    $dialog=New-PreferencesFileDialog $Mode
    try {
        $owner=Get-LenovoDialogOwner
        $result=if ($owner) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
        return $null
    } finally { $dialog.Dispose() }
}

function Show-PortablePreferencesFromUi {
    param([ValidateSet('Export','Import')][string]$Mode)
    if ($script:PreferencesUiActive) { return }
    $script:PreferencesUiActive=$true
    $stage='read'
    try {
        if ($Mode -eq 'Export') {
            $context=Get-PortablePreferencesContext
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.Export') -ExportContext $context -ConfirmText (Get-LocalizedString -Key 'Preferences.ExportConfirm'))) { return }
            $path=Select-PreferencesFile -Mode Export
            if (-not $path) { return }
            $stage='write'
            Save-PortablePreferencesExport -Path $path -Context $context
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Export') -Heading (Get-LocalizedString -Key 'Preferences.Exported') -Message (Get-LocalizedString -Key 'Preferences.ExportSuccess') -Kind Success
        } else {
            if (-not (Test-PortablePreferencesAvailable)) { throw 'PreferencesUnavailable' }
            $path=Select-PreferencesFile -Mode Import
            if (-not $path) { return }
            $import=New-PortablePreferencesImport -Path $path
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.PreviewTitle') -Plan $import.Plan -ConfirmText (Get-LocalizedString -Key 'Preferences.Apply'))) { return }
            $stage='write'
            $before=$script:UiLocale
            [void](Complete-PortablePreferencesImport $import)
            $stage='committed'
            try {
                Update-TrayLocalizedText
                if ($before -cne $script:UiLocale) {
                    Update-CachedBootEntryLocalization
                    Update-PopupLocalePresentation
                } elseif ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows -Reason 'preferences-import' }
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Import') -Heading (Get-LocalizedString -Key 'Preferences.Imported') -Message (Get-LocalizedString -Key 'Preferences.ImportSuccess') -Kind Success
            } catch {
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Import') -Heading (Get-LocalizedString -Key 'Preferences.Imported') -Message (Get-LocalizedString -Key 'Preferences.RefreshWarning') -Kind Warning
            }
        }
    } catch {
        $key=switch -CaseSensitive ($_.Exception.Message) {
            'StalePreview' {'Preferences.ErrorStale'}
            'PreferencesUnavailable' {'Preferences.ErrorBusy'}
            'InvalidLocalSettings' {'Preferences.ErrorLocal'}
            'UnsupportedLocalSettings' {'Preferences.ErrorLocal'}
            'LocalSettingsChanged' {'Preferences.ErrorLocal'}
            'LocaleMigrationPending' {'Preferences.ErrorLocal'}
            'InvalidDestination' {'Preferences.ErrorDestination'}
            'CommitUncertain' { if ($Mode -eq 'Export') {'Preferences.ExportUncertain'} else {'Preferences.ErrorUncertain'} }
            'InvalidPreviewLayout' {'Preferences.ErrorLayout'}
            default { if ($stage -eq 'committed') {'Preferences.RefreshWarning'} elseif ($stage -eq 'write') {'Preferences.ErrorSave'} else {'Preferences.ErrorInvalid'} }
        }
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.ErrorTitle') -Heading (Get-LocalizedString -Key 'Preferences.ErrorTitle') -Message (Get-LocalizedString -Key $key) -Kind Error
    } finally {
        $script:PreferencesUiActive=$false
        Update-PortablePreferencesMenuState
    }
}


function Test-MaintenanceBusy {
    return (Test-MaintenanceRuntimeBusy -State $script:MaintenanceState)
}

function Get-MaintenanceMode {
    return (Get-MaintenanceRuntimeMode -State $script:MaintenanceState)
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
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if (-not $capabilities.CanConfigureSystemFunctions) { return }
        if ([string]$capabilities.State -eq 'ReinitializeRequired') {
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $state = [string]$capabilities.State
    $busy = ($state -eq 'Busy')
    $ready = [bool]$capabilities.IsReady
    $checking = [bool]$capabilities.IsChecking

    $panelMatches = $script:Popup.Controls.Find('MaintenanceStatePanel', $true)
    $panel = if ($panelMatches.Count -gt 0) { $panelMatches[0] } else { $null }
    if ($panel) {
        $heading = $panel.Controls['MaintenanceHeading']
        $message = $panel.Controls['MaintenanceMessage']
        $action = $panel.Controls['MaintenancePrimaryButton']
        $hint = $panel.Controls['MaintenanceHint']
        $glyph = $panel.Controls['MaintenanceGlyph']

        if ($ready -or $checking) {
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
                $action.Enabled = [bool]$capabilities.CanConfigureSystemFunctions
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHint'
            }
            elseif ($state -eq 'RepairRequired' -or $state -eq 'Unknown') {
                $glyph.Text = '!'
                $glyph.ForeColor = $script:ColorWarning
                $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairMessage'
                $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $action.Visible = $true
                $action.Enabled = [bool]$capabilities.CanConfigureSystemFunctions
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
                $action.Enabled = [bool]$capabilities.CanConfigureSystemFunctions
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
        $script:RefreshButton.Enabled = [bool]$capabilities.CanRefresh
        $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    }
    if ($script:ManageEntriesButton -and -not $script:ManageEntriesButton.IsDisposed) {
        $script:ManageEntriesButton.Enabled = [bool]$capabilities.CanManageEntries
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = [bool]$capabilities.CanUseDefaultTarget }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = [bool]$capabilities.CanRestart }

    Update-HeaderRefreshStatus
}

function Show-MaintenanceSuccessDialog {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    if ($Mode -eq 'Remove') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessRemovedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessRemovedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessRemovedMessage') -Kind Success
        return
    }
    if ($Mode -eq 'Reinitialize') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedMessage') -Kind Success
        return
    }
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReadyTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReadyHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReadyMessage') -Kind Success
}


function Refresh-EffectiveNextBootState {
    try {
        $managerText = Get-TaskBrokerFirmwareManagerText -Force
        $manager = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
        $script:SelectedGuid = if ($manager.SelectedGuid) { ([string]$manager.SelectedGuid).ToLowerInvariant() } else { $null }
        $script:NextBootFirmwareReadVerified = $true
        $script:SystemStatusNextObservedUtc = $script:SystemStatusManagerObservedUtc
        Update-RestartTargetUi
        return $script:SelectedGuid
    }
    catch {
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusNextObservedUtc = $null
        $script:SelectedGuid = $null
        Update-RestartTargetUi
        throw
    }
}

function Get-NextBootTargetDisplayName {
    if (-not $script:NextBootFirmwareReadVerified) { return (Get-LocalizedString -Key 'BootNext.Unknown') }
    if ($script:SelectedGuid) {
        $selectedEntry = Get-EntryByGuid $script:SelectedGuid
        if ($selectedEntry) { return [string](Get-EntryDisplayTitle -Entry $selectedEntry) }
        return (Get-LocalizedString -Key 'Settings.DefaultTargetUnavailable')
    }
    return (Get-LocalizedString -Key 'Boot.DefaultOrder')
}

function Use-DefaultForNextRestart {
    # LBS-206 Hotfix: use the very same guarded async selection controller
    # as a manual row activation. Do not call the synchronous firmware writer
    # here: the controller paints pending immediately, interlocks Restart,
    # and only confirms the new target after independent firmware readback.
    if ($script:BootNextPendingGuid -or $script:DefaultTargetChangePending -or $script:IsManageEntriesMode) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if (-not $capabilities.CanSetBootNext -or -not $script:DefaultGuid -or
        -not $script:NextBootFirmwareReadVerified -or -not $script:SelectedGuid -or
        $script:SelectedGuid -eq $script:DefaultGuid) { return }
    # Neither stale/unavailable target nor default may cross the task allowlist.
    if (-not (Get-EntryByGuid ([string]$script:DefaultGuid)) -or
        -not (Get-EntryByGuid ([string]$script:SelectedGuid))) { return }
    Invoke-NormalBootTargetSelection -Guid ([string]$script:DefaultGuid)
}

function Update-RestartTargetUi {
    # The persistent default is saved off-thread; no prior firmware value
    # may be presented as newly confirmed until both readbacks complete.
    if (-not $script:RestartTargetLabel -or $script:RestartTargetLabel.IsDisposed) { return }
    if ($script:DefaultTargetChangePending) {
        $entry = if ($script:DefaultTargetChangeRequestedGuid) { Get-EntryByGuid ([string]$script:DefaultTargetChangeRequestedGuid) } else { $null }
        $target = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
        $key = if ($script:DefaultTargetChangeStage -eq 'verifying') { 'Default.ChangeVerifyingFooter' } else { 'Default.ChangeSavingFooter' }
        $label = Get-LocalizedString -Key $key -Values @{ Target = $target }
        $script:RestartTargetLabel.Text = $label
        $script:RestartTargetLabel.ForeColor = $script:ColorWarning
        $script:RestartTargetLabel.TabStop = $false
        $script:RestartTargetLabel.AccessibleName = $label
        $script:RestartTargetLabel.AccessibleDescription = $label
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:RestartTargetLabel,$label) }
        if ($script:RestartUseDefaultButton -and -not $script:RestartUseDefaultButton.IsDisposed) {
            $script:RestartUseDefaultButton.Visible = $false
            $script:RestartUseDefaultButton.Enabled = $false
            $script:RestartUseDefaultButton.TabStop = $false
        }
        Update-BootNextRestartInterlock
        return
    }
    $hasTarget = (-not $script:SelectedGuid -or $null -ne (Get-EntryByGuid $script:SelectedGuid))
    $model = Resolve-BootNextDisplayStateCore -DefaultGuid $script:DefaultGuid -EffectiveNextGuid $script:SelectedGuid -FirmwareReadSucceeded ([bool]$script:NextBootFirmwareReadVerified) -Checking $false -EffectiveTargetKnown $hasTarget
    $next = Get-NextBootTargetDisplayName
    $default = Get-DefaultEntryTitle
    switch ($model) {
        'unknown'        { $labelKey = 'BootNext.LayoutUnknown' }
        'firmware-order' { $labelKey = 'BootNext.LayoutFirmwareOrder' }
        'aligned'        { $labelKey = 'BootNext.LayoutAligned' }
        'different'      { $labelKey = 'BootNext.LayoutDifferent' }
        'unavailable'    { $labelKey = 'BootNext.LayoutUnavailable' }
        default          { $labelKey = 'BootNext.LayoutUnknown' }
    }
    $label = Get-LocalizedString -Key $labelKey -Values @{ Next=$next; Default=$default }
    $script:RestartTargetLabel.Text = $label
    $script:RestartTargetLabel.AccessibleName = $label
    $script:RestartTargetLabel.AccessibleDescription = $label
    $script:RestartTargetLabel.TabStop = $false
    $script:RestartTargetLabel.Cursor = [Windows.Forms.Cursors]::Default
    $script:RestartTargetLabel.ForeColor = if ($model -in @('unknown','unavailable')) {
        $script:ColorWarning
    } elseif ($model -in @('aligned','different')) {
        $script:ColorPrimary
    } else { $script:ColorSecondary }
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:RestartTargetLabel,$label) }

    # This gate is presentation-only; actual activation retains the existing
    # ProbeReadiness, fixed task, firmware re-read and verification in
    # Use-DefaultForNextRestart. No settings/default write is added here.
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $canApply = ($model -eq 'different') -and
        [bool]$script:DefaultGuid -and
        ($null -ne (Get-EntryByGuid ([string]$script:DefaultGuid))) -and
        [bool]$capabilities.CanSetBootNext -and
        -not [bool]$script:BootNextPendingGuid
    if ($script:RestartUseDefaultButton -and -not $script:RestartUseDefaultButton.IsDisposed) {
        $action = $script:RestartUseDefaultButton
        $action.Text = Get-LocalizedString -Key 'BootNext.UseDefaultOnce'
        $action.AccessibleName = $action.Text
        $action.AccessibleDescription = Get-LocalizedString -Key 'BootNext.UseDefaultHint' -Values @{ Default=$default }
        if ($script:BootTypeToolTip -and $script:BootTypeToolTip.GetToolTip($action) -cne $action.AccessibleDescription) { $script:BootTypeToolTip.SetToolTip($action,$action.AccessibleDescription) }
        $action.Visible = [bool]$canApply
        $action.Enabled = [bool]$canApply
        $action.TabStop = [bool]$canApply
        $action.Cursor = if ($canApply) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
    }
    if ($script:RestartButton -and -not $script:RestartButton.IsDisposed -and $script:RestartButton.Parent) {
        # Every bound is derived from the parent's current physical width,
        # never from a second DPI conversion. This reapplies after rescaling.
        $scale = [double]$script:RestartButton.Parent.Width / 390.0
        $x = if ($canApply) { 229 } else { 16 }
        $w = if ($canApply) { 145 } else { 358 }
        $script:RestartButton.Bounds = [Drawing.Rectangle]::new(
            [int][Math]::Round($x*$scale),
            [int][Math]::Round(30*$scale),
            [Math]::Max(1,[int][Math]::Round($w*$scale)),
            [Math]::Max(1,[int][Math]::Round(31*$scale)))
    }
    Update-BootNextRestartInterlock
}

function Restart-Windows {
    if ($script:BootNextPendingGuid) { return }
    if ($script:DefaultTargetChangePending) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if (-not $capabilities.CanRestart) { return }
    # A cached SelectedGuid must never be the sole evidence in a restart dialog.
    try { [void](Refresh-EffectiveNextBootState) }
    catch {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'BootNext.Unknown') -Message (Get-LocalizedString -Key 'BootNext.CheckFailed') -Kind Error
        return
    }
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
        if ($null -eq $Metadata.PSObject.Properties['defaultRestoreDelaySeconds'] -or [int]$Metadata.defaultRestoreDelaySeconds -ne 0) { return $false }

        $expectedManagerFile = Join-Path $script:TaskBrokerStateDir 'fwbootmgr.txt'
        $expectedFirmwareFile = Join-Path $script:TaskBrokerStateDir 'firmware.txt'
        $expectedDefaultFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'default-guid.txt'
        $expectedOriginFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'bootnext-origin.json'
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.managerFile),[System.IO.Path]::GetFullPath($expectedManagerFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.firmwareFile),[System.IO.Path]::GetFullPath($expectedFirmwareFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.defaultFile),[System.IO.Path]::GetFullPath($expectedDefaultFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.bootNextOriginFile),[System.IO.Path]::GetFullPath($expectedOriginFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }

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

# Bind status-only timestamps to the actual observed cache content.
# Failure leaves provenance unknown; never changes the authorized read result.
function Get-SystemStatusObservationHash {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $null }
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) }
        finally { $sha.Dispose() }
    } catch { return $null }
}
function Test-SystemStatusObservationMatch {
    param([AllowNull()][string]$Text,[AllowNull()][string]$ExpectedHash)
    if (-not $ExpectedHash) { return $false }
    return ((Get-SystemStatusObservationHash $Text) -ceq $ExpectedHash)
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
        $script:SystemStatusManagerObservedHash = Get-SystemStatusObservationHash $script:ManagerCacheText
        $script:SystemStatusManagerObservedUtc = if ($script:SystemStatusManagerObservedHash) { $script:ManagerCacheUtc } else { $null }
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
        $script:SystemStatusEntriesObservedHash = Get-SystemStatusObservationHash $script:FirmwareCacheText
        $script:SystemStatusEntriesObservedUtc = if ($script:SystemStatusEntriesObservedHash) { $script:FirmwareCacheUtc } else { $null }
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
    $script:SystemStatusReadinessObservedUtc = $null
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
    $script:SystemStatusReadinessObservedUtc = $script:TaskBrokerReadyCachedUtc
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
            if (-not (Test-SystemStatusObservationMatch $script:ManagerCacheText $script:SystemStatusManagerObservedHash)) { $script:SystemStatusManagerObservedUtc = $null; $script:SystemStatusManagerObservedHash = $null }
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
            if (-not (Test-SystemStatusObservationMatch $script:FirmwareCacheText $script:SystemStatusEntriesObservedHash)) { $script:SystemStatusEntriesObservedUtc = $null; $script:SystemStatusEntriesObservedHash = $null }
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
    $script:SystemStatusDefaultEvidence = 'unknown'
    $script:SystemStatusDefaultObservedUtc = $null
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not [string]$meta.defaultFile) { return $null }

    $path = [string]$meta.defaultFile
    if (-not (Test-Path -LiteralPath $path)) {
        if (Test-TaskBrokerMetadataContract -Metadata $meta) {
            $script:SystemStatusDefaultEvidence = 'none'
            $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
        }
        return $null
    }

    $candidate = ([System.IO.File]::ReadAllText($path)).Trim().ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $candidate
    if ($target) {
        $script:SystemStatusDefaultEvidence = 'configured'
        $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
        return $candidate
    }
    if (-not $candidate) {
        $script:SystemStatusDefaultEvidence = 'none'
        $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
    } else { $script:SystemStatusDefaultEvidence = 'unavailable' }
    return $null
}


function Get-TaskBrokerBootNextOwnership {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return $null }
    $path = [string]$meta.bootNextOriginFile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $record = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([int]$record.schema -ne 1) { return $null }
        $guid = Normalize-TaskBrokerGuid -Guid ([string]$record.guid)
        if (-not $guid -or -not (Get-TaskBrokerTarget -Guid $guid)) { return $null }
        if ([string]$record.kind -notin @('auto','manual','pending-auto','pending-manual')) { return $null }
        $sequence = [int64]$record.seq
        if ($sequence -lt 1) { return $null }
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if (-not $os -or -not $os.LastBootUpTime) { return $null }
        $cycle = [string]([datetime]$os.LastBootUpTime).ToUniversalTime().Ticks
        if ([string]$record.bootId -cne $cycle) { return $null }
        return [pscustomobject]@{ Kind = [string]$record.kind; Guid = $guid; BootId = $cycle; Sequence = $sequence }
    }
    catch { return $null }
}

function Set-TaskBrokerBootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Firmware-Ziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw "Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden: $normalized"
    }

    # Do not acknowledge a previous run of the same fixed Scheduled Task.
    # The only acceptable completion evidence is an advanced, boot-bound,
    # SYSTEM-written manual provenance sequence for this exact allowlisted GUID.
    $before = Get-TaskBrokerBootNextOwnership
    Invoke-AuthorizedTask -Operation 'BootNext' -Guid $normalized -TimeoutMs 30000 | Out-Null
    $after = Get-TaskBrokerBootNextOwnership
    if (-not $after -or $after.Kind -ne 'manual' -or $after.Guid -ne $normalized) {
        throw 'BootNext task has no verified completed manual provenance.'
    }
    if ($before -and $before.BootId -eq $after.BootId -and
        [int64]$after.Sequence -le [int64]$before.Sequence) {
        throw 'BootNext task returned without advancing protected completion evidence.'
    }
    return (Get-TaskBrokerFirmwareManagerText -Force)
}

function Set-TaskBrokerDefaultTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Standardziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'Für dieses Firmwareziel existiert keine autorisierte Standardziel-Aufgabe.'
    }

    Invoke-AuthorizedTask -Operation 'DefaultSet' -Guid $normalized -TimeoutMs 30000 | Out-Null
}

function Clear-TaskBrokerDefaultTarget {
    if (-not (Test-TaskBrokerMetadataCompatible)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
    Invoke-AuthorizedTask -Operation 'DefaultClear' -TimeoutMs 30000 | Out-Null
}

function Resolve-SystemFunctionsCapabilities {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][bool]$FactsValid,
        [Parameter(Mandatory=$true)][bool]$InstallationPresent,
        [Parameter(Mandatory=$true)][bool]$MetadataCompatible,
        [AllowNull()]$SessionReady,
        [Parameter(Mandatory=$true)][bool]$MaintenanceBusy,
        [AllowEmptyString()][string]$MaintenanceMode = '',
        [Parameter(Mandatory=$true)][bool]$DriftDetected,
        [int]$EntryCount = 0
    )

    $readyKnown = ($null -ne $SessionReady)
    $sessionReadyIsBoolean = (-not $readyKnown -or $SessionReady -is [bool])
    $ready = ($readyKnown -and $sessionReadyIsBoolean -and [bool]$SessionReady)
    $consistent = (
        $FactsValid -and
        $EntryCount -ge 0 -and
        $sessionReadyIsBoolean -and
        (-not $MetadataCompatible -or $InstallationPresent) -and
        (-not $ready -or $MetadataCompatible)
    )

    $state = if (-not $consistent) {
        'Unknown'
    }
    elseif ($MaintenanceBusy) {
        'Busy'
    }
    elseif (-not $InstallationPresent) {
        'SetupRequired'
    }
    elseif (-not $MetadataCompatible) {
        'RepairRequired'
    }
    elseif (-not $readyKnown) {
        'Checking'
    }
    elseif (-not $ready) {
        'RepairRequired'
    }
    elseif ($DriftDetected) {
        'ReinitializeRequired'
    }
    else {
        'Ready'
    }

    $isReady = ($state -eq 'Ready')
    $isChecking = ($state -eq 'Checking')
    $hasEntries = ($EntryCount -gt 0)
    $canUseCachedBootState = (
        $consistent -and
        -not $MaintenanceBusy -and
        $MetadataCompatible -and
        (-not $readyKnown -or $ready) -and
        -not $DriftDetected
    )

    [pscustomobject]@{
        State = $state
        Reason = $state
        MaintenanceMode = if ($MaintenanceBusy) { [string]$MaintenanceMode } else { '' }
        InstallationPresent = [bool]$InstallationPresent
        MetadataCompatible = [bool]$MetadataCompatible
        SessionReadyKnown = [bool]$readyKnown
        SessionReady = [bool]$ready
        DriftDetected = [bool]$DriftDetected
        EntryCount = [int]$EntryCount
        HasEntries = [bool]$hasEntries
        IsReady = [bool]$isReady
        IsChecking = [bool]$isChecking
        CanUseCachedBootState = [bool]$canUseCachedBootState
        CanRefresh = [bool]$isReady
        CanSetBootNext = [bool]($isReady -and $hasEntries)
        CanUseDefaultTarget = [bool]$isReady
        CanSetDefaultTarget = [bool]($isReady -and $hasEntries)
        CanManageEntries = [bool]($isReady -and $hasEntries)
        CanRestart = [bool]($consistent -and -not $MaintenanceBusy -and -not $DriftDetected)
        CanConfigureSystemFunctions = [bool](-not $MaintenanceBusy)
        CanRemoveSystemFunctions = [bool](-not $MaintenanceBusy)
    }
}

function Get-CurrentSystemFunctionsCapabilities {
    [CmdletBinding()]
    param([switch]$ProbeReadiness)

    try {
        $busy = Test-MaintenanceRuntimeBusy -State $script:MaintenanceState
        $mode = Get-MaintenanceRuntimeMode -State $script:MaintenanceState
        $entryCount = @($script:CurrentEntries).Count
        if ($busy) {
            return (Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $true -MaintenanceMode $mode -DriftDetected $false -EntryCount $entryCount)
        }

        $present = [bool](Test-TaskBrokerInstallationPresent)
        $compatible = if ($present) { [bool](Test-TaskBrokerMetadataCompatible) } else { $false }
        $sessionReady = $null

        if ($present -and $compatible) {
            if ($ProbeReadiness) {
                $sessionReady = [bool](Test-TaskBrokerReady)
            }
            elseif ($null -ne $script:TaskBrokerReadyCached) {
                $sessionReady = [bool]$script:TaskBrokerReadyCached
            }
        }

        $drift = [bool](Test-BootTargetDriftRuntimeDetected -State $script:BootTargetDriftState)
        return (Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $present -MetadataCompatible $compatible -SessionReady $sessionReady -MaintenanceBusy $busy -MaintenanceMode $mode -DriftDetected $drift -EntryCount $entryCount)
    }
    catch {
        return (Resolve-SystemFunctionsCapabilities -FactsValid $false -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $false -MaintenanceMode '' -DriftDetected $false -EntryCount 0)
    }
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
        $script:SystemStatusDriftFailed = $false
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
        $script:SystemStatusDriftFailed = $true
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness:(-not $Fast)
    $state = [string]$capabilities.State

    if ($script:TaskBrokerSetupMenuItem) {
        $script:TaskBrokerSetupMenuItem.Enabled = [bool]$capabilities.CanConfigureSystemFunctions
        if ($state -eq 'Busy') {
            $mode = [string]$capabilities.MaintenanceMode
            $script:TaskBrokerSetupMenuItem.Text = if ($mode -eq 'Remove') { Get-LocalizedString -Key 'Maintenance.Menu.Generic' } elseif ($mode -eq 'Reinitialize') { Get-LocalizedString -Key 'Maintenance.Menu.Reinitializing' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { Get-LocalizedString -Key 'Maintenance.Menu.Repairing' } else { Get-LocalizedString -Key 'Maintenance.Menu.SettingUp' }
        }
        elseif ($state -eq 'ReinitializeRequired') {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Reinitialize'
        }
        elseif ($state -eq 'SetupRequired') {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Setup'
        }
        else {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Repair'
        }
    }

    if ($script:TaskBrokerRemoveMenuItem) {
        # Cleanup is intentionally available even when metadata is already gone;
        # it also knows historical/probe task names from pre-TaskBroker builds.
        $script:TaskBrokerRemoveMenuItem.Enabled = [bool]$capabilities.CanRemoveSystemFunctions
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = [bool]$capabilities.CanUseDefaultTarget }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = [bool]$capabilities.CanRestart }
    Update-MaintenanceUi
    return [bool]$capabilities.IsReady
}

function Enter-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    [void](Set-MaintenanceRuntimeActive -State $script:MaintenanceState -Mode $Mode)
    $script:IsManageEntriesMode = $false
    $script:ManageUndoHistory = $null
    $script:ManageUndoInventory = @()
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
    if ($script:DefaultTargetChangePending -or $script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if ([string]$capabilities.State -eq 'Busy') { return }
    $mode = if ([string]$capabilities.State -eq 'ReinitializeRequired') {
        'Reinitialize'
    }
    elseif ([string]$capabilities.State -eq 'Ready') {
        'Repair'
    }
    elseif ([string]$capabilities.State -eq 'SetupRequired') {
        'Setup'
    }
    elseif ($capabilities.InstallationPresent) {
        'Migrate'
    }
    else {
        'Repair'
    }
    $choice = Show-LenovoSystemFunctionsDialog -Mode $mode
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode $mode }
}

function Prompt-TaskBrokerReinitialize {
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'ReinitializeRequired') { return }
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
    $script:SystemStatusManagerObservedUtc = $null
    $script:SystemStatusManagerObservedHash = $null
    $script:SystemStatusEntriesObservedUtc = $null
    $script:SystemStatusEntriesObservedHash = $null
    $script:SystemStatusReadinessObservedUtc = $null
    $script:SystemStatusNextObservedUtc = $null
    $script:SystemStatusDefaultObservedUtc = $null
    $script:SystemStatusDefaultEvidence = 'unknown'
    $script:SystemStatusLastRefresh = 'unknown'
    $script:TaskBrokerMetadata = $null
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    $script:DefaultGuid = $null
    $script:IsManageEntriesMode = $false
    $script:ManageUndoHistory = $null
    $script:ManageUndoInventory = @()
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
    if ($script:DefaultTargetChangePending -or $script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
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
        # Keep the exact original raw input (including empty descriptions)
        # and associated storage snapshot for presentation-only relocalization.
        LocalizationRawDescription = [string]$RawDescription
        LocalizationStorageContext = $StorageContext
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
    param([switch]$UseExistingCache, [switch]$ForceManagerRefresh)

    if ($UseExistingCache -and $ForceManagerRefresh) {
        throw 'Cannot combine cached firmware state with a forced firmware-manager refresh.'
    }
    # A snapshot later labelled freshly verified must bypass the short manager
    # cache. A cached popup-open snapshot must never be labelled verified.
    $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache:$UseExistingCache -Force:$ForceManagerRefresh
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

function Invoke-BackgroundRefreshWorker {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [AllowNull()][string]$ResultPath
    )

    $total = [System.Diagnostics.Stopwatch]::StartNew()
    $timings = [ordered]@{ ReadyMs = 0; ManagerMs = 0; FirmwareMs = 0; StorageMs = 0; TotalMs = 0 }
    $result = [ordered]@{ Success = $false; Error = $null; Stage = 'ready'; StorageContext = $null; Timings = $timings; ManagerObservedUtc = $null; ManagerObservedHash = $null; EntriesObservedUtc = $null; EntriesObservedHash = $null; ReadinessObservedUtc = $null }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if (-not (Test-TaskBrokerReady -Force)) { throw 'Die Systemfunktionen sind nicht vollständig verfügbar.' }
        $sw.Stop(); $timings.ReadyMs = $sw.ElapsedMilliseconds

        $result.Stage = 'manager'
        $sw.Restart(); [void](Get-TaskBrokerFirmwareManagerText -Force); $sw.Stop(); $timings.ManagerMs = $sw.ElapsedMilliseconds
        if ($RefreshFirmware) {
            $result.Stage = 'firmware'
            $sw.Restart(); [void](Get-TaskBrokerFirmwareEntriesText -Force); $sw.Stop(); $timings.FirmwareMs = $sw.ElapsedMilliseconds
        }

        if ($RefreshStorage) {
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
        $result.ManagerObservedUtc = $script:SystemStatusManagerObservedUtc
        $result.ManagerObservedHash = $script:SystemStatusManagerObservedHash
        $result.EntriesObservedUtc = $script:SystemStatusEntriesObservedUtc
        $result.EntriesObservedHash = $script:SystemStatusEntriesObservedHash
        $result.ReadinessObservedUtc = $script:SystemStatusReadinessObservedUtc
        if ($ResultPath) {
            try {
                $parent = Split-Path -Parent $ResultPath
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                $json = $result | ConvertTo-Json -Depth 8
                [System.IO.File]::WriteAllText($ResultPath, $json, (New-Object System.Text.UTF8Encoding($false)))
            }
            catch { }
        }
    }

    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $timings.TotalMs -Data (New-RuntimeDiagnosticData @{ readyMs = $timings.ReadyMs; managerMs = $timings.ManagerMs; firmwareMs = $timings.FirmwareMs; storageMs = $timings.StorageMs; workerError = [string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    if ($result.Success) { return 0 }
    return 1
}

# A separate UNELEVATED PowerShell process executes one allowlisted BootNext
# request. The fixed SYSTEM TaskBroker remains the ONLY privileged writer.
function Start-BootNextSelectionWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [Parameter(Mandatory=$true)][string]$Guid,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [AllowNull()][string]$RuntimeSessionId
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'BootNext worker target is not on the installed firmware allowlist.'
    }
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $parts = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-BootNextWorker', '-BootNextGuid', ('"{0}"' -f $normalized),
        '-BootNextResultPath', ('"{0}"' -f $ResultPath)
    )
    if ($RuntimeSessionId) { $parts += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($parts -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $process = [Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'BootNext worker could not start.' }
    return $process
}

function Invoke-BootNextSelectionWorker {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [Parameter(Mandatory=$true)][string]$ResultPath
    )
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $result = [ordered]@{ Success=$false; Guid=[string]$normalized; Error='' }
    try {
        if (-not $normalized) { throw 'Invalid BootNext worker GUID.' }
        $verified = Set-BootNextTargetService -Guid $normalized
        if ([int]$verified.ExitCode -ne 0 -or [string]$verified.Guid -ne $normalized) {
            throw 'BootNext worker did not verify the selected firmware target.'
        }
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        try {
            $parent = Split-Path -Parent $ResultPath
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                throw 'BootNext worker result directory is missing.'
            }
            $json = $result | ConvertTo-Json -Compress -Depth 4
            [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))
        }
        catch { $result.Success = $false }
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_WORKER_COMPLETED' -Stage 'bootnext' -Success ([bool]$result.Success) -DurationMs $stopwatch.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            guid=$normalized; workerError=[string]$result.Error
        }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    }
    if ($result.Success) { return 0 }
    return 1
}

# LBS-206: unelevated persistent-default worker. The fixed allowlisted
# TaskBroker SYSTEM tasks remain the only privileged writers. UI is not created.
function Start-DefaultTargetWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [AllowNull()][string]$Guid,
        [bool]$Clear,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)][string]$ProgressPath,
        [AllowNull()][string]$RuntimeSessionId
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $Clear -and (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized))) {
        throw 'The requested default target is not in the authorized firmware allowlist.'
    }
    if ($Clear -and $Guid) { throw 'Clear default operation cannot name a target.' }

    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-DefaultTargetWorker',
        '-DefaultTargetResultPath', ('"{0}"' -f $ResultPath),
        '-DefaultTargetProgressPath', ('"{0}"' -f $ProgressPath)
    )
    if ($Clear) { $args += '-DefaultTargetClear' }
    else { $args += @('-DefaultTargetGuid', ('"{0}"' -f $normalized)) }
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $process = [Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Default target worker could not start.' }
    return $process
}

function Invoke-DefaultTargetWorker {
    param(
        [AllowNull()][string]$Guid,
        [bool]$Clear,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)][string]$ProgressPath
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $operation = if ($Clear) { 'clear' } else { 'set' }
    $result = [ordered]@{
        Success = $false
        Operation = $operation
        RequestedGuid = if ($Clear) { '' } else { [string]$normalized }
        SavedGuid = ''
        NextGuid = ''
        NextVerified = $false
        NextObservedUtc = $null
        NextObservedHash = $null
        Stage = 'admission'
        Error = ''
    }
    try {
        if ($Clear -and $Guid) { throw 'Clear worker must not carry a target.' }
        if (-not $Clear -and (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized))) {
            throw 'Default target is not allowlisted.'
        }
        $result.Stage = 'saving'
        # Only the original guarded writer is allowed to persist a default.
        # Its optional progress marker is written AFTER the authorized task
        # returns, and BEFORE its independent default/firmware readback.
        Set-DefaultGuid -Guid $(if ($Clear) { $null } else { $normalized }) -ProgressPath $ProgressPath
        if ($Clear -and $script:DefaultGuid) { throw 'Clear was not verified.' }
        if (-not $Clear -and [string]$script:DefaultGuid -ne $normalized) {
            throw 'Saved default does not match the requested target.'
        }
        $result.SavedGuid = [string]$script:DefaultGuid
        $result.NextGuid = [string]$script:SelectedGuid
        $result.NextVerified = [bool]$script:NextBootFirmwareReadVerified
        $result.NextObservedUtc = $script:SystemStatusNextObservedUtc
        $result.NextObservedHash = $script:SystemStatusManagerObservedHash
        $result.Stage = if ($result.NextVerified) { 'complete' } else { 'next-unverified' }
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
        $result.Stage = 'failed'
    }
    finally {
        $sw.Stop()
        try {
            if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultPath) -PathType Container)) {
                throw 'Default worker result directory does not exist.'
            }
            $json = $result | ConvertTo-Json -Compress -Depth 4
            [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))
        }
        catch { $result.Success = $false }
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            operation=$operation; targetGuid=[string]$result.RequestedGuid
            nextVerified=[bool]$result.NextVerified; workerError=[string]$result.Error
        }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    }
    if ($result.Success) { return 0 }
    return 1
}

function New-BackgroundRefreshRequest {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [ValidateSet('Background','Startup','Popup','Manual')][string]$Origin = 'Background'
    )

    [pscustomobject]@{
        RefreshStorage  = [bool]$RefreshStorage
        RefreshFirmware = [bool]$RefreshFirmware
        Origin          = $Origin
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

# Coalesced equivalent requests retain the most meaningful presentation
# origin without adding work. Startup readiness must never be relabeled.
function Merge-BackgroundRefreshOrigin {
    param([string]$Current,[string]$Requested)
    foreach ($origin in @('Startup','Manual','Popup','Background')) {
        if ($Current -eq $origin -or $Requested -eq $origin) { return $origin }
    }
    return 'Background'
}

function Add-BackgroundRefreshPendingRequest {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Request
    )

    if (-not $State.PendingRequest) {
        $State.PendingRequest = New-BackgroundRefreshRequest -RefreshStorage:$Request.RefreshStorage -RefreshFirmware:$Request.RefreshFirmware -Origin $Request.Origin
        return $State.PendingRequest
    }

    if ($Request.RefreshStorage) { $State.PendingRequest.RefreshStorage = $true }
    if ($Request.RefreshFirmware) { $State.PendingRequest.RefreshFirmware = $true }
    $State.PendingRequest.Origin = Merge-BackgroundRefreshOrigin -Current $State.PendingRequest.Origin -Requested $Request.Origin
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

# LBS-143 follow-up: keep WinForms responsive while the fixed SYSTEM
# BootNext task and authoritative firmware verification execute off-thread.
# All UI state changes occur on the original WinForms message-loop thread.
function Update-BootNextRestartInterlock {
    $pending = [bool]($script:BootNextPendingGuid -or $script:DefaultTargetChangePending)
    if ($script:RestartButton -and -not $script:RestartButton.IsDisposed) {
        $script:RestartButton.Enabled = -not $pending
    }
    if ($script:RestartUseDefaultButton -and -not $script:RestartUseDefaultButton.IsDisposed -and $pending) {
        # The separate one-time action is never available during readback.
        $script:RestartUseDefaultButton.Enabled = $false
        $script:RestartUseDefaultButton.TabStop = $false
        $script:RestartUseDefaultButton.Visible = $false
    }
    if ($script:RestartTargetLabel -and -not $script:RestartTargetLabel.IsDisposed -and $script:BootNextPendingGuid) {
        $entry = Get-EntryByGuid ([string]$script:BootNextPendingGuid)
        $title = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'BootNext.Unknown' }
        $text = Get-LocalizedString -Key 'BootNext.SelectionPendingFooter' -Values @{ Target=$title }
        $script:RestartTargetLabel.Text = $text
        # A passive Label stays enabled so pending amber ink remains readable;
        # its lack of click handler and TabStop keep it non-interactive.
        $script:RestartTargetLabel.Enabled = $true
        if ($script:ColorWarning) { $script:RestartTargetLabel.ForeColor = $script:ColorWarning }
        $script:RestartTargetLabel.TabStop = $false
        $script:RestartTargetLabel.Cursor = [Windows.Forms.Cursors]::Default
        $script:RestartTargetLabel.AccessibleDescription = $text
    }
}

function Stop-BootNextSelectionWorker {
    param([string]$Reason = 'completed')
    if ($script:BootNextSelectionTimer) {
        try { $script:BootNextSelectionTimer.Stop(); $script:BootNextSelectionTimer.Dispose() } catch { }
        $script:BootNextSelectionTimer = $null
    }
    if ($script:BootNextSelectionProcess) {
        try {
            $script:BootNextSelectionProcess.Refresh()
            if (-not $script:BootNextSelectionProcess.HasExited) {
                $script:BootNextSelectionProcess.Kill()
                $script:BootNextSelectionProcess.WaitForExit(3000) | Out-Null
            }
            $script:BootNextSelectionProcess.Dispose()
        } catch { }
        $script:BootNextSelectionProcess = $null
    }
    if ($script:BootNextSelectionResultPath) {
        Remove-BackgroundRefreshResultFile -Path ([string]$script:BootNextSelectionResultPath)
        $script:BootNextSelectionResultPath = $null
    }
    $script:BootNextPendingGuid = $null
    $script:BootNextSelectionDeferred = $false
    $script:BootNextSelectionStartedUtc = [datetime]::MinValue
}

function Start-AuthorizedPendingBootNextWorker {
    $requested = [string]$script:BootNextPendingGuid
    if (-not $requested) { throw 'BootNext request is no longer pending.' }
    # Recheck authorizing facts AFTER cold-start readiness; never run in Checking.
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetBootNext -or
        $script:IsManageEntriesMode -or (Test-MaintenanceBusy) -or $script:DefaultTargetChangePending) {
        throw 'TaskBroker is not ready for a BootNext request.'
    }
    $entry = Get-EntryByGuid $requested
    if (-not $entry -or -not (Get-TaskBrokerTarget -Guid $requested)) {
        throw 'Requested BootNext target is no longer available or allowlisted.'
    }
    # Warm Ready requests can safely retire a stale refresh. A deferred cold
    # request never gets here until its readiness-producing worker has finished.
    if ($script:BackgroundRefreshState -and
        (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
        Stop-BackgroundBootRefreshForMaintenance -Reason 'bootnext-selection'
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }
    $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-bootnext-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $process = Start-BootNextSelectionWorkerProcess -ScriptPath $script:ScriptPath -Guid $requested -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
    $script:BootNextSelectionResultPath = $resultPath
    $script:BootNextSelectionProcess = $process
    $script:BootNextSelectionDeferred = $false
    Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_WORKER_STARTED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$requested; processId=$process.Id; admission='ready' })
}

function Fail-DeferredBootNextSelection {
    param([string]$Reason = 'not-ready', [switch]$Timeout)
    $requested = [string]$script:BootNextPendingGuid
    Write-RuntimeDiagnosticEvent -Event $(if ($Timeout) { 'BOOTNEXT_DEFERRED_TIMEOUT' } else { 'BOOTNEXT_DEFERRED_REJECTED' }) -Stage 'bootnext' -Success $false -Level warning -Data (New-RuntimeDiagnosticData @{ guid=$requested; reason=$Reason })
    Stop-BootNextSelectionWorker -Reason $Reason
    $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
    Update-PopupRows
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
}

function Start-BootNextSelection {
    param([Parameter(Mandatory=$true)][string]$Guid)
    if ($script:DefaultTargetChangePending) {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_REJECTED' -Stage 'bootnext' -Success $false -Data (New-RuntimeDiagnosticData @{ reason='default-target-changing' })
        return
    }
    if ($script:BootNextPendingGuid) {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_REJECTED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ reason='already-pending' })
        return
    }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $entry = if ($normalized) { Get-EntryByGuid $normalized } else { $null }
    $targetAllowed = [bool]($entry -and $normalized -and (Get-TaskBrokerTarget -Guid $normalized))
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $refreshActive = [bool]($script:BackgroundRefreshState -and (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))
    $admission = Resolve-BootNextSelectionAdmissionCore -CapabilityState ([string]$capabilities.State) -CanSetBootNext ([bool]$capabilities.CanSetBootNext) -CanUseCachedBootState ([bool]$capabilities.CanUseCachedBootState) -RefreshActive $refreshActive -TargetAllowlisted $targetAllowed
    if ($script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { $admission = 'reject' }
    if ($admission -eq 'reject') {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_REJECTED' -Stage 'bootnext' -Success $false -Data (New-RuntimeDiagnosticData @{ guid=$normalized; state=[string]$capabilities.State; refreshActive=$refreshActive })
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        Update-PopupRows
        return
    }
    # LBS-219: only a confirmed, allowlisted one-shot target is idempotent.
    # NextBootFirmwareReadVerified is asserted after forced firmware-manager
    # readback, never for a cached projection. An in-flight refresh makes
    # even a previously verified GUID ineligible for this no-op.
    # Admission and all interlocks are checked before changing any GUI state.
    if ($admission -eq 'start' -and $script:NextBootFirmwareReadVerified -and
        $normalized -and $script:SelectedGuid -and
        $normalized -eq $script:SelectedGuid -and -not $refreshActive) {
        return
    }
    $deferred = ($admission -eq 'deferred')
    try {
        $script:BootNextPendingGuid = $normalized
        $script:BootNextSelectionDeferred = $deferred
        $script:BootNextSelectionStartedUtc = [datetime]::UtcNow
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionPending'
        Update-PopupRows
        Update-BootNextRestartInterlock
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_PENDING_SHOWN' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$normalized; deferred=$deferred; state=[string]$capabilities.State })
        if (-not $deferred) {
            Start-AuthorizedPendingBootNextWorker
        }
        else {
            # Never cancel the worker that is establishing first-run readiness.
            Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_DEFERRED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$normalized; state='Checking' })
        }
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 120
        $timer.Add_Tick({ Complete-BootNextSelection })
        $script:BootNextSelectionTimer = $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SELECTION_START_FAILED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
        Stop-BootNextSelectionWorker -Reason 'start-failed'
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        Update-PopupRows
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}

function Complete-BootNextSelection {
    if (-not $script:BootNextPendingGuid) { return }
    if ($script:BootNextSelectionDeferred) {
        $elapsed = ([datetime]::UtcNow - $script:BootNextSelectionStartedUtc).TotalSeconds
        if ($elapsed -gt 45) {
            Fail-DeferredBootNextSelection -Reason 'readiness-timeout' -Timeout
            return
        }
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if ([string]$capabilities.State -eq 'Ready' -and $capabilities.CanSetBootNext) {
            try {
                Start-AuthorizedPendingBootNextWorker
            }
            catch {
                Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_DEFERRED_DISPATCH_FAILED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
                Fail-DeferredBootNextSelection -Reason 'authorized-dispatch-failed'
            }
        }
        elseif ([string]$capabilities.State -ne 'Checking' -or
            -not $capabilities.CanUseCachedBootState -or
            -not $script:BackgroundRefreshState -or
            -not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
            Fail-DeferredBootNextSelection -Reason ('readiness-' + [string]$capabilities.State)
        }
        return
    }
    if (-not $script:BootNextSelectionProcess) {
        Fail-DeferredBootNextSelection -Reason 'worker-missing'
        return
    }
    $process = $script:BootNextSelectionProcess
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) {
        if (([datetime]::UtcNow - $script:BootNextSelectionStartedUtc).TotalSeconds -lt 75) { return }
    }
    $requested = [string]$script:BootNextPendingGuid
    $verified = $false
    try {
        if (-not $process.HasExited) { throw 'BootNext worker timed out before a verified result.' }
        $path = [string]$script:BootNextSelectionResultPath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw 'BootNext worker produced no completion record.'
        }
        $result = ([IO.File]::ReadAllText($path,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop)
        if ($process.ExitCode -ne 0 -or
            -not (Test-BootNextWorkerResultCore -RequestedGuid $requested -ReturnedGuid ([string]$result.Guid) -Success ([bool]$result.Success))) {
            throw ('BootNext worker failed: ' + [string]$result.Error)
        }
        [void](Refresh-EffectiveNextBootState)
        if ($script:SelectedGuid -ne $requested) {
            throw 'Firmware next-boot target changed after worker verification.'
        }
        $verified = $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SELECTION_COMPLETED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
        try { [void](Refresh-EffectiveNextBootState) }
        catch { $script:SelectedGuid = $null; $script:NextBootFirmwareReadVerified = $false }
    }
    finally {
        Stop-BootNextSelectionWorker -Reason 'completed'
        if ($verified) {
            $entry = Get-EntryByGuid $requested
            $script:LastStatusText = if ($entry) {
                Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $entry) }
            } else { Get-LocalizedString -Key 'Status.NextBootSet' }
            Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$requested; source='async-worker' })
        }
        else {
            $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        }
        Update-PopupRows
    }
    if (-not $verified) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}

# LBS-206: an explicit persistent-default change runs in one UNELEVATED
# child process. Only the preinstalled allowlisted SYSTEM tasks may write it.
# WinForms state is mutated only on the main STA / Forms.Timer thread.
function Stop-DefaultTargetChangeWorker {
    param([string]$Reason = 'completed')
    if ($script:DefaultTargetChangeTimer) {
        try { $script:DefaultTargetChangeTimer.Stop(); $script:DefaultTargetChangeTimer.Dispose() } catch { }
        $script:DefaultTargetChangeTimer = $null
    }
    if ($script:DefaultTargetChangeProcess) {
        try {
            $script:DefaultTargetChangeProcess.Refresh()
            if (-not $script:DefaultTargetChangeProcess.HasExited) {
                $script:DefaultTargetChangeProcess.Kill()
                $script:DefaultTargetChangeProcess.WaitForExit(3000) | Out-Null
            }
            $script:DefaultTargetChangeProcess.Dispose()
        }
        catch { }
        $script:DefaultTargetChangeProcess = $null
    }
    foreach ($path in @($script:DefaultTargetChangeResultPath,$script:DefaultTargetChangeProgressPath)) {
        if ($path) { Remove-BackgroundRefreshResultFile -Path ([string]$path) }
    }
    $script:DefaultTargetChangeResultPath = $null
    $script:DefaultTargetChangeProgressPath = $null
    $script:DefaultTargetChangeRequestedGuid = $null
    $script:DefaultTargetChangeOperation = ''
    $script:DefaultTargetChangeStage = ''
    $script:DefaultTargetChangePending = $false
    $script:DefaultTargetChangeWorkerStarted = $false
    $script:DefaultTargetChangeStartedUtc = [datetime]::MinValue
}

function Start-DefaultTargetChange {
    param([AllowNull()][string]$Guid)
    # A pending save is a single immutable intent. No superseding click
    # may create a second SYSTEM task or overlap a one-shot BootNext writer.
    if ($script:DefaultTargetChangePending -or $script:BootNextPendingGuid -or
        $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetDefaultTarget) { return }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if ($Guid -and (-not $normalized -or -not (Get-EntryByGuid $normalized) -or
        -not (Get-TaskBrokerTarget -Guid $normalized))) { return }
    if ([string]$script:DefaultGuid -eq [string]$normalized) { return }
    $script:DefaultTargetChangePending = $true
    $script:DefaultTargetChangeRequestedGuid = if ($normalized) { [string]$normalized } else { $null }
    $script:DefaultTargetChangeOperation = if ($normalized) { 'set' } else { 'clear' }
    $script:DefaultTargetChangeStage = 'saving'
    $script:DefaultTargetChangeStartedUtc = [datetime]::UtcNow
    $script:DefaultTargetChangeWorkerStarted = $false
    $target = if ($normalized) {
        $entry = Get-EntryByGuid $normalized
        if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { $normalized }
    } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
    $script:LastStatusText = Get-LocalizedString -Key 'Default.ChangeSavingFooter' -Values @{ Target = $target }
    try {
        # Render pending BEFORE queuing the child on a later WinForms tick.
        Update-DefaultUi
        Update-RestartTargetUi
        Update-PopupRows
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_PENDING_SHOWN' -Stage 'default' -Success $true -Data (New-RuntimeDiagnosticData @{ operation=$script:DefaultTargetChangeOperation; targetGuid=[string]$normalized })
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 120
        $timer.Add_Tick({ Complete-DefaultTargetChange })
        $script:DefaultTargetChangeTimer = $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_ASYNC_START_FAILED' -Stage 'default' -Success $false -ErrorRecord $_ -Level error
        Stop-DefaultTargetChangeWorker -Reason 'ui-start-failed'
        Update-DefaultUi
        Update-RestartTargetUi
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error
    }
}

function Start-AuthorizedDefaultTargetWorker {
    $requested = [string]$script:DefaultTargetChangeRequestedGuid
    $clear = ($script:DefaultTargetChangeOperation -eq 'clear')
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetDefaultTarget -or
        $script:BootNextPendingGuid -or $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) {
        throw 'Default-target operation is no longer admissible.'
    }
    if (-not $clear -and (-not (Get-EntryByGuid $requested) -or
        -not (Get-TaskBrokerTarget -Guid $requested))) {
        throw 'Default-target operation is not allowlisted.'
    }
    if ($clear -and $requested) { throw 'Clear default cannot have a target.' }
    # The read-only startup refresh must not race a persistent default write.
    if ($script:BackgroundRefreshState -and
        (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
        Stop-BackgroundBootRefreshForMaintenance -Reason 'default-target-change'
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }
    $token = [guid]::NewGuid().ToString('N')
    $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-default-{0}.json" -f $token)
    $progressPath = Join-Path $script:TaskBrokerLocalDir ("runtime-default-{0}.progress" -f $token)
    $process = Start-DefaultTargetWorkerProcess -ScriptPath $script:ScriptPath -Guid $requested -Clear $clear -ResultPath $resultPath -ProgressPath $progressPath -RuntimeSessionId $script:RuntimeSessionId
    $script:DefaultTargetChangeProcess = $process
    $script:DefaultTargetChangeResultPath = $resultPath
    $script:DefaultTargetChangeProgressPath = $progressPath
    Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_WORKER_STARTED' -Stage 'default' -Success $true -Data (New-RuntimeDiagnosticData @{ operation=$script:DefaultTargetChangeOperation; targetGuid=$requested; processId=$process.Id })
}

function Complete-DefaultTargetChange {
    if (-not $script:DefaultTargetChangePending) { return }
    if (-not $script:DefaultTargetChangeWorkerStarted) {
        $script:DefaultTargetChangeWorkerStarted = $true
        try { Start-AuthorizedDefaultTargetWorker }
        catch {
            Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_ASYNC_START_FAILED' -Stage 'default' -Success $false -ErrorRecord $_ -Level error
            Stop-DefaultTargetChangeWorker -Reason 'worker-start-failed'
            Update-DefaultUi
            Update-RestartTargetUi
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error
        }
        return
    }
    if (-not $script:DefaultTargetChangeProcess) { return }
    $process = $script:DefaultTargetChangeProcess
    try { $process.Refresh() } catch { }
    if ($script:DefaultTargetChangeStage -eq 'saving' -and $script:DefaultTargetChangeProgressPath -and
        (Test-Path -LiteralPath $script:DefaultTargetChangeProgressPath -PathType Leaf)) {
        try {
            if ([IO.File]::ReadAllText($script:DefaultTargetChangeProgressPath,[Text.Encoding]::UTF8).Trim() -eq 'verifying') {
                $script:DefaultTargetChangeStage = 'verifying'
                Update-DefaultUi
                Update-RestartTargetUi
                Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_VERIFYING_SHOWN' -Stage 'default' -Success $true
            }
        } catch { }
    }
    $timeout = (([datetime]::UtcNow - $script:DefaultTargetChangeStartedUtc).TotalSeconds -ge 75)
    if (-not $process.HasExited -and -not $timeout) { return }
    $requested = [string]$script:DefaultTargetChangeRequestedGuid
    $operation = [string]$script:DefaultTargetChangeOperation
    $verifiedDefault = $false
    $verifiedNext = $false
    $workerSuccess = $false
    $failure = $null
    $readGuid = $null
    try {
        $result = $null
        if (-not $process.HasExited) { throw 'Default worker timed out.' }
        if (-not $script:DefaultTargetChangeResultPath -or
            -not (Test-Path -LiteralPath $script:DefaultTargetChangeResultPath -PathType Leaf)) {
            throw 'Default worker did not return a result.'
        }
        $result = [IO.File]::ReadAllText($script:DefaultTargetChangeResultPath,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([string]$result.Operation -ne $operation -or
            [string]$result.RequestedGuid -ne $requested) {
            throw 'Default worker result does not match the pending request.'
        }
        $workerSuccess = ($process.ExitCode -eq 0 -and [bool]$result.Success)
        if (-not $workerSuccess) {
            throw ('Default worker did not confirm completion: ' + [string]$result.Error)
        }
    }
    catch { $failure = $_ }
    # This read happens after child process termination on the STA and uses
    # only the SYSTEM-owned file; it does NOT launch a second scheduled task.
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta -or -not [string]$meta.defaultFile) {
            throw 'TaskBroker default-state metadata unavailable.'
        }
        $readGuid = Get-TaskBrokerDefaultTargetGuid
        $verifiedDefault = ([string]$readGuid -eq $requested)
        $script:DefaultGuid = if ($readGuid) { [string]$readGuid } else { $null }
    }
    catch {
        $verifiedDefault = $false
        $failure = $_
    }
    if ($verifiedDefault -and $workerSuccess -and [bool]$result.NextVerified) {
        try {
            $meta = Get-TaskBrokerMetadata
            if (-not $meta -or -not [string]$meta.managerFile) { throw 'Firmware manager cache path unavailable.' }
            # Force-refresh happened INSIDE the worker. The parent reads the
            # newly written SYSTEM snapshot without starting another long task.
            $managerText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
            $state = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
            $workerNext = [string]$result.NextGuid
            $readNext = [string]$state.SelectedGuid
            if ($workerNext -ne $readNext) { throw 'Worker firmware result mismatch.' }
            $script:SelectedGuid = if ($readNext) { $readNext.ToLowerInvariant() } else { $null }
            $script:NextBootFirmwareReadVerified = $true
            $script:SystemStatusNextObservedUtc = if ($result.NextObservedHash -and (Test-SystemStatusObservationMatch $managerText $result.NextObservedHash)) { $result.NextObservedUtc } else { $null }
            $verifiedNext = $true
        }
        catch { $failure = $_ }
    }
    if (-not $verifiedNext) {
        # A default task can succeed while its BootNext side effect remains
        # unreadable. Never keep an old "confirmed" next-boot checkmark.
        $script:SelectedGuid = $null
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusNextObservedUtc = $null
    }
    $outcome = if ($workerSuccess -and $verifiedDefault -and $verifiedNext) { 'complete' }
               elseif ($verifiedDefault) { 'partial' }
               else { 'failed' }
    Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE_ASYNC_COMPLETED' -Stage $outcome -Success ($outcome -eq 'complete') -ErrorRecord $failure -Level $(if ($outcome -eq 'complete') { 'info' } elseif ($outcome -eq 'partial') { 'warning' } else { 'error' }) -Data (New-RuntimeDiagnosticData @{
        operation=$operation; requestedGuid=$requested; observedGuid=[string]$readGuid
        workerSuccess=$workerSuccess; defaultVerified=$verifiedDefault; nextVerified=$verifiedNext
    })
    Stop-DefaultTargetChangeWorker -Reason $outcome
    if ($outcome -eq 'complete') {
        $entry = if ($script:DefaultGuid) { Get-EntryByGuid ([string]$script:DefaultGuid) } else { $null }
        $target = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
        $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemSavedStatus' -Values @{ Name=$target }
    }
    else {
        $script:LastStatusText = if ($outcome -eq 'partial') {
            Get-LocalizedString -Key 'Default.ChangePartial'
        } else { Get-LocalizedString -Key 'Default.SaveErrorHeading' }
    }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-PopupRows
    if ($outcome -ne 'complete') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key $(if ($outcome -eq 'partial') { 'Default.ChangePartialHeading' } else { 'Default.SaveErrorHeading' })) -Message (Get-LocalizedString -Key $(if ($outcome -eq 'partial') { 'Default.ChangePartial' } else { 'Default.SaveErrorMessage' })) -Kind $(if ($outcome -eq 'partial') { 'Warning' } else { 'Error' })
    }
}

# Background-refresh lifecycle orchestration.
# Infrastructure owns worker/IO mechanics; UI owns presentation/timer construction.

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
        $script:SystemStatusLastRefresh = 'error'
        if ($Result.ReadinessObservedUtc) { $script:SystemStatusReadinessObservedUtc = $Result.ReadinessObservedUtc }
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
            if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows -Reason 'readiness-failed' }
            return $false
        }
        throw ("Hintergrund-Refresh ({0}) fehlgeschlagen: {1}" -f ([string]$Result.Stage), ([string]$Result.Error))
    }

    $script:TaskBrokerReadyCached = $true
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    Set-BackgroundRefreshLastTiming -State $script:BackgroundRefreshState -Timing $Result.Timings
    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ requestedStorage = $requestedStorage; readyMs = $Result.Timings.ReadyMs; managerMs = $Result.Timings.ManagerMs; firmwareMs = $Result.Timings.FirmwareMs; storageMs = $Result.Timings.StorageMs })

    [void](Sync-TaskBrokerFirmwareCachesFromFiles)
    if ($Result.ManagerObservedHash -and (Test-SystemStatusObservationMatch $script:ManagerCacheText $Result.ManagerObservedHash)) {
        $script:SystemStatusManagerObservedUtc = $Result.ManagerObservedUtc
        $script:SystemStatusManagerObservedHash = $Result.ManagerObservedHash
    } else {
        $script:SystemStatusManagerObservedUtc = $null
        $script:SystemStatusManagerObservedHash = $null
    }
    if ($Result.EntriesObservedUtc -and $Result.EntriesObservedHash -and (Test-SystemStatusObservationMatch $script:FirmwareCacheText $Result.EntriesObservedHash)) {
        $script:SystemStatusEntriesObservedUtc = $Result.EntriesObservedUtc
        $script:SystemStatusEntriesObservedHash = $Result.EntriesObservedHash
    } elseif (-not $script:SystemStatusEntriesObservedHash -or -not (Test-SystemStatusObservationMatch $script:FirmwareCacheText $script:SystemStatusEntriesObservedHash)) {
        $script:SystemStatusEntriesObservedUtc = $null
        $script:SystemStatusEntriesObservedHash = $null
    }
    $script:SystemStatusReadinessObservedUtc = $Result.ReadinessObservedUtc
    [void](Update-BootTargetDriftState)

    if ($requestedStorage -and $Result.StorageContext) {
        $script:StorageContext = $Result.StorageContext
    }

    $state = Get-FirmwareBootState -UseExistingCache
    Apply-FirmwareBootState -State $state -VerifiedFresh
    $script:SystemStatusLastRefresh = 'success'
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
        $script:SystemStatusLastRefresh = 'error'
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
        Start-BackgroundBootRefresh -RefreshStorage:$pendingStorage -Origin $pending.Origin
    }
}

function Start-BackgroundBootRefresh {
    param([switch]$RefreshStorage,[ValidateSet('Background','Startup','Popup','Manual')][string]$Origin = 'Background')

    if ($script:DefaultTargetChangePending) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_SUPPRESSED' -Stage 'default' -Success $true -Data (New-RuntimeDiagnosticData @{ reason='default-target-changing' })
        return
    }
    if (Test-MaintenanceBusy) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_SUPPRESSED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); refreshStorage = [bool]$RefreshStorage })
        return
    }

    $refreshFirmware = Test-BackgroundRefreshNeedsFirmware `
        -RefreshStorage ([bool]$RefreshStorage) `
        -FirmwareCacheText $script:FirmwareCacheText `
        -FirmwareCacheUtc $script:FirmwareCacheUtc
    $request = New-BackgroundRefreshRequest -RefreshStorage ([bool]$RefreshStorage) -RefreshFirmware ([bool]$refreshFirmware) -Origin $Origin

    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        try {
            $script:BackgroundRefreshState.Process.Refresh()
            if (-not $script:BackgroundRefreshState.Process.HasExited) {
                # Popup opens while startup refresh is active must not queue a duplicate.
                # Only a request that adds storage or firmware work is coalesced as pending.
                if (Test-BackgroundRefreshRequestEscalation -ActiveRequest $script:BackgroundRefreshState.ActiveRequest -Requested $request) {
                    [void](Add-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState -Request $request)
                }
                else {
                    $script:BackgroundRefreshState.ActiveRequest.Origin = Merge-BackgroundRefreshOrigin -Current $script:BackgroundRefreshState.ActiveRequest.Origin -Requested $request.Origin
                }
                Update-RefreshButtonVisual
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

        $timer = New-BackgroundRefreshCompletionTimer -TickAction { Complete-BackgroundBootRefresh }
        Set-BackgroundRefreshTimer -State $script:BackgroundRefreshState -Timer $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware }) -Level error
        $script:SystemStatusLastRefresh = 'error'
        $script:LastStatusText = Get-LocalizedString -Key 'Status.RefreshStartFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}


$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState


function Get-FirmwareBootState {
    param(
        [switch]$RefreshStorage,
        [switch]$UseExistingCache,
        [switch]$ForceManagerRefresh
    )

    $snapshot = Get-BootServiceFirmwareSnapshot -UseExistingCache:$UseExistingCache -ForceManagerRefresh:$ForceManagerRefresh
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if (-not $capabilities.CanSetBootNext) { throw 'Das Startziel ist derzeit nicht verfügbar.' }
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

# LBS-144: establish one DPI-aware WinForms UI thread BEFORE its first HWND.
# SystemAware matches the owner's post-popup context in PowerShell 5.1.
# Do not request PMv2 here: native ToolStrip and manually scaled WinForms
# controls have not been validated for that different awareness contract.
function Initialize-LenovoUiDpiAwareness {
    if (-not ('LenovoUiDpiAwarenessNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LenovoUiDpiAwarenessNative {
    [DllImport("user32.dll", SetLastError=true)]
    private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")]
    private static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")]
    private static extern int GetAwarenessFromDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")]
    private static extern uint GetDpiForSystem();
    public static bool MakeSystemAware() {
        return SetThreadDpiAwarenessContext(new IntPtr(-2)) != IntPtr.Zero;
    }
    public static string ReadThreadAwareness() {
        IntPtr context = GetThreadDpiAwarenessContext();
        if (context == IntPtr.Zero) return "Unavailable";
        switch (GetAwarenessFromDpiAwarenessContext(context)) {
            case 0: return "Unaware";
            case 1: return "SystemAware";
            case 2: return "PerMonitorAware";
            default: return "Unavailable";
        }
    }
    public static int ReadSystemDpi() { return checked((int)GetDpiForSystem()); }
}
'@ -ErrorAction Stop
    }
    $enabled = $false
    try { $enabled = [LenovoUiDpiAwarenessNative]::MakeSystemAware() }
    catch [System.EntryPointNotFoundException] { }
    catch [System.DllNotFoundException] { }
    $awareness = 'Unavailable'
    try { $awareness = [LenovoUiDpiAwarenessNative]::ReadThreadAwareness() } catch { }
    return [pscustomobject]@{
        Success = [bool]($enabled -and $awareness -eq 'SystemAware')
        Awareness = [string]$awareness
    }
}

# The layout units depend on CURRENT thread DPI awareness, not just the
# target monitor's physical scale. SystemAware windows use system-DPI
# coordinates even on a secondary screen; Windows maps them to that screen.
function Resolve-LenovoDpiCoordinateScale {
    param(
        [Parameter(Mandatory=$true)][string]$Awareness,
        [Parameter(Mandatory=$true)][double]$SystemDpi,
        [Parameter(Mandatory=$true)][double]$MonitorScale
    )
    if ($SystemDpi -lt 96 -or $SystemDpi -gt 480) { throw 'System DPI outside supported range.' }
    if ($MonitorScale -lt 1 -or $MonitorScale -gt 5) { throw 'Monitor scale outside supported range.' }
    switch ($Awareness) {
        'Unaware' { return [double]1.0 }
        'SystemAware' { return [double]($SystemDpi / 96.0) }
        'PerMonitorAware' { return [double]$MonitorScale }
        default { throw "Unsupported UI thread DPI awareness: $Awareness" }
    }
}

function Get-LenovoUiCoordinateScale {
    param([System.Windows.Forms.Screen]$Screen)
    if (-not $Screen) { $Screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    $monitor = Get-PopupMonitorDpiScale -Screen $Screen
    $awareness = [LenovoUiDpiAwarenessNative]::ReadThreadAwareness()
    $systemDpi = 0
    try { $systemDpi = [int][LenovoUiDpiAwarenessNative]::ReadSystemDpi() } catch { }
    if ($systemDpi -lt 96 -or $systemDpi -gt 480) {
        $graphics = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        try { $systemDpi = [int][Math]::Round($graphics.DpiX) }
        finally { $graphics.Dispose() }
    }
    $factor = Resolve-LenovoDpiCoordinateScale -Awareness $awareness -SystemDpi $systemDpi -MonitorScale ([double]$monitor.Factor)
    return [pscustomobject]@{
        Factor = [double]$factor
        Percent = [int][Math]::Round($factor * 100)
        Awareness = [string]$awareness
        SystemDpi = [int]$systemDpi
        MonitorPercent = [int]$monitor.Percent
        Source = ('{0};systemDpi={1};monitor={2}' -f $awareness,$systemDpi,$monitor.Source)
    }
}

# LBS-144: use one WinForms-effective logical coordinate space across
# mixed-DPI monitors. The operating system's reported monitor scale is
# diagnostic metadata, not a second layout multiplier. A previous manual
# 2.5x Form.Scale caused tiny text, an oversized 1680px client and blocked
# access to the tray icon on the owner's 100%/250% dual-display setup.
function Resolve-PopupDpiScale {
    param([Parameter(Mandatory=$true)][int]$Percent)
    if ($Percent -lt 100 -or $Percent -gt 500) {
        throw 'Monitor scale percent outside supported range.'
    }
    return ([double]$Percent / 100.0)
}

function Get-PopupMonitorDpiScale {
    param([System.Windows.Forms.Screen]$Screen)
    if (-not $Screen) { $Screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    try {
        if (-not ('LenovoPopupScaleNative' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LenovoPopupScaleNative {
    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromPoint(NativePoint pt, uint flags);
    [DllImport("shcore.dll")]
    private static extern int GetScaleFactorForMonitor(IntPtr monitor, out int scale);
    public static int ReadScalePercent(int x, int y) {
        NativePoint point = new NativePoint { X = x, Y = y };
        IntPtr monitor = MonitorFromPoint(point, 2);
        if (monitor == IntPtr.Zero) { return 0; }
        int percent;
        if (GetScaleFactorForMonitor(monitor, out percent) != 0) { return 0; }
        return percent;
    }
}
'@ -ErrorAction Stop
        }
        if ($Screen) {
            $bounds = $Screen.Bounds
            $x = [int]($bounds.Left + [Math]::Floor($bounds.Width / 2))
            $y = [int]($bounds.Top + [Math]::Floor($bounds.Height / 2))
            $percent = [LenovoPopupScaleNative]::ReadScalePercent($x, $y)
            if ($percent -ge 100 -and $percent -le 500) {
                return [pscustomobject]@{
                    Factor = (Resolve-PopupDpiScale -Percent $percent)
                    Source = 'GetScaleFactorForMonitor'
                    Percent = $percent
                }
            }
        }
    }
    catch { }
    # Keep an independent read-only fallback for nonstandard native contexts.
    try {
        $graphics = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        try {
            $dpiX = [double]$graphics.DpiX
            if ($dpiX -ge 96 -and $dpiX -le 480) {
                $percent = [int][Math]::Round(100 * $dpiX / 96)
                return [pscustomobject]@{ Factor = (Resolve-PopupDpiScale -Percent $percent); Source = 'graphics-dpi'; Percent = $percent }
            }
        }
        finally { $graphics.Dispose() }
    }
    catch { }
    return [pscustomobject]@{ Factor = 1.0; Source = 'unavailable'; Percent = 100 }
}

# Materialize the invisible popup HWND only after the UI thread's DPI
# awareness has been fixed. Handle creation alone cannot change awareness.
function Initialize-LenovoTrayDpiContext {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Popup)
    if ($Popup.IsDisposed) { throw 'Cannot initialize DPI context for a disposed popup.' }
    if (-not $Popup.IsHandleCreated) { [void]$Popup.Handle }
}

# LBS-144 physical Windows captures: the WinForms popup remained 390x672
# pixels with window DPI 240 (laptop-primary) and 96 (external-primary).
# PowerShell/WinForms owns a SystemAware HWND, not a PMv2 HWND.
# Keep one 96-DPI design baseline; scale pixel control bounds from immutable
# design metrics, but preserve point-unit Font.Size. Windows/GDI converts
# points to physical pixels using window DPI; multiplying points also would
# double-scale glyphs and clip the text at 240 DPI.
function Initialize-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.SuspendLayout()
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $Form.Tag = [double]1.0
    # A new popup starts a new design snapshot; dynamically rebuilt rows are
    # scaled from their own fresh 96-DPI builder values, not cached here.
    $script:PopupDesignMetrics = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.Control,System.Object]'
}

function Save-PopupControlDesignMetrics {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control)
    if (-not $script:PopupDesignMetrics.ContainsKey($Control)) {
        $font = $Control.Font
        $script:PopupDesignMetrics.Add($Control, [pscustomobject]@{
            Bounds = $Control.Bounds
            ClientSize = $Control.ClientSize
            Padding = $Control.Padding
            Margin = $Control.Margin
            FontFamily = $font.FontFamily
            FontSize = [single]$font.Size
            FontStyle = $font.Style
            FontUnit = $font.Unit
        })
    }
    foreach ($child in $Control.Controls) {
        Save-PopupControlDesignMetrics -Control $child
    }
}

function Set-PopupControlPhysicalScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][bool]$UseStoredBaseline
    )
    if ($UseStoredBaseline) {
        $base = $script:PopupDesignMetrics[$Control]
        if ($null -eq $base) { throw 'Missing popup design baseline.' }
    }
    else {
        # A boot row is created at design size just before this single call.
        $font = $Control.Font
        $base = [pscustomobject]@{
            Bounds = $Control.Bounds
            ClientSize = $Control.ClientSize
            Padding = $Control.Padding
            Margin = $Control.Margin
            FontFamily = $font.FontFamily
            FontSize = [single]$font.Size
            FontStyle = $font.Style
            FontUnit = $font.Unit
        }
    }
    $rect = [Drawing.Rectangle]::new(
        [int][Math]::Round($base.Bounds.X * $Scale),
        [int][Math]::Round($base.Bounds.Y * $Scale),
        [Math]::Max(1,[int][Math]::Round($base.Bounds.Width * $Scale)),
        [Math]::Max(1,[int][Math]::Round($base.Bounds.Height * $Scale)))
    $Control.SuspendLayout()
    try {
        if ($Control -is [System.Windows.Forms.Form]) {
            $Control.ClientSize = [Drawing.Size]::new(
                [Math]::Max(1,[int][Math]::Round($base.ClientSize.Width * $Scale)),
                [Math]::Max(1,[int][Math]::Round($base.ClientSize.Height * $Scale)))
        }
        else {
            $Control.Bounds = $rect
        }
        $Control.Padding = [System.Windows.Forms.Padding]::new(
            [int][Math]::Round($base.Padding.Left * $Scale),
            [int][Math]::Round($base.Padding.Top * $Scale),
            [int][Math]::Round($base.Padding.Right * $Scale),
            [int][Math]::Round($base.Padding.Bottom * $Scale))
        $Control.Margin = [System.Windows.Forms.Padding]::new(
            [int][Math]::Round($base.Margin.Left * $Scale),
            [int][Math]::Round($base.Margin.Top * $Scale),
            [int][Math]::Round($base.Margin.Right * $Scale),
            [int][Math]::Round($base.Margin.Bottom * $Scale))
        # Font.Size is a typographic point unit. Rendering already converts
        # it to DPI-relative pixel height; NEVER multiply by monitor scale.
        $Control.Font = [Drawing.Font]::new(
            $base.FontFamily,[single]$base.FontSize,
            [Drawing.FontStyle]$base.FontStyle,[Drawing.GraphicsUnit]$base.FontUnit)
        foreach ($child in $Control.Controls) {
            Set-PopupControlPhysicalScale -Control $child -Scale $Scale -UseStoredBaseline $UseStoredBaseline
        }
    }
    finally { $Control.ResumeLayout($true) }
}

function Set-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid popup monitor scale.' }
    $previous = [double]$Form.Tag
    if ($previous -le 0) { $previous = 1.0 }
    Save-PopupControlDesignMetrics -Control $Form
    if ([Math]::Abs($Scale - $previous) -lt 0.001) { return $false }
    Set-PopupControlPhysicalScale -Control $Form -Scale $Scale -UseStoredBaseline $true
    $Form.Tag = [double]$Scale
    return $true
}

function Complete-PopupDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [double]$Scale = 1.0
    )
    try { [void](Set-PopupDpiLayoutScale -Form $Form -Scale $Scale) }
    finally { $Form.ResumeLayout($true) }
}

# Work-area coordinates and Form.ClientSize are physical in the observed
# SystemAware LBS process. Clip to the *target* screen and expose scrolling.
function Set-PopupViewportForWorkingArea {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea
    )
    $scale = [double]$Form.Tag
    if ($scale -le 0) { $scale = 1.0 }
    $designWidth = [int][Math]::Round(390 * $scale)
    $designHeight = [int][Math]::Round(672 * $scale)
    $availableWidth = [Math]::Max(200, $WorkingArea.Width - 12)
    $availableHeight = [Math]::Max(200, $WorkingArea.Height - 12)
    $wantedWidth = [Math]::Min($designWidth, $availableWidth)
    $wantedHeight = [Math]::Min($designHeight, $availableHeight)
    $changed = ($Form.ClientSize.Width -ne $wantedWidth -or $Form.ClientSize.Height -ne $wantedHeight)
    $root = $Form.Controls['PopupRoot']
    $Form.SuspendLayout()
    try {
        if ($root) {
            $root.SuspendLayout()
            try {
                if ($wantedHeight -lt $designHeight -or $wantedWidth -lt $designWidth) {
                    $root.AutoScroll = $true
                    $root.AutoScrollMinSize = [Drawing.Size]::new($designWidth, $designHeight)
                }
                else {
                    $root.AutoScrollMinSize = [Drawing.Size]::Empty
                    $root.AutoScroll = $false
                }
            }
            finally { $root.ResumeLayout($true) }
        }
        $Form.ClientSize = [Drawing.Size]::new($wantedWidth, $wantedHeight)
        if ($root) { $root.Size = $Form.ClientSize }
    }
    finally { $Form.ResumeLayout($true) }
    return $changed
}

function Get-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Popup,
        [int]$DesignWidth = 390
    )
    if ($DesignWidth -le 0 -or $Popup.ClientSize.Width -le 0) {
        throw 'Popup layout width is not available.'
    }
    return [double]$Popup.Tag
}

function Set-PopupBootRowDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Row,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][int]$Y
    )
    if ($Scale -le 0 -or $Scale -gt 5) { throw 'Invalid popup DPI scale.' }
    if ([Math]::Abs($Scale - 1.0) -gt 0.0001) {
        Set-PopupControlPhysicalScale -Control $Row -Scale $Scale -UseStoredBaseline $false
    }
    $Row.Location = [Drawing.Point]::new(0, $Y)
    return [int]$Row.Height
}

function Write-PopupDpiLayoutDiagnostic {
    param(
        [System.Windows.Forms.Form]$Form,
        [string]$Phase,
        [string]$MonitorSource = ''
    )
    if (-not $Form -or $Form.IsDisposed) { return }
    try {
        $h = $Form.Controls.Find('HeaderTitleLabel', $true)
        $t = $Form.Controls.Find('BootTitleLabel', $true)
        $s = $Form.Controls.Find('BootSubtitleLabel', $true)
        $header = if ($h.Count -gt 0) { $h[0] } else { $null }
        $title = if ($t.Count -gt 0) { $t[0] } else { $null }
        $subtitle = if ($s.Count -gt 0) { $s[0] } else { $null }
        $data = @{
            phase = $Phase
            appliedScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
            reportedMonitorScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
            layoutCoordinateSpace = 'system-aware-physical-design-scaled'
            formClientOuterHeightDelta = [int]($Form.ClientSize.Height - $Form.Height)
            monitorScaleSource = $MonitorSource
            formWidth = [int]$Form.Width
            formHeight = [int]$Form.Height
            clientWidth = [int]$Form.ClientSize.Width
            clientHeight = [int]$Form.ClientSize.Height
            autoscaleMode = [string]$Form.AutoScaleMode
            headerLabelHeight = if ($header) { [int]$header.Height } else { 0 }
            headerFontHeight = if ($header) { [int]$header.Font.Height } else { 0 }
            bootTitleLabelHeight = if ($title) { [int]$title.Height } else { 0 }
            bootTitleFontHeight = if ($title) { [int]$title.Font.Height } else { 0 }
            bootSubtitleLabelHeight = if ($subtitle) { [int]$subtitle.Height } else { 0 }
            bootSubtitleFontHeight = if ($subtitle) { [int]$subtitle.Font.Height } else { 0 }
        }
        Write-RuntimeDiagnosticEvent -Event 'POPUP_DPI_LAYOUT' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData $data)
    }
    catch { }
}

# Lenovo Boot Selector - boot-entry row presentation helpers.
# LBS-29 separates row rendering and interaction responsibilities from list refresh orchestration.


# LBS-163: shared candidate resolver for preview and committed drop.
function Get-ManageDropDecision {
    param($Control,[Drawing.Point]$ScreenPoint,[string]$MovedGuid)
    if (-not $script:IsManageEntriesMode -or -not $MovedGuid) { return $null }
    $moved = $MovedGuid.ToLowerInvariant()
    $order = @($script:ManageEntryOrder | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $originalIndex = [array]::IndexOf($order,$moved)
    if ($originalIndex -lt 0) { return $null }

    $target = ''
    $after = $false
    # During live reflow the physical rows move. Resolve pointer coordinates
    # against immutable drag-start slots, never against their animated bounds.
    if ($script:ManageDragLayout -and $script:ManageDragContent -and -not $script:ManageDragContent.IsDisposed) {
        $point = $script:ManageDragContent.PointToClient($ScreenPoint)
        $slots = @($script:ManageDragLayout)
        if ($slots.Count -eq 0 -or $point.X -lt 0 -or $point.X -ge $script:ManageDragContent.ClientSize.Width) { return $null }
        if ($point.Y -lt $slots[0].Top -or $point.Y -ge ($slots[$slots.Count-1].Top + $slots[$slots.Count-1].Height)) { return $null }
        foreach ($slot in $slots) {
            $edge = $slot.Top + $slot.Height + [Math]::Floor($script:ManageDragRowGap / 2.0)
            if ($point.Y -lt $edge) {
                $target = $slot.Guid
                $after = ($point.Y -gt ($slot.Top + $slot.Height / 2.0))
                break
            }
        }
        if (-not $target) {
            $target = $slots[$slots.Count-1].Guid
            $after = $true
        }
    }
    else {
        $row = Get-BootRowFromControl $Control
        if (-not $row -or $row.IsDisposed -or -not $row.Parent -or $row.Parent.Name -ne 'EntryContent') { return $null }
        $point = $row.PointToClient($ScreenPoint)
        if ($point.X -lt 0 -or $point.X -ge $row.Width -or $point.Y -lt 0 -or $point.Y -ge $row.Height) { return $null }
        $target = ([string]$row.Tag).ToLowerInvariant()
        $after = ($point.Y -gt ($row.Height / 2.0))
    }
    $remaining = @($order | Where-Object { $_ -ne $moved })
    $targetIndex = [array]::IndexOf($remaining,$target)
    if (-not $target -or $target -eq $moved -or $targetIndex -lt 0) { return $null }
    $index = $targetIndex + $(if ($after) { 1 } else { 0 })
    if ($index -eq $originalIndex) { return $null }
    return [pscustomobject]@{ MovedGuid=$moved; TargetGuid=$target; After=[bool]$after; InsertIndex=[int]$index }
}
# LBS-163 iteration 2: animate existing WinForms rows; no rows are rebuilt in a drag.
# Slots are captured once, so the pointer decision never depends on animation frames.
# Paint each drag row into one frozen surface before the OLE drag begins.
# Avoid repeatedly painting nested eye, pencil, grip and text HWNDs in flight.
function New-ManageDragRowRaster {
    param($Row)
    if (-not $Row -or $Row.IsDisposed -or $Row.Width -le 0 -or $Row.Height -le 0) {
        throw [System.InvalidOperationException]::new('Drag row has no drawable surface.')
    }
    $Row.Refresh()
    $bitmap = [Drawing.Bitmap]::new([int]$Row.Width,[int]$Row.Height)
    try {
        $Row.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$Row.Width,$Row.Height))
        return $bitmap
    }
    catch {
        $bitmap.Dispose()
        throw
    }
}

# LBS-172: one actual HWND paints the dragged source, every cached neighbor,
# its destination gap and short shadow in ONE optimized buffered WM_PAINT.
# Snapshot PictureBoxes/Panels are detached state holders, not child HWNDs.
function Initialize-ManageDragBufferedCanvas {
    if ('LenovoDragBufferedCanvas' -as [type]) { return }
    $canvasSource = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public sealed class LenovoDragBufferedCanvas : Control
{
    private readonly List<PictureBox> neighbors = new List<PictureBox>();
    public PictureBox Ghost { get; set; }
    public Panel Shadow { get; set; }
    public Panel Placeholder { get; set; }

    public LenovoDragBufferedCanvas()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        DoubleBuffered = true;
        UpdateStyles();
        TabStop = false;
        Enabled = false;
    }

    public bool HasOptimizedPaintStyles
    {
        get {
            return GetStyle(ControlStyles.UserPaint) &&
                   GetStyle(ControlStyles.AllPaintingInWmPaint) &&
                   GetStyle(ControlStyles.OptimizedDoubleBuffer);
        }
    }

    public void AddNeighbor(PictureBox visual)
    {
        if (visual == null || visual.Parent != null || visual.IsHandleCreated)
            throw new InvalidOperationException("Raster state cannot own child HWNDs.");
        neighbors.Add(visual);
    }

    protected override void OnPaintBackground(PaintEventArgs e) { }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor); // Clear inside the same back-buffer transaction.

        if (Placeholder != null && Placeholder.Visible)
        {
            Rectangle r = Placeholder.Bounds;
            using (Brush b = new SolidBrush(Placeholder.BackColor))
                g.FillRectangle(b, r);
            using (Pen p = new Pen(Color.FromArgb(83, 88, 98), 1.0f))
            {
                p.DashStyle = DashStyle.Dash;
                g.DrawRectangle(p, r.Left + 1, r.Top + 1,
                    Math.Max(1, r.Width - 3), Math.Max(1, r.Height - 3));
            }
        }

        foreach (PictureBox row in neighbors)
        {
            if (row != null && row.Visible && row.Image != null)
                g.DrawImageUnscaled(row.Image, row.Left, row.Top);
        }

        if (Shadow != null && Shadow.Visible)
        {
            using (Brush b = new SolidBrush(Shadow.BackColor))
                g.FillRectangle(b, Shadow.Bounds);
        }

        if (Ghost != null && Ghost.Visible && Ghost.Image != null)
            g.DrawImageUnscaled(Ghost.Image, Ghost.Left, Ghost.Top);
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $canvasSource -ErrorAction Stop
}

function Start-ManageDragReflow {
    param($SourceRow)
    if (-not $SourceRow -or -not $SourceRow.Parent -or -not $script:IsManageEntriesMode) { return }
    Stop-ManageDragReflow
    $content = $SourceRow.Parent
    $rows = @($content.Controls | Where-Object { $_.Name -eq 'BootRow' } | Sort-Object Top)
    $slots = @()
    foreach ($row in $rows) {
        $slots += [pscustomobject]@{
            Guid=([string]$row.Tag).ToLowerInvariant()
            Row=$row
            Top=[int]$row.Top
            Height=[int]$row.Height
        }
    }
    if ($slots.Count -lt 2) { return }
    $script:ManageDragContent = $content
    $script:ManageDragLayout = $slots
    $script:ManageDragRowGap = [Math]::Max(0,$slots[1].Top - ($slots[0].Top+$slots[0].Height))
    $script:ManageDragRow = $SourceRow
    $script:ManageDragOriginalColor = $SourceRow.BackColor
    $script:ManageDragGhost = $null
    $script:ManageDragGhostImage = $null
    $script:ManageDragCanvas = $null
    $script:ManageDragVisualActive = $false
    $script:ManageDragCaptureCount = 0
    $script:ManageDragCaptureErrorClass = ''
    $script:ManageDragNeighborVisuals = @{}
    $script:ManageDragNeighborImages = @()
    $script:ManageDragNeighborCaptureCount = 0
    $script:ManageDragRetargetPending = $false
    $script:ManageDragQueuedDecision = $null
    $script:ManageDragRetargetCount = 0
    $script:ManageDragSupersededCount = 0
    $script:ManageDragNeighborMoves = 0

    $grab = $SourceRow.PointToClient([System.Windows.Forms.Control]::MousePosition)
    $script:ManageDragGrabY = [Math]::Max(0,[Math]::Min($SourceRow.Height-1,$grab.Y))

    # LBS-172: DrawToBitmap captures the complete row once, including the
    # independently painted pencil, eye, grip and text labels. Only a single
    # image HWND follows the mouse; the real source row/handlers stay parked.
    # Keep the source visible until OLE DoDragDrop has started.
    $bitmap = $null
    $ghost = $null
    try {
        $bitmap = New-ManageDragRowRaster -Row $SourceRow
        $ghost = New-Object System.Windows.Forms.PictureBox
        $ghost.Name = 'ManageDragGhost'
        $ghost.Location = $SourceRow.Location
        $ghost.Size = $SourceRow.Size
        $ghost.Image = $bitmap
        $ghost.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
        $ghost.BackColor = $SourceRow.BackColor
        $ghost.Enabled = $false # Let OLE hit testing reach the drop-enabled content.
        $ghost.Visible = $false
        # Detached state: the real painter is the shared buffered canvas.
        $script:ManageDragGhost = $ghost
        $script:ManageDragGhostImage = $bitmap
        $script:ManageDragCaptureCount = 1

        # One bitmap presentation per neighbor. Actual child HWNDs are only
        # parked during the active drag; the underlying rows stay intact.
        foreach ($slot in $slots) {
            if ($slot.Guid -eq $script:ManageActiveDragGuid) { continue }
            $neighborBitmap = New-ManageDragRowRaster -Row $slot.Row
            $script:ManageDragNeighborImages += $neighborBitmap
            $picture = New-Object System.Windows.Forms.PictureBox
            $script:ManageDragNeighborVisuals[$slot.Guid] = $picture
            $picture.Name = 'ManageDragNeighbor'
            $picture.Tag = $slot.Guid
            $picture.Location = $slot.Row.Location
            $picture.Size = $slot.Row.Size
            $picture.Image = $neighborBitmap
            $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
            $picture.BackColor = $slot.Row.BackColor
            $picture.Enabled = $false
            $picture.Visible = $false
            $script:ManageDragNeighborCaptureCount++
        }

        Initialize-ManageDragBufferedCanvas
        $canvas = New-Object LenovoDragBufferedCanvas
        $canvas.Name = 'ManageDragCanvas'
        $canvas.BackColor = $content.BackColor
        $canvas.Location = [Drawing.Point]::Empty
        $canvas.Size = $content.ClientSize
        $canvas.Dock = [System.Windows.Forms.DockStyle]::Fill
        $canvas.Ghost = $ghost
        foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
            $canvas.AddNeighbor($picture)
        }
        $canvas.Visible = $false
        $content.Controls.Add($canvas)
        $script:ManageDragCanvas = $canvas
    }
    catch {
        # A failing optional WinForms snapshot must never abort a reorder.
        # Fall back to the existing live-row movement and retain diagnostic
        # evidence; do not suppress the source drag or invent a success.
        $script:ManageDragCaptureErrorClass = $_.Exception.GetType().FullName
        # All-or-nothing setup. A failed visual capture leaves the original
        # safe live-row drag behavior available, never a partial raster layer.
        if ($script:ManageDragCanvas) {
            if ($script:ManageDragCanvas.Parent) {
                $script:ManageDragCanvas.Parent.Controls.Remove($script:ManageDragCanvas)
            }
            $script:ManageDragCanvas.Dispose()
            $script:ManageDragCanvas = $null
        }
        elseif ($canvas) {
            if ($canvas.Parent) { $canvas.Parent.Controls.Remove($canvas) }
            $canvas.Dispose()
        }
        if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
            foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
                if ($picture -and -not $picture.IsDisposed) {
                    if ($picture.Parent) { $picture.Parent.Controls.Remove($picture) }
                    $picture.Image = $null
                    $picture.Dispose()
                }
            }
        }
        foreach ($neighborBitmap in @($script:ManageDragNeighborImages)) {
            if ($neighborBitmap) { $neighborBitmap.Dispose() }
        }
        $script:ManageDragNeighborVisuals = $null
        $script:ManageDragNeighborImages = $null
        $script:ManageDragNeighborCaptureCount = 0
        if ($ghost) {
            if ($ghost.Parent) { $ghost.Parent.Controls.Remove($ghost) }
            $ghost.Image = $null
            $ghost.Dispose()
        }
        if ($bitmap) { $bitmap.Dispose() }
        $script:ManageDragGhost = $null
        $script:ManageDragGhostImage = $null
    }

    $shadow = New-Object System.Windows.Forms.Panel
    $shadow.Name = 'ManageDragShadow'
    # A thin trailing edge avoids the old full-height opaque dark rectangle.
    $shadow.Size = [Drawing.Size]::new([Math]::Max(1,$SourceRow.Width-8),[Math]::Max(3,[int][Math]::Round($SourceRow.Height*0.08)))
    $shadow.BackColor = [Drawing.Color]::FromArgb(12,12,16)
    $shadow.Enabled = $false
    $shadow.Visible = $false
    if (-not $script:ManageDragCanvas) { $content.Controls.Add($shadow) }
    $script:ManageDragShadow = $shadow
    if ($script:ManageDragCanvas) { $script:ManageDragCanvas.Shadow = $shadow }
    $placeholder = New-Object System.Windows.Forms.Panel
    $placeholder.Name = 'ManageDragPlaceholder'
    $placeholder.Size = $SourceRow.Size
    $placeholder.BackColor = [Drawing.Color]::FromArgb(34,36,41)
    $placeholder.Enabled = $false
    $placeholder.Visible = $false
    if (-not $script:ManageDragCanvas) { $placeholder.Add_Paint({
        param($sender,$eventArgs)
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(83,88,98),1.0)
        $pen.DashStyle = [Drawing.Drawing2D.DashStyle]::Dash
        try { $eventArgs.Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$sender.Width-3),[Math]::Max(1,$sender.Height-3)) }
        finally { $pen.Dispose() }
    }) }
    if (-not $script:ManageDragCanvas) {
        $content.Controls.Add($placeholder)
        $placeholder.SendToBack()
        $shadow.BringToFront()
    }
    $script:ManageDragPlaceholder = $placeholder
    if ($script:ManageDragCanvas) {
        $script:ManageDragCanvas.Placeholder = $placeholder
    }
    elseif ($script:ManageDragGhost) {
        $script:ManageDragGhost.BringToFront()
    }
    else {
        $SourceRow.BringToFront()
        $SourceRow.BackColor = [Drawing.Color]::FromArgb(48,48,54)
        $SourceRow.Invalidate($true)
        $shadow.Visible = $true
    }

    $script:ManageDragTargets = @{}
    $script:ManageDragStarts = @{}
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $timer.Add_Tick({ Advance-ManageDragReflow })
    $script:ManageDragTimer = $timer
    Set-ManageDragReflowTargets -Decision $null
    # Initial mapping is not a pointer-target change.
    $script:ManageDragRetargetCount = 0
    Set-ManageDragFloatLocation -ScreenPoint ([System.Windows.Forms.Control]::MousePosition)
}

function Set-ManageDragFloatLocation {
    param([Drawing.Point]$ScreenPoint,[switch]$ActivateVisual)
    if (-not $script:ManageDragRow -or $script:ManageDragRow.IsDisposed -or
        -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    $point = $script:ManageDragContent.PointToClient($ScreenPoint)
    $y = [int]($point.Y - $script:ManageDragGrabY)
    if ($script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed) {
        if ($ActivateVisual -and -not $script:ManageDragVisualActive) {
            # The OLE drag is now active: park the real nested HWND hierarchy
            # and reveal only the cached single-surface visual. A visible
            # dashed placeholder occupies the original slot even on no-op
            # and invalid destinations, avoiding a transient black hole.
            $script:ManageDragVisualActive = $true
            $script:ManageDragRow.Visible = $false
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                foreach ($slot in @($script:ManageDragLayout)) {
                    if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
                    $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                    if ($picture -and -not $picture.IsDisposed) {
                        $slot.Row.Visible = $false
                        $picture.Visible = $true
                    }
                }
            }
            if ($script:ManageDragPlaceholder -and -not $script:ManageDragPlaceholder.IsDisposed) {
                $script:ManageDragPlaceholder.Visible = $true
            }
            if ($script:ManageDragShadow -and -not $script:ManageDragShadow.IsDisposed) {
                $script:ManageDragShadow.Visible = $true
            }
            $script:ManageDragGhost.Visible = $true
            if ($script:ManageDragCanvas) {
                $script:ManageDragCanvas.Visible = $true
                $script:ManageDragCanvas.BringToFront()
            }
            else { $script:ManageDragGhost.BringToFront() }
        }
        if ($script:ManageDragGhost.Top -ne $y) { $script:ManageDragGhost.Top = $y }
    }
    elseif ($script:ManageDragRow.Top -ne $y) {
        # Read-only bitmap capture failed: retain the original drag behavior.
        $script:ManageDragRow.Top = $y
    }
    if ($script:ManageDragShadow -and -not $script:ManageDragShadow.IsDisposed) {
        $left = $script:ManageDragRow.Left + 4
        $shadowY = $y + $script:ManageDragRow.Height - [int][Math]::Floor($script:ManageDragShadow.Height/2.0)
        if ($script:ManageDragShadow.Left -ne $left -or $script:ManageDragShadow.Top -ne $shadowY) {
            $script:ManageDragShadow.Location = [Drawing.Point]::new($left,$shadowY)
        }
    }
    # The WinForms paint queue coalesces this into one buffered raster frame.
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) {
        $script:ManageDragCanvas.Invalidate()
    }
}

function Set-ManageDragReflowTargets {
    param($Decision)
    if (-not $script:ManageDragLayout) { return }
    $slots = @($script:ManageDragLayout)
    $moved = ([string]$script:ManageActiveDragGuid).ToLowerInvariant()
    $sequence = New-Object System.Collections.ArrayList
    $byGuid = @{}
    foreach ($slot in $slots) {
        $byGuid[$slot.Guid] = $slot
        if ($slot.Guid -ne $moved) { [void]$sequence.Add($slot.Guid) }
    }
    if ($Decision) {
        $index = [Math]::Max(0,[Math]::Min($sequence.Count,[int]$Decision.InsertIndex))
        $sequence.Insert($index,$moved)
    }
    else {
        $original = [array]::IndexOf(@($slots | ForEach-Object { $_.Guid }),$moved)
        $sequence.Insert([Math]::Max(0,$original),$moved)
    }
    $targets = @{}
    $y = [int]$slots[0].Top
    foreach ($guid in $sequence) {
        $slot = $byGuid[$guid]
        $targets[$guid] = $y
        $y += $slot.Height + $script:ManageDragRowGap
    }
    $script:ManageDragStarts = @{}
    $needsMotion = $false
    foreach ($slot in $slots) {
        if ($slot.Guid -ne $moved -and -not $slot.Row.IsDisposed) {
            # The raster, not the parked native row, owns the visible position.
            # On a mid-flight reversal, start from the actual picture position
            # instead of snapping to the original hidden HWND's static slot.
            $surface = $slot.Row
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                if ($picture -and -not $picture.IsDisposed) { $surface = $picture }
            }
            $script:ManageDragStarts[$slot.Guid] = [int]$surface.Top
            if ([int]$surface.Top -ne [int]$targets[$slot.Guid]) { $needsMotion = $true }
        }
    }
    $script:ManageDragTargets = $targets
    $script:ManageDragRetargetCount++
    if ($script:ManageDragPlaceholder -and -not $script:ManageDragPlaceholder.IsDisposed) {
        $script:ManageDragPlaceholder.Top = [int]$targets[$moved]
        # Once the source is parked, keep its destination represented even
        # if the pointer temporarily produces a no-op or invalid candidate.
        $script:ManageDragPlaceholder.Visible = ([bool]$script:ManageDragVisualActive -or $null -ne $Decision)
    }
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) { $script:ManageDragCanvas.Invalidate() }
    $script:ManageDragAnimationStartUtc = [datetime]::UtcNow
    if ($script:ManageDragTimer) {
        if ($needsMotion) { $script:ManageDragTimer.Start() }
        else { $script:ManageDragTimer.Stop() }
    }
}

function Advance-ManageDragReflow {
    param([double]$Progress = -1)
    if (-not $script:ManageDragLayout -or -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    if ($script:ManageDragRetargetPending) {
        # Apply the *last* decision once per 16ms UI timer frame, not every
        # DragOver message. This bounds raster moves on rapid reversals.
        $decision = $script:ManageDragQueuedDecision
        $script:ManageDragRetargetPending = $false
        $script:ManageDragQueuedDecision = $null
        Set-ManageDragReflowTargets -Decision $decision
    }
    # LBS-172 V7 A/B: keep the 16ms timer only as a DragOver target
    # coalescing boundary. With cached row pictures, place neighbors at
    # their exact new slots in one callback instead of creating 150ms of
    # intermediate native PictureBox window moves. The moving source ghost
    # and immutable drop-hit slots are unchanged. If capture failed, use
    # the previous eased live-row fallback rather than altering semantics.
    $instantRasterReflow = ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary] -and
                            $script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed)
    $t = if ($instantRasterReflow) { 1.0 }
         elseif ($Progress -ge 0) { [Math]::Min(1.0,[Math]::Max(0.0,$Progress)) }
         else { [Math]::Min(1.0,([datetime]::UtcNow-$script:ManageDragAnimationStartUtc).TotalMilliseconds/150.0) }
    $ease = 1.0 - [Math]::Pow(1.0-$t,3.0)
    $script:ManageDragContent.SuspendLayout()
    try {
        foreach ($slot in @($script:ManageDragLayout)) {
            if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
            $start = [int]$script:ManageDragStarts[$slot.Guid]
            $target = [int]$script:ManageDragTargets[$slot.Guid]
            $top = [int][Math]::Round($start + (($target-$start)*$ease))
            # Move exactly one presentation surface per frame. With a cached
            # raster, the real multi-child row must remain at its immutable
            # slot and never generate native HWND move/invalidation traffic.
            # If capture failed, retain the original live-row fallback.
            $surface = $slot.Row
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                if ($picture -and -not $picture.IsDisposed) { $surface = $picture }
            }
            if ($surface.Top -ne $top) {
                $surface.Top = $top
                $script:ManageDragNeighborMoves++
            }
        }
    }
    finally { $script:ManageDragContent.ResumeLayout($false) }
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) { $script:ManageDragCanvas.Invalidate() }
    if ($t -ge 1.0 -and $script:ManageDragTimer) { $script:ManageDragTimer.Stop() }
}

function Stop-ManageDragReflow {
    param([switch]$KeepPositions)
    $content = $script:ManageDragContent
    $hadSession = [bool]$script:ManageDragLayout
    if ($script:ManageDragTimer) {
        $script:ManageDragTimer.Stop()
        $script:ManageDragTimer.Dispose()
        $script:ManageDragTimer = $null
    }
    if ($content -and -not $content.IsDisposed) { $content.SuspendLayout() }
    try {
        if ($script:ManageDragLayout) {
            $moved = ([string]$script:ManageActiveDragGuid).ToLowerInvariant()
            foreach ($slot in @($script:ManageDragLayout)) {
                if ($slot.Row.IsDisposed) { continue }
                $destination = [int]$slot.Top
                if ($KeepPositions -and $script:ManageDragTargets -and
                    $script:ManageDragTargets.ContainsKey($slot.Guid)) {
                    $destination = [int]$script:ManageDragTargets[$slot.Guid]
                }
                if ($slot.Guid -eq $moved) {
                    # Restore the source once, behind the cached ghost, before
                    # its original nested child HWNDs become visible again.
                    $slot.Row.Top = $destination
                }
                elseif ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary] -and
                        $script:ManageDragNeighborVisuals.ContainsKey($slot.Guid)) {
                    # Cached neighbors remained fixed through every timer
                    # frame. Make one final hidden HWND handoff at the exact
                    # committed/invalid destination before restoring visibility.
                    $slot.Row.Top = $destination
                }
                elseif (-not $KeepPositions) {
                    # Existing live-row fallback: restore after cancel only.
                    $slot.Row.Top = $destination
                }
            }
        }
        if ($script:ManageDragRow -and -not $script:ManageDragRow.IsDisposed) {
            $script:ManageDragRow.BackColor = $script:ManageDragOriginalColor
            if ($script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed) {
                $script:ManageDragRow.Visible = $true
                # One synchronous final paint under the picture, not
                # separate pencil/eye/reorder repaints on each drag frame.
                $script:ManageDragRow.Refresh()
            }
            else { $script:ManageDragRow.Invalidate($true) }
        }
        # Restore native rows at the final slot and synchronously paint them
        # under the cached pictures, then dispose every transient surface.
        if ($script:ManageDragVisualActive -and $script:ManageDragNeighborVisuals) {
            foreach ($slot in @($script:ManageDragLayout)) {
                if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
                $slot.Row.Visible = $true
                $slot.Row.Refresh()
            }
        }
        # Remove the single buffered native HWND before releasing any cached
        # bitmap; detached PictureBoxes and panels never owned child HWNDs.
        if ($script:ManageDragCanvas) {
            if ($script:ManageDragCanvas.Parent) {
                $script:ManageDragCanvas.Parent.Controls.Remove($script:ManageDragCanvas)
            }
            $script:ManageDragCanvas.Dispose()
            $script:ManageDragCanvas = $null
        }
        if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
            foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
                if ($picture -and -not $picture.IsDisposed) {
                    if ($picture.Parent) { $picture.Parent.Controls.Remove($picture) }
                    $picture.Image = $null
                    $picture.Dispose()
                }
            }
        }
        foreach ($neighborBitmap in @($script:ManageDragNeighborImages)) {
            if ($neighborBitmap) { $neighborBitmap.Dispose() }
        }
        foreach ($visual in @($script:ManageDragGhost,$script:ManageDragShadow,$script:ManageDragPlaceholder)) {
            if ($visual -and -not $visual.IsDisposed) {
                if ($visual.Parent) { $visual.Parent.Controls.Remove($visual) }
                if ($visual -is [System.Windows.Forms.PictureBox]) { $visual.Image = $null }
                $visual.Dispose()
            }
        }
        if ($script:ManageDragGhostImage) { $script:ManageDragGhostImage.Dispose() }
    }
    finally {
        if ($content -and -not $content.IsDisposed) { $content.ResumeLayout($false) }
    }

    # One bounded, privacy-preserving diagnostic per completed drag, rather
    # than per mouse movement; no GUID, alias text or target is recorded.
    if ($hadSession -and $script:RuntimeDiagnosticsAvailable) {
        Write-RuntimeDiagnosticEvent -Event 'MANAGE_DRAG_VISUAL' -Stage 'ui' -Success $true -Data (New-RuntimeDiagnosticData @{
            snapshotCaptures = [int]$script:ManageDragCaptureCount
            neighborRasterCaptures = [int]$script:ManageDragNeighborCaptureCount
            fallbackClass = [string]$script:ManageDragCaptureErrorClass
            retargetsApplied = [int]$script:ManageDragRetargetCount
            retargetsSuperseded = [int]$script:ManageDragSupersededCount
            neighborPanelMoves = [int]$script:ManageDragNeighborMoves
            keptPreviewPositions = [bool]$KeepPositions
        })
    }
    $script:ManageDragPlaceholder = $null
    $script:ManageDragShadow = $null
    $script:ManageDragGhost = $null
    $script:ManageDragGhostImage = $null
    $script:ManageDragCanvas = $null
    $script:ManageDragNeighborVisuals = $null
    $script:ManageDragNeighborImages = $null
    $script:ManageDragNeighborCaptureCount = 0
    $script:ManageDragVisualActive = $false
    $script:ManageDragLayout = $null
    $script:ManageDragContent = $null
    $script:ManageDragRow = $null
    $script:ManageDragTargets = $null
    $script:ManageDragStarts = $null
    $script:ManageDragOriginalColor = $null
    $script:ManageDragRowGap = 0
    $script:ManageDragGrabY = 0
    $script:ManageDragRetargetPending = $false
    $script:ManageDragQueuedDecision = $null
    $script:ManageDragCaptureCount = 0
    $script:ManageDragCaptureErrorClass = ''
    $script:ManageDragRetargetCount = 0
    $script:ManageDragSupersededCount = 0
    $script:ManageDragNeighborMoves = 0
}

function Set-ManageDropPreview {
    param($Decision)
    $prior = $script:ManageDropPreview
    if ($prior -and $Decision -and $prior.TargetGuid -eq $Decision.TargetGuid -and $prior.After -eq $Decision.After) { return }
    if (-not $prior -and -not $Decision) { return }
    $script:ManageDropPreview = $Decision
    if ($script:ManageDragLayout) {
        if ($script:ManageDragRetargetPending) { $script:ManageDragSupersededCount++ }
        $script:ManageDragQueuedDecision = $Decision
        $script:ManageDragRetargetPending = $true
        if ($script:ManageDragTimer) { $script:ManageDragTimer.Start() }
        return
    }
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) {
        if (($prior -and [string]$row.Tag -eq $prior.TargetGuid) -or
            ($Decision -and [string]$row.Tag -eq $Decision.TargetGuid)) { $row.Invalidate() }
    }
}
function Reset-ManageDragPreview {
    param([switch]$KeepPositions)
    Stop-ManageDragReflow -KeepPositions:$KeepPositions
    Set-ManageDropPreview -Decision $null
    $script:ManageActiveDragGuid = $null
    $script:ManageDragGuid = $null
    if ($script:Popup -and -not $script:Popup.IsDisposed) {
        foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) { $row.Invalidate() }
    }
    # Apply a real firmware/label change once DoDragDrop has released its rows.
    if ($script:PopupRowsRefreshPending -or $script:PopupRowsViewportPending) {
        Update-PopupRows -Reason 'drag-ended'
    }
}
# Lightweight row-painted cue: no extra WinForms controls intercept pointer events.
function Paint-ManageDropCue {
    param($Row,$Graphics)
    if (-not $script:IsManageEntriesMode) { return }
    $guid = ([string]$Row.Tag).ToLowerInvariant()
    if ($script:ManageActiveDragGuid -and $guid -eq $script:ManageActiveDragGuid) {
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(155,155,155),1.0)
        try { $Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$Row.Width-3),[Math]::Max(1,$Row.Height-3)) }
        finally { $pen.Dispose() }
    }
    if ($script:ManageDragLayout) { return } # Full-height gap replaces the old red line.
    $cue = $script:ManageDropPreview
    if (-not $cue -or $cue.TargetGuid -ne $guid) { return }
    $thickness = [Math]::Max(3,[int][Math]::Round($Row.Height/20.0))
    $y = if ($cue.After) { $Row.Height-$thickness } else { 0 }
    $brush = New-Object Drawing.SolidBrush($script:ColorAccent)
    try {
        $Graphics.FillRectangle($brush,0,$y,$Row.Width,$thickness)
        $Graphics.FillRectangle($brush,0,[Math]::Max(0,$y-$thickness),[Math]::Max(6,$thickness*2),[Math]::Min($Row.Height,$thickness*3))
    }
    finally { $brush.Dispose() }
}

# Wheel messages can arrive at a row, list, or the form when another control
# owns keyboard focus. Mark native handled events to avoid parent double-scroll.
function Invoke-BootEntryWheelScroll {
    param($ListPanel,[Windows.Forms.MouseEventArgs]$EventArgs)
    if (-not $ListPanel -or $ListPanel.IsDisposed -or -not $EventArgs -or $EventArgs.Delta -eq 0) { return }
    if ($EventArgs -is [Windows.Forms.HandledMouseEventArgs] -and $EventArgs.Handled) { return }
    $bar = $ListPanel.Controls['EntryScroll']
    if (-not $bar -or -not $bar.Visible) { return }
    $direction = if ($EventArgs.Delta -gt 0) { -1 } else { 1 }
    $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
    if ($EventArgs -is [Windows.Forms.HandledMouseEventArgs]) { $EventArgs.Handled = $true }
}

function New-BootEntryInteractionHandlers {
    $clickHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode) {
            $capabilities = Get-CurrentSystemFunctionsCapabilities
            if (-not $capabilities.CanManageEntries) { return }
        }
        # BootNext controller owns both Ready and cold-start Checking admission.
        # Do not silently discard the first click before pending feedback.
        $guid = [string]$sender.Tag
        if (-not $guid) {
            $row = Get-BootRowFromControl $sender
            if ($row) { $guid = [string]$row.Tag }
        }
        if (-not $guid) { return }

        if ($script:IsManageEntriesMode) {
            if (([datetime]::UtcNow - $script:ManageLastDragUtc).TotalMilliseconds -lt 350) { return }
            $hadAlias = [bool]$script:ManageAliasEditGuid
            Invoke-ManageRowVisibility -Guid $guid
            if ($hadAlias -and -not $script:ManageAliasEditGuid) { Restore-ManageRowFocus -Guid $guid -KeyboardCue:$false }
            return
        }

        Invoke-NormalBootTargetSelection -Guid $guid
    }

    $enterHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $true }
    $leaveHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $false }
    $wheelHandler = {
        param($sender, $eventArgs)
        $panel = if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $script:Popup.Controls.Find('EntryList',$true) | Select-Object -First 1
        } else { $null }
        Invoke-BootEntryWheelScroll -ListPanel $panel -EventArgs $eventArgs
    }
    $mouseDownHandler = {
        param($sender, $eventArgs)
        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        if ($script:IsManageEntriesMode -and (-not (Get-CurrentSystemFunctionsCapabilities).CanManageEntries -or $script:ManageActiveDragGuid)) { return }
        # Focus transfer is presentation only; the existing Click owner still dispatches exactly once.
        $row = Get-BootRowFromControl $sender
        if ($row -and -not $script:ManageAliasEditGuid) { Set-LenovoPointerFocus -Control $row }
        if (-not $script:IsManageEntriesMode) { return }
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
        $script:ManageActiveDragGuid = ([string]$guid).ToLowerInvariant()
        if ($null -ne $script:ManageUndoHistory) { Update-ManageUndoButtonState }
        # LBS-221: close action help before capturing the row or entering OLE drag.
        try { Hide-DarkActionTooltip } catch { }
        $sourceRow = Get-BootRowFromControl $sender
        if ($sourceRow -and $sourceRow.PSObject.Properties['ManageSpaceArmed']) { $sourceRow.ManageSpaceArmed = $false }
        if ($sourceRow -and $sourceRow.PSObject.Methods['SetManageEditCue']) { $sourceRow.SetManageEditCue($false,$false,$false) }
        if ($sourceRow) { Start-ManageDragReflow -SourceRow $sourceRow }
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) }
        catch { }
        finally {
            Reset-ManageDragPreview
            if ($null -ne $script:ManageUndoHistory) { Update-ManageUndoButtonState }
        }
    }
    $dragOverHandler = {
        param($sender,$eventArgs)
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Set-ManageDropPreview -Decision $null; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Set-ManageDropPreview -Decision $null; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        Set-ManageDropPreview -Decision $decision
        if ($script:ManageDragLayout) { Set-ManageDragFloatLocation -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -ActivateVisual }
        if ($decision) { $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move }
    }
    $dragEnterHandler = $dragOverHandler
    $dragLeaveHandler = {
        param($sender,$eventArgs)
        if (-not $script:Popup -or $script:Popup.IsDisposed) { Reset-ManageDragPreview; return }
        $matches = @($script:Popup.Controls.Find('EntryList',$true))
        if ($matches.Count -eq 0) { Set-ManageDropPreview -Decision $null; return }
        $point = $matches[0].PointToClient([System.Windows.Forms.Control]::MousePosition)
        if (-not $matches[0].ClientRectangle.Contains($point)) { Set-ManageDropPreview -Decision $null }
    }
    $dragDropHandler = {
        param($sender,$eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Reset-ManageDragPreview; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Reset-ManageDragPreview; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        if (-not $decision) { Reset-ManageDragPreview; return }
        $movedGuid = $decision.MovedGuid
        $targetRow = $null
        if ($script:ManageDragLayout) {
            $targetSlot = $script:ManageDragLayout | Where-Object { $_.Guid -eq $decision.TargetGuid } | Select-Object -First 1
            if ($targetSlot) { $targetRow = $targetSlot.Row }
        }
        else {
            $targetRow = Get-BootRowFromControl $sender
        }
        if (-not $targetRow -or $targetRow.IsDisposed -or ([string]$targetRow.Tag).ToLowerInvariant() -ne $decision.TargetGuid) {
            Reset-ManageDragPreview
            return
        }
        # A drop can arrive before the next 16ms timer tick. Flush the
        # exact committed decision and place every existing row at the final
        # preview slot before removing the ghost; no obsolete-order flash.
        Set-ManageDropPreview -Decision $decision
        if ($script:ManageDragLayout) { Advance-ManageDragReflow -Progress 1.0 }
        $after = $decision.After
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
        # The rows already occupy their preview positions; do not briefly snap
        # them back to the obsolete order before the committed render.
        Reset-ManageDragPreview -KeepPositions
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
        DragOver = $dragOverHandler
        DragLeave = $dragLeaveHandler
        DragDrop = $dragDropHandler
    }
}

# LBS-224: a separate, nonselectable cue preserves the native EDIT's Text,
# caret and keyboard routing. The native cue banner was too dim on the dark
# field in the hosted WinForms feasibility probe; this sibling is hit-transparent.
function New-ManageAliasCue {
    param([System.Windows.Forms.TextBox]$Editor, [string]$CueText)
    $cue = $null
    try {
        if (-not ('LenovoAliasCueLabel' -as [type])) {
            Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @'
using System;
using System.Windows.Forms;
public sealed class LenovoAliasCueLabel : Label {
    private TextBox editor;
    private System.Drawing.Font ownedCueFont;
    public LenovoAliasCueLabel() {
        SetStyle(ControlStyles.Selectable, false);
        TabStop = false;
        AccessibleRole = AccessibleRole.None;
        UseMnemonic = false;
        AutoSize = false;
    }
    public void SetCueFont(System.Drawing.Font source) {
        ownedCueFont = new System.Drawing.Font(source, System.Drawing.FontStyle.Italic);
        Font = ownedCueFont;
    }
    public void Bind(TextBox target) {
        Detach();
        editor = target;
        editor.TextChanged += SyncVisibility;
        editor.VisibleChanged += SyncVisibility;
        editor.Disposed += EditorDisposed;
        SyncVisibility(editor, EventArgs.Empty);
    }
    private void SyncVisibility(object sender, EventArgs e) {
        Visible = editor != null && !editor.IsDisposed && editor.Visible && editor.TextLength == 0;
    }
    private void EditorDisposed(object sender, EventArgs e) {
        Detach();
        if (!IsDisposed) Visible = false;
    }
    private void Detach() {
        if (editor == null) return;
        editor.TextChanged -= SyncVisibility;
        editor.VisibleChanged -= SyncVisibility;
        editor.Disposed -= EditorDisposed;
        editor = null;
    }
    protected override void Dispose(bool disposing) {
        if (disposing) Detach();
        try {
            base.Dispose(disposing);
        } finally {
            // Release only the font created by this cue, never the editor's
            // font or a replacement owned by the existing DPI layout path.
            if (disposing && ownedCueFont != null) {
                ownedCueFont.Dispose();
                ownedCueFont = null;
            }
        }
    }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0084) { m.Result = new IntPtr(-1); return; }
        base.WndProc(ref m);
    }
}
'@ -ErrorAction Stop
        }
        $cue = New-Object LenovoAliasCueLabel
        $cue.Name = 'AliasCueLabel'
        $cue.Text = $CueText
        $cue.SetCueFont($Editor.Font)
        $cue.BackColor = $Editor.BackColor
        $cue.ForeColor = [Drawing.Color]::FromArgb(143,166,191)
        # Reserve the native caret's left edge; retain design-scaled bounds.
        $cue.Location = [Drawing.Point]::new($Editor.Left + 4,$Editor.Top)
        $cue.Size = [Drawing.Size]::new([Math]::Max(1,$Editor.Width - 4),$Editor.Height)
        $cue.Bind($Editor)
        return $cue
    }
    catch {
        if ($cue) { $cue.Dispose() }
        Write-Verbose ('Alias cue unavailable; retaining the original-name hint: ' + $_.Exception.Message)
        return $null
    }
}

function Hide-ManageAliasFieldTooltip {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:DarkActionTooltipOwner -eq $Owner) {
        try { Hide-DarkActionTooltip } catch { }
    }
}

function Show-ManageAliasLimitFeedback {
    param([System.Windows.Forms.TextBox]$Editor)
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasLimitExceeded' -Values @{ Limit = (Get-EntryAliasMaxLengthCore) }
    [void]$Editor.Focus()
    try { Show-DarkActionTooltip -Owner $Editor -Text $script:LastStatusText } catch { }
}

# Track only the initiating modality of the existing native editor buttons;
# never replace their native keyboard/click activation or TextBox focus.
function Connect-ManageAliasButtonModality {
    param([Windows.Forms.Button]$Button)
    $Button | Add-Member -NotePropertyName LenovoPointerPress -NotePropertyValue $false
    $Button.Add_MouseDown({ param($sender,$eventArgs) $sender.LenovoPointerPress = ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left) })
    $Button.Add_MouseUp({ param($sender,$eventArgs) if (-not $sender.ClientRectangle.Contains($eventArgs.Location)) { $sender.LenovoPointerPress = $false } })
    $Button.Add_KeyDown({ $this.LenovoPointerPress = $false })
    $Button.Add_LostFocus({ $this.LenovoPointerPress = $false })
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
    $editorFrame.BackColor = [Drawing.Color]::FromArgb(24,24,24)

    $aliasEditor = New-Object System.Windows.Forms.TextBox
    $aliasEditor.Name = 'AliasEditor'
    $aliasEditor.Tag = $entry.Guid
    # Native typing/paste is limited; programmatic initialization preserves
    # an existing overlength alias until the user explicitly edits it.
    $aliasEditor.MaxLength = Get-EntryAliasMaxLengthCore
    $aliasEditor.Text = if ($alias) { [string]$alias } else { '' }
    $aliasEditor.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $aliasEditor.ForeColor = $script:ColorPrimary
    $aliasEditor.BackColor = [Drawing.Color]::FromArgb(24,24,24)
    $aliasEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $aliasEditor.Location = New-Object Drawing.Point(0, 2)
    $aliasEditor.Size = New-Object Drawing.Size(288, 21)
    $aliasEditor.AccessibleName = Get-LocalizedString -Key 'Manage.EditAliasAccessible'
    $aliasEditor.AccessibleDescription = Get-LocalizedString -Key 'Manage.AliasFieldHint'
    $aliasCue = New-ManageAliasCue -Editor $aliasEditor -CueText (Get-LocalizedString -Key 'Manage.AliasCue')

    $aliasUnderline = New-Object System.Windows.Forms.Panel
    $aliasUnderline.Name = 'AliasEditorUnderline'
    $aliasUnderline.Location = New-Object Drawing.Point(0, 25)
    $aliasUnderline.Size = New-Object Drawing.Size(318, 1)
    $aliasUnderline.BackColor = [Drawing.Color]::FromArgb(72,72,72)
    $editorFrame.Controls.Add($aliasUnderline)


    $clearAlias = New-Object System.Windows.Forms.Button
    $clearAlias.Name = 'AliasClearButton'
    $clearAlias.Text = '×'
    $clearAlias.Font = New-Object Drawing.Font('Segoe UI', 13.0, [Drawing.FontStyle]::Regular)
    $clearAlias.ForeColor = [Drawing.Color]::FromArgb(180,180,180)
    $clearAlias.BackColor = $aliasEditor.BackColor
    $clearAlias.AccessibleName = Get-LocalizedString -Key 'Manage.ClearAliasHint'
    $clearAlias.AccessibleDescription = $clearAlias.AccessibleName
    $clearAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $clearAlias.FlatAppearance.BorderSize = 0
    $clearAlias.FlatAppearance.MouseOverBackColor = $aliasEditor.BackColor
    $clearAlias.FlatAppearance.MouseDownBackColor = $aliasEditor.BackColor
    $clearAlias.Location = New-Object Drawing.Point(292, 0)
    $clearAlias.Size = New-Object Drawing.Size(26, 23)
    $clearAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $clearAlias.Visible = -not [string]::IsNullOrEmpty([string]$aliasEditor.Text)
    $clearAlias.Add_MouseEnter({
        param($sender,$eventArgs)
        if (-not $sender.Visible -or $script:ManageActiveDragGuid) { return }
        $sender.ForeColor = [Drawing.Color]::FromArgb(255,110,102)
        try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleName) } catch { }
    })
    $clearAlias.Add_MouseLeave({
        param($sender,$eventArgs)
        $sender.ForeColor = [Drawing.Color]::FromArgb(180,180,180)
        if ($script:DarkActionTooltipOwner -eq $sender) {
            try { Hide-DarkActionTooltip } catch { }
        }
    })
    # The button vanishes when the text is cleared or the editor closes.
    # Only dismiss its own hint; another control may already own the tooltip.
    $clearAlias.Add_VisibleChanged({
        param($sender,$eventArgs)
        if (-not $sender.Visible) {
            $sender.ForeColor = [Drawing.Color]::FromArgb(180,180,180)
            if ($script:DarkActionTooltipOwner -eq $sender) {
                try { Hide-DarkActionTooltip } catch { }
            }
        }
    })
    $clearAlias.Add_Disposed({
        param($sender,$eventArgs)
        if ($script:DarkActionTooltipOwner -eq $sender) {
            try { Hide-DarkActionTooltip } catch { }
        }
    })
    $clearAlias.Add_Click({
        if ($script:DarkActionTooltipOwner -eq $this) {
            try { Hide-DarkActionTooltip } catch { }
        }
        $editor = $this.Parent.Controls.Find('AliasEditor', $false) | Select-Object -First 1
        if ($editor) {
            $editor.Text = ''
            $editor.Focus()
        }
    })
    $editorFrame.Controls.Add($clearAlias)

    $aliasEditor.Add_MouseEnter({
        param($sender,$eventArgs)
        if (-not $sender.Visible -or $script:ManageActiveDragGuid) { return }
        try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
    })
    $aliasEditor.Add_MouseLeave({ param($sender,$eventArgs) Hide-ManageAliasFieldTooltip -Owner $sender })
    $aliasEditor.Add_MouseDown({ param($sender,$eventArgs) Hide-ManageAliasFieldTooltip -Owner $sender })
    $aliasEditor.Add_VisibleChanged({
        param($sender,$eventArgs)
        if (-not $sender.Visible) { Hide-ManageAliasFieldTooltip -Owner $sender }
    })
    $aliasEditor.Add_HandleDestroyed({ param($sender,$eventArgs) Hide-ManageAliasFieldTooltip -Owner $sender })
    $aliasEditor.Add_Disposed({ param($sender,$eventArgs) Hide-ManageAliasFieldTooltip -Owner $sender })
    $aliasEditor.Add_Enter({
        param($sender,$eventArgs)
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = $script:ColorAccent }
        } catch { }
    })
    $aliasEditor.Add_Leave({
        param($sender,$eventArgs)
        Hide-ManageAliasFieldTooltip -Owner $sender
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = [Drawing.Color]::FromArgb(72,72,72) }
        } catch { }
    })
    $aliasEditor.Add_TextChanged({
        param($sender,$eventArgs)
        Hide-ManageAliasFieldTooltip -Owner $sender
        try {
            $clear = $sender.Parent.Controls.Find('AliasClearButton', $false) | Select-Object -First 1
            if ($clear) { $clear.Visible = -not [string]::IsNullOrEmpty([string]$sender.Text) }
            Update-ManageSaveButtonState
        } catch { }
    })
    $aliasEditor.Add_KeyDown({
        param($sender,$eventArgs)
        Hide-ManageAliasFieldTooltip -Owner $sender
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $eventArgs.SuppressKeyPress = $true
            if (-not (Set-ManageEntryAliasDraft -Guid ([string]$sender.Tag) -Alias ([string]$sender.Text))) {
                Show-ManageAliasLimitFeedback -Editor $sender
                return
            }
            $closedGuid = [string]$sender.Tag
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ([string]::IsNullOrWhiteSpace([string]$sender.Text)) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            Update-PopupRows
            Restore-ManageRowFocus -Guid $closedGuid
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $closedGuid = [string]$sender.Tag
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
            $eventArgs.SuppressKeyPress = $true
            Update-PopupRows
            Restore-ManageRowFocus -Guid $closedGuid
        }
    })
    $editorFrame.Controls.Add($aliasEditor)
    if ($aliasCue) {
        $editorFrame.Controls.Add($aliasCue)
        $aliasCue.BringToFront()
    }
    $row.Controls.Add($editorFrame)

    $applyAlias = New-Object System.Windows.Forms.Button
    $applyAlias.Name = 'AliasApplyButton'
    $applyAlias.Text = Get-LocalizedString -Key 'Common.Apply'
    $applyAlias.Tag = $entry.Guid
    $applyAlias.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $applyAlias.ForeColor = [Drawing.Color]::FromArgb(255,110,102)
    $applyAlias.BackColor = $script:ColorRow
    $applyAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyAlias.FlatAppearance.BorderSize = 0
    $applyAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $applyAlias.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $applyAlias.Location = New-Object Drawing.Point(58, 62)
    $applyAlias.Size = New-Object Drawing.Size(92, 24)
    $applyAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    Connect-ManageAliasButtonModality -Button $applyAlias
    $applyAlias.Add_Click({
        param($sender,$eventArgs)
        $keyboardCue = -not $sender.LenovoPointerPress
        $sender.LenovoPointerPress = $false
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor) {
            if (-not (Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text))) {
                Show-ManageAliasLimitFeedback -Editor $editor
                return
            }
            $empty = [string]::IsNullOrWhiteSpace([string]$editor.Text)
            $closedGuid = [string]$editor.Tag
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ($empty) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            Update-PopupRows
            Restore-ManageRowFocus -Guid $closedGuid -KeyboardCue:$keyboardCue
        }
    })
    $row.Controls.Add($applyAlias)

    $cancelAlias = New-Object System.Windows.Forms.Button
    $cancelAlias.Name = 'AliasCancelButton'
    $cancelAlias.Tag = $entry.Guid
    $cancelAlias.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelAlias.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $cancelAlias.ForeColor = $script:ColorSecondary
    $cancelAlias.BackColor = $script:ColorRow
    $cancelAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelAlias.FlatAppearance.BorderSize = 0
    $cancelAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $cancelAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelAlias.Location = New-Object Drawing.Point(154, 62)
    $cancelAlias.Size = New-Object Drawing.Size(80, 24)
    $cancelAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    Connect-ManageAliasButtonModality -Button $cancelAlias
    $cancelAlias.Add_Click({
        param($sender,$eventArgs)
        $keyboardCue = -not $sender.LenovoPointerPress
        $sender.LenovoPointerPress = $false
        $closedGuid = [string]$sender.Tag
        $script:ManageAliasEditGuid = $null
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
        Update-PopupRows
        Restore-ManageRowFocus -Guid $closedGuid -KeyboardCue:$keyboardCue
    })
    $row.Controls.Add($cancelAlias)

    # Fail back to the original instruction rather than lose discoverability.
    if (-not $aliasCue) {
        $originalHint = New-Label -Text (Get-LocalizedString -Key 'Manage.OriginalNameHint') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
            -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 238 -Y 60 -Width 138 -Height 30
        $originalHint.Name = 'AliasOriginalNameHint'
        $originalHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
        $originalHint.AccessibleDescription = $originalHint.Text
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($originalHint,$originalHint.Text) }
        $row.Controls.Add($originalHint)
    }
}

# LBS-144: calculate visibility-eye paint geometry from the graphics surface
# DPI, not from fixed pixels. The popup already scales the 32x34 design
# hit target; keep that unchanged and derive a single-scale glyph.
function Get-LenovoManageEyeGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Visibility glyph requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $eyeWidth = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(20.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $eyeHeight = [Math]::Min(
        [Math]::Max(1,$ClientSize.Height - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $left = [int][Math]::Floor(($ClientSize.Width - $eyeWidth) / 2.0)
    $top = [int][Math]::Floor(($ClientSize.Height - $eyeHeight) / 2.0)
    $eye = [Drawing.Rectangle]::new($left,$top,$eyeWidth,$eyeHeight)
    $pupilSide = [Math]::Min(
        [Math]::Max(1,$eyeHeight - 2),
        [Math]::Max(1,[int][Math]::Round(5.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $pupilSide = [Math]::Min($pupilSide,$eyeWidth)
    $pupil = [Drawing.Rectangle]::new(
        $left + [int][Math]::Floor(($eyeWidth - $pupilSide) / 2.0),
        $top + [int][Math]::Floor(($eyeHeight - $pupilSide) / 2.0),
        $pupilSide,$pupilSide)
    $extension = [Math]::Max(1,[int][Math]::Round(1.0 * $scale,[MidpointRounding]::AwayFromZero))
    return [pscustomobject]@{
        Eye = $eye
        Pupil = $pupil
        SlashStart = [Drawing.Point]::new(
            [Math]::Max(0,$eye.Left - $extension),
            [Math]::Min($ClientSize.Height-1,$eye.Bottom + $extension))
        SlashEnd = [Drawing.Point]::new(
            [Math]::Min($ClientSize.Width-1,$eye.Right + $extension),
            [Math]::Max(0,$eye.Top - $extension))
        Stroke = [single](1.6 * $scale)
        SlashStroke = [single](1.8 * $scale)
    }
}

# LBS-166: draw the reorder affordance at paint-surface DPI, not font size.
# Preserve its existing 26x34 design-unit hit area.
function Get-LenovoManageGripGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Reorder grip requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $width = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(18.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $stroke = [single][Math]::Min(2.4 * $scale,[double]$width)
    $span = [Math]::Min(
        [Math]::Max(0,$ClientSize.Height - 2 * $margin - [int][Math]::Ceiling($stroke)),
        [Math]::Max(0,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $centerX = ($ClientSize.Width - 1) / 2.0
    $centerY = ($ClientSize.Height - 1) / 2.0
    $halfLine = ($width - $stroke) / 2.0
    return [pscustomobject]@{
        Width = [int]$width
        Span = [int]$span
        Stroke = [single]$stroke
        StartX = [single]($centerX - $halfLine)
        EndX = [single]($centerX + $halfLine)
        TopY = [single]($centerY - $span / 2.0)
        MiddleY = [single]$centerY
        BottomY = [single]($centerY + $span / 2.0)
    }
}

function Paint-LenovoManageGripGlyph {
    param(
        [Parameter(Mandatory=$true)][Drawing.Graphics]$Graphics,
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][Drawing.Color]$Color
    )
    $geometry = Get-LenovoManageGripGlyphGeometry -ClientSize $ClientSize -Dpi $Graphics.DpiX
    $smoothing = $Graphics.SmoothingMode
    $pen = New-Object Drawing.Pen($Color,$geometry.Stroke)
    try {
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        foreach ($y in @($geometry.TopY,$geometry.MiddleY,$geometry.BottomY)) {
            $Graphics.DrawLine($pen,$geometry.StartX,[single]$y,$geometry.EndX,[single]$y)
        }
    }
    finally {
        $Graphics.SmoothingMode = $smoothing
        $pen.Dispose()
    }
}

# Shared action owners for mouse and focused-row keyboard interaction.
function Invoke-ManageRowVisibility {
    param([string]$Guid)
    if (-not $script:IsManageEntriesMode -or -not $Guid) { return }
    if ($script:ManageAliasEditGuid -and -not (Commit-ActiveManageAliasEditor)) { return }
    Toggle-ManageEntryVisibility -Guid $Guid
    $script:LastStatusText = if (Test-ManageEntryHidden -Guid $Guid) { Get-LocalizedString -Key 'Manage.EntryHiddenStatus' } else { Get-LocalizedString -Key 'Manage.EntryVisibleStatus' }
    Update-PopupRows
}

function Start-ManageRowAliasEdit {
    param([string]$Guid)
    if (-not $script:IsManageEntriesMode -or -not $Guid -or $script:ManageActiveDragGuid) { return }
    $guid = $Guid.ToLowerInvariant()
    if ($script:ManageAliasEditGuid -and $script:ManageAliasEditGuid -ne $guid) {
        if (-not (Commit-ActiveManageAliasEditor)) { return }
    }
    $script:ManageAliasEditGuid = $guid
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.EditAliasStatus'
    Update-PopupRows
    $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($editor) {
        [void]$editor.Focus()
        $editor.SelectAll()
        Set-NormalBootRowVisible -Row (Get-BootRowFromControl $editor)
    }
}

function Restore-ManageRowFocus {
    param([string]$Guid,[int]$FallbackIndex = -1,[Nullable[bool]]$KeyboardCue,[switch]$EditCue)
    if (-not $script:IsManageEntriesMode -or -not $script:Popup -or $script:Popup.IsDisposed) { return }
    $rows = @($script:Popup.Controls.Find('BootRow',$true) | Where-Object {
        -not $_.IsDisposed -and $_.CanFocus -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode
    } | Sort-Object Top)
    $target = $rows | Where-Object { [string]$_.Tag -eq $Guid } | Select-Object -First 1
    if (-not $target -and $FallbackIndex -ge 0 -and $rows.Count -gt 0) {
        $target = $rows[[Math]::Min($FallbackIndex,$rows.Count-1)]
    }
    if ($target) {
        if ($null -ne $KeyboardCue) { $target.SetKeyboardCue([bool]$KeyboardCue) }
        [void]$target.Focus()
        Set-NormalBootRowVisible -Row $target
        if ($EditCue -and [string]$target.Tag -eq $Guid) { Update-ManageKeyboardEditCue -Row $target -Active:$true }
    }
}

# Keyboard emphasis and actual pointer hover are independent. Reuse the
# existing hover ink; never synthesize hover, change a background, or show help.
function Update-ManageEditGlyphInk {
    param($Control)
    $row = $Control.Parent
    $keyboard = $row -and $row.PSObject.Properties['ManageEditCueActive'] -and $row.ManageEditCueActive
    $hover = -not $script:ManageActiveDragGuid -and ($Control.ManagePointerHovered -or $keyboard)
    $color = if ($Control.Name -eq 'ManageReorderGrip') {
        if ($hover) { [Drawing.Color]::FromArgb(220,220,220) } else { [Drawing.Color]::FromArgb(145,145,145) }
    } else {
        if ($hover) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(190,190,190) }
    }
    if ($Control.ForeColor -ne $color) { $Control.ForeColor = $color; $Control.Invalidate() }
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
$state.ForeColor = if ($isHidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
$state.Cursor = [System.Windows.Forms.Cursors]::Hand
$state.AllowDrop = $true
$state.Add_Paint({
    param($sender,$eventArgs)
    $hidden = ([string]$sender.AccessibleName -eq 'hidden')
    $hover = -not $script:ManageActiveDragGuid -and ($sender.ForeColor -eq [Drawing.Color]::FromArgb(160,160,160) -or $sender.ForeColor -eq [Drawing.Color]::FromArgb(255,110,102))
    $color = if ($hidden) {
        if ($hover) { [Drawing.Color]::FromArgb(160,160,160) } else { [Drawing.Color]::FromArgb(115,115,115) }
    } else {
        if ($hover) { [Drawing.Color]::FromArgb(255,110,102) } else { $script:ColorAccent }
    }
    $geometry = Get-LenovoManageEyeGlyphGeometry -ClientSize $sender.ClientSize -Dpi $eventArgs.Graphics.DpiX
    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen($color, $geometry.Stroke)
    $pupil = New-Object Drawing.SolidBrush($color)
    try {
        $eventArgs.Graphics.DrawEllipse($pen, $geometry.Eye)
        $eventArgs.Graphics.FillEllipse($pupil, $geometry.Pupil)
        if ($hidden) {
            $slash = New-Object Drawing.Pen($color, $geometry.SlashStroke)
            try {
                $eventArgs.Graphics.DrawLine($slash, $geometry.SlashStart, $geometry.SlashEnd)
            } finally { $slash.Dispose() }
        }
    }
    finally {
        $pen.Dispose()
        $pupil.Dispose()
    }
})
$state.Add_MouseEnter({
    param($sender,$eventArgs)
    if ($script:ManageActiveDragGuid) { return }
    $sender.ForeColor = if ($sender.AccessibleName -eq 'hidden') { [Drawing.Color]::FromArgb(160,160,160) } else { [Drawing.Color]::FromArgb(255,110,102) }
    $sender.Invalidate()
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$state.Add_MouseLeave({
    param($sender,$eventArgs)
    $sender.ForeColor = if ($sender.AccessibleName -eq 'hidden') { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
    $sender.Invalidate()
    try { Hide-DarkActionTooltip } catch { }
})
$row.Controls.Add($state)

$editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 14.0, [Drawing.FontStyle]::Regular)) `
    -ForeColor ([Drawing.Color]::FromArgb(190,190,190)) -X 321 -Y 12 -Width 25 -Height 34
$editAlias.Name = 'AliasEditButton'
$editAlias.Tag = $entry.Guid
$editAlias.AccessibleDescription = Get-LocalizedString -Key 'Manage.EditAliasAccessible'
$editAlias.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$editAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
$editAlias | Add-Member -NotePropertyName ManagePointerHovered -NotePropertyValue $false
$editAlias.Add_MouseEnter({
    param($sender,$eventArgs)
    if ($script:ManageActiveDragGuid) { return }
    $sender.ManagePointerHovered = $true
    Update-ManageEditGlyphInk -Control $sender
    Set-RowHoverState $sender $true
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$editAlias.Add_MouseLeave({
    param($sender,$eventArgs)
    $sender.ManagePointerHovered = $false
    Update-ManageEditGlyphInk -Control $sender
    Set-RowHoverState $sender $false
    try { Hide-DarkActionTooltip } catch { }
})
$editAlias.Add_MouseDown({
    param($sender,$eventArgs)
    if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left -and -not $script:ManageActiveDragGuid) {
        Set-LenovoPointerFocus -Control (Get-BootRowFromControl $sender)
    }
})
$editAlias.Add_Click({
    param($sender,$eventArgs)
    try { Hide-DarkActionTooltip } catch { }
    Start-ManageRowAliasEdit -Guid ([string]$sender.Tag)
})
$row.Controls.Add($editAlias)

$grip = New-Object System.Windows.Forms.Panel
$grip.Name = 'ManageReorderGrip'
$grip.Tag = $entry.Guid
$grip.Location = New-Object Drawing.Point(350, 12)
$grip.Size = New-Object Drawing.Size(26, 34)
$grip.BackColor = [Drawing.Color]::Transparent
$grip.ForeColor = [Drawing.Color]::FromArgb(145,145,145)
$grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$grip.AllowDrop = $true
$grip | Add-Member -NotePropertyName ManagePointerHovered -NotePropertyValue $false
$grip.Add_Paint({
    param($sender,$eventArgs)
    $color = if ($script:ManageActiveDragGuid) { [Drawing.Color]::FromArgb(145,145,145) } else { $sender.ForeColor }
    Paint-LenovoManageGripGlyph -Graphics $eventArgs.Graphics -ClientSize $sender.ClientSize -Color $color
})
$grip.Add_MouseEnter({
    param($sender,$eventArgs)
    if ($script:ManageActiveDragGuid) { return }
    $sender.ManagePointerHovered = $true
    Update-ManageEditGlyphInk -Control $sender
    try { Show-DarkActionTooltip -Owner $sender -Text (Get-LocalizedString -Key 'Manage.ReorderHint') } catch { }
})
$grip.Add_MouseLeave({
    param($sender,$eventArgs)
    $sender.ManagePointerHovered = $false
    Update-ManageEditGlyphInk -Control $sender
    try { Hide-DarkActionTooltip } catch { }
})
$grip.Add_MouseDown({
    param($sender,$eventArgs)
    if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left) {
        try { Hide-DarkActionTooltip } catch { }
    }
})
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

    $pending = [bool]($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid))
    $checkText = if ($pending) { '…' } elseif ($isSelected) { '✓' } else { '' }
    $statusHint = if ($pending) { Get-LocalizedString -Key 'BootNext.RowPendingHint' }
        elseif ($isSelected) { Get-LocalizedString -Key 'BootNext.RowSelectedHint' }
        else { '' }
    $check = New-Label -Text $checkText `
        -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
        -ForeColor $(if ($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid)) { $script:ColorWarning } else { $script:ColorAccent }) -X 354 -Y 12 -Width 24 -Height 34
    $check.Name = 'BootSelectionStatusGlyph'
    if ($statusHint) {
        $check.AccessibleRole = [Windows.Forms.AccessibleRole]::StaticText
        $check.AccessibleName = [string]$statusHint
        $check.AccessibleDescription = [string]$statusHint
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($check,[string]$statusHint) }
    }
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
    $dragOverHandler = $Handlers.DragOver
    $dragLeaveHandler = $Handlers.DragLeave
    $dragDropHandler = $Handlers.DragDrop

foreach ($control in $RowControls) {
    if ($control.Name -ne 'ManageReorderGrip') { $control.Add_Click($clickHandler) }
    $control.Add_MouseEnter($enterHandler)
    $control.Add_MouseLeave($leaveHandler)
    $control.Add_MouseWheel($wheelHandler)
    $control.Add_MouseDown($mouseDownHandler)
    if ($script:IsManageEntriesMode) {
        $control.Add_MouseMove($mouseMoveHandler)
        $control.Add_DragEnter($dragEnterHandler)
        $control.Add_DragOver($dragOverHandler)
        $control.Add_DragLeave($dragLeaveHandler)
        $control.Add_DragDrop($dragDropHandler)
    }
}
}

# Initial construction and metadata-only refresh share one text/locale rule.
function Get-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Entry)
    $manage = [bool]$script:IsManageEntriesMode
    $guid = ([string]$Entry.Guid).ToLowerInvariant()
    $alias = Get-EntryAlias -Guid $guid -UseManageDraft:$manage
    $displayTitle = Get-EntryDisplayTitle -Entry $Entry -UseManageDraft:$manage
    $editing = $manage -and $script:ManageAliasEditGuid -and $guid -eq $script:ManageAliasEditGuid
    $pending = -not $manage -and (Resolve-BootNextRowDisplayCore -EntryGuid $guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid) -eq 'pending'
    $titleText = if ($editing) { [string]$Entry.Title } else { [string]$displayTitle }
    $subtitleText = if ($editing) { '' }
        elseif ($manage -and $alias) { Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name=[string]$Entry.Title } }
        elseif ($manage -and ([string]$Entry.RawDescription -eq 'Boot Menu')) { Get-LocalizedString -Key 'Boot.MenuManageSubtitle' }
        elseif ($pending) { Get-LocalizedString -Key 'BootNext.SelectionPending' }
        else { [string]$Entry.Subtitle }
    return [pscustomobject]@{ Title = [string]$titleText; Subtitle = [string]$subtitleText }
}

# Normal mode action help is presentation only. Never probe firmware or
# invoke a selection from a tooltip. Unknown readiness uses conditional wording.
function Update-NormalBootEntryTooltips {
    param($Row,$Entry)
    if ($script:IsManageEntriesMode -or -not $script:BootTypeToolTip -or -not $Row -or $Row.IsDisposed) { return }
    $text = Get-BootEntryRowText -Entry $Entry
    $action = if ($script:BootNextPendingGuid -or $script:DefaultTargetChangePending) {
        Get-LocalizedString -Key 'Tooltip.NextBootPending'
    } elseif ($script:NextBootFirmwareReadVerified -and $script:SelectedGuid -eq $Entry.Guid) {
        Get-LocalizedString -Key 'Tooltip.NextBootSelected'
    } elseif ([string]$Entry.RawDescription -eq 'Boot Menu') {
        Get-LocalizedString -Key 'Tooltip.NextBootMenu'
    } else {
        Get-LocalizedString -Key 'Tooltip.NextBoot' -Values @{ Target=$text.Title }
    }
    $full = $action + [Environment]::NewLine + $text.Title
    if ($text.Subtitle) { $full += [Environment]::NewLine + $text.Subtitle }
    foreach ($control in @($Row) + @($Row.Controls)) {
        $hint = $full
        if ($control.Name -eq 'BootTypeGlyph' -and $Entry.TypeTooltip) {
            $hint = [string]$Entry.TypeTooltip + [Environment]::NewLine + $full
        } elseif ($control.Name -eq 'BootSelectionStatusGlyph' -and $control.AccessibleDescription) {
            $hint = [string]$control.AccessibleDescription + [Environment]::NewLine + $full
        }
        if ($script:BootTypeToolTip.GetToolTip($control) -cne $hint) { $script:BootTypeToolTip.SetToolTip($control,$hint) }
    }
}

# The caller must first prove GUID/order/mode/DPI and structural-signature parity.
# Keep live WinForms controls, handlers and scroll context intact.
function Update-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Row,[Parameter(Mandatory=$true)]$Entry)
    $title = $Row.Controls['BootTitleLabel']
    $subtitle = $Row.Controls['BootSubtitleLabel']
    if (-not $title -or -not $subtitle -or $title.IsDisposed -or $subtitle.IsDisposed) {
        throw 'Metadata-only row update requires existing title and subtitle controls.'
    }
    $text = Get-BootEntryRowText -Entry $Entry
    $changed = $false
    if ([string]$title.Text -cne [string]$text.Title) {
        $title.Text = [string]$text.Title
        $title.AccessibleDescription = [string]$text.Title
        if (-not $script:IsManageEntriesMode -or ($Row.PSObject.Properties['ManageKeyboardMode'] -and $Row.ManageKeyboardMode)) { $Row.AccessibleName = [string]$text.Title }
        if ($script:IsManageEntriesMode -and $script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title,[string]$text.Title) }
        $changed = $true
    }
    if ([string]$subtitle.Text -cne [string]$text.Subtitle) {
        $subtitle.Text = [string]$text.Subtitle
        $subtitle.AccessibleDescription = [string]$text.Subtitle
        if (-not $script:IsManageEntriesMode) { $Row.AccessibleDescription = [string]$text.Subtitle }
        if ($script:IsManageEntriesMode -and $script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle,[string]$text.Subtitle) }
        $changed = $true
    }
    Update-NormalBootEntryTooltips -Row $Row -Entry $Entry
    return [bool]$changed
}


# UX01-V8: a real focusable native Panel preserves all existing mouse/paint
# behavior, but exposes Up/Down/Home/End and Enter/Space as input keys. The
# selected BootNext target is never changed by focus alone.
function Initialize-NormalBootKeyboardRow {
    if ('LenovoNormalBootKeyboardRow' -as [type]) { return }
    $keyboardSource = @'
using System;
using System.Drawing;
using System.Windows.Forms;

public sealed class LenovoNormalBootKeyboardRow : Panel
{
    public bool ManageKeyboardMode { get; set; }
    public bool ManageSpaceArmed { get; set; }
    private bool keyboardCue = true;
    private bool editCue, moveUp, moveDown;
    public bool ManageEditCueActive { get { return editCue && ManageKeyboardMode && Focused && Enabled; } }
    public bool ManageMoveUp { get { return ManageEditCueActive && moveUp; } }
    public bool ManageMoveDown { get { return ManageEditCueActive && moveDown; } }
    public event EventHandler ManageEditCueChanged;

    public void SetManageEditCue(bool active, bool up, bool down)
    {
        active = active && ManageKeyboardMode && Focused && Enabled && Visible;
        up = active && up; down = active && down;
        if (editCue == active && moveUp == up && moveDown == down) return;
        editCue = active; moveUp = up; moveDown = down;
        EventHandler changed = ManageEditCueChanged;
        if (changed != null) changed(this, EventArgs.Empty);
        Invalidate();
    }
    public bool KeyboardCueVisible { get { return Focused && keyboardCue; } }
    public bool KeyboardCueEnabled { get { return keyboardCue; } }

    public void SetKeyboardCue(bool visible)
    {
        if (keyboardCue == visible) return;
        keyboardCue = visible;
        Invalidate();
    }

    public void SetManageTabAnchor()
    {
        if (!ManageKeyboardMode || Parent == null) return;
        foreach (Control sibling in Parent.Controls) {
            LenovoNormalBootKeyboardRow row = sibling as LenovoNormalBootKeyboardRow;
            if (row != null && row.ManageKeyboardMode) row.TabStop = Object.ReferenceEquals(row, this);
        }
    }

    public bool FocusForPointer()
    {
        if (!CanFocus || !Enabled || !Visible) return false;
        SetManageEditCue(false, false, false);
        SetKeyboardCue(false);
        return Focus();
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        SetKeyboardCue(true);
        base.OnKeyDown(e);
    }

    protected override bool ProcessDialogKey(Keys keyData)
    {
        if ((keyData & Keys.KeyCode) == Keys.Tab) {
            SetKeyboardCue(true);
            if (ManageKeyboardMode && (keyData & Keys.Modifiers) == Keys.None) {
                Form form = FindForm();
                if (form != null) {
                    foreach (string name in new string[] { "ManageUndoButton", "ManageCancelButton", "ManageSaveButton" }) {
                        Control[] targets = form.Controls.Find(name, true);
                        if (targets.Length > 0 && targets[0].CanSelect && targets[0].CanFocus && targets[0].Focus()) return true;
                    }
                }
            }
        }
        return base.ProcessDialogKey(keyData);
    }

    public LenovoNormalBootKeyboardRow()
    {
        SetStyle(ControlStyles.Selectable, true);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        TabStop = true;
    }

    protected override bool IsInputKey(Keys keyData)
    {
        Keys key = keyData & Keys.KeyCode;
        if (ManageKeyboardMode && (key == Keys.ControlKey || key == Keys.LControlKey || key == Keys.RControlKey || key == Keys.PageUp || key == Keys.PageDown ||
            (key == Keys.E && (keyData & Keys.Modifiers) == Keys.Control))) return true;
        if (key == Keys.Up || key == Keys.Down || key == Keys.Home ||
            key == Keys.End || key == Keys.Return || key == Keys.Space)
            return true;
        return base.IsInputKey(keyData);
    }

    protected override void OnGotFocus(EventArgs e)
    {
        SetManageTabAnchor();
        base.OnGotFocus(e);
        Invalidate();
    }

    protected override void OnLostFocus(EventArgs e)
    {
        ManageSpaceArmed = false;
        SetManageEditCue(false, false, false);
        base.OnLostFocus(e);
        // A new independent focus acquisition defaults to keyboard visibility.
        keyboardCue = true;
        Invalidate();
    }

    protected override void OnEnabledChanged(EventArgs e)
    {
        if (!Enabled) SetManageEditCue(false, false, false);
        base.OnEnabledChanged(e);
    }

    protected override void OnVisibleChanged(EventArgs e)
    {
        if (!Visible) SetManageEditCue(false, false, false);
        base.OnVisibleChanged(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (!KeyboardCueVisible) return;
        Rectangle r = ClientRectangle;
        r.Inflate(-3, -3);
        if (r.Width > 0 && r.Height > 0)
        {
            using (Brush tint = new SolidBrush(Color.FromArgb(18, 180, 196, 214))) e.Graphics.FillRectangle(tint, r);
            using (Pen p = new Pen(Color.FromArgb(181, 196, 212), 1.5f)) {
                if (!ManageMoveUp && !ManageMoveDown) {
                    e.Graphics.DrawRectangle(p, r);
                } else {
                    // Continuous outline; the arrow tips and wings stay inside
                    // the existing free top/bottom margins, above/below labels.
                    float scale = Height / 60f;
                    float cx = (r.Left + r.Right) / 2f;
                    float half = Math.Min(r.Width / 6f, Math.Max(4f, 7f * scale));
                    float top = ManageMoveUp ? Math.Max(r.Top, (float)Math.Floor(5f * scale)) : r.Top;
                    float bottom = ManageMoveDown ? Math.Min(r.Bottom, Height - (float)Math.Floor(5f * scale)) : r.Bottom;
                    var outline = new System.Collections.Generic.List<PointF>();
                    outline.Add(new PointF(r.Left, top));
                    if (ManageMoveUp) {
                        outline.Add(new PointF(cx-half, top));
                        outline.Add(new PointF(cx, 1f));
                        outline.Add(new PointF(cx+half, top));
                    }
                    outline.Add(new PointF(r.Right, top));
                    outline.Add(new PointF(r.Right, bottom));
                    if (ManageMoveDown) {
                        outline.Add(new PointF(cx+half, bottom));
                        outline.Add(new PointF(cx, Height-2f));
                        outline.Add(new PointF(cx-half, bottom));
                    }
                    outline.Add(new PointF(r.Left, bottom));
                    outline.Add(new PointF(r.Left, top));
                    e.Graphics.DrawLines(p, outline.ToArray());
                }
            }
        }
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $keyboardSource -ErrorAction Stop
}

# One pointer focus owner for custom keyboard rows and native controls. No
# business action, global cue override or synthetic input is performed here.
function Set-LenovoPointerFocus {
    param([Windows.Forms.Control]$Control)
    if (-not $Control -or $Control.IsDisposed -or -not $Control.Enabled -or -not $Control.CanFocus) { return }
    if ($Control.PSObject.Methods['FocusForPointer']) { [void]$Control.FocusForPointer() }
    else { [void]$Control.Focus() }
}

# Keep the canonical BootNext controller as the sole selection owner. This
# shared helper is called by both the existing pointer handler and keyboard
# activation; moving focus never calls it.
function Invoke-NormalBootTargetSelection {
    param([string]$Guid)
    $guid = [string]$Guid
    if (-not $guid -or $script:IsManageEntriesMode) { return }
    try {
        $entry = Get-EntryByGuid $guid
        Start-BootNextSelection -Guid $guid
    }
    catch {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}

# Works with the existing EntryScroll control, including when the content
# panel has been moved by the custom scrollbar's ValueChanged handler.
function Set-NormalBootRowVisible {
    param($Row)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.Parent -or
        $Row.Parent.Name -ne 'EntryContent') { return }
    $content = $Row.Parent
    $list = $content.Parent
    if (-not $list -or $list.Name -ne 'EntryList') { return }
    $scroll = $list.Controls['EntryScroll']
    if (-not $scroll -or -not $scroll.Visible) { return }
    $current = [int]$scroll.Value
    $viewport = [Math]::Max(1,[int]$list.ClientSize.Height)
    $desired = $current
    if ($Row.Top -lt $current) { $desired = [int]$Row.Top }
    elseif ($Row.Bottom -gt ($current + $viewport)) {
        $desired = [int]$Row.Bottom - $viewport
    }
    $desired = [Math]::Max(0,[Math]::Min([int]$scroll.Maximum,$desired))
    if ($scroll.Value -ne $desired) { $scroll.Value = $desired }
    $content.Top = -[int]$scroll.Value
}

function Move-NormalBootKeyboardFocus {
    param($Row,[System.Windows.Forms.Keys]$Key)
    if ($script:IsManageEntriesMode -or -not $Row -or $Row.IsDisposed -or
        -not $Row.Parent -or $Row.Parent.Name -ne 'EntryContent') { return }
    $rows = @($Row.Parent.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed -and $_.Enabled -and $_.Visible
    } | Sort-Object Top)
    if ($rows.Count -eq 0) { return }
    $index = -1
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ([object]::ReferenceEquals($rows[$i],$Row)) { $index = $i; break }
    }
    if ($index -lt 0) { return }
    switch ($Key) {
        ([System.Windows.Forms.Keys]::Down) { $index = [Math]::Min($rows.Count-1,$index+1); break }
        ([System.Windows.Forms.Keys]::Up) { $index = [Math]::Max(0,$index-1); break }
        ([System.Windows.Forms.Keys]::Home) { $index = 0; break }
        ([System.Windows.Forms.Keys]::End) { $index = $rows.Count-1; break }
        default { return }
    }
    $target = $rows[$index]
    [void]$target.Focus()
    Set-NormalBootRowVisible -Row $target
}

# LBS-178: focused Manage rows own their shortcuts; the native TextBox
# and OLE drag retain independent input and cancellation semantics.
function Test-ManageRowKeyboardAdmission {
    param($Row)
    return ($script:IsManageEntriesMode -and $Row -and -not $Row.IsDisposed -and $Row.Focused -and
        $Row.Parent -and $Row.Parent.Name -eq 'EntryContent' -and
        -not $script:ManageAliasEditGuid -and -not $script:ManageActiveDragGuid -and
        (Test-GuidInList -Guid ([string]$Row.Tag) -List @($script:CurrentEntries | ForEach-Object { $_.Guid })) -and
        [bool](Get-CurrentSystemFunctionsCapabilities).CanManageEntries)
}

function Update-ManageKeyboardEditCue {
    param($Row,[bool]$Active)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.PSObject.Methods['SetManageEditCue']) { return }
    if (-not $Active -or -not (Test-ManageRowKeyboardAdmission -Row $Row)) {
        $Row.SetManageEditCue($false,$false,$false)
        return
    }
    $entries = @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)
    $position = -1
    for ($i=0; $i -lt $entries.Count; $i++) {
        if ([string]$entries[$i].Guid -eq [string]$Row.Tag) { $position=$i; break }
    }
    $Row.SetManageEditCue(($position -ge 0),($position -gt 0),($position -ge 0 -and $position -lt $entries.Count-1))
}

function Update-ManageKeyboardRowPresentation {
    param($Row)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.Parent -or -not $Row.PSObject.Properties['ManageKeyboardMode'] -or -not $Row.ManageKeyboardMode) { return }
    $entries = @($Row.Parent.Controls | Where-Object { $_.Name -eq 'BootRow' -and -not $_.IsDisposed } | Sort-Object Top)
    $position = 0
    for ($i=0; $i -lt $entries.Count; $i++) {
        if ([object]::ReferenceEquals($entries[$i],$Row)) { $position=$i+1; break }
    }
    if (-not $position) { return }
    $title = $Row.Controls['BootTitleLabel']
    if ($title) { $Row.AccessibleName = [string]$title.Text }
    $state = if (Test-ManageEntryHidden -Guid ([string]$Row.Tag)) { Get-LocalizedString -Key 'Manage.HiddenAccessible' } else { Get-LocalizedString -Key 'Manage.VisibleAccessible' }
    $values = @{ Position=$position; Count=$entries.Count }
    $Row.AccessibleDescription = ('{0}. {1}. {2}' -f (Get-LocalizedString -Key 'Manage.KeyboardPosition' -Values $values),$state,(Get-LocalizedString -Key 'Manage.KeyboardInstructions'))
    if ($Row.ManageEditCueActive) { Update-ManageKeyboardEditCue -Row $Row -Active:$true }
    if ($Row.Focused -and $script:Popup) {
        $hint = $script:Popup.Controls.Find('ManageKeyboardHint',$true) | Select-Object -First 1
        if ($hint) { $hint.Text = Get-LocalizedString -Key 'Manage.KeyboardPositionHint' -Values $values }
    }
}

function Get-ManageKeyboardPageStep {
    param($Row)
    $bar = if ($Row -and $Row.Parent -and $Row.Parent.Parent) { $Row.Parent.Parent.Controls['EntryScroll'] } else { $null }
    if (-not $bar -or $bar.SmallChange -le 0) { return 1 }
    return [Math]::Max(1,[int][Math]::Floor([double]$bar.LargeChange / [double]$bar.SmallChange))
}

function Invoke-ManageRowKeyboardMove {
    param($Row,[System.Windows.Forms.Keys]$Key,[bool]$Reorder)
    $entries = @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)
    $index = -1
    for ($i=0; $i -lt $entries.Count; $i++) {
        if ([string]$entries[$i].Guid -eq [string]$Row.Tag) { $index=$i; break }
    }
    if ($index -lt 0) { return }
    $pageStep = Get-ManageKeyboardPageStep -Row $Row
    $target = switch ($Key) {
        ([System.Windows.Forms.Keys]::Up) { [Math]::Max(0,$index-1); break }
        ([System.Windows.Forms.Keys]::Down) { [Math]::Min($entries.Count-1,$index+1); break }
        ([System.Windows.Forms.Keys]::PageUp) { [Math]::Max(0,$index-$pageStep); break }
        ([System.Windows.Forms.Keys]::PageDown) { [Math]::Min($entries.Count-1,$index+$pageStep); break }
        ([System.Windows.Forms.Keys]::Home) { 0; break }
        ([System.Windows.Forms.Keys]::End) { $entries.Count-1; break }
        default { $index }
    }
    if ($target -eq $index) { return }
    if ($Reorder) {
        $guid = [string]$Row.Tag
        $editCue = [bool]$Row.ManageEditCueActive
        Move-ManageEntry -MovedGuid $guid -TargetGuid ([string]$entries[$target].Guid) -After:($target -gt $index)
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.KeyboardPosition' -Values @{Position=($target+1);Count=$entries.Count}
        Update-PopupRows -Reason 'manage-keyboard-reorder'
        Restore-ManageRowFocus -Guid $guid -EditCue:$editCue
    }
    else {
        if ($Key -in @([Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown)) {
            $bar = $Row.Parent.Parent.Controls['EntryScroll']
            if ($bar -and $bar.Visible) {
                $direction = if ($Key -eq [Windows.Forms.Keys]::PageUp) { -1 } else { 1 }
                $bar.Value = $bar.Value + ($direction * $pageStep * $bar.SmallChange)
            }
        }
        Restore-ManageRowFocus -Guid ([string]$entries[$target].Guid) -KeyboardCue:$true
    }
}

function Connect-ManageRowKeyboard {
    param($Row)
    $Row.Add_ManageEditCueChanged({
        param($sender,$eventArgs)
        foreach ($name in @('ManageReorderGrip','AliasEditButton')) {
            $glyph = $sender.Controls[$name]
            if ($glyph -and -not $glyph.IsDisposed) { Update-ManageEditGlyphInk -Control $glyph }
        }
    })
    $Row.Add_GotFocus({
        param($sender,$eventArgs)
        Set-NormalBootRowVisible -Row $sender
        Update-ManageKeyboardRowPresentation -Row $sender
    })
    $Row.Add_LostFocus({
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $hint = $script:Popup.Controls.Find('ManageKeyboardHint',$true) | Select-Object -First 1
            if ($hint) { $hint.Text = Get-LocalizedString -Key 'Manage.KeyboardHint' }
        }
    })
    $Row.Add_KeyDown({
        param($sender,$eventArgs)
        if (-not (Test-ManageRowKeyboardAdmission -Row $sender)) {
            Update-ManageKeyboardEditCue -Row $sender -Active:$false
            return
        }
        $key=$eventArgs.KeyCode
        $modifiers=$eventArgs.Modifiers
        $controlKey = $key -in @([Windows.Forms.Keys]::ControlKey,[Windows.Forms.Keys]::LControlKey,[Windows.Forms.Keys]::RControlKey)
        Update-ManageKeyboardEditCue -Row $sender -Active:($modifiers -eq [Windows.Forms.Keys]::Control -or ($controlKey -and $modifiers -eq [Windows.Forms.Keys]::None))
        if ($modifiers -eq [Windows.Forms.Keys]::None -and $key -in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End,[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown)) {
            $eventArgs.SuppressKeyPress=$true
            Invoke-ManageRowKeyboardMove -Row $sender -Key $key -Reorder:$false
        }
        elseif ($modifiers -eq [Windows.Forms.Keys]::Control -and $key -in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End,[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown)) {
            $eventArgs.SuppressKeyPress=$true
            Invoke-ManageRowKeyboardMove -Row $sender -Key $key -Reorder:$true
        }
        elseif ($modifiers -eq [Windows.Forms.Keys]::None -and $key -eq [Windows.Forms.Keys]::Space) {
            # SuppressKeyPress would also suppress KeyUp. Arm once until release.
            $eventArgs.Handled=$true
            $sender.ManageSpaceArmed=$true
        }
        elseif ($modifiers -eq [Windows.Forms.Keys]::Control -and $key -eq [Windows.Forms.Keys]::E) {
            $eventArgs.SuppressKeyPress=$true
            Update-ManageKeyboardEditCue -Row $sender -Active:$false
            Start-ManageRowAliasEdit -Guid ([string]$sender.Tag)
        }
        elseif ($modifiers -eq [Windows.Forms.Keys]::None -and $key -eq [Windows.Forms.Keys]::Enter) {
            $eventArgs.SuppressKeyPress=$true
        }
    })
    $Row.Add_KeyUp({
        param($sender,$eventArgs)
        if ($eventArgs.KeyCode -in @([Windows.Forms.Keys]::ControlKey,[Windows.Forms.Keys]::LControlKey,[Windows.Forms.Keys]::RControlKey) -or $eventArgs.Modifiers -ne [Windows.Forms.Keys]::Control) {
            Update-ManageKeyboardEditCue -Row $sender -Active:$false
        }
        if ($eventArgs.KeyCode -ne [Windows.Forms.Keys]::Space) { return }
        $armed=$sender.ManageSpaceArmed
        $sender.ManageSpaceArmed=$false
        if (-not $armed -or $eventArgs.Modifiers -ne [Windows.Forms.Keys]::None -or -not (Test-ManageRowKeyboardAdmission -Row $sender)) { return }
        $eventArgs.Handled=$true
        $guid=[string]$sender.Tag
        Invoke-ManageRowVisibility -Guid $guid
        Restore-ManageRowFocus -Guid $guid
    })
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

if ($aliasEditActive) {
    $row = New-Object System.Windows.Forms.Panel
    $row.TabStop = $false
}
else {
    Initialize-NormalBootKeyboardRow
    $row = New-Object LenovoNormalBootKeyboardRow
    $row.ManageKeyboardMode = [bool]$script:IsManageEntriesMode
}
$row.Name = 'BootRow'
$row.Tag = $entry.Guid
$row.Location = New-Object Drawing.Point(0, $y)
$row.Size = New-Object Drawing.Size(390, $rowHeight)
$row.BackColor = $script:ColorRow
$row.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$row.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
if ($script:IsManageEntriesMode) { $row.Add_Paint({ param($sender,$eventArgs) Paint-ManageDropCue -Row $sender -Graphics $eventArgs.Graphics }) }

$isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
$rowDisplay = if ($script:IsManageEntriesMode) { 'idle' } else { Resolve-BootNextRowDisplayCore -EntryGuid $entry.Guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid }
$isSelected = ($rowDisplay -eq 'selected')
$isPending = ($rowDisplay -eq 'pending')
if ($isPending) { $row.BackColor = [Drawing.Color]::FromArgb(46,40,27) }
elseif ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

$marker = New-Object System.Windows.Forms.Panel
$marker.Location = New-Object Drawing.Point(0, 0)
$marker.Size = New-Object Drawing.Size(3, $rowHeight)
$marker.BackColor = $script:ColorRow
if ($isPending) { $marker.BackColor = $script:ColorWarning }
elseif ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
elseif ($isHidden) { $marker.BackColor = [Drawing.Color]::FromArgb(70,70,70) }
$marker.Tag = $entry.Guid
$marker.AllowDrop = $script:IsManageEntriesMode
$row.Controls.Add($marker)

$iconColor = if ($isHidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $entry.Accent }
$titleColor = if ($isHidden) { [Drawing.Color]::FromArgb(175,175,175) } else { $script:ColorPrimary }
$subtitleColor = if ($isHidden) { [Drawing.Color]::FromArgb(155,155,155) } else { $script:ColorSecondary }

$icon = New-Label -Text $entry.Symbol -Font (New-Object Drawing.Font('Segoe UI Symbol', 18, [Drawing.FontStyle]::Regular)) `
    -ForeColor $iconColor -X 22 -Y 7 -Width 28 -Height 44
$icon.Name = 'BootTypeGlyph'
$icon.Tag = $entry.Guid
$icon.Cursor = [System.Windows.Forms.Cursors]::Hand
$icon.AllowDrop = $script:IsManageEntriesMode
if ($script:BootTypeToolTip -and $entry.TypeTooltip) {
    $typeHint = [string]$entry.TypeTooltip
    if ($isHidden) { $typeHint += [Environment]::NewLine + (Get-LocalizedString -Key 'Tooltip.HiddenType') }
    $icon.AccessibleDescription = $typeHint
    $script:BootTypeToolTip.SetToolTip($icon, $typeHint)
    # Native SetToolTip proved unreliable on the transparent symbol label
    # on the target PC. MouseHover explicitly shows the same tooltip and
    # MouseLeave closes it, while the semantic text remains on the circle only.
    $icon.Add_MouseHover({
        param($sender, $eventArgs)
        try {
            $text = [string]$script:BootTypeToolTip.GetToolTip($sender)
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
$rowText = Get-BootEntryRowText -Entry $entry
$titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
$titleText = [string]$rowText.Title
if (-not $script:IsManageEntriesMode) {
    $row.AccessibleRole = [System.Windows.Forms.AccessibleRole]::PushButton
    $row.AccessibleName = [string]$rowText.Title
    $row.AccessibleDescription = [string]$rowText.Subtitle
}
elseif (-not $aliasEditActive) {
    $row.AccessibleRole = [System.Windows.Forms.AccessibleRole]::ListItem
    $row.AccessibleName = [string]$rowText.Title
    $row.AccessibleDescription = Get-LocalizedString -Key 'Manage.KeyboardInstructions'
}
$title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
    -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
$title.Name = 'BootTitleLabel'
# At high DPI, WinForms AutoEllipsis can suppress the entire label if its
# vertical rectangle is considered insufficient. Keep text visible; the
# full name is also available in the tooltip and accessible description.
$title.AutoEllipsis = $false
$title.AccessibleDescription = [string]$titleText
if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title, [string]$titleText) }
$title.Tag = $entry.Guid
$title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
$row.Controls.Add($title)

$subtitle = $null
if (-not $aliasEditActive) {
    $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
    $subtitleText = [string]$rowText.Subtitle
    $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $subtitleColor -X 58 -Y 28 -Width $subtitleWidth -Height 26
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.AutoEllipsis = $false
    $subtitle.AccessibleDescription = [string]$subtitleText
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle, [string]$subtitleText) }
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
        Update-NormalBootEntryTooltips -Row $row -Entry $entry
    }

    if ($rowControls.Count -gt 0) {
        Connect-BootEntryRowInteractions -RowControls $rowControls -Handlers $Handlers
    }

    if ($script:IsManageEntriesMode -and -not $aliasEditActive) {
        Connect-ManageRowKeyboard -Row $row
    }
    if (-not $script:IsManageEntriesMode) {
        # Input keys are supplied by LenovoNormalBootKeyboardRow, not by
        # intercepting global Form shortcuts or the Manage Entries editor.
        $row.Add_KeyDown({
            param($sender,$eventArgs)
            if ($script:IsManageEntriesMode -or
                $eventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None) { return }
            $key = $eventArgs.KeyCode
            if ($key -in @([System.Windows.Forms.Keys]::Up,
                           [System.Windows.Forms.Keys]::Down,
                           [System.Windows.Forms.Keys]::Home,
                           [System.Windows.Forms.Keys]::End)) {
                Move-NormalBootKeyboardFocus -Row $sender -Key $key
                $eventArgs.Handled = $true
                $eventArgs.SuppressKeyPress = $true
            }
            elseif ($key -eq [System.Windows.Forms.Keys]::Return -or
                    $key -eq [System.Windows.Forms.Keys]::Space) {
                # Arm exactly one selection for the matching KeyUp. Do not
                # SuppressKeyPress: WinForms also suppresses KeyUp for that
                # physical keystroke (Microsoft keyboard event contract).
                $eventArgs.Handled = $true
                $script:NormalBootActivationArmedRow = $sender
                $script:NormalBootActivationArmedKey = $key
            }
        })
        $row.Add_KeyUp({
            param($sender,$eventArgs)
            $armed = [object]::ReferenceEquals($script:NormalBootActivationArmedRow,$sender) -and
                ($script:NormalBootActivationArmedKey -eq $eventArgs.KeyCode)
            if ($armed) {
                $script:NormalBootActivationArmedRow = $null
                $script:NormalBootActivationArmedKey = [System.Windows.Forms.Keys]::None
            }
            if ($script:IsManageEntriesMode -or
                $eventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None -or -not $armed) { return }
            if (($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Return -or
                 $eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Space) -and
                $sender.Focused) {
                $eventArgs.Handled = $true
                Invoke-NormalBootTargetSelection -Guid ([string]$sender.Tag)
            }
        })
        $row.Add_LostFocus({
            param($sender,$eventArgs)
            if ([object]::ReferenceEquals($script:NormalBootActivationArmedRow,$sender)) {
                $script:NormalBootActivationArmedRow = $null
                $script:NormalBootActivationArmedKey = [System.Windows.Forms.Keys]::None
            }
        })
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
$ContentPanel.Size = New-Object Drawing.Size($ListPanel.ClientSize.Width, $contentHeight)
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
        if ($script:ManageActiveDragGuid -and $rowGuid -eq $script:ManageActiveDragGuid -and $script:ManageDragLayout) {
            $row.BackColor = [Drawing.Color]::FromArgb(48,48,54)
            return
        }
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
    $isPending = $script:BootNextPendingGuid -and ($rowGuid -eq $script:BootNextPendingGuid)
    if ($isPending) { $row.BackColor = [Drawing.Color]::FromArgb(46,40,27) }
    elseif ($isSelected) {
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

# A row's presentation identity deliberately excludes refresh timestamps, diagnostics and
# status text. Firmware metadata matters only when it can affect a rendered row.
# The raw canonical data never leaves this function; diagnostics use SHA-256 only.
function Get-PopupRowsPresentationState {
    param([Parameter(Mandatory=$true)][double]$Scale)

    $manage = [bool]$script:IsManageEntriesMode
    $entries = if ($manage) { @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft) } else { @(Get-OrderedEntriesForUi) }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $entries) {
        $guid = ([string]$entry.Guid).ToLowerInvariant()
        $alias = Get-EntryAlias -Guid $guid -UseManageDraft:$manage
        $title = Get-EntryDisplayTitle -Entry $entry -UseManageDraft:$manage
        $accent = if ($null -ne $entry.Accent) { [int]$entry.Accent.ToArgb() } else { 0 }
        [void]$rows.Add([ordered]@{
            guid = $guid
            title = [string]$entry.Title
            subtitle = [string]$entry.Subtitle
            rawDescription = [string]$entry.RawDescription
            symbol = [string]$entry.Symbol
            typeTooltip = [string]$entry.TypeTooltip
            accent = $accent
            displayTitle = [string]$title
            alias = [string]$alias
            hidden = [bool]($manage -and (Test-ManageEntryHidden -Guid $guid))
            selected = [bool](-not $manage -and $script:SelectedGuid -and $guid -eq $script:SelectedGuid)
            pending = [bool](-not $manage -and $script:BootNextPendingGuid -and $guid -eq $script:BootNextPendingGuid)
            editing = [bool]($manage -and $script:ManageAliasEditGuid -and $guid -eq $script:ManageAliasEditGuid)
        })
    }
    # These translated strings appear within rows and may change without a
    # firmware data change. The status/header themselves are updated separately.
    $localized = @(
        (Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name = '' }),
        (Get-LocalizedString -Key 'Manage.OriginalNameHint'),
        (Get-LocalizedString -Key 'Manage.HiddenAccessible'),
        (Get-LocalizedString -Key 'Manage.VisibleAccessible'),
        (Get-LocalizedString -Key 'Manage.ReorderHint'),
        (Get-LocalizedString -Key 'Manage.KeyboardInstructions'),
        (Get-LocalizedString -Key 'Manage.KeyboardPosition' -Values @{Position=1;Count=1}),
        (Get-LocalizedString -Key 'Manage.ClearAliasHint'),
        (Get-LocalizedString -Key 'Manage.AliasCue'),
        (Get-LocalizedString -Key 'Manage.AliasFieldHint'),
        (Get-LocalizedString -Key 'Boot.MenuManageSubtitle'),
        (Get-LocalizedString -Key 'BootNext.SelectionPending'),
        (Get-LocalizedString -Key 'BootNext.RowPendingHint'),
        (Get-LocalizedString -Key 'BootNext.RowSelectedHint')
    )
    $presentation = [ordered]@{
        scale = [Math]::Round($Scale, 4)
        manage = $manage
        selectedGuid = if ($manage) { '' } else { [string]$script:SelectedGuid }
        pendingGuid = if ($manage) { '' } else { [string]$script:BootNextPendingGuid }
        aliasEditGuid = if ($manage) { [string]$script:ManageAliasEditGuid } else { '' }
        localized = $localized
        rows = $rows.ToArray()
    }
    $identity = ConvertTo-Json -InputObject $presentation -Depth 6 -Compress
    $rowSignatures = @{}
    $rowStructureSignatures = @{}
    foreach ($row in $rows.ToArray()) {
        $rowSignatures[[string]$row.guid] = ConvertTo-Json -InputObject ([ordered]@{
            manage = $manage
            localized = $localized
            row = $row
        }) -Depth 6 -Compress
        # Title, subtitle, raw description and computed display title are text-only.
        $rowStructureSignatures[[string]$row.guid] = ConvertTo-Json -InputObject ([ordered]@{
            manage = $manage
            localized = $localized
            guid = $row.guid
            symbol = $row.symbol
            typeTooltip = $row.typeTooltip
            accent = $row.accent
            alias = $row.alias
            hidden = $row.hidden
            selected = $row.selected
            pending = $row.pending
            editing = $row.editing
        }) -Depth 6 -Compress
    }
    $globalSignature = ConvertTo-Json -InputObject ([ordered]@{
        scale = $presentation.scale
        manage = $presentation.manage
        selectedGuid = $presentation.selectedGuid
        pendingGuid = $presentation.pendingGuid
        aliasEditGuid = $presentation.aliasEditGuid
        localized = $localized
    }) -Depth 6 -Compress
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $fingerprint = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)))).Replace('-', '')
    }
    finally { $hash.Dispose() }
    return [pscustomobject]@{
        Identity = $identity
        Fingerprint = $fingerprint
        Entries = $entries
        EntryCount = $entries.Count
        RowSignatures = $rowSignatures
        RowStructureSignatures = $rowStructureSignatures
        GlobalSignature = $globalSignature
        Mode = $manage
        Scale = $Scale
    }
}

function Update-PopupRowsPeripheralUi {
    param($StatusLabel)
    if ($StatusLabel) { $StatusLabel.Text = $script:LastStatusText }
    if ($script:IsManageEntriesMode -and $script:Popup) {
        $focused = $script:Popup.Controls.Find('BootRow',$true) | Where-Object { $_.Focused -and $_.TabStop } | Select-Object -First 1
        if ($focused) { Update-ManageKeyboardRowPresentation -Row $focused }
    }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-ManageSaveButtonState
    Update-MaintenanceUi
}

function Write-PopupRowsRenderDiagnostic {
    param([string]$Reason, [string]$Before, [string]$After, [int]$EntryCount,
          [bool]$ActiveDrag, [bool]$Skipped, [bool]$Deferred,
          [int]$AffectedCount = 0, [bool]$LayoutUpdated = $false,
          [int]$RebuiltCount = 0, [int]$UpdatedInPlaceCount = 0)
    try {
        Write-RuntimeDiagnosticEvent -Event 'POPUP_ROWS_PRESENTATION' -Stage 'presentation' -Success $true -Data (New-RuntimeDiagnosticData @{
            reason = $Reason
            beforeFingerprint = $Before
            afterFingerprint = $After
            entryCount = $EntryCount
            affectedEntryCount = $AffectedCount
            updatedInPlaceCount = $UpdatedInPlaceCount
            rebuiltEntryCount = $RebuiltCount
            layoutUpdated = $LayoutUpdated
            activeDrag = $ActiveDrag
            skipped = $Skipped
            deferred = $Deferred
            rebuilt = (-not $Skipped -and -not $Deferred -and $RebuiltCount -gt 0)
        })
    }
    catch { Write-Verbose 'Popup row presentation diagnostic unavailable.' }
}

function Save-PopupRowsRenderedSnapshot {
    param($ListPanel,$ContentPanel,$Snapshot)
    $script:PopupRowsContentPanel = $ContentPanel
    $script:PopupRowsIdentity = $Snapshot.Identity
    $script:PopupRowsFingerprint = $Snapshot.Fingerprint
    $script:PopupRowsRowSignatures = $Snapshot.RowSignatures
    $script:PopupRowsRowStructureSignatures = $Snapshot.RowStructureSignatures
    $script:PopupRowsGlobalSignature = $Snapshot.GlobalSignature
    $script:PopupRowsRenderedMode = $Snapshot.Mode
    $script:PopupRowsRenderedScale = $Snapshot.Scale
    $script:PopupRowsViewportHeight = $ListPanel.ClientSize.Height
    $script:PopupRowsRenderedAliasEditGuid = if ($script:IsManageEntriesMode) { [string]$script:ManageAliasEditGuid } else { '' }
}

# -1 requests the existing keyed reconstruction path instead of text-only reuse.
# Validate every visible row before modifying any control (all-or-nothing gate).
function Invoke-PopupRowsTextReconciliation {
    param($ListPanel,$ContentPanel,$Snapshot,[object[]]$ExistingRows)
    if (-not [object]::ReferenceEquals($script:PopupRowsContentPanel,$ContentPanel) -or
        ([bool]$script:PopupRowsRenderedMode -ne [bool]$Snapshot.Mode) -or
        ([double]$script:PopupRowsRenderedScale -ne [double]$Snapshot.Scale) -or
        ([string]$script:PopupRowsGlobalSignature -cne [string]$Snapshot.GlobalSignature) -or
        ($script:PopupRowsRowSignatures -isnot [hashtable]) -or
        ($script:PopupRowsRowStructureSignatures -isnot [hashtable]) -or
        $ExistingRows.Count -ne $Snapshot.EntryCount -or
        $script:PopupRowsViewportHeight -ne $ListPanel.ClientSize.Height) { return -1 }

    $orderedRows = @($ExistingRows | Sort-Object Top)
    for ($i = 0; $i -lt $Snapshot.EntryCount; $i++) {
        $row = $orderedRows[$i]
        $guid = ([string]$Snapshot.Entries[$i].Guid).ToLowerInvariant()
        if ($row.IsDisposed -or ([string]$row.Tag).ToLowerInvariant() -cne $guid -or
            -not $script:PopupRowsRowStructureSignatures.ContainsKey($guid) -or
            -not $script:PopupRowsRowSignatures.ContainsKey($guid) -or
            [string]$script:PopupRowsRowStructureSignatures[$guid] -cne [string]$Snapshot.RowStructureSignatures[$guid] -or
            @($row.Controls.Find('BootTitleLabel',$false)).Count -ne 1 -or
            @($row.Controls.Find('BootSubtitleLabel',$false)).Count -ne 1) { return -1 }
    }

    $updated = 0
    for ($i = 0; $i -lt $Snapshot.EntryCount; $i++) {
        $entry = $Snapshot.Entries[$i]
        $guid = ([string]$entry.Guid).ToLowerInvariant()
        if ([string]$script:PopupRowsRowSignatures[$guid] -cne [string]$Snapshot.RowSignatures[$guid]) {
            if (Update-BootEntryRowText -Row $orderedRows[$i] -Entry $entry) { $updated++ }
        }
    }
    Save-PopupRowsRenderedSnapshot -ListPanel $ListPanel -ContentPanel $ContentPanel -Snapshot $Snapshot
    return [int]$updated
}


# UX01-V8: snapshot only an actually focused normal boot target. A stale
# previously focused GUID must never pull focus away from another UI action.
function Get-NormalBootFocusedGuid {
    param($ContentPanel)
    if ($script:IsManageEntriesMode -or -not $ContentPanel -or $ContentPanel.IsDisposed) { return '' }
    foreach ($row in @($ContentPanel.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed
    })) {
        if ($row.Focused) { return [string]$row.Tag }
    }
    return ''
}

function Restore-NormalBootFocusedGuid {
    param($ContentPanel,[string]$Guid,[Nullable[bool]]$KeyboardCue)
    if ($script:IsManageEntriesMode -or -not $Guid -or -not $ContentPanel -or $ContentPanel.IsDisposed) { return }
    foreach ($row in @($ContentPanel.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed
    })) {
        if (([string]$row.Tag).ToLowerInvariant() -eq $Guid.ToLowerInvariant()) {
            if ($null -ne $KeyboardCue -and $row.PSObject.Methods['SetKeyboardCue']) { $row.SetKeyboardCue([bool]$KeyboardCue) }
            [void]$row.Focus()
            Set-NormalBootRowVisible -Row $row
            return
        }
    }
}

function Invoke-PopupRowsReconciliation {
    param(
        $ListPanel, $ContentPanel, $ScrollBar, $Snapshot,
        [double]$Scale, [object[]]$ExistingRows, [bool]$ActiveDrag
    )

    $script:PopupRowsRefreshPending = $false
    $script:PopupRowsViewportPending = $false
    $focusedNormalGuid = if (-not $Snapshot.Mode) {
        Get-NormalBootFocusedGuid -ContentPanel $ContentPanel
    } else { '' }
    $focusedNormalRow = if ($focusedNormalGuid) { $existingRows | Where-Object { $_.Focused -and [string]$_.Tag -eq $focusedNormalGuid } | Select-Object -First 1 }
    $normalCue = if ($focusedNormalRow -and $focusedNormalRow.PSObject.Properties['KeyboardCueEnabled']) { [bool]$focusedNormalRow.KeyboardCueEnabled } else { $true }
    $manageAnchor = if ($Snapshot.Mode -and $script:PopupRowsRenderedMode) { $existingRows | Where-Object { $_.TabStop -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode } | Select-Object -First 1 }
    $manageAnchorGuid = if ($manageAnchor) { [string]$manageAnchor.Tag } else { '' }
    $manageAnchorIndex = if ($manageAnchor) { [int]$manageAnchor.TabIndex } else { 0 }
    $focusedManageRow = if ($Snapshot.Mode -and $script:PopupRowsRenderedMode) {
        $existingRows | Where-Object { $_.Focused -and $_.TabStop } | Select-Object -First 1
    }
    $focusedManageGuid = if ($focusedManageRow) { [string]$focusedManageRow.Tag } else { '' }
    $focusedManageIndex = if ($focusedManageRow) { [int]$focusedManageRow.TabIndex } else { -1 }
    $manageCue = if ($focusedManageRow -and $focusedManageRow.PSObject.Properties['KeyboardCueEnabled']) { [bool]$focusedManageRow.KeyboardCueEnabled } else { $true }
    $manageEditCue = [bool]($focusedManageRow -and $focusedManageRow.PSObject.Properties['ManageEditCueActive'] -and $focusedManageRow.ManageEditCueActive -and -not $activeDrag -and -not $script:ManageAliasEditGuid)
    if ($activeDrag) { Reset-ManageDragPreview }
    $previousSignatures = $script:PopupRowsRowSignatures
    $canReconcile = [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel) -and
        ([bool]$script:PopupRowsRenderedMode -eq $snapshot.Mode) -and
        ([double]$script:PopupRowsRenderedScale -eq $snapshot.Scale) -and
        ($previousSignatures -is [hashtable])
    $oldRows = @{}
    if ($canReconcile) {
        foreach ($row in $existingRows) {
            $guid = ([string]$row.Tag).ToLowerInvariant()
            if ($oldRows.ContainsKey($guid)) { $canReconcile = $false; break }
            $oldRows[$guid] = $row
        }
    }

    $affected = 0
    $contentPanel.SuspendLayout()
    try {
        if (-not $canReconcile) {
            $affected = $existingRows.Count
            $contentPanel.Controls.Clear()
        }
        $baseRowHeight = 60
        $scaledRowHeight = [int][Math]::Round($baseRowHeight * $scale)
        $rowGap = [int][Math]::Round(4 * $scale)
        $y = 0
        $keyboardTabIndex = 0
        $handlers = New-BootEntryInteractionHandlers
        if ($script:ManageContentDropPanel -ne $contentPanel) {
            $contentPanel.Add_DragEnter($handlers.DragEnter)
            $contentPanel.Add_DragOver($handlers.DragOver)
            $contentPanel.Add_DragLeave($handlers.DragLeave)
            $contentPanel.Add_DragDrop($handlers.DragDrop)
            $script:ManageContentDropPanel = $contentPanel
        }
        $contentPanel.AllowDrop = [bool]$script:IsManageEntriesMode

        foreach ($entry in $snapshot.Entries) {
            $guid = ([string]$entry.Guid).ToLowerInvariant()
            $row = $null
            if ($canReconcile -and $oldRows.ContainsKey($guid)) {
                $prior = $oldRows[$guid]
                if ($previousSignatures.ContainsKey($guid) -and
                    [string]$previousSignatures[$guid] -ceq [string]$snapshot.RowSignatures[$guid]) {
                    $row = $prior
                }
                else {
                    $contentPanel.Controls.Remove($prior)
                    $prior.Dispose()
                    $affected++
                }
                [void]$oldRows.Remove($guid)
            }
            if ($null -eq $row) {
                $rendered = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight $baseRowHeight -Handlers $handlers
                $row = $rendered.Row
                $height = Set-PopupBootRowDpiLayout -Row $row -Scale $scale -Y $y
                $contentPanel.Controls.Add($row)
                $affected++
            }
            else {
                # Reused rows are already physically scaled; never scale twice.
                $row.Location = [Drawing.Point]::new(0, $y)
                $height = $row.Height
            }
            # A stable visual Tab order even when Controls are reused.
            $row.TabIndex = $keyboardTabIndex
            $keyboardTabIndex++
            $y += ($height + $rowGap)
        }
        if ($canReconcile) {
            foreach ($orphan in @($oldRows.Values)) {
                $contentPanel.Controls.Remove($orphan)
                $orphan.Dispose()
                $affected++
            }
        }

        Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $y -BaseRowHeight $scaledRowHeight -RowGap $rowGap

        Save-PopupRowsRenderedSnapshot -ListPanel $listPanel -ContentPanel $contentPanel -Snapshot $snapshot
    }
    finally { $contentPanel.ResumeLayout() }
    # Restore only if a normal row really owned focus before reconciliation.
    # Switching to Restart/settings/Manage Entries must never steal focus.
    Restore-NormalBootFocusedGuid -ContentPanel $ContentPanel -Guid $focusedNormalGuid -KeyboardCue:$normalCue
    if ($Snapshot.Mode) {
        $manageRows = @($ContentPanel.Controls | Where-Object { $_.Name -eq 'BootRow' -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode } | Sort-Object Top)
        foreach ($row in $manageRows) { Update-ManageKeyboardRowPresentation -Row $row }
        $anchor = $manageRows | Where-Object { [string]$_.Tag -eq $manageAnchorGuid } | Select-Object -First 1
        if (-not $anchor -and $manageRows.Count -gt 0) { $anchor = $manageRows[[Math]::Min($manageAnchorIndex,$manageRows.Count-1)] }
        if ($anchor) { $anchor.SetManageTabAnchor() }
        if ($focusedManageGuid -and -not $script:ManageAliasEditGuid) {
            Restore-ManageRowFocus -Guid $focusedManageGuid -FallbackIndex $focusedManageIndex -KeyboardCue:$manageCue -EditCue:$manageEditCue
        }
    }
    return [int]$affected
}

function Update-PopupRows {
    param([string]$Reason = 'caller')
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    if ($Reason -eq 'caller') {
        # Resolve unannotated legacy callers without modifying protected sources.
        $callerFrame = @(Get-PSCallStack | Select-Object -Skip 1 -First 1)
        if ($callerFrame.Count -gt 0 -and $callerFrame[0].Command) {
            $Reason = [string]$callerFrame[0].Command
        }
    }

    $listMatches = $script:Popup.Controls.Find('EntryList', $true)
    $listPanel = if ($listMatches.Count -gt 0) { $listMatches[0] } else { $null }
    $contentPanel = if ($listPanel) { $listPanel.Controls['EntryContent'] } else { $null }
    $scrollBar = if ($listPanel) { $listPanel.Controls['EntryScroll'] } else { $null }
    $statusMatches = $script:Popup.Controls.Find('StatusLabel', $true)
    $statusLabel = if ($statusMatches.Count -gt 0) { $statusMatches[0] } else { $null }
    if (-not $listPanel -or -not $contentPanel) { return }

    # The current mode/viewport can change without invalidating any row.
    Update-ManageEntriesUiState
    $scale = Get-PopupDpiLayoutScale -Popup $script:Popup
    $snapshot = Get-PopupRowsPresentationState -Scale $scale
    $before = [string]$script:PopupRowsFingerprint
    $activeDrag = [bool]$script:ManageActiveDragGuid
    $existingRows = @($contentPanel.Controls | Where-Object { $_.Name -eq 'BootRow' -and -not $_.IsDisposed })
    $same = [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel) -and
            ([string]$script:PopupRowsIdentity -ceq $snapshot.Identity) -and
            $existingRows.Count -eq $snapshot.EntryCount
    if ($same) {
        # A verified/pending state can change without altering row geometry or
        # metadata. Refresh semantic hints in place; unchanged bindings are no-ops.
        if (-not $script:IsManageEntriesMode -and $script:BootTypeToolTip) {
            $entryByGuid = @{}
            foreach ($entry in $snapshot.Entries) { $entryByGuid[[string]$entry.Guid] = $entry }
            foreach ($row in $existingRows) {
                $entry = $entryByGuid[[string]$row.Tag]
                if ($entry) { Update-NormalBootEntryTooltips -Row $row -Entry $entry }
            }
        }
        $script:PopupRowsRefreshPending = $false
        $viewportChanged = ($script:PopupRowsViewportHeight -ne $listPanel.ClientSize.Height)
        if ($viewportChanged -and $activeDrag) {
            # Do not disturb an animated placeholder with a scroll range change.
            $script:PopupRowsViewportPending = $true
        }
        elseif ($viewportChanged) {
            $gap = [int][Math]::Round(4 * $scale)
            $bottom = 0
            foreach ($row in $existingRows) { $bottom = [Math]::Max($bottom, $row.Bottom + $gap) }
            Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $bottom -BaseRowHeight ([int][Math]::Round(60 * $scale)) -RowGap $gap
            $script:PopupRowsViewportHeight = $listPanel.ClientSize.Height
            $script:PopupRowsViewportPending = $false
        }
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $true -Deferred $false -LayoutUpdated ($viewportChanged -and -not $activeDrag)
        return
    }

    # WinForms DoDragDrop uses nested message processing. A worker completion can
    # arrive while the source row and animated placeholder are still in use.
    # Never dispose/recreate those controls until the interaction has ended.
    $editingExistingAlias = $script:IsManageEntriesMode -and $script:ManageAliasEditGuid -and
        ([string]$script:PopupRowsRenderedAliasEditGuid -eq [string]$script:ManageAliasEditGuid)
    if ($script:IsManageEntriesMode -and ($activeDrag -or $editingExistingAlias) -and
        [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel)) {
        $script:PopupRowsRefreshPending = $true
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $false -Deferred $true
        return
    }

    $textUpdated = Invoke-PopupRowsTextReconciliation -ListPanel $listPanel -ContentPanel $contentPanel -Snapshot $snapshot -ExistingRows $existingRows
    if ($textUpdated -ge 0) {
        # A deferred drag/editor refresh is complete after successful in-place
        # reconciliation. Clear the pending flags exactly as a full reconcile does.
        $script:PopupRowsRefreshPending = $false
        $script:PopupRowsViewportPending = $false
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped ($textUpdated -eq 0) -Deferred $false -AffectedCount $textUpdated -UpdatedInPlaceCount $textUpdated
        return
    }

    $affected = Invoke-PopupRowsReconciliation -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -Snapshot $snapshot -Scale $scale -ExistingRows $existingRows -ActiveDrag $activeDrag
    Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
    Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $false -Deferred $false -AffectedCount $affected -LayoutUpdated $true -RebuiltCount $affected
}



function Apply-FirmwareBootState {
    param([Parameter(Mandatory=$true)]$State, [switch]$VerifiedFresh)
    if ($script:BootNextPendingGuid) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_RESULT_DEFERRED_FOR_BOOTNEXT' -Stage 'bootnext' -Success $true
        return
    }

    $script:CurrentEntries = @($State.Entries)
    $script:SelectedGuid = if ($State.SelectedGuid) { $State.SelectedGuid.ToLowerInvariant() } else { $null }
    $script:NextBootFirmwareReadVerified = [bool]$VerifiedFresh
    $script:SystemStatusNextObservedUtc = if ($VerifiedFresh) { $script:SystemStatusManagerObservedUtc } else { $null }

    if ($script:SelectedGuid) {
        $selected = Get-EntryByGuid $script:SelectedGuid
        $script:LastStatusText = if ($selected) { Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $selected) } } else { Get-LocalizedString -Key 'Status.OneTimeNextBootSet' }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.NoOneTimeNextBoot'
    }

    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ($capabilities.CanUseCachedBootState) { [void](Refresh-SystemDefaultState) }
    if ($null -ne $script:ManageUndoHistory) { Update-ManageUndoInventory }
    Update-PopupRows -Reason 'firmware-state'
}

function Refresh-BootState {
    param([switch]$RefreshStorage)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($RefreshStorage) {
        $script:ManagerCacheText = $null
        $script:FirmwareCacheText = $null
    }
    try {
        $state = Get-FirmwareBootState -RefreshStorage:$RefreshStorage -ForceManagerRefresh
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state -VerifiedFresh
        $script:SystemStatusLastRefresh = 'success'
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage; entryCount = @($state.Entries).Count; selectedGuid = $state.SelectedGuid })
    }
    catch {
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusLastRefresh = 'error'
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

# Lenovo Boot Selector - popup section composition.
# Domain-specific WinForms builders extracted from New-PopupForm by LBS-29.

# Keep native Button rendering for every active-owner state. This overlay
# is presentation-only and exists only for the auxiliary modal lifetime.
function Paint-ModalOwnerRefreshGlyph {
    param([Windows.Forms.Button]$Button,[Windows.Forms.PaintEventArgs]$EventArgs)
    if (-not $script:ActiveAuxiliaryPopup -or [Windows.Forms.SystemInformation]::HighContrast) { return }
    $brush = [Drawing.SolidBrush]::new($Button.BackColor)
    try { $EventArgs.Graphics.FillRectangle($brush,$Button.ClientRectangle) }
    finally { $brush.Dispose() }
    $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPrefix
    $ink = if ($Button.Enabled) { $Button.ForeColor } else { [Drawing.SystemColors]::GrayText }
    [Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics,$Button.Text,$Button.Font,$Button.ClientRectangle,$ink,$flags)
}

function Add-PopupHeaderSection {
    param([Parameter(Mandatory=$true)]$Root)

    # LBS-174: fixed two-line header geometry. A reserved status row remains
    # in place even when no status is visible; the brand title never moves.
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size(390, 60)
    $header.BackColor = $script:ColorHeader

    $headerTitle = New-Label -Text 'Lenovo Boot Selector' -Font (New-Object Drawing.Font('Segoe UI', 11.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 16 -Y 8 -Width 278 -Height 25
    $headerTitle.Name = 'HeaderTitleLabel'
    $script:HeaderTitleLabel = $headerTitle
    $header.Controls.Add($headerTitle)

    # LBS-14: a real flat Button keeps the status visually label-like while
    # providing native Enter/Space activation and keyboard focus semantics.
    $headerSub = New-Object System.Windows.Forms.Button
    $headerSub.Text = ''
    $headerSub.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $headerSub.ForeColor = $script:ColorSecondary
    $headerSub.BackColor = $script:ColorHeader
    $headerSub.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $headerSub.FlatAppearance.BorderSize = 0
    $headerSub.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $headerSub.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $headerSub.UseVisualStyleBackColor = $false
    $headerSub.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $headerSub.Padding = New-Object System.Windows.Forms.Padding(0)
    $headerSub.Location = New-Object Drawing.Point(16, 35)
    $headerSub.Size = New-Object Drawing.Size(278, 21)
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

    $info = New-Object LenovoHeaderIconButton
    $info.Name = 'HeaderSystemStatusButton'
    $info.InfoIcon = $true
    $info.Text = ''
    $info.AccessibleName = Get-LocalizedString -Key 'SystemStatus.Title'
    $info.AccessibleDescription = Get-LocalizedString -Key 'SystemStatus.Subtitle'
    $info.ForeColor = $script:ColorSecondary
    $info.BackColor = $script:ColorHeader
    $info.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $info.FlatAppearance.BorderSize = 0
    $info.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $info.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $info.UseVisualStyleBackColor = $false
    $info.Location = [Drawing.Point]::new(302,12)
    $info.Size = [Drawing.Size]::new(34,34)
    $info.Cursor = [Windows.Forms.Cursors]::Hand
    $info.Add_Paint({ param($sender,$eventArgs) Paint-ModalOwnerRefreshGlyph -Button $sender -EventArgs $eventArgs })
    $info.Add_MouseEnter({ if ($this.Enabled) { $this.ForeColor = $script:ColorAccent; $this.Invalidate() } })
    $info.Add_MouseLeave({ $this.ForeColor = $script:ColorSecondary; $this.Invalidate() })
    $info.Add_Click({ Show-SystemStatusPopup -Owner $this })
    $script:SystemStatusButton = $info
    $header.Controls.Add($info)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($info,(Get-LocalizedString -Key 'SystemStatus.Title')) }

    $refresh = New-Object LenovoHeaderIconButton
    $refresh.Name = 'HeaderRefreshButton'
    $refresh.AccessibleName = Get-LocalizedString -Key 'Action.RefreshBootTargets'
    $refresh.Text = ''
    $refresh.Font = New-Object Drawing.Font('Segoe UI Symbol', 15.0, [Drawing.FontStyle]::Regular)
    $refresh.ForeColor = $script:ColorSecondary
    $refresh.BackColor = $script:ColorHeader
    $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $refresh.FlatAppearance.BorderSize = 0
    $refresh.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $refresh.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $refresh.UseVisualStyleBackColor = $false
    $refresh.Location = New-Object Drawing.Point(340, 12)
    $refresh.Size = New-Object Drawing.Size(34, 34)
    $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:RefreshButton = $refresh
    # Native flat buttons can retain their default/focus outline while the
    # top-level owner is disabled by ShowDialog. Keep the real Button and its
    # native painting for the active owner; redraw only the inactive glyph.
    $refresh.Add_Paint({ param($sender,$eventArgs) Paint-ModalOwnerRefreshGlyph -Button $sender -EventArgs $eventArgs })
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
        Update-PopupRows -Reason 'manual-refresh-start'
        Start-BackgroundBootRefresh -RefreshStorage -Origin Manual
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

    $sectionLabel = New-Label -Text (Get-LocalizedString -Key 'Popup.NextBootSection') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 4 -Width 200 -Height 20
    $sectionLabel.Name = 'SectionLabel'
    $section.Controls.Add($sectionLabel)

    $keyboardHint = New-Label -Text (Get-LocalizedString -Key 'Manage.KeyboardHint') -Font (New-Object Drawing.Font('Segoe UI', 8.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 210 -Y 4 -Width 164 -Height 20
    $keyboardHint.Name = 'ManageKeyboardHint'
    $keyboardHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $keyboardHint.Visible = $false
    $section.Controls.Add($keyboardHint)

    $manageButton = New-Object LenovoCustomizeButton
    $manageButton.Name = 'ManageEntriesButton'
    $manageButton.Text = Get-LocalizedString -Key 'Popup.Customize'
    $manageButton.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $manageButton.ForeColor = $script:ColorSecondary
    $manageButton.BackColor = $script:ColorBackground
    $manageButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $manageButton.FlatAppearance.BorderSize = 0
    $manageButton.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38, 38, 38)
    $manageButton.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $manageButton.Location = New-Object Drawing.Point(268, 1)
    $manageButton.Size = New-Object Drawing.Size(104, 25)
    $manageButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $manageButton.Add_Click({ param($sender,$eventArgs) Start-ManageEntriesMode -PointerActivation:([bool]$sender.PointerActivation) })
    $script:ManageEntriesButton = $manageButton
    $section.Controls.Add($manageButton)
    $Root.Controls.Add($section)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($manageButton,(Get-LocalizedString -Key 'Tooltip.Customize')) }
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
        Invoke-BootEntryWheelScroll -ListPanel $sender -EventArgs $eventArgs
    })
    # Hover never changes keyboard ownership. Mouse-wheel delivery remains
    # on the existing list/row handlers and the form's list hit-test route.
    $Root.Controls.Add($listPanel)
}

# The two top-level navigation rows share one hit/hover surface, including
# transparent child labels. Leaving a child within the row must not clear it.
function Get-PopupNavigationRow {
    param([Windows.Forms.Control]$Control)
    if ($Control -is [Windows.Forms.Panel]) { return $Control }
    return $Control.Parent
}

function Test-PopupNavigationRowInteractive {
    param([Windows.Forms.Control]$Row)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.Enabled -or $script:IsManageEntriesMode) { return $false }
    if ($Row.Name -eq 'DefaultPanel') { return [bool]$script:DefaultInteractionEnabled }
    return (-not (Test-MaintenanceBusy))
}

# Shared by pointer hover and the modal-owner highlight; other UI hover colors
# intentionally retain their existing palette.
function Get-PopupNavigationHoverColor {
    return [Drawing.Color]::FromArgb(48,48,48)
}

function Set-PopupNavigationRowHover {
    param([Windows.Forms.Control]$Control,[bool]$Hover)
    $row = Get-PopupNavigationRow -Control $Control
    if (-not $row -or $row.IsDisposed) { return }
    $inside = $Hover -or ($row.Visible -and $row.RectangleToScreen($row.ClientRectangle).Contains([Windows.Forms.Cursor]::Position))
    $row.BackColor = if ($inside -and (Test-PopupNavigationRowInteractive -Row $row)) { Get-PopupNavigationHoverColor } else { $script:ColorSurface }
}

function Invoke-PopupNavigationRow {
    param([Windows.Forms.Control]$Control)
    $row = Get-PopupNavigationRow -Control $Control
    if (-not (Test-PopupNavigationRowInteractive -Row $row)) { return }
    if ($row.Name -eq 'DefaultPanel') { Show-DefaultTargetMenu -Owner $row }
    elseif ($row.Name -eq 'SettingsPanel') { Show-ConfigurationPopup -Owner $row }
}

function Add-PopupNavigationRowHandlers {
    param([Windows.Forms.Control]$Row)
    $hintKey = if ($Row.Name -eq 'DefaultPanel') { 'Tooltip.DefaultNavigation' } else { 'Tooltip.Settings' }
    foreach ($control in @($Row) + @($Row.Controls)) {
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($control,(Get-LocalizedString -Key $hintKey)) }
        $control.Add_MouseEnter({ param($sender,$eventArgs) Set-PopupNavigationRowHover -Control $sender -Hover $true })
        $control.Add_MouseLeave({ param($sender,$eventArgs) Set-PopupNavigationRowHover -Control $sender -Hover $false })
        $control.Add_MouseDown({
            param($sender,$eventArgs)
            if ($eventArgs.Button -ne [Windows.Forms.MouseButtons]::Left) { return }
            $target = Get-PopupNavigationRow -Control $sender
            if (Test-PopupNavigationRowInteractive -Row $target) { Set-LenovoPointerFocus -Control $target }
        })
        $control.Add_Click({ param($sender,$eventArgs) Invoke-PopupNavigationRow -Control $sender })
    }
    $Row.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.Modifiers -eq [Windows.Forms.Keys]::None -and $eventArgs.KeyCode -in @([Windows.Forms.Keys]::Enter,[Windows.Forms.Keys]::Space)) {
            $eventArgs.SuppressKeyPress = $true
            Invoke-PopupNavigationRow -Control $sender
        }
    })
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

    $configLabel = New-Label -Text (Get-LocalizedString -Key 'Settings.Title') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 2 -Width 220 -Height 17
    $configLabel.Name = 'ConfigurationSectionLabel'
    $configSection.Controls.Add($configLabel)
    $Root.Controls.Add($configSection)

    Initialize-NormalBootKeyboardRow
    $settings = New-Object LenovoNormalBootKeyboardRow
    $settings.Name = 'SettingsPanel'
    $settings.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $settings.AccessibleName = Get-LocalizedString -Key 'Settings.More'
    $settings.Location = New-Object Drawing.Point(0, 510)
    $settings.Size = New-Object Drawing.Size(390, 38)
    $settings.BackColor = $script:ColorSurface
    $settings.Cursor = [Windows.Forms.Cursors]::Hand

    $more = New-Label -Text $settings.AccessibleName -Font (New-Object Drawing.Font('Segoe UI',9.0)) -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 330 -Height 22
    $more.Name = 'MoreSettingsButton'
    $more.Cursor = [Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($more)
    $moreArrow = New-Label -Text '‹' -Font (New-Object Drawing.Font('Segoe UI',10.0)) -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $moreArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $moreArrow.Cursor = [Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($moreArrow)
    Add-PopupNavigationRowHandlers -Row $settings
    $Root.Controls.Add($settings)

    $defaultPanel = New-Object LenovoNormalBootKeyboardRow
    $defaultPanel.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $defaultPanel.Name = 'DefaultPanel'
    $defaultPanel.Location = New-Object Drawing.Point(0, 548)
    $defaultPanel.Size = New-Object Drawing.Size(390, 38)
    $defaultPanel.BackColor = $script:ColorSurface
    $defaultPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $defaultName = New-Label -Text (Get-LocalizedString -Key 'Settings.DefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 144 -Height 22
    $defaultName.Name = 'DefaultTargetNameLabel'
    $defaultName.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultName)

    $defaultValue = New-Label -Text (Get-LocalizedString -Key 'Settings.NoDefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 164 -Y 8 -Width 184 -Height 22
    $defaultValue.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $defaultValue.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultValue.Name = 'DefaultTargetValueLabel'
    $defaultPanel.Controls.Add($defaultValue)
    $script:DefaultValueLabel = $defaultValue

    $defaultArrow = New-Label -Text '‹' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $defaultArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $defaultArrow.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultArrow.Name = 'DefaultTargetArrowLabel'
    $defaultPanel.Controls.Add($defaultArrow)
    $script:DefaultArrowLabel = $defaultArrow

    Add-PopupNavigationRowHandlers -Row $defaultPanel
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
    $restartButton.Name = 'RestartActionButton'
    $restartButton.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartButton.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $restartButton.ForeColor = $script:ColorPrimary
    $restartButton.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
    $restartButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restartButton.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68, 68, 68)
    $restartButton.FlatAppearance.BorderSize = 1
    $restartButton.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $restartButton.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58, 27, 25)
    $restartButton.Location = New-Object Drawing.Point(16, 30)
    $restartButton.Size = New-Object Drawing.Size(358, 31)
    $restartButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    # The native Flat adapter paints disabled text nearly black on dark surfaces.
    # Only replace disabled foreground ink, leaving the real WinForms gates,
    # unchanged enabled rendering, geometry, borders and High Contrast intact.
    $pendingDisabledInkPainter = {
        param($sender,$eventArgs)
        if ($sender.Enabled -or [Windows.Forms.SystemInformation]::HighContrast) { return }
        $inner = $sender.ClientRectangle
        $border = $sender.FlatAppearance.BorderSize
        $inner.Inflate(-$border,-$border)
        if ($inner.Width -le 0 -or $inner.Height -le 0) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$inner) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                 [Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                 [Windows.Forms.TextFormatFlags]::SingleLine -bor
                 [Windows.Forms.TextFormatFlags]::EndEllipsis -bor
                 [Windows.Forms.TextFormatFlags]::NoPrefix -bor
                 [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$inner,([Drawing.Color]::FromArgb(146,146,146)),$flags)
    }
    $restartButton.Add_Paint($pendingDisabledInkPainter)
    $restartButton.Add_Click({ Restart-Windows })
    $script:RestartButton = $restartButton
    $restartPanel.Controls.Add($restartButton)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($restartButton,(Get-LocalizedString -Key 'Tooltip.Restart')) }

    # LBS-206 Layout C: the firmware-readback state is always passive and
    # precedes the explicit restart action. The one-time default control is
    # separate, and only appears when the guarded operation is admissible.
    # The original 390x672 footprint and 65px restart panel are unchanged.
    $restartTarget = New-Label -Text (Get-LocalizedString -Key 'BootNext.LayoutUnknown') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 3 -Width 358 -Height 23
    $restartTarget.Name = 'RestartTargetLabel'
    $restartTarget.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $restartTarget.AutoEllipsis = $true
    $restartTarget.TabStop = $false
    $restartTarget.Cursor = [Windows.Forms.Cursors]::Default
    $restartTarget.AccessibleRole = [Windows.Forms.AccessibleRole]::StaticText
    $restartTarget.AccessibleName = $restartTarget.Text
    $restartTarget.AccessibleDescription = $restartTarget.Text
    $restartTarget.Add_TextChanged({
        $this.AccessibleName = $this.Text
        $this.AccessibleDescription = $this.Text
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($this,$this.Text) }
    })
    $restartPanel.Controls.Add($restartTarget)
    $script:RestartTargetLabel = $restartTarget

    $defaultOnce = New-Object System.Windows.Forms.Button
    $defaultOnce.Name = 'RestartUseDefaultButton'
    $defaultOnce.Text = Get-LocalizedString -Key 'BootNext.UseDefaultOnce'
    $defaultOnce.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $defaultOnce.ForeColor = [Drawing.Color]::FromArgb(255,160,150)
    $defaultOnce.BackColor = $script:ColorSelectedRow
    $defaultOnce.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $defaultOnce.FlatAppearance.BorderColor = $script:ColorAccent
    $defaultOnce.FlatAppearance.BorderSize = 1
    $defaultOnce.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(81,37,34)
    $defaultOnce.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(100,40,35)
    $defaultOnce.Location = New-Object Drawing.Point(16,30)
    $defaultOnce.Size = New-Object Drawing.Size(205,31)
    $defaultOnce.Visible = $false
    $defaultOnce.Enabled = $false
    $defaultOnce.TabStop = $false
    $defaultOnce.TabIndex = 0
    $defaultOnce.Cursor = [Windows.Forms.Cursors]::Default
    $defaultOnce.AccessibleName = $defaultOnce.Text
    $defaultOnce.Add_Click({
        if ($script:RestartUseDefaultButton -and
            $script:RestartUseDefaultButton.Enabled -and
            $script:RestartUseDefaultButton.Visible -and
            -not $script:BootNextPendingGuid) { Use-DefaultForNextRestart }
    })
    $restartPanel.Controls.Add($defaultOnce)
    $script:RestartUseDefaultButton = $defaultOnce
    $restartButton.TabIndex = 1
    $Root.Controls.Add($restartPanel)

    # Dedicated footer height prevents Segoe UI/DPI clipping at the bottom edge.
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Name = 'FooterPanel'
    $footerPanel.Location = New-Object Drawing.Point(0, 652)
    $footerPanel.Size = New-Object Drawing.Size(390, 20)
    $footerPanel.BackColor = $script:ColorSurface
    $versionLabel = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 284 -Y 0 -Width 90 -Height 20
    $versionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $footerPanel.Controls.Add($versionLabel)
    $Root.Controls.Add($footerPanel)
}

function Add-PopupManageEntriesSection {
    param([Parameter(Mandatory=$true)]$Root)

    # Entry-management overlay. It temporarily replaces the normal settings/footer
    # while the same boot list switches into edit mode.
    # LBS-231: the redundant instructional block is gone. Keep the action
    # row and version footer at their original absolute positions; the list
    # claims the recovered 72 design pixels in addition to LBS-157.
    # A multiple of four preserves the absolute button positions across
    # fractional quarter-step DPI scales without a one-pixel rounding drift.
    $managePanel = New-Object System.Windows.Forms.Panel
    $managePanel.Name = 'ManageEntriesPanel'
    $managePanel.Location = New-Object Drawing.Point(0, 596)
    $managePanel.Size = New-Object Drawing.Size(390, 76)
    $managePanel.BackColor = $script:ColorSurface
    $managePanel.Visible = $false

    $manageDivider = New-Object System.Windows.Forms.Panel
    $manageDivider.Location = New-Object Drawing.Point(16, 0)
    $manageDivider.Size = New-Object Drawing.Size(358, 1)
    $manageDivider.BackColor = [Drawing.Color]::FromArgb(54,54,54)
    $managePanel.Controls.Add($manageDivider)

    # LBS-179: one native Undo control in the existing action row, no history surface.
    $undoManage = New-Object System.Windows.Forms.Button
    $undoManage.Name = 'ManageUndoButton'
    $undoManage.Text = Get-LocalizedString -Key 'Manage.Undo'
    $undoManage.AccessibleName = $undoManage.Text
    $undoManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $undoManage.ForeColor = [Drawing.Color]::FromArgb(146,146,146)
    $undoManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $undoManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $undoManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $undoManage.FlatAppearance.BorderSize = 1
    $undoManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $undoManage.Location = New-Object Drawing.Point(16, 6)
    $undoManage.Size = New-Object Drawing.Size(100, 34)
    $undoManage.Enabled = $false
    $undoManage.TabIndex = 0
    $undoManage.Add_Click({ Undo-ManageEntryDraft })
    $managePanel.Controls.Add($undoManage)

    $cancelManage = New-Object System.Windows.Forms.Button
    $cancelManage.Name = 'ManageCancelButton'
    $cancelManage.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $cancelManage.ForeColor = $script:ColorPrimary
    $cancelManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $cancelManage.FlatAppearance.BorderSize = 1
    $cancelManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $cancelManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58,27,25)
    $cancelManage.Location = New-Object Drawing.Point(124, 6)
    $cancelManage.Size = New-Object Drawing.Size(84, 34)
    $cancelManage.TabIndex = 1
    $cancelManage.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelManage.Add_Click({ Stop-ManageEntriesMode })
    $managePanel.Controls.Add($cancelManage)

    $saveManage = New-Object System.Windows.Forms.Button
    $saveManage.Name = 'ManageSaveButton'
    $saveManage.Text = Get-LocalizedString -Key 'Manage.Save'
    $saveManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $saveManage.ForeColor = [Drawing.Color]::FromArgb(146,146,146)
    $saveManage.BackColor = [Drawing.Color]::FromArgb(35,35,35)
    $saveManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
    $saveManage.FlatAppearance.BorderSize = 1
    $saveManage.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(190,35,28)
    $saveManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $saveManage.Location = New-Object Drawing.Point(216, 6)
    $saveManage.Size = New-Object Drawing.Size(158, 34)
    $saveManage.TabIndex = 2
    # LBS-186: the native Flat button adapter dims disabled text against
    # the dark background. Repaint only the disabled interior using the
    # configured palette; keep the real Button, native border and Enabled gate.
    $saveManage.Add_Paint({
        param($sender,$eventArgs)
        if ($sender.Enabled -or [Windows.Forms.SystemInformation]::HighContrast) { return }
        $inner = $sender.ClientRectangle
        $border = $sender.FlatAppearance.BorderSize
        $inner.Inflate(-$border,-$border)
        if ($inner.Width -le 0 -or $inner.Height -le 0) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$inner) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                 [Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                 [Windows.Forms.TextFormatFlags]::SingleLine -bor
                 [Windows.Forms.TextFormatFlags]::EndEllipsis -bor
                 [Windows.Forms.TextFormatFlags]::NoPrefix -bor
                 [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$inner,$sender.ForeColor,$flags)
    })
    $saveManage.Enabled = $false
    $saveManage.Cursor = [System.Windows.Forms.Cursors]::Default
    $saveManage.Add_Click({ Stop-ManageEntriesMode -Save })
    $managePanel.Controls.Add($saveManage)
    $script:ManageSaveButton = $saveManage

    $manageFooter = New-Object System.Windows.Forms.Panel
    $manageFooter.Location = New-Object Drawing.Point(0, 44)
    $manageFooter.Size = New-Object Drawing.Size(390, 32)
    $manageFooter.BackColor = $script:ColorSurface
    $manageVersion = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 284 -Y 7 -Width 90 -Height 20
    $manageVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $manageFooter.Controls.Add($manageVersion)
    $managePanel.Controls.Add($manageFooter)
    $Root.Controls.Add($managePanel)
}

# Shared visual shell for the two configuration-specific surfaces. Shared
# fonts and the local tooltip belong to this Form, not to the main popup.
function New-AuxiliaryPopupForm {
    param([string]$Name,[string]$Title,[AllowEmptyString()][string]$Subtitle,[int]$ContentHeight)
    $form = New-Object Windows.Forms.Form
    $form.Name = $Name
    $form.Text = $Title
    $form.AccessibleName = $Title
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.KeyPreview = $true
    $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $form.BackColor = $script:ColorBackground
    $heightLimit = if ($Name -eq 'LenovoConfigurationPopup') { 672 } else { 540 }
    $form.ClientSize = [Drawing.Size]::new(390,[Math]::Min($heightLimit,64+$ContentHeight))
    $regular = [Drawing.Font]::new('Segoe UI',[single]9.0)
    $bold = [Drawing.Font]::new('Segoe UI',[single]10.0,[Drawing.FontStyle]::Bold)
    $heading = [Drawing.Font]::new('Segoe UI',[single]8.5,[Drawing.FontStyle]::Bold)
    $large = [Drawing.Font]::new('Segoe UI',[single]11.5,[Drawing.FontStyle]::Bold)
    $symbol = [Drawing.Font]::new('Segoe UI Symbol',[single]18.0)
    $tip = New-LenovoDarkTooltip -Animate
    $header = New-Object Windows.Forms.Panel
    $header.Name = 'AuxiliaryHeader'
    $header.TabIndex = 1
    $header.BackColor = $script:ColorHeader
    $header.Size = [Drawing.Size]::new(390,64)
    $titleLabel = New-Label -Text $Title -Font $large -ForeColor $script:ColorPrimary -X 16 -Y 7 -Width 318 -Height 26
    $subtitleLabel = New-Label -Text $Subtitle -Font $regular -ForeColor $script:ColorSecondary -X 16 -Y 34 -Width 358 -Height 23
    $subtitleLabel.AccessibleDescription = $Subtitle
    $tip.SetToolTip($subtitleLabel,$Subtitle)
    $header.Controls.Add($titleLabel)
    $header.Controls.Add($subtitleLabel)
    $close = New-Object Windows.Forms.Button
    $close.Name = 'AuxiliaryClose'
    $close.Text = '×'
    $close.AccessibleName = Get-LocalizedString -Key 'Common.Close'
    $close.Cursor = [Windows.Forms.Cursors]::Hand
    $closeHintKey = if ($Name -eq 'LenovoDefaultTargetPicker') { 'Tooltip.ClosePicker' } elseif ($Name -eq 'LenovoSystemStatusPopup') { 'Common.Close' } else { 'Tooltip.CloseSettings' }
    $tip.SetToolTip($close,(Get-LocalizedString -Key $closeHintKey))
    $close.Font = $symbol
    $close.BackColor = $script:ColorHeader
    $close.ForeColor = $script:ColorPrimary
    $close.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $close.FlatAppearance.BorderSize = 0
    $close.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $close.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $close.UseVisualStyleBackColor = $false
    # The close button remains a native keyboard-accessible CancelButton.
    # Native default/focus ink must not survive on an inactive modal owner.
    $close.Add_Paint({
        param($sender,$eventArgs)
        if ([Windows.Forms.SystemInformation]::HighContrast) { return }
        $form = $sender.FindForm()
        if (-not $form) { return }
        if ($sender.Focused -and $form.ContainsFocus -and -not $script:ActiveOwnedDialog) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$sender.ClientRectangle) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPrefix -bor [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$sender.ClientRectangle,$sender.ForeColor,$flags)
    })
    $close.Add_GotFocus({ $this.Invalidate() })
    $close.Add_LostFocus({ $this.Invalidate() })
    $close.Add_MouseEnter({ param($sender,$eventArgs) $sender.ForeColor = $script:ColorAccent })
    $close.Add_MouseLeave({ param($sender,$eventArgs) $sender.ForeColor = $script:ColorPrimary })
    $close.Location = [Drawing.Point]::new(350,7)
    $close.Size = [Drawing.Size]::new(28,30)
    $close.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $header.Controls.Add($close)
    $form.Controls.Add($header)
    # Keep action controls in the body; clip it in a separate fixed viewport.
    # Reuse the main popup's existing painted scrollbar and pixel-value contract.
    $viewport = New-Object Windows.Forms.Panel
    $viewport.Name = 'AuxiliaryViewport'
    $viewport.TabIndex = 0
    $viewport.BackColor = $script:ColorBackground
    $viewport.AutoScroll = $false
    $viewport.Location = [Drawing.Point]::new(0,64)
    $viewport.Size = [Drawing.Size]::new(390,$form.ClientSize.Height-64)
    $body = New-Object Windows.Forms.Panel
    $body.Name = 'AuxiliaryBody'
    $body.TabIndex = 0
    $body.BackColor = $script:ColorBackground
    $body.AutoScroll = $false
    $body.Location = [Drawing.Point]::Empty
    $body.Size = [Drawing.Size]::new(390,$ContentHeight)
    $viewport.Controls.Add($body)
    $scroll = New-Object LenovoVerticalScrollBar
    $scroll.Name = 'AuxiliaryScroll'
    $scroll.Location = [Drawing.Point]::new(382,0)
    $scroll.Size = [Drawing.Size]::new(8,$viewport.Height)
    $scroll.TrackColor = [Drawing.Color]::FromArgb(23,23,23)
    $scroll.ThumbColor = $script:ColorAccent
    $scroll.ThumbHoverColor = [Drawing.Color]::FromArgb(242,59,49)
    $scroll.Visible = $false
    $scroll.Add_ValueChanged({
        param($sender,$eventArgs)
        $content = $sender.Parent.Controls['AuxiliaryBody']
        if ($content) { $content.Top = -$sender.Value }
    })
    $viewport.Controls.Add($scroll)
    $scroll.BringToFront()
    $form.Controls.Add($viewport)
    $form.CancelButton = $close
    # Keep the accessible close button in the tab order and as CancelButton,
    # but do not give it the initial keyboard focus (native focus outline).
    $form.Add_Shown({
        param($sender,$eventArgs)
        [void]$sender.Tag.Body.SelectNextControl($null,$true,$true,$true,$false)
    })
    $form.Tag = [pscustomobject]@{
        Choice=$null; Scale=0.0; Header=$header; Title=$titleLabel; Subtitle=$subtitleLabel
        Close=$close; Body=$body; Viewport=$viewport; Scroll=$scroll; ContentHeight=$ContentHeight; Tip=$tip
        Regular=$regular; Bold=$bold; Heading=$heading; Symbol=$symbol
        Fonts=@($regular,$bold,$heading,$large,$symbol); Timer=$null; DefaultSnapshot=$null; ActionInProgress=$false; InitialModalActivationComplete=$false
    }
    $form.Add_Disposed({
        param($sender,$eventArgs)
        $state = $sender.Tag
        if ($state.Timer) { $state.Timer.Stop(); $state.Timer.Dispose() }
        $state.Tip.Dispose()
        foreach ($font in $state.Fonts) { $font.Dispose() }
    })
    $form.Add_Paint({
        param($sender,$eventArgs)
        $pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(108,108,108))
        try { $eventArgs.Graphics.DrawRectangle($pen,0,0,[Math]::Max(0,$sender.ClientSize.Width-1),[Math]::Max(0,$sender.ClientSize.Height-1)) }
        finally { $pen.Dispose() }
    })
    return $form
}

function Get-ConfigurationActionMenuItem {
    param([string]$Action)
    switch ($Action) {
        'autostart' { return $script:AutostartMenuItem }
        'language-de' { return $script:LanguageGermanMenuItem }
        'language-en' { return $script:LanguageEnglishMenuItem }
        'system-setup' { return $script:TaskBrokerSetupMenuItem }
        'system-remove' { return $script:TaskBrokerRemoveMenuItem }
        'update-check' { return $script:UpdateCheckMenuItem }
        'update-install' { return $script:UpdateInstallMenuItem }
        'preferences-export' { return $script:PreferencesExportMenuItem }
        'preferences-import' { return $script:PreferencesImportMenuItem }
        'diagnostics-save' { return $script:RuntimeDiagnosticMenuItem }
        'diagnostics-upload' { return $script:DiagnosticsUploadMenuItem }
    }
    return $null
}

function Test-ConfigurationActionAvailable {
    param([string]$Action)
    $item = Get-ConfigurationActionMenuItem -Action $Action
    if ($Action -like 'preferences-*' -and $item -and -not $item.IsDisposed) {
        $item.Enabled = [bool](Test-PortablePreferencesAvailable -PresentationOnly)
    }
    return [bool]($item -and -not $item.IsDisposed -and $item.Available -and $item.Enabled -and -not (Test-MaintenanceBusy))
}

function Update-ConfigurationPopupPresentation {
    param([System.Windows.Forms.Form]$Form)
    # Move focus before disabling the current action. WinForms would otherwise
    # fall through to the header's CancelButton when the final row is disabled.
    # Do not move an explicitly selected close button or focus in another window.
    if ($Form.ContainsFocus) {
        $focused = $Form.Tag.Body.Controls | Where-Object { $_.Focused } | Select-Object -First 1
        if ($focused -and $focused.Tag -and -not (Test-ConfigurationActionAvailable -Action ([string]$focused.Tag))) {
            $eligible = @($Form.Tag.Body.Controls | Where-Object {
                $_.TabStop -and $_.CanFocus -and $_.Tag -and
                (Test-ConfigurationActionAvailable -Action ([string]$_.Tag))
            } | Sort-Object TabIndex)
            $target = $eligible | Where-Object { $_.TabIndex -gt $focused.TabIndex } | Select-Object -First 1
            if (-not $target) { $target = $eligible | Select-Object -Last 1 }
            if ($target) { [void]$target.Focus() }
        }
    }
    foreach ($control in $Form.Tag.Body.Controls) {
        $action = [string]$control.Tag
        if (-not $action) { continue }
        $item = Get-ConfigurationActionMenuItem -Action $action
        $control.Enabled = Test-ConfigurationActionAvailable -Action $action
        if (-not $item) { continue }
        $hintKey = if ($action -eq 'autostart') { 'Tooltip.Configuration.autostart' } else { 'Tooltip.Configuration.' + $action }
        $hint = Get-LocalizedString -Key $hintKey
        if (-not $control.Enabled) { $hint += [Environment]::NewLine + (Get-LocalizedString -Key 'Tooltip.Unavailable') }
        if ($Form.Tag.Tip.GetToolTip($control) -cne $hint) { $Form.Tag.Tip.SetToolTip($control,$hint) }
        $control.Cursor = if ($control.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        if ($control -is [Windows.Forms.CheckBox]) {
            if ($control.Checked -ne [bool]$item.Checked) { $control.Checked = [bool]$item.Checked; $control.Invalidate() }
            $control.AccessibleDescription = $hint
        }
        elseif ($control -is [LenovoSettingsAutostartLabel]) {
            $control.AccessibleDescription = $hint
        }
        elseif ($control -is [LenovoSettingsActionButton]) {
            $language = $action -like 'language-*'
            $selected = [bool]($language -and $item.Checked)
            $name = if ($language) {
                if ($action -eq 'language-de') { Get-LocalizedString -Key 'Language.German' }
                else { Get-LocalizedString -Key 'Language.English' }
            } else { ([string]$item.Text).TrimEnd('.') }
            $subtitle = if ($language) { '' } elseif ($action -eq 'update-install' -and -not $control.Enabled) { Get-LocalizedString -Key 'Tooltip.Unavailable' } else { Get-LocalizedString -Key ('Settings.Detail.' + $action) }
            $description = $hint
            if ($language) {
                $description += [Environment]::NewLine + (Get-LocalizedString -Key $(if ($selected) { 'Settings.LanguageSelected' } else { 'Settings.LanguageNotSelected' }))
            }
            $changed = $control.Text -cne $name -or $control.Subtitle -cne $subtitle -or $control.LanguageSelected -ne $selected
            $control.Text = $name
            $control.Subtitle = $subtitle
            $control.LanguageSelected = $selected
            $control.AccessibleName = $name
            $control.AccessibleDescription = $description
            $control.ForeColor = if ($control.Enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(146,146,146) }
            $control.BackColor = if ($language) { $script:ColorSurface } else { [Drawing.Color]::FromArgb(37,37,37) }
            $control.FlatAppearance.BorderColor = if (-not $control.Enabled) { [Drawing.Color]::FromArgb(58,58,58) } elseif ($selected) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(68,68,68) }
            if ($changed) { $control.Invalidate() }
        }
    }
}

function Invoke-ConfigurationPopupAction {
    param([System.Windows.Forms.Control]$Control)
    $action = [string]$Control.Tag
    if (-not (Test-ConfigurationActionAvailable -Action $action)) { return }
    $form = $Control.FindForm()
    $item = Get-ConfigurationActionMenuItem -Action $action
    if (-not $form -or $form.IsDisposed -or $form.Tag.ActionInProgress) { return }
    if ($action -like 'language-*' -and $item.Checked) { return }
    # The existing tray handlers still own all operations and confirmations.
    # Keep the settings modal alive throughout synchronous dispatch; asynchronous
    # result dialogs resolve the currently visible owner when they complete.
    $form.Tag.ActionInProgress = $true
    try { $item.PerformClick() }
    finally {
        if (-not $form.IsDisposed) {
            $form.Tag.ActionInProgress = $false
            Update-ConfigurationPopupPresentation -Form $form
        }
    }
}

function Add-ConfigurationHeading {
    param($Form,[string]$Key,[int]$Y)
    $label = New-Label -Text (Get-LocalizedString -Key $Key) -Font $Form.Tag.Heading -ForeColor $script:ColorSecondary -X 16 -Y $Y -Width 350 -Height 22
    $label.Name = 'ConfigurationLocale-' + $Key
    $Form.Tag.Body.Controls.Add($label)
}

function Add-ConfigurationActionButton {
    param($Form,[string]$Action,[string]$Key,[int]$Y,[int]$X=16,[int]$Width=350,[switch]$Separator)
    $button = New-Object LenovoSettingsActionButton
    $button.Name = 'ConfigurationAction-' + $Action
    $button.Tag = $Action
    $button.ActionIcon = $Action
    $button.LocaleCode = if ($Action -eq 'language-de') { 'de-DE' } elseif ($Action -eq 'language-en') { 'en-US' } else { '' }
    $button.Destructive = ($Action -eq 'system-remove')
    $button.Separator = [bool]$Separator
    $button.Text = Get-LocalizedString -Key $Key
    $button.AccessibleName = $button.Text
    $button.Font = $Form.Tag.Regular
    $button.TitleFont = $Form.Tag.Bold
    $button.SubtitleFont = $Form.Tag.Regular
    $button.ForeColor = $script:ColorPrimary
    $button.BackColor = [Drawing.Color]::FromArgb(37,37,37)
    $button.HoverSurface = $script:ColorHover
    $button.SelectedSurface = $script:ColorSelectedRow
    $button.AccentColor = $script:ColorAccent
    $button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.UseMnemonic = $false
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.Location = [Drawing.Point]::new($X,$Y)
    $height = if ($button.LocaleCode) { 38 } else { 52 }
    $button.Size = [Drawing.Size]::new($Width,$height)
    $button.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $Form.Tag.Body.Controls.Add($button)
}

# Width adaptation is configuration-local; the default picker retains its
# original geometry. Bounds are already scaled once by the auxiliary shell.
function Set-ConfigurationPopupWidth {
    param($Form,[double]$Scale)
    $body = $Form.Tag.Body
    $margin = [int][Math]::Round(16*$Scale)
    $width = [Math]::Max(2,$body.Width-2*$margin)
    $toggle = [Math]::Min([int][Math]::Round(64*$Scale),[int][Math]::Floor($width/3))
    $leftWidth = [Math]::Max(1,$width-$toggle)
    $half = [int][Math]::Floor($width/2)
    foreach ($control in $body.Controls) {
        $control.Left = $margin
        switch ($control.Name) {
            'ConfigurationLocale-Settings.Autostart' { $control.Width = $leftWidth }
            'ConfigurationAutostart' { $control.Left += $leftWidth; $control.Width = $toggle }
            'ConfigurationAction-language-de' { $control.Width = $half }
            'ConfigurationAction-language-en' { $control.Left += $half; $control.Width = $width-$half }
            default { $control.Width = $width }
        }
    }
}

function Update-ConfigurationPopupLocale {
    param([Windows.Forms.Form]$Form)
    $title = Get-LocalizedString -Key 'Settings.More'
    $Form.Text = $title
    $Form.AccessibleName = $title
    $Form.Tag.Title.Text = $title
    $subtitle = Get-LocalizedString -Key 'Settings.MoreSubtitle'
    $Form.Tag.Subtitle.Text = $subtitle
    $Form.Tag.Subtitle.AccessibleDescription = $subtitle
    $Form.Tag.Tip.SetToolTip($Form.Tag.Subtitle,$subtitle)
    $Form.Tag.Body.Controls['ConfigurationLocale-Settings.Autostart'].Subtitle = Get-LocalizedString -Key 'Settings.Detail.autostart'
    $Form.Tag.Close.AccessibleName = Get-LocalizedString -Key 'Common.Close'
    $Form.Tag.Tip.SetToolTip($Form.Tag.Close,(Get-LocalizedString -Key 'Tooltip.CloseSettings'))
    foreach ($control in $Form.Tag.Body.Controls) {
        if ($control.Name.StartsWith('ConfigurationLocale-')) {
            $control.Text = Get-LocalizedString -Key $control.Name.Substring('ConfigurationLocale-'.Length)
            $control.AccessibleName = $control.Text
        }
    }
    $Form.Tag.Body.Controls['ConfigurationAutostart'].AccessibleName = Get-LocalizedString -Key 'Settings.Autostart'
    Update-ConfigurationPopupPresentation -Form $Form
}

function New-ConfigurationPopup {
    $form = New-AuxiliaryPopupForm -Name 'LenovoConfigurationPopup' -Title (Get-LocalizedString -Key 'Settings.More') -Subtitle (Get-LocalizedString -Key 'Settings.MoreSubtitle') -ContentHeight 706
    $groupSurface = [Drawing.Color]::FromArgb(37,37,37)
    Add-ConfigurationHeading -Form $form -Key 'Settings.General' -Y 6
    $autostartLabel = New-Object LenovoSettingsAutostartLabel
    $autostartLabel.Name = 'ConfigurationLocale-Settings.Autostart'
    $autostartLabel.Tag = 'autostart'
    $autostartLabel.Text = Get-LocalizedString -Key 'Settings.Autostart'
    $autostartLabel.AccessibleName = $autostartLabel.Text
    $autostartLabel.Subtitle = Get-LocalizedString -Key 'Settings.Detail.autostart'
    $autostartLabel.Font = $form.Tag.Regular
    $autostartLabel.TitleFont = $form.Tag.Bold
    $autostartLabel.SubtitleFont = $form.Tag.Regular
    $autostartLabel.ForeColor = $script:ColorPrimary
    $autostartLabel.BackColor = $groupSurface
    $autostartLabel.HoverSurface = $script:ColorHover
    $autostartLabel.Location = [Drawing.Point]::new(16,32)
    $autostartLabel.Size = [Drawing.Size]::new(286,52)
    $autostartLabel.Cursor = [Windows.Forms.Cursors]::Hand
    $autostartLabel.Add_MouseDown({
        param($sender,$eventArgs)
        if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left -and (Test-ConfigurationActionAvailable -Action 'autostart')) {
            Set-LenovoPointerFocus -Control $sender.Parent.Controls['ConfigurationAutostart']
        }
    })
    $autostartLabel.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $form.Tag.Body.Controls.Add($autostartLabel)
    $check = New-Object LenovoSettingsToggle
    $check.Name = 'ConfigurationAutostart'
    $check.Tag = 'autostart'
    $check.AutoCheck = $false
    $check.AccessibleName = $autostartLabel.Text
    $check.Font = $form.Tag.Regular
    $check.BackColor = $groupSurface
    $check.HoverSurface = $script:ColorHover
    $check.AccentColor = $script:ColorAccent
    $check.Location = [Drawing.Point]::new(302,32)
    $check.Size = [Drawing.Size]::new(64,52)
    $check.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $form.Tag.Body.Controls.Add($check)
    [void][LenovoSettingsAutostartHover]::new($autostartLabel,$check)
    $language = New-Label -Text (Get-LocalizedString -Key 'Settings.Language') -Font $form.Tag.Bold -ForeColor $script:ColorPrimary -X 16 -Y 90 -Width 350 -Height 24
    $language.Name = 'ConfigurationLocale-Settings.Language'
    $form.Tag.Body.Controls.Add($language)
    Add-ConfigurationActionButton -Form $form -Action 'language-de' -Key 'Language.German' -Y 116 -Width 175
    Add-ConfigurationActionButton -Form $form -Action 'language-en' -Key 'Language.English' -Y 116 -X 191 -Width 175
    Add-ConfigurationHeading -Form $form -Key 'Preferences.Heading' -Y 164
    Add-ConfigurationActionButton -Form $form -Action 'preferences-export' -Key 'Preferences.Export' -Y 188 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'preferences-import' -Key 'Preferences.Import' -Y 240
    Add-ConfigurationHeading -Form $form -Key 'Maintenance.Caption' -Y 300
    Add-ConfigurationActionButton -Form $form -Action 'system-setup' -Key 'Maintenance.Setup' -Y 324 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'system-remove' -Key 'Maintenance.Remove' -Y 376
    Add-ConfigurationHeading -Form $form -Key 'Settings.Updates' -Y 436
    Add-ConfigurationActionButton -Form $form -Action 'update-check' -Key 'Update.Check' -Y 460 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'update-install' -Key 'Update.Install' -Y 512
    Add-ConfigurationHeading -Form $form -Key 'Settings.Diagnostics' -Y 572
    Add-ConfigurationActionButton -Form $form -Action 'diagnostics-save' -Key 'Diagnostics.Save' -Y 596 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'diagnostics-upload' -Key 'Diagnostics.Upload' -Y 648
    Update-ConfigurationPopupPresentation -Form $form
    # Reflect existing presentation state only; do not poll firmware/network.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        if ($script:ActiveAuxiliaryPopup -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoConfigurationPopup') {
            Update-ConfigurationPopupPresentation -Form $script:ActiveAuxiliaryPopup
        }
    })
    $form.Tag.Timer = $timer
    $form.Add_Shown({ $this.Tag.Timer.Start() })
    return $form
}

function Show-ConfigurationPopup {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { return }
    [void](Update-TaskBrokerUiState -Fast)
    [void](Update-AutostartUi)
    Update-UpdateMenuState
    Update-LanguageMenuState
    [void](Show-OwnedAuxiliaryPopup -Form (New-ConfigurationPopup) -Owner $Owner)
}

# LBS-182: read-only status classification; no I/O, privileges or UI state.
function Resolve-SystemStatusCore {
    param($Capabilities,[string]$DefaultEvidence,[string]$DefaultName,[string]$DefaultGuid,
          [bool]$DefaultUncertain,[bool]$NextVerified,[string]$NextName,[string]$NextGuid,
          [bool]$NextTimeKnown,[bool]$Pending,[bool]$Refreshing,[string]$LastRefresh,
          $Drift,[bool]$DriftFailed,[bool]$ReadinessTimeKnown,[bool]$EntriesTimeKnown)
    $state = if ($Capabilities -and $Capabilities.State -in @('Ready','Checking','SetupRequired','RepairRequired','ReinitializeRequired','Busy','Unknown')) { [string]$Capabilities.State } else { 'Unknown' }
    if ($state -eq 'Ready' -and -not $ReadinessTimeKnown) { $state = 'Unknown' }
    $default = if ($DefaultUncertain -or $DefaultEvidence -notin @('configured','none','unavailable')) { 'Unknown' }
        elseif ($DefaultEvidence -eq 'unavailable' -or ($DefaultEvidence -eq 'configured' -and (-not $DefaultGuid -or -not $DefaultName))) { 'Unavailable' }
        elseif ($DefaultEvidence -eq 'none' -and -not $DefaultGuid) { 'NoDefault' }
        elseif ($DefaultEvidence -eq 'configured' -and $DefaultGuid -and $DefaultName) { 'Value' } else { 'Unknown' }
    $next = if ($Pending) { 'Pending' } elseif (-not $NextVerified -or -not $NextTimeKnown) { 'Unknown' }
        elseif (-not $NextGuid) { 'FirmwareOrder' } elseif (-not $NextName) { 'Unavailable' } else { 'Value' }
    $relation = if ($next -eq 'Value' -and $default -eq 'Value') {
        if ($NextGuid -eq $DefaultGuid) { 'Matches' } else { 'Differs' }
    } else { 'Verified' }
    $driftKey = if (-not $Drift -or -not $Drift.Evaluated -or $DriftFailed -or -not $EntriesTimeKnown) { 'Unknown' } elseif ($Drift.HasDrift) { 'DriftChanged' } else { 'DriftNone' }
    $hint = switch ($state) {
        'SetupRequired' { 'SetupHint' }
        'RepairRequired' { 'RepairHint' }
        'ReinitializeRequired' { 'ReinitializeHint' }
        default { '' }
    }
    $summary = if ($state -eq 'Busy' -or $Refreshing -or $Pending -or $state -eq 'Checking') { 'SummaryBusy' }
        elseif ($state -in @('SetupRequired','RepairRequired','ReinitializeRequired') -or $driftKey -eq 'DriftChanged' -or $next -eq 'Unavailable' -or $default -eq 'Unavailable') { 'SummaryAttention' }
        elseif ($state -ne 'Ready' -or -not $ReadinessTimeKnown -or $next -eq 'Unknown' -or $default -eq 'Unknown' -or $driftKey -eq 'Unknown' -or $LastRefresh -eq 'error') { 'SummaryUnknown' }
        else { 'SummaryReady' }
    [pscustomobject]@{ Summary=$summary; Readiness=$state; Default=$default; DefaultName=$DefaultName; Next=$next; NextName=$NextName;
        Relation=$relation; Drift=$driftKey; Hint=$hint; Refresh=if ($Refreshing) {'RefreshRunning'} elseif ($LastRefresh -eq 'error') {'RefreshFailed'} else {''} }
}

# LBS-182: project only existing in-memory observations; no broker/firmware calls.
function ConvertTo-SystemStatusObservedTime {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    try {
        $utc = ([datetime]$Value).ToUniversalTime()
        if ($utc.Year -lt 2000 -or $utc -gt [datetime]::UtcNow) { return $null }
        return $utc
    } catch { return $null }
}

function Format-SystemStatusObservedTime {
    param($Value)
    $utc = ConvertTo-SystemStatusObservedTime $Value
    if (-not $utc) { return (Get-LocalizedString -Key 'SystemStatus.TimeUnknown') }
    $minutes = [int][Math]::Floor(([datetime]::UtcNow-$utc).TotalMinutes)
    return (Get-LocalizedString -Key 'SystemStatus.Age' -Values @{ Time=$utc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'); Minutes=$minutes })
}

function Get-SystemStatusPresentation {
    $defaultEntry = if ($script:DefaultGuid) { Get-EntryByGuid $script:DefaultGuid }
    $nextEntry = if ($script:SelectedGuid) { Get-EntryByGuid $script:SelectedGuid }
    $defaultName = if ($defaultEntry) { Get-EntryDisplayTitle -Entry $defaultEntry } else { '' }
    $nextName = if ($nextEntry) { Get-EntryDisplayTitle -Entry $nextEntry } else { '' }
    $nextTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusNextObservedUtc
    $readinessTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusReadinessObservedUtc
    $entriesTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusEntriesObservedUtc
    $refreshing = [bool](Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)
    $pending = [bool]($script:BootNextPendingGuid -or $script:DefaultTargetChangePending)
    $model = Resolve-SystemStatusCore -Capabilities $script:SystemStatusCapabilities -DefaultEvidence $script:SystemStatusDefaultEvidence -DefaultName $defaultName -DefaultGuid $script:DefaultGuid -DefaultUncertain ([bool]($script:DefaultTargetReadUncertain -or $script:DefaultTargetChangePending)) -NextVerified ([bool]$script:NextBootFirmwareReadVerified) -NextName $nextName -NextGuid $script:SelectedGuid -NextTimeKnown ([bool]$nextTime) -Pending $pending -Refreshing $refreshing -LastRefresh $script:SystemStatusLastRefresh -Drift $script:BootTargetDriftState -DriftFailed ([bool]$script:SystemStatusDriftFailed) -ReadinessTimeKnown ([bool]$readinessTime) -EntriesTimeKnown ([bool]$entriesTime)
    return $model
}

function Update-SystemStatusPopupPresentation {
    param([Windows.Forms.Form]$Form)
    $model = Get-SystemStatusPresentation
    $default = if ($model.Default -eq 'Value') { $model.DefaultName } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Default) }
    $next = if ($model.Next -eq 'Value') {
        $model.NextName + [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Relation))
    } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Next) }
    $ready = Get-LocalizedString -Key ('SystemStatus.'+$model.Readiness)
    if ($model.Hint) { $ready += [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Hint)) }
    $summary = Get-LocalizedString -Key ('SystemStatus.'+$model.Summary)
    if ($model.Refresh) { $summary += [Environment]::NewLine + (Get-LocalizedString -Key ('SystemStatus.'+$model.Refresh)) }
    $freshness = @(
        (Get-LocalizedString -Key 'SystemStatus.ManagerTime' -Values @{Time=(Format-SystemStatusObservedTime $(if ($script:NextBootFirmwareReadVerified) { $script:SystemStatusNextObservedUtc } else { $null }))}),
        (Get-LocalizedString -Key 'SystemStatus.EntriesTime' -Values @{Time=(Format-SystemStatusObservedTime $script:SystemStatusEntriesObservedUtc)}),
        (Get-LocalizedString -Key 'SystemStatus.ReadinessTime' -Values @{Time=(Format-SystemStatusObservedTime $script:SystemStatusReadinessObservedUtc)})
    ) -join [Environment]::NewLine
    $values = @{Summary=$summary;Stored=$default;Next=$next;Readiness=$ready;Drift=(Get-LocalizedString -Key ('SystemStatus.'+$model.Drift));Freshness=$freshness}
    foreach ($key in $values.Keys) {
        $label = $Form.Tag.Body.Controls['SystemStatusValue-'+$key]
        if ($label -and $label.Text -cne $values[$key]) {
            $label.Text = $values[$key]
            $label.AccessibleName = $label.Text
            $label.AccessibleDescription = $label.Text
            $Form.Tag.Tip.SetToolTip($label,$label.Text)
        }
    }
    $label = $Form.Tag.Body.Controls['SystemStatusValue-Summary']
    $label.ForeColor = if ([Windows.Forms.SystemInformation]::HighContrast) { [Drawing.SystemColors]::WindowText } elseif ($model.Summary -in @('SummaryAttention','SummaryUnknown')) { [Drawing.Color]::FromArgb(234,182,94) } else { $script:ColorPrimary }
}

function Set-SystemStatusPopupWidth {
    param($Form,[double]$Scale)
    $margin = [int][Math]::Round(16*$Scale)
    foreach ($control in $Form.Tag.Body.Controls) {
        $control.Left = $margin
        $control.Width = [Math]::Max(1,$Form.Tag.Body.Width-2*$margin)
    }
}

function New-SystemStatusPopup {
    $form = New-AuxiliaryPopupForm -Name 'LenovoSystemStatusPopup' -Title (Get-LocalizedString -Key 'SystemStatus.Title') -Subtitle (Get-LocalizedString -Key 'SystemStatus.Subtitle') -ContentHeight 440
    $y = 8
    $highContrast = [Windows.Forms.SystemInformation]::HighContrast
    $surface = if ($highContrast) { [Drawing.SystemColors]::Window } else { [Drawing.Color]::FromArgb(37,37,37) }
    $valueInk = if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorPrimary }
    $headingInk = if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorSecondary }
    if ($highContrast) {
        $form.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Body.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Viewport.BackColor = [Drawing.SystemColors]::Window
        $form.Tag.Header.BackColor = [Drawing.SystemColors]::Control
        $form.Tag.Title.ForeColor = [Drawing.SystemColors]::ControlText
        $form.Tag.Subtitle.ForeColor = [Drawing.SystemColors]::ControlText
        $form.Tag.Close.BackColor = [Drawing.SystemColors]::Control
        $form.Tag.Close.ForeColor = [Drawing.SystemColors]::ControlText
    }
    foreach ($row in @(
        @{Key='Summary';Height=52},
        @{Key='Stored';Height=40},
        @{Key='Next';Height=48},
        @{Key='Readiness';Height=66},
        @{Key='Drift';Height=34},
        @{Key='Freshness';Height=64}
    )) {
        if ($row.Key -ne 'Summary') {
            $heading = New-Label -Text (Get-LocalizedString -Key ('SystemStatus.'+$row.Key)) -Font $form.Tag.Heading -ForeColor $headingInk -X 16 -Y $y -Width 358 -Height 20
            $heading.Name = 'SystemStatusHeading-'+$row.Key
            $form.Tag.Body.Controls.Add($heading)
            $y += 20
        }
        $label = New-Label -Text '' -Font $form.Tag.Regular -ForeColor $valueInk -X 16 -Y $y -Width 358 -Height $row.Height
        $label.Name = 'SystemStatusValue-'+$row.Key
        $label.BackColor = $surface
        $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $label.Padding = [Windows.Forms.Padding]::new(6,2,6,2)
        $label.AutoEllipsis = $true
        $label.AccessibleRole = [Windows.Forms.AccessibleRole]::StaticText
        $form.Tag.Body.Controls.Add($label)
        $y += $row.Height+4
    }
    Update-SystemStatusPopupPresentation -Form $form
    # Reflect only in-memory state; no extra refresh, readiness probe or hardware polling.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        if ($script:ActiveAuxiliaryPopup -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoSystemStatusPopup') {
            Update-SystemStatusPopupPresentation -Form $script:ActiveAuxiliaryPopup
        }
    })
    $form.Tag.Timer = $timer
    # The shared owned-surface lifecycle starts this timer only after its initial activation handler.
    $form.Add_KeyDown({
        param($sender,$eventArgs)
        $scroll = $sender.Tag.Scroll
        if (-not $scroll.Visible) { return }
        $delta = switch ($eventArgs.KeyCode) {
            'PageDown' { $scroll.LargeChange }
            'PageUp' { -$scroll.LargeChange }
            'Down' { $scroll.SmallChange }
            'Up' { -$scroll.SmallChange }
            default { 0 }
        }
        if ($delta) {
            $scroll.Value = [Math]::Max(0,[Math]::Min($scroll.Maximum,$scroll.Value+$delta))
            $eventArgs.Handled=$true
            $eventArgs.SuppressKeyPress=$true
        }
    })
    return $form
}

function Show-SystemStatusPopup {
    param([Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog -or -not $Owner -or -not $Owner.Enabled) { return }
    [void](Show-OwnedAuxiliaryPopup -Form (New-SystemStatusPopup) -Owner $Owner)
}

# LBS-132: icon-relative placement is pure geometry; shell discovery is best effort.
function Get-PopupLocationFromAnchor {
    param(
        [Drawing.Rectangle]$WorkingArea,
        [Drawing.Rectangle]$DisplayBounds,
        [Drawing.Rectangle]$AnchorRect,
        [Drawing.Size]$PopupSize,
        [switch]$HasAnchor
    )
    $gap = 8
    $x = $WorkingArea.Right - $PopupSize.Width - $gap
    $y = $WorkingArea.Bottom - $PopupSize.Height - $gap

    if ($HasAnchor) {
        $centerX = $AnchorRect.Left + ($AnchorRect.Width / 2.0)
        $centerY = $AnchorRect.Top + ($AnchorRect.Height / 2.0)
        $x = [int][Math]::Round($centerX - ($PopupSize.Width / 2.0), 0, [MidpointRounding]::AwayFromZero)
        $topInset = $WorkingArea.Top - $DisplayBounds.Top
        $bottomInset = $DisplayBounds.Bottom - $WorkingArea.Bottom
        $leftInset = $WorkingArea.Left - $DisplayBounds.Left
        $rightInset = $DisplayBounds.Right - $WorkingArea.Right

        if ($leftInset -gt 0 -and $leftInset -ge $topInset -and $leftInset -ge $bottomInset -and $leftInset -ge $rightInset) {
            $x = $AnchorRect.Right + $gap
            $y = [int][Math]::Round($centerY - ($PopupSize.Height / 2.0))
        }
        elseif ($rightInset -gt 0 -and $rightInset -ge $topInset -and $rightInset -ge $bottomInset) {
            $x = $AnchorRect.Left - $PopupSize.Width - $gap
            $y = [int][Math]::Round($centerY - ($PopupSize.Height / 2.0))
        }
        elseif ($topInset -gt $bottomInset) {
            $y = $AnchorRect.Bottom + $gap
            if ($y + $PopupSize.Height -gt $WorkingArea.Bottom) {
                $y = $AnchorRect.Top - $PopupSize.Height - $gap
            }
        }
        else {
            # Bottom/auto-hidden taskbar and overflow: prefer directly above the icon.
            $y = $AnchorRect.Top - $PopupSize.Height - $gap
            if ($y -lt $WorkingArea.Top) {
                $y = $AnchorRect.Bottom + $gap
            }
        }
    }

    # The closest feasible centered position wins near display edges.
    $maxX = [Math]::Max($WorkingArea.Left, $WorkingArea.Right - $PopupSize.Width)
    $maxY = [Math]::Max($WorkingArea.Top, $WorkingArea.Bottom - $PopupSize.Height)
    $x = [int][Math]::Min($maxX, [Math]::Max($WorkingArea.Left, $x))
    $y = [int][Math]::Min($maxY, [Math]::Max($WorkingArea.Top, $y))
    return [Drawing.Point]::new($x, $y)
}

function ConvertTo-PopupTrayIconRectangle {
    param($Element, [string]$ExpectedName)
    if ($null -eq $Element) { return $null }
    try {
        $name = [string]$Element.Current.Name
        if (-not ($name.Equals($ExpectedName, [StringComparison]::OrdinalIgnoreCase) -or
                  $name.StartsWith(($ExpectedName + ' '), [StringComparison]::OrdinalIgnoreCase))) {
            return $null
        }
        if ($Element.Current.IsOffscreen) { return $null }
        $bounds = $Element.Current.BoundingRectangle
        if ($bounds.IsEmpty -or $bounds.Width -lt 12 -or $bounds.Height -lt 12 -or
            $bounds.Width -gt 192 -or $bounds.Height -gt 192) { return $null }
        return [Drawing.Rectangle]::new(
            [int][Math]::Round($bounds.Left), [int][Math]::Round($bounds.Top),
            [int][Math]::Round($bounds.Width), [int][Math]::Round($bounds.Height)
        )
    }
    catch { return $null }
}

function Get-VisiblePopupTrayIconRectangle {
    param([Drawing.Point]$ClickPoint, [switch]$HasClickPoint)
    try {
        # Supported Windows UI Automation public surface, never private NotifyIcon fields.
        Add-Type -AssemblyName WindowsBase, UIAutomationTypes, UIAutomationClient -ErrorAction Stop
        $expectedName = 'Lenovo Boot Selector'

        if ($HasClickPoint) {
            $element = [System.Windows.Automation.AutomationElement]::FromPoint([System.Windows.Point]::new($ClickPoint.X, $ClickPoint.Y))
            for ($depth = 0; $null -ne $element -and $depth -lt 6; $depth++) {
                $rect = ConvertTo-PopupTrayIconRectangle -Element $element -ExpectedName $expectedName
                if ($null -ne $rect) { return $rect }
                $element = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($element)
            }
        }

        # Search only bounded shell-owned top-level UIA trees, not the whole desktop.
        $desktopWindows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
        $shellClasses = @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd', 'NotifyIconOverflowWindow', 'TopLevelWindowForOverflowXamlIsland')
        $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::NameProperty, $expectedName)
        foreach ($window in $desktopWindows) {
            if ([string]$window.Current.ClassName -notin $shellClasses) { continue }
            $element = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            $rect = ConvertTo-PopupTrayIconRectangle -Element $element -ExpectedName $expectedName
            if ($null -ne $rect) { return $rect }
        }
    }
    catch {
        # Explorer restart, UIA access failure or missing overflow elements: no UI failure.
        return $null
    }
    return $null
}

# Avoid NotifyIcon's mixed-DPI shell auto-placement; use the WinForms cursor
# and Screen.WorkingArea coordinates together for this per-click menu location.
function Get-TrayContextMenuLocation {
    param(
        [Parameter(Mandatory=$true)][Drawing.Point]$ClickPoint,
        [Parameter(Mandatory=$true)][Drawing.Size]$MenuSize,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$DisplayBounds
    )
    $gap = 8
    $bottomInset = $DisplayBounds.Bottom - $WorkingArea.Bottom
    $topInset = $WorkingArea.Top - $DisplayBounds.Top
    $leftInset = $WorkingArea.Left - $DisplayBounds.Left
    $rightInset = $DisplayBounds.Right - $WorkingArea.Right
    $x = $ClickPoint.X - [int][Math]::Floor($MenuSize.Width / 2)
    $y = $ClickPoint.Y - $MenuSize.Height - $gap
    if ($topInset -gt $bottomInset -and $topInset -ge $leftInset -and $topInset -ge $rightInset) {
        $y = $ClickPoint.Y + $gap
    }
    elseif ($leftInset -gt $bottomInset -and $leftInset -gt $rightInset) {
        $x = $ClickPoint.X + $gap
        $y = $ClickPoint.Y - [int][Math]::Floor($MenuSize.Height / 2)
    }
    elseif ($rightInset -gt $bottomInset -and $rightInset -ge $leftInset) {
        $x = $ClickPoint.X - $MenuSize.Width - $gap
        $y = $ClickPoint.Y - [int][Math]::Floor($MenuSize.Height / 2)
    }
    $maxX = [Math]::Max($WorkingArea.Left, $WorkingArea.Right - $MenuSize.Width)
    $maxY = [Math]::Max($WorkingArea.Top, $WorkingArea.Bottom - $MenuSize.Height)
    return [Drawing.Point]::new(
        [int][Math]::Min($maxX, [Math]::Max($WorkingArea.Left, $x)),
        [int][Math]::Min($maxY, [Math]::Max($WorkingArea.Top, $y))
    )
}

# LBS-233: expand only to the left; clamp when a separate surface cannot fit.
function Get-AuxiliaryPopupLocation {
    param([Drawing.Rectangle]$WorkingArea,[Drawing.Rectangle]$OwnerBounds,[Drawing.Size]$SurfaceSize,[Drawing.Rectangle]$TriggerBounds = [Drawing.Rectangle]::Empty,[double]$Scale = 1.0)
    $gap = [int][Math]::Round(8*$Scale)
    $x = $OwnerBounds.Left - $SurfaceSize.Width - $gap
    $x = [int][Math]::Max($WorkingArea.Left,[Math]::Min($WorkingArea.Right-$SurfaceSize.Width,$x))
    # Keep horizontal placement relative to the parent, vertical placement to the initiating row.
    $anchorY = if ($TriggerBounds.IsEmpty) { $OwnerBounds.Top } else { $TriggerBounds.Top }
    $y = [int][Math]::Max($WorkingArea.Top,[Math]::Min($WorkingArea.Bottom-$SurfaceSize.Height,$anchorY))
    return [Drawing.Point]::new($x,$y)
}

# Escape belongs to this visible popup only. Child-local cancellation (alias editor,
# default-target menu and active drag) must run before any parent dismissal.
function Invoke-PopupEscapeDismissal {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.KeyEventArgs]$EventArgs
    )
    if (-not $Form -or -not $EventArgs -or
        $EventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Escape -or
        $EventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None) { return }
    if (-not $Form.Visible -or -not $Form.ContainsFocus) { return }

    # Owned auxiliary forms and OLE drag have independent Escape/cleanup lifecycles.
    if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog) { return }
    if ($script:ManageActiveDragGuid -or $script:ManageDragLayout) { return }

    $aliasEditor = $Form.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($aliasEditor -and -not $aliasEditor.IsDisposed -and $aliasEditor.ContainsFocus) { return }

    # Presentation-only: keep the Form, tray owner, workers and Manage draft alive.
    $EventArgs.Handled = $true
    $EventArgs.SuppressKeyPress = $true
    $Form.Hide()
}

function New-PopupForm {
    param([double]$TargetScale = 1.0, [string]$ScaleSource = 'initial')
    $form = New-Object System.Windows.Forms.Form
    if (-not $script:BootTypeToolTip) {
        $script:BootTypeToolTip = New-LenovoDarkTooltip -Animate
        $form.Add_Disposed({
            if ($script:BootTypeToolTip) {
                $script:BootTypeToolTip.Dispose()
                $script:BootTypeToolTip = $null
            }
        })
    }
    $form.Name = 'LenovoBootSelectorPopup'
    $form.KeyPreview = $true
    Initialize-PopupDpiLayout -Form $form
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

    # Scale the entire static control tree in one WinForms DPI pass.
    Complete-PopupDpiLayout -Form $form -Scale $TargetScale
    Write-PopupDpiLayoutDiagnostic -Form $form -Phase 'constructed' -MonitorSource $ScaleSource
    $form.Add_Shown({
        Write-PopupDpiLayoutDiagnostic -Form $this -Phase 'shown' -MonitorSource 'active-screen'
    })

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_MouseWheel({
        param($sender,$eventArgs)
        $list = $sender.Controls.Find('EntryList',$true) | Select-Object -First 1
        if ($list -and $list.Visible -and $list.RectangleToScreen($list.ClientRectangle).Contains([Windows.Forms.Cursor]::Position)) {
            Invoke-BootEntryWheelScroll -ListPanel $list -EventArgs $eventArgs
        }
    })
    $form.Add_KeyDown({
        param($sender, $eventArgs)
        Invoke-PopupEscapeDismissal -Form $sender -EventArgs $eventArgs
    })

    $form.Add_Deactivate({
        # The owned auxiliary Form is part of this popup's UI. The
        # ownership flag covers Deactivate before the child becomes visible.
        if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog) { return }
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if (-not $script:ExitRequested -and [string]$capabilities.State -ne 'Busy') { $this.Hide() }
    })

    return $form
}
function Position-Popup {
    param([switch]$FromTrayClick)
    if (-not $script:Popup) { return }

    $hasClick = $false
    $clickPoint = [Drawing.Point]::Empty
    if ($FromTrayClick -and $null -ne $script:TrayPopupClickUtc -and
        ([DateTime]::UtcNow - $script:TrayPopupClickUtc).TotalSeconds -le 30) {
        $clickPoint = $script:TrayPopupClickPoint
        $hasClick = $true
    }

    $iconRect = Get-VisiblePopupTrayIconRectangle -ClickPoint $clickPoint -HasClickPoint:$hasClick
    if ($null -ne $iconRect) {
        $screen = [System.Windows.Forms.Screen]::FromRectangle($iconRect)
    }
    elseif ($hasClick) {
        $screen = [System.Windows.Forms.Screen]::FromPoint($clickPoint)
        # Only a genuine recent NotifyIcon click may supply this approximate anchor.
        $iconRect = [Drawing.Rectangle]::new($clickPoint.X - 12, $clickPoint.Y - 12, 24, 24)
    }
    else {
        # Non-pointer/first-run fallback: deterministic primary display, never cursor.
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    if ($null -eq $screen) { return }
    $monitorScale = Get-LenovoUiCoordinateScale -Screen $screen
    $monitorChanged = Set-PopupDpiLayoutScale -Form $script:Popup -Scale ([double]$monitorScale.Factor)
    $viewportChanged = Set-PopupViewportForWorkingArea -Form $script:Popup -WorkingArea $screen.WorkingArea
    if ($monitorChanged -or $viewportChanged) { Update-PopupRows -Reason $(if ($monitorChanged) { 'dpi-changed' } else { 'viewport-changed' }) }
    Write-PopupDpiLayoutDiagnostic -Form $script:Popup -Phase 'positioned' -MonitorSource ([string]$monitorScale.Source)
    $location = Get-PopupLocationFromAnchor -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds -AnchorRect $iconRect -PopupSize $script:Popup.Size -HasAnchor:($null -ne $iconRect)
    $script:Popup.Location = $location
}

# A deliberate tray click must never hide the owner of a modal surface.
# Prefer the deepest application-owned dialog; ownership is set before Shown.
function Test-ActivateTrayModalSurface {
    foreach ($modal in @($script:ActiveOwnedDialog,$script:ActiveAuxiliaryPopup)) {
        if ($modal -and -not $modal.IsDisposed) {
            [LenovoSettingsWindowInput]::ActivateInitialSurface($modal)
            return $true
        }
    }
    return $false
}

function Show-OrTogglePopup {
    param([switch]$FromTrayClick)
    if ($script:PreferencesUiActive) { return }
    if (Test-ActivateTrayModalSurface) { return }
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $initialScreen = [System.Windows.Forms.Screen]::PrimaryScreen
        $initialScale = Get-LenovoUiCoordinateScale -Screen $initialScreen
        $script:Popup = New-PopupForm -TargetScale ([double]$initialScale.Factor) -ScaleSource ([string]$initialScale.Source)
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $maintenanceBusy = ([string]$capabilities.State -eq 'Busy')
    $canUseSystemState = [bool]$capabilities.CanUseCachedBootState
    if ($canUseSystemState) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if ([string]$capabilities.State -eq 'ReinitializeRequired') {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { Get-LocalizedString -Key 'Status.NewBootTargetDetected' } else { Get-LocalizedString -Key 'Status.BootTargetsChanged' }
            }
            elseif ([string]$capabilities.State -eq 'SetupRequired') {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup -FromTrayClick:$FromTrayClick
    $script:Popup.Show()
    $script:Popup.Activate()

    # LBS-21: opening the visible UI is the automatic read-only update-check trigger.
    # The update worker has its own busy gate and can overlap the independent boot-target worker.
    [void](Start-PopupUpdateCheck)

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($canUseSystemState -and -not $maintenanceBusy) {
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext) -Origin Popup
    }
}

# Explicit launcher re-entry is SHOW, never the tray-icon toggle (which hides
# an already visible popup). This runs on the existing WinForms UI thread.
function Show-OrActivatePopup {
    if ($script:PreferencesUiActive) { return }
    if (Test-ActivateTrayModalSurface) { return }
    if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) {
        [void]$script:Popup.Activate()
        return
    }
    Show-OrTogglePopup
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}

# Auxiliary forms are built at 96-DPI design bounds, then scaled once using
# the same effective coordinate factor as the main popup. Keep font points
# and the main popup's immutable metrics independent.
function Set-AuxiliaryControlBounds {
    param([System.Windows.Forms.Control]$Control,[double]$Scale)
    $Control.SuspendLayout()
    try {
        if ($Control -is [System.Windows.Forms.Form]) {
            $Control.ClientSize = [Drawing.Size]::new([int][Math]::Round($Control.ClientSize.Width*$Scale),[int][Math]::Round($Control.ClientSize.Height*$Scale))
        }
        else {
            $b = $Control.Bounds
            $Control.Bounds = [Drawing.Rectangle]::new([int][Math]::Round($b.X*$Scale),[int][Math]::Round($b.Y*$Scale),[int][Math]::Round($b.Width*$Scale),[int][Math]::Round($b.Height*$Scale))
        }
        foreach ($child in $Control.Controls) { Set-AuxiliaryControlBounds -Control $child -Scale $Scale }
    }
    finally { $Control.ResumeLayout($false) }
}

# Scroll position belongs to the custom bar; never let WinForms create a
# competing native scrollbar. Focus reveal is read-only and does not select.
function Set-AuxiliaryPopupControlVisible {
    param([Windows.Forms.Control]$Control)
    $form = $Control.FindForm()
    if (-not $form -or -not $form.Tag.Scroll -or $Control.Parent -ne $form.Tag.Body) { return }
    $state = $form.Tag
    $bar = $state.Scroll
    if ($Control.Top -lt $bar.Value) { $bar.Value = $Control.Top }
    elseif ($Control.Bottom -gt $bar.Value + $state.Viewport.Height) {
        $bar.Value = $Control.Bottom - $state.Viewport.Height
    }
}

function Add-AuxiliaryPopupWheelHandlers {
    param([Windows.Forms.Control]$Control)
    $Control.Add_MouseWheel({
        param($sender,$eventArgs)
        if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs] -and $eventArgs.Handled) { return }
        $form = $sender.FindForm()
        if (-not $form -or -not $form.Tag.Scroll -or $eventArgs.Delta -eq 0) { return }
        $bar = $form.Tag.Scroll
        if ($bar.Maximum -le 0) { return }
        $steps = [Math]::Max(1,[int][Math]::Abs([Math]::Truncate($eventArgs.Delta / 120.0)))
        $bar.Value = $bar.Value - [Math]::Sign($eventArgs.Delta)*$steps*$bar.SmallChange
        if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) { $eventArgs.Handled = $true }
    })
    foreach ($child in $Control.Controls) { Add-AuxiliaryPopupWheelHandlers -Control $child }
}

function Set-AuxiliaryPopupLayout {
    param([System.Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea,[Drawing.Rectangle]$OwnerBounds,[Drawing.Rectangle]$TriggerBounds = [Drawing.Rectangle]::Empty)
    if ($Form.Tag.Scale -ne 0) { throw 'Auxiliary surface has already been scaled.' }
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid auxiliary scale.' }
    Set-AuxiliaryControlBounds -Control $Form -Scale $Scale
    $state = $Form.Tag
    $state.Scale = $Scale
    $width = [Math]::Max(1,[Math]::Min($Form.ClientSize.Width,$WorkingArea.Width-12))
    $height = [Math]::Max(1,[Math]::Min($Form.ClientSize.Height,$WorkingArea.Height-12))
    $Form.ClientSize = [Drawing.Size]::new($width,$height)
    $state.Header.Width = $width
    $state.Close.Left = [Math]::Max(0,$width-$state.Close.Width-[int][Math]::Round(12*$Scale))
    $state.Title.Width = [Math]::Max(1,$state.Close.Left-$state.Title.Left)
    $state.Subtitle.Width = [Math]::Max(1,$width-$state.Subtitle.Left-[int][Math]::Round(16*$Scale))
    $viewportHeight = [Math]::Max(1,$height-$state.Viewport.Top)
    $contentHeight = [Math]::Max($viewportHeight,[int][Math]::Round($state.ContentHeight*$Scale))
    $range = $contentHeight-$viewportHeight
    $gutter = if ($range -gt 0) { [Math]::Min($width-1,[int][Math]::Round(8*$Scale)) } else { 0 }
    $state.Viewport.Size = [Drawing.Size]::new($width,$viewportHeight)
    $state.Body.Bounds = [Drawing.Rectangle]::new(0,0,$width-$gutter,$contentHeight)
    $state.Scroll.Bounds = [Drawing.Rectangle]::new($width-$gutter,0,$gutter,$viewportHeight)
    $state.Scroll.LargeChange = $viewportHeight
    $state.Scroll.SmallChange = [Math]::Max(1,[int][Math]::Round(60*$Scale))
    if ($Form.Name -eq 'LenovoConfigurationPopup') { Set-ConfigurationPopupWidth -Form $Form -Scale $Scale }
    if ($Form.Name -eq 'LenovoSystemStatusPopup') { Set-SystemStatusPopupWidth -Form $Form -Scale $Scale }
    $state.Scroll.Maximum = $range
    $state.Scroll.Value = 0
    $state.Scroll.Visible = ($range -gt 0 -and $gutter -gt 0)
    foreach ($control in $state.Body.Controls) {
        $control.Add_GotFocus({ param($sender,$eventArgs) Set-AuxiliaryPopupControlVisible -Control $sender })
    }
    Add-AuxiliaryPopupWheelHandlers -Control $Form
    $Form.Location = Get-AuxiliaryPopupLocation -WorkingArea $WorkingArea -OwnerBounds $OwnerBounds -SurfaceSize $Form.Size -TriggerBounds $TriggerBounds -Scale $Scale
}

# Owner-local black scrim. A separate layered, non-activating owned window
# dims the actual pixels (not desktop transparency or mutated control colors).
# It has no taskbar entry, no input/focus role and no independent lifetime.
function Initialize-AuxiliaryOwnerDimmer {
    if ('LenovoAuxiliaryOwnerDimmer' -as [type]) { return }
    $source = @'
using System;
using System.Drawing;
using System.Windows.Forms;

// A visual-only bridge; the existing modal forms retain their native bounds.
public sealed class LenovoAuxiliaryConnector : Form
{
    private Color fill;
    public Rectangle VisualBounds { get; private set; }
    public LenovoAuxiliaryConnector()
    {
        Name = "AuxiliaryConnector";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Opacity = 0.99;
        SetStyle(ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.AllPaintingInWmPaint, true);
    }

    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x00000080 | 0x08000000 | 0x00000020;
            return cp;
        }
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x0084) { m.Result = new IntPtr(-1); return; } // HTTRANSPARENT
        base.WndProc(ref m);
    }

    // All inputs are in screen coordinates. Never draw across the owner or
    // outside the actual work area; no right-side or overlapping bridge.
    public static Rectangle GetConnectorBounds(Rectangle work, Rectangle owner,
        Rectangle row, Rectangle child, double scale)
    {
        if (scale < 1.0 || scale > 5.0 || row.Width <= 0 || row.Height <= 0 ||
            !owner.Contains(row) || !work.Contains(row) || !work.Contains(child) ||
            row.Left != owner.Left || child.Right >= row.Left)
            return Rectangle.Empty;
        int gap = row.Left - child.Right;
        if (gap < 3 || gap > (int)Math.Round(8 * scale)) return Rectangle.Empty;
        int half = Math.Max(2, (int)Math.Round(7 * scale));
        int center = row.Top + row.Height / 2;
        if (center - half <= child.Top || center + half >= child.Bottom ||
            center - half < row.Top || center + half >= row.Bottom)
            return Rectangle.Empty;
        Rectangle bridge = new Rectangle(child.Right, center - half, gap, 2 * half + 1);
        return work.Contains(bridge) ? bridge : Rectangle.Empty;
    }

    private Point[] Triangle()
    {
        // WinForms enforces a native minimum size (16x16 on the hosted
        // Windows runner). The visible region must use the requested geometry,
        // never the larger backing window dimensions.
        return new Point[] { new Point(0, 0), new Point(VisualBounds.Width - 1, VisualBounds.Height / 2),
            new Point(0, VisualBounds.Height - 1) };
    }

    public void SetGeometry(Rectangle bounds, Color color)
    {
        fill = color;
        VisualBounds = bounds;
        Bounds = bounds;
        using (var path = new System.Drawing.Drawing2D.GraphicsPath())
        {
            path.AddPolygon(Triangle());
            Region old = Region;
            Region = new Region(path);
            if (old != null) old.Dispose();
        }
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        using (var brush = new SolidBrush(fill))
        using (var pen = new Pen(Color.FromArgb(108, 108, 108)))
        {
            Point[] triangle = Triangle();
            e.Graphics.FillPolygon(brush, triangle);
            e.Graphics.DrawLines(pen, triangle);
        }
    }
}

// Separate input-only owner surface. Nonzero layered alpha is required for
// native hit testing; one alpha unit is visually negligible. The original
// scrim, its highlighted-row hole, and connector remain visual-only.
public sealed class LenovoAuxiliaryOwnerClickShield : Form
{
    private readonly Form parent;
    private readonly Form child;
    private bool armed;
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool IsWindowEnabled(IntPtr hwnd);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public LenovoAuxiliaryOwnerClickShield(Form owner, Form surface)
    {
        parent = owner;
        child = surface;
        Name = "AuxiliaryOwnerClickShield";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.Black;
        Opacity = 1.0 / 255.0;
        TopMost = surface.TopMost;
        TabStop = false;
        SetStyle(ControlStyles.Selectable, false);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            // TOOLWINDOW, NOACTIVATE; deliberately NOT WS_EX_TRANSPARENT.
            cp.ExStyle |= 0x00000080 | 0x08000000;
            return cp;
        }
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x0021) { m.Result = new IntPtr(3); return; } // MA_NOACTIVATE
        if (m.Msg == 0x0202) { // WM_LBUTTONUP
            bool dismiss = armed && CanDismiss() && InExposedOwner(PointToClient(Cursor.Position));
            armed = false;
            base.WndProc(ref m);
            Capture = false;
            if (dismiss && CanDismiss() && child.CancelButton != null)
                child.CancelButton.PerformClick();
            return;
        }
        base.WndProc(ref m);
    }
    private bool CanDismiss()
    {
        return !IsDisposed && !Disposing && parent.Visible && !parent.IsDisposed &&
            child.Visible && !child.IsDisposed && child.IsHandleCreated &&
            child.Modal && IsWindowEnabled(child.Handle) && child.DialogResult == DialogResult.None;
    }
    private bool InExposedOwner(Point point)
    {
        return ClientRectangle.Contains(point) &&
            !child.Bounds.Contains(PointToScreen(point));
    }
    public void SyncOwnerBounds()
    {
        if (IsDisposed || Disposing || parent.IsDisposed || parent.Disposing ||
            child.IsDisposed || child.Disposing || !parent.Visible || !child.Visible)
        {
            armed = false;
            if (!IsDisposed && !Disposing) Hide();
            return;
        }
        Rectangle ownerBounds = parent.RectangleToScreen(parent.ClientRectangle);
        Bounds = ownerBounds;
        Rectangle overlap = Rectangle.Intersect(ownerBounds, child.Bounds);
        Region next = new Region(ClientRectangle);
        if (!overlap.IsEmpty) {
            overlap.Offset(-ownerBounds.Left, -ownerBounds.Top);
            next.Exclude(overlap);
        }
        Region old = Region;
        Region = next;
        if (old != null) old.Dispose();
        if (!Visible) { Owner = parent; Show(); }
        // Keep the shield behind the child, including constrained overlap,
        // and above the disabled owner. No activation or focus transfer.
        SetWindowPos(Handle, child.Handle, 0, 0, 0, 0, 0x0013);
    }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        armed = CanDismiss() && InExposedOwner(e.Location);
        if (armed) Capture = true;
    }
    protected override void OnMouseCaptureChanged(EventArgs e)
    {
        if (!Capture) armed = false;
        base.OnMouseCaptureChanged(e);
    }
    protected override void OnEnabledChanged(EventArgs e)
    {
        if (!Enabled) { armed = false; Capture = false; }
        base.OnEnabledChanged(e);
    }
}

public sealed class LenovoAuxiliaryOwnerDimmer : Form
{
    private Form parent;
    private Form child;
    private Control row;
    private Control rowContainer;
    private readonly double scale;
    private readonly Color highlight;
    private readonly Color accent;
    private Color previousRowColor;
    private bool rowHighlighted;
    private bool childShown;
    private LenovoAuxiliaryConnector connector;
    private bool dismissOnOwnerClick;
    private LenovoAuxiliaryOwnerClickShield clickShield;
    public void EnableOwnerClickDismissal() { dismissOnOwnerClick = true; }
    public Rectangle HighlightedRowBounds { get; private set; }

    public LenovoAuxiliaryOwnerDimmer(Form owner, Control trigger, Form surface,
        double coordinateScale, Color highlightColor, Color accentColor)
    {
        if (owner == null) throw new ArgumentNullException("owner");
        parent = owner;
        child = surface;
        scale = coordinateScale;
        highlight = highlightColor;
        accent = accentColor;
        if (trigger != null && (trigger.Name == "SettingsPanel" || trigger.Name == "DefaultPanel")
            && trigger.FindForm() == owner)
        {
            row = trigger;
            rowContainer = row.Parent;
            previousRowColor = row.BackColor;
            row.Paint += PaintRow;
            row.BackColorChanged += KeepRowHighlight;
            row.LocationChanged += SyncBounds;
            row.SizeChanged += SyncBounds;
            row.VisibleChanged += SyncBounds;
            row.ParentChanged += SyncBounds;
            row.Disposed += SyncBounds;
            if (rowContainer != null) rowContainer.Layout += SyncBounds;
        }
        Name = "AuxiliaryOwnerDimmer";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.Black;
        Opacity = 0.45;
        TopMost = owner.TopMost;
        parent.LocationChanged += SyncBounds;
        parent.SizeChanged += SyncBounds;
        parent.Layout += SyncBounds;
        parent.VisibleChanged += SyncBounds;
        child.LocationChanged += SyncBounds;
        child.SizeChanged += SyncBounds;
        child.VisibleChanged += SyncBounds;
        child.Shown += SurfaceShown;
        child.Disposed += SyncBounds;
        SyncBounds(null, EventArgs.Empty);
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            // TOOLWINDOW, NOACTIVATE, TRANSPARENT (layered-window hit testing).
            cp.ExStyle |= 0x00000080 | 0x08000000 | 0x00000020;
            return cp;
        }
    }

    private Rectangle GetVisibleRow(Rectangle ownerBounds)
    {
        if (row == null || row.IsDisposed || row.Disposing || !row.Visible ||
            row.FindForm() != parent || row.Parent != rowContainer)
            return Rectangle.Empty;
        Rectangle bounds = row.RectangleToScreen(row.ClientRectangle);
        if (!ownerBounds.Contains(bounds) || bounds.Width <= 0 || bounds.Height <= 0)
            return Rectangle.Empty;
        for (Control c = row.Parent; c != null; c = c.Parent)
        {
            if (!c.RectangleToScreen(c.ClientRectangle).Contains(bounds))
                return Rectangle.Empty;
            if (c == parent) break;
        }
        return bounds;
    }

    private void SetRowHighlight(bool enabled)
    {
        if (row == null || row.IsDisposed || row.Disposing || rowHighlighted == enabled) return;
        rowHighlighted = enabled;
        row.BackColor = enabled ? highlight : previousRowColor;
        row.Invalidate();
    }
    private void KeepRowHighlight(object sender, EventArgs args)
    {
        if (rowHighlighted && row.BackColor != highlight) row.BackColor = highlight;
    }
    private void PaintRow(object sender, PaintEventArgs args)
    {
        if (!rowHighlighted) return;
        using (var brush = new SolidBrush(accent))
            args.Graphics.FillRectangle(brush, 0, 0, Math.Max(1, (int)Math.Round(3 * scale)), row.Height);
    }
    private void SurfaceShown(object sender, EventArgs args)
    {
        childShown = true;
        // Create after the native modal loop has disabled its existing owner
        // windows; never enable the main owner or bypass nested modal state.
        if (dismissOnOwnerClick && clickShield == null)
            clickShield = new LenovoAuxiliaryOwnerClickShield(parent, child);
        SyncBounds(sender, args);
    }
    private void HideConnector()
    {
        if (connector != null && !connector.IsDisposed) connector.Hide();
    }

    private void SyncBounds(object sender, EventArgs args)
    {
        if (parent == null || parent.IsDisposed || parent.Disposing || IsDisposed || Disposing)
        {
            HideConnector();
            return;
        }
        Rectangle ownerBounds = parent.RectangleToScreen(parent.ClientRectangle);
        Bounds = ownerBounds;
        Rectangle rowBounds = GetVisibleRow(ownerBounds);
        bool usable = parent.Visible && child != null && !child.IsDisposed && !child.Disposing &&
            !rowBounds.IsEmpty;
        HighlightedRowBounds = usable ? rowBounds : Rectangle.Empty;
        Region next = null;
        if (usable)
        {
            next = new Region(ClientRectangle);
            Rectangle hole = rowBounds;
            hole.Offset(-ownerBounds.Left, -ownerBounds.Top);
            next.Exclude(hole);
        }
        Region old = Region;
        Region = next;
        if (old != null) old.Dispose();
        SetRowHighlight(usable);
        if (clickShield != null) clickShield.SyncOwnerBounds();

        if (!usable || !child.Visible || !childShown)
        {
            HideConnector();
            return;
        }
        Rectangle bridge = LenovoAuxiliaryConnector.GetConnectorBounds(
            Screen.FromControl(parent).WorkingArea, ownerBounds, rowBounds, child.Bounds, scale);
        if (bridge.IsEmpty)
        {
            HideConnector();
            return;
        }
        Color fill = child.BackColor;
        Control header = child.Controls["AuxiliaryHeader"];
        if (header != null && header.RectangleToScreen(header.ClientRectangle).Contains(
                new Point(child.Right - 1, bridge.Top + bridge.Height / 2)))
            fill = header.BackColor;
        if (connector == null || connector.IsDisposed)
        {
            connector = new LenovoAuxiliaryConnector();
            connector.TopMost = child.TopMost;
        }
        connector.SetGeometry(bridge, fill);
        if (!connector.Visible)
        {
            connector.Owner = child;
            connector.Show();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (parent != null)
            {
                parent.LocationChanged -= SyncBounds;
                parent.SizeChanged -= SyncBounds;
                parent.Layout -= SyncBounds;
                parent.VisibleChanged -= SyncBounds;
                parent = null;
            }
            if (child != null)
            {
                child.LocationChanged -= SyncBounds;
                child.SizeChanged -= SyncBounds;
                child.VisibleChanged -= SyncBounds;
                child.Shown -= SurfaceShown;
                child.Disposed -= SyncBounds;
                child = null;
            }
            if (row != null)
            {
                row.Paint -= PaintRow;
                row.BackColorChanged -= KeepRowHighlight;
                row.LocationChanged -= SyncBounds;
                row.SizeChanged -= SyncBounds;
                row.VisibleChanged -= SyncBounds;
                row.ParentChanged -= SyncBounds;
                row.Disposed -= SyncBounds;
                if (rowContainer != null) rowContainer.Layout -= SyncBounds;
                SetRowHighlight(false);
                row = null;
                rowContainer = null;
            }
            if (clickShield != null)
            {
                clickShield.Dispose();
                clickShield = null;
            }
            if (connector != null)
            {
                connector.Dispose();
                connector = null;
            }
        }
        base.Dispose(disposing);
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $source -ErrorAction Stop
}

# Modal ownership prevents competing main-popup selections while a child is
# open. No business action is dispatched by this lifecycle function.
function Show-OwnedAuxiliaryPopup {
    param([System.Windows.Forms.Form]$Form,[System.Windows.Forms.Control]$Owner)
    $dimmer = $null
    $ownerRefreshButton = $null
    $ownerStatusButton = $null
    try {
        if ($script:ActiveAuxiliaryPopup -or -not $Owner -or $Owner.IsDisposed) { return $null }
        $parent = $Owner.FindForm()
        if (-not $parent -or -not $parent.Visible) { return $null }
        $screen = [Windows.Forms.Screen]::FromControl($parent)
        $scale = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
        $triggerBounds = $Owner.RectangleToScreen($Owner.ClientRectangle)
        Set-AuxiliaryPopupLayout -Form $Form -Scale ([double]$scale) -WorkingArea $screen.WorkingArea -OwnerBounds $parent.Bounds -TriggerBounds $triggerBounds
        $script:ActiveAuxiliaryPopup = $Form
        if ($script:RefreshButton -and -not $script:RefreshButton.IsDisposed -and [object]::ReferenceEquals($script:RefreshButton.FindForm(),$parent)) {
            $ownerRefreshButton = $script:RefreshButton
            $ownerRefreshButton.Refresh()
        }
        if ($script:SystemStatusButton -and -not $script:SystemStatusButton.IsDisposed -and [object]::ReferenceEquals($script:SystemStatusButton.FindForm(),$parent)) {
            $ownerStatusButton = $script:SystemStatusButton
            $ownerStatusButton.Refresh()
        }
        Initialize-AuxiliaryOwnerDimmer
        $dimmer = [LenovoAuxiliaryOwnerDimmer]::new($parent,$Owner,$Form,[double]$scale,(Get-PopupNavigationHoverColor),$script:ColorAccent)
        if ($Form.Name -in @('LenovoConfigurationPopup','LenovoDefaultTargetPicker','LenovoSystemStatusPopup')) { $dimmer.EnableOwnerClickDismissal() }
        # Show without activation before the child, which retains its normal
        # modal ownership, z-order and focus even on overlapping placement.
        $dimmer.Show($parent)
        # Both supported auxiliary surfaces receive keyboard focus once as
        # part of deliberate modal opening, after the dimmer's connector.
        if ($Form.Name -in @('LenovoConfigurationPopup','LenovoDefaultTargetPicker','LenovoSystemStatusPopup')) {
            $Form.Add_Shown({
                param($sender,$eventArgs)
                if ($sender.IsDisposed -or -not $sender.Visible -or
                    -not [object]::ReferenceEquals($script:ActiveAuxiliaryPopup,$sender) -or
                    $script:ActiveOwnedDialog) { return }
                [LenovoSettingsWindowInput]::ActivateInitialSurface($sender)
                if (-not $sender.Tag.Body.ContainsFocus) {
                    $target = $sender.Tag.Body.Controls | Where-Object {
                        $_.TabStop -and $_.CanFocus -and $_.Enabled -and $_.Visible
                    } | Sort-Object TabIndex | Select-Object -First 1
                    if ($target) { [void]$target.Focus() }
                    elseif ($sender.Tag.Close.CanFocus) { [void]$sender.Tag.Close.Focus() }
                }
                # This marks completion of the existing one-time Shown sequence, not a readiness or focus result.
                # The dimmer's Shown handler has already run; no periodic activation or shield-dependent retries.
                $sender.Tag.InitialModalActivationComplete = $true
                if ($sender.Name -eq 'LenovoSystemStatusPopup' -and $sender.Tag.Timer) { $sender.Tag.Timer.Start() }
            })
        }
        $result = $Form.ShowDialog($parent)
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return $Form.Tag.Choice }
        return $null
    }
    finally {
        try { if ($dimmer) { $dimmer.Dispose() } }
        finally {
            if ([object]::ReferenceEquals($script:ActiveAuxiliaryPopup,$Form)) { $script:ActiveAuxiliaryPopup = $null }
            try { $Form.Dispose() }
            finally {
                if ($dimmer -and $Owner -and -not $Owner.IsDisposed -and $Owner.Name -in @('SettingsPanel','DefaultPanel')) { Set-PopupNavigationRowHover -Control $Owner -Hover $false }
                if ($ownerRefreshButton -and -not $ownerRefreshButton.IsDisposed) { $ownerRefreshButton.Refresh() }
                if ($ownerStatusButton -and -not $ownerStatusButton.IsDisposed) { $ownerStatusButton.Refresh() }
                if ($dimmer -and $Owner -and -not $Owner.IsDisposed -and $Owner.Name -eq 'HeaderSystemStatusButton' -and $Owner.CanFocus) { [void]$Owner.Focus() }
            }
        }
    }
}


Initialize-RuntimeDiagnostics
if (-not ($BootNextWorker -or $BackgroundRefresh -or $UpdateCheck -or $UpdatePrepare -or $DefaultTargetWorker)) {
    try { [void](Get-DiagnosticsInstallationId -SettingsDirectory $script:SettingsDir) }
    catch { Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_INSTALLATION_ID_UNAVAILABLE' -Stage 'startup' -Success $false -ErrorRecord $_ -Level warning }
}
if (-not $BackgroundRefresh) {
    if ($singleInstanceMutexState -eq 'abandoned-recovered') {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs }) -Level warning
    }
    elseif ($mutexOwned) {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ACQUIRED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs })
    }
}

if ($BootNextWorker) {
    $exitCode = Invoke-BootNextSelectionWorker -Guid $BootNextGuid -ResultPath $BootNextResultPath
    exit $exitCode
}
if ($DefaultTargetWorker) {
    $exitCode = Invoke-DefaultTargetWorker -Guid $DefaultTargetGuid -Clear ([bool]$DefaultTargetClear) -ResultPath $DefaultTargetResultPath -ProgressPath $DefaultTargetProgressPath
    exit $exitCode
}
if ($BackgroundRefresh) {
    $exitCode = Invoke-BackgroundRefreshWorker -RefreshStorage ([bool]$BackgroundRefreshStorage) -RefreshFirmware ([bool]$BackgroundRefreshFirmware) -ResultPath $BackgroundResultPath
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
    # Establish the DPI context before constructing the first WinForms HWND.
    $uiDpi = Initialize-LenovoUiDpiAwareness
    Write-RuntimeDiagnosticEvent -Event 'UI_DPI_AWARENESS_INITIALIZED' -Stage 'ui-layout' -Success ([bool]$uiDpi.Success) -Data (New-RuntimeDiagnosticData @{
        awareness = [string]$uiDpi.Awareness
    }) -Level $(if ($uiDpi.Success) { 'info' } else { 'warning' })
    Write-RuntimeDiagnosticEvent -Event 'TRAY_STARTUP' -Stage 'startup' -Success $true
    Load-AppSettings
    [void](Resolve-PendingLocalePreference)
    $script:LastStatusText = Get-LocalizedString -Key 'Status.Ready'
    Repair-AutostartLauncherIfNeeded

    $initialPopupScale = Get-LenovoUiCoordinateScale -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
    $script:Popup = New-PopupForm -TargetScale ([double]$initialPopupScale.Factor) -ScaleSource ([string]$initialPopupScale.Source)
    # The pre-handle Screen.WorkingArea can be DPI-virtualized at 250%.
    # Capture both sides to distinguish DPI initialization from menu geometry.
    $preHandleWork = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    Initialize-LenovoTrayDpiContext -Popup $script:Popup
    $postHandleWork = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    Write-RuntimeDiagnosticEvent -Event 'TRAY_DPI_CONTEXT_INITIALIZED' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData @{
        preHandleWorkWidth = [int]$preHandleWork.Width
        preHandleWorkHeight = [int]$preHandleWork.Height
        postHandleWorkWidth = [int]$postHandleWork.Width
        postHandleWorkHeight = [int]$postHandleWork.Height
        popupHandleCreated = [bool]$script:Popup.IsHandleCreated
        popupVisible = [bool]$script:Popup.Visible
    })
    Write-LenovoMonitorTopologyEvent -Phase 'startup' -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
    $activationListener = Start-LbsActivationListener -Signal $activationEvent -OnActivate {
        try {
            Show-OrActivatePopup
            Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_ACTIVATED' -Stage 'ui' -Success $true
        }
        catch {
            Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_ACTIVATION_FAILED' -Stage 'ui' -Success $false -ErrorRecord $_ -Level warning
        }
    }
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
    $openItem.ForeColor = [Drawing.Color]::FromArgb(255,110,102)
    $openItem.Add_Click({ Show-OrTogglePopup -FromTrayClick })
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
    $languageRoot.DropDown.Name = 'LenovoLanguageDropDown'
    Initialize-LenovoMenuAppearance -Menu $languageRoot.DropDown
    $languageRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })
    $script:LanguageMenuRoot = $languageRoot

    $languageEnglish = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageEnglish.Name = 'LocaleFlag.en-US'
    $languageEnglish.Text = Get-LocalizedString -Key 'Language.English'
    $languageEnglish.Padding = New-Object System.Windows.Forms.Padding(38, 4, 32, 4)
    $languageEnglish.Add_Click({ [void](Set-LanguageFromUi -Locale 'en-US') })
    $script:LanguageEnglishMenuItem = $languageEnglish
    [void]$languageRoot.DropDownItems.Add($languageEnglish)

    $languageGerman = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageGerman.Name = 'LocaleFlag.de-DE'
    $languageGerman.Text = Get-LocalizedString -Key 'Language.German'
    $languageGerman.Padding = New-Object System.Windows.Forms.Padding(38, 4, 32, 4)
    $languageGerman.Add_Click({ [void](Set-LanguageFromUi -Locale 'de-DE') })
    $script:LanguageGermanMenuItem = $languageGerman
    [void]$languageRoot.DropDownItems.Add($languageGerman)

    Update-LanguageMenuState
    [void]$context.Items.Add($languageRoot)

    $preferencesRoot = New-Object Windows.Forms.ToolStripMenuItem
    $preferencesRoot.Text = Get-LocalizedString -Key 'Preferences.Menu'
    $preferencesRoot.DropDown = New-Object LenovoDropDownMenu
    $preferencesRoot.DropDown.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $preferencesRoot.DropDown
    $preferencesRoot.Add_DropDownOpening({
        Initialize-LenovoMenuAppearance -Menu $this.DropDown
        Update-PortablePreferencesMenuState
    })
    $script:PreferencesMenuRoot = $preferencesRoot
    $exportItem = New-Object Windows.Forms.ToolStripMenuItem
    $exportItem.Text = Get-LocalizedString -Key 'Preferences.Export'
    $exportItem.Padding = New-LenovoSubmenuActionPadding
    $exportItem.Add_Click({ Show-PortablePreferencesFromUi -Mode Export })
    $script:PreferencesExportMenuItem = $exportItem
    [void]$preferencesRoot.DropDownItems.Add($exportItem)
    $importItem = New-Object Windows.Forms.ToolStripMenuItem
    $importItem.Text = Get-LocalizedString -Key 'Preferences.Import'
    $importItem.Padding = New-LenovoSubmenuActionPadding
    $importItem.Add_Click({ Show-PortablePreferencesFromUi -Mode Import })
    $script:PreferencesImportMenuItem = $importItem
    [void]$preferencesRoot.DropDownItems.Add($importItem)
    [void]$context.Items.Add($preferencesRoot)

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
    $setupItem.Padding = New-LenovoSubmenuActionPadding
    $setupItem.Add_Click({ Prompt-TaskBrokerInstall })
    $script:TaskBrokerSetupMenuItem = $setupItem
    [void]$maintenanceRoot.DropDownItems.Add($setupItem)

    $removeTasksItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $removeTasksItem.Text = Get-LocalizedString -Key 'Maintenance.Remove'
    $removeTasksItem.Padding = New-LenovoSubmenuActionPadding
    $removeTasksItem.Add_Click({ Prompt-TaskBrokerRemove })
    $script:TaskBrokerRemoveMenuItem = $removeTasksItem
    [void]$maintenanceRoot.DropDownItems.Add($removeTasksItem)

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $updateCheckItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateCheckItem.Text = Get-LocalizedString -Key 'Update.Check'
    $updateCheckItem.Padding = New-LenovoSubmenuActionPadding
    $updateCheckItem.Add_Click({ Start-ManualUpdateCheck })
    $script:UpdateCheckMenuItem = $updateCheckItem
    [void]$maintenanceRoot.DropDownItems.Add($updateCheckItem)

    $updateInstallItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateInstallItem.Text = Get-LocalizedString -Key 'Update.Install'
    $updateInstallItem.Padding = New-LenovoSubmenuActionPadding
    $updateInstallItem.Enabled = $false
    $updateInstallItem.Add_Click({ Start-ManualAppUpdate })
    $script:UpdateInstallMenuItem = $updateInstallItem
    [void]$maintenanceRoot.DropDownItems.Add($updateInstallItem)
    Update-UpdateMenuState

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $diagnosticItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagnosticItem.Text = Get-LocalizedString -Key 'Diagnostics.Save'
    $diagnosticItem.Padding = New-LenovoSubmenuActionPadding
    $diagnosticItem.Add_Click({ Save-RuntimeDiagnosticsFromUi })
    $script:RuntimeDiagnosticMenuItem = $diagnosticItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)

    $diagnosticUploadItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagnosticUploadItem.Text = Get-LocalizedString -Key 'Diagnostics.Upload'
    $diagnosticUploadItem.Padding = New-LenovoSubmenuActionPadding
    $diagnosticUploadItem.Add_Click({ Start-DiagnosticsUploadFromUi })
    $script:DiagnosticsUploadMenuItem = $diagnosticUploadItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticUploadItem)

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

    # Shell-owned auto-placement jumped to a different monitor in mixed DPI.
    $script:TrayContextMenu = $context
    $script:TrayIcon.ContextMenuStrip = $null
    [void](Show-PendingUpdateResultOnStartup)
    $script:TrayPopupClickUtc = $null
    $script:TrayPopupClickPoint = [Drawing.Point]::Empty
    $script:TrayIcon.Add_MouseClick({
        param($sender, $eventArgs)
        if ($script:PreferencesUiActive) {
            # The native chooser owns focus while no app-owned confirmation is
            # active. Never activate the disabled window beneath it.
            if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Right -and
                $script:ActiveOwnedDialog -and -not $script:ActiveOwnedDialog.IsDisposed) {
                [LenovoSettingsWindowInput]::ActivateInitialSurface($script:ActiveOwnedDialog)
            }
            return
        }
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -or
            $eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            # Capture only genuine tray-icon clicks; never borrow arbitrary cursor state.
            $script:TrayPopupClickPoint = [System.Windows.Forms.Cursor]::Position
            $script:TrayPopupClickUtc = [DateTime]::UtcNow
        }
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-OrTogglePopup -FromTrayClick
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            if (Test-ActivateTrayModalSurface) { return }
            if ($script:Popup -and $script:Popup.Visible) { $script:Popup.Hide() }
            $point = $script:TrayPopupClickPoint
            $screen = [System.Windows.Forms.Screen]::FromPoint($point)
            if ($script:TrayContextMenu -and $screen) {
                Write-LenovoMonitorTopologyEvent -Phase 'tray-click' -Screen $screen
                Initialize-LenovoMenuAppearance -Menu $script:TrayContextMenu
                $factor = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
                [void](Set-LenovoMenuDpiLayout -Menu $script:TrayContextMenu -Scale ([double]$factor))
                $size = $script:TrayContextMenu.GetPreferredSize([Drawing.Size]::Empty)
                $location = Get-TrayContextMenuLocation -ClickPoint $point -MenuSize $size -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds
                Write-LenovoDpiWindowEvent -Control $script:TrayContextMenu -Role 'tray-root' -Phase 'before-show-call' -Screen $screen -RequestedScale ([double]$factor)
                $script:TrayContextMenu.Show($location)
                Write-LenovoDpiWindowEvent -Control $script:TrayContextMenu -Role 'tray-root' -Phase 'after-show-call' -Screen $screen -RequestedScale ([double]$factor)
                Write-RuntimeDiagnosticEvent -Event 'TRAY_CONTEXT_MENU_LOCATION' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData @{
                    menuWidth = [int]$size.Width
                    menuHeight = [int]$size.Height
                    screenWorkWidth = [int]$screen.WorkingArea.Width
                    screenWorkHeight = [int]$screen.WorkingArea.Height
                    menuShownOnClickMonitor = [bool]($screen.Bounds.Contains($location))
                })
            }
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
            Start-BackgroundBootRefresh -RefreshStorage -Origin Startup
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
        try { Stop-UpdateCheckWorkflow -State $script:UpdateState } catch { }
        try { Stop-UpdatePrepareWorkflow -State $script:UpdateState } catch { }
    }
    Stop-BootNextSelectionWorker -Reason 'shutdown'
    Stop-DefaultTargetChangeWorker -Reason 'shutdown'
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
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Process) {
        try { $backgroundRefreshContext.Process.Refresh() } catch { }
        try { if (-not $backgroundRefreshContext.Process.HasExited) { $backgroundRefreshContext.Process.Kill() } } catch { }
        try { $backgroundRefreshContext.Process.Dispose() } catch { }
    }
    if ($backgroundRefreshContext) {
        Remove-BackgroundRefreshResultFile -Path ([string]$backgroundRefreshContext.ResultPath)
    }
    if ($script:DiagnosticsUploadTimer) {
        try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
        $script:DiagnosticsUploadTimer = $null
    }
    if ($script:DiagnosticsUploadState) {
        try { $script:DiagnosticsUploadState.Client.CancelPendingRequests() } catch { }
        Dispose-DiagnosticsUploadTransport -Context $script:DiagnosticsUploadState
        $script:DiagnosticsUploadState = $null
    }
    if ($script:TrayIcon) {
        $script:TrayIcon.Visible = $false
        $script:TrayIcon.Dispose()
    }
    if ($activationListener) {
        try { Stop-LbsActivationListener -Listener $activationListener } catch { }
        $activationListener = $null
    }
    if ($activationEvent) {
        try { $activationEvent.Dispose() } catch { }
        $activationEvent = $null
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
