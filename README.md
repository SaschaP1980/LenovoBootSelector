# Lenovo Boot Selector

<p align="center">
  <img src="icon-preview.png" alt="Lenovo Boot Selector" width="96">
</p>

**Lenovo Boot Selector** ist eine Windows-Tray-Anwendung für Lenovo-Systeme, mit der vorhandene Firmware-Startziele komfortabel als **einmaliges nächstes Bootziel** ausgewählt werden können.

Die Anwendung läuft im Normalbetrieb **uneleviert**. Privilegierte Firmwareänderungen werden ausschließlich über fest definierte, allowgelistete Windows-Scheduled-Tasks ausgeführt. Permanente Änderungen an der UEFI-Bootreihenfolge gehören ausdrücklich nicht zum Produktmodell.

**Aktueller Entwicklungsstand:** v0.5.4  
**Technik:** Windows PowerShell 5.1 · WinForms · Windows Task Scheduler · `bcdedit.exe`

## Downloads und Revisionshistorie

Versionierte Builds liegen im Ordner [`downloads/`](downloads/).

**Aktueller Build:** [LenovoBootMenuTray-v0.5.4.zip](downloads/LenovoBootMenuTray-v0.5.4.zip)  
**SHA-256:** `d31be8d7768e436aebfb4d4b620770b7e71ab3a86159014142eaf7f71e1f0e7d`

Der Ordner dient als **Build-Revisionshistorie**: Sobald sich die produktive Source so ändert, dass eine neue Version gebaut werden muss, wird das neue versionierte Release-ZIP zusätzlich in `downloads/` abgelegt. Bereits veröffentlichte Builds bleiben historisch erhalten und werden nicht durch neuere Versionen ersetzt.

Reine Dokumentations- oder Repository-Pflege ohne Änderung der produktiven Source erzeugt kein künstliches neues Build. Die fachliche Versionshistorie wird zusätzlich im [CHANGELOG.md](CHANGELOG.md) fortgeführt.

## Funktionen

- Auswahl eines vorhandenen Firmware-Startziels für den **nächsten Start**
- übersichtliche Tray-/Popup-Oberfläche im Lenovo-Schwarz/Rot-Stil
- benutzerfreundliche Namen für bekannte Firmwareziele
- Anzeige des aktuell gesetzten einmaligen Bootziels
- persistentes Standard-Startziel über den abgesicherten TaskBroker
- direkter Windows-Neustart aus der Anwendung
- Autostart ohne sichtbares PowerShell-/CMD-Fenster
- Verwaltung von Reihenfolge und Sichtbarkeit der angezeigten Startziele
- read-only Erkennung von Firmware-Zieldrift
- read-only Storage-Kontext für interne NVMe- und USB-Medien
- Diagnose-Export und Wartungsfunktionen

## Aktuelle Storage-Darstellung

### Interne NVMe-SSDs

Bei genau einer erkannten internen NVMe zeigt die aktuelle Version das physische Modell für den ersten internen Slot an. Auf dem bestätigten Zielsystem ergibt sich beispielsweise:

- **NVMe-SSD 1** — `Interne SSD: KXG8AZNV2T04 LA KIOXIA`
- **NVMe-SSD 2** — `Kein Laufwerk erkannt`

Sind mehrere interne NVMe-Laufwerke vorhanden, rät die Anwendung keine unbelegte Zuordnung zwischen Windows-Disk und Firmware-Slot. Dafür ist zunächst eine belastbare Slotkorrelation erforderlich.

### USB-Startmedien

Das Firmwareziel bleibt bewusst das generische **USB HDD**. Der physische Datenträger wird nur als read-only Storage-Befund angezeigt.

Bei genau einem erkannten USB-Bootkandidaten erscheint beispielsweise:

- **Windows: Gaming**
- `USB-Startmedium: SanDisk Extreme Pro USB4`

Wichtig: Diese Anzeige bedeutet, dass das Medium eine erkannte Bootstruktur besitzt. Sie behauptet **keine direkte 1:1-Adressierbarkeit** dieses physischen USB-Geräts durch den generischen Firmwareeintrag `USB HDD`.

## Sicherheitsmodell

Der Lenovo Boot Selector trennt die normale Tray-Anwendung strikt von privilegierten Firmwareaktionen:

- Die Tray-App läuft als normaler Benutzer.
- Privilegierte Änderungen laufen nur über fest eingerichtete SYSTEM-Scheduled-Tasks.
- Es werden keine freien Commands, Tasknamen, GUIDs, Boot####-Nummern oder Device Paths über die Privilege-Grenze übergeben.
- Es gibt keine eigene EXE, die als SYSTEM ausgeführt wird.
- Bootänderungen verwenden ausschließlich einen **one-shot Next-Boot-Pfad**.
- Die Anwendung ändert weder dauerhaft `{fwbootmgr} displayorder` noch die UEFI-`BootOrder`.
- Erkannte Abweichungen führen nicht automatisch zu Reparatur- oder Firmwareaktionen.

## Voraussetzungen

- Windows mit **Windows PowerShell 5.1**
- .NET/WinForms
- Lenovo-System mit über Windows sichtbaren Firmware-Bootzielen
- Administratorrechte nur für die einmalige Einrichtung bzw. Wartung der privilegierten Scheduled-Tasks

Die normale Nutzung der Tray-App erfolgt anschließend ohne dauerhafte Administratorrechte.

## Schnellstart

1. Repository herunterladen oder klonen.
2. Die Dateien gemeinsam in einem Verzeichnis belassen.
3. `Start-LenovoBootMenuTray.cmd` starten.
4. Beim ersten Start die angebotene Einrichtung der Systemfunktionen über **Wartung** ausführen und die einmalige UAC-Abfrage bestätigen.
5. Danach das gewünschte Startziel im Popup auswählen.
6. Optional direkt über **Windows neu starten** neu booten.

Der Launcher verwendet den enthaltenen VBS-Pfad, damit beim Start kein dauerhaft sichtbares PowerShell- oder CMD-Fenster stehen bleibt.

## Projektstruktur

| Pfad | Zweck |
| --- | --- |
| `LenovoBootMenuTray.ps1` | deterministisch erzeugte Single-File-Runtime |
| `src/Core/` | zustandsfreie Fachlogik / Functional Core |
| `src/Application/` | Anwendungs- und Workflowlogik |
| `src/Infrastructure/` | Windows-, Storage-, TaskBroker- und IO-Adapter |
| `src/UI/` | WinForms-Präsentation |
| `tests/` | PowerShell- und Python-Regressions-/Boundary-Tests |
| `tools/` | Build-, Packaging-, Audit- und Transition-Skripte |
| `Install-LenovoBootMenuTasks.ps1` | Einrichtung der privilegierten Systemfunktionen |
| `Uninstall-LenovoBootMenuTasks.ps1` | gezielte Entfernung der projektspezifischen Systemfunktionen |

Die editierbare Source ist modular aufgebaut. Für das Release wird daraus weiterhin eine deterministische Single-File-Runtime erzeugt.

## Entwicklung und Tests

Das Repository enthält unter anderem Tests für:

- Functional Core
- Refresh-Lifecycle
- Single-Instance-Mutex
- Maintenance-Lifecycle
- Firmware-/Bootziel-Drift
- Architektur-Soak
- Windows-PowerShell-5.1-Kompatibilität
- versionsspezifische Regression-, Core- und Boundary-Verträge

Der zentrale native Test-Wrapper ist:

```powershell
.\tests\Test-WindowsPowerShell51.ps1
```

Build- und Packaging-Helfer liegen unter `tools/`.

## Bekannte technische Grenze bei USB

Auf dem untersuchten Lenovo-System zeigt das F12-Bootmenü physische USB-Laufwerke getrennt an. BCD, Standard-UEFI und die dokumentierten Lenovo-WMI-Schnittstellen exponieren softwareseitig jedoch nur das generische Ziel `USB HDD`.

Der Lenovo Boot Selector implementiert deshalb **keine unsichere oder undokumentierte direkte USB-Geräteadressierung** und verwendet keine permanente BootOrder-Manipulation als Ersatz.

## Versionshistorie

Die ausführlichen historischen Versionsnotizen befinden sich in [CHANGELOG.md](CHANGELOG.md).

## Hinweis zum Projektstatus

v0.5.4 ist die aktuelle kanonische Entwicklungsbasis. Die Source-, Regression- und Packaging-Prüfungen sind abgeschlossen; die native Windows-Abnahme des aktuellen v0.5.4-Scopes bleibt separat durchzuführen.
