#!/usr/bin/env python3
"""Focused source contract for LBS-277, also consumed by the regression gate."""
import argparse
import re
from pathlib import Path


def validate_lbs277_state_contract(s, update_runtime):
    checking = re.search(r'(?ms)^function Set-UpdateRuntimeChecking \{\n(.*?)^\}', update_runtime)
    s.c('LBS-277 checking does not discard the validated manifest', bool(checking) and re.search(r'(?i)\$State\.AvailableManifest\s*=', checking.group(1)) is None)


def validate_lbs277_transport_contract(s, transport):
    entry = re.search(r'(?ms)^function Invoke-LenovoUpdateTextDownload \{\n(.*?)^\}', transport)
    body = entry.group(1) if entry else ''
    s.c('LBS-277 manifest entrypoint uses eligible curl and explicit compatibility route',
        'Invoke-LenovoManifestCurlProcess -StartInfo $psi' in body and
        'Invoke-LenovoUpdateDotNetManifestDownload' in body)


class FocusedResult:
    def __init__(self):
        self.failed = 0

    def c(self, name, condition):
        print(('PASS  ' if condition else 'FAIL  ') + name)
        self.failed += not condition


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path)
    parser.add_argument('--transport-source', type=Path)
    args = parser.parse_args()
    result = FocusedResult()
    if args.transport_source:
        validate_lbs277_transport_contract(result, args.transport_source.read_text(encoding='utf-8-sig'))
    elif args.root:
        source = (args.root / 'src/Application/UpdateRuntime.ps1').read_text(encoding='utf-8-sig')
        validate_lbs277_state_contract(result, source)
        transport = (args.root / 'src/Infrastructure/UpdateTransport.ps1').read_text(encoding='utf-8-sig')
        validate_lbs277_transport_contract(result, transport)
    else:
        parser.error('--root or --transport-source is required')
    return int(bool(result.failed))


if __name__ == '__main__':
    raise SystemExit(main())
