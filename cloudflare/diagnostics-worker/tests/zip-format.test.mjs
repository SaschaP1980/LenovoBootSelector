import assert from "node:assert/strict";
import test from "node:test";
import { deflateRawSync } from "node:zlib";
import { inspectDiagnosticZip, extractDiagnosticText, REQUIRED_ENTRIES } from "../src/zip-format.mjs";

const sample={
  "runtime.jsonl":'{"event":"SESSION_STARTED"}\n',
  "environment.json":'{"appVersion":"0.10.7.7"}',
  "task-broker-summary.json":'{"status":"ok"}',
  "summary.txt":"Diagnostic fixture",
};
function crc32(bytes){
  let crc=-1;
  for(const b of bytes){
    crc^=b;
    for(let j=0;j<8;j++)crc=(crc>>>1)^((crc&1)?0xEDB88320:0);
  }
  return (crc^-1)>>>0;
}
function makeZip(files=sample){
  const chunks=[],central=[];
  let cursor=0;
  for(const [name,content] of Object.entries(files)){
    const original=Buffer.from(content,"utf8");
    const zipped=deflateRawSync(original);
    const filename=Buffer.from(name,"ascii");
    const crc=crc32(original);
    const local=Buffer.alloc(30+filename.length);
    local.writeUInt32LE(0x04034b50,0);
    local.writeUInt16LE(8,8);
    local.writeUInt32LE(crc,14);
    local.writeUInt32LE(zipped.length,18);
    local.writeUInt32LE(original.length,22);
    local.writeUInt16LE(filename.length,26);
    filename.copy(local,30);
    chunks.push(local,zipped);
    const header=Buffer.alloc(46+filename.length);
    header.writeUInt32LE(0x02014b50,0);
    header.writeUInt16LE(8,10);
    header.writeUInt32LE(crc,16);
    header.writeUInt32LE(zipped.length,20);
    header.writeUInt32LE(original.length,24);
    header.writeUInt16LE(filename.length,28);
    header.writeUInt32LE(cursor,42);
    filename.copy(header,46);
    central.push(header);
    cursor+=local.length+zipped.length;
  }
  const size=central.reduce((n,b)=>n+b.length,0);
  const end=Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50,0);
  end.writeUInt16LE(central.length,8);
  end.writeUInt16LE(central.length,10);
  end.writeUInt32LE(size,12);
  end.writeUInt32LE(cursor,16);
  return Buffer.concat([...chunks,...central,end]);
}

test("real deflate-format canonical ZIP round-trips all four text entries",async()=>{
  const zip=makeZip();
  const structure=inspectDiagnosticZip(zip);
  assert.deepEqual(structure.entries.map(x=>x.name),REQUIRED_ENTRIES);
  const decoded=await extractDiagnosticText(zip);
  assert.deepEqual(decoded,sample);
});

test("archive with extra, missing or renamed entry is rejected",()=>{
  assert.throws(()=>inspectDiagnosticZip(makeZip({...sample,extra:"x"})),/invalid_diagnostic_zip/);
  const missing={...sample};
  delete missing["summary.txt"];
  assert.throws(()=>inspectDiagnosticZip(makeZip(missing)),/invalid_diagnostic_zip/);
  assert.throws(()=>inspectDiagnosticZip(makeZip({...missing,"../secret.txt":"x"})),/invalid_diagnostic_zip/);
});

test("bad central directory, local signature and length are rejected",()=>{
  const zip=makeZip();
  const badLocal=Buffer.from(zip);
  badLocal[0]=0;
  assert.throws(()=>inspectDiagnosticZip(badLocal),/invalid_diagnostic_zip/);
  assert.throws(()=>inspectDiagnosticZip(zip.subarray(0,zip.length-10)),/invalid_diagnostic_zip/);
  const badDirectory=Buffer.from(zip);
  badDirectory.writeUInt32LE(0xfffffff0,badDirectory.length-6);
  assert.throws(()=>inspectDiagnosticZip(badDirectory),/invalid_diagnostic_zip/);
});

test("CRC mismatches are detected on private readback",async()=>{
  const zip=makeZip();
  const corrupt=Buffer.from(zip);
  const directory=zip.length-22-REQUIRED_ENTRIES.reduce((n,s)=>n+46+s.length,0);
  corrupt.writeUInt32LE(0x01234567,directory+16);
  await assert.rejects(extractDiagnosticText(corrupt),/diagnostic_archive_integrity_failure/);
});

test("oversized ZIP is rejected at structure boundary",()=>{
  assert.throws(()=>inspectDiagnosticZip(new Uint8Array(2*1024*1024+1)),
    /invalid_diagnostic_zip/);
});
