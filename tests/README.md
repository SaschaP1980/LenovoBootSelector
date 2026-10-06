# Test structure

`tests/` contains only the **active canonical tests** and the baseline data they require. Version-specific historical validators are stored separately under [`../tests-history/`](../tests-history/).

## Permanent Python gates

| File | Category | Purpose |
| --- | --- | --- |
| `validate_release.py` | Release | Release, packaging, source, repository, and documentation invariants |
| `validate_core.py` | Core | Functional core logic and modular core contracts |
| `validate_boundary.py` | Boundary | Architecture, privilege, and module boundaries |
| `validate_regression.py` | Regression | Comparison of the current state with the approved basis |

These four files are the permanent Python gates used by the GitHub Release Orchestrator.

## Native Windows / PowerShell tests

| File | Category | Purpose |
| --- | --- | --- |
| `Test-FunctionalCore.ps1` | Core | Parsers, settings, localization resolution/formatting, and functional core behavior |
| `Test-LocalizationRuntime.ps1` | Runtime | Native PS5.1 language selection, persistence, migration, and central lookup |
| `Test-UpdateCore.ps1` | Core | Update model, transport failure contract, and update contracts |
| `Test-RefreshRuntime.ps1` | Runtime | Background refresh state/request lifecycle and child-worker diagnostics-session correlation |
| `Test-MaintenanceRuntime.ps1` | Runtime | Maintenance state and modes |
| `Test-SingleInstanceMutex.ps1` | Runtime | Single-instance / mutex lifecycle |
| `Test-BootTargetDrift.ps1` | Safety | Drift detection and fail-closed states |
| `Test-TaskBrokerBoundary.ps1` | Safety | LBS-6 fixed-task / metadata boundary without privileged execution |
| `Test-ArchitectureSoak.ps1` | Soak | Repeated architecture/state stability |
| `Test-WindowsPowerShell51.ps1` | Compatibility | Windows PowerShell 5.1 parser/encoding gate and native aggregate runner |

From v0.6.9.0 onward, the aggregate wrapper is also executed automatically by `.github/workflows/windows-powershell51.yml` on a fresh GitHub-hosted `windows-2025` runner using the explicit `powershell` shell. The workflow verifies that the runtime is actually Windows PowerShell 5.1, deterministically regenerates/checks the candidate runtime, and emits a machine-readable `WINDOWS_POWERSHELL51_SUMMARY=<json>`.

That GitHub-hosted execution is valid Windows contract-suite evidence. It is **not** physical Lenovo hardware/UEFI E2E and must be reported separately from tests performed on the target ThinkPad.

The Candidate workflow treats this Windows gate as mandatory for every Major, Minor, Patch, and Hotfix release. Linux Candidate Preflight and the Windows gate run in parallel; promotion waits for both and emits `CANDIDATE_TIMING_SUMMARY=<json>` with critical-path data. The permanent always-on policy was selected after the v0.6.9.0 production benchmark kept the complete candidate-to-release cycle at about 90 seconds.

## Baseline data

- `characterization-baseline-v0.3.4.json` — historical characterization basis.
- `taskbroker-baseline-v0.4.1.json` — TaskBroker basis.
- `ui-baseline-v0.4.3.json` — UI basis.

The baselines intentionally remain under `tests/` because existing historical validators still reference these paths.

## Native assertion-count contracts

Native PowerShell suites intentionally use different count strategies; one generic regex/call-site counter is not correct for every suite.

| Suite | Strategy |
| --- | --- |
| `Test-UpdateCore.ps1` | **AST self-audit + fixed coverage guard.** PowerShell counts the `Assert-True` / `Assert-Equal` command ASTs, compares them with the actually executed `$checks`, and additionally requires exactly 62. The permanent release gate validates the same contract statically. |
| `Test-RefreshRuntime.ps1` | Straight-line: fixed runtime count of 28, including LBS-22 inherited/fresh diagnostics-session coverage for background-refresh, update-check, and update-prepare roles. |
| `Test-TaskBrokerBoundary.ps1` | Straight-line: fixed runtime count of 23. |
| `Test-BootTargetDrift.ps1` | Straight-line: fixed runtime count of 13. |
| `Test-SingleInstanceMutex.ps1` | Explicit manual increments; fixed fail guard of 4. |
| `Test-MaintenanceRuntime.ps1` | Loop-derived: 15 runtime checks from static assertions plus assertions repeated per mode. |
| `Test-ArchitectureSoak.ps1` | Four aggregate soak assertions; each assertion covers many iterations. |
| `Test-FunctionalCore.ps1` | Dynamic PASS counting; currently no separate coverage target count. |
| `Test-LocalizationRuntime.ps1` | Straight-line: fixed runtime count of 32 covering native locale selection, explicit-preference persistence, v0.8.0.0 ambiguity resolution, startup-recovery migration, reload, parity, and lookup. |
| `Test-WindowsPowerShell51.ps1` | Aggregate runner/parser gate; file count is dynamic and is not an assertion-coverage count. |

When assertions are added, the corresponding contract must be updated deliberately. In particular, the fixed `62` guard in the update test must not be derived automatically from the source count: it is an additional change-control guard so that a suite extension cannot pass unnoticed.

## Repository documentation language

English is the canonical language for all repository Markdown and durable GitHub documentation. The permanent release validation checks this policy pragmatically while allowing clearly delimited technical literals and exact UI strings.
