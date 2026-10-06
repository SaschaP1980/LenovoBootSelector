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
    tray=txt(root/'LenovoBootMenuTray.ps1'); model=txt(root/'src/Core/BootTargetModel.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md'); native=txt(root/'tests/Test-FunctionalCore.ps1')
    s.has('App version 0.5.4',tray,"$script:AppVersion = '0.5.4'")
    s.eq('Version declaration exactly once',tray.count("$script:AppVersion = '0.5.4'"),1)
    s.c('README title v0.5.4',readme.startswith('# Lenovo Boot Selector v0.5.4'))
    s.has('USB single boot candidate uses start-medium wording',model,"$subtitle = 'USB-Startmedium: ' + [string]$candidate.Model")
    s.no('Old probability wording removed from current model',model,"$subtitle = 'Wahrscheinlich: ' + [string]$candidate.Model")
    s.has('Native test expects new USB text',native,"Assert-Equal 'USB-Startmedium: USB Test Disk' $usb.Subtitle")
    s.no('Native test no longer expects old USB text',native,"Assert-Equal 'Wahrscheinlich: USB Test Disk' $usb.Subtitle")
    # Preserve all other v0.5.3 semantics.
    for token in [
        "USB-Laufwerke werden geprüft …","USB-Laufwerke konnten nicht geprüft werden",
        " erkannt · nicht als Startmedium erkannt","USB-Laufwerke erkannt · kein Startmedium gefunden",
        "Mehrere mögliche USB-Startmedien erkannt","Kein USB-Laufwerk angeschlossen",
        "Interne SSD: ","Kein Laufwerk erkannt"
    ]: s.has(f'Existing presentation token retained: {token}',model,token)
    s.has('USB firmware target title retained',model,"$title = 'USB HDD'")
    s.has('NVMe read-only inventory retained',model,"[string]$_.BusType -eq 'NVMe'")
    for bad in ['SetFirmwareEnvironmentVariable','Lenovo_SetBiosSetting','Lenovo_SaveBiosSetting','Lenovo_SetFunctionRequest']:
        s.no(f'No new firmware/WMI write token: {bad}',tray,bad)
    s.no('No permanent displayorder mutation',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Settings schema unchanged',tray,'schemaVersion = 4')
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True); s.eq('Runtime deterministic',cp.returncode,0)
    if a.release_zip:
        with zipfile.ZipFile(a.release_zip) as z:
            names=z.namelist(); s.eq('Release remains flat 10-file package',len(names),10); s.c('Release has no directories',all('/' not in n for n in names)); s.has('Packaged runtime version 0.5.4',z.read('LenovoBootMenuTray.ps1').decode('utf-8-sig'),"$script:AppVersion = '0.5.4'")
    return s.done()
if __name__=='__main__': raise SystemExit(main())
