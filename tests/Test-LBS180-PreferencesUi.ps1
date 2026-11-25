#requires -version 5.1
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs180Native {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern IntPtr GetFocus();
 [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint command);
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
'@
$root=Split-Path -Parent $PSScriptRoot
foreach ($path in @('src\Core\Localization.ps1','src\Core\EntryPreferences.ps1','src\Core\PortablePreferences.ps1','src\UI\Dialogs.ps1','src\UI\PortablePreferencesPresentation.ps1')) { . (Join-Path $root $path) }
$script:ColorBackground=[Drawing.Color]::FromArgb(31,31,31)
$script:ColorHeader=[Drawing.Color]::Black
$script:ColorSurface=[Drawing.Color]::FromArgb(25,25,25)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:Locale='en-US'
$script:passed=0
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:Locale -Values $Values }
function Get-LenovoUiCoordinateScale { param($Screen) return [pscustomobject]@{Factor=1.0} }
function Assert-True($Value,[string]$Name) {
    if (-not $Value) { throw "FAIL $Name" }
    $script:passed++
    Write-Host "PASS $Name"
}
$g1='{aaaaaaaa-1111-1111-1111-111111111111}'
$g2='{bbbbbbbb-2222-2222-2222-222222222222}'
$g3='{cccccccc-3333-3333-3333-333333333333}'
$g4='{dddddddd-4444-4444-4444-444444444444}'
$s=New-DefaultAppSettingsCore
$s.entryAliases=@{$g1='Before';$g4='Unavailable'}
$local=@([pscustomobject]@{Guid=$g1;Title='Local target'},[pscustomobject]@{Guid=$g2;Title='Local only'})
$doc=ConvertFrom-PortablePreferencesCore ('{"format":"LenovoBootSelector.Preferences","version":1,"locale":"de-DE","entries":[{"guid":"'+$g1+'","alias":"After","hidden":true},{"guid":"'+$g3+'","alias":"Foreign","hidden":false}]}')
$plan=New-PortablePreferencesPlanCore $doc $s $local
$preview=Get-PreferencesPreviewText $plan
Assert-True ($preview.Contains('MATCHED') -and $preview.Contains('SKIPPED') -and $preview.Contains('LOCAL ONLY') -and $preview.Contains($g4) -and $preview.Contains('Before') -and $preview.Contains('After') -and $preview.Contains('en-US') -and $preview.Contains('de-DE')) 'Preview includes matches, changes and exclusions'
Assert-True ((Format-PreferencesPreviewValue ('A'+[char]0x202e+'B')).Contains('\u202e')) 'Preview escapes invisible formatting'
$form=New-PreferencesConfirmationForm -Title 'Preview' -Text ('x'*60000) -ConfirmText 'Apply'
try { Assert-True ($form.Tag.Content.Text.Length -eq 60000 -and $form.Tag.Content.ReadOnly) 'Long preview not truncated or editable' } finally { $form.Dispose() }
foreach ($locale in @('en-US','de-DE')) {
    $script:Locale=$locale
    foreach ($scale in @(1.0,2.5)) {
        $form=New-PreferencesConfirmationForm -Title (Get-LocalizedString -Key 'Preferences.PreviewTitle') -Text (Get-PreferencesPreviewText $plan) -ConfirmText (Get-LocalizedString -Key 'Preferences.Apply')
        try {
            $area=[Drawing.Rectangle]::new(0,0,1920,1080)
            Set-PreferencesConfirmationLayout -Form $form -Scale $scale -WorkingArea $area
            $t=$form.Tag
            Assert-True ($area.Contains($form.Bounds) -and $form.ClientRectangle.Contains($t.Content.Bounds) -and $form.ClientRectangle.Contains($t.Cancel.Bounds) -and $form.ClientRectangle.Contains($t.Confirm.Bounds) -and $t.Content.Bottom -le $t.Cancel.Top -and -not $t.Cancel.Bounds.IntersectsWith($t.Confirm.Bounds) -and $form.AcceptButton -eq $t.Cancel -and $form.CancelButton -eq $t.Cancel -and $t.Content.ScrollBars -eq [Windows.Forms.ScrollBars]::Vertical) "$locale/$scale preview work-area geometry and safe dismissal"
        } finally {$form.Dispose()}
    }
}
$script:Locale='en-US'
$save=New-PreferencesFileDialog Export
try { Assert-True ($save -is [Windows.Forms.SaveFileDialog] -and $save.OverwritePrompt -and $save.DefaultExt -eq 'json' -and $save.RestoreDirectory) 'Native export file chooser contract' } finally {$save.Dispose()}
$open=New-PreferencesFileDialog Import
try { Assert-True ($open -is [Windows.Forms.OpenFileDialog] -and $open.CheckFileExists -and -not $open.Multiselect -and $open.RestoreDirectory) 'Native import file chooser contract' } finally {$open.Dispose()}
$owner=New-Object Windows.Forms.Form
$owner.ClientSize=[Drawing.Size]::new(390,500)
$owner.TopMost=$true
$owner.ShowInTaskbar=$false
$owner.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$owner.Location=[Drawing.Point]::new(10,10)
$button=New-Object Windows.Forms.Button
$button.Text='Owner'
$owner.Controls.Add($button)
$script:Popup=$owner
$script:ActiveAuxiliaryPopup=$null
$script:ActiveOwnedDialog=$null
try {
    $owner.Show();[void]$owner.Activate();[void]$button.Focus();[Windows.Forms.Application]::DoEvents()
    foreach ($mode in @('SafeEnter','Apply','Escape')) {
        $script:probeMode=$mode
        $script:probeObserved=$false
        $script:probeError=$null
        $script:ticks=0
        $timer=New-Object Windows.Forms.Timer
        $timer.Interval=80
        $timer.Add_Tick({
            $script:ticks++
            $f=$script:ActiveOwnedDialog
            if (-not $f -or -not $f.Visible) { return }
            if ($script:ticks -gt 60) { $this.Stop();$f.DialogResult=[Windows.Forms.DialogResult]::Cancel;return }
            if ([Lbs180Native]::GetForegroundWindow() -ne $f.Handle) {return}
            $this.Stop()
            try {
                $initial=([Lbs180Native]::GetFocus() -eq $f.Tag.Cancel.Handle -and -not [Lbs180Native]::IsWindowEnabled($owner.Handle))
                if ($script:probeMode -eq 'SafeEnter') {
                    $script:probeObserved=$initial
                    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
                } elseif ($script:probeMode -eq 'Apply') {
                    [Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [Windows.Forms.SendKeys]::SendWait('{TAB}')
                    $script:probeObserved=$initial -and ([Lbs180Native]::GetFocus() -eq $f.Tag.Confirm.Handle)
                    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
                } else {
                    [Windows.Forms.SendKeys]::SendWait('{TAB}')
                    $script:probeObserved=$initial -and ([Lbs180Native]::GetFocus() -eq $f.Tag.Content.Handle)
                    [Windows.Forms.SendKeys]::SendWait('{ESC}')
                }
            } catch { $script:probeError=$_;$f.DialogResult=[Windows.Forms.DialogResult]::Cancel }
            finally { if ($f.Visible -and $f.DialogResult -eq [Windows.Forms.DialogResult]::None) { $f.DialogResult=[Windows.Forms.DialogResult]::Cancel } }
        })
        $timer.Start()
        try { $result=Show-PreferencesConfirmation -Title 'Preview' -Text $preview -ConfirmText 'Apply' }
        finally { $timer.Stop();$timer.Dispose() }
        if ($script:probeError) {throw $script:probeError}
        Assert-True ($script:probeObserved -and $result -eq ($mode -eq 'Apply')) "Real native $mode confirmation"
    }
    Assert-True ([Lbs180Native]::IsWindowEnabled($owner.Handle) -and -not $script:ActiveOwnedDialog -and $owner.Visible) 'Owner restored after modal preview'
    foreach ($mode in @('Import','Export')) {
        $script:dialogObserved=$false
        $script:dialogHandle=[IntPtr]::Zero
        $script:fileTicks=0
        $timer=New-Object Windows.Forms.Timer
        $timer.Interval=100
        $timer.Add_Tick({
            $script:fileTicks++
            $h=[Lbs180Native]::GetForegroundWindow()
            if ($h -ne [IntPtr]::Zero -and $h -ne $owner.Handle -and [Lbs180Native]::GetWindow($h,4) -eq $owner.Handle) {
                if (-not $script:dialogObserved) {
                    $script:dialogObserved=$true
                    $script:dialogHandle=$h
                    [Windows.Forms.SendKeys]::SendWait('{ESC}')
                } elseif ($script:fileTicks -gt 25 -and $h -eq $script:dialogHandle) {
                    # Bounded fallback closes only the observed owner-bound
                    # dialog, never another process's foreground window.
                    [void][Lbs180Native]::PostMessage($h,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
                }
            }
        })
        $timer.Start()
        try { $path=Select-PreferencesFile -Mode $mode } finally {$timer.Stop();$timer.Dispose()}
        Assert-True ($script:dialogObserved -and -not $path) "Real native $mode file dialog cancellation"
    }
    Assert-True ([Lbs180Native]::IsWindowEnabled($owner.Handle) -and $owner.Visible) 'Owner restored after native file chooser'
} finally {$owner.Dispose()}
Write-Host "LBS180 UI TOTAL $script:passed/16"
if ($script:passed -ne 16) { exit 1 }
