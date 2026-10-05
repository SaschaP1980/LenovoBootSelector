#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, zipfile
from release_common import STAMP, load_version, release_zip_name, source_zip_name

def sha(b:bytes)->str: return hashlib.sha256(b).hexdigest()
def source_files(root:Path):
    for p in sorted(root.rglob('*')):
        if not p.is_file(): continue
        rel=p.relative_to(root).as_posix()
        if '.git' in p.parts or '__pycache__' in p.parts or rel.endswith('.pyc') or rel.endswith('.zip'): continue
        yield rel,p.read_bytes()
def write_zip(path:Path,entries:list[tuple[str,bytes]]):
    path.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in entries:
            zi=zipfile.ZipInfo(name,STAMP); zi.create_system=3; zi.external_attr=(0o100644<<16); zi.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(zi,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,required=True); ap.add_argument('--release-dir',type=Path,required=True); ap.add_argument('--handover-dir',type=Path,required=True); ap.add_argument('--output',type=Path,required=True); args=ap.parse_args()
    version=load_version(args.root.resolve())
    handover=[f'Lenovo-Boot-Menu-Tray-Validation-v{version}.txt',f'Lenovo-Boot-Selector-Full-Handover-v{version}.md',f'Lenovo-Boot-Selector-Initial-Prompt-v{version}.txt',f'Lenovo-Boot-Selector-Open-Build-Plan-after-v{version}.md']
    releases=[source_zip_name(version),release_zip_name(version)]
    entries=[]
    for n in handover: entries.append((f'HANDOVER/{n}',(args.handover_dir/n).read_bytes()))
    for n in releases: entries.append((f'RELEASE/{n}',(args.release_dir/n).read_bytes()))
    for rel,data in source_files(args.root): entries.append((f'SOURCE/{rel}',data))
    entries=sorted(entries,key=lambda x:x[0]); manifest=''.join(f'{sha(data)}  {name}\n' for name,data in entries).encode('utf-8')
    write_zip(args.output,[('MANIFEST-SHA256.txt',manifest)]+entries); print(args.output); return 0
if __name__=='__main__': raise SystemExit(main())
