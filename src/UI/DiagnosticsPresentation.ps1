function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.SavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.SavedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.Location' -Values @{ Path=$path }) -Kind Info -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.ShowFolder') -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.NotSavedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.NotSavedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
    }
}

function Start-DiagnosticsUploadFromUi {
    # A deliberate menu click is the only upload trigger. Never call this
    # during startup, refresh, diagnostics export, or error handling.
    if ($script:DiagnosticsUploadState) { return }
    try {
        $installationId = Get-DiagnosticsInstallationId -SettingsDirectory $script:SettingsDir
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-upload'
        $context = Start-DiagnosticsUploadTransport -ZipPath $path -InstallationUuid $installationId
        $script:DiagnosticsUploadState = $context
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $false }
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 180
        $timer.Add_Tick({ Complete-DiagnosticsUploadFromUi })
        $script:DiagnosticsUploadTimer = $timer
        $timer.Start()
        $script:LastStatusText = Get-LocalizedString -Key 'Diagnostics.Uploading'
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_STARTED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ outputName = [IO.Path]::GetFileName($path) })
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level warning
        if ($script:DiagnosticsUploadTimer) {
            try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
            $script:DiagnosticsUploadTimer = $null
        }
        if ($script:DiagnosticsUploadState) { Dispose-DiagnosticsUploadTransport -Context $script:DiagnosticsUploadState; $script:DiagnosticsUploadState = $null }
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $true }
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadFailedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadFailedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.UploadFailedMessage') -Kind Warning
    }
}

function Complete-DiagnosticsUploadFromUi {
    $context = $script:DiagnosticsUploadState
    if (-not $context -or -not $context.Task -or -not $context.Task.IsCompleted) { return }
    $success = $false
    try {
        $response = $context.Task.GetAwaiter().GetResult()
        $success = ($response.IsSuccessStatusCode -and [int]$response.StatusCode -eq 201)
        if (-not $success) {
            Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_HTTP_FAILURE' -Stage 'diagnostics' -Success $false -Level warning -Data (New-RuntimeDiagnosticData @{ statusCode = [int]$response.StatusCode })
        }
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level warning
    }
    finally {
        # Release timer and state before displaying any modal dialog; dialogs
        # pump Windows messages and could otherwise double-complete a request.
        if ($script:DiagnosticsUploadTimer) {
            try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
            $script:DiagnosticsUploadTimer = $null
        }
        $script:DiagnosticsUploadState = $null
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Enabled = $true }
        Dispose-DiagnosticsUploadTransport -Context $context
    }
    if ($success) {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_UPLOAD_COMPLETED' -Stage 'diagnostics' -Success $true
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.UploadedMessage') -Kind Info
    }
    else {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Diagnostics.UploadFailedTitle') -Heading (Get-LocalizedString -Key 'Diagnostics.UploadFailedHeading') -Message (Get-LocalizedString -Key 'Diagnostics.UploadFailedMessage') -Kind Warning
    }
}
