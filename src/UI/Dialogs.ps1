function Show-LenovoNoticeDialog {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Heading,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Kind = 'Info',
        [string]$SecondaryButtonText,
        [scriptblock]$SecondaryAction
    )

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(470, 245)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    $titleLabel = New-Label -Text $Title -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 420 -Height 24
    $root.Controls.Add($titleLabel)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(434,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyphText = if ($Kind -eq 'Error') { '×' } elseif ($Kind -eq 'Warning') { '!' } else { 'i' }
    $glyphColor = if ($Kind -eq 'Error') { $script:ColorAccent } elseif ($Kind -eq 'Warning') { $script:ColorWarning } else { $script:ColorCyan }
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $headingLabel = New-Label -Text $Heading -Font (New-Object Drawing.Font('Segoe UI', 9.6, [Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 380 -Height 24
    $root.Controls.Add($headingLabel)
    $messageLabel = New-Label -Text $Message -Font (New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 88 -Width 380 -Height 78
    $messageLabel.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($messageLabel)

    if (-not [string]::IsNullOrWhiteSpace($SecondaryButtonText) -and $SecondaryAction) {
        $secondary = New-Object System.Windows.Forms.Button
        $secondary.Text = $SecondaryButtonText
        $secondary.Font = New-Object Drawing.Font('Segoe UI', 8.4, [Drawing.FontStyle]::Regular)
        $secondary.ForeColor = $script:ColorPrimary
        $secondary.BackColor = [Drawing.Color]::FromArgb(34,34,34)
        $secondary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $secondary.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
        $secondary.FlatAppearance.BorderSize = 1
        $secondary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
        $secondary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(38,38,38)
        $secondary.Location = New-Object Drawing.Point(184,190)
        $secondary.Size = New-Object Drawing.Size(146,34)
        $secondary.Cursor = [System.Windows.Forms.Cursors]::Hand
        $secondaryActionLocal = $SecondaryAction
        $dialogLocal = $form
        $secondary.Add_Click({
            param($sender,$eventArgs)
            try {
                $result = & $secondaryActionLocal
                if ($result -ne $false) {
                    $dialogLocal.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $dialogLocal.Close()
                }
            } catch { }
        }.GetNewClosure())
        $root.Controls.Add($secondary)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $ok.ForeColor = [Drawing.Color]::White
    $ok.BackColor = $script:ColorAccent
    $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ok.FlatAppearance.BorderSize = 0
    $ok.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $ok.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $ok.Location = New-Object Drawing.Point(342,190)
    $ok.Size = New-Object Drawing.Size(110,34)
    $ok.Cursor = [System.Windows.Forms.Cursors]::Hand
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $root.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $ok
    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { [void]$form.ShowDialog($owner) } else { [void]$form.ShowDialog() }
    }
    finally { $form.Dispose() }
}

function Show-LenovoSystemFunctionsDialog {
    param([ValidateSet('Setup','Repair','Migrate','Reinitialize','Remove')][string]$Mode)

    $isRemove = ($Mode -eq 'Remove')
    $height = if ($isRemove) { 330 } else { 270 }
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.ClientSize = New-Object Drawing.Size(500, $height)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = [Drawing.Color]::FromArgb(22,22,22)
    $form.Controls.Add($root)

    if ($Mode -eq 'Remove') {
        $titleText = 'Systemfunktionen entfernen'
        $headingText = 'Systemfunktionen wirklich entfernen?'
        $bodyText = "Danach kann Lenovo Boot Selector keine Startziele mehr ändern, bis die Einrichtung erneut durchgeführt wird.`r`n`r`nDas gespeicherte Standard-Startziel wird zurückgesetzt.`r`n`r`nErhalten bleiben deine vorhandenen Startziele, persönlichen App-Einstellungen und die Autostart-Einstellung."
        $primaryText = 'Entfernen'
        $glyphText = '!'
        $glyphColor = $script:ColorWarning
    }
    elseif ($Mode -eq 'Repair') {
        $titleText = 'Systemfunktionen reparieren'
        $headingText = 'Die Systemfunktionen sind bereits eingerichtet.'
        $bodyText = 'Möchtest du sie erneut einrichten und reparieren? Deine Startziele und persönlichen Einstellungen bleiben dabei erhalten.'
        $primaryText = 'Reparieren'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Migrate') {
        $titleText = 'Systemfunktionen reparieren'
        $headingText = 'Die Einrichtung muss aktualisiert werden.'
        $bodyText = 'Eine ältere oder unvollständige Einrichtung wurde gefunden. Repariere sie, damit Startziele wieder zuverlässig geändert werden können.'
        $primaryText = 'Reparieren'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }
    elseif ($Mode -eq 'Reinitialize') {
        $titleText = 'Systemfunktionen neu initialisieren'
        $headingText = 'Neues Startziel erkannt'
        $bodyText = 'Lenovo Boot Selector hat eine Änderung an den verfügbaren Startzielen erkannt. Initialisiere die Systemfunktionen neu, damit das neue Startziel sicher verwendet werden kann. Deine persönlichen Einstellungen bleiben erhalten.'
        $primaryText = 'Neu initialisieren'
        $glyphText = '+'
        $glyphColor = $script:ColorCyan
    }
    else {
        $titleText = 'Systemfunktionen einrichten'
        $headingText = 'Einmalige Einrichtung erforderlich'
        $bodyText = 'Damit Lenovo Boot Selector Startziele ändern kann, ist einmalig eine Windows-Bestätigung erforderlich. Danach kannst du Startziele ohne weitere Bestätigung auswählen.'
        $primaryText = 'Einrichten'
        $glyphText = 'i'
        $glyphColor = $script:ColorCyan
    }

    $title = New-Label -Text $titleText -Font (New-Object Drawing.Font('Segoe UI',10.2,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 450 -Height 24
    $root.Controls.Add($title)
    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18,43)
    $divider.Size = New-Object Drawing.Size(464,1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)
    $glyph = New-Label -Text $glyphText -Font (New-Object Drawing.Font('Segoe UI',15.0,[Drawing.FontStyle]::Bold)) -ForeColor $glyphColor -X 18 -Y 60 -Width 28 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)
    $heading = New-Label -Text $headingText -Font (New-Object Drawing.Font('Segoe UI',9.6,[Drawing.FontStyle]::Bold)) -ForeColor $script:ColorPrimary -X 56 -Y 60 -Width 410 -Height 24
    $root.Controls.Add($heading)
    $bodyHeight = if ($isRemove) { 145 } else { 90 }
    $body = New-Label -Text $bodyText -Font (New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)) -ForeColor $script:ColorSecondary -X 56 -Y 90 -Width 410 -Height $bodyHeight
    $body.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $root.Controls.Add($body)

    $buttonY = $height - 54
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Abbrechen'
    $cancel.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.Location = New-Object Drawing.Point(272,$buttonY)
    $cancel.Size = New-Object Drawing.Size(100,34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $primary = New-Object System.Windows.Forms.Button
    $primary.Text = $primaryText
    $primary.Font = New-Object Drawing.Font('Segoe UI',8.5,[Drawing.FontStyle]::Bold)
    $primary.ForeColor = [Drawing.Color]::White
    $primary.BackColor = $script:ColorAccent
    $primary.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $primary.FlatAppearance.BorderSize = 0
    $primary.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $primary.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $primary.Location = New-Object Drawing.Point(382,$buttonY)
    $primary.Size = New-Object Drawing.Size(100,34)
    $primary.Cursor = [System.Windows.Forms.Cursors]::Hand
    $primary.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($primary)
    $form.AcceptButton = $primary
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally { $form.Dispose() }
}

function Show-LenovoRestartDialog {
    param([Parameter(Mandatory=$true)][string]$TargetName)

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.ClientSize = New-Object Drawing.Size(430, 240)
    $form.KeyPreview = $true

    $root = New-Object System.Windows.Forms.Panel
    $root.Name = 'RestartDialogRoot'
    $root.Location = New-Object Drawing.Point(0, 0)
    $root.Size = New-Object Drawing.Size(430, 240)
    $root.BackColor = [Drawing.Color]::FromArgb(22, 22, 22)
    $form.Controls.Add($root)

    $title = New-Label -Text 'Windows neu starten' -Font (New-Object Drawing.Font('Segoe UI', 10.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 18 -Y 12 -Width 330 -Height 24
    $root.Controls.Add($title)

    $divider = New-Object System.Windows.Forms.Panel
    $divider.Location = New-Object Drawing.Point(18, 43)
    $divider.Size = New-Object Drawing.Size(390, 1)
    $divider.BackColor = $script:ColorAccent
    $root.Controls.Add($divider)

    $glyph = New-Label -Text '!' -Font (New-Object Drawing.Font('Segoe UI', 15.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorWarning -X 18 -Y 58 -Width 26 -Height 34
    $glyph.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $root.Controls.Add($glyph)

    $question = New-Label -Text 'Windows jetzt neu starten?' -Font (New-Object Drawing.Font('Segoe UI', 10.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 58 -Width 340 -Height 24
    $root.Controls.Add($question)

    $targetCaption = New-Label -Text 'NÄCHSTES ZIEL' -Font (New-Object Drawing.Font('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)) `
        -ForeColor ([Drawing.Color]::FromArgb(145,145,145)) -X 54 -Y 92 -Width 330 -Height 18
    $root.Controls.Add($targetCaption)

    $target = New-Label -Text $TargetName -Font (New-Object Drawing.Font('Segoe UI', 9.2, [Drawing.FontStyle]::Bold)) `
        -ForeColor $script:ColorPrimary -X 54 -Y 109 -Width 342 -Height 24
    $target.AutoEllipsis = $true
    $root.Controls.Add($target)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Abbrechen'
    $cancel.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Regular)
    $cancel.ForeColor = $script:ColorPrimary
    $cancel.BackColor = [Drawing.Color]::FromArgb(34,34,34)
    $cancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cancel.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
    $cancel.FlatAppearance.BorderSize = 1
    $cancel.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(46,46,46)
    $cancel.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(28,28,28)
    $cancel.Location = New-Object Drawing.Point(206, 180)
    $cancel.Size = New-Object Drawing.Size(96, 34)
    $cancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
    $root.Controls.Add($cancel)

    $restart = New-Object System.Windows.Forms.Button
    $restart.Text = 'Neu starten'
    $restart.Font = New-Object Drawing.Font('Segoe UI', 8.5, [Drawing.FontStyle]::Bold)
    $restart.ForeColor = [Drawing.Color]::White
    $restart.BackColor = $script:ColorAccent
    $restart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $restart.FlatAppearance.BorderColor = $script:ColorAccent
    $restart.FlatAppearance.BorderSize = 1
    $restart.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(242,59,49)
    $restart.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(185,30,22)
    $restart.Location = New-Object Drawing.Point(312, 180)
    $restart.Size = New-Object Drawing.Size(96, 34)
    $restart.Cursor = [System.Windows.Forms.Cursors]::Hand
    $restart.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $root.Controls.Add($restart)

    $form.AcceptButton = $restart
    $form.CancelButton = $cancel
    $form.Add_KeyDown({ param($sender, $eventArgs) if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $sender.DialogResult = [System.Windows.Forms.DialogResult]::No; $sender.Close() } })

    try {
        $owner = if ($script:Popup -and -not $script:Popup.IsDisposed -and $script:Popup.Visible) { $script:Popup } else { $null }
        if ($owner) { return $form.ShowDialog($owner) }
        return $form.ShowDialog()
    }
    finally {
        $form.Dispose()
    }
}
