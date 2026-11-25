# Escape belongs to this visible popup only. Child-local cancellation (alias editor,
# default-target menu and active drag) must run before any parent dismissal.
function Invoke-PopupEscapeDismissal {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.KeyEventArgs]$EventArgs
    )
    if (-not $Form -or -not $EventArgs -or
        $EventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Escape -or
        $EventArgs.Modifiers -ne [System.Windows.Forms.Keys]::None) { return }
    if (-not $Form.Visible -or -not $Form.ContainsFocus) { return }

    # Owned auxiliary forms and OLE drag have independent Escape/cleanup lifecycles.
    if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog) { return }
    if ($script:ManageActiveDragGuid -or $script:ManageDragLayout) { return }

    $aliasEditor = $Form.Controls.Find('AliasEditor', $true) | Select-Object -First 1
    if ($aliasEditor -and -not $aliasEditor.IsDisposed -and $aliasEditor.ContainsFocus) { return }

    # Presentation-only: keep the Form, tray owner, workers and Manage draft alive.
    $EventArgs.Handled = $true
    $EventArgs.SuppressKeyPress = $true
    $Form.Hide()
}

function New-PopupForm {
    param([double]$TargetScale = 1.0, [string]$ScaleSource = 'initial')
    $form = New-Object System.Windows.Forms.Form
    if (-not $script:BootTypeToolTip) {
        $script:BootTypeToolTip = New-LenovoDarkTooltip -Animate
        $form.Add_Disposed({
            if ($script:BootTypeToolTip) {
                $script:BootTypeToolTip.Dispose()
                $script:BootTypeToolTip = $null
            }
        })
    }
    $form.Name = 'LenovoBootSelectorPopup'
    $form.KeyPreview = $true
    Initialize-PopupDpiLayout -Form $form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    # v0.2.28: plain square utility panel, intentionally without an outer
    # Lenovo-red frame or rounded clipping. Red remains an interaction accent.
    $form.BackColor = $script:ColorBackground
    $form.Width = 390
    $form.Height = 672

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'PopupRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(390, 672)
    $root.BackColor = $script:ColorBackground
    $form.Controls.Add($root)

    Add-PopupHeaderSection -Root $root
    Add-PopupBootEntryListSection -Root $root
    Add-PopupSettingsSection -Root $root
    Add-PopupRestartSection -Root $root
    Add-PopupManageEntriesSection -Root $root
    $maintenancePanel = New-MaintenanceStatePanel
    $root.Controls.Add($maintenancePanel)

    # Scale the entire static control tree in one WinForms DPI pass.
    Complete-PopupDpiLayout -Form $form -Scale $TargetScale
    Write-PopupDpiLayoutDiagnostic -Form $form -Phase 'constructed' -MonitorSource $ScaleSource
    $form.Add_Shown({
        Write-PopupDpiLayoutDiagnostic -Form $this -Phase 'shown' -MonitorSource 'active-screen'
    })

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_KeyDown({
        param($sender, $eventArgs)
        Invoke-PopupEscapeDismissal -Form $sender -EventArgs $eventArgs
    })

    $form.Add_Deactivate({
        # The owned auxiliary Form is part of this popup's UI. The
        # ownership flag covers Deactivate before the child becomes visible.
        if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog) { return }
        $capabilities = Get-CurrentSystemFunctionsCapabilities
        if (-not $script:ExitRequested -and [string]$capabilities.State -ne 'Busy') { $this.Hide() }
    })

    return $form
}
function Position-Popup {
    param([switch]$FromTrayClick)
    if (-not $script:Popup) { return }

    $hasClick = $false
    $clickPoint = [Drawing.Point]::Empty
    if ($FromTrayClick -and $null -ne $script:TrayPopupClickUtc -and
        ([DateTime]::UtcNow - $script:TrayPopupClickUtc).TotalSeconds -le 30) {
        $clickPoint = $script:TrayPopupClickPoint
        $hasClick = $true
    }

    $iconRect = Get-VisiblePopupTrayIconRectangle -ClickPoint $clickPoint -HasClickPoint:$hasClick
    if ($null -ne $iconRect) {
        $screen = [System.Windows.Forms.Screen]::FromRectangle($iconRect)
    }
    elseif ($hasClick) {
        $screen = [System.Windows.Forms.Screen]::FromPoint($clickPoint)
        # Only a genuine recent NotifyIcon click may supply this approximate anchor.
        $iconRect = [Drawing.Rectangle]::new($clickPoint.X - 12, $clickPoint.Y - 12, 24, 24)
    }
    else {
        # Non-pointer/first-run fallback: deterministic primary display, never cursor.
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    if ($null -eq $screen) { return }
    $monitorScale = Get-LenovoUiCoordinateScale -Screen $screen
    $monitorChanged = Set-PopupDpiLayoutScale -Form $script:Popup -Scale ([double]$monitorScale.Factor)
    $viewportChanged = Set-PopupViewportForWorkingArea -Form $script:Popup -WorkingArea $screen.WorkingArea
    if ($monitorChanged -or $viewportChanged) { Update-PopupRows -Reason $(if ($monitorChanged) { 'dpi-changed' } else { 'viewport-changed' }) }
    Write-PopupDpiLayoutDiagnostic -Form $script:Popup -Phase 'positioned' -MonitorSource ([string]$monitorScale.Source)
    $location = Get-PopupLocationFromAnchor -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds -AnchorRect $iconRect -PopupSize $script:Popup.Size -HasAnchor:($null -ne $iconRect)
    $script:Popup.Location = $location
}

function Show-OrTogglePopup {
    param([switch]$FromTrayClick)
    if ($script:PreferencesUiActive) { return }
    if ($script:ActiveOwnedDialog -and -not $script:ActiveOwnedDialog.IsDisposed) {
        [void]$script:ActiveOwnedDialog.Activate()
        return
    }
    if ($script:ActiveAuxiliaryPopup -and -not $script:ActiveAuxiliaryPopup.IsDisposed) {
        [void]$script:ActiveAuxiliaryPopup.Activate()
        return
    }
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $initialScreen = [System.Windows.Forms.Screen]::PrimaryScreen
        $initialScale = Get-LenovoUiCoordinateScale -Screen $initialScreen
        $script:Popup = New-PopupForm -TargetScale ([double]$initialScale.Factor) -ScaleSource ([string]$initialScale.Source)
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $maintenanceBusy = ([string]$capabilities.State -eq 'Busy')
    $canUseSystemState = [bool]$capabilities.CanUseCachedBootState
    if ($canUseSystemState) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if ([string]$capabilities.State -eq 'ReinitializeRequired') {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { Get-LocalizedString -Key 'Status.NewBootTargetDetected' } else { Get-LocalizedString -Key 'Status.BootTargetsChanged' }
            }
            elseif ([string]$capabilities.State -eq 'SetupRequired') {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
            }
            else {
                $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup -FromTrayClick:$FromTrayClick
    $script:Popup.Show()
    $script:Popup.Activate()

    # LBS-21: opening the visible UI is the automatic read-only update-check trigger.
    # The update worker has its own busy gate and can overlap the independent boot-target worker.
    [void](Start-PopupUpdateCheck)

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($canUseSystemState -and -not $maintenanceBusy) {
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext) -Origin Popup
    }
}

# Explicit launcher re-entry is SHOW, never the tray-icon toggle (which hides
# an already visible popup). This runs on the existing WinForms UI thread.
function Show-OrActivatePopup {
    if ($script:PreferencesUiActive) { return }
    if ($script:ActiveOwnedDialog -and -not $script:ActiveOwnedDialog.IsDisposed) {
        [void]$script:ActiveOwnedDialog.Activate()
        return
    }
    if ($script:ActiveAuxiliaryPopup -and -not $script:ActiveAuxiliaryPopup.IsDisposed) {
        [void]$script:ActiveAuxiliaryPopup.Activate()
        return
    }
    if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) {
        [void]$script:Popup.Activate()
        return
    }
    Show-OrTogglePopup
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}

# Auxiliary forms are built at 96-DPI design bounds, then scaled once using
# the same effective coordinate factor as the main popup. Keep font points
# and the main popup's immutable metrics independent.
function Set-AuxiliaryControlBounds {
    param([System.Windows.Forms.Control]$Control,[double]$Scale)
    $Control.SuspendLayout()
    try {
        if ($Control -is [System.Windows.Forms.Form]) {
            $Control.ClientSize = [Drawing.Size]::new([int][Math]::Round($Control.ClientSize.Width*$Scale),[int][Math]::Round($Control.ClientSize.Height*$Scale))
        }
        else {
            $b = $Control.Bounds
            $Control.Bounds = [Drawing.Rectangle]::new([int][Math]::Round($b.X*$Scale),[int][Math]::Round($b.Y*$Scale),[int][Math]::Round($b.Width*$Scale),[int][Math]::Round($b.Height*$Scale))
        }
        foreach ($child in $Control.Controls) { Set-AuxiliaryControlBounds -Control $child -Scale $Scale }
    }
    finally { $Control.ResumeLayout($false) }
}

# Scroll position belongs to the custom bar; never let WinForms create a
# competing native scrollbar. Focus reveal is read-only and does not select.
function Set-AuxiliaryPopupControlVisible {
    param([Windows.Forms.Control]$Control)
    $form = $Control.FindForm()
    if (-not $form -or -not $form.Tag.Scroll -or $Control.Parent -ne $form.Tag.Body) { return }
    $state = $form.Tag
    $bar = $state.Scroll
    if ($Control.Top -lt $bar.Value) { $bar.Value = $Control.Top }
    elseif ($Control.Bottom -gt $bar.Value + $state.Viewport.Height) {
        $bar.Value = $Control.Bottom - $state.Viewport.Height
    }
}

function Add-AuxiliaryPopupWheelHandlers {
    param([Windows.Forms.Control]$Control)
    $Control.Add_MouseWheel({
        param($sender,$eventArgs)
        if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs] -and $eventArgs.Handled) { return }
        $form = $sender.FindForm()
        if (-not $form -or -not $form.Tag.Scroll -or $eventArgs.Delta -eq 0) { return }
        $bar = $form.Tag.Scroll
        if ($bar.Maximum -le 0) { return }
        $steps = [Math]::Max(1,[int][Math]::Abs([Math]::Truncate($eventArgs.Delta / 120.0)))
        $bar.Value = $bar.Value - [Math]::Sign($eventArgs.Delta)*$steps*$bar.SmallChange
        if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) { $eventArgs.Handled = $true }
    })
    foreach ($child in $Control.Controls) { Add-AuxiliaryPopupWheelHandlers -Control $child }
}

function Set-AuxiliaryPopupLayout {
    param([System.Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea,[Drawing.Rectangle]$OwnerBounds,[Drawing.Rectangle]$TriggerBounds = [Drawing.Rectangle]::Empty)
    if ($Form.Tag.Scale -ne 0) { throw 'Auxiliary surface has already been scaled.' }
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid auxiliary scale.' }
    Set-AuxiliaryControlBounds -Control $Form -Scale $Scale
    $state = $Form.Tag
    $state.Scale = $Scale
    $width = [Math]::Max(1,[Math]::Min($Form.ClientSize.Width,$WorkingArea.Width-12))
    $height = [Math]::Max(1,[Math]::Min($Form.ClientSize.Height,$WorkingArea.Height-12))
    $Form.ClientSize = [Drawing.Size]::new($width,$height)
    $state.Header.Width = $width
    $state.Close.Left = [Math]::Max(0,$width-$state.Close.Width-[int][Math]::Round(12*$Scale))
    $state.Title.Width = [Math]::Max(1,$state.Close.Left-$state.Title.Left)
    $state.Subtitle.Width = [Math]::Max(1,$width-$state.Subtitle.Left-[int][Math]::Round(16*$Scale))
    $viewportHeight = [Math]::Max(1,$height-$state.Viewport.Top)
    $contentHeight = [Math]::Max($viewportHeight,[int][Math]::Round($state.ContentHeight*$Scale))
    $range = $contentHeight-$viewportHeight
    $gutter = if ($range -gt 0) { [Math]::Min($width-1,[int][Math]::Round(8*$Scale)) } else { 0 }
    $state.Viewport.Size = [Drawing.Size]::new($width,$viewportHeight)
    $state.Body.Bounds = [Drawing.Rectangle]::new(0,0,$width-$gutter,$contentHeight)
    $state.Scroll.Bounds = [Drawing.Rectangle]::new($width-$gutter,0,$gutter,$viewportHeight)
    $state.Scroll.LargeChange = $viewportHeight
    $state.Scroll.SmallChange = [Math]::Max(1,[int][Math]::Round(60*$Scale))
    if ($Form.Name -eq 'LenovoConfigurationPopup') { Set-ConfigurationPopupWidth -Form $Form -Scale $Scale }
    $state.Scroll.Maximum = $range
    $state.Scroll.Value = 0
    $state.Scroll.Visible = ($range -gt 0 -and $gutter -gt 0)
    foreach ($control in $state.Body.Controls) {
        $control.Add_GotFocus({ param($sender,$eventArgs) Set-AuxiliaryPopupControlVisible -Control $sender })
    }
    Add-AuxiliaryPopupWheelHandlers -Control $Form
    $Form.Location = Get-AuxiliaryPopupLocation -WorkingArea $WorkingArea -OwnerBounds $OwnerBounds -SurfaceSize $Form.Size -TriggerBounds $TriggerBounds -Scale $Scale
}

# Owner-local black scrim. A separate layered, non-activating owned window
# dims the actual pixels (not desktop transparency or mutated control colors).
# It has no taskbar entry, no input/focus role and no independent lifetime.
function Initialize-AuxiliaryOwnerDimmer {
    if ('LenovoAuxiliaryOwnerDimmer' -as [type]) { return }
    $source = @'
using System;
using System.Drawing;
using System.Windows.Forms;

// A visual-only bridge; the existing modal forms retain their native bounds.
public sealed class LenovoAuxiliaryConnector : Form
{
    private Color fill;
    public Rectangle VisualBounds { get; private set; }
    public LenovoAuxiliaryConnector()
    {
        Name = "AuxiliaryConnector";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Opacity = 0.99;
        SetStyle(ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.AllPaintingInWmPaint, true);
    }

    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x00000080 | 0x08000000 | 0x00000020;
            return cp;
        }
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x0084) { m.Result = new IntPtr(-1); return; } // HTTRANSPARENT
        base.WndProc(ref m);
    }

    // All inputs are in screen coordinates. Never draw across the owner or
    // outside the actual work area; no right-side or overlapping bridge.
    public static Rectangle GetConnectorBounds(Rectangle work, Rectangle owner,
        Rectangle row, Rectangle child, double scale)
    {
        if (scale < 1.0 || scale > 5.0 || row.Width <= 0 || row.Height <= 0 ||
            !owner.Contains(row) || !work.Contains(row) || !work.Contains(child) ||
            row.Left != owner.Left || child.Right >= row.Left)
            return Rectangle.Empty;
        int gap = row.Left - child.Right;
        if (gap < 3 || gap > (int)Math.Round(8 * scale)) return Rectangle.Empty;
        int half = Math.Max(2, (int)Math.Round(7 * scale));
        int center = row.Top + row.Height / 2;
        if (center - half <= child.Top || center + half >= child.Bottom ||
            center - half < row.Top || center + half >= row.Bottom)
            return Rectangle.Empty;
        Rectangle bridge = new Rectangle(child.Right, center - half, gap, 2 * half + 1);
        return work.Contains(bridge) ? bridge : Rectangle.Empty;
    }

    private Point[] Triangle()
    {
        // WinForms enforces a native minimum size (16x16 on the hosted
        // Windows runner). The visible region must use the requested geometry,
        // never the larger backing window dimensions.
        return new Point[] { new Point(0, 0), new Point(VisualBounds.Width - 1, VisualBounds.Height / 2),
            new Point(0, VisualBounds.Height - 1) };
    }

    public void SetGeometry(Rectangle bounds, Color color)
    {
        fill = color;
        VisualBounds = bounds;
        Bounds = bounds;
        using (var path = new System.Drawing.Drawing2D.GraphicsPath())
        {
            path.AddPolygon(Triangle());
            Region old = Region;
            Region = new Region(path);
            if (old != null) old.Dispose();
        }
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        using (var brush = new SolidBrush(fill))
        using (var pen = new Pen(Color.FromArgb(108, 108, 108)))
        {
            Point[] triangle = Triangle();
            e.Graphics.FillPolygon(brush, triangle);
            e.Graphics.DrawLines(pen, triangle);
        }
    }
}

public sealed class LenovoAuxiliaryOwnerDimmer : Form
{
    private Form parent;
    private Form child;
    private Control row;
    private Control rowContainer;
    private readonly double scale;
    private readonly Color highlight;
    private readonly Color accent;
    private Color previousRowColor;
    private bool rowHighlighted;
    private bool childShown;
    private LenovoAuxiliaryConnector connector;
    public Rectangle HighlightedRowBounds { get; private set; }

    public LenovoAuxiliaryOwnerDimmer(Form owner, Control trigger, Form surface,
        double coordinateScale, Color highlightColor, Color accentColor)
    {
        if (owner == null) throw new ArgumentNullException("owner");
        parent = owner;
        child = surface;
        scale = coordinateScale;
        highlight = highlightColor;
        accent = accentColor;
        if (trigger != null && (trigger.Name == "SettingsPanel" || trigger.Name == "DefaultPanel")
            && trigger.FindForm() == owner)
        {
            row = trigger;
            rowContainer = row.Parent;
            previousRowColor = row.BackColor;
            row.Paint += PaintRow;
            row.BackColorChanged += KeepRowHighlight;
            row.LocationChanged += SyncBounds;
            row.SizeChanged += SyncBounds;
            row.VisibleChanged += SyncBounds;
            row.ParentChanged += SyncBounds;
            row.Disposed += SyncBounds;
            if (rowContainer != null) rowContainer.Layout += SyncBounds;
        }
        Name = "AuxiliaryOwnerDimmer";
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.Black;
        Opacity = 0.45;
        TopMost = owner.TopMost;
        parent.LocationChanged += SyncBounds;
        parent.SizeChanged += SyncBounds;
        parent.Layout += SyncBounds;
        parent.VisibleChanged += SyncBounds;
        child.LocationChanged += SyncBounds;
        child.SizeChanged += SyncBounds;
        child.VisibleChanged += SyncBounds;
        child.Shown += SurfaceShown;
        child.Disposed += SyncBounds;
        SyncBounds(null, EventArgs.Empty);
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            // TOOLWINDOW, NOACTIVATE, TRANSPARENT (layered-window hit testing).
            cp.ExStyle |= 0x00000080 | 0x08000000 | 0x00000020;
            return cp;
        }
    }

    private Rectangle GetVisibleRow(Rectangle ownerBounds)
    {
        if (row == null || row.IsDisposed || row.Disposing || !row.Visible ||
            row.FindForm() != parent || row.Parent != rowContainer)
            return Rectangle.Empty;
        Rectangle bounds = row.RectangleToScreen(row.ClientRectangle);
        if (!ownerBounds.Contains(bounds) || bounds.Width <= 0 || bounds.Height <= 0)
            return Rectangle.Empty;
        for (Control c = row.Parent; c != null; c = c.Parent)
        {
            if (!c.RectangleToScreen(c.ClientRectangle).Contains(bounds))
                return Rectangle.Empty;
            if (c == parent) break;
        }
        return bounds;
    }

    private void SetRowHighlight(bool enabled)
    {
        if (row == null || row.IsDisposed || row.Disposing || rowHighlighted == enabled) return;
        rowHighlighted = enabled;
        row.BackColor = enabled ? highlight : previousRowColor;
        row.Invalidate();
    }
    private void KeepRowHighlight(object sender, EventArgs args)
    {
        if (rowHighlighted && row.BackColor != highlight) row.BackColor = highlight;
    }
    private void PaintRow(object sender, PaintEventArgs args)
    {
        if (!rowHighlighted) return;
        using (var brush = new SolidBrush(accent))
            args.Graphics.FillRectangle(brush, 0, 0, Math.Max(1, (int)Math.Round(3 * scale)), row.Height);
    }
    private void SurfaceShown(object sender, EventArgs args)
    {
        childShown = true;
        SyncBounds(sender, args);
    }
    private void HideConnector()
    {
        if (connector != null && !connector.IsDisposed) connector.Hide();
    }

    private void SyncBounds(object sender, EventArgs args)
    {
        if (parent == null || parent.IsDisposed || parent.Disposing || IsDisposed || Disposing)
        {
            HideConnector();
            return;
        }
        Rectangle ownerBounds = parent.RectangleToScreen(parent.ClientRectangle);
        Bounds = ownerBounds;
        Rectangle rowBounds = GetVisibleRow(ownerBounds);
        bool usable = parent.Visible && child != null && !child.IsDisposed && !child.Disposing &&
            !rowBounds.IsEmpty;
        HighlightedRowBounds = usable ? rowBounds : Rectangle.Empty;
        Region next = null;
        if (usable)
        {
            next = new Region(ClientRectangle);
            Rectangle hole = rowBounds;
            hole.Offset(-ownerBounds.Left, -ownerBounds.Top);
            next.Exclude(hole);
        }
        Region old = Region;
        Region = next;
        if (old != null) old.Dispose();
        SetRowHighlight(usable);

        if (!usable || !child.Visible || !childShown)
        {
            HideConnector();
            return;
        }
        Rectangle bridge = LenovoAuxiliaryConnector.GetConnectorBounds(
            Screen.FromControl(parent).WorkingArea, ownerBounds, rowBounds, child.Bounds, scale);
        if (bridge.IsEmpty)
        {
            HideConnector();
            return;
        }
        Color fill = child.BackColor;
        Control header = child.Controls["AuxiliaryHeader"];
        if (header != null && header.RectangleToScreen(header.ClientRectangle).Contains(
                new Point(child.Right - 1, bridge.Top + bridge.Height / 2)))
            fill = header.BackColor;
        if (connector == null || connector.IsDisposed)
        {
            connector = new LenovoAuxiliaryConnector();
            connector.TopMost = child.TopMost;
        }
        connector.SetGeometry(bridge, fill);
        if (!connector.Visible)
        {
            connector.Owner = child;
            connector.Show();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (parent != null)
            {
                parent.LocationChanged -= SyncBounds;
                parent.SizeChanged -= SyncBounds;
                parent.Layout -= SyncBounds;
                parent.VisibleChanged -= SyncBounds;
                parent = null;
            }
            if (child != null)
            {
                child.LocationChanged -= SyncBounds;
                child.SizeChanged -= SyncBounds;
                child.VisibleChanged -= SyncBounds;
                child.Shown -= SurfaceShown;
                child.Disposed -= SyncBounds;
                child = null;
            }
            if (row != null)
            {
                row.Paint -= PaintRow;
                row.BackColorChanged -= KeepRowHighlight;
                row.LocationChanged -= SyncBounds;
                row.SizeChanged -= SyncBounds;
                row.VisibleChanged -= SyncBounds;
                row.ParentChanged -= SyncBounds;
                row.Disposed -= SyncBounds;
                if (rowContainer != null) rowContainer.Layout -= SyncBounds;
                SetRowHighlight(false);
                row = null;
                rowContainer = null;
            }
            if (connector != null)
            {
                connector.Dispose();
                connector = null;
            }
        }
        base.Dispose(disposing);
    }
}
'@
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition $source -ErrorAction Stop
}

# Modal ownership prevents competing main-popup selections while a child is
# open. No business action is dispatched by this lifecycle function.
function Show-OwnedAuxiliaryPopup {
    param([System.Windows.Forms.Form]$Form,[System.Windows.Forms.Control]$Owner)
    $dimmer = $null
    $ownerRefreshButton = $null
    try {
        if ($script:ActiveAuxiliaryPopup -or -not $Owner -or $Owner.IsDisposed) { return $null }
        $parent = $Owner.FindForm()
        if (-not $parent -or -not $parent.Visible) { return $null }
        $screen = [Windows.Forms.Screen]::FromControl($parent)
        $scale = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
        $triggerBounds = $Owner.RectangleToScreen($Owner.ClientRectangle)
        Set-AuxiliaryPopupLayout -Form $Form -Scale ([double]$scale) -WorkingArea $screen.WorkingArea -OwnerBounds $parent.Bounds -TriggerBounds $triggerBounds
        $script:ActiveAuxiliaryPopup = $Form
        if ($script:RefreshButton -and -not $script:RefreshButton.IsDisposed -and [object]::ReferenceEquals($script:RefreshButton.FindForm(),$parent)) {
            $ownerRefreshButton = $script:RefreshButton
            $ownerRefreshButton.Refresh()
        }
        Initialize-AuxiliaryOwnerDimmer
        $dimmer = [LenovoAuxiliaryOwnerDimmer]::new($parent,$Owner,$Form,[double]$scale,(Get-PopupNavigationHoverColor),$script:ColorAccent)
        # Show without activation before the child, which retains its normal
        # modal ownership, z-order and focus even on overlapping placement.
        $dimmer.Show($parent)
        # Both supported auxiliary surfaces receive keyboard focus once as
        # part of deliberate modal opening, after the dimmer's connector.
        if ($Form.Name -in @('LenovoConfigurationPopup','LenovoDefaultTargetPicker')) {
            $Form.Add_Shown({
                param($sender,$eventArgs)
                if ($sender.IsDisposed -or -not $sender.Visible -or
                    -not [object]::ReferenceEquals($script:ActiveAuxiliaryPopup,$sender) -or
                    $script:ActiveOwnedDialog) { return }
                [LenovoSettingsWindowInput]::ActivateInitialSurface($sender)
                if (-not $sender.Tag.Body.ContainsFocus) {
                    $target = $sender.Tag.Body.Controls | Where-Object {
                        $_.TabStop -and $_.CanFocus -and $_.Enabled -and $_.Visible
                    } | Sort-Object TabIndex | Select-Object -First 1
                    if ($target) { [void]$target.Focus() }
                    elseif ($sender.Tag.Close.CanFocus) { [void]$sender.Tag.Close.Focus() }
                }
            })
        }
        $result = $Form.ShowDialog($parent)
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return $Form.Tag.Choice }
        return $null
    }
    finally {
        try { if ($dimmer) { $dimmer.Dispose() } }
        finally {
            if ([object]::ReferenceEquals($script:ActiveAuxiliaryPopup,$Form)) { $script:ActiveAuxiliaryPopup = $null }
            try { $Form.Dispose() }
            finally {
                if ($dimmer -and $Owner -and -not $Owner.IsDisposed -and $Owner.Name -in @('SettingsPanel','DefaultPanel')) { Set-PopupNavigationRowHover -Control $Owner -Hover $false }
                if ($ownerRefreshButton -and -not $ownerRefreshButton.IsDisposed) { $ownerRefreshButton.Refresh() }
            }
        }
    }
}
