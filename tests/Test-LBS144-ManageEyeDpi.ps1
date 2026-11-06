#requires -version 5.1
# LBS-144: native DPI-aware visibility eye and header refresh typography.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
$script:Count=0
function Check([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS144 EYE RED: $Name" }
    $script:Count++
    Write-Host "PASS LBS144 EYE $Name"
}
Check 'DPI-relative geometry function exists' ($null -ne (Get-Command Get-LenovoManageEyeGlyphGeometry -ErrorAction SilentlyContinue))
$cases=@(
    @{P=100;Dpi=96;W=32;H=34;EyeW=24;EyeH=14},
    @{P=125;Dpi=120;W=40;H=43;EyeW=30;EyeH=18},
    @{P=150;Dpi=144;W=48;H=51;EyeW=36;EyeH=21},
    @{P=200;Dpi=192;W=64;H=68;EyeW=48;EyeH=28},
    @{P=250;Dpi=240;W=80;H=85;EyeW=60;EyeH=35},
    @{P=300;Dpi=288;W=96;H=102;EyeW=72;EyeH=42}
)
foreach($c in $cases) {
    $g=Get-LenovoManageEyeGlyphGeometry -ClientSize ([Drawing.Size]::new($c.W,$c.H)) -Dpi ([double]$c.Dpi)
    Check ("{0}% ellipse is scaled once" -f $c.P) ($g.Eye.Width -eq $c.EyeW -and $g.Eye.Height -eq $c.EyeH)
    Check ("{0}% ellipse is centered and not clipped" -f $c.P) ($g.Eye.X -ge 0 -and $g.Eye.Y -ge 0 -and $g.Eye.Right -le $c.W -and $g.Eye.Bottom -le $c.H -and [Math]::Abs(2*$g.Eye.X+$g.Eye.Width-$c.W) -le 1 -and [Math]::Abs(2*$g.Eye.Y+$g.Eye.Height-$c.H) -le 1)
    Check ("{0}% pupil and hidden slash fit within control" -f $c.P) ($g.Pupil.Width -gt 0 -and $g.Pupil.Height -gt 0 -and $g.Pupil.Left -ge $g.Eye.Left -and $g.Pupil.Right -le $g.Eye.Right -and $g.Pupil.Top -ge $g.Eye.Top -and $g.Pupil.Bottom -le $g.Eye.Bottom -and $g.SlashStart.X -ge 0 -and $g.SlashStart.Y -lt $c.H -and $g.SlashEnd.X -lt $c.W -and $g.SlashEnd.Y -ge 0)
}
$small=Get-LenovoManageEyeGlyphGeometry -ClientSize ([Drawing.Size]::new(12,9)) -Dpi 240
Check 'Undersized panel clamps without drawing outside bounds' ($small.Eye.X -ge 0 -and $small.Eye.Y -ge 0 -and $small.Eye.Right -le 12 -and $small.Eye.Bottom -le 9)
$rows=[IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
$popup=[IO.File]::ReadAllText((Join-Path $root 'src\UI\PopupComposition.ps1'))
Check 'Actual Paint handler uses the coordinate solver from Graphics.DpiX' ($rows.Contains('Get-LenovoManageEyeGlyphGeometry -ClientSize $sender.ClientSize -Dpi $eventArgs.Graphics.DpiX'))
Check 'Refresh glyph increased to 15pt without changing button geometry' ($popup.Contains("Font('Segoe UI Symbol', 15.0,") -and $popup.Contains('$refresh.Size = New-Object Drawing.Size(34, 34)'))
Check 'Refresh retains existing guard and button behavior' ($popup.Contains('Start-BackgroundBootRefresh -RefreshStorage') -and $popup.Contains('if (Test-MaintenanceBusy) { return }'))
# Exercise the real owner-drawn row via WinForms' native Paint pipeline.
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,
          [int]$X,[int]$Y,[int]$Width,[int]$Height)
    $c=New-Object System.Windows.Forms.Label
    $c.Text=$Text
    $c.Font=$Font
    $c.ForeColor=$ForeColor
    $c.Location=[Drawing.Point]::new($X,$Y)
    $c.Size=[Drawing.Size]::new($Width,$Height)
    return $c
}
function Get-LocalizedString { param([string]$Key) return $Key }
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$row=New-Object System.Windows.Forms.Panel
$row.Size=[Drawing.Size]::new(390,60)
$row.BackColor=[Drawing.Color]::FromArgb(32,32,32)
$dummy=New-Object System.Windows.Forms.Label
$entry=[pscustomobject]@{Guid='85b504b5-cc63-4e0b-b1b5-acf4006325b2'}
try {
    $result=@(Add-ManageBootEntryControls -Row $row -Entry $entry -IsHidden $false -Marker $dummy -Icon $dummy -Title $dummy -Subtitle $dummy)
    $state=$row.Controls['VisibilityGlyph']
    Check 'Actual ManageEntries visibility glyph still has unchanged 32x34 hit target' ($null -ne $state -and $state.Width -eq 32 -and $state.Height -eq 34)
    $bitmap=New-Object Drawing.Bitmap(32,34)
    try {
        $state.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,32,34))
        $reds=0
        for($y=0;$y -lt 34;$y++){for($x=0;$x -lt 32;$x++){ $px=$bitmap.GetPixel($x,$y); if($px.R -gt 150 -and $px.G -lt 100 -and $px.B -lt 100){$reds++} }}
        Check 'Visible eye is materially painted in red in WinForms bitmap' ($reds -ge 20)
    } finally {$bitmap.Dispose()}
    $state.AccessibleName='hidden'
    $state.Invalidate()
    $bitmap=New-Object Drawing.Bitmap(32,34)
    try {
        $state.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,32,34))
        $grays=0
        for($y=0;$y -lt 34;$y++){for($x=0;$x -lt 32;$x++){ $px=$bitmap.GetPixel($x,$y); if($px.R -gt 80 -and $px.R -lt 160 -and [Math]::Abs($px.R-$px.G) -le 2 -and [Math]::Abs($px.R-$px.B) -le 2){$grays++} }}
        Check 'Hidden eye and slash render in gray through real WinForms Paint' ($grays -ge 20)
    } finally {$bitmap.Dispose()}
} finally {$row.Dispose();$dummy.Dispose()}
Write-Host "LBS144 EYE TOTAL $script:Count/26"
if($script:Count -ne 26){throw "Expected 26 native eye and refresh checks; got $script:Count"}
