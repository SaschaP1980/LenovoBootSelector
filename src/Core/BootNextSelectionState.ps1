# Pure BootNext selection display/verification contract.
# A pending user request must never be represented as an effective one-shot
# firmware selection until the protected writer and firmware readback succeed.
function Resolve-BootNextRowDisplayCore {
    param([AllowNull()][string]$EntryGuid,[AllowNull()][string]$ConfirmedGuid,[AllowNull()][string]$PendingGuid)
    if (-not $EntryGuid) { return 'idle' }
    if ($PendingGuid -and $EntryGuid -eq $PendingGuid) { return 'pending' }
    if ($ConfirmedGuid -and $EntryGuid -eq $ConfirmedGuid) { return 'selected' }
    return 'idle'
}

function Test-BootNextWorkerResultCore {
    param([AllowNull()][string]$RequestedGuid,[AllowNull()][string]$ReturnedGuid,[bool]$Success)
    return ([bool]$Success -and [bool]$RequestedGuid -and
        [bool]$ReturnedGuid -and $RequestedGuid -eq $ReturnedGuid)
}

# Distinguish a safe, visibly deferred cold-start intent from authorization
# to execute the fixed SYSTEM BootNext writer. This decision never mutates EFI.
function Resolve-BootNextSelectionAdmissionCore {
    param(
        [AllowEmptyString()][string]$CapabilityState,
        [bool]$CanSetBootNext,
        [bool]$CanUseCachedBootState,
        [bool]$RefreshActive,
        [bool]$TargetAllowlisted
    )
    if (-not $TargetAllowlisted) { return 'reject' }
    if ($CapabilityState -eq 'Ready' -and $CanSetBootNext) { return 'start' }
    if ($CapabilityState -eq 'Checking' -and $CanUseCachedBootState -and $RefreshActive) {
        return 'deferred'
    }
    return 'reject'
}
