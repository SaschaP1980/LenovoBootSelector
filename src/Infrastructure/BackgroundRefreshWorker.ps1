function Start-BackgroundRefreshWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [AllowNull()][string]$RuntimeSessionId
    )

    $powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-BackgroundRefresh',
        '-BackgroundResultPath', ('"{0}"' -f $ResultPath)
    )
    if ($RefreshStorage) { $args += '-BackgroundRefreshStorage' }
    if ($RefreshFirmware) { $args += '-BackgroundRefreshFirmware' }
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershellExe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process = [System.Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Hintergrundprozess konnte nicht gestartet werden.' }
    return $process
}

function Read-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw 'Der Hintergrund-Refresh hat kein Ergebnis geliefert.'
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Remove-BackgroundRefreshResultFile {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return }
    try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch { }
}

function Invoke-BackgroundRefreshWorker {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [AllowNull()][string]$ResultPath
    )

    $total = [System.Diagnostics.Stopwatch]::StartNew()
    $timings = [ordered]@{ ReadyMs = 0; ManagerMs = 0; FirmwareMs = 0; StorageMs = 0; TotalMs = 0 }
    $result = [ordered]@{ Success = $false; Error = $null; Stage = 'ready'; StorageContext = $null; Timings = $timings }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if (-not (Test-TaskBrokerReady -Force)) { throw 'Die Systemfunktionen sind nicht vollständig verfügbar.' }
        $sw.Stop(); $timings.ReadyMs = $sw.ElapsedMilliseconds

        $result.Stage = 'manager'
        $sw.Restart(); [void](Get-TaskBrokerFirmwareManagerText -Force); $sw.Stop(); $timings.ManagerMs = $sw.ElapsedMilliseconds
        if ($RefreshFirmware) {
            $result.Stage = 'firmware'
            $sw.Restart(); [void](Get-TaskBrokerFirmwareEntriesText -Force); $sw.Stop(); $timings.FirmwareMs = $sw.ElapsedMilliseconds
        }

        if ($RefreshStorage) {
            $result.Stage = 'storage'
            $sw.Restart(); $result.StorageContext = Get-StorageContext; $sw.Stop(); $timings.StorageMs = $sw.ElapsedMilliseconds
        }
        $result.Stage = 'complete'
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    finally {
        $total.Stop(); $timings.TotalMs = $total.ElapsedMilliseconds
        if ($ResultPath) {
            try {
                $parent = Split-Path -Parent $ResultPath
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                $json = $result | ConvertTo-Json -Depth 8
                [System.IO.File]::WriteAllText($ResultPath, $json, (New-Object System.Text.UTF8Encoding($false)))
            }
            catch { }
        }
    }

    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $timings.TotalMs -Data (New-RuntimeDiagnosticData @{ readyMs = $timings.ReadyMs; managerMs = $timings.ManagerMs; firmwareMs = $timings.FirmwareMs; storageMs = $timings.StorageMs; workerError = [string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    if ($result.Success) { return 0 }
    return 1
}
