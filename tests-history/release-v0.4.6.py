#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
REMOVED={'Test-IsAdministrator','Get-PresentDiskPnpInfo','Find-MatchingPnpDisk','Show-ManageEntriesMode'}
STORAGE=['Test-PartitionBootStructure','Get-StorageContextCore','Get-StorageContext']
DEAD_GLOBALS=['AutostartTaskName','ColorBorder','ColorFrame']
UNCHANGED=[
    'src/Application/BootService.ps1','src/Application/RefreshRuntime.ps1','src/Application/SettingsService.ps1',
    'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Infrastructure/SettingsRepository.ps1','src/Infrastructure/Autostart.ps1','src/Infrastructure/RuntimeDiagnostics.ps1',
    'src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1',
    'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/RefreshPresentation.ps1',
    'src/UI/ManageEntriesState.ps1','src/UI/DefaultTargetPresentation.ps1','src/UI/DefaultTargetMenu.ps1',
    'src/UI/Dialogs.ps1','src/UI/BootEntryList.ps1','src/UI/Popup.ps1','src/UI/AutostartPresentation.ps1','src/UI/DiagnosticsPresentation.ps1',
    'Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1',
    'Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd',
    'LenovoBootMenuTray.ico','icon-preview.png',
]

class S:
    def __init__(self): self.rows=[]
    def c(self,n,v,d=''): self.rows.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,x in t)
    def no(self,n,t,x): self.c(n,x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.rows: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.rows); print(f'\nTOTAL {p}/{len(self.rows)}'); return 0 if p==len(self.rows) else 1

def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def sha_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def funcs(t): return re.findall(r'(?m)^function\s+([A-Za-z0-9_-]+)\b',t)

def function_fragment(src,name):
    m=re.search(rf'(?m)^function\s+{re.escape(name)}\b',src)
    if not m:return None
    i=m.end(); mode='code'; ob=None
    while i<len(src):
        c=src[i]; n=src[i+1] if i+1<len(src) else ''
        if mode=='code':
            if c=='#': mode='line'; i+=1; continue
            if c=='<' and n=='#': mode='block'; i+=2; continue
            if c=="'": mode='sq'; i+=1; continue
            if c=='"': mode='dq'; i+=1; continue
            if c=='{': ob=i; break
            i+=1
        elif mode=='line':
            if c in '\r\n': mode='code'
            i+=1
        elif mode=='block':
            if c=='#' and n=='>': mode='code'; i+=2
            else:i+=1
        elif mode=='sq':
            if c=="'":
                if n=="'": i+=2
                else: mode='code'; i+=1
            else:i+=1
        elif mode=='dq':
            if c=='`': i+=2
            elif c=='"': mode='code'; i+=1
            else:i+=1
    if ob is None:return None
    depth=0; i=ob; mode='code'
    while i<len(src):
        c=src[i]; n=src[i+1] if i+1<len(src) else ''
        if mode=='code':
            if c=='#': mode='line'; i+=1; continue
            if c=='<' and n=='#': mode='block'; i+=2; continue
            if c=="'": mode='sq'; i+=1; continue
            if c=='"': mode='dq'; i+=1; continue
            if c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0:return src[m.start():i+1].rstrip()+"\n"
            i+=1
        elif mode=='line':
            if c in '\r\n': mode='code'
            i+=1
        elif mode=='block':
            if c=='#' and n=='>': mode='code'; i+=2
            else:i+=1
        elif mode=='sq':
            if c=="'":
                if n=="'": i+=2
                else: mode='code'; i+=1
            else:i+=1
        elif mode=='dq':
            if c=='`': i+=2
            elif c=='"': mode='code'; i+=1
            else:i+=1
    return None

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.4.6',tray,"$script:AppVersion = '0.4.6'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.6'"),1)
    s.c('README title v0.4.6',readme.startswith('# Lenovo Boot Selector v0.4.6'))
    s.has('README documents cleanup/soak',readme,'Cleanup / Soak')

    storage=root/'src/Infrastructure/Storage.ps1'; s.c('Storage Infrastructure module exists',storage.is_file())
    st=txt(storage) if storage.is_file() else ''
    s.eq('Storage module owns intended functions',funcs(st),STORAGE)
    s.eq('Storage include marker exactly once',template.count('# @include src/Infrastructure/Storage.ps1'),1)
    for token in ['System.Windows.Forms','Schedule.Service','Invoke-AuthorizedTask','Start-ScheduledTask']:
        s.no(f'Storage infrastructure excludes {token}',st,token)
    s.has('Storage remains heuristic',st,'Der Lenovo-Eintrag USB HDD ist jedoch generisch')

    for name in REMOVED:
        s.no(f'Dead function removed from runtime: {name}',tray,f'function {name}')
        s.no(f'Dead function removed from modular source: {name}',template+txt(root/'src/UI/ManageEntries.ps1'),f'function {name}')
    for name in DEAD_GLOBALS:
        s.no(f'Dead script global removed: {name}',tray,f'$script:{name}')

    audit=root/'audits/CATCH_AUDIT_v0.4.6.json'; s.c('Catch audit exists',audit.is_file())
    if audit.is_file():
        data=json.loads(audit.read_text(encoding='utf-8'))
        s.eq('Catch audit version',data.get('version'),'0.4.6')
        s.eq('Catch audit count matches entries',data.get('count'),len(data.get('entries',[])))
        allowed=set(data.get('allowed_categories',[])); used={e.get('category') for e in data.get('entries',[])}
        s.c('Catch audit categories are fully declared',used.issubset(allowed))
        s.c('Catch audit has no unclassified entries',all(e.get('category') and e.get('reason') for e in data.get('entries',[])))
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Catch audit deterministic check',cp.returncode,0)

    soak=txt(root/'tests/Test-ArchitectureSoak.ps1') if (root/'tests/Test-ArchitectureSoak.ps1').is_file() else ''
    s.c('Native architecture soak test exists',bool(soak))
    for token in ['500 cycles','SOAK TOTAL $checks/4','Refresh lifecycle returns to idle','Settings normalization is stable','Firmware-manager parser is stable','Firmware freshness threshold remains deterministic']:
        s.has(f'Soak contract retained: {token}',soak,token)
    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('PS5.1 wrapper runs architecture soak',wrapper,"tests\\Test-ArchitectureSoak.ps1")
    s.eq('PowerShell source count is 33',len(list(root.rglob('*.ps1'))),33)

    if a.basis_root:
        basis=a.basis_root.resolve(); basis_tray=txt(basis/'LenovoBootMenuTray.ps1')
        for rel in UNCHANGED:
            s.eq(f'Unrelated file byte-identical to v0.4.5: {rel}',sha_file(root/rel),sha_file(basis/rel))
        for name in STORAGE:
            old=function_fragment(basis_tray,name); new=function_fragment(tray,name)
            s.c(f'Storage function retained: {name}',new is not None)
            if old and new: s.eq(f'Storage function body unchanged: {name}',hashlib.sha256(new.encode()).hexdigest(),hashlib.sha256(old.encode()).hexdigest())
        current=set(funcs(tray)); basis_names=funcs(basis_tray)
        for name in basis_names:
            if name in REMOVED:
                s.c(f'Proven-dead function removed: {name}',name not in current)
                continue
            old=function_fragment(basis_tray,name); new=function_fragment(tray,name)
            s.c(f'Existing runtime function retained: {name}',new is not None)
            if old and new: s.eq(f'Existing runtime function unchanged from native-green v0.4.5: {name}',hashlib.sha256(new.encode()).hexdigest(),hashlib.sha256(old.encode()).hexdigest())
        s.eq('Exactly four dead runtime functions removed',len(funcs(basis_tray))-len(funcs(tray)),4)

    # Security and closed UX invariants.
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false','the form is visible before any fresh Scheduled-Task']:
        s.has(f'Closed UI/runtime contract retained: {x}',tray,x)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No parked drift-repair feature',tray,'firmware drift')
    s.no('No free manual override marker feature',tray,'manual override marker')

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
