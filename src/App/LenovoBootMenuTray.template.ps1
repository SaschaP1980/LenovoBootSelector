#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$HideConsole,
    [switch]$BackgroundRefresh,
    [string]$BackgroundResultPath,
    [switch]$BackgroundRefreshStorage,
    [switch]$BackgroundRefreshFirmware,
    [switch]$UpdateCheck,
    [switch]$UpdatePrepare,
    [string]$UpdateResultPath,
    [string]$UpdateManifestPath,
    [string]$RuntimeSessionId
)

$ErrorActionPreference = 'Stop'

function Start-LenovoBootSelectorHidden {
    $launcherPath = Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs'
    if (-not (Test-Path -LiteralPath $launcherPath)) { return $false }

    try {
        $wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $wscriptPath
        $psi.Arguments = ('"{0}"' -f $launcherPath)
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($psi)
        return $true
    }
    catch {
        return $false
    }
}

# @include src/UI/StartupRecoveryDialog.ps1

# v0.2.18: The tray intentionally runs unelevated. Privileged firmware operations
# are delegated to fixed, pre-authorized Windows Scheduled Tasks. No custom EXE
# runs under SYSTEM.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# v0.3.3: item-local ToolStrip renderer coordinate hotfix; v0.2.22 TaskBroker security architecture remains unchanged.
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class LenovoMenuColorTable : ProfessionalColorTable
{
    private readonly Color accent = Color.FromArgb(225, 37, 27);
    private readonly Color bg = Color.FromArgb(22, 22, 22);
    private readonly Color selected = Color.FromArgb(64, 31, 29);

    public LenovoMenuColorTable() { UseSystemColors = false; }
    public override Color ToolStripDropDownBackground { get { return bg; } }
    public override Color ImageMarginGradientBegin { get { return bg; } }
    public override Color ImageMarginGradientMiddle { get { return bg; } }
    public override Color ImageMarginGradientEnd { get { return bg; } }
    public override Color ImageMarginRevealedGradientBegin { get { return bg; } }
    public override Color ImageMarginRevealedGradientMiddle { get { return bg; } }
    public override Color ImageMarginRevealedGradientEnd { get { return bg; } }
    public override Color MenuBorder { get { return bg; } }
    public override Color MenuItemBorder { get { return selected; } }
    public override Color MenuItemSelected { get { return selected; } }
    public override Color MenuItemSelectedGradientBegin { get { return selected; } }
    public override Color MenuItemSelectedGradientEnd { get { return selected; } }
    public override Color MenuItemPressedGradientBegin { get { return selected; } }
    public override Color MenuItemPressedGradientMiddle { get { return selected; } }
    public override Color MenuItemPressedGradientEnd { get { return selected; } }
    public override Color SeparatorDark { get { return accent; } }
    public override Color SeparatorLight { get { return bg; } }
    public override Color CheckBackground { get { return bg; } }
    public override Color CheckSelectedBackground { get { return selected; } }
    public override Color CheckPressedBackground { get { return selected; } }
    public override Color ButtonSelectedHighlight { get { return selected; } }
    public override Color ButtonSelectedHighlightBorder { get { return selected; } }
    public override Color ToolStripBorder { get { return bg; } }
    public override Color ToolStripGradientBegin { get { return bg; } }
    public override Color ToolStripGradientMiddle { get { return bg; } }
    public override Color ToolStripGradientEnd { get { return bg; } }
}

public sealed class LenovoMenuRenderer : ToolStripProfessionalRenderer
{
    private readonly Color accent = Color.FromArgb(225, 37, 27);
    private readonly Color rootBg = Color.FromArgb(22, 22, 22);
    private readonly Color submenuBg = Color.FromArgb(32, 32, 32);
    private readonly Color submenuEdge = Color.FromArgb(68, 68, 68);
    private readonly Color selected = Color.FromArgb(64, 31, 29);
    private readonly Color arrow = Color.FromArgb(214, 214, 214);
    private readonly Color disabled = Color.FromArgb(105, 105, 105);

    public LenovoMenuRenderer() : base(new LenovoMenuColorTable()) { }

    private static bool IsSubmenu(ToolStrip strip)
    {
        ToolStripDropDown dd = strip as ToolStripDropDown;
        return dd != null && dd.OwnerItem != null;
    }

    private static Rectangle FullRowBounds(ToolStripDropDown menu, ToolStripItem item)
    {
        int inset = IsSubmenu(menu) ? 1 : 0;

        // ToolStrip item render callbacks use an item-local Graphics origin.
        // Convert the DropDown client edges into that local coordinate system
        // instead of applying the item offset a second time.
        int left = inset - item.Bounds.Left;
        int right = menu.ClientRectangle.Right - inset - item.Bounds.Left;
        int width = Math.Max(1, right - left);
        return new Rectangle(left, 0, width, Math.Max(1, item.Height));
    }

    private void DrawRightCheck(Graphics g, Rectangle row, bool enabled)
    {
        int size = 14;
        int x = Math.Max(row.Left + 2, row.Right - 24);
        int y = row.Top + Math.Max(1, (row.Height - size) / 2);
        Rectangle box = new Rectangle(x, y, size, size);
        SmoothingMode oldMode = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (Brush brush = new SolidBrush(enabled ? accent : disabled))
            g.FillRectangle(brush, box);
        using (Pen pen = new Pen(Color.White, 1.8f))
        {
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            g.DrawLines(pen, new Point[] {
                new Point(box.Left + 3, box.Top + 7),
                new Point(box.Left + 6, box.Top + 10),
                new Point(box.Left + 11, box.Top + 4)
            });
        }
        g.SmoothingMode = oldMode;
    }

    private void DrawRightArrow(Graphics g, Rectangle row, bool enabled)
    {
        int cx = row.Right - 15;
        int cy = row.Top + (row.Height / 2);
        Color c = enabled ? arrow : disabled;
        using (Brush brush = new SolidBrush(c))
        {
            Point[] points = new Point[] {
                new Point(cx - 2, cy - 4),
                new Point(cx + 2, cy),
                new Point(cx - 2, cy + 4)
            };
            g.FillPolygon(brush, points);
        }
    }

    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        if (dropDown == null)
        {
            base.OnRenderToolStripBackground(e);
            return;
        }

        bool submenu = IsSubmenu(dropDown);
        GraphicsState ownerState = e.Graphics.Save();
        e.Graphics.ResetClip();
        using (Brush bgBrush = new SolidBrush(submenu ? submenuBg : rootBg))
            e.Graphics.FillRectangle(bgBrush, new Rectangle(Point.Empty, dropDown.ClientRectangle.Size));

        // v0.3.4: Paint the active row in ToolStrip owner coordinates.
        // Per-item renderer Graphics instances are clipped by WinForms to the
        // item/content area and cannot reliably cover the reserved right-side
        // padding/grip region. The ToolStrip background renderer owns the full
        // client surface, so the highlight can extend to the true client edge.
        ToolStripMenuItem hotItem = LenovoMenuLayout.GetVisualHotItem(dropDown);
        if (hotItem != null && hotItem.Enabled)
        {
            int inset = submenu ? 1 : 0;
            int left = dropDown.ClientRectangle.Left + inset;
            int right = dropDown.ClientRectangle.Right - inset;
            int top = Math.Max(dropDown.ClientRectangle.Top, hotItem.Bounds.Top);
            int bottom = Math.Min(dropDown.ClientRectangle.Bottom, hotItem.Bounds.Bottom);
            if (right > left && bottom > top)
            {
                using (Brush selectionBrush = new SolidBrush(selected))
                    e.Graphics.FillRectangle(selectionBrush, new Rectangle(left, top, right - left, bottom - top));
            }
        }

        // Submenus remain visually distinct without any red outer border.
        if (submenu && dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            using (Pen edgePen = new Pen(submenuEdge, 1f))
                e.Graphics.DrawRectangle(edgePen, 0, 0, dropDown.ClientSize.Width - 1, dropDown.ClientSize.Height - 1);
        }
        e.Graphics.Restore(ownerState);
    }

    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
    {
        if (e.ToolStrip is ToolStripDropDown) return;
        base.OnRenderToolStripBorder(e);
    }

    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        if (dropDown == null)
        {
            base.OnRenderSeparator(e);
            return;
        }

        bool submenu = IsSubmenu(dropDown);
        int inset = submenu ? 1 : 0;

        // Separator render callbacks are item-local as well. Translate only
        // the horizontal DropDown client edges; Y starts at this item.
        int left = inset - e.Item.Bounds.Left;
        int right = dropDown.ClientRectangle.Right - 1 - inset - e.Item.Bounds.Left;
        int y = Math.Max(0, e.Item.Height / 2);
        GraphicsState state = e.Graphics.Save();
        e.Graphics.ResetClip();
        using (Pen pen = new Pen(accent, 1f))
            e.Graphics.DrawLine(pen, left, y, Math.Max(left + 1, right), y);
        e.Graphics.Restore(state);
    }

    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
    {
        ToolStripDropDown dropDown = e.ToolStrip as ToolStripDropDown;
        ToolStripMenuItem item = e.Item as ToolStripMenuItem;
        if (dropDown == null || item == null)
        {
            base.OnRenderMenuItemBackground(e);
            return;
        }

        Rectangle row = FullRowBounds(dropDown, item);
        GraphicsState state = e.Graphics.Save();
        e.Graphics.ResetClip();

        // v0.3.4: The full-width selection background is painted once in
        // OnRenderToolStripBackground, where the Graphics surface spans the
        // actual DropDown client area. Keep this item-local pass for indicators
        // only; drawing the highlight here reintroduces the right-edge clipping.

        // Indicators remain item-local and are painted after the background.
        if (item.HasDropDownItems)
            DrawRightArrow(e.Graphics, row, item.Enabled);
        else if (item.Checked)
            DrawRightCheck(e.Graphics, row, item.Enabled);

        e.Graphics.Restore(state);
    }

    protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
    {
        // Checked state is rendered centrally by OnRenderMenuItemBackground.
    }

    protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
    {
        // Submenu arrows are rendered centrally by OnRenderMenuItemBackground.
    }
}

public static class LenovoMenuLayout
{
    public static ToolStripItem HitTestRow(ToolStripDropDown menu, Point clientPoint)
    {
        if (menu == null || menu.IsDisposed || !menu.ClientRectangle.Contains(clientPoint)) return null;
        foreach (ToolStripItem item in menu.Items)
        {
            if (item == null || !item.Available || !(item is ToolStripMenuItem)) continue;
            Rectangle bounds = item.Bounds;
            if (clientPoint.Y >= bounds.Top && clientPoint.Y < bounds.Bottom)
                return item;
        }
        return null;
    }

    public static ToolStripMenuItem GetVisualHotItem(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return null;
        try
        {
            Point point = menu.PointToClient(Control.MousePosition);
            if (menu.ClientRectangle.Contains(point))
            {
                ToolStripMenuItem hit = HitTestRow(menu, point) as ToolStripMenuItem;
                if (hit != null && hit.Available) return hit;
                return null;
            }
        }
        catch { }

        // Keyboard navigation and a parent item with an open child submenu use
        // the native Selected/Pressed state while the pointer is outside.
        foreach (ToolStripItem candidate in menu.Items)
        {
            ToolStripMenuItem menuItem = candidate as ToolStripMenuItem;
            if (menuItem == null || !menuItem.Available) continue;
            if (menuItem.Pressed || menuItem.Selected) return menuItem;
        }
        return null;
    }

    public static void StretchItems(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return;
        int width = Math.Max(1, menu.ClientSize.Width - menu.Padding.Horizontal);
        foreach (ToolStripItem item in menu.Items)
        {
            if (item == null || !item.Available) continue;
            item.Margin = Padding.Empty;
            int height = Math.Max(1, item.Height);
            if (height <= 1)
                height = Math.Max(1, item.GetPreferredSize(Size.Empty).Height);
            item.AutoSize = false;
            if (item.Width != width || item.Height != height)
                item.Size = new Size(width, height);
        }
    }

    public static void PrepareItems(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed) return;
        StretchItems(menu);
        InvalidateWholeMenu(menu);
    }

    public static void InvalidateWholeMenu(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed || !menu.IsHandleCreated) return;
        try
        {
            menu.Invalidate(new Rectangle(Point.Empty, menu.ClientSize), false);
            menu.Update();
        }
        catch { }
    }
}

public sealed class LenovoContextMenuStrip : ContextMenuStrip
{
    public int TargetWidth { get; set; }
    public LenovoContextMenuStrip()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    public override Size GetPreferredSize(Size constrainingSize)
    {
        Size size = base.GetPreferredSize(constrainingSize);
        if (size.Width < TargetWidth) size.Width = TargetWidth;
        return size;
    }

    protected override void OnLayout(LayoutEventArgs e)
    {
        base.OnLayout(e);
        LenovoMenuLayout.StretchItems(this);
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }
}

public sealed class LenovoDropDownMenu : ToolStripDropDownMenu
{
    public int TargetWidth { get; set; }
    public LenovoDropDownMenu()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    public override Size GetPreferredSize(Size constrainingSize)
    {
        Size size = base.GetPreferredSize(constrainingSize);
        if (size.Width < TargetWidth) size.Width = TargetWidth;
        return size;
    }

    protected override void OnLayout(LayoutEventArgs e)
    {
        base.OnLayout(e);
        LenovoMenuLayout.StretchItems(this);
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        LenovoMenuLayout.InvalidateWholeMenu(this);
    }
}

public static class LenovoMenuChrome
{
    private const int GWL_STYLE = -16;
    private const int GWL_EXSTYLE = -20;

    private const long WS_BORDER = 0x00800000L;
    private const long WS_DLGFRAME = 0x00400000L;
    private const long WS_THICKFRAME = 0x00040000L;
    private const long WS_EX_DLGMODALFRAME = 0x00000001L;
    private const long WS_EX_WINDOWEDGE = 0x00000100L;
    private const long WS_EX_CLIENTEDGE = 0x00000200L;
    private const long WS_EX_STATICEDGE = 0x00020000L;

    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;

    private const int DWMWA_NCRENDERING_POLICY = 2;
    private const int DWMNCRP_DISABLED = 1;
    private const int DWMWA_BORDER_COLOR = 34;
    private const uint DWMWA_COLOR_NONE = 0xFFFFFFFEu;

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    private static extern IntPtr SetWindowLong32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);
    [DllImport("dwmapi.dll", EntryPoint = "DwmSetWindowAttribute")]
    private static extern int DwmSetWindowAttributeUInt(IntPtr hwnd, int dwAttribute, ref uint pvAttribute, int cbAttribute);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLong32(hWnd, nIndex);
    }

    private static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr value)
    {
        return IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, nIndex, value) : SetWindowLong32(hWnd, nIndex, value);
    }

    public static void Apply(ToolStripDropDown menu)
    {
        if (menu == null || menu.IsDisposed || !menu.IsHandleCreated) return;

        IntPtr hwnd = menu.Handle;
        long style = GetWindowLongPtr(hwnd, GWL_STYLE).ToInt64();
        long exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();

        style &= ~(WS_BORDER | WS_DLGFRAME | WS_THICKFRAME);
        exStyle &= ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE);

        SetWindowLongPtr(hwnd, GWL_STYLE, new IntPtr(style));
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, new IntPtr(exStyle));

        try
        {
            int policy = DWMNCRP_DISABLED;
            DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, ref policy, sizeof(int));
        }
        catch { }

        // Windows 11 can draw a DWM frame border even for popup/tool windows.
        // Explicitly suppress that system border; the client renderer owns all visible menu chrome.
        try
        {
            uint noBorder = DWMWA_COLOR_NONE;
            DwmSetWindowAttributeUInt(hwnd, DWMWA_BORDER_COLOR, ref noBorder, sizeof(uint));
        }
        catch { }

        SetWindowPos(
            hwnd,
            IntPtr.Zero,
            0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
        );
    }
}

public sealed class LenovoCheckBox : CheckBox
{
    public Color AccentColor { get; set; }
    public Color BoxBackColor { get; set; }
    public Color BoxBorderColor { get; set; }
    public Color HoverColor { get; set; }
    private bool hovering;

    public LenovoCheckBox()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        AccentColor = Color.FromArgb(225, 37, 27);
        BoxBackColor = Color.FromArgb(30, 30, 30);
        BoxBorderColor = Color.FromArgb(82, 82, 82);
        HoverColor = Color.FromArgb(242, 59, 49);
        Cursor = Cursors.Hand;
        AutoSize = false;
    }

    protected override void OnMouseEnter(EventArgs e) { hovering = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovering = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle box = new Rectangle(1, Math.Max(1, (Height - 15) / 2), 14, 14);
        Color fill = Checked ? (hovering ? HoverColor : AccentColor) : BoxBackColor;
        using (Brush b = new SolidBrush(fill)) e.Graphics.FillRectangle(b, box);
        using (Pen p = new Pen(Checked ? AccentColor : BoxBorderColor, 1f)) e.Graphics.DrawRectangle(p, box);
        if (Checked)
        {
            using (Pen p = new Pen(Color.White, 1.8f))
            {
                p.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                p.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                e.Graphics.DrawLines(p, new Point[] { new Point(4, box.Top + 7), new Point(7, box.Top + 10), new Point(12, box.Top + 4) });
            }
        }
        TextRenderer.DrawText(e.Graphics, Text, Font, new Rectangle(23, 0, Math.Max(0, Width - 23), Height), Enabled ? ForeColor : Color.FromArgb(105,105,105), TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
    }
}


public sealed class LenovoVerticalScrollBar : Control
{
    private int minimum = 0;
    private int maximum = 0;
    private int value = 0;
    private int largeChange = 100;
    private int smallChange = 32;
    private bool dragging = false;
    private bool hoverThumb = false;
    private int dragOffset = 0;

    public event EventHandler ValueChanged;

    public Color TrackColor { get; set; }
    public Color ThumbColor { get; set; }
    public Color ThumbHoverColor { get; set; }

    public LenovoVerticalScrollBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        TrackColor = Color.FromArgb(18, 18, 18);
        ThumbColor = Color.FromArgb(225, 37, 27);
        ThumbHoverColor = Color.FromArgb(242, 59, 49);
        Width = 12;
        Cursor = Cursors.Hand;
        TabStop = false;
    }

    public int Minimum
    {
        get { return minimum; }
        set { minimum = value; if (maximum < minimum) maximum = minimum; Value = this.value; Invalidate(); }
    }

    public int Maximum
    {
        get { return maximum; }
        set { maximum = Math.Max(minimum, value); Value = this.value; Invalidate(); }
    }

    public int LargeChange
    {
        get { return largeChange; }
        set { largeChange = Math.Max(1, value); Invalidate(); }
    }

    public int SmallChange
    {
        get { return smallChange; }
        set { smallChange = Math.Max(1, value); }
    }

    public int Value
    {
        get { return value; }
        set
        {
            int next = Math.Max(minimum, Math.Min(maximum, value));
            if (next == this.value) return;
            this.value = next;
            Invalidate();
            if (ValueChanged != null) ValueChanged(this, EventArgs.Empty);
        }
    }

    private Rectangle GetThumbRectangle()
    {
        if (Height <= 0 || maximum <= minimum) return Rectangle.Empty;
        int logicalRange = Math.Max(1, maximum - minimum);
        int thumbHeight = (int)Math.Round((double)Height * largeChange / (logicalRange + largeChange));
        thumbHeight = Math.Max(34, Math.Min(Height, thumbHeight));
        int travel = Math.Max(0, Height - thumbHeight);
        int top = travel == 0 ? 0 : (int)Math.Round((double)(value - minimum) / logicalRange * travel);
        return new Rectangle(2, top, Math.Max(3, Width - 4), thumbHeight);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(TrackColor);
        Rectangle thumb = GetThumbRectangle();
        if (!thumb.IsEmpty)
        {
            using (Brush b = new SolidBrush(hoverThumb || dragging ? ThumbHoverColor : ThumbColor))
                e.Graphics.FillRectangle(b, thumb);
        }
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        Rectangle thumb = GetThumbRectangle();
        if (thumb.Contains(e.Location))
        {
            dragging = true;
            dragOffset = e.Y - thumb.Top;
            Capture = true;
        }
        else if (e.Y < thumb.Top) Value -= largeChange;
        else Value += largeChange;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        Rectangle thumb = GetThumbRectangle();
        bool nextHover = thumb.Contains(e.Location);
        if (nextHover != hoverThumb) { hoverThumb = nextHover; Invalidate(); }
        if (!dragging || thumb.IsEmpty) return;
        int travel = Math.Max(1, Height - thumb.Height);
        int top = Math.Max(0, Math.Min(travel, e.Y - dragOffset));
        int logicalRange = Math.Max(1, maximum - minimum);
        Value = minimum + (int)Math.Round((double)top / travel * logicalRange);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        dragging = false;
        Capture = false;
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        if (!dragging) { hoverThumb = false; Invalidate(); }
    }
}
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

if ($HideConsole) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LenovoBootMenuConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $consoleHandle = [LenovoBootMenuConsoleWindow]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
        [LenovoBootMenuConsoleWindow]::ShowWindow($consoleHandle, 0) | Out-Null
    }
}

# Prevent duplicate tray instances. Internal background-refresh workers deliberately
# skip the tray mutex because they do not create UI or a NotifyIcon. Ownership is
# tested explicitly: an existing-but-free named mutex is not an active instance.
$mutex = $null
$mutexOwned = $false
$singleInstanceMutexState = 'not-applicable'
$singleInstanceGraceMs = 500
if (-not $BackgroundRefresh -and -not $UpdateCheck -and -not $UpdatePrepare) {
    $singleInstanceMutexState = 'busy'
    $mutex = [System.Threading.Mutex]::new($false, 'Local\LenovoBootMenuTray')
    try {
        try {
            $mutexOwned = $mutex.WaitOne(0, $false)
            if ($mutexOwned) { $singleInstanceMutexState = 'acquired' }
        }
        catch [System.Threading.AbandonedMutexException] {
            # WaitOne transfers ownership to this thread before throwing.
            $mutexOwned = $true
            $singleInstanceMutexState = 'abandoned-recovered'
        }

        # A short grace retry only affects a competing launch. It allows a process
        # that is already shutting down to release the mutex without delaying the
        # normal first-instance startup path.
        if (-not $mutexOwned) {
            try {
                $mutexOwned = $mutex.WaitOne($singleInstanceGraceMs, $false)
                if ($mutexOwned) { $singleInstanceMutexState = 'acquired-after-grace' }
            }
            catch [System.Threading.AbandonedMutexException] {
                $mutexOwned = $true
                $singleInstanceMutexState = 'abandoned-recovered'
            }
        }
    }
    catch {
        try { $mutex.Dispose() } catch { }
        $mutex = $null
        throw
    }

    if (-not $mutexOwned) {
        try { $mutex.Dispose() } catch { }
        $mutex = $null
        Show-FatalMessage 'Lenovo Boot Selector läuft bereits.' -AllowRestart $false | Out-Null
        exit 0
    }
}

$script:AppVersion = '0.5.7'
$script:Popup = $null
$script:TrayIcon = $null
$script:CurrentEntries = @()
$script:SelectedGuid = $null
$script:LastStatusText = 'Bereit.'
$script:ExitRequested = $false
$script:StorageContext = $null
$script:AutostartCheckbox = $null
$script:AutostartTextLabel = $null
$script:AutostartMenuItem = $null
$script:UpdatingAutostartUi = $false
$script:ScriptPath = $PSCommandPath
if (-not $script:ScriptPath) { $script:ScriptPath = $MyInvocation.MyCommand.Path }

$script:RuntimeDiagnosticsRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics\Runtime'
$script:RuntimeSessionId = $null
$script:RuntimeSessionDir = $null
$script:RuntimeEventsPath = $null
$script:RuntimeSessionStartedUtc = [datetime]::UtcNow
$script:RuntimeDiagnosticsAvailable = $false
$script:RuntimeDiagnosticsErrorCount = 0
$script:LastRuntimeDiagnosticPackage = $null
$script:RuntimeDiagnosticMenuItem = $null

$script:SupportedTaskBrokerVersions = @('0.2.12')
$script:TaskBrokerStateDir = Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'
$script:TaskBrokerMetadataPath = Join-Path $script:TaskBrokerStateDir 'task-broker.json'
$script:TaskBrokerInstallScript = Join-Path $PSScriptRoot 'Install-LenovoBootMenuTasks.ps1'
$script:TaskBrokerUninstallScript = Join-Path $PSScriptRoot 'Uninstall-LenovoBootMenuTasks.ps1'
$script:TaskBrokerLocalDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\TaskBroker'
$script:TaskBrokerTimeoutMs = 10000
$script:TaskBrokerMetadata = $null
$script:TaskBrokerInstallProcess = $null
$script:TaskBrokerInstallTimer = $null
$script:TaskBrokerSetupMenuItem = $null
$script:TaskBrokerRemoveMenuItem = $null
$script:TaskBrokerInstallInProgress = $false
$script:TaskBrokerInstallDiagnosticStartedUtc = $null
$script:TaskBrokerRemoveInProgress = $false
$script:TaskBrokerRemoveDiagnosticStartedUtc = $null
$script:TaskBrokerRemoveProcess = $null
$script:TaskBrokerRemoveTimer = $null
$script:ManagerCacheText = $null
$script:ManagerCacheUtc = [datetime]::MinValue
$script:FirmwareCacheText = $null
$script:FirmwareCacheUtc = [datetime]::MinValue
$script:TaskBrokerReadyCached = $null
$script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
$script:BackgroundRefreshState = $null
$script:MaintenanceState = $null
$script:BootTargetDriftState = $null
$script:UpdateState = $null
$script:UpdateCheckMenuItem = $null
$script:UpdateInstallMenuItem = $null
$script:RefreshButton = $null
$script:RefreshButtonHovered = $false
$script:HeaderTitleLabel = $null
$script:HeaderStatusLabel = $null
$script:LegacyAutostartTaskName = 'Lenovo Boot Menu Tray Autostart'
$script:AutostartRunValueName = 'Lenovo Boot Menu Tray'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:DefaultGuid = $null
$script:LegacyDefaultGuid = $null
$script:DefaultButton = $null
$script:DefaultValueLabel = $null
$script:RestartTargetLabel = $null
$script:DefaultContextMenu = $null
$script:DefaultContextRoot = $null
$script:LegacySessionRestoreRegistryPath = 'HKCU:\Volatile Environment'
$script:LegacySessionRestoreValueName = 'LenovoBootMenuTrayDefaultRestoreProcessed'
$script:RestartMenuItem = $null
$script:EntryOrder = @()
$script:HiddenEntryGuids = @()
$script:EntryAliases = @{}
$script:IsManageEntriesMode = $false
$script:ManageEntryOrder = @()
$script:ManageHiddenEntryGuids = @()
$script:ManageEntryAliases = @{}
$script:ManageBaselineEntryOrder = @()
$script:ManageBaselineHiddenEntryGuids = @()
$script:ManageBaselineEntryAliases = @{}
$script:ManageSaveButton = $null
$script:ManageAliasEditGuid = $null
$script:ManageDragGuid = $null
$script:ManageDragStartX = 0
$script:ManageDragStartY = 0
$script:ManageLastDragUtc = [datetime]::MinValue
$script:ManageEntriesButton = $null
$script:ManageEntriesMenuItem = $null

# Reference palette from the supplied visual example.
$script:ColorHeader = [Drawing.Color]::FromArgb(0, 0, 0)        # #000000
$script:ColorBackground = [Drawing.Color]::FromArgb(31, 31, 31) # #1F1F1F
$script:ColorRow = [Drawing.Color]::FromArgb(31, 31, 31)
$script:ColorHover = [Drawing.Color]::FromArgb(41, 41, 41)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(44, 25, 24)
$script:ColorSurface = [Drawing.Color]::FromArgb(25, 25, 25)
$script:ColorPrimary = [Drawing.Color]::FromArgb(252, 252, 252)
$script:ColorSecondary = [Drawing.Color]::FromArgb(184, 184, 184)
$script:ColorAccent = [Drawing.Color]::FromArgb(225, 37, 27)    # Lenovo Red from supplied reference #E1251B
$script:ColorWarning = [Drawing.Color]::FromArgb(247, 179, 43)
$script:ColorBlue = [Drawing.Color]::FromArgb(78, 168, 222)
$script:ColorPurple = [Drawing.Color]::FromArgb(161, 103, 218)
$script:ColorCyan = [Drawing.Color]::FromArgb(70, 205, 207)
$script:MenuRenderer = New-Object LenovoMenuRenderer

# @include src/Application/MaintenanceRuntime.ps1
# @include src/Application/BootTargetDrift.ps1
# @include src/Core/UpdateModel.ps1
# @include src/Application/UpdateRuntime.ps1

$script:MaintenanceState = New-MaintenanceRuntimeState
$script:BootTargetDriftState = New-BootTargetDriftRuntimeState
$script:UpdateState = New-UpdateRuntimeState

# @include src/UI/MenuAppearance.ps1

# @include src/UI/RefreshPresentation.ps1

# @include src/Infrastructure/RuntimeDiagnostics.ps1
# @include src/Infrastructure/UpdateClient.ps1

# @include src/UI/DiagnosticsPresentation.ps1
# @include src/UI/UpdatePresentation.ps1

# @include src/Infrastructure/Autostart.ps1

# @include src/UI/AutostartPresentation.ps1

# @include src/Core/EntryPreferences.ps1





# @include src/UI/ManageEntriesState.ps1

# @include src/Infrastructure/SettingsRepository.ps1

# @include src/Application/SettingsService.ps1

function Get-EntryAlias {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [switch]$UseManageDraft
    )
    $normalized = $Guid.ToLowerInvariant()
    $map = if ($UseManageDraft) { $script:ManageEntryAliases } else { $script:EntryAliases }
    if ($map -and $map.ContainsKey($normalized)) {
        $value = ([string]$map[$normalized]).Trim()
        if ($value) { return $value }
    }
    return $null
}

function Get-EntryDisplayTitle {
    param(
        [Parameter(Mandatory=$true)]$Entry,
        [switch]$UseManageDraft
    )
    $alias = Get-EntryAlias -Guid ([string]$Entry.Guid) -UseManageDraft:$UseManageDraft
    if ($alias) { return $alias }
    return [string]$Entry.Title
}

# @include src/UI/ManageEntries.ps1

# @include src/UI/DefaultTargetPresentation.ps1

function Refresh-SystemDefaultState {
    $script:DefaultGuid = $null
    try {
        $script:DefaultGuid = Get-TaskBrokerDefaultTargetGuid
    }
    catch {
        $script:DefaultGuid = $null
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_STATE_READ' -Stage 'default-read' -Success $false -ErrorRecord $_ -Level warning
    }

    Update-DefaultUi
    return $script:DefaultGuid
}

function Complete-LegacyDefaultMigration {
    if (-not $script:LegacyDefaultGuid) { return }
    $script:LegacyDefaultGuid = $null
    try { Save-AppSettings } catch { }
}

function Set-DefaultGuid {
    param([AllowNull()][string]$Guid)
    if (Test-MaintenanceBusy) { throw 'Während der Wartung kann das Standard-Startziel nicht geändert werden.' }
    if (Test-BootTargetDriftDetected) { throw 'Nach einer Änderung der Startziele müssen die Systemfunktionen zuerst neu initialisiert werden.' }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $operation = if ($Guid) { 'set' } else { 'clear' }
    try {
        if (-not (Test-TaskBrokerReady)) {
            throw 'Das Standard-Startziel ist erst nach Einrichtung der Systemfunktionen verfügbar.'
        }

        if ($Guid) {
            $normalized = $Guid.ToLowerInvariant()
            Set-TaskBrokerDefaultTarget -Guid $normalized
            [void](Refresh-SystemDefaultState)
            if (-not $script:DefaultGuid -or $script:DefaultGuid -ne $normalized) {
                throw 'Das systemweite Standardziel konnte nach der Aufgaben-Ausführung nicht verifiziert werden.'
            }

            $entry = Get-EntryByGuid $normalized
            $name = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { $normalized }
            $script:LastStatusText = "Systemstandard gespeichert: $name · wird 30 s nach dem nächsten Windows-Systemstart gesetzt."
        }
        else {
            Clear-TaskBrokerDefaultTarget
            [void](Refresh-SystemDefaultState)
            if ($script:DefaultGuid) { throw 'Das systemweite Standardziel konnte nicht deaktiviert werden.' }
            $script:LastStatusText = 'Automatisches systemweites Standard-Startziel ist deaktiviert.'
        }

        Complete-LegacyDefaultMigration
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) }) -Level error
        throw
    }
}

# @include src/UI/DefaultTargetMenu.ps1

# @include src/UI/Dialogs.ps1

# @include src/UI/MaintenancePresentation.ps1

function Get-NextBootTargetDisplayName {
    if ($script:SelectedGuid) {
        $selectedEntry = Get-EntryByGuid $script:SelectedGuid
        if ($selectedEntry) { return [string](Get-EntryDisplayTitle -Entry $selectedEntry) }
    }
    return 'Standardreihenfolge'
}

function Update-RestartTargetUi {
    if ($script:RestartTargetLabel -and -not $script:RestartTargetLabel.IsDisposed) {
        $script:RestartTargetLabel.Text = 'Nächstes Ziel: ' + (Get-NextBootTargetDisplayName)
    }
}

function Restart-Windows {
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    $targetName = Get-NextBootTargetDisplayName
    $choice = Show-LenovoRestartDialog -TargetName $targetName
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $true -Data (New-RuntimeDiagnosticData @{ confirmed = $false; targetGuid = $script:SelectedGuid })
        return
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Join-Path $env:SystemRoot 'System32\shutdown.exe')
        $psi.Arguments = '/r /t 0'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($psi)
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ confirmed = $true; targetGuid = $script:SelectedGuid })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'RESTART_REQUEST' -Stage 'restart' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ confirmed = $true; targetGuid = $script:SelectedGuid }) -Level error
        Show-LenovoNoticeDialog -Title 'Neustart nicht möglich' -Heading 'Windows konnte nicht neu gestartet werden.' -Message 'Bitte versuche es erneut oder starte Windows über das Startmenü neu.' -Kind Error
    }
}

# @include src/Infrastructure/TaskBroker.ps1

function Test-BootTargetDriftDetected {
    return (Test-BootTargetDriftRuntimeDetected -State $script:BootTargetDriftState)
}

function Test-BootTargetDriftHasNewTargets {
    return (Test-BootTargetDriftRuntimeHasNewTargets -State $script:BootTargetDriftState)
}

function Update-BootTargetDriftState {
    if (Test-MaintenanceBusy) { return $false }
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not (Test-TaskBrokerMetadataCompatible)) {
        [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)
        return $false
    }

    try {
        $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache
        $firmwareText = Get-TaskBrokerFirmwareEntriesText -UseExistingCache
        $manager = ConvertFrom-FirmwareManagerText -Text $managerText
        $descriptions = ConvertFrom-FirmwareEntriesText -Text $firmwareText
        $drift = Compare-BootTargetDriftCore -InstalledTargets @($meta.targets) -Descriptions $descriptions -DisplayOrder @($manager.DisplayOrder)
        [void](Set-BootTargetDriftRuntimeState -State $script:BootTargetDriftState -Drift $drift)
        Write-RuntimeDiagnosticEvent -Event 'BOOT_TARGET_DRIFT_CHECK' -Stage 'drift' -Success $true -Data (New-RuntimeDiagnosticData @{
            hasDrift = [bool]$drift.HasDrift
            hasNewTargets = [bool]$drift.HasNewTargets
            addedCount = @($drift.AddedGuids).Count
            removedCount = @($drift.RemovedGuids).Count
            addedGuids = @($drift.AddedGuids)
            removedGuids = @($drift.RemovedGuids)
        }) -Level $(if ($drift.HasDrift) { 'warning' } else { 'info' })
        return [bool]$drift.HasDrift
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BOOT_TARGET_DRIFT_CHECK' -Stage 'drift' -Success $false -ErrorRecord $_ -Level warning
        return $false
    }
}

function Show-BootTargetDriftNotificationIfNeeded {
    if (-not (Test-BootTargetDriftDetected)) { return }
    if ($script:BootTargetDriftState.NotificationShown) { return }
    [void](Set-BootTargetDriftNotificationShown -State $script:BootTargetDriftState)
    if (-not $script:Popup -or $script:Popup.IsDisposed) { $script:Popup = New-PopupForm }
    Update-MaintenanceUi
    Update-PopupRows
    if (-not $script:Popup.Visible) {
        Position-Popup
        $script:Popup.Show()
        $script:Popup.Activate()
    }
}


function Update-TaskBrokerUiState {
    param([switch]$Fast)
    $busy = Test-MaintenanceBusy
    $ready = if ($busy) {
        $false
    }
    elseif ($Fast) {
        if ($null -ne $script:TaskBrokerReadyCached) { [bool]$script:TaskBrokerReadyCached } else { $false }
    }
    else {
        Test-TaskBrokerReady
    }
    $present = Test-TaskBrokerInstallationPresent
    $drift = [bool]($ready -and (Test-BootTargetDriftDetected))
    $interactiveReady = [bool]($ready -and -not $drift)

    if ($script:TaskBrokerSetupMenuItem) {
        $script:TaskBrokerSetupMenuItem.Enabled = -not $busy
        if ($busy) {
            $mode = Get-MaintenanceMode
            $script:TaskBrokerSetupMenuItem.Text = if ($mode -eq 'Remove') { 'Systemfunktionen…' } elseif ($mode -eq 'Reinitialize') { 'Systemfunktionen werden neu initialisiert…' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { 'Systemfunktionen werden repariert…' } else { 'Systemfunktionen werden eingerichtet…' }
        }
        elseif ($drift) {
            $script:TaskBrokerSetupMenuItem.Text = 'Systemfunktionen neu initialisieren…'
        }
        elseif ($ready -or $present) {
            $script:TaskBrokerSetupMenuItem.Text = 'Systemfunktionen reparieren…'
        }
        else {
            $script:TaskBrokerSetupMenuItem.Text = 'Systemfunktionen einrichten…'
        }
    }

    if ($script:TaskBrokerRemoveMenuItem) {
        # Cleanup is intentionally available even when metadata is already gone;
        # it also knows historical/probe task names from pre-TaskBroker builds.
        $script:TaskBrokerRemoveMenuItem.Enabled = -not $busy
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = ($interactiveReady -and -not $busy) }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = (-not $busy -and -not $drift) }
    Update-MaintenanceUi
    return $interactiveReady
}

function Enter-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    [void](Set-MaintenanceRuntimeActive -State $script:MaintenanceState -Mode $Mode)
    $script:IsManageEntriesMode = $false
    $script:ManageAliasEditGuid = $null
    Stop-BackgroundBootRefreshForMaintenance -Reason $Mode
    $script:LastStatusText = Get-MaintenanceBusyStatusText
    Update-PopupRows
    Update-TaskBrokerUiState -Fast | Out-Null
    Write-RuntimeDiagnosticEvent -Event 'MAINTENANCE_UI_STATE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ state = 'busy'; mode = $Mode })
}

function Exit-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][string]$Reason)
    $mode = Get-MaintenanceMode
    [void](Clear-MaintenanceRuntimeState -State $script:MaintenanceState)
    Write-RuntimeDiagnosticEvent -Event 'MAINTENANCE_UI_STATE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ state = 'idle'; mode = $mode; reason = $Reason })
    Update-TaskBrokerUiState -Fast | Out-Null
    Update-PopupRows
}

function Complete-TaskBrokerInstall {
    param([int]$ExitCode)
    $diagStarted = $script:TaskBrokerInstallDiagnosticStartedUtc
    $completedMode = Get-MaintenanceMode
    if (-not $completedMode) { $completedMode = 'Setup' }

    $script:TaskBrokerInstallInProgress = $false
    if ($script:TaskBrokerInstallTimer) {
        try { $script:TaskBrokerInstallTimer.Stop() } catch { }
        try { $script:TaskBrokerInstallTimer.Dispose() } catch { }
        $script:TaskBrokerInstallTimer = $null
    }
    $script:TaskBrokerInstallProcess = $null
    $script:TaskBrokerMetadata = $null
    Reset-TaskBrokerReadyCache
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)

    $setupSuccess = ($ExitCode -eq 0 -and (Test-TaskBrokerReady))
    if ($setupSuccess) {
        $script:LastStatusText = 'Systemfunktionen sind eingerichtet.'
        try {
            Refresh-BootState -RefreshStorage
            [void](Refresh-SystemDefaultState)
            Complete-LegacyDefaultMigration
        } catch {
            $script:LastStatusText = 'Einrichtung abgeschlossen · Startziele werden erneut aktualisiert.'
        }
    }
    else {
        $script:LastStatusText = 'Systemfunktionen sind nicht eingerichtet.'
    }

    $durationMs = $null
    if ($diagStarted) { $durationMs = [int64](([datetime]::UtcNow - $diagStarted).TotalMilliseconds) }
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_COMPLETED' -Stage 'maintenance' -Success $setupSuccess -DurationMs $durationMs -Data (New-RuntimeDiagnosticData @{ exitCode = $ExitCode; mode = $completedMode; installerDiagnostic = [System.IO.Path]::GetFileName((Get-LatestTaskBrokerDiagnosticPath)) }) -Level $(if ($setupSuccess) { 'info' } else { 'error' })

    Exit-SystemFunctionsMaintenance -Reason $(if ($setupSuccess) { 'completed' } else { 'failed' })
    Update-DefaultUi
    if ($setupSuccess) {
        Show-MaintenanceSuccessDialog -Mode $completedMode
    }
    else {
        # Technical details remain in the installer diagnostic; the UI stays user-facing.
        Show-LenovoNoticeDialog -Title 'Einrichtung nicht abgeschlossen' -Heading 'Die Systemfunktionen konnten nicht eingerichtet werden.' -Message 'Bitte versuche die Einrichtung erneut. Falls das Problem bestehen bleibt, wurde eine Diagnose für die weitere Prüfung gespeichert.' -Kind Error
    }
}

function Start-TaskBrokerInstall {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize')][string]$Mode = 'Setup')
    if ($script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerInstallDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_STARTED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ mode = $Mode })
    if (-not (Test-Path -LiteralPath $script:TaskBrokerInstallScript)) {
        Show-LenovoNoticeDialog -Title 'Einrichtung nicht möglich' -Heading 'Eine benötigte App-Datei fehlt.' -Message 'Bitte installiere oder entpacke Lenovo Boot Selector erneut und versuche es danach noch einmal.' -Kind Error
        return
    }

    $legacyAutostart = (Get-LegacyAutostartInfo).Enabled
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir)) {
        [void](New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force)
    }

    Enter-SystemFunctionsMaintenance -Mode $Mode

    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $legacyDefaultArg = if ($script:LegacyDefaultGuid) { [string]$script:LegacyDefaultGuid } else { '' }
    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $script:TaskBrokerInstallScript),
        '-StateDir', ('"{0}"' -f $script:TaskBrokerStateDir),
        '-UserStateDir', ('"{0}"' -f $script:TaskBrokerLocalDir),
        '-UserSid', ('"{0}"' -f $sid),
        '-LegacyDefaultGuid', ('"{0}"' -f $legacyDefaultArg)
    )

    try {
        $proc = Start-Process -FilePath $ps -ArgumentList ($args -join ' ') -Verb RunAs -WindowStyle Hidden -PassThru
    }
    catch {
        $cancelled = ($_.Exception.Message -match 'canceled|cancelled|abgebrochen|1223')
        $script:LastStatusText = if ($cancelled) { 'Einrichtung wurde abgebrochen.' } else { 'Einrichtung konnte nicht gestartet werden.' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode = $Mode }) -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title 'Einrichtung nicht gestartet' -Heading 'Die Windows-Bestätigung konnte nicht geöffnet werden.' -Message 'Bitte versuche es erneut.' -Kind Error
        }
        return
    }

    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_LAUNCH' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $proc.Id; mode = $Mode })
    $script:TaskBrokerInstallProcess = $proc
    $script:TaskBrokerInstallInProgress = $true
    Update-MaintenanceUi
    Update-TaskBrokerUiState -Fast | Out-Null

    if ($legacyAutostart) { try { Set-AutostartEnabled -Enabled:$true } catch { } }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        try {
            if (-not $script:TaskBrokerInstallProcess) { return }
            $script:TaskBrokerInstallProcess.Refresh()
            if ($script:TaskBrokerInstallProcess.HasExited) {
                $code = $script:TaskBrokerInstallProcess.ExitCode
                Complete-TaskBrokerInstall -ExitCode $code
            }
        }
        catch {
            Complete-TaskBrokerInstall -ExitCode 1
        }
    })
    $script:TaskBrokerInstallTimer = $timer
    $timer.Start()
}

function Prompt-TaskBrokerInstall {
    if (Test-MaintenanceBusy) { return }
    $mode = if (Test-BootTargetDriftDetected) { 'Reinitialize' } elseif (Test-TaskBrokerReady) { 'Repair' } elseif (Test-TaskBrokerInstallationPresent) { 'Migrate' } else { 'Setup' }
    $choice = Show-LenovoSystemFunctionsDialog -Mode $mode
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode $mode }
}

function Prompt-TaskBrokerReinitialize {
    if (Test-MaintenanceBusy -or -not (Test-BootTargetDriftDetected)) { return }
    $choice = Show-LenovoSystemFunctionsDialog -Mode 'Reinitialize'
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode 'Reinitialize' }
}

function Complete-TaskBrokerRemove {
    param([int]$ExitCode)
    $diagStarted = $script:TaskBrokerRemoveDiagnosticStartedUtc

    $script:TaskBrokerRemoveInProgress = $false
    if ($script:TaskBrokerRemoveTimer) {
        try { $script:TaskBrokerRemoveTimer.Stop() } catch { }
        try { $script:TaskBrokerRemoveTimer.Dispose() } catch { }
        $script:TaskBrokerRemoveTimer = $null
    }
    $script:TaskBrokerRemoveProcess = $null
    $script:TaskBrokerMetadata = $null
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    $script:DefaultGuid = $null
    $script:IsManageEntriesMode = $false
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    [void](Clear-BootTargetDriftRuntimeState -State $script:BootTargetDriftState)

    $removeSuccess = ($ExitCode -eq 0 -and -not (Test-TaskBrokerInstallationPresent))
    if ($removeSuccess) {
        $script:TaskBrokerReadyCached = $false
        $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
        $script:CurrentEntries = @()
        $script:SelectedGuid = $null
        $script:LastStatusText = 'Systemfunktionen wurden entfernt.'
    }
    else {
        Reset-TaskBrokerReadyCache
        $script:LastStatusText = 'Systemfunktionen konnten nicht vollständig entfernt werden.'
    }

    $durationMs = $null
    if ($diagStarted) { $durationMs = [int64](([datetime]::UtcNow - $diagStarted).TotalMilliseconds) }
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_COMPLETED' -Stage 'maintenance' -Success $removeSuccess -DurationMs $durationMs -Data (New-RuntimeDiagnosticData @{ exitCode = $ExitCode }) -Level $(if ($removeSuccess) { 'info' } else { 'error' })

    Exit-SystemFunctionsMaintenance -Reason $(if ($removeSuccess) { 'completed' } else { 'failed' })
    Update-ManageEntriesUiState
    Update-DefaultUi
    if ($removeSuccess) {
        Show-MaintenanceSuccessDialog -Mode 'Remove'
    }
    else {
        Show-LenovoNoticeDialog -Title 'Entfernen nicht abgeschlossen' -Heading 'Die Systemfunktionen konnten nicht vollständig entfernt werden.' -Message 'Bitte versuche es erneut. Deine Startziele und persönlichen App-Einstellungen bleiben erhalten.' -Kind Error
    }
}

function Start-TaskBrokerRemove {
    if ($script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerRemoveDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_STARTED' -Stage 'maintenance' -Success $true
    if (-not (Test-Path -LiteralPath $script:TaskBrokerUninstallScript)) {
        Show-LenovoNoticeDialog -Title 'Entfernen nicht möglich' -Heading 'Eine benötigte App-Datei fehlt.' -Message 'Bitte installiere oder entpacke Lenovo Boot Selector erneut und versuche es danach noch einmal.' -Kind Error
        return
    }

    Enter-SystemFunctionsMaintenance -Mode 'Remove'

    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"{0}"' -f $script:TaskBrokerUninstallScript))
    try {
        $proc = Start-Process -FilePath $ps -ArgumentList ($args -join ' ') -Verb RunAs -WindowStyle Hidden -PassThru
    }
    catch {
        $cancelled = ($_.Exception.Message -match 'canceled|cancelled|abgebrochen|1223')
        $script:LastStatusText = if ($cancelled) { 'Entfernen wurde abgebrochen.' } else { 'Systemfunktionen konnten nicht entfernt werden.' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title 'Entfernen nicht gestartet' -Heading 'Die Windows-Bestätigung konnte nicht geöffnet werden.' -Message 'Bitte versuche es erneut.' -Kind Error
        }
        return
    }

    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_LAUNCH' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $proc.Id })
    $script:TaskBrokerRemoveProcess = $proc
    $script:TaskBrokerRemoveInProgress = $true
    Update-MaintenanceUi
    Update-TaskBrokerUiState -Fast | Out-Null

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        try {
            if (-not $script:TaskBrokerRemoveProcess) { return }
            $script:TaskBrokerRemoveProcess.Refresh()
            if ($script:TaskBrokerRemoveProcess.HasExited) {
                $code = $script:TaskBrokerRemoveProcess.ExitCode
                Complete-TaskBrokerRemove -ExitCode $code
            }
        }
        catch { Complete-TaskBrokerRemove -ExitCode 1 }
    })
    $script:TaskBrokerRemoveTimer = $timer
    $timer.Start()
}

function Prompt-TaskBrokerRemove {
    if (Test-MaintenanceBusy) { return }
    $choice = Show-LenovoSystemFunctionsDialog -Mode 'Remove'
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerRemove }
}

# @include src/Infrastructure/Storage.ps1

# @include src/Core/BootTargetModel.ps1

function Get-FriendlyBootEntry {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext
    )

    $model = Get-FriendlyBootEntryCore -Guid $Guid -RawDescription $RawDescription -StorageContext $StorageContext
    $accent = switch ([string]$model.AccentRole) {
        'Accent' { $script:ColorAccent; break }
        'Blue' { $script:ColorBlue; break }
        'Warning' { $script:ColorWarning; break }
        'Purple' { $script:ColorPurple; break }
        'Cyan' { $script:ColorCyan; break }
        default { $script:ColorSecondary; break }
    }

    [pscustomobject]@{
        Guid = [string]$model.Guid
        Title = [string]$model.Title
        Subtitle = [string]$model.Subtitle
        RawDescription = [string]$model.RawDescription
        Accent = $accent
        Symbol = [string]$model.Symbol
        TypeTooltip = [string]$model.TypeTooltip
        Resolution = $model.Resolution
        ResolutionReason = $model.ResolutionReason
    }
}


# @include src/Core/FirmwareParsing.ps1
# @include src/Core/BootTargetDrift.ps1

# @include src/Application/BootService.ps1
# @include src/Infrastructure/BackgroundRefreshWorker.ps1
# @include src/Application/RefreshRuntime.ps1

$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState


function Get-FirmwareBootState {
    param(
        [switch]$RefreshStorage,
        [switch]$UseExistingCache
    )

    $snapshot = Get-BootServiceFirmwareSnapshot -UseExistingCache:$UseExistingCache
    $descriptions = $snapshot.Descriptions
    $managerState = $snapshot.ManagerState
    $displayOrder = @($managerState.DisplayOrder)
    $selectedGuid = $managerState.SelectedGuid

    # Find Lenovo's actual firmware "Boot Menu" application dynamically.
    $bootMenuGuid = $null
    foreach ($key in $descriptions.Keys) {
        if ($descriptions[$key] -eq 'Boot Menu') {
            $bootMenuGuid = $key
            break
        }
    }

    $orderedGuids = New-Object System.Collections.Generic.List[string]
    if ($bootMenuGuid) { $orderedGuids.Add($bootMenuGuid) }
    foreach ($guid in $displayOrder) {
        if (-not $orderedGuids.Contains($guid)) { $orderedGuids.Add($guid) }
    }

    # If the active BootSequence points at an entry not in the display order, keep it visible.
    if ($selectedGuid -and -not $orderedGuids.Contains($selectedGuid)) {
        $orderedGuids.Insert(0, $selectedGuid)
    }

    if ($RefreshStorage -or ((-not $UseExistingCache) -and -not $script:StorageContext)) {
        $script:StorageContext = Get-StorageContext
    }
    $storageContext = $script:StorageContext

    $entries = @()
    foreach ($guid in $orderedGuids) {
        $raw = if ($descriptions.ContainsKey($guid)) { [string]$descriptions[$guid] } else { 'Weiteres Startziel' }
        $entries += Get-FriendlyBootEntry -Guid $guid -RawDescription $raw -StorageContext $storageContext
    }

    [pscustomobject]@{
        Entries = $entries
        SelectedGuid = $selectedGuid
        BootMenuGuid = $bootMenuGuid
        StorageContext = $storageContext
    }
}

function Set-BootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = Set-BootNextTargetService -Guid $Guid
        if ($result.ExitCode -ne 0) { throw 'Das Startziel konnte nicht gesetzt werden.' }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ guid = $Guid.ToLowerInvariant(); exitCode = $result.ExitCode })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOTNEXT_SET' -Stage 'bootnext' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ guid = $Guid.ToLowerInvariant() }) -Level error
        throw
    }
}

function Get-EntryByGuid([string]$Guid) {
    if (-not $Guid) { return $null }
    return $script:CurrentEntries | Where-Object { $_.Guid -eq $Guid.ToLowerInvariant() } | Select-Object -First 1
}

# @include src/UI/BootEntryList.ps1


function Apply-FirmwareBootState {
    param([Parameter(Mandatory=$true)]$State)

    $script:CurrentEntries = @($State.Entries)
    $script:SelectedGuid = if ($State.SelectedGuid) { $State.SelectedGuid.ToLowerInvariant() } else { $null }

    if ($script:SelectedGuid) {
        $selected = Get-EntryByGuid $script:SelectedGuid
        $script:LastStatusText = if ($selected) { "Nächster Start: $(Get-EntryDisplayTitle -Entry $selected)" } else { 'Ein einmaliges Startziel ist gesetzt.' }
    }
    else {
        $script:LastStatusText = 'Kein einmaliges Startziel gesetzt.'
    }

    if (Get-TaskBrokerInteractiveReady) { [void](Refresh-SystemDefaultState) }
    Update-PopupRows
}

function Refresh-BootState {
    param([switch]$RefreshStorage)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($RefreshStorage) {
        $script:ManagerCacheText = $null
        $script:FirmwareCacheText = $null
    }
    try {
        $state = Get-FirmwareBootState -RefreshStorage:$RefreshStorage
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage; entryCount = @($state.Entries).Count; selectedGuid = $state.SelectedGuid })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage }) -Level error
        $script:LastStatusText = 'Startziele konnten nicht gelesen werden.'
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        throw
    }
}

function Load-BootStateFromExistingCache {
    try {
        $state = Get-FirmwareBootState -UseExistingCache
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state
        return $true
    }
    catch {
        return $false
    }
}

function Get-BackgroundRefreshResult {
    param([Parameter(Mandatory=$true)][string]$ResultPath)
    $text = Read-BackgroundRefreshResultText -Path $ResultPath
    return (ConvertFrom-BackgroundRefreshResultText -Text $text)
}

function Apply-BackgroundRefreshResult {
    param(
        [Parameter(Mandatory=$true)]$Result,
        [Parameter(Mandatory=$true)]$Request
    )

    $requestedStorage = [bool]$Request.RefreshStorage
    if (-not $Result.Success) {
        if (Test-MaintenanceBusy) {
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_RESULT_IGNORED' -Stage 'maintenance' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); workerStage = [string]$Result.Stage; workerError = [string]$Result.Error })
            return $false
        }
        if ([string]$Result.Stage -eq 'ready') {
            $script:TaskBrokerReadyCached = $false
            $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
            if (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = 'Systemfunktionen müssen repariert werden.'
            }
            else {
                $script:LastStatusText = 'Systemfunktionen müssen eingerichtet werden.'
            }
            Update-TaskBrokerUiState -Fast | Out-Null
            Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'ready' -Success $false -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ workerError = [string]$Result.Error }) -Level error
            if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
            return $false
        }
        throw ("Hintergrund-Refresh ({0}) fehlgeschlagen: {1}" -f ([string]$Result.Stage), ([string]$Result.Error))
    }

    $script:TaskBrokerReadyCached = $true
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    Set-BackgroundRefreshLastTiming -State $script:BackgroundRefreshState -Timing $Result.Timings
    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $true -DurationMs $Result.Timings.TotalMs -Data (New-RuntimeDiagnosticData @{ requestedStorage = $requestedStorage; readyMs = $Result.Timings.ReadyMs; managerMs = $Result.Timings.ManagerMs; firmwareMs = $Result.Timings.FirmwareMs; storageMs = $Result.Timings.StorageMs })

    [void](Sync-TaskBrokerFirmwareCachesFromFiles)
    [void](Update-BootTargetDriftState)

    if ($requestedStorage -and $Result.StorageContext) {
        $script:StorageContext = $Result.StorageContext
    }

    $state = Get-FirmwareBootState -UseExistingCache
    Apply-FirmwareBootState -State $state
    Update-TaskBrokerUiState -Fast | Out-Null
    Show-BootTargetDriftNotificationIfNeeded
    return $true
}

function Stop-BackgroundBootRefreshForMaintenance {
    param([Parameter(Mandatory=$true)][string]$Reason)
    if (-not $script:BackgroundRefreshState) { return }

    $context = $null
    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    }
    [void](Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState)
    if ($context) {
        if ($context.Timer) {
            try { $context.Timer.Stop() } catch { }
            try { $context.Timer.Dispose() } catch { }
        }
        if ($context.Process) {
            try {
                $context.Process.Refresh()
                if (-not $context.Process.HasExited) { $context.Process.Kill() }
            } catch { }
        }
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_CANCELLED_FOR_MAINTENANCE' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason })
    }
    Update-RefreshButtonVisual
}

function Complete-BackgroundBootRefresh {
    if (Test-MaintenanceBusy) {
        Stop-BackgroundBootRefreshForMaintenance -Reason (Get-MaintenanceMode)
        return
    }
    if (-not (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)) { return }

    $process = $script:BackgroundRefreshState.Process
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) { return }

    $context = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
    if (-not $context) { return }

    if ($context.Timer) {
        try { $context.Timer.Stop() } catch { }
        try { $context.Timer.Dispose() } catch { }
    }
    Update-RefreshButtonVisual

    $continuePending = $true
    try {
        $result = Get-BackgroundRefreshResult -ResultPath ([string]$context.ResultPath)
        $continuePending = Apply-BackgroundRefreshResult -Result $result -Request $context.Request
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_COMPLETED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ requestedStorage = [bool]$context.Request.RefreshStorage }) -Level error
        $script:LastStatusText = 'Startziele konnten nicht aktualisiert werden.'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
    finally {
        Remove-BackgroundRefreshResultFile -Path ([string]$context.ResultPath)
        try { $context.Process.Dispose() } catch { }
    }

    if (-not $continuePending) { return }

    $pending = Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState
    if ($pending) {
        if ($pending.RefreshFirmware) { $script:FirmwareCacheUtc = [datetime]::MinValue }
        $pendingStorage = [bool]$pending.RefreshStorage
        Start-BackgroundBootRefresh -RefreshStorage:$pendingStorage
    }
}

function Start-BackgroundBootRefresh {
    param([switch]$RefreshStorage)

    if (Test-MaintenanceBusy) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_SUPPRESSED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ maintenanceMode = (Get-MaintenanceMode); refreshStorage = [bool]$RefreshStorage })
        return
    }

    $refreshFirmware = Test-BackgroundRefreshNeedsFirmware `
        -RefreshStorage ([bool]$RefreshStorage) `
        -FirmwareCacheText $script:FirmwareCacheText `
        -FirmwareCacheUtc $script:FirmwareCacheUtc
    $request = New-BackgroundRefreshRequest -RefreshStorage ([bool]$RefreshStorage) -RefreshFirmware ([bool]$refreshFirmware)

    if (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) {
        try {
            $script:BackgroundRefreshState.Process.Refresh()
            if (-not $script:BackgroundRefreshState.Process.HasExited) {
                # Popup opens while startup refresh is active must not queue a duplicate.
                # Only a request that adds storage or firmware work is coalesced as pending.
                if (Test-BackgroundRefreshRequestEscalation -ActiveRequest $script:BackgroundRefreshState.ActiveRequest -Requested $request) {
                    [void](Add-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState -Request $request)
                }
                return
            }
        }
        catch { }
        Complete-BackgroundBootRefresh
    }

    if (-not $script:ScriptPath -or -not (Test-Path -LiteralPath $script:ScriptPath)) { return }
    if (-not (Get-TaskBrokerInteractiveReady)) { return }

    try {
        if (-not (Test-Path -LiteralPath $script:TaskBrokerLocalDir)) {
            New-Item -ItemType Directory -Path $script:TaskBrokerLocalDir -Force | Out-Null
        }
        $resultPath = Join-Path $script:TaskBrokerLocalDir ("runtime-refresh-{0}.json" -f ([guid]::NewGuid().ToString('N')))
        $process = Start-BackgroundRefreshWorkerProcess `
            -ScriptPath $script:ScriptPath `
            -ResultPath $resultPath `
            -RefreshStorage ([bool]$request.RefreshStorage) `
            -RefreshFirmware ([bool]$request.RefreshFirmware) `
            -RuntimeSessionId $script:RuntimeSessionId

        Set-BackgroundRefreshActive -State $script:BackgroundRefreshState -Process $process -ResultPath $resultPath -Request $request
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $true -Data (New-RuntimeDiagnosticData @{ processId = $process.Id; refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware })
        Update-RefreshButtonVisual

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 100
        $timer.Add_Tick({ Complete-BackgroundBootRefresh })
        Set-BackgroundRefreshTimer -State $script:BackgroundRefreshState -Timer $timer
        $timer.Start()
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_STARTED' -Stage 'background-refresh' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$request.RefreshStorage; refreshFirmware = [bool]$request.RefreshFirmware }) -Level error
        $script:LastStatusText = 'Aktualisierung konnte nicht gestartet werden.'
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}

function Invoke-BackgroundRefreshWorker {
    $total = [System.Diagnostics.Stopwatch]::StartNew()
    $timings = [ordered]@{ ReadyMs = 0; ManagerMs = 0; FirmwareMs = 0; StorageMs = 0; TotalMs = 0 }
    $result = [ordered]@{ Success = $false; Error = $null; Stage = 'ready'; StorageContext = $null; Timings = $timings }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if (-not (Test-TaskBrokerReady -Force)) { throw 'Die Systemfunktionen sind nicht vollständig verfügbar.' }
        $sw.Stop(); $timings.ReadyMs = $sw.ElapsedMilliseconds

        $result.Stage = 'manager'
        $sw.Restart(); [void](Get-TaskBrokerFirmwareManagerText -Force); $sw.Stop(); $timings.ManagerMs = $sw.ElapsedMilliseconds
        if ($BackgroundRefreshFirmware) {
            $result.Stage = 'firmware'
            $sw.Restart(); [void](Get-TaskBrokerFirmwareEntriesText -Force); $sw.Stop(); $timings.FirmwareMs = $sw.ElapsedMilliseconds
        }

        if ($BackgroundRefreshStorage) {
            $result.Stage = 'storage'
            $sw.Restart(); $result.StorageContext = Get-StorageContext; $sw.Stop(); $timings.StorageMs = $sw.ElapsedMilliseconds
        }
        $result.Stage = 'complete'
        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    finally {
        $total.Stop(); $timings.TotalMs = $total.ElapsedMilliseconds
        if ($BackgroundResultPath) {
            try {
                $parent = Split-Path -Parent $BackgroundResultPath
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                $json = $result | ConvertTo-Json -Depth 8
                [System.IO.File]::WriteAllText($BackgroundResultPath, $json, (New-Object System.Text.UTF8Encoding($false)))
            }
            catch { }
        }
    }

    Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_WORKER_COMPLETED' -Stage ([string]$result.Stage) -Success ([bool]$result.Success) -DurationMs $timings.TotalMs -Data (New-RuntimeDiagnosticData @{ readyMs = $timings.ReadyMs; managerMs = $timings.ManagerMs; firmwareMs = $timings.FirmwareMs; storageMs = $timings.StorageMs; workerError = [string]$result.Error }) -Level $(if ($result.Success) { 'info' } else { 'error' })
    if ($result.Success) { return 0 }
    return 1
}

# @include src/UI/Popup.ps1

Initialize-RuntimeDiagnostics
if (-not $BackgroundRefresh) {
    if ($singleInstanceMutexState -eq 'abandoned-recovered') {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs }) -Level warning
    }
    elseif ($mutexOwned) {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ACQUIRED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs })
    }
}

if ($BackgroundRefresh) {
    $exitCode = Invoke-BackgroundRefreshWorker
    exit $exitCode
}
if ($UpdateCheck) {
    $exitCode = Invoke-UpdateCheckWorker
    exit $exitCode
}
if ($UpdatePrepare) {
    $exitCode = Invoke-UpdatePrepareWorker
    exit $exitCode
}

try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    try {
        [System.Windows.Forms.Application]::add_ThreadException({
            param($sender,$eventArgs)
            Write-RuntimeDiagnosticEvent -Event 'UI_THREAD_EXCEPTION' -Stage 'ui' -Success $false -ErrorRecord $eventArgs.Exception -Level error
        })
    } catch { }
    try {
        [AppDomain]::CurrentDomain.add_UnhandledException({
            param($sender,$eventArgs)
            Write-RuntimeDiagnosticEvent -Event 'APPDOMAIN_UNHANDLED_EXCEPTION' -Stage 'runtime' -Success $false -ErrorRecord $eventArgs.ExceptionObject -Level error
        })
    } catch { }
    Write-RuntimeDiagnosticEvent -Event 'TRAY_STARTUP' -Stage 'startup' -Success $true
    Load-AppSettings
    Repair-AutostartLauncherIfNeeded

    $script:Popup = New-PopupForm
    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayIcon.Icon = Load-TrayIcon
    $script:TrayIcon.Text = 'Lenovo Boot Selector – Startziel wählen'
    $script:TrayIcon.Visible = $true

    $context = New-Object LenovoContextMenuStrip
    $context.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $context.ForeColor = $script:ColorPrimary
    $context.Renderer = $script:MenuRenderer
    $context.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $context.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $context.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $context

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem('Lenovo Boot Selector öffnen')
    $openItem.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $openItem.ForeColor = $script:ColorAccent
    $openItem.Add_Click({ Show-OrTogglePopup })
    [void]$context.Items.Add($openItem)

    # v0.2.32: Refresh and Standard-Startziel remain in the main popup only.
    # The tray menu is intentionally reduced to quick actions and maintenance.
    $autostartItem = New-Object System.Windows.Forms.ToolStripMenuItem('Mit Windows starten')
    $autostartItem.Add_Click({
        $desired = -not (Get-AutostartInfo).Enabled
        Set-AutostartFromUi -Enabled:$desired
    })
    $script:AutostartMenuItem = $autostartItem
    [void]$context.Items.Add($autostartItem)

    $script:DefaultContextRoot = $null
    $script:ManageEntriesMenuItem = $null

    $maintenanceRoot = New-Object System.Windows.Forms.ToolStripMenuItem('Wartung')
    $maintenanceRoot.DropDown = New-Object LenovoDropDownMenu
    $maintenanceRoot.DropDown.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $maintenanceRoot.DropDown
    $maintenanceRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })

    $setupItem = New-Object System.Windows.Forms.ToolStripMenuItem('Systemfunktionen einrichten…')
    $setupItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $setupItem.Add_Click({ Prompt-TaskBrokerInstall })
    $script:TaskBrokerSetupMenuItem = $setupItem
    [void]$maintenanceRoot.DropDownItems.Add($setupItem)

    $removeTasksItem = New-Object System.Windows.Forms.ToolStripMenuItem('Systemfunktionen entfernen…')
    $removeTasksItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $removeTasksItem.Add_Click({ Prompt-TaskBrokerRemove })
    $script:TaskBrokerRemoveMenuItem = $removeTasksItem
    [void]$maintenanceRoot.DropDownItems.Add($removeTasksItem)

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $updateCheckItem = New-Object System.Windows.Forms.ToolStripMenuItem('Auf neue Version prüfen…')
    $updateCheckItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $updateCheckItem.Add_Click({ Start-ManualUpdateCheck })
    $script:UpdateCheckMenuItem = $updateCheckItem
    [void]$maintenanceRoot.DropDownItems.Add($updateCheckItem)

    $updateInstallItem = New-Object System.Windows.Forms.ToolStripMenuItem('App aktualisieren…')
    $updateInstallItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $updateInstallItem.Enabled = $false
    $updateInstallItem.Add_Click({ Start-ManualAppUpdate })
    $script:UpdateInstallMenuItem = $updateInstallItem
    [void]$maintenanceRoot.DropDownItems.Add($updateInstallItem)
    Update-UpdateMenuState

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $diagnosticItem = New-Object System.Windows.Forms.ToolStripMenuItem('Diagnose speichern…')
    $diagnosticItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 14, 4)
    $diagnosticItem.Add_Click({ Save-RuntimeDiagnosticsFromUi })
    $script:RuntimeDiagnosticMenuItem = $diagnosticItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)

    [void]$context.Items.Add($maintenanceRoot)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $restartItem = New-Object System.Windows.Forms.ToolStripMenuItem('Windows neu starten')
    $restartItem.Add_Click({ Restart-Windows })
    $script:RestartMenuItem = $restartItem
    [void]$context.Items.Add($restartItem)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem('Beenden')
    $exitItem.Add_Click({
        $script:ExitRequested = $true
        try { $context.Close() } catch { }
        try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
        try {
            if ($script:TrayIcon) {
                $script:TrayIcon.Visible = $false
                $script:TrayIcon.Dispose()
            }
        } catch { }
        [System.Windows.Forms.Application]::ExitThread()
    })
    [void]$context.Items.Add($exitItem)

    foreach ($menuItem in $context.Items) {
        if ($menuItem -is [System.Windows.Forms.ToolStripMenuItem]) {
            $menuItem.Padding = New-Object System.Windows.Forms.Padding(18, 4, 32, 4)
        }
    }

    $script:TrayIcon.ContextMenuStrip = $context
    $script:TrayIcon.Add_MouseClick({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-OrTogglePopup
        }
    })

    # v0.2.26 startup fast path: only inspect local metadata synchronously. Exact
    # Scheduled-Task validation and fresh firmware/storage reads are delegated to
    # the background worker so the tray event loop can become responsive first.
    $metadataCompatible = Test-TaskBrokerMetadataCompatible
    Write-RuntimeDiagnosticEvent -Event 'TASKBROKER_METADATA_COMPATIBILITY' -Stage 'startup' -Success $metadataCompatible -Data (New-RuntimeDiagnosticData @{ brokerPresent = [bool](Test-TaskBrokerInstallationPresent) }) -Level $(if ($metadataCompatible) { 'info' } else { 'warning' })
    if (-not $metadataCompatible) {
        $script:TaskBrokerReadyCached = $false
        $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
        if (Test-TaskBrokerInstallationPresent) {
            $script:LastStatusText = 'Systemfunktionen müssen repariert werden.'
        }
        else {
            $script:LastStatusText = 'Systemfunktionen müssen eingerichtet werden.'
        }
    }
    else {
        $script:LastStatusText = 'Startziele werden im Hintergrund aktualisiert…'
    }
    Update-TaskBrokerUiState -Fast | Out-Null
    Update-ManageEntriesUiState
    Update-PopupRows
    if (-not $metadataCompatible) {
        # First-run / incomplete-install UX: expose the central setup/repair CTA
        # immediately without launching UAC until the user explicitly confirms.
        Show-OrTogglePopup
    }

    try {
        if ($metadataCompatible) {
            [void](Load-BootStateFromExistingCache)
            [void](Refresh-SystemDefaultState)
            Complete-LegacyDefaultMigration
            Start-BackgroundBootRefresh -RefreshStorage
        }
    } catch { }
    try { Update-AutostartUi | Out-Null } catch { }
    try { Update-DefaultUi } catch { }

    [System.Windows.Forms.Application]::Run()
}
catch {
    Write-RuntimeDiagnosticEvent -Event 'FATAL_RUNTIME_ERROR' -Stage 'runtime' -Success $false -ErrorRecord $_ -Level error
    $script:RestartAfterFatal = ((Show-FatalMessage $_.Exception.Message) -eq 'retry')
}
finally {
    Write-RuntimeDiagnosticEvent -Event 'SESSION_ENDED' -Stage 'shutdown' -Success $true -Data (New-RuntimeDiagnosticData @{ exitRequested = [bool]$script:ExitRequested; errorEvents = $script:RuntimeDiagnosticsErrorCount })
    if ($script:TaskBrokerInstallTimer) {
        try { $script:TaskBrokerInstallTimer.Stop() } catch { }
        try { $script:TaskBrokerInstallTimer.Dispose() } catch { }
    }
    if ($script:TaskBrokerRemoveTimer) {
        try { $script:TaskBrokerRemoveTimer.Stop() } catch { }
        try { $script:TaskBrokerRemoveTimer.Dispose() } catch { }
    }
    if ($script:UpdateState) {
        try { Stop-UpdateCheckUiWorker } catch { }
        try { Stop-UpdatePrepareUiWorker } catch { }
    }
    $backgroundRefreshContext = $null
    if ($script:BackgroundRefreshState) {
        $backgroundRefreshContext = Take-BackgroundRefreshCompletionContext -State $script:BackgroundRefreshState
        [void](Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState)
    }
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Timer) {
        try { $backgroundRefreshContext.Timer.Stop() } catch { }
        try { $backgroundRefreshContext.Timer.Dispose() } catch { }
    }
    if ($script:DarkActionTooltip) {
        try { Hide-DarkActionTooltip } catch { }
        try { $script:DarkActionTooltip.Dispose() } catch { }
    }
    if ($script:DarkActionTooltipFont) {
        try { $script:DarkActionTooltipFont.Dispose() } catch { }
    }
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Process) {
        try { $backgroundRefreshContext.Process.Refresh() } catch { }
        try { if (-not $backgroundRefreshContext.Process.HasExited) { $backgroundRefreshContext.Process.Kill() } } catch { }
        try { $backgroundRefreshContext.Process.Dispose() } catch { }
    }
    if ($backgroundRefreshContext) {
        Remove-BackgroundRefreshResultFile -Path ([string]$backgroundRefreshContext.ResultPath)
    }
    if ($script:TrayIcon) {
        $script:TrayIcon.Visible = $false
        $script:TrayIcon.Dispose()
    }
    if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Dispose() }
    if ($mutex) {
        if ($mutexOwned) {
            try { $mutex.ReleaseMutex() } catch { }
            $mutexOwned = $false
        }
        try { $mutex.Dispose() } catch { }
        $mutex = $null
    }
    if ($script:RestartAfterFatal) {
        [void](Start-LenovoBootSelectorHidden)
    }
}
