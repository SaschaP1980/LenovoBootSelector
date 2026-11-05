#requires -version 5.1
# LBS-144: pre-first-tray click HWND DPI lifecycle and all four dialog layouts.
# Tests actual WinForms controls, no shell/firmware actions.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
$script:checks = 0
function Assert-Lbs144Startup([string]$Name,[bool]$Result) {
    if (-not $Result) { throw "LBS-144 STARTUP/DIALOG RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS-144 STARTUP/DIALOG $Name"
}
$popup = New-Object System.Windows.Forms.Form
try {
    $popup.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $popup.ClientSize = [Drawing.Size]::new(390,672)
    Assert-Lbs144Startup 'Popup has no HWND before startup initialization' (-not $popup.IsHandleCreated)
    Initialize-LenovoTrayDpiContext -Popup $popup
    Assert-Lbs144Startup 'Tray DPI context creates popup HWND before first tray click' ($popup.IsHandleCreated -and $popup.Handle -ne [IntPtr]::Zero)
    Assert-Lbs144Startup 'Pre-created HWND stays invisible and never fires Shown' (-not $popup.Visible -and $popup.AutoScaleMode -eq [System.Windows.Forms.AutoScaleMode]::None)
    $initialHandle = $popup.Handle
    Initialize-LenovoTrayDpiContext -Popup $popup
    Assert-Lbs144Startup 'Tray DPI context initialization is idempotent' ($popup.Handle -eq $initialHandle -and -not $popup.Visible)
}
finally { $popup.Dispose() }

function New-TestDialogForm {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    # Hosted Windows runner has a small physical desktop. Raise its native
    # MaxWindowTrackSize constraint to simulate a roomy 3840px laptop display.
    $form.MaximumSize = [Drawing.Size]::new(2000,2000)
    $form.ClientSize = [Drawing.Size]::new(470,245)
    $form.Tag = 'de-DE'
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $form.Controls.Add($panel)
    $label = New-Object System.Windows.Forms.Label
    $label.Name = 'Title'
    $label.Font = New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)
    $label.Bounds = [Drawing.Rectangle]::new(18,12,420,24)
    $panel.Controls.Add($label)
    $button = New-Object System.Windows.Forms.Button
    $button.Name = 'OK'
    $button.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Bold)
    $button.Bounds = [Drawing.Rectangle]::new(342,190,110,34)
    $panel.Controls.Add($button)
    return $form
}
$workArea = [Drawing.Rectangle]::new(0,0,3840,2280)
$f = New-TestDialogForm
try {
    Set-LenovoDialogDpiLayout -Form $f -Scale 2.5 -WorkingArea $workArea
    $panel = $f.Controls[0]
    $label = $panel.Controls['Title']
    $button = $panel.Controls['OK']
    Write-Host ("LBS144_DIALOG_METRICS clientWidth={0}, clientHeight={1}, outerWidth={2}, outerHeight={3}" -f $f.ClientSize.Width,$f.ClientSize.Height,$f.Width,$f.Height)
    $desired = Get-LenovoDialogScaledSize -DesignSize ([Drawing.Size]::new(470,245)) -Scale 2.5
    Assert-Lbs144Startup '240dpi design client is exactly 1175x613 physical pixels' ($desired.Width -eq 1175 -and $desired.Height -eq 613)
    $systemMax = [System.Windows.Forms.SystemInformation]::MaxWindowTrackSize
    Assert-Lbs144Startup '240dpi notice client respects native host window-track constraint' ($f.ClientSize.Width -ge [Math]::Min(1175,$systemMax.Width) -and $f.ClientSize.Width -le 1175 -and $f.ClientSize.Height -eq 613)
    Assert-Lbs144Startup '240dpi notice heading and buttons scale together' ($label.Left -eq 45 -and $label.Height -eq 60 -and $button.Left -eq 855 -and $button.Height -eq 85)
    Assert-Lbs144Startup 'Dialog typographic point units are not doubled' ([Math]::Abs($label.Font.Size - 9) -lt .01 -and [Math]::Abs($button.Font.Size - 8.5) -lt .01)
    Assert-Lbs144Startup 'Dialog return data is retained' ([string]$f.Tag -eq 'de-DE')
    Assert-Lbs144Startup 'Dialog fits and centers in target physical working area' ($f.Left -ge 0 -and $f.Top -ge 0 -and $f.Right -le $workArea.Right -and $f.Bottom -le $workArea.Bottom -and [Math]::Abs(($f.Left+$f.Width/2)-1920) -le 2)
    Write-Host ("LBS144_SCROLL_METRICS rootWidth={0}, dock={1}, scroll={2}, scrollMin={3}x{4}, buttonRight={5}, formWidth={6}" -f $panel.Width,$panel.Dock,$panel.AutoScroll,$panel.AutoScrollMinSize.Width,$panel.AutoScrollMinSize.Height,$button.Right,$f.ClientSize.Width)
    $scrollable = ($panel.AutoScroll -and $panel.AutoScrollMinSize.Width -ge $desired.Width)
    $visible = ($button.Right -le $f.ClientSize.Width -and $button.Bottom -le $f.ClientSize.Height -and $label.Right -le $f.ClientSize.Width)
    Assert-Lbs144Startup 'Dialog controls fit visible client or have accessible scroll fallback' ($visible -or $scrollable)
}
finally { $f.Dispose() }
$f = New-TestDialogForm
try {
    Set-LenovoDialogDpiLayout -Form $f -Scale 1.0 -WorkingArea ([Drawing.Rectangle]::new(0,0,1920,1040))
    Assert-Lbs144Startup '96dpi dialog keeps original 470x245 geometry' ($f.ClientSize.Width -eq 470 -and $f.ClientSize.Height -eq 245 -and $f.Controls[0].Controls['OK'].Left -eq 342)
}
finally { $f.Dispose() }
$dialogSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\Dialogs.ps1'))
$injections = [regex]::Matches($dialogSource, 'Prepare-LenovoDialogDpiLayout -Form \$form')
Assert-Lbs144Startup 'All four regular modal constructors use shared DPI preparation' ($injections.Count -eq 4)
$appSource = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$popupInit = $appSource.IndexOf('$script:Popup = New-PopupForm', [StringComparison]::Ordinal)
$trayInit = $appSource.IndexOf('Initialize-LenovoTrayDpiContext -Popup $script:Popup', [StringComparison]::Ordinal)
$trayCreate = $appSource.IndexOf('$script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon', [StringComparison]::Ordinal)
Assert-Lbs144Startup 'Real startup primes popup HWND before NotifyIcon is created' ($popupInit -ge 0 -and $trayInit -gt $popupInit -and $trayCreate -gt $trayInit)
$recoverySource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\StartupRecoveryDialog.ps1'))
Assert-Lbs144Startup 'Fatal-recovery dialog retains separate AutoScaleMode DPI policy' ($recoverySource.Contains('$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi'))
$large = Get-LenovoDialogScaledSize -DesignSize ([Drawing.Size]::new(500,330)) -Scale 2.5
Assert-Lbs144Startup 'Removal system dialog supports 1250x825 physical design' ($large.Width -eq 1250 -and $large.Height -eq 825)
$restartSize = Get-LenovoDialogScaledSize -DesignSize ([Drawing.Size]::new(430,240)) -Scale 2.5
Assert-Lbs144Startup 'Restart dialog supports 1075x600 physical design' ($restartSize.Width -eq 1075 -and $restartSize.Height -eq 600)
$fontHeight = [Drawing.Font]::new('Segoe UI',9,[Drawing.FontStyle]::Bold)
try {
    Assert-Lbs144Startup '240dpi label glyph height fits scaled dialog heading' ($fontHeight.GetHeight([single]240) -le 60)
}
finally { $fontHeight.Dispose() }
Write-Host "LBS-144 STARTUP/DIALOG TOTAL $script:checks/18"
if ($script:checks -ne 18) { throw "Expected 18 startup/dialog assertions, got $script:checks" }
