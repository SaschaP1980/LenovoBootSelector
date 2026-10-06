function Test-MaintenanceBusy {
    return (Test-MaintenanceRuntimeBusy -State $script:MaintenanceState)
}

function Get-MaintenanceMode {
    return (Get-MaintenanceRuntimeMode -State $script:MaintenanceState)
}

function Get-SystemFunctionsPresentationState {
    if (Test-MaintenanceBusy) {
        return ('Busy-' + (Get-MaintenanceMode))
    }
    if (Get-TaskBrokerInteractiveReady) {
        if (Test-BootTargetDriftDetected) { return 'ReinitializeRequired' }
        return 'Ready'
    }
    if (Test-TaskBrokerInstallationPresent) { return 'RepairRequired' }
    return 'SetupRequired'
}

function Get-MaintenanceBusyStatusText {
    $mode = Get-MaintenanceMode
    if ($mode -eq 'Remove') { return (Get-LocalizedString -Key 'Maintenance.Busy.Remove') }
    if ($mode -eq 'Reinitialize') { return (Get-LocalizedString -Key 'Maintenance.Busy.Reinitialize') }
    if ($mode -eq 'Repair' -or $mode -eq 'Migrate') { return (Get-LocalizedString -Key 'Maintenance.Busy.Repair') }
    return (Get-LocalizedString -Key 'Maintenance.Busy.Setup')
}

function New-MaintenanceStatePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Name = 'MaintenanceStatePanel'
    $panel.Location = New-Object Drawing.Point(0, 60)
    $panel.Size = New-Object Drawing.Size(390, 592)
    $panel.BackColor = $script:ColorBackground
    $panel.Visible = $false

    $caption = New-Label -Text (Get-LocalizedString -Key 'Maintenance.Caption') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 106 -Width 358 -Height 18
    $caption.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($caption)

    $glyph = New-Label -Text '⚙' -Font (New-Object Drawing.Font('Segoe UI Symbol', 24.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorAccent -X 166 -Y 134 -Width 58 -Height 58
    $glyph.Name = 'MaintenanceGlyph'
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($glyph)

    $heading = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 11.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 32 -Y 204 -Width 326 -Height 30
    $heading.Name = 'MaintenanceHeading'
    $heading.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($heading)

    $message = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 42 -Y 244 -Width 306 -Height 72
    $message.Name = 'MaintenanceMessage'
    $message.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($message)

    $action = New-Object System.Windows.Forms.Button
    $action.Name = 'MaintenancePrimaryButton'
    $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
    $action.Font = New-Object Drawing.Font('Segoe UI', 8.7, [Drawing.FontStyle]::Bold)
    $action.ForeColor = [Drawing.Color]::White
    $action.BackColor = $script:ColorAccent
    $action.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $action.FlatAppearance.BorderSize = 0
    $action.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $action.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $action.Location = New-Object Drawing.Point(55, 334)
    $action.Size = New-Object Drawing.Size(280, 38)
    $action.Cursor = [System.Windows.Forms.Cursors]::Hand
    $action.Add_Click({
        if (Test-MaintenanceBusy) { return }
        if ((Get-SystemFunctionsPresentationState) -eq 'ReinitializeRequired') {
            Prompt-TaskBrokerReinitialize
            return
        }
        Prompt-TaskBrokerInstall
    })
    $panel.Controls.Add($action)

    $hint = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 7.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 42 -Y 388 -Width 306 -Height 52
    $hint.Name = 'MaintenanceHint'
    $hint.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($hint)

    return $panel
}

function Update-MaintenanceUi {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $state = Get-SystemFunctionsPresentationState
    $busy = $state.StartsWith('Busy-')
    $ready = ($state -eq 'Ready')

    $panelMatches = $script:Popup.Controls.Find('MaintenanceStatePanel', $true)
    $panel = if ($panelMatches.Count -gt 0) { $panelMatches[0] } else { $null }
    if ($panel) {
        $heading = $panel.Controls['MaintenanceHeading']
        $message = $panel.Controls['MaintenanceMessage']
        $action = $panel.Controls['MaintenancePrimaryButton']
        $hint = $panel.Controls['MaintenanceHint']
        $glyph = $panel.Controls['MaintenanceGlyph']

        if ($ready) {
            $panel.Visible = $false
        }
        else {
            $panel.Visible = $true
            $panel.BringToFront()
            if ($state -eq 'SetupRequired') {
                $glyph.Text = '⚙'
                $glyph.ForeColor = $script:ColorAccent
                $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
                $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupMessage'
                $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHeading'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.SetupHint'
            }
            elseif ($state -eq 'RepairRequired') {
                $glyph.Text = '!'
                $glyph.ForeColor = $script:ColorWarning
                $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairMessage'
                $action.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHeading'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHint'
            }
            elseif ($state -eq 'ReinitializeRequired') {
                $glyph.Text = '+'
                $glyph.ForeColor = $script:ColorCyan
                if (Test-BootTargetDriftHasNewTargets) {
                    $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.NewTargetHeading'
                    $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.NewTargetMessage'
                }
                else {
                    $heading.Text = Get-LocalizedString -Key 'Maintenance.Panel.TargetsChangedHeading'
                    $message.Text = Get-LocalizedString -Key 'Maintenance.Panel.TargetsChangedMessage'
                }
                $action.Text = Get-LocalizedString -Key 'Maintenance.Action.Reinitialize'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.RepairHint'
            }
            else {
                $mode = Get-MaintenanceMode
                $glyph.Text = '…'
                $glyph.ForeColor = $script:ColorCyan
                $heading.Text = Get-MaintenanceBusyStatusText
                $message.Text = if ($mode -eq 'Remove') { Get-LocalizedString -Key 'Maintenance.Panel.BusyRemoveMessage' } elseif ($mode -eq 'Reinitialize') { Get-LocalizedString -Key 'Maintenance.Panel.BusyReinitializeMessage' } else { Get-LocalizedString -Key 'Maintenance.Panel.BusySetupMessage' }
                $action.Visible = $false
                $action.Enabled = $false
                $hint.Text = Get-LocalizedString -Key 'Maintenance.Panel.BusyHint'
            }
        }
    }

    if ($script:RefreshButton -and -not $script:RefreshButton.IsDisposed) {
        $script:RefreshButton.Enabled = ($ready -and -not $busy)
        $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    }
    if ($script:ManageEntriesButton -and -not $script:ManageEntriesButton.IsDisposed) {
        $script:ManageEntriesButton.Enabled = ($ready -and -not $busy)
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = ($ready -and -not $busy) }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = -not $busy }

    Update-HeaderRefreshStatus
}

function Show-MaintenanceSuccessDialog {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    if ($Mode -eq 'Remove') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessRemovedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessRemovedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessRemovedMessage') -Kind Info
        return
    }
    if ($Mode -eq 'Reinitialize') {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReinitializedMessage') -Kind Info
        return
    }
    Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SuccessReadyTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SuccessReadyHeading') -Message (Get-LocalizedString -Key 'Maintenance.SuccessReadyMessage') -Kind Info
}
