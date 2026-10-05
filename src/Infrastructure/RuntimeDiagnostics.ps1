function Get-RuntimeDiagnosticRole {
    if ($BackgroundRefresh) { return 'background-refresh' }
    if ($UpdateCheck) { return 'update-check' }
    if ($UpdatePrepare) { return 'update-prepare' }
    return 'tray'
}

function ConvertTo-RuntimeDiagnosticText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $result = [string]$Text
    $pairs = @(
        @([string]$env:LOCALAPPDATA, '%LOCALAPPDATA%'),
        @([string]$env:USERPROFILE, '%USERPROFILE%'),
        @([string]$env:USERNAME, '<user>'),
        @([string]$env:COMPUTERNAME, '<computer>')
    )
    foreach ($pair in $pairs) {
        if (-not [string]$pair[0]) { continue }
        $result = [regex]::Replace($result, [regex]::Escape([string]$pair[0]), [string]$pair[1], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $result
}

function New-RuntimeDiagnosticData {
    param([hashtable]$Values)
    $result = [ordered]@{}
    if (-not $Values) { return $result }
    foreach ($key in @($Values.Keys)) {
        if (-not $key) { continue }
        $value = $Values[$key]
        if ($null -eq $value) { continue }
        if ($value -is [string]) { $value = ConvertTo-RuntimeDiagnosticText -Text $value }
        $result[[string]$key] = $value
    }
    return $result
}

function Initialize-RuntimeDiagnostics {
    try {
        $candidate = ([string]$RuntimeSessionId).Trim()
        if ($candidate) { $candidate = ($candidate -replace '[^A-Za-z0-9-]', '') }
        if (-not $candidate) { $candidate = [guid]::NewGuid().ToString('D') }

        $script:RuntimeSessionId = $candidate
        $script:RuntimeSessionStartedUtc = [datetime]::UtcNow
        $script:RuntimeSessionDir = Join-Path $script:RuntimeDiagnosticsRoot $candidate
        $script:RuntimeEventsPath = Join-Path $script:RuntimeSessionDir 'runtime.jsonl'
        if (-not (Test-Path -LiteralPath $script:RuntimeSessionDir)) {
            [void](New-Item -ItemType Directory -Path $script:RuntimeSessionDir -Force)
        }
        $script:RuntimeDiagnosticsAvailable = $true

        # Retention is deliberately conservative and best-effort. A diagnosis must
        # never prevent the tray from starting or a boot action from completing.
        try {
            $cutoff = [datetime]::UtcNow.AddDays(-30)
            foreach ($dir in @(Get-ChildItem -LiteralPath $script:RuntimeDiagnosticsRoot -Directory -ErrorAction SilentlyContinue)) {
                if ($dir.FullName -eq $script:RuntimeSessionDir) { continue }
                if ($dir.LastWriteTimeUtc -lt $cutoff) {
                    Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } catch { }

        Write-RuntimeDiagnosticEvent -Event $(if ($BackgroundRefresh) { 'BACKGROUND_WORKER_STARTED' } elseif ($UpdateCheck) { 'UPDATE_CHECK_WORKER_STARTED' } elseif ($UpdatePrepare) { 'UPDATE_PREPARE_WORKER_STARTED' } else { 'SESSION_STARTED' }) -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{
            role = (Get-RuntimeDiagnosticRole)
            parentSession = [bool]([string]$RuntimeSessionId)
        })
    }
    catch {
        $script:RuntimeDiagnosticsAvailable = $false
    }
}

function Write-RuntimeDiagnosticEvent {
    param(
        [Parameter(Mandatory=$true)][string]$Event,
        [string]$Stage = '',
        [AllowNull()][object]$Success = $null,
        [AllowNull()][object]$DurationMs = $null,
        [AllowNull()]$ErrorRecord = $null,
        [AllowNull()]$Data = $null,
        [ValidateSet('info','warning','error')][string]$Level = 'info'
    )

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeEventsPath) { return }
    try {
        $record = [ordered]@{
            utc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            appVersion = $script:AppVersion
            processId = $PID
            role = (Get-RuntimeDiagnosticRole)
            event = $Event
            stage = $Stage
            level = $Level
        }
        if ($null -ne $Success) { $record.success = [bool]$Success }
        if ($null -ne $DurationMs) { $record.durationMs = [int64]$DurationMs }

        if ($ErrorRecord) {
            $exception = $null
            if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $exception = $ErrorRecord.Exception }
            elseif ($ErrorRecord -is [System.Exception]) { $exception = $ErrorRecord }
            elseif ($ErrorRecord.Exception) { $exception = $ErrorRecord.Exception }
            if ($exception) {
                $record.errorClass = $exception.GetType().FullName
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$exception.Message)
            }
            else {
                $record.errorClass = 'UnknownError'
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$ErrorRecord)
            }
            $script:RuntimeDiagnosticsErrorCount++
        }

        if ($Data) { $record.data = $Data }
        $json = $record | ConvertTo-Json -Depth 10 -Compress

        # FileShare.ReadWrite allows the tray and its hidden refresh child to append
        # to the same session log. Logging is single-attempt/best-effort: diagnostics
        # must never introduce retry delays into a boot or task action.
        try {
            $stream = [System.IO.FileStream]::new($script:RuntimeEventsPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
            try {
                $writer = [System.IO.StreamWriter]::new($stream, (New-Object System.Text.UTF8Encoding($false)))
                try { $writer.WriteLine($json); $writer.Flush() }
                finally { $writer.Dispose() }
            }
            finally { if ($stream) { $stream.Dispose() } }
        }
        catch { }
    }
    catch { }
}

function Get-RuntimeDiagnosticBrokerSummary {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return [ordered]@{ present = $false } }
    $targets = @()
    foreach ($target in @($meta.targets)) {
        $targets += [ordered]@{
            guid = [string]$target.guid
            taskName = [string]$target.taskName
            defaultTaskName = [string]$target.defaultTaskName
        }
    }
    return [ordered]@{
        present = $true
        version = [string]$meta.version
        installedUtc = [string]$meta.installedUtc
        managerRefreshTask = [string]$meta.managerRefreshTask
        firmwareRefreshTask = [string]$meta.firmwareRefreshTask
        defaultClearTask = [string]$meta.defaultClearTask
        defaultRestoreTask = [string]$meta.defaultRestoreTask
        defaultRestoreDelaySeconds = $meta.defaultRestoreDelaySeconds
        targetCount = @($targets).Count
        targets = @($targets)
    }
}

function Export-RuntimeDiagnosticPackage {
    param([string]$Reason = 'manual')

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeSessionId) {
        throw 'Für diese Sitzung sind keine Runtime-Diagnosedaten verfügbar.'
    }

    $exportRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
    if (-not (Test-Path -LiteralPath $exportRoot)) { [void](New-Item -ItemType Directory -Path $exportRoot -Force) }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $shortSession = if ($script:RuntimeSessionId.Length -ge 8) { $script:RuntimeSessionId.Substring(0,8) } else { $script:RuntimeSessionId }
    $zipPath = Join-Path $exportRoot ("Lenovo-Boot-Selector-Diagnostics-{0}-{1}.zip" -f $stamp,$shortSession)
    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("LenovoBootSelectorDiag-{0}" -f ([guid]::NewGuid().ToString('N')))

    Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_REQUESTED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason; outputName = [System.IO.Path]::GetFileName($zipPath) })

    try {
        [void](New-Item -ItemType Directory -Path $stage -Force)
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            Copy-Item -LiteralPath $script:RuntimeEventsPath -Destination (Join-Path $stage 'runtime.jsonl') -Force
        }
        else {
            [System.IO.File]::WriteAllText((Join-Path $stage 'runtime.jsonl'), '', (New-Object System.Text.UTF8Encoding($false)))
        }

        $environment = [ordered]@{
            exportedUtc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            sessionStartedUtc = $script:RuntimeSessionStartedUtc.ToString('o')
            appVersion = $script:AppVersion
            taskBrokerSchemaSupported = @($script:SupportedTaskBrokerVersions)
            osVersion = [Environment]::OSVersion.VersionString
            os64Bit = [Environment]::Is64BitOperatingSystem
            process64Bit = [Environment]::Is64BitProcess
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            clrVersion = [Environment]::Version.ToString()
            role = (Get-RuntimeDiagnosticRole)
            lastBackgroundRefreshTiming = $(if ($script:BackgroundRefreshState) { $script:BackgroundRefreshState.LastTiming } else { $null })
        }
        [System.IO.File]::WriteAllText((Join-Path $stage 'environment.json'), ($environment | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $broker = Get-RuntimeDiagnosticBrokerSummary
        [System.IO.File]::WriteAllText((Join-Path $stage 'task-broker-summary.json'), ($broker | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $eventCount = 0
        $errorCount = 0
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            foreach ($line in @([System.IO.File]::ReadAllLines($script:RuntimeEventsPath, [System.Text.Encoding]::UTF8))) {
                if (-not $line) { continue }
                $eventCount++
                if ($line -match '"level":"error"') { $errorCount++ }
            }
        }
        $summary = @(
            'Lenovo Boot Selector – Runtime-Diagnose',
            "App-Version: $($script:AppVersion)",
            "Session: $($script:RuntimeSessionId)",
            "Sitzungsstart (UTC): $($script:RuntimeSessionStartedUtc.ToString('o'))",
            "Export (UTC): $([datetime]::UtcNow.ToString('o'))",
            "Grund: $Reason",
            "Events: $eventCount",
            "Fehler-Events: $errorCount",
            '',
            'Enthalten sind ausschließlich die aktuelle Runtime-Sitzung sowie technische Environment-/TaskBroker-Metadaten.',
            'Benutzername, Rechnername und TaskBroker-userSid werden nicht exportiert.'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText((Join-Path $stage 'summary.txt'), $summary, (New-Object System.Text.UTF8Encoding($false)))

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        $script:LastRuntimeDiagnosticPackage = $zipPath
        return $zipPath
    }
    finally {
        try { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } } catch { }
    }
}

function Show-DiagnosticPackageInExplorer {
    param([Parameter(Mandatory=$true)][string]$Path)

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Das Diagnosepaket ist nicht mehr vorhanden.' }
        $explorer = Join-Path $env:WINDIR 'explorer.exe'
        if (-not (Test-Path -LiteralPath $explorer -PathType Leaf)) { $explorer = 'explorer.exe' }
        $safePath = $Path.Replace('"','')
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $explorer
        $psi.Arguments = ('/select,"{0}"' -f $safePath)
        $psi.UseShellExecute = $true
        [void][System.Diagnostics.Process]::Start($psi)
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) })
        return $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) }) -Level warning
        return $false
    }
}
