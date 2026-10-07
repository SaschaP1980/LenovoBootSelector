#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')

$script:checks = 0
function Assert-Equal($Expected,$Actual,[string]$Name) {
    if ($Expected -ne $Actual) { throw "FAIL $Name expected=[$Expected] actual=[$Actual]" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Assert-True([bool]$Value,[string]$Name) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}
function Get-LocalizedString {
    param([string]$Key,$Values)
    return $Key
}
function Get-EntryAlias {
    param([string]$Guid,[switch]$UseManageDraft)
    return $script:TestAlias
}
function Get-EntryDisplayTitle {
    param($Entry,[switch]$UseManageDraft)
    if ($script:TestAlias) { return [string]$script:TestAlias }
    return [string]$Entry.Title
}
function Test-ManageEntryHidden {
    param([string]$Guid)
    return (@($script:ManageHiddenEntryGuids) -contains ([string]$Guid).ToLowerInvariant())
}
function Test-MaintenanceBusy { return $false }
function Test-BootTargetDriftDetected { return $false }
function Update-ManageSaveButtonState { }
function Set-ManageEntryAliasDraft { param([string]$Guid,[AllowEmptyString()][string]$Alias) }
function Update-PopupRows { }
function Show-DarkActionTooltip { param($Owner,[string]$Text) }
function Hide-DarkActionTooltip { }
function Commit-ActiveManageAliasEditor { }
function Toggle-ManageEntryVisibility { param([string]$Guid) }
function Get-EntryByGuid { param([string]$Guid) return $null }
function Set-BootNextTarget { param([string]$Guid) }
function Move-ManageEntry { param([string]$MovedGuid,[string]$TargetGuid,[bool]$After) }
function Show-LenovoNoticeDialog { }

$script:ColorRow = [Drawing.Color]::FromArgb(31,31,31)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(64,31,29)
$script:ColorHover = [Drawing.Color]::FromArgb(42,42,42)
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorPrimary = [Drawing.Color]::FromArgb(235,235,235)
$script:ColorSecondary = [Drawing.Color]::FromArgb(175,175,175)
$script:BootTypeToolTip = $null
$script:ManageLastDragUtc = [datetime]::MinValue
$script:ManageHiddenEntryGuids = @()
$script:ManageAliasEditGuid = $null
$script:TestAlias = $null

$guid = '{11111111-2222-3333-4444-555555555555}'.ToLowerInvariant()
$entry = [pscustomobject]@{
    Guid = $guid
    Title = 'USB HDD'
    Subtitle = 'USB boot medium'
    RawDescription = 'USB HDD'
    Symbol = '●'
    Accent = [Drawing.Color]::Orange
    TypeTooltip = ''
}
$handlers = New-BootEntryInteractionHandlers

$script:IsManageEntriesMode = $false
$script:SelectedGuid = $guid
$normal = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight 60 -Handlers $handlers
Assert-Equal 60 $normal.Height 'UI normal boot row keeps base height'
Assert-Equal $script:ColorSelectedRow.ToArgb() $normal.Row.BackColor.ToArgb() 'UI selected boot row keeps selected surface'
$normalCheck = @($normal.Row.Controls | Where-Object { [string]$_.Text -eq '✓' })
Assert-Equal 1 $normalCheck.Count 'UI selected boot row keeps one selection check'
$normalTitle = @($normal.Row.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and [string]$_.Text -eq 'USB HDD' })
Assert-True ($normalTitle.Count -ge 1) 'UI normal boot row keeps display title'
Set-RowHoverState -Control $normal.Row -Hover $true
Assert-Equal $script:ColorSelectedRow.ToArgb() $normal.Row.BackColor.ToArgb() 'UI selected row hover does not replace selected surface'

$script:IsManageEntriesMode = $true
$script:SelectedGuid = $null
$script:ManageHiddenEntryGuids = @($guid)
$script:ManageAliasEditGuid = $null
$script:TestAlias = $null
$hidden = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight 60 -Handlers $handlers
Assert-Equal 60 $hidden.Height 'UI hidden manage row keeps base height'
Assert-Equal ([Drawing.Color]::FromArgb(27,27,27).ToArgb()) $hidden.Row.BackColor.ToArgb() 'UI hidden manage row keeps hidden surface'
$visibility = @($hidden.Row.Controls | Where-Object { $_.Name -eq 'VisibilityGlyph' })
Assert-Equal 1 $visibility.Count 'UI manage row keeps visibility control'
Assert-Equal 'hidden' ([string]$visibility[0].AccessibleName) 'UI hidden manage row exposes hidden accessibility state'
$aliasEdit = @($hidden.Row.Controls | Where-Object { $_.Name -eq 'AliasEditButton' })
Assert-Equal 1 $aliasEdit.Count 'UI manage row keeps alias-edit action'
Set-RowHoverState -Control $hidden.Row -Hover $true
Assert-Equal ([Drawing.Color]::FromArgb(37,37,37).ToArgb()) $hidden.Row.BackColor.ToArgb() 'UI hidden row hover keeps hidden hover surface'
Set-RowHoverState -Control $hidden.Row -Hover $false
Assert-Equal ([Drawing.Color]::FromArgb(27,27,27).ToArgb()) $hidden.Row.BackColor.ToArgb() 'UI hidden row mouse-leave restores hidden surface'

$script:ManageHiddenEntryGuids = @()
$script:ManageAliasEditGuid = $guid
$script:TestAlias = 'My USB'
$editing = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight 60 -Handlers $handlers
Assert-Equal 92 $editing.Height 'UI alias editor expands row height'
$editor = @($editing.Row.Controls.Find('AliasEditor',$true))
Assert-Equal 1 $editor.Count 'UI alias editor renders one textbox'
Assert-Equal 'My USB' ([string]$editor[0].Text) 'UI alias editor preserves draft alias text'
Assert-Equal 1 @($editing.Row.Controls.Find('AliasApplyButton',$true)).Count 'UI alias editor keeps apply action'
Assert-Equal 1 @($editing.Row.Controls.Find('AliasCancelButton',$true)).Count 'UI alias editor keeps cancel action'
Assert-Equal 0 @($editing.Row.Controls.Find('VisibilityGlyph',$true)).Count 'UI alias editor suppresses normal manage visibility control'

$listPanel = New-Object System.Windows.Forms.Panel
$listPanel.Size = New-Object Drawing.Size(390,120)
$contentPanel = New-Object System.Windows.Forms.Panel
$scroll = [pscustomobject]@{ LargeChange=0; SmallChange=0; Maximum=100; Visible=$false; Value=0 }
Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scroll -ContentBottom 200 -BaseRowHeight 60 -RowGap 4
Assert-Equal 200 $contentPanel.Height 'UI scroll layout keeps full content height'
Assert-Equal $true $scroll.Visible 'UI scroll layout shows scrollbar when content exceeds viewport'
Assert-Equal 80 $scroll.Maximum 'UI scroll layout computes maximum from content and viewport'
Assert-Equal 64 $scroll.SmallChange 'UI scroll layout keeps row-sized wheel step'
$scroll.Value = 40
Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scroll -ContentBottom 200 -BaseRowHeight 60 -RowGap 4
Assert-Equal -40 $contentPanel.Top 'UI scroll layout applies scrollbar value to content offset'

Write-Host "UI PRESENTATION TOTAL $script:checks/23"
if ($script:checks -ne 23) { throw "Unexpected UI presentation test count $script:checks" }
