#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
UNCHANGED_RUNTIME_FILES=[
    'src/Application/BootService.ps1','src/Application/BootTargetDrift.ps1','src/Application/MaintenanceRuntime.ps1',
    'src/Application/RefreshRuntime.ps1','src/Application/SettingsService.ps1',
    'src/Infrastructure/TaskBroker.ps1','src/Infrastructure/BackgroundRefreshWorker.ps1',
    'src/Infrastructure/SettingsRepository.ps1','src/Infrastructure/Autostart.ps1','src/Infrastructure/Storage.ps1',
    'src/Core/EntryPreferences.ps1','src/Core/FirmwareParsing.ps1','src/Core/BootTargetModel.ps1','src/Core/BootTargetDrift.ps1',
    'src/UI/StartupRecoveryDialog.ps1','src/UI/MenuAppearance.ps1','src/UI/AutostartPresentation.ps1',
    'src/UI/DiagnosticsPresentation.ps1','src/UI/ManageEntriesState.ps1','src/UI/ManageEntries.ps1',
    'src/UI/DefaultTargetPresentation.ps1','src/UI/DefaultTargetMenu.ps1','src/UI/RefreshPresentation.ps1',
    'src/UI/BootEntryList.ps1','src/UI/MaintenancePresentation.ps1','src/UI/Dialogs.ps1','src/UI/Popup.ps1',
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
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path,required=True); ap.add_argument('--release-zip',type=Path); a=ap.parse_args()
    root=a.root.resolve(); basis=a.basis_root.resolve(); s=S(); tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    s.has('App version 0.5.5',tray,"$script:AppVersion = '0.5.5'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.5.5'"),1)
    for rel in UNCHANGED_RUNTIME_FILES:
        s.eq(f'Unrelated product file byte-identical to v0.5.4: {rel}',sha(root/rel),sha(basis/rel))

    for rel in ['src/Core/UpdateModel.ps1','src/Application/UpdateRuntime.ps1','src/Infrastructure/UpdateClient.ps1','src/UI/UpdatePresentation.ps1','tests/Test-UpdateCore.ps1']:
        s.c(f'New updater file exists: {rel}',(root/rel).is_file())
    s.c('PowerShell source count 44',len(list(root.rglob('*.ps1')))==44,f"count={len(list(root.rglob('*.ps1')))}")

    infra=txt(root/'src/Infrastructure/UpdateClient.ps1'); core=txt(root/'src/Core/UpdateModel.ps1'); ui=txt(root/'src/UI/UpdatePresentation.ps1')
    s.has('Manual check exact label',template,"ToolStripMenuItem('Auf neue Version prüfen…')")
    s.has('Manual install exact label',template,"ToolStripMenuItem('App aktualisieren…')")
    s.has('Update check fixed repo',infra,'SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.has('Download fixed repo',infra,'SaschaP1980/LenovoBootSelector/main/downloads/')
    s.no('No arbitrary URL field',infra,'.downloadUrl')
    s.has('SHA-256 package gate',infra,'Get-LenovoSha256Hex')
    s.has('Flat ZIP gate',infra,"$name.Contains('/')")
    s.has('Traversal ZIP gate',infra,"$name.Contains('..')")
    s.has('Backup path',infra,"Join-Path $WorkDir 'backup'")
    s.has('Rollback comment and implementation',infra,'ROLLBACK')
    s.no('No updater elevation',infra,'RunAs')
    s.no('No updater bcdedit',infra.lower(),'bcdedit')
    s.no('No updater TaskBroker',infra,'TaskBroker')
    s.no('No updater scheduled task API',infra,'ScheduledTask')
    s.no('Pure update core has no script state',core,'$script:')
    s.no('Pure update core has no filesystem IO',core,'Test-Path')
    s.no('Pure update core has no WinForms',core,'System.Windows.Forms')
    s.has('No startup polling policy explicit',ui,'no periodic or startup polling')
    s.no('No timer starts in updater infrastructure network layer',infra,'System.Windows.Forms.Timer')

    # Existing safety architecture remains intact.
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No historical Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest']:
        s.no(f'No firmware/WMI write path: {bad}',tray,bad)
    s.has('30-second restore behavior remains existing scope',txt(root/'Install-LenovoBootMenuTasks.ps1'),'defaultRestoreDelaySeconds = 30')

    # Runtime and catch audit are deterministic.
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)
    audit=root/'audits/CATCH_AUDIT_v0.5.5.json'; s.c('v0.5.5 catch audit exists',audit.is_file()); s.c('v0.5.4 catch audit retained',(root/'audits/CATCH_AUDIT_v0.5.4.json').is_file())
    if audit.is_file():
        data=json.loads(audit.read_text(encoding='utf-8')); s.eq('Catch audit version 0.5.5',data.get('version'),'0.5.5'); s.eq('Catch audit count matches entries',data.get('count'),len(data.get('entries',[])))
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Catch audit deterministic',cp.returncode,0)

    # Distribution remains portable and flat.
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
