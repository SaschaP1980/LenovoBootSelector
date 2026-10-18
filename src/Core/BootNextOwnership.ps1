# LBS-143: pure, fail-closed boot ownership decision core.
# No firmware I/O, storage, system tasks, or process-local provenance assertions.
function Resolve-BootNextSynchronizationCore {
    param(
        [AllowNull()][string]$PreviousDefaultGuid,
        [AllowNull()][string]$NewDefaultGuid,
        [AllowNull()][string]$EffectiveNextGuid,
        [AllowNull()][string]$OriginGuid,
        [AllowNull()][string]$OriginBootId,
        [AllowNull()][string]$CurrentBootId,
        [AllowEmptyString()][string]$OriginKind = '',
        [bool]$FirmwareReadSucceeded = $false
    )
    $decision = 'Preserve'
    $reason = 'unknown-provenance'
    if (-not $NewDefaultGuid) {
        $reason = 'default-cleared'
    }
    elseif ($PreviousDefaultGuid -eq $NewDefaultGuid) {
        $reason = 'default-unchanged'
    }
    elseif (-not $FirmwareReadSucceeded) {
        $reason = 'firmware-unverified'
    }
    elseif (-not $EffectiveNextGuid) {
        $reason = 'firmware-default-order'
    }
    elseif ($OriginKind -eq 'manual' -or $OriginKind -eq 'pending-manual') {
        $reason = 'explicit-lfs-selection'
    }
    elseif ($OriginKind -eq 'auto' -and $OriginGuid -and $OriginBootId -and $CurrentBootId -and
            $OriginBootId -ceq $CurrentBootId -and $OriginGuid -eq $PreviousDefaultGuid -and
            $OriginGuid -eq $EffectiveNextGuid) {
        $decision = 'Synchronize'
        $reason = 'verified-lfs-auto-origin'
    }
    elseif ($OriginKind -eq 'auto' -and $OriginGuid -and $EffectiveNextGuid -and
            $OriginGuid -ne $EffectiveNextGuid) {
        $reason = 'observed-external-mismatch'
    }
    elseif ($OriginKind -eq 'pending-auto') {
        $reason = 'interrupted-auto-write'
    }
    elseif ($OriginBootId -and $CurrentBootId -and $OriginBootId -cne $CurrentBootId) {
        $reason = 'stale-boot-cycle'
    }
    [pscustomobject]@{
        Decision = $decision
        Reason = $reason
        RequiresExplicitSelection = ($decision -ne 'Synchronize' -and
            $NewDefaultGuid -and $PreviousDefaultGuid -ne $NewDefaultGuid -and
            $FirmwareReadSucceeded -and $EffectiveNextGuid -and $EffectiveNextGuid -ne $NewDefaultGuid)
    }
}

function Resolve-BootNextDisplayStateCore {
    param(
        [AllowNull()][string]$DefaultGuid,
        [AllowNull()][string]$EffectiveNextGuid,
        [bool]$FirmwareReadSucceeded,
        [bool]$Checking,
        [bool]$EffectiveTargetKnown = $true
    )
    if ($Checking) { return 'checking' }
    if (-not $FirmwareReadSucceeded) { return 'unknown' }
    if (-not $EffectiveNextGuid) { return 'firmware-order' }
    if (-not $EffectiveTargetKnown) { return 'unavailable' }
    if ($DefaultGuid -and $DefaultGuid -eq $EffectiveNextGuid) { return 'aligned' }
    return 'different'
}
