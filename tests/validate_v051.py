#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, re, subprocess, sys, zipfile

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
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); model=txt(root/'src/Core/BootTargetModel.ps1')
    maint=txt(root/'src/UI/MaintenancePresentation.ps1'); dialogs=txt(root/'src/UI/Dialogs.ps1'); popup=txt(root/'src/UI/Popup.ps1'); readme=txt(root/'README.md')

    s.has('App version 0.5.1',tray,"$script:AppVersion = '0.5.1'")
    s.eq('Version declaration exactly once',tray.count("$script:AppVersion = '0.5.1'"),1)
    s.c('README title v0.5.1',readme.startswith('# Lenovo Boot Selector v0.5.1'))

    # USB HDD remains the actual firmware target; physical media are only status text.
    s.has('USB HDD branch preserves firmware title',model,"$title = 'USB HDD'")
    for forbidden in ["$title = [string]$resolved.Model","$title = 'USB-Bootlaufwerk'","$title = 'USB-Laufwerk'"]:
        s.no(f'USB model no longer replaces firmware title: {forbidden}',model,forbidden)
    for token in [
        'Wahrscheinlich: ',
        ' erkannt · nicht als Startmedium erkannt',
        'USB-Laufwerke erkannt · kein Startmedium gefunden',
        'Mehrere mögliche USB-Startmedien erkannt',
        'Kein USB-Laufwerk angeschlossen',
        'USB-Laufwerke konnten nicht geprüft werden',
    ]:
        s.has(f'USB state text present: {token}',model,token)
    for old in ['Wahrscheinlich das USB-Startziel','Angeschlossenes USB-Laufwerk','Mehrere USB-Startlaufwerke gefunden','Mehrere USB-Laufwerke gefunden','Start von einem USB-Speicherlaufwerk']:
        s.no(f'Old ambiguous USB text removed: {old}',model,old)

    # Firmware drift terminology must not claim a physical device.
    for source_name,source in [('maintenance',maint),('dialogs',dialogs),('popup',popup)]:
        s.no(f'{source_name}: no Neues Gerät erkannt',source,'Neues Gerät erkannt')
    s.has('Maintenance uses Neues Startziel erkannt',maint,'Neues Startziel erkannt')
    s.has('Dialogs use Neues Startziel erkannt',dialogs,'Neues Startziel erkannt')
    s.has('Popup uses Neues Startziel erkannt',popup,'Neues Startziel erkannt')

    # Safety and scope gates.
    combined='\n'.join([template,model,maint,dialogs,popup])
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest']:
        s.no(f'No new firmware/Lenovo write API: {bad}',combined,bad)
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.eq('No new Storage event handler token',combined.count('Register-WmiEvent'),0)

    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Runtime builder check succeeds',cp.returncode,0)

    if a.release_zip:
        s.c('Release ZIP exists',a.release_zip.is_file())
        if a.release_zip.is_file():
            with zipfile.ZipFile(a.release_zip) as z:
                names=z.namelist(); s.c('Release ZIP integrity',z.testzip() is None)
                s.c('Release contains flat runtime', 'LenovoBootMenuTray.ps1' in names and all('/' not in n for n in names))
                r=z.read('LenovoBootMenuTray.ps1').decode('utf-8-sig')
                s.has('Packaged runtime version 0.5.1',r,"$script:AppVersion = '0.5.1'")
    return s.done()

if __name__=='__main__': raise SystemExit(main())
