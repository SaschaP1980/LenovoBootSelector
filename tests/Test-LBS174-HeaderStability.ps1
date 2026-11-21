#requires -version 5.1
# LBS-174: real WinForms header state and DPI regression in an isolated STA process.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\PopupDpiLayout.ps1')
. (Join-Path $root 'src\UI\RefreshPresentation.ps1')
. (Join-Path $root 'src\UI\PopupComposition.ps1')

$script:checks = 0
function Assert-Lbs174([string]$Name,[bool]$Ok) {
    if (-not $Ok) { throw "LBS174 RED: $Name" }
    $script:checks++
    Write-Host "PASS LBS174 $Name"
}
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,
          [int]$X,[int]$Y,[int]$Width,[int]$Height)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = $Font
    $l.ForeColor = $ForeColor
    $l.AutoSize = $false
    $l.Location = [Drawing.Point]::new($X,$Y)
    $l.Size = [Drawing.Size]::new($Width,$Height)
    return $l
}
function Get-LocalizedString {
    param([string]$Key,$Values)
    if ($Key -eq 'Header.Refreshing') {
        if ($script:TestLanguage -eq 'de') { return 'Aktualisiere Bootziele...' }
        return 'Refreshing boot targets...'
    }
    if ($Key -eq 'Update.Available') {
        if ($script:TestLanguage -eq 'de') { return 'Neue App-Version verfuegbar' }
        return 'New app version available'
    }
    return $Key
}
function Get-CurrentSystemFunctionsCapabilities { return $script:TestCapabilities }
function Get-MaintenanceBusyStatusText { return 'Maintenance in progress' }
function Test-BackgroundRefreshActive {
    param($State)
    return [bool]$State.Active
}
function Show-AvailableUpdateDialog { $script:DialogCalls++ }
function Start-ManageEntriesMode { }
function Test-MaintenanceBusy { return $false }
function Update-PopupRows { param([string]$Reason) }
function Start-BackgroundBootRefresh { param([switch]$RefreshStorage) }
$script:ColorHeader = [Drawing.Color]::FromArgb(0,0,0)
$script:ColorBackground = [Drawing.Color]::FromArgb(28,28,28)
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorSecondary = [Drawing.Color]::FromArgb(180,180,180)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(64,31,29)
$script:BootTypeToolTip = $null
$script:BackgroundRefreshState = [pscustomobject]@{ Active = $false }
$script:TestCapabilities = [pscustomobject]@{ State = 'Ready'; CanRefresh = $true }
$script:UpdateState = [pscustomobject]@{ Status = 'UpToDate'; AvailableManifest = $null }
$script:RefreshButtonHovered = $false
$script:HeaderStatusHovered = $false
$script:DialogCalls = 0
$script:TestLanguage = 'de'

function New-Lbs174Fixture {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ClientSize = [Drawing.Size]::new(390,672)
    Initialize-PopupDpiLayout -Form $form
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Name = 'PopupRoot'
    $panel.Location = [Drawing.Point]::new(0,0)
    $panel.Size = [Drawing.Size]::new(390,672)
    $form.Controls.Add($panel)
    Add-PopupHeaderSection -Root $panel
    Complete-PopupDpiLayout -Form $form -Scale 1.0
    return $form
}
$form = New-Lbs174Fixture
try {
    $title = $script:HeaderTitleLabel
    $status = $script:HeaderStatusLabel
    $refresh = $script:RefreshButton
    $atRest = $title.Location
    Assert-Lbs174 'initial header title created once' ($null -ne $title -and $title.Text -eq 'Lenovo Boot Selector')
    Assert-Lbs174 'status and refresh use distinct native controls' ($status -is [System.Windows.Forms.Button] -and $refresh -is [System.Windows.Forms.Button])
    Assert-Lbs174 'initial idle status empty' ([string]$status.Text -eq '')
    Assert-Lbs174 'initial idle no update action' (-not [bool]$script:HeaderUpdateInteractionEnabled)

    $script:BackgroundRefreshState.Active = $true
    Update-HeaderRefreshStatus
    Assert-Lbs174 'refresh does not move title' ($title.Location -eq $atRest)
    Assert-Lbs174 'refresh keeps same title control' ([object]::ReferenceEquals($title,$script:HeaderTitleLabel))
    Assert-Lbs174 'refresh shows localized status text' ($status.Text -eq 'Aktualisiere Bootziele...')
    Assert-Lbs174 'refresh disables interactive update action' (-not [bool]$script:HeaderUpdateInteractionEnabled)
    $script:BackgroundRefreshState.Active = $false
    Update-HeaderRefreshStatus
    Assert-Lbs174 'completion does not move title' ($title.Location -eq $atRest)
    Assert-Lbs174 'completion clears status text' ([string]$status.Text -eq '')
    Assert-Lbs174 'initial header title is larger than compact 10.2pt design' ([Math]::Abs($title.Font.Size-11.5) -lt .05)
    Assert-Lbs174 'initial status uses readable 9pt font' ([Math]::Abs($status.Font.Size-9.0) -lt .05)
    Assert-Lbs174 'title and reserved status region have positive vertical separation' ($title.Bottom + 2 -le $status.Top)
    Assert-Lbs174 'title clears refresh affordance horizontally' ($title.Right + 8 -le $refresh.Left)
    Assert-Lbs174 'status clears refresh affordance horizontally' ($status.Right + 8 -le $refresh.Left)
    Assert-Lbs174 'status keeps bottom breathing room' ($status.Bottom + 4 -le 60)

    $script:UpdateState.Status = 'UpdateAvailable'
    $script:UpdateState.AvailableManifest = [pscustomobject]@{ Version='9.9.9.9' }
    Update-HeaderRefreshStatus
    Assert-Lbs174 'update notification does not move title' ($title.Location -eq $atRest)
    Assert-Lbs174 'update text is localized in German' ($status.Text -eq 'Neue App-Version verfuegbar')
    Assert-Lbs174 'update notification is interactive' ([bool]$script:HeaderUpdateInteractionEnabled -and $status.TabStop)
    Assert-Lbs174 'update notification has hand cursor' ($status.Cursor -eq [System.Windows.Forms.Cursors]::Hand)
    $script:BackgroundRefreshState.Active = $true
    Update-HeaderRefreshStatus
    Assert-Lbs174 'refresh takes precedence over available update' ($status.Text -eq 'Aktualisiere Bootziele...' -and -not $script:HeaderUpdateInteractionEnabled)
    Assert-Lbs174 'refresh/update precedence does not move title' ($title.Location -eq $atRest)

    $script:TestCapabilities.State = 'Busy'
    Update-HeaderRefreshStatus
    Assert-Lbs174 'maintenance Busy keeps title fixed' ($title.Location -eq $atRest)
    Assert-Lbs174 'maintenance Busy shows maintenance status' ($status.Text -eq 'Maintenance in progress')
    Assert-Lbs174 'maintenance Busy update action disabled' (-not [bool]$script:HeaderUpdateInteractionEnabled)
    $script:TestCapabilities.State = 'Ready'
    $script:TestLanguage = 'en'
    Update-HeaderRefreshStatus
    Assert-Lbs174 'English refresh text is available' ($status.Text -eq 'Refreshing boot targets...')
    Assert-Lbs174 'changing language does not move title' ($title.Location -eq $atRest)
    $script:BackgroundRefreshState.Active = $false
    Update-HeaderRefreshStatus
    Assert-Lbs174 'English available-update text is retained' ($status.Text -eq 'New app version available')
    Assert-Lbs174 'update notification restores action after refresh' ([bool]$script:HeaderUpdateInteractionEnabled)

    $oldSize = [single]$title.Font.Size
    $oldStatusSize = [single]$status.Font.Size
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 2.5)
    $at250 = $title.Location
    Assert-Lbs174 '250 percent title X scales once' ($at250.X -eq 40)
    Assert-Lbs174 '250 percent title Y scales once' ($at250.Y -eq [int][Math]::Round($atRest.Y*2.5))
    Assert-Lbs174 '250 percent status/title retain point font sizes' ([Math]::Abs($title.Font.Size-$oldSize) -lt .01 -and [Math]::Abs($status.Font.Size-$oldStatusSize) -lt .01)
    Assert-Lbs174 '250 percent title and status have physical gap' ($title.Bottom + 5 -le $status.Top)
    Assert-Lbs174 '250 percent title avoids refresh icon' ($title.Right + 15 -le $refresh.Left)
    Assert-Lbs174 '250 percent status avoids refresh icon' ($status.Right + 15 -le $refresh.Left)
    Assert-Lbs174 '250 percent title font fits its label box' ($title.Font.GetHeight([single]240) -le $title.Height)
    Assert-Lbs174 '250 percent status font fits its button box' ($status.Font.GetHeight([single]240) -le $status.Height)

    $script:BackgroundRefreshState.Active = $true
    Update-HeaderRefreshStatus
    Assert-Lbs174 '250 percent refresh leaves DPI-scaled title intact' ($title.Location -eq $at250)
    $script:TestCapabilities.State = 'Busy'
    Update-HeaderRefreshStatus
    Assert-Lbs174 '250 percent Busy leaves DPI-scaled title intact' ($title.Location -eq $at250)
    $script:TestCapabilities.State = 'Ready'
    $script:BackgroundRefreshState.Active = $false
    $script:UpdateState.Status = 'UpToDate'
    $script:UpdateState.AvailableManifest = $null
    Update-HeaderRefreshStatus
    Assert-Lbs174 '250 percent idle leaves DPI-scaled title intact' ($title.Location -eq $at250)
    [void](Set-PopupDpiLayoutScale -Form $form -Scale 1.0)
    Update-HeaderRefreshStatus
    Assert-Lbs174 'restoring 100 percent retains title geometry' ($title.Location -eq $atRest)
    Assert-Lbs174 'all transitions preserve title handle identity' ([object]::ReferenceEquals($title,$script:HeaderTitleLabel))
}
finally { $form.Dispose() }

$form2 = New-Lbs174Fixture
try {
    Assert-Lbs174 'fresh popup reopens with stable header position' ($script:HeaderTitleLabel.Location -eq $atRest)
    Assert-Lbs174 'fresh popup starts with expected typography' ([Math]::Abs($script:HeaderTitleLabel.Font.Size-11.5) -lt .05)
}
finally { $form2.Dispose() }

Write-Host "LBS174 HEADER TOTAL $script:checks/44"
if ($script:checks -ne 44) { throw "LBS174 header count mismatch: $script:checks" }
