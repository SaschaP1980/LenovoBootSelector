#!/usr/bin/env python3
from pathlib import Path
import argparse, sys
ROOT_DEFAULT=Path(__file__).resolve().parents[1]

def txt(p): return Path(p).read_text(encoding='utf-8-sig') if Path(p).is_file() else ''

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root.resolve()
    core=txt(root/'src/Core/UpdateModel.ps1'); native=txt(root/'tests/Test-UpdateCore.ps1'); infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    rows=[]
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    rows.append(('App version 0.5.7', "$script:AppVersion = '0.5.7'" in tray))
    rows.append(('Version declaration exactly once', tray.count("$script:AppVersion = '0.5.7'")==1))
    rows.append(('Normalized manifest preserves schema version', 'SchemaVersion = 1' in core))
    rows.append(('Native test asserts normalized schema version', "Normalized manifest schema version" in native))
    rows.append(('Native test covers JSON roundtrip', 'Manifest survives worker JSON roundtrip' in native))
    rows.append(('Worker still performs first validation', 'Test-LenovoUpdateManifestCore -Manifest $raw' in infra))
    rows.append(('Tray path still performs second validation', 'Test-LenovoUpdateManifestCore -Manifest $result.Manifest' in txt(root/'src/UI/UpdatePresentation.ps1')))
    for n,o in rows: print(('PASS  ' if o else 'FAIL  ')+n)
    p=sum(o for _,o in rows); print(f'\nTOTAL {p}/{len(rows)}')
    return 0 if p==len(rows) else 1
if __name__=='__main__': raise SystemExit(main())
