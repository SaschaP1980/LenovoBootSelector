#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Infrastructure\InstanceActivation.ps1')
$checks = 0
function Assert-LbsActivation([bool]$Pass, [string]$Name) {
    if (-not $Pass) { throw "Activation assertion failed: $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Assert-Fails([scriptblock]$Action,[string]$Description) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Assert-LbsActivation $failed $Description
}
$name = 'Local\LenovoBootSelector-ActivationTest-' + [Guid]::NewGuid().ToString('N')
$event = $null
$listener = $null
$script:activationCount = 0
try {
    Assert-LbsActivation ((Get-LbsActivationName) -match '^Local\\LenovoBootSelector-Activate-S-1-') 'Signal name scopes the Windows user and local session'
    $event = New-LbsActivationEvent -Name $name
    Assert-LbsActivation ($null -ne $event) 'Primary can publish activation channel'
    Assert-Fails { $duplicate = New-LbsActivationEvent -Name $name; $duplicate.Dispose() } 'Existing channel cannot be adopted by another owner'
    Assert-LbsActivation (Send-LbsActivationRequest -Name $name -RetryMs 0) 'Competing launch signals an existing channel'
    Assert-LbsActivation ($event.WaitOne(0)) 'Owner receives signaled activation'
    Assert-LbsActivation (-not $event.WaitOne(0)) 'AutoReset does not stay permanently signaled'
    [void](Send-LbsActivationRequest -Name $name -RetryMs 0)
    [void](Send-LbsActivationRequest -Name $name -RetryMs 0)
    Assert-LbsActivation ($event.WaitOne(0)) 'Rapid requests coalesce safely'
    Assert-LbsActivation (-not $event.WaitOne(0)) 'Coalesced signal is cleared'
    Assert-LbsActivation (-not (Send-LbsActivationRequest -Name ($name+'-absent') -RetryMs 0)) 'Missing owner fails without creating a new channel'
    Assert-Fails { Send-LbsActivationRequest -Name $name -RetryMs -1 } 'Negative retry is rejected'
    Assert-Fails { Send-LbsActivationRequest -Name $name -RetryMs 11000 } 'Unbounded retry is rejected'

    $scriptPath = Join-Path $root 'src\Infrastructure\InstanceActivation.ps1'
    $childScript = Join-Path ([System.IO.Path]::GetTempPath()) ('LBS-ActivationChild-' + [Guid]::NewGuid().ToString('N') + '.ps1')
    $child = $null
    try {
        $scriptText = @'
param([string]$Module,[string]$Name)
$ErrorActionPreference = 'Stop'
. $Module
if (Send-LbsActivationRequest -Name $Name -RetryMs 1000) { exit 0 }
exit 3
'@
        [System.IO.File]::WriteAllText($childScript,$scriptText,(New-Object System.Text.UTF8Encoding($true)))
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Join-Path $PSHOME 'powershell.exe'
        $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Module "{1}" -Name "{2}"' -f $childScript,$scriptPath,$name)
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $child = [System.Diagnostics.Process]::Start($psi)
        Assert-LbsActivation ($child.WaitForExit(7000) -and $child.ExitCode -eq 0) 'Separate PowerShell process sends to same-user session owner'
        Assert-LbsActivation ($event.WaitOne(300)) 'Owner receives real child-process notification'
    }
    finally {
        if ($child) { if (-not $child.HasExited) { $child.Kill() }; $child.Dispose() }
        Remove-Item -LiteralPath $childScript -Force -ErrorAction SilentlyContinue
    }

    $listener = Start-LbsActivationListener -Signal $event -OnActivate { $script:activationCount++ }
    Assert-LbsActivation ($null -ne $listener.Host -and $listener.Host.IsHandleCreated) 'Listener owns WinForms UI handle'
    [void](Send-LbsActivationRequest -Name $name -RetryMs 0)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($script:activationCount -lt 1 -and $watch.ElapsedMilliseconds -lt 3000) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 15
    }
    Assert-LbsActivation ($script:activationCount -ge 1) 'ThreadPool notification marshals onto UI-thread callback'
    [void](Send-LbsActivationRequest -Name $name -RetryMs 0)
    $watch.Restart()
    while ($script:activationCount -lt 2 -and $watch.ElapsedMilliseconds -lt 3000) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 15
    }
    Assert-LbsActivation ($script:activationCount -ge 2) 'Subsequent notifications retain listener'
    Stop-LbsActivationListener -Listener $listener; $listener=$null
    Assert-LbsActivation ($true) 'Activation listener is disposed independently from signal'

    . (Join-Path $root 'src\UI\Popup.ps1')
    $script:toggleCalls = 0
    function Show-OrTogglePopup { $script:toggleCalls++ }
    $script:Popup = [pscustomobject]@{ Visible=$true; IsDisposed=$false; ActivateCalls=0 }
    $script:Popup | Add-Member -MemberType ScriptMethod -Name Activate -Value { $this.ActivateCalls++ ; return $true }
    Show-OrActivatePopup
    Assert-LbsActivation ($script:Popup.Visible -and $script:Popup.ActivateCalls -eq 1 -and $script:toggleCalls -eq 0) 'Visible popup activated without toggle/hide'
    $script:Popup.Visible=$false
    Show-OrActivatePopup
    Assert-LbsActivation ($script:toggleCalls -eq 1) 'Hidden popup uses existing ordinary show path'

    $template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
    $duplicateCase = $template.IndexOf('if (Send-LbsActivationRequest) { exit 0 }')
    $legacyDialog = $template.IndexOf('Show-FatalMessage (Get-LocalizedStringCore -Key ''Startup.AlreadyRunningMessage''')
    Assert-LbsActivation ($duplicateCase -ge 0 -and $legacyDialog -gt $duplicateCase) 'Successful duplicate returns before genuine-failure recovery'
    Assert-LbsActivation ($template.Contains('if (-not $BackgroundRefresh -and -not $UpdateCheck -and -not $UpdatePrepare)')) 'Workers bypass single-instance control'
}
finally {
    if ($listener) { Stop-LbsActivationListener -Listener $listener }
    if ($event) { $event.Dispose() }
}
Write-Host "INSTANCE ACTIVATION TOTAL $checks/21"
if ($checks -ne 21) { throw "Unexpected instance activation test count $checks" }
