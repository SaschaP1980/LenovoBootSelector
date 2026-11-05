#requires -version 5.1
# LBS-144: measure the *painted* pixel footprint of the actual Lenovo
# ToolStrip renderer at 96 and 240 DPI, not merely Font.GetHeight.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$start = $template.IndexOf($prefix, [StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Cannot locate canonical C# renderer source' }
$start += $prefix.Length
$endMarker = '"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing'
$end = $template.IndexOf($endMarker,$start,[StringComparison]::Ordinal)
if ($end -le $start) { throw 'Cannot locate canonical renderer end' }
$renderer = $template.Substring($start,$end-$start)
$probe = @'
public static class Lbs144MenuInkProbe
{
    public static int RasterHeight(float dpi, bool gdiplus)
    {
        using (var canvas = new System.Drawing.Bitmap(700, 140))
        {
            canvas.SetResolution(dpi,dpi);
            using (var g = System.Drawing.Graphics.FromImage(canvas))
            using (var f = new System.Drawing.Font("Segoe UI",9f, System.Drawing.FontStyle.Regular))
            using (var m = new LenovoContextMenuStrip())
            {
                g.Clear(System.Drawing.Color.Black);
                var item = new System.Windows.Forms.ToolStripMenuItem("Sprache");
                item.Font = f;
                m.Items.Add(item);
                m.Width = 650;
                item.AutoSize = false;
                item.Size = new System.Drawing.Size(650,55);
                m.PerformLayout();
                var row = new System.Drawing.Rectangle(45,0,570,55);
                if (gdiplus)
                {
                    using (var format = new System.Drawing.StringFormat(System.Drawing.StringFormat.GenericTypographic))
                    {
                        format.Alignment = System.Drawing.StringAlignment.Near;
                        format.LineAlignment = System.Drawing.StringAlignment.Center;
                        format.FormatFlags |= System.Drawing.StringFormatFlags.NoWrap;
                        using (var brush = new System.Drawing.SolidBrush(System.Drawing.Color.White))
                            g.DrawString("Sprache",f,brush,row,format);
                    }
                }
                else
                {
                    var e = new System.Windows.Forms.ToolStripItemTextRenderEventArgs(g,item,"Sprache",row,
                        System.Drawing.Color.White,f,System.Drawing.ContentAlignment.MiddleLeft);
                    var method = typeof(System.Windows.Forms.ToolStripRenderer).GetMethod(
                        "OnRenderItemText",System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
                    if (method == null) throw new System.InvalidOperationException("Cannot invoke renderer text paint");
                    method.Invoke(new LenovoMenuRenderer(),new object[]{ e });
                }
                int first=140,last=-1;
                for(int y=0;y<canvas.Height;y++)
                    for(int x=0;x<canvas.Width;x++)
                    {
                        var px=canvas.GetPixel(x,y);
                        if(px.R > 100 && px.G > 100 && px.B > 100)
                        {
                            if(y<first) first=y;
                            if(y>last) last=y;
                        }
                    }
                return last<first ? 0 : last-first+1;
            }
        }
    }
}
'@
Add-Type -TypeDefinition ($renderer + [Environment]::NewLine + $probe) -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
$gdi96 = [Lbs144MenuInkProbe]::RasterHeight([single]96,$false)
$gdi240 = [Lbs144MenuInkProbe]::RasterHeight([single]240,$false)
$plus96 = [Lbs144MenuInkProbe]::RasterHeight([single]96,$true)
$plus240 = [Lbs144MenuInkProbe]::RasterHeight([single]240,$true)
Write-Host ("LBS144_MENU_INK oldRenderer96={0} oldRenderer240={1} gdiPlus96={2} gdiPlus240={3}" -f $gdi96,$gdi240,$plus96,$plus240)
if ($gdi96 -le 0 -or $gdi240 -le 0 -or $plus96 -le 0 -or $plus240 -le 0) { throw 'Renderer returned no visible glyph pixels in raster probe' }
if ($gdi240 -lt [int][Math]::Floor($plus240 * 0.80)) {
    throw ("LBS-144 MENU INK RED: native ToolStrip text raster is only {0}px, expected >= {1}px at 240-DPI paint surface" -f $gdi240,[int][Math]::Floor($plus240 * 0.80))
}
Write-Host 'LBS-144 MENU INK RASTER RESULT=PASS'
