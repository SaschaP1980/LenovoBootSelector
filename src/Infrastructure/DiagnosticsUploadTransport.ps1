# LBS-103: explicit manual upload only. This module never runs on startup.
# Never add GitHub write credentials or privileged TaskBroker operations here.
function Get-DiagnosticsUploadUri {
    return [uri]'https://lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev/v1/diagnostics'
}

function New-DiagnosticsUploadHttpHandler {
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    # Automatic 30x redirects could forward private ZIPs to a third-party host.
    # Pinning only the initial URI is not enough.
    $handler.AllowAutoRedirect = $false
    return $handler
}

function New-DiagnosticsUploadRequest {
    param(
        [Parameter(Mandatory=$true)][byte[]]$Bytes,
        [Parameter(Mandatory=$true)][string]$InstallationUuid,
        [Parameter(Mandatory=$true)][uri]$Uri
    )
    Add-Type -AssemblyName System.Net.Http
    $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Uri)
    try {
        $payload = New-Object System.Net.Http.ByteArrayContent(,$Bytes)
        $payload.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('application/zip')
        $request.Headers.Add('x-installation-uuid', $InstallationUuid)
        $request.Content = $payload
        return $request
    }
    catch {
        $request.Dispose()
        throw
    }
}

function Start-DiagnosticsUploadTransport {
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$InstallationUuid
    )

    if (-not (Test-DiagnosticsInstallationIdFormat -Value $InstallationUuid)) {
        throw 'The installation UUID is not valid.'
    }
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw 'The diagnostics ZIP does not exist.'
    }
    $maxBytes = 2 * 1024 * 1024
    $size = (Get-Item -LiteralPath $ZipPath).Length
    if ($size -le 0 -or $size -gt $maxBytes) {
        throw 'The diagnostics ZIP exceeds the 2 MB upload limit or is empty.'
    }

    $uri = Get-DiagnosticsUploadUri
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev' -or $uri.AbsolutePath -ne '/v1/diagnostics') {
        throw 'The diagnostics upload destination is not approved.'
    }
    try {
        $existing = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $existing -bor [System.Net.SecurityProtocolType]::Tls12
    } catch { }

    $httpHandler = New-DiagnosticsUploadHttpHandler
    try {
        $client = New-Object System.Net.Http.HttpClient -ArgumentList (,$httpHandler)
    } catch {
        $httpHandler.Dispose()
        throw
    }
    $client.Timeout = [TimeSpan]::FromSeconds(25)
    $content = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($ZipPath)
        if ($bytes.Length -ne $size) { throw 'The diagnostics ZIP changed during preparation.' }
        $request = New-DiagnosticsUploadRequest -Bytes $bytes -InstallationUuid $InstallationUuid -Uri $uri
        $content = $request.Content
        try {
            $task = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseContentRead)
            return [pscustomobject]@{ Client = $client; Task = $task; Content = $content; Request = $request; ZipPath = $ZipPath }
        }
        catch {
            $request.Dispose()
            throw
        }
    }
    catch {
        if ($content) { $content.Dispose() }
        $client.Dispose()
        throw
    }
}

function Dispose-DiagnosticsUploadTransport {
    param([AllowNull()]$Context)
    if (-not $Context) { return }
    try { if ($Context.Task -and $Context.Task.IsCompleted -and -not $Context.Task.IsFaulted) { $Context.Task.Result.Dispose() } } catch { }
    try { if ($Context.Request) { $Context.Request.Dispose() } } catch { }
    try { if ($Context.Content) { $Context.Content.Dispose() } } catch { }
    try { if ($Context.Client) { $Context.Client.Dispose() } } catch { }
}
