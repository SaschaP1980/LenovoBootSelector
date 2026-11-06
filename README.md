# Lenovo Boot Selector

<p align="center">
  <img src="bin/icon-preview.png" alt="Lenovo Boot Selector" width="96">
</p>

**Lenovo Boot Selector** is a Windows tray application for choosing a supported Lenovo firmware boot target before restarting Windows. It offers two complementary modes:

- **Next boot:** set one validated, existing firmware target for the next boot only.
- **Persistent default:** configure a preferred target that a fixed SYSTEM Scheduled Task prepares again whenever a participating Windows installation starts, without requiring a user logon.

It changes the firmware's **one-time `bootsequence`**, not the permanent UEFI `BootOrder`. Boot targets must be supported by the installed TaskBroker configuration; the application cannot address arbitrary devices or independently select individual physical drives behind a generic firmware entry.

**Current development version:** v1.2.0.0  
**Technology:** Windows PowerShell 5.1 · WinForms · Windows Task Scheduler · `bcdedit.exe`  
**Releases:** [Downloads and version history](downloads/README.md) · [Latest published version metadata](downloads/latest.json) · [Changelog](CHANGELOG.md)

## Why it exists

The project was created to solve a specific problem: on the Lenovo laptop used for development, **F12** and sometimes **Enter** are not always detected reliably during early boot, whether pressed on the internal keyboard or on a keyboard connected through a USB dongle.

If the key press is missed during that short firmware window, the normal first boot target starts immediately, typically Windows on the internal NVMe SSD. Trying to start a different Windows installation on an external USB drive could require shutting down and repeating the process; in the original environment, as many as **ten restart attempts** were sometimes necessary.

Lenovo Boot Selector removes the dependency on that pre-boot keyboard timing. A user can prepare the intended firmware target **from within Windows**, then restart. When all participating Windows installations are configured with the same persistent default, an existing Lenovo Boot Menu entry can serve as a recurring hand-off point after those installations start.

Similar timing problems can occur with USB and wireless keyboards, docks, or firmware that initializes input devices late. The application provides a controlled alternative; it is **not a bootloader, BIOS/UEFI replacement, or tool for changing the permanent boot order**.

## Features

- **One-shot boot selection:** prepare a validated firmware target for the next boot through the tray application.
- **Persistent boot default:** reapply a configured target at Windows startup through a hardened, predefined SYSTEM task, without a user session.
- **Boot-target management:** drag to reorder entries, show or hide them, assign custom aliases, and save or discard changes. Clearing an alias restores the original name.
- **Tray and popup UI:** open boot selection from the notification area, display the popup near the tray icon where Windows exposes a suitable anchor, and restart Windows from the application.
- **High-DPI presentation:** DPI-aware WinForms controls, menus, dialogs, and boot-entry scrolling. The external 100% / internal 250% two-monitor configuration has been visually accepted on the development machine; this does not imply certification of every monitor layout or scaling value.
- **Single-instance behavior:** an interactive second start activates the existing application/popup rather than launching a duplicate tray instance.
- **Read-only discovery:** refresh firmware entries, detect boot-target drift, and show available NVMe/USB storage context without claiming unsupported physical-device-to-firmware mappings.
- **Diagnostics:** save a local diagnostic ZIP or explicitly upload a diagnostic ZIP to the private diagnostics service and copy the returned Diagnosis ID.
- **Localization:** English (`en-US`) UI by default, with selectable, persisted German (`de-DE`).
- **Updates:** check for a newer version when opening the popup; installation remains a separate, explicit action with integrity verification and rollback handling.
- **Convenience:** optional hidden autostart, maintenance/setup/repair actions, and localized status messages.

## Requirements and installation

- A Lenovo Windows system with supported firmware boot entries exposed through Windows.
- **Windows PowerShell 5.1**, .NET/Windows Forms, and Windows Task Scheduler.
- A **writable user directory** for the extracted application and its unelevated self-updater.
- Administrator rights **only when explicitly setting up, repairing, reinitializing, or removing** the privileged Scheduled Tasks.

The application is developed and tested on a Lenovo Windows system. Automated Windows PowerShell 5.1 checks cover additional UI and boundary contracts; they do not establish compatibility with every Lenovo firmware model or Windows hardware configuration.

### Quick start

1. Download the current `LenovoBootMenuTray-v<version>.zip` from [downloads/](downloads/) (see the [release index](downloads/README.md)) and **extract the complete ZIP** into a writable user directory.
2. Run `Start-LenovoBootMenuTray.cmd`. The included VBS launcher starts the tray application without leaving a visible PowerShell console.
3. On first use, complete the offered **system-functions setup** through the maintenance menu and approve the UAC prompt. This installs the fixed, validated privileged tasks.
4. Open the tray popup and choose a supported boot target for the next boot. Restart Windows when you want to use that target.
5. Optionally configure the persistent default and **Start with Windows**. Set up the same default in each participating Windows installation if you want it restored after starting any of them.
6. Use **Language / Sprache** in the tray menu to change between English and German.

An interactive second launch reopens or activates the already-running instance. The application's ordinary tray-icon interaction remains unchanged.

## Boot selection and firmware limitations

### One-shot selection versus persistent default

For one-shot selection, the fixed, allowlisted BootNext operation invokes Windows `bcdedit.exe` with the equivalent of:

```text
/set {fwbootmgr} bootsequence <validated installed target GUID>
```

This **temporarily modifies the firmware's next-boot selection**. It does **not** permanently rewrite `{fwbootmgr} displayorder` or UEFI `BootOrder`. The UI itself is not elevated; only the predefined Scheduled Task performs the privileged operation.

The persistent default is different from permanently editing firmware boot order. A dedicated SYSTEM startup task restores the configured one-shot target **when Windows starts**. It does not independently run while the computer is powered off or while a non-Windows operating system is running. Missing, changed, or incompatible TaskBroker/firmware state may require explicit repair or reinitialization before privileged actions are available.

See [Security Boundary](docs/SECURITY_BOUNDARY.md) for the exact authorized operations and restrictions.

### Storage information is context, not boot-target addressability

Firmware entries and physically connected storage devices are different kinds of information. Lenovo Boot Selector displays read-only storage context but does not invent a one-to-one mapping that firmware does not provide.

- **Internal NVMe:** when exactly one internal NVMe drive is detected, the first internal entry can show its model (for example, `NVMe-SSD 1 / Interne SSD: KXG8AZNV2T04 LA KIOXIA`). A second entry may show `Kein Laufwerk erkannt`. With multiple internal NVMe drives, LBS deliberately does not guess which physical drive corresponds to firmware NVMe0/NVMe1.
- **USB:** the firmware target remains the generic `USB HDD`. With exactly one detected USB boot candidate, its model may be shown as contextual text, for example `USB-Startmedium: SanDisk Extreme Pro USB4` (`USB boot medium: SanDisk Extreme Pro USB4` in English). This does **not** mean that LBS can individually address that physical USB drive through the generic firmware target.

The drive names above are **examples from the development system**, not bundled devices or assumptions about another user's computer.

## Localization

All product-controlled user-facing UI text uses a central PowerShell-5.1-compatible localization layer. **English (`en-US`) UI by default** applies to new installations and fallback behavior. **German (`de-DE`)** is available under **Language / Sprache**, and the setting persists.

Existing pre-localization settings are migrated to German to avoid unexpectedly changing the language of an established German installation. Invalid or unknown stored locales fall back to English. Changing the selected language updates the tray menu and rebuilds the visible popup.

Firmware descriptions, device models, GUIDs, paths, diagnostic event codes, and other externally supplied technical identifiers are not translated. The full contract is documented in [docs/LOCALIZATION.md](docs/LOCALIZATION.md).

## Updates

Each transition from a hidden popup to a visible popup starts **one read-only version check** unless an update operation is already busy. Launching only the tray process does not trigger this check; closing and reopening the popup may trigger another. There is **no periodic polling**.

The updater reads the fixed repository's [latest.json](downloads/latest.json) and validates the manifest, version, package filename, tag, size, SHA-256, and expected package contents. An automatic check **never downloads or installs** an update. If a new version is available, the localized popup header indicates this; the indicator can open the update dialog by click or keyboard activation when the UI is not busy.

An explicitly requested update rechecks downloaded package size and SHA-256, installs **unelevated**, retains a local backup, and restarts through the VBS launcher. Success is reported only when the restarted process actually runs the expected version. Failed installations attempt rollback, with a localized result reported after restart. The updater does not edit firmware settings or Scheduled Tasks.

See [Changelog](CHANGELOG.md) for version-specific updater fixes and compatibility handling.

## Diagnostics and privacy

The maintenance menu supports two separate actions:

- **Save Diagnostics:** export a local ZIP for troubleshooting; it stays on the computer unless you choose to share it.
- **Upload Diagnostics:** deliberately send a diagnostic ZIP via HTTPS to the project's private Cloudflare diagnostics service. **There is no automatic upload on launch, refresh, error, or update.** A confirmed successful upload returns a copyable, server-generated **Diagnosis ID** in the form `LBS-XXXXX-XXXXX-XXXXX-XXXXX`. If the response cannot confirm a valid receipt, the application does not invent an ID.

The upload transport enforces a **2 MiB maximum ZIP size** and a **25-second timeout**. The server's documented retention policy is **up to 90 days**, with additional per-installation rotation and capacity limits that may delete older diagnostics sooner. A locally persisted random installation UUID supports correlation; it is not intended as a physical-device fingerprint. Diagnostic archives may contain technical details about the machine and should be treated as potentially sensitive.

Uploads are separate from firmware/TaskBroker privileges. The Windows client does not contain an administrative archive-read token. Further backend, deployment, and operational details are documented in [DevOps Operations](docs/DEVOPS_OPERATIONS.md).

## Security and maintenance

Normal application operation is **unelevated**. Firmware mutations are restricted to a hardened, fail-closed TaskBroker boundary:

- Only predefined operation types and exact task definitions are permitted; no arbitrary command strings, task names, raw `Boot####` identifiers, device paths, or freely supplied privileged GUIDs are accepted.
- Per-target task names are derived from validated installed firmware GUIDs. SYSTEM owns the privileged task actions; normal-user access is constrained to the validated Read+Execute task permissions.
- TaskBroker metadata and state in `%ProgramData%\Lenovo Boot Selector\TaskBroker` are protected against normal-user writes.
- Missing, incompatible, or drifted state disables privileged actions until the user explicitly performs the required setup, repair, or reinitialization.
- The updater runs separately and unelevated. No custom application executable runs as SYSTEM.

Since v0.10.0.0 the canonical privileged tasks are named `LenovoBootSelector-*`. Upgrades from v0.9.x or earlier require an explicit elevated repair/migration step; the existing installation is not removed until the new installation passes validation. Some older-looking package filenames and local-state identifiers remain intentionally for backward compatibility, **not** because the product has reverted to its old name.

Read the authoritative [Security Boundary](docs/SECURITY_BOUNDARY.md) and [Identifier Compatibility](docs/IDENTIFIER_COMPATIBILITY.md) documents for exact task naming, migration, ACL, and safety rules.

## Releases and development

Versioned, immutable historical release ZIPs are retained in [downloads/](downloads/). The current release pointer is [downloads/latest.json](downloads/latest.json); the release list is [downloads/README.md](downloads/README.md). Versions use **MAJOR.MINOR.PATCH.HOTFIX**; legacy three-component releases are compared with `HOTFIX = 0`.

Project components are organized as follows:

| Path | Purpose |
| --- | --- |
| `bin/` | Release/package assets and generated runtime; `bin/version.json` is the canonical version source |
| `src/Core/` | Pure domain logic / Functional Core |
| `src/Application/` | Application services and workflow coordination |
| `src/Infrastructure/` | Windows, storage, update, TaskBroker, and I/O adapters |
| `src/UI/` | WinForms presentation, display scaling, menus, and interaction |
| `tests/` / `tests-history/` | Active automated checks and archived version-specific tests |
| `docs/architecture/` | Canonical and historical architecture baselines |
| `audits/` | Current and historical catch-block classification audits |
| `tools/` | Reproducible runtime generation, packaging, validation, and transition utilities |
| `downloads/` | Versioned release ZIPs, download listing, and update manifests |

The central native Windows PowerShell 5.1 test wrapper is:

```powershell
.\tests\Test-WindowsPowerShell51.ps1
```

The project uses deterministic builds, permanent Release/Core/Boundary/Regression checks, native Windows PowerShell 5.1 tests, exact-SHA Candidate Preflight, reproducibility verification, and post-release validation. Hardware-specific behavior is additionally subject to explicit native owner acceptance. Its engineering rules favor Clean Code, SOLID, and limited, responsibility-aware DRY.

### Agentic software engineering and continuity

GitHub is the project's **single durable source of truth**: current code, Issues/comments, documentation, tests, workflows, and release evidence must be enough to continue work in a new session. Chats, local ZIPs, and model memory are not authoritative development records.

Small executable Patch/Hotfix changes normally use an atomic fast path. Major/Minor and specifically justified larger changes use an Issue-backed `work/LBS-<issue>` path with recoverable checkpoints and one cumulative rolling Issue comment. A Work tree must pass exact-SHA Development Completion before becoming a Candidate. A confirmed regression must be reproduced by a focused **RED** test on the unfixed baseline and proved **GREEN** after the fix, never by intentionally publishing a failing Candidate.

A Candidate is created as `candidate/v<version>` and must pass Linux and Windows gates before GitHub promotes it to `release/v<version>`. Official publication verifies the source tag, reproducible ZIP, integrity, PR squash merge, and post-release state. Separate Diagnostics Worker deployment or health verification has its own evidence and trust boundary. Repository and GitHub documentation use English.

The operational rules and their detailed contracts are maintained in:

- [Initial Prompt](docs/INITIAL_PROMPT.md) – mandatory session bootstrap
- [Development Guidelines](docs/DEVELOPMENT_GUIDELINES.md) – scope, development paths, checkpoints, and testing
- [GitHub How-To](docs/GITHUB_HOWTO.md) – repository workflows and Issue lifecycle
- [Release Process](docs/RELEASE_PROCESS.md) – Candidate, publication, and verification
- [DevOps Operations](docs/DEVOPS_OPERATIONS.md) – GitHub/Cloudflare hand-offs and health evidence
- [Build and Deployment Reporting](docs/BUILD_DEPLOYMENT_REPORTING.md) – reporting and provenance
- [Popup Anchoring](docs/POPUP_ANCHORING.md) – positioning behavior and desktop acceptance
- [Rolling Issue Comment Template](docs/templates/WORK_PATH_ROLLING_COMMENT.md) – Work-Path recovery contract
