import assert from "node:assert/strict";
import test from "node:test";
import { LIMITS, requireUploadIdentity, planArchiveAdmission } from "../src/policy.mjs";

const uuidA = "123e4567-e89b-42d3-a456-426614174000";
const uuidB = "123e4567-e89b-42d3-a456-426614174001";
const now = Date.UTC(2026, 9, 14, 8);
const day = 24 * 60 * 60 * 1000;
const zip = (key, uuid, sizeBytes, ageDays) => ({
  key, uuid, sizeBytes, receivedAtMillis: now - ageDays * day,
});

test("approved limits match Issue #103", () => {
  assert.equal(LIMITS.maxArchiveBytes, 2097152);
  assert.equal(LIMITS.maxTotalBytes, 524288000);
  assert.equal(LIMITS.maxPerInstallation, 20);
  assert.equal(LIMITS.retentionMillis, 90 * day);
});

test("reject oversize, empty, malformed and non-v4 identities before eviction", () => {
  for (const size of [0, -1, 2.5, LIMITS.maxArchiveBytes + 1]) {
    assert.throws(() => requireUploadIdentity(uuidA, size), /invalid_archive_size/);
  }
  assert.throws(() => requireUploadIdentity("not-a-uuid", 120), /invalid_installation_uuid/);
  assert.throws(() => planArchiveAdmission([zip("old",uuidA,10,2)], {uuid:uuidA,sizeBytes:2097153}, now), /invalid_archive_size/);
});

test("nineteen plus one does not rotate; twenty plus one removes oldest of same UUID", () => {
  const a = Array.from({length:20}, (_,i) => zip(`a-${i}`,uuidA,100,20-i));
  const b = [zip("other",uuidB,100,40)];
  const first = planArchiveAdmission(a.slice(1).concat(b),{uuid:uuidA,sizeBytes:100},now);
  assert.deepEqual(first.deleteKeys,[]);
  assert.equal(first.projectedInstallationCount,20);
  const next = planArchiveAdmission(a.concat(b),{uuid:uuidA,sizeBytes:100},now);
  assert.deepEqual(next.deleteKeys,["a-0"]);
  assert.equal(next.projectedInstallationCount,20);
});

test("expiry applies across UUIDs but preserves all archives newer than 90 days", () => {
  const records=[zip("expired",uuidB,100,91),zip("at-boundary",uuidA,100,90),zip("fresh",uuidB,100,89)];
  const x=planArchiveAdmission(records,{uuid:uuidA,sizeBytes:100},now);
  assert.deepEqual(x.deleteKeys,["expired","at-boundary"]);
});

test("global capacity evicts oldest regardless of installation identity", () => {
  const arr=[
    zip("old-b",uuidB,LIMITS.maxTotalBytes-210,5),
    zip("new-a",uuidA,100,1),
  ];
  const x=planArchiveAdmission(arr,{uuid:uuidA,sizeBytes:200},now);
  assert.deepEqual(x.deleteKeys,["old-b"]);
  assert.equal(x.projectedTotalBytes,300);
});

test("deterministic tiebreak for same timestamp and malformed ledger rejection", () => {
  const n=now-100;
  const arr=[{key:"b",uuid:uuidA,sizeBytes:LIMITS.maxTotalBytes-400,receivedAtMillis:n},
    {key:"a",uuid:uuidB,sizeBytes:200,receivedAtMillis:n}];
  const x=planArchiveAdmission(arr,{uuid:uuidA,sizeBytes:500},now);
  assert.deepEqual(x.deleteKeys,["a","b"]);
  assert.throws(() => planArchiveAdmission(arr.concat(arr[0]),{uuid:uuidA,sizeBytes:100},now), /duplicate_archive_ledger_key/);
  assert.throws(() => planArchiveAdmission([{key:"bad",uuid:uuidA,sizeBytes:-1,receivedAtMillis:now}],{uuid:uuidA,sizeBytes:100},now),/invalid_archive_ledger/);
});
