#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, sys, zipfile

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
RELEASE_NAMES = [
    'BUILD_INTEGRITY.txt','icon-preview.png','Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico',
    'LenovoBootMenuTray.ps1','README.md','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs',
    'Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1'
]

class Suite:
    def __init__(self): self.rows=[]
    def check(self,name,cond,detail=''):
        self.rows.append((name,bool(cond),detail))
    def contains(self,name,text,needle): self.check(name,needle in text)
    def absent(self,name,text,needle): self.check(name,needle not in text)
    def eq(self,name,a,b): self.check(name,a==b,f'{a!r} != {b!r}' if a!=b else '')
    def finish(self):
        for name,ok,detail in self.rows:
            print(('PASS  ' if ok else 'FAIL  ')+name+(f' [{detail}]' if detail and not ok else ''))
        passed=sum(ok for _,ok,_ in self.rows); total=len(self.rows)
        print(f'\nTOTAL {passed}/{total}')
        return 0 if passed==total else 1

def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return sha_bytes(Path(p).read_bytes())
def text(p): return Path(p).read_text(encoding='utf-8-sig')

def ps_function(source,name):
    m=re.search(rf'(?m)^function\s+{re.escape(name)}\b',source)
    if not m: return None
    n=re.search(r'(?m)^function\s+[A-Za-z0-9_-]+\b',source[m.end():])
    end=m.end()+n.start() if n else len(source)
    return source[m.start():end].rstrip()+"\n"

def balanced_fragment(source,marker):
    try: start=source.index(marker); brace=source.index('{',start)
    except ValueError: return None
    depth=0; i=brace; sq=dq=False; esc=False
    while i<len(source):
        c=source[i]
        if esc: esc=False
        elif c=='`': esc=True
        elif sq:
            if c=="'": sq=False
        elif dq:
            if c=='"': dq=False
        else:
            if c=="'": sq=True
            elif c=='"': dq=True
            elif c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0: return source[start:i+1]+"\n"
        i+=1
    return None

def lexical_balance(source):
    # Strip comments/strings/here-strings conservatively and count delimiters.
    out=[]; i=0; state='code'
    while i<len(source):
        if state=='here_dq':
            if (i==0 or source[i-1]=='\n') and source.startswith('"@',i): state='code'; i+=2; continue
            i+=1; continue
        if state=='here_sq':
            if (i==0 or source[i-1]=='\n') and source.startswith("'@",i): state='code'; i+=2; continue
            i+=1; continue
        c=source[i]
        if state=='comment':
            if c=='\n': state='code'; out.append('\n')
            i+=1; continue
        if state=='sq':
            if c=="'":
                if i+1<len(source) and source[i+1]=="'": i+=2; continue
                state='code'
            i+=1; continue
        if state=='dq':
            if c=='`': i+=2; continue
            if c=='"': state='code'
            i+=1; continue
        if source.startswith('@"',i): state='here_dq'; i+=2; continue
        if source.startswith("@'",i): state='here_sq'; i+=2; continue
        if c=='#': state='comment'; i+=1; continue
        if c=="'": state='sq'; i+=1; continue
        if c=='"': state='dq'; i+=1; continue
        out.append(c); i+=1
    cleaned=''.join(out)
    return {x:(cleaned.count(x),cleaned.count(y)) for x,y in [('{','}'),('(',')'),('[',']')]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',type=Path,default=ROOT_DEFAULT)
    ap.add_argument('--release-zip',type=Path)
    args=ap.parse_args(); root=args.root
    s=Suite()
    tray_b=(root/'LenovoBootMenuTray.ps1').read_bytes(); tray=text(root/'LenovoBootMenuTray.ps1')
    install=text(root/'Install-LenovoBootMenuTasks.ps1'); uninstall=text(root/'Uninstall-LenovoBootMenuTasks.ps1'); readme=text(root/'README.md')
    baseline=json.loads((root/'tests/characterization-baseline-v0.3.4.json').read_text(encoding='utf-8'))
    arch=json.loads((root/'ARCHITECTURE_BASELINE_v0.4.0.json').read_text(encoding='utf-8'))

    # Version / immutability baseline
    s.contains('App version is 0.4.0',tray,"$script:AppVersion = '0.4.0'")
    s.eq('App version declaration exactly once',tray.count("$script:AppVersion = '0.4.0'"),1)
    s.check('README title is v0.4.0',readme.startswith('# Lenovo Boot Selector v0.4.0'))
    s.contains('README v0.4.0 safety baseline section',readme,'## Neu in v0.4.0 – Refactoring Safety Baseline')
    s.contains('README states no functional/refactoring build',readme,'kein Funktions- oder Refactoring-Build')
    normalized=tray_b.replace(b"$script:AppVersion = '0.4.0'",b"$script:AppVersion = '0.3.4'")
    s.eq('Tray normalized to v0.3.4 is byte-identical by SHA-256',sha_bytes(normalized),baseline['source_sha256']['LenovoBootMenuTray.ps1'])
    for fn in ['Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','Uninstall-LenovoBootMenuTasks.ps1','icon-preview.png']:
        s.eq(f'{fn} byte-identical to v0.3.4',sha_file(root/fn),baseline['source_sha256'][fn])

    # Architecture baseline
    metrics=arch['metrics']
    s.eq('Architecture baseline tray lines',len(tray.splitlines()),metrics['tray_lines'])
    s.eq('Architecture baseline function count',len(re.findall(r'(?m)^function\s+[A-Za-z0-9_-]+\b',tray)),metrics['function_count'])
    vars_=set(x.lower() for x in re.findall(r'\$script:([A-Za-z_][A-Za-z0-9_]*)',tray,re.I))
    s.eq('Architecture baseline distinct script state',len(vars_),metrics['script_state_distinct'])
    s.eq('Architecture baseline script-state references',len(re.findall(r'\$script:[A-Za-z_][A-Za-z0-9_]*',tray,re.I)),metrics['script_state_references'])
    s.eq('Architecture baseline catch blocks',len(re.findall(r'\bcatch\s*\{',tray)),metrics['catch_blocks'])
    s.eq('Architecture baseline empty catch blocks',len(re.findall(r'catch\s*\{\s*\}',tray)),metrics['empty_catch_blocks'])
    for item in metrics['largest_functions'][:5]:
        s.check(f'Architecture hotspot retained: {item["name"]}',ps_function(tray,item['name']) is not None)

    # Critical frozen fragments from native-confirmed v0.3.4
    for key,expected in baseline['critical_fragment_sha256'].items():
        kind,name=key.split(':',1)
        frag=ps_function(tray,name) if kind=='ps' else balanced_fragment(tray,name)
        s.check(f'Critical fragment present: {name}',frag is not None)
        if frag is not None: s.eq(f'Critical fragment unchanged: {name}',sha_bytes(frag.encode('utf-8')),expected)

    # Security / privilege boundary
    s.contains('PowerShell 5.1 requirement retained',tray,'#requires -version 5.1')
    s.contains('TaskBroker schema remains 0.2.12',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.contains('Installer TaskBroker schema remains 0.2.12',install,"$version = '0.2.12'")
    for needle in ['schemaVersion = 4;','schemaVersion = 4\n']:
        pass
    s.check('Settings schema remains 4',tray.count('schemaVersion = 4')>=2)
    s.contains('Restart remains shutdown /r /t 0',tray,"$psi.Arguments = '/r /t 0'")
    s.contains('Tray compatibility wrapper explicitly forbids direct BCDEdit',tray,'the unelevated tray never launches BCDEdit directly')
    s.contains('Unsupported privileged BCDEdit operations fail closed',tray,'Nicht unterstützte privilegierte BCDEdit-Operation')
    s.contains('BootNext mutation only targets fwbootmgr bootsequence',tray,"$Arguments[1] -eq '{fwbootmgr}' -and $Arguments[2] -eq 'bootsequence'")
    s.absent('Tray has no permanent fwbootmgr displayorder set',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.absent('Installer has no permanent displayorder mutation',install,"/set '{{fwbootmgr}}' displayorder")
    s.absent('Installer has no displayorder delete mutation',install,"/deletevalue '{{fwbootmgr}}' displayorder")
    s.contains('Installer boot task hardcodes fwbootmgr bootsequence',install,"'/set \"{{fwbootmgr}}\" bootsequence \"{0}\"'")
    s.contains('Installer uses fixed per-target task prefix',install,"$taskPrefix = 'LenovoBootMenu-Set-'")
    s.contains('Installer uses fixed default target task prefix',install,"$defaultTaskPrefix = 'LenovoBootMenu-Default-Set-'")
    s.contains('Installer fixed manager refresh task',install,"$managerRefreshTask = 'LenovoBootMenu-RefreshManager'")
    s.contains('Installer fixed firmware refresh task',install,"$firmwareRefreshTask = 'LenovoBootMenu-RefreshFirmware'")
    s.contains('Installer fixed default clear task',install,"$defaultClearTask = 'LenovoBootMenu-Default-Clear'")
    s.contains('Installer fixed default restore task',install,"$defaultRestoreTask = 'LenovoBootMenu-Default-Restore'")
    s.contains('Default restore remains AtStartup',install,'New-ScheduledTaskTrigger -AtStartup')
    s.contains('Default restore 30-second delay intentionally retained',install,"$startupTrigger.Delay = 'PT30S'")
    s.contains('Restore script checks hardcoded allowed GUID list',install,'if (`$allowed -notcontains `$guid) { exit 0 }')
    s.contains('Restore mutates only fwbootmgr bootsequence',install,"/set '{fwbootmgr}' bootsequence `$guid")
    s.contains('Task ACL grants users read/execute only',install,'[System.Security.AccessControl.FileSystemRights]::ReadAndExecute')
    s.contains('Task DACL verifies Read+Execute',install,'Test-SddlReadExecuteAce')
    s.contains('Task principal remains SYSTEM',install,"-UserId 'SYSTEM'")
    s.contains('Task principal highest runlevel retained',install,'-RunLevel Highest')
    s.absent('No custom SYSTEM executable path introduced',install,'LenovoBootMenuBroker.exe')
    s.eq('Tray elevation prompts restricted to setup/remove',tray.count('-Verb RunAs'),2)
    s.contains('Exact-task COM access retained',tray,"$taskFolder.GetTask(\"\\$TaskName\")")
    s.contains('Root task enumeration deliberately avoided',tray,'root enumeration is deliberately avoided')
    s.contains('Authorized task uses Start-ScheduledTask by exact name',tray,'Start-ScheduledTask -TaskName $TaskName')
    s.contains('BootNext readback verifies desired GUID',tray,'Das gewünschte BootNext-Ziel wurde nach dem Schreiben nicht als bootsequence zurückgelesen')
    s.contains('Cleanup exact task allowlist exists',uninstall,'$exactTaskNames = @(')
    s.contains('Cleanup owned prefix allowlist exists',uninstall,'$ownedPrefixes = @(')
    s.contains('Cleanup Set prefix exact',uninstall,"'LenovoBootMenu-Set-'")
    s.contains('Cleanup Default-Set prefix exact',uninstall,"'LenovoBootMenu-Default-Set-'")
    s.absent('Cleanup has no broad Lenovo wildcard',uninstall,"-like 'Lenovo*'")
    s.contains('Cleanup only removes matching enumerated task names',uninstall,'Unregister-ScheduledTask -TaskName $name')
    s.contains('Cleanup ProgramData state root is project-specific',uninstall,"'Lenovo Boot Menu\\TaskBroker'")

    # UI regression contracts
    s.contains('ToolStrip background selection path retained',tray,'protected override void OnRenderToolStripBackground')
    s.contains('Background resolves visual hot item',tray,'LenovoMenuLayout.GetVisualHotItem(dropDown)')
    s.contains('Background uses full ClientRectangle left',tray,'dropDown.ClientRectangle.Left + inset')
    s.contains('Background uses full ClientRectangle right',tray,'dropDown.ClientRectangle.Right - inset')
    s.contains('Background uses hot item top',tray,'hotItem.Bounds.Top')
    s.contains('Background uses hot item bottom',tray,'hotItem.Bounds.Bottom')
    s.contains('Background fills active row rectangle',tray,'e.Graphics.FillRectangle(selectionBrush, new Rectangle(left, top, right - left, bottom - top));')
    itemfrag=balanced_fragment(tray,'protected override void OnRenderMenuItemBackground') or ''
    s.absent('Item renderer does not fill selection background',itemfrag,'FillRectangle')
    s.contains('Visual hot resolver uses mouse position',tray,'menu.PointToClient(Control.MousePosition)')
    s.contains('Visual hot resolver uses row hit-test',tray,'HitTestRow(menu, point)')
    s.contains('Visual hot resolver keyboard fallback',tray,'menuItem.Pressed || menuItem.Selected')
    s.absent('Legacy PaintSelectionTail remains removed',tray,'PaintSelectionTail')
    s.absent('Legacy QueueFullInvalidate remains removed',tray,'QueueFullInvalidate')
    layout=(tray[tray.index('public static class LenovoMenuLayout'):tray.index('public sealed class LenovoContextMenuStrip')] if 'public sealed class LenovoContextMenuStrip' in tray else tray)
    s.absent('No delayed BeginInvoke in LenovoMenuLayout',layout,'BeginInvoke')
    s.contains('Separator local Y retained',tray,'e.Item.Height / 2')
    s.contains('Owner-drawn tooltip retained',tray,'$tip.OwnerDraw = $true')
    s.absent('Separate LenovoDarkToolTipForm remains removed',tray,'LenovoDarkToolTipForm')
    for label in ['Sichtbar – klicken zum Ausblenden','Verborgen – klicken zum Einblenden','Anzeigename ändern']:
        s.contains(f'Action tooltip retained: {label}',tray,label)
    s.contains('Diagnostic dialog retains Im Ordner anzeigen',tray,"-SecondaryButtonText 'Im Ordner anzeigen'")
    s.contains('Explorer reveal selects exact ZIP',tray,"$psi.Arguments = ('/select,\"{0}\"' -f $safePath)")
    for ui in ['Lenovo Boot Selector','EINSTELLUNGEN','STARTZIELE ANPASSEN','Auswahlmenü für das nächste Startziel','Startziele aktualisieren','Systemfunktionen reparieren…','Systemfunktionen entfernen…','Diagnose speichern…']:
        s.contains(f'UI text retained: {ui}',tray,ui)

    # Diagnostics contracts
    for evt in ['TRAY_STARTUP','SESSION_ENDED','BOOTNEXT_SET','DEFAULT_TARGET_CHANGE','TASKBROKER_READY_CHECK','AUTHORIZED_TASK','MANAGER_REFRESH','FIRMWARE_REFRESH','STORAGE_RESOLUTION','AUTOSTART_CHANGE','BACKGROUND_REFRESH_STARTED','BACKGROUND_REFRESH_COMPLETED','RESTART_REQUEST','UI_THREAD_EXCEPTION','APPDOMAIN_UNHANDLED_EXCEPTION','FATAL_RUNTIME_ERROR','DIAGNOSTIC_REVEAL']:
        s.contains(f'Runtime event retained: {evt}',tray,evt)
    s.contains('Runtime JSONL retained',tray,"'runtime.jsonl'")
    for fn in ['environment.json','task-broker-summary.json','summary.txt']:
        s.contains(f'Diagnostic export includes {fn}',tray,fn)
    s.contains('Diagnostic privacy redacts USERPROFILE',tray,"@([string]$env:USERPROFILE, '%USERPROFILE%')")
    s.contains('Diagnostic privacy redacts username',tray,"@([string]$env:USERNAME, '<user>')")
    s.contains('Diagnostic privacy redacts computer name',tray,"@([string]$env:COMPUTERNAME, '<computer>')")
    s.contains('Diagnostic summary excludes TaskBroker userSid',tray,'TaskBroker-userSid werden nicht exportiert')

    # Popup-first / worker contracts
    pop=ps_function(tray,'Show-OrTogglePopup') or ''
    s.check('Popup show precedes background refresh',pop.find('$script:Popup.Show()')>=0 and pop.find('Start-BackgroundBootRefresh')>pop.find('$script:Popup.Show()'))
    s.contains('Popup-first rationale retained',pop,'form is visible before any fresh Scheduled-Task')
    bg=ps_function(tray,'Start-BackgroundBootRefresh') or ''
    s.contains('Background worker uses Windows PowerShell',bg,"WindowsPowerShell\\v1.0\\powershell.exe")
    s.contains('Background worker is hidden',bg,"$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden")
    s.contains('Background worker disables shell execute',bg,'$psi.UseShellExecute = $false')
    s.contains('Background worker uses BackgroundRefresh switch',bg,"'-BackgroundRefresh'")
    s.contains('Background worker propagates RuntimeSessionId',bg,"'-RuntimeSessionId'")
    s.contains('Background completion timer retained',bg,'$timer.Interval = 100')
    s.contains('Background completion event retained',tray,"-Event 'BACKGROUND_REFRESH_COMPLETED'")

    # Settings and state contracts
    getset=ps_function(tray,'Get-AppSettings') or ''
    save=ps_function(tray,'Save-AppSettings') or ''
    for field in ['defaultGuid','entryOrder','hiddenEntryGuids','entryAliases']:
        s.contains(f'Settings field retained: {field}',tray,field)
    s.contains('Settings write uses temporary file',save,'.tmp')
    s.contains('Settings write uses Move-Item commit',save,'Move-Item')
    s.contains('Settings JSON depth retained',save,'ConvertTo-Json -Depth 6')
    s.contains('Alias storage remains GUID-keyed',tray,'entryAliases')
    s.contains('Boot display order parsed read-only',tray,"if ($line -match '^\\s*displayorder\\s+')")
    s.contains('Bootsequence parsed read-only',tray,"if ($line -match '^\\s*bootsequence\\s+')")

    # Function uniqueness guards
    for fn in ['Ensure-DarkActionTooltip','Show-DarkActionTooltip','Hide-DarkActionTooltip','Show-DiagnosticPackageInExplorer','Save-RuntimeDiagnosticsFromUi','Show-LenovoNoticeDialog','Export-RuntimeDiagnosticPackage','Set-BootSequence','Test-TaskBrokerReady','Invoke-AuthorizedTask','Invoke-BcdEdit','Start-BackgroundBootRefresh','Complete-BackgroundBootRefresh','Show-OrTogglePopup','Update-PopupRows','New-PopupForm']:
        s.eq(f'Function {fn} exactly once',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',tray)),1)

    # Lexical/static integrity
    balances=lexical_balance(tray)
    for sym,(a,b) in balances.items(): s.eq(f'PowerShell lexical balance {sym}',a,b)
    s.eq('Here-string opener/closer balance',tray.count('@"'),tray.count('"@'))
    s.contains('Embedded primary C# block found',tray,'public sealed class LenovoMenuRenderer')
    csharp=tray[tray.index('using System;'):tray.index('"@',tray.index('using System;'))]
    s.eq('Embedded C# brace balance',csharp.count('{'),csharp.count('}'))
    s.eq('Embedded C# paren balance',csharp.count('('),csharp.count(')'))

    # Build integrity file
    integ=text(root/'BUILD_INTEGRITY.txt')
    s.contains('Integrity header v0.4.0',integ,'Lenovo Boot Selector v0.4.0 - Build Integrity')
    for fn in [x for x in RELEASE_NAMES if x!='BUILD_INTEGRITY.txt']:
        s.contains(f'Integrity lists {fn}',integ,f'{sha_file(root/fn)}  {fn}')

    # Release ZIP packaging
    if args.release_zip:
        zpath=args.release_zip
        s.check('Release ZIP exists',zpath.is_file())
        if zpath.is_file():
            with zipfile.ZipFile(zpath) as z:
                names=z.namelist()
                s.eq('Release ZIP has exactly 10 entries',len(names),10)
                s.eq('Release ZIP names exact',names,RELEASE_NAMES)
                s.check('Release ZIP flat',all('/' not in n for n in names))
                s.check('Release ZIP has no directory entries',all(not n.endswith('/') for n in names))
                s.eq('Release ZIP CRC/testzip passes',z.testzip(),None)
                for n in RELEASE_NAMES:
                    s.eq(f'Release payload equals source {n}',z.read(n),(root/n).read_bytes())
                dates={zi.date_time for zi in z.infolist()}
                s.eq('Release ZIP timestamps deterministic',len(dates),1)
                s.check('Release ZIP unix modes fixed 0644',all(((zi.external_attr>>16)&0o777)==0o644 for zi in z.infolist()))
            s.check('Release ZIP begins with PK signature',zpath.read_bytes().startswith(b'PK\x03\x04'))
            s.eq('Release SHA-256 is 64 hex chars',len(sha_file(zpath)),64)

    return s.finish()

if __name__=='__main__': sys.exit(main())
