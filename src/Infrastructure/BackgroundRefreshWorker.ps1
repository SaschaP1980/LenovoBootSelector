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
