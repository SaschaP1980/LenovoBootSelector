# Build-Revisionshistorie

Dieser Ordner enthält die **historisch erhaltenen gebauten Releases** des Lenovo Boot Selector.

## Regel

- Jede produktive Source-Revision, die einen neuen Build erfordert, erhält eine neue Version.
- Das zugehörige versionierte Release-ZIP wird zusätzlich in diesem Ordner abgelegt.
- Bereits vorhandene Builds werden nicht gelöscht oder durch neuere Versionen ersetzt.
- Reine Dokumentations-/Repository-Änderungen ohne produktive Source-Änderung erzeugen kein neues Build.
- Jede gebaute Version erhält einen unveränderlichen Git-Tag `vX.Y.Z`.
- `latest.json` ist das maschinenlesbare Manifest für die manuelle Update-Funktion; `releases.json` führt die Build-Historie.

## Builds

| Version | Release | Größe | SHA-256 | Git-Tag |
| --- | --- | ---: | --- | --- |
| v0.5.6 | [LenovoBootMenuTray-v0.5.6.zip](LenovoBootMenuTray-v0.5.6.zip) | 84.794 Bytes | `105f565acab53b1b3f142cdcfcb6bcd6433d330ae117c52b221aab472dab0ffc` | `v0.5.6` |
| v0.5.5 | [LenovoBootMenuTray-v0.5.5.zip](LenovoBootMenuTray-v0.5.5.zip) | 84.797 Bytes | `8720b71aa04a0a7f97d034225b137eea7472a13e329767dec1edc1db7910660d` | `v0.5.5` |
| v0.5.4 | [LenovoBootMenuTray-v0.5.4.zip](LenovoBootMenuTray-v0.5.4.zip) | 108.509 Bytes | `d31be8d7768e436aebfb4d4b620770b7e71ab3a86159014142eaf7f71e1f0e7d` | `v0.5.4` |
