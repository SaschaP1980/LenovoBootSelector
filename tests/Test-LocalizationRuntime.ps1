#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Infrastructure\SettingsRepository.ps1')
. (Join-Path $root 'src\Application\SettingsService.ps1')
. (Join-Path $root 'src\Application\LocalizationService.ps1')

$checks = 0
function Assert-Localization([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "LOCALIZATION FAIL: $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-LocalizationTest-' + [guid]::NewGuid().ToString('N'))
try {
    $script:SettingsDir = $tempRoot
    $script:SettingsPath = Join-Path $tempRoot 'settings.json'
    $script:EntryAliases = @{}
    $script:LegacyDefaultGuid = $null
    $script:DefaultGuid = $null
    $script:EntryOrder = @()
    $script:HiddenEntryGuids = @()
    $script:UiLocale = 'en-US'
    $script:LegacySessionRestoreRegistryPath = 'HKCU:\Software\LenovoBootSelector-Test-DoesNotExist'
    $script:LegacySessionRestoreValueName = 'Restore'

    $defaults = New-DefaultAppSettingsCore
    Assert-Localization 'Brand-new settings default to en-US' ([string]$defaults.locale -eq 'en-US')
    Assert-Localization 'Active locale starts as en-US' ((Get-ActiveLocale) -eq 'en-US')
    Assert-Localization 'Central English lookup works' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Cancel')

    $selected = Set-ActiveLocale -Locale 'de-DE' -Persist
    Assert-Localization 'German selection resolves to de-DE' ($selected -eq 'de-DE')
    Assert-Localization 'Language selection writes settings file' (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Persisted settings use schema 5 and de-DE' ([int]$persisted.schemaVersion -eq 5 -and [string]$persisted.locale -eq 'de-DE')

    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Load-AppSettings restores persisted de-DE' ((Get-ActiveLocale) -eq 'de-DE')
    Assert-Localization 'Central German lookup works after reload' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Abbrechen')

    $selected = Set-ActiveLocale -Locale 'fr-FR' -Persist
    Assert-Localization 'Invalid locale selection fails safely to en-US' ($selected -eq 'en-US')
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Invalid locale persists normalized en-US' ([string]$persisted.locale -eq 'en-US')

    $legacy = [ordered]@{
        schemaVersion = 4
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = [ordered]@{}
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $legacy
    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Pre-localization schema migrates to de-DE in memory' ((Get-ActiveLocale) -eq 'de-DE')

    Remove-Item -LiteralPath $script:SettingsPath -Force
    $fresh = Get-AppSettings
    Assert-Localization 'Missing settings file remains a new en-US installation' ([string]$fresh.locale -eq 'en-US')
    Assert-Localization 'English and German catalogs have identical key sets' (Test-LocalizationCatalogParityCore)
    Assert-Localization 'Named localization formatting is deterministic' ((Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale 'en-US' -Values @{ Model='TEST' }) -eq 'Internal SSD: TEST')
}
finally {
    try { if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force } } catch { }
}

Write-Host "LOCALIZATION TOTAL $checks/14"
if ($checks -ne 14) { throw "Expected 14 localization checks, got $checks" }
