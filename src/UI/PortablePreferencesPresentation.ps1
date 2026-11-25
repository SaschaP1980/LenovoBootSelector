# Manual preference workflows. Imported text is data, never an action.
function Update-PortablePreferencesMenuState {
    $available=[bool](Test-PortablePreferencesAvailable -PresentationOnly)
    foreach ($item in @($script:PreferencesExportMenuItem,$script:PreferencesImportMenuItem)) {
        if ($item -and -not $item.IsDisposed) { $item.Enabled=$available }
    }
}

function Format-PreferencesPreviewValue {
    param([AllowEmptyString()][string]$Value)
    if (-not $Value) { return (Get-LocalizedString -Key 'Preferences.NoAlias') }
    # Escape invisible control/format characters so they cannot spoof a row.
    $literal=[regex]::Replace($Value.Replace('\','\\'),'[\p{Cc}\p{Cf}]',[System.Text.RegularExpressions.MatchEvaluator]{
        param($match) return ('\u{0:x4}' -f [int][char]$match.Value[0])
    })
    return ('"'+$literal.Replace('"','\"')+'"')
}

function Get-PreferencesPreviewText {
    param($Plan)
    $lines=[System.Collections.Generic.List[string]]::new()
    $lines.Add((Get-LocalizedString -Key 'Preferences.ReconcileWarning'))
    $lines.Add('')
    $lines.Add((Get-LocalizedString -Key 'Preferences.PreviewLanguage' -Values @{Before=$Plan.OldLocale;After=$Plan.Locale}))
    $lines.Add((Get-LocalizedString -Key 'Preferences.PreviewCounts' -Values @{
        Matched=@($Plan.Rows | Where-Object Status -eq 'Matched').Count
        Unmatched=@($Plan.Rows | Where-Object Status -eq 'Unmatched').Count
        Local=@($Plan.Rows | Where-Object Status -eq 'LocalOnly').Count
    }))
    foreach ($row in @($Plan.Rows)) {
        $lines.Add('')
        $lines.Add((Get-LocalizedString -Key ('Preferences.'+$row.Status)))
        if ($row.Title) { $lines.Add((Format-PreferencesPreviewValue $row.Title)) }
        $lines.Add([string]$row.Guid)
        $newVisibility=Get-LocalizedString -Key $(if ($row.NewHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})
        if ($row.Status -eq 'Unmatched') {
            $lines.Add((Get-LocalizedString -Key 'Preferences.AliasChange' -Values @{Before='—';After=(Format-PreferencesPreviewValue $row.NewAlias)}))
            $lines.Add((Get-LocalizedString -Key 'Preferences.VisibilityChange' -Values @{Before='—';After=$newVisibility}))
            continue
        }
        $oldVisibility=Get-LocalizedString -Key $(if ($row.OldHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})
        $lines.Add((Get-LocalizedString -Key 'Preferences.AliasChange' -Values @{Before=(Format-PreferencesPreviewValue $row.OldAlias);After=(Format-PreferencesPreviewValue $row.NewAlias)}))
        if ($row.AliasSkipped) { $lines.Add((Get-LocalizedString -Key 'Preferences.AliasSkipped')) }
        $lines.Add((Get-LocalizedString -Key 'Preferences.VisibilityChange' -Values @{Before=$oldVisibility;After=$newVisibility}))
        $lines.Add((Get-LocalizedString -Key 'Preferences.OrderChange' -Values @{Before=$row.OldPosition;After=$row.NewPosition}))
    }
    $lines.Add('')
    $lines.Add((Get-LocalizedString -Key 'Preferences.Unavailable'))
    if (@($Plan.UnavailableLocal).Count -eq 0) { $lines.Add((Get-LocalizedString -Key 'Preferences.None')) }
    else { foreach ($guid in @($Plan.UnavailableLocal)) { $lines.Add((Format-PreferencesPreviewValue $guid)) } }
    $lines.Add('')
    $lines.Add((Get-LocalizedString -Key 'Preferences.Scope'))
    return [string]::Join([Environment]::NewLine,$lines.ToArray())
}

function New-PreferencesConfirmationForm {
    param([string]$Title,[string]$Text,[string]$ConfirmText)
    $form=New-Object Windows.Forms.Form
    $form.Name='LenovoPreferencesConfirmation'
    $form.Text=$Title
    $form.AccessibleName=$Title
    $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
    $form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None
    $form.ShowInTaskbar=$false
    $form.TopMost=$true
    $form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
    $form.BackColor=$script:ColorBackground
    $heading=New-Object Windows.Forms.Label
    $heading.Text=$Title
    $heading.UseMnemonic=$false
    $heading.ForeColor=$script:ColorPrimary
    $heading.BackColor=$script:ColorHeader
    $heading.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
    $heading.Font=[Drawing.Font]::new('Segoe UI',11,[Drawing.FontStyle]::Bold)
    $heading.Name='PreferencesTitle'
    $content=New-Object Windows.Forms.TextBox
    $content.Name='PreferencesPreviewText'
    $content.AccessibleName=$Title
    $content.Multiline=$true
    $content.MaxLength=0
    $content.ReadOnly=$true
    $content.WordWrap=$true
    $content.ScrollBars=[Windows.Forms.ScrollBars]::Vertical
    $content.BackColor=$script:ColorSurface
    $content.ForeColor=$script:ColorPrimary
    $content.Font=[Drawing.Font]::new('Segoe UI',9.5)
    $content.BorderStyle=[Windows.Forms.BorderStyle]::FixedSingle
    $content.Text=$Text
    $content.SelectionStart=0
    $content.TabIndex=1
    $cancel=New-Object Windows.Forms.Button
    $cancel.Name='PreferencesCancel'
    $cancel.Text=Get-LocalizedString -Key 'Common.Cancel'
    $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $cancel.TabIndex=0
    $confirm=New-Object Windows.Forms.Button
    $confirm.Name='PreferencesConfirm'
    $confirm.Text=$ConfirmText
    $confirm.DialogResult=[Windows.Forms.DialogResult]::OK
    $confirm.TabIndex=2
    foreach ($button in @($cancel,$confirm)) {
        $button.Font=[Drawing.Font]::new('Segoe UI',9.5)
        $button.FlatStyle=[Windows.Forms.FlatStyle]::Flat
        $button.UseVisualStyleBackColor=$false
        $button.UseMnemonic=$false
        $button.Cursor=[Windows.Forms.Cursors]::Hand
        $button.ForeColor=$script:ColorPrimary
        $button.BackColor=if ($button -eq $confirm) {$script:ColorAccent} else {$script:ColorSurface}
        $button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(70,70,70)
    }
    $form.Controls.Add($heading)
    $form.Controls.Add($content)
    $form.Controls.Add($cancel)
    $form.Controls.Add($confirm)
    # Enter and Escape before a deliberate choice dismiss without writing.
    $form.AcceptButton=$cancel
    $form.CancelButton=$cancel
    $form.Tag=[pscustomobject]@{Heading=$heading;Content=$content;Cancel=$cancel;Confirm=$confirm;Fonts=@($heading.Font,$content.Font,$cancel.Font,$confirm.Font)}
    $form.Add_Shown({ if ($this.Tag.Cancel.CanFocus) { [void]$this.Tag.Cancel.Focus() } })
    $form.Add_Disposed({ foreach ($font in $this.Tag.Fonts) { $font.Dispose() } })
    return $form
}

function Set-PreferencesConfirmationLayout {
    param([Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea)
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) { throw 'InvalidPreviewLayout' }
    function Px([double]$value) { return [Math]::Max(1,[int][Math]::Round($value*$Scale)) }
    $track=[Windows.Forms.SystemInformation]::MaxWindowTrackSize
    $width=[Math]::Min((Px 560),[Math]::Min($WorkingArea.Width,$track.Width))
    $height=[Math]::Min((Px 470),[Math]::Min($WorkingArea.Height,$track.Height))
    $Form.ClientSize=[Drawing.Size]::new($width,$height)
    $width=$Form.ClientSize.Width
    $height=$Form.ClientSize.Height
    $pad=Px 12
    $buttonHeight=Px 36
    $headingHeight=Px 46
    $gap=Px 8
    $bitmap=[Drawing.Bitmap]::new(8,8)
    try {
        $bitmap.SetResolution([single](96*$Scale),[single](96*$Scale))
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $titleHeight=[int][Math]::Ceiling($graphics.MeasureString($Form.Tag.Heading.Text,$Form.Tag.Heading.Font,[Math]::Max(1,$width-2*$pad)).Height)+(Px 10)
            $headingHeight=[Math]::Max($headingHeight,$titleHeight)
            $cancelWidth=[Math]::Max((Px 100),[int][Math]::Ceiling($graphics.MeasureString($Form.Tag.Cancel.Text,$Form.Tag.Cancel.Font).Width)+(Px 20))
            $confirmWidth=[Math]::Max((Px 120),[int][Math]::Ceiling($graphics.MeasureString($Form.Tag.Confirm.Text,$Form.Tag.Confirm.Font).Width)+(Px 20))
        } finally { $graphics.Dispose() }
    } finally { $bitmap.Dispose() }
    $stacked=($cancelWidth+$confirmWidth+$gap -gt $width-2*$pad)
    $footer=if ($stacked) { 2*$buttonHeight+$gap+2*$pad } else { $buttonHeight+2*$pad }
    if ($width-2*$pad -lt [Math]::Max($cancelWidth,$confirmWidth) -or $height-$headingHeight-$footer-2*$pad -lt (Px 50)) { throw 'InvalidPreviewLayout' }
    $Form.Tag.Heading.Bounds=[Drawing.Rectangle]::new($pad,0,($width-2*$pad),$headingHeight)
    $Form.Tag.Content.Bounds=[Drawing.Rectangle]::new($pad,($headingHeight+$pad),($width-2*$pad),($height-$headingHeight-$footer-2*$pad))
    if ($stacked) {
        $Form.Tag.Cancel.Bounds=[Drawing.Rectangle]::new($pad,($height-$footer+$pad),($width-2*$pad),$buttonHeight)
        $Form.Tag.Confirm.Bounds=[Drawing.Rectangle]::new($pad,($height-$pad-$buttonHeight),($width-2*$pad),$buttonHeight)
    } else {
        $Form.Tag.Cancel.Bounds=[Drawing.Rectangle]::new(($width-$pad-$confirmWidth-$gap-$cancelWidth),($height-$pad-$buttonHeight),$cancelWidth,$buttonHeight)
        $Form.Tag.Confirm.Bounds=[Drawing.Rectangle]::new(($width-$pad-$confirmWidth),($height-$pad-$buttonHeight),$confirmWidth,$buttonHeight)
    }
    $Form.Location=Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
}

function Show-PreferencesConfirmation {
    param([string]$Title,[string]$Text,[string]$ConfirmText)
    $form=New-PreferencesConfirmationForm $Title $Text $ConfirmText
    try {
        $owner=Get-LenovoDialogOwner
        $screen=if ($owner) {[Windows.Forms.Screen]::FromControl($owner)} else {[Windows.Forms.Screen]::PrimaryScreen}
        $scale=Get-LenovoUiCoordinateScale -Screen $screen
        Set-PreferencesConfirmationLayout -Form $form -Scale ([double]$scale.Factor) -WorkingArea $screen.WorkingArea
        Register-LenovoDialogVisibilityCorrection -Form $form -Screen $screen
        return ((Show-LenovoOwnedDialog -Form $form -Owner $owner) -eq [Windows.Forms.DialogResult]::OK)
    } finally { $form.Dispose() }
}

function New-PreferencesFileDialog {
    param([ValidateSet('Export','Import')][string]$Mode)
    if ($Mode -eq 'Export') {
        $dialog=New-Object Windows.Forms.SaveFileDialog
        $dialog.Title=Get-LocalizedString -Key 'Preferences.ChooseExport'
        $dialog.FileName='LenovoBootSelector-Preferences.json'
        $dialog.OverwritePrompt=$true
        $dialog.CreatePrompt=$false
    } else {
        $dialog=New-Object Windows.Forms.OpenFileDialog
        $dialog.Title=Get-LocalizedString -Key 'Preferences.ChooseImport'
        $dialog.CheckFileExists=$true
        $dialog.Multiselect=$false
    }
    $dialog.Filter=Get-LocalizedString -Key 'Preferences.FileFilter'
    $dialog.DefaultExt='json'
    $dialog.AddExtension=$true
    $dialog.CheckPathExists=$true
    $dialog.ValidateNames=$true
    $dialog.RestoreDirectory=$true
    return $dialog
}

function Select-PreferencesFile {
    param([ValidateSet('Export','Import')][string]$Mode)
    $dialog=New-PreferencesFileDialog $Mode
    try {
        $owner=Get-LenovoDialogOwner
        $result=if ($owner) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
        return $null
    } finally { $dialog.Dispose() }
}

function Show-PortablePreferencesFromUi {
    param([ValidateSet('Export','Import')][string]$Mode)
    if ($script:PreferencesUiActive) { return }
    $script:PreferencesUiActive=$true
    $stage='read'
    try {
        if ($Mode -eq 'Export') {
            $context=Get-PortablePreferencesContext
            $unavailable=@(@($context.Settings.entryOrder)+@($context.Settings.hiddenEntryGuids)+@($context.Settings.entryAliases.Keys) | Where-Object { $_ -and $_ -notin $context.Entries.Guid } | Sort-Object -Unique)
            $summary=(Get-LocalizedString -Key 'Preferences.Scope')+[Environment]::NewLine+[Environment]::NewLine+(Get-LocalizedString -Key 'Preferences.ExportSummary' -Values @{Count=$context.Entries.Count})
            if ($unavailable.Count -gt 0) {
                $summary += [Environment]::NewLine+[Environment]::NewLine+(Get-LocalizedString -Key 'Preferences.Unavailable')+[Environment]::NewLine+($unavailable -join [Environment]::NewLine)
            }
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.Export') -Text $summary -ConfirmText (Get-LocalizedString -Key 'Preferences.ExportConfirm'))) { return }
            $path=Select-PreferencesFile -Mode Export
            if (-not $path) { return }
            $stage='write'
            Save-PortablePreferencesExport -Path $path -Context $context
            Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Export') -Heading (Get-LocalizedString -Key 'Preferences.Exported') -Message (Get-LocalizedString -Key 'Preferences.ExportSuccess') -Kind Success
        } else {
            if (-not (Test-PortablePreferencesAvailable)) { throw 'PreferencesUnavailable' }
            $path=Select-PreferencesFile -Mode Import
            if (-not $path) { return }
            $import=New-PortablePreferencesImport -Path $path
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.PreviewTitle') -Text (Get-PreferencesPreviewText $import.Plan) -ConfirmText (Get-LocalizedString -Key 'Preferences.Apply'))) { return }
            $stage='write'
            $before=$script:UiLocale
            [void](Complete-PortablePreferencesImport $import)
            $stage='committed'
            try {
                Update-TrayLocalizedText
                if ($before -cne $script:UiLocale) {
                    Update-CachedBootEntryLocalization
                    Update-PopupLocalePresentation
                } elseif ($script:Popup -and -not $script:Popup.IsDisposed) { Update-PopupRows -Reason 'preferences-import' }
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Import') -Heading (Get-LocalizedString -Key 'Preferences.Imported') -Message (Get-LocalizedString -Key 'Preferences.ImportSuccess') -Kind Success
            } catch {
                Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.Import') -Heading (Get-LocalizedString -Key 'Preferences.Imported') -Message (Get-LocalizedString -Key 'Preferences.RefreshWarning') -Kind Warning
            }
        }
    } catch {
        $key=switch -CaseSensitive ($_.Exception.Message) {
            'StalePreview' {'Preferences.ErrorStale'}
            'PreferencesUnavailable' {'Preferences.ErrorBusy'}
            'InvalidLocalSettings' {'Preferences.ErrorLocal'}
            'UnsupportedLocalSettings' {'Preferences.ErrorLocal'}
            'LocalSettingsChanged' {'Preferences.ErrorLocal'}
            'LocaleMigrationPending' {'Preferences.ErrorLocal'}
            'InvalidDestination' {'Preferences.ErrorDestination'}
            'CommitUncertain' { if ($Mode -eq 'Export') {'Preferences.ExportUncertain'} else {'Preferences.ErrorUncertain'} }
            'InvalidPreviewLayout' {'Preferences.ErrorLayout'}
            default { if ($stage -eq 'committed') {'Preferences.RefreshWarning'} elseif ($stage -eq 'write') {'Preferences.ErrorSave'} else {'Preferences.ErrorInvalid'} }
        }
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Preferences.ErrorTitle') -Heading (Get-LocalizedString -Key 'Preferences.ErrorTitle') -Message (Get-LocalizedString -Key $key) -Kind Error
    } finally {
        $script:PreferencesUiActive=$false
        Update-PortablePreferencesMenuState
    }
}
