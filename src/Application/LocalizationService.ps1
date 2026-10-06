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

    if ($Persist -and $changed) {
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
