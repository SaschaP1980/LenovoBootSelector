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
