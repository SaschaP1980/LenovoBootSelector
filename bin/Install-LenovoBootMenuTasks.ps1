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
$version = '0.2.13'
$taskPrefix = 'LenovoBootMenu-Set-'
$defaultTaskPrefix = 'LenovoBootMenu-Default-Set-'
$managerRefreshTask = 'LenovoBootMenu-RefreshManager'
$firmwareRefreshTask = 'LenovoBootMenu-RefreshFirmware'
$defaultClearTask = 'LenovoBootMenu-Default-Clear'
$defaultRestoreTask = 'LenovoBootMenu-Default-Restore'
$legacyBootMenuTask = 'Lenovo Boot Menu Next'
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

function Get-ScheduleService {
    if (-not $script:ScheduleService) {
        $script:ScheduleService = New-Object -ComObject 'Schedule.Service'
        $script:ScheduleService.Connect()
    }
    return $script:ScheduleService
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

function Set-Step([string]$Name) {
    $script:CurrentStep = $Name
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
        $writeMask = [System.Security.AccessControl.FileSystemRights]::Write -bor
                     [System.Security.AccessControl.FileSystemRights]::Modify -bor
                     [System.Security.AccessControl.FileSystemRights]::Delete -bor
                     [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                     [System.Security.AccessControl.FileSystemRights]::TakeOwnership

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

            if (($rights -band $writeMask) -ne 0) { return $false }
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
    $task = $service.GetFolder('\').GetTask("\$TaskName")
    $sddl = $task.GetSecurityDescriptor(0x7)

    if (-not (Test-SddlReadExecuteAce -Sddl $sddl -Sid $Sid)) {
        $newSddl = Get-TaskReadExecuteOnlySddl -Sddl $sddl -Sid $Sid
        $task.SetSecurityDescriptor($newSddl, 0)

        $task = $service.GetFolder('\').GetTask("\$TaskName")
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
        $existing = $service.GetFolder('\').GetTask("\$TaskName")
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
    if (-not (Test-Path -LiteralPath $defaultFile)) { return $null }
    try {
        $candidate = Normalize-GuidText ([System.IO.File]::ReadAllText($defaultFile))
        if ($candidate -and ($AllowedGuids -contains $candidate)) { return $candidate }
    }
    catch { }
    return $null
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
    foreach ($name in $names) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }
}

function New-InstallDiagnosticZip($ErrorRecord) {
    try {
        $diagRoot = Join-Path (Split-Path $UserStateDir -Parent) 'Diagnostics'
        [void](New-Item -ItemType Directory -Path $diagRoot -Force)
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $work = Join-Path $env:TEMP ("LenovoBootMenuTaskInstall-$stamp")
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
            $_.TaskName -like 'LenovoBootMenu-*' -or
            $_.TaskName -eq 'Lenovo Boot Menu Next' -or
            $_.TaskName -eq 'Lenovo Boot Menu Tray Autostart'
        } | Select-Object TaskName,State,TaskPath | Format-List | Out-File -LiteralPath (Join-Path $work 'tasks.txt') -Encoding utf8
        if (Test-Path -LiteralPath $metadataFile) { Copy-Item -LiteralPath $metadataFile -Destination (Join-Path $work 'task-broker.json') -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $defaultFile) { Copy-Item -LiteralPath $defaultFile -Destination (Join-Path $work 'default-guid.txt') -ErrorAction SilentlyContinue }
        $zip = Join-Path $diagRoot ("TaskBrokerInstall-$stamp.zip")
        Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        return $zip
    }
    catch { return $null }
}

try {
    if (-not (Test-IsAdministrator)) { throw 'Dieses Installationsskript muss erhöht ausgeführt werden.' }
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
    $legacyDefault = Normalize-GuidText $LegacyDefaultGuid
    if ($legacyDefault -and -not ($model.AllowedGuids -contains $legacyDefault)) { $legacyDefault = $null }
    $legacyTaskPresent = Test-LegacyBootMenuTaskPresent

    $initialDefault = $existingDefault
    $migrationSource = if ($existingDefault) { 'existing-system-default' } else { 'none' }
    if (-not $initialDefault -and $legacyDefault) {
        $initialDefault = $legacyDefault
        $migrationSource = 'user-settings-v0.2.21-or-earlier'
    }
    elseif (-not $initialDefault -and $legacyTaskPresent -and $model.BootMenuGuid) {
        $initialDefault = $model.BootMenuGuid
        $migrationSource = 'historical-Lenovo-Boot-Menu-Next'
    }
    Write-InstallLog ("Initial default: {0}; source={1}; historicalTaskPresent={2}" -f $(if ($initialDefault) { $initialDefault } else { '<none>' }),$migrationSource,$legacyTaskPresent)

    Set-Step 'register-refresh-manager'
    $mgrCmd = '/d /c ""{0}" /enum "{{fwbootmgr}}" /v > "{1}" 2>&1"' -f $bcdedit,$managerFile
    Register-FixedSystemTask -TaskName $managerRefreshTask -Action (New-ScheduledTaskAction -Execute $cmd -Argument $mgrCmd)

    Set-Step 'register-refresh-firmware'
    $fwCmd = '/d /c ""{0}" /enum firmware /v > "{1}" 2>&1"' -f $bcdedit,$firmwareFile
    Register-FixedSystemTask -TaskName $firmwareRefreshTask -Action (New-ScheduledTaskAction -Execute $cmd -Argument $fwCmd)

    Set-Step 'register-target-tasks'
    $targets = @()
    foreach ($guid in $model.AllowedGuids) {
        $compact = $guid.Trim('{}').Replace('-','')
        $taskName = $taskPrefix + $compact
        $defaultTaskName = $defaultTaskPrefix + $compact

        $bootAction = New-ScheduledTaskAction -Execute $bcdedit -Argument ('/set "{{fwbootmgr}}" bootsequence "{0}"' -f $guid)
        Register-FixedSystemTask -TaskName $taskName -Action $bootAction

        $setDefaultScript = "[System.IO.File]::WriteAllText('$defaultFileEscaped','$guid',[System.Text.Encoding]::ASCII); exit 0"
        Register-FixedSystemTask -TaskName $defaultTaskName -Action (New-EncodedPowerShellAction $setDefaultScript) -ReplaceDefinition

        $desc = if ($model.Descriptions.ContainsKey($guid)) { [string]$model.Descriptions[$guid] } else { 'Firmware-Startziel' }
        $targets += [pscustomobject]@{ guid=$guid; taskName=$taskName; defaultTaskName=$defaultTaskName; description=$desc }
    }

    Set-Step 'register-default-clear'
    $clearDefaultScript = "Remove-Item -LiteralPath '$defaultFileEscaped' -Force -ErrorAction SilentlyContinue; exit 0"
    Register-FixedSystemTask -TaskName $defaultClearTask -Action (New-EncodedPowerShellAction $clearDefaultScript) -ReplaceDefinition

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
    Register-FixedSystemTask -TaskName $defaultRestoreTask -Action (New-EncodedPowerShellAction $restoreScript) -Trigger $startupTrigger -ReplaceDefinition
    Disable-ScheduledTask -TaskName $defaultRestoreTask -ErrorAction Stop | Out-Null
    Write-InstallLog 'Default restore registered with AtStartup + PT30S and temporarily disabled for migration.'

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

    Set-Step 'validate-user-access'
    $requiredTasks = @($managerRefreshTask,$firmwareRefreshTask,$defaultClearTask,$defaultRestoreTask)
    $requiredTasks += @($targets | ForEach-Object { $_.taskName })
    $requiredTasks += @($targets | ForEach-Object { $_.defaultTaskName })
    foreach ($name in $requiredTasks) {
        $service = Get-ScheduleService
        $task = $service.GetFolder('\').GetTask("\$name")
        $sddl = $task.GetSecurityDescriptor(0x7)
        if (-not (Test-SddlReadExecuteAce -Sddl $sddl -Sid $UserSid)) {
            throw "Task-DACL enthält keine wirksame Read+Execute-ACE für den Benutzer: $name"
        }
        Write-InstallLog "ACL verified: $name"
    }

    Set-Step 'migrate-historical-default-task'
    if ($legacyTaskPresent) {
        Unregister-ScheduledTask -TaskName $legacyBootMenuTask -Confirm:$false -ErrorAction Stop
        Write-InstallLog "Historical task removed after successful new-task validation: $legacyBootMenuTask"
    }

    Set-Step 'enable-default-restore'
    Enable-ScheduledTask -TaskName $defaultRestoreTask -ErrorAction Stop | Out-Null
    $restoreDefinition = Get-ScheduledTask -TaskName $defaultRestoreTask -ErrorAction Stop
    $restoreCom = (Get-ScheduleService).GetFolder('\').GetTask("\$defaultRestoreTask")
    if (-not $restoreCom.Enabled) { throw 'Default-Restore-Aufgabe konnte nicht aktiviert werden.' }
    if (@($restoreDefinition.Triggers).Count -lt 1) { throw 'Default-Restore-Aufgabe besitzt keinen Startup-Trigger.' }
    Write-InstallLog ("Default restore trigger delay readback: {0}" -f [string]$restoreDefinition.Triggers[0].Delay)
    $restoreSddl = $restoreCom.GetSecurityDescriptor(0x7)
    if (-not (Test-SddlReadExecuteAce -Sddl $restoreSddl -Sid $UserSid)) { throw 'Default-Restore-ACL wurde beim Aktivieren unerwartet verändert.' }
    Write-InstallLog 'Default restore enabled and revalidated.'

    Set-Step 'write-metadata'
    $metadata = [ordered]@{
        version = $version
        boundaryContract = 'fixed-task-v1'
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
    if (-not (Test-TaskBrokerStatePathLeastPrivilege -Path $metadataFile)) {
        throw 'TaskBroker-Metadatendatei erfüllt den Least-Privilege-ACL-Vertrag nicht.'
    }
    Write-InstallLog 'TaskBroker metadata ACL verified: SYSTEM/Admin write, Users read/execute only.'

    Set-Step 'complete'
    Write-InstallLog 'SUCCESS'
    exit 0
}
catch {
    try {
        [void](New-Item -ItemType Directory -Path $UserStateDir -Force)
        $zip = New-InstallDiagnosticZip -ErrorRecord $_
        if ($zip) { Set-Content -LiteralPath $diagPointer -Value $zip -Encoding UTF8 }
    } catch { }
    Write-Error $_
    exit 1
}
