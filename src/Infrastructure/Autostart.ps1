function Get-LegacyAutostartInfo {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $root = $service.GetFolder('\')
        $task = $root.GetTask("\$($script:LegacyAutostartTaskName)")
        if (-not $task) { return [pscustomobject]@{ Enabled = $false } }
        return [pscustomobject]@{ Enabled = [bool]$task.Enabled }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false }
    }
}

function Get-AutostartLauncherPath {
    return (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
}

function Get-AutostartCommand {
    $launcher = Get-AutostartLauncherPath
    if (-not (Test-Path -LiteralPath $launcher)) { return $null }
    $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
    return ('"{0}" //B //NoLogo "{1}"' -f $wscript, $launcher)
}

function Get-AutostartInfo {
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $props = Get-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -ErrorAction SilentlyContinue
        $value = if ($props) { [string]$props.($script:AutostartRunValueName) } else { '' }
        if (-not $value) {
            return [pscustomobject]@{ Enabled = $false; CurrentPath = $false }
        }
        $launcher = Get-AutostartLauncherPath
        $currentPath = (($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) -or
            ($script:ScriptPath -and ($value.IndexOf($script:ScriptPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)))
        $usesHiddenLauncher = ($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
        return [pscustomobject]@{ Enabled = $true; CurrentPath = $currentPath; UsesHiddenLauncher = $usesHiddenLauncher }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false; CurrentPath = $false }
    }
}

function Set-AutostartEnabled([bool]$Enabled) {
    if (-not $script:ScriptPath) {
        throw 'Der Pfad der Anwendung konnte nicht ermittelt werden.'
    }

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if ($Enabled) {
        if (-not (Test-Path $runKey)) { [void](New-Item -Path $runKey -Force) }
        $command = Get-AutostartCommand
        if (-not $command) { throw 'Der versteckte Autostart-Launcher wurde nicht gefunden.' }
        Set-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -Type String -Value $command
    }
    else {
        Remove-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -ErrorAction SilentlyContinue
    }
}

function Repair-AutostartLauncherIfNeeded {
    try {
        $info = Get-AutostartInfo
        if ($info.Enabled) {
            # The Run value belongs exclusively to this app. Always migrate it to
            # the currently launched package and the hidden WScript/VBS launcher.
            # This also fixes upgrades from older versions that started PowerShell
            # directly and could leave a visible console window at logon.
            Set-AutostartEnabled -Enabled:$true
        }
    }
    catch { }
}
