# Lenovo Boot Selector v0.4.1 - Functional Core: friendly boot-target model
# Presentation-neutral: returns an AccentRole token instead of a UI-specific color object.

function Get-FriendlyBootEntryCore {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext
    )

    $description = if ($RawDescription) { $RawDescription.Trim() } else { 'Weiteres Startziel' }
    $title = $description
    $subtitle = 'Weiteres Startziel'
    $accentRole = 'Secondary'
    $symbol = '●'
    $typeTooltip = 'Grau: weiteres Startziel'

    # The current target ThinkPad has NVMe0 confirmed as the populated internal slot.
    # A single read-only NVMe disk can therefore enrich NVMe0 and implies an empty NVMe1.
    # Do not guess NVMe0/NVMe1 physical mapping when multiple NVMe disks are present.
    $nvmeDisks = @()
    if ($StorageContext -and $null -ne $StorageContext.Disks) {
        $nvmeDisks = @($StorageContext.Disks | Where-Object { [string]$_.BusType -eq 'NVMe' })
    }

    switch -Regex ($description) {
        '^Boot Menu$' {
            $title = 'Lenovo Boot-Menü'
            $subtitle = 'Beim nächsten Start das Boot-Menü öffnen'
            $accentRole = 'Accent'
            $typeTooltip = 'Rot: Lenovo Boot-Menü'
            break
        }
        '^NVMe0$' {
            $title = 'NVMe-SSD 1'
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = 'Interne SSD: ' + [string]$nvmeDisks[0].Model
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            else {
                $subtitle = 'Interne SSD'
            }
            $accentRole = 'Blue'
            $typeTooltip = 'Blau: interne SSD'
            break
        }
        '^NVMe1$' {
            $title = 'NVMe-SSD 2'
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            else {
                $subtitle = 'Zweite interne SSD'
            }
            $accentRole = 'Blue'
            $typeTooltip = 'Blau: interne SSD'
            break
        }
        '^USB HDD$' {
            # USB HDD is the actual firmware target. Physical storage identity is
            # presented only as read-only context and must never replace the target title.
            $title = 'USB HDD'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'

            if (-not $StorageContext) {
                $subtitle = 'USB-Laufwerke werden geprüft …'
            }
            elseif ($StorageContext.UsbResolution -eq 'Unavailable') {
                $subtitle = 'USB-Laufwerke konnten nicht geprüft werden'
            }
            elseif ($StorageContext.UsbBootCandidates.Count -eq 1) {
                $candidate = $StorageContext.UsbBootCandidates[0]
                $subtitle = 'USB-Startmedium: ' + [string]$candidate.Model
            }
            elseif ($StorageContext.UsbBootCandidates.Count -gt 1) {
                $subtitle = 'Mehrere mögliche USB-Startmedien erkannt'
            }
            elseif ($StorageContext.UsbDisks.Count -eq 1) {
                $medium = $StorageContext.UsbDisks[0]
                $subtitle = ([string]$medium.Model) + ' erkannt · nicht als Startmedium erkannt'
            }
            elseif ($StorageContext.UsbDisks.Count -gt 1) {
                $subtitle = 'USB-Laufwerke erkannt · kein Startmedium gefunden'
            }
            elseif ($StorageContext.UsbDisks.Count -eq 0) {
                $subtitle = 'Kein USB-Laufwerk angeschlossen'
            }
            else {
                $subtitle = 'USB-Laufwerke konnten nicht geprüft werden'
            }
            break
        }
        '^USB FDD$' {
            $title = 'USB-Diskettenlaufwerk'
            $subtitle = 'Start von einem USB-Floppy-Laufwerk'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'
            break
        }
        '^USB CD$' {
            $title = 'USB-CD/DVD-Laufwerk'
            $subtitle = 'Start von einem optischen USB-Laufwerk'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'
            break
        }
        '^PXE BOOT$' {
            $title = 'Netzwerkstart'
            $subtitle = 'Start über das lokale Netzwerk'
            $accentRole = 'Purple'
            $typeTooltip = 'Violett: Netzwerkstart'
            break
        }
        '^LENOVO CLOUD$' {
            $title = 'Lenovo Wiederherstellung'
            $subtitle = 'Wiederherstellung über das Netzwerk'
            $accentRole = 'Cyan'
            $typeTooltip = 'Cyan: Lenovo- oder Firmen-Netzwerk'
            break
        }
        '^ON-PREMISE$' {
            $title = 'Firmen-Netzwerkstart'
            $subtitle = 'Start über das Firmennetzwerk'
            $accentRole = 'Cyan'
            $typeTooltip = 'Cyan: Lenovo- oder Firmen-Netzwerk'
            break
        }
        '^Other HDD$' {
            $title = 'Weiteres Laufwerk'
            $subtitle = 'Weiteres erkanntes Laufwerk'
            $accentRole = 'Secondary'
            $typeTooltip = 'Grau: weiteres Laufwerk'
            break
        }
        '^Other CD$' {
            $title = 'Weiteres CD/DVD-Laufwerk'
            $subtitle = 'Anderes optisches Startlaufwerk'
            $accentRole = 'Secondary'
            $typeTooltip = 'Grau: weiteres Startziel'
            break
        }
        default {
            # Preserve unknown firmware descriptions rather than inventing a meaning.
            $title = $description
            $subtitle = 'Weiteres Startziel'
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
