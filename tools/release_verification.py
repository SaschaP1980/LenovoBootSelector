#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys,time

EXPECTED_RELEASE_CONTEXTS=(
    'release/source-integrity',
    'release/core',
    'release/boundary',
    'release/regression',
    'release/package',
    'release/reproducibility',
    'release/history',
    'release/tag',
)

EXPECTED_CANDIDATE_CONTEXTS=(
    'preflight/candidate',
    'preflight/linux',
    'preflight/windows-powershell51',
)

def run(args:list[str], *, cwd:Path|None=None, text:bool=True, check:bool=True):
    cp=subprocess.run(args,cwd=str(cwd) if cwd else None,capture_output=True,text=text)
    if check and cp.returncode:
        stderr=cp.stderr if text else cp.stderr.decode('utf-8','replace')
        raise RuntimeError(f"command failed ({cp.returncode}): {' '.join(args)}\n{stderr}")
    return cp

def git(root:Path,*args:str)->str:
    return run(['git','-C',str(root),*args]).stdout.strip()

def gh_json(repo:str,path:str):
    cp=run(['gh','api',f'repos/{repo}/{path}'])
    return json.loads(cp.stdout)

def require(condition:bool,message:str):
    if not condition:
        raise RuntimeError(message)

def release_status_map(payload:dict)->dict[str,str]:
    latest={}
    for row in payload.get('statuses',[]):
        context=str(row.get('context',''))
        if context in EXPECTED_RELEASE_CONTEXTS and context not in latest:
            latest[context]=str(row.get('state',''))
    return latest

def validate_release_statuses(payload:dict)->dict:
    latest=release_status_map(payload)
    require(set(latest)==set(EXPECTED_RELEASE_CONTEXTS),
            f'release status contexts mismatch: {sorted(latest)}')
    failed={k:v for k,v in latest.items() if v!='success'}
    require(not failed,f'release status contexts not successful: {failed}')
    return {
        'expected':len(EXPECTED_RELEASE_CONTEXTS),
        'success':len(EXPECTED_RELEASE_CONTEXTS),
        'contexts':list(EXPECTED_RELEASE_CONTEXTS),
    }

def candidate_status_map(payload:dict)->dict[str,str]:
    latest={}
    for row in payload.get('statuses',[]):
        context=str(row.get('context',''))
        if context in EXPECTED_CANDIDATE_CONTEXTS and context not in latest:
            latest[context]=str(row.get('state',''))
    return latest

def validate_candidate_statuses(payload:dict)->dict:
    latest=candidate_status_map(payload)
    require(set(latest)==set(EXPECTED_CANDIDATE_CONTEXTS),
            f'candidate status contexts mismatch: {sorted(latest)}')
    failed={k:v for k,v in latest.items() if v!='success'}
    require(not failed,f'candidate status contexts not successful: {failed}')
    return {
        'expected':len(EXPECTED_CANDIDATE_CONTEXTS),
        'success':len(EXPECTED_CANDIDATE_CONTEXTS),
        'contexts':list(EXPECTED_CANDIDATE_CONTEXTS),
    }

def branch_exists(root:Path,branch:str)->bool:
    cp=run(
        ['git','-C',str(root),'ls-remote','--exit-code','--heads','origin',f'refs/heads/{branch}'],
        check=False,
    )
    return cp.returncode==0

def wait_branch_deleted(root:Path,branch:str)->bool:
    for attempt in range(3):
        if not branch_exists(root,branch):
            return True
        if attempt<2:
            time.sleep(1)
    return False

def sha256_bytes(data:bytes)->str:
    return hashlib.sha256(data).hexdigest()

def self_test()->int:
    good={'statuses':[{'context':c,'state':'success'} for c in EXPECTED_RELEASE_CONTEXTS]}
    result=validate_release_statuses(good)
    require(result['expected']==8 and result['success']==8,'self-test expected 8/8')
    bad={'statuses':good['statuses'][:-1]}
    try:
        validate_release_statuses(bad)
    except RuntimeError:
        pass
    else:
        raise RuntimeError('self-test accepted missing release status')
    candidate_good={'statuses':[{'context':c,'state':'success'} for c in EXPECTED_CANDIDATE_CONTEXTS]}
    candidate_result=validate_candidate_statuses(candidate_good)
    require(candidate_result['expected']==3 and candidate_result['success']==3,'self-test expected 3/3 candidate gates')
    candidate_bad={'statuses':candidate_good['statuses'][:-1]}
    try:
        validate_candidate_statuses(candidate_bad)
    except RuntimeError:
        pass
    else:
        raise RuntimeError('self-test accepted missing candidate status')
    print('PASS release verification helper self-test')
    return 0

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument('--self-test',action='store_true')
    ap.add_argument('--root',type=Path)
    ap.add_argument('--version')
    ap.add_argument('--candidate-sha')
    ap.add_argument('--final-sha')
    ap.add_argument('--source-commit')
    ap.add_argument('--pr-url')
    ap.add_argument('--published-utc')
    ap.add_argument('--release-build-json',type=Path)
    ap.add_argument('--reproducibility-marker',type=Path)
    ap.add_argument('--output',type=Path)
    args=ap.parse_args()

    if args.self_test:
        try:
            return self_test()
        except Exception as e:
            print(f'FAIL release verification helper self-test: {e}',file=sys.stderr)
            return 1

    try:
        required={
            'root':args.root,'version':args.version,'candidate-sha':args.candidate_sha,
            'final-sha':args.final_sha,'source-commit':args.source_commit,
            'pr-url':args.pr_url,'published-utc':args.published_utc,
            'release-build-json':args.release_build_json,
            'reproducibility-marker':args.reproducibility_marker,'output':args.output,
        }
        missing=[k for k,v in required.items() if v is None or v=='']
        require(not missing,f'missing required arguments: {missing}')

        root=args.root.resolve()
        repo=os.environ.get('GITHUB_REPOSITORY','').strip()
        require(bool(re.fullmatch(r'[^/]+/[^/]+',repo)),f'invalid GITHUB_REPOSITORY: {repo!r}')
        pr_match=re.search(r'/pull/(\d+)(?:$|[/?#])',args.pr_url)
        require(pr_match is not None,f'invalid PR URL: {args.pr_url!r}')
        pr_number=int(pr_match.group(1))

        build=json.loads(args.release_build_json.read_text(encoding='utf-8'))
        require(build.get('version')==args.version,'release-build version mismatch')
        release=build.get('release') or {}
        source_package=build.get('source') or {}
        require(args.reproducibility_marker.is_file(),'reproducibility marker missing')

        git(root,'fetch','origin','main','--tags','--force')
        main_sha=git(root,'rev-parse','origin/main')

        pr=gh_json(repo,f'pulls/{pr_number}')
        require(pr.get('state')=='closed' and pr.get('merged_at'),'publication PR is not merged')
        require((pr.get('head') or {}).get('sha')==args.final_sha,'PR head SHA mismatch')
        merge_sha=str(pr.get('merge_commit_sha') or '')
        require(bool(merge_sha),'PR merge commit missing')
        require(run(['git','-C',str(root),'merge-base','--is-ancestor',merge_sha,'origin/main'],check=False).returncode==0,
                'PR merge commit is not contained in current main')

        owner=repo.split('/',1)[0]
        prs=gh_json(repo,f'pulls?state=all&head={owner}:release/v{args.version}&per_page=100')
        require(isinstance(prs,list) and len(prs)==1 and int(prs[0].get('number',0))==pr_number,
                f'expected exactly one publication PR, found {len(prs) if isinstance(prs,list) else "invalid"}')

        final_status_payload=gh_json(repo,f'commits/{args.final_sha}/status')
        release_statuses=validate_release_statuses(final_status_payload)

        candidate_status_payload=gh_json(repo,f'commits/{args.candidate_sha}/status')
        candidate_gates=validate_candidate_statuses(candidate_status_payload)

        source_tag=f'v{args.version}'
        tagged_source=git(root,'rev-parse',f'{source_tag}^{{commit}}')
        require(tagged_source==args.source_commit,'source tag does not resolve to expected source commit')
        source_paths=git(root,'ls-tree','-r','--name-only',args.source_commit).splitlines()
        source_zip_free=not any(p.lower().endswith('.zip') for p in source_paths)
        source_cache_free=not any('__pycache__/' in p or p.endswith('.pyc') for p in source_paths)
        require(source_zip_free,'source tree contains ZIP file')
        require(source_cache_free,'source tree contains Python cache artifact')

        latest=json.loads(git(root,'show','origin/main:downloads/latest.json'))
        expected_latest={
            'version':args.version,
            'tag':source_tag,
            'file':release.get('file'),
            'sha256':release.get('sha256'),
            'size':release.get('size'),
            'publishedUtc':args.published_utc,
        }
        for key,value in expected_latest.items():
            require(latest.get(key)==value,f'downloads/latest.json mismatch for {key}')

        release_file=str(release.get('file') or '')
        require(bool(release_file),'release file missing from build summary')
        main_release=run(
            ['git','-C',str(root),'show',f'origin/main:downloads/{release_file}'],
            text=False,
        ).stdout
        release_zip_consistent=(
            len(main_release)==int(release.get('size',-1)) and
            sha256_bytes(main_release)==release.get('sha256')
        )
        require(release_zip_consistent,'published release ZIP does not match build summary')

        candidate_branch=f'candidate/v{args.version}'
        release_branch=f'release/v{args.version}'
        candidate_deleted=wait_branch_deleted(root,candidate_branch)
        release_deleted=wait_branch_deleted(root,release_branch)
        require(candidate_deleted,'candidate branch still exists')
        require(release_deleted,'release branch still exists')

        summary={
            'schemaVersion':1,
            'result':'PASS',
            'version':args.version,
            'publishedUtc':args.published_utc,
            'candidateSha':args.candidate_sha,
            'candidatePreflight':True,
            'candidateGates':candidate_gates,
            'finalPrHeadSha':args.final_sha,
            'prNumber':pr_number,
            'prUrl':args.pr_url,
            'mergeCommitSha':merge_sha,
            'mainSha':main_sha,
            'sourceTag':source_tag,
            'sourceCommit':args.source_commit,
            'releaseStatuses':release_statuses,
            'release':{
                'file':release_file,
                'size':int(release.get('size')),
                'sha256':release.get('sha256'),
            },
            'sourcePackage':{
                'file':source_package.get('file'),
                'size':int(source_package.get('size')),
                'sha256':source_package.get('sha256'),
            },
            'sourceTree':{
                'zipFree':source_zip_free,
                'cacheFree':source_cache_free,
            },
            'branches':{
                'candidateDeleted':candidate_deleted,
                'releaseDeleted':release_deleted,
            },
            'latestConsistent':True,
            'releaseZipConsistent':release_zip_consistent,
            'reproducible':True,
            'historicalZipIntegrity':True,
        }

        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        compact=json.dumps(summary,ensure_ascii=False,separators=(',',':'),sort_keys=True)
        print('RELEASE_VERIFICATION_SUMMARY='+compact)

        step_summary=os.environ.get('GITHUB_STEP_SUMMARY','').strip()
        if step_summary:
            with Path(step_summary).open('a',encoding='utf-8') as f:
                f.write('## Release verification\n\n')
                f.write(f'- Version: **v{args.version}**\n')
                f.write(f'- Result: **PASS**\n')
                f.write(f'- PR: #{pr_number}\n')
                f.write(f'- Release gates: **8/8 success**\n')
                f.write(f'- Candidate gates: **3/3 success**\n')
                f.write(f'- Candidate SHA: `{args.candidate_sha}`\n')
                f.write(f'- Source commit: `{args.source_commit}`\n')
                f.write(f'- Main SHA: `{main_sha}`\n')
                f.write(f'- Release ZIP SHA-256: `{release.get("sha256")}`\n')
                f.write('- Candidate/release branches: **deleted**\n')
                f.write('- Source tree: **ZIP/cache-free**\n')
        return 0
    except Exception as e:
        print(f'RELEASE VERIFICATION FAIL: {e}',file=sys.stderr)
        return 1

if __name__=='__main__':
    raise SystemExit(main())
