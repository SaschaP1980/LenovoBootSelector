function New-DefaultTargetMenu {
    $menu = New-Object LenovoContextMenuStrip
    # Only this owned dropdown gets a distinct neutral outside edge.
    $menu.Name = 'DefaultTargetContextMenu'
    $menu.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $menu.ForeColor = $script:ColorPrimary
    $menu.Renderer = $script:MenuRenderer
    $menu.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $menu.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $menu.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $menu

    $none = New-Object System.Windows.Forms.ToolStripMenuItem((Get-LocalizedString -Key 'Settings.NoDefaultTarget'))
    $none.Checked = -not [bool]$script:DefaultGuid
    $none.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
    $none.Add_Click({
        try { Start-DefaultTargetChange -Guid $null }
        catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
    })
    [void]$menu.Items.Add($none)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    foreach ($entry in @(Get-OrderedEntriesForUi)) {
        $item = New-Object System.Windows.Forms.ToolStripMenuItem((Get-EntryDisplayTitle -Entry $entry))
        $item.Tag = $entry.Guid
        $item.Checked = ($script:DefaultGuid -and $entry.Guid -eq $script:DefaultGuid)
        $item.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
        $item.Add_Click({
            try { Start-DefaultTargetChange -Guid ([string]$this.Tag) }
            catch { Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Settings.DefaultTarget') -Heading (Get-LocalizedString -Key 'Default.SaveErrorHeading') -Message (Get-LocalizedString -Key 'Default.SaveErrorMessage') -Kind Error }
        })
        [void]$menu.Items.Add($item)
    }
    return $menu
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if ($script:DefaultTargetChangePending -or $script:BootNextPendingGuid -or (Test-MaintenanceBusy) -or (Test-BootTargetDriftDetected)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    try {
        if ($script:DefaultContextMenu) { $script:DefaultContextMenu.Dispose() }
    } catch { }
    $script:DefaultContextMenu = New-DefaultTargetMenu
    $script:DefaultContextMenu.Add_Closed({
        param($sender,$eventArgs)
        if (-not [object]::ReferenceEquals($sender,$script:DefaultContextMenu)) { return }
        $script:DefaultTargetMenuOpening = $false
        # An actual click/focus transfer outside LBS still closes the popup;
        # a selected menu item, local Escape or owner click does not.
        $external = $eventArgs.CloseReason -eq [Windows.Forms.ToolStripDropDownCloseReason]::AppFocusChange -or
                    $eventArgs.CloseReason -eq [Windows.Forms.ToolStripDropDownCloseReason]::AppClicked
        if ($external -and $script:Popup -and -not $script:Popup.IsDisposed -and
            $script:Popup.Visible -and -not $script:Popup.ContainsFocus -and
            -not $script:ExitRequested) {
            $capabilities = Get-CurrentSystemFunctionsCapabilities
            if ([string]$capabilities.State -ne 'Busy') { $script:Popup.Hide() }
        }
    })
    $ownerScreen = [System.Windows.Forms.Screen]::FromControl($Owner)
    $ownerScale = (Get-PopupMonitorDpiScale -Screen $ownerScreen).Factor
    [void](Set-LenovoMenuDpiLayout -Menu $script:DefaultContextMenu -Scale ([double]$ownerScale))
    $script:DefaultTargetMenuOpening = $true
    try {
        $script:DefaultContextMenu.Show($Owner, (New-Object Drawing.Point(0, $Owner.Height)))
    }
    catch {
        $script:DefaultTargetMenuOpening = $false
        throw
    }
    if (-not $script:DefaultContextMenu.Visible) { $script:DefaultTargetMenuOpening = $false }
}
