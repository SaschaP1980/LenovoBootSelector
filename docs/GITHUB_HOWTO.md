# GitHub How-To for Lenovo Boot Selector

This document is the operational playbook for ChatGPT when maintaining and publishing **Lenovo Boot Selector** with the user.

It combines the durable project rules from the project handover with lessons verified during real GitHub releases, especially v0.6.3.0.

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
2. Add the corresponding `CHANGELOG.md` section.
3. Choose the release profile intentionally.
4. Product/source changes normally use `patch`.
5. `version-only` is for a release whose product source is otherwise unchanged.
6. Do not use the historical `release-architecture` profile by default.

## Fresh-worktree rule

Build and validation must operate from a fresh, known repository state based on current `main`/the intended release head.

Do not silently fall back to an old local source ZIP when GitHub access is inconvenient.

For Python release tooling use no-bytecode mode:

- `python -B ...`
- `PYTHONDONTWRITEBYTECODE=1` for child processes/workflows

The exact source tag must contain neither ZIP files nor `__pycache__`/`.pyc` artifacts.

## Runtime module closure — mandatory when adding a module

Lenovo Boot Selector is modular in source but published as a deterministic single-file PowerShell runtime.

A new runtime module is not integrated merely because the template contains an include marker.

For every new module that becomes part of the runtime, verify **both**:

1. `src/App/LenovoBootMenuTray.template.ps1` contains exactly one matching `# @include <path>`.
2. `tools/build_runtime.py::INCLUDES` contains the same module exactly once and in the intended order.

Then run the runtime builder/preparation path and verify that no unresolved include marker remains.

### Why this rule exists

The first v0.6.3.0 publication attempt (GitHub Actions run #17) failed before the permanent gates because `UpdateTransport.ps1` was added to the template but not to the static `INCLUDES` list in `tools/build_runtime.py`.

The observed failure was:

`RuntimeError: unresolved include marker remains`

No PR, tag or release was created by that failed attempt. The same release branch was corrected and the next normal push produced successful run #18.

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

## Canonical publication model

For a product build:

`1 build = 1 release branch = 1 PR = 1 merge`

Use:

`release/v<version>`

Do not manually add the new historical release ZIP to the branch. The Release Orchestrator builds and adds it.

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

## GitHub Issues / backlog discipline

GitHub Issues are the backlog.

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
- If a stale branch must be deleted and no delete action is available, report that limitation rather than pretending it was removed.
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
- whether the release branch was removed;
- whether the implementation Issue was closed;
- which native Windows tests were actually executed versus only represented by source/static contracts.

Never claim a test, branch deletion, release artifact or workflow state that was not directly verified.
