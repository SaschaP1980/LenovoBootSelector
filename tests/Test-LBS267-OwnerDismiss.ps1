#requires -version 5.1
# LBS-229: actual native owned forms, no live firmware or privileged actions.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs267Native {
    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint command);
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr GetFocus();
    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(System.Drawing.Point point);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
}
'@ -ReferencedAssemblies System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$begin = $template.IndexOf($prefix,[StringComparison]::Ordinal)+$prefix.Length
$end = $template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($begin -lt $prefix.Length -or $end -le $begin) { throw 'Canonical C# controls missing' }
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\PopupPosition.ps1')
. (Join-Path $root 'src\UI\Popup.ps1')
. (Join-Path $root 'src\UI\DefaultTargetMenu.ps1')
. (Join-Path $root 'src\UI\DefaultTargetPresentation.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
. (Join-Path $root 'src\Core\SystemStatus.ps1')
. (Join-Path $root 'src\UI\SystemStatusPresentation.ps1')
. (Join-Path $root 'src\Application\RefreshRuntime.ps1')
. (Join-Path $root 'src\UI\RefreshPresentation.ps1')
$script:ColorBackground=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorHeader=[Drawing.Color]::Black
$script:ColorRow=$script:ColorBackground
$script:ColorHover=[Drawing.Color]::FromArgb(41,41,41)
$script:ColorSurface=[Drawing.Color]::FromArgb(25,25,25)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(44,25,24)
$script:ColorPrimary=[Drawing.Color]::FromArgb(252,252,252)
$script:ColorSecondary=[Drawing.Color]::FromArgb(184,184,184)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:DefaultGuid='a'
$script:SelectedGuid='b'
$script:CurrentEntries=@(
    [pscustomobject]@{Guid='a';Title='Corporate';Subtitle='Internal SSD';Symbol='●';Accent=[Drawing.Color]::DeepSkyBlue},
    [pscustomobject]@{Guid='b';Title='Gaming';Subtitle='USB';Symbol='●';Accent=[Drawing.Color]::Orange}
)
$script:CurrentEntries += @(1..12 | ForEach-Object { [pscustomobject]@{Guid="extra-$_";Title="Extra target $_";Subtitle='UEFI';Symbol='●';Accent=[Drawing.Color]::Gray} })
$script:DefaultTargetReadUncertain=$false
$script:Busy=$false
$script:Drift=$false
$script:Ready=$true
$script:BackgroundRefreshState=New-BackgroundRefreshRuntimeState
$script:ActiveAuxiliaryPopup=$null
$script:Checks=0
$script:Lbs247Checks=0
$script:Actions=@()
$script:DefaultCalls=@()
$script:BootCalls=0
$script:Locale='en-US'
$script:Scale=1.0
function Assert-Lbs267([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS267 FAIL: $Name" }
    $script:Checks++
    Write-Host "PASS LBS267 $Name"
}
function Assert-Lbs247([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS247 FAIL: $Name" }
    $script:Lbs247Checks++
    Write-Host "PASS LBS247 $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-OrderedEntriesForUi { return @($script:CurrentEntries) }
function Get-EntryByGuid($Guid) { return ($script:CurrentEntries | Where-Object Guid -eq $Guid | Select-Object -First 1) }
function Get-EntryDisplayTitle($Entry) { return [string]$Entry.Title }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ State=$(if ($script:Busy) {'Busy'} elseif ($script:Ready) {'Ready'} else {'Checking'});CanSetDefaultTarget=$script:Ready;CanRefresh=$script:Ready;IsChecking=(-not $script:Ready) } }
function Test-MaintenanceBusy { return $script:Busy }
function Test-PortablePreferencesAvailable { return (-not $script:Busy -and $script:Ready) }
function Test-BootTargetDriftDetected { return $script:Drift }
function Test-TaskBrokerReady { return $script:Ready }
function Refresh-SystemDefaultState { return $script:DefaultGuid }
function Start-DefaultTargetChange { param([AllowNull()][string]$Guid) $script:DefaultCalls+=@([string]$Guid) }
function Start-BootNextSelection { $script:BootCalls++ }
function Update-TaskBrokerUiState { param([switch]$Fast) return $true }
function Update-AutostartUi { return $true }
function Update-UpdateMenuState {}
function Update-LanguageMenuState {}
function Get-LenovoUiCoordinateScale { param($Screen) return [pscustomobject]@{Factor=$script:Scale} }
function Show-LenovoNoticeDialog { throw 'Unexpected error dialog' }
$tray = New-Object Windows.Forms.ContextMenuStrip
$map=[ordered]@{
    AutostartMenuItem='autostart'; LanguageGermanMenuItem='language-de'; LanguageEnglishMenuItem='language-en'
    TaskBrokerSetupMenuItem='system-setup'; TaskBrokerRemoveMenuItem='system-remove'
    UpdateCheckMenuItem='update-check'; UpdateInstallMenuItem='update-install'
    PreferencesExportMenuItem='preferences-export'; PreferencesImportMenuItem='preferences-import'
    RuntimeDiagnosticMenuItem='diagnostics-save'; DiagnosticsUploadMenuItem='diagnostics-upload'
}
foreach ($var in $map.Keys) {
    $item=New-Object Windows.Forms.ToolStripMenuItem
    $item.Text=$map[$var]
    $item.Tag=$map[$var]
    $item.Add_Click({
        param($sender,$eventArgs)
        $script:Actions+=@([string]$sender.Tag)
        if ($sender.Tag -eq 'autostart') { $sender.Checked=-not $sender.Checked }
    })
    [void]$tray.Items.Add($item)
    Set-Variable -Scope Script -Name $var -Value $item
}
$script:LanguageEnglishMenuItem.Checked=$true
$script:UpdateInstallMenuItem.Enabled=$false

function Click-Lbs267([Drawing.Point]$Point,[switch]$Down,[switch]$Up) {
    [Windows.Forms.Cursor]::Position=$Point
    [Windows.Forms.Application]::DoEvents()
    if ($Down) { [Lbs267Native]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [Windows.Forms.Application]::DoEvents() }
    if ($Up) { [Lbs267Native]::mouse_event(4,0,0,0,[UIntPtr]::Zero); [Windows.Forms.Application]::DoEvents() }
}
function Center-Lbs267($Control) {
    return $Control.PointToScreen([Drawing.Point]::new([int]($Control.Width/2),[int]($Control.Height/2)))
}
# Actual pixels, not merely ForeColor. Reacquire only invalid background/state evidence.
function Test-Lbs182ActiveInfoRaster($Button,$Child,[Drawing.Rectangle]$ExpectedBounds) {
    if ([Windows.Forms.SystemInformation]::HighContrast) { throw 'LBS182 normal-theme raster fixture requires normal theme' }
    for ($attempt=1;$attempt -le 5;$attempt++) {
        if (-not $Child.ContainsFocus -or [Lbs267Native]::GetForegroundWindow() -ne $Child.Handle -or $Button.RectangleToScreen($Button.ClientRectangle) -ne $ExpectedBounds) { throw 'LBS182 active icon native state changed' }
        $bitmap=[Drawing.Bitmap]::new($Button.ClientSize.Width,$Button.ClientSize.Height)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($ExpectedBounds.Location,[Drawing.Point]::Empty,$Button.ClientSize)
            $corners=@($bitmap.GetPixel(1,1).ToArgb(),$bitmap.GetPixel($bitmap.Width-2,1).ToArgb(),$bitmap.GetPixel(1,$bitmap.Height-2).ToArgb(),$bitmap.GetPixel($bitmap.Width-2,$bitmap.Height-2).ToArgb())
            $valid=@($corners | Where-Object {$_ -ne $Button.BackColor.ToArgb()}).Count -eq 0
            $accent=0
            $maxRed=[Drawing.Color]::Black
            for ($y=4;$y -lt $bitmap.Height-4;$y++) {
                for ($x=4;$x -lt $bitmap.Width-4;$x++) {
                    $pixel=$bitmap.GetPixel($x,$y)
                    if ($pixel.R -gt $maxRed.R) { $maxRed=$pixel }
                    # The hit shield is black with alpha 1/255. Its composition
                    # can reduce a channel by one code value; compare against
                    # that exact compositing envelope, not an arbitrary red.
                    if ([Math]::Abs([int]$pixel.R-$script:ColorAccent.R) -le 1 -and
                        [Math]::Abs([int]$pixel.G-$script:ColorAccent.G) -le 1 -and
                        [Math]::Abs([int]$pixel.B-$script:ColorAccent.B) -le 1) { $accent++ }
                }
            }
            Write-Host "LBS182 INFO SCREEN attempt=$attempt valid=$valid corners=$($corners -join ',') accentPixels=$accent maxRed=$($maxRed.R),$($maxRed.G),$($maxRed.B) active=$($Button.ModalActive)"
            if ($valid) { return ($accent -ge 8) }
        } finally { $graphics.Dispose();$bitmap.Dispose() }
        if ($attempt -lt 5) { Start-Sleep -Milliseconds 25; [Windows.Forms.Application]::DoEvents() }
    }
    throw 'LBS182 invalid active Info screen; no visual conclusion'
}
$script:DefaultInteractionEnabled=$true
$script:DefaultTargetChangePending=$false
$script:BootNextPendingGuid=$null
$script:ActiveOwnedDialog=$null
$script:IsManageEntriesMode=$false
$cursor=[Windows.Forms.Cursor]::Position
$owner=New-Object Windows.Forms.Form
$owner.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
$owner.ClientSize=[Drawing.Size]::new(390,672)
$owner.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$owner.ShowInTaskbar=$false
$owner.TopMost=$true
$area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$owner.Location=[Drawing.Point]::new(($area.Right-$owner.Width),$area.Top)
$rootPanel=New-Object Windows.Forms.Panel
$rootPanel.Dock=[Windows.Forms.DockStyle]::Fill
$rootPanel.BackColor=$script:ColorBackground
$owner.Controls.Add($rootPanel)
$boot=New-Object Windows.Forms.Button
$boot.Name='TestBootAction'
$boot.Bounds=[Drawing.Rectangle]::new(16,100,250,40)
$boot.Text='Mock BootNext action'
$boot.Add_Click({ Start-BootNextSelection })
$rootPanel.Controls.Add($boot)
$script:OwnerProbe=$owner
$script:BootProbe=$boot
try {
    $owner.Show();$owner.Activate();[Windows.Forms.Application]::DoEvents()
    foreach ($locale in @('de-DE','en-US')) {
        $script:Locale=$locale
        Add-PopupSettingsSection -Root $rootPanel
        Add-PopupHeaderSection -Root $rootPanel
        foreach ($kind in @('SettingsPanel','DefaultPanel','HeaderSystemStatusButton')) {
            $trigger=$rootPanel.Controls.Find($kind,$true) | Select-Object -First 1
            foreach ($case in @('content','trigger','overlap','nested','escape','x','normal-child')) {
                $script:Case=$case
                $script:Kind=$kind
                $script:TriggerProbe=$trigger
                $script:ProbeError=$null
                $script:Observed=$false
                $script:ShieldProbe=$null
                $script:BeforeBoot=$script:BootCalls
                $script:BeforeDefault=$script:DefaultCalls.Count
                $script:BeforeActions=$script:Actions.Count
                $script:OpeningWatch=[Diagnostics.Stopwatch]::StartNew()
                $timer=New-Object Windows.Forms.Timer
                $timer.Interval=100
                $timer.Add_Tick({
                    param($sender,$eventArgs)
                    $child=$script:ActiveAuxiliaryPopup
                    if (-not $child -or -not $child.Visible -or -not $child.Tag.InitialModalActivationComplete) {
                        if ($child -and $child.Visible) {
                            Write-Host "LBS267 INITIAL LIFECYCLE pending kind=$script:Kind case=$script:Case shieldCount=$(@($script:OwnerProbe.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerClickShield').Count) elapsed=$($script:OpeningWatch.ElapsedMilliseconds)"
                        }
                        if ($script:OpeningWatch.ElapsedMilliseconds -lt 5000) { return }
                        $sender.Stop()
                        $script:ProbeError='LBS267 initial native modal lifecycle did not complete within 5 seconds'
                        if ($child -and $child.Visible) { $child.Tag.Close.PerformClick() }
                        return
                    }
                    $sender.Stop()
                    try {
                        $main=$script:OwnerProbe
                        $trigger=$script:TriggerProbe
                        $shield=@($main.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerClickShield')
                        Write-Host "LBS267 MODAL kind=$script:Kind case=$script:Case owned=$($main.OwnedForms | ForEach-Object {$_.Name}) count=$($shield.Count) shieldVisible=$($shield[0].Visible) shieldEnabled=$(if($shield.Count){[Lbs267Native]::IsWindowEnabled($shield[0].Handle)}) ownerEnabled=$([Lbs267Native]::IsWindowEnabled($main.Handle)) childEnabled=$([Lbs267Native]::IsWindowEnabled($child.Handle)) childFocus=$($child.ContainsFocus) foreground=$([Lbs267Native]::GetForegroundWindow()) childHandle=$($child.Handle) shieldHandle=$($shield[0].Handle)"
                        Assert-Lbs267 "$script:Kind/$script:Case one native hit shield and disabled owner" ($shield.Count -eq 1 -and $shield[0].Visible -and [Lbs267Native]::IsWindowEnabled($shield[0].Handle) -and -not [Lbs267Native]::IsWindowEnabled($main.Handle) -and [Lbs267Native]::IsWindowEnabled($child.Handle) -and $child.ContainsFocus -and [Lbs267Native]::GetForegroundWindow() -eq $child.Handle)
                        if ($script:Kind -eq 'HeaderSystemStatusButton' -and $script:Case -eq 'content') {
                            $bridge=@($child.OwnedForms | Where-Object Name -eq 'AuxiliaryConnector')
                            $dimmer=@($main.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer')
                            $iconBounds=$trigger.RectangleToScreen($trigger.ClientRectangle)
                            Write-Host "LBS182 POLISH ownerTop=$($main.Top) childTop=$($child.Top) bridgeCount=$($bridge.Count) hole=$($dimmer[0].HighlightedRowBounds) icon=$iconBounds"
                            Assert-Lbs267 'LBS182 header aligned native connector and isolated icon cutout' ($child.Top -eq $main.Top -and $bridge.Count -eq 1 -and $bridge[0].Visible -and $bridge[0].VisualBounds.Right -eq $main.Left -and $dimmer.Count -eq 1 -and $dimmer[0].HighlightedRowBounds -eq $iconBounds -and $trigger.ModalActive)
                            # Read the actual native connector paint state; its shared OnPaint uses this fill.
                            # The existing geometry/raster/focus assertions remain independent and unchanged.
                            $fillField=$bridge[0].GetType().GetField('fill',[Reflection.BindingFlags]'Instance,NonPublic')
                            if (-not $fillField) { throw 'LBS182 connector paint state unavailable' }
                            $expectedFill=if ([Windows.Forms.SystemInformation]::HighContrast) { $child.Tag.Header.BackColor } else { $script:ColorAccent }
                            $actualFill=[Drawing.Color]$fillField.GetValue($bridge[0])
                            Write-Host "LBS182 CONNECTOR FILL expected=$($expectedFill.ToArgb()) actual=$($actualFill.ToArgb())"
                            $bitmap=[Drawing.Bitmap]::new($bridge[0].Width,$bridge[0].Height)
                            try {
                                $bridge[0].DrawToBitmap($bitmap,$bridge[0].ClientRectangle)
                                $paintedFill=$bitmap.GetPixel(1,[int][Math]::Floor($bridge[0].VisualBounds.Height/2)).ToArgb()
                                Assert-Lbs267 'LBS182 status connector uses active accent fill (High Contrast retains surface)' ($actualFill.ToArgb() -eq $expectedFill.ToArgb() -and $paintedFill -eq $expectedFill.ToArgb())
                            } finally { $bitmap.Dispose() }
                            [Windows.Forms.Cursor]::Position=Center-Lbs267 $child.Tag.Header
                            [Windows.Forms.Application]::DoEvents()
                            Assert-Lbs267 'LBS182 active Info actual screen accent while pointer outside' (Test-Lbs182ActiveInfoRaster $trigger $child $iconBounds)
                        }
                        $script:ShieldProbe=$shield[0]
                        $s=$shield[0]
                        if ($script:Case -eq 'escape') {
                            [Windows.Forms.SendKeys]::SendWait('{ESC}')
                            [Windows.Forms.Application]::DoEvents()
                        } elseif ($script:Case -eq 'x') {
                            $child.Tag.Close.PerformClick()
                        } elseif ($script:Case -eq 'normal-child') {
                            if ($script:Kind -eq 'DefaultPanel') {
                                $row=$child.Tag.Body.Controls | Where-Object { $_.Name -eq 'DefaultPickerRow' -and $_.Tag.Guid -eq 'a' } | Select-Object -First 1
                                $p=Center-Lbs267 $row
                                Click-Lbs267 $p -Down -Up
                            } elseif ($script:Kind -eq 'HeaderSystemStatusButton') {
                                $value=$child.Tag.Body.Controls['SystemStatusValue-Summary']
                                Click-Lbs267 (Center-Lbs267 $value) -Down -Up
                                Assert-Lbs267 'LBS182 read-only child remains open without dispatch' ($child.Visible -and $script:Actions.Count -eq $script:BeforeActions -and $script:BootCalls -eq $script:BeforeBoot -and $script:DefaultCalls.Count -eq $script:BeforeDefault)
                                $child.Tag.Close.PerformClick()
                            } else {
                                $toggle=$child.Tag.Body.Controls['ConfigurationAutostart']
                                if (-not $toggle) { throw 'Native toggle missing' }
                                Click-Lbs267 (Center-Lbs267 $toggle) -Down -Up
                                Assert-Lbs267 'configuration child action remains interactive' ($child.Visible -and $script:Actions.Count -eq $script:BeforeActions+1)
                                $child.Tag.Close.PerformClick()
                            }
                        } else {
                            $point=if ($script:Case -eq 'trigger') { Center-Lbs267 $trigger } else { Center-Lbs267 $script:BootProbe }
                            if ($script:Case -eq 'overlap') {
                                # Real child overlaps the left part of the main
                                # client. The right edge still exposes the owner.
                                $child.Left=$main.Left-$child.Width+80
                                [Windows.Forms.Application]::DoEvents()
                                $inside=[Drawing.Point]::new(($main.Left+20),($child.Top+20))
                                $point=[Drawing.Point]::new(($main.Right-20),($main.Top+100))
                                Assert-Lbs267 'overlapping child is excluded from hit region' (-not $s.Region.IsVisible($s.PointToClient($inside)) -and $s.Region.IsVisible($s.PointToClient($point)) -and [Lbs267Native]::WindowFromPoint($inside) -ne $s.Handle)
                                Click-Lbs267 $inside -Down -Up
                                Assert-Lbs267 'child header click does not dismiss' ($child.Visible -and $child.DialogResult -eq [Windows.Forms.DialogResult]::None)
                            }
                            if ($script:Case -eq 'nested') {
                                $nested=New-Object Windows.Forms.Form
                                $nested.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
                                $nested.StartPosition=[Windows.Forms.FormStartPosition]::Manual
                                $nested.Bounds=[Drawing.Rectangle]::new($child.Left+15,$child.Top+15,120,80)
                                $nested.TopMost=$true;$nested.ShowInTaskbar=$false
                                $script:NestedPoint=$point
                                $script:NestedError=$null
                                $nested.Add_Shown({
                                    param($form,$eventArgs)
                                    try {
                                        Click-Lbs267 $script:NestedPoint -Down -Up
                                        Assert-Lbs267 'nested modal blocks owner dismissal' ($form.Visible -and $script:ActiveAuxiliaryPopup.Visible -and $script:ActiveAuxiliaryPopup.DialogResult -eq [Windows.Forms.DialogResult]::None -and -not [Lbs267Native]::IsWindowEnabled($script:ActiveAuxiliaryPopup.Handle) -and $script:BootCalls -eq $script:BeforeBoot)
                                    } catch { $script:NestedError=$_ }
                                    finally { $form.DialogResult=[Windows.Forms.DialogResult]::Cancel }
                                })
                                try { [void](Show-LenovoOwnedDialog -Form $nested -Owner $child) }
                                finally { $nested.Dispose() }
                                if ($script:NestedError) { throw $script:NestedError }
                                Assert-Lbs267 'nested close restores native shield and side popup' ($child.Visible -and [Lbs267Native]::IsWindowEnabled($s.Handle) -and [Lbs267Native]::IsWindowEnabled($child.Handle) -and $child.ContainsFocus)
                            }
                            [Windows.Forms.Cursor]::Position=$point
                            [Windows.Forms.Application]::DoEvents()
                            $hit=[Lbs267Native]::WindowFromPoint($point)
                            Write-Host "LBS267 HIT kind=$script:Kind case=$script:Case point=$point hit=$hit shield=$($s.Handle) owner=$($main.Handle) child=$($child.Handle)"
                            Assert-Lbs267 'native WindowFromPoint routes owner click to shield' ($hit -eq $s.Handle)
                            Click-Lbs267 $point -Down
                            Assert-Lbs267 'press alone does not close or dispatch' ($child.Visible -and $child.DialogResult -eq [Windows.Forms.DialogResult]::None -and $script:BootCalls -eq $script:BeforeBoot)
                            Click-Lbs267 $point -Up
                            Assert-Lbs267 'release produces Cancel and no underlying dispatch' (($child.DialogResult -eq [Windows.Forms.DialogResult]::Cancel -or -not $child.Visible) -and $script:BootCalls -eq $script:BeforeBoot -and $script:DefaultCalls.Count -eq $script:BeforeDefault -and $script:Actions.Count -eq $script:BeforeActions)
                        }
                        $script:Observed=$true
                    } catch { $script:ProbeError=$_ }
                    finally {
                        # Fail closed on fixture error; don't leave a modal
                        # loop hanging and always release any physical button.
                        [Lbs267Native]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
                        if ($child.Visible -and $child.DialogResult -eq [Windows.Forms.DialogResult]::None) { $child.Tag.Close.PerformClick() }
                    }
                })
                try {
                    [void]$trigger.Focus()
                    $timer.Start()
                    if ($kind -eq 'HeaderSystemStatusButton') { $trigger.PerformClick() } else { Invoke-PopupNavigationRow -Control $trigger }
                } finally { $timer.Stop();$timer.Dispose() }
                if ($script:ProbeError) { throw $script:ProbeError }
                Assert-Lbs267 "$locale/$kind/$case owner and shield fully restored" ($script:Observed -and $script:ShieldProbe.IsDisposed -and -not $script:ActiveAuxiliaryPopup -and $owner.Visible -and $owner.ContainsFocus -and $trigger.Focused -and ($kind -ne 'HeaderSystemStatusButton' -or -not $trigger.ModalActive) -and [Lbs267Native]::IsWindowEnabled($owner.Handle) -and @($owner.OwnedForms | Where-Object Name -in @('AuxiliaryOwnerClickShield','AuxiliaryOwnerDimmer')).Count -eq 0)
                $expectedDefault=if ($case -eq 'normal-child' -and $kind -eq 'DefaultPanel') {1} else {0}
                $expectedActions=if ($case -eq 'normal-child' -and $kind -eq 'SettingsPanel') {1} else {0}
                Assert-Lbs267 "$locale/$kind/$case only intended action count" ($script:BootCalls -eq $script:BeforeBoot -and $script:DefaultCalls.Count -eq $script:BeforeDefault+$expectedDefault -and $script:Actions.Count -eq $script:BeforeActions+$expectedActions)
                if ($case -eq 'content') {
                    Click-Lbs267 (Center-Lbs267 $boot) -Down -Up
                    Assert-Lbs267 'next independent main click dispatches exactly once' ($script:BootCalls -eq $script:BeforeBoot+1)
                }
            }
        }
        foreach ($control in @($rootPanel.Controls | Where-Object Name -ne 'TestBootAction')) { $control.Dispose() }
    }
    $invalid=New-ConfigurationPopup
    $invalid.Enabled=$false
    $failed=$false
    try { [void](Show-OwnedAuxiliaryPopup -Form $invalid -Owner $boot) } catch { $failed=$true }
    Assert-Lbs267 'failed modal show leaves no shield or scrim' ($failed -and $invalid.IsDisposed -and -not $script:ActiveAuxiliaryPopup -and @($owner.OwnedForms | Where-Object Name -in @('AuxiliaryOwnerClickShield','AuxiliaryOwnerDimmer')).Count -eq 0 -and [Lbs267Native]::IsWindowEnabled($owner.Handle))
} finally {
    [Lbs267Native]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    [Windows.Forms.Cursor]::Position=$cursor
    $owner.Dispose();$tray.Dispose()
}
Write-Host "LBS267 OWNER DISMISS TOTAL $script:Checks/239"
if ($script:Checks -ne 239) { throw "Unexpected LBS267 total $script:Checks" }
