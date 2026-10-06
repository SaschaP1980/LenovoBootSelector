# Release process

From v0.5.10.0 onward the canonical release model is **1 build = 1 release branch = 1 pull request = 1 merge**.

Operational companion for ChatGPT/release supervision: [`GITHUB_HOWTO.md`](GITHUB_HOWTO.md).

## Canonical inputs

- `bin/version.json` is the only authoritative release-version source. Schema v2 intentionally contains no `publishedUtc`.
- `releaseProfile` selects regression strictness (`version-only`, `release-architecture`, `patch`).
- Product runtime receives the version only through the `@APP_VERSION@` token during deterministic runtime generation.
- `tools/prepare_release.py` owns generated release metadata and packages. For schema v2, publication time must be supplied explicitly with `--published-utc`.
- Canonical `publishedUtc` is owned by GitHub: the Release Orchestrator captures one UTC timestamp only after the hosted runner is executing the publication job and reuses that exact value for both deterministic rebuilds. Local preparation timestamps are provisional and are never committed as canonical publication metadata.

## Local release preparation

1. Change `bin/version.json` and add the corresponding `CHANGELOG.md` section.
2. Run `python -B tools/prepare_release.py --root . --output-dir <dir> --published-utc <provisional-UTC>` for local validation only.
3. Run the four permanent validators: `validate_release.py`, `validate_core.py`, `validate_boundary.py`, `validate_regression.py`.
4. Push the canonical input changes to `release/v<version>`; do not add the new release ZIP manually. Generated runtime/audit/metadata files may already be present from the local build, but GitHub recreates them deterministically before the PR commit.

## GitHub publication

`release.yml` runs on `release/**`. Once a hosted runner is actually executing the job, it captures the canonical `publishedUtc`, then deterministically recreates all generated release files from the canonical inputs plus that single GitHub-owned timestamp. It verifies a second in-run rebuild byte-for-byte, derives a ZIP-free source commit without creating a source branch, adds exactly one new historical release ZIP to the same release branch and opens exactly one pull request.

The single permanent `release.yml` workflow runs the full release/core/boundary/regression gates itself before PR creation, writes the successful gate states directly onto the final PR-head commit, creates the annotated ZIP-free source tag only after successful PR creation, then merges the PR and deletes the release branch. A separate `pull_request` workflow is intentionally not used: pull requests created with the repository `GITHUB_TOKEN` do not recursively start another workflow.

There is no version-specific workflow, separate PR-verification workflow, Base64 patch transport, helper source branch, required post-merge finalizer, or per-version validator copy.

## Historical ZIP invariant

Existing `downloads/*.zip` files are immutable. A release may add exactly one new ZIP. Existing ZIPs may not be modified, deleted, or temporarily removed/re-added.

## Performance targets

- Version-only hotfix: target <= 5 minutes, limit 10 minutes from start to merged PR, excluding external GitHub incidents.
- Small patch: target <= 10 minutes, limit 15 minutes when no native Windows acceptance is required.

## Runner queue policy

Interactive release supervision waits at most 60 seconds for a GitHub-hosted runner assignment. If the job is still `queued` with no runner after that window, the condition is reported as external GitHub queue delay. The workflow is not cancelled, retried or duplicated; GitHub continues autonomously. A later `Github Status` check verifies the terminal state.


## Repository/runtime layout

Repository runtime/release source files live under `bin/`. The downloadable Release ZIP intentionally remains a flat 10-file package: packaging maps the `bin/` source files back to their established top-level archive names. Architecture baselines live under `docs/architecture/`; catch audits live under `audits/`. The canonical generated files are `docs/architecture/ARCHITECTURE_BASELINE.json` and `audits/CATCH_AUDIT.json`; historical versioned snapshots remain alongside them.
