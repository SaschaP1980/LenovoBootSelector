#requires -version 5.1
# LBS-163: native Manage Entries hit testing and transient preview behavior.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\ManageEntries.ps1')
$script:checks = 0
function Check([string]$Name,[bool]$Pass) {
    if (-not $Pass) { throw "LBS163 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS163 $Name"
}
$script:IsManageEntriesMode = $true
$script:ColorAccent = [Drawing.Color]::Red
$script:ManageEntryOrder = @('a','b','c','d')
$script:ManageActiveDragGuid = 'b'
$script:ManageDropPreview = $null
$form = New-Object System.Windows.Forms.Form
try {
    $list = New-Object System.Windows.Forms.Panel
    $list.Name = 'EntryList'
    $list.Size = [Drawing.Size]::new(390,600)
    $content = New-Object System.Windows.Forms.Panel
    $content.Name = 'EntryContent'
    $content.Size = [Drawing.Size]::new(390,600)
    $list.Controls.Add($content)
    $form.Controls.Add($list)
    $script:Popup = $form
    [void]$form.Handle
    foreach ($i in 0..3) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Name = 'BootRow'
        $row.Tag = $script:ManageEntryOrder[$i]
        $row.Size = [Drawing.Size]::new(390,60)
        $row.Location = [Drawing.Point]::new(0,($i*64))
        $content.Controls.Add($row)
        [void]$row.Handle
    }
    $rows = @($content.Controls | Sort-Object Top)
    foreach ($scale in @(1.0,2.5)) {
        foreach ($i in 0..3) {
            $rows[$i].Size = [Drawing.Size]::new(390,[int](60*$scale))
            $rows[$i].Location = [Drawing.Point]::new(0,([int](64*$scale)*$i))
        }
        $first = Get-ManageDropDecision -Control $rows[0] -ScreenPoint ($rows[0].PointToScreen([Drawing.Point]::new(20,2))) -MovedGuid 'b'
        $last = Get-ManageDropDecision -Control $rows[3] -ScreenPoint ($rows[3].PointToScreen([Drawing.Point]::new(20,($rows[3].Height-2)))) -MovedGuid 'b'
        Check "$scale first slot" ($null -ne $first -and $first.InsertIndex -eq 0 -and -not $first.After)
        Check "$scale last slot" ($null -ne $last -and $last.InsertIndex -eq 3 -and $last.After)
        $label = New-Object System.Windows.Forms.Label
        $label.Location = [Drawing.Point]::new(0,0)
        $label.Size = [Drawing.Size]::new(40,20)
        $rows[2].Controls.Add($label)
        $upper = Get-ManageDropDecision -Control $label -ScreenPoint ($rows[2].PointToScreen([Drawing.Point]::new(20,2))) -MovedGuid 'b'
        $lower = Get-ManageDropDecision -Control $label -ScreenPoint ($rows[2].PointToScreen([Drawing.Point]::new(20,($rows[2].Height-2)))) -MovedGuid 'b'
        Check "$scale nested upper no-op" ($null -eq $upper)
        Check "$scale nested lower after" ($null -ne $lower -and $lower.InsertIndex -eq 2 -and $lower.After)
        $rows[2].Controls.Remove($label)
        $label.Dispose()
        Set-ManageDropPreview -Decision $last
        Check "$scale preview no draft mutation" ((@($script:ManageEntryOrder) -join ',') -eq 'a,b,c,d')
        Check "$scale preview visible state" ($script:ManageDropPreview.TargetGuid -eq 'd')
        $bitmap = New-Object Drawing.Bitmap($rows[3].Width,$rows[3].Height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::Black)
            Paint-ManageDropCue -Row $rows[3] -Graphics $graphics
            $cuePixel = $bitmap.GetPixel(30,($rows[3].Height-2))
            Check "$scale cue raster" ($cuePixel.ToArgb() -eq $script:ColorAccent.ToArgb())
        }
        finally { $graphics.Dispose(); $bitmap.Dispose() }
        Set-ManageDropPreview -Decision $first
        Check "$scale moving target" ($script:ManageDropPreview.TargetGuid -eq 'a')
        Set-ManageDropPreview -Decision $null
        Check "$scale invalid clears" ($null -eq $script:ManageDropPreview)
    }
    $outside = Get-ManageDropDecision -Control $rows[0] -ScreenPoint ($rows[0].PointToScreen([Drawing.Point]::new(-4,-4))) -MovedGuid 'b'
    Check 'outside rejected' ($null -eq $outside)
    $own = Get-ManageDropDecision -Control $rows[1] -ScreenPoint ($rows[1].PointToScreen([Drawing.Point]::new(20,2))) -MovedGuid 'b'
    Check 'self rejected' ($null -eq $own)
    $last = Get-ManageDropDecision -Control $rows[3] -ScreenPoint ($rows[3].PointToScreen([Drawing.Point]::new(20,($rows[3].Height-2)))) -MovedGuid 'b'
    Move-ManageEntry -MovedGuid 'b' -TargetGuid $last.TargetGuid -After:$last.After
    Check 'drop equals last preview' ((@($script:ManageEntryOrder) -join ',') -eq 'a,c,d,b')
    Reset-ManageDragPreview
    Check 'cleanup' (-not $script:ManageActiveDragGuid -and $null -eq $script:ManageDropPreview)
}
finally { $form.Dispose(); $script:Popup = $null }
Write-Host "LBS163 TOTAL $script:checks"
