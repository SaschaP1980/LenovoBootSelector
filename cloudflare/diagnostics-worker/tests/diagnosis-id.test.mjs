import test from "node:test";
import assert from "node:assert/strict";
import { ArchiveIngestion } from "../src/ingestion.mjs";
import { newDiagnosisId, diagnosisReferenceKey } from "../src/diagnosis-id.mjs";

const uuid = "123e4567-e89b-42d3-a456-426614174000";
const now = Date.UTC(2026, 9, 14, 11, 0);
const sha256 = "a".repeat(64);
const zipBytes = new Uint8Array([0x50, 0x4b, 3, 4, 10, 20, 30]);

class Ledger {
  constructor(seed = []) { this.live = [...seed]; this.intents = []; this.garbageRows = []; this.failCommit = false; }
  archives() { return this.live.map(x => ({...x})); }
  pending() { return this.intents.map(x => ({...x})); }
  garbage() { return this.garbageRows.map(x => ({...x})); }
  hasKey(key) { return [...this.live,...this.intents,...this.garbageRows].some(x => x.key === key); }
  hasDiagnosisId(id) { return [...this.live,...this.intents,...this.garbageRows].some(x => x.diagnosisId === id); }
  isCommitted(key) { return this.live.some(x => x.key === key); }
  prepare(record) { this.intents.push({...record}); }
  forgetPending(key) { this.intents = this.intents.filter(x => x.key !== key); }
  forgetGarbage(key) { this.garbageRows = this.garbageRows.filter(x => x.key !== key); }
  commit(record, deleteKeys) {
    if (this.failCommit) throw Error("simulated_sql_commit_failure");
    this.garbageRows.push(...this.live.filter(x => deleteKeys.includes(x.key)));
    this.live = this.live.filter(x => !deleteKeys.includes(x.key));
    this.live.push({...record});
    this.forgetPending(record.key);
  }
}
class KV {
  constructor() { this.objects = new Map(); this.options = new Map(); this.failReferenceWrite = false; this.failDelete = false; }
  async put(key, value, options) {
    if (this.failReferenceWrite && key.startsWith("Diagnose/Refs/")) throw Error("simulated_reference_write_failure");
    this.objects.set(key, value); this.options.set(key, options);
  }
  async delete(key) {
    if (this.failDelete) throw Error("simulated_kv_delete_failure");
    this.objects.delete(key); this.options.delete(key);
  }
}
const make = seed => {
  const ledger = new Ledger(seed), kv = new KV();
  const service = new ArchiveIngestion({ledger, kv, now:() => now});
  return {ledger, kv, service};
};
const incoming = () => ({uuid,zipBytes,sha256});
const re = /^LBS-(?:[0-9A-HJKMNP-TV-Z]{5}-){3}[0-9A-HJKMNP-TV-Z]{5}$/;

test("Diagnosis ID identifies exactly one committed private ZIP without changing canonical filename", async () => {
  const {ledger,kv,service} = make([]);
  const result = await service.ingest(incoming());
  assert.match(result.diagnosisId, re);
  assert.match(result.key, new RegExp("^Diagnose/LBS/" + uuid + "/\\d{8}T\\d{9}Z\\.zip$"));
  assert.equal(ledger.archives()[0].diagnosisId, result.diagnosisId);
  const refKey = "Diagnose/Refs/LBS/" + result.diagnosisId;
  assert.equal(kv.objects.size, 2);
  assert.equal(kv.objects.has(result.key), true);
  const ref = JSON.parse(kv.objects.get(refKey));
  assert.deepEqual({schemaVersion:ref.schemaVersion, project:ref.project, diagnosisId:ref.diagnosisId, key:ref.key, sha256:ref.sha256},
    {schemaVersion:1, project:"LBS", diagnosisId:result.diagnosisId, key:result.key, sha256});
  assert.ok(Number.isSafeInteger(ref.expiresAtMillis));
  assert.ok(kv.options.get(refKey).expiration > Math.floor(now/1000));
});

test("each upload receives a distinct Diagnosis ID even when its ZIP bytes are identical", async () => {
  const {service} = make([]);
  const a = await service.ingest(incoming());
  const b = await service.ingest(incoming());
  assert.match(a.diagnosisId, re);
  assert.match(b.diagnosisId, re);
  assert.notEqual(a.diagnosisId, b.diagnosisId);
  assert.notEqual(a.key, b.key);
});

test("unconfirmed reference write does not return an ID; recovery deletes the orphan ZIP and reference", async () => {
  const {service, ledger, kv} = make([]);
  kv.failReferenceWrite = true;
  await assert.rejects(service.ingest(incoming()), /kv_write_unconfirmed|reference_write_unconfirmed/);
  assert.equal(ledger.archives().length, 0);
  assert.equal(ledger.pending().length, 1);
  kv.failReferenceWrite = false;
  await service.repairPending();
  assert.equal(kv.objects.size, 0);
  assert.deepEqual(ledger.pending(), []);
});

test("transaction failure recovers both ZIP and reference; eviction removes reference before blob", async () => {
  const {service,ledger,kv} = make([]);
  ledger.failCommit = true;
  await assert.rejects(service.ingest(incoming()), /simulated_sql_commit_failure/);
  assert.equal(ledger.pending().length, 1);
  assert.equal(kv.objects.size, 2);
  ledger.failCommit = false;
  await service.repairPending();
  assert.equal(kv.objects.size, 0);
  assert.equal(ledger.pending().length, 0);
});

test("format rejects foreign project IDs and cannot be guessed from an installation UUID", () => {
  const id = newDiagnosisId(() => new Uint8Array(13).fill(0x7a));
  assert.match(id, re);
  assert.equal(diagnosisReferenceKey(id), "Diagnose/Refs/LBS/" + id);
  for (const malformed of ["", "LBS-INVALID", id.toLowerCase(), "FAE-" + id.slice(4), id + "/suffix"]) {
    assert.throws(() => diagnosisReferenceKey(malformed), /invalid_diagnosis_id/);
  }
});

test("colliding random references are retried and never overwrite a prior reference", async () => {
  const {ledger,kv}=make([]);
  const sequence=[0,0,1];
  const client = new ArchiveIngestion({ledger,kv,now:() => now,
    randomBytes:() => new Uint8Array(13).fill(sequence.shift() ?? 2)});
  const first=await client.ingest(incoming());
  const second=await client.ingest(incoming());
  assert.notEqual(first.diagnosisId,second.diagnosisId);
  assert.equal(kv.objects.has(diagnosisReferenceKey(first.diagnosisId)),true);
  assert.equal(kv.objects.has(diagnosisReferenceKey(second.diagnosisId)),true);
});

test("unresolvable cryptographic ID collisions fail without displacing stored ZIPs", async () => {
  const {ledger,kv}=make([]);
  const client = new ArchiveIngestion({ledger,kv,now:() => now,
    randomBytes:() => new Uint8Array(13)});
  await client.ingest(incoming());
  const before=kv.objects.size;
  await assert.rejects(client.ingest(incoming()),/diagnosis_id_collision/);
  assert.equal(kv.objects.size,before);
  assert.equal(ledger.archives().length,1);
});
