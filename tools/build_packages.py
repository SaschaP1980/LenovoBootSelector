#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
VERSION='0.5.9.0'
STAMP=(2026,10,5,0,0,0)
RELEASE_NAMES=[
    'BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico',
    'LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs',
    'Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1'
]

def write_zip(path:Path, entries:list[tuple[str,bytes]]):
    path.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in entries:
            zi=zipfile.ZipInfo(name,STAMP)
            zi.create_system=3
            zi.external_attr=(0o100644 << 16)
            zi.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(zi,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)

def source_entries(root:Path):
    excluded_parts={'.git','__pycache__'}
    out=[]
    for p in root.rglob('*'):
        if not p.is_file(): continue
        rel=p.relative_to(root).as_posix()
        if any(part in excluded_parts for part in p.relative_to(root).parts): continue
        if rel.endswith('.pyc') or rel.endswith('.zip'): continue
        out.append((rel,p.read_bytes()))
    return sorted(out,key=lambda x:x[0])

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--output-dir',type=Path,required=True); args=ap.parse_args()
    root=args.root.resolve(); out=args.output_dir.resolve()
    check=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'])
    if check.returncode: return check.returncode
    release=out/f'LenovoBootMenuTray-v{VERSION}.zip'
    source=out/f'Lenovo-Boot-Selector-Source-v{VERSION}.zip'
    write_zip(release,[(n,(root/n).read_bytes()) for n in RELEASE_NAMES])
    write_zip(source,source_entries(root))
    print(release); print(source)
    return 0

if __name__=='__main__': raise SystemExit(main())
