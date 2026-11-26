#requires -version 5.1
# LBS-252: actual main-popup header and capability-driven native Button state.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$template = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix = 'Add-Type -TypeDefinition @"'
$begin = $template.IndexOf($prefix,[StringComparison]::Ordinal)
if ($begin -lt 0) { throw 'Missing canonical WinForms C# source' }
$begin += $prefix.Length
$end = $template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($end -lt 0) { throw 'Missing canonical WinForms C# source end' }
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Application\SystemCapabilities.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\ManageEntries.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:ColorHeader=[Drawing.Color]::Black
$script:ColorBackground=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorSecondary=[Drawing.Color]::FromArgb(184,184,184)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(44,25,24)
$script:IsManageEntriesMode=$false
$script:ManageCalls=0
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-CurrentSystemFunctionsCapabilities {
    Resolve-SystemFunctionsCapabilities -FactsValid $true -InstallationPresent $true -MetadataCompatible $true -SessionReady $script:SessionReady -MaintenanceBusy $false -DriftDetected $false -EntryCount 1
}
# Fixture isolates unrelated actions and label creation; the target button
# and its Enabled transition are created and owned by production functions.
function New-Label {
    param($Text,$Font,$ForeColor,$X,$Y,$Width,$Height)
    $label=[Windows.Forms.Label]::new()
    $label.Text=$Text; $label.Font=$Font; $label.ForeColor=$ForeColor
    $label.Bounds=[Drawing.Rectangle]::new($X,$Y,$Width,$Height)
    return $label
}
function Update-RefreshButtonVisual {}
function Start-ManageEntriesMode { $script:ManageCalls++ }
function Get-ScreenState([Windows.Forms.Button]$Button) {
    $Button.Refresh()
    [Windows.Forms.Application]::DoEvents()
    $bm=[Drawing.Bitmap]::new($Button.Width,$Button.Height)
    $g=[Drawing.Graphics]::FromImage($bm)
    try {
        $g.CopyFromScreen($Button.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$Button.ClientSize)
        $surface=$bm.GetPixel(1,1).ToArgb()
        $frame=0
        for ($x=4; $x -lt $bm.Width-4; $x++) { if ($bm.GetPixel($x,3).ToArgb() -ne $surface) { $frame++ } }
        $hoverPixels=0
        $hoverInk=[Drawing.Color]::FromArgb(255,110,102).ToArgb()
        for ($y=4;$y -lt $bm.Height-4;$y++) {
            for ($x=4;$x -lt $bm.Width-4;$x++) { if ($bm.GetPixel($x,$y).ToArgb() -eq $hoverInk) { $hoverPixels++ } }
        }
        return [pscustomobject]@{Surface=$surface;Frame=$frame;HoverPixels=$hoverPixels}
    } finally { $g.Dispose(); $bm.Dispose() }
}
function Move-TestPointer($Control,[int]$X,[int]$Y) {
    [Windows.Forms.Cursor]::Position=$Control.PointToScreen([Drawing.Point]::new($X,$Y))
    $sw=[Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 120) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
}
function Get-VisibleInk([Windows.Forms.Button]$Button) {
    $form = $Button.FindForm()
    $bounds = $Button.RectangleToScreen($Button.ClientRectangle)
    $bm=[Drawing.Bitmap]::new($Button.Width,$Button.Height)
    $g=[Drawing.Graphics]::FromImage($bm)
    try {
        # A newly shown/scaled HWND may not yet be present in the compositor.
        # Retry only acquisition validity, never a measured contrast or ink failure.
        $valid=$false
        for ($attempt=1;$attempt -le 5;$attempt++) {
            [Windows.Forms.Application]::DoEvents()
            $Button.Refresh()
            [Windows.Forms.Application]::DoEvents()
            $g.CopyFromScreen($bounds.Location,[Drawing.Point]::Empty,$Button.ClientSize)
            $actual=$bm.GetPixel(2,2).ToArgb()
            $expected=$Button.BackColor.ToArgb()
            $center=[Drawing.Point]::new($bounds.Left+[int]($bounds.Width/2),$bounds.Top+[int]($bounds.Height/2))
            $hit=[Lbs252Native]::WindowFromPoint($center)
            $rootHit=[Lbs252Native]::GetAncestor($hit,2)
            $sameBounds=$Button.RectangleToScreen($Button.ClientRectangle) -eq $bounds
            $pointerOutside=-not $bounds.Contains([Windows.Forms.Cursor]::Position)
            $valid=$form.Visible -and $Button.Visible -and $form.ContainsFocus -and $sameBounds -and $pointerOutside -and ($rootHit -eq $form.Handle) -and ($actual -eq $expected)
            Write-Host "LBS252 INK FRAME locale=$script:Locale scale=$scale enabled=$($Button.Enabled) attempt=$attempt valid=$valid actual=$actual expected=$expected focus=$($form.ContainsFocus) bounds=$bounds sameBounds=$sameBounds pointerOutside=$pointerOutside hitRoot=$rootHit expectedRoot=$($form.Handle)"
            if ($valid) { break }
            if ($attempt -lt 5) { Start-Sleep -Milliseconds 50 }
        }
        if (-not $valid) { throw 'LBS252 fixture background not visible or screen ownership invalid after 5 acquisitions; no visual conclusion' }
        $peak=0; $bright=0
        $levels=[Collections.Generic.Dictionary[int,int]]::new()
        $background=$Button.BackColor.R
        # Ignore perimeter: native default/focus frame is not text ink.
        for ($y=4;$y -lt $bm.Height-4;$y++) {
            for ($x=4;$x -lt $bm.Width-4;$x++) {
                $p=$bm.GetPixel($x,$y)
                $v=[int][Math]::Round(0.2126*$p.R+0.7152*$p.G+0.0722*$p.B)
                $peak=[Math]::Max($peak,$v)
                if ($v -ge 120) { $bright++ }
                if ($v -gt $background) { $levels.Add($y*$bm.Width+$x,$v) }
            }
        }
        # Compare normalized ink coverage rather than absolute brightness.
        # The two states deliberately use different foreground colors.
        $mask=[Collections.Generic.HashSet[int]]::new()
        $minX=$bm.Width; $minY=$bm.Height; $maxX=-1; $maxY=-1
        foreach ($key in $levels.Keys) {
            if (($levels[$key]-$background)*2 -lt ($peak-$background)) { continue }
            [void]$mask.Add($key)
            $x=$key % $bm.Width; $y=[int][Math]::Floor($key/$bm.Width)
            $minX=[Math]::Min($minX,$x); $minY=[Math]::Min($minY,$y)
            $maxX=[Math]::Max($maxX,$x); $maxY=[Math]::Max($maxY,$y)
        }
        return [pscustomobject]@{Peak=$peak;Bright=$bright;Mask=$mask;Bounds="$minX,$minY,$maxX,$maxY";Levels=$levels;Background=$background}
    } finally { $g.Dispose(); $bm.Dispose() }
}
$failures=[Collections.Generic.List[string]]::new()
$checks=0
$typographyFailures=[Collections.Generic.List[string]]::new()
$interactionFailures=[Collections.Generic.List[string]]::new()
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs252Native {
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(System.Drawing.Point point);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
}
'@ -ReferencedAssemblies System.Drawing
$savedCursor=[Windows.Forms.Cursor]::Position
foreach ($locale in @('de-DE','en-US')) {
    foreach ($scale in @(1.0,2.5)) {
        $script:Locale=$locale
        $script:SessionReady=$null
        $form=[Windows.Forms.Form]::new()
        $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
        $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
        $form.Location=[Drawing.Point]::new(0,0)
        $form.TopMost=$true
        $script:Popup=$form
        try {
            Initialize-PopupDpiLayout -Form $form
            $form.ClientSize=[Drawing.Size]::new(390,100)
            $panel=[Windows.Forms.Panel]::new()
            $panel.Size=$form.ClientSize
            $panel.BackColor=$script:ColorBackground
            $form.Controls.Add($panel)
            Add-PopupHeaderSection -Root $panel
            $button=$script:ManageEntriesButton
            Complete-PopupDpiLayout -Form $form -Scale $scale
            Update-ManageEntriesUiState
            $form.Show()
            $form.Activate()
            [Windows.Forms.Cursor]::Position=$form.PointToScreen([Drawing.Point]::new(5,5))
            [Windows.Forms.Application]::DoEvents()
            if ($button.Enabled -or $button.CanSelect -or $button.Text -ne (Get-LocalizedString -Key 'Popup.Customize')) { throw 'LBS252 fixture invalid Checking gate or localized label' }
            $before=$script:ManageCalls
            $button.PerformClick()
            if ($script:ManageCalls -ne $before) { throw 'LBS252 disabled action dispatched' }
            $fontBefore=$button.Font.ToString()
            $boundsBefore=$button.Bounds
            $disabled=Get-VisibleInk $button
            $script:SessionReady=$true
            Update-ManageEntriesUiState
            $form.ActiveControl=$script:RefreshButton
            [Windows.Forms.Application]::DoEvents()
            $enabled=Get-VisibleInk $button
            if (-not $button.Enabled -or -not $button.CanSelect -or $enabled.Peak -lt 160 -or $enabled.Bright -lt 10) { throw 'LBS252 fixture invalid Ready gate or visible text' }
            $button.PerformClick()
            if ($script:ManageCalls -ne $before+1) { throw 'LBS252 enabled native dispatch lost' }
            Write-Host "LBS252 RASTER locale=$locale scale=$scale disabledPeak=$($disabled.Peak) disabledBright=$($disabled.Bright) enabledPeak=$($enabled.Peak) enabledBright=$($enabled.Bright)"
            if ($disabled.Peak -ge 120 -and $disabled.Peak -lt $enabled.Peak -and $disabled.Bright -ge 10) {
                $checks++
                Write-Host "PASS LBS252 $locale $scale disabled ink legible and subdued"
            } else { $failures.Add("$locale $scale") }
            if ($button.Font.ToString() -cne $fontBefore -or $button.Bounds -ne $boundsBefore) { throw 'LBS252 fixture changed font or control geometry across state transition' }
            if ($disabled.Mask.Count -lt 10 -or $enabled.Mask.Count -lt 10) { throw 'LBS252 typography fixture has insufficient visible ink' }
            $common=0
            foreach ($pixel in $disabled.Mask) { if ($enabled.Mask.Contains($pixel)) { $common++ } }
            $union=$disabled.Mask.Count+$enabled.Mask.Count-$common
            $overlap=$common/[double]$union
            # Integrated normalized alpha difference also detects stroke-weight
            # changes that do not change the thresholded bounding rectangle.
            $all=[Collections.Generic.HashSet[int]]::new()
            $all.UnionWith($disabled.Levels.Keys); $all.UnionWith($enabled.Levels.Keys)
            $delta=0.0; $coverage=0.0
            foreach ($pixel in $all) {
                $a=if ($disabled.Levels.ContainsKey($pixel)) { ($disabled.Levels[$pixel]-$disabled.Background)/[double]($disabled.Peak-$disabled.Background) } else { 0.0 }
                $b=if ($enabled.Levels.ContainsKey($pixel)) { ($enabled.Levels[$pixel]-$enabled.Background)/[double]($enabled.Peak-$enabled.Background) } else { 0.0 }
                $delta+=[Math]::Abs($a-$b); $coverage+=[Math]::Max($a,$b)
            }
            $difference=$delta/$coverage
            Write-Host "LBS252 TYPOGRAPHY locale=$locale scale=$scale disabledBounds=$($disabled.Bounds) enabledBounds=$($enabled.Bounds) overlap=$overlap normalizedDifference=$difference"
            if ($disabled.Bounds -ceq $enabled.Bounds -and $overlap -ge 0.95 -and $difference -le 0.08) {
                $checks++
                Write-Host "PASS LBS252 $locale $scale glyph geometry and normalized coverage agree"
            } else { $typographyFailures.Add("$locale $scale") }
            # Verify the new renderer does not lose native hover, focus or
            # keyboard admission. The action is a counter-only fixture.
            Move-TestPointer $button ([int]($button.Width/2)) ([int]($button.Height/2))
            $hover=Get-ScreenState $button
            Move-TestPointer $form 5 5
            $idle=Get-ScreenState $button
            [void]$button.Focus()
            [void][Lbs252Native]::SendMessage($form.Handle,0x127,[IntPtr]0x10002,[IntPtr]::Zero)
            [void][Lbs252Native]::SendMessage($button.Handle,0x128,[IntPtr]0x10002,[IntPtr]::Zero)
            $focused=Get-ScreenState $button
            $hadFocus=$button.Focused
            [Windows.Forms.SendKeys]::SendWait(' ')
            [Windows.Forms.Application]::DoEvents()
            $keyboardDispatch=($script:ManageCalls -eq $before+2)
            $form.ActiveControl=$script:RefreshButton
            [Windows.Forms.Application]::DoEvents()
            $unfocused=Get-ScreenState $button
            $script:SessionReady=$null
            Update-ManageEntriesUiState
            Move-TestPointer $button ([int]($button.Width/2)) ([int]($button.Height/2))
            $disabledHover=Get-ScreenState $button
            $button.PerformClick()
            $blocked=($script:ManageCalls -eq $before+2 -and -not $button.CanSelect)
            Move-TestPointer $form 5 5
            Write-Host "LBS252 INTERACTION locale=$locale scale=$scale hover=$($hover.Surface) idle=$($idle.Surface) focus=$hadFocus frame=$($focused.Frame) unfocused=$($unfocused.Frame) keyboard=$keyboardDispatch disabledBlocked=$blocked"
            $hoverInkValid=$idle.HoverPixels -eq 0 -and $disabledHover.HoverPixels -eq 0 -and $(if ([Windows.Forms.SystemInformation]::HighContrast) {$hover.HoverPixels -eq 0} else {$hover.HoverPixels -gt 0})
            if ($hoverInkValid -and $hover.Surface -eq $button.FlatAppearance.MouseOverBackColor.ToArgb() -and $idle.Surface -eq $button.BackColor.ToArgb() -and $hadFocus -and $focused.Frame -ge 4 -and $unfocused.Frame -eq 0 -and $keyboardDispatch -and $blocked -and $disabledHover.Surface -eq $button.BackColor.ToArgb()) {
                $checks++
                Write-Host "PASS LBS252 $locale $scale hover focus keyboard and disabled admission retained"
            } else { $interactionFailures.Add("$locale $scale") }
        } finally { $form.Dispose(); $script:Popup=$null; $script:ManageEntriesButton=$null; $script:RefreshButton=$null }
    }
}
[Windows.Forms.Cursor]::Position=$savedCursor
Write-Host "LBS252 CUSTOMIZE TOTAL $checks/12"
if ($failures.Count) { throw ("LBS252 RED: disabled ink contrast: " + ($failures -join ', ')) }
if ($typographyFailures.Count) { throw ("LBS252 TYPOGRAPHY RED: " + ($typographyFailures -join ', ')) }
if ($interactionFailures.Count) { throw ("LBS252 INTERACTION FAIL: " + ($interactionFailures -join ', ')) }
