#requires -version 5.1
# Actual native editor input, shared draft admission and isolated settings persistence.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Infrastructure\SettingsRepository.ps1')
. (Join-Path $root 'src\Application\SettingsService.ps1')
. (Join-Path $root 'src\UI\ManageEntries.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Lbs227Edit {
    [DllImport("user32.dll", EntryPoint="SendMessageW")]
    public static extern IntPtr Send(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
'@
$script:checks=0
function Assert-Limit([string]$Name,[bool]$Good) {
    if (-not $Good) { throw "LBS227 ALIAS LIMIT FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS227 ALIAS LIMIT $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) Get-LocalizedStringCore -Key $Key -Locale $script:UiLocale -Values $Values }
function Show-DarkActionTooltip { param($Owner,[string]$Text) $script:DarkActionTooltipOwner=$Owner; $script:TipText=$Text }
function Hide-DarkActionTooltip { $script:DarkActionTooltipOwner=$null; $script:TipText='' }
function Update-ManageSaveButtonState {}
function Update-ManageEntriesUiState {}
function Reset-ManageDragPreview {}
function Update-PopupRows { param($Reason) }
$script:ColorAccent=[Drawing.Color]::Red
$script:ColorRow=[Drawing.Color]::FromArgb(32,32,32)
$script:ColorSelectedRow=[Drawing.Color]::FromArgb(60,30,30)
$script:ColorPrimary=[Drawing.Color]::White
$script:ColorSecondary=[Drawing.Color]::Silver
$script:UiLocale='en-US'
$script:LocalePreferenceSource='user'
$script:LegacyDefaultGuid=$null
$script:SettingsLoadState=$null
$script:SettingsDir=Join-Path ([IO.Path]::GetTempPath()) ('lbs227-'+[guid]::NewGuid().ToString('N'))
$script:SettingsPath=Join-Path $script:SettingsDir 'settings.json'
$script:EntryOrder=@('legacy','new')
$script:HiddenEntryGuids=@()
$legacy='L'*45
$script:EntryAliases=@{legacy=$legacy}
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$click=[Windows.Forms.Control].GetMethod('OnClick',$flags)
$key=[Windows.Forms.Control].GetMethod('OnKeyDown',$flags)
function Begin-TestManage {
    $script:IsManageEntriesMode=$true
    $script:ManageEntryAliases=Copy-EntryAliasMap $script:EntryAliases
    $script:ManageBaselineEntryAliases=Copy-EntryAliasMap $script:EntryAliases
    $script:ManageEntryOrder=@($script:EntryOrder)
    $script:ManageHiddenEntryGuids=@($script:HiddenEntryGuids)
    $script:ManageAliasEditGuid=$null
}
function Open-TestEditor([string]$Guid) {
    if ($script:Popup) { $script:Popup.Dispose() }
    $script:Popup=New-Object Windows.Forms.Form
    $script:Popup.ClientSize=[Drawing.Size]::new(410,120)
    $script:Popup.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None
    $script:Popup.TopMost=$true
    $row=New-Object Windows.Forms.Panel
    $row.Size=[Drawing.Size]::new(390,92)
    $script:Popup.Controls.Add($row)
    $script:ManageAliasEditGuid=$Guid
    Add-BootEntryAliasEditor -Row $row -Entry ([pscustomobject]@{Guid=$Guid}) -Alias ([string]$script:ManageEntryAliases[$Guid])
    $editor=$row.Controls['AliasEditorFrame'].Controls['AliasEditor']
    $script:Popup.Show()
    [void]$editor.Focus()
    [Windows.Forms.Application]::DoEvents()
    return $editor
}
try {
    Assert-Limit 'canonical limit' ((Get-EntryAliasMaxLengthCore) -eq 30)
    Assert-Limit '30 accepted, 31 rejected' ((Test-EntryAliasChangeCore ('a'*30) '') -and -not (Test-EntryAliasChangeCore ('a'*31) ''))
    Assert-Limit 'legacy equality is ordinal, changed overlength rejected' ((Test-EntryAliasChangeCore $legacy $legacy) -and -not (Test-EntryAliasChangeCore $legacy.ToLowerInvariant() $legacy))
    Assert-Limit 'empty and normalized valid alias permitted' ((Test-EntryAliasChangeCore '' $legacy) -and (Test-EntryAliasChangeCore (' '+('a'*30)+' ') $legacy))
    Save-AppSettings
    Assert-Limit 'legacy initially preserved in real settings' ((Get-AppSettingsLoadResult).Settings.entryAliases['legacy'] -ceq $legacy)
    Begin-TestManage
    $editor=Open-TestEditor 'new'
    Assert-Limit 'actual editor length and empty cue' ($editor.MaxLength -eq 30 -and $editor.Text -eq '' -and $editor.Parent.Controls['AliasCueLabel'].Visible)
    $editor.Text='a'*29
    $editor.SelectionStart=$editor.TextLength
    [void][Lbs227Edit]::Send($editor.Handle,0x0102,[IntPtr][int][char]'x',[IntPtr]1)
    [void][Lbs227Edit]::Send($editor.Handle,0x0102,[IntPtr][int][char]'y',[IntPtr]1)
    Assert-Limit 'native WM_CHAR stops at 30' ($editor.Text -ceq (('a'*29)+'x'))
    $editor.SelectAll()
    [Windows.Forms.Clipboard]::SetText('b'*45)
    $editor.Paste()
    Assert-Limit 'native paste limited to 30' ($editor.Text -ceq ('b'*30))
    $editor.SelectionStart=10; $editor.SelectionLength=5
    [Windows.Forms.Clipboard]::SetText('c'*20)
    $editor.Paste()
    Assert-Limit 'selection replacement respects total limit' ($editor.Text -ceq (('b'*10)+('c'*5)+('b'*15)))
    $editor.Text='x'*31
    $row=$editor.Parent.Parent
    [void]$click.Invoke($row.Controls['AliasApplyButton'],@([EventArgs]::Empty))
    Assert-Limit 'Apply rejects programmatically assigned overlength text' (-not $script:ManageEntryAliases.ContainsKey('new') -and $script:ManageAliasEditGuid -eq 'new' -and $script:TipText -eq 'Display name: maximum 30 characters')
    $ev=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Enter)
    [void]$key.Invoke($editor,@($ev))
    Assert-Limit 'Enter rejects and suppresses invalid commit' ($ev.SuppressKeyPress -and -not $script:ManageEntryAliases.ContainsKey('new') -and $script:ManageAliasEditGuid -eq 'new')
    Assert-Limit 'implicit commit rejects, does not end edit' (-not (Commit-ActiveManageAliasEditor) -and $script:ManageAliasEditGuid -eq 'new')
    Stop-ManageEntriesMode -Save
    Assert-Limit 'global Save rejects invalid active editor without persisting' ($script:IsManageEntriesMode -and $script:ManageAliasEditGuid -eq 'new' -and -not (Get-AppSettingsLoadResult).Settings.entryAliases.ContainsKey('new'))
    $editor.Text='v'*30
    [void]$click.Invoke($row.Controls['AliasApplyButton'],@([EventArgs]::Empty))
    Assert-Limit 'valid Apply admits 30 to draft only' ($script:ManageEntryAliases['new'] -ceq ('v'*30) -and -not $script:ManageAliasEditGuid -and -not $script:EntryAliases.ContainsKey('new'))
    $editor=Open-TestEditor 'legacy'
    Assert-Limit 'existing overlength alias opens intact with native limit' ($editor.Text -ceq $legacy -and $editor.MaxLength -eq 30)
    Stop-ManageEntriesMode -Save
    $saved=(Get-AppSettingsLoadResult).Settings.entryAliases
    Assert-Limit 'unrelated Save with unchanged legacy editor preserves both aliases' ($saved['legacy'] -ceq $legacy -and $saved['new'] -ceq ('v'*30) -and -not $script:IsManageEntriesMode)
    Begin-TestManage
    $editor=Open-TestEditor 'legacy'
    $editor.Text='M'*40
    Assert-Limit 'changed legacy overlength rejected without changing prior draft' (-not (Commit-ActiveManageAliasEditor) -and $script:ManageEntryAliases['legacy'] -ceq $legacy)
    $editor.SelectAll(); [Windows.Forms.Clipboard]::SetText('n'*60); $editor.Paste()
    Assert-Limit 'explicit legacy replacement paste respects native limit' ($editor.Text -ceq ('n'*30))
    Stop-ManageEntriesMode
    Assert-Limit 'global Cancel preserves legacy on disk and in memory' ($script:EntryAliases['legacy'] -ceq $legacy -and (Get-AppSettingsLoadResult).Settings.entryAliases['legacy'] -ceq $legacy)
    Begin-TestManage
    $editor=Open-TestEditor 'legacy'
    $script:UiLocale='de-DE'
    $editor.Text='z'*31
    Assert-Limit 'localized rejection feedback' (-not (Commit-ActiveManageAliasEditor) -and $script:TipText -eq 'Anzeigename: maximal 30 Zeichen')
    [void]$click.Invoke($editor.Parent.Controls['AliasClearButton'],@([EventArgs]::Empty))
    Assert-Limit 'clear remains explicit and restores cue' ($editor.Text -eq '' -and $editor.Parent.Controls['AliasCueLabel'].Visible -and $script:ManageEntryAliases['legacy'] -ceq $legacy)
    Stop-ManageEntriesMode -Save
    $saved=(Get-AppSettingsLoadResult).Settings.entryAliases
    Assert-Limit 'explicit clear removes only that alias on Save' (-not $saved.ContainsKey('legacy') -and $saved['new'] -ceq ('v'*30))
    Assert-Limit 'direct draft setter also rejects new overlength' (-not (Set-ManageEntryAliasDraft -Guid 'other' -Alias ('q'*31)) -and -not $script:ManageEntryAliases.ContainsKey('other'))
} finally {
    if ($script:Popup) { $script:Popup.Dispose() }
    Remove-Item -LiteralPath $script:SettingsDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "LBS227 ALIAS LIMIT TOTAL $script:checks/23"
if ($script:checks -ne 23) { throw "Expected 23 alias limit assertions, got $script:checks" }
