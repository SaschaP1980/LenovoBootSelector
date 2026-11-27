# LBS-279: a short synchronous visual transaction owns no business state.
# Hidden/isolated fixtures, modal and OLE-drag paths retain ordinary rendering.
function Start-PopupVisualCommit {
    param([string]$Reason)
    if (-not $script:Popup -or $script:Popup.IsDisposed -or -not $script:Popup.Visible -or
        $script:ActiveAuxiliaryPopup -or $script:ActiveOwnedDialog -or
        $script:ManageActiveDragGuid -or $script:ManageDragLayout) { return }
    if (-not ('LenovoPopupVisualCommit' -as [type])) { return }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        $commit = [LenovoPopupVisualCommit]::Begin($script:Popup)
        if ($commit) {
            $commit.Tag = [pscustomobject]@{ Reason=$Reason; Clock=$clock; CaptureMs=$clock.ElapsedMilliseconds }
            return $commit
        }
    }
    catch {
        # Cosmetic fallback only; Begin disposes any partially created cover.
        Write-Verbose ('Popup visual commit unavailable: ' + $Reason + ' (' + $_.Exception.Message + ')')
        try {
            Write-RuntimeDiagnosticEvent -Event 'POPUP_VISUAL_COMMIT_FALLBACK' -Stage 'presentation' -Success $false -Data (New-RuntimeDiagnosticData @{ reason=$Reason; elapsedMs=$clock.ElapsedMilliseconds }) -Level warning
        }
        catch { Write-Verbose 'Popup visual commit diagnostic unavailable.' }
    }
}

function Stop-PopupVisualCommit {
    param($Commit)
    if ($null -eq $Commit) { return }
    $info = $Commit.Tag
    $success = $false
    try { $Commit.Complete(); $success = $true }
    catch { Write-Verbose 'Popup visual commit final repaint unavailable.' }
    if ($info) {
        try {
            Write-RuntimeDiagnosticEvent -Event 'POPUP_VISUAL_COMMIT' -Stage 'presentation' -Success $success -Data (New-RuntimeDiagnosticData @{ reason=$info.Reason; captureMs=$info.CaptureMs; elapsedMs=$info.Clock.ElapsedMilliseconds; framePaintCount=$Commit.FramePaintCount })
        }
        catch { Write-Verbose 'Popup visual commit diagnostic unavailable.' }
    }
}

function New-Label {
    param(
        [string]$Text,
        [Drawing.Font]$Font,
        [Drawing.Color]$ForeColor,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.BackColor = [Drawing.Color]::Transparent
    $label.Location = New-Object Drawing.Point($X, $Y)
    $label.Size = New-Object Drawing.Size($Width, $Height)
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function Get-BootRowFromControl($Control) {
    $current = $Control
    while ($current) {
        if (($current -is [System.Windows.Forms.Panel]) -and $current.Name -eq 'BootRow') { return $current }
        $current = $current.Parent
    }
    return $null
}

function Set-RowHoverState($Control, [bool]$Hover) {
    $row = Get-BootRowFromControl $Control
    if (-not $row) { return }

    $rowGuid = [string]$row.Tag
    # Presentation only: use the already-observed capability projection, never
    # perform a task/firmware/readiness probe on pointer movement. The existing
    # click owner remains authoritative, including cold-start deferred intent.
    $hot = $Hover -and $row.Enabled -and -not $script:ManageActiveDragGuid
    $observed = $script:SystemStatusCapabilities
    if ($script:IsManageEntriesMode) {
        if ($observed -and -not $observed.CanManageEntries) { $hot = $false }
    } else {
        if ($script:BootNextPendingGuid -or $script:DefaultTargetChangePending -or $script:RestartVerification) { $hot = $false }
        if ($observed -and -not $observed.CanSetBootNext -and -not ($observed.State -eq 'Checking' -and $observed.CanUseCachedBootState)) { $hot = $false }
    }
    $hc = [Windows.Forms.SystemInformation]::HighContrast
    $rowHover = if ($hc) { $script:ColorHover } else { [LenovoInteractionPalette]::Tint($script:ColorRow) }
    $title=$row.Controls['BootTitleLabel']
    if ($title) {
        $hiddenInk=$script:IsManageEntriesMode -and (Test-ManageEntryHidden -Guid $rowGuid)
        $title.ForeColor=if ($hot -and -not [Windows.Forms.SystemInformation]::HighContrast) { [LenovoInteractionPalette]::Hover } elseif ($hiddenInk) { [Drawing.Color]::FromArgb(175,175,175) } else { $script:ColorPrimary }
    }
    if ($script:IsManageEntriesMode) {
        if ($script:ManageActiveDragGuid -and $rowGuid -eq $script:ManageActiveDragGuid -and $script:ManageDragLayout) {
            $row.BackColor = [Drawing.Color]::FromArgb(48,48,54)
            return
        }
        $hidden = Test-ManageEntryHidden -Guid $rowGuid
        if ($hidden) {
            $hiddenSurface = [Drawing.Color]::FromArgb(27,27,27)
            $row.BackColor = if ($hot) { if ($hc) { [Drawing.Color]::FromArgb(37,37,37) } else { [LenovoInteractionPalette]::Tint($hiddenSurface) } } else { $hiddenSurface }
        }
        else {
            $row.BackColor = if ($hot) { $rowHover } else { $script:ColorRow }
        }
        $row.Invalidate($true)
        return
    }

    $isSelected = $script:SelectedGuid -and ($rowGuid -eq $script:SelectedGuid)
    $isPending = $script:BootNextPendingGuid -and ($rowGuid -eq $script:BootNextPendingGuid)
    if ($isPending) { $row.BackColor = [Drawing.Color]::FromArgb(46,40,27) }
    elseif ($isSelected) {
        $row.BackColor = $script:ColorSelectedRow
    }
    elseif ($hot) {
        $row.BackColor = $rowHover
    }
    else {
        $row.BackColor = $script:ColorRow
    }
    $row.Invalidate($true)
}

# A row's presentation identity deliberately excludes refresh timestamps, diagnostics and
# status text. Firmware metadata matters only when it can affect a rendered row.
# The raw canonical data never leaves this function; diagnostics use SHA-256 only.
function Get-PopupRowsPresentationState {
    param([Parameter(Mandatory=$true)][double]$Scale)

    $manage = [bool]$script:IsManageEntriesMode
    $entries = if ($manage) { @(Get-OrderedEntriesForUi -IncludeHidden -UseManageDraft) } else { @(Get-OrderedEntriesForUi) }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $entries) {
        $guid = ([string]$entry.Guid).ToLowerInvariant()
        $alias = Get-EntryAlias -Guid $guid -UseManageDraft:$manage
        $title = Get-EntryDisplayTitle -Entry $entry -UseManageDraft:$manage
        $accent = if ($null -ne $entry.Accent) { [int]$entry.Accent.ToArgb() } else { 0 }
        [void]$rows.Add([ordered]@{
            guid = $guid
            title = [string]$entry.Title
            subtitle = [string]$entry.Subtitle
            rawDescription = [string]$entry.RawDescription
            symbol = [string]$entry.Symbol
            typeTooltip = [string]$entry.TypeTooltip
            accent = $accent
            displayTitle = [string]$title
            alias = [string]$alias
            hidden = [bool]($manage -and (Test-ManageEntryHidden -Guid $guid))
            selected = [bool](-not $manage -and $script:SelectedGuid -and $guid -eq $script:SelectedGuid)
            pending = [bool](-not $manage -and $script:BootNextPendingGuid -and $guid -eq $script:BootNextPendingGuid)
            editing = [bool]($manage -and $script:ManageAliasEditGuid -and $guid -eq $script:ManageAliasEditGuid)
        })
    }
    # These translated strings appear within rows and may change without a
    # firmware data change. The status/header themselves are updated separately.
    $localized = @(
        (Get-LocalizedString -Key 'Manage.OriginalName' -Values @{ Name = '' }),
        (Get-LocalizedString -Key 'Manage.OriginalNameHint'),
        (Get-LocalizedString -Key 'Manage.HiddenAccessible'),
        (Get-LocalizedString -Key 'Manage.VisibleAccessible'),
        (Get-LocalizedString -Key 'Manage.ReorderHint'),
        (Get-LocalizedString -Key 'Manage.KeyboardInstructions'),
        (Get-LocalizedString -Key 'Manage.KeyboardPosition' -Values @{Position=1;Count=1}),
        (Get-LocalizedString -Key 'Manage.ClearAliasHint'),
        (Get-LocalizedString -Key 'Manage.AliasCue'),
        (Get-LocalizedString -Key 'Manage.AliasFieldHint'),
        (Get-LocalizedString -Key 'Boot.MenuManageSubtitle'),
        (Get-LocalizedString -Key 'BootNext.SelectionPending'),
        (Get-LocalizedString -Key 'BootNext.RowPendingHint'),
        (Get-LocalizedString -Key 'BootNext.RowSelectedHint')
    )
    $presentation = [ordered]@{
        scale = [Math]::Round($Scale, 4)
        manage = $manage
        selectedGuid = if ($manage) { '' } else { [string]$script:SelectedGuid }
        pendingGuid = if ($manage) { '' } else { [string]$script:BootNextPendingGuid }
        aliasEditGuid = if ($manage) { [string]$script:ManageAliasEditGuid } else { '' }
        localized = $localized
        rows = $rows.ToArray()
    }
    $identity = ConvertTo-Json -InputObject $presentation -Depth 6 -Compress
    $rowSignatures = @{}
    $rowStructureSignatures = @{}
    foreach ($row in $rows.ToArray()) {
        $rowSignatures[[string]$row.guid] = ConvertTo-Json -InputObject ([ordered]@{
            manage = $manage
            localized = $localized
            row = $row
        }) -Depth 6 -Compress
        # Title, subtitle, raw description and computed display title are text-only.
        $rowStructureSignatures[[string]$row.guid] = ConvertTo-Json -InputObject ([ordered]@{
            manage = $manage
            localized = $localized
            guid = $row.guid
            symbol = $row.symbol
            typeTooltip = $row.typeTooltip
            accent = $row.accent
            alias = $row.alias
            hidden = $row.hidden
            selected = $row.selected
            pending = $row.pending
            editing = $row.editing
        }) -Depth 6 -Compress
    }
    $globalSignature = ConvertTo-Json -InputObject ([ordered]@{
        scale = $presentation.scale
        manage = $presentation.manage
        selectedGuid = $presentation.selectedGuid
        pendingGuid = $presentation.pendingGuid
        aliasEditGuid = $presentation.aliasEditGuid
        localized = $localized
    }) -Depth 6 -Compress
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $fingerprint = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)))).Replace('-', '')
    }
    finally { $hash.Dispose() }
    return [pscustomobject]@{
        Identity = $identity
        Fingerprint = $fingerprint
        Entries = $entries
        EntryCount = $entries.Count
        RowSignatures = $rowSignatures
        RowStructureSignatures = $rowStructureSignatures
        GlobalSignature = $globalSignature
        Mode = $manage
        Scale = $Scale
    }
}

function Update-PopupRowsPeripheralUi {
    param($StatusLabel)
    if ($StatusLabel) { $StatusLabel.Text = $script:LastStatusText }
    if ($script:IsManageEntriesMode -and $script:Popup) {
        $focused = $script:Popup.Controls.Find('BootRow',$true) | Where-Object { $_.Focused -and $_.TabStop } | Select-Object -First 1
        if ($focused) { Update-ManageKeyboardRowPresentation -Row $focused }
    }
    Update-DefaultUi
    Update-RestartTargetUi
    Update-ManageSaveButtonState
    Update-MaintenanceUi
}

function Write-PopupRowsRenderDiagnostic {
    param([string]$Reason, [string]$Before, [string]$After, [int]$EntryCount,
          [bool]$ActiveDrag, [bool]$Skipped, [bool]$Deferred,
          [int]$AffectedCount = 0, [bool]$LayoutUpdated = $false,
          [int]$RebuiltCount = 0, [int]$UpdatedInPlaceCount = 0)
    try {
        Write-RuntimeDiagnosticEvent -Event 'POPUP_ROWS_PRESENTATION' -Stage 'presentation' -Success $true -Data (New-RuntimeDiagnosticData @{
            reason = $Reason
            beforeFingerprint = $Before
            afterFingerprint = $After
            entryCount = $EntryCount
            affectedEntryCount = $AffectedCount
            updatedInPlaceCount = $UpdatedInPlaceCount
            rebuiltEntryCount = $RebuiltCount
            layoutUpdated = $LayoutUpdated
            activeDrag = $ActiveDrag
            skipped = $Skipped
            deferred = $Deferred
            rebuilt = (-not $Skipped -and -not $Deferred -and $RebuiltCount -gt 0)
        })
    }
    catch { Write-Verbose 'Popup row presentation diagnostic unavailable.' }
}

function Save-PopupRowsRenderedSnapshot {
    param($ListPanel,$ContentPanel,$Snapshot)
    $script:PopupRowsContentPanel = $ContentPanel
    $script:PopupRowsIdentity = $Snapshot.Identity
    $script:PopupRowsFingerprint = $Snapshot.Fingerprint
    $script:PopupRowsRowSignatures = $Snapshot.RowSignatures
    $script:PopupRowsRowStructureSignatures = $Snapshot.RowStructureSignatures
    $script:PopupRowsGlobalSignature = $Snapshot.GlobalSignature
    $script:PopupRowsRenderedMode = $Snapshot.Mode
    $script:PopupRowsRenderedScale = $Snapshot.Scale
    $script:PopupRowsViewportHeight = $ListPanel.ClientSize.Height
    $script:PopupRowsRenderedAliasEditGuid = if ($script:IsManageEntriesMode) { [string]$script:ManageAliasEditGuid } else { '' }
}

# -1 requests the existing keyed reconstruction path instead of text-only reuse.
# Validate every visible row before modifying any control (all-or-nothing gate).
function Invoke-PopupRowsTextReconciliation {
    param($ListPanel,$ContentPanel,$Snapshot,[object[]]$ExistingRows)
    if (-not [object]::ReferenceEquals($script:PopupRowsContentPanel,$ContentPanel) -or
        ([bool]$script:PopupRowsRenderedMode -ne [bool]$Snapshot.Mode) -or
        ([double]$script:PopupRowsRenderedScale -ne [double]$Snapshot.Scale) -or
        ([string]$script:PopupRowsGlobalSignature -cne [string]$Snapshot.GlobalSignature) -or
        ($script:PopupRowsRowSignatures -isnot [hashtable]) -or
        ($script:PopupRowsRowStructureSignatures -isnot [hashtable]) -or
        $ExistingRows.Count -ne $Snapshot.EntryCount -or
        $script:PopupRowsViewportHeight -ne $ListPanel.ClientSize.Height) { return -1 }

    $orderedRows = @($ExistingRows | Sort-Object Top)
    for ($i = 0; $i -lt $Snapshot.EntryCount; $i++) {
        $row = $orderedRows[$i]
        $guid = ([string]$Snapshot.Entries[$i].Guid).ToLowerInvariant()
        if ($row.IsDisposed -or ([string]$row.Tag).ToLowerInvariant() -cne $guid -or
            -not $script:PopupRowsRowStructureSignatures.ContainsKey($guid) -or
            -not $script:PopupRowsRowSignatures.ContainsKey($guid) -or
            [string]$script:PopupRowsRowStructureSignatures[$guid] -cne [string]$Snapshot.RowStructureSignatures[$guid] -or
            @($row.Controls.Find('BootTitleLabel',$false)).Count -ne 1 -or
            @($row.Controls.Find('BootSubtitleLabel',$false)).Count -ne 1) { return -1 }
    }

    $updated = 0
    for ($i = 0; $i -lt $Snapshot.EntryCount; $i++) {
        $entry = $Snapshot.Entries[$i]
        $guid = ([string]$entry.Guid).ToLowerInvariant()
        if ([string]$script:PopupRowsRowSignatures[$guid] -cne [string]$Snapshot.RowSignatures[$guid]) {
            if (Update-BootEntryRowText -Row $orderedRows[$i] -Entry $entry) { $updated++ }
        }
    }
    Save-PopupRowsRenderedSnapshot -ListPanel $ListPanel -ContentPanel $ContentPanel -Snapshot $Snapshot
    return [int]$updated
}


# UX01-V8: snapshot only an actually focused normal boot target. A stale
# previously focused GUID must never pull focus away from another UI action.
function Get-NormalBootFocusedGuid {
    param($ContentPanel)
    if ($script:IsManageEntriesMode -or -not $ContentPanel -or $ContentPanel.IsDisposed) { return '' }
    foreach ($row in @($ContentPanel.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed
    })) {
        if ($row.Focused) { return [string]$row.Tag }
    }
    return ''
}

function Restore-NormalBootFocusedGuid {
    param($ContentPanel,[string]$Guid,[Nullable[bool]]$KeyboardCue)
    if ($script:IsManageEntriesMode -or -not $Guid -or -not $ContentPanel -or $ContentPanel.IsDisposed) { return }
    foreach ($row in @($ContentPanel.Controls | Where-Object {
        $_.Name -eq 'BootRow' -and -not $_.IsDisposed
    })) {
        if (([string]$row.Tag).ToLowerInvariant() -eq $Guid.ToLowerInvariant()) {
            if ($null -ne $KeyboardCue -and $row.PSObject.Methods['SetKeyboardCue']) { $row.SetKeyboardCue([bool]$KeyboardCue) }
            [void]$row.Focus()
            Set-NormalBootRowVisible -Row $row
            return
        }
    }
}

function Invoke-PopupRowsReconciliation {
    param(
        $ListPanel, $ContentPanel, $ScrollBar, $Snapshot,
        [double]$Scale, [object[]]$ExistingRows, [bool]$ActiveDrag
    )

    $script:PopupRowsRefreshPending = $false
    $script:PopupRowsViewportPending = $false
    $focusedNormalGuid = if (-not $Snapshot.Mode) {
        Get-NormalBootFocusedGuid -ContentPanel $ContentPanel
    } else { '' }
    $focusedNormalRow = if ($focusedNormalGuid) { $existingRows | Where-Object { $_.Focused -and [string]$_.Tag -eq $focusedNormalGuid } | Select-Object -First 1 }
    $normalCue = if ($focusedNormalRow -and $focusedNormalRow.PSObject.Properties['KeyboardCueEnabled']) { [bool]$focusedNormalRow.KeyboardCueEnabled } else { $true }
    $manageAnchor = if ($Snapshot.Mode -and $script:PopupRowsRenderedMode) { $existingRows | Where-Object { $_.TabStop -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode } | Select-Object -First 1 }
    $manageAnchorGuid = if ($manageAnchor) { [string]$manageAnchor.Tag } else { '' }
    $manageAnchorIndex = if ($manageAnchor) { [int]$manageAnchor.TabIndex } else { 0 }
    $focusedManageRow = if ($Snapshot.Mode -and $script:PopupRowsRenderedMode) {
        $existingRows | Where-Object { $_.Focused -and $_.TabStop } | Select-Object -First 1
    }
    $focusedManageGuid = if ($focusedManageRow) { [string]$focusedManageRow.Tag } else { '' }
    $focusedManageIndex = if ($focusedManageRow) { [int]$focusedManageRow.TabIndex } else { -1 }
    $manageCue = if ($focusedManageRow -and $focusedManageRow.PSObject.Properties['KeyboardCueEnabled']) { [bool]$focusedManageRow.KeyboardCueEnabled } else { $true }
    $manageEditCue = [bool]($focusedManageRow -and $focusedManageRow.PSObject.Properties['ManageEditCueActive'] -and $focusedManageRow.ManageEditCueActive -and -not $activeDrag -and -not $script:ManageAliasEditGuid)
    if ($activeDrag) { Reset-ManageDragPreview }
    $previousSignatures = $script:PopupRowsRowSignatures
    $canReconcile = [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel) -and
        ([bool]$script:PopupRowsRenderedMode -eq $snapshot.Mode) -and
        ([double]$script:PopupRowsRenderedScale -eq $snapshot.Scale) -and
        ($previousSignatures -is [hashtable])
    $oldRows = @{}
    if ($canReconcile) {
        foreach ($row in $existingRows) {
            $guid = ([string]$row.Tag).ToLowerInvariant()
            if ($oldRows.ContainsKey($guid)) { $canReconcile = $false; break }
            $oldRows[$guid] = $row
        }
    }

    $affected = 0
    $contentPanel.SuspendLayout()
    try {
        if (-not $canReconcile) {
            $affected = $existingRows.Count
            $contentPanel.Controls.Clear()
        }
        $baseRowHeight = 60
        $scaledRowHeight = [int][Math]::Round($baseRowHeight * $scale)
        $rowGap = [int][Math]::Round(4 * $scale)
        $y = 0
        $keyboardTabIndex = 0
        $handlers = New-BootEntryInteractionHandlers
        if ($script:ManageContentDropPanel -ne $contentPanel) {
            $contentPanel.Add_DragEnter($handlers.DragEnter)
            $contentPanel.Add_DragOver($handlers.DragOver)
            $contentPanel.Add_DragLeave($handlers.DragLeave)
            $contentPanel.Add_DragDrop($handlers.DragDrop)
            $script:ManageContentDropPanel = $contentPanel
        }
        $contentPanel.AllowDrop = [bool]$script:IsManageEntriesMode

        foreach ($entry in $snapshot.Entries) {
            $guid = ([string]$entry.Guid).ToLowerInvariant()
            $row = $null
            if ($canReconcile -and $oldRows.ContainsKey($guid)) {
                $prior = $oldRows[$guid]
                if ($previousSignatures.ContainsKey($guid) -and
                    [string]$previousSignatures[$guid] -ceq [string]$snapshot.RowSignatures[$guid]) {
                    $row = $prior
                }
                else {
                    $contentPanel.Controls.Remove($prior)
                    $prior.Dispose()
                    $affected++
                }
                [void]$oldRows.Remove($guid)
            }
            if ($null -eq $row) {
                $rendered = New-BootEntryRow -Entry $entry -Y 0 -BaseRowHeight $baseRowHeight -Handlers $handlers
                $row = $rendered.Row
                $height = Set-PopupBootRowDpiLayout -Row $row -Scale $scale -Y $y
                $contentPanel.Controls.Add($row)
                $affected++
            }
            else {
                # Reused rows are already physically scaled; never scale twice.
                $row.Location = [Drawing.Point]::new(0, $y)
                $height = $row.Height
            }
            # A stable visual Tab order even when Controls are reused.
            $row.TabIndex = $keyboardTabIndex
            $keyboardTabIndex++
            $y += ($height + $rowGap)
        }
        if ($canReconcile) {
            foreach ($orphan in @($oldRows.Values)) {
                $contentPanel.Controls.Remove($orphan)
                $orphan.Dispose()
                $affected++
            }
        }

        Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $y -BaseRowHeight $scaledRowHeight -RowGap $rowGap

        Save-PopupRowsRenderedSnapshot -ListPanel $listPanel -ContentPanel $contentPanel -Snapshot $snapshot
    }
    finally { $contentPanel.ResumeLayout() }
    # Restore only if a normal row really owned focus before reconciliation.
    # Switching to Restart/settings/Manage Entries must never steal focus.
    Restore-NormalBootFocusedGuid -ContentPanel $ContentPanel -Guid $focusedNormalGuid -KeyboardCue:$normalCue
    if ($Snapshot.Mode) {
        $manageRows = @($ContentPanel.Controls | Where-Object { $_.Name -eq 'BootRow' -and $_.PSObject.Properties['ManageKeyboardMode'] -and $_.ManageKeyboardMode } | Sort-Object Top)
        foreach ($row in $manageRows) { Update-ManageKeyboardRowPresentation -Row $row }
        $anchor = $manageRows | Where-Object { [string]$_.Tag -eq $manageAnchorGuid } | Select-Object -First 1
        if (-not $anchor -and $manageRows.Count -gt 0) { $anchor = $manageRows[[Math]::Min($manageAnchorIndex,$manageRows.Count-1)] }
        if ($anchor) { $anchor.SetManageTabAnchor() }
        if ($focusedManageGuid -and -not $script:ManageAliasEditGuid) {
            Restore-ManageRowFocus -Guid $focusedManageGuid -FallbackIndex $focusedManageIndex -KeyboardCue:$manageCue -EditCue:$manageEditCue
        }
    }
    return [int]$affected
}

function Update-PopupRows {
    param([string]$Reason = 'caller')
    if (-not $script:Popup -or $script:Popup.IsDisposed) { return }
    if ($Reason -eq 'caller') {
        # Resolve unannotated legacy callers without modifying protected sources.
        $callerFrame = @(Get-PSCallStack | Select-Object -Skip 1 -First 1)
        if ($callerFrame.Count -gt 0 -and $callerFrame[0].Command) {
            $Reason = [string]$callerFrame[0].Command
        }
    }

    $listMatches = $script:Popup.Controls.Find('EntryList', $true)
    $listPanel = if ($listMatches.Count -gt 0) { $listMatches[0] } else { $null }
    $contentPanel = if ($listPanel) { $listPanel.Controls['EntryContent'] } else { $null }
    $scrollBar = if ($listPanel) { $listPanel.Controls['EntryScroll'] } else { $null }
    $statusMatches = $script:Popup.Controls.Find('StatusLabel', $true)
    $statusLabel = if ($statusMatches.Count -gt 0) { $statusMatches[0] } else { $null }
    if (-not $listPanel -or -not $contentPanel) { return }

    # The current mode/viewport can change without invalidating any row.
    Update-ManageEntriesUiState
    $scale = Get-PopupDpiLayoutScale -Popup $script:Popup
    $snapshot = Get-PopupRowsPresentationState -Scale $scale
    $before = [string]$script:PopupRowsFingerprint
    $activeDrag = [bool]$script:ManageActiveDragGuid
    $existingRows = @($contentPanel.Controls | Where-Object { $_.Name -eq 'BootRow' -and -not $_.IsDisposed })
    $same = [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel) -and
            ([string]$script:PopupRowsIdentity -ceq $snapshot.Identity) -and
            $existingRows.Count -eq $snapshot.EntryCount
    if ($same) {
        # A verified/pending state can change without altering row geometry or
        # metadata. Refresh semantic hints in place; unchanged bindings are no-ops.
        if (-not $script:IsManageEntriesMode -and $script:BootTypeToolTip) {
            $entryByGuid = @{}
            foreach ($entry in $snapshot.Entries) { $entryByGuid[[string]$entry.Guid] = $entry }
            foreach ($row in $existingRows) {
                $entry = $entryByGuid[[string]$row.Tag]
                if ($entry) { Update-NormalBootEntryTooltips -Row $row -Entry $entry }
            }
        }
        $script:PopupRowsRefreshPending = $false
        $viewportChanged = ($script:PopupRowsViewportHeight -ne $listPanel.ClientSize.Height)
        if ($viewportChanged -and $activeDrag) {
            # Do not disturb an animated placeholder with a scroll range change.
            $script:PopupRowsViewportPending = $true
        }
        elseif ($viewportChanged) {
            $gap = [int][Math]::Round(4 * $scale)
            $bottom = 0
            foreach ($row in $existingRows) { $bottom = [Math]::Max($bottom, $row.Bottom + $gap) }
            Update-BootEntryScrollLayout -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -ContentBottom $bottom -BaseRowHeight ([int][Math]::Round(60 * $scale)) -RowGap $gap
            $script:PopupRowsViewportHeight = $listPanel.ClientSize.Height
            $script:PopupRowsViewportPending = $false
        }
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $true -Deferred $false -LayoutUpdated ($viewportChanged -and -not $activeDrag)
        return
    }

    # WinForms DoDragDrop uses nested message processing. A worker completion can
    # arrive while the source row and animated placeholder are still in use.
    # Never dispose/recreate those controls until the interaction has ended.
    $editingExistingAlias = $script:IsManageEntriesMode -and $script:ManageAliasEditGuid -and
        ([string]$script:PopupRowsRenderedAliasEditGuid -eq [string]$script:ManageAliasEditGuid)
    if ($script:IsManageEntriesMode -and ($activeDrag -or $editingExistingAlias) -and
        [object]::ReferenceEquals($script:PopupRowsContentPanel, $contentPanel)) {
        $script:PopupRowsRefreshPending = $true
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $false -Deferred $true
        return
    }

    $textUpdated = Invoke-PopupRowsTextReconciliation -ListPanel $listPanel -ContentPanel $contentPanel -Snapshot $snapshot -ExistingRows $existingRows
    if ($textUpdated -ge 0) {
        # A deferred drag/editor refresh is complete after successful in-place
        # reconciliation. Clear the pending flags exactly as a full reconcile does.
        $script:PopupRowsRefreshPending = $false
        $script:PopupRowsViewportPending = $false
        Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
        Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped ($textUpdated -eq 0) -Deferred $false -AffectedCount $textUpdated -UpdatedInPlaceCount $textUpdated
        return
    }

    $affected = Invoke-PopupRowsReconciliation -ListPanel $listPanel -ContentPanel $contentPanel -ScrollBar $scrollBar -Snapshot $snapshot -Scale $scale -ExistingRows $existingRows -ActiveDrag $activeDrag
    Update-PopupRowsPeripheralUi -StatusLabel $statusLabel
    Write-PopupRowsRenderDiagnostic -Reason $Reason -Before $before -After $snapshot.Fingerprint -EntryCount $snapshot.EntryCount -ActiveDrag $activeDrag -Skipped $false -Deferred $false -AffectedCount $affected -LayoutUpdated $true -RebuiltCount $affected
}
