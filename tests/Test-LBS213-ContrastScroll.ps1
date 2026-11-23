#requires -version 5.1
# LBS-213: native isolated WinForms regression for semantic text/ink contrast and scrollbar hit tolerance.
# No product launch, hardware, TaskBroker, firmware, storage writes, reboot, or OS pointer injection.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$rows = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryRows.ps1'))
$script:checks = 0
function Assert-Lbs213([string]$Label,[bool]$Pass) {
    if (-not $Pass) { throw "LBS213 RED: $Label" }
    $script:checks++
    Write-Host "PASS LBS213 $Label"
}
function Get-Lbs213Luminance([Drawing.Color]$C) {
    $channels = @($C.R,$C.G,$C.B)
    $weights = @(0.2126,0.7152,0.0722)
    $l = 0.0
    for ($i=0; $i -lt 3; $i++) {
        $x = [double]$channels[$i] / 255.0
        $linear = if ($x -le 0.04045) { $x/12.92 } else { [Math]::Pow(($x+0.055)/1.055,2.4) }
        $l += $weights[$i] * $linear
    }
    return $l
}
function Get-Lbs213Contrast([Drawing.Color]$A,[Drawing.Color]$B) {
    $la = Get-Lbs213Luminance $A
    $lb = Get-Lbs213Luminance $B
    return ([Math]::Max($la,$lb)+0.05)/([Math]::Min($la,$lb)+0.05)
}
Assert-Lbs213 'Tray Open uses only the scoped light-red semantic ink' ($template.Contains('$openItem.ForeColor = [Drawing.Color]::FromArgb(255,110,102)'))
Assert-Lbs213 'Hidden storage glyph uses only the scoped readable neutral ink' ($rows.Contains('$iconColor = if ($isHidden) { [Drawing.Color]::FromArgb(115,115,115) } else { $entry.Accent }'))
Assert-Lbs213 'Scrollbar mouse-down hit test covers thumb height across control track' ($template.Contains('if (!thumb.IsEmpty && e.Y >= thumb.Top && e.Y < thumb.Bottom)'))
Assert-Lbs213 'Brand palette remains unmodified' ($template.Contains('$script:ColorAccent = [Drawing.Color]::FromArgb(225, 37, 27)'))
$lightRed = [Drawing.Color]::FromArgb(255,110,102)
$hiddenInk = [Drawing.Color]::FromArgb(115,115,115)
$rootBg = [Drawing.Color]::FromArgb(22,22,22)
$hotBg = [Drawing.Color]::FromArgb(64,31,29)
$normalHiddenBg = [Drawing.Color]::FromArgb(27,27,27)
$hoverHiddenBg = [Drawing.Color]::FromArgb(37,37,37)
Assert-Lbs213 'Tray Open text passes root contrast benchmark' ((Get-Lbs213Contrast $lightRed $rootBg) -ge 4.5)
Assert-Lbs213 'Tray Open text passes selected contrast benchmark' ((Get-Lbs213Contrast $lightRed $hotBg) -ge 4.5)
Assert-Lbs213 'Hidden symbol passes normal non-text guidance' ((Get-Lbs213Contrast $hiddenInk $normalHiddenBg) -ge 3.0)
Assert-Lbs213 'Hidden symbol passes hover non-text guidance' ((Get-Lbs213Contrast $hiddenInk $hoverHiddenBg) -ge 3.0)
$prefix = 'Add-Type -TypeDefinition @"'
$start = $template.IndexOf($prefix,[StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Canonical native renderer C# start missing.' }
$start += $prefix.Length
$end = $template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$start,[StringComparison]::Ordinal)
if ($end -le $start) { throw 'Canonical native renderer C# end missing.' }
Add-Type -TypeDefinition ($template.Substring($start,$end-$start)) -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop
$flags = [Reflection.BindingFlags]'Instance,NonPublic'
$paint = [Windows.Forms.ToolStripRenderer].GetMethod('OnRenderItemText',$flags)
if (-not $paint) { throw 'Canonical ToolStrip render entry point unavailable.' }
foreach ($dpi in @(96,240)) {
    $image = New-Object Drawing.Bitmap(700,140)
    $menu = New-Object LenovoContextMenuStrip
    $font = New-Object Drawing.Font('Segoe UI',9.0,[Drawing.FontStyle]::Bold)
    try {
        $image.SetResolution([single]$dpi,[single]$dpi)
        $item = New-Object Windows.Forms.ToolStripMenuItem('Open')
        $item.Font = $font
        $item.ForeColor = $lightRed
        $item.AutoSize = $false
        $item.Size = [Drawing.Size]::new(650,55)
        $menu.Width = 650
        [void]$menu.Items.Add($item)
        $menu.PerformLayout()
        $graphics = [Drawing.Graphics]::FromImage($image)
        try {
            $graphics.Clear($rootBg)
            $bounds = [Drawing.Rectangle]::new(45,0,570,55)
            $args = [Windows.Forms.ToolStripItemTextRenderEventArgs]::new($graphics,$item,'Open',$bounds,$item.ForeColor,$font,[Drawing.ContentAlignment]::MiddleLeft)
            [void]$paint.Invoke((New-Object LenovoMenuRenderer),@($args))
        }
        finally { $graphics.Dispose() }
        $ink = 0
        for ($y=0; $y -lt $image.Height; $y++) {
            for ($x=0; $x -lt $image.Width; $x++) {
                $pixel = $image.GetPixel($x,$y)
                if ([Math]::Abs($pixel.R-$lightRed.R) -le 20 -and
                    [Math]::Abs($pixel.G-$lightRed.G) -le 20 -and
                    [Math]::Abs($pixel.B-$lightRed.B) -le 20) { $ink++ }
            }
        }
        Assert-Lbs213 "$dpi DPI canonical tray text renderer paints the scoped light-red ink" ($ink -ge 3)
    }
    finally { $menu.Dispose(); $font.Dispose(); $image.Dispose() }
}
$thumbMethod = [LenovoVerticalScrollBar].GetMethod('GetThumbRectangle',$flags)
$down = [LenovoVerticalScrollBar].GetMethod('OnMouseDown',$flags)
$move = [LenovoVerticalScrollBar].GetMethod('OnMouseMove',$flags)
$up = [LenovoVerticalScrollBar].GetMethod('OnMouseUp',$flags)
if (-not $thumbMethod -or -not $down -or -not $move -or -not $up) { throw 'Canonical scrollbar mouse handlers missing.' }
foreach ($factor in @(1.0,2.5)) {
    $dpi = [int][Math]::Round(96*$factor)
    foreach ($location in @('left','inside','right','above','below')) {
        $bar = New-Object LenovoVerticalScrollBar
        try {
            $bar.Size = [Drawing.Size]::new([int][Math]::Round(8*$factor),[int][Math]::Round(402*$factor))
            $bar.Minimum = 0
            $bar.Maximum = [int][Math]::Round(1000*$factor)
            $bar.LargeChange = [int][Math]::Round(100*$factor)
            $bar.Value = [int][Math]::Round(500*$factor)
            $initial = [int]$bar.Value
            $thumb = [Drawing.Rectangle]$thumbMethod.Invoke($bar,@())
            if ($thumb.IsEmpty) { throw 'Scrollbar thumb unexpectedly empty.' }
            $x = switch ($location) { 'left' { 0 } 'inside' { [int]($thumb.Left+1) } 'right' { [int]($bar.Width-1) } default { [int]($thumb.Left+1) } }
            $y = switch ($location) { 'above' { [int]($thumb.Top-1) } 'below' { [int]($thumb.Bottom+1) } default { [int]($thumb.Top+[Math]::Floor($thumb.Height/2)) } }
            if ($y -lt 0 -or $y -ge $bar.Height) { throw "Invalid $location test coordinate." }
            $mouseDown = [Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,$x,$y,0)
            [void]$down.Invoke($bar,@($mouseDown))
            $afterDown = [int]$bar.Value
            $mouseMove = [Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,$x,([Math]::Min($bar.Height-1,$y+[int][Math]::Round(25*$factor))),0)
            [void]$move.Invoke($bar,@($mouseMove))
            $afterMove = [int]$bar.Value
            [void]$up.Invoke($bar,@([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,$x,$y,0)))
            if ($location -in @('left','inside','right')) {
                Assert-Lbs213 "$dpi DPI $location thumb-level click drags without paging" ($afterDown -eq $initial -and $afterMove -gt $initial)
            }
            elseif ($location -eq 'above') {
                Assert-Lbs213 "$dpi DPI above-thumb click still pages up" ($afterDown -eq ($initial-$bar.LargeChange) -and $afterMove -eq $afterDown)
            }
            else {
                Assert-Lbs213 "$dpi DPI below-thumb click still pages down" ($afterDown -eq ($initial+$bar.LargeChange) -and $afterMove -eq $afterDown)
            }
        }
        finally { $bar.Dispose() }
    }
}
Write-Host "LBS213 CONTRAST SCROLL TOTAL $script:checks/20"
if ($script:checks -ne 20) { throw "Expected 20 scoped regression assertions, got $script:checks" }
