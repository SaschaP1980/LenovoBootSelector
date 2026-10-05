#!/usr/bin/env python3
from pathlib import Path
import argparse, subprocess, sys, zipfile
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
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
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root.resolve(); s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); model=txt(root/'src/Core/BootTargetModel.ps1'); popup=txt(root/'src/UI/Popup.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.5.2',tray,"$script:AppVersion = '0.5.2'")
    s.eq('Version declaration exactly once',tray.count("$script:AppVersion = '0.5.2'"),1)
    s.c('README title v0.5.2',readme.startswith('# Lenovo Boot Selector v0.5.2'))

    # Pending vs failure presentation state.
    s.has('Pending USB subtitle present',model,'USB-Laufwerke werden geprüft …')
    s.has('True USB failure subtitle retained',model,'USB-Laufwerke konnten nicht geprüft werden')
    s.has('Missing StorageContext maps to pending',model,"if (-not $StorageContext) {")
    s.has('Unavailable resolution handled separately',model,"elseif ($StorageContext.UsbResolution -eq 'Unavailable')")
    s.no('Old conflated pending/failure condition removed',model,"if (-not $StorageContext -or $StorageContext.UsbResolution -eq 'Unavailable')")

    # Popup brand experiment.
    s.has('Header title uses Lenovo red accent',popup,"-ForeColor $script:ColorAccent -X 16 -Y 19")

    # Tray context menu wording/color.
    s.has('Tray open item renamed',template,"ToolStripMenuItem('Lenovo Boot Selector öffnen')")
    s.has('Tray open item uses Lenovo red accent',template,'$openItem.ForeColor = $script:ColorAccent')
    s.no('Old tray open item text removed',template,"ToolStripMenuItem('Boot Selector öffnen')")

    # Existing v0.5.1 USB semantics remain.
    for token in ['Wahrscheinlich: ',' erkannt · nicht als Startmedium erkannt','USB-Laufwerke erkannt · kein Startmedium gefunden','Mehrere mögliche USB-Startmedien erkannt','Kein USB-Laufwerk angeschlossen']:
        s.has(f'Existing USB semantics retained: {token}',model,token)
    s.has('USB firmware title remains stable',model,"$title = 'USB HDD'")

    # Safety scope.
    combined='\n'.join([template,model,popup])
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest','Register-WmiEvent']:
        s.no(f'No forbidden/new mechanism: {bad}',combined,bad)
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Runtime builder check succeeds',cp.returncode,0)
    if a.release_zip:
        s.c('Release ZIP exists',a.release_zip.is_file())
        if a.release_zip.is_file():
            with zipfile.ZipFile(a.release_zip) as z:
                s.c('Release ZIP integrity',z.testzip() is None)
                r=z.read('LenovoBootMenuTray.ps1').decode('utf-8-sig')
                s.has('Packaged runtime version 0.5.2',r,"$script:AppVersion = '0.5.2'")
                s.has('Packaged pending state',r,'USB-Laufwerke werden geprüft …')
                s.has('Packaged tray open text',r,"ToolStripMenuItem('Lenovo Boot Selector öffnen')")
    return s.done()
if __name__=='__main__': raise SystemExit(main())
