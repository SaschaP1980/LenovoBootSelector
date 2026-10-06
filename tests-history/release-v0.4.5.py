#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
MODULES={
    'src/Infrastructure/SettingsRepository.ps1':['Read-AppSettingsRepository','Write-AppSettingsRepository','Remove-LegacySessionRestoreMarker'],
    'src/Application/SettingsService.ps1':['Get-AppSettings','Save-AppSettings','Load-AppSettings'],
    'src/Infrastructure/Autostart.ps1':['Get-LegacyAutostartInfo','Get-AutostartLauncherPath','Get-AutostartCommand','Get-AutostartInfo','Set-AutostartEnabled','Repair-AutostartLauncherIfNeeded'],
    'src/UI/AutostartPresentation.ps1':['Update-AutostartUi','Set-AutostartFromUi'],
    'src/Infrastructure/RuntimeDiagnostics.ps1':['ConvertTo-RuntimeDiagnosticText','New-RuntimeDiagnosticData','Initialize-RuntimeDiagnostics','Write-RuntimeDiagnosticEvent','Get-RuntimeDiagnosticBrokerSummary','Export-RuntimeDiagnosticPackage','Show-DiagnosticPackageInExplorer'],
    'src/UI/DiagnosticsPresentation.ps1':['Save-RuntimeDiagnosticsFromUi'],
}
UNCHANGED=[
    'src/Application/BootService.ps1','src/Application/RefreshRuntime.ps1',
    'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1',
    'Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1',
    'Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd',
    'LenovoBootMenuTray.ico','icon-preview.png',
]
EXISTING_UI=[
    'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/RefreshPresentation.ps1',
    'src/UI/ManageEntriesState.ps1','src/UI/ManageEntries.ps1','src/UI/DefaultTargetPresentation.ps1',
    'src/UI/DefaultTargetMenu.ps1','src/UI/Dialogs.ps1','src/UI/BootEntryList.ps1','src/UI/Popup.ps1',
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
    s.has('App version 0.4.5',tray,"$script:AppVersion = '0.4.5'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.5'"),1)
    s.c('README title v0.4.5',readme.startswith('# Lenovo Boot Selector v0.4.5'))
    s.has('README documents Infrastructure adapters',readme,'Settings-/Autostart-/Diagnostics-Infrastructure-Adapter')

    for rel,names in MODULES.items():
        p=root/rel; s.c(f'Module exists: {rel}',p.is_file()); mod=txt(p) if p.is_file() else ''
        s.eq(f'Module owns intended functions: {rel}',funcs(mod),names)
        marker=f'# @include {rel}'
        s.eq(f'Include marker exactly once: {rel}',template.count(marker),1)
        s.no(f'No unresolved include marker in runtime: {rel}',tray,marker)

    settings_repo=txt(root/'src/Infrastructure/SettingsRepository.ps1') if (root/'src/Infrastructure/SettingsRepository.ps1').is_file() else ''
    settings_service=txt(root/'src/Application/SettingsService.ps1') if (root/'src/Application/SettingsService.ps1').is_file() else ''
    auto_infra=txt(root/'src/Infrastructure/Autostart.ps1') if (root/'src/Infrastructure/Autostart.ps1').is_file() else ''
    auto_ui=txt(root/'src/UI/AutostartPresentation.ps1') if (root/'src/UI/AutostartPresentation.ps1').is_file() else ''
    diag_infra=txt(root/'src/Infrastructure/RuntimeDiagnostics.ps1') if (root/'src/Infrastructure/RuntimeDiagnostics.ps1').is_file() else ''
    diag_ui=txt(root/'src/UI/DiagnosticsPresentation.ps1') if (root/'src/UI/DiagnosticsPresentation.ps1').is_file() else ''

    for token in ['$script:','System.Windows.Forms','Get-ItemProperty','Set-ItemProperty','Schedule.Service']:
        s.no(f'Settings repository excludes {token}',settings_repo,token)
    for token in ['ReadAllText','WriteAllText','Get-ItemProperty','Set-ItemProperty','Remove-ItemProperty','Move-Item','New-Item','Test-Path']:
        s.no(f'Settings service excludes direct IO token {token}',settings_service,token)
    s.has('Settings service uses repository read',settings_service,'Read-AppSettingsRepository')
    s.has('Settings service uses repository write',settings_service,'Write-AppSettingsRepository')
    s.has('Settings service keeps Core normalization',settings_service,'ConvertTo-NormalizedAppSettingsCore')
    s.has('Settings service keeps Core defaults',settings_service,'New-DefaultAppSettingsCore')
    s.has('Settings load delegates legacy marker cleanup',settings_service,'Remove-LegacySessionRestoreMarker')

    for token in ['System.Windows.Forms','Show-LenovoNoticeDialog','ToolStrip','MessageBox']:
        s.no(f'Autostart infrastructure excludes presentation token {token}',auto_infra,token)
    s.has('Autostart infrastructure owns HKCU Run repository',auto_infra,'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run')
    s.has('Autostart infrastructure owns legacy Task Scheduler read',auto_infra,'Schedule.Service')
    for token in ['HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run','Get-ItemProperty','Set-ItemProperty','Remove-ItemProperty','Schedule.Service']:
        s.no(f'Autostart UI excludes infrastructure token {token}',auto_ui,token)
    s.has('Autostart UI uses named read operation',auto_ui,'Get-AutostartInfo')
    s.has('Autostart UI uses named write operation',auto_ui,'Set-AutostartEnabled')

    for token in ['System.Windows.Forms','Show-LenovoNoticeDialog']:
        s.no(f'Diagnostics infrastructure excludes presentation token {token}',diag_infra,token)
    s.has('Diagnostics infrastructure owns runtime file append',diag_infra,'System.IO.FileStream')
    s.has('Diagnostics infrastructure owns ZIP export',diag_infra,'System.IO.Compression.ZipFile')
    for token in ['System.IO.FileStream','System.IO.Compression.ZipFile','ProcessStartInfo','Copy-Item','New-Item']:
        s.no(f'Diagnostics UI excludes infrastructure token {token}',diag_ui,token)
    s.has('Diagnostics UI uses export operation',diag_ui,'Export-RuntimeDiagnosticPackage')
    s.has('Diagnostics UI uses reveal operation',diag_ui,'Show-DiagnosticPackageInExplorer')

    for token in ['Get-ItemProperty','Set-ItemProperty',"ReadAllText($script:SettingsPath","WriteAllText($tmp",'System.IO.Compression.ZipFile','Schedule.Service']:
        s.no(f'App template no longer owns infrastructure detail {token}',template,token)

    # The existing native-green UI modules and security/application boundaries must not be edited by this refactor.
    if a.basis_root:
        basis=a.basis_root.resolve()
        for rel in EXISTING_UI+UNCHANGED:
            s.eq(f'Unrelated file byte-identical to v0.4.4: {rel}',sha_file(root/rel),sha_file(basis/rel))
        basis_tray=txt(basis/'LenovoBootMenuTray.ps1')
        changed={'Get-AppSettings','Save-AppSettings','Load-AppSettings'}
        basis_names=funcs(basis_tray)
        current_names=set(funcs(tray))
        for name in basis_names:
            old=function_fragment(basis_tray,name); new=function_fragment(tray,name)
            s.c(f'Existing runtime function retained: {name}',name in current_names and new is not None)
            if old is None or new is None: continue
            if name in changed:
                s.c(f'Intentional settings adapter refactor changed: {name}',hashlib.sha256(old.encode()).hexdigest()!=hashlib.sha256(new.encode()).hexdigest())
            else:
                s.eq(f'Existing runtime function unchanged from native-green v0.4.4: {name}',hashlib.sha256(new.encode()).hexdigest(),hashlib.sha256(old.encode()).hexdigest())
        s.eq('Exactly three new repository functions added',len(funcs(tray))-len(basis_names),3)

    # Native abandoned-mutex test must retain a parent handle before the child exits.
    mutex=txt(root/'tests/Test-SingleInstanceMutex.ps1')
    s.has('Abandoned test opens existing mutex',mutex,'[System.Threading.Mutex]::OpenExisting($name2)')
    open_idx=mutex.find('[System.Threading.Mutex]::OpenExisting($name2)')
    wait_idx=mutex.find('[void]$child2.WaitForExit(5000)')
    s.c('Parent opens abandoned mutex handle before child exit wait',open_idx>=0 and wait_idx>=0 and open_idx<wait_idx)
    s.has('Abandoned child has explicit parent exit signal',mutex,'ExitPath')
    s.has('Parent signals abandoned child after opening handle',mutex,"WriteAllText($exit2")
    s.has('Mutex namespace still uses one backslash',mutex,"'Local\\LenovoBootSelectorAbandonedTest-'")
    s.no('Mutex namespace has no double backslash',mutex,'Local\\\\LenovoBootSelector')

    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    for rel in ['tests\\Test-FunctionalCore.ps1','tests\\Test-RefreshRuntime.ps1','tests\\Test-SingleInstanceMutex.ps1']:
        s.has(f'PS5.1 wrapper still runs {rel}',wrapper,rel)

    # Encoding, security and closed UX contracts.
    bad=[]
    for p in sorted(root.rglob('*.ps1')):
        b=p.read_bytes(); payload=b[3:] if b.startswith(b'\xef\xbb\xbf') else b
        if any(x>=128 for x in payload) and not b.startswith(b'\xef\xbb\xbf'): bad.append(p.relative_to(root).as_posix())
    s.eq('All non-ASCII PowerShell sources have UTF-8 BOM',bad,[])
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false','the form is visible before any fresh Scheduled-Task']:
        s.has(f'Closed UI/runtime contract retained: {x}',tray,x)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
