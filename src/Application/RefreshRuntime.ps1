function New-BackgroundRefreshRequest {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware
    )

    [pscustomobject]@{
        RefreshStorage  = [bool]$RefreshStorage
        RefreshFirmware = [bool]$RefreshFirmware
    }
}

function New-BackgroundRefreshRuntimeState {
    [pscustomobject]@{
        Process        = $null
        Timer          = $null
        ResultPath     = $null
        ActiveRequest  = $null
        PendingRequest = $null
        LastTiming     = $null
    }
}

function Test-BackgroundRefreshActive {
    param([Parameter(Mandatory=$true)]$State)
    return ($null -ne $State.Process)
}

function Test-BackgroundRefreshNeedsFirmware {
    param(
        [bool]$RefreshStorage,
        [AllowNull()][string]$FirmwareCacheText,
        [datetime]$FirmwareCacheUtc,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if ($RefreshStorage) { return $true }
    if (-not $FirmwareCacheText) { return $true }
    return (($NowUtc - $FirmwareCacheUtc).TotalSeconds -ge 30)
}

function Test-BackgroundRefreshRequestEscalation {
    param(
        [AllowNull()]$ActiveRequest,
        [Parameter(Mandatory=$true)]$Requested
    )

    if (-not $ActiveRequest) { return $true }
    if ($Requested.RefreshStorage -and -not $ActiveRequest.RefreshStorage) { return $true }
    if ($Requested.RefreshFirmware -and -not $ActiveRequest.RefreshFirmware) { return $true }
    return $false
}

function Add-BackgroundRefreshPendingRequest {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Request
    )

    if (-not $State.PendingRequest) {
        $State.PendingRequest = New-BackgroundRefreshRequest -RefreshStorage:$Request.RefreshStorage -RefreshFirmware:$Request.RefreshFirmware
        return $State.PendingRequest
    }

    if ($Request.RefreshStorage) { $State.PendingRequest.RefreshStorage = $true }
    if ($Request.RefreshFirmware) { $State.PendingRequest.RefreshFirmware = $true }
    return $State.PendingRequest
}

function Set-BackgroundRefreshActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Process,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)]$Request
    )

    $State.Process = $Process
    $State.ResultPath = $ResultPath
    $State.ActiveRequest = $Request
}

function Set-BackgroundRefreshTimer {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timer
    )
    $State.Timer = $Timer
}

function Take-BackgroundRefreshCompletionContext {
    param([Parameter(Mandatory=$true)]$State)

    if (-not $State.Process) { return $null }

    $context = [pscustomobject]@{
        Process    = $State.Process
        Timer      = $State.Timer
        ResultPath = $State.ResultPath
        Request    = $State.ActiveRequest
    }

    $State.Process = $null
    $State.Timer = $null
    $State.ResultPath = $null
    $State.ActiveRequest = $null
    return $context
}

function Take-BackgroundRefreshPendingRequest {
    param([Parameter(Mandatory=$true)]$State)
    $pending = $State.PendingRequest
    $State.PendingRequest = $null
    return $pending
}

function Set-BackgroundRefreshLastTiming {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timing
    )
    $State.LastTiming = $Timing
}

function ConvertFrom-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Der Hintergrund-Refresh hat ein leeres Ergebnis geliefert.'
    }
    return ($Text | ConvertFrom-Json)
}
