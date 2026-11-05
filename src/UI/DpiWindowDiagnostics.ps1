# LBS-144: read-only Win32 / DWM window DPI and coordinate-space telemetry.
# Screen/WinForms and GetWindowRect are caller-awareness dependent;
# DWM extended-frame bounds are physical desktop pixels. Never conflate them.
if (-not ('LenovoNativeDpiSnapshot' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class LenovoNativeDpiSnapshot
{
    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    private static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hwnd);
    [DllImport("user32.dll")]
    private static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")]
    private static extern int GetAwarenessFromDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")]
    private static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
    [DllImport("shcore.dll")]
    private static extern int GetProcessDpiAwareness(IntPtr process, out int awareness);
    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out RECT rect, int size);

    private static string Name(int n) {
        if (n == 0) return "Unaware";
        if (n == 1) return "SystemAware";
        if (n == 2) return "PerMonitorAware";
        return "Unknown";
    }
    public static Dictionary<string, object> Capture(IntPtr hwnd) {
        var result = new Dictionary<string, object>();
        result["hwndPresent"] = hwnd != IntPtr.Zero;
        result["windowDpi"] = 0;
        result["windowAwareness"] = "not-created";
        result["threadAwareness"] = "unavailable";
        result["processAwareness"] = "unavailable";
        result["windowRectAvailable"] = false;
        result["windowRectWidth"] = 0;
        result["windowRectHeight"] = 0;
        result["dwmPhysicalAvailable"] = false;
        result["dwmPhysicalWidth"] = 0;
        result["dwmPhysicalHeight"] = 0;
        try {
            int awareness;
            if (GetProcessDpiAwareness(IntPtr.Zero, out awareness) == 0)
                result["processAwareness"] = Name(awareness);
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            IntPtr thread = GetThreadDpiAwarenessContext();
            if (thread != IntPtr.Zero) {
                result["threadAwareness"] = Name(GetAwarenessFromDpiAwarenessContext(thread));
                result["threadPerMonitorV2"] = AreDpiAwarenessContextsEqual(thread, new IntPtr(-4));
            }
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        if (hwnd == IntPtr.Zero) return result;
        try { result["windowDpi"] = (int)GetDpiForWindow(hwnd); }
        catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            IntPtr ctx = GetWindowDpiAwarenessContext(hwnd);
            if (ctx != IntPtr.Zero) {
                result["windowAwareness"] = Name(GetAwarenessFromDpiAwarenessContext(ctx));
                result["windowPerMonitorV2"] = AreDpiAwarenessContextsEqual(ctx, new IntPtr(-4));
            } else result["windowAwareness"] = "unknown";
        } catch (EntryPointNotFoundException) { result["windowAwareness"] = "api-unavailable"; }
          catch (DllNotFoundException) { result["windowAwareness"] = "api-unavailable"; }
        try {
            RECT r;
            if (GetWindowRect(hwnd, out r)) {
                result["windowRectAvailable"] = true;
                result["windowRectLeft"] = r.Left;
                result["windowRectTop"] = r.Top;
                result["windowRectWidth"] = Math.Max(0,r.Right-r.Left);
                result["windowRectHeight"] = Math.Max(0,r.Bottom-r.Top);
            }
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        try {
            RECT r;
            int hr = DwmGetWindowAttribute(hwnd, 9, out r, Marshal.SizeOf(typeof(RECT)));
            if (hr == 0) {
                result["dwmPhysicalAvailable"] = true;
                result["dwmPhysicalLeft"] = r.Left;
                result["dwmPhysicalTop"] = r.Top;
                result["dwmPhysicalWidth"] = Math.Max(0,r.Right-r.Left);
                result["dwmPhysicalHeight"] = Math.Max(0,r.Bottom-r.Top);
            } else result["dwmHResult"] = hr;
        } catch (EntryPointNotFoundException) { } catch (DllNotFoundException) { }
        return result;
    }
}
'@
}

function ConvertTo-LenovoDpiScale {
    param([Parameter(Mandatory=$true)][double]$Dpi)
    if ($Dpi -le 0) { throw 'DPI must be greater than zero.' }
    return [double]($Dpi / 96.0)
}

function Get-LenovoDpiWindowMetrics {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][string]$Role,
        [Parameter(Mandatory=$true)][string]$Phase,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0,
        [double]$PaintDpiX = 0.0,
        [double]$PaintDpiY = 0.0
    )
    # IMPORTANT: reading Control.Handle or Screen.FromControl on a pre-show
    # object may CREATE its HWND and mask the first-show bug under inspection.
    $created = [bool]$Control.IsHandleCreated
    $handle = if ($created) { $Control.Handle } else { [IntPtr]::Zero }
    $data = @{
        schemaVersion = 1
        role = $Role
        phase = $Phase
        controlType = $Control.GetType().Name
        visible = [bool]$Control.Visible
        winFormsLeft = [int]$Control.Left
        winFormsTop = [int]$Control.Top
        winFormsWidth = [int]$Control.Width
        winFormsHeight = [int]$Control.Height
        clientWidth = [int]$Control.ClientSize.Width
        clientHeight = [int]$Control.ClientSize.Height
    }
    $native = [LenovoNativeDpiSnapshot]::Capture($handle)
    foreach ($key in @($native.Keys)) { $data[$key] = $native[$key] }
    if ($data.windowDpi -gt 0) {
        $data.windowDpiScale = ConvertTo-LenovoDpiScale -Dpi ([double]$data.windowDpi)
        $data.windowDpiScalePercent = [Math]::Round(100 * $data.windowDpiScale,3)
    }
    if ($RequestedScale -gt 0) { $data.requestedScale = [double]$RequestedScale }
    if ($PaintDpiX -gt 0) { $data.paintDpiX = [double]$PaintDpiX }
    if ($PaintDpiY -gt 0) { $data.paintDpiY = [double]$PaintDpiY }
    if (-not $Screen) {
        $Screen = if ($created) {
            [System.Windows.Forms.Screen]::FromHandle($handle)
        } else {
            [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
        }
    }
    if ($Screen) {
        $data.screenPrimary = [bool]$Screen.Primary
        $data.screenBoundsLeft = [int]$Screen.Bounds.Left
        $data.screenBoundsTop = [int]$Screen.Bounds.Top
        $data.screenBoundsWidth = [int]$Screen.Bounds.Width
        $data.screenBoundsHeight = [int]$Screen.Bounds.Height
        $data.screenWorkLeft = [int]$Screen.WorkingArea.Left
        $data.screenWorkTop = [int]$Screen.WorkingArea.Top
        $data.screenWorkWidth = [int]$Screen.WorkingArea.Width
        $data.screenWorkHeight = [int]$Screen.WorkingArea.Height
        if (Get-Command Get-PopupMonitorDpiScale -CommandType Function -ErrorAction SilentlyContinue) {
            $reported = Get-PopupMonitorDpiScale -Screen $Screen
            if ($reported -and $reported.Factor -gt 0) {
                $data.monitorReportedScale = [double]$reported.Factor
                $data.monitorReportedScalePercent = [Math]::Round(100*[double]$reported.Factor,3)
            }
        }
    }
    if ($Control -is [System.Windows.Forms.Form]) {
        $data.autoScaleMode = [string]$Control.AutoScaleMode
    }
    # This is a theoretical font metric, NOT actual glyph raster height.
    if ($Control.Font -and $data.windowDpi -gt 0) {
        $data.controlFontPoints = [double]$Control.Font.SizeInPoints
        $data.fontLinePixelsAtWindowDpi = [Math]::Round(
            [double]$Control.Font.GetHeight([single]$data.windowDpi),2)
    }
    return $data
}

function Write-LenovoDpiWindowEvent {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory=$true)][string]$Role,
        [Parameter(Mandatory=$true)][string]$Phase,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0,
        [double]$PaintDpiX = 0.0,
        [double]$PaintDpiY = 0.0
    )
    if (-not $script:RuntimeDiagnosticsAvailable) { return }
    try {
        $metrics = Get-LenovoDpiWindowMetrics -Control $Control -Role $Role -Phase $Phase -Screen $Screen -RequestedScale $RequestedScale -PaintDpiX $PaintDpiX -PaintDpiY $PaintDpiY
        Write-RuntimeDiagnosticEvent -Event 'DPI_WINDOW_SNAPSHOT' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData -Values $metrics)
    }
    catch { } # Read-only diagnostics never affect UI/boot execution.
}

function Register-LenovoDialogDpiWindowDiagnostics {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory=$true)][string]$Role,
        [System.Windows.Forms.Screen]$Screen,
        [double]$RequestedScale = 0.0
    )
    Write-LenovoDpiWindowEvent -Control $Form -Role $Role -Phase 'before-show' -Screen $Screen -RequestedScale $RequestedScale
    $roleCopy = [string]$Role
    $screenCopy = $Screen
    $scaleCopy = [double]$RequestedScale
    $Form.Add_Shown({
        Write-LenovoDpiWindowEvent -Control $this -Role $roleCopy -Phase 'shown' -Screen $screenCopy -RequestedScale $scaleCopy
    }.GetNewClosure())
    $paintRecorded = $false
    $Form.Add_Paint({
        param($sender,$paintArgs)
        if (-not $paintRecorded) {
            $paintRecorded = $true
            Write-LenovoDpiWindowEvent -Control $sender -Role $roleCopy -Phase 'paint' -Screen $screenCopy -RequestedScale $scaleCopy -PaintDpiX $paintArgs.Graphics.DpiX -PaintDpiY $paintArgs.Graphics.DpiY
        }
    }.GetNewClosure())
}
