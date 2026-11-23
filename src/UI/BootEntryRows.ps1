# Lenovo Boot Selector - boot-entry row presentation helpers.
# LBS-29 separates row rendering and interaction responsibilities from list refresh orchestration.


# LBS-163: shared candidate resolver for preview and committed drop.
function Get-ManageDropDecision {
    param($Control,[Drawing.Point]$ScreenPoint,[string]$MovedGuid)
    if (-not $script:IsManageEntriesMode -or -not $MovedGuid) { return $null }
    $moved = $MovedGuid.ToLowerInvariant()
    $order = @($script:ManageEntryOrder | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $originalIndex = [array]::IndexOf($order,$moved)
    if ($originalIndex -lt 0) { return $null }

    $target = ''
    $after = $false
    # During live reflow the physical rows move. Resolve pointer coordinates
    # against immutable drag-start slots, never against their animated bounds.
    if ($script:ManageDragLayout -and $script:ManageDragContent -and -not $script:ManageDragContent.IsDisposed) {
        $point = $script:ManageDragContent.PointToClient($ScreenPoint)
        $slots = @($script:ManageDragLayout)
        if ($slots.Count -eq 0 -or $point.X -lt 0 -or $point.X -ge $script:ManageDragContent.ClientSize.Width) { return $null }
        if ($point.Y -lt $slots[0].Top -or $point.Y -ge ($slots[$slots.Count-1].Top + $slots[$slots.Count-1].Height)) { return $null }
        foreach ($slot in $slots) {
            $edge = $slot.Top + $slot.Height + [Math]::Floor($script:ManageDragRowGap / 2.0)
            if ($point.Y -lt $edge) {
                $target = $slot.Guid
                $after = ($point.Y -gt ($slot.Top + $slot.Height / 2.0))
                break
            }
        }
        if (-not $target) {
            $target = $slots[$slots.Count-1].Guid
            $after = $true
        }
    }
    else {
        $row = Get-BootRowFromControl $Control
        if (-not $row -or $row.IsDisposed -or -not $row.Parent -or $row.Parent.Name -ne 'EntryContent') { return $null }
        $point = $row.PointToClient($ScreenPoint)
        if ($point.X -lt 0 -or $point.X -ge $row.Width -or $point.Y -lt 0 -or $point.Y -ge $row.Height) { return $null }
        $target = ([string]$row.Tag).ToLowerInvariant()
        $after = ($point.Y -gt ($row.Height / 2.0))
    }
    $remaining = @($order | Where-Object { $_ -ne $moved })
    $targetIndex = [array]::IndexOf($remaining,$target)
    if (-not $target -or $target -eq $moved -or $targetIndex -lt 0) { return $null }
    $index = $targetIndex + $(if ($after) { 1 } else { 0 })
    if ($index -eq $originalIndex) { return $null }
    return [pscustomobject]@{ MovedGuid=$moved; TargetGuid=$target; After=[bool]$after; InsertIndex=[int]$index }
}
# LBS-163 iteration 2: animate existing WinForms rows; no rows are rebuilt in a drag.
# Slots are captured once, so the pointer decision never depends on animation frames.
# Paint each drag row into one frozen surface before the OLE drag begins.
# Avoid repeatedly painting nested eye, pencil, grip and text HWNDs in flight.
function New-ManageDragRowRaster {
    param($Row)
    if (-not $Row -or $Row.IsDisposed -or $Row.Width -le 0 -or $Row.Height -le 0) {
        throw [System.InvalidOperationException]::new('Drag row has no drawable surface.')
    }
    $Row.Refresh()
    $bitmap = [Drawing.Bitmap]::new([int]$Row.Width,[int]$Row.Height)
    try {
        $Row.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$Row.Width,$Row.Height))
        return $bitmap
    }
    catch {
        $bitmap.Dispose()
        throw
    }
}

# LBS-172: one actual HWND paints the dragged source, every cached neighbor,
# its destination gap and short shadow in ONE optimized buffered WM_PAINT.
# Snapshot PictureBoxes/Panels are detached state holders, not child HWNDs.
function Initialize-ManageDragBufferedCanvas {
    if ('LenovoDragBufferedCanvas' -as [type]) { return }
    $canvasSource = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public sealed class LenovoDragBufferedCanvas : Control
{
    private readonly List<PictureBox> neighbors = new List<PictureBox>();
    public PictureBox Ghost { get; set; }
    public Panel Shadow { get; set; }
    public Panel Placeholder { get; set; }

    public LenovoDragBufferedCanvas()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        DoubleBuffered = true;
        UpdateStyles();
        TabStop = false;
        Enabled = false;
    }

    public bool HasOptimizedPaintStyles
    {
        get {
            return GetStyle(ControlStyles.UserPaint) &&
                   GetStyle(ControlStyles.AllPaintingInWmPaint) &&
                   GetStyle(ControlStyles.OptimizedDoubleBuffer);
        }
    }

    public void AddNeighbor(PictureBox visual)
    {
        if (visual == null || visual.Parent != null || visual.IsHandleCreated)
            throw new InvalidOperationException("Raster state cannot own child HWNDs.");
        neighbors.Add(visual);
    }

    protected override void OnPaintBackground(PaintEventArgs e) { }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor); // Clear inside the same back-buffer transaction.

        if (Placeholder != null && Placeholder.Visible)
        {
            Rectangle r = Placeholder.Bounds;
            using (Brush b = new SolidBrush(Placeholder.BackColor))
                g.FillRectangle(b, r);
            using (Pen p = new Pen(Color.FromArgb(83, 88, 98), 1.0f))
            {
                p.DashStyle = DashStyle.Dash;
                g.DrawRectangle(p, r.Left + 1, r.Top + 1,
                    Math.Max(1, r.Width - 3), Math.Max(1, r.Height - 3));
            }
        }

        foreach (PictureBox row in neighbors)
        {
            if (row != null && row.Visible && row.Image != null)
                g.DrawImageUnscaled(row.Image, row.Left, row.Top);
        }

        if (Shadow != null && Shadow.Visible)
        {
            using (Brush b = new SolidBrush(Shadow.BackColor))
                g.FillRectangle(b, Shadow.Bounds);
        }

        if (Ghost != null && Ghost.Visible && Ghost.Image != null)
            g.DrawImageUnscaled(Ghost.Image, Ghost.Left, Ghost.Top);
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $canvasSource -ErrorAction Stop
}

function Start-ManageDragReflow {
    param($SourceRow)
    if (-not $SourceRow -or -not $SourceRow.Parent -or -not $script:IsManageEntriesMode) { return }
    Stop-ManageDragReflow
    $content = $SourceRow.Parent
    $rows = @($content.Controls | Where-Object { $_.Name -eq 'BootRow' } | Sort-Object Top)
    $slots = @()
    foreach ($row in $rows) {
        $slots += [pscustomobject]@{
            Guid=([string]$row.Tag).ToLowerInvariant()
            Row=$row
            Top=[int]$row.Top
            Height=[int]$row.Height
        }
    }
    if ($slots.Count -lt 2) { return }
    $script:ManageDragContent = $content
    $script:ManageDragLayout = $slots
    $script:ManageDragRowGap = [Math]::Max(0,$slots[1].Top - ($slots[0].Top+$slots[0].Height))
    $script:ManageDragRow = $SourceRow
    $script:ManageDragOriginalColor = $SourceRow.BackColor
    $script:ManageDragGhost = $null
    $script:ManageDragGhostImage = $null
    $script:ManageDragCanvas = $null
    $script:ManageDragVisualActive = $false
    $script:ManageDragCaptureCount = 0
    $script:ManageDragCaptureErrorClass = ''
    $script:ManageDragNeighborVisuals = @{}
    $script:ManageDragNeighborImages = @()
    $script:ManageDragNeighborCaptureCount = 0
    $script:ManageDragRetargetPending = $false
    $script:ManageDragQueuedDecision = $null
    $script:ManageDragRetargetCount = 0
    $script:ManageDragSupersededCount = 0
    $script:ManageDragNeighborMoves = 0

    $grab = $SourceRow.PointToClient([System.Windows.Forms.Control]::MousePosition)
    $script:ManageDragGrabY = [Math]::Max(0,[Math]::Min($SourceRow.Height-1,$grab.Y))

    # LBS-172: DrawToBitmap captures the complete row once, including the
    # independently painted pencil, eye, grip and text labels. Only a single
    # image HWND follows the mouse; the real source row/handlers stay parked.
    # Keep the source visible until OLE DoDragDrop has started.
    $bitmap = $null
    $ghost = $null
    try {
        $bitmap = New-ManageDragRowRaster -Row $SourceRow
        $ghost = New-Object System.Windows.Forms.PictureBox
        $ghost.Name = 'ManageDragGhost'
        $ghost.Location = $SourceRow.Location
        $ghost.Size = $SourceRow.Size
        $ghost.Image = $bitmap
        $ghost.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
        $ghost.BackColor = $SourceRow.BackColor
        $ghost.Enabled = $false # Let OLE hit testing reach the drop-enabled content.
        $ghost.Visible = $false
        # Detached state: the real painter is the shared buffered canvas.
        $script:ManageDragGhost = $ghost
        $script:ManageDragGhostImage = $bitmap
        $script:ManageDragCaptureCount = 1

        # One bitmap presentation per neighbor. Actual child HWNDs are only
        # parked during the active drag; the underlying rows stay intact.
        foreach ($slot in $slots) {
            if ($slot.Guid -eq $script:ManageActiveDragGuid) { continue }
            $neighborBitmap = New-ManageDragRowRaster -Row $slot.Row
            $script:ManageDragNeighborImages += $neighborBitmap
            $picture = New-Object System.Windows.Forms.PictureBox
            $script:ManageDragNeighborVisuals[$slot.Guid] = $picture
            $picture.Name = 'ManageDragNeighbor'
            $picture.Tag = $slot.Guid
            $picture.Location = $slot.Row.Location
            $picture.Size = $slot.Row.Size
            $picture.Image = $neighborBitmap
            $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
            $picture.BackColor = $slot.Row.BackColor
            $picture.Enabled = $false
            $picture.Visible = $false
            $script:ManageDragNeighborCaptureCount++
        }

        Initialize-ManageDragBufferedCanvas
        $canvas = New-Object LenovoDragBufferedCanvas
        $canvas.Name = 'ManageDragCanvas'
        $canvas.BackColor = $content.BackColor
        $canvas.Location = [Drawing.Point]::Empty
        $canvas.Size = $content.ClientSize
        $canvas.Dock = [System.Windows.Forms.DockStyle]::Fill
        $canvas.Ghost = $ghost
        foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
            $canvas.AddNeighbor($picture)
        }
        $canvas.Visible = $false
        $content.Controls.Add($canvas)
        $script:ManageDragCanvas = $canvas
    }
    catch {
        # A failing optional WinForms snapshot must never abort a reorder.
        # Fall back to the existing live-row movement and retain diagnostic
        # evidence; do not suppress the source drag or invent a success.
        $script:ManageDragCaptureErrorClass = $_.Exception.GetType().FullName
        # All-or-nothing setup. A failed visual capture leaves the original
        # safe live-row drag behavior available, never a partial raster layer.
        if ($script:ManageDragCanvas) {
            if ($script:ManageDragCanvas.Parent) {
                $script:ManageDragCanvas.Parent.Controls.Remove($script:ManageDragCanvas)
            }
            $script:ManageDragCanvas.Dispose()
            $script:ManageDragCanvas = $null
        }
        elseif ($canvas) {
            if ($canvas.Parent) { $canvas.Parent.Controls.Remove($canvas) }
            $canvas.Dispose()
        }
        if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
            foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
                if ($picture -and -not $picture.IsDisposed) {
                    if ($picture.Parent) { $picture.Parent.Controls.Remove($picture) }
                    $picture.Image = $null
                    $picture.Dispose()
                }
            }
        }
        foreach ($neighborBitmap in @($script:ManageDragNeighborImages)) {
            if ($neighborBitmap) { $neighborBitmap.Dispose() }
        }
        $script:ManageDragNeighborVisuals = $null
        $script:ManageDragNeighborImages = $null
        $script:ManageDragNeighborCaptureCount = 0
        if ($ghost) {
            if ($ghost.Parent) { $ghost.Parent.Controls.Remove($ghost) }
            $ghost.Image = $null
            $ghost.Dispose()
        }
        if ($bitmap) { $bitmap.Dispose() }
        $script:ManageDragGhost = $null
        $script:ManageDragGhostImage = $null
    }

    $shadow = New-Object System.Windows.Forms.Panel
    $shadow.Name = 'ManageDragShadow'
    # A thin trailing edge avoids the old full-height opaque dark rectangle.
    $shadow.Size = [Drawing.Size]::new([Math]::Max(1,$SourceRow.Width-8),[Math]::Max(3,[int][Math]::Round($SourceRow.Height*0.08)))
    $shadow.BackColor = [Drawing.Color]::FromArgb(12,12,16)
    $shadow.Enabled = $false
    $shadow.Visible = $false
    if (-not $script:ManageDragCanvas) { $content.Controls.Add($shadow) }
    $script:ManageDragShadow = $shadow
    if ($script:ManageDragCanvas) { $script:ManageDragCanvas.Shadow = $shadow }
    $placeholder = New-Object System.Windows.Forms.Panel
    $placeholder.Name = 'ManageDragPlaceholder'
    $placeholder.Size = $SourceRow.Size
    $placeholder.BackColor = [Drawing.Color]::FromArgb(34,36,41)
    $placeholder.Enabled = $false
    $placeholder.Visible = $false
    if (-not $script:ManageDragCanvas) { $placeholder.Add_Paint({
        param($sender,$eventArgs)
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(83,88,98),1.0)
        $pen.DashStyle = [Drawing.Drawing2D.DashStyle]::Dash
        try { $eventArgs.Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$sender.Width-3),[Math]::Max(1,$sender.Height-3)) }
        finally { $pen.Dispose() }
    }) }
    if (-not $script:ManageDragCanvas) {
        $content.Controls.Add($placeholder)
        $placeholder.SendToBack()
        $shadow.BringToFront()
    }
    $script:ManageDragPlaceholder = $placeholder
    if ($script:ManageDragCanvas) {
        $script:ManageDragCanvas.Placeholder = $placeholder
    }
    elseif ($script:ManageDragGhost) {
        $script:ManageDragGhost.BringToFront()
    }
    else {
        $SourceRow.BringToFront()
        $SourceRow.BackColor = [Drawing.Color]::FromArgb(48,48,54)
        $SourceRow.Invalidate($true)
        $shadow.Visible = $true
    }

    $script:ManageDragTargets = @{}
    $script:ManageDragStarts = @{}
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $timer.Add_Tick({ Advance-ManageDragReflow })
    $script:ManageDragTimer = $timer
    Set-ManageDragReflowTargets -Decision $null
    # Initial mapping is not a pointer-target change.
    $script:ManageDragRetargetCount = 0
    Set-ManageDragFloatLocation -ScreenPoint ([System.Windows.Forms.Control]::MousePosition)
}

function Set-ManageDragFloatLocation {
    param([Drawing.Point]$ScreenPoint,[switch]$ActivateVisual)
    if (-not $script:ManageDragRow -or $script:ManageDragRow.IsDisposed -or
        -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    $point = $script:ManageDragContent.PointToClient($ScreenPoint)
    $y = [int]($point.Y - $script:ManageDragGrabY)
    if ($script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed) {
        if ($ActivateVisual -and -not $script:ManageDragVisualActive) {
            # The OLE drag is now active: park the real nested HWND hierarchy
            # and reveal only the cached single-surface visual. A visible
            # dashed placeholder occupies the original slot even on no-op
            # and invalid destinations, avoiding a transient black hole.
            $script:ManageDragVisualActive = $true
            $script:ManageDragRow.Visible = $false
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                foreach ($slot in @($script:ManageDragLayout)) {
                    if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
                    $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                    if ($picture -and -not $picture.IsDisposed) {
                        $slot.Row.Visible = $false
                        $picture.Visible = $true
                    }
                }
            }
            if ($script:ManageDragPlaceholder -and -not $script:ManageDragPlaceholder.IsDisposed) {
                $script:ManageDragPlaceholder.Visible = $true
            }
            if ($script:ManageDragShadow -and -not $script:ManageDragShadow.IsDisposed) {
                $script:ManageDragShadow.Visible = $true
            }
            $script:ManageDragGhost.Visible = $true
            if ($script:ManageDragCanvas) {
                $script:ManageDragCanvas.Visible = $true
                $script:ManageDragCanvas.BringToFront()
            }
            else { $script:ManageDragGhost.BringToFront() }
        }
        if ($script:ManageDragGhost.Top -ne $y) { $script:ManageDragGhost.Top = $y }
    }
    elseif ($script:ManageDragRow.Top -ne $y) {
        # Read-only bitmap capture failed: retain the original drag behavior.
        $script:ManageDragRow.Top = $y
    }
    if ($script:ManageDragShadow -and -not $script:ManageDragShadow.IsDisposed) {
        $left = $script:ManageDragRow.Left + 4
        $shadowY = $y + $script:ManageDragRow.Height - [int][Math]::Floor($script:ManageDragShadow.Height/2.0)
        if ($script:ManageDragShadow.Left -ne $left -or $script:ManageDragShadow.Top -ne $shadowY) {
            $script:ManageDragShadow.Location = [Drawing.Point]::new($left,$shadowY)
        }
    }
    # The WinForms paint queue coalesces this into one buffered raster frame.
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) {
        $script:ManageDragCanvas.Invalidate()
    }
}

function Set-ManageDragReflowTargets {
    param($Decision)
    if (-not $script:ManageDragLayout) { return }
    $slots = @($script:ManageDragLayout)
    $moved = ([string]$script:ManageActiveDragGuid).ToLowerInvariant()
    $sequence = New-Object System.Collections.ArrayList
    $byGuid = @{}
    foreach ($slot in $slots) {
        $byGuid[$slot.Guid] = $slot
        if ($slot.Guid -ne $moved) { [void]$sequence.Add($slot.Guid) }
    }
    if ($Decision) {
        $index = [Math]::Max(0,[Math]::Min($sequence.Count,[int]$Decision.InsertIndex))
        $sequence.Insert($index,$moved)
    }
    else {
        $original = [array]::IndexOf(@($slots | ForEach-Object { $_.Guid }),$moved)
        $sequence.Insert([Math]::Max(0,$original),$moved)
    }
    $targets = @{}
    $y = [int]$slots[0].Top
    foreach ($guid in $sequence) {
        $slot = $byGuid[$guid]
        $targets[$guid] = $y
        $y += $slot.Height + $script:ManageDragRowGap
    }
    $script:ManageDragStarts = @{}
    $needsMotion = $false
    foreach ($slot in $slots) {
        if ($slot.Guid -ne $moved -and -not $slot.Row.IsDisposed) {
            # The raster, not the parked native row, owns the visible position.
            # On a mid-flight reversal, start from the actual picture position
            # instead of snapping to the original hidden HWND's static slot.
            $surface = $slot.Row
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                if ($picture -and -not $picture.IsDisposed) { $surface = $picture }
            }
            $script:ManageDragStarts[$slot.Guid] = [int]$surface.Top
            if ([int]$surface.Top -ne [int]$targets[$slot.Guid]) { $needsMotion = $true }
        }
    }
    $script:ManageDragTargets = $targets
    $script:ManageDragRetargetCount++
    if ($script:ManageDragPlaceholder -and -not $script:ManageDragPlaceholder.IsDisposed) {
        $script:ManageDragPlaceholder.Top = [int]$targets[$moved]
        # Once the source is parked, keep its destination represented even
        # if the pointer temporarily produces a no-op or invalid candidate.
        $script:ManageDragPlaceholder.Visible = ([bool]$script:ManageDragVisualActive -or $null -ne $Decision)
    }
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) { $script:ManageDragCanvas.Invalidate() }
    $script:ManageDragAnimationStartUtc = [datetime]::UtcNow
    if ($script:ManageDragTimer) {
        if ($needsMotion) { $script:ManageDragTimer.Start() }
        else { $script:ManageDragTimer.Stop() }
    }
}

function Advance-ManageDragReflow {
    param([double]$Progress = -1)
    if (-not $script:ManageDragLayout -or -not $script:ManageDragContent -or $script:ManageDragContent.IsDisposed) { return }
    if ($script:ManageDragRetargetPending) {
        # Apply the *last* decision once per 16ms UI timer frame, not every
        # DragOver message. This bounds raster moves on rapid reversals.
        $decision = $script:ManageDragQueuedDecision
        $script:ManageDragRetargetPending = $false
        $script:ManageDragQueuedDecision = $null
        Set-ManageDragReflowTargets -Decision $decision
    }
    # LBS-172 V7 A/B: keep the 16ms timer only as a DragOver target
    # coalescing boundary. With cached row pictures, place neighbors at
    # their exact new slots in one callback instead of creating 150ms of
    # intermediate native PictureBox window moves. The moving source ghost
    # and immutable drop-hit slots are unchanged. If capture failed, use
    # the previous eased live-row fallback rather than altering semantics.
    $instantRasterReflow = ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary] -and
                            $script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed)
    $t = if ($instantRasterReflow) { 1.0 }
         elseif ($Progress -ge 0) { [Math]::Min(1.0,[Math]::Max(0.0,$Progress)) }
         else { [Math]::Min(1.0,([datetime]::UtcNow-$script:ManageDragAnimationStartUtc).TotalMilliseconds/150.0) }
    $ease = 1.0 - [Math]::Pow(1.0-$t,3.0)
    $script:ManageDragContent.SuspendLayout()
    try {
        foreach ($slot in @($script:ManageDragLayout)) {
            if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
            $start = [int]$script:ManageDragStarts[$slot.Guid]
            $target = [int]$script:ManageDragTargets[$slot.Guid]
            $top = [int][Math]::Round($start + (($target-$start)*$ease))
            # Move exactly one presentation surface per frame. With a cached
            # raster, the real multi-child row must remain at its immutable
            # slot and never generate native HWND move/invalidation traffic.
            # If capture failed, retain the original live-row fallback.
            $surface = $slot.Row
            if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
                $picture = $script:ManageDragNeighborVisuals[$slot.Guid]
                if ($picture -and -not $picture.IsDisposed) { $surface = $picture }
            }
            if ($surface.Top -ne $top) {
                $surface.Top = $top
                $script:ManageDragNeighborMoves++
            }
        }
    }
    finally { $script:ManageDragContent.ResumeLayout($false) }
    if ($script:ManageDragCanvas -and $script:ManageDragVisualActive) { $script:ManageDragCanvas.Invalidate() }
    if ($t -ge 1.0 -and $script:ManageDragTimer) { $script:ManageDragTimer.Stop() }
}

function Stop-ManageDragReflow {
    param([switch]$KeepPositions)
    $content = $script:ManageDragContent
    $hadSession = [bool]$script:ManageDragLayout
    if ($script:ManageDragTimer) {
        $script:ManageDragTimer.Stop()
        $script:ManageDragTimer.Dispose()
        $script:ManageDragTimer = $null
    }
    if ($content -and -not $content.IsDisposed) { $content.SuspendLayout() }
    try {
        if ($script:ManageDragLayout) {
            $moved = ([string]$script:ManageActiveDragGuid).ToLowerInvariant()
            foreach ($slot in @($script:ManageDragLayout)) {
                if ($slot.Row.IsDisposed) { continue }
                $destination = [int]$slot.Top
                if ($KeepPositions -and $script:ManageDragTargets -and
                    $script:ManageDragTargets.ContainsKey($slot.Guid)) {
                    $destination = [int]$script:ManageDragTargets[$slot.Guid]
                }
                if ($slot.Guid -eq $moved) {
                    # Restore the source once, behind the cached ghost, before
                    # its original nested child HWNDs become visible again.
                    $slot.Row.Top = $destination
                }
                elseif ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary] -and
                        $script:ManageDragNeighborVisuals.ContainsKey($slot.Guid)) {
                    # Cached neighbors remained fixed through every timer
                    # frame. Make one final hidden HWND handoff at the exact
                    # committed/invalid destination before restoring visibility.
                    $slot.Row.Top = $destination
                }
                elseif (-not $KeepPositions) {
                    # Existing live-row fallback: restore after cancel only.
                    $slot.Row.Top = $destination
                }
            }
        }
        if ($script:ManageDragRow -and -not $script:ManageDragRow.IsDisposed) {
            $script:ManageDragRow.BackColor = $script:ManageDragOriginalColor
            if ($script:ManageDragGhost -and -not $script:ManageDragGhost.IsDisposed) {
                $script:ManageDragRow.Visible = $true
                # One synchronous final paint under the picture, not
                # separate pencil/eye/reorder repaints on each drag frame.
                $script:ManageDragRow.Refresh()
            }
            else { $script:ManageDragRow.Invalidate($true) }
        }
        # Restore native rows at the final slot and synchronously paint them
        # under the cached pictures, then dispose every transient surface.
        if ($script:ManageDragVisualActive -and $script:ManageDragNeighborVisuals) {
            foreach ($slot in @($script:ManageDragLayout)) {
                if ($slot.Guid -eq $script:ManageActiveDragGuid -or $slot.Row.IsDisposed) { continue }
                $slot.Row.Visible = $true
                $slot.Row.Refresh()
            }
        }
        # Remove the single buffered native HWND before releasing any cached
        # bitmap; detached PictureBoxes and panels never owned child HWNDs.
        if ($script:ManageDragCanvas) {
            if ($script:ManageDragCanvas.Parent) {
                $script:ManageDragCanvas.Parent.Controls.Remove($script:ManageDragCanvas)
            }
            $script:ManageDragCanvas.Dispose()
            $script:ManageDragCanvas = $null
        }
        if ($script:ManageDragNeighborVisuals -is [System.Collections.IDictionary]) {
            foreach ($picture in @($script:ManageDragNeighborVisuals.Values)) {
                if ($picture -and -not $picture.IsDisposed) {
                    if ($picture.Parent) { $picture.Parent.Controls.Remove($picture) }
                    $picture.Image = $null
                    $picture.Dispose()
                }
            }
        }
        foreach ($neighborBitmap in @($script:ManageDragNeighborImages)) {
            if ($neighborBitmap) { $neighborBitmap.Dispose() }
        }
        foreach ($visual in @($script:ManageDragGhost,$script:ManageDragShadow,$script:ManageDragPlaceholder)) {
            if ($visual -and -not $visual.IsDisposed) {
                if ($visual.Parent) { $visual.Parent.Controls.Remove($visual) }
                if ($visual -is [System.Windows.Forms.PictureBox]) { $visual.Image = $null }
                $visual.Dispose()
            }
        }
        if ($script:ManageDragGhostImage) { $script:ManageDragGhostImage.Dispose() }
    }
    finally {
        if ($content -and -not $content.IsDisposed) { $content.ResumeLayout($false) }
    }

    # One bounded, privacy-preserving diagnostic per completed drag, rather
    # than per mouse movement; no GUID, alias text or target is recorded.
    if ($hadSession -and $script:RuntimeDiagnosticsAvailable) {
        Write-RuntimeDiagnosticEvent -Event 'MANAGE_DRAG_VISUAL' -Stage 'ui' -Success $true -Data (New-RuntimeDiagnosticData @{
            snapshotCaptures = [int]$script:ManageDragCaptureCount
            neighborRasterCaptures = [int]$script:ManageDragNeighborCaptureCount
            fallbackClass = [string]$script:ManageDragCaptureErrorClass
            retargetsApplied = [int]$script:ManageDragRetargetCount
            retargetsSuperseded = [int]$script:ManageDragSupersededCount
            neighborPanelMoves = [int]$script:ManageDragNeighborMoves
            keptPreviewPositions = [bool]$KeepPositions
        })
    }
    $script:ManageDragPlaceholder = $null
    $script:ManageDragShadow = $null
    $script:ManageDragGhost = $null
    $script:ManageDragGhostImage = $null
    $script:ManageDragCanvas = $null
    $script:ManageDragNeighborVisuals = $null
    $script:ManageDragNeighborImages = $null
    $script:ManageDragNeighborCaptureCount = 0
    $script:ManageDragVisualActive = $false
    $script:ManageDragLayout = $null
    $script:ManageDragContent = $null
    $script:ManageDragRow = $null
    $script:ManageDragTargets = $null
    $script:ManageDragStarts = $null
    $script:ManageDragOriginalColor = $null
    $script:ManageDragRowGap = 0
    $script:ManageDragGrabY = 0
    $script:ManageDragRetargetPending = $false
    $script:ManageDragQueuedDecision = $null
    $script:ManageDragCaptureCount = 0
    $script:ManageDragCaptureErrorClass = ''
    $script:ManageDragRetargetCount = 0
    $script:ManageDragSupersededCount = 0
    $script:ManageDragNeighborMoves = 0
}

function Set-ManageDropPreview {
    param($Decision)
    $prior = $script:ManageDropPreview
    if ($prior -and $Decision -and $prior.TargetGuid -eq $Decision.TargetGuid -and $prior.After -eq $Decision.After) { return }
    if (-not $prior -and -not $Decision) { return }
    $script:ManageDropPreview = $Decision
    if ($script:ManageDragLayout) {
        if ($script:ManageDragRetargetPending) { $script:ManageDragSupersededCount++ }
        $script:ManageDragQueuedDecision = $Decision
        $script:ManageDragRetargetPending = $true
        if ($script:ManageDragTimer) { $script:ManageDragTimer.Start() }
        return
    }
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) {
        if (($prior -and [string]$row.Tag -eq $prior.TargetGuid) -or
            ($Decision -and [string]$row.Tag -eq $Decision.TargetGuid)) { $row.Invalidate() }
    }
}
function Reset-ManageDragPreview {
    param([switch]$KeepPositions)
    Stop-ManageDragReflow -KeepPositions:$KeepPositions
    Set-ManageDropPreview -Decision $null
    $script:ManageActiveDragGuid = $null
    $script:ManageDragGuid = $null
    if ($script:Popup -and -not $script:Popup.IsDisposed) {
        foreach ($row in @($script:Popup.Controls.Find('BootRow',$true))) { $row.Invalidate() }
    }
    # Apply a real firmware/label change once DoDragDrop has released its rows.
    if ($script:PopupRowsRefreshPending -or $script:PopupRowsViewportPending) {
        Update-PopupRows -Reason 'drag-ended'
    }
}
# Lightweight row-painted cue: no extra WinForms controls intercept pointer events.
function Paint-ManageDropCue {
    param($Row,$Graphics)
    if (-not $script:IsManageEntriesMode) { return }
    $guid = ([string]$Row.Tag).ToLowerInvariant()
    if ($script:ManageActiveDragGuid -and $guid -eq $script:ManageActiveDragGuid) {
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(155,155,155),1.0)
        try { $Graphics.DrawRectangle($pen,1,1,[Math]::Max(1,$Row.Width-3),[Math]::Max(1,$Row.Height-3)) }
        finally { $pen.Dispose() }
    }
    if ($script:ManageDragLayout) { return } # Full-height gap replaces the old red line.
    $cue = $script:ManageDropPreview
    if (-not $cue -or $cue.TargetGuid -ne $guid) { return }
    $thickness = [Math]::Max(3,[int][Math]::Round($Row.Height/20.0))
    $y = if ($cue.After) { $Row.Height-$thickness } else { 0 }
    $brush = New-Object Drawing.SolidBrush($script:ColorAccent)
    try {
        $Graphics.FillRectangle($brush,0,$y,$Row.Width,$thickness)
        $Graphics.FillRectangle($brush,0,[Math]::Max(0,$y-$thickness),[Math]::Max(6,$thickness*2),[Math]::Min($Row.Height,$thickness*3))
    }
    finally { $brush.Dispose() }
}

function New-BootEntryInteractionHandlers {
    $clickHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode) {
            $capabilities = Get-CurrentSystemFunctionsCapabilities
            if (-not $capabilities.CanManageEntries) { return }
        }
        # BootNext controller owns both Ready and cold-start Checking admission.
        # Do not silently discard the first click before pending feedback.
        $guid = [string]$sender.Tag
        if (-not $guid) {
            $row = Get-BootRowFromControl $sender
            if ($row) { $guid = [string]$row.Tag }
        }
        if (-not $guid) { return }

        if ($script:IsManageEntriesMode) {
            if (([datetime]::UtcNow - $script:ManageLastDragUtc).TotalMilliseconds -lt 350) { return }
            if ($script:ManageAliasEditGuid) { Commit-ActiveManageAliasEditor }
            Toggle-ManageEntryVisibility -Guid $guid
            $script:LastStatusText = if (Test-ManageEntryHidden -Guid $guid) { Get-LocalizedString -Key 'Manage.EntryHiddenStatus' } else { Get-LocalizedString -Key 'Manage.EntryVisibleStatus' }
            Update-PopupRows
            return
        }

        Invoke-NormalBootTargetSelection -Guid $guid
    }

    $enterHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $true }
    $leaveHandler = { param($sender,$eventArgs) Set-RowHoverState $sender $false }
    $wheelHandler = {
        param($sender, $eventArgs)
        $panel = $null
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $panelMatches = $script:Popup.Controls.Find('EntryList', $true)
            if ($panelMatches.Count -gt 0) { $panel = $panelMatches[0] }
        }
        $bar = if ($panel) { $panel.Controls['EntryScroll'] } else { $null }
        if ($bar -and $bar.Visible) {
            $direction = if ($eventArgs.Delta -gt 0) { -1 } else { 1 }
            $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
        }
    }
    $mouseDownHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or $eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $guid = [string]$sender.Tag
        if (-not $guid) {
            $row = Get-BootRowFromControl $sender
            if ($row) { $guid = [string]$row.Tag }
        }
        $script:ManageDragGuid = $guid
        $script:ManageDragStartX = $eventArgs.X
        $script:ManageDragStartY = $eventArgs.Y
    }
    $mouseMoveHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $script:ManageDragGuid) { return }
        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $dx = [Math]::Abs($eventArgs.X - $script:ManageDragStartX)
        $dy = [Math]::Abs($eventArgs.Y - $script:ManageDragStartY)
        if ($dx -lt 5 -and $dy -lt 5) { return }
        $guid = $script:ManageDragGuid
        $script:ManageDragGuid = $null
        $script:ManageLastDragUtc = [datetime]::UtcNow
        $script:ManageActiveDragGuid = ([string]$guid).ToLowerInvariant()
        $sourceRow = Get-BootRowFromControl $sender
        if ($sourceRow) { Start-ManageDragReflow -SourceRow $sourceRow }
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) }
        catch { }
        finally { Reset-ManageDragPreview }
    }
    $dragOverHandler = {
        param($sender,$eventArgs)
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Set-ManageDropPreview -Decision $null; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Set-ManageDropPreview -Decision $null; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        Set-ManageDropPreview -Decision $decision
        if ($script:ManageDragLayout) { Set-ManageDragFloatLocation -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -ActivateVisual }
        if ($decision) { $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move }
    }
    $dragEnterHandler = $dragOverHandler
    $dragLeaveHandler = {
        param($sender,$eventArgs)
        if (-not $script:Popup -or $script:Popup.IsDisposed) { Reset-ManageDragPreview; return }
        $matches = @($script:Popup.Controls.Find('EntryList',$true))
        if ($matches.Count -eq 0) { Set-ManageDropPreview -Decision $null; return }
        $point = $matches[0].PointToClient([System.Windows.Forms.Control]::MousePosition)
        if (-not $matches[0].ClientRectangle.Contains($point)) { Set-ManageDropPreview -Decision $null }
    }
    $dragDropHandler = {
        param($sender,$eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $script:ManageActiveDragGuid -or
            -not $eventArgs.Data.GetDataPresent([string])) { Reset-ManageDragPreview; return }
        $guid = ([string]$eventArgs.Data.GetData([string])).ToLowerInvariant()
        if ($guid -ne $script:ManageActiveDragGuid) { Reset-ManageDragPreview; return }
        $decision = Get-ManageDropDecision -Control $sender -ScreenPoint ([Drawing.Point]::new($eventArgs.X,$eventArgs.Y)) -MovedGuid $guid
        if (-not $decision) { Reset-ManageDragPreview; return }
        $movedGuid = $decision.MovedGuid
        $targetRow = $null
        if ($script:ManageDragLayout) {
            $targetSlot = $script:ManageDragLayout | Where-Object { $_.Guid -eq $decision.TargetGuid } | Select-Object -First 1
            if ($targetSlot) { $targetRow = $targetSlot.Row }
        }
        else {
            $targetRow = Get-BootRowFromControl $sender
        }
        if (-not $targetRow -or $targetRow.IsDisposed -or ([string]$targetRow.Tag).ToLowerInvariant() -ne $decision.TargetGuid) {
            Reset-ManageDragPreview
            return
        }
        # A drop can arrive before the next 16ms timer tick. Flush the
        # exact committed decision and place every existing row at the final
        # preview slot before removing the ghost; no obsolete-order flash.
        Set-ManageDropPreview -Decision $decision
        if ($script:ManageDragLayout) { Advance-ManageDragReflow -Progress 1.0 }
        $after = $decision.After
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
        # The rows already occupy their preview positions; do not briefly snap
        # them back to the obsolete order before the committed render.
        Reset-ManageDragPreview -KeepPositions
        $script:ManageLastDragUtc = [datetime]::UtcNow
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.OrderChanged'
        Update-PopupRows
    }

    return [pscustomobject]@{
        Click = $clickHandler
        Enter = $enterHandler
        Leave = $leaveHandler
        Wheel = $wheelHandler
        MouseDown = $mouseDownHandler
        MouseMove = $mouseMoveHandler
        DragEnter = $dragEnterHandler
        DragOver = $dragOverHandler
        DragLeave = $dragLeaveHandler
        DragDrop = $dragDropHandler
    }
}

function Add-BootEntryAliasEditor {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [AllowNull()][string]$Alias
    )

    # v0.2.30: keep the expanded alias editor, but render it as a
    # flat edit line rather than a full focus rectangle. Only the
    # bottom rule turns Lenovo-red while the TextBox has focus.
    $editorFrame = New-Object System.Windows.Forms.Panel
    $editorFrame.Name = 'AliasEditorFrame'
    $editorFrame.Location = New-Object Drawing.Point(58, 32)
    $editorFrame.Size = New-Object Drawing.Size(318, 27)
    $editorFrame.BackColor = $script:ColorRow

    $aliasEditor = New-Object System.Windows.Forms.TextBox
    $aliasEditor.Name = 'AliasEditor'
    $aliasEditor.Tag = $entry.Guid
    $aliasEditor.Text = if ($alias) { [string]$alias } else { '' }
    $aliasEditor.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $aliasEditor.ForeColor = $script:ColorPrimary
    $aliasEditor.BackColor = [Drawing.Color]::FromArgb(24,24,24)
    $aliasEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $aliasEditor.Location = New-Object Drawing.Point(0, 2)
    $aliasEditor.Size = New-Object Drawing.Size(288, 21)

    $aliasUnderline = New-Object System.Windows.Forms.Panel
    $aliasUnderline.Name = 'AliasEditorUnderline'
    $aliasUnderline.Location = New-Object Drawing.Point(0, 25)
    $aliasUnderline.Size = New-Object Drawing.Size(318, 1)
    $aliasUnderline.BackColor = [Drawing.Color]::FromArgb(72,72,72)
    $editorFrame.Controls.Add($aliasUnderline)


    $clearAlias = New-Object System.Windows.Forms.Button
    $clearAlias.Name = 'AliasClearButton'
    $clearAlias.Text = '×'
    $clearAlias.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Regular)
    $clearAlias.ForeColor = [Drawing.Color]::FromArgb(145,145,145)
    $clearAlias.BackColor = [Drawing.Color]::FromArgb(24,24,24)
    $clearAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $clearAlias.FlatAppearance.BorderSize = 0
    $clearAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38,38,38)
    $clearAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(45,30,29)
    $clearAlias.Location = New-Object Drawing.Point(292, 0)
    $clearAlias.Size = New-Object Drawing.Size(26, 23)
    $clearAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $clearAlias.Visible = -not [string]::IsNullOrEmpty([string]$aliasEditor.Text)
    $clearAlias.Add_MouseEnter({ $this.ForeColor = $script:ColorAccent })
    $clearAlias.Add_MouseLeave({ $this.ForeColor = [Drawing.Color]::FromArgb(145,145,145) })
    $clearAlias.Add_Click({
        $editor = $this.Parent.Controls.Find('AliasEditor', $false) | Select-Object -First 1
        if ($editor) {
            $editor.Text = ''
            $editor.Focus()
        }
    })
    $editorFrame.Controls.Add($clearAlias)

    $aliasEditor.Add_Enter({
        param($sender,$eventArgs)
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = $script:ColorAccent }
        } catch { }
    })
    $aliasEditor.Add_Leave({
        param($sender,$eventArgs)
        try {
            $line = $sender.Parent.Controls.Find('AliasEditorUnderline', $false) | Select-Object -First 1
            if ($line) { $line.BackColor = [Drawing.Color]::FromArgb(72,72,72) }
        } catch { }
    })
    $aliasEditor.Add_TextChanged({
        param($sender,$eventArgs)
        try {
            $clear = $sender.Parent.Controls.Find('AliasClearButton', $false) | Select-Object -First 1
            if ($clear) { $clear.Visible = -not [string]::IsNullOrEmpty([string]$sender.Text) }
            Update-ManageSaveButtonState
        } catch { }
    })
    $aliasEditor.Add_KeyDown({
        param($sender,$eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            Set-ManageEntryAliasDraft -Guid ([string]$sender.Tag) -Alias ([string]$sender.Text)
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ([string]::IsNullOrWhiteSpace([string]$sender.Text)) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            $eventArgs.SuppressKeyPress = $true
            Update-PopupRows
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
            $eventArgs.SuppressKeyPress = $true
            Update-PopupRows
        }
    })
    $editorFrame.Controls.Add($aliasEditor)
    $row.Controls.Add($editorFrame)

    $applyAlias = New-Object System.Windows.Forms.Button
    $applyAlias.Name = 'AliasApplyButton'
    $applyAlias.Text = Get-LocalizedString -Key 'Common.Apply'
    $applyAlias.Tag = $entry.Guid
    $applyAlias.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $applyAlias.ForeColor = [Drawing.Color]::FromArgb(255,110,102)
    $applyAlias.BackColor = $script:ColorRow
    $applyAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyAlias.FlatAppearance.BorderSize = 0
    $applyAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $applyAlias.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $applyAlias.Location = New-Object Drawing.Point(58, 62)
    $applyAlias.Size = New-Object Drawing.Size(92, 24)
    $applyAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $applyAlias.Add_Click({
        param($sender,$eventArgs)
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor) {
            Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
            $empty = [string]::IsNullOrWhiteSpace([string]$editor.Text)
            $script:ManageAliasEditGuid = $null
            $script:LastStatusText = if ($empty) { Get-LocalizedString -Key 'Manage.AliasRemoved' } else { Get-LocalizedString -Key 'Manage.AliasChanged' }
            Update-PopupRows
        }
    })
    $row.Controls.Add($applyAlias)

    $cancelAlias = New-Object System.Windows.Forms.Button
    $cancelAlias.Name = 'AliasCancelButton'
    $cancelAlias.Text = Get-LocalizedString -Key 'Common.Cancel'
    $cancelAlias.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $cancelAlias.ForeColor = $script:ColorSecondary
    $cancelAlias.BackColor = $script:ColorRow
    $cancelAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelAlias.FlatAppearance.BorderSize = 0
    $cancelAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
    $cancelAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelAlias.Location = New-Object Drawing.Point(154, 62)
    $cancelAlias.Size = New-Object Drawing.Size(80, 24)
    $cancelAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelAlias.Add_Click({
        $script:ManageAliasEditGuid = $null
        $script:LastStatusText = Get-LocalizedString -Key 'Manage.AliasDiscarded'
        Update-PopupRows
    })
    $row.Controls.Add($cancelAlias)

    $originalHint = New-Label -Text (Get-LocalizedString -Key 'Manage.OriginalNameHint') -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 238 -Y 60 -Width 138 -Height 30
    $originalHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $originalHint.AccessibleDescription = $originalHint.Text
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($originalHint,$originalHint.Text) }
    $row.Controls.Add($originalHint)
}

# LBS-144: calculate visibility-eye paint geometry from the graphics surface
# DPI, not from fixed pixels. The popup already scales the 32x34 design
# hit target; keep that unchanged and derive a single-scale glyph.
function Get-LenovoManageEyeGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Visibility glyph requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $eyeWidth = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(20.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $eyeHeight = [Math]::Min(
        [Math]::Max(1,$ClientSize.Height - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $left = [int][Math]::Floor(($ClientSize.Width - $eyeWidth) / 2.0)
    $top = [int][Math]::Floor(($ClientSize.Height - $eyeHeight) / 2.0)
    $eye = [Drawing.Rectangle]::new($left,$top,$eyeWidth,$eyeHeight)
    $pupilSide = [Math]::Min(
        [Math]::Max(1,$eyeHeight - 2),
        [Math]::Max(1,[int][Math]::Round(5.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $pupilSide = [Math]::Min($pupilSide,$eyeWidth)
    $pupil = [Drawing.Rectangle]::new(
        $left + [int][Math]::Floor(($eyeWidth - $pupilSide) / 2.0),
        $top + [int][Math]::Floor(($eyeHeight - $pupilSide) / 2.0),
        $pupilSide,$pupilSide)
    $extension = [Math]::Max(1,[int][Math]::Round(1.0 * $scale,[MidpointRounding]::AwayFromZero))
    return [pscustomobject]@{
        Eye = $eye
        Pupil = $pupil
        SlashStart = [Drawing.Point]::new(
            [Math]::Max(0,$eye.Left - $extension),
            [Math]::Min($ClientSize.Height-1,$eye.Bottom + $extension))
        SlashEnd = [Drawing.Point]::new(
            [Math]::Min($ClientSize.Width-1,$eye.Right + $extension),
            [Math]::Max(0,$eye.Top - $extension))
        Stroke = [single](1.6 * $scale)
        SlashStroke = [single](1.8 * $scale)
    }
}

# LBS-166: draw the reorder affordance at paint-surface DPI, not font size.
# Preserve its existing 26x34 design-unit hit area.
function Get-LenovoManageGripGlyphGeometry {
    param(
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][double]$Dpi
    )
    if ($ClientSize.Width -lt 1 -or $ClientSize.Height -lt 1) {
        throw 'Reorder grip requires positive client dimensions.'
    }
    $scale = if ($Dpi -gt 0) { [Math]::Min(5.0,[Math]::Max(1.0,$Dpi / 96.0)) } else { 1.0 }
    $margin = [Math]::Max(1,[int][Math]::Round(2.0 * $scale,[MidpointRounding]::AwayFromZero))
    $width = [Math]::Min(
        [Math]::Max(1,$ClientSize.Width - 2 * $margin),
        [Math]::Max(1,[int][Math]::Round(18.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $stroke = [single][Math]::Min(2.4 * $scale,[double]$width)
    $span = [Math]::Min(
        [Math]::Max(0,$ClientSize.Height - 2 * $margin - [int][Math]::Ceiling($stroke)),
        [Math]::Max(0,[int][Math]::Round(12.0 * $scale,[MidpointRounding]::AwayFromZero)))
    $centerX = ($ClientSize.Width - 1) / 2.0
    $centerY = ($ClientSize.Height - 1) / 2.0
    $halfLine = ($width - $stroke) / 2.0
    return [pscustomobject]@{
        Width = [int]$width
        Span = [int]$span
        Stroke = [single]$stroke
        StartX = [single]($centerX - $halfLine)
        EndX = [single]($centerX + $halfLine)
        TopY = [single]($centerY - $span / 2.0)
        MiddleY = [single]$centerY
        BottomY = [single]($centerY + $span / 2.0)
    }
}

function Paint-LenovoManageGripGlyph {
    param(
        [Parameter(Mandatory=$true)][Drawing.Graphics]$Graphics,
        [Parameter(Mandatory=$true)][Drawing.Size]$ClientSize,
        [Parameter(Mandatory=$true)][Drawing.Color]$Color
    )
    $geometry = Get-LenovoManageGripGlyphGeometry -ClientSize $ClientSize -Dpi $Graphics.DpiX
    $smoothing = $Graphics.SmoothingMode
    $pen = New-Object Drawing.Pen($Color,$geometry.Stroke)
    try {
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        foreach ($y in @($geometry.TopY,$geometry.MiddleY,$geometry.BottomY)) {
            $Graphics.DrawLine($pen,$geometry.StartX,[single]$y,$geometry.EndX,[single]$y)
        }
    }
    finally {
        $Graphics.SmoothingMode = $smoothing
        $pen.Dispose()
    }
}

function Add-ManageBootEntryControls {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][bool]$IsHidden,
        [Parameter(Mandatory=$true)]$Marker,
        [Parameter(Mandatory=$true)]$Icon,
        [Parameter(Mandatory=$true)]$Title,
        $Subtitle
    )
$state = New-Object System.Windows.Forms.Panel
$state.Name = 'VisibilityGlyph'
$state.Tag = $entry.Guid
$state.AccessibleName = if ($isHidden) { 'hidden' } else { 'visible' }
$state.AccessibleDescription = if ($isHidden) { Get-LocalizedString -Key 'Manage.HiddenAccessible' } else { Get-LocalizedString -Key 'Manage.VisibleAccessible' }
$state.Location = New-Object Drawing.Point(286, 12)
$state.Size = New-Object Drawing.Size(32, 34)
$state.BackColor = [Drawing.Color]::Transparent
$state.Cursor = [System.Windows.Forms.Cursors]::Hand
$state.AllowDrop = $true
$state.Add_Paint({
    param($sender,$eventArgs)
    $hidden = ([string]$sender.AccessibleName -eq 'hidden')
    $color = if ($hidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
    $geometry = Get-LenovoManageEyeGlyphGeometry -ClientSize $sender.ClientSize -Dpi $eventArgs.Graphics.DpiX
    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object Drawing.Pen($color, $geometry.Stroke)
    $pupil = New-Object Drawing.SolidBrush($color)
    try {
        $eventArgs.Graphics.DrawEllipse($pen, $geometry.Eye)
        $eventArgs.Graphics.FillEllipse($pupil, $geometry.Pupil)
        if ($hidden) {
            $slash = New-Object Drawing.Pen($color, $geometry.SlashStroke)
            try {
                $eventArgs.Graphics.DrawLine($slash, $geometry.SlashStart, $geometry.SlashEnd)
            } finally { $slash.Dispose() }
        }
    }
    finally {
        $pen.Dispose()
        $pupil.Dispose()
    }
})
$state.Add_MouseEnter({
    param($sender,$eventArgs)
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$state.Add_MouseLeave({
    param($sender,$eventArgs)
    try { Hide-DarkActionTooltip } catch { }
})
$row.Controls.Add($state)

$editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 14.0, [Drawing.FontStyle]::Regular)) `
    -ForeColor ([Drawing.Color]::FromArgb(190,190,190)) -X 321 -Y 12 -Width 25 -Height 34
$editAlias.Name = 'AliasEditButton'
$editAlias.Tag = $entry.Guid
$editAlias.AccessibleDescription = Get-LocalizedString -Key 'Manage.EditAliasAccessible'
$editAlias.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$editAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
$editAlias.Add_MouseEnter({
    param($sender,$eventArgs)
    $sender.ForeColor = $script:ColorAccent
    Set-RowHoverState $sender $true
    try { Show-DarkActionTooltip -Owner $sender -Text ([string]$sender.AccessibleDescription) } catch { }
})
$editAlias.Add_MouseLeave({
    param($sender,$eventArgs)
    $sender.ForeColor = [Drawing.Color]::FromArgb(190,190,190)
    Set-RowHoverState $sender $false
    try { Hide-DarkActionTooltip } catch { }
})
$editAlias.Add_Click({
    param($sender,$eventArgs)
    try { Hide-DarkActionTooltip } catch { }
    $guid = ([string]$sender.Tag).ToLowerInvariant()
    if ($script:ManageAliasEditGuid -and $script:ManageAliasEditGuid -ne $guid) {
        Commit-ActiveManageAliasEditor
    }
    $script:ManageAliasEditGuid = $guid
    $script:LastStatusText = Get-LocalizedString -Key 'Manage.EditAliasStatus'
    Update-PopupRows
    $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($editor) {
        $editor.Focus()
        $editor.SelectAll()
    }
})
$row.Controls.Add($editAlias)

$grip = New-Object System.Windows.Forms.Panel
$grip.Name = 'ManageReorderGrip'
$grip.Tag = $entry.Guid
$grip.Location = New-Object Drawing.Point(350, 12)
$grip.Size = New-Object Drawing.Size(26, 34)
$grip.BackColor = [Drawing.Color]::Transparent
$grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$grip.AllowDrop = $true
$grip.Add_Paint({
    param($sender,$eventArgs)
    Paint-LenovoManageGripGlyph -Graphics $eventArgs.Graphics -ClientSize $sender.ClientSize -Color ([Drawing.Color]::FromArgb(145,145,145))
})
$row.Controls.Add($grip)

return @($row, $marker, $icon, $title, $subtitle, $state, $grip)
}

function Add-NormalBootEntryControls {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][bool]$IsSelected,
        [Parameter(Mandatory=$true)]$Marker,
        [Parameter(Mandatory=$true)]$Icon,
        [Parameter(Mandatory=$true)]$Title,
        $Subtitle
    )

    $checkText = if ($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid)) { '…' } elseif ($isSelected) { '✓' } else { '' }
    $check = New-Label -Text $checkText `
        -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
        -ForeColor $(if ($script:BootNextPendingGuid -and ([string]$entry.Guid -eq [string]$script:BootNextPendingGuid)) { $script:ColorWarning } else { $script:ColorAccent }) -X 354 -Y 12 -Width 24 -Height 34
    $check.Tag = $entry.Guid
    $check.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $check.Cursor = [System.Windows.Forms.Cursors]::Hand
    $row.Controls.Add($check)
    return @($row, $marker, $icon, $title, $subtitle, $check)
}

function Connect-BootEntryRowInteractions {
    param(
        [Parameter(Mandatory=$true)][object[]]$RowControls,
        [Parameter(Mandatory=$true)]$Handlers
    )

    $clickHandler = $Handlers.Click
    $enterHandler = $Handlers.Enter
    $leaveHandler = $Handlers.Leave
    $wheelHandler = $Handlers.Wheel
    $mouseDownHandler = $Handlers.MouseDown
    $mouseMoveHandler = $Handlers.MouseMove
    $dragEnterHandler = $Handlers.DragEnter
    $dragOverHandler = $Handlers.DragOver
    $dragLeaveHandler = $Handlers.DragLeave
    $dragDropHandler = $Handlers.DragDrop

foreach ($control in $RowControls) {
    $control.Add_Click($clickHandler)
    $control.Add_MouseEnter($enterHandler)
    $control.Add_MouseLeave($leaveHandler)
    $control.Add_MouseWheel($wheelHandler)
    if ($script:IsManageEntriesMode) {
        $control.Add_MouseDown($mouseDownHandler)
        $control.Add_MouseMove($mouseMoveHandler)
        $control.Add_DragEnter($dragEnterHandler)
        $control.Add_DragOver($dragOverHandler)
        $control.Add_DragLeave($dragLeaveHandler)
        $control.Add_DragDrop($dragDropHandler)
    }
}
}

# Initial construction and metadata-only refresh share one text/locale rule.
function Get-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Entry)
    $manage = [bool]$script:IsManageEntriesMode
    $guid = ([string]$Entry.Guid).ToLowerInvariant()
    $alias = Get-EntryAlias -Guid $guid -UseManageDraft:$manage
    $displayTitle = Get-EntryDisplayTitle -Entry $Entry -UseManageDraft:$manage
    $editing = $manage -and $script:ManageAliasEditGuid -and $guid -eq $script:ManageAliasEditGuid
    $pending = -not $manage -and (Resolve-BootNextRowDisplayCore -EntryGuid $guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid) -eq 'pending'
    $titleText = if ($editing) { [string]$Entry.Title } else { [string]$displayTitle }
    $subtitleText = if ($editing) { '' }
        elseif ($manage -and $alias) { Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name=[string]$Entry.Title } }
        elseif ($manage -and ([string]$Entry.RawDescription -eq 'Boot Menu')) { Get-LocalizedString -Key 'Boot.MenuManageSubtitle' }
        elseif ($pending) { Get-LocalizedString -Key 'BootNext.SelectionPending' }
        else { [string]$Entry.Subtitle }
    return [pscustomobject]@{ Title = [string]$titleText; Subtitle = [string]$subtitleText }
}

# The caller must first prove GUID/order/mode/DPI and structural-signature parity.
# Keep live WinForms controls, handlers and scroll context intact.
function Update-BootEntryRowText {
    param([Parameter(Mandatory=$true)]$Row,[Parameter(Mandatory=$true)]$Entry)
    $title = $Row.Controls['BootTitleLabel']
    $subtitle = $Row.Controls['BootSubtitleLabel']
    if (-not $title -or -not $subtitle -or $title.IsDisposed -or $subtitle.IsDisposed) {
        throw 'Metadata-only row update requires existing title and subtitle controls.'
    }
    $text = Get-BootEntryRowText -Entry $Entry
    $changed = $false
    if ([string]$title.Text -cne [string]$text.Title) {
        $title.Text = [string]$text.Title
        $title.AccessibleDescription = [string]$text.Title
        if (-not $script:IsManageEntriesMode) { $Row.AccessibleName = [string]$text.Title }
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title,[string]$text.Title) }
        $changed = $true
    }
    if ([string]$subtitle.Text -cne [string]$text.Subtitle) {
        $subtitle.Text = [string]$text.Subtitle
        $subtitle.AccessibleDescription = [string]$text.Subtitle
        if (-not $script:IsManageEntriesMode) { $Row.AccessibleDescription = [string]$text.Subtitle }
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle,[string]$text.Subtitle) }
        $changed = $true
    }
    return [bool]$changed
}


# UX01-V8: a real focusable native Panel preserves all existing mouse/paint
# behavior, but exposes Up/Down/Home/End and Enter/Space as input keys. The
# selected BootNext target is never changed by focus alone.
function Initialize-NormalBootKeyboardRow {
    if ('LenovoNormalBootKeyboardRow' -as [type]) { return }
    $keyboardSource = @'
using System;
using System.Drawing;
using System.Windows.Forms;

public sealed class LenovoNormalBootKeyboardRow : Panel
{
    public LenovoNormalBootKeyboardRow()
    {
        SetStyle(ControlStyles.Selectable, true);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        TabStop = true;
    }

    protected override bool IsInputKey(Keys keyData)
    {
        Keys key = keyData & Keys.KeyCode;
        if (key == Keys.Up || key == Keys.Down || key == Keys.Home ||
            key == Keys.End || key == Keys.Return || key == Keys.Space)
            return true;
        return base.IsInputKey(keyData);
    }

    protected override void OnGotFocus(EventArgs e)
    {
        base.OnGotFocus(e);
        Invalidate();
    }

    protected override void OnLostFocus(EventArgs e)
    {
        base.OnLostFocus(e);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (!Focused) return;
        Rectangle r = ClientRectangle;
        r.Inflate(-3, -3);
        if (r.Width > 0 && r.Height > 0)
        {
            using (Brush tint = new SolidBrush(Color.FromArgb(18, 180, 196, 214))) e.Graphics.FillRectangle(tint, r);
            using (Pen p = new Pen(Color.FromArgb(181, 196, 212), 1.5f)) e.Graphics.DrawRectangle(p, r);
        }
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $keyboardSource -ErrorAction Stop
}

# Keep the canonical BootNext controller as the sole selection owner. This
# shared helper is called by both the existing pointer handler and keyboard
# activation; moving focus never calls it.
function Invoke-NormalBootTargetSelection {
    param([string]$Guid)
    $guid = [string]$Guid
    if (-not $guid -or $script:IsManageEntriesMode) { return }
    try {
        $entry = Get-EntryByGuid $guid
        Start-BootNextSelection -Guid $guid
    }
    catch {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Boot.ChangeErrorTitle') -Heading (Get-LocalizedString -Key 'Boot.ChangeErrorHeading') -Message (Get-LocalizedString -Key 'Boot.ChangeErrorMessage') -Kind Error
    }
}

# Works with the existing EntryScroll control, including when the content
# panel has been moved by the custom scrollbar's ValueChanged handler.
function Set-NormalBootRowVisible {
    param($Row)
    if (-not $Row -or $Row.IsDisposed -or -not $Row.Parent -or
        $Row.Parent.Name -ne 'EntryContent') { return }
    $content = $Row.Parent
    $list = $content.Parent
    if (-not $list -or $list.Name -ne 'EntryList') { return }
    $scroll = $list.Controls['EntryScroll']
    if (-not $scroll -or -not $scroll.Visible) { return }
    $current = [int]$scroll.Value
    $viewport = [Math]::Max(1,[int]$list.ClientSize.Height)
    $desired = $current
    if ($Row.Top -lt $current) { $desired = [int]$Row.Top }
    elseif ($Row.Bottom -gt ($current + $viewport)) {
        $desired = [int]$Row.Bottom - $viewport
    }
    $desired = [Math]::Max(0,[Math]::Min([int]$scroll.Maximum,$desired))
    if ($scroll.Value -ne $desired) { $scroll.Value = $desired }
    $content.Top = -[int]$scroll.Value
}

function Move-NormalBootKeyboardFocus {
    param($Row,[System.Windows.Forms.Keys]$Key)
    if ($script:IsManageEntriesMode -or -not $Row -or $Row.IsDisposed -or
        -not $Row.Parent -or $Row.Parent.Name -ne 'EntryContent') { return }
    $rows = @($Row.Parent.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed -and $_.Enabled -and $_.Visible
    } | Sort-Object Top)
    if ($rows.Count -eq 0) { return }
    $index = -1
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ([object]::ReferenceEquals($rows[$i],$Row)) { $index = $i; break }
    }
    if ($index -lt 0) { return }
    switch ($Key) {
        ([System.Windows.Forms.Keys]::Down) { $index = [Math]::Min($rows.Count-1,$index+1); break }
        ([System.Windows.Forms.Keys]::Up) { $index = [Math]::Max(0,$index-1); break }
        ([System.Windows.Forms.Keys]::Home) { $index = 0; break }
        ([System.Windows.Forms.Keys]::End) { $index = $rows.Count-1; break }
        default { return }
    }
    $target = $rows[$index]
    [void]$target.Focus()
    Set-NormalBootRowVisible -Row $target
}

function New-BootEntryRow {
    param(
        [Parameter(Mandatory=$true)]$Entry,
        [Parameter(Mandatory=$true)][int]$Y,
        [Parameter(Mandatory=$true)][int]$BaseRowHeight,
        [Parameter(Mandatory=$true)]$Handlers
    )

$guidNormalized = ([string]$entry.Guid).ToLowerInvariant()
$aliasEditActive = $script:IsManageEntriesMode -and $script:ManageAliasEditGuid -and ($guidNormalized -eq $script:ManageAliasEditGuid)
$rowHeight = if ($aliasEditActive) { 92 } else { $baseRowHeight }

if ($script:IsManageEntriesMode) {
    $row = New-Object System.Windows.Forms.Panel
}
else {
    Initialize-NormalBootKeyboardRow
    $row = New-Object LenovoNormalBootKeyboardRow
}
$row.Name = 'BootRow'
$row.Tag = $entry.Guid
$row.Location = New-Object Drawing.Point(0, $y)
$row.Size = New-Object Drawing.Size(390, $rowHeight)
$row.BackColor = $script:ColorRow
$row.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$row.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
if ($script:IsManageEntriesMode) { $row.Add_Paint({ param($sender,$eventArgs) Paint-ManageDropCue -Row $sender -Graphics $eventArgs.Graphics }) }

$isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
$rowDisplay = if ($script:IsManageEntriesMode) { 'idle' } else { Resolve-BootNextRowDisplayCore -EntryGuid $entry.Guid -ConfirmedGuid $script:SelectedGuid -PendingGuid $script:BootNextPendingGuid }
$isSelected = ($rowDisplay -eq 'selected')
$isPending = ($rowDisplay -eq 'pending')
if ($isPending) { $row.BackColor = [Drawing.Color]::FromArgb(46,40,27) }
elseif ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

$marker = New-Object System.Windows.Forms.Panel
$marker.Location = New-Object Drawing.Point(0, 0)
$marker.Size = New-Object Drawing.Size(3, $rowHeight)
$marker.BackColor = $script:ColorRow
if ($isPending) { $marker.BackColor = $script:ColorWarning }
elseif ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
elseif ($isHidden) { $marker.BackColor = [Drawing.Color]::FromArgb(70,70,70) }
$marker.Tag = $entry.Guid
$marker.AllowDrop = $script:IsManageEntriesMode
$row.Controls.Add($marker)

$iconColor = if ($isHidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $entry.Accent }
$titleColor = if ($isHidden) { [Drawing.Color]::FromArgb(175,175,175) } else { $script:ColorPrimary }
$subtitleColor = if ($isHidden) { [Drawing.Color]::FromArgb(155,155,155) } else { $script:ColorSecondary }

$icon = New-Label -Text $entry.Symbol -Font (New-Object Drawing.Font('Segoe UI Symbol', 18, [Drawing.FontStyle]::Regular)) `
    -ForeColor $iconColor -X 22 -Y 7 -Width 28 -Height 44
$icon.Tag = $entry.Guid
$icon.Cursor = [System.Windows.Forms.Cursors]::Hand
$icon.AllowDrop = $script:IsManageEntriesMode
if ($script:BootTypeToolTip -and $entry.TypeTooltip) {
    $icon.AccessibleDescription = [string]$entry.TypeTooltip
    $script:BootTypeToolTip.SetToolTip($icon, [string]$entry.TypeTooltip)
    # Native SetToolTip proved unreliable on the transparent symbol label
    # on the target PC. MouseHover explicitly shows the same tooltip and
    # MouseLeave closes it, while the semantic text remains on the circle only.
    $icon.Add_MouseHover({
        param($sender, $eventArgs)
        try {
            $text = [string]$sender.AccessibleDescription
            if ($text) { $script:BootTypeToolTip.Show($text, $sender, 18, [Math]::Max(18, $sender.Height - 2), 8000) }
        } catch { }
    })
    $icon.Add_MouseLeave({ param($sender, $eventArgs) try { $script:BootTypeToolTip.Hide($sender) } catch { } })
}
$row.Controls.Add($icon)

$alias = if ($script:IsManageEntriesMode) {
    Get-EntryAlias -Guid ([string]$entry.Guid) -UseManageDraft
}
else {
    Get-EntryAlias -Guid ([string]$entry.Guid)
}
$rowText = Get-BootEntryRowText -Entry $entry
$titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
$titleText = [string]$rowText.Title
if (-not $script:IsManageEntriesMode) {
    $row.AccessibleRole = [System.Windows.Forms.AccessibleRole]::PushButton
    $row.AccessibleName = [string]$rowText.Title
    $row.AccessibleDescription = [string]$rowText.Subtitle
}
$title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
    -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
$title.Name = 'BootTitleLabel'
# At high DPI, WinForms AutoEllipsis can suppress the entire label if its
# vertical rectangle is considered insufficient. Keep text visible; the
# full name is also available in the tooltip and accessible description.
$title.AutoEllipsis = $false
$title.AccessibleDescription = [string]$titleText
if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($title, [string]$titleText) }
$title.Tag = $entry.Guid
$title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
$title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
$row.Controls.Add($title)

$subtitle = $null
if (-not $aliasEditActive) {
    $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
    $subtitleText = [string]$rowText.Subtitle
    $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $subtitleColor -X 58 -Y 28 -Width $subtitleWidth -Height 26
    $subtitle.Name = 'BootSubtitleLabel'
    $subtitle.AutoEllipsis = $false
    $subtitle.AccessibleDescription = [string]$subtitleText
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($subtitle, [string]$subtitleText) }
    $subtitle.Tag = $entry.Guid
    $subtitle.Cursor = [System.Windows.Forms.Cursors]::Hand
    $subtitle.AllowDrop = $script:IsManageEntriesMode
    $row.Controls.Add($subtitle)
}

    if ($script:IsManageEntriesMode) {
        if ($aliasEditActive) {
            Add-BootEntryAliasEditor -Row $row -Entry $entry -Alias $alias
            $rowControls = @()
        }
        else {
            $rowControls = @(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden ([bool]$isHidden) -Marker $marker -Icon $icon -Title $title -Subtitle $subtitle)
        }
    }
    else {
        $rowControls = @(Add-NormalBootEntryControls -Row $row -Entry $entry -IsSelected ([bool]$isSelected) -Marker $marker -Icon $icon -Title $title -Subtitle $subtitle)
    }

    if ($rowControls.Count -gt 0) {
        Connect-BootEntryRowInteractions -RowControls $rowControls -Handlers $Handlers
    }

    if (-not $script:IsManageEntriesMode) {
        # Input keys are supplied by LenovoNormalBootKeyboardRow, not by
        # intercepting global Form shortcuts or the Manage Entries editor.
        $row.Add_KeyDown({
            param($sender,$eventArgs)
            if ($script:IsManageEntriesMode -or
                $eventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None) { return }
            $key = $eventArgs.KeyCode
            if ($key -in @([System.Windows.Forms.Keys]::Up,
                           [System.Windows.Forms.Keys]::Down,
                           [System.Windows.Forms.Keys]::Home,
                           [System.Windows.Forms.Keys]::End)) {
                Move-NormalBootKeyboardFocus -Row $sender -Key $key
                $eventArgs.Handled = $true
                $eventArgs.SuppressKeyPress = $true
            }
            elseif ($key -eq [System.Windows.Forms.Keys]::Return -or
                    $key -eq [System.Windows.Forms.Keys]::Space) {
                # Arm exactly one selection for the matching KeyUp. Do not
                # SuppressKeyPress: WinForms also suppresses KeyUp for that
                # physical keystroke (Microsoft keyboard event contract).
                $eventArgs.Handled = $true
                $script:NormalBootActivationArmedRow = $sender
                $script:NormalBootActivationArmedKey = $key
            }
        })
        $row.Add_KeyUp({
            param($sender,$eventArgs)
            $armed = [object]::ReferenceEquals($script:NormalBootActivationArmedRow,$sender) -and
                ($script:NormalBootActivationArmedKey -eq $eventArgs.KeyCode)
            if ($armed) {
                $script:NormalBootActivationArmedRow = $null
                $script:NormalBootActivationArmedKey = [System.Windows.Forms.Keys]::None
            }
            if ($script:IsManageEntriesMode -or
                $eventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None -or -not $armed) { return }
            if (($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Return -or
                 $eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Space) -and
                $sender.Focused) {
                $eventArgs.Handled = $true
                Invoke-NormalBootTargetSelection -Guid ([string]$sender.Tag)
            }
        })
        $row.Add_LostFocus({
            param($sender,$eventArgs)
            if ([object]::ReferenceEquals($script:NormalBootActivationArmedRow,$sender)) {
                $script:NormalBootActivationArmedRow = $null
                $script:NormalBootActivationArmedKey = [System.Windows.Forms.Keys]::None
            }
        })
    }

    return [pscustomobject]@{
        Row = $row
        Height = $rowHeight
    }
}

function Update-BootEntryScrollLayout {
    param(
        [Parameter(Mandatory=$true)]$ListPanel,
        [Parameter(Mandatory=$true)]$ContentPanel,
        $ScrollBar,
        [Parameter(Mandatory=$true)][int]$ContentBottom,
        [Parameter(Mandatory=$true)][int]$BaseRowHeight,
        [Parameter(Mandatory=$true)][int]$RowGap
    )

$viewportHeight = $ListPanel.ClientSize.Height
$contentHeight = [Math]::Max($viewportHeight, $ContentBottom)
$ContentPanel.Size = New-Object Drawing.Size($ListPanel.ClientSize.Width, $contentHeight)
if ($ScrollBar) {
    $maxScroll = [Math]::Max(0, $contentHeight - $viewportHeight)
    $ScrollBar.LargeChange = [Math]::Max(1, $viewportHeight)
    $ScrollBar.SmallChange = $BaseRowHeight + $RowGap
    $ScrollBar.Maximum = $maxScroll
    $ScrollBar.Visible = ($maxScroll -gt 0)
    if (-not $ScrollBar.Visible) { $ScrollBar.Value = 0 }
    elseif ($ScrollBar.Value -gt $maxScroll) { $ScrollBar.Value = $maxScroll }
    $ContentPanel.Top = -1 * $ScrollBar.Value
}
}
