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
