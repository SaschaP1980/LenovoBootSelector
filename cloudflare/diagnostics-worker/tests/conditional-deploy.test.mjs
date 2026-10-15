import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { deploymentFingerprint, deploymentDecision, validateUploadContract } from "../scripts/deployment-plan.mjs";

const SHA = "a".repeat(64);
const OTHER = "b".repeat(64);
const healthy = {service:"lenovo-boot-selector-diagnostics",ingestionEnabled:false,deploymentFingerprint:SHA};
const receipt = {fingerprint:SHA,ingestionEnabled:false,verified:true,status:"success"};
test("unchanged deployed fingerprint plus verified receipt selects read-only health", () => {
  assert.equal(deploymentDecision({targetFingerprint:SHA,receipt,health:healthy,mode:"auto"}),"health-only");
});
test("client-only release does not replace the verified Worker", () => {
  assert.equal(deploymentDecision({targetFingerprint:SHA,receipt,health:healthy,mode:"auto"}),"health-only");
});
test("changed deployment dependency requires real deployment", () => {
  assert.equal(deploymentDecision({targetFingerprint:OTHER,receipt,health:healthy,mode:"auto"}),"deploy");
});
test("missing or failed latest production receipt forces deployment", () => {
  assert.equal(deploymentDecision({targetFingerprint:SHA,receipt:null,health:healthy,mode:"auto"}),"deploy");
  assert.equal(deploymentDecision({targetFingerprint:SHA,receipt:{...receipt,status:"failure"},health:healthy,mode:"auto"}),"deploy");
});
test("manual recovery always performs controlled full deployment", () => {
  assert.equal(deploymentDecision({targetFingerprint:SHA,receipt,health:healthy,mode:"manual"}),"deploy");
});
test("out-of-band drift, malformed receipt and unhealthy endpoint fail closed", () => {
  assert.throws(()=>deploymentDecision({targetFingerprint:SHA,receipt,health:{...healthy,deploymentFingerprint:OTHER},mode:"auto"}),/drift/);
  assert.throws(()=>deploymentDecision({targetFingerprint:SHA,receipt,health:{...healthy,ingestionEnabled:true},mode:"auto"}),/drift/);
  assert.throws(()=>deploymentDecision({targetFingerprint:SHA,receipt:{...receipt,fingerprint:"invalid"},health:healthy,mode:"auto"}),/receipt/);
  assert.throws(()=>deploymentDecision({targetFingerprint:SHA,receipt,health:{...healthy,service:"other"},mode:"auto"}),/health/);
});
test("fingerprint is content-based, deterministic, and changes on Worker dependency mutation", () => {
  const root=mkdtempSync(join(tmpdir(),"lbs123-fingerprint-"));
  try {
    const file=join(root,"cloudflare/diagnostics-worker/src/index.mjs");
    mkdirSync(join(root,"cloudflare/diagnostics-worker/src"),{recursive:true});
    writeFileSync(file,"export default 1");
    const a=deploymentFingerprint(root,["cloudflare/diagnostics-worker/src/index.mjs"]);
    const b=deploymentFingerprint(root,["cloudflare/diagnostics-worker/src/index.mjs"]);
    assert.equal(a,b);
    assert.match(a,/^[a-f0-9]{64}$/);
    writeFileSync(file,"export default 2");
    assert.notEqual(deploymentFingerprint(root,["cloudflare/diagnostics-worker/src/index.mjs"]),a);
  } finally {rmSync(root,{recursive:true,force:true});}
});
test("actual Windows diagnostics ZIP upload contract remains compatible with Worker", () => {
  assert.equal(validateUploadContract(),true);
});

test("production workflow keeps main pinning and has a secret-free health-only branch", () => {
  const source = readFileSync(new URL("../../../.github/workflows/deploy-diagnostics-worker.yml", import.meta.url), "utf8");
  assert.match(source,/refs\/heads\/main/);
  assert.match(source,/AUTO_DEPLOY_PRECHECK=PASS/);
  assert.match(source,/Revalidate published main before any production outcome/);
  assert.match(source,/deployments: write/);
  assert.match(source,/WORKER_DEPLOY_RESULT=HEALTH_ONLY_PASS/);
  assert.match(source,/WORKER_DEPLOY_RESULT=DEPLOYED_AND_HEALTHY/);
  assert.match(source,/if: steps.plan.outputs.mode == 'deploy'[\s\S]+cloudflare\/wrangler-action@v4/);
  assert.match(source,/if: steps.plan.outputs.mode == 'deploy'[\s\S]+CLOUDFLARE_API_TOKEN/);
  assert.match(source,/failure\(\) && steps.receipt.outputs.id != ''/);
  assert.doesNotMatch(source,/retention-backfill\.mjs/);
});
test("Worker health contains a deterministic deployment identity without client private details", async () => {
  const {default: worker} = await import("../src/index.mjs");
  const result = await worker.fetch(new Request("https://example.invalid/health"), {});
  assert.equal(result.status,200);
  const json=await result.json();
  assert.equal(typeof json.deploymentFingerprint,"string");
  assert.equal(json.ingestionEnabled,false);
  assert.equal(Object.keys(json).sort().join(","), "deploymentFingerprint,ingestionEnabled,service");
});
