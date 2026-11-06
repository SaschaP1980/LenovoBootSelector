#requires -version 5.1
# LBS-144: real owner-drawn checkbox design bounds at DPI 96..288.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$start = $template.IndexOf($prefix,[StringComparison]::Ordinal)
if ($start -lt 0) { throw 'LBS-144 CHECKBOX RED: missing canonical C# source start' }
$start += $prefix.Length
$end = $template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$start,[StringComparison]::Ordinal)
if ($end -lt 0) { throw 'LBS-144 CHECKBOX RED: missing canonical C# source end' }
if (-not ('LenovoCheckBox' -as [type])) {
    Add-Type -TypeDefinition ($template.Substring($start,$end-$start)) -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
}
$script:checks = 0
function Assert-Lbs144Checkbox([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS-144 CHECKBOX RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS144 CHECKBOX $Name"
}
$measure = [LenovoCheckBox].GetMethod('GetGlyphBounds',[Reflection.BindingFlags] 'Public,Static')
Assert-Lbs144Checkbox 'DPI-specific 96px design geometry exposed for real C# renderer' ($null -ne $measure)
$cases = @(
    @{ Percent = 100; Dpi = 96;  W = 26; H = 24; Want = 18 },
    @{ Percent = 125; Dpi = 120; W = 33; H = 30; Want = 23 },
    @{ Percent = 150; Dpi = 144; W = 39; H = 36; Want = 27 },
    @{ Percent = 200; Dpi = 192; W = 52; H = 48; Want = 36 },
    @{ Percent = 250; Dpi = 240; W = 65; H = 60; Want = 45 },
    @{ Percent = 300; Dpi = 288; W = 78; H = 72; Want = 54 }
)
foreach ($c in $cases) {
    $bounds = [LenovoCheckBox]::GetGlyphBounds([Drawing.Size]::new($c.W,$c.H),[single]$c.Dpi)
    Assert-Lbs144Checkbox ("{0}% glyph has expected size" -f $c.Percent) ($bounds.Width -eq $c.Want -and $bounds.Height -eq $c.Want)
    Assert-Lbs144Checkbox ("{0}% glyph is centered and fully inside scaled control" -f $c.Percent) ($bounds.X -ge 0 -and $bounds.Y -ge 0 -and $bounds.Right -le $c.W -and $bounds.Bottom -le $c.H -and [Math]::Abs((2*$bounds.X+$bounds.Width)-$c.W) -le 1 -and [Math]::Abs((2*$bounds.Y+$bounds.Height)-$c.H) -le 1)
}
$small = [LenovoCheckBox]::GetGlyphBounds([Drawing.Size]::new(10,8),[single]240)
Assert-Lbs144Checkbox 'Unexpected small control clips glyph without drawing outside bounds' ($small.X -ge 0 -and $small.Y -ge 0 -and $small.Right -le 10 -and $small.Bottom -le 8)
$cb = New-Object LenovoCheckBox
$cb.Size = [Drawing.Size]::new(26,24)
$cb.BackColor = [Drawing.Color]::FromArgb(30,30,30)
$cb.Checked = $true
$bitmap = New-Object System.Drawing.Bitmap(26,24)
try {
    $cb.DrawToBitmap($bitmap, [Drawing.Rectangle]::new(0,0,26,24))
    $fillPixels=0
    $tickPixels=0
    for($y=0;$y -lt 24;$y++) {
        for($x=0;$x -lt 26;$x++) {
            $p=$bitmap.GetPixel($x,$y)
            if ($p.R -gt 150 -and $p.G -lt 95 -and $p.B -lt 95) { $fillPixels++ }
            if ($p.R -ge 225 -and $p.G -ge 225 -and $p.B -ge 225) { $tickPixels++ }
        }
    }
    Assert-Lbs144Checkbox '96-DPI checkbox visibly paints a substantial accent glyph' ($fillPixels -ge 145)
    Assert-Lbs144Checkbox 'Checked checkbox renders a visible contrast tick' ($tickPixels -ge 5)
} finally { $bitmap.Dispose(); $cb.Dispose() }
$source=[IO.File]::ReadAllText((Join-Path $root 'src\UI\PopupComposition.ps1'))
Assert-Lbs144Checkbox 'Autostart click behavior remains unchanged and accessible' ($source.Contains('Set-AutostartFromUi -Enabled:$this.Checked') -and $source.Contains('$autostartText.Add_Click'))
Assert-Lbs144Checkbox 'Popup 96-DPI checkbox control dimensions remain 26 by 24' ($source.Contains('New-Object Drawing.Size(26, 24)'))
Write-Host ("LBS144 CHECKBOX TOTAL {0}/{0}" -f $script:checks)
if ($script:checks -ne 18) { throw "Expected 18 native checkbox checks, found $script:checks" }
