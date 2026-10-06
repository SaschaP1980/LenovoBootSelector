function ConvertTo-LenovoVersionCore {
    param([Parameter(Mandatory=$true)][string]$Version)
    $value = ([string]$Version).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') { return $null }
    if ($value -match '^\d+\.\d+\.\d+$') { $value += '.0' }
    try { return [version]$value } catch { return $null }
}

function Compare-LenovoAppVersionCore {
    param(
        [Parameter(Mandatory=$true)][string]$Current,
        [Parameter(Mandatory=$true)][string]$Candidate
    )
    $currentVersion = ConvertTo-LenovoVersionCore -Version $Current
    $candidateVersion = ConvertTo-LenovoVersionCore -Version $Candidate
    if (-not $currentVersion -or -not $candidateVersion) { throw 'Ungültiges Versionsformat.' }
    return $candidateVersion.CompareTo($currentVersion)
}

function Resolve-LenovoUpdateRestartResultCore {
    param(
        [AllowNull()]$Result,
        [Parameter(Mandatory=$true)][string]$RunningVersion
    )

    $running = ([string]$RunningVersion).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $running)) { throw 'Ungültige laufende App-Version.' }

    $status = ''
    $sourceVersion = ''
    $targetVersion = ''
    $storedMessage = ''
    $resultUtc = ''
    $rollbackAttempted = $false
    $rollbackSucceeded = $false
    $failureCategory = ''
    $failureStage = ''
    $errorClass = ''
    $legacySuccessProperty = $null
    if ($Result) {
        $status = ([string]$Result.status).Trim().ToLowerInvariant()
        $sourceVersion = ([string]$Result.sourceVersion).Trim()
        $targetVersion = ([string]$Result.targetVersion).Trim()
        $storedMessage = ([string]$Result.message).Trim()
        $resultUtc = [string]$Result.utc
        $rollbackAttempted = [bool]$Result.rollbackAttempted
        $rollbackSucceeded = [bool]$Result.rollbackSucceeded
        $failureCategory = ([string]$Result.failureCategory).Trim().ToLowerInvariant()
        $failureStage = ([string]$Result.failureStage).Trim()
        $errorClass = ([string]$Result.errorClass).Trim()
        $legacySuccessProperty = $Result.PSObject.Properties['success']
    }

    # v0.5.7.2 and older updater helpers persisted { utc, success, message }.
    # Treat that shape as legacy only when status is absent and success is a real Boolean.
    # If a status exists, the v0.5.8.x status contract always wins.
    $isLegacyResult = (-not $status -and $null -ne $legacySuccessProperty -and ($legacySuccessProperty.Value -is [bool]))
    $resultFormat = $(if ($status) { 'status' } elseif ($isLegacyResult) { 'legacy-success' } else { 'unknown' })
    $legacySuccess = $null
    $success = $false
    $message = $storedMessage
    $displayVersion = $targetVersion

    if ($status -eq 'pending-verification') {
        try {
            if (-not $targetVersion) { throw 'Die erwartete Zielversion fehlt im Update-Ergebnis.' }
            $comparison = Compare-LenovoAppVersionCore -Current $running -Candidate $targetVersion
            $success = ($comparison -eq 0)
            if ($success) {
                $message = ('Lenovo Boot Selector wurde erfolgreich auf v{0} aktualisiert.' -f $targetVersion)
            }
            else {
                $message = ('Die erwartete Zielversion v{0} wurde nach dem Neustart nicht erkannt. Aktuell läuft v{1}.' -f $targetVersion,$running)
            }
        }
        catch {
            $success = $false
            $message = $_.Exception.Message
        }
    }
    elseif ($status -eq 'failed') {
        $success = $false
        if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.' }
        if ($rollbackAttempted -and $rollbackSucceeded) {
            $message = "Die Aktualisierung konnte nicht abgeschlossen werden. Die vorherige Version wurde wiederhergestellt.`r`n`r`nUrsache: $message"
        }
    }
    elseif ($isLegacyResult) {
        $legacySuccess = [bool]$legacySuccessProperty.Value
        $success = $legacySuccess
        if ($success) {
            # Legacy records carry no trustworthy targetVersion. Report only the version
            # that is demonstrably running and leave TargetVersion empty in diagnostics.
            $displayVersion = $running
            $message = ('Lenovo Boot Selector wurde erfolgreich aktualisiert. Aktuell läuft v{0}.' -f $running)
        }
        elseif ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.'
        }
    }
    else {
        $success = $false
        $message = ('Unbekannter Update-Ergebnisstatus: {0}' -f $(if ($status) { $status } else { '<leer>' }))
    }

    return [pscustomobject][ordered]@{
        Success = $success
        Message = $message
        DisplayVersion = $displayVersion
        ResultFormat = $resultFormat
        LegacySuccess = $legacySuccess
        ResultUtc = $resultUtc
        ResultStatus = $status
        SourceVersion = $sourceVersion
        TargetVersion = $targetVersion
        RunningVersion = $running
        RollbackAttempted = $rollbackAttempted
        RollbackSucceeded = $rollbackSucceeded
        FailureCategory = $failureCategory
        FailureStage = $failureStage
        ErrorClass = $errorClass
        StoredMessage = $storedMessage
    }
}

function Test-LenovoUpdateManifestCore {
    param([AllowNull()]$Manifest)

    $result = [ordered]@{
        IsValid = $false
        Error = ''
        SchemaVersion = 1
        Version = ''
        File = ''
        Sha256 = ''
        Size = 0
        Tag = ''
        PackageFiles = @()
    }

    if (-not $Manifest) { $result.Error = 'Update-Manifest fehlt.'; return [pscustomobject]$result }
    if ([int]$Manifest.schemaVersion -ne 1) { $result.Error = 'Update-Manifest-Schema wird nicht unterstützt.'; return [pscustomobject]$result }

    $version = ([string]$Manifest.version).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $version)) { $result.Error = 'Update-Version ist ungültig.'; return [pscustomobject]$result }

    $expectedFile = ('LenovoBootMenuTray-v{0}.zip' -f $version)
    $file = ([string]$Manifest.file).Trim()
    if ($file -ne $expectedFile) { $result.Error = 'Update-Dateiname passt nicht zur Version.'; return [pscustomobject]$result }

    $sha = ([string]$Manifest.sha256).Trim().ToLowerInvariant()
    if ($sha -notmatch '^[0-9a-fA-F]{64}$') { $result.Error = 'Update-SHA-256 ist ungültig.'; return [pscustomobject]$result }

    $size = 0L
    try { $size = [int64]$Manifest.size } catch { $size = 0L }
    if ($size -le 0) { $result.Error = 'Update-Dateigröße ist ungültig.'; return [pscustomobject]$result }

    $tag = ([string]$Manifest.tag).Trim()
    if ($tag -ne ('v{0}' -f $version)) { $result.Error = 'Update-Tag passt nicht zur Version.'; return [pscustomobject]$result }

    $packageFiles = @($Manifest.packageFiles)
    if ($packageFiles.Count -lt 1) { $result.Error = 'Update-Paketdateien fehlen.'; return [pscustomobject]$result }
    $seen = @{}
    $normalizedFiles = @()
    foreach ($item in $packageFiles) {
        $name = ([string]$item).Trim()
        if (-not $name -or $name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            $result.Error = 'Update-Paket enthält einen ungültigen Dateinamen.'; return [pscustomobject]$result
        }
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { $result.Error = 'Update-Paket enthält doppelte Dateinamen.'; return [pscustomobject]$result }
        $seen[$key] = $true
        $normalizedFiles += $name
    }
    foreach ($required in @('LenovoBootMenuTray.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1')) {
        if (-not $seen.ContainsKey($required.ToLowerInvariant())) {
            $result.Error = 'Update-Paket ist unvollständig.'; return [pscustomobject]$result
        }
    }

    $result.IsValid = $true
    $result.Version = $version
    $result.File = $file
    $result.Sha256 = $sha
    $result.Size = $size
    $result.Tag = $tag
    $result.PackageFiles = @($normalizedFiles)
    return [pscustomobject]$result
}
