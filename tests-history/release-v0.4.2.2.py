#!/usr/bin/env python3
from pathlib import Path
import argparse, re, subprocess, sys, zipfile
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
class S:
    def __init__(self): self.r=[]
    def c(self,n,v,d=''): self.r.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,x in t)
    def no(self,n,t,x): self.c(n,x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.r: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.r); print(f'\nTOTAL {p}/{len(self.r)}'); return 0 if p==len(self.r) else 1
def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def block(t,start,end):
    a=t.find(start); b=t.find(end,a+len(start)); return t[a:b] if a>=0 and b>a else ''
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root; s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.4.2.2',tray,"$script:AppVersion = '0.4.2.2'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.2.2'"),1)
    s.c('README title v0.4.2.2',readme.startswith('# Lenovo Boot Selector v0.4.2.2'))
    s.has('README documents singleton patch',readme,'robuster Singleton-Mutex')
    startup=block(tray,'# Prevent duplicate tray instances.','$script:AppVersion')
    s.has('Named mutex unchanged',startup,"'Local\\LenovoBootMenuTray'")
    s.has('Mutex constructed unowned',startup,"[System.Threading.Mutex]::new($false, 'Local\\LenovoBootMenuTray')")
    s.no('createdNew singleton heuristic removed',startup,'createdNew')
    s.has('Immediate ownership probe',startup,'$mutex.WaitOne(0, $false)')
    s.has('Grace retry constant 500ms',startup,'$singleInstanceGraceMs = 500')
    s.has('Grace retry ownership probe',startup,'$mutex.WaitOne($singleInstanceGraceMs, $false)')
    s.has('Abandoned mutex explicitly handled',startup,'catch [System.Threading.AbandonedMutexException]')
    s.c('Abandoned mutex handled on both probes',startup.count('catch [System.Threading.AbandonedMutexException]')==2)
    s.has('Abandoned mutex becomes owned',startup,"$singleInstanceMutexState = 'abandoned-recovered'")
    s.has('Busy path only after ownership attempts',startup,'if (-not $mutexOwned) {')
    s.has('Busy path keeps no-restart UX',startup,"Show-FatalMessage 'Lenovo Boot Selector läuft bereits.' -AllowRestart $false")
    s.c('Busy path disposes mutex before dialog',startup.find('$mutex.Dispose()') < startup.find("Show-FatalMessage 'Lenovo Boot Selector läuft bereits.'"))
    s.has('Acquired event exists',tray,"'SINGLE_INSTANCE_MUTEX_ACQUIRED'")
    s.has('Abandoned recovered event exists',tray,"'SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED'")
    s.has('Acquired event records state',tray,'state = $singleInstanceMutexState')
    s.has('Acquired event records grace window',tray,'graceMs = $singleInstanceGraceMs')
    final=block(tray,"finally {\n    Write-RuntimeDiagnosticEvent -Event 'SESSION_ENDED'",'if ($script:RestartAfterFatal)')
    s.has('Final cleanup checks ownership',final,'if ($mutexOwned)')
    s.has('Final cleanup releases owned mutex',final,'$mutex.ReleaseMutex()')
    s.has('Final cleanup clears ownership flag',final,'$mutexOwned = $false')
    s.has('Final cleanup disposes mutex',final,'$mutex.Dispose()')
    # Recovery dialog patch remains present.
    fatal=block(tray,'function Show-FatalMessage','function ')
    s.has('Fatal dialog remains hidden from taskbar',fatal,'$form.ShowInTaskbar = $false')
    s.has('Fallback owner remains hidden from taskbar',fatal,'$owner.ShowInTaskbar = $false')
    # Native test coverage.
    native=txt(root/'tests/Test-SingleInstanceMutex.ps1'); wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('Native singleton test requires PS5.1',native,'#requires -version 5.1')
    s.has('Native singleton test uses unique mutex',native,'LenovoBootSelector-MutexTest-')
    s.has('Native singleton test checks active owner',native,'Active owner blocks nonblocking acquisition')
    s.has('Native singleton test checks post-release acquisition',native,'Released named mutex can be acquired')
    s.has('Native singleton test checks abandoned recovery',native,'Abandoned mutex is reported and recoverable')
    s.has('Native singleton test expects 4 checks',native,'MUTEX TOTAL $checks/4')
    s.has('PS5.1 wrapper runs singleton test',wrapper,"tests\\Test-SingleInstanceMutex.ps1")
    s.has('PS5.1 wrapper still runs functional core',wrapper,"tests\\Test-FunctionalCore.ps1")
    # Encoding invariant retained.
    bad=[]
    for p in sorted(root.rglob('*.ps1')):
        b=p.read_bytes(); payload=b[3:] if b.startswith(b'\xef\xbb\xbf') else b
        if any(x>=128 for x in payload) and not b.startswith(b'\xef\xbb\xbf'): bad.append(p.relative_to(root).as_posix())
    s.eq('All non-ASCII PowerShell sources have UTF-8 BOM',bad,[])
    # Security/architecture invariants retained.
    infra=txt(root/'src/Infrastructure/TaskBroker.ps1'); app=txt(root/'src/Application/BootService.ps1'); install=txt(root/'Install-LenovoBootMenuTasks.ps1')
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.has('Explicit BootNext broker retained',infra,'function Set-TaskBrokerBootNextTarget')
    s.no('Application cannot start Scheduled Tasks directly',app,'Start-ScheduledTask')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Installer schema unchanged',install,"$version = '0.2.12'")
    s.has('Popup-first contract retained',tray,'the form is visible before any fresh Scheduled-Task')
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow']:
        s.has(f'Closed UI contract retained: {x}',tray,x)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        z=zipfile.ZipFile(a.release_zip); names=z.namelist()
        s.eq('Release remains flat 10-file package',len(names),10)
        s.c('Release has no directories',all('/' not in n for n in names))
        s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
