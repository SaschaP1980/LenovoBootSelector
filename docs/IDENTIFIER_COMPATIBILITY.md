# Identifier compatibility and naming policy

Lenovo Boot Selector is the canonical product name.

LBS-19 standardizes active application-owned naming where that is safe, while preserving technical identifiers that are part of update compatibility, persisted state, cross-version singleton behavior, cleanup, or the hardened TaskBroker boundary. Retained legacy-looking identifiers are compatibility IDs only; they are not alternate product names.

The term **Lenovo Boot Menu** remains valid when it describes the actual Lenovo/firmware boot menu as a boot target.

## A — Safe rename

These identifiers are application-internal or developer-facing and have no external compatibility contract:

| Identifier | Canonical target | Rationale |
| --- | --- | --- |
| `src/App/LenovoBootMenuTray.template.ps1` | `src/App/LenovoBootSelector.template.ps1` | Active source template; build/tool references migrate with it. |
| `LenovoBootMenuConsoleWindow` | `LenovoBootSelectorConsoleWindow` | Internal C# helper class. |
| `LenovoBootMenuPopup` | `LenovoBootSelectorPopup` | Internal WinForms control name. |
| `LenovoBootMenuTaskInstall-*` | `LenovoBootSelectorTaskInstall-*` | Ephemeral installer workspace prefix. |
| User-visible uninstall prefix `Lenovo Boot Menu:` | `Lenovo Boot Selector:` | Product-facing console text. |

Documentation and active build/test references follow the canonical source-template name.

## B — Migration required

### HKCU autostart Run value

Canonical value name:

`HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Lenovo Boot Selector`

Legacy value name:

`HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Lenovo Boot Menu Tray`

Migration rules:

1. Read the canonical value first.
2. If it is absent, recognize the legacy value as the application's registration.
3. When autostart is enabled or repaired, write the canonical value first.
4. Remove the legacy value only after the canonical write succeeds.
5. Disabling autostart removes both known value names.
6. Repeating migration is safe and idempotent.
7. No unrelated Run values are read, changed, or removed.

The launcher filename itself remains a category-C compatibility identifier.

## C — Stable compatibility identifiers

These identifiers are intentionally retained because changing them would add migration or security risk without proportional user benefit.

| Identifier / family | Reason retained |
| --- | --- |
| `LenovoBootMenuTray-v<version>.zip` | Pre-v0.9 updaters validate this exact release filename pattern. Retaining it allows direct update to current releases without an intermediate mandatory migration hop. |
| `LenovoBootMenuTray.ps1` | Flat package/runtime compatibility contract used by existing updaters and installed copies. |
| `LenovoBootMenuTray.ico` | Flat package compatibility filename referenced by the runtime. |
| `Start-LenovoBootMenuTray.cmd` / `.vbs` | Existing install/autostart/update launch contract. |
| `Install-LenovoBootMenuTasks.ps1` / `Uninstall-LenovoBootMenuTasks.*` | Existing package, maintenance, update, and repair contract. |
| `%LOCALAPPDATA%\Lenovo Boot Menu Tray\...` | Existing settings, diagnostics, update, and local TaskBroker state root. It is technical state, not product branding. |
| `%ProgramData%\Lenovo Boot Menu\TaskBroker` | Hardened TaskBroker state/ACL boundary. |
| `Local\LenovoBootMenuTray` | Cross-version singleton mutex. Keeping one mutex prevents old and new installed copies from running concurrently. |
| `LenovoBootMenu-RefreshManager` | Fixed allowlisted SYSTEM Scheduled Task. |
| `LenovoBootMenu-RefreshFirmware` | Fixed allowlisted SYSTEM Scheduled Task. |
| `LenovoBootMenu-Default-Clear` | Fixed allowlisted SYSTEM Scheduled Task. |
| `LenovoBootMenu-Default-Restore` | Fixed AtStartup SYSTEM Scheduled Task. |
| `LenovoBootMenu-Set-<GUID>` | Deterministically derived fixed BootNext task family. |
| `LenovoBootMenu-Default-Set-<GUID>` | Deterministically derived fixed default-target task family. |
| `Lenovo Boot Menu Next` | Cleanup-only legacy task identifier. |
| `Lenovo Boot Menu Tray Autostart` | Cleanup-only legacy Scheduled Task identifier. |
| `LenovoBootMenuBroker` | Cleanup-only legacy service identifier. |
| `LenovoBootMenu-*Probe*` / `LenovoBootMenu-SystemBaseline` | Cleanup-only historical probe task names. |
| `LenovoBootMenuTrayDefaultRestoreProcessed` | Cleanup-only legacy session marker. |

The stable TaskBroker names remain exact. No free task-name input crosses the unelevated/SYSTEM privilege boundary.

### Update compatibility boundary

The v0.8.0.4 updater requires the legacy-compatible release ZIP pattern and the existing flat package filenames. Therefore v0.9.0.0 deliberately keeps those names. The product name visible to users remains **Lenovo Boot Selector**.

Future naming cleanup must not change these category-C identifiers unless a separate migration design proves that installations which skip intermediate releases can still update safely.

## D — Historical record

Do not rewrite or rename:

- previously published `downloads/LenovoBootMenuTray-v*.zip` files;
- existing historical rows in `downloads/releases.json` and `downloads/README.md`;
- historical source tags;
- historical changelog entries except for explicit clarification;
- versioned architecture/catch-audit snapshots;
- closed historical Issues and pull requests solely for naming consistency.

Historical release ZIPs remain byte-immutable.

## Active naming guardrails

- User-visible product naming is **Lenovo Boot Selector**.
- The firmware concept **Lenovo Boot Menu** is valid terminology and is not an application-name regression.
- New application-owned identifiers should use `LenovoBootSelector` unless a category-C compatibility contract requires the retained legacy identifier.
- Retained category-C names must stay documented here and covered by permanent tests.
- Cleanup and migration code must touch only exact known project-owned resources.
