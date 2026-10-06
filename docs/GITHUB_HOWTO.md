# GitHub How-To

## Bootstrap for a new chat

The canonical one-line entry point for a completely new chat is `docs/INITIAL_PROMPT.md`. If the user only points to that file, the new chat must execute the complete bootstrap described there and then read this guide and the other current contracts.

When a new chat takes over development, a build, a Hotfix, or a GitHub release for Lenovo Boot Selector, it must **not** act directly from conversation memory or an old handover. It must first reconstruct the current canonical repository state.

Mandatory order:

1. **Read current `main` and record its SHA/tree.**
2. **Read this `docs/GITHUB_HOWTO.md` in full from current `main`.**
3. **Read `docs/RELEASE_PROCESS.md` in full.**
4. For Issue-backed work, read the **current GitHub Issue** including state, labels, comments, and acceptance criteria.
5. Read **`bin/version.json`** and verify current version, `releaseProfile`, `protectedFragmentIntent`, and `repositoryDeleteIntent`.
6. Read the relevant executable contracts:
   - `.github/workflows/candidate-preflight.yml`
   - `.github/workflows/release.yml`
   - `tools/candidate_preflight.py`
   - `tools/release_verification.py`
   - the four permanent validators under `tests/`
7. Only then determine scope, target version, and implementation/release plan and prepare changes.

### Authority order

When information conflicts:

1. current GitHub `main`, including executable workflows/tools;
2. current normative documents `docs/GITHUB_HOWTO.md` and `docs/RELEASE_PROCESS.md`;
3. current GitHub Issues and their comments;
4. handover documents and chat history.

A handover is an **onboarding aid, not the source of truth**. Before any actual change, the new chat must verify the current GitHub state again.

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
3. Current GitHub Issues for backlog/status.
4. A transition handover or prior chat summary.

A handover is context, not an excuse to override newer repository facts.

Never use a stale feature branch as a development basis merely because it still exists. The canonical development basis is GitHub `main`, unless the user explicitly names another verified branch.

## Living-document maintenance — mandatory

This operational GitHub guide is a **living project artifact** and must be kept current.

Whenever work reveals a new durable fact about the GitHub integration, repository publishing behavior, release workflow, connector capabilities/limitations, recovery procedure, validation contract or another operational GitHub rule, update `docs/GITHUB_HOWTO.md` in the same workstream as soon as that fact is established.

Likewise, whenever the GitHub integration or its release/operating process is intentionally changed, update this guide so that it describes the new behavior rather than preserving an obsolete procedure.

Do not rely on chat memory or a handover alone for such knowledge. Durable GitHub-operating knowledge belongs here.

Before finalizing any handover, first read the current `docs/GITHUB_HOWTO.md` from canonical `main`. **Every handover must include the complete latest contents of this guide**, not a summary, excerpt or stale copy. The handover may add release-specific context around it, but it must not omit or replace the current guide.

If the guide changes after a handover draft was created, regenerate/update the handover so the embedded copy matches the current canonical guide before delivering it.

## Source of truth

- `main` is the canonical development basis.
- `bin/version.json` is the only authoritative release version input.
- GitHub Issues are the only authoritative backlog. Do not maintain a competing local backlog.
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

From v0.6.5.0 onward, the ordered `# @include <path>` markers in `src/App/LenovoBootMenuTray.template.ps1` are the **only runtime-module registry**. `tools/build_runtime.py` discovers the include list directly from the template; there is no second static `INCLUDES` list to keep in sync.

For every new runtime module:

1. add exactly one `# @include <path>` marker at the intended position in the template;
2. ensure the path is a relative `src/**/*.ps1` file and exists;
3. run the runtime builder/preflight.

The builder fails on duplicate markers, unsafe/invalid paths, missing files, unresolved include markers or an unresolved version token.

### Why this rule exists

The first v0.6.3.0 publication attempt (GitHub Actions run #17) failed because `UpdateTransport.ps1` existed in the template but was omitted from the former static `tools/build_runtime.py::INCLUDES` registry. v0.6.5.0 removes that double bookkeeping entirely.

## Pre-publication validation

Before pushing the release branch, perform as much of the same preparation as GitHub will perform.

At minimum:

1. Verify runtime generation/closure.
2. Run `tools/prepare_release.py` with a **provisional** UTC timestamp for local validation only.
3. Run the four permanent validators:
   - `tests/validate_release.py`
   - `tests/validate_core.py`
   - `tests/validate_boundary.py`
   - `tests/validate_regression.py`
4. Check the intended diff against the previous canonical basis.
5. Check that unrelated runtime assets/security boundaries did not change.

GitHub owns the canonical `publishedUtc`; a local timestamp is never the publication timestamp.

If native Windows/PowerShell/WinForms tests have not actually been executed on Windows, never report them as passed. Static/source-contract coverage is not a substitute for a native pass.

## Candidate-tree preflight before release branch creation

From v0.6.5.0 onward, a product release enters GitHub through a temporary **`candidate/v<version>`** branch, not directly through `release/v<version>`.

The exact candidate SHA is processed by `.github/workflows/candidate-preflight.yml`. The workflow:

1. verifies the candidate branch/version pairing and current `main` ancestry;
2. checks that the target release branch/tag do not already exist;
3. materializes the immediately previous canonical source tag as the regression basis;
4. runs `tools/candidate_preflight.py`;
5. performs deterministic preparation and two byte-identical provisional builds;
6. runs Release/Core/Boundary/Regression;
7. validates protected-fragment intent and repository-delete intent;
8. rejects any pre-publication modification of historical `downloads/*.zip`;
9. writes commit status `preflight/candidate=success`;
10. only then creates `release/v<version>` on **the identical SHA**;
11. explicitly dispatches `release.yml` for that ref;
12. deletes the temporary candidate branch.

The explicit dispatch is required because GitHub deliberately prevents a normal push performed with `GITHUB_TOKEN` from recursively starting another workflow. `workflow_dispatch` is the supported handoff. If dispatch fails, Candidate Preflight overwrites its status to failure and deletes the just-created release branch again.

The Release Orchestrator independently requires that exact SHA to carry a successful `preflight/candidate` status and that current `origin/main` is still its ancestor. A manually created or stale release branch therefore fails closed.

If Candidate Preflight fails, **no release branch exists yet**. Keep the same `candidate/v<version>` branch, apply the minimal fast-forward correction, and let the normal push rerun the preflight. Do not create a parallel candidate or release branch.

### Protected-fragment intent is release-specific

`bin/version.json` carries `protectedFragmentIntent`, an explicit list of protected fragment keys intentionally changed by that version.

The protection inventory still comes from the canonical characterization baseline, but change detection compares the prepared candidate with the **immediately previous canonical source tag**. The required invariant is exact set equality:

`actual protected changes == protectedFragmentIntent`

Undeclared protected changes fail. Stale/extra declarations fail. If no protected fragment changes, the list is empty.

The former permanent `INTENTIONALLY_CHANGED_FROZEN` bypass is removed. A function that was intentionally changed in an earlier release is fully protected again in the next release.

### Repository deletion intent

`bin/version.json` also carries `repositoryDeleteIntent`. Candidate Preflight compares all repository deletions against this exact list and rejects undeclared or stale deletion intent. Historical release ZIPs may not be changed by the candidate at all.

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
2. **Atomic candidate preparation:** create all intended blobs, one tree and one candidate commit; inspect that commit once before exposing `candidate/v<version>`.
3. **Candidate observation:** perform one initial run lookup. Do not tight-poll. When the run is terminal, read run/jobs/logs together where possible and consume `CANDIDATE_PREFLIGHT_SUMMARY=<json>`.
4. **Release observation:** after dispatch, avoid re-reading unchanged candidate facts. On terminal success, consume the single `RELEASE_VERIFICATION_SUMMARY=<json>` emitted by the Release Orchestrator.
5. **Issue completion:** use the verified summary for the release facts, add the final Issue comment and close the Issue. Do not repeat individual PR/tag/status/latest/ZIP/source-tree reads merely to reconstruct facts already verified in the summary.

`tools/release_verification.py` performs the complete server-side post-release aggregation after the merge. It verifies the merged PR, exactly one publication PR, 8/8 release statuses, candidate preflight status, annotated source tag/commit, ZIP-/cache-free source tree, `downloads/latest.json`, published release ZIP size/hash, candidate/release branch cleanup and the prior reproducibility marker.

The structured summary is an **aggregation of completed checks**, not a replacement for them. If the workflow is not terminal success, the summary is missing, `result != PASS`, or a requested fact is absent, fall back to the full direct post-release checklist below.

The practical target for a small conflict-free patch, once code is ready and runners are available, is roughly **2–3 minutes of interactive orchestration**, while GitHub still executes all existing gates.

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

Every open Issue should carry exactly one priority label from the repository's canonical priority taxonomy:

- `priority: critical` — active severe defect or security/safety boundary violation requiring immediate attention; release-blocking when applicable.
- `priority: high` — high-impact correctness/security/architecture risk that should be addressed ahead of normal enhancements, but is not an active critical failure.
- `priority: medium` — meaningful product/release/process improvement with clear value but no immediate safety or availability impact.
- `priority: low` — parked, evidence-dependent, cosmetic, explicitly non-urgent or currently `wontfix` work.

Priority is independent of type/status labels such as `enhancement` or `wontfix`; preserve those labels. Reassess priority whenever an Issue's evidence, scope, risk or implementation status materially changes.

After a successful release that completes an Issue, close it as `completed`.

## Connector-specific operating notes

These notes describe the current ChatGPT GitHub connector, not a permanent repository property.

### Branch deletion limitation

The currently available connector can create/read/move branch refs but does not expose a general delete-branch/delete-ref action.

Consequences:

- Do not create throwaway documentation/feature branches unless a workflow/merge path will delete them.
- The v0.6.5.0 Candidate Preflight is an intentional exception: its temporary `candidate/**` branch is deleted server-side by the GitHub workflow after successful promotion, so it does not depend on a connector delete-ref action.
- A branch push made by a GitHub Actions job with `GITHUB_TOKEN` does not normally trigger another workflow. Cross-workflow promotion therefore uses explicit `workflow_dispatch`; do not rely on recursive push triggering.
- If another stale branch must be deleted and no workflow owns its cleanup, report the connector limitation rather than pretending it was removed.
- A stale branch must never be reused merely to avoid creating a new branch.

### Atomic Git-object preparation

When a local clone is unavailable, it is possible to prepare a change safely with GitHub Git objects:

1. Create blobs for all intended files.
2. Create one tree based on the verified current base tree.
3. Create one commit with the verified current parent.
4. Inspect that commit/diff.
5. Only then move/create the visible branch ref.

This prevents exposing partially assembled repository state.

## Documentation-only changes

A documentation-only change that does not alter product/runtime/release inputs does not require a product version bump or release package.

Prefer an atomic docs commit on current `main` when creating a temporary branch would leave an undeletable stale ref through the connector.

Do not describe such a documentation update as a product release.

## Repository and GitHub documentation language

English is the canonical language for repository and durable GitHub documentation.

- Every tracked `*.md` file must use English prose, including files under `docs/**`, `tests/**`, `tests-history/**`, `README.md`, `CHANGELOG.md`, and `downloads/README.md`.
- New Markdown files must be written in English.
- GitHub Issue bodies/comments, Pull Request descriptions, release notes, workflow-facing explanations, and other durable project documentation must use English.
- Exact technical literals may remain unchanged where required: identifiers, function/type names, paths, commands, JSON/schema names, status contexts, task names, GUIDs, hashes, version numbers, event/error codes, and exact UI strings intentionally quoted as literals.
- When a German UI label must be referenced for compatibility/history, keep it as a clearly delimited literal while the surrounding prose remains English.
- Interactive chat with the user is separate from repository language policy and may remain in German with established English technical terminology.

The permanent Markdown-language validation is a practical guard against accidental reintroduction of German prose. It deliberately ignores fenced code, inline code, and clearly delimited literal UI text so that compatibility examples remain possible.

## Handover artifact policy

For ordinary hotfix/patch releases, successful GitHub publication is normally sufficient; do not manufacture extra chat artifacts unless requested.

For a minor/major transition where a future conversation needs substantial context, additionally produce a **knowledge-only handover ZIP**. It must not duplicate Source ZIPs or release binaries.

**Mandatory for every handover, regardless of release type or handover format:** include the complete current `docs/GITHUB_HOWTO.md` from canonical `main` in its latest version. Do not substitute a summary or an older embedded copy. Read the canonical guide immediately before final handover assembly and verify that the included copy is identical/current.

If new GitHub integration knowledge or a GitHub-process change is discovered while preparing the handover, update `docs/GITHUB_HOWTO.md` first, then include that updated canonical version in the handover.

A handover should record durable rules and current state, but the next session must still verify current GitHub facts before acting.

## Final reporting

A release report should distinguish:

- what was implemented;
- which automated GitHub gates passed;
- exact version, PR, `main` SHA and source-tag commit;
- release ZIP size/SHA-256;
- whether candidate and release branches were removed;
- whether the implementation Issue was closed;
- which native Windows tests were actually executed versus only represented by source/static contracts.

Prefer the verified `RELEASE_VERIFICATION_SUMMARY` as the single source for aggregated post-release facts instead of reconstructing them through multiple connector calls.

Never claim a test, branch deletion, release artifact or workflow state that was not directly verified.
