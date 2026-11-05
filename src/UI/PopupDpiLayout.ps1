# LBS-144: use one WinForms-effective logical coordinate space across
# mixed-DPI monitors. The operating system's reported monitor scale is
# diagnostic metadata, not a second layout multiplier. A previous manual
# 2.5x Form.Scale caused tiny text, an oversized 1680px client and blocked
# access to the tray icon on the owner's 100%/250% dual-display setup.
function Resolve-PopupDpiScale {
    param([Parameter(Mandatory=$true)][int]$Percent)
    if ($Percent -lt 100 -or $Percent -gt 500) {
        throw 'Monitor scale percent outside supported range.'
    }
    return ([double]$Percent / 100.0)
}

function Get-PopupMonitorDpiScale {
    param([System.Windows.Forms.Screen]$Screen)
    if (-not $Screen) { $Screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    try {
        if (-not ('LenovoPopupScaleNative' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LenovoPopupScaleNative {
    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromPoint(NativePoint pt, uint flags);
    [DllImport("shcore.dll")]
    private static extern int GetScaleFactorForMonitor(IntPtr monitor, out int scale);
    public static int ReadScalePercent(int x, int y) {
        NativePoint point = new NativePoint { X = x, Y = y };
        IntPtr monitor = MonitorFromPoint(point, 2);
        if (monitor == IntPtr.Zero) { return 0; }
        int percent;
        if (GetScaleFactorForMonitor(monitor, out percent) != 0) { return 0; }
        return percent;
    }
}
'@ -ErrorAction Stop
        }
        if ($Screen) {
            $bounds = $Screen.Bounds
            $x = [int]($bounds.Left + [Math]::Floor($bounds.Width / 2))
            $y = [int]($bounds.Top + [Math]::Floor($bounds.Height / 2))
            $percent = [LenovoPopupScaleNative]::ReadScalePercent($x, $y)
            if ($percent -ge 100 -and $percent -le 500) {
                return [pscustomobject]@{
                    Factor = (Resolve-PopupDpiScale -Percent $percent)
                    Source = 'GetScaleFactorForMonitor'
                    Percent = $percent
                }
            }
        }
    }
    catch { }
    # Keep an independent read-only fallback for nonstandard native contexts.
    try {
        $graphics = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        try {
            $dpiX = [double]$graphics.DpiX
            if ($dpiX -ge 96 -and $dpiX -le 480) {
                $percent = [int][Math]::Round(100 * $dpiX / 96)
                return [pscustomobject]@{ Factor = (Resolve-PopupDpiScale -Percent $percent); Source = 'graphics-dpi'; Percent = $percent }
            }
        }
        finally { $graphics.Dispose() }
    }
    catch { }
    return [pscustomobject]@{ Factor = 1.0; Source = 'unavailable'; Percent = 100 }
}

# LBS-144 native evidence: 100%-to-250% monitor change kept fonts at
# 19/18/15px, while manually multiplying form and rows by 2.5. Do not scale
# already virtualized WinForms coordinate and font spaces independently.
function Initialize-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.SuspendLayout()
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    # Tag records reported monitor percent only, not a layout multiplier.
    $Form.Tag = [double]1.0
}

function Set-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid popup monitor scale.' }
    $previous = [double]$Form.Tag
    if ($previous -le 0) { $previous = 1.0 }
    $Form.Tag = [double]$Scale
    # A monitor transition triggers placement/diagnostics, never Form.Scale.
    return ([Math]::Abs($Scale - $previous) -ge 0.001)
}

function Complete-PopupDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [double]$Scale = 1.0
    )
    try { [void](Set-PopupDpiLayoutScale -Form $Form -Scale $Scale) }
    finally { $Form.ResumeLayout($true) }
}

# Keep popup and tray reachable. If a work area is shorter than the logical
# 390x672 design, use native panel scrolling rather than clipping its footer.
function Set-PopupViewportForWorkingArea {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea
    )
    $designWidth = 390
    $designHeight = 672
    $availableWidth = [Math]::Max(200, $WorkingArea.Width - 12)
    $availableHeight = [Math]::Max(200, $WorkingArea.Height - 12)
    $wantedWidth = [Math]::Min($designWidth, $availableWidth)
    $wantedHeight = [Math]::Min($designHeight, $availableHeight)
    $changed = ($Form.ClientSize.Width -ne $wantedWidth -or $Form.ClientSize.Height -ne $wantedHeight)
    $root = $Form.Controls['PopupRoot']
    $Form.SuspendLayout()
    try {
        if ($root) {
            $root.SuspendLayout()
            try {
                if ($wantedHeight -lt $designHeight -or $wantedWidth -lt $designWidth) {
                    $root.AutoScroll = $true
                    $root.AutoScrollMinSize = [Drawing.Size]::new($designWidth, $designHeight)
                }
                else {
                    # Clear the logical scroll extent BEFORE turning auto-scroll
                    # off; avoid stale internal scroll state on monitor return.
                    $root.AutoScrollMinSize = [Drawing.Size]::Empty
                    $root.AutoScroll = $false
                }
            }
            finally { $root.ResumeLayout($true) }
        }
        $Form.ClientSize = [Drawing.Size]::new($wantedWidth, $wantedHeight)
        if ($root) { $root.Size = $Form.ClientSize }
    }
    finally { $Form.ResumeLayout($true) }
    return $changed
}

function Get-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Popup,
        [int]$DesignWidth = 390
    )
    if ($DesignWidth -le 0 -or $Popup.ClientSize.Width -le 0) {
        throw 'Popup layout width is not available.'
    }
    # New boot rows share the original 96-DPI form layout coordinate system.
    # Never interpret a virtualized window-width ratio as physical screen DPI.
    return [double]1.0
}

function Set-PopupBootRowDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Row,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][int]$Y
    )
    if ($Scale -le 0 -or $Scale -gt 5) { throw 'Invalid popup DPI scale.' }
    if ([Math]::Abs($Scale - 1.0) -gt 0.0001) {
        $factor = [single]$Scale
        $Row.Scale([Drawing.SizeF]::new($factor, $factor))
    }
    $Row.Location = [Drawing.Point]::new(0, $Y)
    return [int]$Row.Height
}

function Write-PopupDpiLayoutDiagnostic {
    param(
        [System.Windows.Forms.Form]$Form,
        [string]$Phase,
        [string]$MonitorSource = ''
    )
    if (-not $Form -or $Form.IsDisposed) { return }
    try {
        $h = $Form.Controls.Find('HeaderTitleLabel', $true)
        $t = $Form.Controls.Find('BootTitleLabel', $true)
        $s = $Form.Controls.Find('BootSubtitleLabel', $true)
        $header = if ($h.Count -gt 0) { $h[0] } else { $null }
        $title = if ($t.Count -gt 0) { $t[0] } else { $null }
        $subtitle = if ($s.Count -gt 0) { $s[0] } else { $null }
        $data = @{
            phase = $Phase
            appliedScalePercent = 100
            reportedMonitorScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
            layoutCoordinateSpace = 'winforms-effective'
            formClientOuterHeightDelta = [int]($Form.ClientSize.Height - $Form.Height)
            monitorScaleSource = $MonitorSource
            formWidth = [int]$Form.Width
            formHeight = [int]$Form.Height
            clientWidth = [int]$Form.ClientSize.Width
            clientHeight = [int]$Form.ClientSize.Height
            autoscaleMode = [string]$Form.AutoScaleMode
            headerLabelHeight = if ($header) { [int]$header.Height } else { 0 }
            headerFontHeight = if ($header) { [int]$header.Font.Height } else { 0 }
            bootTitleLabelHeight = if ($title) { [int]$title.Height } else { 0 }
            bootTitleFontHeight = if ($title) { [int]$title.Font.Height } else { 0 }
            bootSubtitleLabelHeight = if ($subtitle) { [int]$subtitle.Height } else { 0 }
            bootSubtitleFontHeight = if ($subtitle) { [int]$subtitle.Font.Height } else { 0 }
        }
        Write-RuntimeDiagnosticEvent -Event 'POPUP_DPI_LAYOUT' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData $data)
    }
    catch { }
}
