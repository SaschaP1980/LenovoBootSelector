import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
const cfg = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
test("production redeployment retains owner-managed variables", () => {
  assert.equal(cfg.keep_vars, true);
  assert.equal(cfg.name, "lenovo-boot-selector-diagnostics");
  assert.equal(cfg.kv_namespaces.length, 1);
  assert.equal(cfg.kv_namespaces[0].binding, "DIAGNOSTICS_KV");
  assert.equal(cfg.kv_namespaces[0].id, "26be3acc56454e47919ff5ad28ac23d3");
  assert.equal(cfg.durable_objects.bindings[0].name, "DIAGNOSTICS_COORDINATOR");
  assert.equal(cfg.exports.DiagnosticsCoordinator.storage, "sqlite");
  assert.equal(cfg.vars, undefined);
});
