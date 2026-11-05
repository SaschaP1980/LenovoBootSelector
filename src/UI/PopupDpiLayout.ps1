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

# LBS-144: the 250% laptop reports a virtualized 1536x912 working area
# until the first popup HWND is created; then Screen.WorkingArea reports the
# physical 3840x2280 size. The tray menu must never be the first HWND user.
# Materialize the already-constructed invisible popup's handle during startup
# (no Show/Activate/firmware action). Repeated calls are idempotent.
function Initialize-LenovoTrayDpiContext {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Popup)
    if ($Popup.IsDisposed) { throw 'Cannot initialize DPI context for a disposed popup.' }
    if (-not $Popup.IsHandleCreated) { [void]$Popup.Handle }
}

# LBS-144 physical Windows captures: the WinForms popup remained 390x672
# pixels with window DPI 240 (laptop-primary) and 96 (external-primary).
# PowerShell/WinForms owns a SystemAware HWND, not a PMv2 HWND.
# Keep one 96-DPI design baseline; scale pixel control bounds from immutable
# design metrics, but preserve point-unit Font.Size. Windows/GDI converts
# points to physical pixels using window DPI; multiplying points also would
# double-scale glyphs and clip the text at 240 DPI.
function Initialize-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.SuspendLayout()
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $Form.Tag = [double]1.0
    # A new popup starts a new design snapshot; dynamically rebuilt rows are
    # scaled from their own fresh 96-DPI builder values, not cached here.
    $script:PopupDesignMetrics = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.Control,System.Object]'
}

function Save-PopupControlDesignMetrics {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control)
    if (-not $script:PopupDesignMetrics.ContainsKey($Control)) {
        $font = $Control.Font
        $script:PopupDesignMetrics.Add($Control, [pscustomobject]@{
            Bounds = $Control.Bounds
            ClientSize = $Control.ClientSize
            Padding = $Control.Padding
            Margin = $Control.Margin
            FontFamily = $font.FontFamily
            FontSize = [single]$font.Size
            FontStyle = $font.Style
            FontUnit = $font.Unit
        })
    }
    foreach ($child in $Control.Controls) {
        Save-PopupControlDesignMetrics -Control $child
    }
}

function Set-PopupControlPhysicalScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][bool]$UseStoredBaseline
    )
    if ($UseStoredBaseline) {
        $base = $script:PopupDesignMetrics[$Control]
        if ($null -eq $base) { throw 'Missing popup design baseline.' }
    }
    else {
        # A boot row is created at design size just before this single call.
        $font = $Control.Font
        $base = [pscustomobject]@{
            Bounds = $Control.Bounds
            ClientSize = $Control.ClientSize
            Padding = $Control.Padding
            Margin = $Control.Margin
            FontFamily = $font.FontFamily
            FontSize = [single]$font.Size
            FontStyle = $font.Style
            FontUnit = $font.Unit
        }
    }
    $rect = [Drawing.Rectangle]::new(
        [int][Math]::Round($base.Bounds.X * $Scale),
        [int][Math]::Round($base.Bounds.Y * $Scale),
        [Math]::Max(1,[int][Math]::Round($base.Bounds.Width * $Scale)),
        [Math]::Max(1,[int][Math]::Round($base.Bounds.Height * $Scale)))
    $Control.SuspendLayout()
    try {
        if ($Control -is [System.Windows.Forms.Form]) {
            $Control.ClientSize = [Drawing.Size]::new(
                [Math]::Max(1,[int][Math]::Round($base.ClientSize.Width * $Scale)),
                [Math]::Max(1,[int][Math]::Round($base.ClientSize.Height * $Scale)))
        }
        else {
            $Control.Bounds = $rect
        }
        $Control.Padding = [System.Windows.Forms.Padding]::new(
            [int][Math]::Round($base.Padding.Left * $Scale),
            [int][Math]::Round($base.Padding.Top * $Scale),
            [int][Math]::Round($base.Padding.Right * $Scale),
            [int][Math]::Round($base.Padding.Bottom * $Scale))
        $Control.Margin = [System.Windows.Forms.Padding]::new(
            [int][Math]::Round($base.Margin.Left * $Scale),
            [int][Math]::Round($base.Margin.Top * $Scale),
            [int][Math]::Round($base.Margin.Right * $Scale),
            [int][Math]::Round($base.Margin.Bottom * $Scale))
        # Font.Size is a typographic point unit. Rendering already converts
        # it to DPI-relative pixel height; NEVER multiply by monitor scale.
        $Control.Font = [Drawing.Font]::new(
            $base.FontFamily,[single]$base.FontSize,
            [Drawing.FontStyle]$base.FontStyle,[Drawing.GraphicsUnit]$base.FontUnit)
        foreach ($child in $Control.Controls) {
            Set-PopupControlPhysicalScale -Control $child -Scale $Scale -UseStoredBaseline $UseStoredBaseline
        }
    }
    finally { $Control.ResumeLayout($true) }
}

function Set-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid popup monitor scale.' }
    $previous = [double]$Form.Tag
    if ($previous -le 0) { $previous = 1.0 }
    Save-PopupControlDesignMetrics -Control $Form
    if ([Math]::Abs($Scale - $previous) -lt 0.001) { return $false }
    Set-PopupControlPhysicalScale -Control $Form -Scale $Scale -UseStoredBaseline $true
    $Form.Tag = [double]$Scale
    return $true
}

function Complete-PopupDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [double]$Scale = 1.0
    )
    try { [void](Set-PopupDpiLayoutScale -Form $Form -Scale $Scale) }
    finally { $Form.ResumeLayout($true) }
}

# Work-area coordinates and Form.ClientSize are physical in the observed
# SystemAware LBS process. Clip to the *target* screen and expose scrolling.
function Set-PopupViewportForWorkingArea {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][Drawing.Rectangle]$WorkingArea
    )
    $scale = [double]$Form.Tag
    if ($scale -le 0) { $scale = 1.0 }
    $designWidth = [int][Math]::Round(390 * $scale)
    $designHeight = [int][Math]::Round(672 * $scale)
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
    return [double]$Popup.Tag
}

function Set-PopupBootRowDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Row,
        [Parameter(Mandatory=$true)][double]$Scale,
        [Parameter(Mandatory=$true)][int]$Y
    )
    if ($Scale -le 0 -or $Scale -gt 5) { throw 'Invalid popup DPI scale.' }
    if ([Math]::Abs($Scale - 1.0) -gt 0.0001) {
        Set-PopupControlPhysicalScale -Control $Row -Scale $Scale -UseStoredBaseline $false
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
            appliedScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
            reportedMonitorScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
            layoutCoordinateSpace = 'system-aware-physical-design-scaled'
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
