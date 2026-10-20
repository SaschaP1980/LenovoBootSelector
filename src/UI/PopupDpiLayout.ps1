# LBS-144: explicit monitor scale in physical coordinates, with one 96-DPI
# design baseline. The previous AutoScaleMode.Dpi configuration left the
# actual tray form at 390 pixels at 250% on the owner's Windows 11 laptop.
# Native Windows monitor scale is read without changing process DPI awareness
# or modifying any machine settings.
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

function Initialize-PopupDpiLayout {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form)
    $Form.SuspendLayout()
    # Explicit one-time 96-DPI design scaling; do not multiply it by WinForms
    # automatic scaling in a second pass.
    $Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
}

function Set-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid popup monitor scale.' }
    $previous = [double]$Form.Tag
    if ($previous -le 0) { $previous = 1.0; $Form.Tag = [double]$previous }
    if ([Math]::Abs($Scale - $previous) -lt 0.001) { return $false }
    $ratio = [single]($Scale / $previous)
    # WinForms' Form.Scale can round/nonlinearly size the client height even
    # when the width is correct (observed under hosted native 250% test).
    # Preserve the intended exact 96-DPI design client geometry explicitly.
    $oldClient = $Form.ClientSize
    $targetWidth = [int][Math]::Round($oldClient.Width * $ratio)
    $targetHeight = [int][Math]::Round($oldClient.Height * $ratio)
    $Form.SuspendLayout()
    try {
        $Form.Scale([Drawing.SizeF]::new($ratio, $ratio))
        $Form.ClientSize = [Drawing.Size]::new($targetWidth, $targetHeight)
        $root = $Form.Controls['PopupRoot']
        if ($root) { $root.Size = $Form.ClientSize }
        # Store only our own applied scale. No guessed physical pixel ratio.
        $Form.Tag = [double]$Scale
    }
    finally { $Form.ResumeLayout($true) }
    return $true
}

function Complete-PopupDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [double]$Scale = 1.0
    )
    try {
        # Scale the existing complete static form/control tree, not merely
        # mock row widths or the outer window rectangle.
        [void](Set-PopupDpiLayoutScale -Form $Form -Scale $Scale)
    }
    finally { $Form.ResumeLayout($true) }
}

function Get-PopupDpiLayoutScale {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Popup,
        [int]$DesignWidth = 390
    )
    if ($DesignWidth -le 0 -or $Popup.ClientSize.Width -le 0) {
        throw 'Popup layout width is not available.'
    }
    return ([double]$Popup.ClientSize.Width / [double]$DesignWidth)
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
            appliedScalePercent = [int][Math]::Round([double]$Form.Tag * 100)
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
