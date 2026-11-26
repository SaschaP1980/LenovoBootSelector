#requires -version 5.1
# LBS-197 UX01-V8: native focus, keyboard navigation and guarded selection.
# Real WinForms controls, synthetic DPI geometry; no firmware or persisted writes.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $PSScriptRoot 'Import-LenovoInteractionTestTypes.ps1')
. (Join-Path $root 'src\Core\BootNextSelectionState.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
$script:checks = 0
function Assert-Lbs197([string]$Label,[bool]$Condition) {
    if (-not $Condition) { throw "LBS197 RED: $Label" }
    $script:checks++
    Write-Host "PASS LBS197 $Label"
}
function Get-LocalizedString { param([string]$Key,$Values) return $Key }
function Get-EntryAlias { param([string]$Guid,[switch]$UseManageDraft) return '' }
function Get-EntryDisplayTitle { param($Entry,[switch]$UseManageDraft) return [string]$Entry.Title }
function Get-EntryByGuid { param([string]$Guid) return @($script:TestEntries | Where-Object { $_.Guid -eq $Guid })[0] }
function Test-ManageEntryHidden { param([string]$Guid) return $false }
function Get-CurrentSystemFunctionsCapabilities { return [pscustomobject]@{ CanManageEntries=$true;CanSetBootNext=$true } }
function Show-LenovoNoticeDialog { throw 'No notice expected during successful keyboard test.' }
function Save-AppSettings { $script:WriteCalls++ }
function Start-BootNextSelection { param([string]$Guid) $script:BootNextCalls++; $script:LastBootNextGuid=$Guid }
$script:ColorRow = [Drawing.Color]::FromArgb(31,31,31)
$script:ColorSelectedRow = [Drawing.Color]::FromArgb(64,31,29)
$script:ColorHover = [Drawing.Color]::FromArgb(42,42,42)
$script:ColorAccent = [Drawing.Color]::FromArgb(225,37,27)
$script:ColorPrimary = [Drawing.Color]::FromArgb(235,235,235)
$script:ColorSecondary = [Drawing.Color]::FromArgb(175,175,175)
$script:ColorWarning = [Drawing.Color]::FromArgb(241,174,63)
$script:IsManageEntriesMode = $false
$script:BootNextPendingGuid = ''
$script:SelectedGuid = ''
$script:BootTypeToolTip = $null
$script:WriteCalls = 0
$script:BootNextCalls = 0
$script:LastBootNextGuid = ''
$script:RestartCalls = 0

function Invoke-Lbs197Key($Row,[System.Windows.Forms.Keys]$Key) {
    $flags = [Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
    $down = $Row.GetType().GetMethod('OnKeyDown',$flags)
    $up = $Row.GetType().GetMethod('OnKeyUp',$flags)
    if (-not $down -or -not $up) { throw 'Native key dispatch method unavailable.' }
    $args = [System.Windows.Forms.KeyEventArgs]::new($Key)
    [void]$down.Invoke($Row,[object[]]@($args))
    [void]$up.Invoke($Row,[object[]]@($args))
    [System.Windows.Forms.Application]::DoEvents()
}
# Paint the actual focused native Panel into an isolated GDI bitmap.
# Sample inside the outline and the untouched interior (away from child labels).
function Get-Lbs197RowPaintPixels($Row) {
    $bmp = [Drawing.Bitmap]::new([int]$Row.ClientSize.Width,[int]$Row.ClientSize.Height)
    $graphics = [Drawing.Graphics]::FromImage($bmp)
    try {
        $graphics.Clear($Row.BackColor)
        $flags = [Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        $paint = $Row.GetType().GetMethod('OnPaint',$flags)
        if (-not $paint) { throw 'Native row OnPaint unavailable.' }
        $args = [System.Windows.Forms.PaintEventArgs]::new($graphics,$Row.ClientRectangle)
        [void]$paint.Invoke($Row,[object[]]@($args))
        return [pscustomobject]@{
            Border = $bmp.GetPixel(3,[int]($Row.Height/2))
            Interior = $bmp.GetPixel(10,[int]($Row.Height-10))
        }
    }
    finally {
        $graphics.Dispose()
        $bmp.Dispose()
    }
}
Assert-Lbs197 'normal WinForms keyboard row initializer exists' (
    $null -ne (Get-Command Initialize-NormalBootKeyboardRow -CommandType Function -ErrorAction SilentlyContinue))
$ui = [IO.File]::ReadAllText((Join-Path $root 'src\UI\BootEntryList.ps1'))
Assert-Lbs197 'keyed reconciler assigns visual TabIndex order' ($ui.Contains('$row.TabIndex'))
Assert-Lbs197 'keyed reconciler preserves focused GUID only' (
    $ui.Contains('Get-NormalBootFocusedGuid') -and $ui.Contains('Restore-NormalBootFocusedGuid'))

foreach ($scale in @(2.5,1.0)) {
    $script:TestEntries = @(0..5 | ForEach-Object {
        $idx = $_
        [pscustomobject]@{
            Guid=('boot-{0}' -f $idx); Title=('Boot target {0}' -f $idx)
            Subtitle=('Description {0}' -f $idx); RawDescription='USB HDD'
            Symbol='●'; Accent=[Drawing.Color]::Orange; TypeTooltip=''
        }
    })
    $form = New-Object System.Windows.Forms.Form
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location = [Drawing.Point]::new(10,10)
    $form.ClientSize = [Drawing.Size]::new([int](390*$scale),[int](210*$scale))
    $list = New-Object System.Windows.Forms.Panel
    $list.Name = 'EntryList'
    $list.Location = [Drawing.Point]::Empty
    $list.Size = [Drawing.Size]::new([int](390*$scale),[int](130*$scale))
    $list.TabStop = $true
    $content = New-Object System.Windows.Forms.Panel
    $content.Name = 'EntryContent'
    $content.Location = [Drawing.Point]::Empty
    $content.Size = [Drawing.Size]::new([int](390*$scale),[int](450*$scale))
    $scroll = New-Object System.Windows.Forms.VScrollBar
    $scroll.Name = 'EntryScroll'
    $scroll.Location = [Drawing.Point]::new([int](382*$scale),0)
    $scroll.Size = [Drawing.Size]::new([int](8*$scale),$list.Height)
    $scroll.Minimum = 0
    $scroll.Maximum = [int](6*64*$scale)
    $scroll.LargeChange = 1
    $scroll.SmallChange = [int](64*$scale)
    $scroll.Visible = $true
    $scroll.Add_ValueChanged({ $content.Top = -$scroll.Value })
    $list.Controls.Add($content)
    $list.Controls.Add($scroll)
    $form.Controls.Add($list)
    $other = New-Object System.Windows.Forms.Button
    $other.Text = 'Other action'
    $other.Location = [Drawing.Point]::new(0,[int](140*$scale))
    $other.Size = [Drawing.Size]::new(90,25)
    $other.TabStop = $true
    $form.Controls.Add($other)
    $rows = @()
    $handlers = New-BootEntryInteractionHandlers
    for ($i=0;$i -lt $script:TestEntries.Count;$i++) {
        $y = [int]($i*64*$scale)
        $r = New-BootEntryRow -Entry $script:TestEntries[$i] -Y $y -BaseRowHeight ([int](60*$scale)) -Handlers $handlers
        $r.Row.TabIndex = $i
        $content.Controls.Add($r.Row)
        $rows += $r.Row
    }
    $script:Popup = $form
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Assert-Lbs197 "$scale all normal rows are native selectable panels" (
            @($rows | Where-Object { $_ -isnot [System.Windows.Forms.Panel] -or -not $_.TabStop }).Count -eq 0)
        Assert-Lbs197 "$scale keyboard row exposes action role and title name" (
            $rows[0].AccessibleRole -eq [System.Windows.Forms.AccessibleRole]::PushButton -and
            $rows[0].AccessibleName -eq $script:TestEntries[0].Title)
        Assert-Lbs197 "$scale normal row preserves enabled pointer hit surface" ($rows[0].Enabled -and $rows[0].Cursor -eq [System.Windows.Forms.Cursors]::Hand)
        $flags = [Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic
        $method = $rows[0].GetType().GetMethod('IsInputKey',$flags)
        Assert-Lbs197 "$scale navigation keys are real WinForms input keys" (
            [bool]$method.Invoke($rows[0],[object[]]@([System.Windows.Forms.Keys]::Down)) -and
            [bool]$method.Invoke($rows[0],[object[]]@([System.Windows.Forms.Keys]::Home)) -and
            [bool]$method.Invoke($rows[0],[object[]]@([System.Windows.Forms.Keys]::Return)))
        Assert-Lbs197 "$scale starting row can take real keyboard focus" ($rows[0].Focus() -and $rows[0].Focused)
        $focusPixels = Get-Lbs197RowPaintPixels $rows[0]
        Assert-Lbs197 "$scale focused outline is cool-neutral and not red" (
            $focusPixels.Border.R -ge 120 -and
            $focusPixels.Border.B -gt ($focusPixels.Border.R + 12) -and
            $focusPixels.Border.G -ge $focusPixels.Border.R)
        Assert-Lbs197 "$scale focused row has subtle tint without modifying base background" (
            $focusPixels.Interior.R -gt $rows[0].BackColor.R -and
            $focusPixels.Interior.B -gt $rows[0].BackColor.B -and
            ($focusPixels.Interior.R - $rows[0].BackColor.R) -lt 20 -and
            $rows[0].BackColor.ToArgb() -eq $script:ColorRow.ToArgb())
        Invoke-Lbs197Key $rows[0] ([System.Windows.Forms.Keys]::Down)
        Assert-Lbs197 "$scale Down focuses next GUID without selection" (
            $rows[1].Focused -and $script:BootNextCalls -eq 0 -and $script:WriteCalls -eq 0 -and $script:RestartCalls -eq 0)
        Invoke-Lbs197Key $rows[1] ([System.Windows.Forms.Keys]::Up)
        Assert-Lbs197 "$scale Up focuses previous GUID" ($rows[0].Focused)
        Invoke-Lbs197Key $rows[0] ([System.Windows.Forms.Keys]::Up)
        Assert-Lbs197 "$scale first-row Up clamps and keeps focus" ($rows[0].Focused)
        Invoke-Lbs197Key $rows[0] ([System.Windows.Forms.Keys]::End)
        Assert-Lbs197 "$scale End focuses last row and scrolls it into viewport" (
            $rows[5].Focused -and $scroll.Value -gt 0 -and
            $rows[5].Bottom -le ($scroll.Value+$list.ClientSize.Height))
        Assert-Lbs197 "$scale focus navigation scroll does not select BootNext" ($script:BootNextCalls -eq 0)
        Invoke-Lbs197Key $rows[5] ([System.Windows.Forms.Keys]::Down)
        Assert-Lbs197 "$scale last-row Down clamps" ($rows[5].Focused)
        Invoke-Lbs197Key $rows[5] ([System.Windows.Forms.Keys]::Home)
        Assert-Lbs197 "$scale Home focuses first and scrolls back" ($rows[0].Focused -and $scroll.Value -eq 0)
        $keyDown = $rows[0].GetType().GetMethod('OnKeyDown',$flags)
        $keyUp = $rows[0].GetType().GetMethod('OnKeyUp',$flags)
        [void]$keyUp.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Return)))
        Assert-Lbs197 "$scale orphan KeyUp never triggers selection" ($script:BootNextCalls -eq 0)
        $enterDown = [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Return)
        [void]$keyDown.Invoke($rows[0],[object[]]@($enterDown))
        Assert-Lbs197 "$scale Return KeyDown is handled without suppressing physical KeyUp" (
            $enterDown.Handled -and -not $enterDown.SuppressKeyPress)
        [void]$keyUp.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Return)))
        Assert-Lbs197 "$scale explicit Enter delegates once to BootNext controller" (
            $script:BootNextCalls -eq 1 -and $script:LastBootNextGuid -eq $script:TestEntries[0].Guid)
        [void]$keyDown.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Space)))
        [void]$keyDown.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Space)))
        Assert-Lbs197 "$scale autorepeated KeyDown does not preemptively select" ($script:BootNextCalls -eq 1)
        [void]$keyUp.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Space)))
        Assert-Lbs197 "$scale explicit Space delegates once to same controller" (
            $script:BootNextCalls -eq 2 -and $script:LastBootNextGuid -eq $script:TestEntries[0].Guid)
        & $handlers.Click $rows[0] $null
        Assert-Lbs197 "$scale pointer click uses same controller" ($script:BootNextCalls -eq 3)
        Assert-Lbs197 "$scale all navigation and activation leave restart and settings untouched" (
            $script:WriteCalls -eq 0 -and $script:RestartCalls -eq 0)
        $focused = Get-NormalBootFocusedGuid -ContentPanel $content
        Assert-Lbs197 "$scale focus snapshot captures exact stable GUID" ($focused -eq $script:TestEntries[0].Guid)
        $old = $rows[0]
        $content.Controls.Remove($old)
        $old.Dispose()
        $recreated = New-BootEntryRow -Entry $script:TestEntries[0] -Y 0 -BaseRowHeight ([int](60*$scale)) -Handlers $handlers
        $content.Controls.Add($recreated.Row)
        $rows[0] = $recreated.Row
        Restore-NormalBootFocusedGuid -ContentPanel $content -Guid $focused
        Assert-Lbs197 "$scale focused GUID survives native row reconstruction" ($rows[0].Focused)
        $armDown = $rows[0].GetType().GetMethod('OnKeyDown',$flags)
        $armUp = $rows[0].GetType().GetMethod('OnKeyUp',$flags)
        [void]$armDown.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Return)))
        $other.Focus() | Out-Null
        [void]$armUp.Invoke($rows[0],[object[]]@(
            [System.Windows.Forms.KeyEventArgs]::new([System.Windows.Forms.Keys]::Return)))
        $unfocusedPixels = Get-Lbs197RowPaintPixels $rows[0]
        Assert-Lbs197 "$scale unfocused row clears its border and tint" (
            $unfocusedPixels.Border.ToArgb() -eq $rows[0].BackColor.ToArgb() -and
            $unfocusedPixels.Interior.ToArgb() -eq $rows[0].BackColor.ToArgb())
        Assert-Lbs197 "$scale moving focus cancels any armed selection" ($script:BootNextCalls -eq 3)
        Assert-Lbs197 "$scale focus elsewhere is not reported as entry focus" (
            (Get-NormalBootFocusedGuid -ContentPanel $content) -eq '')
        Restore-NormalBootFocusedGuid -ContentPanel $content -Guid ''
        Assert-Lbs197 "$scale empty focus snapshot never steals focus" ($other.Focused -and -not $rows[0].Focused)
    }
    finally {
        $form.Dispose()
        $script:Popup = $null
        $script:BootNextCalls = 0
        $script:LastBootNextGuid = ''
    }
}
Write-Host "LBS197 KEYBOARD TOTAL $script:checks/57"
if ($script:checks -ne 57) { throw "LBS197 test total mismatch $script:checks" }
