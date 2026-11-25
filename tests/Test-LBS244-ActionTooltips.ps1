#requires -version 5.1
param([switch]$BaselineProbe)
# LBS-244: actual popup controls and native pointer-triggered tooltip evidence. No firmware or settings mutations.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
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
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\PopupPosition.ps1')
. (Join-Path $root 'src\UI\Popup.ps1')
. (Join-Path $root 'src\UI\DefaultTargetMenu.ps1')
. (Join-Path $root 'src\UI\DefaultTargetPresentation.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
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
function Assert-Lbs244Action([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS244 ACTION FAIL: $Name" }
    $script:Checks++
    Write-Host "PASS LBS244 ACTION $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-OrderedEntriesForUi { return @($script:CurrentEntries) }
function Get-EntryByGuid($Guid) { return ($script:CurrentEntries | Where-Object Guid -eq $Guid | Select-Object -First 1) }
function Get-EntryDisplayTitle { param($Entry,[switch]$UseManageDraft) return [string]$Entry.Title }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ State=$(if ($script:Busy) {'Busy'} elseif ($script:Ready) {'Ready'} else {'Checking'});CanSetDefaultTarget=$script:Ready;CanRefresh=$script:Ready;IsChecking=(-not $script:Ready) } }
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

. (Join-Path $root 'src\Core\BootNextSelectionState.ps1')
. (Join-Path $root 'src\Core\BootNextOwnership.ps1')
. (Join-Path $root 'src\UI\RefreshPresentation.ps1')
$script:ColorWarning=[Drawing.Color]::Orange
$script:NextBootFirmwareReadVerified=$true
$script:DefaultInteractionEnabled=$true
$script:Hidden=$false
$script:AppVersion='test'
$script:CurrentEntries[0] | Add-Member NoteProperty RawDescription NVMe0
$script:CurrentEntries[0] | Add-Member NoteProperty TypeTooltip 'Internal SSD'
$script:CurrentEntries[1] | Add-Member NoteProperty RawDescription 'USB HDD'
$script:CurrentEntries[1] | Add-Member NoteProperty TypeTooltip 'USB drive'
function Get-EntryAlias { param($Guid,[switch]$UseManageDraft) return '' }
function Test-ManageEntryHidden { param($Guid) return $script:Hidden }
function Get-NextBootTargetDisplayName { return 'Gaming' }
function Update-BootNextRestartInterlock {}
function Test-BackgroundRefreshActive { return $false }
function Get-CurrentSystemFunctionsCapabilities {
    return [pscustomobject]@{ State='Ready';CanSetDefaultTarget=$true;CanSetBootNext=$true;CanRefresh=$script:Ready;IsChecking=$false }
}
$start=$template.IndexOf('function Update-RestartTargetUi {')
$end=$template.IndexOf('function Restart-Windows {',$start)
if ($start -lt 0 -or $end -le $start) { throw 'Missing canonical reset presentation function' }
. ([scriptblock]::Create($template.Substring($start,$end-$start)))
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.Threading;
public sealed class Lbs244HoverObserver : IDisposable {
    readonly ToolTip tip;
    Control expected;
    public int Popups, Draws;
    public Lbs244HoverObserver(ToolTip toolTip) {
        tip=toolTip; tip.Popup+=Popup; tip.Draw+=Draw;
    }
    void Popup(object sender, PopupEventArgs e) { if (e.AssociatedControl==expected && !e.Cancel) Popups++; }
    void Draw(object sender, DrawToolTipEventArgs e) { if (e.AssociatedControl==expected) Draws++; }
    static void Pump(int milliseconds) {
        Stopwatch sw=Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds<milliseconds) { Application.DoEvents(); Thread.Sleep(15); }
    }
    public bool Hover(Control c,int x,int y) {
        if (!c.Visible || !c.Enabled || c.IsDisposed) return false;
        Form f=c.FindForm(); f.Activate(); Pump(100);
        Cursor.Position=f.PointToScreen(new Point(f.ClientSize.Width-3, f.ClientSize.Height-3));
        Pump(200);
        expected=c; Popups=Draws=0;
        Point target=c.PointToScreen(new Point(x,y));
        Cursor.Position=target;
        Stopwatch sw=Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds<2200) {
            Application.DoEvents(); Thread.Sleep(15);
            if (Popups>0 && (!tip.OwnerDraw || Draws>0)) return true;
        }
        return false;
    }
    public void Dispose() { tip.Popup-=Popup; tip.Draw-=Draw; }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing
function Test-Hover {
    param($Observer,$Control,[string]$Name,[int]$X=-1,[int]$Y=-1)
    if ($X -lt 0) { $X=[int]($Control.Width/2) }
    if ($Y -lt 0) { $Y=[int]($Control.Height/2) }
    $ok=$Observer.Hover($Control,$X,$Y)
    Write-Host "LBS244 HOVER $Name visible=$($Control.Visible) enabled=$($Control.Enabled) popup=$($Observer.Popups) draw=$($Observer.Draws) result=$ok"
    return $ok
}
function Assert-Binding {
    param($Tip,$Control,[string]$Key,$Values)
    $expected=Get-LocalizedString -Key $Key -Values $Values
    Assert-Lbs244Action "$($Control.Name) binding $Key" ($Tip.GetToolTip($Control).Contains($expected) -and $expected -ne $Key)
}
$cursorBefore=[Windows.Forms.Cursor]::Position
$owner=New-Object Windows.Forms.Form
$owner.ClientSize=[Drawing.Size]::new(390,672)
$owner.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$owner.Location=[Drawing.Point]::new(20,20)
$owner.ShowInTaskbar=$false
$owner.TopMost=$true
$rootPanel=New-Object Windows.Forms.Panel
$rootPanel.Dock=[Windows.Forms.DockStyle]::Fill
$owner.Controls.Add($rootPanel)
$script:BootTypeToolTip=New-LenovoDarkTooltip -Animate
$obs=[Lbs244HoverObserver]::new($script:BootTypeToolTip)
try {
    Add-PopupHeaderSection -Root $rootPanel
    Add-PopupSettingsSection -Root $rootPanel
    Add-PopupRestartSection -Root $rootPanel
    $owner.Show()
    [Windows.Forms.Application]::DoEvents()
    Update-DefaultUi
    Update-RestartTargetUi
    $refreshHover=Test-Hover $obs $script:RefreshButton 'F01 refresh'
    $resetHover=Test-Hover $obs $script:RestartUseDefaultButton 'F04 reset'
    # Observe after repeated identical presentation updates, but do not
    # equate any isolated hosted result with the owner's intermittent failure.
    1..12 | ForEach-Object { Update-RestartTargetUi; [Windows.Forms.Application]::DoEvents() }
    $resetAgain=Test-Hover $obs $script:RestartUseDefaultButton 'F04 reset after updates'
    if ($BaselineProbe) {
        Write-Host "LBS244 BASELINE OBSERVATION refresh=$refreshHover reset=$resetHover repeatedReset=$resetAgain"
        return
    }
    Assert-Lbs244Action 'F01 native refresh popup/draw' $refreshHover
    Assert-Lbs244Action 'F04 native reset popup/draw' $resetHover
    Assert-Lbs244Action 'F04 native reset after repeated UI updates' $resetAgain
    Assert-Binding $script:BootTypeToolTip $script:ManageEntriesButton 'Tooltip.Customize'
    Assert-Lbs244Action 'F02 actual Customize hover' (Test-Hover $obs $script:ManageEntriesButton 'Customize')
    $more=$rootPanel.Controls['SettingsPanel']
    foreach ($control in @($more)+@($more.Controls)) { Assert-Binding $script:BootTypeToolTip $control 'Tooltip.Settings' }
    Assert-Lbs244Action 'F03 actual navigation label hover' (Test-Hover $obs $more.Controls['MoreSettingsButton'] 'settings label')
    $default=$rootPanel.Controls['DefaultPanel']
    foreach ($control in @($default)+@($default.Controls)) { Assert-Binding $script:BootTypeToolTip $control 'Tooltip.DefaultNavigation' }
    Assert-Lbs244Action 'F03 actual default value hover' (Test-Hover $obs $script:DefaultValueLabel 'default value')
    Assert-Binding $script:BootTypeToolTip $script:RestartButton 'Tooltip.Restart'
    Assert-Lbs244Action 'F04 actual Restart hover' (Test-Hover $obs $script:RestartButton 'restart')
    foreach ($caseLocale in @('en-US','de-DE')) {
        $script:Locale=$caseLocale
        $entry=$script:CurrentEntries[0]
        $row=(New-BootEntryRow -Entry $entry -Y 110 -BaseRowHeight 60 -Handlers (New-BootEntryInteractionHandlers)).Row
        $rootPanel.Controls.Add($row)
        try {
            foreach ($control in @($row)+@($row.Controls)) { Assert-Binding $script:BootTypeToolTip $control 'Tooltip.NextBoot' @{Target=$entry.Title} }
            Assert-Lbs244Action "$caseLocale F07 actual normal title hover" (Test-Hover $obs $row.Controls['BootTitleLabel'] "normal title $caseLocale")
            $script:BootNextPendingGuid='b'
            Update-NormalBootEntryTooltips -Row $row -Entry $entry
            Assert-Binding $script:BootTypeToolTip $row 'Tooltip.NextBootPending'
            $script:BootNextPendingGuid=$null
            Update-NormalBootEntryTooltips -Row $row -Entry $entry
        } finally { $row.Dispose() }
        $script:IsManageEntriesMode=$true
        $script:Hidden=$true
        $row=(New-BootEntryRow -Entry $entry -Y 110 -BaseRowHeight 60 -Handlers (New-BootEntryInteractionHandlers)).Row
        $rootPanel.Controls.Add($row)
        try {
            $icon=$row.Controls['BootTypeGlyph']
            Assert-Binding $script:BootTypeToolTip $icon 'Tooltip.HiddenType'
            Assert-Lbs244Action "$caseLocale F08 hidden icon color and category" ($icon.ForeColor.ToArgb() -eq [Drawing.Color]::FromArgb(115,115,115).ToArgb() -and $script:BootTypeToolTip.GetToolTip($icon).Contains($entry.TypeTooltip))
            Assert-Lbs244Action "$caseLocale F08 actual hidden type circle hover" (Test-Hover $obs $icon "hidden type $caseLocale")
        } finally { $row.Dispose(); $script:IsManageEntriesMode=$false; $script:Hidden=$false }
        $cfg=New-ConfigurationPopup
        $cfg.Location=[Drawing.Point]::new(30,25)
        $co=[Lbs244HoverObserver]::new($cfg.Tag.Tip)
        try {
            $cfg.Show(); [Windows.Forms.Application]::DoEvents()
            foreach ($control in $cfg.Tag.Body.Controls) { if ($control.Tag) { Assert-Binding $cfg.Tag.Tip $control ('Tooltip.Configuration.'+[string]$control.Tag) } }
            Assert-Binding $cfg.Tag.Tip $cfg.Tag.Close 'Tooltip.CloseSettings'
            Assert-Lbs244Action "$caseLocale F06 settings hand cursor" ($cfg.Tag.Close.Cursor -eq [Windows.Forms.Cursors]::Hand)
            Assert-Lbs244Action "$caseLocale F05 native settings action hover" (Test-Hover $co $cfg.Tag.Body.Controls['ConfigurationAction-language-de'] "language $caseLocale")
            Assert-Lbs244Action "$caseLocale F06 native settings close hover" (Test-Hover $co $cfg.Tag.Close "settings close $caseLocale")
            $script:Locale=if ($caseLocale -eq 'en-US') { 'de-DE' } else { 'en-US' }
            Update-ConfigurationPopupLocale -Form $cfg
            Assert-Binding $cfg.Tag.Tip $cfg.Tag.Close 'Tooltip.CloseSettings'
            Assert-Binding $cfg.Tag.Tip $cfg.Tag.Body.Controls['ConfigurationAction-language-de'] 'Tooltip.Configuration.language-de'
            $script:Locale=$caseLocale
            Update-ConfigurationPopupLocale -Form $cfg
        } finally { $co.Dispose(); $cfg.Dispose() }
        $picker=New-DefaultTargetPicker
        $picker.Location=[Drawing.Point]::new(30,25)
        $po=[Lbs244HoverObserver]::new($picker.Tag.Tip)
        try {
            $picker.Show(); [Windows.Forms.Application]::DoEvents()
            $rows=@($picker.Tag.Body.Controls | Where-Object Name -eq 'DefaultPickerRow' | Sort-Object Top)
            Assert-Binding $picker.Tag.Tip $rows[0] 'Tooltip.ClearDefault'
            Assert-Binding $picker.Tag.Tip $rows[1] 'Tooltip.CurrentDefault'
            foreach ($control in @($rows[2])+@($rows[2].Controls)) { Assert-Binding $picker.Tag.Tip $control 'Tooltip.SetDefault' @{Target='Gaming'} }
            Assert-Binding $picker.Tag.Tip $picker.Tag.Close 'Tooltip.ClosePicker'
            Assert-Lbs244Action "$caseLocale F06 picker hand cursor" ($picker.Tag.Close.Cursor -eq [Windows.Forms.Cursors]::Hand)
            Assert-Lbs244Action "$caseLocale F09 actual picker title hover" (Test-Hover $po $rows[2].Controls['DefaultPickerTitle'] "picker title $caseLocale")
            Assert-Lbs244Action "$caseLocale F06 actual picker close hover" (Test-Hover $po $picker.Tag.Close "picker close $caseLocale")
            $picker.Tag.Close.PerformClick()
            Assert-Lbs244Action "$caseLocale F06 close does not choose default" ($null -eq $picker.Tag.Choice -and $picker.DialogResult -eq [Windows.Forms.DialogResult]::Cancel)
        } finally { $po.Dispose(); $picker.Dispose() }
    }
    Assert-Lbs244Action 'Hover and close never execute fixture actions' ($script:Actions.Count -eq 0 -and $script:DefaultCalls.Count -eq 0 -and $script:BootCalls -eq 0)
    if ($script:Checks -ne 95) { throw "Unexpected action tooltip assertion count: $script:Checks" }
    Write-Host "LBS244 ACTION TOTAL $script:Checks/95"
} finally {
    $obs.Dispose()
    $script:BootTypeToolTip.Dispose()
    $owner.Dispose()
    $tray.Dispose()
    [Windows.Forms.Cursor]::Position=$cursorBefore
}
