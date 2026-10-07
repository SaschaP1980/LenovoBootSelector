# Lenovo Boot Selector

<p align="center">
  <img src="bin/icon-preview.png" alt="Lenovo Boot Selector" width="96">
</p>

## Overview

**Lenovo Boot Selector** is a Windows tray application for Lenovo systems with two complementary boot-selection modes: choose any existing firmware target as the **one-time target for the next boot**, or configure a **persistent default boot target** that is automatically prepared again for the following boot after every Windows system start.

The persistent default is restored by a fixed SYSTEM Scheduled Task and therefore does **not require a user to log on**. When every participating Windows installation is configured this way, a target such as the Lenovo Boot Menu can effectively become the recurring hand-off point for subsequent boots—without permanently rewriting the UEFI boot order.

## Motivation

The project was created to solve a very specific problem: on the Lenovo laptop used for development, **F12** and sometimes **Enter** are not always detected reliably during the early boot phase. This affects both the internal laptop keyboard and keyboards connected through a USB dongle. If the key press is missed during that short window, the expected boot menu does not appear—instead, the first regular boot target starts immediately, typically the Windows installation on the first NVMe SSD.

When the intended target is an external USB HDD or another installed system, the worst case is frustrating: the wrong Windows installation boots, it must be shut down or restarted again, and the F12/Enter attempt starts over. In practice this sometimes required **up to ten restart attempts** before the keyboard was detected at the right moment.

Lenovo Boot Selector was built to remove that dependency on keyboard timing. The desired boot can be prepared **from within Windows**:

- an existing boot target can be selected as the **one-time target for the next boot**;
- a **persistent default boot target** can be configured and is automatically restored after each Windows system start for the following boot;
- this restore runs as SYSTEM and therefore does **not depend on a user logon**;
- when all participating Windows installations use the same default, the existing **boot menu can act as the recurring default hand-off point**;
- the next restart therefore no longer depends on F12 or Enter being detected within a few seconds of pre-boot time.

For the original use case, this means that when the external USB HDD should boot, the desired target is selected in advance and Windows is restarted. Accidentally booting the wrong NVMe Windows installation—and the resulting chain of repeated shutdowns and restarts—is avoided.

Other systems can suffer from the same class of problem when keyboards are initialized too late or unreliably during the firmware phase, especially through USB, wireless dongles, docks, or other initialization paths. Lenovo Boot Selector provides a reproducible alternative to repeatedly trying to hit the right key at the right moment.

The tool deliberately follows three technical goals:

- **fast and deterministic switching:** select existing boot targets directly from the tray;
- **no permanent change to the normal UEFI order:** the existing firmware configuration remains untouched;
- **a minimal privilege boundary:** the UI runs unelevated and privileged actions are limited to fixed, validated operations.

Lenovo Boot Selector is therefore not a BIOS/UEFI replacement and not a bootloader. It is a Windows interface for a controlled **One-Shot Next Boot** workflow and for systems where classic pre-boot keyboard selection is not reliable enough.

## Features

- select an existing firmware boot target for the **next boot**
- clear tray/popup UI in a Lenovo black/red visual style
- friendly names for known firmware targets
- persistent default boot target through the hardened TaskBroker, restored at Windows system startup without requiring user logon
- restart Windows directly from the application
- autostart without a visible PowerShell/CMD window
- manage ordering and visibility of displayed boot targets
- read-only firmware-target drift detection
- read-only storage context for internal NVMe and USB media
- diagnostic export and maintenance functions
- English (`en-US`) UI by default, with fully selectable and persisted German (`de-DE`)
- self-updater with an automatic read-only version check whenever the popup opens, plus localized manual check/install actions

## Language support

Starting with v0.8.0.0, all product-controlled user-facing UI text is supplied through a central PowerShell-5.1-compatible localization layer. **English (`en-US`) is the default and fallback language**; **German (`de-DE`)** is available from the tray menu under **Language / Sprache** and the selection is persisted in the existing user settings.

A new installation with no settings file starts in English. Existing pre-localization settings (schema versions below 5) migrate to German so an established German installation does not unexpectedly switch language during upgrade. Invalid or unknown stored locale values fail safely to English.

Changing the language updates the tray UI immediately and rebuilds a visible popup in the selected language. Firmware descriptions, drive model names, GUIDs, paths, diagnostic event codes, TaskBroker operations, and other externally supplied or technical identifiers are not translated.

The localization architecture, contribution rules, migration contract, and permanent gates are documented in [docs/LOCALIZATION.md](docs/LOCALIZATION.md).

## Security and maintenance notes

The application runs **unelevated** during normal operation. Privileged firmware mutations are executed only through fixed, allowlisted Windows Scheduled Tasks. Permanent changes to the UEFI boot order are explicitly outside the product model.

The TaskBroker boundary is hardened fail-closed: the runtime accepts only fixed operation types, target-specific task names are derived only from validated installed firmware GUIDs, TaskBroker state/metadata are read-only for normal users, and task DACLs are validated for Read+Execute only. If the installed privileged-task metadata is missing or incompatible, the application reports that setup or repair is required and keeps privileged actions closed until explicit maintenance succeeds. The canonical contract is documented in [docs/SECURITY_BOUNDARY.md](docs/SECURITY_BOUNDARY.md).

Starting with v0.10.0.0, the privileged TaskBroker installation uses `LenovoBootSelector-*` Scheduled Task names and `%ProgramData%\Lenovo Boot Selector\TaskBroker`. Upgrading from v0.9.x or earlier requires one explicit **Repair privileged tasks** action with UAC; the repair migrates a valid system-wide default and removes the exact old TaskBroker installation only after the new one has been fully verified.

**Lenovo Boot Selector** is the only current product name. A small set of older-looking technical identifiers is deliberately retained for updater, package, persisted-state, singleton, or cleanup compatibility; pre-v0.10 TaskBroker identifiers are migration/cleanup inputs only and are no longer runtime authorization identifiers. The complete naming and migration policy is documented in [docs/IDENTIFIER_COMPATIBILITY.md](docs/IDENTIFIER_COMPATIBILITY.md).

Historical migration and repair details for v0.6.4.0/v0.6.4.1 are retained in [CHANGELOG.md](CHANGELOG.md) rather than presented as current maintenance instructions.

**Current development version:** v0.10.4.0  
**Technology:** Windows PowerShell 5.1 · WinForms · Windows Task Scheduler · `bcdedit.exe`

## Downloads and revision history

Versioned builds are stored under [`downloads/`](downloads/). Every product source revision that requires a new build receives a new versioned release ZIP. Previously published builds remain available as immutable historical artifacts.

The latest machine-readable update metadata is stored in [`downloads/latest.json`](downloads/latest.json). The product version history is maintained in [CHANGELOG.md](CHANGELOG.md).

Version format: **MAJOR.MINOR.PATCH.HOTFIX**. Historical three-component versions are compared as if `HOTFIX = 0`.

## Update function

Each transition from a hidden popup to the visible Lenovo Boot Selector UI starts one automatic read-only check for a newer app version, at the same lifecycle point as the existing fresh boot-target refresh. Starting the tray process alone does not perform that check; closing and later reopening the popup starts another one. If an update operation is already busy, the popup-open trigger does not start a competing second update worker. There is still **no periodic polling**. When a newer version is available, the popup header shows the localized update-available text (`New app version available` / `Neue App-Version verfügbar`) as long as no boot-target refresh is active. During a boot-target refresh, the localized refresh state takes precedence; the update indication returns afterward.

The check reads `downloads/latest.json` from the fixed GitHub repository. A newer version is accepted only when manifest, semantic version, filename, tag, size, SHA-256, and package file list are valid. The automatic popup-open check does not download or install anything. Download and installation remain explicit user actions through the existing manual update path. The downloaded ZIP is checked again for size and SHA-256 before extraction. Installation runs unelevated with a local backup and rollback; the app then restarts through the existing VBS launcher.

Since v0.6.3.1, the localized update-available status in the popup header is directly interactive. Hover and keyboard focus highlight the indicator in Lenovo red; click, Enter, or Space opens the existing update dialog. The header uses only the already validated update manifest and does not start another version check. The indicator is not interactive while a boot-target refresh or maintenance operation is active.

Since v0.6.3.0, updater networking is encapsulated in `src/Infrastructure/UpdateTransport.ps1`. Runtime diagnostics distinguish transport failures structurally from manifest, package, hash, installation, and restart failures. Network failures also retain the error class and `WebExceptionStatus`. The security contract remains unchanged: fixed HTTPS source, fail-closed manifest/package validation, unelevated execution, and no periodic polling.

Since v0.5.8.0, the result of an update attempt is persisted across process restart. The restarted app reports success only when the actually running version exactly matches the expected target version. The localized UI then reports update success once. On installation failure, the updater attempts to roll back to the previous version, restarts that version, and reports the failure/rollback state once in the selected language. The result is also copied into the runtime diagnostics of the new session. v0.5.8.1 adds one-time backward compatibility for the legacy `success/message/utc` result format written by older updater helpers; a legacy success is accepted only when `success` is a real Boolean, without inventing a target version that was never stored.

Since v0.5.9.0, the available-update dialog also offers a localized manual install action. It uses the same existing update path as the localized maintenance action; no automatic or second update channel is introduced.

The updater does not change firmware, BCD, or Scheduled Task configuration. Changes to privileged system functions remain exclusive to the existing explicit setup/repair/reinitialize path.

## Current storage presentation

### Internal NVMe SSDs

When exactly one internal NVMe device is detected, the current version shows its physical model for the first internal slot. On the confirmed target system, for example:

- **NVMe SSD 1** — `Internal SSD: KXG8AZNV2T04 LA KIOXIA`
- **NVMe SSD 2** — `No drive detected`

With German selected, the same confirmed state is shown as `NVMe-SSD 1 / Interne SSD: …` and `NVMe-SSD 2 / Kein Laufwerk erkannt`.

When multiple internal NVMe devices are present, the application deliberately does not guess an unsupported physical NVMe0/NVMe1 mapping.

### USB boot media

The firmware target intentionally remains the generic **USB HDD**. The physical drive is shown only as read-only storage context. With exactly one detected USB boot candidate, for example, the default English UI shows `USB boot medium: SanDisk Extreme Pro USB4`; German shows `USB-Startmedium: SanDisk Extreme Pro USB4`.

This presentation makes **no claim of direct 1:1 addressability** of the physical USB device through the generic firmware target `USB HDD`.

## Security model

- The tray application runs as a normal user.
- Privileged changes run only through fixed SYSTEM Scheduled Tasks.
- No free command text, task names, GUIDs, Boot#### numbers, or device paths cross the privilege boundary.
- No custom application EXE runs as SYSTEM.
- Boot mutations use only a **One-Shot Next Boot** path.
- The application never permanently changes `{fwbootmgr} displayorder` or UEFI `BootOrder`.
- The self-updater is fully unelevated and has no separate privileged update channel.

## Requirements

- Windows with **Windows PowerShell 5.1**
- .NET/WinForms
- Lenovo system with firmware boot targets visible through Windows
- administrator rights only for the one-time setup or maintenance of the privileged Scheduled Tasks

## Quick start

1. Download the release ZIP from `downloads/` and extract it completely into a **writable user directory**.
2. Start `Start-LenovoBootMenuTray.cmd`.
3. English is used by default; choose **Language / Sprache** in the tray menu if you want German.
4. On first launch, run the offered system-functions setup through the maintenance menu and confirm the UAC prompt.
5. Select the desired boot target in the popup.
6. Opening the popup automatically performs a read-only version check. The existing maintenance action remains available for an explicit manual re-check or user-controlled update installation.

## Project structure

| Path | Purpose |
| --- | --- |
| `bin/` | release/package inputs and generated runtime artifacts; `version.json` is the authoritative release-version source |
| `src/Core/` | stateless domain logic / Functional Core |
| `src/Application/` | application and workflow logic |
| `src/Infrastructure/` | Windows, storage, update, TaskBroker, and IO adapters |
| `src/UI/` | WinForms presentation |
| `tests/` | active canonical Python gates, native PowerShell tests, and baseline data |
| `tests-history/` | frozen version-specific validators, named by category + version |
| `docs/architecture/` | canonical and historical architecture baselines |
| `docs/LOCALIZATION.md` | localization architecture, migration, contribution rules, and gates |
| `docs/IDENTIFIER_COMPATIBILITY.md` | canonical product naming, retained compatibility IDs, and migration rules |
| `docs/DEVELOPMENT_GUIDELINES.md` | Work-Path/checkpoint/heartbeat resilience, connector, and development-path rules |
| `audits/` | canonical and historical catch audits |
| `tools/` | build, packaging, audit, and transition scripts |
| `downloads/` | historical versioned release ZIPs and update manifests |

## Development and tests

The central native Windows PowerShell 5.1 test wrapper is:

~~~powershell
.\tests\Test-WindowsPowerShell51.ps1
~~~

Build and packaging helpers live under `tools/`. Detailed version history is in [CHANGELOG.md](CHANGELOG.md). Localization development rules are in [docs/LOCALIZATION.md](docs/LOCALIZATION.md). Work-Path development—mandatory for Major/Minor work and used for an explicitly escalated Patch/Hotfix—follows [docs/DEVELOPMENT_GUIDELINES.md](docs/DEVELOPMENT_GUIDELINES.md).

The project's engineering baseline favors Clean Code and SOLID with explicit responsibility boundaries. DRY is applied to genuinely shared rules and knowledge, not mechanically to similar-looking code; limited duplication is preferred over coupling responsibilities that have different reasons to change. The detailed rule is canonical in [docs/DEVELOPMENT_GUIDELINES.md](docs/DEVELOPMENT_GUIDELINES.md).

### Agentic software engineering

Lenovo Boot Selector is developed as an **agentic software engineering** project. GitHub is the project's **single durable point of truth and continuity**: a fresh engineering agent must be able to reconstruct the complete current project state from the current repository, GitHub Issues/comments, workflows, tests, release metadata, and other tracked GitHub evidence alone.

No previous chat, chat summary, handover document or ZIP, model memory, stale local checkout, previous source ZIP, or other unpublished context is required or authoritative for continuing the project. Interactive chats are transient working sessions only. When a durable finding, decision, constraint, acceptance result, or operating rule emerges during a session, it must be captured in the appropriate GitHub artifact before future work depends on it.

Development deliberately uses two persistence models. Small Patch/Hotfix work defaults to one short branchless atomic cycle. Major/Minor work, and any Patch/Hotfix explicitly escalated because it is substantial or interruption-prone, uses a durable `work/LBS-<issue>` Work-Path with coherent product checkpoints plus the temporary `.chatgpt-work/LBS-<issue>.md` continuation journal. While the interactive agent is `ACTIVE`, the journal is updated often enough that its latest heartbeat is no more than approximately three minutes old; `WAITING_FOR_GITHUB` is used only with a concrete independently running Actions run. A roughly five-minute stale heartbeat with no such run is treated as a stopped interactive stream.

Before Candidate creation the Work-Path journal is removed. The Candidate is then created as a clean commit on current `main` whose tree exactly matches the cleaned work branch, so temporary journal/checkpoint history never becomes Candidate, source-tag, PR, or `main` ancestry. After that phase transition, Candidate/Actions/Release state becomes the durable recovery surface. LBS-31, LBS-29 and LBS-27 validated this model in real development; LBS-29 included an actual interactive-stream interruption after Candidate publication and was recovered directly from GitHub state. LBS-27 measured the practical heartbeat cost at roughly **4–6% (about 5%)** of its active Work-Path phase, which the project accepts as a favorable trade for materially stronger interruption recovery. This overhead is confined to Work-Path development; normal small Patch/Hotfix work remains on the journal-free fast path. The canonical details are in [docs/DEVELOPMENT_GUIDELINES.md](docs/DEVELOPMENT_GUIDELINES.md), with GitHub operations in [docs/GITHUB_HOWTO.md](docs/GITHUB_HOWTO.md) and release semantics in [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md).

Agentic work is constrained by the same engineering controls as any other contribution: Issue-backed scope where required, test-first regression handling, explicit safety boundaries, atomic candidate commits, deterministic builds, Linux and Windows PowerShell 5.1 gates, reproducibility checks, post-release verification, and native acceptance where hardware-specific behavior must be proven. Human direction remains authoritative for product intent, safety-sensitive decisions, and final acceptance.

For confirmed bugs and regressions the rule is **failing test first, not failing candidate first**: add a focused permanent regression test, prove that it fails for the expected reason against the unfixed canonical basis, apply the minimal fix, and prove the same test GREEN before exposing a Candidate branch. An intentionally failing Candidate Preflight is not used as RED evidence.

Since v0.6.5.0, a release is first validated as `candidate/v<version>`. A Candidate is release-ready and is created only when its mandatory gates are expected to pass. Only a completely green candidate may be promoted automatically to `release/v<version>` on the exact same commit. Protected runtime fragments use a release-specific `protectedFragmentIntent` instead of permanent exception lists; runtime modules are registered exclusively through template include markers.

Since v0.6.6.0, there are only two active release profiles: `version-only` for unchanged product code under `src/**`, and `patch` for functional product-code changes. The historical `release-architecture` special profile has been removed.

Since v0.6.7.0, the Release Orchestrator aggregates the complete post-release acceptance into a machine-readable `RELEASE_VERIFICATION_SUMMARY`. This allows interactive GitHub verification with far fewer individual queries without reducing Candidate Preflight, reproducibility, 8/8 gates, or source/ZIP integrity checks.

From v0.6.8.0 onward, **English is the canonical language for repository and GitHub documentation**. All tracked Markdown files are maintained in English. Exact UI strings, identifiers, commands, paths, schemas, event codes, and other technical literals may remain in their original form when intentionally quoted. Interactive communication with the user remains separate from this repository policy.
