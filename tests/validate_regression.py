#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,zipfile
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def basis_runtime_path(root:Path,name:str)->Path:
    migrated=root/'bin'/name
    return migrated if migrated.is_file() else root/name
class S:
    def __init__(self): self.rows=[]
    def c(self,n,v,d=''): self.rows.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,x in t)
    def no(self,n,t,x): self.c(n,x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.rows: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.rows); print(f'\nTOTAL {p}/{len(self.rows)}'); return 0 if p==len(self.rows) else 1

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--basis-root',type=Path,required=True); ap.add_argument('--release-zip',type=Path); a=ap.parse_args()
    root=a.root.resolve(); basis=a.basis_root.resolve(); s=S()
    meta=json.loads((root/'bin/version.json').read_text(encoding='utf-8')); version=str(meta['version']); profile=str(meta.get('releaseProfile','patch'))
    basis_tray=txt(basis_runtime_path(basis,'LenovoBootMenuTray.ps1')); tray=txt(root/'bin/LenovoBootMenuTray.ps1')
    bm=re.search(r"\$script:AppVersion = '([^']+)'",basis_tray); basis_version=bm.group(1) if bm else ''
    s.has('Generated runtime uses canonical version',tray,f"$script:AppVersion = '{version}'")
    if profile in {'version-only','release-architecture'}:
        normalized=tray.replace(f"$script:AppVersion = '{version}'",f"$script:AppVersion = '{basis_version}'",1)
        s.eq('Product runtime unchanged except injected version',normalized,basis_tray)
        for p in sorted((root/'src').rglob('*.ps1')):
            rel=p.relative_to(root).as_posix()
            if rel=='src/App/LenovoBootMenuTray.template.ps1' and profile=='release-architecture':
                cur=txt(p).replace("$script:AppVersion = '@APP_VERSION@'",f"$script:AppVersion = '{basis_version}'",1)
                s.eq('Template architecture migration changes only version source',cur,txt(basis/rel))
            else:
                s.eq(f'Product module byte-identical to basis: {rel}',sha(p),sha(basis/rel))
    for rel in ['Uninstall-LenovoBootMenuTasks.ps1','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','LenovoBootMenuTray.ico','icon-preview.png']:
        s.eq(f'Runtime asset byte-identical to basis: {rel}',sha(root/'bin'/rel),sha(basis_runtime_path(basis,rel)))
    if profile in {'version-only','release-architecture'}:
        s.eq('Installer byte-identical for non-product release',sha(root/'bin/Install-LenovoBootMenuTasks.ps1'),sha(basis_runtime_path(basis,'Install-LenovoBootMenuTasks.ps1')))
    ui=txt(root/'src/UI/UpdatePresentation.ps1'); infra=txt(root/'src/Infrastructure/UpdateClient.ps1'); transport=txt(root/'src/Infrastructure/UpdateTransport.ps1')
    refresh_ui=txt(root/'src/UI/RefreshPresentation.ps1'); popup_ui=txt(root/'src/UI/Popup.ps1')
    taskbroker=txt(root/'src/Infrastructure/TaskBroker.ps1'); install=txt(root/'bin/Install-LenovoBootMenuTasks.ps1'); diagnostics=txt(root/'src/Infrastructure/RuntimeDiagnostics.ps1')
    s.has('Update button unchanged',ui,"-SecondaryButtonText 'Jetzt aktualisieren' -SecondaryAction { Start-ManualAppUpdate }")
    s.has('LBS-14 shared update dialog title is canonical',ui,"-Title 'Neue App-Version verfügbar'")
    s.has('LBS-14 header message is canonical',refresh_ui,"'Neue App-Version verfügbar'")
    s.has('LBS-14 header interaction remains refresh-gated',refresh_ui,'Set-HeaderUpdateInteractionState -Enabled (-not $active -and $updateAvailable)')
    s.has('LBS-14 header hover uses Lenovo accent state',refresh_ui,'$script:HeaderStatusLabel.Focused')
    s.has('LBS-14 header control is a Button for native keyboard activation',popup_ui,'$headerSub = New-Object System.Windows.Forms.Button')
    s.has('LBS-14 header hover is tracked',popup_ui,'$script:HeaderStatusHovered = $true')
    s.has('LBS-14 header click is interaction-gated',popup_ui,'if (-not $script:HeaderUpdateInteractionEnabled) { return }')
    s.has('LBS-14 header click opens shared dialog',popup_ui,'[void](Show-AvailableUpdateDialog)')
    s.eq('LBS-14 popup contains one shared-dialog invocation',popup_ui.count('Show-AvailableUpdateDialog'),1)
    s.has('No periodic update polling remains',ui,'There is no periodic polling')
    s.has('Startup check is explicit one-shot process state',ui,'StartupCheckStarted')
    s.has('Fixed GitHub source unchanged',transport,'SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.has('LBS-5 transport module owns WebClient creation',transport,'function New-LenovoWebClient')
    s.no('LBS-5 UpdateClient no longer creates WebClient directly',infra,'function New-LenovoWebClient')
    s.has('LBS-5 manifest network failure is structured',transport,"-Category 'network' -Stage 'manifest-download'")
    s.has('LBS-5 package network failure is structured',transport,"-Category 'network' -Stage 'package-download'")
    s.has('LBS-5 hash failure is separate from package failure',infra,"-Category 'hash' -Stage 'package-hash'")
    s.has('LBS-5 check worker returns failure stage',infra,"FailureStage=''")
    s.has('LBS-5 prepare UI propagates network status',ui,'networkStatus=$networkStatus')
    s.no('Updater remains unelevated',infra+'\n'+transport,'RunAs')
    s.no('Updater has no TaskBroker mutation',infra+'\n'+transport,'TaskBroker')
    s.no('Updater has no bcdedit',(infra+'\n'+transport).lower(),'bcdedit')
    s.has('LBS-6 TaskBroker schema is v0.2.13',tray,"$script:SupportedTaskBrokerVersions = @('0.2.13')")
    s.has('LBS-6 installer schema is v0.2.13',install,"$version = '0.2.13'")
    s.has('LBS-6 explicit metadata boundary contract retained',install,"boundaryContract = 'fixed-task-v1'")
    s.no('LBS-6 no free TaskName call reaches runtime runner',taskbroker.lower(),'invoke-authorizedtask -taskname')
    s.has('LBS-6 operation-only runtime runner retained',taskbroker,"[ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]")
    s.has('LBS-6 strict metadata contract retained',taskbroker,'function Test-TaskBrokerMetadataContract')
    s.has('LBS-6 fixed task-name derivation retained',taskbroker,'function Get-TaskBrokerExpectedTargetTaskName')
    s.has('LBS-6 task ACL dangerous-rights rejection retained',install,'$dangerousMask')
    s.has('LBS-6 ProgramData ACL protection retained',install,'function Protect-TaskBrokerStateDirectory')
    s.has('LBS-6 metadata ACL protection retained',install,'function Protect-TaskBrokerMetadataFile')
    s.has('v0.6.4.1 ACL mutation predicate retained',install,'function Test-TaskBrokerRightsContainMutation')
    s.no('v0.6.4.1 broken composite Modify write-mask removed',install,'[System.Security.AccessControl.FileSystemRights]::Modify -bor')
    s.has('v0.6.4.1 state validator calls ACL mutation predicate',install,'Test-TaskBrokerRightsContainMutation -Rights $rights')
    s.has('v0.6.4.1 diagnostics separate physical presence',diagnostics,'$present = [bool](Test-TaskBrokerInstallationPresent)')
    s.has('v0.6.4.1 diagnostics separate metadata readability',diagnostics,'metadataReadable = $true')
    s.has('v0.6.4.1 diagnostics separate compatibility',diagnostics,'compatible = $compatible')
    s.c('LBS-6 security boundary documentation retained',(root/'docs/SECURITY_BOUNDARY.md').is_file())
    s.c('LBS-6 native boundary test retained',(root/'tests/Test-TaskBrokerBoundary.ps1').is_file())
    native_boundary=txt(root/'tests/Test-TaskBrokerBoundary.ps1')
    s.has('v0.6.4.1 native regression accepts ReadAndExecute',native_boundary,'ReadAndExecute is accepted as non-mutating')
    s.has('v0.6.4.1 native regression rejects Modify',native_boundary,'Modify is rejected as mutating')
    s.has('v0.6.4.1 native regression rejects FullControl',native_boundary,'FullControl is rejected as mutating')
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest']:
        s.no(f'No firmware/WMI write path: {bad}',tray,bad)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)
    cp=subprocess.run([sys.executable,str(root/'tools/build_catch_audit.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Catch audit deterministic',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'bin/LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
