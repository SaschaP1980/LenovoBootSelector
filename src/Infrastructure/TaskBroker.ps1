function Normalize-TaskBrokerGuid {
    param([AllowNull()][string]$Guid)
    if ([string]::IsNullOrWhiteSpace($Guid)) { return $null }
    $candidate = $Guid.Trim().ToLowerInvariant()
    if ($candidate -notmatch '^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$') { return $null }
    return $candidate
}

function Get-TaskBrokerExpectedTargetTaskName {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [switch]$DefaultTarget
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { return $null }
    $compact = $normalized.Trim('{}').Replace('-','')
    if ($DefaultTarget) { return ('LenovoBootSelector-Default-Set-' + $compact) }
    return ('LenovoBootSelector-Set-' + $compact)
}

function Test-TaskBrokerMetadataContract {
    param([Parameter(Mandatory=$true)]$Metadata)
    try {
        if ($script:SupportedTaskBrokerVersions -notcontains [string]$Metadata.version) { return $false }
        if ([string]$Metadata.boundaryContract -ne 'fixed-task-v2') { return $false }
        if ([string]$Metadata.managerRefreshTask -ne 'LenovoBootSelector-RefreshManager') { return $false }
        if ([string]$Metadata.firmwareRefreshTask -ne 'LenovoBootSelector-RefreshFirmware') { return $false }
        if ([string]$Metadata.defaultClearTask -ne 'LenovoBootSelector-Default-Clear') { return $false }
        if ([string]$Metadata.defaultRestoreTask -ne 'LenovoBootSelector-Default-Restore') { return $false }
        if ($null -eq $Metadata.PSObject.Properties['defaultRestoreDelaySeconds'] -or [int]$Metadata.defaultRestoreDelaySeconds -ne 0) { return $false }

        $expectedManagerFile = Join-Path $script:TaskBrokerStateDir 'fwbootmgr.txt'
        $expectedFirmwareFile = Join-Path $script:TaskBrokerStateDir 'firmware.txt'
        $expectedDefaultFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'default-guid.txt'
        $expectedOriginFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'bootnext-origin.json'
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.managerFile),[System.IO.Path]::GetFullPath($expectedManagerFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.firmwareFile),[System.IO.Path]::GetFullPath($expectedFirmwareFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.defaultFile),[System.IO.Path]::GetFullPath($expectedDefaultFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.bootNextOriginFile),[System.IO.Path]::GetFullPath($expectedOriginFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }

        $targets = @($Metadata.targets)
        if ($targets.Count -lt 1) { return $false }
        $seenGuids = @{}
        $seenTaskNames = @{}
        foreach ($target in $targets) {
            $normalized = Normalize-TaskBrokerGuid -Guid ([string]$target.guid)
            if (-not $normalized -or [string]$target.guid -ne $normalized) { return $false }
            $expectedBoot = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            $expectedDefault = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
            if ([string]$target.taskName -ne $expectedBoot) { return $false }
            if ([string]$target.defaultTaskName -ne $expectedDefault) { return $false }
            if ($seenGuids.ContainsKey($normalized)) { return $false }
            $bootKey = $expectedBoot.ToLowerInvariant()
            $defaultKey = $expectedDefault.ToLowerInvariant()
            if ($seenTaskNames.ContainsKey($bootKey) -or $seenTaskNames.ContainsKey($defaultKey)) { return $false }
            $seenGuids[$normalized] = $true
            $seenTaskNames[$bootKey] = $true
            $seenTaskNames[$defaultKey] = $true
        }
        return $true
    }
    catch { return $false }
}


function Get-TaskBrokerMetadata {
    if ($script:TaskBrokerMetadata) {
        if (Test-TaskBrokerMetadataContract -Metadata $script:TaskBrokerMetadata) { return $script:TaskBrokerMetadata }
        $script:TaskBrokerMetadata = $null
    }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerMetadataPath)) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText($script:TaskBrokerMetadataPath, [System.Text.Encoding]::UTF8)
        $meta = $text | ConvertFrom-Json
        if (-not (Test-TaskBrokerMetadataContract -Metadata $meta)) { return $null }
        $script:TaskBrokerMetadata = $meta
        return $meta
    }
    catch { return $null }
}

function Get-TaskBrokerTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return $null }
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { return $null }
    foreach ($target in @($meta.targets)) {
        if ([string]$target.guid -eq $normalized) { return $target }
    }
    return $null
}
function Resolve-TaskBrokerAuthorizedTaskName {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]
        [string]$Operation,
        [AllowNull()][string]$Guid
    )

    if (-not (Test-TaskBrokerMetadataCompatible)) {
        throw 'Die TaskBroker-Metadaten erfüllen den festen Privilege-Boundary-Vertrag nicht.'
    }

    switch ($Operation) {
        'ManagerRefresh' { return 'LenovoBootSelector-RefreshManager' }
        'FirmwareRefresh' { return 'LenovoBootSelector-RefreshFirmware' }
        'DefaultClear' { return 'LenovoBootSelector-Default-Clear' }
        'BootNext' {
            $normalized = Normalize-TaskBrokerGuid -Guid $Guid
            if (-not $normalized) { throw 'Ungültiges BootNext-Ziel.' }
            $target = Get-TaskBrokerTarget -Guid $normalized
            if (-not $target) { throw 'Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden.' }
            $expected = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            if ([string]$target.taskName -ne $expected) { throw 'BootNext-Aufgabenname verletzt den festen TaskBroker-Vertrag.' }
            return $expected
        }
        'DefaultSet' {
            $normalized = Normalize-TaskBrokerGuid -Guid $Guid
            if (-not $normalized) { throw 'Ungültiges Standardziel.' }
            $target = Get-TaskBrokerTarget -Guid $normalized
            if (-not $target) { throw 'Für dieses Firmware-Ziel ist keine autorisierte Standardziel-Aufgabe vorhanden.' }
            $expected = Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
            if ([string]$target.defaultTaskName -ne $expected) { throw 'Standardziel-Aufgabenname verletzt den festen TaskBroker-Vertrag.' }
            return $expected
        }
    }
    throw 'Nicht unterstützte TaskBroker-Operation.'
}


function Invoke-AuthorizedTask {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]
        [string]$Operation,
        [AllowNull()][string]$Guid,
        [int]$TimeoutMs = $script:TaskBrokerTimeoutMs
    )

    $started = [datetime]::Now
    $diagSw = [System.Diagnostics.Stopwatch]::StartNew()
    $taskName = ''
    $normalizedGuid = Normalize-TaskBrokerGuid -Guid $Guid
    try {
        $taskName = Resolve-TaskBrokerAuthorizedTaskName -Operation $Operation -Guid $normalizedGuid

        # IMPORTANT: exact-task access is retained; root enumeration is deliberately avoided.
        try {
            $scheduleService = New-Object -ComObject 'Schedule.Service'
            $scheduleService.Connect()
            $taskFolder = $scheduleService.GetFolder('\')
            $registeredTask = $taskFolder.GetTask("\$taskName")
            if (-not $registeredTask) { throw 'Aufgabe nicht gefunden.' }
        }
        catch {
            throw "Die autorisierte Windows-Aufgabe '$taskName' ist für den aktuellen Benutzer nicht lesbar: $($_.Exception.Message)"
        }

        try { Start-ScheduledTask -TaskName $taskName -ErrorAction Stop }
        catch { throw "Die autorisierte Windows-Aufgabe '$taskName' konnte nicht gestartet werden: $($_.Exception.Message)" }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds 75
            try {
                $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
                $registeredTask = $taskFolder.GetTask("\$taskName")
                $state = [int]$registeredTask.State
            }
            catch {
                throw "Der Status der autorisierten Windows-Aufgabe '$taskName' konnte nicht gelesen werden: $($_.Exception.Message)"
            }

            $recent = ($info.LastRunTime -ge $started.AddSeconds(-2))
            $result = [uint32]$info.LastTaskResult
            $isTransientResult = ($result -eq 0x00041301 -or $result -eq 0x00041325)
            if ($recent -and ($state -eq 4 -or $isTransientResult)) { continue }

            if ($recent -and $state -ne 4) {
                if ($result -ne 0) {
                    throw ("Die autorisierte Windows-Aufgabe '{0}' ist mit 0x{1:X8} ({2}) fehlgeschlagen." -f $taskName,$result,$result)
                }
                $diagSw.Stop()
                Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $true -DurationMs $diagSw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ operation = $Operation; taskName = $taskName; targetGuid = $normalizedGuid; lastTaskResult = [uint32]$result; state = $state })
                return $info
            }
        } while ($sw.ElapsedMilliseconds -lt $TimeoutMs)

        throw "Zeitüberschreitung beim Warten auf die autorisierte Windows-Aufgabe '$taskName'."
    }
    catch {
        $diagSw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $false -DurationMs $diagSw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $Operation; taskName = $taskName; targetGuid = $normalizedGuid; timeoutMs = $TimeoutMs }) -Level error
        throw
    }
}
function Read-TaskBrokerTextFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Statusdatei fehlt: $Path"
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

# Bind status-only timestamps to the actual observed cache content.
# Failure leaves provenance unknown; never changes the authorized read result.
function Get-SystemStatusObservationHash {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $null }
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) }
        finally { $sha.Dispose() }
    } catch { return $null }
}
function Test-SystemStatusObservationMatch {
    param([AllowNull()][string]$Text,[AllowNull()][string]$ExpectedHash)
    if (-not $ExpectedHash) { return $false }
    return ((Get-SystemStatusObservationHash $Text) -ceq $ExpectedHash)
}

function Refresh-ManagerCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:ManagerCacheText -and (([datetime]::UtcNow - $script:ManagerCacheUtc).TotalMilliseconds -lt 750)) {
        return $script:ManagerCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -Operation 'ManagerRefresh' | Out-Null
        $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
        $script:ManagerCacheUtc = [datetime]::UtcNow
        $script:SystemStatusManagerObservedHash = Get-SystemStatusObservationHash $script:ManagerCacheText
        $script:SystemStatusManagerObservedUtc = if ($script:SystemStatusManagerObservedHash) { $script:ManagerCacheUtc } else { $null }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:ManagerCacheText.Length })
        return $script:ManagerCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}

function Refresh-FirmwareCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:FirmwareCacheText -and (([datetime]::UtcNow - $script:FirmwareCacheUtc).TotalSeconds -lt 30)) {
        return $script:FirmwareCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -Operation 'FirmwareRefresh' | Out-Null
        $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
        $script:FirmwareCacheUtc = [datetime]::UtcNow
        $script:SystemStatusEntriesObservedHash = Get-SystemStatusObservationHash $script:FirmwareCacheText
        $script:SystemStatusEntriesObservedUtc = if ($script:SystemStatusEntriesObservedHash) { $script:FirmwareCacheUtc } else { $null }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:FirmwareCacheText.Length })
        return $script:FirmwareCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}


function Test-TaskBrokerMetadataCompatible {
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { return $false }
        if (-not (Test-TaskBrokerMetadataContract -Metadata $meta)) { return $false }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { return $false }
        return $true
    }
    catch { return $false }
}
function Get-TaskBrokerInteractiveReady {
    if ($null -ne $script:TaskBrokerReadyCached) { return [bool]$script:TaskBrokerReadyCached }
    return (Test-TaskBrokerMetadataCompatible)
}

function Reset-TaskBrokerReadyCache {
    $script:TaskBrokerReadyCached = $null
    $script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
    $script:SystemStatusReadinessObservedUtc = $null
}


function Test-TaskBrokerReady {
    param([switch]$Force)

    if (-not $Force -and $null -ne $script:TaskBrokerReadyCached) {
        return [bool]$script:TaskBrokerReadyCached
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    $failure = $null
    $requiredCount = 0
    $failedTask = $null
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta -or -not (Test-TaskBrokerMetadataContract -Metadata $meta)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { throw 'TaskBroker ist nicht für den aktuellen Benutzer autorisiert.' }

        $required = @(
            'LenovoBootSelector-RefreshManager',
            'LenovoBootSelector-RefreshFirmware',
            'LenovoBootSelector-Default-Clear',
            'LenovoBootSelector-Default-Restore'
        )
        foreach ($target in @($meta.targets)) {
            $normalized = Normalize-TaskBrokerGuid -Guid ([string]$target.guid)
            if (-not $normalized) { throw 'TaskBroker-Zielmetadaten enthalten eine ungültige GUID.' }
            $required += Get-TaskBrokerExpectedTargetTaskName -Guid $normalized
            $required += Get-TaskBrokerExpectedTargetTaskName -Guid $normalized -DefaultTarget
        }
        $required = @($required | Select-Object -Unique)
        $requiredCount = $required.Count
        foreach ($name in $required) {
            if (-not $name) { throw 'Taskname fehlt.' }
            $failedTask = $name
            [void](Get-ScheduledTaskInfo -TaskName $name -ErrorAction Stop)
        }
        $failedTask = $null
        $ready = $true
    }
    catch {
        $failure = $_
        $ready = $false
    }

    $sw.Stop()
    Write-RuntimeDiagnosticEvent -Event 'TASKBROKER_READY_CHECK' -Stage 'ready' -Success $ready -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $failure -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; requiredTaskCount = $requiredCount; failedTask = $failedTask; brokerPresent = [bool](Test-TaskBrokerInstallationPresent) }) -Level $(if ($ready) { 'info' } else { 'error' })
    $script:TaskBrokerReadyCached = $ready
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    $script:SystemStatusReadinessObservedUtc = $script:TaskBrokerReadyCachedUtc
    return $ready
}
function Test-TaskBrokerInstallationPresent {
    if (Test-Path -LiteralPath $script:TaskBrokerMetadataPath) { return $true }
    if ($script:LegacyTaskBrokerMetadataPath -and (Test-Path -LiteralPath $script:LegacyTaskBrokerMetadataPath)) { return $true }
    return $false
}

function Get-LatestTaskBrokerDiagnosticPath {
    $diagPointer = Join-Path $script:TaskBrokerLocalDir 'latest-install-diagnostic.txt'
    if (Test-Path -LiteralPath $diagPointer) {
        try { return ([System.IO.File]::ReadAllText($diagPointer)).Trim() } catch { }
    }
    return ''
}

function Get-TaskBrokerFirmwareManagerText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:ManagerCacheText) {
            $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
            if (-not (Test-SystemStatusObservationMatch $script:ManagerCacheText $script:SystemStatusManagerObservedHash)) { $script:SystemStatusManagerObservedUtc = $null; $script:SystemStatusManagerObservedHash = $null }
            try { $script:ManagerCacheUtc = (Get-Item -LiteralPath ([string]$meta.managerFile)).LastWriteTimeUtc } catch { }
        }
        return $script:ManagerCacheText
    }

    return (Refresh-ManagerCache -Force:$Force)
}

function Get-TaskBrokerFirmwareEntriesText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:FirmwareCacheText) {
            $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
            if (-not (Test-SystemStatusObservationMatch $script:FirmwareCacheText $script:SystemStatusEntriesObservedHash)) { $script:SystemStatusEntriesObservedUtc = $null; $script:SystemStatusEntriesObservedHash = $null }
            try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc } catch { }
        }
        return $script:FirmwareCacheText
    }

    return (Refresh-FirmwareCache -Force:$Force)
}

function Sync-TaskBrokerFirmwareCachesFromFiles {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'TaskBroker-Metadaten fehlen nach dem Hintergrund-Refresh.' }

    $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
    $script:ManagerCacheUtc = [datetime]::UtcNow
    $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
    try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc }
    catch { $script:FirmwareCacheUtc = [datetime]::UtcNow }

    [pscustomobject]@{
        ManagerText = $script:ManagerCacheText
        FirmwareText = $script:FirmwareCacheText
    }
}

function Get-TaskBrokerDefaultTargetGuid {
    $script:SystemStatusDefaultEvidence = 'unknown'
    $script:SystemStatusDefaultObservedUtc = $null
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not [string]$meta.defaultFile) { return $null }

    $path = [string]$meta.defaultFile
    if (-not (Test-Path -LiteralPath $path)) {
        if (Test-TaskBrokerMetadataContract -Metadata $meta) {
            $script:SystemStatusDefaultEvidence = 'none'
            $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
        }
        return $null
    }

    $candidate = ([System.IO.File]::ReadAllText($path)).Trim().ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $candidate
    if ($target) {
        $script:SystemStatusDefaultEvidence = 'configured'
        $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
        return $candidate
    }
    if (-not $candidate) {
        $script:SystemStatusDefaultEvidence = 'none'
        $script:SystemStatusDefaultObservedUtc = [datetime]::UtcNow
    } else { $script:SystemStatusDefaultEvidence = 'unavailable' }
    return $null
}


function Get-TaskBrokerBootNextOwnership {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return $null }
    $path = [string]$meta.bootNextOriginFile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $record = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([int]$record.schema -ne 1) { return $null }
        $guid = Normalize-TaskBrokerGuid -Guid ([string]$record.guid)
        if (-not $guid -or -not (Get-TaskBrokerTarget -Guid $guid)) { return $null }
        if ([string]$record.kind -notin @('auto','manual','pending-auto','pending-manual')) { return $null }
        $sequence = [int64]$record.seq
        if ($sequence -lt 1) { return $null }
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if (-not $os -or -not $os.LastBootUpTime) { return $null }
        $cycle = [string]([datetime]$os.LastBootUpTime).ToUniversalTime().Ticks
        if ([string]$record.bootId -cne $cycle) { return $null }
        return [pscustomobject]@{ Kind = [string]$record.kind; Guid = $guid; BootId = $cycle; Sequence = $sequence }
    }
    catch { return $null }
}

function Set-TaskBrokerBootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Firmware-Ziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw "Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden: $normalized"
    }

    # Do not acknowledge a previous run of the same fixed Scheduled Task.
    # The only acceptable completion evidence is an advanced, boot-bound,
    # SYSTEM-written manual provenance sequence for this exact allowlisted GUID.
    $before = Get-TaskBrokerBootNextOwnership
    Invoke-AuthorizedTask -Operation 'BootNext' -Guid $normalized -TimeoutMs 30000 | Out-Null
    $after = Get-TaskBrokerBootNextOwnership
    if (-not $after -or $after.Kind -ne 'manual' -or $after.Guid -ne $normalized) {
        throw 'BootNext task has no verified completed manual provenance.'
    }
    if ($before -and $before.BootId -eq $after.BootId -and
        [int64]$after.Sequence -le [int64]$before.Sequence) {
        throw 'BootNext task returned without advancing protected completion evidence.'
    }
    return (Get-TaskBrokerFirmwareManagerText -Force)
}

function Set-TaskBrokerDefaultTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Standardziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'Für dieses Firmwareziel existiert keine autorisierte Standardziel-Aufgabe.'
    }

    Invoke-AuthorizedTask -Operation 'DefaultSet' -Guid $normalized -TimeoutMs 30000 | Out-Null
}

function Clear-TaskBrokerDefaultTarget {
    if (-not (Test-TaskBrokerMetadataCompatible)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
    Invoke-AuthorizedTask -Operation 'DefaultClear' -TimeoutMs 30000 | Out-Null
}


# LBS-287: observational checks only. The protected SYSTEM writer lock is
# deliberately not acquired by the tray. Exact registered writer identities
# come from the already-validated metadata contract, never scene/UI input.
function Get-RestartOriginStamp {
    $meta=Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) { throw 'Restart metadata unavailable.' }
    $path=[string]$meta.bootNextOriginFile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return 'absent' }
    $before=(Get-Item -LiteralPath $path -ErrorAction Stop).LastWriteTimeUtc
    $hash=Get-SystemStatusObservationHash (Read-TaskBrokerTextFile -Path $path)
    $after=(Get-Item -LiteralPath $path -ErrorAction Stop).LastWriteTimeUtc
    if (-not $hash -or $before -ne $after) { throw 'Boot writer provenance changed during observation.' }
    return ('{0}:{1}' -f $after.Ticks,$hash)
}

function Get-RestartWriterFingerprint {
    $meta=Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) { throw 'Restart metadata unavailable.' }
    $names=@('LenovoBootSelector-Default-Clear','LenovoBootSelector-Default-Restore')
    foreach ($target in @($meta.targets)) {
        $names+=Get-TaskBrokerExpectedTargetTaskName -Guid ([string]$target.guid)
        $names+=Get-TaskBrokerExpectedTargetTaskName -Guid ([string]$target.guid) -DefaultTarget
    }
    $service=$null; $folder=$null
    $stamps=@()
    try {
        $service=New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $folder=$service.GetFolder('\')
        foreach ($name in @($names)+@('LenovoBootSelector-RefreshManager','LenovoBootSelector-RefreshFirmware')) {
            if (-not $name) { throw 'Invalid installed boot writer identity.' }
            $task=$null
            try {
                $task=$folder.GetTask("\$name")
                # TASK_STATE_READY = 3. Queued/running/disabled/unknown all
                # invalidate restart admission. No task is started here.
                if (-not $task -or [int]$task.State -ne 3) { throw 'An installed boot reader or writer is not idle.' }
                if ($names -contains $name) { $stamps+=('{0}:{1}:{2}' -f $name,([datetime]$task.LastRunTime).Ticks,[int64]$task.LastTaskResult) }
            }
            finally {
                if ($task -and [Runtime.InteropServices.Marshal]::IsComObject($task)) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($task) }
            }
        }
        $origin=Get-RestartOriginStamp
        return [pscustomobject]@{Fingerprint=($stamps -join '|');Origin=$origin}
    }
    finally {
        if ($folder -and [Runtime.InteropServices.Marshal]::IsComObject($folder)) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) }
        if ($service -and [Runtime.InteropServices.Marshal]::IsComObject($service)) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($service) }
    }
}

# A successful worker exit and its local JSON alone are insufficient. Bind
# the observations to protected ProgramData snapshots newly written during
# this particular phase, and reject changes between file reads.
function Read-RestartFreshSnapshot {
    param([string]$Path,[datetime]$PreviousWriteUtc,[datetime]$StartedUtc,$ObservedUtc,[string]$ObservedHash)
    if (-not $ObservedUtc -or -not $ObservedHash) { throw 'Missing fresh observation.' }
    $observed=[datetime]::ParseExact([string]$ObservedUtc,'o',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    $now=[datetime]::UtcNow
    if ($observed -lt $StartedUtc -or $observed -gt $now) { throw 'Observation does not belong to this restart verification.' }
    $before=(Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    if ($before -le $PreviousWriteUtc -or $before -lt $StartedUtc -or $before -gt $observed) { throw ('Protected snapshot is not fresh (previous={0:o}; start={1:o}; write={2:o}; observed={3:o}).' -f $PreviousWriteUtc,$StartedUtc,$before,$observed) }
    $text=Read-TaskBrokerTextFile -Path $Path
    $after=(Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    if ($after -ne $before -or -not (Test-SystemStatusObservationMatch $text $ObservedHash)) { throw 'Protected snapshot changed or does not match worker evidence.' }
    return $text
}

function Get-RestartReadbackBaseline {
    $meta=Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) { throw 'Restart metadata unavailable.' }
    [pscustomobject]@{
        ManagerWriteUtc=(Get-Item -LiteralPath ([string]$meta.managerFile) -ErrorAction Stop).LastWriteTimeUtc
        EntriesWriteUtc=(Get-Item -LiteralPath ([string]$meta.firmwareFile) -ErrorAction Stop).LastWriteTimeUtc
    }
}

function Get-RestartReadbackEvidence {
    param($Context,$Result)
    if ($Result.Success -isnot [bool] -or -not $Result.Success -or $Result.RestartVerified -isnot [bool] -or -not $Result.RestartVerified -or [string]$Result.Stage -ne 'complete') {
        throw 'Restart verification worker did not confirm fresh evidence.'
    }
    $meta=Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) { throw 'Restart metadata unavailable.' }
    $entries=Read-RestartFreshSnapshot -Path ([string]$meta.firmwareFile) -PreviousWriteUtc $Context.Baseline.EntriesWriteUtc -StartedUtc $Context.StartedUtc -ObservedUtc $Result.EntriesObservedUtc -ObservedHash ([string]$Result.EntriesObservedHash)
    $manager=Read-RestartFreshSnapshot -Path ([string]$meta.managerFile) -PreviousWriteUtc $Context.Baseline.ManagerWriteUtc -StartedUtc $Context.StartedUtc -ObservedUtc $Result.ManagerObservedUtc -ObservedHash ([string]$Result.ManagerObservedHash)
    if (-not $Result.RestartOriginStamp -or (Get-RestartOriginStamp) -cne [string]$Result.RestartOriginStamp) { throw 'Boot writer provenance changed after readback.' }
    $state=ConvertFrom-RestartFirmwareEvidence -Text $manager
    $descriptions=ConvertFrom-FirmwareEntriesText -Text $entries
    if ($state.ExplicitTarget) {
        if (-not $descriptions.ContainsKey([string]$state.SelectedGuid) -or -not (Get-TaskBrokerTarget -Guid ([string]$state.SelectedGuid))) { throw 'Observed boot target unavailable or not allowlisted.' }
    } elseif (-not $descriptions.ContainsKey([string]$state.DisplayOrder[0])) {
        throw 'Normal firmware order cannot be confirmed.'
    }
    # Bound age of the final read, including worker exit and STA scheduling.
    $utc=[datetime]::ParseExact([string]$Result.ManagerObservedUtc,'o',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    if (([datetime]::UtcNow-$utc).TotalSeconds -gt 5) { throw 'Restart readback is too old.' }
    [pscustomobject]@{Guid=$state.SelectedGuid;DisplayOrder=@($state.DisplayOrder);OriginStamp=[string]$Result.RestartOriginStamp;ObservedUtc=$utc;ManagerText=$manager;EntriesText=$entries;ManagerHash=[string]$Result.ManagerObservedHash;EntriesHash=[string]$Result.EntriesObservedHash;EntriesUtc=[datetime]::ParseExact([string]$Result.EntriesObservedUtc,'o',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()}
}
