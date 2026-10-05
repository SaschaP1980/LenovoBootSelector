#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,tempfile
from release_common import load_release_config,release_zip_name,source_zip_name

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
INTEGRITY_NAMES=['icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1']

def sha(path:Path)->str: return hashlib.sha256(path.read_bytes()).hexdigest()
def render_integrity(root:Path,version:str)->bytes:
    lines=[f'Lenovo Boot Selector v{version} - Build Integrity','Generated: 2026-10-05','']+[f'{sha(root/n)}  {n}' for n in INTEGRITY_NAMES]
    return ('\n'.join(lines)+'\n').encode('utf-8')
def update_readme(root:Path,version:str,check:bool):
    p=root/'README.md'; s=p.read_text(encoding='utf-8-sig'); import re
    expected=f'**Aktueller Entwicklungsstand:** v{version}  '
    new,n=re.subn(r'\*\*Aktueller Entwicklungsstand:\*\* v[^\s]+  ',expected,s,count=1)
    if n!=1: raise RuntimeError('README current-development marker missing or ambiguous')
    if check:
        if s!=new: raise RuntimeError('README current version is not canonical')
    else: p.write_text(new,encoding='utf-8-sig')
def require_changelog(root:Path,version:str):
    if f'## v{version} ' not in (root/'CHANGELOG.md').read_text(encoding='utf-8-sig'): raise RuntimeError(f'CHANGELOG missing v{version} section')
def run(*args):
    cp=subprocess.run([sys.executable,*map(str,args)]); 
    if cp.returncode: raise RuntimeError(f'command failed: {args}')
def resolve_published_utc(cfg:dict,explicit:str|None)->str:
    published=(explicit or cfg.get('publishedUtc') or '').strip()
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z',published):
        raise RuntimeError('publishedUtc must be supplied explicitly for schemaVersion 2')
    return published

def update_download_metadata(root:Path,cfg:dict,published_utc:str,release_hash:str,release_size:int,check:bool):
    version=cfg['version']; tag=f'v{version}'; file=release_zip_name(version)
    latest_path=root/'downloads/latest.json'; latest=json.loads(latest_path.read_text(encoding='utf-8'))
    expected=dict(latest); expected.update(version=version,tag=tag,file=file,sha256=release_hash,size=release_size,publishedUtc=published_utc)
    if check:
        for k in ['version','tag','file','sha256','size','publishedUtc']:
            if latest.get(k)!=expected[k]: raise RuntimeError(f'downloads/latest.json mismatch for {k}')
    else: latest_path.write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    releases_path=root/'downloads/releases.json'; data=json.loads(releases_path.read_text(encoding='utf-8')); rows=[r for r in data['releases'] if str(r.get('version'))!=version]; rows.insert(0,expected); expected_releases={'schemaVersion':data.get('schemaVersion',1),'releases':rows}
    if check:
        if data!=expected_releases: raise RuntimeError('downloads/releases.json is not canonical')
    else: releases_path.write_text(json.dumps(expected_releases,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    readme_path=root/'downloads/README.md'; text=readme_path.read_text(encoding='utf-8-sig'); lines=[line for line in text.splitlines() if not line.startswith(f'| v{version} |')]; marker='| --- | --- | ---: | --- | --- |'; idx=lines.index(marker)+1; row=f'| v{version} | [{file}]({file}) | {release_size:,} Bytes | `{release_hash}` | `{tag}` |'.replace(',', '.') ; lines.insert(idx,row); rendered='\n'.join(lines)+'\n'
    if check:
        if text!=rendered: raise RuntimeError('downloads/README.md is not canonical')
    else: readme_path.write_text(rendered,encoding='utf-8-sig')
def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--output-dir',type=Path,required=True); ap.add_argument('--published-utc'); ap.add_argument('--check',action='store_true'); args=ap.parse_args(); root=args.root.resolve(); out=args.output_dir.resolve(); out.mkdir(parents=True,exist_ok=True); cfg=load_release_config(root); version=cfg['version']
    try:
        published_utc=resolve_published_utc(cfg,args.published_utc); require_changelog(root,version); update_readme(root,version,args.check)
        if args.check:
            run(root/'tools/build_runtime.py','--root',root,'--check'); run(root/'tools/build_catch_audit.py','--root',root,'--check'); run(root/'tools/build_architecture_baseline.py','--root',root,'--check')
            expected_integrity=render_integrity(root,version)
            if not (root/'BUILD_INTEGRITY.txt').is_file() or (root/'BUILD_INTEGRITY.txt').read_bytes()!=expected_integrity: raise RuntimeError('BUILD_INTEGRITY.txt is not canonical')
        else:
            run(root/'tools/build_runtime.py','--root',root); run(root/'tools/build_catch_audit.py','--root',root); run(root/'tools/build_architecture_baseline.py','--root',root); (root/'BUILD_INTEGRITY.txt').write_bytes(render_integrity(root,version))
        run(root/'tools/build_packages.py','--root',root,'--output-dir',out,'--kind','release')
        release=out/release_zip_name(version); release_hash=sha(release); release_size=release.stat().st_size
        update_download_metadata(root,cfg,published_utc,release_hash,release_size,args.check)
        if not args.check:
            # Metadata changed after release creation but is not part of the runtime package. Build source only after metadata is canonical.
            pass
        run(root/'tools/build_packages.py','--root',root,'--output-dir',out,'--kind','source')
        source=out/source_zip_name(version); summary={'version':version,'releaseProfile':cfg['releaseProfile'],'publishedUtc':published_utc,'release':{'file':release.name,'sha256':release_hash,'size':release_size},'source':{'file':source.name,'sha256':sha(source),'size':source.stat().st_size}}
        (out/'release-build.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(summary,ensure_ascii=False)); return 0
    except Exception as e:
        print(f'FAIL prepare_release: {e}',file=sys.stderr); return 1
if __name__=='__main__': raise SystemExit(main())
