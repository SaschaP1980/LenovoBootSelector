function Initialize-LenovoMenuAppearance {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [int]$Radius = 0
    )
    if ($Menu.Tag -eq '__LenovoFlatMenu') { return }
    $Menu.Tag = '__LenovoFlatMenu'
    $isSubmenu = ($null -ne $Menu.OwnerItem)
    $Menu.BackColor = if ($isSubmenu) { [Drawing.Color]::FromArgb(32, 32, 32) } else { [Drawing.Color]::FromArgb(22, 22, 22) }
    $Menu.ForeColor = $script:ColorPrimary
    $Menu.Renderer = $script:MenuRenderer
    # v0.2.32: square, borderless root menu with no native check/image gutter.
    # Submenus use a lighter panel plus neutral edge. Selection, separators,
    # checks and arrows are painted centrally in owner coordinates.
    $Menu.DropShadowEnabled = $false
    if ($Menu -is [System.Windows.Forms.ToolStripDropDownMenu]) {
        $Menu.ShowCheckMargin = $false
        $Menu.ShowImageMargin = $false
    }
    $Menu.Padding = if ($isSubmenu) {
        New-Object System.Windows.Forms.Padding(1, 2, 1, 2)
    }
    else {
        New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    }
    $Menu.Add_Opening({
        try {
            $this.Region = $null
            [LenovoMenuLayout]::PrepareItems($this)
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    $Menu.Add_Opened({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
            [LenovoMenuLayout]::PrepareItems($this)
        } catch { }
    })
    $Menu.Add_SizeChanged({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    # v0.3.2: Full-menu hover invalidation is implemented directly by the
    # custom drop-down classes. No delayed BeginInvoke/tail-paint workaround.
}

function Ensure-DarkActionTooltip {
    if (-not $script:DarkActionTooltip) {
        $script:DarkActionTooltipFont = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.OwnerDraw = $true
        $tip.ShowAlways = $true
        $tip.UseAnimation = $false
        $tip.UseFading = $false
        $tip.InitialDelay = 0
        $tip.ReshowDelay = 0
        $tip.AutoPopDelay = 3500
        $tip.BackColor = [Drawing.Color]::FromArgb(28,28,28)
        $tip.ForeColor = [Drawing.Color]::FromArgb(238,238,238)
        $tip.Add_Popup({
            param($sender,$eventArgs)
            $text = [string]$script:DarkActionTooltipText
            if ([string]::IsNullOrWhiteSpace($text)) { return }
            $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
                $text,
                $script:DarkActionTooltipFont,
                (New-Object Drawing.Size(320,0)),
                ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
            )
            $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
            $height = [Math]::Max(30, $measured.Height + 12)
            $eventArgs.ToolTipSize = New-Object Drawing.Size($width,$height)
        })
        $tip.Add_Draw({
            param($sender,$eventArgs)
            $bounds = $eventArgs.Bounds
            $bg = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(28,28,28))
            $border = New-Object Drawing.Pen([Drawing.Color]::FromArgb(76,76,76),1)
            try {
                $eventArgs.Graphics.FillRectangle($bg, $bounds)
                $eventArgs.Graphics.DrawRectangle($border, 0, 0, [Math]::Max(0,$bounds.Width-1), [Math]::Max(0,$bounds.Height-1))
                $textRect = New-Object Drawing.Rectangle(9, 0, [Math]::Max(1,$bounds.Width-18), $bounds.Height)
                [System.Windows.Forms.TextRenderer]::DrawText(
                    $eventArgs.Graphics,
                    [string]$script:DarkActionTooltipText,
                    $script:DarkActionTooltipFont,
                    $textRect,
                    [Drawing.Color]::FromArgb(238,238,238),
                    ([System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
                )
            }
            finally {
                $border.Dispose()
                $bg.Dispose()
            }
        })
        $script:DarkActionTooltip = $tip
    }
    return $script:DarkActionTooltip
}

function Show-DarkActionTooltip {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Owner,
        [Parameter(Mandatory=$true)][string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text) -or -not $Owner -or $Owner.IsDisposed) { return }
    $tip = Ensure-DarkActionTooltip
    $script:DarkActionTooltipText = $Text
    $script:DarkActionTooltipOwner = $Owner

    $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text,
        $script:DarkActionTooltipFont,
        (New-Object Drawing.Size(320,0)),
        ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
    )
    $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
    $height = [Math]::Max(30, $measured.Height + 12)
    $work = [System.Windows.Forms.Screen]::FromControl($Owner).WorkingArea
    $ownerTopLeft = $Owner.PointToScreen([System.Drawing.Point]::Empty)
    $x = $ownerTopLeft.X + $Owner.Width + 8
    if (($x + $width) -gt $work.Right) { $x = $ownerTopLeft.X - $width - 8 }
    if ($x -lt $work.Left) { $x = [Math]::Max($work.Left, [Math]::Min($work.Right - $width, $ownerTopLeft.X)) }
    $y = $ownerTopLeft.Y + [int](($Owner.Height - $height) / 2)
    if ($y -lt $work.Top) { $y = $work.Top }
    if (($y + $height) -gt $work.Bottom) { $y = $work.Bottom - $height }
    $clientPoint = $Owner.PointToClient((New-Object Drawing.Point($x,$y)))

    try { $tip.Hide($Owner) } catch { }
    $tip.Show($Text, $Owner, $clientPoint.X, $clientPoint.Y, 3500)
}

function Hide-DarkActionTooltip {
    if ($script:DarkActionTooltip -and $script:DarkActionTooltipOwner) {
        try { $script:DarkActionTooltip.Hide($script:DarkActionTooltipOwner) } catch { }
    }
    $script:DarkActionTooltipOwner = $null
    $script:DarkActionTooltipText = $null
}
