#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, json, re, sys

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
OUTPUT_NAME = 'CATCH_AUDIT_v0.5.9.1.json'
ALLOWED = {
    'cleanup_best_effort',
    'presentation_best_effort',
    'telemetry_best_effort',
    'optional_probe_best_effort',
    'cache_metadata_best_effort',
    'legacy_cleanup_best_effort',
    'self_repair_best_effort',
    'migration_persistence_best_effort',
    'migration_autostart_best_effort',
    'lifecycle_race_best_effort',
}

def classify(rel: str, line: str) -> tuple[str, str]:
    low = line.lower()
    cleanup_tokens = ['.dispose()', '.stop()', '.kill()', '.releasemutex()', '.close()', 'remove-item', '.hide(']
    if any(t in low for t in cleanup_tokens):
        return 'cleanup_best_effort', 'Cleanup/dispose failure must not replace the primary operation result.'
    if rel.endswith('RuntimeDiagnostics.ps1'):
        return 'telemetry_best_effort', 'Diagnostics are observational and must never break product behavior.'
    if rel.startswith('src/UI/'):
        return 'presentation_best_effort', 'Non-critical presentation/tooltip/notification failure is tolerated.'
    if rel.endswith('Storage.ps1'):
        return 'optional_probe_best_effort', 'Optional storage metadata/probe failure degrades enrichment only.'
    if rel.endswith('TaskBroker.ps1'):
        return 'cache_metadata_best_effort', 'Optional cache timestamp/diagnostic metadata failure is tolerated.'
    if rel.endswith('SettingsRepository.ps1'):
        return 'legacy_cleanup_best_effort', 'Legacy cleanup is non-blocking after canonical settings handling.'
    if rel.endswith('Autostart.ps1'):
        return 'self_repair_best_effort', 'Autostart self-repair is opportunistic and must not block the tray.'
    if 'save-appsettings' in low:
        return 'migration_persistence_best_effort', 'Legacy migration persistence failure is non-fatal and retryable.'
    if 'set-autostartenabled' in low:
        return 'migration_autostart_best_effort', 'Legacy autostart migration is best-effort and retryable.'
    return 'lifecycle_race_best_effort', 'Expected lifecycle/race cleanup failure is tolerated; primary path owns status/diagnostics.'

def collect(root: Path) -> dict:
    paths = [root/'src/App/LenovoBootMenuTray.template.ps1'] + sorted((root/'src/Application').glob('*.ps1')) + sorted((root/'src/Core').glob('*.ps1')) + sorted((root/'src/Infrastructure').glob('*.ps1')) + sorted((root/'src/UI').glob('*.ps1'))
    entries=[]
    pat=re.compile(r'catch\s*\{\s*\}')
    for p in paths:
        text=p.read_text(encoding='utf-8-sig')
        rel=p.relative_to(root).as_posix()
        for no,line in enumerate(text.splitlines(),1):
            if not pat.search(line):
                continue
            category,reason=classify(rel,line.strip())
            entries.append({'source':rel,'line':no,'category':category,'reason':reason,'code':line.strip()})
    return {
        'version':'0.5.9.1',
        'scope':'Inline empty/best-effort catch blocks in modular runtime source; generated runtime excluded.',
        'policy':'Every silent catch must be classified. Product-affecting failures must use explicit handling/diagnostics rather than this allowlist.',
        'allowed_categories':sorted(ALLOWED),
        'count':len(entries),
        'entries':entries,
    }

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--check',action='store_true'); args=ap.parse_args()
    root=args.root.resolve(); path=root/OUTPUT_NAME
    data=collect(root); rendered=(json.dumps(data,ensure_ascii=False,indent=2,sort_keys=False)+'\n').encode('utf-8')
    if args.check:
        if not path.is_file() or path.read_bytes()!=rendered:
            print(f'FAIL {OUTPUT_NAME} differs from current source',file=sys.stderr); return 1
        print(f'PASS {OUTPUT_NAME} covers {data["count"]} inline silent catches'); return 0
    path.write_bytes(rendered); print(path); return 0
if __name__=='__main__': raise SystemExit(main())
