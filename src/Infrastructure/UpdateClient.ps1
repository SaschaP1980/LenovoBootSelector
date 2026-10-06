function Get-LenovoUpdateResultPath {
    $root = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    return (Join-Path $root 'last-update-result.json')
}

function Read-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $json = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($json)) { return $null }
        return ($json | ConvertFrom-Json)
    }
    catch {
        return [pscustomobject]@{
            schemaVersion = 1
            status = 'failed'
            sourceVersion = ''
            targetVersion = ''
            utc = [datetime]::UtcNow.ToString('o')
            message = ('Update-Ergebnis konnte nicht gelesen werden: ' + $_.Exception.Message)
            rollbackAttempted = $false
            rollbackSucceeded = $false
        }
    }
}

function Remove-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    try {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    } catch { }
}


function Get-LenovoUpdateManifestRemote {
    $json = Invoke-LenovoUpdateTextDownload -Uri (Get-LenovoUpdateManifestUri)
    if ([string]::IsNullOrWhiteSpace($json)) { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-content' -Message 'Update-Manifest ist leer.') }
    try { return ($json | ConvertFrom-Json) }
    catch { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-parse' -Message ('Update-Manifest ist kein gültiges JSON: ' + $_.Exception.Message) -InnerException $_.Exception) }
}
function Get-LenovoSha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try { $hash = $sha.ComputeHash($stream) }
        finally { $stream.Dispose() }
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally { $sha.Dispose() }
}

function Write-LenovoUpdateWorkerResult {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path,$json,(New-Object System.Text.UTF8Encoding($false)))
}


function Invoke-UpdateCheckWorker {
    $result = [ordered]@{ Success=$false; UpdateAvailable=$false; Manifest=$null; Error=''; ErrorCategory=''; FailureStage=''; ErrorClass=''; NetworkStatus='' }
    try {
        $raw = Get-LenovoUpdateManifestRemote
        $validated = Test-LenovoUpdateManifestCore -Manifest $raw
        if (-not $validated.IsValid) { throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-validation' -Message $validated.Error) }
        $comparison = Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version
        $result.Success = $true; $result.UpdateAvailable = ($comparison -gt 0); $result.Manifest = $validated
    }
    catch {
        $failure = Get-LenovoUpdateFailureInfo -ErrorRecord $_ -DefaultCategory 'runtime' -DefaultStage 'update-check'
        $result.Error=$failure.Message; $result.ErrorCategory=$failure.Category; $result.FailureStage=$failure.Stage; $result.ErrorClass=$failure.ErrorClass; $result.NetworkStatus=$failure.NetworkStatus
    }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_WORKER_COMPLETED' -Stage $(if ($result.FailureStage) { [string]$result.FailureStage } else { 'update-check' }) -Success ([bool]$result.Success) -Data (New-RuntimeDiagnosticData @{ updateAvailable=[bool]$result.UpdateAvailable; errorCategory=[string]$result.ErrorCategory; failureStage=[string]$result.FailureStage; errorClass=[string]$result.ErrorClass; networkStatus=[string]$result.NetworkStatus; workerError=[string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'warning' })
    if ($UpdateResultPath) { Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result) }
    return $(if ($result.Success) { 0 } else { 1 })
}
function Start-UpdateCheckWorkerProcess {
    param([Parameter(Mandatory=$true)][string]$ResultPath,[string]$RuntimeSessionId)
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdateCheck','-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}


function Test-LenovoUpdatePackageZip {
    param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)]$Manifest)
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try { $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath) }
    catch { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message ('Update-ZIP konnte nicht geöffnet werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    try {
        $names=@()
        foreach($entry in @($archive.Entries)) {
            $name=[string]$entry.FullName
            if ([string]::IsNullOrWhiteSpace($name)) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen leeren Pfad.') }
            if ($name.Contains('..') -or $name.Contains('/') -or $name.Contains('\')) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen unzulässigen Pfad.') }
            if ($entry.Length -lt 0) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält einen ungültigen Eintrag.') }
            $names+=$name
        }
        $expected=@($Manifest.PackageFiles|Sort-Object); $actual=@($names|Sort-Object)
        if ($expected.Count -ne $actual.Count) { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP enthält nicht die erwartete Anzahl Dateien.') }
        for($i=0;$i -lt $expected.Count;$i++){ if([string]$expected[$i] -ne [string]$actual[$i]){ throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-structure' -Message 'Update-ZIP-Dateiliste stimmt nicht mit dem Manifest überein.') } }
    } finally { $archive.Dispose() }
}

function Prepare-LenovoUpdatePackage {
    param([Parameter(Mandatory=$true)]$Manifest)
    $updateRoot=Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    try {
        if(-not(Test-Path -LiteralPath $updateRoot)){[void](New-Item -ItemType Directory -Path $updateRoot -Force)}
        $work=Join-Path $updateRoot (('{0}-{1}' -f $Manifest.Version,([guid]::NewGuid().ToString('N')))); $payload=Join-Path $work 'payload'
        [void](New-Item -ItemType Directory -Path $payload -Force); $zipPath=Join-Path $work ([string]$Manifest.File); $manifestPath=Join-Path $work 'manifest.json'
        [System.IO.File]::WriteAllText($manifestPath,($Manifest|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    } catch { throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-workspace' -Message ('Update-Arbeitsverzeichnis konnte nicht vorbereitet werden: '+$_.Exception.Message) -InnerException $_.Exception) }
    $uri=(Get-LenovoUpdateDownloadBaseUri)+[Uri]::EscapeDataString([string]$Manifest.File); Invoke-LenovoUpdateFileDownload -Uri $uri -DestinationPath $zipPath
    $length=(Get-Item -LiteralPath $zipPath).Length
    if([int64]$length -ne [int64]$Manifest.Size){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-size' -Message 'Update-Dateigröße stimmt nicht mit dem Manifest überein.')}
    try{$actualSha=Get-LenovoSha256Hex -Path $zipPath}catch{throw (New-LenovoUpdateFailureException -Category 'hash' -Stage 'package-hash' -Message ('Update-SHA-256 konnte nicht berechnet werden: '+$_.Exception.Message) -InnerException $_.Exception)}
    if($actualSha -ne ([string]$Manifest.Sha256).ToLowerInvariant()){throw (New-LenovoUpdateFailureException -Category 'hash' -Stage 'package-hash' -Message 'Update-SHA-256 stimmt nicht mit dem Manifest überein.')}
    Test-LenovoUpdatePackageZip -ZipPath $zipPath -Manifest $Manifest
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try{[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$payload)}catch{throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-extract' -Message ('Update-ZIP konnte nicht entpackt werden: '+$_.Exception.Message) -InnerException $_.Exception)}
    $runtimePath=Join-Path $payload 'LenovoBootMenuTray.ps1'
    if(-not(Test-Path -LiteralPath $runtimePath -PathType Leaf)){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-runtime' -Message 'Update-Runtime fehlt im Paket.')}
    $runtimeText=[System.IO.File]::ReadAllText($runtimePath,[System.Text.Encoding]::UTF8); $versionNeedle=('$script:AppVersion = ''{0}''' -f [string]$Manifest.Version)
    if(-not $runtimeText.Contains($versionNeedle)){throw (New-LenovoUpdateFailureException -Category 'package' -Stage 'package-runtime' -Message 'Update-Runtime-Version stimmt nicht mit dem Manifest überein.')}
    return [pscustomobject]@{WorkDir=$work;PayloadDir=$payload;ManifestPath=$manifestPath;Version=[string]$Manifest.Version}
}

function Invoke-UpdatePrepareWorker {
    $result=[ordered]@{Success=$false;WorkDir='';PayloadDir='';ManifestPath='';Version='';Error='';ErrorCategory='';FailureStage='';ErrorClass='';NetworkStatus=''}
    try {
        if(-not $UpdateManifestPath -or -not(Test-Path -LiteralPath $UpdateManifestPath -PathType Leaf)){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-input' -Message 'Update-Manifestdatei fehlt.')}
        try{$manifestJson=[System.IO.File]::ReadAllText($UpdateManifestPath,[System.Text.Encoding]::UTF8)}catch{throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-input' -Message ('Update-Manifestdatei konnte nicht gelesen werden: '+$_.Exception.Message) -InnerException $_.Exception)}
        try{$raw=$manifestJson|ConvertFrom-Json}catch{throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-parse' -Message ('Update-Manifest ist kein gültiges JSON: '+$_.Exception.Message) -InnerException $_.Exception)}
        $validated=Test-LenovoUpdateManifestCore -Manifest $raw
        if(-not $validated.IsValid){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'manifest-validation' -Message $validated.Error)}
        if((Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version) -le 0){throw (New-LenovoUpdateFailureException -Category 'manifest' -Stage 'version-eligibility' -Message 'Es liegt keine neuere Version vor.')}
        $prepared=Prepare-LenovoUpdatePackage -Manifest $validated; $result.Success=$true; $result.WorkDir=$prepared.WorkDir; $result.PayloadDir=$prepared.PayloadDir; $result.ManifestPath=$prepared.ManifestPath; $result.Version=$prepared.Version
    } catch {
        $failure=Get-LenovoUpdateFailureInfo -ErrorRecord $_ -DefaultCategory 'runtime' -DefaultStage 'update-prepare'
        $result.Error=$failure.Message; $result.ErrorCategory=$failure.Category; $result.FailureStage=$failure.Stage; $result.ErrorClass=$failure.ErrorClass; $result.NetworkStatus=$failure.NetworkStatus
    }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_WORKER_COMPLETED' -Stage $(if($result.FailureStage){[string]$result.FailureStage}else{'update-prepare'}) -Success ([bool]$result.Success) -Data (New-RuntimeDiagnosticData @{version=[string]$result.Version;errorCategory=[string]$result.ErrorCategory;failureStage=[string]$result.FailureStage;errorClass=[string]$result.ErrorClass;networkStatus=[string]$result.NetworkStatus;workerError=[string]$result.Error}) -Level $(if($result.Success){'info'}else{'error'})
    if($UpdateResultPath){Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result)}
    return $(if($result.Success){0}else{1})
}
function Start-UpdatePrepareWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [string]$RuntimeSessionId
    )
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdatePrepare','-UpdateManifestPath',('"{0}"' -f $ManifestPath),'-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}

function Test-UpdateInstallDirectoryWritable {
    $probe = Join-Path $PSScriptRoot ('.lbs-update-write-{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllText($probe,'probe',(New-Object System.Text.UTF8Encoding($false)))
        return $true
    }
    catch { return $false }
    finally { try { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force } } catch { } }
}

function New-LenovoUpdateInstallerHelper {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helperPath = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelectorUpdate-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
    $scriptText = @'
param(
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$InstallDir,
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [Parameter(Mandatory=$true)][string]$SourceVersion,
    [Parameter(Mandatory=$true)][string]$FailurePrefixBase64,
    [Parameter(Mandatory=$true)][string]$ManualRestartBase64
)
$ErrorActionPreference = 'Stop'
$backup = Join-Path $WorkDir 'backup'
$payload = Join-Path $WorkDir 'payload'
$manifestPath = Join-Path $WorkDir 'manifest.json'
$resultPath = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates\last-update-result.json'
$targetVersion = ''
$rollbackAttempted = $false
$rollbackSucceeded = $false
$failureCategory = ''
$failureStage = ''
$errorClass = ''
$failurePrefix = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FailurePrefixBase64))
$manualRestartMessage = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ManualRestartBase64))
function Write-Result([string]$Status,[string]$Message) {
    $parent = Split-Path -Parent $resultPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $obj=[ordered]@{
        schemaVersion=1
        utc=[datetime]::UtcNow.ToString('o')
        status=$Status
        sourceVersion=$SourceVersion
        targetVersion=$targetVersion
        message=$Message
        rollbackAttempted=[bool]$rollbackAttempted
        rollbackSucceeded=[bool]$rollbackSucceeded
        failureCategory=[string]$failureCategory
        failureStage=[string]$failureStage
        errorClass=[string]$errorClass
    }
    [System.IO.File]::WriteAllText($resultPath,($obj|ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding($false)))
}
function Restart-InstalledApp {
    $launcher=Join-Path $InstallDir 'Start-LenovoBootMenuTray.vbs'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw 'Launcher fehlt nach dem Update.' }
    $wscript=Join-Path $env:SystemRoot 'System32\wscript.exe'
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName=$wscript
    $psi.Arguments=('"{0}"' -f $launcher)
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    return [System.Diagnostics.Process]::Start($psi)
}
function Show-UpdateError([string]$Message) {
    try { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($Message,'Lenovo Boot Selector – Update',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) } catch { }
}
try {
    $failureCategory='manifest'; $failureStage='install-manifest'; $errorClass=''
    try { $parent=[System.Diagnostics.Process]::GetProcessById($ParentPid); [void]$parent.WaitForExit(30000) } catch { }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest fehlt.' }
    $manifest=[System.IO.File]::ReadAllText($manifestPath,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
    $targetVersion=[string]$manifest.version
    $files=@($manifest.packageFiles)
    if ($files.Count -lt 1) { throw 'Paketdateien fehlen.' }
    $failureCategory='install'; $failureStage='backup'; $errorClass=''
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $backup -Force)
    $existing=@{}
    foreach($name in $files) {
        $source=Join-Path $payload ([string]$name)
        $target=Join-Path $InstallDir ([string]$name)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Paketdatei fehlt: $name" }
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $existing[[string]$name]=$true
            Copy-Item -LiteralPath $target -Destination (Join-Path $backup ([string]$name)) -Force
        }
        else { $existing[[string]$name]=$false }
    }
    try {
        $failureCategory='install'; $failureStage='install-files'; $errorClass=''
        foreach($name in $files) {
            Copy-Item -LiteralPath (Join-Path $payload ([string]$name)) -Destination (Join-Path $InstallDir ([string]$name)) -Force
        }
        # Success is intentionally not declared here. The restarted tray must prove
        # that the expected target version is actually running before showing success.
        $failureCategory=''; $failureStage=''; $errorClass=''
        Write-Result 'pending-verification' ('Update auf v' + $targetVersion + ' installiert; Neustart-Verifikation ausstehend.')
        $failureCategory='restart'; $failureStage='restart-after-install'; $errorClass=''
        $started = Restart-InstalledApp
        if (-not $started) { throw 'Lenovo Boot Selector konnte nach dem Update nicht neu gestartet werden.' }
        try { $started.Dispose() } catch { }
    }
    catch {
        $installError=$_.Exception.Message
        $primaryFailureCategory=$failureCategory
        $primaryFailureStage=$failureStage
        $primaryErrorClass=$_.Exception.GetType().FullName
        # ROLLBACK: restore every previous managed file and remove newly introduced files.
        $rollbackAttempted=$true
        $failureCategory='install'; $failureStage='rollback'; $errorClass=''
        try {
            foreach($name in $files) {
                $target=Join-Path $InstallDir ([string]$name)
                $saved=Join-Path $backup ([string]$name)
                if ($existing[[string]$name] -and (Test-Path -LiteralPath $saved -PathType Leaf)) {
                    Copy-Item -LiteralPath $saved -Destination $target -Force
                }
                elseif (-not $existing[[string]$name] -and (Test-Path -LiteralPath $target -PathType Leaf)) {
                    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
                }
            }
            $rollbackSucceeded=$true
        }
        catch {
            $rollbackSucceeded=$false
            throw ($installError + ' | Rollback fehlgeschlagen: ' + $_.Exception.Message)
        }
        $failureCategory=$primaryFailureCategory
        $failureStage=$primaryFailureStage
        $errorClass=$primaryErrorClass
        throw $installError
    }
    try { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
catch {
    $failureMessage=$_.Exception.Message
    if (-not $errorClass) { $errorClass=$_.Exception.GetType().FullName }
    if (-not $failureCategory) { $failureCategory='install' }
    if (-not $failureStage) { $failureStage='install' }
    Write-Result 'failed' $failureMessage
    try {
        $restart = Restart-InstalledApp
        if ($restart) { try { $restart.Dispose() } catch { } }
        else { throw 'Lenovo Boot Selector konnte nach dem fehlgeschlagenen Update nicht neu gestartet werden.' }
    }
    catch {
        Show-UpdateError ($failurePrefix + "`r`n`r`n" + $manualRestartMessage)
    }
}
finally {
    try { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue } catch { }
}
'@
    [System.IO.File]::WriteAllText($helperPath,$scriptText,(New-Object System.Text.UTF8Encoding($true)))
    return $helperPath
}

function Start-LenovoUpdateInstallerHelper {
    param(
        [Parameter(Mandatory=$true)][string]$WorkDir,
        [Parameter(Mandatory=$true)][string]$SourceVersion,
        [Parameter(Mandatory=$true)][string]$FailurePrefix,
        [Parameter(Mandatory=$true)][string]$ManualRestartMessage
    )
    $helper = New-LenovoUpdateInstallerHelper -WorkDir $WorkDir
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $failurePrefixBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($FailurePrefix))
    $manualRestartBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ManualRestartMessage))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -ParentPid {1} -InstallDir "{2}" -WorkDir "{3}" -SourceVersion "{4}" -FailurePrefixBase64 "{5}" -ManualRestartBase64 "{6}"' -f $helper,$PID,$PSScriptRoot,$WorkDir,$SourceVersion,$failurePrefixBase64,$manualRestartBase64)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}
