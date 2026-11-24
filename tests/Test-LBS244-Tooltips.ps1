#requires -version 5.1
# LBS-244: real WinForms component construction, measurement, raster and lifecycle.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src/UI/MenuAppearance.ps1')
$script:checks = 0
function Assert-Lbs244([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS244 FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS244 $Name"
}
$form = [Windows.Forms.Form]::new()
$form.Size = [Drawing.Size]::new(320,180)
$a = [Windows.Forms.Button]::new()
$b = [Windows.Forms.Button]::new()
$b.Top = 40
$form.Controls.Add($a)
$form.Controls.Add($b)
$auto = New-LenovoDarkTooltip -Animate
$manual = New-LenovoDarkTooltip -InitialDelay 0 -ReshowDelay 0 -AutoPopDelay 3500
$aux = New-LenovoDarkTooltip -Animate
try {
    Assert-Lbs244 'three independently owned instances' ($auto -ne $manual -and $manual -ne $aux -and $auto -ne $aux)
    Assert-Lbs244 'automatic native delay and animation retained' ($auto.InitialDelay -eq 350 -and $auto.ReshowDelay -eq 100 -and $auto.AutoPopDelay -eq 8000 -and $auto.UseAnimation -and $auto.UseFading)
    Assert-Lbs244 'manual native timing retained' ($manual.InitialDelay -eq 0 -and $manual.ReshowDelay -eq 0 -and $manual.AutoPopDelay -eq 3500 -and -not $manual.UseAnimation -and -not $manual.UseFading)
    Assert-Lbs244 'high contrast native fallback or dark owner drawing' ($auto.OwnerDraw -eq (-not [Windows.Forms.SystemInformation]::HighContrast))
    $auto.SetToolTip($a,'Boot & target')
    $aux.SetToolTip($a,'Other context')
    Assert-Lbs244 'registration is independent and ampersand literal' ($auto.GetToolTip($a) -eq 'Boot & target' -and $aux.GetToolTip($a) -eq 'Other context' -and -not $auto.StripAmpersands)
    $work = [Drawing.Rectangle]::new(-1920,-100,1920,1080)
    $anchor = [Drawing.Rectangle]::new(-25,950,20,20)
    foreach ($scale in @(1.0,2.5)) {
        $short = [LenovoDarkTooltip]::MeasureHint('Confirmed next boot target',$scale,$work)
        $longText = ('Bestaetigtes Bootziel & ' + ('Long firmware description with many words. ' * 12))
        $long = [LenovoDarkTooltip]::MeasureHint($longText,$scale,$work)
        $multi = [LenovoDarkTooltip]::MeasureHint(('One line'+[Environment]::NewLine+'Second line'+[Environment]::NewLine+'Third line'),$scale,$work)
        Assert-Lbs244 "long text wraps at $scale" ($long.Height -gt $short.Height -and $long.Width -le [Math]::Round(340*$scale))
        Assert-Lbs244 "multiline height at $scale" ($multi.Height -gt $short.Height)
        $point = [LenovoDarkTooltip]::PlaceHint($anchor,$long,$work,$scale)
        Assert-Lbs244 "negative-origin work-area bounds at $scale" ($work.Contains([Drawing.Rectangle]::new($point,$long)))
        $image = [Drawing.Bitmap]::new($long.Width,$long.Height)
        $graphics = [Drawing.Graphics]::FromImage($image)
        try {
            [LenovoDarkTooltip]::PaintHint($graphics,[Drawing.Rectangle]::new([Drawing.Point]::Empty,$long),$longText,$scale)
            Assert-Lbs244 "actual dark raster at $scale" ($image.GetPixel(2,2).ToArgb() -eq [Drawing.Color]::FromArgb(28,28,28).ToArgb())
            Assert-Lbs244 "actual border raster at $scale" ($image.GetPixel(0,0).ToArgb() -eq [Drawing.Color]::FromArgb(76,76,76).ToArgb())
            $foundInk = $false
            for ($y=7;$y -lt $image.Height-7 -and -not $foundInk;$y+=2) {
                for ($x=8;$x -lt $image.Width-8;$x+=2) {
                    if ($image.GetPixel($x,$y).R -gt 150) { $foundInk = $true; break }
                }
            }
            Assert-Lbs244 "actual light text raster at $scale" $foundInk
        }
        finally { $graphics.Dispose(); $image.Dispose() }
    }
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $manual.ShowManual($a,'First hint')
    Assert-Lbs244 'first manual owner' ($manual.ManualOwner -eq $a)
    $manual.ShowManual($b,'Second hint')
    Assert-Lbs244 'owner changes without stale previous owner' ($manual.ManualOwner -eq $b)
    $a.Hide()
    Assert-Lbs244 'previous owner hide does not clear new owner' ($manual.ManualOwner -eq $b)
    $b.Hide()
    Assert-Lbs244 'current owner hide clears manual owner' ($null -eq $manual.ManualOwner)
    $a.Show()
    $manual.ShowManual($a,'Third hint')
    $a.Dispose()
    Assert-Lbs244 'disposed owner clears manual owner' ($null -eq $manual.ManualOwner)
    $auto.SetToolTip($b,'Retained registration')
    $aux.Dispose()
    Assert-Lbs244 'auxiliary disposal leaves automatic registration' ($auto.GetToolTip($b) -eq 'Retained registration')
}
finally { $manual.Dispose(); $auto.Dispose(); $aux.Dispose(); $form.Dispose() }
if ($script:checks -ne 23) { throw "LBS244 unexpected assertion count: $script:checks" }
Write-Host "LBS244 TOOLTIP TOTAL $script:checks/23"
