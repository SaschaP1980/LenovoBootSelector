#requires -version 5.1
# Exercise the canonical tray callback with real owned WinForms windows.
# No live shell injection or boot/system action is performed.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$template=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix='Add-Type -TypeDefinition @"'
$begin=$template.IndexOf($prefix,[StringComparison]::Ordinal)+$prefix.Length
$end=$template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($begin -lt $prefix.Length -or $end -le $begin) {throw 'Missing canonical C#'}
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
foreach ($path in @('src\UI\MenuAppearance.ps1','src\UI\PopupPosition.ps1','src\UI\Popup.ps1','src\UI\Dialogs.ps1')) {. (Join-Path $root $path)}
$script:ColorPrimary=[Drawing.Color]::White
$script:MenuRenderer=[Windows.Forms.ToolStripProfessionalRenderer]::new()
$script:checks=0;$script:failures=[Collections.Generic.List[string]]::new()
function Check([string]$Name,[bool]$Value) {
    $script:checks++
    if ($Value) {Write-Host "PASS LBS180 TRAY $Name"} else {$script:failures.Add($Name);Write-Host "FAIL LBS180 TRAY $Name"}
}
function Get-LocalizedString {param($Key) return $Key}
function Get-LenovoUiCoordinateScale {param($Screen) return [pscustomobject]@{Factor=1.0}}
function Write-LenovoMonitorTopologyEvent {}
function Write-LenovoDpiWindowEvent {}
function Write-RuntimeDiagnosticEvent {}
function New-RuntimeDiagnosticData {param($Data) return $Data}
function Update-PortablePreferencesMenuState {}
$context=[LenovoContextMenuStrip]::new()
$script:TrayContextMenu=$context
$start=$template.IndexOf('    $preferencesRoot = New-Object Windows.Forms.ToolStripMenuItem')
$end=$template.IndexOf('    $removeTasksItem = New-Object',$start)
if ($start -lt 0 -or $end -le $start) {throw 'Missing canonical menu construction'}
. ([scriptblock]::Create($template.Substring($start,$end-$start)))
foreach ($factor in @(1.0,2.5,1.0)) {
    [void](Set-LenovoMenuDpiLayout -Menu $preferencesRoot.DropDown -Scale $factor)
    [void](Set-LenovoMenuDpiLayout -Menu $maintenanceRoot.DropDown -Scale $factor)
    Check "F02 scale $factor parity for both preferences actions" ($exportItem.Padding -eq $setupItem.Padding -and $importItem.Padding -eq $setupItem.Padding -and $setupItem.Padding.Left -eq [int](18*$factor))
}
$start=$template.IndexOf('$script:TrayIcon.Add_MouseClick({')
$end=$template.IndexOf('    # v0.2.26 startup fast path',$start)
if ($start -lt 0 -or $end -le $start) {throw 'Missing canonical tray handler'}
$handlerText=$template.Substring($start,$end-$start)
$open=$handlerText.IndexOf('{')
$close=$handlerText.LastIndexOf('})')
$handler=[scriptblock]::Create($handlerText.Substring($open+1,$close-$open-1))
$right=[Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Right,1,0,0,0)
$script:PreferencesUiActive=$false
$owner=[Windows.Forms.Form]::new()
$owner.ShowInTaskbar=$false;$owner.TopMost=$true
$owner.StartPosition='Manual';$owner.Location=[Drawing.Point]::new(20,20)
$owner.ClientSize=[Drawing.Size]::new(390,500)
$script:Popup=$owner
try {
    $script:ActiveAuxiliaryPopup=$null;$script:ActiveOwnedDialog=$null
    & $handler $null $right
    Check 'F04 no popup opens menu' $context.Visible
    $context.Close()
    $owner.Show();[Windows.Forms.Application]::DoEvents()
    & $handler $null $right
    Check 'F04 main only hides main and opens menu' (-not $owner.Visible -and $context.Visible)
    $context.Close()
    foreach ($name in @('LenovoConfigurationPopup','LenovoDefaultTargetPicker','LenovoPreferencesConfirmation','LenovoPreferencesActiveConfirmation','LenovoNativeChooserGuard')) {
        $owner.Show();$owner.Activate();[Windows.Forms.Application]::DoEvents()
        $child=[Windows.Forms.Form]::new()
        $child.Name=$name;$child.TopMost=$true;$child.ShowInTaskbar=$false
        $child.ClientSize=[Drawing.Size]::new(240,120)
        $script:PreferencesUiActive=$name -in @('LenovoPreferencesActiveConfirmation','LenovoNativeChooserGuard')
        if ($name -in @('LenovoPreferencesConfirmation','LenovoPreferencesActiveConfirmation')) {$script:ActiveOwnedDialog=$child}
        elseif ($name -ne 'LenovoNativeChooserGuard') {$script:ActiveAuxiliaryPopup=$child}
        $script:TrayObserved=$false;$script:TrayFailure=$null
        $timer=[Windows.Forms.Timer]::new()
        $timer.Interval=100
        $timer.Add_Tick({
            $this.Stop()
            try {
                if (-not $child.Visible -or -not $owner.Visible) {throw 'Invalid modal fixture before tray callback'}
                & $handler $null $right
                $script:TrayObserved=($owner.Visible -and $child.Visible -and -not $context.Visible -and $child.ContainsFocus)
                Write-Host "LBS180 F04 native $name owner=$($owner.Visible) child=$($child.Visible) menu=$($context.Visible) focus=$($child.ContainsFocus)"
            } catch {$script:TrayFailure=$_}
            finally {$context.Close();$child.DialogResult=[Windows.Forms.DialogResult]::Cancel}
        })
        try {$timer.Start();[void]$child.ShowDialog($owner)}
        finally {$timer.Stop();$timer.Dispose();$child.Dispose();$script:ActiveAuxiliaryPopup=$null;$script:ActiveOwnedDialog=$null;$script:PreferencesUiActive=$false}
        if ($script:TrayFailure) {throw $script:TrayFailure}
        Check "F04 $name preserves modal owner and activates child" $script:TrayObserved
    }
} finally {$context.Dispose();$maintenanceRoot.Dispose();$owner.Dispose()}
Write-Host "LBS180 TRAY TOTAL $($script:checks-$script:failures.Count)/10"
if ($script:checks -ne 10 -or $script:failures.Count) {throw ('LBS180 TRAY RED: '+($script:failures -join '; '))}
