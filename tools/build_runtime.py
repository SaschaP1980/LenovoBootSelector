#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, sys

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
INCLUDES = [
    'src/UI/StartupRecoveryDialog.ps1',
    'src/Application/MaintenanceRuntime.ps1',
    'src/Application/BootTargetDrift.ps1',
    'src/UI/MenuAppearance.ps1',
    'src/UI/RefreshPresentation.ps1',
    'src/Infrastructure/RuntimeDiagnostics.ps1',
    'src/UI/DiagnosticsPresentation.ps1',
    'src/Infrastructure/Autostart.ps1',
    'src/UI/AutostartPresentation.ps1',
    'src/Core/EntryPreferences.ps1',
    'src/UI/ManageEntriesState.ps1',
    'src/Infrastructure/SettingsRepository.ps1',
    'src/Application/SettingsService.ps1',
    'src/UI/ManageEntries.ps1',
    'src/UI/DefaultTargetPresentation.ps1',
    'src/UI/DefaultTargetMenu.ps1',
    'src/UI/Dialogs.ps1',
    'src/UI/MaintenancePresentation.ps1',
    'src/Infrastructure/TaskBroker.ps1',
    'src/Infrastructure/Storage.ps1',
    'src/Core/BootTargetModel.ps1',
    'src/Core/FirmwareParsing.ps1',
    'src/Core/BootTargetDrift.ps1',
    'src/Application/BootService.ps1',
    'src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Application/RefreshRuntime.ps1',
    'src/UI/BootEntryList.ps1',
    'src/UI/Popup.ps1',
]

def render(root: Path) -> bytes:
    template = (root / 'src/App/LenovoBootMenuTray.template.ps1').read_text(encoding='utf-8-sig')
    for rel in INCLUDES:
        marker = f'# @include {rel}'
        count = template.count(marker)
        if count != 1:
            raise RuntimeError(f'{marker}: expected exactly once, found {count}')
        module = (root / rel).read_text(encoding='utf-8-sig').rstrip() + '\n'
        template = template.replace(marker, module, 1)
    if '# @include ' in template:
        raise RuntimeError('unresolved include marker remains')
    return b'\xef\xbb\xbf' + template.encode('utf-8')

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=ROOT_DEFAULT)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    root = args.root.resolve()
    output = root / 'LenovoBootMenuTray.ps1'
    rendered = render(root)
    if args.check:
        if not output.is_file() or output.read_bytes() != rendered:
            print('FAIL generated LenovoBootMenuTray.ps1 differs from modular source', file=sys.stderr)
            return 1
        print('PASS generated LenovoBootMenuTray.ps1 matches modular source')
        return 0
    output.write_bytes(rendered)
    print(output)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
