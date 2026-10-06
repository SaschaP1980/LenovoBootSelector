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
