#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json, re

VERSION_RE = re.compile(r'^\d+\.\d+\.\d+\.\d+$')
VALID_PROFILES = {'version-only','release-architecture','patch'}
STAMP = (2026,10,5,0,0,0)


def load_release_config(root: Path) -> dict:
    path = root / 'bin' / 'version.json'
    if not path.is_file():
        raise RuntimeError(f'missing canonical version file: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    schema = data.get('schemaVersion')
    if schema not in {1,2}:
        raise RuntimeError('version.json schemaVersion must be 1 or 2')
    version = str(data.get('version','')).strip()
    if not VERSION_RE.fullmatch(version):
        raise RuntimeError(f'invalid four-part version: {version!r}')
    profile = str(data.get('releaseProfile','')).strip()
    if profile not in VALID_PROFILES:
        raise RuntimeError(f'invalid releaseProfile: {profile!r}')
    published = None
    if schema == 1:
        published = str(data.get('publishedUtc','')).strip()
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', published):
            raise RuntimeError(f'invalid publishedUtc: {published!r}')
    elif 'publishedUtc' in data:
        raise RuntimeError('version.json schemaVersion 2 must not contain publishedUtc; GitHub owns publication time')

    protected=data.get('protectedFragmentIntent',[])
    if not isinstance(protected,list) or any(not isinstance(x,str) or not x.strip() for x in protected):
        raise RuntimeError('protectedFragmentIntent must be an array of non-empty strings')
    if len(protected)!=len(set(protected)):
        raise RuntimeError('protectedFragmentIntent must not contain duplicates')

    deletes=data.get('repositoryDeleteIntent',[])
    if not isinstance(deletes,list) or any(not isinstance(x,str) or not x.strip() for x in deletes):
        raise RuntimeError('repositoryDeleteIntent must be an array of non-empty strings')
    if len(deletes)!=len(set(deletes)):
        raise RuntimeError('repositoryDeleteIntent must not contain duplicates')
    for rel in deletes:
        p=Path(rel)
        if p.is_absolute() or '..' in p.parts or rel.startswith('.git/'):
            raise RuntimeError(f'invalid repositoryDeleteIntent path: {rel!r}')

    return {
        'schemaVersion':schema,
        'version':version,
        'releaseProfile':profile,
        'publishedUtc':published,
        'protectedFragmentIntent':sorted(protected),
        'repositoryDeleteIntent':sorted(deletes),
    }


def load_version(root: Path) -> str:
    return load_release_config(root)['version']


def release_tag(version: str) -> str:
    return f'v{version}'


def release_zip_name(version: str) -> str:
    return f'LenovoBootMenuTray-v{version}.zip'


def source_zip_name(version: str) -> str:
    return f'Lenovo-Boot-Selector-Source-v{version}.zip'
