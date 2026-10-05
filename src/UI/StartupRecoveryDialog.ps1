function Show-FatalMessage([string]$Message, [bool]$AllowRestart = $true) {
    $diagnosticSaved = $false
    $diagDir = $null
    $diagPath = $null
    try {
        $diagDir = Join-Path $env:LOCALAPPDATA 'Lenovo Boot Menu Tray\Diagnostics'
        if (-not (Test-Path -LiteralPath $diagDir)) { [void](New-Item -ItemType Directory -Path $diagDir -Force) }
        $diagPath = Join-Path $diagDir ("RuntimeError-{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
        $diagText = "Lenovo Boot Selector runtime error`r`nTime: $([datetime]::Now.ToString('o'))`r`n`r`n$Message"
        [System.IO.File]::WriteAllText($diagPath, $diagText, [System.Text.Encoding]::UTF8)
        $diagnosticSaved = $true
    } catch { }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $isAlreadyRunning = ($Message -eq 'Lenovo Boot Selector läuft bereits.')
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Lenovo Boot Selector'
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.ShowInTaskbar = $false
        $form.ShowIcon = $true
        $form.TopMost = $true
        $form.ClientSize = New-Object System.Drawing.Size(560, 242)
        $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
        $form.ForeColor = [System.Drawing.Color]::FromArgb(238, 238, 238)
        $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
        $form.Tag = 'close'

        $iconPath = Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'
        if (Test-Path -LiteralPath $iconPath) {
            try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch { }
        }

        $accent = New-Object System.Windows.Forms.Panel
        $accent.Location = New-Object System.Drawing.Point(0, 0)
        $accent.Size = New-Object System.Drawing.Size(5, 242)
        $accent.BackColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $form.Controls.Add($accent)

        $badge = New-Object System.Windows.Forms.Label
        $badge.Text = '!'
        $badge.Location = New-Object System.Drawing.Point(24, 28)
        $badge.Size = New-Object System.Drawing.Size(38, 38)
        $badge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $badge.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18.0, [System.Drawing.FontStyle]::Bold)
        $badge.ForeColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $badge.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $form.Controls.Add($badge)

        $title = New-Object System.Windows.Forms.Label
        $title.Location = New-Object System.Drawing.Point(78, 24)
        $title.Size = New-Object System.Drawing.Size(452, 28)
        $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11.0, [System.Drawing.FontStyle]::Bold)
        $title.ForeColor = [System.Drawing.Color]::White
        $title.Text = $(if ($isAlreadyRunning) { 'Lenovo Boot Selector läuft bereits' } else { 'Lenovo Boot Selector konnte nicht gestartet werden' })
        $form.Controls.Add($title)

        $body = New-Object System.Windows.Forms.Label
        $body.Location = New-Object System.Drawing.Point(78, 60)
        $body.Size = New-Object System.Drawing.Size(452, 70)
        $body.Font = New-Object System.Drawing.Font('Segoe UI', 9.0, [System.Drawing.FontStyle]::Regular)
        $body.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
        if ($isAlreadyRunning) {
            $body.Text = 'Die App ist bereits geöffnet. Schließe dieses Fenster und verwende das vorhandene Tray-Symbol.'
        }
        elseif ($diagnosticSaved) {
            $body.Text = "Beim Start ist ein Problem aufgetreten.`r`nEine Diagnose wurde gespeichert. Du kannst die App erneut starten oder die Diagnose öffnen."
        }
        else {
            $body.Text = "Beim Start ist ein Problem aufgetreten.`r`nDie Diagnose konnte nicht gespeichert werden. Du kannst die App erneut starten."
        }
        $form.Controls.Add($body)

        $diagLabel = New-Object System.Windows.Forms.Label
        $diagLabel.Location = New-Object System.Drawing.Point(78, 136)
        $diagLabel.Size = New-Object System.Drawing.Size(452, 24)
        $diagLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8.0, [System.Drawing.FontStyle]::Regular)
        $diagLabel.ForeColor = [System.Drawing.Color]::FromArgb(145, 145, 145)
        if ($diagnosticSaved -and $diagPath) {
            $diagLabel.Text = ('Diagnose: {0}' -f (Split-Path -Leaf $diagPath))
        }
        elseif (-not $isAlreadyRunning) {
            $diagLabel.Text = 'Keine Diagnose-Datei verfügbar.'
        }
        $form.Controls.Add($diagLabel)

        $buttonBar = New-Object System.Windows.Forms.Panel
        $buttonBar.Location = New-Object System.Drawing.Point(5, 178)
        $buttonBar.Size = New-Object System.Drawing.Size(555, 64)
        $buttonBar.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 31)
        $form.Controls.Add($buttonBar)

        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = 'Schließen'
        $closeButton.Location = New-Object System.Drawing.Point(433, 16)
        $closeButton.Size = New-Object System.Drawing.Size(100, 32)
        $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $closeButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $closeButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $closeButton.ForeColor = [System.Drawing.Color]::White
        $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $closeButton.Add_Click({ $form.Tag = 'close'; $form.Close() })
        $buttonBar.Controls.Add($closeButton)
        $form.CancelButton = $closeButton

        $diagnosticButton = New-Object System.Windows.Forms.Button
        $diagnosticButton.Text = 'Diagnose öffnen'
        $diagnosticButton.Location = New-Object System.Drawing.Point(279, 16)
        $diagnosticButton.Size = New-Object System.Drawing.Size(142, 32)
        $diagnosticButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $diagnosticButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(86, 86, 86)
        $diagnosticButton.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $diagnosticButton.ForeColor = [System.Drawing.Color]::White
        $diagnosticButton.Font = New-Object System.Drawing.Font('Segoe UI', 9.0)
        $diagnosticButton.Enabled = [bool]($diagnosticSaved -and $diagDir)
        $diagnosticButton.Add_Click({
            try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $diagDir) | Out-Null } catch { }
        })
        $buttonBar.Controls.Add($diagnosticButton)

        $retryButton = New-Object System.Windows.Forms.Button
        $retryButton.Text = 'Erneut starten'
        $retryButton.Location = New-Object System.Drawing.Point(125, 16)
        $retryButton.Size = New-Object System.Drawing.Size(142, 32)
        $retryButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $retryButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(225, 37, 27)
        $retryButton.BackColor = [System.Drawing.Color]::FromArgb(64, 31, 29)
        $retryButton.ForeColor = [System.Drawing.Color]::White
        $retryButton.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.0, [System.Drawing.FontStyle]::Bold)
        $launcherAvailable = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs')
        $retryButton.Enabled = [bool]($AllowRestart -and -not $isAlreadyRunning -and $launcherAvailable)
        $retryButton.Add_Click({ $form.Tag = 'retry'; $form.Close() })
        $buttonBar.Controls.Add($retryButton)

        if ($retryButton.Enabled) { $form.AcceptButton = $retryButton } else { $form.AcceptButton = $closeButton }
        [void]$form.ShowDialog()
        $action = [string]$form.Tag
        $form.Dispose()
        return $action
    }
    catch {
        # Fallback remains owner-bound and taskbar-silent. If WinForms itself is
        # unavailable, fall back to stderr without creating a visible console.
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $owner = New-Object System.Windows.Forms.Form
            $owner.ShowInTaskbar = $false
            $owner.Opacity = 0
            $owner.Size = New-Object System.Drawing.Size(1, 1)
            $owner.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $owner.Location = New-Object System.Drawing.Point(-32000, -32000)
            $owner.Show()
            [System.Windows.Forms.MessageBox]::Show(
                $owner,
                'Lenovo Boot Selector konnte nicht gestartet werden.',
                'Lenovo Boot Selector',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            $owner.Close()
            $owner.Dispose()
        }
        catch {
            Write-Error $Message
        }
        return 'close'
    }
}
