#requires -version 5.1
# LBS-167: actual WinForms row identity and refresh/drag presentation lifecycle.
# Isolated in a native STA child; no privileged or firmware mutation.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'src\UI\BootEntryRows.ps1')
. (Join-Path $root 'src\UI\BootEntryList.ps1')
$script:checks = 0
$script:rebuildRows = 0
$script:diag = @()
function Check([string]$Name,[bool]$Pass) {
    if (-not $Pass) { throw "LBS167 FAIL: $Name" }
    $script:checks++
    Write-Host "PASS LBS167 $Name"
}
function Get-LocalizedString { param([string]$Key,$Values) return ($Key + ':' + [string]$script:LocaleSuffix) }
function Get-PopupDpiLayoutScale { param($Popup) return [double]$Popup.Tag }
function Update-ManageEntriesUiState { $script:UiUpdates++ }
function Update-DefaultUi { }
function Update-RestartTargetUi { }
function Update-ManageSaveButtonState { }
function Update-MaintenanceUi { }
function New-RuntimeDiagnosticData { param($Data) return $Data }
function Write-RuntimeDiagnosticEvent {
    param([string]$Event,[string]$Stage,[bool]$Success,$Data)
    $script:diag += [pscustomobject]@{ Event=$Event; Data=$Data }
}
function Test-ManageEntryHidden { param([string]$Guid) return ($script:ManageHiddenEntryGuids -contains $Guid) }
function Get-EntryAlias {
    param([string]$Guid,[switch]$UseManageDraft)
    $map = if ($UseManageDraft) { $script:ManageEntryAliases } else { $script:EntryAliases }
    if ($map -and $map.ContainsKey($Guid)) { return $map[$Guid] }
    return ''
}
function Get-EntryDisplayTitle {
    param($Entry,[switch]$UseManageDraft)
    $alias = Get-EntryAlias -Guid ([string]$Entry.Guid) -UseManageDraft:$UseManageDraft
    if ($alias) { return $alias }
    return [string]$Entry.Title
}
function Get-OrderedEntriesForUi {
    param([switch]$IncludeHidden,[switch]$UseManageDraft)
    if (-not $UseManageDraft) { return @($script:CurrentEntries) }
    $rows = @()
    foreach ($guid in $script:ManageEntryOrder) {
        foreach ($entry in $script:CurrentEntries) {
            if ([string]$entry.Guid -eq [string]$guid) { $rows += $entry }
        }
    }
    return $rows
}
function New-BootEntryInteractionHandlers {
    return [pscustomobject]@{ DragEnter={}; DragOver={}; DragLeave={}; DragDrop={} }
}
function New-BootEntryRow {
    param($Entry,[int]$Y,[int]$BaseRowHeight,$Handlers)
    $script:rebuildRows++
    $row = New-Object System.Windows.Forms.Panel
    $row.Name = 'BootRow'
    $row.Tag = [string]$Entry.Guid
    $row.Size = [Drawing.Size]::new(390, $BaseRowHeight)
    return [pscustomobject]@{ Row = $row; Height = $BaseRowHeight }
}
function Set-PopupBootRowDpiLayout {
    param($Row,[double]$Scale,[int]$Y)
    $Row.Size = [Drawing.Size]::new([int][Math]::Round(390*$Scale),[int][Math]::Round(60*$Scale))
    $Row.Top = $Y
    return $Row.Height
}
function New-TestEntry([string]$Guid,[string]$Title) {
    return [pscustomobject]@{
        Guid=$Guid; Title=$Title; Subtitle='Available'; RawDescription=$Title;
        Symbol='*'; Accent=[Drawing.Color]::Red; TypeTooltip='Boot target'
    }
}

$script:LocaleSuffix = 'en'
$script:UiUpdates = 0
$script:IsManageEntriesMode = $true
$script:CurrentEntries = @((New-TestEntry 'a' 'Alpha'),(New-TestEntry 'b' 'Beta'),(New-TestEntry 'c' 'Gamma'))
$script:ManageEntryOrder = @('a','b','c')
$script:ManageHiddenEntryGuids = @()
$script:ManageEntryAliases = @{}
$script:EntryAliases = @{}
$script:LastStatusText = 'ready'
$script:ManageAliasEditGuid = $null
$script:ManageActiveDragGuid = $null
$script:ManageDropPreview = $null
$script:PopupRowsRefreshPending = $false

$form = New-Object System.Windows.Forms.Form
try {
    $form.Tag = [double]1.0
    $list = New-Object System.Windows.Forms.Panel
    $list.Name = 'EntryList'
    $list.Size = [Drawing.Size]::new(390,100)
    $content = New-Object System.Windows.Forms.Panel
    $content.Name = 'EntryContent'
    $list.Controls.Add($content)
    $scroll = New-Object System.Windows.Forms.VScrollBar
    $scroll.Name = 'EntryScroll'
    $list.Controls.Add($scroll)
    $form.Controls.Add($list)
    $status = New-Object System.Windows.Forms.Label
    $status.Name = 'StatusLabel'
    $form.Controls.Add($status)
    $script:Popup = $form
    [void]$form.Handle

    Update-PopupRows -Reason 'initial'
    $initial = @($content.Controls | Where-Object { $_.Name -eq 'BootRow' })
    Check 'initial build includes all targets' ($initial.Count -eq 3 -and $script:rebuildRows -eq 3)
    Check 'initial diagnostic announces rebuild' (@($script:diag | Where-Object { $_.Data.rebuilt }).Count -eq 1)
    Check 'entry order matches draft' ((@($initial | ForEach-Object Tag) -join ',') -eq 'a,b,c')

    $scroll.Maximum = 1000
    $scroll.LargeChange = 10
    $scroll.Value = 30
    $content.Top = -30
    Update-PopupRows -Reason 'firmware-state'
    Check 'identical firmware snapshot preserves controls' ([object]::ReferenceEquals($initial[0],$content.Controls[0]) -and $script:rebuildRows -eq 3)
    Check 'identical refresh preserves scroll' ($scroll.Value -eq 30 -and $content.Top -eq -30)
    Check 'identical refresh is diagnosed as skipped' ([bool]$script:diag[-1].Data.skipped -and -not [bool]$script:diag[-1].Data.deferred)

    $script:LastStatusText = 'refresh finished'
    Update-PopupRows -Reason 'status-only'
    Check 'status updates without row reconstruction' ($status.Text -eq 'refresh finished' -and $script:rebuildRows -eq 3)

    $script:ManageActiveDragGuid = 'a'
    Update-PopupRows -Reason 'firmware-state'
    Check 'unchanged refresh never cancels active drag' ($script:ManageActiveDragGuid -eq 'a' -and $script:rebuildRows -eq 3)
    $script:CurrentEntries[0].Title = 'Alpha updated'
    Update-PopupRows -Reason 'firmware-state'
    Check 'changed target is deferred while dragging' ($script:PopupRowsRefreshPending -and $script:ManageActiveDragGuid -eq 'a' -and $script:rebuildRows -eq 3)
    Check 'deferred diagnostic omits raw target identity' ([bool]$script:diag[-1].Data.deferred -and $script:diag[-1].Data.afterFingerprint.Length -eq 64 -and -not $script:diag[-1].Data.ContainsKey('guid'))
    Reset-ManageDragPreview
    Check 'drag completion applies pending target change' (-not $script:ManageActiveDragGuid -and -not $script:PopupRowsRefreshPending -and $script:rebuildRows -eq 4)
    Check 'drag completion preserves saved draft order' ((@($script:ManageEntryOrder) -join ',') -eq 'a,b,c')

    Update-PopupRows -Reason 'quick-reopen'
    Check 'quick reopen is a no-op' ($script:rebuildRows -eq 4)
    $script:ManageEntryAliases['a'] = 'Alias draft'
    Update-PopupRows -Reason 'alias-changed'
    Check 'draft alias change redraws once and remains draft' ($script:rebuildRows -eq 5 -and $script:ManageEntryAliases['a'] -eq 'Alias draft')
    $script:ManageEntryOrder = @('b','a','c')
    $beforeReorder = $script:rebuildRows
    Update-PopupRows -Reason 'reorder'
    Check 'reorder keeps existing row controls' ($script:rebuildRows -eq $beforeReorder)
    Check 'draft reorder appears without committing settings' ((@($content.Controls | Where-Object { $_.Name -eq 'BootRow' } | Sort-Object Top | ForEach-Object Tag) -join ',') -eq 'b,a,c')

    $script:ManageAliasEditGuid = 'a'
    Update-PopupRows -Reason 'alias-enter'
    $beforeEditing = $script:rebuildRows
    $script:CurrentEntries[0].Subtitle = 'Availability changed'
    Update-PopupRows -Reason 'firmware-state'
    Check 'active alias editor defers replacement' ($script:PopupRowsRefreshPending -and $script:rebuildRows -eq $beforeEditing)
    $script:ManageAliasEditGuid = $null
    Update-PopupRows -Reason 'alias-done'
    Check 'alias editor exit applies changed metadata' (-not $script:PopupRowsRefreshPending -and $script:rebuildRows -eq ($beforeEditing + 1))
    Check 'alias editor refresh preserves draft alias' ($script:ManageEntryAliases['a'] -eq 'Alias draft')

    $script:LocaleSuffix = 'de'
    $beforeLocale = $script:rebuildRows
    Update-PopupRows -Reason 'language-change'
    Check 'localized row text changes invalidate presentation' ($script:rebuildRows -eq ($beforeLocale + 3))

    $script:CurrentEntries += (New-TestEntry 'd' 'Delta')
    $script:ManageEntryOrder += 'd'
    $beforeNew = $script:rebuildRows
    Update-PopupRows -Reason 'firmware-state'
    Check 'new firmware target appears' (@($content.Controls | Where-Object { $_.Name -eq 'BootRow' }).Count -eq 4 -and $script:rebuildRows -eq ($beforeNew + 1))

    $script:IsManageEntriesMode = $false
    $script:SelectedGuid = 'b'
    $beforeMode = $script:rebuildRows
    Update-PopupRows -Reason 'manage-exit'
    Check 'mode exit rebuilds normal boot rows' ($script:rebuildRows -eq ($beforeMode + 4))
    Update-PopupRows -Reason 'popup-reopen'
    Check 'unchanged normal popup reopen is stable' ($script:rebuildRows -eq ($beforeMode + 4))

    $script:SelectedGuid = 'c'
    Update-PopupRows -Reason 'selection-changed'
    Check 'actual next-boot selection change invalidates rows' ($script:rebuildRows -eq ($beforeMode + 6))
    $beforeDpi = $script:rebuildRows
    $form.Tag = [double]2.5
    Update-PopupRows -Reason 'dpi-changed'
    Check 'DPI scale change rebuilds row geometry' ($script:rebuildRows -eq ($beforeDpi + 4) -and $content.Controls[0].Height -eq 150)
    Update-PopupRows -Reason 'viewport-changed'
    Check 'same scale viewport request reuses rows' ($script:rebuildRows -eq ($beforeDpi + 4))
    $beforeViewport = $script:rebuildRows
    $list.Height = 140
    Update-PopupRows -Reason 'viewport-resized'
    Check 'viewport changes recompute scrollbar without row loss' ($script:rebuildRows -eq $beforeViewport -and $scroll.LargeChange -eq 140)
}
finally {
    $form.Dispose()
    $script:Popup = $null
}
Write-Host "LBS167 TOTAL $script:checks/27"
if ($script:checks -ne 27) { throw "Expected 27 LBS167 checks, got $script:checks" }
