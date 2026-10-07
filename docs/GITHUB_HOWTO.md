# GitHub How-To

## Bootstrap for a new chat

The canonical one-line entry point for a completely new chat is `docs/INITIAL_PROMPT.md`. If the user only points to that file, the new chat must execute the complete bootstrap described there and then read this guide and the other current contracts.

When a fresh engineering session takes over development, a build, a Hotfix, or a GitHub release for Lenovo Boot Selector, it must reconstruct the complete current project state from GitHub. No previous chat, handover artifact, model memory, local checkout, or prior source ZIP is required or authoritative.

Mandatory order:

1. **Read current `main` and record its SHA/tree.**
2. **Read this `docs/GITHUB_HOWTO.md` in full from current `main`.**
3. **Read `docs/RELEASE_PROCESS.md` in full.**
4. **Read `docs/DEVELOPMENT_GUIDELINES.md` in full** for Major/Minor work and for Patch/Hotfix work only when the pre-implementation effort/risk analysis escalates it to the work-branch/checkpoint model.
5. For Issue-backed work, read the **current GitHub Issue** including state, labels, comments, and acceptance criteria.
6. Read **`bin/version.json`** and verify current version, `releaseProfile`, `protectedFragmentIntent`, and `repositoryDeleteIntent`.
7. Read the relevant executable contracts:
   - `.github/workflows/candidate-preflight.yml`
   - `.github/workflows/windows-powershell51.yml`
   - `.github/workflows/release.yml`
   - `tools/candidate_preflight.py`
   - `tools/release_verification.py`
   - the four permanent validators under `tests/`
8. If resuming an existing `work/LBS-*` task, read that work-branch head and the Issue's rolling recovery comment, then directly verify any referenced GitHub Actions run before continuing. A legacy `.chatgpt-work/LBS-<issue>.md` may exist on older active branches but is not the primary recovery surface.
9. Only then determine scope, target version, and implementation/release plan. For Patch/Hotfix, perform the brief effort/risk analysis **before implementation** and default to the branchless atomic path unless the analysis justifies escalation.

### Authority order

When information conflicts:

1. current GitHub `main`, including executable workflows/tools;
2. current normative documents `docs/GITHUB_HOWTO.md` and `docs/RELEASE_PROCESS.md`;
3. current GitHub Issues and their comments, including recorded acceptance evidence.

Off-repository material such as previous chats, model memory, local files, source ZIPs, or handover artifacts has no authority. If a durable fact is missing from GitHub, capture it there rather than carrying it forward privately.

### Minimum start check before any implementation

Before creating code or release refs, the new chat must be able to answer at least:

- What SHA is current `main`?
- What is the current product version?
- Which Issue or Hotfix scope authorizes the change?
- Is the intended version level Major, Minor, Patch, or Hotfix?
- Which release profile is correct: `version-only` or `patch`?
- Which files are allowed to change functionally?
- Which Candidate/Release gates must end GREEN?
- Which native Windows tests were actually executed and which were only covered statically/in CI?

If any of these fundamentals is unclear, read the repository/Issue first instead of guessing.

## Authority and conflict resolution

Use this precedence when information disagrees:

1. The current GitHub repository state and executable workflow/build code on `main`.
2. Normative repository documentation, especially `docs/RELEASE_PROCESS.md` and this document.
3. Current GitHub Issues/comments for backlog, implementation status, and acceptance evidence.

Previous chat context is not part of the authority chain. A fresh session must be able to derive every durable project fact needed for safe continuation from GitHub alone.

Never use a stale feature branch as a development basis merely because it still exists. The canonical development basis is GitHub `main`, unless the user explicitly names another verified branch.

## Living-document maintenance — mandatory

This operational GitHub guide is a **living project artifact** and must be kept current.

Whenever work reveals a new durable fact about the GitHub integration, repository publishing behavior, release workflow, connector capabilities/limitations, recovery procedure, validation contract or another operational GitHub rule, update `docs/GITHUB_HOWTO.md` in the same workstream as soon as that fact is established.

Likewise, whenever the GitHub integration or its release/operating process is intentionally changed, update this guide so that it describes the new behavior rather than preserving an obsolete procedure.

Do not rely on chat memory or off-repository transition artifacts for such knowledge. Durable GitHub-operating knowledge belongs in this guide or another appropriate GitHub artifact.

When interactive work reveals a durable fact that a future engineering session will need, update the appropriate repository documentation, Issue/comment, test, workflow, or source contract in the same workstream. The continuity test is simple: a fresh session with access only to GitHub must be able to recover the fact.

## Source of truth

- `main` is the canonical development basis.
- `bin/version.json` is the only authoritative release version input.
- GitHub Issues are the only authoritative backlog. Do not maintain a competing local backlog.
- GitHub repository state plus durable GitHub Issues/comments form the complete project continuity record; previous chats and handover artifacts are never required.
- Existing files under `downloads/*.zip` are immutable historical releases.
- The annotated version tag points to the exact ZIP-free source commit.
- `main` after a release points to the merged publication state and therefore also contains the newly added historical release ZIP.
- Source-tag state and post-merge `main` are intentionally not identical.

## User command semantics

When the user says **“Implementiere …”**, **“baue …”** or otherwise explicitly requests implementation, the normal project contract is:

`implement -> build -> test -> GitHub publication -> final verification`

Do not stop after editing source unless the user explicitly says not to build or not to publish.

When the user says **“Github Status”**, verify the complete last relevant release state, not only whether one workflow is green. The status check must cover workflow, PR/merge, tag, `main`, 8/8 release statuses, release-branch cleanup, `downloads/latest.json`, the release ZIP, and the ZIP/cache-free source tag.

## Safety invariants that a GitHub change must not weaken

The following are architectural hard boundaries:

- The tray application runs unelevated.
- Privileged operations use only fixed allowlisted SYSTEM Scheduled Tasks.
- No free command text, arbitrary task names, arbitrary GUIDs, Boot#### numbers, device paths or equivalent generic privileged arguments may cross the privilege boundary.
- Do not introduce a custom SYSTEM EXE/broker.
- Boot selection is a **one-shot Next Boot** operation.
- Never permanently mutate UEFI `BootOrder` or `{fwbootmgr}` `displayorder`.
- Do not add polling or PnP/device-arrival handlers as a shortcut for storage or boot refresh.
- Storage discovery is read-only context. Do not claim an unsupported physical-device-to-firmware-target mapping.
- The updater remains unelevated and must not become a second privileged control channel.
- BootService, TaskBroker, Storage and firmware/BCD boundaries must remain unchanged unless the requested feature explicitly requires a reviewed change there.

## Version and release profile

The version format is four components:

`MAJOR.MINOR.PATCH.HOTFIX`

Historical three-component versions compare as `HOTFIX = 0`.

Before a release:

1. Update `bin/version.json`.
2. Add the corresponding `CHANGELOG.md` section **for every released version**, including a version-only Hotfix or a pure release-performance measurement.
3. Choose the release profile intentionally.
4. If product code under `src/**` is unchanged, use `version-only`. This profile requires strict product-source byte identity to the previous canonical source basis, apart from the injected runtime version.
5. If product code under `src/**` changes functionally, use `patch`.
6. These are the only active profiles. The former `release-architecture` profile was removed in v0.6.6.0 because it encoded a completed one-time AppVersion-template migration and caused misleading profile selection/false positives.

### Mandatory changelog contract

Every version that is actually published must have a matching `CHANGELOG.md` section **before** the candidate branch is created.

This also applies when the requested product change is only “raise the version number”, a version-only Hotfix, or a release-pipeline/performance measurement. In those cases the minimum release diff is:

`bin/version.json + matching minimal CHANGELOG.md section`

Do not interpret “only bump the version” as permission to omit the changelog. `tools/prepare_release.py` enforces this contract and Candidate Preflight will fail before the release branch if the section is missing.

The v0.6.7.1 measurement confirmed this behavior: the first candidate was rejected because only `bin/version.json` had changed; after adding the minimal v0.6.7.1 changelog section, the same candidate branch passed.

## Fresh-worktree rule

Build and validation must operate from a fresh, known repository state based on current `main`/the intended release head.

Do not silently fall back to an old local source ZIP when GitHub access is inconvenient.

For Python release tooling use no-bytecode mode:

- `python -B ...`
- `PYTHONDONTWRITEBYTECODE=1` for child processes/workflows

The exact source tag must contain neither ZIP files nor `__pycache__`/`.pyc` artifacts.

## Runtime module closure — template is the single source of truth

Lenovo Boot Selector is modular in source but published as a deterministic single-file PowerShell runtime.

From v0.6.5.0 onward, the ordered `# @include <path>` markers in `src/App/LenovoBootSelector.template.ps1` are the **only runtime-module registry**. `tools/build_runtime.py` discovers the include list directly from the template; there is no second static `INCLUDES` list to keep in sync.

For every new runtime module:

1. add exactly one `# @include <path>` marker at the intended position in the template;
2. ensure the path is a relative `src/**/*.ps1` file and exists;
3. run the runtime builder/preflight.

The builder fails on duplicate markers, unsafe/invalid paths, missing files, unresolved include markers or an unresolved version token.

### Why this rule exists

The first v0.6.3.0 publication attempt (GitHub Actions run #17) failed because `UpdateTransport.ps1` existed in the template but was omitted from the former static `tools/build_runtime.py::INCLUDES` registry. v0.6.5.0 removes that double bookkeeping entirely.

## Pre-publication validation

Validation before Candidate exposure is **development-path specific**.

### Branchless Patch/Hotfix fast path

Use the lightweight atomic contract defined in `docs/RELEASE_PROCESS.md` and `docs/DEVELOPMENT_GUIDELINES.md`:

- prove the focused bug/regression RED→GREEN when applicable;
- run directly relevant syntax/parser/encoding/determinism smoke checks;
- verify version/changelog/release metadata and inspect the complete Candidate diff;
- do not create a chain of local/full-matrix commits merely to imitate Candidate Preflight.

For this deliberately lightweight path, Candidate Preflight is the first authoritative full repository integration matrix unless another explicit release contract makes a pre-Candidate check mandatory.

### Work-Path

For `work/LBS-*`, the final exact Work SHA must satisfy the mandatory Candidate Entry contract below. That contract includes deterministic runtime/audit/baseline, all four permanent validators, intent equality, relevant focused/native/source-type checks, propagation/ownership sweeps when applicable, and hosted Windows exact-SHA evidence.

A missing mandatory Work-Path capability is `BLOCKED`; it is not permission to fall back to Candidate as the first runner.

### Common release facts

GitHub owns the canonical `publishedUtc`; any local timestamp is provisional only.

If Windows/PowerShell tests have not actually been executed on Windows, never report them as passed. Static/source-contract coverage is not a substitute for a Windows pass. A GitHub-hosted Windows PowerShell 5.1 run is a real Windows test run for the contract suite, but it is **not** Lenovo hardware/UEFI E2E and must be reported separately from physical-machine acceptance.

### Work-Path Candidate Entry operational rule

For any `work/LBS-*` release, the detailed Candidate-entry contract in `docs/DEVELOPMENT_GUIDELINES.md` is mandatory.

Operationally:

1. freeze the intended final Work-Branch SHA;
2. before the first hosted Development Completion request, directly execute the changed Python validator/release-tool/workflow-helper runtime path when applicable; syntax/AST/import-only checks do not satisfy this runtime-binding smoke;
3. produce all mandatory Candidate-entry evidence on that exact SHA;
4. run the Contract Propagation Sweep when test/validator/workflow contracts changed;
5. run the Ownership/Change-Impact Matrix when responsibility ownership moved;
6. derive and verify protected/delete intent from the exact final reconciled diff;
7. require hosted Windows PowerShell 5.1 evidence on the exact final Work SHA;
8. re-read `main` and Work-Branch head after the checks;
9. update the Issue rolling comment with an explicit `Candidate-Entry: PASS|BLOCKED` block;
10. expose Candidate only when the block is PASS.

For mandatory evidence, unavailable tooling is **BLOCKED**, not `N/A`. `N/A` is valid only when a check is genuinely not applicable to the change and the reason is recorded.

Do not use Candidate Preflight as the first executor of a missing mandatory Development Completion check.

#### Starting Development Completion from a connector-only session

The canonical implementation is `.github/workflows/development-completion.yml`.

After the intended Work tree is complete and all release metadata/generated artifacts are synchronized:

1. re-read current `main` and reconcile the Work tree;
2. if changed Python validators/release tools/workflow helpers are part of the tree, run a direct focused runtime smoke that reaches each changed execution path; record the exact command/test and PASS result. `py_compile`, AST/source inspection, or import-only success is not enough to catch runtime binding/order failures;
3. persist the last substantive Work-Branch checkpoint;
4. create one new commit with **the identical tree** and the exact trailer `Development-Completion: requested`;
5. advance the same `work/LBS-<issue>` ref to that request commit;
6. observe the resulting `Development Completion` Actions run for that exact SHA;
7. require terminal PASS, `DEVELOPMENT_COMPLETION_SUMMARY=<json>`, and `development-completion/gate=success`;
8. require the summary/status Main SHA to remain current and the Work-Branch head to remain the tested SHA;
9. record the run ID, summaries, totals, timings and Candidate Entry block in the rolling Issue ledger.

No direct `workflow_dispatch` action is required. Ordinary checkpoint pushes intentionally produce only a skipped Development Completion run because they lack the request trailer.

If any correction changes the Work tree or moves the Work head after a gate attempt, previous evidence is stale. Persist the correction, create a fresh tree-identical request commit, and rerun.

Candidate Preflight independently enforces the successful exact Work-SHA status plus its bound Main SHA and exact Work/Candidate tree equality.

When a test contract changes, explicitly search active repository contracts for stale suite names, total markers, expected counts, aggregate keys, wrappers, hosted parsers, permanent validators and test inventory references before declaring Candidate Entry PASS.

When an automated transformation touches executable/machine-consumed files, inspect the exact diff and per-file change volume before checkpointing. An unexpectedly large or structurally unrelated delta is a hard stop; rebuild the affected file from a verified basis instead of incrementally repairing an untrusted transformation.


### Test-first bug/regression rule: failing test first, not failing candidate first

For a confirmed bug or regression, establish the regression contract **before changing the product code**:

1. add a focused permanent regression test that expresses the corrected behavior;
2. execute that test against the current unfixed canonical basis and verify that it fails for the expected bug-specific reason;
3. record the RED evidence durably when applicable: base SHA, test/validator and relevant failure reason belong in the active Issue for Issue-backed work; an Issue-less Hotfix must retain equivalent evidence in its changelog/PR/release audit trail;
4. implement the smallest fix;
5. rerun the same test and require GREEN;
6. complete the applicable broader prechecks before creating the Candidate.

The RED run should use the narrowest available test or validator harness capable of reproducing the defect against the canonical basis. A materialized canonical basis or focused local/container check is sufficient when it executes the relevant contract. The purpose is to prove that the new regression test detects the old defect, not to make the release pipeline fail.

**Do not intentionally create or push a known-failing `candidate/v<version>` to collect RED evidence.** Candidate branches are release candidates: they are exposed only after implementation, focused RED→GREEN proof, release metadata and applicable prechecks are complete, and all mandatory Candidate gates are expected to pass.

An unexpected Candidate Preflight failure is still handled by the normal same-branch fast-forward correction process; this exception does not convert Candidate Preflight into a test sandbox.

## Candidate-tree preflight before release branch creation

From v0.6.5.0 onward, a product release enters GitHub through a temporary **`candidate/v<version>`** branch, not directly through `release/v<version>`. The Candidate is a release-ready state whose mandatory gates are expected to pass; it is not used for deliberate RED test runs.

From v0.6.9.0 onward, the exact candidate SHA is validated by two mandatory jobs that run in parallel after the candidate push:

1. **Linux Candidate Preflight** on `ubuntu-latest`:
   - verifies candidate branch/version pairing and current `main` ancestry;
   - checks that the target release branch/tag do not already exist;
   - materializes the immediately previous canonical source tag as the regression basis;
   - runs `tools/candidate_preflight.py`;
   - performs deterministic preparation and two byte-identical provisional builds;
   - runs Release/Core/Boundary/Regression;
   - validates protected-fragment intent and repository-delete intent;
   - rejects any pre-publication modification of historical `downloads/*.zip`;
   - writes `preflight/linux` on the exact candidate SHA.
2. **Windows PowerShell 5.1 Gate** through `.github/workflows/windows-powershell51.yml` on a fresh GitHub-hosted `windows-2025` runner:
   - checks out the same exact candidate SHA;
   - explicitly verifies Windows PowerShell 5.1;
   - deterministically regenerates/checks the runtime;
   - runs `tests/Test-WindowsPowerShell51.ps1`;
   - emits `WINDOWS_POWERSHELL51_SUMMARY=<json>` with parser/suite totals and setup/runtime/test/total timings;
   - writes `preflight/windows-powershell51` on the exact candidate SHA.

A separate **promotion job** has `needs` dependencies on both jobs. It may create `release/v<version>` only if both jobs are successful, the latest `preflight/linux` and `preflight/windows-powershell51` statuses are successful on the same exact SHA, the candidate branch still points to that SHA, and current `main` is still an ancestor. Only then does it write `preflight/candidate=success`, create the release ref, explicitly dispatch `release.yml`, and delete the temporary candidate branch.

The promotion job also emits `CANDIDATE_TIMING_SUMMARY=<json>`. It records Linux/Windows queue and execution durations, Windows setup/runtime-preparation/test timings, total time until both candidate gates are complete, and whether Linux or Windows owned the candidate critical path.

The explicit dispatch is required because GitHub deliberately prevents a normal push performed with `GITHUB_TOKEN` from recursively starting another workflow. `workflow_dispatch` is the supported handoff. If dispatch fails, promotion overwrites `preflight/candidate` to failure and deletes the just-created release branch again.

The Release Orchestrator independently requires successful `preflight/candidate`, `preflight/linux`, and `preflight/windows-powershell51` statuses on the exact release SHA and also verifies that current `origin/main` remains its ancestor. A manually created, stale, or partially validated release branch therefore fails closed.

The Windows workflow also supports manual `workflow_dispatch` runs for benchmark/retest purposes. Manual runs do not count as a candidate gate and must not be reported as firmware/hardware E2E.

The permanent LBS-20 policy is **always mandatory** for Major, Minor, Patch, and Hotfix releases.

The first production benchmark was v0.6.9.0. Its Windows runner reported Windows PowerShell 5.1.26100.33438 with 46/46 parser checks and 174/174 functional contract checks. The Windows job took about 25.0 seconds total (about 12.7 seconds setup, 1.3 seconds runtime preparation, and 10.9 seconds test execution). Linux Candidate Preflight completed in about 4 seconds. Because both ran in parallel, the Windows gate owned the candidate critical path and added about 27.8 seconds relative to Linux completion. The complete candidate-start-to-release-complete cycle was about 90 seconds, still comfortably inside the project's roughly 2–3 minute orchestration target.

Based on that measured critical-path impact and the additional Windows-specific coverage gained on every release, the gate remains mandatory for all version levels. Future timing data continues to be emitted by `CANDIDATE_TIMING_SUMMARY`; changing this policy requires an explicit, tested, documented release-process change.

If either candidate gate fails unexpectedly, **no release branch exists yet**. Keep the same `candidate/v<version>` branch, apply the minimal fast-forward correction, and let the normal push rerun both mandatory paths. Do not create a parallel candidate or release branch. Do not manufacture such a failure as part of normal test-first evidence.

For every unexpected Candidate failure, update the rolling Issue ledger with exactly one primary classification:

- `Development Guideline miss`;
- `Tooling gap`;
- `Genuinely Candidate-only`;
- `External infrastructure failure`.

Then record the corrective action. Guideline misses require a process/permanent-contract hardening action; tooling gaps require a linked tooling/automation Issue; genuinely Candidate-only findings require a reason why no pre-Candidate check could evaluate them; external failures must not be counted as repository correctness failures.


### Protected-fragment intent is release-specific

`bin/version.json` carries `protectedFragmentIntent`, an explicit list of protected fragment keys intentionally changed by that version.

For Work-Path Candidate entry, derive the declaration from the **exact final reconciled diff** before Candidate exposure. Re-read current `main`, compute the actual protected-fragment change set for the final Work-Branch state, and require exact set equality:

`actual protected changes == protectedFragmentIntent`

Undeclared protected changes fail. Stale/extra declarations fail. An empty list is valid only after the exact final diff proves the actual set is empty.

Any later executable/source/workflow/test change that can affect the protected diff, or any later `main` reconciliation, invalidates the evidence and requires recomputation before Candidate entry.

Candidate Preflight independently repeats the authoritative release-entry calculation against the immediately previous canonical source tag.

The former permanent `INTENTIONALLY_CHANGED_FROZEN` bypass is removed. A function that was intentionally changed in an earlier release is fully protected again in the next release.

### Repository deletion intent

`bin/version.json` also carries `repositoryDeleteIntent`.

For Work-Path Candidate entry, derive it from the same exact final reconciled diff used for protected-fragment intent and require exact set equality. Any later repository-path change or `main` reconciliation makes the evidence stale and requires recomputation.

Candidate Preflight independently compares all repository deletions against this exact list and rejects undeclared or stale deletion intent. Historical release ZIPs may not be changed by the candidate at all.

The GitHub Release Orchestrator remains the authoritative second backstop and reruns the server-side release gates; Candidate Preflight reduces avoidable publication attempts but never replaces final GitHub verification.

## Canonical publication model

For a product build:

`1 exact candidate SHA = 1 release branch = 1 PR = 1 merge`

Entry branch:

`candidate/v<version>`

Promoted publication branch, created automatically only after GREEN:

`release/v<version>`

The candidate branch is temporary and is deleted by the Candidate Preflight workflow after successful promotion. Do not manually create `release/v<version>` for a normal product release and do not manually add the new historical release ZIP. The Release Orchestrator builds and adds it.

The persistent `.github/workflows/release.yml` is the publication authority. There is intentionally no version-specific workflow, no helper source branch, no Base64 patch transport, no separate PR workflow and no required post-merge finalizer.

## What the Release Orchestrator is expected to do

A successful release run should, in substance:

1. Check out the one release branch.
2. Capture one GitHub-owned UTC publication timestamp after the hosted runner starts.
3. Recreate generated runtime/audit/release state.
4. Build release and source packages.
5. Perform a second independent rebuild and compare outputs byte-for-byte.
6. Run the permanent release/core/boundary/regression gates.
7. Derive the exact ZIP-free source commit without creating a source helper branch.
8. Verify that the source commit contains no ZIP/cache artifacts.
9. Add exactly one new historical release ZIP while leaving all older ZIPs byte-unchanged.
10. Commit the publication state to the release branch.
11. Write successful release-status contexts onto the final PR head.
12. Create exactly one PR.
13. Create the annotated source tag only after the PR exists and all preceding gates passed.
14. Add the tag status gate.
15. Merge the PR and delete the release branch.
16. Verify the merged `main` publication metadata.
17. Run the integrated LBS-16 post-release verifier and emit one `RELEASE_VERIFICATION_SUMMARY=<json>` line plus the GitHub Job Summary.

## LBS-16 orchestration efficiency

For connector-supervised releases, optimize the **number of orchestration roundtrips**, not the depth of validation.

Use phase snapshots:

1. **Preparation snapshot:** read current `main` SHA/tree, implementation Issue, version and all files required for the planned change in one batched/parallel read where technically possible. Reuse that snapshot while its base SHA remains current.
2. **Patch/Hotfix focused validation:** for the normal branchless path, run the bug-specific RED regression against the unfixed canonical basis, then require that same regression GREEN after the fix. Add only source-type smoke checks that protect distinct risks (for example Python syntax, PowerShell parser/encoding/BOM, deterministic generated-output checks). Do not run or reconstruct the full repository matrix before every intermediate Git object.
3. **Atomic candidate preparation:** create all intended blobs, one tree and one candidate commit; inspect that commit once before exposing `candidate/v<version>`. For a normal Patch/Hotfix, avoid file-by-file visible implementation commits.
4. **Candidate observation:** perform one initial run lookup. Do not tight-poll. When the run is terminal, read run/jobs/logs together where possible and consume `CANDIDATE_PREFLIGHT_SUMMARY=<json>`.
5. **Release observation:** after dispatch, avoid re-reading unchanged candidate facts. On terminal success, consume the single `RELEASE_VERIFICATION_SUMMARY=<json>` emitted by the Release Orchestrator.
6. **Issue completion:** use the verified summary for the release facts, add the final Issue comment and close the Issue. Do not repeat individual PR/tag/status/latest/ZIP/source-tree reads merely to reconstruct facts already verified in the summary.

`tools/release_verification.py` performs the complete server-side post-release aggregation after the merge. It verifies the merged PR, exactly one publication PR, 8/8 release statuses, all 3/3 candidate statuses (`preflight/candidate`, `preflight/linux`, `preflight/windows-powershell51`), annotated source tag/commit, ZIP-/cache-free source tree, `downloads/latest.json`, published release ZIP size/hash, candidate/release branch cleanup and the prior reproducibility marker.

The structured summary is an **aggregation of completed checks**, not a replacement for them. If the workflow is not terminal success, the summary is missing, `result != PASS`, or a requested fact is absent, fall back to the full direct post-release checklist below.

The practical target for a small conflict-free patch, once code is ready and runners are available, is roughly **2–3 minutes of interactive orchestration**, while GitHub still executes all existing gates.

### Avoid duplicate validation

Once a behavior/invariant has a permanent executable owner, call that test or validator instead of rebuilding the same proof with connector-side string searches. An additional test is justified only when it covers a distinct layer or failure mode.

In particular:

- prefer an existing Functional Core/native/integration test over a new issue-specific validator that only mirrors it;
- avoid exact prose/punctuation assertions for human documentation unless tooling genuinely consumes that exact text;
- do not manually repeat catalog parity, runtime closure, protected-fragment or other checks already owned by permanent validators;
- do not re-verify fields individually after a successful aggregate Candidate/Release summary unless investigating an inconsistency.

LBS-23/v0.8.0.1 demonstrated the cost of violating this rule: duplicated structural checks and an issue-specific validator created extra quote/prose-literal corrections without adding equivalent product protection.

## The eight release status gates

A fully accepted release has exactly these successful contexts on the final PR head:

- `release/source-integrity`
- `release/core`
- `release/boundary`
- `release/regression`
- `release/package`
- `release/reproducibility`
- `release/history`
- `release/tag`

A green workflow is important, but the final acceptance check should also verify these 8/8 statuses directly.

## Runner queue policy

After a release push, allow at most 60 seconds for a GitHub-hosted runner assignment during interactive supervision.

If after 60 seconds the run is still `queued` with no runner:

- report `EXTERNAL_QUEUE_WAIT`;
- do not cancel the workflow;
- do not retry it;
- do not push another no-op commit;
- do not create a second release branch;
- let GitHub continue autonomously.

A later **Github Status** check must verify the terminal result.

For broader GitHub/service write outages, use `Agent-State: BLOCKED_EXTERNAL` in the rolling ledger when the comment path remains writable. Preserve the last confirmed SHA/state, avoid rapid retries/no-op writes, and resume only after write capability is independently confirmed. If Issue-comment writes are also unavailable, do not claim a heartbeat was persisted; record the outage immediately when writes recover. Retain outage duration in raw wall-clock history but exclude it from normalized repository-process performance metrics.


## Recovery after a failed release run

A failed workflow run does **not** automatically mean a new release branch/version is required.

If the run fails before PR/tag/publication side effects:

1. Read the failing job log and identify the exact gate.
2. Keep the same `release/v<version>` branch.
3. Apply the minimal correction as a fast-forward commit on that branch.
4. Let the normal branch push trigger the next workflow run.
5. Do not manually rerun the failed job if a code correction is required.
6. Do not create a parallel release branch or duplicate publication path.

The project invariant is **one release branch / one PR / one merge**, not necessarily one workflow-run attempt.

Multiple workflow runs on the same release branch are acceptable during correction. There must still be exactly one successful publication PR, one source tag and one merge.

### v0.6.3.0 verified recovery example

- Run #17 failed during release preparation because the new runtime module was missing from `tools/build_runtime.py::INCLUDES`.
- It failed before PR/tag/release publication.
- The same `release/v0.6.3.0` branch was fast-forwarded with the build-closure fix.
- Run #18 succeeded.
- Exactly one publication PR (#28), one `v0.6.3.0` tag and one merge were produced.

## Post-release verification checklist

Do not declare a release complete until all relevant items are verified:

1. Release workflow is terminal `success`.
2. Exactly one publication PR exists and is merged.
3. `main` points to the expected merge result/publication state.
4. Final PR head has 8/8 successful release contexts.
5. The annotated `v<version>` tag exists.
6. The tag resolves to the intended exact source commit.
7. The source commit contains no `.zip`, `__pycache__` or `.pyc`.
8. `downloads/latest.json` has the expected version, tag, file, SHA-256, size and GitHub-owned publication timestamp.
9. The new historical release ZIP exists.
10. Previously published ZIPs are unchanged.
11. The release branch has been deleted.
12. Only after this should the corresponding implementation Issue be closed as `completed`.
13. For Issue-backed work, add the final release/version/PR result to the Issue before closing it.
14. If the release is a corrective Hotfix for a reopened Issue, close it only after the Hotfix itself is published and verified.
15. Candidate branch cleanup is confirmed.

From v0.6.7.0 onward, `RELEASE_VERIFICATION_SUMMARY` verifies items 2–11 and 15 together inside the same authoritative Release Orchestrator. For normal interactive supervision, one terminal workflow/log read of a `result=PASS` summary is sufficient evidence for those aggregated facts; do not issue redundant connector reads for each field. Item 1 (terminal workflow success) is still checked directly. Issue closure remains a separate explicit action.

## GitHub Issues / backlog discipline

GitHub Issues are the backlog and the canonical implementation/audit trail for planned product work.

### Issue requirement by version level

The version level determines whether an Issue is mandatory **before implementation starts**:

- **MAJOR:** at least one relevant GitHub Issue is mandatory before implementation.
- **MINOR:** at least one relevant GitHub Issue is mandatory before implementation.
- **PATCH:** at least one relevant GitHub Issue is mandatory before implementation.
- **HOTFIX:** a pre-existing/new Issue is optional. A narrowly scoped defect may be fixed, built, tested and released directly when no Issue already covers it.

A Major/Minor/Patch release must not be started as issue-less work and must not reach `release/v<version>` without a relevant Issue that existed before implementation. If several independent product changes are bundled, each substantive work item should be represented by an Issue rather than hidden only in a changelog/PR.

The Hotfix exception exists to keep urgent, narrow corrections fast. Even when a Hotfix has no Issue, the root cause, scope, tests and release result must still be documented in the changelog/PR/release history.

### Issue-backed implementation lifecycle — best practice

When work is backed by an Issue, keep that Issue as the durable lifecycle record:

1. Read/reconcile the Issue against current `main` before changing code.
2. Keep/reopen the Issue while its implementation or a directly related corrective Hotfix is actively unresolved.
3. Preserve the Issue's type/status labels and maintain exactly one current `priority:*` label.
4. During implementation or corrective work, add concise comments for materially important findings such as confirmed root cause, changed scope, migration impact or the planned Hotfix version.
5. Close the Issue as `completed` **only after** the implementing release is successfully published and post-release verification is complete.
6. Before closing, add a final implementation/release comment that records at least the released version and relevant release PR; include important migration/testing notes when applicable.

If a released implementation later proves defective and the defect is a **direct regression or incomplete fulfillment of that same Issue**, reopen the original Issue instead of silently fixing around it. Add a comment with the confirmed failure/root cause and Hotfix plan, reassess its priority for the active incident, and keep it open until the corrective release is published and verified. Then add the Hotfix release result and close it again as `completed`.

Create a new Issue instead when the newly found problem is materially different in scope from the original Issue rather than a regression/incomplete implementation of it.

Before implementing an Issue:

- read the current Issue body and acceptance criteria;
- compare them with current `main`, because older Issue text may be partially obsolete;
- determine whether the Issue is already fully implemented, partially implemented or still open;
- update/implement only the remaining valid contract;
- do not resurrect a `wontfix` item without explicit user direction.

### Canonical Issue label taxonomy

Use labels as independent dimensions. Do not encode priority, development path, and work type into one label.

#### Primary type

For a newly created actionable LBS Issue, normally choose exactly one primary type:

- `bug` — existing/released behavior is incorrect, regressed, or fails its documented contract. A confirmed bug/regression is subject to the project's focused RED-before-fix rule.
- `enhancement` — new capability, refactoring, architecture work, release/process hardening, documentation/process improvement, or other planned change that is not a defect in existing behavior.

Historical closed Issues that predate this taxonomy do not need retroactive relabeling.

#### Priority

Every **open** Issue must carry exactly one current priority label:

- `priority: critical` — active severe defect or security/safety boundary violation requiring immediate attention; release-blocking when applicable.
- `priority: high` — high-impact correctness/security/architecture risk that should be addressed ahead of normal enhancements, but is not an active critical failure.
- `priority: medium` — meaningful product/release/process improvement with clear value but no immediate safety or availability impact.
- `priority: low` — parked, evidence-dependent, cosmetic, explicitly non-urgent or deliberately deferred work.

Priority is independent of type/status and development-path labels. Reassess it whenever evidence, scope, risk, or implementation status materially changes. Closed Issues may retain their final priority as historical provenance; old closed Issues are not required to be normalized.

#### Development path

The two development-path labels are mutually exclusive:

- `dev-path: fast` — the Issue will use the branchless atomic Patch/Hotfix path.
- `dev-path: work-branch` — the Issue will use `work/LBS-<issue>` with product checkpoints and the Work-Path rolling-comment recovery standard.

A backlog Issue may intentionally have **no** `dev-path:*` label while the implementation path is still undecided. For Issue-backed **executable/product release work**, choose the path during the required pre-implementation effort/risk analysis and set exactly one development-path label before implementation starts:

- Major/Minor work uses `dev-path: work-branch`;
- Patch/Hotfix defaults to `dev-path: fast`;
- a Patch/Hotfix uses `dev-path: work-branch` only when the documented escalation criteria are met and the reason is recorded durably.

A documentation-only/process-guidance Issue that changes no executable or package input is outside this development-path dimension and needs no `dev-path:*` label. In particular, documentation about Work-Path behavior does not itself justify `dev-path: work-branch`.

Preserve the selected development-path label after completion as useful implementation provenance. Do not apply both development-path labels at once. An Issue-less Hotfix has no Issue label to maintain; its path/provenance remains in the release history.

#### Status / special-case label

- `wontfix` — the item is deliberately not planned for implementation. Do not resume it without explicit user direction. It may coexist with a primary type label and may remain on a closed Issue as historical status.

GitHub Issue state reasons such as `completed`, `duplicate`, and `not_planned` are lifecycle state, not replacements for the label dimensions above while an Issue is open.

Do not invent new `priority:*` or `dev-path:*` values without updating this taxonomy and the corresponding process documentation in the same change.

After a successful product release that completes an Issue, close it as `completed`. For a documentation-only/process-guidance Issue that intentionally has no product release, close it as `completed` after the atomic documentation commit is verified on current `main`, and record that main SHA in the final Issue comment.

## Connector-specific operating notes

These notes describe the current ChatGPT GitHub connector, not a permanent repository property.

### ChatGPT runtime repository access: connector-first, clone-optional

For ChatGPT-managed repository work, the GitHub connector is the **primary and canonical repository transport**. A direct `git clone` from the execution/container runtime is only an optional convenience and must not be assumed to have outbound GitHub network access.

Use this procedure:

1. Read and pin current `main` SHA/tree through the GitHub connector before any implementation.
2. Read all required source, test, workflow and documentation files through the connector at that exact SHA.
3. Do **not** require a local clone in order to implement, validate or publish a change.
4. If a direct clone is attempted as an optimization and fails because runtime network access is unavailable, treat that as an environment limitation, not a repository failure:
   - do not repeatedly retry the clone;
   - do not change the canonical base;
   - do not fall back to stale local/source-ZIP state;
   - continue through the GitHub connector.
5. Prepare repository changes with GitHub Git objects:
   - create blobs for every intended changed file;
   - create one tree based on the pinned current `main` tree;
   - create one commit with the pinned current `main` commit as parent;
   - inspect the complete commit/diff before creating any visible Candidate ref.
6. Re-read `main` immediately before exposing the Candidate branch. If `main` advanced, stop and rebuild/reconcile the candidate from the new canonical `main`; never force the stale candidate onto the new base.
7. Use `candidate/v<version>` only after the exact candidate commit is complete and inspected. Its candidate-only history must carry exactly one `Work-Branch:` trailer as defined below so the release can safely clean durable work state. Candidate Preflight then performs the authoritative repository-wide Linux validation and GitHub-hosted Windows PowerShell 5.1 validation on that exact SHA.
8. For documentation-only changes that do not touch product/runtime/release inputs, use the same connector-first reads and lease check, then make one atomic documentation commit directly on current `main` as allowed by the documentation-only policy.

Local/container checks built from connector-fetched files may be used as focused prechecks, but they are **not** a substitute for the repository-wide Candidate/Release gates and must not be reported as such. Conversely, lack of a local clone must not block a valid implementation or release when the connector and GitHub workflows provide the required canonical reads, Git-object writes and authoritative tests.

This is the preferred recovery path for the recurring ChatGPT-runtime condition where direct GitHub cloning is unavailable.

### Repository archive / ZIP materialization limitation

The current connector may provide file/ref/Git-object operations without providing a general repository archive/zipball materialization action. This is an execution-tool limitation, **not a work-branch limitation**.

A `work/**` branch is a normal Git ref and is not inherently less cloneable/downloadable than `main`. The limitation becomes more visible during work-branch development only because the newest intermediate tree exists on GitHub and a local full worktree would be convenient for repository-wide build/validation.

If repository-archive materialization is unavailable and direct container GitHub access also fails:

- do not repeatedly try clone/ZIP/archive variants;
- do not interpret the failure as a repository or branch defect;
- do not fall back to a stale Source ZIP;
- stay connector-first for canonical reads/writes;
- prefer a GitHub-hosted workflow for operations that genuinely need a full worktree;
- record any resulting precheck limitation rather than compensating with increasingly elaborate ad-hoc reconstruction.

LBS-17/v0.8.0.0 established this rule: the connector had no general archive action and the container could not resolve `github.com`; neither condition was caused by `work/LBS-17`.

### Branch deletion and release-owned work-branch cleanup

The currently available ChatGPT GitHub connector can create/read/move branch refs but does not expose a general delete-branch/delete-ref action. **Normal release cleanup must therefore be owned by GitHub Actions, not by the interactive connector.**

Candidate provenance is mandatory:

- Major/Minor Candidates require exactly one unique `Work-Branch: work/LBS-<issue>` trailer;
- Patch/Hotfix Candidates default to exactly one `Work-Branch: none` trailer;
- a Patch/Hotfix may declare `Work-Branch: work/LBS-<issue>` only after a pre-implementation effort/risk escalation and must then also contain exactly one unique `Work-Branch-Reason: <reason>` trailer;
- same-candidate correction commits may omit the trailers, but they must not introduce conflicting values;
- Candidate Preflight verifies the release-level policy, the declared branch, and exact Candidate/work-tree equality.

After successful publication/merge, the Release Orchestrator owns cleanup:

1. it re-reads the declared `work/LBS-*` branch;
2. it compares that branch's current tree with the released Candidate tree again;
3. only an exact tree match may be deleted;
4. if the branch advanced or diverged, deletion fails closed and the branch is preserved;
5. `tools/release_verification.py` requires the declared work branch to be absent before emitting `RELEASE_VERIFICATION_SUMMARY=... PASS`.

This makes a work branch durable recovery state **during development** and disposable state **only after its exact content has been published successfully**. Never force-delete an advanced work branch merely to satisfy cleanup.

Other consequences remain:

- Do not create throwaway documentation/feature branches unless a workflow/merge path owns their cleanup.
- Temporary `candidate/**` branches are deleted server-side after successful promotion.
- Temporary `release/**` branches are deleted by the publication merge path.
- A branch push made by a GitHub Actions job with `GITHUB_TOKEN` does not normally trigger another workflow. Cross-workflow promotion therefore uses explicit `workflow_dispatch`; do not rely on recursive push triggering.
- A stale branch must never be reused merely to avoid creating a new branch.

### Work-Path rolling recovery comment

Work-Path development maintains exactly one cumulative recovery comment in the active Issue.

Operational contract:

1. Prefer the implementation-start comment and update that same comment in place.
2. While `Agent-State: ACTIVE`, update it often enough that `Last heartbeat` is never more than approximately **3 minutes old**.
3. Do not overwrite history with only the latest three-minute delta. The comment must cumulatively retain the complete Build & Release lifecycle: SHAs, checkpoints, decisions, successes, failures, test/gate results, timings, Actions runs, Candidate/Release history, open risks and exact next action.
4. If no new finding exists, a minimal liveness refresh is allowed; otherwise the latest engineering findings belong in the same update.
5. Use `WAITING_FOR_GITHUB` only with an exact run ID that is independently `queued` or `in_progress`; use `IDLE`/`STOPPED` when no interactive work is continuing.
6. Serialize comment writes and avoid redundant mutative GitHub calls.
7. Product/checkpoint commits remain source-history events. **Do not create Git commits solely for heartbeat timing.**
8. Legacy `.chatgpt-work/LBS-<issue>.md` files on already-active branches must be absorbed into the rolling comment and removed before Candidate creation; do not create new ones.
9. After Candidate exposure, Candidate/Actions/Release state is the canonical recovery surface. Continue using the rolling Issue comment for cumulative supervision/timing, but do not mutate the work branch after the exact Candidate tree has been exposed.

A stale `ACTIVE` heartbeat older than roughly three minutes is a missed heartbeat. A heartbeat older than roughly five minutes indicates stopped interactive progress only after any referenced GitHub Actions run has been checked directly.

## Documentation-only changes

A documentation-only change that does not alter product/runtime/release inputs does not require a product version bump or release package.

Classify this scope **before** choosing a development path. If the complete repository diff is Markdown/process documentation only and does not change product source, tests, workflows, validators, build/release tooling, machine-consumed release inputs, or package contents:

- do not create `work/LBS-*`;
- do not create a Candidate or Release;
- do not modify `bin/version.json` or add a release `CHANGELOG.md` section;
- do not apply a `dev-path:*` label to the Issue;
- prefer one atomic docs commit directly on freshly re-read `main`;
- inspect the unreferenced commit/diff before moving `main`;
- close the Issue after the new main SHA is verified, with a final documentation-completion comment.

The document's subject does not change this classification. A tiny edit to Work-Branch, Candidate, or Release guidance is still documentation-only if it changes no executable contract.

**Hard rule: no executable source/code change → no `work/LBS-*` branch.** Here, source/code includes product source, tests, workflows, validators, tools/scripts, and other machine-enforced executable repository contracts. Markdown/documentation and GitHub Issue metadata do not qualify. When the intended diff is documentation/Issue metadata only, creating a Work-Branch is a process error and must be corrected before implementation continues.

Do not describe such a documentation update as a product release.

## Repository and GitHub documentation language

English is the canonical language for repository and durable GitHub documentation.

### Machine-consumed documentation markers

Release/build tooling must not depend on stale localized documentation markers.

If a README heading, marker, or other documentation string is consumed by tooling and that string is renamed or translated, the consuming tooling and its permanent regression coverage must be updated in the **same candidate**. A documentation-language migration is not complete while release tooling still searches for the previous localized marker.

The canonical README version marker is:

`**Current development version:**`

`tools/prepare_release.py` must use this English marker. The legacy German marker `Aktueller Entwicklungsstand` is forbidden in active release tooling and is protected by permanent Release/Regression gates.

This rule was established by the v0.6.8.0 / LBS-18 Candidate Preflight finding: the first candidate was correctly blocked because the README had already been translated while `prepare_release.py` still searched for the German marker. The correction was made on the same candidate branch before release promotion.


- Every tracked `*.md` file must use English prose, including files under `docs/**`, `tests/**`, `tests-history/**`, `README.md`, `CHANGELOG.md`, and `downloads/README.md`.
- New Markdown files must be written in English.
- GitHub Issue bodies/comments, Pull Request descriptions, release notes, workflow-facing explanations, and other durable project documentation must use English.
- Exact technical literals may remain unchanged where required: identifiers, function/type names, paths, commands, JSON/schema names, status contexts, task names, GUIDs, hashes, version numbers, event/error codes, and exact UI strings intentionally quoted as literals.
- When a German UI label must be referenced for compatibility/history, keep it as a clearly delimited literal while the surrounding prose remains English.
- Interactive chat with the user is separate from repository language policy and may remain in German with established English technical terminology.

The permanent Markdown-language validation is a practical guard against accidental reintroduction of German prose. It deliberately ignores fenced code, inline code, and clearly delimited literal UI text so that compatibility examples remain possible.

## GitHub-only continuity policy

Do not create or require cross-chat handover documents, knowledge-only ZIPs, or chat summaries as a project-continuity mechanism. They create a second, potentially stale state outside GitHub and are therefore outside the canonical project model.

A fresh engineering session starts from `docs/INITIAL_PROMPT.md` on current `main` and reconstructs the complete working state from the repository, current Issues/comments, executable workflows/tests, tags, release metadata, and other durable GitHub evidence.

If an external diagnostic file, native test result, or interactive discussion establishes a fact that matters beyond the current session, distill that fact into GitHub immediately: use an Issue/comment for backlog or acceptance evidence, documentation for durable operating/architecture rules, and code/tests/workflows for executable contracts. The external artifact may remain supporting evidence, but it must never be the only durable record.

Release ZIPs and Source ZIPs remain publication artifacts; they are not substitutes for the canonical GitHub development state.

## Final reporting

A release report should distinguish:

- what was implemented;
- which automated GitHub gates passed;
- exact version, PR, `main` SHA and source-tag commit;
- release ZIP size/SHA-256;
- whether candidate, release, and declared work branches were removed;
- whether the implementation Issue was closed;
- which native Windows tests were actually executed versus only represented by source/static contracts.

Prefer the verified `RELEASE_VERIFICATION_SUMMARY` as the single source for aggregated post-release facts instead of reconstructing them through multiple connector calls.

Never claim a test, branch deletion, release artifact or workflow state that was not directly verified.
