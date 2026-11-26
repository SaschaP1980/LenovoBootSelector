#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\UpdateModel.ps1')
. (Join-Path $root 'src\Application\UpdateRuntime.ps1')
. (Join-Path $root 'src\Infrastructure\UpdateTransport.ps1')
. (Join-Path $root 'src\Infrastructure\UpdateClient.ps1')
$checks = 0
function Assert-True([string]$Name,[bool]$Value) { if (-not $Value) { throw "FAIL $Name" }; $script:checks++; Write-Host "PASS  $Name" }
function Assert-Equal([string]$Name,$Expected,$Actual) { if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }; $script:checks++; Write-Host "PASS  $Name" }

Assert-Equal 'Newer version compares positive' 1 (Compare-LenovoAppVersionCore -Current '0.5.6' -Candidate '0.5.7')
Assert-Equal 'Same version compares zero' 0 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7')
Assert-Equal 'Older version compares negative' -1 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.6')
Assert-Equal 'Major version comparison' 1 (Compare-LenovoAppVersionCore -Current '0.9.9' -Candidate '1.0.0')
Assert-Equal 'Legacy three-part equals explicit hotfix zero' 0 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7.0')
Assert-Equal 'Hotfix compares newer than legacy patch' 1 (Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate '0.5.7.1')
Assert-Equal 'Higher hotfix compares newer' 1 (Compare-LenovoAppVersionCore -Current '0.5.7.1' -Candidate '0.5.7.2')
Assert-True 'Four-part version parses' ($null -ne (ConvertTo-LenovoVersionCore -Version '0.5.8.0'))
Assert-True 'Invalid version returns null' ($null -eq (ConvertTo-LenovoVersionCore -Version '0.5'))

$runtime=New-UpdateRuntimeState
Assert-True 'Update runtime has no process-once startup gate' ($null -eq $runtime.PSObject.Properties['StartupCheckStarted'])
Assert-True 'Update runtime has no process-once startup completion flag' ($null -eq $runtime.PSObject.Properties['StartupCheckCompleted'])
Assert-Equal 'Update check mode starts empty' '' $runtime.CheckMode
$threw=$false; try { [void](Compare-LenovoAppVersionCore -Current '0.5.7' -Candidate 'dev') } catch { $threw=$true }; Assert-True 'Invalid compare throws' $threw


$manifestBaseUri=[string](Get-LenovoUpdateManifestBaseUri)
$manifestUri1=[string](Get-LenovoUpdateManifestUri)
$manifestUri2=[string](Get-LenovoUpdateManifestUri)
Assert-Equal 'Manifest base URI remains exact mutable latest.json resource' 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json' $manifestBaseUri
Assert-True 'Manifest URI appends cache-buster only after exact base resource' ($manifestUri1.StartsWith($manifestBaseUri + '?cb='))
Assert-True 'Consecutive manifest checks use distinct cache-busters' ($manifestUri1 -ne $manifestUri2)
Assert-True 'Manifest cache-buster is one GUID nonce query' ($manifestUri1 -match '\?cb=[0-9a-f]{32}$')
$downloadBaseUri=[string](Get-LenovoUpdateDownloadBaseUri)
Assert-Equal 'Versioned package download base remains query-free' 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/' $downloadBaseUri
$packageUri=$downloadBaseUri+[Uri]::EscapeDataString('LenovoBootMenuTray-v0.8.0.4.zip')
Assert-Equal 'Versioned package URI remains stable and cacheable' 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/LenovoBootMenuTray-v0.8.0.4.zip' $packageUri

$dnsError=[System.Net.WebException]::new('dns',[System.Net.WebExceptionStatus]::NameResolutionFailure)
$failure=Get-LenovoUpdateFailureInfo -ErrorRecord $dnsError -DefaultCategory 'runtime' -DefaultStage 'fixture'
Assert-Equal 'DNS failure classified as network' 'network' $failure.Category
Assert-Equal 'DNS network status retained' 'NameResolutionFailure' $failure.NetworkStatus
Assert-Equal 'DNS error class retained' 'System.Net.WebException' $failure.ErrorClass

$timeoutError=[System.Net.WebException]::new('timeout',[System.Net.WebExceptionStatus]::Timeout)
$failure=Get-LenovoUpdateFailureInfo -ErrorRecord $timeoutError -DefaultCategory 'runtime' -DefaultStage 'fixture'
Assert-Equal 'Timeout failure classified as network' 'network' $failure.Category
Assert-Equal 'Timeout network status retained' 'Timeout' $failure.NetworkStatus

$connectError=[System.Net.WebException]::new('connect',[System.Net.WebExceptionStatus]::ConnectFailure)
$failure=Get-LenovoUpdateFailureInfo -ErrorRecord $connectError -DefaultCategory 'runtime' -DefaultStage 'fixture'
Assert-Equal 'Connect failure classified as network' 'network' $failure.Category
Assert-Equal 'Connect network status retained' 'ConnectFailure' $failure.NetworkStatus

$wrapped=New-LenovoUpdateFailureException -Category 'network' -Stage 'manifest-download' -Message 'Manifest transport failed' -InnerException $dnsError
$failure=Get-LenovoUpdateFailureInfo -ErrorRecord $wrapped -DefaultCategory 'runtime' -DefaultStage 'fixture'
Assert-Equal 'Wrapped transport keeps network category' 'network' $failure.Category
Assert-Equal 'Wrapped transport keeps stage' 'manifest-download' $failure.Stage
Assert-Equal 'Wrapped transport keeps network status' 'NameResolutionFailure' $failure.NetworkStatus
Assert-Equal 'Wrapped transport exposes underlying error class' 'System.Net.WebException' $failure.ErrorClass
Assert-Equal 'Wrapped transport keeps user-facing message' 'Manifest transport failed' $failure.Message

$hashFailure=New-LenovoUpdateFailureException -Category 'hash' -Stage 'package-hash' -Message 'Hash mismatch'
$failure=Get-LenovoUpdateFailureInfo -ErrorRecord $hashFailure -DefaultCategory 'runtime' -DefaultStage 'fixture'
Assert-Equal 'Hash failure classified separately' 'hash' $failure.Category
Assert-Equal 'Hash failure stage retained' 'package-hash' $failure.Stage


$files=@('BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1')
$valid=[pscustomobject]@{schemaVersion=1;version='0.5.8.1';file='LenovoBootMenuTray-v0.5.8.1.zip';sha256=('a'*64);size=123;tag='v0.5.8.1';packageFiles=$files}
$r=Test-LenovoUpdateManifestCore -Manifest $valid
Assert-True 'Valid manifest accepted' $r.IsValid
Assert-Equal 'Normalized manifest schema version' 1 $r.SchemaVersion
Assert-Equal 'Normalized manifest version' '0.5.8.1' $r.Version
Assert-Equal 'Normalized manifest filename' 'LenovoBootMenuTray-v0.5.8.1.zip' $r.File
Assert-Equal 'Normalized manifest file count' 10 @($r.PackageFiles).Count
$json=$r | ConvertTo-Json -Depth 10; $round=$json | ConvertFrom-Json; $roundResult=Test-LenovoUpdateManifestCore -Manifest $round; Assert-True 'Manifest survives worker JSON roundtrip' $roundResult.IsValid

$x=$valid.psobject.Copy(); $x.schemaVersion=2; Assert-True 'Unknown schema rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.version='0.5'; Assert-True 'Malformed version rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.file='other.zip'; Assert-True 'Filename/version mismatch rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.sha256='abc'; Assert-True 'Malformed SHA rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.size=0; Assert-True 'Zero size rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.tag='latest'; Assert-True 'Tag/version mismatch rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@(); Assert-True 'Missing package files rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files + '..\evil.ps1'); Assert-True 'Unsafe package filename rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files + 'README.md'); Assert-True 'Duplicate package filename rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'LenovoBootMenuTray.ps1' }); Assert-True 'Missing runtime rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Start-LenovoBootMenuTray.vbs' }); Assert-True 'Missing launcher rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Install-LenovoBootMenuTasks.ps1' }); Assert-True 'Missing installer rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
$x=$valid.psobject.Copy(); $x.packageFiles=@($files | Where-Object { $_ -ne 'Uninstall-LenovoBootMenuTasks.ps1' }); Assert-True 'Missing uninstaller rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $x).IsValid)
Assert-True 'Null manifest rejected' (-not (Test-LenovoUpdateManifestCore -Manifest $null).IsValid)


function New-UpdateCheckFixtureManifest([string]$Version,[string]$PublishedUtc) {
    return [pscustomobject]@{
        schemaVersion=1
        version=$Version
        file=('LenovoBootMenuTray-v{0}.zip' -f $Version)
        sha256=('a'*64)
        size=123
        tag=('v{0}' -f $Version)
        publishedUtc=$PublishedUtc
        packageFiles=$files
    }
}
function New-RuntimeDiagnosticData { param([hashtable]$Data) return $Data }
function Write-RuntimeDiagnosticEvent {
    param([string]$Event,[string]$Stage,[bool]$Success,$Data,[string]$Level)
    if ($Event -eq 'UPDATE_CHECK_WORKER_COMPLETED') { $script:CapturedUpdateDiagnostic=$Data }
}
function Get-LenovoUpdateManifestRemote {
    param([hashtable]$Timings)
    $Timings.manifestFetchMs=1
    $Timings.manifestParseMs=1
    return $script:UpdateManifestFixture
}

$script:AppVersion='0.8.0.3'
$script:UpdateResultPath=$null
$script:UpdateManifestFixture=New-UpdateCheckFixtureManifest -Version '0.8.0.4' -PublishedUtc '2026-10-07T03:00:00Z'
$script:CapturedUpdateDiagnostic=$null
Assert-Equal 'Newer manifest worker succeeds' 0 (Invoke-UpdateCheckWorker)
Assert-Equal 'Update diagnostics record running version' '0.8.0.3' ([string]$script:CapturedUpdateDiagnostic.runningVersion)
Assert-Equal 'Update diagnostics record received manifest version' '0.8.0.4' ([string]$script:CapturedUpdateDiagnostic.manifestVersion)
Assert-Equal 'Update diagnostics record manifest publishedUtc' '2026-10-07T03:00:00Z' ([string]$script:CapturedUpdateDiagnostic.manifestPublishedUtc)
Assert-True 'Newer manifest reports update available' ([bool]$script:CapturedUpdateDiagnostic.updateAvailable)
Assert-True 'LBS-277 diagnostics record monotonic worker timing' ($script:CapturedUpdateDiagnostic.workerElapsedMs -ge 0 -and $null -ne $script:CapturedUpdateDiagnostic.timings)
Assert-Equal 'LBS-277 diagnostics propagate manifest fetch timing' 1 $script:CapturedUpdateDiagnostic.timings.manifestFetchMs
Assert-Equal 'LBS-277 diagnostics propagate manifest parse timing' 1 $script:CapturedUpdateDiagnostic.timings.manifestParseMs
Assert-True 'LBS-277 diagnostics measure validation and comparison' ($script:CapturedUpdateDiagnostic.timings.ContainsKey('manifestValidationMs') -and $script:CapturedUpdateDiagnostic.timings.ContainsKey('versionCompareMs'))
$manifestRequest=New-LenovoUpdateManifestRequest -Uri ([uri]$manifestUri1)
Assert-Equal 'LBS-277 explicit request response timeout' 100000 $manifestRequest.Timeout
Assert-Equal 'LBS-277 explicit response read timeout' 15000 $manifestRequest.ReadWriteTimeout
Assert-Equal 'LBS-277 request retains cache-busting URI' $manifestUri1 $manifestRequest.RequestUri.AbsoluteUri
Assert-Equal 'LBS-277 request retains no-cache header' 'no-cache' $manifestRequest.Headers['Cache-Control']
Assert-True 'LBS-277 request retains system proxy policy' ([object]::ReferenceEquals($manifestRequest.Proxy,[System.Net.WebRequest]::DefaultWebProxy))
Assert-True 'LBS-277 compatibility request rejects redirects' (-not $manifestRequest.AllowAutoRedirect)
$curlPath=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'curl.exe'
Assert-Equal 'LBS-277 inbox curl selected on direct default route' 'curl' (Get-LenovoManifestTransportChoice -Uri ([uri]$manifestUri1) -CurlPath $curlPath -Proxy $null -CustomEnvironment $false)
Assert-Equal 'LBS-277 missing curl selects compatibility transport' 'dotnet-curl-unavailable' (Get-LenovoManifestTransportChoice -Uri ([uri]$manifestUri1) -CurlPath $null -Proxy $null)
Assert-Equal 'LBS-277 alternate environment selects compatibility transport' 'dotnet-custom-environment' (Get-LenovoManifestTransportChoice -Uri ([uri]$manifestUri1) -CurlPath $curlPath -Proxy $null -CustomEnvironment $true)
$proxy=[System.Net.WebProxy]::new('http://127.0.0.1:8080')
Assert-Equal 'LBS-277 configured proxy selects compatibility transport' 'dotnet-configured-proxy' (Get-LenovoManifestTransportChoice -Uri ([uri]$manifestUri1) -CurlPath $curlPath -Proxy $proxy)
$curlInfo=New-LenovoManifestCurlStartInfo -CurlPath $curlPath -Uri ([uri]$manifestUri1)
Assert-True 'LBS-277 fixed executable and no shell or visible console' ($curlInfo.FileName -eq $curlPath -and -not $curlInfo.UseShellExecute -and $curlInfo.CreateNoWindow -and $curlInfo.RedirectStandardOutput -and $curlInfo.RedirectStandardError)
Assert-True 'LBS-277 curl ignores local config and fixes HTTPS protocol and budgets' ($curlInfo.Arguments.StartsWith('--disable --proto "=https" --http1.1 --tlsv1.2 ') -and $curlInfo.Arguments.Contains('--connect-timeout 5 --max-time 10 --max-filesize 65536') -and $curlInfo.Arguments.Contains($manifestUri1) -and $curlInfo.Arguments.Contains('%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}'))
Assert-True 'LBS-277 no TLS bypass redirect proxy bypass or forced address family' ($curlInfo.Arguments -notmatch '(?i)(?:^|\s)(?:--insecure|-k|--location|-L|--noproxy|--ssl-no-revoke|--ssl-revoke-best-effort|-4|-6)(?:\s|$)')
$uriRejected=$false
try { [void](New-LenovoManifestCurlStartInfo -CurlPath $curlPath -Uri ([uri]'https://example.com/latest.json')) } catch { $uriRejected=$true }
Assert-True 'LBS-277 rejects a noncanonical manifest URL before process launch' $uriRejected
$fixtureBody='{"version":"1.10.2.1"}'
$fixtureOutput=$fixtureBody + [char]10 + 'LBS277_CURL|200|0.021152|0.030485|0.138168|0.324335|0.324390' + [char]10
$curlTiming=@{}
$parsed=ConvertFrom-LenovoManifestCurlResponse -Result ([pscustomobject]@{ExitCode=0;Output=$fixtureOutput}) -Timings $curlTiming
Assert-Equal 'LBS-277 curl response body separated from completion metadata' $fixtureBody $parsed
Assert-True 'LBS-277 curl timing and HTTP status propagated' ($curlTiming.httpStatus -eq 200 -and $curlTiming.curldnsMs -eq 21 -and $curlTiming.curltcpMs -eq 30 -and $curlTiming.curltlsMs -eq 138 -and $curlTiming.curlfirstMs -eq 324 -and $curlTiming.curltotalMs -eq 324)
$bad=$null
try { [void](ConvertFrom-LenovoManifestCurlResponse -Result ([pscustomobject]@{ExitCode=0;Output=$fixtureOutput.Replace('|200|','|301|')}) -Timings @{}) } catch { $bad=Get-LenovoUpdateFailureInfo -ErrorRecord $_ }
Assert-Equal 'LBS-277 HTTP redirect never becomes accepted manifest' 'ProtocolError' $bad.NetworkStatus
$bad=$null
try { [void](ConvertFrom-LenovoManifestCurlResponse -Result ([pscustomobject]@{ExitCode=60;Output=$fixtureOutput}) -Timings @{}) } catch { $bad=Get-LenovoUpdateFailureInfo -ErrorRecord $_ }
Assert-Equal 'LBS-277 failed certificate rejects even an otherwise valid body' 'TrustFailure' $bad.NetworkStatus
$bad=$false
try { [void](ConvertFrom-LenovoManifestCurlResponse -Result ([pscustomobject]@{ExitCode=0;Output=$fixtureBody}) -Timings @{}) } catch { $bad=$true }
Assert-True 'LBS-277 incomplete transport metadata fails closed' $bad
$bad=$false
try { [void](ConvertFrom-LenovoManifestCurlResponse -Result ([pscustomobject]@{ExitCode=0;Output=('a'*65537)+$fixtureOutput}) -Timings @{}) } catch { $bad=$true }
Assert-True 'LBS-277 oversized curl manifest fails closed' $bad

# Exercise the real child process/pipe lifecycle without making network calls.
$childInfo=New-Object System.Diagnostics.ProcessStartInfo
$childInfo.FileName=Join-Path $PSHOME 'powershell.exe'
$childInfo.Arguments='-NoProfile -NonInteractive -Command "[Console]::Write(''fixture''); [Console]::Error.Write(''discard''); exit 7"'
$childInfo.UseShellExecute=$false
$childInfo.CreateNoWindow=$true
$childInfo.RedirectStandardOutput=$true
$childInfo.RedirectStandardError=$true
$child=Invoke-LenovoManifestCurlProcess -StartInfo $childInfo
Assert-True 'LBS-277 child drains both pipes and preserves output and exit code' ($child.Output -ceq 'fixture' -and $child.ExitCode -eq 7)
$childInfo.Arguments='-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 10"'
$childFailure=$null
$childClock=[System.Diagnostics.Stopwatch]::StartNew()
try { [void](Invoke-LenovoManifestCurlProcess -StartInfo $childInfo -DeadlineMs 100) } catch { $childFailure=Get-LenovoUpdateFailureInfo -ErrorRecord $_ }
Assert-True 'LBS-277 owned child deadline bounds hung process' ($childFailure.NetworkStatus -eq 'Timeout' -and $childClock.ElapsedMilliseconds -lt 5000)

# Inject transport boundaries, keeping the real entrypoint and response parser.
$script:FakeTransportChoice='curl'
$script:FakeCurlResult=[pscustomobject]@{ExitCode=0;Output=$fixtureOutput}
$script:FakeCurlStarts=0
$script:FakeDotNetStarts=0
function Get-LenovoManifestCurlPath { return (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'curl.exe') }
function Get-LenovoManifestTransportChoice { param([uri]$Uri,[string]$CurlPath,$Proxy,[bool]$CustomEnvironment) return $script:FakeTransportChoice }
function Invoke-LenovoManifestCurlProcess { param($StartInfo) $script:FakeCurlStarts++; return $script:FakeCurlResult }
$script:FakeTransportFails=$false
$script:FakeTransportResponse=$null
function New-LenovoUpdateManifestRequest {
    param([uri]$Uri)
    $script:FakeDotNetStarts++
    $req=[pscustomobject]@{Timeout=100000;ReadWriteTimeout=15000}
    $req | Add-Member ScriptMethod GetResponse {
        if ($script:FakeTransportFails) { throw [System.Net.WebException]::new('timeout',[System.Net.WebExceptionStatus]::Timeout) }
        $r=[pscustomobject]@{Disposed=$false;StatusCode=200}
        $r | Add-Member ScriptMethod GetResponseStream { return [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes('{"version":"1.10.2.1"}')) }
        $r | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
        $script:FakeTransportResponse=$r
        return $r
    }
    return $req
}
$transportTiming=@{}
$curlText=Invoke-LenovoUpdateTextDownload -Uri ([uri]$manifestUri1) -Timings $transportTiming
Assert-True 'LBS-277 real manifest entrypoint selects curl on eligible route' ($curlText -ceq $fixtureBody -and $transportTiming.transport -eq 'curl' -and $script:FakeCurlStarts -eq 1 -and $script:FakeDotNetStarts -eq 0)
$script:FakeCurlResult=[pscustomobject]@{ExitCode=28;Output=$fixtureOutput}
$curlFailure=$null
try { [void](Invoke-LenovoUpdateTextDownload -Uri ([uri]$manifestUri1) -Timings @{}) } catch { $curlFailure=Get-LenovoUpdateFailureInfo -ErrorRecord $_ }
Assert-True 'LBS-277 curl timeout does not retry through slow compatibility route' ($curlFailure.NetworkStatus -eq 'Timeout' -and $curlFailure.Stage -eq 'manifest-download' -and $script:FakeCurlStarts -eq 2 -and $script:FakeDotNetStarts -eq 0)
$script:FakeTransportChoice='dotnet-configured-proxy'
$transportTiming=@{}
$textResult=Invoke-LenovoUpdateTextDownload -Uri ([uri]$manifestUri1) -Timings $transportTiming
Assert-Equal 'LBS-277 offline transport reads response body' '{"version":"1.10.2.1"}' $textResult
Assert-True 'LBS-277 explicit compatibility route never invokes curl' ($transportTiming.transport -eq 'dotnet-configured-proxy' -and $script:FakeDotNetStarts -eq 1 -and $script:FakeCurlStarts -eq 2)
Assert-True 'LBS-277 successful response disposes owned handle' ([bool]$script:FakeTransportResponse.Disposed)
Assert-True 'LBS-277 offline transport records setup wait and read' ($transportTiming.ContainsKey('transportSetupMs') -and $transportTiming.ContainsKey('responseWaitMs') -and $transportTiming.ContainsKey('responseReadMs'))
$script:FakeTransportFails=$true
$transportTiming=@{}
$transportFailure=$null
try { [void](Invoke-LenovoUpdateTextDownload -Uri ([uri]$manifestUri1) -Timings $transportTiming) }
catch { $transportFailure=Get-LenovoUpdateFailureInfo -ErrorRecord $_ }
Assert-True 'LBS-277 response timeout remains a classified network failure' ($transportFailure -and $transportFailure.Category -eq 'network' -and $transportFailure.Stage -eq 'manifest-download' -and $transportFailure.NetworkStatus -eq 'Timeout')
Assert-True 'LBS-277 response failure records failed phase' ($transportTiming.transportFailurePhase -eq 'response-wait' -and $transportTiming.transportFailurePhaseMs -ge 0)

$script:UpdateManifestFixture=New-UpdateCheckFixtureManifest -Version '0.8.0.3' -PublishedUtc '2026-10-07T03:01:00Z'
$script:CapturedUpdateDiagnostic=$null
[void](Invoke-UpdateCheckWorker)
Assert-True 'Equal manifest reports no update available' (-not [bool]$script:CapturedUpdateDiagnostic.updateAvailable)

$script:UpdateManifestFixture=New-UpdateCheckFixtureManifest -Version '0.8.0.2' -PublishedUtc '2026-10-07T03:02:00Z'
$script:CapturedUpdateDiagnostic=$null
[void](Invoke-UpdateCheckWorker)
Assert-True 'Older manifest reports no update available' (-not [bool]$script:CapturedUpdateDiagnostic.updateAvailable)


$migrationManifest=[pscustomobject]@{schemaVersion=1;version='0.9.0.0';file='LenovoBootMenuTray-v0.9.0.0.zip';sha256=('b'*64);size=456;tag='v0.9.0.0';packageFiles=$files}
$migrationResult=Test-LenovoUpdateManifestCore -Manifest $migrationManifest
Assert-True 'v0.9.0.0 migration manifest remains acceptable to pre-migration updater contract' $migrationResult.IsValid
Assert-Equal 'v0.9.0.0 retains legacy-compatible release ZIP filename' 'LenovoBootMenuTray-v0.9.0.0.zip' $migrationResult.File
Assert-True 'v0.9.0.0 retains legacy-compatible runtime package filename' (@($migrationResult.PackageFiles) -contains 'LenovoBootMenuTray.ps1')
Assert-True 'v0.9.0.0 retains legacy-compatible launcher package filename' (@($migrationResult.PackageFiles) -contains 'Start-LenovoBootMenuTray.vbs')

$legacyOk=[pscustomobject]@{utc='2026-10-05T11:00:00Z';success=$true;message='Update auf v0.5.8.1 installiert.'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $legacyOk -RunningVersion '0.5.8.1'
Assert-Equal 'Legacy success format detected' 'legacy-success' $rr.ResultFormat
Assert-True 'Legacy success is successful' $rr.Success
Assert-Equal 'Legacy success display uses running version' '0.5.8.1' $rr.DisplayVersion
Assert-Equal 'Legacy success does not invent target version' '' $rr.TargetVersion
Assert-True 'Legacy success message reports actual running version' ($rr.Message -match 'Aktuell läuft v0\.5\.8\.1')

$legacyFail=[pscustomobject]@{utc='2026-10-05T11:00:00Z';success=$false;message='Legacy install failed'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $legacyFail -RunningVersion '0.5.8.1'
Assert-Equal 'Legacy failure format detected' 'legacy-success' $rr.ResultFormat
Assert-True 'Legacy false remains failure' (-not $rr.Success)
Assert-Equal 'Legacy failure keeps helper message' 'Legacy install failed' $rr.Message

$newPending=[pscustomobject]@{schemaVersion=1;status='pending-verification';sourceVersion='0.5.8.0';targetVersion='0.5.8.1';utc='2026-10-05T11:00:00Z';message='pending';rollbackAttempted=$false;rollbackSucceeded=$false}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $newPending -RunningVersion '0.5.8.1'
Assert-Equal 'Status format remains primary' 'status' $rr.ResultFormat
Assert-True 'Pending verification succeeds on exact running target' $rr.Success
Assert-Equal 'Pending verification preserves target version' '0.5.8.1' $rr.TargetVersion

$mixed=[pscustomobject]@{status='failed';success=$true;message='new format wins';rollbackAttempted=$false;rollbackSucceeded=$false}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $mixed -RunningVersion '0.5.8.1'
Assert-Equal 'Status wins over legacy success field' 'status' $rr.ResultFormat
Assert-True 'Failed status wins over legacy success true' (-not $rr.Success)

$malformed=[pscustomobject]@{success='true';message='not a Boolean'}
$rr=Resolve-LenovoUpdateRestartResultCore -Result $malformed -RunningVersion '0.5.8.1'
Assert-Equal 'Non-Boolean legacy success is rejected' 'unknown' $rr.ResultFormat
Assert-True 'Malformed legacy result fails closed' (-not $rr.Success)
$tokens = $null
$parseErrors = $null
$testAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $MyInvocation.MyCommand.Path,
    [ref]$tokens,
    [ref]$parseErrors
)
if (@($parseErrors).Count -ne 0) {
    throw "Update test self-audit could not parse its own source."
}
$sourceAssertionCount = @(
    $testAst.FindAll({
        param($node)
        if ($node -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
        $commandName = $node.GetCommandName()
        return $commandName -eq 'Assert-True' -or $commandName -eq 'Assert-Equal'
    }, $true)
).Count
if ($checks -ne $sourceAssertionCount) {
    throw "Update assertion execution/source mismatch: executed $checks, source $sourceAssertionCount"
}
Write-Host "UPDATE ASSERTION SOURCE $sourceAssertionCount/113"
if ($sourceAssertionCount -ne 113) { throw "Unexpected update assertion source count $sourceAssertionCount" }

Write-Host "UPDATE TOTAL $checks/113"
if ($checks -ne 113) { throw "Unexpected update test count $checks" }
