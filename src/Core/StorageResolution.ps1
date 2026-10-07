# Lenovo Boot Selector - pure storage-resolution model.
# No Windows storage cmdlets or hardware IO belong in this module.

function Resolve-PartitionBootStructureCore {
    param(
        [Parameter(Mandatory=$true)]$Disk,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Partitions
    )

    $hasEfiSystemPartition = $false
    $hasActiveFatPartition = $false

    foreach ($partition in @($Partitions)) {
        $gptType = ([string]$partition.GptType).Trim().Trim([char[]]'{}').ToLowerInvariant()
        if ($gptType -eq 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b') {
            $hasEfiSystemPartition = $true
        }

        if (([string]$Disk.PartitionStyle -eq 'MBR') -and ($partition.IsActive -eq $true)) {
            $partitionType = [string]$partition.Type
            $mbrType = [string]$partition.MbrType
            if (($partitionType -match '(?i)FAT32') -or ($mbrType -eq '11') -or ($mbrType -eq '12')) {
                $hasActiveFatPartition = $true
            }
        }
    }

    return [pscustomobject]@{
        HasEfiSystemPartition = $hasEfiSystemPartition
        HasActiveFatPartition = $hasActiveFatPartition
        HasBootStructure = ($hasEfiSystemPartition -or $hasActiveFatPartition)
    }
}

function Resolve-StorageContextCore {
    param($Snapshot)

    if (-not $Snapshot -or $Snapshot.Available -ne $true) {
        return [pscustomobject]@{
            Disks = @()
            UsbDisks = @()
            UsbBootCandidates = @()
            ResolvedUsbHdd = $null
            UsbResolution = 'Unavailable'
            UsbResolutionReason = 'Speichergeräte konnten nicht gelesen werden.'
        }
    }

    $inventory = @()
    foreach ($disk in @($Snapshot.Disks)) {
        $partitions = @($disk.Partitions)
        $bootStructure = Resolve-PartitionBootStructureCore -Disk $disk -Partitions $partitions

        $model = ([string]$disk.Model).Trim()
        if (-not $model) { $model = "Datenträger $($disk.Number)" }

        $inventory += [pscustomobject]@{
            Number = $disk.Number
            Model = $model
            SerialNumber = ([string]$disk.SerialNumber).Trim()
            BusType = [string]$disk.BusType
            PartitionStyle = [string]$disk.PartitionStyle
            Path = [string]$disk.Path
            IsBootCandidate = [bool]$bootStructure.HasBootStructure
            HasEfiSystemPartition = [bool]$bootStructure.HasEfiSystemPartition
            HasActiveFatPartition = [bool]$bootStructure.HasActiveFatPartition
            PnpInstanceId = $null
            PnpParent = $null
            PnpLocationPaths = @()
        }
    }

    $usbDisks = @($inventory | Where-Object { $_.BusType -eq 'USB' })
    $usbBootCandidates = @($usbDisks | Where-Object { $_.IsBootCandidate })
    $resolvedUsbHdd = $null
    $resolution = 'Ambiguous'
    $reason = 'Mehrere mögliche USB-Laufwerke erkannt.'

    if ($usbBootCandidates.Count -eq 1) {
        $resolvedUsbHdd = $usbBootCandidates[0]
        $resolution = 'Candidate'
        $reason = 'Genau ein aktuelles USB-Laufwerk besitzt eine erkannte Bootstruktur. Der Lenovo-Eintrag USB HDD ist jedoch generisch; die physische Zuordnung wird erst durch den Boottest bestätigt.'
    }
    elseif ($usbBootCandidates.Count -gt 1) {
        $resolution = 'Ambiguous'
        $reason = "$($usbBootCandidates.Count) USB-Laufwerke besitzen eine erkannte Bootstruktur."
    }
    elseif ($usbDisks.Count -eq 1) {
        $resolvedUsbHdd = $usbDisks[0]
        $resolution = 'Medium'
        $reason = 'Nur ein aktuelles USB-Laufwerk ist angeschlossen; eine Bootstruktur konnte jedoch nicht bestätigt werden.'
    }
    elseif ($usbDisks.Count -eq 0) {
        $resolution = 'None'
        $reason = 'Kein aktuelles USB-Speicherlaufwerk erkannt.'
    }

    return [pscustomobject]@{
        Disks = @($inventory)
        UsbDisks = @($usbDisks)
        UsbBootCandidates = @($usbBootCandidates)
        ResolvedUsbHdd = $resolvedUsbHdd
        UsbResolution = $resolution
        UsbResolutionReason = $reason
    }
}
