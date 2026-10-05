# Build-Revisionshistorie

Dieser Ordner enthält die **historisch erhaltenen gebauten Releases** des Lenovo Boot Selector.

## Regel

- Jede produktive Source-Revision, die einen neuen Build erfordert, erhält eine neue Version.
- Das zugehörige versionierte Release-ZIP wird zusätzlich in diesem Ordner abgelegt.
- Bereits vorhandene Builds werden nicht gelöscht oder durch neuere Versionen ersetzt.
- Reine Dokumentations-/Repository-Änderungen ohne produktive Source-Änderung erzeugen kein neues Build.
- Jede gebaute Version erhält einen unveränderlichen Git-Tag `vMAJOR.MINOR.PATCH.HOTFIX`.
- `latest.json` ist das maschinenlesbare Manifest für die manuelle Update-Funktion; `releases.json` führt die Build-Historie.

## Builds

| Version | Release | Größe | SHA-256 | Git-Tag |
| --- | --- | ---: | --- | --- |
| v0.5.8.1 | [LenovoBootMenuTray-v0.5.8.1.zip](LenovoBootMenuTray-v0.5.8.1.zip) | 87.219 Bytes | `0481e8500dee26d00af4c193893f41b48cd48720eb78ed0c7887a9b2b947b74e` | `v0.5.8.1` |
| v0.5.8.0 | [LenovoBootMenuTray-v0.5.8.0.zip](LenovoBootMenuTray-v0.5.8.0.zip) | 86.400 Bytes | `16b7f881b48b4a692e5fb7c2cff9d7ae67cfd5c48a3735a8fbe17e6a83a5e0ba` | `v0.5.8.0` |
| v0.5.7.2 | [LenovoBootMenuTray-v0.5.7.2.zip](LenovoBootMenuTray-v0.5.7.2.zip) | 84.909 Bytes | `01b5f2e2af26b64f473ae14547780301ca9b7e6f065af1b1a19ec9c4d38a985c` | `v0.5.7.2` |
| v0.5.7.1 | [LenovoBootMenuTray-v0.5.7.1.zip](LenovoBootMenuTray-v0.5.7.1.zip) | 84.906 Bytes | `275aa4177188253fadc983f80dde87c9d950d56f229fb0be12f5aca37d414a90` | `v0.5.7.1` |
| v0.5.7 | [LenovoBootMenuTray-v0.5.7.zip](LenovoBootMenuTray-v0.5.7.zip) | 84.801 Bytes | `a5eab1a2a902f1572dbecea00093e75e625453b9a6683573215652e05e8d0f8f` | `v0.5.7` |
| v0.5.6 | [LenovoBootMenuTray-v0.5.6.zip](LenovoBootMenuTray-v0.5.6.zip) | 84.794 Bytes | `105f565acab53b1b3f142cdcfcb6bcd6433d330ae117c52b221aab472dab0ffc` | `v0.5.6` |
| v0.5.5 | [LenovoBootMenuTray-v0.5.5.zip](LenovoBootMenuTray-v0.5.5.zip) | 84.797 Bytes | `8720b71aa04a0a7f97d034225b137eea7472a13e329767dec1edc1db7910660d` | `v0.5.5` |
| v0.5.4 | [LenovoBootMenuTray-v0.5.4.zip](LenovoBootMenuTray-v0.5.4.zip) | 108.509 Bytes | `d31be8d7768e436aebfb4d4b620770b7e71ab3a86159014142eaf7f71e1f0e7d` | `v0.5.4` |
