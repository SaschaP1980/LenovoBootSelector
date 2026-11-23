#requires -version 5.1
# LBS-172: isolated native WinForms drag paint-surface, reflow and draft lifecycle.
# No firmware I/O and no settings writes. Physical Lenovo visual acceptance is separate.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\ManageEntries.ps1')
$script:checks = 0
function Assert-Lbs172([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "LBS172 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS172 $Name"
}
# Establish a focused early RED on the unfixed source before creating HWNDs.
# Later checks verify painted child raster pixels, reflow and cleanup.
Assert-Lbs172 "drag raster constructor exists before native painting" (
    $null -ne (Get-Command New-ManageDragRowRaster -CommandType Function -ErrorAction SilentlyContinue))
$script:IsManageEntriesMode = $true
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ManageLastDragUtc = [datetime]::MinValue
$script:ManageActiveDragGuid = $null
$script:ManageDropPreview = $null
$script:PopupRowsRefreshPending = $false
$script:PopupRowsViewportPending = $false
$script:TestSettingsWrites = 0
function Save-AppSettings { $script:TestSettingsWrites++ }
$script:Popup = $null

function New-Lbs172Row([string]$Guid,[int]$Y,[double]$Scale) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Name = 'BootRow'
    $row.Tag = $Guid
    $row.Size = [Drawing.Size]::new([int][Math]::Round(390*$Scale),[int][Math]::Round(60*$Scale))
    $row.Location = [Drawing.Point]::new(0,$Y)
    $row.BackColor = [Drawing.Color]::FromArgb(36,36,39)
    $title = New-Object System.Windows.Forms.Label
    $title.Name = 'BootTitleLabel'
    $title.Text = "Windows: $Guid"
    $title.ForeColor = [Drawing.Color]::White
    $title.BackColor = [Drawing.Color]::Transparent
    $title.Font = New-Object Drawing.Font('Segoe UI',10.0,[Drawing.FontStyle]::Bold)
    $title.Location = [Drawing.Point]::new([int][Math]::Round(58*$Scale),[int][Math]::Round(6*$Scale))
    $title.Size = [Drawing.Size]::new([int][Math]::Round(220*$Scale),[int][Math]::Round(23*$Scale))
    $row.Controls.Add($title)
    $pencil = New-Object System.Windows.Forms.Label
    $pencil.Name = 'AliasEditButton'
    $pencil.Text = [string][char]0x270E
    $pencil.Font = New-Object Drawing.Font('Segoe UI Symbol',14.0,[Drawing.FontStyle]::Regular)
    $pencil.ForeColor = [Drawing.Color]::FromArgb(220,220,220)
    $pencil.BackColor = [Drawing.Color]::Transparent
    $pencil.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $pencil.Location = [Drawing.Point]::new([int][Math]::Round(321*$Scale),[int][Math]::Round(12*$Scale))
    $pencil.Size = [Drawing.Size]::new([int][Math]::Round(25*$Scale),[int][Math]::Round(34*$Scale))
    $row.Controls.Add($pencil)
    # Native child glyph labels provide deterministic raster ink without
    # PowerShell Paint callbacks in this isolated STA fixture.
    $eye = New-Object System.Windows.Forms.Label
    $eye.Name = 'VisibilityGlyph'
    $eye.Text = [string][char]0x25CF
    $eye.Font = New-Object Drawing.Font('Segoe UI Symbol',14.0,[Drawing.FontStyle]::Regular)
    $eye.ForeColor = [Drawing.Color]::White
    $eye.BackColor = [Drawing.Color]::Transparent
    $eye.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $eye.Location = [Drawing.Point]::new([int][Math]::Round(286*$Scale),[int][Math]::Round(12*$Scale))
    $eye.Size = [Drawing.Size]::new([int][Math]::Round(32*$Scale),[int][Math]::Round(34*$Scale))
    $row.Controls.Add($eye)
    $grip = New-Object System.Windows.Forms.Label
    $grip.Text = [string][char]0x2261
    $grip.Font = New-Object Drawing.Font('Segoe UI Symbol',14.0,[Drawing.FontStyle]::Regular)
    $grip.ForeColor = [Drawing.Color]::White
    $grip.BackColor = [Drawing.Color]::Transparent
    $grip.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $grip.Name = 'ManageReorderGrip'
    $grip.Location = [Drawing.Point]::new([int][Math]::Round(350*$Scale),[int][Math]::Round(12*$Scale))
    $grip.Size = [Drawing.Size]::new([int][Math]::Round(26*$Scale),[int][Math]::Round(34*$Scale))
    $row.Controls.Add($grip)
    return $row
}

function Test-Lbs172VisibleInk($Bitmap,[Drawing.Rectangle]$Bounds) {
    if (-not $Bitmap) { return $false }
    $right = [Math]::Min([int]$Bitmap.Width,$Bounds.Right)
    $bottom = [Math]::Min([int]$Bitmap.Height,$Bounds.Bottom)
    for ($y = [Math]::Max(0,$Bounds.Top); $y -lt $bottom; $y++) {
        for ($x = [Math]::Max(0,$Bounds.Left); $x -lt $right; $x++) {
            $pixel = $Bitmap.GetPixel($x,$y)
            if ($pixel.R -gt 150 -and $pixel.G -gt 150 -and $pixel.B -gt 150) { return $true }
        }
    }
    return $false
}

# Exercise the physical-size 250% case before 100% when establishing RED.
foreach ($scale in @(2.5,1.0)) {
    $script:ManageEntryOrder = @('a','b','c','d')
    $script:ManageActiveDragGuid = 'b'
    $form = New-Object System.Windows.Forms.Form
    $form.ClientSize = [Drawing.Size]::new([int][Math]::Round(390*$scale),[int][Math]::Round(670*$scale))
    $list = New-Object System.Windows.Forms.Panel
    $list.Name = 'EntryList'
    $list.Size = $form.ClientSize
    $content = New-Object System.Windows.Forms.Panel
    $content.Name = 'EntryContent'
    $content.Size = $list.Size
    $content.AllowDrop = $true
    $list.Controls.Add($content)
    $form.Controls.Add($list)
    $script:Popup = $form
    [void]$form.Handle
    $rows = @()
    for ($i = 0; $i -lt 4; $i++) {
        $row = New-Lbs172Row -Guid $script:ManageEntryOrder[$i] -Y ([int][Math]::Round(64*$scale)*$i) -Scale $scale
        $content.Controls.Add($row)
        [void]$row.Handle
        foreach ($child in $row.Controls) { [void]$child.Handle }
        $rows += $row
    }
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    $source = $rows[1]
    $pencilBefore = $source.Controls['AliasEditButton']
    $eyeBefore = $source.Controls['VisibilityGlyph']
    $gripBefore = $source.Controls['ManageReorderGrip']
    $sourceTop = $source.Top
    try {
        Start-ManageDragReflow -SourceRow $source
        Assert-Lbs172 "$scale stable row-slot snapshot" (@($script:ManageDragLayout).Count -eq 4)
        Assert-Lbs172 "$scale native snapshot drag visual exists" (
            $script:ManageDragGhost -is [System.Windows.Forms.PictureBox] -and
            $null -ne $script:ManageDragGhost.Image)
        Assert-Lbs172 "$scale bitmap contains full row" ($script:ManageDragGhost.Image.Width -eq $source.Width -and $script:ManageDragGhost.Image.Height -eq $source.Height)
        Assert-Lbs172 "$scale source remains visible until OLE starts" ($source.Visible -and -not $script:ManageDragGhost.Visible)
        Assert-Lbs172 "$scale 14pt pencil is unchanged" ([Math]::Abs($pencilBefore.Font.SizeInPoints-14.0) -lt 0.05)
        Assert-Lbs172 "$scale pencil and eye/grip identities intact" (
            [object]::ReferenceEquals($pencilBefore,$source.Controls['AliasEditButton']) -and
            [object]::ReferenceEquals($eyeBefore,$source.Controls['VisibilityGlyph']) -and
            [object]::ReferenceEquals($gripBefore,$source.Controls['ManageReorderGrip']))
        Assert-Lbs172 "$scale image is a single control (no alias child)" ($script:ManageDragGhost.Controls.Count -eq 0)
        $hasPencilInk = $false
        $bounds = $pencilBefore.Bounds
        $captured = $script:ManageDragGhost.Image
        for ($py = $bounds.Top; $py -lt $bounds.Bottom -and -not $hasPencilInk; $py++) {
            for ($px = $bounds.Left; $px -lt $bounds.Right; $px++) {
                $pixel = $captured.GetPixel($px,$py)
                if ($pixel.R -gt 105 -and $pixel.G -gt 105 -and $pixel.B -gt 105) {
                    $hasPencilInk = $true
                    break
                }
            }
        }
        Assert-Lbs172 "$scale frozen bitmap captures visible pencil pixels" $hasPencilInk
        Assert-Lbs172 "$scale image surface initialized once" ($script:ManageDragCaptureCount -eq 1)
        Assert-Lbs172 "$scale original source remains at immutable slot" ($source.Top -eq $sourceTop)
        Assert-Lbs172 "$scale no extra logical BootRow introduced" (@($content.Controls | Where-Object { $_.Name -eq 'BootRow' }).Count -eq 4)
        $image = $script:ManageDragGhost.Image
        $screen = $content.PointToScreen([Drawing.Point]::new(20,([int][Math]::Round(120*$scale))))
        Set-ManageDragFloatLocation -ScreenPoint $screen -ActivateVisual
        Assert-Lbs172 "$scale activate freezes real source" (-not $source.Visible -and $source.Top -eq $sourceTop)
        $neighbors = @($rows | Where-Object { -not [object]::ReferenceEquals($_,$source) })
        $originalNeighborTops = @{}
        $originalNeighborHandles = @{}
        foreach ($neighbor in $neighbors) {
            $originalNeighborTops[[string]$neighbor.Tag] = [int]$neighbor.Top
            $originalNeighborHandles[[string]$neighbor.Tag] = $neighbor.Handle
        }
        $flatImages = if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
            @($script:ManageDragNeighborVisuals.Values)
        } else { @() }
        Assert-Lbs172 "$scale all neighbor rows have flat raster pictures during drag" (
            $flatImages.Count -eq 3 -and
            @($flatImages | Where-Object { $_ -is [System.Windows.Forms.PictureBox] -and $null -ne $_.Image }).Count -eq 3)
        Assert-Lbs172 "$scale native multi-child neighbor HWNDs are parked" (
            @($neighbors | Where-Object { $_.Visible }).Count -eq 0)
        $allGlyphs = ($flatImages.Count -eq 3)
        if ($allGlyphs) {
            foreach ($neighbor in $neighbors) {
                $pic = $script:ManageDragNeighborVisuals[[string]$neighbor.Tag]
                if (-not $pic -or -not (Test-Lbs172VisibleInk -Bitmap $pic.Image -Bounds $neighbor.Controls['BootTitleLabel'].Bounds) -or
                    -not (Test-Lbs172VisibleInk -Bitmap $pic.Image -Bounds $neighbor.Controls['AliasEditButton'].Bounds) -or
                    -not (Test-Lbs172VisibleInk -Bitmap $pic.Image -Bounds $neighbor.Controls['VisibilityGlyph'].Bounds) -or
                    -not (Test-Lbs172VisibleInk -Bitmap $pic.Image -Bounds $neighbor.Controls['ManageReorderGrip'].Bounds)) {
                    $allGlyphs = $false
                    break
                }
            }
        }
        Assert-Lbs172 "$scale each cached neighbor raster includes complete text and eye pencil grip ink" $allGlyphs
        Assert-Lbs172 "$scale floating image becomes visible" ($script:ManageDragGhost.Visible)
        Assert-Lbs172 "$scale single drag image stays same object" ([object]::ReferenceEquals($image,$script:ManageDragGhost.Image))
        Assert-Lbs172 "$scale image follows intended pointer position" ($script:ManageDragGhost.Top -eq $content.PointToClient($screen).Y-$script:ManageDragGrabY)
        Assert-Lbs172 "$scale shadow is a narrow bottom edge behind the image" (
            $null -ne $script:ManageDragShadow -and
            $script:ManageDragShadow.Height -lt ($script:ManageDragGhost.Height/4) -and
            $script:ManageDragShadow.Top -ge ($script:ManageDragGhost.Top+$script:ManageDragGhost.Height-$script:ManageDragShadow.Height))

        $lastPoint = $content.PointToScreen([Drawing.Point]::new(24,([int][Math]::Round(64*$scale)*3+$rows[3].Height-2)))
        $firstPoint = $content.PointToScreen([Drawing.Point]::new(24,2))
        $last = Get-ManageDropDecision -Control $source -ScreenPoint $lastPoint -MovedGuid 'b'
        $first = Get-ManageDropDecision -Control $source -ScreenPoint $firstPoint -MovedGuid 'b'
        Assert-Lbs172 "$scale immutable decisions keep candidate positions" ($null -ne $last -and $last.InsertIndex -eq 3 -and $null -ne $first -and $first.InsertIndex -eq 0)
        $content.Top = -[int][Math]::Round(20*$scale)
        $scrolled = $content.PointToScreen([Drawing.Point]::new(24,([int][Math]::Round(64*$scale)*3+$rows[3].Height-2)))
        $scrolledDecision = Get-ManageDropDecision -Control $source -ScreenPoint $scrolled -MovedGuid 'b'
        Assert-Lbs172 "$scale scroll offset keeps immutable target identity" ($scrolledDecision.InsertIndex -eq $last.InsertIndex -and $scrolledDecision.TargetGuid -eq $last.TargetGuid)
        $content.Top = 0
        Set-ManageDropPreview -Decision $first
        Set-ManageDropPreview -Decision $last
        Set-ManageDropPreview -Decision $first
        Set-ManageDropPreview -Decision $last
        Assert-Lbs172 "$scale rapid previews coalesce before next paint frame" ($script:ManageDragRetargetPending -and $script:ManageDragRetargetCount -eq 0)
        Assert-Lbs172 "$scale no neighbor HWND reposition before frame" ($rows[2].Top -eq [int][Math]::Round(128*$scale))
        Advance-ManageDragReflow -Progress 0.5
        Assert-Lbs172 "$scale last queued decision is applied once" ($script:ManageDragRetargetCount -eq 1 -and $script:ManageDragTargets['b'] -eq [int][Math]::Round(192*$scale))
        # LBS-172 A/B: a single coalesced timer callback must settle the
        # cached neighbors directly, not perform 150ms of 1px HWND moves.
        Assert-Lbs172 "$scale neighbor rasters jump directly to final preview slots" (
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(64*$scale) -and
            $script:ManageDragNeighborVisuals['d'].Top -eq [int][Math]::Round(128*$scale))
        Assert-Lbs172 "$scale reflow timer stops after first target update" (
            $null -ne $script:ManageDragTimer -and -not $script:ManageDragTimer.Enabled)
        $settledMoveCount = [int]$script:ManageDragNeighborMoves
        Advance-ManageDragReflow -Progress 0.25
        Assert-Lbs172 "$scale repeated partial frame adds no neighbor movement" (
            $script:ManageDragNeighborMoves -eq $settledMoveCount -and
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(64*$scale))
        Assert-Lbs172 "$scale raster neighbor follows preview position without revealing child HWNDs" (
            $script:ManageDragNeighborVisuals['c'].Top -ne $rows[2].Top -and
            -not $rows[2].Visible)
        Assert-Lbs172 "$scale hidden native neighbor HWND coordinates stay parked during eased reflow" (
            @($neighbors | Where-Object { $_.Top -ne $originalNeighborTops[[string]$_.Tag] }).Count -eq 0)
        Assert-Lbs172 "$scale hidden native neighbor HWND identities remain stable" (
            @($neighbors | Where-Object { $_.Handle -ne $originalNeighborHandles[[string]$_.Tag] }).Count -eq 0)
        $midRasterTop = [int]$script:ManageDragNeighborVisuals['c'].Top
        $midRasterImage = $script:ManageDragNeighborVisuals['c'].Image
        Set-ManageDropPreview -Decision $first
        Advance-ManageDragReflow -Progress 0.0
        Assert-Lbs172 "$scale reverse retarget starts at the actual moving raster top" (
            $script:ManageDragStarts['c'] -eq $midRasterTop)
        Assert-Lbs172 "$scale reverse retarget settles in one callback without raster recapture" (
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(128*$scale) -and
            [object]::ReferenceEquals($midRasterImage,$script:ManageDragNeighborVisuals['c'].Image) -and
            (Test-Lbs172VisibleInk -Bitmap $midRasterImage -Bounds $rows[2].Controls['BootTitleLabel'].Bounds))
        $reverseMoveCount = [int]$script:ManageDragNeighborMoves
        Advance-ManageDragReflow -Progress 0.5
        Assert-Lbs172 "$scale reverse direction has no subsequent intermediate moves" (
            $script:ManageDragNeighborMoves -eq $reverseMoveCount -and
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(128*$scale))
        Set-ManageDropPreview -Decision $last
        Advance-ManageDragReflow -Progress 1.0
        Assert-Lbs172 "$scale live preview reaches final slot" (
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(64*$scale) -and
            $script:ManageDragNeighborVisuals['d'].Top -eq [int][Math]::Round(128*$scale))
        Assert-Lbs172 "$scale all native neighbor rows stay parked after multiple reversals" (
            @($neighbors | Where-Object { $_.Top -ne $originalNeighborTops[[string]$_.Tag] }).Count -eq 0)
        Assert-Lbs172 "$scale full-size placeholder tracks last slot" ($script:ManageDragPlaceholder.Visible -and $script:ManageDragPlaceholder.Top -eq [int][Math]::Round(192*$scale))
        Assert-Lbs172 "$scale order remains draft-only during drag" ((@($script:ManageEntryOrder) -join ',') -eq 'a,b,c,d' -and $script:TestSettingsWrites -eq 0)
        Set-ManageDropPreview -Decision $first
        Advance-ManageDragReflow -Progress 1.0
        Assert-Lbs172 "$scale reverse direction moves gap to first slot" (
            $script:ManageDragTargets['b'] -eq 0 -and
            $script:ManageDragNeighborVisuals['a'].Top -eq [int][Math]::Round(64*$scale) -and
            $rows[0].Top -eq $originalNeighborTops['a'])
        Set-ManageDropPreview -Decision $null
        Advance-ManageDragReflow -Progress 1.0
        Assert-Lbs172 "$scale invalid preview keeps a defined original-slot placeholder" ($script:ManageDragPlaceholder.Visible -and $script:ManageDragPlaceholder.Top -eq $sourceTop)
        Assert-Lbs172 "$scale invalid preview restores all neighbors" (
            $rows[0].Top -eq 0 -and $rows[2].Top -eq [int][Math]::Round(128*$scale) -and
            $script:ManageDragNeighborVisuals['a'].Top -eq 0 -and
            $script:ManageDragNeighborVisuals['c'].Top -eq [int][Math]::Round(128*$scale))
        Reset-ManageDragPreview
        Assert-Lbs172 "$scale cancellation restores source original slot and visibility" ($source.Visible -and $source.Top -eq $sourceTop)
        Assert-Lbs172 "$scale cancellation restores native neighbors and clears raster pictures" (
            @($neighbors | Where-Object { -not $_.Visible }).Count -eq 0 -and
            $null -eq $script:ManageDragNeighborVisuals -and
            @($content.Controls | Where-Object { $_.Name -eq 'ManageDragNeighbor' }).Count -eq 0)
        Assert-Lbs172 "$scale cancellation keeps all four original row and child identities" (
            @($content.Controls | Where-Object { $_.Name -eq 'BootRow' }).Count -eq 4 -and
            [object]::ReferenceEquals($pencilBefore,$source.Controls['AliasEditButton']) -and
            [object]::ReferenceEquals($gripBefore,$source.Controls['ManageReorderGrip']))
        Assert-Lbs172 "$scale temporary picture and paint bitmap disposed" (
            $null -eq $script:ManageDragGhost -and $null -eq $script:ManageDragGhostImage)
        Assert-Lbs172 "$scale shadow placeholder timer cleaned" (
            $null -eq $script:ManageDragShadow -and $null -eq $script:ManageDragPlaceholder -and $null -eq $script:ManageDragTimer)
        Assert-Lbs172 "$scale no orphaned WinForms drag visual controls" (
            @($content.Controls | Where-Object { $_.Name -like 'ManageDrag*' }).Count -eq 0)
        Assert-Lbs172 "$scale no settings write on cancel" ($script:TestSettingsWrites -eq 0)

        # The committed drop must finalize the preview before making rows visible.
        $script:ManageActiveDragGuid = 'b'
        Start-ManageDragReflow -SourceRow $source
        $last = Get-ManageDropDecision -Control $source -ScreenPoint $lastPoint -MovedGuid 'b'
        Set-ManageDropPreview -Decision $last
        Advance-ManageDragReflow -Progress 1.0
        Move-ManageEntry -MovedGuid 'b' -TargetGuid $last.TargetGuid -After:$last.After
        Assert-Lbs172 "$scale valid drop defers all original neighbor moves until handoff" (
            @($neighbors | Where-Object { $_.Top -ne $originalNeighborTops[[string]$_.Tag] }).Count -eq 0)
        Reset-ManageDragPreview -KeepPositions
        Assert-Lbs172 "$scale successful drop exactly matches preview order" ((@($script:ManageEntryOrder) -join ',') -eq 'a,c,d,b')
        Assert-Lbs172 "$scale successful drop keeps source visible in destination" ($source.Visible -and $source.Top -eq [int][Math]::Round(192*$scale))
        Assert-Lbs172 "$scale successful drop restores neighbor handles and clears raster clones" (
            @($rows | Where-Object { -not $_.Visible }).Count -eq 0 -and
            $null -eq $script:ManageDragNeighborVisuals)
        Assert-Lbs172 "$scale successful drop never recreates the pencil" ([object]::ReferenceEquals($pencilBefore,$source.Controls['AliasEditButton']))
        Assert-Lbs172 "$scale successful drop preserves neighbor positions" ($rows[2].Top -eq [int][Math]::Round(64*$scale) -and $rows[3].Top -eq [int][Math]::Round(128*$scale))
        Assert-Lbs172 "$scale successful drop leaves no ghost/placeholder" ($null -eq $script:ManageDragGhost -and $null -eq $script:ManageDragPlaceholder)
        Assert-Lbs172 "$scale committed draft does not persist until explicit save" ($script:TestSettingsWrites -eq 0)
    }
    finally {
        try { Reset-ManageDragPreview } catch {}
        $form.Dispose()
        $script:Popup = $null
    }
}
Write-Host "LBS172 DRAG TOTAL $script:checks/111"
if ($script:checks -ne 111) { throw "LBS172 test total mismatch $script:checks" }
