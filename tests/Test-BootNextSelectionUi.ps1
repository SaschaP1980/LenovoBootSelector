#requires -version 5.1
# LBS-143 follow-up: immediate UI feedback may never mean verified firmware.
# Focused core and wiring guard. No Task Scheduler or firmware operations.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$corePath = Join-Path $root 'src\Core\BootNextSelectionState.ps1'
if (-not (Test-Path -LiteralPath $corePath)) { throw 'RED: BootNext pending presentation core is absent.' }
. $corePath
$checks = 0
function Assert-Selection([string]$Name,[bool]$Condition) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Name" }
    Write-Host "PASS $Name"
}
$a = '{11111111-1111-1111-1111-111111111111}'
$b = '{22222222-2222-2222-2222-222222222222}'
$c = '{33333333-3333-3333-3333-333333333333}'
Assert-Selection 'Unselected boot row remains idle' ((Resolve-BootNextRowDisplayCore -EntryGuid $b -ConfirmedGuid $a -PendingGuid '') -eq 'idle')
Assert-Selection 'Confirmed boot row keeps checked state' ((Resolve-BootNextRowDisplayCore -EntryGuid $a -ConfirmedGuid $a -PendingGuid '') -eq 'selected')
Assert-Selection 'Pending row is not treated as selected' ((Resolve-BootNextRowDisplayCore -EntryGuid $b -ConfirmedGuid $a -PendingGuid $b) -eq 'pending')
Assert-Selection 'Previous selection remains visibly confirmed during pending' ((Resolve-BootNextRowDisplayCore -EntryGuid $a -ConfirmedGuid $a -PendingGuid $b) -eq 'selected')
Assert-Selection 'Unrelated third target is idle while pending' ((Resolve-BootNextRowDisplayCore -EntryGuid $c -ConfirmedGuid $a -PendingGuid $b) -eq 'idle')
Assert-Selection 'Repeated pending target still pending' ((Resolve-BootNextRowDisplayCore -EntryGuid $b -ConfirmedGuid $b -PendingGuid $b) -eq 'pending')
Assert-Selection 'GUID matching ignores case' ((Resolve-BootNextRowDisplayCore -EntryGuid $b.ToUpperInvariant() -ConfirmedGuid $a -PendingGuid $b) -eq 'pending')
Assert-Selection 'Empty GUID never represents a selected row' ((Resolve-BootNextRowDisplayCore -EntryGuid '' -ConfirmedGuid '' -PendingGuid '') -eq 'idle')
Assert-Selection 'Worker success needs exact requested GUID' (Test-BootNextWorkerResultCore -RequestedGuid $b -ReturnedGuid $b -Success $true)
Assert-Selection 'Worker success cannot authorize a different GUID' (-not (Test-BootNextWorkerResultCore -RequestedGuid $b -ReturnedGuid $c -Success $true))
Assert-Selection 'Worker failure cannot authorize any GUID' (-not (Test-BootNextWorkerResultCore -RequestedGuid $b -ReturnedGuid $b -Success $false))
Assert-Selection 'Worker absence cannot authorize a GUID' (-not (Test-BootNextWorkerResultCore -RequestedGuid $b -ReturnedGuid '' -Success $true))
$ui = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
$app = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$workerPath = Join-Path $root 'src\Infrastructure\BootNextSelectionWorker.ps1'
$controllerPath = Join-Path $root 'src\Application\BootNextSelectionController.ps1'
Assert-Selection 'Entry clicks dispatch the nonblocking selection controller' ($ui.Contains('Start-BootNextSelection -Guid $guid') -and -not $ui.Contains('Set-BootNextTarget -Guid $guid'))
Assert-Selection 'Pending entry keeps distinct row rendering from confirmed selection' ($ui.Contains('Resolve-BootNextRowDisplayCore') -and $ui.Contains("'BootNext.SelectionPending'"))
Assert-Selection 'Application dispatches a dedicated nontray BootNext worker' ($app.Contains('if ($BootNextWorker) {') -and $app.Contains('Invoke-BootNextSelectionWorker'))
Assert-Selection 'BootNext worker is excluded from the main UI mutex' ($app.Contains('-not $BootNextWorker -and -not $BackgroundRefresh'))
Assert-Selection 'Worker delegates only to allowlisted verified BootService' ((Test-Path -LiteralPath $workerPath) -and ([IO.File]::ReadAllText($workerPath)).Contains('Set-BootNextTargetService -Guid $normalized'))
Assert-Selection 'Worker result is checked against the originally requested GUID' ((Test-Path -LiteralPath $controllerPath) -and ([IO.File]::ReadAllText($controllerPath)).Contains('Test-BootNextWorkerResultCore'))
Assert-Selection 'Pending state blocks unverified Windows restart' ($app.Contains('if ($script:BootNextPendingGuid) { return }') -and $app.Contains('Update-BootNextRestartInterlock'))
Assert-Selection 'Background refresh cannot replace pending visible firmware selection' ($app.Contains('if ($script:BootNextPendingGuid) {') -and $app.Contains('BACKGROUND_REFRESH_RESULT_DEFERRED_FOR_BOOTNEXT'))
Assert-Selection 'BootNext worker process is disposed during shutdown' ($app.Contains('Stop-BootNextSelectionWorker -Reason'))
Assert-Selection 'Both English and German pending labels exist' (([IO.File]::ReadAllText((Join-Path $root 'src\Core\Localization.ps1')) -split "'BootNext.SelectionPending' =").Count -eq 3)
# Exercise the actual unelevated worker body with a mocked, allowlisted
# BootService boundary. This must never touch real Scheduled Tasks or BCDEdit.
. $workerPath
$script:MockBootNextMode = 'success'
function Normalize-TaskBrokerGuid { param([string]$Guid) return ([string]$Guid).ToLowerInvariant() }
function Set-BootNextTargetService {
    param([string]$Guid)
    if ($script:MockBootNextMode -eq 'throw') { throw 'fake authorized task failure' }
    if ($script:MockBootNextMode -eq 'mismatch') { return [pscustomobject]@{ ExitCode=0; Guid=$c } }
    return [pscustomobject]@{ ExitCode=0; Guid=$Guid }
}
function New-RuntimeDiagnosticData { param($Data) return $Data }
function Write-RuntimeDiagnosticEvent {
    param([string]$Event,[string]$Stage,[bool]$Success,$DurationMs,$Data,[string]$Level)
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('LBS143-UI-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
try {
    $path = Join-Path $temp 'bootnext.json'
    $exit = Invoke-BootNextSelectionWorker -Guid $b -ResultPath $path
    $result = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    Assert-Selection 'Worker returns success only after mocked verified service result' ($exit -eq 0)
    Assert-Selection 'Worker serializes the actual verified requested GUID' ($result.Success -and $result.Guid -eq $b)
    $script:MockBootNextMode = 'mismatch'
    $exit = Invoke-BootNextSelectionWorker -Guid $b -ResultPath $path
    $result = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    Assert-Selection 'Worker refuses mismatched verified target' ($exit -ne 0 -and -not $result.Success)
    $script:MockBootNextMode = 'throw'
    $exit = Invoke-BootNextSelectionWorker -Guid $b -ResultPath $path
    $result = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    Assert-Selection 'Worker fails closed when authorized task fails' ($exit -ne 0 -and -not $result.Success)
    Assert-Selection 'Worker conveys the failure in its completion file' ([string]$result.Error -like '*fake authorized task failure*')

    Add-Type -AssemblyName System.Windows.Forms
    . $controllerPath
    $script:BootNextPendingGuid = $b
    $script:RestartButton = New-Object System.Windows.Forms.Button
    $script:RestartTargetLabel = New-Object System.Windows.Forms.Button
    function Get-EntryByGuid { param($Guid) return [pscustomobject]@{ Guid=$Guid; Title='Windows: Gaming' } }
    function Get-EntryDisplayTitle { param($Entry) return $Entry.Title }
    function Get-LocalizedString {
        param($Key,$Values)
        if ($Key -eq 'BootNext.SelectionPendingFooter') { return ('Setting ' + $Values.Target) }
        return $Key
    }
    Update-BootNextRestartInterlock
    Assert-Selection 'Pending UI makes Windows restart unavailable' (-not $script:RestartButton.Enabled)
    Assert-Selection 'Pending footer explicitly labels requested target' ($script:RestartTargetLabel.Text -like '*Windows: Gaming*')
    $script:BootNextPendingGuid = $null
    Update-BootNextRestartInterlock
    Assert-Selection 'Restart interlock releases only after pending request ends' ([bool]$script:RestartButton.Enabled)
}
finally {
    if ($script:RestartButton) { $script:RestartButton.Dispose() }
    if ($script:RestartTargetLabel) { $script:RestartTargetLabel.Dispose() }
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
# Cold-open regression: an already known/allowlisted boot target must be
# visibly queued while the first cached-readiness background worker is active.
# These decisions are pure and never invoke any privileged BootNext action.
Assert-Selection 'Cold Checking with prior cached/allowed target and active refresh defers' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Checking' -CanSetBootNext $false -CanUseCachedBootState $true -RefreshActive $true -TargetAllowlisted $true) -eq 'deferred')
Assert-Selection 'Cold Checking without verified cached capability fails closed' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Checking' -CanSetBootNext $false -CanUseCachedBootState $false -RefreshActive $true -TargetAllowlisted $true) -eq 'reject')
Assert-Selection 'Cold Checking without an active readiness refresh fails closed' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Checking' -CanSetBootNext $false -CanUseCachedBootState $true -RefreshActive $false -TargetAllowlisted $true) -eq 'reject')
Assert-Selection 'Cold Checking never defers an unallowlisted target' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Checking' -CanSetBootNext $false -CanUseCachedBootState $true -RefreshActive $true -TargetAllowlisted $false) -eq 'reject')
Assert-Selection 'Warm Ready and authorized target starts immediately' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Ready' -CanSetBootNext $true -CanUseCachedBootState $true -RefreshActive $false -TargetAllowlisted $true) -eq 'start')
Assert-Selection 'Ready without BootNext capability fails closed' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Ready' -CanSetBootNext $false -CanUseCachedBootState $true -RefreshActive $false -TargetAllowlisted $true) -eq 'reject')
Assert-Selection 'Missing target never starts even when ready' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Ready' -CanSetBootNext $true -CanUseCachedBootState $true -RefreshActive $false -TargetAllowlisted $false) -eq 'reject')
Assert-Selection 'RepairRequired never starts' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'RepairRequired' -CanSetBootNext $false -CanUseCachedBootState $false -RefreshActive $true -TargetAllowlisted $true) -eq 'reject')
Assert-Selection 'Maintenance Busy never queues a request' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'Busy' -CanSetBootNext $false -CanUseCachedBootState $true -RefreshActive $true -TargetAllowlisted $true) -eq 'reject')
Assert-Selection 'Firmware drift ReinitializeRequired never queues a request' ((Resolve-BootNextSelectionAdmissionCore -CapabilityState 'ReinitializeRequired' -CanSetBootNext $false -CanUseCachedBootState $false -RefreshActive $true -TargetAllowlisted $true) -eq 'reject')
$sourceController = [IO.File]::ReadAllText($controllerPath)
Assert-Selection 'Boot click reaches guarded controller during Checking' ($ui.Contains('Start-BootNextSelection -Guid $guid') -and -not $ui.Contains('elseif (-not $capabilities.CanSetBootNext)'))
Assert-Selection 'Controller evaluates explicit cold readiness disposition' ($sourceController.Contains('Resolve-BootNextSelectionAdmissionCore') -and $sourceController.Contains("'deferred'"))
Assert-Selection 'Cold intent keeps independent deferred state while pending is visible' ($sourceController.Contains('$script:BootNextSelectionDeferred') -and $sourceController.Contains('Update-PopupRows'))
Assert-Selection 'Cold intent does not cancel the readiness-producing refresh first' ($sourceController.Contains('BOOTNEXT_CLICK_DEFERRED') -and $sourceController.Contains('if (-not $deferred'))
Assert-Selection 'Deferred request has bounded timeout and a visible failure path' ($sourceController.Contains('BOOTNEXT_DEFERRED_TIMEOUT') -and $sourceController.Contains('Fail-DeferredBootNextSelection'))
Assert-Selection 'Telemetry separates pending display and actual authorized worker start' ($sourceController.Contains('BOOTNEXT_PENDING_SHOWN') -and $sourceController.Contains('BOOTNEXT_WORKER_STARTED'))
# Simulate the real WinForms controller during the first (cold) popup open.
# These mocks replace ALL task/firmware writes with in-process observations.
$script:MockReadiness = 'Checking'
$script:MockRefreshActive = $true
$script:MockWorkerStarts = 0
$script:MockRefreshStops = 0
$script:MockRowsDrawn = 0
$script:MockNotices = 0
$script:TaskBrokerLocalDir = $temp
$script:ScriptPath = 'isolated-test-application.ps1'
$script:RuntimeSessionId = 'focused-native-mock'
$script:BackgroundRefreshState = [pscustomobject]@{ Active=$true }
$script:IsManageEntriesMode = $false
$script:BootNextPendingGuid = $null
$script:BootNextSelectionDeferred = $false
$script:BootNextSelectionStartedUtc = [datetime]::MinValue
$script:BootNextSelectionProcess = $null
$script:BootNextSelectionTimer = $null
$script:RestartButton = New-Object System.Windows.Forms.Button
$script:RestartTargetLabel = New-Object System.Windows.Forms.Button
function Get-TaskBrokerTarget { param([string]$Guid) return [pscustomobject]@{ Guid=$Guid } }
function Test-MaintenanceBusy { return $false }
function Test-BackgroundRefreshActive { param($State) return [bool]$script:MockRefreshActive }
function Stop-BackgroundBootRefreshForMaintenance { param([string]$Reason) $script:MockRefreshStops++ }
function Remove-BackgroundRefreshResultFile { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { Remove-Item -LiteralPath $Path -Force } }
function Get-CurrentSystemFunctionsCapabilities {
    return [pscustomobject]@{
        State=$script:MockReadiness
        CanUseCachedBootState=($script:MockReadiness -eq 'Checking' -or $script:MockReadiness -eq 'Ready')
        CanSetBootNext=($script:MockReadiness -eq 'Ready')
    }
}
function Update-PopupRows { $script:MockRowsDrawn++ }
function Show-LenovoNoticeDialog { param($Title,$Heading,$Message,$Kind) $script:MockNotices++ }
function Start-BootNextSelectionWorkerProcess {
    param($ScriptPath,$Guid,$ResultPath,$RuntimeSessionId)
    $script:MockWorkerStarts++
    return [pscustomobject]@{ Id=4242; HasExited=$false }
}
try {
    Start-BootNextSelection -Guid $b
    Assert-Selection 'First click during Checking creates deferred pending GUID' ($script:BootNextPendingGuid -eq $b -and $script:BootNextSelectionDeferred)
    Assert-Selection 'First click paints pending marker and blocks restart' ($script:MockRowsDrawn -gt 0 -and -not $script:RestartButton.Enabled)
    Assert-Selection 'First click does not cancel readiness-producing refresh or start writer' ($script:MockRefreshStops -eq 0 -and $script:MockWorkerStarts -eq 0)
    Complete-BootNextSelection
    Assert-Selection 'Repeated Checking timer tick does not start worker' ($script:MockWorkerStarts -eq 0 -and $script:BootNextSelectionDeferred)
    Start-BootNextSelection -Guid $c
    Assert-Selection 'Second click cannot replace queued first target' ($script:BootNextPendingGuid -eq $b -and $script:MockWorkerStarts -eq 0)
    $script:MockRefreshActive = $false
    $script:MockReadiness = 'Ready'
    Complete-BootNextSelection
    Assert-Selection 'Readiness transition starts exactly one verified-path worker' ($script:MockWorkerStarts -eq 1 -and -not $script:BootNextSelectionDeferred)
    Assert-Selection 'Worker start still retains unverified pending marker' ($script:BootNextPendingGuid -eq $b -and -not $script:RestartButton.Enabled)
    Complete-BootNextSelection
    Assert-Selection 'Repeated timer cannot launch a second privileged request' ($script:MockWorkerStarts -eq 1)
    Stop-BootNextSelectionWorker -Reason 'mock-finished'
    Assert-Selection 'Test controller cleanup clears pending and deferred state' (-not $script:BootNextPendingGuid -and -not $script:BootNextSelectionDeferred)

    $script:MockReadiness = 'Checking'
    $script:MockRefreshActive = $true
    Start-BootNextSelection -Guid $b
    $script:MockReadiness = 'RepairRequired'
    Complete-BootNextSelection
    Assert-Selection 'Failed startup readiness clears pending and reports error' (-not $script:BootNextPendingGuid -and $script:MockNotices -ge 1 -and $script:MockWorkerStarts -eq 1)

    $script:MockReadiness = 'Checking'
    $script:MockRefreshActive = $true
    Start-BootNextSelection -Guid $b
    $script:BootNextSelectionStartedUtc = [datetime]::UtcNow.AddSeconds(-47)
    Complete-BootNextSelection
    Assert-Selection 'Stalled cold startup expires pending without starting writer' (-not $script:BootNextPendingGuid -and $script:MockWorkerStarts -eq 1 -and $script:MockNotices -ge 2)
}
finally {
    Stop-BootNextSelectionWorker -Reason 'focused-native-cleanup'
    $script:RestartButton.Dispose()
    $script:RestartTargetLabel.Dispose()
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "BOOTNEXT SELECTION UI TOTAL $checks/57"
if ($checks -ne 57) { throw "Unexpected pending selection count $checks" }
