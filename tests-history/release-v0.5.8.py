#!/usr/bin/env python3
from pathlib import Path
import argparse, sys
ROOT_DEFAULT=Path(__file__).resolve().parents[1]

def txt(p):
    p=Path(p)
    return p.read_text(encoding='utf-8-sig') if p.is_file() else ''

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',type=Path,default=ROOT_DEFAULT); a=ap.parse_args(); root=a.root.resolve()
    tray=txt(root/'LenovoBootMenuTray.ps1')
    template=txt(root/'src/App/LenovoBootMenuTray.template.ps1')
    infra=txt(root/'src/Infrastructure/UpdateClient.ps1')
    ui=txt(root/'src/UI/UpdatePresentation.ps1')
    rows=[]
    rows.append(('App version 0.5.8.0', "$script:AppVersion = '0.5.8.0'" in tray))
    rows.append(('Update result path is persistent under LOCALAPPDATA', "last-update-result.json" in infra and "Lenovo Boot Menu Tray\\Updates" in infra))
    rows.append(('Persistent result reader exists', 'function Read-LenovoUpdateResult' in infra))
    rows.append(('Persistent result consumer exists', 'function Remove-LenovoUpdateResult' in infra))
    rows.append(('Helper receives source version', '[string]$SourceVersion' in infra and '-SourceVersion' in infra))
    helper=infra[infra.find('function New-LenovoUpdateInstallerHelper'):]; rows.append(('Helper writes pending verification before restart', ("'pending-verification'" in helper and helper.find("'pending-verification'") < helper.find('$started = Restart-InstalledApp'))))
    rows.append(('Helper records failed update', "'failed'" in infra and 'rollbackAttempted' in infra and 'rollbackSucceeded' in infra))
    rows.append(('Helper attempts app restart after failure', 'Restart-InstalledApp' in infra))
    rows.append(('Startup result handler exists', 'function Show-PendingUpdateResultOnStartup' in ui))
    rows.append(('Startup verifies target version', 'Compare-LenovoAppVersionCore -Current $script:AppVersion -Candidate $targetVersion' in ui))
    rows.append(('Startup writes restart-result diagnostics', "'UPDATE_RESTART_RESULT'" in ui))
    rows.append(('Startup success popup exists', "-Title 'Update erfolgreich'" in ui))
    rows.append(('Startup failure popup exists', "-Title 'Update fehlgeschlagen'" in ui))
    rows.append(('Result consumed once after handling', 'Remove-LenovoUpdateResult' in ui))
    rows.append(('Startup invokes update result handler', 'Show-PendingUpdateResultOnStartup' in template))
    rows.append(('Updater remains unelevated', 'RunAs' not in infra))
    rows.append(('Updater still has no TaskBroker mutation', 'TaskBroker' not in infra))
    rows.append(('Updater still has no bcdedit', 'bcdedit' not in infra.lower()))
    for name,ok in rows: print(('PASS  ' if ok else 'FAIL  ')+name)
    passed=sum(ok for _,ok in rows); print(f'\nTOTAL {passed}/{len(rows)}')
    return 0 if passed==len(rows) else 1
if __name__=='__main__': raise SystemExit(main())
