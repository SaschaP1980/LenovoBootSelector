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

function Invoke-LenovoUpdateTextDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri)
    $client = New-LenovoWebClient
    try { return $client.DownloadString($Uri) }
    catch { throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'manifest-download' -Message ('Update-Manifest konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    finally { $client.Dispose() }
}

function Invoke-LenovoUpdateFileDownload {
    param([Parameter(Mandatory=$true)][uri]$Uri,[Parameter(Mandatory=$true)][string]$DestinationPath)
    $client = New-LenovoWebClient
    try { $client.DownloadFile($Uri,$DestinationPath) }
    catch { throw (New-LenovoUpdateFailureException -Category 'network' -Stage 'package-download' -Message ('Update-Paket konnte nicht geladen werden: ' + $_.Exception.Message) -InnerException $_.Exception) }
    finally { $client.Dispose() }
}
