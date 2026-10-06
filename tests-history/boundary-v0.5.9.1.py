#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
INFRA='src/Infrastructure/TaskBroker.ps1'
APP='src/Application/BootService.ps1'
CORE=['src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1']

class Suite:
    def __init__(self): self.rows=[]
    def check(self,n,c,d=''): self.rows.append((n,bool(c),d))
    def contains(self,n,t,x): self.check(n,x in t)
    def absent(self,n,t,x): self.check(n,x not in t)
    def eq(self,n,a,b): self.check(n,a==b,f'{a!r} != {b!r}' if a!=b else '')
    def finish(self):
        for n,o,d in self.rows: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.rows); total=len(self.rows); print(f'\nTOTAL {p}/{total}'); return 0 if p==total else 1

def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def sha_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def psfn(s,n):
    m=re.search(rf'(?m)^function\s+{re.escape(n)}\b',s)
    if not m:return ''
    q=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',s[m.end():]); e=m.end()+q.start() if q else len(s)
    return s[m.start():e].rstrip()+"\n"

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root
    s=Suite(); tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    s.contains('App version is 0.5.9.1',tray,"$script:AppVersion = '0.5.9.1'")
    s.eq('App version declaration exactly once',tray.count("$script:AppVersion = '0.5.9.1'"),1)
    s.check('Infrastructure TaskBroker module exists',(root/INFRA).is_file())
    s.check('Application BootService module exists',(root/APP).is_file())
    infra=txt(root/INFRA) if (root/INFRA).is_file() else ''; app=txt(root/APP) if (root/APP).is_file() else ''
    for rel in [INFRA,APP,*CORE]:
        marker=f'# @include {rel}'
        s.eq(f'Include marker once: {rel}',template.count(marker),1)
        s.absent(f'No unresolved marker in bundle: {rel}',tray,marker)
    for fn in ['Get-TaskBrokerFirmwareManagerText','Get-TaskBrokerFirmwareEntriesText','Get-TaskBrokerDefaultTargetGuid','Set-TaskBrokerBootNextTarget','Set-TaskBrokerDefaultTarget','Clear-TaskBrokerDefaultTarget']:
        s.eq(f'Explicit infrastructure operation once: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',infra)),1)
        s.eq(f'Explicit infrastructure operation bundled once: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',tray)),1)
    for fn in ['Get-BootServiceFirmwareSnapshot','Set-BootNextTargetService']:
        s.eq(f'Application service once: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',app)),1)
        s.eq(f'Application service bundled once: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',tray)),1)
    s.absent('Historical Invoke-BcdEdit function removed',tray,'function Invoke-BcdEdit')
    s.absent('Historical Invoke-BcdEdit references removed',tray,'Invoke-BcdEdit')
    s.absent('Historical Set-BootSequence function removed',tray,'function Set-BootSequence')
    s.eq('Explicit Set-BootNextTarget shell once',len(re.findall(r'(?m)^function\s+Set-BootNextTarget\b',tray)),1)
    s.contains('UI boot row uses Set-BootNextTarget',tray,'Set-BootNextTarget -Guid $guid')
    # Infrastructure owns privileged mechanics; app/template must not call the generic runner.
    s.contains('Infrastructure retains exact task runner',infra,'function Invoke-AuthorizedTask')
    s.absent('Template does not directly call generic authorized task runner',template,'Invoke-AuthorizedTask')
    s.absent('Application does not directly call generic authorized task runner',app,'Invoke-AuthorizedTask')
    s.absent('Application has no Start-ScheduledTask',app,'Start-ScheduledTask')
    s.absent('Application has no Get-ScheduledTask',app,'Get-ScheduledTask')
    s.absent('Application has no Schedule.Service',app,'Schedule.Service')
    s.absent('Application has no script-global state',app,'$script:')
    s.absent('Application has no WinForms',app,'System.Windows.Forms')
    s.contains('Exact-task COM access stays infrastructure-only',infra,"New-Object -ComObject 'Schedule.Service'")
    s.contains('Exact task start stays infrastructure-only',infra,'Start-ScheduledTask -TaskName $TaskName')
    s.contains('BootNext resolves target from metadata',psfn(infra,'Set-TaskBrokerBootNextTarget'),'Get-TaskBrokerTarget -Guid $normalized')
    s.contains('BootNext invokes only resolved fixed task',psfn(infra,'Set-TaskBrokerBootNextTarget'),'Invoke-AuthorizedTask -TaskName ([string]$target.taskName)')
    s.contains('Default set resolves target from metadata',psfn(infra,'Set-TaskBrokerDefaultTarget'),'Get-TaskBrokerTarget -Guid $normalized')
    s.contains('Default set invokes only resolved fixed task',psfn(infra,'Set-TaskBrokerDefaultTarget'),'Invoke-AuthorizedTask -TaskName ([string]$target.defaultTaskName)')
    s.contains('Default clear uses metadata fixed task',psfn(infra,'Clear-TaskBrokerDefaultTarget'),'defaultClearTask')
    s.contains('Boot service verifies returned bootsequence',psfn(app,'Set-BootNextTargetService'),'ConvertFrom-FirmwareManagerText')
    s.contains('Boot service requires exact selected GUID',psfn(app,'Set-BootNextTargetService'),'SelectedGuid -ne $normalized')
    fw=psfn(tray,'Get-FirmwareBootState'); s.contains('Firmware shell delegates broker read/parse to boot service',fw,'Get-BootServiceFirmwareSnapshot')
    s.absent('Firmware shell no direct TaskBroker metadata IO',fw,'Get-TaskBrokerMetadata')
    default=psfn(tray,'Set-DefaultGuid')
    s.contains('Default UI shell uses explicit broker set',default,'Set-TaskBrokerDefaultTarget')
    s.contains('Default UI shell uses explicit broker clear',default,'Clear-TaskBrokerDefaultTarget')
    dstate=psfn(tray,'Refresh-SystemDefaultState'); s.contains('Default read uses explicit broker operation',dstate,'Get-TaskBrokerDefaultTargetGuid')
    worker=psfn(tray,'Invoke-BackgroundRefreshWorker')
    s.contains('Background worker uses explicit manager read',worker,'Get-TaskBrokerFirmwareManagerText -Force')
    s.contains('Background worker uses explicit firmware read',worker,'Get-TaskBrokerFirmwareEntriesText -Force')
    # No new generic privileged command/GUID API.
    for bad in ['Invoke-PrivilegedCommand','Invoke-PrivilegedTask','-CommandText','-Arguments $Arguments','param([string]$TaskName)']:
        s.absent(f'No generic privileged API token: {bad}',app+'\n'+template,bad)
    s.absent('No direct bcdedit executable from tray',tray.lower(),'bcdedit.exe')
    s.absent('No permanent displayorder set in tray',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    # Installer/uninstaller and core remain unchanged from v0.4.1 inputs.
    base=json.loads((root/'tests/characterization-baseline-v0.3.4.json').read_text())
    for fn in ['Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','icon-preview.png']:
        s.eq(f'Unrelated runtime asset still baseline-identical: {fn}',sha_file(root/fn),base['source_sha256'][fn])
    uninstall_bytes=(root/'Uninstall-LenovoBootMenuTasks.ps1').read_bytes()
    s.check('Uninstaller now carries UTF-8 BOM for PS5.1',uninstall_bytes.startswith(b'\xef\xbb\xbf'))
    # v0.4.1 native test-harness parser finding is fixed in source.
    ntest=txt(root/'tests/Test-FunctionalCore.ps1')
    s.absent('Native test has no ambiguous $Name: interpolation',ntest,'"$Name:')
    s.contains('Native test uses delimited Name interpolation',ntest,'"${Name}:')
    # Deterministic build check.
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Runtime builder check succeeds',cp.returncode,0)
    return s.finish()
if __name__=='__main__': raise SystemExit(main())
