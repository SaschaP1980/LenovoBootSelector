# Lenovo Boot Selector diagnostics service — LBS-103

[Issue #103](https://github.com/SaschaP1980/LenovoBootSelector/issues/103) governs the implementation. The source lives in the existing product repository, but **diagnostic archives never belong in its public Git tree**.

## Implementation state

- The Worker/KV/SQLite Durable Object service and project-scoped archive keys were released/deployed in v0.11.0.1. v0.11.1.0 adds server-generated copyable Diagnosis IDs and a private KV reference for ChatGPT lookup. Target v0.11.1.1 adds automatic ZIP expiration and separately authorized historical migration. Publishing source, deploying the Worker and mutating historical KV are separate operator actions.
- The owner verified live anonymous ZIP upload, owner-authorized listing, complete four-file text/ZIP readback with SHA-256 integrity, and a native LBS upload. No automatic deployment is performed when GitHub source changes.
- `GET /health` is public and contains **no archive contents or secrets**.
- `POST /v1/diagnostics` is **disabled by default**. It returns HTTP 503 until `ENABLE_DIAGNOSTIC_UPLOAD` is exactly `true` **and** a valid `DIAGNOSTICS_READ_TOKEN` is provisioned.
- `GET /v1/archives`, `GET /v1/archives/entries` and `GET /v1/archives/zip` require `Authorization: Bearer <owner secret>`. The list filters on installation UUID; the entries endpoint returns all four canonical decoded diagnostic files; ZIP returns the unchanged stored binary.
- Sender requires **no GitHub account**. The Windows UI starts uploads **only after clicking** `Maintenance → Upload Diagnostics`, directly below `Save Diagnostics`.

## Data integrity and storage policy

| Contract | Limit or behavior |
|---|---|
| Upload ZIP | Max **2 MiB** (2,097,152 bytes); strictly canonical four-entry ZIP validated before any mutation |
| Total archives | Max **500 MiB** (524,288,000 bytes) of live ZIP records |
| Per-installation history | **20 ZIPs** for each persisted random UUID, rotating oldest-first |
| Retention (new target) | **90 days**; ZIP and ID reference share absolute native KV expiration. Owner read endpoints reject records at exact millisecond deadline independently of new uploads |
| Global capacity | Evict globally oldest records if needed for the incoming ZIP |
| Abuse protection | **6 accepted admissions per IP-hash/hour**, **30 accepted admissions globally/day**, via durable SQLite counters |
| Storage cleanup | Each new admission first repairs pending writes and drains tombstones; a failed write does not displace committed older ZIP records |
| Privileged operations | **None**. This service must not affect boot selection, TaskBroker, firmware, updates or app startup. |
| Monetary policy | **Workers Free / KV Free / SQLite Durable Objects Free only**; do not upgrade to a paid account to make tests pass |

Cloudflare Workers KV has eventual-consistency limitations; the SQLite Durable Object is the source of truth for history and serialized admission. The owner verified the v0.11.1.0 live private Diagnosis-ID lookup and ZIP integrity. Native ZIP expiry and historical backfill are separate v0.11.1.1 acceptance objectives.

## Credentials and private access

**GitHub Actions secrets** (deployment only, reported set by the owner; values cannot be verified through the connector):

- `CLOUDFLARE_API_TOKEN`: owner-created account-scoped deployment token
- `CLOUDFLARE_ACCOUNT_ID`: owner account ID

**Cloudflare Worker configuration** (must be created in the Cloudflare dashboard / encrypted settings by the owner or secure deployment tooling; **do not add them to GitHub source or Issues**):

- `DIAGNOSTICS_READ_TOKEN`: strong random secret, minimum 32 characters, used only to authorize private listing and downloads.
- `ENABLE_DIAGNOSTIC_UPLOAD`: optional `"true"` flag. **Leave absent/false** until all tests, review, abuse-risk assessment and real readback gate succeed.

Never send any token into ChatGPT, screenshots, GitHub Issues, PR comments, CI logs or the Lenovo client. The browser UI does not currently support a one-click owner session. **ChatGPT private direct ZIP read is verified for the original synthetic fixture** using the official Cloudflare OAuth plugin; the new ID lookup needs its own post-deployment readback. Do not mistake a Bearer-protected HTTP URL alone for an installed ChatGPT connector.

## HTTP contract

- `POST /v1/diagnostics`: `Content-Type: application/zip`, `x-installation-uuid: <uuid-v4>`, ZIP body; success `201` returns `status`, `key`, `diagnosisId`, `sha256`, `sizeBytes`. Other responses include `400` (invalid ZIP/UUID), `413` (oversized), `415` (media type), `429` (rate limit), `503` (disabled/storage fault).
- `GET /v1/archives?uuid=<uuid-v4>`: owner-authenticated list.
- `GET /v1/archives/entries?key=<encoded-key>`: owner-authenticated JSON containing `metadata` and all four decoded UTF-8 diagnostic file contents.
- `GET /v1/archives/zip?key=<encoded-key>`: owner-authenticated, unmodified ZIP binary.
- **New uploads:** `Diagnose/LBS/<uuid>/<UTC_TIMESTAMP>.zip`, UTC with milliseconds (e.g. `20261014T102339852Z`), with the UUID only in its parent folder. The `LBS` project is fixed server-side; client-supplied arbitrary project paths are forbidden. **Legacy objects:** `Diagnose/<uuid>/<uuid>_<UTC_TIMESTAMP>.zip` remain in KV with their original keys, and can still be listed, read and rotated alongside new objects under the same 20-record LBS installation quota. This change does not physically relocate or delete old ZIPs. Other future project prefixes require explicit server-owned project registration and segregated per-project identity/quota handling.
- **Diagnosis ID (new in v0.11.1.0):** Each committed upload receives a server-generated `LBS-XXXXX-XXXXX-XXXXX-XXXXX` identifier. Its private JSON lookup object is stored at `Diagnose/Refs/LBS/<DIAGNOSIS_ID>` with project, immutable archive key, SHA-256 and expiry metadata. The same existing KV namespace is reused; no new public endpoint is created. Authorized ChatGPT users with Workers KV Storage Read resolve the exact reference key, verify its fields/expiry, retrieve the referenced original ZIP bytes privately and analyze the canonical four files. A Diagnosis ID is not a password; existing Cloudflare OAuth permissions still apply. Archive keys are **never renamed** for the new feature; historical archives without a reference remain accessible by their existing owner UUID/key routes. On rotation and global eviction, reference and original ZIP are retired together with durable cleanup; new ZIP/reference entries additionally expire automatically with matching absolute KV expiration. The source archive remains authoritative in SQLite; the reference is a read-only lookup convenience.
- **Capacity impact:** One small additional KV write per accepted upload plus matching deletion/expiry. The Cloudflare Workers KV Free budget is currently 1,000 writes/day, 1,000 deletes/day, 1,000 list operations/day, 100,000 reads/day and 1 GiB storage (https://developers.cloudflare.com/workers/platform/pricing/). Stay on Free; quota exhaustion must not create fake success or billable upgrades.

**Important:** Do not activate upload merely to test a path from ChatGPT. First use a private, scoped connection and a synthetic fixture ZIP. Avoid sending real diagnostic data to any tool not covered by the chosen authorized read path.

## Retention backfill: operator-only, never automatic

New v0.11.1.1 uploads put the immutable ZIP and its reference with the **same** absolute KV expiry: 90 days after the actual admission timestamp, rounded **up** to whole UNIX seconds. Neither a filename collision nor a repeated read extends that deadline. Owner-authenticated listing/text/ZIP paths independently reject expired SQLite records at exact millisecond resolution. SQLite historical rows are lazily cleaned at the next safe admission, whereas ZIP/reference data expire natively even if no further admissions occur.

The new **read-only** endpoint `GET /v1/maintenance/inventory?limit=100&cursor=...` requires the existing owner Bearer token and pages over authoritative committed SQLite metadata, including expired records. There is **no administrative mutation endpoint**.

Historical ZIPs that predate native expiry require an **explicit one-time, dry-run-first migration**, implemented in `scripts/retention-backfill.mjs`. The script is not deployed as a Worker route or invoked from normal uploads, app startup, CI, source publication, or Worker deployment. It supports both legacy and LBS project-scoped archive layouts and never changes archive filenames or bytes.

**Operator acceptance procedure (outside ChatGPT):**

1. Complete normal source release and separately deploy Worker on `main` using the existing manual workflow. Verify `GET /health` and private authorized archive lookup first.
2. Temporarily disable uploads by setting `ENABLE_DIAGNOSTIC_UPLOAD=false` in the existing private Worker configuration. Verify `/health` returns `ingestionEnabled:false`; wait **at least 120 seconds**, confirm no in-flight upload remains, and maintain a quiet maintenance window until the entire migration finishes. User-initiated uploads return 503 during this window.
3. In a trusted local operator environment, supply `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_KV_NAMESPACE_ID`, `CLOUDFLARE_API_TOKEN` (Workers KV read/write/delete), `DIAGNOSTICS_READ_TOKEN` (existing owner-only private reader) and `DIAGNOSTICS_WORKER_URL` (HTTPS URL). **Never paste credentials in chat, Issues, CI logs or command arguments.** The existing read-only ChatGPT Cloudflare OAuth connection is intentionally not sufficient for migration.
4. Run the default **dry-run**: `node cloudflare/diagnostics-worker/scripts/retention-backfill.mjs`. Review aggregate-only counts, historical ledger/KV parity, Free-tier quota headroom and required operation budget. The script rejects unowned LBS archive keys, incorrect bytes/keys, duplicate records and unexpectedly missing live archives instead of guessing or re-creating them.
5. Only after a separate explicit owner decision to change historical KV, run a bounded batch: `node cloudflare/diagnostics-worker/scripts/retention-backfill.mjs --apply --uploads-paused-120s --max-mutations=100`. Repeat dry-run / apply until it reports no remaining migrations. A key with less than 60 seconds left is **not** deleted early or artificially extended: wait until its deadline and rerun. Batches are capped at 200 KV mutations maximum.
6. Verify original and resulting ZIP SHA-256 integrity, reference/ZIP expiry metadata, owner access and expected ledger state; resume uploads only after the complete migration review. If anything fails or a quota is nearly exhausted, keep uploads paused and investigate before proceeding.

Cloudflare uses whole-second expiry and enforces at least 60 seconds of remaining lifetime when a new expiry is set. Do **not** backdate, reset expiry relative to migration time, or rewrite keys during an active upload. No paid service, cron, new namespace, public ZIP endpoint or elevated ChatGPT rights are required.

Sources: [Cloudflare KV expiration](https://developers.cloudflare.com/kv/api/write-key-value-pairs/#expiring-keys), [Cloudflare KV Free limits](https://developers.cloudflare.com/kv/platform/limits/).

## Build and deployment

The checked-in `wrangler.jsonc` declares the existing `DIAGNOSTICS_KV` binding and a `DIAGNOSTICS_COORDINATOR` class with SQLite storage.

`.github/workflows/diagnostics-worker-ci.yml` tests the Work-Branch and PRs using Node 22, a Wrangler 4 `--dry-run`, and Windows PowerShell 5.1 without production secrets. As of 2026-10-14, the hosted CI passed **33/33 Node tests** at commit `e40e4e8a7ef3ea12e89e37899464548f192c8e9a`, plus Windows and dry-run gates. Any source change invalidates that precise test result until rerun.

`.github/workflows/deploy-diagnostics-worker.yml` is `workflow_dispatch` only, restricted to `main` and explicit dropdown confirmation. It consumes the two Actions secrets, runs tests, and deploys with Wrangler. The production code cannot be deployed through that workflow until it has completed the existing LBS Work-Branch / Development Completion / Candidate / Release process and reached canonical `main`. **Do not auto-deploy on push or untrusted PRs**.

Local source validation (Node 22+):
```sh
node --test cloudflare/diagnostics-worker/tests/*.test.mjs
cd cloudflare/diagnostics-worker
npx --yes wrangler@4 deploy --dry-run
```

The v0.11.0.0 product and Cloudflare service were released and tested with real Windows uploads and owner private readback. v0.11.0.1's project-scoped key layout is live. The v0.11.1.0 Diagnosis ID extension remains a source/deployment change until separately released and manually deployed; direct private ChatGPT reads already work for historical synthetic ZIPs.
