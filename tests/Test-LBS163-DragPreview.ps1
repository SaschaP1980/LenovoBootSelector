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

    # LBS-172 follow-up: cached raster views reflow while the original nested
    # row HWNDs remain at their fixed slots; the draft order stays untouched.
    foreach ($scale in @(1.0,2.5)) {
        $script:ManageEntryOrder = @('a','b','c','d')
        $script:ManageActiveDragGuid = 'b'
        foreach ($i in 0..3) {
            $rows[$i].Size = [Drawing.Size]::new(390,[int](60*$scale))
            $rows[$i].Location = [Drawing.Point]::new(0,([int](64*$scale)*$i))
        }
        Start-ManageDragReflow -SourceRow $rows[1]
        Check "$scale stable slot snapshot" (@($script:ManageDragLayout).Count -eq 4)
        Check "$scale elevated source row" ($null -ne $script:ManageDragRow -and $null -ne $script:ManageDragShadow)
        $originalLastPoint = $content.PointToScreen([Drawing.Point]::new(30,($rows[3].Top+$rows[3].Height-2)))
        $visualLast = Get-ManageDropDecision -Control $rows[1] -ScreenPoint $originalLastPoint -MovedGuid 'b'
        Check "$scale immutable last destination" ($null -ne $visualLast -and $visualLast.InsertIndex -eq 3)
        Set-ManageDropPreview -Decision $visualLast
        Advance-ManageDragReflow -Progress 0.5
        Check "$scale single-frame final neighbor placement" (
            $script:ManageDragNeighborVisuals['c'].Top -eq [int](64*$scale) -and
            $script:ManageDragNeighborVisuals['d'].Top -eq [int](128*$scale) -and
            $rows[2].Top -eq [int](128*$scale))
        Advance-ManageDragReflow -Progress 1.0
        Check "$scale first neighbor shifts up" (
            $script:ManageDragNeighborVisuals['c'].Top -eq [int](64*$scale) -and
            $rows[2].Top -eq [int](128*$scale))
        Check "$scale second neighbor shifts up" (
            $script:ManageDragNeighborVisuals['d'].Top -eq [int](128*$scale) -and
            $rows[3].Top -eq [int](192*$scale))
        Check "$scale full-height final gap" ($script:ManageDragTargets['b'] -eq [int](192*$scale))
        Check "$scale placeholder geometry matches drop slot" (-not $script:ManageDragPlaceholder.IsDisposed -and $script:ManageDragPlaceholder.Top -eq [int](192*$scale) -and $script:ManageDragPlaceholder.Height -eq [int](60*$scale))
        Check "$scale reflow is draft-only" ((@($script:ManageEntryOrder) -join ',') -eq 'a,b,c,d')
        $stableLast = Get-ManageDropDecision -Control $rows[3] -ScreenPoint $originalLastPoint -MovedGuid 'b'
        Check "$scale preview does not jitter after motion" ($stableLast.InsertIndex -eq $visualLast.InsertIndex)
        $bitmap = New-Object Drawing.Bitmap($rows[3].Width,$rows[3].Height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::Black)
            Paint-ManageDropCue -Row $rows[3] -Graphics $graphics
            Check "$scale old red cue suppressed during reflow" ($bitmap.GetPixel(30,($rows[3].Height-2)).ToArgb() -eq [Drawing.Color]::Black.ToArgb())
        }
        finally { $graphics.Dispose(); $bitmap.Dispose() }
        $firstPoint = $content.PointToScreen([Drawing.Point]::new(30,2))
        $visualFirst = Get-ManageDropDecision -Control $rows[3] -ScreenPoint $firstPoint -MovedGuid 'b'
        Set-ManageDropPreview -Decision $visualFirst
        Advance-ManageDragReflow -Progress 1.0
        Check "$scale top gap is full row" ($script:ManageDragTargets['b'] -eq 0)
        Check "$scale first row makes room" (
            $script:ManageDragNeighborVisuals['a'].Top -eq [int](64*$scale) -and
            $rows[0].Top -eq 0)
        Set-ManageDropPreview -Decision $null
        Advance-ManageDragReflow -Progress 1.0
        Check "$scale invalid/cancel returns neighbors" (
            $script:ManageDragNeighborVisuals['a'].Top -eq 0 -and
            $script:ManageDragNeighborVisuals['c'].Top -eq [int](128*$scale) -and
            $rows[0].Top -eq 0 -and $rows[2].Top -eq [int](128*$scale))
        Check "$scale invalid clears placeholder state" ($null -eq $script:ManageDropPreview -and -not $script:ManageDragPlaceholder.Visible)
        Reset-ManageDragPreview
        Check "$scale cancel restores all row slots" (
            $rows[0].Top -eq 0 -and $rows[1].Top -eq [int](64*$scale) -and
            $rows[2].Top -eq [int](128*$scale) -and $rows[3].Top -eq [int](192*$scale))
        Check "$scale timer shadow and placeholder disposed" ($null -eq $script:ManageDragTimer -and $null -eq $script:ManageDragShadow -and $null -eq $script:ManageDragPlaceholder)

        # Successful drops keep the already previewed arrangement until redraw.
        $script:ManageActiveDragGuid = 'b'
        Start-ManageDragReflow -SourceRow $rows[1]
        $successful = Get-ManageDropDecision -Control $rows[3] -ScreenPoint $originalLastPoint -MovedGuid 'b'
        Set-ManageDropPreview -Decision $successful
        Advance-ManageDragReflow -Progress 1.0
        Reset-ManageDragPreview -KeepPositions
        Check "$scale commit does not snap neighbors back" ($rows[2].Top -eq [int](64*$scale) -and $rows[3].Top -eq [int](128*$scale))
        foreach ($i in 0..3) { $rows[$i].Top = [int](64*$scale)*$i }
    }
}
finally { $form.Dispose(); $script:Popup = $null }
Write-Host "LBS163 TOTAL $script:checks"
