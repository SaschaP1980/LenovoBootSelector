# LBS-144: independent, physical-pixel DPI layout for ToolStrip menus.
# A SystemAware PowerShell/WinForms host supplies the design 9pt text and
# fixed 260px menu independently of its 96/240 system DPI. Keep immutable
# baselines so tray, language, maintenance and default-target menus can switch
# between 100% and 250% without cumulative scaling or layout drift.
function Get-LenovoScaledMenuPadding {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Padding]$Padding,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    return [System.Windows.Forms.Padding]::new(
        [int][Math]::Round($Padding.Left * $Scale),
        [int][Math]::Round($Padding.Top * $Scale),
        [int][Math]::Round($Padding.Right * $Scale),
        [int][Math]::Round($Padding.Bottom * $Scale))
}

function Set-LenovoMenuDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid menu monitor scale.' }
    if (-not $script:LenovoMenuDesignBaselines) {
        $script:LenovoMenuDesignBaselines = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripDropDown,System.Object]'
    }
    if (-not $script:LenovoMenuDesignBaselines.ContainsKey($Menu)) {
        $widthProperty = $Menu.PSObject.Properties['TargetWidth']
        $width = if ($null -ne $widthProperty) { [int]$widthProperty.Value } else { 0 }
        $state = [pscustomobject]@{
            Width = $width
            Padding = $Menu.Padding
            ItemBases = (New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripItem,System.Object]')
            Scale = [double]1.0
        }
        $script:LenovoMenuDesignBaselines.Add($Menu,$state)
        $Menu.Add_Disposed({
            if ($script:LenovoMenuDesignBaselines) {
                [void]$script:LenovoMenuDesignBaselines.Remove($this)
            }
        })
    }
    $state = $script:LenovoMenuDesignBaselines[$Menu]
    foreach ($item in $Menu.Items) {
        if (-not $state.ItemBases.ContainsKey($item)) {
            $state.ItemBases.Add($item,[pscustomobject]@{
                Height = [Math]::Max(1,[int]$item.Height)
                Padding = $item.Padding
                FontStyle = $item.Font.Style
            })
        }
    }
    if ([Math]::Abs($state.Scale - $Scale) -lt 0.001) { return $false }
    $Menu.SuspendLayout()
    try {
        # All LBS menus use the same 96-DPI Segoe UI 9pt design font.
        # Submenus must not inherit the already-scaled parent item font.
        $Menu.Font = [Drawing.Font]::new('Segoe UI',[single](9.0 * $Scale),[Drawing.FontStyle]::Regular)
        $Menu.Padding = Get-LenovoScaledMenuPadding -Padding $state.Padding -Scale $Scale
        if ($null -ne $Menu.PSObject.Properties['TargetWidth']) {
            $Menu.TargetWidth = [Math]::Max(1,[int][Math]::Round($state.Width * $Scale))
        }
        foreach ($item in $Menu.Items) {
            $base = $state.ItemBases[$item]
            $item.AutoSize = $false
            $item.Padding = Get-LenovoScaledMenuPadding -Padding $base.Padding -Scale $Scale
            $item.Font = [Drawing.Font]::new('Segoe UI',[single](9.0 * $Scale),[Drawing.FontStyle]$base.FontStyle)
            $item.Height = [Math]::Max(1,[int][Math]::Round($base.Height * $Scale))
        }
    }
    finally { $Menu.ResumeLayout($true) }
    $state.Scale = [double]$Scale
    return $true
}

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
            $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
            $factor = (Get-PopupMonitorDpiScale -Screen $screen).Factor
            [void](Set-LenovoMenuDpiLayout -Menu $this -Scale ([double]$factor))
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
