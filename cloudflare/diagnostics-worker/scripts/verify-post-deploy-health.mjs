import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { performance } from "node:perf_hooks";
import { setTimeout as delay } from "node:timers/promises";

// Trusted post-deploy read-only verification; no deployment, receipts or secrets.
const SERVICE = "lenovo-boot-selector-diagnostics";
const URL = "https://lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev/health";
const SHA = /^[0-9a-f]{64}$/;
const RETRYABLE_HTTP = new Set([429, 502, 503, 504]);
export const RETRY_POLICY = Object.freeze({
  maxAttempts: 5,
  requestTimeoutMs: 8000,
  delaysMs: Object.freeze([2000, 4000, 6000, 8000]),
  totalBudgetMs: 70000,
});

function blocked(category) {
  return new Error("post_deploy_health_blocked:" + category);
}
function exhausted(category) {
  return new Error("post_deploy_health_retry_exhausted:" + category);
}
function isHealthShape(health) {
  return health && typeof health === "object" && !Array.isArray(health) &&
    health.service === SERVICE && typeof health.ingestionEnabled === "boolean";
}

/**
 * Complete, finite, read-only verification on every attempt, including 200/old-fingerprint.
 * Injected request/clock/sleep permit permanent deterministic regression tests.
 * A successful result NEVER creates or mutates a production deployment receipt.
 */
export async function verifyPostDeployHealth({
  targetFingerprint, before, getHealth, sleep = delay, now = () => performance.now(),
  onAttempt = () => {}, policy = RETRY_POLICY,
}) {
  if (!SHA.test(targetFingerprint || "")) throw blocked("invalid_target_fingerprint");
  if (!isHealthShape(before)) throw blocked("invalid_predeployment_health");
  if (typeof getHealth !== "function" || typeof sleep !== "function" ||
      typeof now !== "function" || typeof onAttempt !== "function") throw blocked("invalid_callbacks");
  if (!Number.isInteger(policy.maxAttempts) || policy.maxAttempts < 1 ||
      policy.maxAttempts > RETRY_POLICY.maxAttempts ||
      !Array.isArray(policy.delaysMs) || policy.delaysMs.length !== policy.maxAttempts - 1 ||
      policy.delaysMs.some(x => !Number.isInteger(x) || x < 0) ||
      !Number.isInteger(policy.requestTimeoutMs) || policy.requestTimeoutMs < 1 ||
      policy.requestTimeoutMs > RETRY_POLICY.requestTimeoutMs ||
      !Number.isInteger(policy.totalBudgetMs) || policy.totalBudgetMs < 1 ||
      policy.totalBudgetMs > RETRY_POLICY.totalBudgetMs) throw blocked("invalid_retry_policy");

  const started = now();
  let last = "no_attempt";
  for (let attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    const remaining = policy.totalBudgetMs - (now() - started);
    if (remaining <= 0) throw exhausted(last === "no_attempt" ? "time_budget" : last);
    let category = "unknown";
    let health;
    let reply;
    try {
      reply = await getHealth({ timeoutMs: Math.max(1, Math.min(policy.requestTimeoutMs, remaining)) });
    } catch {
      category = "transport_transient";
    }
    if (reply) {
      if (reply.status !== 200) {
        if (RETRYABLE_HTTP.has(reply.status)) category = "http_transient";
        else throw blocked("http_unexpected_status");
      } else {
        try {
          health = await reply.json();
        } catch {
          throw blocked("invalid_health_json");
        }
        if (!isHealthShape(health)) throw blocked("invalid_service_or_ingestion_state");
        if (health.ingestionEnabled !== before.ingestionEnabled) throw blocked("upload_state_drift");
        if (!SHA.test(health.deploymentFingerprint || "")) throw blocked("invalid_deployment_fingerprint");
        category = health.deploymentFingerprint === targetFingerprint ? "verified" : "fingerprint_stale";
      }
    }
    last = category;
    const elapsedMs = Math.max(0, Math.round(now() - started));
    onAttempt({ attempt, maxAttempts:policy.maxAttempts, elapsedMs, category });
    if (category === "verified") return { attempts:attempt, elapsedMs, health };
    if (attempt === policy.maxAttempts) throw exhausted(category);
    const waitMs = policy.delaysMs[attempt - 1];
    if (now() - started + waitMs >= policy.totalBudgetMs) throw exhausted(category);
    await sleep(waitMs);
  }
  throw exhausted(last);
}

async function runCli() {
  const [target, beforePath, afterPath, ...extra] = process.argv.slice(2);
  if (!target || !beforePath || !afterPath || extra.length) throw blocked("invalid_cli_arguments");
  // Input comes exclusively from the trusted deployment job's existing /health baseline.
  const before = JSON.parse(readFileSync(beforePath, "utf8"));
  const result = await verifyPostDeployHealth({
    targetFingerprint:target, before,
    getHealth:({timeoutMs})=>fetch(URL, {
      method:"GET", headers:{accept:"application/json"}, signal:AbortSignal.timeout(timeoutMs),
    }),
    onAttempt:event=>console.log("POST_DEPLOY_HEALTH_ATTEMPT=" + JSON.stringify(event)),
  });
  // Write verified health only after all identity, upload and fingerprint checks succeeded.
  writeFileSync(afterPath, JSON.stringify(result.health) + "\n", {encoding:"utf8",flag:"w"});
  console.log("POST_DEPLOY_HEALTH_VERIFIED attempts=" + result.attempts +
              " elapsed_ms=" + result.elapsedMs);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await runCli();
  } catch (error) {
    // Only static diagnostic categories, never response bodies, tokens or ZIP content.
    const message = String(error?.message || "");
    const safe = /^post_deploy_health_(blocked|retry_exhausted):[a-z_]+$/.test(message)
      ? message : "post_deploy_health_blocked:unexpected_error";
    console.error("POST_DEPLOY_HEALTH_RESULT=BLOCKED reason=" + safe);
    process.exitCode = 1;
  }
}
