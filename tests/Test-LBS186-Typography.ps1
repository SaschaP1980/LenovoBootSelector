#requires -version 5.1
# LBS-186: real WinForms typography, measured text fit and effective contrast.
# Synthetic 96/240-DPI geometry is not physical mixed-monitor acceptance.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
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
. (Join-Path $root 'src\Core\BootNextSelectionState.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')
. (Join-Path $root 'src\UI\RefreshPresentation.ps1')
. (Join-Path $root 'src\UI\DefaultTargetPresentation.ps1')
. (Join-Path $root 'src\UI\ManageEntriesState.ps1')
. (Join-Path $root 'src\Application\BootNextSelectionController.ps1')

$script:checks = 0
function Assert-Lbs186([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "LBS186 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS186 $Name"
}
function Get-Lbs186Luminance([Drawing.Color]$Color) {
    $sum = 0.0
    $channels = @($Color.R,$Color.G,$Color.B)
    $weights = @(0.2126,0.7152,0.0722)
    for ($i = 0; $i -lt 3; $i++) {
        $v = $channels[$i]/255.0
        $linear = if ($v -le 0.04045) { $v/12.92 } else { [Math]::Pow(($v+0.055)/1.055,2.4) }
        $sum += $linear*$weights[$i]
    }
    return $sum
}
function Test-Lbs186Contrast([Drawing.Color]$Foreground,[Drawing.Color]$Background,[string]$Name) {
    $a = Get-Lbs186Luminance $Foreground
    $b = Get-Lbs186Luminance $Background
    $ratio = ([Math]::Max($a,$b)+0.05)/([Math]::Min($a,$b)+0.05)
    Write-Host ("LBS186_CONTRAST {0} ratio={1:F2}" -f $Name,$ratio)
    return ($ratio -ge 4.5)
}
function Test-Lbs186TextFit($Control,[Drawing.Graphics]$Graphics,[single]$Dpi,[switch]$HeightOnly) {
    if ($null -eq $Control -or -not $Control.Font) { return $false }
    $h = $Control.Font.GetHeight($Dpi)
    $size = $Graphics.MeasureString([string]$Control.Text,$Control.Font)
    Write-Host ("LBS186_FONT {0} dpi={1} pt={2} inkHeight={3:F2} width={4:F2} box={5}x{6}" -f $Control.Text,$Dpi,$Control.Font.Size,$h,$size.Width,$Control.Width,$Control.Height)
    return ($h -le $Control.Height -and ($HeightOnly -or $size.Width -le $Control.Width))
}
function Test-Lbs186DisabledInk($Button,[int]$ExpectedBackground,[string]$Label) {
    $raster=New-Object Drawing.Bitmap($Button.Width,$Button.Height)
    try {
        $Button.DrawToBitmap($raster,[Drawing.Rectangle]::new(0,0,$Button.Width,$Button.Height))
        $background=$raster.GetPixel([int]($Button.Width*0.06),[int]($Button.Height*0.5))
        $brightInk=0; $darkInk=0
        for ($y=[int]($Button.Height*0.16); $y -lt [int]($Button.Height*0.84); $y++) {
            for ($x=[int]($Button.Width*0.10); $x -lt [int]($Button.Width*0.90); $x++) {
                $pixel=$raster.GetPixel($x,$y)
                if ($pixel.R -eq $pixel.G -and $pixel.G -eq $pixel.B) {
                    if ($pixel.R -ge 140 -and $pixel.R -le 165) { $brightInk++ }
                    if ($pixel.R -lt ($Button.BackColor.R-10)) { $darkInk++ }
                }
            }
        }
        # Use the actual control background as the contrast reference. A
        # fixed interior raster sample can land on subpixel-antialiased ink,
        # especially on long ellipsized footer text at synthetic 240 DPI.
        $surface=$Button.BackColor
        Write-Host ("LBS186_PENDING_RASTER {0} sampled={1},{2},{3} surface={4},{5},{6} ink={7} dark={8}" -f $Label,$background.R,$background.G,$background.B,$surface.R,$surface.G,$surface.B,$brightInk,$darkInk)
        return ($surface.R -eq $ExpectedBackground -and $surface.G -eq $ExpectedBackground -and $surface.B -eq $ExpectedBackground -and $brightInk -ge 10 -and $darkInk -eq 0 -and
            (Test-Lbs186Contrast ([Drawing.Color]::FromArgb(140,140,140)) $surface $Label))
    }
    finally { $raster.Dispose() }
}
# Read the actual palette constants rather than maintaining independent test colors.
foreach ($name in @('ColorHeader','ColorBackground','ColorRow','ColorHover','ColorSelectedRow','ColorSurface','ColorPrimary','ColorSecondary','ColorAccent','ColorWarning')) {
    $pattern = '(?m)^\$script:' + $name + ' = \[Drawing\.Color\]::FromArgb\((\d+),\s*(\d+),\s*(\d+)\)'
    $m = [regex]::Match($template,$pattern)
    if (-not $m.Success) { throw "Missing palette constant $name" }
    Set-Variable -Scope Script -Name $name -Value ([Drawing.Color]::FromArgb([int]$m.Groups[1].Value,[int]$m.Groups[2].Value,[int]$m.Groups[3].Value))
}
$script:AppVersion = '1.5.1.0'
$script:TestCapabilities = [pscustomobject]@{ State='Ready'; CanRefresh=$true; CanSetDefaultTarget=$true; CanSetBootNext=$true; IsChecking=$false; CanManageEntries=$true }
$script:BackgroundRefreshState = [pscustomobject]@{ Active=$false }
$script:UpdateState = [pscustomobject]@{ Status='UpToDate'; AvailableManifest=$null }
$script:TestGuid = '{11111111-2222-3333-4444-555555555555}'
$script:TestEntry = [pscustomobject]@{ Guid=$script:TestGuid; Title=('Long firmware model '+('NVMe ABC123456789 ' * 12)); Subtitle=('Storage description '+('USB 123456789 ' * 12)); RawDescription='USB HDD'; Symbol=[string][char]0x25CF; Accent=$script:ColorAccent; TypeTooltip='USB' }
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:TestLocale -Values $Values }
function Get-CurrentSystemFunctionsCapabilities { $script:TestCapabilities }
function Test-BackgroundRefreshActive { param($State) [bool]$State.Active }
function Get-MaintenanceBusyStatusText { Get-LocalizedString -Key 'Status.Checking' }
function Test-ManageEntriesDirty { return [bool]$script:TestDirty }
function Stop-ManageEntriesMode { param([switch]$Save) if ($Save) { $script:SaveCalls++ } }
function Get-EntryByGuid { param([string]$Guid) $script:TestEntry }
function Get-EntryDisplayTitle { param($Entry,[switch]$UseManageDraft) [string]$Entry.Title }
function Get-EntryAlias { param([string]$Guid,[switch]$UseManageDraft) $script:TestAlias }
function Test-ManageEntryHidden { param([string]$Guid) [bool]$script:TestHidden }
function Get-NextBootTargetDisplayName { [string]$script:TestEntry.Title }
function Resolve-BootNextDisplayStateCore { param($DefaultGuid,$EffectiveNextGuid,$FirmwareReadSucceeded,$Checking,$EffectiveTargetKnown) 'different' }
# Execute the canonical template's presentation-only restart updater, not a copy.
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
$restartAst=$ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-RestartTargetUi'},$true)
if (-not $restartAst -or $errors.Count -gt 0) { throw 'Cannot extract canonical restart presentation function' }
. ([scriptblock]::Create($restartAst.Extent.Text))

foreach ($locale in @('en-US','de-DE')) {
    $script:TestLocale=$locale
    foreach ($factor in @(1.0,2.5)) {
        $dpi=[single](96*$factor)
        $script:BootTypeToolTip = New-Object System.Windows.Forms.ToolTip
        $form=New-Object System.Windows.Forms.Form
        $bitmap=New-Object Drawing.Bitmap(1,1)
        $bitmap.SetResolution($dpi,$dpi)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $normal=$null; $hidden=$null; $editing=$null; $pending=$null
        try {
            $form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None
            Initialize-PopupDpiLayout -Form $form
            $form.ClientSize=[Drawing.Size]::new(390,672)
            $rootPanel=New-Object System.Windows.Forms.Panel
            $rootPanel.Name='PopupRoot'
            $rootPanel.Size=[Drawing.Size]::new(390,672)
            $form.Controls.Add($rootPanel)
            Add-PopupHeaderSection -Root $rootPanel
            Add-PopupSettingsSection -Root $rootPanel
            Add-PopupRestartSection -Root $rootPanel
            Add-PopupManageEntriesSection -Root $rootPanel
            Complete-PopupDpiLayout -Form $form -Scale $factor
            $script:DefaultGuid=$script:TestGuid
            $script:SelectedGuid=$script:TestGuid
            $script:NextBootFirmwareReadVerified=$true
            Update-DefaultUi
            Update-RestartTargetUi
            $tag="$locale $([int]($factor*100))%"
            $status=$script:HeaderStatusLabel
            $script:UpdateState.Status='UpdateAvailable'
            $script:UpdateState.AvailableManifest=[pscustomobject]@{Version='9.9.9.9'}
            $script:HeaderStatusHovered=$true
            Update-HeaderRefreshStatus
            Assert-Lbs186 "$tag header status fits and hover text is readable" ((Test-Lbs186TextFit $status $graphics $dpi) -and (Test-Lbs186Contrast $status.ForeColor $status.BackColor 'header-update'))
            $script:HeaderStatusHovered=$false
            $script:UpdateState.Status='UpToDate'
            $script:UpdateState.AvailableManifest=$null
            $section=$rootPanel.Controls.Find('SectionLabel',$true)[0]
            $customize=$script:ManageEntriesButton
            Assert-Lbs186 "$tag section and customize roles fit" ((Test-Lbs186TextFit $section $graphics $dpi) -and (Test-Lbs186TextFit $customize $graphics $dpi))
            $value=$script:DefaultValueLabel
            Assert-Lbs186 "$tag default long value retains full accessible text and tooltip" ($value.AccessibleDescription -eq $value.Text -and $script:BootTypeToolTip.GetToolTip($value).Contains($value.Text) -and (Test-Lbs186TextFit $value $graphics $dpi -HeightOnly))
            $target=$script:RestartTargetLabel
            Assert-Lbs186 "$tag restart long status keeps complete text and readable interaction" ($target.AccessibleName -eq $target.Text -and $script:BootTypeToolTip.GetToolTip($target) -eq $target.Text -and (Test-Lbs186TextFit $target $graphics $dpi -HeightOnly) -and (Test-Lbs186Contrast $target.ForeColor $script:ColorSelectedRow 'restart-selected'))
            $manage=$rootPanel.Controls['ManageEntriesPanel']
            $textControls=@($manage.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -or $_ -is [System.Windows.Forms.Button] })
            $fit=$true
            foreach ($control in $textControls) {
                if (-not (Test-Lbs186TextFit $control $graphics $dpi)) { $fit=$false }
            }
            Assert-Lbs186 "$tag localized Manage labels/actions fit" $fit
            $save=$script:ManageSaveButton
            $manage.Visible=$true
            $form.Show()
            $script:TestDirty=$false
            $script:SaveCalls=0
            Update-ManageSaveButtonState
            $save.PerformClick()
            Assert-Lbs186 "$tag clean draft Save remains genuinely disabled and cannot invoke Save" (-not $save.Enabled -and -not $save.CanSelect -and $script:SaveCalls -eq 0 -and $save.Cursor -eq [Windows.Forms.Cursors]::Default)
            # Verify actual disabled ink, not only ForeColor (the flat WinForms
            # adapter can substitute near-black text on a dark button).
            $raster=New-Object Drawing.Bitmap($save.Width,$save.Height)
            try {
                $save.DrawToBitmap($raster,[Drawing.Rectangle]::new(0,0,$save.Width,$save.Height))
                $background=$raster.GetPixel([int]($save.Width*0.06),[int]($save.Height*0.5))
                $maxGray=0; $brightInk=0; $darkInk=0
                for ($y=[int]($save.Height*0.15); $y -lt [int]($save.Height*0.85); $y++) {
                    for ($x=[int]($save.Width*0.10); $x -lt [int]($save.Width*0.90); $x++) {
                        $pixel=$raster.GetPixel($x,$y)
                        if ($pixel.R -eq $pixel.G -and $pixel.G -eq $pixel.B) {
                            $maxGray=[Math]::Max($maxGray,[int]$pixel.R)
                            if ($pixel.R -ge 140 -and $pixel.R -le 160) { $brightInk++ }
                            if ($pixel.R -lt ($background.R-10)) { $darkInk++ }
                        }
                    }
                }
                Write-Host ("LBS186_SAVE_RASTER {0} background={1} maxGray={2} brightInk={3} darkInk={4}" -f $tag,$background.R,$maxGray,$brightInk,$darkInk)
                Assert-Lbs186 "$tag disabled Save raster contains readable neutral text" ($background.R -eq 35 -and $brightInk -ge 10 -and (Test-Lbs186Contrast ([Drawing.Color]::FromArgb(140,140,140)) $background 'disabled-save-ink'))
            }
            finally { $raster.Dispose() }
            $script:TestDirty=$true
            Update-ManageSaveButtonState
            $save.PerformClick()
            Assert-Lbs186 "$tag dirty draft re-enables the existing Save action exactly once" ($save.Enabled -and $save.CanSelect -and $script:SaveCalls -eq 1 -and $save.BackColor.ToArgb() -eq $script:ColorAccent.ToArgb() -and $save.Cursor -eq [Windows.Forms.Cursors]::Hand)
            $script:TestDirty=$false
            Update-ManageSaveButtonState
            $save.PerformClick()
            Assert-Lbs186 "$tag returning to clean draft disables Save again" (-not $save.Enabled -and $script:SaveCalls -eq 1)
            $script:TestDirty=$true
            Update-ManageSaveButtonState
            Assert-Lbs186 "$tag enabled Save text meets contrast in all states" ((Test-Lbs186Contrast $save.ForeColor $save.BackColor 'save-normal') -and (Test-Lbs186Contrast $save.ForeColor $save.FlatAppearance.MouseOverBackColor 'save-hover') -and (Test-Lbs186Contrast $save.ForeColor $save.FlatAppearance.MouseDownBackColor 'save-pressed'))
            # LBS-186: actual pending BootNext UI, no task or firmware writes.
            $manage.Visible=$false
            $script:BootNextPendingGuid=$script:TestGuid
            Update-DefaultUi
            Update-RestartTargetUi
            $reboot=$script:RestartButton
            $pendingFooter=$script:RestartTargetLabel
            Assert-Lbs186 "$tag pending restart has readable disabled ink" (Test-Lbs186DisabledInk $reboot 34 "$tag restart")
            Assert-Lbs186 "$tag pending passive status retains readable amber text" (
                $pendingFooter -is [Windows.Forms.Label] -and $pendingFooter.Enabled -and
                $pendingFooter.ForeColor.ToArgb() -eq $script:ColorWarning.ToArgb() -and
                (Test-Lbs186TextFit $pendingFooter $graphics $dpi -HeightOnly) -and
                (Test-Lbs186Contrast $pendingFooter.ForeColor $script:ColorSurface 'pending-status'))
            Assert-Lbs186 "$tag pending interlock preserves restart and one-time default gates" (
                -not $reboot.Enabled -and -not $reboot.CanSelect -and
                $pendingFooter.Enabled -and -not $pendingFooter.TabStop -and
                $pendingFooter.AccessibleDescription -eq $pendingFooter.Text -and
                (-not $script:RestartUseDefaultButton.Visible -or -not $script:RestartUseDefaultButton.Enabled))
            $defaultName=$script:DefaultButton.Controls[0]
            $disabledInk=[Drawing.Color]::FromArgb(146,146,146).ToArgb()
            Assert-Lbs186 "$tag pending default row is visibly gated" (-not $script:DefaultInteractionEnabled -and $script:DefaultButton.Cursor -eq [Windows.Forms.Cursors]::Default -and $defaultName.ForeColor.ToArgb() -eq $disabledInk -and $script:DefaultValueLabel.ForeColor.ToArgb() -eq $disabledInk -and $script:DefaultArrowLabel.ForeColor.ToArgb() -eq $disabledInk)
            $script:BootNextPendingGuid=$null
            Update-DefaultUi
            Update-RestartTargetUi
            Assert-Lbs186 "$tag completion restores ready interactions" ($reboot.Enabled -and $pendingFooter.Enabled -and $script:DefaultInteractionEnabled -and $script:DefaultButton.Cursor -eq [Windows.Forms.Cursors]::Hand -and $defaultName.ForeColor.ToArgb() -eq $script:ColorPrimary.ToArgb() -and $script:DefaultArrowLabel.ForeColor.ToArgb() -eq $script:ColorSecondary.ToArgb())
            $footer=$rootPanel.Controls['FooterPanel'].Controls[0]
            Assert-Lbs186 "$tag footer role fits and is readable" ((Test-Lbs186TextFit $footer $graphics $dpi) -and (Test-Lbs186Contrast $footer.ForeColor $script:ColorSurface 'version-footer'))
            $script:IsManageEntriesMode=$false
            $script:BootNextPendingGuid=$null
            $script:TestAlias=$null
            $script:TestHidden=$false
            $handlers=New-BootEntryInteractionHandlers
            $normal=(New-BootEntryRow -Entry $script:TestEntry -Y 0 -BaseRowHeight 60 -Handlers $handlers).Row
            [void](Set-PopupBootRowDpiLayout -Row $normal -Scale $factor -Y 0)
            $title=$normal.Controls['BootTitleLabel']; $sub=$normal.Controls['BootSubtitleLabel']
            Assert-Lbs186 "$tag long row text remains accessible and fits vertically" ($title.AccessibleDescription -eq $title.Text -and $sub.AccessibleDescription -eq $sub.Text -and $script:BootTypeToolTip.GetToolTip($title).Contains($title.Text) -and $script:BootTypeToolTip.GetToolTip($sub).Contains($sub.Text) -and (Test-Lbs186TextFit $title $graphics $dpi -HeightOnly) -and (Test-Lbs186TextFit $sub $graphics $dpi -HeightOnly) -and $title.Bottom -lt $sub.Top)
            Assert-Lbs186 "$tag selected title and subtitle meet contrast" ((Test-Lbs186Contrast $title.ForeColor $normal.BackColor 'selected-title') -and (Test-Lbs186Contrast $sub.ForeColor $normal.BackColor 'selected-subtitle'))
            $script:BootNextPendingGuid=$script:TestGuid
            $script:SelectedGuid=$null
            $pending=(New-BootEntryRow -Entry $script:TestEntry -Y 0 -BaseRowHeight 60 -Handlers $handlers).Row
            [void](Set-PopupBootRowDpiLayout -Row $pending -Scale $factor -Y 0)
            $p=$pending.Controls['BootSubtitleLabel']
            Assert-Lbs186 "$tag pending status text remains readable" ((Test-Lbs186TextFit $p $graphics $dpi -HeightOnly) -and (Test-Lbs186Contrast $p.ForeColor $pending.BackColor 'pending-subtitle'))
            $script:BootNextPendingGuid=$null
            $script:IsManageEntriesMode=$true
            $script:TestHidden=$true
            $script:ManageAliasEditGuid=$null
            $hidden=(New-BootEntryRow -Entry $script:TestEntry -Y 0 -BaseRowHeight 60 -Handlers $handlers).Row
            [void](Set-PopupBootRowDpiLayout -Row $hidden -Scale $factor -Y 0)
            Set-RowHoverState -Control $hidden -Hover $true
            Assert-Lbs186 "$tag hidden hover retains readable subtitle and visible state" ((Test-Lbs186Contrast $hidden.Controls['BootSubtitleLabel'].ForeColor $hidden.BackColor 'hidden-hover-subtitle') -and (Test-Lbs186Contrast $hidden.Controls['BootTitleLabel'].ForeColor $hidden.BackColor 'hidden-hover-title') -and $hidden.Controls['VisibilityGlyph'].AccessibleName -eq 'hidden')
            $script:TestHidden=$false
            $script:ManageAliasEditGuid=$script:TestGuid
            $script:TestAlias='My long alias'
            $editing=(New-BootEntryRow -Entry $script:TestEntry -Y 0 -BaseRowHeight 60 -Handlers $handlers).Row
            [void](Set-PopupBootRowDpiLayout -Row $editing -Scale $factor -Y 0)
            $apply=$editing.Controls['AliasApplyButton']; $cancel=$editing.Controls['AliasCancelButton']
            Assert-Lbs186 "$tag alias actions fit without overlap and preserve red text contrast" ((Test-Lbs186TextFit $apply $graphics $dpi) -and (Test-Lbs186TextFit $cancel $graphics $dpi) -and $apply.Right -lt $cancel.Left -and (Test-Lbs186Contrast $apply.ForeColor $apply.FlatAppearance.MouseOverBackColor 'alias-apply-hover'))
        }
        finally {
            foreach ($row in @($normal,$pending,$hidden,$editing)) { if ($row) { $row.Dispose() } }
            $graphics.Dispose()
            $bitmap.Dispose()
            $form.Dispose()
            $script:BootTypeToolTip.Dispose()
            $script:BootTypeToolTip=$null
            $script:ManageAliasEditGuid=$null
            $script:IsManageEntriesMode=$false
        }
    }
}
Write-Host "LBS186 TYPOGRAPHY TOTAL $script:checks/84"
if ($script:checks -ne 84) { throw "LBS186 expected 84 checks, got $script:checks" }
