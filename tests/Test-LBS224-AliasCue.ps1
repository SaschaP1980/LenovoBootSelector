#requires -version 5.1
# LBS-224: actual product alias cue and native editor contracts; no firmware or persistent settings.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class Lbs224ProductNative {
    [DllImport("user32.dll", EntryPoint="SendMessageW")]
    public static extern IntPtr HitTest(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")]
    public static extern bool GetCaretPos(out Point p);
}
'@
$script:checks=0
function Assert-AliasCue([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS224 ALIAS CUE FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS224 ALIAS CUE $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:TestLocale -Values $Values }
function Show-DarkActionTooltip { param($Owner,[string]$Text) $script:DarkActionTooltipOwner=$Owner; $script:TipText=$Text }
function Hide-DarkActionTooltip { $script:DarkActionTooltipOwner=$null; $script:TipText='' }
function Update-ManageSaveButtonState { $script:SaveStateCalls++ }
function Set-ManageEntryAliasDraft { param([string]$Guid,[string]$Alias) $script:DraftCalls++; $script:LastGuid=$Guid; $script:LastAlias=$Alias; return $true }
function Update-PopupRows { $script:RefreshCalls++ }
function Save-AppSettings { throw 'Unexpected persistent settings write' }
function Get-ProductCueInk {
    param([Windows.Forms.Control]$Editor)
    $bitmap=New-Object Drawing.Bitmap($Editor.Width,$Editor.Height)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($Editor.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$Editor.Size)
        $bright=0; $dark=0; $peak=0; $blueGray=0
        for ($y=0;$y -lt $bitmap.Height;$y++) {
            for ($x=12;$x -lt [Math]::Min(240,$bitmap.Width);$x++) {
                $px=$bitmap.GetPixel($x,$y)
                $v=[Math]::Min($px.R,[Math]::Min($px.G,$px.B))
                if ($v -ge 130) { $bright++ }
                if ($v -ge 130 -and ($px.B - $px.R) -ge 30 -and ($px.G - $px.R) -ge 10) { $blueGray++ }
                if ($v -le 30) { $dark++ }
                if ($v -gt $peak) { $peak=$v }
            }
        }
        return [pscustomobject]@{bright=$bright;dark=$dark;peak=$peak;blueGray=$blueGray}
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorRow=[Drawing.Color]::FromArgb(32,32,32)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(60,30,30)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::Silver
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$enter=[Windows.Forms.Control].GetMethod('OnMouseEnter',$flags)
$leave=[Windows.Forms.Control].GetMethod('OnMouseLeave',$flags)
$down=[Windows.Forms.Control].GetMethod('OnMouseDown',$flags)
$click=[Windows.Forms.Control].GetMethod('OnClick',$flags)
$key=[Windows.Forms.Control].GetMethod('OnKeyDown',$flags)
$recreate=[Windows.Forms.Control].GetMethod('RecreateHandle',$flags)
foreach ($locale in @('en-US','de-DE')) {
    $script:TestLocale=$locale
    $expectedCue=if ($locale -eq 'en-US') { 'Use original name' } else { 'Originalname verwenden' }
    $expectedHint=if ($locale -eq 'en-US') { 'Empty: use original name' } else { 'Leer: Originalname verwenden' }
    foreach ($factor in @(1.0,2.5)) {
        $prefix="$locale $factor"
        $script:DarkActionTooltipOwner=$null; $script:TipText=''
        $script:SaveStateCalls=0; $script:DraftCalls=0; $script:RefreshCalls=0
        $script:LastAlias=$null; $script:LastGuid=$null; $script:ManageActiveDragGuid=$null
        $entry=[pscustomobject]@{Guid='12345678-1234-4234-8234-123456789abc'}
        $form=New-Object Windows.Forms.Form
        $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
        $form.Location=[Drawing.Point]::new(20,20)
        $form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None
        $form.ClientSize=[Drawing.Size]::new(1030,300)
        $form.TopMost=$true
        $script:Popup=$form
        $script:IsManageEntriesMode=$true
        $script:ManageAliasEditGuid=$entry.Guid
        $row=New-Object Windows.Forms.Panel
        $row.Name='BootRow'; $row.Tag=$entry.Guid
        $row.Size=[Drawing.Size]::new(390,92); $row.BackColor=$script:ColorRow
        $form.Controls.Add($row)
        try {
            Add-BootEntryAliasEditor -Row $row -Entry $entry -Alias ''
            [void](Set-PopupBootRowDpiLayout -Row $row -Scale $factor -Y 0)
            $frame=$row.Controls['AliasEditorFrame']
            $editor=$frame.Controls['AliasEditor']
            $cue=$frame.Controls['AliasCueLabel']
            $clear=$frame.Controls['AliasClearButton']
            $apply=$row.Controls['AliasApplyButton']; $cancel=$row.Controls['AliasCancelButton']
            $form.Show(); $form.Activate(); [void]$editor.Focus()
            [Windows.Forms.Application]::DoEvents()
            Assert-AliasCue "$prefix empty native field has cue, not actual text" ($editor -is [Windows.Forms.TextBox] -and $editor.Text -eq '' -and $editor.SelectedText -eq '' -and $cue.Visible -and -not $clear.Visible -and $editor.Focused)
            Assert-AliasCue "$prefix localized cue and accessible field hint" ($cue.Text -eq $expectedCue -and $editor.AccessibleName -eq (Get-LocalizedString -Key 'Manage.EditAliasAccessible') -and $editor.AccessibleDescription -eq $expectedHint)
            Assert-AliasCue "$prefix nonselectable label, no static hint and no dirty side effect" (-not $cue.TabStop -and -not $cue.CanSelect -and $cue.AccessibleRole -eq [Windows.Forms.AccessibleRole]::None -and $null -eq $row.Controls['AliasOriginalNameHint'] -and $script:SaveStateCalls -eq 0 -and $script:DraftCalls -eq 0)
            $inlineOk=$true
            foreach ($action in @($apply,$cancel)) {
                [void]$leave.Invoke($action,@([EventArgs]::Empty))
                $normalInk=$action.ForeColor
                $normalSurface=$action.FlatAppearance.MouseOverBackColor
                [void]$enter.Invoke($action,@([EventArgs]::Empty))
                $bmp=[Drawing.Bitmap]::new($action.Width,$action.Height)
                try {
                    $action.DrawToBitmap($bmp,$action.ClientRectangle)
                    $ink=[Drawing.Color]::FromArgb(255,110,102).ToArgb()
                    $bottom=0; $top=0
                    for ($x=4;$x -lt $bmp.Width-4;$x++) {
                        for ($y=0;$y -lt 4;$y++) {
                            if ($bmp.GetPixel($x,$y).ToArgb() -eq $ink) {$top++}
                            if ($bmp.GetPixel($x,$bmp.Height-1-$y).ToArgb() -eq $ink) {$bottom++}
                        }
                    }
                    $hc=[Windows.Forms.SystemInformation]::HighContrast
                    $paintOk=if ($hc) { $bottom -eq 0 -and $action.ForeColor -eq $normalInk } else { $bottom -gt 0 -and $top -eq 0 -and $action.ForeColor.ToArgb() -eq $ink -and $action.FlatAppearance.MouseOverBackColor -eq $action.BackColor }
                    $inlineOk=$inlineOk -and $action.InlineAction -and $paintOk
                } finally { $bmp.Dispose(); [void]$leave.Invoke($action,@([EventArgs]::Empty)) }
                $inlineOk=$inlineOk -and $action.ForeColor -eq $normalInk -and $action.FlatAppearance.MouseOverBackColor -eq $normalSurface
            }
            Assert-AliasCue "$prefix unchanged editor and action geometry, inline hover raster" ($inlineOk -and $row.Height -eq [int][Math]::Round(92*$factor) -and $frame.Width -eq [int][Math]::Round(318*$factor) -and $editor.Width -eq [int][Math]::Round(288*$factor) -and $clear.Left -eq [int][Math]::Round(292*$factor) -and $clear.Width -eq [int][Math]::Round(26*$factor) -and $apply.Left -eq [int][Math]::Round(58*$factor) -and $cancel.Left -eq [int][Math]::Round(154*$factor))
            Assert-AliasCue "$prefix cue bounds reserve caret and stay inside editor" ($cue.Left -eq [int][Math]::Round(4*$factor) -and $cue.Top -eq $editor.Top -and $cue.Right -eq $editor.Right -and $cue.Bottom -lt $frame.Controls['AliasEditorUnderline'].Top)
            $cue.Invalidate(); $cue.Update(); [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
            $ink=Get-ProductCueInk -Editor $editor
            Write-Host ('LBS224_PRODUCT_CUE_RASTER ' + $prefix + ' ' + ($ink | ConvertTo-Json -Compress))
            Assert-AliasCue "$prefix actual visible blue-gray dark-theme cue raster" ($cue.ForeColor -eq [Drawing.Color]::FromArgb(143,166,191) -and $cue.BackColor -eq $editor.BackColor -and $ink.bright -gt 10 -and $ink.dark -gt 100 -and $ink.blueGray -gt 3)
            Assert-AliasCue "$prefix italic cue distinct from regular native text at unchanged size" ($cue.Font.Style -eq [Drawing.FontStyle]::Italic -and $editor.Font.Style -eq [Drawing.FontStyle]::Regular -and $cue.Font.FontFamily.Name -eq $editor.Font.FontFamily.Name -and [Math]::Abs($cue.Font.SizeInPoints-$editor.Font.SizeInPoints) -lt 0.05 -and $editor.ForeColor -eq $script:ColorPrimary -and $cue.ForeColor -ne $editor.ForeColor)
            $hit=[Lbs224ProductNative]::HitTest($cue.Handle,0x0084,[IntPtr]0,[IntPtr]0).ToInt64()
            $point=$cue.PointToScreen([Drawing.Point]::new(20,5))
            $nativeHit=[Lbs224ProductNative]::WindowFromPoint($point)
            $caret=[Drawing.Point]::Empty
            $caretKnown=[Lbs224ProductNative]::GetCaretPos([ref]$caret)
            Assert-AliasCue "$prefix native hit reaches editor and caret is outside cue" ($hit -eq -1 -and $nativeHit -eq $editor.Handle -and $caretKnown -and $caret.X -lt ($cue.Left-$editor.Left) -and $editor.Focused)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix contextual dark field hint" ($script:DarkActionTooltipOwner -eq $editor -and $script:TipText -eq $expectedHint)
            [void]$leave.Invoke($editor,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix mouse leave hides own field hint" ($null -eq $script:DarkActionTooltipOwner)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            Show-DarkActionTooltip -Owner $apply -Text 'other'
            [void]$leave.Invoke($editor,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix field cleanup preserves other tooltip owner" ($script:DarkActionTooltipOwner -eq $apply)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            [void]$down.Invoke($editor,@([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,5,5,0)))
            Assert-AliasCue "$prefix mouse down dismisses field help" ($null -eq $script:DarkActionTooltipOwner)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            $editor.SelectedText='Typed Alias'
            Assert-AliasCue "$prefix typing hides cue, retains actual text and focus" ($editor.Text -eq 'Typed Alias' -and -not $cue.Visible -and $clear.Visible -and $editor.Focused -and $script:SaveStateCalls -ge 1 -and $script:DraftCalls -eq 0 -and $null -eq $script:DarkActionTooltipOwner)
            $editor.SelectAll(); $editor.Copy()
            Assert-AliasCue "$prefix copy returns only real alias" ([Windows.Forms.Clipboard]::GetText() -eq 'Typed Alias')
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix existing clear tooltip remains localized" ($script:DarkActionTooltipOwner -eq $clear -and $script:TipText -eq (Get-LocalizedString -Key 'Manage.ClearAliasHint'))
            [void]$click.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix clear restores empty cue and focus, no draft commit" ($editor.Text -eq '' -and $cue.Visible -and -not $clear.Visible -and $editor.Focused -and $null -eq $script:DarkActionTooltipOwner -and $script:DraftCalls -eq 0)
            [Windows.Forms.Clipboard]::SetText('sentinel'); $editor.SelectAll(); $editor.Copy()
            Assert-AliasCue "$prefix empty cue is not selectable or copied" ($editor.SelectedText -eq '' -and [Windows.Forms.Clipboard]::GetText() -eq 'sentinel')
            [Windows.Forms.Clipboard]::SetText('Pasted Alias'); $editor.Paste()
            Assert-AliasCue "$prefix native paste works and hides cue" ($editor.Text -eq 'Pasted Alias' -and -not $cue.Visible -and $clear.Visible)
            $editor.SelectAll(); $editor.SelectedText=''
            Assert-AliasCue "$prefix native selection deletion restores cue" ($editor.Text -eq '' -and $cue.Visible -and -not $clear.Visible)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            $editor.Visible=$false
            Assert-AliasCue "$prefix hide removes cue and owned help" (-not $cue.Visible -and $null -eq $script:DarkActionTooltipOwner)
            $editor.Visible=$true; [void]$editor.Focus()
            Assert-AliasCue "$prefix show restores cue without setting Text" ($cue.Visible -and $editor.Text -eq '' -and $editor.Focused)
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            [void]$recreate.Invoke($editor,@()); [void]$editor.Focus()
            [Windows.Forms.Application]::DoEvents()
            Assert-AliasCue "$prefix handle recreation preserves cue and clears stale help" ($editor.IsHandleCreated -and $cue.Visible -and $editor.Text -eq '' -and $editor.Focused -and $null -eq $script:DarkActionTooltipOwner)
            $ev=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Enter)
            [void]$key.Invoke($editor,@($ev))
            Assert-AliasCue "$prefix Enter commits empty draft only, never cue" ($ev.SuppressKeyPress -and $script:DraftCalls -eq 1 -and $script:LastAlias -eq '' -and $script:LastGuid -eq $entry.Guid -and $script:RefreshCalls -eq 1)
            # This isolated fixture stubs row reconstruction; each next action models a new editor session.
            $script:ManageAliasEditGuid=$entry.Guid
            $editor.Text='Discard me'
            $ev=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Escape)
            [void]$key.Invoke($editor,@($ev))
            Assert-AliasCue "$prefix Escape discards without another draft commit" ($ev.SuppressKeyPress -and $script:DraftCalls -eq 1 -and $script:RefreshCalls -eq 2)
            $script:ManageAliasEditGuid=$entry.Guid
            $editor.Text='Applied alias'
            [void]$click.Invoke($apply,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix Apply uses only real entered text" ($script:DraftCalls -eq 2 -and $script:LastAlias -eq 'Applied alias' -and $script:RefreshCalls -eq 3)
            $script:ManageAliasEditGuid=$entry.Guid
            [void]$click.Invoke($cancel,@([EventArgs]::Empty))
            Assert-AliasCue "$prefix Cancel leaves draft unchanged" ($script:DraftCalls -eq 2 -and $script:RefreshCalls -eq 4)
            $editor.Text=''
            [void]$enter.Invoke($editor,@([EventArgs]::Empty))
            $editor.Dispose()
            Assert-AliasCue "$prefix editor disposal hides cue and help" ($editor.IsDisposed -and -not $cue.Visible -and $null -eq $script:DarkActionTooltipOwner)
            $row.Dispose()
            Assert-AliasCue "$prefix parent disposal releases cue" ($cue.IsDisposed)
        } finally { $form.Dispose(); $script:Popup=$null; $script:DarkActionTooltipOwner=$null }
    }
}
# Force helper-unavailable fallback without changing the product or its saved state.
function New-ManageAliasCue { param($Editor,[string]$CueText) return $null }
$script:TestLocale='en-US'; $script:SaveStateCalls=0; $script:DraftCalls=0
$fallback=New-Object Windows.Forms.Panel
try {
    Add-BootEntryAliasEditor -Row $fallback -Entry ([pscustomobject]@{Guid='12345678-1234-4234-8234-123456789abc'}) -Alias ''
    $frame=$fallback.Controls['AliasEditorFrame']
    $hint=$fallback.Controls['AliasOriginalNameHint']
    Assert-AliasCue 'Uninitialized helper retains original instruction' ($hint -and $hint.Text -eq 'Leave empty = original name' -and $null -eq $frame.Controls['AliasCueLabel'])
    Assert-AliasCue 'Fallback retains truly empty editor and no draft side effect' ($frame.Controls['AliasEditor'].Text -eq '' -and $script:SaveStateCalls -eq 0 -and $script:DraftCalls -eq 0)
} finally { $fallback.Dispose() }
Write-Host "LBS224 ALIAS CUE TOTAL $script:checks/114"
if ($script:checks -ne 114) { throw "Expected 114 native alias cue assertions, got $script:checks" }
