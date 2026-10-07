function Resolve-SystemFunctionsCapabilities {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][bool]$FactsValid,
        [Parameter(Mandatory=$true)][bool]$InstallationPresent,
        [Parameter(Mandatory=$true)][bool]$MetadataCompatible,
        [AllowNull()]$SessionReady,
        [Parameter(Mandatory=$true)][bool]$MaintenanceBusy,
        [AllowEmptyString()][string]$MaintenanceMode = '',
        [Parameter(Mandatory=$true)][bool]$DriftDetected,
        [int]$EntryCount = 0
    )

    $readyKnown = ($null -ne $SessionReady)
    $sessionReadyIsBoolean = (-not $readyKnown -or $SessionReady -is [bool])
    $ready = ($readyKnown -and $sessionReadyIsBoolean -and [bool]$SessionReady)
    $consistent = (
        $FactsValid -and
        $EntryCount -ge 0 -and
        $sessionReadyIsBoolean -and
        (-not $MetadataCompatible -or $InstallationPresent) -and
        (-not $ready -or $MetadataCompatible)
    )

    $state = if (-not $consistent) {
        'Unknown'
    }
    elseif ($MaintenanceBusy) {
        'Busy'
    }
    elseif (-not $InstallationPresent) {
        'SetupRequired'
    }
    elseif (-not $MetadataCompatible) {
        'RepairRequired'
    }
    elseif (-not $readyKnown) {
        'Checking'
    }
    elseif (-not $ready) {
        'RepairRequired'
    }
    elseif ($DriftDetected) {
        'ReinitializeRequired'
    }
    else {
        'Ready'
    }

    $isReady = ($state -eq 'Ready')
    $isChecking = ($state -eq 'Checking')
    $hasEntries = ($EntryCount -gt 0)
    $canUseCachedBootState = (
        $consistent -and
        -not $MaintenanceBusy -and
        $MetadataCompatible -and
        (-not $readyKnown -or $ready) -and
        -not $DriftDetected
    )

    [pscustomobject]@{
        State = $state
        Reason = $state
        MaintenanceMode = if ($MaintenanceBusy) { [string]$MaintenanceMode } else { '' }
        InstallationPresent = [bool]$InstallationPresent
        MetadataCompatible = [bool]$MetadataCompatible
        SessionReadyKnown = [bool]$readyKnown
        SessionReady = [bool]$ready
        DriftDetected = [bool]$DriftDetected
        EntryCount = [int]$EntryCount
        HasEntries = [bool]$hasEntries
        IsReady = [bool]$isReady
        IsChecking = [bool]$isChecking
        CanUseCachedBootState = [bool]$canUseCachedBootState
        CanRefresh = [bool]$isReady
        CanSetBootNext = [bool]($isReady -and $hasEntries)
        CanUseDefaultTarget = [bool]$isReady
        CanSetDefaultTarget = [bool]($isReady -and $hasEntries)
        CanManageEntries = [bool]($isReady -and $hasEntries)
        CanRestart = [bool]($consistent -and -not $MaintenanceBusy -and -not $DriftDetected)
        CanConfigureSystemFunctions = [bool](-not $MaintenanceBusy)
        CanRemoveSystemFunctions = [bool](-not $MaintenanceBusy)
    }
}

function Get-CurrentSystemFunctionsCapabilities {
    [CmdletBinding()]
    param([switch]$ProbeReadiness)

    try {
        $busy = Test-MaintenanceRuntimeBusy -State $script:MaintenanceState
        $mode = Get-MaintenanceRuntimeMode -State $script:MaintenanceState
        $entryCount = @($script:CurrentEntries).Count
        if ($busy) {
            return (Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $true -MaintenanceMode $mode -DriftDetected $false -EntryCount $entryCount)
        }

        $present = [bool](Test-TaskBrokerInstallationPresent)
        $compatible = if ($present) { [bool](Test-TaskBrokerMetadataCompatible) } else { $false }
        $sessionReady = $null

        if ($present -and $compatible) {
            if ($ProbeReadiness) {
                $sessionReady = [bool](Test-TaskBrokerReady)
            }
            elseif ($null -ne $script:TaskBrokerReadyCached) {
                $sessionReady = [bool]$script:TaskBrokerReadyCached
            }
        }

        $drift = [bool](Test-BootTargetDriftRuntimeDetected -State $script:BootTargetDriftState)
        return (Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $present -MetadataCompatible $compatible -SessionReady $sessionReady -MaintenanceBusy $busy -MaintenanceMode $mode -DriftDetected $drift -EntryCount $entryCount)
    }
    catch {
        return (Resolve-SystemFunctionsCapabilities -FactsValid $false -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $false -MaintenanceMode '' -DriftDetected $false -EntryCount 0)
    }
}
