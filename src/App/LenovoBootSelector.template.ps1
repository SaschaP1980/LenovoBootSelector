#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$HideConsole,
    [switch]$BackgroundRefresh,
    [switch]$BootNextWorker,
    [switch]$DefaultTargetWorker,
    [string]$DefaultTargetGuid,
    [switch]$DefaultTargetClear,
    [string]$DefaultTargetResultPath,
    [string]$DefaultTargetProgressPath,
    [string]$BootNextGuid,
    [string]$BootNextResultPath,
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

# LBS-17: pure localization is loaded before startup recovery so duplicate-instance
# and fatal-startup UI can honor the persisted locale safely.
# @include src/Core/Localization.ps1
# @include src/Core/EntryPreferences.ps1
# @include src/Core/PortablePreferences.ps1
# @include src/Core/BootNextOwnership.ps1
# @include src/Core/BootNextSelectionState.ps1
# @include src/UI/StartupRecoveryDialog.ps1
# @include src/Infrastructure/InstanceActivation.ps1

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

// Small, deterministic country flags shared by the Language submenu and settings.
// Drawn locally at the active DPI; no emoji fonts, native image gutters or assets.
public static class LenovoLocaleFlags
{
    private const string MenuName = "LenovoLanguageDropDown";
    private static int Scale(int value, float dpi)
    {
        return Math.Max(1, (int)Math.Round(value * Math.Max(96f, dpi) / 96f));
    }

    // Graphics.DpiX is the native GDI pixel density of the paint surface.
    // Glyph dimensions use this density, not (font.SizeInPoints / 9), since
    // typographic point sizes must remain constant across monitor scales.

    public static string GetLocale(ToolStripItem item)
    {
        if (item == null || item.Owner == null || item.Owner.Name != MenuName)
            return null;
        if (item.Name == "LocaleFlag.en-US") return "en-US";
        if (item.Name == "LocaleFlag.de-DE") return "de-DE";
        return null;
    }

    public static Rectangle GetBounds(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return Rectangle.Empty;
        int width = Scale(16, dpi);
        int height = Scale(12, dpi);
        return new Rectangle(row.Left + Scale(10, dpi),
            row.Top + Math.Max(0, (row.Height - height) / 2), width, height);
    }

    public static int TextLeft(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return row.Left;
        return row.Left + Scale(34, dpi);
    }

    public static Rectangle GetTextBounds(ToolStripItem item, Rectangle row, float dpi)
    {
        if (GetLocale(item) == null) return Rectangle.Empty;
        int left = TextLeft(item, row, dpi);
        // Reserve the right-side checkmark independently of WinForms' original
        // TextRectangle. The native rectangle may be only a few pixels wide
        // because the menu deliberately suppresses the image/check gutters.
        int right = row.Right - Scale(32, dpi);
        return new Rectangle(left, row.Top, Math.Max(0, right - left), row.Height);
    }

    public static void Draw(Graphics g, ToolStripItem item, Rectangle row)
    {
        string locale = GetLocale(item);
        if (locale == null || g == null) return;
        DrawFlag(g, locale, GetBounds(item, row, g.DpiX));
    }

    public static void DrawFlag(Graphics g, string locale, Rectangle flag)
    {
        if (g == null || flag.Width <= 0 || flag.Height <= 0 ||
            (locale != "de-DE" && locale != "en-US")) return;
        GraphicsState saved = g.Save();
        try
        {
            g.SmoothingMode = SmoothingMode.None;
            g.SetClip(flag, CombineMode.Intersect);
            if (locale == "de-DE")
            {
                Color[] bands = { Color.Black, Color.FromArgb(221, 0, 0), Color.FromArgb(255, 206, 0) };
                for (int i = 0; i < bands.Length; i++)
                {
                    using (Brush brush = new SolidBrush(bands[i]))
                        g.FillRectangle(brush, new RectangleF(flag.Left, flag.Top + i * flag.Height / 3f,
                            flag.Width, flag.Height / 3f + 0.3f));
                }
            }
            else
            {
                using (Brush white = new SolidBrush(Color.White))
                    g.FillRectangle(white, flag);
                // Rasterize all thirteen official stripes onto the available pixels.
                // Pixel-center sampling keeps the first and last stripes red,
                // including at 16x12 where one logical stripe cannot get a row.
                using (Brush red = new SolidBrush(Color.FromArgb(178, 34, 52)))
                    for (int y = 0; y < flag.Height; y++)
                    {
                        int stripe = Math.Min(12, (int)Math.Floor((y + 0.5) * 13.0 / flag.Height));
                        if ((stripe % 2) == 0)
                            g.FillRectangle(red, flag.Left, flag.Top + y, flag.Width, 1);
                    }
                RectangleF canton = new RectangleF(flag.Left, flag.Top,
                    flag.Width * 0.47f, flag.Height * 7f / 13f);
                using (Brush blue = new SolidBrush(Color.FromArgb(60, 59, 110)))
                    g.FillRectangle(blue, canton);
                // At this icon size, light star dots are legible without tiny glyphs.
                using (Brush stars = new SolidBrush(Color.White))
                {
                    float dot = Math.Max(1f, g.DpiX / 96f);
                    for (int rowIndex = 0; rowIndex < 3; rowIndex++)
                        for (int col = 0; col < 3; col++)
                            g.FillRectangle(stars, canton.Left + (col + 0.5f) * canton.Width / 3f,
                                canton.Top + (rowIndex + 0.5f) * canton.Height / 3f, dot, dot);
                }
            }
        }
        finally { g.Restore(saved); }
    }
}

// LBS-270: action hover is independent of status, selection and operation ink.
public static class LenovoInteractionPalette
{
    public static readonly Color Hover = Color.FromArgb(255,110,102);
    public static readonly Color Normal = Color.FromArgb(184,184,184);
    public static readonly Color Disabled = Color.FromArgb(119,119,119);
    public static readonly Color Active = Color.FromArgb(225,37,27);
    // The full-frame and inline treatments share a single hover token.
    // Keep both pure white and the configured #FCFCFC text at >= 4.5:1.
    public static readonly Color PrimaryHover = Color.FromArgb(225,41,32);
    public static Color Tint(Color surface)
    {
        return Color.FromArgb((int)Math.Round(surface.R*0.88+Hover.R*0.12),
            (int)Math.Round(surface.G*0.88+Hover.G*0.12),
            (int)Math.Round(surface.B*0.88+Hover.B*0.12));
    }
    public static Color ButtonHoverSurface(Color surface)
    {
        return surface.ToArgb() == Active.ToArgb() ? PrimaryHover : Tint(surface);
    }
    public static void DrawHoverFrame(Graphics g, Rectangle bounds, int inset)
    {
        if (SystemInformation.HighContrast) return;
        int line = Math.Max(1,(int)Math.Round(g.DpiX / 96f));
        bounds.Inflate(-inset*line,-inset*line);
        if (bounds.Width < 2*line || bounds.Height < 2*line) return;
        using (Brush brush = new SolidBrush(Hover)) {
            g.FillRectangle(brush,bounds.Left,bounds.Top,bounds.Width,line);
            g.FillRectangle(brush,bounds.Left,bounds.Bottom-line,bounds.Width,line);
            g.FillRectangle(brush,bounds.Left,bounds.Top+line,line,bounds.Height-2*line);
            g.FillRectangle(brush,bounds.Right-line,bounds.Top+line,line,bounds.Height-2*line);
        }
    }
    public static void DrawInlineUnderline(Graphics g, Rectangle bounds, string text, Font font)
    { DrawInlineUnderline(g,bounds,text,font,false); }
    public static void DrawInlineUnderline(Graphics g, Rectangle bounds, string text, Font font, bool leftAligned)
    {
        if (SystemInformation.HighContrast || bounds.Width < 6 || bounds.Height < 6) return;
        int px=Math.Max(1,(int)Math.Round(g.DpiX / 96f));
        int width=Math.Min(bounds.Width-4*px,TextRenderer.MeasureText(g,text,font,
            new Size(bounds.Width,bounds.Height),TextFormatFlags.SingleLine|TextFormatFlags.NoPadding).Width);
        if (width <= 0) return;
        using (Brush brush=new SolidBrush(Hover))
            g.FillRectangle(brush,leftAligned ? bounds.Left+2*px : bounds.Left+(bounds.Width-width)/2,bounds.Bottom-3*px,width,2*px);
    }
    public static void DrawIconHalo(Graphics g, Rectangle bounds)
    {
        if (SystemInformation.HighContrast) return;
        int side=Math.Min(bounds.Width,bounds.Height);
        int inset=Math.Max(2,side/10);
        side-=2*inset;
        if (side <= 0) return;
        var state=g.Save();
        try {
            g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using (Brush brush=new SolidBrush(Color.FromArgb(31,Hover)))
                g.FillEllipse(brush,bounds.Left+(bounds.Width-side)/2,bounds.Top+(bounds.Height-side)/2,side,side);
        } finally { g.Restore(state); }
    }
}

// Native Button retains input, accessibility, DialogResult, default and focus
// painting. Only pointer-owned appearance is changed and restored on exit.
public sealed class LenovoActionButton : Button
{
    public bool InlineAction { get; set; }
    public bool PreserveSelection { get; set; }
    private bool hovered, styled, keyPressed, mousePressed;
    private Color oldSurface, oldInk;
    private void ApplyPointerStyle()
    {
        bool hot=Enabled && hovered && !SystemInformation.HighContrast;
        if (hot) {
            if (!styled) {
                oldSurface=FlatAppearance.MouseOverBackColor;
                oldInk=ForeColor;
                styled=true;
            }
            FlatAppearance.MouseOverBackColor=InlineAction ? BackColor :
                PreserveSelection ? BackColor : LenovoInteractionPalette.ButtonHoverSurface(BackColor);
            if (InlineAction) ForeColor=LenovoInteractionPalette.Hover;
        } else if (styled) {
            styled=false;
            FlatAppearance.MouseOverBackColor=oldSurface;
            if (InlineAction) ForeColor=oldInk;
        }
    }
    protected override void OnMouseEnter(EventArgs e) {
        hovered=Enabled; ApplyPointerStyle(); base.OnMouseEnter(e); Invalidate();
    }
    protected override void OnMouseLeave(EventArgs e) {
        hovered=false; ApplyPointerStyle(); base.OnMouseLeave(e); Invalidate();
    }
    protected override void OnEnabledChanged(EventArgs e) {
        mousePressed=keyPressed=false;
        hovered=Enabled && IsHandleCreated && Visible && ClientRectangle.Contains(PointToClient(Cursor.Position));
        ApplyPointerStyle(); base.OnEnabledChanged(e); Invalidate();
    }
    protected override void OnBackColorChanged(EventArgs e) {
        base.OnBackColorChanged(e);
        if (hovered) ApplyPointerStyle();
    }
    protected override void OnSystemColorsChanged(EventArgs e) {
        base.OnSystemColorsChanged(e); ApplyPointerStyle(); Invalidate();
    }
    protected override void OnVisibleChanged(EventArgs e) {
        if (!Visible) { hovered=false; mousePressed=keyPressed=false; ApplyPointerStyle(); }
        base.OnVisibleChanged(e);
    }
    protected override void OnMouseDown(MouseEventArgs e) {
        mousePressed=e.Button==MouseButtons.Left; base.OnMouseDown(e); Invalidate();
    }
    protected override void OnMouseUp(MouseEventArgs e) {
        mousePressed=false; base.OnMouseUp(e); Invalidate();
    }
    protected override void OnMouseCaptureChanged(EventArgs e) {
        mousePressed=false; base.OnMouseCaptureChanged(e); Invalidate();
    }
    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.KeyCode==Keys.Space) keyPressed=true; base.OnKeyDown(e); Invalidate();
    }
    protected override void OnKeyUp(KeyEventArgs e) {
        if (e.KeyCode==Keys.Space) keyPressed=false; base.OnKeyUp(e); Invalidate();
    }
    protected override void OnLostFocus(EventArgs e) {
        keyPressed=false; base.OnLostFocus(e); Invalidate();
    }
    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        if (!Enabled || !hovered || SystemInformation.HighContrast || keyPressed || mousePressed ||
            (Control.MouseButtons & System.Windows.Forms.MouseButtons.Left) != 0) return;
        if (InlineAction) LenovoInteractionPalette.DrawInlineUnderline(e.Graphics,ClientRectangle,Text,Font);
        else LenovoInteractionPalette.DrawHoverFrame(e.Graphics,ClientRectangle,PreserveSelection ? 1 : 0);
    }
}

// Native glyph controls retain their original hit area, focus and dispatch.
// Hover is inferred only from the established pointer-owned hover ink.
public sealed class LenovoHoverGlyphLabel : Label
{
    protected override void OnPaintBackground(PaintEventArgs e)
    {
        base.OnPaintBackground(e);
        if (Enabled && ForeColor.ToArgb()==LenovoInteractionPalette.Hover.ToArgb() &&
            (Control.MouseButtons & System.Windows.Forms.MouseButtons.Left)==0)
            LenovoInteractionPalette.DrawIconHalo(e.Graphics,ClientRectangle);
    }
}
public sealed class LenovoHoverGlyphButton : Button
{
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (!Enabled || SystemInformation.HighContrast || ForeColor.ToArgb()!=LenovoInteractionPalette.Hover.ToArgb() ||
            (Control.MouseButtons & System.Windows.Forms.MouseButtons.Left)!=0) return;
        // The circular cue is inside the native focus perimeter.
        LenovoInteractionPalette.DrawIconHalo(e.Graphics,ClientRectangle);
        TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,ForeColor,
            TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|
            TextFormatFlags.SingleLine|TextFormatFlags.NoPrefix|TextFormatFlags.PreserveGraphicsClipping);
    }
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

    private static int Ui(int value, float scale)
    {
        return Math.Max(1, (int)Math.Round(value * scale));
    }

    private void DrawRightCheck(Graphics g, Rectangle row, bool enabled, float dpi)
    {
        float scale = Math.Max(1f, dpi / 96f);
        int size = Ui(14, scale);
        int x = Math.Max(row.Left + Ui(2, scale), row.Right - Ui(24, scale));
        int y = row.Top + Math.Max(1, (row.Height - size) / 2);
        Rectangle box = new Rectangle(x, y, size, size);
        SmoothingMode oldMode = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (Brush brush = new SolidBrush(enabled ? accent : disabled))
            g.FillRectangle(brush, box);
        using (Pen pen = new Pen(Color.White, Math.Max(1f, 1.8f * scale)))
        {
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            g.DrawLines(pen, new Point[] {
                new Point(box.Left + Ui(3, scale), box.Top + Ui(7, scale)),
                new Point(box.Left + Ui(6, scale), box.Top + Ui(10, scale)),
                new Point(box.Left + Ui(11, scale), box.Top + Ui(4, scale))
            });
        }
        g.SmoothingMode = oldMode;
    }

    private void DrawRightArrow(Graphics g, Rectangle row, bool enabled, float dpi)
    {
        float scale = Math.Max(1f, dpi / 96f);
        int cx = row.Right - Ui(15, scale);
        int cy = row.Top + (row.Height / 2);
        Color c = enabled ? arrow : disabled;
        using (Brush brush = new SolidBrush(c))
        {
            Point[] points = new Point[] {
                new Point(cx - Ui(2, scale), cy - Ui(4, scale)),
                new Point(cx + Ui(2, scale), cy),
                new Point(cx - Ui(2, scale), cy + Ui(4, scale))
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
                bool pointerHot = !SystemInformation.HighContrast && !hotItem.Pressed &&
                    Object.ReferenceEquals(LenovoMenuLayout.HitTestRow(dropDown,dropDown.PointToClient(Control.MousePosition)),hotItem);
                Color rowSurface = pointerHot ? LenovoInteractionPalette.Tint(submenu ? submenuBg : rootBg) : selected;
                using (Brush selectionBrush = new SolidBrush(rowSurface))
                    e.Graphics.FillRectangle(selectionBrush, new Rectangle(left, top, right - left, bottom - top));
            }
        }

        // Submenus retain their original subdued edge. The standard-target
        // root dropdown alone needs a neutral contrast boundary against the
        // main popup's near-identical dark surfaces (#161616 vs #191919).
        if (submenu && dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            using (Pen edgePen = new Pen(submenuEdge, 1f))
                e.Graphics.DrawRectangle(edgePen, 0, 0, dropDown.ClientSize.Width - 1, dropDown.ClientSize.Height - 1);
        }
        if (!submenu &&
            String.Equals(dropDown.Name, "DefaultTargetContextMenu", StringComparison.Ordinal) &&
            dropDown.ClientSize.Width > 1 && dropDown.ClientSize.Height > 1)
        {
            float edgeWidth = Math.Max(1f, (float)Math.Round(e.Graphics.DpiX / 96f));
            float offset = edgeWidth / 2f;
            using (Pen edgePen = new Pen(Color.FromArgb(108, 108, 108), edgeWidth))
                e.Graphics.DrawRectangle(edgePen, offset, offset,
                    Math.Max(0f, dropDown.ClientSize.Width - edgeWidth),
                    Math.Max(0f, dropDown.ClientSize.Height - edgeWidth));
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
            DrawRightArrow(e.Graphics, row, item.Enabled, e.Graphics.DpiX);
        else if (item.Checked)
            DrawRightCheck(e.Graphics, row, item.Enabled, e.Graphics.DpiX);

        LenovoLocaleFlags.Draw(e.Graphics, item, row);
        e.Graphics.Restore(state);
    }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        ToolStripDropDown owner = e.ToolStrip as ToolStripDropDown;
        if (owner == null || e.Item == null || e.Graphics == null)
        {
            base.OnRenderItemText(e);
            return;
        }
        // LBS-144 native 240-DPI raster RED: base.OnRenderItemText printed
        // a 12px glyph on both 96-DPI and 240-DPI GDI+ surfaces, whereas
        // Graphics.DrawString produces 12px and 30px respectively. Do not
        // multiply 9pt fonts: render typographic points on the target HDC.
        Rectangle row = FullRowBounds(owner, e.Item);
        Rectangle text;
        if (LenovoLocaleFlags.GetLocale(e.Item) != null)
        {
            // Preserve the full language label and dedicated, DPI-scaled flag.
            text = LenovoLocaleFlags.GetTextBounds(e.Item, row, e.Graphics.DpiX);
            // LBS-117: language labels expose their expanded text rectangle.
            e.TextRectangle = text;
        }
        else
        {
            // The native item TextRectangle may carry a stale 96-DPI height
            // or a hidden image gutter. Use full item-local row coordinates.
            int left = row.Left + Math.Max(0, e.Item.Padding.Left);
            int right = row.Right - Math.Max(0, e.Item.Padding.Right);
            text = new Rectangle(left, row.Top, Math.Max(0, right - left), row.Height);
        }
        if (text.Width <= 0 || text.Height <= 0) return;
        GraphicsState state = e.Graphics.Save();
        try
        {
            e.Graphics.ResetClip();
            using (StringFormat format = (StringFormat)StringFormat.GenericTypographic.Clone())
            using (Brush brush = new SolidBrush(!SystemInformation.HighContrast && e.Item.Enabled && !e.Item.Pressed && Object.ReferenceEquals(LenovoMenuLayout.GetVisualHotItem(owner), e.Item) && Object.ReferenceEquals(LenovoMenuLayout.HitTestRow(owner, owner.PointToClient(Control.MousePosition)), e.Item) ? LenovoInteractionPalette.Hover : e.TextColor))
            {
                format.Alignment = StringAlignment.Near;
                format.LineAlignment = StringAlignment.Center;
                format.FormatFlags |= StringFormatFlags.NoWrap;
                format.Trimming = StringTrimming.EllipsisCharacter;
                format.HotkeyPrefix = System.Drawing.Text.HotkeyPrefix.Show;
                Font font = e.TextFont ?? e.Item.Font;
                e.Graphics.DrawString(e.Text ?? String.Empty, font, brush, text, format);
            }
        }
        finally { e.Graphics.Restore(state); }
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
    // ToolStrip's default Down key may leave an unavailable or disabled menu
    // item selected. Navigate the visible enabled actions explicitly while
    // retaining native Right/Left/Enter/Escape handling and actual Click events.
    public static bool SelectEnabledArrowItem(ToolStripDropDown menu, Keys keyData)
    {
        Keys key = keyData & Keys.KeyCode;
        if (key != Keys.Up && key != Keys.Down) return false;
        if (menu == null || menu.IsDisposed) return true;
        int count = menu.Items.Count;
        if (count == 0) return true;
        int start = key == Keys.Up ? 0 : -1;
        for (int i = 0; i < count; i++)
            if (menu.Items[i].Selected) { start = i; break; }
        int direction = key == Keys.Up ? -1 : 1;
        for (int offset = 1; offset <= count; offset++)
        {
            int index = ((start + direction * offset) % count + count) % count;
            ToolStripMenuItem candidate = menu.Items[index] as ToolStripMenuItem;
            if (candidate == null || !candidate.Available || !candidate.Enabled) continue;
            candidate.Select();
            InvalidateWholeMenu(menu);
            return true;
        }
        return true;
    }

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
        // Native keyboard selection must outrank the last stationary pointer
        // position. WinForms also updates Selected during actual mouse hover,
        // retaining pointer behavior while keeping arrow focus visible.
        foreach (ToolStripItem candidate in menu.Items)
        {
            ToolStripMenuItem menuItem = candidate as ToolStripMenuItem;
            if (menuItem == null || !menuItem.Available) continue;
            if (menuItem.Pressed || menuItem.Selected) return menuItem;
        }
        try
        {
            Point point = menu.PointToClient(Control.MousePosition);
            if (menu.ClientRectangle.Contains(point))
            {
                ToolStripMenuItem hit = HitTestRow(menu, point) as ToolStripMenuItem;
                if (hit != null && hit.Available) return hit;
            }
        }
        catch { }
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
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    public int TargetWidth { get; set; }
    public LenovoContextMenuStrip()
    {
        TargetWidth = 260;
        ShowCheckMargin = false;
        ShowImageMargin = false;
    }

    // NotifyIcon's native context-menu path establishes a foreground HWND.
    // This tray menu is manually positioned (mixed-DPI safety), so restore
    // native keyboard activation without touching its placement or handlers.
    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        if (Visible && AutoClose && IsHandleCreated)
        {
            SetForegroundWindow(Handle);
            Focus();
        }
    }

    protected override bool ProcessDialogKey(Keys keyData)
    {
        if (LenovoMenuLayout.SelectEnabledArrowItem(this, keyData)) return true;
        return base.ProcessDialogKey(keyData);
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

    protected override bool ProcessDialogKey(Keys keyData)
    {
        if (LenovoMenuLayout.SelectEnabledArrowItem(this, keyData)) return true;
        return base.ProcessDialogKey(keyData);
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
        HoverColor = LenovoInteractionPalette.Hover;
        Cursor = Cursors.Hand;
        AutoSize = false;
    }

    protected override void OnMouseEnter(EventArgs e) { hovering = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovering = false; Invalidate(); base.OnMouseLeave(e); }

    // The popup scales the control bounds from immutable 96-DPI geometry.
    // Scale this owner-drawn glyph exactly once from its paint-surface DPI;
    // the Windows SystemAware host will map the resulting pixels to a 100%
    // secondary display. Neither OS display position nor Font.Size is scaled.
    public static Rectangle GetGlyphBounds(Size clientSize, float dpi)
    {
        if (clientSize.Width <= 0 || clientSize.Height <= 0) return Rectangle.Empty;
        float scale = dpi > 0f ? Math.Max(1f, Math.Min(5f, dpi / 96f)) : 1f;
        int designSide = (int)Math.Round(18f * scale, MidpointRounding.AwayFromZero);
        int availableSide = Math.Min(clientSize.Width - 2, clientSize.Height - 2);
        if (availableSide < 1) return Rectangle.Empty;
        int side = Math.Min(designSide, availableSide);
        return new Rectangle((clientSize.Width - side) / 2,
                             (clientSize.Height - side) / 2, side, side);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        float scale = e.Graphics.DpiX > 0f ? Math.Max(1f, Math.Min(5f, e.Graphics.DpiX / 96f)) : 1f;
        Rectangle box = GetGlyphBounds(ClientSize, e.Graphics.DpiX);
        if (!box.IsEmpty)
        {
            Color fill = Checked ? AccentColor : BoxBackColor;
            using (Brush b = new SolidBrush(fill)) e.Graphics.FillRectangle(b, box);
            using (Pen p = new Pen(Enabled && hovering && !SystemInformation.HighContrast ? HoverColor : Checked ? AccentColor : BoxBorderColor, Math.Max(1f, scale)))
                e.Graphics.DrawRectangle(p, box);
            if (Checked)
            {
                using (Pen p = new Pen(Color.White, 1.8f * scale))
                {
                    p.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                    p.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                    e.Graphics.DrawLines(p, new PointF[] {
                        new PointF(box.Left + box.Width * 0.24f, box.Top + box.Height * 0.52f),
                        new PointF(box.Left + box.Width * 0.42f, box.Top + box.Height * 0.72f),
                        new PointF(box.Left + box.Width * 0.76f, box.Top + box.Height * 0.29f)
                    });
                }
            }
        }
        int textLeft = (int)Math.Round(24f * scale, MidpointRounding.AwayFromZero);
        if (!String.IsNullOrEmpty(Text))
            TextRenderer.DrawText(e.Graphics, Text, Font,
                new Rectangle(textLeft, 0, Math.Max(0, Width - textLeft), Height),
                Enabled ? ForeColor : Color.FromArgb(105,105,105),
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
    }
}


// Configuration-only drawing. Native Button and CheckBox retain input,
// enabled state, tab order and click semantics; painting does not dispatch.
public static class LenovoSettingsInk
{
    public static int Px(float dpi, int value)
    { return Math.Max(1, (int)Math.Round(value * Math.Max(96f, dpi) / 96f)); }

    public static Color Muted(bool enabled)
    { return SystemInformation.HighContrast ? (enabled ? SystemColors.ControlText : SystemColors.GrayText)
        : (enabled ? Color.FromArgb(184,184,184) : Color.FromArgb(146,146,146)); }

    public static void DrawIcon(Graphics g, string key, Rectangle bounds, Color ink)
    {
        if (bounds.Width <= 0 || bounds.Height <= 0) return;
        GraphicsState state = g.Save();
        try {
            g.TranslateTransform(bounds.X, bounds.Y);
            g.ScaleTransform(bounds.Width / 24f, bounds.Height / 24f);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (Pen p = new Pen(ink, 1.6f)) {
                p.StartCap = p.EndCap = LineCap.Round;
                p.LineJoin = LineJoin.Round;
                switch (key) {
                    case "autostart":
                        g.DrawArc(p, 4, 4, 16, 16, -55, 290);
                        g.DrawLine(p, 12, 2, 12, 11); break;
                    case "system-setup":
                        g.DrawLines(p, new Point[] { new Point(20,3), new Point(15,3), new Point(12,6), new Point(13,10), new Point(4,19), new Point(7,22), new Point(16,13), new Point(20,14), new Point(23,10), new Point(23,6), new Point(19,10), new Point(16,7), new Point(20,3) }); break;
                    case "system-remove":
                        g.DrawLine(p, 4, 6, 20, 6);
                        g.DrawLines(p,new Point[] { new Point(8,6),new Point(8,3),new Point(16,3),new Point(16,6) });
                        g.DrawLines(p,new Point[] { new Point(6,7),new Point(7,21),new Point(17,21),new Point(18,7) });
                        g.DrawLine(p,10,10,10,17); g.DrawLine(p,14,10,14,17); break;
                    case "update-check":
                        g.DrawArc(p,4,4,16,16,-75,310);
                        g.DrawLines(p,new Point[] { new Point(20,3),new Point(20,10),new Point(13,10) }); break;
                    case "update-install":
                    case "diagnostics-upload":
                        bool up = key == "diagnostics-upload";
                        g.DrawLine(p,12,3,12,16);
                        if (up) g.DrawLines(p,new Point[] { new Point(7,8),new Point(12,3),new Point(17,8) });
                        else g.DrawLines(p,new Point[] { new Point(7,11),new Point(12,16),new Point(17,11) });
                        g.DrawLines(p,new Point[] { new Point(4,15),new Point(4,21),new Point(20,21),new Point(20,15) }); break;
                    case "preferences-drive":
                        g.DrawRectangle(p,3,5,18,14); g.DrawLine(p,3,14,21,14); g.DrawEllipse(p,6,16,1,1); g.DrawLine(p,10,17,17,17); break;
                    case "preferences-json":
                        g.DrawLines(p,new Point[] {new Point(5,3),new Point(14,3),new Point(19,8),new Point(19,21),new Point(5,21),new Point(5,3)});
                        g.DrawLines(p,new Point[] {new Point(14,3),new Point(14,8),new Point(19,8)});
                        g.DrawLines(p,new Point[] {new Point(10,11),new Point(8,11),new Point(8,14),new Point(7,15),new Point(8,16),new Point(8,19),new Point(10,19)});
                        g.DrawLines(p,new Point[] {new Point(14,11),new Point(16,11),new Point(16,14),new Point(17,15),new Point(16,16),new Point(16,19),new Point(14,19)}); break;
                    case "preferences-language":
                        g.DrawEllipse(p,3,3,18,18); g.DrawEllipse(p,8,3,8,18); g.DrawLine(p,3,12,21,12); break;
                    case "preferences-alias":
                        g.DrawLines(p,new Point[] {new Point(4,6),new Point(13,6),new Point(21,14),new Point(14,21),new Point(4,11),new Point(4,6)}); g.DrawEllipse(p,7,8,2,2); break;
                    case "preferences-visible":
                        g.DrawArc(p,2,5,20,14,180,180); g.DrawArc(p,2,5,20,14,0,180); g.DrawEllipse(p,9,9,6,6); break;
                    case "preferences-order":
                        g.DrawLine(p,7,4,7,20); g.DrawLines(p,new Point[] {new Point(3,8),new Point(7,4),new Point(11,8)});
                        g.DrawLine(p,17,4,17,20); g.DrawLines(p,new Point[] {new Point(13,16),new Point(17,20),new Point(21,16)}); break;
                    case "preferences-shield":
                        g.DrawLines(p,new Point[] {new Point(12,3),new Point(21,6),new Point(20,15),new Point(12,22),new Point(4,15),new Point(3,6),new Point(12,3)});
                        g.DrawLines(p,new Point[] {new Point(8,12),new Point(11,15),new Point(16,9)}); break;
                    case "preferences-lock":
                        g.DrawArc(p,7,3,10,12,180,180); g.DrawRectangle(p,5,10,14,11); g.DrawLine(p,12,14,12,17); break;
                    case "preferences-export":
                    case "preferences-import":
                        g.DrawLines(p,new Point[] { new Point(4,3),new Point(13,3),new Point(18,8),new Point(18,21),new Point(4,21),new Point(4,3) });
                        g.DrawLines(p,new Point[] { new Point(13,3),new Point(13,8),new Point(18,8) });
                        if (key == "preferences-export") {
                            g.DrawLine(p,8,14,22,14);
                            g.DrawLines(p,new Point[] { new Point(18,10),new Point(22,14),new Point(18,18) });
                        } else {
                            g.DrawLine(p,22,14,8,14);
                            g.DrawLines(p,new Point[] { new Point(12,10),new Point(8,14),new Point(12,18) });
                        }
                        break;
                    case "diagnostics-save":
                        g.DrawLines(p,new Point[] { new Point(5,3),new Point(14,3),new Point(19,8),new Point(19,21),new Point(5,21),new Point(5,3) });
                        g.DrawLines(p,new Point[] { new Point(14,3),new Point(14,8),new Point(19,8) });
                        g.DrawLine(p,8,12,16,12); g.DrawLine(p,8,16,16,16); break;
                }
            }
        } finally { g.Restore(state); }
    }

    public static Rectangle TextBounds(Rectangle bounds, float dpi, bool language)
    {
        int left = Px(dpi, language ? 42 : 44), right = Px(dpi, language ? 9 : 12);
        return new Rectangle(left, 0, Math.Max(0, bounds.Width-left-right), bounds.Height);
    }

    public static void DrawTextPair(Graphics g, Rectangle bounds, Font titleFont, Font subtitleFont,
        string title, string subtitle, Color titleInk, Color secondaryInk)
    {
        int top = Px(g.DpiX,5);
        int h = Math.Max(1,(bounds.Height-top*2)/2);
        TextFormatFlags flags = TextFormatFlags.Left | TextFormatFlags.VerticalCenter |
            TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix |
            TextFormatFlags.PreserveGraphicsClipping;
        TextRenderer.DrawText(g,title ?? "",titleFont,new Rectangle(bounds.X,top,bounds.Width,h),titleInk,flags);
        TextRenderer.DrawText(g,subtitle ?? "",subtitleFont,new Rectangle(bounds.X,top+h,bounds.Width,h),secondaryInk,flags);
    }

    public static void DrawFocus(Graphics g, Rectangle bounds, Color fg, Color bg)
    {
        bounds.Inflate(-Px(g.DpiX,3),-Px(g.DpiX,3));
        if (bounds.Width > 0 && bounds.Height > 0) ControlPaint.DrawFocusRectangle(g,bounds,fg,bg);
    }
}

// LBS-252: the same glyph renderer and layout are used in every state.
// Header icon ink is independent of native disabled text rendering.
// Keep the native Button adapter, focus cues, and all input/admission semantics.
public sealed class LenovoHeaderIconButton : Button
{
    public bool InfoIcon { get; set; }
    public bool OperationActive { get; set; }
    private bool modalActive;
    public bool ModalActive { get { return modalActive; } set { modalActive = value; Invalidate(); } }
    public LenovoHeaderIconButton()
    {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnEnabledChanged(EventArgs e)
    { base.OnEnabledChanged(e); Invalidate(); }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        bool activeInfo = InfoIcon && ModalActive;
        bool active = activeInfo || OperationActive;
        Color ink = SystemInformation.HighContrast
            ? (Enabled || active ? SystemColors.ControlText : SystemColors.GrayText)
            : (active ? LenovoInteractionPalette.Active : (Enabled ? ForeColor : LenovoInteractionPalette.Disabled));
        if (SystemInformation.HighContrast) {
            Rectangle center = ClientRectangle;
            int inset = Math.Max(2, Math.Min(center.Width,center.Height)/7);
            center.Inflate(-inset,-inset);
            using (SolidBrush surface = new SolidBrush(SystemColors.Control))
                if (center.Width > 0 && center.Height > 0) e.Graphics.FillRectangle(surface,center);
        }
        if (Enabled && !active && ForeColor.ToArgb()==LenovoInteractionPalette.Hover.ToArgb() &&
            (Control.MouseButtons & System.Windows.Forms.MouseButtons.Left)==0)
            LenovoInteractionPalette.DrawIconHalo(e.Graphics,ClientRectangle);
        float size = Math.Min(ClientSize.Width,ClientSize.Height) * 0.60f;
        if (size <= 0) return;
        GraphicsState saved = e.Graphics.Save();
        try {
            e.Graphics.TranslateTransform((ClientSize.Width-size)/2f,(ClientSize.Height-size)/2f);
            e.Graphics.ScaleTransform(size/24f,size/24f);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (Pen p = new Pen(ink,2.4f)) {
                p.StartCap = p.EndCap = LineCap.Round;
                p.LineJoin = LineJoin.Round;
                if (InfoIcon) {
                    e.Graphics.DrawEllipse(p,2.5f,2.5f,19f,19f);
                    e.Graphics.DrawLine(p,12f,11f,12f,17f);
                    using (SolidBrush dot = new SolidBrush(ink))
                        e.Graphics.FillEllipse(dot,10.7f,6.1f,2.6f,2.6f);
                } else {
                    e.Graphics.DrawArc(p,3f,3f,18f,18f,185f,153f);
                    e.Graphics.DrawLines(p,new PointF[] { new PointF(16f,8f),new PointF(21f,8f),new PointF(21f,3f) });
                    e.Graphics.DrawArc(p,3f,3f,18f,18f,5f,153f);
                    e.Graphics.DrawLines(p,new PointF[] { new PointF(8f,16f),new PointF(3f,16f),new PointF(3f,21f) });
                }
            }
        }
        finally { e.Graphics.Restore(saved); }
    }
}

// Button retains native input, accessibility, Enabled and Click semantics.
public sealed class LenovoCustomizeButton : Button
{
    private bool hovering, mousePressed, keyPressed;
    public bool PointerActivation { get; private set; }

    // Scope provenance to the native mouse-up dispatch, not hover or a stale press.
    // Keyboard/PerformClick activation retains the ordinary keyboard cue.
    protected override void WndProc(ref Message m)
    {
        if (m.Msg != 0x0202) { base.WndProc(ref m); return; } // WM_LBUTTONUP
        PointerActivation = true;
        try { base.WndProc(ref m); }
        finally { PointerActivation = false; }
    }

    public LenovoCustomizeButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    { base.OnMouseEnter(e); hovering = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e)
    { base.OnMouseLeave(e); hovering = false; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e)
    { mousePressed = e.Button == MouseButtons.Left; base.OnMouseDown(e); Invalidate(); }
    protected override void OnMouseUp(MouseEventArgs e)
    { mousePressed = false; base.OnMouseUp(e); Invalidate(); }
    protected override void OnMouseCaptureChanged(EventArgs e)
    { mousePressed = false; base.OnMouseCaptureChanged(e); Invalidate(); }
    protected override void OnKeyDown(KeyEventArgs e)
    { if (e.KeyCode == Keys.Space) keyPressed = true; base.OnKeyDown(e); Invalidate(); }
    protected override void OnKeyUp(KeyEventArgs e)
    { if (e.KeyCode == Keys.Space) keyPressed = false; base.OnKeyUp(e); Invalidate(); }
    protected override void OnGotFocus(EventArgs e)
    { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e)
    { keyPressed = false; base.OnLostFocus(e); Invalidate(); }
    protected override void OnEnabledChanged(EventArgs e)
    {
        mousePressed = keyPressed = false;
        hovering = Enabled && IsHandleCreated && Visible &&
            ClientRectangle.Contains(PointToClient(Cursor.Position));
        base.OnEnabledChanged(e);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        bool pressed = Enabled && (keyPressed || (mousePressed && hovering));
        Color bg = pressed ? FlatAppearance.MouseDownBackColor :
            Enabled && hovering ? FlatAppearance.MouseOverBackColor : BackColor;
        if (bg.IsEmpty) bg = BackColor;
        Color ink = Enabled ? (hovering && !pressed && !SystemInformation.HighContrast ? LenovoInteractionPalette.Hover : ForeColor) : Color.FromArgb(138,138,138);
        using (SolidBrush brush = new SolidBrush(bg))
            e.Graphics.FillRectangle(brush, ClientRectangle);
        TextRenderer.DrawText(e.Graphics, Text, Font, ClientRectangle, ink,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter |
            TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix |
            TextFormatFlags.PreserveGraphicsClipping);
        if (Enabled && hovering && !pressed && !SystemInformation.HighContrast)
            LenovoInteractionPalette.DrawInlineUnderline(e.Graphics,ClientRectangle,Text,Font);
        if (Enabled && Focused && ShowFocusCues) {
            Rectangle focus = ClientRectangle;
            focus.Inflate(-3,-3);
            if (focus.Width > 0 && focus.Height > 0)
                ControlPaint.DrawFocusRectangle(e.Graphics, focus, ink, bg);
        }
    }
}

public sealed class LenovoSettingsActionButton : Button
{
    public string ActionIcon { get; set; }
    public string LocaleCode { get; set; }
    public string Subtitle { get; set; }
    public Font TitleFont { get; set; }
    public Font SubtitleFont { get; set; }
    public Color HoverSurface { get; set; }
    public Color SelectedSurface { get; set; }
    public Color AccentColor { get; set; }
    public bool LanguageSelected { get; set; }
    public bool Destructive { get; set; }
    public bool Separator { get; set; }
    private bool hovering, pressed;

    public LenovoSettingsActionButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        HoverSurface = Color.FromArgb(41,41,41);
        SelectedSurface = Color.FromArgb(44,25,24);
        AccentColor = Color.FromArgb(225,37,27);
    }
    protected override void OnMouseEnter(EventArgs e) { hovering = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovering = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { pressed = e.Button == MouseButtons.Left; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnMouseCaptureChanged(EventArgs e) { pressed = false; Invalidate(); base.OnMouseCaptureChanged(e); }
    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }

    protected override AccessibleObject CreateAccessibilityInstance()
    {
        if (String.IsNullOrEmpty(LocaleCode)) return base.CreateAccessibilityInstance();
        return new LanguageAccessible(this);
    }
    private sealed class LanguageAccessible : Control.ControlAccessibleObject
    {
        private readonly LenovoSettingsActionButton button;
        public LanguageAccessible(LenovoSettingsActionButton owner) : base(owner) { button = owner; }
        public override AccessibleRole Role { get { return AccessibleRole.RadioButton; } }
        public override AccessibleStates State {
            get { return base.State | AccessibleStates.Selectable |
                (button.LanguageSelected ? AccessibleStates.Selected | AccessibleStates.Checked : AccessibleStates.None); }
        }
        public override void DoDefaultAction() { if (button.Enabled) button.PerformClick(); }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        bool language = !String.IsNullOrEmpty(LocaleCode);
        bool hc = SystemInformation.HighContrast;
        Color bg = hc ? (LanguageSelected ? SystemColors.Highlight : SystemColors.Control) :
            (Enabled && (LanguageSelected || pressed) ? SelectedSurface : Enabled && hovering ? HoverSurface : BackColor);
        Color fg = hc ? (Enabled ? (LanguageSelected ? SystemColors.HighlightText : SystemColors.ControlText) : SystemColors.GrayText) :
            (!Enabled ? LenovoSettingsInk.Muted(false) : Destructive ? Color.FromArgb(239,86,78) : ForeColor);
        if (!hc && Enabled && hovering && !pressed) fg = LenovoInteractionPalette.Hover;
        g.Clear(bg);
        float dpi = g.DpiX;
        int px = LenovoSettingsInk.Px(dpi,1);
        Rectangle text = LenovoSettingsInk.TextBounds(ClientRectangle,dpi,language);
        if (language) {
            int fw = LenovoSettingsInk.Px(dpi,16), fh = LenovoSettingsInk.Px(dpi,12);
            LenovoLocaleFlags.DrawFlag(g,LocaleCode,new Rectangle(LenovoSettingsInk.Px(dpi,12),(Height-fh)/2,fw,fh));
            TextRenderer.DrawText(g,Text,Font,text,fg,TextFormatFlags.Left | TextFormatFlags.VerticalCenter |
                TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis);
            using (Pen border = new Pen(hc ? SystemColors.ControlText : LanguageSelected ? AccentColor : Color.FromArgb(68,68,68),px))
                g.DrawRectangle(border,px/2,px/2,Math.Max(0,Width-px-1),Math.Max(0,Height-px-1));
            if (!hc && Enabled && hovering && !pressed)
                LenovoInteractionPalette.DrawHoverFrame(g,ClientRectangle,LanguageSelected ? 1 : 0);
        } else {
            int side = LenovoSettingsInk.Px(dpi,22);
            LenovoSettingsInk.DrawIcon(g,ActionIcon,new Rectangle(LenovoSettingsInk.Px(dpi,11),(Height-side)/2,side,side),
                Enabled && hovering && !pressed && !hc ? LenovoInteractionPalette.Hover : Destructive && Enabled ? fg : LenovoSettingsInk.Muted(Enabled));
            LenovoSettingsInk.DrawTextPair(g,text,TitleFont ?? Font,SubtitleFont ?? Font,Text,Subtitle,fg,LenovoSettingsInk.Muted(Enabled));
            if (Separator) using (Pen p = new Pen(hc ? SystemColors.ControlDark : Color.FromArgb(57,57,57),px))
                g.DrawLine(p,LenovoSettingsInk.Px(dpi,44),Height-px,Math.Max(0,Width-LenovoSettingsInk.Px(dpi,12)),Height-px);
        }
        if (Focused && ShowFocusCues) LenovoSettingsInk.DrawFocus(g,ClientRectangle,fg,bg);
    }
}

public sealed class LenovoSettingsAutostartLabel : Label
{
    public string Subtitle { get; set; }
    public Font TitleFont { get; set; }
    public Font SubtitleFont { get; set; }
    public Color HoverSurface { get; set; }
    internal bool TileHovered { get; set; }
    public LenovoSettingsAutostartLabel()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g=e.Graphics;
        bool hc=SystemInformation.HighContrast;
        g.Clear(hc ? SystemColors.Control : Enabled && TileHovered ? HoverSurface : BackColor);
        int side=LenovoSettingsInk.Px(g.DpiX,22), left=LenovoSettingsInk.Px(g.DpiX,44);
        Color fg=hc ? (Enabled ? SystemColors.ControlText : SystemColors.GrayText) :
            (Enabled ? ForeColor : LenovoSettingsInk.Muted(false));
        if (!hc && Enabled && TileHovered) fg=LenovoInteractionPalette.Hover;
        LenovoSettingsInk.DrawIcon(g,"autostart",new Rectangle(LenovoSettingsInk.Px(g.DpiX,11),(Height-side)/2,side,side),!hc && Enabled && TileHovered ? LenovoInteractionPalette.Hover : LenovoSettingsInk.Muted(Enabled));
        LenovoSettingsInk.DrawTextPair(g,new Rectangle(left,0,Math.Max(0,Width-left-LenovoSettingsInk.Px(g.DpiX,3)),Height),
            TitleFont ?? Font,SubtitleFont ?? Font,Text,Subtitle,fg,LenovoSettingsInk.Muted(Enabled));
    }
}

public sealed class LenovoSettingsToggle : CheckBox
{
    public Color AccentColor { get; set; }
    public Color HoverSurface { get; set; }
    internal bool TileHovered { get; set; }
    public LenovoSettingsToggle()
    {
        AutoCheck=false; AutoSize=false;
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw,true);
    }
    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g=e.Graphics;
        bool hc=SystemInformation.HighContrast;
        Color bg=hc ? SystemColors.Control : Enabled && TileHovered ? HoverSurface : BackColor;
        g.Clear(bg);
        int w=Math.Min(Math.Max(0,Width-4),LenovoSettingsInk.Px(g.DpiX,38));
        int h=Math.Min(Math.Max(0,Height-4),LenovoSettingsInk.Px(g.DpiX,22));
        if (w >= h && h >= 4) {
            Rectangle r=new Rectangle((Width-w)/2,(Height-h)/2,w,h);
            Color fill=hc ? (Checked ? SystemColors.Highlight : SystemColors.ControlDark) :
                (Checked && Enabled ? AccentColor : Color.FromArgb(85,85,85));
            g.SmoothingMode=SmoothingMode.AntiAlias;
            using (GraphicsPath path=new GraphicsPath()) {
                path.AddArc(r.Left,r.Top,h,h,90,180);
                path.AddArc(r.Right-h,r.Top,h,h,270,180);
                path.CloseFigure();
                using (Brush brush=new SolidBrush(fill)) g.FillPath(brush,path);
                // Hover belongs to the switch, not its keyboard focus perimeter.
                if (!hc && Enabled && TileHovered)
                    using (Pen pen=new Pen(LenovoInteractionPalette.Hover,Math.Max(1f,LenovoSettingsInk.Px(g.DpiX,2)))) g.DrawPath(pen,path);
            }
            int pad=LenovoSettingsInk.Px(g.DpiX,3), d=Math.Max(1,h-2*pad);
            using (Brush brush=new SolidBrush(hc ? SystemColors.ControlText : Enabled ? Color.White : Color.FromArgb(155,155,155)))
                g.FillEllipse(brush,Checked ? r.Right-pad-d : r.Left+pad,r.Top+pad,d,d);
        }
        // The settings switch is the initial keyboard target even after a
        // mouse-open. Show its real focus immediately, without changing the
        // system's cue policy or the focus state of any other control.
        if (Enabled && Focused) LenovoSettingsInk.DrawFocus(g,ClientRectangle,SystemColors.ControlText,bg);
    }
}

// One hover owner for both native autostart hit areas. Screen coordinates
// preserve the highlight across sibling transitions and clipped scrolling.
// Settings input is independent of business actions. Native hit testing
// distinguishes a visible pointer target from keyboard focus, and the modal
// enable state rejects hover underneath a nested dialog.
public static class LenovoSettingsWindowInput
{
    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")]
    private static extern bool IsWindowEnabled(IntPtr window);
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    public static bool IsPointerOnSurface(Form form, Point pointer)
    {
        if (form == null || form.IsDisposed || !form.Visible ||
            !form.IsHandleCreated || !IsWindowEnabled(form.Handle)) return false;
        IntPtr hit = WindowFromPoint(pointer);
        return hit != IntPtr.Zero && GetAncestor(hit, 2) == form.Handle;
    }

    // Called once, at the end of the user-initiated settings Shown event
    // after the owner dimmer/connector has been shown. Respect OS foreground
    // restrictions; never use periodic activation or injected input.
    public static void ActivateInitialSurface(Form form)
    {
        if (form == null || form.IsDisposed || !form.Visible ||
            !form.IsHandleCreated || !IsWindowEnabled(form.Handle)) return;
        if (GetForegroundWindow() != form.Handle) SetForegroundWindow(form.Handle);
        if (!form.ContainsFocus) form.Activate();
    }
}

public sealed class LenovoSettingsAutostartHover
{
    private readonly LenovoSettingsAutostartLabel label;
    private readonly LenovoSettingsToggle toggle;
    private readonly Form form;

    public LenovoSettingsAutostartHover(LenovoSettingsAutostartLabel label, LenovoSettingsToggle toggle)
    {
        this.label = label;
        this.toggle = toggle;
        form = label.FindForm();
        foreach (Control control in new Control[] { label, toggle }) {
            control.MouseEnter += Refresh;
            control.MouseLeave += Refresh;
            control.MouseMove += Refresh;
            control.EnabledChanged += Refresh;
            control.VisibleChanged += Refresh;
            control.LocationChanged += Refresh;
            control.SizeChanged += Refresh;
        }
        for (Control parent = label.Parent; parent != null; parent = parent.Parent) {
            parent.LocationChanged += Refresh;
            parent.SizeChanged += Refresh;
        }
        if (form != null) {
            form.Activated += Refresh;
            form.Deactivate += Clear;
        }
    }

    private static bool ContainsVisiblePoint(Control control, Point screen)
    {
        for (Control current = control; current != null; current = current.Parent) {
            if (!current.Visible || !current.IsHandleCreated ||
                !current.RectangleToScreen(current.ClientRectangle).Contains(screen)) return false;
        }
        return true;
    }

    private void Refresh(object sender, EventArgs e)
    {
        if (label.IsDisposed || toggle.IsDisposed) return;
        Point pointer = Control.MousePosition;
        SetHovered(label.Enabled && toggle.Enabled && LenovoSettingsWindowInput.IsPointerOnSurface(form, pointer) &&
            (ContainsVisiblePoint(label, pointer) || ContainsVisiblePoint(toggle, pointer)));
    }

    private void Clear(object sender, EventArgs e) { SetHovered(false); }

    private void SetHovered(bool hovered)
    {
        if (label.IsDisposed || toggle.IsDisposed) return;
        if (label.TileHovered == hovered && toggle.TileHovered == hovered) return;
        label.TileHovered = toggle.TileHovered = hovered;
        label.Invalidate();
        toggle.Invalidate();
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
        ThumbHoverColor = LenovoInteractionPalette.Hover;
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
            using (Brush b = new SolidBrush(Enabled && hoverThumb && !dragging && !SystemInformation.HighContrast ? ThumbHoverColor : ThumbColor))
                e.Graphics.FillRectangle(b, thumb);
        }
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        Rectangle thumb = GetThumbRectangle();
        if (!thumb.IsEmpty && e.Y >= thumb.Top && e.Y < thumb.Bottom)
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
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility

if ($HideConsole) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LenovoBootSelectorConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $consoleHandle = [LenovoBootSelectorConsoleWindow]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
        [LenovoBootSelectorConsoleWindow]::ShowWindow($consoleHandle, 0) | Out-Null
    }
}

# Prevent duplicate tray instances. Internal background-refresh workers deliberately
# skip the tray mutex because they do not create UI or a NotifyIcon. Ownership is
# tested explicitly: an existing-but-free named mutex is not an active instance.
$mutex = $null
$mutexOwned = $false
$activationEvent = $null
$activationListener = $null
$singleInstanceMutexState = 'not-applicable'
$singleInstanceGraceMs = 500
if (-not $BootNextWorker -and -not $BackgroundRefresh -and -not $UpdateCheck -and -not $UpdatePrepare -and -not $DefaultTargetWorker) {
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
        if (Send-LbsActivationRequest) { exit 0 }
        # A genuine failed handoff is not treated as a successful activation.
        $startupLocale = Get-StartupRecoveryLocale
        Show-FatalMessage (Get-LocalizedStringCore -Key 'Startup.AlreadyRunningMessage' -Locale $startupLocale) -AllowRestart $false | Out-Null
        exit 2
    }
    # Publish the signal immediately after mutex ownership. If the primary
    # instance is still initializing, the AutoReset event retains the request
    # until its UI listener is installed (no polling or second tray owner).
    $activationEvent = New-LbsActivationEvent
}

$script:AppVersion = '@APP_VERSION@'
$script:Popup = $null
$script:TrayIcon = $null
$script:CurrentEntries = @()
$script:SelectedGuid = $null
$script:BootNextPendingGuid = $null
$script:BootNextSelectionDeferred = $false
$script:BootNextSelectionStartedUtc = [datetime]::MinValue
$script:BootNextSelectionResultPath = $null
$script:BootNextSelectionProcess = $null
$script:BootNextSelectionTimer = $null
$script:RestartButton = $null
$script:NextBootFirmwareReadVerified = $false
$script:LastStatusText = ''
$script:ExitRequested = $false
$script:StorageContext = $null
$script:AutostartCheckbox = $null
$script:AutostartTextLabel = $null
$script:AutostartMenuItem = $null
$script:UpdatingAutostartUi = $false
$script:ScriptPath = $PSCommandPath
if (-not $script:ScriptPath) { $script:ScriptPath = $MyInvocation.MyCommand.Path }

$script:RuntimeDiagnosticsRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics\Runtime'
# Preserve the command-line parent-session input before active diagnostics state
# reuses the RuntimeSessionId name in script scope.
$script:InheritedRuntimeSessionId = [string]$RuntimeSessionId
$script:RuntimeSessionId = $null
$script:RuntimeSessionDir = $null
$script:RuntimeEventsPath = $null
$script:RuntimeSessionStartedUtc = [datetime]::UtcNow
$script:RuntimeDiagnosticsAvailable = $false
$script:RuntimeDiagnosticsErrorCount = 0
$script:LastRuntimeDiagnosticPackage = $null
$script:RuntimeDiagnosticMenuItem = $null
$script:DiagnosticsUploadMenuItem = $null
$script:DiagnosticsUploadState = $null
$script:DiagnosticsUploadTimer = $null

$script:SupportedTaskBrokerVersions = @('0.2.16')
$script:TaskBrokerStateDir = Join-Path $env:ProgramData 'Lenovo Boot Selector\TaskBroker'
$script:TaskBrokerMetadataPath = Join-Path $script:TaskBrokerStateDir 'task-broker.json'
$script:LegacyTaskBrokerStateDir = Join-Path $env:ProgramData 'Lenovo Boot Menu\TaskBroker'
$script:LegacyTaskBrokerMetadataPath = Join-Path $script:LegacyTaskBrokerStateDir 'task-broker.json'
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
$script:TrayOpenMenuItem = $null
$script:LanguageMenuRoot = $null
$script:LanguageEnglishMenuItem = $null
$script:LanguageGermanMenuItem = $null
$script:MaintenanceRootMenuItem = $null
$script:PreferencesMenuRoot = $null
$script:PreferencesExportMenuItem = $null
$script:PreferencesImportMenuItem = $null
$script:PreferencesUiActive = $false
$script:TrayExitMenuItem = $null
$script:RefreshButton = $null
$script:SystemStatusButton = $null
$script:SystemStatusCapabilities = $null
$script:SystemStatusManagerObservedUtc = $null
$script:SystemStatusManagerObservedHash = $null
$script:SystemStatusEntriesObservedUtc = $null
$script:SystemStatusEntriesObservedHash = $null
$script:SystemStatusReadinessObservedUtc = $null
$script:SystemStatusNextObservedUtc = $null
$script:SystemStatusDefaultObservedUtc = $null
$script:SystemStatusDefaultEvidence = 'unknown'
$script:SystemStatusLastRefresh = 'unknown'
$script:SystemStatusDriftFailed = $false
$script:RefreshButtonHovered = $false
$script:HeaderTitleLabel = $null
$script:HeaderStatusLabel = $null
$script:LegacyAutostartTaskName = 'Lenovo Boot Menu Tray Autostart'
$script:AutostartRunValueName = 'Lenovo Boot Selector'
$script:LegacyAutostartRunValueName = 'Lenovo Boot Menu Tray'
$script:SettingsDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:SettingsLoadState = $null
$script:UiLocale = 'en-US'
$script:LocalePreferenceSource = 'default'
$script:LocalePreferenceNeedsConfirmation = $false
$script:DefaultGuid = $null
$script:DefaultTargetReadUncertain = $false
$script:DefaultTargetChangePending = $false
$script:DefaultTargetChangeRequestedGuid = $null
$script:DefaultTargetChangeOperation = ''
$script:DefaultTargetChangeStage = ''
$script:DefaultTargetChangeWorkerStarted = $false
$script:DefaultTargetChangeStartedUtc = [datetime]::MinValue
$script:DefaultTargetChangeProcess = $null
$script:DefaultTargetChangeTimer = $null
$script:DefaultTargetChangeResultPath = $null
$script:DefaultTargetChangeProgressPath = $null
$script:LegacyDefaultGuid = $null
$script:DefaultButton = $null
$script:DefaultValueLabel = $null
$script:DefaultArrowLabel = $null
$script:DefaultInteractionEnabled = $false
$script:RestartTargetLabel = $null
$script:RestartUseDefaultButton = $null
$script:ActiveAuxiliaryPopup = $null
$script:ActiveOwnedDialog = $null
$script:DefaultContextRoot = $null
$script:LegacySessionRestoreRegistryPath = 'HKCU:\Volatile Environment'
$script:LegacySessionRestoreValueName = 'LenovoBootMenuTrayDefaultRestoreProcessed'
$script:RestartMenuItem = $null
$script:EntryOrder = @()
$script:HiddenEntryGuids = @()
$script:EntryAliases = @{}
$script:IsManageEntriesMode = $false
$script:ManageUndoHistory = $null
$script:ManageUndoInventory = @()
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

# @include src/UI/DpiWindowDiagnostics.ps1
# @include src/UI/MenuAppearance.ps1

# @include src/UI/RefreshPresentation.ps1

# @include src/Infrastructure/DiagnosticsIdentity.ps1
# @include src/Infrastructure/DiagnosticsUploadTransport.ps1
# @include src/Infrastructure/RuntimeDiagnostics.ps1
# @include src/Infrastructure/UpdateTransport.ps1
# @include src/Infrastructure/UpdateClient.ps1
# @include src/Application/UpdateController.ps1

# @include src/UI/DiagnosticsPresentation.ps1
# @include src/UI/UpdatePresentation.ps1

# @include src/Infrastructure/Autostart.ps1

# @include src/UI/AutostartPresentation.ps1

# @include src/Application/LocalizationService.ps1





# @include src/UI/ManageEntriesState.ps1

# @include src/Infrastructure/SettingsRepository.ps1
# @include src/Infrastructure/PreferencesFileRepository.ps1

# @include src/Application/SettingsService.ps1
# @include src/Application/PortablePreferencesService.ps1
# @include src/UI/LanguagePresentation.ps1

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
    $script:DefaultTargetReadUncertain = $true
    try {
        $script:DefaultGuid = Get-TaskBrokerDefaultTargetGuid
        $script:DefaultTargetReadUncertain = $false
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
    param([AllowNull()][string]$Guid, [AllowNull()][string]$ProgressPath)
    if ($script:DefaultTargetChangePending) { throw 'Ein Standardzielwechsel wird noch überprüft.' }
    if ($script:BootNextPendingGuid) { throw 'Eine manuelle BootNext-Auswahl wird noch verifiziert.' }
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if ([string]$capabilities.State -eq 'Busy') { throw 'Während der Wartung kann das Standard-Startziel nicht geändert werden.' }
    if ([string]$capabilities.State -eq 'ReinitializeRequired') { throw 'Nach einer Änderung der Startziele müssen die Systemfunktionen zuerst neu initialisiert werden.' }
    if (-not $capabilities.CanUseDefaultTarget) { throw 'Das Standard-Startziel ist erst nach Einrichtung der Systemfunktionen verfügbar.' }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $operation = if ($Guid) { 'set' } else { 'clear' }
    try {
        if ($Guid) {
            $normalized = $Guid.ToLowerInvariant()
            Set-TaskBrokerDefaultTarget -Guid $normalized
            if ($ProgressPath) {
                try { [IO.File]::WriteAllText($ProgressPath,'verifying',(New-Object Text.UTF8Encoding($false))) }
                catch { }
            }
            [void](Refresh-SystemDefaultState)
            if (-not $script:DefaultGuid -or $script:DefaultGuid -ne $normalized) {
                throw 'Das systemweite Standardziel konnte nach der Aufgaben-Ausführung nicht verifiziert werden.'
            }

            $entry = Get-EntryByGuid $normalized
            $name = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { $normalized }
            $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemSavedStatus' -Values @{ Name=$name }
        }
        else {
            Clear-TaskBrokerDefaultTarget
            if ($ProgressPath) {
                try { [IO.File]::WriteAllText($ProgressPath,'verifying',(New-Object Text.UTF8Encoding($false))) }
                catch { }
            }
            [void](Refresh-SystemDefaultState)
            if ($script:DefaultGuid) { throw 'Das systemweite Standardziel konnte nicht deaktiviert werden.' }
            $script:LastStatusText = Get-LocalizedString -Key 'Default.SystemDisabledStatus'
        }

        # DefaultSet may have synchronized the effective next-boot target inside
        # the privileged SYSTEM task. Re-read firmware before showing success.
        try { [void](Refresh-EffectiveNextBootState) }
        catch {
            $script:NextBootFirmwareReadVerified = $false
            Update-RestartTargetUi
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
        # Default persistence can succeed before a subsequent BootNext verification
        # fails. Reflect both authoritative states rather than claiming a rollback.
        try { [void](Refresh-SystemDefaultState) } catch { }
        try { [void](Refresh-EffectiveNextBootState) } catch { $script:NextBootFirmwareReadVerified = $false }
        Update-RestartTargetUi
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'DEFAULT_TARGET_CHANGE' -Stage 'default' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ operation = $operation; guid = $(if ($Guid) { $Guid.ToLowerInvariant() } else { $null }) }) -Level error
        throw
    }
}

# @include src/UI/DefaultTargetMenu.ps1

# @include src/UI/Dialogs.ps1
# @include src/UI/PortablePreferencesPresentation.ps1

# @include src/UI/MaintenancePresentation.ps1

function Refresh-EffectiveNextBootState {
    try {
        $managerText = Get-TaskBrokerFirmwareManagerText -Force
        $manager = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
        $script:SelectedGuid = if ($manager.SelectedGuid) { ([string]$manager.SelectedGuid).ToLowerInvariant() } else { $null }
        $script:NextBootFirmwareReadVerified = $true
        $script:SystemStatusNextObservedUtc = $script:SystemStatusManagerObservedUtc
        Update-RestartTargetUi
        return $script:SelectedGuid
    }
    catch {
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusNextObservedUtc = $null
        $script:SelectedGuid = $null
        Update-RestartTargetUi
        throw
    }
}

function Get-NextBootTargetDisplayName {
    if (-not $script:NextBootFirmwareReadVerified) { return (Get-LocalizedString -Key 'BootNext.Unknown') }
    if ($script:SelectedGuid) {
        $selectedEntry = Get-EntryByGuid $script:SelectedGuid
        if ($selectedEntry) { return [string](Get-EntryDisplayTitle -Entry $selectedEntry) }
        return (Get-LocalizedString -Key 'Settings.DefaultTargetUnavailable')
    }
    return (Get-LocalizedString -Key 'Boot.DefaultOrder')
}

function Use-DefaultForNextRestart {
    # LBS-206 Hotfix: use the very same guarded async selection controller
    # as a manual row activation. Do not call the synchronous firmware writer
    # here: the controller paints pending immediately, interlocks Restart,
    # and only confirms the new target after independent firmware readback.
    if ($script:BootNextPendingGuid -or $script:DefaultTargetChangePending -or $script:IsManageEntriesMode) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if (-not $capabilities.CanSetBootNext -or -not $script:DefaultGuid -or
        -not $script:NextBootFirmwareReadVerified -or -not $script:SelectedGuid -or
        $script:SelectedGuid -eq $script:DefaultGuid) { return }
    # Neither stale/unavailable target nor default may cross the task allowlist.
    if (-not (Get-EntryByGuid ([string]$script:DefaultGuid)) -or
        -not (Get-EntryByGuid ([string]$script:SelectedGuid))) { return }
    Invoke-NormalBootTargetSelection -Guid ([string]$script:DefaultGuid)
}

function Update-RestartTargetUi {
    # The persistent default is saved off-thread; no prior firmware value
    # may be presented as newly confirmed until both readbacks complete.
    if (-not $script:RestartTargetLabel -or $script:RestartTargetLabel.IsDisposed) { return }
    if ($script:DefaultTargetChangePending) {
        $entry = if ($script:DefaultTargetChangeRequestedGuid) { Get-EntryByGuid ([string]$script:DefaultTargetChangeRequestedGuid) } else { $null }
        $target = if ($entry) { Get-EntryDisplayTitle -Entry $entry } else { Get-LocalizedString -Key 'Settings.NoDefaultTarget' }
        $key = if ($script:DefaultTargetChangeStage -eq 'verifying') { 'Default.ChangeVerifyingFooter' } else { 'Default.ChangeSavingFooter' }
        $label = Get-LocalizedString -Key $key -Values @{ Target = $target }
        $script:RestartTargetLabel.Text = $label
        $script:RestartTargetLabel.ForeColor = $script:ColorWarning
        $script:RestartTargetLabel.TabStop = $false
        $script:RestartTargetLabel.AccessibleName = $label
        $script:RestartTargetLabel.AccessibleDescription = $label
        if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:RestartTargetLabel,$label) }
        if ($script:RestartUseDefaultButton -and -not $script:RestartUseDefaultButton.IsDisposed) {
            $script:RestartUseDefaultButton.Visible = $false
            $script:RestartUseDefaultButton.Enabled = $false
            $script:RestartUseDefaultButton.TabStop = $false
        }
        Update-BootNextRestartInterlock
        return
    }
    $hasTarget = (-not $script:SelectedGuid -or $null -ne (Get-EntryByGuid $script:SelectedGuid))
    $model = Resolve-BootNextDisplayStateCore -DefaultGuid $script:DefaultGuid -EffectiveNextGuid $script:SelectedGuid -FirmwareReadSucceeded ([bool]$script:NextBootFirmwareReadVerified) -Checking $false -EffectiveTargetKnown $hasTarget
    $next = Get-NextBootTargetDisplayName
    $default = Get-DefaultEntryTitle
    switch ($model) {
        'unknown'        { $labelKey = 'BootNext.LayoutUnknown' }
        'firmware-order' { $labelKey = 'BootNext.LayoutFirmwareOrder' }
        'aligned'        { $labelKey = 'BootNext.LayoutAligned' }
        'different'      { $labelKey = 'BootNext.LayoutDifferent' }
        'unavailable'    { $labelKey = 'BootNext.LayoutUnavailable' }
        default          { $labelKey = 'BootNext.LayoutUnknown' }
    }
    $label = Get-LocalizedString -Key $labelKey -Values @{ Next=$next; Default=$default }
    $script:RestartTargetLabel.Text = $label
    $script:RestartTargetLabel.AccessibleName = $label
    $script:RestartTargetLabel.AccessibleDescription = $label
    $script:RestartTargetLabel.TabStop = $false
    $script:RestartTargetLabel.Cursor = [Windows.Forms.Cursors]::Default
    $script:RestartTargetLabel.ForeColor = if ($model -in @('unknown','unavailable')) {
        $script:ColorWarning
    } elseif ($model -in @('aligned','different')) {
        $script:ColorPrimary
    } else { $script:ColorSecondary }
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($script:RestartTargetLabel,$label) }

    # This gate is presentation-only; actual activation retains the existing
    # ProbeReadiness, fixed task, firmware re-read and verification in
    # Use-DefaultForNextRestart. No settings/default write is added here.
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    $canApply = ($model -eq 'different') -and
        [bool]$script:DefaultGuid -and
        ($null -ne (Get-EntryByGuid ([string]$script:DefaultGuid))) -and
        [bool]$capabilities.CanSetBootNext -and
        -not [bool]$script:BootNextPendingGuid
    if ($script:RestartUseDefaultButton -and -not $script:RestartUseDefaultButton.IsDisposed) {
        $action = $script:RestartUseDefaultButton
        $action.Text = Get-LocalizedString -Key 'BootNext.UseDefaultOnce'
        $action.AccessibleName = $action.Text
        $action.AccessibleDescription = Get-LocalizedString -Key 'BootNext.UseDefaultHint' -Values @{ Default=$default }
        if ($script:BootTypeToolTip -and $script:BootTypeToolTip.GetToolTip($action) -cne $action.AccessibleDescription) { $script:BootTypeToolTip.SetToolTip($action,$action.AccessibleDescription) }
        $action.Visible = [bool]$canApply
        $action.Enabled = [bool]$canApply
        $action.TabStop = [bool]$canApply
        $action.Cursor = if ($canApply) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
    }
    if ($script:RestartButton -and -not $script:RestartButton.IsDisposed -and $script:RestartButton.Parent) {
        # Every bound is derived from the parent's current physical width,
        # never from a second DPI conversion. This reapplies after rescaling.
        $scale = [double]$script:RestartButton.Parent.Width / 390.0
        $x = if ($canApply) { 229 } else { 16 }
        $w = if ($canApply) { 145 } else { 358 }
        $script:RestartButton.Bounds = [Drawing.Rectangle]::new(
            [int][Math]::Round($x*$scale),
            [int][Math]::Round(30*$scale),
            [Math]::Max(1,[int][Math]::Round($w*$scale)),
            [Math]::Max(1,[int][Math]::Round(31*$scale)))
    }
    Update-BootNextRestartInterlock
}

function Restart-Windows {
    if ($script:BootNextPendingGuid) { return }
    if ($script:DefaultTargetChangePending) { return }
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if (-not $capabilities.CanRestart) { return }
    # A cached SelectedGuid must never be the sole evidence in a restart dialog.
    try { [void](Refresh-EffectiveNextBootState) }
    catch {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'BootNext.Unknown') -Message (Get-LocalizedString -Key 'BootNext.CheckFailed') -Kind Error
        return
    }
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
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Restart.FailedTitle') -Heading (Get-LocalizedString -Key 'Restart.FailedHeading') -Message (Get-LocalizedString -Key 'Restart.FailedMessage') -Kind Error
    }
}

# @include src/Infrastructure/TaskBroker.ps1
# @include src/Application/SystemCapabilities.ps1

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
        $script:SystemStatusDriftFailed = $false
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
        $script:SystemStatusDriftFailed = $true
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness:(-not $Fast)
    $state = [string]$capabilities.State

    if ($script:TaskBrokerSetupMenuItem) {
        $script:TaskBrokerSetupMenuItem.Enabled = [bool]$capabilities.CanConfigureSystemFunctions
        if ($state -eq 'Busy') {
            $mode = [string]$capabilities.MaintenanceMode
            $script:TaskBrokerSetupMenuItem.Text = if ($mode -eq 'Remove') { Get-LocalizedString -Key 'Maintenance.Menu.Generic' } elseif ($mode -eq 'Reinitialize') { Get-LocalizedString -Key 'Maintenance.Menu.Reinitializing' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { Get-LocalizedString -Key 'Maintenance.Menu.Repairing' } else { Get-LocalizedString -Key 'Maintenance.Menu.SettingUp' }
        }
        elseif ($state -eq 'ReinitializeRequired') {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Reinitialize'
        }
        elseif ($state -eq 'SetupRequired') {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Setup'
        }
        else {
            $script:TaskBrokerSetupMenuItem.Text = Get-LocalizedString -Key 'Maintenance.Menu.Repair'
        }
    }

    if ($script:TaskBrokerRemoveMenuItem) {
        # Cleanup is intentionally available even when metadata is already gone;
        # it also knows historical/probe task names from pre-TaskBroker builds.
        $script:TaskBrokerRemoveMenuItem.Enabled = [bool]$capabilities.CanRemoveSystemFunctions
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = [bool]$capabilities.CanUseDefaultTarget }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = [bool]$capabilities.CanRestart }
    Update-MaintenanceUi
    return [bool]$capabilities.IsReady
}

function Enter-SystemFunctionsMaintenance {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    [void](Set-MaintenanceRuntimeActive -State $script:MaintenanceState -Mode $Mode)
    $script:IsManageEntriesMode = $false
    $script:ManageUndoHistory = $null
    $script:ManageUndoInventory = @()
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
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsInstalled'
        try {
            Refresh-BootState -RefreshStorage
            [void](Refresh-SystemDefaultState)
            Complete-LegacyDefaultMigration
        } catch {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SetupCompleteRefreshing'
        }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsNotInstalled'
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
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SetupIncompleteTitle') -Heading (Get-LocalizedString -Key 'Maintenance.SetupIncompleteHeading') -Message (Get-LocalizedString -Key 'Maintenance.SetupIncompleteMessage') -Kind Error
    }
}

function Start-TaskBrokerInstall {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize')][string]$Mode = 'Setup')
    if ($script:DefaultTargetChangePending -or $script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerInstallDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_STARTED' -Stage 'maintenance' -Success $true -Data (New-RuntimeDiagnosticData @{ mode = $Mode })
    if (-not (Test-Path -LiteralPath $script:TaskBrokerInstallScript)) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.FileMissingTitle') -Heading (Get-LocalizedString -Key 'Maintenance.FileMissingHeading') -Message (Get-LocalizedString -Key 'Maintenance.FileMissingMessage') -Kind Error
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
        $script:LastStatusText = if ($cancelled) { Get-LocalizedString -Key 'Maintenance.SetupCancelledStatus' } else { Get-LocalizedString -Key 'Maintenance.SetupStartFailedStatus' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_SETUP_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ mode = $Mode }) -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.SetupNotStartedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.ConfirmationFailedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if ([string]$capabilities.State -eq 'Busy') { return }
    $mode = if ([string]$capabilities.State -eq 'ReinitializeRequired') {
        'Reinitialize'
    }
    elseif ([string]$capabilities.State -eq 'Ready') {
        'Repair'
    }
    elseif ([string]$capabilities.State -eq 'SetupRequired') {
        'Setup'
    }
    elseif ($capabilities.InstallationPresent) {
        'Migrate'
    }
    else {
        'Repair'
    }
    $choice = Show-LenovoSystemFunctionsDialog -Mode $mode
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) { Start-TaskBrokerInstall -Mode $mode }
}

function Prompt-TaskBrokerReinitialize {
    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ([string]$capabilities.State -ne 'ReinitializeRequired') { return }
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
    $script:SystemStatusManagerObservedUtc = $null
    $script:SystemStatusManagerObservedHash = $null
    $script:SystemStatusEntriesObservedUtc = $null
    $script:SystemStatusEntriesObservedHash = $null
    $script:SystemStatusReadinessObservedUtc = $null
    $script:SystemStatusNextObservedUtc = $null
    $script:SystemStatusDefaultObservedUtc = $null
    $script:SystemStatusDefaultEvidence = 'unknown'
    $script:SystemStatusLastRefresh = 'unknown'
    $script:TaskBrokerMetadata = $null
    $script:ManagerCacheText = $null
    $script:FirmwareCacheText = $null
    $script:DefaultGuid = $null
    $script:IsManageEntriesMode = $false
    $script:ManageUndoHistory = $null
    $script:ManageUndoInventory = @()
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
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRemoved'
    }
    else {
        Reset-TaskBrokerReadyCache
        $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRemoveIncomplete'
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
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteTitle') -Heading (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteHeading') -Message (Get-LocalizedString -Key 'Maintenance.RemoveIncompleteMessage') -Kind Error
    }
}

function Start-TaskBrokerRemove {
    if ($script:DefaultTargetChangePending -or $script:TaskBrokerInstallInProgress -or $script:TaskBrokerRemoveInProgress -or (Test-MaintenanceBusy)) { return }
    $script:TaskBrokerRemoveDiagnosticStartedUtc = [datetime]::UtcNow
    Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_STARTED' -Stage 'maintenance' -Success $true
    if (-not (Test-Path -LiteralPath $script:TaskBrokerUninstallScript)) {
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveNotPossibleTitle') -Heading (Get-LocalizedString -Key 'Maintenance.FileMissingHeading') -Message (Get-LocalizedString -Key 'Maintenance.FileMissingMessage') -Kind Error
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
        $script:LastStatusText = if ($cancelled) { Get-LocalizedString -Key 'Maintenance.RemoveCancelledStatus' } else { Get-LocalizedString -Key 'Maintenance.RemoveFailedStatus' }
        Write-RuntimeDiagnosticEvent -Event 'SYSTEM_FUNCTIONS_REMOVE_LAUNCH' -Stage 'maintenance' -Success $false -ErrorRecord $_ -Level $(if ($cancelled) { 'warning' } else { 'error' })
        Exit-SystemFunctionsMaintenance -Reason $(if ($cancelled) { 'cancelled' } else { 'launch-failed' })
        if (-not $cancelled) {
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Maintenance.RemoveNotStartedTitle') -Heading (Get-LocalizedString -Key 'Maintenance.ConfirmationFailedHeading') -Message (Get-LocalizedString -Key 'Common.TryAgain') -Kind Error
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

# @include src/Core/StorageResolution.ps1
# @include src/Infrastructure/Storage.ps1

# @include src/Core/BootTargetModel.ps1

function Get-FriendlyBootEntry {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext
    )

    $model = Get-FriendlyBootEntryCore -Guid $Guid -RawDescription $RawDescription -StorageContext $StorageContext -Locale (Get-ActiveLocale)
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
        # Keep the exact original raw input (including empty descriptions)
        # and associated storage snapshot for presentation-only relocalization.
        LocalizationRawDescription = [string]$RawDescription
        LocalizationStorageContext = $StorageContext
    }
}


# @include src/Core/FirmwareParsing.ps1
# @include src/Core/BootTargetDrift.ps1

# @include src/Application/BootService.ps1
# @include src/Infrastructure/BackgroundRefreshWorker.ps1
# @include src/Infrastructure/BootNextSelectionWorker.ps1
# @include src/Infrastructure/DefaultTargetChangeWorker.ps1
# @include src/Application/RefreshRuntime.ps1
# @include src/Application/BootNextSelectionController.ps1
# @include src/Application/DefaultTargetChangeController.ps1
# @include src/Application/RefreshController.ps1

$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState


function Get-FirmwareBootState {
    param(
        [switch]$RefreshStorage,
        [switch]$UseExistingCache,
        [switch]$ForceManagerRefresh
    )

    $snapshot = Get-BootServiceFirmwareSnapshot -UseExistingCache:$UseExistingCache -ForceManagerRefresh:$ForceManagerRefresh
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
        $raw = if ($descriptions.ContainsKey($guid)) { [string]$descriptions[$guid] } else { '' }
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
    $capabilities = Get-CurrentSystemFunctionsCapabilities -ProbeReadiness
    if (-not $capabilities.CanSetBootNext) { throw 'Das Startziel ist derzeit nicht verfügbar.' }
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

# @include src/UI/PopupDpiLayout.ps1
# @include src/UI/BootEntryRows.ps1
# @include src/UI/BootEntryList.ps1


function Apply-FirmwareBootState {
    param([Parameter(Mandatory=$true)]$State, [switch]$VerifiedFresh)
    if ($script:BootNextPendingGuid) {
        Write-RuntimeDiagnosticEvent -Event 'BACKGROUND_REFRESH_RESULT_DEFERRED_FOR_BOOTNEXT' -Stage 'bootnext' -Success $true
        return
    }

    $script:CurrentEntries = @($State.Entries)
    $script:SelectedGuid = if ($State.SelectedGuid) { $State.SelectedGuid.ToLowerInvariant() } else { $null }
    $script:NextBootFirmwareReadVerified = [bool]$VerifiedFresh
    $script:SystemStatusNextObservedUtc = if ($VerifiedFresh) { $script:SystemStatusManagerObservedUtc } else { $null }

    if ($script:SelectedGuid) {
        $selected = Get-EntryByGuid $script:SelectedGuid
        $script:LastStatusText = if ($selected) { Get-LocalizedString -Key 'Status.NextBootTarget' -Values @{ Title=(Get-EntryDisplayTitle -Entry $selected) } } else { Get-LocalizedString -Key 'Status.OneTimeNextBootSet' }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.NoOneTimeNextBoot'
    }

    $capabilities = Get-CurrentSystemFunctionsCapabilities
    if ($capabilities.CanUseCachedBootState) { [void](Refresh-SystemDefaultState) }
    if ($null -ne $script:ManageUndoHistory) { Update-ManageUndoInventory }
    Update-PopupRows -Reason 'firmware-state'
}

function Refresh-BootState {
    param([switch]$RefreshStorage)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($RefreshStorage) {
        $script:ManagerCacheText = $null
        $script:FirmwareCacheText = $null
    }
    try {
        $state = Get-FirmwareBootState -RefreshStorage:$RefreshStorage -ForceManagerRefresh
        [void](Update-BootTargetDriftState)
        Apply-FirmwareBootState -State $state -VerifiedFresh
        $script:SystemStatusLastRefresh = 'success'
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage; entryCount = @($state.Entries).Count; selectedGuid = $state.SelectedGuid })
    }
    catch {
        $script:NextBootFirmwareReadVerified = $false
        $script:SystemStatusLastRefresh = 'error'
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'BOOT_STATE_REFRESH' -Stage 'boot-state' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ refreshStorage = [bool]$RefreshStorage }) -Level error
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsReadFailed'
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

# @include src/UI/PopupComposition.ps1
# @include src/Core/SystemStatus.ps1
# @include src/UI/SystemStatusPresentation.ps1
# @include src/UI/PopupPosition.ps1
# @include src/UI/Popup.ps1

Initialize-RuntimeDiagnostics
if (-not ($BootNextWorker -or $BackgroundRefresh -or $UpdateCheck -or $UpdatePrepare -or $DefaultTargetWorker)) {
    try { [void](Get-DiagnosticsInstallationId -SettingsDirectory $script:SettingsDir) }
    catch { Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_INSTALLATION_ID_UNAVAILABLE' -Stage 'startup' -Success $false -ErrorRecord $_ -Level warning }
}
if (-not $BackgroundRefresh) {
    if ($singleInstanceMutexState -eq 'abandoned-recovered') {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs }) -Level warning
    }
    elseif ($mutexOwned) {
        Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_MUTEX_ACQUIRED' -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{ state = $singleInstanceMutexState; graceMs = $singleInstanceGraceMs })
    }
}

if ($BootNextWorker) {
    $exitCode = Invoke-BootNextSelectionWorker -Guid $BootNextGuid -ResultPath $BootNextResultPath
    exit $exitCode
}
if ($DefaultTargetWorker) {
    $exitCode = Invoke-DefaultTargetWorker -Guid $DefaultTargetGuid -Clear ([bool]$DefaultTargetClear) -ResultPath $DefaultTargetResultPath -ProgressPath $DefaultTargetProgressPath
    exit $exitCode
}
if ($BackgroundRefresh) {
    $exitCode = Invoke-BackgroundRefreshWorker -RefreshStorage ([bool]$BackgroundRefreshStorage) -RefreshFirmware ([bool]$BackgroundRefreshFirmware) -ResultPath $BackgroundResultPath
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
    # Establish the DPI context before constructing the first WinForms HWND.
    $uiDpi = Initialize-LenovoUiDpiAwareness
    Write-RuntimeDiagnosticEvent -Event 'UI_DPI_AWARENESS_INITIALIZED' -Stage 'ui-layout' -Success ([bool]$uiDpi.Success) -Data (New-RuntimeDiagnosticData @{
        awareness = [string]$uiDpi.Awareness
    }) -Level $(if ($uiDpi.Success) { 'info' } else { 'warning' })
    Write-RuntimeDiagnosticEvent -Event 'TRAY_STARTUP' -Stage 'startup' -Success $true
    Load-AppSettings
    [void](Resolve-PendingLocalePreference)
    $script:LastStatusText = Get-LocalizedString -Key 'Status.Ready'
    Repair-AutostartLauncherIfNeeded

    $initialPopupScale = Get-LenovoUiCoordinateScale -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
    $script:Popup = New-PopupForm -TargetScale ([double]$initialPopupScale.Factor) -ScaleSource ([string]$initialPopupScale.Source)
    # The pre-handle Screen.WorkingArea can be DPI-virtualized at 250%.
    # Capture both sides to distinguish DPI initialization from menu geometry.
    $preHandleWork = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    Initialize-LenovoTrayDpiContext -Popup $script:Popup
    $postHandleWork = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    Write-RuntimeDiagnosticEvent -Event 'TRAY_DPI_CONTEXT_INITIALIZED' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData @{
        preHandleWorkWidth = [int]$preHandleWork.Width
        preHandleWorkHeight = [int]$preHandleWork.Height
        postHandleWorkWidth = [int]$postHandleWork.Width
        postHandleWorkHeight = [int]$postHandleWork.Height
        popupHandleCreated = [bool]$script:Popup.IsHandleCreated
        popupVisible = [bool]$script:Popup.Visible
    })
    Write-LenovoMonitorTopologyEvent -Phase 'startup' -Screen ([System.Windows.Forms.Screen]::PrimaryScreen)
    $activationListener = Start-LbsActivationListener -Signal $activationEvent -OnActivate {
        try {
            Show-OrActivatePopup
            Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_ACTIVATED' -Stage 'ui' -Success $true
        }
        catch {
            Write-RuntimeDiagnosticEvent -Event 'SINGLE_INSTANCE_ACTIVATION_FAILED' -Stage 'ui' -Success $false -ErrorRecord $_ -Level warning
        }
    }
    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayIcon.Icon = Load-TrayIcon
    $script:TrayIcon.Text = 'Lenovo Boot Selector'
    $script:TrayIcon.Visible = $true

    $context = New-Object LenovoContextMenuStrip
    $context.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $context.ForeColor = $script:ColorPrimary
    $context.Renderer = $script:MenuRenderer
    $context.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $context.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $context.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $context

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $openItem.Text = Get-LocalizedString -Key 'Tray.Open'
    $script:TrayOpenMenuItem = $openItem
    $openItem.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Bold)
    $openItem.ForeColor = [Drawing.Color]::FromArgb(255,110,102)
    $openItem.Add_Click({ Show-OrTogglePopup -FromTrayClick })
    [void]$context.Items.Add($openItem)

    # v0.2.32: Refresh and Standard-Startziel remain in the main popup only.
    # The tray menu is intentionally reduced to quick actions and maintenance.
    $autostartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $autostartItem.Text = Get-LocalizedString -Key 'Settings.Autostart'
    $autostartItem.Add_Click({
        $desired = -not (Get-AutostartInfo).Enabled
        Set-AutostartFromUi -Enabled:$desired
    })
    $script:AutostartMenuItem = $autostartItem
    [void]$context.Items.Add($autostartItem)

    $languageRoot = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageRoot.Text = Get-LocalizedString -Key 'Settings.Language'
    $languageRoot.DropDown = New-Object LenovoDropDownMenu
    $languageRoot.DropDown.TargetWidth = 220
    $languageRoot.DropDown.Name = 'LenovoLanguageDropDown'
    Initialize-LenovoMenuAppearance -Menu $languageRoot.DropDown
    $languageRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })
    $script:LanguageMenuRoot = $languageRoot

    $languageEnglish = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageEnglish.Name = 'LocaleFlag.en-US'
    $languageEnglish.Text = Get-LocalizedString -Key 'Language.English'
    $languageEnglish.Padding = New-Object System.Windows.Forms.Padding(38, 4, 32, 4)
    $languageEnglish.Add_Click({ [void](Set-LanguageFromUi -Locale 'en-US') })
    $script:LanguageEnglishMenuItem = $languageEnglish
    [void]$languageRoot.DropDownItems.Add($languageEnglish)

    $languageGerman = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageGerman.Name = 'LocaleFlag.de-DE'
    $languageGerman.Text = Get-LocalizedString -Key 'Language.German'
    $languageGerman.Padding = New-Object System.Windows.Forms.Padding(38, 4, 32, 4)
    $languageGerman.Add_Click({ [void](Set-LanguageFromUi -Locale 'de-DE') })
    $script:LanguageGermanMenuItem = $languageGerman
    [void]$languageRoot.DropDownItems.Add($languageGerman)

    Update-LanguageMenuState
    [void]$context.Items.Add($languageRoot)

    $preferencesRoot = New-Object Windows.Forms.ToolStripMenuItem
    $preferencesRoot.Text = Get-LocalizedString -Key 'Preferences.Menu'
    $preferencesRoot.DropDown = New-Object LenovoDropDownMenu
    $preferencesRoot.DropDown.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $preferencesRoot.DropDown
    $preferencesRoot.Add_DropDownOpening({
        Initialize-LenovoMenuAppearance -Menu $this.DropDown
        Update-PortablePreferencesMenuState
    })
    $script:PreferencesMenuRoot = $preferencesRoot
    $exportItem = New-Object Windows.Forms.ToolStripMenuItem
    $exportItem.Text = Get-LocalizedString -Key 'Preferences.Export'
    $exportItem.Padding = New-LenovoSubmenuActionPadding
    $exportItem.Add_Click({ Show-PortablePreferencesFromUi -Mode Export })
    $script:PreferencesExportMenuItem = $exportItem
    [void]$preferencesRoot.DropDownItems.Add($exportItem)
    $importItem = New-Object Windows.Forms.ToolStripMenuItem
    $importItem.Text = Get-LocalizedString -Key 'Preferences.Import'
    $importItem.Padding = New-LenovoSubmenuActionPadding
    $importItem.Add_Click({ Show-PortablePreferencesFromUi -Mode Import })
    $script:PreferencesImportMenuItem = $importItem
    [void]$preferencesRoot.DropDownItems.Add($importItem)
    [void]$context.Items.Add($preferencesRoot)

    $script:DefaultContextRoot = $null
    $script:ManageEntriesMenuItem = $null

    $maintenanceRoot = New-Object System.Windows.Forms.ToolStripMenuItem
    $maintenanceRoot.Text = Get-LocalizedString -Key 'Tray.Maintenance'
    $script:MaintenanceRootMenuItem = $maintenanceRoot
    $maintenanceRoot.DropDown = New-Object LenovoDropDownMenu
    $maintenanceRoot.DropDown.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $maintenanceRoot.DropDown
    $maintenanceRoot.Add_DropDownOpening({ Initialize-LenovoMenuAppearance -Menu $this.DropDown })

    $setupItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $setupItem.Text = Get-LocalizedString -Key 'Maintenance.Setup'
    $setupItem.Padding = New-LenovoSubmenuActionPadding
    $setupItem.Add_Click({ Prompt-TaskBrokerInstall })
    $script:TaskBrokerSetupMenuItem = $setupItem
    [void]$maintenanceRoot.DropDownItems.Add($setupItem)

    $removeTasksItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $removeTasksItem.Text = Get-LocalizedString -Key 'Maintenance.Remove'
    $removeTasksItem.Padding = New-LenovoSubmenuActionPadding
    $removeTasksItem.Add_Click({ Prompt-TaskBrokerRemove })
    $script:TaskBrokerRemoveMenuItem = $removeTasksItem
    [void]$maintenanceRoot.DropDownItems.Add($removeTasksItem)

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $updateCheckItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateCheckItem.Text = Get-LocalizedString -Key 'Update.Check'
    $updateCheckItem.Padding = New-LenovoSubmenuActionPadding
    $updateCheckItem.Add_Click({ Start-ManualUpdateCheck })
    $script:UpdateCheckMenuItem = $updateCheckItem
    [void]$maintenanceRoot.DropDownItems.Add($updateCheckItem)

    $updateInstallItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $updateInstallItem.Text = Get-LocalizedString -Key 'Update.Install'
    $updateInstallItem.Padding = New-LenovoSubmenuActionPadding
    $updateInstallItem.Enabled = $false
    $updateInstallItem.Add_Click({ Start-ManualAppUpdate })
    $script:UpdateInstallMenuItem = $updateInstallItem
    [void]$maintenanceRoot.DropDownItems.Add($updateInstallItem)
    Update-UpdateMenuState

    [void]$maintenanceRoot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $diagnosticItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagnosticItem.Text = Get-LocalizedString -Key 'Diagnostics.Save'
    $diagnosticItem.Padding = New-LenovoSubmenuActionPadding
    $diagnosticItem.Add_Click({ Save-RuntimeDiagnosticsFromUi })
    $script:RuntimeDiagnosticMenuItem = $diagnosticItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)

    $diagnosticUploadItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $diagnosticUploadItem.Text = Get-LocalizedString -Key 'Diagnostics.Upload'
    $diagnosticUploadItem.Padding = New-LenovoSubmenuActionPadding
    $diagnosticUploadItem.Add_Click({ Start-DiagnosticsUploadFromUi })
    $script:DiagnosticsUploadMenuItem = $diagnosticUploadItem
    [void]$maintenanceRoot.DropDownItems.Add($diagnosticUploadItem)

    [void]$context.Items.Add($maintenanceRoot)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $restartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $restartItem.Text = Get-LocalizedString -Key 'Action.RestartWindows'
    $restartItem.Add_Click({ Restart-Windows })
    $script:RestartMenuItem = $restartItem
    [void]$context.Items.Add($restartItem)

    [void]$context.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = Get-LocalizedString -Key 'Tray.Exit'
    $script:TrayExitMenuItem = $exitItem
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

    # Shell-owned auto-placement jumped to a different monitor in mixed DPI.
    $script:TrayContextMenu = $context
    $script:TrayIcon.ContextMenuStrip = $null
    [void](Show-PendingUpdateResultOnStartup)
    $script:TrayPopupClickUtc = $null
    $script:TrayPopupClickPoint = [Drawing.Point]::Empty
    $script:TrayIcon.Add_MouseClick({
        param($sender, $eventArgs)
        if ($script:PreferencesUiActive) {
            # The native chooser owns focus while no app-owned confirmation is
            # active. Never activate the disabled window beneath it.
            if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Right -and
                $script:ActiveOwnedDialog -and -not $script:ActiveOwnedDialog.IsDisposed) {
                [LenovoSettingsWindowInput]::ActivateInitialSurface($script:ActiveOwnedDialog)
            }
            return
        }
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -or
            $eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            # Capture only genuine tray-icon clicks; never borrow arbitrary cursor state.
            $script:TrayPopupClickPoint = [System.Windows.Forms.Cursor]::Position
            $script:TrayPopupClickUtc = [DateTime]::UtcNow
        }
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-OrTogglePopup -FromTrayClick
        }
        elseif ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            if (Test-ActivateTrayModalSurface) { return }
            if ($script:Popup -and $script:Popup.Visible) { $script:Popup.Hide() }
            $point = $script:TrayPopupClickPoint
            $screen = [System.Windows.Forms.Screen]::FromPoint($point)
            if ($script:TrayContextMenu -and $screen) {
                Write-LenovoMonitorTopologyEvent -Phase 'tray-click' -Screen $screen
                Initialize-LenovoMenuAppearance -Menu $script:TrayContextMenu
                $factor = (Get-LenovoUiCoordinateScale -Screen $screen).Factor
                [void](Set-LenovoMenuDpiLayout -Menu $script:TrayContextMenu -Scale ([double]$factor))
                $size = $script:TrayContextMenu.GetPreferredSize([Drawing.Size]::Empty)
                $location = Get-TrayContextMenuLocation -ClickPoint $point -MenuSize $size -WorkingArea $screen.WorkingArea -DisplayBounds $screen.Bounds
                Write-LenovoDpiWindowEvent -Control $script:TrayContextMenu -Role 'tray-root' -Phase 'before-show-call' -Screen $screen -RequestedScale ([double]$factor)
                $script:TrayContextMenu.Show($location)
                Write-LenovoDpiWindowEvent -Control $script:TrayContextMenu -Role 'tray-root' -Phase 'after-show-call' -Screen $screen -RequestedScale ([double]$factor)
                Write-RuntimeDiagnosticEvent -Event 'TRAY_CONTEXT_MENU_LOCATION' -Stage 'ui-layout' -Success $true -Data (New-RuntimeDiagnosticData @{
                    menuWidth = [int]$size.Width
                    menuHeight = [int]$size.Height
                    screenWorkWidth = [int]$screen.WorkingArea.Width
                    screenWorkHeight = [int]$screen.WorkingArea.Height
                    menuShownOnClickMonitor = [bool]($screen.Bounds.Contains($location))
                })
            }
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
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsRepairRequired'
        }
        else {
            $script:LastStatusText = Get-LocalizedString -Key 'Status.SystemFunctionsSetupRequired'
        }
    }
    else {
        $script:LastStatusText = Get-LocalizedString -Key 'Status.BootTargetsRefreshing'
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
            Start-BackgroundBootRefresh -RefreshStorage -Origin Startup
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
        try { Stop-UpdateCheckWorkflow -State $script:UpdateState } catch { }
        try { Stop-UpdatePrepareWorkflow -State $script:UpdateState } catch { }
    }
    Stop-BootNextSelectionWorker -Reason 'shutdown'
    Stop-DefaultTargetChangeWorker -Reason 'shutdown'
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
    if ($backgroundRefreshContext -and $backgroundRefreshContext.Process) {
        try { $backgroundRefreshContext.Process.Refresh() } catch { }
        try { if (-not $backgroundRefreshContext.Process.HasExited) { $backgroundRefreshContext.Process.Kill() } } catch { }
        try { $backgroundRefreshContext.Process.Dispose() } catch { }
    }
    if ($backgroundRefreshContext) {
        Remove-BackgroundRefreshResultFile -Path ([string]$backgroundRefreshContext.ResultPath)
    }
    if ($script:DiagnosticsUploadTimer) {
        try { $script:DiagnosticsUploadTimer.Stop(); $script:DiagnosticsUploadTimer.Dispose() } catch { }
        $script:DiagnosticsUploadTimer = $null
    }
    if ($script:DiagnosticsUploadState) {
        try { $script:DiagnosticsUploadState.Client.CancelPendingRequests() } catch { }
        Dispose-DiagnosticsUploadTransport -Context $script:DiagnosticsUploadState
        $script:DiagnosticsUploadState = $null
    }
    if ($script:TrayIcon) {
        $script:TrayIcon.Visible = $false
        $script:TrayIcon.Dispose()
    }
    if ($activationListener) {
        try { Stop-LbsActivationListener -Listener $activationListener } catch { }
        $activationListener = $null
    }
    if ($activationEvent) {
        try { $activationEvent.Dispose() } catch { }
        $activationEvent = $null
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
