#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys

ROOT_DEFAULT=Path(__file__).resolve().parents[1]
CORE_FILES=[
    'src/Core/EntryPreferences.ps1',
    'src/Core/FirmwareParsing.ps1',
    'src/Core/BootTargetModel.ps1',
    'src/Core/UpdateModel.ps1',
]
CHANGED_WRAPPERS={'Get-AppSettings','Save-AppSettings','Load-AppSettings','Get-FirmwareBootState','Get-FriendlyBootEntry','Update-PopupRows','Complete-BackgroundBootRefresh','Start-BackgroundBootRefresh','Export-RuntimeDiagnosticPackage','Show-OrTogglePopup','New-PopupForm'}
REMOVED_FROZEN={'Set-BootSequence','Invoke-BcdEdit'}

class Suite:
    def __init__(self): self.rows=[]
    def check(self,name,cond,detail=''): self.rows.append((name,bool(cond),detail))
    def contains(self,name,text,needle): self.check(name,needle in text)
    def absent(self,name,text,needle): self.check(name,needle not in text)
    def eq(self,name,a,b): self.check(name,a==b,f'{a!r} != {b!r}' if a!=b else '')
    def finish(self):
        for name,ok,detail in self.rows:
            print(('PASS  ' if ok else 'FAIL  ')+name+(f' [{detail}]' if detail and not ok else ''))
        p=sum(ok for _,ok,_ in self.rows); t=len(self.rows)
        print(f'\nTOTAL {p}/{t}')
        return 0 if p==t else 1

def txt(p): return Path(p).read_text(encoding='utf-8-sig')
def load_version(root):
    p=root/'version.json'
    if not p.is_file(): return None
    import json
    return str(json.loads(p.read_text(encoding='utf-8'))['version'])
def sha(b): return hashlib.sha256(b).hexdigest()
def sha_file(p): return sha(Path(p).read_bytes())
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

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); args=ap.parse_args(); root=args.root
    s=Suite()
    tray_path=root/'LenovoBootMenuTray.ps1'; template_path=root/'src/App/LenovoBootMenuTray.template.ps1'; builder=root/'tools/build_runtime.py'
    s.check('Generated runtime exists',tray_path.is_file())
    s.check('Runtime template exists',template_path.is_file())
    s.check('Deterministic runtime builder exists',builder.is_file())
    if not tray_path.is_file(): return s.finish()
    tray=txt(tray_path)
    template=txt(template_path) if template_path.is_file() else ''
    version=load_version(root)
    s.check('version.json provides version',bool(version))
    expected=f"$script:AppVersion = '{version}'" if version else ''
    s.contains(f'App version is {version}',tray,expected)
    s.eq('App version declaration exactly once',tray.count(expected),1)

    # Modular source ownership and pure-core boundary.
    forbidden=['$script:','System.Windows.Forms','Drawing.Color','Test-Path','ReadAllText','WriteAllText','Get-ItemProperty','Set-ItemProperty','Start-ScheduledTask','Get-ScheduledTask','Schedule.Service','ProcessStartInfo','Invoke-BcdEdit','TaskBroker']
    core_text={}
    for rel in CORE_FILES:
        p=root/rel; s.check(f'Core module exists: {rel}',p.is_file())
        if not p.is_file(): continue
        t=txt(p); core_text[rel]=t
        for needle in forbidden: s.absent(f'{rel} excludes infrastructure token {needle}',t,needle)
        marker=f'# @include {rel}'
        s.eq(f'Template include marker exactly once: {rel}',template.count(marker),1)
        s.absent(f'Generated runtime contains no include marker: {rel}',tray,marker)

    entry=core_text.get('src/Core/EntryPreferences.ps1','')
    firmware=core_text.get('src/Core/FirmwareParsing.ps1','')
    boot=core_text.get('src/Core/BootTargetModel.ps1','')
    for fn in ['Convert-EntryAliasesToHashtable','Copy-EntryAliasMap','Test-StringSequenceEqual','Test-EntryAliasMapsEqual','Test-GuidInList','New-DefaultAppSettingsCore','ConvertTo-NormalizedAppSettingsCore','Get-OrderedEntriesCore']:
        s.eq(f'Entry core function once in module: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',entry)),1)
        s.eq(f'Entry core function once in bundle: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',tray)),1)
    for fn in ['Parse-GuidFromLine','ConvertFrom-FirmwareEntriesText','ConvertFrom-FirmwareManagerText']:
        s.eq(f'Firmware core function once in module: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',firmware)),1)
        s.eq(f'Firmware core function once in bundle: {fn}',len(re.findall(rf'(?m)^function\s+{re.escape(fn)}\b',tray)),1)
    s.eq('Friendly core function once in module',len(re.findall(r'(?m)^function\s+Get-FriendlyBootEntryCore\b',boot)),1)
    s.eq('Friendly core function once in bundle',len(re.findall(r'(?m)^function\s+Get-FriendlyBootEntryCore\b',tray)),1)

    # Thin shell adapters actually consume the core; no dead extraction.
    getset=ps_function(tray,'Get-AppSettings') or ''
    order=ps_function(tray,'Get-OrderedEntriesForUi') or ''
    friendly=ps_function(tray,'Get-FriendlyBootEntry') or ''
    fwstate=ps_function(tray,'Get-FirmwareBootState') or ''
    s.contains('Settings shell calls default core',getset,'New-DefaultAppSettingsCore')
    s.contains('Settings shell calls normalization core',getset,'ConvertTo-NormalizedAppSettingsCore')
    s.contains('Settings shell delegates repository read',getset,'Read-AppSettingsRepository')
    s.contains('Entry-order shell calls pure core',order,'Get-OrderedEntriesCore')
    s.contains('Entry-order shell passes CurrentEntries explicitly',order,'-Source @($script:CurrentEntries)')
    s.contains('Friendly shell calls presentation-neutral core',friendly,'Get-FriendlyBootEntryCore')
    s.contains('Friendly shell maps AccentRole',friendly,'switch ([string]$model.AccentRole)')
    s.absent('Friendly core has no Drawing.Color',boot,'Drawing.Color')
    s.absent('Friendly core has no script palette',boot,'$script:Color')
    s.contains('Firmware shell delegates to boot service snapshot',fwstate,'Get-BootServiceFirmwareSnapshot')
    app=txt(root/'src/Application/BootService.ps1') if (root/'src/Application/BootService.ps1').is_file() else ''
    s.contains('Boot service calls entries parser',app,'ConvertFrom-FirmwareEntriesText')
    s.contains('Boot service calls manager parser',app,'ConvertFrom-FirmwareManagerText')
    s.contains('Firmware IO remains outside core',app,'Get-TaskBrokerFirmwareManagerText')
    s.contains('Firmware parser supports English identifier',firmware,'identifier|Bezeichner')
    s.contains('Firmware parser supports German description',firmware,'description|Beschreibung')
    s.contains('Manager parser keeps displayorder read-only parsing',firmware,"if ($line -match '^\\s*displayorder\\s+')")
    s.contains('Manager parser keeps bootsequence read-only parsing',firmware,"if ($line -match '^\\s*bootsequence\\s+')")

    # Generated bundle must be exactly reproducible from template + modules.
    if builder.is_file() and template_path.is_file():
        cp=subprocess.run([sys.executable,str(builder),'--root',str(root),'--check'],capture_output=True,text=True)
        s.eq('Runtime builder --check succeeds',cp.returncode,0)
        s.contains('Runtime builder confirms exact match',cp.stdout,'matches modular source')

    # Preserve all frozen native/security fragments except the three deliberately refactored wrappers.
    base_path=root/'tests/characterization-baseline-v0.3.4.json'
    s.check('v0.3.4 characterization baseline retained',base_path.is_file())
    if base_path.is_file():
        baseline=json.loads(base_path.read_text(encoding='utf-8'))
        for key,expected in baseline['critical_fragment_sha256'].items():
            kind,name=key.split(':',1)
            frag=ps_function(tray,name) if kind=='ps' else balanced_fragment(tray,name)
            if name in REMOVED_FROZEN:
                s.check(f'Historical frozen fragment intentionally removed: {name}',frag is None)
                continue
            s.check(f'Critical fragment present: {name}',frag is not None)
            if frag is None: continue
            actual=sha(frag.encode('utf-8'))
            if name in CHANGED_WRAPPERS:
                s.check(f'Intentional wrapper refactor changed frozen fragment: {name}',actual!=expected)
            else:
                s.eq(f'Unrelated critical fragment unchanged: {name}',actual,expected)
        for fn in ['Install-LenovoBootMenuTasks.ps1','LenovoBootMenuTray.ico','Start-LenovoBootMenuTray.cmd','Start-LenovoBootMenuTray.vbs','Uninstall-LenovoBootMenuTasks.cmd','icon-preview.png']:
            s.eq(f'Unrelated runtime asset byte-identical to v0.3.4: {fn}',sha_file(root/fn),baseline['source_sha256'][fn])
        uninstall_bytes=(root/'Uninstall-LenovoBootMenuTasks.ps1').read_bytes()
        normalized_uninstall=uninstall_bytes[3:] if uninstall_bytes.startswith(b'\xef\xbb\xbf') else uninstall_bytes
        baseline_uninstall=(root/'Uninstall-LenovoBootMenuTasks.ps1').read_text(encoding='utf-8-sig').encode('utf-8')
        s.eq('Uninstaller differs only by UTF-8 BOM normalization',normalized_uninstall,baseline_uninstall)

    # Security invariants remain in shell/installer, never in core.
    install=txt(root/'Install-LenovoBootMenuTasks.ps1'); uninstall=txt(root/'Uninstall-LenovoBootMenuTasks.ps1')
    s.contains('TaskBroker schema unchanged',tray,"$script:SupportedTaskBrokerVersions = @('0.2.12')")
    s.contains('Installer schema unchanged',install,"$version = '0.2.12'")
    s.eq('Elevation prompts still restricted to setup/remove',tray.count('-Verb RunAs'),2)
    s.contains('Explicit BootNext broker operation bundled',tray,'function Set-TaskBrokerBootNextTarget')
    s.absent('Historical Invoke-BcdEdit removed from runtime',tray,'Invoke-BcdEdit')
    s.absent('No permanent displayorder mutation in tray',tray,"'/set', '{fwbootmgr}', 'displayorder'")
    s.absent('No custom SYSTEM EXE introduced',install,'LenovoBootMenuBroker.exe')
    s.contains('Cleanup exact allowlist retained',uninstall,'$exactTaskNames = @(')
    s.contains('Cleanup owned prefixes retained',uninstall,'$ownedPrefixes = @(')

    return s.finish()

if __name__=='__main__': raise SystemExit(main())
