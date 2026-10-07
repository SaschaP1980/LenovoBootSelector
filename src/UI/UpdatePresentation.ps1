function Get-LocalizedUpdateRestartMessage {
    param([Parameter(Mandatory=$true)]$Resolved)

    if ([bool]$Resolved.Success) {
        return (Get-LocalizedString -Key 'Update.RestartSuccessMessage')
    }
    if ([bool]$Resolved.RollbackAttempted -and [bool]$Resolved.RollbackSucceeded) {
        return (Get-LocalizedString -Key 'Update.RestartRollbackMessage')
    }
    if ([string]$Resolved.TargetVersion -and [string]$Resolved.RunningVersion -and ([string]$Resolved.TargetVersion -ne [string]$Resolved.RunningVersion)) {
        return (Get-LocalizedString -Key 'Update.RestartMismatchMessage' -Values @{
            TargetVersion = [string]$Resolved.TargetVersion
            RunningVersion = [string]$Resolved.RunningVersion
        })
    }
    return (Get-LocalizedString -Key 'Update.RestartFailureMessage')
}

function Show-PendingUpdateResultOnStartup {
    $resolved = Get-PendingUpdateRestartWorkflowResult -RunningVersion $script:AppVersion
    if (-not $resolved) { return $false }

    if ($resolved.Success) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.SuccessTitle') -Heading (Get-LocalizedString -Key 'Update.SuccessHeading' -Values @{ Version=$resolved.DisplayVersion }) -Message (Get-LocalizedUpdateRestartMessage -Resolved $resolved) -Kind Info
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.RestartFailureHeading') -Message (Get-LocalizedUpdateRestartMessage -Resolved $resolved) -Kind Error
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
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.Available') -Heading (Get-LocalizedString -Key 'Update.AvailableHeading' -Values @{ Version=$manifest.Version }) -Message (Get-LocalizedString -Key 'Update.AvailableMessage') -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Update.InstallNow') -SecondaryAction { Start-ManualAppUpdate }
    return $true
}

function New-UpdateWorkflowCompletionTimer {
    param([Parameter(Mandatory=$true)][scriptblock]$TickAction)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $timer.Add_Tick($TickAction)
    return $timer
}

function Complete-UpdateCheckPresentation {
    param([Parameter(Mandatory=$true)][ValidateSet('Manual','Popup')][string]$Mode)

    $isPopup = ($Mode -eq 'Popup')
    $outcome = Complete-UpdateCheckWorkflow -State $script:UpdateState -Mode $Mode -NoResultMessage (Get-LocalizedString -Key 'Update.CheckNoResult')
    try {
        if ($outcome.Success) {
            if ($outcome.UpdateAvailable) {
                $script:LastStatusText = Get-LocalizedString -Key 'Update.AvailableStatus' -Values @{ Version=$outcome.Manifest.Version }
                if (-not $isPopup) { [void](Show-AvailableUpdateDialog) }
            }
            elseif (-not $isPopup) {
                $script:LastStatusText = Get-LocalizedString -Key 'Update.CurrentStatus' -Values @{ Version=$script:AppVersion }
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NoNewTitle') -Heading (Get-LocalizedString -Key 'Update.CurrentHeading' -Values @{ Version=$script:AppVersion }) -Message (Get-LocalizedString -Key 'Update.NoNewMessage') -Kind Info
            }
        }
        elseif (-not $isPopup) {
            $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckFailedStatus'
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckFailedHeading') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
        }
    }
    finally {
        Update-UpdateMenuState
        Update-HeaderRefreshStatus
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
    return $outcome
}

function Complete-ManualUpdateCheck {
    return (Complete-UpdateCheckPresentation -Mode 'Manual')
}

function Complete-PopupUpdateCheck {
    return (Complete-UpdateCheckPresentation -Mode 'Popup')
}

function Start-ManualUpdateCheck {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdateCheckWorkflow -State $script:UpdateState -Mode 'Manual' -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-ManualUpdateCheck } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.CheckStartFailed')
    if ($started.Started) {
        $script:LastStatusText = Get-LocalizedString -Key 'Update.CheckingStatus'
    }
    elseif ($started.Reason -eq 'StartFailed') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.CheckStartFailed') -Message (Get-LocalizedString -Key 'Update.CheckFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
}

function Start-PopupUpdateCheck {
    if (-not $script:UpdateState -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return $false }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdateCheckWorkflow -State $script:UpdateState -Mode 'Popup' -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-PopupUpdateCheck } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.CheckStartFailed')
    Update-UpdateMenuState
    return [bool]$started.Started
}

function Exit-TrayForPreparedUpdate {
    $script:ExitRequested = $true
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible = $false } } catch { }
    try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
    [System.Windows.Forms.Application]::ExitThread()
}

function Complete-ManualAppUpdatePrepare {
    $outcome = Complete-UpdatePrepareWorkflow -State $script:UpdateState -NoResultMessage (Get-LocalizedString -Key 'Update.PrepareNoResult')
    if ($outcome.Success) {
        $handoff = Start-UpdateInstallerHandoff -State $script:UpdateState -WorkDir $outcome.WorkDir -SourceVersion $script:AppVersion -FailurePrefix (Get-LocalizedString -Key 'Update.HelperFailurePrefix') -ManualRestartMessage (Get-LocalizedString -Key 'Update.HelperManualRestart') -StartFailureMessage (Get-LocalizedString -Key 'Update.InstallerStartFailed')
        if ($handoff.Success) {
            Exit-TrayForPreparedUpdate
        }
        else {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
        }
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
    return $outcome
}

function Start-ManualAppUpdate {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    $manifest = $script:UpdateState.AvailableManifest
    if (-not $manifest) { return }

    $timerFactory = {
        param([scriptblock]$TickAction)
        New-UpdateWorkflowCompletionTimer -TickAction $TickAction
    }
    $started = Start-UpdatePrepareWorkflow -State $script:UpdateState -Manifest $manifest -RuntimeSessionId $script:RuntimeSessionId -CompletionAction { Complete-ManualAppUpdatePrepare } -TimerFactory $timerFactory -StartFailureMessage (Get-LocalizedString -Key 'Update.PrepareStartFailed')
    if ($started.Started) {
        $script:LastStatusText = Get-LocalizedString -Key 'Update.PreparingStatus' -Values @{ Version=$manifest.Version }
    }
    elseif ($started.Reason -eq 'DirectoryNotWritable') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.NotPossibleTitle') -Heading (Get-LocalizedString -Key 'Update.DirectoryNotWritableHeading') -Message (Get-LocalizedString -Key 'Update.DirectoryNotWritableMessage') -Kind Error
    }
    elseif ($started.Reason -eq 'StartFailed') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.FailureTitle') -Heading (Get-LocalizedString -Key 'Update.PrepareFailedHeading') -Message (Get-LocalizedString -Key 'Update.PrepareFailureMessage') -Kind Error
    }
    Update-UpdateMenuState
}
