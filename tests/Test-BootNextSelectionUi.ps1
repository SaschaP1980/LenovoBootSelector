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
Write-Host "BOOTNEXT SELECTION UI TOTAL $checks/30"
if ($checks -ne 30) { throw "Unexpected pending selection count $checks" }
