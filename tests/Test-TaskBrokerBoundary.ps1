#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$checks = 0

function Assert-True([string]$Name,[bool]$Value) {
    $script:checks++
    if (-not $Value) { throw "FAIL: $Name" }
    Write-Host "PASS  $Name"
}
function Assert-False([string]$Name,[bool]$Value) { Assert-True $Name (-not $Value) }
function Assert-Equal([string]$Name,$Expected,$Actual) {
    $script:checks++
    if ($Expected -ne $Actual) { throw "FAIL: $Name expected=$Expected actual=$Actual" }
    Write-Host "PASS  $Name"
}

$script:SupportedTaskBrokerVersions = @('0.2.14')
$script:TaskBrokerStateDir = Join-Path ([System.IO.Path]::GetTempPath()) 'LenovoBootSelector-LBS6-Boundary'
$script:TaskBrokerMetadataPath = Join-Path $script:TaskBrokerStateDir 'task-broker.json'
$script:TaskBrokerMetadata = $null
$script:TaskBrokerTimeoutMs = 100
. (Join-Path $root 'src\Infrastructure\TaskBroker.ps1')

$guid = '{11111111-2222-3333-4444-555555555555}'
$compact = '11111111222233334444555555555555'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$meta = [pscustomobject]@{
    version = '0.2.14'
    boundaryContract = 'fixed-task-v2'
    userSid = $sid
    managerRefreshTask = 'LenovoBootSelector-RefreshManager'
    firmwareRefreshTask = 'LenovoBootSelector-RefreshFirmware'
    managerFile = (Join-Path $script:TaskBrokerStateDir 'fwbootmgr.txt')
    firmwareFile = (Join-Path $script:TaskBrokerStateDir 'firmware.txt')
    defaultFile = (Join-Path (Join-Path $script:TaskBrokerStateDir 'Default') 'default-guid.txt')
    defaultClearTask = 'LenovoBootSelector-Default-Clear'
    defaultRestoreTask = 'LenovoBootSelector-Default-Restore'
    targets = @([pscustomobject]@{
        guid = $guid
        taskName = ('LenovoBootSelector-Set-' + $compact)
        defaultTaskName = ('LenovoBootSelector-Default-Set-' + $compact)
        description = 'Test'
    })
}

Assert-Equal 'Canonical GUID retained' $guid (Normalize-TaskBrokerGuid -Guid $guid)
Assert-True 'Malformed GUID rejected' ($null -eq (Normalize-TaskBrokerGuid -Guid 'not-a-guid'))
Assert-Equal 'BootNext task name derived from GUID' ('LenovoBootSelector-Set-' + $compact) (Get-TaskBrokerExpectedTargetTaskName -Guid $guid)
Assert-Equal 'Default task name derived from GUID' ('LenovoBootSelector-Default-Set-' + $compact) (Get-TaskBrokerExpectedTargetTaskName -Guid $guid -DefaultTarget)
Assert-True 'Valid fixed-task-v2 metadata accepted' (Test-TaskBrokerMetadataContract -Metadata $meta)

$script:TaskBrokerMetadata = $meta
Assert-Equal 'Manager refresh resolves fixed task' 'LenovoBootSelector-RefreshManager' (Resolve-TaskBrokerAuthorizedTaskName -Operation ManagerRefresh)
Assert-Equal 'Firmware refresh resolves fixed task' 'LenovoBootSelector-RefreshFirmware' (Resolve-TaskBrokerAuthorizedTaskName -Operation FirmwareRefresh)
Assert-Equal 'Default clear resolves fixed task' 'LenovoBootSelector-Default-Clear' (Resolve-TaskBrokerAuthorizedTaskName -Operation DefaultClear)
Assert-Equal 'BootNext resolves only derived task' ('LenovoBootSelector-Set-' + $compact) (Resolve-TaskBrokerAuthorizedTaskName -Operation BootNext -Guid $guid)
Assert-Equal 'DefaultSet resolves only derived task' ('LenovoBootSelector-Default-Set-' + $compact) (Resolve-TaskBrokerAuthorizedTaskName -Operation DefaultSet -Guid $guid)

$runner = Get-Command Invoke-AuthorizedTask
Assert-False 'Runtime task runner exposes no TaskName parameter' $runner.Parameters.ContainsKey('TaskName')

$badStatic = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$badStatic.managerRefreshTask = 'Arbitrary-System-Task'
Assert-False 'Arbitrary static task name rejected' (Test-TaskBrokerMetadataContract -Metadata $badStatic)

$badTarget = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$badTarget.targets[0].taskName = 'Arbitrary-System-Task'
Assert-False 'Arbitrary target task name rejected' (Test-TaskBrokerMetadataContract -Metadata $badTarget)

$badPath = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$badPath.managerFile = (Join-Path ([System.IO.Path]::GetTempPath()) 'outside.txt')
Assert-False 'Arbitrary state path rejected' (Test-TaskBrokerMetadataContract -Metadata $badPath)

$badBoundary = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$badBoundary.boundaryContract = 'anything-goes'
Assert-False 'Unknown boundary contract rejected' (Test-TaskBrokerMetadataContract -Metadata $badBoundary)

$badVersion = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$badVersion.version = '0.2.13'
Assert-False 'Legacy schema rejected by hardened runtime' (Test-TaskBrokerMetadataContract -Metadata $badVersion)

$duplicate = $meta | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$duplicate.targets = @($duplicate.targets[0],$duplicate.targets[0])
Assert-False 'Duplicate target rejected' (Test-TaskBrokerMetadataContract -Metadata $duplicate)

$defaultRestoreExposed = $false
try { [void](Resolve-TaskBrokerAuthorizedTaskName -Operation DefaultRestore) ; $defaultRestoreExposed = $true } catch { }
Assert-False 'DefaultRestore is not an unelevated runtime operation' $defaultRestoreExposed

$installerPath = Join-Path $root 'bin\Install-LenovoBootMenuTasks.ps1'
$tokens = $null
$parseErrors = $null
$installerAst = [System.Management.Automation.Language.Parser]::ParseFile($installerPath,[ref]$tokens,[ref]$parseErrors)
Assert-Equal 'Installer source parses for ACL predicate extraction' 0 @($parseErrors).Count
$rightsFunctionAst = $installerAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Test-TaskBrokerRightsContainMutation'
},$true)
Assert-True 'ACL mutation predicate exists in installer' ($null -ne $rightsFunctionAst)
Invoke-Expression $rightsFunctionAst.Extent.Text

Assert-False 'ReadAndExecute is accepted as non-mutating' (Test-TaskBrokerRightsContainMutation -Rights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute))
Assert-True 'Modify is rejected as mutating' (Test-TaskBrokerRightsContainMutation -Rights ([System.Security.AccessControl.FileSystemRights]::Modify))
Assert-True 'FullControl is rejected as mutating' (Test-TaskBrokerRightsContainMutation -Rights ([System.Security.AccessControl.FileSystemRights]::FullControl))


$legacyNames = $meta | ConvertTo-Json -Depth 6 | ConvertFrom-Json
$legacyNames.managerRefreshTask = 'LenovoBootMenu-RefreshManager'
Assert-False 'Legacy fixed task name rejected by fixed-task-v2 metadata' (Test-TaskBrokerMetadataContract -Metadata $legacyNames)
$legacyBoundary = $meta | ConvertTo-Json -Depth 6 | ConvertFrom-Json
$legacyBoundary.boundaryContract = 'fixed-task-v1'
Assert-False 'Legacy fixed-task-v1 boundary marker rejected' (Test-TaskBrokerMetadataContract -Metadata $legacyBoundary)
Write-Host "TASKBROKER BOUNDARY TOTAL $checks/25"
if ($checks -ne 25) { throw "Unexpected TaskBroker boundary test count $checks" }
