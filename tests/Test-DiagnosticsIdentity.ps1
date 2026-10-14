# This suite uses only temporary local paths; it never invokes Cloudflare.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Infrastructure\DiagnosticsIdentity.ps1')
$count = 0
function Assert-DiagnosticsIdentity {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
    $script:count++
}
$firstDir = Join-Path ([IO.Path]::GetTempPath()) ('LBS-103-Identity-' + [guid]::NewGuid().ToString('N'))
$secondDir = Join-Path ([IO.Path]::GetTempPath()) ('LBS-103-Identity-' + [guid]::NewGuid().ToString('N'))
try {
    $id = Get-DiagnosticsInstallationId -SettingsDirectory $firstDir
    Assert-DiagnosticsIdentity (Test-DiagnosticsInstallationIdFormat $id) 'Generated UUID must be v4.'
    Assert-DiagnosticsIdentity ($id -eq (Get-DiagnosticsInstallationId -SettingsDirectory $firstDir)) 'UUID must persist across launches.'
    $other = Get-DiagnosticsInstallationId -SettingsDirectory $secondDir
    Assert-DiagnosticsIdentity ($other -ne $id) 'Distinct installations must get distinct UUIDs.'
    Assert-DiagnosticsIdentity ((Get-Content (Join-Path $firstDir 'installation-id.txt') -Raw).Trim() -eq $id) 'Persisted UUID must match.'
    [IO.File]::WriteAllText((Join-Path $firstDir 'installation-id.txt'),'broken')
    $failed = $false
    try { [void](Get-DiagnosticsInstallationId -SettingsDirectory $firstDir) } catch { $failed = $true }
    Assert-DiagnosticsIdentity $failed 'Corrupt persisted identity must fail closed.'
    Assert-DiagnosticsIdentity ((Get-Content (Join-Path $firstDir 'installation-id.txt') -Raw) -eq 'broken') 'Identity must not rotate on corruption.'
}
finally {
    Remove-Item -LiteralPath $firstDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $secondDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('DIAGNOSTICS_IDENTITY_CHECKS=' + $script:count)
