#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupPosition.ps1')

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
$script:TestCapabilities = [pscustomobject]@{
    CanManageEntries = $true
    CanSetBootNext = $true
}
function Get-CurrentSystemFunctionsCapabilities { return $script:TestCapabilities }
function Update-ManageSaveButtonState { }
function Set-ManageEntryAliasDraft { param([string]$Guid,[AllowEmptyString()][string]$Alias) }
function Update-PopupRows { }
function Show-DarkActionTooltip { param($Owner,[string]$Text) }
function Hide-DarkActionTooltip { }
function Commit-ActiveManageAliasEditor { }
function Toggle-ManageEntryVisibility { param([string]$Guid) }
function Get-EntryByGuid { param([string]$Guid) return $null }
$script:BootNextCalls = 0
function Set-BootNextTarget { param([string]$Guid) $script:BootNextCalls++ }
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
& $handlers.Click $normal.Row $null
Assert-Equal 1 $script:BootNextCalls 'UI boot row consumes enabled canonical BootNext capability'
$script:TestCapabilities.CanSetBootNext = $false
& $handlers.Click $normal.Row $null
Assert-Equal 1 $script:BootNextCalls 'UI boot row blocks interaction when canonical BootNext capability is disabled'
$script:TestCapabilities.CanSetBootNext = $true

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


# LBS-132: native PS5.1 geometry assertions, no Explorer or privileged operation.
$display = [Drawing.Rectangle]::new(0, 0, 1920, 1080)
$work = [Drawing.Rectangle]::new(0, 0, 1920, 1040)
$size = [Drawing.Size]::new(390, 672)
$icon = [Drawing.Rectangle]::new(1650, 1008, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $icon -PopupSize $size -HasAnchor
Assert-Equal 1467 $placed.X 'Popup centers horizontally above the actual icon'
Assert-Equal 328 $placed.Y 'Popup uses icon top for bottom taskbar placement'
$icon = [Drawing.Rectangle]::new(1500, 1008, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $icon -PopupSize $size -HasAnchor
Assert-Equal 1317 $placed.X 'Reordered icon changes horizontal popup position'
$icon = [Drawing.Rectangle]::new(1900, 1008, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $icon -PopupSize $size -HasAnchor
Assert-Equal 1530 $placed.X 'Popup clamps to right screen edge'
$icon = [Drawing.Rectangle]::new(0, 1008, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $icon -PopupSize $size -HasAnchor
Assert-Equal 0 $placed.X 'Popup clamps to left screen edge'
$icon = [Drawing.Rectangle]::new(850, 800, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $icon -PopupSize $size -HasAnchor
Assert-Equal 667 $placed.X 'Overflow flyout icon owns horizontal anchor'
Assert-Equal 120 $placed.Y 'Overflow flyout icon owns vertical anchor'
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -PopupSize $size
Assert-Equal 1522 $placed.X 'Non-pointer fallback has deterministic horizontal placement'
Assert-Equal 360 $placed.Y 'Non-pointer fallback has deterministic vertical placement'
$topWork = [Drawing.Rectangle]::new(0, 40, 1920, 1040)
$topIcon = [Drawing.Rectangle]::new(850, 45, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $topWork -DisplayBounds $display -AnchorRect $topIcon -PopupSize $size -HasAnchor
Assert-Equal 77 $placed.Y 'Top-docked taskbar places popup below the icon'
$rightWork = [Drawing.Rectangle]::new(0, 0, 1860, 1080)
$rightIcon = [Drawing.Rectangle]::new(1870, 500, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $rightWork -DisplayBounds $display -AnchorRect $rightIcon -PopupSize $size -HasAnchor
Assert-Equal 1472 $placed.X 'Right-docked taskbar places popup to icon left'
Assert-Equal 176 $placed.Y 'Side-docked taskbar aligns popup vertically'
$leftWork = [Drawing.Rectangle]::new(55, 0, 1865, 1080)
$leftIcon = [Drawing.Rectangle]::new(12, 500, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $leftWork -DisplayBounds $display -AnchorRect $leftIcon -PopupSize $size -HasAnchor
Assert-Equal 55 $placed.X 'Left-docked taskbar clamps popup to working area'
$negativeDisplay = [Drawing.Rectangle]::new(-1600, -200, 1600, 900)
$negativeWork = [Drawing.Rectangle]::new(-1600, -200, 1600, 860)
$negativeIcon = [Drawing.Rectangle]::new(-300, 600, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $negativeWork -DisplayBounds $negativeDisplay -AnchorRect $negativeIcon -PopupSize $size -HasAnchor
Assert-Equal -483 $placed.X 'Negative virtual-screen X centers on second monitor'
Assert-Equal -80 $placed.Y 'Negative virtual-screen Y remains within working area'
$scaledSize = [Drawing.Size]::new(480, 800)
$scaledIcon = [Drawing.Rectangle]::new(950, 1000, 40, 40)
$placed = Get-PopupLocationFromAnchor -WorkingArea $work -DisplayBounds $display -AnchorRect $scaledIcon -PopupSize $scaledSize -HasAnchor
Assert-Equal 730 $placed.X 'Scaled form width is used rather than hardcoded 390'
Assert-Equal 192 $placed.Y 'Scaled form height is used rather than hardcoded 672'
$autoHide = [Drawing.Rectangle]::new(0, 0, 1920, 1080)
$autoIcon = [Drawing.Rectangle]::new(1600, 1040, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $autoHide -DisplayBounds $autoHide -AnchorRect $autoIcon -PopupSize $size -HasAnchor
Assert-Equal 360 $placed.Y 'Auto-hidden bottom taskbar prefers placement above icon'
$shortWork = [Drawing.Rectangle]::new(0, 0, 850, 700)
$shortIcon = [Drawing.Rectangle]::new(15, 660, 24, 24)
$placed = Get-PopupLocationFromAnchor -WorkingArea $shortWork -DisplayBounds $shortWork -AnchorRect $shortIcon -PopupSize $size -HasAnchor
Assert-Equal 28 $placed.Y 'Tall popup clamps inside short usable work area'
$placed = Get-PopupLocationFromAnchor -WorkingArea $negativeWork -DisplayBounds $negativeDisplay -PopupSize $size
Assert-Equal -398 $placed.X 'Negative-monitor fallback clamps correctly'
Assert-Equal -20 $placed.Y 'Negative-monitor fallback places above usable bottom'

Write-Host "UI PRESENTATION TOTAL $script:checks/46"
if ($script:checks -ne 46) { throw "Unexpected UI presentation test count $script:checks" }
