#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Core\UpdateModel.ps1')
. (Join-Path $root 'src\Application\UpdateRuntime.ps1')
. (Join-Path $root 'src\Application\UpdateController.ps1')

$script:checks = 0
function Assert-UpdateController {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "$Name: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

function New-FakeUpdateProcess {
    param([int]$Id,[bool]$HasExited=$false)
    $p=[pscustomobject]@{Id=$Id;HasExited=$HasExited;RefreshCount=0;Disposed=$false}
    $p | Add-Member ScriptMethod Refresh { $this.RefreshCount++ }
    $p | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    return $p
}

function New-FakeUpdateTimer {
    param([scriptblock]$TickAction)
    $t=[pscustomobject]@{Started=$false;Stopped=$false;Disposed=$false;Action=$TickAction}
    $t | Add-Member ScriptMethod Start { $this.Started=$true }
    $t | Add-Member ScriptMethod Stop { $this.Stopped=$true }
    $t | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    return $t
}

$script:FakeFiles=@{}
$script:RemovedFiles=@()
$script:Diagnostics=@()
$script:CheckStarts=0
$script:PrepareStarts=0
$script:InstallerStarts=0
$script:NextProcessId=100
$script:InstallDirectoryWritable=$true
$script:CompletionCount=0
$script:LastCheckTimer=$null
$script:LastPrepareTimer=$null
$script:LastInstallerProcess=$null
$script:PendingRestartResult=$null
$script:PendingRestartRemoved=0

function New-RuntimeDiagnosticData { param([hashtable]$Data) return $Data }
function Write-RuntimeDiagnosticEvent {
    param([string]$Event,[string]$Stage,[bool]$Success,$DurationMs,$Data,$ErrorRecord,[string]$Level)
    $script:Diagnostics += [pscustomobject]@{Event=$Event;Stage=$Stage;Success=$Success;Data=$Data;Level=$Level}
}
function New-LenovoUpdateCheckResultPath {
    return ('check-{0}.json' -f ([guid]::NewGuid().ToString('N')))
}
function Read-LenovoUpdateWorkerResult {
    param([string]$Path)
    if (-not $Path -or -not $script:FakeFiles.ContainsKey($Path)) { return $null }
    $value=$script:FakeFiles[$Path]
    if ($value -is [System.Exception]) { throw $value }
    return $value
}
function Remove-LenovoUpdateWorkflowFile {
    param([string]$Path)
    if ($Path) {
        $script:RemovedFiles += $Path
        [void]$script:FakeFiles.Remove($Path)
    }
}
function New-LenovoUpdatePrepareInput {
    param($Manifest)
    $id=[guid]::NewGuid().ToString('N')
    $manifestPath="manifest-$id.json"
    $resultPath="prepare-$id.json"
    $script:FakeFiles[$manifestPath]=$Manifest
    return [pscustomobject]@{ManifestPath=$manifestPath;ResultPath=$resultPath}
}
function Start-UpdateCheckWorkerProcess {
    param([string]$ResultPath,[string]$RuntimeSessionId)
    $script:CheckStarts++
    $p=New-FakeUpdateProcess -Id $script:NextProcessId
    $script:NextProcessId++
    return $p
}
function Start-UpdatePrepareWorkerProcess {
    param([string]$ManifestPath,[string]$ResultPath,[string]$RuntimeSessionId)
    $script:PrepareStarts++
    $p=New-FakeUpdateProcess -Id $script:NextProcessId
    $script:NextProcessId++
    return $p
}
function Test-UpdateInstallDirectoryWritable { return [bool]$script:InstallDirectoryWritable }
function Start-LenovoUpdateInstallerHelper {
    param([string]$WorkDir,[string]$SourceVersion,[string]$FailurePrefix,[string]$ManualRestartMessage)
    $script:InstallerStarts++
    if ($script:InstallerStarts -lt 0) { return $null }
    $p=New-FakeUpdateProcess -Id $script:NextProcessId
    $script:NextProcessId++
    $script:LastInstallerProcess=$p
    return $p
}
function Read-LenovoUpdateResult { return $script:PendingRestartResult }
function Remove-LenovoUpdateResult { $script:PendingRestartRemoved++ }

function New-TestManifest([string]$Version='0.10.4.0') {
    return [pscustomobject]@{
        schemaVersion=1
        version=$Version
        file=("LenovoBootMenuTray-v$Version.zip")
        sha256=('a'*64)
        size=123
        tag=("v$Version")
        packageFiles=@(
            'BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1',
            'LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','README.md',
            'Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs',
            'Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1'
        )
    }
}

$timerFactory={
    param([scriptblock]$TickAction)
    $t=New-FakeUpdateTimer -TickAction $TickAction
    if (-not $script:LastCheckTimer -or $script:ActiveTimerKind -eq 'check') { $script:LastCheckTimer=$t }
    else { $script:LastPrepareTimer=$t }
    return $t
}

$state=New-UpdateRuntimeState
$script:ActiveTimerKind='check'
$start=Start-UpdateCheckWorkflow -State $state -Mode 'Manual' -RuntimeSessionId 'parent-session' -CompletionAction { $script:CompletionCount++ } -TimerFactory $timerFactory -StartFailureMessage 'check-start-failed'
$firstProcess=$state.CheckProcess
$firstTimer=$state.CheckTimer
Assert-UpdateController 'Manual check starts' ([bool]$start.Started)
Assert-UpdateController 'Manual check enters Checking' ([string]$state.Status -eq 'Checking')
Assert-UpdateController 'Manual check owns process' ($null -ne $state.CheckProcess)
Assert-UpdateController 'Manual check starts timer' ([bool]$firstTimer.Started)
Assert-UpdateController 'Manual check emits start diagnostic' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_CHECK_STARTED' -and $_.Success}).Count -eq 1)

$busy=Start-UpdateCheckWorkflow -State $state -Mode 'Popup' -RuntimeSessionId 'parent-session' -CompletionAction { $script:CompletionCount++ } -TimerFactory $timerFactory -StartFailureMessage 'check-start-failed'
Assert-UpdateController 'Busy check is rejected' (-not [bool]$busy.Started -and [string]$busy.Reason -eq 'Busy')
Assert-UpdateController 'Busy check does not start second worker' ($script:CheckStarts -eq 1)

$firstProcess.HasExited=$true
& $firstTimer.Action
Assert-UpdateController 'Exited check worker invokes injected completion' ($script:CompletionCount -eq 1)

$checkPath=[string]$state.CheckResultPath
$script:FakeFiles[$checkPath]=[pscustomobject]@{Success=$true;UpdateAvailable=$true;Manifest=(New-TestManifest);Error='';ErrorCategory='';FailureStage='';ErrorClass='';NetworkStatus=''}
$complete=Complete-UpdateCheckWorkflow -State $state -Mode 'Manual' -NoResultMessage 'no-check-result'
Assert-UpdateController 'Available check completes successfully' ([bool]$complete.Success)
Assert-UpdateController 'Available check reports update' ([bool]$complete.UpdateAvailable)
Assert-UpdateController 'Available check stores validated manifest' ([string]$state.AvailableManifest.Version -eq '0.10.4.0')
Assert-UpdateController 'Available check enters UpdateAvailable' ([string]$state.Status -eq 'UpdateAvailable')
Assert-UpdateController 'Check completion disposes process' ([bool]$firstProcess.Disposed)
Assert-UpdateController 'Check completion stops and disposes timer' ([bool]$firstTimer.Stopped -and [bool]$firstTimer.Disposed)
Assert-UpdateController 'Check result file is removed' ($script:RemovedFiles -contains $checkPath)
Assert-UpdateController 'Manual completion diagnostic is emitted' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_CHECK_COMPLETED' -and $_.Success}).Count -eq 1)

$script:ActiveTimerKind='check'
$popupStart=Start-UpdateCheckWorkflow -State $state -Mode 'Popup' -RuntimeSessionId 'parent-session' -CompletionAction { $script:CompletionCount++ } -TimerFactory $timerFactory -StartFailureMessage 'check-start-failed'
$popupPath=[string]$state.CheckResultPath
$script:FakeFiles[$popupPath]=[pscustomobject]@{Success=$true;UpdateAvailable=$false;Manifest=$null;Error='';ErrorCategory='';FailureStage='';ErrorClass='';NetworkStatus=''}
$popupComplete=Complete-UpdateCheckWorkflow -State $state -Mode 'Popup' -NoResultMessage 'no-check-result'
Assert-UpdateController 'Popup check starts through same controller' ([bool]$popupStart.Started)
Assert-UpdateController 'No-update popup completes successfully' ([bool]$popupComplete.Success -and -not [bool]$popupComplete.UpdateAvailable)
Assert-UpdateController 'No-update popup returns to Idle' ([string]$state.Status -eq 'Idle')
Assert-UpdateController 'No-update popup clears available manifest' ($null -eq $state.AvailableManifest)
Assert-UpdateController 'Popup completion diagnostic is distinct' (@($script:Diagnostics|Where-Object{$_.Event -eq 'POPUP_UPDATE_CHECK_COMPLETED' -and $_.Success}).Count -eq 1)

$script:ActiveTimerKind='check'
[void](Start-UpdateCheckWorkflow -State $state -Mode 'Manual' -RuntimeSessionId 'parent-session' -CompletionAction { } -TimerFactory $timerFactory -StartFailureMessage 'check-start-failed')
$failedPath=[string]$state.CheckResultPath
$script:FakeFiles[$failedPath]=[pscustomobject]@{Success=$false;UpdateAvailable=$false;Manifest=$null;Error='network down';ErrorCategory='network';FailureStage='manifest-download';ErrorClass='System.Net.WebException';NetworkStatus='NameResolutionFailure'}
$failed=Complete-UpdateCheckWorkflow -State $state -Mode 'Manual' -NoResultMessage 'no-check-result'
Assert-UpdateController 'Worker failure returns unsuccessful outcome' (-not [bool]$failed.Success)
Assert-UpdateController 'Worker failure preserves category and stage' ([string]$failed.ErrorCategory -eq 'network' -and [string]$failed.FailureStage -eq 'manifest-download')
Assert-UpdateController 'Worker failure preserves class and network status' ([string]$failed.ErrorClass -eq 'System.Net.WebException' -and [string]$failed.NetworkStatus -eq 'NameResolutionFailure')
Assert-UpdateController 'Worker failure lifecycle returns to Idle' ([string]$state.Status -eq 'Idle')
Assert-UpdateController 'Worker failure result is cleaned' ($script:RemovedFiles -contains $failedPath)

$script:ActiveTimerKind='check'
[void](Start-UpdateCheckWorkflow -State $state -Mode 'Manual' -RuntimeSessionId 'parent-session' -CompletionAction { } -TimerFactory $timerFactory -StartFailureMessage 'check-start-failed')
$missingPath=[string]$state.CheckResultPath
$missing=Complete-UpdateCheckWorkflow -State $state -Mode 'Manual' -NoResultMessage 'no-check-result'
Assert-UpdateController 'Missing check result fails closed' (-not [bool]$missing.Success -and [string]$missing.FailureStage -eq 'check-result')
Assert-UpdateController 'Missing check result is cleaned by ownership path' ($script:RemovedFiles -contains $missingPath)

$manifest=New-TestManifest
[void](Set-UpdateRuntimeAvailable -State $state -Manifest $manifest)
$script:InstallDirectoryWritable=$false
$script:ActiveTimerKind='prepare'
$blockedPrepare=Start-UpdatePrepareWorkflow -State $state -Manifest $manifest -RuntimeSessionId 'parent-session' -CompletionAction { $script:CompletionCount++ } -TimerFactory $timerFactory -StartFailureMessage 'prepare-start-failed'
Assert-UpdateController 'Unwritable install directory blocks prepare' (-not [bool]$blockedPrepare.Started -and [string]$blockedPrepare.Reason -eq 'DirectoryNotWritable')
Assert-UpdateController 'Unwritable directory starts no prepare worker' ($script:PrepareStarts -eq 0)
Assert-UpdateController 'Unwritable directory does not change available state' ([string]$state.Status -eq 'UpdateAvailable')

$script:InstallDirectoryWritable=$true
$prepare=Start-UpdatePrepareWorkflow -State $state -Manifest $manifest -RuntimeSessionId 'parent-session' -CompletionAction { $script:CompletionCount++ } -TimerFactory $timerFactory -StartFailureMessage 'prepare-start-failed'
$prepareProcess=$state.PrepareProcess
$prepareTimer=$state.PrepareTimer
$prepareResultPath=[string]$state.PrepareResultPath
$prepareManifestPath=[string]$state.ManifestPath
Assert-UpdateController 'Prepare starts' ([bool]$prepare.Started)
Assert-UpdateController 'Prepare enters Preparing' ([string]$state.Status -eq 'Preparing')
Assert-UpdateController 'Prepare owns manifest and result paths' ($prepareManifestPath -and $prepareResultPath)
Assert-UpdateController 'Prepare starts process and timer' ($null -ne $prepareProcess -and [bool]$prepareTimer.Started)
Assert-UpdateController 'Prepare start emits diagnostic' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_PREPARE_STARTED' -and $_.Success}).Count -eq 1)
Assert-UpdateController 'Prepare does not auto-start installer helper' ($script:InstallerStarts -eq 0)

$prepareProcess.HasExited=$true
& $prepareTimer.Action
Assert-UpdateController 'Exited prepare worker invokes injected completion' ($script:CompletionCount -eq 2)

$script:FakeFiles[$prepareResultPath]=[pscustomobject]@{Success=$true;WorkDir='work-dir';PayloadDir='payload';ManifestPath='worker-manifest';Version='0.10.4.0';Error='';ErrorCategory='';FailureStage='';ErrorClass='';NetworkStatus=''}
$prepared=Complete-UpdatePrepareWorkflow -State $state -NoResultMessage 'no-prepare-result'
Assert-UpdateController 'Prepared package completes successfully' ([bool]$prepared.Success)
Assert-UpdateController 'Prepared package returns work directory' ([string]$prepared.WorkDir -eq 'work-dir')
Assert-UpdateController 'Prepared package enters ReadyToInstall' ([string]$state.Status -eq 'ReadyToInstall')
Assert-UpdateController 'Prepare completion disposes process' ([bool]$prepareProcess.Disposed)
Assert-UpdateController 'Prepare completion stops and disposes timer' ([bool]$prepareTimer.Stopped -and [bool]$prepareTimer.Disposed)
Assert-UpdateController 'Prepare result and input manifest are cleaned' (($script:RemovedFiles -contains $prepareResultPath) -and ($script:RemovedFiles -contains $prepareManifestPath))
Assert-UpdateController 'Prepared package diagnostic is emitted' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_PACKAGE_PREPARED' -and $_.Success}).Count -eq 1)

$handoff=Start-UpdateInstallerHandoff -State $state -WorkDir $prepared.WorkDir -SourceVersion '0.10.3.0' -FailurePrefix 'failure' -ManualRestartMessage 'restart' -StartFailureMessage 'installer-start-failed'
Assert-UpdateController 'Installer handoff succeeds only when explicitly invoked' ([bool]$handoff.Success)
Assert-UpdateController 'Installer helper starts exactly once at handoff' ($script:InstallerStarts -eq 1)
Assert-UpdateController 'Installer helper process is disposed after handoff' ([bool]$script:LastInstallerProcess.Disposed)
Assert-UpdateController 'Installer handoff diagnostic is emitted' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_INSTALL_HELPER_STARTED' -and $_.Success}).Count -eq 1)

[void](Set-UpdateRuntimeAvailable -State $state -Manifest $manifest)
$script:ActiveTimerKind='prepare'
[void](Start-UpdatePrepareWorkflow -State $state -Manifest $manifest -RuntimeSessionId 'parent-session' -CompletionAction { } -TimerFactory $timerFactory -StartFailureMessage 'prepare-start-failed')
$prepareFailureResultPath=[string]$state.PrepareResultPath
$prepareFailureManifestPath=[string]$state.ManifestPath
$script:FakeFiles[$prepareFailureResultPath]=[pscustomobject]@{Success=$false;WorkDir='';Version='';Error='hash mismatch';ErrorCategory='hash';FailureStage='package-hash';ErrorClass='System.Exception';NetworkStatus=''}
$prepareFailed=Complete-UpdatePrepareWorkflow -State $state -NoResultMessage 'no-prepare-result'
Assert-UpdateController 'Prepare worker failure is unsuccessful' (-not [bool]$prepareFailed.Success)
Assert-UpdateController 'Prepare worker failure preserves classification' ([string]$prepareFailed.ErrorCategory -eq 'hash' -and [string]$prepareFailed.FailureStage -eq 'package-hash')
Assert-UpdateController 'Prepare worker failure returns to Idle' ([string]$state.Status -eq 'Idle')
Assert-UpdateController 'Prepare failure cleans result and manifest files' (($script:RemovedFiles -contains $prepareFailureResultPath) -and ($script:RemovedFiles -contains $prepareFailureManifestPath))

$script:PendingRestartResult=[pscustomobject]@{schemaVersion=1;status='pending-verification';sourceVersion='0.10.2.0';targetVersion='0.10.3.0';utc='2026-10-07T10:00:00Z';message='pending';rollbackAttempted=$false;rollbackSucceeded=$false}
$restart=Get-PendingUpdateRestartWorkflowResult -RunningVersion '0.10.3.0'
Assert-UpdateController 'Pending restart result resolves against running version' ([bool]$restart.Success)
Assert-UpdateController 'Pending restart result is consumed once' ($script:PendingRestartRemoved -eq 1)
Assert-UpdateController 'Pending restart result emits diagnostic' (@($script:Diagnostics|Where-Object{$_.Event -eq 'UPDATE_RESTART_RESULT'}).Count -eq 1)

Write-Host "UPDATE CONTROLLER TOTAL $script:checks/56"
if ($script:checks -ne 56) { throw "Expected 56 update controller checks, got $script:checks" }
