# LBS-144: regular modal forms have 96-DPI *pixel* geometry but
# typographic point-unit fonts. Do not reuse the popup's script-global
# design metric cache and never multiply Font.Size by the monitor factor.
# All controls are new and scaled exactly once before ShowDialog().
# Calculate a visible top-left in the SAME WinForms coordinate space as the
# selected Screen.WorkingArea, including negative-origin external displays.
function Get-LenovoVisibleDialogLocation {
    param(
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea,
        [Parameter(Mandatory=$true)][Drawing.Size]$WindowSize
    )
    if ($WorkingArea.Width -le 0 -or $WorkingArea.Height -le 0 -or
        $WindowSize.Width -le 0 -or $WindowSize.Height -le 0) {
        throw 'Invalid dialog work-area or size.'
    }
    $centerX = [int][Math]::Floor($WorkingArea.Left + ($WorkingArea.Width - $WindowSize.Width) / 2.0)
    $centerY = [int][Math]::Floor($WorkingArea.Top + ($WorkingArea.Height - $WindowSize.Height) / 2.0)
    $maxX = [Math]::Max($WorkingArea.Left, $WorkingArea.Right - $WindowSize.Width)
    $maxY = [Math]::Max($WorkingArea.Top, $WorkingArea.Bottom - $WindowSize.Height)
    return [Drawing.Point]::new(
        [int][Math]::Min($maxX,[Math]::Max($WorkingArea.Left,$centerX)),
        [int][Math]::Min($maxY,[Math]::Max($WorkingArea.Top,$centerY)))
}

# The pre-Show WinForms size/position can change when the native HWND is
# created (host MaxWindowTrackSize, mixed-DPI and monitor selection).
# Clamp once again inside Shown, before the existing physical DWM snapshot.
function Register-LenovoDialogVisibilityCorrection {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][System.Windows.Forms.Screen]$Screen
    )
    $screenCopy = $Screen
    $Form.Add_Shown({
        if ($this.IsDisposed) { return }
        $this.Location = Get-LenovoVisibleDialogLocation -WorkingArea $screenCopy.WorkingArea -WindowSize $this.Size
        if ($this.Visible) { [void]$this.Activate() }
    }.GetNewClosure())
}

function Get-LenovoDialogScaledSize {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$DesignSize,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid dialog DPI scale.' }
    return [Drawing.Size]::new(
        [Math]::Max(1,[int][Math]::Round($DesignSize.Width * $Scale,[MidpointRounding]::AwayFromZero)),
        [Math]::Max(1,[int][Math]::Round($DesignSize.Height * $Scale,[MidpointRounding]::AwayFromZero)))
}

# Shared regular modal presentation; the form's Tag still belongs to its caller.
function Initialize-LenovoRegularDialog {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Panel]$Root,
        [Windows.Forms.Label]$Title,[Windows.Forms.Panel]$Divider,
        [Windows.Forms.Label]$Glyph,[Windows.Forms.Control[]]$Content,
        [Windows.Forms.Button[]]$Buttons)
    $Root.Dock=[Windows.Forms.DockStyle]::Fill
    $Root.BackColor = [Drawing.Color]::FromArgb(31,31,31)
    $Form.BackColor = $Root.BackColor
    $Form.Text = $Title.Text
    $Form.AccessibleName = $Title.Text
    $header = New-Object Windows.Forms.Panel
    $header.Name='DialogHeader'
    $header.BackColor=[Drawing.Color]::FromArgb(9,9,9)
    $Title.Name='DialogTitle'
    $Title.UseMnemonic=$false
    $Title.BackColor=$header.BackColor
    $header.Controls.Add($Title)
    $header.Controls.Add($Divider)
    $viewport = New-Object Windows.Forms.Panel
    $viewport.Name='DialogViewport'
    $viewport.BackColor=$Root.BackColor
    $body = New-Object Windows.Forms.Panel
    $body.Name='DialogBody'
    $body.BackColor=$Root.BackColor
    if ($Glyph) { $body.Controls.Add($Glyph); $Glyph.Name='DialogGlyph' }
    foreach ($control in $Content) {
        if ($control -is [Windows.Forms.Label]) { $control.UseMnemonic=$false }
        $body.Controls.Add($control)
    }
    $viewport.Controls.Add($body)
    $footer = New-Object Windows.Forms.Panel
    $footer.Name='DialogActions'
    $footer.BackColor=[Drawing.Color]::FromArgb(24,24,24)
    # Reparenting a button clears WinForms' accept/cancel reference. Preserve
    # the actual existing default actions after the new parent is attached.
    $accept=$Form.AcceptButton
    $cancel=$Form.CancelButton
    foreach ($button in $Buttons) { $footer.Controls.Add($button) }
    $Root.Controls.Add($header)
    $Root.Controls.Add($viewport)
    $Root.Controls.Add($footer)
    $Form.AcceptButton=$accept
    $Form.CancelButton=$cancel
    $scroll=$null
    # Production reuses the main/auxiliary red/dark scrollbar. Isolated hosts
    # without that control type retain a content-only native scroll fallback.
    if ('LenovoVerticalScrollBar' -as [type]) {
        $scroll=New-Object LenovoVerticalScrollBar
        $scroll.Name='DialogScroll'
        $scroll.TrackColor=[Drawing.Color]::FromArgb(23,23,23)
        $scroll.ThumbColor=$script:ColorAccent
        $scroll.ThumbHoverColor=[LenovoInteractionPalette]::Hover
        $scroll.Visible=$false
        $viewport.Controls.Add($scroll)
        $scroll.Add_ValueChanged({ $body.Top=-$scroll.Value }.GetNewClosure())
        $wheel = {
            param($sender,$eventArgs)
            if (-not $scroll.Visible -or -not $eventArgs.Delta) { return }
            if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) {
                if ($eventArgs.Handled) { return }
                $eventArgs.Handled=$true
            }
            $scroll.Value -= [int]([Math]::Sign($eventArgs.Delta)*$scroll.SmallChange)
        }.GetNewClosure()
        $Form.Add_KeyDown({
            param($sender,$eventArgs)
            if (-not $scroll.Visible) { return }
            switch ($eventArgs.KeyCode) {
                ([Windows.Forms.Keys]::PageUp) { $scroll.Value -= $scroll.LargeChange }
                ([Windows.Forms.Keys]::PageDown) { $scroll.Value += $scroll.LargeChange }
                ([Windows.Forms.Keys]::Home) { if (-not $eventArgs.Control) { return }; $scroll.Value=0 }
                ([Windows.Forms.Keys]::End) { if (-not $eventArgs.Control) { return }; $scroll.Value=$scroll.Maximum }
                default { return }
            }
            $eventArgs.Handled=$true
            $eventArgs.SuppressKeyPress=$true
        }.GetNewClosure())
        foreach ($control in (@($viewport,$body,$Glyph)+@($Content))) {
            if ($control) { $control.Add_MouseWheel($wheel) }
        }
    }
    $Root.Tag=[pscustomobject]@{Kind='LenovoRegularDialog';Header=$header;Title=$Title;Divider=$Divider;Viewport=$viewport;Body=$body;Glyph=$Glyph;Content=$Content;Footer=$footer;Buttons=$Buttons;Scroll=$scroll}
}

function Set-LenovoRegularDialogDpiLayout {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Panel]$Root,[double]$Scale,[Drawing.Rectangle]$WorkingArea)
    $s=$Root.Tag
    function Px([double]$value) { [Math]::Max(1,[int][Math]::Round($value*$Scale)) }
    $Form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None
    $track=[Windows.Forms.SystemInformation]::MaxWindowTrackSize
    $maxWidth=[Math]::Min($WorkingArea.Width,$track.Width)
    $maxHeight=[Math]::Min($WorkingArea.Height,$track.Height)
    $width=[Math]::Min((Px 500),$maxWidth)
    $pad=Px 20
    $gap=Px 10
    $bitmap=New-Object Drawing.Bitmap(8,8)
    try {
        $bitmap.SetResolution([single](96*$Scale),[single](96*$Scale))
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            function LabelHeight($label,[int]$w) {
                $label.UseCompatibleTextRendering=$true
                $label.AutoEllipsis=$false
                $label.AutoSize=$false
                $measured=$graphics.MeasureString([string]$label.Text,$label.Font,[Math]::Max(1,$w))
                return [Math]::Max((Px 22),[int][Math]::Ceiling($measured.Height)+(Px 6))
            }
            $headerHeight=[Math]::Max((Px 49),((LabelHeight $s.Title ($width-2*$pad))+(Px 20)))
            $buttonHeight=Px 34
            $buttonWidths=@()
            foreach ($button in $s.Buttons) {
                $labels=@([string]$button.Text)
                if ($button.Tag -is [string[]]) { $labels+=@($button.Tag) }
                $maxText=0
                foreach ($label in $labels) { $maxText=[Math]::Max($maxText,[int][Math]::Ceiling($graphics.MeasureString($label,$button.Font).Width)) }
                $buttonWidths+= [Math]::Min(($width-2*$pad),[Math]::Max((Px 110),($maxText+(Px 24))))
            }
            $total=0
            foreach ($w in $buttonWidths) { $total+=$w }
            $total+=$gap*[Math]::Max(0,$s.Buttons.Count-1)
            $stacked=$total -gt ($width-2*$pad)
            $footerHeight=if ($stacked) { (Px 22)+$s.Buttons.Count*$buttonHeight+($s.Buttons.Count-1)*$gap } else { $buttonHeight+(Px 22) }
            $available=[Math]::Max(1,$maxHeight-$headerHeight-$footerHeight)
            $bodyWidth=$width
            $gutter=0
            $contentHeight=0
            for ($pass=0;$pass -lt 2;$pass++) {
                $bodyWidth=$width-$gutter
                $y=Px 16
                $first=$true
                foreach ($control in $s.Content) {
                    $left=$pad
                    if ($first -and $s.Glyph) { $left+=(Px 40) }
                    $cw=[Math]::Max(1,$bodyWidth-$left-$pad)
                    $ch=LabelHeight $control $cw
                    $control.Bounds=[Drawing.Rectangle]::new($left,$y,$cw,$ch)
                    if ($first -and $s.Glyph) {
                        $s.Glyph.Bounds=[Drawing.Rectangle]::new($pad,$y,(Px 30),(Px 34))
                        $ch=[Math]::Max($ch,(Px 34))
                    }
                    $y+=$ch+(Px 6)
                    $first=$false
                }
                $contentHeight=$y+(Px 10)
                if ($contentHeight -le $available -or $pass -eq 1) { break }
                $gutter=if ($s.Scroll) { Px 12 } else { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
            }
            $viewportHeight=[Math]::Min($available,$contentHeight)
            $Form.ClientSize=[Drawing.Size]::new($width,($headerHeight+$viewportHeight+$footerHeight))
            $s.Header.Bounds=[Drawing.Rectangle]::new(0,0,$width,$headerHeight)
            $s.Title.Bounds=[Drawing.Rectangle]::new($pad,(Px 9),($width-2*$pad),($headerHeight-(Px 19)))
            $s.Divider.Bounds=[Drawing.Rectangle]::new(0,($headerHeight-(Px 2)),$width,(Px 2))
            $s.Viewport.Bounds=[Drawing.Rectangle]::new(0,$headerHeight,$width,$viewportHeight)
            $s.Body.Bounds=[Drawing.Rectangle]::new(0,0,$bodyWidth,$contentHeight)
            $s.Footer.Bounds=[Drawing.Rectangle]::new(0,($headerHeight+$viewportHeight),$width,$footerHeight)
            if ($s.Scroll) {
                $s.Scroll.Bounds=[Drawing.Rectangle]::new(($width-(Px 10)),0,(Px 10),$viewportHeight)
                $s.Scroll.Maximum=[Math]::Max(0,$contentHeight-$viewportHeight)
                $s.Scroll.LargeChange=$viewportHeight
                $s.Scroll.SmallChange=Px 60
                $s.Scroll.Value=0
                $s.Scroll.Visible=$s.Scroll.Maximum -gt 0
                $s.Scroll.BringToFront()
            } else {
                $s.Viewport.AutoScroll=$contentHeight -gt $viewportHeight
                if ($s.Viewport.AutoScroll) { $s.Viewport.AutoScrollMinSize=[Drawing.Size]::new($bodyWidth,$contentHeight) }
            }
            $x=if ($stacked) { $pad } else { $width-$pad-$total }
            $y=Px 11
            for ($i=0;$i -lt $s.Buttons.Count;$i++) {
                $bw=if ($stacked) { $width-2*$pad } else { $buttonWidths[$i] }
                $s.Buttons[$i].Bounds=[Drawing.Rectangle]::new($x,$y,$bw,$buttonHeight)
                if ($stacked) { $y+=$buttonHeight+$gap } else { $x+=$bw+$gap }
            }
        } finally { $graphics.Dispose() }
    } finally { $bitmap.Dispose() }
    $Form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
    $Form.Location=Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
}

function Set-LenovoDialogDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid dialog DPI scale.' }
    if ($WorkingArea.Width -le 0 -or $WorkingArea.Height -le 0) { throw 'Invalid dialog work area.' }
    $regularRoot = $Form.Controls | Where-Object { $_ -is [Windows.Forms.Panel] -and $_.Tag -and $_.Tag.Kind -eq 'LenovoRegularDialog' } | Select-Object -First 1
    if ($regularRoot) {
        Set-LenovoRegularDialogDpiLayout -Form $Form -Root $regularRoot -Scale $Scale -WorkingArea $WorkingArea
        return
    }
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $baseline = $Form.ClientSize
    $pending = New-Object System.Collections.Stack
    $pending.Push($Form)
    $entries = New-Object 'System.Collections.Generic.List[object]'
    while ($pending.Count -gt 0) {
        $control = [System.Windows.Forms.Control]$pending.Pop()
        $entries.Add([pscustomobject]@{
            Control = $control
            Bounds = $control.Bounds
            Padding = $control.Padding
            Margin = $control.Margin
            Dock = $control.Dock
        })
        foreach ($child in $control.Controls) { $pending.Push($child) }
    }
    foreach ($entry in $entries) { $entry.Control.SuspendLayout() }
    try {
        foreach ($entry in $entries) {
            $control = [System.Windows.Forms.Control]$entry.Control
            if ([object]::ReferenceEquals($control, $Form)) { continue }
            if ($entry.Dock -eq [System.Windows.Forms.DockStyle]::None) {
                $r = $entry.Bounds
                $control.Bounds = [Drawing.Rectangle]::new(
                    [int][Math]::Round($r.Left * $Scale),
                    [int][Math]::Round($r.Top * $Scale),
                    [Math]::Max(1,[int][Math]::Round($r.Width * $Scale)),
                    [Math]::Max(1,[int][Math]::Round($r.Height * $Scale)))
            }
            $p = $entry.Padding
            $control.Padding = [System.Windows.Forms.Padding]::new(
                [int][Math]::Round($p.Left * $Scale),[int][Math]::Round($p.Top * $Scale),
                [int][Math]::Round($p.Right * $Scale),[int][Math]::Round($p.Bottom * $Scale))
            $m = $entry.Margin
            $control.Margin = [System.Windows.Forms.Padding]::new(
                [int][Math]::Round($m.Left * $Scale),[int][Math]::Round($m.Top * $Scale),
                [int][Math]::Round($m.Right * $Scale),[int][Math]::Round($m.Bottom * $Scale))
        }
        $desired = Get-LenovoDialogScaledSize -DesignSize $baseline -Scale $Scale
        $Form.ClientSize = $desired
        # WinForms may cap an unshown borderless form to the actual desktop
        # MaxWindowTrackSize (small CI displays). Preserve access to every
        # scaled control through the root panel's scrollable virtual client.
        foreach ($entry in $entries) {
            $control = [System.Windows.Forms.Control]$entry.Control
            if ([object]::ReferenceEquals($control.Parent, $Form) -and $control -is [System.Windows.Forms.Panel]) {
                $control.Dock = [System.Windows.Forms.DockStyle]::Fill
            }
        }
        $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $Form.Location = Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
    }
    finally {
        for ($i = $entries.Count - 1; $i -ge 0; $i--) {
            $entries[$i].Control.ResumeLayout($true)
        }
    }
    # An unshown WinForms form may only adopt the system's MaxWindowTrackSize
    # *after* ResumeLayout. Check the resulting client here, not before.
    if ($Form.ClientSize.Width -lt $desired.Width -or $Form.ClientSize.Height -lt $desired.Height) {
        foreach ($control in $Form.Controls) {
            if ($control -is [System.Windows.Forms.Panel]) {
                $control.AutoScroll = $true
                $control.AutoScrollMinSize = $desired
            }
        }
    }
}

function Prepare-LenovoDialogDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Form]$Owner,
        [string]$Role = 'regular-modal'
    )
    $screen = if ($Owner -and -not $Owner.IsDisposed -and $Owner.Visible) {
        [System.Windows.Forms.Screen]::FromControl($Owner)
    }
    # Without a visible owner, use the stable primary display rather than
    # a possibly DPI-virtualized cursor coordinate on a secondary monitor.
    else { [System.Windows.Forms.Screen]::PrimaryScreen }
    if (-not $screen) { $screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    $scale = Get-LenovoUiCoordinateScale -Screen $screen
    Set-LenovoDialogDpiLayout -Form $Form -Scale ([double]$scale.Factor) -WorkingArea $screen.WorkingArea
    Register-LenovoDialogVisibilityCorrection -Form $Form -Screen $screen
    Write-LenovoMonitorTopologyEvent -Phase ('before-' + $Role) -Screen $screen
    Register-LenovoDialogDpiWindowDiagnostics -Form $Form -Role $Role -Screen $screen -RequestedScale ([double]$scale.Factor)
}

# Resolve the deepest visible modal owner at display time, not at worker start.
# Closing settings during a worker does not reopen it or an abandoned main popup.
function Get-LenovoDialogOwner {
    foreach ($candidate in @($script:ActiveOwnedDialog,$script:ActiveAuxiliaryPopup,$script:Popup)) {
        if ($candidate -and -not $candidate.IsDisposed -and $candidate.Visible) { return $candidate }
    }
    return $null
}

function Show-LenovoOwnedDialog {
    param([Windows.Forms.Form]$Form,[Windows.Forms.Form]$Owner)
    $previous = $script:ActiveOwnedDialog
    $dimmer = $null
    $auxiliaryOwner = $null
    $returnFocus = $null
    if ($Owner -and -not $Owner.IsDisposed -and [object]::ReferenceEquals($Owner,$script:ActiveAuxiliaryPopup)) {
        $auxiliaryOwner = $Owner
        $returnFocus = $Owner.Tag.Body.Controls | Where-Object { $_.Focused } | Select-Object -First 1
    }
    $script:ActiveOwnedDialog = $Form
    try {
        if ($Owner -and -not $Owner.IsDisposed -and $Owner.Visible) {
            # The main owner's existing scrim remains alive; dim the immediate
            # modal owner only, without a navigation cutout or connector.
            if ($script:ActiveAuxiliaryPopup) {
                if ($auxiliaryOwner) { $auxiliaryOwner.Tag.Close.Refresh() }
                Initialize-AuxiliaryOwnerDimmer
                $dimmer = [LenovoAuxiliaryOwnerDimmer]::new($Owner,$null,$Form,1.0,$script:ColorHover,$script:ColorAccent)
                $dimmer.Show($Owner)
            }
            return $Form.ShowDialog($Owner)
        }
        return $Form.ShowDialog()
    }
    finally {
        try { if ($dimmer) { $dimmer.Dispose() } }
        finally {
            $script:ActiveOwnedDialog = $previous
            if ($auxiliaryOwner -and -not $auxiliaryOwner.IsDisposed -and $auxiliaryOwner.Visible -and
                [object]::ReferenceEquals($auxiliaryOwner,$script:ActiveAuxiliaryPopup)) {
                if ($returnFocus -and -not $returnFocus.IsDisposed -and $returnFocus.CanFocus -and
                    $auxiliaryOwner.ContainsFocus) { [void]$returnFocus.Focus() }
                $auxiliaryOwner.Tag.Close.Refresh()
            }
        }
    }
}

function Show-LenovoNoticeDialog {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Heading,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error')][string]$Kind = 'Info',
        [string]$SecondaryButtonText,
        [scriptblock]$SecondaryAction,
        [switch]$PromoteSecondaryAction,
        [string]$DismissButtonText,
        [string]$ValueCaption,
        [string]$ValueText,
        [switch]$KeepOpenAfterSecondary
    )

    # Only the available-update notice promotes the optional action.
    # Require a named safe dismissal so Enter/Escape cannot install by default.
    if ($PromoteSecondaryAction -and
        ([string]::IsNullOrWhiteSpace($SecondaryButtonText) -or
         -not $SecondaryAction -or
         [string]::IsNullOrWhiteSpace($DismissButtonText))) {
        throw 'Promoted notice actions require explicit install and dismiss labels.'
    }

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(470, 245)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $titleLabel = New-Label -Text $Title -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 420 -Height 24
    $root.Controls.Add($titleLabel)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(434,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyphText = if ($Kind -eq 'Success') { '✓' } elseif ($Kind -eq 'Error') { '×' } elseif ($Kind -eq 'Warning') { '!' } else { 'i' }
    $glyphColor = if ($Kind -eq 'Success') { [Drawing.Color]::FromArgb(104,206,141) } elseif ($Kind -eq 'Error') { $script:ColorAccent } elseif ($Kind -eq 'Warning') { $script:ColorWarning } else { $script:ColorCyan }
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $headingLabel = New-Label -Text $Heading -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 380 -Height 24
    $root.Controls.Add($headingLabel)
    $messageLabel = New-Label -Text $Message -Font (New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 88 -Width 380 -Height 78
    $messageLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($messageLabel)
    $headingLabel.Name='DialogHeading'
    $messageLabel.Name='DialogMessage'
    $content=@($headingLabel)
    if ($ValueCaption -and $ValueText) {
        $caption=New-Label -Text $ValueCaption -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorSecondary -X 20 -Y 0 -Width 460 -Height 24
        $caption.Name='DialogValueCaption'
        $caption.BackColor=[Drawing.Color]::FromArgb(21,21,21)
        $value=New-Label -Text $ValueText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 20 -Y 0 -Width 460 -Height 24
        $value.Name='DialogValue'
        $value.AccessibleName=$ValueCaption
        $value.AccessibleDescription=$ValueText
        $value.BackColor=$caption.BackColor
        $content+=@($caption,$value)
    }
    $content+=@($messageLabel)
    $secondary=$null

    if (-not [string]::IsNullOrWhiteSpace($SecondaryButtonText) -and $SecondaryAction) {
        $secondary = New-Object LenovoActionButton
        $secondary.Text = $SecondaryButtonText
        $secondary.Font = if ($PromoteSecondaryAction) {
            New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold)
        } else { New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular) }
        $secondary.ForeColor = if ($PromoteSecondaryAction) { [Drawing.Color]::White } else { $script:ColorPrimary }
        $secondary.BackColor = if ($PromoteSecondaryAction) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(34,34,34) }
        $secondary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $secondary.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
        $secondary.FlatAppearance.BorderSize = if ($PromoteSecondaryAction) { 0 } else { 1 }
        $secondary.FlatAppearance.MouseOverBackColor = if ($PromoteSecondaryAction) { $script:ColorAccent } else { [Drawing.Color]::FromArgb(46,46,46) }
        $secondary.FlatAppearance.MouseDownBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(185,30,22) } else { [Drawing.Color]::FromArgb(38,38,38) }
        $secondary.Location = if ($PromoteSecondaryAction) { New-Object Drawing.Point(306,190) } else { New-Object Drawing.Point(184,190) }
        $secondary.Size = New-Object Drawing.Size(146,34)
        $secondary.TabIndex = if ($PromoteSecondaryAction) { 1 } else { 0 }
        $secondary.Cursor = [System.Windows.Forms.Cursors]::Hand
        $secondaryActionLocal = $SecondaryAction
        $dialogLocal = $form
        $keepOpenLocal=[bool]$KeepOpenAfterSecondary
        $copiedText=if ($keepOpenLocal) { Get-LocalizedString -Key 'Diagnostics.Copied' } else { '' }
        $copyFailedText=if ($keepOpenLocal) { Get-LocalizedString -Key 'Diagnostics.CopyFailed' } else { '' }
        $originalText=$secondary.Text
        $originalColor=$secondary.ForeColor
        if ($keepOpenLocal) {
            $secondary.Tag=[string[]]@($copiedText,$copyFailedText)
            $feedbackTimer=New-Object Windows.Forms.Timer
            $feedbackTimer.Interval=2000
            $copyButton=$secondary
            $feedbackTimer.Add_Tick({
                $feedbackTimer.Stop()
                if (-not $copyButton.IsDisposed) {
                    $copyButton.Text=$originalText
                    $copyButton.ForeColor=$originalColor
                    $copyButton.AccessibleDescription=''
                }
            }.GetNewClosure())
            $form.Add_Disposed({ $feedbackTimer.Stop(); $feedbackTimer.Dispose() }.GetNewClosure())
        }
        $secondary.Add_Click({
            param($sender,$eventArgs)
            try {
                $result = & $secondaryActionLocal
                if ($keepOpenLocal) {
                    $confirmed=($result -eq $true)
                    $sender.Text=if ($confirmed) { $copiedText } else { $copyFailedText }
                    $sender.ForeColor=if ($confirmed) { [Drawing.Color]::FromArgb(104,206,141) } else { [Drawing.Color]::FromArgb(236,191,68) }
                    $sender.AccessibleDescription=$sender.Text
                    $feedbackTimer.Stop()
                    $feedbackTimer.Start()
                } elseif ($result -ne $false) {
                    $dialogLocal.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $dialogLocal.Close()
                }
            } catch {
                if ($keepOpenLocal) {
                    $sender.Text=$copyFailedText
                    $sender.ForeColor=[Drawing.Color]::FromArgb(236,191,68)
                    $sender.AccessibleDescription=$copyFailedText
                    $feedbackTimer.Stop()
                    $feedbackTimer.Start()
                }
            }
        }.GetNewClosure())
        $root.Controls.Add($secondary)
    }

    $ok = New-Object LenovoActionButton
    $ok.Text = if ($PromoteSecondaryAction) { $DismissButtonText } else { Get-LocalizedString -Key 'Common.OK' }
    $ok.Font = if ($PromoteSecondaryAction) {
        New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
    } else { New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold) }
    $ok.ForeColor = if ($PromoteSecondaryAction) { $script:ColorPrimary } else { [Drawing.Color]::White }
    $ok.BackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(34,34,34) } else { $script:ColorAccent }
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $ok.FlatAppearance.BorderSize = if ($PromoteSecondaryAction) { 1 } else { 0 }
    $ok.FlatAppearance.MouseOverBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(46,46,46) } else { $script:ColorAccent }
    $ok.FlatAppearance.MouseDownBackColor = if ($PromoteSecondaryAction) { [Drawing.Color]::FromArgb(38,38,38) } else { [Drawing.Color]::FromArgb(185,30,22) }
    $ok.Location = if ($PromoteSecondaryAction) { New-Object Drawing.Point(184,190) } else { New-Object Drawing.Point(342,190) }
    $ok.Size = New-Object Drawing.Size(110,34)
    $ok.TabIndex = if ($PromoteSecondaryAction) { 0 } else { 1 }
    $ok.Cursor = [System.Windows.Forms.Cursors]::Hand
    $ok.DialogResult = if ($PromoteSecondaryAction) { [System.Windows.Forms.DialogResult]::Cancel } else { [System.Windows.Forms.DialogResult]::OK }
    $root.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $ok
    $buttons=if ($secondary) {
        if ($PromoteSecondaryAction) { @($ok,$secondary) } else { @($secondary,$ok) }
    } else { @($ok) }
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $titleLabel -Divider $divider -Glyph $glyph -Content $content -Buttons $buttons
    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'notice'
        if ($PromoteSecondaryAction) {
            # Safe dismissal receives initial focus even if the native tab
            # traversal order or owner activation changes during ShowDialog.
            $dismissButtonLocal = $ok
            $form.Add_Shown({
                if (-not $dismissButtonLocal.IsDisposed -and $dismissButtonLocal.CanFocus) {
                    [void]$dismissButtonLocal.Focus()
                }
            }.GetNewClosure())
        }
        [void](Show-LenovoOwnedDialog -Form $form -Owner $owner)
    }
    finally { $form.Dispose() }
}

function Show-LocaleMigrationDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, 260)
    $form.KeyPreview = $true
    $form.Tag = $null

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $title = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationTitle') -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $heading = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationHeading') -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 28 -Y 62 -Width 440 -Height 24
    $root.Controls.Add($heading)
    $message = New-Label -Text (Get-LocalizedString -Key 'Language.MigrationMessage') -Font (New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 28 -Y 92 -Width 440 -Height 92
    $message.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($message)

    $german = New-Object LenovoActionButton
    $german.Text = Get-LocalizedString -Key 'Language.MigrationKeepGerman'
    $german.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)
    $german.ForeColor = $script:ColorPrimary
    $german.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $german.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $german.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $german.FlatAppearance.BorderSize = 1
    $german.Location = New-Object Drawing.Point(196,204)
    $german.Size = New-Object Drawing.Size(136,34)
    $german.Cursor = [System.Windows.Forms.Cursors]::Hand
    $german.Add_Click({ $form.Tag = 'de-DE'; $form.Close() })
    $root.Controls.Add($german)

    $english = New-Object LenovoActionButton
    $english.Text = Get-LocalizedString -Key 'Language.MigrationUseEnglish'
    $english.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Bold)
    $english.ForeColor = [Drawing.Color]::White
    $english.BackColor = $script:ColorAccent
    $english.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $english.FlatAppearance.BorderSize = 0
    $english.Location = New-Object Drawing.Point(344,204)
    $english.Size = New-Object Drawing.Size(136,34)
    $english.Cursor = [System.Windows.Forms.Cursors]::Hand
    $english.Add_Click({ $form.Tag = 'en-US'; $form.Close() })
    $root.Controls.Add($english)
    $form.AcceptButton = $english
    $heading.Name='DialogHeading'
    $message.Name='DialogMessage'
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Content @($heading,$message) -Buttons @($german,$english)

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'language-migration'
        [void](Show-LenovoOwnedDialog -Form $form -Owner $owner)
        return [string]$form.Tag
    }
    finally { $form.Dispose() }
}

function Show-LenovoSystemFunctionsDialog {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)

    $isRemove = ($Mode -eq 'Remove')
    $height = if ($isRemove) { 330 } else { 270 }
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, $height)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    if ($Mode -eq 'Remove') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.RemoveBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Remove'
        $glyphText = '!'
        $glyphColor = $script:ColorWarning
    }
    elseif ($Mode -eq 'Repair') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Repair'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Migrate') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.RepairTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.MigrateHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.MigrateBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Repair'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Reinitialize') {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.ReinitializeBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Reinitialize'
        $glyphText = '+'
        $glyphColor = $script:ColorCyan
    }
    else {
        $titleText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupTitle'
        $headingText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupHeading'
        $bodyText = Get-LocalizedString -Key 'Maintenance.Dialog.SetupBody'
        $primaryText = Get-LocalizedString -Key 'Maintenance.Action.Setup'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }

    $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI',15.0,[Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)
    $heading = New-Label -Text $headingText -Font (New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 410 -Height 24
    $root.Controls.Add($heading)
    $bodyHeight = if ($isRemove) { 145 } else { 90 }
    $body = New-Label -Text $bodyText -Font (New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 90 -Width 410 -Height $bodyHeight
    $body.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($body)

    $buttonY = $height - 54
    $cancel = New-Object LenovoActionButton
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.Location = New-Object Drawing.Point(272,$buttonY)
    $cancel.Size = New-Object Drawing.Size(100,34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $primary = New-Object LenovoActionButton
    $primary.Text = $primaryText
    $primary.Font = New-Object Drawing.Font('Segoe UI',9.5,[Drawing.FontStyle]::Bold)
    $primary.ForeColor = [Drawing.Color]::White
    $primary.BackColor = $script:ColorAccent
    $primary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $primary.FlatAppearance.BorderSize = 0
    $primary.FlatAppearance.MouseOverBackColor = $script:ColorAccent
    $primary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $primary.Location = New-Object Drawing.Point(382,$buttonY)
    $primary.Size = New-Object Drawing.Size(100,34)
    $primary.Cursor = [System.Windows.Forms.Cursors]::Hand
    $primary.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($primary)
    $heading.Name='DialogHeading'
    $body.Name='DialogMessage'
    $content=@($heading,$body)
    if ($isRemove) {
        # Split the existing three localized paragraphs without losing their facts.
        $paragraphs=$bodyText -split '\r?\n\r?\n'
        if ($paragraphs.Count -eq 3) {
            $changes=New-Label -Text (Get-LocalizedString -Key 'Maintenance.Dialog.Changes') -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorWarning -X 20 -Y 0 -Width 460 -Height 24
            $changes.BackColor=[Drawing.Color]::FromArgb(48,40,29)
            $body.Text=$paragraphs[0]+[Environment]::NewLine+$paragraphs[1]
            $body.BackColor=$changes.BackColor
            $retained=New-Label -Text (Get-LocalizedString -Key 'Maintenance.Dialog.Retained') -Font (New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)) -ForeColor ([Drawing.Color]::FromArgb(104,206,141)) -X 20 -Y 0 -Width 460 -Height 24
            $retained.BackColor=[Drawing.Color]::FromArgb(32,44,36)
            $retainedBody=New-Label -Text $paragraphs[2] -Font (New-Object Drawing.Font('Segoe UI',9.5)) -ForeColor $script:ColorSecondary -X 20 -Y 0 -Width 460 -Height 24
            $retainedBody.BackColor=$retained.BackColor
            $content=@($heading,$changes,$body,$retained,$retainedBody)
        }
    }
    $form.AcceptButton = $primary
    $form.CancelButton = $cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Glyph $glyph -Content $content -Buttons @($cancel,$primary)
    $form.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'system-functions'
        return (Show-LenovoOwnedDialog -Form $form -Owner $owner)
    }
    finally { $form.Dispose() }
}

function Show-LenovoRestartDialog {
    param([Parameter(Mandatory=$true)][string]$TargetName)

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.ClientSize = New-Object Drawing.Size(430, 240)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'RestartDialogRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(430, 240)
    $root.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.Controls.Add($root)

    $title = New-Label -Text (Get-LocalizedString -Key 'Restart.DialogTitle') -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 330 -Height 24
    $root.Controls.Add($title)

    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18, 43)
    $divider.Size = New-Object Drawing.Size(390, 1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyph = New-Label -Text '!' -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorWarning -X 18 -Y 58 -Width 26 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $question = New-Label -Text (Get-LocalizedString -Key 'Restart.Question') -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 58 -Width 340 -Height 24
    $root.Controls.Add($question)

    $targetCaption = New-Label -Text (Get-LocalizedString -Key 'Restart.NextTarget') -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 54 -Y 92 -Width 330 -Height 18
    $root.Controls.Add($targetCaption)

    $target = New-Label -Text $TargetName -Font (New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 109 -Width 342 -Height 24
    $target.AutoEllipsis = $true
    $root.Controls.Add($target)

    $cancel = New-Object LenovoActionButton
    $cancel.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancel.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(28,28,28)
    $cancel.Location = New-Object Drawing.Point(206, 180)
    $cancel.Size = New-Object Drawing.Size(96, 34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $restart = New-Object LenovoActionButton
    $restart.Text = Get-LocalizedString -Key 'Restart.Action'
    $restart.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold)
    $restart.ForeColor = [Drawing.Color]::White
    $restart.BackColor = $script:ColorAccent
    $restart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restart.FlatAppearance.BorderColor = $script:ColorAccent
    $restart.FlatAppearance.BorderSize = 1
    $restart.FlatAppearance.MouseOverBackColor = $script:ColorAccent
    $restart.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $restart.Location = New-Object Drawing.Point(312, 180)
    $restart.Size = New-Object Drawing.Size(96, 34)
    $restart.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restart.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($restart)

    $question.Name='DialogHeading'
    $targetCaption.Name='DialogValueCaption'
    $target.Name='DialogValue'
    $target.AccessibleDescription=$TargetName
    $target.AutoEllipsis=$false
    $targetCaption.BackColor=[Drawing.Color]::FromArgb(21,21,21)
    $target.BackColor=$targetCaption.BackColor
    $form.AcceptButton = $restart
    $form.CancelButton = $cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $title -Divider $divider -Glyph $glyph -Content @($question,$targetCaption,$target) -Buttons @($cancel,$restart)
    $form.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = Get-LenovoDialogOwner
        Prepare-LenovoDialogDpiLayout -Form $form -Owner $owner -Role 'restart-confirmation'
        return (Show-LenovoOwnedDialog -Form $form -Owner $owner)
    }
    finally {
        $form.Dispose()
    }
}
