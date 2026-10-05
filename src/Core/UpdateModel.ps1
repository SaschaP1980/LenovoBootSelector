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
