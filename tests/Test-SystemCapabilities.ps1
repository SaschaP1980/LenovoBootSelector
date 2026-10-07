#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Application\SystemCapabilities.ps1')

$script:checks = 0
function Assert-CapabilityEqual {
    param($Expected,$Actual,[Parameter(Mandatory=$true)][string]$Name)
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Assert-CapabilityTrue {
    param([bool]$Actual,[Parameter(Mandatory=$true)][string]$Name)
    Assert-CapabilityEqual $true $Actual $Name
}
function Assert-CapabilityFalse {
    param([bool]$Actual,[Parameter(Mandatory=$true)][string]$Name)
    Assert-CapabilityEqual $false $Actual $Name
}

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $false -DriftDetected $false -EntryCount 0
Assert-CapabilityEqual 'SetupRequired' $state.State 'No installation requires setup'
Assert-CapabilityFalse $state.CanSetBootNext 'Setup blocks BootNext'
Assert-CapabilityFalse $state.CanSetDefaultTarget 'Setup blocks default target'
Assert-CapabilityTrue $state.CanRestart 'Setup does not block ordinary restart'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $false -DriftDetected $false -EntryCount 2
Assert-CapabilityEqual 'RepairRequired' $state.State 'Incompatible installation requires repair'
Assert-CapabilityFalse $state.CanManageEntries 'Repair blocks entry management'
Assert-CapabilityTrue $state.CanConfigureSystemFunctions 'Repair keeps recovery action available'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $null -MaintenanceBusy $false -DriftDetected $false -EntryCount 2
Assert-CapabilityEqual 'Checking' $state.State 'Pending session readiness is checking'
Assert-CapabilityTrue $state.IsChecking 'Checking flag is explicit'
Assert-CapabilityTrue $state.CanUseCachedBootState 'Checking keeps compatible read-only cache access'
Assert-CapabilityFalse $state.CanRefresh 'Checking blocks interactive refresh'
Assert-CapabilityFalse $state.CanUseDefaultTarget 'Checking blocks default-target mutation'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $true -MaintenanceBusy $false -DriftDetected $false -EntryCount 2
Assert-CapabilityEqual 'Ready' $state.State 'Ready inputs produce Ready state'
Assert-CapabilityTrue $state.IsReady 'Ready flag is explicit'
Assert-CapabilityTrue $state.CanSetBootNext 'Ready entries enable BootNext'
Assert-CapabilityTrue $state.CanSetDefaultTarget 'Ready entries enable default target'
Assert-CapabilityTrue $state.CanUseDefaultTarget 'Ready enables default-target surface'
Assert-CapabilityTrue $state.CanManageEntries 'Ready entries enable entry management'
Assert-CapabilityTrue $state.CanRefresh 'Ready enables refresh'
Assert-CapabilityTrue $state.CanRestart 'Ready enables restart'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $true -MaintenanceBusy $false -DriftDetected $false -EntryCount 0
Assert-CapabilityEqual 'Ready' $state.State 'Ready state does not depend on entry count'
Assert-CapabilityFalse $state.CanSetBootNext 'No entries block BootNext'
Assert-CapabilityFalse $state.CanSetDefaultTarget 'No entries block default-target selection'
Assert-CapabilityFalse $state.CanManageEntries 'No entries block entry management'
Assert-CapabilityTrue $state.CanUseDefaultTarget 'No entries do not invalidate system readiness'
Assert-CapabilityTrue $state.CanRefresh 'No entries do not block refresh'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $true -MaintenanceBusy $false -DriftDetected $true -EntryCount 2
Assert-CapabilityEqual 'ReinitializeRequired' $state.State 'Drift requires reinitialization'
Assert-CapabilityFalse $state.CanRestart 'Drift blocks restart'
Assert-CapabilityFalse $state.CanSetBootNext 'Drift blocks BootNext'
Assert-CapabilityFalse $state.CanUseCachedBootState 'Drift blocks cached system-state use'
Assert-CapabilityTrue $state.CanConfigureSystemFunctions 'Drift keeps reinitialize action available'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $true -MaintenanceBusy $true -MaintenanceMode 'Repair' -DriftDetected $false -EntryCount 2
Assert-CapabilityEqual 'Busy' $state.State 'Maintenance produces Busy state'
Assert-CapabilityEqual 'Repair' $state.MaintenanceMode 'Busy state retains maintenance mode'
Assert-CapabilityFalse $state.CanRestart 'Maintenance blocks restart'
Assert-CapabilityFalse $state.CanRefresh 'Maintenance blocks refresh'
Assert-CapabilityFalse $state.CanConfigureSystemFunctions 'Maintenance blocks concurrent maintenance action'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $false -MaintenanceBusy $false -DriftDetected $false -EntryCount 2
Assert-CapabilityEqual 'RepairRequired' $state.State 'Failed session readiness requires repair'
Assert-CapabilityFalse $state.CanUseCachedBootState 'Failed readiness blocks cached system-state use'
Assert-CapabilityTrue $state.CanRestart 'Failed readiness preserves ordinary restart'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $false -InstallationPresent $false -MetadataCompatible $false -SessionReady $null -MaintenanceBusy $false -DriftDetected $false -EntryCount 0
Assert-CapabilityEqual 'Unknown' $state.State 'Invalid facts fail closed as Unknown'
Assert-CapabilityFalse $state.CanRestart 'Unknown facts block restart'
Assert-CapabilityFalse $state.CanRefresh 'Unknown facts block refresh'
Assert-CapabilityFalse $state.CanUseDefaultTarget 'Unknown facts block default-target capability'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $false -MetadataCompatible $true -SessionReady $null -MaintenanceBusy $false -DriftDetected $false -EntryCount 1
Assert-CapabilityEqual 'Unknown' $state.State 'Inconsistent metadata facts fail closed'
Assert-CapabilityFalse $state.CanSetBootNext 'Inconsistent facts block BootNext'

$state = Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady 'yes' -MaintenanceBusy $false -DriftDetected $false -EntryCount 1
Assert-CapabilityEqual 'Unknown' $state.State 'Non-boolean readiness fails closed'
Assert-CapabilityFalse $state.IsReady 'Invalid readiness never reports Ready'

Write-Host "SYSTEM CAPABILITIES TOTAL $script:checks/47"
if ($script:checks -ne 47) { throw "Unexpected system capability test count $script:checks" }
