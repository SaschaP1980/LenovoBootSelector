# LBS-182: project only existing in-memory observations; no broker/firmware calls.
function ConvertTo-SystemStatusObservedTime {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    try {
        $utc = ([datetime]$Value).ToUniversalTime()
        if ($utc.Year -lt 2000 -or $utc -gt [datetime]::UtcNow) { return $null }
        return $utc
    } catch { return $null }
}

function Format-SystemStatusObservationAge {
    param([datetime]$Utc,[datetime]$Now = [datetime]::UtcNow)
    $minutes = [int][Math]::Max(0,[Math]::Floor(($Now-$Utc).TotalMinutes))
    if ($minutes -eq 0) { return (Get-LocalizedString -Key 'SystemStatus.JustNow') }
    return (Get-LocalizedString -Key 'SystemStatus.MinutesAgo' -Values @{Minutes=$minutes})
}

function Get-SystemStatusObservationPresentation {
    param($Next,$Entries,$Readiness,[datetime]$Now = [datetime]::UtcNow)
    $times = @((ConvertTo-SystemStatusObservedTime $Next),(ConvertTo-SystemStatusObservedTime $Entries),(ConvertTo-SystemStatusObservedTime $Readiness))
    # Only share a date and age when all three independent observations agree
    # at the displayed second. Never imply a shared time for missing evidence.
    $shared = ($null -ne $times[0] -and $null -ne $times[1] -and $null -ne $times[2] -and
        $times[0].ToString('yyyyMMddHHmmss') -eq $times[1].ToString('yyyyMMddHHmmss') -and
        $times[0].ToString('yyyyMMddHHmmss') -eq $times[2].ToString('yyyyMMddHHmmss') -and
        (Format-SystemStatusObservationAge $times[0] $Now) -eq (Format-SystemStatusObservationAge $times[1] $Now) -and
        (Format-SystemStatusObservationAge $times[0] $Now) -eq (Format-SystemStatusObservationAge $times[2] $Now))
    $values = @(
        foreach ($utc in $times) {
            if ($null -eq $utc) { Get-LocalizedString -Key 'SystemStatus.TimeUnknown' }
            elseif ($shared) { $utc.ToLocalTime().ToString('HH:mm:ss') }
            else { $utc.ToLocalTime().ToString('dd.MM.yyyy HH:mm:ss') + ' · ' + (Format-SystemStatusObservationAge $utc $Now) }
        }
    )
    [pscustomobject]@{Values=$values;Shared=if ($shared) { $times[0].ToLocalTime().ToString('dd.MM.yyyy') + ' · ' + (Format-SystemStatusObservationAge $times[0] $Now) } else { '' }}
}

function Get-SystemStatusPresentation {
    $defaultEntry = if ($script:DefaultGuid) { Get-EntryByGuid $script:DefaultGuid }
    $nextEntry = if ($script:SelectedGuid) { Get-EntryByGuid $script:SelectedGuid }
    $defaultName = if ($defaultEntry) { Get-EntryDisplayTitle -Entry $defaultEntry } else { '' }
    $nextName = if ($nextEntry) { Get-EntryDisplayTitle -Entry $nextEntry } else { '' }
    $nextTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusNextObservedUtc
    $readinessTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusReadinessObservedUtc
    $entriesTime = ConvertTo-SystemStatusObservedTime $script:SystemStatusEntriesObservedUtc
    $refreshing = [bool](Test-BackgroundRefreshActive -State $script:BackgroundRefreshState)
    $pending = [bool]($script:BootNextPendingGuid -or $script:DefaultTargetChangePending)
    $model = Resolve-SystemStatusCore -Capabilities $script:SystemStatusCapabilities -DefaultEvidence $script:SystemStatusDefaultEvidence -DefaultName $defaultName -DefaultGuid $script:DefaultGuid -DefaultUncertain ([bool]($script:DefaultTargetReadUncertain -or $script:DefaultTargetChangePending)) -NextVerified ([bool]$script:NextBootFirmwareReadVerified) -NextName $nextName -NextGuid $script:SelectedGuid -NextTimeKnown ([bool]$nextTime) -Pending $pending -Refreshing $refreshing -LastRefresh $script:SystemStatusLastRefresh -Drift $script:BootTargetDriftState -DriftFailed ([bool]$script:SystemStatusDriftFailed) -ReadinessTimeKnown ([bool]$readinessTime) -EntriesTimeKnown ([bool]$entriesTime)
    return $model
}

function Set-SystemStatusLabelContent {
    param($Form,[string]$Name,[string]$Text)
    $label = $Form.Tag.Body.Controls[$Name]
    if (-not $label) { return $false }
    $changed = $label.Text -cne $Text
    if ($changed) { $label.Text = $Text }
    $label.AccessibleName = $Text
    $label.AccessibleDescription = $Text
    if ($changed) { $Form.Tag.Tip.SetToolTip($label,$Text) }
    return $changed
}

function Set-SystemStatusSymbol {
    param($Form,[string]$Name,[string]$State)
    $label = $Form.Tag.Body.Controls['SystemStatusSymbol-'+$Name]
    $label.Text = switch ($State) { 'good' {'✓'} 'attention' {'!'} 'busy' {'…'} default {'?'} }
    $label.ForeColor = if ([Windows.Forms.SystemInformation]::HighContrast) { [Drawing.SystemColors]::WindowText }
        elseif ($State -eq 'good') { [Drawing.Color]::FromArgb(129,184,149) }
        elseif ($State -in @('attention','unknown')) { [Drawing.Color]::FromArgb(234,182,94) }
        else { $script:ColorSecondary }
}

function Update-SystemStatusPopupPresentation {
    param([Windows.Forms.Form]$Form)
    $model = Get-SystemStatusPresentation
    $default = if ($model.Default -eq 'Value') { $model.DefaultName } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Default) }
    $next = if ($model.Next -eq 'Value') { $model.NextName } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Next) }
    $relation = if ($model.Next -eq 'Value') { Get-LocalizedString -Key ('SystemStatus.'+$model.Relation) } else { '' }
    $ready = if ($model.Readiness -eq 'Ready') { Get-LocalizedString -Key 'SystemStatus.ReadyShort' } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Readiness) }
    $readyDetail = if ($model.Hint) { Get-LocalizedString -Key ('SystemStatus.'+$model.Hint) } elseif ($model.Readiness -eq 'Ready') { Get-LocalizedString -Key 'SystemStatus.ConfigurationChecked' } else { '' }
    $summary = if ($model.Summary -eq 'SummaryReady') { Get-LocalizedString -Key 'SystemStatus.SummaryReadyShort' } else { Get-LocalizedString -Key ('SystemStatus.'+$model.Summary) }
    $summaryDetail = if ($model.Refresh) { Get-LocalizedString -Key ('SystemStatus.'+$model.Refresh) } elseif ($model.Summary -eq 'SummaryReady') { Get-LocalizedString -Key 'SystemStatus.LastCheck' } else { '' }
    $drift = if ($model.Drift -eq 'DriftNone') { Get-LocalizedString -Key 'SystemStatus.DriftNoneShort' } elseif ($model.Drift -eq 'DriftChanged') { Get-LocalizedString -Key 'SystemStatus.DriftChangedShort' } else { Get-LocalizedString -Key 'SystemStatus.Unknown' }
    $driftDetail = if ($model.Drift -in @('DriftNone','DriftChanged')) { Get-LocalizedString -Key 'SystemStatus.LastComparison' } else { Get-LocalizedString -Key 'SystemStatus.DriftUnknown' }
    $times = Get-SystemStatusObservationPresentation -Next $(if ($script:NextBootFirmwareReadVerified) { $script:SystemStatusNextObservedUtc } else { $null }) -Entries $script:SystemStatusEntriesObservedUtc -Readiness $script:SystemStatusReadinessObservedUtc
    $values = @{Summary=$summary;Stored=$default;Next=$next;Readiness=$ready;Drift=$drift;Freshness=$times.Shared}
    $details = @{Summary=$summaryDetail;Next=$relation;Readiness=$readyDetail;Drift=$driftDetail}
    $changed = $false
    foreach ($key in $values.Keys) { if (Set-SystemStatusLabelContent $Form ('SystemStatusValue-'+$key) $values[$key]) { $changed=$true } }
    foreach ($key in $details.Keys) { if (Set-SystemStatusLabelContent $Form ('SystemStatusDetail-'+$key) $details[$key]) { $changed=$true } }
    $index=0
    foreach ($key in @('Manager','Entries','Readiness')) {
        if (Set-SystemStatusLabelContent $Form ('SystemStatusTimeValue-'+$key) $times.Values[$index]) { $changed=$true }
        $index++
    }
    Set-SystemStatusSymbol $Form 'Summary' $(switch ($model.Summary) { 'SummaryReady' {'good'} 'SummaryAttention' {'attention'} 'SummaryBusy' {'busy'} default {'unknown'} })
    Set-SystemStatusSymbol $Form 'Readiness' $(switch ($model.Readiness) { 'Ready' {'good'} 'Checking' {'busy'} 'Busy' {'busy'} 'Unknown' {'unknown'} default {'attention'} })
    Set-SystemStatusSymbol $Form 'Drift' $(switch ($model.Drift) { 'DriftNone' {'good'} 'DriftChanged' {'attention'} default {'unknown'} })
    if ($changed) { Set-SystemStatusPopupWidth -Form $Form -Scale ([Math]::Max(1.0,$Form.Tag.Scale)) }
}

# Measure actual text at the available width and current native font.
# Empty secondary lines consume no vertical space.
function Set-SystemStatusTextBounds {
    param($Control,[int]$X,[int]$Y,[int]$Width,[double]$Scale)
    $Control.Visible = -not [string]::IsNullOrEmpty($Control.Text)
    if (-not $Control.Text) { $Control.Bounds=[Drawing.Rectangle]::new($X,$Y,[Math]::Max(1,$Width),0); return 0 }
    $flags=[Windows.Forms.TextFormatFlags]::WordBreak -bor [Windows.Forms.TextFormatFlags]::NoPrefix
    $measured=[Windows.Forms.TextRenderer]::MeasureText($Control.Text,$Control.Font,[Drawing.Size]::new([Math]::Max(1,$Width),32767),$flags)
    $height=[Math]::Max([int][Math]::Ceiling(17*$Scale),$measured.Height+2)
    $Control.Bounds=[Drawing.Rectangle]::new($X,$Y,[Math]::Max(1,$Width),$height)
    return $height
}

function Set-SystemStatusContentLayout {
    param($Form,[int]$Width,[double]$Scale)
    $controls=$Form.Tag.Body.Controls
    $margin=[int][Math]::Round(16*$Scale)
    $gap=[Math]::Max(2,[int][Math]::Round(4*$Scale))
    $sectionGap=[Math]::Max(4,[int][Math]::Round(8*$Scale))
    $iconWidth=[Math]::Max(1,[int][Math]::Round(30*$Scale))
    $available=[Math]::Max(1,$Width-2*$margin)
    $y=$sectionGap
    foreach ($key in @('Summary','Stored','Next','Readiness','Drift')) {
        $heading=$controls['SystemStatusHeading-'+$key]
        $section=$controls['SystemStatusSection-'+$key]
        if ($section) {
            $y+=$sectionGap
            $divider=$controls['SystemStatusDivider-'+$key]
            $divider.Bounds=[Drawing.Rectangle]::new($margin,$y,$available,[Math]::Max(1,[int][Math]::Round($Scale)))
            $y+=$sectionGap
            $y+=Set-SystemStatusTextBounds $section $margin $y $available $Scale
            $y+=$gap
        }
        if ($heading) { $y+=Set-SystemStatusTextBounds $heading $margin $y $available $Scale }
        $symbol=$controls['SystemStatusSymbol-'+$key]
        $offset=if ($symbol) { [Math]::Min($iconWidth,[Math]::Max(0,$available-1)) } else { 0 }
        $top=$y
        $value=$controls['SystemStatusValue-'+$key]
        $y+=Set-SystemStatusTextBounds $value ($margin+$offset) $y ($available-$offset) $Scale
        $detail=$controls['SystemStatusDetail-'+$key]
        if ($detail) { $y+=Set-SystemStatusTextBounds $detail ($margin+$offset) $y ($available-$offset) $Scale }
        if ($symbol) {
            $symbol.Bounds=[Drawing.Rectangle]::new($margin,$top,[Math]::Max(1,$offset-$gap),[Math]::Max(1,$y-$top))
        }
        $y+=$gap
    }
    $y+=$sectionGap
    $controls['SystemStatusDivider-Freshness'].Bounds=[Drawing.Rectangle]::new($margin,$y,$available,[Math]::Max(1,[int][Math]::Round($Scale)))
    $y+=$sectionGap
    $y+=Set-SystemStatusTextBounds $controls['SystemStatusSection-Freshness'] $margin $y $available $Scale
    $y+=$gap
    $leftWidth=[Math]::Max(1,[int][Math]::Floor($available*0.39))
    $rightWidth=[Math]::Max(1,$available-$leftWidth-$gap)
    foreach ($key in @('Manager','Entries','Readiness')) {
        $left=Set-SystemStatusTextBounds $controls['SystemStatusTimeLabel-'+$key] $margin $y $leftWidth $Scale
        $right=Set-SystemStatusTextBounds $controls['SystemStatusTimeValue-'+$key] ($margin+$leftWidth+$gap) $y $rightWidth $Scale
        $y+=[Math]::Max($left,$right)+$gap
    }
    $y+=Set-SystemStatusTextBounds $controls['SystemStatusValue-Freshness'] $margin $y $available $Scale
    return ($y+$sectionGap)
}

function Set-SystemStatusPopupWidth {
    param($Form,[double]$Scale)
    $state=$Form.Tag
    $width=$state.Viewport.Width
    $height=$state.Viewport.Height
    if ($width -le 0 -or $height -le 0) { return }
    $state.Body.SuspendLayout()
    try {
        $content=Set-SystemStatusContentLayout -Form $Form -Width $width -Scale $Scale
        $gutter=0
        if ($content -gt $height) {
            $gutter=[Math]::Min($width-1,[int][Math]::Round(8*$Scale))
            $content=Set-SystemStatusContentLayout -Form $Form -Width ($width-$gutter) -Scale $Scale
        }
        $range=[Math]::Max(0,$content-$height)
        $previous=$state.Scroll.Value
        $state.Scroll.Bounds=[Drawing.Rectangle]::new($width-$gutter,0,$gutter,$height)
        $state.Scroll.Maximum=$range
        $state.Scroll.LargeChange=$height
        $state.Scroll.Value=[Math]::Min($previous,$range)
        $state.Scroll.Visible=($range -gt 0 -and $gutter -gt 0)
        $state.Body.Bounds=[Drawing.Rectangle]::new(0,-$state.Scroll.Value,$width-$gutter,[Math]::Max($height,$content))
    } finally { $state.Body.ResumeLayout($false) }
}

function Add-SystemStatusLabel {
    param($Form,[string]$Name,[string]$Text,$Font,[Drawing.Color]$Ink,[switch]$Right)
    $label=New-Label -Text $Text -Font $Font -ForeColor $Ink -X 16 -Y 0 -Width 358 -Height 20
    $label.Name=$Name
    $label.BackColor=$Form.Tag.Body.BackColor
    $label.AutoSize=$false
    $label.AutoEllipsis=$false
    $label.UseMnemonic=$false
    $label.TextAlign=if ($Right) { [Drawing.ContentAlignment]::TopRight } else { [Drawing.ContentAlignment]::TopLeft }
    $label.AccessibleRole=[Windows.Forms.AccessibleRole]::StaticText
    $label.AccessibleName=$Text
    $label.AccessibleDescription=$Text
    $Form.Tag.Body.Controls.Add($label)
}

function New-SystemStatusPopup {
    $form = New-AuxiliaryPopupForm -Name 'LenovoSystemStatusPopup' -Title (Get-LocalizedString -Key 'SystemStatus.Title') -Subtitle (Get-LocalizedString -Key 'SystemStatus.Subtitle') -ContentHeight 440
    $highContrast=[Windows.Forms.SystemInformation]::HighContrast
    $valueInk=if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorPrimary }
    $secondaryInk=if ($highContrast) { [Drawing.SystemColors]::WindowText } else { $script:ColorSecondary }
    $lineInk=if ($highContrast) { [Drawing.SystemColors]::WindowText } else { [Drawing.Color]::FromArgb(57,57,57) }
    if ($highContrast) {
        $form.BackColor=[Drawing.SystemColors]::Window
        $form.Tag.Body.BackColor=[Drawing.SystemColors]::Window
        $form.Tag.Viewport.BackColor=[Drawing.SystemColors]::Window
        $form.Tag.Header.BackColor=[Drawing.SystemColors]::Control
        $form.Tag.Title.ForeColor=[Drawing.SystemColors]::ControlText
        $form.Tag.Subtitle.ForeColor=[Drawing.SystemColors]::ControlText
        $form.Tag.Close.BackColor=[Drawing.SystemColors]::Control
        $form.Tag.Close.ForeColor=[Drawing.SystemColors]::ControlText
    }
    foreach ($key in @('Stored','Readiness','Freshness')) {
        $sectionKey=switch ($key) { 'Stored' {'Targets'} 'Readiness' {'Readiness'} default {'Checks'} }
        Add-SystemStatusLabel $form ('SystemStatusSection-'+$key) (Get-LocalizedString -Key ('SystemStatus.'+$sectionKey)) $form.Tag.Heading $secondaryInk
        $divider=New-Object Windows.Forms.Panel
        $divider.Name='SystemStatusDivider-'+$key
        $divider.BackColor=$lineInk
        $divider.TabStop=$false
        $form.Tag.Body.Controls.Add($divider)
    }
    foreach ($key in @('Stored','Next')) {
        Add-SystemStatusLabel $form ('SystemStatusHeading-'+$key) (Get-LocalizedString -Key ('SystemStatus.'+$key+'Caption')) $form.Tag.Regular $secondaryInk
    }
    foreach ($key in @('Summary','Stored','Next','Readiness','Drift','Freshness')) {
        $font=if ($key -eq 'Freshness') { $form.Tag.Regular } else { $form.Tag.Bold }
        $ink=if ($key -eq 'Freshness') { $secondaryInk } else { $valueInk }
        Add-SystemStatusLabel $form ('SystemStatusValue-'+$key) '' $font $ink
    }
    foreach ($key in @('Summary','Next','Readiness','Drift')) {
        Add-SystemStatusLabel $form ('SystemStatusDetail-'+$key) '' $form.Tag.Regular $secondaryInk
    }
    foreach ($key in @('Summary','Readiness','Drift')) {
        Add-SystemStatusLabel $form ('SystemStatusSymbol-'+$key) '' $form.Tag.Bold $secondaryInk
    }
    foreach ($key in @('Manager','Entries','Readiness')) {
        Add-SystemStatusLabel $form ('SystemStatusTimeLabel-'+$key) (Get-LocalizedString -Key ('SystemStatus.'+$key+'Caption')) $form.Tag.Regular $secondaryInk
        Add-SystemStatusLabel $form ('SystemStatusTimeValue-'+$key) '' $form.Tag.Regular $valueInk -Right
    }
    Update-SystemStatusPopupPresentation -Form $form
    $content=Set-SystemStatusContentLayout -Form $form -Width $form.ClientSize.Width -Scale 1.0
    $form.Tag.ContentHeight=$content
    $form.ClientSize=[Drawing.Size]::new(390,[Math]::Min(540,64+$content))
    $form.Tag.Viewport.Height=$form.ClientSize.Height-64
    Set-SystemStatusPopupWidth -Form $form -Scale 1.0
    # Presentation only; the existing lifecycle owns and disposes this timer.
    $timer=New-Object Windows.Forms.Timer
    $timer.Interval=500
    $timer.Add_Tick({
        if ($script:ActiveAuxiliaryPopup -and $script:ActiveAuxiliaryPopup.Name -eq 'LenovoSystemStatusPopup') {
            Update-SystemStatusPopupPresentation -Form $script:ActiveAuxiliaryPopup
        }
    })
    $form.Tag.Timer=$timer
    $form.Add_KeyDown({
        param($sender,$eventArgs)
        $scroll = $sender.Tag.Scroll
        if (-not $scroll.Visible) { return }
        $delta = switch ($eventArgs.KeyCode) {
            'PageDown' { $scroll.LargeChange }
            'PageUp' { -$scroll.LargeChange }
            'Down' { $scroll.SmallChange }
            'Up' { -$scroll.SmallChange }
            default { 0 }
        }
        if ($delta) {
            $scroll.Value = [Math]::Max(0,[Math]::Min($scroll.Maximum,$scroll.Value+$delta))
            $eventArgs.Handled=$true
            $eventArgs.SuppressKeyPress=$true
        }
    })
    return $form
}

function Show-SystemStatusPopup {
    param([Windows.Forms.Control]$Owner)
    if ($script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog -or -not $Owner -or -not $Owner.Enabled) { return }
    [void](Show-OwnedAuxiliaryPopup -Form (New-SystemStatusPopup) -Owner $Owner)
}
