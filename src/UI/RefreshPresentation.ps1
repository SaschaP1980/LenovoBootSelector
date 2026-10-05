function Update-HeaderRefreshStatus {
    if (Test-MaintenanceBusy) {
        if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) { $script:HeaderTitleLabel.Location = New-Object Drawing.Point(16, 10) }
        if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
            $script:HeaderStatusLabel.Text = Get-MaintenanceBusyStatusText
            $script:HeaderStatusLabel.Visible = $true
        }
        return
    }

    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }

    if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) {
        $script:HeaderTitleLabel.Location = if ($active) {
            New-Object Drawing.Point(16, 10)
        }
        else {
            New-Object Drawing.Point(16, 19)
        }
    }

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($active) { 'Aktualisiere Bootziele…' } else { '' }
        $script:HeaderStatusLabel.Visible = $active
    }
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
