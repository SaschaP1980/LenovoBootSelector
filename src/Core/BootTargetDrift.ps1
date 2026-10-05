# Lenovo Boot Selector v0.5.0 - Functional Core: firmware target drift comparison
# Pure/deterministic functions only. No UI, IO, Task Scheduler or global script state.

function Compare-BootTargetDriftCore {
    param(
        [AllowNull()]$InstalledTargets,
        [AllowNull()]$Descriptions,
        [AllowNull()][string[]]$DisplayOrder
    )

    $installed = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($InstalledTargets)) {
        $guid = [string]$target.guid
        if (-not $guid) { continue }
        $normalized = $guid.Trim().ToLowerInvariant()
        if ($normalized -and -not $installed.Contains($normalized)) { $installed.Add($normalized) }
    }

    $current = New-Object System.Collections.Generic.List[string]
    $bootMenuGuid = $null
    if ($Descriptions) {
        foreach ($key in @($Descriptions.Keys)) {
            if ([string]$Descriptions[$key] -eq 'Boot Menu') {
                $bootMenuGuid = ([string]$key).Trim().ToLowerInvariant()
                break
            }
        }
    }
    if ($bootMenuGuid -and -not $current.Contains($bootMenuGuid)) { $current.Add($bootMenuGuid) }

    foreach ($guid in @($DisplayOrder)) {
        if (-not $guid) { continue }
        $normalized = ([string]$guid).Trim().ToLowerInvariant()
        if ($normalized -and -not $current.Contains($normalized)) { $current.Add($normalized) }
    }

    $added = @($current | Where-Object { -not $installed.Contains($_) })
    $removed = @($installed | Where-Object { -not $current.Contains($_) })

    [pscustomobject]@{
        HasDrift = [bool]($added.Count -gt 0 -or $removed.Count -gt 0)
        HasNewTargets = [bool]($added.Count -gt 0)
        AddedGuids = @($added)
        RemovedGuids = @($removed)
        CurrentGuids = @($current.ToArray())
        InstalledGuids = @($installed.ToArray())
        BootMenuGuid = $bootMenuGuid
    }
}
