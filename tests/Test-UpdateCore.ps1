#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\UpdateModel.ps1')
$checks = 0
function Assert-True([string]$Name,[bool]$Value) { if (-not $Value) { throw "FAIL $Name" }; $script:checks++; Write-Host "PASS  $Name" }
function Assert-Equal([string]$Name,$Expected,$Actual) { if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }; $script:checks++; Write-Host "PASS  $Name" }

Assert-Equal 'Newer version compares positive' 1 (Compare-LenovoAppVersionCore -Current '0.5.4' -Candidate '0.5.5')
Assert-Equal 'Same version compares zero' 0 (Compare-LenovoAppVersionCore -Current '0.5.5' -Candidate '0.5.5')
Assert-Equal 'Older version compares negative' -1 (Compare-LenovoAppVersionCore -Current '0.5.5' -Candidate '0.5.4')
Assert-Equal 'Major version comparison' 1 (Compare-LenovoAppVersionCore -Current '0.9.9' -Candidate '1.0.0')
Assert-True 'Invalid version returns null' ($null -eq (ConvertTo-LenovoVersionCore -Version '0.5'))
$threw=$false; try { [void](Compare-LenovoAppVersionCore -Current '0.5.5' -Candidate 'dev') } catch { $threw=$true }; Assert-True 'Invalid compare throws' $threw

$files=@('BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1')
$valid=[pscustomobject]@{schemaVersion=1;version='0.5.5';file='LenovoBootMenuTray-v0.5.5.zip';sha256=('a'*64);size=123;tag='v0.5.5';packageFiles=$files}
$r=Test-LenovoUpdateManifestCore -Manifest $valid
Assert-True 'Valid manifest accepted' $r.IsValid
Assert-Equal 'Normalized manifest version' '0.5.5' $r.Version
Assert-Equal 'Normalized manifest filename' 'LenovoBootMenuTray-v0.5.5.zip' $r.File
Assert-Equal 'Normalized manifest file count' 10 @($r.PackageFiles).Count

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
Write-Host "UPDATE TOTAL $checks/24"
if ($checks -ne 24) { throw "Unexpected update test count $checks" }
