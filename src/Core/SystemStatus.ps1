# LBS-182: read-only status classification; no I/O, privileges or UI state.
function Resolve-SystemStatusCore {
    param($Capabilities,[string]$DefaultEvidence,[string]$DefaultName,[string]$DefaultGuid,
          [bool]$DefaultUncertain,[bool]$NextVerified,[string]$NextName,[string]$NextGuid,
          [bool]$NextTimeKnown,[bool]$Pending,[bool]$Refreshing,[string]$LastRefresh,
          $Drift,[bool]$DriftFailed,[bool]$ReadinessTimeKnown,[bool]$EntriesTimeKnown)
    $state = if ($Capabilities -and $Capabilities.State -in @('Ready','Checking','SetupRequired','RepairRequired','ReinitializeRequired','Busy','Unknown')) { [string]$Capabilities.State } else { 'Unknown' }
    if ($state -eq 'Ready' -and -not $ReadinessTimeKnown) { $state = 'Unknown' }
    $default = if ($DefaultUncertain -or $DefaultEvidence -notin @('configured','none','unavailable')) { 'Unknown' }
        elseif ($DefaultEvidence -eq 'unavailable' -or ($DefaultEvidence -eq 'configured' -and (-not $DefaultGuid -or -not $DefaultName))) { 'Unavailable' }
        elseif ($DefaultEvidence -eq 'none' -and -not $DefaultGuid) { 'NoDefault' }
        elseif ($DefaultEvidence -eq 'configured' -and $DefaultGuid -and $DefaultName) { 'Value' } else { 'Unknown' }
    $next = if ($Pending) { 'Pending' } elseif (-not $NextVerified -or -not $NextTimeKnown) { 'Unknown' }
        elseif (-not $NextGuid) { 'FirmwareOrder' } elseif (-not $NextName) { 'Unavailable' } else { 'Value' }
    $relation = if ($next -eq 'Value' -and $default -eq 'Value') {
        if ($NextGuid -eq $DefaultGuid) { 'Matches' } else { 'Differs' }
    } else { 'Verified' }
    $driftKey = if (-not $Drift -or -not $Drift.Evaluated -or $DriftFailed -or -not $EntriesTimeKnown) { 'Unknown' } elseif ($Drift.HasDrift) { 'DriftChanged' } else { 'DriftNone' }
    $hint = switch ($state) {
        'SetupRequired' { 'SetupHint' }
        'RepairRequired' { 'RepairHint' }
        'ReinitializeRequired' { 'ReinitializeHint' }
        default { '' }
    }
    $summary = if ($state -eq 'Busy' -or $Refreshing -or $Pending -or $state -eq 'Checking') { 'SummaryBusy' }
        elseif ($state -in @('SetupRequired','RepairRequired','ReinitializeRequired') -or $driftKey -eq 'DriftChanged' -or $next -eq 'Unavailable' -or $default -eq 'Unavailable') { 'SummaryAttention' }
        elseif ($state -ne 'Ready' -or -not $ReadinessTimeKnown -or $next -eq 'Unknown' -or $default -eq 'Unknown' -or $driftKey -eq 'Unknown' -or $LastRefresh -eq 'error') { 'SummaryUnknown' }
        else { 'SummaryReady' }
    [pscustomobject]@{ Summary=$summary; Readiness=$state; Default=$default; DefaultName=$DefaultName; Next=$next; NextName=$NextName;
        Relation=$relation; Drift=$driftKey; Hint=$hint; Refresh=if ($Refreshing) {'RefreshRunning'} elseif ($LastRefresh -eq 'error') {'RefreshFailed'} else {''} }
}
