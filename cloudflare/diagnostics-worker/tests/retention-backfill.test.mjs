import test from "node:test";
import assert from "node:assert/strict";
import { classifyInventory, isLbsArchiveKey } from "../scripts/retention-backfill.mjs";

const uuid="123e4567-e89b-42d3-a456-426614174000";
const start=Date.UTC(2026,9,14,12,0,0,501);
const ninety=90*86400000;
const key=`Diagnose/LBS/${uuid}/20261014T120000501Z.zip`;
const row=(delta=0)=>({key,uuid,receivedAtMillis:start,sizeBytes:500,sha256:"a".repeat(64),diagnosisId:null});
test("backfill plans absolute expiry from original admission, not migration time",()=>{
 const list=[{name:key}];
 const plan=classifyInventory([row()],list,start+89*86400000);
 assert.equal(plan.length,1);
 assert.equal(plan[0].action,"reexpire");
 assert.equal(plan[0].expiresSeconds,Math.ceil((start+ninety)/1000));
});
test("backfill classifies already-expired and near-expiration without resetting 90-day TTL",()=>{
 const all=[{name:key}];
 const expired=classifyInventory([row()],all,start+ninety+1);
 assert.equal(expired[0].action,"retire");
 const near=classifyInventory([row()],all,start+ninety-50000);
 assert.equal(near[0].action,"near-expiry");
});
test("backfill is fail-closed on foreign, orphan, duplicate, or mismatched keys",()=>{
 assert.ok(isLbsArchiveKey(key));
 assert.ok(isLbsArchiveKey(`Diagnose/${uuid}/${uuid}_20261014T120000501Z.zip`));
 assert.equal(isLbsArchiveKey(`Diagnose/FAE/${uuid}/20261014T120000501Z.zip`),false);
 assert.throws(()=>classifyInventory([row()],[{name:key},{name:`Diagnose/LBS/${uuid}/20261014T120000502Z.zip`}],start+1000),/unowned|orphan|unrecognized/);
 assert.throws(()=>classifyInventory([row(),row()],[{name:key}],start+1000),/duplicate/);
 assert.throws(()=>classifyInventory([{...row(),uuid:"123e4567-e89b-42d3-a456-426614174001"}],[{name:key}],start+1000),/mismatch/);
});
test("backfill reports missing active blob and accepts already-missing expired blob",()=>{
 assert.throws(()=>classifyInventory([row()],[],start+2),/missing/);
 assert.equal(classifyInventory([row()],[],start+ninety+1)[0].action,"already-gone");
});
