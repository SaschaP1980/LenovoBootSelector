#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Infrastructure\Autostart.ps1')

$checks = 0
function Assert-True([string]$Name,[bool]$Value) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Assert-Equal([string]$Name,$Expected,$Actual) {
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$script:AutostartRunValueName = 'Lenovo Boot Selector'
$script:LegacyAutostartRunValueName = 'Lenovo Boot Menu Tray'
$script:LegacyAutostartTaskName = 'Lenovo Boot Menu Tray Autostart'
$script:ScriptPath = 'C:\App\LenovoBootMenuTray.ps1'
$script:FakeLauncherPath = 'C:\App\Start-LenovoBootMenuTray.vbs'
$script:FakeAutostartCommand = '"C:\Windows\System32\wscript.exe" //B //NoLogo "C:\App\Start-LenovoBootMenuTray.vbs"'
$script:FakeRunValues = @{}
$script:FakeSetCalls = 0
$script:FakeSetShouldFail = $false

function Get-AutostartLauncherPath { return $script:FakeLauncherPath }
function Get-AutostartCommand { return $script:FakeAutostartCommand }
function Get-ItemProperty {
    param([string]$Path,[string]$Name,[object]$ErrorAction)
    if (-not $script:FakeRunValues.ContainsKey($Name)) { return $null }
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name $Name -Value $script:FakeRunValues[$Name]
    return $obj
}
function Set-ItemProperty {
    param([string]$Path,[string]$Name,[object]$Type,[string]$Value)
    if ($script:FakeSetShouldFail) { throw 'simulated canonical Run-value write failure' }
    $script:FakeRunValues[$Name] = $Value
    $script:FakeSetCalls++
}
function Remove-ItemProperty {
    param([string]$Path,[string]$Name,[object]$ErrorAction)
    if ($script:FakeRunValues.ContainsKey($Name)) { [void]$script:FakeRunValues.Remove($Name) }
}
function Test-Path {
    param([string]$Path,[string]$LiteralPath,[object]$PathType)
    return $true
}
function New-Item {
    param([object]$ItemType,[string]$Path,[switch]$Force)
    return [pscustomobject]@{ FullName=$Path }
}

$script:FakeRunValues[$script:LegacyAutostartRunValueName] = $script:FakeAutostartCommand
$script:FakeRunValues['Unrelated App'] = 'leave-me'
$legacyInfo = Get-AutostartInfo
Assert-True 'Legacy-only autostart registration is recognized' ([bool]$legacyInfo.Enabled)
Assert-True 'Legacy-only autostart registration is marked for migration' ([bool]$legacyInfo.UsesLegacyValue)
Assert-True 'Legacy-only autostart registration still resolves current launcher path' ([bool]$legacyInfo.CurrentPath)
Assert-True 'Canonical Run value is absent before migration' (-not $script:FakeRunValues.ContainsKey($script:AutostartRunValueName))

$script:FakeSetShouldFail = $true
$writeFailed = $false
try { Set-AutostartEnabled -Enabled:$true } catch { $writeFailed = $true }
Assert-True 'Canonical Run-value write failure is surfaced' $writeFailed
Assert-True 'Failed canonical write leaves working legacy Run value intact' ($script:FakeRunValues.ContainsKey($script:LegacyAutostartRunValueName))
Assert-True 'Failed canonical write does not invent canonical Run value' (-not $script:FakeRunValues.ContainsKey($script:AutostartRunValueName))
$script:FakeSetShouldFail = $false

Set-AutostartEnabled -Enabled:$true
Assert-True 'Enabling autostart writes canonical Run value' ($script:FakeRunValues.ContainsKey($script:AutostartRunValueName))
Assert-Equal 'Canonical Run value receives current launcher command' $script:FakeAutostartCommand $script:FakeRunValues[$script:AutostartRunValueName]
Assert-True 'Legacy Run value is removed only after canonical write' (-not $script:FakeRunValues.ContainsKey($script:LegacyAutostartRunValueName))
Assert-True 'Autostart migration performed at least one canonical write' ($script:FakeSetCalls -ge 1)
Assert-Equal 'Autostart migration leaves unrelated Run values untouched' 'leave-me' $script:FakeRunValues['Unrelated App']

Set-AutostartEnabled -Enabled:$true
Assert-Equal 'Repeated autostart migration is idempotent' $script:FakeAutostartCommand $script:FakeRunValues[$script:AutostartRunValueName]
Assert-True 'Repeated autostart migration does not recreate legacy value' (-not $script:FakeRunValues.ContainsKey($script:LegacyAutostartRunValueName))

$script:FakeRunValues[$script:LegacyAutostartRunValueName] = $script:FakeAutostartCommand
Set-AutostartEnabled -Enabled:$false
Assert-True 'Disabling autostart removes canonical value' (-not $script:FakeRunValues.ContainsKey($script:AutostartRunValueName))
Assert-True 'Disabling autostart removes legacy value' (-not $script:FakeRunValues.ContainsKey($script:LegacyAutostartRunValueName))
Assert-Equal 'Disabling autostart leaves unrelated Run values untouched' 'leave-me' $script:FakeRunValues['Unrelated App']

$newTemplatePath = Join-Path $root 'src\App\LenovoBootSelector.template.ps1'
$oldTemplatePath = Join-Path $root 'src\App\LenovoBootMenuTray.template.ps1'
Assert-True 'Canonical source template exists' ([System.IO.File]::Exists($newTemplatePath))
Assert-True 'Legacy source template path is removed' (-not [System.IO.File]::Exists($oldTemplatePath))

$templateText = if ([System.IO.File]::Exists($newTemplatePath)) { [System.IO.File]::ReadAllText($newTemplatePath,[System.Text.Encoding]::UTF8) } else { '' }
$popupText = [System.IO.File]::ReadAllText((Join-Path $root 'src\UI\Popup.ps1'),[System.Text.Encoding]::UTF8)
$releaseCommonText = [System.IO.File]::ReadAllText((Join-Path $root 'tools\release_common.py'),[System.Text.Encoding]::UTF8)
$taskBrokerText = [System.IO.File]::ReadAllText((Join-Path $root 'src\Infrastructure\TaskBroker.ps1'),[System.Text.Encoding]::UTF8)

Assert-True 'Internal console helper uses canonical identifier' ($templateText.Contains('LenovoBootSelectorConsoleWindow'))
Assert-True 'Legacy internal console helper identifier is removed' (-not $templateText.Contains('LenovoBootMenuConsoleWindow'))
Assert-True 'Popup internal name uses canonical identifier' ($popupText.Contains("$form.Name = 'LenovoBootSelectorPopup'"))
Assert-True 'Legacy popup internal name is removed' (-not $popupText.Contains("$form.Name = 'LenovoBootMenuPopup'"))
Assert-True 'Legacy-compatible packaged runtime filename remains present' ([System.IO.File]::Exists((Join-Path $root 'bin\LenovoBootMenuTray.ps1')))
Assert-True 'Legacy-compatible release ZIP pattern remains retained' ($releaseCommonText.Contains("return f'LenovoBootMenuTray-v{version}.zip'"))
Assert-True 'Hardened TaskBroker fixed task identifier remains retained' ($taskBrokerText.Contains("return 'LenovoBootMenu-RefreshManager'"))
Assert-True 'Cross-version singleton mutex identifier remains retained' ($templateText.Contains("'Local\LenovoBootMenuTray'"))
Assert-True 'Persisted LocalAppData root remains retained compatibility identifier' ($templateText.Contains("Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray'"))
Assert-True 'Hardened ProgramData TaskBroker root remains retained compatibility identifier' ($templateText.Contains("Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'"))

Write-Host "IDENTIFIER TOTAL $checks/29"
if ($checks -ne 29) { throw "Unexpected identifier compatibility test count $checks" }
