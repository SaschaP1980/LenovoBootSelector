#!/usr/bin/env python3
from pathlib import Path
import argparse, json, subprocess, sys, zipfile

ROOT_DEFAULT = Path(__file__).resolve().parents[1]

class S:
    def __init__(self): self.rows=[]
    def c(self,n,v,d=''): self.rows.append((n,bool(v),d))
    def has(self,n,t,x): self.c(n, bool(t) and x in t)
    def no(self,n,t,x): self.c(n, (not t) or x not in t)
    def eq(self,n,a,b): self.c(n,a==b,f'{a!r}!={b!r}' if a!=b else '')
    def done(self):
        for n,o,d in self.rows: print(('PASS  ' if o else 'FAIL  ')+n+(f' [{d}]' if d and not o else ''))
        p=sum(o for _,o,_ in self.rows); print(f'\nTOTAL {p}/{len(self.rows)}'); return 0 if p==len(self.rows) else 1

def txt(p):
    p=Path(p)
    return p.read_text(encoding='utf-8-sig') if p.is_file() else ''

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',type=Path,default=ROOT_DEFAULT)
    ap.add_argument('--release-zip',type=Path)
    a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1')
    template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    core=txt(root/'src/Core/UpdateModel.ps1')
    app=txt(root/'src/Application/UpdateRuntime.ps1')
    infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    ui=txt(root/'src/UI/UpdatePresentation.ps1')
    wrapper=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    native=txt(root/'tests/Test-UpdateCore.ps1')

    s.has('App version 0.5.6',tray,"$script:AppVersion = '0.5.6'")
    s.eq('Version declaration exactly once',tray.count("$script:AppVersion = '0.5.6'"),1)
    for rel in ['src/Core/UpdateModel.ps1','src/Application/UpdateRuntime.ps1','src/Infrastructure/UpdateClient.ps1','src/UI/UpdatePresentation.ps1']:
        s.c(f'Updater module exists: {rel}',(root/rel).is_file())
        s.eq(f'Updater include marker once: {rel}',template.count(f'# @include {rel}'),1)
        s.no(f'Updater include resolved in runtime: {rel}',tray,f'# @include {rel}')

    s.has('Exact menu label: check',template,"ToolStripMenuItem('Auf neue Version prüfen…')")
    s.has('Exact menu label: update',template,"ToolStripMenuItem('App aktualisieren…')")
    s.has('Exact menu label: diagnostic',template,"ToolStripMenuItem('Diagnose speichern…')")
    mstart=template.find("$maintenanceRoot = New-Object System.Windows.Forms.ToolStripMenuItem('Wartung')")
    mend=template.find('[void]$context.Items.Add($maintenanceRoot)',mstart)
    mblock=template[mstart:mend] if mstart>=0 and mend>mstart else ''
    s.c('Maintenance themed order: system -> updates -> diagnostic',0 <= mblock.find('[void]$maintenanceRoot.DropDownItems.Add($removeTasksItem)') < mblock.find('[void]$maintenanceRoot.DropDownItems.Add($updateCheckItem)') < mblock.find('[void]$maintenanceRoot.DropDownItems.Add($updateInstallItem)') < mblock.find('[void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)'))
    s.eq('Maintenance has exactly two thematic separators',mblock.count('DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))'),2)
    s.c('Diagnostic final maintenance item',mblock.rstrip().endswith('[void]$maintenanceRoot.DropDownItems.Add($diagnosticItem)'))
    s.has('Update action initially disabled',template,'$updateInstallItem.Enabled = $false')
    s.has('Check action is explicit click only',template,'$updateCheckItem.Add_Click({ Start-ManualUpdateCheck })')
    s.has('Update action explicit click',template,'$updateInstallItem.Add_Click({ Start-ManualAppUpdate })')

    s.has('Fixed GitHub latest manifest URL',infra,'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/latest.json')
    s.has('Fixed GitHub download base',infra,'https://raw.githubusercontent.com/SaschaP1980/LenovoBootSelector/main/downloads/')
    s.no('No arbitrary manifest downloadUrl trust',infra,'.downloadUrl')
    s.has('TLS 1.2 enabled for GitHub request',infra,'Tls12')
    s.has('SHA-256 verification exists',infra,'SHA256')
    s.has('Hash mismatch is fatal',infra,'SHA-256 stimmt nicht')
    s.has('ZIP traversal validation exists',infra,"Contains('..')")
    s.has('Flat package validation exists',infra,"Contains('/')")
    s.has('Package file list validated',infra,'packageFiles')
    s.has('Staged runtime version validated',infra,"$script:AppVersion = '")
    s.no('Updater never requests elevation',infra,'Verb = \'RunAs\'')
    s.no('Updater never invokes bcdedit',infra,'bcdedit')
    s.no('Updater never invokes ScheduledTask',infra,'ScheduledTask')

    s.has('Semantic version comparison core',core,'Compare-LenovoAppVersionCore')
    s.has('Manifest validation core',core,'Test-LenovoUpdateManifestCore')
    s.has('Manifest schema 1 required',core,'schemaVersion')
    s.has('Manifest SHA format validated',core,'^[0-9a-fA-F]{64}$')
    s.has('Manifest file name bound to version',core,'LenovoBootMenuTray-v{0}.zip')
    s.has('Manifest package file names validated',core,'PackageFiles')

    s.has('Update state starts idle',app,"Status = 'Idle'")
    s.has('Update state remembers manifest',app,'AvailableManifest')
    s.has('Checking state exists',app,"'Checking'")
    s.has('Preparing state exists',app,"'Preparing'")
    s.has('ReadyToInstall state exists',app,"'ReadyToInstall'")

    s.has('Manual check starts hidden child worker',ui,'Start-UpdateCheckWorkerProcess')
    s.has('Manual install starts hidden prepare worker',ui,'Start-UpdatePrepareWorkerProcess')
    s.has('No automatic startup update call marker',ui,'Manual update check only')
    s.has('Update menu enablement driven by newer manifest',ui,'AvailableManifest')
    s.has('Update error shown in app UI',ui,'Update fehlgeschlagen')
    s.has('Update current result shown in app UI',ui,'ist aktuell')

    s.has('Helper waits for tray process exit',infra,'WaitForExit')
    s.has('Helper creates backup',infra,'backup')
    s.has('Helper rollback path exists',infra,'ROLLBACK')
    s.has('Helper restarts through VBS launcher',infra,'Start-LenovoBootMenuTray.vbs')
    s.has('Helper remains unelevated',infra,'UseShellExecute = $false')

    s.has('Update check child parameter',template,'[switch]$UpdateCheck')
    s.has('Update prepare child parameter',template,'[switch]$UpdatePrepare')
    s.has('Update result path parameter',template,'[string]$UpdateResultPath')
    s.has('Update manifest path parameter',template,'[string]$UpdateManifestPath')
    s.has('Update workers bypass singleton mutex',template,'-not $UpdateCheck -and -not $UpdatePrepare')
    s.has('Update check worker exits before tray UI',template,'Invoke-UpdateCheckWorker')
    s.has('Update prepare worker exits before tray UI',template,'Invoke-UpdatePrepareWorker')

    s.c('Native update core test exists',(root/'tests/Test-UpdateCore.ps1').is_file())
    s.has('PS5.1 wrapper runs update test',wrapper,'Test-UpdateCore.ps1')
    s.has('Native update test has explicit total',native,'UPDATE TOTAL')

    s.c('latest.json exists',(root/'downloads/latest.json').is_file())
    if (root/'downloads/latest.json').is_file():
        try:
            data=json.loads((root/'downloads/latest.json').read_text(encoding='utf-8'))
            s.eq('latest manifest version',data.get('version'),'0.5.6')
            s.eq('latest manifest schema',data.get('schemaVersion'),1)
        except Exception as e: s.c('latest manifest parses',False,str(e))
    else:
        s.c('latest manifest version',False)
        s.c('latest manifest schema',False)

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Runtime deterministic',cp.returncode,0)

    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist()
            s.eq('Release remains flat 10-file package',len(names),10)
            s.c('Release has no directories',all('/' not in n for n in names))
            s.has('Packaged runtime version 0.5.6',z.read('LenovoBootMenuTray.ps1').decode('utf-8-sig'),"$script:AppVersion = '0.5.6'")
    return s.done()

if __name__=='__main__': raise SystemExit(main())
