# Local, unelevated, bounded IO only. No firmware, registry, process or broker calls.
function Read-PreferencesFileSnapshot {
    param([Parameter(Mandatory=$true)][string]$Path,[switch]$AllowMissing)
    $stream=$null
    try {
        try { $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read) }
        catch [IO.FileNotFoundException] { if ($AllowMissing) { return [pscustomobject]@{Exists=$false;Token='missing';Text=''} }; throw }
        catch [IO.DirectoryNotFoundException] { if ($AllowMissing) { return [pscustomobject]@{Exists=$false;Token='missing';Text=''} }; throw }
        $length=$stream.Length
        if ($length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
        $bytes=[byte[]]::new([int]$length)
        $offset=0
        while ($offset -lt $bytes.Length) {
            $count=$stream.Read($bytes,$offset,$bytes.Length-$offset)
            if ($count -le 0) { throw 'ReadChanged' }
            $offset+=$count
        }
        if ($stream.ReadByte() -ne -1) { throw 'ReadChanged' }
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $token=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
        $start=0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $start=3 }
        $encoding=[Text.UTF8Encoding]::new($false,$true)
        $text=$encoding.GetString($bytes,$start,$bytes.Length-$start)
        return [pscustomobject]@{Exists=$true;Token=$token;Text=$text}
    }
    finally { if ($stream) { $stream.Dispose() } }
}

function Write-PreferencesFileAtomic {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Text,[Parameter(Mandatory=$true)][string]$ExpectedToken)
    $encoding=[Text.UTF8Encoding]::new($false,$true)
    $bytes=$encoding.GetBytes($Text)
    if ($bytes.Length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    $path=[IO.Path]::GetFullPath($Path)
    $directory=[IO.Path]::GetDirectoryName($path)
    $original=Read-PreferencesFileSnapshot -Path $path -AllowMissing
    if ($original.Token -cne $ExpectedToken) { throw 'StalePreview' }
    # A unique sibling temporary file permits an atomic same-volume rename.
    # File.Replace retains a rollback copy until the replacement succeeds.
    [void][IO.Directory]::CreateDirectory($directory)
    $nonce=[guid]::NewGuid().ToString('N')
    $temporary=[IO.Path]::Combine($directory,'.lbs-preferences-'+$nonce+'.tmp')
    $backup=[IO.Path]::Combine($directory,'.lbs-preferences-'+$nonce+'.bak')
    $committed=$false
    $replacementAttempted=$false
    try {
        $stream=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        $new=Read-PreferencesFileSnapshot -Path $temporary
        $latest=Read-PreferencesFileSnapshot -Path $path -AllowMissing
        if ($latest.Token -cne $ExpectedToken) { throw 'StalePreview' }
        $replacementAttempted=$true
        if ($original.Exists) { [IO.File]::Replace($temporary,$path,$backup) }
        else { [IO.File]::Move($temporary,$path) }
        $committed=$true
    }
    catch {
        if ($replacementAttempted) {
            try {
                $observed=Read-PreferencesFileSnapshot -Path $path -AllowMissing
                if ($observed.Token -cne $ExpectedToken) {
                    # Never overwrite an unrelated external writer's new data.
                    if ($original.Exists -and [IO.File]::Exists($backup) -and
                        (-not $observed.Exists -or $observed.Token -ceq $new.Token)) {
                        if ($observed.Exists) { [IO.File]::Replace($backup,$path,$null) }
                        else { [IO.File]::Move($backup,$path) }
                    }
                    elseif (-not $original.Exists -and $observed.Token -ceq $new.Token) { [IO.File]::Delete($path) }
                    else { throw 'CommitUncertain' }
                    if ((Read-PreferencesFileSnapshot -Path $path -AllowMissing).Token -cne $ExpectedToken) { throw 'CommitUncertain' }
                }
            }
            catch { throw 'CommitUncertain' }
        }
        throw
    }
    finally {
        try { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } } catch { }
        # Preserve an available rollback copy on uncertain failure.
        if ($committed) { try { if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) } } catch { } }
    }
}
