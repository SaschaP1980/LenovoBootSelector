#requires -version 5.1
# Read-only LBS-277 transport probe. Does not change proxy settings or install updates.
param(
    [ValidateSet('Supervisor','Legacy','Proxy','Http','Dns')][string]$Mode = 'Supervisor',
    [string]$ResultPath = ''
)
$ErrorActionPreference = 'Stop'
$baseUri = 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json'
$uri = [uri]($baseUri + '?cb=' + [guid]::NewGuid().ToString('N'))

function Write-ProbeJson($Value,[string]$Path) {
    [System.IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
}

if ($Mode -eq 'Supervisor') {
    $workspace = Join-Path ([System.IO.Path]::GetTempPath()) ('LBS277Probe-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $workspace)
    $output = Join-Path $PSScriptRoot ('LBS277-TransportProbe-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    $results = @()
    $retainWorkspace = $false
    try {
        foreach ($kind in @('Legacy','Proxy','Http','Dns')) {
            Write-Host ('Running {0} probe (independent Windows PowerShell process)...' -f $kind)
            $path = Join-Path $workspace ($kind + '.json')
            $start = New-Object System.Diagnostics.ProcessStartInfo
            $start.FileName = Join-Path $PSHOME 'powershell.exe'
            $start.Arguments = ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Mode {1} -ResultPath "{2}"' -f $PSCommandPath,$kind,$path)
            $start.UseShellExecute = $false
            $start.CreateNoWindow = $true
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            $process = [System.Diagnostics.Process]::Start($start)
            $timedOut = $false
            $exited = $false
            $exitCode = $null
            try {
                $exited = $process.WaitForExit(125000)
                if (-not $exited) {
                    $timedOut = $true
                    try { $process.Kill() } catch { Write-Warning 'Probe termination could not be confirmed.' }
                    $exited = $process.WaitForExit(1000)
                }
                if ($exited) { $exitCode = $process.ExitCode }
                else { $retainWorkspace = $true }
            }
            finally { $process.Dispose() }
            $child = $null
            if (Test-Path -LiteralPath $path) {
                try { $child = [System.IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop }
                catch { Write-Warning 'Child probe snapshot was incomplete.' }
            }
            $results += [ordered]@{ mode=$kind; totalMs=$clock.ElapsedMilliseconds; timedOut=$timedOut; exited=$exited; exitCode=$exitCode; detail=$child }
            Write-Host ('{0}: {1} ms (timed out: {2})' -f $kind,$clock.ElapsedMilliseconds,$timedOut)
            if (-not $exited) { break }
        }
        Write-ProbeJson -Value ([ordered]@{ schemaVersion=1; createdUtc=[datetime]::UtcNow.ToString('o'); powershellVersion=$PSVersionTable.PSVersion.ToString(); probes=$results; note='Independent processes run sequentially; operating-system proxy/DNS caches may be shared. No proxy bypass or settings changes.' }) -Path $output
        Write-Host ('Result file: ' + $output)
    }
    finally {
        if (-not $retainWorkspace) { Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction SilentlyContinue }
        else { Write-Warning 'A probe worker did not exit; its temporary workspace was retained.' }
    }
    return
}

if ([string]::IsNullOrWhiteSpace($ResultPath)) { throw 'Child mode requires a result path.' }
$report = [ordered]@{ mode=$Mode; success=$false; activePhase=''; phases=[ordered]@{}; errorClass=''; networkStatus=''; manifestVersion=''; proxySelected=$null; dnsAddressCount=$null }
$phaseClock = [System.Diagnostics.Stopwatch]::new()
function Start-Phase([string]$Name) {
    $report.activePhase = $Name
    Write-ProbeJson -Value $report -Path $ResultPath
    $phaseClock.Restart()
}
function Complete-Phase {
    $report.phases[$report.activePhase] = $phaseClock.ElapsedMilliseconds
    $report.activePhase = ''
    Write-ProbeJson -Value $report -Path $ResultPath
}
$client = $null
$response = $null
$reader = $null
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    switch ($Mode) {
        'Legacy' {
            Start-Phase 'webClientSetup'
            $client = New-Object System.Net.WebClient
            $client.Headers['User-Agent'] = 'LenovoBootSelector/1.10.2.0'
            $client.Headers['Cache-Control'] = 'no-cache'
            Complete-Phase
            Start-Phase 'downloadString'
            $json = $client.DownloadString($uri)
            Complete-Phase
            Start-Phase 'manifestParse'
            $report.manifestVersion = [string]($json | ConvertFrom-Json -ErrorAction Stop).version
            Complete-Phase
        }
        'Proxy' {
            Start-Phase 'defaultProxyLookup'
            $proxy = [System.Net.WebRequest]::DefaultWebProxy
            Complete-Phase
            Start-Phase 'proxyResolveForManifest'
            if ($null -eq $proxy) { $report.proxySelected = $false }
            else {
                $resolved = $proxy.GetProxy($uri)
                $report.proxySelected = ($null -ne $resolved -and -not $resolved.Equals($uri))
            }
            Complete-Phase
        }
        'Http' {
            Start-Phase 'requestSetup'
            $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($uri)
            $request.Method = 'GET'
            $request.UserAgent = 'LenovoBootSelector/1.10.2.0'
            $request.Headers['Cache-Control'] = 'no-cache'
            $request.Timeout = 100000
            $request.ReadWriteTimeout = 15000
            Complete-Phase
            Start-Phase 'responseWait'
            $response = $request.GetResponse()
            Complete-Phase
            Start-Phase 'responseRead'
            $reader = [System.IO.StreamReader]::new($response.GetResponseStream(),[System.Text.Encoding]::UTF8,$true)
            $json = $reader.ReadToEnd()
            Complete-Phase
            Start-Phase 'manifestParse'
            $report.manifestVersion = [string]($json | ConvertFrom-Json -ErrorAction Stop).version
            Complete-Phase
        }
        'Dns' {
            Start-Phase 'dnsResolve'
            $report.dnsAddressCount = @([System.Net.Dns]::GetHostAddresses($uri.Host)).Count
            Complete-Phase
        }
    }
    $report.success = $true
}
catch {
    if ($report.activePhase) { $report.phases[$report.activePhase] = $phaseClock.ElapsedMilliseconds }
    $exception = $_.Exception
    $report.errorClass = $exception.GetType().FullName
    while ($exception) {
        if ($exception -is [System.Net.WebException]) { $report.networkStatus = [string]$exception.Status; $report.errorClass = $exception.GetType().FullName; break }
        $exception = $exception.InnerException
    }
}
finally {
    if ($reader) { $reader.Dispose() }
    if ($response) { $response.Dispose() }
    if ($client) { $client.Dispose() }
    Write-ProbeJson -Value $report -Path $ResultPath
}
if (-not $report.success) { exit 1 }
