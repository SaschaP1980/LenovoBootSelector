#requires -version 5.1
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::FromArgb(184,184,184)
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorWarning=[Drawing.Color]::FromArgb(236,191,68)
$script:ColorCyan=[Drawing.Color]::FromArgb(66,203,213)
$script:Checks=0
$onKeyDown=[Windows.Forms.Control].GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic')
function Assert-Dialog([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "LBS242 FAIL: $Name" }
    $script:Checks++
    Write-Host "PASS LBS242 $Name"
}
function Get-LocalizedString {
    param([string]$Key,[System.Collections.IDictionary]$Values)
    Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values
}
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,[int]$X,[int]$Y,[int]$Width,[int]$Height)
    $label=New-Object Windows.Forms.Label
    $label.Text=$Text
    $label.Font=$Font
    $label.ForeColor=$ForeColor
    $label.Bounds=[Drawing.Rectangle]::new($X,$Y,$Width,$Height)
    return $label
}
$src=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
# Compile the complete canonical WinForms block in one assembly so the
# scrollbar and action buttons resolve the shared interaction palette.
$prefix='Add-Type -TypeDefinition @"'
$begin=$src.IndexOf($prefix,[StringComparison]::Ordinal)
if ($begin -lt 0) { throw 'Missing canonical WinForms C# source' }
$begin+=$prefix.Length
$end=$src.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($end -lt 0) { throw 'Missing canonical WinForms C# source end' }
Add-Type -TypeDefinition ($src.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
function Prepare-LenovoDialogDpiLayout {
    param([Windows.Forms.Form]$Form,$Owner,[string]$Role)
    Set-LenovoDialogDpiLayout -Form $Form -Scale $script:Scale -WorkingArea $script:Area
}
# Inspect the actual shared native Button paint, not a copied renderer.
function Test-Lbs270DialogHover([Windows.Forms.Button]$Button) {
    if ($Button -isnot [LenovoActionButton]) { return $false }
    $flags=[Reflection.BindingFlags]'Instance,NonPublic'
    $enter=[Windows.Forms.Control].GetMethod('OnMouseEnter',$flags)
    $leave=[Windows.Forms.Control].GetMethod('OnMouseLeave',$flags)
    $hoverInk=[Drawing.Color]::FromArgb(255,110,102).ToArgb()
    $hc=[Windows.Forms.SystemInformation]::HighContrast
    $oldEnabled=$Button.Enabled
    try {
        $Button.Enabled=$true
        [void]$leave.Invoke($Button,@([EventArgs]::Empty))
        $oldSurface=$Button.FlatAppearance.MouseOverBackColor
        $idleForeground=$Button.ForeColor
        $idleBack=$Button.BackColor
        $idle=Get-Lbs270DialogHoverPixels $Button $hoverInk
        [void]$enter.Invoke($Button,@([EventArgs]::Empty))
        $expectedSurface=if ($idleBack.ToArgb() -eq [Drawing.Color]::FromArgb(225,37,27).ToArgb()) {
            [Drawing.Color]::FromArgb(225,41,32)
        } else {
            [Drawing.Color]::FromArgb([int][Math]::Round($idleBack.R*0.88+255*0.12),[int][Math]::Round($idleBack.G*0.88+110*0.12),[int][Math]::Round($idleBack.B*0.88+102*0.12))
        }
        $hot=Get-Lbs270DialogHoverPixels $Button $hoverInk $expectedSurface.ToArgb()
        $hotStyle=($Button.ForeColor -eq $idleForeground -and $Button.BackColor -eq $idleBack -and $Button.FlatAppearance.MouseOverBackColor.ToArgb() -eq $expectedSurface.ToArgb())
        [void]$leave.Invoke($Button,@([EventArgs]::Empty))
        $restored=Get-Lbs270DialogHoverPixels $Button $hoverInk
        $restoredStyle=$Button.FlatAppearance.MouseOverBackColor -eq $oldSurface
        $Button.Enabled=$false
        [void]$enter.Invoke($Button,@([EventArgs]::Empty))
        $disabled=Get-Lbs270DialogHoverPixels $Button $hoverInk
        $disabledStyle=$Button.FlatAppearance.MouseOverBackColor -eq $oldSurface
        $noOverlay=(-not $idle.Any -and -not $restored.Any -and -not $disabled.Any)
        return ($noOverlay -and $restoredStyle -and $disabledStyle -and $(if($hc){-not $hot.Any}else{$hot.All -and $hot.Fill -and $hotStyle}))
    } finally { [void]$leave.Invoke($Button,@([EventArgs]::Empty)); $Button.Enabled=$oldEnabled }
}
function Get-Lbs270DialogHoverPixels([Windows.Forms.Button]$Button,[int]$Ink,[int]$Surface=0) {
    $bmp=[Drawing.Bitmap]::new($Button.Width,$Button.Height)
    try {
        $Button.DrawToBitmap($bmp,$Button.ClientRectangle)
        # Sample each edge separately, away from text and corner intersections.
        $top=0; $bottom=0; $left=0; $right=0
        for ($x=4;$x -lt $bmp.Width-4;$x++) {
            for ($offset=0;$offset -lt [Math]::Min(4,[int]($bmp.Height/3));$offset++) {
                if ($bmp.GetPixel($x,$offset).ToArgb() -eq $Ink) { $top++ }
                if ($bmp.GetPixel($x,$bmp.Height-1-$offset).ToArgb() -eq $Ink) { $bottom++ }
            }
        }
        for ($y=4;$y -lt $bmp.Height-4;$y++) {
            for ($offset=0;$offset -lt [Math]::Min(4,[int]($bmp.Width/3));$offset++) {
                if ($bmp.GetPixel($offset,$y).ToArgb() -eq $Ink) { $left++ }
                if ($bmp.GetPixel($bmp.Width-1-$offset,$y).ToArgb() -eq $Ink) { $right++ }
            }
        }
        $fill=0
        for ($x=4;$x -lt $bmp.Width-4;$x++) {
            for ($y=4;$y -lt [Math]::Min(8,[int]($bmp.Height/3));$y++) {
                if ($bmp.GetPixel($x,$y).ToArgb() -eq $Surface) { $fill++ }
            }
        }
        return [pscustomobject]@{ Any=($top+$bottom+$left+$right -gt 0); All=($top -gt 0 -and $bottom -gt 0 -and $left -gt 0 -and $right -gt 0); Fill=($fill -ge $bmp.Width/2) }
    } finally { $bmp.Dispose() }
}
# Inspect the actual copy button's opt-in Small status raster in its reserved
# right-hand slot; the rest of the action remains native.
function Test-Lbs274FeedbackRaster([LenovoActionButton]$Button,[LenovoStatusKind]$Kind) {
    if (-not $Button.HasStatusFeedback -or $Button.StatusFeedbackKind -ne $Kind -or $Button.Padding.Right -le 0) { return $false }
    $ink=[LenovoStatusIconRenderer]::Ink($Kind,[Windows.Forms.SystemInformation]::HighContrast)
    $bmp=[Drawing.Bitmap]::new($Button.Width,$Button.Height)
    try {
        $Button.DrawToBitmap($bmp,$Button.ClientRectangle)
        $matches=0
        $start=[Math]::Max(2,$bmp.Width-$Button.Padding.Right+2)
        for ($x=$start;$x -lt $bmp.Width-2;$x++) {
            for ($y=2;$y -lt $bmp.Height-2;$y++) {
                $pixel=$bmp.GetPixel($x,$y)
                # Small antialiased strokes need not contain fully opaque pixels.
                if ([Math]::Abs([int]$pixel.R-[int]$ink.R) -le 40 -and [Math]::Abs([int]$pixel.G-[int]$ink.G) -le 40 -and [Math]::Abs([int]$pixel.B-[int]$ink.B) -le 40) { $matches++ }
            }
        }
        Write-Host "LBS274 inline $Kind raster: $matches matching pixels, $($Button.Size), reserved=$($Button.Padding.Right)"
        return ($matches -gt 3)
    } finally { $bmp.Dispose() }
}
# Real controls and mocked side effects. Actual modal lifecycle is covered by LBS202/229.
function Show-LenovoOwnedDialog {
    param([Windows.Forms.Form]$Form,$Owner)
    $Form.Show()
    try {
        $s=$Form.Controls[0].Tag
        Assert-Dialog 'shared dark header and separate fixed action bar' ($s.Kind -eq 'LenovoRegularDialog' -and $s.Header.BackColor.R -eq 9 -and $s.Footer.Top -eq $s.Viewport.Bottom)
        Assert-Dialog 'visible action bar and bounded window' ($s.Footer.Bottom -le $Form.ClientSize.Height -and $Form.Width -le $script:Area.Width -and $Form.Height -le $script:Area.Height -and @($s.Buttons | Where-Object {$_.Right -gt $s.Footer.Width -or $_.Bottom -gt $s.Footer.Height}).Count -eq 0)
        $hoverValid=$true
        foreach ($action in $s.Buttons) { if (-not (Test-Lbs270DialogHover $action)) { $hoverValid=$false } }
        Assert-Dialog "LBS270 $script:Locale/$script:Scale/$script:Case every dialog action paints hover only when enabled" $hoverValid
        if ($script:Case -eq 'copy') {
            $b=$s.Buttons[0]
            $handle=$Form.Handle
            $idleText=$b.Text; $idleInk=$b.ForeColor; $idlePadding=$b.Padding
            Assert-Dialog 'verified success icon and full value' ($s.Glyph -is [LenovoStatusIcon] -and $s.Glyph.Kind -eq [LenovoStatusKind]::Success -and $s.Glyph.DesignSize -eq 24 -and $s.Glyph.ForeColor -eq [LenovoStatusIconRenderer]::Ink([LenovoStatusKind]::Success,[Windows.Forms.SystemInformation]::HighContrast) -and $s.Glyph.AccessibleName -eq $s.Body.Controls['DialogHeading'].Text -and $s.Body.Controls['DialogValue'].Text -eq $script:Value)
            Assert-Dialog 'copy notice preserves OK accept and cancel' ($Form.AcceptButton -eq $s.Buttons[1] -and $Form.CancelButton -eq $s.Buttons[1])
            $b.PerformClick()
            Assert-Dialog 'copy success stays open with localized feedback' ($Form.Visible -and $Form.Handle -eq $handle -and $Form.DialogResult -eq [Windows.Forms.DialogResult]::None -and $b.Text -eq (Get-LocalizedString -Key 'Diagnostics.Copied') -and (Test-Lbs274FeedbackRaster $b ([LenovoStatusKind]::Success)) -and $script:Copies -eq 1)
            $b.PerformClick()
            Assert-Dialog 'repeat copy works without upload or close' ($script:Copies -eq 2 -and $Form.Visible -and $b.HasStatusFeedback -and $b.StatusFeedbackKind -eq [LenovoStatusKind]::Success)
            $script:FailCopy=$true
            $b.PerformClick()
            $failedState=($b.Text -eq (Get-LocalizedString -Key 'Diagnostics.CopyFailed') -and $Form.Visible -and $script:Copies -eq 2 -and (Test-Lbs274FeedbackRaster $b ([LenovoStatusKind]::Warning)))
            $clock=[Diagnostics.Stopwatch]::StartNew()
            while ($b.HasStatusFeedback -and $clock.ElapsedMilliseconds -lt 3500) {
                [Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 25
            }
            Assert-Dialog 'failed copy replaces success and timer restores native idle action' ($failedState -and -not $b.HasStatusFeedback -and $b.Text -eq $idleText -and $b.ForeColor -eq $idleInk -and $b.Padding -eq $idlePadding -and -not $b.AccessibleDescription -and $Form.Visible)
            Assert-Dialog 'scroll overflow is confined to body' ($s.Scroll.Maximum -eq [Math]::Max(0,$s.Body.Height-$s.Viewport.Height))
            if ($s.Scroll.Maximum -gt 0) {
                $key=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::End -bor [Windows.Forms.Keys]::Control)
                [void]$onKeyDown.Invoke($Form,@($key))
                Assert-Dialog 'keyboard end reaches body end while actions stay fixed' ($s.Body.Bottom -eq $s.Viewport.Height -and $s.Scroll.ThumbColor -eq $script:ColorAccent -and $s.Footer.Top -eq $s.Viewport.Bottom)
            } else { Assert-Dialog 'no overflow hides scrollbar' (-not $s.Scroll.Visible) }
        } elseif ($script:Case -in @('Info','Warning','Error')) {
            $expected=[LenovoStatusKind]$script:Case
            Assert-Dialog 'semantic notice glyph and single OK default' ($s.Glyph -is [LenovoStatusIcon] -and $s.Glyph.Kind -eq $expected -and $s.Glyph.AccessibleName -eq $s.Body.Controls['DialogHeading'].Text -and $s.Buttons.Count -eq 1 -and $Form.AcceptButton -eq $s.Buttons[0] -and $Form.CancelButton -eq $s.Buttons[0])
        } elseif ($script:Case -eq 'restart') {
            Assert-Dialog 'restart shows complete target and preserves Yes/No' ($s.Glyph -is [LenovoStatusIcon] -and $s.Glyph.Kind -eq [LenovoStatusKind]::Warning -and $s.Body.Controls['DialogValue'].Text -eq $script:Value -and -not $s.Body.Controls['DialogValue'].AutoEllipsis -and $Form.AcceptButton.DialogResult -eq [Windows.Forms.DialogResult]::Yes -and $Form.CancelButton.DialogResult -eq [Windows.Forms.DialogResult]::No)
        } elseif ($script:Case -eq 'migration') {
            Assert-Dialog 'migration preserves English default and no new cancel action' ($Form.AcceptButton -eq $s.Buttons[1] -and -not $Form.CancelButton)
        } else {
            $expected=if ($script:Case -eq 'Remove') { [LenovoStatusKind]::Warning } else { [LenovoStatusKind]::Info }
            Assert-Dialog 'maintenance preserves primary Yes and Cancel No' ($s.Glyph -is [LenovoStatusIcon] -and $s.Glyph.Kind -eq $expected -and $s.Glyph.AccessibleName -and $Form.AcceptButton -eq $s.Buttons[1] -and $Form.AcceptButton.DialogResult -eq [Windows.Forms.DialogResult]::Yes -and $Form.CancelButton -eq $s.Buttons[0] -and $Form.CancelButton.DialogResult -eq [Windows.Forms.DialogResult]::No)
            if ($script:Case -eq 'Remove') {
                $all=($s.Content | ForEach-Object Text) -join ' '
                $paragraphs=(Get-LocalizedString -Key 'Maintenance.Dialog.RemoveBody') -split '\r?\n\r?\n'
                Assert-Dialog 'removal includes all original facts and group headings' ($paragraphs.Count -eq 3 -and $all.Contains($paragraphs[0]) -and $all.Contains($paragraphs[1]) -and $all.Contains($paragraphs[2]) -and $all.Contains((Get-LocalizedString -Key 'Maintenance.Dialog.Changes')) -and $all.Contains((Get-LocalizedString -Key 'Maintenance.Dialog.Retained')))
            }
        }
        return [Windows.Forms.DialogResult]::Cancel
    } finally { $Form.Hide() }
}
foreach ($locale in @('de-DE','en-US')) {
    $script:Locale=$locale
    foreach ($scale in @(1.0,2.5)) {
        $script:Scale=$scale
        $script:Area=[Drawing.Rectangle]::new(-800,0,800,600)
        $script:Value=('long-target-or-receipt-'*20)
        $script:Copies=0
        $script:FailCopy=$false
        $script:Case='copy'
        Show-LenovoNoticeDialog -Title 'Diagnostic' -Heading 'Verified' -Message ('Long explanatory text. '*24) -Kind Success -ValueCaption 'ID' -ValueText $script:Value -SecondaryButtonText (Get-LocalizedString -Key 'Diagnostics.CopyId') -SecondaryAction { if ($script:FailCopy) { throw 'simulated clipboard failure' }; $script:Copies++; return $true } -KeepOpenAfterSecondary
        foreach ($kind in @('Info','Warning','Error')) {
            $script:Case=$kind
            Show-LenovoNoticeDialog -Title $kind -Heading $kind -Message 'Example notice' -Kind $kind
        }
        $script:Case='restart'
        [void](Show-LenovoRestartDialog -TargetName $script:Value)
        $script:Case='migration'
        [void](Show-LocaleMigrationDialog)
        foreach ($mode in @('Setup','Repair','Migrate','Reinitialize','Remove')) {
            $script:Case=$mode
            [void](Show-LenovoSystemFunctionsDialog -Mode $mode)
        }
    }
}
Write-Host "LBS242 DIALOG COMPOSITION TOTAL $script:Checks"
if ($script:Checks -ne 204) { throw "Expected 204 native dialog checks, got $script:Checks" }
