#!/usr/bin/env python3
from pathlib import Path
import argparse,re
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
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); ui=txt(root/'src/UI/UpdatePresentation.ps1'); infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    complete=fn(ui,'Complete-ManualUpdateCheck')
    s.has('App version 0.5.9.1',tray,"$script:AppVersion = '0.5.9.1'")
    s.eq('App version declaration once',tray.count("$script:AppVersion = '0.5.9.1'"),1)
    s.has('Template version 0.5.9.1',template,"$script:AppVersion = '0.5.9.1'")
    s.has('Update button remains present',complete,"-SecondaryButtonText 'Jetzt aktualisieren'")
    s.has('Update button still reuses manual update path',complete,'Start-ManualAppUpdate')
    s.has('Final explanatory text remains unchanged',complete,'Später findest du die Aktualisierung im Tray-Menü unter „Wartung“ → „App aktualisieren…“.')
    s.has('Manual-only update policy remains explicit',ui,'no periodic or startup polling')
    s.has('Fixed GitHub update source unchanged',infra,'SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.no('Updater remains unelevated',infra,'RunAs')
    s.no('Updater still has no TaskBroker mutation',infra,'TaskBroker')
    s.no('Updater still has no bcdedit',infra.lower(),'bcdedit')
    return s.done()
if __name__=='__main__': raise SystemExit(main())
