# Lenovo Boot Selector – Changelog


## v0.10.0.2 – LBS-35 TaskBroker Repair performance hotfix

- Reduce the physical `Repair privileged tasks` cost caused by repeated ScheduledTasks CIM roundtrips on the affected ThinkPad.
- Load the exact canonical task definition set through one `Get-ScheduledTask` invocation, then preserve the existing per-task SYSTEM principal, Highest run level, action, arguments, authoritative COM/XML trigger, and Read+Execute-only DACL verification.
- Batch-unregister the already allowlisted legacy TaskBroker task-name set and the fixed historical probe-task list instead of invoking `Unregister-ScheduledTask` once per task.
- Cache the Task Scheduler root COM folder while keeping the existing `Schedule.Service` connection cache and exact task lookup semantics.
- Add durable installer timing diagnostics for every major step, canonical definition batch read, canonical task verification aggregate/slowest task, legacy discovery, legacy batch unregister, and overall installer duration.
- Expand the permanent TaskBroker Migration suite from 36 to 42 checks to lock the batched ScheduledTasks contract and timing diagnostics.
- Preserve the LBS-34 authoritative XML trigger validation, exact legacy ownership filters, verify-before-cleanup ordering, TaskBroker schema `0.2.14 / fixed-task-v2`, BootNext/default semantics, and privilege boundary.
- Physical ThinkPad duration acceptance remains required in LBS-35 after publication.
- Release profile: `patch`. `protectedFragmentIntent` and `repositoryDeleteIntent` are empty.

## v0.10.0.1 – LBS-34 native TaskBroker trigger-verification hotfix

- Fix the physical v0.10.0.0 Repair/Migrate failure at `verify-canonical-installation` where the ScheduledTasks CIM `.Triggers` projection falsely classified `LenovoBootSelector-RefreshManager` as triggered.
- Verify the trigger contract from the authoritative registered Task Scheduler COM XML instead: normal privileged tasks require zero trigger elements; `LenovoBootSelector-Default-Restore` requires exactly one 30-second `BootTrigger`.
- Keep principal, action, arguments, metadata, state ACL and task DACL verification unchanged.
- Keep fail-closed verify-before-legacy-cleanup ordering unchanged; the recoverable v0.10.0.0 dual-task state is intentionally supported by another Repair run.
- Expand the permanent TaskBroker Migration suite from 28 to 36 checks with triggerless, wrong-trigger, wrong-delay and multiple-trigger XML regressions.
- No TaskBroker schema, task name, ProgramData path, privilege-boundary, BootNext or default-target semantics change.
- Release profile: `patch`. `protectedFragmentIntent` and `repositoryDeleteIntent` are empty.

## v0.10.0.0 – LBS-33 privileged TaskBroker identifier migration

- Move the privileged TaskBroker installation to canonical `LenovoBootSelector-*` Scheduled Task names and `%ProgramData%\Lenovo Boot Selector\TaskBroker`.
- Advance the TaskBroker metadata contract to `0.2.14 / fixed-task-v2`; the unelevated runtime authorizes only the canonical v2 names and paths.
- Treat a pre-v0.10 TaskBroker installation as present but incompatible so the UI requires one explicit Repair/Migrate action with UAC.
- Preserve a valid system-wide default using precedence: canonical state → legacy TaskBroker state → historical user-settings default → historical Boot Menu task fallback.
- Build, enable and fully verify the canonical task set, metadata and ACLs before removing any exact legacy TaskBroker task or the legacy ProgramData state root.
- Make repair idempotent and keep failed pre-cleanup migrations recoverable; diagnostics retain both canonical and legacy migration evidence.
- Update privileged cleanup/uninstall to recognize both generations using exact static names and exact 32-hex per-GUID patterns only; no generic Lenovo wildcard removal is introduced.
- Keep `Local\LenovoBootMenuTray`, `%LOCALAPPDATA%\Lenovo Boot Menu Tray`, release ZIP names and flat package filenames unchanged because they have separate lifecycle/compatibility semantics.
- One manual **Repair privileged tasks** operation is required after upgrading from v0.9.x or earlier.
- Release profile: `patch`. Intentional protected-fragment delta: `ps:Test-TaskBrokerReady`. No repository deletions.

## v0.9.0.0 – LBS-19 identifier standardization and compatibility migration

- Standardize safe active application-owned identifiers on `Lenovo Boot Selector` / `LenovoBootSelector`, including the canonical source template, internal console helper, popup control name, installer workspace prefix, and user-visible uninstall prefix.
- Migrate the HKCU Run value from `Lenovo Boot Menu Tray` to `Lenovo Boot Selector` idempotently: recognize the legacy registration, write the canonical value first, and remove only the exact legacy value after the canonical write succeeds; disabling autostart removes both known names.
- Deliberately retain the pre-v0.9 release ZIP and flat package filenames so v0.8.0.4 and other compatible older installations can update directly to v0.9.0.0 without an intermediate migration release.
- Deliberately retain the existing `%LOCALAPPDATA%\Lenovo Boot Menu Tray` state root, `%ProgramData%\Lenovo Boot Menu\TaskBroker`, `Local\LenovoBootMenuTray` mutex, fixed `LenovoBootMenu-*` TaskBroker names, and cleanup-only legacy identifiers as stable technical compatibility contracts rather than product branding.
- Preserve visible `Lenovo Boot Menu` terminology where it describes the actual Lenovo/firmware boot menu.
- Add `docs/IDENTIFIER_COMPATIBILITY.md`, a permanent 22-check Windows PowerShell 5.1 identifier/migration suite, and explicit v0.9 updater-compatibility regression coverage.
- Preserve the unelevated updater, fixed TaskBroker privilege boundary, BootNext semantics, firmware/BCD safety rules, and historical release immutability.
- Release profile: `patch`. Intentional protected-fragment delta: `ps:New-PopupForm`. Intentional repository deletion: `src/App/LenovoBootMenuTray.template.ps1` after migration to `src/App/LenovoBootSelector.template.ps1`.

## v0.8.0.4 – LBS-25 fresh update-manifest hotfix

- Prevent a just-published release from being hidden behind a stale mutable `downloads/latest.json` response by adding a unique cache-busting query parameter to every manifest check.
- Keep versioned release ZIP download URLs unchanged and query-free so immutable packages remain normally cacheable.
- Extend `UPDATE_CHECK_WORKER_COMPLETED` diagnostics with the running app version, received manifest version, and manifest `publishedUtc` when present.
- Expand the native Update Core suite from 62 to 75 assertions, covering distinct manifest cache-busters, stable package URLs, newer/equal/older manifest decisions, and the new diagnostic metadata.
- Preserve HTTPS/TLS behavior, manifest/package/hash validation, user-controlled unelevated installation, and all BootService/TaskBroker/Storage/firmware safety boundaries.
- Release profile: `patch`. `protectedFragmentIntent` and `repositoryDeleteIntent` remain empty.

## v0.8.0.3 – Work-Branch Hotfix path performance measurement

- Pure version-only Hotfix used to benchmark the optimized Work-Branch exception path against the immediately preceding branchless v0.8.0.2 measurement.
- Canonical version raised from `0.8.0.2` to `0.8.0.3`.
- `releaseProfile` is `version-only`; product code under `src/**` is unchanged.
- `protectedFragmentIntent` and `repositoryDeleteIntent` are empty.
- The work branch is intentional only for this performance benchmark; normal small Patch/Hotfix releases remain branchless by default.

## v0.8.0.2 – Version-only Hotfix path performance measurement

- Pure version-only Hotfix used to measure the streamlined branchless Patch/Hotfix development and release path.
- Canonical version raised from `0.8.0.1` to `0.8.0.2`.
- `releaseProfile` is `version-only`; product code under `src/**` is unchanged.
- `protectedFragmentIntent` and `repositoryDeleteIntent` are empty.
- The run measures preparation, Candidate Preflight, promotion, Release Orchestrator, and total end-to-end release timing without mixing in a functional product change.

## v0.8.0.1 – LBS-23 English-default localization migration hotfix

- Fix the v0.8.0.0 localization migration so pre-localization settings without an explicit locale resolve to English (`en-US`) instead of German.
- Advance user settings to schema 6 and persist `localePreferenceSource` as explicit evidence of whether the active language is the default, a user choice, or the one-time ambiguous v0.8.0.0 migration state.
- Treat schema-5 `locale: "de-DE"` without preference metadata as `migration-pending` because v0.8.0.0 serialized both automatic migration and a possible explicit German selection identically; do not guess or silently overwrite it.
- Ask once on normal startup whether that ambiguous state should use English or keep German, then persist the result as an explicit user choice. Selecting German explicitly is recorded even when German is already active.
- Reuse the canonical locale-resolution rule for startup-recovery: pre-localization settings without a locale use English, while unresolved v0.8.0.0 German remains German only until the normal UI can obtain the explicit choice.
- Expand the native Windows PowerShell 5.1 localization suite from 14 to 32 checks, covering schema-6 persistence, the ambiguous migration state, same-locale German confirmation, one-time English correction, later explicit German selection, reload behavior, startup recovery, parity, and lookup.
- Add permanent focused LBS-23 release validation and update localization architecture documentation.
- BootService, TaskBroker, Storage mutation, firmware/BCD, BootNext, SYSTEM task allowlist, updater installation safety, and USB detection architecture are unchanged.
- Release profile: `patch`. Intentional characterized protected-fragment delta: `ps:Load-AppSettings`, `ps:Save-AppSettings`.

## v0.8.0.0 – LBS-17 English/German localization

- Introduce a central deterministic localization layer with matching `en-US` and `de-DE` catalogs; English is the canonical default and fallback language.
- Add explicit persisted language selection through the tray UI. A visible popup and tray labels relocalize immediately when the language changes.
- Advance user settings to schema 5: new installations default to English, while pre-localization settings without a locale migrate deliberately to German.
- Localize product-controlled tray, popup, boot/default-target, Friendly/Storage/NVMe/USB, dialog, maintenance, update, startup-recovery, diagnostics, busy/error, tooltip, and accessibility presentation.
- Keep firmware descriptions, drive model names, GUIDs, paths, diagnostic codes, TaskBroker operations, schema fields, and other external/technical identities untranslated.
- Prevent raw update-worker/restart technical messages from being rendered as product copy; the standalone installer fallback receives centrally localized text as Base64 data.
- Add permanent catalog parity/duplicate-key checks and a static gate against uncontrolled hard-coded visible text in affected UI/presentation/template surfaces.
- Add `Test-LocalizationRuntime.ps1` to the mandatory GitHub-hosted Windows PowerShell 5.1 aggregate for selection, persistence, reload, migration, fallback, parity, and formatting coverage.
- Document localization architecture and contribution rules in `docs/LOCALIZATION.md`.
- Preserve BootService, TaskBroker, Storage mutation, firmware/BCD, BootNext, privilege, polling, and updater safety boundaries.
- Release profile: `patch` because product source changes. Intentional characterized protected-fragment delta:
  - `ps:Complete-BackgroundBootRefresh`
  - `ps:Get-FirmwareBootState`
  - `ps:Get-FriendlyBootEntry`
  - `ps:Load-AppSettings`
  - `ps:New-PopupForm`
  - `ps:Save-AppSettings`
  - `ps:Save-RuntimeDiagnosticsFromUi`
  - `ps:Show-LenovoNoticeDialog`
  - `ps:Show-OrTogglePopup`
  - `ps:Start-BackgroundBootRefresh`
  - `ps:Update-PopupRows`

## v0.7.0.2 – LBS-22 child-worker runtime diagnostics correlation

- Fix the runtime-diagnostics session hand-off so background-refresh, update-check, and update-prepare child processes reuse the parent tray session when `-RuntimeSessionId` is supplied.
- Preserve the incoming child-process session identifier before active runtime diagnostics state is initialized; a child without an inherited identifier still creates a fresh session.
- Make `parentSession` describe a genuinely inherited, sanitized session identifier rather than the post-initialization active session value.
- Add native Windows regression coverage for all three child-worker roles plus fresh-session behavior, and permanent Release/Regression contracts for the bootstrap wiring.
- No BootService, TaskBroker, Storage, firmware/BCD, BootNext, privilege, or updater-install boundary changes are made.
- The release uses the `patch` profile. No characterized protected fragment changes, so `protectedFragmentIntent=[]`.

## v0.7.0.1 – Version-only Hotfix for popup-open update-check acceptance

- Pure version-only Hotfix used to provide a newer release target for native acceptance of the v0.7.0.0 popup-open automatic update-check behavior.
- Canonical version raised from `0.7.0.0` to `0.7.0.1`.
- `releaseProfile` is `version-only`; product code under `src/**` is unchanged.
- `protectedFragmentIntent` and `repositoryDeleteIntent` are empty because this Hotfix intentionally changes no protected product fragment and deletes no repository path.
- The release cycle is also used to measure current Candidate Preflight, Windows PowerShell 5.1, promotion, Release Orchestrator, and total candidate-to-release performance without mixing in a functional code change.

## v0.7.0.0 – LBS-21 popup-open automatic update checks

- Automatic read-only app-version discovery moves from tray-process startup to each actual popup-open transition.
- Opening the popup now starts the existing validated update-check worker alongside the existing fresh boot-target refresh; the two read-only workers remain independent and may overlap.
- Closing and later reopening the popup starts a fresh version check again, while opening cannot start a competing second update operation when the updater is already busy.
- The historical process-once `StartupCheckStarted` / `StartupCheckCompleted` state and dedicated startup-check trigger are removed instead of keeping a second automatic path.
- Boot-target refresh status keeps priority over the update-available hint; the existing `Neue App-Version verfügbar` indication returns after refresh when applicable.
- Manual update checking and installation remain explicit user-controlled paths. There is still no periodic polling, automatic package download, or automatic installation.
- BootService, TaskBroker, Storage, firmware/BCD behavior, BootNext semantics, and the privilege boundary are unchanged.
- The release uses the `patch` regression profile because product code under `src/**` changes. The intentional protected-fragment delta is exactly `ps:Show-OrTogglePopup`.

## v0.6.9.1 – LBS-20 release-cycle performance measurement

- Pure version-only Hotfix used to measure the now-parallel Candidate Preflight with the mandatory GitHub-hosted Windows PowerShell 5.1 gate.
- Canonical version raised from `0.6.9.0` to `0.6.9.1`.
- `releaseProfile` remains `version-only`; product code under `src/**` and release infrastructure are unchanged.
- The run is intended to measure Linux/Windows queue time, parallel candidate critical-path impact, Windows PowerShell 5.1 execution time, and total candidate-to-release duration.

## v0.6.9.0 – LBS-20 parallel Windows PowerShell 5.1 candidate gate

- Candidate validation now runs the existing Linux exact-candidate preflight and a real GitHub-hosted Windows PowerShell 5.1 contract-suite gate in parallel on the same candidate SHA.
- New reusable `.github/workflows/windows-powershell51.yml` runs on an ephemeral `windows-2025` runner, explicitly verifies Windows PowerShell 5.1, deterministically regenerates/checks the runtime, and executes `tests/Test-WindowsPowerShell51.ps1`.
- The Windows gate emits `WINDOWS_POWERSHELL51_SUMMARY=<json>` with parser/suite totals plus setup, runtime-preparation, test, and total timings, and publishes `preflight/windows-powershell51`.
- Linux Candidate Preflight publishes `preflight/linux`; neither validation job may promote a release.
- A separate promotion job waits for both mandatory jobs, verifies both latest statuses on the exact candidate SHA, verifies the candidate ref and current-main ancestry, emits `CANDIDATE_TIMING_SUMMARY=<json>`, and only then writes `preflight/candidate`, creates the release ref, dispatches the Release Orchestrator, and deletes the candidate branch.
- The Release Orchestrator and integrated post-release verifier require all 3/3 candidate contexts: `preflight/candidate`, `preflight/linux`, and `preflight/windows-powershell51`.
- The Windows workflow also supports manual `workflow_dispatch` benchmark/retest runs. GitHub-hosted Windows results are explicitly distinguished from physical Lenovo hardware/UEFI E2E.
- Initial LBS-20 policy is **always mandatory** for Major, Minor, Patch, and Hotfix releases while real timing data is collected; the permanent policy is selected from measured critical-path impact.
- Product code under `src/**` is unchanged; v0.6.9.0 therefore uses `version-only`. BootService, TaskBroker, Storage, updater, firmware/BCD behavior, and the privilege boundary are unchanged.

## v0.6.8.1 – Tray tooltip simplified

- Removes the historical German suffix `– Startziel wählen` from the Windows tray icon tooltip.
- The tray tooltip is now exactly `Lenovo Boot Selector`, which better represents both One-Shot Next Boot selection and the persistent default boot-target feature.
- A permanent Regression gate requires the exact product-name-only tooltip and rejects reintroduction of the old suffix.
- No BootService, TaskBroker, Storage, firmware/BCD, updater, or privilege-boundary behavior changes.

## v0.6.8.0 – LBS-18 repository documentation standardized on English

- All tracked Markdown documentation is migrated to English, including `README.md`, `CHANGELOG.md`, `docs/**`, `tests/**`, `tests-history/**`, and `downloads/README.md`.
- English is now the canonical language for repository documentation, development/process documentation, GitHub Issues/PRs/release notes, and other durable GitHub project communication.
- `docs/INITIAL_PROMPT.md` remains the one-line bootstrap entry point and now explicitly distinguishes repository language from interactive chat language: repository/GitHub documentation stays English, while user chat may remain German with established English technical terminology.
- `docs/GITHUB_HOWTO.md` and `docs/RELEASE_PROCESS.md` document the permanent language policy and keep the existing authority, Candidate Preflight, release, security, and handover contracts intact.
- A new permanent `tools/validate_markdown_language.py` gate scans every tracked Markdown file and pragmatically rejects German-looking prose while excluding fenced code, inline code, and clearly delimited literal UI/technical text.
- `tests/validate_release.py` runs the Markdown-language gate during Candidate Preflight/Release validation; `tests/validate_regression.py` protects the permanent wiring.
- Exact identifiers, paths, commands, schemas, status contexts, event/error codes, hashes, version numbers, and intentionally quoted UI strings remain unchanged where required.
- Product code under `src/**` is unchanged; v0.6.8.0 therefore uses `version-only`. BootService, TaskBroker, Storage, updater, firmware/BCD behavior, and the privilege boundary are unchanged.

## v0.6.7.3 – Native test-harness count drift hardened

- `Test-UpdateCore.ps1` corrects the historically stale final count from 61 to 62; all 62 existing functional assertions were already passing.
- The update test additionally performs a PowerShell-AST self-audit: the `Assert-True` / `Assert-Equal` command calls defined in source must exactly match the actually executed `$checks`.
- As a deliberate additional change-control guard, `Write-Host "UPDATE TOTAL $checks/62"` and `if ($checks -ne 62) { throw "Unexpected update test count $checks" }` remain fixed; the AST source count must also explicitly equal 62.
- The permanent release gate structurally checks 62 update assertion call sites plus the AST self-audit and both 62-count guards, so count drift is detected during Candidate Preflight.
- `Test-SingleInstanceMutex.ps1` now has a real fail guard for exactly four checks in addition to `MUTEX TOTAL $checks/4`.
- `tests/README.md` documents the different count strategies used by native suites; loop-, soak-, and dynamically counted suites are not incorrectly treated with a generic call-site count.
- Product code under `src/**` is unchanged; the Hotfix therefore uses `version-only`.
- Native Windows/PowerShell-5.1 execution remains a separate post-publication confirmation.

## v0.6.7.2 – Version-only release-cycle measurement

- Pure Hotfix/release-process test with no functional product change.
- Canonical version raised from `0.6.7.1` to `0.6.7.2`.
- `releaseProfile` remains `version-only`; product code under `src/**` is unchanged.
- This build exists only to remeasure the optimized Candidate/Release flow.

## v0.6.7.1 – Version-only release-cycle measurement

- Pure Hotfix/release-process test with no functional product change.
- Canonical version raised from `0.6.7.0` to `0.6.7.1`.
- `releaseProfile` remains `version-only`; product code under `src/**` is unchanged.
- This build exists only to measure the LBS-16 Candidate/Release flow.

## v0.6.7.0 – LBS-16 release orchestration aggregated

- New integrated `tools/release_verification.py` final verifier aggregates GitHub/repository facts that had previously been checked through many interactive requests after merge.
- The verifier checks: merged PR and exactly one publication PR, 8/8 release status contexts, Candidate Preflight status, source tag/commit, ZIP/cache-free source tree, `downloads/latest.json`, published release ZIP size/SHA-256, candidate/release branch cleanup, and the previously completed reproducibility comparison.
- Successful releases emit exactly one machine-readable `RELEASE_VERIFICATION_SUMMARY=<json>` plus a compact GitHub Job Summary.
- Candidate Preflight additionally emits `CANDIDATE_PREFLIGHT_SUMMARY=<json>` while retaining `CANDIDATE PREFLIGHT PASS` for compatibility.
- Interactive orchestration now prefers batched initial reads, one atomic candidate commit, conservative workflow polling, and the verified final summary instead of redundant individual lookups.
- The new verification helper has a permanently executed self-test; Release and Regression gates protect the summary/workflow contracts.
- Candidate Preflight, two deterministic builds, Release/Core/Boundary/Regression, 8/8 status gates, source integrity, and historical ZIP integrity remain fully intact.
- v0.6.7.0 uses `version-only`; product code under `src/**`, installer, boot/firmware/storage logic, and privilege behavior are unchanged.

## v0.6.6.0 – LBS-10 historical release profile removed

- Active `release-architecture` was removed completely. Its special behavior covered only the long-completed migration from a hard-coded AppVersion to the `@APP_VERSION@` template token.
- Active release profiles are now only `version-only` and `patch`.
- `version-only` is the strict choice when product code under `src/**` is unchanged: all product modules must be byte-identical to the immediately previous canonical source basis; only the injected runtime version may differ.
- `patch` remains the profile for functional product-code changes.
- The release-config parser now rejects the historical profile; Release and Regression gates permanently protect the two-profile semantics.
- Historical validators and prior releases remain unchanged under `tests-history/` and `downloads/`.
- v0.6.6.0 correctly uses `version-only` because LBS-10 changes only release tooling, tests, and documentation and does not change product code under `src/**`.
- No change to product runtime, BootService, TaskBroker, Storage, updater, firmware/BCD, or privilege logic.

## v0.6.5.0 – LBS-15 release entry hardened

- A new upstream **Candidate Preflight** uses `candidate/v<version>` so the exact candidate SHA is fully validated before a visible `release/v<version>` branch may exist.
- The Candidate workflow writes `preflight/candidate`, creates the release branch only after GREEN on the exact same SHA, then deletes the candidate branch.
- The Release Orchestrator rejects candidates without successful `preflight/candidate` and rejects stale candidates when current `main` is no longer an ancestor of the release SHA.
- `tools/candidate_preflight.py` performs deterministic release preparation, two reproducible builds, Release/Core/Boundary/Regression, repository-delete intent checks, and ZIP-history checks before release-branch creation.
- `protectedFragmentIntent` in `bin/version.json` is now an exact release-specific change intent. Protected fragments are compared with the immediately previous canonical source tag; actual and declared changes must match exactly.
- The permanent `INTENTIONALLY_CHANGED_FROZEN` bypass allowlist was removed. Future changes to security/critical functions that were intentionally changed in a prior release are protected again.
- `repositoryDeleteIntent` makes intended repository deletions explicit; undeclared or stale deletion intent blocks preflight.
- `tools/build_runtime.py` no longer has a second static include registry. Module set/order is derived only from `# @include ...` markers in the runtime template and validated for duplicates, safe paths, and existence.
- GitHub remains the authoritative second barrier: Release Orchestrator, source-tag semantics, historical ZIP integrity, and the existing eight release status gates remain.
- No change to product-runtime functionality, BootService, TaskBroker, Storage, firmware/BCD paths, or the privilege boundary.

## v0.6.4.1 – Hotfix for LBS-6 repair ACL validation

- Fixes the confirmed v0.6.4.0 repair failure at installer step `protect-state`.
- Root cause: `FileSystemRights::Modify` was used as a composite forbidden mask and overlaps the explicitly allowed `ReadAndExecute` rights. The newly written Users=ReadAndExecute ACL was therefore falsely classified as writable.
- Validation now checks only concrete mutation rights such as WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, and TakeOwnership.
- `ReadAndExecute` is correctly treated as non-mutating; `Modify` and `FullControl` remain forbidden.
- The native TaskBroker boundary test extracts the actual rights predicate from the installer and explicitly verifies ReadAndExecute = PASS, Modify = FAIL, and FullControl = FAIL.
- Runtime diagnostics now distinguish `present`, `metadataReadable`, and `compatible`. An existing but incompatible 0.2.12 metadata file is no longer falsely reported as absent.
- TaskBroker schema 0.2.13, `boundaryContract = fixed-task-v1`, operation-gated runtime, One-Shot `bootsequence`, and all other LBS-6 security boundaries are unchanged.
- After a repair failed under v0.6.4.0, the existing German maintenance action `Wartung → Systemfunktionen reparieren…` can safely be run again with v0.6.4.1.

## v0.6.4.0 – LBS-6 boot/privilege boundary hardened fail-closed

- Runtime TaskBroker no longer accepts freely supplied Scheduled Task names. `Invoke-AuthorizedTask` accepts only fixed operations `ManagerRefresh`, `FirmwareRefresh`, `BootNext`, `DefaultSet`, and `DefaultClear`.
- Static task names are fixed by the runtime contract; target-specific BootNext/DefaultSet task names are derived only from strictly validated installed firmware GUIDs.
- TaskBroker schema **0.2.13** introduces `boundaryContract = fixed-task-v1`. Metadata is validated fail-closed for schema, user SID, fixed task names, fixed state paths, canonical GUIDs, derived task names, and duplicates.
- Elevated setup protects the complete TaskBroker state directory under ProgramData plus `task-broker.json` with SYSTEM/Admin FullControl and Users ReadAndExecute. Normal users can no longer rewrite trusted TaskBroker metadata.
- Task-DACL verification no longer accepts `GENERIC_ALL` as success. Over-broad user allow ACEs are replaced by exactly one Read+Execute ACE and verified by read-back.
- `LenovoBootMenu-Default-Restore` remains a trigger-only fixed SYSTEM task and is not exposed as an unelevated runtime operation.
- One-Shot `bootsequence` semantics remain unchanged; permanent `BootOrder` / `{fwbootmgr} displayorder` mutation remains forbidden.
- New canonical threat/boundary contract: `docs/SECURITY_BOUNDARY.md`.
- Existing schema-0.2.12 system functions are intentionally treated as requiring repair after the app update. One explicit UAC repair installs schema 0.2.13 and the new ACL boundaries.
- Updater, Storage, and USB detection receive no new privileged interface.

## v0.6.3.1 – LBS-14 update indicator made interactive and dialog title aligned

- The header indicator now consistently uses the exact German UI text `Neue App-Version verfügbar`.
- When an update is available, the indicator is interactive: hover and keyboard focus turn the text Lenovo red and the pointer indicates clickability.
- The status uses a flat WinForms button and therefore supports native activation with Enter and Space.
- Only click/keyboard activation opens the existing update dialog; hover alone does nothing.
- The dialog title also uses `Neue App-Version verfügbar` and continues to use the already validated manifest stored in process state.
- Header activation starts no additional network/version check and does not automatically download or install anything.
- Existing priority remains unchanged: active boot-target refresh before update indicator before normal header; the update indicator is not interactive during refresh or maintenance.
- LBS-11 startup check, LBS-5 updater boundaries, BootService, TaskBroker, Storage, and firmware/BCD paths remain unchanged.

## v0.6.3.0 – LBS-5 updater networking isolated and diagnostics hardened

- New infrastructure boundary `src/Infrastructure/UpdateTransport.ps1` owns the fixed GitHub source, TLS 1.2 activation, WebClient creation, and manifest/package transport instead of UpdateClient.
- Network failures are recorded structurally as `network` with stages `manifest-download` or `package-download`; underlying `WebExceptionStatus` remains in runtime diagnostics.
- Manifest, package, size, and SHA-256 failures have separate categories/stages. Hash failures are specifically classified as `hash / package-hash`.
- Update-check and prepare workers return `ErrorCategory`, `FailureStage`, `ErrorClass`, and `NetworkStatus` to the UI; runtime diagnostics record the same structured fields.
- Persistent installer/restart results also carry `failureCategory`, `failureStage`, and `errorClass` so installation and restart failures remain distinguishable.
- Targeted native update tests cover DNS, timeout, ConnectFailure classification, and the separate hash category.
- LBS-11's one-time read-only startup version check remains; opening/reopening the popup starts no additional check and periodic polling remains excluded.
- No change to BootService, TaskBroker, Storage, firmware/BCD paths, or the privilege boundary.

## v0.6.2.2 – Test structure cleaned up and one-time startup version check

### LBS-13 – Test structure

- `tests/` now contains only active canonical validators, native PowerShell tests, and required baseline data.
- 74 historical `validate_v*.py` files were moved byte-for-byte to `tests-history/`.
- Historical filenames now explicitly contain test category `release`, `core`, `boundary`, or `regression` plus a readable version.
- `tests/README.md` documents the active test matrix; `tests-history/README.md` documents historical snapshots and naming.
- The four permanent GitHub gates remain `validate_release.py`, `validate_core.py`, `validate_boundary.py`, and `validate_regression.py`.

### LBS-11 – Version check per tray process

- A new tray process automatically performs exactly one read-only check for a newer app version.
- Opening/reopening the popup starts no additional automatic check; periodic polling remains excluded.
- The automatic check shows no update dialogs, downloads nothing, and installs nothing.
- When an update is available, the validated manifest remains in process state and the header shows the exact historical German UI text `Neue App Version verfügbar`.
- An active boot-target refresh takes header precedence with `Aktualisiere Bootziele…`; the update message returns after completion.
- The existing manual update path with dialog and explicit installation is unchanged.
- No change to BootService, TaskBroker, Storage, firmware/BCD paths, or the privilege boundary.

## v0.6.2.1 – Default boot target remains clear during initial check

- During the initial asynchronous system-functions check, the `Standard-Startziel` row remains fully readable.
- The right-hand value shows `Wird geprüft …` instead of a disabled already-known target name.
- The chevron is hidden during the check and the row is non-interactive.
- After completion, actual default-target value, chevron, and interaction are restored automatically.
- Other disabled states keep their previous dimmed semantics.
- No change to BootService, TaskBroker, Storage, firmware/BCD paths, or the privilege boundary.

## v0.6.2.0 – LBS-1 architecture/audit artifacts structured

- Canonical and historical `ARCHITECTURE_BASELINE*.json` files now live under `docs/architecture/`.
- Canonical and historical `CATCH_AUDIT*.json` files now live under `audits/`.
- Generators, permanent and historical regression tests, documentation, and the release-migration gate use the new paths.
- Source/transition packaging includes the new directories automatically; the flat release ZIP structure is unchanged.
- Boot, TaskBroker, privilege, Storage, and UI logic remain unchanged.
- LBS-1 is fully integrated into the release cycle with v0.6.2.0.

## v0.6.1.0 – LBS-2 repository-root cleanup

v0.6.1.0 implements LBS-2 and cleanly separates repository structure from shipped release structure.

- Runtime/project files previously loose in the repository root now live under `bin/`.
- This includes the generated runtime, installer/uninstaller, launcher, icon/preview, `BUILD_INTEGRITY.txt`, and canonical `version.json`.
- `README.md` and `CHANGELOG.md` remain in the root; `.gitignore` remains as the Git control file.
- JSON architecture/audit artifacts remain explicitly unchanged within LBS-1 scope and are not moved by LBS-2.
- Build, test, packaging, release-workflow, and documentation paths were updated to the new `bin/` source.
- The shipped release ZIP intentionally remains unchanged and flat with the same 10 files; `bin/` is repository/source structure only.
- Updater, boot, Storage, TaskBroker, and privilege-boundary semantics remain unchanged.

## v0.6.0.0 – GitHub-owned publication timestamp and release-cycle hardening

v0.6.0.0 is a minor release of the release system. Product runtime remains unchanged except for the version number.

- `version.json` moves to schema 2 and no longer contains a pre-set `publishedUtc`.
- Release profile remains `version-only` because all product modules stay byte-identical to the v0.5.10.4 basis and only release tooling changes.
- GitHub Release Orchestrator creates canonical `publishedUtc` only once the hosted runner is executing the publication job.
- Both deterministic GitHub rebuilds receive the exact same GitHub-generated timestamp.
- `tools/prepare_release.py` requires explicit `--published-utc` for schema 2; local values are provisional build metadata only.
- Legacy schema 1 remains readable for older source states.
- Python calls in the release workflow use `-B` so interpreter caches are not written to the working tree.
- Runner queue policy is documented: wait interactively at most 60 seconds, then no cancel/retry/duplicate trigger; check later with the `Github Status` user command.
- LBS-9 is implemented.

## v0.5.10.4 – Version-only performance optimization test 3

v0.5.10.4 is a pure Hotfix for measuring the further optimized end-to-end release path. There is no functional product change from v0.5.10.3.

- Version raised from `0.5.10.3` to `0.5.10.4`.
- `releaseProfile` remains `version-only`.
- LBS-8 / Squash Merge is explicitly not part of this build.
- No persistent extracted worktree cache: the canonical v0.5.10.3 source ZIP is the only basis.
- No intermediate workflow polling; after trigger there is one wait block followed by aggregated final verification.
- No change to product runtime, update behavior, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.

## v0.5.10.3 – Version-only performance optimization test 2

v0.5.10.3 is a pure Hotfix for measuring the further optimized end-to-end release path. There is no functional product change from v0.5.10.2.

- Version raised from `0.5.10.2` to `0.5.10.3`.
- `releaseProfile` remains `version-only`.
- LBS-8 / Squash Merge is explicitly not part of this build.
- No change to product runtime, update behavior, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.
- The run measures all steps, records errors/retries, and uses the verified v0.5.10.2 source cache.

## v0.5.10.2 – Version-only performance optimization test

v0.5.10.2 is a pure Hotfix for another end-to-end performance measurement of the permanent release path. There is no functional product change from v0.5.10.1.

- Version raised from `0.5.10.1` to `0.5.10.2`.
- `releaseProfile` remains `version-only`.
- LBS-8 / Squash Merge is explicitly not part of this build.
- No change to product runtime, update behavior, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.
- The run measures all steps, records retries/errors, and uses safe caches where possible.

## v0.5.10.1 – Version-only pipeline performance test

v0.5.10.1 is a pure Hotfix for measuring the permanent build/GitHub release path. There is no functional product change from v0.5.10.0. Changes are limited to canonical version/release configuration and deterministically generated release metadata/packages.

- Version raised from `0.5.10.0` to `0.5.10.1`.
- `releaseProfile` is `version-only`.
- No change to product runtime, update behavior, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.
- This release explicitly measures end-to-end performance of the permanent Release Orchestrator.

## v0.5.10.0 – Permanent release pipeline and centralized versioning

v0.5.10.0 is a build/release architecture patch with no new product feature. From this version, app version is derived only from `version.json`; runtime, package, audit, and transition builds use the same canonical source.

Changes:

- New canonical `version.json` with version, release profile, and deterministic publication timestamp.
- `LenovoBootMenuTray.template.ps1` contains only build token `@APP_VERSION@`; `tools/build_runtime.py` injects the canonical version deterministically.
- `build_packages.py`, `build_transition.py`, and `build_catch_audit.py` no longer contain a hard-coded release version.
- New permanent tools `release_common.py`, `prepare_release.py`, and `build_architecture_baseline.py`.
- Catch Audit and Architecture Baseline continue under canonical names `CATCH_AUDIT.json` and `ARCHITECTURE_BASELINE.json`; historical versioned snapshots remain unchanged.
- Permanent validators `validate_release.py`, `validate_core.py`, `validate_boundary.py`, and `validate_regression.py` replace future version-specific copies. Historical validators remain as evidence of earlier releases.
- Permanent GitHub release path: exactly one `release/v<version>` branch, one PR, and one merge. No Base64 patch transport, separate source branch, or required post-merge finalizer.
- The single permanent GitHub orchestrator reproduces the release and runs Release/Core/Boundary/Regression itself. Green gate statuses are written to the final PR head; a separate `pull_request` workflow is intentionally absent because PR events created with `GITHUB_TOKEN` do not recursively start another workflow. The ZIP-free annotated source tag is created only after successful gates and PR creation, before merge.
- Existing historical `downloads/*.zip` remain immutable; each release may add exactly one new ZIP.
- Product runtime, update behavior, BootService, TaskBroker, Storage, firmware/BCD paths, and privilege boundary remain functionally unchanged from v0.5.9.1.

**Performance target for the following version-only test:** target <= 5 minutes, hard expected limit 10 minutes from start to merged PR, assuming no external GitHub incident.

## v0.5.9.1 – Version Hotfix without functional change

v0.5.9.1 exists solely to verify the simplified build/GitHub release process. There is no functional product change from v0.5.9.0; runtime logic is byte-identical apart from the app-version line.

Changes:

- App version raised from `0.5.9.0` to `0.5.9.1`.
- Version-related build, audit, download, and revision metadata advanced to v0.5.9.1.
- No change to update dialog, update networking, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.
- Release process is verified as **1 build = 1 release branch = 1 PR**; source tag and reproducible package check must complete before merge.

**Native verification:** no new functional test required; starting the app and confirming displayed version v0.5.9.1 is sufficient as a smoke test.

## v0.5.9.0 – Start update directly from availability dialog

v0.5.9.0 changes only the manual update entry after a successful newer-version check. Existing update path, network/hash validation, and privilege boundary remain unchanged.

Changes:

- Dialog `Neue Version verfügbar` additionally offers button `Jetzt aktualisieren`.
- The button calls the existing `Start-ManualAppUpdate` path directly; no second installation/download path is introduced.
- Historical German helper text is exactly: `Du kannst die neue Version jetzt direkt installieren. Später findest du die Aktualisierung im Tray-Menü unter ‚Wartung‘ → ‚App aktualisieren…‘.`
- **OK** remains a non-installing action; existing maintenance item `Wartung → App aktualisieren…` remains available.
- No change to download source, update networking, SHA-256/package validation, backup/rollback, restart-result logic, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.

**Native verification required:** after a real update check, visually verify the dialog, trigger `Jetzt aktualisieren` and confirm the same existing update process starts; regressively verify **OK** only closes the dialog.

## v0.5.8.1 – Legacy updater restart result compatibility

v0.5.8.1 is a narrow Hotfix based on canonical v0.5.8.0 source. The real v0.5.7.2 → v0.5.8.0 web-update test installed v0.5.8.0 successfully, but after restart falsely showed `Update fehlgeschlagen – Unbekannter Update-Ergebnisstatus: <leer>`. Root cause was the persisted restart-result format transition: the helper still running from v0.5.7.2 wrote `{ utc, success, message }` while v0.5.8.0 already expected the new `status/sourceVersion/targetVersion/rollback...` format.

Changes:

- Restart evaluation now normalizes through `Resolve-LenovoUpdateRestartResultCore`.
- Legacy format is detected only when `status` is absent and `success` is a real Boolean. This correctly handles `success=false` without accepting malformed string/pseudo-Boolean values.
- Legacy `success=true` produces `Update erfolgreich` once. Because old format stores no reliable `targetVersion`, diagnostics do not invent one; only the actually running app version is shown.
- Legacy `success=false` produces `Update fehlgeschlagen` once and uses the stored legacy error message or a neutral fallback.
- When `status` is present, v0.5.8.x status format takes precedence; `pending-verification`, exact target-version verification, `failed`, and rollback presentation remain unchanged.
- `UPDATE_RESTART_RESULT` additionally contains `resultFormat` and, for legacy results, `legacySuccess` so compatibility handling is diagnostically explicit.
- Unknown/malformed result shapes remain fail-closed and continue to produce `Unbekannter Update-Ergebnisstatus`.
- The result is still consumed before the modal dialog, so the message appears at most once.
- No change to download source, network logic, SHA-256/package validation, backup/rollback, BootService, TaskBroker, Storage, firmware/BCD paths, or privilege boundary.

**Native verification required:** fully test the new resolver under Windows PowerShell 5.1 and confirm either a real transition from a helper using the legacy result format to v0.5.8.1 or a controlled legacy fixture. The new status format must remain regressively unchanged.

## v0.5.8.0 – Confirm update result after restart

v0.5.8.0 extends the manual self-updater with persistent completion confirmation across process restart. The successful real v0.5.7.1 → v0.5.7.2 update proved the update path works, but previous runtime diagnostics ended with the old session and the user saw no explicit final message after restart.

Changes:

- The unelevated installer helper writes a persistent update result before restart under `%LOCALAPPDATA%\Lenovo Boot Menu Tray\Updates\last-update-result.json`.
- An update is initially marked `pending-verification`. **Success is confirmed only by the restarted tray app** when its running version exactly equals the expected target version.
- After successful verification, `Update erfolgreich` appears once with the installed target version.
- Installation/restart failures continue to use the existing backup/rollback path. The helper stores `failed` plus rollback state and then attempts to start the installed/restored app again.
- After a failed update, `Update fehlgeschlagen` appears once on the next app start; successful rollback is stated explicitly.
- The consumed result is copied as `UPDATE_RESTART_RESULT` into the new session's runtime diagnostics with source version, target version, running version, and rollback status.
- The result is consumed before the modal dialog so the same completion message appears at most once.
- Version schema remains **MAJOR.MINOR.PATCH.HOTFIX**; v0.5.8.0 is the next PATCH after v0.5.7.2.
- No change to firmware/BCD/TaskBroker/Storage paths and no new privileged update channel.

**Native verification required:** update an older installed version to v0.5.8.0 and confirm exactly one `Update erfolgreich` after automatic restart. Also run a controlled error/rollback test in a disposable copy.

## v0.5.7.2 – Web-update test release

v0.5.7.2 is an intentionally minimal test release for the first real web-update path from v0.5.7.1 to v0.5.7.2. Only the version number changes; there is no other functional product change. By explicit request, no tests or handover were generated for this release.

## v0.5.7.1 – Four-component version schema for web updates

v0.5.7.1 is an intentionally minimal test release for **MAJOR.MINOR.PATCH.HOTFIX**. The update parser now accepts three- and four-component versions; historical three-component versions are internally compared with `HOTFIX = 0`. There are no other functional product changes. By explicit request, no tests or handover were generated for this release.

## v0.5.7 – Update-manifest roundtrip fixed

v0.5.7 is a narrow updater bugfix based on v0.5.6. During manual update check, the remote manifest was validated correctly in the check worker, but normalized output lost `schemaVersion`. The tray app validated that worker result a second time and rejected it with `Update-Manifest-Schema wird nicht unterstützt.`

Changes:

- `Test-LenovoUpdateManifestCore` includes `SchemaVersion = 1` in normalized manifest output.
- Worker→JSON→Tray roundtrip is complete and second validation accepts an already valid manifest.
- `Test-UpdateCore.ps1` explicitly checks normalized schema version and a complete JSON roundtrip.
- Download source, SHA-256 gate, package validation, backup/rollback, unelevated installer helper, and all boot/TaskBroker/Storage/privilege paths remain unchanged.

**Native verification required:** install v0.5.7 manually, run `Auf neue Version prüfen…`, and confirm current-state message `Lenovo Boot Selector v0.5.7 ist aktuell.`. A later version is required for the first real successful self-update.

## v0.5.6 – Maintenance menu grouped by topic

v0.5.6 is a narrow UI/menu-structure patch based on v0.5.5. Update, boot, Storage, TaskBroker, and privilege logic are unchanged.

Changes:

- Maintenance submenu keeps thematic groups and now clearly orders them as **system functions → updates → diagnostics**.
- `Diagnose speichern…` is the final item at the bottom of the maintenance submenu.
- Exactly one separator appears between system functions/updates and updates/diagnostics.
- `Auf neue Version prüfen…` and `App aktualisieren…` retain their v0.5.5 behavior and semantics.
- No change to self-updater download/hash/backup/rollback, firmware/BCD paths, Scheduled Tasks, Storage detection, or boot-target logic.

**Native verification required:** open the maintenance submenu and visually confirm group order and both separators. Briefly regress v0.5.5 updater behavior.

## v0.5.5 – Manual self-updater

v0.5.5 introduces an explicitly user-started self-updater. There is still no periodic or automatic update check.

Changes:

- Tray maintenance menu exposes exactly `Auf neue Version prüfen…` and `App aktualisieren…`.
- `App aktualisieren…` is initially disabled and becomes enabled only after a successful check finds a genuinely newer valid version.
- Update metadata is read only from fixed public repository `SaschaP1980/LenovoBootSelector`.
- `downloads/latest.json` is the machine-readable manifest. Version format, filename, Git tag, file size, SHA-256, and expected flat package file list are strictly validated.
- Release ZIP is validated for size and SHA-256 before extraction. Any mismatch fails closed.
- ZIP must be flat; directories, `..` path components, and unexpected files are rejected.
- Download/package preparation run in hidden unelevated worker processes so network I/O does not block the tray UI.
- After successful preparation, a temporary unelevated update helper waits for the tray app to exit, backs up all managed release files, replaces them atomically best-effort, restarts the app through the existing VBS launcher, and rolls back to backups on installation failure.
- Settings, diagnostics, and TaskBroker state under `%LOCALAPPDATA%` / `%ProgramData%` are not changed by the updater.
- The updater has no `RunAs`/SYSTEM path and executes neither `bcdedit` nor Scheduled Task operations. If a future version needs different system functions, existing TaskBroker compatibility/repair logic remains responsible after restart.
- Update check, preparation, and helper start are logged through existing runtime diagnostics.
- Build revision history under `downloads/` remains. Every built product-source revision receives a versioned ZIP; older ZIPs remain.
- Every built version receives an immutable Git tag `vX.Y.Z` on its source commit.

### Native Windows acceptance required

In addition to existing Parser/Core/Refresh/Mutex/Soak/Maintenance/Drift tests, `Test-UpdateCore.ps1` must be fully green. Manual checks include at least “no new version”, “new version found”, bad hash/download, and one successful self-update with restart.

## Repository maintenance after v0.5.4

- `README.md` is a conventional GitHub project overview; continuous version history lives in `CHANGELOG.md`.
- `downloads/` is permanent build revision history, not only a folder for the latest ZIP.
- Architecture baselines and Catch Audits are planned for a controlled cleanup from repository root into `docs/architecture/` and `audits/` with test/build paths migrated together.

## v0.5.4 – USB boot medium named explicitly

v0.5.4 is based only on canonical v0.5.3 source. The patch changes only the user-facing label for the already read-only detected single USB boot candidate. Instead of probability wording, UI now describes the evidenced Storage finding directly. Boot, firmware, TaskBroker, Storage-refresh, and privilege architecture remain unchanged.

Change:

- **Exactly one USB boot candidate:** subtext beneath generic firmware target `USB HDD` or an alias such as `Windows: Gaming` is now `USB-Startmedium: <Modell>`. On the target system, `USB-Startmedium: SanDisk Extreme Pro USB4` is expected.
- **No new firmware binding:** wording states only which physical USB medium has detected boot structure. It still does not claim direct 1:1 addressability of the generic `USB HDD` firmware target.
- **All other USB states unchanged:** pending, real Storage failure, media not detected as boot media, multiple possible USB boot media, and no USB drive remain unchanged.

**Native verification required:** with SanDisk as the only detected USB boot candidate, full Storage refresh must show `USB-Startmedium: SanDisk Extreme Pro USB4`. v0.5.3 NVMe presentation and header/tray red must remain unchanged.

## v0.5.3 – NVMe slot presentation

v0.5.3 is based only on canonical v0.5.2 source. It changes only the read-only presentation of internal NVMe slots on the confirmed target ThinkPad. With exactly one internal NVMe detected by Windows, `NVMe-SSD 1` shows its model as `Interne SSD: <Modell>` and `NVMe-SSD 2` shows `Kein Laufwerk erkannt`. With multiple NVMe drives, no unsupported physical NVMe0/NVMe1 mapping is guessed and prior generic subtexts remain. Boot, firmware, TaskBroker, Storage-refresh, and privilege architecture are unchanged.

## v0.5.2 – USB pending state and Lenovo-red experiment

v0.5.2 is based only on canonical v0.5.1 source. It corrects USB presentation observed during native startup and includes two deliberately small UI experiments. Boot, Storage, and privilege architecture remain unchanged.

Changes:

- **USB check pending instead of error:** while first popup build has no `StorageContext` yet, `USB HDD` now shows `USB-Laufwerke werden geprüft …`. `USB-Laufwerke konnten nicht geprüft werden` remains only for completed failure state `UsbResolution = 'Unavailable'`.
- **Header experimentally Lenovo red:** `Lenovo Boot Selector` at upper left uses the existing Lenovo-red accent.
- **Tray menu clarified:** `Boot Selector öffnen` becomes `Lenovo Boot Selector öffnen` and is experimentally shown in Lenovo red. Other tray items are unchanged.
- **No refresh-architecture change:** no polling, no PnP/device-arrival handlers, no `Storage.ps1` change. Existing popup-first background refresh remains.
- **No new privileged mutation:** TaskBroker, BootService, installer/uninstaller, and firmware/BCD write boundaries are unchanged.

**Native verification required:** observe cold/app startup: first `USB-Laufwerke werden geprüft …`, then real USB state. Also verify header/tray menu text/color. A real Storage read failure must still show `USB-Laufwerke konnten nicht geprüft werden`.

## v0.5.1 – USB HDD semantics after read-only capability discovery

v0.5.1 is based only on canonical v0.5.0 source. Read-only USB direct-boot discovery showed that although the ThinkPad F12 menu can distinguish physical USB devices by name, BCD, standard UEFI, and documented Lenovo WMI surfaces expose only generic firmware target `USB HDD` as software-addressable. v0.5.1 therefore changes only presentation/terminology; privilege boundary and all mutating boot paths remain unchanged.

Changes:

- **Firmware target remains visible:** selectable entry is always `USB HDD`. A physical USB drive no longer replaces firmware title.
- **Physical medium is status only:** with exactly one detected USB boot candidate, subtext is `Wahrscheinlich: <Modell>`. With exactly one USB drive without detected boot structure, it is `<Modell> erkannt · nicht als Startmedium erkannt`.
- **Additional USB states:** no USB drive → `Kein USB-Laufwerk angeschlossen`; multiple drives without candidate → `USB-Laufwerke erkannt · kein Startmedium gefunden`; multiple candidates → `Mehrere mögliche USB-Startmedien erkannt`; failed Storage detection → `USB-Laufwerke konnten nicht geprüft werden`.
- **Drift wording clarified:** firmware-only drift is `Neues Startziel erkannt` instead of `Neues Gerät erkannt`; neutral change states refer to boot targets rather than physical boot devices.
- **No new USB addressing:** no SanDisk/Micron-specific Next Boot path, no new firmware variable, no Lenovo WMI setter, and no permanent `BootOrder` / `displayorder` mutation.
- **Refresh policy unchanged:** no PnP/device-arrival event handlers and no periodic polling. App start, existing refresh, and manual reload remain refresh triggers.

**Native verification required:** on target ThinkPad test at least `SanDisk + Micron`, `nur Micron`, and `kein USB` with full refresh. Title must remain `USB HDD` and subtext must switch between `Wahrscheinlich: SanDisk Extreme Pro USB4`, `Micron CT2000X9PROSSD9 erkannt · nicht als Startmedium erkannt`, and `Kein USB-Laufwerk angeschlossen`. Also verify firmware-drift simulation shows `Neues Startziel erkannt`.

## v0.5.0 – Read-only drift detection and reinitialization for new boot targets

v0.5.0 builds on natively fully approved v0.4.7. The app detects firmware/boot-target inventory changes strictly read-only and compares the current firmware target set with the TaskBroker target set authorized during setup. It never performs automatic repair or reinitialization.

Changes:

- **Read-only drift detection:** after fresh firmware/manager refresh, Boot Menu + `{fwbootmgr} displayorder` are compared with installed `task-broker.json` targets. Added and removed GUIDs are diagnosed separately.
- **New-target UX:** added firmware targets make the central popup show `Neues Gerät erkannt`. Removal-only drift shows `Startgeräte wurden geändert`. Primary action in both cases is `Systemfunktionen neu initialisieren`.
- **No auto-repair:** detection starts neither UAC nor setup automatically. Only explicit user confirmation invokes the existing safe installer path. Privilege boundary remains unchanged; no free GUID, task name, or argument is passed.
- **Drift blocks normal mutation:** while reinitialization is pending, BootNext, default target, Manage, Restart, and manual refresh are disabled/covered in normal UI. Read-only diagnostics remain available.
- **Reinitialize as a maintenance mode:** busy view and success dialog use user terminology `neu initialisieren` / `neu initialisiert`, not Repair. Existing `Reparieren` UX remains only for truly incomplete/old installations.
- **Diagnostics:** `BOOT_TARGET_DRIFT_CHECK` logs drift plus added/removed firmware GUIDs as Warning, not Runtime Error.
- **Native tests:** `Test-BootTargetDrift.ps1` checks equal set, added/removed targets, and drift runtime state. The Windows PowerShell 5.1 wrapper runs it too.

**Native verification required:** create/simulate a firmware/boot-target change on target PC, verify `Neues Gerät erkannt` and CTA `Systemfunktionen neu initialisieren`, confirm no UAC/mutation before user confirmation, complete reinitialization with UAC, then confirm drift disappears and normal boot functions are restored.

## v0.4.7 – Maintenance UX, first-run setup, and maintenance diagnostics

v0.4.7 is a required corrective/UX build after the first fully native maintenance-cycle test. Setup/Repair/Remove remain unchanged behind fixed SYSTEM Scheduled Tasks; only lifecycle locks, main-popup presentation, completion feedback, and maintenance-aware diagnostics change.

Changes:

- **Central maintenance state:** Setup, Repair, Migrate, and Remove use explicit busy state. Normal boot-target, default, Manage, Refresh, and Restart paths are blocked while active; running/pending background refresh work is stopped in a controlled way.
- **Prominent first-run/repair state:** when system functions are missing, main popup centrally offers `Systemfunktionen einrichten` as primary CTA. For an incomplete existing installation, it offers `Systemfunktionen reparieren`. On true first run the popup opens automatically; UAC starts only after explicit user confirmation.
- **Clear maintenance presentation:** during installation/repair/removal, a central app-native maintenance view covers normal UI. Popup stays visible and shows current state instead of still-interactive boot functions.
- **App-native completion:** successful Setup/Repair confirms `Systemfunktionen sind bereit.`; successful Remove confirms `Systemfunktionen wurden entfernt.`. UI is then deterministically rebuilt or moved to setup state.
- **Maintenance-aware diagnostics:** new refreshes are suppressed during maintenance; running refreshes are cancelled in a controlled way and logged as expected maintenance state. After successful Remove, intentionally missing TaskBroker is no longer emitted as a runtime error by normal ready check.
- **Soak harness corrected:** `Test-ArchitectureSoak.ps1` now correctly uses `-Source $raw` instead of `-Settings $raw` for Settings normalization.
- **No privilege change:** tray remains unelevated; no free commands/arguments/task names/GUIDs, no permanent `displayorder`, no custom SYSTEM EXE.

**Native verification required:** Windows PowerShell 5.1 wrapper including Maintenance test, first run without registered tasks, Setup/Repair/Remove/Re-Setup with busy UI and success dialogs, and final diagnostics with no expected maintenance conditions recorded as Error.

## v0.4.6 – Cleanup / soak and architecture completion

v0.4.6 completes the planned 0.4.x refactoring series behavior-preservingly. There is no new user-facing feature. The natively green v0.4.5 state remains behavior basis; cleanup occurs only where static call analysis and regression tests unambiguously protect removal/movement.

Changes:

- **Four dead runtime functions removed:** `Test-IsAdministrator`, `Get-PresentDiskPnpInfo`, `Find-MatchingPnpDisk`, and unused wrapper `Show-ManageEntriesMode` had no callers in modular source graph. They are not replaced.
- **Three dead globals removed:** `$script:AutostartTaskName`, `$script:ColorBorder`, and `$script:ColorFrame` were declarations with no readers.
- **Storage infrastructure explicit:** active still-heuristic Storage/USB path (`Test-PartitionBootStructure`, `Get-StorageContextCore`, `Get-StorageContext`) now lives in `src/Infrastructure/Storage.ps1`. Function bodies remain unchanged from v0.4.5.
- **Catch audit instead of silent ambiguity:** `CATCH_AUDIT_v0.4.6.json` classifies every remaining inline empty/best-effort `catch { }` in modular runtime source. `tools/build_catch_audit.py --check` ensures audit exactly matches source. Product-relevant failure paths remain explicitly diagnosed.
- **Native architecture soak:** `tests/Test-ArchitectureSoak.ps1` repeats refresh lifecycle, Settings normalization, firmware-manager parsing, and 30-second firmware freshness 500 times each. Windows PowerShell 5.1 wrapper runs this test in addition to Core, Refresh, and Mutex.
- **No security/UX change:** TaskBroker, BootService, RefreshRuntime, Settings service, Autostart, Diagnostics, and closed UI paths are unchanged. Popup-first, full-width hover/selected, red separators, eye/pencil tooltips, and taskbar-silent recovery dialog remain regression contracts.

**Native verification required:** `tests\Test-WindowsPowerShell51.ps1` must run Parser/Core/Refresh/Mutex/Soak fully green. Then run a longer tray/refresh/close-restart soak plus known boot/settings/autostart/diagnostics/UI regression paths.

## v0.4.5 – Settings/Autostart/Diagnostics infrastructure adapters

v0.4.5 is the next behavior-preserving architecture step based on natively confirmed v0.4.4 runtime/UI paths. Persistence, Registry/Task-Scheduler, and diagnostics filesystem access move out of App/UI layers behind named Infrastructure operations. There is no new user-facing feature.

Changes:

- **SettingsRepository:** file/JSON I/O and legacy Registry cleanup live in `src/Infrastructure/SettingsRepository.ps1`; normalization remains in Functional Core. `src/Application/SettingsService.ps1` continues to build the same Settings contract (`schemaVersion = 4`) and uses only named repository operations.
- **Autostart separated:** HKCU Run key, hidden VBS launcher, and read-only legacy-task detection live in `src/Infrastructure/Autostart.ps1`. WinForms state and user feedback live separately in `src/UI/AutostartPresentation.ps1`.
- **Runtime diagnostics separated:** session logging, retention, export ZIP, and Explorer reveal live in `src/Infrastructure/RuntimeDiagnostics.ps1`; manual UI action lives in `src/UI/DiagnosticsPresentation.ps1`.
- **No runtime module dependency:** release remains a deterministically generated single-file `LenovoBootMenuTray.ps1`; loose source modules are not loaded at runtime.
- **Abandoned-mutex test fixed:** parent opens its handle to named mutex before child owner process is terminated. An explicit file signal synchronizes exit so the test actually validates `AbandonedMutexException`. Product singleton implementation remains unchanged.
- **Security/UX unchanged:** TaskBroker, BootService, RefreshRuntime, BackgroundRefreshWorker, Functional Core, and existing UI modules remain unchanged. Popup-first, fixed SYSTEM tasks, full-width hover/selected, red separators, eye/pencil tooltips, and recovery dialog remain regression contracts.

**Native verification required:** `tests\Test-WindowsPowerShell51.ps1` must run Parser/Core/Refresh/Mutex fully green. Then perform short Settings/Autostart/Diagnostics smoke plus existing boot/UI regressions.

## v0.4.4 – UI source split without runtime behavior change

v0.4.4 is the next behavior-preserving architecture step based on natively fully confirmed v0.4.3 runtime/UI paths. WinForms presentation moves from App template into clearly named `src/UI/` modules; release remains a deterministically generated single-file `LenovoBootMenuTray.ps1`. There is no new user-facing feature.

Changes:

- **UI source modularized:** startup error dialog, menu rendering/tooltips, refresh presentation, Manage mode, default-target presentation/menu, app dialogs, boot-target list, and popup live in ten `src/UI/*.ps1` modules.
- **No runtime module dependency:** `tools/build_runtime.py` still bundles Core, Application, Infrastructure, and UI deterministically into one runtime file. No loose modules are imported at runtime.
- **UI behavior frozen:** 34 moved UI functions are characterized against function SHA-256 from native v0.4.3 basis. Full-width hover/selected, red separators, eye/pencil tooltips, and taskbar-silent recovery dialog remain unchanged.
- **Layer boundary:** `src/UI/` may not call privileged Scheduled Task/TaskBroker mechanisms directly. Privileged operations remain only behind Infrastructure/Application.
- **App template substantially smaller:** generated runtime may remain large; editable App shell contains much less Presentation code.
- **Mutex test harness fixed:** temporary Named Mutex paths in `Test-SingleInstanceMutex.ps1` correctly use exactly one backslash (`Local\...`), allowing Windows PowerShell 5.1 test to create real namespace.
- **No functional change:** RefreshRuntime, BackgroundRefreshWorker, TaskBroker, BootService, Functional Core, installer/uninstaller, and launcher remain semantically unchanged.

**Native verification required:** `tests\Test-WindowsPowerShell51.ps1` must run Parser/Core/Refresh/Mutex fully green. Then perform short UI smoke for popup, boot-target list, Manage mode, default-target menu, dialogs, full-width hover/separators/tooltips, and recovery dialog.

## v0.4.3 – Explicit Refresh Runtime state

v0.4.3 is the next behavior-preserving architecture step based on natively fully confirmed v0.4.2.2. There is no new user-facing feature. Goal: move background refresh, request coalescing, result processing, and refresh lifecycle from scattered global `$script:` state into clearly bounded contracts without changing popup-first or privileged TaskBroker boundary.

Changes:

- **One refresh state instead of nine globals:** process, timer, result file, active request, pending request, and last timing live in explicit `BackgroundRefreshState`. Old globals `BackgroundRefreshProcess`, `BackgroundRefreshTimer`, `BackgroundRefreshResultPath`, `BackgroundRefreshRequested*`, `BackgroundRefreshPending*`, and `LastBackgroundRefreshTiming` are removed.
- **Request/transition logic extracted:** `src/Application/RefreshRuntime.ps1` contains stateless refresh contract for request creation, firmware freshness, escalation/coalescing, lifecycle adoption, pending request, and result parsing. Module uses no `$script:` state, WinForms, or process/filesystem API.
- **Process/result I/O isolated:** `src/Infrastructure/BackgroundRefreshWorker.ps1` launches only the existing hidden unelevated Windows PowerShell worker and encapsulates result read/cleanup. UI/Application no longer creates `ProcessStartInfo` directly.
- **Completion split:** lifecycle completion, result read/parse, and UI/cache application are separate responsibilities (`Complete-BackgroundBootRefresh`, `Get-BackgroundRefreshResult`, `Apply-BackgroundRefreshResult`).
- **Coalescing unchanged:** active refresh gets no redundant follow-up job. Only newly required Storage/firmware work is merged into pending request.
- **Popup-first unchanged:** firmware/Storage work remains in unelevated background worker. Popup still does not wait for fresh Scheduled Task/Storage run.
- **Security boundary unchanged:** `src/Infrastructure/TaskBroker.ps1`, `src/Application/BootService.ps1`, Functional Core, installer/uninstaller, and launcher are byte-identical to v0.4.2.2. No free command/argument/GUID interface, no permanent `displayorder` mutation, and no custom SYSTEM EXE.
- **New native characterization:** `tests/Test-RefreshRuntime.ps1` validates refresh-state/request contract with 18 checks under Windows PowerShell 5.1 and is run by existing `Test-WindowsPowerShell51.ps1`.

**Native verification required:** app start/popup-first, multiple refreshes, fast popup open during running refresh, Storage escalation, BootNext/default regression, UI regressions, and diagnostics export. Wrapper must additionally report `REFRESH TOTAL 18/18`.

## v0.4.2.2 – Robust singleton mutex

v0.4.2.2 is a targeted stability patch based on v0.4.2.1. Trigger was a native startup finding: app reported `läuft bereits` even though afterward neither a matching process nor named mutex existed. Boot, firmware, TaskBroker, and main UI logic remain unchanged.

Changes:

- **Actual ownership instead of `createdNew`:** tray singleton still uses named mutex `Local\LenovoBootMenuTray` but now decides via `WaitOne(...)` whether current process actually owns it. An existing but free kernel object is no longer treated as a running app.
- **Fast first start unchanged:** normal first start tries `WaitOne(0, $false)` and acquires without extra wait. Only a competing start gets one 500-ms grace retry so an exiting process can release cleanly.
- **Abandoned recovery:** `AbandonedMutexException` is explicitly treated as acquired ownership. A crashed/early-exited old instance no longer blocks next start.
- **Clean ownership cleanup:** `ReleaseMutex()` runs only if this process owns the mutex; Dispose remains best-effort.
- **Diagnostics:** successful ownership logs `SINGLE_INSTANCE_MUTEX_ACQUIRED`; takeover after abandonment logs `SINGLE_INSTANCE_MUTEX_ABANDONED_RECOVERED`.
- **Native mutex test:** `tests/Test-SingleInstanceMutex.ps1` checks active foreign owner, release/takeover, and abandoned recovery under Windows PowerShell 5.1 with unique temporary mutex name. `Test-WindowsPowerShell51.ps1` runs it after Parser/Functional-Core gate.
- **v0.4.2.1 patches retained:** custom startup error dialog without taskbar entry and UTF-8 BOM rule for non-ASCII PowerShell sources remain unchanged.

**Native verification required:** run `tests\Test-WindowsPowerShell51.ps1`, verify normal first start, real double start (only second rejected with `läuft bereits`), then exit tray and immediately restart; no false positive is allowed.

## v0.4.2.1 – Custom startup error dialog and PS5.1 encoding fix

v0.4.2.1 is a targeted UX/compatibility patch based on v0.4.2. TaskBroker/BootService architecture, boot logic, and privilege boundaries remain unchanged.

Changes:

- **Custom startup error dialog:** unbound native `MessageBox` is replaced with compact WinForms recovery dialog in Lenovo Boot Selector style. It has no own taskbar entry (`ShowInTaskbar = $false`) and uses Lenovo red only as accent.
- **Clear recovery actions:** on a real fatal startup error, `Erneut starten`, `Diagnose öffnen`, and `Schließen` are available. Restart occurs only after tray mutex release via existing hidden VBS launcher. `Erneut starten` is disabled if another instance is already running.
- **Taskbar fallback hardened:** if custom dialog cannot be built, native MessageBox is bound only to invisible owner with `ShowInTaskbar = $false`.
- **PS5.1 encoding fix:** modular PowerShell sources with non-ASCII content are shipped UTF-8 with BOM. This preserves `Lenovo Boot-Menü` when directly dot-sourced under Windows PowerShell 5.1.
- **Windows gate extended:** `tests/Test-WindowsPowerShell51.ps1` additionally checks encoding rule for non-ASCII `.ps1` files and still runs Functional Core.
- **No boot/security change:** no changes to fixed SYSTEM tasks, TaskBroker schema 0.2.12, GUID allowlist, `{fwbootmgr} bootsequence`, default logic, cleanup, or popup-first.

**Native verification required:** provoke/use dedicated path for startup error on target PC: no PowerShell taskbar icon, app-style dialog, `Diagnose öffnen`, `Schließen`, and `Erneut starten` correct. Also run `tests\Test-WindowsPowerShell51.ps1` natively.

## v0.4.2 – Explicit TaskBroker / BootService boundary

v0.4.2 is the second behavior-preserving refactoring build of the 0.4.x series. Natively fully confirmed v0.4.1 runtime is basis; parked v0.3.5/v0.3.6 features remain unimplemented.

Changes:

- **Historical `Invoke-BcdEdit` pseudo-API removed:** tray runtime has no generic BCDEdit compatibility layer. Read-only firmware access, BootNext, and system-wide default target use clearly named operations.
- **Infrastructure module introduced:** `src/Infrastructure/TaskBroker.ps1` encapsulates TaskBroker metadata, exact Scheduled Task start, cache/status files, and fixed broker operations. Generic internal task starter is no longer called directly outside module.
- **Explicit broker operations:** `Get-TaskBrokerFirmwareManagerText`, `Get-TaskBrokerFirmwareEntriesText`, `Get-TaskBrokerDefaultTargetGuid`, `Set-TaskBrokerBootNextTarget`, `Set-TaskBrokerDefaultTarget`, and `Clear-TaskBrokerDefaultTarget` represent allowed domain-level broker access.
- **Application Boot Service introduced:** `src/Application/BootService.ps1` reads firmware data through Infrastructure boundary, delegates text parsing to Functional Core, and verifies BootNext after write by reading back `bootsequence`.
- **BootNext terminology clarified:** UI/shell path is now `Set-BootNextTarget`; historical `Set-BootSequence` is removed. Actual privileged behavior is unchanged: only preinstalled GUID-bound SYSTEM task may set `{fwbootmgr} bootsequence`.
- **Default Set/Clear decoupled:** `Set-DefaultGuid` knows no task names and calls only explicit broker operations. Target GUIDs are still resolved only against installed TaskBroker metadata.
- **Background refresh decoupled:** worker uses explicit read-only broker operations; main window syncs cache files through Infrastructure adapter. Popup-first unchanged.
- **No privilege-surface growth:** no free command/argument/task-name/GUID interface introduced; `Invoke-AuthorizedTask` remains internal Infrastructure mechanism. Installer/uninstaller, task definitions, ACLs, and TaskBroker schema **0.2.12** are byte-identical.
- **PS5.1 test finding fixed:** three ambiguous `$Name:` interpolations found on Windows in `tests/Test-FunctionalCore.ps1` are corrected to `${Name}:`. `tests/Test-WindowsPowerShell51.ps1` now natively parses all shipped `.ps1` sources with Windows PowerShell parser and then runs Functional Core.
- **Closed UI paths unchanged:** full-width hover/selected, red separators, and eye/pencil tooltips are not functionally changed.

**Native verification:** v0.4.1 was fully native GREEN (S01 24/24, S02–S16 UI clean, S17 diagnostics without runtime errors). v0.4.2 changes internal broker/BootService calls and therefore requires targeted Windows smoke for firmware read/refresh, BootNext read-back, Default Set/Clear, and closed UI regressions.

## v0.4.1 – Functional Core

v0.4.1 is the first behavior-preserving refactoring build of the 0.4.x series. The prior single-file runtime remains for deployment/startup but is now **deterministically generated from modular source files**. There is no intended functional, UX, security, or privilege change.

Changes:

- **Functional Core introduced:** `src/Core/EntryPreferences.ps1`, `src/Core/FirmwareParsing.ps1`, and `src/Core/BootTargetModel.ps1` contain deterministic logic with no global script state, WinForms, filesystem, Registry, Scheduled Tasks, process starts, or privileged broker access.
- **Settings normalized:** `Get-AppSettings` remains I/O shell and delegates default/normalization logic to Core. Schema **4** unchanged.
- **Entry Preferences extracted:** alias normalization, sequence/map comparison, GUID-list validation, and sort/visibility live in Core; `Get-OrderedEntriesForUi` is only a thin state adapter.
- **Firmware text parser extracted:** GUID, firmware-entry, `displayorder`, and `bootsequence` parsing live in Core. `Get-FirmwareBootState` retains only cache/TaskBroker/Storage orchestration.
- **Friendly boot-target model presentation-neutral:** classification emits `AccentRole` token; only UI shell maps token to existing `Drawing.Color` values. User text and USB heuristic unchanged.
- **Deterministic single-file build:** `src/App/LenovoBootMenuTray.template.ps1` plus Core modules are bundled byte-exact by `tools/build_runtime.py` into `LenovoBootMenuTray.ps1`. Release remains flat and needs no additional runtime modules.
- **Regression gates extended:** all v0.3.4/v0.4.0 critical fragments not intentionally refactored remain SHA-256-identical. New Core/Boundary gates cover three intentionally changed shell functions.
- **Security architecture unchanged:** unelevated tray; fixed allowlisted SYSTEM Scheduled Tasks; no free commands/arguments/GUIDs; only `{fwbootmgr} bootsequence`; no permanent `displayorder`; no custom SYSTEM EXE; bounded cleanup.
- **Popup-first and closed UI paths unchanged:** full-width hover/selected, red separators, eye/pencil tooltips, and background-worker ordering are unchanged.
- **Parked features remain parked:** formerly planned v0.3.5/v0.3.6 features are not part of v0.4.1.

**Native verification:** Linux build environment cannot execute Windows PowerShell 5.1, WinForms, Task Scheduler, or UEFI. Because v0.4.1 first changes productive internal structure, a short Windows smoke is recommended before next refactor: app start, popup-first, boot-target list/names, alias/visibility/order, refresh, and already-closed hover/separator/tooltip paths. Task/ACL code is unchanged.

## v0.3.4 – Full-width hover over actual DropDown client area

v0.3.4 is an isolated WinForms Hotfix based on v0.3.3. Native v0.3.3 testing confirmed hover and red separators were restored, but a narrow dark remainder still stayed on the right. Root cause: selection background was still painted in the per-item renderer. WinForms clips that Graphics context to item/content area, so the system-reserved right padding/grip area of the DropDown could not be reliably covered even with a mathematically larger rectangle.

Changes:

- **Selection paint moved to real DropDown surface:** hover/selected background is now drawn in `OnRenderToolStripBackground(...)`. This renderer operates on full `ToolStripDropDown.ClientRectangle` and can cover the previously excluded right remainder.
- **Exact full width:** root menus use full `ClientRectangle` width. Submenus leave only their existing neutral 1-px edge.
- **Deterministic hover detection retained:** `GetVisualHotItem(...)` still uses current mouse position plus row hit test; `Selected`/`Pressed` remains fallback for keyboard navigation/open submenu.
- **Item renderer no longer paints selection background:** `OnRenderMenuItemBackground(...)` remains responsible only for checkmarks and submenu arrows, preventing item-local clip bounds from truncating full-width background.
- **Separators unchanged:** local separator paint fixed in v0.3.3 (`Item.Height / 2`) remains.
- **No new timing logic:** no `PaintSelectionTail`, timer, or delayed `BeginInvoke`; existing synchronous full invalidates remain.
- **No security change:** TaskBroker schema stays **0.2.12**, Settings schema **4**. BootNext, Default, runtime diagnostics, allowlist, ACL, cleanup, and restart semantics unchanged.

**Native verification required:** repeatedly open tray context menu, `Wartung`, and `Standard-Startziel` and hover every row slowly/quickly to right edge. Highlight must reach actual right client edge with no dark remainder; red separators, checkmarks, arrows remain correct.

## v0.3.3 – ToolStrip coordinate fix for hover and separators

v0.3.3 is an isolated native WinForms renderer Hotfix based on v0.3.2. v0.3.2 made hover deterministic but incorrectly handled coordinate systems in per-item renderers: `item.Bounds.Top` was added again inside an already item-local Graphics context. Hover was effectively visible only in first row, and red separators were painted vertically outside their items.

Changes:

- **Item-local hover paint:** `FullRowBounds(...)` always starts vertically at `Y = 0`. DropDown client edges are translated only horizontally into local item coordinates.
- **Full width retained:** selection background still reaches real DropDown client edge; no separate tail paint, timer, or delayed `BeginInvoke` is reintroduced.
- **Red separators visible again:** `OnRenderSeparator(...)` draws at `Item.Height / 2` in local separator coordinates. Again, only horizontal client edges are translated.
- **Checkmarks and submenu arrows fixed:** both use same local full-row rectangle as hover background.
- **Hover detection still deterministic:** current mouse position plus row hit test remains authoritative; `Selected`/`Pressed` only fallback for keyboard/open submenu.
- **No security change:** TaskBroker schema **0.2.12**, Settings schema **4**. BootNext, Default, runtime diagnostics, allowlist, ACL, cleanup, and restart semantics unchanged.

**Native verification required:** in tray context menu, `Wartung` submenu, and `Standard-Startziel` DropDown, hover every row repeatedly slowly/quickly. Every row must highlight fully and red horizontal separators remain continuously visible.

## v0.3.2 – Deterministic full-width hover in DropDown menus

v0.3.2 is a targeted native WinForms Hotfix based on v0.3.1. Eye/pencil tooltips and diagnostics Explorer path fixed in v0.3.1 remain unchanged. BootNext, TaskBroker, Default, diagnostics, cleanup, privilege, and Settings architecture remain functionally unchanged.

Changes:

- **Hover race removed:** hover/selected area no longer depends on whether `ToolStripMenuItem.Selected` had already updated during a particular paint cycle.
- **One controlled paint path:** `LenovoMenuRenderer.OnRenderMenuItemBackground` derives current row directly from mouse position and paints complete row in owner coordinates to actual DropDown client edge.
- **Right remainder no longer separately repainted:** v0.3.1 workaround `PaintSelectionTail(...)` removed completely; delayed `BeginInvoke` / `QueueFullInvalidate` path also removed.
- **Immediate full repaint:** both custom DropDown classes synchronously invalidate entire small menu surface on mouse movement, eliminating delayed second paint step.
- **Checkmarks/submenu arrows in same item pass:** right-side state indicators are painted with full-width row and cannot be overwritten by later tail fill.
- **Keyboard/submenu behavior retained:** when mouse is outside menu, native `Selected`/`Pressed` still used for keyboard navigation/open child submenu.
- **No security change:** TaskBroker schema **0.2.12**, Settings schema **4**. No change to privileged tasks, allowlist, `{fwbootmgr} bootsequence`, `displayorder`, ACLs, cleanup, or restart semantics.

**Native verification required:** repeatedly open tray context menu, `Wartung`, and `Standard-Startziel` and move mouse slowly/quickly across all rows. Hover must reach intended client edge without dark right remainder in every cycle.

## v0.3.1 – Tooltip focus fix, complete DropDown hover, and reveal diagnostics file

v0.3.1 is a targeted Hotfix/UX build based on v0.3.0. Runtime diagnostics from v0.3.0 remain; BootNext, TaskBroker, Default, cleanup, privilege, and Settings architecture remain functionally unchanged.

Changes:

- **Eye/pencil no longer close UI:** separate `LenovoDarkToolTipForm` introduced in v0.2.35 is removed from this path. Eye and pencil now use owner-drawn `System.Windows.Forms.ToolTip`, avoiding an app `Form` that could deactivate main window and trigger `Deactivate → Hide`.
- **Dark tooltip style retained:** tooltips remain square, dark, compact and use exact UI literals `Sichtbar – klicken zum Ausblenden`, `Verborgen – klicken zum Einblenden`, and `Anzeigename ändern`. Position remains screen-aware right of icon or left when space is insufficient.
- **DropDown hover to real right client edge:** in addition to existing full-row renderer, `LenovoContextMenuStrip` and `LenovoDropDownMenu` repaint any remaining right selection tail after normal WinForms painting. The neutral 1-px submenu edge remains excluded.
- **Find diagnostics ZIP directly:** success dialog `Diagnose gespeichert` adds action `Im Ordner anzeigen` beside `OK`. It opens Windows Explorer with `/select,"<Diagnose-ZIP>"` so the generated package is selected; visible storage path remains.
- **Diagnostics for new action:** success/failure of Explorer launch is logged best-effort as `DIAGNOSTIC_REVEAL`. Failure does not block app.
- **No security change:** TaskBroker schema **0.2.12**, Settings schema **4**. No new privileged interface, free GUID/arguments, or change to `{fwbootmgr} bootsequence`, allowlist, task ACLs, cleanup, or restart semantics.

**Native verification required:** hover eye/pencil repeatedly without main window disappearing. Verify gapless hover/selected surface to right edge in root, `Wartung`, and `Standard-Startziel` DropDowns. Diagnostics export `Im Ordner anzeigen` must open Explorer and select exact generated ZIP.

## v0.3.0 – Complete runtime diagnostics

v0.3.0 implements phase 1 of technical build plan after v0.2.35. Focus is continuous read-only runtime diagnostics so technical causes remain traceable while visible UI stays user-friendly. BootNext, TaskBroker, Default, cleanup, privilege, and Settings architecture remain functionally unchanged.

Changes:

- **One diagnostics session per app start:** every normal tray start gets random `sessionId`. Hidden background refresh carries same session ID so UI/worker events land in one chronological `runtime.jsonl` session.
- **Structured append-only events:** events contain UTC time, session, app version, process role, event/stage, success, duration, and on errors class/text. Diagnostic write failures are swallowed and may never block app/boot action.
- **Covered paths:** BootNext set, default-target set/clear, authorized Scheduled Tasks, TaskBroker ready check, manager/firmware refresh, background refresh including phase timings, Storage/USB resolution, Autostart, setup/repair, cleanup, restart, and UI/unhandled/fatal exceptions.
- **Background timings persisted:** `ReadyMs`, `ManagerMs`, `FirmwareMs`, `StorageMs`, and `TotalMs` measured since v0.2.26 are now also written to runtime diagnostics.
- **Maintenance → save diagnostics:** compact diagnostics ZIP for **current session** can be created any time from maintenance submenu.
- **Diagnostics package deliberately small:** contains `runtime.jsonl`, `environment.json`, `task-broker-summary.json`, and `summary.txt`. Historical runtime sessions, `settings.json`, and user files are excluded.
- **Data minimization:** broker `userSid`, username, and machine name are excluded from export. Technical error text is scrubbed best-effort of `%LOCALAPPDATA%`, `%USERPROFILE%`, username, and machine name.
- **30-day retention:** old runtime-session directories are best-effort removed after 30 days. Cleanup cannot block app functionality.
- **Error hooks:** WinForms thread exceptions, AppDomain unhandled exceptions, and outer fatal path write structured diagnostics when session is available.
- **No privilege change:** TaskBroker schema **0.2.12**, Settings schema **4**. Installer/uninstaller, fixed task names, task ACLs, allowlist, `{fwbootmgr} bootsequence`, and `shutdown.exe /r /t 0` unchanged from v0.2.35.

**Native verification required:** Linux build environment cannot run Windows PowerShell 5.1, Task Scheduler, WinForms, or UEFI. On target PC verify successful/failed BootNext, background refresh, Autostart change, Setup/Repair failure, and export via `Wartung → Diagnose speichern…`. Exported ZIP must contain only current session and four documented files.

## v0.2.35 – Consistent tooltips and full-width DropDown interaction

v0.2.35 is a targeted UI/UX quality pass based on v0.2.34. BootNext, TaskBroker, Default, cleanup, display-name, and background-refresh architecture remain unchanged.

Changes:

- **Custom dark visibility tooltips:** eyes in mode `STARTZIELE ANPASSEN` no longer use bright native Windows tooltips. A square dark app tooltip appears with subtle neutral edge and automatic left/right positioning within current working area.
- **Shorter visibility text:** open eye `Sichtbar – klicken zum Ausblenden`; crossed-out eye `Verborgen – klicken zum Einblenden`.
- **Pencil explains function:** same dark tooltip style shows `Anzeigename ändern`.
- **Boot-menu subtext in edit mode:** unchanged entry `Lenovo Boot-Menü` now shows descriptive subtext `Auswahlmenü für das nächste Startziel`. Entries with display name still show `Originalname: …`.
- **DropDown width contract strengthened:** root context menu, `Standard-Startziel`, and `Wartung` use custom ToolStripDropDown classes with real minimum width at preferred-size level. After each native layout phase, all items stretch to full usable client width so hit-test, hover, selected, check, and arrow zones share same real row width.
- **Hover repaint after native selection:** asynchronous full-surface invalidation after mouse movement ensures owner-based hover/selected background is painted after internal WinForms selection updates, preventing dark right remainder.
- **Maintenance submenu uses same contract:** explicitly uses same full-width DropDown layout as root/default target menu; existing neutral submenu edge remains.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. Firmware GUIDs, BootNext targets, task names, allowlist, default target, cleanup boundaries, and unelevated app semantics unchanged.

**Native verification required:** on target PC verify complete hover/selected width in root/maintenance/default-target menus, hit testing to right edge, and position/readability/non-focus behavior of new dark tooltips.

## v0.2.34 – Visibility tooltips and red settings separator

v0.2.34 is a small UI/UX quality pass based on v0.2.33. BootNext, TaskBroker, Default, cleanup, display-name, and background-refresh architecture remain unchanged.

Changes:

- **Visibility eye explains state/action:** open eye tooltip is `In der Standardansicht sichtbar – klicken zum Ausblenden`; crossed-out eye tooltip is `In der Standardansicht verborgen – klicken zum Einblenden`.
- **Robust tooltip fallback:** in addition to normal WinForms `ToolTip.SetToolTip(...)`, owner-drawn visibility icon has explicit `MouseHover` / `MouseLeave` path, matching proven marker-tooltip fallback.
- **Red separator before restart area:** horizontal line between `Einstellungen` and `Windows neu starten` now uses Lenovo red instead of neutral gray.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. Firmware GUIDs, BootNext targets, task names, allowlist, default target, cleanup boundaries, and unelevated app semantics unchanged.

**Native verification required:** visually check tooltips for open/crossed eye and red separator between settings/restart area.

## v0.2.33 – Major end-user UI/UX quality pass

v0.2.33 is a comprehensive quality build based on v0.2.32. Goal: substantially more consistent and understandable end-user UI without unnecessary technical terminology. BootNext, TaskBroker, Default, cleanup, alias persistence, and background-refresh architecture remain unchanged.

Changes:

- **End-user vocabulary standardized:** visible UI consistently uses exact historical German terms `Startziel`, `Standard-Startziel`, `Einstellungen`, `Anzeigename`, and `Systemfunktionen`. Implementation terms such as privileged tasks, TaskBroker, Default-Restore, Scheduled Tasks, HKCU, and ExitCodes are removed from normal dialogs/menus.
- **Manage mode made clearer:** `VERWALTEN` becomes `ANPASSEN`; `EINTRÄGE VERWALTEN` becomes `STARTZIELE ANPASSEN`; section `KONFIGURATION` becomes `EINSTELLUNGEN`.
- **Visibility uses icon instead of ON/OFF:** an eye is drawn at previous ON/OFF location. Open eye = visible in standard view; crossed eye = hidden. Hidden rows remain dimmed; tooltip explains state.
- **Alias becomes display name:** visible UI uses `Anzeigename` / `Umbenennen` instead of Alias. `Originalname:` and `Leer lassen = Originalname` clarify semantics. Technical Settings structure `entryAliases` remains for compatibility.
- **Default target clearer:** `Kein Standard` becomes `Kein Standardziel`. Restart row shows `Nächstes Ziel: …`; technical `Firmware-Standardreihenfolge` is simplified to `Standardreihenfolge`.
- **Boot-target text simplified:** tooltips/subtitles avoid unnecessary terms such as NVMe/PCIe, PXE, firmware boot selection, or on-premise unless decision requires them. Examples include `Interne SSD`, `Netzwerkstart`, `Wiederherstellung über das Netzwerk`, `Start über das Firmennetzwerk`.
- **Marker tooltips shortened:** compact meanings such as `Rot: Lenovo Boot-Menü`, `Gelb: USB-Laufwerk`, `Blau: interne SSD`, `Violett: Netzwerkstart`, `Grau: weiteres Startziel`.
- **Maintenance clearer:** menu items become `Systemfunktionen einrichten/reparieren…` and `Systemfunktionen entfernen…`. Internal task/broker terms are removed from menu.
- **Custom maintenance dialogs:** Setup, Repair/Migration, Remove use square dark app-style dialogs instead of bright Windows MessageBoxes, with red accent and clear primary/secondary action. Text explains consequences rather than implementation.
- **User-friendly errors:** common interactive errors no longer expose raw exception/task/path/ExitCode text. UI names failed action and understandable next step; technical details stay in diagnostics.
- **Tray menu text:** `Bootauswahl öffnen` becomes `Boot Selector öffnen`. Tray tooltip is `Lenovo Boot Selector – Startziel wählen`.
- **Refresh help:** reload icon tooltip is `Startziele aktualisieren`.
- **Restart dialog simplified:** target heading is `NÄCHSTES ZIEL`; redundant sentence `Dieses Ziel wird beim Neustart verwendet.` removed.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. Firmware GUIDs, BootNext targets, task names, allowlist, default state, cleanup boundaries, and unelevated app semantics unchanged.

**Native verification required:** Linux build environment cannot run Windows PowerShell 5.1/WinForms. On target PC verify new dark system-function dialogs, eye icon, all revised text/tooltips, and existing menu/hover/alias/restart regressions.

## v0.2.32 – Robust full-width menus and cleaner management footer

v0.2.32 is a UI/UX correction pass based on v0.2.31. BootNext, TaskBroker, Default, cleanup, alias, and background-refresh architecture remain unchanged.

Changes:

- **Menu hover/selection centrally rerendered:** shared `LenovoMenuRenderer` no longer paints hover/pressed inside native content-based `ToolStripItem` paint area. Complete row surfaces are drawn directly in `ToolStripDropDown` owner coordinates from `ClientSize`, independent of `MinimumSize`, text width, and WinForms item clipping.
- **Right-side state instead of left checkbox gutter:** checked states such as `Mit Windows starten` and active `Standard-Startziel` render as red checkbox with white check at right edge. Text stays left; no overlapping checkmark column.
- **Submenu arrows stabilized at right:** arrows for `Wartung` and future submenus are owner-drawn in fixed right zone.
- **Separators remain full-width:** red horizontal group separators drawn over real DropDown inner width. Maintenance submenu keeps only subtle neutral 1-px edge, no red outer/top border.
- **No fragile item stretching:** v0.2.31 workaround with `AutoSize = false` and post-layout `Item.Size` removed. WinForms may calculate normal text sizes; visible hover/selected surface is decoupled.
- **Version no longer clipped:** normal view has dedicated 20-px footer. Version is vertically centered with guaranteed bottom spacing; Manage mode also has dedicated footer.
- **Alias field with clear action:** small `×` appears at right when text exists; clears only current field, keeps focus, saves nothing. `✓ Übernehmen`, `Esc`/`Abbrechen`, and global save remain.
- **Management footer restructured:** `Reihenfolge & Sichtbarkeit` becomes `ÄNDERUNGEN`. Compact hints: `Ziehen = Reihenfolge · Klick = Ein/Aus · Stift = Alias` and `Alias leer = Originalname · Ausgegraut = ausgeblendet`.
- **Buttons horizontal:** `Abbrechen` left; `Änderungen speichern` right as larger primary action.
- **Dirty state for Save:** `Änderungen speichern` enabled/Lenovo-red only if order, visibility, alias draft, or current alias text differs from initial state; otherwise dark/disabled.
- **Tray menu stays reduced:** `Aktualisieren` and `Standard-Startziel` remain only in main UI; tray contains only `Bootauswahl öffnen`, `Mit Windows starten`, `Wartung`, `Windows neu starten`, and `Beenden`.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**.

**Native verification required:** verify full hover/selected width in root/maintenance/default-target menus, right-side checks/arrows, alias clear button, Save dirty-state, and unclipped version.

## v0.2.31 – Consistent menus and simplified lower third

v0.2.31 combines menu/layout issues confirmed by native v0.2.30 smoke with requested UX revision of lower third. BootNext, TaskBroker, Default, cleanup, alias, and background-refresh architecture remain unchanged.

Changes:

- **Tray context menu reduced:** `Aktualisieren` and `Standard-Startziel` removed from tray context menu. Refresh remains in main popup; default target remains in popup configuration area.
- **Shared menu-width fix:** layout forces all `ToolStripItem` elements after native DropDown layout to actual usable client width and repeats once via `BeginInvoke` after WinForms layout. Hover/selected surfaces should therefore reach full usable width in root, maintenance submenu, and default-target popup.
- **No separate native check margin:** `ShowCheckMargin` and `ShowImageMargin` disabled. Checked states are drawn by shared renderer within actual menu row, not separate left gutter.
- **Continuous red separators:** group dividers span complete usable width. Root menu retains only meaningful separations before `Windows neu starten` and `Beenden`.
- **Maintenance submenu cleaned:** submenus stay visually second-level via slightly lighter background + subtle neutral 1-px edge; red top/outer border removed.
- **Lower third restructured:** `Mit Windows starten` and `Standard-Startziel` are equivalent configuration rows: label left, state/value right.
- **Autostart state right-aligned:** checkbox for `Mit Windows starten` sits compactly on right; label separately clickable.
- **Default target clearer:** row explicitly named `Standard-Startziel`; current target name right, followed by arrow.
- **Restart contextual:** under `Windows neu starten`, actual next target shown, e.g. `mit Lenovo Boot-Menü`.
- **Duplicate status removed:** prior footer pair `Nächster Start: …` + `Die Auswahl gilt nur für den nächsten Start.` removed. Version remains subtle at lower right.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. BootNext, system-wide default, alias persistence, custom restart dialog, popup-first background refresh, and privileged Scheduled Task boundaries unchanged.

**Native verification required:** verify full hover/selected width root/maintenance menu, integrated checked state, full separator width, no red submenu border, and new lower third.

## v0.2.30 – Reliable menu hover and flat alias focus

v0.2.30 is a targeted UI fix based on v0.2.29. BootNext, TaskBroker, Default, cleanup, alias persistence, and background-refresh architecture remain unchanged.

Changes:

- **Menu hover centrally corrected:** shared `LenovoMenuRenderer` now consistently treats render context as item-local coordinates. Previous heuristic using `VisibleClipBounds` and `item.Bounds.Top` removed because lower items could paint hover outside visible row.
- **All DropDown levels benefit:** hover/pressed always starts local `Y = 0`; X is translated to actual owner client origin and area expanded to `ToolStripDropDown.ClientSize.Width`. Applies to root menu, `Standard-Startziel`, `Wartung`, checked items, and future submenus.
- **Alias field without full red border:** expanded alias editor stays wide/dark but no surrounding red focus border; only a **1-px underline** indicates focus.
- **Subtle focus state:** without focus bottom line neutral gray; on focus only line becomes Lenovo red. Textbox itself borderless dark.
- **Alias semantics unchanged:** `Enter` accepts into edit draft, `Esc` discards current input, `✓ Übernehmen` / `× Abbrechen` remain, and only global `Speichern` persists alias/order/visibility.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. Popup-first background refresh, boot-target tooltips, custom restart dialog, context-menu chrome, and GUID-bound alias persistence unchanged.

**Native verification required:** verify hover/selected at all positions in `Standard-Startziel` submenu and new alias-focus state.

## v0.2.29 – Clearer header, configuration block, and alias editor

v0.2.29 is a pure UI/UX pass based on v0.2.28. BootNext, TaskBroker, Default, cleanup, alias persistence, and background-refresh architecture remain unchanged. Visible product name is now **Lenovo Boot Selector**; historical internal task/path names remain for compatibility.

Changes:

- **New visible app name:** header, tray tooltip, user-facing dialog/balloon titles use `Lenovo Boot Selector`. Internal task names, `%LOCALAPPDATA%` / ProgramData paths, and legacy identifiers unchanged.
- **Header simplified:** decorative red dot removed. Permanent subtitle `Einmaliges Startziel · Geräte erkannt` removed. Idle header shows only app name and refresh button.
- **Dynamic refresh status:** only while background refresh runs, `Aktualisiere Bootziele…` appears temporarily. Title moves slightly upward and recenters after completion. Existing Variant-B refresh-icon behavior retained: neutral idle, Lenovo red on hover/running refresh.
- **Lower area grouped as configuration:** above `Mit Windows starten` and `Standardziel` is heading `KONFIGURATION`. Restart remains separate below without redundant second heading.
- **Alias inline editing redesigned:** pencil click no longer replaces title with narrow textbox. Row temporarily expands to 92 px, shows original name above and wide dark alias field below.
- **Clear editing mode:** while editing alias, `AN/AUS`, pencil, and drag handle hide; `✓ Übernehmen` and `× Abbrechen` plus hint `leer = Originalname` appear.
- **Focus accent:** alias field has subtle neutral 1-px border; focus changes it Lenovo red. `Enter` accepts into draft, `Esc` discards; only global `Speichern` persists alias/order/visibility.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. GUID binding, alias persistence, BootNext, system-wide default, cleanup, context menus, custom restart dialog, and popup-first background refresh unchanged.

**Native verification required:** verify header idle/refresh status, configuration grouping, alias editor (pencil, focus, accept/cancel, Enter/Esc, global save), and existing boot/default/refresh regressions.

## v0.2.28 – Flat rectangular main UI and regrouped context menu

v0.2.28 moves visible tray UI to requested flat rectangular utility style. BootNext, TaskBroker, Default, cleanup, alias, and background-refresh architecture from v0.2.27 remain unchanged.

Changes:

- **Main popup without outer frame:** Lenovo-red outer ring removed. Popup is simple rectangular 390×672 box without rounded window region.
- **No rounded corners:** main popup and custom restart dialog use no rounded region. Red remains interaction/status accent instead of window frame.
- **Boot rows full width:** rows start at left edge and span full list width. Current BootNext selection's red vertical bar sits at outer left wall; hover/selection color entire row.
- **Reload action Variant B:** upper-right refresh icon neutral/light idle; Lenovo red on hover and during background refresh. Existing non-blocking refresh architecture from v0.2.26/v0.2.27 unchanged.
- **Tray context menu square/borderless:** no red/neutral outer border or rounding. Group separators are 1-px Lenovo-red horizontal lines.
- **Submenus deliberately separated:** `Standard-Startziel` and `Wartung` use slightly lighter dark-gray panel (`#202020`), subtle neutral 1-px edge, and red top accent line, separating submenu layer without red box.
- **Menu hover stays full width:** central renderer from v0.2.27 retained; hover/pressed calculated against real DropDown client width. Root reaches full client edge; submenu reaches just inside neutral edge.
- **Native popup edge remains suppressed:** `DropShadowEnabled=false`, relevant Win32 edge styles removed, DWM border suppression retained.
- **Restart dialog adapted:** dark custom dialog remains, now rectangular with no red outer ring; confirm action stays Lenovo red, safety semantics unchanged.
- **No functional change:** TaskBroker schema **0.2.12**, Settings schema **4**. Boot-target aliases, tooltips, background refresh, default target, cleanup, Autostart, and `shutdown.exe /r /t 0` unchanged.

**Native verification required:** verify rectangular main UI, missing outer frame, full-width boot rows, reload hover/active state, red menu separators, and submenu visual separation.

## v0.2.27 – Complete menu highlighting, native outer edge removed, and boot-target aliases

v0.2.27 centrally fixes both context-menu problems confirmed in native v0.2.26 smoke and adds requested alias feature in `Einträge verwalten` mode. BootNext, TaskBroker, Default, cleanup, Autostart, Restart, and background-refresh architecture remain unchanged.

Changes:

- **Hover/Selected over full menu width:** shared `LenovoMenuRenderer` no longer paints selection only inside WinForms-calculated item width. Item clip region is controlled for background and area calculated against actual `ToolStripDropDown.ClientSize.Width`. Fix applies to main menu, `Standard-Startziel`, `Wartung`, and future submenus.
- `LenovoMenuLayout` additionally uses actual client width instead of `DisplayRectangle.Width`; v0.2.26 alone did not capture target system's right remainder.
- **2-px Lenovo frame retained:** rendered as filled red outer ring plus dark inner surface, eliminating dark pixel strip outside red contour at client edge.
- **Native black outer edge:** besides `DropShadowEnabled = false`, `LenovoMenuChrome` removes relevant native border/edge window styles, disables DWM non-client rendering for DropDown, and sets Windows 11 `DWMWA_BORDER_COLOR` to `DWMWA_COLOR_NONE`. Red frame remains entirely client-rendered.
- **Boot-target aliases:** each entry in `Einträge verwalten` gets small pencil action opening inline input field. `Enter` accepts alias into edit draft; `Esc` discards current input; empty alias means original name.
- Aliases persist only together with `Speichern`. `Abbrechen` discards alias changes too.
- Set alias becomes visible primary name in normal boot selection; Manage view shows original name in subtext when alias set.
- Aliases are local UI metadata keyed stably by firmware GUID. They change **no** firmware GUID, BootNext value, task name, TaskBroker allowlist, or privileged identity.
- Alias display is also used for user-facing target names in default-target menus, status display, and restart dialog; technical identity always remains GUID.
- `settings.json` expands backward-compatibly to **schema 4** with `entryAliases` in addition to `defaultGuid`, `entryOrder`, `hiddenEntryGuids`. Schema 3 or older still loads; missing aliases mean empty alias set.
- TaskBroker schema remains **0.2.12**. Installer, uninstaller, launcher, and privileged Scheduled Task contracts unchanged.

**Native verification required:** Linux build environment cannot run WinForms/DWM. On target PC verify full-width hover/selected in all menus, complete absence of black outer edge, pencil/inline alias editing, and persistence after app restart.

## v0.2.26 – Context-menu finishing, custom restart dialog, and immediately visible boot selection

v0.2.26 follows native UI smoke after v0.2.25. Privileged boot/TaskBroker/Default architecture remains unchanged; only presentation, tooltip reliability, and interactive refresh path change.

Changes:

- Lenovo-red frame around tray context menu/submenus is again **2 px**. Native `ToolStripDropDown` shadow disabled in v0.2.25 stays disabled to avoid black shadow outside red frame.
- Menu items are explicitly stretched to usable DropDown width on opening; hover/selected backgrounds should again reach full usable width even when `MinimumSize` exceeds automatic text width.
- Hover background is more present (`#401F1D` instead of prior subtle tone) but remains dark/Lenovo-consistent.
- `Windows neu starten` no longer uses native Windows Yes/No dialog. Custom confirmation dialog uses dark Lenovo surface, 2-px red outer frame, consistent typography, and `Abbrechen` / `Neu starten`. Safety unchanged: concrete next target shown, explicit confirmation required, restart remains `shutdown.exe /r /t 0` with no extra UAC.
- Boot-target marker tooltips add explicit `MouseHover` fallback beside normal `ToolTip.SetToolTip(...)` so explanatory text appears on colored circle even when native tooltip on transparent label does not.
- **Startup latency:** `Show-OrTogglePopup` no longer performs fresh task/firmware query before `Popup.Show()`. Existing cache files read immediately; UI shown first. Exact TaskBroker check, manager/firmware refresh, and optional Storage discovery run afterward in hidden unelevated Windows PowerShell background process; main UI only polls completion and applies result.
- Explicit refresh via header/context menu also uses non-blocking background path. Firmware is refreshed only as needed/full Storage refresh; manager state read fresh.
- Background worker measures TaskBroker check, manager refresh, firmware refresh, Storage discovery, and total durations, enabling native follow-up to isolate slow phase without blocking UI before display.
- TaskBroker schema remains **0.2.12**, Settings schema **3**. Installer, uninstaller, launcher, and privileged Scheduled Task contracts unchanged.

**Native verification required:** target PC must confirm 2-px frame, full hover width, custom restart dialog, marker tooltips, and subjective/measured improvement to visible boot selection. Linux environment cannot execute Windows PowerShell 5.1, WinForms/DWM, or Task Scheduler.

## v0.2.25 – Slim context-menu frame without black outer edge

v0.2.25 changes only external appearance of tray context menu. BootNext, TaskBroker, Default, Autostart, cleanup, Restart, and tooltip architecture from v0.2.24 remain unchanged.

Changes:

- Lenovo-red outer frame of context menu/submenus reduced from **2 px to 1 px**.
- Frame is painted directly at client edge so no extra dark client border remains outside red line.
- Native WinForms `ToolStripDropDown` shadow disabled (`DropShadowEnabled = false`) so no extra black shadow contour should appear outside red frame.
- Rounded corners, checked states, submenu arrows, menu structure, maintenance submenu, and marker-tooltip explanations remain unchanged.
- TaskBroker schema **0.2.12**, Settings schema **3**; no repair/re-setup of privileged tasks required for this UI-only update.
- Visual effect still requires native Windows verification because Linux build environment cannot run WinForms/DWM DropDown chrome.

## v0.2.24 – Explain colored boot-target markers via tooltip

v0.2.24 adds only UI explanation for colored circles in boot list. BootNext, TaskBroker, Default, Autostart, cleanup, Restart, and context-menu architecture from v0.2.23 remain unchanged.

Changes:

- Hovering **colored circle** of boot target shows tooltip explaining category/color meaning.
- Red = Lenovo Boot Menu / firmware boot selection.
- Yellow = USB boot target.
- Blue = internal NVMe/PCIe boot drive.
- Violet = PXE network boot.
- Cyan = Lenovo/enterprise network/recovery boot target.
- Gray = other/non-specifically classified firmware target.
- Tooltip is intentionally bound only to colored circle; selection remains separately recognizable via left red bar, row background, and checkmark.
- TaskBroker schema **0.2.12**, Settings schema **3**; no repair/re-setup of privileged tasks required.

## v0.2.23 – Context menu focused and visually aligned with main UI

v0.2.23 is a pure UI/UX pass on tray context menu. BootNext, TaskBroker, Default, Autostart, and cleanup architecture from v0.2.22 remain unchanged.

Changes:

- `Einträge verwalten…` removed from tray context menu. Function remains via `VERWALTEN` in main UI.
- Technical actions `Privilegierte Aufgaben einrichten/reparieren…` and `Privilegierte Aufgaben entfernen…` grouped under `Wartung ›` submenu.
- Status hints for missing/repair-needed privileged tasks now point correctly to `Rechtsklick → Wartung → …`.
- `Bootauswahl öffnen` is subtly bold as primary tray action.
- Context menu has continuous 2-px Lenovo Red `#E1251B` frame matching main UI red outer ring, still rounded.
- Checked states use red checkbox with white check instead of inconsistent native Windows look.
- Submenu arrows gain contrast and vertical padding is slightly increased.
- TaskBroker schema **0.2.12**, Settings schema **3**; no repair/re-setup required solely because of v0.2.23.

## v0.2.22 – System-wide default restore, legacy migration, and complete task cleanup

v0.2.22 resolves competing default mechanisms. User-specific login/session restore in tray app is removed. Installation instead has exactly one system-wide SYSTEM startup restore that sets configured default boot target 30 seconds after Windows system start. Unelevated tray changes this default only through fixed pre-authorized Scheduled Tasks.

Changes and security boundaries:

- new TaskBroker schema **0.2.12**; v0.2.21 and older intentionally detected as needing repair/migration;
- new fixed SYSTEM task `LenovoBootMenu-Default-Restore` with `AtStartup` + **30-second delay**;
- one additional fixed task `LenovoBootMenu-Default-Set-<GUID>` per allowlisted firmware target;
- `LenovoBootMenu-Default-Clear` disables automatic default;
- startup restore reads system-wide default from `C:\ProgramData\Lenovo Boot Menu\TaskBroker\Default\default-guid.txt` but accepts only known firmware GUIDs embedded at setup time;
- Default state directory hardened to **SYSTEM/Administrators = Full Control**, **Users = Read/Execute**; unelevated app never writes file directly;
- existing `LenovoBootMenu-Set-<GUID>` tasks remain only for immediate manual BootNext selection;
- app no longer performs login/session restore and removes old HKCU volatile marker;
- migration priority: existing system-wide default → prior `settings.json` default → historical `Lenovo Boot Menu Next` / Boot Menu → no default;
- historical `Lenovo Boot Menu Next` is removed only after new task set is registered and ACL-validated; new startup restore disabled during migration, enabled afterward;
- **manual BootNext after startup restore wins** for next boot. Manual selection within first 30 seconds after system start can still be overwritten by delayed restore;
- `settings.json` is schema **3**: UI order/hidden entries remain user-specific; `defaultGuid` exists temporarily only as legacy migration source and is cleared after migration;
- new cleanup action `Privilegierte Aufgaben entfernen…` (from v0.2.23 under `Wartung`) starts targeted removal after confirmation/UAC of all known project Scheduled Tasks, old service-broker prototype, and system-wide TaskBroker/default state;
- cleanup deletes only exact known task names and explicit prefixes `LenovoBootMenu-Set-` / `LenovoBootMenu-Default-Set-`; there is **no broad Lenovo wildcard delete path**;
- UEFI boot entries and permanent firmware `displayorder` are changed by neither migration nor cleanup;
- HKCU app Autostart intentionally remains during task cleanup.

**Important when upgrading from v0.2.21:** run `Wartung → Privilegierte Aufgaben reparieren…` once and confirm UAC. This installs new Default Restore and Default Set/Clear tasks and controlled migration of historical `Lenovo Boot Menu Next`.

## v0.2.21 – Manage entries

v0.2.21 adds requested local management of visible boot targets. Firmware order (`displayorder`) is explicitly **not** changed; only UI ordering and visibility are stored.

Changes:

- new `VERWALTEN` entry above boot list plus `Einträge verwalten…` in tray context menu;
- edit mode shows **all detected firmware entries**, including previously hidden;
- order can be changed by **Drag & Drop**;
- clicking an entry toggles **AN** / **AUS**; hidden entries dim immediately;
- click in edit mode sets **no BootNext**;
- `Speichern` persists order/visibility and returns to normal read-only view;
- `Abbrechen` discards unsaved changes;
- normal view then shows only **active entries in saved order**;
- `settings.json` expands backward-compatibly to schema 2: `defaultGuid`, `entryOrder`, `hiddenEntryGuids`;
- new/previously unknown firmware entries append after saved order and default visible;
- main UI and continuous rounded Lenovo frame remain at v0.2.20 state; improved rounded context menu remains;
- privileged TaskBroker tasks, BootNext mechanism, Autostart, default target, and restart logic unchanged;
- **no repair/re-setup of privileged Windows tasks required**.

## v0.2.20 – Main UI reverted to v0.2.18, context menu retained, frame closed cleanly

v0.2.20 intentionally returns main surface to v0.2.18. Newer rounded context-menu design remains. Outer frame is rebuilt so Lenovo red is continuous on all four sides and especially corners.

Changes:

- main UI (boot list, rows, default-target row, restart button, footer, scroll area) matches v0.2.18 layout;
- improved dark context menu from newer UI retained with rounded corners;
- old frame composed of four straight edge panels removed;
- complete v0.2.18 surface now sits in inner rounded surface within a **continuous 2-px Lenovo-red outer ring**;
- outer/inner surfaces clipped with coordinated radii so red curves stay closed on all four corners;
- boot logic, TaskBroker, Autostart, persistent default target, and restart function unchanged;
- **no repair/re-setup of privileged Windows tasks required**.

## v0.2.18 – Visual-polish build startup failure fixed

v0.2.18 fixes PowerShell argument-binding error from v0.2.17. Three UI labels passed static `[Drawing.Color]::FromArgb(...)` call directly as `-ForeColor` argument. Windows PowerShell treated expression as text instead of evaluating it, so it could not convert to `System.Drawing.Color` and popup construction failed.

Changes:

- all three affected `-ForeColor` arguments are explicitly evaluated as `([Drawing.Color]::FromArgb(...))`;
- displayed version raised to **v0.2.18**;
- visual polish, scrollbar, context menu, boot logic, TaskBroker, Autostart, default target, and restart behavior remain unchanged from v0.2.17;
- **no repair/re-setup of privileged Windows tasks required**.

## v0.2.17 – Complete visual-polish pass

v0.2.17 changes only presentation and interaction hierarchy of tray UI; boot logic, TaskBroker, Autostart, default target, and restart behavior unchanged.

Changes:

- popup widened to **390 px** for more space for device names/detail text;
- calmer header with more internal spacing, compact subtitle, subtle separator;
- active boot row now uses subtle dark-red fill, 3-px Lenovo-red accent left, and red checkmark;
- consistent horizontal text axes and larger padding in all boot rows;
- SanDisk detail text shortened to `USB HDD · wahrscheinlicher Bootkandidat` without detection-logic change;
- scrollbar reduced to narrow **8-px dark track** with slim Lenovo-red thumb;
- native blue Windows checkbox replaced with custom black/Lenovo-red checkbox;
- default target presented as compact navigation row with `›`;
- restart action no longer permanently red-framed; becomes Lenovo red only on hover/interaction;
- footer made calmer and version right-aligned cleanly;
- previously dominant red outer frame retained by design only as subtle **1-px dark-red line**;
- popup gets slightly rounded corners;
- context menu: no bright red outer frame, instead dark-gray contour, dark hover with Lenovo-red accent, more padding, cleaner grouping;
- separator after `Aktualisieren` separates navigation actions from settings.

**No repair/re-setup of privileged Windows tasks required.**

## v0.2.16 – Scroll crash fixed

v0.2.16 fixes reproducible mouse-wheel/scrollbar crash from v0.2.15. `ValueChanged` handler of new Lenovo scrollbar used local variable `$host`. PowerShell variable names are case-insensitive, so it collided with built-in read-only automatic variable `$Host` and WinForms showed unhandled .NET exception.

Changes:

- local scroll-container variable renamed `$scrollContainer`;
- `ValueChanged` callback additionally guarded so UI scroll event cannot produce WinForms JIT dialog;
- Lenovo frame, red custom scrollbar, context-menu theme, boot logic, TaskBroker, Autostart, default target, and restart logic remain unchanged from v0.2.15;
- **no repair/re-setup of privileged tasks required**.

## v0.2.15 – Lenovo frame, version display, and fully themed navigation

v0.2.15 completes black/Lenovo-red tray look:

- complete popup UI now has **2-px Lenovo-red outer frame**;
- running **version number is visible bottom-right in footer**;
- native bright Windows scrollbar replaced by custom dark scroll track with Lenovo-red thumb;
- horizontal standard scrollbar removed because boot rows fit available width;
- mouse-wheel scrolling and dragging/clicking red scroll thumb remain possible;
- tray context menu and `Standard-Startziel` menu use same dark background, Lenovo red for frame/selection/checked states, and light text;
- boot, TaskBroker, Autostart, default-target, and restart logic remain unchanged from v0.2.14; no privileged-task re-setup required.

## v0.2.14 – More readable subtexts

Two-line boot-target detail text is no longer clipped inside too-short single-line area. Entry rows are slightly taller, subtexts get enough height for two lines and slightly larger font. Secondary text changed from dark to lighter gray so short/long descriptions are much easier to read on dark background.

Boot logic, privileged Windows tasks, Autostart, default-target, and restart functions remain unchanged from v0.2.13. No privileged-task re-setup required.

## v0.2.13 – Restart dialog names concrete boot target

Confirmation dialog for `Windows neu starten` now shows currently set next boot target using end-user-friendly name, e.g. `SanDisk Extreme Pro USB4` or `Lenovo Boot-Menü`. If no one-shot `bootsequence` target is set, `Firmware-Standardreihenfolge` is shown. Restart logic itself is unchanged.

## v0.2.12 – Hidden Autostart, persistent default target, and restart

v0.2.12 extends normal unelevated tray operation with three functions:

- **Autostart without visible PowerShell window:** HKCU Autostart no longer starts `powershell.exe` directly; it uses existing `wscript.exe` / VBS launcher. Existing active Autostart from older versions migrates automatically to hidden launcher of currently running version.
- **Persistent default boot target:** popup contains `Standard: …` and tray context menu `Standard-Startziel`. Selection stored under `%LOCALAPPDATA%\Lenovo Boot Menu Tray\settings.json`. At first app start in a Windows logon session—including Autostart—target is restored once as `bootsequence`. Session marker is in `HKCU\Volatile Environment` and disappears at next Windows logon.
- **Restart Windows:** action available in popup and tray context menu. Confirmation required; Windows then restarts through `shutdown.exe /r /t 0` without extra UAC. Current `bootsequence` target is used.

Privileged TaskBroker tasks from v0.2.11 remain unchanged/compatible; v0.2.12 requires **no repair/re-setup**.

### Using the default boot target

1. Open popup.
2. Click `Standard: …` and choose a firmware/boot target—or use tray context menu `Standard-Startziel`.
3. Selection is persisted.
4. At first tool start of next Windows logon session, target is automatically set as one-time next boot. Further app restarts in same session do not overwrite a later manual choice.

**Note on historical `Lenovo Boot Menu Next` task:** separately configured old task remains untouched and can set Lenovo Boot Menu again about 30 seconds after Windows start. If another persistent default is desired, this historical task can later overwrite it.

## v0.2.11 – Handle Task Scheduler status 0x00041301 correctly

v0.2.11 fixes runtime error when selecting boot target. Windows Task Scheduler uses `0x00041301` (`267009`, `SCHED_S_TASK_RUNNING`) as **success/status code for “task currently running”**. v0.2.10 could falsely display transient state as error due to race between `LastTaskResult` and COM task state.

Changes:

- `0x00041301` (`SCHED_S_TASK_RUNNING`) and `0x00041325` (`SCHED_S_TASK_QUEUED`) are transient, not errors;
- concrete COM task is reopened on every poll so stale `State` not used;
- success accepted only when current run ended and `LastTaskResult = 0`;
- existing v0.2.10 TaskBroker/ACL install remains compatible; no repair required.

## v0.2.10 – Task ACL verification fixed

v0.2.10 fixes concrete repair defect from v0.2.9. Windows Task Scheduler typically normalizes written `(A;;GRGX;;;SID)` ACE to object-specific access-mask `0x1200A9` when persisted. v0.2.9 checked only original GENERIC_READ/GENERIC_EXECUTE bits and falsely reported ACL was not set.

Changes:

- DACL verification accepts both `GR+GX` and persisted Task Scheduler mask `0x1200A9`;
- task reopened after `SetSecurityDescriptor()` before ACL verification;
- real verification failure logs read-back SDDL;
- existing v0.2.6–v0.2.9 tasks reused and only repaired;
- security boundary unchanged: user gets Read+Execute only, not Modify/Delete;
- no `displayorder` change; boot mutations still only through fixed SYSTEM tasks.

## v0.2.9 – Repair state detected correctly

v0.2.9 cleanly distinguishes **not installed** from **present but not operational**. If `task-broker.json` exists but unelevated readiness fails due bad task DACL, tray shows `Privilegierte Aufgaben reparieren…` instead of `… einrichten…`.

Changes:

- context menu offers `Privilegierte Aufgaben reparieren…` when TaskBroker install exists but broken;
- popup shows `Reparatur erforderlich` instead of `Einrichtung erforderlich`;
- repair dialog explains existing installation is incomplete/inaccessible;
- installer v0.2.9 retains v0.2.8 DACL repair/verification and writes metadata version 0.2.9;
- older TaskBroker metadata 0.2.6–0.2.8 remain readable/repairable.

## v0.2.8 – Task ACL / readiness fix

v0.2.8 fixes error in unelevated verification of successfully installed SYSTEM tasks. On target system, tasks exposed through task DACL could be started and read using `Get-ScheduledTaskInfo` while `Get-ScheduledTask` failed during root-folder enumeration in unelevated process. v0.2.6 therefore falsely reported “not configured” although installer ended with `SUCCESS` / ExitCode 0.

Changes:

- no `Get-ScheduledTask` root enumeration in unelevated tray;
- exact read through Task Scheduler COM `GetTask()` plus `Get-ScheduledTaskInfo`;
- task execution waits through exact COM task state for completion;
- existing v0.2.6 TaskBroker installation accepted—**no repeated UAC setup** if already successful;
- ExitCode 0 + failed client verification no longer falsely labeled installer failure;
- installer v0.2.8 uses reused Task Scheduler COM connection for ACL work to reduce setup overhead.

## v0.2.8 – Bootstrap/tray hardening

v0.2.8 fixes startup and interaction problems observed in v0.2.5:

- **no permanently open CMD window:** CMD starter immediately delegates to hidden detached `wscript` launcher and exits;
- **tray remains operable:** one-time privileged-task setup no longer blocks UI startup;
- **Exit remains available** even when privileged tasks are missing or setup fails;
- left-click with missing setup opens normal popup with status hint instead of repeated error MessageBox;
- new context-menu action `Privilegierte Aufgaben einrichten…` or, after successful setup, `… reparieren…`;
- UAC installation runs asynchronously; tray UI remains responsive;
- installation failures still reference diagnostics ZIP.

## Privilege separation

The tray app runs as a normal user. Privileged firmware operations use fixed Windows Scheduled Tasks created once:

~~~text
Lenovo Boot Menu Tray
normal user
        |
        | Read + Execute on fixed tasks
        v
Windows Task Scheduler
task runs as SYSTEM
        |
        v
Microsoft bcdedit.exe
fixed boot target
~~~

There is **no Lenovo-owned EXE running as SYSTEM**.

A dedicated task with an embedded GUID is created for each allowed firmware target. The user receives only Read+Execute (`GRGX`) on these task objects. The tray app therefore cannot pass arbitrary admin commands or free GUID parameters to a privileged process.

## One-time setup

After first launch the tray is immediately usable. While privileged tasks are missing, popup shows exact historical UI text:

~~~text
Einrichtung erforderlich · Rechtsklick → Wartung
~~~

Then use tray context menu `Wartung → Privilegierte Aufgaben einrichten…` and confirm the one-time UAC prompt.

After successful setup, firmware state reloads automatically. Normal operation requires no further UAC prompts.

## Launcher

`Start-LenovoBootMenuTray.cmd` starts `Start-LenovoBootMenuTray.vbs`. From v0.2.12 Windows Autostart also uses this WScript/VBS path directly. Therefore neither manual start nor Windows logon leaves visible PowerShell/CMD window.

## Existing functions

- black popup with **Lenovo Red `#E1251B`** as highlight color;
- flat rectangular main popup with no outer red frame or rounding;
- slim 8-px dark-gray scroll track with Lenovo-red thumb;
- square borderless black/Lenovo-red context menu with red horizontal separators and subtly separated submenus;
- Lenovo red in tray icon;
- current `bootsequence` target marked;
- dynamic firmware entries without GUIDs in end-user UI;
- `USB HDD` associated from current Storage/partition data with a plausible physical USB boot candidate;
- SanDisk Extreme Pro USB4 prioritized over non-bootable Micron in examined setup;
- Storage context cached;
- `Einträge verwalten`: all entries visible, Drag & Drop, on/off by click, Save/Cancel, persistent local order/visibility;
- `Mit Windows starten` through HKCU Autostart via invisible WScript/VBS launcher without UAC;
- **system-wide default boot target** via authorized Default Set/Clear tasks;
- one SYSTEM Default Restore 30 seconds after each Windows system start;
- `Windows neu starten` available in popup and tray context menu.

## Historical task `Lenovo Boot Menu Next`

From v0.2.22 this task is no longer a parallel permanent mechanism. During one-time repair/migration its previous behavior is considered as fallback for initial system default. After successful validation of new Default tasks, `Lenovo Boot Menu Next` is removed and only `LenovoBootMenu-Default-Restore` is used.

## Still open at that historical point

- complete diagnostics ZIPs for **every** relevant runtime failure of the tray app;
- native Windows acceptance of v0.2.26 UI/performance changes: context-menu frame/hover, custom restart dialog, marker tooltips, actual time to visible boot selection, and background-refresh duration; plus legacy task/default/cleanup regression.

## Uninstall / cleanup of privileged tasks

Tray context menu under `Wartung` exposes `Privilegierte Aufgaben entfernen…`. After confirmation and UAC, the following are targeted for removal:

- `Lenovo Boot Menu Next`;
- `Lenovo Boot Menu Tray Autostart` historical Scheduled Task Autostart if present;
- `LenovoBootMenu-RefreshManager`;
- `LenovoBootMenu-RefreshFirmware`;
- all `LenovoBootMenu-Set-<GUID>`;
- all `LenovoBootMenu-Default-Set-<GUID>`;
- `LenovoBootMenu-Default-Clear`;
- `LenovoBootMenu-Default-Restore`;
- known probe/test tasks (`AclProbe`, `ElevationProbe`, `SystemReadProbe`, `SystemExecProbe`, `SystemBaseline`, `LenovoBootMenuBroker-SystemProbe`);
- historical `LenovoBootMenuBroker` service/Program-Files prototype if present;
- `C:\ProgramData\Lenovo Boot Menu\TaskBroker` including Default state and metadata.

Current HKCU Run Autostart setting of tray app is **not** removed. Firmware boot entries and `displayorder` remain untouched.

## Build

- Tray: Windows PowerShell 5.1 / WinForms
- privileged path: Windows Task Scheduler + Microsoft `bcdedit.exe`
- no custom SYSTEM EXE in package

## v0.2.8 – Task ACL correction

- Fixes concrete ACL-detection defect from v0.2.5–v0.2.7: user SID can already appear in Group field (`G:<SID>`) of task security descriptor. Old check searched only for SID text and falsely interpreted this as existing user ACE.
- v0.2.8 checks only DACL and requires a real `AccessAllowed` ACE with `GENERIC_READ + GENERIC_EXECUTE` for user SID.
- Permission is set structurally through `RawSecurityDescriptor` / `CommonAce` and verified by read-back.
- Installer reports SUCCESS only when every privileged task has real Read+Execute ACE; otherwise diagnostics ZIP is generated.
- Existing v0.2.7 tasks are reused during repair; ACL is repaired instead of deleting/recreating all tasks.
