#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Core\FirmwareParsing.ps1')
. (Join-Path $root 'src\Core\BootTargetModel.ps1')

$script:Pass = 0
function Assert-Equal($Expected, $Actual, [string]$Name) {
    if ($Expected -is [array] -or $Actual -is [array]) {
        $e = @($Expected); $a = @($Actual)
        if ($e.Count -ne $a.Count) { throw "${Name}: count $($a.Count) != $($e.Count)" }
        for ($i=0; $i -lt $e.Count; $i++) {
            if ([string]$e[$i] -ne [string]$a[$i]) { throw "${Name}: index $i '$($a[$i])' != '$($e[$i])'" }
        }
    }
    elseif ($Expected -ne $Actual) { throw "${Name}: '$Actual' != '$Expected'" }
    $script:Pass++
    Write-Host "PASS  $Name"
}

Assert-Equal @('en-US','de-DE') @(Get-SupportedLocaleIdsCore) 'Localization supported locales'
Assert-Equal 'en-US' (Resolve-LocaleIdCore -Locale $null) 'Localization default locale is English'
Assert-Equal 'de-DE' (Resolve-LocaleIdCore -Locale 'de-de') 'Localization locale matching is case-insensitive'
Assert-Equal 'en-US' (Resolve-LocaleIdCore -Locale 'fr-FR') 'Localization unknown locale falls back to English'
Assert-Equal $true (Test-LocalizationCatalogParityCore) 'Localization catalogs have identical key sets'
Assert-Equal 'Cancel' (Get-LocalizedStringCore -Key 'Common.Cancel' -Locale 'en-US') 'Localization English lookup'
Assert-Equal 'Abbrechen' (Get-LocalizedStringCore -Key 'Common.Cancel' -Locale 'de-DE') 'Localization German lookup'
Assert-Equal 'Cancel' (Get-LocalizedStringCore -Key 'Common.Cancel' -Locale 'invalid') 'Localization invalid locale lookup falls back to English'
Assert-Equal 'Unknown.Key' (Get-LocalizedStringCore -Key 'Unknown.Key' -Locale 'de-DE') 'Localization unknown key is deterministic'
Assert-Equal 'Step 2 of 5' (Get-LocalizedStringCore -Key 'Progress.StepOf' -Locale 'en-US' -Arguments @(2,5)) 'Localization positional formatting'
Assert-Equal 'Interne SSD: KXG8AZNV2T04 LA KIOXIA' (Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale 'de-DE' -Values @{ Model='KXG8AZNV2T04 LA KIOXIA' }) 'Localization named formatting'

$g1 = '{ABCDEF12-3456-7890-ABCD-EF1234567890}'
$g2 = '{11111111-2222-3333-4444-555555555555}'
Assert-Equal $g1.ToLowerInvariant() (Parse-GuidFromLine "identifier              $g1") 'GUID parser normalizes lowercase'
Assert-Equal $null (Parse-GuidFromLine 'identifier              {not-a-guid}') 'GUID parser rejects invalid GUID'

$firmware = @"
Firmware Application (101fffff)
-------------------------------
identifier              $g1
description             Boot Menu

Firmwareanwendung (101fffff)
----------------------------
Bezeichner               $g2
Beschreibung             USB HDD
"@
$desc = ConvertFrom-FirmwareEntriesText $firmware
Assert-Equal 'Boot Menu' $desc[$g1.ToLowerInvariant()] 'Firmware parser English description'
Assert-Equal 'USB HDD' $desc[$g2.ToLowerInvariant()] 'Firmware parser German description'

$manager = @"
displayorder            $g1
                        $g2
bootsequence            $g2
"@
$mgr = ConvertFrom-FirmwareManagerText $manager
Assert-Equal @($g1.ToLowerInvariant(),$g2.ToLowerInvariant()) @($mgr.DisplayOrder) 'Manager parser display order'
Assert-Equal $g2.ToLowerInvariant() $mgr.SelectedGuid 'Manager parser bootsequence'

$defaults = New-DefaultAppSettingsCore
Assert-Equal 6 $defaults.schemaVersion 'Default settings schema'
Assert-Equal 'en-US' $defaults.locale 'New settings default to English'
Assert-Equal 'default' $defaults.localePreferenceSource 'New settings record default locale source'
Assert-Equal $false $defaults.localePreferenceNeedsConfirmation 'New settings need no locale confirmation'
Assert-Equal 0 @($defaults.entryOrder).Count 'Default settings empty order'
Assert-Equal 0 @($defaults.hiddenEntryGuids).Count 'Default settings empty hidden list'

$source = [pscustomobject]@{
    schemaVersion = 4
    defaultGuid = $g1.ToUpperInvariant()
    entryOrder = @($g2.ToUpperInvariant(),$g2.ToLowerInvariant(),$g1.ToUpperInvariant())
    hiddenEntryGuids = @($g1.ToUpperInvariant(),$g1.ToLowerInvariant())
    entryAliases = [pscustomobject]@{ ($g1.ToUpperInvariant()) = '  Test Alias  ' }
}
$norm = ConvertTo-NormalizedAppSettingsCore $source
Assert-Equal 6 $norm.schemaVersion 'Legacy settings normalize to current schema'
Assert-Equal 'en-US' $norm.locale 'Legacy pre-localization settings migrate to English'
Assert-Equal 'default' $norm.localePreferenceSource 'Legacy migration records default locale source'
Assert-Equal $false $norm.localePreferenceNeedsConfirmation 'Legacy pre-localization settings need no confirmation'
Assert-Equal $g1.ToLowerInvariant() $norm.defaultGuid 'Settings default GUID normalization'
Assert-Equal @($g2.ToLowerInvariant(),$g1.ToLowerInvariant()) @($norm.entryOrder) 'Settings order lowercase unique'
Assert-Equal @($g1.ToLowerInvariant()) @($norm.hiddenEntryGuids) 'Settings hidden lowercase unique'
Assert-Equal 'Test Alias' $norm.entryAliases[$g1.ToLowerInvariant()] 'Alias trim and lowercase key'

$currentEnglish = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=5; locale='en-US' })
Assert-Equal 'en-US' $currentEnglish.locale 'Schema-5 English remains English'
Assert-Equal 'default' $currentEnglish.localePreferenceSource 'Schema-5 English has default preference source'
Assert-Equal $false $currentEnglish.localePreferenceNeedsConfirmation 'Schema-5 English needs no confirmation'

$ambiguousGerman = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=5; locale='de-de' })
Assert-Equal 'de-DE' $ambiguousGerman.locale 'Schema-5 German remains German until ambiguity is resolved'
Assert-Equal 'migration-pending' $ambiguousGerman.localePreferenceSource 'Schema-5 German is marked migration-pending'
Assert-Equal $true $ambiguousGerman.localePreferenceNeedsConfirmation 'Schema-5 German requires one explicit choice'

$explicitGerman = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=6; locale='de-de'; localePreferenceSource='user' })
Assert-Equal 'de-DE' $explicitGerman.locale 'Explicit German user preference normalizes and persists'
Assert-Equal 'user' $explicitGerman.localePreferenceSource 'Explicit German user preference retains user source'
Assert-Equal $false $explicitGerman.localePreferenceNeedsConfirmation 'Explicit German user preference needs no confirmation'

$currentInvalid = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=5; locale='fr-FR' })
Assert-Equal 'en-US' $currentInvalid.locale 'Invalid stored locale falls back to English'
Assert-Equal 'default' $currentInvalid.localePreferenceSource 'Invalid stored locale has no explicit user evidence'
$currentMissing = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=5 })
Assert-Equal 'en-US' $currentMissing.locale 'Current settings without locale fall back to English'
$currentDefaultGerman = ConvertTo-NormalizedAppSettingsCore ([pscustomobject]@{ schemaVersion=6; locale='de-DE'; localePreferenceSource='default' })
Assert-Equal 'en-US' $currentDefaultGerman.locale 'German is not retained without explicit user evidence'

$entries = @(
    [pscustomobject]@{ Guid=$g1.ToLowerInvariant(); Title='One' },
    [pscustomobject]@{ Guid=$g2.ToLowerInvariant(); Title='Two' }
)
$ordered = @(Get-OrderedEntriesCore -Source $entries -Order @($g2,$g1) -Hidden @($g1))
Assert-Equal @($g2.ToLowerInvariant()) @($ordered | ForEach-Object Guid) 'Entry ordering excludes hidden'
$orderedAll = @(Get-OrderedEntriesCore -Source $entries -Order @($g2,$g1) -Hidden @($g1) -IncludeHidden)
Assert-Equal @($g2.ToLowerInvariant(),$g1.ToLowerInvariant()) @($orderedAll | ForEach-Object Guid) 'Entry ordering includes hidden when requested'

$bootMenu = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'Boot Menu' -StorageContext $null -Locale 'de-DE'
Assert-Equal 'Lenovo Boot-Menü' $bootMenu.Title 'Friendly model Boot Menu title'
Assert-Equal 'Accent' $bootMenu.AccentRole 'Friendly model Boot Menu accent role'
$nvme = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe0' -StorageContext $null -Locale 'de-DE'
Assert-Equal 'NVMe-SSD 1' $nvme.Title 'Friendly model NVMe title'
Assert-Equal 'Blue' $nvme.AccentRole 'Friendly model NVMe accent role'
$singleNvmeDisk = [pscustomobject]@{ Model='KXG8AZNV2T04 LA KIOXIA'; BusType='NVMe' }
$singleNvmeStorage = [pscustomobject]@{ Disks=@($singleNvmeDisk); UsbResolution='None'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@() }
$nvme0Resolved = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe0' -StorageContext $singleNvmeStorage -Locale 'de-DE'
Assert-Equal 'Interne SSD: KXG8AZNV2T04 LA KIOXIA' $nvme0Resolved.Subtitle 'Friendly NVMe0 single internal model'
$nvme1Empty = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe1' -StorageContext $singleNvmeStorage -Locale 'de-DE'
Assert-Equal 'Kein Laufwerk erkannt' $nvme1Empty.Subtitle 'Friendly NVMe1 empty slot with one confirmed internal NVMe'
$twoNvmeStorage = [pscustomobject]@{ Disks=@([pscustomobject]@{Model='A';BusType='NVMe'},[pscustomobject]@{Model='B';BusType='NVMe'}); UsbResolution='None'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@() }
$nvme0Ambiguous = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe0' -StorageContext $twoNvmeStorage -Locale 'de-DE'
Assert-Equal 'Interne SSD' $nvme0Ambiguous.Subtitle 'Friendly NVMe0 does not guess multi-NVMe mapping'
$nvme1Ambiguous = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe1' -StorageContext $twoNvmeStorage -Locale 'de-DE'
Assert-Equal 'Zweite interne SSD' $nvme1Ambiguous.Subtitle 'Friendly NVMe1 does not guess multi-NVMe mapping'
$unknown = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'Vendor Custom Loader' -StorageContext $null -Locale 'de-DE'
Assert-Equal 'Vendor Custom Loader' $unknown.Title 'Friendly model preserves unknown description'
Assert-Equal 'Secondary' $unknown.AccentRole 'Friendly model unknown accent role'
$candidateDisk = [pscustomobject]@{Model='USB Test Disk'}
$storage = [pscustomobject]@{ ResolvedUsbHdd=$candidateDisk; UsbResolution='Candidate'; UsbResolutionReason='fixture'; UsbBootCandidates=@($candidateDisk); UsbDisks=@($candidateDisk) }
$usb = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storage -Locale 'de-DE'
Assert-Equal 'USB HDD' $usb.Title 'Friendly USB preserves firmware target title'
Assert-Equal 'USB-Startmedium: USB Test Disk' $usb.Subtitle 'Friendly USB boot medium is contextual subtext'
Assert-Equal 'Warning' $usb.AccentRole 'Friendly USB accent role'

$nonBootDisk = [pscustomobject]@{Model='USB Data Disk'}
$storageNonBoot = [pscustomobject]@{ ResolvedUsbHdd=$nonBootDisk; UsbResolution='Medium'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@($nonBootDisk) }
$usbNonBoot = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storageNonBoot -Locale 'de-DE'
Assert-Equal 'USB HDD' $usbNonBoot.Title 'Friendly USB non-boot media keeps firmware title'
Assert-Equal 'USB Data Disk erkannt · nicht als Startmedium erkannt' $usbNonBoot.Subtitle 'Friendly USB non-boot medium text'

$storageNone = [pscustomobject]@{ ResolvedUsbHdd=$null; UsbResolution='None'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@() }
$usbNone = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storageNone -Locale 'de-DE'
Assert-Equal 'Kein USB-Laufwerk angeschlossen' $usbNone.Subtitle 'Friendly USB no media text'

$storageMultiNoBoot = [pscustomobject]@{ ResolvedUsbHdd=$null; UsbResolution='Ambiguous'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@([pscustomobject]@{Model='A'},[pscustomobject]@{Model='B'}) }
$usbMultiNoBoot = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storageMultiNoBoot -Locale 'de-DE'
Assert-Equal 'USB-Laufwerke erkannt · kein Startmedium gefunden' $usbMultiNoBoot.Subtitle 'Friendly USB multiple non-boot media text'

$storageMultiBoot = [pscustomobject]@{ ResolvedUsbHdd=$null; UsbResolution='Ambiguous'; UsbResolutionReason='fixture'; UsbBootCandidates=@([pscustomobject]@{Model='A'},[pscustomobject]@{Model='B'}); UsbDisks=@([pscustomobject]@{Model='A'},[pscustomobject]@{Model='B'}) }
$usbMultiBoot = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storageMultiBoot -Locale 'de-DE'
Assert-Equal 'Mehrere mögliche USB-Startmedien erkannt' $usbMultiBoot.Subtitle 'Friendly USB multiple boot candidates text'

$usbPending = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $null -Locale 'de-DE'
Assert-Equal 'USB-Laufwerke werden geprüft …' $usbPending.Subtitle 'Friendly USB pending text'

$storageUnavailable = [pscustomobject]@{ ResolvedUsbHdd=$null; UsbResolution='Unavailable'; UsbResolutionReason='fixture'; UsbBootCandidates=@(); UsbDisks=@() }
$usbUnavailable = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storageUnavailable -Locale 'de-DE'
Assert-Equal 'USB-Laufwerke konnten nicht geprüft werden' $usbUnavailable.Subtitle 'Friendly USB unavailable text'

$bootMenuEnglish = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'Boot Menu' -StorageContext $null -Locale 'en-US'
Assert-Equal 'Lenovo Boot Menu' $bootMenuEnglish.Title 'Friendly model English Boot Menu title'
Assert-Equal 'Open the boot menu on the next startup' $bootMenuEnglish.Subtitle 'Friendly model English Boot Menu subtitle'
$nvmeEnglish = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'NVMe0' -StorageContext $singleNvmeStorage -Locale 'en-US'
Assert-Equal 'Internal SSD: KXG8AZNV2T04 LA KIOXIA' $nvmeEnglish.Subtitle 'Friendly model English NVMe storage text'
$usbEnglish = Get-FriendlyBootEntryCore -Guid $g2 -RawDescription 'USB HDD' -StorageContext $storage -Locale 'en-US'
Assert-Equal 'USB boot medium: USB Test Disk' $usbEnglish.Subtitle 'Friendly model English USB boot-medium text'
$unknownEnglish = Get-FriendlyBootEntryCore -Guid $g1 -RawDescription 'Vendor Custom Loader' -StorageContext $null -Locale 'en-US'
Assert-Equal 'Vendor Custom Loader' $unknownEnglish.Title 'Friendly model keeps external firmware description untranslated'

Write-Host "TOTAL $script:Pass/$script:Pass"
exit 0
