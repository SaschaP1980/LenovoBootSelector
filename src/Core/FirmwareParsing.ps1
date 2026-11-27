# Lenovo Boot Selector v0.4.1 - Functional Core: firmware text parsing
# Pure/deterministic functions only. Input is text; output is normalized data.

function Parse-GuidFromLine([string]$Line) {
    if ($Line -match '(\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\})') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}
function ConvertFrom-FirmwareEntriesText {
    param([AllowEmptyString()][string]$Text)

    # Map GUID -> firmware description. Support English and German field labels.
    $descriptions = @{}
    $currentGuid = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*(identifier|Bezeichner)\s+') {
            $currentGuid = Parse-GuidFromLine $line
            continue
        }

        if ($currentGuid -and $line -match '^\s*(description|Beschreibung)\s+(.+?)\s*$') {
            $descriptions[$currentGuid] = $Matches[2].Trim()
        }
    }
    return $descriptions
}

function ConvertFrom-FirmwareManagerText {
    param([AllowEmptyString()][string]$Text)

    $displayOrder = New-Object System.Collections.Generic.List[string]
    $selectedGuid = $null
    $readingDisplayOrder = $false

    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*displayorder\s+') {
            $guid = Parse-GuidFromLine $line
            if ($guid) { $displayOrder.Add($guid) }
            $readingDisplayOrder = $true
            continue
        }

        if ($readingDisplayOrder) {
            $continuedGuid = Parse-GuidFromLine $line
            if ($continuedGuid -and $line -match '^\s+\{') {
                $displayOrder.Add($continuedGuid)
                continue
            }
            $readingDisplayOrder = $false
        }

        if ($line -match '^\s*bootsequence\s+') {
            $selectedGuid = Parse-GuidFromLine $line
        }
    }

    return [pscustomobject]@{
        DisplayOrder = @($displayOrder.ToArray())
        SelectedGuid = $selectedGuid
    }
}


# LBS-287: strict evidence for restart admission only. Do not reinterpret a
# malformed or ambiguous bootsequence as the ordinary firmware-order case.
function ConvertFrom-RestartFirmwareEvidence {
    param([AllowEmptyString()][string]$Text)
    $guidPattern = '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}'
    $managerCount = 0
    $orderCount = 0
    $sequenceCount = 0
    $timeoutCount = 0
    $defaultCount = 0
    $selected = $null
    $order = New-Object 'System.Collections.Generic.List[string]'
    $field = ''
    # A successful /enum {fwbootmgr} /v contains exactly one manager record.
    # Require its identity, a nonempty canonical displayorder and a numeric
    # timeout (the terminal field in the supported manager record). Reject
    # unexpected fields rather than guessing that a partial record is absent.
    $headingSeen=$false
    $dividerSeen=$false
    foreach ($line in ($Text.TrimStart([char]0xFEFF) -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if (-not $headingSeen) {
            if ($line.Trim() -notin @('Firmware Boot Manager','Firmware-Start-Manager','Firmwarestart-Manager')) { throw 'Unexpected firmware manager heading.' }
            $headingSeen=$true
            continue
        }
        if (-not $dividerSeen) {
            if ($line.Trim() -notmatch '^-{3,}$') { throw 'Firmware manager divider missing.' }
            $dividerSeen=$true
            continue
        }
        if ($line -match '^\s*(identifier|Bezeichner)\s+(\S+)\s*$') {
            $managerCount++
            if ($managerCount -ne 1 -or $Matches[2] -notin @('{fwbootmgr}','{a5a30fa2-3d06-4e9f-b5f4-a01df9d1fcba}')) { throw 'Invalid firmware manager identity.' }
            $field='identifier'
            continue
        }
        if ($managerCount -ne 1) { throw 'Firmware manager identity missing.' }
        if ($line -match ('^\s*displayorder\s+('+$guidPattern+')\s*$')) {
            $orderCount++
            if ($orderCount -ne 1) { throw 'Duplicate firmware displayorder.' }
            $order.Add($Matches[1].ToLowerInvariant())
            $field='displayorder'
            continue
        }
        if ($line -match ('^\s*bootsequence\s+('+$guidPattern+')\s*$')) {
            $sequenceCount++
            if ($sequenceCount -ne 1) { throw 'Duplicate bootsequence.' }
            $selected=$Matches[1].ToLowerInvariant()
            $field='bootsequence'
            continue
        }
        if ($line -match ('^\s+('+$guidPattern+')\s*$')) {
            if ($field -ne 'displayorder') { throw 'Ambiguous firmware GUID continuation.' }
            $guid=$Matches[1].ToLowerInvariant()
            if ($order.Contains($guid)) { throw 'Duplicate firmware displayorder target.' }
            $order.Add($guid)
            continue
        }
        if ($line -match ('^\s*default\s+('+$guidPattern+')\s*$')) {
            $defaultCount++
            if ($defaultCount -ne 1) { throw 'Duplicate firmware default field.' }
            $field='default'
            continue
        }
        if ($line -match '^\s*(timeout|Zeitlimit)\s+\d+\s*$') {
            $timeoutCount++
            if ($timeoutCount -ne 1) { throw 'Duplicate firmware timeout.' }
            $field='timeout'
            continue
        }
        if ($line -match '^\s*(description|Beschreibung)\s+\S.*$') {
            $field='description'
            continue
        }
        throw 'Unsupported, malformed or incomplete firmware manager record.'
    }
    if ($managerCount -ne 1 -or $orderCount -ne 1 -or $order.Count -lt 1 -or $timeoutCount -ne 1 -or $field -ne 'timeout') {
        throw 'Incomplete firmware manager evidence.'
    }
    [pscustomobject]@{SelectedGuid=$selected;DisplayOrder=@($order.ToArray());ExplicitTarget=($sequenceCount -eq 1)}
}
