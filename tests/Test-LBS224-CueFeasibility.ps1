#requires -version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class Lbs224CueProbeNative {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, string l);
    [DllImport("user32.dll", EntryPoint="SendMessageW")]
    public static extern IntPtr HitTest(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")]
    public static extern bool GetCaretPos(out Point p);
}
public sealed class Lbs224ProbeCueLabel : Label {
    public Lbs224ProbeCueLabel() {
        SetStyle(ControlStyles.Selectable, false);
        TabStop = false;
        AccessibleRole = AccessibleRole.None;
        UseMnemonic = false;
        AutoSize = false;
    }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0084) { m.Result = new IntPtr(-1); return; }
        base.WndProc(ref m);
    }
}
'@
function Get-FieldInk {
    param([Windows.Forms.Control]$Control)
    $bmp = New-Object Drawing.Bitmap($Control.Width,$Control.Height)
    $g = [Drawing.Graphics]::FromImage($bmp)
    try {
        $g.CopyFromScreen($Control.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$Control.Size)
        $bright = 0; $peak = 0; $dark = 0
        for ($y=0;$y -lt $bmp.Height;$y++) {
            for ($x=8;$x -lt [Math]::Min(240,$bmp.Width);$x++) {
                $px=$bmp.GetPixel($x,$y)
                $lum=[Math]::Min($px.R,[Math]::Min($px.G,$px.B))
                if ($lum -le 30) { $dark++ }
                if ($lum -ge 130) { $bright++ }
                if ($lum -gt $peak) { $peak=$lum }
            }
        }
        return [pscustomobject]@{bright=$bright;peak=$peak;dark=$dark}
    } finally { $g.Dispose(); $bmp.Dispose() }
}
function Refresh-Probe {
    param($Control)
    $Control.Invalidate(); $Control.Update()
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 100
}
$form=New-Object Windows.Forms.Form
$form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$form.Location=[Drawing.Point]::new(40,40)
$form.ClientSize=[Drawing.Size]::new(370,160)
$form.TopMost=$true
$form.BackColor=[Drawing.Color]::FromArgb(32,32,32)
$editor=New-Object Windows.Forms.TextBox
$editor.Font=New-Object Drawing.Font('Segoe UI',9.0)
$editor.ForeColor=[Drawing.Color]::White
$editor.BackColor=[Drawing.Color]::FromArgb(24,24,24)
$editor.BorderStyle=[Windows.Forms.BorderStyle]::None
$editor.Location=[Drawing.Point]::new(15,15)
$editor.Size=[Drawing.Size]::new(288,21)
$other=New-Object Windows.Forms.Button
$other.Text='Focus'; $other.Location=[Drawing.Point]::new(15,65)
$form.Controls.Add($editor); $form.Controls.Add($other)
try {
    $form.Show(); $form.Activate(); [void]$editor.Focus()
    $editor.Text='Use original name'
    Refresh-Probe $editor
    $reference=Get-FieldInk $editor
    $editor.Text=''
    Refresh-Probe $editor
    $blank=Get-FieldInk $editor
    $validCapture=($reference.bright -gt 10 -and $reference.dark -gt 100 -and $blank.bright -lt 5)
    $cueSet=[Lbs224CueProbeNative]::SendMessage($editor.Handle,0x1501,[IntPtr]1,'Use original name').ToInt64() -ne 0
    Refresh-Probe $editor
    $focused=Get-FieldInk $editor
    $focusedActual=$editor.Focused
    $nativeTextEmpty=($editor.Text -eq '')
    [void]$other.Focus(); Refresh-Probe $editor
    $unfocused=Get-FieldInk $editor
    # The native API does not expose cue color. On #181818, a neutral
    # channel around 128 or greater is needed for 4.5:1 text contrast.
    $nativeQualified=$validCapture -and $cueSet -and $nativeTextEmpty -and $focusedActual -and $focused.bright -gt 10 -and $unfocused.bright -gt 10
    [void][Lbs224CueProbeNative]::SendMessage($editor.Handle,0x1501,[IntPtr]0,'')
    $label=New-Object Lbs224ProbeCueLabel
    $label.Text='Use original name'
    $label.Font=$editor.Font
    $label.BackColor=$editor.BackColor
    $label.ForeColor=[Drawing.Color]::FromArgb(155,155,155)
    $label.Location=[Drawing.Point]::new($editor.Left+4,$editor.Top)
    $label.Size=[Drawing.Size]::new($editor.Width-4,$editor.Height)
    $form.Controls.Add($label); $label.BringToFront()
    $editor.Add_TextChanged({$label.Visible=($editor.Text.Length -eq 0)})
    [void]$editor.Focus()
    Refresh-Probe $label
    $overlayInk=Get-FieldInk $editor
    $hit=[Lbs224CueProbeNative]::HitTest($label.Handle,0x0084,[IntPtr]0,[IntPtr]0).ToInt64()
    $screenPoint=$label.PointToScreen([Drawing.Point]::new(20,5))
    $nativeHit=[Lbs224CueProbeNative]::WindowFromPoint($screenPoint)
    $caret=[Drawing.Point]::Empty
    $caretKnown=[Lbs224CueProbeNative]::GetCaretPos([ref]$caret)
    $focusPreserved=$editor.Focused
    $emptyBefore=$editor.Text -eq ''
    $editor.SelectedText='Alias'
    $typed=($editor.Text -eq 'Alias' -and -not $label.Visible -and $editor.Focused)
    $editor.Clear()
    $cleared=($editor.Text -eq '' -and $label.Visible -and $editor.Focused)
    $overlayQualified=$validCapture -and $overlayInk.bright -gt 10 -and $hit -eq -1 -and $nativeHit -eq $editor.Handle -and $caretKnown -and $caret.X -lt 4 -and $focusPreserved -and $emptyBefore -and $typed -and $cleared -and -not $label.CanSelect
    $summary=[ordered]@{captureValid=$validCapture;frameworkPlaceholderAvailable=($null -ne [Windows.Forms.TextBox].GetProperty('PlaceholderText'));reference=$reference;blank=$blank;nativeCueSet=$cueSet;nativeFocused=$focusedActual;nativeTextEmpty=$nativeTextEmpty;nativeFocusedInk=$focused;nativeUnfocusedInk=$unfocused;nativeQualified=$nativeQualified;overlayInk=$overlayInk;overlayHitCode=$hit;underlyingNativeHit=($nativeHit -eq $editor.Handle);caretKnown=$caretKnown;caretX=$caret.X;overlayNonselectable=(-not $label.CanSelect);overlayFocusPreserved=$focusPreserved;overlayTyped=$typed;overlayCleared=$cleared;overlayQualified=$overlayQualified}
    Write-Host ('LBS224_CUE_FEASIBILITY=' + ($summary | ConvertTo-Json -Depth 5 -Compress))
    if (-not ($nativeQualified -or $overlayQualified)) { throw 'No cue mechanism qualified by native feasibility evidence' }
} finally { $form.Dispose() }
