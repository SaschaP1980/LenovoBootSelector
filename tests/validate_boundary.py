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
def load_version(root):
    p=root/'bin/version.json'
    if not p.is_file(): return None
    import json
    return str(json.loads(p.read_text(encoding='utf-8'))['version'])
def sha_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def psfn(s,n):
    m=re.search(rf'(?m)^function\s+{re.escape(n)}\b',s)
    if not m:return ''
    q=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',s[m.end():]); e=m.end()+q.start() if q else len(s)
    return s[m.start():e].rstrip()+"\n"

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root
    s=Suite(); tray=txt(root/'bin/LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootSelector.template.ps1')
    refresh_controller=txt(root/'src/Application/RefreshController.ps1') if (root/'src/Application/RefreshController.ps1').is_file() else ''
    refresh_worker=txt(root/'src/Infrastructure/BackgroundRefreshWorker.ps1') if (root/'src/Infrastructure/BackgroundRefreshWorker.ps1').is_file() else ''
    refresh_ui=txt(root/'src/UI/RefreshPresentation.ps1') if (root/'src/UI/RefreshPresentation.ps1').is_file() else ''
    version=load_version(root)
    s.check('bin/version.json provides version',bool(version))
    expected=f"$script:AppVersion = '{version}'" if version else ''
    s.contains(f'App version is {version}',tray,expected)
    s.eq('App version declaration exactly once',tray.count(expected),1)
    s.check('Infrastructure TaskBroker module exists',(root/INFRA).is_file())
    s.check('Application BootService module exists',(root/APP).is_file())
    infra=txt(root/INFRA) if (root/INFRA).is_file() else ''; app=txt(root/APP) if (root/APP).is_file() else ''
    install=txt(root/'bin/Install-LenovoBootMenuTasks.ps1'); security_doc=txt(root/'docs/SECURITY_BOUNDARY.md') if (root/'docs/SECURITY_BOUNDARY.md').is_file() else ''
    diagnostics=txt(root/'src/Infrastructure/RuntimeDiagnostics.ps1')
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
    # Infrastructure owns privileged mechanics; app/template cannot access the runner.
    runner=psfn(infra,'Invoke-AuthorizedTask'); resolver=psfn(infra,'Resolve-TaskBrokerAuthorizedTaskName'); contract=psfn(infra,'Test-TaskBrokerMetadataContract')
    s.contains('Infrastructure retains exact operation runner',infra,'function Invoke-AuthorizedTask')
    s.absent('Template does not directly call authorized operation runner',template,'Invoke-AuthorizedTask')
    s.absent('Application does not directly call authorized operation runner',app,'Invoke-AuthorizedTask')
    s.absent('Application has no Start-ScheduledTask',app,'Start-ScheduledTask')
    s.absent('Application has no Get-ScheduledTask',app,'Get-ScheduledTask')
    s.absent('Application has no Schedule.Service',app,'Schedule.Service')
    s.absent('Application has no script-global state',app,'$script:')
    s.absent('Application has no WinForms',app,'System.Windows.Forms')
    s.contains('Exact-task COM access stays infrastructure-only',infra,"New-Object -ComObject 'Schedule.Service'")
    s.contains('Exact task start stays infrastructure-only',runner,'Start-ScheduledTask -TaskName $taskName')
    s.absent('LBS-6 runtime runner accepts no free TaskName parameter',runner.lower(),'[string]$taskname')
    s.contains('LBS-6 runtime runner accepts only operation enum',runner,"[ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]")
    s.contains('LBS-6 runtime runner resolves task before scheduler access',runner,'Resolve-TaskBrokerAuthorizedTaskName -Operation $Operation')
    s.contains('LBS-6 resolver exposes fixed operation set',resolver,"[ValidateSet('ManagerRefresh','FirmwareRefresh','BootNext','DefaultSet','DefaultClear')]")
    s.absent('LBS-6 DefaultRestore not exposed as runtime operation',resolver,"'DefaultRestore'")
    s.contains('LBS-6 manager refresh name is fixed',resolver,"return 'LenovoBootSelector-RefreshManager'")
    s.contains('LBS-6 firmware refresh name is fixed',resolver,"return 'LenovoBootSelector-RefreshFirmware'")
    s.contains('LBS-6 default clear name is fixed',resolver,"return 'LenovoBootSelector-Default-Clear'")
    s.contains('LBS-6 target task names are derived from GUID',infra,'function Get-TaskBrokerExpectedTargetTaskName')
    s.contains('LBS-6 metadata requires explicit boundary contract',contract,"boundaryContract -ne 'fixed-task-v2'")
    s.contains('LBS-6 metadata fixes manager state path',contract,"'fwbootmgr.txt'")
    s.contains('LBS-6 metadata fixes firmware state path',contract,"'firmware.txt'")
    s.contains('LBS-6 metadata fixes default state path',contract,"'default-guid.txt'")
    s.contains('LBS-33 canonical manager task name is fixed',contract,"'LenovoBootSelector-RefreshManager'")
    s.absent('LBS-33 legacy manager task is not authorized by metadata contract',contract,"'LenovoBootMenu-RefreshManager'")
    s.contains('LBS-33 runtime can detect legacy install only for repair',infra,'LegacyTaskBrokerMetadataPath')

    s.contains('LBS-6 metadata rejects duplicate GUIDs',contract,'$seenGuids.ContainsKey($normalized)')
    s.contains('LBS-6 metadata rejects duplicate task names',contract,'$seenTaskNames.ContainsKey($bootKey)')
    s.contains('BootNext resolves target from metadata',psfn(infra,'Set-TaskBrokerBootNextTarget'),'Get-TaskBrokerTarget -Guid $normalized')
    s.contains('BootNext invokes only operation-gated runner',psfn(infra,'Set-TaskBrokerBootNextTarget'),"Invoke-AuthorizedTask -Operation 'BootNext' -Guid $normalized")
    s.contains('Default set resolves target from metadata',psfn(infra,'Set-TaskBrokerDefaultTarget'),'Get-TaskBrokerTarget -Guid $normalized')
    s.contains('Default set invokes only operation-gated runner',psfn(infra,'Set-TaskBrokerDefaultTarget'),"Invoke-AuthorizedTask -Operation 'DefaultSet' -Guid $normalized")
    s.contains('Default clear invokes only fixed operation',psfn(infra,'Clear-TaskBrokerDefaultTarget'),"Invoke-AuthorizedTask -Operation 'DefaultClear'")
    s.contains('Boot service verifies returned bootsequence',psfn(app,'Set-BootNextTargetService'),'ConvertFrom-FirmwareManagerText')
    s.contains('Boot service requires exact selected GUID',psfn(app,'Set-BootNextTargetService'),'SelectedGuid -ne $normalized')
    fw=psfn(tray,'Get-FirmwareBootState'); s.contains('Firmware shell delegates broker read/parse to boot service',fw,'Get-BootServiceFirmwareSnapshot')
    s.absent('Firmware shell no direct TaskBroker metadata IO',fw,'Get-TaskBrokerMetadata')
    default=psfn(tray,'Set-DefaultGuid')
    s.contains('Default UI shell uses explicit broker set',default,'Set-TaskBrokerDefaultTarget')
    s.contains('Default UI shell uses explicit broker clear',default,'Clear-TaskBrokerDefaultTarget')
    dstate=psfn(tray,'Refresh-SystemDefaultState'); s.contains('Default read uses explicit broker operation',dstate,'Get-TaskBrokerDefaultTargetGuid')
    s.check('LBS-27 refresh controller module exists',(root/'src/Application/RefreshController.ps1').is_file())
    s.check('LBS-27 refresh worker infrastructure module exists',(root/'src/Infrastructure/BackgroundRefreshWorker.ps1').is_file())
    s.eq('LBS-27 refresh controller include marker exactly once',template.count('# @include src/Application/RefreshController.ps1'),1)
    for fn_name in ['Get-BackgroundRefreshResult','Apply-BackgroundRefreshResult','Stop-BackgroundBootRefreshForMaintenance','Complete-BackgroundBootRefresh','Start-BackgroundBootRefresh']:
        s.eq(f'LBS-27 {fn_name} removed from app template',len(re.findall(rf'(?m)^function\s+{re.escape(fn_name)}\b',template)),0)
        s.eq(f'LBS-27 {fn_name} owned once by Application controller',len(re.findall(rf'(?m)^function\s+{re.escape(fn_name)}\b',refresh_controller)),1)
    s.eq('LBS-27 worker execution removed from app template',len(re.findall(r'(?m)^function\s+Invoke-BackgroundRefreshWorker\b',template)),0)
    s.eq('LBS-27 worker execution owned once by Infrastructure',len(re.findall(r'(?m)^function\s+Invoke-BackgroundRefreshWorker\b',refresh_worker)),1)
    s.absent('LBS-27 Application controller has no direct WinForms construction',refresh_controller,'System.Windows.Forms')
    for forbidden in ['[System.IO.File]','Get-Disk','Get-Partition','Get-ScheduledTask','Invoke-AuthorizedTask']:
        s.absent(f'LBS-27 Application controller excludes infrastructure token {forbidden}',refresh_controller,forbidden)
    s.contains('LBS-27 UI owns completion timer construction',refresh_ui,'function New-BackgroundRefreshCompletionTimer')
    s.contains('LBS-27 controller delegates completion timer construction',psfn(refresh_controller,'Start-BackgroundBootRefresh'),'New-BackgroundRefreshCompletionTimer')
    s.absent('LBS-27 refresh controller does not depend on update workflow',refresh_controller,'UpdateCheck')
    s.absent('LBS-27 refresh controller does not depend on update prepare workflow',refresh_controller,'UpdatePrepare')
    worker=psfn(refresh_worker,'Invoke-BackgroundRefreshWorker')
    s.contains('Background worker uses explicit manager read',worker,'Get-TaskBrokerFirmwareManagerText -Force')
    s.contains('Background worker uses explicit firmware read',worker,'Get-TaskBrokerFirmwareEntriesText -Force')
    s.contains('LBS-27 Background worker owns result-file write',worker,'[System.IO.File]::WriteAllText')
    s.contains('LBS-27 Background worker owns storage access',worker,'Get-StorageContext')
    # No new generic privileged command/GUID API.
    for bad in ['Invoke-PrivilegedCommand','Invoke-PrivilegedTask','-CommandText','-Arguments $Arguments','param([string]$TaskName)']:
        s.absent(f'No generic privileged API token: {bad}',app+'\n'+template,bad)
    s.absent('No direct bcdedit executable from tray',tray.lower(),'bcdedit.exe')
    s.absent('No permanent displayorder set in tray',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    # Installer/uninstaller and core remain unchanged from v0.4.1 inputs.
    base=json.loads((root/'tests/characterization-baseline-v0.3.4.json').read_text())
    for fn in ['LenovoBootMenuTray.ico','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','icon-preview.png']:
        s.eq(f'Unrelated runtime asset still baseline-identical: {fn}',sha_file(root/'bin'/fn),base['source_sha256'][fn])
    s.contains('LBS-6 installer schema bumped',install,"$version = '0.2.14'")
    s.contains('LBS-6 installer writes boundary contract',install,"boundaryContract = 'fixed-task-v2'")
    s.contains('LBS-6 task ACL rejects dangerous rights',install,'$dangerousMask')
    s.absent('LBS-6 task ACL no longer treats GenericAll as sufficient',install,'$hasAll =')
    s.contains('LBS-6 task ACL replaces user allow ACEs',install,'function Get-TaskReadExecuteOnlySddl')
    s.contains('LBS-6 state directory disables inherited ACLs',install,'$acl.SetAccessRuleProtection($true,$false)')
    state_acl=psfn(install,'Test-TaskBrokerStatePathLeastPrivilege'); rights_predicate=psfn(install,'Test-TaskBrokerRightsContainMutation'); broker_summary=psfn(diagnostics,'Get-RuntimeDiagnosticBrokerSummary')
    s.contains('LBS-6 state directory least-privilege validator exists',install,'function Test-TaskBrokerStatePathLeastPrivilege')
    s.contains('v0.6.4.1 ACL mutation predicate exists',install,'function Test-TaskBrokerRightsContainMutation')
    s.contains('v0.6.4.1 ACL mutation predicate checks concrete write rights',rights_predicate,'FileSystemRights]::WriteData')
    s.absent('v0.6.4.1 state ACL validator excludes composite Modify mask',state_acl,'FileSystemRights]::Modify')
    s.contains('v0.6.4.1 state ACL validator delegates mutation decision',state_acl,'Test-TaskBrokerRightsContainMutation -Rights $rights')
    s.contains('v0.6.4.1 broker diagnostics use physical presence probe',broker_summary,'Test-TaskBrokerInstallationPresent')
    s.contains('v0.6.4.1 broker diagnostics expose metadataReadable',broker_summary,'metadataReadable = $true')
    s.contains('v0.6.4.1 broker diagnostics expose compatibility',broker_summary,'compatible = $compatible')
    s.absent('v0.6.4.1 broker diagnostics do not conflate trust and presence',broker_summary,'$meta = Get-TaskBrokerMetadata')
    s.contains('LBS-6 ProgramData state is explicitly protected',install,'function Protect-TaskBrokerStateDirectory')
    s.contains('LBS-6 metadata file is explicitly protected',install,'function Protect-TaskBrokerMetadataFile')
    s.contains('LBS-6 security boundary document exists',security_doc,'No runtime API accepts a free Scheduled Task name.')
    s.contains('LBS-6 security boundary documents one-shot rule',security_doc,'One-Shot Next Boot')
    s.check('LBS-6 native TaskBroker boundary test exists',(root/'tests/Test-TaskBrokerBoundary.ps1').is_file())
    aggregate=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.contains('LBS-6 native boundary test is in PS5.1 aggregate',aggregate,'Test-TaskBrokerBoundary.ps1')
    s.contains('LBS-33 native migration test is in PS5.1 aggregate',aggregate,'Test-TaskBrokerMigration.ps1')
    native_boundary=txt(root/'tests/Test-TaskBrokerBoundary.ps1')
    s.contains('v0.6.4.1 native ACL regression accepts ReadAndExecute',native_boundary,'ReadAndExecute is accepted as non-mutating')
    s.contains('v0.6.4.1 native ACL regression rejects Modify',native_boundary,'Modify is rejected as mutating')
    s.contains('v0.6.4.1 native ACL regression rejects FullControl',native_boundary,'FullControl is rejected as mutating')
    uninstall_bytes=(root/'bin/Uninstall-LenovoBootMenuTasks.ps1').read_bytes()
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
