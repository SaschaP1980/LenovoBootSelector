import assert from "node:assert/strict";
import test from "node:test";
import { DatabaseSync } from "node:sqlite";
import { SqlArchiveLedger } from "../src/sql-ledger.mjs";

const uuid="123e4567-e89b-42d3-a456-426614174000";
const record=(key)=>({key,uuid,sizeBytes:100,receivedAtMillis:123456789,sha256:"f".repeat(64)});

function createStorage() {
  const database=new DatabaseSync(":memory:");
  const storage={
    sql:{
      exec(query,...params){
        const statement=database.prepare(query);
        const isRead=/^\s*SELECT\b/i.test(query);
        const result=isRead?statement.all(...params):statement.run(...params);
        return {toArray(){return isRead?result:[];}};
      }
    },
    transactionSync(callback) {
      database.exec("BEGIN IMMEDIATE");
      try{
        const result=callback();
        database.exec("COMMIT");
        return result;
      }catch(error){
        database.exec("ROLLBACK");
        throw error;
      }
    }
  };
  return {storage,database};
}

test("archive intent is committed atomically with old archive tombstones",()=>{
  const {storage,database}=createStorage();
  try{
    const ledger=new SqlArchiveLedger(storage);
    const a=record("old");
    const b=record("new");
    ledger.prepare(a);
    ledger.commit(a,[]);
    assert.equal(ledger.archives().length,1);
    ledger.prepare(b);
    ledger.commit(b,["old"]);
    assert.deepEqual(ledger.archives().map(x=>x.key),["new"]);
    assert.deepEqual(ledger.garbage().map(x=>x.key),["old"]);
    assert.deepEqual(ledger.pending(),[]);
    ledger.forgetGarbage("old");
    assert.deepEqual(ledger.garbage(),[]);
  }finally{database.close();}
});

test("commit rollback retains old archive and uncommitted intent",()=>{
  const {storage,database}=createStorage();
  try{
    const ledger=new SqlArchiveLedger(storage);
    const a=record("old"),b=record("new");
    ledger.prepare(a);ledger.commit(a,[]);
    ledger.prepare(b);
    assert.throws(()=>ledger.commit(b,["not-a-real-old-archive"]),/missing_eviction_record/);
    assert.deepEqual(ledger.archives().map(x=>x.key),["old"]);
    assert.deepEqual(ledger.pending().map(x=>x.key),["new"]);
    assert.deepEqual(ledger.garbage(),[]);
  }finally{database.close();}
});

test("mis-matched upload intent cannot commit a different ZIP",()=>{
  const {storage,database}=createStorage();
  try{
    const ledger=new SqlArchiveLedger(storage);
    ledger.prepare(record("a"));
    assert.throws(()=>ledger.commit({...record("a"),sha256:"0".repeat(64)},[]),
      /missing_or_mismatched_upload_intent/);
    assert.deepEqual(ledger.pending().map(x=>x.key),["a"]);
    assert.deepEqual(ledger.archives(),[]);
  }finally{database.close();}
});

test("durable IP rate limit enforces six per hour",()=>{
  const {storage,database}=createStorage();
  try{
    const ledger=new SqlArchiveLedger(storage);
    const hour=Date.UTC(2026,9,14,8);
    for(let i=0;i<6;i++)assert.equal(ledger.consumeUploadRate("a".repeat(64),hour+1000),true);
    assert.equal(ledger.consumeUploadRate("a".repeat(64),hour+2000),false);
    assert.equal(ledger.consumeUploadRate("a".repeat(64),hour+3600000),true);
  }finally{database.close();}
});

test("durable global rate limit enforces thirty uploads per UTC day",()=>{
  const {storage,database}=createStorage();
  try{
    const ledger=new SqlArchiveLedger(storage);
    const midnight=Date.UTC(2026,9,14);
    for(let i=0;i<30;i++) assert.equal(
      ledger.consumeUploadRate(i.toString(16).padStart(64,"0"),midnight+i*1000),
      true
    );
    assert.equal(ledger.consumeUploadRate("f".repeat(64),midnight+35000),false);
    assert.equal(ledger.consumeUploadRate("f".repeat(64),midnight+86400000),true);
  }finally{database.close();}
});

test("additive diagnosis reference migration preserves historical archive rows", () => {
  const {storage,database}=createStorage();
  try {
    database.exec("CREATE TABLE archives (key TEXT PRIMARY KEY, uuid TEXT NOT NULL, size_bytes INTEGER NOT NULL, received_at_ms INTEGER NOT NULL, sha256 TEXT NOT NULL)");
    database.prepare("INSERT INTO archives VALUES(?,?,?,?,?)").run("legacy",uuid,100,123456789,"f".repeat(64));
    const ledger=new SqlArchiveLedger(storage);
    assert.equal(ledger.archives().length,1);
    assert.equal(ledger.archives()[0].diagnosisId,null);
    const current={...record("current"),diagnosisId:"LBS-00000-00000-00000-00000"};
    ledger.prepare(current);ledger.commit(current,[]);
    assert.equal(ledger.archives().length,2);
    assert.equal(ledger.hasDiagnosisId(current.diagnosisId),true);
    assert.equal(ledger.archives().find(x=>x.key==="legacy").diagnosisId,null);
  } finally {database.close();}
});

test("SQLite link state stays atomic with archive retirement and garbage cleanup", () => {
  const {storage,database}=createStorage();
  try {
    const ledger=new SqlArchiveLedger(storage);
    const a={...record("a"),diagnosisId:"LBS-11111-11111-11111-11111"};
    const b={...record("b"),diagnosisId:"LBS-22222-22222-22222-22222"};
    ledger.prepare(a);ledger.commit(a,[]);
    ledger.prepare(b);ledger.commit(b,["a"]);
    assert.equal(ledger.garbage()[0].diagnosisId,a.diagnosisId);
    assert.equal(ledger.archives()[0].diagnosisId,b.diagnosisId);
    assert.equal(ledger.hasDiagnosisId(a.diagnosisId),true);
    ledger.forgetGarbage("a");
    assert.equal(ledger.hasDiagnosisId(a.diagnosisId),false);
    assert.equal(ledger.hasDiagnosisId(b.diagnosisId),true);
  } finally {database.close();}
});
