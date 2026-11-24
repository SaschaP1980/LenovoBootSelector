#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1' | Sort-Object FullName)
$pass = 0
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $payloadBytes = if ($hasUtf8Bom -and $bytes.Length -gt 3) { @($bytes[3..($bytes.Length - 1)]) } elseif ($hasUtf8Bom) { @() } else { @($bytes) }
    $hasNonAscii = @($payloadBytes | Where-Object { $_ -ge 128 }).Count -gt 0
    if ($hasNonAscii -and -not $hasUtf8Bom) {
        throw "Encoding failure in $($file.FullName): non-ASCII PowerShell source requires UTF-8 BOM for Windows PowerShell 5.1"
    }
    if ($hasNonAscii) { Write-Host "PASS  Encoding $($file.FullName.Substring($root.Length + 1))" }

    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) {
        $detail = (@($errors) | ForEach-Object { $_.Message }) -join '; '
        throw "Parse failure in $($file.FullName): $detail"
    }
    $pass++
    Write-Host "PASS  Parse $($file.FullName.Substring($root.Length + 1))"
}
Write-Host "PARSER TOTAL $pass/$($files.Count)"

# LBS-172: isolate native snapshot-drag, fast reversals, cleanup and 100%/250% DPI.
$dragVisualProbe = Join-Path $root 'tests\Test-LBS172-DragVisual.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $dragVisualProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-172 native Manage Entries drag visual regression failed' }

# LBS-217: native DE/EN selected/pending/idle row status semantics at 96/240 synthetic DPI.
$bootRowStateProbe = Join-Path $root 'tests\Test-LBS217-RowState.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $bootRowStateProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-217 native boot row state semantics regression failed' }

# LBS-227: native EDIT length limit and actual draft/settings legacy preservation.
$aliasLimitProbe = Join-Path $root 'tests\Test-LBS227-AliasLimit.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $aliasLimitProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-227 native alias limit regression failed' }

# LBS-224: actual product cue rendering, input, hit test and lifecycle.
$aliasCueProbe = Join-Path $root 'tests\Test-LBS224-AliasCue.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $aliasCueProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-224 native alias cue regression failed' }

# LBS-221 Hotfix: native alias-clear appearance, tooltip lifetime and draft-only behavior.
$aliasClearProbe = Join-Path $root 'tests\Test-LBS221-AliasClear.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $aliasClearProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-221 native alias-clear regression failed' }

# LBS-221: isolated native Manage action hover and drag-safe dark hint routing.
$manageHoverProbe = Join-Path $root 'tests\Test-LBS221-ManageHover.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $manageHoverProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-221 native Manage hover regression failed' }

# LBS-215: isolate native Manage grip click routing and unchanged drag admission.
$gripClickProbe = Join-Path $root 'tests\Test-LBS215-GripClick.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $gripClickProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-215 native Manage grip click routing regression failed' }

# LBS-213: isolated native semantic ink contrast and scrollbar pointer-hit regression.
$contrastScrollProbe = Join-Path $root 'tests\Test-LBS213-ContrastScroll.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $contrastScrollProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-213 native contrast / scrollbar regression failed' }

# LBS-206: native asynchronous persistent default change, exact readback and
# pending interlock (mock worker: never touches firmware or SYSTEM tasks).
$defaultAsyncProbe = Join-Path $root 'tests\Test-LBS206-DefaultAsync.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $defaultAsyncProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-206 default-target asynchronous feedback regression failed' }

# LBS-206 Hotfix v1.5.10.2: owner-painted Standardziel boundary + reset tooltip.
$menuEdgeProbe = Join-Path $root 'tests\Test-LBS206-MenuContrast.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $menuEdgeProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-206 native Standardziel contrast / tooltip regression failed' }

# LBS-206: native Layout C readback status, explicit default once and DPI safety.
$layoutCProbe = Join-Path $root 'tests\Test-LBS206-LayoutC.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $layoutCProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-206 native Layout C regression failed' }

# LBS-206 hotfix: real canonical reset entry point must enqueue the standard
# asynchronous selection, not a synchronous firmware write.
$resetProbe = Join-Path $root 'tests\Test-LBS206-Hotfix.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $resetProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-206 reset pending hotfix regression failed' }

# LBS-205: focused popup Escape routing, child precedence and draft safety.
$popupEscapeProbe = Join-Path $root 'tests\Test-LBS205-PopupEscape.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $popupEscapeProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-205 native main popup Escape regression failed' }

# LBS-200: isolated native WinForms tray-menu activation and dismissal probe.
$trayMenuProbe = Join-Path $root 'tests\Test-LBS200-TrayMenu.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $trayMenuProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-200 native tray menu regression failed' }

# LBS-202: isolated native update notice focus, safe defaults and deliberate install.
$updateNoticeProbe = Join-Path $root 'tests\Test-LBS202-UpdateNotice.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $updateNoticeProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-202 native update-available dialog regression failed' }

# UX01-V8 / LBS-197: real focusable normal rows, scroll and safe keyboard selection.
$keyboardProbe = Join-Path $root 'tests\Test-LBS197-NormalKeyboard.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $keyboardProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-197 native normal popup keyboard regression failed' }

& (Join-Path $root 'tests\Test-FunctionalCore.ps1')
& (Join-Path $root 'tests\Test-StorageInfrastructure.ps1')
& (Join-Path $root 'tests\Test-UIPresentation.ps1')
& (Join-Path $root 'tests\Test-LBS163-DragPreview.ps1')
& (Join-Path $root 'tests\Test-PopupDpiLayout.ps1')
& (Join-Path $root 'tests\Test-LocalizationRuntime.ps1')
& (Join-Path $root 'tests\Test-RefreshRuntime.ps1')
& (Join-Path $root 'tests\Test-DiagnosticsIdentity.ps1')
& (Join-Path $root 'tests\Test-DiagnosticsUploadTransport.ps1')
& (Join-Path $root 'tests\Test-RefreshController.ps1')
& (Join-Path $root 'tests\Test-SingleInstanceMutex.ps1')
& (Join-Path $root 'tests\Test-InstanceActivation.ps1')
& (Join-Path $root 'tests\Test-ArchitectureSoak.ps1')
& (Join-Path $root 'tests\Test-MaintenanceRuntime.ps1')
& (Join-Path $root 'tests\Test-SystemCapabilities.ps1')
& (Join-Path $root 'tests\Test-BootTargetDrift.ps1')
& (Join-Path $root 'tests\Test-BootServiceSnapshot.ps1')
& (Join-Path $root 'tests\Test-BootNextOwnership.ps1')
& (Join-Path $root 'tests\Test-BootNextSelectionUi.ps1')
& (Join-Path $root 'tests\Test-BootWriterPriority.ps1')
# LBS-143: actual temporary SYSTEM tasks with isolated fake firmware state.
& (Join-Path $root 'tests\Test-BootWriterScheduledTasks.ps1')
& (Join-Path $root 'tests\Test-TaskBrokerBoundary.ps1')
& (Join-Path $root 'tests\Test-TaskBrokerMigration.ps1')
& (Join-Path $root 'tests\Test-IdentifierCompatibility.ps1')
& (Join-Path $root 'tests\Test-UpdateCore.ps1')
& (Join-Path $root 'tests\Test-UpdateController.ps1')
# LBS-144: Renderer raster probe compiles the canonical embedded C# types and
# must run in an isolated PS5.1 process (this aggregate already loaded them).
# The first-click HWND and four regular-dialog DPI contract is real WinForms.
& (Join-Path $root 'tests\Test-LBS144-TrayStartupAndDialogs.ps1')
$menuInkProbe = Join-Path $root 'tests\Test-LBS144-MenuInkRaster.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $menuInkProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-144 menu text raster regression failed' }
# Read-only DPI window diagnostic, including real Win32/DWM metrics and arbitrary scale values.
& (Join-Path $root 'tests\Test-LBS144-DpiWindowDiagnostics.ps1')
# LBS-144: first native UI HWND and mixed-coordinate awareness contracts.
& (Join-Path $root 'tests\Test-LBS144-DpiAwarenessStartup.ps1')
# LBS-144 owner-drawn Autostart checkbox 96..288 DPI bounds and real paint.
& (Join-Path $root 'tests\Test-LBS144-CheckboxDpi.ps1')

# LBS-144 hotfix P1/P2/P3: native modal geometry, ToolStrip rows and monitor inventory.
# Isolate WinForms Show/Shown from earlier resident test fixture HWNDs.
$hotfixProbe = Join-Path $root 'tests\Test-LBS144-MixedMonitorHotfix.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $hotfixProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-144 P123 isolated native regression failed' }
# LBS-144: isolate painted eye DrawToBitmap and local UI test stubs.
$eyeGlyphProbe = Join-Path $root 'tests\Test-LBS144-ManageEyeDpi.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $eyeGlyphProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-144 visibility eye/refresh DPI regression failed' }

# LBS-166: owner-drawn reorder grip DPI, ink and interaction contract.
$gripGlyphProbe = Join-Path $root 'tests\Test-LBS166-ManageGripDpi.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $gripGlyphProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-166 Manage Entries grip DPI regression failed' }

# LBS-157: real WinForms Manage Entries viewport across six DPI scales.
$manageViewportProbe = Join-Path $root 'tests\Test-LBS157-ManageViewport.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $manageViewportProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-157 Manage Entries viewport regression failed' }

# LBS-167: isolate real WinForms refresh/drag row identity and diagnostics.
$refreshRowsProbe = Join-Path $root 'tests\Test-LBS167-RefreshRendering.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $refreshRowsProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-167 popup refresh/drag regression failed' }

# LBS-174: isolate real WinForms header typography, refresh/update/Busy states and mixed DPI.
$headerProbe = Join-Path $root 'tests\Test-LBS174-HeaderStability.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $headerProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-174 native popup header regression failed' }

# LBS-186: actual popup and row text fit, contrast and localized roles.
$typographyProbe = Join-Path $root 'tests\Test-LBS186-Typography.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $typographyProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-186 native typography regression failed' }

# LBS-191: exercise the canonical locale and cached-entry adapters in isolation.
$liveLocalizationProbe = Join-Path $root 'tests\Test-LBS191-LiveLocalization.ps1'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File $liveLocalizationProbe
if ($LASTEXITCODE -ne 0) { throw 'LBS-191 live localization regression failed' }

