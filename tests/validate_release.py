#!/usr/bin/env python3
from pathlib import Path
import argparse,json,re,subprocess,sys
ROOT_DEFAULT=Path(__file__).resolve().parents[1]

def txt(p): return Path(p).read_text(encoding='utf-8-sig')
class S:
    def __init__(self): self.rows=[]
    def c(self,n,v,d=''): self.rows.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,x in t)
    def no(self,n,t,x): self.c(n,x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.rows: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.rows); print(f'\nTOTAL {p}/{len(self.rows)}'); return 0 if p==len(self.rows) else 1

def fn(src,name):
    m=re.search(rf'(?m)^function\s+{re.escape(name)}\b',src)
    if not m:return ''
    n=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',src[m.end():])
    e=m.end()+n.start() if n else len(src)
    return src[m.start():e]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root.resolve(); s=S()
    vp=root/'bin/version.json'; s.c('Canonical bin/version.json exists',vp.is_file())
    meta={}
    if vp.is_file():
        try: meta=json.loads(vp.read_text(encoding='utf-8'))
        except Exception: meta={}
    version=str(meta.get('version','')); profile=str(meta.get('releaseProfile','')); schema=meta.get('schemaVersion')
    s.c('Canonical version schema is v2',schema==2,schema)
    s.c('Canonical version input excludes publishedUtc','publishedUtc' not in meta)
    s.c('Canonical version is four numeric components',bool(re.fullmatch(r'\d+\.\d+\.\d+\.\d+',version)),version)
    s.c('Release profile declared',profile in {'version-only','release-architecture','patch'},profile)
    runtime_names=['BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','LenovoBootMenuTray.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1','version.json']
    for name in runtime_names:
        s.c(f'LBS-2 runtime/project file moved to bin: {name}',(root/'bin'/name).is_file())
        s.c(f'LBS-2 obsolete root path removed: {name}',not (root/name).exists())
    s.c('README remains repository-root file',(root/'README.md').is_file())
    s.c('CHANGELOG remains repository-root file',(root/'CHANGELOG.md').is_file())
    s.c('Git control file remains at repository root',(root/'.gitignore').is_file())
    s.c('LBS-1 JSON artifacts remain outside LBS-2 scope',(root/'ARCHITECTURE_BASELINE.json').is_file() and (root/'CATCH_AUDIT.json').is_file())
    tray=txt(root/'bin/LenovoBootMenuTray.ps1') if (root/'bin/LenovoBootMenuTray.ps1').is_file() else ''
    template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    expected=f"$script:AppVersion = '{version}'"
    s.has('Generated runtime uses canonical version',tray,expected)
    s.eq('Generated runtime version declaration exactly once',tray.count(expected),1)
    s.eq('Template has exactly one version injection token',template.count('@APP_VERSION@'),1)
    s.no('Template no longer hard-codes concrete AppVersion',template,"$script:AppVersion = '0.5.")
    for rel in ['tools/build_packages.py','tools/build_transition.py','tools/build_catch_audit.py']:
        t=txt(root/rel)
        s.no(f'{rel} has no hard-coded VERSION constant',t,"VERSION='")
        s.has(f'{rel} uses release_common version source',t,'release_common')
    s.c('Persistent prepare_release tool exists',(root/'tools/prepare_release.py').is_file())
    prepare=txt(root/'tools/prepare_release.py') if (root/'tools/prepare_release.py').is_file() else ''
    common=txt(root/'tools/release_common.py') if (root/'tools/release_common.py').is_file() else ''
    s.has('Prepare tool accepts explicit publication timestamp',prepare,"ap.add_argument('--published-utc')")
    s.has('Prepare tool rejects missing schema-v2 publication timestamp',prepare,'publishedUtc must be supplied explicitly for schemaVersion 2')
    s.has('Release config keeps legacy schema 1 readable',common,"schema not in {1,2}")
    s.has('Release config forbids publishedUtc in schema 2',common,'schemaVersion 2 must not contain publishedUtc')
    s.c('Canonical catch audit exists',(root/'CATCH_AUDIT.json').is_file())
    s.c('Canonical architecture baseline exists',(root/'ARCHITECTURE_BASELINE.json').is_file())
    s.c('Persistent release workflow exists',(root/'.github/workflows/release.yml').is_file())
    s.c('No redundant PR verification workflow exists',not (root/'.github/workflows/release-pr.yml').exists())
    if (root/'.github/workflows/release.yml').is_file():
        w=txt(root/'.github/workflows/release.yml')
        s.has('Release workflow targets one release branch family',w,'release/**')
        s.has('Release workflow captures GitHub publication timestamp',w,"PUBLISHED_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')")
        s.eq('Release workflow passes publication timestamp to both rebuilds',w.count('--published-utc "$PUBLISHED_UTC"'),2)
        s.has('Release workflow uses Python no-bytecode mode',w,'python3 -B tools/prepare_release.py')
        s.has('Release workflow disables child-process bytecode writes',w,"PYTHONDONTWRITEBYTECODE: '1'")
        s.has('Release workflow can create PRs',w,'pull-requests: write')
        s.has('Release workflow creates exactly one PR',w,'gh pr create')
        s.has('Release workflow writes final-head gate statuses',w,'statuses/$FINAL_SHA')
        s.has('Release workflow runs permanent release validator',w,'tests/validate_release.py')
        s.has('Release workflow runs permanent core validator',w,'tests/validate_core.py')
        s.has('Release workflow runs permanent boundary validator',w,'tests/validate_boundary.py')
        s.has('Release workflow runs permanent regression validator',w,'tests/validate_regression.py')
        s.has('Release workflow creates tag only after PR creation',w,'Tag only after all gates and successful PR creation')
        s.has('Release workflow merges and deletes release branch',w,'gh pr merge')
        s.no('Release workflow is not version-specific',w,'0.5.10.0')
        s.no('Release workflow has no Base64 patch transport',w,'base64')
        s.no('Release workflow has no source helper branch',w,'source-v')
        s.no('Release workflow has no post-merge finalizer',w,'finalize')
        s.has('Release workflow allows only exact one-time LBS-2 root migration deletes',w,'EXPECTED_LBS2_DELETIONS')
        s.has('LBS-2 delete compatibility is gated by legacy root version',w,'origin/main:version.json')
        s.has('LBS-2 delete compatibility requires missing migrated version on main',w,'origin/main:bin/version.json')
        s.has('LBS-2 delete comparison disables rename detection',w,'--diff-filter=D --no-renames origin/main')
    for rel in ['tests/validate_release.py','tests/validate_core.py','tests/validate_boundary.py','tests/validate_regression.py']:
        s.c(f'Permanent validator exists: {rel}',(root/rel).is_file())
    ui=txt(root/'src/UI/UpdatePresentation.ps1'); infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    complete=fn(ui,'Complete-ManualUpdateCheck')
    s.has('Update button retained',complete,"-SecondaryButtonText 'Jetzt aktualisieren'")
    s.has('Update button still reuses manual update path',complete,'Start-ManualAppUpdate')
    s.has('Manual-only update policy retained',ui,'no periodic or startup polling')
    s.has('Fixed GitHub update source retained',infra,'SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.no('Updater remains unelevated',infra,'RunAs')
    s.no('Updater has no TaskBroker mutation',infra,'TaskBroker')
    s.no('Updater has no bcdedit',infra.lower(),'bcdedit')
    return s.done()
if __name__=='__main__': raise SystemExit(main())
