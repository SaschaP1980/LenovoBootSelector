# Release process

From v0.5.10.0 onward the canonical release model is **1 build = 1 release branch = 1 pull request = 1 merge**.

Operational companion for ChatGPT/release supervision: [`GITHUB_HOWTO.md`](GITHUB_HOWTO.md).

## Canonical inputs

- `bin/version.json` is the only authoritative release-version source. Schema v2 intentionally contains no `publishedUtc`.
- `releaseProfile` selects regression strictness. Active values are only `version-only` and `patch`.
- Product runtime receives the version only through the `@APP_VERSION@` token during deterministic runtime generation.
- `tools/prepare_release.py` owns generated release metadata and packages. For schema v2, publication time must be supplied explicitly with `--published-utc`.
- Canonical `publishedUtc` is owned by GitHub: the Release Orchestrator captures one UTC timestamp only after the hosted runner is executing the publication job and reuses that exact value for both deterministic rebuilds. Local preparation timestamps are provisional and are never committed as canonical publication metadata.
- `version-only`: use when product code under `src/**` is unchanged. Regression requires product-source byte identity to the previous canonical source basis, apart from the injected runtime version.
- `patch`: use when product code under `src/**` changes functionally.
- The former `release-architecture` profile was removed in v0.6.6.0. Its only special behavior covered the already completed migration from a hard-coded AppVersion to the `@APP_VERSION@` template token. Historical validators remain in `tests-history/`; there is no active selectable migration profile.

## Issue prerequisite by version level

Before implementation/release preparation:

- **MAJOR / MINOR / PATCH:** relevant GitHub Issue(s) are mandatory before implementation starts. Do not create the release candidate or release branch for issue-less Major/Minor/Patch product work.
- **HOTFIX:** an Issue is optional for a narrow defect correction. A direct Hotfix may be implemented and released without first creating an Issue when no existing Issue covers it.
- If a Hotfix corrects a direct regression/incomplete implementation of an already completed Issue, reopen that original Issue, document the confirmed failure/root cause and Hotfix plan, reassess priority, and keep it open through successful Hotfix publication. Add the final Hotfix version/PR result, then close it again as `completed`.

For Issue-backed releases, the Issue is part of the audit trail: important implementation findings belong in comments, and closure occurs only after successful publication/post-release verification.

## Release level and work-branch policy

Release level is derived from the first changed component of the four-part numeric version relative to the currently published version:

- component 1 → **Major**;
- component 2 → **Minor**;
- component 3 → **Patch**;
- component 4 → **Hotfix**.

Work-branch policy is intentionally asymmetric:

- **Major / Minor:** `work/LBS-<issue>` is mandatory.
- **Patch / Hotfix:** default to **no work branch** and the shortest safe atomic implementation path.
- Before Patch/Hotfix implementation, perform a brief effort/risk analysis. Use a work branch only as an exception when the change is likely to be substantial, cross-cutting, migration-heavy, interruption-prone, or otherwise likely to require several recoverable checkpoints.
- A Patch/Hotfix exception must be recorded durably before implementation and the Candidate must contain exactly one `Work-Branch-Reason: <reason>` trailer.
- Do not escalate a small Patch/Hotfix merely to reuse the Major/Minor process.

## Test-first bug/regression preparation

For every confirmed product bug or regression, use **failing test first, not failing candidate first**.

Before implementing the fix:

1. add a focused permanent regression test that specifies the corrected behavior;
2. execute it against the current unfixed canonical basis and confirm RED for the expected defect-specific reason;
3. record the RED evidence in the active Issue when Issue-backed, or in equivalent durable release history for an Issue-less Hotfix.

Then implement the smallest fix, rerun the same regression test and require GREEN. Complete applicable broader prechecks before Candidate creation.

The Candidate branch is **release-ready**, not a RED-test vehicle. Do not intentionally publish a known-failing Candidate or run Candidate Preflight merely to prove the pre-fix failure. Candidate Preflight is the mandatory integration/release-entry gate for a state that is already expected to pass. Unexpected Candidate failures continue to use the existing same-branch fast-forward correction path.

## Local release preparation

1. Verify the version-level Issue prerequisite above.
2. Change `bin/version.json`.
3. Add the corresponding `CHANGELOG.md` section for **every** published version. This is mandatory even for a version-only Hotfix, a pure version bump, or a release-performance measurement.
4. Set `protectedFragmentIntent` to exactly the protected fragments intentionally changed by this version; normally `[]`.
5. Set `repositoryDeleteIntent` to exactly the repository paths intentionally deleted by this version; normally `[]`.
6. For a bug/regression, complete the focused RED→GREEN proof described above and run applicable broader prechecks.
7. Prepare one exact **release-ready** candidate commit based on current `main`.
8. The candidate-only commit range must contain exactly one unique `Work-Branch:` trailer:
   - Major/Minor: `Work-Branch: work/LBS-<issue>` is mandatory;
   - Patch/Hotfix normal path: `Work-Branch: none`;
   - Patch/Hotfix exception: `Work-Branch: work/LBS-<issue>` plus exactly one `Work-Branch-Reason: <reason>` from the pre-implementation effort/risk analysis.
   Same-candidate correction commits may omit these trailers, but must not introduce conflicting values. When a work branch is declared, its current tree must exactly match the Candidate tree.
9. Push that commit only as `candidate/v<version>`. Do **not** manually create `release/v<version>`.

### Version-only minimum diff

For a release whose only intended product change is the version number, the minimum valid release diff is still:

- `bin/version.json`
- the matching minimal `CHANGELOG.md` section

`tools/prepare_release.py` validates the changelog/version pairing. A candidate without the matching changelog entry must fail before promotion to `release/v<version>`.

This rule was empirically confirmed by the v0.6.7.1 release-cycle measurement.

## Mandatory candidate preflight

`.github/workflows/candidate-preflight.yml` is the release-entry gate for a Candidate that is already expected to be GREEN. It is not the normal mechanism for obtaining pre-fix RED evidence. From v0.6.9.0 onward it runs two mandatory candidate paths in parallel on the exact same SHA:

- **Linux Candidate Preflight** on `ubuntu-latest`, which runs `tools/candidate_preflight.py` against the immediately previous canonical source tag and performs deterministic preparation, two reproducibility builds, Release/Core/Boundary/Regression, protected-fragment intent, repository-delete intent and historical-ZIP checks. It writes `preflight/linux`.
- **Windows PowerShell 5.1 Gate** through `.github/workflows/windows-powershell51.yml` on an ephemeral GitHub-hosted `windows-2025` runner. It verifies Windows PowerShell 5.1, deterministically regenerates/checks the candidate runtime, runs `tests/Test-WindowsPowerShell51.ps1`, emits `WINDOWS_POWERSHELL51_SUMMARY=<json>`, and writes `preflight/windows-powershell51`.

A separate promotion job depends on both jobs. It verifies that both latest statuses are successful on the exact candidate SHA, that the candidate branch still points to that SHA, and that current `main` remains an ancestor. Only then does it write `preflight/candidate=success`, create `release/v<version>` at the same SHA, explicitly dispatch `release.yml`, and delete the candidate branch.

The promotion job emits `CANDIDATE_TIMING_SUMMARY=<json>` with Linux/Windows queue and duration data, Windows setup/runtime-preparation/test timings, total candidate-gate elapsed time, and the critical-path owner.

The explicit `workflow_dispatch` is mandatory because a `GITHUB_TOKEN` branch push does not recursively trigger another workflow. If dispatch fails, promotion marks `preflight/candidate` failed and rolls the new release branch back.

`release.yml` refuses a release SHA unless `preflight/candidate`, `preflight/linux`, and `preflight/windows-powershell51` are all successful and current `main` remains an ancestor. GitHub then reruns the authoritative publication gates.

The Windows workflow also supports manual `workflow_dispatch` benchmark/retest runs. Those runs are Windows contract-suite evidence only; they are not physical Lenovo firmware/UEFI E2E.

The permanent LBS-20 execution policy is **always mandatory** for Major, Minor, Patch, and Hotfix releases.

The v0.6.9.0 production benchmark measured the Windows job at about 25.0 seconds total (12.7 seconds setup, 1.3 seconds runtime preparation, 10.9 seconds tests), with 46/46 parser and 174/174 functional checks. Linux Candidate Preflight completed in about 4 seconds. The Windows path extended the candidate critical path by about 27.8 seconds, while the complete candidate-to-release cycle finished in about 90 seconds. This remains well within the project's 2–3 minute orchestration target, so the Windows gate is retained for every version level. Timing remains machine-readable through `CANDIDATE_TIMING_SUMMARY` for ongoing observation.

## GitHub publication

`candidate-preflight.yml` runs first on `candidate/**` and is the only normal path that promotes a candidate SHA to `release/v<version>`.

`release.yml` runs on `release/**`. Once a hosted runner is actually executing the job, it first verifies all three candidate statuses (`preflight/candidate`, `preflight/linux`, `preflight/windows-powershell51`) plus current-main ancestry, captures the canonical `publishedUtc`, then deterministically recreates all generated release files from the canonical inputs plus that single GitHub-owned timestamp. It verifies a second in-run rebuild byte-for-byte, derives a ZIP-free source commit without creating a source branch, adds exactly one new historical release ZIP to the same release branch and opens exactly one pull request.

The single permanent `release.yml` workflow runs the full release/core/boundary/regression gates itself before PR creation, writes the successful gate states directly onto the final PR-head commit, creates the annotated ZIP-free source tag only after successful PR creation, then merges the PR and deletes the release branch. A separate `pull_request` workflow is intentionally not used: pull requests created with the repository `GITHUB_TOKEN` do not recursively start another workflow.

After the merge, the Release Orchestrator also owns **work-branch cleanup**. If the Candidate declared `Work-Branch: work/LBS-<issue>`, the workflow re-reads that branch immediately before deletion and deletes it only when its current tree still exactly equals the released Candidate tree. If the branch advanced or diverged, cleanup fails closed and the branch is preserved; the workflow never force-deletes active development state. `Work-Branch: none` means no work-branch deletion is expected.

After cleanup, the same workflow runs `tools/release_verification.py`. This integrated verifier checks PR/merge state, exactly one publication PR, 8/8 release statuses, all 3/3 candidate statuses, source tag/source tree, `downloads/latest.json`, published release ZIP hash/size, candidate/release/work-branch cleanup and the completed reproducibility marker. It emits one machine-readable `RELEASE_VERIFICATION_SUMMARY=<json>` line and a human-readable GitHub Job Summary.

There is no version-specific workflow, separate PR-verification workflow, Base64 patch transport, helper source branch, separate required post-merge finalizer, or per-version validator copy.

## Historical ZIP invariant

Existing `downloads/*.zip` files are immutable. A release may add exactly one new ZIP. Existing ZIPs may not be modified, deleted, or temporarily removed/re-added.

## Performance targets

GitHub validation depth is not reduced for performance.

- Linux Candidate Preflight and the Windows PowerShell 5.1 gate run in parallel; promotion waits for both.
- Candidate timing is emitted as `CANDIDATE_TIMING_SUMMARY=<json>`, including queue/duration data and critical-path ownership.
- Hosted Candidate Preflight + Release Orchestrator remain governed by their existing safety gates.
- Once implementation is ready, a small conflict-free connector-supervised patch should target roughly **2–3 minutes interactive orchestration time**, excluding external runner queues/incidents.
- Achieve this by batched initial reads, one atomic candidate commit, non-aggressive run observation and the aggregated `RELEASE_VERIFICATION_SUMMARY`; never by skipping gates or verification.
- If the structured summary is unavailable or not `PASS`, fall back to the full direct post-release verification.

## Runner queue policy

Interactive release supervision waits at most 60 seconds for a GitHub-hosted runner assignment. If the job is still `queued` with no runner after that window, the condition is reported as external GitHub queue delay. The workflow is not cancelled, retried or duplicated; GitHub continues autonomously. A later `Github Status` check verifies the terminal state.


## Repository/runtime layout

Product runtime source is modular under `src/**`, with `src/App/LenovoBootMenuTray.template.ps1` providing the ordered runtime include registry. The deterministic build produces the single-file runtime under `bin/`; `bin/version.json` is the authoritative release-version source and the remaining `bin/` files are release/package inputs or generated runtime assets. The downloadable Release ZIP intentionally remains a flat 10-file package. Architecture baselines live under `docs/architecture/`; catch audits live under `audits/`. The canonical generated files are `docs/architecture/ARCHITECTURE_BASELINE.json` and `audits/CATCH_AUDIT.json`; historical versioned snapshots remain alongside them.

## Documentation language

English is the canonical language for repository and durable GitHub documentation.

- All tracked `*.md` files, including `README.md`, `CHANGELOG.md`, `docs/**`, `tests/**`, `tests-history/**`, and `downloads/README.md`, use English prose.
- New Markdown documentation must be written in English.
- Durable GitHub Issue/PR/release/process documentation uses English.
- Stable technical literals and exact UI strings may remain unchanged when intentionally quoted.
- Interactive chat with the user is outside this repository-language contract and may remain in German with English technical terminology.

The permanent release validation includes a practical Markdown-language guard so that accidental reintroduction of German prose fails before publication.

## Operational guide maintenance and GitHub-only continuity

`docs/GITHUB_HOWTO.md` is a mandatory living operational artifact. New durable findings about GitHub integration/release behavior and intentional changes to that integration must be documented there when established.

GitHub is the sole durable continuity mechanism for release work. A future engineering session must not require a previous chat, handover document/ZIP, model memory, or local artifact to reconstruct release state or operating rules. Any durable release-process finding established during a session must be written to the appropriate repository document, Issue/comment, workflow, test, or source contract before future work depends on it.

