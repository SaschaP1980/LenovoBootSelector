#requires -version 5.1
# LBS-143 focused pure decision matrix, with zero privileged operations.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\BootNextOwnership.ps1')
$checks = 0
function Assert-Decision([string]$Name, [string]$Expected, $Actual) {
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=$Expected actual=$Actual" }
    $script:checks++
    Write-Host "PASS $Name"
}
$a = '{11111111-1111-1111-1111-111111111111}'
$b = '{22222222-2222-2222-2222-222222222222}'
$c = '{33333333-3333-3333-3333-333333333333}'
$boot = '638964033000000000'
$params = @{
    PreviousDefaultGuid = $a; NewDefaultGuid = $b; EffectiveNextGuid = $a
    OriginGuid = $a; OriginBootId = $boot; CurrentBootId = $boot
    OriginKind = 'auto'; FirmwareReadSucceeded = $true
}
Assert-Decision 'Trusted same-cycle automatic restore syncs' 'Synchronize' (Resolve-BootNextSynchronizationCore @params).Decision
Assert-Decision 'Trusted automatic restore has explicit provenance reason' 'verified-lfs-auto-origin' (Resolve-BootNextSynchronizationCore @params).Reason
$params.OriginKind = 'manual'
Assert-Decision 'Explicit manual selection wins even if it equals old default' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
Assert-Decision 'Manual writes have documented reason' 'explicit-lfs-selection' (Resolve-BootNextSynchronizationCore @params).Reason
$params.OriginKind = 'pending-manual'
Assert-Decision 'Pending manual intent also blocks automatic sync' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.OriginKind = 'auto'
$params.OriginBootId = 'other-cycle'
Assert-Decision 'Stale cycle cannot synchronize' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.OriginBootId = $boot
$params.EffectiveNextGuid = $c
Assert-Decision 'Observable external mismatch cannot synchronize' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
Assert-Decision 'Observable external mismatch reason' 'observed-external-mismatch' (Resolve-BootNextSynchronizationCore @params).Reason
$params.EffectiveNextGuid = $a
$params.OriginGuid = $null
Assert-Decision 'Absent origin cannot silently overwrite equal GUID' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.OriginGuid = $a
$params.FirmwareReadSucceeded = $false
Assert-Decision 'Failed firmware read cannot synchronize' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.FirmwareReadSucceeded = $true
$params.EffectiveNextGuid = $null
Assert-Decision 'Firmware default order is preserved' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.EffectiveNextGuid = $a
$params.NewDefaultGuid = $a
Assert-Decision 'Idempotent same-value change avoids write' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.NewDefaultGuid = $null
Assert-Decision 'Clearing default never clears next boot implicitly' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
$params.NewDefaultGuid = $b
$params.OriginKind = 'pending-auto'
Assert-Decision 'Interrupted automatic mutation fails closed' 'Preserve' (Resolve-BootNextSynchronizationCore @params).Decision
Assert-Decision 'Checking display state' 'checking' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $a -FirmwareReadSucceeded $false -Checking $true)
Assert-Decision 'Failed read display state' 'unknown' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $a -FirmwareReadSucceeded $false -Checking $false)
Assert-Decision 'No bootsequence display state' 'firmware-order' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $null -FirmwareReadSucceeded $true -Checking $false)
Assert-Decision 'Matching display state' 'aligned' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $a -FirmwareReadSucceeded $true -Checking $false)
Assert-Decision 'Different display state' 'different' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $b -FirmwareReadSucceeded $true -Checking $false)
Assert-Decision 'Missing target display state' 'unavailable' (Resolve-BootNextDisplayStateCore -DefaultGuid $a -EffectiveNextGuid $b -FirmwareReadSucceeded $true -Checking $false -EffectiveTargetKnown $false)
Write-Host "BOOTNEXT OWNERSHIP TOTAL $checks/20"
if ($checks -ne 20) { throw "Unexpected BootNext ownership check count $checks" }
