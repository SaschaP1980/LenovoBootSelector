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

# Safety boundary: only exact task names and the two explicit project-owned
# per-GUID prefixes are eligible for removal. No generic Lenovo wildcard is used.
$exactTaskNames = @(
    'Lenovo Boot Menu Next',
    'Lenovo Boot Menu Tray Autostart',
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
$ownedPrefixes = @(
    'LenovoBootMenu-Set-',
    'LenovoBootMenu-Default-Set-'
)

$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $name = [string]$_.TaskName
    if ($exactTaskNames -contains $name) { return $true }
    foreach ($prefix in $ownedPrefixes) {
        if ($name.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
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

$oldBrokerRoot = Join-Path ${env:ProgramFiles} 'Lenovo Boot Menu\Broker'
if (Test-Path -LiteralPath $oldBrokerRoot) {
    Remove-Item -LiteralPath $oldBrokerRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# System-wide TaskBroker metadata, firmware caches and default state.
$stateRoot = Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'
if (Test-Path -LiteralPath $stateRoot) {
    Remove-Item -LiteralPath $stateRoot -Recurse -Force -ErrorAction Stop
}
$projectRoot = Split-Path $stateRoot -Parent
if (Test-Path -LiteralPath $projectRoot) {
    $remaining = @(Get-ChildItem -LiteralPath $projectRoot -Force -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) { Remove-Item -LiteralPath $projectRoot -Force -ErrorAction SilentlyContinue }
}

Write-Host ('Lenovo Boot Menu: {0} projektbezogene Scheduled Tasks entfernt.' -f $removed.Count)
foreach ($name in $removed) { Write-Host ('  - ' + $name) }
Write-Host 'Systemweiter TaskBroker-/Default-Zustand wurde bereinigt.'
