function New-UpdateRuntimeState {
    [pscustomobject]@{
        Status = 'Idle'
        AvailableManifest = $null
        LastError = ''
        CheckProcess = $null
        CheckTimer = $null
        CheckResultPath = $null
        CheckMode = ''
        PrepareProcess = $null
        PrepareTimer = $null
        PrepareResultPath = $null
        ManifestPath = $null
    }
}

function Set-UpdateRuntimeChecking {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Checking'
    $State.AvailableManifest = $null
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeIdle {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Idle'
    return $State
}

function Set-UpdateRuntimeAvailable {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)]$Manifest)
    $State.Status = 'UpdateAvailable'
    $State.AvailableManifest = $Manifest
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimePreparing {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Preparing'
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeReadyToInstall {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'ReadyToInstall'
    return $State
}

function Set-UpdateRuntimeFailed {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$Message)
    $State.Status = 'Failed'
    $State.LastError = $Message
    return $State
}

function Test-UpdateRuntimeBusy {
    param([AllowNull()]$State)
    if (-not $State) { return $false }
    return @('Checking','Preparing','ReadyToInstall') -contains [string]$State.Status
}
