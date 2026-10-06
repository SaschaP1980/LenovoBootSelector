# Historical validators

This directory contains frozen, version-specific validators from the development history of Lenovo Boot Selector. They are **not** the current permanent release gates. The current gates are under [`../tests/`](../tests/).

## Naming scheme

`<category>-v<version>.py`

Categories:

- `release` — release/integrity acceptance used at that time
- `core` — core/module validation used at that time
- `boundary` — architecture/privilege-boundary validation used at that time
- `regression` — version-specific regression comparison used at that time

Examples:

- `release-v0.4.0.py`
- `core-v0.5.1.py`
- `boundary-v0.5.8.1.py`
- `regression-v0.5.9.1.py`

The Python files were moved byte-for-byte from `tests/validate_v*.py` during cleanup. They still live exactly one directory level below the repository root so that their existing `ROOT_DEFAULT = Path(__file__).resolve().parents[1]` semantics remain unchanged.
