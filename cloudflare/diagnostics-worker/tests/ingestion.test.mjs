import test from "node:test";
import assert from "node:assert/strict";
import { ArchiveIngestion } from "../src/ingestion.mjs";
import { LIMITS } from "../src/policy.mjs";

const uuid = "123e4567-e89b-42d3-a456-426614174000";
const now = Date.UTC(2026, 9, 14, 8, 55);
const digest = "f".repeat(64);
const bytes = new Uint8Array(100);
const old = (key, date = now - 86400000) =>
  ({key,uuid,sizeBytes:100,receivedAtMillis:date,sha256:digest});

class MemoryLedger {
  constructor(seed = []) {
    this.live = seed.slice(); this.intents = []; this.tombstones = [];
    this.failCommit = false;
  }
  archives() { return this.live.map(x=>({...x})); }
  pending() { return this.intents.map(x=>({...x})); }
  garbage() { return this.tombstones.map(x=>({...x})); }
  hasKey(key) { return [...this.live,...this.intents,...this.tombstones].some(x=>x.key===key); }
  isCommitted(key) { return this.live.some(x=>x.key===key); }
  prepare(record) { this.intents.push({...record}); }
  forgetPending(key) { this.intents=this.intents.filter(x=>x.key!==key); }
  forgetGarbage(key) { this.tombstones=this.tombstones.filter(x=>x.key!==key); }
  commit(record,deleteKeys) {
    if(this.failCommit) throw new Error("simulated_transaction_rollback");
    const victims=this.live.filter(x=>deleteKeys.includes(x.key));
    this.tombstones.push(...victims);
    this.live=this.live.filter(x=>!deleteKeys.includes(x.key));
    this.live.push({...record});
    this.forgetPending(record.key);
  }
}
class MemoryKV {
  constructor() { this.objects=new Map();this.failPut=false;this.failDelete=false; }
  async put(key,value) {
    if(this.failPut) throw new Error("kv_put_fault");
    this.objects.set(key,value);
  }
  async delete(key) {
    if(this.failDelete) throw new Error("kv_delete_fault");
    this.objects.delete(key);
  }
}
function service(seed=[]) {
  const ledger=new MemoryLedger(seed),kv=new MemoryKV();
  return {ledger,kv,client:new ArchiveIngestion({ledger,kv,now:()=>now})};
}
const upload=()=>({uuid,zipBytes:bytes,sha256:digest});

test("new ZIP is durably staged then committed before it replaces an old slot",async()=>{
  const seed=Array.from({length:20},(_,i)=>old(`Diagnose/old-${i}`,now-(21-i)*1000));
  const {ledger,kv,client}=service(seed);
  const first=await client.ingest(upload());
  assert.equal(first.deletedArchiveCount,1);
  assert.equal(ledger.archives().length,20);
  assert.equal(ledger.archives().some(x=>x.key===seed[0].key),false);
  assert.equal(kv.objects.has(first.key),true);
  assert.deepEqual(ledger.pending(),[]);
  assert.deepEqual(ledger.garbage(),[]);
});

test("oversized upload does not delete or mark old archives",async()=>{
  const {ledger,kv,client}=service([old("old")]);
  await assert.rejects(client.ingest({...upload(),zipBytes:new Uint8Array(LIMITS.maxArchiveBytes+1)}),/invalid_archive_size/);
  assert.deepEqual(ledger.archives().map(x=>x.key),["old"]);
  assert.equal(kv.objects.size,0);
});

test("failed KV put keeps previous archive and journals pending",async()=>{
  const {ledger,kv,client}=service([old("old")]);
  kv.failPut=true;
  await assert.rejects(client.ingest(upload()),/kv_write_unconfirmed/);
  assert.deepEqual(ledger.archives().map(x=>x.key),["old"]);
  assert.equal(ledger.pending().length,1);
  kv.failPut=false;
  await client.repairPending();
  assert.deepEqual(ledger.pending(),[]);
  assert.deepEqual(ledger.archives().map(x=>x.key),["old"]);
});

test("SQL commit failure preserves old archives, and recovery removes uncommitted staged ZIP",async()=>{
  const {ledger,kv,client}=service([old("old")]);
  ledger.failCommit=true;
  await assert.rejects(client.ingest(upload()),/simulated_transaction_rollback/);
  assert.equal(ledger.archives().length,1);
  assert.equal(kv.objects.size,1);
  assert.equal(ledger.pending().length,1);
  ledger.failCommit=false;
  await client.repairPending();
  assert.equal(kv.objects.size,0);
  assert.equal(ledger.archives()[0].key,"old");
});

test("failed physical deletion remains tombstoned and blocks next write",async()=>{
  const seed=Array.from({length:20},(_,i)=>old(`old-${i}`,now-(21-i)*1000));
  const {ledger,kv,client}=service(seed);
  kv.failDelete=true;
  await client.ingest(upload());
  assert.equal(ledger.garbage().length,1);
  const before=ledger.archives().length;
  await assert.rejects(client.ingest(upload()),/kv_delete_fault/);
  assert.equal(ledger.archives().length,before);
  kv.failDelete=false;
  await client.drainGarbage();
  assert.deepEqual(ledger.garbage(),[]);
});

test("read-side listing is bounded and includes only one UUID",async()=>{
  const second="123e4567-e89b-42d3-a456-426614174001";
  const {client}=service([old("a"),{...old("b"),uuid:second}]);
  assert.deepEqual(client.list(uuid).map(x=>x.key),["a"]);
  assert.throws(()=>client.list(uuid,100),/invalid_listing_limit/);
});
