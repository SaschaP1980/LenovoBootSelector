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

function Show-FatalMessage([string]$Message, [bool]$AllowRestart = $true) {
    $diagnosticSaved = $false
    $diagDir = $null
    $diagPath = $null
    try {
        $diagDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
        if (-not (Test-Path -LiteralPath $diagDir)) { [void](New-Item -ItemType Directory -Path $diagDir -Force) }
        $diagPath = Join-Path $diagDir ("RuntimeError-{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        $diagText = "Lenovo Boot Selector runtime error`r`nTime: $([datetime]::Now.ToString('o'))`r`n`r`n$Message"
        [System.IO.File]::WriteAllText($diagPath, $diagText, [System.Text.Encoding]::UTF8)
        $diagnosticSaved = $true
    } catch { }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $isAlreadyRunning = ($Message -eq 'Lenovo Boot Selector läuft bereits.')
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Lenovo Boot Selector'
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.ShowInTaskbar = $false
        $form.ShowIcon = $true
        $form.TopMost = $true
        $form.ClientSize = New-Object System.Drawing.Size(560, 242)
        $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
        $form.ForeColor = [System.Drawing.Color]::FromArgb(238, 238, 238)
        $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
        $form.Tag = 'close'

        $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
        if (Test-Path -LiteralPath $iconPath) {
            try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch { }
        }

        $accent = New-Object System.Windows.Forms.Panel
        $accent.Location = New-Object System.Drawing.Point(0, 0)
        $accent.Size = New-Object System.Drawing.Size(5, 242)
        $accent.BackColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $form.Controls.Add($accent)

        $badge = New-Object System.Windows.Forms.Label
        $badge.Text = '!'
        $badge.Location = New-Object System.Drawing.Point(24, 28)
        $badge.Size = New-Object System.Drawing.Size(38, 38)
        $badge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $badge.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18.0, [System.Drawing.FontStyle]::Bold)
        $badge.ForeColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $badge.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $form.Controls.Add($badge)

        $title = New-Object System.Windows.Forms.Label
        $title.Location = New-Object System.Drawing.Point(78, 24)
        $title.Size = New-Object System.Drawing.Size(452, 28)
        $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11.0, [System.Drawing.FontStyle]::Bold)
        $title.ForeColor = [System.Drawing.Color]::White
        $title.Text = $(if ($isAlreadyRunning) { 'Lenovo Boot Selector läuft bereits' } else { 'Lenovo Boot Selector konnte nicht gestartet werden' })
        $form.Controls.Add($title)

        $body = New-Object System.Windows.Forms.Label
        $body.Location = New-Object System.Drawing.Point(78, 60)
        $body.Size = New-Object System.Drawing.Size(452, 70)
        $body.Font = New-Object System.Drawing.Font('Segoe UI', 9.0, [System.Drawing.FontStyle]::Regular)
        $body.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
        if ($isAlreadyRunning) {
            $body.Text = 'Die App ist bereits geöffnet. Schließe dieses Fenster und verwende das vorhandene Tray-Symbol.'
        }
        elseif ($diagnosticSaved) {
            $body.Text = "Beim Start ist ein Problem aufgetreten.`r`nEine Diagnose wurde gespeichert. Du kannst die App erneut starten oder die Diagnose öffnen."
        }
        else {
            $body.Text = "Beim Start ist ein Problem aufgetreten.`r`nDie Diagnose konnte nicht gespeichert werden. Du kannst die App erneut starten."
        }
        $form.Controls.Add($body)

        $diagLabel = New-Object System.Windows.Forms.Label
        $diagLabel.Location = New-Object System.Drawing.Point(78, 136)
        $diagLabel.Size = New-Object System.Drawing.Size(452, 24)
        $diagLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8.0, [System.Drawing.FontStyle]::Regular)
        $diagLabel.ForeColor = [System.Drawing.Color]::FromArgb(145, 145, 145)
        if ($diagnosticSaved -and $diagPath) {
            $diagLabel.Text = ('Diagnose: {0}' -f (Split-Path -Leaf $diagPath))
        }
        elseif (-not $isAlreadyRunning) {
            $diagLabel.Text = 'Keine Diagnose-Datei verfügbar.'
        }
        $form.Controls.Add($diagLabel)

        $buttonBar = New-Object System.Windows.Forms.Panel
        $buttonBar.Location = New-Object System.Drawing.Point(5, 178)
        $buttonBar.Size = New-Object System.Drawing.Size(555, 64)
        $buttonBar.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 31)
        $form.Controls.Add($buttonBar)

        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = 'Schließen'
        $closeButton.Location = New-Object System.Drawing.Point(433, 16)
        $closeButton.Size = New-Object System.Drawing.Size(100, 32)
        $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $closeButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $closeButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $closeButton.ForeColor = [System.Drawing.Color]::White
        $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $closeButton.Add_Click({ $form.Tag = 'close'; $form.Close() })
        $buttonBar.Controls.Add($closeButton)
        $form.CancelButton = $closeButton

        $diagnosticButton = New-Object System.Windows.Forms.Button
        $diagnosticButton.Text = 'Diagnose öffnen'
        $diagnosticButton.Location = New-Object System.Drawing.Point(279, 16)
        $diagnosticButton.Size = New-Object System.Drawing.Size(142, 32)
        $diagnosticButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $diagnosticButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $diagnosticButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $diagnosticButton.ForeColor = [System.Drawing.Color]::White
        $diagnosticButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $diagnosticButton.Enabled = [bool]($diagnosticSaved -and $diagDir)
        $diagnosticButton.Add_Click({
            try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $diagDir) | Out-Null } catch { }
        })
        $buttonBar.Controls.Add($diagnosticButton)

        $retryButton = New-Object System.Windows.Forms.Button
        $retryButton.Text = 'Erneut starten'
        $retryButton.Location = New-Object System.Drawing.Point(125, 16)
        $retryButton.Size = New-Object System.Drawing.Size(142, 32)
        $retryButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $retryButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $retryButton.BackColor = [System.Drawing.Color]::FromArgb(64, 31, 29)
        $retryButton.ForeColor = [System.Drawing.Color]::White
        $retryButton.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.0, [System.Drawing.FontStyle]::Bold)
        $launcherAvailable = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
        $retryButton.Enabled = [bool]($AllowRestart -and -not $isAlreadyRunning -and $launcherAvailable)
        $retryButton.Add_Click({ $form.Tag = 'retry'; $form.Close() })
        $buttonBar.Controls.Add($retryButton)

        if ($retryButton.Enabled) { $form.AcceptButton = $retryButton } else { $form.AcceptButton = $closeButton }
        [void]$form.ShowDialog()
        $action = [string]$form.Tag
        $form.Dispose()
        return $action
    }
    catch {
        # Fallback remains owner-bound and taskbar-silent. If WinForms itself is
        # unavailable, fall back to stderr without creating a visible console.
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $owner = New-Object System.Windows.Forms.Form
            $owner.ShowInTaskbar = $false
            $owner.Opacity = 0
            $owner.Size = New-Object System.Drawing.Size(1, 1)
            $owner.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $owner.Location = New-Object System.Drawing.Point(-32000, -32000)
            $owner.Show()
            [System.Windows.Forms.MessageBox]::Show(
                $owner,
                'Lenovo Boot Selector konnte nicht gestartet werden.',
                'Lenovo Boot Selector',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            $owner.Close()
            $owner.Dispose()
        }
        catch {
            Write-Error $Message
        }
        return 'close'
    }
}


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

$script:AppVersion = '0.5.10.3'
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

function New-MaintenanceRuntimeState {
    [pscustomobject]@{
        Busy = $false
        Mode = ''
        StartedUtc = $null
    }
}

function Set-MaintenanceRuntimeActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    $State.Busy = $true
    $State.Mode = $Mode
    $State.StartedUtc = $NowUtc
    return $State
}

function Clear-MaintenanceRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Busy = $false
    $State.Mode = ''
    $State.StartedUtc = $null
    return $State
}

function Test-MaintenanceRuntimeBusy {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Busy)
}

function Get-MaintenanceRuntimeMode {
    param([AllowNull()]$State)
    if (-not $State -or -not $State.Busy) { return '' }
    return [string]$State.Mode
}

# Lenovo Boot Selector v0.5.0 - Application state for read-only firmware-target drift.
# No UI, IO, Scheduled Tasks or global script state.

function New-BootTargetDriftRuntimeState {
    [pscustomobject]@{
        Evaluated = $false
        HasDrift = $false
        HasNewTargets = $false
        AddedGuids = @()
        RemovedGuids = @()
        CurrentGuids = @()
        InstalledGuids = @()
        CheckedUtc = $null
        NotificationShown = $false
    }
}

function Set-BootTargetDriftRuntimeState {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Drift,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $oldFingerprint = ((@($State.AddedGuids) + @('|') + @($State.RemovedGuids)) -join ',')
    $newFingerprint = ((@($Drift.AddedGuids) + @('|') + @($Drift.RemovedGuids)) -join ',')
    if (-not $State.Evaluated -or $oldFingerprint -ne $newFingerprint) {
        $State.NotificationShown = $false
    }

    $State.Evaluated = $true
    $State.HasDrift = [bool]$Drift.HasDrift
    $State.HasNewTargets = [bool]$Drift.HasNewTargets
    $State.AddedGuids = @($Drift.AddedGuids)
    $State.RemovedGuids = @($Drift.RemovedGuids)
    $State.CurrentGuids = @($Drift.CurrentGuids)
    $State.InstalledGuids = @($Drift.InstalledGuids)
    $State.CheckedUtc = $NowUtc
    if (-not $State.HasDrift) { $State.NotificationShown = $false }
    return $State
}

function Clear-BootTargetDriftRuntimeState {
    param([Parameter(Mandatory=$true)]$State)
    $State.Evaluated = $false
    $State.HasDrift = $false
    $State.HasNewTargets = $false
    $State.AddedGuids = @()
    $State.RemovedGuids = @()
    $State.CurrentGuids = @()
    $State.InstalledGuids = @()
    $State.CheckedUtc = $null
    $State.NotificationShown = $false
    return $State
}

function Test-BootTargetDriftRuntimeDetected {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift)
}

function Test-BootTargetDriftRuntimeHasNewTargets {
    param([AllowNull()]$State)
    return [bool]($State -and $State.Evaluated -and $State.HasDrift -and $State.HasNewTargets)
}

function Set-BootTargetDriftNotificationShown {
    param([Parameter(Mandatory=$true)]$State)
    $State.NotificationShown = $true
    return $State
}

function ConvertTo-LenovoVersionCore {
    param([Parameter(Mandatory=$true)][string]$Version)
    $value = ([string]$Version).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') { return $null }
    if ($value -match '^\d+\.\d+\.\d+$') { $value += '.0' }
    try { return [version]$value } catch { return $null }
}

function Compare-LenovoAppVersionCore {
    param(
        [Parameter(Mandatory=$true)][string]$Current,
        [Parameter(Mandatory=$true)][string]$Candidate
    )
    $currentVersion = ConvertTo-LenovoVersionCore -Version $Current
    $candidateVersion = ConvertTo-LenovoVersionCore -Version $Candidate
    if (-not $currentVersion -or -not $candidateVersion) { throw 'Ungültiges Versionsformat.' }
    return $candidateVersion.CompareTo($currentVersion)
}

function Resolve-LenovoUpdateRestartResultCore {
    param(
        [AllowNull()]$Result,
        [Parameter(Mandatory=$true)][string]$RunningVersion
    )

    $running = ([string]$RunningVersion).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $running)) { throw 'Ungültige laufende App-Version.' }

    $status = ''
    $sourceVersion = ''
    $targetVersion = ''
    $storedMessage = ''
    $resultUtc = ''
    $rollbackAttempted = $false
    $rollbackSucceeded = $false
    $legacySuccessProperty = $null
    if ($Result) {
        $status = ([string]$Result.status).Trim().ToLowerInvariant()
        $sourceVersion = ([string]$Result.sourceVersion).Trim()
        $targetVersion = ([string]$Result.targetVersion).Trim()
        $storedMessage = ([string]$Result.message).Trim()
        $resultUtc = [string]$Result.utc
        $rollbackAttempted = [bool]$Result.rollbackAttempted
        $rollbackSucceeded = [bool]$Result.rollbackSucceeded
        $legacySuccessProperty = $Result.PSObject.Properties['success']
    }

    # v0.5.7.2 and older updater helpers persisted { utc, success, message }.
    # Treat that shape as legacy only when status is absent and success is a real Boolean.
    # If a status exists, the v0.5.8.x status contract always wins.
    $isLegacyResult = (-not $status -and $null -ne $legacySuccessProperty -and ($legacySuccessProperty.Value -is [bool]))
    $resultFormat = $(if ($status) { 'status' } elseif ($isLegacyResult) { 'legacy-success' } else { 'unknown' })
    $legacySuccess = $null
    $success = $false
    $message = $storedMessage
    $displayVersion = $targetVersion

    if ($status -eq 'pending-verification') {
        try {
            if (-not $targetVersion) { throw 'Die erwartete Zielversion fehlt im Update-Ergebnis.' }
            $comparison = Compare-LenovoAppVersionCore -Current $running -Candidate $targetVersion
            $success = ($comparison -eq 0)
            if ($success) {
                $message = ('Lenovo Boot Selector wurde erfolgreich auf v{0} aktualisiert.' -f $targetVersion)
            }
            else {
                $message = ('Die erwartete Zielversion v{0} wurde nach dem Neustart nicht erkannt. Aktuell läuft v{1}.' -f $targetVersion,$running)
            }
        }
        catch {
            $success = $false
            $message = $_.Exception.Message
        }
    }
    elseif ($status -eq 'failed') {
        $success = $false
        if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.' }
        if ($rollbackAttempted -and $rollbackSucceeded) {
            $message = "Die Aktualisierung konnte nicht abgeschlossen werden. Die vorherige Version wurde wiederhergestellt.`r`n`r`nUrsache: $message"
        }
    }
    elseif ($isLegacyResult) {
        $legacySuccess = [bool]$legacySuccessProperty.Value
        $success = $legacySuccess
        if ($success) {
            # Legacy records carry no trustworthy targetVersion. Report only the version
            # that is demonstrably running and leave TargetVersion empty in diagnostics.
            $displayVersion = $running
            $message = ('Lenovo Boot Selector wurde erfolgreich aktualisiert. Aktuell läuft v{0}.' -f $running)
        }
        elseif ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'Die Aktualisierung konnte nicht abgeschlossen werden.'
        }
    }
    else {
        $success = $false
        $message = ('Unbekannter Update-Ergebnisstatus: {0}' -f $(if ($status) { $status } else { '<leer>' }))
    }

    return [pscustomobject][ordered]@{
        Success = $success
        Message = $message
        DisplayVersion = $displayVersion
        ResultFormat = $resultFormat
        LegacySuccess = $legacySuccess
        ResultUtc = $resultUtc
        ResultStatus = $status
        SourceVersion = $sourceVersion
        TargetVersion = $targetVersion
        RunningVersion = $running
        RollbackAttempted = $rollbackAttempted
        RollbackSucceeded = $rollbackSucceeded
        StoredMessage = $storedMessage
    }
}

function Test-LenovoUpdateManifestCore {
    param([AllowNull()]$Manifest)

    $result = [ordered]@{
        IsValid = $false
        Error = ''
        SchemaVersion = 1
        Version = ''
        File = ''
        Sha256 = ''
        Size = 0
        Tag = ''
        PackageFiles = @()
    }

    if (-not $Manifest) { $result.Error = 'Update-Manifest fehlt.'; return [pscustomobject]$result }
    if ([int]$Manifest.schemaVersion -ne 1) { $result.Error = 'Update-Manifest-Schema wird nicht unterstützt.'; return [pscustomobject]$result }

    $version = ([string]$Manifest.version).Trim()
    if (-not (ConvertTo-LenovoVersionCore -Version $version)) { $result.Error = 'Update-Version ist ungültig.'; return [pscustomobject]$result }

    $expectedFile = ('LenovoBootMenuTray-v{0}.zip' -f $version)
    $file = ([string]$Manifest.file).Trim()
    if ($file -ne $expectedFile) { $result.Error = 'Update-Dateiname passt nicht zur Version.'; return [pscustomobject]$result }

    $sha = ([string]$Manifest.sha256).Trim().ToLowerInvariant()
    if ($sha -notmatch '^[0-9a-fA-F]{64}$') { $result.Error = 'Update-SHA-256 ist ungültig.'; return [pscustomobject]$result }

    $size = 0L
    try { $size = [int64]$Manifest.size } catch { $size = 0L }
    if ($size -le 0) { $result.Error = 'Update-Dateigröße ist ungültig.'; return [pscustomobject]$result }

    $tag = ([string]$Manifest.tag).Trim()
    if ($tag -ne ('v{0}' -f $version)) { $result.Error = 'Update-Tag passt nicht zur Version.'; return [pscustomobject]$result }

    $packageFiles = @($Manifest.packageFiles)
    if ($packageFiles.Count -lt 1) { $result.Error = 'Update-Paketdateien fehlen.'; return [pscustomobject]$result }
    $seen = @{}
    $normalizedFiles = @()
    foreach ($item in $packageFiles) {
        $name = ([string]$item).Trim()
        if (-not $name -or $name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            $result.Error = 'Update-Paket enthält einen ungültigen Dateinamen.'; return [pscustomobject]$result
        }
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { $result.Error = 'Update-Paket enthält doppelte Dateinamen.'; return [pscustomobject]$result }
        $seen[$key] = $true
        $normalizedFiles += $name
    }
    foreach ($required in @('LenovoBootMenuTray.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1')) {
        if (-not $seen.ContainsKey($required.ToLowerInvariant())) {
            $result.Error = 'Update-Paket ist unvollständig.'; return [pscustomobject]$result
        }
    }

    $result.IsValid = $true
    $result.Version = $version
    $result.File = $file
    $result.Sha256 = $sha
    $result.Size = $size
    $result.Tag = $tag
    $result.PackageFiles = @($normalizedFiles)
    return [pscustomobject]$result
}

function New-UpdateRuntimeState {
    [pscustomobject]@{
        Status = 'Idle'
        AvailableManifest = $null
        LastError = ''
        CheckProcess = $null
        CheckTimer = $null
        CheckResultPath = $null
        PrepareProcess = $null
        PrepareTimer = $null
        PrepareResultPath = $null
        ManifestPath = $null
    }
}

function Set-UpdateRuntimeChecking {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Checking'
    $State.AvailableManifest = $null
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeIdle {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Idle'
    return $State
}

function Set-UpdateRuntimeAvailable {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)]$Manifest)
    $State.Status = 'UpdateAvailable'
    $State.AvailableManifest = $Manifest
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimePreparing {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'Preparing'
    $State.LastError = ''
    return $State
}

function Set-UpdateRuntimeReadyToInstall {
    param([Parameter(Mandatory=$true)]$State)
    $State.Status = 'ReadyToInstall'
    return $State
}

function Set-UpdateRuntimeFailed {
    param([Parameter(Mandatory=$true)]$State,[Parameter(Mandatory=$true)][string]$Message)
    $State.Status = 'Failed'
    $State.LastError = $Message
    return $State
}

function Test-UpdateRuntimeBusy {
    param([AllowNull()]$State)
    if (-not $State) { return $false }
    return @('Checking','Preparing','ReadyToInstall') -contains [string]$State.Status
}


$script:MaintenanceState = New-MaintenanceRuntimeState
$script:BootTargetDriftState = New-BootTargetDriftRuntimeState
$script:UpdateState = New-UpdateRuntimeState

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
    $Menu.Add_Opening({
        try {
            $this.Region = $null
            [LenovoMenuLayout]::PrepareItems($this)
            [LenovoMenuChrome]::Apply($this)
        } catch { }
    })
    $Menu.Add_Opened({
        try {
            $this.Region = $null
            [LenovoMenuChrome]::Apply($this)
            [LenovoMenuLayout]::PrepareItems($this)
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

function Ensure-DarkActionTooltip {
    if (-not $script:DarkActionTooltip) {
        $script:DarkActionTooltipFont = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.OwnerDraw = $true
        $tip.ShowAlways = $true
        $tip.UseAnimation = $false
        $tip.UseFading = $false
        $tip.InitialDelay = 0
        $tip.ReshowDelay = 0
        $tip.AutoPopDelay = 3500
        $tip.BackColor = [Drawing.Color]::FromArgb(28,28,28)
        $tip.ForeColor = [Drawing.Color]::FromArgb(238,238,238)
        $tip.Add_Popup({
            param($sender,$eventArgs)
            $text = [string]$script:DarkActionTooltipText
            if ([string]::IsNullOrWhiteSpace($text)) { return }
            $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
                $text,
                $script:DarkActionTooltipFont,
                (New-Object Drawing.Size(320,0)),
                ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
            )
            $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
            $height = [Math]::Max(30, $measured.Height + 12)
            $eventArgs.ToolTipSize = New-Object Drawing.Size($width,$height)
        })
        $tip.Add_Draw({
            param($sender,$eventArgs)
            $bounds = $eventArgs.Bounds
            $bg = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(28,28,28))
            $border = New-Object Drawing.Pen([Drawing.Color]::FromArgb(76,76,76),1)
            try {
                $eventArgs.Graphics.FillRectangle($bg, $bounds)
                $eventArgs.Graphics.DrawRectangle($border, 0, 0, [Math]::Max(0,$bounds.Width-1), [Math]::Max(0,$bounds.Height-1))
                $textRect = New-Object Drawing.Rectangle(9, 0, [Math]::Max(1,$bounds.Width-18), $bounds.Height)
                [System.Windows.Forms.TextRenderer]::DrawText(
                    $eventArgs.Graphics,
                    [string]$script:DarkActionTooltipText,
                    $script:DarkActionTooltipFont,
                    $textRect,
                    [Drawing.Color]::FromArgb(238,238,238),
                    ([System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
                )
            }
            finally {
                $border.Dispose()
                $bg.Dispose()
            }
        })
        $script:DarkActionTooltip = $tip
    }
    return $script:DarkActionTooltip
}

function Show-DarkActionTooltip {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Control]$Owner,
        [Parameter(Mandatory=$true)][string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text) -or -not $Owner -or $Owner.IsDisposed) { return }
    $tip = Ensure-DarkActionTooltip
    $script:DarkActionTooltipText = $Text
    $script:DarkActionTooltipOwner = $Owner

    $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text,
        $script:DarkActionTooltipFont,
        (New-Object Drawing.Size(320,0)),
        ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
    )
    $width = [Math]::Min(340, [Math]::Max(120, $measured.Width + 20))
    $height = [Math]::Max(30, $measured.Height + 12)
    $work = [System.Windows.Forms.Screen]::FromControl($Owner).WorkingArea
    $ownerTopLeft = $Owner.PointToScreen([System.Drawing.Point]::Empty)
    $x = $ownerTopLeft.X + $Owner.Width + 8
    if (($x + $width) -gt $work.Right) { $x = $ownerTopLeft.X - $width - 8 }
    if ($x -lt $work.Left) { $x = [Math]::Max($work.Left, [Math]::Min($work.Right - $width, $ownerTopLeft.X)) }
    $y = $ownerTopLeft.Y + [int](($Owner.Height - $height) / 2)
    if ($y -lt $work.Top) { $y = $work.Top }
    if (($y + $height) -gt $work.Bottom) { $y = $work.Bottom - $height }
    $clientPoint = $Owner.PointToClient((New-Object Drawing.Point($x,$y)))

    try { $tip.Hide($Owner) } catch { }
    $tip.Show($Text, $Owner, $clientPoint.X, $clientPoint.Y, 3500)
}

function Hide-DarkActionTooltip {
    if ($script:DarkActionTooltip -and $script:DarkActionTooltipOwner) {
        try { $script:DarkActionTooltip.Hide($script:DarkActionTooltipOwner) } catch { }
    }
    $script:DarkActionTooltipOwner = $null
    $script:DarkActionTooltipText = $null
}


function Update-HeaderRefreshStatus {
    if (Test-MaintenanceBusy) {
        if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) { $script:HeaderTitleLabel.Location = New-Object Drawing.Point(16, 10) }
        if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
            $script:HeaderStatusLabel.Text = Get-MaintenanceBusyStatusText
            $script:HeaderStatusLabel.Visible = $true
        }
        return
    }

    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }

    if ($script:HeaderTitleLabel -and -not $script:HeaderTitleLabel.IsDisposed) {
        $script:HeaderTitleLabel.Location = if ($active) {
            New-Object Drawing.Point(16, 10)
        }
        else {
            New-Object Drawing.Point(16, 19)
        }
    }

    if ($script:HeaderStatusLabel -and -not $script:HeaderStatusLabel.IsDisposed) {
        $script:HeaderStatusLabel.Text = if ($active) { 'Aktualisiere Bootziele…' } else { '' }
        $script:HeaderStatusLabel.Visible = $active
    }
}

function Update-RefreshButtonVisual {
    if (-not $script:RefreshButton -or $script:RefreshButton.IsDisposed) {
        Update-HeaderRefreshStatus
        return
    }
    $active = $false
    try { $active = (Test-BackgroundRefreshActive -State $script:BackgroundRefreshState) } catch { }
    $script:RefreshButton.Enabled = ((Get-SystemFunctionsPresentationState) -eq 'Ready')
    $script:RefreshButton.ForeColor = if ($active -or $script:RefreshButtonHovered) { $script:ColorAccent } else { $script:ColorSecondary }
    Update-HeaderRefreshStatus
}


function Get-RuntimeDiagnosticRole {
    if ($BackgroundRefresh) { return 'background-refresh' }
    if ($UpdateCheck) { return 'update-check' }
    if ($UpdatePrepare) { return 'update-prepare' }
    return 'tray'
}

function ConvertTo-RuntimeDiagnosticText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $result = [string]$Text
    $pairs = @(
        @([string]$env:LOCALAPPDATA, '%LOCALAPPDATA%'),
        @([string]$env:USERPROFILE, '%USERPROFILE%'),
        @([string]$env:USERNAME, '<user>'),
        @([string]$env:COMPUTERNAME, '<computer>')
    )
    foreach ($pair in $pairs) {
        if (-not [string]$pair[0]) { continue }
        $result = [regex]::Replace($result, [regex]::Escape([string]$pair[0]), [string]$pair[1], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $result
}

function New-RuntimeDiagnosticData {
    param([hashtable]$Values)
    $result = [ordered]@{}
    if (-not $Values) { return $result }
    foreach ($key in @($Values.Keys)) {
        if (-not $key) { continue }
        $value = $Values[$key]
        if ($null -eq $value) { continue }
        if ($value -is [string]) { $value = ConvertTo-RuntimeDiagnosticText -Text $value }
        $result[[string]$key] = $value
    }
    return $result
}

function Initialize-RuntimeDiagnostics {
    try {
        $candidate = ([string]$RuntimeSessionId).Trim()
        if ($candidate) { $candidate = ($candidate -replace '[^A-Za-z0-9-]', '') }
        if (-not $candidate) { $candidate = [guid]::NewGuid().ToString('D') }

        $script:RuntimeSessionId = $candidate
        $script:RuntimeSessionStartedUtc = [datetime]::UtcNow
        $script:RuntimeSessionDir = Join-Path $script:RuntimeDiagnosticsRoot $candidate
        $script:RuntimeEventsPath = Join-Path $script:RuntimeSessionDir 'runtime.jsonl'
        if (-not (Test-Path -LiteralPath $script:RuntimeSessionDir)) {
            [void](New-Item -ItemType Directory -Path $script:RuntimeSessionDir -Force)
        }
        $script:RuntimeDiagnosticsAvailable = $true

        # Retention is deliberately conservative and best-effort. A diagnosis must
        # never prevent the tray from starting or a boot action from completing.
        try {
            $cutoff = [datetime]::UtcNow.AddDays(-30)
            foreach ($dir in @(Get-ChildItem -LiteralPath $script:RuntimeDiagnosticsRoot -Directory -ErrorAction SilentlyContinue)) {
                if ($dir.FullName -eq $script:RuntimeSessionDir) { continue }
                if ($dir.LastWriteTimeUtc -lt $cutoff) {
                    Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } catch { }

        Write-RuntimeDiagnosticEvent -Event $(if ($BackgroundRefresh) { 'BACKGROUND_WORKER_STARTED' } elseif ($UpdateCheck) { 'UPDATE_CHECK_WORKER_STARTED' } elseif ($UpdatePrepare) { 'UPDATE_PREPARE_WORKER_STARTED' } else { 'SESSION_STARTED' }) -Stage 'startup' -Success $true -Data (New-RuntimeDiagnosticData @{
            role = (Get-RuntimeDiagnosticRole)
            parentSession = [bool]([string]$RuntimeSessionId)
        })
    }
    catch {
        $script:RuntimeDiagnosticsAvailable = $false
    }
}

function Write-RuntimeDiagnosticEvent {
    param(
        [Parameter(Mandatory=$true)][string]$Event,
        [string]$Stage = '',
        [AllowNull()][object]$Success = $null,
        [AllowNull()][object]$DurationMs = $null,
        [AllowNull()]$ErrorRecord = $null,
        [AllowNull()]$Data = $null,
        [ValidateSet('info','warning','error')][string]$Level = 'info'
    )

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeEventsPath) { return }
    try {
        $record = [ordered]@{
            utc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            appVersion = $script:AppVersion
            processId = $PID
            role = (Get-RuntimeDiagnosticRole)
            event = $Event
            stage = $Stage
            level = $Level
        }
        if ($null -ne $Success) { $record.success = [bool]$Success }
        if ($null -ne $DurationMs) { $record.durationMs = [int64]$DurationMs }

        if ($ErrorRecord) {
            $exception = $null
            if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $exception = $ErrorRecord.Exception }
            elseif ($ErrorRecord -is [System.Exception]) { $exception = $ErrorRecord }
            elseif ($ErrorRecord.Exception) { $exception = $ErrorRecord.Exception }
            if ($exception) {
                $record.errorClass = $exception.GetType().FullName
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$exception.Message)
            }
            else {
                $record.errorClass = 'UnknownError'
                $record.errorMessage = ConvertTo-RuntimeDiagnosticText -Text ([string]$ErrorRecord)
            }
            $script:RuntimeDiagnosticsErrorCount++
        }

        if ($Data) { $record.data = $Data }
        $json = $record | ConvertTo-Json -Depth 10 -Compress

        # FileShare.ReadWrite allows the tray and its hidden refresh child to append
        # to the same session log. Logging is single-attempt/best-effort: diagnostics
        # must never introduce retry delays into a boot or task action.
        try {
            $stream = [System.IO.FileStream]::new($script:RuntimeEventsPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
            try {
                $writer = [System.IO.StreamWriter]::new($stream, (New-Object System.Text.UTF8Encoding($false)))
                try { $writer.WriteLine($json); $writer.Flush() }
                finally { $writer.Dispose() }
            }
            finally { if ($stream) { $stream.Dispose() } }
        }
        catch { }
    }
    catch { }
}

function Get-RuntimeDiagnosticBrokerSummary {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return [ordered]@{ present = $false } }
    $targets = @()
    foreach ($target in @($meta.targets)) {
        $targets += [ordered]@{
            guid = [string]$target.guid
            taskName = [string]$target.taskName
            defaultTaskName = [string]$target.defaultTaskName
        }
    }
    return [ordered]@{
        present = $true
        version = [string]$meta.version
        installedUtc = [string]$meta.installedUtc
        managerRefreshTask = [string]$meta.managerRefreshTask
        firmwareRefreshTask = [string]$meta.firmwareRefreshTask
        defaultClearTask = [string]$meta.defaultClearTask
        defaultRestoreTask = [string]$meta.defaultRestoreTask
        defaultRestoreDelaySeconds = $meta.defaultRestoreDelaySeconds
        targetCount = @($targets).Count
        targets = @($targets)
    }
}

function Export-RuntimeDiagnosticPackage {
    param([string]$Reason = 'manual')

    if (-not $script:RuntimeDiagnosticsAvailable -or -not $script:RuntimeSessionId) {
        throw 'Für diese Sitzung sind keine Runtime-Diagnosedaten verfügbar.'
    }

    $exportRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
    if (-not (Test-Path -LiteralPath $exportRoot)) { [void](New-Item -ItemType Directory -Path $exportRoot -Force) }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $shortSession = if ($script:RuntimeSessionId.Length -ge 8) { $script:RuntimeSessionId.Substring(0,8) } else { $script:RuntimeSessionId }
    $zipPath = Join-Path $exportRoot ("Lenovo-Boot-Selector-Diagnostics-{0}-{1}.zip" -f $stamp,$shortSession)
    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("LenovoBootSelectorDiag-{0}" -f ([guid]::NewGuid().ToString('N')))

    Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_REQUESTED' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ reason = $Reason; outputName = [System.IO.Path]::GetFileName($zipPath) })

    try {
        [void](New-Item -ItemType Directory -Path $stage -Force)
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            Copy-Item -LiteralPath $script:RuntimeEventsPath -Destination (Join-Path $stage 'runtime.jsonl') -Force
        }
        else {
            [System.IO.File]::WriteAllText((Join-Path $stage 'runtime.jsonl'), '', (New-Object System.Text.UTF8Encoding($false)))
        }

        $environment = [ordered]@{
            exportedUtc = [datetime]::UtcNow.ToString('o')
            sessionId = $script:RuntimeSessionId
            sessionStartedUtc = $script:RuntimeSessionStartedUtc.ToString('o')
            appVersion = $script:AppVersion
            taskBrokerSchemaSupported = @($script:SupportedTaskBrokerVersions)
            osVersion = [Environment]::OSVersion.VersionString
            os64Bit = [Environment]::Is64BitOperatingSystem
            process64Bit = [Environment]::Is64BitProcess
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            clrVersion = [Environment]::Version.ToString()
            role = (Get-RuntimeDiagnosticRole)
            lastBackgroundRefreshTiming = $(if ($script:BackgroundRefreshState) { $script:BackgroundRefreshState.LastTiming } else { $null })
        }
        [System.IO.File]::WriteAllText((Join-Path $stage 'environment.json'), ($environment | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $broker = Get-RuntimeDiagnosticBrokerSummary
        [System.IO.File]::WriteAllText((Join-Path $stage 'task-broker-summary.json'), ($broker | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

        $eventCount = 0
        $errorCount = 0
        if (Test-Path -LiteralPath $script:RuntimeEventsPath) {
            foreach ($line in @([System.IO.File]::ReadAllLines($script:RuntimeEventsPath, [System.Text.Encoding]::UTF8))) {
                if (-not $line) { continue }
                $eventCount++
                if ($line -match '"level":"error"') { $errorCount++ }
            }
        }
        $summary = @(
            'Lenovo Boot Selector – Runtime-Diagnose',
            "App-Version: $($script:AppVersion)",
            "Session: $($script:RuntimeSessionId)",
            "Sitzungsstart (UTC): $($script:RuntimeSessionStartedUtc.ToString('o'))",
            "Export (UTC): $([datetime]::UtcNow.ToString('o'))",
            "Grund: $Reason",
            "Events: $eventCount",
            "Fehler-Events: $errorCount",
            '',
            'Enthalten sind ausschließlich die aktuelle Runtime-Sitzung sowie technische Environment-/TaskBroker-Metadaten.',
            'Benutzername, Rechnername und TaskBroker-userSid werden nicht exportiert.'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText((Join-Path $stage 'summary.txt'), $summary, (New-Object System.Text.UTF8Encoding($false)))

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        $script:LastRuntimeDiagnosticPackage = $zipPath
        return $zipPath
    }
    finally {
        try { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } } catch { }
    }
}

function Show-DiagnosticPackageInExplorer {
    param([Parameter(Mandatory=$true)][string]$Path)

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Das Diagnosepaket ist nicht mehr vorhanden.' }
        $explorer = Join-Path $env:WINDIR 'explorer.exe'
        if (-not (Test-Path -LiteralPath $explorer -PathType Leaf)) { $explorer = 'explorer.exe' }
        $safePath = $Path.Replace('"','')
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $explorer
        $psi.Arguments = ('/select,"{0}"' -f $safePath)
        $psi.UseShellExecute = $true
        [void][System.Diagnostics.Process]::Start($psi)
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $true -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) })
        return $true
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_REVEAL' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ outputName = [System.IO.Path]::GetFileName($Path) }) -Level warning
        return $false
    }
}

function Get-LenovoUpdateManifestUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json'
}

function Get-LenovoUpdateDownloadBaseUri {
    return 'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/'
}

function Get-LenovoUpdateResultPath {
    $root = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    return (Join-Path $root 'last-update-result.json')
}

function Read-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $json = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($json)) { return $null }
        return ($json | ConvertFrom-Json)
    }
    catch {
        return [pscustomobject]@{
            schemaVersion = 1
            status = 'failed'
            sourceVersion = ''
            targetVersion = ''
            utc = [datetime]::UtcNow.ToString('o')
            message = ('Update-Ergebnis konnte nicht gelesen werden: ' + $_.Exception.Message)
            rollbackAttempted = $false
            rollbackSucceeded = $false
        }
    }
}

function Remove-LenovoUpdateResult {
    $path = Get-LenovoUpdateResultPath
    try {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    } catch { }
}

function Enable-LenovoUpdateTls12 {
    try {
        $current = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $current -bor [System.Net.SecurityProtocolType]::Tls12
    } catch { }
}

function New-LenovoWebClient {
    Enable-LenovoUpdateTls12
    $client = New-Object System.Net.WebClient
    $client.Headers['User-Agent'] = 'LenovoBootSelector/' + $script:AppVersion
    $client.Headers['Cache-Control'] = 'no-cache'
    return $client
}

function Get-LenovoUpdateManifestRemote {
    $client = New-LenovoWebClient
    try {
        $json = $client.DownloadString((Get-LenovoUpdateManifestUri))
        if ([string]::IsNullOrWhiteSpace($json)) { throw 'Update-Manifest ist leer.' }
        return ($json | ConvertFrom-Json)
    }
    finally { $client.Dispose() }
}

function Get-LenovoSha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try { $hash = $sha.ComputeHash($stream) }
        finally { $stream.Dispose() }
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally { $sha.Dispose() }
}

function Write-LenovoUpdateWorkerResult {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path,$json,(New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-UpdateCheckWorker {
    $result = [ordered]@{ Success=$false; UpdateAvailable=$false; Manifest=$null; Error='' }
    try {
        $raw = Get-LenovoUpdateManifestRemote
        $validated = Test-LenovoUpdateManifestCore -Manifest $raw
        if (-not $validated.IsValid) { throw $validated.Error }
        $comparison = Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version
        $result.Success = $true
        $result.UpdateAvailable = ($comparison -gt 0)
        $result.Manifest = $validated
    }
    catch { $result.Error = $_.Exception.Message }
    if ($UpdateResultPath) { Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result) }
    return $(if ($result.Success) { 0 } else { 1 })
}

function Start-UpdateCheckWorkerProcess {
    param([Parameter(Mandatory=$true)][string]$ResultPath,[string]$RuntimeSessionId)
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdateCheck','-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}

function Test-LenovoUpdatePackageZip {
    param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)]$Manifest)
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $names = @()
        foreach ($entry in @($archive.Entries)) {
            $name = [string]$entry.FullName
            if ([string]::IsNullOrWhiteSpace($name)) { throw 'Update-ZIP enthält einen leeren Pfad.' }
            if ($name.Contains('..') -or $name.Contains('/') -or $name.Contains('\')) { throw 'Update-ZIP enthält einen unzulässigen Pfad.' }
            if ($entry.Length -lt 0) { throw 'Update-ZIP enthält einen ungültigen Eintrag.' }
            $names += $name
        }
        $expected = @($Manifest.PackageFiles | Sort-Object)
        $actual = @($names | Sort-Object)
        if ($expected.Count -ne $actual.Count) { throw 'Update-ZIP enthält nicht die erwartete Anzahl Dateien.' }
        for ($i=0;$i -lt $expected.Count;$i++) {
            if ([string]$expected[$i] -ne [string]$actual[$i]) { throw 'Update-ZIP-Dateiliste stimmt nicht mit dem Manifest überein.' }
        }
    }
    finally { $archive.Dispose() }
}

function Prepare-LenovoUpdatePackage {
    param([Parameter(Mandatory=$true)]$Manifest)
    $updateRoot = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates'
    if (-not (Test-Path -LiteralPath $updateRoot)) { [void](New-Item -ItemType Directory -Path $updateRoot -Force) }
    $work = Join-Path $updateRoot (('{0}-{1}' -f $Manifest.Version,([guid]::NewGuid().ToString('N'))))
    $payload = Join-Path $work 'payload'
    [void](New-Item -ItemType Directory -Path $payload -Force)
    $zipPath = Join-Path $work ([string]$Manifest.File)
    $manifestPath = Join-Path $work 'manifest.json'
    [System.IO.File]::WriteAllText($manifestPath,($Manifest | ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))

    $client = New-LenovoWebClient
    try {
        $uri = (Get-LenovoUpdateDownloadBaseUri) + [Uri]::EscapeDataString([string]$Manifest.File)
        $client.DownloadFile($uri,$zipPath)
    }
    finally { $client.Dispose() }

    $length = (Get-Item -LiteralPath $zipPath).Length
    if ([int64]$length -ne [int64]$Manifest.Size) { throw 'Update-Dateigröße stimmt nicht mit dem Manifest überein.' }
    $actualSha = Get-LenovoSha256Hex -Path $zipPath
    if ($actualSha -ne ([string]$Manifest.Sha256).ToLowerInvariant()) { throw 'Update-SHA-256 stimmt nicht mit dem Manifest überein.' }

    Test-LenovoUpdatePackageZip -ZipPath $zipPath -Manifest $Manifest
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$payload)

    $runtimePath = Join-Path $payload 'LenovoBootMenuTray.ps1'
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) { throw 'Update-Runtime fehlt im Paket.' }
    $runtimeText = [System.IO.File]::ReadAllText($runtimePath,[System.Text.Encoding]::UTF8)
    $versionNeedle = ('$script:AppVersion = ''{0}''' -f [string]$Manifest.Version)
    if (-not $runtimeText.Contains($versionNeedle)) { throw 'Update-Runtime-Version stimmt nicht mit dem Manifest überein.' }

    return [pscustomobject]@{ WorkDir=$work; PayloadDir=$payload; ManifestPath=$manifestPath; Version=[string]$Manifest.Version }
}

function Invoke-UpdatePrepareWorker {
    $result = [ordered]@{ Success=$false; WorkDir=''; PayloadDir=''; ManifestPath=''; Version=''; Error='' }
    try {
        if (-not $UpdateManifestPath -or -not (Test-Path -LiteralPath $UpdateManifestPath -PathType Leaf)) { throw 'Update-Manifestdatei fehlt.' }
        $raw = [System.IO.File]::ReadAllText($UpdateManifestPath,[System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $validated = Test-LenovoUpdateManifestCore -Manifest $raw
        if (-not $validated.IsValid) { throw $validated.Error }
        if ((Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $validated.Version) -le 0) { throw 'Es liegt keine neuere Version vor.' }
        $prepared = Prepare-LenovoUpdatePackage -Manifest $validated
        $result.Success = $true
        $result.WorkDir = $prepared.WorkDir
        $result.PayloadDir = $prepared.PayloadDir
        $result.ManifestPath = $prepared.ManifestPath
        $result.Version = $prepared.Version
    }
    catch { $result.Error = $_.Exception.Message }
    if ($UpdateResultPath) { Write-LenovoUpdateWorkerResult -Path $UpdateResultPath -Value ([pscustomobject]$result) }
    return $(if ($result.Success) { 0 } else { 1 })
}

function Start-UpdatePrepareWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [string]$RuntimeSessionId
    )
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:ScriptPath),'-UpdatePrepare','-UpdateManifestPath',('"{0}"' -f $ManifestPath),'-UpdateResultPath',('"{0}"' -f $ResultPath))
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId',('"{0}"' -f $RuntimeSessionId)) }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}

function Test-UpdateInstallDirectoryWritable {
    $probe = Join-Path $PSScriptRoot ('.lbs-update-write-{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllText($probe,'probe',(New-Object System.Text.UTF8Encoding($false)))
        return $true
    }
    catch { return $false }
    finally { try { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force } } catch { } }
}

function New-LenovoUpdateInstallerHelper {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helperPath = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelectorUpdate-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
    $scriptText = @'
param(
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$InstallDir,
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [Parameter(Mandatory=$true)][string]$SourceVersion
)
$ErrorActionPreference = 'Stop'
$backup = Join-Path $WorkDir 'backup'
$payload = Join-Path $WorkDir 'payload'
$manifestPath = Join-Path $WorkDir 'manifest.json'
$resultPath = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Updates\last-update-result.json'
$targetVersion = ''
$rollbackAttempted = $false
$rollbackSucceeded = $false
function Write-Result([string]$Status,[string]$Message) {
    $parent = Split-Path -Parent $resultPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    $obj=[ordered]@{
        schemaVersion=1
        utc=[datetime]::UtcNow.ToString('o')
        status=$Status
        sourceVersion=$SourceVersion
        targetVersion=$targetVersion
        message=$Message
        rollbackAttempted=[bool]$rollbackAttempted
        rollbackSucceeded=[bool]$rollbackSucceeded
    }
    [System.IO.File]::WriteAllText($resultPath,($obj|ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding($false)))
}
function Restart-InstalledApp {
    $launcher=Join-Path $InstallDir 'Start-LenovoBootMenuTray.vbs'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw 'Launcher fehlt nach dem Update.' }
    $wscript=Join-Path $env:SystemRoot 'System32\wscript.exe'
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName=$wscript
    $psi.Arguments=('"{0}"' -f $launcher)
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    return [System.Diagnostics.Process]::Start($psi)
}
function Show-UpdateError([string]$Message) {
    try { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($Message,'Lenovo Boot Selector – Update',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) } catch { }
}
try {
    try { $parent=[System.Diagnostics.Process]::GetProcessById($ParentPid); [void]$parent.WaitForExit(30000) } catch { }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest fehlt.' }
    $manifest=[System.IO.File]::ReadAllText($manifestPath,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
    $targetVersion=[string]$manifest.version
    $files=@($manifest.packageFiles)
    if ($files.Count -lt 1) { throw 'Paketdateien fehlen.' }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $backup -Force)
    $existing=@{}
    foreach($name in $files) {
        $source=Join-Path $payload ([string]$name)
        $target=Join-Path $InstallDir ([string]$name)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Paketdatei fehlt: $name" }
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $existing[[string]$name]=$true
            Copy-Item -LiteralPath $target -Destination (Join-Path $backup ([string]$name)) -Force
        }
        else { $existing[[string]$name]=$false }
    }
    try {
        foreach($name in $files) {
            Copy-Item -LiteralPath (Join-Path $payload ([string]$name)) -Destination (Join-Path $InstallDir ([string]$name)) -Force
        }
        # Success is intentionally not declared here. The restarted tray must prove
        # that the expected target version is actually running before showing success.
        Write-Result 'pending-verification' ('Update auf v' + $targetVersion + ' installiert; Neustart-Verifikation ausstehend.')
        $started = Restart-InstalledApp
        if (-not $started) { throw 'Lenovo Boot Selector konnte nach dem Update nicht neu gestartet werden.' }
        try { $started.Dispose() } catch { }
    }
    catch {
        $installError=$_.Exception.Message
        # ROLLBACK: restore every previous managed file and remove newly introduced files.
        $rollbackAttempted=$true
        try {
            foreach($name in $files) {
                $target=Join-Path $InstallDir ([string]$name)
                $saved=Join-Path $backup ([string]$name)
                if ($existing[[string]$name] -and (Test-Path -LiteralPath $saved -PathType Leaf)) {
                    Copy-Item -LiteralPath $saved -Destination $target -Force
                }
                elseif (-not $existing[[string]$name] -and (Test-Path -LiteralPath $target -PathType Leaf)) {
                    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
                }
            }
            $rollbackSucceeded=$true
        }
        catch {
            $rollbackSucceeded=$false
            throw ($installError + ' | Rollback fehlgeschlagen: ' + $_.Exception.Message)
        }
        throw $installError
    }
    try { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
catch {
    $failureMessage=$_.Exception.Message
    Write-Result 'failed' $failureMessage
    try {
        $restart = Restart-InstalledApp
        if ($restart) { try { $restart.Dispose() } catch { } }
        else { throw 'Lenovo Boot Selector konnte nach dem fehlgeschlagenen Update nicht neu gestartet werden.' }
    }
    catch {
        Show-UpdateError ('Update fehlgeschlagen: ' + $failureMessage + "`r`n`r`nDie App konnte nicht automatisch neu gestartet werden. Bitte starte Lenovo Boot Selector manuell.")
    }
}
finally {
    try { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue } catch { }
}
'@
    [System.IO.File]::WriteAllText($helperPath,$scriptText,(New-Object System.Text.UTF8Encoding($true)))
    return $helperPath
}

function Start-LenovoUpdateInstallerHelper {
    param(
        [Parameter(Mandatory=$true)][string]$WorkDir,
        [Parameter(Mandatory=$true)][string]$SourceVersion
    )
    $helper = New-LenovoUpdateInstallerHelper -WorkDir $WorkDir
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershell)) { $powershell = 'powershell.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershell
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -ParentPid {1} -InstallDir "{2}" -WorkDir "{3}" -SourceVersion "{4}"' -f $helper,$PID,$PSScriptRoot,$WorkDir,$SourceVersion)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}


function Save-RuntimeDiagnosticsFromUi {
    try {
        $path = Export-RuntimeDiagnosticPackage -Reason 'manual-ui'
        $revealPath = $path
        $revealAction = { Show-DiagnosticPackageInExplorer -Path $revealPath }.GetNewClosure()
        Show-LenovoNoticeDialog -Title 'Diagnose gespeichert' -Heading 'Das Diagnosepaket wurde erstellt.' -Message ("Speicherort:`r`n{0}" -f $path) -Kind Info -SecondaryButtonText 'Im Ordner anzeigen' -SecondaryAction $revealAction
    }
    catch {
        Write-RuntimeDiagnosticEvent -Event 'DIAGNOSTIC_EXPORT_FAILED' -Stage 'diagnostics' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title 'Diagnose nicht gespeichert' -Heading 'Das Diagnosepaket konnte nicht erstellt werden.' -Message 'Bitte versuche es erneut.' -Kind Error
    }
}

function Show-PendingUpdateResultOnStartup {
    $result = Read-LenovoUpdateResult
    if (-not $result) { return $false }

    $resolved = Resolve-LenovoUpdateRestartResultCore -Result $result -RunningVersion $script:AppVersion

    Write-RuntimeDiagnosticEvent -Event 'UPDATE_RESTART_RESULT' -Stage 'update-restart' -Success $resolved.Success -Data (New-RuntimeDiagnosticData @{
        resultUtc = $resolved.ResultUtc
        resultStatus = $resolved.ResultStatus
        resultFormat = $resolved.ResultFormat
        legacySuccess = $resolved.LegacySuccess
        sourceVersion = $resolved.SourceVersion
        targetVersion = $resolved.TargetVersion
        runningVersion = $resolved.RunningVersion
        rollbackAttempted = $resolved.RollbackAttempted
        rollbackSucceeded = $resolved.RollbackSucceeded
        resultMessage = $resolved.StoredMessage
    }) -Level $(if ($resolved.Success) { 'info' } else { 'error' })

    # Consume before showing the modal dialog so this result is shown at most once,
    # even if the process is terminated while the dialog is open.
    Remove-LenovoUpdateResult

    if ($resolved.Success) {
        Show-LenovoNoticeDialog -Title 'Update erfolgreich' -Heading ('Lenovo Boot Selector v{0} ist installiert.' -f $resolved.DisplayVersion) -Message $resolved.Message -Kind Info
    }
    else {
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht erfolgreich aktualisiert werden.' -Message $resolved.Message -Kind Error
    }
    return $true
}

function Update-UpdateMenuState {
    # Manual update check only: there is intentionally no periodic or startup polling.
    if (-not $script:UpdateState) { return }
    $busy = Test-UpdateRuntimeBusy -State $script:UpdateState
    if ($script:UpdateCheckMenuItem) { $script:UpdateCheckMenuItem.Enabled = -not $busy }
    if ($script:UpdateInstallMenuItem) {
        $script:UpdateInstallMenuItem.Text = 'App aktualisieren…'
        $script:UpdateInstallMenuItem.Enabled = (-not $busy -and $null -ne $script:UpdateState.AvailableManifest)
    }
}

function Stop-UpdateCheckUiWorker {
    if ($script:UpdateState.CheckTimer) { try { $script:UpdateState.CheckTimer.Stop() } catch { }; try { $script:UpdateState.CheckTimer.Dispose() } catch { }; $script:UpdateState.CheckTimer=$null }
    if ($script:UpdateState.CheckProcess) { try { $script:UpdateState.CheckProcess.Dispose() } catch { }; $script:UpdateState.CheckProcess=$null }
}

function Complete-ManualUpdateCheck {
    Stop-UpdateCheckUiWorker
    $path=[string]$script:UpdateState.CheckResultPath
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Die Update-Prüfung hat kein Ergebnis geliefert.' }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) { throw ([string]$result.Error) }
        if ($result.UpdateAvailable) {
            $validated=Test-LenovoUpdateManifestCore -Manifest $result.Manifest
            if (-not $validated.IsValid) { throw $validated.Error }
            [void](Set-UpdateRuntimeAvailable -State $script:UpdateState -Manifest $validated)
            $script:LastStatusText = ('Neue Version verfügbar: v{0}' -f $validated.Version)
            Show-LenovoNoticeDialog -Title 'Neue Version verfügbar' -Heading ('Lenovo Boot Selector v{0} ist verfügbar.' -f $validated.Version) -Message 'Du kannst die neue Version jetzt direkt installieren. Später findest du die Aktualisierung im Tray-Menü unter „Wartung“ → „App aktualisieren…“.' -Kind Info -SecondaryButtonText 'Jetzt aktualisieren' -SecondaryAction { Start-ManualAppUpdate }
            Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_COMPLETED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$true; availableVersion=$validated.Version })
        }
        else {
            $script:UpdateState.AvailableManifest=$null
            [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
            $script:LastStatusText = ('Lenovo Boot Selector ist aktuell · v{0}' -f $script:AppVersion)
            Show-LenovoNoticeDialog -Title 'Keine neue Version' -Heading ('Lenovo Boot Selector v{0} ist aktuell.' -f $script:AppVersion) -Message 'Es ist derzeit keine neuere Version verfügbar.' -Kind Info
            Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_COMPLETED' -Stage 'update-check' -Success $true -Data (New-RuntimeDiagnosticData @{ updateAvailable=$false })
        }
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        $script:LastStatusText='Update-Prüfung fehlgeschlagen.'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_COMPLETED' -Stage 'update-check' -Success $false -ErrorRecord $_ -Level warning
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die Prüfung auf eine neue Version ist fehlgeschlagen.' -Message $_.Exception.Message -Kind Error
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.CheckResultPath=$null
        if ($script:UpdateState.Status -eq 'Failed') { [void](Set-UpdateRuntimeIdle -State $script:UpdateState) }
        Update-UpdateMenuState
        if ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows }
    }
}

function Start-ManualUpdateCheck {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    [void](Set-UpdateRuntimeChecking -State $script:UpdateState)
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateCheck-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $script:UpdateState.CheckResultPath=$resultPath
    try {
        $proc=Start-UpdateCheckWorkerProcess -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw 'Update-Prüfung konnte nicht gestartet werden.' }
        $script:UpdateState.CheckProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.CheckProcess) { return }
                $script:UpdateState.CheckProcess.Refresh()
                if ($script:UpdateState.CheckProcess.HasExited) { Complete-ManualUpdateCheck }
            } catch { Complete-ManualUpdateCheck }
        })
        $script:UpdateState.CheckTimer=$timer; $timer.Start()
        $script:LastStatusText='Auf neue Version wird geprüft…'
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_CHECK_STARTED' -Stage 'update-check' -Success $true
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Stop-UpdateCheckUiWorker
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die Prüfung konnte nicht gestartet werden.' -Message $_.Exception.Message -Kind Error
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
    }
    Update-UpdateMenuState
}

function Stop-UpdatePrepareUiWorker {
    if ($script:UpdateState.PrepareTimer) { try { $script:UpdateState.PrepareTimer.Stop() } catch { }; try { $script:UpdateState.PrepareTimer.Dispose() } catch { }; $script:UpdateState.PrepareTimer=$null }
    if ($script:UpdateState.PrepareProcess) { try { $script:UpdateState.PrepareProcess.Dispose() } catch { }; $script:UpdateState.PrepareProcess=$null }
}

function Exit-TrayForPreparedUpdate {
    param([Parameter(Mandatory=$true)][string]$WorkDir)
    $helper=Start-LenovoUpdateInstallerHelper -WorkDir $WorkDir -SourceVersion $script:AppVersion
    if (-not $helper) { throw 'Update-Installer konnte nicht gestartet werden.' }
    Write-RuntimeDiagnosticEvent -Event 'UPDATE_INSTALL_HELPER_STARTED' -Stage 'update-install' -Success $true -Data (New-RuntimeDiagnosticData @{ processId=$helper.Id; version=$script:UpdateState.AvailableManifest.Version })
    try { $helper.Dispose() } catch { }
    $script:ExitRequested=$true
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible=$false } } catch { }
    try { if ($script:Popup -and -not $script:Popup.IsDisposed) { $script:Popup.Hide() } } catch { }
    [System.Windows.Forms.Application]::ExitThread()
}

function Complete-ManualAppUpdatePrepare {
    Stop-UpdatePrepareUiWorker
    $path=[string]$script:UpdateState.PrepareResultPath
    try {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Die Update-Vorbereitung hat kein Ergebnis geliefert.' }
        $result=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::UTF8)|ConvertFrom-Json
        if (-not $result.Success) { throw ([string]$result.Error) }
        [void](Set-UpdateRuntimeReadyToInstall -State $script:UpdateState)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$result.Version })
        Exit-TrayForPreparedUpdate -WorkDir ([string]$result.WorkDir)
    }
    catch {
        [void](Set-UpdateRuntimeFailed -State $script:UpdateState -Message $_.Exception.Message)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PACKAGE_PREPARED' -Stage 'update-prepare' -Success $false -ErrorRecord $_ -Level error
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht aktualisiert werden.' -Message $_.Exception.Message -Kind Error
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
    }
    finally {
        try { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } } catch { }
        try { if ($script:UpdateState.ManifestPath -and (Test-Path -LiteralPath $script:UpdateState.ManifestPath)) { Remove-Item -LiteralPath $script:UpdateState.ManifestPath -Force -ErrorAction SilentlyContinue } } catch { }
        $script:UpdateState.PrepareResultPath=$null; $script:UpdateState.ManifestPath=$null
        Update-UpdateMenuState
    }
}

function Start-ManualAppUpdate {
    if (Test-MaintenanceBusy -or (Test-UpdateRuntimeBusy -State $script:UpdateState)) { return }
    $manifest=$script:UpdateState.AvailableManifest
    if (-not $manifest) { return }
    if (-not (Test-UpdateInstallDirectoryWritable)) {
        Show-LenovoNoticeDialog -Title 'Update nicht möglich' -Heading 'Der App-Ordner ist nicht beschreibbar.' -Message 'Verschiebe Lenovo Boot Selector in einen Ordner, den dein Benutzerkonto ändern darf, und versuche es erneut.' -Kind Error
        return
    }
    [void](Set-UpdateRuntimePreparing -State $script:UpdateState)
    $manifestPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdateManifest-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $resultPath=Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-UpdatePrepare-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 10),(New-Object System.Text.UTF8Encoding($false)))
    $script:UpdateState.ManifestPath=$manifestPath; $script:UpdateState.PrepareResultPath=$resultPath
    try {
        $proc=Start-UpdatePrepareWorkerProcess -ManifestPath $manifestPath -ResultPath $resultPath -RuntimeSessionId $script:RuntimeSessionId
        if (-not $proc) { throw 'Update-Vorbereitung konnte nicht gestartet werden.' }
        $script:UpdateState.PrepareProcess=$proc
        $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=200
        $timer.Add_Tick({
            try {
                if (-not $script:UpdateState.PrepareProcess) { return }
                $script:UpdateState.PrepareProcess.Refresh()
                if ($script:UpdateState.PrepareProcess.HasExited) { Complete-ManualAppUpdatePrepare }
            } catch { Complete-ManualAppUpdatePrepare }
        })
        $script:UpdateState.PrepareTimer=$timer; $timer.Start()
        $script:LastStatusText=('Update auf v{0} wird vorbereitet…' -f $manifest.Version)
        Write-RuntimeDiagnosticEvent -Event 'UPDATE_PREPARE_STARTED' -Stage 'update-prepare' -Success $true -Data (New-RuntimeDiagnosticData @{ version=$manifest.Version })
    }
    catch {
        Stop-UpdatePrepareUiWorker
        [void](Set-UpdateRuntimeIdle -State $script:UpdateState)
        Show-LenovoNoticeDialog -Title 'Update fehlgeschlagen' -Heading 'Die App konnte nicht aktualisiert werden.' -Message $_.Exception.Message -Kind Error
    }
    Update-UpdateMenuState
}


function Get-LegacyAutostartInfo {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $root = $service.GetFolder('\')
        $task = $root.GetTask("\$($script:LegacyAutostartTaskName)")
        if (-not $task) { return [pscustomobject]@{ Enabled = $false } }
        return [pscustomobject]@{ Enabled = [bool]$task.Enabled }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false }
    }
}

function Get-AutostartLauncherPath {
    return (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
}

function Get-AutostartCommand {
    $launcher = Get-AutostartLauncherPath
    if (-not (Test-Path -LiteralPath $launcher)) { return $null }
    $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
    return ('"{0}" //B //NoLogo "{1}"' -f $wscript, $launcher)
}

function Get-AutostartInfo {
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $props = Get-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -ErrorAction SilentlyContinue
        $value = if ($props) { [string]$props.($script:AutostartRunValueName) } else { '' }
        if (-not $value) {
            return [pscustomobject]@{ Enabled = $false; CurrentPath = $false }
        }
        $launcher = Get-AutostartLauncherPath
        $currentPath = (($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) -or
            ($script:ScriptPath -and ($value.IndexOf($script:ScriptPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)))
        $usesHiddenLauncher = ($launcher -and ($value.IndexOf($launcher, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
        return [pscustomobject]@{ Enabled = $true; CurrentPath = $currentPath; UsesHiddenLauncher = $usesHiddenLauncher }
    }
    catch {
        return [pscustomobject]@{ Enabled = $false; CurrentPath = $false }
    }
}

function Set-AutostartEnabled([bool]$Enabled) {
    if (-not $script:ScriptPath) {
        throw 'Der Pfad der Anwendung konnte nicht ermittelt werden.'
    }

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if ($Enabled) {
        if (-not (Test-Path $runKey)) { [void](New-Item -Path $runKey -Force) }
        $command = Get-AutostartCommand
        if (-not $command) { throw 'Der versteckte Autostart-Launcher wurde nicht gefunden.' }
        Set-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -Type String -Value $command
    }
    else {
        Remove-ItemProperty -Path $runKey -Name $script:AutostartRunValueName -ErrorAction SilentlyContinue
    }
}

function Repair-AutostartLauncherIfNeeded {
    try {
        $info = Get-AutostartInfo
        if ($info.Enabled) {
            # The Run value belongs exclusively to this app. Always migrate it to
            # the currently launched package and the hidden WScript/VBS launcher.
            # This also fixes upgrades from older versions that started PowerShell
            # directly and could leave a visible console window at logon.
            Set-AutostartEnabled -Enabled:$true
        }
    }
    catch { }
}


function Update-AutostartUi {
    $info = Get-AutostartInfo

    $script:UpdatingAutostartUi = $true
    try {
        if ($script:AutostartCheckbox -and -not $script:AutostartCheckbox.IsDisposed) {
            $script:AutostartCheckbox.Checked = [bool]$info.Enabled
            $script:AutostartCheckbox.Text = ''
        }
        if ($script:AutostartTextLabel -and -not $script:AutostartTextLabel.IsDisposed) {
            $script:AutostartTextLabel.Text = 'Mit Windows starten'
        }
        if ($script:AutostartMenuItem) {
            $script:AutostartMenuItem.Checked = [bool]$info.Enabled
            if ($info.Enabled -and -not $info.CurrentPath) {
                $script:AutostartMenuItem.Text = 'Mit Windows starten'
            }
            else {
                $script:AutostartMenuItem.Text = 'Mit Windows starten'
            }
        }
    }
    finally {
        $script:UpdatingAutostartUi = $false
    }

    return $info
}

function Set-AutostartFromUi([bool]$Enabled) {
    if ($script:UpdatingAutostartUi) { return }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Set-AutostartEnabled -Enabled:$Enabled
        $info = Update-AutostartUi
        if ($Enabled) { $script:LastStatusText = 'Autostart ist aktiviert.' }
        else { $script:LastStatusText = 'Autostart ist deaktiviert.' }

        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $matches = $script:Popup.Controls.Find('StatusLabel', $true)
            if ($matches.Count -gt 0) { $matches[0].Text = $script:LastStatusText }
        }
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTOSTART_CHANGE' -Stage 'autostart' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ enabled = $Enabled; currentPath = [bool]$info.CurrentPath; hiddenLauncher = [bool]$info.UsesHiddenLauncher })
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTOSTART_CHANGE' -Stage 'autostart' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ enabled = $Enabled }) -Level error
        Update-AutostartUi | Out-Null
        Show-LenovoNoticeDialog -Title 'Mit Windows starten' -Heading 'Die Einstellung konnte nicht geändert werden.' -Message 'Bitte versuche es erneut.' -Kind Error
    }
}


# Lenovo Boot Selector v0.4.1 - Functional Core: entry preferences/settings normalization
# Pure/deterministic functions only. No global script state, WinForms, filesystem, registry,
# Scheduled Tasks, process starts, or privileged broker access are permitted in this file.

function Convert-EntryAliasesToHashtable {
    param($Source)

    $result = @{}
    if (-not $Source) { return $result }

    if ($Source -is [System.Collections.IDictionary]) {
        foreach ($key in @($Source.Keys)) {
            if (-not $key) { continue }
            $normalized = ([string]$key).ToLowerInvariant()
            $value = ([string]$Source[$key]).Trim()
            if ($value) { $result[$normalized] = $value }
        }
        return $result
    }

    foreach ($property in @($Source.PSObject.Properties)) {
        if (-not $property.Name) { continue }
        $normalized = ([string]$property.Name).ToLowerInvariant()
        $value = ([string]$property.Value).Trim()
        if ($value) { $result[$normalized] = $value }
    }
    return $result
}
function Copy-EntryAliasMap {
    param($Source)
    $copy = @{}
    if (-not $Source) { return $copy }
    foreach ($key in @($Source.Keys)) {
        $value = ([string]$Source[$key]).Trim()
        if ($key -and $value) { $copy[([string]$key).ToLowerInvariant()] = $value }
    }
    return $copy
}
function Test-StringSequenceEqual {
    param([object[]]$Left, [object[]]$Right, [switch]$Sort)
    $a = @($Left | ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } })
    $b = @($Right | ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } })
    if ($Sort) { $a = @($a | Sort-Object -Unique); $b = @($b | Sort-Object -Unique) }
    if ($a.Count -ne $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) {
        if ($a[$i] -ne $b[$i]) { return $false }
    }
    return $true
}
function Test-EntryAliasMapsEqual {
    param($Left, $Right)
    $a = Copy-EntryAliasMap $Left
    $b = Copy-EntryAliasMap $Right
    $aKeys = @($a.Keys | Sort-Object)
    $bKeys = @($b.Keys | Sort-Object)
    if (-not (Test-StringSequenceEqual -Left $aKeys -Right $bKeys)) { return $false }
    foreach ($key in $aKeys) {
        if (([string]$a[$key]).Trim() -ne ([string]$b[$key]).Trim()) { return $false }
    }
    return $true
}
function Test-GuidInList {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [object[]]$List
    )
    $normalized = $Guid.ToLowerInvariant()
    foreach ($item in @($List)) {
        if ([string]$item -and ([string]$item).ToLowerInvariant() -eq $normalized) { return $true }
    }
    return $false
}
function New-DefaultAppSettingsCore {
    return [pscustomobject]@{
        schemaVersion = 4
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = @{}
    }
}

function ConvertTo-NormalizedAppSettingsCore {
    param($Source)

    if (-not $Source) { return New-DefaultAppSettingsCore }

    return [pscustomobject]@{
        schemaVersion = if ($Source.schemaVersion) { [int]$Source.schemaVersion } else { 1 }
        # defaultGuid is retained only as an upgrade/migration input from
        # v0.2.21 and earlier. v0.2.22 stores the live default system-wide.
        defaultGuid = if ($Source.defaultGuid) { ([string]$Source.defaultGuid).ToLowerInvariant() } else { $null }
        entryOrder = @(
            @($Source.entryOrder) |
                ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } } |
                Select-Object -Unique
        )
        hiddenEntryGuids = @(
            @($Source.hiddenEntryGuids) |
                ForEach-Object { if ($_){ ([string]$_).ToLowerInvariant() } } |
                Select-Object -Unique
        )
        entryAliases = Convert-EntryAliasesToHashtable $Source.entryAliases
    }
}

function Get-OrderedEntriesCore {
    param(
        [object[]]$Source,
        [object[]]$Order,
        [object[]]$Hidden,
        [switch]$IncludeHidden
    )

    $sourceItems = @($Source)
    if ($sourceItems.Count -eq 0) { return @() }

    $result = New-Object System.Collections.Generic.List[object]
    $added = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($guid in @($Order)) {
        if (-not $guid) { continue }
        $entry = $sourceItems | Where-Object { $_.Guid -eq ([string]$guid).ToLowerInvariant() } | Select-Object -First 1
        if ($entry -and $added.Add([string]$entry.Guid)) {
            if ($IncludeHidden -or -not (Test-GuidInList -Guid $entry.Guid -List $Hidden)) {
                [void]$result.Add($entry)
            }
        }
    }

    foreach ($entry in $sourceItems) {
        if ($added.Add([string]$entry.Guid)) {
            if ($IncludeHidden -or -not (Test-GuidInList -Guid $entry.Guid -List $Hidden)) {
                [void]$result.Add($entry)
            }
        }
    }

    return @($result.ToArray())
}






function Test-ManageEntriesDirty {
    if (-not $script:IsManageEntriesMode) { return $false }
    if (-not (Test-StringSequenceEqual -Left $script:ManageEntryOrder -Right $script:ManageBaselineEntryOrder)) { return $true }
    if (-not (Test-StringSequenceEqual -Left $script:ManageHiddenEntryGuids -Right $script:ManageBaselineHiddenEntryGuids -Sort)) { return $true }
    if (-not (Test-EntryAliasMapsEqual -Left $script:ManageEntryAliases -Right $script:ManageBaselineEntryAliases)) { return $true }

    # A still-open alias editor is part of the draft. Reflect its current text
    # immediately so the global save button responds before Enter/Übernehmen.
    if ($script:ManageAliasEditGuid -and $script:Popup -and -not $script:Popup.IsDisposed) {
        $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
        if ($editor -and [string]$editor.Tag) {
            $guid = ([string]$editor.Tag).ToLowerInvariant()
            $current = ([string]$editor.Text).Trim()
            $draft = ''
            if ($script:ManageEntryAliases.ContainsKey($guid)) { $draft = ([string]$script:ManageEntryAliases[$guid]).Trim() }
            if ($current -ne $draft) { return $true }
        }
    }
    return $false
}

function Update-ManageSaveButtonState {
    $button = $script:ManageSaveButton
    if (-not $button -or $button.IsDisposed) { return }
    $dirty = Test-ManageEntriesDirty
    $button.Enabled = $dirty
    if ($dirty) {
        $button.ForeColor = $script:ColorPrimary
        $button.BackColor = $script:ColorAccent
        $button.FlatAppearance.BorderColor = $script:ColorAccent
        $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    else {
        $button.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
        $button.BackColor = [Drawing.Color]::FromArgb(35,35,35)
        $button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
        $button.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}


function Read-AppSettingsRepository {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Write-AppSettingsRepository {
    param(
        [Parameter(Mandatory=$true)][string]$Directory,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Payload
    )

    [void](New-Item -ItemType Directory -Path $Directory -Force)
    $json = $Payload | ConvertTo-Json -Depth 6
    $tmp = $Path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Remove-LegacySessionRestoreMarker {
    param(
        [Parameter(Mandatory=$true)][string]$RegistryPath,
        [Parameter(Mandatory=$true)][string]$ValueName
    )

    try {
        Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
    }
    catch { }
}


function Get-AppSettings {
    try {
        $obj = Read-AppSettingsRepository -Path $script:SettingsPath
        if ($null -eq $obj) {
            return New-DefaultAppSettingsCore
        }
        return ConvertTo-NormalizedAppSettingsCore -Source $obj
    }
    catch {
        return New-DefaultAppSettingsCore
    }
}

function Save-AppSettings {
    $aliases = [ordered]@{}
    foreach ($key in @($script:EntryAliases.Keys | Sort-Object)) {
        $value = ([string]$script:EntryAliases[$key]).Trim()
        if ($key -and $value) { $aliases[[string]$key] = $value }
    }

    $payload = [ordered]@{
        schemaVersion = 4
        # Keep an unmigrated legacy default only until the new SYSTEM-backed
        # default architecture has been installed successfully.
        defaultGuid = $script:LegacyDefaultGuid
        entryOrder = @($script:EntryOrder)
        hiddenEntryGuids = @($script:HiddenEntryGuids)
        # v0.2.27: aliases are user-interface metadata only. Keys are stable
        # firmware GUIDs; no privileged task identity is ever changed.
        entryAliases = $aliases
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $payload
}

function Load-AppSettings {
    $settings = Get-AppSettings
    $script:LegacyDefaultGuid = if ($settings.defaultGuid) { ([string]$settings.defaultGuid).ToLowerInvariant() } else { $null }
    $script:DefaultGuid = $null
    $script:EntryOrder = @($settings.entryOrder)
    $script:HiddenEntryGuids = @($settings.hiddenEntryGuids)
    $script:EntryAliases = Convert-EntryAliasesToHashtable $settings.entryAliases

    # v0.2.21 and earlier used an HKCU Volatile Environment marker for a
    # login-time restore. v0.2.22 no longer uses that mechanism.
    Remove-LegacySessionRestoreMarker -RegistryPath $script:LegacySessionRestoreRegistryPath -ValueName $script:LegacySessionRestoreValueName
}


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

function Set-ManageEntryAliasDraft {
    param(
        [Parameter(Mandatory=$true)][string]$Guid,
        [AllowEmptyString()][string]$Alias
    )
    $normalized = $Guid.ToLowerInvariant()
    $value = if ($null -eq $Alias) { '' } else { ([string]$Alias).Trim() }
    if ($value) {
        $script:ManageEntryAliases[$normalized] = $value
    }
    else {
        [void]$script:ManageEntryAliases.Remove($normalized)
    }
}

function Commit-ActiveManageAliasEditor {
    if (-not $script:ManageAliasEditGuid) { return }
    try {
        if ($script:Popup -and -not $script:Popup.IsDisposed) {
            $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
            if ($editor -and [string]$editor.Tag) {
                Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
            }
        }
    }
    finally {
        $script:ManageAliasEditGuid = $null
    }
}


function Get-OrderedEntriesForUi {
    param(
        [switch]$IncludeHidden,
        [switch]$UseManageDraft
    )

    $order = if ($UseManageDraft) { @($script:ManageEntryOrder) } else { @($script:EntryOrder) }
    $hidden = if ($UseManageDraft) { @($script:ManageHiddenEntryGuids) } else { @($script:HiddenEntryGuids) }
    return @(Get-OrderedEntriesCore -Source @($script:CurrentEntries) -Order $order -Hidden $hidden -IncludeHidden:$IncludeHidden)
}


function Test-ManageEntryHidden {
    param([Parameter(Mandatory=$true)][string]$Guid)
    return (Test-GuidInList -Guid $Guid -List $script:ManageHiddenEntryGuids)
}

function Toggle-ManageEntryVisibility {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $normalized = $Guid.ToLowerInvariant()
    if (Test-ManageEntryHidden -Guid $normalized) {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids | Where-Object { ([string]$_).ToLowerInvariant() -ne $normalized })
    }
    else {
        $script:ManageHiddenEntryGuids = @($script:ManageHiddenEntryGuids) + $normalized
    }
}

function Move-ManageEntry {
    param(
        [Parameter(Mandatory=$true)][string]$MovedGuid,
        [Parameter(Mandatory=$true)][string]$TargetGuid,
        [bool]$After = $false
    )

    $moved = $MovedGuid.ToLowerInvariant()
    $target = $TargetGuid.ToLowerInvariant()
    if ($moved -eq $target) { return }

    $list = New-Object System.Collections.ArrayList
    foreach ($guid in @($script:ManageEntryOrder)) {
        if ([string]$guid -and ([string]$guid).ToLowerInvariant() -ne $moved) {
            [void]$list.Add(([string]$guid).ToLowerInvariant())
        }
    }

    $targetIndex = $list.IndexOf($target)
    if ($targetIndex -lt 0) {
        [void]$list.Add($moved)
    }
    else {
        $insertIndex = $targetIndex + $(if ($After) { 1 } else { 0 })
        if ($insertIndex -gt $list.Count) { $insertIndex = $list.Count }
        $list.Insert($insertIndex, $moved)
    }
    $script:ManageEntryOrder = @($list)
}

function Update-ManageEntriesUiState {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $sectionLabel = $script:Popup.Controls.Find('SectionLabel', $true) | Select-Object -First 1
    $manageButton = $script:Popup.Controls.Find('ManageEntriesButton', $true) | Select-Object -First 1
    $managePanel = $script:Popup.Controls.Find('ManageEntriesPanel', $true) | Select-Object -First 1
    $configSectionPanel = $script:Popup.Controls.Find('ConfigSectionPanel', $true) | Select-Object -First 1
    $settingsPanel = $script:Popup.Controls.Find('SettingsPanel', $true) | Select-Object -First 1
    $defaultPanel = $script:Popup.Controls.Find('DefaultPanel', $true) | Select-Object -First 1
    $settingsDivider = $script:Popup.Controls.Find('SettingsDivider', $true) | Select-Object -First 1
    $restartPanel = $script:Popup.Controls.Find('RestartPanel', $true) | Select-Object -First 1
    $footerPanel = $script:Popup.Controls.Find('FooterPanel', $true) | Select-Object -First 1

    if ($sectionLabel) { $sectionLabel.Text = if ($script:IsManageEntriesMode) { 'STARTZIELE ANPASSEN' } else { 'NÄCHSTER START' } }
    if ($manageButton) {
        $manageButton.Visible = -not $script:IsManageEntriesMode
        $manageButton.Enabled = (-not $script:IsManageEntriesMode -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
    }
    if ($managePanel) {
        $managePanel.Visible = $script:IsManageEntriesMode
        if ($script:IsManageEntriesMode) { $managePanel.BringToFront() }
    }
    foreach ($control in @($configSectionPanel,$settingsPanel,$defaultPanel,$settingsDivider,$restartPanel,$footerPanel)) {
        if ($control) { $control.Visible = -not $script:IsManageEntriesMode }
    }

    if ($script:ManageEntriesMenuItem) {
        $script:ManageEntriesMenuItem.Enabled = (-not $script:IsManageEntriesMode -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
    }
}

function Start-ManageEntriesMode {
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    if ($script:IsManageEntriesMode) { return }
    if ($script:CurrentEntries.Count -eq 0) { return }

    $script:ManageEntryOrder = @((Get-OrderedEntriesForUi -IncludeHidden) | ForEach-Object { $_.Guid })
    $script:ManageHiddenEntryGuids = @($script:HiddenEntryGuids)
    $script:ManageEntryAliases = Copy-EntryAliasMap $script:EntryAliases
    $script:ManageBaselineEntryOrder = @($script:ManageEntryOrder)
    $script:ManageBaselineHiddenEntryGuids = @($script:ManageHiddenEntryGuids)
    $script:ManageBaselineEntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
    $script:ManageAliasEditGuid = $null
    $script:IsManageEntriesMode = $true
    $script:LastStatusText = 'Startziele anpassen · Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden · Stift für Anzeigename'
    Update-ManageEntriesUiState
    Update-PopupRows
    Update-ManageSaveButtonState
}

function Stop-ManageEntriesMode {
    param([switch]$Save)
    if (-not $script:IsManageEntriesMode) { return }

    if ($Save) {
        Commit-ActiveManageAliasEditor
        $script:EntryOrder = @($script:ManageEntryOrder)
        $script:HiddenEntryGuids = @($script:ManageHiddenEntryGuids | Select-Object -Unique)
        $script:EntryAliases = Copy-EntryAliasMap $script:ManageEntryAliases
        Save-AppSettings
        $script:LastStatusText = 'Änderungen an den Startzielen wurden gespeichert.'
    }
    else {
        $script:LastStatusText = 'Änderungen wurden verworfen.'
    }

    $script:IsManageEntriesMode = $false
    $script:ManageEntryOrder = @()
    $script:ManageHiddenEntryGuids = @()
    $script:ManageEntryAliases = @{}
    $script:ManageBaselineEntryOrder = @()
    $script:ManageBaselineHiddenEntryGuids = @()
    $script:ManageBaselineEntryAliases = @{}
    $script:ManageAliasEditGuid = $null
    Update-ManageEntriesUiState
    Update-PopupRows
}


function Get-DefaultEntryTitle {
    if (-not $script:DefaultGuid) { return 'Kein Standardziel' }
    $entry = Get-EntryByGuid $script:DefaultGuid
    if ($entry) { return (Get-EntryDisplayTitle -Entry $entry) }
    return 'Nicht verfügbares Startziel'
}

function Update-DefaultUi {
    if ($script:DefaultButton -and -not $script:DefaultButton.IsDisposed) {
        $meta = Get-TaskBrokerMetadata
        $schemaReady = ($meta -and ($script:SupportedTaskBrokerVersions -contains [string]$meta.version))
        $sessionReady = ($script:TaskBrokerReadyCached -eq $true)
        $enabled = ($schemaReady -and $sessionReady -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
        $script:DefaultButton.Enabled = $enabled
        if ($script:DefaultValueLabel -and -not $script:DefaultValueLabel.IsDisposed) {
            $script:DefaultValueLabel.Text = Get-DefaultEntryTitle
            $script:DefaultValueLabel.ForeColor = if ($enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(110,110,110) }
        }
        foreach ($child in $script:DefaultButton.Controls) {
            try { $child.Enabled = $enabled } catch { }
        }
    }
}


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

function New-DefaultTargetMenu {
    $menu = New-Object LenovoContextMenuStrip
    $menu.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $menu.ForeColor = $script:ColorPrimary
    $menu.Renderer = $script:MenuRenderer
    $menu.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $menu.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $menu.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $menu

    $none = New-Object System.Windows.Forms.ToolStripMenuItem('Kein Standardziel')
    $none.Checked = -not [bool]$script:DefaultGuid
    $none.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
    $none.Add_Click({
        try { Set-DefaultGuid -Guid $null }
        catch { Show-LenovoNoticeDialog -Title 'Standard-Startziel' -Heading 'Das Standard-Startziel konnte nicht gespeichert werden.' -Message 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.' -Kind Error }
    })
    [void]$menu.Items.Add($none)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    foreach ($entry in @(Get-OrderedEntriesForUi)) {
        $item = New-Object System.Windows.Forms.ToolStripMenuItem((Get-EntryDisplayTitle -Entry $entry))
        $item.Tag = $entry.Guid
        $item.Checked = ($script:DefaultGuid -and $entry.Guid -eq $script:DefaultGuid)
        $item.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
        $item.Add_Click({
            try { Set-DefaultGuid -Guid ([string]$this.Tag) }
            catch { Show-LenovoNoticeDialog -Title 'Standard-Startziel' -Heading 'Das Standard-Startziel konnte nicht gespeichert werden.' -Message 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.' -Kind Error }
        })
        [void]$menu.Items.Add($item)
    }
    return $menu
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    try {
        if ($script:DefaultContextMenu) { $script:DefaultContextMenu.Dispose() }
    } catch { }
    $script:DefaultContextMenu = New-DefaultTargetMenu
    $script:DefaultContextMenu.Show($Owner, (New-Object Drawing.Point(0, $Owner.Height)))
}


function Show-LenovoNoticeDialog {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Heading,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Kind = 'Info',
        [string]$SecondaryButtonText,
        [scriptblock]$SecondaryAction
    )

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(470, 245)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $titleLabel = New-Label -Text $Title -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 420 -Height 24
    $root.Controls.Add($titleLabel)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(434,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyphText = if ($Kind -eq 'Error') { '×' } elseif ($Kind -eq 'Warning') { '!' } else { 'i' }
    $glyphColor = if ($Kind -eq 'Error') { $script:ColorAccent } elseif ($Kind -eq 'Warning') { $script:ColorWarning } else { $script:ColorCyan }
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $headingLabel = New-Label -Text $Heading -Font (New-Object Drawing.Font('Segoe UI', 9.6, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 380 -Height 24
    $root.Controls.Add($headingLabel)
    $messageLabel = New-Label -Text $Message -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 88 -Width 380 -Height 78
    $messageLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($messageLabel)

    if (-not [string]::IsNullOrWhiteSpace($SecondaryButtonText) -and $SecondaryAction) {
        $secondary = New-Object System.Windows.Forms.Button
        $secondary.Text = $SecondaryButtonText
        $secondary.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
        $secondary.ForeColor = $script:ColorPrimary
        $secondary.BackColor = [Drawing.Color]::FromArgb(34,34,34)
        $secondary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $secondary.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
        $secondary.FlatAppearance.BorderSize = 1
        $secondary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
        $secondary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(38,38,38)
        $secondary.Location = New-Object Drawing.Point(184,190)
        $secondary.Size = New-Object Drawing.Size(146,34)
        $secondary.Cursor = [System.Windows.Forms.Cursors]::Hand
        $secondaryActionLocal = $SecondaryAction
        $dialogLocal = $form
        $secondary.Add_Click({
            param($sender,$eventArgs)
            try {
                $result = & $secondaryActionLocal
                if ($result -ne $false) {
                    $dialogLocal.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $dialogLocal.Close()
                }
            } catch { }
        }.GetNewClosure())
        $root.Controls.Add($secondary)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $ok.ForeColor = [Drawing.Color]::White
    $ok.BackColor = $script:ColorAccent
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderSize = 0
    $ok.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $ok.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $ok.Location = New-Object Drawing.Point(342,190)
    $ok.Size = New-Object Drawing.Size(110,34)
    $ok.Cursor = [System.Windows.Forms.Cursors]::Hand
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $root.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $ok
    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { [void]$form.ShowDialog($owner) } else { [void]$form.ShowDialog() }
    }
    finally { $form.Dispose() }
}

function Show-LenovoSystemFunctionsDialog {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)

    $isRemove = ($Mode -eq 'Remove')
    $height = if ($isRemove) { 330 } else { 270 }
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, $height)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    if ($Mode -eq 'Remove') {
        $titleText = 'Systemfunktionen entfernen'
        $headingText = 'Systemfunktionen wirklich entfernen?'
        $bodyText = "Danach kann Lenovo Boot Selector keine Startziele mehr ändern, bis die Einrichtung erneut durchgeführt wird.`r`n`r`nDas gespeicherte Standard-Startziel wird zurückgesetzt.`r`n`r`nErhalten bleiben deine vorhandenen Startziele, persönlichen App-Einstellungen und die Autostart-Einstellung."
        $primaryText = 'Entfernen'
        $glyphText = '!'
        $glyphColor = $script:ColorWarning
    }
    elseif ($Mode -eq 'Repair') {
        $titleText = 'Systemfunktionen reparieren'
        $headingText = 'Die Systemfunktionen sind bereits eingerichtet.'
        $bodyText = 'Möchtest du sie erneut einrichten und reparieren? Deine Startziele und persönlichen Einstellungen bleiben dabei erhalten.'
        $primaryText = 'Reparieren'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Migrate') {
        $titleText = 'Systemfunktionen reparieren'
        $headingText = 'Die Einrichtung muss aktualisiert werden.'
        $bodyText = 'Eine ältere oder unvollständige Einrichtung wurde gefunden. Repariere sie, damit Startziele wieder zuverlässig geändert werden können.'
        $primaryText = 'Reparieren'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Reinitialize') {
        $titleText = 'Systemfunktionen neu initialisieren'
        $headingText = 'Neues Startziel erkannt'
        $bodyText = 'Lenovo Boot Selector hat eine Änderung an den verfügbaren Startzielen erkannt. Initialisiere die Systemfunktionen neu, damit das neue Startziel sicher verwendet werden kann. Deine persönlichen Einstellungen bleiben erhalten.'
        $primaryText = 'Neu initialisieren'
        $glyphText = '+'
        $glyphColor = $script:ColorCyan
    }
    else {
        $titleText = 'Systemfunktionen einrichten'
        $headingText = 'Einmalige Einrichtung erforderlich'
        $bodyText = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich. Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
        $primaryText = 'Einrichten'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }

    $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI',15.0,[Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)
    $heading = New-Label -Text $headingText -Font (New-Object Drawing.Font('Segoe UI',9.6,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 410 -Height 24
    $root.Controls.Add($heading)
    $bodyHeight = if ($isRemove) { 145 } else { 90 }
    $body = New-Label -Text $bodyText -Font (New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 90 -Width 410 -Height $bodyHeight
    $body.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($body)

    $buttonY = $height - 54
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Abbrechen'
    $cancel.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.Location = New-Object Drawing.Point(272,$buttonY)
    $cancel.Size = New-Object Drawing.Size(100,34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $primary = New-Object System.Windows.Forms.Button
    $primary.Text = $primaryText
    $primary.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Bold)
    $primary.ForeColor = [Drawing.Color]::White
    $primary.BackColor = $script:ColorAccent
    $primary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $primary.FlatAppearance.BorderSize = 0
    $primary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $primary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $primary.Location = New-Object Drawing.Point(382,$buttonY)
    $primary.Size = New-Object Drawing.Size(100,34)
    $primary.Cursor = [System.Windows.Forms.Cursors]::Hand
    $primary.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($primary)
    $form.AcceptButton = $primary
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally { $form.Dispose() }
}

function Show-LenovoRestartDialog {
    param([Parameter(Mandatory=$true)][string]$TargetName)

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.ClientSize = New-Object Drawing.Size(430, 240)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'RestartDialogRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(430, 240)
    $root.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.Controls.Add($root)

    $title = New-Label -Text 'Windows neu starten' -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 330 -Height 24
    $root.Controls.Add($title)

    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18, 43)
    $divider.Size = New-Object Drawing.Size(390, 1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyph = New-Label -Text '!' -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorWarning -X 18 -Y 58 -Width 26 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $question = New-Label -Text 'Windows jetzt neu starten?' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 58 -Width 340 -Height 24
    $root.Controls.Add($question)

    $targetCaption = New-Label -Text 'NÄCHSTES ZIEL' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 54 -Y 92 -Width 330 -Height 18
    $root.Controls.Add($targetCaption)

    $target = New-Label -Text $TargetName -Font (New-Object Drawing.Font('Segoe UI', 9.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 109 -Width 342 -Height 24
    $target.AutoEllipsis = $true
    $root.Controls.Add($target)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Abbrechen'
    $cancel.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(28,28,28)
    $cancel.Location = New-Object Drawing.Point(206, 180)
    $cancel.Size = New-Object Drawing.Size(96, 34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $restart = New-Object System.Windows.Forms.Button
    $restart.Text = 'Neu starten'
    $restart.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $restart.ForeColor = [Drawing.Color]::White
    $restart.BackColor = $script:ColorAccent
    $restart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restart.FlatAppearance.BorderColor = $script:ColorAccent
    $restart.FlatAppearance.BorderSize = 1
    $restart.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $restart.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $restart.Location = New-Object Drawing.Point(312, 180)
    $restart.Size = New-Object Drawing.Size(96, 34)
    $restart.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restart.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($restart)

    $form.AcceptButton = $restart
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally {
        $form.Dispose()
    }
}


function Test-MaintenanceBusy {
    return (Test-MaintenanceRuntimeBusy -State $script:MaintenanceState)
}

function Get-MaintenanceMode {
    return (Get-MaintenanceRuntimeMode -State $script:MaintenanceState)
}

function Get-SystemFunctionsPresentationState {
    if (Test-MaintenanceBusy) {
        return ('Busy-' + (Get-MaintenanceMode))
    }
    if (Get-TaskBrokerInteractiveReady) {
        if (Test-BootTargetDriftDetected) { return 'ReinitializeRequired' }
        return 'Ready'
    }
    if (Test-TaskBrokerInstallationPresent) { return 'RepairRequired' }
    return 'SetupRequired'
}

function Get-MaintenanceBusyStatusText {
    $mode = Get-MaintenanceMode
    if ($mode -eq 'Remove') { return 'Systemfunktionen werden entfernt…' }
    if ($mode -eq 'Reinitialize') { return 'Systemfunktionen werden neu initialisiert…' }
    if ($mode -eq 'Repair' -or $mode -eq 'Migrate') { return 'Systemfunktionen werden repariert…' }
    return 'Systemfunktionen werden eingerichtet…'
}

function New-MaintenanceStatePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Name = 'MaintenanceStatePanel'
    $panel.Location = New-Object Drawing.Point(0, 60)
    $panel.Size = New-Object Drawing.Size(390, 592)
    $panel.BackColor = $script:ColorBackground
    $panel.Visible = $false

    $caption = New-Label -Text 'SYSTEMFUNKTIONEN' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 106 -Width 358 -Height 18
    $caption.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($caption)

    $glyph = New-Label -Text '⚙' -Font (New-Object Drawing.Font('Segoe UI Symbol', 24.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorAccent -X 166 -Y 134 -Width 58 -Height 58
    $glyph.Name = 'MaintenanceGlyph'
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($glyph)

    $heading = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 11.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 32 -Y 204 -Width 326 -Height 30
    $heading.Name = 'MaintenanceHeading'
    $heading.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($heading)

    $message = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 42 -Y 244 -Width 306 -Height 72
    $message.Name = 'MaintenanceMessage'
    $message.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($message)

    $action = New-Object System.Windows.Forms.Button
    $action.Name = 'MaintenancePrimaryButton'
    $action.Text = 'Systemfunktionen einrichten'
    $action.Font = New-Object Drawing.Font('Segoe UI', 8.7, [Drawing.FontStyle]::Bold)
    $action.ForeColor = [Drawing.Color]::White
    $action.BackColor = $script:ColorAccent
    $action.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $action.FlatAppearance.BorderSize = 0
    $action.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $action.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $action.Location = New-Object Drawing.Point(55, 334)
    $action.Size = New-Object Drawing.Size(280, 38)
    $action.Cursor = [System.Windows.Forms.Cursors]::Hand
    $action.Add_Click({
        if (Test-MaintenanceBusy) { return }
        if ((Get-SystemFunctionsPresentationState) -eq 'ReinitializeRequired') {
            Prompt-TaskBrokerReinitialize
            return
        }
        Prompt-TaskBrokerInstall
    })
    $panel.Controls.Add($action)

    $hint = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 7.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 42 -Y 388 -Width 306 -Height 52
    $hint.Name = 'MaintenanceHint'
    $hint.TextAlign = [Drawing.ContentAlignment]::TopCenter
    $panel.Controls.Add($hint)

    return $panel
}

function Update-MaintenanceUi {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    $state = Get-SystemFunctionsPresentationState
    $busy = $state.StartsWith('Busy-')
    $ready = ($state -eq 'Ready')

    $panelMatches = $script:Popup.Controls.Find('MaintenanceStatePanel', $true)
    $panel = if ($panelMatches.Count -gt 0) { $panelMatches[0] } else { $null }
    if ($panel) {
        $heading = $panel.Controls['MaintenanceHeading']
        $message = $panel.Controls['MaintenanceMessage']
        $action = $panel.Controls['MaintenancePrimaryButton']
        $hint = $panel.Controls['MaintenanceHint']
        $glyph = $panel.Controls['MaintenanceGlyph']

        if ($ready) {
            $panel.Visible = $false
        }
        else {
            $panel.Visible = $true
            $panel.BringToFront()
            if ($state -eq 'SetupRequired') {
                $glyph.Text = '⚙'
                $glyph.ForeColor = $script:ColorAccent
                $heading.Text = 'Systemfunktionen einrichten'
                $message.Text = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich.'
                $action.Text = 'Systemfunktionen einrichten'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
            }
            elseif ($state -eq 'RepairRequired') {
                $glyph.Text = '!'
                $glyph.ForeColor = $script:ColorWarning
                $heading.Text = 'Systemfunktionen reparieren'
                $message.Text = 'Die vorhandene Einrichtung ist unvollständig oder muss aktualisiert werden.'
                $action.Text = 'Systemfunktionen reparieren'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Deine persönlichen Einstellungen bleiben dabei erhalten.'
            }
            elseif ($state -eq 'ReinitializeRequired') {
                $glyph.Text = '+'
                $glyph.ForeColor = $script:ColorCyan
                if (Test-BootTargetDriftHasNewTargets) {
                    $heading.Text = 'Neues Startziel erkannt'
                    $message.Text = 'Lenovo Boot Selector hat ein neues Startziel erkannt. Initialisiere die Systemfunktionen neu, damit es sicher verwendet werden kann.'
                }
                else {
                    $heading.Text = 'Startziele wurden geändert'
                    $message.Text = 'Die verfügbaren Startziele haben sich geändert. Initialisiere die Systemfunktionen neu, damit die Auswahl wieder vollständig passt.'
                }
                $action.Text = 'Systemfunktionen neu initialisieren'
                $action.Visible = $true
                $action.Enabled = $true
                $hint.Text = 'Deine persönlichen Einstellungen bleiben dabei erhalten.'
            }
            else {
                $mode = Get-MaintenanceMode
                $glyph.Text = '…'
                $glyph.ForeColor = $script:ColorCyan
                $heading.Text = if ($mode -eq 'Remove') { 'Systemfunktionen werden entfernt…' } elseif ($mode -eq 'Reinitialize') { 'Systemfunktionen werden neu initialisiert…' } elseif ($mode -eq 'Repair' -or $mode -eq 'Migrate') { 'Systemfunktionen werden repariert…' } else { 'Systemfunktionen werden eingerichtet…' }
                $message.Text = if ($mode -eq 'Remove') { 'Die Systemfunktionen werden sicher entfernt. Bitte warte einen Moment.' } elseif ($mode -eq 'Reinitialize') { 'Windows richtet die Systemfunktionen für die geänderten Startziele neu ein. Bitte warte einen Moment.' } else { 'Windows richtet die benötigten Systemfunktionen ein. Bitte warte einen Moment.' }
                $action.Visible = $false
                $action.Enabled = $false
                $hint.Text = 'Die App wird nach Abschluss automatisch aktualisiert.'
            }
        }
    }

    if ($script:RefreshButton -and -not $script:RefreshButton.IsDisposed) {
        $script:RefreshButton.Enabled = ($ready -and -not $busy)
        $script:RefreshButton.Cursor = if ($script:RefreshButton.Enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }
    }
    if ($script:ManageEntriesButton -and -not $script:ManageEntriesButton.IsDisposed) {
        $script:ManageEntriesButton.Enabled = ($ready -and -not $busy)
    }
    if ($script:DefaultContextRoot) { $script:DefaultContextRoot.Enabled = ($ready -and -not $busy) }
    if ($script:RestartMenuItem) { $script:RestartMenuItem.Enabled = -not $busy }

    Update-HeaderRefreshStatus
}

function Show-MaintenanceSuccessDialog {
    param([Parameter(Mandatory=$true)][ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)
    if ($Mode -eq 'Remove') {
        Show-LenovoNoticeDialog -Title 'Systemfunktionen entfernt' -Heading 'Systemfunktionen wurden entfernt.' -Message 'Startziele können wieder geändert werden, nachdem du die Systemfunktionen erneut eingerichtet hast.' -Kind Info
        return
    }
    if ($Mode -eq 'Reinitialize') {
        Show-LenovoNoticeDialog -Title 'Neu initialisiert' -Heading 'Systemfunktionen wurden neu initialisiert.' -Message 'Das erkannte Startziel kann jetzt sicher verwendet werden.' -Kind Info
        return
    }
    Show-LenovoNoticeDialog -Title 'Systemfunktionen bereit' -Heading 'Systemfunktionen sind bereit.' -Message 'Lenovo Boot Selector kann jetzt Startziele ändern.' -Kind Info
}


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

function Get-TaskBrokerMetadata {
    if ($script:TaskBrokerMetadata) { return $script:TaskBrokerMetadata }
    if (-not (Test-Path -LiteralPath $script:TaskBrokerMetadataPath)) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText($script:TaskBrokerMetadataPath, [System.Text.Encoding]::UTF8)
        $meta = $text | ConvertFrom-Json
        $script:TaskBrokerMetadata = $meta
        return $meta
    }
    catch { return $null }
}

function Get-TaskBrokerTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { return $null }
    $normalized = $Guid.ToLowerInvariant()
    foreach ($target in @($meta.targets)) {
        if ([string]$target.guid -and ([string]$target.guid).ToLowerInvariant() -eq $normalized) {
            return $target
        }
    }
    return $null
}

function Invoke-AuthorizedTask {
    param(
        [Parameter(Mandatory=$true)][string]$TaskName,
        [int]$TimeoutMs = $script:TaskBrokerTimeoutMs
    )

    $started = [datetime]::Now
    $diagSw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # IMPORTANT: exact-task access is retained; root enumeration is deliberately avoided.
        try {
            $scheduleService = New-Object -ComObject 'Schedule.Service'
            $scheduleService.Connect()
            $taskFolder = $scheduleService.GetFolder('\')
            $registeredTask = $taskFolder.GetTask("\$TaskName")
            if (-not $registeredTask) { throw 'Aufgabe nicht gefunden.' }
        }
        catch {
            throw "Die autorisierte Windows-Aufgabe '$TaskName' ist für den aktuellen Benutzer nicht lesbar: $($_.Exception.Message)"
        }

        try { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop }
        catch { throw "Die autorisierte Windows-Aufgabe '$TaskName' konnte nicht gestartet werden: $($_.Exception.Message)" }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds 75
            try {
                $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
                $registeredTask = $taskFolder.GetTask("\$TaskName")
                $state = [int]$registeredTask.State
            }
            catch {
                throw "Der Status der autorisierten Windows-Aufgabe '$TaskName' konnte nicht gelesen werden: $($_.Exception.Message)"
            }

            $recent = ($info.LastRunTime -ge $started.AddSeconds(-2))
            $result = [uint32]$info.LastTaskResult
            $isTransientResult = ($result -eq 0x00041301 -or $result -eq 0x00041325)
            if ($recent -and ($state -eq 4 -or $isTransientResult)) { continue }

            if ($recent -and $state -ne 4) {
                if ($result -ne 0) {
                    throw ("Die autorisierte Windows-Aufgabe '{0}' ist mit 0x{1:X8} ({2}) fehlgeschlagen." -f $TaskName,$result,$result)
                }
                $diagSw.Stop()
                Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $true -DurationMs $diagSw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ taskName = $TaskName; lastTaskResult = [uint32]$result; state = $state })
                return $info
            }
        } while ($sw.ElapsedMilliseconds -lt $TimeoutMs)

        throw "Zeitüberschreitung beim Warten auf die autorisierte Windows-Aufgabe '$TaskName'."
    }
    catch {
        $diagSw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'AUTHORIZED_TASK' -Stage 'task' -Success $false -DurationMs $diagSw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ taskName = $TaskName; timeoutMs = $TimeoutMs }) -Level error
        throw
    }
}

function Read-TaskBrokerTextFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Statusdatei fehlt: $Path"
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Refresh-ManagerCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:ManagerCacheText -and (([datetime]::UtcNow - $script:ManagerCacheUtc).TotalMilliseconds -lt 750)) {
        return $script:ManagerCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -TaskName ([string]$meta.managerRefreshTask) | Out-Null
        $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
        $script:ManagerCacheUtc = [datetime]::UtcNow
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:ManagerCacheText.Length })
        return $script:ManagerCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'MANAGER_REFRESH' -Stage 'manager-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}

function Refresh-FirmwareCache {
    param([switch]$Force)
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'Die Systemfunktionen sind nicht eingerichtet.' }

    if (-not $Force -and $script:FirmwareCacheText -and (([datetime]::UtcNow - $script:FirmwareCacheUtc).TotalSeconds -lt 30)) {
        return $script:FirmwareCacheText
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-AuthorizedTask -TaskName ([string]$meta.firmwareRefreshTask) | Out-Null
        $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
        $script:FirmwareCacheUtc = [datetime]::UtcNow
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $true -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; bytes = $script:FirmwareCacheText.Length })
        return $script:FirmwareCacheText
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'FIRMWARE_REFRESH' -Stage 'firmware-refresh' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force }) -Level error
        throw
    }
}

function Test-TaskBrokerMetadataCompatible {
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { return $false }
        if ($script:SupportedTaskBrokerVersions -notcontains [string]$meta.version) { return $false }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { return $false }
        if (-not [string]$meta.managerRefreshTask -or -not [string]$meta.firmwareRefreshTask -or
            -not [string]$meta.managerFile -or -not [string]$meta.firmwareFile -or
            -not [string]$meta.defaultFile -or -not [string]$meta.defaultClearTask -or -not [string]$meta.defaultRestoreTask) { return $false }
        foreach ($target in @($meta.targets)) {
            if (-not [string]$target.guid -or -not [string]$target.taskName -or -not [string]$target.defaultTaskName) { return $false }
        }
        return $true
    }
    catch { return $false }
}

function Get-TaskBrokerInteractiveReady {
    if ($null -ne $script:TaskBrokerReadyCached) { return [bool]$script:TaskBrokerReadyCached }
    return (Test-TaskBrokerMetadataCompatible)
}

function Reset-TaskBrokerReadyCache {
    $script:TaskBrokerReadyCached = $null
    $script:TaskBrokerReadyCachedUtc = [datetime]::MinValue
}

function Test-TaskBrokerReady {
    param([switch]$Force)

    if (-not $Force -and $null -ne $script:TaskBrokerReadyCached) {
        return [bool]$script:TaskBrokerReadyCached
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    $failure = $null
    $requiredCount = 0
    $failedTask = $null
    try {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if ($script:SupportedTaskBrokerVersions -notcontains [string]$meta.version) { throw 'Nicht unterstützte TaskBroker-Version.' }
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ([string]$meta.userSid -ne $sid) { throw 'TaskBroker ist nicht für den aktuellen Benutzer autorisiert.' }
        if (-not [string]$meta.defaultFile -or -not [string]$meta.defaultClearTask -or -not [string]$meta.defaultRestoreTask) { throw 'TaskBroker-Metadaten sind unvollständig.' }

        $required = @([string]$meta.managerRefreshTask,[string]$meta.firmwareRefreshTask,[string]$meta.defaultClearTask,[string]$meta.defaultRestoreTask)
        foreach ($target in @($meta.targets)) {
            if (-not [string]$target.guid -or -not [string]$target.taskName -or -not [string]$target.defaultTaskName) { throw 'TaskBroker-Zielmetadaten sind unvollständig.' }
            $required += [string]$target.taskName
            $required += [string]$target.defaultTaskName
        }
        $requiredCount = @($required).Count
        foreach ($name in $required) {
            if (-not $name) { throw 'Taskname fehlt.' }
            $failedTask = $name
            [void](Get-ScheduledTaskInfo -TaskName $name -ErrorAction Stop)
        }
        $failedTask = $null
        $ready = $true
    }
    catch {
        $failure = $_
        $ready = $false
    }

    $sw.Stop()
    Write-RuntimeDiagnosticEvent -Event 'TASKBROKER_READY_CHECK' -Stage 'ready' -Success $ready -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $failure -Data (New-RuntimeDiagnosticData @{ force = [bool]$Force; requiredTaskCount = $requiredCount; failedTask = $failedTask; brokerPresent = [bool](Test-TaskBrokerInstallationPresent) }) -Level $(if ($ready) { 'info' } else { 'error' })
    $script:TaskBrokerReadyCached = $ready
    $script:TaskBrokerReadyCachedUtc = [datetime]::UtcNow
    return $ready
}

function Test-TaskBrokerInstallationPresent {
    if (Test-Path -LiteralPath $script:TaskBrokerMetadataPath) { return $true }
    return $false
}

function Get-LatestTaskBrokerDiagnosticPath {
    $diagPointer = Join-Path $script:TaskBrokerLocalDir 'latest-install-diagnostic.txt'
    if (Test-Path -LiteralPath $diagPointer) {
        try { return ([System.IO.File]::ReadAllText($diagPointer)).Trim() } catch { }
    }
    return ''
}

function Get-TaskBrokerFirmwareManagerText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:ManagerCacheText) {
            $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
            try { $script:ManagerCacheUtc = (Get-Item -LiteralPath ([string]$meta.managerFile)).LastWriteTimeUtc } catch { }
        }
        return $script:ManagerCacheText
    }

    return (Refresh-ManagerCache -Force:$Force)
}

function Get-TaskBrokerFirmwareEntriesText {
    param(
        [switch]$Force,
        [switch]$UseExistingCache
    )

    if ($UseExistingCache) {
        $meta = Get-TaskBrokerMetadata
        if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
        if (-not $script:FirmwareCacheText) {
            $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
            try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc } catch { }
        }
        return $script:FirmwareCacheText
    }

    return (Refresh-FirmwareCache -Force:$Force)
}

function Sync-TaskBrokerFirmwareCachesFromFiles {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'TaskBroker-Metadaten fehlen nach dem Hintergrund-Refresh.' }

    $script:ManagerCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.managerFile)
    $script:ManagerCacheUtc = [datetime]::UtcNow
    $script:FirmwareCacheText = Read-TaskBrokerTextFile -Path ([string]$meta.firmwareFile)
    try { $script:FirmwareCacheUtc = (Get-Item -LiteralPath ([string]$meta.firmwareFile)).LastWriteTimeUtc }
    catch { $script:FirmwareCacheUtc = [datetime]::UtcNow }

    [pscustomobject]@{
        ManagerText = $script:ManagerCacheText
        FirmwareText = $script:FirmwareCacheText
    }
}

function Get-TaskBrokerDefaultTargetGuid {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta -or -not [string]$meta.defaultFile) { return $null }

    $path = [string]$meta.defaultFile
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    $candidate = ([System.IO.File]::ReadAllText($path)).Trim().ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $candidate
    if ($target) { return $candidate }
    return $null
}

function Set-TaskBrokerBootNextTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = $Guid.ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $normalized
    if (-not $target -or -not [string]$target.taskName) {
        throw "Für dieses Firmware-Ziel ist keine vorab autorisierte Windows-Aufgabe vorhanden: $normalized"
    }

    Invoke-AuthorizedTask -TaskName ([string]$target.taskName) | Out-Null
    return (Get-TaskBrokerFirmwareManagerText -Force)
}

function Set-TaskBrokerDefaultTarget {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = $Guid.ToLowerInvariant()
    $target = Get-TaskBrokerTarget -Guid $normalized
    if (-not $target -or -not [string]$target.defaultTaskName) {
        throw 'Für dieses Firmwareziel existiert keine autorisierte Standardziel-Aufgabe.'
    }

    Invoke-AuthorizedTask -TaskName ([string]$target.defaultTaskName) | Out-Null
}

function Clear-TaskBrokerDefaultTarget {
    $meta = Get-TaskBrokerMetadata
    if (-not $meta) { throw 'TaskBroker-Metadaten fehlen.' }
    if (-not [string]$meta.defaultClearTask) { throw 'Die autorisierte Aufgabe zum Deaktivieren des Standardziels fehlt.' }
    Invoke-AuthorizedTask -TaskName ([string]$meta.defaultClearTask) | Out-Null
}


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

function Test-PartitionBootStructure {
    param(
        [Parameter(Mandatory=$true)]$Disk,
        [Parameter(Mandatory=$true)][object[]]$Partitions
    )

    $hasEfiSystemPartition = $false
    $hasActiveFatPartition = $false

    foreach ($partition in $Partitions) {
        $gptType = ([string]$partition.GptType).Trim().Trim([char[]]'{}').ToLowerInvariant()
        if ($gptType -eq 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b') {
            $hasEfiSystemPartition = $true
        }

        if (([string]$Disk.PartitionStyle -eq 'MBR') -and ($partition.IsActive -eq $true)) {
            $partitionType = [string]$partition.Type
            $mbrType = [string]$partition.MbrType
            if (($partitionType -match '(?i)FAT32') -or ($mbrType -eq '11') -or ($mbrType -eq '12')) {
                $hasActiveFatPartition = $true
            }
        }
    }

    [pscustomobject]@{
        HasEfiSystemPartition = $hasEfiSystemPartition
        HasActiveFatPartition = $hasActiveFatPartition
        HasBootStructure = ($hasEfiSystemPartition -or $hasActiveFatPartition)
    }
}
function Get-StorageContextCore {
    # Performance-critical path: resolve storage from Get-Disk/Get-Partition only.
    # v0.2.0 queried every present DiskDrive PnP node plus Parent/LocationPaths
    # synchronously on the WinForms UI thread. On the target ThinkPad this could
    # take ~20 seconds and blocked both left-click and the tray context menu.
    # PnP enrichment is intentionally not part of the interactive refresh path.
    $inventory = @()

    try {
        $disks = @(Get-Disk -ErrorAction Stop)
    }
    catch {
        return [pscustomobject]@{
            Disks = @()
            UsbDisks = @()
            UsbBootCandidates = @()
            ResolvedUsbHdd = $null
            UsbResolution = 'Unavailable'
            UsbResolutionReason = 'Speichergeräte konnten nicht gelesen werden.'
        }
    }

    foreach ($disk in $disks) {
        $partitions = @()
        try {
            $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction Stop)
        }
        catch { }

        $bootStructure = Test-PartitionBootStructure -Disk $disk -Partitions $partitions

        $model = ([string]$disk.FriendlyName).Trim()
        if (-not $model) { $model = "Datenträger $($disk.Number)" }

        $inventory += [pscustomobject]@{
            Number = $disk.Number
            Model = $model
            SerialNumber = ([string]$disk.SerialNumber).Trim()
            BusType = [string]$disk.BusType
            PartitionStyle = [string]$disk.PartitionStyle
            Path = [string]$disk.Path
            IsBootCandidate = [bool]$bootStructure.HasBootStructure
            HasEfiSystemPartition = [bool]$bootStructure.HasEfiSystemPartition
            HasActiveFatPartition = [bool]$bootStructure.HasActiveFatPartition
            PnpInstanceId = $null
            PnpParent = $null
            PnpLocationPaths = @()
        }
    }

    $usbDisks = @($inventory | Where-Object { $_.BusType -eq 'USB' })
    $usbBootCandidates = @($usbDisks | Where-Object { $_.IsBootCandidate })
    $resolvedUsbHdd = $null
    $resolution = 'Ambiguous'
    $reason = 'Mehrere mögliche USB-Laufwerke erkannt.'

    if ($usbBootCandidates.Count -eq 1) {
        $resolvedUsbHdd = $usbBootCandidates[0]
        $resolution = 'Candidate'
        $reason = 'Genau ein aktuelles USB-Laufwerk besitzt eine erkannte Bootstruktur. Der Lenovo-Eintrag USB HDD ist jedoch generisch; die physische Zuordnung wird erst durch den Boottest bestätigt.'
    }
    elseif ($usbBootCandidates.Count -gt 1) {
        $resolution = 'Ambiguous'
        $reason = "$($usbBootCandidates.Count) USB-Laufwerke besitzen eine erkannte Bootstruktur."
    }
    elseif ($usbDisks.Count -eq 1) {
        $resolvedUsbHdd = $usbDisks[0]
        $resolution = 'Medium'
        $reason = 'Nur ein aktuelles USB-Laufwerk ist angeschlossen; eine Bootstruktur konnte jedoch nicht bestätigt werden.'
    }
    elseif ($usbDisks.Count -eq 0) {
        $resolution = 'None'
        $reason = 'Kein aktuelles USB-Speicherlaufwerk erkannt.'
    }

    [pscustomobject]@{
        Disks = @($inventory)
        UsbDisks = @($usbDisks)
        UsbBootCandidates = @($usbBootCandidates)
        ResolvedUsbHdd = $resolvedUsbHdd
        UsbResolution = $resolution
        UsbResolutionReason = $reason
    }
}
function Get-StorageContext {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = Get-StorageContextCore
        $sw.Stop()
        $storageSuccess = ([string]$result.UsbResolution -ne 'Unavailable')
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $storageSuccess -DurationMs $sw.ElapsedMilliseconds -Data (New-RuntimeDiagnosticData @{
            diskCount = @($result.Disks).Count
            usbDiskCount = @($result.UsbDisks).Count
            usbBootCandidateCount = @($result.UsbBootCandidates).Count
            resolution = [string]$result.UsbResolution
        }) -Level $(if ($storageSuccess) { 'info' } else { 'warning' })
        return $result
    }
    catch {
        $sw.Stop()
        Write-RuntimeDiagnosticEvent -Event 'STORAGE_RESOLUTION' -Stage 'storage' -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorRecord $_ -Level error
        throw
    }
}


# Lenovo Boot Selector v0.4.1 - Functional Core: friendly boot-target model
# Presentation-neutral: returns an AccentRole token instead of a UI-specific color object.

function Get-FriendlyBootEntryCore {
    param(
        [string]$Guid,
        [string]$RawDescription,
        $StorageContext
    )

    $description = if ($RawDescription) { $RawDescription.Trim() } else { 'Weiteres Startziel' }
    $title = $description
    $subtitle = 'Weiteres Startziel'
    $accentRole = 'Secondary'
    $symbol = '●'
    $typeTooltip = 'Grau: weiteres Startziel'

    # The current target ThinkPad has NVMe0 confirmed as the populated internal slot.
    # A single read-only NVMe disk can therefore enrich NVMe0 and implies an empty NVMe1.
    # Do not guess NVMe0/NVMe1 physical mapping when multiple NVMe disks are present.
    $nvmeDisks = @()
    if ($StorageContext -and $null -ne $StorageContext.Disks) {
        $nvmeDisks = @($StorageContext.Disks | Where-Object { [string]$_.BusType -eq 'NVMe' })
    }

    switch -Regex ($description) {
        '^Boot Menu$' {
            $title = 'Lenovo Boot-Menü'
            $subtitle = 'Beim nächsten Start das Boot-Menü öffnen'
            $accentRole = 'Accent'
            $typeTooltip = 'Rot: Lenovo Boot-Menü'
            break
        }
        '^NVMe0$' {
            $title = 'NVMe-SSD 1'
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = 'Interne SSD: ' + [string]$nvmeDisks[0].Model
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            else {
                $subtitle = 'Interne SSD'
            }
            $accentRole = 'Blue'
            $typeTooltip = 'Blau: interne SSD'
            break
        }
        '^NVMe1$' {
            $title = 'NVMe-SSD 2'
            if ($StorageContext -and $nvmeDisks.Count -eq 1) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            elseif ($StorageContext -and $nvmeDisks.Count -eq 0) {
                $subtitle = 'Kein Laufwerk erkannt'
            }
            else {
                $subtitle = 'Zweite interne SSD'
            }
            $accentRole = 'Blue'
            $typeTooltip = 'Blau: interne SSD'
            break
        }
        '^USB HDD$' {
            # USB HDD is the actual firmware target. Physical storage identity is
            # presented only as read-only context and must never replace the target title.
            $title = 'USB HDD'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'

            if (-not $StorageContext) {
                $subtitle = 'USB-Laufwerke werden geprüft …'
            }
            elseif ($StorageContext.UsbResolution -eq 'Unavailable') {
                $subtitle = 'USB-Laufwerke konnten nicht geprüft werden'
            }
            elseif ($StorageContext.UsbBootCandidates.Count -eq 1) {
                $candidate = $StorageContext.UsbBootCandidates[0]
                $subtitle = 'USB-Startmedium: ' + [string]$candidate.Model
            }
            elseif ($StorageContext.UsbBootCandidates.Count -gt 1) {
                $subtitle = 'Mehrere mögliche USB-Startmedien erkannt'
            }
            elseif ($StorageContext.UsbDisks.Count -eq 1) {
                $medium = $StorageContext.UsbDisks[0]
                $subtitle = ([string]$medium.Model) + ' erkannt · nicht als Startmedium erkannt'
            }
            elseif ($StorageContext.UsbDisks.Count -gt 1) {
                $subtitle = 'USB-Laufwerke erkannt · kein Startmedium gefunden'
            }
            elseif ($StorageContext.UsbDisks.Count -eq 0) {
                $subtitle = 'Kein USB-Laufwerk angeschlossen'
            }
            else {
                $subtitle = 'USB-Laufwerke konnten nicht geprüft werden'
            }
            break
        }
        '^USB FDD$' {
            $title = 'USB-Diskettenlaufwerk'
            $subtitle = 'Start von einem USB-Floppy-Laufwerk'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'
            break
        }
        '^USB CD$' {
            $title = 'USB-CD/DVD-Laufwerk'
            $subtitle = 'Start von einem optischen USB-Laufwerk'
            $accentRole = 'Warning'
            $typeTooltip = 'Gelb: USB-Laufwerk'
            break
        }
        '^PXE BOOT$' {
            $title = 'Netzwerkstart'
            $subtitle = 'Start über das lokale Netzwerk'
            $accentRole = 'Purple'
            $typeTooltip = 'Violett: Netzwerkstart'
            break
        }
        '^LENOVO CLOUD$' {
            $title = 'Lenovo Wiederherstellung'
            $subtitle = 'Wiederherstellung über das Netzwerk'
            $accentRole = 'Cyan'
            $typeTooltip = 'Cyan: Lenovo- oder Firmen-Netzwerk'
            break
        }
        '^ON-PREMISE$' {
            $title = 'Firmen-Netzwerkstart'
            $subtitle = 'Start über das Firmennetzwerk'
            $accentRole = 'Cyan'
            $typeTooltip = 'Cyan: Lenovo- oder Firmen-Netzwerk'
            break
        }
        '^Other HDD$' {
            $title = 'Weiteres Laufwerk'
            $subtitle = 'Weiteres erkanntes Laufwerk'
            $accentRole = 'Secondary'
            $typeTooltip = 'Grau: weiteres Laufwerk'
            break
        }
        '^Other CD$' {
            $title = 'Weiteres CD/DVD-Laufwerk'
            $subtitle = 'Anderes optisches Startlaufwerk'
            $accentRole = 'Secondary'
            $typeTooltip = 'Grau: weiteres Startziel'
            break
        }
        default {
            # Preserve unknown firmware descriptions rather than inventing a meaning.
            $title = $description
            $subtitle = 'Weiteres Startziel'
            $accentRole = 'Secondary'
        }
    }

    return [pscustomobject]@{
        Guid = $Guid.ToLowerInvariant()
        Title = $title
        Subtitle = $subtitle
        RawDescription = $description
        AccentRole = $accentRole
        Symbol = $symbol
        TypeTooltip = $typeTooltip
        Resolution = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolution } else { $null }
        ResolutionReason = if ($description -eq 'USB HDD' -and $StorageContext) { [string]$StorageContext.UsbResolutionReason } else { $null }
    }
}


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


# Lenovo Boot Selector v0.4.1 - Functional Core: firmware text parsing
# Pure/deterministic functions only. Input is text; output is normalized data.

function Parse-GuidFromLine([string]$Line) {
    if ($Line -match '(\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\})') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}
function ConvertFrom-FirmwareEntriesText {
    param([AllowEmptyString()][string]$Text)

    # Map GUID -> firmware description. Support English and German field labels.
    $descriptions = @{}
    $currentGuid = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*(identifier|Bezeichner)\s+') {
            $currentGuid = Parse-GuidFromLine $line
            continue
        }

        if ($currentGuid -and $line -match '^\s*(description|Beschreibung)\s+(.+?)\s*$') {
            $descriptions[$currentGuid] = $Matches[2].Trim()
        }
    }
    return $descriptions
}

function ConvertFrom-FirmwareManagerText {
    param([AllowEmptyString()][string]$Text)

    $displayOrder = New-Object System.Collections.Generic.List[string]
    $selectedGuid = $null
    $readingDisplayOrder = $false

    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*displayorder\s+') {
            $guid = Parse-GuidFromLine $line
            if ($guid) { $displayOrder.Add($guid) }
            $readingDisplayOrder = $true
            continue
        }

        if ($readingDisplayOrder) {
            $continuedGuid = Parse-GuidFromLine $line
            if ($continuedGuid -and $line -match '^\s+\{') {
                $displayOrder.Add($continuedGuid)
                continue
            }
            $readingDisplayOrder = $false
        }

        if ($line -match '^\s*bootsequence\s+') {
            $selectedGuid = Parse-GuidFromLine $line
        }
    }

    return [pscustomobject]@{
        DisplayOrder = @($displayOrder.ToArray())
        SelectedGuid = $selectedGuid
    }
}

# Lenovo Boot Selector v0.5.0 - Functional Core: firmware target drift comparison
# Pure/deterministic functions only. No UI, IO, Task Scheduler or global script state.

function Compare-BootTargetDriftCore {
    param(
        [AllowNull()]$InstalledTargets,
        [AllowNull()]$Descriptions,
        [AllowNull()][string[]]$DisplayOrder
    )

    $installed = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($InstalledTargets)) {
        $guid = [string]$target.guid
        if (-not $guid) { continue }
        $normalized = $guid.Trim().ToLowerInvariant()
        if ($normalized -and -not $installed.Contains($normalized)) { $installed.Add($normalized) }
    }

    $current = New-Object System.Collections.Generic.List[string]
    $bootMenuGuid = $null
    if ($Descriptions) {
        foreach ($key in @($Descriptions.Keys)) {
            if ([string]$Descriptions[$key] -eq 'Boot Menu') {
                $bootMenuGuid = ([string]$key).Trim().ToLowerInvariant()
                break
            }
        }
    }
    if ($bootMenuGuid -and -not $current.Contains($bootMenuGuid)) { $current.Add($bootMenuGuid) }

    foreach ($guid in @($DisplayOrder)) {
        if (-not $guid) { continue }
        $normalized = ([string]$guid).Trim().ToLowerInvariant()
        if ($normalized -and -not $current.Contains($normalized)) { $current.Add($normalized) }
    }

    $added = @($current | Where-Object { -not $installed.Contains($_) })
    $removed = @($installed | Where-Object { -not $current.Contains($_) })

    [pscustomobject]@{
        HasDrift = [bool]($added.Count -gt 0 -or $removed.Count -gt 0)
        HasNewTargets = [bool]($added.Count -gt 0)
        AddedGuids = @($added)
        RemovedGuids = @($removed)
        CurrentGuids = @($current.ToArray())
        InstalledGuids = @($installed.ToArray())
        BootMenuGuid = $bootMenuGuid
    }
}


function Get-BootServiceFirmwareSnapshot {
    param([switch]$UseExistingCache)

    $managerText = Get-TaskBrokerFirmwareManagerText -UseExistingCache:$UseExistingCache
    $firmwareText = Get-TaskBrokerFirmwareEntriesText -UseExistingCache:$UseExistingCache

    [pscustomobject]@{
        Descriptions = ConvertFrom-FirmwareEntriesText -Text ([string]$firmwareText)
        ManagerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    }
}

function Set-BootNextTargetService {
    param([Parameter(Mandatory=$true)][string]$Guid)

    $normalized = $Guid.ToLowerInvariant()
    $managerText = Set-TaskBrokerBootNextTarget -Guid $normalized
    if ($managerText -notmatch [regex]::Escape($normalized)) {
        throw "BCDEdit wurde ausgeführt, aber das gewünschte Ziel konnte im Firmware Boot Manager nicht nachgewiesen werden: $normalized"
    }

    $managerState = ConvertFrom-FirmwareManagerText -Text ([string]$managerText)
    if (-not $managerState.SelectedGuid -or $managerState.SelectedGuid -ne $normalized) {
        throw "Das gewünschte BootNext-Ziel wurde nach dem Schreiben nicht als bootsequence zurückgelesen: $normalized"
    }

    [pscustomobject]@{
        ExitCode = 0
        Guid = $normalized
        ManagerText = $managerText
    }
}

function Start-BackgroundRefreshWorkerProcess {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware,
        [AllowNull()][string]$RuntimeSessionId
    )

    $powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = @(
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath),
        '-BackgroundRefresh',
        '-BackgroundResultPath', ('"{0}"' -f $ResultPath)
    )
    if ($RefreshStorage) { $args += '-BackgroundRefreshStorage' }
    if ($RefreshFirmware) { $args += '-BackgroundRefreshFirmware' }
    if ($RuntimeSessionId) { $args += @('-RuntimeSessionId', ('"{0}"' -f $RuntimeSessionId)) }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $powershellExe
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process = [System.Diagnostics.Process]::Start($psi)
    if (-not $process) { throw 'Hintergrundprozess konnte nicht gestartet werden.' }
    return $process
}

function Read-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw 'Der Hintergrund-Refresh hat kein Ergebnis geliefert.'
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Remove-BackgroundRefreshResultFile {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return }
    try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch { }
}

function New-BackgroundRefreshRequest {
    param(
        [bool]$RefreshStorage,
        [bool]$RefreshFirmware
    )

    [pscustomobject]@{
        RefreshStorage  = [bool]$RefreshStorage
        RefreshFirmware = [bool]$RefreshFirmware
    }
}

function New-BackgroundRefreshRuntimeState {
    [pscustomobject]@{
        Process        = $null
        Timer          = $null
        ResultPath     = $null
        ActiveRequest  = $null
        PendingRequest = $null
        LastTiming     = $null
    }
}

function Test-BackgroundRefreshActive {
    param([Parameter(Mandatory=$true)]$State)
    return ($null -ne $State.Process)
}

function Test-BackgroundRefreshNeedsFirmware {
    param(
        [bool]$RefreshStorage,
        [AllowNull()][string]$FirmwareCacheText,
        [datetime]$FirmwareCacheUtc,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if ($RefreshStorage) { return $true }
    if (-not $FirmwareCacheText) { return $true }
    return (($NowUtc - $FirmwareCacheUtc).TotalSeconds -ge 30)
}

function Test-BackgroundRefreshRequestEscalation {
    param(
        [AllowNull()]$ActiveRequest,
        [Parameter(Mandatory=$true)]$Requested
    )

    if (-not $ActiveRequest) { return $true }
    if ($Requested.RefreshStorage -and -not $ActiveRequest.RefreshStorage) { return $true }
    if ($Requested.RefreshFirmware -and -not $ActiveRequest.RefreshFirmware) { return $true }
    return $false
}

function Add-BackgroundRefreshPendingRequest {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Request
    )

    if (-not $State.PendingRequest) {
        $State.PendingRequest = New-BackgroundRefreshRequest -RefreshStorage:$Request.RefreshStorage -RefreshFirmware:$Request.RefreshFirmware
        return $State.PendingRequest
    }

    if ($Request.RefreshStorage) { $State.PendingRequest.RefreshStorage = $true }
    if ($Request.RefreshFirmware) { $State.PendingRequest.RefreshFirmware = $true }
    return $State.PendingRequest
}

function Set-BackgroundRefreshActive {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)]$Process,
        [Parameter(Mandatory=$true)][string]$ResultPath,
        [Parameter(Mandatory=$true)]$Request
    )

    $State.Process = $Process
    $State.ResultPath = $ResultPath
    $State.ActiveRequest = $Request
}

function Set-BackgroundRefreshTimer {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timer
    )
    $State.Timer = $Timer
}

function Take-BackgroundRefreshCompletionContext {
    param([Parameter(Mandatory=$true)]$State)

    if (-not $State.Process) { return $null }

    $context = [pscustomobject]@{
        Process    = $State.Process
        Timer      = $State.Timer
        ResultPath = $State.ResultPath
        Request    = $State.ActiveRequest
    }

    $State.Process = $null
    $State.Timer = $null
    $State.ResultPath = $null
    $State.ActiveRequest = $null
    return $context
}

function Take-BackgroundRefreshPendingRequest {
    param([Parameter(Mandatory=$true)]$State)
    $pending = $State.PendingRequest
    $State.PendingRequest = $null
    return $pending
}

function Set-BackgroundRefreshLastTiming {
    param(
        [Parameter(Mandatory=$true)]$State,
        [AllowNull()]$Timing
    )
    $State.LastTiming = $Timing
}

function ConvertFrom-BackgroundRefreshResultText {
    param([Parameter(Mandatory=$true)][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Der Hintergrund-Refresh hat ein leeres Ergebnis geliefert.'
    }
    return ($Text | ConvertFrom-Json)
}


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

function New-Label {
    param(
        [string]$Text,
        [Drawing.Font]$Font,
        [Drawing.Color]$ForeColor,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.BackColor = [Drawing.Color]::Transparent
    $label.Location = New-Object Drawing.Point($X, $Y)
    $label.Size = New-Object Drawing.Size($Width, $Height)
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function Get-BootRowFromControl($Control) {
    $current = $Control
    while ($current) {
        if (($current -is [System.Windows.Forms.Panel]) -and $current.Name -eq 'BootRow') { return $current }
        $current = $current.Parent
    }
    return $null
}

function Set-RowHoverState($Control, [bool]$Hover) {
    $row = Get-BootRowFromControl $Control
    if (-not $row) { return }

    $rowGuid = [string]$row.Tag
    if ($script:IsManageEntriesMode) {
        $hidden = Test-ManageEntryHidden -Guid $rowGuid
        if ($hidden) {
            $row.BackColor = if ($Hover) { [Drawing.Color]::FromArgb(37,37,37) } else { [Drawing.Color]::FromArgb(27,27,27) }
        }
        else {
            $row.BackColor = if ($Hover) { $script:ColorHover } else { $script:ColorRow }
        }
        $row.Invalidate($true)
        return
    }

    $isSelected = $script:SelectedGuid -and ($rowGuid -eq $script:SelectedGuid)
    if ($isSelected) {
        $row.BackColor = $script:ColorSelectedRow
    }
    elseif ($Hover) {
        $row.BackColor = $script:ColorHover
    }
    else {
        $row.BackColor = $script:ColorRow
    }
    $row.Invalidate($true)
}

function Update-PopupRows {
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }

    $listMatches = $script:Popup.Controls.Find('EntryList', $true)
    $listPanel = if ($listMatches.Count -gt 0) { $listMatches[0] } else { $null }
    $contentPanel = if ($listPanel) { $listPanel.Controls['EntryContent'] } else { $null }
    $scrollBar = if ($listPanel) { $listPanel.Controls['EntryScroll'] } else { $null }
    $statusMatches = $script:Popup.Controls.Find('StatusLabel', $true)
    $statusLabel = if ($statusMatches.Count -gt 0) { $statusMatches[0] } else { $null }
    if (-not $listPanel -or -not $contentPanel) { return }

    $contentPanel.SuspendLayout()
    $contentPanel.Controls.Clear()

    $baseRowHeight = 60
    $rowGap = 4
    $y = 0
    $displayEntries = if ($script:IsManageEntriesMode) {
        @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft)
    }
    else {
        @(Get-OrderedEntriesForUi)
    }

    $clickHandler = {
        param($sender, $eventArgs)
        if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
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
            $script:LastStatusText = if (Test-ManageEntryHidden -Guid $guid) { 'Eintrag wird ausgeblendet.' } else { 'Eintrag wird angezeigt.' }
            Update-PopupRows
            return
        }

        try {
            $entry = Get-EntryByGuid $guid
            Set-BootNextTarget -Guid $guid
            $script:SelectedGuid = $guid.ToLowerInvariant()
            $script:LastStatusText = if ($entry) { "Nächster Start: $(Get-EntryDisplayTitle -Entry $entry)" } else { 'Nächstes Startziel wurde gesetzt.' }
            Update-PopupRows
        }
        catch {
            Show-LenovoNoticeDialog -Title 'Startziel konnte nicht geändert werden' -Heading 'Die Auswahl wurde nicht übernommen.' -Message 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.' -Kind Error
        }
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
        try { [void]$sender.DoDragDrop($guid, [System.Windows.Forms.DragDropEffects]::Move) } catch { }
    }
    $dragEnterHandler = {
        param($sender, $eventArgs)
        if ($script:IsManageEntriesMode -and $eventArgs.Data.GetDataPresent([string])) {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
        else {
            $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    }
    $dragDropHandler = {
        param($sender, $eventArgs)
        if (-not $script:IsManageEntriesMode -or -not $eventArgs.Data.GetDataPresent([string])) { return }
        $movedGuid = [string]$eventArgs.Data.GetData([string])
        $targetRow = Get-BootRowFromControl $sender
        if (-not $targetRow) { return }
        $point = $targetRow.PointToClient((New-Object Drawing.Point($eventArgs.X, $eventArgs.Y)))
        $after = ($point.Y -gt ($targetRow.Height / 2))
        Move-ManageEntry -MovedGuid $movedGuid -TargetGuid ([string]$targetRow.Tag) -After:$after
        $script:ManageLastDragUtc = [datetime]::UtcNow
        $script:LastStatusText = 'Reihenfolge geändert · Speichern übernimmt die Änderung.'
        Update-PopupRows
    }

    $contentPanel.AllowDrop = $false

    foreach ($entry in $displayEntries) {
        $guidNormalized = ([string]$entry.Guid).ToLowerInvariant()
        $aliasEditActive = $script:IsManageEntriesMode -and $script:ManageAliasEditGuid -and ($guidNormalized -eq $script:ManageAliasEditGuid)
        $rowHeight = if ($aliasEditActive) { 92 } else { $baseRowHeight }

        $row = New-Object System.Windows.Forms.Panel
        $row.Name = 'BootRow'
        $row.Tag = $entry.Guid
        $row.Location = New-Object Drawing.Point(0, $y)
        $row.Size = New-Object Drawing.Size(390, $rowHeight)
        $row.BackColor = $script:ColorRow
        $row.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
        $row.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)

        $isHidden = $script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $entry.Guid)
        $isSelected = (-not $script:IsManageEntriesMode) -and $script:SelectedGuid -and ($entry.Guid -eq $script:SelectedGuid)
        if ($isSelected) { $row.BackColor = $script:ColorSelectedRow }
        elseif ($isHidden) { $row.BackColor = [Drawing.Color]::FromArgb(27,27,27) }

        $marker = New-Object System.Windows.Forms.Panel
        $marker.Location = New-Object Drawing.Point(0, 0)
        $marker.Size = New-Object Drawing.Size(3, $rowHeight)
        $marker.BackColor = $script:ColorRow
        if ($isSelected -or ($script:IsManageEntriesMode -and -not $isHidden)) { $marker.BackColor = $script:ColorAccent }
        elseif ($isHidden) { $marker.BackColor = [Drawing.Color]::FromArgb(70,70,70) }
        $marker.Tag = $entry.Guid
        $marker.AllowDrop = $script:IsManageEntriesMode
        $row.Controls.Add($marker)

        $iconColor = if ($isHidden) { [Drawing.Color]::FromArgb(105,105,105) } else { $entry.Accent }
        $titleColor = if ($isHidden) { [Drawing.Color]::FromArgb(145,145,145) } else { $script:ColorPrimary }
        $subtitleColor = if ($isHidden) { [Drawing.Color]::FromArgb(100,100,100) } else { $script:ColorSecondary }

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
        $displayTitle = if ($script:IsManageEntriesMode) {
            Get-EntryDisplayTitle -Entry $entry -UseManageDraft
        }
        else {
            Get-EntryDisplayTitle -Entry $entry
        }

        $titleWidth = if ($script:IsManageEntriesMode) { if ($aliasEditActive) { 318 } else { 220 } } else { 284 }
        $titleText = if ($aliasEditActive) { [string]$entry.Title } else { $displayTitle }
        $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
            -ForeColor $titleColor -X 58 -Y 6 -Width $titleWidth -Height 21
        $title.Tag = $entry.Guid
        $title.Cursor = if ($aliasEditActive) { [System.Windows.Forms.Cursors]::Default } else { [System.Windows.Forms.Cursors]::Hand }
        $title.AllowDrop = ($script:IsManageEntriesMode -and -not $aliasEditActive)
        $row.Controls.Add($title)

        $subtitle = $null
        if (-not $aliasEditActive) {
            $subtitleWidth = if ($script:IsManageEntriesMode) { 220 } else { 284 }
            $subtitleText = if ($script:IsManageEntriesMode -and $alias) {
                "Originalname: $($entry.Title)"
            }
            elseif ($script:IsManageEntriesMode -and ([string]$entry.Title -eq 'Lenovo Boot-Menü')) {
                'Auswahlmenü für das nächste Startziel'
            }
            else {
                [string]$entry.Subtitle
            }
            $subtitle = New-Label -Text $subtitleText -Font (New-Object Drawing.Font('Segoe UI', 8.3, [Drawing.FontStyle]::Regular)) `
                -ForeColor $subtitleColor -X 58 -Y 27 -Width $subtitleWidth -Height 27
            $subtitle.AutoEllipsis = $false
            $subtitle.Tag = $entry.Guid
            $subtitle.Cursor = [System.Windows.Forms.Cursors]::Hand
            $subtitle.AllowDrop = $script:IsManageEntriesMode
            $row.Controls.Add($subtitle)
        }

        if ($script:IsManageEntriesMode) {
            if ($aliasEditActive) {
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
                $aliasEditor.Font = New-Object Drawing.Font('Segoe UI', 9.2, [Drawing.FontStyle]::Regular)
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
                        $script:LastStatusText = if ([string]::IsNullOrWhiteSpace([string]$sender.Text)) { 'Anzeigename entfernt · Speichern übernimmt die Änderung.' } else { 'Anzeigename geändert · Speichern übernimmt die Änderung.' }
                        $eventArgs.SuppressKeyPress = $true
                        Update-PopupRows
                    }
                    elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
                        $script:ManageAliasEditGuid = $null
                        $script:LastStatusText = 'Änderung am Anzeigenamen verworfen.'
                        $eventArgs.SuppressKeyPress = $true
                        Update-PopupRows
                    }
                })
                $editorFrame.Controls.Add($aliasEditor)
                $row.Controls.Add($editorFrame)

                $applyAlias = New-Object System.Windows.Forms.Button
                $applyAlias.Name = 'AliasApplyButton'
                $applyAlias.Text = 'Übernehmen'
                $applyAlias.Tag = $entry.Guid
                $applyAlias.Font = New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Bold)
                $applyAlias.ForeColor = $script:ColorAccent
                $applyAlias.BackColor = $script:ColorRow
                $applyAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                $applyAlias.FlatAppearance.BorderSize = 0
                $applyAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
                $applyAlias.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
                $applyAlias.Location = New-Object Drawing.Point(58, 62)
                $applyAlias.Size = New-Object Drawing.Size(104, 24)
                $applyAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
                $applyAlias.Add_Click({
                    param($sender,$eventArgs)
                    $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
                    if ($editor) {
                        Set-ManageEntryAliasDraft -Guid ([string]$editor.Tag) -Alias ([string]$editor.Text)
                        $empty = [string]::IsNullOrWhiteSpace([string]$editor.Text)
                        $script:ManageAliasEditGuid = $null
                        $script:LastStatusText = if ($empty) { 'Anzeigename entfernt · Speichern übernimmt die Änderung.' } else { 'Anzeigename geändert · Speichern übernimmt die Änderung.' }
                        Update-PopupRows
                    }
                })
                $row.Controls.Add($applyAlias)

                $cancelAlias = New-Object System.Windows.Forms.Button
                $cancelAlias.Name = 'AliasCancelButton'
                $cancelAlias.Text = 'Abbrechen'
                $cancelAlias.Font = New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Regular)
                $cancelAlias.ForeColor = $script:ColorSecondary
                $cancelAlias.BackColor = $script:ColorRow
                $cancelAlias.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                $cancelAlias.FlatAppearance.BorderSize = 0
                $cancelAlias.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(42,42,42)
                $cancelAlias.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(34,34,34)
                $cancelAlias.Location = New-Object Drawing.Point(166, 62)
                $cancelAlias.Size = New-Object Drawing.Size(94, 24)
                $cancelAlias.Cursor = [System.Windows.Forms.Cursors]::Hand
                $cancelAlias.Add_Click({
                    $script:ManageAliasEditGuid = $null
                    $script:LastStatusText = 'Änderung am Anzeigenamen verworfen.'
                    Update-PopupRows
                })
                $row.Controls.Add($cancelAlias)

                $originalHint = New-Label -Text 'Leer lassen = Originalname' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
                    -ForeColor ([Drawing.Color]::FromArgb(125,125,125)) -X 266 -Y 65 -Width 110 -Height 18
                $originalHint.TextAlign = [Drawing.ContentAlignment]::MiddleRight
                $row.Controls.Add($originalHint)

                $rowControls = @()
            }
            else {
                $state = New-Object System.Windows.Forms.Panel
                $state.Name = 'VisibilityGlyph'
                $state.Tag = $entry.Guid
                $state.AccessibleName = if ($isHidden) { 'hidden' } else { 'visible' }
                $state.AccessibleDescription = if ($isHidden) { 'Verborgen – klicken zum Einblenden' } else { 'Sichtbar – klicken zum Ausblenden' }
                $state.Location = New-Object Drawing.Point(286, 12)
                $state.Size = New-Object Drawing.Size(32, 34)
                $state.BackColor = [Drawing.Color]::Transparent
                $state.Cursor = [System.Windows.Forms.Cursors]::Hand
                $state.AllowDrop = $true
                $state.Add_Paint({
                    param($sender,$eventArgs)
                    $hidden = ([string]$sender.AccessibleName -eq 'hidden')
                    $color = if ($hidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $script:ColorAccent }
                    $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $pen = New-Object Drawing.Pen($color, 1.6)
                    $pupil = New-Object Drawing.SolidBrush($color)
                    try {
                        $eye = New-Object Drawing.Rectangle(7, 11, 18, 11)
                        $eventArgs.Graphics.DrawEllipse($pen, $eye)
                        $eventArgs.Graphics.FillEllipse($pupil, 14, 14, 4, 4)
                        if ($hidden) {
                            $slash = New-Object Drawing.Pen($color, 1.8)
                            try { $eventArgs.Graphics.DrawLine($slash, 6, 24, 26, 9) } finally { $slash.Dispose() }
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

                $editAlias = New-Label -Text '✎' -Font (New-Object Drawing.Font('Segoe UI Symbol', 12.0, [Drawing.FontStyle]::Regular)) `
                    -ForeColor ([Drawing.Color]::FromArgb(190,190,190)) -X 321 -Y 12 -Width 25 -Height 34
                $editAlias.Name = 'AliasEditButton'
                $editAlias.Tag = $entry.Guid
                $editAlias.AccessibleDescription = 'Anzeigename ändern'
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
                    $script:LastStatusText = 'Anzeigename bearbeiten · Enter übernimmt · Esc verwirft · leer = Originalname'
                    Update-PopupRows
                    $editor = $script:Popup.Controls.Find('AliasEditor', $true) | Select-Object -First 1
                    if ($editor) {
                        $editor.Focus()
                        $editor.SelectAll()
                    }
                })
                $row.Controls.Add($editAlias)

                $grip = New-Label -Text '≡' -Font (New-Object Drawing.Font('Segoe UI Symbol', 13, [Drawing.FontStyle]::Regular)) `
                    -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 350 -Y 12 -Width 26 -Height 34
                $grip.Tag = $entry.Guid
                $grip.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
                $grip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
                $grip.AllowDrop = $true
                $row.Controls.Add($grip)

                $rowControls = @($row, $marker, $icon, $title, $subtitle, $state, $grip)
            }
        }
        else {
            $checkText = if ($isSelected) { '✓' } else { '' }
            $check = New-Label -Text $checkText `
                -Font (New-Object Drawing.Font('Segoe UI Symbol', 12, [Drawing.FontStyle]::Bold)) `
                -ForeColor $script:ColorAccent -X 354 -Y 12 -Width 24 -Height 34
            $check.Tag = $entry.Guid
            $check.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
            $check.Cursor = [System.Windows.Forms.Cursors]::Hand
            $row.Controls.Add($check)
            $rowControls = @($row, $marker, $icon, $title, $subtitle, $check)
        }

        foreach ($control in $rowControls) {
            $control.Add_Click($clickHandler)
            $control.Add_MouseEnter($enterHandler)
            $control.Add_MouseLeave($leaveHandler)
            $control.Add_MouseWheel($wheelHandler)
            if ($script:IsManageEntriesMode) {
                $control.Add_MouseDown($mouseDownHandler)
                $control.Add_MouseMove($mouseMoveHandler)
                $control.Add_DragEnter($dragEnterHandler)
                $control.Add_DragDrop($dragDropHandler)
            }
        }

        $contentPanel.Controls.Add($row)
        $y += ($rowHeight + $rowGap)
    }

    $viewportHeight = $listPanel.ClientSize.Height
    $contentHeight = [Math]::Max($viewportHeight, $y)
    $contentPanel.Size = New-Object Drawing.Size(390, $contentHeight)
    if ($scrollBar) {
        $maxScroll = [Math]::Max(0, $contentHeight - $viewportHeight)
        $scrollBar.LargeChange = [Math]::Max(1, $viewportHeight)
        $scrollBar.SmallChange = $baseRowHeight + $rowGap
        $scrollBar.Maximum = $maxScroll
        $scrollBar.Visible = ($maxScroll -gt 0)
        if (-not $scrollBar.Visible) { $scrollBar.Value = 0 }
        elseif ($scrollBar.Value -gt $maxScroll) { $scrollBar.Value = $maxScroll }
        $contentPanel.Top = -1 * $scrollBar.Value
    }

    if ($statusLabel) { $statusLabel.Text = $script:LastStatusText }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-ManageEntriesUiState
    Update-ManageSaveButtonState
    $contentPanel.ResumeLayout()
    Update-MaintenanceUi
}



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

function New-PopupForm {
    if (-not $script:BootTypeToolTip) {
        $script:BootTypeToolTip = New-Object System.Windows.Forms.ToolTip
        $script:BootTypeToolTip.InitialDelay = 350
        $script:BootTypeToolTip.ReshowDelay = 100
        $script:BootTypeToolTip.AutoPopDelay = 8000
        $script:BootTypeToolTip.ShowAlways = $true
        $script:BootTypeToolTip.UseAnimation = $true
        $script:BootTypeToolTip.UseFading = $true
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Name = 'LenovoBootMenuPopup'
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

    # v0.2.29: compact brand header. No decorative status dot and no permanent
    # subtitle. A status line appears only while the background refresh is active.
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object Drawing.Point(0, 0)
    $header.Size = New-Object Drawing.Size(390, 60)
    $header.BackColor = $script:ColorHeader

    $headerTitle = New-Label -Text 'Lenovo Boot Selector' -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorAccent -X 16 -Y 19 -Width 285 -Height 22
    $headerTitle.Name = 'HeaderTitleLabel'
    $script:HeaderTitleLabel = $headerTitle
    $header.Controls.Add($headerTitle)

    $headerSub = New-Label -Text '' -Font (New-Object Drawing.Font('Segoe UI', 7.8, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 31 -Width 290 -Height 16
    $headerSub.Name = 'HeaderStatusLabel'
    $headerSub.Visible = $false
    $script:HeaderStatusLabel = $headerSub
    $header.Controls.Add($headerSub)

    $refresh = New-Object System.Windows.Forms.Button
    $refresh.Text = '↻'
    $refresh.Font = New-Object Drawing.Font('Segoe UI Symbol', 11.5, [Drawing.FontStyle]::Regular)
    $refresh.ForeColor = $script:ColorSecondary
    $refresh.BackColor = $script:ColorHeader
    $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $refresh.FlatAppearance.BorderSize = 0
    $refresh.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    $refresh.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $refresh.Location = New-Object Drawing.Point(340, 12)
    $refresh.Size = New-Object Drawing.Size(34, 34)
    $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:RefreshButton = $refresh
    $refresh.Add_MouseEnter({
        $script:RefreshButtonHovered = $true
        Update-RefreshButtonVisual
    })
    $refresh.Add_MouseLeave({
        $script:RefreshButtonHovered = $false
        Update-RefreshButtonVisual
    })
    $refresh.Add_Click({
        if (Test-MaintenanceBusy) { return }
        $script:LastStatusText = 'Startziele werden im Hintergrund aktualisiert…'
        Update-PopupRows
        Start-BackgroundBootRefresh -RefreshStorage
        Update-RefreshButtonVisual
    })
    $header.Controls.Add($refresh)
    if ($script:BootTypeToolTip) { $script:BootTypeToolTip.SetToolTip($refresh, 'Startziele aktualisieren') }
    Update-RefreshButtonVisual
    $root.Controls.Add($header)

    $headerDivider = New-Object System.Windows.Forms.Panel
    $headerDivider.Location = New-Object Drawing.Point(0, 59)
    $headerDivider.Size = New-Object Drawing.Size(390, 1)
    $headerDivider.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
    $root.Controls.Add($headerDivider)

    $section = New-Object System.Windows.Forms.Panel
    $section.Location = New-Object Drawing.Point(0, 60)
    $section.Size = New-Object Drawing.Size(390, 28)
    $section.BackColor = $script:ColorBackground

    $sectionLabel = New-Label -Text 'NÄCHSTER START' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 4 -Width 200 -Height 20
    $sectionLabel.Name = 'SectionLabel'
    $section.Controls.Add($sectionLabel)

    $manageButton = New-Object System.Windows.Forms.Button
    $manageButton.Name = 'ManageEntriesButton'
    $manageButton.Text = 'ANPASSEN'
    $manageButton.Font = New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)
    $manageButton.ForeColor = $script:ColorSecondary
    $manageButton.BackColor = $script:ColorBackground
    $manageButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $manageButton.FlatAppearance.BorderSize = 0
    $manageButton.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(38, 38, 38)
    $manageButton.FlatAppearance.MouseDownBackColor = $script:ColorSelectedRow
    $manageButton.Location = New-Object Drawing.Point(268, 1)
    $manageButton.Size = New-Object Drawing.Size(104, 25)
    $manageButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $manageButton.Add_Click({ Start-ManageEntriesMode })
    $script:ManageEntriesButton = $manageButton
    $section.Controls.Add($manageButton)
    $root.Controls.Add($section)

    $listPanel = New-Object System.Windows.Forms.Panel
    $listPanel.Name = 'EntryList'
    $listPanel.Location = New-Object Drawing.Point(0, 88)
    $listPanel.Size = New-Object Drawing.Size(390, 402)
    $listPanel.BackColor = $script:ColorBackground
    $listPanel.AutoScroll = $false
    $listPanel.TabStop = $true

    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Name = 'EntryContent'
    $contentPanel.Location = New-Object Drawing.Point(0, 0)
    $contentPanel.Size = New-Object Drawing.Size(390, 402)
    $contentPanel.BackColor = $script:ColorBackground
    $listPanel.Controls.Add($contentPanel)

    $entryScroll = New-Object LenovoVerticalScrollBar
    $entryScroll.Name = 'EntryScroll'
    $entryScroll.Location = New-Object Drawing.Point(382, 0)
    $entryScroll.Size = New-Object Drawing.Size(8, 402)
    $entryScroll.TrackColor = [Drawing.Color]::FromArgb(23, 23, 23)
    $entryScroll.ThumbColor = $script:ColorAccent
    $entryScroll.ThumbHoverColor = [Drawing.Color]::FromArgb(242, 59, 49)
    $entryScroll.Visible = $false
    $entryScroll.Add_ValueChanged({
        try {
            $scrollContainer = $this.Parent
            if ($scrollContainer) {
                $content = $scrollContainer.Controls['EntryContent']
                if ($content) { $content.Top = -1 * $this.Value }
            }
        }
        catch {
            $script:LastStatusText = 'Scrollposition konnte nicht aktualisiert werden.'
        }
    })
    $listPanel.Controls.Add($entryScroll)
    $entryScroll.BringToFront()

    $listPanel.Add_MouseWheel({
        param($sender, $eventArgs)
        $bar = $sender.Controls['EntryScroll']
        if ($bar -and $bar.Visible) {
            $direction = if ($eventArgs.Delta -gt 0) { -1 } else { 1 }
            $bar.Value = $bar.Value + ($direction * $bar.SmallChange)
        }
    })
    $listPanel.Add_MouseEnter({ $this.Focus() })
    $root.Controls.Add($listPanel)

    # v0.2.31: compact lower third with two aligned configuration rows and one
    # action area. The selected next-boot target is shown directly with Restart,
    # so the former duplicate status/footer block is no longer needed.
    $configSection = New-Object System.Windows.Forms.Panel
    $configSection.Name = 'ConfigSectionPanel'
    $configSection.Location = New-Object Drawing.Point(0, 490)
    $configSection.Size = New-Object Drawing.Size(390, 20)
    $configSection.BackColor = $script:ColorSurface

    $configLabel = New-Label -Text 'EINSTELLUNGEN' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 2 -Width 220 -Height 17
    $configSection.Controls.Add($configLabel)
    $root.Controls.Add($configSection)

    $settings = New-Object System.Windows.Forms.Panel
    $settings.Name = 'SettingsPanel'
    $settings.Location = New-Object Drawing.Point(0, 510)
    $settings.Size = New-Object Drawing.Size(390, 38)
    $settings.BackColor = $script:ColorSurface

    $autostartText = New-Label -Text 'Mit Windows starten' -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 280 -Height 22
    $autostartText.Cursor = [System.Windows.Forms.Cursors]::Hand
    $settings.Controls.Add($autostartText)
    $script:AutostartTextLabel = $autostartText

    $autostart = New-Object LenovoCheckBox
    $autostart.Name = 'AutostartCheckbox'
    $autostart.Text = ''
    $autostart.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $autostart.ForeColor = $script:ColorPrimary
    $autostart.BackColor = $script:ColorSurface
    $autostart.AccentColor = $script:ColorAccent
    $autostart.Location = New-Object Drawing.Point(348, 7)
    $autostart.Size = New-Object Drawing.Size(26, 24)
    $autostart.Add_CheckedChanged({
        if (-not $script:UpdatingAutostartUi) {
            Set-AutostartFromUi -Enabled:$this.Checked
        }
    })
    $autostartText.Add_Click({ if ($script:AutostartCheckbox) { $script:AutostartCheckbox.Checked = -not $script:AutostartCheckbox.Checked } })
    $script:AutostartCheckbox = $autostart
    $settings.Controls.Add($autostart)
    $root.Controls.Add($settings)

    $defaultPanel = New-Object System.Windows.Forms.Panel
    $defaultPanel.Name = 'DefaultPanel'
    $defaultPanel.Location = New-Object Drawing.Point(0, 548)
    $defaultPanel.Size = New-Object Drawing.Size(390, 38)
    $defaultPanel.BackColor = $script:ColorSurface
    $defaultPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $defaultName = New-Label -Text 'Standard-Startziel' -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 16 -Y 8 -Width 150 -Height 22
    $defaultName.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultName)

    $defaultValue = New-Label -Text 'Kein Standardziel' -Font (New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorPrimary -X 164 -Y 8 -Width 184 -Height 22
    $defaultValue.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $defaultValue.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultValue.Name = 'DefaultTargetValueLabel'
    $defaultPanel.Controls.Add($defaultValue)
    $script:DefaultValueLabel = $defaultValue

    $defaultArrow = New-Label -Text '›' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 352 -Y 7 -Width 22 -Height 23
    $defaultArrow.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $defaultArrow.Cursor = [System.Windows.Forms.Cursors]::Hand
    $defaultPanel.Controls.Add($defaultArrow)

    $defaultRowEnter = {
        if ($script:DefaultButton -and $script:DefaultButton.Enabled) { $script:DefaultButton.BackColor = [Drawing.Color]::FromArgb(38,38,38) }
    }
    $defaultRowLeave = {
        if ($script:DefaultButton) { $script:DefaultButton.BackColor = $script:ColorSurface }
    }
    $defaultRowClick = {
        if ($script:DefaultButton -and $script:DefaultButton.Enabled) { Show-DefaultTargetMenu -Owner $script:DefaultButton }
    }
    foreach ($control in @($defaultPanel,$defaultName,$defaultValue,$defaultArrow)) {
        $control.Add_MouseEnter($defaultRowEnter)
        $control.Add_MouseLeave($defaultRowLeave)
        $control.Add_Click($defaultRowClick)
    }
    $script:DefaultButton = $defaultPanel
    $root.Controls.Add($defaultPanel)

    $settingsDivider = New-Object System.Windows.Forms.Panel
    $settingsDivider.Name = 'SettingsDivider'
    $settingsDivider.Location = New-Object Drawing.Point(16, 586)
    $settingsDivider.Size = New-Object Drawing.Size(358, 1)
    $settingsDivider.BackColor = $script:ColorAccent
    $root.Controls.Add($settingsDivider)

    $restartPanel = New-Object System.Windows.Forms.Panel
    $restartPanel.Name = 'RestartPanel'
    $restartPanel.Location = New-Object Drawing.Point(0, 587)
    $restartPanel.Size = New-Object Drawing.Size(390, 65)
    $restartPanel.BackColor = $script:ColorSurface

    $restartButton = New-Object System.Windows.Forms.Button
    $restartButton.Text = 'Windows neu starten'
    $restartButton.Font = New-Object Drawing.Font('Segoe UI', 8.6, [Drawing.FontStyle]::Bold)
    $restartButton.ForeColor = $script:ColorPrimary
    $restartButton.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
    $restartButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restartButton.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68, 68, 68)
    $restartButton.FlatAppearance.BorderSize = 1
    $restartButton.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $restartButton.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58, 27, 25)
    $restartButton.Location = New-Object Drawing.Point(16, 6)
    $restartButton.Size = New-Object Drawing.Size(358, 31)
    $restartButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restartButton.Add_Click({ Restart-Windows })
    $restartPanel.Controls.Add($restartButton)

    $restartTarget = New-Label -Text 'Nächstes Ziel: Standardreihenfolge' -Font (New-Object Drawing.Font('Segoe UI', 7.6, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(155,155,155)) -X 16 -Y 39 -Width 358 -Height 18
    $restartTarget.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $restartTarget.Name = 'RestartTargetLabel'
    $restartPanel.Controls.Add($restartTarget)
    $script:RestartTargetLabel = $restartTarget
    $root.Controls.Add($restartPanel)

    # Dedicated footer height prevents Segoe UI/DPI clipping at the bottom edge.
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Name = 'FooterPanel'
    $footerPanel.Location = New-Object Drawing.Point(0, 652)
    $footerPanel.Size = New-Object Drawing.Size(390, 20)
    $footerPanel.BackColor = $script:ColorSurface
    $versionLabel = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(115,115,115)) -X 316 -Y 0 -Width 58 -Height 18
    $versionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $footerPanel.Controls.Add($versionLabel)
    $root.Controls.Add($footerPanel)

    # Entry-management overlay. It temporarily replaces the normal settings/footer
    # while the same boot list switches into edit mode.
    $managePanel = New-Object System.Windows.Forms.Panel
    $managePanel.Name = 'ManageEntriesPanel'
    $managePanel.Location = New-Object Drawing.Point(0, 490)
    $managePanel.Size = New-Object Drawing.Size(390, 182)
    $managePanel.BackColor = $script:ColorSurface
    $managePanel.Visible = $false

    $manageDivider = New-Object System.Windows.Forms.Panel
    $manageDivider.Location = New-Object Drawing.Point(16, 0)
    $manageDivider.Size = New-Object Drawing.Size(358, 1)
    $manageDivider.BackColor = [Drawing.Color]::FromArgb(54,54,54)
    $managePanel.Controls.Add($manageDivider)

    $manageTitle = New-Label -Text 'ÄNDERUNGEN' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 8 -Width 350 -Height 18
    $managePanel.Controls.Add($manageTitle)

    $manageHint = New-Label -Text 'Ziehen zum Sortieren · Klicken zum Ein-/Ausblenden' -Font (New-Object Drawing.Font('Segoe UI', 7.5, [Drawing.FontStyle]::Regular)) `
        -ForeColor $script:ColorSecondary -X 16 -Y 29 -Width 358 -Height 17
    $managePanel.Controls.Add($manageHint)

    $manageSubHint = New-Label -Text 'Stift zum Umbenennen · Leer lassen = Originalname' -Font (New-Object Drawing.Font('Segoe UI', 7.2, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 16 -Y 46 -Width 358 -Height 17
    $managePanel.Controls.Add($manageSubHint)

    $cancelManage = New-Object System.Windows.Forms.Button
    $cancelManage.Text = 'Abbrechen'
    $cancelManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
    $cancelManage.ForeColor = $script:ColorPrimary
    $cancelManage.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancelManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancelManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(68,68,68)
    $cancelManage.FlatAppearance.BorderSize = 1
    $cancelManage.FlatAppearance.MouseOverBackColor = $script:ColorSelectedRow
    $cancelManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(58,27,25)
    $cancelManage.Location = New-Object Drawing.Point(16, 78)
    $cancelManage.Size = New-Object Drawing.Size(126, 34)
    $cancelManage.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancelManage.Add_Click({ Stop-ManageEntriesMode })
    $managePanel.Controls.Add($cancelManage)

    $saveManage = New-Object System.Windows.Forms.Button
    $saveManage.Text = 'Änderungen speichern'
    $saveManage.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Bold)
    $saveManage.ForeColor = [Drawing.Color]::FromArgb(135,135,135)
    $saveManage.BackColor = [Drawing.Color]::FromArgb(35,35,35)
    $saveManage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveManage.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(58,58,58)
    $saveManage.FlatAppearance.BorderSize = 1
    $saveManage.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $saveManage.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $saveManage.Location = New-Object Drawing.Point(150, 78)
    $saveManage.Size = New-Object Drawing.Size(224, 34)
    $saveManage.Enabled = $false
    $saveManage.Cursor = [System.Windows.Forms.Cursors]::Default
    $saveManage.Add_Click({ Stop-ManageEntriesMode -Save })
    $managePanel.Controls.Add($saveManage)
    $script:ManageSaveButton = $saveManage

    $manageFooter = New-Object System.Windows.Forms.Panel
    $manageFooter.Location = New-Object Drawing.Point(0, 150)
    $manageFooter.Size = New-Object Drawing.Size(390, 32)
    $manageFooter.BackColor = $script:ColorSurface
    $manageVersion = New-Label -Text ("v{0}" -f $script:AppVersion) -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Regular)) `
        -ForeColor ([Drawing.Color]::FromArgb(120,120,120)) -X 316 -Y 7 -Width 58 -Height 18
    $manageVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $manageFooter.Controls.Add($manageVersion)
    $managePanel.Controls.Add($manageFooter)
    $root.Controls.Add($managePanel)

    $maintenancePanel = New-MaintenanceStatePanel
    $root.Controls.Add($maintenancePanel)

    # v0.2.28: no window region is applied; the popup stays rectangular.

    $form.Add_Deactivate({
        if (-not $script:ExitRequested -and -not (Test-MaintenanceBusy)) { $this.Hide() }
    })

    return $form
}

function Position-Popup {
    if (-not $script:Popup) { return }
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
    $wa = $screen.WorkingArea
    $x = $wa.Right - $script:Popup.Width - 10
    $y = $wa.Bottom - $script:Popup.Height - 10
    if ($x -lt $wa.Left) { $x = $wa.Left + 5 }
    if ($y -lt $wa.Top) { $y = $wa.Top + 5 }
    $script:Popup.Location = New-Object Drawing.Point($x, $y)
}

function Show-OrTogglePopup {
    if (-not $script:Popup -or $script:Popup.IsDisposed) {
        $script:Popup = New-PopupForm
    }

    if ($script:Popup.Visible) {
        $script:Popup.Hide()
        return
    }

    $maintenanceBusy = Test-MaintenanceBusy
    $brokerReady = if ($maintenanceBusy) { $false } else { ((Get-SystemFunctionsPresentationState) -eq 'Ready') }
    if ($brokerReady) {
        if ($script:CurrentEntries.Count -eq 0) { [void](Load-BootStateFromExistingCache) }
        try { [void](Refresh-SystemDefaultState) } catch { }
    }
    else {
        if (-not $maintenanceBusy) {
            $script:CurrentEntries = @()
            $script:SelectedGuid = $null
            if (Test-BootTargetDriftDetected) {
                $script:LastStatusText = if (Test-BootTargetDriftHasNewTargets) { 'Neues Startziel erkannt · Systemfunktionen neu initialisieren.' } else { 'Startziele geändert · Systemfunktionen neu initialisieren.' }
            }
            elseif (Test-TaskBrokerInstallationPresent) {
                $script:LastStatusText = 'Systemfunktionen müssen repariert werden.'
            }
            else {
                $script:LastStatusText = 'Systemfunktionen müssen eingerichtet werden.'
            }
        }
        Update-PopupRows
    }

    Update-AutostartUi | Out-Null
    Update-MaintenanceUi
    Position-Popup
    $script:Popup.Show()
    $script:Popup.Activate()

    # Critical latency path: the form is visible before any fresh Scheduled-Task
    # refresh begins. Maintenance/missing-system-function states never launch a
    # competing worker; slow firmware/storage work stays in the hidden child.
    if ($brokerReady -and -not $maintenanceBusy) {
        Start-BackgroundBootRefresh -RefreshStorage:($null -eq $script:StorageContext)
    }
}

function Load-TrayIcon {
    $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
    if (Test-Path $iconPath) {
        try { return [Drawing.Icon]::new($iconPath) } catch { }
    }
    return [Drawing.SystemIcons]::Application
}


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
    [void](Show-PendingUpdateResultOnStartup)
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
