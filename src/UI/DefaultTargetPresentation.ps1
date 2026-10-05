function Get-DefaultEntryTitle {
    if (-not $script:DefaultGuid) { return 'Kein Standardziel' }
    $entry = Get-EntryByGuid $script:DefaultGuid
    if ($entry) { return (Get-EntryDisplayTitle -Entry $entry) }
    return 'Nicht verfügbares Startziel'
}

function Update-DefaultUi {
    if ($script:DefaultButton -and -not $script:DefaultButton.IsDisposed) {
        $meta = Get-TaskBrokerMetadata
        $schemaReady = ($meta -and ($script:SupportedTaskBrokerVersions -contains [string]$meta.version))
        $sessionReady = ($script:TaskBrokerReadyCached -eq $true)
        $enabled = ($schemaReady -and $sessionReady -and -not (Test-BootTargetDriftDetected) -and $script:CurrentEntries.Count -gt 0)
        $script:DefaultButton.Enabled = $enabled
        if ($script:DefaultValueLabel -and -not $script:DefaultValueLabel.IsDisposed) {
            $script:DefaultValueLabel.Text = Get-DefaultEntryTitle
            $script:DefaultValueLabel.ForeColor = if ($enabled) { $script:ColorPrimary } else { [Drawing.Color]::FromArgb(110,110,110) }
        }
        foreach ($child in $script:DefaultButton.Controls) {
            try { $child.Enabled = $enabled } catch { }
        }
    }
}
