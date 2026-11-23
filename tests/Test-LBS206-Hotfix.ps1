#requires -version 5.1
# LBS-206 Hotfix: shared asynchronous reset; never write firmware in this test.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\BootNextSelectionState.ps1')
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$rowSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
function Import-Lbs206Function([string]$Content,[string]$Name) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Content,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -gt 0) { throw 'Source parse failed' }
    $fn = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name},$true)
    if (-not $fn) { throw "Missing canonical function $Name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
# Dot-scope extraction so actual implementation is invoked, not copied.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
$reset=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Use-DefaultForNextRestart'},$true)
if (-not $reset -or @($errors).Count -gt 0) { throw 'Missing canonical reset function' }
. ([scriptblock]::Create($reset.Extent.Text))
$ast=[Management.Automation.Language.Parser]::ParseInput($rowSource,[ref]$tokens,[ref]$errors)
$select=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-NormalBootTargetSelection'},$true)
if (-not $select -or @($errors).Count -gt 0) { throw 'Missing canonical normal selection helper' }
. ([scriptblock]::Create($select.Extent.Text))
$script:checks=0
function Assert-Lbs206Hotfix([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "LBS206_HOTFIX_RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS206_HOTFIX $Name"
}
$script:DefaultGuid='{11111111-2222-3333-4444-555555555555}'
$script:GamingGuid='{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}'
$script:SelectedGuid=$script:GamingGuid
$script:BootNextPendingGuid=$null
$script:NextBootFirmwareReadVerified=$true
$script:IsManageEntriesMode=$false
$script:CanSetBootNext=$true
$script:SelectionCalls=0
$script:ResetCalls=0
$script:SyncWrites=0
$script:RefreshCalls=0
$script:ErrorNotices=0
function Get-CurrentSystemFunctionsCapabilities { param([switch]$ProbeReadiness)
    return [pscustomobject]@{ CanSetBootNext=$script:CanSetBootNext; CanRestart=$true; State='Ready' }
}
function Get-EntryByGuid { param([string]$Guid)
    if ($Guid -eq $script:DefaultGuid -or $Guid -eq $script:GamingGuid) { return [pscustomobject]@{Guid=$Guid;Title=$Guid} }
    return $null
}
function Start-BootNextSelection { param([string]$Guid)
    $script:SelectionCalls++
    $script:LastRequestedGuid=$Guid
    $script:BootNextPendingGuid=$Guid
}
function Set-BootNextTarget { param([string]$Guid) $script:SyncWrites++ }
function Refresh-EffectiveNextBootState { $script:RefreshCalls++; return $true }
function Update-PopupRows { $script:ResetCalls++ }
function Get-LocalizedString { param($Key,$Values) $Key }
function Show-LenovoNoticeDialog { $script:ErrorNotices++ }

Use-DefaultForNextRestart
Assert-Lbs206Hotfix 'reset delegates to the actual normal async selection helper rather than synchronous firmware write' (
    $script:SelectionCalls -eq 1 -and $script:SyncWrites -eq 0 -and
    $script:LastRequestedGuid -eq $script:DefaultGuid -and
    $script:BootNextPendingGuid -eq $script:DefaultGuid)
Assert-Lbs206Hotfix 'stored default is visibly pending while previously confirmed Gaming is not falsely promoted' (
    (Resolve-BootNextRowDisplayCore -EntryGuid $script:DefaultGuid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid) -eq 'pending' -and
    (Resolve-BootNextRowDisplayCore -EntryGuid $script:GamingGuid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid) -eq 'selected')
Use-DefaultForNextRestart
Assert-Lbs206Hotfix 'repeated click during pending does not queue a second writer' (
    $script:SelectionCalls -eq 1 -and $script:SyncWrites -eq 0)
$script:BootNextPendingGuid=$null
$script:SelectedGuid=$script:DefaultGuid
Use-DefaultForNextRestart
Assert-Lbs206Hotfix 'already aligned effective target does not enqueue another selection' ($script:SelectionCalls -eq 1)
$script:SelectedGuid=$script:GamingGuid
$script:NextBootFirmwareReadVerified=$false
Use-DefaultForNextRestart
Assert-Lbs206Hotfix 'unverified firmware state fails closed' ($script:SelectionCalls -eq 1)
$script:NextBootFirmwareReadVerified=$true
$script:CanSetBootNext=$false
Use-DefaultForNextRestart
Assert-Lbs206Hotfix 'unavailable BootNext capability fails closed' ($script:SelectionCalls -eq 1)
Assert-Lbs206Hotfix 'no synchronous write, synthetic restart or error notice' (
    $script:SyncWrites -eq 0 -and $script:ErrorNotices -eq 0)
Write-Host "LBS206 HOTFIX TOTAL $script:checks"
