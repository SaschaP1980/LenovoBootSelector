#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Application\RefreshRuntime.ps1')
. (Join-Path $root 'src\Infrastructure\BackgroundRefreshWorker.ps1')
. (Join-Path $root 'src\Application\RefreshController.ps1')

$script:checks = 0
function Assert-RefreshControllerTest {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "${Name}: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

function New-FakeRefreshProcess {
    param([int]$Id,[bool]$HasExited=$false)
    $p = [pscustomobject]@{
        Id = $Id
        HasExited = $HasExited
        RefreshCount = 0
        Killed = $false
        Disposed = $false
    }
    $p | Add-Member ScriptMethod Refresh { $this.RefreshCount++ }
    $p | Add-Member ScriptMethod Kill { $this.Killed = $true; $this.HasExited = $true }
    $p | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
    return $p
}

function New-FakeRefreshTimer {
    $t = [pscustomobject]@{
        Started = $false
        Stopped = $false
        Disposed = $false
    }
    $t | Add-Member ScriptMethod Start { $this.Started = $true }
    $t | Add-Member ScriptMethod Stop { $this.Stopped = $true }
    $t | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
    return $t
}

$script:TestMaintenanceBusy = $false
$script:TestMaintenanceMode = 'None'
$script:TestBrokerReady = $true
$script:TestBrokerPresent = $true
$script:TestWorkerStarts = 0
$script:TestNextProcessId = 100
$script:TestLastStartedProcess = $null
$script:TestLastTimer = $null
$script:TestRemovedPaths = @()
$script:TestDiagnostics = @()
$script:TestResultText = '{"Success":true,"Stage":"complete","StorageContext":null,"Timings":{"ReadyMs":1,"ManagerMs":2,"FirmwareMs":3,"StorageMs":0,"TotalMs":6}}'
$script:TestPopupRows = 0
$script:TestRefreshVisual = 0
$script:TestApplyFirmware = 0
$script:TestSyncCaches = 0
$script:TestDriftUpdates = 0
$script:TestDriftNotifications = 0
$script:TestWorkerStorageContext = [pscustomobject]@{ Marker = 'worker-storage' }

function Test-MaintenanceBusy { return [bool]$script:TestMaintenanceBusy }
function Get-MaintenanceMode { return [string]$script:TestMaintenanceMode }
function New-RuntimeDiagnosticData { param($Data) return $Data }
function Write-RuntimeDiagnosticEvent {
    param([string]$Event,[string]$Stage,[bool]$Success,$DurationMs,$Data,$ErrorRecord,[string]$Level)
    $script:TestDiagnostics += [pscustomobject]@{ Event=$Event; Stage=$Stage; Success=$Success; Data=$Data; Level=$Level }
}
function Test-TaskBrokerInstallationPresent { return [bool]$script:TestBrokerPresent }
function Get-LocalizedString { param([string]$Key,$Values) return $Key }
function Update-TaskBrokerUiState { param([switch]$Fast); return $true }
function Update-PopupRows { $script:TestPopupRows++ }
function Sync-TaskBrokerFirmwareCachesFromFiles { $script:TestSyncCaches++; return [pscustomobject]@{} }
function Update-BootTargetDriftState { $script:TestDriftUpdates++; return $true }
function Get-FirmwareBootState { param([switch]$UseExistingCache); return [pscustomobject]@{ Entries=@(); SelectedGuid=$null } }
function Apply-FirmwareBootState { param($State); $script:TestApplyFirmware++ }
function Show-BootTargetDriftNotificationIfNeeded { $script:TestDriftNotifications++ }
function Update-RefreshButtonVisual { $script:TestRefreshVisual++ }
function Read-BackgroundRefreshResultText { param([string]$Path); return [string]$script:TestResultText }
function Remove-BackgroundRefreshResultFile { param([string]$Path); $script:TestRemovedPaths += [string]$Path }
function Get-TaskBrokerInteractiveReady { return [bool]$script:TestBrokerReady }
function Start-BackgroundRefreshWorkerProcess {
    param([string]$ScriptPath,[string]$ResultPath,[bool]$RefreshStorage,[bool]$RefreshFirmware,[string]$RuntimeSessionId)
    $script:TestWorkerStarts++
    $p = New-FakeRefreshProcess -Id $script:TestNextProcessId
    $script:TestNextProcessId++
    $script:TestLastStartedProcess = $p
    return $p
}
function New-BackgroundRefreshCompletionTimer {
    param([scriptblock]$TickAction)
    $script:TestLastTimer = New-FakeRefreshTimer
    return $script:TestLastTimer
}
function Test-TaskBrokerReady { param([switch]$Force); return [bool]$script:TestBrokerReady }
function Get-TaskBrokerFirmwareManagerText { param([switch]$Force); return 'manager' }
function Get-TaskBrokerFirmwareEntriesText { param([switch]$Force); return 'firmware' }
function Get-StorageContext { return $script:TestWorkerStorageContext }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-RefreshController-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$scriptPath = Join-Path $tempRoot 'runtime.ps1'
[System.IO.File]::WriteAllText($scriptPath,'# test',[System.Text.Encoding]::UTF8)

try {
    $script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState
    $script:ScriptPath = $scriptPath
    $script:TaskBrokerLocalDir = $tempRoot
    $script:RuntimeSessionId = 'parent-session'
    $script:FirmwareCacheText = 'cached'
    $script:FirmwareCacheUtc = [datetime]::UtcNow
    $script:TaskBrokerReadyCached = $null
    $script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
    $script:LastStatusText = ''
    $script:StorageContext = $null
    $script:Popup = $null

    Start-BackgroundBootRefresh
    $firstProcess = $script:BackgroundRefreshState.Process
    $firstTimer = $script:BackgroundRefreshState.Timer
    Assert-RefreshControllerTest 'Idle request starts one worker' ($script:TestWorkerStarts -eq 1)
    Assert-RefreshControllerTest 'Idle request becomes active' (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)
    Assert-RefreshControllerTest 'Fresh cache keeps firmware work false' (-not [bool]$script:BackgroundRefreshState.ActiveRequest.RefreshFirmware)
    Assert-RefreshControllerTest 'Controller starts completion timer' ([bool]$firstTimer.Started)

    Start-BackgroundBootRefresh
    Assert-RefreshControllerTest 'Equivalent active request does not queue pending work' ($null -eq $script:BackgroundRefreshState.PendingRequest)
    Assert-RefreshControllerTest 'Equivalent active request does not start another worker' ($script:TestWorkerStarts -eq 1)

    Start-BackgroundBootRefresh -RefreshStorage
    Assert-RefreshControllerTest 'Storage escalation is coalesced as pending' ([bool]$script:BackgroundRefreshState.PendingRequest.RefreshStorage)
    Assert-RefreshControllerTest 'Storage escalation also requests firmware refresh' ([bool]$script:BackgroundRefreshState.PendingRequest.RefreshFirmware)

    $firstProcess.HasExited = $true
    Complete-BackgroundBootRefresh
    Assert-RefreshControllerTest 'Completion continues pending request with second worker' ($script:TestWorkerStarts -eq 2)
    Assert-RefreshControllerTest 'Pending continuation becomes active storage request' ([bool]$script:BackgroundRefreshState.ActiveRequest.RefreshStorage)
    Assert-RefreshControllerTest 'Completed process is disposed' ([bool]$firstProcess.Disposed)
    Assert-RefreshControllerTest 'Completed timer is stopped and disposed' ([bool]$firstTimer.Stopped -and [bool]$firstTimer.Disposed)

    $secondProcess = $script:BackgroundRefreshState.Process
    $secondTimer = $script:BackgroundRefreshState.Timer
    $secondProcess.HasExited = $true
    $script:TestResultText = '{"Success":true,"Stage":"complete","StorageContext":{"Marker":"applied-storage"},"Timings":{"ReadyMs":4,"ManagerMs":5,"FirmwareMs":6,"StorageMs":7,"TotalMs":22}}'
    Complete-BackgroundBootRefresh
    Assert-RefreshControllerTest 'Successful storage completion returns lifecycle to idle' (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))
    Assert-RefreshControllerTest 'Successful storage result is applied to application state' ([string]$script:StorageContext.Marker -eq 'applied-storage')
    Assert-RefreshControllerTest 'Successful timing is retained in RefreshRuntime state' ($script:BackgroundRefreshState.LastTiming.TotalMs -eq 22)
    Assert-RefreshControllerTest 'Successful result refreshes caches and drift' ($script:TestSyncCaches -ge 2 -and $script:TestDriftUpdates -ge 2)
    Assert-RefreshControllerTest 'Second completion owns timer cleanup' ([bool]$secondTimer.Stopped -and [bool]$secondTimer.Disposed)

    $readyFailure = [pscustomobject]@{
        Success = $false
        Stage = 'ready'
        Error = 'not ready'
        StorageContext = $null
        Timings = [pscustomobject]@{ TotalMs = 9; ReadyMs=9; ManagerMs=0; FirmwareMs=0; StorageMs=0 }
    }
    $continue = Apply-BackgroundRefreshResult -Result $readyFailure -Request (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $false)
    Assert-RefreshControllerTest 'Ready-stage failure suppresses pending continuation' (-not [bool]$continue)
    Assert-RefreshControllerTest 'Ready-stage failure invalidates TaskBroker readiness' ($script:TaskBrokerReadyCached -eq $false)
    Assert-RefreshControllerTest 'Ready-stage failure selects repair-required status when broker exists' ($script:LastStatusText -eq 'Status.SystemFunctionsRepairRequired')

    Start-BackgroundBootRefresh
    $cancelProcess = $script:BackgroundRefreshState.Process
    $cancelTimer = $script:BackgroundRefreshState.Timer
    [void](Add-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState -Request (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $true))
    Stop-BackgroundBootRefreshForMaintenance -Reason 'Repair'
    Assert-RefreshControllerTest 'Maintenance cancellation returns lifecycle to idle' (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))
    Assert-RefreshControllerTest 'Maintenance cancellation clears pending work' ($null -eq $script:BackgroundRefreshState.PendingRequest)
    Assert-RefreshControllerTest 'Maintenance cancellation kills and disposes worker' ([bool]$cancelProcess.Killed -and [bool]$cancelProcess.Disposed)
    Assert-RefreshControllerTest 'Maintenance cancellation stops and disposes timer' ([bool]$cancelTimer.Stopped -and [bool]$cancelTimer.Disposed)
    Assert-RefreshControllerTest 'Maintenance cancellation removes owned result file' ($script:TestRemovedPaths.Count -ge 3)

    $beforeSuppressed = $script:TestWorkerStarts
    $script:TestMaintenanceBusy = $true
    $script:TestMaintenanceMode = 'Repair'
    Start-BackgroundBootRefresh -RefreshStorage
    Assert-RefreshControllerTest 'Maintenance suppresses new refresh worker' ($script:TestWorkerStarts -eq $beforeSuppressed)
    Assert-RefreshControllerTest 'Maintenance suppression is diagnosed' (@($script:TestDiagnostics | Where-Object { $_.Event -eq 'BACKGROUND_REFRESH_SUPPRESSED' }).Count -ge 1)
    $script:TestMaintenanceBusy = $false

    $failureProcess = New-FakeRefreshProcess -Id 999 -HasExited $true
    $failureTimer = New-FakeRefreshTimer
    $failureRequest = New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $false
    Set-BackgroundRefreshActive -State $script:BackgroundRefreshState -Process $failureProcess -ResultPath 'broken-result.json' -Request $failureRequest
    Set-BackgroundRefreshTimer -State $script:BackgroundRefreshState -Timer $failureTimer
    $script:TestResultText = 'not-json'
    Complete-BackgroundBootRefresh
    Assert-RefreshControllerTest 'Malformed worker result still clears active lifecycle' (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))
    Assert-RefreshControllerTest 'Malformed worker result sets localized refresh-failed status' ($script:LastStatusText -eq 'Status.BootTargetsRefreshFailed')
    Assert-RefreshControllerTest 'Malformed worker result still disposes process' ([bool]$failureProcess.Disposed)
    Assert-RefreshControllerTest 'Malformed worker result still removes result file' ($script:TestRemovedPaths -contains 'broken-result.json')

    $script:TestDiagnostics = @()
    $script:TestBrokerReady = $true
    $successPath = Join-Path $tempRoot 'worker-success.json'
    $exitCode = Invoke-BackgroundRefreshWorker -RefreshStorage $true -RefreshFirmware $true -ResultPath $successPath
    $successResult = ([System.IO.File]::ReadAllText($successPath,[System.Text.Encoding]::UTF8) | ConvertFrom-Json)
    Assert-RefreshControllerTest 'Infrastructure worker success returns zero' ($exitCode -eq 0)
    Assert-RefreshControllerTest 'Infrastructure worker success writes complete result' ([bool]$successResult.Success -and [string]$successResult.Stage -eq 'complete')
    Assert-RefreshControllerTest 'Infrastructure worker success serializes storage result' ([string]$successResult.StorageContext.Marker -eq 'worker-storage')
    Assert-RefreshControllerTest 'Infrastructure worker success writes completion diagnostic' (@($script:TestDiagnostics | Where-Object { $_.Event -eq 'BACKGROUND_WORKER_COMPLETED' -and $_.Success }).Count -eq 1)

    $script:TestDiagnostics = @()
    $script:TestBrokerReady = $false
    $failurePath = Join-Path $tempRoot 'worker-failure.json'
    $exitCode = Invoke-BackgroundRefreshWorker -RefreshStorage $false -RefreshFirmware $false -ResultPath $failurePath
    $workerFailure = ([System.IO.File]::ReadAllText($failurePath,[System.Text.Encoding]::UTF8) | ConvertFrom-Json)
    Assert-RefreshControllerTest 'Infrastructure worker ready failure returns one' ($exitCode -eq 1)
    Assert-RefreshControllerTest 'Infrastructure worker ready failure preserves ready stage' (-not [bool]$workerFailure.Success -and [string]$workerFailure.Stage -eq 'ready')
    Assert-RefreshControllerTest 'Infrastructure worker ready failure persists error text' (-not [string]::IsNullOrWhiteSpace([string]$workerFailure.Error))
}
finally {
    try { if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force } } catch { }
}

Write-Host "REFRESH CONTROLLER TOTAL $script:checks/38"
if ($script:checks -ne 38) { throw "Expected 38 refresh controller checks, got $script:checks" }
