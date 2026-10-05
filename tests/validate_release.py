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
    vp=root/'version.json'; s.c('Canonical version.json exists',vp.is_file())
    meta={}
    if vp.is_file():
        try: meta=json.loads(vp.read_text(encoding='utf-8'))
        except Exception: meta={}
    version=str(meta.get('version','')); profile=str(meta.get('releaseProfile',''))
    s.c('Canonical version is four numeric components',bool(re.fullmatch(r'\d+\.\d+\.\d+\.\d+',version)),version)
    s.c('Release profile declared',profile in {'version-only','release-architecture','patch'},profile)
    tray=txt(root/'LenovoBootMenuTray.ps1') if (root/'LenovoBootMenuTray.ps1').is_file() else ''
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
    s.c('Canonical catch audit exists',(root/'CATCH_AUDIT.json').is_file())
    s.c('Canonical architecture baseline exists',(root/'ARCHITECTURE_BASELINE.json').is_file())
    s.c('Persistent release workflow exists',(root/'.github/workflows/release.yml').is_file())
    s.c('No redundant PR verification workflow exists',not (root/'.github/workflows/release-pr.yml').exists())
    if (root/'.github/workflows/release.yml').is_file():
        w=txt(root/'.github/workflows/release.yml')
        s.has('Release workflow targets one release branch family',w,'release/**')
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
