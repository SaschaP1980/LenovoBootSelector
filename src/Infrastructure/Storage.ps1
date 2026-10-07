# Windows-specific storage acquisition and normalization.
# Classification and product-facing storage resolution live in Core/StorageResolution.ps1.

function ConvertTo-WindowsStorageDiskSnapshot {
    param(
        [Parameter(Mandatory=$true)]$Disk,
        [Parameter(Mandatory=$true)][object[]]$Partitions
    )

    $normalizedPartitions = @(
        foreach ($partition in @($Partitions)) {
            [pscustomobject]@{
                GptType = [string]$partition.GptType
                IsActive = [bool]$partition.IsActive
                Type = [string]$partition.Type
                MbrType = [string]$partition.MbrType
            }
        }
    )

    return [pscustomobject]@{
        Number = $Disk.Number
        Model = ([string]$Disk.FriendlyName).Trim()
        SerialNumber = ([string]$Disk.SerialNumber).Trim()
        BusType = [string]$Disk.BusType
        PartitionStyle = [string]$Disk.PartitionStyle
        Path = [string]$Disk.Path
        Partitions = @($normalizedPartitions)
    }
}

function Get-WindowsStorageSnapshot {
    # Performance-critical Windows IO path. PnP enrichment remains intentionally
    # excluded from interactive refresh; only Get-Disk/Get-Partition are queried.
    try {
        $disks = @(Get-Disk -ErrorAction Stop)
    }
    catch {
        return [pscustomobject]@{
            Available = $false
            Disks = @()
        }
    }

    $inventory = @()
    foreach ($disk in $disks) {
        $partitions = @()
        try {
            $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction Stop)
        }
        catch { }

        $inventory += ConvertTo-WindowsStorageDiskSnapshot -Disk $disk -Partitions $partitions
    }

    return [pscustomobject]@{
        Available = $true
        Disks = @($inventory)
    }
}

function Get-StorageContext {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $snapshot = Get-WindowsStorageSnapshot
        $result = Resolve-StorageContextCore -Snapshot $snapshot
        $sw.Stop()
        $storageSuccess = ([string]$result.UsbResolution -ne 'Unavailable')
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $storageSuccess -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            diskCount = @($result.Disks).Count
            usbDiskCount = @($result.UsbDisks).Count
            usbBootCandidateCount = @($result.UsbBootCandidates).Count
            resolution = [string]$result.UsbResolution
        }) -Level $(if ($storageSuccess) { 'info' } else { 'warning' })
        return $result
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Level error
        throw
    }
}
