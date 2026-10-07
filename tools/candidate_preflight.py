#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse,json,shutil,subprocess,sys,tempfile
from release_common import load_release_config,release_zip_name,source_zip_name
from protected_fragments import changed_protected_fragments

ROOT_DEFAULT=Path(__file__).resolve().parents[1]

def run(cmd:list[str],cwd:Path|None=None,capture:bool=False)->subprocess.CompletedProcess:
    cp=subprocess.run(cmd,cwd=str(cwd) if cwd else None,text=True,capture_output=capture)
    if cp.returncode:
        if capture:
            if cp.stdout: print(cp.stdout,end='',file=sys.stderr)
            if cp.stderr: print(cp.stderr,end='',file=sys.stderr)
        raise RuntimeError('command failed: '+' '.join(cmd))
    return cp

def git(root:Path,*args:str)->str:
    return run(['git','-C',str(root),*args],capture=True).stdout.strip()

def verify_repository_delta(root:Path,main_ref:str,cfg:dict,mode:str='candidate')->dict:
    if git(root,'status','--porcelain','--untracked-files=all'):
        raise RuntimeError('validation working tree is not clean')
    candidate_sha=git(root,'rev-parse','HEAD')
    main_sha=git(root,'rev-parse',main_ref)
    if mode=='candidate':
        cp=subprocess.run(['git','-C',str(root),'merge-base','--is-ancestor',main_ref,'HEAD'])
        if cp.returncode:
            raise RuntimeError(f'candidate is not based on current canonical main {main_sha}')
    elif mode!='development-completion':
        raise RuntimeError(f'unsupported preflight mode: {mode}')

    rows=[x for x in git(root,'diff','--name-status','--no-renames',main_ref,'HEAD').splitlines() if x]
    deleted=sorted(row.split('\t',1)[1] for row in rows if row.startswith('D\t'))
    declared=sorted(cfg.get('repositoryDeleteIntent',[]))
    if deleted!=declared:
        raise RuntimeError(f'repositoryDeleteIntent mismatch: actual={deleted!r} declared={declared!r}')

    zip_rows=[row for row in rows if '\tdownloads/' in row and row.lower().endswith('.zip')]
    if zip_rows:
        raise RuntimeError('candidate must not modify historical release ZIPs before publication: '+repr(zip_rows))
    return {'candidateSha':candidate_sha,'mainSha':main_sha,'deletedPaths':deleted}

def copy_candidate(root:Path,target:Path)->None:
    def ignore(path,names):
        ignored={'.git','__pycache__'}
        ignored.update(x for x in names if x.endswith('.pyc'))
        return ignored.intersection(names)
    shutil.copytree(root,target,ignore=ignore)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',type=Path,default=ROOT_DEFAULT)
    ap.add_argument('--basis-root',type=Path,required=True)
    ap.add_argument('--main-ref',default='origin/main')
    ap.add_argument('--published-utc',default='2000-01-01T00:00:00Z')
    ap.add_argument('--mode',choices=['candidate','development-completion'],default='candidate')
    args=ap.parse_args()
    root=args.root.resolve()
    basis=args.basis_root.resolve()
    try:
        cfg=load_release_config(root)
        delta=verify_repository_delta(root,args.main_ref,cfg,args.mode)

        with tempfile.TemporaryDirectory(prefix='lbs-candidate-preflight-') as td:
            temp=Path(td)
            work=temp/'candidate'
            out1=temp/'build-a'
            out2=temp/'build-b'
            copy_candidate(root,work)

            run([sys.executable,'-B',str(work/'tools/prepare_release.py'),'--root',str(work),'--output-dir',str(out1),'--published-utc',args.published_utc])
            run([sys.executable,'-B',str(work/'tools/prepare_release.py'),'--root',str(work),'--output-dir',str(out2),'--published-utc',args.published_utc,'--check'])

            version=cfg['version']
            release_name=release_zip_name(version)
            source_name=source_zip_name(version)
            if (out1/release_name).read_bytes()!=(out2/release_name).read_bytes():
                raise RuntimeError('candidate release package is not reproducible')
            if (out1/source_name).read_bytes()!=(out2/source_name).read_bytes():
                raise RuntimeError('candidate source package is not reproducible')

            actual=changed_protected_fragments(work,basis)
            declared=sorted(cfg.get('protectedFragmentIntent',[]))
            if actual!=declared:
                raise RuntimeError(f'protectedFragmentIntent mismatch: actual={actual!r} declared={declared!r}')

            run([sys.executable,'-B',str(work/'tools/validate_test_contracts.py'),'--root',str(work)])
            run([sys.executable,'-B',str(work/'tests/validate_release.py'),'--root',str(work)])
            run([sys.executable,'-B',str(work/'tests/validate_core.py'),'--root',str(work),'--basis-root',str(basis)])
            run([sys.executable,'-B',str(work/'tests/validate_boundary.py'),'--root',str(work)])
            run([sys.executable,'-B',str(work/'tests/validate_regression.py'),'--root',str(work),'--basis-root',str(basis),'--release-zip',str(out1/release_name)])

            report={
                'version':version,
                'mode':args.mode,
                'candidateSha':delta['candidateSha'],
                'testedSha':delta['candidateSha'],
                'mainSha':delta['mainSha'],
                'protectedFragmentIntent':declared,
                'repositoryDeleteIntent':delta['deletedPaths'],
                'contractPropagation':'PASS',
                'releasePackage':release_name,
                'sourcePackage':source_name,
                'result':'PASS',
            }
            compact=json.dumps(report,ensure_ascii=False,separators=(',',':'),sort_keys=True)
            print('CANDIDATE PREFLIGHT PASS')
            print('CANDIDATE_PREFLIGHT_SUMMARY='+compact)
        return 0
    except Exception as e:
        print(f'CANDIDATE PREFLIGHT FAIL: {e}',file=sys.stderr)
        return 1

if __name__=='__main__':
    raise SystemExit(main())
