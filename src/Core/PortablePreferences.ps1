# Portable preference format v1. Pure data operations; no IO or action admission.
function Get-PortablePreferencesLimitCore { return 262144 }

function Read-PortableJsonTokenCore {
    param($Reader)
    $match = $Reader.Pattern.Match($Reader.Text,$Reader.Offset)
    if (-not $match.Success -or $match.Index -ne $Reader.Offset) { throw 'InvalidJson' }
    $Reader.Offset = $match.Index + $match.Length
    return $match.Groups['token'].Value
}

function ConvertFrom-PortableJsonStringCore {
    param([string]$Token)
    $value = [regex]::Replace($Token.Substring(1,$Token.Length-2),'\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4})',[System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        switch -CaseSensitive ($m.Value.Substring(1,1)) {
            '"' { return '"' }
            '\' { return '\' }
            '/' { return '/' }
            'b' { return [string][char]8 }
            'f' { return [string][char]12 }
            'n' { return [string][char]10 }
            'r' { return [string][char]13 }
            't' { return [string][char]9 }
            'u' { return [string][char][Convert]::ToInt32($m.Value.Substring(2),16) }
        }
    })
    [void]([System.Text.UTF8Encoding]::new($false,$true).GetByteCount($value))
    return $value
}

function Read-PortableJsonValueCore {
    param($Reader,[string]$Token,[int]$Depth)
    if ($Depth -gt 5) { throw 'InvalidDepth' }
    if ($Token -ceq '{') {
        $map = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::OrdinalIgnoreCase)
        $key = Read-PortableJsonTokenCore $Reader
        if ($key -ceq '}') { return [pscustomobject]@{Value=$map} }
        while ($true) {
            if (-not $key.StartsWith('"')) { throw 'InvalidJson' }
            $name = ConvertFrom-PortableJsonStringCore $key
            if ($map.Contains($name)) { throw 'DuplicateKey' }
            if ((Read-PortableJsonTokenCore $Reader) -cne ':') { throw 'InvalidJson' }
            $value = Read-PortableJsonValueCore $Reader (Read-PortableJsonTokenCore $Reader) ($Depth+1)
            $map.Add($name,$value.Value)
            if ($map.Count -gt 512) { throw 'InvalidShape' }
            $separator = Read-PortableJsonTokenCore $Reader
            if ($separator -ceq '}') { break }
            if ($separator -cne ',') { throw 'InvalidJson' }
            $key = Read-PortableJsonTokenCore $Reader
        }
        return [pscustomobject]@{Value=$map}
    }
    if ($Token -ceq '[') {
        $items = [System.Collections.Generic.List[object]]::new()
        $next = Read-PortableJsonTokenCore $Reader
        if ($next -cne ']') {
            while ($true) {
                $item = Read-PortableJsonValueCore $Reader $next ($Depth+1)
                $items.Add($item.Value)
                if ($items.Count -gt 512) { throw 'TooManyEntries' }
                $separator = Read-PortableJsonTokenCore $Reader
                if ($separator -ceq ']') { break }
                if ($separator -cne ',') { throw 'InvalidJson' }
                $next = Read-PortableJsonTokenCore $Reader
            }
        }
        return [pscustomobject]@{Value=$items.ToArray()}
    }
    if ($Token.StartsWith('"')) {
        $value = ConvertFrom-PortableJsonStringCore $Token
        return [pscustomobject]@{Value=$value}
    }
    switch -CaseSensitive ($Token) {
        'true' { return [pscustomobject]@{Value=$true} }
        'false' { return [pscustomobject]@{Value=$false} }
        'null' { return [pscustomobject]@{Value=$null} }
        default {
            if ($Token -cmatch '^(0|[1-9][0-9]*)$') {
                $number = 0
                if ([int]::TryParse($Token,[ref]$number)) { return [pscustomobject]@{Value=$number} }
            }
            throw 'InvalidScalar'
        }
    }
}

function Assert-PortableKeysCore {
    param($Map,[string[]]$Keys)
    if ($Map -isnot [System.Collections.IDictionary] -or $Map.Count -ne $Keys.Count) { throw 'InvalidShape' }
    foreach ($key in $Map.Keys) {
        if ($key -cnotin $Keys) { throw 'UnknownKey' }
    }
}

function ConvertTo-PortableGuidCore {
    param($Value)
    if ($Value -isnot [string] -or $Value -cnotmatch '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$') { throw 'InvalidIdentity' }
    return $Value.ToLowerInvariant()
}

function Read-BoundedPreferencesJsonCore {
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    $encoding = [System.Text.UTF8Encoding]::new($false,$true)
    if ($encoding.GetByteCount($Text) -gt (Get-PortablePreferencesLimitCore)) { throw 'InvalidSize' }
    # Narrow grammar for preference documents (integer versions, no floats).
    # Decode strings without date coercion; detect duplicate decoded keys.
    $reader = [pscustomobject]@{
        Text=$Text; Offset=0
        Pattern=[regex]::new('\G[ \t\r\n]*(?<token>"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"|[{}\[\]:,]|true|false|null|0|[1-9][0-9]*)',[System.Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(2))
    }
    $root = (Read-PortableJsonValueCore $reader (Read-PortableJsonTokenCore $reader) 0).Value
    if ($Text.Substring($reader.Offset) -cnotmatch '^[ \t\r\n]*$') { throw 'TrailingJson' }
    return [pscustomobject]@{Value=$root}
}

function ConvertFrom-PortablePreferencesCore {
    param([AllowEmptyString()][string]$Text)
    $root = (Read-BoundedPreferencesJsonCore $Text).Value
    $encoding = [System.Text.UTF8Encoding]::new($false,$true)
    Assert-PortableKeysCore $root @('format','version','locale','entries')
    if ($root.format -isnot [string] -or $root.format -cne 'LenovoBootSelector.Preferences' -or $root.version -isnot [int] -or $root.version -ne 1) { throw 'UnsupportedFormat' }
    if ($root.locale -isnot [string] -or $root.locale -cnotin @('de-DE','en-US')) { throw 'InvalidLocale' }
    if ($root.entries -isnot [array]) { throw 'InvalidEntries' }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $root.entries) {
        Assert-PortableKeysCore $row @('guid','alias','hidden')
        $guid = ConvertTo-PortableGuidCore $row.guid
        if (-not $seen.Add($guid)) { throw 'DuplicateIdentity' }
        if ($row.hidden -isnot [bool] -or $row.alias -isnot [string]) { throw 'InvalidEntry' }
        if ($row.alias.Length -gt 4096 -or $row.alias -match '[\x00-\x1f\x7f]' -or $row.alias -cne $row.alias.Trim()) { throw 'InvalidAlias' }
        [void]$encoding.GetByteCount($row.alias)
        $entries.Add([pscustomobject]@{guid=$guid;alias=$row.alias;hidden=$row.hidden})
    }
    return [pscustomobject]@{format=$root.format;version=1;locale=$root.locale;entries=$entries.ToArray()}
}

function New-PortablePreferencesCore {
    param($Settings,[object[]]$CurrentEntries)
    if ($Settings.localePreferenceNeedsConfirmation -or $Settings.localePreferenceSource -eq 'migration-pending') { throw 'LocaleMigrationPending' }
    $aliases = Convert-EntryAliasesToHashtable $Settings.entryAliases
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($CurrentEntries)) {
        if (-not $seen.Add((ConvertTo-PortableGuidCore $entry.Guid))) { throw 'DuplicateLocalIdentity' }
    }
    $rows = @(
        foreach ($entry in @(Get-OrderedEntriesCore -Source $CurrentEntries -Order $Settings.entryOrder -Hidden $Settings.hiddenEntryGuids -IncludeHidden)) {
            $guid = ConvertTo-PortableGuidCore $entry.Guid
            [ordered]@{guid=$guid;alias=[string]$aliases[$guid];hidden=(Test-GuidInList -Guid $guid -List $Settings.hiddenEntryGuids)}
        }
    )
    $payload = [ordered]@{format='LenovoBootSelector.Preferences';version=1;locale=[string]$Settings.locale;entries=$rows}
    $json = ConvertTo-Json -InputObject $payload -Depth 5
    # Self-validate before any file write; never emit an unsupported file.
    [void](ConvertFrom-PortablePreferencesCore $json)
    return $json
}

function New-PortablePreferencesPlanCore {
    param($Imported,$Settings,[object[]]$CurrentEntries)
    if ($Settings.localePreferenceNeedsConfirmation -or $Settings.localePreferenceSource -eq 'migration-pending') { throw 'LocaleMigrationPending' }
    $local = @{}
    foreach ($entry in @($CurrentEntries)) {
        $guid = ConvertTo-PortableGuidCore $entry.Guid
        if ($local.ContainsKey($guid)) { throw 'DuplicateLocalIdentity' }
        $local[$guid]=$entry
    }
    $aliases = Convert-EntryAliasesToHashtable $Settings.entryAliases
    $hidden = @($Settings.hiddenEntryGuids)
    $ordered = @(Get-OrderedEntriesCore -Source $CurrentEntries -Order $Settings.entryOrder -Hidden $hidden -IncludeHidden | ForEach-Object { [string]$_.Guid })
    # Preserve unavailable persisted order entries at their existing positions.
    $order = [System.Collections.Generic.List[string]]::new()
    $orderSeen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($guid in @($Settings.entryOrder)+$ordered) {
        if ($guid -and $orderSeen.Add([string]$guid)) { $order.Add([string]$guid) }
    }
    $matched = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $importOrder = [System.Collections.Generic.List[string]]::new()
    $preview = [System.Collections.Generic.List[object]]::new()
    foreach ($row in @($Imported.entries)) {
        $guid = $row.guid
        if (-not $local.ContainsKey($guid)) {
            $preview.Add([pscustomobject]@{Guid=$guid;Title='';Status='Unmatched';OldAlias='';NewAlias=$row.alias;OldHidden=$null;NewHidden=$row.hidden;OldPosition=$null;NewPosition=$null;AliasSkipped=$false})
            continue
        }
        $old = [string]$aliases[$guid]
        $skip = -not (Test-EntryAliasChangeCore -Value $row.alias -Previous $old)
        $new = if ($skip) {$old} else {$row.alias}
        $wasHidden = Test-GuidInList -Guid $guid -List $hidden
        if ($new) { $aliases[$guid]=$new } else { $aliases.Remove($guid) }
        if ($wasHidden -ne $row.hidden) {
            $hidden = @($hidden | Where-Object { $_ -ne $guid })
            if ($row.hidden) { $hidden += $guid }
        }
        [void]$matched.Add($guid)
        $importOrder.Add($guid)
        $preview.Add([pscustomobject]@{Guid=$guid;Title=[string]$local[$guid].Title;Status='Matched';OldAlias=$old;NewAlias=$new;OldHidden=$wasHidden;NewHidden=$row.hidden;OldPosition=([array]::IndexOf($ordered,$guid)+1);NewPosition=$null;AliasSkipped=$skip})
    }
    $index=0
    for ($i=0;$i -lt $order.Count;$i++) {
        if ($matched.Contains($order[$i])) { $order[$i]=$importOrder[$index]; $index++ }
    }
    $newOrdered = @($order | Where-Object { $local.ContainsKey($_) })
    foreach ($row in $preview) {
        if ($row.Status -eq 'Matched') { $row.NewPosition=[array]::IndexOf($newOrdered,$row.Guid)+1 }
    }
    foreach ($guid in $ordered) {
        if (-not $matched.Contains($guid)) {
            $preview.Add([pscustomobject]@{Guid=$guid;Title=[string]$local[$guid].Title;Status='LocalOnly';OldAlias=[string]$aliases[$guid];NewAlias=[string]$aliases[$guid];OldHidden=(Test-GuidInList -Guid $guid -List $hidden);NewHidden=(Test-GuidInList -Guid $guid -List $hidden);OldPosition=([array]::IndexOf($ordered,$guid)+1);NewPosition=([array]::IndexOf($newOrdered,$guid)+1);AliasSkipped=$false})
        }
    }
    $unavailable = @(@($Settings.entryOrder)+@($Settings.hiddenEntryGuids)+@($aliases.Keys) | Where-Object { $_ -and -not $local.ContainsKey($_) } | Sort-Object -Unique)
    $resultOrder = if (Test-StringSequenceEqual -Left $ordered -Right $newOrdered) { @($Settings.entryOrder) } else { $order.ToArray() }
    return [pscustomobject]@{Locale=$Imported.locale;OldLocale=$Settings.locale;EntryOrder=@($resultOrder);HiddenEntryGuids=@($hidden | Select-Object -Unique);EntryAliases=$aliases;Rows=$preview.ToArray();UnavailableLocal=$unavailable}
}
