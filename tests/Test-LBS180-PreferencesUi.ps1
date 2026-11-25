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
$template=[IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'))
$prefix='Add-Type -TypeDefinition @"'
$begin=$template.IndexOf($prefix,[StringComparison]::Ordinal)+$prefix.Length
$end=$template.IndexOf('"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing',$begin,[StringComparison]::Ordinal)
if ($begin -lt $prefix.Length -or $end -le $begin) {throw 'Missing canonical C#'}
Add-Type -TypeDefinition ($template.Substring($begin,$end-$begin)) -ReferencedAssemblies System.Windows.Forms,System.Drawing,Accessibility
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
$view=New-PreferencesPreviewView $plan
$planBefore=ConvertTo-Json -InputObject $plan -Depth 8 -Compress
Assert-True ($view.Matched -eq 1 -and $view.Changed -eq 1 -and $view.Skipped -eq 1 -and $view.LocalOnly -eq 1 -and $view.Unavailable -eq 1 -and $view.Rows.Count -eq 4) 'Separate reconciliation and effective-change counts'
$details=@(Get-PreferencesDetailSegments $view.Rows[0]) -join ' '
Assert-True ($details.Contains($g1) -and $details.Contains('Before') -and $details.Contains('After') -and $details.Contains('visible') -and $details.Contains('hidden') -and $view.OldLocale -ceq 'en-US' -and $view.Locale -ceq 'de-DE') 'All comparison evidence remains accessible'
Assert-True ((Format-PreferencesPreviewValue ('A'+[char]0x202e+'B')).Contains('\u202e')) 'Preview escapes invisible formatting'
$longRow=[pscustomobject]@{Guid=$g1;Title='Long';Status='Matched';OldAlias=('x'*60000);NewAlias='';OldHidden=$false;NewHidden=$false;OldPosition=1;NewPosition=1;AliasSkipped=$false}
$largePlan=[pscustomobject]@{Rows=@(1..512 | ForEach-Object {$longRow});UnavailableLocal=@();OldLocale='en-US';Locale='en-US'}
$large=New-PreferencesConfirmationForm -Title 'Preview' -ConfirmText 'Apply' -Plan $largePlan
try {
    $large.Tag.Page=63
    Update-PreferencesConfirmationBody $large
    Assert-True ($large.Tag.View.Rows.Count -eq 512 -and $large.Tag.PageCount -eq 64 -and $large.Tag.VisibleRows.Count -eq 8 -and $large.Tag.VisibleRows[-1].Id -eq 'Entry511') 'All 512 incoming entries reachable through bounded pages'
    $segments=@(Get-PreferencesDetailSegments $large.Tag.View.Rows[0])
    Assert-True (($segments -join '').Contains(('x'*60000)) -and @($segments | Where-Object Length -gt 600).Count -eq 0) 'Long legacy detail not truncated; bounded segments'
} finally {$large.Dispose()}
$exportContext=[pscustomobject]@{Settings=(New-DefaultAppSettingsCore);Entries=$local}
foreach ($locale in @('en-US','de-DE')) {
    $script:Locale=$locale
    foreach ($scale in @(1.0,2.5)) {
        $area=[Drawing.Rectangle]::new(0,0,1920,1080)
        $form=New-PreferencesConfirmationForm -Title (Get-LocalizedString -Key 'Preferences.PreviewTitle') -Plan $plan -ConfirmText (Get-LocalizedString -Key 'Preferences.Apply')
        try {
            Set-PreferencesConfirmationLayout -Form $form -Scale $scale -WorkingArea $area
            $t=$form.Tag;$sh=$t.Shell
            $fit=($area.Contains($form.Bounds) -and $form.ClientRectangle.Contains($sh.Viewport.Bounds) -and $sh.Footer.ClientRectangle.Contains($t.Cancel.Bounds) -and $sh.Footer.ClientRectangle.Contains($t.Confirm.Bounds) -and $sh.Viewport.Bottom -le $sh.Footer.Top -and -not $t.Cancel.Bounds.IntersectsWith($t.Confirm.Bounds))
            $fit=$fit -and $form.AcceptButton -eq $t.Cancel -and $form.CancelButton -eq $t.Cancel -and $sh.Scroll -is [LenovoVerticalScrollBar]
            Assert-True $fit "$locale/$scale structured preview geometry, dark scrollbar and safe dismissal"
            $names=@('MetricMatched','MetricChanged','MetricSkipped','MetricLocalOnly','LanguageComparison','ReconcileWarning','SystemUnchanged','FilterAll','FilterChanged','FilterSkipped','FilterLocalOnly','FilterUnavailable','Entry0Title','Entry0Details','ExcludedScope','PrivacyBody')
            Assert-True (@($names | Where-Object {$form.Controls.Find($_,$true).Count -ne 1}).Count -eq 0 -and $form.Controls.Find('PreferencesPreviewText',$true).Count -eq 0 -and $t.VisibleRows.Count -eq 4) "$locale/$scale distinct structured preview controls"
            $flagBefore=$form.Controls.Find('LanguageBeforeFlag',$true)[0]
            $flagAfter=$form.Controls.Find('LanguageAfterFlag',$true)[0]
            $beforeBitmap=[Drawing.Bitmap]::new($flagBefore.Width,$flagBefore.Height)
            $afterBitmap=[Drawing.Bitmap]::new($flagAfter.Width,$flagAfter.Height)
            try {
                $flagBefore.DrawToBitmap($beforeBitmap,$flagBefore.ClientRectangle)
                $flagAfter.DrawToBitmap($afterBitmap,$flagAfter.ClientRectangle)
                $beforePixel=$beforeBitmap.GetPixel($beforeBitmap.Width-1,$beforeBitmap.Height-1).ToArgb()
                $afterPixel=$afterBitmap.GetPixel($afterBitmap.Width-1,$afterBitmap.Height-1).ToArgb()
                Assert-True ($flagBefore.Tag -ceq 'en-US' -and $flagAfter.Tag -ceq 'de-DE' -and $beforePixel -eq [Drawing.Color]::FromArgb(178,34,52).ToArgb() -and $afterPixel -eq [Drawing.Color]::FromArgb(255,206,0).ToArgb()) "$locale/$scale canonical US/German flag raster"
            } finally {$beforeBitmap.Dispose();$afterBitmap.Dispose()}
        } finally {$form.Dispose()}
        $form=New-PreferencesConfirmationForm -Title (Get-LocalizedString -Key 'Preferences.Export') -ExportContext $exportContext -ConfirmText (Get-LocalizedString -Key 'Preferences.ExportConfirm')
        try {
            Set-PreferencesConfirmationLayout -Form $form -Scale $scale -WorkingArea $area
            $t=$form.Tag;$sh=$t.Shell
            $names=@('ExportCount','IncludedLanguage','IncludedAliases','IncludedVisibility','IncludedOrder','ExcludedScope','PrivacyBody','UnavailableNote')
            $fit=($area.Contains($form.Bounds) -and $sh.Footer.ClientRectangle.Contains($t.Cancel.Bounds) -and $sh.Footer.ClientRectangle.Contains($t.Confirm.Bounds) -and $t.Shell.Scroll -is [LenovoVerticalScrollBar] -and @($names | Where-Object {$form.Controls.Find($_,$true).Count -ne 1}).Count -eq 0)
            if ($scale -eq 1.0) {$fit=$fit -and $sh.Scroll.Maximum -eq 0 -and $sh.Viewport.Height -eq $sh.Body.Height}
            Assert-True $fit "$locale/$scale compact export with included/excluded/private sections"
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
    foreach ($mode in @('SafeEnter','Apply','Escape','Filters')) {
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
                    $script:probeObserved=$initial -and ([Lbs180Native]::GetFocus() -eq $f.Tag.Confirm.Handle)
                    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
                } elseif ($script:probeMode -eq 'Escape') {
                    [Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [Windows.Forms.SendKeys]::SendWait('{TAB}')
                    $focused=$f.Controls.Find('FilterAll',$true)[0]
                    $script:probeObserved=$initial -and $focused.Focused
                    [Windows.Forms.SendKeys]::SendWait('{ESC}')
                } else {
                    $ok=$initial
                    foreach ($key in @('Changed','Skipped','LocalOnly','Unavailable','All')) {
                        $f.Controls.Find(('Filter'+$key),$true)[0].PerformClick()
                        $expected=if ($key -eq 'All') {4} else {1}
                        $ok=$ok -and $f.Tag.Filter -ceq $key -and $f.Tag.VisibleRows.Count -eq $expected
                    }
                    $f.Controls.Find('Entry0Details',$true)[0].PerformClick()
                    $detailLabels=@($f.Tag.Shell.Body.Controls | ForEach-Object {$_.Controls} | Where-Object Name -like 'Entry0Detail*' | Where-Object {$_ -is [Windows.Forms.Label]})
                    $ok=$ok -and $f.Tag.Expanded -ceq 'Entry0' -and (($detailLabels.Text -join ' ').Contains($g1))
                    $script:probeObserved=$ok -and (ConvertTo-Json -InputObject $plan -Depth 8 -Compress) -ceq $planBefore
                    $f.DialogResult=[Windows.Forms.DialogResult]::Cancel
                }
            } catch { $script:probeError=$_;$f.DialogResult=[Windows.Forms.DialogResult]::Cancel }
            finally { if ($f.Visible -and $f.DialogResult -eq [Windows.Forms.DialogResult]::None) { $f.DialogResult=[Windows.Forms.DialogResult]::Cancel } }
        })
        $timer.Start()
        try { $result=Show-PreferencesConfirmation -Title 'Preview' -Plan $plan -ConfirmText 'Apply' }
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
Write-Host "LBS180 UI TOTAL $script:passed/31"
if ($script:passed -ne 31) { exit 1 }
