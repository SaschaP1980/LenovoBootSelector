# DevOps operations and system hand-offs

> **Role:** Cross-system architecture, evidence inventory, incident navigation and bounded operational runbook. This is an **overview**, not a second normative Release Process, GitHub How-To, development policy or security boundary. Verify its descriptions against the current executable workflows on `main` before acting.

## 1. Scope, ownership and system map

Lenovo Boot Selector consists of a user-controlled **unelevated Windows tray application**, a GitHub-hosted CI/source-release pipeline, immutable historical software packages, and a **separate Cloudflare Diagnostics Worker production deployment**. These components have distinct trust boundaries and different forms of proof.

| System | Operational function | Canonical evidence |
| --- | --- | --- |
| GitHub `main` and Issues | Current project source, backlog, decisions and durable continuity | SHA/tree, Issue and PR history, workflow/source files |
| `work/LBS-<issue>` when applicable | Recoverable product development checkpoints | One cumulative GitHub Issue rolling comment, Development Completion exact-SHA evidence |
| `candidate/v<version>` | Ready-to-test source Candidate | Linux/Windows same-SHA checks and three preflight status contexts |
| `release/v<version>` and Release PR | Deterministic build, security/reproducibility gates, source tag, verified activation | Eight status contexts, preactivation summary, single squash-merge, final verification |
| `downloads/latest.json` and immutable ZIP history | Current public update pointer and retained released packages | Verified `main` pointer, file sizes/hashes and ZIP-free source tag |
| Diagnostics Worker | Separate Cloudflare production diagnostic service | Trusted GitHub Deployment receipt, Worker dependency fingerprint and live read-only `/health` |
| Physical Windows/Lenovo firmware | Installed tray/task boundaries and real boot behavior | Deliberately collected **native target-hardware** results, not hosted CI |

Repository executable code/workflows have primary authority. Normative procedural owners are [Initial Prompt](INITIAL_PROMPT.md), [GitHub How-To](GITHUB_HOWTO.md), [Release Process](RELEASE_PROCESS.md), [Development Guidelines](DEVELOPMENT_GUIDELINES.md) and [Security Boundary](SECURITY_BOUNDARY.md). This file does **not** change the precedence between them.

## 2. Six GitHub Actions workflows and hand-offs

| Workflow | Actual trigger and responsibility | Explicit boundary |
| --- | --- | --- |
| [Development Completion](../.github/workflows/development-completion.yml) | Push to `work/LBS-*` with exact `Development-Completion: requested` trailer runs hosted full-worktree qualification | Work-Path development only; not a source release |
| [Candidate Preflight](../.github/workflows/candidate-preflight.yml) | `candidate/**` push executes Linux and called Windows qualification and promotes only when green | One exact Candidate SHA, three preflight statuses |
| [Windows PowerShell 5.1 Gate](../.github/workflows/windows-powershell51.yml) | Reusable `workflow_call` plus supported manual benchmark mode | Genuine hosted Windows contract suite, **not** physical Lenovo E2E |
| [Release](../.github/workflows/release.yml) | Explicit `workflow_dispatch` for qualified `release/v<version>` | Publication authority, verified single PR/merge and source tag |
| [Diagnostics Worker CI](../.github/workflows/diagnostics-worker-ci.yml) | Relevant `work/LBS-*` pushes, Node/Wrangler and hosted Windows checks | No general `pull_request` trigger, no production deployment |
| [Deploy Diagnostics Worker](../.github/workflows/deploy-diagnostics-worker.yml) | Validated `workflow_dispatch` on trusted `main` | Health-only versus actual Cloudflare production deployment |

### Release pipeline in order

1. **Scope and engineering:** Work starts from verified `main` and authorized Issue. Major/Minor requires Work-Path; Patch/Hotfix normally uses a short atomic path. A confirmed bug needs a focused regression proven RED against the unfixed basis, then GREEN after its correction.
2. **Work-Path only:** Coherent checkpoint commits and **one in-place updated GitHub Issue rolling recovery comment** persist state. The final clean Work tree must pass exact-SHA Development Completion and `Candidate-Entry: PASS`. Any subsequent tree change invalidates that exact-SHA evidence.
3. **Candidate:** A release-ready `candidate/v<version>` push triggers Linux `preflight/linux` and hosted Windows PowerShell 5.1 `preflight/windows-powershell51` on that SHA. Promotion requires both and sets `preflight/candidate` success; it creates the release ref at the exact qualified SHA and explicitly dispatches `release.yml`.
4. **Release:** The orchestrator checks source/main ancestry, builds deterministically twice, validates integrity/regression/security, writes eight release statuses, creates exactly one PR and the annotated **ZIP-free** source tag. `RELEASE_PREACTIVATION_SUMMARY=PASS` proves the previous public pointer is still active before the **single squash merge** atomically updates `main` and `downloads/latest.json`.
5. **Source verification:** `RELEASE_VERIFICATION_SUMMARY.result=PASS` and a terminal successful release run attest to the new source/publication state, PR, tag, ZIP size/hash, immutable history, reproducibility and cleanup. The annotated source tag **does not** equal the final squashed `main` commit.
6. **Independent Worker:** Only after source release verification does the trusted release workflow dispatch a separate Diagnostics Worker workflow. Its health/deployment run must be independently checked and reported.

The **three** Candidate contexts are `preflight/linux`, `preflight/windows-powershell51` and `preflight/candidate`. The **eight** Release contexts are `release/source-integrity`, `release/core`, `release/boundary`, `release/regression`, `release/package`, `release/reproducibility`, `release/history` and `release/tag`. One group cannot substitute for the other.

**Documentation-only changes** take one atomic Markdown/documentation commit directly on freshly verified `main`. They do not create product versions, Work-Branches, Candidates, Release PRs or release ZIPs. See [documentation-only scope](RELEASE_PROCESS.md#documentation-only-scope).

## 3. Environments and observability boundaries

| Environment | What can be verified | What cannot be inferred |
| --- | --- | --- |
| GitHub connector / local inspection | Exact repository content, diff, Issue/PR and limited static checks | Unexecuted hosted CI or deployed production health |
| Hosted Linux | Python contract gates, deterministic packages, source/release structure | Installed Windows Task Scheduler ACLs or Lenovo firmware behavior |
| Hosted Windows 2025 / PowerShell 5.1 | Real native Windows parser and functional tests | Physical ThinkPad UEFI selection or live owner-machine acceptance |
| Published GitHub source and update feed | Tagged source, one publication merge, immutable ZIP/hash and active update pointer | End-user installation on arbitrary machines |
| Cloudflare Worker production | Public `/health`, matching fingerprint, protected upload-state check and GitHub Deployment receipt | Every unexposed provider configuration value or hardware UEFI result |
| Owner hardware | Specifically executed, explicitly observed Windows and firmware behavior | Generalized conclusions across devices/reboots without corroboration |

The product [Security Boundary](SECURITY_BOUNDARY.md) is unchanged: unelevated tray; privileged boot tasks fixed and allowlisted as SYSTEM; no arbitrary commands, Task names, GUIDs or UEFI device paths across that trust boundary; **One-Shot Next Boot** only; no permanent `BootOrder`/`displayorder` mutation. DevOps automation does not grant new boot privileges.

## 4. Diagnostics Worker deployment and health

[Release Process](RELEASE_PROCESS.md#conditional-post-release-cloudflare-worker-verification-lbs-108--lbs-123-v1110) and [the trusted deployment workflow](../.github/workflows/deploy-diagnostics-worker.yml) govern the behavior. The workflow verifies released canonical `main` and package identity before credential-sensitive activity. A read-only plan examines the most recent GitHub production Deployment receipt, deterministic Worker/dependency fingerprint, public `/health` identity and upload configuration.

| Observed outcome | Interpretation | Deployment action |
| --- | --- | --- |
| `WORKER_DEPLOY_RESULT=HEALTH_ONLY_PASS` | Prior successful receipt and live fingerprint/health/upload state match the currently released Worker inputs | Read-only verification, **no** Wrangler redeploy, no Cloudflare secrets or KV mutation |
| `WORKER_DEPLOY_RESULT=DEPLOYED_AND_HEALTHY` | First bootstrap or actual dependency change requires full production deploy and completes verification | Node tests, Wrangler dry-run, credential checks, pending receipt, production deploy, bounded health validation, successful receipt |
| `BLOCKED` or failed Worker job | Missing, malformed, incomplete, stale, unhealthy or contradictory evidence; or deployment/verification failed | Fail closed; preserve failed receipt where one has been registered |

Some errors occur before a receipt or the literal `BLOCKED` summary can be written; inspect the **actual hosted job** rather than asserting that every failure emitted the summary. The source `RELEASE_VERIFICATION_SUMMARY` is not a Cloudflare-success claim.

LBS-125 allows bounded read-only **post-deploy health** retries: maximum five complete requests, eight-second individual timeout, backoff 2/4/6/8 seconds and 70-second overall deadline. The retries **do not repeat Wrangler deployment, modify credentials or rerun receipt creation**. The older unconditional redeploy-on-every-source-release approach is **historical**.

## 5. Current operational evidence and limitations

Available evidence sources: GitHub workflow runs/jobs/logs, commit status contexts, Issue/PR comments, source tag and final Main, ZIP sizes/hashes, `DEVELOPMENT_COMPLETION_SUMMARY`, `CANDIDATE_TIMING_SUMMARY`, `RELEASE_PREACTIVATION_SUMMARY`, `RELEASE_VERIFICATION_SUMMARY`, GitHub Deployment receipts, Worker dependency fingerprints and live `/health`.

The **one rolling GitHub Issue comment** is the cumulative ledger for Work-Path engineering/recovery/heartbeat. An `ACTIVE` heartbeat every roughly three minutes helps identify an interrupted interactive session; it is **not** external always-on uptime monitoring.

**Not established by these mechanisms:** continuous production polling/alerts, pager/on-call, SLO dashboard, automatic firmware observations, generic production rollback or independent provider-side drift checks for configuration invisible to `/health`. Do not present hypothetical facilities as deployed. User-facing build dashboards follow [Build & Deployment Reporting](BUILD_DEPLOYMENT_REPORTING.md) and must separate `PASS`, `FAIL`, `BLOCKED`, `NOT RUN` and unknown.

## 6. Incident and recovery decisions

| Condition | Primary evidence | Existing safe response | Hard boundary |
| --- | --- | --- | --- |
| Regression on a proposed bug fix | Focused RED/expected failure on unfixed SHA; GREEN after fix | Correct and validate before Candidate | Never create deliberately failing Candidate for RED |
| Development Completion failed or stale | Final Work SHA, `development-completion/gate`, job log and Issue ledger | Correct Work branch, new checkpoint and new exact-SHA qualification | Previous Work-SHA proof cannot be reused |
| Linux/Windows Candidate failure | Candidate SHA, `preflight/linux` and `preflight/windows-powershell51` and hosted logs | Classify failure, correct **same Candidate** and rerun required paths | No parallel bypass branch or skipped Windows gate |
| Runner queue or connector outage | Actual run queue/status and exact tool result | Track external wait/run and resume from verified state | Do not claim PASS, cancel or trigger extra run due to wait alone |
| Release gate or preactivation failure | Eight statuses, PR/head/tag, `RELEASE_PREACTIVATION_SUMMARY` | Follow [release recovery](GITHUB_HOWTO.md#recovery-after-a-failed-release-run) using exact source/PR evidence | Do not manually switch latest pointer or move immutable tag |
| Source verified, Worker not verified | Successful source summary **and separately** Worker run/receipt | Report source success and Worker pending/blocked/failure separately | A source release PASS is not Worker deploy PASS |
| Production receipt drift, Worker error or health mismatch | Live `/health`, last Deployment receipt, Worker fingerprint/log | Investigate; use documented trusted-`main` manual recovery only when authorized | No speculative redeploy, secret exposure or silent state change |
| Real Lenovo behavior differs from hosted CI | Explicit native hardware test evidence | Record and investigate on physical target with authorization | Hosted Windows is not Lenovo UEFI E2E |

**Rollback distinction:** The pipeline has fail-closed preactivation and controlled same-branch corrections; the Worker has a separately authorized deploy/manual break-glass path; the product updater has its own update recovery. None implies a deployed **automatic universal rollback** of source, Worker, firmware or user installations.

## 7. Secrets, maintenance, and future work

- Trusted workflow permissions and canonical `main` validation must precede production-secret usage. Never publish token values, diagnostic secrets, serial numbers or other sensitive owner-device identifiers in Issues/PRs.
- Preserve version tags, immutable historical ZIPs, archived validators, architecture baselines and compatibility identifiers. Documentation reorganization is not license to destroy provenance.
- Keep `README.md` and normative document navigation current, and re-check the real executable workflow before stating operational facts.
- Separate **observed evidence** from hypotheses, documented constraints and requested-but-not-implemented features.
- Cloudflare secret rotation, retention and upload-option mutation, automated rollback, external uptime alerting and deeper provider-side drift reconciliation remain **separate, potentially executable proposals** requiring explicit authorization, tests and security review. This document does not enable any of them.
- Changes to source, tests, workflows, scripts, deployment tooling, secrets/configuration, machine-consumed files or production behavior are **not documentation-only**, even when motivated by this runbook.

## 8. Authoritative reference index

| Concern | Owning source |
| --- | --- |
| Bootstrap and authority | [Initial Prompt](INITIAL_PROMPT.md) |
| GitHub Issue/branch/recovery operations | [GitHub How-To](GITHUB_HOWTO.md) |
| Versions, Candidate, Release, Worker hand-off | [Release Process](RELEASE_PROCESS.md) and [release workflow](../.github/workflows/release.yml) |
| Work-Path, checkpoints, RED/ GREEN, Development Completion | [Development Guidelines](DEVELOPMENT_GUIDELINES.md), [rolling ledger template](templates/WORK_PATH_ROLLING_COMMENT.md) |
| TaskBroker privileges and allowed boot mutation | [Security Boundary](SECURITY_BOUNDARY.md) |
| User-facing deployment reporting | [Build & Deployment Reporting](BUILD_DEPLOYMENT_REPORTING.md) |
| Product domains | [Localization](LOCALIZATION.md), [Identifier Compatibility](IDENTIFIER_COMPATIBILITY.md), [Popup Anchoring](POPUP_ANCHORING.md) |
| Cross-system operations and incident evidence | **This document**, verified against its linked executable/normative owners |

When procedures change, update their canonical owner and amend references, **not** a second full copy of the procedure. Legacy examples belong in clearly labeled historical context, and missing runtime capabilities must be reported as missing.
