#requires -version 5.1
param([switch]$CorrectionProbeOnly,[switch]$SettingsCorrectionProbeOnly,[switch]$InitialFocusProbeOnly,[switch]$FocusOutlineProbeOnly,[switch]$DefaultInitialFocusProbeOnly,[switch]$Lbs182StatusProbeOnly)
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
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint command);
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }
    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(NativePoint point);
    public static IntPtr Hit(int x, int y) { return WindowFromPoint(new NativePoint { X=x, Y=y }); }
    [DllImport("user32.dll")]
    public static extern IntPtr GetFocus();
    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@
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
$script:Lbs247Checks=0
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
    function Test-Lbs182StatusOverview {
        $startChecks=$script:Checks
        $savedLocale=$script:Locale
        $savedScale=$script:Scale
        $savedDefault=$script:DefaultGuid
        $savedSelected=$script:SelectedGuid
        $savedReady=$script:Ready
        $savedActions=$script:Actions.Count
        $savedCalls=$script:BootCalls
        $savedDefaultCalls=$script:DefaultCalls.Count
        $savedCursor=[Windows.Forms.Cursor]::Position
        . (Join-Path $root 'src\Application\RefreshRuntime.ps1')
        . (Join-Path $root 'src\UI\RefreshPresentation.ps1')
        $script:BackgroundRefreshState=New-BackgroundRefreshRuntimeState
        $script:SystemStatusDefaultEvidence='configured'
        $script:DefaultTargetReadUncertain=$false
        $script:SystemStatusCapabilities=[pscustomobject]@{State='Ready'}
        $script:NextBootFirmwareReadVerified=$true
        $script:SystemStatusNextObservedUtc=[datetime]::UtcNow.AddMinutes(-2)
        $script:SystemStatusEntriesObservedUtc=[datetime]::UtcNow.AddMinutes(-4)
        $script:SystemStatusReadinessObservedUtc=[datetime]::UtcNow.AddMinutes(-3)
        $script:SystemStatusLastRefresh='success'
        $script:BootTargetDriftState=[pscustomobject]@{Evaluated=$true;HasDrift=$false}
        $script:SystemStatusDriftFailed=$false
        $rootPanel=New-Object Windows.Forms.Panel
        $rootPanel.Size=$owner.ClientSize
        $owner.Controls.Add($rootPanel)
        try {
            $tokens=$null; $parseErrors=$null
            $brokerAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src\Infrastructure\TaskBroker.ps1'),[ref]$tokens,[ref]$parseErrors)
            if ($parseErrors.Count) { throw 'LBS182 broker source cannot be parsed' }
            foreach ($functionName in @('Get-SystemStatusObservationHash','Test-SystemStatusObservationMatch')) {
                $definition=$brokerAst.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName },$true)
                if (-not $definition) { throw "Missing observation helper $functionName" }
                . ([scriptblock]::Create($definition.Extent.Text))
            }
            $observed=Get-SystemStatusObservationHash 'fixture observed content'
            Assert-Lbs229 'LBS182 identical observed content retains provenance' ($observed -and (Test-SystemStatusObservationMatch 'fixture observed content' $observed))
            Assert-Lbs229 'LBS182 changed cache content cannot retain observation provenance' (-not (Test-SystemStatusObservationMatch 'different cache content' $observed))
            Assert-Lbs229 'LBS182 missing observation cannot establish provenance' (-not (Test-SystemStatusObservationMatch 'fixture observed content' $null))
            $model=Get-SystemStatusPresentation
            Assert-Lbs229 'LBS182 different targets remain valid and require no intervention' ($model.Default -eq 'Value' -and $model.Next -eq 'Value' -and $model.Relation -eq 'Differs' -and $model.Summary -eq 'SummaryReady')
            $script:SelectedGuid='a'
            Assert-Lbs229 'LBS182 aligned confirmed targets' ((Get-SystemStatusPresentation).Relation -eq 'Matches')
            $script:SelectedGuid=$null
            Assert-Lbs229 'LBS182 confirmed firmware order is not unknown' ((Get-SystemStatusPresentation).Next -eq 'FirmwareOrder')
            $script:NextBootFirmwareReadVerified=$false
            Assert-Lbs229 'LBS182 failed read cannot assert firmware order' ((Get-SystemStatusPresentation).Next -eq 'Unknown')
            $script:NextBootFirmwareReadVerified=$true
            $script:SystemStatusNextObservedUtc=$null
            Assert-Lbs229 'LBS182 cached read without timestamp is unknown' ((Get-SystemStatusPresentation).Next -eq 'Unknown')
            $script:SystemStatusNextObservedUtc=[datetime]::UtcNow.AddMinutes(-2)
            $script:SelectedGuid='missing'
            Assert-Lbs229 'LBS182 unavailable next target is not exposed as raw identifier' ((Get-SystemStatusPresentation).Next -eq 'Unavailable')
            $script:SelectedGuid='b'
            $script:BootNextPendingGuid='a'
            Assert-Lbs229 'LBS182 pending selection cannot appear verified' ((Get-SystemStatusPresentation).Next -eq 'Pending')
            $script:BootNextPendingGuid=$null
            $script:SystemStatusDefaultEvidence='unknown'
            Assert-Lbs229 'LBS182 missing default evidence is not a cleared setting' ((Get-SystemStatusPresentation).Default -eq 'Unknown')
            $script:DefaultGuid=$null
            $script:SystemStatusDefaultEvidence='none'
            Assert-Lbs229 'LBS182 explicit unset default is distinct' ((Get-SystemStatusPresentation).Default -eq 'NoDefault')
            $script:DefaultGuid='a'
            $script:SystemStatusDefaultEvidence='configured'
            $script:SystemStatusReadinessObservedUtc=$null
            Assert-Lbs229 'LBS182 no readiness probe cannot claim readiness' ((Get-SystemStatusPresentation).Readiness -eq 'Unknown')
            $script:SystemStatusReadinessObservedUtc=[datetime]::UtcNow.AddMinutes(-3)
            $script:SystemStatusLastRefresh='error'
            Assert-Lbs229 'LBS182 failed refresh not all clear' ((Get-SystemStatusPresentation).Summary -eq 'SummaryUnknown' -and (Get-SystemStatusPresentation).Refresh -eq 'RefreshFailed')
            $script:SystemStatusLastRefresh='success'
            $script:SystemStatusDriftFailed=$true
            Assert-Lbs229 'LBS182 failed drift comparison cannot claim unchanged' ((Get-SystemStatusPresentation).Drift -eq 'Unknown')
            $script:SystemStatusDriftFailed=$false
            foreach ($state in @('SetupRequired','RepairRequired','ReinitializeRequired','Busy','Checking','Unknown')) {
                $script:SystemStatusCapabilities.State=$state
                $model=Get-SystemStatusPresentation
                Assert-Lbs229 "LBS182 capability $state" ($model.Readiness -eq $state -and $model.Summary -ne 'SummaryReady' -and (($state -in @('SetupRequired','RepairRequired','ReinitializeRequired')) -eq [bool]$model.Hint))
            }
            $script:Ready=$false
            Add-PopupHeaderSection -Root $rootPanel
            $info=$script:SystemStatusButton
            $refresh=$script:RefreshButton
            Assert-Lbs229 'LBS182 info available while refresh disabled' ($info.Enabled -and $info.TabStop -and -not $refresh.Enabled)
            foreach ($locale in @('de-DE','en-US')) {
                $script:Locale=$locale
                foreach ($scale in @(1.0,2.5)) {
                    $script:Scale=$scale
                    $script:SystemStatusCapabilities=[pscustomobject]@{State='Ready'}
                    $form=New-SystemStatusPopup
                    try {
                        Set-AuxiliaryPopupLayout -Form $form -Scale $scale -WorkingArea $area -OwnerBounds $anchor
                        $labels=@($form.Tag.Body.Controls | Where-Object Name -like 'SystemStatusValue-*')
                        Assert-Lbs229 "LBS182 $locale/$scale localized read-only labels and layout" ($labels.Count -eq 6 -and @($labels | Where-Object {$_.Width -le 0 -or $_.Right -gt $form.Tag.Body.Width -or $_.Bottom -gt $form.Tag.Body.Height -or $_.AccessibleName -ne $_.Text -or $_.Text -match '^SystemStatus\.'}).Count -eq 0 -and $form.Tag.Body.Controls['SystemStatusValue-Stored'].Text -eq 'Corporate' -and $form.Tag.Body.Controls['SystemStatusValue-Next'].Text -match 'Gaming' -and @($form.Tag.Body.Controls | Where-Object TabStop).Count -eq 0)
                        $body=$form.Tag.Body
                        $visibleText=@($body.Controls | Where-Object { $_ -is [Windows.Forms.Label] -and $_.Text })
                        $bad=@($visibleText | Where-Object { $_.Width -le 0 -or $_.Height -le 0 -or $_.Right -gt $body.Width -or $_.Bottom -gt $body.Height -or $_.BackColor -ne $body.BackColor -or $_.AutoEllipsis })
                        $overlaps=0
                        for ($i=0;$i -lt $visibleText.Count;$i++) {
                            for ($j=$i+1;$j -lt $visibleText.Count;$j++) {
                                if ($visibleText[$i].Bounds.IntersectsWith($visibleText[$j].Bounds)) { $overlaps++ }
                            }
                        }
                        Assert-Lbs229 "LBS182 $locale/$scale flat grouped labels no overlap or clipping" ($bad.Count -eq 0 -and $overlaps -eq 0 -and $body.Controls['SystemStatusValue-Stored'].Font.Bold -and -not $body.Controls['SystemStatusHeading-Stored'].Font.Bold -and @($body.Controls | Where-Object Name -like 'SystemStatusDivider-*').Count -eq 3)
                    } finally { $form.Dispose() }
                }
            }
            $now=[datetime]::UtcNow
            $fresh=$now.AddSeconds(-5)
            $same=Get-SystemStatusObservationPresentation $fresh $fresh $fresh $now
            $mixed=Get-SystemStatusObservationPresentation $fresh $null $fresh.AddMinutes(-3) $now
            Assert-Lbs229 'LBS182 same-second observations share date and just-now age only once' ($same.Values.Count -eq 3 -and @($same.Values | Where-Object { $_ -ne $fresh.ToLocalTime().ToString('HH:mm:ss') }).Count -eq 0 -and $same.Shared.Contains((Get-LocalizedString -Key 'SystemStatus.JustNow')))
            Assert-Lbs229 'LBS182 independent/missing observations never share a timestamp' ($mixed.Values.Count -eq 3 -and -not $mixed.Shared -and $mixed.Values[1] -eq (Get-LocalizedString -Key 'SystemStatus.TimeUnknown') -and $mixed.Values[0].Contains((Get-LocalizedString -Key 'SystemStatus.JustNow')) -and $mixed.Values[2] -ne $mixed.Values[0])
            $script:Scale=1.0
            $script:Locale='de-DE'
            $script:Ready=$false
            $script:SystemStatusCapabilities=[pscustomobject]@{State='Checking'}
            $script:Lbs182OwnerProbe=$owner
            $script:Lbs182ModalSeen=$false
            $script:Lbs182ModalError=$null
            $timer=New-Object Windows.Forms.Timer
            $timer.Interval=50
            $timer.Add_Tick({
                param($sender,$eventArgs)
                $child=$script:ActiveAuxiliaryPopup
                if (-not $child -or -not $child.Visible -or -not $child.Tag.Timer.Enabled) { return }
                $sender.Stop()
                try {
                    Write-Host "LBS182 MODAL name=$($child.Name) focus=$($child.ContainsFocus) foreground=$([Lbs229Native]::GetForegroundWindow()) child=$($child.Handle) owner=$($script:Lbs182OwnerProbe.Handle) nativeOwner=$([Lbs229Native]::GetWindow($child.Handle,4)) ownerEnabled=$([Lbs229Native]::IsWindowEnabled($script:Lbs182OwnerProbe.Handle)) readiness=$($child.Tag.Body.Controls['SystemStatusValue-Readiness'].Text) expected=$(Get-LocalizedString -Key 'SystemStatus.Checking')"
                    Assert-Lbs229 'LBS182 actual native status modal owns focus and preserves disabled owner' ($child.Name -eq 'LenovoSystemStatusPopup' -and $child.ContainsFocus -and [Lbs229Native]::GetForegroundWindow() -eq $child.Handle -and [Lbs229Native]::GetWindow($child.Handle,4) -eq $script:Lbs182OwnerProbe.Handle -and -not [Lbs229Native]::IsWindowEnabled($script:Lbs182OwnerProbe.Handle) -and $child.Tag.Body.Controls['SystemStatusValue-Readiness'].Text -eq (Get-LocalizedString -Key 'SystemStatus.Checking'))
                    $script:Lbs182ModalSeen=$true
                } catch { $script:Lbs182ModalError=$_ }
                finally { $child.Tag.Close.PerformClick() }
            })
            try { $owner.Activate(); [void]$info.Focus(); $timer.Start(); $info.PerformClick() }
            finally { $timer.Stop();$timer.Dispose() }
            if ($script:Lbs182ModalError) { throw $script:Lbs182ModalError }
            Assert-Lbs229 'LBS182 modal close restores owner and no action dispatch' ($script:Lbs182ModalSeen -and $info.Focused -and [Lbs229Native]::IsWindowEnabled($owner.Handle) -and -not $script:ActiveAuxiliaryPopup -and @($owner.OwnedForms | Where-Object Name -in @('AuxiliaryOwnerDimmer','AuxiliaryOwnerClickShield')).Count -eq 0 -and $script:Actions.Count -eq $savedActions -and $script:BootCalls -eq $savedCalls -and $script:DefaultCalls.Count -eq $savedDefaultCalls)
            Write-Host "LBS182 STATUS TOTAL $($script:Checks-$startChecks)/34"
            if ($script:Checks-$startChecks -ne 34) { throw 'LBS182 status count mismatch' }
        } finally {
            $rootPanel.Dispose()
            $script:SystemStatusButton=$null
            $script:RefreshButton=$null
            $script:HeaderStatusLabel=$null
            $script:Locale=$savedLocale
            $script:Scale=$savedScale
            $script:DefaultGuid=$savedDefault
            $script:SelectedGuid=$savedSelected
            $script:Ready=$savedReady
            $script:NextBootFirmwareReadVerified=$false
            $script:BackgroundRefreshState=New-BackgroundRefreshRuntimeState
            [Windows.Forms.Cursor]::Position=$savedCursor
        }
    }
    if ($Lbs182StatusProbeOnly -or -not ($CorrectionProbeOnly -or $SettingsCorrectionProbeOnly -or $InitialFocusProbeOnly -or $FocusOutlineProbeOnly -or $DefaultInitialFocusProbeOnly)) { Test-Lbs182StatusOverview }
    if ($Lbs182StatusProbeOnly) { return }

    # F10: observe actual picker foreground and keyboard focus before any
    # child input. Controlled loss during Shown tests the opening recovery
    # contract separately from unperturbed owner-specific reproduction.
    function Test-Lbs229DefaultOpeningFocus {
        $rootPanel=New-Object Windows.Forms.Panel
        $rootPanel.Dock=[Windows.Forms.DockStyle]::Fill
        $owner.Controls.Add($rootPanel)
        $savedDefaultButton=$script:DefaultButton
        $savedDefaultValueLabel=$script:DefaultValueLabel
        $savedDefaultArrowLabel=$script:DefaultArrowLabel
        $savedLocale=$script:Locale
        $savedScale=$script:Scale
        $savedCalls=$script:DefaultCalls
        $savedCursor=[Windows.Forms.Cursor]::Position
        $errors=[Collections.Generic.List[string]]::new()
        $passed=0
        Add-PopupSettingsSection -Root $rootPanel
        $trigger=$rootPanel.Controls['DefaultPanel']
        try {
            foreach ($locale in @('de-DE','en-US')) {
                $script:Locale=$locale
                $script:Scale=if ($locale -eq 'de-DE') { 1.0 } else { 2.5 }
                foreach ($mode in @('natural','controlled')) {
                    $script:F10Error=$null
                    $script:F10Loss=$false
                    $script:F10Initial=$false
                    $script:F10Navigation=$false
                    $script:F10Escape=$false
                    $script:F10Raster=$false
                    [void]$trigger.Focus()
                    $form=$null
                    if ($mode -eq 'controlled') {
                        $form=New-DefaultTargetPicker
                        $form.Add_Shown({
                            [void][Lbs229Native]::SetFocus([IntPtr]::Zero)
                            $script:F10Loss=([Lbs229Native]::GetFocus() -eq [IntPtr]::Zero -and -not $this.ContainsFocus)
                        })
                    }
                    $timer=New-Object Windows.Forms.Timer
                    $timer.Interval=75
                    $timer.Add_Tick({
                        param($sender,$eventArgs)
                        $active=$script:ActiveAuxiliaryPopup
                        if (-not $active -or -not $active.Visible) { return }
                        $sender.Stop()
                        try {
                            $rows=@($active.Tag.Body.Controls | Where-Object Name -eq 'DefaultPickerRow' | Sort-Object Top)
                            $focus=[Lbs229Native]::GetFocus()
                            $foreground=[Lbs229Native]::GetForegroundWindow()
                            $script:F10Initial=($foreground -eq $active.Handle -and $active.Tag.Body.ContainsFocus -and $rows[0].Focused -and $focus -eq $rows[0].Handle)
                            Write-Host "LBS229 F10 initial locale=$script:Locale mode=$mode loss=$script:F10Loss foreground=$foreground child=$($active.Handle) focus=$focus first=$($rows[0].Handle) initial=$script:F10Initial"
                            if ($script:F10Initial) {
                                $row=$rows[0]
                                $row.Refresh()
                                [Windows.Forms.Application]::DoEvents()
                                $bm=[Drawing.Bitmap]::new($row.Width,$row.Height)
                                $g=[Drawing.Graphics]::FromImage($bm)
                                try {
                                    $g.CopyFromScreen($row.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$row.ClientSize)
                                    $ink=0
                                    for ($x=5;$x -lt $bm.Width-5;$x++) {
                                        $p=$bm.GetPixel($x,3)
                                        if ($p.R -ge 140 -and $p.G -ge 155 -and $p.B -ge 170) { $ink++ }
                                    }
                                    $script:F10Raster=$ink -ge 8
                                } finally { $g.Dispose(); $bm.Dispose() }
                                [Windows.Forms.SendKeys]::SendWait('{TAB}')
                                [Windows.Forms.Application]::DoEvents()
                                $tab=$rows[1].Focused
                                [Windows.Forms.SendKeys]::SendWait('+{TAB}')
                                [Windows.Forms.Application]::DoEvents()
                                $back=$rows[0].Focused
                                [Windows.Forms.SendKeys]::SendWait('{DOWN}')
                                [Windows.Forms.Application]::DoEvents()
                                $down=$rows[1].Focused
                                [Windows.Forms.SendKeys]::SendWait('{UP}')
                                [Windows.Forms.Application]::DoEvents()
                                $up=$rows[0].Focused
                                [Windows.Forms.SendKeys]::SendWait('{END}')
                                [Windows.Forms.Application]::DoEvents()
                                $end=$rows[-1].Focused -and $active.Tag.Scroll.Value -eq $active.Tag.Scroll.Maximum
                                [Windows.Forms.SendKeys]::SendWait('{HOME}')
                                [Windows.Forms.Application]::DoEvents()
                                $homeReached=$rows[0].Focused -and $active.Tag.Scroll.Value -eq 0
                                $script:F10Navigation=$tab -and $back -and $down -and $up -and $end -and $homeReached
                                [Windows.Forms.SendKeys]::SendWait('{ESC}')
                                [Windows.Forms.Application]::DoEvents()
                                $script:F10Escape=($active.DialogResult -eq [Windows.Forms.DialogResult]::Cancel -or -not $active.Visible)
                                Write-Host "LBS229 F10 keys tab=$tab shiftTab=$back down=$down up=$up end=$end home=$homeReached escape=$script:F10Escape raster=$script:F10Raster"
                            }
                        } catch { $script:F10Error=$_ }
                        finally {
                            if (-not $active.IsDisposed -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None) { $active.DialogResult=[Windows.Forms.DialogResult]::Cancel }
                        }
                    })
                    try {
                        $timer.Start()
                        if ($mode -eq 'natural') { Show-DefaultTargetMenu -Owner $trigger }
                        else { [void](Show-OwnedAuxiliaryPopup -Form $form -Owner $trigger) }
                    } finally { $timer.Stop(); $timer.Dispose() }
                    if ($script:F10Error) { throw $script:F10Error }
                    if ($mode -eq 'controlled' -and -not $script:F10Loss) { throw 'F10 fixture failed to establish controlled Shown focus loss' }
                    $restored=$owner.ContainsFocus -and $trigger.Focused -and -not $script:ActiveAuxiliaryPopup
                    Write-Host "LBS229 F10 lifecycle locale=$locale mode=$mode ownerRestored=$restored"
                    if ($script:DefaultCalls.Count -ne $savedCalls.Count -or $script:BootCalls -ne 0) { throw 'F10 navigation unexpectedly dispatched a target action' }
                    if ($script:F10Initial -and $script:F10Navigation -and $script:F10Escape -and $script:F10Raster -and $restored) {
                        $passed++
                        Assert-Lbs229 "F10 $locale $mode opening focus and actual keyboard lifecycle" $true
                    } else { $errors.Add("$locale $mode") }
                }
            }
        } finally {
            $rootPanel.Dispose()
            $script:DefaultButton=$savedDefaultButton
            $script:DefaultValueLabel=$savedDefaultValueLabel
            $script:DefaultArrowLabel=$savedDefaultArrowLabel
            $script:Locale=$savedLocale
            $script:Scale=$savedScale
            [Windows.Forms.Cursor]::Position=$savedCursor
        }
        Write-Host "LBS229 F10 TOTAL $passed/4"
        if ($errors.Count) { throw ('LBS229 F10 RED: '+($errors -join '; ')) }
    }
    if ($DefaultInitialFocusProbeOnly -or (-not $CorrectionProbeOnly -and -not $SettingsCorrectionProbeOnly -and -not $InitialFocusProbeOnly -and -not $FocusOutlineProbeOnly)) {
        Test-Lbs229DefaultOpeningFocus
        if ($DefaultInitialFocusProbeOnly) { return }
    }
    # LBS247 correction: independent defect-specific raster observations, on
    # real production controls. Baseline probe deliberately fails both findings.
    $settingsFailures=[Collections.Generic.List[string]]::new()
    function Observe-Lbs247Correction([string]$Name,[scriptblock]$Test) {
        try { & $Test; Assert-Lbs247 $Name $true }
        catch { $settingsFailures.Add("$Name : $_"); Write-Host "RED LBS247 $Name : $_" }
    }
    function Move-Lbs247Pointer($Control,[int]$X,[int]$Y) {
        [Windows.Forms.Cursor]::Position=$Control.PointToScreen([Drawing.Point]::new($X,$Y))
        $sw=[Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 120) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
    }
    function Get-Lbs247Background($Control) {
        $bm=[Drawing.Bitmap]::new($Control.Width,$Control.Height)
        try {
            $Control.DrawToBitmap($bm,$Control.ClientRectangle)
            return $bm.GetPixel(1,1).ToArgb()
        } finally { $bm.Dispose() }
    }
    # F04 / LBS-260: keep real screen evidence separate from the outline
    # predicate. Never interpret an invalid frame as a valid absence.
    function Resolve-Lbs260Raster([scriptblock]$Acquire,[bool]$ExpectedOutline,[scriptblock]$BetweenInvalid={
        Start-Sleep -Milliseconds 25
        [Windows.Forms.Application]::DoEvents()
    }) {
        for ($attempt=1; $attempt -le 5; $attempt++) {
            $frame=& $Acquire $attempt
            if ($null -eq $frame -or $frame.Valid -isnot [bool] -or $frame.Present -isnot [bool]) { throw 'LBS260 malformed raster evidence' }
            if ($frame.Valid) {
                if ($frame.Present -ne $ExpectedOutline) { throw "LBS260 VALID OUTLINE MISMATCH expected=$ExpectedOutline actual=$($frame.Present) attempt=$attempt" }
                return $true
            }
            Write-Host "LBS260 INVALID ACQUISITION attempt=$attempt reason=$($frame.Reason)"
            if ($attempt -lt 5) { & $BetweenInvalid }
        }
        throw 'LBS260 INVALID SCREEN FRAME after 5 acquisitions; no valid outline evidence'
    }
    function Get-Lbs260ScreenFrame($Control,[IntPtr]$ExpectedFocus,[IntPtr]$ExpectedForm,[Drawing.Rectangle]$ExpectedBounds,[bool]$ExpectedFocused,[int]$Attempt) {
        $foregroundBefore=[Lbs229Native]::GetForegroundWindow()
        $focusBefore=[Lbs229Native]::GetFocus()
        $bounds=$Control.RectangleToScreen($Control.ClientRectangle)
        if (-not $Control.Visible -or -not $Control.Enabled -or $foregroundBefore -ne $ExpectedForm -or $focusBefore -ne $ExpectedFocus -or $Control.Focused -ne $ExpectedFocused -or $bounds -ne $ExpectedBounds) {
            throw "LBS260 NATIVE STATE CHANGED before capture foreground=$foregroundBefore expectedForm=$ExpectedForm focus=$focusBefore expectedFocus=$ExpectedFocus bounds=$bounds expectedBounds=$ExpectedBounds focused=$($Control.Focused)"
        }
        $bm=[Drawing.Bitmap]::new($Control.ClientSize.Width,$Control.ClientSize.Height)
        $g=[Drawing.Graphics]::FromImage($bm)
        $cg=$Control.CreateGraphics()
        try {
            $p=[LenovoSettingsInk]::Px($cg.DpiX,3)
            $x0=$p; $y0=$p; $x1=$bm.Width-$p-1; $y1=$bm.Height-$p-1
            if ($x1-$x0 -lt 5 -or $y1-$y0 -lt 5) { throw 'LBS260 insufficient screen geometry for unchanged perimeter threshold' }
            $points=@([Drawing.Point]::new(1,1),[Drawing.Point]::new($bm.Width-2,1),[Drawing.Point]::new(1,$bm.Height-2),[Drawing.Point]::new($bm.Width-2,$bm.Height-2),[Drawing.Point]::new([int]($bm.Width/2),[int]($bm.Height/2)))
            $hitsBefore=@(foreach ($point in $points) { [Lbs229Native]::Hit(($bounds.X+$point.X),($bounds.Y+$point.Y)) })
            $g.CopyFromScreen($bounds.Location,[Drawing.Point]::Empty,$Control.ClientSize)
            $hitsAfter=@(foreach ($point in $points) { [Lbs229Native]::Hit(($bounds.X+$point.X),($bounds.Y+$point.Y)) })
            $foregroundAfter=[Lbs229Native]::GetForegroundWindow()
            $focusAfter=[Lbs229Native]::GetFocus()
            $boundsAfter=$Control.RectangleToScreen($Control.ClientRectangle)
            if ($foregroundAfter -ne $ExpectedForm -or $focusAfter -ne $ExpectedFocus -or $Control.Focused -ne $ExpectedFocused -or $boundsAfter -ne $ExpectedBounds -or -not $Control.Visible -or -not $Control.Enabled) {
                throw "LBS260 NATIVE STATE CHANGED during capture foreground=$foregroundBefore/$foregroundAfter focus=$focusBefore/$focusAfter bounds=$bounds/$boundsAfter"
            }
            $expectedColors=if ([Windows.Forms.SystemInformation]::HighContrast) { @([Drawing.SystemColors]::Control.ToArgb()) } else { @($Control.BackColor.ToArgb(),$Control.HoverSurface.ToArgb()) }
            $corners=@(foreach ($point in $points[0..3]) { $bm.GetPixel($point.X,$point.Y).ToArgb() })
            $bg=$corners[0]
            $surfaceValid=($bg -in $expectedColors) -and (@($corners | Where-Object { $_ -ne $bg }).Count -eq 0)
            $hitValid=@(($hitsBefore+$hitsAfter) | Where-Object { $_ -ne $Control.Handle }).Count -eq 0
            $top=0;$bottom=0;$left=0;$right=0
            for ($x=$x0+1;$x -lt $x1;$x++) {
                if ($bm.GetPixel($x,$y0).ToArgb() -ne $bg) { $top++ }
                if ($bm.GetPixel($x,$y1).ToArgb() -ne $bg) { $bottom++ }
            }
            for ($y=$y0+1;$y -lt $y1;$y++) {
                if ($bm.GetPixel($x0,$y).ToArgb() -ne $bg) { $left++ }
                if ($bm.GetPixel($x1,$y).ToArgb() -ne $bg) { $right++ }
            }
            $present=$top -ge 4 -and $bottom -ge 4 -and $left -ge 4 -and $right -ge 4
            $valid=$surfaceValid -and $hitValid
            Write-Host "LBS247 F04 SCREEN attempt=$Attempt checked=$($Control.Checked) focus=$($Control.Focused) focusHandles=$focusBefore/$focusAfter foreground=$foregroundBefore/$foregroundAfter form=$ExpectedForm target=$($Control.Handle) bounds=$bounds dpi=$($cg.DpiX) expected=$($expectedColors -join ',') bg=$bg corners=$($corners -join ',') hitsBefore=$($hitsBefore -join ',') hitsAfter=$($hitsAfter -join ',') hitValid=$hitValid surfaceValid=$surfaceValid valid=$valid perimeter=$top,$bottom,$left,$right result=$present"
            return [pscustomobject]@{Valid=$valid;Present=$present;Reason="surface=$surfaceValid hit=$hitValid bg=$bg expected=$($expectedColors -join ',')"}
        } finally {
            $cg.Dispose()
            $g.Dispose()
            $bm.Dispose()
        }
    }
    function Test-Lbs247FocusRaster($Control,[bool]$ExpectedOutline=$true) {
        $form=$Control.FindForm()
        $expectedFocus=[Lbs229Native]::GetFocus()
        $bounds=$Control.RectangleToScreen($Control.ClientRectangle)
        if ($null -eq $form -or $Control.Focused -ne $ExpectedOutline -or $expectedFocus -eq [IntPtr]::Zero -or (($expectedFocus -eq $Control.Handle) -ne $ExpectedOutline) -or -not $form.ContainsFocus) {
            throw 'LBS260 unexpected native focus before raster assertion'
        }
        $expectedForm=$form.Handle
        $Control.Refresh()
        [Windows.Forms.Application]::DoEvents()
        return (Resolve-Lbs260Raster -ExpectedOutline $ExpectedOutline -Acquire {
            param($attempt)
            Get-Lbs260ScreenFrame $Control $expectedFocus $expectedForm $bounds $ExpectedOutline $attempt
        })
    }
    # Exercise the exact production-test decision loop independently with
    # deterministic observations. These never substitute for CopyFromScreen.
    function Test-Lbs260AcquisitionPolicy {
        $invalid=[pscustomobject]@{Valid=$false;Present=$false;Reason='controlled wrong-surface observation'}
        $absent=[pscustomobject]@{Valid=$true;Present=$false;Reason='valid absent'}
        $present=[pscustomobject]@{Valid=$true;Present=$true;Reason='valid present'}
        $cases=@(
            @{Name='valid missing outline fails immediately';Frames=@($absent,$present);Expected=$true;Calls=1;Error='LBS260 VALID OUTLINE MISMATCH*'},
            @{Name='valid unexpected outline fails immediately';Frames=@($present,$absent);Expected=$false;Calls=1;Error='LBS260 VALID OUTLINE MISMATCH*'},
            @{Name='invalid frame then valid outline succeeds';Frames=@($invalid,$present);Expected=$true;Calls=2;Error=$null},
            @{Name='invalid frame then valid missing outline fails without further retry';Frames=@($invalid,$absent,$present);Expected=$true;Calls=2;Error='LBS260 VALID OUTLINE MISMATCH*'},
            @{Name='invalid frame cannot satisfy expected absence';Frames=@($invalid,$invalid,$invalid,$invalid,$invalid);Expected=$false;Calls=5;Error='LBS260 INVALID SCREEN FRAME*'}
        )
        foreach ($case in $cases) {
            $state=@{Calls=0;Waits=0}
            $failure=$null
            $matched=$false
            try {
                $matched=Resolve-Lbs260Raster -ExpectedOutline $case.Expected -Acquire {
                    param($attempt)
                    $state.Calls++
                    if ($attempt -gt $case.Frames.Count) { throw 'LBS260 acquisition exceeded fixture observations' }
                    $case.Frames[$attempt-1]
                } -BetweenInvalid { $state.Waits++ }
            } catch { $failure=$_.Exception.Message }
            $expectedResult=if ($null -eq $case.Error) { $matched -and $null -eq $failure } else { $failure -like $case.Error -and -not $matched }
            Assert-Lbs247 ("LBS260 "+$case.Name) ($expectedResult -and $state.Calls -eq $case.Calls -and $state.Waits -eq ($case.Calls-1))
        }
    }
    # LBS-260 negative control: an actual visible wrong surface over the
    # focused switch must never be interpreted as a valid absent outline.
    function Test-Lbs260OccludedScreen($Control) {
        $cover=New-Object Windows.Forms.Panel
        $cover.BackColor=[Drawing.Color]::FromArgb(133,133,133)
        $cover.Bounds=$Control.Bounds
        $cover.TabStop=$false
        $parent=$Control.Parent
        $focus=[Lbs229Native]::GetFocus()
        $foreground=[Lbs229Native]::GetForegroundWindow()
        try {
            $parent.Controls.Add($cover)
            $cover.BringToFront()
            $cover.Refresh()
            [Windows.Forms.Application]::DoEvents()
            $bm=[Drawing.Bitmap]::new($Control.ClientSize.Width,$Control.ClientSize.Height)
            $g=[Drawing.Graphics]::FromImage($bm)
            try {
                $g.CopyFromScreen($Control.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$Control.ClientSize)
                $bg=$bm.GetPixel(1,1).ToArgb()
                $far=$bm.GetPixel($bm.Width-2,$bm.Height-2).ToArgb()
                Write-Host "LBS260 NEGATIVE CONTROL foreground=$foreground focus=$focus switch=$($Control.Handle) cover=$($cover.Handle) bounds=$($Control.RectangleToScreen($Control.ClientRectangle)) bg=$bg far=$far"
                if ($bg -ne $cover.BackColor.ToArgb() -or $far -ne $bg -or [Lbs229Native]::GetFocus() -ne $focus -or [Lbs229Native]::GetForegroundWindow() -ne $foreground -or -not $Control.Focused) { throw 'LBS260 negative-control fixture did not establish visible occlusion with retained focus' }
            } finally { $g.Dispose(); $bm.Dispose() }
            $invalid=$false
            try { $present=Test-Lbs247FocusRaster $Control }
            catch {
                if ($_.Exception.Message -notlike 'LBS260 INVALID SCREEN FRAME*') { throw }
                $invalid=$true
            }
            if (-not $invalid) { throw "LBS260 RED: wrong-surface raster returned ordinary outline result=$present instead of invalid-frame failure" }
            Assert-Lbs247 'LBS260 actual occlusion is rejected rather than interpreted as an absent outline' $true
        } finally {
            $cover.Dispose()
            $Control.Refresh()
            [Windows.Forms.Application]::DoEvents()
        }
        if ([Lbs229Native]::GetFocus() -ne $focus -or [Lbs229Native]::GetForegroundWindow() -ne $foreground) { throw 'LBS260 negative-control cleanup changed native focus/foreground' }
    }
    # F03: use the actual owned modal route, including the navigation trigger
    # and connector. Observe natural initial focus before any input. A second,
    # explicitly controlled focusless phase isolates the reported hover dependency.
    if (-not $SettingsCorrectionProbeOnly) {
        $f03Errors=[Collections.Generic.List[string]]::new()
        $f04Errors=[Collections.Generic.List[string]]::new()
        $f03Root=New-Object Windows.Forms.Panel
        $f03Root.Dock=[Windows.Forms.DockStyle]::Fill
        $savedDefaultButton=$script:DefaultButton
        $savedDefaultValueLabel=$script:DefaultValueLabel
        $savedDefaultArrowLabel=$script:DefaultArrowLabel
        $savedCursor=[Windows.Forms.Cursor]::Position
        $savedCheck=$script:AutostartMenuItem.Checked
        $actionCount=$script:Actions.Count
        $owner.Controls.Add($f03Root)
        Add-PopupSettingsSection -Root $f03Root
        $trigger=$f03Root.Controls['SettingsPanel']
        try {
            foreach ($checkedState in @($false,$true)) {
                $script:AutostartMenuItem.Checked=$checkedState
                $script:F03State=$checkedState
                $script:F03Error=$null
                $script:F03Initial=$false
                $script:F03Pointer=$false
                $script:F03Controlled=$false
                $script:F03Escape=$false
                $script:F04Natural=$false
                $script:F04Controlled=$false
                $script:F04LossReturn=$false
                # Establish focus only on the invoking OWNER, never on the child.
                [void]$trigger.Focus()
                $timer=New-Object Windows.Forms.Timer
                $timer.Interval=75
                $timer.Add_Tick({
                    param($sender,$eventArgs)
                    $active=$script:ActiveAuxiliaryPopup
                    if (-not $active -or -not $active.Visible) { return }
                    $sender.Stop()
                    try {
                        $label=$active.Tag.Body.Controls['ConfigurationLocale-Settings.Autostart']
                        $toggle=$active.Tag.Body.Controls['ConfigurationAutostart']
                        $hot=$label.HoverSurface.ToArgb()
                        $normal=$label.BackColor.ToArgb()
                        $focusBefore=[Lbs229Native]::GetFocus()
                        $foreground=[Lbs229Native]::GetForegroundWindow()
                        $initial=$foreground -eq $active.Handle -and $active.ContainsFocus -and $active.Tag.Body.ContainsFocus -and -not $active.Tag.Close.Focused
                        Write-Host "LBS247 F03 initial checked=$script:F03State foreground=$foreground child=$($active.Handle) focus=$focusBefore body=$($active.Tag.Body.ContainsFocus)"
                        if (-not $InitialFocusProbeOnly) {
                            # Capture before any pointer move, click or key in the child.
                            $naturalCue=[Lbs229Native]::SendMessage($toggle.Handle,0x129,[IntPtr]::Zero,[IntPtr]::Zero).ToInt64()
                            $script:F04Natural=$initial -and $toggle.Focused -and $focusBefore -eq $toggle.Handle -and (Test-Lbs247FocusRaster $toggle)
                            # Reproduce mouse-mode cue suppression explicitly, without
                            # moving native keyboard focus or executing an action.
                            [void][Lbs229Native]::SendMessage($active.Handle,0x127,[IntPtr]0x10001,[IntPtr]::Zero)
                            [void][Lbs229Native]::SendMessage($toggle.Handle,0x128,[IntPtr]0x10001,[IntPtr]::Zero)
                            $toggle.Refresh()
                            $hidden=([Lbs229Native]::SendMessage($toggle.Handle,0x129,[IntPtr]::Zero,[IntPtr]::Zero).ToInt64() -band 1) -ne 0
                            $script:F04Controlled=$hidden -and $toggle.Focused -and (Test-Lbs247FocusRaster $toggle)
                            Write-Host "LBS247 F04 INITIAL checked=$script:F03State focus=$($toggle.Focused) naturalCue=$naturalCue naturalRaster=$script:F04Natural forcedHidden=$hidden forcedRaster=$script:F04Controlled"
                        }
                        $pointerOk=$true
                        foreach ($step in @(@{C=$active.Tag.Title;X=5;Y=5;Hot=$false},@{C=$label;X=10;Y=20;Hot=$true},@{C=$toggle;X=10;Y=20;Hot=$true},@{C=$active.Tag.Title;X=5;Y=5;Hot=$false})) {
                            Move-Lbs247Pointer $step.C $step.X $step.Y
                            $expect=if ($step.Hot) { $hot } else { $normal }
                            if ((Get-Lbs247Background $label) -ne $expect -or (Get-Lbs247Background $toggle) -ne $expect) { $pointerOk=$false }
                        }
                        $script:F03Pointer=$pointerOk
                        if ($initial) {
                            [Windows.Forms.SendKeys]::SendWait('{TAB}')
                            [Windows.Forms.Application]::DoEvents()
                            $next=[Lbs229Native]::GetFocus()
                            $lostRaster=if (-not $InitialFocusProbeOnly) { Test-Lbs247FocusRaster $toggle -ExpectedOutline $false } else { $true }
                            [Windows.Forms.SendKeys]::SendWait('+{TAB}')
                            [Windows.Forms.Application]::DoEvents()
                            $back=[Lbs229Native]::GetFocus()
                            if (-not $InitialFocusProbeOnly) {
                                $script:F04LossReturn=$lostRaster -and $next -eq $active.Tag.Body.Controls['ConfigurationAction-language-de'].Handle -and $back -eq $toggle.Handle -and (Test-Lbs247FocusRaster $toggle)
                                Write-Host "LBS247 F04 TRAVERSAL checked=$script:F03State lostRaster=$lostRaster returned=$script:F04LossReturn"
                            }
                            $script:F03Initial=$next -ne [IntPtr]::Zero -and $next -ne $focusBefore -and $back -eq $focusBefore -and $active.ContainsFocus
                        }
                        if (-not $InitialFocusProbeOnly -and $script:F03State -and $script:F04LossReturn) { Test-Lbs260OccludedScreen $toggle }
                        # Explicitly separate a controlled focus loss from the
                        # natural opening observation. No click or action dispatch.
                        [void][Lbs229Native]::SetFocus([IntPtr]::Zero)
                        $focusless=(-not $active.ContainsFocus -and [Lbs229Native]::GetFocus() -eq [IntPtr]::Zero)
                        Move-Lbs247Pointer $label 10 20
                        $lp=Get-Lbs247Background $label
                        $tp=Get-Lbs247Background $toggle
                        $script:F03Controlled=$focusless -and -not $active.ContainsFocus -and $lp -eq $hot -and $tp -eq $hot
                        Write-Host "LBS247 F03 controlled checked=$script:F03State focusless=$focusless focusAfter=$([Lbs229Native]::GetFocus()) label=$lp switch=$tp expected=$hot result=$script:F03Controlled"
                        # Restore deliberately perturbed focus solely for the
                        # Escape test; this is not used to satisfy initial focus.
                        if ($initial) {
                            [void][Lbs229Native]::SetFocus($focusBefore)
                            [Windows.Forms.SendKeys]::SendWait('{ESC}')
                            [Windows.Forms.Application]::DoEvents()
                            $script:F03Escape=($active.DialogResult -eq [Windows.Forms.DialogResult]::Cancel -or -not $active.Visible)
                        }
                    } catch { $script:F03Error=$_ }
                    finally {
                        if (-not $active.IsDisposed -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None) { $active.DialogResult=[Windows.Forms.DialogResult]::Cancel }
                    }
                })
                try { $timer.Start(); Show-ConfigurationPopup -Owner $trigger }
                finally { $timer.Stop(); $timer.Dispose() }
                if ($script:F03Error) { throw $script:F03Error }
                $restored=$owner.ContainsFocus -and $trigger.Focused -and -not $script:ActiveAuxiliaryPopup
                Write-Host "LBS247 F03 lifecycle checked=$checkedState initialTab=$script:F03Initial pointer=$script:F03Pointer escape=$script:F03Escape ownerRestored=$restored"
                if ($script:F03Initial -and $script:F03Pointer -and $script:F03Escape -and $restored) { Assert-Lbs247 "F03 unforced modal opening, Tab/Shift+Tab, hover, Escape and owner restoration ($checkedState)" $true }
                else { $f03Errors.Add("Natural modal lifecycle ($checkedState)") }
                if ($script:F03Controlled) { Assert-Lbs247 "F03 actual pointer hover without keyboard focus ($checkedState)" $true }
                else { $f03Errors.Add("Controlled focusless hover ($checkedState)") }
                if ($script:Actions.Count -ne $actionCount -or $script:AutostartMenuItem.Checked -ne $checkedState) { throw 'F03 unexpectedly dispatched an action' }
                if (-not $InitialFocusProbeOnly) {
                    if ($script:F04Natural -and $script:F04LossReturn) { Assert-Lbs247 "F04 initial and traversal focus outline ($checkedState)" $true }
                    else { $f04Errors.Add("Initial/traversal outline ($checkedState)") }
                    if ($script:F04Controlled) { Assert-Lbs247 "F04 focused outline under native hidden focus cues ($checkedState)" $true }
                    else { $f04Errors.Add("Hidden cue suppresses focused outline ($checkedState)") }
                }
            }
            # Controlled loss DURING Shown, before the product's final opening
            # callback. Distinct from the unperturbed real-opening tests above.
            $script:F03OpeningLossObserved=$false
            $script:F03OpeningRecovered=$false
            $script:F03OpeningError=$null
            $script:AutostartMenuItem.Checked=$savedCheck
            [void]$trigger.Focus()
            $form=New-ConfigurationPopup
            $form.Add_Shown({
                [void][Lbs229Native]::SetFocus([IntPtr]::Zero)
                $script:F03OpeningLossObserved=([Lbs229Native]::GetFocus() -eq [IntPtr]::Zero -and -not $this.ContainsFocus)
            })
            $timer=New-Object Windows.Forms.Timer
            $timer.Interval=75
            $timer.Add_Tick({
                param($sender,$eventArgs)
                $active=$script:ActiveAuxiliaryPopup
                if (-not $active -or -not $active.Visible) { return }
                $sender.Stop()
                try {
                    $script:F03OpeningRecovered=$script:F03OpeningLossObserved -and [Lbs229Native]::GetForegroundWindow() -eq $active.Handle -and $active.Tag.Body.ContainsFocus -and -not $active.Tag.Close.Focused
                    Write-Host "LBS247 F03 opening perturbation observed=$script:F03OpeningLossObserved recovered=$script:F03OpeningRecovered focus=$([Lbs229Native]::GetFocus())"
                } catch { $script:F03OpeningError=$_ }
                finally { $active.DialogResult=[Windows.Forms.DialogResult]::Cancel }
            })
            try { $timer.Start(); [void](Show-OwnedAuxiliaryPopup -Form $form -Owner $trigger) }
            finally { $timer.Stop(); $timer.Dispose() }
            if ($script:F03OpeningError) { throw $script:F03OpeningError }
            if ($script:F03OpeningRecovered -and $owner.ContainsFocus -and $trigger.Focused -and $script:Actions.Count -eq $actionCount) {
                Assert-Lbs247 'F03 controlled focus loss during modal opening is recovered before first input' $true
            } else { $f03Errors.Add('Controlled opening focus loss recovery') }
        } finally {
            $script:AutostartMenuItem.Checked=$savedCheck
            $f03Root.Dispose()
            $script:DefaultButton=$savedDefaultButton
            $script:DefaultValueLabel=$savedDefaultValueLabel
            $script:DefaultArrowLabel=$savedDefaultArrowLabel
            [Windows.Forms.Cursor]::Position=$savedCursor
        }
        if ($f03Errors.Count) { throw ('LBS247 F03 RED: '+($f03Errors -join '; ')) }
        if ($f04Errors.Count) { throw ('LBS247 F04 RED: '+($f04Errors -join '; ')) }
        if (-not $InitialFocusProbeOnly) { Test-Lbs260AcquisitionPolicy; Write-Host 'LBS260 RASTER VALIDITY TOTAL 6/6' }
        if ($FocusOutlineProbeOnly) {
            if ($script:Lbs247Checks -ne 15) { throw 'Unexpected F04/LBS260 fixture total' }
            Write-Host "LBS247 F04 TOTAL 4/4"
            return
        }
        if ($InitialFocusProbeOnly) {
            if ($script:Lbs247Checks -ne 5) { throw 'Unexpected F03 test count' }
            Write-Host "LBS247 F03 TOTAL $script:Lbs247Checks/5"
            return
        }
    }
    Observe-Lbs247Correction 'F01 actual pointer transitions highlight both autostart surfaces without mutation' {
        $popup=New-ConfigurationPopup
        $cursor=[Windows.Forms.Cursor]::Position
        $before=$script:Actions.Count
        $checked=$script:AutostartMenuItem.Checked
        try {
            $popup.StartPosition=[Windows.Forms.FormStartPosition]::Manual
            $popup.Location=[Drawing.Point]::new(30,30)
            $popup.Show($owner)
            $popup.Activate()
            [Windows.Forms.Application]::DoEvents()
            $label=$popup.Tag.Body.Controls['ConfigurationLocale-Settings.Autostart']
            $toggle=$popup.Tag.Body.Controls['ConfigurationAutostart']
            $normal=$label.BackColor.ToArgb()
            $hot=$label.HoverSurface.ToArgb()
            $ok=$true
            foreach ($step in @(
                @{ Control=$popup.Tag.Title; X=5; Y=5; Hot=$false; Name='outside' },
                @{ Control=$label; X=10; Y=20; Hot=$true; Name='label' },
                @{ Control=$toggle; X=10; Y=20; Hot=$true; Name='switch' },
                @{ Control=$label; X=($label.Width-4); Y=20; Hot=$true; Name='return label' },
                @{ Control=$popup.Tag.Title; X=5; Y=5; Hot=$false; Name='leave tile' }
            )) {
                Move-Lbs247Pointer $step.Control $step.X $step.Y
                $expect=if ($step.Hot) { $hot } else { $normal }
                $lp=Get-Lbs247Background $label
                $tp=Get-Lbs247Background $toggle
                $match=$lp -eq $expect -and $tp -eq $expect
                Write-Host "LBS247 TILE HOVER $($step.Name) label=$lp switch=$tp expected=$expect result=$match"
                if (-not $match) { $ok=$false }
            }
            $script:Busy=$true
            Update-ConfigurationPopupPresentation $popup
            Move-Lbs247Pointer $label 10 20
            $disabled=(-not $label.Enabled -and -not $toggle.Enabled -and (Get-Lbs247Background $label) -eq $normal -and (Get-Lbs247Background $toggle) -eq $normal)
            Write-Host "LBS247 TILE HOVER disabled result=$disabled"
            if (-not ($ok -and $disabled -and $script:Actions.Count -eq $before -and $script:AutostartMenuItem.Checked -eq $checked)) { throw 'Autostart split hover, disabled paint or mutation mismatch' }
        } finally {
            $script:Busy=$false
            $popup.Dispose()
            [Windows.Forms.Cursor]::Position=$cursor
            [Windows.Forms.Application]::DoEvents()
        }
    }
    $probeLocale=$script:Locale
    $probeInstall=$script:UpdateInstallMenuItem.Enabled
    $operationKeys=[ordered]@{
        TaskBrokerSetupMenuItem='Maintenance.Menu.Repair'; TaskBrokerRemoveMenuItem='Maintenance.Remove'
        UpdateCheckMenuItem='Update.Check'; UpdateInstallMenuItem='Update.Install'
        RuntimeDiagnosticMenuItem='Diagnostics.Save'; DiagnosticsUploadMenuItem='Diagnostics.Upload'
    }
    $oldTexts=@{}
    foreach ($var in $operationKeys.Keys) { $oldTexts[$var]=(Get-Variable -Scope Script -Name $var -ValueOnly).Text }
    try {
        foreach ($probeLanguage in @('en-US','de-DE')) {
            $script:Locale=$probeLanguage
            foreach ($var in $operationKeys.Keys) { (Get-Variable -Scope Script -Name $var -ValueOnly).Text=Get-LocalizedString -Key $operationKeys[$var] }
            foreach ($probeScale in @(1.0,2.5)) {
                Observe-Lbs247Correction "F02 $probeLanguage/$probeScale operation row raster has no chevron" {
                    $popup=New-ConfigurationPopup
                    try {
                        Set-AuxiliaryPopupLayout $popup $probeScale $area $anchor
                        $ok=$true
                        foreach ($available in @($false,$true)) {
                            $script:UpdateInstallMenuItem.Enabled=$available
                            Update-ConfigurationPopupPresentation $popup
                            foreach ($row in @($popup.Tag.Body.Controls | Where-Object { $_ -is [LenovoSettingsActionButton] -and -not $_.LocaleCode })) {
                                $bm=[Drawing.Bitmap]::new($row.Width,$row.Height)
                                $bm.SetResolution([single](96*$probeScale),[single](96*$probeScale))
                                $g=[Drawing.Graphics]::FromImage($bm)
                                $paint=[Windows.Forms.PaintEventArgs]::new($g,$row.ClientRectangle)
                                try {
                                    $method=$row.GetType().GetMethod('OnPaint',[Reflection.BindingFlags]'Instance,NonPublic')
                                    [void]$method.Invoke($row,@($paint))
                                    $bg=$bm.GetPixel(1,1).ToArgb()
                                    $ink=0
                                    $left=$row.Width-[LenovoSettingsInk]::Px([single](96*$probeScale),22)
                                    $right=$row.Width-[LenovoSettingsInk]::Px([single](96*$probeScale),10)
                                    $mid=[int][Math]::Floor($row.Height/2)
                                    $half=[LenovoSettingsInk]::Px([single](96*$probeScale),6)
                                    for ($y=$mid-$half;$y -le $mid+$half;$y++) {
                                        for ($x=$left;$x -le $right;$x++) { if ($bm.GetPixel($x,$y).ToArgb() -ne $bg) { $ink++ } }
                                    }
                                    Write-Host "LBS247 ROW RASTER $probeLanguage/$probeScale $($row.Tag) enabled=$($row.Enabled) chevronZoneInk=$ink"
                                    if ($ink -ne 0) { $ok=$false }
                                } finally { $paint.Dispose(); $g.Dispose(); $bm.Dispose() }
                            }
                        }
                        $rows=@($popup.Tag.Body.Controls | Where-Object { $_ -is [LenovoSettingsActionButton] -and -not $_.LocaleCode })
                        if ($rows.Count -ne 8) { throw "Expected eight operation rows, got $($rows.Count)" }
                        if (-not $ok) { throw 'Operation row chevron zone contains navigation ink' }
                    } finally { $popup.Dispose() }
                }
            }
        }
    } finally {
        $script:Locale=$probeLocale
        $script:UpdateInstallMenuItem.Enabled=$probeInstall
        foreach ($var in $oldTexts.Keys) { (Get-Variable -Scope Script -Name $var -ValueOnly).Text=$oldTexts[$var] }
    }
    if ($settingsFailures.Count) { throw ('LBS247 CORRECTION RED: '+($settingsFailures -join '; ')) }
    if ($SettingsCorrectionProbeOnly) {
        Write-Host "LBS247 CORRECTION TOTAL $script:Lbs247Checks/5"
        if ($script:Lbs247Checks -ne 5) { throw 'Unexpected correction count' }
        return
    }

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
        Require-Lbs229Correction ($p.X -eq -398 -and $p.Y -eq 400) "Expected left side at trigger Y=400, got $p"
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
    # F07/F08: exercise real native glyph events and both modal lifetimes.
    $secondFailures = [Collections.Generic.List[string]]::new()
    function Test-Lbs229SecondCorrection([string]$Name,[scriptblock]$Action) {
        try { & $Action; Write-Host "PASS LBS229 second correction $Name" }
        catch { $secondFailures.Add("$Name : $_"); Write-Host "RED LBS229 second correction $Name : $_" }
    }
    function Invoke-Lbs229MouseEvent($Control,[string]$Method) {
        $flags = [Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        [void]$Control.GetType().GetMethod($Method,$flags).Invoke($Control,@([EventArgs]::Empty))
    }
    function Test-Lbs229Above([IntPtr]$Upper,[IntPtr]$Lower) {
        # GW_HWNDPREV walks toward the top of native z-order.
        $h = $Lower
        for ($i=0; $i -lt 512; $i++) {
            $h = [Lbs229Native]::GetWindow($h,3)
            if ($h -eq [IntPtr]::Zero) { return $false }
            if ($h -eq $Upper) { return $true }
        }
        return $false
    }
    foreach ($kind in @('configuration','default')) {
        $surface = if ($kind -eq 'configuration') { New-ConfigurationPopup } else { New-DefaultTargetPicker }
        try {
            Test-Lbs229SecondCorrection "F07 $kind close glyph hover" {
                $close = $surface.Tag.Close
                $idle = $close.ForeColor
                Invoke-Lbs229MouseEvent $close 'OnMouseEnter'
                Require-Lbs229Correction ($close.ForeColor -eq $script:ColorAccent -and $close.FlatAppearance.MouseOverBackColor -eq $close.BackColor -and $close.FlatAppearance.MouseDownBackColor -eq $close.BackColor) 'Close must turn red with unchanged background'
                Invoke-Lbs229MouseEvent $close 'OnMouseLeave'
                Require-Lbs229Correction ($close.ForeColor -eq $idle) 'Close restores idle glyph'
            }
            Test-Lbs229SecondCorrection "F08 $kind actual modal dimming and restoration" {
                $originalBounds = $owner.Bounds
                $originalOpacity = $owner.Opacity
                $script:DimProbeError = $null
                $script:DimProbeSeen = $false
                $timer = New-Object Windows.Forms.Timer
                $timer.Interval = 50
                $timer.Add_Tick({
                    param($sender,$eventArgs)
                    $child = $script:ActiveAuxiliaryPopup
                    if (-not $child -or -not $child.Visible) { return }
                    $sender.Stop()
                    try {
                        $dim = @($owner.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer')
                        Require-Lbs229Correction ($dim.Count -eq 1 -and $dim[0].Visible -and $dim[0].BackColor -eq [Drawing.Color]::Black -and $dim[0].Opacity -ge 0.25 -and $dim[0].Opacity -le 0.5) 'Expected one visible black translucent owner dimmer'
                        Require-Lbs229Correction ($dim[0].Bounds -eq $owner.RectangleToScreen($owner.ClientRectangle) -and -not $dim[0].ShowInTaskbar -and $child.Opacity -eq 1.0 -and [Lbs229Native]::IsWindowEnabled($child.Handle) -and -not [Lbs229Native]::IsWindowEnabled($owner.Handle)) 'Dimmer must cover only owner client area; child remains opaque and enabled'
                        Require-Lbs229Correction ((Test-Lbs229Above $dim[0].Handle $owner.Handle) -and (Test-Lbs229Above $child.Handle $dim[0].Handle)) 'Native z-order must keep the scrim above the owner and below the active child'
                        Require-Lbs229Correction (-not $child.Tag.Close.Focused -and $child.Tag.Body.ContainsFocus) 'LBS233 hotfix initial keyboard focus belongs to content, not close glyph'
                        Require-Lbs229Correction ([Math]::Abs($dim[0].Opacity-0.45) -lt 0.005) 'LBS233 hotfix owner dimming is 45 percent'
                        $script:DimProbeSeen = $true
                    } catch { $script:DimProbeError = $_ }
                    finally { $child.Tag.Close.PerformClick() }
                })
                try {
                    $timer.Start()
                    [void](Show-OwnedAuxiliaryPopup -Form $surface -Owner $owner)
                } finally { $timer.Stop(); $timer.Dispose() }
                if ($script:DimProbeError) { throw $script:DimProbeError }
                Require-Lbs229Correction ($script:DimProbeSeen -and @($owner.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer').Count -eq 0 -and $owner.Bounds -eq $originalBounds -and $owner.Opacity -eq $originalOpacity -and [Lbs229Native]::IsWindowEnabled($owner.Handle)) 'Owner must restore immediately without residual dimmer or geometry changes'
            }
        } finally { if (-not $surface.IsDisposed) { $surface.Dispose() } }
    }
    Test-Lbs229SecondCorrection 'F07 main refresh glyph background and hover' {
        $rootPanel = New-Object Windows.Forms.Panel
        try {
            Add-PopupHeaderSection -Root $rootPanel
            $refresh = $script:RefreshButton
            Require-Lbs229Correction ($refresh.FlatAppearance.MouseOverBackColor -eq $refresh.BackColor -and $refresh.FlatAppearance.MouseDownBackColor -eq $refresh.BackColor) 'Refresh hover and press must preserve header background'
            Invoke-Lbs229MouseEvent $refresh 'OnMouseEnter'
            Require-Lbs229Correction ($refresh.ForeColor -eq $script:ColorAccent) 'Refresh hover glyph must use existing accent'
            Invoke-Lbs229MouseEvent $refresh 'OnMouseLeave'
            Require-Lbs229Correction ($refresh.ForeColor -eq $script:ColorSecondary) 'Refresh idle glyph restores'
        } finally { $rootPanel.Dispose(); $script:RefreshButton = $null; $script:HeaderStatusLabel = $null }
    }
    Test-Lbs229SecondCorrection 'F08 failed modal show restores owner' {
        $invalid = New-ConfigurationPopup
        $invalid.Enabled = $false
        $failed = $false
        try {
            try { [void](Show-OwnedAuxiliaryPopup -Form $invalid -Owner $owner) }
            catch { $failed = $true }
            Require-Lbs229Correction ($failed -and $invalid.IsDisposed -and -not $script:ActiveAuxiliaryPopup -and @($owner.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer').Count -eq 0 -and [Lbs229Native]::IsWindowEnabled($owner.Handle)) 'Failed ShowDialog must release scrim, child and modal guard'
        } finally { if (-not $invalid.IsDisposed) { $invalid.Dispose() } }
    }
    if ($secondFailures.Count) { throw ("LBS229 second correction RED: " + ($secondFailures -join '; ')) }
    # F09: exercise real native Button rendering, not just FlatAppearance
    # properties. NotifyDefault models a retained native default-button outline
    # even when the actual owner is disabled by ShowDialog.
    function Get-Lbs229RefreshFramePixels([Windows.Forms.Button]$Button) {
        $bitmap = [Drawing.Bitmap]::new($Button.Width,$Button.Height)
        try {
            $Button.DrawToBitmap($bitmap,$Button.ClientRectangle)
            $background = $Button.BackColor.ToArgb()
            $count = 0
            for ($y=0; $y -lt $bitmap.Height; $y++) {
                for ($x=0; $x -lt $bitmap.Width; $x++) {
                    if ($x -ge 4 -and $x -lt $bitmap.Width-4 -and $y -ge 4 -and $y -lt $bitmap.Height-4) { continue }
                    if ($bitmap.GetPixel($x,$y).ToArgb() -ne $background) { $count++ }
                }
            }
            return $count
        } finally { $bitmap.Dispose() }
    }
    # WinForms default/focus pixels depend on the actual foreground window
    # and keyboard cue state. Do not require an outline when the active
    # control is not in that state. Directly verify that the modal-only
    # painter is a no-op once the owner is interactive again.
    function Test-Lbs229ActiveRefreshNativePaint([Windows.Forms.Form]$Owner,[Windows.Forms.Button]$Button) {
        if ($script:ActiveAuxiliaryPopup -or -not [Lbs229Native]::IsWindowEnabled($Owner.Handle) -or -not $Button.TabStop -or -not $Button.Enabled -or -not $Button.CanSelect) { return $false }
        $bitmap = [Drawing.Bitmap]::new($Button.Width,$Button.Height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $args = [Windows.Forms.PaintEventArgs]::new($graphics,$Button.ClientRectangle)
        try {
            $graphics.Clear([Drawing.Color]::Magenta)
            Paint-ModalOwnerRefreshGlyph -Button $Button -EventArgs $args
            for ($y=0; $y -lt $bitmap.Height; $y++) {
                for ($x=0; $x -lt $bitmap.Width; $x++) {
                    if ($bitmap.GetPixel($x,$y).ToArgb() -ne [Drawing.Color]::Magenta.ToArgb()) { return $false }
                }
            }
            return $true
        } finally { $args.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
    }
    $thirdFailures = [Collections.Generic.List[string]]::new()
    function Test-Lbs229ThirdCorrection([string]$Name,[scriptblock]$Action) {
        try { & $Action; Write-Host "PASS LBS229 third correction $Name" }
        catch { $thirdFailures.Add("$Name : $_"); Write-Host "RED LBS229 third correction $Name : $_" }
    }
    $headerRoot = New-Object Windows.Forms.Panel
    $headerRoot.Size = $owner.ClientSize
    $owner.Controls.Add($headerRoot)
    try {
        Add-PopupHeaderSection -Root $headerRoot
        $refresh = $script:RefreshButton
        $refresh.NotifyDefault($true)
        $activeFrame = Get-Lbs229RefreshFramePixels $refresh
        Write-Host "F09 active native frame pixels=$activeFrame"
        if ($activeFrame -lt 8) { throw 'F09 fixture could not reproduce native active default outline' }
        foreach ($kind in @('configuration','default')) {
            Test-Lbs229ThirdCorrection "F09 $kind inactive outline and active restoration" {
                $surface = if ($kind -eq 'configuration') { New-ConfigurationPopup } else { New-DefaultTargetPicker }
                $script:FocusProbeError = $null
                $script:FocusProbeSeen = $false
                $timer = New-Object Windows.Forms.Timer
                $timer.Interval = 50
                $timer.Add_Tick({
                    param($sender,$eventArgs)
                    $child = $script:ActiveAuxiliaryPopup
                    if (-not $child -or -not $child.Visible) { return }
                    $sender.Stop()
                    try {
                        $refresh.NotifyDefault($true)
                        $pixels = Get-Lbs229RefreshFramePixels $refresh
                        Write-Host "F09 $kind modal native frame pixels=$pixels"
                        Require-Lbs229Correction ($pixels -eq 0) "Inactive refresh outline remains ($pixels frame pixels)"
                        Require-Lbs229Correction (-not [Lbs229Native]::IsWindowEnabled($owner.Handle) -and $refresh.TabStop -and $refresh.FlatAppearance.BorderSize -eq 0) 'Native modal admission and keyboard route unchanged'
                        $script:FocusProbeSeen = $true
                    } catch { $script:FocusProbeError = $_ }
                    finally { $child.Tag.Close.PerformClick() }
                })
                try {
                    $timer.Start()
                    [void](Show-OwnedAuxiliaryPopup -Form $surface -Owner $owner)
                } finally { $timer.Stop(); $timer.Dispose() }
                if ($script:FocusProbeError) { throw $script:FocusProbeError }
                Require-Lbs229Correction (Test-Lbs229ActiveRefreshNativePaint $owner $refresh) 'Active native painting and keyboard route must be restored after close'
                Require-Lbs229Correction $script:FocusProbeSeen 'Actual modal must have been observed'
            }
        }
        Test-Lbs229ThirdCorrection 'F09 failed modal start restores active rendering' {
            $invalid = New-ConfigurationPopup
            $invalid.Enabled = $false
            $failed = $false
            try { [void](Show-OwnedAuxiliaryPopup -Form $invalid -Owner $owner) }
            catch { $failed = $true }
            Require-Lbs229Correction ($failed -and $invalid.IsDisposed -and (Test-Lbs229ActiveRefreshNativePaint $owner $refresh)) 'Failed modal must restore native active painting and keyboard route'
        }
    } finally {
        $headerRoot.Dispose()
        $script:RefreshButton = $null
        $script:HeaderStatusLabel = $null
    }
    if ($thirdFailures.Count) { throw ("LBS229 third correction RED: " + ($thirdFailures -join '; ')) }
    if ($CorrectionProbeOnly) { return }

    # LBS-233: positive coverage for the approved left-only placement and the
    # pure bridge geometry (screen coordinates, negative origin, 100/250%).
    Initialize-AuxiliaryOwnerDimmer
    foreach ($factor in @(1.0,2.5)) {
        $gap = [int][Math]::Round(8*$factor)
        $wa = [Drawing.Rectangle]::new(-2500,-400,4000,2000)
        $main = [Drawing.Rectangle]::new(-700,0,975,1000)
        $row = [Drawing.Rectangle]::new(-700,400,975,[int][Math]::Round(38*$factor))
        $childSize = [Drawing.Size]::new(975,600)
        $pos = Get-AuxiliaryPopupLocation $wa $main $childSize $row $factor
        $childBounds = [Drawing.Rectangle]::new($pos,$childSize)
        $bridge = [LenovoAuxiliaryConnector]::GetConnectorBounds($wa,$main,$row,$childBounds,$factor)
        Assert-Lbs229 "LBS233 scale $factor left-only aligned bridge" ($childBounds.Right -eq $main.Left-$gap -and $bridge.Left -eq $childBounds.Right -and $bridge.Right -eq $row.Left -and $bridge.Top+[int][Math]::Floor($bridge.Height/2) -eq $row.Top+[int][Math]::Floor($row.Height/2))
        $overlap = [Drawing.Rectangle]::new($main.Left,0,975,600)
        Assert-Lbs229 "LBS233 scale $factor overlap omits bridge" ([LenovoAuxiliaryConnector]::GetConnectorBounds($wa,$main,$row,$overlap,$factor).IsEmpty)
        $rightOnly = [Drawing.Rectangle]::new($main.Left-5,0,2300,1400)
        $clamp = Get-AuxiliaryPopupLocation $rightOnly $main $childSize $row $factor
        Assert-Lbs229 "LBS233 scale $factor never switches right" ($clamp.X -eq $rightOnly.Left)
        $low = [Drawing.Rectangle]::new($childBounds.X,0,$childBounds.Width,100)
        Assert-Lbs229 "LBS233 scale $factor vertically unsafe bridge omitted" ([LenovoAuxiliaryConnector]::GetConnectorBounds($wa,$main,$row,$low,$factor).IsEmpty)
    }
    $p=Get-AuxiliaryPopupLocation $area $anchor $size
    Assert-Lbs229 'left placement stays on owner monitor' ($p.X -eq -398 -and $p.Y -eq 0)
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
        $script:PreferencesExportMenuItem.Text=Get-LocalizedString -Key 'Preferences.Export'
        $script:PreferencesImportMenuItem.Text=Get-LocalizedString -Key 'Preferences.Import'
        $script:RuntimeDiagnosticMenuItem.Text=Get-LocalizedString -Key 'Diagnostics.Save'
        $script:DiagnosticsUploadMenuItem.Text=Get-LocalizedString -Key 'Diagnostics.Upload'
        foreach ($scale in @(1.0,2.5)) {
            $case="$locale/$scale"
            $config=New-ConfigurationPopup
            try {
                Set-AuxiliaryPopupLayout $config $scale $area $anchor
                $body=$config.Tag.Body
                $button=@($body.Controls | Where-Object { $_ -is [Windows.Forms.Button] })
                Assert-Lbs229 "$case grouped configuration has all ten direct actions" ($button.Count -eq 10 -and $body.Controls['ConfigurationAutostart'] -and $config.CancelButton -eq $config.Tag.Close)
                Assert-Lbs229 "$case bounds and typography scale once" ($config.Width -eq [int](390*$scale) -and $body.Controls['ConfigurationAction-language-de'].Height -eq [int](38*$scale) -and $body.Controls['ConfigurationAction-system-setup'].Height -eq [int](52*$scale) -and $button[0].Font.Size -eq 9.0)
                Assert-Lbs229 "$case language selection and disabled install truthful" ($body.Controls["ConfigurationAction-language-$(if ($locale -eq 'de-DE') {'de'} else {'en'})"].LanguageSelected -and -not $body.Controls['ConfigurationAction-update-install'].Enabled)
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
                        $bounds=[LenovoSettingsInk]::TextBounds($b.ClientRectangle,[single](96*$scale),[bool]$b.LocaleCode)
                        $font=if ($b.LocaleCode) { $b.Font } else { $b.TitleFont }
                        $size=$g.MeasureString($b.Text,$font)
                        if ($size.Width -gt $bounds.Width -or $font.GetHeight([single](96*$scale)) -gt $b.Height) { $fit=$false }
                        if ($b.Subtitle -and $g.MeasureString($b.Subtitle,$b.SubtitleFont).Width -gt $bounds.Width) { $fit=$false }
                    }
                    Assert-Lbs229 "$case localized action labels fit synthetic design bounds" $fit
                } finally { $g.Dispose(); $bitmap.Dispose() }
                $de=$body.Controls['ConfigurationAction-language-de']
                $en=$body.Controls['ConfigurationAction-language-en']
                $toggle=$body.Controls['ConfigurationAutostart']
                $label=$body.Controls['ConfigurationLocale-Settings.Autostart']
                Assert-Lbs247 "$case native names and contiguous equal segments" ($de.Text -ceq 'Deutsch' -and $en.Text -ceq 'English' -and $de.LocaleCode -eq 'de-DE' -and $en.LocaleCode -eq 'en-US' -and [Math]::Abs($de.Width-$en.Width) -le 1 -and $de.Right -eq $en.Left -and $de.Top -eq $en.Top)
                $selected=if ($script:Locale -eq 'de-DE') { $de } else { $en }
                $other=if ($selected -eq $de) { $en } else { $de }
                Assert-Lbs247 "$case programmatic selected state, no checkmark" ($selected.LanguageSelected -and -not $other.LanguageSelected -and ($selected.AccessibilityObject.State -band [Windows.Forms.AccessibleStates]::Selected) -and -not ($other.AccessibilityObject.State -band [Windows.Forms.AccessibleStates]::Selected) -and $selected.FlatAppearance.BorderColor -eq $script:ColorAccent)
                $setup=$body.Controls['ConfigurationAction-system-setup']
                $remove=$body.Controls['ConfigurationAction-system-remove']
                Assert-Lbs247 "$case grouped action rows and native toggle" ($toggle -is [LenovoSettingsToggle] -and -not $toggle.AutoCheck -and $label.Right -eq $toggle.Left -and $label.Height -eq $toggle.Height -and $setup.Bottom -eq $remove.Top -and $setup.Separator -and $remove.Destructive -and $remove.FlatAppearance.BorderSize -eq 0 -and $setup.Subtitle -and $remove.Subtitle)
                $flagsMatch=$true
                foreach ($langButton in @($de,$en)) {
                    $actual=[Drawing.Bitmap]::new($langButton.Width,$langButton.Height)
                    $expected=[Drawing.Bitmap]::new($langButton.Width,$langButton.Height)
                    $actual.SetResolution([single](96*$scale),[single](96*$scale))
                    $expected.SetResolution([single](96*$scale),[single](96*$scale))
                    $ag=[Drawing.Graphics]::FromImage($actual)
                    $eg=[Drawing.Graphics]::FromImage($expected)
                    $fw=[LenovoSettingsInk]::Px([single](96*$scale),16)
                    $fh=[LenovoSettingsInk]::Px([single](96*$scale),12)
                    $fr=[Drawing.Rectangle]::new([LenovoSettingsInk]::Px([single](96*$scale),12),[int][Math]::Floor(($langButton.Height-$fh)/2),$fw,$fh)
                    $paint=[Windows.Forms.PaintEventArgs]::new($ag,$langButton.ClientRectangle)
                    try {
                        $method=$langButton.GetType().GetMethod('OnPaint',[Reflection.BindingFlags]'Instance,NonPublic')
                        [void]$method.Invoke($langButton,@($paint))
                        [LenovoLocaleFlags]::DrawFlag($eg,$langButton.LocaleCode,$fr)
                        for ($y=$fr.Top;$y -lt $fr.Bottom;$y++) {
                            for ($x=$fr.Left;$x -lt $fr.Right;$x++) {
                                if ($actual.GetPixel($x,$y).ToArgb() -ne $expected.GetPixel($x,$y).ToArgb()) { $flagsMatch=$false }
                            }
                        }
                    } finally { $paint.Dispose(); $ag.Dispose(); $eg.Dispose(); $actual.Dispose(); $expected.Dispose() }
                }
                Assert-Lbs247 "$case actual language button raster matches shared country flag renderer" $flagsMatch
                $savedLocale=$script:Locale
                $script:Locale=if ($savedLocale -eq 'de-DE') { 'en-US' } else { 'de-DE' }
                $script:LanguageEnglishMenuItem.Checked=($script:Locale -eq 'en-US')
                $script:LanguageGermanMenuItem.Checked=($script:Locale -eq 'de-DE')
                Update-ConfigurationPopupLocale -Form $config
                Assert-Lbs247 "$case live locale update preserves language identities and reverses selected state" ($de -eq $body.Controls['ConfigurationAction-language-de'] -and $en -eq $body.Controls['ConfigurationAction-language-en'] -and $de.Text -ceq 'Deutsch' -and $en.Text -ceq 'English' -and $other.LanguageSelected -and -not $selected.LanguageSelected -and $config.Tag.Subtitle.Text -ceq (Get-LocalizedString -Key 'Settings.MoreSubtitle'))
                $script:Locale=$savedLocale
                $script:LanguageEnglishMenuItem.Checked=($savedLocale -eq 'en-US')
                $script:LanguageGermanMenuItem.Checked=($savedLocale -eq 'de-DE')
                Update-ConfigurationPopupLocale -Form $config
            } finally { $config.Dispose() }
            $picker=New-DefaultTargetPicker
            try {
                Set-AuxiliaryPopupLayout $picker $scale $area $anchor
                $rows=@($picker.Tag.Body.Controls | Where-Object Name -eq 'DefaultPickerRow')
                $selected=@($rows | Where-Object {$_.Tag.Selected})
                Assert-Lbs229 "$case all visible ordered choices plus none" ($rows.Count -eq 15 -and -not $rows[0].Tag.Guid -and $rows[1].Tag.Guid -eq 'a')
                Assert-Lbs229 "$case persistent marker independent of one-shot" ($selected.Count -eq 1 -and $selected[0].Tag.Guid -eq 'a' -and $selected[0].Controls['DefaultPickerSelected'])
                Assert-Lbs229 "$case familiar row geometry and full accessible text" ($rows[1].Height -eq [int](60*$scale) -and $rows[1].Controls['DefaultPickerTitle'].AccessibleDescription -eq 'Corporate' -and $rows[1].Controls['DefaultPickerSubtitle'].Text -eq 'Internal SSD')
                $bar=$picker.Tag.Scroll
                Assert-Lbs229 "$case long list uses existing red/dark custom scrollbar" ($bar -is [LenovoVerticalScrollBar] -and -not $picker.Tag.Body.AutoScroll -and -not $picker.Tag.Viewport.AutoScroll -and $bar.TrackColor.ToArgb() -eq [Drawing.Color]::FromArgb(23,23,23).ToArgb() -and $bar.ThumbColor -eq $script:ColorAccent)
                Assert-Lbs229 "$case scaled scroll extent and content clipping" ($bar.Maximum -eq [int](900*$scale)-$picker.Tag.Viewport.Height -and $bar.LargeChange -eq $picker.Tag.Viewport.Height -and $bar.Width -eq [int](8*$scale) -and $picker.Tag.Body.Right -eq $bar.Left)
                $bar.Value=$bar.Maximum
                Assert-Lbs229 "$case bottom scroll reaches final choice without overscroll" ($picker.Tag.Body.Top -eq -$bar.Maximum -and $picker.Tag.Body.Bottom -eq $picker.Tag.Viewport.Height -and $rows[-1].Bottom -eq $picker.Tag.Body.Height)
                $bar.Value=0
            } finally { $picker.Dispose() }
        }
    }
    $small=New-ConfigurationPopup
    try {
        Set-AuxiliaryPopupLayout $small 2.5 ([Drawing.Rectangle]::new(-400,0,800,600)) ([Drawing.Rectangle]::new(-390,0,700,590))
        Assert-Lbs229 'small work area clamps child and exposes scrolling' ($small.Width -le 800 -and $small.Height -le 600 -and $small.Tag.Scroll.Maximum -gt 0 -and -not $small.Tag.Viewport.AutoScroll -and $small.Tag.Close.Right -le $small.Width)
    } finally { $small.Dispose() }
    $savedEntries=$script:CurrentEntries
    try {
        $script:CurrentEntries=@($savedEntries | Select-Object -First 2)
        $short=New-DefaultTargetPicker
        try {
            Set-AuxiliaryPopupLayout $short 1.0 $area $anchor
            Assert-Lbs229 'short picker has no scroll range or reserved gutter' ($short.Tag.Scroll -is [LenovoVerticalScrollBar] -and $short.Tag.Scroll.Maximum -eq 0 -and $short.Tag.Body.Width -eq $short.Tag.Viewport.Width)
        } finally { $short.Dispose() }
    } finally { $script:CurrentEntries=$savedEntries }
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
            try {
                $dim = @($owner.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer')
                Require-Lbs229Correction ($dim.Count -eq 1 -and $dim[0].Visible -and (Test-Lbs229Above $active.Handle $dim[0].Handle)) 'Existing modal route must keep owner dimmed below child'
                & $script:ModalAction $active
            }
            catch { $script:ModalError=$_ }
            finally { if ($active.DialogResult -eq [Windows.Forms.DialogResult]::None) { $active.DialogResult=[Windows.Forms.DialogResult]::Cancel } }
        })
        try {
            $timer.Start()
            if ($Kind -eq 'default') { Show-DefaultTargetMenu -Owner $owner }
            else { Show-ConfigurationPopup -Owner $owner }
        } finally { $timer.Stop(); $timer.Dispose() }
        if ($script:ModalError) { throw $script:ModalError }
        Assert-Lbs229 "$Kind modal actually shown, ownership released" ($script:ModalObserved -and -not $script:ActiveAuxiliaryPopup -and $owner.Visible -and [Lbs229Native]::IsWindowEnabled($owner.Handle) -and @($owner.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer').Count -eq 0)
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
        Assert-Lbs229 'LBS233 update action dispatches while both windows stay open' ($script:Actions.Count -eq 2 -and $active.Visible -and $owner.Visible -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None -and -not [Lbs229Native]::IsWindowEnabled($owner.Handle))
    }
    Assert-Lbs229 'advanced selection delegates to existing menu action exactly once' ($script:Actions.Count -eq 2 -and $script:Actions[1] -eq 'update-check')
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        $active.Tag.Body.Controls['ConfigurationAction-language-en'].PerformClick()
        Assert-Lbs229 'LBS233 language action retains both visible modal windows' ($script:Actions.Count -eq 3 -and $active.Visible -and $owner.Visible -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None)
    }
    Assert-Lbs229 'direct language choice dispatches existing language action' ($script:Actions.Count -eq 3 -and $script:Actions[2] -eq 'language-en')
    Invoke-Lbs229Modal 'default' {
        param($active)
        $bar=$active.Tag.Scroll
        $viewport=$active.Tag.Viewport
        $rows=@($active.Tag.Body.Controls | Where-Object Name -eq 'DefaultPickerRow' | Sort-Object Top)
        Assert-Lbs229 'actual overflow uses visible custom bar with fixed header' ($bar.Visible -and $bar.Maximum -gt 0 -and $viewport.Top -eq $active.Tag.Header.Bottom)
        $bitmap=[Drawing.Bitmap]::new($bar.Width,$bar.Height)
        try {
            $bar.DrawToBitmap($bitmap,$bar.ClientRectangle)
            Assert-Lbs229 'actual scrollbar paint has dark track and red thumb' ($bitmap.GetPixel(0,0).ToArgb() -eq $bar.TrackColor.ToArgb() -and $bitmap.GetPixel(3,5).ToArgb() -in @($bar.ThumbColor.ToArgb(),$bar.ThumbHoverColor.ToArgb()))
        } finally { $bitmap.Dispose() }
        $flags=[Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        $wheel=[Windows.Forms.HandledMouseEventArgs]::new([Windows.Forms.MouseButtons]::None,0,1,1,-120)
        [void]$rows[0].GetType().GetMethod('OnMouseWheel',$flags).Invoke($rows[0],@($wheel))
        Assert-Lbs229 'wheel scrolls content once without selecting target' ($wheel.Handled -and $bar.Value -eq $bar.SmallChange -and $active.Tag.Body.Top -eq -$bar.Value)
        [void]$rows[0].Focus()
        [void]$rows[0].GetType().GetMethod('OnKeyDown',$flags).Invoke($rows[0],@([Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::End)))
        Assert-Lbs229 'End keyboard navigation reveals last focused row' ($rows[-1].Focused -and $bar.Value -eq $bar.Maximum -and $active.Tag.Body.Bottom -eq $viewport.Height)
        [void]$rows[-1].GetType().GetMethod('OnKeyDown',$flags).Invoke($rows[-1],@([Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Home)))
        Assert-Lbs229 'Home keyboard navigation restores top' ($rows[0].Focused -and $bar.Value -eq 0)
        $active.Tag.Close.PerformClick()
    }
    Assert-Lbs229 'default cancellation performs no write' ($script:DefaultCalls.Count -eq 0)
    Invoke-Lbs229Modal 'default' {
        param($active)
        $row=$active.Tag.Body.Controls | Where-Object {$_.Tag.Guid -eq 'b'} | Select-Object -First 1
        [Windows.Forms.SendKeys]::SendWait('{HOME}')
        [Windows.Forms.SendKeys]::SendWait('{DOWN}')
        [Windows.Forms.SendKeys]::SendWait('{DOWN}')
        [Windows.Forms.Application]::DoEvents()
        Assert-Lbs229 'real keyboard navigation focuses chosen row without default or BootNext dispatch' ($row.Focused -and $script:DefaultCalls.Count -eq 0 -and $script:BootCalls -eq 0)
        [Windows.Forms.SendKeys]::SendWait('{ENTER}')
        [Windows.Forms.Application]::DoEvents()
        Assert-Lbs229 'Enter records default choice before controller dispatch' ($script:DefaultCalls.Count -eq 0 -and $active.Tag.Choice.Guid -eq 'b')
    }
    Assert-Lbs229 'picker delegates exactly once to persistent-default controller' ($script:DefaultCalls.Count -eq 1 -and $script:DefaultCalls[0] -eq 'b' -and $script:BootCalls -eq 0)
    Invoke-Lbs229Modal 'default' {
        param($active)
        $none=$active.Tag.Body.Controls | Where-Object {-not $_.Tag.Guid} | Select-Object -First 1
        [Windows.Forms.SendKeys]::SendWait('{HOME}')
        [Windows.Forms.Application]::DoEvents()
        if (-not $none.Focused) { throw 'F10 clear row lacks keyboard focus' }
        [Windows.Forms.SendKeys]::SendWait(' ')
        [Windows.Forms.Application]::DoEvents()
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

    # LBS-233: exercise the actual navigation rows and modal path, including
    # real owner cutout, row paint, non-activating connector and layout loss.
    $script:Busy = $false
    $script:Drift = $false
    $script:Ready = $true
    $script:DefaultInteractionEnabled = $true
    $script:DefaultTargetChangePending = $false
    $script:BootNextPendingGuid = $null
    $script:Scale = 1.0
    $nativeOwner = New-Object Windows.Forms.Form
    $nativeOwner.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $nativeOwner.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $nativeOwner.ClientSize = [Drawing.Size]::new(390,672)
    $nativeOwner.ShowInTaskbar = $false
    $nativeOwner.TopMost = $true
    $nativeArea = [Windows.Forms.Screen]::FromControl($owner).WorkingArea
    $nativeOwner.Location = [Drawing.Point]::new(($nativeArea.Right-$nativeOwner.Width),$nativeArea.Top)
    $nativeRoot = New-Object Windows.Forms.Panel
    $nativeRoot.Dock = [Windows.Forms.DockStyle]::Fill
    $nativeOwner.Controls.Add($nativeRoot)
    try {
        $nativeOwner.Show()
        [Windows.Forms.Application]::DoEvents()
        foreach ($locale in @('de-DE','en-US')) {
            $script:Locale = $locale
            Add-PopupSettingsSection -Root $nativeRoot
            foreach ($kind in @('SettingsPanel','DefaultPanel')) {
                $script:Lbs233Row = $nativeRoot.Controls[$kind]
                Set-PopupNavigationRowHover -Control $script:Lbs233Row -Hover $true
                Require-Lbs229Correction ($script:Lbs233Row.BackColor.ToArgb() -eq [Drawing.Color]::FromArgb(48,48,48).ToArgb()) 'LBS233 hotfix ordinary navigation hover uses brighter color'
                $script:Lbs233Owner = $nativeOwner
                $script:Lbs233Observed = $false
                $script:Lbs233Error = $null
                $script:Lbs233Connector = $null
                $script:Lbs233Dimmer = $null
                $timer = New-Object Windows.Forms.Timer
                $timer.Interval = 50
                $timer.Add_Tick({
                    param($sender,$eventArgs)
                    $child = $script:ActiveAuxiliaryPopup
                    if (-not $child -or -not $child.Visible) { return }
                    $sender.Stop()
                    try {
                        $row = $script:Lbs233Row
                        $parent = $script:Lbs233Owner
                        $dim = @($parent.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer')
                        Require-Lbs229Correction ($dim.Count -eq 1 -and $dim[0].Visible) 'Exactly one owner scrim'
                        $script:Lbs233Dimmer = $dim[0]
                        $bounds = $row.RectangleToScreen($row.ClientRectangle)
                        $center = $dim[0].PointToClient([Drawing.Point]::new(($bounds.Left+8),($bounds.Top+8)))
                        Require-Lbs229Correction ($dim[0].HighlightedRowBounds -eq $bounds -and $dim[0].Region -and -not $dim[0].Region.IsVisible($center) -and $dim[0].Region.IsVisible(1,1)) 'Only initiating row is excluded from dimming'
                        Require-Lbs229Correction ($row.BackColor.ToArgb() -eq [Drawing.Color]::FromArgb(48,48,48).ToArgb() -and -not [Lbs229Native]::IsWindowEnabled($parent.Handle)) 'LBS233 hotfix brighter initiating row must not reactivate modal owner'
                        $bmp = [Drawing.Bitmap]::new($row.Width,$row.Height)
                        try {
                            $row.DrawToBitmap($bmp,$row.ClientRectangle)
                            Require-Lbs229Correction ($bmp.GetPixel(1,10).ToArgb() -eq $script:ColorAccent.ToArgb()) 'Red accent must be painted on actual initiating row'
                        } finally { $bmp.Dispose() }
                        $expected = [LenovoAuxiliaryConnector]::GetConnectorBounds([Windows.Forms.Screen]::FromControl($parent).WorkingArea,$parent.RectangleToScreen($parent.ClientRectangle),$bounds,$child.Bounds,1.0)
                        $connectors = @($child.OwnedForms | Where-Object Name -eq 'AuxiliaryConnector')
                        if (-not $expected.IsEmpty) {
                            Require-Lbs229Correction ($connectors.Count -eq 1 -and $connectors[0].Visible -and $connectors[0].VisualBounds -eq $expected -and $connectors[0].Location -eq $expected.Location -and -not $connectors[0].ShowInTaskbar) ("Real bridge follows screen-coordinate geometry: expected=$expected count=$($connectors.Count) actual=$($connectors | ForEach-Object { 'bounds='+$_.Bounds+' visible='+$_.Visible+' taskbar='+$_.ShowInTaskbar }) child=$($child.Bounds) row=$bounds owner=$($parent.Bounds)")
                            $script:Lbs233Connector = $connectors[0]
                            Require-Lbs229Correction ($connectors[0].Region.IsVisible(1,[int][Math]::Floor($expected.Height/2)) -and -not $connectors[0].Region.IsVisible($expected.Width,[int][Math]::Floor($expected.Height/2)) -and -not $connectors[0].Region.IsVisible(1,$expected.Height)) 'Visible bridge must be clipped to approved geometry even if WinForms enlarges the backing window'
                            $style = [Lbs229Native]::GetWindowLong($connectors[0].Handle,-20)
                            Require-Lbs229Correction (($style -band 0x08000020) -eq 0x08000020) 'Bridge is non-activating and input-transparent'
                            # A clipped trigger must immediately lose its bridge
                            # and scrim hole; restoring it recreates safe geometry.
                            $row.Left = 1
                            Require-Lbs229Correction (-not $connectors[0].Visible -and $dim[0].HighlightedRowBounds.IsEmpty) 'Unsafe layout removes bridge and highlight'
                            $row.Left = 0
                            Require-Lbs229Correction ($connectors[0].Visible -and $dim[0].HighlightedRowBounds -eq $bounds) 'Restored layout restores bridge and highlight'
                        } else {
                            Require-Lbs229Correction (@($connectors | Where-Object Visible).Count -eq 0) 'Constrained native work area must omit bridge'
                        }
                        $script:Lbs233Observed = $true
                    } catch { $script:Lbs233Error = $_ }
                    finally { $child.Tag.Close.PerformClick() }
                })
                try {
                    $timer.Start()
                    $flags = [Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
                    if ($kind -eq 'DefaultPanel') {
                        [void]$script:Lbs233Row.GetType().GetMethod('OnKeyDown',$flags).Invoke($script:Lbs233Row,@([Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Enter)))
                    } else {
                        [void]$script:Lbs233Row.GetType().GetMethod('OnClick',$flags).Invoke($script:Lbs233Row,@([EventArgs]::Empty))
                    }
                } finally { $timer.Stop(); $timer.Dispose() }
                if ($script:Lbs233Error) { throw $script:Lbs233Error }
                $expectedHover = if ($script:Lbs233Row.RectangleToScreen($script:Lbs233Row.ClientRectangle).Contains([Windows.Forms.Cursor]::Position) -and (Test-PopupNavigationRowInteractive -Row $script:Lbs233Row)) { [Drawing.Color]::FromArgb(48,48,48) } else { $script:ColorSurface }
                Assert-Lbs229 "LBS233 $locale $kind real navigation modal highlight and cleanup" ($script:Lbs233Observed -and $script:Lbs233Dimmer.IsDisposed -and (-not $script:Lbs233Connector -or $script:Lbs233Connector.IsDisposed) -and -not $script:ActiveAuxiliaryPopup -and $script:Lbs233Row.BackColor.ToArgb() -eq $expectedHover.ToArgb() -and [Lbs229Native]::IsWindowEnabled($nativeOwner.Handle))
            }
            foreach ($control in @($nativeRoot.Controls)) { $control.Dispose() }
        }
    } finally { $nativeOwner.Dispose() }
    Assert-Lbs229 'LBS233 modal visual probes dispatch no action' ($script:Actions.Count -eq 3 -and $script:DefaultCalls.Count -eq 2 -and $script:BootCalls -eq 0)
    # LBS-233 focus regression: model the actual async upload state without network.
    $script:Busy=$false
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        $upload=$active.Tag.Body.Controls['ConfigurationAction-diagnostics-upload']
        [void]$upload.Focus()
        Assert-Lbs229 'upload action holds keyboard focus before disabling' ($upload.Focused)
        $script:DiagnosticsUploadMenuItem.Enabled=$false
        try {
            Update-ConfigurationPopupPresentation -Form $active
            Assert-Lbs229 'disabled final action hands focus to eligible body control, never close glyph' (-not $upload.Enabled -and $active.Tag.Body.ContainsFocus -and -not $active.Tag.Close.Focused)
        } finally { $script:DiagnosticsUploadMenuItem.Enabled=$true }
        Update-ConfigurationPopupPresentation -Form $active
        # Check restoration on the same real owned window using a content control.
        [void]$upload.Focus()
        $restore=New-Object Windows.Forms.Form
        $restore.Add_Shown({ $this.DialogResult=[Windows.Forms.DialogResult]::Cancel })
        try {
            [void](Show-LenovoOwnedDialog -Form $restore -Owner $active)
            Assert-Lbs229 'nested notice restores eligible originating body focus' ($upload.Focused -and $active.Visible -and -not $active.Tag.Close.Focused)
        } finally { $restore.Dispose() }
        # Force the legitimate keyboard close focus; inactive rendering must
        # still suppress its outline while a nested notice owns the window.
        [void]$active.Tag.Close.Focus()
        Assert-Lbs229 'close button remains keyboard focusable and CancelButton' ($active.Tag.Close.Focused -and $active.Tag.Close.TabStop -and $active.CancelButton -eq $active.Tag.Close)
        $notice=New-Object Windows.Forms.Form
        $notice.ShowInTaskbar=$false
        $notice.TopMost=$true
        $script:FocusNoticeError=$null
        $notice.Add_Shown({
            param($sender,$eventArgs)
            try {
                $parent=$script:ActiveAuxiliaryPopup
                $close=$parent.Tag.Close
                $bitmap=[Drawing.Bitmap]::new($close.Width,$close.Height)
                try {
                    $close.DrawToBitmap($bitmap,$close.ClientRectangle)
                    $background=$close.BackColor.ToArgb()
                    $edgeInk=0
                    for ($x=0;$x -lt $bitmap.Width;$x++) {
                        foreach ($y in @(0,1,($bitmap.Height-2),($bitmap.Height-1))) {
                            if ($bitmap.GetPixel($x,$y).ToArgb() -ne $background) { $edgeInk++ }
                        }
                    }
                    for ($y=2;$y -lt $bitmap.Height-2;$y++) {
                        foreach ($x in @(0,1,($bitmap.Width-2),($bitmap.Width-1))) {
                            if ($bitmap.GetPixel($x,$y).ToArgb() -ne $background) { $edgeInk++ }
                        }
                    }
                    $glyphInk=0
                    for ($x=2;$x -lt $bitmap.Width-2;$x++) {
                        for ($y=2;$y -lt $bitmap.Height-2;$y++) {
                            if ($bitmap.GetPixel($x,$y).ToArgb() -ne $background) { $glyphInk++ }
                        }
                    }
                    Require-Lbs229Correction ($edgeInk -eq 0 -and $glyphInk -gt 0) "Inactive close glyph must retain X without outline: edge ink=$edgeInk glyph ink=$glyphInk"
                } finally { $bitmap.Dispose() }
            } catch { $script:FocusNoticeError=$_ }
            finally { $sender.DialogResult=[Windows.Forms.DialogResult]::Cancel }
        })
        try {
            [void](Show-LenovoOwnedDialog -Form $notice -Owner $active)
            if ($script:FocusNoticeError) { throw $script:FocusNoticeError }
            Assert-Lbs229 'nested notice closes with no inactive close outline' ($active.Visible -and -not $script:ActiveOwnedDialog)
        } finally { $notice.Dispose() }
    }
    # Exercise every remaining settings action without real privileged/network effects.
    $script:Busy=$false
    $script:UpdateInstallMenuItem.Enabled=$true
    Invoke-Lbs229Modal 'configuration' {
        param($active)
        foreach ($action in @('preferences-export','preferences-import','system-setup','system-remove','diagnostics-save','diagnostics-upload','update-install')) {
            $before=$script:Actions.Count
            $active.Tag.Body.Controls['ConfigurationAction-'+$action].PerformClick()
            Assert-Lbs229 "LBS233 $action dispatch once and preserve settings modal" ($script:Actions.Count -eq $before+1 -and $script:Actions[-1] -eq $action -and $active.Visible -and $owner.Visible -and $active.DialogResult -eq [Windows.Forms.DialogResult]::None)
        }
        $oldLocale=$script:Locale
        $script:Locale=if ($oldLocale -eq 'de-DE') {'en-US'} else {'de-DE'}
        Update-ConfigurationPopupLocale -Form $active
        Assert-Lbs229 'LBS233 settings headings and accessibility relocalize on same visible handle' ($active.Visible -and $active.Tag.Title.Text -eq (Get-LocalizedString -Key 'Settings.More') -and $active.Tag.Body.Controls['ConfigurationLocale-Settings.Language'].Text -eq (Get-LocalizedString -Key 'Settings.Language'))
        $script:Locale=$oldLocale
        $nested=New-Object Windows.Forms.Form
        $nested.ShowInTaskbar=$false
        $nested.TopMost=$true
        $script:NestedObserved=$false
        $script:NestedError=$null
        $nested.Add_Shown({
            param($sender,$eventArgs)
            try {
                $parent=$script:ActiveAuxiliaryPopup
                $scrim=@($parent.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer')
                Require-Lbs229Correction ($parent.Visible -and $sender.Owner -eq $parent -and $scrim.Count -eq 1 -and $scrim[0].Visible -and -not [Lbs229Native]::IsWindowEnabled($parent.Handle) -and (Get-LenovoDialogOwner) -eq $sender) 'Nested dialog owns active settings and dims it without hiding either window'
                $script:NestedObserved=$true
            } catch { $script:NestedError=$_ }
            finally { $sender.DialogResult=[Windows.Forms.DialogResult]::Cancel }
        })
        try {
            $result=Show-LenovoOwnedDialog -Form $nested -Owner (Get-LenovoDialogOwner)
            if ($script:NestedError) { throw $script:NestedError }
            Assert-Lbs229 'LBS233 nested cancel restores same modal owner and removes nested scrim' ($script:NestedObserved -and $result -eq [Windows.Forms.DialogResult]::Cancel -and $active.Visible -and [Lbs229Native]::IsWindowEnabled($active.Handle) -and -not $script:ActiveOwnedDialog -and @($active.OwnedForms | Where-Object Name -eq 'AuxiliaryOwnerDimmer').Count -eq 0)
        } finally { $nested.Dispose() }
        # Real native activation of both language choices while the same modal
        # stays open. Use the existing tray dispatch and a fixture locale owner.
        $savedLocale=$script:Locale
        $savedEn=$script:LanguageEnglishMenuItem.Checked
        $savedDe=$script:LanguageGermanMenuItem.Checked
        $handler=[EventHandler]{
            param($sender,$eventArgs)
            $script:Locale=if ($sender.Tag -eq 'language-de') { 'de-DE' } else { 'en-US' }
            $script:LanguageGermanMenuItem.Checked=($script:Locale -eq 'de-DE')
            $script:LanguageEnglishMenuItem.Checked=($script:Locale -eq 'en-US')
            Update-ConfigurationPopupLocale -Form $script:ActiveAuxiliaryPopup
        }
        $script:LanguageGermanMenuItem.Add_Click($handler)
        $script:LanguageEnglishMenuItem.Add_Click($handler)
        try {
            $script:Locale='en-US'
            $script:LanguageGermanMenuItem.Checked=$false
            $script:LanguageEnglishMenuItem.Checked=$true
            Update-ConfigurationPopupLocale -Form $active
            $de=$active.Tag.Body.Controls['ConfigurationAction-language-de']
            $en=$active.Tag.Body.Controls['ConfigurationAction-language-en']
            $handle=$active.Handle
            $before=$script:Actions.Count
            $de.PerformClick()
            Assert-Lbs247 'real activation from English to German keeps native flag and modal identity' ($script:Actions.Count -eq $before+1 -and $script:Actions[-1] -eq 'language-de' -and $de.LanguageSelected -and -not $en.LanguageSelected -and $de.Text -ceq 'Deutsch' -and $en.Text -ceq 'English' -and $active.Visible -and $active.Handle -eq $handle)
            $en.PerformClick()
            Assert-Lbs247 'real activation from German to English restores language without closing modal' ($script:Actions.Count -eq $before+2 -and $script:Actions[-1] -eq 'language-en' -and $en.LanguageSelected -and -not $de.LanguageSelected -and $active.Visible -and $active.Handle -eq $handle)
            $en.PerformClick()
            Assert-Lbs247 'selected language activation is a no-op' ($script:Actions.Count -eq $before+2 -and $en.LanguageSelected)
        } finally {
            $script:LanguageGermanMenuItem.Remove_Click($handler)
            $script:LanguageEnglishMenuItem.Remove_Click($handler)
            $script:Locale=$savedLocale
            $script:LanguageGermanMenuItem.Checked=$savedDe
            $script:LanguageEnglishMenuItem.Checked=$savedEn
        }
    }
} finally {
    $owner.Dispose()
    $tray.Dispose()
}
Write-Host "LBS229 CONFIGURATION TOTAL $script:Checks"
if ($script:Lbs247Checks -ne 43) { throw "Unexpected LBS247/LBS260 test count: $script:Lbs247Checks" }
Write-Host "LBS247 SETTINGS TOTAL $script:Lbs247Checks/43"
