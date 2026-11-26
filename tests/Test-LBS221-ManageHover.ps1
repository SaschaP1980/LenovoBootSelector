#requires -version 5.1
# LBS-221: native WinForms hover events and tooltip routing; no firmware/settings or physical input.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
function Assert-Lbs221([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS221 FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS221 $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:TestLocale -Values $Values }
function Show-DarkActionTooltip { param($Owner,[string]$Text) $script:TipOwner = $Owner; $script:TipText = $Text; $script:ShowCalls++ }
function Hide-DarkActionTooltip { $script:TipOwner = $null; $script:TipText = ''; $script:HideCalls++ }
function Test-ManageEntryHidden { param([string]$Guid) return [bool]$script:Hidden }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ CanManageEntries=$true } }
function Toggle-ManageEntryVisibility { param([string]$Guid) $script:Mutations++ }
function Update-PopupRows { param([string]$Reason) $script:Mutations++ }
function Save-AppSettings { $script:Mutations++ }
function Invoke-NormalBootTargetSelection { param([string]$Guid) $script:Mutations++ }
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorPrimary = [Drawing.Color]::FromArgb(252,252,252)
$script:ColorRow = [Drawing.Color]::FromArgb(32,32,32)
$script:ColorHover = [Drawing.Color]::FromArgb(42,42,42)
$script:IsManageEntriesMode = $true
$script:ManageLastDragUtc = [datetime]::MinValue
$script:Mutations = 0
$flags = [Reflection.BindingFlags]'Instance,NonPublic'
$enter = [Windows.Forms.Control].GetMethod('OnMouseEnter',$flags)
$leave = [Windows.Forms.Control].GetMethod('OnMouseLeave',$flags)
$down = [Windows.Forms.Control].GetMethod('OnMouseDown',$flags)
$click = [Windows.Forms.Control].GetMethod('OnClick',$flags)
$source = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
$dragStart = $source.IndexOf('# LBS-221: close action help before capturing the row or entering OLE drag.')
$capture = $source.IndexOf('Start-ManageDragReflow -SourceRow $sourceRow',$dragStart)
$hide = $source.IndexOf('Hide-DarkActionTooltip',$dragStart)
Assert-Lbs221 'Shared drag threshold hides help before raster capture and OLE' ($dragStart -ge 0 -and $hide -gt $dragStart -and $capture -gt $hide)
$listSource = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryList.ps1'))
Assert-Lbs221 'Localized grip help participates in live row localization identity' ($listSource.Contains("'Manage.ReorderHint'"))
foreach ($locale in @('en-US','de-DE')) {
    $script:TestLocale = $locale
    $expectedHint = if ($locale -eq 'en-US') { 'Drag to change the order' } else { 'Ziehen, um die Reihenfolge zu ' + [char]0x00E4 + 'ndern' }
    foreach ($factor in @(1.0,2.5)) {
        foreach ($hidden in @($false,$true)) {
            $script:Hidden = $hidden
            $script:ManageActiveDragGuid = $null
            $script:ManageDragGuid = $null
            $script:ManageAliasEditGuid = $null
            $script:TipOwner = $null; $script:TipText = ''; $script:ShowCalls = 0; $script:HideCalls = 0
            $entry = [pscustomobject]@{ Guid='12345678-1234-4234-8234-123456789abc' }
            $row = New-Object Windows.Forms.Panel
            $row.Name='BootRow'; $row.Tag=$entry.Guid
            $row.Size=[Drawing.Size]::new(390,60); $row.BackColor=$script:ColorRow
            try {
                $children = @()
                foreach ($name in @('Marker','BootTypeIcon','BootTitleLabel','BootSubtitleLabel')) {
                    $label=New-Object Windows.Forms.Label
                    $label.Name=$name; $label.Tag=$entry.Guid
                    $label.Size=[Drawing.Size]::new(20,20); $row.Controls.Add($label)
                    $children += $label
                }
                $controls = @(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden $hidden -Marker $children[0] -Icon $children[1] -Title $children[2] -Subtitle $children[3])
                Connect-BootEntryRowInteractions -RowControls $controls -Handlers (New-BootEntryInteractionHandlers)
                [void](Set-PopupBootRowDpiLayout -Row $row -Scale $factor -Y 0)
                $eye = $row.Controls['VisibilityGlyph']; $grip = $row.Controls['ManageReorderGrip']; $pencil = $row.Controls['AliasEditButton']
                $prefix = "$locale $factor hidden=$hidden"
                $eyeIdle = if ($hidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
                $eyeHover = if ([Windows.Forms.SystemInformation]::HighContrast) { $eyeIdle } else { [Drawing.Color]::FromArgb(255,110,102) }
                $gripHover = if ([Windows.Forms.SystemInformation]::HighContrast) { [Drawing.Color]::FromArgb(145,145,145) } else { [Drawing.Color]::FromArgb(255,110,102) }
                $stateName = if ($hidden) { 'hidden' } else { 'visible' }
                $titleIdle = if ($hidden) { [Drawing.Color]::FromArgb(175,175,175) } else { $script:ColorPrimary }
                Assert-Lbs221 "$prefix original action dimensions" ($eye.Width -eq [int][Math]::Round(32*$factor) -and $grip.Width -eq [int][Math]::Round(26*$factor) -and $pencil.Width -eq [int][Math]::Round(25*$factor) -and $row.Height -eq [int][Math]::Round(60*$factor))
                Assert-Lbs221 "$prefix idle ink unchanged" ($eye.ForeColor -eq $eyeIdle -and $grip.ForeColor -eq [Drawing.Color]::FromArgb(145,145,145))
                [void]$enter.Invoke($eye,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix eye hover preserves visibility semantics" ($eye.ForeColor -eq $eyeHover -and $eye.AccessibleName -eq $stateName -and $script:TipOwner -eq $eye)
                [void]$leave.Invoke($eye,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix eye leave restores idle ink and closes help" ($eye.ForeColor -eq $eyeIdle -and $children[2].ForeColor -eq $titleIdle -and $null -eq $script:TipOwner)
                [void]$enter.Invoke($grip,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix grip hover brightens and routes localized dark help" ($grip.ForeColor -eq $gripHover -and $script:TipOwner -eq $grip -and $script:TipText -eq $expectedHint)
                [void]$down.Invoke($grip,@([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,5,5,0)))
                Assert-Lbs221 "$prefix grip down hides help without changing drag admission" ($null -eq $script:TipOwner -and $script:ManageDragGuid -eq $entry.Guid)
                [void]$click.Invoke($grip,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix stationary grip click remains no-op" ($script:Mutations -eq 0)
                [void]$leave.Invoke($grip,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix grip leave restores neutral ink" ($grip.ForeColor -eq [Drawing.Color]::FromArgb(145,145,145) -and $null -eq $script:TipOwner)
                $script:ManageActiveDragGuid = $entry.Guid
                $before = $script:ShowCalls
                foreach ($control in @($grip,$eye,$pencil)) { [void]$enter.Invoke($control,@([EventArgs]::Empty)) }
                Assert-Lbs221 "$prefix active drag suppresses all three action hints" ($script:ShowCalls -eq $before -and $null -eq $script:TipOwner -and $eye.ForeColor -eq $eyeIdle -and $grip.ForeColor -eq [Drawing.Color]::FromArgb(145,145,145))
                $script:ManageActiveDragGuid = $null
                [void]$enter.Invoke($grip,@([EventArgs]::Empty))
                Assert-Lbs221 "$prefix hover help recovers after drag" ($script:TipOwner -eq $grip -and $script:TipText -eq $expectedHint)
                [void]$leave.Invoke($grip,@([EventArgs]::Empty))
            } finally { $row.Dispose(); $script:ManageActiveDragGuid=$null; $script:ManageDragGuid=$null }
        }
    }
}
Assert-Lbs221 'No draft/settings/boot mutation in hover fixture' ($script:Mutations -eq 0)
Write-Host "LBS221 MANAGE HOVER TOTAL $script:checks/83"
if ($script:checks -ne 83) { throw "Expected 83 native hover assertions, got $script:checks" }
