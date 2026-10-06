#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\UpdateModel.ps1')
. (Join-Path $root 'src\Application\UpdateRuntime.ps1')
$checks = 0
function Assert-True([string]$Name,[bool]$Value) { if (-not $Value) { throw "FAIL $Name" }; $script:checks++; Write-Host "PASS  $Name" }
function Assert-Equal([string]$Name,$Expected,$Actual) { if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }; $script:checks++; Write-Host "PASS  $Name" }

Assert-Equal 'Newer version compares positive' 1 (Compare-LenovoAppVersionCore -Current '0.5.6' -Candidate '0.5.7')
Assert-Equal 'Same version compares zero' 0 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7')
Assert-Equal 'Older version compares negative' -1 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.6')
Assert-Equal 'Major version comparison' 1 (Compare-LenovoAppVersionCore -Current '0.9.9' -Candidate '1.0.0')
Assert-Equal 'Legacy three-part equals explicit hotfix zero' 0 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7.0')
Assert-Equal 'Hotfix compares newer than legacy patch' 1 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7.1')
Assert-Equal 'Higher hotfix compares newer' 1 (Compare-LenovoAppVersionCore -Current '0.5.7.1' -Candidate '0.5.7.2')
Assert-True 'Four-part version parses' ($null -ne (ConvertTo-LenovoVersionCore -Version '0.5.8.0'))
Assert-True 'Invalid version returns null' ($null -eq (ConvertTo-LenovoVersionCore -Version '0.5'))

$runtime=New-UpdateRuntimeState
Assert-True 'Startup update check starts unattempted' (-not $runtime.StartupCheckStarted)
Assert-True 'Startup update check starts incomplete' (-not $runtime.StartupCheckCompleted)
Assert-Equal 'Update check mode starts empty' '' $runtime.CheckMode
$threw=$false; try { [void](Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate 'dev') } catch { $threw=$true }; Assert-True 'Invalid compare throws' $threw

$files=@('BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1')
$valid=[pscustomobject]@{schemaVersion=1;version='0.5.8.1';file='LenovoBootMenuTray-v0.5.8.1.zip';sha256=('a'*64);size=123;tag='v0.5.8.1';packageFiles=$files}
$r=Test-LenovoUpdateManifestCore -Manifest $valid
Assert-True 'Valid manifest accepted' $r.IsValid
Assert-Equal 'Normalized manifest schema version' 1 $r.SchemaVersion
Assert-Equal 'Normalized manifest version' '0.5.8.1' $r.Version
Assert-Equal 'Normalized manifest filename' 'LenovoBootMenuTray-v0.5.8.1.zip' $r.File
Assert-Equal 'Normalized manifest file count' 10 @($r.PackageFiles).Count
$json=$r | ConvertTo-Json -Depth 10; $round=$json | ConvertFrom-Json; $roundResult=Test-LenovoUpdateManifestCore -Manifest $round; Assert-True 'Manifest survives worker JSON roundtrip' $roundResult.IsValid

$x=$valid.psobject.Copy(); $x.schemaVersion=2; Assert-True 'Unknown schema rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.version='0.5'; Assert-True 'Malformed version rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.file='other.zip'; Assert-True 'Filename/version mismatch rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.sha256='abc'; Assert-True 'Malformed SHA rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.size=0; Assert-True 'Zero size rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.tag='latest'; Assert-True 'Tag/version mismatch rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@(); Assert-True 'Missing package files rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files + '..\evil.ps1'); Assert-True 'Unsafe package filename rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files + 'README.md'); Assert-True 'Duplicate package filename rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'LenovoBootMenuTray.ps1' }); Assert-True 'Missing runtime rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Start-LenovoBootMenuTray.vbs' }); Assert-True 'Missing launcher rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Install-LenovoBootMenuTasks.ps1' }); Assert-True 'Missing installer rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Uninstall-LenovoBootMenuTasks.ps1' }); Assert-True 'Missing uninstaller rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
Assert-True 'Null manifest rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $null).IsValid)

$legacyOk=[pscustomobject]@{utc='2026-10-05T11:00:00Z';success=$true;message='Update auf v0.5.8.1 installiert.'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $legacyOk -RunningVersion '0.5.8.1'
Assert-Equal 'Legacy success format detected' 'legacy-success' $rr.ResultFormat
Assert-True 'Legacy success is successful' $rr.Success
Assert-Equal 'Legacy success display uses running version' '0.5.8.1' $rr.DisplayVersion
Assert-Equal 'Legacy success does not invent target version' '' $rr.TargetVersion
Assert-True 'Legacy success message reports actual running version' ($rr.Message -match 'Aktuell läuft v0\.5\.8\.1')

$legacyFail=[pscustomobject]@{utc='2026-10-05T11:00:00Z';success=$false;message='Legacy install failed'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $legacyFail -RunningVersion '0.5.8.1'
Assert-Equal 'Legacy failure format detected' 'legacy-success' $rr.ResultFormat
Assert-True 'Legacy false remains failure' (-not $rr.Success)
Assert-Equal 'Legacy failure keeps helper message' 'Legacy install failed' $rr.Message

$newPending=[pscustomobject]@{schemaVersion=1;status='pending-verification';sourceVersion='0.5.8.0';targetVersion='0.5.8.1';utc='2026-10-05T11:00:00Z';message='pending';rollbackAttempted=$false;rollbackSucceeded=$false}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $newPending -RunningVersion '0.5.8.1'
Assert-Equal 'Status format remains primary' 'status' $rr.ResultFormat
Assert-True 'Pending verification succeeds on exact running target' $rr.Success
Assert-Equal 'Pending verification preserves target version' '0.5.8.1' $rr.TargetVersion

$mixed=[pscustomobject]@{status='failed';success=$true;message='new format wins';rollbackAttempted=$false;rollbackSucceeded=$false}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $mixed -RunningVersion '0.5.8.1'
Assert-Equal 'Status wins over legacy success field' 'status' $rr.ResultFormat
Assert-True 'Failed status wins over legacy success true' (-not $rr.Success)

$malformed=[pscustomobject]@{success='true';message='not a Boolean'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $malformed -RunningVersion '0.5.8.1'
Assert-Equal 'Non-Boolean legacy success is rejected' 'unknown' $rr.ResultFormat
Assert-True 'Malformed legacy result fails closed' (-not $rr.Success)
Write-Host "UPDATE TOTAL $checks/47"
if ($checks -ne 47) { throw "Unexpected update test count $checks" }
