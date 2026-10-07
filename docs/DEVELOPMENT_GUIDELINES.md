# Development Guidelines

This document defines the durable development workflow for substantial Lenovo Boot Selector feature work.

It applies **by default to Major and Minor releases**.

### Scope classification comes before development-path selection

First decide whether the requested repository change is an executable/product change or a documentation-only/process-guidance change.

A change is **documentation-only** when its complete repository diff is limited to Markdown/process documentation and it does not change product source, tests, workflows, validators, build/release tooling, machine-consumed release inputs, or package contents.

Documentation-only work:

- does not receive a product version or release profile;
- does not create a Candidate or Release;
- does not use `work/LBS-*` merely because the document being edited describes Work-Path behavior;
- does not require a `dev-path:*` Issue label;
- should be prepared as one atomic documentation commit directly on freshly verified `main`, with the exact diff inspected before the ref moves.

The **subject of the documentation is not implementation complexity**. Editing Work-Branch or release guidance does not itself make a small documentation correction a Work-Branch change.

> **Hard rule: no executable source/code change → no Work-Branch.**

For this rule, **source/code** means any executable or machine-enforced repository implementation artifact: product source under `src/**`, tests, GitHub Actions workflows, validators, build/release tooling, scripts, or equivalent executable contracts. Markdown/documentation and GitHub Issue metadata do **not** count as source/code. If the complete intended change contains none of those executable/machine-enforced changes, `work/LBS-*` is forbidden regardless of topic, Issue priority, perceived importance, or the fact that the edited documentation governs the Work-Path itself.

Patch and Hotfix work uses the shortest safe atomic path **without a work branch by default**. Before implementation begins, perform a brief development-path decision. Work-Path is permitted only when either (a) effort/risk makes the change substantial, cross-cutting, migration-heavy, interruption-prone, or otherwise unlikely to fit safely into one short implementation cycle, or (b) the user explicitly authorizes a process-validation/benchmark exercise whose purpose is to exercise the complete Work-Path itself. Record the exact exception reason durably and carry it into the Candidate as exactly one `Work-Branch-Reason:` trailer.

A process-validation/benchmark exception is evidence about the development process, not evidence that the underlying product change is complex. Outside these two exception classes, do not route a small Patch/Hotfix through Work-Path merely for consistency or convenience.

The Work-Path rolling recovery comment defined below is the established resilience standard **only after a `work/LBS-*` path has already been selected**. It is not used for the normal branchless Patch/Hotfix fast path.

The release path remains defined by `docs/RELEASE_PROCESS.md`. Connector/GitHub operating details remain defined by `docs/GITHUB_HOWTO.md`.

## 1. Purpose

Long-running agentic development must survive chat, stream, runtime and connector interruptions without depending on transient context.

The core rule is:

> **No substantial completed work may exist only in the active agent session.**

GitHub is the durable continuation record.

For substantial feature work:

- the Issue owns **What / Why / Acceptance**;
- a dedicated work branch owns the **recoverable implementation state**;
- checkpoint commits own **How / Current state / Validation / Next step**;
- the Candidate remains **release-ready only**;
- the Release PR remains the only normal product merge into `main`.

### Engineering design principles: Clean Code, SOLID, and pragmatic DRY

Implementation work should optimize for **clear responsibilities, maintainability, testability, and explicit boundaries**. Clean Code and SOLID are the default design direction, but they are engineering heuristics rather than goals to satisfy mechanically.

Prefer:

- small, cohesive functions/modules with one clear responsibility and one primary reason to change;
- names that express domain intent instead of implementation mechanics;
- explicit dependencies and narrow interfaces;
- separation of domain/core logic from application workflow, infrastructure/IO, and UI concerns;
- extension through well-defined seams rather than unrelated conditionals spread across modules;
- abstractions that make ownership and behavior easier to understand, test, and change.

Apply the SOLID principles pragmatically:

- **Single Responsibility:** keep distinct responsibilities in distinct functions/modules even when some code looks similar.
- **Open/Closed:** prefer stable extension points where repeated variation is expected, but do not build speculative frameworks for hypothetical future use.
- **Liskov Substitution:** replacement implementations must preserve the behavioral contract expected by their callers.
- **Interface Segregation:** expose the smallest useful contract instead of broad interfaces that force consumers to depend on unrelated capabilities.
- **Dependency Inversion:** keep high-level product rules independent from concrete infrastructure where that separation materially improves testability, safety, or change isolation.

#### DRY is subordinate to responsibility boundaries

Use DRY to remove duplication of the **same knowledge, business rule, invariant, or responsibility**. Do not apply DRY merely because two code blocks currently look similar.

The governing rule is:

> **Same responsibility and same rule: prefer one canonical implementation. Different responsibilities or different reasons to change: keep them separate, even if some code is duplicated.**

In particular:

- do not merge Core, Application, Infrastructure, UI, TaskBroker, updater, storage, or other boundary-specific logic solely to eliminate superficial repetition;
- do not create a shared helper when its callers have different ownership, lifecycle, safety constraints, failure semantics, or likely future changes;
- prefer a small amount of obvious duplication over a premature or misleading abstraction that couples unrelated responsibilities;
- extract shared code when the common concept is stable and semantically identical, not merely syntactically similar;
- if an abstraction needs many mode flags, caller-specific branches, or knowledge of unrelated layers, reconsider whether the responsibilities should remain separate;
- canonicalize genuinely shared rules such as version comparison, locale resolution, release-level classification, schema validation, or another invariant that must behave identically everywhere.

**Responsibility boundaries outrank deduplication.** A future change that should be able to affect one path without affecting another is strong evidence that those paths do not share one responsibility and should not be forced through a common abstraction.

Clean Code/SOLID/DRY refactoring must not weaken the project's explicit safety boundaries, deterministic build/release contracts, PowerShell 5.1 compatibility, or fail-closed behavior. Avoid refactoring for stylistic purity when it increases coupling, indirection, migration risk, or cognitive load without a concrete maintenance benefit.

## 2. Work branch

### Selection gate

This gate applies only after the scope has been classified as executable/product release work. Documentation-only changes use the documentation policy above and never enter this selection gate.

Use a work branch when:

- the release is **Major or Minor**; or
- a **Patch or Hotfix** has been explicitly escalated by the pre-implementation effort/risk analysis; or
- a **Patch or Hotfix** is intentionally routed through Work-Path as an explicit user-authorized process-validation/benchmark exercise.

For Patch/Hotfix effort/risk escalation, indicators include multiple independently risky phases, settings/data migration, broad cross-module behavior changes, expected work substantially beyond a short atomic patch cycle, or a realistic need for several recoverable checkpoints. A narrow bug fix, text/UI correction, small validator change, isolated behavior patch, or version-only Hotfix should normally remain branchless unless the user explicitly requests the separate process-validation/benchmark exception.

For Issue-backed executable/product work, record the selected development model before implementation using exactly one mutually exclusive label from the canonical taxonomy in `docs/GITHUB_HOWTO.md`: `dev-path: work-branch` for this Work-Path model, or `dev-path: fast` for the branchless atomic Patch/Hotfix path. A backlog Issue may remain without a development-path label until this selection gate is actually performed. Documentation-only/process-guidance Issues remain outside this label dimension.

When a Patch/Hotfix uses Work-Path by exception, record the concise reason in the Issue when Issue-backed (or equivalent durable release history for an Issue-less Hotfix) and later include the same decision as `Work-Branch-Reason: <reason>` in the Candidate history. The reason must distinguish an effort/risk escalation from an explicit process-validation/benchmark exercise.

### GitHub Issue identity and Work-Branch naming

For this repository, **`LBS` is the project-specific Issue/branch prefix for Lenovo Boot Selector**.

For every newly created actionable project Issue, the numeric component is the **GitHub Issue number itself**. Do not maintain or search for a separate free LBS sequence.

Canonical forms:

- GitHub Issue `#90` -> Issue title prefix `[LBS-90]`;
- Work-Path branch -> `work/LBS-90`;
- Candidate provenance -> `Work-Branch: work/LBS-90`.

Because GitHub assigns the Issue number only after creation, use this two-step creation flow:

1. create the Issue with the intended descriptive title/body/labels;
2. read the returned GitHub Issue number;
3. immediately rename the Issue to `[LBS-<github-issue-number>] <descriptive title>` before implementation starts;
4. if Work-Path is selected, use that same GitHub Issue number in the work branch and Candidate provenance.

Do not infer another numeric namespace and do not scan for an unused LBS number. The GitHub Issue number is the single numeric identity for new work.

Historical Issues that predate this convention may retain older independent LBS identifiers (for example GitHub Issue `#88` titled `[LBS-41] ...`). They remain valid historical evidence and are not retroactively renumbered. New work must use the GitHub-number convention above.

### Patch/Hotfix atomic fast path

For a Patch/Hotfix that is **not** routed to a work branch, prefer one short atomic development cycle:

1. pin current `main`;
2. for a confirmed bug/regression, reproduce it and establish the focused RED regression against the unfixed canonical basis; for a non-bug change, define the smallest focused positive acceptance/validation check instead;
3. prepare the complete source/test/documentation/release-metadata change in memory/Git objects without creating a chain of visible intermediate commits;
4. run the defect-specific GREEN regression or the focused positive validation, plus the smallest relevant syntax/encoding/determinism checks;
5. create **one unreferenced candidate commit** from the pinned `main`;
6. inspect the complete candidate diff/scope once;
7. re-read `main` and expose `candidate/v<version>` only if the base lease still holds.

Do not create a durable RED commit merely to prove test-first work for a normal branchless bug/regression Hotfix. Durable RED evidence belongs in the Issue/release audit trail; non-bug changes do not invent artificial RED evidence. The Candidate itself remains release-ready only.

If the work can no longer fit safely in this atomic path because scope or duration grows materially, stop before accumulating many intermediate commits and explicitly reconsider whether the Patch/Hotfix should be escalated to the work-branch model.

Create the selected work branch from a freshly verified current `main`:

`work/LBS-<github-issue-number>`

Example for GitHub Issue `#90`:

`work/LBS-90`

The number is the GitHub Issue number under the naming contract above; it is not a separate project sequence.

Rules:

1. Pin the current `main` SHA/tree before creating the branch.
2. Do not reuse a stale work branch from earlier work.
3. One work branch belongs to one Issue/scope.
4. Never use `candidate/v<version>` as an intermediate checkpoint branch.
5. Re-read `main` before final Candidate preparation. If `main` advanced, reconcile deliberately; never force a stale work state over it.
6. After a successful release, the Release Orchestrator owns tree-verified work-branch deletion. Do not keep or manually fast-forward a completed work branch merely because the interactive connector cannot delete refs.

## 3. Product-decision gate before implementation

No release level may silently invent user-facing policy where the Issue leaves a material ambiguity. This decision gate applies to Major, Minor, Patch, and Hotfix work whenever the change can affect user state, defaults, migration, destructive behavior, compatibility/fallback semantics, persistence, security, or safety.

Before implementation, resolve and record any decision that changes existing user state or defaults, including:

- migrations;
- default values;
- destructive or irreversible behavior;
- compatibility/fallback behavior;
- persistence semantics;
- security/safety interpretation.

If the expected product behavior is genuinely ambiguous, ask the user before coding.

Tests can faithfully protect an implemented policy while that policy is still wrong for the intended product behavior. Resolve material product-policy ambiguity before coding rather than relying on tests to discover the decision later.

## 4. Checkpoints are persistence gates, not stop points

A checkpoint is a coherent, recoverable development state.

A checkpoint is **not required to have the complete repository test matrix GREEN**. Its purpose is durable recovery, not release qualification. A checkpoint may intentionally contain a known RED focused regression, an intermediate migration state, or a phase for which some broader/native tests have not yet run, as long as the commit body states the validation status honestly.

**Checkpoint != stop point.**

After a successful checkpoint is persisted, continue the same user-authorized task automatically unless:

- a real product/architecture decision requires user input;
- a new finding materially changes agreed scope;
- a safety/security decision cannot be made from existing contracts;
- the environment cannot continue safely.

Do not return to the user merely because a checkpoint was created.

### Checkpoint cadence

Target a durable checkpoint before more than about **10–15 minutes of substantive completed work** can exist only in transient agent context.

Also checkpoint before a long/high-risk tool sequence when the immediately completed state is coherent enough to persist.

Do not create checkpoints mechanically every few minutes. Merge adjacent tiny phases; split phases that are likely to exceed the resilience window.

### Checkpoint cost and frequency

Checkpoint frequency is a **resilience requirement**. Do not reduce the number of useful checkpoints merely because remote persistence or validation is expensive. The correct optimization target is the technical cost of producing a checkpoint.

For a normal checkpoint, target no more than about **1–2 minutes of agent/connector orchestration overhead after the substantive implementation is complete**, excluding the actual runtime of tests and external GitHub-runner queue time.

Focused validation that belongs to the just-completed implementation phase should normally run **before or as part of that checkpoint**, not be accumulated into a late pre-Development-Completion validation project. In particular, if the phase introduced a new focused self-test/smoke and it is runnable in the current environment, run it before calling that phase validated.

A checkpoint must not become a separate mini-build project. In particular:

- do not run the complete Release/Core/Boundary/Regression/native matrix before every checkpoint commit;
- run only the focused checks needed to prove that the checkpoint is coherent enough for its stated phase;
- do not manually reconstruct the generated single-file runtime through large connector string transformations;
- do not repeat permanent validator logic with ad-hoc remote reads once the repository already owns the corresponding executable check;
- do not create a second metadata-only commit with the same tree merely to label an implementation commit as a checkpoint;
- do not trade away checkpoint frequency to hide expensive tooling;
- prefer moving build and standardized validation to a full-worktree GitHub-hosted workflow.

The resilience objective is that an unexpected chat termination, stream disconnect, connector interruption, or agent-runtime stop loses at most the coherent work completed since the latest durable checkpoint.

### One checkpoint commit per gate

Prefer **one commit that contains both the implementation state and the checkpoint body**.

Do not normally create:

1. an implementation commit;
2. move the work branch;
3. validate;
4. create a second metadata-only checkpoint commit with the same tree.

That doubles Git/ref work without adding source value.

If validation cannot finish before the resilience window, split the phase into smaller coherent checkpoint commits instead.

### Required checkpoint body

A checkpoint commit should contain at least:

- Issue / target version;
- canonical start or current reconciled `main` SHA;
- checkpoint/phase name;
- completed work;
- validation actually executed and its result;
- tests not yet executed (especially native Windows);
- open work;
- next action;
- blockers/decisions, if any.

A fresh agent should be able to read the Issue and latest work-branch checkpoint and continue without the previous chat.

### Work-Path rolling recovery comment

This mechanism applies **only** to development that already uses a durable `work/LBS-<github-issue-number>` branch. Major/Minor work and explicitly escalated Patch/Hotfix work use it; the normal branchless Patch/Hotfix fast path does not.

Maintain exactly **one rolling recovery comment** in the active GitHub Issue. Prefer the implementation-start comment and update that same comment in place. Do not create a new heartbeat comment every interval.

Use [`docs/templates/WORK_PATH_ROLLING_COMMENT.md`](templates/WORK_PATH_ROLLING_COMMENT.md) as the canonical default layout: a compact recovery-state header, explicit intended diff and validation plan, one cumulative measurement ledger, counters, phase-specific evidence, final release verification, performance result, and plan-conformance assessment. Historical Issue comments are evidence, not normative templates; the tracked template and current process documents define the standard.

The layout is part of the recovery standard, not merely presentation. Preserve the same major sections unless a task-specific section adds useful recovery information. At successful completion, update this **same** rolling comment to `Agent-State: COMPLETED`, record the authoritative release/PR/main/tag/artifact/cleanup facts, set the next action to Issue closure, and then close the Issue. Do not add a second redundant completion comment when the terminal rolling-comment update already contains the required final implementation/release record.

#### Canonical in-place section updates

Treat the rolling comment as a mutable canonical ledger, not an append-only transcript.

- Keep exactly one unnumbered block for each singleton lifecycle section defined by the template, including `Candidate Entry`, `Release`, `Final Release Verification`, `Performance result`, and `Plan-conformance assessment`.
- Update a singleton block **in place** as its state changes. For example, when Candidate Entry moves from `BLOCKED` to `PASS`, replace the existing Candidate Entry state/details; do not append a second Candidate Entry block and leave the stale `BLOCKED` block behind.
- Keep exactly one block per numbered attempt. `Development Completion attempt 1` and `Candidate #1` may transition from queued/in-progress to PASS/FAIL by replacing that attempt's current fields. Create a new numbered block only for an actual new attempt/revision.
- Keep exactly one `Release` block for the release attempt state. Update `pending` / `in_progress` fields to the terminal run/result instead of appending another `Release` heading.
- Preserve prior **attempt evidence**, corrections, and failure classifications, but consolidate the current state of the same attempt/phase rather than preserving stale intermediate status text.
- At terminal completion, no completed phase may still say `pending`, `in progress`, or `not started`. The recovery-state header must also reflect terminal branch state truthfully, including deleted Work/Candidate/Release refs where applicable.
- Populate every applicable final-verification field from authoritative GitHub evidence, including PR number, merge timestamp, final `main`, source tag/commit, artifact hashes/sizes, status totals, reproducibility/integrity, and branch cleanup. Do not omit a template field merely because the same fact appears elsewhere in the comment.
- Before closing the Issue, perform one final structural pass over the complete rolling comment: singleton headings occur once, numbered attempts are unique by number, no stale terminal-state contradictions remain, and the header/measurement ledger/final verification agree on the final facts.

These rules govern **ledger maintenance**, not deployment semantics. A malformed or duplicated rolling-comment section does not retroactively invalidate a machine-verified GREEN deployment, but it is a Development Guideline conformance defect and must be corrected before Issue closure when still possible.

The rolling comment and a product checkpoint have different responsibilities:

- a **product checkpoint** is a coherent recoverable source state on `work/LBS-<github-issue-number>` and may include focused validation;
- the **rolling recovery comment** is the **canonical cumulative Build & Release ledger** for the complete Work-Path lifecycle: implementation, Development Completion, Candidate correction, Release, recovery, timing, and retrospective evidence.

The rolling comment must remain sufficient for a fresh session to continue without reconstructing prior chat. It is not private chain-of-thought. Keep concise but complete durable facts such as:

- base `main`, current work head and last product checkpoint SHA;
- target version, release profile and development-path reason;
- current phase, `Agent-State`, exact next action and open risks;
- architecture decisions and safety constraints;
- every product checkpoint with purpose/result;
- experiments attempted, failures and why approaches were rejected;
- test/validator findings and corrections;
- Development Completion evidence and unavailable-capability/tooling gaps;
- exact GitHub Actions run IDs, tested SHA, totals and timings;
- Candidate history, including every PASS/FAIL and correction cause;
- Release/PR/tag/artifact verification;
- wall-clock and gate timing measurements used for pilot comparisons.

#### Heartbeat cadence and stale interpretation

While the interactive agent is actively working on a Work-Path task, cadence is **time-based, not event-based**.

- With `Agent-State: ACTIVE`, the rolling comment's `Last heartbeat` must not become more than approximately **3 minutes old**.
- Every update is cumulative: retain prior Build & Release evidence and add/refresh the newest recovery-relevant information.
- A finding, decision, failed experiment, checkpoint or gate result is the preferred heartbeat payload.
- If no new recovery-relevant information exists when the interval expires, update the same comment with a minimal truthful liveness statement; do not create a Git commit merely for the timer.
- Update immediately before a potentially long/high-risk tool sequence when the next action matters for recovery.
- Serialize mutative GitHub writes; do not parallelize heartbeat/comment mutations.

The active cadence may pause only when:

- `Agent-State: WAITING_FOR_GITHUB` names an exact independently running Actions run;
- `Agent-State: BLOCKED_EXTERNAL` names a verified external GitHub/service outage or unavailable write path and records the last confirmed repository SHA/state; or
- `Agent-State: IDLE` / `STOPPED` truthfully states that interactive work is not continuing; or
- `Agent-State: COMPLETED` is used only after the requested Work-Path lifecycle has completed and final release verification is PASS.

`BLOCKED_EXTERNAL` is not a development failure. Do not spam retries, create no-op commits, or create alternate branches to work around an external outage. If the rolling-comment write path itself is unavailable, do not claim a heartbeat was persisted; update the ledger immediately after write capability is independently confirmed.

When a referenced workflow completes, an external block clears, or interactive work otherwise resumes, set `Agent-State: ACTIVE` and immediately resume the maximum-three-minute cadence.

Interpretation:

- a recent `ACTIVE` timestamp means the interactive agent was active at that recorded point;
- an `ACTIVE` heartbeat older than roughly **3 minutes** is a missed heartbeat;
- when the latest heartbeat is older than roughly **5 minutes** and no referenced Actions run is `queued` or `in_progress`, treat the interactive stream as stopped and resume from durable GitHub state;
- when `WAITING_FOR_GITHUB` references a live run, GitHub automation may continue independently even if the chat stream stops.

On recovery, re-read current `main`, the Issue including the rolling recovery comment, the `work/LBS-<github-issue-number>` head and the latest product checkpoint before continuing. Re-check referenced Actions runs directly.

#### Timing ledger

The rolling comment must preserve both raw wall-clock history and normalized process timing. Keep these categories separate when they occur:

- active implementation time;
- checkpoint/orchestration overhead;
- Development Completion queue time and execution time;
- Candidate queue, execution, and correction time;
- Release queue and execution time;
- external infrastructure outage time;
- user/interactive pause time;
- chat/runtime timeout and recovery time.

Never subtract external/user/timeout delays from the **raw** total; retain them as part of the chronology.

Do not invent or normalize away a missing start timestamp. A user-authorized start may be recorded as authoritative only when the interaction/runtime provides an exact observed timestamp. If it is unavailable, mark it unavailable or approximate; **do not substitute `issue.created_at` and label that as the user-authorized start**.

Use distinct timing classes:

- **raw durable GitHub end-to-end** — for Issue-backed work, `Issue created_at → authoritative Release Verification summary`; do not subtract pauses or outages;
- **raw user-authorized end-to-end** — only when an exact user-authorization timestamp is actually observed;
- **normalized repository-process time** — raw chronology minus only independently verified external-infrastructure, user/interactive, or chat/runtime interruption intervals. List every excluded interval. If those intervals cannot be quantified reliably, report normalized time as unavailable rather than guessing.

For process comparisons, also report at least:

- Issue creation → authoritative Release Verification summary;
- first Development Completion request → authoritative Release Verification summary for Work-Path runs;
- first Candidate creation → authoritative Release Verification summary;
- final GREEN Candidate creation → authoritative Release Verification summary;
- Release run creation → authoritative Release Verification summary;
- number of failed Candidate revisions/correction loops;
- cause classification for every unexpected Candidate failure.

This separation prevents external outages or session interruptions from being misreported as repository-development performance.

Tracked `.chatgpt-work/LBS-<github-issue-number>.md` files are **legacy only**. Do not create them for new work. If an already-active branch contains one, first absorb all recovery-relevant state into the rolling Issue comment, then remove the legacy file **before the final release-ready Work tree is frozen for Development Completion**.

#### Candidate cleanup and history isolation

The final exact Work tree qualified by Development Completion must already be free of legacy recovery files and contain only intended release content.

Before the final `Development-Completion: requested` commit:

1. absorb/remove any legacy `.chatgpt-work/LBS-<github-issue-number>.md`;
2. verify the cleaned work-branch tree contains only intended release content;
3. re-read and reconcile current `main`;
4. recompute any evidence invalidated by that reconciliation;
5. create the tree-identical qualification request commit and run Development Completion on that exact cleaned tree.

After `Candidate-Entry: PASS` is recorded for that frozen Work SHA, do **not** mutate the Work branch before Candidate creation. Any Work-tree change after qualification makes the exact-SHA Development Completion evidence stale and requires a new request/evaluation before Candidate exposure.

Create the release-ready Candidate as a **single clean commit whose parent is current `main` and whose tree exactly equals the frozen, cleaned Work tree**. Work-branch checkpoint history must not become Candidate ancestry. After Candidate exposure, Candidate/Actions/Release state is the canonical recovery surface; continue updating the rolling Issue comment, but do not recreate legacy recovery files or mutate the Work branch.


## 5. Stream/session resilience

There is no reliable warning before an interactive stream/session stops.

Therefore:

- do not hold a large finished change only in tool memory;
- do not assume work continues between user turns;
- when asked whether work is still running, verify GitHub refs/commit timestamps and relevant Actions runs instead of inferring activity from conversation text;
- after any unexpected interruption, re-read `main`, the work-branch head and the rolling Issue recovery comment before continuing;
- use the rolling-comment heartbeat plus direct GitHub Actions state to distinguish a dead interactive stream from independently running GitHub automation;
- never claim that background development continued when no automation/workflow was actually running.

## 6. Connector-call budget and atomic Git writes

A single orchestration/code-mode block must not try to perform an unbounded sequence of connector operations.

Use bounded phases:

1. read and pin refs/tree;
2. fetch the necessary files;
3. transform locally in memory;
4. create blobs in small batches;
5. create one tree;
6. create one checkpoint commit;
7. re-read the branch ref;
8. move the ref with a lease/expected SHA when supported;
9. verify the resulting ref.

As a conservative operating rule, keep one orchestration block to a small number of nested GitHub actions (typically about **5–8**) rather than attempting dozens of reads/writes in one block.

If an orchestration call aborts:

- assume partial side effects are possible;
- re-read the branch and `main` first;
- do not blindly replay the whole write sequence;
- unreferenced blobs/trees/commits are not authoritative project state.

## 7. Repository archive / ZIP and clone limitations

### This is not work-branch-specific

A work branch does **not** inherently prevent cloning, ZIP download, materialization, or normal Git operations.

A connector/runtime environment may lack repository archive materialization or direct GitHub network access even though normal GitHub ref/file/Git-object operations remain available. Treat that as an execution-environment limitation, not a Git or work-branch property.


### Required behavior

If the connector has no repository-archive action and direct clone/network access is unavailable:

1. **do not repeatedly probe clone/ZIP/archive routes**;
2. do not treat this as a repository failure;
3. do not fall back to an old Source ZIP;
4. continue connector-first for canonical file/ref/Git-object work;
5. prefer repository-hosted GitHub Actions for operations that genuinely require a complete worktree.

The repository's hosted **Development Completion gate** is the required full-worktree qualification path for the exact final Work-Branch SHA. It is a final Candidate-entry qualification gate, not a mandatory full-matrix runner for every routine checkpoint.

If a local full worktree is unavailable during ordinary checkpoint work, persist a coherent recoverable source checkpoint and record full-worktree qualification as pending rather than emulating the repository through ad-hoc connector assertions. This is acceptable checkpoint state only. Before Candidate exposure, the final exact SHA must satisfy the mandatory Candidate-entry contract; if no truthful full-worktree execution path exists, Candidate Entry is `BLOCKED`.

## 8. Generated runtime handling

The tracked single-file runtime must remain deterministic.

### Version-only Work-Path pre-Development-Completion checklist

A deliberately minimal `releaseProfile: version-only` Hotfix routed through the Work-Path must enter its **first** hosted Development Completion request with all deterministic version-bearing tracked artifacts already synchronized. Development Completion is a qualification gate, not a generation/canonicalization step.

For the current repository contract, the release-ready Work tree for a pure version-only change must contain exactly these five pre-Candidate changes:

- `bin/version.json` — authoritative version bump;
- `CHANGELOG.md` — mandatory minimal version section;
- `bin/LenovoBootMenuTray.ps1` — deterministic generated runtime with the injected version;
- `audits/CATCH_AUDIT.json` — deterministic catch-audit metadata with the current version;
- `docs/architecture/ARCHITECTURE_BASELINE.json` — deterministic architecture baseline with the current version.

Before creating the tree-identical `Development-Completion: requested` commit:

1. synchronize those three deterministic generated/version-bearing artifacts from the new authoritative version;
2. run or truthfully reproduce the repository-owned runtime, catch-audit, and architecture-baseline deterministic checks on the exact Work tree;
3. inspect the complete Work diff and require the expected five-file scope;
4. treat any additional pre-Candidate file as a scope anomaly requiring explicit review.

Do **not** manually add Release-Orchestrator-owned publication outputs such as `README.md`, `bin/BUILD_INTEGRITY.txt`, `downloads/latest.json`, `downloads/releases.json`, `downloads/README.md`, or historical release ZIPs to the Work tree merely to complete a version-only Hotfix.

This five-file scope is the current version-only Work-Path invariant. Development Completion qualifies that already synchronized tree; it does not repair or canonicalize stale generated state.

Do not manually patch `bin/LenovoBootMenuTray.ps1` through a long chain of ad-hoc incremental text replacements when the repository build tool can define the composition authoritatively.

Preferred order:

1. edit canonical modular source/template;
2. use the repository's deterministic runtime-build semantics;
3. validate runtime closure;
4. persist the coherent result.

If a full local worktree is unavailable, prefer a GitHub-hosted full-worktree validation/build path over manual reconstruction.

For routine work-branch checkpoints, edit the canonical modular source and persist only coherent recoverable states. A checkpoint may honestly record deterministic runtime regeneration or full-worktree validation as pending; it must not be labeled synchronized/GREEN when tracked generated output is stale.

Development Completion is an exact-SHA qualification gate and must not mutate or canonicalize source/generated files as part of qualifying the requested Work SHA.

Before Candidate creation, tracked runtime state must match canonical source and the mandatory Development Completion/Candidate Entry checks must PASS on the exact frozen Work SHA.

When text composition is unavoidable in JavaScript tooling, treat PowerShell `$` characters as data. Do not use the replacement-string form of JavaScript `String.replace()` for generated PowerShell content because `$` sequences have replacement semantics. Use a literal-safe method such as `split/join` or a replacement callback.

## 9. Avoid unreferenced staging-commit chains

Git blobs/trees are useful for atomic preparation, but do not turn every partial runtime step into another unreferenced Git commit.

Use:

- blobs as temporary assembly objects;
- at most one temporary tree/commit when it materially helps inspection;
- one referenced checkpoint commit for the coherent phase.

Temporary Git objects may support atomic assembly, but chains of unreferenced staging commits are not the normal target process and must never become the durable recovery model.

## 10. Validation hierarchy before Candidate

The Candidate is expected GREEN.

### Commit validation versus Candidate validation

Do **not** use the rule "every commit requires every test suite to be GREEN."

Use validation proportional to the Git object's role:

- **RED-evidence state:** the focused regression is expected to fail for the defect-specific reason.
- **Work-branch checkpoint:** run the focused checks needed to establish a coherent recoverable phase; broader/native suites may remain pending and must be recorded honestly.
- **Branchless Patch/Hotfix candidate preparation:** require the same focused test that proved RED to be GREEN, plus directly relevant syntax/encoding/determinism smoke checks before exposing the Candidate. The authoritative full repository integration matrix begins at Candidate Preflight for this deliberately lightweight path unless a separate contract makes a precheck mandatory.
- **Work-Path Candidate preparation:** require `Candidate-Entry: PASS` from the final exact-SHA Development Completion contract before exposing the Candidate.
- **Release-ready Candidate:** after the path-specific preparation above, the Candidate is expected GREEN; GitHub Candidate Preflight then reruns the authoritative Linux and Windows PowerShell 5.1 gates on the exact exposed SHA.
- **Release:** the Release Orchestrator reruns the publication/reproducibility/status gates as defense in depth.

The full repository matrix does **not** run before every persistence commit. For Work-Path releases, final Development Completion runs the mandatory Linux Candidate-entry validator set plus hosted Windows PowerShell 5.1 evidence on the exact Work SHA. Candidate Preflight reruns the authoritative Linux and hosted Windows release-entry gates on the exposed Candidate SHA. Release automation reruns the publication-side deterministic/permanent validators and release integrity/reproducibility gates as defense in depth; it is not described as rerunning the complete hosted Windows Candidate suite. For the branchless fast path, Candidate Preflight remains the first full integration matrix by design.

### Test ownership and redundancy

Prefer the **lowest existing permanent test layer that directly proves the behavior**. Add a second test layer only when it protects a meaningfully different risk.

Once a repository invariant is owned by a permanent executable test or validator:

- execute that test/validator instead of reconstructing the same assertion with multiple connector reads;
- do not add an issue-specific validator that merely duplicates existing Functional Core/native/integration coverage;
- do not assert exact documentation wording, capitalization, punctuation, or implementation-detail strings unless the text is itself a machine-consumed compatibility contract;
- do not keep both ad-hoc structural checks and a permanent regression when they prove the same fact.

A new permanent regression should normally encode behavior or a stable architectural invariant, not incidental source spelling.

Hand-written structural checks are useful focused prechecks, but they must not be mistaken for the actual repository validators.

### Safe transformation and diff-anomaly rule

Automated text transformation of executable or machine-consumed files is itself a development risk.

For PowerShell, YAML/workflows, Python, JSON, or other executable/machine-consumed content:

- prefer structure-aware editing or literal/function-based replacement over replacement-string semantics that interpret metacharacters;
- never assume characters such as PowerShell `$`, regex escapes, backreferences, YAML indentation, or JSON quoting survive an unverified generic replacement;
- inspect the exact per-file diff immediately after a transformation and before persisting the checkpoint;
- treat unexpectedly large line-count changes, duplicated blocks, unrelated hunks, or scope outside the intended files as a **hard stop**;
- on an anomalous transformation, discard/rebuild the affected file from the last verified canonical basis instead of incrementally repairing an untrusted transformed copy;
- run the cheapest applicable parser/syntax/encoding check before checkpointing when such a check is available.

A checkpoint must never be justified only by “the replacement command succeeded”; the resulting diff is the evidence.

### Focused validation planning

Focused validation is part of implementation design, not a final release-preparation task.

As soon as the intended executable/tooling scope is known, identify for every changed behavior/control path:

- the canonical implementation owner;
- the focused validation owner that can execute the changed path;
- whether that validation path already exists and is non-destructive;
- whether a new focused smoke/self-test is required;
- when that smoke will be executed relative to the checkpoint that introduces it.

For changed Python validators, release/build tools, workflow helpers, or similar executable tooling expected to run during Development Completion, Candidate Preflight, or Release:

1. define the focused runtime path **before or together with the implementation change**;
2. prefer, in order:
   - the real non-destructive CLI against the current worktree;
   - an existing focused consumer/test that executes the changed callable/control path;
   - only then a narrow new `--self-test` / smoke harness;
3. if a new smoke/harness is required, implement it in the **same coherent implementation phase/checkpoint** as the executable change it validates whenever practical;
4. execute a newly created or materially changed smoke **immediately after implementing it and before treating that phase as validated** when the current environment can run it;
5. do not defer designing the smoke until release metadata, final reconciliation, or Development Completion preparation;
6. if the smoke cannot yet run, the checkpoint may still be persisted for resilience only when it records `runtime smoke pending/BLOCKED`; it must not be described as validation-complete or release-ready.

A newly added smoke/self-test is itself executable code. Apply the same transformation/diff-anomaly discipline to it:

- inspect the helper body and call path after extraction/refactoring;
- reject empty, self-recursive, disconnected, duplicated, or assertion-free helper bodies unless that structure is explicitly intended and tested;
- run the new smoke itself before relying on it as evidence;
- never infer correctness merely because the smoke option/function exists in source.

This rule minimizes late validation-harness construction and prevents the validation mechanism itself from becoming the last-minute source of Development Completion failures.

### Python runtime-binding smoke rule

A Python parser/syntax check proves only that the file can be parsed. It does **not** prove that names are bound in the correct order, that a changed function/CLI path can execute, or that runtime imports/locals used by the changed path exist.

When a change modifies a Python validator, release/build tool, workflow helper, or other Python path that is expected to execute during Development Completion, Candidate Preflight, or Release:

- use the focused runtime path selected during Focused Validation Planning; do not invent it only at final release preparation unless new evidence makes the earlier plan invalid;
- before the **first hosted Development Completion request** for that Work tree, execute at least one focused runtime path that reaches the changed code;
- prefer the script's real non-destructive CLI against the current worktree when available;
- otherwise use an existing focused consumer/test, or add/use a narrow `--self-test` / smoke entrypoint that exercises the changed binding/control path without publication side effects;
- for imported helpers, importing the module alone is insufficient when the defect could exist inside a function body; exercise the changed callable through its focused owner;
- `python -m py_compile`, AST parsing, lint/source inspection, or import-only success may accompany the runtime smoke but **cannot substitute for it**;
- record the command/test and PASS result in the rolling Issue ledger before creating the first `Development-Completion: requested` commit;
- if no safe focused runtime path can be executed, the first hosted Development Completion request is **BLOCKED** until such a path exists or the exact dependency closure can be executed truthfully.

This rule is intentionally targeted. It does not require the full repository matrix before ordinary checkpoints and does not duplicate permanent validators; it exists to catch runtime-only integration defects such as `NameError`, `UnboundLocalError`, initialization-order errors, and changed CLI/control-flow wiring before consuming a hosted Development Completion attempt.

### Development Completion and Candidate Entry

Before Candidate creation, every Work-Path release must perform one deliberate **Development Completion** against the exact final intended Work-Branch state.

Development Completion has two classes of evidence:

1. **mandatory Candidate-entry evidence** — absence or failure blocks Candidate creation;
2. **best-effort development evidence** — useful additional evidence that may be unavailable without blocking Candidate when it is genuinely outside the Candidate-entry contract, such as physical Lenovo/UEFI E2E unless the Issue explicitly makes it mandatory.

A tooling limitation is never `N/A`. For mandatory evidence:
- `PASS` means the exact required check ran successfully against the exact required state;
- `N/A` is allowed only when the check is genuinely not applicable to the change and the reason is recorded;
- unavailable tooling, missing dispatch capability, unavailable full worktree, stale evidence, or inability to run the check means **`BLOCKED`**;
- `FAIL` means the check ran and found a defect.

`BLOCKED` and `FAIL` both prohibit Candidate exposure.

#### Mandatory Candidate-entry evidence

For the exact final Work-Branch SHA, require:

- current `main` re-read and deliberately reconciled;
- final Work-Branch SHA frozen for Development Completion;
- deterministic runtime generation/check GREEN;
- catch-audit generation/check GREEN;
- architecture-baseline generation/check GREEN;
- exact `protectedFragmentIntent` against current reconciled `main...final-work-head`;
- exact `repositoryDeleteIntent` against that same range;
- Release validator GREEN;
- Core validator GREEN;
- Boundary validator GREEN;
- Regression validator GREEN;
- relevant focused/native tests GREEN;
- source-type parser/encoding checks GREEN when applicable, including changed PowerShell runtime/test sources;
- changed Python validator/release-tool/runtime-helper binding smoke PASS when the Python runtime-binding rule applies;
- **Contract Propagation Sweep** PASS when a test/validator/workflow contract changed;
- **Ownership/Change-Impact Matrix** PASS when responsibility ownership moved;
- hosted Windows PowerShell 5.1 contract-suite evidence GREEN on the exact final Work-Branch SHA;
- zero unresolved deterministic Development Completion findings.

For this contract, **relevant focused/native tests** means every active permanent suite that directly owns changed behavior, every active suite modified by the work, and every additional test explicitly required by the Issue acceptance criteria. If none exist for a category, record `N/A` with the concrete reason; lack of tooling is not a reason for `N/A`.

Run independent validators/checks in the same Development Completion pass where technically safe so one failure does not hide other independent actionable findings.

Candidate Preflight remains authoritative and reruns its mandatory Linux/Windows release-entry gates. Development Completion never substitutes for Candidate Preflight and never authorizes publication.

#### Contract Propagation Sweep

Whenever a test, validator, aggregate, or workflow contract changes, perform a repository-wide propagation sweep before Candidate entry.

Review at minimum:

- suite/test/validator name;
- summary/total marker;
- fixed expected count or expected aggregate key;
- direct/native aggregate wrapper;
- hosted Windows aggregate parser/required-total list;
- permanent Release/Core/Boundary/Regression validators;
- test inventory/documentation where the value is contractually recorded;
- issue-specific compatibility/regression contracts that duplicate the changed expectation.

Search for both the old and new contract values where practical. A changed fixed count or summary marker must not reach Candidate while any stale active reference remains.

Prefer one canonical machine-readable owner over repeated hard-coded totals where practical. If a fixed total is intentionally duplicated as a compatibility contract, its propagation points must be explicit.

#### Ownership/Change-Impact Matrix

Whenever a responsibility or canonical owner moves, review and record the impact across:

1. canonical product owner;
2. all product consumers;
3. focused/native tests;
4. aggregate/wrapper wiring;
5. permanent validators;
6. workflow-facing references;
7. release metadata/intents affected by changed protected functions/fragments or repository paths;
8. documentation/test inventory where contractually relevant.

Do not close this matrix with a generic “validators checked”. Record the affected owners/contracts or explicitly record that an item is `N/A` and why.

#### Release-intent derivation and invalidation

`protectedFragmentIntent` and `repositoryDeleteIntent` are release-integrity declarations derived from the final reconciled diff, not remembered metadata.

For a Work-Path release:

1. stabilize the product/test/workflow tree;
2. re-read and reconcile current `main`;
3. compute actual protected-fragment changes and repository deletions from that exact `main...final-work-head` range;
4. set the declared intents to exact set equality with the computed result;
5. record actual vs declared values in the rolling comment;
6. if any later executable/source/workflow/test/repository-path change occurs, or `main` is reconciled again, mark the intent evidence stale and recompute it before Candidate entry.

An empty intent list is a valid PASS only after the exact final diff proves that the actual set is empty.

#### Executable Development Completion workflow

The mandatory hosted/full-worktree Development Completion path is `.github/workflows/development-completion.yml`.

Operational contract:

1. stabilize the complete intended Work-Branch tree, including release metadata and all tracked deterministic generated artifacts required by the Candidate-entry contract;
2. before the first hosted request for that tree, execute and record the targeted Python runtime-binding smoke when changed Python validators/release tooling/workflow helpers make it applicable;
3. persist the last substantive product/tooling checkpoint;
4. create exactly one **tree-identical qualification request commit** on the same `work/LBS-<github-issue-number>` branch with exactly one trailer line:
   `Development-Completion: requested`;
5. that request commit becomes the frozen Work-SHA for Development Completion;
6. the Work-Branch push automatically triggers the workflow; ordinary Work-Branch pushes without the trailer are recognized but skip the expensive gate;
7. Linux first checks tracked runtime, catch audit, and architecture baseline directly on the exact Work-SHA, then reuses `tools/candidate_preflight.py --mode development-completion` for reproducible preparation, protected/delete intent, contract propagation, and Release/Core/Boundary/Regression;
8. hosted Windows PowerShell 5.1 runs in parallel through the reusable Windows workflow's `development-completion` mode on the same exact Work-SHA;
9. the final job emits `DEVELOPMENT_COMPLETION_SUMMARY=<json>` and writes `development-completion/gate` on the exact Work-SHA;
10. a successful status description records the exact tested Main SHA as `PASS main=<sha>`;
11. Candidate Preflight later requires both that exact Work-SHA success status and the same current Main SHA before accepting the Work-Branch provenance.

The tree-identical qualification request commit is an explicit gate-orchestration commit, not a product checkpoint and not heartbeat churn. It is permitted only for a final Development Completion attempt. If the Work-Branch tree changes after the request, the old status is irrelevant; persist the correction and create a new tree-identical request commit for the new exact SHA.

Connector-only agents start the gate by creating that final request commit and advancing `work/LBS-<github-issue-number>` to it. No direct `workflow_dispatch`, local clone, temporary Candidate branch, or publication ref is required.

#### Hosted Windows exact-SHA evidence

Hosted Windows PowerShell 5.1 evidence must test the exact final Work-Branch SHA.

After the run:
- retain the run ID, exact tested SHA, `WINDOWS_POWERSHELL51_SUMMARY`, totals, and timing;
- re-read the Work-Branch head;
- if the head differs from the tested SHA, the evidence is stale and Candidate entry returns to `BLOCKED` until the exact new SHA is tested.

This is Windows contract-suite evidence only. It is not physical Lenovo/UEFI E2E.

#### Candidate Entry block

Immediately before exposing `candidate/v<version>`, the rolling comment must contain exactly one explicit Candidate Entry block for the exact final Work SHA.

If that block was previously `Candidate-Entry: BLOCKED`, update the same block in place after the missing evidence is resolved. Do not retain the obsolete BLOCKED block and append a second PASS block. Historical failure/correction evidence belongs in the relevant Development Completion/Candidate attempt entries, not in duplicate singleton Candidate Entry sections.

Minimum fields:

- `Candidate-Entry: PASS|BLOCKED`;
- current reconciled `Main-SHA`;
- frozen `Work-SHA`;
- runtime / catch audit / architecture baseline;
- protected-fragment intent;
- repository-delete intent;
- Release / Core / Boundary / Regression;
- relevant focused/native tests;
- parser/encoding checks when applicable;
- changed Python runtime-binding smoke: `PASS|N/A`;
- Contract Propagation Sweep: `PASS|N/A`;
- Ownership/Change-Impact Matrix: `PASS|N/A`;
- hosted Windows exact-SHA run;
- unresolved findings count;
- intended Candidate tree equality with the frozen Work tree;
- intended Candidate parent = current reconciled `main`.

`Candidate-Entry: PASS` is permitted only when every mandatory applicable item is PASS, every genuine non-applicable item is explicitly N/A with a reason, and unresolved deterministic findings are zero.

If any mandatory evidence cannot be produced, set `Candidate-Entry: BLOCKED`; do not use Candidate Preflight as the first runner for that missing evidence.

For changed PowerShell sources containing non-ASCII text, a cheap encoding/BOM/parser smoke check is appropriate before Candidate exposure. This is a targeted precheck, not justification for running the full repository suite before every commit.

## 11. Candidate and release supervision

Once the release-ready Candidate exists, follow `docs/RELEASE_PROCESS.md` and `docs/GITHUB_HOWTO.md`.

Do not tight-poll Actions.

Use:

1. one initial run lookup;
2. one terminal run/jobs/log read when practical;
3. `CANDIDATE_PREFLIGHT_SUMMARY` / `CANDIDATE_TIMING_SUMMARY`;
4. after release, the authoritative `RELEASE_VERIFICATION_SUMMARY`.

Do not reconstruct fields already covered by a successful aggregate summary through many additional connector calls unless investigating an inconsistency.

For any Candidate derived from a durable work branch, first ensure no legacy `.chatgpt-work/LBS-<github-issue-number>.md` remains, then create a clean current-`main`-parent Candidate commit whose tree exactly matches the cleaned work-branch tree. The work-branch journal/checkpoint history is recovery state and must not become Candidate ancestry.

Include exactly one unique candidate-history trailer:

`Work-Branch: work/LBS-<github-issue-number>`

Use `Work-Branch: none` for the normal Patch/Hotfix path and whenever no work branch exists. Major/Minor releases may not use `none`. If a Patch/Hotfix declares `work/LBS-*`, Candidate Preflight additionally requires exactly one non-empty `Work-Branch-Reason:` trailer documenting the pre-implementation effort/risk exception. Candidate Preflight requires an exact tree match between the declared work branch and the Candidate. After successful publication, the Release Orchestrator rechecks the tree and deletes that work branch automatically. If the branch changed after Candidate creation, cleanup fails closed and preserves the branch. The final `RELEASE_VERIFICATION_SUMMARY` must confirm candidate, release, and declared work-branch cleanup.

## 12. Normal Work-Path target process

For Work-Path development, use this target sequence:

1. Issue and product-decision gate when applicable;
2. freshly verified `main`;
3. one `work/LBS-<github-issue-number>` branch;
4. coherent product checkpoints at a cadence that prevents more than about **10–15 minutes of substantive completed work** from existing only in transient context;
5. bounded connector operations and no heartbeat-only Git commits;
6. focused validation owned by each implementation phase;
7. no clone/ZIP detours after an environment limitation is established;
8. no manual incremental generated-runtime reconstruction;
9. remove/absorb any legacy recovery file before freezing the final Work tree;
10. perform Development Completion on that exact cleaned Work SHA and produce all mandatory Candidate-entry evidence;
11. if any mandatory evidence is unavailable, stale, or failed, keep Candidate Entry `BLOCKED` and resolve it before proceeding;
12. expose one release-ready Candidate only after `Candidate-Entry: PASS`, carrying exact Work-Branch provenance;
13. let Candidate/Release automation perform promotion/publication and tree-verified cleanup.

Checkpoint count is not a quota. A rough count such as 3–5 may be convenient for some features, but the **10–15 minute resilience bound has priority** and may require more checkpoints.

Never optimize by weakening validation, safety boundaries, reproducibility, or release verification.

## 13. Unexpected Candidate failure classification

Every unexpected Candidate failure must be classified in the rolling comment as exactly one primary category:

- **Development Guideline miss** — an applicable, executable/inspectable pre-Candidate check was not performed or propagated correctly;
- **Tooling gap** — mandatory pre-Candidate evidence had no executable path;
- **Genuinely Candidate-only** — the condition could not reasonably exist or be evaluated before Candidate exposure;
- **External infrastructure failure** — GitHub/runner/service failure unrelated to repository correctness.

Follow-up is mandatory:

- Guideline miss → harden the guideline/checklist or permanent executable contract;
- Tooling gap → add/fix the executable path before future equivalent Candidate entry;
- Candidate-only → document why Candidate is the correct first evaluation point;
- External infrastructure → preserve exact repository state, avoid retry storms, and keep outage time separate from normalized repository-process timing.

## 14. Development Completion and release separation

The repository-supported Work-Path route through `.github/workflows/development-completion.yml` is the **required** execution path for mandatory hosted/full-worktree Candidate-entry evidence. If it cannot run or cannot produce exact-SHA PASS evidence, Work-Path remains `BLOCKED`; Candidate Preflight must not be used as a substitute first runner.

Development Completion is never publication authorization. It must not:

- create or promote `candidate/**` or `release/**` branches;
- create version tags, release ZIPs, or publication PRs;
- replace Candidate Preflight;
- replace the hosted Windows Candidate gate;
- replace Release Orchestrator verification;
- be reported as physical hardware/UEFI acceptance.

Candidate Preflight and Release remain fail-closed and unchanged.
