#requires -version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach ($path in @('src\Core\Localization.ps1','src\Core\EntryPreferences.ps1','src\Core\PortablePreferences.ps1','src\Infrastructure\SettingsRepository.ps1','src\Infrastructure\PreferencesFileRepository.ps1','src\Application\SettingsService.ps1','src\Application\PortablePreferencesService.ps1')) { . (Join-Path $root $path) }
$script:passed=0
function Assert-True($Value,[string]$Name) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:passed++;Write-Host "PASS $Name"
}
function Test-MaintenanceBusy { return $false }
function Get-CurrentSystemFunctionsCapabilities { [pscustomobject]@{CanManageEntries=$true} }
function Test-BackgroundRefreshActive { param($State) return $false }
$dir=[IO.Path]::Combine([IO.Path]::GetTempPath(),'lbs180-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
try {
    $script:SettingsDir=Join-Path $dir 'settings'
    $script:SettingsPath=Join-Path $script:SettingsDir 'settings.json'
    $script:UiLocale='en-US';$script:LocalePreferenceSource='user';$script:LocalePreferenceNeedsConfirmation=$false
    $a='{aaaaaaaa-1111-1111-1111-111111111111}';$b='{bbbbbbbb-2222-2222-2222-222222222222}'
    $script:LegacyDefaultGuid='{cccccccc-3333-3333-3333-333333333333}'
    $script:DefaultGuid='{dddddddd-4444-4444-4444-444444444444}'
    $script:EntryOrder=@($a,$b);$script:HiddenEntryGuids=@($a);$script:EntryAliases=@{$a='Old'}
    $script:CurrentEntries=@([pscustomobject]@{Guid=$a;Title='A'},[pscustomobject]@{Guid=$b;Title='B'})
    $script:SettingsLoadState=$null
    Save-AppSettings
    $original=Read-PreferencesFileSnapshot $script:SettingsPath
    $context=Get-PortablePreferencesContext
    $export=Join-Path $dir 'export.json'
    Save-PortablePreferencesExport $export $context
    Assert-True ((Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Export no settings mutation'
    Assert-True ((ConvertFrom-PortablePreferencesCore (Read-PreferencesFileSnapshot $export).Text).entries.Count -eq 2) 'Valid portable export'
    Save-PortablePreferencesExport $export $context
    Assert-True ((Read-PreferencesFileSnapshot $export).Exists) 'Replace existing valid export'
    $unrelated=Join-Path $dir 'unrelated.json'
    [IO.File]::WriteAllText($unrelated,'{}')
    $denied=$false;try { Save-PortablePreferencesExport $unrelated $context } catch {$denied=$true}
    Assert-True ($denied -and [IO.File]::ReadAllText($unrelated) -ceq '{}') 'Unrelated file not overwritten'
    $denied=$false;try { Save-PortablePreferencesExport $script:SettingsPath $context } catch {$denied=$true}
    Assert-True ($denied -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Internal settings destination rejected'
    $importFile=Join-Path $dir 'import.json'
    $json='{"format":"LenovoBootSelector.Preferences","version":1,"locale":"de-DE","entries":[{"guid":"'+$b+'","alias":"Beta","hidden":true},{"guid":"'+$a+'","alias":"","hidden":false}]}'
    [IO.File]::WriteAllText($importFile,$json)
    $import=New-PortablePreferencesImport $importFile
    Assert-True ($import.Plan.Locale -ceq 'de-DE' -and $script:UiLocale -ceq 'en-US' -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Preview and cancel have no effects'
    $script:CurrentEntries[0].Title='Changed'
    $denied=$false;try { [void](Complete-PortablePreferencesImport $import) } catch {$denied=$true}
    Assert-True ($denied -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Changed local snapshot rejects stale preview'
    $script:CurrentEntries[0].Title='A'
    $import=New-PortablePreferencesImport $importFile
    $script:BootNextPendingGuid=$a
    $denied=$false;try { [void](Complete-PortablePreferencesImport $import) } catch {$denied=$true}
    $script:BootNextPendingGuid=$null
    Assert-True ($denied -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Pending action rejects commit'
    $handle=[IO.File]::Open($script:SettingsPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        $denied=$false;try { [void](Complete-PortablePreferencesImport $import) } catch {$denied=$true}
        Assert-True ($denied -and $script:UiLocale -ceq 'en-US' -and $script:EntryAliases[$a] -ceq 'Old') 'Locked settings failure preserves runtime'
    } finally {$handle.Dispose()}
    Assert-True ((Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $original.Token) 'Locked settings failure preserves disk'
    [void](Complete-PortablePreferencesImport $import)
    Assert-True ($script:UiLocale -ceq 'de-DE' -and ($script:EntryOrder -join ',') -eq (@($b,$a) -join ',') -and $script:EntryAliases[$b] -ceq 'Beta' -and -not $script:EntryAliases.ContainsKey($a)) 'Confirmed import publishes approved runtime fields'
    $saved=Get-AppSettingsLoadResult
    Assert-True ($saved.Status -eq 'Loaded' -and $saved.Settings.locale -ceq 'de-DE' -and $saved.Settings.defaultGuid -ceq $script:LegacyDefaultGuid -and $script:DefaultGuid -ceq '{dddddddd-4444-4444-4444-444444444444}') 'Disk matches runtime; legacy and live default unchanged'
    $roundtrip=New-PortablePreferencesImport $export
    [void](Complete-PortablePreferencesImport $roundtrip)
    Assert-True ($script:UiLocale -ceq 'en-US' -and $script:EntryAliases[$a] -ceq 'Old' -and -not $script:EntryAliases.ContainsKey($b) -and ($script:EntryOrder -join ',') -eq (@($a,$b) -join ',')) 'Export/import roundtrip'
    $import=New-PortablePreferencesImport $importFile
    [IO.File]::AppendAllText($script:SettingsPath,' ')
    $changed=Read-PreferencesFileSnapshot $script:SettingsPath
    $denied=$false;try { [void](Complete-PortablePreferencesImport $import) } catch {$denied=$true}
    Assert-True ($denied -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $changed.Token) 'Byte-level stale settings detected'
    [IO.File]::WriteAllText($script:SettingsPath,'{broken')
    $bad=Read-PreferencesFileSnapshot $script:SettingsPath
    $denied=$false;try { [void](New-PortablePreferencesImport $importFile) } catch {$denied=$true}
    Assert-True ($denied -and (Read-PreferencesFileSnapshot $script:SettingsPath).Token -ceq $bad.Token) 'Damaged local settings not replaced'
    [IO.File]::WriteAllBytes($importFile,[byte[]]@(255,255))
    $denied=$false;try { [void](New-PortablePreferencesImport $importFile) } catch {$denied=$true}
    Assert-True $denied 'Invalid UTF-8 rejected'
    [IO.File]::WriteAllBytes($importFile,[byte[]]::new(262145))
    $denied=$false;try { [void](Read-PreferencesFileSnapshot $importFile) } catch {$denied=$true}
    Assert-True $denied 'Bounded file read rejects oversized file'
    Write-Host "LBS180 TRANSACTION TOTAL $script:passed/17"
    if ($script:passed -ne 17) { exit 1 }
} finally { [IO.Directory]::Delete($dir,$true) }
