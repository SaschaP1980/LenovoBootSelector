# Lenovo Boot Selector v0.5.0 - Application state for read-only firmware-target drift.
# No UI, IO, Scheduled Tasks or global script state.

function New-BootTargetDriftRuntimeState {
    [pscustomobject]@{
        Evaluated = $false
        HasDrift = $false
        HasNewTargets = $false
        AddedGuids = @()
        RemovedGuids = @()
        CurrentGuids = @()
        InstalledGuids = @()
        CheckedUtc = $null
        NotificationShown = $false
    }
}

function Set-BootTargetDriftRuntimeState {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Drift,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $oldFingerprint = ((@($State.AddedGuids) + @('|') + @($State.RemovedGuids)) -join ',')
    $newFingerprint = ((@($Drift.AddedGuids) + @('|') + @($Drift.RemovedGuids)) -join ',')
    if (-not $State.Evaluated -or $oldFingerprint -ne $newFingerprint) {
        $State.NotificationShown = $false
    }

    $State.Evaluated = $true
    $State.HasDrift = [bool]$Drift.HasDrift
    $State.HasNewTargets = [bool]$Drift.HasNewTargets
    $State.AddedGuids = @($Drift.AddedGuids)
    $State.RemovedGuids = @($Drift.RemovedGuids)
    $State.CurrentGuids = @($Drift.CurrentGuids)
    $State.InstalledGuids = @($Drift.InstalledGuids)
    $State.CheckedUtc = $NowUtc
    if (-not $State.HasDrift) { $State.NotificationShown = $false }
    return $State
}

function Clear-BootTargetDriftRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Evaluated = $false
    $State.HasDrift = $false
    $State.HasNewTargets = $false
    $State.AddedGuids = @()
    $State.RemovedGuids = @()
    $State.CurrentGuids = @()
    $State.InstalledGuids = @()
    $State.CheckedUtc = $null
    $State.NotificationShown = $false
    return $State
}

function Test-BootTargetDriftRuntimeDetected {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift)
}

function Test-BootTargetDriftRuntimeHasNewTargets {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift -and $State.HasNewTargets)
}

function Set-BootTargetDriftNotificationShown {
    param([Parameter(Mandatory=$true)]$State)
    $State.NotificationShown = $true
    return $State
}
