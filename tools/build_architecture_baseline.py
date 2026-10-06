#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse,json,re,sys
from release_common import load_version
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
OUTPUT_NAME='ARCHITECTURE_BASELINE.json'

def metrics(text:str)->dict:
    refs=re.findall(r'\$script:([A-Za-z0-9_]+)',text,re.I)
    return {'lines':len(text.splitlines()),'functions':len(re.findall(r'(?m)^\s*function\s+[A-Za-z0-9_-]+\b',text,re.I)),'scriptReferences':len(refs)}
def section(root:Path,name:str)->dict:
    files=sorted((root/'src'/name).glob('*.ps1')); texts=[p.read_text(encoding='utf-8-sig') for p in files]
    return {'files':len(files),'lines':sum(len(t.splitlines()) for t in texts),'functions':sum(len(re.findall(r'(?m)^\s*function\s+[A-Za-z0-9_-]+\b',t,re.I)) for t in texts),'scriptReferences':sum(len(re.findall(r'\$script:([A-Za-z0-9_]+)',t,re.I)) for t in texts)}
def collect(root:Path)->dict:
    tray=(root/'bin/LenovoBootMenuTray.ps1').read_text(encoding='utf-8-sig'); tm=metrics(tray); refs=re.findall(r'\$script:([A-Za-z0-9_]+)',tray,re.I)
    runtime={**tm,'scriptVariables':len({x.lower() for x in refs}),'catchBlocks':len(re.findall(r'\bcatch\s*\{',tray,re.I)),'inlineSilentCatches':len(re.findall(r'catch\s*\{\s*\}',tray,re.I))}
    return {'version':load_version(root),'runtime':runtime,'core':section(root,'Core'),'application':section(root,'Application'),'infrastructure':section(root,'Infrastructure'),'ui':section(root,'UI'),'appTemplate':metrics((root/'src/App/LenovoBootMenuTray.template.ps1').read_text(encoding='utf-8-sig'))}
def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--check',action='store_true'); args=ap.parse_args(); root=args.root.resolve(); path=root/OUTPUT_NAME; data=collect(root); rendered=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
    if args.check:
        if not path.is_file() or path.read_bytes()!=rendered: print(f'FAIL {OUTPUT_NAME} differs from current source',file=sys.stderr); return 1
        print(f'PASS {OUTPUT_NAME} matches current source'); return 0
    path.write_bytes(rendered); print(path); return 0
if __name__=='__main__': raise SystemExit(main())
