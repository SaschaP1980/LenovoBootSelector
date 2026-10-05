#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Application\RefreshRuntime.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Core\FirmwareParsing.ps1')

$checks = 0
function Assert-SoakTest {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "${Name}: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

# Exercise the complete request -> active -> pending -> completion lifecycle repeatedly.
$refreshOk = $true
for ($i = 0; $i -lt 500; $i++) {
    $state = New-BackgroundRefreshRuntimeState
    $active = New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true
    $process = [pscustomobject]@{ Id = (1000 + $i) }
    Set-BackgroundRefreshActive -State $state -Process $process -ResultPath ("result-{0}.json" -f $i) -Request $active
    [void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $false))
    [void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true))
    $context = Take-BackgroundRefreshCompletionContext -State $state
    $pending = Take-BackgroundRefreshPendingRequest -State $state
    Set-BackgroundRefreshLastTiming -State $state -Timing ([pscustomobject]@{ TotalMs = $i })
    if ((Test-BackgroundRefreshActive -State $state) -or $null -ne $state.PendingRequest -or -not $pending.RefreshStorage -or -not $pending.RefreshFirmware -or $context.Process.Id -ne (1000 + $i) -or $state.LastTiming.TotalMs -ne $i) {
        $refreshOk = $false
        break
    }
}
Assert-SoakTest 'Refresh lifecycle returns to idle across 500 cycles' $refreshOk

# Repeated settings normalization must stay stable and deduplicate GUID lists/aliases.
$settingsOk = $true
for ($i = 0; $i -lt 500; $i++) {
    $raw = [pscustomobject]@{
        schemaVersion = 4
        defaultGuid = '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}'
        entryOrder = @('{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}','{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}')
        hiddenEntryGuids = @('{11111111-2222-3333-4444-555555555555}','{11111111-2222-3333-4444-555555555555}')
        entryAliases = [pscustomobject]@{ '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}' = '  Test Alias  ' }
    }
    $n = ConvertTo-NormalizedAppSettingsCore -Source $raw
    if (@($n.entryOrder).Count -ne 1 -or @($n.hiddenEntryGuids).Count -ne 1 -or [string]$n.defaultGuid -ne '{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}' -or [string]$n.entryAliases['{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}'] -ne 'Test Alias') {
        $settingsOk = $false
        break
    }
}
Assert-SoakTest 'Settings normalization is stable across 500 cycles' $settingsOk

# Repeated manager parsing must not accumulate or mutate prior results.
$managerText = @'
Firmware Boot Manager
---------------------
identifier              {fwbootmgr}
displayorder            {aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}
                        {11111111-2222-3333-4444-555555555555}
bootsequence            {11111111-2222-3333-4444-555555555555}
'@
$parserOk = $true
for ($i = 0; $i -lt 500; $i++) {
    $r = ConvertFrom-FirmwareManagerText -Text $managerText
    if (@($r.DisplayOrder).Count -ne 2 -or [string]$r.SelectedGuid -ne '{11111111-2222-3333-4444-555555555555}') {
        $parserOk = $false
        break
    }
}
Assert-SoakTest 'Firmware-manager parser is stable across 500 cycles' $parserOk

# Firmware freshness boundary stays deterministic at the exact 30-second threshold.
$now = [datetime]::UtcNow
$freshnessOk = $true
for ($i = 0; $i -lt 500; $i++) {
    if (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-29) -NowUtc $now) { $freshnessOk = $false; break }
    if (-not (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-30) -NowUtc $now)) { $freshnessOk = $false; break }
}
Assert-SoakTest 'Firmware freshness threshold remains deterministic across 500 cycles' $freshnessOk

Write-Host "SOAK TOTAL $checks/4"
if ($checks -ne 4) { throw "Expected 4 soak checks, got $checks" }
