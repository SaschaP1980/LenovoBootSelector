# Work-Path Rolling Build & Release Recovery Comment Template

Use this template as the default structure for the **single cumulative GitHub Issue comment** maintained during Lenovo Boot Selector Work-Path development.

For new work, `LBS-<github-issue-number>` uses the GitHub Issue number directly. Example: Issue `#90` -> `LBS-90` -> `work/LBS-90`.

Do not create a new comment for each heartbeat or phase. Update the same comment in place and retain previous evidence. Singleton lifecycle sections (`Benchmark configuration`, `Candidate Entry`, `Release`, `Final Release Verification`, `Performance result`, `Evidence audit`, `Plan-conformance assessment`) occur exactly once and are updated in place; numbered attempt sections occur once per actual attempt/revision. Replace placeholders only with verified facts; do not invent unavailable values. Detailed validator totals and error evidence must survive the terminal update; do not shorten them to generic PASS claims.

~~~markdown
## LBS-<github-issue-number> — Rolling Build & Release Recovery State

**Last heartbeat:** <UTC timestamp>  
**Agent-State:** ACTIVE | WAITING_FOR_GITHUB | BLOCKED_EXTERNAL | IDLE | STOPPED | COMPLETED  
**Issue:** LBS-<github-issue-number> / #<github-issue-number>  
**Base main:** `<sha>`  
**Work branch:** `work/LBS-<github-issue-number>` | deleted after successful release  
**Current work head:** `<sha/status>`  
**Last product checkpoint:** `<sha/status>`  
**Target version:** v<version>  
**Release profile:** `<profile>`  
**Release level:** <Major | Minor | Patch | Hotfix>  
**Current phase:** <phase>  
**Next action:** <exact next action>

### Explicit Work-Path decision / exception

<Why Work-Path applies. For a Patch/Hotfix exception, identify whether this is effort/risk escalation or an explicit user-authorized process-validation/benchmark, and include the exact durable Work-Branch-Reason.>

### Benchmark configuration

- Assistant-identifiable model: <model family | unknown>; evidence: <assistant-declared | runtime-exposed | user-reported | unknown>. Do not imply the assistant can inspect the user's model selector.
- User-selected model in ChatGPT UI: <value | unknown>; evidence: <user-reported | independently exposed in runtime | unknown>. Distinguish UI selection from assistant-declared model identity.
- Thinking/reasoning effort: <Medium | High | other | unknown>; evidence: <user-reported | independently exposed in runtime | unknown>. Never infer effort from speed, response appearance, model identity, or prior chats. The assistant normally cannot read this UI setting.
- Workload signature: <release level, version-only versus functional diff, work-path versus fast-path, expected exact file scope, mandatory hosted gates>; deviations: <facts>.
- Benchmark comparison conditions: <comparable inputs/gate policy | differences and confounders>; never attribute changes in wall time to reasoning effort alone without controlled evidence.

### Allowed release-ready diff

Only:
- `<path>`
- ...

State important forbidden scope explicitly, especially safety/privilege/firmware/runtime boundaries when relevant.

### Validation plan

- Focused validation owner(s): <checks>
- Python runtime-binding smoke: <PASS | BLOCKED | N/A with reason>
- Contract Propagation Sweep: <PASS | BLOCKED | N/A with reason>
- Ownership/Change-Impact Matrix: <PASS | BLOCKED | N/A with reason>
- Hosted exact-SHA Development Completion before Candidate: required

### Measurement ledger

| Event | UTC | Evidence |
| --- | --- | --- |
| User-authorized performance/work start | <timestamp | unavailable/approximate> | <evidence; never substitute Issue creation and call it user authorization> |
| Issue created / Work-Path decision recorded | <timestamp> | #<issue> |
| First product checkpoint | <timestamp> | `<sha>` |
| First Development Completion request | <timestamp> | run <id> |
| Final GREEN Development Completion | <timestamp> | run <id> |
| Candidate commit created / ref exposed | <timestamp | unknown> | `<sha>` / commit/ref evidence; do not substitute workflow-run created_at |
| Candidate Preflight run created | <timestamp> | run <id> |
| Candidate exact-SHA gates GREEN | <timestamp> | run <id> / 3/3 contexts; distinct from promotion |
| Candidate promotion completed | <timestamp> | run <id> / `CANDIDATE_TIMING_SUMMARY` or step evidence |
| Release Orchestrator run created | <timestamp> | run <id> |
| Release Verification PASS | <timestamp> | run <id> / authoritative summary |

Keep user-authorized start, Issue creation, Candidate commit/ref creation, run creation, GREEN gates, promotion and final verification as distinct events. A workflow timestamp is not evidence of an earlier commit's exact creation time.

### Counters

- Product checkpoints: <n>
- Development Completion attempts: <n>
- Development Completion failures/corrections: <n>
- Candidate revisions exposed: <n>
- Candidate failures: <n>
- Candidate correction loops: <n>
- Release attempts: <n>
- Release failures: <n>

### Minimal assembly / implementation phase — <UTC>

<Concise cumulative facts about prepared source/release-ready state and any pending validation.>

### Checkpoint <n>/<total or ?> — <UTC>

- Work checkpoint: `<sha>`
- Work tree: `<tree>`
- Current main: `<sha>`
- Scope: <facts>
- Validation executed: <facts/results>
- Native Windows tests: <PASS/pending/not applicable>
- Open work: <facts>
- Next action: <action>
- Blockers/decisions: <facts>

### Development Completion attempt <n> — <PASS | FAIL | in progress>

Run: `<run-id>`  
Created: <UTC>  
Completed: <UTC or pending>  
Elapsed wall time: <duration or pending>

- Frozen Work-SHA: `<sha>`
- Work tree: `<tree>`
- Main-SHA: `<sha>`
- Contract Propagation: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Release: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Core: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Boundary: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Regression: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Windows parser: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Windows functional: <PASS/FAIL, passed/expected; evidence job/log/summary>
- Windows total: <queue/setup/runtime-preparation/test/total durations, where available>
- Totals retention: copy every applicable independently verified total, not just an aggregate PASS; otherwise mark unavailable and link the owning hosted job.
- Failure classification/correction: <if applicable>

### Candidate Entry — <PASS | BLOCKED>

`Candidate-Entry: <PASS | BLOCKED>`

- frozen Work-SHA: `<sha>`
- current Main-SHA: `<sha>`
- exact Work tree: `<tree>`
- runtime / catch audit / architecture baseline: <result>
- protected fragment intent: <result/value>
- repository delete intent: <result/value>
- focused/native checks: <result>
- Python runtime-binding smoke: <result>
- Contract Propagation Sweep: <result>
- Ownership/Change-Impact Matrix: <result>
- hosted Windows exact-SHA evidence: <result/run>
- unresolved deterministic findings: <n>

### Candidate #<n> — <GREEN | FAIL | in progress>

Run: `<run-id>`  
Created: <UTC>  
Completed: <UTC or pending>

- Candidate SHA: `<sha>`
- Parent: `<main-sha>`
- Tree: `<tree>`
- Linux: <PASS/FAIL>, queue <duration>, duration <duration>
- Linux validator totals: Contract Propagation <passed/expected>, Release <passed/expected>, Core <passed/expected>, Boundary <passed/expected>, Regression <passed/expected>; <run/job/log evidence or individually unavailable>
- Windows: <PASS/FAIL>, queue <duration>, duration <duration>; setup <duration>, runtime preparation <duration>, tests <duration> where available
- Candidate gate elapsed: <duration; exact machine-readable timing definition>
- Candidate promotion completed: <UTC/elapsed; distinct from exact-SHA gate GREEN>
- Critical path: <Linux | Windows>
- Parser: <passed/expected; evidence>
- Functional: <passed/expected; evidence>
- Failure/correction cause: <if applicable>

### Release

- Release Orchestrator run: `<run-id>`
- Created: <UTC>
- Current status: <status>
- Release attempts: <n>

### Final Release Verification

- `RELEASE_PREACTIVATION_SUMMARY.result`: <PASS>
- `RELEASE_VERIFICATION_SUMMARY.result`: <PASS>
- PR: #<pr>
- merged at: <UTC>
- final main: `<sha>`
- source tag: `v<version>`
- source commit: `<sha>`
- published UTC: <UTC>
- release ZIP: `<file>`, <bytes>, SHA-256 `<hash>`
- source ZIP: `<file>`, <bytes>, SHA-256 `<hash>`
- Candidate contexts: <3/3>
- Release contexts: <8/8>
- latest consistent: <true>
- release ZIP consistent: <true>
- reproducible: <true>
- historical ZIP integrity: <true>
- Candidate branch deleted: <true>
- Release branch deleted: <true>
- Work branch deleted: <true>

### Performance result

User-authorized start: <UTC if exactly observed | unavailable/approximate>  
Issue creation: <UTC>  
Final Release Verification summary: <UTC>

- raw durable GitHub end-to-end (Issue creation -> final verification): <duration>
- raw user-authorized start -> final verification: <duration | N/A when exact start unavailable>
- normalized repository-process time: <duration + listed verified excluded intervals | N/A if not reliably quantifiable>
- issue creation -> Development Completion request: <duration; Work-Path only>
- Development Completion queue/execution: <durations; job/run evidence>
- first Development Completion request -> final verification: <duration>
- final GREEN Development Completion -> final verification: <duration>
- Candidate commit/ref creation -> final verification: <duration | N/A if exact timestamp unknown>
- Candidate run creation -> exact-SHA gate GREEN: <duration>
- Candidate gate GREEN -> promotion completed: <duration>
- Candidate run creation -> final verification: <duration>
- promotion completed -> final verification: <duration>
- Release run creation -> final verification: <duration>
- Release queue/execution: <durations and measured boundaries>
- ChatGPT/connector orchestration gaps between hosted runs: <separately measured intervals; these are not direct model compute or thinking-time measurements>
- external infrastructure/user/chat-runtime pause time: <verified duration(s) or unknown; retain in raw chronology>
- failed/corrected gate attempts: <summary>

### Evidence audit

- Scope: <exact reviewed Issue/comment, commits/diffs, Actions runs/jobs, and summary IDs>
- Validator totals: <Contract Propagation, Release, Core, Boundary, Regression, Windows parser/functional preserved above with passed/expected and linked run/job evidence; unavailable values named explicitly>
- Every documented error, limitation, retry and failure: <short claim -> observed tool call/output or Actions run/job/step/log reference -> primary classification>. If evidence is not reproducible in GitHub, quote only the minimally necessary observed non-secret diagnostic and explicitly label the source as interactive tool output.
- Unverified or incorrectly attributed claims: <correct/remove, or flag explicitly unverified; never present an assumed local/network error as observed>
- Model and reasoning-effort provenance: <assistant-declared vs UI user-reported vs independently verified vs unknown; no unverifiable automatic setting claims>
- Time-anchor audit: <Issue creation distinct from user authorization; Candidate commit/ref distinct from Candidate run creation; Candidate GREEN gate distinct from promotion complete; Release Verification summary distinct from workflow completion>
- Final structural consistency: <each singleton heading exactly once; numbered attempts unique; no stale BLOCKED/pending/active content in completed phases; source tag/PR/main/ZIP/cleanup agree with summaries>
- Unresolved evidence concerns: <none, or list with consequence for reporting/closure>

### Plan-conformance assessment

**<PASS | PASS WITH CORRECTION | FAIL>.**

1. <checkpoint behavior>
2. <Development Completion behavior>
3. <Candidate behavior>
4. <Release behavior>
5. <cleanup behavior>
6. <deviations classified as guideline / repository / external infrastructure / product finding>

At successful completion update this same comment to:

- **Agent-State:** COMPLETED
- **Current phase:** Release Verification complete
- **Next action:** close #<github-issue-number> as completed

Before Issue closure, perform the explicit Evidence audit and structural consistency pass: singleton headings occur once, numbered attempts are unique, every failure/error assertion has an observed source, validator totals remain available or are clearly marked unavailable, benchmark model/effort sources are correctly qualified, timing anchors are not conflated, no terminal section still says pending/in progress/not started, and the header/measurement/final-verification facts agree. Correct or clearly mark unsupported historical claims before completion. The terminal update of this same rolling comment is the final Work-Path implementation/release record. Do not add a second redundant completion comment unless it contains materially new information.
~~~
