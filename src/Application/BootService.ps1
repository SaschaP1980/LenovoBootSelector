function Get-BootServiceFirmwareSnapshot {
    param([switch]$UseExistingCache, [switch]$ForceManagerRefresh)

    if ($UseExistingCache -and $ForceManagerRefresh) {
        throw 'Cannot combine cached firmware state with a forced firmware-manager refresh.'
    }
    # A snapshot later labelled freshly verified must bypass the short manager
    # cache. A cached popup-open snapshot must never be labelled verified.
    $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache:$UseExistingCache -Force:$ForceManagerRefresh
    $firmwareText = Get-TaskBrokerFirmwareEntriesText -UseExistingCache:$UseExistingCache

    [pscustomobject]@{
        Descriptions = ConvertFrom-FirmwareEntriesText -Text ([string]$firmwareText)
        ManagerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    }
}

function Set-BootNextTargetService {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = $Guid.ToLowerInvariant()
    $managerText = Set-TaskBrokerBootNextTarget -Guid $normalized
    if ($managerText -notmatch [regex]::Escape($normalized)) {
        throw "BCDEdit wurde ausgeführt, aber das gewünschte Ziel konnte im Firmware Boot Manager nicht nachgewiesen werden: $normalized"
    }

    $managerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    if (-not $managerState.SelectedGuid -or $managerState.SelectedGuid -ne $normalized) {
        throw "Das gewünschte BootNext-Ziel wurde nach dem Schreiben nicht als bootsequence zurückgelesen: $normalized"
    }

    [pscustomobject]@{
        ExitCode = 0
        Guid = $normalized
        ManagerText = $managerText
    }
}
