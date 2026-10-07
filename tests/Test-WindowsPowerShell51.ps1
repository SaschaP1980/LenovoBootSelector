#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1' | Sort-Object FullName)
$pass = 0
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $payloadBytes = if ($hasUtf8Bom -and $bytes.Length -gt 3) { @($bytes[3..($bytes.Length - 1)]) } elseif ($hasUtf8Bom) { @() } else { @($bytes) }
    $hasNonAscii = @($payloadBytes | Where-Object { $_ -ge 128 }).Count -gt 0
    if ($hasNonAscii -and -not $hasUtf8Bom) {
        throw "Encoding failure in $($file.FullName): non-ASCII PowerShell source requires UTF-8 BOM for Windows PowerShell 5.1"
    }
    if ($hasNonAscii) { Write-Host "PASS  Encoding $($file.FullName.Substring($root.Length + 1))" }

    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) {
        $detail = (@($errors) | ForEach-Object { $_.Message }) -join '; '
        throw "Parse failure in $($file.FullName): $detail"
    }
    $pass++
    Write-Host "PASS  Parse $($file.FullName.Substring($root.Length + 1))"
}
Write-Host "PARSER TOTAL $pass/$($files.Count)"
& (Join-Path $root 'tests\Test-FunctionalCore.ps1')
& (Join-Path $root 'tests\Test-LocalizationRuntime.ps1')
& (Join-Path $root 'tests\Test-RefreshRuntime.ps1')
& (Join-Path $root 'tests\Test-SingleInstanceMutex.ps1')
& (Join-Path $root 'tests\Test-ArchitectureSoak.ps1')
& (Join-Path $root 'tests\Test-MaintenanceRuntime.ps1')
& (Join-Path $root 'tests\Test-BootTargetDrift.ps1')
& (Join-Path $root 'tests\Test-TaskBrokerBoundary.ps1')
& (Join-Path $root 'tests\Test-TaskBrokerMigration.ps1')
& (Join-Path $root 'tests\Test-IdentifierCompatibility.ps1')
& (Join-Path $root 'tests\Test-UpdateCore.ps1')
