#requires -version 5.1
# LBS-221 Hotfix: native WinForms alias-clear appearance and lifecycle; no firmware/settings operations.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
$script:checks = 0
function Assert-AliasClear([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS221 ALIAS CLEAR FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS221 ALIAS CLEAR $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:TestLocale -Values $Values }
function Show-DarkActionTooltip { param($Owner,[string]$Text) $script:DarkActionTooltipOwner=$Owner; $script:TipText=$Text }
function Hide-DarkActionTooltip { $script:DarkActionTooltipOwner=$null; $script:TipText='' }
function Update-ManageSaveButtonState { $script:SaveStateCalls++ }
function Set-ManageEntryAliasDraft { param([string]$Guid,[string]$Alias) $script:Mutations++; return $true }
function Save-AppSettings { $script:Mutations++ }
function Update-PopupRows { $script:Mutations++ }
$script:ColorAccent=[Drawing.Color]::FromArgb(225,37,27)
$script:ColorRow=[Drawing.Color]::FromArgb(32,32,32)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(60,30,30)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::Silver
$script:Mutations=0
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$enter=[Windows.Forms.Control].GetMethod('OnMouseEnter',$flags)
$leave=[Windows.Forms.Control].GetMethod('OnMouseLeave',$flags)
$click=[Windows.Forms.Control].GetMethod('OnClick',$flags)
$idle=[Drawing.Color]::FromArgb(180,180,180)
$hover=[Drawing.Color]::FromArgb(255,110,102)
foreach ($locale in @('en-US','de-DE')) {
    $script:TestLocale=$locale
    $expected=if ($locale -eq 'en-US') { 'Clear display name' } else { 'Anzeigename leeren' }
    foreach ($factor in @(1.0,2.5)) {
        $prefix="$locale $factor"
        $script:DarkActionTooltipOwner=$null; $script:TipText=''; $script:SaveStateCalls=0
        $script:ManageActiveDragGuid=$null
        $entry=[pscustomobject]@{Guid='12345678-1234-4234-8234-123456789abc'}
        $form=New-Object Windows.Forms.Form
        $row=New-Object Windows.Forms.Panel
        $row.Name='BootRow'; $row.Tag=$entry.Guid
        $row.Size=[Drawing.Size]::new(390,92)
        $row.BackColor=$script:ColorRow
        $form.ClientSize=[Drawing.Size]::new(1020,300)
        $form.Controls.Add($row)
        try {
            Add-BootEntryAliasEditor -Row $row -Entry $entry -Alias 'Windows: Corporate'
            [void](Set-PopupBootRowDpiLayout -Row $row -Scale $factor -Y 0)
            $frame=$row.Controls['AliasEditorFrame']
            $editor=$frame.Controls['AliasEditor']
            $clear=$frame.Controls['AliasClearButton']
            $other=$row.Controls['AliasApplyButton']
            $form.Show()
            [void]$editor.Focus()
            [Windows.Forms.Application]::DoEvents()
            Assert-AliasClear "$prefix native button and unchanged hit target" ($clear -is [Windows.Forms.Button] -and $clear.TabStop -and $clear.Width -eq [int][Math]::Round(26*$factor) -and $clear.Height -eq [int][Math]::Round(23*$factor) -and $clear.Left -eq [int][Math]::Round(292*$factor))
            Assert-AliasClear "$prefix larger cross and idle color" ([Math]::Abs($clear.Font.SizeInPoints-13.0) -lt 0.05 -and $clear.Text -eq ([string][char]0x00D7) -and $clear.ForeColor -eq $idle)
            Assert-AliasClear "$prefix integrated field background in all states" ($clear.BackColor -eq $editor.BackColor -and $frame.BackColor -eq $editor.BackColor -and $clear.FlatAppearance.MouseOverBackColor -eq $editor.BackColor -and $clear.FlatAppearance.MouseDownBackColor -eq $editor.BackColor -and $clear.FlatAppearance.BorderSize -eq 0)
            Assert-AliasClear "$prefix localized accessible action" ($clear.AccessibleName -eq $expected -and $clear.AccessibleDescription -eq $expected)
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasClear "$prefix hover ink and dark hint route" ($clear.ForeColor -eq $hover -and $script:DarkActionTooltipOwner -eq $clear -and $script:TipText -eq $expected)
            [void]$leave.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasClear "$prefix leave restores idle and closes own hint" ($clear.ForeColor -eq $idle -and $null -eq $script:DarkActionTooltipOwner)
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            Show-DarkActionTooltip -Owner $other -Text 'other'
            [void]$leave.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasClear "$prefix leave does not hide another control hint" ($script:DarkActionTooltipOwner -eq $other)
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            $editor.Text=''
            Assert-AliasClear "$prefix keyboard deletion hides cross and own hint" (-not $clear.Visible -and $null -eq $script:DarkActionTooltipOwner -and $clear.ForeColor -eq $idle)
            $editor.Text='Windows: Corporate'
            Assert-AliasClear "$prefix refilling restores cross with idle ink" ($clear.Visible -and $clear.ForeColor -eq $idle)
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            [void]$click.Invoke($clear,@([EventArgs]::Empty))
            Assert-AliasClear "$prefix clear empties text and hides tooltip, returning focus" ($editor.Text -eq '' -and -not $clear.Visible -and $null -eq $script:DarkActionTooltipOwner -and $editor.Focused)
            Assert-AliasClear "$prefix clear updates save state without committing a draft or settings" ($script:SaveStateCalls -ge 3 -and $script:Mutations -eq 0)
            $editor.Text='Temporary'
            [void]$enter.Invoke($clear,@([EventArgs]::Empty))
            $clear.Dispose()
            Assert-AliasClear "$prefix disposal clears owned tooltip" ($clear.IsDisposed -and $null -eq $script:DarkActionTooltipOwner)
        } finally { $form.Dispose(); $script:DarkActionTooltipOwner=$null }
    }
}
Assert-AliasClear 'Fixture did not commit any alias draft or persistent settings' ($script:Mutations -eq 0)
Write-Host "LBS221 ALIAS CLEAR TOTAL $script:checks/49"
if ($script:checks -ne 49) { throw "Expected 49 native alias-clear assertions, got $script:checks" }
