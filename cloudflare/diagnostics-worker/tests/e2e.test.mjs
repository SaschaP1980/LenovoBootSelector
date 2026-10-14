import assert from "node:assert/strict";
import test from "node:test";
import { DatabaseSync } from "node:sqlite";
import { deflateRawSync } from "node:zlib";
import worker, { DiagnosticsCoordinator } from "../src/index.mjs";

const UUID_A = "123e4567-e89b-42d3-a456-426614174000";
const UUID_B = "123e4567-e89b-42d3-a456-426614174001";
const TOKEN = "diagnostics-owner-read-token-for-test-only-value";
const files = Object.freeze({
  "runtime.jsonl": '{"event":"SESSION_STARTED"}\n',
  "environment.json": '{"appVersion":"0.10.7.7"}',
  "task-broker-summary.json": '{"status":"ok"}',
  "summary.txt": "Complete diagnostics fixture",
});

function crc32(bytes) {
  let crc = -1;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i=0;i<8;i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ -1) >>> 0;
}
function fixtureZip() {
  const chunks = [], directory = [];
  let offset = 0;
  for (const [name,text] of Object.entries(files)) {
    const nameBytes = Buffer.from(name, "ascii");
    const raw = Buffer.from(text, "utf8");
    const packed = deflateRawSync(raw);
    const header = Buffer.alloc(30 + nameBytes.length);
    header.writeUInt32LE(0x04034b50,0);
    header.writeUInt16LE(8,8);
    header.writeUInt32LE(crc32(raw),14);
    header.writeUInt32LE(packed.length,18);
    header.writeUInt32LE(raw.length,22);
    header.writeUInt16LE(nameBytes.length,26);
    nameBytes.copy(header,30);
    chunks.push(header,packed);
    const central = Buffer.alloc(46 + nameBytes.length);
    central.writeUInt32LE(0x02014b50,0);
    central.writeUInt16LE(8,10);
    central.writeUInt32LE(crc32(raw),16);
    central.writeUInt32LE(packed.length,20);
    central.writeUInt32LE(raw.length,24);
    central.writeUInt16LE(nameBytes.length,28);
    central.writeUInt32LE(offset,42);
    nameBytes.copy(central,46);
    directory.push(central);
    offset += header.length + packed.length;
  }
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50,0);
  eocd.writeUInt16LE(directory.length,8);
  eocd.writeUInt16LE(directory.length,10);
  eocd.writeUInt32LE(directory.reduce((x,b)=>x+b.length,0),12);
  eocd.writeUInt32LE(offset,16);
  return Buffer.concat([...chunks,...directory,eocd]);
}

function environment() {
  const db = new DatabaseSync(":memory:");
  const storage = {
    sql: {
      exec(sql,...values) {
        const read = /^\s*SELECT\b/i.test(sql);
        const stmt = db.prepare(sql);
        const valuesOrResult = read ? stmt.all(...values) : stmt.run(...values);
        return {toArray:()=>read ? valuesOrResult : []};
      },
    },
    transactionSync(callback) {
      db.exec("BEGIN IMMEDIATE");
      try {
        const value=callback();
        db.exec("COMMIT");
        return value;
      } catch (error) {
        db.exec("ROLLBACK");
        throw error;
      }
    },
  };
  const data = new Map();
  const kv = {
    async put(key,bytes) { data.set(key,Uint8Array.from(bytes)); },
    async delete(key) { data.delete(key); },
    async get(key,format) {
      if(format!=="arrayBuffer")throw Error("unexpected KV format");
      const bytes=data.get(key);
      return bytes ? Uint8Array.from(bytes).buffer : null;
    },
  };
  const owner = new DiagnosticsCoordinator({storage},{DIAGNOSTICS_KV:kv});
  // A real Durable Object stub accepts either a URL string or Request and
  // normalizes it before calling the object's fetch handler. Mirror that
  // runtime contract rather than calling the class instance with a string.
  const binding={idFromName:name=>name,get:()=>({
    fetch(input,init) {
      return owner.fetch(input instanceof Request ? input : new Request(input,init));
    },
  })};
  const env = {
    DIAGNOSTICS_KV:kv,
    DIAGNOSTICS_COORDINATOR:binding,
    DIAGNOSTICS_READ_TOKEN:TOKEN,
    ENABLE_DIAGNOSTIC_UPLOAD:"true",
  };
  return {db,env,data,owner};
}

function upload(zip,uuid=UUID_A,ip="192.0.2.15") {
  return worker.fetch(new Request("https://test.invalid/v1/diagnostics",{
    method:"POST",
    headers:{"content-type":"application/zip","x-installation-uuid":uuid,"cf-connecting-ip":ip},
    body:Uint8Array.from(zip),
  }), this);
}
function read(env,path,token=TOKEN) {
  return worker.fetch(new Request("https://test.invalid"+path,{
    headers:token ? {authorization:"Bearer "+token}:{},
  }),env);
}

test("end-to-end upload, UUID index, private text and complete ZIP readback",async()=>{
  const {db,env,data}=environment();
  try{
    const zip=fixtureZip();
    const uploadResponse=await upload.call(env,zip);
    assert.equal(uploadResponse.status,201);
    const created=await uploadResponse.json();
    assert.equal(created.status,"stored");
    assert.match(created.key,new RegExp("^Diagnose/"+UUID_A+"/"+UUID_A+"_\\d{8}T\\d{9}Z\\.zip$"));
    assert.equal(data.size,1);

    const list=await read(env,"/v1/archives?uuid="+UUID_A);
    assert.equal(list.status,200);
    const index=await list.json();
    assert.equal(index.archives.length,1);
    assert.equal(index.archives[0].key,created.key);
    const encoded=encodeURIComponent(created.key);

    const privateText=await read(env,"/v1/archives/entries?key="+encoded);
    assert.equal(privateText.status,200);
    const parsed=await privateText.json();
    assert.deepEqual(parsed.files,files);
    assert.equal(parsed.metadata.sha256,created.sha256);

    const privateZip=await read(env,"/v1/archives/zip?key="+encoded);
    assert.equal(privateZip.status,200);
    assert.equal(privateZip.headers.get("content-type"),"application/zip");
    assert.deepEqual(Buffer.from(await privateZip.arrayBuffer()),zip);

    assert.equal((await read(env,"/v1/archives/entries?key="+encoded,null)).status,401);
    assert.equal((await read(env,"/v1/archives/entries?key="+encoded,"bad-token-that-will-not-match")).status,401);
    assert.equal((await read(env,"/v1/archives/zip?key="+encoded,null)).status,401);
  }finally{db.close();}
});

test("parallel requests are serialized to unique keys with no archive overwritten",async()=>{
  const {db,env,data,owner}=environment();
  try{
    owner.store.now=()=>Date.UTC(2026,9,14,9,0,0,42);
    const zip=fixtureZip();
    const [a,b]=await Promise.all([upload.call(env,zip),upload.call(env,zip)]);
    assert.equal(a.status,201);
    assert.equal(b.status,201);
    const x=await a.json(),y=await b.json();
    assert.notEqual(x.key,y.key);
    assert.equal(data.size,2);
    const r=await read(env,"/v1/archives?uuid="+UUID_A);
    assert.equal((await r.json()).archives.length,2);
  }finally{db.close();}
});

test("one owner's archive is never discoverable through another installation UUID",async()=>{
  const {db,env}=environment();
  try{
    assert.equal((await upload.call(env,fixtureZip(),UUID_A)).status,201);
    const list=await read(env,"/v1/archives?uuid="+UUID_B);
    assert.deepEqual((await list.json()).archives,[]);
  }finally{db.close();}
});

test("anonymous upload remains unavailable without explicit upload enablement",async()=>{
  const {db,env,data}=environment();
  try{
    delete env.ENABLE_DIAGNOSTIC_UPLOAD;
    const response=await upload.call(env,fixtureZip());
    assert.equal(response.status,503);
    assert.equal(data.size,0);
  }finally{db.close();}
});

test("HTTP rotation retains newest 20 ZIPs and removes oldest KV blob",async()=>{
  const {db,env,data,owner}=environment();
  try{
    const zip=fixtureZip();
    let moment=Date.UTC(2026,9,14,9,0,0,0);
    owner.store.now=()=>moment;
    const names=[];
    for(let i=0;i<21;i++){
      moment+=1000;
      const response=await upload.call(env,zip,UUID_A,"192.0.2."+(i+1));
      assert.equal(response.status,201,"upload index "+i);
      names.push((await response.json()).key);
    }
    const listed=await read(env,"/v1/archives?uuid="+UUID_A);
    assert.equal(listed.status,200);
    const body=await listed.json();
    assert.equal(body.archives.length,20);
    assert.equal(data.size,20);
    assert.equal(data.has(names[0]),false,"oldest blob must be deleted");
    assert.equal(data.has(names[20]),true,"latest blob must remain");
    assert.deepEqual(body.archives.map(x=>x.key),names.slice(1).reverse());
  } finally { db.close(); }
});
