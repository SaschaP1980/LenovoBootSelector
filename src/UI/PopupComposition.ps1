# Lenovo Boot Selector - popup section composition.
# Domain-specific WinForms builders extracted from New-PopupForm by LBS-29.

# Keep native Button rendering for every active-owner state. This overlay
# is presentation-only and exists only for the auxiliary modal lifetime.
function Paint-ModalOwnerRefreshGlyph {
    param([Windows.Forms.Button]$Button,[Windows.Forms.PaintEventArgs]$EventArgs)
    if (-not $script:ActiveAuxiliaryPopup) { return }
    $brush = [Drawing.SolidBrush]::new($Button.BackColor)
    try { $EventArgs.Graphics.FillRectangle($brush,$Button.ClientRectangle) }
    finally { $brush.Dispose() }
    $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPrefix
    $ink = if ($Button.Enabled) { $Button.ForeColor } else { [Drawing.SystemColors]::GrayText }
    [Windows.Forms.TextRenderer]::DrawText($EventArgs.Graphics,$Button.Text,$Button.Font,$Button.ClientRectangle,$ink,$flags)
}

function Add-PopupHeaderSection {
    param([Parameter(Mandatory=$true)]$Root)

    # LBS-174: fixed two-line header geometry. A reserved status row remains
    # in place even when no status is visible; the brand title never moves.
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size(390, 60)
    $header.BackColor = $script:ColorHeader

    $headerTitle = New-Label -Text 'Lenovo Boot Selector' -Font (New-Object Drawing.Font('Segoe UI', 11.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 16 -Y 8 -Width 285 -Height 25
    $headerTitle.Name = 'HeaderTitleLabel'
    $script:HeaderTitleLabel = $headerTitle
    $header.Controls.Add($headerTitle)

    # LBS-14: a real flat Button keeps the status visually label-like while
    # providing native Enter/Space activation and keyboard focus semantics.
    $headerSub = New-Object System.Windows.Forms.Button
    $headerSub.Text = ''
    $headerSub.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $headerSub.ForeColor = $script:ColorSecondary
    $headerSub.BackColor = $script:ColorHeader
    $headerSub.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $headerSub.FlatAppearance.BorderSize = 0
    $headerSub.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $headerSub.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $headerSub.UseVisualStyleBackColor = $false
    $headerSub.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $headerSub.Padding = New-Object System.Windows.Forms.Padding(0)
    $headerSub.Location = New-Object Drawing.Point(16, 35)
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
    $refresh.Font = New-Object Drawing.Font('Segoe UI Symbol', 15.0, [Drawing.FontStyle]::Regular)
    $refresh.ForeColor = $script:ColorSecondary
    $refresh.BackColor = $script:ColorHeader
    $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $refresh.FlatAppearance.BorderSize = 0
    $refresh.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $refresh.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $refresh.UseVisualStyleBackColor = $false
    $refresh.Location = New-Object Drawing.Point(340, 12)
    $refresh.Size = New-Object Drawing.Size(34, 34)
    $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:RefreshButton = $refresh
    # Native flat buttons can retain their default/focus outline while the
    # top-level owner is disabled by ShowDialog. Keep the real Button and its
    # native painting for the active owner; redraw only the inactive glyph.
    $refresh.Add_Paint({ param($sender,$eventArgs) Paint-ModalOwnerRefreshGlyph -Button $sender -EventArgs $eventArgs })
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
        Update-PopupRows -Reason 'manual-refresh-start'
        Start-BackgroundBootRefresh -RefreshStorage -Origin Manual
        Update-RefreshButtonVisual
    })
    $header.Controls.Add($refresh)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($refresh, (Get-LocalizedString -Key 'Action.RefreshBootTargets')) }
    Update-RefreshButtonVisual
    $Root.Controls.Add($header)

    $headerDivider = New-Object System.Windows.Forms.Panel
    $headerDivider.Location = New-Object Drawing.Point(0, 59)
    $headerDivider.Size = New-Object Drawing.Size(390, 1)
    $headerDivider.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
    $Root.Controls.Add($headerDivider)

    $section = New-Object System.Windows.Forms.Panel
    $section.Location = New-Object Drawing.Point(0, 60)
    $section.Size = New-Object Drawing.Size(390, 28)
    $section.BackColor = $script:ColorBackground

    $sectionLabel = New-Label -Text (Get-LocalizedString -Key 'Popup.NextBootSection') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 4 -Width 200 -Height 20
    $sectionLabel.Name = 'SectionLabel'
    $section.Controls.Add($sectionLabel)

    $keyboardHint = New-Label -Text (Get-LocalizedString -Key 'Manage.KeyboardHint') -Font (New-Object Drawing.Font('Segoe UI', 8.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 210 -Y 4 -Width 164 -Height 20
    $keyboardHint.Name = 'ManageKeyboardHint'
    $keyboardHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $keyboardHint.Visible = $false
    $section.Controls.Add($keyboardHint)

    $manageButton = New-Object LenovoCustomizeButton
    $manageButton.Name = 'ManageEntriesButton'
    $manageButton.Text = Get-LocalizedString -Key 'Popup.Customize'
    $manageButton.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
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
    $Root.Controls.Add($section)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($manageButton,(Get-LocalizedString -Key 'Tooltip.Customize')) }
}

function Add-PopupBootEntryListSection {
    param([Parameter(Mandatory=$true)]$Root)

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
        Invoke-BootEntryWheelScroll -ListPanel $sender -EventArgs $eventArgs
    })
    # Hover never changes keyboard ownership. Mouse-wheel delivery remains
    # on the existing list/row handlers and the form's list hit-test route.
    $Root.Controls.Add($listPanel)
}

# The two top-level navigation rows share one hit/hover surface, including
# transparent child labels. Leaving a child within the row must not clear it.
function Get-PopupNavigationRow {
    param([Windows.Forms.Control]$Control)
    if ($Control -is [Windows.Forms.Panel]) { return $Control }
    return $Control.Parent
}

function Test-PopupNavigationRowInteractive {
    param([Windows.Forms.Control]$Row)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.Enabled -or $script:IsManageEntriesMode) { return $false }
    if ($Row.Name -eq 'DefaultPanel') { return [bool]$script:DefaultInteractionEnabled }
    return (-not (Test-MaintenanceBusy))
}

# Shared by pointer hover and the modal-owner highlight; other UI hover colors
# intentionally retain their existing palette.
function Get-PopupNavigationHoverColor {
    return [Drawing.Color]::FromArgb(48,48,48)
}

function Set-PopupNavigationRowHover {
    param([Windows.Forms.Control]$Control,[bool]$Hover)
    $row = Get-PopupNavigationRow -Control $Control
    if (-not $row -or $row.IsDisposed) { return }
    $inside = $Hover -or ($row.Visible -and $row.RectangleToScreen($row.ClientRectangle).Contains([Windows.Forms.Cursor]::Position))
    $row.BackColor = if ($inside -and (Test-PopupNavigationRowInteractive -Row $row)) { Get-PopupNavigationHoverColor } else { $script:ColorSurface }
}

function Invoke-PopupNavigationRow {
    param([Windows.Forms.Control]$Control)
    $row = Get-PopupNavigationRow -Control $Control
    if (-not (Test-PopupNavigationRowInteractive -Row $row)) { return }
    if ($row.Name -eq 'DefaultPanel') { Show-DefaultTargetMenu -Owner $row }
    elseif ($row.Name -eq 'SettingsPanel') { Show-ConfigurationPopup -Owner $row }
}

function Add-PopupNavigationRowHandlers {
    param([Windows.Forms.Control]$Row)
    $hintKey = if ($Row.Name -eq 'DefaultPanel') { 'Tooltip.DefaultNavigation' } else { 'Tooltip.Settings' }
    foreach ($control in @($Row) + @($Row.Controls)) {
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($control,(Get-LocalizedString -Key $hintKey)) }
        $control.Add_MouseEnter({ param($sender,$eventArgs) Set-PopupNavigationRowHover -Control $sender -Hover $true })
        $control.Add_MouseLeave({ param($sender,$eventArgs) Set-PopupNavigationRowHover -Control $sender -Hover $false })
        $control.Add_MouseDown({
            param($sender,$eventArgs)
            if ($eventArgs.Button -ne [Windows.Forms.MouseButtons]::Left) { return }
            $target = Get-PopupNavigationRow -Control $sender
            if (Test-PopupNavigationRowInteractive -Row $target) { Set-LenovoPointerFocus -Control $target }
        })
        $control.Add_Click({ param($sender,$eventArgs) Invoke-PopupNavigationRow -Control $sender })
    }
    $Row.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.Modifiers -eq [Windows.Forms.Keys]::None -and $eventArgs.KeyCode -in @([Windows.Forms.Keys]::Enter,[Windows.Forms.Keys]::Space)) {
            $eventArgs.SuppressKeyPress = $true
            Invoke-PopupNavigationRow -Control $sender
        }
    })
}

function Add-PopupSettingsSection {
    param([Parameter(Mandatory=$true)]$Root)

    # v0.2.31: compact lower third with two aligned configuration rows and one
    # action area. The selected next-boot target is shown directly with Restart,
    # so the former duplicate status/footer block is no longer needed.
    $configSection = New-Object System.Windows.Forms.Panel
    $configSection.Name = 'ConfigSectionPanel'
    $configSection.Location = New-Object Drawing.Point(0, 490)
    $configSection.Size = New-Object Drawing.Size(390, 20)
    $configSection.BackColor = $script:ColorSurface

    $configLabel = New-Label -Text (Get-LocalizedString -Key 'Settings.Title') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 2 -Width 220 -Height 17
    $configLabel.Name = 'ConfigurationSectionLabel'
    $configSection.Controls.Add($configLabel)
    $Root.Controls.Add($configSection)

    Initialize-NormalBootKeyboardRow
    $settings = New-Object LenovoNormalBootKeyboardRow
    $settings.Name = 'SettingsPanel'
    $settings.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $settings.AccessibleName = Get-LocalizedString -Key 'Settings.More'
    $settings.Location = New-Object Drawing.Point(0, 510)
    $settings.Size = New-Object Drawing.Size(390, 38)
    $settings.BackColor = $script:ColorSurface
    $settings.Cursor = [Windows.Forms.Cursors]::Hand

    $more = New-Label -Text $settings.AccessibleName -Font (New-Object Drawing.Font('Segoe UI',9.0)) -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 330 -Height 22
    $more.Name = 'MoreSettingsButton'
    $more.Cursor = [Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($more)
    $moreArrow = New-Label -Text '‹' -Font (New-Object Drawing.Font('Segoe UI',10.0)) -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $moreArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $moreArrow.Cursor = [Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($moreArrow)
    Add-PopupNavigationRowHandlers -Row $settings
    $Root.Controls.Add($settings)

    $defaultPanel = New-Object LenovoNormalBootKeyboardRow
    $defaultPanel.AccessibleRole = [Windows.Forms.AccessibleRole]::PushButton
    $defaultPanel.Name = 'DefaultPanel'
    $defaultPanel.Location = New-Object Drawing.Point(0, 548)
    $defaultPanel.Size = New-Object Drawing.Size(390, 38)
    $defaultPanel.BackColor = $script:ColorSurface
    $defaultPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $defaultName = New-Label -Text (Get-LocalizedString -Key 'Settings.DefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 144 -Height 22
    $defaultName.Name = 'DefaultTargetNameLabel'
    $defaultName.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultName)

    $defaultValue = New-Label -Text (Get-LocalizedString -Key 'Settings.NoDefaultTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 164 -Y 8 -Width 184 -Height 22
    $defaultValue.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $defaultValue.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultValue.Name = 'DefaultTargetValueLabel'
    $defaultPanel.Controls.Add($defaultValue)
    $script:DefaultValueLabel = $defaultValue

    $defaultArrow = New-Label -Text '‹' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $defaultArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $defaultArrow.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultArrow.Name = 'DefaultTargetArrowLabel'
    $defaultPanel.Controls.Add($defaultArrow)
    $script:DefaultArrowLabel = $defaultArrow

    Add-PopupNavigationRowHandlers -Row $defaultPanel
    $script:DefaultButton = $defaultPanel
    $Root.Controls.Add($defaultPanel)

    $settingsDivider = New-Object System.Windows.Forms.Panel
    $settingsDivider.Name = 'SettingsDivider'
    $settingsDivider.Location = New-Object Drawing.Point(16, 586)
    $settingsDivider.Size = New-Object Drawing.Size(358, 1)
    $settingsDivider.BackColor = $script:ColorAccent
    $Root.Controls.Add($settingsDivider)
}

function Add-PopupRestartSection {
    param([Parameter(Mandatory=$true)]$Root)

    $restartPanel = New-Object System.Windows.Forms.Panel
    $restartPanel.Name = 'RestartPanel'
    $restartPanel.Location = New-Object Drawing.Point(0, 587)
    $restartPanel.Size = New-Object Drawing.Size(390, 65)
    $restartPanel.BackColor = $script:ColorSurface

    $restartButton = New-Object System.Windows.Forms.Button
    $restartButton.Name = 'RestartActionButton'
    $restartButton.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartButton.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $restartButton.ForeColor = $script:ColorPrimary
    $restartButton.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
    $restartButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restartButton.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68, 68, 68)
    $restartButton.FlatAppearance.BorderSize = 1
    $restartButton.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $restartButton.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58, 27, 25)
    $restartButton.Location = New-Object Drawing.Point(16, 30)
    $restartButton.Size = New-Object Drawing.Size(358, 31)
    $restartButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    # The native Flat adapter paints disabled text nearly black on dark surfaces.
    # Only replace disabled foreground ink, leaving the real WinForms gates,
    # unchanged enabled rendering, geometry, borders and High Contrast intact.
    $pendingDisabledInkPainter = {
        param($sender,$eventArgs)
        if ($sender.Enabled -or [Windows.Forms.SystemInformation]::HighContrast) { return }
        $inner = $sender.ClientRectangle
        $border = $sender.FlatAppearance.BorderSize
        $inner.Inflate(-$border,-$border)
        if ($inner.Width -le 0 -or $inner.Height -le 0) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$inner) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                 [Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                 [Windows.Forms.TextFormatFlags]::SingleLine -bor
                 [Windows.Forms.TextFormatFlags]::EndEllipsis -bor
                 [Windows.Forms.TextFormatFlags]::NoPrefix -bor
                 [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$inner,([Drawing.Color]::FromArgb(146,146,146)),$flags)
    }
    $restartButton.Add_Paint($pendingDisabledInkPainter)
    $restartButton.Add_Click({ Restart-Windows })
    $script:RestartButton = $restartButton
    $restartPanel.Controls.Add($restartButton)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($restartButton,(Get-LocalizedString -Key 'Tooltip.Restart')) }

    # LBS-206 Layout C: the firmware-readback state is always passive and
    # precedes the explicit restart action. The one-time default control is
    # separate, and only appears when the guarded operation is admissible.
    # The original 390x672 footprint and 65px restart panel are unchanged.
    $restartTarget = New-Label -Text (Get-LocalizedString -Key 'BootNext.LayoutUnknown') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 3 -Width 358 -Height 23
    $restartTarget.Name = 'RestartTargetLabel'
    $restartTarget.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $restartTarget.AutoEllipsis = $true
    $restartTarget.TabStop = $false
    $restartTarget.Cursor = [Windows.Forms.Cursors]::Default
    $restartTarget.AccessibleRole = [Windows.Forms.AccessibleRole]::StaticText
    $restartTarget.AccessibleName = $restartTarget.Text
    $restartTarget.AccessibleDescription = $restartTarget.Text
    $restartTarget.Add_TextChanged({
        $this.AccessibleName = $this.Text
        $this.AccessibleDescription = $this.Text
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($this,$this.Text) }
    })
    $restartPanel.Controls.Add($restartTarget)
    $script:RestartTargetLabel = $restartTarget

    $defaultOnce = New-Object System.Windows.Forms.Button
    $defaultOnce.Name = 'RestartUseDefaultButton'
    $defaultOnce.Text = Get-LocalizedString -Key 'BootNext.UseDefaultOnce'
    $defaultOnce.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $defaultOnce.ForeColor = [Drawing.Color]::FromArgb(255,160,150)
    $defaultOnce.BackColor = $script:ColorSelectedRow
    $defaultOnce.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $defaultOnce.FlatAppearance.BorderColor = $script:ColorAccent
    $defaultOnce.FlatAppearance.BorderSize = 1
    $defaultOnce.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(81,37,34)
    $defaultOnce.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(100,40,35)
    $defaultOnce.Location = New-Object Drawing.Point(16,30)
    $defaultOnce.Size = New-Object Drawing.Size(205,31)
    $defaultOnce.Visible = $false
    $defaultOnce.Enabled = $false
    $defaultOnce.TabStop = $false
    $defaultOnce.TabIndex = 0
    $defaultOnce.Cursor = [Windows.Forms.Cursors]::Default
    $defaultOnce.AccessibleName = $defaultOnce.Text
    $defaultOnce.Add_Click({
        if ($script:RestartUseDefaultButton -and
            $script:RestartUseDefaultButton.Enabled -and
            $script:RestartUseDefaultButton.Visible -and
            -not $script:BootNextPendingGuid) { Use-DefaultForNextRestart }
    })
    $restartPanel.Controls.Add($defaultOnce)
    $script:RestartUseDefaultButton = $defaultOnce
    $restartButton.TabIndex = 1
    $Root.Controls.Add($restartPanel)

    # Dedicated footer height prevents Segoe UI/DPI clipping at the bottom edge.
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Name = 'FooterPanel'
    $footerPanel.Location = New-Object Drawing.Point(0, 652)
    $footerPanel.Size = New-Object Drawing.Size(390, 20)
    $footerPanel.BackColor = $script:ColorSurface
    $versionLabel = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 284 -Y 0 -Width 90 -Height 20
    $versionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $footerPanel.Controls.Add($versionLabel)
    $Root.Controls.Add($footerPanel)
}

function Add-PopupManageEntriesSection {
    param([Parameter(Mandatory=$true)]$Root)

    # Entry-management overlay. It temporarily replaces the normal settings/footer
    # while the same boot list switches into edit mode.
    # LBS-231: the redundant instructional block is gone. Keep the action
    # row and version footer at their original absolute positions; the list
    # claims the recovered 72 design pixels in addition to LBS-157.
    # A multiple of four preserves the absolute button positions across
    # fractional quarter-step DPI scales without a one-pixel rounding drift.
    $managePanel = New-Object System.Windows.Forms.Panel
    $managePanel.Name = 'ManageEntriesPanel'
    $managePanel.Location = New-Object Drawing.Point(0, 596)
    $managePanel.Size = New-Object Drawing.Size(390, 76)
    $managePanel.BackColor = $script:ColorSurface
    $managePanel.Visible = $false

    $manageDivider = New-Object System.Windows.Forms.Panel
    $manageDivider.Location = New-Object Drawing.Point(16, 0)
    $manageDivider.Size = New-Object Drawing.Size(358, 1)
    $manageDivider.BackColor = [Drawing.Color]::FromArgb(54,54,54)
    $managePanel.Controls.Add($manageDivider)

    # LBS-179: one native Undo control in the existing action row, no history surface.
    $undoManage = New-Object System.Windows.Forms.Button
    $undoManage.Name = 'ManageUndoButton'
    $undoManage.Text = Get-LocalizedString -Key 'Manage.Undo'
    $undoManage.AccessibleName = $undoManage.Text
    $undoManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $undoManage.ForeColor = [Drawing.Color]::FromArgb(146,146,146)
    $undoManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $undoManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $undoManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $undoManage.FlatAppearance.BorderSize = 1
    $undoManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $undoManage.Location = New-Object Drawing.Point(16, 6)
    $undoManage.Size = New-Object Drawing.Size(100, 34)
    $undoManage.Enabled = $false
    $undoManage.TabIndex = 0
    $undoManage.Add_Click({ Undo-ManageEntryDraft })
    $managePanel.Controls.Add($undoManage)

    $cancelManage = New-Object System.Windows.Forms.Button
    $cancelManage.Name = 'ManageCancelButton'
    $cancelManage.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $cancelManage.ForeColor = $script:ColorPrimary
    $cancelManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $cancelManage.FlatAppearance.BorderSize = 1
    $cancelManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $cancelManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58,27,25)
    $cancelManage.Location = New-Object Drawing.Point(124, 6)
    $cancelManage.Size = New-Object Drawing.Size(84, 34)
    $cancelManage.TabIndex = 1
    $cancelManage.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelManage.Add_Click({ Stop-ManageEntriesMode })
    $managePanel.Controls.Add($cancelManage)

    $saveManage = New-Object System.Windows.Forms.Button
    $saveManage.Name = 'ManageSaveButton'
    $saveManage.Text = Get-LocalizedString -Key 'Manage.Save'
    $saveManage.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $saveManage.ForeColor = [Drawing.Color]::FromArgb(146,146,146)
    $saveManage.BackColor = [Drawing.Color]::FromArgb(35,35,35)
    $saveManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
    $saveManage.FlatAppearance.BorderSize = 1
    $saveManage.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(190,35,28)
    $saveManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $saveManage.Location = New-Object Drawing.Point(216, 6)
    $saveManage.Size = New-Object Drawing.Size(158, 34)
    $saveManage.TabIndex = 2
    # LBS-186: the native Flat button adapter dims disabled text against
    # the dark background. Repaint only the disabled interior using the
    # configured palette; keep the real Button, native border and Enabled gate.
    $saveManage.Add_Paint({
        param($sender,$eventArgs)
        if ($sender.Enabled -or [Windows.Forms.SystemInformation]::HighContrast) { return }
        $inner = $sender.ClientRectangle
        $border = $sender.FlatAppearance.BorderSize
        $inner.Inflate(-$border,-$border)
        if ($inner.Width -le 0 -or $inner.Height -le 0) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$inner) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                 [Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                 [Windows.Forms.TextFormatFlags]::SingleLine -bor
                 [Windows.Forms.TextFormatFlags]::EndEllipsis -bor
                 [Windows.Forms.TextFormatFlags]::NoPrefix -bor
                 [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$inner,$sender.ForeColor,$flags)
    })
    $saveManage.Enabled = $false
    $saveManage.Cursor = [System.Windows.Forms.Cursors]::Default
    $saveManage.Add_Click({ Stop-ManageEntriesMode -Save })
    $managePanel.Controls.Add($saveManage)
    $script:ManageSaveButton = $saveManage

    $manageFooter = New-Object System.Windows.Forms.Panel
    $manageFooter.Location = New-Object Drawing.Point(0, 44)
    $manageFooter.Size = New-Object Drawing.Size(390, 32)
    $manageFooter.BackColor = $script:ColorSurface
    $manageVersion = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 284 -Y 7 -Width 90 -Height 20
    $manageVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $manageFooter.Controls.Add($manageVersion)
    $managePanel.Controls.Add($manageFooter)
    $Root.Controls.Add($managePanel)
}

# Shared visual shell for the two configuration-specific surfaces. Shared
# fonts and the local tooltip belong to this Form, not to the main popup.
function New-AuxiliaryPopupForm {
    param([string]$Name,[string]$Title,[AllowEmptyString()][string]$Subtitle,[int]$ContentHeight)
    $form = New-Object Windows.Forms.Form
    $form.Name = $Name
    $form.Text = $Title
    $form.AccessibleName = $Title
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.KeyPreview = $true
    $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $form.BackColor = $script:ColorBackground
    $heightLimit = if ($Name -eq 'LenovoConfigurationPopup') { 672 } else { 540 }
    $form.ClientSize = [Drawing.Size]::new(390,[Math]::Min($heightLimit,64+$ContentHeight))
    $regular = [Drawing.Font]::new('Segoe UI',[single]9.0)
    $bold = [Drawing.Font]::new('Segoe UI',[single]10.0,[Drawing.FontStyle]::Bold)
    $heading = [Drawing.Font]::new('Segoe UI',[single]8.5,[Drawing.FontStyle]::Bold)
    $large = [Drawing.Font]::new('Segoe UI',[single]11.5,[Drawing.FontStyle]::Bold)
    $symbol = [Drawing.Font]::new('Segoe UI Symbol',[single]18.0)
    $tip = New-LenovoDarkTooltip -Animate
    $header = New-Object Windows.Forms.Panel
    $header.Name = 'AuxiliaryHeader'
    $header.TabIndex = 1
    $header.BackColor = $script:ColorHeader
    $header.Size = [Drawing.Size]::new(390,64)
    $titleLabel = New-Label -Text $Title -Font $large -ForeColor $script:ColorPrimary -X 16 -Y 7 -Width 318 -Height 26
    $subtitleLabel = New-Label -Text $Subtitle -Font $regular -ForeColor $script:ColorSecondary -X 16 -Y 34 -Width 358 -Height 23
    $subtitleLabel.AccessibleDescription = $Subtitle
    $tip.SetToolTip($subtitleLabel,$Subtitle)
    $header.Controls.Add($titleLabel)
    $header.Controls.Add($subtitleLabel)
    $close = New-Object Windows.Forms.Button
    $close.Name = 'AuxiliaryClose'
    $close.Text = '×'
    $close.AccessibleName = Get-LocalizedString -Key 'Common.Close'
    $close.Cursor = [Windows.Forms.Cursors]::Hand
    $closeHintKey = if ($Name -eq 'LenovoDefaultTargetPicker') { 'Tooltip.ClosePicker' } else { 'Tooltip.CloseSettings' }
    $tip.SetToolTip($close,(Get-LocalizedString -Key $closeHintKey))
    $close.Font = $symbol
    $close.BackColor = $script:ColorHeader
    $close.ForeColor = $script:ColorPrimary
    $close.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $close.FlatAppearance.BorderSize = 0
    $close.FlatAppearance.MouseOverBackColor = $script:ColorHeader
    $close.FlatAppearance.MouseDownBackColor = $script:ColorHeader
    $close.UseVisualStyleBackColor = $false
    # The close button remains a native keyboard-accessible CancelButton.
    # Native default/focus ink must not survive on an inactive modal owner.
    $close.Add_Paint({
        param($sender,$eventArgs)
        if ([Windows.Forms.SystemInformation]::HighContrast) { return }
        $form = $sender.FindForm()
        if (-not $form) { return }
        if ($sender.Focused -and $form.ContainsFocus -and -not $script:ActiveOwnedDialog) { return }
        $background = New-Object Drawing.SolidBrush($sender.BackColor)
        try { $eventArgs.Graphics.FillRectangle($background,$sender.ClientRectangle) }
        finally { $background.Dispose() }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPrefix -bor [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,$sender.Text,$sender.Font,$sender.ClientRectangle,$sender.ForeColor,$flags)
    })
    $close.Add_GotFocus({ $this.Invalidate() })
    $close.Add_LostFocus({ $this.Invalidate() })
    $close.Add_MouseEnter({ param($sender,$eventArgs) $sender.ForeColor = $script:ColorAccent })
    $close.Add_MouseLeave({ param($sender,$eventArgs) $sender.ForeColor = $script:ColorPrimary })
    $close.Location = [Drawing.Point]::new(350,7)
    $close.Size = [Drawing.Size]::new(28,30)
    $close.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $header.Controls.Add($close)
    $form.Controls.Add($header)
    # Keep action controls in the body; clip it in a separate fixed viewport.
    # Reuse the main popup's existing painted scrollbar and pixel-value contract.
    $viewport = New-Object Windows.Forms.Panel
    $viewport.Name = 'AuxiliaryViewport'
    $viewport.TabIndex = 0
    $viewport.BackColor = $script:ColorBackground
    $viewport.AutoScroll = $false
    $viewport.Location = [Drawing.Point]::new(0,64)
    $viewport.Size = [Drawing.Size]::new(390,$form.ClientSize.Height-64)
    $body = New-Object Windows.Forms.Panel
    $body.Name = 'AuxiliaryBody'
    $body.TabIndex = 0
    $body.BackColor = $script:ColorBackground
    $body.AutoScroll = $false
    $body.Location = [Drawing.Point]::Empty
    $body.Size = [Drawing.Size]::new(390,$ContentHeight)
    $viewport.Controls.Add($body)
    $scroll = New-Object LenovoVerticalScrollBar
    $scroll.Name = 'AuxiliaryScroll'
    $scroll.Location = [Drawing.Point]::new(382,0)
    $scroll.Size = [Drawing.Size]::new(8,$viewport.Height)
    $scroll.TrackColor = [Drawing.Color]::FromArgb(23,23,23)
    $scroll.ThumbColor = $script:ColorAccent
    $scroll.ThumbHoverColor = [Drawing.Color]::FromArgb(242,59,49)
    $scroll.Visible = $false
    $scroll.Add_ValueChanged({
        param($sender,$eventArgs)
        $content = $sender.Parent.Controls['AuxiliaryBody']
        if ($content) { $content.Top = -$sender.Value }
    })
    $viewport.Controls.Add($scroll)
    $scroll.BringToFront()
    $form.Controls.Add($viewport)
    $form.CancelButton = $close
    # Keep the accessible close button in the tab order and as CancelButton,
    # but do not give it the initial keyboard focus (native focus outline).
    $form.Add_Shown({
        param($sender,$eventArgs)
        [void]$sender.Tag.Body.SelectNextControl($null,$true,$true,$true,$false)
    })
    $form.Tag = [pscustomobject]@{
        Choice=$null; Scale=0.0; Header=$header; Title=$titleLabel; Subtitle=$subtitleLabel
        Close=$close; Body=$body; Viewport=$viewport; Scroll=$scroll; ContentHeight=$ContentHeight; Tip=$tip
        Regular=$regular; Bold=$bold; Heading=$heading; Symbol=$symbol
        Fonts=@($regular,$bold,$heading,$large,$symbol); Timer=$null; DefaultSnapshot=$null; ActionInProgress=$false
    }
    $form.Add_Disposed({
        param($sender,$eventArgs)
        $state = $sender.Tag
        if ($state.Timer) { $state.Timer.Stop(); $state.Timer.Dispose() }
        $state.Tip.Dispose()
        foreach ($font in $state.Fonts) { $font.Dispose() }
    })
    $form.Add_Paint({
        param($sender,$eventArgs)
        $pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(108,108,108))
        try { $eventArgs.Graphics.DrawRectangle($pen,0,0,[Math]::Max(0,$sender.ClientSize.Width-1),[Math]::Max(0,$sender.ClientSize.Height-1)) }
        finally { $pen.Dispose() }
    })
    return $form
}

function Get-ConfigurationActionMenuItem {
    param([string]$Action)
    switch ($Action) {
        'autostart' { return $script:AutostartMenuItem }
        'language-de' { return $script:LanguageGermanMenuItem }
        'language-en' { return $script:LanguageEnglishMenuItem }
        'system-setup' { return $script:TaskBrokerSetupMenuItem }
        'system-remove' { return $script:TaskBrokerRemoveMenuItem }
        'update-check' { return $script:UpdateCheckMenuItem }
        'update-install' { return $script:UpdateInstallMenuItem }
        'preferences-export' { return $script:PreferencesExportMenuItem }
        'preferences-import' { return $script:PreferencesImportMenuItem }
        'diagnostics-save' { return $script:RuntimeDiagnosticMenuItem }
        'diagnostics-upload' { return $script:DiagnosticsUploadMenuItem }
    }
    return $null
}

function Test-ConfigurationActionAvailable {
    param([string]$Action)
    $item = Get-ConfigurationActionMenuItem -Action $Action
    if ($Action -like 'preferences-*' -and $item -and -not $item.IsDisposed) {
        $item.Enabled = [bool](Test-PortablePreferencesAvailable -PresentationOnly)
    }
    return [bool]($item -and -not $item.IsDisposed -and $item.Available -and $item.Enabled -and -not (Test-MaintenanceBusy))
}

function Update-ConfigurationPopupPresentation {
    param([System.Windows.Forms.Form]$Form)
    # Move focus before disabling the current action. WinForms would otherwise
    # fall through to the header's CancelButton when the final row is disabled.
    # Do not move an explicitly selected close button or focus in another window.
    if ($Form.ContainsFocus) {
        $focused = $Form.Tag.Body.Controls | Where-Object { $_.Focused } | Select-Object -First 1
        if ($focused -and $focused.Tag -and -not (Test-ConfigurationActionAvailable -Action ([string]$focused.Tag))) {
            $eligible = @($Form.Tag.Body.Controls | Where-Object {
                $_.TabStop -and $_.CanFocus -and $_.Tag -and
                (Test-ConfigurationActionAvailable -Action ([string]$_.Tag))
            } | Sort-Object TabIndex)
            $target = $eligible | Where-Object { $_.TabIndex -gt $focused.TabIndex } | Select-Object -First 1
            if (-not $target) { $target = $eligible | Select-Object -Last 1 }
            if ($target) { [void]$target.Focus() }
        }
    }
    foreach ($control in $Form.Tag.Body.Controls) {
        $action = [string]$control.Tag
        if (-not $action) { continue }
        $item = Get-ConfigurationActionMenuItem -Action $action
        $control.Enabled = Test-ConfigurationActionAvailable -Action $action
        if (-not $item) { continue }
        $hintKey = if ($action -eq 'autostart') { 'Tooltip.Configuration.autostart' } else { 'Tooltip.Configuration.' + $action }
        $hint = Get-LocalizedString -Key $hintKey
        if (-not $control.Enabled) { $hint += [Environment]::NewLine + (Get-LocalizedString -Key 'Tooltip.Unavailable') }
        if ($Form.Tag.Tip.GetToolTip($control) -cne $hint) { $Form.Tag.Tip.SetToolTip($control,$hint) }
        $control.Cursor = if ($control.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        if ($control -is [Windows.Forms.CheckBox]) {
            if ($control.Checked -ne [bool]$item.Checked) { $control.Checked = [bool]$item.Checked; $control.Invalidate() }
            $control.AccessibleDescription = $hint
        }
        elseif ($control -is [LenovoSettingsAutostartLabel]) {
            $control.AccessibleDescription = $hint
        }
        elseif ($control -is [LenovoSettingsActionButton]) {
            $language = $action -like 'language-*'
            $selected = [bool]($language -and $item.Checked)
            $name = if ($language) {
                if ($action -eq 'language-de') { Get-LocalizedString -Key 'Language.German' }
                else { Get-LocalizedString -Key 'Language.English' }
            } else { ([string]$item.Text).TrimEnd('.') }
            $subtitle = if ($language) { '' } elseif ($action -eq 'update-install' -and -not $control.Enabled) { Get-LocalizedString -Key 'Tooltip.Unavailable' } else { Get-LocalizedString -Key ('Settings.Detail.' + $action) }
            $description = $hint
            if ($language) {
                $description += [Environment]::NewLine + (Get-LocalizedString -Key $(if ($selected) { 'Settings.LanguageSelected' } else { 'Settings.LanguageNotSelected' }))
            }
            $changed = $control.Text -cne $name -or $control.Subtitle -cne $subtitle -or $control.LanguageSelected -ne $selected
            $control.Text = $name
            $control.Subtitle = $subtitle
            $control.LanguageSelected = $selected
            $control.AccessibleName = $name
            $control.AccessibleDescription = $description
            $control.ForeColor = if ($control.Enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(146,146,146) }
            $control.BackColor = if ($language) { $script:ColorSurface } else { [Drawing.Color]::FromArgb(37,37,37) }
            $control.FlatAppearance.BorderColor = if (-not $control.Enabled) { [Drawing.Color]::FromArgb(58,58,58) } elseif ($selected) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(68,68,68) }
            if ($changed) { $control.Invalidate() }
        }
    }
}

function Invoke-ConfigurationPopupAction {
    param([System.Windows.Forms.Control]$Control)
    $action = [string]$Control.Tag
    if (-not (Test-ConfigurationActionAvailable -Action $action)) { return }
    $form = $Control.FindForm()
    $item = Get-ConfigurationActionMenuItem -Action $action
    if (-not $form -or $form.IsDisposed -or $form.Tag.ActionInProgress) { return }
    if ($action -like 'language-*' -and $item.Checked) { return }
    # The existing tray handlers still own all operations and confirmations.
    # Keep the settings modal alive throughout synchronous dispatch; asynchronous
    # result dialogs resolve the currently visible owner when they complete.
    $form.Tag.ActionInProgress = $true
    try { $item.PerformClick() }
    finally {
        if (-not $form.IsDisposed) {
            $form.Tag.ActionInProgress = $false
            Update-ConfigurationPopupPresentation -Form $form
        }
    }
}

function Add-ConfigurationHeading {
    param($Form,[string]$Key,[int]$Y)
    $label = New-Label -Text (Get-LocalizedString -Key $Key) -Font $Form.Tag.Heading -ForeColor $script:ColorSecondary -X 16 -Y $Y -Width 350 -Height 22
    $label.Name = 'ConfigurationLocale-' + $Key
    $Form.Tag.Body.Controls.Add($label)
}

function Add-ConfigurationActionButton {
    param($Form,[string]$Action,[string]$Key,[int]$Y,[int]$X=16,[int]$Width=350,[switch]$Separator)
    $button = New-Object LenovoSettingsActionButton
    $button.Name = 'ConfigurationAction-' + $Action
    $button.Tag = $Action
    $button.ActionIcon = $Action
    $button.LocaleCode = if ($Action -eq 'language-de') { 'de-DE' } elseif ($Action -eq 'language-en') { 'en-US' } else { '' }
    $button.Destructive = ($Action -eq 'system-remove')
    $button.Separator = [bool]$Separator
    $button.Text = Get-LocalizedString -Key $Key
    $button.AccessibleName = $button.Text
    $button.Font = $Form.Tag.Regular
    $button.TitleFont = $Form.Tag.Bold
    $button.SubtitleFont = $Form.Tag.Regular
    $button.ForeColor = $script:ColorPrimary
    $button.BackColor = [Drawing.Color]::FromArgb(37,37,37)
    $button.HoverSurface = $script:ColorHover
    $button.SelectedSurface = $script:ColorSelectedRow
    $button.AccentColor = $script:ColorAccent
    $button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.UseMnemonic = $false
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.Location = [Drawing.Point]::new($X,$Y)
    $height = if ($button.LocaleCode) { 38 } else { 52 }
    $button.Size = [Drawing.Size]::new($Width,$height)
    $button.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $Form.Tag.Body.Controls.Add($button)
}

# Width adaptation is configuration-local; the default picker retains its
# original geometry. Bounds are already scaled once by the auxiliary shell.
function Set-ConfigurationPopupWidth {
    param($Form,[double]$Scale)
    $body = $Form.Tag.Body
    $margin = [int][Math]::Round(16*$Scale)
    $width = [Math]::Max(2,$body.Width-2*$margin)
    $toggle = [Math]::Min([int][Math]::Round(64*$Scale),[int][Math]::Floor($width/3))
    $leftWidth = [Math]::Max(1,$width-$toggle)
    $half = [int][Math]::Floor($width/2)
    foreach ($control in $body.Controls) {
        $control.Left = $margin
        switch ($control.Name) {
            'ConfigurationLocale-Settings.Autostart' { $control.Width = $leftWidth }
            'ConfigurationAutostart' { $control.Left += $leftWidth; $control.Width = $toggle }
            'ConfigurationAction-language-de' { $control.Width = $half }
            'ConfigurationAction-language-en' { $control.Left += $half; $control.Width = $width-$half }
            default { $control.Width = $width }
        }
    }
}

function Update-ConfigurationPopupLocale {
    param([Windows.Forms.Form]$Form)
    $title = Get-LocalizedString -Key 'Settings.More'
    $Form.Text = $title
    $Form.AccessibleName = $title
    $Form.Tag.Title.Text = $title
    $subtitle = Get-LocalizedString -Key 'Settings.MoreSubtitle'
    $Form.Tag.Subtitle.Text = $subtitle
    $Form.Tag.Subtitle.AccessibleDescription = $subtitle
    $Form.Tag.Tip.SetToolTip($Form.Tag.Subtitle,$subtitle)
    $Form.Tag.Body.Controls['ConfigurationLocale-Settings.Autostart'].Subtitle = Get-LocalizedString -Key 'Settings.Detail.autostart'
    $Form.Tag.Close.AccessibleName = Get-LocalizedString -Key 'Common.Close'
    $Form.Tag.Tip.SetToolTip($Form.Tag.Close,(Get-LocalizedString -Key 'Tooltip.CloseSettings'))
    foreach ($control in $Form.Tag.Body.Controls) {
        if ($control.Name.StartsWith('ConfigurationLocale-')) {
            $control.Text = Get-LocalizedString -Key $control.Name.Substring('ConfigurationLocale-'.Length)
            $control.AccessibleName = $control.Text
        }
    }
    $Form.Tag.Body.Controls['ConfigurationAutostart'].AccessibleName = Get-LocalizedString -Key 'Settings.Autostart'
    Update-ConfigurationPopupPresentation -Form $Form
}

function New-ConfigurationPopup {
    $form = New-AuxiliaryPopupForm -Name 'LenovoConfigurationPopup' -Title (Get-LocalizedString -Key 'Settings.More') -Subtitle (Get-LocalizedString -Key 'Settings.MoreSubtitle') -ContentHeight 706
    $groupSurface = [Drawing.Color]::FromArgb(37,37,37)
    Add-ConfigurationHeading -Form $form -Key 'Settings.General' -Y 6
    $autostartLabel = New-Object LenovoSettingsAutostartLabel
    $autostartLabel.Name = 'ConfigurationLocale-Settings.Autostart'
    $autostartLabel.Tag = 'autostart'
    $autostartLabel.Text = Get-LocalizedString -Key 'Settings.Autostart'
    $autostartLabel.AccessibleName = $autostartLabel.Text
    $autostartLabel.Subtitle = Get-LocalizedString -Key 'Settings.Detail.autostart'
    $autostartLabel.Font = $form.Tag.Regular
    $autostartLabel.TitleFont = $form.Tag.Bold
    $autostartLabel.SubtitleFont = $form.Tag.Regular
    $autostartLabel.ForeColor = $script:ColorPrimary
    $autostartLabel.BackColor = $groupSurface
    $autostartLabel.HoverSurface = $script:ColorHover
    $autostartLabel.Location = [Drawing.Point]::new(16,32)
    $autostartLabel.Size = [Drawing.Size]::new(286,52)
    $autostartLabel.Cursor = [Windows.Forms.Cursors]::Hand
    $autostartLabel.Add_MouseDown({
        param($sender,$eventArgs)
        if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left -and (Test-ConfigurationActionAvailable -Action 'autostart')) {
            Set-LenovoPointerFocus -Control $sender.Parent.Controls['ConfigurationAutostart']
        }
    })
    $autostartLabel.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $form.Tag.Body.Controls.Add($autostartLabel)
    $check = New-Object LenovoSettingsToggle
    $check.Name = 'ConfigurationAutostart'
    $check.Tag = 'autostart'
    $check.AutoCheck = $false
    $check.AccessibleName = $autostartLabel.Text
    $check.Font = $form.Tag.Regular
    $check.BackColor = $groupSurface
    $check.HoverSurface = $script:ColorHover
    $check.AccentColor = $script:ColorAccent
    $check.Location = [Drawing.Point]::new(302,32)
    $check.Size = [Drawing.Size]::new(64,52)
    $check.Add_Click({ param($sender,$eventArgs) Invoke-ConfigurationPopupAction -Control $sender })
    $form.Tag.Body.Controls.Add($check)
    [void][LenovoSettingsAutostartHover]::new($autostartLabel,$check)
    $language = New-Label -Text (Get-LocalizedString -Key 'Settings.Language') -Font $form.Tag.Bold -ForeColor $script:ColorPrimary -X 16 -Y 90 -Width 350 -Height 24
    $language.Name = 'ConfigurationLocale-Settings.Language'
    $form.Tag.Body.Controls.Add($language)
    Add-ConfigurationActionButton -Form $form -Action 'language-de' -Key 'Language.German' -Y 116 -Width 175
    Add-ConfigurationActionButton -Form $form -Action 'language-en' -Key 'Language.English' -Y 116 -X 191 -Width 175
    Add-ConfigurationHeading -Form $form -Key 'Preferences.Heading' -Y 164
    Add-ConfigurationActionButton -Form $form -Action 'preferences-export' -Key 'Preferences.Export' -Y 188 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'preferences-import' -Key 'Preferences.Import' -Y 240
    Add-ConfigurationHeading -Form $form -Key 'Maintenance.Caption' -Y 300
    Add-ConfigurationActionButton -Form $form -Action 'system-setup' -Key 'Maintenance.Setup' -Y 324 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'system-remove' -Key 'Maintenance.Remove' -Y 376
    Add-ConfigurationHeading -Form $form -Key 'Settings.Updates' -Y 436
    Add-ConfigurationActionButton -Form $form -Action 'update-check' -Key 'Update.Check' -Y 460 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'update-install' -Key 'Update.Install' -Y 512
    Add-ConfigurationHeading -Form $form -Key 'Settings.Diagnostics' -Y 572
    Add-ConfigurationActionButton -Form $form -Action 'diagnostics-save' -Key 'Diagnostics.Save' -Y 596 -Separator
    Add-ConfigurationActionButton -Form $form -Action 'diagnostics-upload' -Key 'Diagnostics.Upload' -Y 648
    Update-ConfigurationPopupPresentation -Form $form
    # Reflect existing presentation state only; do not poll firmware/network.
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        if ($script:ActiveAuxiliaryPopup -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoConfigurationPopup') {
            Update-ConfigurationPopupPresentation -Form $script:ActiveAuxiliaryPopup
        }
    })
    $form.Tag.Timer = $timer
    $form.Add_Shown({ $this.Tag.Timer.Start() })
    return $form
}

function Show-ConfigurationPopup {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or $script:IsManageEntriesMode -or (Test-MaintenanceBusy)) { return }
    [void](Update-TaskBrokerUiState -Fast)
    [void](Update-AutostartUi)
    Update-UpdateMenuState
    Update-LanguageMenuState
    [void](Show-OwnedAuxiliaryPopup -Form (New-ConfigurationPopup) -Owner $Owner)
}
