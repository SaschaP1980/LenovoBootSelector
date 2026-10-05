#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json, re

VERSION_RE = re.compile(r'^\d+\.\d+\.\d+\.\d+$')
VALID_PROFILES = {'version-only','release-architecture','patch'}
STAMP = (2026,10,5,0,0,0)


def load_release_config(root: Path) -> dict:
    path = root / 'version.json'
    if not path.is_file():
        raise RuntimeError(f'missing canonical version file: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if data.get('schemaVersion') != 1:
        raise RuntimeError('version.json schemaVersion must be 1')
    version = str(data.get('version','')).strip()
    if not VERSION_RE.fullmatch(version):
        raise RuntimeError(f'invalid four-part version: {version!r}')
    profile = str(data.get('releaseProfile','')).strip()
    if profile not in VALID_PROFILES:
        raise RuntimeError(f'invalid releaseProfile: {profile!r}')
    published = str(data.get('publishedUtc','')).strip()
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', published):
        raise RuntimeError(f'invalid publishedUtc: {published!r}')
    return {'schemaVersion':1,'version':version,'releaseProfile':profile,'publishedUtc':published}


def load_version(root: Path) -> str:
    return load_release_config(root)['version']


def release_tag(version: str) -> str:
    return f'v{version}'


def release_zip_name(version: str) -> str:
    return f'LenovoBootMenuTray-v{version}.zip'


def source_zip_name(version: str) -> str:
    return f'Lenovo-Boot-Selector-Source-v{version}.zip'
