import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL("../", import.meta.url));
export const REPOSITORY_ROOT = resolve(HERE, "../..");
export const SERVICE = "lenovo-boot-selector-diagnostics";
export const HEALTH_URL = "https://lenovo-boot-selector-diagnostics.sascha-petrovitsch.workers.dev/health";
export const ENVIRONMENT = "diagnostics-worker-production";
const SHA = /^[0-9a-f]{64}$/;

// Deliberate allowlist. These are deploy-relevant inputs, not release/version
// metadata. The generated identity module is excluded from its own digest.
const EXACT_FILES = [
  "cloudflare/diagnostics-worker/wrangler.jsonc",
  ".github/workflows/deploy-diagnostics-worker.yml",
  "cloudflare/diagnostics-worker/scripts/deployment-plan.mjs",
  "cloudflare/diagnostics-worker/scripts/verify-post-deploy-health.mjs",
  "src/Infrastructure/DiagnosticsUploadTransport.ps1",
  "src/Infrastructure/DiagnosticsIdentity.ps1",
  "tests/Test-DiagnosticsUploadTransport.ps1",
];
const DIRECTORIES = [
  "cloudflare/diagnostics-worker/tests",
  "cloudflare/diagnostics-worker/src",
];
const GENERATED = "cloudflare/diagnostics-worker/src/deployment-identity.mjs";
const excluded = new Set([GENERATED]);

export function deploymentFiles(root = REPOSITORY_ROOT) {
  const paths = [...EXACT_FILES];
  for (const dir of DIRECTORIES) {
    const absolute = join(root, dir);
    for (const name of readdirSync(absolute).sort()) {
      if (name.endsWith(".mjs")) paths.push(dir + "/" + name);
    }
  }
  return [...new Set(paths)].filter(p => !excluded.has(p)).sort();
}

export function deploymentFingerprint(root = REPOSITORY_ROOT, files = deploymentFiles(root)) {
  const hash = createHash("sha256");
  if (!Array.isArray(files) || files.length === 0) throw Error("empty_deployment_scope");
  for (const name of [...new Set(files)].sort()) {
    if (!/^[A-Za-z0-9_./-]+$/.test(name) || name.startsWith("/") || name.split("/").includes("..") || excluded.has(name))
      throw Error("unsafe_deployment_path");
    const abs = resolve(root, name);
    const st = statSync(abs);
    if (!st.isFile() || st.isSymbolicLink()) throw Error("unsafe_deployment_input");
    const value = readFileSync(abs);
    hash.update(name, "utf8");
    hash.update(Buffer.from([0]));
    hash.update(String(value.length), "utf8");
    hash.update(Buffer.from([0]));
    hash.update(value);
    hash.update(Buffer.from([0]));
  }
  return hash.digest("hex");
}

export function validateHealth(health, { fingerprintRequired = false } = {}) {
  if (!health || health.service !== SERVICE || typeof health.ingestionEnabled !== "boolean")
    throw Error("unhealthy_or_invalid_worker_health");
  if (fingerprintRequired && !SHA.test(health.deploymentFingerprint || ""))
    throw Error("unverified_worker_health_fingerprint");
  return true;
}

export function deploymentDecision({ targetFingerprint, receipt, health, mode = "auto" }) {
  if (!SHA.test(targetFingerprint || "")) throw Error("invalid_target_fingerprint");
  validateHealth(health);
  if (mode === "manual") return "deploy";
  if (mode !== "auto") throw Error("unknown_deployment_mode");
  if (receipt === null) return "deploy"; // Initial bootstrap, never health-only.
  if (!receipt || !["success", "failure", "pending", "error", "inactive"].includes(receipt.status))
    throw Error("invalid_deployment_receipt");
  // An incomplete/failed latest production attempt invalidates health-only.
  if (receipt.status !== "success") return "deploy";
  if (receipt.verified !== true || !SHA.test(receipt.fingerprint || "") ||
      typeof receipt.ingestionEnabled !== "boolean")
    throw Error("invalid_deployment_receipt");
  // The live server is the evidence, not merely the repository diff. If a
  // previous successful receipt no longer matches live, refuse to claim success.
  if (health.deploymentFingerprint !== receipt.fingerprint ||
      health.ingestionEnabled !== receipt.ingestionEnabled)
    throw Error("worker_production_drift_detected");
  return targetFingerprint === receipt.fingerprint ? "health-only" : "deploy";
}

export function validateUploadContract(root = REPOSITORY_ROOT) {
  const client = readFileSync(join(root, "src/Infrastructure/DiagnosticsUploadTransport.ps1"), "utf8");
  const worker = readFileSync(join(root, "cloudflare/diagnostics-worker/src/index.mjs"), "utf8");
  const zip = readFileSync(join(root, "cloudflare/diagnostics-worker/src/zip-format.mjs"), "utf8");
  const expected = [
    [client, "/v1/diagnostics"],
    [client, "application/zip"],
    [client, "x-installation-uuid"],
    [client, "Get-DiagnosticsUploadUri"],
    [worker, 'url.pathname==="/v1/diagnostics"'],
    [worker, '"application/zip"'],
    [worker, '"x-installation-uuid"'],
    [worker, 'diagnosisId:record.diagnosisId'],
    [zip, '"runtime.jsonl"'],
    [zip, '"environment.json"'],
    [zip, '"task-broker-summary.json"'],
    [zip, '"summary.txt"'],
  ];
  for (const [source, needle] of expected) {
    if (!source.includes(needle)) throw Error("diagnostics_client_worker_contract_mismatch:" + needle);
  }
  return true;
}

function loadJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}
function command() {
  const [operation, ...args] = process.argv.slice(2);
  switch (operation) {
    case "fingerprint":
      validateUploadContract();
      process.stdout.write(deploymentFingerprint() + "\n");
      return;
    case "stamp": {
      const sha = args[0];
      if (!SHA.test(sha || "")) throw Error("invalid_stamp_fingerprint");
      if (sha !== deploymentFingerprint()) throw Error("fingerprint_stamp_source_drift");
      writeFileSync(join(REPOSITORY_ROOT, GENERATED),
        "// Generated only in trusted deployment checkout; never publish in Git.\n" +
        "export const DEPLOYMENT_FINGERPRINT = " + JSON.stringify(sha) + ";\n");
      process.stdout.write("DEPLOYMENT_FINGERPRINT_STAMPED\n");
      return;
    }
    case "plan": {
      const [target, receiptPath, healthPath, mode] = args;
      const decision = deploymentDecision({
        targetFingerprint: target, receipt: loadJson(receiptPath),
        health: loadJson(healthPath), mode,
      });
      process.stdout.write(decision + "\n");
      return;
    }
    default:
      throw Error("unknown_deployment_plan_command");
  }
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { command(); } catch (error) {
    console.error("DEPLOYMENT_PLAN_BLOCKED=" + (error?.message || "unknown"));
    process.exitCode = 1;
  }
}
