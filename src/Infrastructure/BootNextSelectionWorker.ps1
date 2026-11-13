# A separate UNELEVATED PowerShell process executes one allowlisted BootNext
# request. The fixed SYSTEM TaskBroker remains the ONLY privileged writer.
function Start-BootNextSelectionWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [Parameter(Mandatory=$true)][string]$Guid,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [AllowNull()][string]$RuntimeSessionId
    )
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    if (-not $normalized -or -not (Get-TaskBrokerTarget -Guid $normalized)) {
        throw 'BootNext worker target is not on the installed firmware allowlist.'
    }
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $parts = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-BootNextWorker', '-BootNextGuid', ('"{0}"' -f $normalized),
        '-BootNextResultPath', ('"{0}"' -f $ResultPath)
    )
    if ($RuntimeSessionId) { $parts += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($parts -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $process = [Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'BootNext worker could not start.' }
    return $process
}

function Invoke-BootNextSelectionWorker {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [Parameter(Mandatory=$true)][string]$ResultPath
    )
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $normalized = Normalize-TaskBrokerGuid -Guid $Guid
    $result = [ordered]@{ Success=$false; Guid=[string]$normalized; Error='' }
    try {
        if (-not $normalized) { throw 'Invalid BootNext worker GUID.' }
        $verified = Set-BootNextTargetService -Guid $normalized
        if ([int]$verified.ExitCode -ne 0 -or [string]$verified.Guid -ne $normalized) {
            throw 'BootNext worker did not verify the selected firmware target.'
        }
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        try {
            $parent = Split-Path -Parent $ResultPath
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                throw 'BootNext worker result directory is missing.'
            }
            $json = $result | ConvertTo-Json -Compress -Depth 4
            [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))
        }
        catch { $result.Success = $false }
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_WORKER_COMPLETED' -Stage 'bootnext' -Success ([bool]$result.Success) -DurationMs $stopwatch.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            guid=$normalized; workerError=[string]$result.Error
        }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    }
    if ($result.Success) { return 0 }
    return 1
}
