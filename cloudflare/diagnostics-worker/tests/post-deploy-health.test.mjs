import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verifyPostDeployHealth, RETRY_POLICY } from "../scripts/verify-post-deploy-health.mjs";

const SHA="a".repeat(64), OLD="b".repeat(64), SERVICE="lenovo-boot-selector-diagnostics";
const before={service:SERVICE,ingestionEnabled:false,deploymentFingerprint:OLD};
const health=(fingerprint=SHA,ingestionEnabled=false)=>({service:SERVICE,ingestionEnabled,deploymentFingerprint:fingerprint});
const ok=h=>new Response(JSON.stringify(h),{status:200});
const response=status=>new Response("transient",{status});
function scenario(values,options={}){
 let i=0, clock=0;const sleeps=[],events=[];
 return {sleeps,events,get calls(){return i;},run:()=>verifyPostDeployHealth({
  targetFingerprint:SHA,before,
  getHealth:async()=>{const value=values[i++];if(value instanceof Error)throw value;if(value===undefined)throw Error("unexpected_extra_probe");return value;},
  sleep:async ms=>{sleeps.push(ms);clock+=ms;},now:()=>clock,
  onAttempt:e=>events.push(e),...options,
 })};
}
test("LBS-125 retries stale HTTP 200 fingerprint then succeeds only on all health invariants",async()=>{
 const t=scenario([ok(health(OLD)),ok(health(OLD)),ok(health())]);
 assert.equal((await t.run()).attempts,3);
 assert.deepEqual(t.sleeps,RETRY_POLICY.delaysMs.slice(0,2));
 assert.deepEqual(t.events.map(e=>e.category),["fingerprint_stale","fingerprint_stale","verified"]);
});
test("LBS-125 returns immediately on healthy Worker without sleeping",async()=>{
 const t=scenario([ok(health())]);assert.equal((await t.run()).attempts,1);assert.deepEqual(t.sleeps,[]);
});
test("LBS-125 transient HTTP and transport errors retry without production writes",async()=>{
 const t=scenario([response(503),new Error("ECONNRESET"),ok(health())]);
 assert.equal((await t.run()).attempts,3);
 assert.deepEqual(t.events.map(e=>e.category),["http_transient","transport_transient","verified"]);
});
test("LBS-125 permanent fingerprint mismatch exhausts fixed attempts and stays failed",async()=>{
 const t=scenario(Array.from({length:RETRY_POLICY.maxAttempts},()=>ok(health(OLD))));
 await assert.rejects(t.run(),/post_deploy_health_retry_exhausted:fingerprint_stale/);
 assert.equal(t.calls,RETRY_POLICY.maxAttempts);
 assert.deepEqual(t.sleeps,RETRY_POLICY.delaysMs);
});
test("LBS-125 invalid service, upload drift, malformed state or fingerprint fail closed immediately",async()=>{
 for(const invalid of [{...health(),service:"other"},health(SHA,true),{...health(),ingestionEnabled:"false"},{...health(),deploymentFingerprint:"bad"}]){
  const t=scenario([ok(invalid),ok(health())]);
  await assert.rejects(t.run(),/post_deploy_health_blocked/);
  assert.equal(t.calls,1);assert.deepEqual(t.sleeps,[]);
 }
});
test("LBS-125 invalid baseline/target, non-transient HTTP and malformed JSON never pass",async()=>{
 for(const opts of [{before:{service:SERVICE,ingestionEnabled:"false"}},{targetFingerprint:"bad"}]){
  const t=scenario([ok(health())],opts);await assert.rejects(t.run(),/post_deploy_health_blocked/);assert.equal(t.calls,0);
 }
 for(const res of [response(401),new Response("not-json",{status:200})]){
  const t=scenario([res,ok(health())]);await assert.rejects(t.run(),/post_deploy_health_blocked/);assert.equal(t.calls,1);
 }
});
test("LBS-125 retry must stop when total time budget is already exhausted",async()=>{
 let clocks=0;const t=scenario([ok(health(OLD)),ok(health())],{now:()=>clocks++<2?0:100000});
 await assert.rejects(t.run(),/post_deploy_health_retry_exhausted/);assert.equal(t.calls,1);
});
test("LBS-125 workflow uses bounded helper only after Wrangler and before success receipt",()=>{
 const s=readFileSync(new URL("../../../.github/workflows/deploy-diagnostics-worker.yml",import.meta.url),"utf8");
 const deploy=s.indexOf("      - name: Deploy verified main to Cloudflare");
 const verify=s.indexOf("      - name: Verify health and preserved upload configuration");
 const receipt=s.indexOf("      - name: Commit successful production deployment receipt");
 assert.ok(deploy>=0&&verify>deploy&&receipt>verify);
 assert.match(s.slice(verify,receipt),/node cloudflare\/diagnostics-worker\/scripts\/verify-post-deploy-health\.mjs/);
 assert.doesNotMatch(s.slice(verify,receipt),/wrangler deploy|gh api --method POST/);
 assert.match(s,/if: failure\(\) && steps\.receipt\.outputs\.id != ''/);
});
test("LBS-125 new health verifier belongs to production fingerprint allowlist",()=>{
 const s=readFileSync(new URL("../scripts/deployment-plan.mjs",import.meta.url),"utf8");
 assert.ok(s.includes('"cloudflare/diagnostics-worker/scripts/verify-post-deploy-health.mjs"'));
});