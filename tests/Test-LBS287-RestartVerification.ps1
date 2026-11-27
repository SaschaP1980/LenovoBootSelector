#requires -version 5.1
# LBS-287: actual restart entry, controller, read-only worker and native
# completion timers. Every task call and shutdown dispatch is intercepted.
param([switch]$MismatchProbeOnly)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$controller=Join-Path $root 'src\Application\RestartController.ps1'
if (Test-Path -LiteralPath $controller) { . $controller }
. (Join-Path $root 'src\Core\FirmwareParsing.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Infrastructure\TaskBroker.ps1')
. (Join-Path $root 'src\Infrastructure\BackgroundRefreshWorker.ps1')
. (Join-Path $root 'src\Application\RefreshRuntime.ps1')
. (Join-Path $root 'src\Application\RefreshController.ps1')
. (Join-Path $root 'src\Application\BootNextSelectionController.ps1')
. (Join-Path $root 'src\Application\DefaultTargetChangeController.ps1')
. (Join-Path $root 'src\UI\RefreshPresentation.ps1')
$template=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
$entry=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Restart-Windows'},$true)
if (-not $entry -or @($errors).Count) { throw 'Canonical restart entry point unavailable.' }
. ([scriptblock]::Create($entry.Extent.Text))
$script:A='{aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}'
$script:B='{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}'
$script:C='{cccccccc-cccc-cccc-cccc-cccccccccccc}'
$script:checks=0
$script:TaskBrokerLocalDir=Join-Path ([IO.Path]::GetTempPath()) ('lbs287-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir)
$script:Meta=[pscustomobject]@{
    managerFile=(Join-Path $script:TaskBrokerLocalDir 'fwbootmgr.txt')
    firmwareFile=(Join-Path $script:TaskBrokerLocalDir 'firmware.txt')
    bootNextOriginFile=(Join-Path $script:TaskBrokerLocalDir 'bootnext-origin.json')
    targets=@([pscustomobject]@{guid=$script:A},[pscustomobject]@{guid=$script:B})
}
$script:RestartButton=New-Object Windows.Forms.Button
$script:RestartUseDefaultButton=New-Object Windows.Forms.Button
$script:RestartTargetLabel=New-Object Windows.Forms.Label
$script:RestartMenuItem=New-Object Windows.Forms.ToolStripMenuItem
$script:ScriptPath='mock-runtime.ps1'
$script:RuntimeSessionId='lbs287-native'
$script:BackgroundRefreshState=New-BackgroundRefreshRuntimeState
$script:DefaultGuid=$script:B

function Assert-Lbs287([string]$Name,[bool]$Ok) {
    if (-not $Ok) {
        Write-Host ('LBS287 fixture state: ' + (@{Selected=$script:SelectedGuid;Verified=$script:NextBootFirmwareReadVerified;Confirmations=$script:ConfirmationCalls;Notices=$script:NoticeCalls;NoticeMessage=$script:NoticeMessage;Dispatches=$script:DispatchCalls;Reads=$script:ReadOrder;Events=$script:Events} | ConvertTo-Json -Depth 6 -Compress))
        throw "LBS287_FAIL: $Name"
    }
    $script:checks++
    Write-Host "PASS LBS287 $Name"
}
function Get-CurrentSystemFunctionsCapabilities {
    param([switch]$ProbeReadiness)
    [pscustomobject]@{State=$script:Capability;CanRestart=($script:Capability -eq 'Ready')}
}
function Test-MaintenanceBusy { return [bool]$script:MockMaintenance }
function Get-TaskBrokerMetadata { return $script:Meta }
function Test-TaskBrokerMetadataCompatible { return $true }
function Test-TaskBrokerReady { param([switch]$Force) return [bool]$script:MockReady }
function Get-EntryByGuid { param([string]$Guid) if ($Guid -in @($script:A,$script:B)) { [pscustomobject]@{Guid=$Guid;Title=$Guid} } }
function Get-EntryDisplayTitle { param($Entry) return [string]$Entry.Title }
function Get-LocalizedString {
    param([string]$Key,$Values)
    return (Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values)
}
function Refresh-EffectiveNextBootState { $script:SelectedGuid=$script:Observed; return $script:SelectedGuid }
function Get-NextBootTargetDisplayName { return $script:SelectedGuid }
function Show-LenovoRestartDialog {
    param($TargetName)
    $script:ConfirmationCalls++
    $script:ConfirmedName=$TargetName
    if ($script:ChangeDuringDialog) { $script:SelectedGuid=$script:B }
    if ($script:DuplicateDuringDialog) { Restart-Windows }
    return $script:Choice
}
function Show-LenovoNoticeDialog { param($Title,$Heading,$Message,$Kind) $script:NoticeCalls++;$script:NoticeMessage=$Message }
function Write-RuntimeDiagnosticEvent {
    param($Event,$Stage,$Success,$Data,$Level,$DurationMs,$ErrorRecord)
    $script:Events+= [pscustomobject]@{Event=$Event;Stage=$Stage;Success=$Success;Data=$Data;Error=if ($ErrorRecord) { [string]$ErrorRecord } else { '' }}
    if ($ErrorRecord) { Write-Host ('LBS287 diagnostic failure: ' + [string]$ErrorRecord) }
}
function New-RuntimeDiagnosticData { param($Data) return $Data }
function Update-PopupRows { param($Reason) }
function Update-RestartTargetUi { Update-BootNextRestartInterlock }
function Update-TaskBrokerUiState { param([switch]$Fast) $script:RestartMenuItem.Enabled=-not [bool]$script:RestartVerification; return $true }
function New-Lbs287Process {
    param([bool]$Exited=$false,[int]$ExitCode=0)
    $p=[pscustomobject]@{HasExited=$Exited;ExitCode=$ExitCode;Killed=$false;Disposed=$false}
    $p | Add-Member ScriptMethod Kill { $this.Killed=$true;$this.HasExited=$true }
    $p | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    return $p
}
function Start-BackgroundRefreshWorkerProcess {
    param($ScriptPath,$ResultPath,[bool]$RefreshStorage,[bool]$RefreshFirmware,$RuntimeSessionId,[switch]$VerifyRestart)
    if (-not $VerifyRestart -or $RefreshStorage -or -not $RefreshFirmware) { throw 'Wrong worker admission.' }
    $script:WorkerStarts++
    return (New-Lbs287Process)
}
function Invoke-RestartDispatch {
    if ($script:DispatchThrows) { throw 'Mock dispatch failed.' }
    $script:DispatchCalls++
    return (New-Lbs287Process)
}
function Get-RestartWriterFingerprint {
    $script:WriterReads++
    if ($script:WriterMode -eq 'busy') { throw 'Mock installed writer busy.' }
    $fingerprint=if ($script:WriterMode -eq 'changed') { [string]$script:WriterReads } else { 'idle' }
    [pscustomobject]@{Fingerprint=$fingerprint;Origin=(Get-RestartOriginStamp)}
}
function New-Lbs287ManagerText {
    param([AllowNull()][string]$Guid,[string]$First=$script:A)
    $heading=if ($script:Locale -eq 'de-DE') { 'Firmware-Start-Manager' } else { 'Firmware Boot Manager' }
    $identifier=if ($script:Locale -eq 'de-DE') { 'Bezeichner' } else { 'identifier' }
    $s="$heading"+"<NL>---------------------<NL>$identifier {a5a30fa2-3d06-4e9f-b5f4-a01df9d1fcba}<NL>displayorder $First<NL>"
    if ($First -eq $script:A) { $s+="                        $script:B<NL>" }
    else { $s+="                        $script:A<NL>" }
    if ($Guid) { $s+="bootsequence $Guid<NL>" }
    return ($s+"timeout 1<NL>").Replace('<NL>',[Environment]::NewLine)
}
function New-Lbs287EntriesText {
    $identifier=if ($script:Locale -eq 'de-DE') { 'Bezeichner' } else { 'identifier' }
    $description=if ($script:Locale -eq 'de-DE') { 'Beschreibung' } else { 'description' }
    $s="$identifier $script:A<NL>$description Windows A<NL>"
    if (-not $script:MissingEntry) { $s+="$identifier $script:B<NL>$description Windows B<NL>" }
    return $s.Replace('<NL>',[Environment]::NewLine)
}
function Write-Lbs287Snapshot {
    param($Path,$Text,[bool]$Stale)
    if (-not $Stale) {
        Start-Sleep -Milliseconds 12
        [IO.File]::WriteAllText($Path,$Text,[Text.Encoding]::UTF8)
        [IO.File]::SetLastWriteTimeUtc($Path,[datetime]::UtcNow)
    }
    return [IO.File]::ReadAllText($Path)
}
function Get-TaskBrokerFirmwareEntriesText {
    param([switch]$Force)
    if (-not $Force) { throw 'Entries cache used.' }
    $script:ReadOrder+='entries'
    $text=Write-Lbs287Snapshot -Path $script:Meta.firmwareFile -Text (New-Lbs287EntriesText) -Stale $false
    $script:SystemStatusEntriesObservedHash=Get-SystemStatusObservationHash $text
    $script:SystemStatusEntriesObservedUtc=[datetime]::UtcNow
    return $text
}
function Get-TaskBrokerFirmwareManagerText {
    param([switch]$Force)
    if (-not $Force) { throw 'Manager cache used.' }
    $script:ReadOrder+='manager'
    if ($script:ReadThrows) { throw 'Mock manager read failed.' }
    $text=if ($script:RawManager) { $script:RawManager } else { New-Lbs287ManagerText -Guid $script:Observed -First $script:FirstOrder }
    $text=Write-Lbs287Snapshot -Path $script:Meta.managerFile -Text $text -Stale $script:Stale
    $script:SystemStatusManagerObservedHash=Get-SystemStatusObservationHash $text
    $script:SystemStatusManagerObservedUtc=[datetime]::UtcNow
    return $text
}
function Complete-Lbs287Readback {
    $ctx=$script:RestartVerification
    if (-not $ctx) { throw 'No restart verification pending.' }
    $code=Invoke-BackgroundRefreshWorker -RefreshStorage $false -RefreshFirmware $true -ResultPath $ctx.ResultPath -VerifyRestart
    $ctx.Process.ExitCode=$code
    $ctx.Process.HasExited=$true
    if ($script:TamperSnapshot) {
        [IO.File]::WriteAllText($script:Meta.managerFile,(New-Lbs287ManagerText -Guid $script:B))
    }
    if ($script:TamperOrigin) {
        [IO.File]::WriteAllText($script:Meta.bootNextOriginFile,'changed after worker')
    }
    Complete-RestartVerification
}
function Reset-Lbs287 {
    if ($script:RestartVerification) { Stop-RestartVerification -Shutdown }
    $script:SelectedGuid=$script:A
    $script:Expected=$script:A
    $script:Observed=$script:A
    $script:FirstOrder=$script:A
    $script:NextBootFirmwareReadVerified=$true
    $script:BootNextPendingGuid=$null
    $script:DefaultTargetChangePending=$false
    $script:RestartVerification=$null
    $script:IsManageEntriesMode=$false
    $script:PreferencesUiActive=$false
    $script:ActiveOwnedDialog=$null
    $script:ActiveAuxiliaryPopup=$null
    $script:ExitRequested=$false
    $script:TaskBrokerInstallInProgress=$false
    $script:TaskBrokerRemoveInProgress=$false
    $script:BackgroundRefreshState=New-BackgroundRefreshRuntimeState
    $script:Capability='Ready'
    $script:MockReady=$true
    $script:MockMaintenance=$false
    $script:ConfirmationCalls=0
    $script:NoticeCalls=0
    $script:DispatchCalls=0
    $script:WorkerStarts=0
    $script:WriterReads=0
    $script:ReadOrder=@()
    $script:Events=@()
    $script:Choice=[Windows.Forms.DialogResult]::No
    $script:ConfirmedName=''
    $script:NoticeMessage=''
    $script:WriterMode='idle'
    $script:ReadThrows=$false
    $script:RawManager=$null
    $script:Stale=$false
    $script:MissingEntry=$false
    $script:TamperSnapshot=$false
    $script:TamperOrigin=$false
    $script:ChangeDuringDialog=$false
    $script:DuplicateDuringDialog=$false
    $script:DispatchThrows=$false
    $script:RestartButton.Enabled=$true
    $script:RestartMenuItem.Enabled=$true
    [IO.File]::WriteAllText($script:Meta.managerFile,(New-Lbs287ManagerText -Guid $script:A))
    [IO.File]::WriteAllText($script:Meta.firmwareFile,(New-Lbs287EntriesText))
    [IO.File]::WriteAllText($script:Meta.bootNextOriginFile,'stable-provenance')
}
function Invoke-Lbs287MismatchProbe {
    Reset-Lbs287
    $script:Observed=$script:B
    Restart-Windows
    if ($script:RestartVerification) { Complete-Lbs287Readback }
    Assert-Lbs287 'pre-confirmation mismatch blocks without retargeting the confirmation' ($script:ConfirmationCalls -eq 0 -and $script:DispatchCalls -eq 0 -and $script:NoticeCalls -eq 1)
}
function Test-Lbs287Blocked {
    param([string]$Name,[int]$Confirmations)
    Assert-Lbs287 $Name ($script:ConfirmationCalls -eq $Confirmations -and $script:DispatchCalls -eq 0 -and -not $script:RestartVerification -and $script:NoticeCalls -eq 1)
}
try {
    $script:Locale='en-US'
    Invoke-Lbs287MismatchProbe
    if ($MismatchProbeOnly) { Write-Host 'LBS287 MISMATCH TOTAL 1/1';return }
    Assert-Lbs287 'mismatch reflects observed B without dispatch or default mutation' ($script:SelectedGuid -eq $script:B -and $script:DefaultGuid -eq $script:B -and $script:NextBootFirmwareReadVerified)
    foreach ($locale in @('de-DE','en-US')) {
        $script:Locale=$locale
        Reset-Lbs287
        $valid=ConvertFrom-RestartFirmwareEvidence (New-Lbs287ManagerText -Guid $script:A.ToUpperInvariant())
        Assert-Lbs287 "$locale canonical GUID and full order parsed" ($valid.SelectedGuid -eq $script:A -and $valid.ExplicitTarget -and $valid.DisplayOrder.Count -eq 2)
        $absent=ConvertFrom-RestartFirmwareEvidence (New-Lbs287ManagerText -Guid $null)
        Assert-Lbs287 "$locale valid absence distinguished from unknown" (-not $absent.ExplicitTarget -and -not $absent.SelectedGuid)
        foreach ($raw in @('', 'Access denied', (New-Lbs287ManagerText -Guid 'invalid'), ((New-Lbs287ManagerText -Guid $script:A).Replace('timeout 1','')), ((New-Lbs287ManagerText -Guid $script:A).Replace('timeout 1',"bootsequence $script:B<NL>timeout 1".Replace('<NL>',[Environment]::NewLine))), ((New-Lbs287ManagerText -Guid $script:A).Replace('timeout 1',"   $script:B<NL>timeout 1".Replace('<NL>',[Environment]::NewLine))), ((New-Lbs287ManagerText -Guid $script:A).Replace('{a5a30fa2-3d06-4e9f-b5f4-a01df9d1fcba}',$script:B)))) {
            $failed=$false;try { [void](ConvertFrom-RestartFirmwareEvidence $raw) } catch { $failed=$true }
            Assert-Lbs287 "$locale malformed/ambiguous record rejected" $failed
        }
        Reset-Lbs287
        $script:Choice=[Windows.Forms.DialogResult]::Yes
        $script:DuplicateDuringDialog=$true
        Restart-Windows
        $ctx=$script:RestartVerification
        Assert-Lbs287 "$locale async admission and native timer, no premature confirmation" ($ctx -and $ctx.Timer -is [Windows.Forms.Timer] -and $ctx.Timer.Enabled -and $script:ConfirmationCalls -eq 0 -and -not $script:RestartButton.Enabled -and -not $script:RestartMenuItem.Enabled)
        Complete-RestartVerification
        Restart-Windows
        Start-BootNextSelection -Guid $script:B
        Start-DefaultTargetChange -Guid $script:B
        Start-BackgroundBootRefresh -Origin Manual
        Assert-Lbs287 "$locale duplicate and competing LBS actions rejected" ($script:WorkerStarts -eq 1 -and $script:DispatchCalls -eq 0 -and -not $script:BootNextPendingGuid -and -not $script:DefaultTargetChangePending -and -not $script:BackgroundRefreshState.Process)
        Complete-Lbs287Readback
        Assert-Lbs287 "$locale affirmative confirmation starts independent second read" ($script:ConfirmationCalls -eq 1 -and $script:ConfirmedName -eq $script:A -and $script:WorkerStarts -eq 2 -and $script:RestartVerification.Stage -eq 'post-confirmation' -and $script:DispatchCalls -eq 0)
        Complete-Lbs287Readback
        Assert-Lbs287 "$locale two forced entries/manager reads then exactly one dispatch" ($script:DispatchCalls -eq 1 -and ($script:ReadOrder -join ',') -eq 'entries,manager,entries,manager' -and $script:RestartVerification.Stage -eq 'dispatching' -and $script:DefaultGuid -eq $script:B)
        $matches=@($script:Events | Where-Object { $_.Event -eq 'RESTART_VERIFICATION' -and $_.Data.outcome -eq 'match' })
        Assert-Lbs287 "$locale diagnostics correlate both verified phases and intended GUID" ($matches.Count -eq 2 -and $matches[0].Data.requestId -eq $matches[1].Data.requestId -and $matches[1].Data.expectedGuid -eq $script:A -and $matches[1].Data.observedGuid -eq $script:A)
        $script:RestartVerification.Process.HasExited=$true
        Complete-RestartVerification
        Restart-Windows
        Assert-Lbs287 "$locale accepted restart request retains admission without duplicate dispatch" ($script:RestartVerification.Stage -eq 'requested' -and $script:DispatchCalls -eq 1)
        $script:RestartVerification.DispatchUtc=[datetime]::UtcNow.AddSeconds(-31)
        Complete-RestartVerification
        Assert-Lbs287 "$locale uncertain restart outcome releases bounded admission" (-not $script:RestartVerification -and $script:NoticeCalls -eq 1 -and $script:RestartButton.Enabled)
        Reset-Lbs287
        Restart-Windows;Complete-Lbs287Readback
        Assert-Lbs287 "$locale No/Escape result cancels before second read" ($script:ConfirmationCalls -eq 1 -and $script:WorkerStarts -eq 1 -and $script:DispatchCalls -eq 0 -and -not $script:RestartVerification)
        foreach ($case in @('mismatch','absent','stale','malformed','multiple','worker-error','writer-busy','writer-changed','snapshot-changed','origin-changed','missing-entry')) {
            Reset-Lbs287
            $script:Choice=[Windows.Forms.DialogResult]::Yes
            Restart-Windows;Complete-Lbs287Readback
            switch ($case) {
                'mismatch' { $script:Observed=$script:B }
                'absent' { $script:Observed=$null }
                'stale' { $script:Stale=$true }
                'malformed' { $script:RawManager='Access denied' }
                'multiple' { $script:RawManager=(New-Lbs287ManagerText -Guid $script:A).Replace('timeout 1',"   $script:B<NL>timeout 1".Replace('<NL>',[Environment]::NewLine)) }
                'worker-error' { $script:ReadThrows=$true }
                'writer-busy' { $script:WriterMode='busy' }
                'writer-changed' { $script:WriterMode='changed' }
                'snapshot-changed' { $script:TamperSnapshot=$true }
                'origin-changed' { $script:TamperOrigin=$true }
                'missing-entry' { $script:Observed=$script:B;$script:MissingEntry=$true }
            }
            Complete-Lbs287Readback
            Test-Lbs287Blocked "$locale final $case blocks dispatch and releases admission" 1
        }
        Reset-Lbs287
        $script:SelectedGuid=$null;$script:Observed=$null
        $script:Choice=[Windows.Forms.DialogResult]::Yes
        Restart-Windows;Complete-Lbs287Readback;Complete-Lbs287Readback
        Assert-Lbs287 "$locale valid absent BootNext permits deliberate normal-order restart" ($script:DispatchCalls -eq 1 -and $script:ConfirmedName -eq (Get-LocalizedString -Key 'Boot.DefaultOrder'))
        Reset-Lbs287
        $script:SelectedGuid=$null;$script:Observed=$null;$script:Choice=[Windows.Forms.DialogResult]::Yes
        Restart-Windows;Complete-Lbs287Readback
        $script:FirstOrder=$script:B;Complete-Lbs287Readback
        Test-Lbs287Blocked "$locale changed firmware order invalidates absence confirmation" 1
        Reset-Lbs287
        $script:SelectedGuid=$null;$script:Observed=$script:A
        Restart-Windows;Complete-Lbs287Readback
        Test-Lbs287Blocked "$locale absent intent vs new explicit target rejected" 0
        Reset-Lbs287
        $script:NextBootFirmwareReadVerified=$false
        Restart-Windows
        Assert-Lbs287 "$locale unknown intent does not launch worker" ($script:WorkerStarts -eq 0 -and $script:NoticeCalls -eq 1 -and $script:DispatchCalls -eq 0)
        Reset-Lbs287
        $script:SelectedGuid=$script:C
        Restart-Windows
        Assert-Lbs287 "$locale unavailable or unallowlisted intent rejected" ($script:WorkerStarts -eq 0 -and $script:NoticeCalls -eq 1)
        Reset-Lbs287
        $script:MockMaintenance=$true
        Restart-Windows
        Assert-Lbs287 "$locale maintenance prevents restart admission" ($script:WorkerStarts -eq 0 -and $script:NoticeCalls -eq 1)
        Reset-Lbs287
        $script:BackgroundRefreshState.Process=New-Lbs287Process
        Restart-Windows
        Assert-Lbs287 "$locale active refresh prevents restart admission" ($script:WorkerStarts -eq 0 -and $script:NoticeCalls -eq 1)
        Reset-Lbs287
        $script:BootNextPendingGuid=$script:B;Restart-Windows
        $script:BootNextPendingGuid=$null;$script:DefaultTargetChangePending=$true;Restart-Windows
        Assert-Lbs287 "$locale pending BootNext/default guards remain before worker" ($script:WorkerStarts -eq 0 -and $script:DispatchCalls -eq 0)
        Reset-Lbs287
        $script:Choice=[Windows.Forms.DialogResult]::Yes;$script:ChangeDuringDialog=$true
        Restart-Windows;Complete-Lbs287Readback
        Test-Lbs287Blocked "$locale changed intent during dialog blocks second phase" 1
        Reset-Lbs287
        Restart-Windows;$p=$script:RestartVerification.Process
        $script:RestartVerification.StartedUtc=[datetime]::UtcNow.AddSeconds(-46)
        Complete-RestartVerification
        Assert-Lbs287 "$locale bounded timeout retires read-only child without dispatch" ($p.Killed -and $p.Disposed -and -not $script:RestartVerification -and $script:DispatchCalls -eq 0)
        Reset-Lbs287
        $script:Choice=[Windows.Forms.DialogResult]::Yes;$script:DispatchThrows=$true
        Restart-Windows;Complete-Lbs287Readback;Complete-Lbs287Readback
        Test-Lbs287Blocked "$locale restart launch failure does not retry" 1
        Reset-Lbs287
        $script:Choice=[Windows.Forms.DialogResult]::Yes
        Restart-Windows;Complete-Lbs287Readback;Complete-Lbs287Readback
        $script:RestartVerification.Process.ExitCode=5;$script:RestartVerification.Process.HasExited=$true
        Complete-RestartVerification
        Assert-Lbs287 "$locale nonzero shutdown exit is a failure, not boot success" ($script:DispatchCalls -eq 1 -and $script:NoticeCalls -eq 1 -and -not $script:RestartVerification -and @($script:Events | Where-Object {$_.Event -eq 'RESTART_REQUEST' -and $_.Success -eq $false}).Count -eq 1)
    }
    Write-Host "LBS287 RESTART TOTAL $script:checks/82"
    if ($script:checks -ne 82) { throw "Unexpected LBS287 total: $script:checks" }
}
finally {
    if ($script:RestartVerification) { Stop-RestartVerification -Shutdown }
    $script:RestartButton.Dispose();$script:RestartUseDefaultButton.Dispose()
    $script:RestartTargetLabel.Dispose();$script:RestartMenuItem.Dispose()
    Remove-Item -LiteralPath $script:TaskBrokerLocalDir -Recurse -Force -ErrorAction SilentlyContinue
}
