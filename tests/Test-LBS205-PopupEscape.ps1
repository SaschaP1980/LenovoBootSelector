#requires -version 5.1
# LBS-205: native, scoped main-popup Escape routing; no privileged operations.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs205Keys {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr handle, int message, IntPtr wParam, IntPtr lParam);
}
'@
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\Popup.ps1')
Initialize-NormalBootKeyboardRow

$script:checks = 0
$script:SaveCalls = 0
$script:BootCalls = 0
$script:RestartCalls = 0
$script:WorkerCancels = 0
$script:ReopenCalls = 0
$script:RefreshCalls = 0
$script:CurrentEntries = @([pscustomobject]@{ Guid='boot-1'; Title='Boot target' })
$script:ColorBackground = [Drawing.Color]::FromArgb(22,22,22)
$script:ColorRow = [Drawing.Color]::FromArgb(31,31,31)
$script:ColorPrimary = [Drawing.Color]::White
$script:ColorSecondary = [Drawing.Color]::Gray
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(64,31,29)
$script:ColorAccent = [Drawing.Color]::Red
$script:BootTypeToolTip = $null
function Assert-Lbs205([string]$Label,[bool]$Condition) {
    if (-not $Condition) { throw "LBS205 FAIL: $Label" }
    $script:checks++
    Write-Host "PASS LBS205 $Label"
}
function Get-LocalizedString { param([string]$Key,$Values) return "$script:Locale $Key" }
function Initialize-PopupDpiLayout { param($Form) }
function Complete-PopupDpiLayout {
    param($Form,[double]$Scale)
    $Form.ClientSize = [Drawing.Size]::new([int](390*$Scale),[int](672*$Scale))
}
function Write-PopupDpiLayoutDiagnostic { param($Form,$Phase,$MonitorSource) }
function Add-PopupHeaderSection { param($Root) }
function Add-PopupBootEntryListSection {
    param($Root)
    $script:Row = New-Object LenovoNormalBootKeyboardRow
    $script:Row.Name = 'BootRow'
    $script:Row.TabStop = $true
    $script:Row.Location = [Drawing.Point]::new(8,8)
    $script:Row.Size = [Drawing.Size]::new(360,110)
    $Root.Controls.Add($script:Row)
}
function Add-PopupSettingsSection {
    param($Root)
    $script:Ordinary = New-Object System.Windows.Forms.TextBox
    $script:Ordinary.Name = 'OrdinaryControl'
    $script:Ordinary.Location = [Drawing.Point]::new(8,130)
    $script:Ordinary.Size = [Drawing.Size]::new(260,24)
    $Root.Controls.Add($script:Ordinary)
}
function Add-PopupRestartSection {
    param($Root)
    $script:Action = New-Object System.Windows.Forms.Button
    $script:Action.Name = 'RestartButton'
    $script:Action.Text = 'Restart'
    $script:Action.Location = [Drawing.Point]::new(8,170)
    $script:Action.Size = [Drawing.Size]::new(200,40)
    $script:Action.Add_Click({ $script:RestartCalls++ })
    $Root.Controls.Add($script:Action)
}
function Add-PopupManageEntriesSection { param($Root) }
function New-MaintenanceStatePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Visible = $false
    return $panel
}
function Get-CurrentSystemFunctionsCapabilities {
    return [pscustomobject]@{State='Ready';CanUseCachedBootState=$true}
}
function Refresh-SystemDefaultState { return $true }
function Update-AutostartUi { return $true }
function Update-MaintenanceUi { }
function Position-Popup { param([switch]$FromTrayClick) }
function Start-PopupUpdateCheck { $script:ReopenCalls++; return $true }
function Start-BackgroundBootRefresh { param([switch]$RefreshStorage) $script:RefreshCalls++ }
function Update-ManageSaveButtonState { }
function Update-PopupRows { param([string]$Reason) }
function Save-AppSettings { $script:SaveCalls++ }
function Start-BootNextSelection { $script:BootCalls++ }

function Send-Lbs205Key($Control,[System.Windows.Forms.Keys]$Key) {
    if (-not $Control.IsHandleCreated) { throw 'Control HWND not created' }
    $wParam = [IntPtr]::new([int]$Key)
    if (-not [Lbs205Keys]::PostMessage($Control.Handle,0x0100,$wParam,[IntPtr]::Zero)) {
        throw 'WM_KEYDOWN post failed'
    }
    if (-not [Lbs205Keys]::PostMessage($Control.Handle,0x0101,$wParam,[IntPtr]::Zero)) {
        throw 'WM_KEYUP post failed'
    }
    for ($i=0; $i -lt 4; $i++) { [System.Windows.Forms.Application]::DoEvents() }
}
function Focus-Lbs205($Control) {
    [void]$script:Popup.Activate()
    [void]$Control.Focus()
    [System.Windows.Forms.Application]::DoEvents()
    if (-not $Control.Focused) { throw "Could not focus $($Control.Name)" }
}
foreach ($locale in @('en-US','de-DE')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale = $locale
        $script:IsManageEntriesMode = $false
        $script:ManageAliasEditGuid = $null
        $script:ManageActiveDragGuid = $null
        $script:ManageDragLayout = $null
        $script:DefaultContextMenu = $null
        $script:Popup = New-PopupForm -TargetScale $scale -ScaleSource 'native-synthetic'
        $form = $script:Popup
        try {
            $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $form.Location = [Drawing.Point]::new(30,30)
            $form.Show()
            [System.Windows.Forms.Application]::DoEvents()
            $case = "$locale / $scale"
            Assert-Lbs205 "$case native popup has preview and scaled bounds" (
                $form.KeyPreview -and $form.Visible -and $form.ClientSize.Width -eq [int](390*$scale))
            Focus-Lbs205 $script:Ordinary
            Send-Lbs205Key $script:Ordinary ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case ordinary child Escape hides but does not dispose popup" (
                -not $form.Visible -and -not $form.IsDisposed)
            Assert-Lbs205 "$case Escape causes no privileged, reboot or write actions" (
                $script:SaveCalls -eq 0 -and $script:BootCalls -eq 0 -and
                $script:RestartCalls -eq 0 -and $script:WorkerCancels -eq 0)

            Show-OrTogglePopup
            [System.Windows.Forms.Application]::DoEvents()
            Assert-Lbs205 "$case tray reopen reuses the same form" (
                $form.Visible -and [object]::ReferenceEquals($script:Popup,$form))
            Focus-Lbs205 $script:Row
            Send-Lbs205Key $script:Row ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case native focusable boot row Escape hides popup" (-not $form.Visible)

            Show-OrTogglePopup
            [System.Windows.Forms.Application]::DoEvents()
            $script:IsManageEntriesMode = $true
            $script:ManageAliasEditGuid = 'boot-1'
            Add-BootEntryAliasEditor -Row $script:Row -Entry ([pscustomobject]@{ Guid='boot-1' }) -Alias 'Before'
            $editor = $form.Controls.Find('AliasEditor',$true) | Select-Object -First 1
            $editor.Text = 'Uncommitted'
            Focus-Lbs205 $editor
            Send-Lbs205Key $editor ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case alias Escape cancels editor first, leaving popup open" (
                $form.Visible -and -not $script:ManageAliasEditGuid)
            $editorFrame = $form.Controls.Find('AliasEditorFrame',$true) | Select-Object -First 1
            if ($editorFrame) { $editorFrame.Parent.Controls.Remove($editorFrame); $editorFrame.Dispose() }
            foreach ($controlName in @('AliasApplyButton','AliasCancelButton')) {
                $control = $form.Controls.Find($controlName,$true) | Select-Object -First 1
                if ($control) { $control.Parent.Controls.Remove($control); $control.Dispose() }
            }
            $script:IsManageEntriesMode = $false
            Focus-Lbs205 $script:Action

            # A genuine native ToolStrip owns Escape while its menu is open.
            $menu = New-Object System.Windows.Forms.ContextMenuStrip
            [void]$menu.Items.Add('A target')
            $script:DefaultContextMenu = $menu
            try {
                $menu.Show($script:Action,[Drawing.Point]::new(0,$script:Action.Height))
                [System.Windows.Forms.Application]::DoEvents()
                Assert-Lbs205 "$case child menu is native and visible" ($menu.Visible)
                # Regression: native popup Deactivate must not hide its own
                # still-open default-target menu. The previous handler did.
                $deactivate = $form.GetType().GetMethod('OnDeactivate',([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
                if (-not $deactivate) { throw 'Native Form.OnDeactivate method unavailable' }
                [void]$deactivate.Invoke($form,[object[]]@([EventArgs]::Empty))
                Assert-Lbs205 "$case menu-owned Deactivate preserves popup while menu open" ($form.Visible -and $menu.Visible)
                Send-Lbs205Key $menu ([System.Windows.Forms.Keys]::Escape)
                Assert-Lbs205 "$case menu Escape closes menu without popup dismissal" (
                    -not $menu.Visible -and $form.Visible)
            }
            finally {
                $script:DefaultContextMenu = $null
                $menu.Dispose()
            }

            $script:IsManageEntriesMode = $true
            $script:ManageEntryOrder = @('boot-2','boot-1')
            $script:ManageHiddenEntryGuids = @('boot-2')
            $script:ManageEntryAliases = @{ 'boot-1'='Edited draft' }
            Focus-Lbs205 $script:Action
            Send-Lbs205Key $script:Action ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case Manage Escape hides without saving or dropping draft" (
                -not $form.Visible -and $script:IsManageEntriesMode -and
                ($script:ManageEntryOrder -join ',') -eq 'boot-2,boot-1' -and
                ($script:ManageHiddenEntryGuids -join ',') -eq 'boot-2' -and
                $script:ManageEntryAliases['boot-1'] -eq 'Edited draft' -and $script:SaveCalls -eq 0)

            Show-OrTogglePopup
            [System.Windows.Forms.Application]::DoEvents()
            Assert-Lbs205 "$case reopen keeps Manage draft and mode" (
                $form.Visible -and $script:IsManageEntriesMode -and
                $script:ManageEntryAliases['boot-1'] -eq 'Edited draft')
            Focus-Lbs205 $script:Action
            $script:ManageActiveDragGuid = 'boot-1'
            Send-Lbs205Key $script:Action ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case active drag takes Escape precedence" ($form.Visible)
            $script:ManageActiveDragGuid = $null
            $script:ManageDragLayout = [pscustomobject]@{ Active=$true }
            Send-Lbs205Key $script:Action ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case active drag canvas takes Escape precedence" ($form.Visible)
            $script:ManageDragLayout = $null
            Send-Lbs205Key $script:Action ([System.Windows.Forms.Keys]::Escape)
            Assert-Lbs205 "$case following Escape hides without changing drafts" (
                -not $form.Visible -and $script:ManageEntryAliases['boot-1'] -eq 'Edited draft')

            $noFocusEvent = [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Escape)
            Invoke-PopupEscapeDismissal -Form $form -EventArgs $noFocusEvent
            Assert-Lbs205 "$case invisible popup never handles foreign Escape" (
                -not $noFocusEvent.Handled -and -not $form.Visible)
            Assert-Lbs205 "$case no destructive action on any Escape" (
                $script:SaveCalls -eq 0 -and $script:BootCalls -eq 0 -and
                $script:RestartCalls -eq 0 -and $script:WorkerCancels -eq 0)
        }
        finally {
            $form.Dispose()
            $script:Popup = $null
            $script:DefaultContextMenu = $null
        }
    }
}
Write-Host "LBS205 POPUP ESCAPE TOTAL $script:checks"
