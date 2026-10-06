# Teststruktur

`tests/` enthält ausschließlich die **aktiven, kanonischen Tests** und die von ihnen benötigten Baseline-Daten. Versionsgebundene historische Validatoren liegen getrennt unter [`../tests-history/`](../tests-history/).

## Permanente Python-Gates

| Datei | Kategorie | Zweck |
| --- | --- | --- |
| `validate_release.py` | Release | Release-, Packaging-, Source- und Repository-Invarianten |
| `validate_core.py` | Core | fachliche Kernlogik und modulare Kernverträge |
| `validate_boundary.py` | Boundary | Architektur-, Privilege- und Modulgrenzen |
| `validate_regression.py` | Regression | Vergleich des aktuellen Stands mit der freigegebenen Basis |

Diese vier Dateien sind die permanenten Python-Gates des GitHub-Release-Orchestrators.

## Native Windows-/PowerShell-Tests

| Datei | Kategorie | Zweck |
| --- | --- | --- |
| `Test-FunctionalCore.ps1` | Core | Parser, Settings und fachliche Kernfunktionen |
| `Test-UpdateCore.ps1` | Core | Update-Modell, Transport-Fehlervertrag und Update-Verträge |
| `Test-RefreshRuntime.ps1` | Runtime | Background-Refresh-State und Request-Lifecycle |
| `Test-MaintenanceRuntime.ps1` | Runtime | Maintenance-State und Modi |
| `Test-SingleInstanceMutex.ps1` | Runtime | Single-Instance-/Mutex-Lifecycle |
| `Test-BootTargetDrift.ps1` | Safety | Drift-Erkennung und fail-closed Zustände |
| `Test-TaskBrokerBoundary.ps1` | Safety | LBS-6 Fixed-Task-/Metadata-Boundary ohne privilegierte Ausführung |
| `Test-ArchitectureSoak.ps1` | Soak | wiederholte Architektur-/State-Stabilität |
| `Test-WindowsPowerShell51.ps1` | Compatibility | Windows PowerShell 5.1 Parser-/Encoding-Gate und nativer Sammelrunner |

## Baseline-Daten

- `characterization-baseline-v0.3.4.json` – historische Characterization-Basis.
- `taskbroker-baseline-v0.4.1.json` – TaskBroker-Basis.
- `ui-baseline-v0.4.3.json` – UI-Basis.

Die Baselines bleiben bewusst in `tests/`, weil vorhandene historische Validatoren diese Pfade weiterhin verwenden.

## Native Assertion-Count-Verträge

Native PowerShell-Suites verwenden bewusst unterschiedliche Count-Strategien; ein pauschaler Regex-/Call-Site-Zähler ist nicht für jede Suite korrekt.

| Suite | Strategie |
| --- | --- |
| `Test-UpdateCore.ps1` | **AST-self-audit + fester Coverage-Guard.** PowerShell zählt die `Assert-True`-/`Assert-Equal`-Command-ASTs, vergleicht sie mit den tatsächlich ausgeführten `$checks` und verlangt zusätzlich bewusst exakt 62. Das permanente Release-Gate prüft denselben Vertrag statisch. |
| `Test-RefreshRuntime.ps1` | Straight-line: fester Laufzeitzähler 18. |
| `Test-TaskBrokerBoundary.ps1` | Straight-line: fester Laufzeitzähler 23. |
| `Test-BootTargetDrift.ps1` | Straight-line: fester Laufzeitzähler 13. |
| `Test-SingleInstanceMutex.ps1` | Explizite manuelle Inkremente; fester Fail-Guard 4. |
| `Test-MaintenanceRuntime.ps1` | Loop-derived: 15 Laufzeitchecks aus statischen und pro Modus wiederholten Assertions. |
| `Test-ArchitectureSoak.ps1` | Vier aggregierte Soak-Assertions; jede Assertion umfasst viele Iterationen. |
| `Test-FunctionalCore.ps1` | Dynamische PASS-Zählung; derzeit kein separater Coverage-Sollzähler. |
| `Test-WindowsPowerShell51.ps1` | Sammelrunner/Parser-Gate; Dateizahl ist dynamisch und kein Assertion-Coverage-Count. |

Bei neuen Assertions muss der jeweilige Vertrag bewusst angepasst werden. Insbesondere darf beim Update-Test der feste `62`-Guard nicht automatisch aus der Source-Anzahl abgeleitet werden: Er ist ein zusätzlicher Change-Control-Guard, damit eine Suite-Erweiterung nicht unbemerkt durchrutscht.
