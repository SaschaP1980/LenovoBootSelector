# Escape belongs to this visible popup only. Child-local cancellation (alias editor,
# default-target menu and active drag) must run before any parent dismissal.
function Invoke-PopupEscapeDismissal {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.KeyEventArgs]$EventArgs
    )
    if (-not $Form -or -not $EventArgs -or
        $EventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Escape -or
        $EventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None) { return }
    if (-not $Form.Visible -or -not $Form.ContainsFocus) { return }

    # Owned auxiliary forms and OLE drag have independent Escape/cleanup lifecycles.
    if ($script:ActiveAuxiliaryPopup) { return }
    if ($script:ManageActiveDragGuid -or $script:ManageDragLayout) { return }

    $aliasEditor = $Form.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($aliasEditor -and -not $aliasEditor.IsDisposed -and $aliasEditor.ContainsFocus) { return }

    # Presentation-only: keep the Form, tray owner, workers and Manage draft alive.
    $EventArgs.Handled = $true
    $EventArgs.SuppressKeyPress = $true
    $Form.Hide()
}

function New-PopupForm {
    param([double]$TargetScale = 1.0, [string]$ScaleSource = 'initial')
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
    $form.KeyPreview = $true
    Initialize-PopupDpiLayout -Form $form
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

    # Scale the entire static control tree in one WinForms DPI pass.
    Complete-PopupDpiLayout -Form $form -Scale $TargetScale
    Write-PopupDpiLayoutDiagnostic -Form $form -Phase 'constructed' -MonitorSource $ScaleSource
    $form.Add_Shown({
        Write-PopupDpiLayoutDiagnostic -Form $this -Phase 'shown' -MonitorSource 'active-screen'
    })

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_KeyDown({
        param($sender, $eventArgs)
        Invoke-PopupEscapeDismissal -Form $sender -EventArgs $eventArgs
    })

    $form.Add_Deactivate({
        # The owned auxiliary Form is part of this popup's UI. The
        # ownership flag covers Deactivate before the child becomes visible.
        if ($script:ActiveAuxiliaryPopup) { return }
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
    $monitorScale = Get-LenovoUiCoordinateScale -Screen $screen
    $monitorChanged = Set-PopupDpiLayoutScale -Form $script:Popup -Scale ([double]$monitorScale.Factor)
    $viewportChanged = Set-PopupViewportForWorkingArea -Form $script:Popup -WorkingArea $screen.WorkingArea
    if ($monitorChanged -or $viewportChanged) { Update-PopupRows -Reason $(if ($monitorChanged) { 'dpi-changed' } else { 'viewport-changed' }) }
    Write-PopupDpiLayoutDiagnostic -Form $script:Popup -Phase 'positioned' -MonitorSource ([string]$monitorScale.Source)
    $location = Get-PopupLocationFromAnchor -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds -AnchorRect $iconRect -PopupSize $script:Popup.Size -HasAnchor:($null -ne $iconRect)
    $script:Popup.Location = $location
}

function Show-OrTogglePopup {
    param([switch]$FromTrayClick)
    if ($script:ActiveAuxiliaryPopup -and -not $script:ActiveAuxiliaryPopup.IsDisposed) {
        [void]$script:ActiveAuxiliaryPopup.Activate()
        return
    }
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $initialScreen = [System.Windows.Forms.Screen]::PrimaryScreen
        $initialScale = Get-LenovoUiCoordinateScale -Screen $initialScreen
        $script:Popup = New-PopupForm -TargetScale ([double]$initialScale.Factor) -ScaleSource ([string]$initialScale.Source)
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
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext) -Origin Popup
    }
}

# Explicit launcher re-entry is SHOW, never the tray-icon toggle (which hides
# an already visible popup). This runs on the existing WinForms UI thread.
function Show-OrActivatePopup {
    if ($script:ActiveAuxiliaryPopup -and -not $script:ActiveAuxiliaryPopup.IsDisposed) {
        [void]$script:ActiveAuxiliaryPopup.Activate()
        return
    }
    if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) {
        [void]$script:Popup.Activate()
        return
    }
    Show-OrTogglePopup
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}

# Auxiliary forms are built at 96-DPI design bounds, then scaled once using
# the same effective coordinate factor as the main popup. Keep font points
# and the main popup's immutable metrics independent.
function Set-AuxiliaryControlBounds {
    param([System.Windows.Forms.Control]$Control,[double]$Scale)
    $Control.SuspendLayout()
    try {
        if ($Control -is [System.Windows.Forms.Form]) {
            $Control.ClientSize = [Drawing.Size]::new([int][Math]::Round($Control.ClientSize.Width*$Scale),[int][Math]::Round($Control.ClientSize.Height*$Scale))
        }
        else {
            $b = $Control.Bounds
            $Control.Bounds = [Drawing.Rectangle]::new([int][Math]::Round($b.X*$Scale),[int][Math]::Round($b.Y*$Scale),[int][Math]::Round($b.Width*$Scale),[int][Math]::Round($b.Height*$Scale))
        }
        foreach ($child in $Control.Controls) { Set-AuxiliaryControlBounds -Control $child -Scale $Scale }
    }
    finally { $Control.ResumeLayout($false) }
}

function Set-AuxiliaryPopupLayout {
    param([System.Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea,[Drawing.Rectangle]$OwnerBounds,[Drawing.Rectangle]$TriggerBounds = [Drawing.Rectangle]::Empty)
    if ($Form.Tag.Scale -ne 0) { throw 'Auxiliary surface has already been scaled.' }
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid auxiliary scale.' }
    Set-AuxiliaryControlBounds -Control $Form -Scale $Scale
    $state = $Form.Tag
    $state.Scale = $Scale
    $width = [Math]::Max(1,[Math]::Min($Form.ClientSize.Width,$WorkingArea.Width-12))
    $height = [Math]::Max(1,[Math]::Min($Form.ClientSize.Height,$WorkingArea.Height-12))
    $Form.ClientSize = [Drawing.Size]::new($width,$height)
    $state.Header.Width = $width
    $state.Close.Left = [Math]::Max(0,$width-$state.Close.Width-[int][Math]::Round(12*$Scale))
    $state.Title.Width = [Math]::Max(1,$state.Close.Left-$state.Title.Left)
    $state.Subtitle.Width = [Math]::Max(1,$width-$state.Subtitle.Left-[int][Math]::Round(16*$Scale))
    $state.Body.Size = [Drawing.Size]::new($width,[Math]::Max(1,$height-$state.Body.Top))
    $state.Body.AutoScroll = $true
    $state.Body.AutoScrollMinSize = [Drawing.Size]::new(0,[int][Math]::Round($state.ContentHeight*$Scale))
    $Form.Location = Get-AuxiliaryPopupLocation -WorkingArea $WorkingArea -OwnerBounds $OwnerBounds -SurfaceSize $Form.Size -TriggerBounds $TriggerBounds
}

# Modal ownership prevents competing main-popup selections while a child is
# open. No business action is dispatched by this lifecycle function.
function Show-OwnedAuxiliaryPopup {
    param([System.Windows.Forms.Form]$Form,[System.Windows.Forms.Control]$Owner)
    try {
        if ($script:ActiveAuxiliaryPopup -or -not $Owner -or $Owner.IsDisposed) { return $null }
        $parent = $Owner.FindForm()
        if (-not $parent -or -not $parent.Visible) { return $null }
        $screen = [Windows.Forms.Screen]::FromControl($parent)
        $scale = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
        $triggerBounds = $Owner.RectangleToScreen($Owner.ClientRectangle)
        Set-AuxiliaryPopupLayout -Form $Form -Scale ([double]$scale) -WorkingArea $screen.WorkingArea -OwnerBounds $parent.Bounds -TriggerBounds $triggerBounds
        $script:ActiveAuxiliaryPopup = $Form
        $result = $Form.ShowDialog($parent)
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return $Form.Tag.Choice }
        return $null
    }
    finally {
        if ([object]::ReferenceEquals($script:ActiveAuxiliaryPopup,$Form)) { $script:ActiveAuxiliaryPopup = $null }
        $Form.Dispose()
    }
}
