#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Application\MaintenanceRuntime.ps1')

$checks = 0
function Assert-MaintenanceTest {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "${Name}: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$state = New-MaintenanceRuntimeState
Assert-MaintenanceTest 'Initial maintenance state is idle' (-not (Test-MaintenanceRuntimeBusy -State $state))
Assert-MaintenanceTest 'Initial maintenance mode is empty' ((Get-MaintenanceRuntimeMode -State $state) -eq '')

$started = [datetime]::UtcNow
[void](Set-MaintenanceRuntimeActive -State $state -Mode 'Setup' -NowUtc $started)
Assert-MaintenanceTest 'Setup enters busy state' (Test-MaintenanceRuntimeBusy -State $state)
Assert-MaintenanceTest 'Setup mode is retained' ((Get-MaintenanceRuntimeMode -State $state) -eq 'Setup')
Assert-MaintenanceTest 'Setup start time is retained' ($state.StartedUtc -eq $started)

[void](Clear-MaintenanceRuntimeState -State $state)
Assert-MaintenanceTest 'Clear returns maintenance state to idle' (-not (Test-MaintenanceRuntimeBusy -State $state))
Assert-MaintenanceTest 'Clear removes maintenance mode' ((Get-MaintenanceRuntimeMode -State $state) -eq '')

foreach ($mode in @('Repair','Migrate','Reinitialize','Remove')) {
    [void](Set-MaintenanceRuntimeActive -State $state -Mode $mode)
    Assert-MaintenanceTest "Mode $mode enters busy state" (Test-MaintenanceRuntimeBusy -State $state)
    Assert-MaintenanceTest "Mode $mode is retained" ((Get-MaintenanceRuntimeMode -State $state) -eq $mode)
    [void](Clear-MaintenanceRuntimeState -State $state)
}

Write-Host "MAINTENANCE TOTAL $checks/15"
if ($checks -ne 15) { throw "Expected 15 maintenance checks, got $checks" }
