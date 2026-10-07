#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import argparse,json,os,re,sys

from release_verification import (
    gh_json,
    git,
    require,
    run,
    sha256_bytes,
    validate_candidate_statuses,
    validate_release_statuses,
)


def validate_pointer_transition(public_latest:dict, staged_latest:dict, *, previous_version:str, version:str, release:dict, published_utc:str)->dict:
    source_tag=f'v{version}'
    require(str(public_latest.get('version'))==previous_version,
            f'public latest version changed before activation: {public_latest.get("version")!r} != {previous_version!r}')
    require(str(public_latest.get('version'))!=version,
            f'public latest already exposes unactivated version {version}')
    expected={
        'version':version,
        'tag':source_tag,
        'file':release.get('file'),
        'sha256':release.get('sha256'),
        'size':release.get('size'),
        'publishedUtc':published_utc,
    }
    for key,value in expected.items():
        require(staged_latest.get(key)==value,f'staged downloads/latest.json mismatch for {key}')
    return expected


def self_test()->int:
    release={'file':'LenovoBootMenuTray-v2.0.0.zip','sha256':'abc','size':123}
    public={'version':'1.9.0'}
    staged={
        'version':'2.0.0','tag':'v2.0.0','file':release['file'],'sha256':'abc','size':123,
        'publishedUtc':'2026-01-02T03:04:05Z',
    }
    expected=validate_pointer_transition(
        public,staged,previous_version='1.9.0',version='2.0.0',release=release,
        published_utc='2026-01-02T03:04:05Z',
    )
    require(expected['version']=='2.0.0','self-test staged version mismatch')
    try:
        validate_pointer_transition(
            {'version':'2.0.0'},staged,previous_version='1.9.0',version='2.0.0',release=release,
            published_utc='2026-01-02T03:04:05Z',
        )
    except RuntimeError:
        pass
    else:
        raise RuntimeError('self-test accepted already activated public latest')
    bad=dict(staged); bad['sha256']='wrong'
    try:
        validate_pointer_transition(
            public,bad,previous_version='1.9.0',version='2.0.0',release=release,
            published_utc='2026-01-02T03:04:05Z',
        )
    except RuntimeError:
        pass
    else:
        raise RuntimeError('self-test accepted staged latest metadata mismatch')
    print('PASS release pre-activation helper self-test')
    return 0


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument('--self-test',action='store_true')
    ap.add_argument('--root',type=Path)
    ap.add_argument('--version')
    ap.add_argument('--previous-version')
    ap.add_argument('--base-main-sha')
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
        except Exception as exc:
            print(f'FAIL release pre-activation helper self-test: {exc}',file=sys.stderr)
            return 1

    try:
        required={
            'root':args.root,'version':args.version,'previous-version':args.previous_version,
            'base-main-sha':args.base_main_sha,'candidate-sha':args.candidate_sha,
            'final-sha':args.final_sha,'source-commit':args.source_commit,'pr-url':args.pr_url,
            'published-utc':args.published_utc,'release-build-json':args.release_build_json,
            'reproducibility-marker':args.reproducibility_marker,'output':args.output,
        }
        missing=[key for key,value in required.items() if value is None or value=='']
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
        require(args.reproducibility_marker.is_file(),'reproducibility marker missing')

        git(root,'fetch','origin','main','--tags','--force')
        require(git(root,'rev-parse','HEAD')==args.final_sha,'release checkout is not exact final PR head')
        main_sha=git(root,'rev-parse','origin/main')
        require(main_sha==args.base_main_sha,
                f'main changed before activation: current={main_sha} expected={args.base_main_sha}')

        pr=gh_json(repo,f'pulls/{pr_number}')
        require(pr.get('state')=='open' and not pr.get('merged_at'),'publication PR is already merged before activation gate')
        require((pr.get('head') or {}).get('sha')==args.final_sha,'PR head SHA mismatch before activation')
        require((pr.get('base') or {}).get('ref')=='main','publication PR base is not main')

        owner=repo.split('/',1)[0]
        prs=gh_json(repo,f'pulls?state=all&head={owner}:release/v{args.version}&per_page=100')
        require(isinstance(prs,list) and len(prs)==1 and int(prs[0].get('number',0))==pr_number,
                f'expected exactly one publication PR, found {len(prs) if isinstance(prs,list) else "invalid"}')

        release_statuses=validate_release_statuses(gh_json(repo,f'commits/{args.final_sha}/status'))
        candidate_gates=validate_candidate_statuses(gh_json(repo,f'commits/{args.candidate_sha}/status'))

        source_tag=f'v{args.version}'
        tagged_source=git(root,'rev-parse',f'{source_tag}^{{commit}}')
        require(tagged_source==args.source_commit,'source tag does not resolve to expected source commit before activation')
        source_paths=git(root,'ls-tree','-r','--name-only',args.source_commit).splitlines()
        source_zip_free=not any(path.lower().endswith('.zip') for path in source_paths)
        source_cache_free=not any('__pycache__/' in path or path.endswith('.pyc') for path in source_paths)
        require(source_zip_free,'source tree contains ZIP file before activation')
        require(source_cache_free,'source tree contains Python cache artifact before activation')

        public_latest=json.loads(git(root,'show','origin/main:downloads/latest.json'))
        staged_latest=json.loads(git(root,'show',f'{args.final_sha}:downloads/latest.json'))
        expected_latest=validate_pointer_transition(
            public_latest,staged_latest,previous_version=args.previous_version,version=args.version,
            release=release,published_utc=args.published_utc,
        )

        release_file=str(release.get('file') or '')
        require(bool(release_file),'release file missing from build summary')
        staged_release=run(
            ['git','-C',str(root),'show',f'{args.final_sha}:downloads/{release_file}'],
            text=False,
        ).stdout
        staged_release_consistent=(
            len(staged_release)==int(release.get('size',-1)) and
            sha256_bytes(staged_release)==release.get('sha256')
        )
        require(staged_release_consistent,'staged release ZIP does not match build summary')

        summary={
            'schemaVersion':1,
            'result':'PASS',
            'phase':'pre-activation',
            'version':args.version,
            'previousVersion':args.previous_version,
            'publishedUtc':args.published_utc,
            'baseMainSha':args.base_main_sha,
            'candidateSha':args.candidate_sha,
            'candidateGates':candidate_gates,
            'finalPrHeadSha':args.final_sha,
            'prNumber':pr_number,
            'prUrl':args.pr_url,
            'sourceTag':source_tag,
            'sourceCommit':args.source_commit,
            'releaseStatuses':release_statuses,
            'publicLatestVersionBeforeActivation':public_latest.get('version'),
            'stagedLatest':expected_latest,
            'stagedLatestConsistent':True,
            'stagedReleaseZipConsistent':staged_release_consistent,
            'sourceTree':{'zipFree':source_zip_free,'cacheFree':source_cache_free},
            'reproducible':True,
        }
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        compact=json.dumps(summary,ensure_ascii=False,separators=(',',':'),sort_keys=True)
        print('RELEASE_PREACTIVATION_SUMMARY='+compact)

        step_summary=os.environ.get('GITHUB_STEP_SUMMARY','').strip()
        if step_summary:
            with Path(step_summary).open('a',encoding='utf-8') as handle:
                handle.write('## Release pre-activation verification\n\n')
                handle.write(f'- Version: **v{args.version}**\n')
                handle.write('- Result: **PASS**\n')
                handle.write(f'- Public latest before activation: **v{args.previous_version}**\n')
                handle.write(f'- Staged latest after activation: **v{args.version}**\n')
                handle.write('- Release gates: **8/8 success**\n')
                handle.write('- Candidate gates: **3/3 success**\n')
                handle.write(f'- Final PR head: `{args.final_sha}`\n')
                handle.write(f'- Base main: `{args.base_main_sha}`\n')
        return 0
    except Exception as exc:
        print(f'FAIL release pre-activation verification: {exc}',file=sys.stderr)
        return 1


if __name__=='__main__':
    raise SystemExit(main())
