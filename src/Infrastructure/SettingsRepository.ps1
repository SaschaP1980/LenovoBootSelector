function Read-AppSettingsRepositoryResult {
    param([Parameter(Mandatory=$true)][string]$Path)

    # Distinguish an absent first-run file from a probe/read failure. No
    # user-authored contents or full local paths enter the result metadata.
    try {
        $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ Status='Unreadable'; FailureKind='ProbeFailure'; Source=$null }
    }
    if (-not $exists) {
        return [pscustomobject]@{ Status='Missing'; FailureKind='None'; Source=$null }
    }

    try {
        $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    }
    catch {
        return [pscustomobject]@{ Status='Unreadable'; FailureKind='ReadFailure'; Source=$null }
    }

    try {
        $source = ConvertFrom-Json -InputObject $text -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ Status='Invalid'; FailureKind='ParseFailure'; Source=$null }
    }
    if ($null -eq $source -or $source -isnot [pscustomobject]) {
        return [pscustomobject]@{ Status='Invalid'; FailureKind='InvalidRoot'; Source=$null }
    }
    return [pscustomobject]@{ Status='Loaded'; FailureKind='None'; Source=$source }
}

function Read-AppSettingsRepository {
    param([Parameter(Mandatory=$true)][string]$Path)

    $result = Read-AppSettingsRepositoryResult -Path $Path
    if ($result.Status -eq 'Missing') { return $null }
    if ($result.Status -eq 'Loaded') { return $result.Source }
    throw ("Unable to read settings: {0}/{1}" -f $result.Status, $result.FailureKind)
}

function Write-AppSettingsRepository {
    param(
        [Parameter(Mandatory=$true)][string]$Directory,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Payload
    )

    [void](New-Item -ItemType Directory -Path $Directory -Force)
    $json = $Payload | ConvertTo-Json -Depth 6
    $tmp = $Path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Remove-LegacySessionRestoreMarker {
    param(
        [Parameter(Mandatory=$true)][string]$RegistryPath,
        [Parameter(Mandatory=$true)][string]$ValueName
    )

    try {
        Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
    }
    catch { }
}
