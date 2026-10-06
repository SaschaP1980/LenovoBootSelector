#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, zipfile
ROOT_DEFAULT=Path(__file__).resolve().parents[1]
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
def psfn(t,n):
    m=re.search(rf'(?m)^function\s+{re.escape(n)}\b',t)
    if not m:return ''
    q=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',t[m.end():]); e=m.end()+q.start() if q else len(t)
    return t[m.start():e]
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); ap.add_argument('--release-zip',type=Path); a=ap.parse_args(); root=a.root; s=S()
    tray=txt(root/'LenovoBootMenuTray.ps1'); template=txt(root/'src/App/LenovoBootMenuTray.template.ps1'); readme=txt(root/'README.md')
    fatal=psfn(tray,'Show-FatalMessage'); restart=psfn(tray,'Start-LenovoBootSelectorHidden')
    s.has('App version 0.4.2.1',tray,"$script:AppVersion = '0.4.2.1'")
    s.eq('Version declaration once',tray.count("$script:AppVersion = '0.4.2.1'"),1)
    s.c('README title v0.4.2.1',readme.startswith('# Lenovo Boot Selector v0.4.2.1'))
    s.has('README documents startup dialog patch',readme,'eigener Startfehlerdialog')
    s.has('Custom fatal dialog creates WinForms Form',fatal,'New-Object System.Windows.Forms.Form')
    s.has('Fatal dialog hidden from taskbar',fatal,'$form.ShowInTaskbar = $false')
    s.has('Fatal dialog Lenovo accent',fatal,'FromArgb(225, 37, 27)')
    for x in ['Erneut starten','Diagnose öffnen','Schließen']:
        s.has(f'Fatal dialog action: {x}',fatal,x)
    s.has('Fatal dialog uses app icon',fatal,"Join-Path $PSScriptRoot 'LenovoBootMenuTray.ico'")
    s.has('Fatal dialog opens diagnostics with Explorer',fatal,"Start-Process -FilePath 'explorer.exe'")
    s.has('Already-running path disables restart',tray,"Show-FatalMessage 'Lenovo Boot Selector läuft bereits.' -AllowRestart $false")
    s.has('Fatal catch records retry request',tray,"$script:RestartAfterFatal = ((Show-FatalMessage $_.Exception.Message) -eq 'retry')")
    mutex=tray.find('try { $mutex.ReleaseMutex() }'); relaunch=tray.find('[void](Start-LenovoBootSelectorHidden)',mutex)
    s.c('Fatal restart happens only after mutex release',mutex>=0 and relaunch>mutex)
    s.has('Hidden relaunch uses fixed VBS launcher',restart,"Join-Path $PSScriptRoot 'Start-LenovoBootMenuTray.vbs'")
    s.has('Hidden relaunch uses wscript',restart,"System32\\wscript.exe")
    s.has('Hidden relaunch disables shell execute',restart,'$psi.UseShellExecute = $false')
    s.has('Hidden relaunch requests no window',restart,'$psi.CreateNoWindow = $true')
    # Any fallback native MessageBox must be owner-bound; old unowned signature is forbidden.
    s.has('Fallback uses invisible owner',fatal,'$owner.ShowInTaskbar = $false')
    s.has('Fallback MessageBox is owner-bound',fatal,'[System.Windows.Forms.MessageBox]::Show(\n                $owner,')
    s.no('Old unowned fatal MessageBox text removed',fatal,"[System.Windows.Forms.MessageBox]::Show(\n            $text,")
    # Encoding policy for Windows PowerShell 5.1: any non-ASCII .ps1 must have UTF-8 BOM.
    psfiles=sorted(root.rglob('*.ps1')); bad=[]
    for p in psfiles:
        b=p.read_bytes(); payload=b[3:] if b.startswith(b'\xef\xbb\xbf') else b
        if any(x>=128 for x in payload) and not b.startswith(b'\xef\xbb\xbf'): bad.append(p.relative_to(root).as_posix())
    s.eq('All non-ASCII PowerShell sources have UTF-8 BOM',bad,[])
    win=txt(root/'tests/Test-WindowsPowerShell51.ps1')
    s.has('Native gate checks UTF-8 BOM',win,'non-ASCII PowerShell source requires UTF-8 BOM')
    s.has('Native gate still parses every PS1',win,'Parser]::ParseFile')
    s.has('Native gate still runs Functional Core',win,"tests\\Test-FunctionalCore.ps1")
    s.has('Friendly model source preserves Menü',txt(root/'src/Core/BootTargetModel.ps1'),'Lenovo Boot-Menü')
    # Security invariants / architecture refactor remain intact.
    infra=txt(root/'src/Infrastructure/TaskBroker.ps1'); app=txt(root/'src/Application/BootService.ps1'); install=txt(root/'Install-LenovoBootMenuTasks.ps1')
    s.no('No Invoke-BcdEdit regression',tray,'Invoke-BcdEdit')
    s.has('Fixed BootNext broker operation retained',infra,'function Set-TaskBrokerBootNextTarget')
    s.has('BootNext resolves GUID from metadata',infra,'Get-TaskBrokerTarget -Guid $normalized')
    s.no('Application cannot start scheduled tasks directly',app,'Start-ScheduledTask')
    s.no('No permanent displayorder mutation in tray',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.has('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.has('Installer schema unchanged',install,"$version = '0.2.12'")
    s.has('Popup-first rationale retained',tray,'the form is visible before any fresh Scheduled-Task')
    # Frozen UI renderer/tooltips remain exactly present.
    for x in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern','protected override void OnRenderSeparator','public static ToolStripItem HitTestRow']:
        s.has(f'Closed UI regression contract retained: {x}',tray,x)
    cp=subprocess.run([sys.executable,str(root/'tools/build_runtime.py'),'--root',str(root),'--check'],capture_output=True,text=True)
    s.eq('Deterministic runtime check',cp.returncode,0)
    if a.release_zip:
        z=zipfile.ZipFile(a.release_zip); names=z.namelist()
        s.eq('Release remains flat 10-file package',len(names),10)
        s.c('Release has no directories',all('/' not in n for n in names))
        s.eq('Packaged runtime equals source runtime',z.read('LenovoBootMenuTray.ps1'),(root/'LenovoBootMenuTray.ps1').read_bytes())
    return s.done()
if __name__=='__main__': raise SystemExit(main())
