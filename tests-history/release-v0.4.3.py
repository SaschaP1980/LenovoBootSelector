#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, re, subprocess, sys, zipfile

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
APP_REFRESH='src/Application/RefreshRuntime.ps1'
INFRA_WORKER='src/Infrastructure/BackgroundRefreshWorker.ps1'
BASELINE_SHA={
    'src/Infrastructure/TaskBroker.ps1':'549e3f3df30a8fdefa6133401d6345740192662ebb261077845d0ad5415ed14a',
    'src/Application/BootService.ps1':'b9fe6538113370b6abfffe0dd813fc8eb9ac0a3a26b2ffd94344530fd5d2263b',
    'src/Core/BootTargetModel.ps1':'f00e6268e4982ab3f46104c9396d35df530c08569ef45663b2332511403e345e',
    'src/Core/EntryPreferences.ps1':'abb5c47df2dffb776bd6b85afb324a6af96bf7beeb4204329e2fa7dd250c681e',
    'src/Core/FirmwareParsing.ps1':'3d4c4989d8ace808e0b40a81230b7bb9456a56a30dd16f07e8fbc3a2be29a3b6',
    'Install-LenovoBootMenuTasks.ps1':'6de32e668b2a5535e963842712274160aabdd357c7ef513eba209b3202354662',
    'Uninstall-LenovoBootMenuTasks.ps1':'201c7ee0794c834b22df97b6ed8c0f4503fd6b4eecf2bd6bd326bfa8ec0bf5c7',
    'Start-LenovoBootMenuTray.vbs':'ef0ed39201596eff9bf9e944acf2fe7ac7ea5f904f97ec001c13566dbf546eb3',
    'Start-LenovoBootMenuTray.cmd':'05b1f997cfb2be13c915c67e76cc8c62f6f9acf9095c37b43ec3801bdde8ad41',
    'LenovoBootMenuTray.ico':'e6b4dcb643b770e523f95365804bbbfda62884b362cd49318509d952dddbdda3',
    'icon-preview.png':'43c301063a4dd9851544bb49f48d50f204dd242231303150d8449ad131529eb1',
}

class S:
    def __init__(self): self.r=[]
    def c(self,n,v,d=''): self.r.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n,x in t)
    def no(self,n,t,x): self.c(n,x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.r: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.r); print(f'\nTOTAL {p}/{len(self.r)}'); return 0 if p==len(self.r) else 1

def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def sha_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def fn(t,n):
    m=re.search(rf'(?m)^function\s+{re.escape(n)}\b',t)
    if not m:return ''
    q=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',t[m.end():]); e=m.end()+q.start() if q else len(t)
    return t[m.start():e].rstrip()+"\n"

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root; s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    app=txt(root/APP_REFRESH) if (root/APP_REFRESH).is_file() else ''; worker=txt(root/INFRA_WORKER) if (root/INFRA_WORKER).is_file() else ''
    s.has('App version 0.4.3',tray,"$script:AppVersion = '0.4.3'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.3'"),1)
    s.c('README title v0.4.3',readme.startswith('# Lenovo Boot Selector v0.4.3'))
    s.has('README documents refresh runtime refactor',readme,'expliziter Refresh-Runtime-State')

    for rel in [APP_REFRESH,INFRA_WORKER]:
        s.c(f'Module exists: {rel}',(root/rel).is_file())
        marker=f'# @include {rel}'
        s.eq(f'Include marker once: {rel}',template.count(marker),1)
        s.no(f'No unresolved marker in runtime: {rel}',tray,marker)

    # Application refresh state is pure orchestration/state; no hidden global or OS/UI dependency.
    for token in ['$script:','System.Windows.Forms','ProcessStartInfo','Process]::Start','Test-Path','ReadAllText','WriteAllText','Start-ScheduledTask','Schedule.Service']:
        s.no(f'RefreshRuntime excludes {token}',app,token)
    for name in ['New-BackgroundRefreshRequest','New-BackgroundRefreshRuntimeState','Test-BackgroundRefreshActive','Test-BackgroundRefreshNeedsFirmware','Test-BackgroundRefreshRequestEscalation','Add-BackgroundRefreshPendingRequest','Set-BackgroundRefreshActive','Set-BackgroundRefreshTimer','Take-BackgroundRefreshCompletionContext','Take-BackgroundRefreshPendingRequest','Set-BackgroundRefreshLastTiming','ConvertFrom-BackgroundRefreshResultText']:
        s.eq(f'Refresh contract function once: {name}',len(re.findall(rf'(?m)^function\s+{re.escape(name)}\b',app)),1)
        s.eq(f'Refresh contract bundled once: {name}',len(re.findall(rf'(?m)^function\s+{re.escape(name)}\b',tray)),1)

    # Worker/process mechanics stay infrastructure-only and receive explicit data.
    s.no('Background worker infrastructure has no script-global state',worker,'$script:')
    s.no('Background worker infrastructure has no WinForms',worker,'System.Windows.Forms')
    s.has('Infrastructure owns ProcessStartInfo',worker,'System.Diagnostics.ProcessStartInfo')
    s.has('Infrastructure starts hidden Windows PowerShell',worker,"System32\\WindowsPowerShell\\v1.0\\powershell.exe")
    s.has('Infrastructure keeps CreateNoWindow',worker,'$psi.CreateNoWindow = $true')
    s.has('Infrastructure reads result file',worker,'function Read-BackgroundRefreshResultText')
    s.has('Infrastructure owns result cleanup',worker,'function Remove-BackgroundRefreshResultFile')

    old_globals=['BackgroundRefreshProcess','BackgroundRefreshTimer','BackgroundRefreshResultPath','BackgroundRefreshRequestedStorage','BackgroundRefreshRequestedFirmware','BackgroundRefreshPending','BackgroundRefreshPendingStorage','BackgroundRefreshPendingFirmware','LastBackgroundRefreshTiming']
    for name in old_globals: s.no(f'Legacy refresh global removed: {name}',template,f'$script:{name}')
    s.has('Single refresh state global initialized',template,'$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState')
    s.eq('Refresh state initialization once',template.count('$script:BackgroundRefreshState = New-BackgroundRefreshRuntimeState'),1)

    start=fn(tray,'Start-BackgroundBootRefresh'); complete=fn(tray,'Complete-BackgroundBootRefresh'); apply=fn(tray,'Apply-BackgroundRefreshResult'); getres=fn(tray,'Get-BackgroundRefreshResult')
    s.has('Start uses cache freshness contract',start,'Test-BackgroundRefreshNeedsFirmware')
    s.has('Start creates explicit request',start,'New-BackgroundRefreshRequest')
    s.has('Start coalesces only escalations',start,'Test-BackgroundRefreshRequestEscalation')
    s.has('Start stores pending request through state contract',start,'Add-BackgroundRefreshPendingRequest')
    s.has('Start delegates process creation to infrastructure',start,'Start-BackgroundRefreshWorkerProcess')
    s.has('Start records active lifecycle through state contract',start,'Set-BackgroundRefreshActive')
    s.has('Start records timer through state contract',start,'Set-BackgroundRefreshTimer')
    s.no('Start no direct ProcessStartInfo',start,'ProcessStartInfo')
    s.has('Complete takes one lifecycle context',complete,'Take-BackgroundRefreshCompletionContext')
    s.has('Complete applies parsed result separately',complete,'Apply-BackgroundRefreshResult')
    s.has('Complete consumes coalesced pending request',complete,'Take-BackgroundRefreshPendingRequest')
    s.has('Complete delegates result file cleanup',complete,'Remove-BackgroundRefreshResultFile')
    s.has('Result reader separates IO and parsing',getres,'Read-BackgroundRefreshResultText')
    s.has('Result reader uses application parser',getres,'ConvertFrom-BackgroundRefreshResultText')
    s.has('Result application preserves broker-ready failure UX',apply,'Reparatur erforderlich · Rechtsklick → Wartung')
    s.has('Result application preserves cache sync',apply,'Sync-TaskBrokerFirmwareCachesFromFiles')
    s.has('Result application stores last timing in state',apply,'Set-BackgroundRefreshLastTiming')
    s.has('Result application preserves boot-state apply',apply,'Apply-FirmwareBootState')

    header=fn(tray,'Update-HeaderRefreshStatus'); visual=fn(tray,'Update-RefreshButtonVisual')
    s.has('Header reads explicit refresh state',header,'Test-BackgroundRefreshActive')
    s.has('Refresh button reads explicit refresh state',visual,'Test-BackgroundRefreshActive')
    s.has('Diagnostics reads last timing from state',tray,'lastBackgroundRefreshTiming = $script:BackgroundRefreshState.LastTiming')
    s.has('Shutdown takes refresh lifecycle context',tray,'$backgroundRefreshContext = Take-BackgroundRefreshCompletionContext')
    s.has('Shutdown clears pending request',tray,'Take-BackgroundRefreshPendingRequest -State $script:BackgroundRefreshState')

    # Worker still performs slow firmware/storage work out of process.
    workerfn=fn(tray,'Invoke-BackgroundRefreshWorker')
    s.has('Worker still checks broker readiness',workerfn,'Test-TaskBrokerReady -Force')
    s.has('Worker still refreshes manager',workerfn,'Get-TaskBrokerFirmwareManagerText -Force')
    s.has('Worker still refreshes firmware when requested',workerfn,'Get-TaskBrokerFirmwareEntriesText -Force')
    s.has('Worker still resolves storage when requested',workerfn,'Get-StorageContext')
    s.has('Popup-first contract retained',tray,'the form is visible before any fresh Scheduled-Task')

    # Native tests and encoding.
    native=txt(root/'tests/Test-RefreshRuntime.ps1'); wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('Native refresh test requires PS5.1',native,'#requires -version 5.1')
    s.has('Native refresh test expects 18 checks',native,'REFRESH TOTAL $checks/18')
    s.has('PS5.1 wrapper runs refresh test',wrapper,"tests\\Test-RefreshRuntime.ps1")
    bad=[]
    for p in sorted(root.rglob('*.ps1')):
        b=p.read_bytes(); payload=b[3:] if b.startswith(b'\xef\xbb\xbf') else b
        if any(x>=128 for x in payload) and not b.startswith(b'\xef\xbb\xbf'): bad.append(p.relative_to(root).as_posix())
    s.eq('All non-ASCII PowerShell sources have UTF-8 BOM',bad,[])

    # Unrelated security/runtime modules remain byte-identical to the native-green v0.4.2.2 basis.
    for rel,expected in BASELINE_SHA.items(): s.eq(f'Unrelated file byte-identical to v0.4.2.2: {rel}',sha_file(root/rel),expected)
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.has('Explicit BootNext broker retained',txt(root/'src/Infrastructure/TaskBroker.ps1'),'function Set-TaskBrokerBootNextTarget')
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Installer schema unchanged',txt(root/'Install-LenovoBootMenuTasks.ps1'),"$version = '0.2.12'")
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow','$form.ShowInTaskbar = $false']:
        s.has(f'Closed UI/startup contract retained: {x}',tray,x)

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist()
            s.eq('Release remains flat 10-file package',len(names),10)
            s.c('Release has no directories',all('/' not in n for n in names))
            s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()

if __name__=='__main__': raise SystemExit(main())
