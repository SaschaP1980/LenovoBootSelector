# Development Guidelines

This document defines the durable development workflow for substantial Lenovo Boot Selector feature work.

It applies **by default to Major and Minor releases**. Apply it to a Patch release when the user explicitly requests the work-branch/checkpoint model or when the Issue itself declares that model. Hotfixes normally use the shortest safe test-first path unless explicitly escalated.

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

## 2. Work branch

Create the work branch from a freshly verified current `main`:

`work/LBS-<issue-number>`

Example:

`work/LBS-17`

Rules:

1. Pin the current `main` SHA/tree before creating the branch.
2. Do not reuse a stale work branch from earlier work.
3. One work branch belongs to one Issue/scope.
4. Never use `candidate/v<version>` as an intermediate checkpoint branch.
5. Re-read `main` before final Candidate preparation. If `main` advanced, reconcile deliberately; never force a stale work state over it.
6. After a successful release, delete the work branch when the available GitHub mechanism supports it. If the active connector cannot delete refs, fast-forward the work branch to final `main` and report the remaining cleanup honestly.

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

## 5. Stream/session resilience

There is no reliable warning before an interactive stream/session stops.

Therefore:

- do not hold a large finished change only in tool memory;
- do not assume work continues between user turns;
- when asked whether work is still running, verify GitHub refs/commit timestamps and relevant Actions runs instead of inferring activity from conversation text;
- after any unexpected interruption, re-read `main` and the work-branch head before continuing;
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

A future dedicated **work-branch integration/preflight workflow** would remove most of this friction by running the real repository build/validators on GitHub before Candidate creation. Until such a workflow exists, lack of a local full worktree must be treated as a known precheck limitation, not compensated for with increasingly elaborate archive workarounds.

## 8. Generated runtime handling

The tracked single-file runtime must remain deterministic.

Do not manually patch `bin/LenovoBootMenuTray.ps1` through a long chain of ad-hoc incremental text replacements when the repository build tool can define the composition authoritatively.

Preferred order:

1. edit canonical modular source/template;
2. use the repository's deterministic runtime-build semantics;
3. validate runtime closure;
4. persist the coherent result.

If a full local worktree is unavailable, prefer a GitHub-hosted full-worktree validation/build path over manual reconstruction.

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

Hand-written structural checks are useful focused prechecks, but they must not be mistaken for the actual repository validators.

Before Candidate creation, the final development-completion gate should execute the closest available equivalent of the real Candidate checks:

- deterministic runtime build/check;
- Release/Core/Boundary/Regression validators;
- protected-fragment intent;
- repository-delete intent;
- relevant native Windows PowerShell 5.1 coverage when an available hosted work-branch path exists.

If the current environment cannot execute the real full-worktree checks, record that limitation explicitly. Do not manufacture dozens of approximate checks as a substitute.

LBS-17's first Candidate failed because a regression assertion was too broad. The product behavior was correct; the exact permanent validator had not been executed against the work branch before Candidate exposure. A hosted work-branch preflight would have caught this earlier.

## 11. Candidate and release supervision

Once the release-ready Candidate exists, follow `docs/RELEASE_PROCESS.md` and `docs/GITHUB_HOWTO.md`.

Do not tight-poll Actions.

Use:

1. one initial run lookup;
2. one terminal run/jobs/log read when practical;
3. `CANDIDATE_PREFLIGHT_SUMMARY` / `CANDIDATE_TIMING_SUMMARY`;
4. after release, the authoritative `RELEASE_VERIFICATION_SUMMARY`.

Do not reconstruct fields already covered by a successful aggregate summary through many additional connector calls unless investigating an inconsistency.

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
3. one `work/LBS-<issue>` branch;
4. roughly 3–5 coherent checkpoints rather than many tiny checkpoints;
5. no more than about 10–15 minutes of completed unpersisted work;
6. bounded connector operations;
7. no clone/ZIP detours after the environment limitation is known;
8. no manual incremental generated-runtime reconstruction;
9. one development-completion validation gate using the real validators as closely as the environment permits;
10. one release-ready Candidate;
11. normal Candidate/Release automation;
12. work-branch cleanup.

Never optimize by weakening validation, safety boundaries, reproducibility, or release verification.
