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

        $expectedManagerFile = Join-Path $script:TaskBrokerStateDir 'fwbootmgr.txt'
        $expectedFirmwareFile = Join-Path $script:TaskBrokerStateDir 'firmware.txt'
        $expectedDefaultFile = Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'default-guid.txt'
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.managerFile),[System.IO.Path]::GetFullPath($expectedManagerFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.firmwareFile),[System.IO.Path]::GetFullPath($expectedFirmwareFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$Metadata.defaultFile),[System.IO.Path]::GetFullPath($expectedDefaultFile),[System.StringComparison]::OrdinalIgnoreCase)) { return $false }

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
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not [string]$meta.defaultFile) { return $null }

    $path = [string]$meta.defaultFile
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    $candidate = ([System.IO.File]::ReadAllText($path)).Trim().ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $candidate
    if ($target) { return $candidate }
    return $null
}


function Set-TaskBrokerBootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Firmware-Ziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw "Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden: $normalized"
    }

    Invoke-AuthorizedTask -Operation 'BootNext' -Guid $normalized | Out-Null
    return (Get-TaskBrokerFirmwareManagerText -Force)
}

function Set-TaskBrokerDefaultTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized) { throw 'Ungültiges Standardziel.' }
    if (-not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'Für dieses Firmwareziel existiert keine autorisierte Standardziel-Aufgabe.'
    }

    Invoke-AuthorizedTask -Operation 'DefaultSet' -Guid $normalized | Out-Null
}

function Clear-TaskBrokerDefaultTarget {
    if (-not (Test-TaskBrokerMetadataCompatible)) { throw 'TaskBroker-Metadaten verletzen den festen Boundary-Vertrag.' }
    Invoke-AuthorizedTask -Operation 'DefaultClear' | Out-Null
}
