#!/usr/bin/env python3
"""Focused source safety checks for a Windows-only LBS-3 research probe.

These checks cannot substitute for Windows PowerShell parsing or physical boot tests.
"""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'tools' / 'Probe-LBS3EarlyBoot.ps1').read_text(encoding='utf-8-sig')

class TestEarlyBootProbeContract(unittest.TestCase):
    def test_immutable_fixed_name_and_bounded_modes(self):
        self.assertIn("$taskName = 'LBS3-EarlyBoot-ReadOnly'", SOURCE)
        self.assertIn("[ValidateSet('Install','Probe','Collect','Remove')]", SOURCE)
        self.assertNotIn('param([string]$TaskName', SOURCE)
        self.assertNotIn('Invoke-Expression', SOURCE)

    def test_unmodified_product_scheduler_and_one_shot_firmware(self):
        self.assertIn('Register-ScheduledTask -TaskName $taskName', SOURCE)
        self.assertIn('Unregister-ScheduledTask -TaskName $taskName', SOURCE)
        self.assertNotIn('Unregister-ScheduledTask -TaskName $defaultRestoreTask', SOURCE)
        self.assertNotRegex(SOURCE, r'(?i)\bbcdedit(?:\.exe)?[^\n]*(?:/set|/deletevalue)')
        self.assertNotIn("'/set'", SOURCE)
        self.assertNotIn('SetFirmwareEnvironmentVariable', SOURCE)
        self.assertNotIn('Set-ScheduledTask', SOURCE)

    def test_boot_trigger_has_no_delay_and_is_verified(self):
        self.assertIn('New-ScheduledTaskTrigger -AtStartup', SOURCE)
        self.assertRegex(SOURCE, r'\$trigger\s*=\s*New-ScheduledTaskTrigger -AtStartup[^\n]*')
        self.assertNotIn('$trigger.Delay', SOURCE)
        self.assertIn('Diagnostic boot trigger has an unwanted delay.', SOURCE)
        self.assertIn("[string]$triggers[0].LocalName -ne 'BootTrigger'", SOURCE)

    def test_protection_and_no_arbitrary_system_script(self):
        self.assertIn('Assert-Administrator', SOURCE)
        self.assertIn('SetAccessRuleProtection($true,$false)', SOURCE)
        self.assertIn("'S-1-5-18','S-1-5-32-544'", SOURCE)
        self.assertIn('Refusing reparse-point path', SOURCE)
        self.assertIn('Get-FileHash -LiteralPath $installedScript -Algorithm SHA256', SOURCE)
        self.assertIn('The protected diagnostic script differs from the source.', SOURCE)
        self.assertIn('Assert-ProbeTaskDefinition', SOURCE)

    def test_readiness_evidence_and_bounded_followup(self):
        self.assertIn('Win32_OperatingSystem', SOURCE)
        self.assertIn('LastBootUpTime', SOURCE)
        self.assertIn("& $bcd /enum '{fwbootmgr}' /v", SOURCE)
        self.assertIn("'Lenovo Boot Selector\\TaskBroker'", SOURCE)
        self.assertIn('bootnext-writer.lock', SOURCE)
        self.assertIn('@(0,2,5,10,20)', SOURCE)
        self.assertIn('writesFirmware = $false', SOURCE)
        self.assertIn('if ($owned.Count -gt 20)', SOURCE)
        self.assertIn("$target = Join-Path $probeRoot ('probe-' + $runId + '.json')", SOURCE)

    def test_no_sensitive_firmware_dump(self):
        self.assertIn('bootSequencePresent', SOURCE)
        self.assertNotIn('firmwareText =', SOURCE)
        self.assertNotIn('defaultGuid =', SOURCE)
        self.assertNotIn('allowedGuids =', SOURCE)

if __name__ == '__main__':
    unittest.main(verbosity=2)
