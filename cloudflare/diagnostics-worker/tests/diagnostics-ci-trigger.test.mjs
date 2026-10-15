import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const root = new URL("../../../", import.meta.url);
const read = path => readFileSync(new URL(path, root), "utf8");
const ci = read(".github/workflows/diagnostics-worker-ci.yml");
const release = read(".github/workflows/release.yml");

test("LBS-110 Diagnostics Worker CI triggers only for matching work-branch pushes", () => {
  const triggers = ci.slice(ci.indexOf("\non:\n"), ci.indexOf("\npermissions:\n"));
  assert.match(triggers, /\n  push:\n/);
  assert.match(triggers, /\n    branches:\n      - 'work\/LBS-\*'/);
  assert.match(triggers, /\n    paths:\n/);
  assert.match(triggers, /cloudflare\/diagnostics-worker\/\*\*/);
  assert.match(triggers, /\.github\/workflows\/diagnostics-worker-ci\.yml/);
  assert.doesNotMatch(triggers, /\n  pull_request(?:_target)?:/, "PRs must not trigger additional Diagnostics Worker tests");
  assert.doesNotMatch(triggers, /\n  workflow_dispatch:/, "manual/non-work-branch Diagnostics runs are not authorized");
});

test("LBS-110 retained work-branch gates still run Node, Wrangler and hosted Windows", () => {
  assert.match(ci, /\npermissions:\n  contents: read/);
  assert.match(ci, /persist-credentials: false/);
  assert.match(ci, /node --test cloudflare\/diagnostics-worker\/tests\/\*\.test\.mjs/);
  assert.match(ci, /wrangler@4 deploy --dry-run/);
  assert.match(ci, /windows-identity:/);
  assert.match(ci, /runs-on: windows-2025/);
  assert.match(ci, /Test-WindowsPowerShell51\.ps1/);
  assert.doesNotMatch(ci, /secrets\./);
});

test("LBS-110 Candidate, Release and deployment gates remain independent", () => {
  assert.match(release, /preflight\/candidate/);
  assert.match(release, /preflight\/linux/);
  assert.match(release, /preflight\/windows-powershell51/);
  assert.match(release, /tools\/release_pre_activation\.py/);
  assert.match(release, /tools\/release_verification\.py/);
  assert.match(release, /release\/tag/);
  assert.match(release, /gh pr create/);
  assert.match(release, /gh pr merge/);
  const worker = read(".github/workflows/deploy-diagnostics-worker.yml");
  assert.match(worker, /node --test cloudflare\/diagnostics-worker\/tests\/\*\.test\.mjs/);
  assert.match(worker, /wrangler@4 deploy --dry-run/);
});
