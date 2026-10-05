#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
ALLOWED_CHANGED_RUNTIME={
    'src/Core/UpdateModel.ps1','src/UI/UpdatePresentation.ps1','src/App/LenovoBootMenuTray.template.ps1','LenovoBootMenuTray.ps1',
    'README.md','CHANGELOG.md','BUILD_INTEGRITY.txt','tests/Test-UpdateCore.ps1',
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
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path,required=True); ap.add_argument('--release-zip',type=Path); a=ap.parse_args()
    root=a.root.resolve(); basis=a.basis_root.resolve(); s=S(); tray=txt(root/'LenovoBootMenuTray.ps1'); core=txt(root/'src/Core/UpdateModel.ps1'); ui=txt(root/'src/UI/UpdatePresentation.ps1'); infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    s.has('App version 0.5.8.1',tray,"$script:AppVersion = '0.5.8.1'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.5.8.1'"),1)
    # Product runtime outside the hotfix scope must remain byte-identical to the canonical v0.5.8.0 basis.
    for rel in [
        'src/Application/BootService.ps1','src/Application/BootTargetDrift.ps1','src/Application/MaintenanceRuntime.ps1','src/Application/RefreshRuntime.ps1','src/Application/SettingsService.ps1','src/Application/UpdateRuntime.ps1',
        'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1','src/Infrastructure/SettingsRepository.ps1','src/Infrastructure/Autostart.ps1','src/Infrastructure/Storage.ps1','src/Infrastructure/RuntimeDiagnostics.ps1','src/Infrastructure/UpdateClient.ps1',
        'src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1','src/Core/BootTargetDrift.ps1',
        'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/AutostartPresentation.ps1','src/UI/DiagnosticsPresentation.ps1','src/UI/ManageEntriesState.ps1','src/UI/ManageEntries.ps1','src/UI/DefaultTargetPresentation.ps1','src/UI/DefaultTargetMenu.ps1','src/UI/RefreshPresentation.ps1','src/UI/BootEntryList.ps1','src/UI/MaintenancePresentation.ps1','src/UI/Dialogs.ps1','src/UI/Popup.ps1',
        'Install-LenovoBootMenuTasks.ps1','Uninstall-LenovoBootMenuTasks.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','LenovoBootMenuTray.ico','icon-preview.png']:
        s.eq(f'Unrelated runtime file byte-identical to v0.5.8.0: {rel}',sha(root/rel),sha(basis/rel))
    s.has('Legacy compatibility resolver present',core,'Resolve-LenovoUpdateRestartResultCore')
    s.has('Legacy success property tested by presence',core,"$Result.PSObject.Properties['success']")
    s.has('Legacy boolean is required',core,'-is [bool]')
    s.has('Legacy result format diagnostic',core,"'legacy-success'")
    s.has('Status result format diagnostic',core,"'status'")
    s.has('UI uses core resolver',ui,'Resolve-LenovoUpdateRestartResultCore')
    s.has('Diagnostic includes result format',ui,'resultFormat = $resolved.ResultFormat')
    s.has('Diagnostic includes legacy success field',ui,'legacySuccess = $resolved.LegacySuccess')
    s.has('One-shot consume remains before modal',ui,'Remove-LenovoUpdateResult')
    s.has('Manual-only update policy unchanged',ui,'no periodic or startup polling')
    s.has('Fixed GitHub update source unchanged',infra,'SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.no('Updater remains unelevated',infra,'RunAs')
    s.no('Updater still has no TaskBroker mutation',infra,'TaskBroker')
    s.no('Updater still has no bcdedit',infra.lower(),'bcdedit')
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest']:
        s.no(f'No firmware/WMI write path: {bad}',tray,bad)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Catch audit deterministic',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
