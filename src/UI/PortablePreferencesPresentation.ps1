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

# Presentation projections never mutate the validated reconciliation plan.
function Get-PreferencesChangedFields {
    param($Row)
    if ($Row.Status -ne 'Matched') { return }
    if ($Row.OldAlias -cne $Row.NewAlias) { 'Alias' }
    if ($Row.OldHidden -ne $Row.NewHidden) { 'Visibility' }
    if ($Row.OldPosition -ne $Row.NewPosition) { 'Order' }
}

function New-PreferencesPreviewView {
    param($Plan)
    $rows=[Collections.Generic.List[object]]::new()
    foreach ($row in @($Plan.Rows)) {
        $fields=@(Get-PreferencesChangedFields $row)
        $rows.Add([pscustomobject]@{
            Id='Entry'+$rows.Count; Row=$row; Status=$row.Status
            Changed=($fields.Count -gt 0); Fields=$fields; AliasSkipped=[bool]$row.AliasSkipped
            Guid=[string]$row.Guid
        })
    }
    foreach ($guid in @($Plan.UnavailableLocal)) {
        $rows.Add([pscustomobject]@{Id='Entry'+$rows.Count;Row=$null;Status='Unavailable';Changed=$false;Fields=@();AliasSkipped=$false;Guid=[string]$guid})
    }
    return [pscustomobject]@{
        Rows=$rows.ToArray(); OldLocale=$Plan.OldLocale; Locale=$Plan.Locale
        Matched=@($rows | Where-Object Status -eq 'Matched').Count
        Changed=@($rows | Where-Object Changed).Count
        Skipped=@($rows | Where-Object Status -eq 'Unmatched').Count
        LocalOnly=@($rows | Where-Object Status -eq 'LocalOnly').Count
        Unavailable=@($rows | Where-Object Status -eq 'Unavailable').Count
        AliasSkipped=@($rows | Where-Object AliasSkipped).Count
    }
}

function Get-PreferencesFilteredRows {
    param($View,[string]$Filter)
    switch ($Filter) {
        'Changed' { $View.Rows | Where-Object Changed }
        'Skipped' { $View.Rows | Where-Object { $_.Status -eq 'Unmatched' -or $_.AliasSkipped } }
        'LocalOnly' { $View.Rows | Where-Object Status -eq 'LocalOnly' }
        'Unavailable' { $View.Rows | Where-Object Status -eq 'Unavailable' }
        default { $View.Rows }
    }
}

function Get-PreferencesFieldText {
    param($Row,[ValidateSet('Alias','Visibility','Order')][string]$Field)
    $unmatched=$Row.Status -eq 'Unmatched'
    switch ($Field) {
        'Alias' {
            $before=if ($unmatched) {'—'} else {Format-PreferencesPreviewValue $Row.OldAlias}
            $after=Format-PreferencesPreviewValue $Row.NewAlias
        }
        'Visibility' {
            $before=if ($unmatched) {'—'} else {Get-LocalizedString -Key $(if ($Row.OldHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})}
            $after=Get-LocalizedString -Key $(if ($Row.NewHidden) {'Preferences.Hidden'} else {'Preferences.Visible'})
        }
        'Order' {
            $before=[string]$Row.OldPosition; $after=[string]$Row.NewPosition
        }
    }
    return (Get-LocalizedString -Key ('Preferences.'+$Field+'Change') -Values @{Before=$before;After=$after})
}

function Limit-PreferencesSummaryText {
    param([string]$Text)
    if ($Text.Length -le 120) {return $Text}
    $end=120
    if ([char]::IsHighSurrogate($Text[$end-1])) {$end--}
    return ($Text.Substring(0,$end)+'…')
}

function Get-PreferencesDetailSegments {
    param($Entry)
    $lines=[Collections.Generic.List[string]]::new()
    if ($Entry.Row -and $Entry.Row.Title) { $lines.Add((Format-PreferencesPreviewValue $Entry.Row.Title)) }
    $lines.Add('GUID: '+$Entry.Guid)
    if ($Entry.Row) {
        $lines.Add((Get-PreferencesFieldText $Entry.Row Alias))
        if ($Entry.AliasSkipped) {$lines.Add((Get-LocalizedString -Key 'Preferences.AliasSkipped'))}
        $lines.Add((Get-PreferencesFieldText $Entry.Row Visibility))
        if ($Entry.Status -ne 'Unmatched') {$lines.Add((Get-PreferencesFieldText $Entry.Row Order))}
    } else {$lines.Add((Get-LocalizedString -Key 'Preferences.Unavailable'))}
    # Bounded detail pages keep the native child geometry safe even with
    # legacy very long aliases. No content is discarded or silently clipped.
    foreach ($line in $lines) {
        for ($offset=0;$offset -lt $line.Length;) {
            $length=[Math]::Min(600,$line.Length-$offset)
            if ($offset+$length -lt $line.Length -and [char]::IsHighSurrogate($line[$offset+$length-1])) {$length--}
            $line.Substring($offset,$length)
            $offset+=$length
        }
    }
}

function New-PreferencesTextControl {
    param($Form,[string]$Name,[string]$Text,[string]$Role='Body')
    $label=[Windows.Forms.Label]::new()
    $label.Name=$Name
    $label.Text=$Text
    $label.AccessibleName=$Text
    $label.UseMnemonic=$false
    $label.UseCompatibleTextRendering=$true
    $label.AutoEllipsis=$false
    $label.AutoSize=$false
    $label.BackColor=[Drawing.Color]::Transparent
    $label.Font=switch ($Role) {
        'Count' {$Form.Tag.Fonts.Metric}
        'Heading' {$Form.Tag.Fonts.Heading}
        'Caption' {$Form.Tag.Fonts.Caption}
        default {$Form.Tag.Fonts.Body}
    }
    $label.ForeColor=switch ($Role) {
        'Caption' {[Drawing.Color]::FromArgb(184,184,184)}
        'Positive' {[Drawing.Color]::FromArgb(104,206,141)}
        'Warning' {[Drawing.Color]::FromArgb(233,182,92)}
        'Changed' {[Drawing.Color]::FromArgb(255,224,222)}
        default {$script:ColorPrimary}
    }
    return $label
}

function New-PreferencesViewButton {
    param($Form,[string]$Name,[string]$Text,[string]$Action,$Value,[switch]$Selected)
    $button=[LenovoActionButton]::new()
    $button.Name=$Name;$button.Text=$Text;$button.AccessibleName=$Text
    $button.UseMnemonic=$false;$button.UseVisualStyleBackColor=$false
    $button.FlatStyle='Flat';$button.Font=$Form.Tag.Fonts.Body
    $button.ForeColor=$script:ColorPrimary
    $button.BackColor=if ($Selected) {[Drawing.Color]::FromArgb(62,32,30)} else {[Drawing.Color]::FromArgb(37,37,37)}
    $button.PreserveSelection=[bool]$Selected
    $button.FlatAppearance.BorderColor=if ($Selected) {$script:ColorAccent} else {[Drawing.Color]::FromArgb(72,72,72)}
    $button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(55,55,55)
    $button.Cursor=[Windows.Forms.Cursors]::Hand
    $button.Tag=[pscustomobject]@{Action=$Action;Value=$Value}
    $button.Add_Click({
        param($sender,$eventArgs)
        $f=$sender.FindForm()
        if (-not $f -or $f.IsDisposed) {return}
        $state=$f.Tag;$name=$sender.Name;$keep=$false
        switch ($sender.Tag.Action) {
            'Filter' {$state.Filter=[string]$sender.Tag.Value;$state.Page=0;$state.Expanded='';$state.DetailPage=0}
            'Page' {$state.Page=[int]$sender.Tag.Value;$state.Expanded='';$state.DetailPage=0}
            'Expand' {
                $state.Expanded=if ($state.Expanded -ceq $sender.Tag.Value) {''} else {[string]$sender.Tag.Value}
                $state.DetailPage=0;$keep=$true
            }
            'Detail' {$state.DetailPage=[int]$sender.Tag.Value;$keep=$true}
        }
        try {Update-PreferencesConfirmationBody -Form $f -FocusName $name -KeepScroll:$keep}
        catch {$state.LayoutFailed=$true;$f.DialogResult=[Windows.Forms.DialogResult]::Cancel}
    })
    $button.Add_Enter({
        param($sender,$eventArgs)
        $f=$sender.FindForm()
        if ($f -and $f.Visible) {Move-PreferencesFocusedControlIntoView -Form $f -Control $sender}
    })
    return $button
}

function New-PreferencesBlock {
    param([Windows.Forms.Control[]]$Controls,[string]$Kind='Stack',[switch]$Card)
    $panel=[Windows.Forms.Panel]::new()
    $panel.TabStop=$false
    $panel.BackColor=if ($Card) {[Drawing.Color]::FromArgb(37,37,37)} else {[Drawing.Color]::Transparent}
    # A card is a filled summary surface, not a framed box.
    $panel.Tag=[pscustomobject]@{Kind=$Kind;Card=[bool]$Card;Items=$Controls}
    for ($i=0;$i -lt $Controls.Count;$i++) {
        $Controls[$i].TabIndex=$i
        $panel.Controls.Add($Controls[$i])
    }
    return $panel
}

function Add-PreferencesBlock {
    param($Form,[Windows.Forms.Control[]]$Controls,[string]$Kind='Stack',[switch]$Card)
    $block=New-PreferencesBlock -Controls $Controls -Kind $Kind -Card:$Card
    $block.TabIndex=$Form.Tag.Blocks.Count
    $Form.Tag.Blocks.Add($block)
    $Form.Tag.Shell.Body.Controls.Add($block)
    # The shared regular dialog already owns viewport/body scrolling.
    # Add its nested labels/buttons to the same single scroll range.
    function AttachWheel($control) {
        $control.Add_MouseWheel({
            param($sender,$eventArgs)
            $f=$sender.FindForm()
            if (-not $f -or -not $f.Tag.Shell.Scroll -or -not $eventArgs.Delta) {return}
            $scroll=$f.Tag.Shell.Scroll
            if ($scroll.Maximum -le 0) {return}
            if ($eventArgs -is [Windows.Forms.HandledMouseEventArgs]) {
                if ($eventArgs.Handled) {return}
                $eventArgs.Handled=$true
            }
            $scroll.Value-=[int]([Math]::Sign($eventArgs.Delta)*$scroll.SmallChange)
        })
        foreach ($child in $control.Controls) {AttachWheel $child}
    }
    AttachWheel $block
}

function Move-PreferencesFocusedControlIntoView {
    param($Form,$Control)
    $shell=$Form.Tag.Shell;$scroll=$shell.Scroll
    if (-not $scroll -or $scroll.Maximum -le 0 -or -not $Control.Visible) {return}
    $top=$shell.Body.PointToClient($Control.PointToScreen([Drawing.Point]::Empty)).Y
    if ($top -lt $scroll.Value) {$scroll.Value=$top}
    elseif ($top+$Control.Height -gt $scroll.Value+$shell.Viewport.Height) {
        $scroll.Value=$top+$Control.Height-$shell.Viewport.Height
    }
}

function New-PreferencesIcon {
    param([string]$Name,[string]$Key)
    $icon=[Windows.Forms.Panel]::new()
    $icon.Name=$Name;$icon.Tag=$Key;$icon.TabStop=$false
    $icon.BackColor=[Drawing.Color]::Transparent
    $icon.Add_Paint({
        param($sender,$eventArgs)
        [LenovoSettingsInk]::DrawIcon($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle,[Drawing.Color]::FromArgb(184,184,184))
    })
    return $icon
}

function New-PreferencesSeparator {
    $line=[Windows.Forms.Panel]::new()
    $line.Name='PreferencesSeparator';$line.TabStop=$false
    $line.BackColor=[Drawing.Color]::FromArgb(63,63,63)
    return $line
}

function New-PreferencesSummaryHead {
    param($Form,[string]$Name,[string]$Count,[string]$Caption)
    return (New-PreferencesBlock -Kind SummaryHead -Controls @(
        (New-PreferencesIcon ($Name+'DriveIcon') 'preferences-drive'),
        (New-PreferencesBlock -Controls @(
            (New-PreferencesTextControl $Form $Name $Count Count),
            (New-PreferencesTextControl $Form ($Name+'Label') $Caption Caption)
        )),
        (New-PreferencesIcon ($Name+'JsonIcon') 'preferences-json')
    ))
}

function New-PreferencesIconText {
    param($Form,[string]$Name,[string]$Key,[Windows.Forms.Control[]]$Controls)
    return (New-PreferencesBlock -Kind IconText -Controls @(
        (New-PreferencesIcon ($Name+'Icon') $Key),
        (New-PreferencesBlock -Controls $Controls)
    ))
}

function Add-PreferencesMetrics {
    param($Form,$View)
    $items=@()
    foreach ($key in @('Changed','Skipped','LocalOnly')) {
        $items+=,(New-PreferencesBlock -Controls @(
            (New-PreferencesTextControl $Form ('Metric'+$key) ([string]$View.$key) Heading),
            (New-PreferencesTextControl $Form ('MetricLabel'+$key) (Get-LocalizedString -Key ('Preferences.Metric'+$key)) Caption)
        ))
    }
    Add-PreferencesBlock $Form @(
        (New-PreferencesSummaryHead $Form 'MetricMatched' (Get-LocalizedString -Key 'Preferences.TargetCount' -Values @{Count=$View.Matched}) (Get-LocalizedString -Key 'Preferences.MetricMatched')),
        (New-PreferencesSeparator),
        (New-PreferencesBlock -Controls $items -Kind CompactMetrics)
    ) -Card
}

function New-PreferencesLanguageTile {
    param($Form,[string]$Name,[string]$Locale,[string]$CaptionKey)
    $flag=[Windows.Forms.Panel]::new()
    $flag.Name=$Name+'Flag';$flag.Tag=$Locale;$flag.TabStop=$false
    $flag.BackColor=[Drawing.Color]::Transparent
    $flag.Add_Paint({
        param($sender,$eventArgs)
        [LenovoLocaleFlags]::DrawFlag($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle)
    })
    $nameText=Get-LocalizedString -Key $(if ($Locale -ceq 'de-DE') {'Language.German'} else {'Language.English'})
    return (New-PreferencesBlock -Kind Language -Controls @(
        (New-PreferencesTextControl $Form ($Name+'Caption') (Get-LocalizedString -Key $CaptionKey) Caption),
        $flag,
        (New-PreferencesTextControl $Form ($Name+'Name') $nameText Heading)
    ))
}

function Add-PreferencesEntryCard {
    param($Form,$Entry)
    $s=$Form.Tag
    $title=if ($Entry.Row -and $Entry.Row.Title) {Format-PreferencesPreviewValue $Entry.Row.Title} elseif ($Entry.Status -eq 'Unavailable') {Get-LocalizedString -Key 'Preferences.UnavailableTitle'} else {Get-LocalizedString -Key 'Preferences.UnmatchedTitle'}
    $statusKey=switch ($Entry.Status) {
        'Matched' {if ($Entry.Changed) {'Preferences.RowChanged'} else {'Preferences.RowUnchanged'}}
        'LocalOnly' {'Preferences.LocalOnly'}
        'Unmatched' {'Preferences.Unmatched'}
        default {'Preferences.UnavailableTitle'}
    }
    $role=if ($Entry.Status -in @('Unmatched','Unavailable') -or $Entry.AliasSkipped) {'Warning'} elseif ($Entry.Changed) {'Changed'} elseif ($Entry.Status -eq 'Matched') {'Positive'} else {'Caption'}
    $items=@(
        (New-PreferencesTextControl $Form ($Entry.Id+'Title') (Limit-PreferencesSummaryText $title) Heading),
        (New-PreferencesTextControl $Form ($Entry.Id+'Status') (Get-LocalizedString -Key $statusKey) $role)
    )
    foreach ($field in @($Entry.Fields)) {
        $items+=,(New-PreferencesTextControl $Form ($Entry.Id+$field) (Limit-PreferencesSummaryText (Get-PreferencesFieldText $Entry.Row $field)) Changed)
    }
    if ($Entry.AliasSkipped) {$items+=,(New-PreferencesTextControl $Form ($Entry.Id+'AliasSkipped') (Get-LocalizedString -Key 'Preferences.AliasSkipped') Warning)}
    $expanded=$s.Expanded -ceq $Entry.Id
    $items+=,(New-PreferencesViewButton $Form ($Entry.Id+'Details') (Get-LocalizedString -Key $(if ($expanded) {'Preferences.HideDetails'} else {'Preferences.ShowDetails'})) Expand $Entry.Id -Selected:$expanded)
    if ($expanded) {
        $segments=@(Get-PreferencesDetailSegments $Entry)
        $pages=[Math]::Max(1,[int][Math]::Ceiling($segments.Count/6.0))
        $s.DetailPage=[Math]::Max(0,[Math]::Min($pages-1,$s.DetailPage))
        $items+=,(New-PreferencesTextControl $Form ($Entry.Id+'DetailHeader') (Get-LocalizedString -Key 'Preferences.DetailPage' -Values @{Page=($s.DetailPage+1);Total=$pages}) Caption)
        $i=0
        foreach ($segment in @($segments | Select-Object -Skip ($s.DetailPage*6) -First 6)) {
            $items+=,(New-PreferencesTextControl $Form ($Entry.Id+'Detail'+$i) $segment Body)
            $i++
        }
        if ($pages -gt 1) {
            $previous=New-PreferencesViewButton $Form ($Entry.Id+'DetailPrevious') (Get-LocalizedString -Key 'Preferences.Previous') Detail ($s.DetailPage-1)
            $previous.Enabled=$s.DetailPage -gt 0
            $next=New-PreferencesViewButton $Form ($Entry.Id+'DetailNext') (Get-LocalizedString -Key 'Preferences.Next') Detail ($s.DetailPage+1)
            $next.Enabled=$s.DetailPage -lt $pages-1
            $items+=,(New-PreferencesBlock -Controls @($previous,$next) -Kind Buttons)
        }
    }
    $items+=,(New-PreferencesSeparator)
    Add-PreferencesBlock $Form $items
}

function Update-PreferencesConfirmationBody {
    param($Form,[string]$FocusName,[switch]$KeepScroll)
    $s=$Form.Tag;$body=$s.Shell.Body
    $oldValue=if ($KeepScroll) {$s.Shell.Scroll.Value} else {0}
    $body.SuspendLayout()
    try {
        foreach ($control in @($body.Controls)) {$body.Controls.Remove($control);$control.Dispose()}
        $s.Blocks.Clear()
        if ($s.Mode -eq 'Export') {
            $included=@()
            $icons=@{Language='preferences-language';Aliases='preferences-alias';Visibility='preferences-visible';Order='preferences-order'}
            foreach ($key in @('Language','Aliases','Visibility','Order')) {
                $included+=,(New-PreferencesIconText $Form ('Included'+$key) $icons[$key] @(
                    (New-PreferencesTextControl $Form ('Included'+$key) (Get-LocalizedString -Key ('Preferences.Included'+$key)) Body)
                ))
            }
            Add-PreferencesBlock $Form @(
                (New-PreferencesSummaryHead $Form 'ExportCount' (Get-LocalizedString -Key 'Preferences.TargetCount' -Values @{Count=$s.ExportCount}) (Get-LocalizedString -Key 'Preferences.ExportIntro')),
                (New-PreferencesSeparator),
                (New-PreferencesBlock -Controls $included -Kind TwoColumns)
            ) -Card
        } else {
            Add-PreferencesMetrics $Form $s.View
            $languageTiles=New-PreferencesBlock -Kind TwoColumns -Controls @(
                (New-PreferencesLanguageTile $Form 'LanguageBefore' $s.View.OldLocale 'Preferences.LanguageBefore'),
                (New-PreferencesLanguageTile $Form 'LanguageAfter' $s.View.Locale 'Preferences.LanguageAfter')
            )
            Add-PreferencesBlock $Form @(
                (New-PreferencesTextControl $Form 'LanguageHeading' (Get-LocalizedString -Key 'Preferences.IncludedLanguage') Heading),
                $languageTiles,
                (New-PreferencesTextControl $Form 'LanguageStatus' (Get-LocalizedString -Key $(if ($s.View.OldLocale -ceq $s.View.Locale) {'Preferences.NoChange'} else {'Preferences.LanguageChanged'})) $(if ($s.View.OldLocale -cne $s.View.Locale) {'Changed'} else {'Caption'})),
                (New-PreferencesSeparator)
            )
            $entryIntro=@((New-PreferencesTextControl $Form 'EntryHeading' (Get-LocalizedString -Key 'Preferences.EntriesHeading') Heading))
            if ($s.View.Unavailable -gt 0) {
                $entryIntro+=,(New-PreferencesTextControl $Form 'UnavailableCount' (Get-LocalizedString -Key 'Preferences.UnavailableCount' -Values @{Count=$s.View.Unavailable}) Caption)
            }
            if ($s.View.AliasSkipped -gt 0) {
                $entryIntro+=,(New-PreferencesTextControl $Form 'AliasSkippedCount' (Get-LocalizedString -Key 'Preferences.AliasSkippedCount' -Values @{Count=$s.View.AliasSkipped}) Warning)
            }
            Add-PreferencesBlock $Form $entryIntro
            $filters=@()
            foreach ($key in @('All','Changed','Skipped','LocalOnly','Unavailable')) {
                $filters+=,(New-PreferencesViewButton $Form ('Filter'+$key) (Get-LocalizedString -Key ('Preferences.Filter'+$key)) Filter $key -Selected:($s.Filter -ceq $key))
            }
            Add-PreferencesBlock $Form $filters Buttons
        }
        if ($s.Mode -eq 'Import' -or $s.View.Unavailable -gt 0) {
            $rows=@(Get-PreferencesFilteredRows $s.View $s.Filter)
            $s.PageCount=[Math]::Max(1,[int][Math]::Ceiling($rows.Count/8.0))
            $s.Page=[Math]::Max(0,[Math]::Min($s.PageCount-1,$s.Page))
            $s.VisibleRows=@($rows | Select-Object -Skip ($s.Page*8) -First 8)
            if ($s.Mode -eq 'Export') {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'ExportUnavailable' (Get-LocalizedString -Key 'Preferences.Unavailable') Caption))
            }
            if ($rows.Count -gt 0) {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'PageInfo' (Get-LocalizedString -Key 'Preferences.PageInfo' -Values @{Page=($s.Page+1);Total=$s.PageCount;Count=$rows.Count}) Caption))
                if ($s.PageCount -gt 1) {
                    $previous=New-PreferencesViewButton $Form 'PagePrevious' (Get-LocalizedString -Key 'Preferences.Previous') Page ($s.Page-1)
                    $previous.Enabled=$s.Page -gt 0
                    $next=New-PreferencesViewButton $Form 'PageNext' (Get-LocalizedString -Key 'Preferences.Next') Page ($s.Page+1)
                    $next.Enabled=$s.Page -lt $s.PageCount-1
                    Add-PreferencesBlock $Form @($previous,$next) Buttons
                }
                foreach ($entry in $s.VisibleRows) {Add-PreferencesEntryCard $Form $entry}
            } else {
                Add-PreferencesBlock $Form @((New-PreferencesTextControl $Form 'NoRows' (Get-LocalizedString -Key 'Preferences.NoRows') Caption))
            }
        }
        if ($s.Mode -eq 'Import') {
            Add-PreferencesBlock $Form @(
                (New-PreferencesIconText $Form 'Reconcile' 'preferences-shield' @(
                    (New-PreferencesTextControl $Form 'ReconcileHeading' (Get-LocalizedString -Key 'Preferences.ReconcileHeading') Heading),
                    (New-PreferencesTextControl $Form 'ReconcileWarning' (Get-LocalizedString -Key 'Preferences.ReconcileWarning') Body),
                    (New-PreferencesTextControl $Form 'IncludedScope' (Get-LocalizedString -Key 'Preferences.IncludedScope') Caption)
                )),
                (New-PreferencesSeparator)
            )
        }
        $excludedHeading=if ($s.Mode -eq 'Import') {'Preferences.UnchangedHeading'} else {'Preferences.ExcludedHeading'}
        $excluded=@(
            (New-PreferencesTextControl $Form 'ExcludedHeading' (Get-LocalizedString -Key $excludedHeading) Heading),
            (New-PreferencesTextControl $Form 'ExcludedScope' (Get-LocalizedString -Key 'Preferences.ExcludedScope') Body)
        )
        if ($s.Mode -eq 'Import') {
            $excluded+=,(New-PreferencesTextControl $Form 'SystemUnchanged' (Get-LocalizedString -Key 'Preferences.SystemUnchanged') Caption)
        }
        Add-PreferencesBlock $Form @(
            (New-PreferencesIconText $Form 'Excluded' 'preferences-shield' $excluded),
            (New-PreferencesSeparator)
        )
        Add-PreferencesBlock $Form @(
            (New-PreferencesIconText $Form 'Privacy' 'preferences-lock' @(
                (New-PreferencesTextControl $Form 'PrivacyHeading' (Get-LocalizedString -Key 'Preferences.PrivacyHeading') Heading),
                (New-PreferencesTextControl $Form 'PrivacyBody' (Get-LocalizedString -Key 'Preferences.PrivacyBody') Caption),
                (New-PreferencesTextControl $Form 'UnavailableNote' (Get-LocalizedString -Key 'Preferences.UnavailableNote') Caption)
            ))
        )
    } finally {$body.ResumeLayout($false)}
    if ($s.Scale -gt 0) {
        Set-PreferencesConfirmationLayout -Form $Form -Scale $s.Scale -WorkingArea $s.WorkingArea
        $s.Shell.Scroll.Value=$oldValue
        if ($FocusName) {
            $target=$Form.Controls.Find($FocusName,$true) | Select-Object -First 1
            if ($target -and $target.CanFocus -and $target.Enabled) {[void]$target.Focus()}
            elseif ($s.Cancel.CanFocus) {[void]$s.Cancel.Focus()}
        }
    }
}

function New-PreferencesConfirmationForm {
    param([string]$Title,[string]$ConfirmText,$Plan,$ExportContext)
    if (($null -ne $Plan) -eq ($null -ne $ExportContext)) {throw 'InvalidPreviewLayout'}
    $form=[Windows.Forms.Form]::new()
    $form.Name='LenovoPreferencesConfirmation';$form.Text=$Title;$form.AccessibleName=$Title
    $form.FormBorderStyle='None';$form.AutoScaleMode='None';$form.ShowInTaskbar=$false;$form.TopMost=$true
    $form.StartPosition='Manual';$form.KeyPreview=$true;$form.BackColor=$script:ColorBackground
    $root=[Windows.Forms.Panel]::new();$root.Name='PreferencesRoot';$form.Controls.Add($root)
    $fonts=@{Title=[Drawing.Font]::new('Segoe UI',11,[Drawing.FontStyle]::Bold);Heading=[Drawing.Font]::new('Segoe UI',10,[Drawing.FontStyle]::Bold);Body=[Drawing.Font]::new('Segoe UI',9.5);Caption=[Drawing.Font]::new('Segoe UI',9);Metric=[Drawing.Font]::new('Segoe UI',19,[Drawing.FontStyle]::Bold)}
    $heading=[Windows.Forms.Label]::new();$heading.Text=$Title;$heading.Font=$fonts.Title;$heading.ForeColor=$script:ColorPrimary
    $divider=[Windows.Forms.Panel]::new();$divider.BackColor=$script:ColorAccent
    $cancel=[LenovoActionButton]::new();$cancel.Name='PreferencesCancel';$cancel.Text=Get-LocalizedString -Key 'Common.Cancel';$cancel.DialogResult='Cancel'
    $confirm=[LenovoActionButton]::new();$confirm.Name='PreferencesConfirm';$confirm.Text=$ConfirmText;$confirm.DialogResult='OK'
    foreach ($button in @($cancel,$confirm)) {
        $button.AccessibleName=$button.Text;$button.Font=$fonts.Body;$button.FlatStyle='Flat'
        $button.UseVisualStyleBackColor=$false;$button.UseMnemonic=$false;$button.Cursor=[Windows.Forms.Cursors]::Hand
        $button.ForeColor=$script:ColorPrimary
        $button.BackColor=if ($button -eq $confirm) {$script:ColorAccent} else {$script:ColorSurface}
        $button.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(72,72,72)
        $button.FlatAppearance.MouseOverBackColor=if ($button -eq $confirm) {$script:ColorAccent} else {[Drawing.Color]::FromArgb(45,45,45)}
    }
    $cancel.TabIndex=0;$confirm.TabIndex=1
    $form.AcceptButton=$cancel;$form.CancelButton=$cancel
    Initialize-LenovoRegularDialog -Form $form -Root $root -Title $heading -Divider $divider -Content @() -Buttons @($cancel,$confirm)
    $icon=[Windows.Forms.Panel]::new();$icon.Name='PreferencesHeaderIcon';$icon.TabStop=$false
    $icon.Tag=if ($Plan) {'preferences-import'} else {'preferences-export'}
    $icon.BackColor=$root.Tag.Header.BackColor
    $icon.Add_Paint({
        param($sender,$eventArgs)
        [LenovoSettingsInk]::DrawIcon($eventArgs.Graphics,[string]$sender.Tag,$sender.ClientRectangle,[Drawing.Color]::FromArgb(225,37,27))
    })
    $root.Tag.Header.Controls.Add($icon)
    $root.Tag.Footer.TabIndex=0;$root.Tag.Viewport.TabIndex=1;$root.Tag.Header.TabStop=$false
    $root.Tag.Body.TabIndex=0
    $mode=if ($Plan) {'Import'} else {'Export'}
    $view=if ($Plan) {New-PreferencesPreviewView $Plan} else {
        $unavailable=@(@($ExportContext.Settings.entryOrder)+@($ExportContext.Settings.hiddenEntryGuids)+@($ExportContext.Settings.entryAliases.Keys) | Where-Object { $_ -and $_ -notin $ExportContext.Entries.Guid } | Sort-Object -Unique)
        New-PreferencesPreviewView ([pscustomobject]@{Rows=@();UnavailableLocal=$unavailable})
    }
    $form.Tag=[pscustomobject]@{
        Mode=$mode;View=$view;ExportCount=@($ExportContext.Entries).Count
        Shell=$root.Tag;Root=$root;Cancel=$cancel;Confirm=$confirm;Fonts=$fonts;HeaderIcon=$icon;LayoutFailed=$false
        Blocks=[Collections.Generic.List[object]]::new();Filter='All';Page=0;PageCount=1;Expanded='';DetailPage=0;VisibleRows=@()
        Scale=0.0;WorkingArea=[Drawing.Rectangle]::Empty
    }
    $form.Add_Shown({if ($this.Tag.Cancel.CanFocus) {[void]$this.Tag.Cancel.Focus()}})
    $form.Add_Disposed({foreach ($font in $this.Tag.Fonts.Values) {$font.Dispose()}})
    if (-not $root.Tag.Scroll) {$form.Dispose();throw 'InvalidPreviewLayout'}
    try {Update-PreferencesConfirmationBody $form;return $form}
    catch {$form.Dispose();throw}
}

function Set-PreferencesBlockLayout {
    param($Block,[int]$Width,$Graphics,[double]$Scale)
    function Px([double]$n) {return [Math]::Max(1,[int][Math]::Round($n*$Scale))}
    $pad=if ($Block.Tag.Card) {Px 10} else {0}
    $gap=Px 5
    $available=[Math]::Max(1,$Width-2*$pad)
    $y=$pad;$x=$pad;$lineHeight=0
    if ($Block.Tag.Kind -in @('Metrics','TwoColumns','CompactMetrics')) {
        $columns=switch ($Block.Tag.Kind) {
            'TwoColumns' {if ($available -ge (Px 250)) {2} else {1}}
            'CompactMetrics' {if ($available -ge (Px 300)) {3} elseif ($available -ge (Px 200)) {2} else {1}}
            default {if ($available -ge (Px 620)) {4} elseif ($available -ge (Px 250)) {2} else {1}}
        }
        $columns=[Math]::Max(1,[Math]::Min($columns,$Block.Tag.Items.Count))
        $cell=[int][Math]::Floor(($available-($columns-1)*$gap)/$columns)
        $index=0
        foreach ($item in $Block.Tag.Items) {
            $col=$index%$columns
            if ($col -eq 0 -and $index -gt 0) {$y+=$lineHeight+$gap;$lineHeight=0}
            $h=Set-PreferencesBlockLayout $item $cell $Graphics $Scale
            $item.Bounds=[Drawing.Rectangle]::new(($pad+$col*($cell+$gap)),$y,$cell,$h)
            $lineHeight=[Math]::Max($lineHeight,$h);$index++
        }
        $y+=$lineHeight
    } elseif ($Block.Tag.Kind -in @('SummaryHead','IconText')) {
        $icon=$Block.Tag.Items[0];$content=$Block.Tag.Items[1]
        $summary=$Block.Tag.Kind -eq 'SummaryHead'
        $side=[Math]::Min((Px $(if ($summary) {38} else {20})),[Math]::Max(1,[int]($available/5)))
        $right=if ($summary) {$side+$gap} else {0}
        $cw=[Math]::Max(1,$available-$side-$gap-$right)
        $ch=Set-PreferencesBlockLayout $content $cw $Graphics $Scale
        $h=[Math]::Max($side,$ch)
        $icon.Bounds=[Drawing.Rectangle]::new($pad,($y+[int](($h-$side)/2)),$side,$side)
        $content.Bounds=[Drawing.Rectangle]::new(($pad+$side+$gap),$y,$cw,$ch)
        if ($summary) {
            $Block.Tag.Items[2].Bounds=[Drawing.Rectangle]::new(($pad+$available-$side),($y+[int](($h-$side)/2)),$side,$side)
        }
        $y+=$h
    } elseif ($Block.Tag.Kind -eq 'Language') {
        $caption=$Block.Tag.Items[0];$flag=$Block.Tag.Items[1];$name=$Block.Tag.Items[2]
        $h=[Math]::Max((Px 16),[int][Math]::Ceiling($Graphics.MeasureString($caption.Text,$caption.Font,$available).Height)+(Px 4))
        $caption.Bounds=[Drawing.Rectangle]::new($pad,$y,$available,$h)
        $y+=$h+$gap
        $fw=[Math]::Min((Px 28),[Math]::Max(1,$available-(Px 30)))
        $fh=[Math]::Max(1,[int][Math]::Round($fw*0.75))
        $nw=[Math]::Max(1,$available-$fw-$gap)
        $nh=[Math]::Max($fh,[int][Math]::Ceiling($Graphics.MeasureString($name.Text,$name.Font,$nw).Height)+(Px 4))
        $flag.Bounds=[Drawing.Rectangle]::new($pad,($y+[int](($nh-$fh)/2)),$fw,$fh)
        $name.Bounds=[Drawing.Rectangle]::new(($pad+$fw+$gap),$y,$nw,$nh)
        $y+=$nh
    } elseif ($Block.Tag.Kind -eq 'Buttons') {
        foreach ($item in $Block.Tag.Items) {
            $desired=[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font).Width)+(Px 22)
            $w=[Math]::Min($available,[Math]::Max((Px 70),$desired))
            $h=[Math]::Max((Px 30),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w-(Px 10))).Height)+(Px 8))
            if ($x -gt $pad -and $x+$w -gt $pad+$available) {$y+=$lineHeight+$gap;$x=$pad;$lineHeight=0}
            $item.Bounds=[Drawing.Rectangle]::new($x,$y,$w,$h)
            $x+=$w+$gap;$lineHeight=[Math]::Max($lineHeight,$h)
        }
        $y+=$lineHeight
    } else {
        foreach ($item in $Block.Tag.Items) {
            $w=$available
            if ($item.Name -ceq 'PreferencesSeparator') {
                $h=Px 1
            } elseif ($item -is [Windows.Forms.Panel]) {
                $h=Set-PreferencesBlockLayout $item $w $Graphics $Scale
            } elseif ($item -is [Windows.Forms.Button]) {
                $w=[Math]::Min($available,[Math]::Max((Px 100),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font).Width)+(Px 22)))
                $h=[Math]::Max((Px 30),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w-(Px 10))).Height)+(Px 8))
            } else {
                $h=[Math]::Max((Px 16),[int][Math]::Ceiling($Graphics.MeasureString($item.Text,$item.Font,[Math]::Max(1,$w)).Height)+(Px 4))
            }
            $item.Bounds=[Drawing.Rectangle]::new($pad,$y,$w,$h)
            $y+=$h+$gap
        }
        $y-=$gap
    }
    return [int][Math]::Max(1,$y+$pad)
}

function Set-PreferencesConfirmationLayout {
    param([Windows.Forms.Form]$Form,[double]$Scale,[Drawing.Rectangle]$WorkingArea)
    if ($Scale -lt 1.0 -or $Scale -gt 5.0) {throw 'InvalidPreviewLayout'}
    function Px([double]$n) {return [Math]::Max(1,[int][Math]::Round($n*$Scale))}
    $s=$Form.Tag;$shell=$s.Shell
    $s.Scale=$Scale;$s.WorkingArea=$WorkingArea
    $track=[Windows.Forms.SystemInformation]::MaxWindowTrackSize
    $width=[Math]::Min((Px $(if ($s.Mode -eq 'Export') {500} else {780})),[Math]::Min($WorkingArea.Width,$track.Width))
    $maxHeight=[Math]::Min($WorkingArea.Height,$track.Height)
    if ($s.Mode -eq 'Import') {$maxHeight=[Math]::Min($maxHeight,(Px 650))}
    $pad=Px 18;$gap=Px 10
    $bitmap=[Drawing.Bitmap]::new(8,8)
    try {
        $bitmap.SetResolution([single](96*$Scale),[single](96*$Scale))
        $g=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $titleWidth=$width-2*$pad
            if ($titleWidth -lt (Px 80)) {throw 'InvalidPreviewLayout'}
            $shell.Title.UseCompatibleTextRendering=$true;$shell.Title.AutoSize=$false;$shell.Title.AutoEllipsis=$false
            $iconSize=Px 23
            $headingWidth=$titleWidth-$iconSize-$gap
            if ($headingWidth -lt (Px 40)) {throw 'InvalidPreviewLayout'}
            $headerHeight=[Math]::Max((Px 49),[int][Math]::Ceiling($g.MeasureString($shell.Title.Text,$shell.Title.Font,$headingWidth).Height)+(Px 20))
            $buttonWidths=@();$buttonHeight=Px 36
            foreach ($button in @($s.Cancel,$s.Confirm)) {
                $bw=[Math]::Min($titleWidth,[Math]::Max((Px 108),[int][Math]::Ceiling($g.MeasureString($button.Text,$button.Font).Width)+(Px 24)))
                $buttonWidths+=$bw
                $buttonHeight=[Math]::Max($buttonHeight,[int][Math]::Ceiling($g.MeasureString($button.Text,$button.Font,[Math]::Max(1,$bw-(Px 12))).Height)+(Px 10))
            }
            $total=$buttonWidths[0]+$buttonWidths[1]+$gap
            $stacked=$total -gt $titleWidth
            $footerHeight=if ($stacked) {2*$buttonHeight+3*$gap} else {$buttonHeight+2*$gap}
            $available=$maxHeight-$headerHeight-$footerHeight
            if ($available -lt (Px 50)) {throw 'InvalidPreviewLayout'}
            $gutter=0;$height=0
            for ($pass=0;$pass -lt 2;$pass++) {
                $bodyWidth=$width-$gutter
                $blockWidth=$bodyWidth-2*$pad
                if ($blockWidth -lt (Px 70)) {throw 'InvalidPreviewLayout'}
                $y=$pad
                foreach ($block in $s.Blocks) {
                    $h=Set-PreferencesBlockLayout $block $blockWidth $g $Scale
                    $block.Bounds=[Drawing.Rectangle]::new($pad,$y,$blockWidth,$h)
                    $y+=$h+$gap
                }
                $height=$y-$gap+$pad
                if ($height -le $available -or $pass -eq 1) {break}
                $gutter=Px 12
            }
            $viewportHeight=if ($s.Mode -eq 'Import') {$available} else {[Math]::Min($available,$height)}
            $Form.ClientSize=[Drawing.Size]::new($width,($headerHeight+$viewportHeight+$footerHeight))
            $shell.Header.Bounds=[Drawing.Rectangle]::new(0,0,$width,$headerHeight)
            $s.HeaderIcon.Bounds=[Drawing.Rectangle]::new($pad,[int](($headerHeight-$iconSize)/2),$iconSize,$iconSize)
            $shell.Title.Bounds=[Drawing.Rectangle]::new(($pad+$iconSize+$gap),(Px 8),$headingWidth,($headerHeight-(Px 18)))
            $shell.Divider.Bounds=[Drawing.Rectangle]::new(0,($headerHeight-(Px 2)),$width,(Px 2))
            $shell.Viewport.Bounds=[Drawing.Rectangle]::new(0,$headerHeight,$width,$viewportHeight)
            $shell.Body.Bounds=[Drawing.Rectangle]::new(0,0,$bodyWidth,$height)
            $shell.Footer.Bounds=[Drawing.Rectangle]::new(0,($headerHeight+$viewportHeight),$width,$footerHeight)
            $scroll=$shell.Scroll
            $scroll.Bounds=[Drawing.Rectangle]::new(($width-(Px 10)),0,(Px 10),$viewportHeight)
            $scroll.Value=0;$scroll.Maximum=[Math]::Max(0,$height-$viewportHeight)
            $scroll.LargeChange=$viewportHeight;$scroll.SmallChange=Px 60
            $scroll.Visible=$scroll.Maximum -gt 0;$scroll.BringToFront()
            $x=if ($stacked) {$pad} else {$width-$pad-$total}
            $y=$gap
            for ($i=0;$i -lt 2;$i++) {
                $button=@($s.Cancel,$s.Confirm)[$i]
                $bw=if ($stacked) {$titleWidth} else {$buttonWidths[$i]}
                $button.Bounds=[Drawing.Rectangle]::new($x,$y,$bw,$buttonHeight)
                if ($stacked) {$y+=$buttonHeight+$gap} else {$x+=$bw+$gap}
            }
        } finally {$g.Dispose()}
    } finally {$bitmap.Dispose()}
    $Form.Location=Get-LenovoVisibleDialogLocation -WorkingArea $WorkingArea -WindowSize $Form.Size
}

function Show-PreferencesConfirmation {
    param([string]$Title,[string]$ConfirmText,$Plan,$ExportContext)
    $form=New-PreferencesConfirmationForm -Title $Title -ConfirmText $ConfirmText -Plan $Plan -ExportContext $ExportContext
    try {
        $owner=Get-LenovoDialogOwner
        $screen=if ($owner) {[Windows.Forms.Screen]::FromControl($owner)} else {[Windows.Forms.Screen]::PrimaryScreen}
        $scale=Get-LenovoUiCoordinateScale -Screen $screen
        Set-PreferencesConfirmationLayout -Form $form -Scale ([double]$scale.Factor) -WorkingArea $screen.WorkingArea
        Register-LenovoDialogVisibilityCorrection -Form $form -Screen $screen
        $result=Show-LenovoOwnedDialog -Form $form -Owner $owner
        if ($form.Tag.LayoutFailed) {throw 'InvalidPreviewLayout'}
        return ($result -eq [Windows.Forms.DialogResult]::OK)
    } finally {$form.Dispose()}
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
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.Export') -ExportContext $context -ConfirmText (Get-LocalizedString -Key 'Preferences.ExportConfirm'))) { return }
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
            if (-not (Show-PreferencesConfirmation -Title (Get-LocalizedString -Key 'Preferences.PreviewTitle') -Plan $import.Plan -ConfirmText (Get-LocalizedString -Key 'Preferences.Apply'))) { return }
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
