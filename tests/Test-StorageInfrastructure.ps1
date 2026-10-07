#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Core\StorageResolution.ps1')
. (Join-Path $root 'src\Infrastructure\Storage.ps1')

$checks = 0
function Assert-Equal($Expected,$Actual,[string]$Name) {
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$disk = [pscustomobject]@{
    Number = 7
    FriendlyName = '  USB Fixture  '
    SerialNumber = '  SERIAL-7  '
    BusType = 'USB'
    PartitionStyle = 'GPT'
    Path = '\\?\fixture-disk-7'
}
$partition = [pscustomobject]@{
    GptType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    IsActive = $false
    Type = 'Basic'
    MbrType = ''
}
$normalized = ConvertTo-WindowsStorageDiskSnapshot -Disk $disk -Partitions @($partition)
Assert-Equal 7 $normalized.Number 'Storage infrastructure preserves disk number'
Assert-Equal 'USB Fixture' $normalized.Model 'Storage infrastructure trims Windows FriendlyName'
Assert-Equal 'SERIAL-7' $normalized.SerialNumber 'Storage infrastructure trims serial number'
Assert-Equal 'USB' $normalized.BusType 'Storage infrastructure preserves bus type'
Assert-Equal 'GPT' $normalized.PartitionStyle 'Storage infrastructure preserves partition style'
Assert-Equal '\\?\fixture-disk-7' $normalized.Path 'Storage infrastructure preserves disk path'
Assert-Equal 1 @($normalized.Partitions).Count 'Storage infrastructure normalizes partition collection'
Assert-Equal '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' $normalized.Partitions[0].GptType 'Storage infrastructure preserves GPT type'
Assert-Equal $false $normalized.Partitions[0].IsActive 'Storage infrastructure preserves inactive partition state'
Assert-Equal '' $normalized.Partitions[0].MbrType 'Storage infrastructure preserves empty MBR type'

$blankModelDisk = [pscustomobject]@{
    Number = 8; FriendlyName = '  '; SerialNumber = ''; BusType = 'NVMe'; PartitionStyle = 'GPT'; Path = 'disk-8'
}
$blankModel = ConvertTo-WindowsStorageDiskSnapshot -Disk $blankModelDisk -Partitions @()
Assert-Equal '' $blankModel.Model 'Storage infrastructure does not inject presentation fallback names'

$script:StorageTestThrowDisk = $false
$script:StorageTestDisks = @($disk,$blankModelDisk)
$script:StorageTestPartitions = @{ 7 = @($partition) }
function Get-Disk {
    [CmdletBinding()]
    param()
    if ($script:StorageTestThrowDisk) { throw 'fixture Get-Disk failure' }
    return @($script:StorageTestDisks)
}
function Get-Partition {
    [CmdletBinding()]
    param([int]$DiskNumber)
    if ($DiskNumber -eq 8) { throw 'fixture partition failure' }
    return @($script:StorageTestPartitions[$DiskNumber])
}

$snapshot = Get-WindowsStorageSnapshot
Assert-Equal $true $snapshot.Available 'Storage infrastructure reports successful Windows inventory'
Assert-Equal 2 @($snapshot.Disks).Count 'Storage infrastructure returns all normalized Windows disks'
Assert-Equal 1 @($snapshot.Disks[0].Partitions).Count 'Storage infrastructure attaches normalized partitions'
Assert-Equal 0 @($snapshot.Disks[1].Partitions).Count 'Storage infrastructure tolerates one disk partition-query failure'

$script:StorageTestThrowDisk = $true
$unavailable = Get-WindowsStorageSnapshot
Assert-Equal $false $unavailable.Available 'Storage infrastructure reports unavailable Get-Disk inventory'
Assert-Equal 0 @($unavailable.Disks).Count 'Storage infrastructure unavailable snapshot contains no disks'

Write-Host "STORAGE INFRA TOTAL $checks/17"
if ($checks -ne 17) { throw "Unexpected storage infrastructure test count $checks" }
