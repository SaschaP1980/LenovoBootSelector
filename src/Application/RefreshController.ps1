# Background-refresh lifecycle orchestration.
# Infrastructure owns worker/IO mechanics; UI owns presentation/timer construction.

function Get-BackgroundRefreshResult {
    param([Parameter(Mandatory=$true)][string]$ResultPath)
    $text = Read-BackgroundRefreshResultText -Path $ResultPath
    return (ConvertFrom-BackgroundRefreshResultText -Text $text)
}

function Apply-BackgroundRefreshResult {
    param(
        [Parameter(Mandatory=$true)]$Result,
        [Parameter(Mandatory=$true)]$Request
    )

    $requestedStorage = [bool]$Request.RefreshStorage
    if (-not $Result.Success) {
        if (Test-MaintenanceBusy) {
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_RESULT_IGNORED' -Stage 'maintenance' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); workerStage = [string]$Result.Stage; workerError = [string]$Result.Error })
            return $false
        }
        if ([string]$Result.Stage -eq 'ready') {
            $script:TaskBrokerReadyCached = $false
            $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
            if (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
            Update-TaskBrokerUiState -Fast | Out-Null
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'ready' -Success $false -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ workerError = [string]$Result.Error }) -Level error
            if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
            return $false
        }
        throw ("Hintergrund-Refresh ({0}) fehlgeschlagen: {1}" -f ([string]$Result.Stage), ([string]$Result.Error))
    }

    $script:TaskBrokerReadyCached = $true
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    Set-BackgroundRefreshLastTiming -State $script:BackgroundRefreshState -Timing $Result.Timings
    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ requestedStorage = $requestedStorage; readyMs = $Result.Timings.ReadyMs; managerMs = $Result.Timings.ManagerMs; firmwareMs = $Result.Timings.FirmwareMs; storageMs = $Result.Timings.StorageMs })

    [void](Sync-TaskBrokerFirmwareCachesFromFiles)
    [void](Update-BootTargetDriftState)

    if ($requestedStorage -and $Result.StorageContext) {
        $script:StorageContext = $Result.StorageContext
    }

    $state = Get-FirmwareBootState -UseExistingCache
    Apply-FirmwareBootState -State $state
    Update-TaskBrokerUiState -Fast | Out-Null
    Show-BootTargetDriftNotificationIfNeeded
    return $true
}

function Stop-BackgroundBootRefreshForMaintenance {
    param([Parameter(Mandatory=$true)][string]$Reason)
    if (-not $script:BackgroundRefreshState) { return }

    $context = $null
    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    }
    [void](Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState)
    if ($context) {
        if ($context.Timer) {
            try { $context.Timer.Stop() } catch { }
            try { $context.Timer.Dispose() } catch { }
        }
        if ($context.Process) {
            try {
                $context.Process.Refresh()
                if (-not $context.Process.HasExited) { $context.Process.Kill() }
            } catch { }
        }
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_CANCELLED_FOR_MAINTENANCE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason })
    }
    Update-RefreshButtonVisual
}

function Complete-BackgroundBootRefresh {
    if (Test-MaintenanceBusy) {
        Stop-BackgroundBootRefreshForMaintenance -Reason (Get-MaintenanceMode)
        return
    }
    if (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) { return }

    $process = $script:BackgroundRefreshState.Process
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) { return }

    $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    if (-not $context) { return }

    if ($context.Timer) {
        try { $context.Timer.Stop() } catch { }
        try { $context.Timer.Dispose() } catch { }
    }
    Update-RefreshButtonVisual

    $continuePending = $true
    try {
        $result = Get-BackgroundRefreshResult -ResultPath ([string]$context.ResultPath)
        $continuePending = Apply-BackgroundRefreshResult -Result $result -Request $context.Request
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ requestedStorage = [bool]$context.Request.RefreshStorage }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
    finally {
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
    }

    if (-not $continuePending) { return }

    $pending = Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState
    if ($pending) {
        if ($pending.RefreshFirmware) { $script:FirmwareCacheUtc = [datetime]::MinValue }
        $pendingStorage = [bool]$pending.RefreshStorage
        Start-BackgroundBootRefresh -RefreshStorage:$pendingStorage
    }
}

function Start-BackgroundBootRefresh {
    param([switch]$RefreshStorage)

    if (Test-MaintenanceBusy) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_SUPPRESSED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); refreshStorage = [bool]$RefreshStorage })
        return
    }

    $refreshFirmware = Test-BackgroundRefreshNeedsFirmware `
        -RefreshStorage ([bool]$RefreshStorage) `
        -FirmwareCacheText $script:FirmwareCacheText `
        -FirmwareCacheUtc $script:FirmwareCacheUtc
    $request = New-BackgroundRefreshRequest -RefreshStorage ([bool]$RefreshStorage) -RefreshFirmware ([bool]$refreshFirmware)

    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        try {
            $script:BackgroundRefreshState.Process.Refresh()
            if (-not $script:BackgroundRefreshState.Process.HasExited) {
                # Popup opens while startup refresh is active must not queue a duplicate.
                # Only a request that adds storage or firmware work is coalesced as pending.
                if (Test-BackgroundRefreshRequestEscalation -ActiveRequest $script:BackgroundRefreshState.ActiveRequest -Requested $request) {
                    [void](Add-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState -Request $request)
                }
                return
            }
        }
        catch { }
        Complete-BackgroundBootRefresh
    }

    if (-not $script:ScriptPath -or -not (Test-Path -LiteralPath $script:ScriptPath)) { return }
    if (-not (Get-TaskBrokerInteractiveReady)) { return }

    try {
        if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir)) {
            New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force | Out-Null
        }
        $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-refresh-{0}.json" -f ([guid]::NewGuid().ToString('N')))
        $process = Start-BackgroundRefreshWorkerProcess `
            -ScriptPath $script:ScriptPath `
            -ResultPath $resultPath `
            -RefreshStorage ([bool]$request.RefreshStorage) `
            -RefreshFirmware ([bool]$request.RefreshFirmware) `
            -RuntimeSessionId $script:RuntimeSessionId

        Set-BackgroundRefreshActive -State $script:BackgroundRefreshState -Process $process -ResultPath $resultPath -Request $request
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $process.Id; refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware })
        Update-RefreshButtonVisual

        $timer = New-BackgroundRefreshCompletionTimer -TickAction { Complete-BackgroundBootRefresh }
        Set-BackgroundRefreshTimer -State $script:BackgroundRefreshState -Timer $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.RefreshStartFailed'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}
