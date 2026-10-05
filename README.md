# Lenovo Boot Selector

<p align="center">
  <img src="icon-preview.png" alt="Lenovo Boot Selector" width="96">
</p>

**Lenovo Boot Selector** ist eine Windows-Tray-Anwendung für Lenovo-Systeme, mit der vorhandene Firmware-Startziele komfortabel als **einmaliges nächstes Bootziel** ausgewählt werden können.

Die Anwendung läuft im Normalbetrieb **uneleviert**. Privilegierte Firmwareänderungen werden ausschließlich über fest definierte, allowgelistete Windows-Scheduled-Tasks ausgeführt. Permanente Änderungen an der UEFI-Bootreihenfolge gehören ausdrücklich nicht zum Produktmodell.

**Aktueller Entwicklungsstand:** v0.5.7.2  
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

Der Updater arbeitet ausschließlich auf ausdrückliche Nutzeraktion. Es gibt **kein periodisches Polling und keinen automatischen Update-Check beim Start**.

Die Prüfung liest `downloads/latest.json` aus dem fest eingebauten GitHub-Repository. Eine neue Version wird nur akzeptiert, wenn Manifest, semantische Version, Dateiname, Tag, Größe, SHA-256 und Paketdateiliste valide sind. Das heruntergeladene ZIP wird vor dem Entpacken nochmals gegen Größe und SHA-256 geprüft. Die Installation läuft uneleviert mit lokalem Backup und Rollback; anschließend startet die App über den vorhandenen VBS-Launcher neu.

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
| `LenovoBootMenuTray.ps1` | deterministisch erzeugte Single-File-Runtime |
| `src/Core/` | zustandsfreie Fachlogik / Functional Core |
| `src/Application/` | Anwendungs- und Workflowlogik |
| `src/Infrastructure/` | Windows-, Storage-, Update-, TaskBroker- und IO-Adapter |
| `src/UI/` | WinForms-Präsentation |
| `tests/` | PowerShell- und Python-Regressions-/Boundary-Tests |
| `tools/` | Build-, Packaging-, Audit- und Transition-Skripte |
| `downloads/` | historische versionierte Release-ZIPs und Update-Manifeste |

## Entwicklung und Tests

Der zentrale native Windows-PowerShell-5.1-Testwrapper ist:

```powershell
.\tests\Test-WindowsPowerShell51.ps1
```

Build- und Packaging-Helfer liegen unter `tools/`. Die ausführliche Versionshistorie befindet sich in [CHANGELOG.md](CHANGELOG.md).
