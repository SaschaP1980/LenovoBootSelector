function New-UpdateRuntimeState {
    [pscustomobject]@{
        Status = 'Idle'
        AvailableManifest = $null
        LastError = ''
        CheckProcess = $null
        CheckTimer = $null
        CheckResultPath = $null
        CheckMode = ''
        CheckClock = $null
        CheckTerminationReason = ''
        CheckCleanupProcess = $null
        CheckCleanupResultPath = $null
        CheckCooldownClock = $null
        LastCheckSucceeded = $null
        PrepareProcess = $null
        PrepareTimer = $null
        PrepareResultPath = $null
        ManifestPath = $null
    }
}

function Set-UpdateRuntimeChecking {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Checking'
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeIdle {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Idle'
    return $State
}

# A failed read-only check must not invalidate a previously validated manifest.
function Restore-UpdateRuntimeAfterCheckFailure {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = if ($null -ne $State.AvailableManifest) { 'UpdateAvailable' } else { 'Idle' }
    return $State
}

function Set-UpdateRuntimeAvailable {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)]$Manifest)
    $State.Status = 'UpdateAvailable'
    $State.AvailableManifest = $Manifest
    $State.LastError = ''
    return $State
}

# Monotonic freshness avoids repeated network work when a popup is reopened.
# Manual checks bypass this policy, never the single-flight gate.
function Set-UpdateRuntimeCheckOutcome {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][bool]$Success)
    $State.LastCheckSucceeded = $Success
    $State.CheckCooldownClock = [System.Diagnostics.Stopwatch]::StartNew()
}

function Test-UpdateRuntimePopupCheckFresh {
    param([Parameter(Mandatory=$true)]$State)
    if (-not $State.CheckCooldownClock) { return $false }
    $intervalMs = if ($State.LastCheckSucceeded) { 300000 } else { 30000 }
    return ($State.CheckCooldownClock.ElapsedMilliseconds -lt $intervalMs)
}

function Set-UpdateRuntimePreparing {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Preparing'
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeReadyToInstall {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'ReadyToInstall'
    return $State
}

function Set-UpdateRuntimeFailed {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$Message)
    $State.Status = 'Failed'
    $State.LastError = $Message
    return $State
}

function Test-UpdateRuntimeBusy {
    param([AllowNull()]$State)
    if (-not $State) { return $false }
    return @('Checking','Preparing','ReadyToInstall') -contains [string]$State.Status
}
