#!/usr/bin/env python3
"""Focused source contract for LBS-279 visual transaction boundaries."""
import argparse
import re
from pathlib import Path


def function_body(source, name):
    match = re.search(r'(?ms)^function ' + re.escape(name) + r' \{\n(.*?)^\}', source)
    return match.group(1) if match else ''


def ordered(body, *markers):
    pos = 0
    for marker in markers:
        found = body.find(marker, pos)
        if found < 0:
            return False
        pos = found + len(marker)
    return True


def validate_lbs279_render_contract(s, manage, rows):
    enter = function_body(manage, 'Start-ManageEntriesMode')
    exit_mode = function_body(manage, 'Stop-ManageEntriesMode')
    reorder = function_body(rows, 'Invoke-ManageRowKeyboardMove')
    s.c('LBS-279 enter covers mode/list/footer/focus mutation with guaranteed release', ordered(
        enter, 'Start-PopupVisualCommit', 'try {', '$script:IsManageEntriesMode = $true',
        "Update-PopupRows -Reason 'manage-enter'", 'Update-ManageSaveButtonState',
        'Restore-ManageRowFocus', 'finally {', 'Stop-PopupVisualCommit'))
    s.c('LBS-279 exit covers visual mutation after persistence with guaranteed release', ordered(
        exit_mode, 'Save-AppSettings', 'Start-PopupVisualCommit', 'try {',
        '$script:IsManageEntriesMode = $false', "Update-PopupRows -Reason 'manage-exit'",
        'finally {', 'Stop-PopupVisualCommit'))
    s.c('LBS-279 keyboard reorder covers draft/list/focus mutation after boundary no-op', ordered(
        reorder, 'if ($target -eq $index) { return }', 'if ($Reorder)',
        'Start-PopupVisualCommit', 'try {', 'Move-ManageEntry',
        "Update-PopupRows -Reason 'manage-keyboard-reorder'", 'Restore-ManageRowFocus',
        'finally {', 'Stop-PopupVisualCommit'))


class FocusedResult:
    def __init__(self):
        self.failed = 0

    def c(self, name, condition):
        print(('PASS  ' if condition else 'FAIL  ') + name)
        self.failed += not condition


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    result = FocusedResult()
    manage = (args.root / 'src/UI/ManageEntries.ps1').read_text(encoding='utf-8-sig')
    rows = (args.root / 'src/UI/BootEntryRows.ps1').read_text(encoding='utf-8-sig')
    validate_lbs279_render_contract(result, manage, rows)
    return int(bool(result.failed))


if __name__ == '__main__':
    raise SystemExit(main())
