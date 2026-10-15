#requires -version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $root 'src\Core\Localization.ps1')
. (Join-Path $root 'src\Core\EntryPreferences.ps1')
. (Join-Path $root 'src\Infrastructure\SettingsRepository.ps1')
. (Join-Path $root 'src\Application\SettingsService.ps1')
. (Join-Path $root 'src\Application\LocalizationService.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $root 'src\UI\StartupRecoveryDialog.ps1')

$checks = 0
function Assert-Localization([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "LOCALIZATION FAIL: $Name" }
    $script:checks++
    Write-Host "PASS  $Name"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('LenovoBootSelector-LocalizationTest-' + [guid]::NewGuid().ToString('N'))
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $appDataRoot = Join-Path $tempRoot 'LocalAppData'
    $script:SettingsDir = Join-Path $appDataRoot 'Lenovo Boot Menu Tray'
    $script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
    $env:LOCALAPPDATA = $appDataRoot
    $script:EntryAliases = @{}
    $script:LegacyDefaultGuid = $null
    $script:DefaultGuid = $null
    $script:EntryOrder = @()
    $script:HiddenEntryGuids = @()
    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    $script:LocalePreferenceNeedsConfirmation = $false
    $script:LegacySessionRestoreRegistryPath = 'HKCU:\Software\LenovoBootSelector-Test-DoesNotExist'
    $script:LegacySessionRestoreValueName = 'Restore'

    $defaults = New-DefaultAppSettingsCore
    Assert-Localization 'Brand-new settings use schema 6' ([int]$defaults.schemaVersion -eq 6)
    Assert-Localization 'Brand-new settings default to en-US' ([string]$defaults.locale -eq 'en-US')
    Assert-Localization 'Brand-new settings mark locale as default' ([string]$defaults.localePreferenceSource -eq 'default')
    Assert-Localization 'Brand-new settings need no locale confirmation' (-not [bool]$defaults.localePreferenceNeedsConfirmation)
    Assert-Localization 'Active locale starts as en-US' ((Get-ActiveLocale) -eq 'en-US')
    Assert-Localization 'Central English lookup works' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Cancel')

    # LBS-30: native, observable catalog coverage migrated from the legacy
    # source-literal-only LBS-23 validator (both supported locales).
    foreach ($migrationKey in @('Language.MigrationTitle', 'Language.MigrationUseEnglish', 'Language.MigrationKeepGerman')) {
        $english = Get-LocalizedStringCore -Key $migrationKey -Locale 'en-US'
        $german = Get-LocalizedStringCore -Key $migrationKey -Locale 'de-DE'
        Assert-Localization ('LBS-23 migration prompt resolves ' + $migrationKey) (
            -not [string]::IsNullOrWhiteSpace([string]$english) -and
            -not [string]::IsNullOrWhiteSpace([string]$german) -and
            $english -ne $migrationKey -and $german -ne $migrationKey
        )
    }

    $selected = Set-ActiveLocale -Locale 'de-DE' -Persist
    Assert-Localization 'German selection resolves to de-DE' ($selected -eq 'de-DE')
    Assert-Localization 'Language selection writes settings file' (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Persisted settings use schema 6 and de-DE' ([int]$persisted.schemaVersion -eq 6 -and [string]$persisted.locale -eq 'de-DE')
    Assert-Localization 'Persisted German selection records user choice' ([string]$persisted.localePreferenceSource -eq 'user')

    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    Load-AppSettings
    Assert-Localization 'Load-AppSettings restores persisted de-DE' ((Get-ActiveLocale) -eq 'de-DE')
    Assert-Localization 'Reload preserves explicit user preference metadata' ([string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'Central German lookup works after reload' ((Get-LocalizedString -Key 'Common.Cancel') -eq 'Abbrechen')

    $selected = Set-ActiveLocale -Locale 'fr-FR' -Persist
    Assert-Localization 'Invalid locale selection fails safely to en-US' ($selected -eq 'en-US')
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Invalid locale persists normalized en-US' ([string]$persisted.locale -eq 'en-US' -and [string]$persisted.localePreferenceSource -eq 'user')

    $legacy = [ordered]@{
        schemaVersion = 4
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = [ordered]@{}
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $legacy
    $script:UiLocale = 'de-DE'
    $script:LocalePreferenceSource = 'user'
    $script:LocalePreferenceNeedsConfirmation = $true
    Load-AppSettings
    Assert-Localization 'Pre-localization schema migrates to en-US' ((Get-ActiveLocale) -eq 'en-US')
    Assert-Localization 'Pre-localization migration uses default preference without confirmation' ([string]$script:LocalePreferenceSource -eq 'default' -and -not $script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'Startup recovery uses en-US for pre-localization settings' ((Get-StartupRecoveryLocale) -eq 'en-US')

    Remove-Item -LiteralPath $script:SettingsPath -Force
    $fresh = Get-AppSettings
    Assert-Localization 'Missing settings file remains a new en-US installation' ([string]$fresh.locale -eq 'en-US')

    $v0800German = [ordered]@{
        schemaVersion = 5
        locale = 'de-DE'
        defaultGuid = $null
        entryOrder = @()
        hiddenEntryGuids = @()
        entryAliases = [ordered]@{}
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $v0800German
    $script:UiLocale = 'en-US'
    $script:LocalePreferenceSource = 'default'
    $script:LocalePreferenceNeedsConfirmation = $false
    Load-AppSettings
    Assert-Localization 'v0.8.0.0 migrated German remains de-DE until resolved' ((Get-ActiveLocale) -eq 'de-DE')
    Assert-Localization 'v0.8.0.0 migrated German requires confirmation' ($script:LocalePreferenceNeedsConfirmation)
    Assert-Localization 'v0.8.0.0 migrated German is marked migration-pending' ([string]$script:LocalePreferenceSource -eq 'migration-pending')
    Assert-Localization 'Startup recovery preserves ambiguous de-DE until explicit choice' ((Get-StartupRecoveryLocale) -eq 'de-DE')

    Save-AppSettings
    $persisted = [System.IO.File]::ReadAllText($script:SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Localization 'Unresolved migration persists schema 6 migration-pending state' ([int]$persisted.schemaVersion -eq 6 -and [string]$persisted.localePreferenceSource -eq 'migration-pending')
    $script:LocalePreferenceNeedsConfirmation = $false
    Load-AppSettings
    Assert-Localization 'Reload preserves unresolved migration confirmation' ($script:LocalePreferenceNeedsConfirmation)

    $selected = Set-ActiveLocale -Locale 'de-DE' -Persist
    Assert-Localization 'Explicit German confirmation persists user choice' ($selected -eq 'de-DE' -and [string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)
    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Explicit German confirmation survives reload' ((Get-ActiveLocale) -eq 'de-DE' -and -not $script:LocalePreferenceNeedsConfirmation)

    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $v0800German
    Load-AppSettings
    $selected = Set-ActiveLocale -Locale 'en-US' -Persist
    Assert-Localization 'v0.8.0.0 migrated German can be corrected to English once' ($selected -eq 'en-US' -and [string]$script:LocalePreferenceSource -eq 'user')
    $script:UiLocale = 'de-DE'
    $script:LocalePreferenceNeedsConfirmation = $true
    Load-AppSettings
    Assert-Localization 'English correction survives reload without another prompt' ((Get-ActiveLocale) -eq 'en-US' -and -not $script:LocalePreferenceNeedsConfirmation)

    [void](Set-ActiveLocale -Locale 'de-DE' -Persist)
    $script:UiLocale = 'en-US'
    Load-AppSettings
    Assert-Localization 'Later explicit German choice survives reload' ((Get-ActiveLocale) -eq 'de-DE' -and [string]$script:LocalePreferenceSource -eq 'user' -and -not $script:LocalePreferenceNeedsConfirmation)


    # LBS-111: test the real live tray refresh with actual WinForms menu items.
    . (Join-Path $root 'src\UI\LanguagePresentation.ps1')
    Assert-Localization 'English upload catalog uses sentence case' ((Get-LocalizedStringCore -Key 'Diagnostics.Upload' -Locale 'en-US') -eq 'Upload diagnostics…')
    Assert-Localization 'German upload catalog remains translated' ((Get-LocalizedStringCore -Key 'Diagnostics.Upload' -Locale 'de-DE') -eq 'Diagnose hochladen…')
    $script:RuntimeDiagnosticMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $script:DiagnosticsUploadMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    try {
        [void](Set-ActiveLocale -Locale 'en-US' -Persist)
        Update-TrayLocalizedText
        Assert-Localization 'English tray refresh localizes diagnostic save' ($script:RuntimeDiagnosticMenuItem.Text -eq 'Save diagnostics…')
        Assert-Localization 'English tray refresh localizes diagnostic upload' ($script:DiagnosticsUploadMenuItem.Text -eq 'Upload diagnostics…')

        [void](Set-ActiveLocale -Locale 'de-DE' -Persist)
        Update-TrayLocalizedText
        Assert-Localization 'Switch en-US to de-DE localizes diagnostic save' ($script:RuntimeDiagnosticMenuItem.Text -eq 'Diagnose speichern…')
        Assert-Localization 'Switch en-US to de-DE localizes diagnostic upload' ($script:DiagnosticsUploadMenuItem.Text -eq 'Diagnose hochladen…')

        [void](Set-ActiveLocale -Locale 'en-US' -Persist)
        Update-TrayLocalizedText
        Assert-Localization 'Switch de-DE to en-US localizes diagnostic save' ($script:RuntimeDiagnosticMenuItem.Text -eq 'Save diagnostics…')
        Assert-Localization 'Switch de-DE to en-US localizes diagnostic upload' ($script:DiagnosticsUploadMenuItem.Text -eq 'Upload diagnostics…')

        $script:DiagnosticsUploadMenuItem.Dispose()
        $script:DiagnosticsUploadMenuItem = $null
        Update-TrayLocalizedText
        Assert-Localization 'Missing upload menu item does not block other refreshes' ($script:RuntimeDiagnosticMenuItem.Text -eq 'Save diagnostics…')
    }
    finally {
        if ($script:DiagnosticsUploadMenuItem) { $script:DiagnosticsUploadMenuItem.Dispose(); $script:DiagnosticsUploadMenuItem = $null }
        if ($script:RuntimeDiagnosticMenuItem) { $script:RuntimeDiagnosticMenuItem.Dispose(); $script:RuntimeDiagnosticMenuItem = $null }
    }

    # LBS-117 country flag renderer: compile the actual template C# in PS5.1,
    # exercise scoped menu identity, geometry, pixels and locale checkmarks.
    $templateText = [IO.File]::ReadAllText((Join-Path $root 'src\App\LenovoBootSelector.template.ps1'), [Text.Encoding]::UTF8)
    $beginMarker = 'Add-Type -TypeDefinition @"'
    $endMarker = '"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing'
    $startIndex = $templateText.IndexOf($beginMarker, [StringComparison]::Ordinal)
    $endIndex = $templateText.IndexOf($endMarker, $startIndex + $beginMarker.Length, [StringComparison]::Ordinal)
    if ($startIndex -lt 0 -or $endIndex -le $startIndex) { throw 'LBS-117 menu C# source block not found' }
    $menuCode = $templateText.Substring($startIndex + $beginMarker.Length, $endIndex - $startIndex - $beginMarker.Length)
    Add-Type -TypeDefinition $menuCode -ReferencedAssemblies System.Windows.Forms,System.Drawing

    Assert-Localization 'LBS-117 real tray wires US and German flag identities' (
        $templateText.Contains('$languageRoot.DropDown.Name = ''LenovoLanguageDropDown''') -and
        $templateText.Contains('$languageEnglish.Name = ''LocaleFlag.en-US''') -and
        $templateText.Contains('$languageGerman.Name = ''LocaleFlag.de-DE''')
    )
    $flagsMenu = New-Object LenovoDropDownMenu
    $flagsMenu.Name = 'LenovoLanguageDropDown'
    $usFlagItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $usFlagItem.Name = 'LocaleFlag.en-US'
    $usFlagItem.Text = 'English'
    $deFlagItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $deFlagItem.Name = 'LocaleFlag.de-DE'
    $deFlagItem.Text = 'Deutsch'
    $unrelatedItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $unrelatedItem.Name = 'Maintenance'
    [void]$flagsMenu.Items.Add($usFlagItem)
    [void]$flagsMenu.Items.Add($deFlagItem)
    [void]$flagsMenu.Items.Add($unrelatedItem)
    $otherMenu = New-Object LenovoDropDownMenu
    $wrongOwner = New-Object System.Windows.Forms.ToolStripMenuItem
    $wrongOwner.Name = 'LocaleFlag.en-US'
    [void]$otherMenu.Items.Add($wrongOwner)
    try {
        Assert-Localization 'LBS-117 en-US maps only to US flag' ([LenovoLocaleFlags]::GetLocale($usFlagItem) -ceq 'en-US')
        Assert-Localization 'LBS-117 de-DE maps only to Germany flag' ([LenovoLocaleFlags]::GetLocale($deFlagItem) -ceq 'de-DE')
        Assert-Localization 'LBS-117 unrelated language-menu entry has no flag' ($null -eq [LenovoLocaleFlags]::GetLocale($unrelatedItem))
        Assert-Localization 'LBS-117 other menus never acquire flags' ($null -eq [LenovoLocaleFlags]::GetLocale($wrongOwner))
        $row = New-Object Drawing.Rectangle(0,0,220,28)
        $usBounds = [LenovoLocaleFlags]::GetBounds($usFlagItem,$row,[single]96)
        $deBounds = [LenovoLocaleFlags]::GetBounds($deFlagItem,$row,[single]96)
        Assert-Localization 'LBS-117 flags are 16 by 12 and vertically centered' (
            $usBounds.Width -eq 16 -and $usBounds.Height -eq 12 -and
            $usBounds.Top -eq 8 -and $deBounds.Equals($usBounds)
        )
        Assert-Localization 'LBS-117 text begins after icon at standard DPI' (
            [LenovoLocaleFlags]::TextLeft($usFlagItem,$row,[single]96) -gt ($usBounds.Right + 4)
        )
        $scaled = [LenovoLocaleFlags]::GetBounds($deFlagItem,$row,[single]144)
        Assert-Localization 'LBS-117 flag geometry scales at 150 percent DPI' (
            $scaled.Width -eq 24 -and $scaled.Height -eq 18 -and
            [LenovoLocaleFlags]::TextLeft($deFlagItem,$row,[single]144) -gt ($scaled.Right + 4)
        )
        $bitmap = New-Object System.Drawing.Bitmap(220,28)
        $g = [Drawing.Graphics]::FromImage($bitmap)
        try {
            [LenovoLocaleFlags]::Draw($g,$usFlagItem,$row)
            $usRed = $bitmap.GetPixel(($usBounds.Right - 2),$usBounds.Top)
            $usBlue = $bitmap.GetPixel($usBounds.Left,$usBounds.Top)
            Assert-Localization 'LBS-117 US flag draws red stripes and navy canton' (
                $usRed.ToArgb() -eq ([Drawing.Color]::FromArgb(178,34,52)).ToArgb() -and
                $usBlue.ToArgb() -eq ([Drawing.Color]::FromArgb(60,59,110)).ToArgb()
            )
            Assert-Localization 'LBS-117 hotfix US fly-end first and final stripes are red' (
                $bitmap.GetPixel(($usBounds.Right - 2),$usBounds.Top).ToArgb() -eq ([Drawing.Color]::FromArgb(178,34,52)).ToArgb() -and
                $bitmap.GetPixel(($usBounds.Right - 2),($usBounds.Bottom - 1)).ToArgb() -eq ([Drawing.Color]::FromArgb(178,34,52)).ToArgb()
            )
            $g.Clear([Drawing.Color]::Transparent)
            [LenovoLocaleFlags]::Draw($g,$deFlagItem,$row)
            Assert-Localization 'LBS-117 German flag draws black red gold bands' (
                $bitmap.GetPixel($deBounds.Left,$deBounds.Top).ToArgb() -eq [Drawing.Color]::Black.ToArgb() -and
                $bitmap.GetPixel($deBounds.Left,($deBounds.Top + 5)).ToArgb() -eq ([Drawing.Color]::FromArgb(221,0,0)).ToArgb() -and
                $bitmap.GetPixel($deBounds.Left,($deBounds.Bottom - 1)).ToArgb() -eq ([Drawing.Color]::FromArgb(255,206,0)).ToArgb()
            )
        }
        finally { $g.Dispose(); $bitmap.Dispose() }

        # Native regression: a hidden WinForms image gutter used to give the
        # renderer a precomputed 12px text box, clipping both entire labels.
        $textBoundsEn = [LenovoLocaleFlags]::GetTextBounds($usFlagItem,$row,[single]96)
        Assert-Localization 'LBS-117 hotfix English text area independent of native narrow bounds' (
            $textBoundsEn.Left -ge ($usBounds.Right + 5) -and
            $textBoundsEn.Width -gt 125 -and $textBoundsEn.Right -le 190
        )
        $textBoundsDe150 = [LenovoLocaleFlags]::GetTextBounds($deFlagItem,$row,[single]144)
        Assert-Localization 'LBS-117 hotfix German text fits at 150 percent DPI' (
            $textBoundsDe150.Left -gt ($scaled.Right + 4) -and
            $textBoundsDe150.Width -ge 110 -and $textBoundsDe150.Right -le 172
        )
        $flagsMenu.AutoSize = $false
        $flagsMenu.Size = New-Object System.Drawing.Size(220,90)
        $usFlagItem.AutoSize = $false
        $deFlagItem.AutoSize = $false
        $usFlagItem.Size = New-Object System.Drawing.Size(220,28)
        $deFlagItem.Size = New-Object System.Drawing.Size(220,28)
        $otherMenu.AutoSize = $false
        $otherMenu.Size = New-Object System.Drawing.Size(220,40)
        $wrongOwner.AutoSize = $false
        $wrongOwner.Size = New-Object System.Drawing.Size(220,28)
        $renderer = New-Object LenovoMenuRenderer
        $font = New-Object System.Drawing.Font('Segoe UI',9.0)
        $textBitmap = New-Object System.Drawing.Bitmap(220,28)
        $tg = [Drawing.Graphics]::FromImage($textBitmap)
        $nativeNarrow = New-Object Drawing.Rectangle(0,0,12,28)
        try {
            $tg.Clear([Drawing.Color]::Black)
            $enArgs = [System.Windows.Forms.ToolStripItemTextRenderEventArgs]::new(
                $tg,$usFlagItem,'English',$nativeNarrow,[Drawing.Color]::White,$font,
                [System.Windows.Forms.TextFormatFlags]::SingleLine)
            $renderer.DrawItemText($enArgs)
            Assert-Localization 'LBS-117 hotfix real English renderer expands clipped text rectangle' (
                $enArgs.TextRectangle.Left -ge $textBoundsEn.Left -and
                $enArgs.TextRectangle.Width -ge 100 -and $enArgs.TextRectangle.Right -le 190
            )
            $paintedEnglish = $false
            for ($px=60; $px -lt 115; $px++) {
                for ($py=3; $py -lt 25; $py++) {
                    if ($textBitmap.GetPixel($px,$py).ToArgb() -ne [Drawing.Color]::Black.ToArgb()) {
                        $paintedEnglish = $true
                        break
                    }
                }
                if ($paintedEnglish) { break }
            }
            Assert-Localization 'LBS-117 hotfix English letters paint past old 12px clip' $paintedEnglish

            $tg.Clear([Drawing.Color]::Black)
            $deArgs = [System.Windows.Forms.ToolStripItemTextRenderEventArgs]::new(
                $tg,$deFlagItem,'Deutsch',$nativeNarrow,[Drawing.Color]::White,$font,
                [System.Windows.Forms.TextFormatFlags]::SingleLine)
            $renderer.DrawItemText($deArgs)
            Assert-Localization 'LBS-117 hotfix real German renderer expands clipped text rectangle' (
                $deArgs.TextRectangle.Left -ge $textBoundsEn.Left -and
                $deArgs.TextRectangle.Width -ge 100 -and $deArgs.TextRectangle.Right -le 190
            )
            $paintedGerman = $false
            for ($px=60; $px -lt 115; $px++) {
                for ($py=3; $py -lt 25; $py++) {
                    if ($textBitmap.GetPixel($px,$py).ToArgb() -ne [Drawing.Color]::Black.ToArgb()) {
                        $paintedGerman = $true
                        break
                    }
                }
                if ($paintedGerman) { break }
            }
            Assert-Localization 'LBS-117 hotfix German letters paint past old 12px clip' $paintedGerman

            $otherArgs = [System.Windows.Forms.ToolStripItemTextRenderEventArgs]::new(
                $tg,$wrongOwner,'Maintenance',$nativeNarrow,[Drawing.Color]::White,$font,
                [System.Windows.Forms.TextFormatFlags]::SingleLine)
            $renderer.DrawItemText($otherArgs)
            Assert-Localization 'LBS-117 hotfix non-language renderer retains native rectangle' (
                $otherArgs.TextRectangle.Equals($nativeNarrow)
            )
        }
        finally { $tg.Dispose(); $textBitmap.Dispose(); $font.Dispose() }
        $script:LanguageEnglishMenuItem = $usFlagItem
        $script:LanguageGermanMenuItem = $deFlagItem
        [void](Set-ActiveLocale -Locale 'en-US' -Persist)
        Update-LanguageMenuState
        Assert-Localization 'LBS-117 en-US remains checked only for English' ($usFlagItem.Checked -and -not $deFlagItem.Checked)
        [void](Set-ActiveLocale -Locale 'de-DE' -Persist)
        Update-LanguageMenuState
        Assert-Localization 'LBS-117 de-DE remains checked only for German' ($deFlagItem.Checked -and -not $usFlagItem.Checked)
        Assert-Localization 'LBS-117 other menu gutters remain disabled' (
            -not $otherMenu.ShowImageMargin -and -not $otherMenu.ShowCheckMargin -and
            -not $flagsMenu.ShowImageMargin -and -not $flagsMenu.ShowCheckMargin
        )
        Assert-Localization 'LBS-117 menu text remains English and Deutsch' (
            $usFlagItem.Text -ceq 'English' -and $deFlagItem.Text -ceq 'Deutsch'
        )
    }
    finally {
        $script:LanguageEnglishMenuItem = $null
        $script:LanguageGermanMenuItem = $null
        $flagsMenu.Dispose()
        $otherMenu.Dispose()
    }


    # LBS-32: persisted settings must not be silently replaced after load failures.
    $script:SettingsDiagnosticsObserved = @()
    function New-RuntimeDiagnosticData { param([hashtable]$Values) return $Values }
    function Write-RuntimeDiagnosticEvent {
        param([string]$Event, [string]$Stage, $Success, $Data, [string]$Level)
        $script:SettingsDiagnosticsObserved += [pscustomobject]@{
            Event = $Event; Stage = $Stage; Success = $Success; Data = $Data; Level = $Level
        }
    }

    Remove-Item -LiteralPath $script:SettingsPath -Force -ErrorAction SilentlyContinue
    $missingOutcome = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 missing file is a non-error first-run outcome' (
        $missingOutcome.Status -eq 'Missing' -and -not $missingOutcome.PersistenceBlocked -and
        $missingOutcome.Settings.locale -eq 'en-US'
    )
    $null = Get-AppSettings
    Assert-Localization 'LBS-32 settings getter exposes Missing status separately' (
        $script:SettingsLoadState.Status -eq 'Missing'
    )

    $goodSettings = [ordered]@{
        schemaVersion=6; locale='de-DE'; localePreferenceSource='user'
        defaultGuid=$null; entryOrder=@('ABC','abc'); hiddenEntryGuids=@('AAA')
        entryAliases=[ordered]@{ 'ABC'='Müller' }
    }
    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $goodSettings
    $loadedOutcome = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 loaded outcome preserves schema-6 locale and normalized entries' (
        $loadedOutcome.Status -eq 'Loaded' -and -not $loadedOutcome.PersistenceBlocked -and
        $loadedOutcome.Settings.locale -eq 'de-DE' -and
        $loadedOutcome.Settings.localePreferenceSource -eq 'user' -and
        @($loadedOutcome.Settings.entryOrder).Count -eq 1
    )
    Load-AppSettings
    Assert-Localization 'LBS-32 successful reload records Loaded state' (
        $script:SettingsLoadState.Status -eq 'Loaded' -and $script:UiLocale -eq 'de-DE'
    )

    $malformed = '{ "schemaVersion": 6, broken JSON '
    [IO.File]::WriteAllText($script:SettingsPath, $malformed, (New-Object Text.UTF8Encoding($false)))
    $invalidOutcome = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 invalid JSON is not classified as missing' (
        $invalidOutcome.Status -eq 'Invalid' -and
        $invalidOutcome.FailureKind -eq 'ParseFailure' -and
        $invalidOutcome.PersistenceBlocked -and $invalidOutcome.Settings.locale -eq 'en-US'
    )
    $script:SettingsDiagnosticsObserved = @()
    Load-AppSettings
    Assert-Localization 'LBS-32 invalid persisted state has safe runtime defaults' (
        $script:UiLocale -eq 'en-US' -and $script:SettingsLoadState.Status -eq 'Invalid'
    )
    Assert-Localization 'LBS-32 invalid settings produce structured failure diagnostics' (
        @($script:SettingsDiagnosticsObserved | Where-Object {
            $_.Event -eq 'SETTINGS_LOAD_FALLBACK' -and $_.Stage -eq 'settings' -and
            $_.Data.status -eq 'Invalid' -and $_.Data.failureKind -eq 'ParseFailure' -and
            $_.Data.persistenceBlocked -eq $true
        }).Count -eq 1
    )
    $blockedSave = $false
    try { Save-AppSettings } catch { $blockedSave = $true }
    Assert-Localization 'LBS-32 save blocks known-invalid source without overwriting bytes' (
        $blockedSave -and [IO.File]::ReadAllText($script:SettingsPath) -ceq $malformed
    )
    Assert-Localization 'LBS-32 blocked settings save is observable' (
        @($script:SettingsDiagnosticsObserved | Where-Object { $_.Event -eq 'SETTINGS_SAVE_BLOCKED' }).Count -gt 0
    )

    Write-AppSettingsRepository -Directory $script:SettingsDir -Path $script:SettingsPath -Payload $goodSettings
    $stillBlocked = $false
    try { Save-AppSettings } catch { $stillBlocked = $true }
    Assert-Localization 'LBS-32 external repair requires explicit clean reload before saving' $stillBlocked
    Load-AppSettings
    Save-AppSettings
    Assert-Localization 'LBS-32 successful reload allows deterministic schema-6 save' (
        $script:SettingsLoadState.Status -eq 'Loaded' -and
        ([IO.File]::ReadAllText($script:SettingsPath) | ConvertFrom-Json).schemaVersion -eq 6 -and
        -not (Test-Path -LiteralPath ($script:SettingsPath + '.tmp'))
    )

    [IO.File]::WriteAllText($script:SettingsPath, 'null', (New-Object Text.UTF8Encoding($false)))
    $nullRoot = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 JSON null root is Invalid not Missing' (
        $nullRoot.Status -eq 'Invalid' -and $nullRoot.FailureKind -eq 'InvalidRoot'
    )

    [IO.File]::WriteAllText($script:SettingsPath, '{"schemaVersion":"not-an-int"}', (New-Object Text.UTF8Encoding($false)))
    $badNormalize = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 invalid schema normalization is explicitly reported' (
        $badNormalize.Status -eq 'Invalid' -and $badNormalize.FailureKind -eq 'NormalizeFailure'
    )

    Remove-Item -LiteralPath $script:SettingsPath -Force
    [void](New-Item -ItemType Directory -Path $script:SettingsPath -Force)
    $unreadable = Get-AppSettingsLoadResult
    Assert-Localization 'LBS-32 non-readable path reports Unreadable not first run' (
        $unreadable.Status -eq 'Unreadable' -and
        $unreadable.FailureKind -eq 'ReadFailure' -and $unreadable.PersistenceBlocked
    )
    $script:SettingsDiagnosticsObserved = @()
    Load-AppSettings
    Assert-Localization 'LBS-32 I/O failure survives as application state and diagnostics' (
        $script:SettingsLoadState.Status -eq 'Unreadable' -and
        @($script:SettingsDiagnosticsObserved | Where-Object {
            $_.Event -eq 'SETTINGS_LOAD_FALLBACK' -and $_.Data.status -eq 'Unreadable'
        }).Count -eq 1
    )
    $noDirectoryOverwrite = $false
    try { Save-AppSettings } catch { $noDirectoryOverwrite = $true }
    Assert-Localization 'LBS-32 unreadable directory is preserved after rejected save' (
        $noDirectoryOverwrite -and (Test-Path -LiteralPath $script:SettingsPath -PathType Container)
    )
    Remove-Item -LiteralPath $script:SettingsPath -Recurse -Force
    Load-AppSettings
    Assert-Localization 'LBS-32 repaired missing path permits first-run saving' (
        $script:SettingsLoadState.Status -eq 'Missing'
    )
    $script:EntryAliases = @{ '{abcdef12-3456-7890-abcd-ef1234567890}' = 'Müller' }
    Save-AppSettings
    $savedBytes = [IO.File]::ReadAllBytes($script:SettingsPath)
    $savedText = [IO.File]::ReadAllText($script:SettingsPath, [Text.Encoding]::UTF8)
    Assert-Localization 'LBS-32 repaired settings persist as UTF-8 without BOM' (
        $savedBytes.Length -gt 2 -and
        -not ($savedBytes[0] -eq 0xEF -and $savedBytes[1] -eq 0xBB -and $savedBytes[2] -eq 0xBF) -and
        $savedText.Contains('Müller') -and -not (Test-Path -LiteralPath ($script:SettingsPath + '.tmp'))
    )

    Assert-Localization 'English and German catalogs have identical key sets' (Test-LocalizationCatalogParityCore)
    Assert-Localization 'Named localization formatting is deterministic' ((Get-LocalizedStringCore -Key 'Storage.InternalSsdModel' -Locale 'en-US' -Values @{ Model='TEST' }) -eq 'Internal SSD: TEST')
}
finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    try { if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force } } catch { }
}

Write-Host "LOCALIZATION TOTAL $checks/84"
if ($checks -ne 84) { throw "Expected 84 localization checks, got $checks" }
