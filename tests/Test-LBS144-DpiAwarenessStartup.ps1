#requires -version 5.1
# LBS-144: verify first Windows UI HWND begins SystemAware, not Unaware.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
if (-not ('Lbs144TestDpiNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs144TestDpiNative {
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr ctx);
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr ctx);
}
'@ -ErrorAction Stop
}
$script:checks = 0
function Assert-StartupDpi([string]$Name, [bool]$Success) {
    if (-not $Success) { throw "LBS-144 DPI STARTUP RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS144 DPI STARTUP $Name"
}
$previous = [Lbs144TestDpiNative]::SetThreadDpiAwarenessContext([IntPtr]::new(-1))
if ($previous -eq [IntPtr]::Zero) { throw 'Could not establish test DPI-Unaware thread context.' }
try {
    Assert-StartupDpi 'Unaware thread was established for owner regression' ([Lbs144TestDpiNative]::GetAwarenessFromDpiAwarenessContext([Lbs144TestDpiNative]::GetThreadDpiAwarenessContext()) -eq 0)
    $init = Get-Command Initialize-LenovoUiDpiAwareness -ErrorAction SilentlyContinue
    Assert-StartupDpi 'Startup explicitly sets awareness before first UI HWND' ($null -ne $init)
    $result = Initialize-LenovoUiDpiAwareness
    Assert-StartupDpi 'Startup reports successful SystemAware context' ($result.Success -eq $true -and $result.Awareness -eq 'SystemAware')
    Assert-StartupDpi 'Native thread awareness is SystemAware before HWND' ([Lbs144TestDpiNative]::GetAwarenessFromDpiAwarenessContext([Lbs144TestDpiNative]::GetThreadDpiAwarenessContext()) -eq 1)
    $form = New-Object System.Windows.Forms.Form
    try {
        Assert-StartupDpi 'Creating Form alone does not create an HWND' (-not $form.IsHandleCreated)
        [void]$form.Handle
        Assert-StartupDpi 'First Form HWND created under stable awareness' ($form.IsHandleCreated -and [Lbs144TestDpiNative]::GetAwarenessFromDpiAwarenessContext([Lbs144TestDpiNative]::GetThreadDpiAwarenessContext()) -eq 1)
    } finally { $form.Dispose() }
    $cases = @(
        @{ Name='DPI-Unaware applies no manual scaling'; Awareness='Unaware'; Dpi=240; Monitor=2.5; Expected=1.0 },
        @{ Name='SystemAware 250% primary retains system scale'; Awareness='SystemAware'; Dpi=240; Monitor=2.5; Expected=2.5 },
        @{ Name='SystemAware on 100% secondary stays in system coordinates'; Awareness='SystemAware'; Dpi=240; Monitor=1.0; Expected=2.5 },
        @{ Name='PerMonitorAware 100% uses target monitor'; Awareness='PerMonitorAware'; Dpi=240; Monitor=1.0; Expected=1.0 },
        @{ Name='PerMonitorAware 250% uses target monitor'; Awareness='PerMonitorAware'; Dpi=240; Monitor=2.5; Expected=2.5 },
        @{ Name='SystemAware 125% uses system DPI'; Awareness='SystemAware'; Dpi=120; Monitor=2.5; Expected=1.25 },
        @{ Name='SystemAware 150% uses system DPI'; Awareness='SystemAware'; Dpi=144; Monitor=1.0; Expected=1.5 },
        @{ Name='SystemAware 200% uses system DPI'; Awareness='SystemAware'; Dpi=192; Monitor=2.5; Expected=2.0 },
        @{ Name='SystemAware 300% uses system DPI'; Awareness='SystemAware'; Dpi=288; Monitor=1.0; Expected=3.0 }
    )
    Assert-StartupDpi 'Shared coordinate resolver is defined' ($null -ne (Get-Command Resolve-LenovoDpiCoordinateScale -ErrorAction SilentlyContinue))
    foreach ($c in $cases) {
        $scale = Resolve-LenovoDpiCoordinateScale -Awareness $c.Awareness -SystemDpi $c.Dpi -MonitorScale $c.Monitor
        Assert-StartupDpi $c.Name ([Math]::Abs([double]$scale - [double]$c.Expected) -lt 0.000001)
    }
    Assert-StartupDpi 'Runtime coordinate resolver is defined' ($null -ne (Get-Command Get-LenovoUiCoordinateScale -ErrorAction SilentlyContinue))
    $actual = Get-LenovoUiCoordinateScale -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
    Assert-StartupDpi 'Live SystemAware scaling uses a numeric system DPI' ($actual.Factor -ge 1 -and $actual.Factor -le 5 -and $actual.Awareness -eq 'SystemAware')
    $appSource = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
    $start = $appSource.IndexOf('Initialize-LenovoUiDpiAwareness')
    $firstForm = $appSource.LastIndexOf('$script:Popup = New-PopupForm')
    Assert-StartupDpi 'Application sets UI awareness before popup creation' ($start -gt 0 -and $firstForm -gt $start)
    Assert-StartupDpi 'Root menu uses coordinate-aware scaling' ($appSource.Contains('Get-LenovoUiCoordinateScale -Screen $screen'))
    $menuSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\MenuAppearance.ps1'))
    $dialogSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\Dialogs.ps1'))
    $popupSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\Popup.ps1'))
    Assert-StartupDpi 'Submenus use coordinate-aware scaling' ($menuSource.Contains('Get-LenovoUiCoordinateScale -Screen $screen'))
    Assert-StartupDpi 'Dialogs use coordinate-aware scaling' ($dialogSource.Contains('Get-LenovoUiCoordinateScale -Screen $screen'))
    Assert-StartupDpi 'Main popup uses coordinate-aware scaling' ($popupSource.Contains('Get-LenovoUiCoordinateScale -Screen $screen'))
    Write-Host "LBS144 DPI STARTUP TOTAL $script:checks/23"
    if ($script:checks -ne 23) { throw "Expected 23 startup DPI checks, saw $script:checks" }
}
finally {
    $restored = [Lbs144TestDpiNative]::SetThreadDpiAwarenessContext($previous)
    if ($restored -eq [IntPtr]::Zero) { throw 'Failed to restore DPI awareness after native test.' }
}
