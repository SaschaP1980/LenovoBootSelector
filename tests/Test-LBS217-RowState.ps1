#requires -version 5.1
# LBS-217: native WinForms normal-row selection-state semantics at two locales and synthetic DPI scales.
# Does not launch product, modify settings, call firmware, create tasks, or inject physical input.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\BootNextSelectionState.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
$script:MutationCalls = 0
function Assert-Lbs217([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS217 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS217 $Name"
}
function Get-LocalizedString {
    param([string]$Key,$Values)
    return (Get-LocalizedStringCore -Key $Key -Locale $script:TestLocale -Values $Values)
}
function Get-EntryAlias { param([string]$Guid,[switch]$UseManageDraft) return '' }
function Get-EntryDisplayTitle { param($Entry,[switch]$UseManageDraft) return [string]$Entry.Title }
function Test-ManageEntryHidden { param([string]$Guid) return $false }
function Get-CurrentSystemFunctionsCapabilities {
    return [pscustomobject]@{ CanSetBootNext=$false; CanManageEntries=$false }
}
function Start-BootNextSelection { param([string]$Guid) $script:MutationCalls++ }
function Save-AppSettings { $script:MutationCalls++ }
function Restart-Windows { $script:MutationCalls++ }
$script:ColorRow = [Drawing.Color]::FromArgb(31,31,31)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(64,31,29)
$script:ColorHover = [Drawing.Color]::FromArgb(42,42,42)
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorPrimary = [Drawing.Color]::FromArgb(235,235,235)
$script:ColorSecondary = [Drawing.Color]::FromArgb(175,175,175)
$script:ColorWarning = [Drawing.Color]::FromArgb(241,174,63)
$script:IsManageEntriesMode = $false
$script:ManageAliasEditGuid = $null
$script:BootTypeToolTip = New-Object Windows.Forms.ToolTip
$entry = [pscustomobject]@{
    Guid = '12345678-1234-4234-8234-123456789abc'
    Title = 'NVMe SSD 1'
    Subtitle = 'Long model identification remains intact'
    RawDescription = 'NVMe0'
    Symbol = '*'
    Accent = [Drawing.Color]::Blue
    TypeTooltip = 'Internal SSD'
}
$handlers = New-BootEntryInteractionHandlers
$source = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
$localizedSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryList.ps1'))
Assert-Lbs217 'Canonical normal-row status glyph exposes an explicit accessible name' (
    $source.Contains('$check.Name = ''BootSelectionStatusGlyph''') -and
    $source.Contains('$check.AccessibleName = [string]$statusHint'))
Assert-Lbs217 'Row localization fingerprint includes both per-state hint keys' (
    $localizedSource.Contains("'BootNext.RowPendingHint'") -and
    $localizedSource.Contains("'BootNext.RowSelectedHint'"))
try {
    foreach ($locale in @('en-US','de-DE')) {
        $script:TestLocale = $locale
        foreach ($factor in @(1.0,2.5)) {
            $dpi = [int][Math]::Round(96*$factor)
            foreach ($status in @('selected','pending','idle')) {
                $script:SelectedGuid = if ($status -eq 'idle') { '' } else { $entry.Guid }
                $script:BootNextPendingGuid = if ($status -eq 'pending') { $entry.Guid } else { '' }
                $expectedGlyph = if ($status -eq 'pending') { [string][char]0x2026 } elseif ($status -eq 'selected') { [string][char]0x2713 } else { '' }
                $key = if ($status -eq 'pending') { 'BootNext.RowPendingHint' } elseif ($status -eq 'selected') { 'BootNext.RowSelectedHint' } else { '' }
                $expectedHint = if ($key) { Get-LocalizedString -Key $key } else { '' }
                $expectedSubtitle = if ($status -eq 'pending') { Get-LocalizedString -Key 'BootNext.SelectionPending' } else { [string]$entry.Subtitle }
                $result = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight 60 -Handlers $handlers
                $row = $result.Row
                try {
                    [void](Set-PopupBootRowDpiLayout -Row $row -Scale $factor -Y 0)
                    $glyph = $row.Controls['BootSelectionStatusGlyph']
                    $prefix = "$locale $dpi DPI $status"
                    Assert-Lbs217 "$prefix original visual glyph and distinct control identity" (
                        $null -ne $glyph -and $glyph.Text -eq $expectedGlyph -and
                        $glyph.Name -eq 'BootSelectionStatusGlyph')
                    Assert-Lbs217 "$prefix localized hint resolves without fallback" (
                        ($status -eq 'idle' -and $expectedHint -eq '') -or
                        ($status -ne 'idle' -and -not [string]::IsNullOrWhiteSpace($expectedHint) -and
                            $expectedHint -ne $key -and
                            ($status -ne 'pending' -or $expectedHint -match 'not|noch')))
                    Assert-Lbs217 "$prefix state glyph has non-color accessible semantics" (
                        [string]$glyph.AccessibleName -eq $expectedHint -and
                        [string]$glyph.AccessibleDescription -eq $expectedHint -and
                        ($status -eq 'idle' -or $glyph.AccessibleRole -eq [Windows.Forms.AccessibleRole]::StaticText))
                    Assert-Lbs217 "$prefix state hint is attached to native ToolTip" (
                        [string]$script:BootTypeToolTip.GetToolTip($glyph) -eq $expectedHint)
                    Assert-Lbs217 "$prefix status glyph and row physical bounds remain stable" (
                        $row.Width -eq [int][Math]::Round(390*$factor) -and
                        $row.Height -eq [int][Math]::Round(60*$factor) -and
                        $glyph.Width -eq [int][Math]::Round(24*$factor) -and
                        $glyph.Height -eq [int][Math]::Round(34*$factor))
                    Assert-Lbs217 "$prefix target title and state subtitle preserve keyboard row identity" (
                        $row.AccessibleRole -eq [Windows.Forms.AccessibleRole]::PushButton -and
                        $row.AccessibleName -eq $entry.Title -and
                        $row.AccessibleDescription -eq $expectedSubtitle -and
                        $row.Controls['BootTitleLabel'].Text -eq $entry.Title -and
                        $row.Controls['BootSubtitleLabel'].Text -eq $expectedSubtitle)
                }
                finally { $row.Dispose() }
            }
        }
    }
    Assert-Lbs217 'Read-only fixture never reaches a boot, restart or settings mutation' (
        $script:MutationCalls -eq 0)
}
finally { $script:BootTypeToolTip.Dispose() }
Write-Host "LBS217 ROW STATE TOTAL $script:checks/75"
if ($script:checks -ne 75) { throw "Expected 75 native state-semantic assertions, got $script:checks" }
