#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import argparse, ast, json, re

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
FIXED_TOTAL_RE = re.compile(r'Write-Host\s+["\']([^"\']*?TOTAL)\s+[^"\']*/(\d+)["\']')
TOTAL_MARKER_RE = re.compile(r'Write-Host\s+["\']([^"\']*?TOTAL)(?:\s+|["\'])')
README_FIXED_RE = re.compile(r'\|\s+`(Test-[^`]+\.ps1)`\s+\|[^\n]*?fixed runtime count of\s+(\d+)\b', re.I)
WINDOWS_MARKER_RE = re.compile(r"Get-TestTotal\s+\$logText\s+'\^([^']*?TOTAL)\\s\+")


def read_text(path: Path) -> str:
    return path.read_text(encoding='utf-8-sig')


def active_test_sources(root: Path) -> dict[str, str]:
    return {p.name: read_text(p) for p in sorted((root / 'tests').glob('Test-*.ps1')) if p.is_file()}


def fixed_totals(text: str) -> list[tuple[str, int]]:
    return [(m.group(1).strip(), int(m.group(2))) for m in FIXED_TOTAL_RE.finditer(text)]


def permanent_validator_literals(root: Path) -> list[tuple[str, str]]:
    rows = []
    for path in sorted((root / 'tests').glob('validate_*.py')):
        tree = ast.parse(read_text(path), filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute):
                continue
            if node.func.attr != 'has' or len(node.args) < 3:
                continue
            literal = node.args[2]
            if not isinstance(literal, ast.Constant) or not isinstance(literal.value, str):
                continue
            value = literal.value
            if 'Write-Host' in value and 'TOTAL' in value and re.search(r'/\d+', value):
                rows.append((path.relative_to(root).as_posix(), value))
    return rows


def validate(root: Path) -> tuple[list[str], int]:
    errors = []
    checks = 0
    sources = active_test_sources(root)
    combined = '\n'.join(sources.values())

    for rel, literal in permanent_validator_literals(root):
        checks += 1
        if literal not in combined:
            errors.append(f'stale fixed-total literal in {rel}: {literal!r}')

    readme = read_text(root / 'tests' / 'README.md')
    for match in README_FIXED_RE.finditer(readme):
        checks += 1
        name = match.group(1)
        expected = int(match.group(2))
        source = sources.get(name)
        if source is None:
            errors.append(f'tests/README.md references missing active suite: {name}')
            continue
        counts = {count for _, count in fixed_totals(source)}
        if expected not in counts:
            errors.append(f'tests/README.md fixed runtime count mismatch for {name}: documented={expected} source={sorted(counts)}')

    emitted_markers = {
        match.group(1).strip()
        for text in sources.values()
        for match in TOTAL_MARKER_RE.finditer(text)
    }
    windows = read_text(root / '.github' / 'workflows' / 'windows-powershell51.yml')
    for match in WINDOWS_MARKER_RE.finditer(windows):
        checks += 1
        marker = match.group(1).replace('\\', '').strip()
        if marker not in emitted_markers:
            errors.append(f'Windows aggregate parses missing TOTAL marker: {marker!r}')

    return errors, checks


def self_test() -> None:
    good = 'Write-Host "FOO TOTAL $checks/2"'
    assert fixed_totals(good) == [('FOO TOTAL', 2)]
    dynamic = 'Write-Host "PARSER TOTAL $passed/$total"'
    assert [m.group(1) for m in TOTAL_MARKER_RE.finditer(dynamic)] == ['PARSER TOTAL']
    sample = "Get-TestTotal $logText '^FOO TOTAL\\s+(\\d+)/(\\d+)\\s*$'"
    match = WINDOWS_MARKER_RE.search(sample)
    assert match and match.group(1) == 'FOO TOTAL'


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=ROOT_DEFAULT)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        self_test()
        print('PASS contract propagation validator self-test')
        return 0

    root = args.root.resolve()
    try:
        errors, checks = validate(root)
    except Exception as exc:
        print(f'FAIL contract propagation validator: {exc}')
        return 1

    passed = checks - len(errors)
    for error in errors:
        print('FAIL  ' + error)
    print(f'CONTRACT PROPAGATION TOTAL {passed}/{checks}')
    summary = {'schemaVersion': 1, 'result': 'PASS' if not errors else 'FAIL', 'checks': checks, 'passed': passed, 'errors': errors}
    print('CONTRACT_PROPAGATION_SUMMARY=' + json.dumps(summary, separators=(',', ':'), sort_keys=True))
    return 0 if not errors else 1


if __name__ == '__main__':
    raise SystemExit(main())
