# Work-Path Rolling Build & Release Recovery Comment Template

Use this template as the default structure for the **single cumulative GitHub Issue comment** maintained during Lenovo Boot Selector Work-Path development.

For new work, `LBS-<github-issue-number>` uses the GitHub Issue number directly. Example: Issue `#90` -> `LBS-90` -> `work/LBS-90`.

Do not create a new comment for each heartbeat or phase. Update the same comment in place and retain previous evidence. Singleton lifecycle sections (`Candidate Entry`, `Release`, `Final Release Verification`, `Performance result`, `Plan-conformance assessment`) occur exactly once and are updated in place; numbered attempt sections occur once per actual attempt/revision. Replace placeholders only with verified facts; do not invent unavailable values.

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
| First Candidate creation | <timestamp> | `<sha>` / run <id> |
| Final GREEN Candidate | <timestamp> | run <id> |
| Release Verification PASS | <timestamp> | run <id> / summary |

Keep user-authorized start, Issue creation, first hosted gate, Candidate creation, and final verification as distinct events.

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
- Contract Propagation: <result/totals>
- Release: <result/totals>
- Core: <result/totals>
- Boundary: <result/totals>
- Regression: <result/totals>
- Windows parser: <result/totals>
- Windows functional: <result/totals>
- Windows total: <duration>
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
- Windows: <PASS/FAIL>, queue <duration>, duration <duration>
- Candidate gate elapsed: <duration>
- Critical path: <Linux | Windows>
- Parser: <totals>
- Functional: <totals>
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
- normalized repository-process time: <duration + listed excluded intervals | N/A if not reliably quantifiable>
- first Development Completion request -> final verification: <duration>
- final GREEN Development Completion -> final verification: <duration>
- first Candidate creation -> final verification: <duration>
- final GREEN Candidate creation -> final verification: <duration>
- Release run creation -> final verification: <duration>
- external infrastructure/user/chat-runtime pause time: <duration(s); report separately and retain in raw chronology>
- failed/corrected gate attempts: <summary>

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

Before Issue closure, perform one structural consistency pass: singleton headings occur once, numbered attempts are unique, no terminal section still says pending/in progress/not started, and the header/measurement/final-verification facts agree. The terminal update of this same rolling comment is the final Work-Path implementation/release record. Do not add a second redundant completion comment unless it contains materially new information.
~~~
