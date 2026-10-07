# Update check/prepare application workflow.
# UI owns presentation and user commands; Infrastructure owns transport/process/filesystem/install mechanics.

function Stop-UpdateCheckWorkflow {
    param([Parameter(Mandatory=$true)]$State)

    if ($State.CheckTimer) {
        try { $State.CheckTimer.Stop() } catch { }
        try { $State.CheckTimer.Dispose() } catch { }
        $State.CheckTimer = $null
    }
    if ($State.CheckProcess) {
        try { $State.CheckProcess.Dispose() } catch { }
        $State.CheckProcess = $null
    }
}

function Start-UpdateCheckWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode,
        [AllowNull()][string]$RuntimeSessionId,
        [Parameter(Mandatory=$true)][scriptblock]$CompletionAction,
        [Parameter(Mandatory=$true)][scriptblock]$TimerFactory,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    if (Test-UpdateRuntimeBusy -State $State) {
        return [pscustomobject]@{ Started=$false; Reason='Busy'; Error='' }
    }

    [void](Set-UpdateRuntimeChecking -State $State)
    $State.CheckMode = $Mode
    $resultPath = New-LenovoUpdateCheckResultPath
    $State.CheckResultPath = $resultPath

    try {
        $process = Start-UpdateCheckWorkerProcess -ResultPath $resultPath -RuntimeSessionId $RuntimeSessionId
        if (-not $process) { throw $StartFailureMessage }
        $State.CheckProcess = $process

        $stateForTick = $State
        $completionForTick = $CompletionAction
        $tickAction = {
            try {
                if (-not $stateForTick.CheckProcess) { return }
                $stateForTick.CheckProcess.Refresh()
                if ($stateForTick.CheckProcess.HasExited) { & $completionForTick }
            }
            catch {
                & $completionForTick
            }
        }.GetNewClosure()

        $timer = & $TimerFactory $tickAction
        if (-not $timer) { throw $StartFailureMessage }
        $State.CheckTimer = $timer
        $timer.Start()

        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_STARTED' } else { 'UPDATE_CHECK_STARTED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode=$Mode })
        return [pscustomobject]@{ Started=$true; Reason='Started'; Error='' }
    }
    catch {
        $errorMessage = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $errorMessage)
        Stop-UpdateCheckWorkflow -State $State
        Remove-LenovoUpdateWorkflowFile -Path $resultPath
        $State.CheckResultPath = $null
        $State.CheckMode = ''
        [void](Set-UpdateRuntimeIdle -State $State)
        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_STARTED' } else { 'UPDATE_CHECK_STARTED' }) -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode }) -Level warning
        return [pscustomobject]@{ Started=$false; Reason='StartFailed'; Error=$errorMessage }
    }
}

function Complete-UpdateCheckWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode,
        [Parameter(Mandatory=$true)][string]$NoResultMessage
    )

    Stop-UpdateCheckWorkflow -State $State
    $path = [string]$State.CheckResultPath
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $networkStatus = ''
    $outcome = [ordered]@{
        Success = $false
        Mode = $Mode
        UpdateAvailable = $false
        Manifest = $null
        Error = ''
        ErrorCategory = ''
        FailureStage = ''
        ErrorClass = ''
        NetworkStatus = ''
    }

    try {
        $result = Read-LenovoUpdateWorkerResult -Path $path
        if ($null -eq $result) {
            $failureCategory = 'runtime'
            $failureStage = 'check-result'
            throw $NoResultMessage
        }
        if (-not [bool]$result.Success) {
            $failureCategory = ([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage = ([string]$result.FailureStage).Trim()
            $errorClass = ([string]$result.ErrorClass).Trim()
            $networkStatus = ([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }

        if ([bool]$result.UpdateAvailable) {
            $validated = Test-LenovoUpdateManifestCore -Manifest $result.Manifest
            if (-not $validated.IsValid) {
                $failureCategory = 'manifest'
                $failureStage = 'result-manifest-validation'
                throw $validated.Error
            }
            [void](Set-UpdateRuntimeAvailable -State $State -Manifest $validated)
            $outcome.Success = $true
            $outcome.UpdateAvailable = $true
            $outcome.Manifest = $validated
            Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$true; availableVersion=$validated.Version; mode=$Mode })
        }
        else {
            $State.AvailableManifest = $null
            [void](Set-UpdateRuntimeIdle -State $State)
            $outcome.Success = $true
            Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$false; mode=$Mode })
        }
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        $outcome.Error = $message
        $outcome.ErrorCategory = $failureCategory
        $outcome.FailureStage = $failureStage
        $outcome.ErrorClass = $errorClass
        $outcome.NetworkStatus = $networkStatus
        Write-RuntimeDiagnosticEvent -Event $(if ($Mode -eq 'Popup') { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage $(if ($failureStage) { $failureStage } else { 'update-check' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode; errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level warning
    }
    finally {
        Remove-LenovoUpdateWorkflowFile -Path $path
        $State.CheckResultPath = $null
        $State.CheckMode = ''
        if ($State.Status -eq 'Failed') { [void](Set-UpdateRuntimeIdle -State $State) }
    }

    return [pscustomobject]$outcome
}

function Stop-UpdatePrepareWorkflow {
    param([Parameter(Mandatory=$true)]$State)

    if ($State.PrepareTimer) {
        try { $State.PrepareTimer.Stop() } catch { }
        try { $State.PrepareTimer.Dispose() } catch { }
        $State.PrepareTimer = $null
    }
    if ($State.PrepareProcess) {
        try { $State.PrepareProcess.Dispose() } catch { }
        $State.PrepareProcess = $null
    }
}

function Start-UpdatePrepareWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Manifest,
        [AllowNull()][string]$RuntimeSessionId,
        [Parameter(Mandatory=$true)][scriptblock]$CompletionAction,
        [Parameter(Mandatory=$true)][scriptblock]$TimerFactory,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    if (Test-UpdateRuntimeBusy -State $State) {
        return [pscustomobject]@{ Started=$false; Reason='Busy'; Error=''; Version='' }
    }
    if ($null -eq $Manifest) {
        return [pscustomobject]@{ Started=$false; Reason='NoManifest'; Error=''; Version='' }
    }
    if (-not (Test-UpdateInstallDirectoryWritable)) {
        return [pscustomobject]@{ Started=$false; Reason='DirectoryNotWritable'; Error=''; Version=[string]$Manifest.Version }
    }

    [void](Set-UpdateRuntimePreparing -State $State)
    $input = $null
    try {
        $input = New-LenovoUpdatePrepareInput -Manifest $Manifest
        $State.ManifestPath = [string]$input.ManifestPath
        $State.PrepareResultPath = [string]$input.ResultPath

        $process = Start-UpdatePrepareWorkerProcess -ManifestPath $State.ManifestPath -ResultPath $State.PrepareResultPath -RuntimeSessionId $RuntimeSessionId
        if (-not $process) { throw $StartFailureMessage }
        $State.PrepareProcess = $process

        $stateForTick = $State
        $completionForTick = $CompletionAction
        $tickAction = {
            try {
                if (-not $stateForTick.PrepareProcess) { return }
                $stateForTick.PrepareProcess.Refresh()
                if ($stateForTick.PrepareProcess.HasExited) { & $completionForTick }
            }
            catch {
                & $completionForTick
            }
        }.GetNewClosure()

        $timer = & $TimerFactory $tickAction
        if (-not $timer) { throw $StartFailureMessage }
        $State.PrepareTimer = $timer
        $timer.Start()

        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=[string]$Manifest.Version })
        return [pscustomobject]@{ Started=$true; Reason='Started'; Error=''; Version=[string]$Manifest.Version }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Stop-UpdatePrepareWorkflow -State $State
        Remove-LenovoUpdateWorkflowFile -Path ([string]$State.PrepareResultPath)
        Remove-LenovoUpdateWorkflowFile -Path ([string]$State.ManifestPath)
        $State.PrepareResultPath = $null
        $State.ManifestPath = $null
        [void](Set-UpdateRuntimeIdle -State $State)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ version=[string]$Manifest.Version }) -Level warning
        return [pscustomobject]@{ Started=$false; Reason='StartFailed'; Error=$errorMessage; Version=[string]$Manifest.Version }
    }
}

function Complete-UpdatePrepareWorkflow {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][string]$NoResultMessage
    )

    Stop-UpdatePrepareWorkflow -State $State
    $path = [string]$State.PrepareResultPath
    $manifestPath = [string]$State.ManifestPath
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $networkStatus = ''
    $outcome = [ordered]@{
        Success = $false
        WorkDir = ''
        Version = ''
        Error = ''
        ErrorCategory = ''
        FailureStage = ''
        ErrorClass = ''
        NetworkStatus = ''
    }

    try {
        $result = Read-LenovoUpdateWorkerResult -Path $path
        if ($null -eq $result) {
            $failureCategory = 'runtime'
            $failureStage = 'prepare-result'
            throw $NoResultMessage
        }
        if (-not [bool]$result.Success) {
            $failureCategory = ([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage = ([string]$result.FailureStage).Trim()
            $errorClass = ([string]$result.ErrorClass).Trim()
            $networkStatus = ([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }

        [void](Set-UpdateRuntimeReadyToInstall -State $State)
        $outcome.Success = $true
        $outcome.WorkDir = [string]$result.WorkDir
        $outcome.Version = [string]$result.Version
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=[string]$result.Version })
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        $outcome.Error = $message
        $outcome.ErrorCategory = $failureCategory
        $outcome.FailureStage = $failureStage
        $outcome.ErrorClass = $errorClass
        $outcome.NetworkStatus = $networkStatus
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage $(if ($failureStage) { $failureStage } else { 'update-prepare' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level error
        [void](Set-UpdateRuntimeIdle -State $State)
    }
    finally {
        Remove-LenovoUpdateWorkflowFile -Path $path
        Remove-LenovoUpdateWorkflowFile -Path $manifestPath
        $State.PrepareResultPath = $null
        $State.ManifestPath = $null
    }

    return [pscustomobject]$outcome
}

function Start-UpdateInstallerHandoff {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][string]$WorkDir,
        [Parameter(Mandatory=$true)][string]$SourceVersion,
        [Parameter(Mandatory=$true)][string]$FailurePrefix,
        [Parameter(Mandatory=$true)][string]$ManualRestartMessage,
        [Parameter(Mandatory=$true)][string]$StartFailureMessage
    )

    try {
        $helper = Start-LenovoUpdateInstallerHelper -WorkDir $WorkDir -SourceVersion $SourceVersion -FailurePrefix $FailurePrefix -ManualRestartMessage $ManualRestartMessage
        if (-not $helper) { throw $StartFailureMessage }
        $processId = $helper.Id
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_INSTALL_HELPER_STARTED' -Stage 'update-install' -Success $true -Data (New-RuntimeDiagnosticData @{ processId=$processId; version=[string]$State.AvailableManifest.Version })
        try { $helper.Dispose() } catch { }
        return [pscustomobject]@{ Success=$true; Error=''; ProcessId=$processId }
    }
    catch {
        $message = $_.Exception.Message
        [void](Set-UpdateRuntimeFailed -State $State -Message $message)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory='runtime'; failureStage='update-install'; errorClass=$_.Exception.GetType().FullName; networkStatus='' }) -Level error
        [void](Set-UpdateRuntimeIdle -State $State)
        return [pscustomobject]@{ Success=$false; Error=$message; ProcessId=$null }
    }
}

function Get-PendingUpdateRestartWorkflowResult {
    param([Parameter(Mandatory=$true)][string]$RunningVersion)

    $result = Read-LenovoUpdateResult
    if (-not $result) { return $null }

    $resolved = Resolve-LenovoUpdateRestartResultCore -Result $result -RunningVersion $RunningVersion
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_RESTART_RESULT' -Stage 'update-restart' -Success $resolved.Success -Data (New-RuntimeDiagnosticData @{
        resultUtc = $resolved.ResultUtc
        resultStatus = $resolved.ResultStatus
        resultFormat = $resolved.ResultFormat
        legacySuccess = $resolved.LegacySuccess
        sourceVersion = $resolved.SourceVersion
        targetVersion = $resolved.TargetVersion
        runningVersion = $resolved.RunningVersion
        rollbackAttempted = $resolved.RollbackAttempted
        rollbackSucceeded = $resolved.RollbackSucceeded
        failureCategory = $resolved.FailureCategory
        failureStage = $resolved.FailureStage
        errorClass = $resolved.ErrorClass
        resultMessage = $resolved.StoredMessage
    }) -Level $(if ($resolved.Success) { 'info' } else { 'error' })

    Remove-LenovoUpdateResult
    return $resolved
}
