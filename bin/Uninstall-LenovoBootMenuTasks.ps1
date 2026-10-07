#requires -version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw 'Dieses Bereinigungsskript muss erhöht ausgeführt werden.'
}

# Safety boundary: only exact task names and exact project-owned per-GUID
# patterns are eligible for removal. No generic Lenovo wildcard is used.
$exactTaskNames = @(
    'Lenovo Boot Menu Next',
    'Lenovo Boot Menu Tray Autostart',
    'LenovoBootSelector-RefreshManager',
    'LenovoBootSelector-RefreshFirmware',
    'LenovoBootSelector-Default-Clear',
    'LenovoBootSelector-Default-Restore',
    'LenovoBootMenu-RefreshManager',
    'LenovoBootMenu-RefreshFirmware',
    'LenovoBootMenu-Default-Clear',
    'LenovoBootMenu-Default-Restore',
    'LenovoBootMenu-AclProbe',
    'LenovoBootMenu-ElevationProbe',
    'LenovoBootMenu-SystemReadProbe',
    'LenovoBootMenu-SystemExecProbe',
    'LenovoBootMenu-SystemBaseline',
    'LenovoBootMenuBroker-SystemProbe'
)

function Test-OwnedTaskName {
    param([AllowEmptyString()][string]$TaskName)
    if ([string]::IsNullOrWhiteSpace($TaskName)) { return $false }
    if ($exactTaskNames -contains $TaskName) { return $true }
    if ($TaskName -match '^LenovoBootSelector-Set-[0-9a-fA-F]{32}$') { return $true }
    if ($TaskName -match '^LenovoBootSelector-Default-Set-[0-9a-fA-F]{32}$') { return $true }
    if ($TaskName -match '^LenovoBootMenu-Set-[0-9a-fA-F]{32}$') { return $true }
    if ($TaskName -match '^LenovoBootMenu-Default-Set-[0-9a-fA-F]{32}$') { return $true }
    return $false
}

$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    Test-OwnedTaskName -TaskName ([string]$_.TaskName)
})

$removed = New-Object System.Collections.Generic.List[string]
foreach ($task in $tasks) {
    $name = [string]$task.TaskName
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction Stop
    [void]$removed.Add($name)
}

# Historical custom SYSTEM broker from early prototypes, if still present.
try {
    $svc = Get-Service -Name 'LenovoBootMenuBroker' -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') { Stop-Service -Name 'LenovoBootMenuBroker' -Force -ErrorAction SilentlyContinue }
        & (Join-Path $env:SystemRoot 'System32\sc.exe') delete LenovoBootMenuBroker | Out-Null
    }
} catch { }

$oldBrokerRoot = Join-Path $env:ProgramFiles 'Lenovo Boot Menu\Broker'
if (Test-Path -LiteralPath $oldBrokerRoot) {
    Remove-Item -LiteralPath $oldBrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove both the canonical v0.10+ state and the exact pre-v0.10 legacy state.
$stateRoots = @(
    (Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'),
    (Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker')
)
foreach ($stateRoot in $stateRoots) {
    if (Test-Path -LiteralPath $stateRoot) {
        Remove-Item -LiteralPath $stateRoot -Recurse -Force -ErrorAction Stop
    }
    $projectRoot = Split-Path $stateRoot -Parent
    if (Test-Path -LiteralPath $projectRoot) {
        $remaining = @(Get-ChildItem -LiteralPath $projectRoot -Force -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) { Remove-Item -LiteralPath $projectRoot -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ('Lenovo Boot Selector: {0} projektbezogene Scheduled Tasks entfernt.' -f $removed.Count)
foreach ($name in $removed) { Write-Host ('  - ' + $name) }
Write-Host 'Systemweiter TaskBroker-/Default-Zustand wurde bereinigt.'
