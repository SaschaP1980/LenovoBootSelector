# Lenovo Boot Selector – Changelog

## v0.5.10.1 – Version-only Pipeline-Performance-Test

v0.5.10.1 ist ein reiner Hotfix zur Messung des permanenten Build- und GitHub-Releasepfads. Gegenüber v0.5.10.0 gibt es keine funktionale Produktänderung. Die Änderung beschränkt sich auf die kanonische Versions-/Release-Konfiguration und die daraus deterministisch erzeugten Release-Metadaten und Pakete.

- Version von `0.5.10.0` auf `0.5.10.1` erhöht.
- `releaseProfile` ist `version-only`.
- Keine Änderung an Produkt-Runtime, Update-Verhalten, BootService, TaskBroker, Storage, Firmware-/BCD-Pfaden oder Privilege Boundary.
- Dieser Release dient ausdrücklich der End-to-End-Performance-Messung des permanenten Release-Orchestrators.

## v0.5.10.0 – Permanente Release-Pipeline und zentrale Versionierung

v0.5.10.0 ist ein Build-/Release-Architekturpatch ohne neue Produktfunktion. Die App-Version wird ab dieser Version ausschließlich aus `version.json` abgeleitet; Runtime-, Paket-, Audit- und Transition-Builds verwenden dieselbe kanonische Quelle.

Änderungen:

- Neue kanonische `version.json` mit Version, Release-Profil und deterministischem Veröffentlichungszeitpunkt.
- `LenovoBootMenuTray.template.ps1` enthält nur noch den Build-Token `@APP_VERSION@`; `tools/build_runtime.py` injiziert die kanonische Version deterministisch.
- `build_packages.py`, `build_transition.py` und `build_catch_audit.py` enthalten keine hart codierte Releaseversion mehr.
- Neue permanente Werkzeuge `release_common.py`, `prepare_release.py` und `build_architecture_baseline.py`.
- Catch-Audit und Architektur-Baseline werden ab dieser Version unter den kanonischen Dateinamen `CATCH_AUDIT.json` und `ARCHITECTURE_BASELINE.json` fortgeführt; historische versionierte Snapshots bleiben unverändert erhalten.
- Permanente Validatoren `validate_release.py`, `validate_core.py`, `validate_boundary.py` und `validate_regression.py` ersetzen künftige versionsspezifische Testkopien. Historische Validatoren bleiben als frühere Releasebelege bestehen.
- Permanenter GitHub-Releasepfad: genau ein `release/v<version>`-Branch, genau ein PR und genau ein Merge. Kein Base64-Patchtransport, kein separater Source-Branch und kein notwendiger Post-Merge-Finalizer.
- Der einzige permanente GitHub-Orchestrator reproduziert das Release und führt Release-/Core-/Boundary-/Regression-Gates selbst aus. Die grünen Gate-Status werden auf den finalen PR-Head geschrieben; ein separater `pull_request`-Workflow entfällt bewusst, weil durch `GITHUB_TOKEN` erzeugte PR-Ereignisse keinen rekursiven Workflow starten. Der ZIP-freie annotierte Source-Tag wird erst nach erfolgreichen Gates und erfolgreicher PR-Erstellung, aber vor dem Merge gesetzt.
- Bestehende historische `downloads/*.zip` bleiben unveränderlich; pro Release darf genau ein neues ZIP ergänzt werden.
- Produkt-Runtime, Update-Verhalten, BootService, TaskBroker, Storage, Firmware-/BCD-Pfade und Privilege Boundary bleiben gegenüber v0.5.9.1 funktional unverändert.

**Performance-Ziel für den anschließenden Version-only-Test:** Ziel <= 5 Minuten, harte Erwartungsgrenze 10 Minuten vom Start bis zum gemergten PR, sofern keine externe GitHub-Störung vorliegt.

## v0.5.9.1 – Versions-Hotfix ohne Funktionsänderung

v0.5.9.1 dient ausschließlich der Verifikation des vereinfachten Build-/GitHub-Release-Prozesses. Gegenüber v0.5.9.0 gibt es keine funktionale Produktänderung; die Laufzeitlogik bleibt byteidentisch, abgesehen von der App-Versionszeile.

Änderungen:

- App-Version von `0.5.9.0` auf `0.5.9.1` angehoben.
- Versionsbezogene Build-, Audit-, Download- und Revisionsmetadaten auf v0.5.9.1 fortgeschrieben.
- Keine Änderung an Update-Dialog, Update-Netzwerklogik, BootService, TaskBroker, Storage, Firmware-/BCD-Pfaden oder Privilege Boundary.
- Releaseprozess wird als **1 Build = 1 Release-Branch = 1 PR** geprüft; Source-Tag und reproduzierbare Paketprüfung müssen vor dem Merge abgeschlossen sein.

**Native Prüfung:** keine neue Funktionsprüfung erforderlich; ein Start der App mit angezeigter Version v0.5.9.1 genügt als Smoke-Test.

## v0.5.9.0 – Update direkt aus dem Verfügbarkeitsdialog starten

v0.5.9.0 verbessert ausschließlich den manuellen Update-Einstieg nach einer erfolgreichen Prüfung auf eine neue Version. Der vorhandene Updatepfad, die Netzwerk-/Hashprüfung und die Privilege Boundary bleiben unverändert.

Änderungen:

- Der Dialog **„Neue Version verfügbar“** besitzt zusätzlich den Button **„Jetzt aktualisieren“**.
- Der Button ruft direkt den bereits bestehenden `Start-ManualAppUpdate`-Pfad auf; es entsteht kein zweiter Installations- oder Downloadpfad.
- Der Hinweistext lautet: **„Du kannst die neue Version jetzt direkt installieren. Später findest du die Aktualisierung im Tray-Menü unter ‚Wartung‘ → ‚App aktualisieren…‘.“**
- **OK** bleibt als nicht installierende Aktion erhalten; der bestehende Menüeintrag **Wartung → App aktualisieren…** bleibt unverändert verfügbar.
- Keine Änderung an Downloadquelle, Update-Netzwerklogik, SHA-256-/Paketvalidierung, Backup/Rollback, Restart-Ergebnislogik, BootService, TaskBroker, Storage, Firmware-/BCD-Pfaden oder Privilege Boundary.

**Native Prüfung erforderlich:** Dialog nach einer realen Updateprüfung visuell prüfen, **„Jetzt aktualisieren“** auslösen und bestätigen, dass derselbe bestehende Updateprozess startet; anschließend **OK** regressiv als reines Schließen prüfen.

## v0.5.8.1 – Legacy-Updater-Ergebnis beim Neustart kompatibel auswerten

v0.5.8.1 ist ein enger Hotfix auf Basis der kanonischen v0.5.8.0-Source. Der reale Web-Update-Test v0.5.7.2 → v0.5.8.0 installierte v0.5.8.0 erfolgreich, zeigte nach dem Neustart jedoch fälschlich **„Update fehlgeschlagen – Unbekannter Update-Ergebnisstatus: <leer>“**. Ursache war der Formatwechsel des persistenten Restart-Ergebnisses: Der noch aus v0.5.7.2 laufende Helper schrieb `{ utc, success, message }`, während v0.5.8.0 bereits das neue Statusformat mit `status/sourceVersion/targetVersion/rollback...` erwartete.

Änderungen:

- Die Restart-Auswertung normalisiert das Ergebnis jetzt über `Resolve-LenovoUpdateRestartResultCore`.
- Das Legacy-Format wird ausschließlich erkannt, wenn `status` fehlt und `success` als echter Boolean vorliegt. Dadurch wird insbesondere `success=false` korrekt erkannt, ohne dass beschädigte String-/Pseudo-Boolean-Werte akzeptiert werden.
- Legacy `success=true` führt einmalig zu **„Update erfolgreich“**. Da das alte Format keine belastbare `targetVersion` speichert, wird diagnostisch keine Zielversion erfunden; angezeigt wird ausschließlich die tatsächlich laufende App-Version.
- Legacy `success=false` führt einmalig zu **„Update fehlgeschlagen“** und übernimmt die gespeicherte Legacy-Fehlermeldung bzw. einen neutralen Fallback.
- Sobald `status` vorhanden ist, hat das v0.5.8.x-Statusformat Vorrang; `pending-verification`, exakte Zielversionsprüfung, `failed` und Rollbackdarstellung bleiben unverändert.
- `UPDATE_RESTART_RESULT` enthält zusätzlich `resultFormat` und bei Legacy-Ergebnissen `legacySuccess`, damit die Kompatibilitätsauswertung diagnostisch eindeutig erkennbar ist.
- Unbekannte bzw. beschädigte Ergebnisformen bleiben fail-closed und erzeugen weiterhin **„Unbekannter Update-Ergebnisstatus“**.
- Das Ergebnis wird weiterhin vor dem modalen Dialog konsumiert und deshalb höchstens einmal angezeigt.
- Keine Änderung an Downloadquelle, Netzwerklogik, SHA-256-/Paketprüfung, Backup/Rollback, BootService, TaskBroker, Storage, Firmware-/BCD-Pfaden oder Privilege Boundary.

**Native Prüfung erforderlich:** den neuen Resolver unter Windows PowerShell 5.1 vollständig prüfen und einen realen Übergang von einem Helper mit Legacy-Ergebnisformat auf v0.5.8.1 bzw. einen kontrollierten Legacy-Fixture-Fall bestätigen. Das neue Statusformat muss regressiv unverändert funktionieren.

## v0.5.8.0 – Update-Ergebnis nach Neustart bestätigen

v0.5.8.0 erweitert den manuellen Self-Updater um eine persistente Abschlussbestätigung über den Prozessneustart hinweg. Der erfolgreiche reale Web-Update-Test v0.5.7.1 → v0.5.7.2 hat gezeigt, dass der Updatepfad selbst funktioniert; die vorherige Runtime-Diagnose endete jedoch mit der alten Sitzung und zeigte dem Nutzer nach dem Neustart keine explizite Abschlussmeldung.

Änderungen:

- Der unelevierte Installer-Helper schreibt vor dem Neustart ein persistentes Update-Ergebnis unter `%LOCALAPPDATA%\Lenovo Boot Menu Tray\Updates\last-update-result.json`.
- Ein Update wird zunächst als `pending-verification` markiert. **Erfolg wird erst von der neu gestarteten Tray-App bestätigt**, wenn ihre laufende Version exakt der erwarteten Zielversion entspricht.
- Nach erfolgreicher Verifikation erscheint einmalig **„Update erfolgreich“** mit der installierten Zielversion.
- Bei Installations-/Restartfehlern wird weiterhin der bestehende Backup-/Rollback-Pfad verwendet. Der Helper speichert `failed` samt Rollbackstatus und versucht anschließend, die installierte bzw. wiederhergestellte App erneut zu starten.
- Nach einem fehlgeschlagenen Update erscheint beim nächsten App-Start einmalig **„Update fehlgeschlagen“**; bei erfolgreichem Rollback wird dies ausdrücklich genannt.
- Das konsumierte Ergebnis wird als `UPDATE_RESTART_RESULT` mit Quellversion, Zielversion, laufender Version und Rollbackstatus in die Runtime-Diagnose der neuen Sitzung übernommen.
- Das Ergebnis wird vor Anzeige des modalen Dialogs konsumiert, damit dieselbe Abschlussmeldung höchstens einmal erscheint.
- Versionsschema bleibt **MAJOR.MINOR.PATCH.HOTFIX**; v0.5.8.0 ist der nächste PATCH nach v0.5.7.2.
- Keine Änderung an Firmware-/BCD-/TaskBroker-/Storage-Pfaden und kein neuer privilegierter Updatekanal.

**Native Prüfung erforderlich:** Update von einer älteren installierten Version auf v0.5.8.0 durchführen und bestätigen, dass nach dem automatischen Neustart genau einmal **„Update erfolgreich“** erscheint. Zusätzlich ist ein kontrollierter Fehler-/Rollbacktest in einer disposable Kopie vorgesehen.

## v0.5.7.2 – Web-Update-Testrelease

v0.5.7.2 ist ein bewusst minimaler Test-Release für den ersten echten Web-Update-Pfad von v0.5.7.1 auf v0.5.7.2. Gegenüber v0.5.7.1 wurde ausschließlich die Versionsnummer erhöht; es gibt keine weitere funktionale Produktänderung. Auf ausdrücklichen Wunsch wurden für dieses Release keine Tests und kein Handover erzeugt.

## v0.5.7.1 – Vierstufiges Versionsschema für Web-Updates

v0.5.7.1 ist ein bewusst minimaler Test-Release für das Versionsschema **MAJOR.MINOR.PATCH.HOTFIX**. Der Update-Parser akzeptiert jetzt drei- und vierteilige Versionen; historische dreiteilige Versionen werden intern mit `HOTFIX = 0` verglichen. Darüber hinaus enthält dieser Test-Release keine funktionalen Produktänderungen. Auf ausdrücklichen Wunsch wurden für dieses Release keine Tests und kein Handover erzeugt.

## v0.5.7 – Update-Manifest-Roundtrip korrigiert

v0.5.7 ist ein enger Updater-Bugfix auf Basis von v0.5.6. Der Fehler trat beim manuellen Update-Check auf: Das Remote-Manifest wurde im Check-Worker zunächst korrekt validiert, das normalisierte Ergebnis verlor jedoch `schemaVersion`. Die Tray-App validierte dieses Worker-Ergebnis ein zweites Mal und lehnte es deshalb mit **„Update-Manifest-Schema wird nicht unterstützt.“** ab.

Änderungen:

- `Test-LenovoUpdateManifestCore` erhält `SchemaVersion = 1` im normalisierten Manifest-Ergebnis.
- Der Worker→JSON→Tray-Roundtrip bleibt damit vollständig und die zweite Validierung akzeptiert ein zuvor bereits valides Manifest.
- `Test-UpdateCore.ps1` prüft nun explizit die normalisierte Schema-Version und einen vollständigen JSON-Roundtrip.
- Downloadquelle, SHA-256-Gate, Paketvalidierung, Backup/Rollback, unelevierter Installer-Helper und alle Boot-/TaskBroker-/Storage-/Privilege-Pfade bleiben unverändert.

**Native Prüfung erforderlich:** v0.5.7 manuell installieren, **„Auf neue Version prüfen…“** ausführen und bestätigen, dass bei aktuellem Stand **„Lenovo Boot Selector v0.5.7 ist aktuell.“** erscheint. Für den ersten echten Self-Update-Erfolg ist anschließend eine spätere Version erforderlich.

## v0.5.6 – Wartungsmenü thematisch geordnet

v0.5.6 ist ein enger UI-/Menüstruktur-Patch auf Basis von v0.5.5. Die Update-, Boot-, Storage-, TaskBroker- und Privilege-Logik bleibt unverändert.

Änderungen:

- Im Untermenü **Wartung** bleiben die thematischen Blöcke erhalten und werden jetzt klar in der Reihenfolge **Systemfunktionen → Updates → Diagnose** dargestellt.
- **„Diagnose speichern…“** steht als letzter Eintrag ganz unten im Wartungs-Untermenü.
- Zwischen Systemfunktionen und Updates sowie zwischen Updates und Diagnose steht jeweils genau ein Separator.
- **„Auf neue Version prüfen…“** und **„App aktualisieren…“** behalten ihre v0.5.5-Funktion und -Semantik unverändert bei.
- Keine Änderung an Self-Updater-Download/Hash/Backup/Rollback, Firmware-/BCD-Pfaden, Scheduled Tasks, Storage-Erkennung oder Bootziel-Logik.

**Native Prüfung erforderlich:** Wartungs-Untermenü öffnen und die Reihenfolge Systemfunktionen → Updates → Diagnose sowie die beiden Separatoren visuell bestätigen. Die v0.5.5-Updater-Funktion kurz regressiv prüfen.

## v0.5.5 – Manueller Self-Updater

v0.5.5 führt einen explizit vom Benutzer gestarteten Self-Updater ein. Es gibt weiterhin keinerlei periodische oder automatische Update-Prüfung.

Änderungen:

- Im Tray-Kontextmenü unter **Wartung** stehen jetzt exakt **„Auf neue Version prüfen…“** und **„App aktualisieren…“** zur Verfügung.
- **„App aktualisieren…“** ist zunächst deaktiviert und wird erst nach einer erfolgreichen Prüfung auf eine tatsächlich neuere, valide Version aktiv.
- Die Update-Metadaten werden ausschließlich aus dem fest eingebauten öffentlichen Repository `SaschaP1980/LenovoBootSelector` gelesen.
- `downloads/latest.json` ist das maschinenlesbare Manifest. Versionsformat, Dateiname, Git-Tag, Dateigröße, SHA-256 und die erwartete flache Paketdateiliste werden strikt validiert.
- Das Release-ZIP wird vor dem Entpacken gegen Größe und SHA-256 geprüft. Abweichungen brechen das Update fail-closed ab.
- Das ZIP muss flach sein; Verzeichnisse, `..`-Pfadbestandteile und unerwartete Dateien werden abgelehnt.
- Download und Paketvorbereitung laufen in versteckten, unelevierten Worker-Prozessen, damit die Tray-UI nicht durch Netzwerkzugriffe blockiert wird.
- Nach erfolgreicher Vorbereitung startet ein temporärer unelevierter Update-Helper. Er wartet auf das Ende der Tray-App, sichert alle verwalteten Release-Dateien, ersetzt sie atomar best-effort, startet die App über den vorhandenen VBS-Launcher neu und führt bei Installationsfehlern einen Rollback auf die gesicherten Dateien aus.
- Einstellungen, Diagnosen und TaskBroker-Zustand unter `%LOCALAPPDATA%` bzw. `%ProgramData%` werden vom Updater nicht verändert.
- Der Updater besitzt keinen `RunAs`-/SYSTEM-Pfad und führt weder `bcdedit` noch Scheduled-Task-Operationen aus. Falls eine zukünftige Version andere Systemfunktionen benötigt, greift nach dem Neustart weiterhin die bestehende TaskBroker-Kompatibilitäts-/Repair-Logik.
- Update-Prüfung, Vorbereitung und Helper-Start werden in der bestehenden Runtime-Diagnose protokolliert.
- Die Build-Revisionshistorie in `downloads/` bleibt erhalten. Jede gebaute produktive Source-Revision bekommt ein versioniertes ZIP; ältere ZIPs bleiben bestehen.
- Jede gebaute Version erhält einen unveränderlichen Git-Tag `vX.Y.Z` auf den zugehörigen Source-Commit.

### Native Windows-Abnahme erforderlich

Zusätzlich zu den bisherigen Parser/Core/Refresh/Mutex/Soak/Maintenance/Drift-Tests muss `Test-UpdateCore.ps1` vollständig grün sein. Manuell sind mindestens „keine neue Version“, „neue Version gefunden“, fehlerhafter Hash/Download sowie ein erfolgreicher Self-Update-Pfad mit Neustart zu prüfen.

## Repository-Pflege nach v0.5.4

- `README.md` ist eine klassische GitHub-Projektübersicht; die fortlaufende Versionshistorie liegt in dieser `CHANGELOG.md`.
- `downloads/` ist eine dauerhafte Build-Revisionshistorie, nicht nur ein Ordner für das jeweils neueste ZIP.
- Architektur-Baselines und Catch-Audits sollen in einem späteren kontrollierten Cleanup aus dem Repository-Root nach `docs/architecture/` bzw. `audits/` verschoben werden; Tests/Buildpfade werden dabei gemeinsam migriert.

## Neu in v0.5.4 – USB-Startmedium klar benennen

v0.5.4 baut ausschließlich auf der kanonischen v0.5.3-Source auf. Der Patch ändert nur die endanwenderseitige Bezeichnung für den bereits read-only erkannten einzelnen USB-Bootkandidaten. Statt einer Wahrscheinlichkeitsformulierung beschreibt die UI nun direkt den belegten Storage-Befund. Boot-, Firmware-, TaskBroker-, Storage-Refresh- und Privilege-Architektur bleiben unverändert.

Änderung:

- **Genau ein USB-Bootkandidat:** Der Subtext unter dem generischen Firmwareziel `USB HDD` bzw. einem Alias wie `Windows: Gaming` lautet nun **`USB-Startmedium: <Modell>`**. Auf dem Zielsystem wird damit **`USB-Startmedium: SanDisk Extreme Pro USB4`** erwartet.
- **Keine neue Firmwarebindung:** Die Formulierung sagt nur aus, welches physische USB-Medium eine erkannte Bootstruktur besitzt. Sie behauptet weiterhin keine direkte 1:1-Adressierbarkeit des generischen Firmwareziels `USB HDD`.
- **Alle anderen USB-Zustände unverändert:** Pending, echter Storagefehler, nicht als Startmedium erkannte Medien, mehrere mögliche USB-Startmedien und kein USB-Laufwerk bleiben unverändert.

**Native Prüfung erforderlich:** Mit SanDisk als einzigem erkannten USB-Bootkandidaten muss nach dem Storage-Refresh `USB-Startmedium: SanDisk Extreme Pro USB4` erscheinen. Die v0.5.3-NVMe-Darstellung sowie Header-/Tray-Rot müssen unverändert bleiben.


## Neu in v0.5.3 – NVMe-Slotdarstellung

v0.5.3 baut ausschließlich auf der kanonischen v0.5.2-Source auf. Der Patch verbessert nur die read-only Darstellung der internen NVMe-Slots auf dem bestätigten Ziel-ThinkPad. Bei genau einer von Windows erkannten internen NVMe zeigt `NVMe-SSD 1` deren Modell als `Interne SSD: <Modell>`; `NVMe-SSD 2` zeigt in diesem bestätigten Ein-Slot-Zustand `Kein Laufwerk erkannt`. Bei mehreren NVMe-Laufwerken wird bewusst keine physische NVMe0/NVMe1-Zuordnung geraten; die bisherigen generischen Subtexte bleiben dann erhalten. Boot-, Firmware-, TaskBroker-, Storage-Refresh- und Privilege-Architektur bleiben unverändert.

## Neu in v0.5.2 – USB-Pending-State und Lenovo-Rot-Experiment

v0.5.2 baut ausschließlich auf der kanonischen v0.5.1-Source auf. Der Patch korrigiert den beim nativen Start beobachteten Präsentationszustand der USB-Erkennung und enthält zwei bewusst kleine UI-Experimente. Boot-, Storage- und Privilege-Architektur bleiben unverändert.

Änderungen:

- **USB-Prüfung laufend statt Fehler:** Solange beim ersten Popup-Aufbau noch kein `StorageContext` vorliegt, zeigt `USB HDD` nun **`USB-Laufwerke werden geprüft …`**. **`USB-Laufwerke konnten nicht geprüft werden`** bleibt ausschließlich dem tatsächlich abgeschlossenen Fehlerzustand `UsbResolution = 'Unavailable'` vorbehalten.
- **Header testweise in Lenovo-Rot:** Der Schriftzug **`Lenovo Boot Selector`** oben links im Popup verwendet testweise den bestehenden Lenovo-Rot-Akzent.
- **Tray-Kontextmenü präzisiert:** **`Boot Selector öffnen`** heißt nun **`Lenovo Boot Selector öffnen`** und wird testweise in Lenovo-Rot dargestellt. Die übrigen Kontextmenüeinträge bleiben unverändert.
- **Keine Refresh-Architekturänderung:** Kein Polling, keine PnP-/Device-Arrival-Handler und keine Änderung an `Storage.ps1`. Der bestehende Popup-first-Hintergrundrefresh bleibt erhalten.
- **Keine neue privilegierte Mutation:** TaskBroker, BootService, Installer/Uninstaller und Firmware-/BCD-Schreibgrenzen bleiben unverändert.

**Native Prüfung erforderlich:** Kaltstart/Appstart beobachten: zuerst `USB-Laufwerke werden geprüft …`, danach den realen USB-Zustand. Zusätzlich Headerfarbe und Tray-Menütext/-farbe unter Windows prüfen. Ein echter Storage-Lesefehler muss weiterhin `USB-Laufwerke konnten nicht geprüft werden` anzeigen.

## Neu in v0.5.1 – USB-HDD-Semantik nach read-only Capability-Discovery

v0.5.1 baut ausschließlich auf der kanonischen v0.5.0-Source auf. Die read-only USB-Direct-Boot-Discovery hat gezeigt, dass das ThinkPad die physischen USB-Geräte im F12-Menü zwar namentlich unterscheiden kann, BCD, Standard-UEFI und die dokumentierten Lenovo-WMI-Oberflächen aber nur das generische Firmwareziel `USB HDD` als softwareseitig adressierbares Bootobjekt exponieren. v0.5.1 korrigiert deshalb ausschließlich Darstellung und Terminologie; die Privilege-Boundary und alle mutierenden Bootpfade bleiben unverändert.

Änderungen:

- **Firmwareziel bleibt sichtbar:** Der auswählbare Eintrag heißt immer **`USB HDD`**. Ein physisches USB-Laufwerk ersetzt den Firmwaretitel nicht mehr.
- **Physisches Medium nur als Status:** Bei genau einem erkannten USB-Bootkandidaten lautet der Subtext **`Wahrscheinlich: <Modell>`**. Bei genau einem USB-Laufwerk ohne erkannte Bootstruktur lautet er **`<Modell> erkannt · nicht als Startmedium erkannt`**.
- **Weitere USB-Zustände:** Ohne USB-Laufwerk wird **`Kein USB-Laufwerk angeschlossen`** angezeigt; mehrere Laufwerke ohne Bootkandidaten ergeben **`USB-Laufwerke erkannt · kein Startmedium gefunden`**; mehrere Bootkandidaten **`Mehrere mögliche USB-Startmedien erkannt`**; bei fehlgeschlagener Storage-Erkennung **`USB-Laufwerke konnten nicht geprüft werden`**.
- **Drift-Begriff präzisiert:** Firmware-only-Drift heißt **`Neues Startziel erkannt`** statt `Neues Gerät erkannt`; neutrale Änderungszustände sprechen von `Startzielen` statt physischen `Startgeräten`.
- **Keine neue USB-Adressierung:** Es gibt keinen neuen SanDisk-/Micron-spezifischen Next-Boot-Pfad, keine neue Firmwarevariable, keinen Lenovo-WMI-Setter und keine permanente `BootOrder`-/`displayorder`-Mutation.
- **Refresh-Policy unverändert:** Keine PnP-/Device-Arrival-Eventhandler und kein periodisches Polling. Appstart, bestehender Refresh und manueller Reload bleiben die Aktualisierungspfade.

**Native Prüfung erforderlich:** Auf dem Ziel-ThinkPad mindestens die Zustände `SanDisk + Micron`, `nur Micron` und `kein USB` per vollständigem Refresh prüfen. Der Titel muss jeweils `USB HDD` bleiben; der Subtext muss zwischen `Wahrscheinlich: SanDisk Extreme Pro USB4`, `Micron CT2000X9PROSSD9 erkannt · nicht als Startmedium erkannt` und `Kein USB-Laufwerk angeschlossen` wechseln. Zusätzlich den Firmware-Drift-Simulationspfad auf `Neues Startziel erkannt` prüfen.


## Neu in v0.5.0 – read-only Drift-Erkennung und Neu-Initialisierung bei neuen Startgeräten

v0.5.0 baut auf der nativ vollständig freigegebenen v0.4.7-Basis auf. Die App erkennt Änderungen am Firmware-/Bootzielbestand ausschließlich read-only und vergleicht den aktuell gelesenen Firmware-Zielsatz mit dem bei der Einrichtung fest autorisierten TaskBroker-Zielsatz. Es findet niemals eine automatische Reparatur oder Neu-Initialisierung statt.

Änderungen:

- **Read-only Drift-Erkennung:** Nach einem frischen Firmware-/Manager-Refresh werden Boot Menu + `{fwbootmgr}`-`displayorder` mit den installierten `task-broker.json`-Targets verglichen. Hinzugekommene und entfernte GUIDs werden getrennt diagnostiziert.
- **Neue Geräte-UX:** Bei neu hinzugekommenen Firmware-Zielen zeigt das zentrale Popup **`Neues Gerät erkannt`**. Bei einer reinen Entfernung wird neutral **`Startgeräte wurden geändert`** angezeigt. Die primäre Aktion heißt in beiden Fällen **`Systemfunktionen neu initialisieren`**.
- **Kein Auto-Repair:** Die Erkennung startet weder UAC noch Setup automatisch. Erst die explizite Nutzerbestätigung startet den bestehenden sicheren Installer-Pfad. Intern bleibt die Privilege-Boundary unverändert; keine freie GUID, kein freier Taskname und kein freies Argument werden übergeben.
- **Drift blockiert normale Mutation:** Solange die Neu-Initialisierung aussteht, sind BootNext, Standardziel, Manage, Restart und manueller Refresh in der normalen UI gesperrt/überdeckt. Die App kann weiterhin read-only diagnostizieren.
- **Neu-Initialisieren als eigener Maintenance-Modus:** Busy-Ansicht und Erfolgsdialog verwenden bewusst die Nutzerbegriffe `neu initialisieren` / `neu initialisiert`, nicht `Repair`. Die bestehende `Reparieren`-UX bleibt nur für wirklich unvollständige/alte Installationen bestehen.
- **Diagnose:** `BOOT_TARGET_DRIFT_CHECK` protokolliert Driftstatus sowie hinzugekommene/entfernte Firmware-GUIDs als Warning, nicht als Runtime-Error.
- **Native Tests:** `Test-BootTargetDrift.ps1` prüft Gleichstand, hinzugefügte und entfernte Ziele sowie den Drift-Runtime-State. Der Windows-PowerShell-5.1-Wrapper führt ihn zusätzlich aus.

**Native Prüfung erforderlich:** Firmware-/Bootzieländerung auf dem Ziel-PC erzeugen bzw. kontrolliert simulieren, `Neues Gerät erkannt` und die CTA `Systemfunktionen neu initialisieren` prüfen, sicherstellen dass vor Nutzerbestätigung keine UAC/Mutation erfolgt, anschließend Neu-Initialisierung mit UAC abschließen und verifizieren, dass der Drift verschwindet und die normalen Bootfunktionen wieder freigegeben werden.


## Neu in v0.4.7 – Maintenance UX, First-Run Setup und Wartungsdiagnostik

v0.4.7 ist ein verpflichtender Korrektur-/UX-Build nach dem erstmalig vollständig nativ getesteten Maintenance-Zyklus. Setup/Repair/Remove bleiben sicherheitstechnisch unverändert hinter den festen SYSTEM-Scheduled-Tasks; geändert werden ausschließlich Lifecycle-Sperren, Haupt-Popup-Präsentation, Abschlussfeedback und maintenance-aware Diagnose.

Änderungen:

- **Zentraler Maintenance-State:** Setup, Repair, Migrate und Remove verwenden einen expliziten Busy-State. Währenddessen werden normale Bootziel-, Default-, Manage-, Refresh- und Restart-Pfade gesperrt; laufende/pending Background-Refresh-Arbeit wird kontrolliert beendet.
- **Prominenter First-Run-/Repair-State:** Fehlen die Systemfunktionen, zeigt das Haupt-Popup zentral `Systemfunktionen einrichten` mit primärer CTA. Bei vorhandener, unvollständiger Installation wird zentral `Systemfunktionen reparieren` angeboten. Auf einem echten Erststart öffnet sich das Popup automatisch; UAC startet erst nach ausdrücklicher Nutzerbestätigung.
- **Klare Wartungsanzeige:** Während Installation/Reparatur/Entfernung liegt eine zentrale app-eigene Wartungsansicht über der normalen UI. Das Popup bleibt sichtbar und zeigt den aktuellen Zustand statt weiter bedienbarer Bootfunktionen.
- **App-eigener Abschluss:** Erfolgreiches Setup/Repair bestätigt `Systemfunktionen sind bereit.`; erfolgreiches Remove bestätigt `Systemfunktionen wurden entfernt.`. Danach wird die UI deterministisch neu aufgebaut bzw. in den Setup-State gewechselt.
- **Maintenance-aware Diagnostics:** Neue Refreshs werden während Wartung unterdrückt, laufende Refreshs kontrolliert abgebrochen und als erwarteter Maintenance-Zustand protokolliert. Nach erfolgreichem Remove wird der absichtlich fehlende TaskBroker nicht mehr über einen normalen Ready-Check als Runtime-Fehler erzeugt.
- **Soak-Test-Harness korrigiert:** `Test-ArchitectureSoak.ps1` verwendet für die Settings-Normalisierung korrekt `-Source $raw` statt des falschen `-Settings $raw`.
- **Keine Privilege-Änderung:** Tray bleibt uneleviert; keine freien Commands/Argumente/Tasknamen/GUIDs, keine permanente `displayorder`, keine Custom-SYSTEM-EXE.

**Native Prüfung erforderlich:** Windows-PowerShell-5.1-Wrapper inklusive Maintenance-Test, First-Run ohne registrierte Tasks, Setup/Repair/Remove/Re-Setup mit Busy-UI und Erfolgsdialogen sowie abschließende Diagnose ohne erwartbare Maintenance-Fehler als Error.


## Neu in v0.4.6 – Cleanup / Soak und Architekturabschluss

v0.4.6 schließt die geplante 0.4.x-Refactoring-Serie behavior-preserving ab. Es gibt keine neue Endanwenderfunktion. Der nativ grüne v0.4.5-Stand bleibt die Verhaltensbasis; Cleanup wird nur dort vorgenommen, wo statische Aufrufanalyse und Regressionstests die Entfernung oder Verschiebung eindeutig absichern.

Änderungen:

- **Vier tote Runtime-Funktionen entfernt:** `Test-IsAdministrator`, `Get-PresentDiskPnpInfo`, `Find-MatchingPnpDisk` und der unbenutzte Wrapper `Show-ManageEntriesMode` hatten im modularen Source-Graph keine Aufrufer mehr. Sie werden nicht durch neue Implementierungen ersetzt.
- **Drei tote Globals entfernt:** `$script:AutostartTaskName`, `$script:ColorBorder` und `$script:ColorFrame` waren nur noch Deklarationen ohne Leser.
- **Storage-Infrastructure explizit:** Der tatsächlich aktive, weiterhin heuristische Storage-/USB-Pfad (`Test-PartitionBootStructure`, `Get-StorageContextCore`, `Get-StorageContext`) liegt jetzt in `src/Infrastructure/Storage.ps1`. Die Funktionskörper bleiben gegenüber v0.4.5 unverändert.
- **Catch-Audit statt stiller Unklarheit:** `CATCH_AUDIT_v0.4.6.json` klassifiziert jeden verbleibenden inline leeren/best-effort `catch { }` im modularen Runtime-Source. `tools/build_catch_audit.py --check` stellt sicher, dass der Audit exakt zum Source passt. Produktrelevante Fehlerpfade bleiben weiterhin explizit diagnostiziert.
- **Nativer Architektur-Soak:** `tests/Test-ArchitectureSoak.ps1` wiederholt Refresh-Lifecycle, Settings-Normalisierung, Firmware-Manager-Parsing und die 30-Sekunden-Firmware-Freshness jeweils 500-mal. Der Windows-PowerShell-5.1-Wrapper führt diesen Test zusätzlich zu Core, Refresh und Mutex aus.
- **Keine Sicherheits-/UX-Änderung:** TaskBroker, BootService, RefreshRuntime, Settings-Service, Autostart, Diagnostics und die geschlossenen UI-Pfade bleiben unverändert. Popup-first, Vollbreiten-Hover/Selected, rote Separatoren, Auge-/Stift-Tooltips und der taskbar-silente Recovery-Dialog bleiben Regression-Verträge.

**Native Prüfung erforderlich:** `tests\Test-WindowsPowerShell51.ps1` muss Parser/Core/Refresh/Mutex/Soak vollständig grün durchlaufen. Anschließend folgt ein längerer Tray-/Refresh-/Close-Restart-Soak plus die bekannten Boot-/Settings-/Autostart-/Diagnose-/UI-Regressionspfade.


## Neu in v0.4.5 – Settings-/Autostart-/Diagnostics-Infrastructure-Adapter

v0.4.5 ist der nächste behavior-preserving Architektur-Schritt auf Basis der nativ bestätigten v0.4.4-Runtime/UI-Pfade. Persistenz-, Registry-/Task-Scheduler- und Diagnose-Dateisystemzugriffe werden aus der App-/UI-Schicht hinter klar benannte Infrastructure-Operationen verschoben. Es gibt keine neue Endanwenderfunktion.

Änderungen:

- **SettingsRepository:** Datei-/JSON-IO und der Legacy-Registry-Cleanup liegen in `src/Infrastructure/SettingsRepository.ps1`; Normalisierung bleibt im Functional Core. `src/Application/SettingsService.ps1` baut weiterhin denselben Settings-Vertrag (`schemaVersion = 4`) und verwendet nur benannte Repository-Operationen.
- **Autostart getrennt:** HKCU-Run-Key, versteckter VBS-Launcher und read-only Legacy-Task-Erkennung liegen in `src/Infrastructure/Autostart.ps1`. WinForms-Zustand und Benutzerfeedback liegen separat in `src/UI/AutostartPresentation.ps1`.
- **Runtime-Diagnose getrennt:** Session-Logging, Retention, Export-ZIP und Explorer-Reveal liegen in `src/Infrastructure/RuntimeDiagnostics.ps1`; die manuelle UI-Aktion liegt in `src/UI/DiagnosticsPresentation.ps1`.
- **Keine Runtime-Modulabhängigkeit:** Der Release bleibt eine deterministisch erzeugte Single-File-`LenovoBootMenuTray.ps1`; lose Source-Module werden zur Laufzeit nicht geladen.
- **Abandoned-Mutex-Test korrigiert:** Der Parent öffnet jetzt seinen Handle auf den benannten Mutex, bevor der Child-Prozess als Eigentümer beendet wird. Ein explizites Dateisignal synchronisiert den Exit, sodass der Test tatsächlich `AbandonedMutexException` prüfen kann. Die Produkt-Singleton-Implementierung bleibt unverändert.
- **Security/UX unverändert:** TaskBroker, BootService, RefreshRuntime, BackgroundRefreshWorker, Functional Core und die bestehenden UI-Module bleiben unverändert. Popup-first, feste SYSTEM-Tasks, Vollbreiten-Hover/Selected, rote Separatoren, Auge-/Stift-Tooltips und Recovery-Dialog bleiben Regression-Verträge.

**Native Prüfung erforderlich:** `tests\Test-WindowsPowerShell51.ps1` muss Parser/Core/Refresh/Mutex vollständig grün durchlaufen. Danach kurzer Settings-/Autostart-/Diagnose-Smoke plus die bestehenden Boot-/UI-Regressionspfade.


## Neu in v0.4.4 – UI-Source-Split ohne Runtime-Verhaltensänderung

v0.4.4 ist der nächste behavior-preserving Architektur-Schritt auf Basis der nativ vollständig bestätigten v0.4.3-Runtime/UI-Pfade. Die WinForms-Präsentation wird aus dem App-Template in klar benannte `src/UI/`-Module extrahiert; der Release bleibt weiterhin ein deterministisch erzeugtes Single-File-`LenovoBootMenuTray.ps1`. Es gibt keine neue Endanwenderfunktion.

Änderungen:

- **UI-Source modularisiert:** Startfehlerdialog, Menüdarstellung/Tooltips, Refresh-Präsentation, Manage-Mode, Standardziel-Präsentation/-Menü, App-Dialoge, Bootziel-Liste und Popup liegen in zehn `src/UI/*.ps1`-Modulen.
- **Keine Runtime-Modulabhängigkeit:** `tools/build_runtime.py` bündelt Core, Application, Infrastructure und UI weiterhin deterministisch in die eine Runtime-Datei. Zur Laufzeit werden keine losen Module importiert.
- **UI-Verhalten eingefroren:** Die 34 verschobenen UI-Funktionen werden gegen Funktions-SHA-256 der nativen v0.4.3-Basis charakterisiert. Vollbreiten-Hover/Selected, rote Separatoren, Auge-/Stift-Tooltips und der taskbar-silente Recovery-Dialog bleiben unverändert.
- **Schichtgrenze:** `src/UI/` darf keine privilegierten Scheduled-Task-/TaskBroker-Mechanismen direkt aufrufen. Privilegierte Operationen bleiben ausschließlich hinter Infrastructure/Application.
- **App-Template deutlich kleiner:** Die generierte Runtime darf weiterhin groß sein; die editierbare App-Shell enthält jedoch wesentlich weniger Presentation-Code.
- **Mutex-Test-Harness korrigiert:** Die temporären Named-Mutex-Pfade in `Test-SingleInstanceMutex.ps1` verwenden jetzt korrekt genau einen Backslash (`Local\...`). Damit kann der Windows-PowerShell-5.1-Test den realen Namespace erzeugen.
- **Keine fachliche Änderung:** RefreshRuntime, BackgroundRefreshWorker, TaskBroker, BootService, Functional Core, Installer/Uninstaller und Launcher bleiben semantisch unverändert.

**Native Prüfung erforderlich:** `tests\Test-WindowsPowerShell51.ps1` muss Parser/Core/Refresh/Mutex vollständig grün durchlaufen. Danach kurzer UI-Smoke für Popup, Bootzielliste, Manage-Mode, Standardziel-Menü, Dialoge, Vollbreiten-Hover/Separatoren/Tooltips und Recovery-Dialog.


## Neu in v0.4.3 – expliziter Refresh-Runtime-State

v0.4.3 ist der nächste behavior-preserving Architektur-Schritt auf Basis der nativ vollständig bestätigten v0.4.2.2. Es gibt keine neue Endanwenderfunktion. Ziel ist, Background-Refresh, Request-Coalescing, Ergebnisverarbeitung und Refresh-Lifecycle aus verstreutem globalem `$script:`-State in klar abgegrenzte Verträge zu überführen, ohne Popup-first oder die privilegierte TaskBroker-Grenze zu verändern.

Änderungen:

- **Ein Refresh-State statt neun Einzelglobals:** Prozess, Timer, Ergebnisdatei, aktiver Request, Pending-Request und letztes Timing liegen in einem expliziten `BackgroundRefreshState`. Die bisherigen Globals `BackgroundRefreshProcess`, `BackgroundRefreshTimer`, `BackgroundRefreshResultPath`, `BackgroundRefreshRequested*`, `BackgroundRefreshPending*` und `LastBackgroundRefreshTiming` entfallen.
- **Request-/Transition-Logik ausgelagert:** `src/Application/RefreshRuntime.ps1` enthält den zustandsfreien Refresh-Vertrag für Request-Erzeugung, Firmware-Freshness, Eskalation/Coalescing, Lifecycle-Übernahme, Pending-Request und Result-Parsing. Das Modul verwendet keinen `$script:`-State, kein WinForms und keine Prozess-/Dateisystem-API.
- **Prozess-/Result-IO isoliert:** `src/Infrastructure/BackgroundRefreshWorker.ps1` startet ausschließlich den bereits vorhandenen versteckten unelevierten Windows-PowerShell-Worker und kapselt Result-Read/Cleanup. Die UI/Application-Schicht erzeugt keinen `ProcessStartInfo` mehr direkt.
- **Completion aufgeteilt:** Lifecycle-Abschluss, Ergebnislesen/-parsen und UI-/Cache-Anwendung sind getrennte Verantwortlichkeiten (`Complete-BackgroundBootRefresh`, `Get-BackgroundRefreshResult`, `Apply-BackgroundRefreshResult`).
- **Coalescing unverändert:** Ein laufender Refresh bekommt keinen redundanten Folgejob. Nur neu hinzukommende Storage-/Firmware-Arbeit wird als Pending-Request zusammengeführt.
- **Popup-first unverändert:** Firmware-/Storage-Arbeit bleibt im unelevierten Background-Worker. Das Popup wartet weiterhin nicht auf einen frischen Scheduled-Task-/Storage-Lauf.
- **Security Boundary unverändert:** `src/Infrastructure/TaskBroker.ps1`, `src/Application/BootService.ps1`, Functional Core, Installer/Uninstaller und Launcher bleiben byteidentisch zu v0.4.2.2. Keine freie Command-/Argument-/GUID-Schnittstelle, keine permanente `displayorder`-Mutation und keine Custom-SYSTEM-EXE.
- **Neue native Characterization:** `tests/Test-RefreshRuntime.ps1` prüft unter Windows PowerShell 5.1 den Refresh-State-/Request-Vertrag mit 18 Checks und wird vom bestehenden `Test-WindowsPowerShell51.ps1` mit ausgeführt.

**Native Prüfung erforderlich:** Appstart/Popup-first, mehrere Refreshs, schneller Popup-Open während laufendem Refresh, Storage-Eskalation, BootNext/Default-Regression, UI-Regressionen und Diagnoseexport. Der Testwrapper muss zusätzlich `REFRESH TOTAL 18/18` melden.


## Neu in v0.4.2.2 – robuster Singleton-Mutex

v0.4.2.2 ist ein gezielter Stabilitäts-Patch auf Basis von v0.4.2.1. Anlass war ein nativer Startbefund: Die App meldete „läuft bereits“, obwohl anschließend weder ein passender Prozess noch der benannte Mutex vorhanden war. Boot-, Firmware-, TaskBroker- und Haupt-UI-Logik bleiben unverändert.

Änderungen:

- **Tatsächlicher Besitz statt `createdNew`:** Der Tray-Singleton verwendet den benannten Mutex `Local\LenovoBootMenuTray` weiterhin, entscheidet aber jetzt über `WaitOne(...)`, ob der aktuelle Prozess den Mutex tatsächlich besitzt. Ein bereits existierendes, aber freies Kernelobjekt wird nicht mehr automatisch als laufende App gewertet.
- **Schneller Erststart bleibt unverändert:** Der normale Erststart versucht `WaitOne(0, $false)` und erhält den Mutex ohne zusätzliche Wartezeit. Nur ein konkurrierender Start bekommt einen einmaligen 500-ms-Grace-Retry, damit ein gerade beendender Prozess sauber freigeben kann.
- **Abandoned-Recovery:** `AbandonedMutexException` wird explizit als übernommener Mutex-Besitz behandelt. Eine abgestürzte/früh beendete Altinstanz blockiert damit keinen Folgestart.
- **Sauberer Ownership-Cleanup:** `ReleaseMutex()` wird nur noch ausgeführt, wenn dieser Prozess den Mutex tatsächlich besitzt; Dispose bleibt best-effort.
- **Diagnose:** Erfolgreicher Besitz wird als `SINGLE_INSTANCE_MUTEX_ACQUIRED` dokumentiert; eine Übernahme nach Abbruch als `SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED`.
- **Nativer Mutex-Test:** `tests/Test-SingleInstanceMutex.ps1` prüft unter Windows PowerShell 5.1 einen aktiven Fremdbesitzer, Freigabe/Übernahme und abandoned recovery mit eindeutigem temporärem Mutexnamen. `Test-WindowsPowerShell51.ps1` führt diesen Test nach Parser- und Functional-Core-Gate automatisch aus.
- **v0.4.2.1-Patches bleiben erhalten:** eigener Startfehlerdialog ohne Taskleisten-Eintrag und die UTF-8-BOM-Regel für nicht-ASCII-PowerShell-Sources bleiben unverändert.

**Native Prüfung erforderlich:** `tests\Test-WindowsPowerShell51.ps1` ausführen, normalen Erststart prüfen, anschließend echten Doppelstart prüfen und sicherstellen, dass nur der zweite Start mit „läuft bereits“ abgewiesen wird. Danach Tray beenden und unmittelbar neu starten; der Neustart muss ohne False Positive funktionieren.


## Neu in v0.4.2.1 – eigener Startfehlerdialog und PS5.1-Encoding-Fix

v0.4.2.1 ist ein gezielter UX-/Kompatibilitäts-Patch auf Basis von v0.4.2. Die TaskBroker-/Boot-Service-Architektur, Bootlogik und Privilege-Grenzen bleiben unverändert.

Änderungen:

- **Eigener Startfehlerdialog:** Die ungebundene Standard-`MessageBox` wurde durch einen kompakten WinForms-Recovery-Dialog im Lenovo-Boot-Selector-Stil ersetzt. Er zeigt keinen eigenen Taskleisten-Eintrag (`ShowInTaskbar = $false`) und verwendet Lenovo-Rot nur als Akzent.
- **Klare Recovery-Aktionen:** Bei einem echten Fatal-Startfehler stehen `Erneut starten`, `Diagnose öffnen` und `Schließen` bereit. Der Neustart erfolgt erst nach Freigabe des Tray-Mutex über den bestehenden versteckten VBS-Launcher. Bei einer bereits laufenden Instanz ist `Erneut starten` deaktiviert.
- **Taskleisten-Fallback abgesichert:** Falls der eigene Dialog nicht erstellt werden kann, wird die native MessageBox nur an einen unsichtbaren Owner mit `ShowInTaskbar = $false` gebunden.
- **PS5.1-Encoding-Fix:** Modulare PowerShell-Sources mit Nicht-ASCII-Inhalt werden als UTF-8 mit BOM ausgeliefert. Dadurch bleibt `Lenovo Boot-Menü` beim direkten Dot-Sourcing unter Windows PowerShell 5.1 korrekt.
- **Windows-Gate erweitert:** `tests/Test-WindowsPowerShell51.ps1` prüft zusätzlich die Encoding-Regel für `.ps1`-Dateien mit Nicht-ASCII-Inhalt und führt weiterhin den Functional-Core-Test aus.
- **Keine Boot-/Security-Änderung:** Keine Änderung an festen SYSTEM-Tasks, TaskBroker-Schema 0.2.12, GUID-Allowlist, `{fwbootmgr}`-`bootsequence`, Default-Logik, Cleanup oder Popup-first.

**Native Prüfung erforderlich:** Startfehlerdialog auf dem Ziel-PC provozieren bzw. über den dedizierten Testpfad prüfen: kein PowerShell-Symbol in der Taskleiste, Dialog im App-Stil, `Diagnose öffnen`, `Schließen` und `Erneut starten` korrekt. Zusätzlich `tests\Test-WindowsPowerShell51.ps1` nativ ausführen.


## Neu in v0.4.2 – explizite TaskBroker-/Boot-Service-Grenze

v0.4.2 ist der zweite behavior-preserving Refactoring-Build der 0.4.x-Reihe. Die in v0.4.1 nativ vollständig bestätigte Runtime dient als Basis; es werden weiterhin keine geparkten v0.3.5-/v0.3.6-Funktionen umgesetzt.

Änderungen:

- **Historische `Invoke-BcdEdit`-Pseudo-API entfernt:** Die Tray-Runtime besitzt keine generische BCDEdit-Kompatibilitätsschicht mehr. Read-only Firmwarezugriffe, BootNext und systemweites Standardziel verwenden klar benannte Operationen.
- **Infrastructure-Modul eingeführt:** `src/Infrastructure/TaskBroker.ps1` kapselt TaskBroker-Metadaten, exakten Scheduled-Task-Start, Cache-/Statusdateien und die festen Brokeroperationen. Der generische interne Task-Starter wird außerhalb dieses Moduls nicht mehr direkt aufgerufen.
- **Explizite Brokeroperationen:** `Get-TaskBrokerFirmwareManagerText`, `Get-TaskBrokerFirmwareEntriesText`, `Get-TaskBrokerDefaultTargetGuid`, `Set-TaskBrokerBootNextTarget`, `Set-TaskBrokerDefaultTarget` und `Clear-TaskBrokerDefaultTarget` bilden die erlaubten fachlichen Brokerzugriffe ab.
- **Application-Boot-Service eingeführt:** `src/Application/BootService.ps1` liest Firmwaredaten über die Infrastructure-Grenze, delegiert Textparsing an den Functional Core und verifiziert BootNext nach dem Schreiben durch Read-back der `bootsequence`.
- **BootNext-Begriff präzisiert:** Der UI/Shell-Pfad heißt nun `Set-BootNextTarget`; die historische Funktion `Set-BootSequence` entfällt. Das tatsächliche privilegierte Verhalten bleibt unverändert: ausschließlich der vorinstallierte, GUID-gebundene SYSTEM-Task darf `{fwbootmgr}` `bootsequence` setzen.
- **Default-Set/Clear entkoppelt:** `Set-DefaultGuid` kennt keine Tasknamen mehr und ruft nur noch die expliziten Brokeroperationen auf. Ziel-GUIDs werden weiterhin ausschließlich gegen die installierten TaskBroker-Metadaten aufgelöst.
- **Background-Refresh entkoppelt:** Der Worker nutzt die expliziten read-only Brokeroperationen; das Hauptfenster synchronisiert Cache-Dateien über einen Infrastructure-Adapter. Popup-first bleibt unverändert.
- **Kein Privilege-Surface-Wachstum:** Keine freie Command-, Argument-, Taskname- oder GUID-Schnittstelle wurde eingeführt; `Invoke-AuthorizedTask` bleibt ein interner Infrastructure-Mechanismus. Installer/Uninstaller, Taskdefinitionen, ACLs und TaskBroker-Schema **0.2.12** bleiben byteidentisch.
- **PS5.1-Testfinding behoben:** Die drei unter Windows gefundenen mehrdeutigen `$Name:`-Interpolationen in `tests/Test-FunctionalCore.ps1` sind mit `${Name}:` korrigiert. `tests/Test-WindowsPowerShell51.ps1` parst künftig alle ausgelieferten `.ps1`-Quellen nativ mit dem Windows-PowerShell-Parser und führt anschließend den Functional-Core-Test aus.
- **Geschlossene UI-Pfade unverändert:** Vollbreiten-Hover/Selected, rote Separatoren und Auge-/Stift-Tooltips werden nicht funktional verändert.

**Native Prüfung:** v0.4.1 wurde vollständig nativ GREEN bestätigt (S01 24/24, S02–S16 UI sauber, S17 Diagnose ohne Runtime-Fehler). v0.4.2 verändert interne Broker-/Boot-Service-Aufrufe und benötigt deshalb einen gezielten Windows-Smoke für Firmware-Read/Refresh, BootNext-Read-back, Default-Set/Clear sowie die geschlossenen UI-Regressionspfade.


## Neu in v0.4.1 – Functional Core

v0.4.1 ist der erste behavior-preserving Refactoring-Build der 0.4.x-Reihe. Die bisherige Single-File-Runtime bleibt für Deployment und Startup erhalten, wird aber nun **deterministisch aus modularen Source-Dateien erzeugt**. Es gibt keine beabsichtigte Funktions-, UX-, Sicherheits- oder Privilege-Änderung.

Änderungen:

- **Functional Core eingeführt:** `src/Core/EntryPreferences.ps1`, `src/Core/FirmwareParsing.ps1` und `src/Core/BootTargetModel.ps1` enthalten deterministische Logik ohne globalen Script-State, WinForms, Dateisystem, Registry, Scheduled Tasks, Prozessstarts oder privilegierten Brokerzugriff.
- **Settings normalisiert:** `Get-AppSettings` bleibt IO-Shell und delegiert Default-/Normalisierungslogik an den Core. Schema **4** bleibt unverändert.
- **Entry-Preferences extrahiert:** Alias-Normalisierung, Sequenz-/Map-Vergleich, GUID-Listenprüfung und Sortierung/Sichtbarkeit laufen im Core; `Get-OrderedEntriesForUi` ist nur noch ein dünner State-Adapter.
- **Firmware-Textparser extrahiert:** GUID-, Firmware-Entry-, `displayorder`- und `bootsequence`-Parsing liegen im Core. `Get-FirmwareBootState` behält ausschließlich Cache/TaskBroker/Storage-Orchestrierung.
- **Friendly-Bootzielmodell presentation-neutral:** Die Klassifikation erzeugt ein `AccentRole`-Token; erst die UI-Shell ordnet dieses Token den bestehenden `Drawing.Color`-Werten zu. Nutzertexte und USB-Heuristik bleiben unverändert.
- **Deterministischer Single-File-Build:** `src/App/LenovoBootMenuTray.template.ps1` plus die Core-Module werden durch `tools/build_runtime.py` bytegenau zu `LenovoBootMenuTray.ps1` gebündelt. Das Release bleibt flach und benötigt zur Laufzeit keine zusätzlichen Module.
- **Regression-Gates erweitert:** Alle nicht absichtlich refaktorierten v0.3.4/v0.4.0-Critical-Fragments bleiben SHA-256-identisch. Für die drei bewusst geänderten Shell-Funktionen existieren neue Core-/Boundary-Gates.
- **Sicherheitsarchitektur unverändert:** Tray uneleviert; feste allowgelistete SYSTEM-Scheduled-Tasks; keine freien Commands/Argumente/GUIDs; nur `{fwbootmgr}` `bootsequence`; keine permanente `displayorder`; keine Custom-SYSTEM-EXE; begrenzter Cleanup.
- **Popup-first und geschlossene UI-Pfade unverändert:** Vollbreiten-Hover/Selected, rote Separatoren, Auge-/Stift-Tooltips sowie Background-Worker-Reihenfolge werden nicht verändert.
- **Geparkte Funktionen bleiben geparkt:** Die ehemals geplanten v0.3.5-/v0.3.6-Funktionen sind nicht Bestandteil von v0.4.1.

**Native Prüfung:** Die Linux-Buildumgebung kann Windows PowerShell 5.1, WinForms, Task Scheduler und UEFI nicht ausführen. Weil v0.4.1 erstmals produktive interne Struktur verändert, ist vor dem nächsten Refactoring ein kurzer Windows-Smoke sinnvoll: Appstart, Popup-first, Bootzielliste/Bezeichnungen, Alias/Sichtbarkeit/Reihenfolge, Refresh sowie die bereits geschlossenen Hover-/Separator-/Tooltip-Pfade. Task-/ACL-Code wurde nicht geändert.


## Neu in v0.3.4 – Vollbreiten-Hover über die tatsächliche DropDown-Clientfläche

v0.3.4 ist ein isolierter WinForms-Hotfix auf Basis von v0.3.3. Die native Prüfung von v0.3.3 bestätigte, dass Hover-Funktion und rote Separatoren wiederhergestellt waren, rechts aber weiterhin ein schmaler dunkler Restbereich stehen blieb. Ursache: Der Auswahlhintergrund wurde weiterhin im per-Item-Renderer gezeichnet. WinForms beschränkt diesen Graphics-Kontext auf den Item-/Contentbereich; der systemintern reservierte rechte Padding-/Grip-Bereich des DropDowns konnte damit trotz rechnerisch größerem Rechteck nicht zuverlässig übermalt werden.

Änderungen:

- **Selection-Paint auf die echte DropDown-Fläche verlagert:** Der Hover-/Selected-Hintergrund wird jetzt in `OnRenderToolStripBackground(...)` gezeichnet. Dieser Renderer arbeitet auf der vollständigen `ToolStripDropDown.ClientRectangle`-Fläche und kann daher auch den zuvor ausgesparten rechten Restbereich abdecken.
- **Exakte Vollbreite:** Root-Menüs nutzen die komplette `ClientRectangle`-Breite. Untermenüs lassen nur ihre bestehende neutrale 1-px-Kante frei.
- **Deterministische Hover-Ermittlung bleibt erhalten:** `GetVisualHotItem(...)` verwendet weiterhin aktuelle Mausposition plus Zeilen-Hit-Test; bei Tastaturnavigation bzw. geöffnetem Untermenü bleibt `Selected`/`Pressed` der Fallback.
- **Item-Renderer zeichnet keinen Auswahlhintergrund mehr:** `OnRenderMenuItemBackground(...)` bleibt ausschließlich für Häkchen und Untermenü-Pfeile zuständig. Dadurch kann keine item-lokale Clip-Grenze den Vollbreiten-Hintergrund erneut beschneiden.
- **Separatoren unverändert:** Der in v0.3.3 korrigierte lokale Separator-Paint (`Item.Height / 2`) bleibt unverändert.
- **Keine neue Timing-Logik:** Kein `PaintSelectionTail`, kein Timer, kein verzögertes `BeginInvoke`; die bestehenden synchronen Full-Invalidates bleiben bestehen.
- **Keine Sicherheitsänderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. BootNext-, Default-, Runtime-Diagnose-, Allowlist-, ACL-, Cleanup- und Neustartsemantik bleiben unverändert.

**Native Prüfung erforderlich:** Tray-Kontextmenü, `Wartung` und `Standard-Startziel` mehrfach öffnen und jede Zeile langsam/schnell bis ganz an den rechten Rand hovern. Die Hervorhebung muss ohne dunklen Reststreifen bis zur tatsächlichen rechten Clientkante reichen; rote Separatoren, Häkchen und Pfeile müssen unverändert korrekt bleiben.

## Neu in v0.3.3 – ToolStrip-Koordinatenfix für Hover und Separatoren

v0.3.3 ist ein isolierter nativer WinForms-Renderer-Hotfix auf Basis von v0.3.2. v0.3.2 hatte die Hover-Erkennung zwar deterministisch gemacht, dabei aber die Koordinatensysteme der per-Item-Renderer falsch behandelt: `item.Bounds.Top` wurde in einem bereits item-lokalen Graphics-Kontext erneut addiert. Dadurch war der Hover praktisch nur in der ersten Zeile sichtbar; auch die roten Separatoren wurden vertikal außerhalb ihrer Items gezeichnet.

Änderungen:

- **Item-lokaler Hover-Paint:** `FullRowBounds(...)` beginnt vertikal immer bei `Y = 0`. Die DropDown-Clientkanten werden nur horizontal in das lokale Item-Koordinatensystem übersetzt.
- **Vollbreite bleibt erhalten:** Der Auswahlhintergrund reicht weiterhin bis zum realen DropDown-Clientrand; ein separates Tail-Paint, Timer oder verzögertes `BeginInvoke` wird nicht wieder eingeführt.
- **Rote Separatoren wieder sichtbar:** `OnRenderSeparator(...)` zeichnet die Linie bei `Item.Height / 2` im lokalen Separator-Koordinatensystem. Auch hier werden nur die horizontalen Clientkanten übersetzt.
- **Häkchen und Untermenü-Pfeile korrigiert:** Beide verwenden dasselbe lokale Vollzeilen-Rechteck wie der Hover-Hintergrund.
- **Hover-Erkennung unverändert deterministisch:** Aktuelle Mausposition plus Zeilen-Hit-Test bleiben maßgeblich; `Selected`/`Pressed` bleibt nur der Fallback für Tastatur bzw. geöffnetes Untermenü.
- **Keine Sicherheitsänderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. BootNext-, Default-, Runtime-Diagnose-, Allowlist-, ACL-, Cleanup- und Neustartsemantik bleiben unverändert.

**Native Prüfung erforderlich:** Im Tray-Kontextmenü, im `Wartung`-Untermenü und im `Standard-Startziel`-DropDown jede Zeile mehrfach langsam und schnell hovern. Jede Zeile muss vollständig hervorgehoben werden; die roten horizontalen Separatoren müssen durchgehend sichtbar sein.

## Neu in v0.3.2 – deterministischer Vollbreiten-Hover in DropDown-Menüs

v0.3.2 ist ein gezielter nativer WinForms-Hotfix auf Basis von v0.3.1. Die in v0.3.1 korrigierten Auge-/Stift-Tooltips und der Diagnose-Explorerpfad bleiben unverändert. BootNext-, TaskBroker-, Default-, Diagnose-, Cleanup-, Privilege- und Settings-Architektur bleiben funktional unverändert.

Änderungen:

- **Hover-Race entfernt:** Die Hover-/Selected-Fläche hängt nicht mehr davon ab, ob `ToolStripMenuItem.Selected` genau während eines bestimmten Paint-Zyklus bereits aktualisiert wurde.
- **Ein kontrollierter Paint-Pfad:** `LenovoMenuRenderer.OnRenderMenuItemBackground` ermittelt die aktuell getroffene Zeile direkt aus der Mausposition und zeichnet die komplette Zeile in Owner-Koordinaten bis zum tatsächlichen DropDown-Clientrand.
- **Rechte Restfläche nicht mehr separat nachgemalt:** Der v0.3.1-Workaround `PaintSelectionTail(...)` wurde vollständig entfernt. Ebenso entfällt der verzögerte `BeginInvoke`-/`QueueFullInvalidate`-Pfad.
- **Sofortiges Full-Repaint:** Die beiden eigenen DropDown-Klassen invalidieren bei Mausbewegung die gesamte kleine Menüfläche synchron. Dadurch gibt es keinen zeitversetzten zweiten Paint-Schritt mehr.
- **Häkchen und Untermenü-Pfeile im selben Item-Pass:** Rechte Statusindikatoren werden gemeinsam mit der Vollbreitenzeile gezeichnet und können nicht mehr von einem späteren Tail-Fill übermalt werden.
- **Keyboard-/Submenu-Verhalten bleibt erhalten:** Befindet sich die Maus außerhalb des jeweiligen Menüs, wird für Tastaturnavigation bzw. ein geöffnetes Kind-Untermenü weiterhin auf den nativen `Selected`-/`Pressed`-Zustand zurückgefallen.
- **Keine Sicherheitsänderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Keine Änderung an privilegierten Tasks, Allowlist, `{fwbootmgr}`-`bootsequence`, `displayorder`, ACLs, Cleanup oder Neustartsemantik.

**Native Prüfung erforderlich:** Tray-Kontextmenü, `Wartung` und `Standard-Startziel` mehrfach öffnen und mit der Maus langsam sowie schnell über alle Zeilen bewegen. Die Hoverfläche muss in jedem Zyklus ohne dunklen rechten Reststreifen bis zum vorgesehenen Clientrand reichen.


## Neu in v0.3.1 – Tooltip-Fokusfix, vollständig durchgezogener DropDown-Hover und Diagnose-Datei anzeigen

v0.3.1 ist ein gezielter Hotfix-/UX-Build auf Basis von v0.3.0. Die Runtime-Diagnose aus v0.3.0 bleibt erhalten; BootNext-, TaskBroker-, Default-, Cleanup-, Privilege- und Settings-Architektur bleiben funktional unverändert.

Änderungen:

- **Auge/Stift schließen die UI nicht mehr:** Der in v0.2.35 eingeführte separate `LenovoDarkToolTipForm` wurde vollständig aus diesem Pfad entfernt. Auge und Stift verwenden jetzt einen owner-drawn `System.Windows.Forms.ToolTip`. Damit wird kein eigenes App-`Form` mehr geöffnet, das das Hauptfenster deaktivieren und dadurch dessen `Deactivate → Hide`-Logik auslösen könnte.
- **Dunkler Tooltip-Stil bleibt erhalten:** Die Tooltips bleiben eckig, dunkel, kompakt und verwenden weiterhin `Sichtbar – klicken zum Ausblenden`, `Verborgen – klicken zum Einblenden` sowie `Anzeigename ändern`. Die Position wird weiterhin bildschirmbewusst rechts bzw. bei Platzmangel links des Symbols gewählt.
- **DropDown-Hover bis zum echten rechten Clientrand:** Zusätzlich zum bestehenden Full-Row-Renderer zeichnen `LenovoContextMenuStrip` und `LenovoDropDownMenu` nach dem normalen WinForms-Painting einen eventuell verbleibenden rechten Selection-Tail nach. Dadurch wird auch der von WinForms trotz gestreckter Item-Bounds zurückbehaltene Restbereich gefüllt. Die neutrale 1-px-Untermenükante bleibt ausgespart.
- **Diagnose-ZIP direkt finden:** Der Erfolgsdialog `Diagnose gespeichert` besitzt neben `OK` jetzt **`Im Ordner anzeigen`**. Die Aktion öffnet den Windows-Explorer mit `/select,"<Diagnose-ZIP>"`, sodass das gerade erzeugte Paket direkt markiert wird. Der sichtbare Speicherpfad bleibt bestehen.
- **Diagnose der neuen Aktion:** Erfolg bzw. Fehlschlag des Explorer-Aufrufs wird als `DIAGNOSTIC_REVEAL` best-effort in der laufenden Runtime-Diagnose protokolliert. Ein Fehlschlag blockiert die App nicht.
- **Keine Sicherheitsänderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Es gibt keine neue privilegierte Schnittstelle, keine freien GUIDs/Argumente und keine Änderung an `{fwbootmgr}`-`bootsequence`, Allowlist, Task-ACLs, Cleanup oder Neustartsemantik.

**Native Prüfung erforderlich:** Auf dem Ziel-PC müssen Auge/Stift mehrfach gehovert werden, ohne dass das Hauptfenster verschwindet. Root-, `Wartung`- und `Standard-Startziel`-DropDowns sind auf eine lückenlose Hover-/Selected-Fläche bis zur rechten Kante zu prüfen. Beim Diagnoseexport muss `Im Ordner anzeigen` den Explorer öffnen und genau das erzeugte ZIP markieren.


## Neu in v0.3.0 – vollständige Runtime-Diagnose

v0.3.0 setzt Phase 1 des technischen Build-Plans nach v0.2.35 um. Schwerpunkt ist eine durchgängige, rein beobachtende Runtime-Diagnose, damit technische Ursachen nachvollziehbar bleiben, während die sichtbare UI weiterhin endbenutzerfreundliche Meldungen zeigt. Die BootNext-, TaskBroker-, Default-, Cleanup-, Privilege- und Settings-Architektur bleibt funktional unverändert.

Änderungen:

- **Eine Diagnose-Session pro Appstart:** Jeder normale Tray-Start erhält eine zufällige `sessionId`. Der versteckte Hintergrund-Refresh übernimmt dieselbe Session-ID, sodass UI- und Worker-Ereignisse in einer gemeinsamen chronologischen `runtime.jsonl`-Sitzung landen.
- **Strukturierte append-only Events:** Runtime-Ereignisse enthalten UTC-Zeit, Session, Appversion, Prozessrolle, Event/Stage, Erfolg, Laufzeit und bei Fehlern Fehlerklasse/-text. Diagnose-Schreibfehler werden vollständig geschluckt und dürfen keine App-/Bootaktion blockieren.
- **Abgedeckte Pfade:** BootNext setzen, Standard-Startziel setzen/löschen, autorisierte Scheduled Tasks, TaskBroker-Ready-Prüfung, Manager-/Firmware-Refresh, Background-Refresh inklusive Phase-Timings, Storage-/USB-Auflösung, Autostart, Einrichtung/Reparatur, Cleanup, Neustart sowie UI-/Unhandled-/Fatal-Exceptions.
- **Background-Timings persistiert:** Die bereits seit v0.2.26 gemessenen Zeiten `ReadyMs`, `ManagerMs`, `FirmwareMs`, `StorageMs` und `TotalMs` werden nun zusätzlich in der Runtime-Diagnose festgehalten.
- **Wartung → Diagnose speichern…:** Im Wartungs-Untermenü kann jederzeit ein kompaktes Diagnose-ZIP der **aktuellen Session** erzeugt werden.
- **Diagnosepaket bewusst klein:** Enthalten sind `runtime.jsonl`, `environment.json`, `task-broker-summary.json` und `summary.txt`. Historische Runtime-Sessions, `settings.json` und Benutzerdateien werden nicht mit exportiert.
- **Datensparsamkeit:** Broker-`userSid`, Benutzername und Rechnername werden nicht in das Runtime-Diagnosepaket geschrieben. Technische Fehltexte werden best-effort um `%LOCALAPPDATA%`, `%USERPROFILE%`, Benutzer- und Rechnernamen bereinigt.
- **30-Tage-Retention:** Alte Runtime-Session-Verzeichnisse werden best-effort nach 30 Tagen entfernt. Diese Bereinigung kann keine Appfunktion blockieren.
- **Fehlerhaken:** WinForms-Thread-Exceptions, AppDomain-Unhandled-Exceptions und der äußere Fatal-Pfad schreiben strukturierte Diagnoseevents, sofern die Diagnose-Session bereits verfügbar ist.
- **Keine Privilege-Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Installer/Uninstaller, feste Tasknamen, Task-ACLs, Allowlist, `{fwbootmgr}`-`bootsequence` und `shutdown.exe /r /t 0` sind gegenüber v0.2.35 unverändert.

**Native Prüfung erforderlich:** In der Linux-Buildumgebung stehen Windows PowerShell 5.1, Task Scheduler, WinForms und UEFI nicht zur Verfügung. Auf dem Ziel-PC sind insbesondere ein erfolgreicher/fehlgeschlagener BootNext-Lauf, Background-Refresh, Autostartänderung, Setup/Repair-Fehler und der Export über `Wartung → Diagnose speichern…` zu prüfen. Das exportierte ZIP muss ausschließlich die aktuelle Session und die vier dokumentierten Dateien enthalten.


## Neu in v0.2.35 – konsistente Tooltips und vollbreite DropDown-Interaktion

v0.2.35 ist ein gezielter UI-/UX-Qualitätspass auf Basis von v0.2.34. Die BootNext-, TaskBroker-, Default-, Cleanup-, Anzeigenamen- und Hintergrund-Refresh-Architektur bleibt unverändert.

Änderungen:

- **Eigene dunkle Tooltips für Sichtbarkeit:** Die Augen im Modus `STARTZIELE ANPASSEN` verwenden keine hellen nativen Windows-Tooltips mehr. Stattdessen erscheint ein eckiger dunkler App-Tooltip mit dezenter Neutral-Kante und automatischer Links-/Rechts-Positionierung innerhalb des aktuellen Arbeitsbereichs.
- **Kürzere Sichtbarkeits-Texte:** Offenes Auge: `Sichtbar – klicken zum Ausblenden`; durchgestrichenes Auge: `Verborgen – klicken zum Einblenden`.
- **Stift erklärt seine Funktion:** Der Stift besitzt nun im selben dunklen Tooltip-Stil den Hinweis `Anzeigename ändern`.
- **Boot-Menü-Subtext im Anpassungsmodus:** Beim unveränderten Eintrag `Lenovo Boot-Menü` lautet der beschreibende Subtext jetzt `Auswahlmenü für das nächste Startziel`. Einträge mit gesetztem Anzeigenamen zeigen weiterhin `Originalname: …`.
- **DropDown-Breitenvertrag verstärkt:** Root-Kontextmenü, `Standard-Startziel` und `Wartung` verwenden nun eigene ToolStripDropDown-Klassen mit einer echten Mindestbreite auf Preferred-Size-Ebene. Nach jeder nativen Layoutphase werden alle Items auf die komplette nutzbare Clientbreite gestreckt, sodass Hit-Test-, Hover-, Selected-, Check- und Pfeilzone dieselbe reale Zeilenbreite besitzen.
- **Hover-Repaint nach nativer Selection:** Eine asynchrone Vollflächen-Invalidierung nach Mausbewegungen stellt sicher, dass der owner-basierte Hover/Selected-Hintergrund erst nach der internen WinForms-Selection aktualisiert wird. Dadurch soll kein dunkler Reststreifen rechts mehr verbleiben.
- **Wartungs-Untermenü nutzt denselben Vertrag:** Das Wartungsmenü erhält explizit das gleiche vollbreite DropDown-Layout wie Root- und Standardziel-Menü; die bestehende neutrale Submenu-Kante bleibt erhalten.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Firmware-GUIDs, BootNext-Ziele, Tasknamen, Allowlist, Standard-Startziel, Cleanup-Grenzen und unelevierte App-Semantik bleiben unverändert.

**Native Prüfung erforderlich:** Auf dem Ziel-PC sind besonders die vollständige Hover-/Selected-Breite in Root-/Wartungs-/Standardziel-Menüs, Hit-Testing bis an den rechten Rand sowie Position, Lesbarkeit und Nicht-Fokussierung der neuen dunklen Tooltips zu prüfen.


## Neu in v0.2.34 – Sichtbarkeits-Tooltips und roter Einstellungs-Separator

v0.2.34 ist ein kleiner UI-/UX-Qualitätspass auf Basis von v0.2.33. Die BootNext-, TaskBroker-, Default-, Cleanup-, Anzeigenamen- und Hintergrund-Refresh-Architektur bleibt unverändert.

Änderungen:

- **Sichtbarkeits-Auge erklärt Zustand und Aktion:** Das offene Auge zeigt nun den Tooltip **`In der Standardansicht sichtbar – klicken zum Ausblenden`**. Das durchgestrichene Auge zeigt **`In der Standardansicht verborgen – klicken zum Einblenden`**.
- **Robuster Tooltip-Fallback:** Zusätzlich zum normalen WinForms-`ToolTip.SetToolTip(...)` besitzt das owner-drawn Sichtbarkeitssymbol einen expliziten `MouseHover`-/`MouseLeave`-Pfad. Damit entspricht die Zuverlässigkeit dem bereits bewährten Fallback der farbigen Bootziel-Marker.
- **Rote Trennlinie vor dem Neustartbereich:** Die horizontale Linie zwischen **Einstellungen** und **Windows neu starten** verwendet jetzt Lenovo-Rot statt Neutralgrau.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Firmware-GUIDs, BootNext-Ziele, Tasknamen, Allowlist, Standard-Startziel, Cleanup-Grenzen und unelevierte App-Semantik bleiben unverändert.

**Native Prüfung erforderlich:** Auf dem Ziel-PC sind insbesondere die Tooltips des offenen/durchgestrichenen Auges sowie die rote Trennlinie zwischen Einstellungen und Neustartbereich visuell zu prüfen.


## Neu in v0.2.33 – großer UI-/UX-Qualitätspass für Endanwender

v0.2.33 ist ein umfassender Qualitäts-Build auf Basis von v0.2.32. Ziel ist eine deutlich konsistentere, verständlichere Endanwenderoberfläche ohne unnötige technische Begriffe. Die BootNext-, TaskBroker-, Default-, Cleanup-, Alias-Persistenz- und Hintergrund-Refresh-Architektur bleibt unverändert.

Änderungen:

- **Endanwender-Vokabular vereinheitlicht:** Die sichtbare UI spricht konsequent von `Startziel`, `Standard-Startziel`, `Einstellungen`, `Anzeigename` und `Systemfunktionen`. Technische Implementierungsbegriffe wie privilegierte Aufgaben, TaskBroker, Default-Restore, Scheduled Tasks, HKCU und ExitCodes werden aus den normalen Dialogen und Menüs entfernt.
- **Verwaltungsmodus verständlicher:** `VERWALTEN` heißt jetzt **`ANPASSEN`**, `EINTRÄGE VERWALTEN` wird zu **`STARTZIELE ANPASSEN`**. Der Abschnitt `KONFIGURATION` heißt **`EINSTELLUNGEN`**.
- **Sichtbarkeit als Symbol statt AN/AUS:** An der bisherigen AN/AUS-Position wird jetzt ein Auge gezeichnet. Offenes Auge = in der Standardansicht sichtbar, durchgestrichenes Auge = verborgen. Verborgene Zeilen bleiben zusätzlich gedimmt. Ein Tooltip erklärt den Zustand.
- **Alias wird zum Anzeigenamen:** Die sichtbare UI verwendet **`Anzeigename`** bzw. `Umbenennen` statt Alias. `Originalname:` und `Leer lassen = Originalname` erklären die Semantik klarer. Die technische Settings-Struktur `entryAliases` bleibt aus Kompatibilitätsgründen unverändert.
- **Standardziel klarer:** `Kein Standard` heißt **`Kein Standardziel`**. In der Neustartzeile wird **`Nächstes Ziel: …`** angezeigt; der technische Begriff `Firmware-Standardreihenfolge` ist als **`Standardreihenfolge`** vereinfacht.
- **Bootzieltexte vereinfacht:** Tooltips und Untertitel vermeiden unnötige Begriffe wie NVMe/PCIe, PXE, Firmware-Bootauswahl oder On-Premise, sofern sie für die Entscheidung nicht nötig sind. Beispiele: `Interne SSD`, `Netzwerkstart`, `Wiederherstellung über das Netzwerk`, `Start über das Firmennetzwerk`.
- **Marker-Tooltips verkürzt:** Statt technischer Erklärsätze stehen kompakte Bedeutungen wie `Rot: Lenovo Boot-Menü`, `Gelb: USB-Laufwerk`, `Blau: interne SSD`, `Violett: Netzwerkstart` und `Grau: weiteres Startziel`.
- **Wartung verständlicher:** Die Menüpunkte heißen jetzt **`Systemfunktionen einrichten/reparieren…`** und **`Systemfunktionen entfernen…`**. Interne Task-/Broker-Begriffe werden nicht mehr im Menü gezeigt.
- **Eigene Wartungsdialoge im App-Stil:** Einrichtung, Reparatur/Migration und Entfernen verwenden keine hellen Windows-MessageBoxes mehr, sondern eckige dunkle Lenovo-Boot-Selector-Dialoge mit roter Akzentlinie und klarer Primär-/Sekundäraktion. Die Texte erklären Konsequenzen statt Implementierungsdetails.
- **Fehlertexte endanwenderfreundlicher:** Häufige interaktive Fehler zeigen keine rohen Exception-, Task-, Pfad- oder ExitCode-Texte mehr. Stattdessen nennt die UI die fehlgeschlagene Aktion und einen verständlichen nächsten Schritt. Technische Details bleiben in bestehenden Diagnosepfaden.
- **Tray-Menütext:** `Bootauswahl öffnen` heißt nun **`Boot Selector öffnen`**. Der Tray-Tooltip lautet kompakt **`Lenovo Boot Selector – Startziel wählen`**.
- **Refresh-Hilfe:** Das Reload-Symbol besitzt den Tooltip **`Startziele aktualisieren`**.
- **Neustartdialog gestrafft:** Die Zielüberschrift lautet `NÄCHSTES ZIEL`; der redundante Satz `Dieses Ziel wird beim Neustart verwendet.` entfällt.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Firmware-GUIDs, BootNext-Ziele, Tasknamen, Allowlist, Default-State, Cleanup-Grenzen und unelevierte App-Semantik bleiben unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1 und WinForms nicht ausführen. Auf dem Ziel-PC sind besonders die neuen dunklen Systemfunktionen-Dialoge, das Augen-Symbol für Sichtbarkeit, alle überarbeiteten Texte/Tooltips sowie die bestehenden Menü-/Hover-/Alias-/Restart-Regressionspfade zu prüfen.



## Neu in v0.2.32 – robuste Vollbreiten-Menüs und aufgeräumter Verwaltungsfooter

v0.2.32 ist ein UI-/UX-Korrekturpass auf Basis von v0.2.31. Die BootNext-, TaskBroker-, Default-, Cleanup-, Alias- und Hintergrund-Refresh-Architektur bleibt unverändert.

Änderungen:

- **Menü-Hover/Selection zentral neu gerendert:** Der gemeinsame `LenovoMenuRenderer` zeichnet Hover-/Pressed-Flächen nicht mehr innerhalb der nativen, content-basierten `ToolStripItem`-Paintfläche. Stattdessen werden die vollständigen Zeilenflächen direkt im `ToolStripDropDown`-Ownerkoordinatensystem aus dessen `ClientSize` gezeichnet. Dadurch ist die Interaktionsfläche unabhängig von `MinimumSize`, Textbreite und WinForms-Item-Clipping.
- **Rechter Zustand statt linker Checkbox-Gutter:** Checked-Zustände wie **„Mit Windows starten“** und das aktive **Standard-Startziel** werden als rote Checkbox mit weißem Häkchen am rechten Zeilenrand dargestellt. Text bleibt links; es gibt keine überlappende Checkmark-Spalte mehr.
- **Untermenü-Pfeile rechts stabilisiert:** Pfeile für **„Wartung“** und künftige Untermenüs werden ebenfalls owner-basiert in einer festen rechten Zone gezeichnet.
- **Separatoren weiterhin vollbreit:** Rote horizontale Gruppentrenner werden zentral über die reale DropDown-Innenbreite gezeichnet. Das Wartungs-Untermenü behält nur seine dezente neutrale 1-px-Kante, keinen roten Außen-/Top-Border.
- **Keine fragile Item-Stretch-Logik mehr:** Der v0.2.31-Workaround mit `AutoSize = false` und nachträglichem `Item.Size` wurde entfernt. WinForms darf Textgrößen normal berechnen; die sichtbare Hover-/Selected-Fläche ist davon entkoppelt.
- **Versionsnummer nicht mehr abgeschnitten:** Die normale Ansicht besitzt jetzt einen eigenen 20-px-Footer. Die Version wird darin vertikal zentriert und hat garantierten Abstand zur unteren Fensterkante. Im Verwaltungsmodus liegt die Version ebenfalls in einem eigenen Footerbereich.
- **Alias-Feld mit Löschaktion:** Rechts im Alias-Eingabefeld erscheint bei vorhandenem Text ein kleines `×`. Es leert nur den aktuellen Feldinhalt, lässt den Fokus im Feld und speichert noch nichts. `✓ Übernehmen`, `Esc`/`Abbrechen` und das globale Speichern bleiben unverändert.
- **Verwaltungsfooter neu strukturiert:** Die bisherige Überschrift **„Reihenfolge & Sichtbarkeit“** wird durch **„ÄNDERUNGEN“** ersetzt. Die Hinweise sind kompakter: `Ziehen = Reihenfolge · Klick = Ein/Aus · Stift = Alias` sowie `Alias leer = Originalname · Ausgegraut = ausgeblendet`.
- **Buttons horizontal:** `Abbrechen` steht links, **„Änderungen speichern“** rechts als größere Primäraktion.
- **Dirty-State für Speichern:** **„Änderungen speichern“** ist nur aktiv und Lenovo-rot, wenn Reihenfolge, Sichtbarkeit, Alias-Draft oder der aktuell offene Alias-Text tatsächlich vom Ausgangszustand abweichen. Ohne Änderungen bleibt der Button dunkel/deaktiviert.
- **Tray-Menü bleibt gestrafft:** `Aktualisieren` und `Standard-Startziel` bleiben ausschließlich in der Haupt-UI; das Tray-Menü enthält weiterhin nur `Bootauswahl öffnen`, `Mit Windows starten`, `Wartung`, `Windows neu starten` und `Beenden`.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1 und WinForms/ToolStripDropDown nicht ausführen. Auf dem Ziel-PC sind besonders die volle Hover-/Selected-Breite in Root-/Wartungs-/Standardziel-Menüs, die rechtsseitigen Häkchen/Pfeile, der Alias-Clear-Button, Dirty-State des Speichern-Buttons sowie die nicht mehr abgeschnittene Versionsnummer zu prüfen.


## Neu in v0.2.31 – konsistente Menüs und vereinfachtes unteres Drittel

v0.2.31 bündelt die nach dem nativen v0.2.30-Smoke bestätigten Menü-/Layoutprobleme und die gewünschte UX-Überarbeitung des unteren Drittels. BootNext-, TaskBroker-, Default-, Cleanup-, Alias- und Hintergrund-Refresh-Architektur bleiben unverändert.

Änderungen:

- **Tray-Kontextmenü gestrafft:** `Aktualisieren` und `Standard-Startziel` wurden aus dem Tray-Kontextmenü entfernt. Aktualisieren bleibt über den Refresh-Button im Haupt-Popup erreichbar; das Standard-Startziel bleibt im Konfigurationsbereich des Haupt-Popups erreichbar.
- **Gemeinsamer Menübreiten-Fix:** Der Menü-Layoutpfad zwingt alle `ToolStripItem`s nach dem nativen DropDown-Layout auf die tatsächliche nutzbare Clientbreite und wiederholt dies einmal per `BeginInvoke` nach Abschluss der WinForms-Layoutphase. Dadurch sollen Hover-/Selected-Flächen im Hauptmenü, im Wartungs-Untermenü und im Standardziel-Popup bis zur vollständigen nutzbaren Breite reichen.
- **Keine separierte native Check-Margin mehr:** `ShowCheckMargin` und `ShowImageMargin` werden für DropDown-Menüs deaktiviert. Checked-Zustände werden im gemeinsamen Renderer direkt innerhalb der eigentlichen Menüzeile gezeichnet. Die Checkbox ist damit Teil derselben Hover-/Selected-Fläche statt einer optisch separaten linken Gutter-Spalte.
- **Durchgängige rote Separatoren:** Gruppentrenner werden vom Renderer über die komplette nutzbare Menübreite gezeichnet. Im Root-Menü bleiben nur die fachlich sinnvollen Trennungen vor `Windows neu starten` und `Beenden`.
- **Wartungs-Untermenü bereinigt:** Untermenüs bleiben über den etwas helleren Hintergrund und eine dezente neutrale 1-px-Kante als zweite Ebene erkennbar. Der rote Top-/Außenborder wurde entfernt.
- **Unteres Drittel neu strukturiert:** `Mit Windows starten` und `Standard-Startziel` sind nun zwei gleichartig aufgebaute Konfigurationszeilen. Die Beschriftung steht links, der Zustand bzw. aktuelle Wert rechts.
- **Autostart-Status rechts:** Die Checkbox von `Mit Windows starten` sitzt als kompakter Zustand rechts in derselben Zeile; die Zeilenbeschriftung ist separat und ebenfalls klickbar.
- **Standard-Startziel klarer:** Die Zeile heißt jetzt ausdrücklich `Standard-Startziel`; der aktuelle Zielname steht rechts, gefolgt vom Pfeil.
- **Neustart kontextbezogen:** Unter `Windows neu starten` steht direkt das tatsächlich verwendete nächste Ziel, z. B. `mit Lenovo Boot-Menü`.
- **Doppelte Statusinformation entfernt:** Die frühere Footer-Kombination `Nächster Start: …` plus `Die Auswahl gilt nur für den nächsten Start.` entfällt. Die Versionsnummer bleibt sehr dezent am unteren rechten Rand.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. BootNext, systemweiter Default, Alias-Persistenz, eigener Restartdialog, Popup-first-Hintergrundrefresh und privilegierte Scheduled-Task-Grenzen bleiben unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1 und WinForms/ToolStripDropDown nicht ausführen. Auf dem Ziel-PC sind besonders volle Hover-/Selected-Breite in Root- und Wartungsmenü, integrierte Checked-Darstellung, volle Separatorbreite, fehlender roter Submenu-Border sowie das neue untere Drittel zu prüfen.


## Neu in v0.2.30 – zuverlässiger Menü-Hover und flacher Alias-Fokus

v0.2.30 ist ein gezielter UI-Fix auf Basis von v0.2.29. BootNext-, TaskBroker-, Default-, Cleanup-, Alias-Persistenz- und Hintergrund-Refresh-Architektur bleiben unverändert.

Änderungen:

- **Menü-Hover zentral korrigiert:** Der gemeinsame `LenovoMenuRenderer` behandelt den Renderkontext jetzt konsequent als Item-lokale Koordinaten. Der bisherige Heuristikpfad über `VisibleClipBounds` und `item.Bounds.Top` wurde entfernt, weil er bei weiter unten liegenden Einträgen den Hover-Hintergrund außerhalb der sichtbaren Zeile zeichnen konnte.
- **Alle DropDown-Ebenen profitieren gemeinsam:** Hover/Pressed beginnt jetzt immer bei lokalem `Y = 0`; die X-Koordinate wird weiterhin auf den tatsächlichen Owner-Clientursprung zurückgerechnet und die Fläche auf `ToolStripDropDown.ClientSize.Width` erweitert. Das gilt für Hauptmenü, **„Standard-Startziel“**, **„Wartung“**, Checked-Einträge und künftige Untermenüs.
- **Alias-Feld ohne roten Vollrahmen:** Der aufgeklappte Alias-Editor bleibt breit und dunkel, besitzt aber keinen umlaufenden roten Fokusrahmen mehr. Stattdessen zeigt nur eine **1-px-Unterstreichung** den Fokus an.
- **Zurückhaltender Fokuszustand:** Ohne Fokus ist die Bottom-Line neutralgrau; beim Fokus wird ausschließlich diese Linie Lenovo-rot. Die Textbox selbst bleibt borderless auf dunkler Fläche.
- **Alias-Semantik unverändert:** `Enter` übernimmt in den Bearbeitungsentwurf, `Esc` verwirft die aktuelle Eingabe, **„✓ Übernehmen“** / **„× Abbrechen“** bleiben erhalten und erst das globale **„Speichern“** persistiert Alias, Reihenfolge und Sichtbarkeit.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Popup-first-Hintergrundrefresh, Bootziel-Tooltips, eigener Neustartdialog, Kontextmenü-Chrome und GUID-gebundene Alias-Persistenz bleiben unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1 und WinForms nicht ausführen. Auf dem Ziel-PC sind besonders Hover/Selected bei allen Positionen im Untermenü **„Standard-Startziel“** sowie der neue Alias-Fokuszustand zu prüfen.


## Neu in v0.2.29 – klarerer Header, Konfigurationsblock und Alias-Editor

v0.2.29 ist ein reiner UI-/UX-Pass auf Basis von v0.2.28. Die BootNext-, TaskBroker-, Default-, Cleanup-, Alias-Persistenz- und Hintergrund-Refresh-Architektur bleibt unverändert. Sichtbare Produktbezeichnung ist nun **Lenovo Boot Selector**; historische interne Task-/Pfadnamen bleiben aus Kompatibilitätsgründen unverändert.

Änderungen:

- **Neuer sichtbarer App-Name:** Der Header, Tray-Tooltip sowie nutzerseitige Dialog-/Balloon-Titel verwenden **„Lenovo Boot Selector“**. Interne Tasknamen, `%LOCALAPPDATA%`-/ProgramData-Pfade und Legacy-Bezeichner bleiben unverändert.
- **Header vereinfacht:** Der rein dekorative rote Punkt wurde entfernt. Der permanente Untertitel **„Einmaliges Startziel · Geräte erkannt“** entfällt vollständig. Im Ruhezustand zeigt der Header nur den App-Namen und den Refresh-Button.
- **Dynamischer Refresh-Status:** Nur während eines laufenden Hintergrund-Refreshs erscheint temporär **„Aktualisiere Bootziele…“**. Der Titel rückt dafür kurz nach oben und wird nach Abschluss wieder vertikal zentriert. Die vorhandene Variante-B-Logik des Refresh-Icons bleibt erhalten: neutral im Ruhezustand, Lenovo-rot bei Hover bzw. laufender Aktualisierung.
- **Unterer Bereich als Konfiguration gegliedert:** Über **„Mit Windows starten“** und **„Standardziel“** steht nun die kleine Abschnittsüberschrift **„KONFIGURATION“**. Der Neustart bleibt als separate Aktion darunter, ohne redundante zweite Überschrift.
- **Alias-Inline-Editing neu gestaltet:** Ein Klick auf den Stift öffnet nicht mehr eine schmale Textbox anstelle des Titels. Die betroffene Zeile klappt temporär auf 92 px auf, zeigt oben den Originalnamen als Referenz und darunter ein breites, dunkles Alias-Feld.
- **Klarer Editiermodus:** Während der Aliasbearbeitung werden `AN/AUS`, Stift und Drag-Handle der betroffenen Zeile ausgeblendet. Stattdessen erscheinen **„✓ Übernehmen“** und **„× Abbrechen“** sowie der Hinweis **„leer = Originalname“**. Dadurch konkurrieren keine Zeilenaktionen mit der Texteingabe.
- **Fokus-Akzent:** Das Alias-Feld besitzt eine zurückhaltende neutrale 1-px-Flächenkante; bei Fokus wird diese Lenovo-rot. `Enter` übernimmt weiterhin in den Bearbeitungsentwurf, `Esc` verwirft. Erst das globale **„Speichern“** persistiert Alias, Reihenfolge und Sichtbarkeit.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. GUID-Bindung, Alias-Persistenz, BootNext, systemweiter Default, Cleanup, Kontextmenüs, eigener Neustartdialog und Popup-first-Hintergrundrefresh bleiben funktional unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1 und WinForms nicht ausführen. Auf dem Ziel-PC sind besonders Header-Ruhezustand/Refreshstatus, Konfigurationsgliederung, Alias-Editor (Stift, Fokus, Übernehmen, Abbrechen, Enter/Esc, globales Speichern) sowie die bestehenden Boot-/Default-/Refresh-Regressionspfade zu prüfen.


## Neu in v0.2.28 – flache eckige Haupt-UI und neu gegliedertes Kontextmenü

v0.2.28 überführt die sichtbare Tray-Oberfläche in den gewünschten flachen, rechteckigen Utility-Stil. Die BootNext-, TaskBroker-, Default-, Cleanup-, Alias- und Hintergrund-Refresh-Architektur aus v0.2.27 bleibt unverändert.

Änderungen:

- **Haupt-Popup ohne Außenrahmen:** Der bisherige Lenovo-rote Außenring wurde vollständig entfernt. Das Popup ist jetzt ein einfacher rechteckiger 390×672-Kasten ohne abgerundete Window-Region.
- **Keine abgerundeten Ecken:** Haupt-Popup und der bereits eigene Neustartdialog verwenden keine Rounded-Region mehr. Rot bleibt Interaktions-/Statusakzent statt Fensterumrandung.
- **Bootzeilen über volle Breite:** Bootzeilen beginnen direkt an der linken Kante und reichen über die vollständige Listenbreite. Bei der aktuellen BootNext-Selektion liegt der rote vertikale Auswahlstreifen direkt an der äußeren linken Wand der Zeile. Hover und Selection färben die gesamte Zeilenfläche.
- **Reload-Aktion Variante B:** Das Aktualisieren-Symbol rechts oben bleibt im Normalzustand neutral/hell. Bei Hover sowie während eines laufenden Hintergrund-Refreshs wird das Symbol Lenovo-rot. Die bestehende nicht blockierende Refresh-Architektur aus v0.2.26/v0.2.27 bleibt unverändert.
- **Tray-Kontextmenü eckig und borderless:** Das Haupt-Kontextmenü besitzt keine rote oder neutrale Außenumrandung und keine Rundungen. Die vorhandenen Gruppen-Separatoren werden als 1-px-Lenovo-rote horizontale Linien gerendert.
- **Untermenüs bewusst abgesetzt:** `Standard-Startziel` und `Wartung` verwenden einen etwas helleren dunkelgrauen Panel-Hintergrund (`#202020`) statt Schwarz-auf-Schwarz. Eine dezente 1-px-Neutralkante und eine rote obere Akzentlinie trennen die Untermenüebene visuell vom Hauptmenü, ohne wieder einen roten Kasten zu erzeugen.
- **Menü-Hover bleibt vollbreit:** Die zentrale Renderer-Lösung aus v0.2.27 bleibt erhalten; Hover/Pressed wird gegen die tatsächliche DropDown-Clientbreite gezeichnet. Beim Hauptmenü reicht die Fläche bis an die vollständige Clientkante, bei Untermenüs bis unmittelbar innerhalb der dezenten 1-px-Kante.
- **Native Popup-Kante bleibt unterdrückt:** `DropShadowEnabled=false`, Entfernung der relevanten Win32-Window-Edge-Stile sowie die DWM-Border-Unterdrückung bleiben erhalten.
- **Neustartdialog an den neuen Stil angepasst:** Der eigene dunkle Dialog bleibt erhalten, ist jetzt ebenfalls rechteckig und ohne roten Außenring; die bestätigende Aktion bleibt Lenovo-rot und die Sicherheitssemantik bleibt unverändert.
- **Keine fachliche Änderung:** TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **4**. Bootziel-Aliase, Tooltips, Hintergrund-Refresh, Standardziel, Cleanup, Autostart und `shutdown.exe /r /t 0` bleiben funktional unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1, WinForms/DWM und ToolStripDropDown nicht ausführen. Auf dem Ziel-PC sind besonders rechteckige Haupt-UI, fehlender Außenrahmen, vollbreite Bootzeilen, Reload-Hover/Aktivzustand, rote Menüseparatoren und die optische Trennung der Untermenüs zu prüfen.


## Neu in v0.2.27 – vollständige Menü-Hervorhebung, native Außenkante entfernt und Bootziel-Aliase

v0.2.27 setzt die beiden im nativen v0.2.26-Smoke bestätigten Kontextmenü-Probleme zentral um und ergänzt die gewünschte Alias-Funktion im Modus **„Einträge verwalten“**. Die BootNext-, TaskBroker-, Default-, Cleanup-, Autostart-, Restart- und Hintergrund-Refresh-Architektur bleibt unverändert.

Änderungen:

- **Hover/Selected über die volle Menübreite:** Der gemeinsame `LenovoMenuRenderer` zeichnet die Auswahlfläche nicht mehr nur innerhalb der von WinForms berechneten Item-Breite. Die Item-Clipregion wird für die Hintergrundfläche kontrolliert aufgehoben und die Fläche gegen die tatsächliche `ToolStripDropDown.ClientSize.Width` berechnet. Damit gilt die Korrektur gemeinsam für Hauptmenü, **„Standard-Startziel“**, **„Wartung“** und künftige Untermenüs.
- `LenovoMenuLayout` verwendet zusätzlich die tatsächliche Clientbreite statt `DisplayRectangle.Width`; die v0.2.26-Lösung allein hatte auf dem Zielsystem die rechte Restfläche nicht erfasst.
- **2-px-Lenovo-Rahmen bleibt erhalten**, wird aber als gefüllter roter Außenring plus dunkle Innenfläche gerendert. Dadurch liegt an der äußersten Clientkante kein dunkler Pixelstreifen mehr außerhalb der roten Kontur.
- **Native schwarze Außenkante:** Zusätzlich zu `DropShadowEnabled = false` entfernt `LenovoMenuChrome` relevante native Border-/Edge-Fensterstile, deaktiviert DWM-Non-Client-Rendering für das DropDown und setzt unter Windows 11 `DWMWA_BORDER_COLOR` auf `DWMWA_COLOR_NONE`. Der rote Rahmen bleibt vollständig clientseitig.
- **Bootziel-Aliase:** Im Modus **„Einträge verwalten“** besitzt jeder Eintrag eine kleine Stift-Aktion. Sie öffnet direkt in der Zeile ein Inline-Eingabefeld. `Enter` übernimmt den Alias in den Bearbeitungsentwurf, `Esc` verwirft die aktuelle Eingabe; ein leerer Alias bedeutet wieder Originalname.
- Aliase werden erst zusammen mit **„Speichern“** dauerhaft übernommen. **„Abbrechen“** verwirft auch Aliasänderungen.
- Ein gesetzter Alias wird in der normalen Bootauswahl als sichtbarer Hauptname verwendet. Zur Orientierung zeigt die Verwaltungsansicht bei gesetztem Alias im Subtext den Originalnamen.
- Aliase werden als reine lokale UI-Metadaten stabil an der Firmware-GUID gespeichert. Sie verändern **keine** Firmware-GUID, keinen BootNext-Wert, keine Tasknamen, keine TaskBroker-Allowlist und keine sonstige privilegierte Identität.
- Die Alias-Anzeige wird auch für endnutzerseitige Zielnamen wie Standardziel-Menüs, Statusanzeige und Neustartdialog verwendet; die technische Identität bleibt immer die GUID.
- `settings.json` wird abwärtskompatibel auf **Schema 4** erweitert: zusätzlich zu `defaultGuid`, `entryOrder` und `hiddenEntryGuids` gibt es `entryAliases`. Dateien aus Schema 3 oder älter werden weiterhin eingelesen; fehlende Aliase entsprechen einer leeren Alias-Menge.
- TaskBroker-Schema bleibt **0.2.12**. Installer, Uninstaller, Launcher und privilegierte Scheduled-Task-Verträge sind unverändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann WinForms/DWM nicht ausführen. Auf dem Ziel-PC sind insbesondere die vollständig breite Hover-/Selected-Fläche in allen Menüs, das vollständige Fehlen der schwarzen Außenkante sowie Stift-/Inline-Aliasbearbeitung und Persistenz nach App-Neustart zu prüfen.


## Neu in v0.2.26 – Kontextmenü-Finishing, eigener Neustartdialog und sofort sichtbare Bootauswahl

v0.2.26 setzt den nativen UI-Smoke nach v0.2.25 um. Die privilegierte Boot-/TaskBroker-/Default-Architektur bleibt unverändert; geändert werden ausschließlich Darstellung, Tooltip-Zuverlässigkeit und der interaktive Refreshpfad.

Änderungen:

- Der Lenovo-rote Rahmen des Tray-Kontextmenüs und seiner Untermenüs ist wieder **2 px** breit. Der in v0.2.25 deaktivierte native `ToolStripDropDown`-Schatten bleibt deaktiviert, damit außerhalb des roten Rahmens keine zusätzliche schwarze Schattenkante gewollt ist.
- Menüeinträge werden beim Öffnen explizit auf die nutzbare Dropdown-Breite gestreckt. Hover-/Selected-Hintergründe sollen dadurch wieder bis zur vollen nutzbaren Breite reichen – auch bei Menüs, deren `MinimumSize` breiter als der automatisch berechnete Textinhalt ist.
- Der Hover-Hintergrund ist etwas präsenter (`#401F1D` statt des sehr zurückhaltenden bisherigen Tons), bleibt aber dunkel und Lenovo-konform.
- **„Windows neu starten“** verwendet keinen nativen Windows-Standard-Yes/No-Dialog mehr. Der neue eigene Bestätigungsdialog nutzt die dunkle Lenovo-Oberfläche, einen 2-px-roten Außenrahmen, konsistente Typografie sowie `Abbrechen`/`Neu starten`. Sicherheitssemantik bleibt unverändert: das konkrete nächste Startziel wird angezeigt, es ist eine explizite Bestätigung erforderlich und der eigentliche Neustart bleibt `shutdown.exe /r /t 0` ohne zusätzliche UAC-Abfrage.
- Die Bootziel-Marker-Tooltips verwenden zusätzlich zum normalen `ToolTip.SetToolTip(...)` einen expliziten `MouseHover`-Fallback. Damit wird der Erklärungstext direkt am farbigen Kreis angezeigt, auch wenn der native WinForms-Tooltip auf dem transparenten Symbol-Label nicht selbständig erscheint.
- **Startlatenz:** `Show-OrTogglePopup` führt vor `Popup.Show()` keine frische Task-/Firmware-Abfrage mehr aus. Vorhandene Cache-Dateien werden sofort gelesen; die UI wird zuerst sichtbar. Die vollständige exakte TaskBroker-Prüfung sowie Manager-/Firmware-Refresh und optional Storage-Ermittlung laufen danach in einem versteckten, unelevierten Windows-PowerShell-Hintergrundprozess. Die Haupt-UI pollt nur dessen Abschluss und übernimmt das Ergebnis anschließend.
- Auch der explizite Refresh über Kopfzeile bzw. Kontextmenü nutzt den nicht blockierenden Hintergrundpfad. Firmware wird dabei weiterhin nur bei Bedarf bzw. beim vollständigen Storage-Refresh erneuert; der Managerzustand wird frisch gelesen.
- Der Hintergrundworker misst intern die Laufzeiten für TaskBroker-Prüfung, Manager-Refresh, Firmware-Refresh, Storage-Ermittlung und Gesamtzeit. Dadurch kann ein nativer Folgetest die tatsächlich langsame Phase eindeutig eingrenzen, ohne die UI vor dem Anzeigen zu blockieren.
- TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **3**. Installer, Uninstaller, Launcher und privilegierte Scheduled-Task-Verträge werden durch v0.2.26 nicht geändert.

**Native Prüfung erforderlich:** Die Linux-Buildumgebung kann Windows PowerShell 5.1, WinForms/DWM und Task Scheduler nicht ausführen. Insbesondere müssen auf dem Ziel-PC der 2-px-Rahmen, die volle Hover-Breite, der eigene Neustartdialog, die Marker-Tooltips und die subjektive/zeitliche Verbesserung beim Öffnen der Boot-Auswahl bestätigt werden.


## Neu in v0.2.25 – schlanker Kontextmenü-Rahmen ohne schwarze Außenkante

v0.2.25 verfeinert ausschließlich die äußere Darstellung des Tray-Kontextmenüs. BootNext-, TaskBroker-, Default-, Autostart-, Cleanup-, Restart- und Tooltip-Architektur aus v0.2.24 bleiben unverändert.

Änderungen:

- Der Lenovo-rote Außenrahmen des Kontextmenüs und seiner Untermenüs wurde von **2 px auf 1 px** reduziert.
- Der Rahmen wird nun direkt an der Clientkante gezeichnet, sodass außerhalb der roten Linie kein zusätzlicher dunkler Client-Rand mehr verbleibt.
- Der native WinForms-`ToolStripDropDown`-Schatten wird deaktiviert (`DropShadowEnabled = false`), damit außerhalb des roten Rahmens keine zusätzliche schwarze Schattenkontur erscheinen soll.
- Abgerundete Ecken, Checked-Zustände, Untermenü-Pfeile, Menüstruktur, Wartungs-Untermenü und die Tooltip-Erklärungen der Bootziel-Marker bleiben unverändert.
- TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **3**; für dieses reine UI-Update ist keine Reparatur/Neueinrichtung der privilegierten Aufgaben erforderlich.
- Die visuelle Wirkung muss weiterhin nativ unter Windows geprüft werden, da WinForms-/DWM-Dropdown-Chrome in der Linux-Buildumgebung nicht ausgeführt werden kann.


## Neu in v0.2.24 – Bedeutung der farbigen Bootziel-Marker per Tooltip

v0.2.24 ergänzt ausschließlich eine UI-Erklärung für die farbigen Kreise in der Bootliste. BootNext-, TaskBroker-, Default-, Autostart-, Cleanup-, Restart- und Kontextmenü-Architektur aus v0.2.23 bleiben unverändert.

Änderungen:

- Beim Überfahren des **farbigen Kreises** eines Bootziels erscheint jetzt ein Tooltip, der Kategorie und Farbbedeutung erklärt.
- Rot = Lenovo Boot-Menü / Firmware-Bootauswahl.
- Gelb = USB-Startziel.
- Blau = internes NVMe-/PCIe-Startlaufwerk.
- Violett = PXE-Netzwerkstart.
- Cyan = Lenovo-/Unternehmens-Netzwerk-/Recovery-Startziel.
- Grau = sonstiges bzw. nicht speziell klassifiziertes Firmware-Startziel.
- Der Tooltip ist bewusst nur am farbigen Kreis gebunden; Auswahlzustand bleibt weiterhin separat durch linken roten Balken, Zeilenhintergrund und Häkchen erkennbar.
- TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **3**; keine Reparatur/Neueinrichtung der privilegierten Aufgaben erforderlich.


## Neu in v0.2.23 – Kontextmenü fokussiert und optisch an die Haupt-UI angeglichen

v0.2.23 ist ein reiner UI-/UX-Pass am Tray-Kontextmenü. BootNext-, TaskBroker-, Default-, Autostart- und Cleanup-Architektur aus v0.2.22 bleiben unverändert.

Änderungen:

- **„Einträge verwalten…“ wurde aus dem Tray-Kontextmenü entfernt.** Die Funktion bleibt vollständig erhalten und ist weiterhin über **„VERWALTEN“** direkt in der Haupt-UI erreichbar.
- Die beiden technischen Aktionen **„Privilegierte Aufgaben einrichten/reparieren…“** und **„Privilegierte Aufgaben entfernen…“** sind jetzt im Untermenü **„Wartung ›“** gebündelt.
- Statushinweise für fehlende bzw. reparaturbedürftige privilegierte Aufgaben verweisen jetzt korrekt auf **„Rechtsklick → Wartung → …“**.
- **„Bootauswahl öffnen“** ist als primäre Tray-Aktion dezent durch Fettschrift hervorgehoben.
- Das Kontextmenü besitzt jetzt einen **durchgängigen 2-px-Rahmen in Lenovo Red `#E1251B`**, passend zum roten Außenring der Haupt-UI, weiterhin mit abgerundeten Ecken.
- Checked-Zustände im Kontextmenü verwenden eine **rote Checkbox mit weißem Häkchen** statt des uneinheitlichen nativen Windows-Looks.
- Untermenü-Pfeile wurden kontrastreicher gestaltet und die vertikalen Innenabstände der Menüeinträge leicht vergrößert.
- TaskBroker-Schema bleibt **0.2.12**, Settings-Schema bleibt **3**; es ist **keine Reparatur/Neueinrichtung der privilegierten Aufgaben allein wegen des Updates auf v0.2.23 erforderlich**.


## Neu in v0.2.22 – systemweiter Default-Restore, Legacy-Migration und vollständige Task-Bereinigung

v0.2.22 löst die bisher konkurrierenden Default-Mechanismen auf. Der benutzerspezifische Login-/Session-Restore der Tray-App entfällt. Stattdessen besitzt die Installation genau einen systemweiten SYSTEM-Startup-Restore, der 30 Sekunden nach Windows-Systemstart das konfigurierte Standard-Bootziel setzt. Die unelevierte Tray-App ändert diesen Standard ausschließlich über fest definierte, vorautorisierte Scheduled Tasks.

Änderungen und Sicherheitsgrenzen:

- neuer TaskBroker-Schema-Stand **0.2.12**; Installationen aus v0.2.21 und älter werden absichtlich als **reparatur-/migrationsbedürftig** erkannt;
- neuer fixer SYSTEM-Task **`LenovoBootMenu-Default-Restore`** mit `AtStartup` + **30 Sekunden Delay**;
- pro allowgelistetem Firmwareziel zusätzlicher fixer Task **`LenovoBootMenu-Default-Set-<GUID>`**;
- **`LenovoBootMenu-Default-Clear`** deaktiviert den automatischen Standard;
- der eigentliche Startup-Restore liest den systemweiten Default aus `C:\ProgramData\Lenovo Boot Menu\TaskBroker\Default\default-guid.txt`, akzeptiert aber ausschließlich beim Setup fest in den Restore-Task eingebettete, bekannte Firmware-GUIDs;
- der Default-State-Ordner wird auf **SYSTEM/Administratoren = Full Control** und **Benutzer = Read/Execute** gehärtet; die unelevierte App schreibt die Datei niemals direkt;
- bestehende **`LenovoBootMenu-Set-<GUID>`**-Tasks bleiben ausschließlich für die unmittelbare manuelle BootNext-Auswahl zuständig;
- die App führt **keinen Login-/Session-Restore mehr aus** und entfernt den alten HKCU-Volatile-Marker;
- Migration priorisiert: vorhandener systemweiter Default → bisheriger `settings.json`-Default → historischer Task `Lenovo Boot Menu Next`/Boot Menu → kein Standard;
- der historische Task **`Lenovo Boot Menu Next`** wird erst entfernt, nachdem die neue Taskmenge erfolgreich registriert und ACL-validiert wurde; der neue Startup-Restore ist während dieser Migrationsphase deaktiviert und wird erst danach aktiviert;
- **manuelle BootNext-Auswahl nach Ausführung des Startup-Restore gewinnt** für den nächsten Start. Eine manuelle Auswahl innerhalb der ersten 30 Sekunden nach Systemstart kann dagegen noch vom verzögerten Restore überschrieben werden;
- `settings.json` ist Schema **3**: UI-Reihenfolge und ausgeblendete Einträge bleiben benutzerspezifisch; `defaultGuid` existiert nur noch temporär als Legacy-Migrationsquelle und wird nach erfolgreicher Migration geleert;
- neue Cleanup-Aktion **„Privilegierte Aufgaben entfernen…“** (ab v0.2.23 unter **„Wartung“**) startet nach Bestätigung und UAC eine gezielte Bereinigung aller bekannten projektbezogenen Scheduled Tasks, des alten Service-Broker-Prototyps sowie des systemweiten TaskBroker-/Default-Zustands;
- die Bereinigung löscht nur exakte bekannte Tasknamen und die expliziten Projektpräfixe `LenovoBootMenu-Set-` und `LenovoBootMenu-Default-Set-`; es gibt **keinen pauschalen Lenovo-Wildcard-Löschpfad**;
- UEFI-Boot-Einträge und die permanente Firmware-`displayorder` werden weder bei Migration noch bei Bereinigung verändert;
- HKCU-App-Autostart bleibt bei der Task-Bereinigung bewusst bestehen.

**Wichtig beim Upgrade von v0.2.21:** Einmal **„Wartung → Privilegierte Aufgaben reparieren…“** ausführen und die UAC-Abfrage bestätigen. Erst dadurch werden der neue Default-Restore und die Default-Set/Clear-Tasks installiert und der historische `Lenovo Boot Menu Next` kontrolliert migriert.

## Neu in v0.2.21 – Einträge verwalten

v0.2.21 ergänzt die gewünschte lokale Verwaltung der sichtbaren Bootziele. Die Firmware-Reihenfolge (`displayorder`) wird dabei ausdrücklich **nicht** verändert; gespeichert werden ausschließlich UI-Reihenfolge und Sichtbarkeit des Lenovo Boot Menu Tray.

Änderungen:

- neuer Einstieg **„VERWALTEN“** direkt über der Bootliste sowie **„Einträge verwalten…“** im Tray-Kontextmenü;
- im Bearbeitungsmodus werden **alle erkannten Firmware-Einträge** angezeigt – auch zuvor ausgeblendete;
- Reihenfolge lässt sich per **Drag & Drop** verändern;
- Klick auf einen Eintrag schaltet ihn zwischen **AN** und **AUS** um; ausgeblendete Einträge werden unmittelbar ausgegraut;
- ein Klick im Bearbeitungsmodus setzt **kein BootNext**;
- **Speichern** übernimmt Reihenfolge und Sichtbarkeit persistent und kehrt in die normale Read-only-Ansicht zurück;
- **Abbrechen** verwirft die noch nicht gespeicherten Änderungen;
- normale Ansicht zeigt anschließend ausschließlich **aktive Einträge in der gespeicherten Reihenfolge**;
- `settings.json` wurde abwärtskompatibel auf Schema 2 erweitert: `defaultGuid`, `entryOrder`, `hiddenEntryGuids`;
- neue bzw. bislang unbekannte Firmware-Einträge werden automatisch hinter der gespeicherten Reihenfolge ergänzt und sind standardmäßig sichtbar;
- Haupt-UI und durchgängiger abgerundeter Lenovo-Rahmen bleiben auf dem Stand von v0.2.20; das verbesserte abgerundete Kontextmenü bleibt erhalten;
- privilegierte TaskBroker-Aufgaben, BootNext-Mechanik, Autostart, Standardziel und Neustartlogik bleiben unverändert;
- **keine erneute Einrichtung oder Reparatur der privilegierten Windows-Aufgaben erforderlich.**


## Neu in v0.2.20 – Haupt-UI zurück auf v0.2.18, Kontextmenü beibehalten, Rahmen sauber geschlossen

v0.2.20 nimmt die Hauptoberfläche bewusst wieder auf den Stand von v0.2.18 zurück. Die neuere Kontextmenü-Gestaltung mit abgerundeten Ecken bleibt erhalten. Zusätzlich wurde der Außenrahmen technisch neu aufgebaut, damit Lenovo-Rot an allen vier Seiten und insbesondere an den Ecken durchgängig sichtbar ist.

Änderungen:

- Haupt-UI (Bootliste, Zeilen, Standardziel-Zeile, Neustartbutton, Footer, Scrollbereich) entspricht wieder dem v0.2.18-Layout;
- das verbesserte dunkle Kontextmenü aus der neueren UI bleibt erhalten und besitzt abgerundete Ecken;
- der bisher aus vier geraden Rand-Panels zusammengesetzte Rahmen wurde entfernt;
- stattdessen liegt die komplette v0.2.18-Oberfläche in einer inneren, abgerundeten Fläche innerhalb eines **durchgängigen 2-px-Lenovo-roten Außenrings**;
- Außen- und Innenfläche werden mit aufeinander abgestimmten Radien geclippt, sodass die roten Rundungen an allen vier Ecken geschlossen bleiben;
- Bootlogik, TaskBroker, Autostart, persistentes Standardziel und Neustartfunktion bleiben unverändert;
- **keine erneute Einrichtung oder Reparatur der privilegierten Windows-Aufgaben erforderlich.**


## Neu in v0.2.18 – Startfehler des Visual-Polish-Builds behoben

v0.2.18 korrigiert einen PowerShell-Argumentbindungsfehler aus v0.2.17. Drei UI-Labels übergaben einen statischen `[Drawing.Color]::FromArgb(...)`-Aufruf direkt als Argument an `-ForeColor`. In Windows PowerShell wurde dieser Ausdruck dabei nicht ausgewertet, sondern als Text behandelt; dadurch konnte der Wert nicht in `System.Drawing.Color` konvertiert werden und das Popup brach beim Aufbau ab.

Änderungen:

- alle drei betroffenen `-ForeColor`-Argumente werden jetzt explizit als ausgewerteter Ausdruck `([Drawing.Color]::FromArgb(...))` übergeben;
- Versionsanzeige auf **v0.2.18** angehoben;
- Visual-Polish, Scrollbar, Kontextmenü, Bootlogik, TaskBroker, Autostart, Standardziel und Neustartverhalten bleiben gegenüber v0.2.17 unverändert;
- **keine erneute Einrichtung oder Reparatur der privilegierten Windows-Aufgaben erforderlich.**



## Neu in v0.2.17 – kompletter Visual-Polish-Pass

v0.2.17 überarbeitet ausschließlich Darstellung und Bedienhierarchie der Tray-Oberfläche; Bootlogik, TaskBroker, Autostart, Standardziel und Neustartverhalten bleiben unverändert.

Änderungen:

- Popup auf **390 px Breite** erweitert, damit Gerätenamen und Detailtexte mehr Luft erhalten;
- Header ruhiger aufgebaut: mehr Innenabstand, kompakter Untertitel und dezente Trennlinie;
- aktive Bootzeile verwendet nur noch eine **subtile dunkelrote Fläche**, einen 3-px-Lenovo-Rot-Akzent links und das rote Häkchen;
- gleichmäßige horizontale Textachsen und größere Innenabstände in allen Bootzeilen;
- SanDisk-Detailtext kompakter formuliert (`USB HDD · wahrscheinlicher Bootkandidat`), ohne die Erkennungslogik zu ändern;
- Scrollbar auf einen schmalen **8-px dunklen Track** mit schlankem Lenovo-rotem Thumb reduziert;
- native blaue Windows-Checkbox durch eine eigene schwarz/Lenovo-rote Checkbox ersetzt;
- Standardziel als kompakte Navigationszeile mit `›` gestaltet;
- Neustart-Aktion ist nicht mehr permanent rot umrandet, sondern erhält Lenovo-Rot erst bei Hover/Interaktion;
- Footer beruhigt und Versionsanzeige sauber rechts ausgerichtet;
- der zuvor dominante rote Außenrahmen bleibt gemäß Designvorgabe erhalten, aber nur noch als **subtile 1-px dunkelrote Linie**;
- Popup erhält leicht gerundete Ecken;
- Kontextmenü: kein leuchtend roter Außenrahmen mehr, stattdessen dunkelgraue Kontur, dunkler Hover mit Lenovo-Rot-Akzent, mehr Innenabstand und sauberere Gruppierung;
- nach „Aktualisieren“ trennt jetzt ein Separator die Navigationsaktionen von den Einstellungen.

**Keine erneute Einrichtung oder Reparatur der privilegierten Windows-Aufgaben erforderlich.**


## Neu in v0.2.16 – Scroll-Crash behoben

v0.2.16 behebt den reproduzierten Absturz beim Mausrad-/Scrollbar-Scrollen aus v0.2.15. Der `ValueChanged`-Handler des neuen Lenovo-Scrollbalkens verwendete lokal den Variablennamen `$host`. PowerShell behandelt Variablennamen ohne Beachtung der Groß-/Kleinschreibung; dadurch kollidierte `$host` mit der eingebauten schreibgeschützten automatischen Variable `$Host` und WinForms zeigte eine unbehandelte .NET-Ausnahme.

Änderungen:

- die lokale Scroll-Container-Variable heißt nun konfliktfrei `$scrollContainer`;
- der `ValueChanged`-Callback ist zusätzlich defensiv abgefangen, damit ein UI-Scrollereignis keinen WinForms-JIT-Dialog mehr auslösen kann;
- Lenovo-Rahmen, roter Custom-Scrollbar, Kontextmenü-Theme, Bootlogik, TaskBroker, Autostart, Standardziel und Neustartlogik bleiben gegenüber v0.2.15 unverändert;
- **keine erneute Einrichtung/Reparatur der privilegierten Aufgaben erforderlich**.


## Neu in v0.2.15 – Lenovo-Rahmen, Versionsanzeige und vollständig thematisierte Navigation

v0.2.15 vervollständigt den Schwarz/Lenovo-Rot-Look der Tray-Oberfläche:

- die komplette Popup-UI besitzt jetzt einen **2-px-Lenovo-roten Außenrahmen**;
- die laufende **Versionsnummer ist unten rechts im Footer sichtbar**;
- der bisherige native helle Windows-Scrollbar wurde durch einen **eigenen dunklen Scroll-Track mit Lenovo-rotem Schieber** ersetzt;
- der horizontale Standard-Scrollbar entfällt, da die Bootzeilen nun innerhalb der verfügbaren Breite gerendert werden;
- Scrollen per Mausrad sowie Ziehen/Klicken des roten Scroll-Schiebers bleiben möglich;
- das Tray-Kontextmenü und das Menü **„Standard-Startziel“** verwenden nun denselben dunklen Hintergrund, Lenovo-Rot für Rahmen/Selection/Checked-Zustände und helle Schrift;
- die Boot-, TaskBroker-, Autostart-, Standardziel- und Neustartlogik bleibt gegenüber v0.2.14 unverändert; eine erneute Einrichtung der privilegierten Aufgaben ist **nicht erforderlich**.



## Neu in v0.2.14 – besser lesbare Subtexte

Die zweizeiligen Detailtexte der Bootziele werden nicht mehr in einer zu niedrigen Ein-Zeilen-Fläche abgeschnitten. Die Eintragszeilen sind etwas höher, die Subtexte erhalten ausreichend Höhe für zwei Zeilen und eine leicht größere Schrift. Zusätzlich wurde der Sekundärtext von dunklem Grau auf ein helleres Grau angehoben, damit kurze und längere Beschreibungen auf dem dunklen Hintergrund deutlich besser lesbar sind.

Die Bootlogik, privilegierten Windows-Aufgaben, Autostart-, Standardziel- und Neustartfunktionen bleiben gegenüber v0.2.13 unverändert. Eine erneute Einrichtung der privilegierten Aufgaben ist nicht erforderlich.


## Neu in v0.2.13 – Neustartdialog nennt das konkrete Bootziel

Der Bestätigungsdialog für **„Windows neu starten“** zeigt jetzt das aktuell gesetzte nächste Startziel mit seinem endanwenderfreundlichen Namen an, zum Beispiel **„SanDisk Extreme Pro USB4“** oder **„Lenovo Boot-Menü“**. Ist kein einmaliges `bootsequence`-Ziel gesetzt, wird **„Firmware-Standardreihenfolge“** angezeigt. Die Neustartlogik selbst bleibt unverändert.

## Neu in v0.2.12 – versteckter Autostart, persistentes Standardziel und Neustart

v0.2.12 erweitert den normalen, unelevierten Tray-Betrieb um drei Funktionen:

- **Autostart ohne sichtbares PowerShell-Fenster:** Der HKCU-Autostart startet nicht mehr direkt `powershell.exe`, sondern den vorhandenen `wscript.exe`/VBS-Launcher. Ein bereits aktiver Autostart-Eintrag aus älteren Versionen wird beim Start automatisch auf den versteckten Launcher der aktuell ausgeführten Version migriert.
- **Persistentes Standard-Startziel:** Im Popup gibt es **„Standard: …“**, zusätzlich im Tray-Kontextmenü **„Standard-Startziel“**. Die Auswahl wird unter `%LOCALAPPDATA%\Lenovo Boot Menu Tray\settings.json` gespeichert. Beim ersten Start der App in einer Windows-Anmeldesitzung – also auch beim Autostart – wird dieses Ziel einmalig als `bootsequence` wiederhergestellt. Der Sitzungsmarker liegt in `HKCU\Volatile Environment` und verschwindet bei der nächsten Windows-Anmeldung.
- **Windows neu starten:** Die Aktion ist sowohl direkt im Popup als auch im Tray-Kontextmenü vorhanden. Vor dem Neustart wird bestätigt; anschließend wird Windows über `shutdown.exe /r /t 0` ohne zusätzliche UAC-Abfrage neu gestartet. Das aktuell gesetzte `bootsequence`-Ziel wird dabei verwendet.

Die privilegierten TaskBroker-Aufgaben aus v0.2.11 bleiben unverändert und kompatibel; für v0.2.12 ist **keine erneute Reparatur/Einrichtung** erforderlich.

### Standard-Startziel verwenden

1. Popup öffnen.
2. Auf **„Standard: …“** klicken und ein Firmware-/Bootziel auswählen – oder im Tray-Kontextmenü **„Standard-Startziel“** verwenden.
3. Die Auswahl wird persistent gespeichert.
4. Beim ersten Toolstart der nächsten Windows-Anmeldesitzung wird dieses Ziel automatisch als einmaliges nächstes Startziel gesetzt. Weitere App-Neustarts in derselben Sitzung überschreiben eine danach manuell getroffene Auswahl nicht erneut.

**Hinweis zum historischen Task `Lenovo Boot Menu Next`:** Dieser separat früher eingerichtete Task bleibt weiterhin unangetastet und kann ca. 30 Sekunden nach Windows-Start erneut das Lenovo Boot-Menü setzen. Wenn ein anderes persistentes Standardziel verwendet werden soll, kann dieser historische Task das Standardziel später wieder überschreiben.



## Neu in v0.2.11 – Task-Status 0x00041301 korrekt behandeln

v0.2.11 behebt einen Laufzeitfehler beim Auswählen eines Bootziels. Der Windows Task Scheduler verwendet `0x00041301` (`267009`, `SCHED_S_TASK_RUNNING`) als **Erfolgs-/Statuscode für „Aufgabe wird gerade ausgeführt“**. v0.2.10 konnte diesen transienten Zustand aufgrund eines Rennens zwischen `LastTaskResult` und dem COM-Taskzustand fälschlich als Fehler anzeigen.

Änderungen:

- `0x00041301` (`SCHED_S_TASK_RUNNING`) und `0x00041325` (`SCHED_S_TASK_QUEUED`) werden als transiente Zustände behandelt und nicht als Fehler;
- der konkrete COM-Task wird bei jedem Poll neu geöffnet, damit kein veralteter `State`-Wert verwendet wird;
- Erfolg wird erst akzeptiert, wenn der aktuelle Lauf beendet ist und `LastTaskResult = 0` zurückliefert;
- die bestehende TaskBroker-/ACL-Installation aus v0.2.10 bleibt kompatibel; eine erneute Reparatur ist nicht erforderlich.

## Neu in v0.2.10 – Task-ACL-Verifikation korrigiert

v0.2.10 behebt den konkreten Reparaturfehler aus v0.2.9. Windows Task Scheduler normalisiert eine gesetzte `(A;;GRGX;;;SID)`-ACE beim Persistieren typischerweise auf den objektspezifischen Zugriffsmaskenwert `0x1200A9`. v0.2.9 prüfte nach dem Schreiben ausschließlich die ursprünglichen GENERIC_READ-/GENERIC_EXECUTE-Bits und meldete deshalb fälschlich, die ACL sei nicht gesetzt worden.

Änderungen:

- akzeptiert bei der DACL-Verifikation sowohl `GR+GX` als auch die persistierte Task-Scheduler-Maske `0x1200A9`;
- öffnet den Task nach `SetSecurityDescriptor()` erneut, bevor die ACL verifiziert wird;
- protokolliert bei einem echten Verifikationsfehler den zurückgelesenen SDDL;
- vorhandene v0.2.6–v0.2.9-Tasks werden weiterverwendet und nur repariert;
- die Sicherheitsgrenze bleibt unverändert: der Benutzer erhält nur Lesen + Ausführen, nicht Ändern/Löschen;
- keine Änderung an `displayorder`; Bootänderungen erfolgen weiterhin ausschließlich über die festen SYSTEM-Tasks.


## Neu in v0.2.9 – Reparaturzustand korrekt erkennen

v0.2.9 trennt jetzt sauber zwischen **nicht installiert** und **vorhanden, aber nicht funktionsbereit**. Wenn `task-broker.json` bereits existiert, die unelevierte Readiness-Prüfung aber wegen einer fehlerhaften Task-DACL scheitert, zeigt das Tray nun **„Privilegierte Aufgaben reparieren…“** statt erneut **„… einrichten…“** an.

Änderungen:

- Kontextmenü bietet bei vorhandener, aber defekter TaskBroker-Installation **„Privilegierte Aufgaben reparieren…“** an;
- Popup zeigt **„Reparatur erforderlich“** statt „Einrichtung erforderlich“;
- der Reparaturdialog erklärt, dass die vorhandene Installation unvollständig oder nicht zugreifbar ist;
- der Installer v0.2.9 behält die v0.2.8-DACL-Reparatur/Verifikation bei und schreibt Metadaten mit Version 0.2.9;
- ältere TaskBroker-Metadaten 0.2.6–0.2.8 bleiben lesbar und reparierbar.


## Neu in v0.2.8 – Task-ACL/Readiness-Fix

v0.2.8 korrigiert einen Fehler in der unelevierten Verifikation der bereits erfolgreich eingerichteten SYSTEM-Aufgaben. Auf dem Zielsystem konnten die per Task-DACL freigegebenen Aufgaben gestartet und mit `Get-ScheduledTaskInfo` gelesen werden, während `Get-ScheduledTask` beim Root-Folder-Enumerieren im unelevierten Prozess fehlschlug. Dadurch meldete v0.2.6 fälschlich „nicht eingerichtet“, obwohl der Installer mit `SUCCESS` und ExitCode 0 beendet war.

Änderungen:

- keine `Get-ScheduledTask`-Root-Enumeration mehr im unelevierten Tray;
- exaktes Lesen über Task-Scheduler-COM `GetTask()` plus `Get-ScheduledTaskInfo`;
- Task-Ausführung wartet über den exakten COM-Taskzustand auf Abschluss;
- vorhandene v0.2.6-TaskBroker-Installation wird akzeptiert – **keine erneute UAC-Einrichtung nötig**, wenn sie bereits erfolgreich war;
- ExitCode 0 + fehlgeschlagene Client-Verifikation wird nicht mehr fälschlich als Installerfehler bezeichnet;
- der Installer v0.2.8 verwendet eine wiederverwendete Task-Scheduler-COM-Verbindung für ACL-Arbeit, um unnötigen Setup-Overhead zu reduzieren.

## Neu in v0.2.8 – Bootstrap-/Tray-Härtung

v0.2.8 behebt die in v0.2.5 beobachteten Start- und Bedienprobleme:

- **kein dauerhaft offenes CMD-Fenster mehr**: der CMD-Starter delegiert sofort an einen versteckten, entkoppelten `wscript`-Launcher und beendet sich;
- **Tray bleibt immer bedienbar**: die einmalige Einrichtung der privilegierten Tasks blockiert nicht mehr den UI-Start;
- **Beenden bleibt verfügbar**, auch wenn die privilegierten Tasks fehlen oder ihre Einrichtung fehlschlägt;
- Linksklick öffnet bei fehlender Einrichtung jetzt das normale Popup mit einem Statushinweis statt einer wiederholten Fehler-MessageBox;
- neue Kontextmenü-Aktion **„Privilegierte Aufgaben einrichten…“** bzw. nach erfolgreicher Einrichtung **„… reparieren…“**;
- die UAC-Installation läuft asynchron; die Tray-UI bleibt währenddessen reaktionsfähig;
- bei Installationsfehlern wird weiterhin auf das Diagnose-ZIP verwiesen.

## Privilege-Separation

Die Tray-App läuft als normaler Benutzer. Für privilegierte Firmwareoperationen werden einmalig fest definierte Windows-Scheduled-Tasks erstellt:

```text
Lenovo Boot Menu Tray
normaler Benutzer
        |
        | Read + Execute auf fest definierte Tasks
        v
Windows Task Scheduler
Task läuft als SYSTEM
        |
        v
Microsoft bcdedit.exe
fest vorgegebenes Bootziel
```

Es läuft **keine Lenovo-eigene EXE als SYSTEM**.

Für jedes zulässige Firmware-Ziel wird ein eigener Task mit fest eingebauter GUID angelegt. Der Benutzer erhält auf diesen Taskobjekten nur Read + Execute (`GRGX`). Die Tray-App kann daher keine frei wählbaren Admin-Kommandos oder freie GUID-Parameter an einen privilegierten Prozess übergeben.

## Einmalige Einrichtung

Nach dem ersten Start bleibt das Tray sofort benutzbar. Solange die privilegierten Aufgaben fehlen, steht im Popup:

```text
Einrichtung erforderlich · Rechtsklick → Wartung
```

Dann im Tray-Kontextmenü **„Wartung → Privilegierte Aufgaben einrichten…“** wählen und die einmalige UAC-Abfrage bestätigen.

Nach erfolgreicher Einrichtung wird der Firmwarezustand automatisch neu geladen. Im Normalbetrieb sind anschließend keine UAC-Abfragen mehr erforderlich.

## Launcher

`Start-LenovoBootMenuTray.cmd` startet `Start-LenovoBootMenuTray.vbs`. Zusätzlich verwendet auch der Windows-Autostart ab v0.2.12 direkt diesen WScript/VBS-Pfad. Dadurch bleibt weder beim manuellen Start noch bei der Windows-Anmeldung ein PowerShell-/CMD-Fenster sichtbar.

## Bestehende Funktionen

- schwarzes Popup mit **Lenovo Red `#E1251B`** als Highlight-Farbe;
- flaches, rechteckiges Haupt-Popup ohne äußeren roten Rahmen oder Rundungen;
- schlanker 8-px-dunkelgrauer Scroll-Track mit Lenovo-rotem Scroll-Schieber;
- eckiges, borderless Schwarz/Lenovo-Rot-Kontextmenü mit roten horizontalen Separatoren und dezent abgesetzten Untermenüs;
- Lenovo-Rot im Tray-Icon;
- aktuelles `bootsequence`-Ziel wird markiert;
- dynamische Firmware-Einträge ohne GUIDs in der Endanwender-UI;
- `USB HDD` wird anhand aktueller Storage-/Partitionsdaten einem plausiblen physischen USB-Bootkandidaten zugeordnet;
- SanDisk Extreme Pro USB4 wird in der untersuchten Konstellation gegenüber der nicht bootfähigen Micron priorisiert;
- Storage-Kontext wird gecacht;
- **Einträge verwalten**: alle Einträge sichtbar, Drag & Drop, Ein/Aus per Klick, Speichern/Abbrechen, persistente lokale Reihenfolge/Sichtbarkeit;
- **Mit Windows starten** über HKCU-Autostart via unsichtbarem WScript/VBS-Launcher ohne UAC;
- **systemweites Standard-Startziel** über autorisierte Default-Set/Clear-Tasks;
- einmaliger SYSTEM-Default-Restore 30 Sekunden nach jedem Windows-Systemstart;
- **Windows neu starten** im Popup und im Tray-Kontextmenü.

## Historischer Task „Lenovo Boot Menu Next“

Ab v0.2.22 ist dieser Task kein paralleler Dauermechanismus mehr. Beim einmaligen Reparatur-/Migrationslauf wird sein bisheriges Verhalten als Fallback für den initialen Systemstandard berücksichtigt. Nach erfolgreicher Validierung der neuen Default-Aufgaben wird `Lenovo Boot Menu Next` entfernt und anschließend ausschließlich `LenovoBootMenu-Default-Restore` verwendet.

## Noch offen

- vollständige Diagnose-ZIPs bei **jedem** relevanten Laufzeitfehler der Tray-App;
- native Windows-Abnahme der v0.2.26-UI-/Performanceänderungen: Kontextmenü-Rahmen/Hover, eigener Neustartdialog, Marker-Tooltips sowie tatsächliche Zeit bis zur sichtbaren Boot-Auswahl und Hintergrund-Refreshdauer; außerdem weiterhin Legacy-Task-/Default-/Cleanup-Regressionsprüfung.

## Deinstallation/Bereinigung der privilegierten Aufgaben

Im Tray-Kontextmenü steht unter **„Wartung“** die Aktion **„Privilegierte Aufgaben entfernen…“** zur Verfügung. Nach Bestätigung und UAC werden gezielt entfernt:

- `Lenovo Boot Menu Next`;
- `Lenovo Boot Menu Tray Autostart` als historischer Scheduled-Task-Autostart, falls noch vorhanden;
- `LenovoBootMenu-RefreshManager`;
- `LenovoBootMenu-RefreshFirmware`;
- alle `LenovoBootMenu-Set-<GUID>`;
- alle `LenovoBootMenu-Default-Set-<GUID>`;
- `LenovoBootMenu-Default-Clear`;
- `LenovoBootMenu-Default-Restore`;
- bekannte Probe-/Test-Tasks (`AclProbe`, `ElevationProbe`, `SystemReadProbe`, `SystemExecProbe`, `SystemBaseline`, `LenovoBootMenuBroker-SystemProbe`);
- der historische `LenovoBootMenuBroker`-Service/Program-Files-Prototyp, falls noch vorhanden;
- `C:\ProgramData\Lenovo Boot Menu\TaskBroker` einschließlich Default-State und Metadaten.

Die aktuelle HKCU-Run-Autostart-Einstellung der Tray-App wird **nicht** entfernt. Firmware-Boot-Einträge und `displayorder` bleiben unangetastet.

## Build

- Tray: Windows PowerShell 5.1 / WinForms
- privilegierter Pfad: Windows Task Scheduler + Microsoft `bcdedit.exe`
- keine eigene SYSTEM-EXE im Paket


## v0.2.8 – Task-ACL-Korrektur

- Behebt einen konkreten ACL-Erkennungsfehler aus v0.2.5–v0.2.7: Die Benutzer-SID kann bereits im Group-Feld (`G:<SID>`) des Task-Security-Descriptors stehen. Die alte Prüfung suchte nur nach der SID als Text und hielt dies fälschlich für eine vorhandene Benutzer-ACE.
- v0.2.8 prüft ausschließlich die DACL und verlangt eine echte `AccessAllowed`-ACE mit `GENERIC_READ + GENERIC_EXECUTE` für die Benutzer-SID.
- Das Setzen der Berechtigung erfolgt strukturiert über `RawSecurityDescriptor`/`CommonAce` und wird per Read-back verifiziert.
- Der Installer meldet nur noch SUCCESS, wenn jede privilegierte Aufgabe die echte Read+Execute-ACE besitzt. Andernfalls wird ein Diagnose-ZIP erzeugt.
- Vorhandene v0.2.7-Tasks werden bei der Reparatur wiederverwendet; ihre ACL wird repariert, statt alle Tasks neu anzulegen.
