#requires -version 5.1
# LBS-143: read-only firmware snapshot proof; no Task Scheduler/BCD writes.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\FirmwareParsing.ps1')
. (Join-Path $root 'src\Application\BootService.ps1')
$script:checks = 0
function Assert-Snapshot([string]$Name, [bool]$Ok) {
    if (-not $Ok) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS $Name"
}
$a = '{aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}'
$b = '{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}'
$script:ManagerText = "Firmware Boot Manager" + "`r`nidentifier {fwbootmgr}`r`ndisplayorder $a`r`nbootsequence $b`r`n"
$script:EntriesText = "Firmware Application" + "`r`nidentifier $a`r`ndescription Boot Menu`r`n"
$script:ManagerCalls = @()
$script:EntriesCalls = @()
function Get-TaskBrokerFirmwareManagerText {
    param([switch]$Force, [switch]$UseExistingCache)
    $script:ManagerCalls += [pscustomobject]@{ Force=[bool]$Force; Cache=[bool]$UseExistingCache }
    return $script:ManagerText
}
function Get-TaskBrokerFirmwareEntriesText {
    param([switch]$Force, [switch]$UseExistingCache)
    $script:EntriesCalls += [pscustomobject]@{ Force=[bool]$Force; Cache=[bool]$UseExistingCache }
    return $script:EntriesText
}
$initial = Get-BootServiceFirmwareSnapshot
Assert-Snapshot 'Regular snapshot preserves parsed selected GUID' ($initial.ManagerState.SelectedGuid -eq $b)
Assert-Snapshot 'Regular snapshot parses display order' (@($initial.ManagerState.DisplayOrder).Count -eq 1 -and @($initial.ManagerState.DisplayOrder)[0] -eq $a)
Assert-Snapshot 'Regular snapshot preserves description' ([string]$initial.Descriptions[$a] -eq 'Boot Menu')
Assert-Snapshot 'Regular snapshot does not assert forced manager refresh' ($script:ManagerCalls.Count -eq 1 -and -not $script:ManagerCalls[0].Force)
Assert-Snapshot 'Regular snapshot does not force firmware entries read' ($script:EntriesCalls.Count -eq 1 -and -not $script:EntriesCalls[0].Force)
$verified = Get-BootServiceFirmwareSnapshot -ForceManagerRefresh
Assert-Snapshot 'Verified snapshot forces manager read' ($script:ManagerCalls.Count -eq 2 -and $script:ManagerCalls[1].Force -and -not $script:ManagerCalls[1].Cache)
Assert-Snapshot 'Forced manager read retains next target' ($verified.ManagerState.SelectedGuid -eq $b)
$cached = Get-BootServiceFirmwareSnapshot -UseExistingCache
Assert-Snapshot 'Cached snapshot uses manager cache' ($script:ManagerCalls.Count -eq 3 -and $script:ManagerCalls[2].Cache -and -not $script:ManagerCalls[2].Force)
Assert-Snapshot 'Cached snapshot uses firmware entries cache' ($script:EntriesCalls.Count -eq 3 -and $script:EntriesCalls[2].Cache)
$before = $script:ManagerCalls.Count
$rejected = $false
try { [void](Get-BootServiceFirmwareSnapshot -UseExistingCache -ForceManagerRefresh) }
catch { $rejected = $true }
Assert-Snapshot 'Force plus cache fails before broker access' ($rejected -and $script:ManagerCalls.Count -eq $before)
Write-Host "BOOT SERVICE SNAPSHOT TOTAL $script:checks/10"
if ($script:checks -ne 10) { throw "Unexpected boot snapshot count $script:checks" }
