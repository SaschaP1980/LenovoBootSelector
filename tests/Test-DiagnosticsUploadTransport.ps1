# Read-only contract tests. Never create a real upload or network request.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Infrastructure\DiagnosticsIdentity.ps1')
. (Join-Path $root 'src\Infrastructure\DiagnosticsUploadTransport.ps1')
$script:passed = 0
function Assert-DiagnosticUpload {
    param([bool]$Check,[string]$Reason)
    if (-not $Check) { throw $Reason }
    $script:passed++
}
function Test-ExpectedUploadRejection {
    param([scriptblock]$Action)
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    return $rejected
}
$folder = Join-Path ([IO.Path]::GetTempPath()) ('LBS-103-UploadTest-' + [guid]::NewGuid().ToString('N'))
$valid = '123e4567-e89b-42d3-a456-426614174000'
try {
    [void](New-Item -ItemType Directory -Path $folder -Force)
    $zero = Join-Path $folder 'empty.zip'
    [IO.File]::WriteAllBytes($zero, [byte[]]@())
    $huge = Join-Path $folder 'oversize.zip'
    [IO.File]::WriteAllBytes($huge, (New-Object byte[] (2 * 1024 * 1024 + 1)))
    $uri = Get-DiagnosticsUploadUri
    Assert-DiagnosticUpload ($uri.Scheme -eq 'https') 'Only HTTPS is approved.'
    Assert-DiagnosticUpload ($uri.Host -eq 'lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev') 'Upload host must be pinned.'
    Assert-DiagnosticUpload ($uri.AbsolutePath -eq '/v1/diagnostics') 'Upload route must be pinned.'
    $handler = New-DiagnosticsUploadHttpHandler
    try {
        Assert-DiagnosticUpload (-not $handler.AllowAutoRedirect) 'Redirects must be refused to prevent ZIP exfiltration.'
    } finally {
        $handler.Dispose()
    }
    # Construct an in-memory POST request, never call SendAsync or perform I/O.
    $sampleBytes = [byte[]]@(0x50, 0x4b, 0x03, 0x04, 0xff)
    $sampleRequest = New-DiagnosticsUploadRequest -Bytes $sampleBytes -InstallationUuid $valid -Uri $uri
    try {
        Assert-DiagnosticUpload ($sampleRequest.Method.Method -eq 'POST') 'HTTP request must use POST.'
        Assert-DiagnosticUpload ($sampleRequest.RequestUri.AbsoluteUri -eq $uri.AbsoluteUri) 'Request URI must match the approved destination.'
        Assert-DiagnosticUpload ($sampleRequest.Content.Headers.ContentType.MediaType -eq 'application/zip') 'HTTP request must specify application/zip.'
        Assert-DiagnosticUpload ($sampleRequest.Headers.GetValues('x-installation-uuid').GetEnumerator().MoveNext()) 'Installation UUID header must exist.'
        $headerValue = [string]@($sampleRequest.Headers.GetValues('x-installation-uuid'))[0]
        Assert-DiagnosticUpload ($headerValue -eq $valid) 'Installation UUID header must match.'
        $encoded = $sampleRequest.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        Assert-DiagnosticUpload ([BitConverter]::ToString($encoded) -eq [BitConverter]::ToString($sampleBytes)) 'ZIP bytes must not change in transit preparation.'
    } finally {
        $sampleRequest.Dispose()
    }
    Assert-DiagnosticUpload (Test-ExpectedUploadRejection { Start-DiagnosticsUploadTransport -ZipPath $zero -InstallationUuid 'abc' }) 'Invalid UUID must reject.'
    Assert-DiagnosticUpload (Test-ExpectedUploadRejection { Start-DiagnosticsUploadTransport -ZipPath (Join-Path $folder 'missing.zip') -InstallationUuid $valid }) 'Missing local ZIP must reject.'
    Assert-DiagnosticUpload (Test-ExpectedUploadRejection { Start-DiagnosticsUploadTransport -ZipPath $zero -InstallationUuid $valid }) 'Empty ZIP must reject.'
    Assert-DiagnosticUpload (Test-ExpectedUploadRejection { Start-DiagnosticsUploadTransport -ZipPath $huge -InstallationUuid $valid }) 'Oversize ZIP must reject.'
    # LBS-103: read a synthetic HTTP 201 response without network access.
    Add-Type -AssemblyName System.Net.Http
    $validDiagnosisId = 'LBS-7K2MP-9Q4V6-TR3X8-AB123'
    $validKey = 'Diagnose/LBS/' + $valid + '/20261014T110851797Z.zip'
    $json = '{"status":"stored","diagnosisId":"' + $validDiagnosisId +
        '","key":"' + $validKey + '","sha256":"' + ('a' * 64) +
        '","sizeBytes":547}'
    $created = New-Object System.Net.Http.HttpResponseMessage ([System.Net.HttpStatusCode]::Created)
    try {
        $created.Content = New-Object System.Net.Http.StringContent ($json)
        $receipt = Read-DiagnosticsUploadReceipt -Response $created
        Assert-DiagnosticUpload ($receipt.DiagnosisId -ceq $validDiagnosisId) 'Receipt must preserve the server-issued Diagnosis ID.'
        Assert-DiagnosticUpload ($receipt.Key -ceq $validKey) 'Receipt must preserve the project-scoped archive key.'
    } finally { $created.Dispose() }

    foreach ($badJson in @(
        '{"status":"stored","diagnosisId":"","key":"' + $validKey + '"}',
        '{"status":"stored","diagnosisId":"LBS-INVALID","key":"' + $validKey + '"}',
        '{"status":"stored","diagnosisId":"' + $validDiagnosisId + '","key":"Diagnose/FAE/not-lfs.zip"}',
        'not-json'
    )) {
        $created = New-Object System.Net.Http.HttpResponseMessage ([System.Net.HttpStatusCode]::Created)
        try {
            $created.Content = New-Object System.Net.Http.StringContent ($badJson)
            Assert-DiagnosticUpload (Test-ExpectedUploadRejection { Read-DiagnosticsUploadReceipt -Response $created }) 'Malformed or untrusted HTTP 201 receipt must be rejected.'
        } finally { $created.Dispose() }
    }
} finally {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ('DIAGNOSTIC_UPLOAD_TRANSPORT_CHECKS=' + $script:passed)
