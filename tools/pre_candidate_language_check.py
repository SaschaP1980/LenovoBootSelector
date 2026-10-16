#!/usr/bin/env python3
"""Read-only language and version sanity check for a release-ready candidate tree.

Run on the intended candidate tree before candidate/v* is exposed.
Candidate and Release gates independently repeat it fail closed.
"""
from __future__ import annotations

import argparse
import json
import re
import tempfile
from pathlib import Path

from validate_markdown_language import strip_literals, suspicious_reason, validate as validate_markdown

ROOT_DEFAULT = Path(__file__).resolve().parents[1]
RELEASE_HEADING = re.compile(r'^## v(\d+\.\d+\.\d+\.\d+)\s+[–-]\s+\S')
GERMAN_RELEASE_WORDS = re.compile(
    r'\b(?:erhöht|ausschließlich|versionsnummer|funktionsänderungen|'
    r'veröffentlicht|synchronisiert|geprüft|behoben|fehlerbehebung|'
    r'sicherheitsprüfung|übernommen|unverändert)\b', re.IGNORECASE
)


def check(root: Path) -> list[str]:
    """Validate the repository and its current release-note section."""
    failures: list[str] = []
    try:
        cfg = json.loads((root / 'bin/version.json').read_text(encoding='utf-8-sig'))
        version = cfg['version']
        if not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+\.\d+\.\d+', version):
            return ['bin/version.json: invalid four-component version']
        lines = (root / 'CHANGELOG.md').read_text(encoding='utf-8-sig').splitlines()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return [f'pre-candidate input missing or invalid: {exc}']

    headings = [(idx, match.group(1)) for idx, line in enumerate(lines)
                if (match := RELEASE_HEADING.match(line))]
    if not headings or headings[0][1] != version:
        actual = headings[0][1] if headings else 'none'
        failures.append(f'CHANGELOG.md: first version heading must match v{version}; found {actual}')
    else:
        start = headings[0][0] + 1
        end = headings[1][0] if len(headings) > 1 else len(lines)
        section = lines[start:end]
        if not any(re.match(r'^\s*[-*]\s+\S', line) for line in section):
            failures.append(f'CHANGELOG.md: v{version} needs at least one release-note bullet')
        in_fence = False
        for idx, line in enumerate(section, start + 1):
            if line.lstrip().startswith((chr(96) * 3, '~~~')):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            plain = strip_literals(line)
            if GERMAN_RELEASE_WORDS.search(plain):
                failures.append(f'CHANGELOG.md:{idx}: German release-note wording: {line.strip()}')
            elif suspicious_reason(plain):
                failures.append(f'CHANGELOG.md:{idx}: non-English release note: {line.strip()}')

    failures.extend(validate_markdown(root))
    return sorted(set(failures))


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix='lbs-language-pre-candidate-') as temp:
        root = Path(temp)
        (root / 'bin').mkdir()
        (root / 'bin/version.json').write_text('{"version":"1.2.3.4"}\n', encoding='utf-8')
        log = root / 'CHANGELOG.md'
        good = ('# Changelog\n\n## v1.2.3.4 – Version-only Hotfix\n\n'
                '- Increase the release version only; no functional changes.\n\n'
                '## v1.2.3.3 – Prior release\n\n- Earlier release.\n')
        log.write_text(good, encoding='utf-8')
        assert not check(root), check(root)

        log.write_text(good.replace('Increase the release version only; no functional changes.',
                                    'Erhöht ausschließlich die Versionsnummer.'), encoding='utf-8')
        assert any('German release-note wording' in e for e in check(root))
        log.write_text(good.replace('- Increase the release version only; no functional changes.',
                                    'Version-only metadata update.'), encoding='utf-8')
        assert any('at least one release-note bullet' in e for e in check(root))
        log.write_text(good.replace('v1.2.3.4', 'v1.2.3.5', 1), encoding='utf-8')
        assert any('first version heading must match' in e for e in check(root))
        log.write_text(good, encoding='utf-8')
        (root / 'README.md').write_text('# Einrichtung und Voraussetzungen\n', encoding='utf-8')
        assert any('README.md' in e for e in check(root))
        (root / 'README.md').write_text('# Overview\n', encoding='utf-8')
        assert not check(root)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=ROOT_DEFAULT)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()
    if args.self_test:
        self_test()
        print('PRE_CANDIDATE_LANGUAGE_SELF_TEST=PASS')
        return 0
    failures = check(args.root.resolve())
    for failure in failures:
        print('FAIL  ' + failure)
    if failures:
        print('PRE_CANDIDATE_LANGUAGE_RESULT=FAIL')
        return 1
    print('PRE_CANDIDATE_LANGUAGE_RESULT=PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
