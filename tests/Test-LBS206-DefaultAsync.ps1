#requires -version 5.1
# LBS-206: true asynchronous permanent-default selection, not a cosmetic spinner.
# Real WinForms controls and mocked UNELEVATED child; no firmware/SYSTEM mutation.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$controller = Join-Path $root 'src\Application\DefaultTargetChangeController.ps1'
$worker = Join-Path $root 'src\Infrastructure\DefaultTargetChangeWorker.ps1'
function Assert-Lbs206Default([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS206_DEFAULT_ASYNC_RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS206_DEFAULT $Name"
}
$script:checks = 0
Assert-Lbs206Default 'dedicated nonblocking default-target controller exists' (Test-Path -LiteralPath $controller)
Assert-Lbs206Default 'dedicated guarded default-target worker exists' (Test-Path -LiteralPath $worker)
. $controller
. $worker
. (Join-Path $root 'src\UI\DefaultTargetPresentation.ps1')
$source = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$menu = [IO.File]::ReadAllText((Join-Path $root 'src\UI\DefaultTargetMenu.ps1'))
Assert-Lbs206Default 'menu choices enqueue an async default change' (
    $menu.Contains('Start-DefaultTargetChange -Guid ([string]$this.Tag)') -and
    $menu.Contains('Start-DefaultTargetChange -Guid $null') -and
    -not $menu.Contains('try { Set-DefaultGuid -Guid'))
Assert-Lbs206Default 'default worker skips tray mutex and has isolated CLI entry' (
    $source.Contains('-DefaultTargetWorker') -and
    $source.Contains('if ($DefaultTargetWorker) {') -and
    $source.Contains('Invoke-DefaultTargetWorker'))
Assert-Lbs206Default 'existing allowlisted persistence writer is reused inside worker' (
    ([IO.File]::ReadAllText($worker)).Contains('Set-DefaultGuid -Guid'))
Assert-Lbs206Default 'pending blocks restart and BootNext paths before confirmation' (
    $source.Contains('if ($script:DefaultTargetChangePending) { return }') -and
    $source.Contains('function Restart-Windows {') -and
    ([IO.File]::ReadAllText((Join-Path $root 'src\Application\BootNextSelectionController.ps1'))).Contains('DefaultTargetChangePending'))
Assert-Lbs206Default 'pending, verifying and partial-readback labels localized DE/EN' (
    ([IO.File]::ReadAllText((Join-Path $root 'src\Core\Localization.ps1')) -split "'Default.ChangeSaving' =").Count -eq 3 -and
    ([IO.File]::ReadAllText((Join-Path $root 'src\Core\Localization.ps1')) -split "'Default.ChangeVerifying' =").Count -eq 3 -and
    ([IO.File]::ReadAllText((Join-Path $root 'src\Core\Localization.ps1')) -split "'Default.ChangePartial' =").Count -eq 3)

# The menu click must not block the WinForms message pump with a SYSTEM task.
Assert-Lbs206Default 'worker runs without the main tray single-instance mutex' (
    $source.Contains('-not $DefaultTargetWorker') -and
    $source.Contains('-or $DefaultTargetWorker'))
Assert-Lbs206Default 'worker writes verification stage after the allowlisted task' (
    $source.Contains('Set-TaskBrokerDefaultTarget -Guid $normalized') -and
    $source.Contains('WriteAllText($ProgressPath') -and
    $source.Contains('Clear-TaskBrokerDefaultTarget'))
$script:DefaultGuid = '{11111111-1111-1111-1111-111111111111}'
$script:Requested = '{22222222-2222-2222-2222-222222222222}'
$script:SelectedGuid = $script:DefaultGuid
$script:NextBootFirmwareReadVerified = $true
$script:DefaultTargetChangePending = $false
$script:DefaultTargetChangeProcess = $null
$script:DefaultTargetChangeTimer = $null
$script:DefaultTargetChangeStage = ''
$script:BootNextPendingGuid = $null
$script:IsManageEntriesMode = $false
$script:TaskBrokerLocalDir = Join-Path ([IO.Path]::GetTempPath()) ('lbs206-default-' + [guid]::NewGuid().ToString('N'))
$script:ScriptPath = 'mock-runtime.ps1'
$script:RuntimeSessionId = 'test-session'
$script:ColorWarning = [Drawing.Color]::FromArgb(247,179,43)
$script:ColorPrimary = [Drawing.Color]::FromArgb(252,252,252)
$script:ColorSecondary = [Drawing.Color]::FromArgb(184,184,184)
$script:ColorSurface = [Drawing.Color]::FromArgb(25,25,25)
$script:MockWorkerCalls = 0
$script:MockNotices = 0
$script:MockRestartCalls = 0
$script:MockRows = 0
$script:MockStatus = ''
$script:MockSavedGuid = $script:DefaultGuid
$script:DefaultButton = New-Object Windows.Forms.Panel
$script:DefaultValueLabel = New-Object Windows.Forms.Label
$script:DefaultArrowLabel = New-Object Windows.Forms.Label
$script:DefaultButton.Controls.Add($script:DefaultValueLabel)
$script:DefaultButton.Controls.Add($script:DefaultArrowLabel)
$script:RestartButton = New-Object Windows.Forms.Button
$script:RestartUseDefaultButton = New-Object Windows.Forms.Button
$script:RestartTargetLabel = New-Object Windows.Forms.Label
$script:BootTypeToolTip = New-Object Windows.Forms.ToolTip
$script:Popup = $null
$script:LastStatusText = ''
$script:BackgroundRefreshState = $null
function Get-EntryByGuid { param([string]$Guid) if ($Guid) { return [pscustomobject]@{Guid=$Guid; Title= $(if($Guid -eq $script:Requested){'Lenovo Boot-Menü'}else{'Windows: Corporate'})} }; return $null }
function Get-EntryDisplayTitle { param($Entry) return [string]$Entry.Title }
function Get-LocalizedString { param([string]$Key,$Values)
    switch ($Key) {
        'Default.ChangeSaving' { return 'Standardziel wird gespeichert …' }
        'Default.ChangeVerifying' { return 'Standardziel wird überprüft …' }
        'Default.ChangeSavingFooter' { return ('Speichern: ' + [string]$Values.Target) }
        'Default.ChangeVerifyingFooter' { return ('Prüfen: ' + [string]$Values.Target) }
        'Default.ChangePartial' { return 'Standardziel gesetzt, nächster Start ungeprüft' }
        'Default.SystemSavedStatus' { return 'Standard gespeichert' }
        default { return $Key }
    }
}
function Get-CurrentSystemFunctionsCapabilities {
    param([switch]$ProbeReadiness)
    return [pscustomobject]@{State='Ready';CanSetDefaultTarget=$true;CanUseDefaultTarget=$true;CanRestart=$true;CanSetBootNext=$true;IsChecking=$false}
}
function Get-TaskBrokerTarget { param([string]$Guid) if ($Guid -eq $script:Requested) { return [pscustomobject]@{Guid=$Guid} };return $null }
function Normalize-TaskBrokerGuid { param([string]$Guid) if ($Guid) { return $Guid.ToLowerInvariant() }; return $null }
function Get-TaskBrokerDefaultTargetGuid { return $script:MockSavedGuid }
function Get-TaskBrokerMetadata { return [pscustomobject]@{
    managerFile=(Join-Path $script:TaskBrokerLocalDir 'manager.txt')
    defaultFile=(Join-Path $script:TaskBrokerLocalDir 'default-guid.txt')
} }
function Read-TaskBrokerTextFile { param([string]$Path) return [IO.File]::ReadAllText($Path) }
function ConvertFrom-FirmwareManagerText { param([string]$Text) return [pscustomobject]@{SelectedGuid=$Text.Trim()} }
function Test-MaintenanceBusy { return $false }
function Test-BootTargetDriftDetected { return $false }
function Stop-BackgroundBootRefreshForMaintenance { param([string]$Reason) }
function Remove-BackgroundRefreshResultFile { param([string]$Path) if ($Path -and (Test-Path $Path)) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } }
function Update-PopupRows { $script:MockRows++ }
function Update-RestartTargetUi { $script:MockStatus = if ($script:DefaultTargetChangePending){$script:DefaultTargetChangeStage}else{'ready'}; Update-BootNextRestartInterlock }
function Update-BootNextRestartInterlock {
    $script:RestartButton.Enabled = -not ($script:BootNextPendingGuid -or $script:DefaultTargetChangePending)
    $script:RestartUseDefaultButton.Enabled = $script:RestartButton.Enabled
}
function New-RuntimeDiagnosticData { param($Data) return $Data }
function Write-RuntimeDiagnosticEvent { param($Event,$Stage,$Success,$DurationMs,$Data,$Level,$ErrorRecord) }
function Show-LenovoNoticeDialog { param($Title,$Heading,$Message,$Kind) $script:MockNotices++ }
function Start-DefaultTargetWorkerProcess {
    param($ScriptPath,$Guid,$Clear,$ResultPath,$ProgressPath,$RuntimeSessionId)
    $script:MockWorkerCalls++
    $p=[pscustomobject]@{Id=9876;HasExited=$false;ExitCode=0}
    $p | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }
    $p | Add-Member -MemberType ScriptMethod -Name Kill -Value { $this.HasExited=$true }
    $p | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($timeout) return $true }
    $p | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    return $p
}
try {
    Start-DefaultTargetChange -Guid $script:Requested
    Assert-Lbs206Default 'acceptance immediately records pending request without starting a task' (
        $script:DefaultTargetChangePending -and $script:DefaultTargetChangeRequestedGuid -eq $script:Requested -and $script:MockWorkerCalls -eq 0)
    Assert-Lbs206Default 'UI immediately shows amber pending and independently disables restart' (
        $script:DefaultValueLabel.Text -match '(?i)(speicher|saving)' -and
        $script:DefaultValueLabel.ForeColor.ToArgb() -eq $script:ColorWarning.ToArgb() -and
        -not $script:RestartButton.Enabled)
    Assert-Lbs206Default 'saving hides the separate redundant ellipsis without losing status text' (
        -not $script:DefaultArrowLabel.Visible -and $script:DefaultArrowLabel.Text -eq '›' -and
        $script:DefaultValueLabel.Text -match '(?i)(speicher|saving)')
    Assert-Lbs206Default 'requested pending never overwrites last verified default' ($script:DefaultGuid -ne $script:Requested)
    Start-DefaultTargetChange -Guid $script:DefaultGuid
    Assert-Lbs206Default 'rapid second click cannot replace the pending request' ($script:DefaultTargetChangeRequestedGuid -eq $script:Requested -and $script:MockWorkerCalls -eq 0)
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'first timer tick starts exactly one child after UI painted' ($script:MockWorkerCalls -eq 1 -and $script:DefaultTargetChangePending)
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'repeated timer tick does not duplicate privileged request' ($script:MockWorkerCalls -eq 1)
    [IO.File]::WriteAllText($script:DefaultTargetChangeProgressPath,'verifying')
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'worker progress switches to verification without claiming saved state' ($script:DefaultTargetChangeStage -eq 'verifying' -and $script:DefaultGuid -ne $script:Requested)
    Assert-Lbs206Default 'verifying hides the separate redundant ellipsis without losing status text' (
        -not $script:DefaultArrowLabel.Visible -and $script:DefaultArrowLabel.Text -eq '›' -and
        $script:DefaultValueLabel.Text -match '(?i)(prüf|verif|überprüf)')
    $script:MockSavedGuid=$script:Requested
    [IO.File]::WriteAllText((Join-Path $script:TaskBrokerLocalDir 'manager.txt'),$script:Requested)
    $good=[ordered]@{Success=$true;Operation='set';RequestedGuid=$script:Requested;SavedGuid=$script:Requested;NextGuid=$script:Requested;NextVerified=$true;Error=''}
    [IO.File]::WriteAllText($script:DefaultTargetChangeResultPath,($good | ConvertTo-Json -Compress))
    $script:DefaultTargetChangeProcess.HasExited=$true
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'success only after independent stored default and next boot readback' (
        -not $script:DefaultTargetChangePending -and $script:DefaultGuid -eq $script:Requested -and
        $script:SelectedGuid -eq $script:Requested -and $script:NextBootFirmwareReadVerified)
    Assert-Lbs206Default 'successful completion clears amber state and restores restart' (
        $script:DefaultValueLabel.ForeColor.ToArgb() -ne $script:ColorWarning.ToArgb() -and $script:RestartButton.Enabled)
    Assert-Lbs206Default 'normal selection chevron returns when save is fully verified' (
        $script:DefaultArrowLabel.Visible -and $script:DefaultArrowLabel.Text -eq '›')
    $script:DefaultGuid='{11111111-1111-1111-1111-111111111111}'
    $script:MockSavedGuid=$script:DefaultGuid
    Start-DefaultTargetChange -Guid $script:Requested
    Complete-DefaultTargetChange
    $bad=[ordered]@{Success=$false;Operation='set';RequestedGuid=$script:Requested;SavedGuid='';NextGuid='';NextVerified=$false;Error='mock task failure'}
    [IO.File]::WriteAllText($script:DefaultTargetChangeResultPath,($bad | ConvertTo-Json -Compress))
    $script:DefaultTargetChangeProcess.HasExited=$true
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'failed worker retains verified old default and reports failure' (
        -not $script:DefaultTargetChangePending -and $script:DefaultGuid -eq $script:MockSavedGuid -and $script:MockNotices -gt 0)
    Start-DefaultTargetChange -Guid $script:Requested
    Complete-DefaultTargetChange
    $script:MockSavedGuid=$script:Requested
    [IO.File]::WriteAllText($script:DefaultTargetChangeResultPath,($good | ConvertTo-Json -Compress))
    $script:DefaultTargetChangeProcess.HasExited=$true
    $good.NextVerified=$false
    [IO.File]::WriteAllText($script:DefaultTargetChangeResultPath,($good | ConvertTo-Json -Compress))
    $notices=$script:MockNotices
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'verified persistence with unavailable next-boot readback stays partial' (
        -not $script:DefaultTargetChangePending -and $script:DefaultGuid -eq $script:Requested -and
        -not $script:NextBootFirmwareReadVerified -and $script:MockNotices -gt $notices)
    $script:DefaultGuid='{11111111-1111-1111-1111-111111111111}'
    $script:MockSavedGuid=$script:DefaultGuid
    Start-DefaultTargetChange -Guid $script:Requested
    Complete-DefaultTargetChange
    $script:DefaultTargetChangeStartedUtc=[datetime]::UtcNow.AddSeconds(-90)
    $old=$script:MockNotices
    Complete-DefaultTargetChange
    Assert-Lbs206Default 'worker timeout cancels pending and surfaces a warning' (
        -not $script:DefaultTargetChangePending -and $script:MockNotices -gt $old)

    # Exercise the REAL unelevated worker body with a mocked original writer:
    # no scheduled task, privileged operation or firmware state is touched.
    $script:MockPersistenceMode = 'success'
    function Set-DefaultGuid {
        param([AllowNull()][string]$Guid,[AllowNull()][string]$ProgressPath)
        if ($script:MockPersistenceMode -eq 'throw') { throw 'mock authorized task rejected' }
        $script:DefaultGuid = $Guid
        $script:SelectedGuid = $Guid
        $script:NextBootFirmwareReadVerified = ($script:MockPersistenceMode -ne 'partial')
        if ($ProgressPath) { [IO.File]::WriteAllText($ProgressPath,'verifying') }
    }
    $workerPath=Join-Path $script:TaskBrokerLocalDir 'standalone-worker.json'
    $progressPath=Join-Path $script:TaskBrokerLocalDir 'standalone-worker.progress'
    $script:MockPersistenceMode = 'success'
    $code=Invoke-DefaultTargetWorker -Guid $script:Requested -Clear $false -ResultPath $workerPath -ProgressPath $progressPath
    $result=[IO.File]::ReadAllText($workerPath) | ConvertFrom-Json
    Assert-Lbs206Default 'real worker confirms result only after mocked verified persistence' (
        $code -eq 0 -and $result.Success -and $result.Operation -eq 'set' -and
        $result.SavedGuid -eq $script:Requested -and $result.NextVerified -and
        [IO.File]::ReadAllText($progressPath) -eq 'verifying')
    $script:MockPersistenceMode = 'partial'
    $code=Invoke-DefaultTargetWorker -Guid $script:Requested -Clear $false -ResultPath $workerPath -ProgressPath $progressPath
    $result=[IO.File]::ReadAllText($workerPath) | ConvertFrom-Json
    Assert-Lbs206Default 'worker marks next boot unverified rather than falsely confirmed' (
        $code -eq 0 -and $result.Success -and -not $result.NextVerified)
    $script:MockPersistenceMode = 'throw'
    $code=Invoke-DefaultTargetWorker -Guid $script:Requested -Clear $false -ResultPath $workerPath -ProgressPath $progressPath
    $result=[IO.File]::ReadAllText($workerPath) | ConvertFrom-Json
    Assert-Lbs206Default 'worker fails closed on mocked privileged task error' (
        $code -ne 0 -and -not $result.Success -and $result.Error -match 'mock authorized task rejected')
    $script:MockPersistenceMode = 'success'
    $code=Invoke-DefaultTargetWorker -Guid $null -Clear $true -ResultPath $workerPath -ProgressPath $progressPath
    $result=[IO.File]::ReadAllText($workerPath) | ConvertFrom-Json
    Assert-Lbs206Default 'worker clear uses exact empty target and only reports observed null state' (
        $code -eq 0 -and $result.Success -and $result.Operation -eq 'clear' -and
        -not $result.RequestedGuid -and -not $result.SavedGuid)
}
finally {
    Stop-DefaultTargetChangeWorker -Reason 'fixture-cleanup'
    foreach($control in @($script:DefaultButton,$script:RestartButton,$script:RestartUseDefaultButton,$script:RestartTargetLabel,$script:BootTypeToolTip)){
        if($control){$control.Dispose()}
    }
    if(Test-Path $script:TaskBrokerLocalDir){Remove-Item $script:TaskBrokerLocalDir -Recurse -Force -ErrorAction SilentlyContinue}
}
Write-Host "LBS206 DEFAULT ASYNC TOTAL $script:checks"
