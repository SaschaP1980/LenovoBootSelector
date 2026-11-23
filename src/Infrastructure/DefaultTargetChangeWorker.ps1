# LBS-206: unelevated persistent-default worker. The fixed allowlisted
# TaskBroker SYSTEM tasks remain the only privileged writers. UI is not created.
function Start-DefaultTargetWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [AllowNull()][string]$Guid,
        [bool]$Clear,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)][string]$ProgressPath,
        [AllowNull()][string]$RuntimeSessionId
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $Clear -and (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized))) {
        throw 'The requested default target is not in the authorized firmware allowlist.'
    }
    if ($Clear -and $Guid) { throw 'Clear default operation cannot name a target.' }

    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-DefaultTargetWorker',
        '-DefaultTargetResultPath', ('"{0}"' -f $ResultPath),
        '-DefaultTargetProgressPath', ('"{0}"' -f $ProgressPath)
    )
    if ($Clear) { $args += '-DefaultTargetClear' }
    else { $args += @('-DefaultTargetGuid', ('"{0}"' -f $normalized)) }
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $process = [Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Default target worker could not start.' }
    return $process
}

function Invoke-DefaultTargetWorker {
    param(
        [AllowNull()][string]$Guid,
        [bool]$Clear,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)][string]$ProgressPath
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $operation = if ($Clear) { 'clear' } else { 'set' }
    $result = [ordered]@{
        Success = $false
        Operation = $operation
        RequestedGuid = if ($Clear) { '' } else { [string]$normalized }
        SavedGuid = ''
        NextGuid = ''
        NextVerified = $false
        Stage = 'admission'
        Error = ''
    }
    try {
        if ($Clear -and $Guid) { throw 'Clear worker must not carry a target.' }
        if (-not $Clear -and (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized))) {
            throw 'Default target is not allowlisted.'
        }
        $result.Stage = 'saving'
        # Only the original guarded writer is allowed to persist a default.
        # Its optional progress marker is written AFTER the authorized task
        # returns, and BEFORE its independent default/firmware readback.
        Set-DefaultGuid -Guid $(if ($Clear) { $null } else { $normalized }) -ProgressPath $ProgressPath
        if ($Clear -and $script:DefaultGuid) { throw 'Clear was not verified.' }
        if (-not $Clear -and [string]$script:DefaultGuid -ne $normalized) {
            throw 'Saved default does not match the requested target.'
        }
        $result.SavedGuid = [string]$script:DefaultGuid
        $result.NextGuid = [string]$script:SelectedGuid
        $result.NextVerified = [bool]$script:NextBootFirmwareReadVerified
        $result.Stage = if ($result.NextVerified) { 'complete' } else { 'next-unverified' }
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
        $result.Stage = 'failed'
    }
    finally {
        $sw.Stop()
        try {
            if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultPath) -PathType Container)) {
                throw 'Default worker result directory does not exist.'
            }
            $json = $result | ConvertTo-Json -Compress -Depth 4
            [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))
        }
        catch { $result.Success = $false }
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            operation=$operation; targetGuid=[string]$result.RequestedGuid
            nextVerified=[bool]$result.NextVerified; workerError=[string]$result.Error
        }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    }
    if ($result.Success) { return 0 }
    return 1
}
