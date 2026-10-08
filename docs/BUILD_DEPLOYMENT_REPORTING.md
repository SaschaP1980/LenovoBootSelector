# Build & Deployment – Chat Report Presentation Standard

This document defines the **user-facing final report presentation** for Lenovo Boot Selector build, deployment, release and process-benchmark instructions. It is linked from `docs/DEVELOPMENT_GUIDELINES.md`. It governs presentation only: executable workflows, validators, release gates, safety policy, evidence requirements and the Issue rolling recovery ledger retain precedence and remain unchanged.

## When to use it

After a completed build/release/deployment request, present a concise, visually structured technical dashboard in the interactive response, including version-only Hotfix and process-benchmark runs. For an in-progress or blocked run, use the same sequence but visibly distinguish confirmed progress from pending/failed stages. Never present a pending release as successfully deployed.

The repository and durable GitHub prose remain **English**; the interactive user report may be in **German**. This file does not require any particular ChatGPT version or user-interface capability.

## Default presentation and order

1. **Title and status:** show the project/build context, target version, and a single prominent factual status: verified successful deployment, pending, blocked or failed. A status badge may be used when supported, never as the sole status signal.
2. **Top-level metrics:** two compact prominent metrics: verified raw end-to-end duration with an explicit start/end definition, and failed mandatory gate count (or state unavailable rather than inventing it). Use number cards/tiles if supported.
3. **Performance visualization:** horizontal bars for Development Completion, Candidate Preflight and Release Orchestrator when those stages actually ran, with clearly labeled seconds and a brief explanation for each. Use one consistent scale. Differentiate overall run wall time from measured gate execution, queue time and overlapping jobs. If a stage is not part of the chosen development path, mark it N/A instead of displaying a fabricated zero. If graphic bars are unavailable, use a compact Markdown table.
4. **Validation table:** show applicable exact PASS/FAIL/BLOCKED/NOT RUN outcomes and available counts for Development Completion, 3/3 Candidate contexts, Windows PowerShell 5.1 parser and functional tests, 8/8 Release contexts, reproducibility, historical ZIP integrity, post-release verification, and branch cleanup. Include other relevant checks when meaningful. Do not claim all gate categories ran merely because the workflow was green.
5. **Findings and bottlenecks:** report observed errors, failed/retried gates, corrective loops, setup/environment limitations, queue delays, and measured critical path; distinguish pipeline defects, external infrastructure, and harmless performance bottlenecks. Explicitly say when no failure was observed. Never treat a local tool limitation as a hosted deployment failure without evidence.
6. **Publication identifiers:** provide version, Issue, PR, source tag/commit, final `main` SHA, release ZIP filename, size and SHA-256, and source ZIP SHA-256 when verified. Link to real GitHub resources. Put long hashes in readable monospace text, rather than stuffing metrics into cards.
7. **Concise conclusion:** state verified success or the exact outstanding blocker, and the operational significance. For an Issue-backed Work-Path, link its canonical cumulative rolling recovery comment/Issue; it remains the durable detail record.

## Visual design preferences

- Favor compact executive-dashboard composition: status, two key number tiles, neutral horizontal performance bars, a compact test table, findings, and publication evidence.
- Use semantic visual distinctions, whitespace, aligned labels and legible numbers rather than decorative graphics.
- Prefer actual UI components when available, but do **not** rely on them for critical meaning. A plain Markdown equivalent is always acceptable.
- Do not promise a pixel-identical or component-identical layout across different clients/models. Avoid decorative images, unnecessary badges, and excessive visual density.
- Keep the response readable on narrow/mobile screens; no oversized table or uncropped hash that obscures other details.
- No speculative percentages, scores, statuses, or timestamps.

## Measurement semantics

- Label the time interval for each reported number. Distinguish **raw durable GitHub end-to-end** (Issue creation to authoritative release-verification summary) from **raw user-authorized end-to-end** (only when its exact start timestamp is observed), **normalized repository-process time** (only when individually verified excluded intervals can be quantified), and individual workflow stage durations.
- Preserve unadjusted raw chronology. Never subtract unknown chat pauses, queues, outages, or other unquantified intervals. Report unavailable instead of estimating.
- Report Linux and Windows as parallel Candidate jobs when applicable. The critical path is the slower complete required job, not the sum of both execution durations. Show queue/setup/test durations separately if available.
- Distinguish Candidate gate elapsed from end-to-end Candidate workflow promotion duration, and Release workflow completion from the timestamp of `RELEASE_VERIFICATION_SUMMARY=PASS`.
- Derive facts from current GitHub/Actions evidence. Prefer machine-readable `DEVELOPMENT_COMPLETION_SUMMARY`, `CANDIDATE_TIMING_SUMMARY`, `RELEASE_PREACTIVATION_SUMMARY` and `RELEASE_VERIFICATION_SUMMARY`; inspect underlying jobs when investigating a failure.
- Clearly separate GitHub-hosted Windows PowerShell 5.1 contract-suite execution from **physical Lenovo hardware/UEFI end-to-end testing**. Never infer the latter from the former.

## Short report skeleton

```text
Build & Deployment: <version> — <verified status>
[Raw duration: <value and interval>] [Failed mandatory gates: <count/unknown>]
Performance: Development Completion | Candidate Preflight | Release Orchestrator
Validation: concise PASS/FAIL/NOT RUN table with actual counts
Findings: issues, remediation, bottlenecks and remaining risks
Publication: Issue | PR | tag | main SHA | ZIP size/hash | branch cleanup
Conclusion: operational result + durable GitHub evidence link
```

A documentation-only change that does not build/deploy a product should instead receive a short documentation-change confirmation, not a synthetic release dashboard. This presentation standard never creates build authorization, changes release scope, or overrides the documentation-only fast-track rule.
