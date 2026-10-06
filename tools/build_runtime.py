#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, re, sys
from release_common import load_version

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
VERSION_TOKEN='@APP_VERSION@'
INCLUDE_RE=re.compile(r'(?m)^# @include ([^\r\n]+)$')

def template_include_paths(root:Path,template:str|None=None)->list[str]:
    if template is None:
        template=(root/'src/App/LenovoBootMenuTray.template.ps1').read_text(encoding='utf-8-sig')
    includes=[m.group(1).strip() for m in INCLUDE_RE.finditer(template)]
    if not includes:
        raise RuntimeError('runtime template contains no include markers')
    if len(includes)!=len(set(includes)):
        duplicates=sorted({x for x in includes if includes.count(x)>1})
        raise RuntimeError(f'duplicate runtime include marker(s): {duplicates}')
    for rel in includes:
        p=Path(rel)
        if p.is_absolute() or '..' in p.parts or not rel.startswith('src/') or p.suffix.lower()!='.ps1':
            raise RuntimeError(f'invalid runtime include path: {rel}')
        if not (root/p).is_file():
            raise RuntimeError(f'runtime include file missing: {rel}')
    return includes

def render(root: Path) -> bytes:
    version=load_version(root)
    template=(root/'src/App/LenovoBootMenuTray.template.ps1').read_text(encoding='utf-8-sig')
    count=template.count(VERSION_TOKEN)
    if count!=1: raise RuntimeError(f'{VERSION_TOKEN}: expected exactly once, found {count}')
    includes=template_include_paths(root,template)
    template=template.replace(VERSION_TOKEN,version,1)
    for rel in includes:
        marker=f'# @include {rel}'
        count=template.count(marker)
        if count!=1: raise RuntimeError(f'{marker}: expected exactly once, found {count}')
        module=(root/rel).read_text(encoding='utf-8-sig').rstrip()+'\n'
        template=template.replace(marker,module,1)
    if '# @include ' in template: raise RuntimeError('unresolved include marker remains')
    if VERSION_TOKEN in template: raise RuntimeError('unresolved version token remains')
    return b'\xef\xbb\xbf'+template.encode('utf-8')

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',type=Path,default=ROOT_DEFAULT)
    ap.add_argument('--check',action='store_true')
    ap.add_argument('--list-includes',action='store_true')
    args=ap.parse_args()
    root=args.root.resolve()
    if args.list_includes:
        for rel in template_include_paths(root):
            print(rel)
        return 0
    output=root/'bin/LenovoBootMenuTray.ps1'
    rendered=render(root)
    if args.check:
        if not output.is_file() or output.read_bytes()!=rendered:
            print('FAIL generated LenovoBootMenuTray.ps1 differs from modular source',file=sys.stderr)
            return 1
        print('PASS generated LenovoBootMenuTray.ps1 matches modular source')
        return 0
    output.write_bytes(rendered)
    print(output)
    return 0
if __name__=='__main__': raise SystemExit(main())
