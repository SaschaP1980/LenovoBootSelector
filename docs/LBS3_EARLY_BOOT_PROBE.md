# LBS-3 — read-only early Windows boot readiness probe

## Purpose and limits

This temporary Windows-only probe tests whether the current Lenovo Boot Selector dependencies are available **when an undelayed Windows `AtStartup` Scheduled Task first executes**. It does **not** change the product Default Restore task, firmware `bootsequence`, permanent BootOrder, BCD configuration, TaskBroker settings, or the configured default target. Installation/removal *does* register/unregister one separately named temporary SYSTEM diagnostics task and creates protected diagnostic files. It is opt-in and requires an explicitly elevated Windows PowerShell 5.1 session.

This is an investigation tool, not an approved Default Restore implementation. Results from a conventional running Windows session or from hosted Windows CI cannot prove actual early startup on the owner's ThinkPad. The observation that a read-only firmware enumeration succeeds is **not** proof that a privileged firmware *write + readback* succeeds at the same time. Product changes remain blocked until native acceptance of those additional conditions.

## Files

- `tools/Probe-LBS3EarlyBoot.ps1` — stand-alone installer, startup probe, report collector, and task remover. It uses one fixed temporary task name, `LBS3-EarlyBoot-ReadOnly`, and copies itself to an administrator/SYSTEM-only directory in `%ProgramData%` before registration.
- `tests/test_lbs3_earlyboot_probe.py` — Linux-compatible focused source/safety checks only; no PowerShell parser or Windows SYSTEM execution is claimed.

The SYSTEM task is a fixed `AtStartup` trigger with **no configured Delay**. It runs the staged PowerShell script with `-Mode Probe`. The script performs only `Get-CimInstance Win32_OperatingSystem`, read-only `bcdedit /enum {fwbootmgr} /v`, and protected TaskBroker metadata/default **reads** plus a check that the existing lock file is present. It does not acquire the product writer lock, write firmware, invoke the product BootNext task, or touch the product task definitions. The first sample is immediate after task process initialization; follow-up samples, only if a check fails, are scheduled for approximately 2, 5, 10 and 20 seconds after probe start. Each sample records actual elapsed time and operation duration, not a claimed Windows boot timestamp. A checkpoint JSON is written before the first probe operation and updated atomically after each sample; a killed or hung task can leave `state: running`. Retention is bounded to 20 owned reports.

Reports contain process identity/SID, UTC timestamps, the observed LastBootUpTime, success/error/duration per read, and booleans indicating configured default and whether a `bootsequence` line was seen. **No raw default GUID, firmware output or allowlist is exported.** Exception text might still reveal Windows paths; review before sharing publicly.

## On the physical ThinkPad

1. Download the exact probe script from the reviewed GitHub Work-Branch checkpoint and inspect its SHA-256. Open **Windows PowerShell 5.1 as Administrator**. The example uses `-ExecutionPolicy Bypass` only for that PowerShell child process after source/hash review; it does not change the machine-wide execution policy.
2. Install the temporary test task once:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Probe-LBS3EarlyBoot.ps1 -Mode Install
   ```

   The installer refuses an existing task or existing diagnostic directory, verifies SYSTEM/Highest, exact action, single BootTrigger with no positive delay, and protects its staged script from unprivileged writes. This does **not** trigger a firmware write.
3. Restart Windows normally. After login, run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Probe-LBS3EarlyBoot.ps1 -Mode Collect | Format-List
   ```

4. Inspect the JSON files under `C:\ProgramData\LBS3-EarlyBoot-ReadOnly\`, especially the first sample and any later recoveries. Confirm the task's start/action events using the Windows Task Scheduler Operational log (task name `LBS3-EarlyBoot-ReadOnly`) and correlate with Windows boot events. Repeat across several full restarts; later test shutdown/fast startup/hibernate separately.
5. Remove the temporary task when done:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Probe-LBS3EarlyBoot.ps1 -Mode Remove
   ```

   **The diagnostic JSON remains** in the protected folder for review. The remove operation never deletes any `LenovoBootSelector-*` product task. If the task definition does not match the fixed probe contract, removal stops rather than deleting an arbitrary task.

## Acceptance interpretation

A useful first-stage PASS requires, on a *physical early-boot run*: a completed report, SYSTEM identity SID `S-1-5-18`, and the **initial** sample reporting `bootIdentity.success = true`, `firmware.success = true`, and `broker.success = true`. The default may be legitimately unconfigured (`defaultState = not-configured`), but a subsequent end-to-end restore test must use a genuinely configured valid target. The read-only smoke should succeed on repeated real restarts. If a later sample first succeeds, retain its actual elapsed times as evidence of a boot readiness dependency. If a scheduled task does not start, determine why from Windows Task Scheduler event logs; the absence of a JSON report is not a PASS.

The next stage—**not performed by this tool**—is a separately authorized, native test of the existing product fixed SYSTEM writer with an undelayed BootTrigger, real `bcdedit /set {fwbootmgr} bootsequence` and readback, including manual BootNext priority. That step requires an explicit elevated product repair and a reviewed rollback path. Only after its success should the product's fixed 30-second delay and matching UI/metadata/tests be removed.

## Safety and test status

No Windows Task Scheduler, SYSTEM runtime, early boot, or physical Lenovo test is claimed until independently executed and documented. Python source contract checks do not verify Windows PowerShell 5.1 parsing or ACL behavior. This file and the script can be developed in the Work branch without changing the public product or release.
