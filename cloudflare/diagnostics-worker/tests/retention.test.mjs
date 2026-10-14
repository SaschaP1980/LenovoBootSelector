import test from "node:test";
import assert from "node:assert/strict";
import { ArchiveIngestion } from "../src/ingestion.mjs";
import { LIMITS } from "../src/policy.mjs";
import { diagnosisReferenceKey } from "../src/diagnosis-id.mjs";

const uuid="123e4567-e89b-42d3-a456-426614174000";
const start=Date.UTC(2026,9,14,8,0,0,321);
const raw=new Uint8Array([80,75,3,4,1,2,3]);
const sha="b".repeat(64);
const incoming=()=>({uuid,zipBytes:raw,sha256:sha});
class Ledger {
  constructor(records=[]) {this.live=records.map(x=>({...x}));this.pendingList=[];this.garbageList=[];}
  archives(){return this.live.map(x=>({...x}));}
  pending(){return this.pendingList.map(x=>({...x}));}
  garbage(){return this.garbageList.map(x=>({...x}));}
  hasKey(k){return [...this.live,...this.pendingList,...this.garbageList].some(x=>x.key===k);}
  hasDiagnosisId(id){return [...this.live,...this.pendingList,...this.garbageList].some(x=>x.diagnosisId===id);}
  isCommitted(k){return this.live.some(x=>x.key===k);}
  prepare(x){this.pendingList.push({...x});}
  forgetPending(k){this.pendingList=this.pendingList.filter(x=>x.key!==k);}
  forgetGarbage(k){this.garbageList=this.garbageList.filter(x=>x.key!==k);}
  commit(x,deleteKeys){
    this.garbageList.push(...this.live.filter(v=>deleteKeys.includes(v.key)));
    this.live=this.live.filter(v=>!deleteKeys.includes(v.key));
    this.live.push({...x});this.forgetPending(x.key);
  }
}
class KV {
  constructor(){this.objects=new Map();this.putOptions=new Map();}
  async put(k,v,options){this.objects.set(k,v);this.putOptions.set(k,options||{});}
  async delete(k){this.objects.delete(k);this.putOptions.delete(k);}
}
function fixture(){
  let clock=start;
  const ledger=new Ledger(),kv=new KV();
  const service=new ArchiveIngestion({ledger,kv,now:()=>clock});
  return {ledger,kv,service,setTime:x=>{clock=x;}};
}

test("new ZIP and Diagnosis ID reference must use the exact same absolute native KV expiration",async()=>{
  const {service,kv}=fixture();
  const report=await service.ingest(incoming());
  const zipExpiry=kv.putOptions.get(report.key)?.expiration;
  const refExpiry=kv.putOptions.get(diagnosisReferenceKey(report.diagnosisId))?.expiration;
  assert.equal(zipExpiry,Math.ceil((start+LIMITS.retentionMillis)/1000));
  assert.equal(refExpiry,zipExpiry);
  assert.ok(zipExpiry*1000>=start+LIMITS.retentionMillis,"rounding must never delete before the 90-day deadline");
  assert.ok(!("expirationTtl" in kv.putOptions.get(report.key)));
});

test("legacy and new archives are hidden from list/read at 90 days without another upload",async()=>{
  const {service,ledger,setTime}=fixture();
  const report=await service.ingest(incoming());
  const old={key:`Diagnose/${uuid}/${uuid}_20261014T075959321Z.zip`,uuid,sizeBytes:raw.length,receivedAtMillis:start-1000,sha256:sha};
  ledger.live.push(old);
  setTime(start+LIMITS.retentionMillis-2);
  assert.ok(service.get(report.key));
  assert.ok(service.list(uuid).some(x=>x.key===report.key));
  assert.equal(service.get(old.key),null);
  setTime(start+LIMITS.retentionMillis);
  assert.equal(service.get(report.key),null);
  assert.equal(service.list(uuid).length,0);
  assert.equal(ledger.archives().length,2,"read gating must not mutate SQLite");
});

test("same-millisecond filename collision must not extend original admission lifetime",async()=>{
  const {service,ledger,kv}=fixture();
  const first=service.nextArchiveKey(uuid,start);
  ledger.live.push({key:first.key,uuid,sizeBytes:raw.length,receivedAtMillis:start,sha256:sha});
  const value=await service.ingest(incoming());
  assert.notEqual(value.key,first.key);
  assert.equal(ledger.archives().find(x=>x.key===value.key).receivedAtMillis,start);
  assert.equal(kv.putOptions.get(value.key)?.expiration,Math.ceil((start+LIMITS.retentionMillis)/1000));
});

test("expired ZIP is never listed even when KV has not yet physically removed it",async()=>{
  const {service,ledger,setTime,kv}=fixture();
  const value=await service.ingest(incoming());
  setTime(start+LIMITS.retentionMillis+2500);
  assert.ok(kv.objects.has(value.key),"KV fake retains bytes to model delayed provider propagation");
  assert.equal(service.list(uuid).length,0);
  assert.equal(service.get(value.key),null);
  assert.equal(ledger.archives().length,1);
});
