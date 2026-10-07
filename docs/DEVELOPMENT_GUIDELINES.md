# Development Guidelines

This document defines the durable development workflow for substantial Lenovo Boot Selector feature work.

It applies **by default to Major and Minor releases**.

Patch and Hotfix work uses the shortest safe atomic path **without a work branch by default**. Before implementation begins, perform a brief effort/risk analysis. Escalate a Patch or Hotfix to the work-branch/checkpoint model only when that analysis indicates that the work is likely to be substantial, cross-cutting, migration-heavy, interruption-prone, or otherwise unlikely to fit safely into one short implementation cycle. Record the reason durably and carry it into the Candidate as exactly one `Work-Branch-Reason:` trailer.

Do not use a work branch for a small Patch/Hotfix merely for consistency with Major/Minor releases; the resilience machinery must not become routine overhead for short fixes.

The experimental Work-Path heartbeat journal defined below applies **only after a `work/LBS-*` path has already been selected**. It is not used for the normal branchless Patch/Hotfix fast path.

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

Use a work branch when:

- the release is **Major or Minor**; or
- a **Patch or Hotfix** has been explicitly escalated by the pre-implementation effort/risk analysis.

For Patch/Hotfix analysis, indicators for escalation include multiple independently risky phases, settings/data migration, broad cross-module behavior changes, expected work substantially beyond a short atomic patch cycle, or a realistic need for several recoverable checkpoints. A narrow bug fix, text/UI correction, small validator change, or isolated behavior patch should normally remain branchless.

When a Patch/Hotfix is escalated, record the concise reason in the Issue when Issue-backed (or equivalent durable release history for an Issue-less Hotfix) and later include the same decision as `Work-Branch-Reason: <reason>` in the Candidate history.

### Patch/Hotfix atomic fast path

For a Patch/Hotfix that is **not** escalated to a work branch, prefer one short atomic development cycle:

1. pin current `main`;
2. reproduce the bug and establish the focused RED regression against the unfixed canonical basis;
3. prepare the complete source/test/documentation/release-metadata change in memory/Git objects without creating a chain of visible intermediate commits;
4. run the focused GREEN regression plus the smallest relevant syntax/encoding/determinism checks;
5. create **one unreferenced candidate commit** from the pinned `main`;
6. inspect the complete candidate diff/scope once;
7. re-read `main` and expose `candidate/v<version>` only if the base lease still holds.

Do not create a durable RED commit merely to prove test-first work for a normal branchless Patch/Hotfix. Durable RED evidence belongs in the Issue/release audit trail; the Candidate itself remains release-ready only.

If the work can no longer fit safely in this atomic path because scope or duration grows materially, stop before accumulating many intermediate commits and explicitly reconsider whether the Patch/Hotfix should be escalated to the work-branch model.

Create the selected work branch from a freshly verified current `main`:

`work/LBS-<issue-number>`

Example:

`work/LBS-17`

Rules:

1. Pin the current `main` SHA/tree before creating the branch.
2. Do not reuse a stale work branch from earlier work.
3. One work branch belongs to one Issue/scope.
4. Never use `candidate/v<version>` as an intermediate checkpoint branch.
5. Re-read `main` before final Candidate preparation. If `main` advanced, reconcile deliberately; never force a stale work state over it.
6. After a successful release, the Release Orchestrator owns tree-verified work-branch deletion. Do not keep or manually fast-forward a completed work branch merely because the interactive connector cannot delete refs.

## 3. Product-decision gate before implementation

A Major/Minor feature must not silently invent user-facing policy where the Issue leaves a material ambiguity.

Before implementation, resolve and record any decision that changes existing user state or defaults, including:

- migrations;
- default values;
- destructive or irreversible behavior;
- compatibility/fallback behavior;
- persistence semantics;
- security/safety interpretation.

If the expected product behavior is genuinely ambiguous, ask the user before coding.

LBS-17 demonstrated why this matters: the implementation deliberately migrated pre-localization installations to German even though the later native acceptance expectation was English-by-default. The tests faithfully protected the implemented rule, but the rule itself was wrong for the intended product behavior.

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

### Work-Path heartbeat journal — experimental

This mechanism applies **only** to development that already uses a durable `work/LBS-<issue>` branch. It therefore applies to Major/Minor work and to the exceptional Patch/Hotfix that was explicitly escalated to the Work-Path model. It does **not** apply to the normal branchless Patch/Hotfix fast path.

During active interactive Work-Path development, maintain one temporary tracked continuation journal:

`.chatgpt-work/LBS-<issue>.md`

The journal and a product checkpoint have different responsibilities:

- a **product checkpoint** is a coherent recoverable source state and may include focused validation;
- a **heartbeat journal commit** is a deliberately lightweight persistence event for recent engineering findings and liveness state.

A heartbeat journal commit must not trigger a build, full test matrix, runtime regeneration, Candidate gate or checkpoint gate merely because the journal changed. When the connector supports a single-file contents update, prefer that lightweight write path rather than reconstructing a full product checkpoint.

The journal records only durable engineering continuation information that could appropriately appear in a normal progress update. It is **not** a private chain-of-thought record. Useful entries include:

- facts and constraints discovered;
- experiments attempted and their concise result;
- failed approaches and the technical reason they were rejected;
- test/validator findings;
- evidence-based decisions;
- current phase and next intended action;
- relevant GitHub workflow/run identifiers.

Keep a compact status header with at least:

```text
Branch: work/LBS-XX
Base-Main: <sha>
Last-Heartbeat-UTC: <timestamp>
Agent-State: ACTIVE
GitHub-Run: none | <workflow/run identifier>
Last-Product-Checkpoint: <sha>
Current-Phase: <short phase>
Next-Action: <short next action>
```

Exact formatting may evolve, but the semantics above must remain recoverable.

#### Heartbeat cadence and stale interpretation

While substantive interactive Work-Path development is actively producing findings or state changes, update the journal approximately every **1–3 minutes**. Also update it before a potentially long/high-risk tool sequence when the intended next action matters for recovery. Do not create meaningless commits merely to satisfy a timer when nothing changed.

Operationally:

- a recent heartbeat means only that the interactive agent was active at that recorded point;
- when the latest heartbeat is older than roughly **5 minutes** and no referenced GitHub Actions run is currently `queued` or `in_progress`, treat the interactive agent/stream as stopped and resume from durable GitHub state;
- when a referenced GitHub Actions run is still `queued` or `in_progress`, that GitHub work continues independently even if the chat stream stopped;
- never describe interactive-agent work as continuing in the background when no independent automation is actually running.

On recovery from an interrupted Work-Path session, a fresh agent must read current `main`, the Issue, the `work/LBS-<issue>` head, the latest product checkpoint context and the journal when it exists before taking further action. Re-check any referenced GitHub run directly rather than trusting a stale journal status.

#### Candidate cleanup and history isolation

The journal is disposable Work-Path state and must never be published.

Before Candidate creation:

1. finish the intended product work and required development-completion checks;
2. remove `.chatgpt-work/LBS-<issue>.md` from the work branch;
3. verify the final cleaned work-branch tree contains only intended release content;
4. re-read current `main` and reconcile it if necessary;
5. create the release-ready Candidate as a **single clean commit whose parent is current `main` and whose tree exactly equals the final cleaned work-branch tree**;
6. include the normal `Work-Branch: work/LBS-<issue>` provenance trailer and, for an escalated Patch/Hotfix, the required `Work-Branch-Reason:` trailer.

The Work-Path journal commits therefore remain reachable only through the disposable work branch. They must not become ancestors of the Candidate, source tag, publication PR or `main`. Existing exact Candidate/work-branch tree equality remains the release safety contract, and the Release Orchestrator retains responsibility for deleting the work branch only after rechecking that equality.

This mechanism is an experiment introduced by LBS-36. Evaluate it on the next suitable Work-Path development task. If it does not materially improve liveness visibility and recovery, revert this process rule cleanly rather than preserving ceremony without value.

## 5. Stream/session resilience

There is no reliable warning before an interactive stream/session stops.

Therefore:

- do not hold a large finished change only in tool memory;
- do not assume work continues between user turns;
- when asked whether work is still running, verify GitHub refs/commit timestamps and relevant Actions runs instead of inferring activity from conversation text;
- after any unexpected interruption, re-read `main`, the work-branch head and the Work-Path heartbeat journal when present before continuing;
- use the journal heartbeat plus direct GitHub Actions state to distinguish a dead interactive stream from independently running GitHub automation;
- never claim that background development continued when no automation/workflow was actually running.

LBS-17 had two significant continuity gaps: work stopped after checkpoint 4 and again after checkpoint 7 until the user prompted continuation. The checkpoint model prevented source loss, but the idle wall-clock time was still avoidable.

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

The first LBS-17 implementation attempt exceeded the code-mode tool-call limit because too many GitHub reads/writes were composed into one block. The visible branch remained safe, but the retry consumed avoidable time.

## 7. Repository archive / ZIP and clone limitations

### This is not work-branch-specific

A work branch does **not** inherently prevent cloning, ZIP download, materialization, or normal Git operations.

The LBS-17 message:

> “The connector ZIP path is not available in this environment…”

described an **execution-environment/tooling limitation**, not a Git or work-branch property.

During the pilot:

- the available GitHub connector did not expose a general repository archive/zipball materialization operation;
- the container runtime could not resolve/reach `github.com` for direct Git access;
- attempting GitHub archive URLs through web/container access did not provide a reliable canonical full-worktree path.

The work branch only made this limitation more visible because the newest intermediate source state existed only on GitHub and a full local worktree would have been convenient for runtime generation and repository-wide validators.

### Required behavior

If the connector has no repository-archive action and direct clone/network access is unavailable:

1. **do not repeatedly probe clone/ZIP/archive routes**;
2. do not treat this as a repository failure;
3. do not fall back to an old Source ZIP;
4. continue connector-first for canonical file/ref/Git-object work;
5. prefer repository-hosted GitHub Actions for operations that genuinely require a complete worktree.

A dedicated **Work Checkpoint Gate** is the intended permanent solution for this friction. It should run the repository build and standardized validators on GitHub against the exact work-branch checkpoint instead of forcing the agent to emulate a full worktree through connector reads. The target contract is defined in section 14 below.

Until that workflow exists, lack of a local full worktree must be treated as a known precheck limitation, not compensated for with increasingly elaborate archive workarounds. If necessary, persist a coherent modular-source checkpoint and record runtime synchronization or full-worktree validation as pending rather than performing unsafe manual runtime reconstruction. Such a checkpoint is recoverable development state, not a GREEN development-completion gate and not a release-ready Candidate.

## 8. Generated runtime handling

The tracked single-file runtime must remain deterministic.

Do not manually patch `bin/LenovoBootMenuTray.ps1` through a long chain of ad-hoc incremental text replacements when the repository build tool can define the composition authoritatively.

Preferred order:

1. edit canonical modular source/template;
2. use the repository's deterministic runtime-build semantics;
3. validate runtime closure;
4. persist the coherent result.

If a full local worktree is unavailable, prefer a GitHub-hosted full-worktree validation/build path over manual reconstruction.

For routine work-branch checkpoints, the agent should edit the canonical modular source and let the future Work Checkpoint Gate own deterministic runtime synchronization. If the tracked runtime must change, the preferred hosted model is at most **one deterministic canonicalization follow-up commit** on the same work branch, containing only the generated runtime/audit outputs that the workflow is explicitly authorized to update. The workflow must never create a chain of incremental staging commits. The exact generated follow-up SHA, when one is needed, becomes the validated checkpoint head.

Until that hosted path is implemented, do not claim a source-only checkpoint is fully synchronized or validator-GREEN when `bin/LenovoBootMenuTray.ps1` still needs deterministic regeneration. Before Candidate creation, the tracked runtime must be regenerated from canonical source and the real development-completion checks must pass.

When text composition is unavoidable in JavaScript tooling, treat PowerShell `$` characters as data. Do not use the replacement-string form of JavaScript `String.replace()` for generated PowerShell content because `$` sequences have replacement semantics. Use a literal-safe method such as `split/join` or a replacement callback.

LBS-17 hit this exact problem once and had to regenerate the staged runtime.

## 9. Avoid unreferenced staging-commit chains

Git blobs/trees are useful for atomic preparation, but do not turn every partial runtime step into another unreferenced Git commit.

Use:

- blobs as temporary assembly objects;
- at most one temporary tree/commit when it materially helps inspection;
- one referenced checkpoint commit for the coherent phase.

LBS-17 created many temporary/unreferenced staging commits while incrementally rebuilding the runtime. They protected the visible work branch but added connector roundtrips and debugging overhead. This is not the normal target process.

## 10. Validation hierarchy before Candidate

The Candidate is expected GREEN.

### Commit validation versus Candidate validation

Do **not** use the rule "every commit requires every test suite to be GREEN."

Use validation proportional to the Git object's role:

- **RED-evidence state:** the focused regression is expected to fail for the defect-specific reason.
- **Work-branch checkpoint:** run the focused checks needed to establish a coherent recoverable phase; broader/native suites may remain pending and must be recorded honestly.
- **Branchless Patch/Hotfix candidate preparation:** require the same focused test that proved RED to be GREEN, plus directly relevant syntax/encoding/determinism smoke checks before exposing the Candidate.
- **Release-ready Candidate:** all available prechecks should indicate expected GREEN; GitHub Candidate Preflight then runs the authoritative Linux and Windows PowerShell 5.1 gates on the exact exposed SHA.
- **Release:** the Release Orchestrator reruns the publication/reproducibility/status gates as defense in depth.

The full repository matrix belongs at the Candidate/Release boundary, not mechanically before every persistence commit.

### Test ownership and redundancy

Prefer the **lowest existing permanent test layer that directly proves the behavior**. Add a second test layer only when it protects a meaningfully different risk.

Once a repository invariant is owned by a permanent executable test or validator:

- execute that test/validator instead of reconstructing the same assertion with multiple connector reads;
- do not add an issue-specific validator that merely duplicates existing Functional Core/native/integration coverage;
- do not assert exact documentation wording, capitalization, punctuation, or implementation-detail strings unless the text is itself a machine-consumed compatibility contract;
- do not keep both ad-hoc structural checks and a permanent regression when they prove the same fact.

A new permanent regression should normally encode behavior or a stable architectural invariant, not incidental source spelling.

Hand-written structural checks are useful focused prechecks, but they must not be mistaken for the actual repository validators.

Before Candidate creation, the final development-completion gate should execute the closest available equivalent of the real Candidate checks:

- deterministic runtime build/check;
- Release/Core/Boundary/Regression validators;
- protected-fragment intent;
- repository-delete intent;
- relevant native Windows PowerShell 5.1 coverage when an available hosted work-branch path exists.

If the current environment cannot execute the real full-worktree checks, record that limitation explicitly. Do not manufacture dozens of approximate checks as a substitute.

LBS-17's first Candidate failed because a regression assertion was too broad. The product behavior was correct; the exact permanent validator had not been executed against the work branch before Candidate exposure. A hosted work-branch preflight would have caught this earlier.

LBS-23/v0.8.0.1 reinforced the opposite efficiency lesson for small fixes: the work branch accumulated **24 commits** for an 18-file Hotfix, while several manual structural checks and an issue-specific Python validator duplicated behavior already covered by Functional Core and the native localization suite. The extra validator also created avoidable quote/prose-literal corrections. Future small Patch/Hotfix work should therefore favor the atomic branchless path, one behavioral regression at the lowest useful layer, and only distinct integration coverage.

The LBS-23 Candidate also found a displaced UTF-8 BOM on a PowerShell file. For changed PowerShell sources containing non-ASCII text, a cheap encoding/BOM/parser smoke check is appropriate before Candidate exposure; that is a targeted precheck, not justification for running the full repository suite before every commit.

## 11. Candidate and release supervision

Once the release-ready Candidate exists, follow `docs/RELEASE_PROCESS.md` and `docs/GITHUB_HOWTO.md`.

Do not tight-poll Actions.

Use:

1. one initial run lookup;
2. one terminal run/jobs/log read when practical;
3. `CANDIDATE_PREFLIGHT_SUMMARY` / `CANDIDATE_TIMING_SUMMARY`;
4. after release, the authoritative `RELEASE_VERIFICATION_SUMMARY`.

Do not reconstruct fields already covered by a successful aggregate summary through many additional connector calls unless investigating an inconsistency.

For any Candidate derived from a durable work branch, first remove the temporary Work-Path heartbeat journal, then create a clean current-`main`-parent Candidate commit whose tree exactly matches the cleaned work-branch tree. The work-branch journal/checkpoint history is recovery state and must not become Candidate ancestry.

Include exactly one unique candidate-history trailer:

`Work-Branch: work/LBS-<issue>`

Use `Work-Branch: none` for the normal Patch/Hotfix path and whenever no work branch exists. Major/Minor releases may not use `none`. If a Patch/Hotfix declares `work/LBS-*`, Candidate Preflight additionally requires exactly one non-empty `Work-Branch-Reason:` trailer documenting the pre-implementation effort/risk exception. Candidate Preflight requires an exact tree match between the declared work branch and the Candidate. After successful publication, the Release Orchestrator rechecks the tree and deletes that work branch automatically. If the branch changed after Candidate creation, cleanup fails closed and preserves the branch. The final `RELEASE_VERIFICATION_SUMMARY` must confirm candidate, release, and declared work-branch cleanup.

LBS-17 included several unnecessary repeated job-status reads and redundant post-release API verification calls even though the repository already had aggregated summaries.

## 12. LBS-17 pilot timing evidence

The LBS-17 work-branch pilot started at **2026-10-06 18:26:53Z** and the Release Orchestrator finished at **20:52:25Z**: about **2 h 25 min 32 s** wall-clock.

Checkpoint timestamps:

| Gate | UTC | Delta |
| --- | --- | ---: |
| Pilot start | 18:26:53 | — |
| Checkpoint 1 | 18:32:31 | 5m 38s |
| Checkpoint 2 | 18:36:06 | 3m 35s |
| Checkpoint 3 | 18:52:32 | 16m 26s |
| Checkpoint 4 | 19:02:10 | 9m 38s |
| Checkpoint 5 | 19:48:53 | 46m 43s |
| Checkpoint 6 | 20:04:48 | 15m 55s |
| Checkpoint 7 | 20:13:04 | 8m 16s |
| First Candidate run | 20:49:28 | 36m 24s after CP7 |
| Release complete | 20:52:25 | 2m 57s after first Candidate start |

The large elapsed time was therefore **not the publication pipeline**.

The successful Candidate reported:

- candidate gate elapsed: about **28.5 s**;
- Linux execution: about **4 s**;
- Windows critical path: about **22.3 s**;
- Windows localization runtime: **14/14**;
- aggregate Windows functional checks: **221/221**.

The first Candidate start through final release completion took about **2m57s**, including one unexpected Candidate failure, its minimal validator correction, a second Candidate Preflight, and the Release Orchestrator.

The two largest wall-clock gaps were:

- checkpoint 4 → 5: **46m43s**, including an interrupted interactive workstream plus the most complex UI/runtime migration phase;
- checkpoint 7 → Candidate: **36m24s**, dominated by an idle/terminated interactive session that required the user to prompt continuation.

Optimization effort should therefore target development/session/connector orchestration, not remove Candidate/Release safety gates.

## 13. Normal target process for the next Major/Minor feature

For a comparable feature, aim for:

1. Issue and explicit product-decision gate;
2. verified `main`;
3. one `work/LBS-<issue>` branch (Major/Minor, or an explicitly escalated Patch/Hotfix exception);
4. roughly 3–5 coherent checkpoints rather than many tiny checkpoints;
5. no more than about 10–15 minutes of completed unpersisted work;
6. bounded connector operations;
7. no clone/ZIP detours after the environment limitation is known;
8. no manual incremental generated-runtime reconstruction;
9. use the Work Checkpoint Gate for deterministic runtime synchronization and standardized checkpoint validation as soon as that hosted path exists;
10. one development-completion validation gate using the real validators as closely as the environment permits;
11. one release-ready Candidate carrying the exact `Work-Branch:` provenance trailer;
12. normal Candidate/Release automation;
13. automatic, tree-verified work-branch cleanup after successful publication.

Never optimize by weakening validation, safety boundaries, reproducibility, or release verification.

## 14. Work Checkpoint Gate — target architecture

### Purpose

The Work Checkpoint Gate exists to make **frequent durable checkpoints cheap enough to use as the primary defense against unavoidable interactive-session failure**.

The project must assume that a chat, response stream, agent runtime, connector call, or local execution environment can stop without warning. That condition cannot be eliminated by asking one interactive prompt to run until an entire feature and release are complete. The durable engineering response is therefore:

```text
agent work
  -> durable work-branch checkpoint
  -> GitHub-hosted checkpoint build/validation
  -> continue automatically
```

A fresh session must be able to recover from the latest work-branch head and its GitHub validation evidence without needing the interrupted conversation.

### Non-goals and release separation

The Work Checkpoint Gate is **not** Candidate Preflight and is **not** a publication path.

It must not:

- create `candidate/**`, `release/**`, version tags, publication PRs, or release ZIPs;
- weaken or replace Linux Candidate Preflight;
- weaken or replace the mandatory Windows PowerShell 5.1 Candidate gate;
- weaken or replace the Release Orchestrator or its eight final release contexts;
- convert an intermediate development checkpoint into a release-ready Candidate merely because a subset of checks is GREEN.

Candidate Preflight remains the release-entry authority. The Work Checkpoint Gate exists only to make development state recoverable and to catch integration defects earlier.

### Trigger and exact-SHA discipline

The intended hosted workflow should operate on `work/LBS-*` checkpoints and validate an exact commit SHA.

At minimum it should:

1. check out the exact work-branch checkpoint on a full GitHub-hosted worktree;
2. verify that the work branch still points to the expected source checkpoint before applying any generated follow-up;
3. regenerate the single-file runtime through the repository's authoritative deterministic build tooling;
4. verify runtime closure/determinism;
5. run the relevant focused and permanent validators that are appropriate for that checkpoint;
6. publish a clear exact-SHA PASS/FAIL result and machine-readable summary;
7. leave the work branch in a recoverable state even when validation fails.

A failed checkpoint gate is development evidence, not a reason to create a Candidate or release branch. Correct the smallest problem on the same work branch and continue.

### Generated runtime canonicalization

The agent should normally modify **canonical modular source**, not manually splice the 350–450 KB generated single-file runtime through connector string operations.

If deterministic regeneration changes tracked generated files, the preferred hosted behavior is:

1. preserve the original source checkpoint as a durable recoverable commit;
2. generate the tracked runtime/audit outputs in the full GitHub worktree;
3. if generated files differ, create **at most one** deterministic follow-up canonicalization commit on the same work branch;
4. allow only the explicitly expected generated paths in that follow-up;
5. validate the resulting exact follow-up SHA;
6. make that validated SHA the effective checkpoint head.

If no generated file changes, no follow-up commit is created.

The workflow must prevent self-trigger loops and must not create unreferenced or repeated staging-commit chains. Automated canonicalization is acceptable because it removes expensive and error-prone connector reconstruction; manual incremental runtime staging is not.

### Checkpoint validation levels

Not every development checkpoint needs the full publication matrix. The gate should support validation proportional to the checkpoint while keeping the final development-completion gate strong.

A normal checkpoint should prioritize:

- deterministic runtime generation/check;
- runtime closure;
- relevant focused regression tests;
- permanent static Release/Core/Boundary/Regression checks that are valid for the current intermediate state;
- protected-fragment and repository-delete intent checks when those contracts are already meaningful.

A checkpoint that touches Windows-specific runtime behavior, PowerShell parsing/encoding, localization runtime, TaskBroker boundaries, or other Windows-only contracts should run the relevant hosted Windows PowerShell 5.1 coverage when practical.

Before Candidate creation, the **development-completion checkpoint** should run the closest available equivalent of the real Candidate validation, including hosted Windows PowerShell 5.1 coverage when the work-branch workflow provides it. Candidate Preflight still reruns its mandatory authoritative gates afterward.

### Validator ownership and remote-read budget

Once an invariant has a permanent executable validator, the Work Checkpoint Gate should execute that validator instead of having the agent reconstruct the same assertion through multiple GitHub fetches.

Examples include:

- localization catalog parity;
- runtime include/closure checks;
- uncontrolled visible-literal checks;
- architecture/boundary invariants;
- protected-fragment intent;
- repository deletion intent;
- deterministic generated-runtime checks.

Connector reads remain appropriate for understanding code, reviewing exact diffs, diagnosing a failed gate, and making implementation decisions. They should not become a second hand-built validation framework beside the repository's validators.

### Continuation behavior

After a checkpoint is durably persisted and its required checkpoint gate is GREEN, continue the already authorized task automatically. Do not stop merely to announce that a checkpoint exists.

If the checkpoint gate is still running when the interactive session ends, the work branch remains the recovery anchor. A later session must read the branch head and GitHub gate result before continuing.

If the gate is RED, resume from that exact checkpoint, read the failure evidence, make the smallest correction, and rerun the gate. Do not discard the branch and do not start an unrelated parallel implementation path.

### Performance objective

The performance target is not fewer checkpoints. It is **cheap checkpoints**.

For a normal checkpoint, aim for roughly:

- no more than **1–2 minutes of agent/connector orchestration overhead** after substantive implementation, excluding test execution and external runner queues;
- one durable source/checkpoint commit;
- zero manual large-runtime reconstruction;
- zero duplicated ad-hoc checks for invariants already owned by permanent validators;
- at most one automated deterministic generated-output follow-up commit when required.

The LBS-17 pilot showed that the final persistence overhead itself was usually acceptable; the dominant avoidable cost was manual generated-runtime synchronization and repeated connector-side revalidation. The Work Checkpoint Gate is specifically intended to remove that cost while preserving or increasing checkpoint frequency.
