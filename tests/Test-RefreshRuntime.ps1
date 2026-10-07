#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Application\RefreshRuntime.ps1')
. (Join-Path $root 'src\Infrastructure\RuntimeDiagnostics.ps1')

$checks = 0
function Assert-RefreshTest {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Condition)
    if (-not $Condition) { throw "${Name}: assertion failed" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$state = New-BackgroundRefreshRuntimeState
Assert-RefreshTest 'Initial state is idle' (-not (Test-BackgroundRefreshActive -State $state))

$request = New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $false
Assert-RefreshTest 'Request stores storage flag' ([bool]$request.RefreshStorage)
Assert-RefreshTest 'Request stores firmware flag' (-not [bool]$request.RefreshFirmware)

$now = [datetime]::UtcNow
Assert-RefreshTest 'Missing firmware cache requires refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText $null -FirmwareCacheUtc ([datetime]::MinValue) -NowUtc $now)
Assert-RefreshTest 'Fresh firmware cache skips refresh' (-not (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-5) -NowUtc $now))
Assert-RefreshTest 'Stale firmware cache requires refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $false -FirmwareCacheText 'cached' -FirmwareCacheUtc $now.AddSeconds(-31) -NowUtc $now)
Assert-RefreshTest 'Storage refresh forces firmware refresh' (Test-BackgroundRefreshNeedsFirmware -RefreshStorage $true -FirmwareCacheText 'cached' -FirmwareCacheUtc $now -NowUtc $now)

$activeRequest = New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true
$fakeProcess = [pscustomobject]@{ Id = 1234 }
Set-BackgroundRefreshActive -State $state -Process $fakeProcess -ResultPath 'result.json' -Request $activeRequest
Assert-RefreshTest 'Active lifecycle is visible' (Test-BackgroundRefreshActive -State $state)
Assert-RefreshTest 'Equivalent request does not escalate' (-not (Test-BackgroundRefreshRequestEscalation -ActiveRequest $activeRequest -Requested (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true)))
Assert-RefreshTest 'Storage request escalates firmware-only active request' (Test-BackgroundRefreshRequestEscalation -ActiveRequest $activeRequest -Requested (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $true))

[void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $true -RefreshFirmware $false))
Assert-RefreshTest 'Pending request records storage escalation' ([bool]$state.PendingRequest.RefreshStorage)
[void](Add-BackgroundRefreshPendingRequest -State $state -Request (New-BackgroundRefreshRequest -RefreshStorage $false -RefreshFirmware $true))
Assert-RefreshTest 'Pending request coalesces firmware escalation' ([bool]$state.PendingRequest.RefreshFirmware)

$context = Take-BackgroundRefreshCompletionContext -State $state
Assert-RefreshTest 'Completion context preserves active request' ([bool]$context.Request.RefreshFirmware)
Assert-RefreshTest 'Completion context clears active lifecycle' (-not (Test-BackgroundRefreshActive -State $state))

$pending = Take-BackgroundRefreshPendingRequest -State $state
Assert-RefreshTest 'Pending request survives active completion' ([bool]$pending.RefreshStorage -and [bool]$pending.RefreshFirmware)
Assert-RefreshTest 'Taking pending request clears queue' ($null -eq $state.PendingRequest)

$timing = [pscustomobject]@{ TotalMs = 321 }
Set-BackgroundRefreshLastTiming -State $state -Timing $timing
Assert-RefreshTest 'Last timing stored in runtime state' ($state.LastTiming.TotalMs -eq 321)

$parsed = ConvertFrom-BackgroundRefreshResultText -Text '{"Success":true,"Stage":"complete"}'
Assert-RefreshTest 'Result JSON parses through application contract' ([bool]$parsed.Success -and [string]$parsed.Stage -eq 'complete')

# LBS-22: child workers must inherit the tray diagnostics session instead of
# silently creating a separate session that is absent from the exported ZIP.
$templatePath = Join-Path $root 'src\App\LenovoBootSelector.template.ps1'
$templateText = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
$captureMarker = '$script:InheritedRuntimeSessionId = [string]$RuntimeSessionId'
$resetMarker = '$script:RuntimeSessionId = $null'
$captureIndex = $templateText.IndexOf($captureMarker, [System.StringComparison]::Ordinal)
$resetIndex = $templateText.IndexOf($resetMarker, [System.StringComparison]::Ordinal)
Assert-RefreshTest 'Runtime session input captured before active state reset' ($captureIndex -ge 0 -and $resetIndex -gt $captureIndex)

$diagnosticRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-DiagnosticTest-' + [guid]::NewGuid().ToString('N'))
$parentSession = '11111111-2222-3333-4444-555555555555'
try {
    $script:RuntimeDiagnosticsRoot = $diagnosticRoot
    $script:RuntimeDiagnosticsErrorCount = 0
    $script:InheritedRuntimeSessionId = $parentSession

    $script:BackgroundRefresh = $true
    $script:UpdateCheck = $false
    $script:UpdatePrepare = $false
    $script:RuntimeSessionId = $null
    $script:RuntimeDiagnosticsAvailable = $false
    Initialize-RuntimeDiagnostics
    $parentLogPath = $script:RuntimeEventsPath
    $backgroundRecord = ([System.IO.File]::ReadAllLines($parentLogPath, [System.Text.Encoding]::UTF8) | Select-Object -Last 1) | ConvertFrom-Json
    Assert-RefreshTest 'Background worker reuses inherited diagnostics session' ($script:RuntimeSessionId -eq $parentSession)
    Assert-RefreshTest 'Background worker start is correlated to parent log' ($backgroundRecord.event -eq 'BACKGROUND_WORKER_STARTED' -and [bool]$backgroundRecord.data.parentSession -and $backgroundRecord.sessionId -eq $parentSession)

    $script:BackgroundRefresh = $false
    $script:UpdateCheck = $true
    $script:UpdatePrepare = $false
    $script:RuntimeSessionId = $null
    $script:RuntimeDiagnosticsAvailable = $false
    Initialize-RuntimeDiagnostics
    $updateCheckRecord = ([System.IO.File]::ReadAllLines($parentLogPath, [System.Text.Encoding]::UTF8) | Select-Object -Last 1) | ConvertFrom-Json
    Assert-RefreshTest 'Update-check worker reuses inherited diagnostics session' ($script:RuntimeSessionId -eq $parentSession)
    Assert-RefreshTest 'Update-check worker start is correlated to parent log' ($updateCheckRecord.event -eq 'UPDATE_CHECK_WORKER_STARTED' -and [bool]$updateCheckRecord.data.parentSession -and $updateCheckRecord.sessionId -eq $parentSession)

    $script:BackgroundRefresh = $false
    $script:UpdateCheck = $false
    $script:UpdatePrepare = $true
    $script:RuntimeSessionId = $null
    $script:RuntimeDiagnosticsAvailable = $false
    Initialize-RuntimeDiagnostics
    $updatePrepareRecord = ([System.IO.File]::ReadAllLines($parentLogPath, [System.Text.Encoding]::UTF8) | Select-Object -Last 1) | ConvertFrom-Json
    Assert-RefreshTest 'Update-prepare worker reuses inherited diagnostics session' ($script:RuntimeSessionId -eq $parentSession)
    Assert-RefreshTest 'Update-prepare worker start is correlated to parent log' ($updatePrepareRecord.event -eq 'UPDATE_PREPARE_WORKER_STARTED' -and [bool]$updatePrepareRecord.data.parentSession -and $updatePrepareRecord.sessionId -eq $parentSession)

    $parentRecords = @([System.IO.File]::ReadAllLines($parentLogPath, [System.Text.Encoding]::UTF8) | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-RefreshTest 'All three child roles share one parent diagnostics log' ($parentRecords.Count -eq 3 -and @($parentRecords | Where-Object { $_.sessionId -eq $parentSession }).Count -eq 3)

    $script:InheritedRuntimeSessionId = ''
    $script:BackgroundRefresh = $true
    $script:UpdateCheck = $false
    $script:UpdatePrepare = $false
    $script:RuntimeSessionId = $null
    $script:RuntimeDiagnosticsAvailable = $false
    Initialize-RuntimeDiagnostics
    $freshSession = [string]$script:RuntimeSessionId
    $freshRecord = ([System.IO.File]::ReadAllLines($script:RuntimeEventsPath, [System.Text.Encoding]::UTF8) | Select-Object -Last 1) | ConvertFrom-Json
    $parsedFreshGuid = [guid]::Empty
    $freshIsGuid = [guid]::TryParse($freshSession, [ref]$parsedFreshGuid)
    Assert-RefreshTest 'Worker without inherited session creates fresh session' ($freshIsGuid -and $freshSession -ne $parentSession)
    Assert-RefreshTest 'Fresh worker session is not marked as parent session' ($freshRecord.event -eq 'BACKGROUND_WORKER_STARTED' -and -not [bool]$freshRecord.data.parentSession -and $freshRecord.sessionId -eq $freshSession)
}
finally {
    $script:BackgroundRefresh = $false
    $script:UpdateCheck = $false
    $script:UpdatePrepare = $false
    try { if (Test-Path -LiteralPath $diagnosticRoot) { Remove-Item -LiteralPath $diagnosticRoot -Recurse -Force } } catch { }
}

Write-Host "REFRESH TOTAL $checks/28"
if ($checks -ne 28) { throw "Expected 28 refresh checks, got $checks" }
