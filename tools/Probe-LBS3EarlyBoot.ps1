#requires -version 5.1
<#
.SYNOPSIS
  LBS-3: temporary, read-only SYSTEM AtStartup readiness diagnostic.
.DESCRIPTION
  Install registers ONE fixed, separate read-only SYSTEM diagnostic task without
  changing LenovoBootSelector-* product tasks, BCD, firmware or boot order.
  Probe is invoked by that task on actual Windows startup. Collect reads results.
  Remove unregisters only this exact diagnostic task and preserves evidence.
  Explicit administrator consent is required to Install or Remove.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install','Probe','Collect','Remove')]
    [string]$Mode = 'Collect'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$taskName = 'LBS3-EarlyBoot-ReadOnly'
$probeRoot = Join-Path $env:ProgramData 'LBS3-EarlyBoot-ReadOnly'
$installedScript = Join-Path $probeRoot 'Probe-LBS3EarlyBoot.ps1'
$expectedExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$expectedArgs = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $installedScript + '" -Mode Probe'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this action from an explicitly elevated Windows PowerShell 5.1 process.'
    }
}

function Assert-NoReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('Refusing reparse-point path: ' + $Path)
    }
}

function New-ProtectedProbeDirectory {
    if (Test-Path -LiteralPath $probeRoot) {
        throw ('Probe directory already exists; refusing to reuse unknown contents: ' + $probeRoot)
    }
    [void][IO.Directory]::CreateDirectory($probeRoot)
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagate = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    foreach ($sidText in @('S-1-5-18','S-1-5-32-544')) {
        $sid = [Security.Principal.SecurityIdentifier]::new($sidText)
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$propagate,$allow)
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $probeRoot -AclObject $acl -ErrorAction Stop
    $actual = Get-Acl -LiteralPath $probeRoot -ErrorAction Stop
    if (-not $actual.AreAccessRulesProtected) { throw 'Probe root ACL inheritance is not protected.' }
    foreach ($rule in @($actual.Access)) {
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if ($rule.AccessControlType -eq 'Allow' -and $sid -notin @('S-1-5-18','S-1-5-32-544')) {
            throw 'Probe root has an unapproved allow ACE.'
        }
    }
}

function Get-ProbeTask {
    return (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
}

function Assert-ProbeTaskDefinition {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    if ($task.Principal.UserId -notin @('SYSTEM','S-1-5-18')) { throw 'Diagnostic task is not SYSTEM.' }
    if ([string]$task.State -eq 'Disabled') { throw 'Diagnostic task is disabled.' }
    if ([string]$task.Principal.RunLevel -ne 'Highest') { throw 'Diagnostic task run level is unexpected.' }
    $actions = @($task.Actions)
    if ($actions.Count -ne 1 -or
        -not [string]::Equals([string]$actions[0].Execute,$expectedExe,[StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals([string]$actions[0].Arguments,$expectedArgs,[StringComparison]::Ordinal)) {
        throw 'Diagnostic task action does not match the fixed protected script.'
    }
    [xml]$xml = (Export-ScheduledTask -TaskName $taskName -ErrorAction Stop)
    $triggers = @($xml.SelectNodes("/*[local-name()='Task']/*[local-name()='Triggers']/*"))
    if ($triggers.Count -ne 1 -or [string]$triggers[0].LocalName -ne 'BootTrigger') {
        throw 'Diagnostic task must have exactly one Windows boot trigger.'
    }
    $delayNode = $triggers[0].SelectSingleNode("./*[local-name()='Delay']")
    if ($delayNode) {
        $delay = [System.Xml.XmlConvert]::ToTimeSpan([string]$delayNode.InnerText)
        if ($delay.Ticks -ne 0) { throw 'Diagnostic boot trigger has an unwanted delay.' }
    }
}

function Read-OneShotReadiness {
    $record = [ordered]@{
        utc = [datetime]::UtcNow.ToString('o')
        bootIdentity = [ordered]@{ success = $false; bootUtc = $null; durationMs = $null; error = $null }
        firmware = [ordered]@{ success = $false; bootSequencePresent = $null; durationMs = $null; error = $null }
        broker = [ordered]@{ success = $false; metadataPresent = $false; defaultState = 'unknown'; lockPresent = $false; durationMs = $null; error = $null }
    }
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if (-not $os -or -not $os.LastBootUpTime) { throw 'LastBootUpTime is missing.' }
        $boot = ([datetime]$os.LastBootUpTime).ToUniversalTime()
        if ($boot.Year -lt 2000 -or $boot -gt [datetime]::UtcNow) { throw 'LastBootUpTime is implausible.' }
        $record.bootIdentity.success = $true
        $record.bootIdentity.bootUtc = $boot.ToString('o')
    }
    catch { $record.bootIdentity.error = $_.Exception.Message }
    finally { $record.bootIdentity.durationMs = $stopwatch.ElapsedMilliseconds }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $bcd = Join-Path $env:SystemRoot 'System32\bcdedit.exe'
        if (-not (Test-Path -LiteralPath $bcd -PathType Leaf)) { throw 'Windows BCDEdit executable not found.' }
        $output = (& $bcd /enum '{fwbootmgr}' /v 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) { throw ('BCDEdit /enum fwbootmgr failed with exit code ' + $LASTEXITCODE) }
        if ([string]::IsNullOrWhiteSpace($output)) { throw 'Firmware manager output was empty.' }
        $record.firmware.success = $true
        $record.firmware.bootSequencePresent = [bool]($output -match '(?im)^\s*bootsequence\s+\{[a-fA-F0-9-]{36}\}')
    }
    catch { $record.firmware.error = $_.Exception.Message }
    finally { $record.firmware.durationMs = $stopwatch.ElapsedMilliseconds }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $state = Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'
        $metaFile = Join-Path $state 'task-broker.json'
        $defaultFile = Join-Path $state 'Default\default-guid.txt'
        $lockFile = Join-Path $state 'Default\bootnext-writer.lock'
        $record.broker.metadataPresent = [IO.File]::Exists($metaFile)
        $record.broker.lockPresent = [IO.File]::Exists($lockFile)
        if (-not $record.broker.metadataPresent) { throw 'TaskBroker metadata absent.' }
        $meta = [IO.File]::ReadAllText($metaFile,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([string]$meta.boundaryContract -ne 'fixed-task-v2' -or
            [string]$meta.defaultRestoreTask -ne 'LenovoBootSelector-Default-Restore') {
            throw 'TaskBroker metadata boundary contract mismatch.'
        }
        if (-not $record.broker.lockPresent) { throw 'Boot writer lock file absent.' }
        if ([IO.File]::Exists($defaultFile)) {
            $guid = [IO.File]::ReadAllText($defaultFile).Trim().ToLowerInvariant()
            if ($guid -notmatch '^\{[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\}$') {
                throw 'Default target is malformed.'
            }
            $allowed = @($meta.targets | Where-Object { [string]$_.guid -eq $guid })
            if ($allowed.Count -ne 1) { throw 'Default target is not in the installed allowlist.' }
            $record.broker.defaultState = 'configured-allowlisted'
        }
        else { $record.broker.defaultState = 'not-configured' }
        $record.broker.success = $true
    }
    catch { $record.broker.error = $_.Exception.Message }
    finally { $record.broker.durationMs = $stopwatch.ElapsedMilliseconds }
    return $record
}

function Save-ProbeReport([string]$Path,$Data) {
    # Replace the previous checkpoint atomically. On interrupted execution the
    # first valid 'running' snapshot remains available for diagnosis.
    $tmp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $bak = $Path + '.' + [guid]::NewGuid().ToString('N') + '.bak'
    try {
        [IO.File]::WriteAllText($tmp,($Data | ConvertTo-Json -Depth 10),[Text.Encoding]::UTF8)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($tmp,$Path,$bak) }
        else { [IO.File]::Move($tmp,$Path) }
    }
    finally {
        if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
        if ([IO.File]::Exists($bak)) { [IO.File]::Delete($bak) }
    }
}

function Invoke-Probe {
    Assert-NoReparsePoint -Path $probeRoot
    Assert-NoReparsePoint -Path $installedScript
    if (-not (Test-Path -LiteralPath $probeRoot -PathType Container)) { throw 'Probe directory not installed.' }
    $runId = [guid]::NewGuid().ToString('N')
    $data = [ordered]@{
        schema = 1
        kind = 'LBS3-EarlyBoot-ReadOnly'
        runId = $runId
        startUtc = [datetime]::UtcNow.ToString('o')
        identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        identitySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        samples = @()
        completeUtc = $null
        state = 'running'
        writesFirmware = $false
    }
    $target = Join-Path $probeRoot ('probe-' + $runId + '.json')
    Save-ProbeReport -Path $target -Data $data
    # One immediate sample. On failure, bounded read-only follow-up samples
    # reveal earliest availability without introducing any runtime polling service.
    $elapsed = [Diagnostics.Stopwatch]::StartNew()
    foreach ($seconds in @(0,2,5,10,20)) {
        $remainingMs = [int][Math]::Ceiling(($seconds - $elapsed.Elapsed.TotalSeconds) * 1000)
        if ($remainingMs -gt 0) { Start-Sleep -Milliseconds $remainingMs }
        $offset = [Math]::Round($elapsed.Elapsed.TotalSeconds,3)
        $sample = Read-OneShotReadiness
        $sample['offsetSeconds'] = $offset
        $data.samples += $sample
        Save-ProbeReport -Path $target -Data $data
        if ($sample.bootIdentity.success -and $sample.firmware.success -and $sample.broker.success) { break }
    }
    $data.completeUtc = [datetime]::UtcNow.ToString('o')
    $data.state = 'completed'
    Save-ProbeReport -Path $target -Data $data
    # Bounded retention: at most 20 own diagnostic JSON files, never touch
    # other files or the product TaskBroker state.
    $owned = @(Get-ChildItem -LiteralPath $probeRoot -Filter 'probe-*.json' -File |
        Where-Object { $_.Name -match '^probe-[0-9a-f]{32}\.json$' } |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($owned.Count -gt 20) {
        foreach ($old in @($owned | Select-Object -Skip 20)) { Remove-Item -LiteralPath $old.FullName -Force -ErrorAction Stop }
    }
}

switch ($Mode) {
    'Install' {
        Assert-Administrator
        if (Get-ProbeTask) { throw ('Fixed diagnostic task already exists: ' + $taskName) }
        New-ProtectedProbeDirectory
        # Stage immutable-by-users code before registering a SYSTEM task.
        [IO.File]::Copy($PSCommandPath,$installedScript,$false)
        if ((Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $installedScript -Algorithm SHA256).Hash) {
            throw 'The protected diagnostic script differs from the source.'
        }
        $action = New-ScheduledTaskAction -Execute $expectedExe -Argument $expectedArgs
        $trigger = New-ScheduledTaskTrigger -AtStartup  # deliberately no Delay
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -ErrorAction Stop | Out-Null
        Assert-ProbeTaskDefinition
        Write-Host 'Installed read-only SYSTEM boot probe. No LenovoBootSelector-* task or firmware state changed.'
        Write-Host 'Restart Windows normally, then run this script with -Mode Collect in an elevated PowerShell 5.1 session.'
    }
    'Probe' { Invoke-Probe }
    'Collect' {
        Assert-Administrator
        Assert-NoReparsePoint -Path $probeRoot
        if (-not (Test-Path -LiteralPath $probeRoot -PathType Container)) {
            throw 'Probe directory not installed.'
        }
        $files = @(Get-ChildItem -LiteralPath $probeRoot -Filter 'probe-*.json' -File |
            Where-Object { $_.Name -match '^probe-[0-9a-f]{32}\.json$' } |
            Sort-Object LastWriteTimeUtc -Descending)
        if ($files.Count -eq 0) { Write-Warning 'No boot probe report has been written yet.' }
        foreach ($file in $files) {
            $report = [IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8) | ConvertFrom-Json
            $samples = @($report.samples)
            $first = if ($samples.Count -gt 0) { $samples[0] } else { $null }
            $last = if ($samples.Count -gt 0) { $samples[-1] } else { $null }
            [pscustomobject]@{
                File = $file.FullName
                RunId = $report.runId
                StartUtc = $report.startUtc
                Identity = $report.identity
                IdentitySid = $report.identitySid
                State = $report.state
                Samples = $samples.Count
                FirstBootIdOk = [bool]$(if ($first) { $first.bootIdentity.success } else { $false })
                FirstFirmwareOk = [bool]$(if ($first) { $first.firmware.success } else { $false })
                FirstBrokerOk = [bool]$(if ($first) { $first.broker.success } else { $false })
                FinalBootIdOk = [bool]$(if ($last) { $last.bootIdentity.success } else { $false })
                FinalFirmwareOk = [bool]$(if ($last) { $last.firmware.success } else { $false })
                FinalBrokerOk = [bool]$(if ($last) { $last.broker.success } else { $false })
            }
        }
    }
    'Remove' {
        Assert-Administrator
        if (Get-ProbeTask) {
            Assert-ProbeTaskDefinition
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        }
        Write-Host 'Only the exact LBS3-EarlyBoot-ReadOnly diagnostic task was removed.'
        Write-Host ('Collected JSON evidence remains in ' + $probeRoot)
    }
}
