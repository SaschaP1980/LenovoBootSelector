function Show-PendingUpdateResultOnStartup {
    $result = Read-LenovoUpdateResult
    if (-not $result) { return $false }

    $resolved = Resolve-LenovoUpdateRestartResultCore -Result $result -RunningVersion $script:AppVersion

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

    # Consume before showing the modal dialog so this result is shown at most once,
    # even if the process is terminated while the dialog is open.
    Remove-LenovoUpdateResult

    if ($resolved.Success) {
        Show-LenovoNoticeDialog -Title 'Update erfolgreich' -Heading ('Lenovo Boot Selector v{0} ist installiert.' -f $resolved.DisplayVersion) -Message $resolved.Message -Kind Info
    }
    else {
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht erfolgreich aktualisiert werden.' -Message $resolved.Message -Kind Error
    }
    return $true
}

function Update-UpdateMenuState {
    # Automatic read-only checks are triggered by popup-open transitions. There is no periodic polling.
    if (-not $script:UpdateState) { return }
    $busy = Test-UpdateRuntimeBusy -State $script:UpdateState
    if ($script:UpdateCheckMenuItem) { $script:UpdateCheckMenuItem.Enabled = -not $busy }
    if ($script:UpdateInstallMenuItem) {
        $script:UpdateInstallMenuItem.Text = Get-LocalizedString -Key 'Update.Install'
        $script:UpdateInstallMenuItem.Enabled = (-not $busy -and $null -ne $script:UpdateState.AvailableManifest)
    }
}

function Show-AvailableUpdateDialog {
    if (-not $script:UpdateState -or [string]$script:UpdateState.Status -ne 'UpdateAvailable' -or $null -eq $script:UpdateState.AvailableManifest) {
        return $false
    }
    $manifest = $script:UpdateState.AvailableManifest
    Show-LenovoNoticeDialog -Title 'Neue App-Version verfügbar' -Heading ('Lenovo Boot Selector v{0} ist verfügbar.' -f $manifest.Version) -Message 'Du kannst die neue Version jetzt direkt installieren. Später findest du die Aktualisierung im Tray-Menü unter „Wartung“ → „App aktualisieren…“.' -Kind Info -SecondaryButtonText 'Jetzt aktualisieren' -SecondaryAction { Start-ManualAppUpdate }
    return $true
}

function Stop-UpdateCheckUiWorker {
    if ($script:UpdateState.CheckTimer) { try { $script:UpdateState.CheckTimer.Stop() } catch { }; try { $script:UpdateState.CheckTimer.Dispose() } catch { }; $script:UpdateState.CheckTimer=$null }
    if ($script:UpdateState.CheckProcess) { try { $script:UpdateState.CheckProcess.Dispose() } catch { }; $script:UpdateState.CheckProcess=$null }
}


function Complete-UpdateCheck {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)
    Stop-UpdateCheckUiWorker
    $path=[string]$script:UpdateState.CheckResultPath
    $isPopup = ($Mode -eq 'Popup')
    $failureCategory=''; $failureStage=''; $errorClass=''; $networkStatus=''
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { $failureCategory='runtime'; $failureStage='check-result'; throw 'Die Update-Prüfung hat kein Ergebnis geliefert.' }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) {
            $failureCategory=([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage=([string]$result.FailureStage).Trim()
            $errorClass=([string]$result.ErrorClass).Trim()
            $networkStatus=([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }
        if ($result.UpdateAvailable) {
            $validated=Test-LenovoUpdateManifestCore -Manifest $result.Manifest
            if (-not $validated.IsValid) { $failureCategory='manifest'; $failureStage='result-manifest-validation'; throw $validated.Error }
            [void](Set-UpdateRuntimeAvailable -State $script:UpdateState -Manifest $validated)
            $script:LastStatusText = ('Neue App-Version verfügbar: v{0}' -f $validated.Version)
            if (-not $isPopup) {
                [void](Show-AvailableUpdateDialog)
            }
            Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$true; availableVersion=$validated.Version; mode=$Mode })
        }
        else {
            $script:UpdateState.AvailableManifest=$null
            [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
            if (-not $isPopup) {
                $script:LastStatusText = ('Lenovo Boot Selector ist aktuell · v{0}' -f $script:AppVersion)
                Show-LenovoNoticeDialog -Title 'Keine neue Version' -Heading ('Lenovo Boot Selector v{0} ist aktuell.' -f $script:AppVersion) -Message 'Es ist derzeit keine neuere Version verfügbar.' -Kind Info
            }
            Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$false; mode=$Mode })
        }
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        if (-not $isPopup) {
            $script:LastStatusText='Update-Prüfung fehlgeschlagen.'
            Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die Prüfung auf eine neue Version ist fehlgeschlagen.' -Message $_.Exception.Message -Kind Error
        }
        Write-RuntimeDiagnosticEvent -Event $(if ($isPopup) { 'POPUP_UPDATE_CHECK_COMPLETED' } else { 'UPDATE_CHECK_COMPLETED' }) -Stage $(if ($failureStage) { $failureStage } else { 'update-check' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode=$Mode; errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level warning
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.CheckResultPath=$null
        $script:UpdateState.CheckMode=''
        if ($script:UpdateState.Status -eq 'Failed') { [void](Set-UpdateRuntimeIdle -State $script:UpdateState) }
        Update-UpdateMenuState
        Update-HeaderRefreshStatus
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}
function Complete-ManualUpdateCheck {
    Complete-UpdateCheck -Mode 'Manual'
}

function Complete-PopupUpdateCheck {
    Complete-UpdateCheck -Mode 'Popup'
}

function Start-UpdateCheckUiWorker {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)

    if (Test-UpdateRuntimeBusy -State $script:UpdateState) { return $false }
    [void](Set-UpdateRuntimeChecking -State $script:UpdateState)
    $script:UpdateState.CheckMode=$Mode
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateCheck-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $script:UpdateState.CheckResultPath=$resultPath
    try {
        $proc=Start-UpdateCheckWorkerProcess -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw 'Update-Prüfung konnte nicht gestartet werden.' }
        $script:UpdateState.CheckProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.CheckProcess) { return }
                $script:UpdateState.CheckProcess.Refresh()
                if ($script:UpdateState.CheckProcess.HasExited) {
                    if ([string]$script:UpdateState.CheckMode -eq 'Popup') { Complete-PopupUpdateCheck }
                    else { Complete-ManualUpdateCheck }
                }
            }
            catch {
                if ([string]$script:UpdateState.CheckMode -eq 'Popup') { Complete-PopupUpdateCheck }
                else { Complete-ManualUpdateCheck }
            }
        })
        $script:UpdateState.CheckTimer=$timer; $timer.Start()
        return $true
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Stop-UpdateCheckUiWorker
        $script:UpdateState.CheckResultPath=$null
        $script:UpdateState.CheckMode=''
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
        throw
    }
}

function Start-ManualUpdateCheck {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    try {
        if (-not (Start-UpdateCheckUiWorker -Mode 'Manual')) { return }
        $script:LastStatusText='Auf neue Version wird geprüft…'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode='Manual' })
    }
    catch {
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die Prüfung konnte nicht gestartet werden.' -Message $_.Exception.Message -Kind Error
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode='Manual' }) -Level warning
    }
    Update-UpdateMenuState
}

function Start-PopupUpdateCheck {
    if (-not $script:UpdateState -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return $false }
    try {
        if (-not (Start-UpdateCheckUiWorker -Mode 'Popup')) { return $false }
        Write-RuntimeDiagnosticEvent -Event 'POPUP_UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ mode='Popup' })
        Update-UpdateMenuState
        return $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'POPUP_UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode='Popup' }) -Level warning
        Update-UpdateMenuState
        return $false
    }
}

function Stop-UpdatePrepareUiWorker {
    if ($script:UpdateState.PrepareTimer) { try { $script:UpdateState.PrepareTimer.Stop() } catch { }; try { $script:UpdateState.PrepareTimer.Dispose() } catch { }; $script:UpdateState.PrepareTimer=$null }
    if ($script:UpdateState.PrepareProcess) { try { $script:UpdateState.PrepareProcess.Dispose() } catch { }; $script:UpdateState.PrepareProcess=$null }
}

function Exit-TrayForPreparedUpdate {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helper=Start-LenovoUpdateInstallerHelper -WorkDir $WorkDir -SourceVersion $script:AppVersion
    if (-not $helper) { throw 'Update-Installer konnte nicht gestartet werden.' }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_INSTALL_HELPER_STARTED' -Stage 'update-install' -Success $true -Data (New-RuntimeDiagnosticData @{ processId=$helper.Id; version=$script:UpdateState.AvailableManifest.Version })
    try { $helper.Dispose() } catch { }
    $script:ExitRequested=$true
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible=$false } } catch { }
    try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
    [System.Windows.Forms.Application]::ExitThread()
}


function Complete-ManualAppUpdatePrepare {
    Stop-UpdatePrepareUiWorker
    $path=[string]$script:UpdateState.PrepareResultPath
    $failureCategory=''; $failureStage=''; $errorClass=''; $networkStatus=''
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { $failureCategory='runtime'; $failureStage='prepare-result'; throw 'Die Update-Vorbereitung hat kein Ergebnis geliefert.' }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) {
            $failureCategory=([string]$result.ErrorCategory).Trim().ToLowerInvariant()
            $failureStage=([string]$result.FailureStage).Trim()
            $errorClass=([string]$result.ErrorClass).Trim()
            $networkStatus=([string]$result.NetworkStatus).Trim()
            throw ([string]$result.Error)
        }
        [void](Set-UpdateRuntimeReadyToInstall -State $script:UpdateState)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$result.Version })
        Exit-TrayForPreparedUpdate -WorkDir ([string]$result.WorkDir)
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage $(if ($failureStage) { $failureStage } else { 'update-prepare' }) -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ errorCategory=$failureCategory; failureStage=$failureStage; errorClass=$errorClass; networkStatus=$networkStatus }) -Level error
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht aktualisiert werden.' -Message $_.Exception.Message -Kind Error
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        try { if ($script:UpdateState.ManifestPath -and (Test-Path -LiteralPath $script:UpdateState.ManifestPath)) { Remove-Item -LiteralPath $script:UpdateState.ManifestPath -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.PrepareResultPath=$null; $script:UpdateState.ManifestPath=$null
        Update-UpdateMenuState
    }
}
function Start-ManualAppUpdate {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    $manifest=$script:UpdateState.AvailableManifest
    if (-not $manifest) { return }
    if (-not (Test-UpdateInstallDirectoryWritable)) {
        Show-LenovoNoticeDialog -Title 'Update nicht möglich' -Heading 'Der App-Ordner ist nicht beschreibbar.' -Message 'Verschiebe Lenovo Boot Selector in einen Ordner, den dein Benutzerkonto ändern darf, und versuche es erneut.' -Kind Error
        return
    }
    [void](Set-UpdateRuntimePreparing -State $script:UpdateState)
    $manifestPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateManifest-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdatePrepare-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    $script:UpdateState.ManifestPath=$manifestPath; $script:UpdateState.PrepareResultPath=$resultPath
    try {
        $proc=Start-UpdatePrepareWorkerProcess -ManifestPath $manifestPath -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw 'Update-Vorbereitung konnte nicht gestartet werden.' }
        $script:UpdateState.PrepareProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.PrepareProcess) { return }
                $script:UpdateState.PrepareProcess.Refresh()
                if ($script:UpdateState.PrepareProcess.HasExited) { Complete-ManualAppUpdatePrepare }
            } catch { Complete-ManualAppUpdatePrepare }
        })
        $script:UpdateState.PrepareTimer=$timer; $timer.Start()
        $script:LastStatusText=('Update auf v{0} wird vorbereitet…' -f $manifest.Version)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$manifest.Version })
    }
    catch {
        Stop-UpdatePrepareUiWorker
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht aktualisiert werden.' -Message $_.Exception.Message -Kind Error
    }
    Update-UpdateMenuState
}
