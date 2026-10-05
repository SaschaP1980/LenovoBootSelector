#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
EXPECTED_CHANGED={
    'Set-DefaultGuid','Restart-Windows','Update-TaskBrokerUiState','Complete-TaskBrokerInstall',
    'Start-TaskBrokerInstall','Prompt-TaskBrokerInstall','Complete-TaskBrokerRemove','Start-TaskBrokerRemove',
    'Prompt-TaskBrokerRemove','Apply-BackgroundRefreshResult','Complete-BackgroundBootRefresh',
    'Start-BackgroundBootRefresh','Update-HeaderRefreshStatus','Update-RefreshButtonVisual',
    'Start-ManageEntriesMode','Show-DefaultTargetMenu','Update-PopupRows','New-PopupForm','Show-OrTogglePopup'
}
EXPECTED_NEW={
    'New-MaintenanceRuntimeState','Set-MaintenanceRuntimeActive','Clear-MaintenanceRuntimeState',
    'Test-MaintenanceRuntimeBusy','Get-MaintenanceRuntimeMode','Test-MaintenanceBusy','Get-MaintenanceMode',
    'Get-SystemFunctionsPresentationState','Get-MaintenanceBusyStatusText','New-MaintenanceStatePanel',
    'Update-MaintenanceUi','Show-MaintenanceSuccessDialog','Enter-SystemFunctionsMaintenance',
    'Exit-SystemFunctionsMaintenance','Stop-BackgroundBootRefreshForMaintenance'
}
UNCHANGED_FILES=[
    'src/Application/BootService.ps1','src/Application/RefreshRuntime.ps1','src/Application/SettingsService.ps1',
    'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Infrastructure/SettingsRepository.ps1','src/Infrastructure/Autostart.ps1','src/Infrastructure/RuntimeDiagnostics.ps1',
    'src/Infrastructure/Storage.ps1','src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1',
    'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/AutostartPresentation.ps1',
    'src/UI/DiagnosticsPresentation.ps1','src/UI/ManageEntriesState.ps1','src/UI/DefaultTargetPresentation.ps1',
    'src/UI/Dialogs.ps1','Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1',
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
            if c=='`': i+=2
            elif c=='"': mode='code'; i+=1
            else:i+=1
    return None

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.4.7',tray,"$script:AppVersion = '0.4.7'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.7'"),1)
    s.c('README title v0.4.7',readme.startswith('# Lenovo Boot Selector v0.4.7'))
    s.has('README documents Maintenance UX',readme,'Maintenance UX')

    app=root/'src/Application/MaintenanceRuntime.ps1'; ui=root/'src/UI/MaintenancePresentation.ps1'
    s.c('Maintenance application module exists',app.is_file()); s.c('Maintenance presentation module exists',ui.is_file())
    at=txt(app) if app.is_file() else ''; ut=txt(ui) if ui.is_file() else ''
    s.eq('Maintenance application functions',funcs(at),['New-MaintenanceRuntimeState','Set-MaintenanceRuntimeActive','Clear-MaintenanceRuntimeState','Test-MaintenanceRuntimeBusy','Get-MaintenanceRuntimeMode'])
    s.no('Maintenance runtime has no script globals',at,'$script:')
    for token in ['System.Windows.Forms','Start-Process','ScheduledTask','TaskBroker','Test-Path']:
        s.no(f'Maintenance runtime excludes infrastructure/UI token {token}',at,token)
    for marker in ['# @include src/Application/MaintenanceRuntime.ps1','# @include src/UI/MaintenancePresentation.ps1']:
        s.eq(f'Include marker once {marker}',template.count(marker),1)
        s.no(f'No unresolved include {marker}',tray,marker)

    for token in ['MaintenanceStatePanel','Systemfunktionen einrichten','Systemfunktionen reparieren','Systemfunktionen werden entfernt…','Die App wird nach Abschluss automatisch aktualisiert.']:
        s.has(f'Central maintenance presentation: {token}',ut,token)
    s.has('First-run primary CTA calls safe existing prompt',ut,'Prompt-TaskBrokerInstall')
    s.no('Maintenance UI has no privileged task runner',ut,'Invoke-AuthorizedTask')
    s.no('Maintenance UI has no Start-ScheduledTask',ut,'Start-ScheduledTask')

    # Busy lifecycle and concurrent work suppression.
    for token in ['Set-MaintenanceRuntimeActive -State $script:MaintenanceState','Stop-BackgroundBootRefreshForMaintenance -Reason $Mode','Clear-MaintenanceRuntimeState -State $script:MaintenanceState','BACKGROUND_REFRESH_CANCELLED_FOR_MAINTENANCE','BACKGROUND_REFRESH_SUPPRESSED','BACKGROUND_REFRESH_RESULT_IGNORED']:
        s.has(f'Maintenance lifecycle contract: {token}',tray,token)
    s.has('Setup start records explicit mode',tray,'Start-TaskBrokerInstall -Mode $mode')
    s.has('Remove enters central state',tray,"Enter-SystemFunctionsMaintenance -Mode 'Remove'")
    s.has('TaskBroker UI uses central busy state',function_fragment(tray,'Update-TaskBrokerUiState'),'Test-MaintenanceBusy')
    s.has('TaskBroker UI avoids full ready check while busy',function_fragment(tray,'Update-TaskBrokerUiState'),'if ($busy)')
    s.has('Refresh start is blocked during maintenance',function_fragment(tray,'Start-BackgroundBootRefresh'),'if (Test-MaintenanceBusy)')
    s.has('Refresh completion is blocked during maintenance',function_fragment(tray,'Complete-BackgroundBootRefresh'),'Stop-BackgroundBootRefreshForMaintenance')
    s.has('Boot-row click is blocked during maintenance',function_fragment(tray,'Update-PopupRows'),'if (Test-MaintenanceBusy) { return }')
    s.has('Manage mode is blocked during maintenance',function_fragment(tray,'Start-ManageEntriesMode'),'if (Test-MaintenanceBusy) { return }')
    s.has('Default menu is blocked during maintenance',function_fragment(tray,'Show-DefaultTargetMenu'),'if (Test-MaintenanceBusy) { return }')
    s.has('Default mutation is blocked during maintenance',function_fragment(tray,'Set-DefaultGuid'),'Während der Wartung')
    s.has('Restart is blocked during maintenance',function_fragment(tray,'Restart-Windows'),'if (Test-MaintenanceBusy) { return }')

    # Completion UX and no false-ready diagnostic after removal.
    ci=function_fragment(tray,'Complete-TaskBrokerInstall'); cr=function_fragment(tray,'Complete-TaskBrokerRemove')
    s.has('Install success uses app dialog',ci,'Show-MaintenanceSuccessDialog -Mode $completedMode')
    s.has('Remove success uses app dialog',cr,"Show-MaintenanceSuccessDialog -Mode 'Remove'")
    s.has('Remove completion caches expected not-ready state',cr,'$script:TaskBrokerReadyCached = $false')
    s.no('Remove completion does not call full ready check',cr,'Test-TaskBrokerReady')
    s.has('Maintenance exit rebuilds UI',function_fragment(tray,'Exit-SystemFunctionsMaintenance'),'Update-PopupRows')
    s.no('Old maintenance success balloon removed from install completion',ci,'ShowBalloonTip')
    s.no('Old maintenance success balloon removed from remove completion',cr,'ShowBalloonTip')

    # First-run central UX.
    s.has('Startup auto-opens popup when metadata missing/incompatible',template,'if (-not $metadataCompatible) {\n        # First-run / incomplete-install UX')
    s.no('Startup no longer instructs right-click maintenance',template,'Rechtsklick → Wartung')
    s.no('Startup no longer relies on setup balloon',template,'Einmalige Einrichtung der Systemfunktionen erforderlich.')
    pop=function_fragment(tray,'Show-OrTogglePopup')
    s.has('Popup is maintenance-aware',pop,'$maintenanceBusy = Test-MaintenanceBusy')
    s.has('Popup missing-state text is user-facing',pop,'Systemfunktionen müssen eingerichtet werden.')
    s.has('Popup repair-state text is user-facing',pop,'Systemfunktionen müssen repariert werden.')
    s.has('Popup does not start worker while maintenance busy',pop,'if ($brokerReady -and -not $maintenanceBusy)')

    # Soak bug fix and native maintenance test.
    soak=txt(root/'tests/Test-ArchitectureSoak.ps1')
    s.has('Soak settings call uses correct Source parameter',soak,'ConvertTo-NormalizedAppSettingsCore -Source $raw')
    s.no('Soak no longer uses wrong Settings parameter',soak,'ConvertTo-NormalizedAppSettingsCore -Settings $raw')
    mt=root/'tests/Test-MaintenanceRuntime.ps1'; s.c('Native maintenance runtime test exists',mt.is_file())
    mtt=txt(mt) if mt.is_file() else ''
    s.has('Maintenance native test expects 13 checks',mtt,'MAINTENANCE TOTAL $checks/13')
    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('PS5.1 wrapper runs maintenance test',wrapper,"tests\\Test-MaintenanceRuntime.ps1")
    s.eq('PowerShell source count is 36',len(list(root.rglob('*.ps1'))),36)

    # Catch audit and build generators updated.
    audit=root/'CATCH_AUDIT_v0.4.7.json'; s.c('v0.4.7 catch audit exists',audit.is_file())
    s.c('v0.4.6 catch audit removed',not (root/'CATCH_AUDIT_v0.4.6.json').exists())
    if audit.is_file():
        data=json.loads(audit.read_text(encoding='utf-8')); s.eq('Catch audit version',data.get('version'),'0.4.7'); s.eq('Catch audit count is entries',data.get('count'),len(data.get('entries',[])))
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Catch audit deterministic',cp.returncode,0)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)

    # Baseline preservation outside intended lifecycle/UI changes.
    if a.basis_root:
        basis=a.basis_root.resolve(); bt=txt(basis/'LenovoBootMenuTray.ps1')
        for rel in UNCHANGED_FILES:
            s.eq(f'Unrelated file byte-identical to v0.4.6: {rel}',sha_file(root/rel),sha_file(basis/rel))
        old=set(funcs(bt)); new=set(funcs(tray));
        added=new-old; removed=old-new
        s.eq('No existing runtime function removed',removed,set())
        s.eq('Expected new runtime function set',added,EXPECTED_NEW)
        changed=set()
        for name in sorted(old & new):
            of=function_fragment(bt,name); nf=function_fragment(tray,name)
            if of!=nf: changed.add(name)
        s.eq('Only intended existing runtime functions changed',changed,EXPECTED_CHANGED)

    # Permanent security and closed UX invariants.
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false','the form is visible before any fresh Scheduled-Task']:
        s.has(f'Closed UI/runtime contract retained: {x}',tray,x)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No parked firmware drift feature',tray,'firmware drift')
    s.no('No free manual override marker feature',tray,'manual override marker')

    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
