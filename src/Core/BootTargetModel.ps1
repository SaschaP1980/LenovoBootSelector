# Lenovo Boot Selector v0.4.1 - Functional Core: friendly boot-target model
# Presentation-neutral: returns an AccentRole token instead of a UI-specific color object.

function Get-FriendlyBootEntryCore {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext,
        [string]$Locale = 'en-US'
    )

    $localeId = Resolve-LocaleIdCore -Locale $Locale
    $description = if ($RawDescription) { $RawDescription.Trim() } else { Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId }
    $title = $description
    $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId
    $accentRole = 'Secondary'
    $symbol = '●'
    $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherTargetTooltip' -Locale $localeId

    # The current target ThinkPad has NVMe0 confirmed as the populated internal slot.
    # A single read-only NVMe disk can therefore enrich NVMe0 and implies an empty NVMe1.
    # Do not guess NVMe0/NVMe1 physical mapping when multiple NVMe disks are present.
    $nvmeDisks = @()
    if ($StorageContext -and $null -ne $StorageContext.Disks) {
        $nvmeDisks = @($StorageContext.Disks | Where-Object { [string]$_.BusType -eq 'NVMe' })
    }

    switch -Regex ($description) {
        '^Boot Menu$' {
            $title = Get-LocalizedStringCore -Key 'Boot.MenuTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.MenuSubtitle' -Locale $localeId
            $accentRole = 'Accent'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.MenuTooltip' -Locale $localeId
            break
        }
        '^NVMe0$' {
            $title = Get-LocalizedStringCore -Key 'Boot.Nvme1Title' -Locale $localeId
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale $localeId -Values @{ Model=[string]$nvmeDisks[0].Model }
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.InternalSsd' -Locale $localeId
            }
            $accentRole = 'Blue'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.InternalSsdTooltip' -Locale $localeId
            break
        }
        '^NVMe1$' {
            $title = Get-LocalizedStringCore -Key 'Boot.Nvme2Title' -Locale $localeId
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.NoDrive' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.SecondInternalSsd' -Locale $localeId
            }
            $accentRole = 'Blue'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.InternalSsdTooltip' -Locale $localeId
            break
        }
        '^USB HDD$' {
            # USB HDD is the actual firmware target. Physical storage identity is
            # presented only as read-only context and must never replace the target title.
            $title = 'USB HDD'
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId

            if (-not $StorageContext) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbChecking' -Locale $localeId
            }
            elseif ($StorageContext.UsbResolution -eq 'Unavailable') {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCheckFailed' -Locale $localeId
            }
            elseif ($StorageContext.UsbBootCandidates.Count -eq 1) {
                $candidate = $StorageContext.UsbBootCandidates[0]
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbBootMedium' -Locale $localeId -Values @{ Model=[string]$candidate.Model }
            }
            elseif ($StorageContext.UsbBootCandidates.Count -gt 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbMultipleBoot' -Locale $localeId
            }
            elseif ($StorageContext.UsbDisks.Count -eq 1) {
                $medium = $StorageContext.UsbDisks[0]
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbNonBoot' -Locale $localeId -Values @{ Model=[string]$medium.Model }
            }
            elseif ($StorageContext.UsbDisks.Count -gt 1) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbMultipleNoBoot' -Locale $localeId
            }
            elseif ($StorageContext.UsbDisks.Count -eq 0) {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbNone' -Locale $localeId
            }
            else {
                $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCheckFailed' -Locale $localeId
            }
            break
        }
        '^USB FDD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.UsbFddTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbFddSubtitle' -Locale $localeId
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId
            break
        }
        '^USB CD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.UsbCdTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.UsbCdSubtitle' -Locale $localeId
            $accentRole = 'Warning'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.UsbTooltip' -Locale $localeId
            break
        }
        '^PXE BOOT$' {
            $title = Get-LocalizedStringCore -Key 'Boot.PxeTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.PxeSubtitle' -Locale $localeId
            $accentRole = 'Purple'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.PxeTooltip' -Locale $localeId
            break
        }
        '^LENOVO CLOUD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.LenovoRecoveryTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.LenovoRecoverySubtitle' -Locale $localeId
            $accentRole = 'Cyan'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.CyanTooltip' -Locale $localeId
            break
        }
        '^ON-PREMISE$' {
            $title = Get-LocalizedStringCore -Key 'Boot.CorporateTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.CorporateSubtitle' -Locale $localeId
            $accentRole = 'Cyan'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.CyanTooltip' -Locale $localeId
            break
        }
        '^Other HDD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.OtherDriveTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherDriveSubtitle' -Locale $localeId
            $accentRole = 'Secondary'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherDriveTooltip' -Locale $localeId
            break
        }
        '^Other CD$' {
            $title = Get-LocalizedStringCore -Key 'Boot.OtherCdTitle' -Locale $localeId
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherCdSubtitle' -Locale $localeId
            $accentRole = 'Secondary'
            $typeTooltip = Get-LocalizedStringCore -Key 'Boot.OtherTargetTooltip' -Locale $localeId
            break
        }
        default {
            # Preserve unknown firmware descriptions rather than inventing a meaning.
            $title = $description
            $subtitle = Get-LocalizedStringCore -Key 'Boot.OtherTarget' -Locale $localeId
            $accentRole = 'Secondary'
        }
    }

    return [pscustomobject]@{
        Guid = $Guid.ToLowerInvariant()
        Title = $title
        Subtitle = $subtitle
        RawDescription = $description
        AccentRole = $accentRole
        Symbol = $symbol
        TypeTooltip = $typeTooltip
        Resolution = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolution } else { $null }
        ResolutionReason = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolutionReason } else { $null }
    }
}
