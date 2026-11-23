#requires -version 5.1
# LBS-206 v1.5.10.2: native owner-painted Standardziel menu edge and true reset tooltip.
# This fixture never changes a boot target, firmware, settings or task broker.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\MenuAppearance.ps1')
. (Join-Path $root 'src\UI\DefaultTargetMenu.ps1')
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$start = $template.IndexOf($prefix,[StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Canonical C# menu renderer start not found' }
$start += $prefix.Length
$endMarker = '"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing'
$end = $template.IndexOf($endMarker,$start,[StringComparison]::Ordinal)
if ($end -le $start) { throw 'Canonical C# menu renderer end not found' }
$rendererSource = $template.Substring($start,$end-$start)
Add-Type -TypeDefinition $rendererSource -ReferencedAssemblies System.Windows.Forms,System.Drawing -ErrorAction Stop

$script:ColorPrimary = [Drawing.Color]::FromArgb(252,252,252)
$script:MenuRenderer = New-Object LenovoMenuRenderer
$script:DefaultGuid = '{11111111-2222-3333-4444-555555555555}'
$script:Checks = 0
function Assert-Lbs206Edge([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS206_EDGE_RED: $Name" }
    $script:Checks++
    Write-Host "PASS LBS206_EDGE $Name"
}
function Get-LocalizedString { param([string]$Key,$Values)
    return (Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values)
}
function Get-OrderedEntriesForUi { return @(
    [pscustomobject]@{ Guid=$script:DefaultGuid;Title='Lenovo Boot-Menü' },
    [pscustomobject]@{ Guid='{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}';Title='Windows: Gaming' })
}
function Get-EntryDisplayTitle { param($Entry) return [string]$Entry.Title }
function Get-Lbs206Luminance([int]$Channel) {
    $v = [double]$Channel / 255.0
    if ($v -le 0.04045) { return ($v / 12.92) }
    return [Math]::Pow((($v + 0.055)/1.055),2.4)
}
function Get-Lbs206Contrast([Drawing.Color]$A,[Drawing.Color]$B) {
    $x = 0.2126 *(Get-Lbs206Luminance $A.R) + 0.7152 *(Get-Lbs206Luminance $A.G) + 0.0722 *(Get-Lbs206Luminance $A.B)
    $y = 0.2126 *(Get-Lbs206Luminance $B.R) + 0.7152 *(Get-Lbs206Luminance $B.G) + 0.0722 *(Get-Lbs206Luminance $B.B)
    return ([Math]::Max($x,$y)+0.05)/([Math]::Min($x,$y)+0.05)
}
$method = [LenovoMenuRenderer].GetMethod('OnRenderToolStripBackground',([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
if (-not $method) { throw 'Canonical native renderer background method unavailable' }
$surface = [Drawing.Color]::FromArgb(25,25,25)
$list = [Drawing.Color]::FromArgb(31,31,31)
$background = [Drawing.Color]::FromArgb(22,22,22)
$edge = [Drawing.Color]::FromArgb(108,108,108)
Assert-Lbs206Edge 'neutral contrast target is >=3:1 versus settings and list' (
    (Get-Lbs206Contrast $edge $surface) -ge 3.0 -and (Get-Lbs206Contrast $edge $list) -ge 3.0)
foreach ($locale in @('de-DE','en-US')) {
    $script:Locale = $locale
    $hint = Get-LocalizedString -Key 'BootNext.UseDefaultHint' -Values @{ Default='Lenovo Boot-Menü' }
    if ($locale -eq 'de-DE') {
        Assert-Lbs206Edge 'German tooltip describes replacement, persisted default and no restart' (
            $hint -match '(?i)(ersetzt|zurück)' -and $hint.Contains('Lenovo Boot-Menü') -and
            $hint -match '(?i)(nicht.*neu gestartet|kein Neustart)' -and $hint -notmatch 'vormerken')
    }
    else {
        Assert-Lbs206Edge 'English tooltip describes replacement, persisted default and no restart' (
            $hint -match '(?i)(replaces|reset)' -and $hint.Contains('Lenovo Boot-Menü') -and
            $hint -match '(?i)(does not restart|no restart)' -and $hint -notmatch '^Set ')
    }
    foreach ($scale in @(1.0,2.5)) {
        $menu = New-DefaultTargetMenu
        $menu.Name = 'DefaultTargetContextMenu'
        $tag = "$locale/$scale"
        try {
            $menu.Size = [Drawing.Size]::new([int](260*$scale),[int](150*$scale))
            $canvas = [Drawing.Bitmap]::new($menu.Width,$menu.Height)
            $canvas.SetResolution([single](96*$scale),[single](96*$scale))
            $g = [Drawing.Graphics]::FromImage($canvas)
            try {
                $g.Clear([Drawing.Color]::Black)
                $render = [System.Windows.Forms.ToolStripRenderEventArgs]::new($g,$menu)
                [void]$method.Invoke($script:MenuRenderer,[object[]]@($render))
                $edgeX = if ($scale -ge 2.0) { 1 } else { 0 }
                $paintedEdge = $canvas.GetPixel($edgeX,[int]($menu.Height/2))
                $paintedFill = $canvas.GetPixel([int]($menu.Width/2),[int]($menu.Height-15))
                Assert-Lbs206Edge "$tag real renderer paints distinct neutral outer menu edge" (
                    [Math]::Abs([int]$paintedEdge.R-108) -le 6 -and
                    [Math]::Abs([int]$paintedEdge.G-108) -le 6 -and
                    [Math]::Abs([int]$paintedEdge.B-108) -le 6)
                Assert-Lbs206Edge "$tag existing dark interior and text color remain unchanged" (
                    $paintedFill.ToArgb() -eq $background.ToArgb() -and
                    $menu.ForeColor.ToArgb() -eq $script:ColorPrimary.ToArgb())
                Assert-Lbs206Edge "$tag rendered edge meets 3:1 against adjacent surfaces" (
                    (Get-Lbs206Contrast $paintedEdge $surface) -ge 3.0 -and
                    (Get-Lbs206Contrast $paintedEdge $list) -ge 3.0)
            }
            finally { $g.Dispose(); $canvas.Dispose() }
        }
        finally { $menu.Dispose() }
    }
}
# The menu outline must be localized to the named Standardziel root menu.
$otherMenu = New-Object LenovoContextMenuStrip
# A real ToolStrip has items and a non-empty client raster. An empty, auto-
# sized WinForms dropdown may report a zero-width ClientRectangle on CI.
[void]$otherMenu.Items.Add('Tray option')
$otherMenu.AutoSize = $false
$otherMenu.Size = [Drawing.Size]::new(260,150)
$otherCanvas = [Drawing.Bitmap]::new(260,150)
$otherG = [Drawing.Graphics]::FromImage($otherCanvas)
try {
    $otherG.Clear([Drawing.Color]::Black)
    $render = [System.Windows.Forms.ToolStripRenderEventArgs]::new($otherG,$otherMenu)
    [void]$method.Invoke($script:MenuRenderer,[object[]]@($render))
    $trayPixel = $otherCanvas.GetPixel(0,75)
    Write-Host ("LBS206_EDGE_TRAY_PIXEL={0},{1},{2}" -f $trayPixel.R,$trayPixel.G,$trayPixel.B)
    Assert-Lbs206Edge 'unrelated tray menu does not receive Standardziel outline' (
        $trayPixel.ToArgb() -eq $background.ToArgb())
}
finally { $otherG.Dispose(); $otherCanvas.Dispose(); $otherMenu.Dispose() }
Write-Host "LBS206 EDGE TOTAL $script:Checks"
