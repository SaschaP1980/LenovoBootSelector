#requires -version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Core\PortablePreferences.ps1')
$script:passed=0
function Assert-True($Value,[string]$Name) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:passed++
    Write-Host "PASS $Name"
}
function Assert-Rejected([string]$Text,[string]$Name) {
    $rejected=$false
    try { [void](ConvertFrom-PortablePreferencesCore $Text) } catch { $rejected=$true }
    Assert-True $rejected $Name
}
$a='{aaaaaaaa-1111-1111-1111-111111111111}'
$b='{22222222-2222-2222-2222-222222222222}'
$c='{33333333-3333-3333-3333-333333333333}'
$d='{44444444-4444-4444-4444-444444444444}'
$e='{55555555-5555-5555-5555-555555555555}'
$s=New-DefaultAppSettingsCore
$s.locale='de-DE';$s.localePreferenceSource='user';$s.defaultGuid=$e
$s.entryOrder=@($a,$d,$c,$b);$s.hiddenEntryGuids=@($a,$d);$s.entryAliases=@{$a='Alpha';$b='Beta';$d='Unavailable'}
$local=@([pscustomobject]@{Guid=$a;Title='A'},[pscustomobject]@{Guid=$b;Title='B'},[pscustomobject]@{Guid=$c;Title='C'})
$json=New-PortablePreferencesCore $s $local
$loaded=ConvertFrom-PortablePreferencesCore $json
Assert-True ($loaded.locale -ceq 'de-DE' -and $loaded.entries.Count -eq 3) 'Export language and discovered entries'
Assert-True (($loaded.entries.guid -join ',') -eq (@($a,$c,$b) -join ',')) 'Export current order including hidden'
Assert-True ($loaded.entries[0].hidden -and $loaded.entries[0].alias -ceq 'Alpha') 'Export hidden alias'
Assert-True ($json -notmatch 'defaultGuid|Unavailable|localePreferenceSource|Title' -and -not $json.Contains($d)) 'Excluded metadata'
$plan=New-PortablePreferencesPlanCore $loaded $s $local
Assert-True (Test-StringSequenceEqual $s.entryOrder $plan.EntryOrder) 'Same installation order roundtrip'
Assert-True (Test-StringSequenceEqual $s.hiddenEntryGuids $plan.HiddenEntryGuids -Sort) 'Same installation visibility roundtrip'
Assert-True (Test-EntryAliasMapsEqual $s.entryAliases $plan.EntryAliases) 'Same installation alias roundtrip'
$import=ConvertFrom-PortablePreferencesCore ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$b+'","alias":"","hidden":true},{"guid":"'+$a+'","alias":"New","hidden":false},{"guid":"'+$e+'","alias":"Alpha","hidden":false}]}')
$plan=New-PortablePreferencesPlanCore $import $s $local
Assert-True (($plan.EntryOrder -join ',') -eq (@($b,$d,$c,$a) -join ',')) 'Reorder matched slots only'
Assert-True ($plan.EntryAliases[$a] -ceq 'New' -and -not $plan.EntryAliases.ContainsKey($b) -and $plan.EntryAliases[$d] -ceq 'Unavailable') 'Explicit alias replace/clear preserve excluded'
Assert-True ($b -in $plan.HiddenEntryGuids -and $a -notin $plan.HiddenEntryGuids -and $d -in $plan.HiddenEntryGuids) 'Explicit visibility changes preserve excluded'
Assert-True (@($plan.Rows | Where-Object Status -eq 'Unmatched').Count -eq 1 -and @($plan.Rows | Where-Object Status -eq 'LocalOnly').Count -eq 1) 'Preview exact matching only'
Assert-True ($plan.UnavailableLocal -contains $d -and $s.defaultGuid -eq $e -and $s.entryAliases[$a] -ceq 'Alpha') 'Pure plan preserves input and legacy default'
$legacy='x'*31
$import.entries[0].alias=$legacy
$plan=New-PortablePreferencesPlanCore $import $s $local
Assert-True ($plan.EntryAliases[$b] -ceq 'Beta' -and $plan.Rows[0].AliasSkipped) 'Different overlength alias skipped'
$s.entryAliases[$b]=$legacy
$plan=New-PortablePreferencesPlanCore $import $s $local
Assert-True ($plan.EntryAliases[$b] -ceq $legacy -and -not $plan.Rows[0].AliasSkipped) 'Unchanged overlength alias preserved'
$empty=ConvertFrom-PortablePreferencesCore '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[]}'
Assert-True ($empty.entries.Count -eq 0) 'Empty entry list valid'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":2,"locale":"en-US","entries":[]}' 'Unsupported version'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","Locale":"de-DE","entries":[]}' 'Case duplicate key'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","\u006cocale":"de-DE","entries":[]}' 'Escaped duplicate key'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[],"defaultGuid":null}' 'Unknown protected key'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"fr-FR","entries":[]}' 'Invalid locale'
Assert-Rejected ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"","hidden":false},{"guid":"'+$a.ToUpperInvariant()+'","alias":"","hidden":false}]}') 'Duplicate normalized identity'
Assert-Rejected ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"","hidden":"false"}]}') 'Reject coerced boolean'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"bad","alias":"","hidden":false}]}' 'Reject malformed identity'
Assert-Rejected ($json+' {}') 'Reject trailing JSON'
Assert-Rejected (' '*262145) 'Reject oversized input'
Assert-Rejected '{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[[[[[[]]]]]]}' 'Reject excessive depth'
Assert-Rejected ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"a\nb","hidden":false}]}') 'Reject control alias'
$date=ConvertFrom-PortablePreferencesCore ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"2026-11-25T12:34:56Z","hidden":false}]}')
Assert-True ($date.entries[0].alias -is [string] -and $date.entries[0].alias -ceq '2026-11-25T12:34:56Z') 'Literal date-like alias preserved'
$escape=ConvertFrom-PortablePreferencesCore ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"A\u00df \"B\" \\ C","hidden":false}]}')
Assert-True ($escape.entries[0].alias -ceq 'Aß "B" \ C') 'Literal escaped Unicode and punctuation'
Assert-Rejected ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"en-US","entries":[{"guid":"'+$a+'","alias":"\ud800","hidden":false}]}') 'Reject unpaired surrogate'
$s2=New-DefaultAppSettingsCore
$plan=New-PortablePreferencesPlanCore $empty $s2 $local
Assert-True ($plan.EntryOrder.Count -eq 0 -and $plan.EntryAliases.Count -eq 0) 'No-match import retains implicit local order'
Write-Host "LBS180 CORE TOTAL $script:passed/31"
if ($script:passed -ne 31) { exit 1 }
