# LBS-3: five-reboot acceptance without opening the LBS popup

This is owner-operated **native** acceptance, not a CI test. In v1.5.0.0 the fixed SYSTEM Default Restore has one AtStartup BootTrigger **without** a Delay element. Windows still decides when that boot-triggered task actually runs; this is not a pre-Windows or zero-latency guarantee. The operation remains a one-shot firmware bootsequence, not permanent BootOrder.

## One-time preparation

1. Install the validated v1.5.0.0 package using the normal LBS update/install path.
2. Choose **Maintenance -> Repair privileged tasks** and explicitly approve UAC. This is **required** to upgrade the installed TaskBroker schema 0.2.15 to 0.2.16 and replace the old PT30S trigger; installing new app files alone does not alter the existing scheduled task. Failed Repair means STOP.
3. Confirm a system-wide Standard-Startziel is configured and allowed. Do not manually change BootNext during the baseline restart series.
4. Save the read-only source file `tools/Export-LBS3BootSnapshot.ps1` from the reviewed v1.5.0.0 source in your Downloads folder. It does not launch the LBS popup or need an LBS runtime session.

## For each of five actual Windows restarts

Use **Restart**, not shut down, sleep, or hibernate. After each restart and Windows logon, open **Windows PowerShell 5.1 as Administrator** and run:

```powershell
& "$env:USERPROFILE\Downloads\Export-LBS3BootSnapshot.ps1"
```

Review the printed `LBS3 result` and unique JSON path. Required for a valid baseline pass: `AUTO_DEFAULT_CONFIRMED`, TaskBroker 0.2.16, one enabled BootTrigger with no Delay, current-boot successful task execution, matching protected provenance `kind=auto`/`bootId`/`guid`, and fresh firmware `bootsequence` matching the configured Standard-Startziel. The script writes JSON under `%USERPROFILE%\Downloads\LBS3-BootEvidence` and **never** changes firmware, tasks, or TaskBroker files.

If the script says `UNVERIFIED`, **do not count a pass**. Save the JSON and stop for analysis. An old Scheduled Task `LastTaskResult=0` alone is not adequate; a stored default file alone is not proof of a successful firmware write; the fresh firmware read must match the protected current-boot completion.

After five verified restarts, in PowerShell:

```powershell
Compress-Archive -Path "$env:USERPROFILE\Downloads\LBS3-BootEvidence\LBS3-BootEvidence-*.json" -DestinationPath "$env:USERPROFILE\Downloads\LBS3-five-reboots.zip" -Force
```

Review for boot GUIDs or system identifiers before sharing, then upload the ZIP in the ChatGPT issue discussion. We need five distinct Windows boot IDs and five independently confirmed restore/readback results. The existing LBS session-oriented runtime-diagnostics ZIP does **not** independently attest to these early SYSTEM writes.

## Known limitations

The no-delay task may start tens of seconds after reported Windows boot because Windows controls Task Scheduler readiness. A script result `UNVERIFIED` can indicate a genuine failure, unavailable firmware information, a manual BootNext override, missing UAC repair, or a parser limitation. Preserve evidence instead of assuming a cause. This sequence covers normal restarts only; cold-start, fast startup, and resume paths require separate proof.

Source: Issue #3, TaskBroker schema and the protected LBS-143 BootNext origin contract.
