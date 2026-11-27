# LBS-287: one explicit, unelevated restart admission owner. Two independent
# protected readbacks; never use the observed selection as the expected intent.
# Existing background worker/timer infrastructure is reused only while active.

function Test-RestartAdmission {
    if ($script:ExitRequested -or $script:BootNextPendingGuid -or $script:DefaultTargetChangePending -or
        $script:IsManageEntriesMode -or $script:PreferencesUiActive -or $script:ActiveOwnedDialog -or $script:ActiveAuxiliaryPopup -or
        $script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return $false }
    if ($script:BackgroundRefreshState -and (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) { return $false }
    $caps=Get-CurrentSystemFunctionsCapabilities
    return [bool]($caps.CanRestart -and [string]$caps.State -eq 'Ready')
}

function Get-RestartIntentDisplayName {
    param([AllowNull()][string]$Guid)
    if (-not $Guid) { return (Get-LocalizedString -Key 'Boot.DefaultOrder') }
    $entry=Get-EntryByGuid $Guid
    if ($entry) { return [string](Get-EntryDisplayTitle -Entry $entry) }
    return (Get-LocalizedString -Key 'Settings.DefaultTargetUnavailable')
}

function Write-RestartVerificationEvent {
    param($Context,[string]$Outcome,[bool]$Success,$Evidence,[bool]$Dispatched=$false,$Failure=$null)
    Write-RuntimeDiagnosticEvent -Event 'RESTART_VERIFICATION' -Stage ([string]$Context.Stage) -Success $Success -ErrorRecord $Failure -Level $(if ($Success) { 'info' } else { 'warning' }) -Data (New-RuntimeDiagnosticData @{
        requestId=[string]$Context.Id; expectedGuid=[string]$Context.ExpectedGuid
        observedGuid=if ($Evidence) { [string]$Evidence.Guid } else { $null }
        observedUtc=if ($Evidence) { $Evidence.ObservedUtc } else { $null }
        outcome=$Outcome; confirmed=[bool]$Context.Confirmed; dispatched=$Dispatched
    })
}

function Clear-RestartVerificationWorker {
    param($Context)
    if ($Context.Timer) {
        try { $Context.Timer.Stop(); $Context.Timer.Dispose() } catch { Write-Verbose 'Restart timer disposal failed.' }
        $Context.Timer=$null
    }
    if ($Context.Process) {
        try {
            # Never kill a dispatched shutdown command. Only our read-only
            # child may be retired. A started SYSTEM read task may finish later.
            if ($Context.Stage -in @('pre-confirmation','post-confirmation') -and -not $Context.Process.HasExited) { $Context.Process.Kill() }
        } catch { Write-Verbose 'Restart child cleanup failed.' }
        try { $Context.Process.Dispose() } catch { Write-Verbose 'Restart child disposal failed.' }
        $Context.Process=$null
    }
    if ($Context.ResultPath) {
        Remove-BackgroundRefreshResultFile -Path $Context.ResultPath
        $Context.ResultPath=$null
    }
}

function Stop-RestartVerification {
    param([switch]$Shutdown)
    $context=$script:RestartVerification
    if (-not $context) { return }
    Clear-RestartVerificationWorker -Context $context
    $script:RestartVerification=$null
    if (-not $Shutdown) { Update-PopupRows -Reason 'restart-verification'; Update-RestartTargetUi; Update-TaskBrokerUiState -Fast | Out-Null }
}

function Set-RestartObservedState {
    param($Evidence)
    if ($Evidence) {
        $script:SelectedGuid=if ($Evidence.Guid) { [string]$Evidence.Guid } else { $null }
        $script:NextBootFirmwareReadVerified=$true
        $script:SystemStatusNextObservedUtc=$Evidence.ObservedUtc
        $script:ManagerCacheText=$Evidence.ManagerText
        $script:ManagerCacheUtc=$Evidence.ObservedUtc
        $script:SystemStatusManagerObservedHash=$Evidence.ManagerHash
        $script:SystemStatusManagerObservedUtc=$Evidence.ObservedUtc
        $script:FirmwareCacheText=$Evidence.EntriesText
        $script:FirmwareCacheUtc=$Evidence.EntriesUtc
        $script:SystemStatusEntriesObservedHash=$Evidence.EntriesHash
        $script:SystemStatusEntriesObservedUtc=$Evidence.EntriesUtc
    } else {
        $script:SelectedGuid=$null
        $script:NextBootFirmwareReadVerified=$false
        $script:SystemStatusNextObservedUtc=$null
        $script:ManagerCacheText=$null
        $script:ManagerCacheUtc=[datetime]::MinValue
        $script:SystemStatusManagerObservedHash=$null
        $script:SystemStatusManagerObservedUtc=$null
    }
}

function Fail-RestartVerification {
    param($Context,[string]$Outcome,$Evidence=$null,$Failure=$null)
    Write-RestartVerificationEvent -Context $Context -Outcome $Outcome -Success $false -Evidence $Evidence -Failure $Failure
    $message=Get-LocalizedString -Key 'Restart.VerificationFailed'
    if ($Outcome -eq 'mismatch' -and [string]$Context.ExpectedGuid -ne [string]$Evidence.Guid) {
        $message=Get-LocalizedString -Key 'Restart.TargetChanged' -Values @{
            Expected=$Context.TargetName; Observed=(Get-RestartIntentDisplayName -Guid $Evidence.Guid)
        }
    } elseif ($Outcome -eq 'admission-changed') {
        $message=Get-LocalizedString -Key 'Restart.Busy'
    }
    if ($Outcome -eq 'mismatch') { Set-RestartObservedState -Evidence $Evidence }
    elseif ($Outcome -ne 'admission-changed') { Set-RestartObservedState -Evidence $null }
    $script:LastStatusText=Get-LocalizedString -Key 'Restart.BlockedStatus'
    Stop-RestartVerification
    if (-not $script:ExitRequested -and -not $script:ActiveOwnedDialog -and -not $script:ActiveAuxiliaryPopup -and -not $script:PreferencesUiActive) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.BlockedStatus') -Message $message -Kind Warning
    }
}

function Start-RestartVerificationPhase {
    param($Context,[ValidateSet('pre-confirmation','post-confirmation')][string]$Stage)
    $Context.Stage=$Stage
    $Context.Baseline=Get-RestartReadbackBaseline
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }
    $Context.ResultPath=Join-Path $script:TaskBrokerLocalDir ("runtime-restart-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $Context.StartedUtc=[datetime]::UtcNow
    $Context.Process=Start-BackgroundRefreshWorkerProcess -ScriptPath $script:ScriptPath -ResultPath $Context.ResultPath -RefreshStorage $false -RefreshFirmware $true -RuntimeSessionId $script:RuntimeSessionId -VerifyRestart
    $Context.Timer=New-BackgroundRefreshCompletionTimer -TickAction { Complete-RestartVerification }
    $Context.Timer.Start()
}

function Start-VerifiedRestart {
    param([AllowNull()][string]$ExpectedGuid,[bool]$ExpectedVerified)
    if ($script:RestartVerification) { return }
    $context=[pscustomobject]@{
        Id=[guid]::NewGuid().ToString('N');ExpectedGuid=$ExpectedGuid;TargetName=''
        Stage='admission';Confirmed=$false;Baseline=$null;ConfirmedOrder=$null;StartedUtc=[datetime]::MinValue
        Process=$null;Timer=$null;ResultPath=$null;DispatchUtc=$null
    }
    if (-not (Test-RestartAdmission)) {
        Write-RestartVerificationEvent -Context $context -Outcome 'admission-changed' -Success $false
        if (-not $script:ActiveOwnedDialog -and -not $script:ActiveAuxiliaryPopup -and -not $script:PreferencesUiActive) {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.BlockedStatus') -Message (Get-LocalizedString -Key 'Restart.Busy') -Kind Warning
        }
        return
    }
    # Null is a legitimate intent only after a previously verified observation;
    # invalid nonempty GUIDs must not normalize into that absence case.
    $normalized=if ($ExpectedGuid) { Normalize-TaskBrokerGuid -Guid $ExpectedGuid } else { $null }
    if (-not $ExpectedVerified -or -not $script:NextBootFirmwareReadVerified -or
        [string]$ExpectedGuid -ne [string]$script:SelectedGuid -or
        ($ExpectedGuid -and (-not $normalized -or -not (Get-EntryByGuid $normalized) -or -not (Get-TaskBrokerTarget -Guid $normalized)))) {
        Write-RestartVerificationEvent -Context $context -Outcome 'unknown-intent' -Success $false
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.BlockedStatus') -Message (Get-LocalizedString -Key 'Restart.VerificationFailed') -Kind Warning
        return
    }
    $context.ExpectedGuid=$normalized
    $context.TargetName=Get-RestartIntentDisplayName -Guid $normalized
    $script:RestartVerification=$context
    try {
        $context.Stage='pre-confirmation'
        Update-PopupRows -Reason 'restart-verification'
        Update-RestartTargetUi
        Update-TaskBrokerUiState -Fast | Out-Null
        Start-RestartVerificationPhase -Context $context -Stage 'pre-confirmation'
    } catch { Fail-RestartVerification -Context $context -Outcome 'read-failed' -Failure $_ }
}

function Invoke-RestartDispatch {
    # Fixed existing unelevated route; no caller-controlled command or options.
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=Join-Path $env:SystemRoot 'System32\shutdown.exe'
    $psi.Arguments='/r /t 0'
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    $process=[Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Windows restart process could not start.' }
    return $process
}

function Complete-RestartDispatch {
    param($Context)
    # A successful process exit is only acceptance of the request, never proof
    # of a reboot or the subsequent OS. Hold admission until shutdown or a
    # bounded uncertain outcome; do not terminate or reissue the command.
    try {
        if ($Context.Process -and $Context.Process.HasExited) {
            $code=$Context.Process.ExitCode
            $Context.Process.Dispose()
            $Context.Process=$null
            Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'dispatch' -Success ($code -eq 0) -Data (New-RuntimeDiagnosticData @{
                confirmed=$true; targetGuid=$Context.ExpectedGuid; requestId=$Context.Id; dispatched=$true; exitCode=$code
            }) -Level $(if ($code -eq 0) { 'info' } else { 'error' })
            if ($code -ne 0) { throw 'Windows restart command returned failure.' }
            $Context.Stage='requested'
        }
        if (([datetime]::UtcNow-$Context.DispatchUtc).TotalSeconds -ge 30) {
            Write-RestartVerificationEvent -Context $Context -Outcome 'restart-outcome-unconfirmed' -Success $false -Dispatched $true
            Stop-RestartVerification
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.OutcomeUnknown') -Message (Get-LocalizedString -Key 'Restart.OutcomeMessage') -Kind Warning
        }
    } catch {
        Write-RestartVerificationEvent -Context $Context -Outcome 'dispatch-failed' -Success $false -Dispatched $true -Failure $_
        Stop-RestartVerification
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.FailedHeading') -Message (Get-LocalizedString -Key 'Restart.DispatchFailed') -Kind Error
    }
}

function Complete-RestartVerification {
    $context=$script:RestartVerification
    if (-not $context) { return }
    if ($context.Stage -in @('dispatching','requested')) { Complete-RestartDispatch -Context $context; return }
    if ($context.Stage -notin @('pre-confirmation','post-confirmation')) { return }
    $phase=$context.Stage
    $evidence=$null
    try {
        if (-not $context.Process) { throw 'Restart worker missing.' }
        if (([datetime]::UtcNow-$context.StartedUtc).TotalSeconds -ge 45) { throw 'Restart verification timed out.' }
        if (-not $context.Process.HasExited) { return }
        if ($context.Process.ExitCode -ne 0) { throw 'Restart verification worker failed.' }
        if (-not (Test-RestartAdmission) -or -not $script:NextBootFirmwareReadVerified -or [string]$script:SelectedGuid -ne [string]$context.ExpectedGuid) {
            Fail-RestartVerification -Context $context -Outcome 'admission-changed'
            return
        }
        $result=Get-BackgroundRefreshResult -ResultPath $context.ResultPath
        $evidence=Get-RestartReadbackEvidence -Context $context -Result $result
        Clear-RestartVerificationWorker -Context $context
        if ([string]$evidence.Guid -ne [string]$context.ExpectedGuid -or
            ($phase -eq 'post-confirmation' -and -not $context.ExpectedGuid -and $context.ConfirmedOrder -cne ($evidence.DisplayOrder -join '|'))) {
            Fail-RestartVerification -Context $context -Outcome 'mismatch' -Evidence $evidence
            return
        }
        Write-RestartVerificationEvent -Context $context -Outcome 'match' -Success $true -Evidence $evidence
        if ($phase -eq 'pre-confirmation') {
            Set-RestartObservedState -Evidence $evidence
            $context.ConfirmedOrder=$evidence.DisplayOrder -join '|'
            $context.Stage='confirming'
            $choice=Show-LenovoRestartDialog -TargetName $context.TargetName
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) {
                Write-RestartVerificationEvent -Context $context -Outcome 'cancelled' -Success $true -Evidence $evidence
                Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $true -Data (New-RuntimeDiagnosticData @{confirmed=$false;targetGuid=$context.ExpectedGuid;dispatched=$false;requestId=$context.Id})
                Stop-RestartVerification
                return
            }
            $context.Confirmed=$true
            if (-not (Test-RestartAdmission) -or -not $script:NextBootFirmwareReadVerified -or [string]$script:SelectedGuid -ne [string]$context.ExpectedGuid) {
                Fail-RestartVerification -Context $context -Outcome 'admission-changed'
                return
            }
            Start-RestartVerificationPhase -Context $context -Stage 'post-confirmation'
            return
        }
        if (-not $context.Confirmed) { throw 'Final verification lacks confirmation.' }
        if (([datetime]::UtcNow-$evidence.ObservedUtc).TotalSeconds -gt 5 -or (Get-RestartOriginStamp) -cne $evidence.OriginStamp) { throw 'Final evidence changed or expired before dispatch.' }
        # The final evidence is already bound to this attempt and the captured
        # intent. Do not refresh/repaint or ask for another confirmation here.
        $context.Stage='dispatching'
        $context.DispatchUtc=[datetime]::UtcNow
        try {
            $context.Process=Invoke-RestartDispatch
        } catch {
            Write-RestartVerificationEvent -Context $context -Outcome 'dispatch-not-started' -Success $false -Evidence $evidence -Failure $_
            Stop-RestartVerification
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.FailedHeading') -Message (Get-LocalizedString -Key 'Restart.DispatchFailed') -Kind Error
            return
        }
        Write-RestartVerificationEvent -Context $context -Outcome 'restart-requested' -Success $true -Evidence $evidence -Dispatched $true
        $context.Timer=New-BackgroundRefreshCompletionTimer -TickAction { Complete-RestartVerification }
        $context.Timer.Start()
        Update-RestartTargetUi
    } catch {
        if ($script:RestartVerification -and $script:RestartVerification.Id -eq $context.Id) {
            if ($context.Stage -eq 'dispatching') {
                Write-RestartVerificationEvent -Context $context -Outcome 'dispatch-observation-failed' -Success $false -Dispatched $true -Failure $_
                Stop-RestartVerification
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.OutcomeUnknown') -Message (Get-LocalizedString -Key 'Restart.OutcomeMessage') -Kind Warning
            } else { Fail-RestartVerification -Context $context -Outcome 'read-failed' -Failure $_ }
        }
    }
}
