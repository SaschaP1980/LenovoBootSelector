#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$checks = 0
function Assert-True([string]$Name,[bool]$Value) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Assert-False([string]$Name,[bool]$Value) { Assert-True -Name $Name -Value (-not $Value) }
function Assert-Equal([string]$Name,$Expected,$Actual) {
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$installerPath = Join-Path $root 'bin\Install-LenovoBootMenuTasks.ps1'
$uninstallerPath = Join-Path $root 'bin\Uninstall-LenovoBootMenuTasks.ps1'
$templatePath = Join-Path $root 'src\App\LenovoBootSelector.template.ps1'
$taskBrokerPath = Join-Path $root 'src\Infrastructure\TaskBroker.ps1'
$installer = [System.IO.File]::ReadAllText($installerPath,[System.Text.Encoding]::UTF8)
$uninstaller = [System.IO.File]::ReadAllText($uninstallerPath,[System.Text.Encoding]::UTF8)
$template = [System.IO.File]::ReadAllText($templatePath,[System.Text.Encoding]::UTF8)
$taskBroker = [System.IO.File]::ReadAllText($taskBrokerPath,[System.Text.Encoding]::UTF8)

Assert-True 'Installer advances TaskBroker schema to 0.2.14' ($installer.Contains('$version = ''0.2.14'''))
Assert-True 'Installer writes fixed-task-v2 metadata' ($installer.Contains("boundaryContract = 'fixed-task-v2'"))
Assert-True 'Runtime accepts only TaskBroker schema 0.2.14' ($template.Contains('$script:SupportedTaskBrokerVersions = @(''0.2.14'')'))
Assert-True 'Canonical ProgramData TaskBroker root uses Lenovo Boot Selector' ($template.Contains('Join-Path $env:ProgramData ''Lenovo Boot Selector\TaskBroker'''))
Assert-True 'Legacy ProgramData root remains explicit migration input' ($template.Contains('Join-Path $env:ProgramData ''Lenovo Boot Menu\TaskBroker'''))
Assert-True 'Canonical static task prefix is present' ($taskBroker.Contains('LenovoBootSelector-RefreshManager'))
Assert-False 'Runtime authorization no longer returns legacy manager task' ($taskBroker.Contains("return 'LenovoBootMenu-RefreshManager'"))


$script:TaskBrokerMetadataPath = 'C:\Canonical\task-broker.json'
$script:LegacyTaskBrokerMetadataPath = 'C:\Legacy\task-broker.json'
$script:FakeExistingPaths = @($script:LegacyTaskBrokerMetadataPath)
function Test-Path {
    param([string]$LiteralPath,[string]$Path,[object]$PathType)
    $candidate = if ($LiteralPath) { $LiteralPath } else { $Path }
    return ($script:FakeExistingPaths -contains $candidate)
}
. $taskBrokerPath
Assert-True 'Legacy-only TaskBroker installation is detected for Repair/Migrate' (Test-TaskBrokerInstallationPresent)
$script:FakeExistingPaths = @($script:TaskBrokerMetadataPath)
Assert-True 'Canonical TaskBroker installation is detected' (Test-TaskBrokerInstallationPresent)
$script:FakeExistingPaths = @()
Assert-False 'Missing canonical and legacy TaskBroker state is not reported as installed' (Test-TaskBrokerInstallationPresent)
Assert-True 'Repair deterministically replaces canonical task definitions' ($installer.Contains('Register-FixedSystemTask -TaskName $managerRefreshTask -Action $mgrAction -ReplaceDefinition'))

$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($installerPath,[ref]$tokens,[ref]$errors)
if (@($errors).Count -ne 0) { throw 'Installer AST parse failed.' }
function Import-InstallerFunction([string]$Name) {
    $fn = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name },$true))
    if ($fn.Count -ne 1) { throw "Expected exactly one installer function: $Name" }
    Invoke-Expression $fn[0].Extent.Text
}
Import-InstallerFunction 'Resolve-TaskBrokerInitialDefault'
Import-InstallerFunction 'Test-LegacyTaskBrokerOwnedTaskName'

$g1='{11111111-1111-1111-1111-111111111111}'
$g2='{22222222-2222-2222-2222-222222222222}'
$g3='{33333333-3333-3333-3333-333333333333}'
$g4='{44444444-4444-4444-4444-444444444444}'
Assert-Equal 'Canonical default has highest migration precedence' $g1 (Resolve-TaskBrokerInitialDefault -CanonicalDefault $g1 -LegacyTaskBrokerDefault $g2 -LegacyUserDefault $g3 -HistoricalBootMenuDefault $g4)
Assert-Equal 'Legacy TaskBroker default precedes user-settings fallback' $g2 (Resolve-TaskBrokerInitialDefault -CanonicalDefault '' -LegacyTaskBrokerDefault $g2 -LegacyUserDefault $g3 -HistoricalBootMenuDefault $g4)
Assert-Equal 'Legacy user default remains fallback after TaskBroker state' $g3 (Resolve-TaskBrokerInitialDefault -CanonicalDefault '' -LegacyTaskBrokerDefault '' -LegacyUserDefault $g3 -HistoricalBootMenuDefault $g4)
Assert-Equal 'Historical Boot Menu default remains final fallback' $g4 (Resolve-TaskBrokerInitialDefault -CanonicalDefault '' -LegacyTaskBrokerDefault '' -LegacyUserDefault '' -HistoricalBootMenuDefault $g4)
Assert-Equal 'No migration source yields no default' '' (Resolve-TaskBrokerInitialDefault -CanonicalDefault '' -LegacyTaskBrokerDefault '' -LegacyUserDefault '' -HistoricalBootMenuDefault '')

Assert-True 'Legacy static TaskBroker task is recognized as owned' (Test-LegacyTaskBrokerOwnedTaskName -TaskName 'LenovoBootMenu-RefreshManager')
Assert-True 'Legacy BootNext task with exact 32-hex suffix is recognized' (Test-LegacyTaskBrokerOwnedTaskName -TaskName 'LenovoBootMenu-Set-0123456789abcdef0123456789ABCDEF')
Assert-True 'Legacy DefaultSet task with exact 32-hex suffix is recognized' (Test-LegacyTaskBrokerOwnedTaskName -TaskName 'LenovoBootMenu-Default-Set-0123456789abcdef0123456789ABCDEF')
Assert-False 'Legacy prefix with malformed suffix is rejected' (Test-LegacyTaskBrokerOwnedTaskName -TaskName 'LenovoBootMenu-Set-not-a-guid')
Assert-False 'Unrelated Lenovo task is rejected' (Test-LegacyTaskBrokerOwnedTaskName -TaskName 'LenovoUpdate-Anything')

$verifyIndex=$installer.IndexOf("Set-Step 'verify-canonical-installation'",[System.StringComparison]::Ordinal)
$cleanupIndex=$installer.IndexOf("Set-Step 'cleanup-legacy-taskbroker'",[System.StringComparison]::Ordinal)
Assert-True 'Legacy cleanup occurs only after canonical verification marker' ($verifyIndex -ge 0 -and $cleanupIndex -gt $verifyIndex)
Assert-True 'Installer cleanup targets exact legacy ProgramData root' ($installer.Contains('$legacyStateDir = Join-Path $env:ProgramData ''Lenovo Boot Menu\TaskBroker'''))
Assert-True 'Installer never wildcard-unregisters legacy tasks' (-not $installer.Contains("Unregister-ScheduledTask -TaskName 'LenovoBootMenu-*'"))
Assert-True 'Uninstaller recognizes canonical manager task' ($uninstaller.Contains("'LenovoBootSelector-RefreshManager'"))
Assert-True 'Uninstaller still recognizes legacy manager task' ($uninstaller.Contains("'LenovoBootMenu-RefreshManager'"))
Assert-True 'Uninstaller removes canonical ProgramData root' ($uninstaller.Contains('Join-Path $env:ProgramData ''Lenovo Boot Selector\TaskBroker'''))
Assert-True 'Uninstaller also removes exact legacy ProgramData root' ($uninstaller.Contains('Join-Path $env:ProgramData ''Lenovo Boot Menu\TaskBroker'''))

Write-Host "TASKBROKER MIGRATION TOTAL $checks/28"
if ($checks -ne 28) { throw "Unexpected TaskBroker migration test count $checks" }
