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
$start=$src.IndexOf('public sealed class LenovoVerticalScrollBar : Control')
if ($start -lt 0) { throw 'Scrollbar source missing' }
$depth=0; $opened=$false; $end=-1
for ($i=$start;$i -lt $src.Length;$i++) {
    if ($src[$i] -eq '{') { $depth++; $opened=$true }
    elseif ($src[$i] -eq '}') { $depth--; if ($opened -and $depth -eq 0) { $end=$i; break } }
}
if ($end -lt 0) { throw 'Scrollbar source incomplete' }
Add-Type -TypeDefinition ("using System; using System.Drawing; using System.Windows.Forms;"+$src.Substring($start,$end-$start+1)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
function Prepare-LenovoDialogDpiLayout {
    param([Windows.Forms.Form]$Form,$Owner,[string]$Role)
    Set-LenovoDialogDpiLayout -Form $Form -Scale $script:Scale -WorkingArea $script:Area
}
# Real controls and mocked side effects. Actual modal lifecycle is covered by LBS202/229.
function Show-LenovoOwnedDialog {
    param([Windows.Forms.Form]$Form,$Owner)
    $Form.Show()
    try {
        $s=$Form.Controls[0].Tag
        Assert-Dialog 'shared dark header and separate fixed action bar' ($s.Kind -eq 'LenovoRegularDialog' -and $s.Header.BackColor.R -eq 9 -and $s.Footer.Top -eq $s.Viewport.Bottom)
        Assert-Dialog 'visible action bar and bounded window' ($s.Footer.Bottom -le $Form.ClientSize.Height -and $Form.Width -le $script:Area.Width -and $Form.Height -le $script:Area.Height -and @($s.Buttons | Where-Object {$_.Right -gt $s.Footer.Width -or $_.Bottom -gt $s.Footer.Height}).Count -eq 0)
        if ($script:Case -eq 'copy') {
            $b=$s.Buttons[0]
            $handle=$Form.Handle
            Assert-Dialog 'verified success icon and full value' ($s.Glyph.Text -eq '✓' -and $s.Glyph.ForeColor.G -eq 206 -and $s.Body.Controls['DialogValue'].Text -eq $script:Value)
            Assert-Dialog 'copy notice preserves OK accept and cancel' ($Form.AcceptButton -eq $s.Buttons[1] -and $Form.CancelButton -eq $s.Buttons[1])
            $b.PerformClick()
            Assert-Dialog 'copy success stays open with localized feedback' ($Form.Visible -and $Form.Handle -eq $handle -and $Form.DialogResult -eq [Windows.Forms.DialogResult]::None -and $b.Text -eq (Get-LocalizedString -Key 'Diagnostics.Copied') -and $script:Copies -eq 1)
            $b.PerformClick()
            Assert-Dialog 'repeat copy works without upload or close' ($script:Copies -eq 2 -and $Form.Visible)
            $script:FailCopy=$true
            $b.PerformClick()
            Assert-Dialog 'failed copy cannot retain false success' ($b.Text -eq (Get-LocalizedString -Key 'Diagnostics.CopyFailed') -and $Form.Visible -and $script:Copies -eq 2)
            Assert-Dialog 'scroll overflow is confined to body' ($s.Scroll.Maximum -eq [Math]::Max(0,$s.Body.Height-$s.Viewport.Height))
            if ($s.Scroll.Maximum -gt 0) {
                $key=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::End -bor [Windows.Forms.Keys]::Control)
                [void]$onKeyDown.Invoke($Form,@($key))
                Assert-Dialog 'keyboard end reaches body end while actions stay fixed' ($s.Body.Bottom -eq $s.Viewport.Height -and $s.Scroll.ThumbColor -eq $script:ColorAccent -and $s.Footer.Top -eq $s.Viewport.Bottom)
            } else { Assert-Dialog 'no overflow hides scrollbar' (-not $s.Scroll.Visible) }
        } elseif ($script:Case -in @('Info','Warning','Error')) {
            $expected=if ($script:Case -eq 'Info') { 'i' } elseif ($script:Case -eq 'Warning') { '!' } else { '×' }
            Assert-Dialog 'semantic notice glyph and single OK default' ($s.Glyph.Text -eq $expected -and $s.Buttons.Count -eq 1 -and $Form.AcceptButton -eq $s.Buttons[0] -and $Form.CancelButton -eq $s.Buttons[0])
        } elseif ($script:Case -eq 'restart') {
            Assert-Dialog 'restart shows complete target and preserves Yes/No' ($s.Body.Controls['DialogValue'].Text -eq $script:Value -and -not $s.Body.Controls['DialogValue'].AutoEllipsis -and $Form.AcceptButton.DialogResult -eq [Windows.Forms.DialogResult]::Yes -and $Form.CancelButton.DialogResult -eq [Windows.Forms.DialogResult]::No)
        } elseif ($script:Case -eq 'migration') {
            Assert-Dialog 'migration preserves English default and no new cancel action' ($Form.AcceptButton -eq $s.Buttons[1] -and -not $Form.CancelButton)
        } else {
            Assert-Dialog 'maintenance preserves primary Yes and Cancel No' ($Form.AcceptButton -eq $s.Buttons[1] -and $Form.AcceptButton.DialogResult -eq [Windows.Forms.DialogResult]::Yes -and $Form.CancelButton -eq $s.Buttons[0] -and $Form.CancelButton.DialogResult -eq [Windows.Forms.DialogResult]::No)
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
if ($script:Checks -ne 160) { throw "Expected 160 native dialog checks, got $script:Checks" }
