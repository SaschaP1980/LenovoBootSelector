#requires -version 5.1
# LBS-143: safe, non-privileged execution of the exact fixed SYSTEM writer body.
# Only temporary data and a fake BCDEdit CMD file are used. Real BCD is untouched.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$installer = [IO.File]::ReadAllText((Join-Path $root 'bin\Install-LenovoBootMenuTasks.ps1'),[Text.Encoding]::UTF8)
$checks = 0
function Assert-True([string]$Name,[bool]$Condition) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Name" }
    Write-Host "PASS  $Name"
}
$pattern = '(?s)\$coordinatedTaskTemplate = @''\r?\n(.*?)\r?\n''@'
$match = [regex]::Match($installer,$pattern)
Assert-True 'Privileged writer is embedded as a single fixed source template' $match.Success
$body = $match.Groups[1].Value
Assert-True 'Writer requires pre-installed exclusive lock file' ($body.Contains("[IO.File]::Open(") -and $body.Contains('[IO.FileShare]::None') -and $body.Contains('[IO.FileMode]::Open'))
Assert-True 'Unprotected global named mutex is absent' (-not $body.Contains('Global\LenovoBootSelector-BootNext'))
Assert-True 'Writer uses a bounded lock acquisition deadline' ($body.Contains('lockWait.ElapsedMilliseconds') -and $body.Contains('8000'))
Assert-True 'Manual provenance has a protected increasing sequence' ($body.Contains('seq = $script:writerSeq') -and $body.Contains("'pending-manual'") -and $body.Contains("'manual'"))
Assert-True 'Atomic provenance replacement uses a legal backup path on PS5.1' ($body.Contains('[IO.File]::Replace($tmp,$originPath,$backup)') -and -not $body.Contains('[IO.File]::Replace($tmp,$originPath,$null)'))
Assert-True 'A queued restore preserves completed manual intent' ($body.Contains("origin.kind -in @('manual','pending-manual','pending-auto')"))
Assert-True 'Installer provisions writer-only state file' ($installer.Contains('function Protect-BootWriterLockFile') -and $installer.Contains('Protect-BootWriterLockFile'))
Assert-True 'Installer requires Queue for fixed writer tasks' ($installer.Contains('-MultipleInstances Queue') -and $installer.Contains('MultipleInstancesPolicy') -and $installer.Contains('SerializedWriter'))

$temp = Join-Path ([IO.Path]::GetTempPath()) ('LBS143-Writer-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
$defaultPath = Join-Path $temp 'default.txt'
$originPath = Join-Path $temp 'origin.json'
$lockPath = Join-Path $temp 'writer.lock'
$firmwarePath = Join-Path $temp 'firmware.txt'
$fakeBcd = Join-Path $temp 'fake-bcdedit.cmd'
$psExe = Join-Path $PSHOME 'powershell.exe'
$a = '{11111111-1111-1111-1111-111111111111}'
$b = '{22222222-2222-2222-2222-222222222222}'
$c = '{33333333-3333-3333-3333-333333333333}'
try {
    [IO.File]::WriteAllBytes($lockPath,[byte[]]@())
    [IO.File]::WriteAllText($fakeBcd,@'
@echo off
if "%1"=="/enum" (
  if exist "%LBS143_FAKE_FIRMWARE%" for /f %%G in ('type "%LBS143_FAKE_FIRMWARE%"') do echo bootsequence %%G
  exit /b 0
)
if "%1"=="/set" (
  > "%LBS143_FAKE_FIRMWARE%" echo %4
  exit /b 0
)
exit /b 1
'@,[Text.Encoding]::ASCII)
    $env:LBS143_FAKE_FIRMWARE = $firmwarePath

    function Reset-Fixture([string]$OldDefault) {
        foreach ($path in @($defaultPath,$originPath,$firmwarePath)) {
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        }
        if ($OldDefault) { [IO.File]::WriteAllText($defaultPath,$OldDefault) }
    }
    function Read-Next {
        if (-not (Test-Path -LiteralPath $firmwarePath)) { return '' }
        return ([IO.File]::ReadAllText($firmwarePath)).Trim()
    }
    function Read-Origin {
        return ([IO.File]::ReadAllText($originPath,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    }
    function New-WriterScript([string]$Operation,[string]$Guid='') {
        $scriptText = $body.Replace('__OP__',$Operation).Replace('__GUID__',$Guid)
        $scriptText = $scriptText.Replace('__ALLOWED__',("'$a','$b','$c'"))
        $scriptText = $scriptText.Replace('__DEFAULT__',$defaultPath.Replace("'","''"))
        $scriptText = $scriptText.Replace('__ORIGIN__',$originPath.Replace("'","''"))
        $scriptText = $scriptText.Replace('__LOCK__',$lockPath.Replace("'","''"))
        $scriptText = $scriptText.Replace('__BCDEDIT__',$fakeBcd.Replace("'","''"))
        $file = Join-Path $temp ('writer-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [IO.File]::WriteAllText($file,$scriptText,[Text.Encoding]::UTF8)
        return $file
    }
    function Invoke-Writer([string]$Operation,[string]$Guid='') {
        $file = New-WriterScript -Operation $Operation -Guid $Guid
        $out = $file + '.out'
        $err = $file + '.err'
        try {
            $proc = Start-Process -FilePath $psExe -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $file + '"') -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
            try {
                $output = ([IO.File]::ReadAllText($out) + [IO.File]::ReadAllText($err))
                return [pscustomobject]@{ Code = [int]$proc.ExitCode; Output = $output }
            }
            finally { $proc.Dispose() }
        }
        finally {
            foreach ($path in @($file,$out,$err)) { Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue }
        }
    }
    function Invoke-TwoWriters([string]$First,[string]$FirstGuid,[string]$Second,[string]$SecondGuid) {
        $firstFile = New-WriterScript -Operation $First -Guid $FirstGuid
        $secondFile = New-WriterScript -Operation $Second -Guid $SecondGuid
        $processes = @()
        try {
            foreach ($file in @($firstFile,$secondFile)) {
                $processes += Start-Process -FilePath $psExe -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $file + '"') -PassThru
            }
            $finished = $true
            foreach ($process in $processes) {
                if (-not $process.WaitForExit(30000)) {
                    $finished = $false
                    $process.Kill()
                    [void]$process.WaitForExit(5000)
                }
            }
            return ($finished -and @($processes | Where-Object { $_.ExitCode -ne 0 }).Count -eq 0)
        }
        finally {
            foreach ($process in $processes) { $process.Dispose() }
            foreach ($file in @($firstFile,$secondFile)) { Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue }
        }
    }

    Reset-Fixture $a
    $r = Invoke-Writer -Operation DefaultRestore
    if ($r.Code -ne 0 -or (Read-Next) -ne $a -or -not (Test-Path -LiteralPath $originPath)) {
        Write-Host ("LBS143_INITIAL_RESTORE_DIAGNOSTIC code={0}; next={1}; originPresent={2}; childOutput={3}" -f $r.Code,(Read-Next),(Test-Path -LiteralPath $originPath),$r.Output)
    }
    Assert-True 'Initial restore writes a verified automatic A' ($r.Code -eq 0 -and (Read-Next) -eq $a -and (Read-Origin).kind -eq 'auto')

    $r = Invoke-Writer -Operation DefaultSet -Guid $b
    Assert-True 'Verified auto A synchronizes to new default B' ($r.Code -eq 0 -and (Read-Next) -eq $b -and ([IO.File]::ReadAllText($defaultPath)) -eq $b)

    $oldSequence = [int64](Read-Origin).seq
    $r = Invoke-Writer -Operation DefaultSet -Guid $b
    Assert-True 'Repeated same-value default set never rewrites automatic BootNext' ($r.Code -eq 0 -and (Read-Next) -eq $b -and [int64](Read-Origin).seq -eq $oldSequence)

    $r = Invoke-Writer -Operation BootNext -Guid $c
    $manual = Read-Origin
    Assert-True 'Manual C creates verified manual provenance' ($r.Code -eq 0 -and (Read-Next) -eq $c -and $manual.kind -eq 'manual' -and [int64]$manual.seq -gt 0)

    $r = Invoke-Writer -Operation DefaultSet -Guid $a
    Assert-True 'Later default change must preserve manual C' ($r.Code -eq 0 -and (Read-Next) -eq $c -and ([IO.File]::ReadAllText($defaultPath)) -eq $a)

    $r = Invoke-Writer -Operation DefaultRestore
    Assert-True 'Delayed startup restore must preserve manual C' ($r.Code -eq 0 -and (Read-Next) -eq $c -and (Read-Origin).kind -eq 'manual')

    $seq = [int64](Read-Origin).seq
    $r = Invoke-Writer -Operation BootNext -Guid $c
    Assert-True 'Repeated manual C yields a new protected completion sequence' ($r.Code -eq 0 -and [int64](Read-Origin).seq -gt $seq)

    Reset-Fixture $a
    $r = Invoke-Writer -Operation BootNext -Guid $c
    $r = Invoke-Writer -Operation DefaultRestore
    Assert-True 'Manual C before delayed restore is never overwritten' ($r.Code -eq 0 -and (Read-Next) -eq $c)

    Reset-Fixture $a
    $ok = Invoke-TwoWriters -First DefaultRestore -FirstGuid '' -Second BootNext -SecondGuid $c
    Assert-True 'Concurrent restore and manual task preserve manual C regardless of order' ($ok -and (Read-Next) -eq $c -and (Read-Origin).kind -eq 'manual')

    Reset-Fixture $a
    $r = Invoke-Writer -Operation DefaultRestore
    $ok = Invoke-TwoWriters -First DefaultSet -FirstGuid $b -Second BootNext -SecondGuid $c
    Assert-True 'Concurrent auto synchronization and manual C preserve manual priority' ($ok -and (Read-Next) -eq $c -and (Read-Origin).kind -eq 'manual')

    Reset-Fixture $a
    $r = Invoke-Writer -Operation DefaultRestore
    [IO.File]::WriteAllText($firmwarePath,$c)
    $r = Invoke-Writer -Operation DefaultSet -Guid $b
    Assert-True 'Observable external mismatch blocks automatic synchronization' ($r.Code -eq 0 -and (Read-Next) -eq $c)

    Reset-Fixture $a
    [IO.File]::WriteAllText($originPath,('{"schema":1,"bootId":"0","kind":"manual","guid":"' + $c + '","seq":12}'))
    $r = Invoke-Writer -Operation DefaultRestore
    Assert-True 'Manual provenance from an older real boot cycle is ignored' ($r.Code -eq 0 -and (Read-Next) -eq $a)

    Reset-Fixture $a
    [IO.File]::WriteAllText($originPath,'invalid-json')
    $r = Invoke-Writer -Operation DefaultRestore
    Assert-True 'Corrupt protected provenance fails closed' ($r.Code -ne 0 -and -not (Test-Path -LiteralPath $firmwarePath))

    Reset-Fixture $a
    $held = [IO.File]::Open($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        $r = Invoke-Writer -Operation DefaultRestore
        Assert-True 'Contended writer lock times out without changing firmware' ($r.Code -ne 0 -and -not (Test-Path -LiteralPath $firmwarePath))
    }
    finally { $held.Dispose() }
    Remove-Item -LiteralPath $lockPath -Force
    $r = Invoke-Writer -Operation DefaultRestore
    Assert-True 'Missing pre-installed writer lock fails closed' ($r.Code -ne 0 -and -not (Test-Path -LiteralPath $firmwarePath))
}
finally {
    Remove-Item Env:LBS143_FAKE_FIRMWARE -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
Write-Host "BOOT WRITER PRIORITY TOTAL $checks/24"
if ($checks -ne 24) { throw "Unexpected boot writer priority count $checks" }
