#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Application\RefreshRuntime.ps1')

$checks = 0
function Assert-RefreshTest {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "${Name}: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$state = New-BackgroundRefreshRuntimeState
Assert-RefreshTest 'Initial state is idle' (-not (Test-BackgroundRefreshActive -State $state))

$request = New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $false
Assert-RefreshTest 'Request stores storage flag' ([bool]$request.RefreshStorage)
Assert-RefreshTest 'Request stores firmware flag' (-not [bool]$request.RefreshFirmware)

$now = [datetime]::UtcNow
Assert-RefreshTest 'Missing firmware cache requires refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText $null -FirmwareCacheUtc ([datetime]::MinValue) -NowUtc $now)
Assert-RefreshTest 'Fresh firmware cache skips refresh' (-not (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-5) -NowUtc $now))
Assert-RefreshTest 'Stale firmware cache requires refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-31) -NowUtc $now)
Assert-RefreshTest 'Storage refresh forces firmware refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $true -FirmwareCacheText 'cached' -FirmwareCacheUtc $now -NowUtc $now)

$activeRequest = New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true
$fakeProcess = [pscustomobject]@{ Id = 1234 }
Set-BackgroundRefreshActive -State $state -Process $fakeProcess -ResultPath 'result.json' -Request $activeRequest
Assert-RefreshTest 'Active lifecycle is visible' (Test-BackgroundRefreshActive -State $state)
Assert-RefreshTest 'Equivalent request does not escalate' (-not (Test-BackgroundRefreshRequestEscalation -ActiveRequest $activeRequest -Requested (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true)))
Assert-RefreshTest 'Storage request escalates firmware-only active request' (Test-BackgroundRefreshRequestEscalation -ActiveRequest $activeRequest -Requested (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $true))

[void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $false))
Assert-RefreshTest 'Pending request records storage escalation' ([bool]$state.PendingRequest.RefreshStorage)
[void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true))
Assert-RefreshTest 'Pending request coalesces firmware escalation' ([bool]$state.PendingRequest.RefreshFirmware)

$context = Take-BackgroundRefreshCompletionContext -State $state
Assert-RefreshTest 'Completion context preserves active request' ([bool]$context.Request.RefreshFirmware)
Assert-RefreshTest 'Completion context clears active lifecycle' (-not (Test-BackgroundRefreshActive -State $state))

$pending = Take-BackgroundRefreshPendingRequest -State $state
Assert-RefreshTest 'Pending request survives active completion' ([bool]$pending.RefreshStorage -and [bool]$pending.RefreshFirmware)
Assert-RefreshTest 'Taking pending request clears queue' ($null -eq $state.PendingRequest)

$timing = [pscustomobject]@{ TotalMs = 321 }
Set-BackgroundRefreshLastTiming -State $state -Timing $timing
Assert-RefreshTest 'Last timing stored in runtime state' ($state.LastTiming.TotalMs -eq 321)

$parsed = ConvertFrom-BackgroundRefreshResultText -Text '{"Success":true,"Stage":"complete"}'
Assert-RefreshTest 'Result JSON parses through application contract' ([bool]$parsed.Success -and [string]$parsed.Stage -eq 'complete')

Write-Host "REFRESH TOTAL $checks/18"
if ($checks -ne 18) { throw "Expected 18 refresh checks, got $checks" }
