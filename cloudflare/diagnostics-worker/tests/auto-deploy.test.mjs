import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const root = new URL("../../../", import.meta.url);
const source = path => readFileSync(new URL(path, root), "utf8");
const release = () => source(".github/workflows/release.yml");
const worker = () => source(".github/workflows/deploy-diagnostics-worker.yml");

test("release orchestrator dispatches the privileged worker job ONLY after successful final release verification", () => {
  const s = release();
  const done = s.indexOf("tools/release_verification.py");
  const dispatch = s.indexOf("gh workflow run deploy-diagnostics-worker.yml");
  assert.ok(done >= 0 && dispatch > done, "release verified before deployment dispatch");
  assert.match(s, /actions:\s*write/);
  assert.match(s, /-f\s+expected_main_sha=/);
  assert.match(s, /-f\s+expected_version=/);
  assert.match(s, /-f\s+confirm=deploy-diagnostics-worker/);
});

test("worker deployment requires exact released main SHA, released version, and package checksum", () => {
  const s = worker();
  assert.match(s, /expected_main_sha:/);
  assert.match(s, /expected_version:/);
  assert.match(s, /refs\/heads\/main/);
  assert.match(s, /downloads\/latest\.json/);
  assert.match(s, /sha256sum/);
  assert.match(s, /refs\/tags\/v/);
  assert.match(s, /CLOUDFLARE_API_TOKEN/);
  assert.match(s, /CLOUDFLARE_ACCOUNT_ID/);
});

test("deployment does not bypass Node/Wrangler tests and performs post-deploy health verification", () => {
  const s = worker();
  const testAt = s.indexOf("node --test cloudflare/diagnostics-worker/tests/*.test.mjs");
  const dry = s.indexOf("deploy --dry-run");
  const deploy = s.indexOf("cloudflare/wrangler-action@v4");
  const health = s.lastIndexOf("/health");
  assert.ok(testAt >= 0 && dry > testAt && deploy > dry && health > deploy);
  assert.match(s, /cancel-in-progress:\s*false/);
  assert.match(s, /deploy-diagnostics-worker/);
  assert.doesNotMatch(s, /retention-backfill\.mjs/);
  assert.doesNotMatch(s, /workflow_run:/);
});

test("existing manual recovery dispatch remains gated and automatic flow uses only main", () => {
  const s = worker();
  assert.match(s, /workflow_dispatch:/);
  assert.match(s, /github\.ref\s*==\s*'refs\/heads\/main'/);
  assert.match(s, /inputs\.confirm\s*==\s*'deploy-diagnostics-worker'/);
  assert.match(s, /persist-credentials:\s*false/);
});
