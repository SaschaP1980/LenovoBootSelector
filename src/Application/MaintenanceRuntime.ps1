function New-MaintenanceRuntimeState {
    [pscustomobject]@{
        Busy = $false
        Mode = ''
        StartedUtc = $null
    }
}

function Set-MaintenanceRuntimeActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    $State.Busy = $true
    $State.Mode = $Mode
    $State.StartedUtc = $NowUtc
    return $State
}

function Clear-MaintenanceRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Busy = $false
    $State.Mode = ''
    $State.StartedUtc = $null
    return $State
}

function Test-MaintenanceRuntimeBusy {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Busy)
}

function Get-MaintenanceRuntimeMode {
    param([AllowNull()]$State)
    if (-not $State -or -not $State.Busy) { return '' }
    return [string]$State.Mode
}
