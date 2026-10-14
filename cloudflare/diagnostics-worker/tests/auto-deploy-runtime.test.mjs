import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";

const workflowPath = fileURLToPath(new URL("../../../.github/workflows/deploy-diagnostics-worker.yml", import.meta.url));
const yaml = readFileSync(workflowPath, "utf8");
const a = yaml.indexOf("      - name: Validate released main and immutable package before using secrets");
const b = yaml.indexOf("      - name: Validate Worker source", a);
if (a < 0 || b <= a) throw Error("deployment_gate_not_located");
const step = yaml.slice(a, b);
const mark = "        run: |\n";
const offset = step.indexOf(mark);
if (offset < 0) throw Error("deployment_gate_not_executable");
const bashScript = step.slice(offset + mark.length).split("\n")
  .map(line => line.startsWith("          ") ? line.slice(10) : line).join("\n");

const VERSION = "0.11.1.2";
const zipName = "LenovoBootMenuTray-v" + VERSION + ".zip";
function fixture() {
  const dir = mkdtempSync(join(tmpdir(), "lbs108-released-gate-"));
  const git = (...args) => execFileSync("git", args, { cwd: dir, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
  mkdirSync(join(dir, "bin"), { recursive: true });
  mkdirSync(join(dir, "downloads"), { recursive: true });
  const bytes = Buffer.from("synthetic-only-release-zip");
  const sha = createHash("sha256").update(bytes).digest("hex");
  writeFileSync(join(dir, "bin", "version.json"), JSON.stringify({ version: VERSION }));
  writeFileSync(join(dir, "downloads", zipName), bytes);
  const latest = { version: VERSION, tag: "v" + VERSION, file: zipName, sha256: sha, size: bytes.length };
  const latestPath = join(dir, "downloads", "latest.json");
  writeFileSync(latestPath, JSON.stringify(latest));
  git("init", "-q");
  git("config", "user.email", "test@example.invalid");
  git("config", "user.name", "LBS Regression");
  git("add", ".");
  git("commit", "-qm", "synthetic sealed release");
  git("tag", "-a", "v" + VERSION, "-m", "synthetic sealed release");
  const shaCommit = git("rev-parse", "HEAD");
  function execute(expectedSha = shaCommit, expectedVersion = VERSION) {
    return spawnSync("bash", ["-e", "-c", bashScript], {
      cwd: dir, encoding: "utf8",
      env: { ...process.env, EXPECTED_MAIN_SHA: expectedSha, EXPECTED_VERSION: expectedVersion },
      timeout: 7000,
    });
  }
  return { dir, shaCommit, latest, latestPath, git, execute, zipFile:join(dir, "downloads", zipName) };
}
function inFixture(cb) {
  const f = fixture();
  try { cb(f); } finally { rmSync(f.dir, { recursive: true, force: true }); }
}

test("real shell pre-deployment gate accepts only matching published main/sha/ZIP and source tag", () => {
  inFixture(f => {
    const run = f.execute();
    assert.equal(run.status, 0, run.stderr);
    assert.match(run.stdout, /AUTO_DEPLOY_PRECHECK=PASS/);
  });
});
test("stale released-main SHA and forged version are both rejected before secret access", () => {
  inFixture(f => {
    assert.notEqual(f.execute("0".repeat(40), VERSION).status, 0);
    assert.notEqual(f.execute(f.shaCommit, "0.11.1.1").status, 0);
    assert.notEqual(f.execute("invalid-sha", VERSION).status, 0);
    assert.notEqual(f.execute(f.shaCommit, "malicious;touch /tmp/lbs108-fail").status, 0);
  });
});
test("incomplete auto-release handoff fails closed instead of silently falling back to manual", () => {
  inFixture(f => {
    assert.notEqual(f.execute("", VERSION).status, 0);
    assert.notEqual(f.execute(f.shaCommit, "").status, 0);
    assert.equal(f.execute("", "").status, 0, "explicit manually authorized recovery remains allowed");
  });
});
test("package tampering and mismatched latest metadata or missing source tag all block deployment", () => {
  inFixture(f => {
    writeFileSync(f.zipFile, "tampered-package");
    assert.notEqual(f.execute().status, 0);
  });
  inFixture(f => {
    writeFileSync(f.latestPath, JSON.stringify({ ...f.latest, version: "0.11.1.1" }));
    assert.notEqual(f.execute().status, 0);
  });
  inFixture(f => {
    f.git("tag", "-d", "v" + VERSION);
    assert.notEqual(f.execute().status, 0);
  });
});
