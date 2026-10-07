# Lenovo Boot Selector – Initial Prompt

> **Single entry point for a new chat**
>
> If the user starts a new chat with only:
>
> `Read https://github.com/SaschaP1980/LenovoBootSelector/tree/main/docs/INITIAL_PROMPT.md`
>
> treat this file as an **instruction to perform the complete project bootstrap**. Read it in full and execute the steps below immediately. Do not ask the user to restate prior chat history, release rules, or architecture.

## 1. Assignment and repository

Repository:

`SaschaP1980/LenovoBootSelector`

Always work from the **current GitHub `main`** and current GitHub project state. Previous chats, chat summaries, model memory, local checkouts, source ZIPs, or off-repository transition artifacts are neither required nor authoritative.

If a GitHub connector is available, use it for repository, Issue, Pull Request, workflow, and commit work. Repository changes must be guarded against the current state; on concurrent changes, do not guess or overwrite blindly.

## 2. Bootstrap – always execute first

Before planning or implementing a product change:

1. Read the current `main` commit, including SHA and tree.
2. Read this file from the current `main`.
3. Read **in full**:
   - `docs/GITHUB_HOWTO.md`
   - `docs/RELEASE_PROCESS.md`
   - `docs/DEVELOPMENT_GUIDELINES.md`
   - `tests/README.md`
   - `bin/version.json`
4. Read the executable release contracts:
   - `.github/workflows/candidate-preflight.yml`
   - `.github/workflows/windows-powershell51.yml`
   - `.github/workflows/release.yml`
   - `tools/candidate_preflight.py`
   - `tools/release_verification.py`
   - `tests/validate_release.py`
   - `tests/validate_core.py`
   - `tests/validate_boundary.py`
   - `tests/validate_regression.py`
5. If the user names an LBS Issue, Issue number, or concrete planned feature, read the **current GitHub Issue in full**, including state, labels, comments, and acceptance criteria.
6. Before implementation, verify whether `main` advanced since the initial snapshot. If it did, refresh the basis.
7. Only then classify the change scope **before** choosing a development path:
   - documentation-only/process-guidance change;
   - executable product/release/tooling change.
8. Only for executable/product release work determine target version, release profile, development path, and concrete file set.

If the user only asks you to read this file and has not yet provided a concrete task, perform the complete bootstrap and then report briefly:
- current `main` SHA;
- current version;
- whether the release path is consistently readable;
- that you are ready to work.

Do **not** pick an arbitrary backlog item on your own when the user has not provided a scope.

## 3. Authority order

When information conflicts, use this precedence from strongest to weakest:

1. current GitHub `main`, especially executable workflows, tools, and validators;
2. current normative documents `docs/GITHUB_HOWTO.md`, `docs/RELEASE_PROCESS.md`, and `docs/DEVELOPMENT_GUIDELINES.md`;
3. current GitHub Issues including comments and acceptance evidence.

No previous chat, model memory, handover artifact, local file, or prior source ZIP participates in the authority order. If durable project knowledge is needed for future work but is not represented in GitHub, treat that as an incomplete project record and capture it in the appropriate repository document, Issue/comment, test, workflow, or source change before relying on it.

## 4. User-command semantics

The normal project contract is that user commands such as:

- **“Implementiere …”**
- **“Baue …”**
- **“Baue die nächste Version …”**

mean, unless the user explicitly says otherwise:

**analyze → for confirmed bugs/regressions prove focused RED first → implement → prove GREEN → prepare release-ready candidate → Candidate Preflight → GitHub release → PR/merge → post-release verification → Issue completion.**

Do not ask separately whether the project should be built or published after the user has already clearly said “Implementiere” or “Baue”.

A pure analysis/planning request without build authorization is excluded from this rule.

A **documentation-only/process-guidance implementation** is also excluded from the automatic product build/release interpretation. If the complete repository change is limited to Markdown/process documentation and GitHub Issue metadata, and it does not change product source, tests, workflows, validators, build/release tooling, machine-consumed release inputs, or package contents, then:

- do not assign a product version;
- do not create a Candidate or Release;
- do not create a `work/LBS-*` branch merely because the documentation describes Work-Path behavior;
- do not assign a `dev-path:*` label, because no product implementation path is being selected;
- use one atomic documentation commit directly on freshly verified `main` after inspecting the exact diff.

The **subject matter** of a document does not determine the development path. A small documentation change about Work-Branch policy is still documentation-only work.

**Hard rule:** **No executable source/code change → no `work/LBS-*` branch.** For this rule, executable source/code includes product source, tests, workflows, validators, build/release tools, scripts, and other machine-enforced repository artifacts. Markdown/documentation and GitHub Issue metadata are not source/code. If the complete intended diff contains only documentation/Issue metadata, a Work-Branch is prohibited.

### Engineering design baseline

Use `docs/DEVELOPMENT_GUIDELINES.md` as the canonical design guidance. Favor Clean Code and SOLID with clear responsibility boundaries, cohesive modules, explicit dependencies, and testable behavior. Apply DRY pragmatically: deduplicate the same rule/knowledge/responsibility, not merely similar-looking code. When responsibilities, reasons to change, lifecycles, safety constraints, or failure semantics differ, keep the implementations separate even if limited duplication remains. Prefer small explicit duplication over a false abstraction that couples unrelated concerns.

## 5. Versioning and Issue rules

Version format:

`MAJOR.MINOR.PATCH.HOTFIX`

Before implementation, first apply the documentation-only scope rule above. Only executable/product release work proceeds to version-level and development-path selection.

For **MAJOR and MINOR** product work, follow the persistent work-branch/checkpoint model in `docs/DEVELOPMENT_GUIDELINES.md`.

For **PATCH and HOTFIX**, default to the shortest safe branchless atomic path. Before implementation, perform a brief effort/risk analysis. Escalate to the work-branch/checkpoint model only when that analysis shows the work is likely to be substantial, cross-cutting, migration-heavy, interruption-prone, or otherwise likely to require several recoverable checkpoints. Record the exception reason durably and carry it into the Candidate as `Work-Branch-Reason:`.

For a normal branchless Patch/Hotfix, do not create a chain of intermediate commits: establish focused RED evidence against the unfixed basis, prepare the complete fix atomically, require focused GREEN plus directly relevant syntax/encoding/determinism checks, then expose one release-ready Candidate. Do not run the full test matrix before every commit; full authoritative validation belongs at the Candidate/Release gates. Reuse permanent validators instead of duplicating their assertions with ad-hoc connector checks.

When a `work/LBS-*` Work-Path is selected, use the established continuation model in `docs/DEVELOPMENT_GUIDELINES.md`: maintain coherent product checkpoints plus `.chatgpt-work/LBS-<issue>.md`; keep an `ACTIVE` heartbeat no more than approximately three minutes old; use `WAITING_FOR_GITHUB` only with an exact independently running Actions run; and treat a roughly five-minute stale heartbeat with no running workflow as a stopped interactive stream. The observed practical heartbeat cost is on the order of **~5%** for a representative larger Work-Path task and is an accepted resilience budget; do not apply it to the normal small Patch/Hotfix fast path. A fresh session must re-read current `main`, the Issue, work-branch head, latest product checkpoint and journal before continuing, then directly verify any referenced Actions run.

- **MAJOR:** a relevant GitHub Issue is mandatory.
- **MINOR:** a relevant GitHub Issue is mandatory.
- **PATCH:** a relevant GitHub Issue is mandatory.
- **HOTFIX:** an Issue is optional when the change is a narrow, clearly bounded correction and no existing Issue already covers it.

If a released defect is a direct regression or incomplete implementation of an existing Issue, **reopen the original Issue**, document root cause and Hotfix plan, reassess priority, and close it as `completed` only after the corrective release succeeds.

Open Issues should carry exactly one `priority:*` label. For Issue-backed **product/release implementation**, select exactly one `dev-path:*` label during the pre-implementation path decision; backlog Issues and documentation-only/process-guidance Issues do not require a development-path label. The canonical label taxonomy is defined in `docs/GITHUB_HOWTO.md`.

## 6. Release profiles

There are only two active release profiles:

### `version-only`

Use when product code under `src/**` is unchanged.

Regression requires strict product-source identity to the previous canonical source basis, apart from the deterministically injected version.

### `patch`

Use when product code under `src/**` changes functionally.

The historical `release-architecture` profile has been removed and must not be reintroduced as an active profile.

## 7. Required files for every published version

Every version that is actually published requires, **before the candidate**:

1. the new version in `bin/version.json`;
2. a matching section in `CHANGELOG.md`.

This explicitly includes:

- a pure version bump;
- a `version-only` Hotfix;
- a pipeline/performance measurement;
- a release with no functional product change.

A request for a “Hotfix that only increments the version” therefore technically means at least:

`bin/version.json + matching minimal CHANGELOG.md section`

`tools/prepare_release.py` enforces this contract.

Also keep these fields in `bin/version.json` accurate:

- `protectedFragmentIntent`
- `repositoryDeleteIntent`

The normal value for both is `[]`. Never hide intentionally changed protected fragments or repository deletions.

## 8. Product safety boundaries

These are hard boundaries and must not be weakened incidentally:

- The tray application runs unelevated.
- Privileged operations use only fixed, allowlisted SYSTEM Scheduled Tasks.
- No arbitrary command text, task names, GUIDs, Boot#### numbers, Device Paths, or other uncontrolled values may cross the privilege boundary.
- Boot changes are **One-Shot Next Boot** only.
- Never permanently mutate `{fwbootmgr} displayorder` or UEFI `BootOrder`.
- Do not introduce an arbitrary custom SYSTEM EXE as a privilege channel.
- Do not add PnP/device-arrival handlers or polling as the USB-detection architecture.
- Do not claim a physical USB→firmware mapping without defensible read-only evidence.
- Preserve BootService, TaskBroker, and Storage boundaries.
- The self-updater remains user-controlled, unelevated, and without automatic download/install behavior.

On security/privilege uncertainty, **fail closed**.

### Test-first defect workflow

For every confirmed bug or regression, follow **failing test first, not failing candidate first**:

1. add the smallest focused permanent regression test that captures the intended corrected behavior;
2. run that test against the current unfixed canonical basis and confirm that it is RED for the expected bug-specific reason;
3. when the work is Issue-backed, record the base SHA, failing test and relevant failure reason in the Issue; for an Issue-less Hotfix, retain equivalent durable evidence in the release/changelog audit trail;
4. only then implement the smallest product fix;
5. rerun the same regression test and require it to be GREEN;
6. run the appropriate broader prechecks before preparing the Candidate.

The RED proof should use the narrowest test/validator environment capable of reproducing the defect against the canonical basis. It does **not** require a Candidate branch or Candidate Preflight.

A Candidate is a **release-ready state expected to pass all mandatory gates**. Do not intentionally publish a known-broken Candidate merely to obtain RED evidence. Candidate failures are reserved for unexpected integration/gate findings; if one occurs, use the existing same-branch correction procedure below.

## 9. Atomic candidate preparation

Normal release entry model:

`1 exact candidate SHA = 1 release branch = 1 PR = 1 merge`

Before exposing a visible branch ref:

1. verify current `main` SHA/tree;
2. prepare all intended file changes completely;
3. create the blobs;
4. create one tree based on the verified `main`;
5. create one candidate commit;
6. inspect the candidate commit/diff once in full;
7. only then create `candidate/v<version>` at that exact SHA.

Do not publish partially assembled intermediate states. The exact Candidate must already be release-ready: all intended implementation, regression coverage, focused RED→GREEN evidence, release metadata and applicable prechecks are complete before the Candidate ref is exposed.

For a Work-Path Candidate, first complete the final **Development Completion review** defined in `docs/DEVELOPMENT_GUIDELINES.md`: exhaust the permanent checks that are executable before Candidate exposure, perform the ownership/parser integration sweep, and run the existing manually dispatchable hosted Windows PowerShell 5.1 workflow against the exact final Work-Branch revision. Record any tooling limitation explicitly; do not invent substitute evidence. Only after that review is green for every executable check should the temporary journal be removed and the Candidate be created as a clean current-`main`-parent commit whose tree exactly equals the cleaned work tree. Temporary journal/checkpoint history must not become Candidate ancestry. After the Candidate is exposed, Candidate/Actions/Release state—not a recreated journal—is the canonical recovery surface.

For normal releases, **never create `release/v<version>` manually**. Only a successful Candidate Preflight may create it.

## 10. Candidate Preflight

`.github/workflows/candidate-preflight.yml` is the release-entry gate.

From v0.6.9.0 onward, one candidate push starts two mandatory paths in parallel on the same exact SHA:

### Linux Candidate Preflight

The `ubuntu-latest` job verifies:

- the exact candidate SHA;
- current `main` as a valid basis;
- the previous canonical source tag;
- deterministic release preparation;
- two byte-identical builds;
- Release/Core/Boundary/Regression;
- exact `protectedFragmentIntent`;
- exact `repositoryDeleteIntent`;
- no change to historical release ZIPs;
- Runtime Closure/build contracts.

It emits `CANDIDATE_PREFLIGHT_SUMMARY=<json>` and writes `preflight/linux`.

### Windows PowerShell 5.1 Gate

The reusable `.github/workflows/windows-powershell51.yml` runs on a fresh GitHub-hosted `windows-2025` runner. It:

- checks out the same exact SHA;
- explicitly verifies Windows PowerShell 5.1;
- deterministically regenerates and checks the runtime;
- runs `tests/Test-WindowsPowerShell51.ps1`;
- emits `WINDOWS_POWERSHELL51_SUMMARY=<json>` with suite totals and timing data;
- writes `preflight/windows-powershell51`.

### Promotion

A separate promotion job depends on both candidate jobs. It revalidates their latest statuses on the same exact SHA, verifies the candidate ref has not moved and current `main` is still an ancestor, then:

1. emits `CANDIDATE_TIMING_SUMMARY=<json>`;
2. writes `preflight/candidate=success`;
3. creates `release/v<version>` at the **same SHA**;
4. explicitly starts `release.yml` through `workflow_dispatch`;
5. deletes the candidate branch.

The explicit dispatch is required because a push performed with `GITHUB_TOKEN` does not reliably trigger a recursive follow-up workflow.

The permanent LBS-20 policy is **always mandatory** for Major, Minor, Patch, and Hotfix releases. The v0.6.9.0 production benchmark kept the complete candidate-to-release cycle at about 90 seconds, so the additional Windows coverage was judged worth the measured critical-path cost. Any later policy change must be explicit, deterministic, tested, and documented.

### Candidate failures

A Candidate failure is an **unexpected validation/integration finding**, not a planned test-first RED step.

If either mandatory candidate job fails:

- there must not yet be a normal release;
- read the exact job log for the cause;
- apply the smallest correction as a fast-forward on the **same candidate branch**;
- do not create a parallel candidate or release branch;
- let the normal push rerun both required paths.

## 11. Release Orchestrator

`.github/workflows/release.yml` is the publication authority.

It first requires:

- successful `preflight/candidate` status;
- successful `preflight/linux` status;
- successful `preflight/windows-powershell51` status;
- current `main` as an ancestor;
- a not-yet-existing target tag.

Then it:

1. captures GitHub-owned `publishedUtc`;
2. builds release + source packages deterministically;
3. performs a second independent build;
4. compares both outputs byte-for-byte;
5. reruns permanent Release/Core/Boundary/Regression gates;
6. derives the exact ZIP/cache-free source commit;
7. adds exactly one new historical release ZIP;
8. creates the publication commit on the release branch;
9. writes release status contexts to the final PR head;
10. creates exactly one PR;
11. creates the annotated source tag;
12. sets `release/tag`;
13. merges the PR and deletes the release branch;
14. performs complete post-release verification.

Historical `downloads/*.zip` files are **immutable**. A release may add exactly one new ZIP; existing ZIPs must not be modified or deleted.

## 12. The eight release gates

The final PR head must have exactly these eight successful release contexts:

- `release/source-integrity`
- `release/core`
- `release/boundary`
- `release/regression`
- `release/package`
- `release/reproducibility`
- `release/history`
- `release/tag`

A green workflow alone is not sufficient evidence; the eight contexts are part of the release contract.

## 13. Aggregated post-release verification

LBS-16 introduced `tools/release_verification.py` to aggregate final verification.

A successful release emits:

`RELEASE_VERIFICATION_SUMMARY=<json>`

The summary confirms, among other things:

- version;
- candidate SHA;
- successful Candidate Preflight;
- final PR head;
- exactly one publication PR;
- PR number and merge commit;
- `main` SHA after merge;
- source tag and source commit;
- 8/8 release gates;
- release ZIP name, size, and SHA-256;
- source ZIP name, size, and SHA-256;
- ZIP-free source tree;
- cache-free source tree;
- candidate branch deleted;
- release branch deleted;
- consistent `downloads/latest.json`;
- consistent published release ZIP;
- successful reproducibility check;
- successful historical ZIP integrity check.

When the workflow is terminal `success` and `RELEASE_VERIFICATION_SUMMARY.result == "PASS"`, use that aggregated data as the verified final facts. Do not reconstruct the same facts again through many redundant connector requests.

If the summary is missing, incomplete, or not PASS, use the full direct post-release verification from `docs/GITHUB_HOWTO.md`.

## 14. Performance and roundtrip rules

Release safety is **never reduced for speed**.

Preferred orchestration:

- batch/parallelize initial reads;
- reuse immutable facts within the same SHA phase;
- prepare changes in one atomic candidate;
- do not poll aggressively;
- observe Candidate Preflight using the Linux summary, Windows summary, and `CANDIDATE_TIMING_SUMMARY` where relevant;
- remember that Linux and Windows candidate jobs run in parallel and promotion waits for both;
- observe the release using a terminal read + `RELEASE_VERIFICATION_SUMMARY`.

Target for a small, conflict-free release when GitHub runners are available: roughly **2–3 minutes of interactive orchestration time**. The measured pipeline itself can be substantially faster.

### Runner queue

If a GitHub-hosted runner has not been assigned after 60 seconds:

- report `EXTERNAL_QUEUE_WAIT`;
- do not cancel the workflow;
- do not retrigger it;
- do not push a no-op commit;
- do not create a second release branch;
- let GitHub continue;
- check terminal state later.

## 15. Release failures and recovery

A failed workflow is not a reason to start an unverified parallel release path.

For a correctable failure before irreversible publication side effects:

- read the exact failing gate/log;
- make the smallest correction;
- keep the intended existing branch/release path;
- do not create duplicate PRs, tags, or parallel release branches.

Executable workflows and `docs/GITHUB_HOWTO.md` take precedence for concrete recovery behavior.

## 16. Tests

The four permanent GitHub gates are:

- `tests/validate_release.py`
- `tests/validate_core.py`
- `tests/validate_boundary.py`
- `tests/validate_regression.py`

`tests/README.md` documents the active test matrix.

Historical validators are stored under `tests-history/` and are not part of active release selection.

### Windows and hardware test evidence

Windows/PowerShell-5.1 tests may be reported as **PASS** only when they were actually executed on Windows.

From v0.6.9.0 onward, the mandatory GitHub-hosted Windows gate executes `tests/Test-WindowsPowerShell51.ps1` on Windows PowerShell 5.1 and therefore counts as genuine Windows contract-suite execution.

It does **not** count as physical Lenovo hardware/UEFI E2E. Final reports must explicitly distinguish:

- automated Linux/GitHub static and release gates;
- GitHub-hosted Windows PowerShell 5.1 contract-suite results;
- physical Lenovo hardware/firmware tests actually executed;
- physical hardware tests that remain outstanding.

## 17. GitHub Issue lifecycle

For Issue-backed work:

1. read the Issue before implementation;
2. reconcile state/labels/acceptance criteria with current `main`;
3. document materially important root-cause/scope/migration findings in concise Issue comments;
4. keep the Issue open during implementation;
5. after successful publication and post-release verification, add a final comment with version and PR;
6. only then close it as `completed`.

A release is not successful merely because the Issue was closed; technical release verification comes first.

## 18. Documentation-only changes

A documentation/process-only change that does not alter product code, runtime, release inputs, or release packages does **not** require a product version bump or release.

When safe and conflict-free, it may be committed atomically directly to current `main`. Verify current `main` first and change only the intended documentation files.

## 19. Repository and GitHub language policy

English is the canonical language for **all repository and durable GitHub documentation**.

This includes:

- every tracked `*.md` file, including `docs/**`, `tests/**`, `tests-history/**`, `README.md`, `CHANGELOG.md`, and `downloads/README.md`;
- GitHub Issue bodies/comments, Pull Request descriptions, release notes, and durable development/process documentation;
- new documentation added in future work.

Technical literals remain unchanged when required: identifiers, function/type names, paths, commands, JSON/schema names, status contexts, task names, GUIDs, hashes, version numbers, event/error codes, and exact UI strings intentionally quoted as literals.

Interactive communication with the user is separate from this repository policy: **chat may remain in German while using established English technical terminology**, according to the user's preference.

Do not introduce new German prose into repository/GitHub documentation. When a change establishes a new durable rule, document that rule in English.

## 20. GitHub-only continuity rule

GitHub is the sole durable continuity mechanism for this project. No cross-chat handover document, knowledge ZIP, chat summary, or model memory is required to continue development.

This `INITIAL_PROMPT.md` is the bootstrap entry point for a fresh engineering session. It instructs the agent to reconstruct the current state from GitHub; it does not carry project state itself and does not replace rereading the current normative documents, Issues, workflows, tests, and release metadata.

Any durable finding discovered during interactive work must be recorded in GitHub before future work depends on it. Diagnostic files or chat discussion may provide evidence, but the resulting durable conclusion belongs in the appropriate Issue/comment, documentation, test, workflow, or source change.

## 21. Final report after a release

After complete implementation, report precisely:

- what was implemented;
- target version;
- Candidate/Release run;
- aggregate test results;
- PR;
- final `main` SHA;
- source tag/commit;
- release ZIP size + SHA-256;
- source ZIP SHA-256;
- candidate/release branch cleanup;
- Issue state;
- which native Windows tests were actually executed.

Do not claim any test, branch, hash, tag, or release fact without direct verification.

## 22. Behavior after this bootstrap

After reading this file and all referenced current sources:

- work according to the reconstructed current repository contract;
- do not ask the user to restate old rules;
- do not use or request a stale project version, prior-chat handover, or remembered project state;
- if the user subsequently says, for example, `Implementiere LBS-XX`, immediately reconcile the Issue and carry out the end-to-end implementation under this process;
- if a new real-world finding changes product knowledge or the durable GitHub/build/release process, record it in the appropriate canonical GitHub artifact so a completely fresh session can recover it without access to this chat.
