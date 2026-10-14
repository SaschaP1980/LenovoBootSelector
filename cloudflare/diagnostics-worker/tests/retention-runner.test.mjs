import test from "node:test";
import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {performBackfill} from "../scripts/retention-backfill.mjs";

const UUID="123e4567-e89b-42d3-a456-426614174000";
const timestamp=Date.UTC(2026,9,14,10,0,0,345),now=timestamp+86400000;
const key="Diagnose/LBS/"+UUID+"/20261014T100000345Z.zip";
const id="LBS-7K2MP-9Q4V6-TR3X8-AB123";
const bytes=new Uint8Array([80,75,3,4,12,17,25]);
const sha=createHash("sha256").update(bytes).digest("hex");
const refKey="Diagnose/Refs/LBS/"+id;
const row={key,uuid:UUID,receivedAtMillis:timestamp,sizeBytes:bytes.length,sha256:sha,diagnosisId:id};
const expiration=Math.ceil((timestamp+90*86400000)/1000);
const ACCOUNT="a".repeat(32),NS="b".repeat(32),TOKEN="c".repeat(40),READ="d".repeat(40);
const env={CLOUDFLARE_ACCOUNT_ID:ACCOUNT,CLOUDFLARE_KV_NAMESPACE_ID:NS,
  CLOUDFLARE_API_TOKEN:TOKEN,DIAGNOSTICS_READ_TOKEN:READ,
  DIAGNOSTICS_WORKER_URL:"https://example.workers.dev"};
const json=(v,status=200)=>new Response(JSON.stringify(v),{status,headers:{"content-type":"application/json"}});
function testRig(){
  let uploadEnabled=false,requests=[],failPutAt=0,writes=0;
  const blobs=new Map([[key,bytes],[refKey,new TextEncoder().encode(JSON.stringify({
    schemaVersion:1,project:"LBS",diagnosisId:id,key,sha256:sha,
    receivedAtMillis:timestamp,expiresAtMillis:timestamp+90*86400000
  }))]]);
  const expirations=new Map();
  const fetcher=async(uri,options={})=>{
    const u=new URL(uri.toString());requests.push({path:u.pathname,method:options.method||"GET"});
    if(u.pathname==="/health")return json({ingestionEnabled:uploadEnabled});
    if(u.pathname==="/v1/maintenance/inventory"){
      assert.equal(options.headers.authorization,"Bearer "+READ);
      return json({archives:[row],nextCursor:null});
    }
    if(u.pathname.endsWith("/keys")){
      assert.equal(options.headers.authorization,"Bearer "+TOKEN);
      return json({success:true,result:[...blobs].map(([name])=>({name,expiration:expirations.get(name)})),result_info:{}});
    }
    const marker="/values/";
    if(!u.pathname.includes(marker))throw Error("unknown_fake_endpoint");
    assert.equal(options.headers.authorization,"Bearer "+TOKEN);
    const name=decodeURIComponent(u.pathname.split(marker)[1]);
    if(options.method==="PUT"){
      writes++;
      if(failPutAt===writes)return json({success:false,errors:[{code:123}]},500);
      assert.ok(blobs.has(name),"never create missing/archive orphan");
      const newBytes=new Uint8Array(options.body);
      blobs.set(name,newBytes);
      expirations.set(name,Number(u.searchParams.get("expiration")));
      return json({success:true,result:null});
    }
    if(options.method==="DELETE"){
      blobs.delete(name);expirations.delete(name);
      return json({success:true,result:null});
    }
    return blobs.has(name)?new Response(blobs.get(name),{status:200}):new Response(null,{status:404});
  };
  return {blobs,expirations,requests,fetcher,enable:()=>{uploadEnabled=true;},
    failPutAt:x=>{failPutAt=x;},getWrites:()=>writes};
}

test("operator dry-run leaves every archive byte and reference untouched",async()=>{
  const t=testRig(),lines=[];
  const before=t.blobs.get(key).slice();
  const x=await performBackfill({fetcher:t.fetcher,env,args:[],now:()=>now,writeOutput:s=>lines.push(s)});
  assert.equal(x.applied,false);
  assert.equal(x.counts.reexpire,1);
  assert.deepEqual(t.blobs.get(key),before);
  assert.equal(t.getWrites(),0);
  assert.ok(lines.every(l=>!l.includes(UUID)&&!l.includes(id)&&!l.includes(sha)));
});
test("explicit paused apply rewrites identical bytes with original absolute ZIP/reference expiration",async()=>{
  const t=testRig(),messages=[];
  const x=await performBackfill({fetcher:t.fetcher,env,
    args:["--apply","--uploads-paused-120s","--max-mutations=2"],
    now:()=>now,writeOutput:s=>messages.push(s)});
  assert.equal(x.applied,true);
  assert.equal(x.completed,true);
  assert.equal(x.mutations,2);
  assert.deepEqual(t.blobs.get(key),bytes);
  assert.equal(t.expirations.get(key),expiration);
  assert.equal(t.expirations.get(refKey),expiration);
  const second=await performBackfill({fetcher:t.fetcher,env,args:[],now:()=>now,writeOutput:()=>{}});
  assert.equal(second.counts.compliant,1,"rerun must not waste KV Free writes");
});
test("apply refuses missing quiescence flag and enabled ingestion, without changing storage",async()=>{
  const t=testRig();
  await assert.rejects(performBackfill({fetcher:t.fetcher,env,args:["--apply"],now:()=>now,writeOutput:()=>{}}),/apply_requires/);
  t.enable();
  await assert.rejects(performBackfill({fetcher:t.fetcher,env,args:[],now:()=>now,writeOutput:()=>{}}),/pause_uploads/);
  assert.equal(t.getWrites(),0);
});
test("failed partial rewrite stops and can be repeated without changing ZIP SHA",async()=>{
  const t=testRig();t.failPutAt(2);
  const args=["--apply","--uploads-paused-120s","--max-mutations=2"];
  await assert.rejects(performBackfill({fetcher:t.fetcher,env,args,now:()=>now,writeOutput:()=>{}}),/rewrite_api_failure|rewrite_http_500/);
  assert.deepEqual(t.blobs.get(key),bytes);
  t.failPutAt(0);
  const res=await performBackfill({fetcher:t.fetcher,env,args,now:()=>now,writeOutput:()=>{}});
  assert.equal(res.completed,true);
  assert.equal(t.expirations.get(refKey),expiration);
});
