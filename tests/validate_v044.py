#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
UI_MODULES={
    'src/UI/StartupRecoveryDialog.ps1':['Show-FatalMessage'],
    'src/UI/MenuAppearance.ps1':['Initialize-LenovoMenuAppearance','Ensure-DarkActionTooltip','Show-DarkActionTooltip','Hide-DarkActionTooltip'],
    'src/UI/RefreshPresentation.ps1':['Update-HeaderRefreshStatus','Update-RefreshButtonVisual'],
    'src/UI/ManageEntriesState.ps1':['Test-ManageEntriesDirty','Update-ManageSaveButtonState'],
    'src/UI/ManageEntries.ps1':['Set-ManageEntryAliasDraft','Commit-ActiveManageAliasEditor','Get-OrderedEntriesForUi','Test-ManageEntryHidden','Toggle-ManageEntryVisibility','Move-ManageEntry','Update-ManageEntriesUiState','Start-ManageEntriesMode','Stop-ManageEntriesMode','Show-ManageEntriesMode'],
    'src/UI/DefaultTargetPresentation.ps1':['Get-DefaultEntryTitle','Update-DefaultUi'],
    'src/UI/DefaultTargetMenu.ps1':['New-DefaultTargetMenu','Show-DefaultTargetMenu'],
    'src/UI/Dialogs.ps1':['Show-LenovoNoticeDialog','Show-LenovoSystemFunctionsDialog','Show-LenovoRestartDialog'],
    'src/UI/BootEntryList.ps1':['New-Label','Get-BootRowFromControl','Set-RowHoverState','Update-PopupRows'],
    'src/UI/Popup.ps1':['New-PopupForm','Position-Popup','Show-OrTogglePopup','Load-TrayIcon'],
}
UNCHANGED={
    'src/Application/BootService.ps1',
    'src/Application/RefreshRuntime.ps1',
    'src/Infrastructure/TaskBroker.ps1',
    'src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Core/EntryPreferences.ps1',
    'src/Core/FirmwareParsing.ps1',
    'src/Core/BootTargetModel.ps1',
    'Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1',
    'Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd',
    'LenovoBootMenuTray.ico','icon-preview.png'
}

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
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return sha_bytes(Path(p).read_bytes())

def function_fragment(src,name):
    m=re.search(rf'(?m)^function\s+{re.escape(name)}\b',src)
    if not m:return None
    i=m.end(); mode='code'
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
    else:return None
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
    s.has('App version 0.4.4',tray,"$script:AppVersion = '0.4.4'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.4'"),1)
    s.c('README title v0.4.4',readme.startswith('# Lenovo Boot Selector v0.4.4'))
    s.has('README documents UI split',readme,'UI-Source-Split ohne Runtime-Verhaltensänderung')

    baseline=json.loads((root/'tests/ui-baseline-v0.4.3.json').read_text(encoding='utf-8'))
    expected_fns=baseline['functions']
    all_module_fns=[]
    for rel,names in UI_MODULES.items():
        p=root/rel; s.c(f'UI module exists: {rel}',p.is_file())
        mod=txt(p) if p.is_file() else ''
        marker=f'# @include {rel}'
        s.eq(f'Include marker once: {rel}',template.count(marker),1)
        s.no(f'No unresolved UI marker: {rel}',tray,marker)
        actual_names=re.findall(r'(?m)^function\s+([A-Za-z0-9_-]+)\b',mod)
        s.eq(f'UI module owns only intended functions: {rel}',actual_names,names)
        all_module_fns.extend(actual_names)
        for token in ['Invoke-AuthorizedTask','Start-ScheduledTask','Schedule.Service','Invoke-BcdEdit','Set-TaskBrokerBootNextTarget','Set-TaskBrokerDefaultTarget','Clear-TaskBrokerDefaultTarget']:
            s.no(f'{rel} excludes privilege-boundary token {token}',mod,token)
        for name in names:
            frag=function_fragment(tray,name)
            s.c(f'Bundled UI function present: {name}',frag is not None)
            if frag is not None:
                s.eq(f'UI function unchanged from native-green v0.4.3: {name}',sha_bytes(frag.encode('utf-8')),expected_fns[name])
    s.eq('Exactly 34 UI functions extracted',len(all_module_fns),34)
    s.eq('UI function names unique across modules',len(set(all_module_fns)),34)
    s.c('App template reduced below 3000 lines',len(template.splitlines())<3000,str(len(template.splitlines())))

    # Mutex native-test harness fix: PowerShell backslash is literal, so namespace must contain exactly one separator.
    mutex=txt(root/'tests/Test-SingleInstanceMutex.ps1')
    s.has('Mutex active test uses one namespace backslash',mutex,"'Local\\LenovoBootSelectorTest-'")
    s.has('Mutex abandoned test uses one namespace backslash',mutex,"'Local\\LenovoBootSelectorAbandonedTest-'")
    s.no('Mutex test no double namespace backslash',mutex,'Local\\\\LenovoBootSelector')
    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    for rel in ['tests\\Test-FunctionalCore.ps1','tests\\Test-RefreshRuntime.ps1','tests\\Test-SingleInstanceMutex.ps1']:
        s.has(f'PS5.1 wrapper runs {rel}',wrapper,rel)

    # PS5.1 source encoding rule must cover the newly extracted UI modules too.
    bad=[]
    for p in sorted(root.rglob('*.ps1')):
        b=p.read_bytes(); payload=b[3:] if b.startswith(b'\xef\xbb\xbf') else b
        if any(x>=128 for x in payload) and not b.startswith(b'\xef\xbb\xbf'): bad.append(p.relative_to(root).as_posix())
    s.eq('All non-ASCII PowerShell sources have UTF-8 BOM',bad,[])

    # Closed UI contracts remain present in the bundle.
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false','the form is visible before any fresh Scheduled-Task']:
        s.has(f'Closed UI/runtime contract retained: {x}',tray,x)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")

    # Compare unrelated files byte-for-byte to provided native-green v0.4.3 source when available.
    if a.basis_root:
        basis=a.basis_root.resolve()
        for rel in sorted(UNCHANGED):
            s.eq(f'Unrelated file byte-identical to v0.4.3: {rel}',sha_file(root/rel),sha_file(basis/rel))

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
