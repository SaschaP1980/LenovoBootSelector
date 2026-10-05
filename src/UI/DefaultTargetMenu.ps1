function New-DefaultTargetMenu {
    $menu = New-Object LenovoContextMenuStrip
    $menu.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $menu.ForeColor = $script:ColorPrimary
    $menu.Renderer = $script:MenuRenderer
    $menu.Font = New-Object Drawing.Font('Segoe UI', 9.0, [Drawing.FontStyle]::Regular)
    $menu.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $menu.TargetWidth = 260
    Initialize-LenovoMenuAppearance -Menu $menu

    $none = New-Object System.Windows.Forms.ToolStripMenuItem('Kein Standardziel')
    $none.Checked = -not [bool]$script:DefaultGuid
    $none.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
    $none.Add_Click({
        try { Set-DefaultGuid -Guid $null }
        catch { Show-LenovoNoticeDialog -Title 'Standard-Startziel' -Heading 'Das Standard-Startziel konnte nicht gespeichert werden.' -Message 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.' -Kind Error }
    })
    [void]$menu.Items.Add($none)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    foreach ($entry in @(Get-OrderedEntriesForUi)) {
        $item = New-Object System.Windows.Forms.ToolStripMenuItem((Get-EntryDisplayTitle -Entry $entry))
        $item.Tag = $entry.Guid
        $item.Checked = ($script:DefaultGuid -and $entry.Guid -eq $script:DefaultGuid)
        $item.Padding = New-Object System.Windows.Forms.Padding(18, 3, 32, 3)
        $item.Add_Click({
            try { Set-DefaultGuid -Guid ([string]$this.Tag) }
            catch { Show-LenovoNoticeDialog -Title 'Standard-Startziel' -Heading 'Das Standard-Startziel konnte nicht gespeichert werden.' -Message 'Bitte versuche es erneut. Falls das Problem bestehen bleibt, öffne Wartung → Systemfunktionen reparieren.' -Kind Error }
        })
        [void]$menu.Items.Add($item)
    }
    return $menu
}

function Show-DefaultTargetMenu {
    param([System.Windows.Forms.Control]$Owner)
    if (Test-MaintenanceBusy -or (Test-BootTargetDriftDetected)) { return }
    if (-not $Owner -or $script:CurrentEntries.Count -eq 0 -or -not (Test-TaskBrokerReady)) { return }
    [void](Refresh-SystemDefaultState)
    try {
        if ($script:DefaultContextMenu) { $script:DefaultContextMenu.Dispose() }
    } catch { }
    $script:DefaultContextMenu = New-DefaultTargetMenu
    $script:DefaultContextMenu.Show($Owner, (New-Object Drawing.Point(0, $Owner.Height)))
}
