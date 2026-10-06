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
            'Settings.Language' = 'Language'
            'Language.English' = 'English'
            'Language.German' = 'Deutsch'
            'Progress.StepOf' = 'Step {0} of {1}'
            'Storage.InternalSsdModel' = 'Internal SSD: {Model}'
        }
        'de-DE' = [ordered]@{
            'Common.OK' = 'OK'
            'Common.Cancel' = 'Abbrechen'
            'Common.Close' = 'Schließen'
            'Settings.Language' = 'Sprache'
            'Language.English' = 'English'
            'Language.German' = 'Deutsch'
            'Progress.StepOf' = 'Schritt {0} von {1}'
            'Storage.InternalSsdModel' = 'Interne SSD: {Model}'
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
