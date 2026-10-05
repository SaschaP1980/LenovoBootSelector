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
    if ($mode -eq 'Remove') { return 'Systemfunktionen werden entfernt…' }
    if ($mode -eq 'Reinitialize') { return 'Systemfunktionen werden neu initialisiert…' }
    if ($mode -eq 'Repair' -or $mode -eq 'Migrate') { return 'Systemfunktionen werden repariert…' }
    return 'Systemfunktionen werden eingerichtet…'
}

function New-MaintenanceStatePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Name = 'MaintenanceStatePanel'
    $panel.Location = New-Object Drawing.Point(0, 60)
    $panel.Size = New-Object Drawing.Size(390, 592)
    $panel.BackColor = $script:ColorBackground
    $panel.Visible = $false

    $caption = New-Label -Text 'SYSTEMFUNKTIONEN' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
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
    $action.Text = 'Systemfunktionen einrichten'
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
                $heading.Text = 'Systemfunktionen einrichten'
                $message.Text = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich.'
                $action.Text = 'Systemfunktionen einrichten'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
            }
            elseif ($state -eq 'RepairRequired') {
                $glyph.Text = '!'
                $glyph.ForeColor = $script:ColorWarning
                $heading.Text = 'Systemfunktionen reparieren'
                $message.Text = 'Die vorhandene Einrichtung ist unvollständig oder muss aktualisiert werden.'
                $action.Text = 'Systemfunktionen reparieren'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Deine persönlichen Einstellungen bleiben dabei erhalten.'
            }
            elseif ($state -eq 'ReinitializeRequired') {
                $glyph.Text = '+'
                $glyph.ForeColor = $script:ColorCyan
                if (Test-BootTargetDriftHasNewTargets) {
                    $heading.Text = 'Neues Startziel erkannt'
                    $message.Text = 'Lenovo Boot Selector hat ein neues Startziel erkannt. Initialisiere die Systemfunktionen neu, damit es sicher verwendet werden kann.'
                }
                else {
                    $heading.Text = 'Startziele wurden geändert'
                    $message.Text = 'Die verfügbaren Startziele haben sich geändert. Initialisiere die Systemfunktionen neu, damit die Auswahl wieder vollständig passt.'
                }
                $action.Text = 'Systemfunktionen neu initialisieren'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Deine persönlichen Einstellungen bleiben dabei erhalten.'
            }
            else {
                $mode = Get-MaintenanceMode
                $glyph.Text = '…'
                $glyph.ForeColor = $script:ColorCyan
                $heading.Text = if ($mode -eq 'Remove') { 'Systemfunktionen werden entfernt…' } elseif ($mode -eq 'Reinitialize') { 'Systemfunktionen werden neu initialisiert…' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { 'Systemfunktionen werden repariert…' } else { 'Systemfunktionen werden eingerichtet…' }
                $message.Text = if ($mode -eq 'Remove') { 'Die Systemfunktionen werden sicher entfernt. Bitte warte einen Moment.' } elseif ($mode -eq 'Reinitialize') { 'Windows richtet die Systemfunktionen für die geänderten Startziele neu ein. Bitte warte einen Moment.' } else { 'Windows richtet die benötigten Systemfunktionen ein. Bitte warte einen Moment.' }
                $action.Visible = $false
                $action.Enabled = $false
                $hint.Text = 'Die App wird nach Abschluss automatisch aktualisiert.'
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
        Show-LenovoNoticeDialog -Title 'Systemfunktionen entfernt' -Heading 'Systemfunktionen wurden entfernt.' -Message 'Startziele können wieder geändert werden, nachdem du die Systemfunktionen erneut eingerichtet hast.' -Kind Info
        return
    }
    if ($Mode -eq 'Reinitialize') {
        Show-LenovoNoticeDialog -Title 'Neu initialisiert' -Heading 'Systemfunktionen wurden neu initialisiert.' -Message 'Das erkannte Startziel kann jetzt sicher verwendet werden.' -Kind Info
        return
    }
    Show-LenovoNoticeDialog -Title 'Systemfunktionen bereit' -Heading 'Systemfunktionen sind bereit.' -Message 'Lenovo Boot Selector kann jetzt Startziele ändern.' -Kind Info
}
