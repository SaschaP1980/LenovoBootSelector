$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Core\FirmwareParsing.ps1')
. (Join-Path $root 'src\Core\BootTargetDrift.ps1')
. (Join-Path $root 'src\Application\BootTargetDrift.ps1')

$checks = 0
function Pass([string]$Name) { $script:checks++; Write-Host "PASS  $Name" }
function Assert-True([bool]$Condition,[string]$Name) { if (-not $Condition) { throw "${Name}: expected true" }; Pass $Name }
function Assert-False([bool]$Condition,[string]$Name) { if ($Condition) { throw "${Name}: expected false" }; Pass $Name }
function Assert-Equal($Expected,$Actual,[string]$Name) { if ([string]$Expected -ne [string]$Actual) { throw "${Name}: '$Actual' != '$Expected'" }; Pass $Name }

$gBoot='{11111111-1111-1111-1111-111111111111}'
$gA='{aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}'
$gB='{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}'
$gC='{cccccccc-cccc-cccc-cccc-cccccccccccc}'
$desc=@{$gBoot='Boot Menu';$gA='NVMe0';$gB='USB HDD';$gC='NVMe1'}
$installed=@([pscustomobject]@{guid=$gBoot},[pscustomobject]@{guid=$gA},[pscustomobject]@{guid=$gB})

$d=Compare-BootTargetDriftCore -InstalledTargets $installed -Descriptions $desc -DisplayOrder @($gA,$gB)
Assert-False $d.HasDrift 'Equal target set has no drift'
Assert-Equal 3 $d.CurrentGuids.Count 'Boot Menu plus display order forms current set'

$d=Compare-BootTargetDriftCore -InstalledTargets $installed -Descriptions $desc -DisplayOrder @($gA,$gB,$gC)
Assert-True $d.HasDrift 'Added firmware target creates drift'
Assert-True $d.HasNewTargets 'Added firmware target is classified as new target'
Assert-Equal $gC $d.AddedGuids[0] 'Added GUID is reported'

$d=Compare-BootTargetDriftCore -InstalledTargets $installed -Descriptions $desc -DisplayOrder @($gA)
Assert-True $d.HasDrift 'Removed firmware target creates drift'
Assert-False $d.HasNewTargets 'Removal-only drift is not classified as new target'
Assert-Equal $gB $d.RemovedGuids[0] 'Removed GUID is reported'

$state=New-BootTargetDriftRuntimeState
Assert-False (Test-BootTargetDriftRuntimeDetected -State $state) 'Initial drift state is clear'
$d=Compare-BootTargetDriftCore -InstalledTargets $installed -Descriptions $desc -DisplayOrder @($gA,$gB,$gC)
[void](Set-BootTargetDriftRuntimeState -State $state -Drift $d)
Assert-True (Test-BootTargetDriftRuntimeDetected -State $state) 'Runtime state records detected drift'
Assert-True (Test-BootTargetDriftRuntimeHasNewTargets -State $state) 'Runtime state records new target'
[void](Set-BootTargetDriftNotificationShown -State $state)
Assert-True $state.NotificationShown 'Drift notification can be marked shown'
[void](Clear-BootTargetDriftRuntimeState -State $state)
Assert-False (Test-BootTargetDriftRuntimeDetected -State $state) 'Clear resets drift state'

Write-Host "DRIFT TOTAL $checks/13"
if ($checks -ne 13) { exit 1 }
