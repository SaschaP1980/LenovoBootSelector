#requires -version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$StateDir,
    [Parameter(Mandatory=$true)][string]$UserStateDir,
    [Parameter(Mandatory=$true)][string]$UserSid,
    [AllowEmptyString()][string]$LegacyDefaultGuid = ''
)

$ErrorActionPreference = 'Stop'
$script:CurrentStep = 'init'
$version = '0.2.14'
$taskPrefix = 'LenovoBootSelector-Set-'
$defaultTaskPrefix = 'LenovoBootSelector-Default-Set-'
$managerRefreshTask = 'LenovoBootSelector-RefreshManager'
$firmwareRefreshTask = 'LenovoBootSelector-RefreshFirmware'
$defaultClearTask = 'LenovoBootSelector-Default-Clear'
$defaultRestoreTask = 'LenovoBootSelector-Default-Restore'
$legacyBootMenuTask = 'Lenovo Boot Menu Next'
$canonicalStateDir = Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'
$legacyStateDir = Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'
$legacyDefaultFile = Join-Path (Join-Path $legacyStateDir 'Default') 'default-guid.txt'
$managerFile = Join-Path $StateDir 'fwbootmgr.txt'
$firmwareFile = Join-Path $StateDir 'firmware.txt'
$metadataFile = Join-Path $StateDir 'task-broker.json'
$defaultStateDir = Join-Path $StateDir 'Default'
$defaultFile = Join-Path $defaultStateDir 'default-guid.txt'
$installLog = Join-Path $UserStateDir 'task-broker-install.log'
$diagPointer = Join-Path $UserStateDir 'latest-install-diagnostic.txt'
$bcdedit = Join-Path $env:SystemRoot 'System32\bcdedit.exe'
$cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$script:ScheduleService = $null
$script:ScheduleRootFolder = $null
$script:InstallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:StepStopwatch = $null

function Get-ScheduleService {
    if (-not $script:ScheduleService) {
        $script:ScheduleService = New-Object -ComObject 'Schedule.Service'
        $script:ScheduleService.Connect()
    }
    return $script:ScheduleService
}

function Get-ScheduleRootFolder {
    if (-not $script:ScheduleRootFolder) {
        $script:ScheduleRootFolder = (Get-ScheduleService).GetFolder('\')
    }
    return $script:ScheduleRootFolder
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-InstallLog([string]$Message) {
    if (-not (Test-Path -LiteralPath $UserStateDir)) { [void](New-Item -ItemType Directory -Path $UserStateDir -Force) }
    $line = "{0} [{1}] {2}" -f ([datetime]::Now.ToString('s')),$script:CurrentStep,$Message
    Add-Content -LiteralPath $installLog -Value $line -Encoding UTF8
}

function Complete-CurrentStepTiming {
    if (-not $script:StepStopwatch) { return }
    $script:StepStopwatch.Stop()
    Write-InstallLog ("END durationMs={0}" -f $script:StepStopwatch.ElapsedMilliseconds)
    $script:StepStopwatch = $null
}

function Set-Step([string]$Name) {
    Complete-CurrentStepTiming
    $script:CurrentStep = $Name
    $script:StepStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-InstallLog 'BEGIN'
}

function Parse-GuidFromLine([string]$Line) {
    if ($Line -match '(\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\})') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}

function Normalize-GuidText([AllowNull()][string]$Value) {
    if (-not $Value) { return $null }
    $valueText = $Value.Trim().ToLowerInvariant()
    if ($valueText -match '^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$') { return $valueText }
    return $null
}


function Resolve-TaskBrokerInitialDefault {
    param(
        [AllowEmptyString()][string]$CanonicalDefault = '',
        [AllowEmptyString()][string]$LegacyTaskBrokerDefault = '',
        [AllowEmptyString()][string]$LegacyUserDefault = '',
        [AllowEmptyString()][string]$HistoricalBootMenuDefault = ''
    )
    foreach ($candidate in @($CanonicalDefault,$LegacyTaskBrokerDefault,$LegacyUserDefault,$HistoricalBootMenuDefault)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { return [string]$candidate }
    }
    return ''
}

function Get-ValidDefaultFromPath {
    param(
        [AllowEmptyString()][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$AllowedGuids
    )
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $candidate = Normalize-GuidText ([System.IO.File]::ReadAllText($Path))
        if ($candidate -and ($AllowedGuids -contains $candidate)) { return $candidate }
    }
    catch { }
    return $null
}

function Test-LegacyTaskBrokerOwnedTaskName {
    param([AllowEmptyString()][string]$TaskName)
    if ([string]::IsNullOrWhiteSpace($TaskName)) { return $false }
    if (@(
        'LenovoBootMenu-RefreshManager',
        'LenovoBootMenu-RefreshFirmware',
        'LenovoBootMenu-Default-Clear',
        'LenovoBootMenu-Default-Restore'
    ) -contains $TaskName) { return $true }
    if ($TaskName -match '^LenovoBootMenu-Set-[0-9a-fA-F]{32}$') { return $true }
    if ($TaskName -match '^LenovoBootMenu-Default-Set-[0-9a-fA-F]{32}$') { return $true }
    return $false
}

function Get-LegacyTaskBrokerOwnedTaskNames {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $scheduled = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($task in $scheduled) {
        $name = [string]$task.TaskName
        if (Test-LegacyTaskBrokerOwnedTaskName -TaskName $name) { [void]$names.Add($name) }
    }
    $owned = @($names | Sort-Object -Unique)
    $sw.Stop()
    Write-InstallLog ("Legacy task discovery: scanned={0}; owned={1}; durationMs={2}" -f $scheduled.Count,$owned.Count,$sw.ElapsedMilliseconds)
    return $owned
}

function Remove-LegacyTaskBrokerInstallation {
    $removed = @(Get-LegacyTaskBrokerOwnedTaskNames)
    if ($removed.Count -gt 0) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Unregister-ScheduledTask -TaskName $removed -Confirm:$false -ErrorAction Stop
        $sw.Stop()
        Write-InstallLog ("Legacy task batch unregister: tasks={0}; durationMs={1}" -f $removed.Count,$sw.ElapsedMilliseconds)
    }

    $canonicalFull = [System.IO.Path]::GetFullPath($canonicalStateDir)
    $legacyFull = [System.IO.Path]::GetFullPath($legacyStateDir)
    if ([string]::Equals($canonicalFull,$legacyFull,[System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Legacy and canonical TaskBroker state roots unexpectedly resolve to the same path.'
    }
    if (Test-Path -LiteralPath $legacyStateDir) {
        Remove-Item -LiteralPath $legacyStateDir -Recurse -Force -ErrorAction Stop
    }
    $legacyProjectRoot = Split-Path $legacyStateDir -Parent
    if (Test-Path -LiteralPath $legacyProjectRoot) {
        $remaining = @(Get-ChildItem -LiteralPath $legacyProjectRoot -Force -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) { Remove-Item -LiteralPath $legacyProjectRoot -Force -ErrorAction SilentlyContinue }
    }
    Write-InstallLog ("Legacy TaskBroker cleanup complete: tasks={0}; stateRoot={1}" -f $removed.Count,$legacyStateDir)
}

function Invoke-BcdEditText([string[]]$Arguments) {
    $output = @(& $bcdedit @Arguments 2>&1)
    $exit = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join "`r`n"
    if ($exit -ne 0) {
        throw "BCDEdit fehlgeschlagen (ExitCode $exit): $($Arguments -join ' ')`r`n$text"
    }
    return $text
}

function Get-FirmwareModel {
    $managerText = Invoke-BcdEditText @('/enum','{fwbootmgr}','/v')
    $firmwareText = Invoke-BcdEditText @('/enum','firmware','/v')

    $descriptions = @{}
    $currentGuid = $null
    foreach ($line in ($firmwareText -split '\r?\n')) {
        if ($line -match '^\s*(identifier|Bezeichner)\s+') {
            $currentGuid = Parse-GuidFromLine $line
            continue
        }
        if ($currentGuid -and $line -match '^\s*(description|Beschreibung)\s+(.+?)\s*$') {
            $descriptions[$currentGuid] = $Matches[2].Trim()
        }
    }

    $displayOrder = New-Object System.Collections.Generic.List[string]
    $readingDisplayOrder = $false
    foreach ($line in ($managerText -split '\r?\n')) {
        if ($line -match '^\s*displayorder\s+') {
            $guid = Parse-GuidFromLine $line
            if ($guid) { $displayOrder.Add($guid) }
            $readingDisplayOrder = $true
            continue
        }
        if ($readingDisplayOrder) {
            $continuedGuid = Parse-GuidFromLine $line
            if ($continuedGuid -and $line -match '^\s+\{') {
                $displayOrder.Add($continuedGuid)
                continue
            }
            $readingDisplayOrder = $false
        }
    }

    $bootMenuGuid = $null
    foreach ($key in $descriptions.Keys) {
        if ([string]$descriptions[$key] -eq 'Boot Menu') {
            $bootMenuGuid = [string]$key
            break
        }
    }

    $allowed = New-Object System.Collections.Generic.List[string]
    if ($bootMenuGuid) { $allowed.Add($bootMenuGuid) }
    foreach ($guid in $displayOrder) {
        if (-not $allowed.Contains($guid)) { $allowed.Add($guid) }
    }

    if ($allowed.Count -eq 0) { throw 'Keine zulässigen Firmware-Bootziele wurden gefunden.' }

    [pscustomobject]@{
        ManagerText = $managerText
        FirmwareText = $firmwareText
        Descriptions = $descriptions
        AllowedGuids = @($allowed)
        BootMenuGuid = $bootMenuGuid
    }
}


function Test-SddlReadExecuteAce([string]$Sddl, [string]$Sid) {
    try {
        $raw = New-Object -TypeName 'System.Security.AccessControl.RawSecurityDescriptor' -ArgumentList $Sddl
        if (-not $raw.DiscretionaryAcl) { return $false }

        # Task Scheduler maps written generic GR+GX to 0x1200A9 on this system.
        # LBS-6: GR+GX is a least-privilege contract, not merely a minimum.
        $genericRead = [int]::MinValue
        $genericExecute = 0x20000000
        $mappedReadExecute = 0x001200A9
        $dangerousMask = 0x10000000 -bor 0x40000000 -bor 0x00010000 -bor 0x00040000 -bor 0x00080000
        $hasSafeReadExecute = $false

        foreach ($ace in $raw.DiscretionaryAcl) {
            if ($ace -isnot [System.Security.AccessControl.QualifiedAce]) { continue }
            if ($ace.AceQualifier -ne [System.Security.AccessControl.AceQualifier]::AccessAllowed) { continue }
            if (-not $ace.SecurityIdentifier -or $ace.SecurityIdentifier.Value -ne $Sid) { continue }

            $mask = [int]$ace.AccessMask
            if (($mask -band $dangerousMask) -ne 0) { return $false }

            $hasGenericReadExecute = ((($mask -band $genericRead) -ne 0) -and (($mask -band $genericExecute) -ne 0))
            $hasMappedReadExecute = ($mask -eq $mappedReadExecute)
            if ($hasGenericReadExecute -or $hasMappedReadExecute) {
                $hasSafeReadExecute = $true
                continue
            }

            if ($mask -ne 0) { return $false }
        }
        return $hasSafeReadExecute
    }
    catch { return $false }
}
function Get-TaskReadExecuteOnlySddl {
    param(
        [Parameter(Mandatory=$true)][string]$Sddl,
        [Parameter(Mandatory=$true)][string]$Sid
    )
    $raw = [System.Security.AccessControl.RawSecurityDescriptor]::new($Sddl)
    $oldDacl = $raw.DiscretionaryAcl
    $revision = if ($oldDacl) { $oldDacl.Revision } else { [byte]2 }
    $capacity = if ($oldDacl) { $oldDacl.Count + 1 } else { 1 }
    $newDacl = [System.Security.AccessControl.RawAcl]::new($revision,$capacity)

    if ($oldDacl) {
        foreach ($ace in $oldDacl) {
            $drop = $false
            if ($ace -is [System.Security.AccessControl.QualifiedAce] -and
                $ace.AceQualifier -eq [System.Security.AccessControl.AceQualifier]::AccessAllowed -and
                $ace.SecurityIdentifier -and $ace.SecurityIdentifier.Value -eq $Sid) {
                $drop = $true
            }
            if (-not $drop) { $newDacl.InsertAce($newDacl.Count,$ace) }
        }
    }

    $sidObject = [System.Security.Principal.SecurityIdentifier]::new($Sid)
    $readExecuteMask = ([int]::MinValue -bor 0x20000000)
    $readExecuteAce = [System.Security.AccessControl.CommonAce]::new(
        [System.Security.AccessControl.AceFlags]::None,
        [System.Security.AccessControl.AceQualifier]::AccessAllowed,
        $readExecuteMask,
        $sidObject,
        $false,
        $null
    )
    $newDacl.InsertAce($newDacl.Count,$readExecuteAce)
    $raw.DiscretionaryAcl = $newDacl
    return $raw.GetSddlForm([System.Security.AccessControl.AccessControlSections]::All)
}

function Test-TaskBrokerRightsContainMutation {
    param([Parameter(Mandatory=$true)][System.Security.AccessControl.FileSystemRights]$Rights)

    # FileSystemRights::Modify is composite and overlaps ReadAndExecute. Do not use
    # it as a forbidden bit mask. Check only concrete mutation-capable rights.
    $mutationMask = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
                    [System.Security.AccessControl.FileSystemRights]::AppendData -bor
                    [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
                    [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
                    [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
                    [System.Security.AccessControl.FileSystemRights]::Delete -bor
                    [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                    [System.Security.AccessControl.FileSystemRights]::TakeOwnership
    return (($Rights -band $mutationMask) -ne 0)
}


function Test-TaskBrokerStatePathLeastPrivilege {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $acl = Get-Acl -LiteralPath $Path
        if (-not $acl.AreAccessRulesProtected) { return $false }

        $systemSid = 'S-1-5-18'
        $adminsSid = 'S-1-5-32-544'
        $usersSid = 'S-1-5-32-545'
        $hasSystemFull = $false
        $hasAdminsFull = $false
        $hasUsersRead = $false

        foreach ($rule in @($acl.Access)) {
            if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }
            try { $ruleSid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value }
            catch { return $false }
            $rights = [System.Security.AccessControl.FileSystemRights]$rule.FileSystemRights

            if ($ruleSid -eq $systemSid) {
                if (($rights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq [System.Security.AccessControl.FileSystemRights]::FullControl) { $hasSystemFull = $true }
                continue
            }
            if ($ruleSid -eq $adminsSid) {
                if (($rights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq [System.Security.AccessControl.FileSystemRights]::FullControl) { $hasAdminsFull = $true }
                continue
            }

            if (Test-TaskBrokerRightsContainMutation -Rights $rights) { return $false }
            if ($ruleSid -eq $usersSid -and
                (($rights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [System.Security.AccessControl.FileSystemRights]::ReadAndExecute)) {
                $hasUsersRead = $true
            }
        }

        return ($hasSystemFull -and $hasAdminsFull -and $hasUsersRead)
    }
    catch { return $false }
}
function Protect-TaskBrokerStateDirectory {
    [void](New-Item -ItemType Directory -Path $StateDir -Force)
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagation = [System.Security.AccessControl.PropagationFlags]::None
    $allow = [System.Security.AccessControl.AccessControlType]::Allow
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($systemSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$inheritance,$propagation,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($adminsSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$inheritance,$propagation,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($usersSid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,$inheritance,$propagation,$allow))
    Set-Acl -LiteralPath $StateDir -AclObject $acl
}

function Protect-TaskBrokerMetadataFile {
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw 'TaskBroker-Metadatendatei fehlt.' }
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true,$false)
    $allow = [System.Security.AccessControl.AccessControlType]::Allow
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($systemSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($adminsSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($usersSid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,$allow))
    Set-Acl -LiteralPath $metadataFile -AclObject $acl
}


function Grant-TaskReadExecute([string]$TaskName, [string]$Sid) {
    $service = Get-ScheduleService
    $task = (Get-ScheduleRootFolder).GetTask("\$TaskName")
    $sddl = $task.GetSecurityDescriptor(0x7)

    if (-not (Test-SddlReadExecuteAce -Sddl $sddl -Sid $Sid)) {
        $newSddl = Get-TaskReadExecuteOnlySddl -Sddl $sddl -Sid $Sid
        $task.SetSecurityDescriptor($newSddl, 0)

        $task = (Get-ScheduleRootFolder).GetTask("\$TaskName")
        $verifySddl = $task.GetSecurityDescriptor(0x7)
        if (-not (Test-SddlReadExecuteAce -Sddl $verifySddl -Sid $Sid)) {
            Write-InstallLog ("ACL verification failed after least-privilege replacement: {0}; SDDL={1}" -f $TaskName,$verifySddl)
            throw "Task-ACL konnte nicht auf ausschließlich Read+Execute für $Sid begrenzt werden: $TaskName"
        }
        Write-InstallLog ("ACL replaced and least-privilege verified: {0}" -f $TaskName)
    }
}
function New-SystemTaskSettings {
    return New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
}

function Register-FixedSystemTask {
    param(
        [Parameter(Mandatory=$true)][string]$TaskName,
        [Parameter(Mandatory=$true)]$Action,
        $Trigger = $null,
        [switch]$ReplaceDefinition
    )

    $exists = $false
    try {
        $service = Get-ScheduleService
        $existing = (Get-ScheduleRootFolder).GetTask("\$TaskName")
        if ($existing) { $exists = $true }
    } catch { $exists = $false }

    if (-not $exists -or $ReplaceDefinition) {
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-SystemTaskSettings
        if ($Trigger) {
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $principal -Settings $settings -Force | Out-Null
        }
        else {
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $principal -Settings $settings -Force | Out-Null
        }
        Write-InstallLog $(if ($exists) { "Task definition replaced: $TaskName" } else { "Task created: $TaskName" })
    }
    else {
        Write-InstallLog "Task reused; repairing ACL: $TaskName"
    }

    Grant-TaskReadExecute -TaskName $TaskName -Sid $UserSid
}


function Test-CanonicalTaskTriggerXml {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$TaskXml,
        [AllowEmptyString()][string]$StartupDelay = ''
    )

    try {
        [xml]$xml = $TaskXml
        $triggerNodes = @($xml.SelectNodes("/*[local-name()='Task']/*[local-name()='Triggers']/*"))

        if ([string]::IsNullOrWhiteSpace($StartupDelay)) {
            return ($triggerNodes.Count -eq 0)
        }

        if ($triggerNodes.Count -ne 1) { return $false }
        $trigger = $triggerNodes[0]
        if ([string]$trigger.LocalName -ne 'BootTrigger') { return $false }

        $delayNode = $trigger.SelectSingleNode("./*[local-name()='Delay']")
        if (-not $delayNode) { return $false }

        try {
            $actualDelay = [System.Xml.XmlConvert]::ToTimeSpan([string]$delayNode.InnerText)
            $expectedDelay = [System.Xml.XmlConvert]::ToTimeSpan($StartupDelay)
        }
        catch {
            return $false
        }

        return ($actualDelay -eq $expectedDelay)
    }
    catch {
        return $false
    }
}


function Get-CanonicalTaskDefinitionMap {
    param([Parameter(Mandatory=$true)][object[]]$Specs)

    $names = @($Specs | ForEach-Object { [string]$_.Name })
    if ($names.Count -eq 0) { throw 'Canonical task verification requires at least one task.' }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $definitions = @(Get-ScheduledTask -TaskName $names -ErrorAction Stop)
    $sw.Stop()
    Write-InstallLog ("Canonical task definition batch read: requested={0}; returned={1}; durationMs={2}" -f $names.Count,$definitions.Count,$sw.ElapsedMilliseconds)

    if ($definitions.Count -ne $names.Count) {
        throw ("Canonical task definition count mismatch: expected={0}; actual={1}" -f $names.Count,$definitions.Count)
    }

    $map = @{}
    foreach ($definition in $definitions) {
        $name = [string]$definition.TaskName
        if (-not ($names -contains $name)) { throw "Unexpected canonical task definition returned: $name" }
        if ($map.ContainsKey($name)) { throw "Duplicate canonical task definition returned: $name" }
        $map[$name] = $definition
    }
    foreach ($name in $names) {
        if (-not $map.ContainsKey($name)) { throw "Canonical task definition is missing: $name" }
    }
    return $map
}

function Assert-CanonicalTaskSpec {
    param(
        [Parameter(Mandatory=$true)]$Spec,
        [Parameter(Mandatory=$true)]$Definition
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $definition = $Definition
    $principalUser = [string]$definition.Principal.UserId
    if ($principalUser -ne 'SYSTEM' -and $principalUser -ne 'S-1-5-18') {
        throw "Task principal is not SYSTEM: $($Spec.Name)"
    }
    if ([string]$definition.Principal.RunLevel -ne 'Highest') {
        throw "Task run level is not Highest: $($Spec.Name)"
    }

    $actions = @($definition.Actions)
    if ($actions.Count -ne 1) { throw "Task action count is not exactly one: $($Spec.Name)" }
    if (-not [string]::Equals([string]$actions[0].Execute,[string]$Spec.Execute,[System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Task executable mismatch: $($Spec.Name)"
    }
    if (-not [string]::Equals([string]$actions[0].Arguments,[string]$Spec.Arguments,[System.StringComparison]::Ordinal)) {
        throw "Task arguments mismatch: $($Spec.Name)"
    }

    $task = (Get-ScheduleRootFolder).GetTask("\$($Spec.Name)")
    if (-not (Test-CanonicalTaskTriggerXml -TaskXml ([string]$task.Xml) -StartupDelay ([string]$Spec.StartupDelay))) {
        throw "Task trigger contract mismatch: $($Spec.Name)"
    }

    $sddl = $task.GetSecurityDescriptor(0x7)
    if (-not (Test-SddlReadExecuteAce -Sddl $sddl -Sid $UserSid)) {
        throw "Task DACL violates Read+Execute-only contract: $($Spec.Name)"
    }

    $sw.Stop()
    return [int64]$sw.ElapsedMilliseconds
}

function Assert-CanonicalTaskBrokerMetadata {
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw 'Canonical TaskBroker metadata is missing.' }
    $meta = ([System.IO.File]::ReadAllText($metadataFile,[System.Text.Encoding]::UTF8) | ConvertFrom-Json)
    if ([string]$meta.version -ne '0.2.14') { throw 'Canonical metadata version mismatch.' }
    if ([string]$meta.boundaryContract -ne 'fixed-task-v2') { throw 'Canonical metadata boundary contract mismatch.' }
    if ([string]$meta.userSid -ne $UserSid) { throw 'Canonical metadata user SID mismatch.' }
    if ([string]$meta.managerRefreshTask -ne $managerRefreshTask) { throw 'Canonical manager task mismatch.' }
    if ([string]$meta.firmwareRefreshTask -ne $firmwareRefreshTask) { throw 'Canonical firmware task mismatch.' }
    if ([string]$meta.defaultClearTask -ne $defaultClearTask) { throw 'Canonical default-clear task mismatch.' }
    if ([string]$meta.defaultRestoreTask -ne $defaultRestoreTask) { throw 'Canonical default-restore task mismatch.' }

    foreach ($pair in @(
        @([string]$meta.managerFile,$managerFile),
        @([string]$meta.firmwareFile,$firmwareFile),
        @([string]$meta.defaultFile,$defaultFile)
    )) {
        if (-not [string]::Equals([System.IO.Path]::GetFullPath($pair[0]),[System.IO.Path]::GetFullPath($pair[1]),[System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Canonical metadata state path mismatch.'
        }
    }

    $metaTargets = @($meta.targets)
    if ($metaTargets.Count -ne $targets.Count) { throw 'Canonical metadata target count mismatch.' }
    foreach ($target in @($targets)) {
        $match = @($metaTargets | Where-Object { [string]$_.guid -eq [string]$target.guid })
        if ($match.Count -ne 1) { throw "Canonical metadata target mismatch: $($target.guid)" }
        if ([string]$match[0].taskName -ne [string]$target.taskName) { throw "Canonical BootNext metadata mismatch: $($target.guid)" }
        if ([string]$match[0].defaultTaskName -ne [string]$target.defaultTaskName) { throw "Canonical DefaultSet metadata mismatch: $($target.guid)" }
    }
}

function New-EncodedPowerShellAction([string]$ScriptText) {
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptText)
    $encoded = [Convert]::ToBase64String($bytes)
    return New-ScheduledTaskAction -Execute $powershell -Argument ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand {0}" -f $encoded)
}

function Protect-DefaultStateDirectory {
    [void](New-Item -ItemType Directory -Path $defaultStateDir -Force)

    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagation = [System.Security.AccessControl.PropagationFlags]::None
    $allow = [System.Security.AccessControl.AccessControlType]::Allow

    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')

    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($systemSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$inheritance,$propagation,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($adminsSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$inheritance,$propagation,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($usersSid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,$inheritance,$propagation,$allow))
    Set-Acl -LiteralPath $defaultStateDir -AclObject $acl
    Write-InstallLog 'Default-state directory ACL set to SYSTEM/Admin write + Users read/execute.'
}

function Protect-DefaultStateFile {
    if (-not (Test-Path -LiteralPath $defaultFile)) { return }

    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true,$false)
    $allow = [System.Security.AccessControl.AccessControlType]::Allow
    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($systemSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($adminsSid,[System.Security.AccessControl.FileSystemRights]::FullControl,$allow))
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($usersSid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,$allow))
    Set-Acl -LiteralPath $defaultFile -AclObject $acl
    Write-InstallLog 'Default-state file ACL set to SYSTEM/Admin write + Users read/execute.'
}

function Get-ExistingSystemDefault([string[]]$AllowedGuids) {
    return (Get-ValidDefaultFromPath -Path $defaultFile -AllowedGuids $AllowedGuids)
}

function Get-LegacyTaskBrokerDefault([string[]]$AllowedGuids) {
    return (Get-ValidDefaultFromPath -Path $legacyDefaultFile -AllowedGuids $AllowedGuids)
}

function Test-LegacyBootMenuTaskPresent {
    try { return [bool](Get-ScheduledTask -TaskName $legacyBootMenuTask -ErrorAction Stop) }
    catch { return $false }
}

function Remove-OldServiceBroker {
    try {
        $svc = Get-Service -Name 'LenovoBootMenuBroker' -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne 'Stopped') { Stop-Service -Name 'LenovoBootMenuBroker' -Force -ErrorAction SilentlyContinue }
            & (Join-Path $env:SystemRoot 'System32\sc.exe') delete LenovoBootMenuBroker | Out-Null
            Start-Sleep -Milliseconds 500
        }
        $oldRoot = Join-Path ${env:ProgramFiles} 'Lenovo Boot Menu\Broker'
        if (Test-Path -LiteralPath $oldRoot) { Remove-Item -LiteralPath $oldRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
    catch { Write-InstallLog ("Old broker cleanup ignored: {0}" -f $_.Exception.Message) }
}

function Remove-ProbeTasks {
    $names = @(
        'LenovoBootMenu-AclProbe',
        'LenovoBootMenu-ElevationProbe',
        'LenovoBootMenu-SystemReadProbe',
        'LenovoBootMenu-SystemExecProbe',
        'LenovoBootMenu-SystemBaseline',
        'LenovoBootMenuBroker-SystemProbe'
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Unregister-ScheduledTask -TaskName $names -Confirm:$false -ErrorAction SilentlyContinue
    $sw.Stop()
    Write-InstallLog ("Probe task batch cleanup: requested={0}; durationMs={1}" -f $names.Count,$sw.ElapsedMilliseconds)
}

function New-InstallDiagnosticZip($ErrorRecord) {
    try {
        $diagRoot = Join-Path (Split-Path $UserStateDir -Parent) 'Diagnostics'
        [void](New-Item -ItemType Directory -Path $diagRoot -Force)
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $work = Join-Path $env:TEMP ("LenovoBootSelectorTaskInstall-$stamp")
        [void](New-Item -ItemType Directory -Path $work -Force)
        Copy-Item -LiteralPath $installLog -Destination (Join-Path $work 'install.log') -ErrorAction SilentlyContinue
        @(
            "Version: $version",
            "Step: $script:CurrentStep",
            "UserSid: $UserSid",
            "StateDir: $StateDir",
            "LegacyDefaultGuid: $LegacyDefaultGuid",
            "Error: $($ErrorRecord.Exception.ToString())"
        ) | Set-Content -LiteralPath (Join-Path $work 'error.txt') -Encoding UTF8
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $_.TaskName -like 'LenovoBootSelector-*' -or
            $_.TaskName -like 'LenovoBootMenu-*' -or
            $_.TaskName -eq 'Lenovo Boot Menu Next' -or
            $_.TaskName -eq 'Lenovo Boot Menu Tray Autostart'
        } | Select-Object TaskName,State,TaskPath | Format-List | Out-File -LiteralPath (Join-Path $work 'tasks.txt') -Encoding utf8
        if (Test-Path -LiteralPath $metadataFile) { Copy-Item -LiteralPath $metadataFile -Destination (Join-Path $work 'task-broker.json') -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $defaultFile) { Copy-Item -LiteralPath $defaultFile -Destination (Join-Path $work 'default-guid.txt') -ErrorAction SilentlyContinue }
        $legacyMetadataFile = Join-Path $legacyStateDir 'task-broker.json'
        if (Test-Path -LiteralPath $legacyMetadataFile) { Copy-Item -LiteralPath $legacyMetadataFile -Destination (Join-Path $work 'legacy-task-broker.json') -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $legacyDefaultFile) { Copy-Item -LiteralPath $legacyDefaultFile -Destination (Join-Path $work 'legacy-default-guid.txt') -ErrorAction SilentlyContinue }
        $zip = Join-Path $diagRoot ("TaskBrokerInstall-$stamp.zip")
        Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        return $zip
    }
    catch { return $null }
}

try {
    if (-not (Test-IsAdministrator)) { throw 'Dieses Installationsskript muss erhöht ausgeführt werden.' }

    $stateFull = [System.IO.Path]::GetFullPath($StateDir)
    $canonicalFull = [System.IO.Path]::GetFullPath($canonicalStateDir)
    if (-not [string]::Equals($stateFull,$canonicalFull,[System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unerwartetes TaskBroker-State-Verzeichnis: $StateDir"
    }

    [void](New-Item -ItemType Directory -Path $StateDir -Force)
    [void](New-Item -ItemType Directory -Path $UserStateDir -Force)
    Remove-Item -LiteralPath $installLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $diagPointer -Force -ErrorAction SilentlyContinue

    Set-Step 'protect-state'
    Protect-TaskBrokerStateDirectory
    if (-not (Test-TaskBrokerStatePathLeastPrivilege -Path $StateDir)) {
        throw 'TaskBroker-State-Verzeichnis erfüllt den Least-Privilege-ACL-Vertrag nicht.'
    }
    Write-InstallLog 'TaskBroker state ACL verified: SYSTEM/Admin write, Users read/execute only.'

    Set-Step 'cleanup-old-service'
    Remove-OldServiceBroker
    Remove-ProbeTasks

    Set-Step 'enumerate-firmware'
    $model = Get-FirmwareModel
    Write-InstallLog ("Allowed firmware targets: {0}" -f ($model.AllowedGuids -join ', '))

    Set-Step 'prepare-state'
    $model.ManagerText | Set-Content -LiteralPath $managerFile -Encoding UTF8
    $model.FirmwareText | Set-Content -LiteralPath $firmwareFile -Encoding UTF8
    Protect-DefaultStateDirectory
    $defaultFileEscaped = $defaultFile.Replace("'","''")
    $bcdeditEscaped = $bcdedit.Replace("'","''")

    $existingDefault = Get-ExistingSystemDefault -AllowedGuids $model.AllowedGuids
    $legacyTaskBrokerDefault = Get-LegacyTaskBrokerDefault -AllowedGuids $model.AllowedGuids
    $legacyDefault = Normalize-GuidText $LegacyDefaultGuid
    if ($legacyDefault -and -not ($model.AllowedGuids -contains $legacyDefault)) { $legacyDefault = $null }
    $legacyTaskPresent = Test-LegacyBootMenuTaskPresent
    $historicalBootMenuDefault = if ($legacyTaskPresent -and $model.BootMenuGuid) { [string]$model.BootMenuGuid } else { '' }

    $initialDefault = Resolve-TaskBrokerInitialDefault -CanonicalDefault $(if ($existingDefault) { $existingDefault } else { '' }) -LegacyTaskBrokerDefault $(if ($legacyTaskBrokerDefault) { $legacyTaskBrokerDefault } else { '' }) -LegacyUserDefault $(if ($legacyDefault) { $legacyDefault } else { '' }) -HistoricalBootMenuDefault $historicalBootMenuDefault

    $migrationSource = if ($existingDefault) {
        'canonical-system-default'
    }
    elseif ($legacyTaskBrokerDefault) {
        'legacy-taskbroker-v0.2.13'
    }
    elseif ($legacyDefault) {
        'user-settings-v0.2.21-or-earlier'
    }
    elseif ($historicalBootMenuDefault) {
        'historical-Lenovo-Boot-Menu-Next'
    }
    else {
        'none'
    }
    Write-InstallLog ("Initial default: {0}; source={1}; historicalTaskPresent={2}" -f $(if ($initialDefault) { $initialDefault } else { '<none>' }),$migrationSource,$legacyTaskPresent)

    $taskSpecs = @()

    Set-Step 'register-refresh-manager'
    $mgrCmd = '/d /c ""{0}" /enum "{{fwbootmgr}}" /v > "{1}" 2>&1"' -f $bcdedit,$managerFile
    $mgrAction = New-ScheduledTaskAction -Execute $cmd -Argument $mgrCmd
    Register-FixedSystemTask -TaskName $managerRefreshTask -Action $mgrAction -ReplaceDefinition
    $taskSpecs += [pscustomobject]@{ Name=$managerRefreshTask; Execute=$cmd; Arguments=$mgrCmd; StartupDelay='' }

    Set-Step 'register-refresh-firmware'
    $fwCmd = '/d /c ""{0}" /enum firmware /v > "{1}" 2>&1"' -f $bcdedit,$firmwareFile
    $fwAction = New-ScheduledTaskAction -Execute $cmd -Argument $fwCmd
    Register-FixedSystemTask -TaskName $firmwareRefreshTask -Action $fwAction -ReplaceDefinition
    $taskSpecs += [pscustomobject]@{ Name=$firmwareRefreshTask; Execute=$cmd; Arguments=$fwCmd; StartupDelay='' }

    Set-Step 'register-target-tasks'
    $targets = @()
    foreach ($guid in $model.AllowedGuids) {
        $compact = $guid.Trim('{}').Replace('-','')
        $taskName = $taskPrefix + $compact
        $defaultTaskName = $defaultTaskPrefix + $compact

        $bootArgs = '/set "{{fwbootmgr}}" bootsequence "{0}"' -f $guid
        $bootAction = New-ScheduledTaskAction -Execute $bcdedit -Argument $bootArgs
        Register-FixedSystemTask -TaskName $taskName -Action $bootAction -ReplaceDefinition
        $taskSpecs += [pscustomobject]@{ Name=$taskName; Execute=$bcdedit; Arguments=$bootArgs; StartupDelay='' }

        $setDefaultScript = "[System.IO.File]::WriteAllText('$defaultFileEscaped','$guid',[System.Text.Encoding]::ASCII); exit 0"
        $setDefaultAction = New-EncodedPowerShellAction $setDefaultScript
        Register-FixedSystemTask -TaskName $defaultTaskName -Action $setDefaultAction -ReplaceDefinition
        $taskSpecs += [pscustomobject]@{ Name=$defaultTaskName; Execute=$powershell; Arguments=[string]$setDefaultAction.Arguments; StartupDelay='' }

        $desc = if ($model.Descriptions.ContainsKey($guid)) { [string]$model.Descriptions[$guid] } else { 'Firmware-Startziel' }
        $targets += [pscustomobject]@{ guid=$guid; taskName=$taskName; defaultTaskName=$defaultTaskName; description=$desc }
    }

    Set-Step 'register-default-clear'
    $clearDefaultScript = "Remove-Item -LiteralPath '$defaultFileEscaped' -Force -ErrorAction SilentlyContinue; exit 0"
    $clearAction = New-EncodedPowerShellAction $clearDefaultScript
    Register-FixedSystemTask -TaskName $defaultClearTask -Action $clearAction -ReplaceDefinition
    $taskSpecs += [pscustomobject]@{ Name=$defaultClearTask; Execute=$powershell; Arguments=[string]$clearAction.Arguments; StartupDelay='' }

    Set-Step 'register-default-restore-disabled'
    $allowedLiteral = (@($model.AllowedGuids) | ForEach-Object { "'$_'" }) -join ','
    $restoreScript = @"
`$allowed = @($allowedLiteral)
`$path = '$defaultFileEscaped'
if (-not (Test-Path -LiteralPath `$path)) { exit 0 }
try { `$guid = [System.IO.File]::ReadAllText(`$path).Trim().ToLowerInvariant() } catch { exit 0 }
if (`$allowed -notcontains `$guid) { exit 0 }
& '$bcdeditEscaped' /set '{fwbootmgr}' bootsequence `$guid
exit `$LASTEXITCODE
"@
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    $startupTrigger.Delay = 'PT30S'
    $restoreAction = New-EncodedPowerShellAction $restoreScript
    Register-FixedSystemTask -TaskName $defaultRestoreTask -Action $restoreAction -Trigger $startupTrigger -ReplaceDefinition
    Disable-ScheduledTask -TaskName $defaultRestoreTask -ErrorAction Stop | Out-Null
    $taskSpecs += [pscustomobject]@{ Name=$defaultRestoreTask; Execute=$powershell; Arguments=[string]$restoreAction.Arguments; StartupDelay='PT30S' }
    Write-InstallLog 'Canonical default restore registered with AtStartup + PT30S and temporarily disabled.'

    Set-Step 'persist-initial-default'
    if ($initialDefault) {
        [System.IO.File]::WriteAllText($defaultFile,$initialDefault,[System.Text.Encoding]::ASCII)
        Protect-DefaultStateFile
        Write-InstallLog "System default persisted: $initialDefault"
    }
    else {
        Remove-Item -LiteralPath $defaultFile -Force -ErrorAction SilentlyContinue
        Write-InstallLog 'System default disabled (no default file).'
    }

    Set-Step 'write-metadata'
    $metadata = [ordered]@{
        version = $version
        boundaryContract = 'fixed-task-v2'
        installedUtc = [datetime]::UtcNow.ToString('o')
        userSid = $UserSid
        managerRefreshTask = $managerRefreshTask
        firmwareRefreshTask = $firmwareRefreshTask
        managerFile = $managerFile
        firmwareFile = $firmwareFile
        defaultFile = $defaultFile
        defaultClearTask = $defaultClearTask
        defaultRestoreTask = $defaultRestoreTask
        defaultRestoreDelaySeconds = 30
        targets = $targets
    }
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataFile -Encoding UTF8
    Protect-TaskBrokerMetadataFile

    Set-Step 'enable-default-restore'
    Enable-ScheduledTask -TaskName $defaultRestoreTask -ErrorAction Stop | Out-Null

    Set-Step 'verify-canonical-installation'
    if (-not (Test-TaskBrokerStatePathLeastPrivilege -Path $StateDir)) {
        throw 'Canonical TaskBroker state ACL verification failed.'
    }
    if (-not (Test-TaskBrokerStatePathLeastPrivilege -Path $defaultStateDir)) {
        throw 'Canonical default-state directory ACL verification failed.'
    }
    if ($initialDefault -and -not (Test-TaskBrokerStatePathLeastPrivilege -Path $defaultFile)) {
        throw 'Canonical default-state file ACL verification failed.'
    }
    if (-not (Test-TaskBrokerStatePathLeastPrivilege -Path $metadataFile)) {
        throw 'Canonical metadata ACL verification failed.'
    }
    Assert-CanonicalTaskBrokerMetadata
    $definitionMap = Get-CanonicalTaskDefinitionMap -Specs @($taskSpecs)
    $verifyTasksSw = [System.Diagnostics.Stopwatch]::StartNew()
    $slowestTask = ''
    $slowestTaskDurationMs = -1
    foreach ($spec in @($taskSpecs)) {
        $name = [string]$spec.Name
        $durationMs = [int64](Assert-CanonicalTaskSpec -Spec $spec -Definition $definitionMap[$name])
        if ($durationMs -gt $slowestTaskDurationMs) {
            $slowestTaskDurationMs = $durationMs
            $slowestTask = $name
        }
    }
    $verifyTasksSw.Stop()
    Write-InstallLog ("Canonical task verification timings: tasks={0}; durationMs={1}; slowestTask={2}; slowestTaskDurationMs={3}" -f $taskSpecs.Count,$verifyTasksSw.ElapsedMilliseconds,$slowestTask,$slowestTaskDurationMs)

    $restoreCom = (Get-ScheduleRootFolder).GetTask("\$defaultRestoreTask")
    if (-not $restoreCom.Enabled) { throw 'Default-Restore-Aufgabe konnte nicht aktiviert werden.' }
    Write-InstallLog 'Canonical TaskBroker installation fully verified.'

    Set-Step 'cleanup-legacy-taskbroker'
    Remove-LegacyTaskBrokerInstallation

    Set-Step 'migrate-historical-default-task'
    if ($legacyTaskPresent) {
        Unregister-ScheduledTask -TaskName $legacyBootMenuTask -Confirm:$false -ErrorAction Stop
        Write-InstallLog "Historical task removed after successful canonical validation: $legacyBootMenuTask"
    }

    Set-Step 'complete'
    Complete-CurrentStepTiming
    $script:InstallStopwatch.Stop()
    Write-InstallLog ("INSTALL durationMs={0}" -f $script:InstallStopwatch.ElapsedMilliseconds)
    Write-InstallLog 'SUCCESS'
    exit 0
}
catch {
    try {
        Complete-CurrentStepTiming
        if ($script:InstallStopwatch.IsRunning) { $script:InstallStopwatch.Stop() }
        Write-InstallLog ("FAILED durationMs={0}" -f $script:InstallStopwatch.ElapsedMilliseconds)
    } catch { }
    try {
        [void](New-Item -ItemType Directory -Path $UserStateDir -Force)
        $zip = New-InstallDiagnosticZip -ErrorRecord $_
        if ($zip) { Set-Content -LiteralPath $diagPointer -Value $zip -Encoding UTF8 }
    } catch { }
    Write-Error $_
    exit 1
}
