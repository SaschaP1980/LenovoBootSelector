function Update-HeaderStatusInteractionVisual {
    if (-not $script:HeaderStatusLabel -or $script:HeaderStatusLabel.IsDisposed) { return }
    $interactive = [bool]$script:HeaderUpdateInteractionEnabled
    $highlight = ($interactive -and [bool]$script:HeaderStatusHovered)
    $script:HeaderStatusLabel.ForeColor = if ($highlight -and -not [Windows.Forms.SystemInformation]::HighContrast) { [LenovoInteractionPalette]::Hover } else { $script:ColorSecondary }
    $script:HeaderStatusLabel.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    $script:HeaderStatusLabel.TabStop = $interactive
}

function Set-HeaderUpdateInteractionState {
    param([Parameter(Mandatory=$true)][bool]$Enabled)
    $script:HeaderUpdateInteractionEnabled = $Enabled
    Update-HeaderStatusInteractionVisual
}

function Update-HeaderRefreshStatus {
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $script:SystemStatusCapabilities = $capabilities
    if ([string]$capabilities.State -eq 'Busy') {
        if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
            $script:HeaderStatusLabel.Text = Get-MaintenanceBusyStatusText
            $script:HeaderStatusLabel.Visible = $true
        }
        Set-HeaderUpdateInteractionState -Enabled $false
        return
    }

    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $updateAvailable = $false
    try {
        $updateAvailable = ($script:UpdateState -and [string]$script:UpdateState.Status -eq 'UpdateAvailable' -and $null -ne $script:UpdateState.AvailableManifest)
    } catch { }
    # Active request provenance affects presentation only, never worker admission.
    # Initial readiness wins until it ends; a deliberate manual refresh wins
    # over coexisting read-only popup checks. Popup work can outlive boot work.
    $origin = if ($active) { [string]$script:BackgroundRefreshState.ActiveRequest.Origin } else { '' }
    $pendingOrigin = if ($active) { [string]$script:BackgroundRefreshState.PendingRequest.Origin } else { '' }
    $popupUpdateActive = ($script:UpdateState -and $script:UpdateState.CheckProcess -and [string]$script:UpdateState.CheckMode -eq 'Popup')
    $refreshKey = if ($active -and $origin -eq 'Startup') { 'Header.InitializingApplication' }
        elseif ($active -and ($origin -eq 'Manual' -or $pendingOrigin -eq 'Manual')) { 'Header.Refreshing' }
        elseif (($active -and ($origin -eq 'Popup' -or $pendingOrigin -eq 'Popup')) -or $popupUpdateActive) { 'Header.RefreshingApplication' }
        elseif ($active) { 'Header.Refreshing' }
        else { '' }
    $refreshVisible = -not [string]::IsNullOrEmpty($refreshKey)
    $showStatus = ($refreshVisible -or $updateAvailable)

    # LBS-174: status may appear/disappear, but title geometry belongs only
    # to Add-PopupHeaderSection and must not be mutated by refresh state.

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($refreshVisible) {
            if ($refreshKey -eq 'Header.Refreshing') { Get-LocalizedString -Key 'Header.Refreshing' }
            else { Get-LocalizedString -Key $refreshKey }
        }
        elseif ($updateAvailable) {
            Get-LocalizedString -Key 'Update.Available'
        }
        else {
            ''
        }
        $script:HeaderStatusLabel.Visible = $showStatus
    }
    Set-HeaderUpdateInteractionState -Enabled (-not $refreshVisible -and $updateAvailable)
}

function Update-RefreshButtonVisual {
    if (-not $script:RefreshButton -or $script:RefreshButton.IsDisposed) {
        Update-HeaderRefreshStatus
        return
    }
    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $script:RefreshButton.Enabled = [bool]$capabilities.CanRefresh
    $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
    # Initialization is not an available Refresh action. Keep its legible
    # disabled glyph distinct from a genuinely running available refresh.
    $script:RefreshButton.OperationActive = ($active -and $script:RefreshButton.Enabled)
    $script:RefreshButton.ForeColor = if ($script:RefreshButton.OperationActive) { [LenovoInteractionPalette]::Active } elseif (-not $script:RefreshButton.Enabled) { [LenovoInteractionPalette]::Disabled } elseif ($script:RefreshButtonHovered -and -not [Windows.Forms.SystemInformation]::HighContrast) { [LenovoInteractionPalette]::Hover } else { [LenovoInteractionPalette]::Normal }
    $script:RefreshButton.Invalidate()
    Update-HeaderRefreshStatus
}

function New-BackgroundRefreshCompletionTimer {
    param([Parameter(Mandatory=$true)][scriptblock]$TickAction)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 100
    $timer.Add_Tick($TickAction)
    return $timer
}
