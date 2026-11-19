# LBS-143 follow-up: keep WinForms responsive while the fixed SYSTEM
# BootNext task and authoritative firmware verification execute off-thread.
# All UI state changes occur on the original WinForms message-loop thread.
function Update-BootNextRestartInterlock {
    $pending = [bool]$script:BootNextPendingGuid
    if ($script:RestartButton -and -not $script:RestartButton.IsDisposed) {
        $script:RestartButton.Enabled = -not $pending
    }
    if ($script:RestartTargetLabel -and -not $script:RestartTargetLabel.IsDisposed -and $pending) {
        $entry = Get-EntryByGuid ([string]$script:BootNextPendingGuid)
        $title = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'BootNext.Unknown' }
        $text = Get-LocalizedString -Key 'BootNext.SelectionPendingFooter' -Values @{ Target=$title }
        $script:RestartTargetLabel.Text = $text
        $script:RestartTargetLabel.Enabled = $false
        $script:RestartTargetLabel.TabStop = $false
        $script:RestartTargetLabel.Cursor = [Windows.Forms.Cursors]::Default
        $script:RestartTargetLabel.AccessibleDescription = $text
    }
}

function Stop-BootNextSelectionWorker {
    param([string]$Reason = 'completed')
    if ($script:BootNextSelectionTimer) {
        try { $script:BootNextSelectionTimer.Stop(); $script:BootNextSelectionTimer.Dispose() } catch { }
        $script:BootNextSelectionTimer = $null
    }
    if ($script:BootNextSelectionProcess) {
        try {
            $script:BootNextSelectionProcess.Refresh()
            if (-not $script:BootNextSelectionProcess.HasExited) {
                $script:BootNextSelectionProcess.Kill()
                $script:BootNextSelectionProcess.WaitForExit(3000) | Out-Null
            }
            $script:BootNextSelectionProcess.Dispose()
        } catch { }
        $script:BootNextSelectionProcess = $null
    }
    if ($script:BootNextSelectionResultPath) {
        Remove-BackgroundRefreshResultFile -Path ([string]$script:BootNextSelectionResultPath)
        $script:BootNextSelectionResultPath = $null
    }
    $script:BootNextPendingGuid = $null
    $script:BootNextSelectionDeferred = $false
    $script:BootNextSelectionStartedUtc = [datetime]::MinValue
}

function Start-AuthorizedPendingBootNextWorker {
    $requested = [string]$script:BootNextPendingGuid
    if (-not $requested) { throw 'BootNext request is no longer pending.' }
    # Recheck authorizing facts AFTER cold-start readiness; never run in Checking.
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'Ready' -or -not $capabilities.CanSetBootNext -or
        $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) {
        throw 'TaskBroker is not ready for a BootNext request.'
    }
    $entry = Get-EntryByGuid $requested
    if (-not $entry -or -not (Get-TaskBrokerTarget -Guid $requested)) {
        throw 'Requested BootNext target is no longer available or allowlisted.'
    }
    # Warm Ready requests can safely retire a stale refresh. A deferred cold
    # request never gets here until its readiness-producing worker has finished.
    if ($script:BackgroundRefreshState -and
        (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
        Stop-BackgroundBootRefreshForMaintenance -Reason 'bootnext-selection'
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }
    $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-bootnext-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $process = Start-BootNextSelectionWorkerProcess -ScriptPath $script:ScriptPath -Guid $requested -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
    $script:BootNextSelectionResultPath = $resultPath
    $script:BootNextSelectionProcess = $process
    $script:BootNextSelectionDeferred = $false
    Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_WORKER_STARTED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$requested; processId=$process.Id; admission='ready' })
}

function Fail-DeferredBootNextSelection {
    param([string]$Reason = 'not-ready', [switch]$Timeout)
    $requested = [string]$script:BootNextPendingGuid
    Write-RuntimeDiagnosticEvent -Event $(if ($Timeout) { 'BOOTNEXT_DEFERRED_TIMEOUT' } else { 'BOOTNEXT_DEFERRED_REJECTED' }) -Stage 'bootnext' -Success $false -Level warning -Data (New-RuntimeDiagnosticData @{ guid=$requested; reason=$Reason })
    Stop-BootNextSelectionWorker -Reason $Reason
    $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
    Update-PopupRows
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
}

function Start-BootNextSelection {
    param([Parameter(Mandatory=$true)][string]$Guid)
    if ($script:BootNextPendingGuid) {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_REJECTED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ reason='already-pending' })
        return
    }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $entry = if ($normalized) { Get-EntryByGuid $normalized } else { $null }
    $targetAllowed = [bool]($entry -and $normalized -and (Get-TaskBrokerTarget -Guid $normalized))
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $refreshActive = [bool]($script:BackgroundRefreshState -and (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState))
    $admission = Resolve-BootNextSelectionAdmissionCore -CapabilityState ([string]$capabilities.State) -CanSetBootNext ([bool]$capabilities.CanSetBootNext) -CanUseCachedBootState ([bool]$capabilities.CanUseCachedBootState) -RefreshActive $refreshActive -TargetAllowlisted $targetAllowed
    if ($script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { $admission = 'reject' }
    if ($admission -eq 'reject') {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_REJECTED' -Stage 'bootnext' -Success $false -Data (New-RuntimeDiagnosticData @{ guid=$normalized; state=[string]$capabilities.State; refreshActive=$refreshActive })
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        Update-PopupRows
        return
    }
    $deferred = ($admission -eq 'deferred')
    try {
        $script:BootNextPendingGuid = $normalized
        $script:BootNextSelectionDeferred = $deferred
        $script:BootNextSelectionStartedUtc = [datetime]::UtcNow
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionPending'
        Update-PopupRows
        Update-BootNextRestartInterlock
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_PENDING_SHOWN' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$normalized; deferred=$deferred; state=[string]$capabilities.State })
        if (-not $deferred) {
            Start-AuthorizedPendingBootNextWorker
        }
        else {
            # Never cancel the worker that is establishing first-run readiness.
            Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_CLICK_DEFERRED' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$normalized; state='Checking' })
        }
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 120
        $timer.Add_Tick({ Complete-BootNextSelection })
        $script:BootNextSelectionTimer = $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SELECTION_START_FAILED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
        Stop-BootNextSelectionWorker -Reason 'start-failed'
        $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        Update-PopupRows
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}

function Complete-BootNextSelection {
    if (-not $script:BootNextPendingGuid) { return }
    if ($script:BootNextSelectionDeferred) {
        $elapsed = ([datetime]::UtcNow - $script:BootNextSelectionStartedUtc).TotalSeconds
        if ($elapsed -gt 45) {
            Fail-DeferredBootNextSelection -Reason 'readiness-timeout' -Timeout
            return
        }
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if ([string]$capabilities.State -eq 'Ready' -and $capabilities.CanSetBootNext) {
            try {
                Start-AuthorizedPendingBootNextWorker
            }
            catch {
                Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_DEFERRED_DISPATCH_FAILED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
                Fail-DeferredBootNextSelection -Reason 'authorized-dispatch-failed'
            }
        }
        elseif ([string]$capabilities.State -ne 'Checking' -or
            -not $capabilities.CanUseCachedBootState -or
            -not $script:BackgroundRefreshState -or
            -not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) {
            Fail-DeferredBootNextSelection -Reason ('readiness-' + [string]$capabilities.State)
        }
        return
    }
    if (-not $script:BootNextSelectionProcess) {
        Fail-DeferredBootNextSelection -Reason 'worker-missing'
        return
    }
    $process = $script:BootNextSelectionProcess
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) {
        if (([datetime]::UtcNow - $script:BootNextSelectionStartedUtc).TotalSeconds -lt 75) { return }
    }
    $requested = [string]$script:BootNextPendingGuid
    $verified = $false
    try {
        if (-not $process.HasExited) { throw 'BootNext worker timed out before a verified result.' }
        $path = [string]$script:BootNextSelectionResultPath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw 'BootNext worker produced no completion record.'
        }
        $result = ([IO.File]::ReadAllText($path,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop)
        if ($process.ExitCode -ne 0 -or
            -not (Test-BootNextWorkerResultCore -RequestedGuid $requested -ReturnedGuid ([string]$result.Guid) -Success ([bool]$result.Success))) {
            throw ('BootNext worker failed: ' + [string]$result.Error)
        }
        [void](Refresh-EffectiveNextBootState)
        if ($script:SelectedGuid -ne $requested) {
            throw 'Firmware next-boot target changed after worker verification.'
        }
        $verified = $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SELECTION_COMPLETED' -Stage 'bootnext' -Success $false -ErrorRecord $_ -Level error
        try { [void](Refresh-EffectiveNextBootState) }
        catch { $script:SelectedGuid = $null; $script:NextBootFirmwareReadVerified = $false }
    }
    finally {
        Stop-BootNextSelectionWorker -Reason 'completed'
        if ($verified) {
            $entry = Get-EntryByGuid $requested
            $script:LastStatusText = if ($entry) {
                Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $entry) }
            } else { Get-LocalizedString -Key 'Status.NextBootSet' }
            Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $true -Data (New-RuntimeDiagnosticData @{ guid=$requested; source='async-worker' })
        }
        else {
            $script:LastStatusText = Get-LocalizedString -Key 'BootNext.SelectionFailed'
        }
        Update-PopupRows
    }
    if (-not $verified) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}
