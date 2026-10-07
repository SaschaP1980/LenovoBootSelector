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

TaskBroker schema 0.2.14 introduces the explicit boundary marker:

`boundaryContract = fixed-task-v2`

Runtime metadata is accepted only when all of the following are true:

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
