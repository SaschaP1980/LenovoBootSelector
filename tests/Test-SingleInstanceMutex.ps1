#requires -version 5.1
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "${Name}: expected true" }
    Write-Host "PASS  $Name"
}
function Assert-False([bool]$Condition, [string]$Name) {
    if ($Condition) { throw "${Name}: expected false" }
    Write-Host "PASS  $Name"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-MutexTest-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot -Force)
$childPath = Join-Path $testRoot 'MutexChild.ps1'
$childSource = @'
param([string]$Name, [string]$ReadyPath, [ValidateSet('hold','abandon')][string]$Mode, [string]$ExitPath)
$ErrorActionPreference = 'Stop'
$m = [System.Threading.Mutex]::new($false, $Name)
$owned = $false
try {
    $owned = $m.WaitOne(0, $false)
    if (-not $owned) { exit 7 }
    [System.IO.File]::WriteAllText($ReadyPath, 'ready', [System.Text.Encoding]::ASCII)
    if ($Mode -eq 'hold') {
        Start-Sleep -Milliseconds 900
        $m.ReleaseMutex()
        $owned = $false
    }
    else {
        # Keep the named object alive until the parent has opened its own handle.
        $deadline = [datetime]::UtcNow.AddSeconds(5)
        while ([datetime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $ExitPath)) {
            Start-Sleep -Milliseconds 25
        }
        if (-not (Test-Path -LiteralPath $ExitPath)) { exit 8 }
        # Exit while still owning the mutex so the parent can verify recovery.
        exit 0
    }
}
finally {
    if ($Mode -eq 'hold' -and $owned) { try { $m.ReleaseMutex() } catch { } }
    if ($Mode -eq 'hold') { try { $m.Dispose() } catch { } }
}
'@
[System.IO.File]::WriteAllText($childPath, $childSource, (New-Object System.Text.UTF8Encoding($true)))

function Start-MutexChild([string]$Name, [string]$ReadyPath, [string]$Mode, [string]$ExitPath = '') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $PSHOME 'powershell.exe'
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Name "{1}" -ReadyPath "{2}" -Mode {3} -ExitPath "{4}"' -f $childPath, $Name, $ReadyPath, $Mode, $ExitPath)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    return [System.Diagnostics.Process]::Start($psi)
}
function Wait-Ready([string]$Path, [System.Diagnostics.Process]$Process) {
    $deadline = [datetime]::UtcNow.AddSeconds(5)
    while ([datetime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path) { return }
        if ($Process.HasExited) { throw "Child exited before acquiring mutex. ExitCode=$($Process.ExitCode)" }
        Start-Sleep -Milliseconds 25
    }
    throw 'Timed out waiting for child mutex acquisition.'
}

$checks = 0
try {
    # Active-owner behavior: parent must not acquire while child owns, then must acquire after release.
    $name = 'Local\LenovoBootSelectorTest-' + [guid]::NewGuid().ToString('N')
    $ready = Join-Path $testRoot 'hold.ready'
    $child = Start-MutexChild -Name $name -ReadyPath $ready -Mode 'hold'
    Wait-Ready -Path $ready -Process $child
    $m = [System.Threading.Mutex]::new($false, $name)
    $owned = $false
    try {
        $owned = $m.WaitOne(0, $false)
        Assert-False $owned 'Active owner blocks nonblocking acquisition'; $checks++
        [void]$child.WaitForExit(5000)
        if (-not $child.HasExited -or $child.ExitCode -ne 0) { throw 'Hold child did not exit cleanly.' }
        $owned = $m.WaitOne(1000, $false)
        Assert-True $owned 'Released named mutex can be acquired'; $checks++
    }
    finally {
        if ($owned) { try { $m.ReleaseMutex() } catch { } }
        try { $m.Dispose() } catch { }
        try { $child.Dispose() } catch { }
    }

    # Abandoned-owner behavior: WaitOne must transfer ownership via AbandonedMutexException.
    $name2 = 'Local\LenovoBootSelectorAbandonedTest-' + [guid]::NewGuid().ToString('N')
    $ready2 = Join-Path $testRoot 'abandon.ready'
    $exit2 = Join-Path $testRoot 'abandon.exit'
    $child2 = Start-MutexChild -Name $name2 -ReadyPath $ready2 -Mode 'abandon' -ExitPath $exit2
    Wait-Ready -Path $ready2 -Process $child2
    # Hold a parent handle before the owner exits. Otherwise the kernel object is
    # destroyed with the child's last handle and reopening creates a clean mutex.
    $m2 = [System.Threading.Mutex]::OpenExisting($name2)
    [System.IO.File]::WriteAllText($exit2, 'exit', [System.Text.Encoding]::ASCII)
    [void]$child2.WaitForExit(5000)
    if (-not $child2.HasExited -or $child2.ExitCode -ne 0) { throw 'Abandon child did not exit cleanly.' }
    $owned2 = $false
    $abandonedRecovered = $false
    try {
        try { $owned2 = $m2.WaitOne(1000, $false) }
        catch [System.Threading.AbandonedMutexException] {
            $owned2 = $true
            $abandonedRecovered = $true
        }
        Assert-True $abandonedRecovered 'Abandoned mutex is reported and recoverable'; $checks++
        Assert-True $owned2 'Abandoned mutex ownership transfers to new process'; $checks++
    }
    finally {
        if ($owned2) { try { $m2.ReleaseMutex() } catch { } }
        try { $m2.Dispose() } catch { }
        try { $child2.Dispose() } catch { }
    }
}
finally {
    try { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
Write-Host "MUTEX TOTAL $checks/4"
