# LBS-144: independent, physical-pixel DPI layout for ToolStrip menus.
# A SystemAware PowerShell/WinForms host supplies the design 9pt text and
# fixed 260px menu independently of its 96/240 system DPI. Keep immutable
# geometry baselines; font point sizes stay at 9pt because GDI/WinForms
# converts points to pixels at its current DPI without further multiplication.
function Get-LenovoScaledMenuPadding {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Padding]$Padding,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    return [System.Windows.Forms.Padding]::new(
        [int][Math]::Round($Padding.Left * $Scale),
        [int][Math]::Round($Padding.Top * $Scale),
        [int][Math]::Round($Padding.Right * $Scale),
        [int][Math]::Round($Padding.Bottom * $Scale))
}

# ToolStripItem.Height is already dependent on the host's current DPI.
# It is NOT a 96-DPI design value. The Lenovo menus contain only one-line
# items and separators; choose their immutable 96-DPI design heights here.
function Get-LenovoMenuDesignItemHeight {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripItem]$Item)
    if ($Item -is [System.Windows.Forms.ToolStripSeparator]) { return [int]6 }
    return [int]24
}

function Set-LenovoMenuDpiLayout {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [Parameter(Mandatory=$true)][double]$Scale
    )
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'Invalid menu monitor scale.' }
    if (-not $script:LenovoMenuDesignBaselines) {
        $script:LenovoMenuDesignBaselines = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripDropDown,System.Object]'
    }
    if (-not $script:LenovoMenuDesignBaselines.ContainsKey($Menu)) {
        $widthProperty = $Menu.PSObject.Properties['TargetWidth']
        $width = if ($null -ne $widthProperty) { [int]$widthProperty.Value } else { 0 }
        $state = [pscustomobject]@{
            Width = $width
            Padding = $Menu.Padding
            ItemBases = (New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripItem,System.Object]')
            Scale = [double]0.0
        }
        $script:LenovoMenuDesignBaselines.Add($Menu,$state)
        $Menu.Add_Disposed({
            if ($script:LenovoMenuDesignBaselines) {
                [void]$script:LenovoMenuDesignBaselines.Remove($this)
            }
        })
    }
    $state = $script:LenovoMenuDesignBaselines[$Menu]
    foreach ($item in $Menu.Items) {
        if (-not $state.ItemBases.ContainsKey($item)) {
            $state.ItemBases.Add($item,[pscustomobject]@{
                Height = Get-LenovoMenuDesignItemHeight -Item $item
                Padding = $item.Padding
                FontStyle = $item.Font.Style
            })
        }
    }
    if ([Math]::Abs($state.Scale - $Scale) -lt 0.001) { return $false }
    $Menu.SuspendLayout()
    try {
        # Fonts remain 9pt: DPI affects the rendered pixel line height.
        # Submenus must not inherit any separately transformed parent font.
        $Menu.Font = [Drawing.Font]::new('Segoe UI',[single]9.0,[Drawing.FontStyle]::Regular)
        $Menu.Padding = Get-LenovoScaledMenuPadding -Padding $state.Padding -Scale $Scale
        if ($null -ne $Menu.PSObject.Properties['TargetWidth']) {
            $Menu.TargetWidth = [Math]::Max(1,[int][Math]::Round($state.Width * $Scale))
        }
        foreach ($item in $Menu.Items) {
            $base = $state.ItemBases[$item]
            $item.AutoSize = $false
            $item.Padding = Get-LenovoScaledMenuPadding -Padding $base.Padding -Scale $Scale
            $item.Font = [Drawing.Font]::new('Segoe UI',[single]9.0,[Drawing.FontStyle]$base.FontStyle)
            $item.Height = [Math]::Max(1,[int][Math]::Round($base.Height * $Scale))
        }
    }
    finally { $Menu.ResumeLayout($true) }
    $state.Scale = [double]$Scale
    return $true
}

function Initialize-LenovoMenuAppearance {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.ToolStripDropDown]$Menu,
        [int]$Radius = 0
    )
    if ($Menu.Tag -eq '__LenovoFlatMenu') { return }
    $Menu.Tag = '__LenovoFlatMenu'
    $isSubmenu = ($null -ne $Menu.OwnerItem)
    $Menu.BackColor = if ($isSubmenu) { [Drawing.Color]::FromArgb(32, 32, 32) } else { [Drawing.Color]::FromArgb(22, 22, 22) }
    $Menu.ForeColor = $script:ColorPrimary
    $Menu.Renderer = $script:MenuRenderer
    # v0.2.32: square, borderless root menu with no native check/image gutter.
    # Submenus use a lighter panel plus neutral edge. Selection, separators,
    # checks and arrows are painted centrally in owner coordinates.
    $Menu.DropShadowEnabled = $false
    if ($Menu -is [System.Windows.Forms.ToolStripDropDownMenu]) {
        $Menu.ShowCheckMargin = $false
        $Menu.ShowImageMargin = $false
    }
    $Menu.Padding = if ($isSubmenu) {
        New-Object System.Windows.Forms.Padding(1, 2, 1, 2)
    }
    else {
        New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    }
    # Only one paint snapshot per opening, rather than every hover redraw.
    if (-not $script:LenovoDpiMenuPaintRecorded) {
        $script:LenovoDpiMenuPaintRecorded = New-Object 'System.Collections.Generic.Dictionary[System.Windows.Forms.ToolStripDropDown,System.Boolean]'
    }
    $Menu.Add_Opening({
        try {
            $script:LenovoDpiMenuPaintRecorded[$this] = $false
            $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
            $factor = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
            [void](Set-LenovoMenuDpiLayout -Menu $this -Scale ([double]$factor))
            $this.Region = $null
            [LenovoMenuLayout]::PrepareItems($this)
            [LenovoMenuChrome]::Apply($this)
            Write-LenovoDpiWindowEvent -Control $this -Role $(if ($this.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'opening' -Screen $screen -RequestedScale ([double]$factor)
        } catch { }
    })
    $Menu.Add_Opened({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
            [LenovoMenuLayout]::PrepareItems($this)
            Write-LenovoDpiWindowEvent -Control $this -Role $(if ($this.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'opened'
        } catch { }
    })
    $Menu.Add_Paint({
        param($sender,$paintArgs)
        try {
            if ($sender.Visible -and -not $script:LenovoDpiMenuPaintRecorded[$sender]) {
                $script:LenovoDpiMenuPaintRecorded[$sender] = $true
                Write-LenovoDpiWindowEvent -Control $sender -Role $(if ($sender.OwnerItem) { 'submenu' } else { 'tray-root' }) -Phase 'paint' -PaintDpiX $paintArgs.Graphics.DpiX -PaintDpiY $paintArgs.Graphics.DpiY
            }
        } catch { }
    })
    $Menu.Add_SizeChanged({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    # v0.3.2: Full-menu hover invalidation is implemented directly by the
    # custom drop-down classes. No delayed BeginInvoke/tail-paint workaround.
}

# LBS-244: common rendering, independent native ToolTip instances and timing.
function New-LenovoDarkTooltip {
    param([int]$InitialDelay = 350,[int]$ReshowDelay = 100,[int]$AutoPopDelay = 8000,[switch]$Animate)
    if (-not ('LenovoDarkTooltip' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;

public sealed class LenovoDarkTooltip : ToolTip {
    private readonly Func<Control, double> coordinateScale;
    private Control manualOwner;
    private Form manualForm;
    private string manualText;
    private static readonly Color Surface = Color.FromArgb(28,28,28);
    private static readonly Color Ink = Color.FromArgb(238,238,238);
    private static readonly Color Edge = Color.FromArgb(76,76,76);
    private const TextFormatFlags Flags = TextFormatFlags.WordBreak |
        TextFormatFlags.TextBoxControl | TextFormatFlags.NoPrefix |
        TextFormatFlags.NoPadding;

    public LenovoDarkTooltip(Func<Control, double> scale, int initial, int reshow, int duration, bool animate) {
        if (scale == null) throw new ArgumentNullException("scale");
        coordinateScale = scale;
        OwnerDraw = !SystemInformation.HighContrast;
        ShowAlways = true;
        UseAnimation = animate;
        UseFading = animate;
        InitialDelay = initial;
        ReshowDelay = reshow;
        AutoPopDelay = duration;
        StripAmpersands = false;
        if (OwnerDraw) {
            BackColor = Surface;
            ForeColor = Ink;
            Popup += OnHintPopup;
            Draw += OnHintDraw;
        }
    }

    private static double ValidScale(double scale) {
        if (Double.IsNaN(scale) || Double.IsInfinity(scale) || scale < 1 || scale > 5)
            throw new ArgumentOutOfRangeException("scale");
        return scale;
    }

    private static int Px(double n, double scale) {
        return Math.Max(1, (int)Math.Round(n * ValidScale(scale), MidpointRounding.AwayFromZero));
    }

    private static Font HintFont(double scale) {
        // Pixel units: the effective WinForms coordinate scale already
        // accounts for awareness/system DPI. Do not multiply point fonts.
        return new Font("Segoe UI", (float)(8.5 * 96.0 / 72.0 * ValidScale(scale)),
            FontStyle.Regular, GraphicsUnit.Pixel);
    }

    public static Size MeasureHint(string text, double scale, Rectangle work) {
        if (work.Width <= 0 || work.Height <= 0) throw new ArgumentException("Invalid work area.");
        int px = Px(10,scale), py = Px(6,scale);
        int maxWidth = Math.Min(work.Width, Px(340,scale));
        int textWidth = Math.Max(1,maxWidth - 2 * px);
        using (Font font = HintFont(scale)) {
            Size measured = TextRenderer.MeasureText(text ?? String.Empty, font,
                new Size(textWidth,32767), Flags);
            int width = Math.Min(maxWidth, Math.Max(Px(120,scale), measured.Width + 2 * px));
            int height = Math.Min(work.Height, Math.Max(Px(30,scale), measured.Height + 2 * py));
            return new Size(Math.Max(1,width), Math.Max(1,height));
        }
    }

    public static Point PlaceHint(Rectangle anchor, Size hint, Rectangle work, double scale) {
        int gap = Px(8,scale);
        int x = anchor.Right + gap;
        if ((long)x + hint.Width > work.Right) x = anchor.Left - hint.Width - gap;
        int y = anchor.Top + (anchor.Height - hint.Height)/2;
        x = Math.Max(work.Left,Math.Min(work.Right - hint.Width,x));
        y = Math.Max(work.Top,Math.Min(work.Bottom - hint.Height,y));
        return new Point(x,y);
    }

    public static void PaintHint(Graphics graphics, Rectangle bounds, string text, double scale) {
        int px = Px(10,scale), py = Px(6,scale);
        using (SolidBrush bg = new SolidBrush(Surface))
        using (Pen border = new Pen(Edge))
        using (Font font = HintFont(scale)) {
            graphics.FillRectangle(bg,bounds);
            graphics.DrawRectangle(border,bounds.X,bounds.Y,Math.Max(0,bounds.Width-1),Math.Max(0,bounds.Height-1));
            Rectangle body = new Rectangle(bounds.X+px,bounds.Y+py,
                Math.Max(1,bounds.Width-2*px),Math.Max(1,bounds.Height-2*py));
            TextRenderer.DrawText(graphics,text ?? String.Empty,font,body,Ink,Flags);
        }
    }

    private void OnHintPopup(object sender, PopupEventArgs e) {
        Control owner = e.AssociatedControl;
        if (owner == null || owner.IsDisposed) { e.Cancel = true; return; }
        string text = Object.ReferenceEquals(owner,manualOwner) ? manualText : GetToolTip(owner);
        if (String.IsNullOrWhiteSpace(text)) { e.Cancel = true; return; }
        e.ToolTipSize = MeasureHint(text,coordinateScale(owner),Screen.FromControl(owner).WorkingArea);
    }

    private void OnHintDraw(object sender, DrawToolTipEventArgs e) {
        Control owner = e.AssociatedControl;
        if (owner == null || owner.IsDisposed) return;
        PaintHint(e.Graphics,e.Bounds,e.ToolTipText,coordinateScale(owner));
    }

    public Control ManualOwner { get { return manualOwner; } }

    public void ShowManual(Control owner, string text) {
        if (owner == null || owner.IsDisposed || !owner.Visible || String.IsNullOrWhiteSpace(text)) return;
        HideManual();
        manualOwner = owner;
        manualText = text;
        manualForm = owner.FindForm();
        owner.VisibleChanged += OnManualOwnerVisibility;
        owner.HandleDestroyed += OnManualOwnerEnded;
        owner.Disposed += OnManualOwnerEnded;
        if (manualForm != null) manualForm.Deactivate += OnManualOwnerEnded;
        try {
            double scale = coordinateScale(owner);
            Rectangle work = Screen.FromControl(owner).WorkingArea;
            Rectangle anchor = new Rectangle(owner.PointToScreen(Point.Empty),owner.Size);
            Point client = owner.PointToClient(PlaceHint(anchor,MeasureHint(text,scale,work),work,scale));
            Show(text,owner,client.X,client.Y,AutoPopDelay);
        } catch {
            HideManual();
            throw;
        }
    }

    private void OnManualOwnerVisibility(object sender, EventArgs e) {
        if (manualOwner != null && !manualOwner.Visible) HideManual();
    }

    private void OnManualOwnerEnded(object sender, EventArgs e) { HideManual(); }

    public void HideManual() {
        Control owner = manualOwner;
        Form form = manualForm;
        manualOwner = null;
        manualForm = null;
        manualText = null;
        if (owner != null) {
            owner.VisibleChanged -= OnManualOwnerVisibility;
            owner.HandleDestroyed -= OnManualOwnerEnded;
            owner.Disposed -= OnManualOwnerEnded;
        }
        if (form != null) form.Deactivate -= OnManualOwnerEnded;
        if (owner != null && !owner.IsDisposed && owner.IsHandleCreated) Hide(owner);
    }

    protected override void Dispose(bool disposing) {
        if (disposing) HideManual();
        base.Dispose(disposing);
    }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
    }
    $scale = [Func[Windows.Forms.Control,double]]{
        param($owner)
        if (Get-Command Get-LenovoUiCoordinateScale -ErrorAction SilentlyContinue) {
            return [double](Get-LenovoUiCoordinateScale -Screen ([Windows.Forms.Screen]::FromControl($owner))).Factor
        }
        # Isolated native fixtures need not load the application's DPI provider.
        $graphics = $owner.CreateGraphics()
        try { return [Math]::Max(1.0,[Math]::Min(5.0,[double]$graphics.DpiX / 96.0)) }
        finally { $graphics.Dispose() }
    }
    return [LenovoDarkTooltip]::new($scale,$InitialDelay,$ReshowDelay,$AutoPopDelay,[bool]$Animate)
}

function Ensure-DarkActionTooltip {
    if (-not $script:DarkActionTooltip) {
        $script:DarkActionTooltip = New-LenovoDarkTooltip -InitialDelay 0 -ReshowDelay 0 -AutoPopDelay 3500
    }
    return $script:DarkActionTooltip
}

function Show-DarkActionTooltip {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Owner,
        [Parameter(Mandatory=$true)][string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text) -or $Owner.IsDisposed -or -not $Owner.Visible) { return }
    $tip = Ensure-DarkActionTooltip
    $tip.ShowManual($Owner,$Text)
    $script:DarkActionTooltipOwner = $tip.ManualOwner
}

function Hide-DarkActionTooltip {
    if ($script:DarkActionTooltip) { $script:DarkActionTooltip.HideManual() }
    $script:DarkActionTooltipOwner = $null
}
