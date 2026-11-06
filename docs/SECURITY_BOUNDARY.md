# Lenovo Boot Selector – Security Boundary

This document defines the security boundary for privileged boot operations. It is a product architecture contract, not an implementation suggestion.

## Trust model

The normal Lenovo Boot Selector tray process is **unelevated**.

The only privileged firmware mutations are fixed Windows Scheduled Tasks that run as SYSTEM and are created by the explicit elevated setup/repair flow. The tray receives Read+Execute access to those exact task objects only.

The updater is a separate unelevated path and is not allowed to become a privileged boot-control channel.

## Allowed privileged operations

The unelevated runtime may request only these logical operations:

- `ManagerRefresh`
- `FirmwareRefresh`
- `BootNext`
- `DefaultSet`
- `DefaultClear`

No runtime API accepts a free Scheduled Task name.

`DefaultRestore` exists as the fixed startup task `LenovoBootSelector-Default-Restore`, but it is not exposed as an unelevated runtime operation. It is driven only by its fixed AtStartup trigger.

Since v0.10.0.0, the canonical privileged installation uses the `LenovoBootSelector-*` task family and `%ProgramData%\Lenovo Boot Selector\TaskBroker`. Exact pre-v0.10 `LenovoBootMenu-*` tasks and `%ProgramData%\Lenovo Boot Menu\TaskBroker` are recognized only by the elevated migration/cleanup path and are never accepted as runtime authorization. See [IDENTIFIER_COMPATIBILITY.md](IDENTIFIER_COMPATIBILITY.md).

## Fixed task naming

Static tasks have exact names:

- `LenovoBootSelector-RefreshManager`
- `LenovoBootSelector-RefreshFirmware`
- `LenovoBootSelector-Default-Clear`
- `LenovoBootSelector-Default-Restore`

Target-specific task names are deterministically derived from a strictly validated firmware GUID:

- BootNext: `LenovoBootSelector-Set-<32 hex characters>`
- DefaultSet: `LenovoBootSelector-Default-Set-<32 hex characters>`

The runtime never accepts a task name supplied by UI state, user input or arbitrary metadata.

## Metadata contract

TaskBroker schema 0.2.15 introduces the explicit boundary marker:

`boundaryContract = fixed-task-v2`

Runtime metadata is accepted only when all of the following are true:

- protected boot provenance path is fixed within the TaskBroker Default directory;

- schema version is explicitly supported;
- boundary marker is exact;
- current Windows user SID matches the installed SID;
- static task names are exact;
- manager, firmware and default-state paths resolve to the fixed TaskBroker ProgramData directory;
- every target GUID has the canonical braced GUID form;
- BootNext and DefaultSet task names exactly match the names derived from that GUID;
- GUIDs and derived task names are unique.

Any mismatch is fail-closed and makes the System Functions state require repair/reinitialization.

## ProgramData state integrity

The elevated installer protects `%ProgramData%\Lenovo Boot Selector\TaskBroker` with a non-inheriting ACL:

- SYSTEM: FullControl
- Administrators: FullControl
- Users: ReadAndExecute

The metadata file is explicitly protected with the same write boundary.

ACL verification must distinguish concrete mutation rights from composite convenience rights. In particular, `FileSystemRights::Modify` must **not** be used as a forbidden bit mask because it includes read/execute components and therefore overlaps the allowed `ReadAndExecute` set. The verifier checks concrete mutation-capable bits (write/create/append/delete/ACL/ownership changes) instead.

This prevents the normal unelevated user from rewriting task names, target GUIDs or trusted state paths after setup while still accepting the intended Users=ReadAndExecute ACL.

### v0.10 migration rule

An upgraded pre-v0.10 installation is treated as present-but-incompatible and therefore requires the explicit elevated Repair/Migrate path. The installer builds and verifies the complete canonical state, task definitions, SYSTEM principals, task ACLs, metadata, state ACLs and enabled Default Restore before deleting any exact legacy TaskBroker task or legacy ProgramData state. If canonical setup fails before that verification point, the old TaskBroker installation is left intact. Cleanup recognizes only exact static names or the two project-owned per-GUID name patterns with a 32-hex suffix; no generic Lenovo wildcard deletion is allowed.

## Scheduled Task DACL contract

The authorized user receives **Read+Execute only** on the fixed SYSTEM tasks.

Task ACL validation treats this as an exact least-privilege contract, not a minimum-permission check. In particular, GENERIC_ALL, GENERIC_WRITE, DELETE, WRITE_DAC and WRITE_OWNER are rejected.

If an existing user allow-ACE is broader than the contract, the elevated installer removes the user's allow-ACEs and writes one GR+GX ACE, then verifies the persisted Task Scheduler ACL.

## Boot mutation semantics

Boot selection remains **One-Shot Next Boot** only.

The fixed BootNext task runs Microsoft `bcdedit.exe` with the prebuilt action equivalent to:

`/set {fwbootmgr} bootsequence <fixed installed target GUID>`

The application must never permanently mutate UEFI `BootOrder` or `{fwbootmgr}` `displayorder`.

No arbitrary command text, arbitrary Scheduled Task name, raw Boot#### identifier, device path or free privileged GUID parameter may cross the unelevated-to-SYSTEM boundary.

## Verification

Security-sensitive changes to TaskBroker, BootService or the installer must be accompanied by Boundary/Core/Regression contracts.

The canonical gates must continue to verify at least:

- operation-only runtime invocation;
- fixed/derived task-name resolution;
- strict metadata contract;
- least-privilege task ACL behavior;
- protected ProgramData metadata/state;
- One-Shot `bootsequence` semantics;
- absence of permanent `displayorder` mutation;
- absence of a custom SYSTEM executable/broker;
- updater isolation from TaskBroker.

Native Windows testing remains required before claiming actual Task Scheduler ACL behavior as natively proven.

## LBS-143 — coordinated LBS writer priority

From schema 0.2.15, the fixed SYSTEM tasks for `BootNext`, `DefaultSet`, `DefaultClear`, and delayed `DefaultRestore` coordinate within a **single exclusive file lock** under the protected TaskBroker `Default` directory. The elevated installer pre-creates `bootnext-writer.lock` with only SYSTEM and Administrators FullControl. The writer uses `FileMode.Open` with `FileShare.None`, never `OpenOrCreate`, and a bounded 8-second contention wait; missing, malformed, unopenable, or incorrectly protected lock state fails closed. The lock handle is released when its process terminates. All writer task registrations explicitly use Task Scheduler `MultipleInstances = Queue`; reconfiguration requires elevated Repair, not runtime task mutation. The installed task specifications independently verify both exact encoded actions and Queue policy.

SYSTEM-owned boot provenance persists a protected, real-boot-cycle-bound increasing sequence through `pending-manual` and successful `manual` records. A manual BootNext caller requires a new verified manual sequence for the requested allowlisted GUID plus a fresh firmware readback before reporting success; it cannot trust an older Scheduled Task `LastTaskResult` alone. The later completed manual state takes priority over delayed LBS automatic Default Restore. Default synchronization is permitted only when both current LBS-auto origin and a fresh firmware GUID match the old default while the privileged lock is held. The authority boundary and task names remain unchanged. The writer lock is not an externally enforced transaction against unrelated privileged firmware tools.

This is **LBS-owned writer precedence**, not a claim of controlling independent privileged firmware writers. External writes are neither synchronized by this lock nor intrinsically attributable when they reuse the same target GUID. Observable external mismatch is preserved where the current state reveals it. Where provenance is unknown or stale, no silent automatic default-change synchronization is permitted. Failed/partial actions are not reported as atomic success. The existing runtime operation whitelist, deterministic task names, SYSTEM/no-admin-UI boundary and one-shot `bootsequence` limit remain mandatory.

Upgrading older 0.2.14 SYSTEM task installations to 0.2.15 requires the explicit elevated Repair system functions flow. No unelevated automatic task reconfiguration is allowed; old metadata fails compatibility checks.
