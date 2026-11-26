# LBS-206: an explicit persistent-default change runs in one UNELEVATED
# child process. Only the preinstalled allowlisted SYSTEM tasks may write it.
# WinForms state is mutated only on the main STA / Forms.Timer thread.
function Stop-DefaultTargetChangeWorker {
    param([string]$Reason = 'completed')
    if ($script:DefaultTargetChangeTimer) {
        try { $script:DefaultTargetChangeTimer.Stop(); $script:DefaultTargetChangeTimer.Dispose() } catch { }
        $script:DefaultTargetChangeTimer = $null
    }
    if ($script:DefaultTargetChangeProcess) {
        try {
            $script:DefaultTargetChangeProcess.Refresh()
            if (-not $script:DefaultTargetChangeProcess.HasExited) {
                $script:DefaultTargetChangeProcess.Kill()
                $script:DefaultTargetChangeProcess.WaitForExit(3000) | Out-Null
            }
            $script:DefaultTargetChangeProcess.Dispose()
        }
        catch { }
        $script:DefaultTargetChangeProcess = $null
    }
    foreach ($path in @($script:DefaultTargetChangeResultPath,$script:DefaultTargetChangeProgressPath)) {
        if ($path) { Remove-BackgroundRefreshResultFile -Path ([string]$path) }
    }
    $script:DefaultTargetChangeResultPath = $null
    $script:DefaultTargetChangeProgressPath = $null
    $script:DefaultTargetChangeRequestedGuid = $null
    $script:DefaultTargetChangeOperation = ''
    $script:DefaultTargetChangeStage = ''
    $script:DefaultTargetChangePending = $false
    $script:DefaultTargetChangeWorkerStarted = $false
    $script:DefaultTargetChangeStartedUtc = [datetime]::MinValue
}

function Start-DefaultTargetChange {
    param([AllowNull()][string]$Guid)
    # A pending save is a single immutable intent. No superseding click
    # may create a second SYSTEM task or overlap a one-shot BootNext writer.
    if ($script:DefaultTargetChangePending -or $script:BootNextPendingGuid -or
        $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetDefaultTarget) { return }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if ($Guid -and (-not $normalized -or -not (Get-EntryByGuid $normalized) -or
        -not (Get-TaskBrokerTarget -Guid $normalized))) { return }
    if ([string]$script:DefaultGuid -eq [string]$normalized) { return }
    $script:DefaultTargetChangePending = $true
    $script:DefaultTargetChangeRequestedGuid = if ($normalized) { [string]$normalized } else { $null }
    $script:DefaultTargetChangeOperation = if ($normalized) { 'set' } else { 'clear' }
    $script:DefaultTargetChangeStage = 'saving'
    $script:DefaultTargetChangeStartedUtc = [datetime]::UtcNow
    $script:DefaultTargetChangeWorkerStarted = $false
    $target = if ($normalized) {
        $entry = Get-EntryByGuid $normalized
        if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { $normalized }
    } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
    $script:LastStatusText = Get-LocalizedString -Key 'Default.ChangeSavingFooter' -Values @{ Target = $target }
    try {
        # Render pending BEFORE queuing the child on a later WinForms tick.
        Update-DefaultUi
        Update-RestartTargetUi
        Update-PopupRows
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_PENDING_SHOWN' -Stage 'default' -Success $true -Data (New-RuntimeDiagnosticData @{ operation=$script:DefaultTargetChangeOperation; targetGuid=[string]$normalized })
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 120
        $timer.Add_Tick({ Complete-DefaultTargetChange })
        $script:DefaultTargetChangeTimer = $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_ASYNC_START_FAILED' -Stage 'default' -Success $false -ErrorRecord $_ -Level error
        Stop-DefaultTargetChangeWorker -Reason 'ui-start-failed'
        Update-DefaultUi
        Update-RestartTargetUi
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error
    }
}

function Start-AuthorizedDefaultTargetWorker {
    $requested = [string]$script:DefaultTargetChangeRequestedGuid
    $clear = ($script:DefaultTargetChangeOperation -eq 'clear')
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetDefaultTarget -or
        $script:BootNextPendingGuid -or $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) {
        throw 'Default-target operation is no longer admissible.'
    }
    if (-not $clear -and (-not (Get-EntryByGuid $requested) -or
        -not (Get-TaskBrokerTarget -Guid $requested))) {
        throw 'Default-target operation is not allowlisted.'
    }
    if ($clear -and $requested) { throw 'Clear default cannot have a target.' }
    # The read-only startup refresh must not race a persistent default write.
    if ($script:BackgroundRefreshState -and
        (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
        Stop-BackgroundBootRefreshForMaintenance -Reason 'default-target-change'
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }
    $token = [guid]::NewGuid().ToString('N')
    $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-default-{0}.json" -f $token)
    $progressPath = Join-Path $script:TaskBrokerLocalDir ("runtime-default-{0}.progress" -f $token)
    $process = Start-DefaultTargetWorkerProcess -ScriptPath $script:ScriptPath -Guid $requested -Clear $clear -ResultPath $resultPath -ProgressPath $progressPath -RuntimeSessionId $script:RuntimeSessionId
    $script:DefaultTargetChangeProcess = $process
    $script:DefaultTargetChangeResultPath = $resultPath
    $script:DefaultTargetChangeProgressPath = $progressPath
    Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_WORKER_STARTED' -Stage 'default' -Success $true -Data (New-RuntimeDiagnosticData @{ operation=$script:DefaultTargetChangeOperation; targetGuid=$requested; processId=$process.Id })
}

function Complete-DefaultTargetChange {
    if (-not $script:DefaultTargetChangePending) { return }
    if (-not $script:DefaultTargetChangeWorkerStarted) {
        $script:DefaultTargetChangeWorkerStarted = $true
        try { Start-AuthorizedDefaultTargetWorker }
        catch {
            Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_ASYNC_START_FAILED' -Stage 'default' -Success $false -ErrorRecord $_ -Level error
            Stop-DefaultTargetChangeWorker -Reason 'worker-start-failed'
            Update-DefaultUi
            Update-RestartTargetUi
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error
        }
        return
    }
    if (-not $script:DefaultTargetChangeProcess) { return }
    $process = $script:DefaultTargetChangeProcess
    try { $process.Refresh() } catch { }
    if ($script:DefaultTargetChangeStage -eq 'saving' -and $script:DefaultTargetChangeProgressPath -and
        (Test-Path -LiteralPath $script:DefaultTargetChangeProgressPath -PathType Leaf)) {
        try {
            if ([IO.File]::ReadAllText($script:DefaultTargetChangeProgressPath,[Text.Encoding]::UTF8).Trim() -eq 'verifying') {
                $script:DefaultTargetChangeStage = 'verifying'
                Update-DefaultUi
                Update-RestartTargetUi
                Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_VERIFYING_SHOWN' -Stage 'default' -Success $true
            }
        } catch { }
    }
    $timeout = (([datetime]::UtcNow - $script:DefaultTargetChangeStartedUtc).TotalSeconds -ge 75)
    if (-not $process.HasExited -and -not $timeout) { return }
    $requested = [string]$script:DefaultTargetChangeRequestedGuid
    $operation = [string]$script:DefaultTargetChangeOperation
    $verifiedDefault = $false
    $verifiedNext = $false
    $workerSuccess = $false
    $failure = $null
    $readGuid = $null
    try {
        $result = $null
        if (-not $process.HasExited) { throw 'Default worker timed out.' }
        if (-not $script:DefaultTargetChangeResultPath -or
            -not (Test-Path -LiteralPath $script:DefaultTargetChangeResultPath -PathType Leaf)) {
            throw 'Default worker did not return a result.'
        }
        $result = [IO.File]::ReadAllText($script:DefaultTargetChangeResultPath,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([string]$result.Operation -ne $operation -or
            [string]$result.RequestedGuid -ne $requested) {
            throw 'Default worker result does not match the pending request.'
        }
        $workerSuccess = ($process.ExitCode -eq 0 -and [bool]$result.Success)
        if (-not $workerSuccess) {
            throw ('Default worker did not confirm completion: ' + [string]$result.Error)
        }
    }
    catch { $failure = $_ }
    # This read happens after child process termination on the STA and uses
    # only the SYSTEM-owned file; it does NOT launch a second scheduled task.
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta -or -not [string]$meta.defaultFile) {
            throw 'TaskBroker default-state metadata unavailable.'
        }
        $readGuid = Get-TaskBrokerDefaultTargetGuid
        $verifiedDefault = ([string]$readGuid -eq $requested)
        $script:DefaultGuid = if ($readGuid) { [string]$readGuid } else { $null }
    }
    catch {
        $verifiedDefault = $false
        $failure = $_
    }
    if ($verifiedDefault -and $workerSuccess -and [bool]$result.NextVerified) {
        try {
            $meta = Get-TaskBrokerMetadata
            if (-not $meta -or -not [string]$meta.managerFile) { throw 'Firmware manager cache path unavailable.' }
            # Force-refresh happened INSIDE the worker. The parent reads the
            # newly written SYSTEM snapshot without starting another long task.
            $managerText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
            $state = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
            $workerNext = [string]$result.NextGuid
            $readNext = [string]$state.SelectedGuid
            if ($workerNext -ne $readNext) { throw 'Worker firmware result mismatch.' }
            $script:SelectedGuid = if ($readNext) { $readNext.ToLowerInvariant() } else { $null }
            $script:NextBootFirmwareReadVerified = $true
            $script:SystemStatusNextObservedUtc = if ($result.NextObservedHash -and (Test-SystemStatusObservationMatch $managerText $result.NextObservedHash)) { $result.NextObservedUtc } else { $null }
            $verifiedNext = $true
        }
        catch { $failure = $_ }
    }
    if (-not $verifiedNext) {
        # A default task can succeed while its BootNext side effect remains
        # unreadable. Never keep an old "confirmed" next-boot checkmark.
        $script:SelectedGuid = $null
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusNextObservedUtc = $null
    }
    $outcome = if ($workerSuccess -and $verifiedDefault -and $verifiedNext) { 'complete' }
               elseif ($verifiedDefault) { 'partial' }
               else { 'failed' }
    Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE_ASYNC_COMPLETED' -Stage $outcome -Success ($outcome -eq 'complete') -ErrorRecord $failure -Level $(if ($outcome -eq 'complete') { 'info' } elseif ($outcome -eq 'partial') { 'warning' } else { 'error' }) -Data (New-RuntimeDiagnosticData @{
        operation=$operation; requestedGuid=$requested; observedGuid=[string]$readGuid
        workerSuccess=$workerSuccess; defaultVerified=$verifiedDefault; nextVerified=$verifiedNext
    })
    Stop-DefaultTargetChangeWorker -Reason $outcome
    if ($outcome -eq 'complete') {
        $entry = if ($script:DefaultGuid) { Get-EntryByGuid ([string]$script:DefaultGuid) } else { $null }
        $target = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
        $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemSavedStatus' -Values @{ Name=$target }
    }
    else {
        $script:LastStatusText = if ($outcome -eq 'partial') {
            Get-LocalizedString -Key 'Default.ChangePartial'
        } else { Get-LocalizedString -Key 'Default.SaveErrorHeading' }
    }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-PopupRows
    if ($outcome -ne 'complete') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key $(if ($outcome -eq 'partial') { 'Default.ChangePartialHeading' } else { 'Default.SaveErrorHeading' })) -Message (Get-LocalizedString -Key $(if ($outcome -eq 'partial') { 'Default.ChangePartial' } else { 'Default.SaveErrorMessage' })) -Kind $(if ($outcome -eq 'partial') { 'Warning' } else { 'Error' })
    }
}
