#requires -version 5.1
# LBS-143: hosted Windows SYSTEM Task Scheduler E2E, with an isolated fake BCDEdit.
# NEVER invoke real bcdedit.exe, alter firmware, or register product task names.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$installerFile = Join-Path $root 'bin\Install-LenovoBootMenuTasks.ps1'
$source = [IO.File]::ReadAllText($installerFile,[Text.Encoding]::UTF8)
$match = [regex]::Match($source,'(?s)\$coordinatedTaskTemplate = @''\r?\n(.*?)\r?\n''@')
if (-not $match.Success) { throw 'Fixed SYSTEM writer template not found.' }
$template = $match.Groups[1].Value
$a = '{11111111-1111-1111-1111-111111111111}'
$b = '{22222222-2222-2222-2222-222222222222}'
$c = '{33333333-3333-3333-3333-333333333333}'
$suffix = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $env:ProgramData ('LBS143-WinTask-' + $suffix)
$defaultDir = Join-Path $testRoot 'Default'
$defaultPath = Join-Path $defaultDir 'default.txt'
$originPath = Join-Path $defaultDir 'origin.json'
$lockPath = Join-Path $defaultDir 'bootnext-writer.lock'
$firmwarePath = Join-Path $testRoot 'fake-firmware.txt'
$fakeBcd = Join-Path $testRoot 'fake-bcdedit.ps1'
$psExe = Join-Path $PSHOME 'powershell.exe'
$prefix = 'LBS143-Smoke-' + $suffix + '-'
$tasks = @()
$checks = 0

function Assert-True([string]$Label,[bool]$Value) {
    $script:checks++
    if (-not $Value) { throw "FAIL: $Label" }
    Write-Host "PASS  $Label"
}
function Install-DirectoryAcl([string]$Path) {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagate = [Security.AccessControl.PropagationFlags]::None
    foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
        $identity = [Security.Principal.SecurityIdentifier]::new($sid)
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $identity,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$propagate,$allow)
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}
function Register-TestWriter([string]$Operation,[string]$Guid='') {
    $code = $template.Replace('__OP__',$Operation).Replace('__GUID__',$Guid)
    $code = $code.Replace('__ALLOWED__',("'$a','$b','$c'"))
    $code = $code.Replace('__DEFAULT__',$defaultPath.Replace("'","''"))
    $code = $code.Replace('__ORIGIN__',$originPath.Replace("'","''"))
    $code = $code.Replace('__LOCK__',$lockPath.Replace("'","''"))
    $code = $code.Replace('__BCDEDIT__',$fakeBcd.Replace("'","''"))
    if ($code.Contains('__LOCK__') -or $code.Contains('__BCDEDIT__')) { throw 'Unresolved writer placeholder.' }
    # The task runs as SYSTEM; capture its terminating error in a test-only file.
    $errorFile = Join-Path $testRoot ($Operation + '.error.log')
    $trap = 'trap { [IO.File]::WriteAllText(''' + $errorFile.Replace("'","''") + ''', ($_ | Out-String), [Text.Encoding]::UTF8); throw }'
    $code = $trap + [Environment]::NewLine + $code
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $name = $prefix + $Operation + '-' + $tasks.Count
    $action = New-ScheduledTaskAction -Execute $psExe -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' + $encoded)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances Queue
    Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    $script:tasks += $name
    [xml]$xml = (Get-ScheduledTask -TaskName $name | Export-ScheduledTask)
    $policy = $xml.SelectSingleNode("/*[local-name()='Task']/*[local-name()='Settings']/*[local-name()='MultipleInstancesPolicy']")
    Assert-True ("SYSTEM " + $Operation + " is Queue-enabled") ([string]$policy.InnerText -eq 'Queue')
    return $name
}
function Wait-Tasks([string[]]$Names,[datetime]$Earliest) {
    $end = (Get-Date).AddSeconds(60)
    foreach ($name in $Names) {
        $complete = $false
        do {
            $info = Get-ScheduledTaskInfo -TaskName $name
            $task = Get-ScheduledTask -TaskName $name
            if ($info.LastRunTime -ge $Earliest.AddSeconds(-2) -and [string]$task.State -ne 'Running') {
                if ([uint32]$info.LastTaskResult -ne 0) {
                    $errors = @(Get-ChildItem -LiteralPath $testRoot -Filter '*.error.log' -ErrorAction SilentlyContinue | ForEach-Object { [IO.File]::ReadAllText($_.FullName) })
                    throw ("SYSTEM writer {0} exited with 0x{1:X8}; details={2}" -f $name,[uint32]$info.LastTaskResult,($errors -join ' | '))
                }
                $complete = $true
                break
            }
            Start-Sleep -Milliseconds 150
        } while ((Get-Date) -lt $end)
        if (-not $complete) { throw "Timed out waiting for SYSTEM writer: $name" }
    }
}
function Invoke-Tasks([string[]]$Names) {
    $earliest = Get-Date
    foreach ($name in $Names) { Start-ScheduledTask -TaskName $name }
    Wait-Tasks -Names $Names -Earliest $earliest
}
function Reset-Fixture {
    foreach ($path in @($originPath,$firmwarePath,$defaultPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    [IO.File]::WriteAllText($defaultPath,$a,[Text.Encoding]::ASCII)
}
function Get-NextGuid {
    if (-not (Test-Path -LiteralPath $firmwarePath)) { return '' }
    return [IO.File]::ReadAllText($firmwarePath).Trim()
}
function Get-Origin {
    return ([IO.File]::ReadAllText($originPath,[Text.Encoding]::UTF8) | ConvertFrom-Json)
}

try {
    [void](New-Item -ItemType Directory -Path $defaultDir -Force)
    Install-DirectoryAcl -Path $testRoot
    Install-DirectoryAcl -Path $defaultDir
    [IO.File]::WriteAllBytes($lockPath,[byte[]]@())

    # Validate the real installer ACL setup routines against this test-only path.
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($installerFile,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -ne 0) { throw 'Cannot parse canonical installer.' }
    foreach ($name in @('Protect-BootWriterLockFile','Assert-BootWriterLockFile')) {
        $fn = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true))
        if ($fn.Count -ne 1) { throw "Expected installer function $name exactly once." }
        Invoke-Expression $fn[0].Extent.Text
    }
    $bootWriterLockFile = $lockPath
    Protect-BootWriterLockFile
    Assert-BootWriterLockFile
    Assert-True 'SYSTEM-only lock file is protected' ((Get-Acl -LiteralPath $lockPath).AreAccessRulesProtected)

    # Fake BCDEdit writes to test-only state and emits the same token as bcdedit /enum.
    $mock = @'
$ErrorActionPreference = 'Stop'
$firmwarePath = '__FIRMWARE__'
if ($args.Count -lt 1) { $global:LASTEXITCODE = 1; return }
if ([string]$args[0] -eq '/set') {
    if ($args.Count -ne 4) { $global:LASTEXITCODE = 1; return }
    [IO.File]::WriteAllText($firmwarePath,[string]$args[3],[Text.Encoding]::ASCII)
    $global:LASTEXITCODE = 0
    return
}
if ([string]$args[0] -eq '/enum') {
    if ([IO.File]::Exists($firmwarePath)) {
        Write-Output ('bootsequence ' + [IO.File]::ReadAllText($firmwarePath).Trim())
    }
    $global:LASTEXITCODE = 0
    return
}
$global:LASTEXITCODE = 1
'@
    [IO.File]::WriteAllText($fakeBcd,$mock.Replace('__FIRMWARE__',$firmwarePath.Replace("'","''")),[Text.Encoding]::UTF8)
    $probeSet = (& $fakeBcd /set '{fwbootmgr}' bootsequence $a 2>&1 | Out-String)
    $probeSetExit = $LASTEXITCODE
    $probeEnum = (& $fakeBcd /enum '{fwbootmgr}' /v 2>&1 | Out-String)
    $probeEnumExit = $LASTEXITCODE
    Assert-True 'Fake PowerShell BCDEdit stub supports exact write and read semantics' (
        $probeSetExit -eq 0 -and $probeEnumExit -eq 0 -and
        $probeEnum -match [regex]::Escape($a))
    if (Test-Path -LiteralPath $firmwarePath) { Remove-Item -LiteralPath $firmwarePath -Force }

    $restore = Register-TestWriter -Operation DefaultRestore
    $manual = Register-TestWriter -Operation BootNext -Guid $c
    $set = Register-TestWriter -Operation DefaultSet -Guid $b

    Reset-Fixture
    Invoke-Tasks -Names @($restore,$manual)
    Assert-True 'Concurrent SYSTEM restore and manual BootNext preserve C' ((Get-NextGuid) -eq $c -and (Get-Origin).kind -eq 'manual')

    Invoke-Tasks -Names @($set)
    Assert-True 'SYSTEM DefaultSet B does not overwrite manual C' ((Get-NextGuid) -eq $c -and [IO.File]::ReadAllText($defaultPath).Trim() -eq $b)

    Reset-Fixture
    Invoke-Tasks -Names @($manual,$restore)
    Assert-True 'Manual-first SYSTEM Restore still preserves C' ((Get-NextGuid) -eq $c -and (Get-Origin).kind -eq 'manual')

    Reset-Fixture
    Invoke-Tasks -Names @($restore)
    Invoke-Tasks -Names @($set,$manual)
    Assert-True 'SYSTEM default synchronization racing manual BootNext preserves C' ((Get-NextGuid) -eq $c -and (Get-Origin).kind -eq 'manual')
}
finally {
    foreach ($name in @($tasks)) {
        Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "BOOT WRITER SCHEDULED TOTAL $checks/9"
if ($checks -ne 9) { throw "Unexpected writer scheduled total: $checks" }
