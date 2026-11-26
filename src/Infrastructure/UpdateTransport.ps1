function Get-LenovoUpdateManifestBaseUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json'
}

function Get-LenovoUpdateManifestUri {
    $cacheBuster = [guid]::NewGuid().ToString('N')
    return ('{0}?cb={1}' -f (Get-LenovoUpdateManifestBaseUri),$cacheBuster)
}

function Get-LenovoUpdateDownloadBaseUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/'
}

function Enable-LenovoUpdateTls12 {
    try {
        $current = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $current -bor [System.Net.SecurityProtocolType]::Tls12
    } catch { }
}

function New-LenovoWebClient {
    Enable-LenovoUpdateTls12
    $client = New-Object System.Net.WebClient
    $client.Headers['User-Agent'] = 'LenovoBootSelector/' + $script:AppVersion
    $client.Headers['Cache-Control'] = 'no-cache'
    return $client
}

function New-LenovoUpdateFailureException {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('network','manifest','package','hash','install','restart','runtime')][string]$Category,
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter(Mandatory=$true)][string]$Message,
        [AllowNull()][System.Exception]$InnerException = $null
    )
    $exception = if ($InnerException) { [System.InvalidOperationException]::new($Message,$InnerException) } else { [System.InvalidOperationException]::new($Message) }
    $exception.Data['LenovoUpdateCategory'] = $Category
    $exception.Data['LenovoUpdateStage'] = $Stage
    return $exception
}

function Get-LenovoUpdateFailureInfo {
    param(
        [AllowNull()]$ErrorRecord,
        [ValidateSet('network','manifest','package','hash','install','restart','runtime')][string]$DefaultCategory = 'runtime',
        [string]$DefaultStage = 'update'
    )
    $exception = $null
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $exception = $ErrorRecord.Exception }
    elseif ($ErrorRecord -is [System.Exception]) { $exception = $ErrorRecord }
    elseif ($ErrorRecord -and $ErrorRecord.Exception) { $exception = $ErrorRecord.Exception }
    $category = $DefaultCategory
    $stage = $DefaultStage
    $errorClass = ''
    $networkStatus = ''
    $message = [string]$ErrorRecord
    if ($exception) {
        $message = [string]$exception.Message
        $errorClass = $exception.GetType().FullName
        $hasStructuredCategory = $exception.Data.Contains('LenovoUpdateCategory')
        if ($hasStructuredCategory) { $category = [string]$exception.Data['LenovoUpdateCategory'] }
        if ($exception.Data.Contains('LenovoUpdateStage')) { $stage = [string]$exception.Data['LenovoUpdateStage'] }
        $probe = $exception
        while ($probe) {
            if ($probe -is [System.Net.WebException]) {
                if (-not $hasStructuredCategory) { $category = 'network' }
                $networkStatus = [string]$probe.Status
                $errorClass = $probe.GetType().FullName
                break
            }
            $probe = $probe.InnerException
        }
    }
    return [pscustomobject][ordered]@{ Category=$category; Stage=$stage; ErrorClass=$errorClass; NetworkStatus=$networkStatus; Message=$message }
}

function New-LenovoUpdateManifestRequest {
    param([Parameter(Mandatory=$true)][uri]$Uri)
    Enable-LenovoUpdateTls12
    $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($Uri)
    $request.Method = 'GET'
    $request.AllowAutoRedirect = $false
    $request.UserAgent = 'LenovoBootSelector/' + $script:AppVersion
    $request.Headers['Cache-Control'] = 'no-cache'
    # Keep configured system proxy and certificate validation. The initial
    # response budget deliberately preserves the observed slow successful path
    # until native phase evidence supports a tighter limit.
    $request.Timeout = 100000
    $request.ReadWriteTimeout = 15000
    return $request
}

function Invoke-LenovoUpdateDotNetManifestDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri,[hashtable]$Timings=@{})
    $phase = 'request-setup'
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $response = $null
    $reader = $null
    try {
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_TRANSPORT_PHASE' -Stage $phase
        $clock.Restart()
        $request = New-LenovoUpdateManifestRequest -Uri $Uri
        $Timings.transportSetupMs = $clock.ElapsedMilliseconds
        $phase = 'response-wait'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_TRANSPORT_PHASE' -Stage $phase -Data (New-RuntimeDiagnosticData @{ requestTimeoutMs=$request.Timeout; readTimeoutMs=$request.ReadWriteTimeout; setupMs=$Timings.transportSetupMs })
        $clock.Restart()
        $response = $request.GetResponse()
        if ([int]$response.StatusCode -ne 200) { throw [System.Net.WebException]::new('Unexpected manifest HTTP status.',[System.Net.WebExceptionStatus]::ProtocolError) }
        $Timings.responseWaitMs = $clock.ElapsedMilliseconds
        $phase = 'response-read'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_TRANSPORT_PHASE' -Stage $phase -Data (New-RuntimeDiagnosticData @{ responseWaitMs=$Timings.responseWaitMs })
        $clock.Restart()
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream(),[System.Text.Encoding]::UTF8,$true)
        $text = $reader.ReadToEnd()
        $Timings.responseReadMs = $clock.ElapsedMilliseconds
        return $text
    }
    catch {
        $Timings.transportFailurePhase = $phase
        $Timings.transportFailurePhaseMs = $clock.ElapsedMilliseconds
        throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'manifest-download' -Message ('Update-Manifest konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception)
    }
    finally {
        if ($reader) { try { $reader.Dispose() } catch { } }
        if ($response) { try { $response.Dispose() } catch { } }
    }
}

function Get-LenovoManifestCurlPath {
    # Never resolve an executable from PATH or the application directory.
    $directory = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
    if (-not $directory) { return $null }
    $path = Join-Path $directory 'curl.exe'
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    return $null
}

function Test-LenovoManifestCustomCurlEnvironment {
    # Do not silently substitute curl for a configured proxy or alternate
    # certificate environment. The existing .NET route owns those cases.
    foreach ($name in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY','CURL_CA_BUNDLE','SSL_CERT_FILE','SSL_CERT_DIR','SSLKEYLOGFILE')) {
        if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { return $true }
    }
    return $false
}

function Get-LenovoManifestTransportChoice {
    param([Parameter(Mandatory=$true)][uri]$Uri,[AllowNull()][string]$CurlPath,[AllowNull()]$Proxy,[bool]$CustomEnvironment)
    if (-not $CurlPath) { return 'dotnet-curl-unavailable' }
    if ($CustomEnvironment) { return 'dotnet-custom-environment' }
    if ($Proxy) {
        $resolved = $Proxy.GetProxy($Uri)
        if ($null -eq $resolved -or -not $resolved.Equals($Uri)) { return 'dotnet-configured-proxy' }
    }
    return 'curl'
}

function Assert-LenovoManifestRequestUri {
    param([Parameter(Mandatory=$true)][uri]$Uri)
    $pattern = '\A' + [regex]::Escape((Get-LenovoUpdateManifestBaseUri)) + '\?cb=[0-9a-f]{32}\z'
    if ($Uri.AbsoluteUri -cnotmatch $pattern) { throw 'Unexpected update manifest URI.' }
}

function New-LenovoManifestCurlStartInfo {
    param([Parameter(Mandatory=$true)][string]$CurlPath,[Parameter(Mandatory=$true)][uri]$Uri)
    Assert-LenovoManifestRequestUri -Uri $Uri
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CurlPath
    $psi.WorkingDirectory = Split-Path -Parent $CurlPath
    # --disable must be the first option. No redirect, config file, shell,
    # forced IP family, certificate override or proxy bypass is allowed.
    $psi.Arguments = ('--disable --proto "=https" --http1.1 --tlsv1.2 --silent --show-error --fail --connect-timeout 5 --max-time 10 --max-filesize 65536 --header "Cache-Control: no-cache" --user-agent "LenovoBootSelector" --output - --write-out "\nLBS277_CURL|%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}\n" "' + $Uri.AbsoluteUri + '"')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    return $psi
}

function New-LenovoManifestCurlTimeout {
    return [System.Net.WebException]::new('Manifest transport exceeded its process deadline.',[System.Net.WebExceptionStatus]::Timeout)
}

function Invoke-LenovoManifestCurlProcess {
    param([Parameter(Mandatory=$true)][System.Diagnostics.ProcessStartInfo]$StartInfo,[ValidateRange(1,60000)][int]$DeadlineMs=12000)
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::Start($StartInfo)
    if (-not $process) { throw 'Manifest transport process could not be started.' }
    $memory = [System.IO.MemoryStream]::new()
    try {
        # Drain stderr concurrently to avoid a pipe deadlock. Do not retain or
        # report the text, which could contain local network details.
        $errorRead = $process.StandardError.ReadToEndAsync()
        $stream = $process.StandardOutput.BaseStream
        $buffer = New-Object byte[] 4096
        while ($true) {
            $remaining = $DeadlineMs - [int]$clock.ElapsedMilliseconds
            if ($remaining -le 0) { throw (New-LenovoManifestCurlTimeout) }
            $read = $stream.ReadAsync($buffer,0,$buffer.Length)
            if (-not $read.Wait($remaining)) { throw (New-LenovoManifestCurlTimeout) }
            $count = $read.Result
            if ($count -eq 0) { break }
            # Bound actual output, including on older curl releases for which
            # max-filesize cannot stop an unknown-length response in flight.
            if ($memory.Length + $count -gt 66560) { throw 'Manifest transport output exceeded its size limit.' }
            $memory.Write($buffer,0,$count)
        }
        $remaining = $DeadlineMs - [int]$clock.ElapsedMilliseconds
        if ($remaining -le 0 -or -not $process.WaitForExit($remaining)) { throw (New-LenovoManifestCurlTimeout) }
        $remaining = $DeadlineMs - [int]$clock.ElapsedMilliseconds
        if ($remaining -le 0 -or -not $errorRead.Wait($remaining)) { throw (New-LenovoManifestCurlTimeout) }
        $encoding = [System.Text.UTF8Encoding]::new($false,$true)
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Output=$encoding.GetString($memory.ToArray()) }
    }
    finally {
        try {
            if (-not $process.HasExited) {
                $process.Kill()
                if (-not $process.WaitForExit(500)) { throw 'Manifest transport termination not confirmed.' }
            }
        }
        catch {
            Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_CURL_CLEANUP_FAILED' -Stage 'curl-cleanup' -Success $false -ErrorRecord $_ -Level warning
        }
        finally {
            $memory.Dispose()
            $process.Dispose()
        }
    }
}

function ConvertFrom-LenovoManifestCurlResponse {
    param([Parameter(Mandatory=$true)]$Result,[Parameter(Mandatory=$true)][hashtable]$Timings)
    $code = [int]$Result.ExitCode
    $Timings.curlExitCode = $code
    if ($code -ne 0) {
        $status = switch ($code) {
            5 { [System.Net.WebExceptionStatus]::ProxyNameResolutionFailure }
            6 { [System.Net.WebExceptionStatus]::NameResolutionFailure }
            7 { [System.Net.WebExceptionStatus]::ConnectFailure }
            22 { [System.Net.WebExceptionStatus]::ProtocolError }
            28 { [System.Net.WebExceptionStatus]::Timeout }
            35 { [System.Net.WebExceptionStatus]::SecureChannelFailure }
            60 { [System.Net.WebExceptionStatus]::TrustFailure }
            default { [System.Net.WebExceptionStatus]::UnknownError }
        }
        throw [System.Net.WebException]::new(('Manifest curl transport failed (exit {0}).' -f $code),$status)
    }
    $match = [regex]::Match([string]$Result.Output,'(?s)\A(?<body>.*)\r?\nLBS277_CURL\|(?<http>[0-9]{3})\|(?<dns>[0-9.]+)\|(?<tcp>[0-9.]+)\|(?<tls>[0-9.]+)\|(?<first>[0-9.]+)\|(?<total>[0-9.]+)\r?\n\z')
    if (-not $match.Success) { throw 'Manifest curl response has no valid completion record.' }
    $Timings.httpStatus = [int]$match.Groups['http'].Value
    foreach ($name in @('dns','tcp','tls','first','total')) {
        $seconds = [double]::Parse($match.Groups[$name].Value,[Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or $seconds -lt 0 -or $seconds -gt 60) { throw 'Manifest curl timing is invalid.' }
        $Timings[('curl' + $name + 'Ms')] = [int64][Math]::Round($seconds * 1000)
    }
    if ($Timings.httpStatus -ne 200) { throw [System.Net.WebException]::new('Unexpected manifest HTTP status.',[System.Net.WebExceptionStatus]::ProtocolError) }
    $body = $match.Groups['body'].Value
    if ([System.Text.Encoding]::UTF8.GetByteCount($body) -gt 65536) { throw 'Manifest response exceeded its size limit.' }
    return $body
}

function Invoke-LenovoUpdateTextDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri,[hashtable]$Timings=@{})
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $phase = 'transport-selection'
    try {
        Assert-LenovoManifestRequestUri -Uri $Uri
        $curlPath = Get-LenovoManifestCurlPath
        $choice = if ($curlPath) { Get-LenovoManifestTransportChoice -Uri $Uri -CurlPath $curlPath -Proxy ([System.Net.WebRequest]::DefaultWebProxy) -CustomEnvironment (Test-LenovoManifestCustomCurlEnvironment) } else { 'dotnet-curl-unavailable' }
        $Timings.transport = $choice
        $Timings.transportSelectionMs = $clock.ElapsedMilliseconds
        if ($choice -ne 'curl') {
            # No fallback after an attempted curl request: especially not on
            # certificate, HTTP or other network failures.
            return (Invoke-LenovoUpdateDotNetManifestDownload -Uri $Uri -Timings $Timings)
        }
        $phase = 'curl-process'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_TRANSPORT_PHASE' -Stage $phase -Data (New-RuntimeDiagnosticData @{ transport='curl'; connectTimeoutMs=5000; transferTimeoutMs=10000; processDeadlineMs=12000 })
        $clock.Restart()
        $psi = New-LenovoManifestCurlStartInfo -CurlPath $curlPath -Uri $Uri
        $result = Invoke-LenovoManifestCurlProcess -StartInfo $psi
        $Timings.curlProcessMs = $clock.ElapsedMilliseconds
        $phase = 'curl-response'
        $clock.Restart()
        return (ConvertFrom-LenovoManifestCurlResponse -Result $result -Timings $Timings)
    }
    catch {
        if (-not $Timings.transportFailurePhase) {
            $Timings.transportFailurePhase = $phase
            $Timings.transportFailurePhaseMs = $clock.ElapsedMilliseconds
        }
        throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'manifest-download' -Message ('Update-Manifest konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception)
    }
}

function Invoke-LenovoUpdateFileDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri,[Parameter(Mandatory=$true)][string]$DestinationPath)
    $client = New-LenovoWebClient
    try { $client.DownloadFile($Uri,$DestinationPath) }
    catch { throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'package-download' -Message ('Update-Paket konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    finally { $client.Dispose() }
}
