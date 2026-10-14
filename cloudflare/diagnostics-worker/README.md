# Lenovo Boot Selector diagnostics service — LBS-103

[Issue #103](https://github.com/SaschaP1980/LenovoBootSelector/issues/103) governs the implementation. The source lives in the existing product repository, but **diagnostic archives never belong in its public Git tree**.

## Implementation state

- A Cloudflare Worker + Workers KV + SQLite-backed Durable Object service is implemented on `work/LBS-103`, using the owner's existing KV namespace and the declarative Durable Object binding.
- The **production Cloudflare Worker is still the user's original Hello World scaffold**, not this implementation. A successful Wrangler `--dry-run` does not deploy anything.
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
| Retention | **90 days**; expiry at the next successful admission attempt |
| Global capacity | Evict globally oldest records if needed for the incoming ZIP |
| Abuse protection | **6 accepted admissions per IP-hash/hour**, **30 accepted admissions globally/day**, via durable SQLite counters |
| Storage cleanup | Each new admission first repairs pending writes and drains tombstones; a failed write does not displace committed older ZIP records |
| Privileged operations | **None**. This service must not affect boot selection, TaskBroker, firmware, updates or app startup. |
| Monetary policy | **Workers Free / KV Free / SQLite Durable Objects Free only**; do not upgrade to a paid account to make tests pass |

Cloudflare Workers KV has eventual-consistency limitations; the SQLite Durable Object is the source of truth for history and serialized admission. **No cloud runtime end-to-end acceptance has occurred yet**, so operational assumptions must be checked before enabling uploads.

## Credentials and private access

**GitHub Actions secrets** (deployment only, reported set by the owner; values cannot be verified through the connector):

- `CLOUDFLARE_API_TOKEN`: owner-created account-scoped deployment token
- `CLOUDFLARE_ACCOUNT_ID`: owner account ID

**Cloudflare Worker configuration** (must be created in the Cloudflare dashboard / encrypted settings by the owner or secure deployment tooling; **do not add them to GitHub source or Issues**):

- `DIAGNOSTICS_READ_TOKEN`: strong random secret, minimum 32 characters, used only to authorize private listing and downloads.
- `ENABLE_DIAGNOSTIC_UPLOAD`: optional `"true"` flag. **Leave absent/false** until all tests, review, abuse-risk assessment and real readback gate succeed.

Never send any token into ChatGPT, screenshots, GitHub Issues, PR comments, CI logs or the Lenovo client. The browser UI does not currently support a one-click owner session. **ChatGPT direct private retrieval remains a separate acceptance gate**: an authenticated connector or equally secure text/ZIP access mechanism must be demonstrably usable in the real ChatGPT runtime before Issue closure. Do not mistake a Bearer-protected HTTP URL alone for an installed ChatGPT connector.

## HTTP contract

- `POST /v1/diagnostics`: `Content-Type: application/zip`, `x-installation-uuid: <uuid-v4>`, ZIP body; success `201` returns `status`, `key`, `sha256`, `sizeBytes`. Other responses include `400` (invalid ZIP/UUID), `413` (oversized), `415` (media type), `429` (rate limit), `503` (disabled/storage fault).
- `GET /v1/archives?uuid=<uuid-v4>`: owner-authenticated list.
- `GET /v1/archives/entries?key=<encoded-key>`: owner-authenticated JSON containing `metadata` and all four decoded UTF-8 diagnostic file contents.
- `GET /v1/archives/zip?key=<encoded-key>`: owner-authenticated, unmodified ZIP binary.
- URLs/keys always refer to the `Diagnose/<uuid>/<uuid>_<UTC_TIMESTAMP>.zip` storage namespace; key names are never accepted directly from untrusted upload headers.

**Important:** Do not activate upload merely to test a path from ChatGPT. First use a private, scoped connection and a synthetic fixture ZIP. Avoid sending real diagnostic data to any tool not covered by the chosen authorized read path.

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

Product smoke and owner ChatGPT readback are required before Issue #103 is closed. There is no production deployment or verified private ChatGPT integration yet.
