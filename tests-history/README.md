# Historische Validatoren

Dieses Verzeichnis enthält eingefrorene, versionsgebundene Validatoren aus der Entwicklungsgeschichte des Lenovo Boot Selector. Sie sind **nicht** die aktuellen permanenten Release-Gates. Die aktuellen Gates liegen unter [`../tests/`](../tests/).

## Namensschema

`<kategorie>-v<version>.py`

Kategorien:

- `release` – damalige Release-/Integritätsabnahme
- `core` – damalige Kern-/Modulprüfung
- `boundary` – damalige Architektur-/Privilege-Grenzen
- `regression` – damaliger versionsbezogener Regressionsvergleich

Beispiele:

- `release-v0.4.0.py`
- `core-v0.5.1.py`
- `boundary-v0.5.8.1.py`
- `regression-v0.5.9.1.py`

Die Python-Dateien wurden beim Aufräumen byteidentisch aus `tests/validate_v*.py` übernommen. Sie liegen weiterhin genau eine Verzeichnisebene unter dem Repository-Root, damit ihre bestehende `ROOT_DEFAULT = Path(__file__).resolve().parents[1]`-Semantik erhalten bleibt.
