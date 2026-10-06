function Update-HeaderStatusInteractionVisual {
    if (-not $script:HeaderStatusLabel -or $script:HeaderStatusLabel.IsDisposed) { return }
    $interactive = [bool]$script:HeaderUpdateInteractionEnabled
    $highlight = ($interactive -and ([bool]$script:HeaderStatusHovered -or $script:HeaderStatusLabel.Focused))
    $script:HeaderStatusLabel.ForeColor = if ($highlight) { $script:ColorAccent } else { $script:ColorSecondary }
    $script:HeaderStatusLabel.Cursor = if ($interactive) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    $script:HeaderStatusLabel.TabStop = $interactive
}

function Set-HeaderUpdateInteractionState {
    param([Parameter(Mandatory=$true)][bool]$Enabled)
    $script:HeaderUpdateInteractionEnabled = $Enabled
    Update-HeaderStatusInteractionVisual
}

function Update-HeaderRefreshStatus {
    if (Test-MaintenanceBusy) {
        if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) { $script:HeaderTitleLabel.Location = New-Object Drawing.Point(16, 10) }
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
    $showStatus = ($active -or $updateAvailable)

    if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) {
        $script:HeaderTitleLabel.Location = if ($showStatus) {
            New-Object Drawing.Point(16, 10)
        }
        else {
            New-Object Drawing.Point(16, 19)
        }
    }

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($active) {
            Get-LocalizedString -Key 'Header.Refreshing'
        }
        elseif ($updateAvailable) {
            Get-LocalizedString -Key 'Update.Available'
        }
        else {
            ''
        }
        $script:HeaderStatusLabel.Visible = $showStatus
    }
    Set-HeaderUpdateInteractionState -Enabled (-not $active -and $updateAvailable)
}

function Update-RefreshButtonVisual {
    if (-not $script:RefreshButton -or $script:RefreshButton.IsDisposed) {
        Update-HeaderRefreshStatus
        return
    }
    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $script:RefreshButton.Enabled = ((Get-SystemFunctionsPresentationState) -eq 'Ready')
    $script:RefreshButton.ForeColor = if ($active -or $script:RefreshButtonHovered) { $script:ColorAccent } else { $script:ColorSecondary }
    Update-HeaderRefreshStatus
}
