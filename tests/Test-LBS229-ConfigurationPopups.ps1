#requires -version 5.1
param([switch]$CorrectionProbeOnly)
# LBS-229: actual native owned forms, no live firmware or privileged actions.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs229Native {
    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr hWnd);
}
'@
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$begin = $template.IndexOf($prefix,[StringComparison]::Ordinal)+$prefix.Length
$end = $template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($begin -lt $prefix.Length -or $end -le $begin) { throw 'Canonical C# controls missing' }
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\PopupPosition.ps1')
. (Join-Path $root 'src\UI\Popup.ps1')
. (Join-Path $root 'src\UI\DefaultTargetMenu.ps1')
. (Join-Path $root 'src\UI\DefaultTargetPresentation.ps1')
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
$script:ActiveAuxiliaryPopup=$null
$script:Checks=0
$script:Actions=@()
$script:DefaultCalls=@()
$script:BootCalls=0
$script:Locale='en-US'
$script:Scale=1.0
function Assert-Lbs229([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS229 FAIL: $Name" }
    $script:Checks++
    Write-Host "PASS LBS229 $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-OrderedEntriesForUi { return @($script:CurrentEntries) }
function Get-EntryByGuid($Guid) { return ($script:CurrentEntries | Where-Object Guid -eq $Guid | Select-Object -First 1) }
function Get-EntryDisplayTitle($Entry) { return [string]$Entry.Title }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ State=$(if ($script:Busy) {'Busy'} elseif ($script:Ready) {'Ready'} else {'Checking'});CanSetDefaultTarget=$script:Ready;IsChecking=(-not $script:Ready) } }
function Test-MaintenanceBusy { return $script:Busy }
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
$owner=New-Object Windows.Forms.Form
$owner.ClientSize=[Drawing.Size]::new(390,672)
$owner.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$owner.Location=[Drawing.Point]::new(20,20)
$owner.ShowInTaskbar=$false
$owner.TopMost=$true
$owner.Show()
[Windows.Forms.Application]::DoEvents()
$area=[Drawing.Rectangle]::new(-1000,-100,3000,1700)
$anchor=[Drawing.Rectangle]::new(0,0,390,672)
$size=[Drawing.Size]::new(390,514)
try {
    # LBS229-F01–F06: focused correction contracts. Keep each check independent
    # so the published basis reports all observed failures rather than stopping at F01.
    $correctionFailures = [Collections.Generic.List[string]]::new()
    function Test-Lbs229Correction([string]$Name,[scriptblock]$Action) {
        try { & $Action; Write-Host "PASS LBS229 correction $Name" }
        catch { $correctionFailures.Add("$Name : $_"); Write-Host "RED LBS229 correction $Name : $_" }
    }
    function Require-Lbs229Correction([bool]$Pass,[string]$Detail) {
        if (-not $Pass) { throw $Detail }
    }
    Test-Lbs229Correction 'F01 row anchor' {
        $trigger = [Drawing.Rectangle]::new(0,400,390,38)
        $p = Get-AuxiliaryPopupLocation $area $anchor $size $trigger
        Require-Lbs229Correction ($p.X -eq 398 -and $p.Y -eq 400) "Expected right side at trigger Y=400, got $p"
    }
    Test-Lbs229Correction 'F01 negative-origin row anchor and bottom clamp' {
        $wa = [Drawing.Rectangle]::new(-1600,-300,1600,900)
        $parent = [Drawing.Rectangle]::new(-430,-100,390,672)
        $trigger = [Drawing.Rectangle]::new(-430,410,390,38)
        $p = Get-AuxiliaryPopupLocation $wa $parent $size $trigger
        Require-Lbs229Correction ($p.X -eq -828 -and $p.Y -eq 86) "Expected left side and clamped trigger Y=86, got $p"
    }
    Test-Lbs229Correction 'F02 full-width focusable settings row' {
        $rootPanel = New-Object Windows.Forms.Panel
        try {
            Add-PopupSettingsSection -Root $rootPanel
            $more = $rootPanel.Controls['SettingsPanel']
            $default = $rootPanel.Controls['DefaultPanel']
            Require-Lbs229Correction ($more.GetType() -eq $default.GetType() -and $more.Width -eq $default.Width -and $more.Height -eq $default.Height -and $more.AccessibleRole -eq [Windows.Forms.AccessibleRole]::PushButton -and $more.TabStop) 'Further settings must use the same full-width keyboard row affordance as Default'
        } finally { $rootPanel.Dispose() }
    }
    Test-Lbs229Correction 'F03 disabled configuration action treatment' {
        $config = New-ConfigurationPopup
        try {
            $install = $config.Tag.Body.Controls['ConfigurationAction-update-install']
            $enabled = $config.Tag.Body.Controls['ConfigurationAction-update-check']
            Require-Lbs229Correction (-not $install.Enabled -and $enabled.Enabled -and $install.ForeColor -ne $enabled.ForeColor -and $install.FlatAppearance.BorderColor -ne $enabled.FlatAppearance.BorderColor -and $install.Cursor -eq [Windows.Forms.Cursors]::Default) 'Disabled install must have muted foreground/border and no hand cursor'
        } finally { $config.Dispose() }
    }
    . (Join-Path $root 'src\Application\RefreshRuntime.ps1')
    . (Join-Path $root 'src\UI\RefreshPresentation.ps1')
    $script:HeaderStatusLabel = New-Object Windows.Forms.Label
    $owner.Controls.Add($script:HeaderStatusLabel)
    $script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState
    $script:BackgroundRefreshState.Process = [pscustomobject]@{}
    $script:UpdateState = [pscustomobject]@{ Status='Idle'; AvailableManifest=$null; CheckProcess=$null; CheckMode='' }
    foreach ($locale in @('en-US','de-DE')) {
        $script:Locale = $locale
        Test-Lbs229Correction "F04 $locale startup header" {
            $script:BackgroundRefreshState.ActiveRequest = [pscustomobject]@{ Origin='Startup' }
            Update-HeaderRefreshStatus
            $expected = if ($script:Locale -eq 'de-DE') { 'Initialisiere Anwendung …' } else { 'Initializing application …' }
            Require-Lbs229Correction ($script:HeaderStatusLabel.Text -eq $expected -and -not $script:HeaderUpdateInteractionEnabled) "Expected $expected, got $($script:HeaderStatusLabel.Text)"
        }
        Test-Lbs229Correction "F05 $locale warm popup header" {
            $script:BackgroundRefreshState.ActiveRequest = [pscustomobject]@{ Origin='Popup' }
            Update-HeaderRefreshStatus
            $expected = if ($script:Locale -eq 'de-DE') { 'Aktualisiere Anwendungsstatus …' } else { 'Refreshing application state …' }
            Require-Lbs229Correction ($script:HeaderStatusLabel.Text -eq $expected -and -not $script:HeaderUpdateInteractionEnabled) "Expected $expected, got $($script:HeaderStatusLabel.Text)"
        }
        Test-Lbs229Correction "F06 $locale manual refresh precedence" {
            $script:BackgroundRefreshState.ActiveRequest = [pscustomobject]@{ Origin='Manual' }
            $script:UpdateState.CheckMode = 'Popup'
            $script:UpdateState.CheckProcess = [pscustomobject]@{}
            $script:UpdateState.Status = 'Checking'
            Update-HeaderRefreshStatus
            Require-Lbs229Correction ($script:HeaderStatusLabel.Text -eq (Get-LocalizedString -Key 'Header.Refreshing')) 'Manual boot refresh retains boot-specific status even during a legitimate popup update check'
        }
        Test-Lbs229Correction "F05 $locale independent popup update lifetime" {
            $script:BackgroundRefreshState.Process = $null
            $script:BackgroundRefreshState.ActiveRequest = $null
            Update-HeaderRefreshStatus
            $expected = if ($script:Locale -eq 'de-DE') { 'Aktualisiere Anwendungsstatus …' } else { 'Refreshing application state …' }
            Require-Lbs229Correction ($script:HeaderStatusLabel.Text -eq $expected -and -not $script:HeaderUpdateInteractionEnabled) "Expected $expected during remaining popup update work, got $($script:HeaderStatusLabel.Text)"
        }
        Test-Lbs229Correction "F05 $locale terminal update available" {
            $script:UpdateState.CheckProcess = $null
            $script:UpdateState.CheckMode = ''
            $script:UpdateState.Status = 'UpdateAvailable'
            $script:UpdateState.AvailableManifest = [pscustomobject]@{ Version='9.9.9.9' }
            Update-HeaderRefreshStatus
            Require-Lbs229Correction ($script:HeaderStatusLabel.Text -eq (Get-LocalizedString -Key 'Update.Available') -and $script:HeaderUpdateInteractionEnabled) 'Terminal verified update availability regains its interactive header'
        }
        $script:BackgroundRefreshState.Process = [pscustomobject]@{}
        $script:UpdateState.Status = 'Idle'
        $script:UpdateState.AvailableManifest = $null
    }
    $script:BackgroundRefreshState = $null
    $script:UpdateState = $null
    $script:HeaderStatusLabel.Dispose()
    $script:HeaderStatusLabel = $null
    $script:Locale = 'en-US'
    if ($correctionFailures.Count) { throw ("LBS229 correction RED: " + ($correctionFailures -join '; ')) }
    if ($CorrectionProbeOnly) { return }

    $p=Get-AuxiliaryPopupLocation $area $anchor $size
    Assert-Lbs229 'right placement stays on owner monitor' ($p.X -eq 398 -and $p.Y -eq 0)
    $rightEdge=[Drawing.Rectangle]::new(1600,1200,390,400)
    $p=Get-AuxiliaryPopupLocation $area $rightEdge $size
    Assert-Lbs229 'left placement and bottom clamp' ($p.X -eq 1202 -and $p.Y -eq 1086)
    $p=Get-AuxiliaryPopupLocation ([Drawing.Rectangle]::new(-420,0,420,620)) ([Drawing.Rectangle]::new(-410,0,390,600)) $size
    Assert-Lbs229 'no side available remains within working area' ($p.X -ge -420 -and $p.X+390 -le 0)
    foreach ($locale in @('en-US','de-DE')) {
        $script:Locale=$locale
        $script:LanguageEnglishMenuItem.Text=Get-LocalizedString -Key 'Language.English'
        $script:LanguageGermanMenuItem.Text=Get-LocalizedString -Key 'Language.German'
        $script:LanguageEnglishMenuItem.Checked=($locale -eq 'en-US')
        $script:LanguageGermanMenuItem.Checked=($locale -eq 'de-DE')
        $script:TaskBrokerSetupMenuItem.Text=Get-LocalizedString -Key 'Maintenance.Menu.Repair'
        $script:TaskBrokerRemoveMenuItem.Text=Get-LocalizedString -Key 'Maintenance.Remove'
        $script:UpdateCheckMenuItem.Text=Get-LocalizedString -Key 'Update.Check'
        $script:UpdateInstallMenuItem.Text=Get-LocalizedString -Key 'Update.Install'
        $script:RuntimeDiagnosticMenuItem.Text=Get-LocalizedString -Key 'Diagnostics.Save'
        $script:DiagnosticsUploadMenuItem.Text=Get-LocalizedString -Key 'Diagnostics.Upload'
        foreach ($scale in @(1.0,2.5)) {
            $case="$locale/$scale"
            $config=New-ConfigurationPopup
            try {
                Set-AuxiliaryPopupLayout $config $scale $area $anchor
                $body=$config.Tag.Body
                $button=@($body.Controls | Where-Object { $_ -is [Windows.Forms.Button] })
                Assert-Lbs229 "$case flat configuration has all eight direct actions" ($button.Count -eq 8 -and $body.Controls['ConfigurationAutostart'] -and $config.CancelButton -eq $config.Tag.Close)
                Assert-Lbs229 "$case bounds and typography scale once" ($config.Width -eq [int](390*$scale) -and $button[0].Height -eq [int](34*$scale) -and $button[0].Font.Size -eq 9.0)
                Assert-Lbs229 "$case language selection and disabled install truthful" ($body.Controls["ConfigurationAction-language-$(if ($locale -eq 'de-DE') {'de'} else {'en'})"].Text.StartsWith('✓ ') -and -not $body.Controls['ConfigurationAction-update-install'].Enabled)
                $script:UpdateInstallMenuItem.Enabled=$true
                Update-ConfigurationPopupPresentation $config
                Assert-Lbs229 "$case existing availability changes mirrored" ($body.Controls['ConfigurationAction-update-install'].Enabled)
                $script:UpdateInstallMenuItem.Enabled=$false
                $script:Busy=$true
                Update-ConfigurationPopupPresentation $config
                Assert-Lbs229 "$case busy gate disables all configuration actions" (@($button | Where-Object Enabled).Count -eq 0 -and -not $body.Controls['ConfigurationAutostart'].Enabled)
                $script:Busy=$false
                Update-ConfigurationPopupPresentation $config
                $bitmap=[Drawing.Bitmap]::new(100,100)
                $bitmap.SetResolution([single](96*$scale),[single](96*$scale))
                $g=[Drawing.Graphics]::FromImage($bitmap)
                try {
                    $fit=$true
                    foreach ($b in $button) {
                        $size=$g.MeasureString($b.Text,$b.Font)
                        if ($size.Width -gt $b.Width - 8*$scale -or $b.Font.GetHeight([single](96*$scale)) -gt $b.Height) { $fit=$false }
                    }
                    Assert-Lbs229 "$case localized action labels fit synthetic design bounds" $fit
                } finally { $g.Dispose(); $bitmap.Dispose() }
            } finally { $config.Dispose() }
            $picker=New-DefaultTargetPicker
            try {
                Set-AuxiliaryPopupLayout $picker $scale $area $anchor
                $rows=@($picker.Tag.Body.Controls | Where-Object Name -eq 'DefaultPickerRow')
                $selected=@($rows | Where-Object {$_.Tag.Selected})
                Assert-Lbs229 "$case all visible ordered choices plus none" ($rows.Count -eq 15 -and -not $rows[0].Tag.Guid -and $rows[1].Tag.Guid -eq 'a')
                Assert-Lbs229 "$case persistent marker independent of one-shot" ($selected.Count -eq 1 -and $selected[0].Tag.Guid -eq 'a' -and $selected[0].Controls['DefaultPickerSelected'])
                Assert-Lbs229 "$case familiar row geometry and full accessible text" ($rows[1].Height -eq [int](60*$scale) -and $rows[1].Controls['DefaultPickerTitle'].AccessibleDescription -eq 'Corporate' -and $rows[1].Controls['DefaultPickerSubtitle'].Text -eq 'Internal SSD')
                Assert-Lbs229 "$case long list scroll extent exceeds visible body" ($picker.Tag.Body.AutoScroll -and $picker.Tag.Body.AutoScrollMinSize.Height -gt $picker.Tag.Body.Height)
            } finally { $picker.Dispose() }
        }
    }
    $small=New-ConfigurationPopup
    try {
        Set-AuxiliaryPopupLayout $small 2.5 ([Drawing.Rectangle]::new(-400,0,800,600)) ([Drawing.Rectangle]::new(-390,0,700,590))
        Assert-Lbs229 'small work area clamps child and exposes scrolling' ($small.Width -le 800 -and $small.Height -le 600 -and $small.Tag.Body.AutoScroll -and $small.Tag.Close.Right -le $small.Width)
    } finally { $small.Dispose() }
    $script:DefaultTargetReadUncertain=$true
    $unknown=New-DefaultTargetPicker
    try { Assert-Lbs229 'uncertain read has no selected marker' (@($unknown.Tag.Body.Controls | Where-Object {$_.Tag.Selected}).Count -eq 0) } finally { $unknown.Dispose() }
    $script:DefaultTargetReadUncertain=$false
    Assert-Lbs229 'building and scaling controls does not invoke any action' ($script:Actions.Count -eq 0 -and $script:DefaultCalls.Count -eq 0 -and $script:BootCalls -eq 0)

    # Drive real modal surfaces through the WinForms message loop. A watchdog
    # closes the child even if an assertion or event fails; never touch firmware.
    function Invoke-Lbs229Modal([string]$Kind,[scriptblock]$Action) {
        $script:ModalAction=$Action
        $script:ModalError=$null
        $script:ModalObserved=$false
        $timer=New-Object Windows.Forms.Timer
        $timer.Interval=50
        $timer.Add_Tick({
            param($sender,$eventArgs)
            $active=$script:ActiveAuxiliaryPopup
            if (-not $active -or -not $active.Visible) { return }
            $sender.Stop()
            $script:ModalObserved=$true
            try { & $script:ModalAction $active }
            catch { $script:ModalError=$_ }
            finally { if ($active.DialogResult -eq [Windows.Forms.DialogResult]::None) { $active.DialogResult=[Windows.Forms.DialogResult]::Cancel } }
        })
        try {
            $timer.Start()
            if ($Kind -eq 'default') { Show-DefaultTargetMenu -Owner $owner }
            else { Show-ConfigurationPopup -Owner $owner }
        } finally { $timer.Stop(); $timer.Dispose() }
        if ($script:ModalError) { throw $script:ModalError }
        Assert-Lbs229 "$Kind modal actually shown, ownership released" ($script:ModalObserved -and -not $script:ActiveAuxiliaryPopup -and $owner.Visible -and [Lbs229Native]::IsWindowEnabled($owner.Handle))
    }
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        Assert-Lbs229 'owned main disabled while child is open' (-not [Lbs229Native]::IsWindowEnabled($owner.Handle) -and $owner.Visible)
        $active.Tag.Close.PerformClick()
    }
    Assert-Lbs229 'configuration cancel performs no action' ($script:Actions.Count -eq 0)
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        $check=$active.Tag.Body.Controls['ConfigurationAutostart']
        Invoke-ConfigurationPopupAction $check
        Assert-Lbs229 'autostart delegates once and stays in popup with checked state' ($script:Actions.Count -eq 1 -and $script:Actions[0] -eq 'autostart' -and $check.Checked -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None)
        $active.Tag.Close.PerformClick()
    }
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        $active.Tag.Body.Controls['ConfigurationAction-update-check'].PerformClick()
        Assert-Lbs229 'advanced choice does not dispatch before child closes' ($script:Actions.Count -eq 1)
    }
    Assert-Lbs229 'advanced selection delegates to existing menu action exactly once' ($script:Actions.Count -eq 2 -and $script:Actions[1] -eq 'update-check')
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        $active.Tag.Body.Controls['ConfigurationAction-language-en'].PerformClick()
    }
    Assert-Lbs229 'direct language choice dispatches existing language action' ($script:Actions.Count -eq 3 -and $script:Actions[2] -eq 'language-en')
    Invoke-Lbs229Modal 'default' {
        param($active)
        $active.Tag.Close.PerformClick()
    }
    Assert-Lbs229 'default cancellation performs no write' ($script:DefaultCalls.Count -eq 0)
    Invoke-Lbs229Modal 'default' {
        param($active)
        $row=$active.Tag.Body.Controls | Where-Object {$_.Tag.Guid -eq 'b'} | Select-Object -First 1
        [void]$row.Focus()
        Assert-Lbs229 'focus alone does not dispatch default or BootNext' ($script:DefaultCalls.Count -eq 0 -and $script:BootCalls -eq 0)
        Invoke-DefaultPickerRow $row.Controls['DefaultPickerTitle']
        Assert-Lbs229 'default choice recorded before controller dispatch' ($script:DefaultCalls.Count -eq 0 -and $active.Tag.Choice.Guid -eq 'b')
    }
    Assert-Lbs229 'picker delegates exactly once to persistent-default controller' ($script:DefaultCalls.Count -eq 1 -and $script:DefaultCalls[0] -eq 'b' -and $script:BootCalls -eq 0)
    Invoke-Lbs229Modal 'default' {
        param($active)
        $none=$active.Tag.Body.Controls | Where-Object {-not $_.Tag.Guid} | Select-Object -First 1
        Invoke-DefaultPickerRow $none
    }
    Assert-Lbs229 'clear option delegates null without BootNext dispatch' ($script:DefaultCalls.Count -eq 2 -and -not $script:DefaultCalls[1] -and $script:BootCalls -eq 0)
    Invoke-Lbs229Modal 'default' {
        param($active)
        $script:DefaultGuid='b'
        Invoke-DefaultPickerRow $active.Tag.Body.Controls[1]
        Assert-Lbs229 'changed readback invalidates stale picker' ($active.DialogResult -eq [Windows.Forms.DialogResult]::Cancel)
    }
    Assert-Lbs229 'stale picker dispatches no action' ($script:DefaultCalls.Count -eq 2)
    $script:BootNextPendingGuid='b'
    Show-DefaultTargetMenu -Owner $owner
    Assert-Lbs229 'pending one-shot gate blocks default popup entirely' (-not $script:ActiveAuxiliaryPopup -and $script:DefaultCalls.Count -eq 2)
    $script:BootNextPendingGuid=$null
    $script:Busy=$true
    Show-ConfigurationPopup -Owner $owner
    Assert-Lbs229 'busy gate blocks settings popup entirely' (-not $script:ActiveAuxiliaryPopup -and $script:Actions.Count -eq 3)
} finally {
    $owner.Dispose()
    $tray.Dispose()
}
Write-Host "LBS229 CONFIGURATION TOTAL $script:Checks"
