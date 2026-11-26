#requires -version 5.1
# LBS-206: real isolated WinForms Layout C and firmware-readback presentation.
# The only action delegates are safe counters; no firmware, SYSTEM task or restart.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\BootNextOwnership.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\Application\BootNextSelectionController.ps1')
$template=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
$renderer=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-RestartTargetUi'},$true)
if (-not $renderer -or @($errors).Count -gt 0) { throw 'Canonical restart renderer unavailable' }
. ([scriptblock]::Create($renderer.Extent.Text))

$script:ColorSurface=[Drawing.Color]::FromArgb(25,25,25)
$script:ColorPrimary=[Drawing.Color]::FromArgb(235,235,235)
$script:ColorSecondary=[Drawing.Color]::FromArgb(175,175,175)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(64,31,29)
$script:ColorWarning=[Drawing.Color]::FromArgb(241,174,63)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:AppVersion='1.5.10.0'
$script:BootTypeToolTip=New-Object System.Windows.Forms.ToolTip
$script:Entry1='boot-1'
$script:Entry2='boot-2'
$script:NextTitle='Windows - Gaming'
$script:DefaultTitle='Windows - Work'
$script:CanSetBootNext=$true
$script:checks=0
$script:DefaultCalls=0
$script:RestartCalls=0
function Assert-Lbs206([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS206 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS206 $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-CurrentSystemFunctionsCapabilities { param([switch]$ProbeReadiness) return [pscustomobject]@{ CanSetBootNext=[bool]$script:CanSetBootNext;CanRestart=$true } }
function Get-EntryByGuid {
    param([string]$Guid)
    if ($Guid -eq $script:Entry1) { return [pscustomobject]@{Guid=$Guid;Title=$script:DefaultTitle} }
    if ($Guid -eq $script:Entry2) { return [pscustomobject]@{Guid=$Guid;Title=$script:NextTitle} }
    return $null
}
function Get-EntryDisplayTitle { param($Entry) return [string]$Entry.Title }
function Get-NextBootTargetDisplayName {
    if (-not $script:NextBootFirmwareReadVerified) { return 'Unverified' }
    if (-not $script:SelectedGuid) { return 'Firmware order' }
    $e=Get-EntryByGuid -Guid $script:SelectedGuid
    if ($e) { return [string]$e.Title }
    return 'Unavailable'
}
function Get-DefaultEntryTitle {
    $e=Get-EntryByGuid -Guid $script:DefaultGuid
    if ($e) { return [string]$e.Title }
    return 'None'
}
function Use-DefaultForNextRestart { $script:DefaultCalls++ }
function Restart-Windows { $script:RestartCalls++ }
foreach ($locale in @('en-US','de-DE')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $form=New-Object System.Windows.Forms.Form
        $rootPanel=New-Object System.Windows.Forms.Panel
        $rootPanel.Name='PopupRoot'
        $rootPanel.Size=[Drawing.Size]::new(390,672)
        $form.ClientSize=$rootPanel.Size
        $form.Controls.Add($rootPanel)
        Initialize-PopupDpiLayout -Form $form
        Add-PopupRestartSection -Root $rootPanel
        Complete-PopupDpiLayout -Form $form -Scale $scale
        $script:Popup=$form
        $form.Show()
        [Windows.Forms.Application]::DoEvents()
        $tag="$locale/$scale"
        try {
            $status=$form.Controls.Find('RestartTargetLabel',$true) | Select-Object -First 1
            $action=$form.Controls.Find('RestartUseDefaultButton',$true) | Select-Object -First 1
            $restart=$script:RestartButton
            Assert-Lbs206 "$tag separate static status and explicit one-time action exist" (
                $status -is [Windows.Forms.Label] -and
                $action -is [Windows.Forms.Button] -and
                -not [object]::ReferenceEquals($status,$action) -and
                $status.TabStop -eq $false)
            Assert-Lbs206 "$tag original footprint and status-before-restart layout" (
                $form.Controls.Find('RestartPanel',$true)[0].Height -eq [int][Math]::Round(65*$scale) -and
                $status.Bottom -lt $restart.Top -and
                $status.Left -eq [int][Math]::Round(16*$scale) -and
                $status.Right -le [int][Math]::Round(374*$scale) -and
                $restart.Bottom -le [int][Math]::Round(65*$scale))
            $script:DefaultGuid=$script:Entry1
            $script:SelectedGuid=$script:Entry2
            $script:NextBootFirmwareReadVerified=$true
            $script:BootNextPendingGuid=$null
            $script:CanSetBootNext=$true
            Update-RestartTargetUi
            $expectedAction=if($locale -eq 'de-DE'){'Auf Standardziel zurücksetzen'}else{'Reset to default target'}
            Assert-Lbs206 "$tag differing verified target has separate explicit action" (
                $action.Visible -and $action.Enabled -and $action.TabStop -and
                $action.Text -eq $expectedAction -and
                $status.Text -notmatch '[(](change|ändern)[)]' -and
                $status.Text -match '(?i)(differ|abweich|standard|default)')
            $bitmap=[Drawing.Bitmap]::new(1,1)
            $bitmap.SetResolution([single](96*$scale),[single](96*$scale))
            $g=[Drawing.Graphics]::FromImage($bitmap)
            try {
                $actionWidth=$g.MeasureString($action.Text,$action.Font).Width
                $restartWidth=$g.MeasureString($restart.Text,$restart.Font).Width
                Assert-Lbs206 "$tag native fonts fit distinct actions without overlap" (
                    $actionWidth -le ($action.Width-8) -and
                    $restartWidth -le ($restart.Width-8) -and
                    $action.Right -le $restart.Left -and
                    $restart.Right -le [int][Math]::Round(374*$scale))
            } finally { $g.Dispose();$bitmap.Dispose() }
            Assert-Lbs206 "$tag status has full accessible text and tooltip" (
                $status.AccessibleDescription -eq $status.Text -and
                $script:BootTypeToolTip.GetToolTip($status) -eq $status.Text -and
                $status.Cursor -eq [Windows.Forms.Cursors]::Default)
            $before=$script:DefaultCalls
            [void]$action.Focus()
            [Windows.Forms.Application]::DoEvents()
            Assert-Lbs206 "$tag focus never applies stored default" ($script:DefaultCalls -eq $before)
            $action.PerformClick()
            Assert-Lbs206 "$tag explicit button delegates exactly once" ($script:DefaultCalls -eq ($before+1))
            $script:CanSetBootNext=$false
            Update-RestartTargetUi
            $action.PerformClick()
            Assert-Lbs206 "$tag readiness rejects disabled one-time action" (
                (-not $action.Enabled -or -not $action.Visible) -and $script:DefaultCalls -eq ($before+1))
            $script:CanSetBootNext=$true
            $script:SelectedGuid=$script:DefaultGuid
            Update-RestartTargetUi
            Assert-Lbs206 "$tag aligned readback needs no apply action" (
                (-not $action.Enabled -or -not $action.Visible) -and $status.Text -match '(?i)(match|standard)')
            $script:NextBootFirmwareReadVerified=$false
            Update-RestartTargetUi
            Assert-Lbs206 "$tag unknown readback never shows verified target or active action" (
                (-not $action.Enabled -or -not $action.Visible) -and
                $status.Text -match '(?i)(unknown|ungeprüft|unverified|unbekannt)')
            $script:NextBootFirmwareReadVerified=$true
            $script:SelectedGuid='nonexistent-boot'
            Update-RestartTargetUi
            Assert-Lbs206 "$tag unavailable target cannot trigger action" (
                (-not $action.Enabled -or -not $action.Visible) -and
                $status.Text -match '(?i)(unavailable|verfügbar)')
            $script:SelectedGuid=$null
            Update-RestartTargetUi
            Assert-Lbs206 "$tag firmware order is not misrepresented as confirmed BootNext" (
                $status.Text -match '(?i)(firmware|reihenfolge)' -and (-not $action.Enabled -or -not $action.Visible))
            $script:SelectedGuid=$script:Entry2
            $script:BootNextPendingGuid=$script:Entry2
            Update-RestartTargetUi
            Assert-Lbs206 "$tag pending visibly unverified and blocks both buttons" (
                $status.Text -match '(?i)(verif|bestät|pending|setting|wird|setze)' -and
                -not $restart.Enabled -and
                (-not $action.Enabled -or -not $action.Visible))
            $script:BootNextPendingGuid=$null
            $script:NextTitle=('Very long boot target alias ' * 12)
            Update-RestartTargetUi
            Assert-Lbs206 "$tag long aliases remain available through accessible description and tooltip" (
                $status.AccessibleDescription -eq $status.Text -and
                $status.Text.Contains('Very long boot target alias') -and
                $script:BootTypeToolTip.GetToolTip($status) -eq $status.Text)
            $script:NextTitle='Windows - Gaming'
            $script:DefaultGuid=$null
            Update-RestartTargetUi
            Assert-Lbs206 "$tag absent persistent default hides one-time action" (
                (-not $action.Enabled -or -not $action.Visible) -and $restart.Enabled)
            $beforeRestart=$script:RestartCalls
            $restart.PerformClick()
            Assert-Lbs206 "$tag explicit Restart remains independent from default action" (
                $script:RestartCalls -eq ($beforeRestart+1) -and $script:DefaultCalls -eq ($before+1))
        }
        finally {
            $script:BootNextPendingGuid=$null
            $script:NextTitle='Windows - Gaming'
            $script:DefaultGuid=$null
            $script:SelectedGuid=$null
            $script:Popup=$null
            $form.Dispose()
        }
    }
}
$script:BootTypeToolTip.Dispose()
Write-Host "LBS206 LAYOUT C TOTAL $script:checks"
