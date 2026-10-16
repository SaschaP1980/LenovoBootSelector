function New-PopupForm {
    if (-not $script:BootTypeToolTip) {
        $script:BootTypeToolTip = New-Object System.Windows.Forms.ToolTip
        $script:BootTypeToolTip.InitialDelay = 350
        $script:BootTypeToolTip.ReshowDelay = 100
        $script:BootTypeToolTip.AutoPopDelay = 8000
        $script:BootTypeToolTip.ShowAlways = $true
        $script:BootTypeToolTip.UseAnimation = $true
        $script:BootTypeToolTip.UseFading = $true
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Name = 'LenovoBootSelectorPopup'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    # v0.2.28: plain square utility panel, intentionally without an outer
    # Lenovo-red frame or rounded clipping. Red remains an interaction accent.
    $form.BackColor = $script:ColorBackground
    $form.Width = 390
    $form.Height = 672

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'PopupRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(390, 672)
    $root.BackColor = $script:ColorBackground
    $form.Controls.Add($root)

    Add-PopupHeaderSection -Root $root
    Add-PopupBootEntryListSection -Root $root
    Add-PopupSettingsSection -Root $root
    Add-PopupRestartSection -Root $root
    Add-PopupManageEntriesSection -Root $root
    $maintenancePanel = New-MaintenanceStatePanel
    $root.Controls.Add($maintenancePanel)

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_Deactivate({
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if (-not $script:ExitRequested -and [string]$capabilities.State -ne 'Busy') { $this.Hide() }
    })

    return $form
}
function Position-Popup {
    param([switch]$FromTrayClick)
    if (-not $script:Popup) { return }

    $hasClick = $false
    $clickPoint = [Drawing.Point]::Empty
    if ($FromTrayClick -and $null -ne $script:TrayPopupClickUtc -and
        ([DateTime]::UtcNow - $script:TrayPopupClickUtc).TotalSeconds -le 30) {
        $clickPoint = $script:TrayPopupClickPoint
        $hasClick = $true
    }

    $iconRect = Get-VisiblePopupTrayIconRectangle -ClickPoint $clickPoint -HasClickPoint:$hasClick
    if ($null -ne $iconRect) {
        $screen = [System.Windows.Forms.Screen]::FromRectangle($iconRect)
    }
    elseif ($hasClick) {
        $screen = [System.Windows.Forms.Screen]::FromPoint($clickPoint)
        # Only a genuine recent NotifyIcon click may supply this approximate anchor.
        $iconRect = [Drawing.Rectangle]::new($clickPoint.X - 12, $clickPoint.Y - 12, 24, 24)
    }
    else {
        # Non-pointer/first-run fallback: deterministic primary display, never cursor.
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    if ($null -eq $screen) { return }
    $location = Get-PopupLocationFromAnchor -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds -AnchorRect $iconRect -PopupSize $script:Popup.Size -HasAnchor:($null -ne $iconRect)
    $script:Popup.Location = $location
}

function Show-OrTogglePopup {
    param([switch]$FromTrayClick)
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $script:Popup = New-PopupForm
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $maintenanceBusy = ([string]$capabilities.State -eq 'Busy')
    $canUseSystemState = [bool]$capabilities.CanUseCachedBootState
    if ($canUseSystemState) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if ([string]$capabilities.State -eq 'ReinitializeRequired') {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { Get-LocalizedString -Key 'Status.NewBootTargetDetected' } else { Get-LocalizedString -Key 'Status.BootTargetsChanged' }
            }
            elseif ([string]$capabilities.State -eq 'SetupRequired') {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup -FromTrayClick:$FromTrayClick
    $script:Popup.Show()
    $script:Popup.Activate()

    # LBS-21: opening the visible UI is the automatic read-only update-check trigger.
    # The update worker has its own busy gate and can overlap the independent boot-target worker.
    [void](Start-PopupUpdateCheck)

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($canUseSystemState -and -not $maintenanceBusy) {
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext)
    }
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}

