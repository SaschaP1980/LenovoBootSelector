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
