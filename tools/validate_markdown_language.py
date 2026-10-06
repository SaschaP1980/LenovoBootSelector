#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import argparse
import re

ROOT_DEFAULT = Path(__file__).resolve().parents[1]

GERMAN_STOPWORDS = {
    'aber','als','auch','auf','aus','bei','beim','bereits','bleibt','bleiben','das','dass',
    'dem','den','der','des','die','dies','diese','diesem','diesen','dieser','dieses','durch',
    'ein','eine','einem','einen','einer','eines','für','gegen','hat','haben','hier','im','in',
    'ist','kein','keine','keinen','mit','muss','müssen','nach','nicht','noch','nur','oder',
    'sich','sind','statt','über','um','und','vom','von','vor','wenn','werden','wird','wurde',
    'wurden','zur','zum'
}

GERMAN_STRONG = {
    'änderung','änderungen','aktuell','ausführung','benutzer','bestehend','bestehende',
    'build-revisionshistorie','einrichtung','erforderlich','fehler','funktionen','gehärtet',
    'historische','hinweis','korrigiert','neu','prüfung','reparatur','sicherheitsmodell',
    'schnellstart','standard-startziel','teststruktur','verfügbar','voraussetzungen','warum',
    'wartung','zweck'
}

INLINE_CODE = re.compile(r'`[^`]*`')
BOLD = re.compile(r'\*\*[^*]+\*\*')
LINK_TARGET = re.compile(r'\]\([^)]*\)')
HTML = re.compile(r'<[^>]+>')
CURLY_QUOTE = re.compile(r'[„“][^„“]*[„“]')
STRAIGHT_QUOTE = re.compile(r'(?<!\w)"[^"\n]*"(?!\w)')
WORD = re.compile(r"[A-Za-zÄÖÜäöüß-]+")
HEADING = re.compile(r'^\s*#{1,6}\s+')


def strip_literals(line: str) -> str:
    line = INLINE_CODE.sub(' ', line)
    line = BOLD.sub(' ', line)
    line = CURLY_QUOTE.sub(' ', line)
    line = STRAIGHT_QUOTE.sub(' ', line)
    line = LINK_TARGET.sub(']', line)
    line = HTML.sub(' ', line)
    return line


def suspicious_reason(line: str) -> str | None:
    cleaned = strip_literals(line)
    words = [w.lower() for w in WORD.findall(cleaned)]
    if not words:
        return None

    strong = sorted({w for w in words if w in GERMAN_STRONG})
    stop = sorted({w for w in words if w in GERMAN_STOPWORDS})

    if HEADING.match(cleaned) and (strong or len(stop) >= 2):
        return f'German-looking heading tokens: {", ".join(strong or stop)}'

    score = len(strong) * 2 + len(stop)
    if score >= 4 and len(words) >= 4:
        evidence = strong + stop
        return f'German-looking prose tokens: {", ".join(evidence[:8])}'
    return None


def markdown_files(root: Path):
    for path in sorted(root.rglob('*.md')):
        if '.git' in path.parts:
            continue
        yield path


def validate(root: Path) -> list[str]:
    failures: list[str] = []
    for path in markdown_files(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding='utf-8-sig')
        in_fence = False
        for number, line in enumerate(text.splitlines(), 1):
            if re.match(r'^\s*(```|~~~)', line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            reason = suspicious_reason(line)
            if reason:
                failures.append(f'{rel}:{number}: {reason}: {line.strip()}')
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.root.resolve()

    files = list(markdown_files(root))
    failures = validate(root)
    if failures:
        print('FAIL  Repository Markdown prose is not consistently English')
        for failure in failures:
            print(f'  {failure}')
        print(f'\nMARKDOWN LANGUAGE TOTAL 0/1 ({len(files)} files scanned, {len(failures)} suspicious lines)')
        return 1

    print(f'PASS  Repository Markdown prose is English ({len(files)} files scanned)')
    print('\nMARKDOWN LANGUAGE TOTAL 1/1')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
