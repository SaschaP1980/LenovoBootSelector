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
