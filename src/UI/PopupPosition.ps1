# LBS-132: icon-relative placement is pure geometry; shell discovery is best effort.
function Get-PopupLocationFromAnchor {
    param(
        [Drawing.Rectangle]$WorkingArea,
        [Drawing.Rectangle]$DisplayBounds,
        [Drawing.Rectangle]$AnchorRect,
        [Drawing.Size]$PopupSize,
        [switch]$HasAnchor
    )
    $gap = 8
    $x = $WorkingArea.Right - $PopupSize.Width - $gap
    $y = $WorkingArea.Bottom - $PopupSize.Height - $gap

    if ($HasAnchor) {
        $centerX = $AnchorRect.Left + ($AnchorRect.Width / 2.0)
        $centerY = $AnchorRect.Top + ($AnchorRect.Height / 2.0)
        $x = [int][Math]::Round($centerX - ($PopupSize.Width / 2.0), 0, [MidpointRounding]::AwayFromZero)
        $topInset = $WorkingArea.Top - $DisplayBounds.Top
        $bottomInset = $DisplayBounds.Bottom - $WorkingArea.Bottom
        $leftInset = $WorkingArea.Left - $DisplayBounds.Left
        $rightInset = $DisplayBounds.Right - $WorkingArea.Right

        if ($leftInset -gt 0 -and $leftInset -ge $topInset -and $leftInset -ge $bottomInset -and $leftInset -ge $rightInset) {
            $x = $AnchorRect.Right + $gap
            $y = [int][Math]::Round($centerY - ($PopupSize.Height / 2.0))
        }
        elseif ($rightInset -gt 0 -and $rightInset -ge $topInset -and $rightInset -ge $bottomInset) {
            $x = $AnchorRect.Left - $PopupSize.Width - $gap
            $y = [int][Math]::Round($centerY - ($PopupSize.Height / 2.0))
        }
        elseif ($topInset -gt $bottomInset) {
            $y = $AnchorRect.Bottom + $gap
            if ($y + $PopupSize.Height -gt $WorkingArea.Bottom) {
                $y = $AnchorRect.Top - $PopupSize.Height - $gap
            }
        }
        else {
            # Bottom/auto-hidden taskbar and overflow: prefer directly above the icon.
            $y = $AnchorRect.Top - $PopupSize.Height - $gap
            if ($y -lt $WorkingArea.Top) {
                $y = $AnchorRect.Bottom + $gap
            }
        }
    }

    # The closest feasible centered position wins near display edges.
    $maxX = [Math]::Max($WorkingArea.Left, $WorkingArea.Right - $PopupSize.Width)
    $maxY = [Math]::Max($WorkingArea.Top, $WorkingArea.Bottom - $PopupSize.Height)
    $x = [int][Math]::Min($maxX, [Math]::Max($WorkingArea.Left, $x))
    $y = [int][Math]::Min($maxY, [Math]::Max($WorkingArea.Top, $y))
    return [Drawing.Point]::new($x, $y)
}

function ConvertTo-PopupTrayIconRectangle {
    param($Element, [string]$ExpectedName)
    if ($null -eq $Element) { return $null }
    try {
        $name = [string]$Element.Current.Name
        if (-not ($name.Equals($ExpectedName, [StringComparison]::OrdinalIgnoreCase) -or
                  $name.StartsWith(($ExpectedName + ' '), [StringComparison]::OrdinalIgnoreCase))) {
            return $null
        }
        if ($Element.Current.IsOffscreen) { return $null }
        $bounds = $Element.Current.BoundingRectangle
        if ($bounds.IsEmpty -or $bounds.Width -lt 12 -or $bounds.Height -lt 12 -or
            $bounds.Width -gt 192 -or $bounds.Height -gt 192) { return $null }
        return [Drawing.Rectangle]::new(
            [int][Math]::Round($bounds.Left), [int][Math]::Round($bounds.Top),
            [int][Math]::Round($bounds.Width), [int][Math]::Round($bounds.Height)
        )
    }
    catch { return $null }
}

function Get-VisiblePopupTrayIconRectangle {
    param([Drawing.Point]$ClickPoint, [switch]$HasClickPoint)
    try {
        # Supported Windows UI Automation public surface, never private NotifyIcon fields.
        Add-Type -AssemblyName WindowsBase, UIAutomationTypes, UIAutomationClient -ErrorAction Stop
        $expectedName = 'Lenovo Boot Selector'

        if ($HasClickPoint) {
            $element = [System.Windows.Automation.AutomationElement]::FromPoint([System.Windows.Point]::new($ClickPoint.X, $ClickPoint.Y))
            for ($depth = 0; $null -ne $element -and $depth -lt 6; $depth++) {
                $rect = ConvertTo-PopupTrayIconRectangle -Element $element -ExpectedName $expectedName
                if ($null -ne $rect) { return $rect }
                $element = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($element)
            }
        }

        # Search only bounded shell-owned top-level UIA trees, not the whole desktop.
        $desktopWindows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
        $shellClasses = @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd', 'NotifyIconOverflowWindow', 'TopLevelWindowForOverflowXamlIsland')
        $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::NameProperty, $expectedName)
        foreach ($window in $desktopWindows) {
            if ([string]$window.Current.ClassName -notin $shellClasses) { continue }
            $element = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            $rect = ConvertTo-PopupTrayIconRectangle -Element $element -ExpectedName $expectedName
            if ($null -ne $rect) { return $rect }
        }
    }
    catch {
        # Explorer restart, UIA access failure or missing overflow elements: no UI failure.
        return $null
    }
    return $null
}
