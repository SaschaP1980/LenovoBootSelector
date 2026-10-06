#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Infrastructure\SettingsRepository.ps1')
. (Join-Path $root 'src\Application\SettingsService.ps1')
. (Join-Path $root 'src\Application\LocalizationService.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $root 'src\UI\StartupRecoveryDialog.ps1')

$checks = 0
function Assert-Localization([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "LOCALIZATION FAIL: $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-LocalizationTest-' + [guid]::NewGuid().ToString('N'))
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $appDataRoot = Join-Path $tempRoot 'LocalAppData'
    $script:SettingsDir = Join-Path $appDataRoot 'Lenovo Boot Menu Tray'
    $script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
    $env:LOCALAPPDATA = $appDataRoot
    $script:EntryAliases = @{}
    $script:LegacyDefaultGuid = $null
    $script:DefaultGuid = $null
    $script:EntryOrder = @()
    $script:HiddenEntryGuids = @()
    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    $script:LocalePreferenceNeedsConfirmation = $false
    $script:LegacySessionRestoreRegistryPath = 'HKCU:\Software\LenovoBootSelector-Test-DoesNotExist'
    $script:LegacySessionRestoreValueName = 'Restore'

    $defaults = New-DefaultAppSettingsCore
    Assert-Localization 'Brand-new settings use schema 6' ([int]$defaults.schemaVersion -eq 6)
    Assert-Localization 'Brand-new settings default to en-US' ([string]$defaults.locale -eq 'en-US')
    Assert-Localization 'Brand-new settings mark locale as default' ([string]$defaults.localePreferenceSource -eq 'default')
    Assert-Localization 'Brand-new settings need no locale confirmation' (-not [bool]$defaults.localePreferenceNeedsConfirmation)
    Assert-Localization 'Active locale starts as en-US' ((Get-ActiveLocale) -eq 'en-US')
    Assert-Localization 'Central English lookup works' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Cancel')

    $selected = Set-ActiveLocale -Locale 'de-DE' -Persist
    Assert-Localization 'German selection resolves to de-DE' ($selected -eq 'de-DE')
    Assert-Localization 'Language selection writes settings file' (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Persisted settings use schema 6 and de-DE' ([int]$persisted.schemaVersion -eq 6 -and [string]$persisted.locale -eq 'de-DE')
    Assert-Localization 'Persisted German selection records user choice' ([string]$persisted.localePreferenceSource -eq 'user')

    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    Load-AppSettings
    Assert-Localization 'Load-AppSettings restores persisted de-DE' ((Get-ActiveLocale) -eq 'de-DE')
    Assert-Localization 'Reload preserves explicit user preference metadata' ([string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'Central German lookup works after reload' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Abbrechen')

    $selected = Set-ActiveLocale -Locale 'fr-FR' -Persist
    Assert-Localization 'Invalid locale selection fails safely to en-US' ($selected -eq 'en-US')
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Invalid locale persists normalized en-US' ([string]$persisted.locale -eq 'en-US' -and [string]$persisted.localePreferenceSource -eq 'user')

    $legacy = [ordered]@{
        schemaVersion = 4
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = [ordered]@{}
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $legacy
    $script:UiLocale = 'de-DE'
    $script:LocalePreferenceSource = 'user'
    $script:LocalePreferenceNeedsConfirmation = $true
    Load-AppSettings
    Assert-Localization 'Pre-localization schema migrates to en-US' ((Get-ActiveLocale) -eq 'en-US')
    Assert-Localization 'Pre-localization migration uses default preference without confirmation' ([string]$script:LocalePreferenceSource -eq 'default' -and -not $script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'Startup recovery uses en-US for pre-localization settings' ((Get-StartupRecoveryLocale) -eq 'en-US')

    Remove-Item -LiteralPath $script:SettingsPath -Force
    $fresh = Get-AppSettings
    Assert-Localization 'Missing settings file remains a new en-US installation' ([string]$fresh.locale -eq 'en-US')

    $v0800German = [ordered]@{
        schemaVersion = 5
        locale = 'de-DE'
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = [ordered]@{}
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $v0800German
    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    $script:LocalePreferenceNeedsConfirmation = $false
    Load-AppSettings
    Assert-Localization 'v0.8.0.0 migrated German remains de-DE until resolved' ((Get-ActiveLocale) -eq 'de-DE')
    Assert-Localization 'v0.8.0.0 migrated German requires confirmation' ($script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'v0.8.0.0 migrated German is marked migration-pending' ([string]$script:LocalePreferenceSource -eq 'migration-pending')
    Assert-Localization 'Startup recovery preserves ambiguous de-DE until explicit choice' ((Get-StartupRecoveryLocale) -eq 'de-DE')

    Save-AppSettings
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Unresolved migration persists schema 6 migration-pending state' ([int]$persisted.schemaVersion -eq 6 -and [string]$persisted.localePreferenceSource -eq 'migration-pending')
    $script:LocalePreferenceNeedsConfirmation = $false
    Load-AppSettings
    Assert-Localization 'Reload preserves unresolved migration confirmation' ($script:LocalePreferenceNeedsConfirmation)

    $selected = Set-ActiveLocale -Locale 'de-DE' -Persist
    Assert-Localization 'Explicit German confirmation persists user choice' ($selected -eq 'de-DE' -and [string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)
    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Explicit German confirmation survives reload' ((Get-ActiveLocale) -eq 'de-DE' -and -not $script:LocalePreferenceNeedsConfirmation)

    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $v0800German
    Load-AppSettings
    $selected = Set-ActiveLocale -Locale 'en-US' -Persist
    Assert-Localization 'v0.8.0.0 migrated German can be corrected to English once' ($selected -eq 'en-US' -and [string]$script:LocalePreferenceSource -eq 'user')
    $script:UiLocale = 'de-DE'
    $script:LocalePreferenceNeedsConfirmation = $true
    Load-AppSettings
    Assert-Localization 'English correction survives reload without another prompt' ((Get-ActiveLocale) -eq 'en-US' -and -not $script:LocalePreferenceNeedsConfirmation)

    [void](Set-ActiveLocale -Locale 'de-DE' -Persist)
    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Later explicit German choice survives reload' ((Get-ActiveLocale) -eq 'de-DE' -and [string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)

    Assert-Localization 'English and German catalogs have identical key sets' (Test-LocalizationCatalogParityCore)
    Assert-Localization 'Named localization formatting is deterministic' ((Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale 'en-US' -Values @{ Model='TEST' }) -eq 'Internal SSD: TEST')
}
finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    try { if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force } } catch { }
}

Write-Host "LOCALIZATION TOTAL $checks/32"
if ($checks -ne 32) { throw "Expected 32 localization checks, got $checks" }
