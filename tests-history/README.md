# Historical validators

This directory contains frozen, version-specific validators from the development history of Lenovo Boot Selector. They are **not** the current permanent release gates. The current gates are under [`../tests/`](../tests/).

## LBS-30 archived localized migration validator

The original `tests/validate_lbs23_localization.py` (32 source/documentation/test-name assertions) was archived byte-for-byte as `localization-v0.8.0.0.py`. This one-off audit is **not an active gate**. Its permanent assertion-owner matrix and native behavior replacements are documented in `../tests/README.md`.

The existing 74 LBS-13 historical validators remain intact. This fifth-category localization file is the separately documented 75th archive. The Release Orchestrator permits precisely this one path deletion after proving identical old/archive Git blob identities; every other tracked deletion remains blocked.

## Naming scheme

`<category>-v<version>.py`

Categories:

- `release` — release/integrity acceptance used at that time
- `core` — core/module validation used at that time
- `boundary` — architecture/privilege-boundary validation used at that time
- `regression` — version-specific regression comparison used at that time
- `localization` — one-off historical LBS-23 migration acceptance, not a current release category

Examples:

- `release-v0.4.0.py`
- `core-v0.5.1.py`
- `boundary-v0.5.8.1.py`
- `regression-v0.5.9.1.py`

The Python files were moved byte-for-byte from `tests/validate_v*.py` during cleanup. They still live exactly one directory level below the repository root so that their existing `ROOT_DEFAULT = Path(__file__).resolve().parents[1]` semantics remain unchanged.
