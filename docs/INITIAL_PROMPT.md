# Lenovo Boot Selector – Initial Prompt

> **Einziger Einstieg für einen neuen Chat**
>
> Wenn der Nutzer in einem neuen Chat nur sagt:
>
> `Lies https://github.com/SaschaP1980/LenovoBootSelector/tree/main/docs/INITIAL_PROMPT.md`
>
> dann ist diese Datei als **Arbeitsauftrag zum vollständigen Projekt-Bootstrap** zu verstehen. Lies sie vollständig und führe die unten beschriebenen Schritte unmittelbar aus. Verlange vom Nutzer nicht, die bisherige Chat-Historie, Release-Regeln oder Architektur erneut zu erklären.

## 1. Auftrag und Repository

Repository:

`SaschaP1980/LenovoBootSelector`

Arbeite immer gegen den **aktuellen GitHub-`main`**, nicht gegen Erinnerungen, alte Chat-Zusammenfassungen, frühere Source-ZIPs oder einen möglicherweise veralteten Handover-Stand.

Wenn ein GitHub-Connector verfügbar ist, verwende ihn für Repository-, Issue-, PR-, Workflow- und Commit-Arbeit. Änderungen am Repository müssen gegen den aktuellen Stand abgesichert werden; bei konkurrierenden Änderungen nicht raten oder blind überschreiben.

## 2. Bootstrap – immer zuerst ausführen

Bevor du eine fachliche Änderung planst oder implementierst:

1. Lies den aktuellen `main`-Commit inklusive SHA und Tree.
2. Lies diese Datei aus dem aktuellen `main`.
3. Lies **vollständig**:
   - `docs/GITHUB_HOWTO.md`
   - `docs/RELEASE_PROCESS.md`
   - `tests/README.md`
   - `bin/version.json`
4. Lies die ausführbaren Release-Verträge:
   - `.github/workflows/candidate-preflight.yml`
   - `.github/workflows/release.yml`
   - `tools/candidate_preflight.py`
   - `tools/release_verification.py`
   - `tests/validate_release.py`
   - `tests/validate_core.py`
   - `tests/validate_boundary.py`
   - `tests/validate_regression.py`
5. Wenn der Nutzer ein LBS-Issue, eine Issue-Nummer oder eine konkrete geplante Funktion nennt, lies das **aktuelle GitHub Issue vollständig**, einschließlich Status, Labels, Kommentare und Akzeptanzkriterien.
6. Prüfe vor jeder Umsetzung, ob `main` seit dem ersten Snapshot weitergelaufen ist. Wenn ja, aktualisiere die Grundlage.
7. Erst danach Scope, Zielversion, Releaseprofil und konkrete Dateiliste festlegen.

Wenn der Nutzer nur diese Datei lesen lässt und noch keine konkrete Aufgabe nennt, führe den Bootstrap vollständig aus und melde anschließend knapp:
- aktuelles `main`-SHA,
- aktuelle Version,
- ob der Releasepfad konsistent lesbar ist,
- dass du arbeitsbereit bist.

Beginne **keine beliebige Backlog-Aufgabe eigenmächtig**, wenn der Nutzer noch keinen Scope genannt hat.

## 3. Autoritätsreihenfolge

Bei Widersprüchen gilt, von stark nach schwach:

1. aktueller GitHub-`main`, insbesondere ausführbare Workflows, Tools und Validatoren;
2. aktuelle normative Dokumente `docs/GITHUB_HOWTO.md` und `docs/RELEASE_PROCESS.md`;
3. aktuelle GitHub Issues einschließlich Kommentare;
4. Handover-Dokumente;
5. Chat-Historie oder Modellgedächtnis.

Ein Handover ist Einstiegshilfe, **nicht Source of Truth**. Alte Gesprächsinformationen dürfen nie einen aktuelleren Repository-Zustand überschreiben.

## 4. Bedeutung von Nutzerbefehlen

Im Projekt gilt standardmäßig:

- **„Implementiere …“**
- **„Baue …“**
- **„Baue die nächste Version …“**

bedeutet, sofern der Nutzer nicht ausdrücklich etwas anderes sagt:

**analysieren → implementieren → testen → Candidate vorbereiten → Candidate Preflight → GitHub Release → PR/Merge → Post-Release-Verifikation → Issue-Abschluss.**

Frage nicht noch einmal separat, ob gebaut oder veröffentlicht werden soll, wenn der Nutzer bereits eindeutig „Implementiere“ oder „Baue“ gesagt hat.

Ein reiner Analyse-/Planungswunsch ohne Build-Freigabe ist davon ausgenommen.

## 5. Versionsschema und Issue-Regeln

Versionsschema:

`MAJOR.MINOR.PATCH.HOTFIX`

Vor der Umsetzung gilt:

- **MAJOR:** relevantes GitHub Issue zwingend.
- **MINOR:** relevantes GitHub Issue zwingend.
- **PATCH:** relevantes GitHub Issue zwingend.
- **HOTFIX:** Issue optional, wenn es eine enge, eindeutig abgegrenzte Korrektur ist und kein bestehendes Issue den Fall bereits abdeckt.

Wenn ein veröffentlichter Fehler eine direkte Regression oder unvollständige Umsetzung eines bestehenden Issues ist, **das ursprüngliche Issue wieder öffnen**, Ursache/Hotfix dokumentieren, Priorität neu bewerten und erst nach erfolgreichem Hotfix wieder als `completed` schließen.

Offene Issues sollen genau ein `priority:*`-Label besitzen.

## 6. Releaseprofile

Es gibt nur zwei aktive Releaseprofile:

### `version-only`

Verwenden, wenn Produktcode unter `src/**` unverändert bleibt.

Die Regression verlangt dann strikte Produkt-Source-Identität zur vorherigen kanonischen Source-Basis, abgesehen von der deterministisch injizierten Versionsnummer.

### `patch`

Verwenden, wenn Produktcode unter `src/**` fachlich geändert wird.

Das historische Profil `release-architecture` ist entfernt und darf nicht wieder als aktives Profil verwendet werden.

## 7. Pflichtdateien für jede veröffentlichte Version

Jede tatsächlich veröffentlichte Version braucht **vor dem Candidate**:

1. die neue Version in `bin/version.json`;
2. einen passenden Abschnitt in `CHANGELOG.md`.

Das gilt ausdrücklich auch für:

- reinen Versionsbump;
- `version-only` Hotfix;
- Pipeline-/Performance-Messung;
- Release ohne fachliche Produktänderung.

Ein gewünschter „Hotfix, der nur die Version hochzählt“ bedeutet technisch mindestens:

`bin/version.json + minimaler passender CHANGELOG.md-Abschnitt`

`tools/prepare_release.py` erzwingt diesen Vertrag.

Außerdem müssen in `bin/version.json` korrekt gepflegt sein:

- `protectedFragmentIntent`
- `repositoryDeleteIntent`

Normalfall jeweils `[]`; niemals absichtlich geänderte geschützte Fragmente oder Löschungen verschweigen.

## 8. Sicherheitsgrenzen des Produkts

Diese Grenzen sind hart und dürfen nicht beiläufig abgeschwächt werden:

- Tray-App läuft uneleviert.
- Privilegierte Operationen ausschließlich über fest definierte, allowgelistete SYSTEM-Scheduled-Tasks.
- Keine freien Commands, freien Tasknamen, freien GUIDs, Boot####-Nummern, Device Paths oder anderen unkontrollierten Werte über die Privilege-Grenze.
- Bootänderungen ausschließlich **One-Shot Next Boot**.
- Keine permanente Mutation von `{fwbootmgr} displayorder` oder UEFI `BootOrder`.
- Keine eigene beliebige SYSTEM-EXE als Privilege-Kanal.
- Keine PnP-/Device-Arrival-Handler und kein Polling als USB-Erkennungsarchitektur.
- Keine behauptete physische USB→Firmware-Zuordnung ohne belastbare Read-only-Evidenz.
- BootService-, TaskBroker- und Storage-Grenzen erhalten.
- Self-Updater bleibt nutzergesteuert, uneleviert und ohne automatisches Download-/Install-Verhalten.

Bei Sicherheits-/Privilege-Unsicherheit **fail-closed**.

## 9. Atomare Candidate-Vorbereitung

Normales Release-Einstiegsmodell:

`1 exakter Candidate-SHA = 1 Releasebranch = 1 PR = 1 Merge`

Vor sichtbaren Branch-Refs:

1. aktuellen `main`-SHA/Tree verifizieren;
2. alle geplanten Dateiänderungen vollständig vorbereiten;
3. Blobs erzeugen;
4. einen Tree auf Basis des verifizierten `main` erzeugen;
5. einen Candidate-Commit erzeugen;
6. Commit/Diff einmal vollständig prüfen;
7. erst dann `candidate/v<version>` auf genau diesen SHA setzen.

Keine halbfertigen Zwischenzustände veröffentlichen.

Für normale Releases **niemals manuell `release/v<version>` erzeugen**. Das darf nur der erfolgreiche Candidate-Preflight.

## 10. Candidate Preflight

`.github/workflows/candidate-preflight.yml` ist das Release-Eingangstor.

Der Preflight prüft unter anderem:

- exakten Candidate-SHA;
- aktuellen `main` als gültige Basis;
- vorherigen kanonischen Source-Tag;
- deterministische Release-Vorbereitung;
- zwei byteidentische Builds;
- Release/Core/Boundary/Regression;
- exaktes `protectedFragmentIntent`;
- exaktes `repositoryDeleteIntent`;
- keine Änderung historischer Release-ZIPs;
- Runtime-Closure/Build-Verträge.

Bei Erfolg:

1. `preflight/candidate=success`;
2. `release/v<version>` wird auf **denselben SHA** gesetzt;
3. `release.yml` wird explizit per `workflow_dispatch` gestartet;
4. Candidate-Branch wird gelöscht.

Der explizite Dispatch ist notwendig, weil ein Push mit `GITHUB_TOKEN` keinen rekursiven Folgeworkflow zuverlässig auslöst.

Der erfolgreiche Preflight emittiert:

`CANDIDATE_PREFLIGHT_SUMMARY=<json>`

### Candidate-Fehler

Wenn Candidate Preflight scheitert:

- es darf noch keinen normalen Release geben;
- Ursache aus dem konkreten Job-Log lesen;
- minimale Korrektur auf **demselben Candidate-Branch** als Fast-Forward;
- keinen parallelen Candidate/Releasebranch anlegen;
- danach normal erneut prüfen lassen.

## 11. Release Orchestrator

`.github/workflows/release.yml` ist die Publikationsautorität.

Er verlangt zunächst:

- erfolgreichen `preflight/candidate`-Status;
- aktuellen `main` als Ancestor;
- noch nicht vorhandenen Ziel-Tag.

Danach:

1. GitHub-eigenen `publishedUtc` erfassen;
2. Release + Source-Paket deterministisch bauen;
3. zweiten unabhängigen Build erzeugen;
4. beide Outputs byteidentisch vergleichen;
5. permanente Release/Core/Boundary/Regression-Gates erneut ausführen;
6. ZIP-/cache-freien exakten Source-Commit ableiten;
7. exakt ein neues historisches Release-ZIP hinzufügen;
8. Publication-Commit auf Releasebranch erzeugen;
9. Release-Statuskontexte auf finalen PR-Head schreiben;
10. genau einen PR erzeugen;
11. annotierten Source-Tag erzeugen;
12. `release/tag` setzen;
13. PR mergen und Releasebranch löschen;
14. vollständige Post-Release-Verifikation ausführen.

Historische `downloads/*.zip` sind **immutable**. Ein Release darf genau ein neues ZIP hinzufügen; bestehende ZIPs nicht verändern oder löschen.

## 12. Die acht Release-Gates

Der finale PR-Head muss exakt diese acht erfolgreichen Release-Kontexte besitzen:

- `release/source-integrity`
- `release/core`
- `release/boundary`
- `release/regression`
- `release/package`
- `release/reproducibility`
- `release/history`
- `release/tag`

Ein grüner Workflow allein reicht als Akzeptanzbegründung nicht; die acht Kontexte sind Teil des Vertrags.

## 13. Gebündelte Post-Release-Verifikation

Ab LBS-16 bündelt `tools/release_verification.py` die Abschlussprüfung.

Ein erfolgreicher Release emittiert:

`RELEASE_VERIFICATION_SUMMARY=<json>`

Dieser Summary bestätigt unter anderem:

- Version;
- Candidate-SHA;
- Candidate-Preflight erfolgreich;
- finalen PR-Head;
- genau einen Publication-PR;
- PR-Nummer und Merge-Commit;
- `main`-SHA nach Merge;
- Source-Tag und Source-Commit;
- 8/8 Release-Gates;
- Release-ZIP Name, Größe, SHA-256;
- Source-ZIP Name, Größe, SHA-256;
- Source-Tree ZIP-frei;
- Source-Tree cache-frei;
- Candidate-Branch gelöscht;
- Release-Branch gelöscht;
- `downloads/latest.json` konsistent;
- veröffentlichtes Release-ZIP konsistent;
- Reproduzierbarkeit erfolgreich;
- historische ZIP-Integrität erfolgreich.

Wenn der Workflow terminal `success` ist und `RELEASE_VERIFICATION_SUMMARY.result == "PASS"`, nutze diesen aggregierten Datensatz für die bestätigten Endfakten. Rekonstruiere dieselben Fakten nicht noch einmal über viele redundante Connector-Abfragen.

Wenn Summary fehlt, unvollständig ist oder nicht PASS meldet, gilt die vollständige direkte Post-Release-Prüfung aus `docs/GITHUB_HOWTO.md`.

## 14. Performance-/Roundtrip-Regeln

Release-Sicherheit wird **nicht** für Geschwindigkeit reduziert.

Bevorzugter Ablauf:

- Ausgangsdaten parallel/gebündelt lesen;
- unveränderte Fakten innerhalb derselben SHA-Phase wiederverwenden;
- Änderungen in einem atomaren Candidate vorbereiten;
- nicht aggressiv pollen;
- Candidate nach Möglichkeit über einen Terminal-Read + Summary auswerten;
- Release über einen Terminal-Read + `RELEASE_VERIFICATION_SUMMARY` auswerten.

Ziel für einen kleinen konfliktfreien Release bei verfügbaren GitHub-Runnern: ungefähr **2–3 Minuten interaktive Orchestrierungszeit**. Die tatsächlich gemessene Pipeline kann deutlich darunter liegen.

### Runner Queue

Wenn ein GitHub-hosted Runner nach 60 Sekunden noch nicht zugewiesen ist:

- `EXTERNAL_QUEUE_WAIT` melden;
- Workflow nicht abbrechen;
- nicht erneut triggern;
- keinen No-op-Push;
- keinen zweiten Releasebranch;
- GitHub weiterlaufen lassen;
- später Terminalstatus prüfen.

## 15. Release-Fehler und Recovery

Ein fehlgeschlagener Workflow ist kein Anlass, ungeprüft einen zweiten parallelen Releasepfad zu eröffnen.

Bei einem korrigierbaren Fehler vor irreversiblen Publication-Side-Effects:

- konkretes Gate/Log lesen;
- minimale Korrektur;
- bestehenden vorgesehenen Branch/Releasepfad beibehalten;
- keine Doppel-PRs, Doppel-Tags oder parallelen Releasebranches erzeugen.

Die ausführbaren Workflows und `docs/GITHUB_HOWTO.md` haben für die konkrete Recovery Vorrang.

## 16. Tests

Die vier permanenten GitHub-Gates sind:

- `tests/validate_release.py`
- `tests/validate_core.py`
- `tests/validate_boundary.py`
- `tests/validate_regression.py`

`tests/README.md` beschreibt die aktive Testmatrix.

Historische Validatoren liegen in `tests-history/` und sind keine aktive Release-Auswahl.

### Native Windows-Tests

Native Windows-/PowerShell-5.1-Tests dürfen nur als **PASS** bezeichnet werden, wenn sie tatsächlich auf Windows ausgeführt wurden.

Ein Linux-/GitHub-Static-/Contract-Gate ist kein Ersatz für eine native Ausführung. Im Abschlussbericht ausdrücklich unterscheiden:

- automatisierte GitHub-/statische Tests;
- tatsächlich ausgeführte native Windows-Tests;
- native Tests, die noch offen sind.

## 17. GitHub-Issue-Lifecycle

Für Issue-getriebene Arbeit:

1. Issue vor der Umsetzung lesen.
2. Status/Labels/Akzeptanzkriterien mit aktuellem `main` abgleichen.
3. Relevante Root-Cause-/Scope-/Migrationsbefunde als knappe Issue-Kommentare dokumentieren.
4. Issue während der Umsetzung offen halten.
5. Nach erfolgreicher Veröffentlichung und Post-Release-Verifikation finalen Kommentar mit Version und PR hinzufügen.
6. Erst dann als `completed` schließen.

Ein Release darf nicht deshalb als erfolgreich gelten, weil das Issue geschlossen wurde; die technische Release-Verifikation kommt zuerst.

## 18. Dokumentations-only Änderungen

Eine reine Dokumentations-/Prozessänderung, die Produktcode, Runtime, Releaseinputs und Releasepakete nicht verändert, benötigt **keinen Produktversionsbump und keinen Release**.

Wenn sicher und konfliktfrei, darf sie atomar direkt auf aktuellem `main` committed werden. Vorher aktuellen `main` verifizieren und nur die beabsichtigten Docs-Dateien ändern.

## 19. Handover-Regel

Ein Handover muss mindestens die **vollständige aktuelle** `docs/GITHUB_HOWTO.md` aus dem kanonischen `main` enthalten.

Diese `INITIAL_PROMPT.md` ist der Bootstrap-Einstieg für neue Chats. Sie ersetzt aber nicht das erneute Lesen der aktuellen normativen Dokumente und Workflows.

## 20. Abschlussbericht nach einem Release

Nach einer vollständigen Umsetzung nenne präzise:

- was umgesetzt wurde;
- Zielversion;
- Candidate-/Release-Run;
- Test-Gesamtergebnisse;
- PR;
- finales `main`-SHA;
- Source-Tag/-Commit;
- Release-ZIP Größe + SHA-256;
- Source-ZIP SHA-256;
- Candidate-/Release-Branch-Cleanup;
- Issue-Status;
- welche nativen Windows-Tests tatsächlich ausgeführt wurden.

Keine Test-, Branch-, Hash-, Tag- oder Releasebehauptung ohne direkte Verifikation.

## 21. Verhalten nach diesem Bootstrap

Nach dem vollständigen Lesen dieser Datei und der referenzierten aktuellen Quellen:

- Arbeite ab dann nach dem rekonstruierten aktuellen Repository-Vertrag.
- Bitte den Nutzer nicht, alte Regeln erneut zu erklären.
- Verwende keine veraltete Projektversion aus Chatgedächtnis.
- Wenn der Nutzer anschließend z. B. `Implementiere LBS-XX` sagt, beginne unmittelbar mit Issue-Abgleich und End-to-End-Umsetzung nach diesem Prozess.
- Wenn eine neue reale Erkenntnis den dauerhaften GitHub-/Build-/Release-Prozess verändert, dokumentiere sie in den kanonischen Docs, damit der nächste Chat sie ebenfalls erhält.

