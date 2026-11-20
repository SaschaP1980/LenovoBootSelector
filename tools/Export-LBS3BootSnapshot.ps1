#requires -version 5.1
# LBS-3: manual, read-only snapshot for physical no-delay startup acceptance.
# Never launch LBS UI, schedule tasks, write firmware, or mutate protected TaskBroker state.
[CmdletBinding()]
param(
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Join-Path $env:USERPROFILE 'Downloads') 'LBS3-BootEvidence'
}

function Normalize-Lbs3Guid {
    param([AllowNull()][string]$Value)
    $candidate = ([string]$Value).Trim().ToLowerInvariant()
    if ($candidate -notmatch '^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$') {
        return $null
    }
    return $candidate
}

$root = Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'
$metadataPath = Join-Path $root 'task-broker.json'
$defaultPath = Join-Path (Join-Path $root 'Default') 'default-guid.txt'
$originPath = Join-Path (Join-Path $root 'Default') 'bootnext-origin.json'
$taskName = 'LenovoBootSelector-Default-Restore'
$bcd = Join-Path $env:SystemRoot 'System32\bcdedit.exe'
$report = [ordered]@{
    schema = 1
    purpose = 'LBS3-Undelayed-DefaultRestore-ReadOnly'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    bootUtc = $null
    bootId = $null
    # Deliberately omit user and machine names from exported diagnostics.
    metadataVersion = $null
    metadataDelaySeconds = $null
    defaultGuid = $null
    allowedTargetCount = 0
    provenance = [ordered]@{
        present = $false
        schema = $null
        bootId = $null
        isCurrentBoot = $false
        kind = $null
        guid = $null
        sequence = $null
    }
    task = [ordered]@{
        definitionRead = $false
        exactlyOneBootTrigger = $false
        hasNoDelayElement = $false
        enabled = $null
        lastRunUtc = $null
        lastTaskResult = $null
        ranInCurrentBoot = $false
    }
    firmware = [ordered]@{
        readSucceeded = $false
        bootSequencePresent = $false
        bootSequenceGuid = $null
    }
    result = 'UNVERIFIED'
    errors = @()
    writesFirmware = $false
}
$allowed = @()

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    if (-not $os -or -not $os.LastBootUpTime) { throw 'LastBootUpTime unavailable.' }
    $bootUtc = ([datetime]$os.LastBootUpTime).ToUniversalTime()
    $report.bootUtc = $bootUtc.ToString('o')
    $report.bootId = [string]$bootUtc.Ticks
}
catch { $report.errors += 'BOOT_ID: ' + $_.Exception.Message }

try {
    $metadata = [IO.File]::ReadAllText($metadataPath,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
    $report.metadataVersion = [string]$metadata.version
    $report.metadataDelaySeconds = $metadata.defaultRestoreDelaySeconds
    if ([string]$metadata.boundaryContract -ne 'fixed-task-v2') { throw 'Unexpected TaskBroker boundary.' }
    if ([string]$metadata.defaultRestoreTask -ne $taskName) { throw 'Unexpected restore task name.' }
    if ([string]$metadata.version -ne '0.2.16') { throw 'New undelayed TaskBroker schema is not installed. Run elevated Repair.' }
    if ($null -eq $metadata.PSObject.Properties['defaultRestoreDelaySeconds'] -or [int]$metadata.defaultRestoreDelaySeconds -ne 0) {
        throw 'Metadata still indicates a configured startup delay.'
    }
    foreach ($target in @($metadata.targets)) {
        $guid = Normalize-Lbs3Guid -Value ([string]$target.guid)
        if (-not $guid) { throw 'Invalid allowlisted target in metadata.' }
        $allowed += $guid
    }
    if ($allowed.Count -eq 0 -or @($allowed | Select-Object -Unique).Count -ne $allowed.Count) {
        throw 'Invalid target allowlist.'
    }
    $report.allowedTargetCount = $allowed.Count
}
catch { $report.errors += 'METADATA: ' + $_.Exception.Message }

try {
    if (-not [IO.File]::Exists($defaultPath)) { throw 'No system-wide default target configured.' }
    $value = Normalize-Lbs3Guid -Value ([IO.File]::ReadAllText($defaultPath,[Text.Encoding]::ASCII))
    if (-not $value) { throw 'Invalid configured default GUID.' }
    if ($value -notin $allowed) { throw 'Configured default is not in the metadata allowlist.' }
    $report.defaultGuid = $value
}
catch { $report.errors += 'DEFAULT: ' + $_.Exception.Message }

try {
    if (-not [IO.File]::Exists($originPath)) { throw 'No protected BootNext provenance for this boot.' }
    $origin = [IO.File]::ReadAllText($originPath,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
    $report.provenance.present = $true
    $report.provenance.schema = $origin.schema
    $report.provenance.bootId = [string]$origin.bootId
    $report.provenance.kind = [string]$origin.kind
    $report.provenance.guid = Normalize-Lbs3Guid -Value ([string]$origin.guid)
    $report.provenance.sequence = $origin.seq
    $report.provenance.isCurrentBoot = ($null -ne $report.bootId -and [string]$origin.bootId -ceq [string]$report.bootId)
    if ([int]$origin.schema -ne 1 -or [string]$origin.kind -notin @('auto','manual','pending-auto','pending-manual') -or
        -not $report.provenance.guid -or $report.provenance.guid -notin $allowed -or
        $null -eq $origin.seq -or [int64]$origin.seq -lt 1) {
        throw 'Invalid protected provenance record.'
    }
    if (-not $report.provenance.isCurrentBoot) { throw 'Provenance belongs to another Windows boot cycle.' }
}
catch { $report.errors += 'PROVENANCE: ' + $_.Exception.Message }

try {
    [xml]$taskXml = Export-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $report.task.definitionRead = $true
    $nodes = @($taskXml.SelectNodes("/*[local-name()='Task']/*[local-name()='Triggers']/*"))
    $report.task.exactlyOneBootTrigger = ($nodes.Count -eq 1 -and [string]$nodes[0].LocalName -eq 'BootTrigger')
    if (-not $report.task.exactlyOneBootTrigger) { throw 'Expected exactly one BootTrigger.' }
    $report.task.hasNoDelayElement = ($null -eq $nodes[0].SelectSingleNode("./*[local-name()='Delay']"))
    if (-not $report.task.hasNoDelayElement) { throw 'Task still has a configured Delay.' }
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $report.task.enabled = ([string]$task.State -ne 'Disabled')
    if (-not $report.task.enabled) { throw 'Default Restore task is disabled.' }
    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
    $report.task.lastRunUtc = ([datetime]$info.LastRunTime).ToUniversalTime().ToString('o')
    $report.task.lastTaskResult = [uint32]$info.LastTaskResult
    if ($report.bootUtc) {
        $report.task.ranInCurrentBoot = ([datetime]$info.LastRunTime).ToUniversalTime() -ge ([datetime]::Parse($report.bootUtc).ToUniversalTime())
    }
}
catch { $report.errors += 'SCHEDULED_TASK: ' + $_.Exception.Message }

try {
    if (-not [IO.File]::Exists($bcd)) { throw 'Windows BCDEdit executable is missing.' }
    $text = (& $bcd /enum '{fwbootmgr}' /v 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($text)) {
        throw 'Firmware manager enumeration failed or returned no data.'
    }
    $report.firmware.readSucceeded = $true
    if ($text -match '(?im)^\s*bootsequence\s+(\{[0-9a-fA-F-]{36}\})') {
        $report.firmware.bootSequenceGuid = Normalize-Lbs3Guid -Value $Matches[1]
        $report.firmware.bootSequencePresent = [bool]$report.firmware.bootSequenceGuid
    }
    if (-not $report.firmware.bootSequencePresent) {
        throw 'Bootsequence was not found or could not be parsed in BCDEdit output.'
    }
}
catch { $report.errors += 'FIRMWARE: ' + $_.Exception.Message }

if ($report.errors.Count -eq 0 -and $report.task.ranInCurrentBoot -and
    [uint32]$report.task.lastTaskResult -eq 0 -and $report.task.enabled -and
    $report.provenance.kind -eq 'auto' -and $report.provenance.isCurrentBoot -and
    $report.provenance.guid -eq $report.defaultGuid -and
    $report.firmware.bootSequenceGuid -eq $report.defaultGuid) {
    $report.result = 'AUTO_DEFAULT_CONFIRMED'
}
elseif ($report.errors.Count -eq 0 -and $report.task.ranInCurrentBoot -and
    [uint32]$report.task.lastTaskResult -eq 0 -and
    $report.provenance.kind -eq 'manual' -and $report.provenance.isCurrentBoot -and
    $report.firmware.bootSequenceGuid -eq $report.provenance.guid) {
    $report.result = 'MANUAL_PRIORITY_CONFIRMED'
}

[void][IO.Directory]::CreateDirectory($OutputDirectory)
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$name = 'LBS3-BootEvidence-' + $stamp + '-' + [guid]::NewGuid().ToString('N') + '.json'
$destination = Join-Path $OutputDirectory $name
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($destination,($report | ConvertTo-Json -Depth 8),$utf8)
Write-Host ('LBS3 result: {0}' -f $report.result)
Write-Host ('Evidence: {0}' -f $destination)
if ($report.errors.Count -gt 0) { Write-Host ('Checks needing review: {0}' -f ($report.errors -join '; ')) }
