#requires -version 5.1
# LBS-166: native WinForms reorder grip optical footprint, DPI and interaction contract.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
function Check([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS166 FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS166 $Name"
}
function Get-LocalizedString { param([string]$Key) return $Key }
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,
          [int]$X,[int]$Y,[int]$Width,[int]$Height)
    $c = New-Object System.Windows.Forms.Label
    $c.Text = $Text
    $c.Font = $Font
    $c.ForeColor = $ForeColor
    $c.Location = [Drawing.Point]::new($X,$Y)
    $c.Size = [Drawing.Size]::new($Width,$Height)
    return $c
}
function Measure-GripInk {
    param([Parameter(Mandatory=$true)][Drawing.Bitmap]$Bitmap)
    $count = 0
    $left = $Bitmap.Width; $top = $Bitmap.Height; $right = -1; $bottom = -1
    for ($y=0; $y -lt $Bitmap.Height; $y++) {
        for ($x=0; $x -lt $Bitmap.Width; $x++) {
            $p = $Bitmap.GetPixel($x,$y)
            if ($p.R -ge 95 -and $p.R -le 190 -and
                [Math]::Abs($p.R-$p.G) -le 2 -and [Math]::Abs($p.R-$p.B) -le 2) {
                $count++; $left = [Math]::Min($left,$x); $right = [Math]::Max($right,$x)
                $top = [Math]::Min($top,$y); $bottom = [Math]::Max($bottom,$y)
            }
        }
    }
    return [pscustomobject]@{
        Count=$count; Left=$left; Top=$top; Right=$right; Bottom=$bottom
        Width=($right-$left+1); Height=($bottom-$top+1)
    }
}
Check 'DPI grip solver is present' ($null -ne (Get-Command Get-LenovoManageGripGlyphGeometry -ErrorAction SilentlyContinue))
$cases = @(
    @{P=100;Dpi=96;W=26;H=34;InkW=18;Span=12;EyeW=20;EyeH=12},
    @{P=125;Dpi=120;W=33;H=43;InkW=23;Span=15;EyeW=25;EyeH=15},
    @{P=150;Dpi=144;W=39;H=51;InkW=27;Span=18;EyeW=30;EyeH=18},
    @{P=200;Dpi=192;W=52;H=68;InkW=36;Span=24;EyeW=40;EyeH=24},
    @{P=250;Dpi=240;W=65;H=85;InkW=45;Span=30;EyeW=50;EyeH=30},
    @{P=300;Dpi=288;W=78;H=102;InkW=54;Span=36;EyeW=60;EyeH=36}
)
foreach ($c in $cases) {
    $g = Get-LenovoManageGripGlyphGeometry -ClientSize ([Drawing.Size]::new($c.W,$c.H)) -Dpi ([double]$c.Dpi)
    Check "$($c.P)% grip width and vertical span scale once" ($g.Width -eq $c.InkW -and $g.Span -eq $c.Span)
    Check "$($c.P)% grip stays centered in action column" ([Math]::Abs($g.StartX+$g.EndX-($c.W-1)) -lt 0.01 -and [Math]::Abs($g.TopY+$g.BottomY-($c.H-1)) -lt 0.01)
    Check "$($c.P)% rounded ink stays entirely inside hit target" ($g.StartX-$g.Stroke/2 -ge 0 -and $g.EndX+$g.Stroke/2 -le $c.W-1 -and $g.TopY-$g.Stroke/2 -ge 0 -and $g.BottomY+$g.Stroke/2 -le $c.H-1)
    Check "$($c.P)% ink footprint comparable to visibility eye" ($g.Width/$c.EyeW -ge 0.8 -and $g.Width/$c.EyeW -le 1.05 -and ($g.Span+$g.Stroke)/$c.EyeH -ge 0.9 -and ($g.Span+$g.Stroke)/$c.EyeH -le 1.3)
}
$small = Get-LenovoManageGripGlyphGeometry -ClientSize ([Drawing.Size]::new(12,9)) -Dpi 240
Check 'Small control clamps DPI stroke and spacing' ($small.Width -le 12 -and $small.Stroke -le $small.Width -and $small.TopY -ge 0 -and $small.BottomY -le 8)
$source = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
Check 'The real paint event uses the shared DPI renderer' ($source.Contains('Paint-LenovoManageGripGlyph -Graphics $eventArgs.Graphics -ClientSize $sender.ClientSize'))
Check 'Existing pencil text, eye and drag hookups preserved' ($source.Contains("-Text '$([char]0x270E)'") -and $source.Contains('Get-LenovoManageEyeGlyphGeometry') -and $source.Contains('$control.Add_MouseDown($mouseDownHandler)') -and -not $source.Contains("-Text '$([char]0x2261)'"))
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$row = New-Object System.Windows.Forms.Panel
$row.Size = [Drawing.Size]::new(390,60)
$row.BackColor = [Drawing.Color]::FromArgb(32,32,32)
$dummy = New-Object System.Windows.Forms.Label
$entry = [pscustomobject]@{Guid='85b504b5-cc63-4e0b-b1b5-acf4006325b2'}
try {
    $controls = @(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden $false -Marker $dummy -Icon $dummy -Title $dummy -Subtitle $dummy)
    $grip = $row.Controls['ManageReorderGrip']
    $eye = $row.Controls['VisibilityGlyph']
    $pencil = $row.Controls['AliasEditButton']
    Check 'Native reorder handle uses owner-drawn Panel' ($null -ne $grip -and $grip -is [Windows.Forms.Panel])
    Check 'Existing grip column and 26x34 hit target' ($grip.Left -eq 350 -and $grip.Top -eq 12 -and $grip.Width -eq 26 -and $grip.Height -eq 34)
    Check 'Eye and pencil retain original geometry' ($eye.Left -eq 286 -and $eye.Width -eq 32 -and $pencil.Left -eq 321 -and $pencil.Width -eq 25)

    # Owner follow-up after v1.3.1.0: only the pencil font grows, not its hit area.
    Check 'Pencil uses the new 14pt optical font size' ([Math]::Abs($pencil.Font.SizeInPoints - 14.0) -lt 0.05)
    Check 'Pencil retains 25x34 click area and vertical centering' ($pencil.Top -eq 12 -and $pencil.Height -eq 34 -and $pencil.Width -eq 25 -and $pencil.TextAlign -eq [Drawing.ContentAlignment]::MiddleCenter)
    Check 'Pencil retains original identity and accessible hand action' ($pencil.Name -eq 'AliasEditButton' -and $pencil.Text -eq ([string][char]0x270E) -and $pencil.Cursor -eq [Windows.Forms.Cursors]::Hand -and [string]$pencil.Tag -eq $entry.Guid -and $pencil.AccessibleDescription -eq 'Manage.EditAliasAccessible')
    $oldPencilFont = New-Object Drawing.Font('Segoe UI Symbol', 12.0, [Drawing.FontStyle]::Regular)
    try {
        $oldInk = [Windows.Forms.TextRenderer]::MeasureText($pencil.Text,$oldPencilFont)
        $newInk = [Windows.Forms.TextRenderer]::MeasureText($pencil.Text,$pencil.Font)
        Check 'New pencil text metrics exceed previous 12pt baseline' ($newInk.Height -gt $oldInk.Height -and $newInk.Width -ge $oldInk.Width)
    }
    finally { $oldPencilFont.Dispose() }
    Check 'Grip retains SizeAll cursor, drop target and tag' ($grip.Cursor -eq [Windows.Forms.Cursors]::SizeAll -and $grip.AllowDrop -and [string]$grip.Tag -eq $entry.Guid)
    Check 'Grip retains same event hookup control collection' ($controls.Count -eq 7 -and $controls[6] -eq $grip)
    $native = New-Object Drawing.Bitmap(26,34)
    try {
        $grip.DrawToBitmap($native,[Drawing.Rectangle]::new(0,0,26,34))
        $ink = Measure-GripInk -Bitmap $native
        Check 'Native WinForms Paint produces materially visible strokes' ($ink.Count -ge 35)
        Check 'Native raster stays centered and not clipped' ($ink.Width -ge 14 -and $ink.Width -le 22 -and $ink.Height -ge 11 -and $ink.Height -le 18 -and $ink.Left -gt 0 -and $ink.Right -lt 25)
    }
    finally { $native.Dispose() }
    [void](Set-PopupBootRowDpiLayout -Row $row -Scale 2.5 -Y 0)
    Check '250% layout scales hit area once without scaling point font twice' (
        $pencil.Left -eq [int][Math]::Round(321*2.5) -and
        $pencil.Top -eq 30 -and
        $pencil.Width -eq [int][Math]::Round(25*2.5) -and
        $pencil.Height -eq 85 -and
        [Math]::Abs($pencil.Font.SizeInPoints - 14.0) -lt 0.05)
}
finally { $row.Dispose(); $dummy.Dispose() }
foreach ($c in @($cases[0],$cases[4])) {
    $bitmap = New-Object Drawing.Bitmap($c.W,$c.H)
    $bitmap.SetResolution([single]$c.Dpi,[single]$c.Dpi)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::FromArgb(32,32,32))
        Paint-LenovoManageGripGlyph -Graphics $graphics -ClientSize ([Drawing.Size]::new($c.W,$c.H)) -Color ([Drawing.Color]::FromArgb(145,145,145))
        $ink = Measure-GripInk -Bitmap $bitmap
        Check "$($c.P)% offscreen DPI raster visibly painted" ($ink.Count -gt (35*$c.Dpi/96.0))
        Check "$($c.P)% raster ink bounds match optical footprint" ($ink.Width -ge ($c.InkW-5) -and $ink.Width -le ($c.InkW+2) -and $ink.Height -ge ($c.Span-1) -and $ink.Height -le ($c.Span+8*$c.Dpi/96.0) -and $ink.Left -ge 0 -and $ink.Right -lt $c.W)
    }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
Write-Host "LBS166 GRIP TOTAL $script:checks/44"
if ($script:checks -ne 44) { throw "Expected 44 native grip/pencil checks, got $script:checks" }
