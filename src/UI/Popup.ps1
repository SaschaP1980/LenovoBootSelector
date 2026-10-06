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
    $form.Name = 'LenovoBootMenuPopup'
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

    # v0.2.29: compact brand header. No decorative status dot and no permanent
    # subtitle. A status line appears only while the background refresh is active.
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size(390, 60)
    $header.BackColor = $script:ColorHeader

    $headerTitle = New-Label -Text 'Lenovo Boot Selector' -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 16 -Y 19 -Width 285 -Height 22
    $headerTitle.Name = 'HeaderTitleLabel'
    $script:HeaderTitleLabel = $headerTitle
    $header.Controls.Add($headerTitle)

    # LBS-14: a real flat Button keeps the status visually label-like while
    # providing native Enter/Space activation and keyboard focus semantics.
    $headerSub = New-Object System.Windows.Forms.Button
    $headerSub.Text = ''
    $headerSub.Font = New-Object Drawing.Font('Segoe UI', 7.8, [Drawing.FontStyle]::Regular)
    $headerSub.ForeColor = $script:ColorSecondary
    $headerSub.BackColor = $script:ColorHeader
    $headerSub.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $headerSub.FlatAppearance.BorderSize = 0
    $headerSub.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $headerSub.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $headerSub.UseVisualStyleBackColor = $false
    $headerSub.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $headerSub.Padding = New-Object System.Windows.Forms.Padding(0)
    $headerSub.Location = New-Object Drawing.Point(13, 28)
    $headerSub.Size = New-Object Drawing.Size(300, 21)
    $headerSub.TabStop = $false
    $headerSub.Cursor = [System.Windows.Forms.Cursors]::Default
    $headerSub.Name = 'HeaderStatusLabel'
    $headerSub.Visible = $false
    $headerSub.AccessibleDescription = Get-LocalizedString -Key 'Popup.HeaderUpdateAccessible'
    $headerSub.Add_MouseEnter({
        $script:HeaderStatusHovered = $true
        Update-HeaderStatusInteractionVisual
    })
    $headerSub.Add_MouseLeave({
        $script:HeaderStatusHovered = $false
        Update-HeaderStatusInteractionVisual
    })
    $headerSub.Add_Enter({ Update-HeaderStatusInteractionVisual })
    $headerSub.Add_Leave({ Update-HeaderStatusInteractionVisual })
    $headerSub.Add_Click({
        if (-not $script:HeaderUpdateInteractionEnabled) { return }
        [void](Show-AvailableUpdateDialog)
    })
    $script:HeaderStatusLabel = $headerSub
    $header.Controls.Add($headerSub)

    $refresh = New-Object System.Windows.Forms.Button
    $refresh.Text = '↻'
    $refresh.Font = New-Object Drawing.Font('Segoe UI Symbol', 11.5, [Drawing.FontStyle]::Regular)
    $refresh.ForeColor = $script:ColorSecondary
    $refresh.BackColor = $script:ColorHeader
    $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $refresh.FlatAppearance.BorderSize = 0
    $refresh.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    $refresh.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $refresh.Location = New-Object Drawing.Point(340, 12)
    $refresh.Size = New-Object Drawing.Size(34, 34)
    $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:RefreshButton = $refresh
    $refresh.Add_MouseEnter({
        $script:RefreshButtonHovered = $true
        Update-RefreshButtonVisual
    })
    $refresh.Add_MouseLeave({
        $script:RefreshButtonHovered = $false
        Update-RefreshButtonVisual
    })
    $refresh.Add_Click({
        if (Test-MaintenanceBusy) { return }
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshing'
        Update-PopupRows
        Start-BackgroundBootRefresh -RefreshStorage
        Update-RefreshButtonVisual
    })
    $header.Controls.Add($refresh)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($refresh, (Get-LocalizedString -Key 'Action.RefreshBootTargets')) }
    Update-RefreshButtonVisual
    $root.Controls.Add($header)

    $headerDivider = New-Object System.Windows.Forms.Panel
    $headerDivider.Location = New-Object Drawing.Point(0, 59)
    $headerDivider.Size = New-Object Drawing.Size(390, 1)
    $headerDivider.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
    $root.Controls.Add($headerDivider)

    $section = New-Object System.Windows.Forms.Panel
    $section.Location = New-Object Drawing.Point(0, 60)
    $section.Size = New-Object Drawing.Size(390, 28)
    $section.BackColor = $script:ColorBackground

    $sectionLabel = New-Label -Text (Get-LocalizedString -Key 'Popup.NextBootSection') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 4 -Width 200 -Height 20
    $sectionLabel.Name = 'SectionLabel'
    $section.Controls.Add($sectionLabel)

    $manageButton = New-Object System.Windows.Forms.Button
    $manageButton.Name = 'ManageEntriesButton'
    $manageButton.Text = Get-LocalizedString -Key 'Popup.Customize'
    $manageButton.Font = New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)
    $manageButton.ForeColor = $script:ColorSecondary
    $manageButton.BackColor = $script:ColorBackground
    $manageButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $manageButton.FlatAppearance.BorderSize = 0
    $manageButton.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38, 38, 38)
    $manageButton.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $manageButton.Location = New-Object Drawing.Point(268, 1)
    $manageButton.Size = New-Object Drawing.Size(104, 25)
    $manageButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $manageButton.Add_Click({ Start-ManageEntriesMode })
    $script:ManageEntriesButton = $manageButton
    $section.Controls.Add($manageButton)
    $root.Controls.Add($section)

    $listPanel = New-Object System.Windows.Forms.Panel
    $listPanel.Name = 'EntryList'
    $listPanel.Location = New-Object Drawing.Point(0, 88)
    $listPanel.Size = New-Object Drawing.Size(390, 402)
    $listPanel.BackColor = $script:ColorBackground
    $listPanel.AutoScroll = $false
    $listPanel.TabStop = $true

    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Name = 'EntryContent'
    $contentPanel.Location = New-Object Drawing.Point(0, 0)
    $contentPanel.Size = New-Object Drawing.Size(390, 402)
    $contentPanel.BackColor = $script:ColorBackground
    $listPanel.Controls.Add($contentPanel)

    $entryScroll = New-Object LenovoVerticalScrollBar
    $entryScroll.Name = 'EntryScroll'
    $entryScroll.Location = New-Object Drawing.Point(382, 0)
    $entryScroll.Size = New-Object Drawing.Size(8, 402)
    $entryScroll.TrackColor = [Drawing.Color]::FromArgb(23, 23, 23)
    $entryScroll.ThumbColor = $script:ColorAccent
    $entryScroll.ThumbHoverColor = [Drawing.Color]::FromArgb(242, 59, 49)
    $entryScroll.Visible = $false
    $entryScroll.Add_ValueChanged({
        try {
            $scrollContainer = $this.Parent
            if ($scrollContainer) {
                $content = $scrollContainer.Controls['EntryContent']
                if ($content) { $content.Top = -1 * $this.Value }
            }
        }
        catch {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.ScrollPositionFailed'
        }
    })
    $listPanel.Controls.Add($entryScroll)
    $entryScroll.BringToFront()

    $listPanel.Add_MouseWheel({
        param($sender, $eventArgs)
        $bar = $sender.Controls['EntryScroll']
        if ($bar -and $bar.Visible) {
            $direction = if ($eventArgs.Delta -gt 0) { -1 } else { 1 }
            $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
        }
    })
    $listPanel.Add_MouseEnter({ $this.Focus() })
    $root.Controls.Add($listPanel)

    # v0.2.31: compact lower third with two aligned configuration rows and one
    # action area. The selected next-boot target is shown directly with Restart,
    # so the former duplicate status/footer block is no longer needed.
    $configSection = New-Object System.Windows.Forms.Panel
    $configSection.Name = 'ConfigSectionPanel'
    $configSection.Location = New-Object Drawing.Point(0, 490)
    $configSection.Size = New-Object Drawing.Size(390, 20)
    $configSection.BackColor = $script:ColorSurface

    $configLabel = New-Label -Text (Get-LocalizedString -Key 'Settings.Title') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 2 -Width 220 -Height 17
    $configSection.Controls.Add($configLabel)
    $root.Controls.Add($configSection)

    $settings = New-Object System.Windows.Forms.Panel
    $settings.Name = 'SettingsPanel'
    $settings.Location = New-Object Drawing.Point(0, 510)
    $settings.Size = New-Object Drawing.Size(390, 38)
    $settings.BackColor = $script:ColorSurface

    $autostartText = New-Label -Text (Get-LocalizedString -Key 'Settings.Autostart') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 280 -Height 22
    $autostartText.Cursor = [System.Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($autostartText)
    $script:AutostartTextLabel = $autostartText

    $autostart = New-Object LenovoCheckBox
    $autostart.Name = 'AutostartCheckbox'
    $autostart.Text = ''
    $autostart.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $autostart.ForeColor = $script:ColorPrimary
    $autostart.BackColor = $script:ColorSurface
    $autostart.AccentColor = $script:ColorAccent
    $autostart.Location = New-Object Drawing.Point(348, 7)
    $autostart.Size = New-Object Drawing.Size(26, 24)
    $autostart.Add_CheckedChanged({
        if (-not $script:UpdatingAutostartUi) {
            Set-AutostartFromUi -Enabled:$this.Checked
        }
    })
    $autostartText.Add_Click({ if ($script:AutostartCheckbox) { $script:AutostartCheckbox.Checked = -not $script:AutostartCheckbox.Checked } })
    $script:AutostartCheckbox = $autostart
    $settings.Controls.Add($autostart)
    $root.Controls.Add($settings)

    $defaultPanel = New-Object System.Windows.Forms.Panel
    $defaultPanel.Name = 'DefaultPanel'
    $defaultPanel.Location = New-Object Drawing.Point(0, 548)
    $defaultPanel.Size = New-Object Drawing.Size(390, 38)
    $defaultPanel.BackColor = $script:ColorSurface
    $defaultPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $defaultName = New-Label -Text (Get-LocalizedString -Key 'Settings.DefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 150 -Height 22
    $defaultName.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultName)

    $defaultValue = New-Label -Text (Get-LocalizedString -Key 'Settings.NoDefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 164 -Y 8 -Width 184 -Height 22
    $defaultValue.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $defaultValue.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultValue.Name = 'DefaultTargetValueLabel'
    $defaultPanel.Controls.Add($defaultValue)
    $script:DefaultValueLabel = $defaultValue

    $defaultArrow = New-Label -Text '›' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $defaultArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $defaultArrow.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultArrow.Name = 'DefaultTargetArrowLabel'
    $defaultPanel.Controls.Add($defaultArrow)
    $script:DefaultArrowLabel = $defaultArrow

    $defaultRowEnter = {
        if ($script:DefaultInteractionEnabled -and $script:DefaultButton) { $script:DefaultButton.BackColor = [Drawing.Color]::FromArgb(38,38,38) }
    }
    $defaultRowLeave = {
        if ($script:DefaultButton) { $script:DefaultButton.BackColor = $script:ColorSurface }
    }
    $defaultRowClick = {
        if ($script:DefaultInteractionEnabled -and $script:DefaultButton) { Show-DefaultTargetMenu -Owner $script:DefaultButton }
    }
    foreach ($control in @($defaultPanel,$defaultName,$defaultValue,$defaultArrow)) {
        $control.Add_MouseEnter($defaultRowEnter)
        $control.Add_MouseLeave($defaultRowLeave)
        $control.Add_Click($defaultRowClick)
    }
    $script:DefaultButton = $defaultPanel
    $root.Controls.Add($defaultPanel)

    $settingsDivider = New-Object System.Windows.Forms.Panel
    $settingsDivider.Name = 'SettingsDivider'
    $settingsDivider.Location = New-Object Drawing.Point(16, 586)
    $settingsDivider.Size = New-Object Drawing.Size(358, 1)
    $settingsDivider.BackColor = $script:ColorAccent
    $root.Controls.Add($settingsDivider)

    $restartPanel = New-Object System.Windows.Forms.Panel
    $restartPanel.Name = 'RestartPanel'
    $restartPanel.Location = New-Object Drawing.Point(0, 587)
    $restartPanel.Size = New-Object Drawing.Size(390, 65)
    $restartPanel.BackColor = $script:ColorSurface

    $restartButton = New-Object System.Windows.Forms.Button
    $restartButton.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartButton.Font = New-Object Drawing.Font('Segoe UI', 8.6, [Drawing.FontStyle]::Bold)
    $restartButton.ForeColor = $script:ColorPrimary
    $restartButton.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
    $restartButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restartButton.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68, 68, 68)
    $restartButton.FlatAppearance.BorderSize = 1
    $restartButton.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $restartButton.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58, 27, 25)
    $restartButton.Location = New-Object Drawing.Point(16, 6)
    $restartButton.Size = New-Object Drawing.Size(358, 31)
    $restartButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restartButton.Add_Click({ Restart-Windows })
    $restartPanel.Controls.Add($restartButton)

    $restartTarget = New-Label -Text (Get-LocalizedString -Key 'Status.NextTargetDefaultOrder') -Font (New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 16 -Y 39 -Width 358 -Height 18
    $restartTarget.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $restartTarget.Name = 'RestartTargetLabel'
    $restartPanel.Controls.Add($restartTarget)
    $script:RestartTargetLabel = $restartTarget
    $root.Controls.Add($restartPanel)

    # Dedicated footer height prevents Segoe UI/DPI clipping at the bottom edge.
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Name = 'FooterPanel'
    $footerPanel.Location = New-Object Drawing.Point(0, 652)
    $footerPanel.Size = New-Object Drawing.Size(390, 20)
    $footerPanel.BackColor = $script:ColorSurface
    $versionLabel = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(115,115,115)) -X 316 -Y 0 -Width 58 -Height 18
    $versionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $footerPanel.Controls.Add($versionLabel)
    $root.Controls.Add($footerPanel)

    # Entry-management overlay. It temporarily replaces the normal settings/footer
    # while the same boot list switches into edit mode.
    $managePanel = New-Object System.Windows.Forms.Panel
    $managePanel.Name = 'ManageEntriesPanel'
    $managePanel.Location = New-Object Drawing.Point(0, 490)
    $managePanel.Size = New-Object Drawing.Size(390, 182)
    $managePanel.BackColor = $script:ColorSurface
    $managePanel.Visible = $false

    $manageDivider = New-Object System.Windows.Forms.Panel
    $manageDivider.Location = New-Object Drawing.Point(16, 0)
    $manageDivider.Size = New-Object Drawing.Size(358, 1)
    $manageDivider.BackColor = [Drawing.Color]::FromArgb(54,54,54)
    $managePanel.Controls.Add($manageDivider)

    $manageTitle = New-Label -Text (Get-LocalizedString -Key 'Manage.Title') -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 8 -Width 350 -Height 18
    $managePanel.Controls.Add($manageTitle)

    $manageHint = New-Label -Text (Get-LocalizedString -Key 'Manage.Hint') -Font (New-Object Drawing.Font('Segoe UI', 7.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 29 -Width 358 -Height 17
    $managePanel.Controls.Add($manageHint)

    $manageSubHint = New-Label -Text (Get-LocalizedString -Key 'Manage.SubHint') -Font (New-Object Drawing.Font('Segoe UI', 7.2, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 46 -Width 358 -Height 17
    $managePanel.Controls.Add($manageSubHint)

    $cancelManage = New-Object System.Windows.Forms.Button
    $cancelManage.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $cancelManage.ForeColor = $script:ColorPrimary
    $cancelManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $cancelManage.FlatAppearance.BorderSize = 1
    $cancelManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $cancelManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58,27,25)
    $cancelManage.Location = New-Object Drawing.Point(16, 78)
    $cancelManage.Size = New-Object Drawing.Size(126, 34)
    $cancelManage.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelManage.Add_Click({ Stop-ManageEntriesMode })
    $managePanel.Controls.Add($cancelManage)

    $saveManage = New-Object System.Windows.Forms.Button
    $saveManage.Text = Get-LocalizedString -Key 'Manage.Save'
    $saveManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Bold)
    $saveManage.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
    $saveManage.BackColor = [Drawing.Color]::FromArgb(35,35,35)
    $saveManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
    $saveManage.FlatAppearance.BorderSize = 1
    $saveManage.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $saveManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $saveManage.Location = New-Object Drawing.Point(150, 78)
    $saveManage.Size = New-Object Drawing.Size(224, 34)
    $saveManage.Enabled = $false
    $saveManage.Cursor = [System.Windows.Forms.Cursors]::Default
    $saveManage.Add_Click({ Stop-ManageEntriesMode -Save })
    $managePanel.Controls.Add($saveManage)
    $script:ManageSaveButton = $saveManage

    $manageFooter = New-Object System.Windows.Forms.Panel
    $manageFooter.Location = New-Object Drawing.Point(0, 150)
    $manageFooter.Size = New-Object Drawing.Size(390, 32)
    $manageFooter.BackColor = $script:ColorSurface
    $manageVersion = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(120,120,120)) -X 316 -Y 7 -Width 58 -Height 18
    $manageVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $manageFooter.Controls.Add($manageVersion)
    $managePanel.Controls.Add($manageFooter)
    $root.Controls.Add($managePanel)

    $maintenancePanel = New-MaintenanceStatePanel
    $root.Controls.Add($maintenancePanel)

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_Deactivate({
        if (-not $script:ExitRequested -and -not (Test-MaintenanceBusy)) { $this.Hide() }
    })

    return $form
}

function Position-Popup {
    if (-not $script:Popup) { return }
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
    $wa = $screen.WorkingArea
    $x = $wa.Right - $script:Popup.Width - 10
    $y = $wa.Bottom - $script:Popup.Height - 10
    if ($x -lt $wa.Left) { $x = $wa.Left + 5 }
    if ($y -lt $wa.Top) { $y = $wa.Top + 5 }
    $script:Popup.Location = New-Object Drawing.Point($x, $y)
}

function Show-OrTogglePopup {
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $script:Popup = New-PopupForm
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $maintenanceBusy = Test-MaintenanceBusy
    $brokerReady = if ($maintenanceBusy) { $false } else { ((Get-SystemFunctionsPresentationState) -eq 'Ready') }
    if ($brokerReady) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if (Test-BootTargetDriftDetected) {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { Get-LocalizedString -Key 'Status.NewBootTargetDetected' } else { Get-LocalizedString -Key 'Status.BootTargetsChanged' }
            }
            elseif (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup
    $script:Popup.Show()
    $script:Popup.Activate()

    # LBS-21: opening the visible UI is the automatic read-only update-check trigger.
    # The update worker has its own busy gate and can overlap the independent boot-target worker.
    [void](Start-PopupUpdateCheck)

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($brokerReady -and -not $maintenanceBusy) {
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
