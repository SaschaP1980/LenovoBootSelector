# Lenovo Boot Selector

<p align="center">
  <img src="bin/icon-preview.png" alt="Lenovo Boot Selector" width="96">
</p>

**Lenovo Boot Selector** ist eine Windows-Tray-Anwendung für Lenovo-Systeme, mit der vorhandene Firmware-Startziele komfortabel als **einmaliges nächstes Bootziel** ausgewählt werden können.

Die Anwendung läuft im Normalbetrieb **uneleviert**. Privilegierte Firmwareänderungen werden ausschließlich über fest definierte, allowgelistete Windows-Scheduled-Tasks ausgeführt. Permanente Änderungen an der UEFI-Bootreihenfolge gehören ausdrücklich nicht zum Produktmodell.

Ab v0.6.4.0 ist diese Grenze zusätzlich technisch fail-closed gehärtet: Der Runtime-TaskBroker akzeptiert keine freien Tasknamen mehr, sondern nur feste Operationsarten; zielbezogene Tasknamen werden ausschließlich aus validierten, installierten Firmware-GUIDs abgeleitet. TaskBroker-State und Metadaten sind für normale Benutzer read-only, und die Task-DACL wird auf ausschließlich Read+Execute geprüft bzw. repariert. Der kanonische Vertrag ist in [docs/SECURITY_BOUNDARY.md](docs/SECURITY_BOUNDARY.md) dokumentiert.

**Einmalige Wartung nach dem Update auf v0.6.4.0:** vorhandene TaskBroker-Installationen mit Schema 0.2.12 werden absichtlich nicht weiter vertraut. Unter **Wartung → Systemfunktionen reparieren…** muss einmal der erhöhte Reparaturpfad ausgeführt werden; dadurch werden Schema 0.2.13 und die gehärteten ACLs installiert.

**Aktueller Entwicklungsstand:** v0.6.4.0  
**Technik:** Windows PowerShell 5.1 · WinForms · Windows Task Scheduler · `bcdedit.exe`

## Downloads und Revisionshistorie

Versionierte Builds liegen im Ordner [`downloads/`](downloads/). Jede produktive Source-Revision, die einen neuen Build erfordert, bekommt ein neues versioniertes Release-ZIP. Bereits veröffentlichte Builds bleiben historisch erhalten.

Die neueste maschinenlesbare Updateinformation liegt in [`downloads/latest.json`](downloads/latest.json). Die fachliche Versionshistorie steht in [CHANGELOG.md](CHANGELOG.md).

Versionsschema: **MAJOR.MINOR.PATCH.HOTFIX**. Historische dreiteilige Versionen werden für Vergleiche als `HOTFIX = 0` behandelt.

## Funktionen

- Auswahl eines vorhandenen Firmware-Startziels für den **nächsten Start**
- übersichtliche Tray-/Popup-Oberfläche im Lenovo-Schwarz/Rot-Stil
- benutzerfreundliche Namen für bekannte Firmwareziele
- persistentes Standard-Startziel über den abgesicherten TaskBroker
- direkter Windows-Neustart aus der Anwendung
- Autostart ohne sichtbares PowerShell-/CMD-Fenster
- Verwaltung von Reihenfolge und Sichtbarkeit der angezeigten Startziele
- read-only Erkennung von Firmware-Zieldrift
- read-only Storage-Kontext für interne NVMe- und USB-Medien
- Diagnose-Export und Wartungsfunktionen
- manueller Self-Updater mit **„Auf neue Version prüfen…“** und **„App aktualisieren…“**

## Update-Funktion

Beim Start jedes neuen Tray-Prozesses wird **genau einmal** automatisch read-only geprüft, ob eine neuere App-Version verfügbar ist. Das erneute Öffnen des Popups löst keinen weiteren Check aus; es gibt weiterhin **kein periodisches Polling**. Wird eine neue Version gefunden, zeigt der Popup-Header – solange kein Bootziel-Refresh läuft – **„Neue App-Version verfügbar“**. Während eines Bootziel-Refreshs hat **„Aktualisiere Bootziele…“** Vorrang und danach erscheint die Update-Meldung wieder.

Die Prüfung liest `downloads/latest.json` aus dem fest eingebauten GitHub-Repository. Eine neue Version wird nur akzeptiert, wenn Manifest, semantische Version, Dateiname, Tag, Größe, SHA-256 und Paketdateiliste valide sind. Der automatische Startcheck lädt oder installiert nichts. Download und Installation bleiben ausschließlich explizite Nutzeraktionen über den bestehenden manuellen Updatepfad. Das heruntergeladene ZIP wird vor dem Entpacken nochmals gegen Größe und SHA-256 geprüft. Die Installation läuft uneleviert mit lokalem Backup und Rollback; anschließend startet die App über den vorhandenen VBS-Launcher neu.

Ab v0.6.3.1 ist **„Neue App-Version verfügbar“** im Popup-Header direkt bedienbar. Hover und Tastaturfokus heben den Hinweis Lenovo-rot hervor; Klick, Enter oder Leertaste öffnen den vorhandenen Dialog **„Neue App-Version verfügbar“**. Der Header verwendet dabei ausschließlich das bereits validierte Update-Manifest und startet keinen weiteren Versionscheck. Während eines Bootziel-Refreshs oder einer Wartungsaktion bleibt der Hinweis nicht interaktiv.

Ab v0.6.3.0 ist die Netzwerkseite des Updaters in `src/Infrastructure/UpdateTransport.ps1` gekapselt. Runtime-Diagnosen unterscheiden Transportfehler strukturiert von Manifest-, Paket-, Hash-, Installations- und Restartfehlern. Bei Netzwerkfehlern werden zusätzlich Fehlerklasse und `WebExceptionStatus` erfasst. Der Sicherheitsvertrag bleibt unverändert: feste HTTPS-Quelle, fail-closed Manifest-/Paketprüfung, unelevierte Ausführung und kein periodisches Polling.

Ab v0.5.8.0 wird das Ergebnis eines Updateversuchs über den Prozessneustart hinweg gespeichert. Die neu gestartete App bestätigt einen Erfolg erst dann, wenn die tatsächlich laufende Version exakt der erwarteten Zielversion entspricht. Danach erscheint einmalig **„Update erfolgreich“**. Bei einem Installationsfehler wird nach Möglichkeit auf die vorherige Version zurückgerollt, diese erneut gestartet und einmalig **„Update fehlgeschlagen“** angezeigt. Das Ergebnis wird zusätzlich in die Runtime-Diagnose der neuen Sitzung übernommen. v0.5.8.1 ergänzt dabei die einmalige Rückwärtskompatibilität für das von älteren Updater-Helpern geschriebene Legacy-Ergebnisformat `success/message/utc`; ein Legacy-Erfolg wird nur bei einem echten Boolean-`success` akzeptiert, ohne eine nicht gespeicherte Zielversion zu erfinden.

Ab v0.5.9.0 bietet der Dialog **„Neue Version verfügbar“** zusätzlich **„Jetzt aktualisieren“** an. Der Button verwendet denselben bestehenden manuellen Updatepfad wie **Wartung → App aktualisieren…**; ein automatischer oder zweiter Updatekanal wird nicht eingeführt.

Der Updater verändert keine Firmware-, BCD- oder Scheduled-Task-Konfiguration. Änderungen an privilegierten Systemfunktionen bleiben weiterhin ausschließlich dem bestehenden expliziten Setup-/Repair-/Reinitialize-Pfad vorbehalten.

## Aktuelle Storage-Darstellung

### Interne NVMe-SSDs

Bei genau einer erkannten internen NVMe zeigt die aktuelle Version das physische Modell für den ersten internen Slot an. Auf dem bestätigten Zielsystem ergibt sich beispielsweise:

- **NVMe-SSD 1** — `Interne SSD: KXG8AZNV2T04 LA KIOXIA`
- **NVMe-SSD 2** — `Kein Laufwerk erkannt`

Sind mehrere interne NVMe-Laufwerke vorhanden, rät die Anwendung keine unbelegte Zuordnung zwischen Windows-Disk und Firmware-Slot.

### USB-Startmedien

Das Firmwareziel bleibt bewusst das generische **USB HDD**. Der physische Datenträger wird nur als read-only Storage-Befund angezeigt. Bei genau einem erkannten USB-Bootkandidaten erscheint beispielsweise `USB-Startmedium: SanDisk Extreme Pro USB4`.

Diese Anzeige behauptet **keine direkte 1:1-Adressierbarkeit** des physischen USB-Geräts durch den generischen Firmwareeintrag `USB HDD`.

## Sicherheitsmodell

- Die Tray-App läuft als normaler Benutzer.
- Privilegierte Änderungen laufen nur über fest eingerichtete SYSTEM-Scheduled-Tasks.
- Es werden keine freien Commands, Tasknamen, GUIDs, Boot####-Nummern oder Device Paths über die Privilege-Grenze übergeben.
- Es gibt keine eigene EXE, die als SYSTEM ausgeführt wird.
- Bootänderungen verwenden ausschließlich einen **one-shot Next-Boot-Pfad**.
- Die Anwendung ändert weder dauerhaft `{fwbootmgr} displayorder` noch die UEFI-`BootOrder`.
- Der Self-Updater ist vollständig uneleviert und besitzt keinen separaten privilegierten Updatekanal.

## Voraussetzungen

- Windows mit **Windows PowerShell 5.1**
- .NET/WinForms
- Lenovo-System mit über Windows sichtbaren Firmware-Bootzielen
- Administratorrechte nur für die einmalige Einrichtung bzw. Wartung der privilegierten Scheduled-Tasks

## Schnellstart

1. Release-ZIP aus `downloads/` laden und vollständig in einen **beschreibbaren Benutzerordner** entpacken.
2. `Start-LenovoBootMenuTray.cmd` starten.
3. Beim ersten Start die angebotene Einrichtung der Systemfunktionen über **Wartung** ausführen und die UAC-Abfrage bestätigen.
4. Danach das gewünschte Startziel im Popup auswählen.
5. Updates bei Bedarf manuell über **Wartung → Auf neue Version prüfen…** prüfen.

## Projektstruktur

| Pfad | Zweck |
| --- | --- |
| `bin/` | kanonische Runtime-/Release-Quelldateien, inklusive generierter Single-File-Runtime und `version.json` |
| `src/Core/` | zustandsfreie Fachlogik / Functional Core |
| `src/Application/` | Anwendungs- und Workflowlogik |
| `src/Infrastructure/` | Windows-, Storage-, Update-, TaskBroker- und IO-Adapter |
| `src/UI/` | WinForms-Präsentation |
| `tests/` | aktive kanonische Python-Gates, native PowerShell-Tests und Baseline-Daten |
| `tests-history/` | eingefrorene versionsgebundene Validatoren, nach Kategorie + Version benannt |
| `docs/architecture/` | kanonische und historische Architektur-Baselines |
| `audits/` | kanonische und historische Catch-Audits |
| `tools/` | Build-, Packaging-, Audit- und Transition-Skripte |
| `downloads/` | historische versionierte Release-ZIPs und Update-Manifeste |

## Entwicklung und Tests

Der zentrale native Windows-PowerShell-5.1-Testwrapper ist:

```powershell
.\tests\Test-WindowsPowerShell51.ps1
```

Build- und Packaging-Helfer liegen unter `tools/`. Die ausführliche Versionshistorie befindet sich in [CHANGELOG.md](CHANGELOG.md).
