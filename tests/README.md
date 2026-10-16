# Test structure

`tests/` contains only the **active canonical tests** and the baseline data they require. Version-specific historical validators are stored separately under [`../tests-history/`](../tests-history/).

## Pre-Candidate changelog language guard (v1.1.6.2)

The read-only `tools/pre_candidate_language_check.py` is mandatory on the final intended release tree **before** exposing a Candidate branch. It validates the exact current version in the first changelog heading, nonempty current release notes and English-looking prose throughout the repository. Run `python3 -B tools/pre_candidate_language_check.py --root .` and require `PRE_CANDIDATE_LANGUAGE_RESULT=PASS`.

Its deterministic `--self-test` covers a valid English Hotfix, German release notes, missing bullets, mismatched version headings and unrelated German Markdown. The permanent Release validator runs both the self-test and the actual check. Candidate Preflight and release preparation repeat the check fail-closed before building packages. This prevents another unnoticed German changelog from passing the repository pipeline, while the pre-exposure command avoids known-failing Candidate runs when followed. Language detection is heuristic and is not a formal translation-quality certificate.

## Diagnostics Worker conditional-deployment tests

`cloudflare/diagnostics-worker/tests/conditional-deploy.test.mjs` validates LBS-123 deployment fingerprints, successful-production-receipt guards, health-only versus deployment decisions, source/runtime workflow invariants and the pinned Windows upload contract. The trusted Worker job runs it through the existing complete Node test suite only when a new Worker deployment is required; hosted Work-Branch Diagnostics Worker CI runs it for changed backend sources. A version-only release with a verified matching live fingerprint instead takes the secret-free health-only path.

## LBS-30 assertion ownership and historical localization (v1.1.3.0)

The original LBS-23 validator has **32 assertions** and is archived byte-identically as `tests-history/localization-v0.8.0.0.py`. It no longer runs as a fifth active gate.

| Old LBS-23 assertion category | Count | Permanent owner |
| --- | ---: | --- |
| Preference schema/core migration and normalization | 8 | Core / native FunctionalCore and LocalizationRuntime |
| Settings persistence and restoration | 4 | Native LocalizationRuntime settings tests |
| Explicit locale service | 2 | Native locale selection, persistence and reload |
| Startup recovery locale | 2 | Native startup-recovery behavior and Release wiring check |
| UI choice-dialog migration | 3 | Native explicit choice/confirmation and Release dialog integration |
| Bilingual migration catalog keys | 3 | Three *new* native localization lookup tests (both locales) |
| Startup template composition and order | 2 | Permanent Release startup ordering and resolver integration checks |
| Source-text presence of six native test names | 6 | The actual six native migration tests executed on Windows, not tests-of-test-names |
| Exact natural-language document fragments | 2 | Existing Release/localization documentation contracts |

**Owners:** Release controls packaging, repository history, documentation, workflow integrity and distinct startup composition; Core controls pure module behavior; Boundary controls privilege/security and independently protects runtime/installer trust boundaries; Regression controls basis comparisons and declared change intent. Exactly **27** duplicate Release-owned source-literal assertions were removed from Regression. Existing independent TaskBroker/privilege assertions are intentionally preserved, not counted as redundant simply because of similar spelling.

**Gate execution is not assertion duplication.** The four permanent Python gates remain separately executed by Development Completion, Candidate and Release; the propagation validator remains mandatory and hosted Windows PowerShell 5.1 executes the native tests. Candidate 3/3, Release 8/8, reproducibility/history/ZIP and source-tag checks are unchanged. The original 74 LBS-13 historical validators remain; the archived LBS-23 file becomes the 75th, with a one-file deletion and byte-identical Git archive proof enforced by Release.

## LBS-130 / P1 — canonical native-test structural ownership (v1.1.4.0)

**Phase P1 only (P2/P3 remain open).** After LBS-30, the four permanent validators still repeated checks that a native TaskBroker test exists, is included in the same aggregate runner and contains the *names* of three ACL checks. Those checks all inspected the same test text rather than providing four independent behaviors. P1 removes **26 redundant static assertions** (Release 6, Core 6, Boundary 6, Regression 8), while retaining the actual privileged-operation/installer ACL predicates and independent Runtime/Core/Boundary/Release security-invariant checks.

**Single authoritative ownership:** `tools/validate_test_contracts.py` now checks that `Test-WindowsPowerShell51.ps1` *executes exactly once* each `Test-TaskBrokerBoundary.ps1` and `Test-TaskBrokerMigration.ps1` (anchored call shape, not a mere filename substring). It additionally verifies the executable native `Test-TaskBrokerBoundary.ps1` still contains exactly one each of the following *function calls and expected polarities*, independent of test label wording: `ReadAndExecute → Assert-False`, `Modify → Assert-True`, `FullControl → Assert-True`. Its fail-closed in-memory negative mutations simulate missing/duplicate suite calls and missing/reversed ACL test calls. Native hosted Windows PowerShell 5.1 still executes the original unchanged suites; no native check was removed or count relaxed.

| Contract | Before | After / owner |
| --- | --- | --- |
| TaskBroker Boundary/Migration aggregate registration | Three per-suite source-string observations across Release/Core/Boundary | Two authoritative anchored invocation checks in Contract Propagation, plus mandatory Windows execution |
| Three ACL native test-label presence checks | Three copies each in all four permanent Python validators (12 greps) | Three ACL invocation/polarity structural checks in Contract Propagation, native execution remains 25/25 |
| Native Boundary suite exists | Four static file-presence checks | Nonempty native source plus three structural checks in Contract Propagation, Windows runs unmodified |
| Duplicate native source AST/count checks | Regression repeated Release-owned update AST, update 79, mutex 4 and system capability 47 expectations | Release and Contract Propagation remain canonical for counts; native fixed-count and Windows summary remain authoritative |
| Four independent Python gate executables | Release/Core/Boundary/Regression | **All four retained** and executed independently |

**Expected static gate delta:** Release 442 → 436, Core 267 → 261, Boundary 176 → 170, Regression 184 → 176; Contract Propagation 50 → 55 because five focused structural protections replace repeated text presence checks. These are intended assertion-count changes, **not removed native test cases**. Hosted Windows parser **67/67**, functional **610/610** (TaskBroker Boundary 25/25, Migration 42/42) are expected unchanged. Any change to an existing native total must still be synchronized under LBS-40; this P1 change intentionally makes none.

**Deferred:** P2 owns UI/update/workflow Release–Regression duplicates. P3 owns authorization, ACL/schema and boot-security invariants across different trust surfaces. P1 does **not** consolidate them. A future cleanup may not reintroduce duplicate name-greps instead of using this single contract.

## LBS-130 / P2 — UI, update and pipeline assertion ownership (v1.1.5.0)

**Phase P2 only; P3 remains open.** A pre-change lexical/target audit on v1.1.4.0 identified **26 same-source, same-polarity duplicate assertions** between Release and Regression in the UI, update, localization, capability and workflow sources. An additional **five weaker or broad-scope Regression assertions** repeated stronger scoped Release invariants. P2 eliminates exactly **31 Regression assertions**, and no security/TaskBroker assertion, native test, release workflow or product-source file. The independent Regression baseline/intent logic remains, along with four separately executed Python gates.

| Domain / previous Regression evidence | Removed | Permanent owner and remaining enforcement |
| --- | ---: | --- |
| Popup header, focus, hover, gated dialog invocation and single-dialog count | 9 | Release scoped composition and event-handler checks, including its single-dialog invocation count; native UI/update suites stay required |
| Popup-open scheduling, update polling, source URL, manifest/package transport and hash category | 9 | Release verifies actual UpdateRuntime, UpdateTransport and UpdateClient source boundaries; required native UpdateCore/UpdateController remains |
| Persisted tray language choice and migration/recovery | 5 | Release checks both language options, persistence, popup rebuild and recovery; native LocalizationRuntime 84/84 stays |
| Capability resolver/adapter | 2 | Release owns canonical SystemCapabilities source; native runtime/UI capability suites still execute |
| Runtime include registry, Candidate provenance/fast policy, Windows/release dispatch and verifier argument | 6 | Release owns source/workflow wiring, while Candidate/Release automation continues to enforce exact-SHA status gates independently |
| **Total duplicated Regression assertions retired** | **31** | **No change to actual native cases, security boundaries or release states** |

**New fail-closed ownership contract:** `tools/validate_test_contracts.py` compares parsed Python AST calls for `s.has`/`s.no`, scoped to same source target, literal and polarity for UI/update/workflow families (with known source aliases). It rejects reintroduced same-source checks in Regression, and verifies **five canonical Release-owner anchors** remain. Its deterministic in-memory negative mutations reinsert duplicate checks and remove each canary owner to prove that the gate blocks both regressions. Opposite-polarity, different-source, conditional migration, and TaskBroker/privilege/boot cases remain outside this P2 contract and belong to P3 if applicable.

**Static test counts expected:** Contract Propagation **55 → 61**, Regression **176 → 145** (removed 31); Release **436**, Core **261**, Boundary **170** remain unchanged. Native Windows PowerShell 5.1 parser **67/67**, functional **610/610**, localization **84/84** and TaskBroker Boundary/Migration **25/25 + 42/42** remain unchanged. Candidate **3/3**, Release **8/8**, release preactivation, reproducible packages/history, and Cloudflare read-only health verification are unchanged.

**Exclusions retained intentionally:** Release/Regression preactivation ordering, non-mutating Development Completion (opposite authority), historical migration-only branches, distinct-scope header focus/source checks, separate transport-stage classifications without a same-source duplicate, and all P3 ACL/privilege/TaskBroker/firmware operations. Reducing the raw assertion count is not a substitute for proving behavior or trust-boundary coverage.

## LBS-130 / P3 — security-boundary ownership and negative proofs (v1.1.6.0)

**Phase P3 closes the #130 backlog only after hosted and release verification.** The v1.1.5.0 cross-validator audit found 27 lexical security overlap groups; that number was **not** a removal target. This narrowly scoped phase removes **24 weaker whole-file Core/Regression source assertions** (Core **9**, Regression **15**), **only after** transferring explicit guarantees to the permanent Boundary/Release gates and adding stronger source-function safety contracts to mandatory Contract Propagation. No original Boundary/Release security assertion, PowerShell native case, app/runtime/installer/uninstaller source, privilege boundary or BCD behavior is removed.

| Security concern | Former redundant assertions | Permanent authority after P3 |
| --- | ---: | --- |
| Installer/runtime schema `0.2.14`, `fixed-task-v2` | Core 3, Regression 3 | Boundary and Release each remain independently active; new cross-surface equality/security check; native TaskBroker Boundary/Migration |
| Exact operation allowlist, no free task name, metadata name derivation | Core 2, Regression 4 | Boundary function-scoped runner **and** resolver checks; native negative metadata/operation tests; cross-function security contract |
| Installer mutation-bit ACL, protected directory/file ACL and ownership checks | Core 3, Regression 5 | Boundary scoped ACL validator, Release packaged installer check, native ACL behavior, explicit protected-state and task DACL contracts |
| TaskBroker diagnostic presence/readability/compatibility | Core 1, Regression 3 | Boundary and Release separate states; explicit diagnostic function contract and negative mutation checks |
| **Total redundant source assertions removed** | **24** | **No functional native test reduction** |

The new `tools/validate_test_contracts.py` P3 extension has **16 independently named security-source conditions** over the actual installer, runtime resolver/runner/metadata, state/DACL ACL functions, diagnostics, migration ordering and One-Shot BootNext versus forbidden permanent `displayorder` writes. It additionally injects **16 deterministic negative source mutations** in memory (wrong schema/marker, broad operation, task-name bypass, ACL bits/protection, diagnostic fusion, premature/wildcard legacy removal and permanent boot order) and requires every mutation to fail closed. The checks do not execute any privileged operation, write ACLs or alter firmware. They are **bounded source-form proofs**, not proof of a real installed SYSTEM task DACL or arbitrary unseen syntactic encoding of a `displayorder` command.

**Intentional independent defenses retained:** Release's shipped installer/runtime assertions, Boundary's function-scoped privilege/metadata/ACL operations, Regression's historical migration and wildcard negatives, Core's pure read-only parser and boot safety assertions, native `Test-TaskBrokerBoundary.ps1` and `Test-TaskBrokerMigration.ps1`, mandatory Windows PowerShell 5.1 and P1/P2 ownership contracts. The read-only parser may still inspect `displayorder`; a permanent firmware write is prohibited. Static source checks complement, rather than replace, native behavior tests. No duplicate-grep elimination is a reason to change installer or application semantics.

**Expected checks:** Contract Propagation **61 → 101** (24 ownership exclusions plus 16 security conditions), Core **261 → 252**, Regression **145 → 130**, Release **436**, Boundary **170**. Native PowerShell parser **67/67**, functional **610/610**, TaskBroker Boundary **25/25** and Migration **42/42** remain unchanged. Candidate **3/3**, Release **8/8**, deterministic ZIP and historical integrity are mandatory. Exact P3 test-first RED and GREEN GitHub runs, any corrections, final SHA and native acceptance belong in [Issue #130](https://github.com/SaschaP1980/LenovoBootSelector/issues/130).

## Permanent Python gates

| File | Category | Purpose |
| --- | --- | --- |
| `validate_release.py` | Release | Release, packaging, source, repository, and documentation invariants |
| `validate_core.py` | Core | Functional core logic and modular core contracts |
| `validate_boundary.py` | Boundary | Architecture, privilege, and module boundaries |
| `validate_regression.py` | Regression | Comparison of the current state with the approved basis |

These four files are the permanent Python gates used by the GitHub Release Orchestrator.

LBS-40 adds `../tools/validate_test_contracts.py` as a shared preflight contract-propagation validator. It is not a fifth permanent Release/Core/Boundary/Regression gate. Instead, Candidate Preflight and Work-Branch Development Completion both execute it before the four permanent validators. It derives active fixed TOTAL values from the PowerShell test sources and rejects stale fixed-total literals in permanent validators, mismatched fixed runtime counts in this README, and Windows aggregate TOTAL markers that no active PowerShell test emits.

## Native Windows / PowerShell tests

| File | Category | Purpose |
| --- | --- | --- |
| `Test-FunctionalCore.ps1` | Core | Parsers, settings, localization resolution/formatting, pure storage resolution, and functional core behavior |
| `Test-StorageInfrastructure.ps1` | Infrastructure | Windows storage snapshot normalization and acquisition-failure behavior without duplicating pure classification cases |
| `Test-UIPresentation.ps1` | Presentation | Native WinForms characterization of selected/hidden boot rows, alias editing, hover state, and scrolling |
| `Test-LocalizationRuntime.ps1` | Runtime | Native PS5.1 language selection, persistence, migration, and central lookup |
| `Test-UpdateCore.ps1` | Core | Update model, transport failure contract, and update contracts |
| `Test-UpdateController.ps1` | Application / Infrastructure | Update check/prepare lifecycle, busy gating, result classification, resource cleanup, explicit installer handoff, and restart-result consumption with faked boundaries |
| `Test-RefreshRuntime.ps1` | Runtime | Background refresh state/request lifecycle and child-worker diagnostics-session correlation |
| `Test-DiagnosticsIdentity.ps1` | Infrastructure / Privacy | Persistent random installation UUID, restart stability, independent installations, fail-closed handling of corrupted identity data |
| `Test-DiagnosticsUploadTransport.ps1` | Infrastructure / Safety | Approved HTTPS origin, blocked redirects, in-memory POST request ZIP/UUID byte parity, and refusal of invalid/oversized local inputs without network I/O |
| `Test-RefreshController.ps1` | Application / Infrastructure | Background-refresh admission, coalescing, completion, maintenance cancellation, result application, worker success/failure, and cleanup ownership with faked boundaries |
| `Test-MaintenanceRuntime.ps1` | Runtime | Maintenance state and modes |
| `Test-SystemCapabilities.ps1` | Application | Canonical system-function readiness/capability derivation from explicit facts |
| `Test-SingleInstanceMutex.ps1` | Runtime | Single-instance / mutex lifecycle |
| `Test-BootTargetDrift.ps1` | Safety | Drift detection and fail-closed states |
| `Test-TaskBrokerBoundary.ps1` | Safety | Fixed-task / metadata privilege boundary without privileged execution |
| `Test-TaskBrokerMigration.ps1` | Safety / Migration | LBS-33 canonical privileged identifiers, migration ordering, legacy cleanup ownership, and default-state precedence |
| `Test-IdentifierCompatibility.ps1` | Compatibility | Active naming contract, autostart migration, package compatibility IDs, and cross-version singleton/task invariants |
| `Test-ArchitectureSoak.ps1` | Soak | Repeated architecture/state stability |
| `Test-WindowsPowerShell51.ps1` | Compatibility | Windows PowerShell 5.1 parser/encoding gate and native aggregate runner |

From v0.6.9.0 onward, the aggregate wrapper is also executed automatically by `.github/workflows/windows-powershell51.yml` on a fresh GitHub-hosted `windows-2025` runner using the explicit `powershell` shell. The workflow verifies that the runtime is actually Windows PowerShell 5.1, deterministically regenerates/checks the candidate runtime, and emits a machine-readable `WINDOWS_POWERSHELL51_SUMMARY=<json>`.

That GitHub-hosted execution is valid Windows contract-suite evidence. It is **not** physical Lenovo hardware/UEFI E2E and must be reported separately from tests performed on the target ThinkPad.

The Candidate workflow treats this Windows gate as mandatory for every Major, Minor, Patch, and Hotfix release. Linux Candidate Preflight and the Windows gate run in parallel; promotion waits for both and emits `CANDIDATE_TIMING_SUMMARY=<json>` with critical-path data. The permanent always-on policy was selected after the v0.6.9.0 production benchmark kept the complete candidate-to-release cycle at about 90 seconds.

## Baseline data

- `characterization-baseline-v0.3.4.json` — historical characterization basis.
- `taskbroker-baseline-v0.4.1.json` — TaskBroker basis.
- `ui-baseline-v0.4.3.json` — UI basis.

The baselines intentionally remain under `tests/` because existing historical validators still reference these paths.

## Native assertion-count contracts

Native PowerShell suites intentionally use different count strategies; one generic regex/call-site counter is not correct for every suite.

| Suite | Strategy |
| --- | --- |
| `Test-UpdateCore.ps1` | **AST self-audit + fixed coverage guard.** PowerShell counts the `Assert-True` / `Assert-Equal` command ASTs, compares them with the actually executed `$checks`, and additionally requires exactly 79. The permanent release gate validates the same contract statically. |
| `Test-UpdateController.ps1` | Straight-line: fixed runtime count of 56 covering LBS-26 Application orchestration and explicit Infrastructure/UI adapter boundaries. |
| `Test-RefreshRuntime.ps1` | Straight-line: fixed runtime count of 28, including LBS-22 inherited/fresh diagnostics-session coverage for background-refresh, update-check, and update-prepare roles. |
| `Test-RefreshController.ps1` | Straight-line: fixed runtime count of 38 covering LBS-27 lifecycle orchestration and the explicit Infrastructure worker boundary. |
| `Test-TaskBrokerBoundary.ps1` | Straight-line: fixed runtime count of 25, including rejection of the v1 boundary and legacy fixed task names. |
| `Test-TaskBrokerMigration.ps1` | Straight-line: fixed runtime count of 42 covering LBS-33 migration, LBS-34 authoritative Task Scheduler XML trigger verification, and LBS-35 batched ScheduledTasks performance contracts. |
| `Test-BootTargetDrift.ps1` | Straight-line: fixed runtime count of 13. |
| `Test-SingleInstanceMutex.ps1` | Explicit manual increments; fixed fail guard of 4. |
| `Test-IdentifierCompatibility.ps1` | Straight-line: fixed runtime count of 29 covering LBS-19 naming, migration-failure safety, unrelated-value isolation, and retained compatibility roots. |
| `Test-MaintenanceRuntime.ps1` | Loop-derived: 15 runtime checks from static assertions plus assertions repeated per mode. |
| `Test-SystemCapabilities.ps1` | Straight-line: fixed runtime count of 47 covering setup/repair/checking/ready/drift/busy/unknown capability derivation and fail-closed actions. |
| `Test-ArchitectureSoak.ps1` | Four aggregate soak assertions; each assertion covers many iterations. |
| `Test-FunctionalCore.ps1` | Dynamic PASS counting; includes deterministic LBS-31 storage-resolution cases with no hardware dependency. |
| `Test-StorageInfrastructure.ps1` | Straight-line: fixed runtime count of 17 covering Windows disk/partition normalization, per-disk partition-query failure, and unavailable inventory. |
| `Test-UIPresentation.ps1` | Straight-line: fixed runtime count of 25 covering normal selected rows, hidden/manage visual state, alias-editor state, hover behavior, scroll layout, and canonical capability interaction gates using real WinForms controls. |
| `Test-LocalizationRuntime.ps1` | Straight-line: fixed runtime count of 84 covering native locale selection, explicit-preference persistence, v0.8.0.0 ambiguity resolution, startup-recovery migration, catalog parity, LBS-111 live diagnostics menu refresh and LBS-117 scoped US/German flag drawing, DPI geometry, checkmark preservation, hotfix full-label WinForms rasterization under narrow native text rectangles, and authentic US stripe endpoints, and LBS-32 missing/loaded/invalid/unreadable settings load outcomes, structured diagnostics, fail-closed preservation and explicit recovery. |
| `Test-WindowsPowerShell51.ps1` | Aggregate runner/parser gate; file count is dynamic and is not an assertion-coverage count. |

When assertions are added, the corresponding contract must be updated deliberately. In particular, the fixed `79` guard in the update test must not be derived automatically from the source count: it is an additional change-control guard so that a suite extension cannot pass unnoticed.

## Repository documentation language

English is the canonical language for all repository Markdown and durable GitHub documentation. The permanent release validation checks this policy pragmatically while allowing clearly delimited technical literals and exact UI strings.
