#!/usr/bin/env python3
from pathlib import Path
import argparse, re, sys
ROOT_DEFAULT=Path(__file__).resolve().parents[1]

def txt(p):
    p=Path(p)
    return p.read_text(encoding='utf-8-sig') if p.is_file() else ''

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
    if not m: return ''
    n=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',src[m.end():])
    e=m.end()+n.start() if n else len(src)
    return src[m.start():e]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); core=txt(root/'src/Core/UpdateModel.ps1'); ui=txt(root/'src/UI/UpdatePresentation.ps1'); native=txt(root/'tests/Test-UpdateCore.ps1')
    resolver=fn(core,'Resolve-LenovoUpdateRestartResultCore'); show=fn(ui,'Show-PendingUpdateResultOnStartup')
    s.has('App version 0.5.8.1',tray,"$script:AppVersion = '0.5.8.1'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.5.8.1'"),1)
    s.has('Template version 0.5.8.1',template,"$script:AppVersion = '0.5.8.1'")
    s.has('Pure restart-result resolver exists',core,'function Resolve-LenovoUpdateRestartResultCore')
    s.has('Legacy success property presence is inspected',resolver,"$Result.PSObject.Properties['success']")
    s.has('Legacy format requires missing status',resolver,'-not $status')
    s.has('Legacy format requires Boolean success',resolver,'-is [bool]')
    s.has('Legacy result format is diagnostic',resolver,"'legacy-success'")
    s.has('Status result format remains diagnostic',resolver,"'status'")
    s.has('Unknown result format is diagnostic',resolver,"'unknown'")
    s.has('Legacy success uses actual running version for display',resolver,'$displayVersion = $running')
    s.has('Legacy success does not synthesize target version',resolver,'TargetVersion = $targetVersion')
    s.has('Legacy failure keeps stored message fallback',resolver,'Die Aktualisierung konnte nicht abgeschlossen werden.')
    s.has('New pending verification still compares target',resolver,'Compare-LenovoAppVersionCore -Current $running -Candidate $targetVersion')
    s.has('New failed status remains supported',resolver,"elseif ($status -eq 'failed')")
    s.has('Malformed/unknown status remains fail closed',resolver,'Unbekannter Update-Ergebnisstatus')
    s.has('UI delegates restart interpretation to core',show,'Resolve-LenovoUpdateRestartResultCore')
    s.has('UI diagnostics include result format',show,'resultFormat = $resolved.ResultFormat')
    s.has('UI diagnostics include legacy success when applicable',show,'legacySuccess = $resolved.LegacySuccess')
    s.has('UI still emits restart result event',show,"UPDATE_RESTART_RESULT")
    s.has('UI still consumes result before modal',show,'Remove-LenovoUpdateResult')
    s.has('UI success heading uses resolved display version',show,'$resolved.DisplayVersion')
    s.has('UI success popup retained',show,"-Title 'Update erfolgreich'")
    s.has('UI failure popup retained',show,"-Title 'Update fehlgeschlagen'")
    s.no('No legacy target inferred from stored message',resolver,'-match.*Update auf v')
    s.has('Native Update Core includes legacy success test',native,"Legacy success format detected")
    s.has('Native Update Core includes legacy false test',native,"Legacy false remains failure")
    s.has('Native Update Core covers new-format precedence',native,"Status wins over legacy success field")
    s.has('Native Update Core rejects non-Boolean legacy field',native,"Non-Boolean legacy success is rejected")
    s.has('Native Update Core expected count is 44',native,'UPDATE TOTAL $checks/44')
    return s.done()
if __name__=='__main__': raise SystemExit(main())
