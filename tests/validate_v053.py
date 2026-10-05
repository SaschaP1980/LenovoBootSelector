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
    tray=txt(root/'LenovoBootMenuTray.ps1'); model=txt(root/'src/Core/BootTargetModel.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    s.has('App version 0.5.3',tray,"$script:AppVersion = '0.5.3'")
    s.eq('Version declaration exactly once',tray.count("$script:AppVersion = '0.5.3'"),1)
    s.c('README title v0.5.3',readme.startswith('# Lenovo Boot Selector v0.5.3'))

    # NVMe presentation for the confirmed single-NVMe target configuration.
    s.has('NVMe inventory is derived from read-only storage context',model,"$nvmeDisks = @($StorageContext.Disks | Where-Object { [string]$_.BusType -eq 'NVMe' })")
    s.has('NVMe0 model prefix',model,"$subtitle = 'Interne SSD: ' + [string]$nvmeDisks[0].Model")
    s.has('NVMe1 empty-slot text',model,"$subtitle = 'Kein Laufwerk erkannt'")
    s.has('NVMe0 single-device condition',model,"if ($StorageContext -and $nvmeDisks.Count -eq 1)")
    s.has('NVMe1 single-device condition',model,"if ($StorageContext -and $nvmeDisks.Count -eq 1)")
    s.has('NVMe ambiguity comment retained',model,'Do not guess NVMe0/NVMe1 physical mapping when multiple NVMe disks are present.')

    # Existing v0.5.2 changes remain.
    for token in ['USB-Laufwerke werden geprüft …','USB-Laufwerke konnten nicht geprüft werden','Wahrscheinlich: ',' erkannt · nicht als Startmedium erkannt','Kein USB-Laufwerk angeschlossen']:
        s.has(f'Existing USB semantics retained: {token}',model,token)
    s.has('Header Lenovo-red experiment retained',txt(root/'src/UI/Popup.ps1'),'-ForeColor $script:ColorAccent -X 16 -Y 19')
    s.has('Tray open wording retained',template,"ToolStripMenuItem('Lenovo Boot Selector öffnen')")
    s.has('Tray open Lenovo-red retained',template,'$openItem.ForeColor = $script:ColorAccent')

    combined='\n'.join([template,model])
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
                s.has('Packaged runtime version 0.5.3',r,"$script:AppVersion = '0.5.3'")
                s.has('Packaged NVMe0 model subtitle',r,"$subtitle = 'Interne SSD: ' + [string]$nvmeDisks[0].Model")
                s.has('Packaged NVMe1 empty slot subtitle',r,"$subtitle = 'Kein Laufwerk erkannt'")
    return s.done()
if __name__=='__main__': raise SystemExit(main())
