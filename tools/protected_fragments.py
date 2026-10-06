#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json,re

def read_text(path:Path)->str:
    return path.read_text(encoding='utf-8-sig')

def ps_function(source:str,name:str)->str|None:
    m=re.search(rf'(?m)^function\s+{re.escape(name)}\b',source)
    if not m:
        return None
    n=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',source[m.end():])
    end=m.end()+n.start() if n else len(source)
    return source[m.start():end].rstrip()+'\n'

def balanced_fragment(source:str,marker:str)->str|None:
    try:
        start=source.index(marker)
        brace=source.index('{',start)
    except ValueError:
        return None
    depth=0
    i=brace
    sq=dq=False
    esc=False
    while i<len(source):
        c=source[i]
        if esc:
            esc=False
        elif ord(c)==96:
            esc=True
        elif sq:
            if c=="'":
                sq=False
        elif dq:
            if c=='"':
                dq=False
        else:
            if c=="'":
                sq=True
            elif c=='"':
                dq=True
            elif c=='{':
                depth+=1
            elif c=='}':
                depth-=1
                if depth==0:
                    return source[start:i+1]+'\n'
        i+=1
    return None

def protected_keys(root:Path)->list[str]:
    baseline=root/'tests/characterization-baseline-v0.3.4.json'
    data=json.loads(baseline.read_text(encoding='utf-8'))
    keys=list(data.get('critical_fragment_sha256',{}).keys())
    if not keys:
        raise RuntimeError('protected fragment baseline contains no critical fragments')
    return keys

def extract_fragment(runtime_text:str,key:str)->str|None:
    kind,name=key.split(':',1)
    if kind=='ps':
        return ps_function(runtime_text,name)
    if kind=='cs':
        return balanced_fragment(runtime_text,name)
    raise RuntimeError(f'unsupported protected fragment kind: {kind}')

def changed_protected_fragments(candidate_root:Path,basis_root:Path)->list[str]:
    candidate=read_text(candidate_root/'bin/LenovoBootMenuTray.ps1')
    basis=read_text(basis_root/'bin/LenovoBootMenuTray.ps1')
    changed=[]
    for key in protected_keys(candidate_root):
        if extract_fragment(candidate,key)!=extract_fragment(basis,key):
            changed.append(key)
    return sorted(changed)
