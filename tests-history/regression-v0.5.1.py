#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
EXPECTED_NEW=set()
EXPECTED_CHANGED={
    'Get-FriendlyBootEntryCore','Set-DefaultGuid',
    'Show-LenovoSystemFunctionsDialog','Show-MaintenanceSuccessDialog',
    'Show-OrTogglePopup','Update-MaintenanceUi'
}
UNCHANGED_FILES=[
    'src/Application/BootService.ps1','src/Application/BootTargetDrift.ps1','src/Application/MaintenanceRuntime.ps1',
    'src/Application/RefreshRuntime.ps1','src/Application/SettingsService.ps1',
    'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Infrastructure/SettingsRepository.ps1','src/Infrastructure/Autostart.ps1',
    'src/Infrastructure/RuntimeDiagnostics.ps1','src/Infrastructure/Storage.ps1',
    'src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetDrift.ps1',
    'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/AutostartPresentation.ps1',
    'src/UI/DiagnosticsPresentation.ps1','src/UI/ManageEntriesState.ps1','src/UI/ManageEntries.ps1',
    'src/UI/DefaultTargetPresentation.ps1','src/UI/DefaultTargetMenu.ps1','src/UI/RefreshPresentation.ps1',
    'src/UI/BootEntryList.ps1',
    'Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1',
    'Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd',
    'LenovoBootMenuTray.ico','icon-preview.png'
]

class S:
    def __init__(self): self.rows=[]
    def c(self,n,v,d=''): self.rows.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,bool(t) and x in t)
    def no(self,n,t,x): self.c(n,(not t) or x not in t)
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
            if c=='`':i+=2
            elif c=='"':mode='code';i+=1
            else:i+=1
    return None

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.5.1',tray,"$script:AppVersion = '0.5.1'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.5.1'"),1)
    s.c('README title v0.5.1',readme.startswith('# Lenovo Boot Selector v0.5.1'))
    s.has('README documents drift detection',readme,'Drift-Erkennung')

    core=root/'src/Core/BootTargetDrift.ps1'; app=root/'src/Application/BootTargetDrift.ps1'
    s.c('Drift core exists',core.is_file()); s.c('Drift application state exists',app.is_file())
    ct=txt(core) if core.is_file() else ''; at=txt(app) if app.is_file() else ''
    for token in ['$script:','System.Windows.Forms','Start-Process','ScheduledTask','TaskBroker','Test-Path','ReadAllText','WriteAllText']:
        s.no(f'Drift core excludes {token}',ct,token)
        s.no(f'Drift application excludes {token}',at,token)
    s.has('Core compares installed targets',ct,'InstalledTargets')
    s.has('Core builds current target set from display order',ct,'DisplayOrder')
    s.has('Core includes Boot Menu',ct,"-eq 'Boot Menu'")
    s.has('Core reports additions',ct,'AddedGuids')
    s.has('Core reports removals',ct,'RemovedGuids')
    s.has('Core distinguishes new targets',ct,'HasNewTargets')
    s.no('Core never invokes maintenance',ct,'Start-TaskBrokerInstall')
    s.no('Application never invokes maintenance',at,'Start-TaskBrokerInstall')
    for marker in ['# @include src/Core/BootTargetDrift.ps1','# @include src/Application/BootTargetDrift.ps1']:
        s.eq(f'Include marker once: {marker}',template.count(marker),1); s.no(f'No unresolved include: {marker}',tray,marker)

    # Read-only detection path and diagnostics.
    upd=function_fragment(tray,'Update-BootTargetDriftState') or ''
    s.has('Drift uses installed broker metadata',upd,'Get-TaskBrokerMetadata')
    s.has('Drift uses cached manager read',upd,'Get-TaskBrokerFirmwareManagerText -UseExistingCache')
    s.has('Drift uses cached firmware read',upd,'Get-TaskBrokerFirmwareEntriesText -UseExistingCache')
    s.has('Drift delegates pure comparison',upd,'Compare-BootTargetDriftCore')
    s.has('Drift diagnostic event present',upd,"BOOT_TARGET_DRIFT_CHECK")
    s.no('Drift check has no automatic setup',upd,'Start-TaskBrokerInstall')
    s.no('Drift check has no privileged task runner',upd,'Invoke-AuthorizedTask')
    s.no('Drift check does not mutate bootsequence',upd,'bootsequence')
    s.no('Drift check does not mutate displayorder',upd,'displayorder')
    apply=function_fragment(tray,'Apply-BackgroundRefreshResult') or ''
    s.has('Fresh background result evaluates drift after cache sync',apply,'Sync-TaskBrokerFirmwareCachesFromFiles')
    s.has('Fresh background result calls drift evaluation',apply,'Update-BootTargetDriftState')
    s.has('Drift notification follows result application',apply,'Show-BootTargetDriftNotificationIfNeeded')

    # Explicit user action and terminology.
    mp=txt(root/'src/UI/MaintenancePresentation.ps1'); dialogs=txt(root/'src/UI/Dialogs.ps1')
    for token in ['ReinitializeRequired','Neues Startziel erkannt','Systemfunktionen neu initialisieren','Startziele wurden geändert']:
        s.has(f'Drift UI token: {token}',mp,token)
    s.has('Busy UI says neu initialisiert',mp,'Systemfunktionen werden neu initialisiert…')
    s.has('Success UI says neu initialisiert',mp,'Systemfunktionen wurden neu initialisiert.')
    reinit_branch=dialogs[dialogs.find("elseif ($Mode -eq 'Reinitialize')"):dialogs.find("else {",dialogs.find("elseif ($Mode -eq 'Reinitialize')"))]
    s.has('Confirmation has Reinitialize mode',dialogs,"$Mode -eq 'Reinitialize'")
    s.has('Confirmation says Neues Startziel erkannt',reinit_branch,'Neues Startziel erkannt')
    s.has('Confirmation primary action Neu initialisieren',reinit_branch,"$primaryText = 'Neu initialisieren'")
    s.no('Reinitialize confirmation does not call it repair',reinit_branch,'Repar')
    prompt=function_fragment(tray,'Prompt-TaskBrokerReinitialize') or ''
    s.has('Explicit confirmation shown before reinitialize',prompt,"Show-LenovoSystemFunctionsDialog -Mode 'Reinitialize'")
    s.has('Reinitialize starts only after Yes',prompt,"DialogResult]::Yes")
    s.has('Reinitialize reuses fixed install path',prompt,"Start-TaskBrokerInstall -Mode 'Reinitialize'")

    # Central interaction block while drift is unresolved.
    s.has('Presentation state blocks normal Ready on drift',function_fragment(tray,'Get-SystemFunctionsPresentationState') or '','ReinitializeRequired')
    s.has('TaskBroker UI derives drift',function_fragment(tray,'Update-TaskBrokerUiState') or '','Test-BootTargetDriftDetected')
    s.has('TaskBroker maintenance menu says neu initialisieren',function_fragment(tray,'Update-TaskBrokerUiState') or '','Systemfunktionen neu initialisieren…')
    s.has('Boot target click blocks on drift',function_fragment(tray,'Update-PopupRows') or '','Test-BootTargetDriftDetected')
    s.has('Manage blocks on drift',function_fragment(tray,'Start-ManageEntriesMode') or '','Test-BootTargetDriftDetected')
    s.has('Default menu blocks on drift',function_fragment(tray,'Show-DefaultTargetMenu') or '','Test-BootTargetDriftDetected')
    s.has('Default mutation blocks on drift',function_fragment(tray,'Set-DefaultGuid') or '','neu initialisiert')
    s.has('Restart blocks on drift',function_fragment(tray,'Restart-Windows') or '','Test-BootTargetDriftDetected')
    s.has('Refresh button uses presentation readiness',function_fragment(tray,'Update-RefreshButtonVisual') or '',"Get-SystemFunctionsPresentationState")
    s.has('Default presentation disables during drift',txt(root/'src/UI/DefaultTargetPresentation.ps1'),'Test-BootTargetDriftDetected')
    s.has('Manage presentation disables during drift',txt(root/'src/UI/ManageEntries.ps1'),'Test-BootTargetDriftDetected')
    s.has('Popup uses presentation readiness',function_fragment(tray,'Show-OrTogglePopup') or '',"Get-SystemFunctionsPresentationState")

    # Reinitialize mode is lifecycle-only and preserves privilege boundary.
    for name in ['Set-MaintenanceRuntimeActive','Enter-SystemFunctionsMaintenance','Start-TaskBrokerInstall','Show-MaintenanceSuccessDialog']:
        s.has(f'Reinitialize mode supported by {name}',function_fragment(tray,name) or '', 'Reinitialize')
    s.has('Install path still launches fixed installer script',function_fragment(tray,'Start-TaskBrokerInstall') or '', '$script:TaskBrokerInstallScript')
    s.no('Install path has no free GUID argument',function_fragment(tray,'Start-TaskBrokerInstall') or '', '-Guid')
    s.no('No automatic reinitialize on detection',upd,'Prompt-TaskBrokerReinitialize')

    # Native tests.
    drift_test=root/'tests/Test-BootTargetDrift.ps1'; s.c('Native drift test exists',drift_test.is_file())
    dtt=txt(drift_test) if drift_test.is_file() else ''
    s.has('Native drift test expects 13 checks',dtt,'DRIFT TOTAL $checks/13')
    s.has('Native drift test covers added target',dtt,'Added firmware target creates drift')
    s.has('Native drift test covers removed target',dtt,'Removed firmware target creates drift')
    mtt=txt(root/'tests/Test-MaintenanceRuntime.ps1')
    s.has('Maintenance native test includes Reinitialize',mtt,"'Reinitialize'")
    s.has('Maintenance native test expects 15 checks',mtt,'MAINTENANCE TOTAL $checks/15')
    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('PS5.1 wrapper runs drift test',wrapper,"tests\\Test-BootTargetDrift.ps1")
    s.eq('PowerShell source count is 39',len(list(root.rglob('*.ps1'))),39)

    # Catch audit and deterministic runtime.
    audit=root/'audits/CATCH_AUDIT_v0.5.1.json'; s.c('v0.5.1 catch audit exists',audit.is_file()); s.c('v0.5.0 catch audit removed',not (root/'audits/CATCH_AUDIT_v0.5.0.json').exists())
    if audit.is_file():
        data=json.loads(audit.read_text(encoding='utf-8')); s.eq('Catch audit version',data.get('version'),'0.5.1'); s.eq('Catch audit count matches entries',data.get('count'),len(data.get('entries',[])))
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Catch audit deterministic',cp.returncode,0)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)

    # Baseline preservation and constrained delta.
    if a.basis_root:
        basis=a.basis_root.resolve(); bt=txt(basis/'LenovoBootMenuTray.ps1')
        for rel in UNCHANGED_FILES:
            s.eq(f'Unrelated file byte-identical to v0.5.0: {rel}',sha_file(root/rel),sha_file(basis/rel))
        old=set(funcs(bt)); new=set(funcs(tray)); s.eq('No existing runtime function removed',old-new,set()); s.eq('Expected new runtime functions',new-old,EXPECTED_NEW)
        changed=set()
        for name in sorted(old & new):
            if function_fragment(bt,name)!=function_fragment(tray,name): changed.add(name)
        s.eq('Only intended existing runtime functions changed',changed,EXPECTED_CHANGED)

    # Permanent security/closed UI invariants.
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false','the form is visible before any fresh Scheduled-Task']:
        s.has(f'Closed UI/runtime contract retained: {x}',tray,x)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No parked manual override marker feature',tray,'manual override marker')
    s.eq('Installer byte-identical to v0.5.0 when basis supplied' if a.basis_root else 'Installer exists', sha_file(root/'Install-LenovoBootMenuTasks.ps1') if a.basis_root else True, sha_file(a.basis_root/'Install-LenovoBootMenuTasks.ps1') if a.basis_root else True)

    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()

if __name__=='__main__': raise SystemExit(main())
