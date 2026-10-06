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
| `Test-UpdateCore.ps1` | Core | Update-Modell und Update-Verträge |
| `Test-RefreshRuntime.ps1` | Runtime | Background-Refresh-State und Request-Lifecycle |
| `Test-MaintenanceRuntime.ps1` | Runtime | Maintenance-State und Modi |
| `Test-SingleInstanceMutex.ps1` | Runtime | Single-Instance-/Mutex-Lifecycle |
| `Test-BootTargetDrift.ps1` | Safety | Drift-Erkennung und fail-closed Zustände |
| `Test-ArchitectureSoak.ps1` | Soak | wiederholte Architektur-/State-Stabilität |
| `Test-WindowsPowerShell51.ps1` | Compatibility | Windows PowerShell 5.1 Parser-/Encoding-Gate und nativer Sammelrunner |

## Baseline-Daten

- `characterization-baseline-v0.3.4.json` – historische Characterization-Basis.
- `taskbroker-baseline-v0.4.1.json` – TaskBroker-Basis.
- `ui-baseline-v0.4.3.json` – UI-Basis.

Die Baselines bleiben bewusst in `tests/`, weil vorhandene historische Validatoren diese Pfade weiterhin verwenden.
