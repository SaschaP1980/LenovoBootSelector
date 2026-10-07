#!/usr/bin/env python3
from pathlib import Path
import argparse, sys

ROOT_DEFAULT = Path(__file__).resolve().parents[1]

class Suite:
    def __init__(self):
        self.rows = []
    def check(self, name, cond, detail=''):
        self.rows.append((name, bool(cond), detail))
    def contains(self, name, text, needle):
        self.check(name, needle in text, needle)
    def absent(self, name, text, needle):
        self.check(name, needle not in text, needle)
    def done(self):
        for name, ok, detail in self.rows:
            print(('PASS  ' if ok else 'FAIL  ') + name + (f' [{detail}]' if detail and not ok else ''))
        passed = sum(ok for _, ok, _ in self.rows)
        total = len(self.rows)
        print(f'\nTOTAL {passed}/{total}')
        return 0 if passed == total else 1

def txt(path: Path) -> str:
    return path.read_text(encoding='utf-8-sig')

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=ROOT_DEFAULT)
    args = ap.parse_args()
    root = args.root.resolve()
    s = Suite()

    entry = txt(root/'src/Core/EntryPreferences.ps1')
    settings = txt(root/'src/Application/SettingsService.ps1')
    localization_service = txt(root/'src/Application/LocalizationService.ps1')
    startup = txt(root/'src/UI/StartupRecoveryDialog.ps1')
    language_ui = txt(root/'src/UI/LanguagePresentation.ps1')
    template = txt(root/'src/App/LenovoBootSelector.template.ps1')
    catalog = txt(root/'src/Core/Localization.ps1')
    native = txt(root/'tests/Test-LocalizationRuntime.ps1')
    docs = txt(root/'docs/LOCALIZATION.md')

    s.absent('Legacy pre-localization settings no longer force German', entry, "if ($SourceSchemaVersion -lt 5) { return 'de-DE' }")
    s.contains('Settings schema advances to v6', entry, 'schemaVersion = 6')
    s.contains('Default locale preference source is explicit metadata', entry, "localePreferenceSource = 'default'")
    s.contains('Core can derive locale preference source', entry, 'function Get-AppSettingsLocalePreferenceSourceCore')
    s.contains('Core models ambiguous v0.8.0.0 German state explicitly', entry, "'migration-pending'")
    s.contains('Core exposes confirmation requirement', entry, 'function Test-AppSettingsLocaleConfirmationRequiredCore')
    s.contains('Normalized settings carry locale preference source', entry, 'localePreferenceSource = $preferenceSource')
    s.contains('Normalized settings carry confirmation state', entry, "localePreferenceNeedsConfirmation = ($preferenceSource -eq 'migration-pending')")

    s.contains('Settings persistence writes schema v6', settings, 'schemaVersion = 6')
    s.contains('Settings persistence writes locale preference source', settings, 'localePreferenceSource = $preferenceSource')
    s.contains('Settings load restores preference source', settings, '$script:LocalePreferenceSource = [string]$settings.localePreferenceSource')
    s.contains('Settings load restores confirmation state', settings, '$script:LocalePreferenceNeedsConfirmation = [bool]$settings.localePreferenceNeedsConfirmation')

    s.contains('Explicit language selection records user preference', localization_service, "$script:LocalePreferenceSource = 'user'")
    s.contains('Explicit selection persists even when locale is unchanged', localization_service, 'if ($Persist) {')

    s.absent('Startup recovery no longer hard-codes legacy German migration', startup, "if ($sourceSchema -lt 5) { return 'de-DE' }")
    s.contains('Startup recovery reuses canonical locale resolution', startup, 'Get-AppSettingsLocaleCore -Source $source -SourceSchemaVersion $sourceSchema')

    s.contains('Language UI resolves pending locale preference', language_ui, 'function Resolve-PendingLocalePreference')
    s.contains('Pending resolution uses dedicated choice dialog', language_ui, 'Show-LocaleMigrationDialog')
    s.contains('English correction is explicitly persisted', language_ui, "Set-ActiveLocale -Locale $choice -Persist")

    s.contains('Localization catalog has migration prompt title', catalog, "'Language.MigrationTitle'")
    s.contains('Localization catalog has English choice', catalog, "'Language.MigrationUseEnglish'")
    s.contains('Localization catalog has German choice', catalog, "'Language.MigrationKeepGerman'")

    entry_marker = '# @include src/Core/EntryPreferences.ps1'
    startup_marker = '# @include src/UI/StartupRecoveryDialog.ps1'
    s.check('EntryPreferences is available before startup recovery', template.find(entry_marker) >= 0 and template.find(entry_marker) < template.find(startup_marker))
    s.contains('Startup resolves ambiguous locale before UI construction', template, '[void](Resolve-PendingLocalePreference)')

    s.contains('Native test covers pre-localization English migration', native, 'Pre-localization schema migrates to en-US')
    s.contains('Native test covers startup-recovery English migration', native, 'Startup recovery uses en-US for pre-localization settings')
    s.contains('Native test covers ambiguous v0.8.0.0 state', native, 'v0.8.0.0 migrated German requires confirmation')
    s.contains('Native test covers same-locale explicit German confirmation', native, 'Explicit German confirmation persists user choice')
    s.contains('Native test covers one-time English correction', native, 'v0.8.0.0 migrated German can be corrected to English once')
    s.contains('Native test covers later explicit German choice', native, 'Later explicit German choice survives reload')
    s.contains('Localization docs define English pre-localization migration', docs, 'Pre-localization settings without an explicit locale migrate to `en-US`.')
    s.contains('Localization docs define ambiguous v0.8.0.0 handling', docs, 'migration-pending')

    return s.done()

if __name__ == '__main__':
    raise SystemExit(main())
