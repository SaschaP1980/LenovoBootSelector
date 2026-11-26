#requires -version 5.1
# LBS-202 UX01-V13: exercise real WinForms notice controls and actual update-available
# presentation with a stub update action. No downloads, process handoff or UEFI.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\UI\Dialogs.ps1')
. (Join-Path $root 'src\UI\UpdatePresentation.ps1')

$script:ColorPrimary = [Drawing.Color]::FromArgb(235,235,235)
$script:ColorSecondary = [Drawing.Color]::FromArgb(175,175,175)
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorWarning = [Drawing.Color]::FromArgb(236,191,68)
$script:ColorCyan = [Drawing.Color]::FromArgb(66,203,213)
$script:Popup = $null
$script:checks = 0
$script:failures = New-Object 'System.Collections.Generic.List[string]'
$script:UpdateStarts = 0
$script:OtherActions = 0
$script:CaseScale = 1.0
$global:Lbs202CaseMode = 'safe'
$global:Lbs202Captured = $null
$global:Lbs202CapturedError = $null

function Assert-Lbs202([string]$Name,[bool]$Pass) {
    $script:checks++
    if ($Pass) { Write-Host "PASS LBS202 $Name" }
    else { $script:failures.Add($Name); Write-Host "FAIL LBS202 $Name" }
}
function Get-LocalizedString {
    param([string]$Key,[System.Collections.IDictionary]$Values)
    Get-LocalizedStringCore -Key $Key -Locale $script:CaseLocale -Values $Values
}
function New-Label {
    param([string]$Text,[Drawing.Font]$Font,[Drawing.Color]$ForeColor,
        [int]$X,[int]$Y,[int]$Width,[int]$Height)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.Bounds = [Drawing.Rectangle]::new($X,$Y,$Width,$Height)
    return $label
}
function Start-ManualAppUpdate { $script:UpdateStarts++; return $true }
function Get-Lbs202Snapshot([System.Windows.Forms.Form]$Form) {
    $buttons = @($Form.Controls.Find('DialogActions',$true)[0].Controls |
        Where-Object { $_ -is [System.Windows.Forms.Button] } | Sort-Object Left)
    $left = if ($buttons.Count -ge 1) { $buttons[0] } else { $null }
    $right = if ($buttons.Count -ge 2) { $buttons[1] } else { $left }
    $accept = $Form.AcceptButton
    $cancel = $Form.CancelButton
    $scale = [double]$script:CaseScale
    $leftBounds = if ($left) { $left.Bounds } else { [Drawing.Rectangle]::Empty }
    $rightBounds = if ($right) { $right.Bounds } else { [Drawing.Rectangle]::Empty }
    $textFit = $false
    if ($right) {
        $bmp = New-Object Drawing.Bitmap(8,8)
        try {
            $dpi = [single](96*$scale)
            $bmp.SetResolution($dpi,$dpi)
            $g = [Drawing.Graphics]::FromImage($bmp)
            try { $textFit = ($g.MeasureString($right.Text,$right.Font).Width -le ($right.Width-8*$scale)) }
            finally { $g.Dispose() }
        } finally { $bmp.Dispose() }
    }
    return [pscustomobject]@{
        Count = $buttons.Count
        LeftText = if ($left) { [string]$left.Text } else { '' }
        RightText = if ($right) { [string]$right.Text } else { '' }
        LeftBounds = $leftBounds
        RightBounds = $rightBounds
        LeftColor = if ($left) { $left.BackColor.ToArgb() } else { 0 }
        RightColor = if ($right) { $right.BackColor.ToArgb() } else { 0 }
        LeftBorder = if ($left) { $left.FlatAppearance.BorderSize } else { -1 }
        RightBorder = if ($right) { $right.FlatAppearance.BorderSize } else { -1 }
        AcceptIsLeft = ($left -and [object]::ReferenceEquals($accept,$left))
        CancelIsLeft = ($left -and [object]::ReferenceEquals($cancel,$left))
        LeftFocused = ($left -and $left.ContainsFocus)
        LeftTabIndex = if ($left) { $left.TabIndex } else { -1 }
        RightTabIndex = if ($right) { $right.TabIndex } else { -1 }
        RightTextFits = $textFit
        Heading = [string]$Form.Controls.Find('DialogHeading',$true)[0].Text
        Message = [string]$Form.Controls.Find('DialogMessage',$true)[0].Text
        AcceptText = if ($accept) { [string]$accept.Text } else { '' }
    }
}
# Inject only DPI setup/inspection of the *real* modal. Form and buttons
# are constructed by src/UI/Dialogs.ps1 without copying production logic.
function Prepare-LenovoDialogDpiLayout {
    param([System.Windows.Forms.Form]$Form,$Owner,[string]$Role)
    $scale = [double]$script:CaseScale
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    Set-LenovoDialogDpiLayout -Form $Form -Scale $scale -WorkingArea $screen.WorkingArea
    $f = $Form
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 50
    $timer.Add_Tick({
        $timer.Stop()
        try {
            $global:Lbs202Captured = Get-Lbs202Snapshot $f
            $buttons = @($f.Controls.Find('DialogActions',$true)[0].Controls |
                Where-Object { $_ -is [System.Windows.Forms.Button] } | Sort-Object Left)
            if ($global:Lbs202CaseMode -eq 'safe') {
                $f.AcceptButton.PerformClick()
            }
            elseif ($global:Lbs202CaseMode -eq 'cancel') {
                $f.CancelButton.PerformClick()
            }
            elseif ($global:Lbs202CaseMode -eq 'install') {
                $buttons[$buttons.Count-1].PerformClick()
            }
            elseif ($global:Lbs202CaseMode -eq 'other-secondary') {
                $buttons[0].PerformClick()
            }
        } catch {
            $global:Lbs202CapturedError = [string]$_.Exception
        } finally {
            if ($f.Visible) { $f.Close() }
            $timer.Dispose()
        }
    }.GetNewClosure())
    $timer.Start()
}
$expectedCases = 0
foreach ($locale in @('en-US','de-DE')) {
    $script:CaseLocale = $locale
    $later = if ($locale -eq 'de-DE') { 'Später' } else { 'Later' }
    $install = if ($locale -eq 'de-DE') { 'Jetzt aktualisieren' } else { 'Update now' }
    foreach ($scale in @(1.0,2.5)) {
        $script:CaseScale = $scale
        $tag = "$locale/$scale"
        $script:UpdateState = [pscustomobject]@{
            Status = 'UpdateAvailable'
            AvailableManifest = [pscustomobject]@{ Version='9.8.7.6' }
        }
        $script:UpdateStarts = 0
        $global:Lbs202CaseMode = 'safe'
        $global:Lbs202Captured = $null
        $global:Lbs202CapturedError = $null
        $shown = Show-AvailableUpdateDialog
        $s = $global:Lbs202Captured
        if (-not $s -or $global:Lbs202CapturedError) { Write-Host ("LBS202_HARNESS_DIAGNOSTIC locale={0} scale={1} error={2} captured={3}" -f $locale,$scale,$global:Lbs202CapturedError,([bool]$s)) }
        Assert-Lbs202 "$tag modal opened without test harness error" ($shown -and $null -ne $s -and -not $global:Lbs202CapturedError)
        if (-not $s) { continue }
        Assert-Lbs202 "$tag two actions remain visible" ($s.Count -eq 2)
        Assert-Lbs202 "$tag safe left action has explicit Later label" ($s.LeftText -eq $later)
        Assert-Lbs202 "$tag update action is on right with localized verb" ($s.RightText -eq $install)
        Assert-Lbs202 "$tag right update is the red visual primary" ($s.RightColor -eq $script:ColorAccent.ToArgb() -and $s.RightBorder -eq 0)
        Assert-Lbs202 "$tag left safe action is outlined and neutral" ($s.LeftColor -eq ([Drawing.Color]::FromArgb(34,34,34)).ToArgb() -and $s.LeftBorder -eq 1)
        Assert-Lbs202 "$tag AcceptButton is noninstalling Later" ($s.AcceptIsLeft)
        Assert-Lbs202 "$tag CancelButton is noninstalling Later" ($s.CancelIsLeft)
        Assert-Lbs202 "$tag default keyboard focus is safe Later" ($s.LeftFocused -and $s.LeftTabIndex -lt $s.RightTabIndex)
        Assert-Lbs202 "$tag right/left positions are DPI scaled and do not overlap" (
            $s.LeftBounds.Width -ge [int][Math]::Round(110*$scale) -and
            $s.RightBounds.Width -ge [int][Math]::Round(110*$scale) -and
            $s.LeftBounds.Height -eq [int][Math]::Round(34*$scale) -and
            $s.RightBounds.Height -eq [int][Math]::Round(34*$scale) -and
            $s.LeftBounds.Right -le $s.RightBounds.Left)
        Assert-Lbs202 "$tag update action label fits at DPI scale" $s.RightTextFits
        Assert-Lbs202 "$tag notice retains version and tray update instructions" (
            $s.Heading.Contains('9.8.7.6') -and
            ($s.Message -match '(Maintenance|Wartung)'))
        Assert-Lbs202 "$tag Enter default never calls installer" ($script:UpdateStarts -eq 0)

        $global:Lbs202CaseMode = 'cancel'
        $global:Lbs202CapturedError = $null
        [void](Show-AvailableUpdateDialog)
        Assert-Lbs202 "$tag Escape/Cancel action never calls installer" (
            $script:UpdateStarts -eq 0 -and -not $global:Lbs202CapturedError)

        $global:Lbs202CaseMode = 'install'
        $global:Lbs202CapturedError = $null
        [void](Show-AvailableUpdateDialog)
        Assert-Lbs202 "$tag deliberate right update starts exactly once" (
            $script:UpdateStarts -eq 1 -and -not $global:Lbs202CapturedError)

        $global:Lbs202CaseMode = 'safe'
        $global:Lbs202CapturedError = $null
        $global:Lbs202Captured = $null
        Show-LenovoNoticeDialog -Title (Get-LocalizedString -Key 'Update.SuccessTitle') -Heading 'Updated' -Message 'Update completed.' -Kind Info
        $legacy=$global:Lbs202Captured
        Assert-Lbs202 "$tag success notice remains a single red OK action" (
            $legacy -and $legacy.Count -eq 1 -and
            $legacy.RightText -eq 'OK' -and $legacy.RightColor -eq $script:ColorAccent.ToArgb() -and
            $script:UpdateStarts -eq 1 -and -not $global:Lbs202CapturedError)
        $expectedCases+=16
    }
}
# Legacy two-action notice semantics must remain unchanged: outlined
# secondary left, red OK right, and no automatic secondary callback.
foreach ($locale in @('en-US','de-DE')) {
    $script:CaseLocale = $locale
    $script:CaseScale = 1.0
    $global:Lbs202CaseMode = 'safe'
    $global:Lbs202Captured=$null
    $global:Lbs202CapturedError=$null
    $previous = $script:OtherActions
    Show-LenovoNoticeDialog -Title 'Other' -Heading 'Other action' -Message 'Safe text' -SecondaryButtonText 'Copy' -SecondaryAction { $script:OtherActions++ }
    $other=$global:Lbs202Captured
    if (-not $other -or $global:Lbs202CapturedError) { Write-Host ("LBS202_HARNESS_DIAGNOSTIC legacy={0} error={1}" -f $locale,$global:Lbs202CapturedError) }
    Assert-Lbs202 "$locale legacy secondary remains outlined left with red OK right" (
        $other -and $other.Count -eq 2 -and $other.LeftText -eq 'Copy' -and
        $other.RightText -eq 'OK' -and $other.RightColor -eq $script:ColorAccent.ToArgb() -and
        $other.LeftColor -eq ([Drawing.Color]::FromArgb(34,34,34)).ToArgb())
    Assert-Lbs202 "$locale generic default OK does not run secondary callback" (
        $script:OtherActions -eq $previous -and -not $global:Lbs202CapturedError)
    $expectedCases+=2
}
Write-Host "LBS202 UPDATE NOTICE TOTAL $script:checks/$expectedCases"
Write-Host ("LBS202 UPDATE NOTICE RESULT={0}" -f $(if($script:failures.Count -eq 0){'PASS'}else{'RED'}))
if ($script:checks -ne $expectedCases -or $script:failures.Count -gt 0) {
    throw ('LBS202 NATIVE RED: ' + ($script:failures -join '; '))
}
