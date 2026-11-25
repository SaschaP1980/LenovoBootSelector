#requires -version 5.1
# LBS-200: isolate actual native tray-menu foreground and external-process dismissal.
# Mock menu items only; no NotifyIcon, firmware, updater or task handler is invoked.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$start = $template.IndexOf($prefix,[StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Canonical menu C# source missing' }
$start += $prefix.Length
$tail = '"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing'
$end = $template.IndexOf($tail,$start,[StringComparison]::Ordinal)
if ($end -le $start) { throw 'Canonical menu C# boundary missing' }
$cs = $template.Substring($start,$end-$start)
$native = @'
public static class Lbs200Win32 {
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern System.IntPtr GetForegroundWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool PostMessage(System.IntPtr h, int msg, System.IntPtr wp, System.IntPtr lp);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool AllowSetForegroundWindow(int pid);
}
'@
Add-Type -TypeDefinition ($cs + [Environment]::NewLine + $native) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility -ErrorAction Stop

$script:checks = 0
$script:failures = New-Object System.Collections.Generic.List[string]
$script:activated = 0
function Assert-Lbs200([string]$Name,[bool]$Result) {
    $script:checks++
    if ($Result) { Write-Host "PASS LBS200 $Name" }
    else { $script:failures.Add($Name); Write-Host "FAIL LBS200 $Name" }
}
function Wait-Lbs200([string]$Path) {
    for ($i=0; $i -lt 100; $i++) {
        if ([IO.File]::Exists($Path)) { return [IO.File]::ReadAllText($Path) }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    throw "External WinForms test process did not acknowledge $Path"
}
function Send-Lbs200Key($Menu,[System.Windows.Forms.Keys]$Key) {
    if (-not $Menu -or -not $Menu.IsHandleCreated) { throw 'Native keyboard HWND missing' }
    $code = [IntPtr]::new([int]$Key)
    if (-not [Lbs200Win32]::PostMessage($Menu.Handle,0x0100,$code,[IntPtr]::Zero)) {
        throw 'Native WM_KEYDOWN post failed'
    }
    if (-not [Lbs200Win32]::PostMessage($Menu.Handle,0x0101,$code,[IntPtr]::Zero)) {
        throw 'Native WM_KEYUP post failed'
    }
    [System.Windows.Forms.Application]::DoEvents()
}
function New-Lbs200Menu([int]$Width) {
    $menu = New-Object LenovoContextMenuStrip
    $menu.TargetWidth = $Width
    $menu.AutoClose = $true
    $first = New-Object System.Windows.Forms.ToolStripMenuItem('Open')
    $disabled = New-Object System.Windows.Forms.ToolStripMenuItem('Disabled')
    $disabled.Enabled = $false
    $branch = New-Object System.Windows.Forms.ToolStripMenuItem('Language')
    $branch.DropDown = New-Object LenovoDropDownMenu
    [void]$branch.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripMenuItem('English')))
    [void]$branch.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripMenuItem('German')))
    [void]$menu.Items.Add($first)
    [void]$menu.Items.Add($disabled)
    [void]$menu.Items.Add($branch)
    $first.Add_Click({ $script:activated++ })
    return $menu
}

# An independent WinForms process simulates Explorer (initial foreground)
# and another application (outside activation). It grants foreground rights
# just as a user-initiated tray click does; no global mouse injection.
$dir = Join-Path ([IO.Path]::GetTempPath()) ('lbs200-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($dir) | Out-Null
$childFile = Join-Path $dir 'external.ps1'
$childSource = @'
param([string]$Dir,[int]$CallerPid)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Lbs200External {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int pid);
}
"@
$a = New-Object System.Windows.Forms.Form
$b = New-Object System.Windows.Forms.Form
try {
    $a.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $b.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $a.Location = [Drawing.Point]::new(350,50)
    $b.Location = [Drawing.Point]::new(580,60)
    $a.ClientSize = [Drawing.Size]::new(170,110)
    $b.ClientSize = [Drawing.Size]::new(170,110)
    $a.Show()
    $b.Show()
    [System.Windows.Forms.Application]::DoEvents()
    [IO.File]::WriteAllText((Join-Path $Dir 'ready'),("$($a.Handle.ToInt64()),$($b.Handle.ToInt64())"))
    $deadline = [datetime]::UtcNow.AddSeconds(28)
    while ([datetime]::UtcNow -lt $deadline) {
        if ([IO.File]::Exists((Join-Path $Dir 'stop'))) { break }
        if ([IO.File]::Exists((Join-Path $Dir 'grant'))) {
            [IO.File]::Delete((Join-Path $Dir 'grant'))
            [void][Lbs200External]::SetForegroundWindow($a.Handle)
            $allowed = [Lbs200External]::AllowSetForegroundWindow($CallerPid)
            [IO.File]::WriteAllText((Join-Path $Dir 'granted'),([string]$allowed))
        }
        if ([IO.File]::Exists((Join-Path $Dir 'switch'))) {
            [IO.File]::Delete((Join-Path $Dir 'switch'))
            [void][Lbs200External]::SetForegroundWindow($b.Handle)
            [IO.File]::WriteAllText((Join-Path $Dir 'switched'),'True')
        }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
    }
}
finally { $b.Dispose(); $a.Dispose() }
'@
[IO.File]::WriteAllText($childFile,$childSource,(New-Object System.Text.UTF8Encoding($false)))
$argsText = ('-NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "{0}" "{1}" {2}' -f $childFile,$dir,$PID)
$child = $null
$hostForm = New-Object System.Windows.Forms.Form
try {
    $hostForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $hostForm.Location = [Drawing.Point]::new(20,35)
    $hostForm.ClientSize = [Drawing.Size]::new(220,130)
    $hostForm.Show()
    $child = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argsText -PassThru
    $parts = (Wait-Lbs200 (Join-Path $dir 'ready')).Split(',')
    $handleA = [IntPtr]::new([long]$parts[0])
    $handleB = [IntPtr]::new([long]$parts[1])
    $screen = [System.Windows.Forms.Screen]::FromControl($hostForm)
    $point = [Drawing.Point]::new($screen.WorkingArea.Left+20,$screen.WorkingArea.Top+20)
    foreach ($scale in @(1.0,2.5)) {
        $script:activated = 0
        $width = [int](260*$scale)
        $menu = New-Lbs200Menu -Width $width
        try {
            Assert-Lbs200 "$scale native root and child menus preserve AutoClose" (
                $menu.AutoClose -and ($menu.Items[2]).HasDropDownItems)
            # Request foreground ownership to be transferable to the test
            # process, modelling a genuine right-click activation grant.
            $grantedFile = Join-Path $dir 'granted'
            if ([IO.File]::Exists($grantedFile)) { [IO.File]::Delete($grantedFile) }
            [IO.File]::WriteAllText((Join-Path $dir 'grant'),'1')
            $grant = Wait-Lbs200 $grantedFile
            if ($grant -ne 'True') { throw "Test harness foreground grant refused: $grant" }
            if ([Lbs200Win32]::GetForegroundWindow() -ne $handleA) {
                throw 'Test harness did not establish external initial foreground.'
            }
            $menu.Show($point)
            [System.Windows.Forms.Application]::DoEvents()
            $owned = ($menu.Visible -and $menu.IsHandleCreated -and
                [Lbs200Win32]::GetForegroundWindow() -eq $menu.Handle)
            Assert-Lbs200 "$scale V9 root menu acquires native keyboard foreground" $owned
            Assert-Lbs200 "$scale opening menu never invokes an action" ($script:activated -eq 0)
            if ($owned) {
                Send-Lbs200Key $menu ([System.Windows.Forms.Keys]::Down)
                $nativeSelected = @($menu.Items | Where-Object { $_.Selected -and $_.Enabled })
                Assert-Lbs200 "$scale V9 Down reaches an enabled menu item" ($nativeSelected.Count -eq 1)
                Send-Lbs200Key $menu ([System.Windows.Forms.Keys]::Down)
                Assert-Lbs200 "$scale V9 arrows skip a disabled item" (-not ($menu.Items[1]).Selected)
                $branch = [System.Windows.Forms.ToolStripMenuItem]$menu.Items[2]
                $branch.Select()
                Assert-Lbs200 "$scale V9 focused submenu row has visual hot state" (
                    [object]::ReferenceEquals([LenovoMenuLayout]::GetVisualHotItem($menu),$branch))
                Send-Lbs200Key $menu ([System.Windows.Forms.Keys]::Right)
                Assert-Lbs200 "$scale V9 Right opens Language submenu" ($branch.DropDown.Visible -and $menu.Visible)
                if ($branch.DropDown.Visible) {
                    Send-Lbs200Key $branch.DropDown ([System.Windows.Forms.Keys]::Left)
                }
                Assert-Lbs200 "$scale V9 Left closes submenu but keeps root" (
                    -not $branch.DropDown.Visible -and $menu.Visible)
            }
            else {
                foreach ($label in @('Down reaches an enabled menu item','arrows skip a disabled item',
                    'focused submenu row has visual hot state','Right opens Language submenu','Left closes submenu but keeps root')) {
                    Assert-Lbs200 "$scale V9 $label" $false
                }
            }
            Assert-Lbs200 "$scale V9 focus navigation never invokes an action" ($script:activated -eq 0)
            # A foreground switch to a different process's other form is an
            # isolated native analogue of a click in another application.
            $switchedFile = Join-Path $dir 'switched'
            if ([IO.File]::Exists($switchedFile)) { [IO.File]::Delete($switchedFile) }
            # The menu process currently owns foreground; allow the independent
            # helper process to take focus, as an actual outside user click does.
            if (-not [Lbs200Win32]::AllowSetForegroundWindow([int]$child.Id)) {
                throw 'Test harness could not grant external application foreground.'
            }
            [IO.File]::WriteAllText((Join-Path $dir 'switch'),'1')
            $null = Wait-Lbs200 $switchedFile
            [System.Windows.Forms.Application]::DoEvents()
            if ([Lbs200Win32]::GetForegroundWindow() -ne $handleB) {
                throw 'Test harness did not establish outside-process foreground.'
            }
            Assert-Lbs200 "$scale V10 external application activation closes root" (-not $menu.Visible)
            Assert-Lbs200 "$scale V10 dismissal never invokes an action" ($script:activated -eq 0)
            # Deliberate Enter is a separate, explicitly selected menu action.
            if ([IO.File]::Exists($grantedFile)) { [IO.File]::Delete($grantedFile) }
            [IO.File]::WriteAllText((Join-Path $dir 'grant'),'1')
            if ((Wait-Lbs200 $grantedFile) -ne 'True') { throw 'Second foreground grant failed' }
            $menu.Show($point)
            [System.Windows.Forms.Application]::DoEvents()
            $menu.Items[0].Select()
            Send-Lbs200Key $menu ([System.Windows.Forms.Keys]::Return)
            Assert-Lbs200 "$scale V9 Enter runs explicit selected item exactly once" ($script:activated -eq 1)
            # Escape must dismiss without invoking the item a second time.
            if ([IO.File]::Exists($grantedFile)) { [IO.File]::Delete($grantedFile) }
            [IO.File]::WriteAllText((Join-Path $dir 'grant'),'1')
            if ((Wait-Lbs200 $grantedFile) -ne 'True') { throw 'Third foreground grant failed' }
            $menu.Show($point)
            [System.Windows.Forms.Application]::DoEvents()
            Send-Lbs200Key $menu ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs200 "$scale V9 Escape dismisses without action" (
                -not $menu.Visible -and $script:activated -eq 1)
        }
        finally { $menu.Close(); $menu.Dispose() }
    }
}
finally {
    [IO.File]::WriteAllText((Join-Path $dir 'stop'),'1')
    if ($child) {
        try { if (-not $child.WaitForExit(3000)) { $child.Kill() } } catch { }
        $child.Dispose()
    }
    $hostForm.Dispose()
    try { [IO.Directory]::Delete($dir,$true) } catch { }
}
Write-Host "LBS200 TRAY MENU TOTAL $($script:checks)/26"
Write-Host "LBS200 TRAY MENU RESULT=$($(if ($script:failures.Count -eq 0) { 'PASS' } else { 'RED' }))"
if ($script:checks -ne 26 -or $script:failures.Count -gt 0) {
    throw ('LBS200 TRAY MENU RED: ' + ($script:failures -join '; '))
}
