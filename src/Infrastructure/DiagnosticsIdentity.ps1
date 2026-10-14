# Persistent pseudonymous UUID for this Windows user's Lenovo Boot Selector
# installation. It is not a physical-device fingerprint or a runtime session ID.
function Test-DiagnosticsInstallationIdFormat {
    param([AllowNull()][string]$Value)
    return [bool]($Value -match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
}

function Get-DiagnosticsInstallationId {
    param([Parameter(Mandatory=$true)][string]$SettingsDirectory)

    $path = Join-Path $SettingsDirectory 'installation-id.txt'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $current = ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Trim().ToLowerInvariant()
        if (-not (Test-DiagnosticsInstallationIdFormat -Value $current)) {
            throw 'The persisted diagnostics installation UUID is invalid; it will not be silently replaced.'
        }
        return $current
    }

    if (-not (Test-Path -LiteralPath $SettingsDirectory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $SettingsDirectory -Force)
    }
    $newId = [guid]::NewGuid().ToString('D').ToLowerInvariant()
    $handle = $null
    try {
        # Atomic CreateNew prevents two competing initial launches overwriting
        # each other's IDs. An existing file is never overwritten by a reset.
        $handle = New-Object System.IO.FileStream($path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $content = [System.Text.Encoding]::UTF8.GetBytes($newId + "`r`n")
        $handle.Write($content, 0, $content.Length)
        $handle.Flush($true)
        return $newId
    }
    catch [System.IO.IOException] {
        # Another process may have created the file; await its final flush.
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw }
    }
    finally {
        if ($handle) { $handle.Dispose() }
    }
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        Start-Sleep -Milliseconds 25
        try {
            $read = ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Trim().ToLowerInvariant()
            if (Test-DiagnosticsInstallationIdFormat -Value $read) { return $read }
        } catch [System.IO.IOException] { }
    }
    throw 'The diagnostics installation UUID could not be persisted safely.'
}
