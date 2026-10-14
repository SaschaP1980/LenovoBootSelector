import assert from "node:assert/strict";
import test from "node:test";
import handler, { SERVICE_NAME } from "../src/index.mjs";

test("health exposes no secrets and upload stays disabled by default", async () => {
  const response=await handler.fetch(new Request("https://test.invalid/health"),{});
  assert.equal(response.status,200);
  assert.deepEqual(await response.json(),{service:SERVICE_NAME,ingestionEnabled:false});
  assert.equal(response.headers.get("cache-control"),"no-store");
});

test("disabled upload does not touch KV or coordinator",async()=>{
  const fake={
    DIAGNOSTICS_KV:{put(){throw Error("KV must not be called");}},
    DIAGNOSTICS_COORDINATOR:{get(){throw Error("coordinator must not be called");}}
  };
  const response=await handler.fetch(new Request("https://test.invalid/v1/diagnostics",{
    method:"POST",headers:{"content-type":"application/zip"},
    body:new Uint8Array([0x50,0x4b,0x03,0x04])
  }),fake);
  assert.equal(response.status,503);
  assert.deepEqual(await response.json(),{error:"ingestion_not_enabled"});
});

test("upload cannot enable without private read token",async()=>{
  const response=await handler.fetch(new Request("https://test.invalid/v1/diagnostics",{
    method:"POST",body:new Uint8Array([0x50,0x4b,0x03,0x04])
  }),{ENABLE_DIAGNOSTIC_UPLOAD:"true"});
  assert.equal(response.status,503);
});

test("read interfaces deny callers without owner bearer token",async()=>{
  const env={DIAGNOSTICS_READ_TOKEN:"a".repeat(48)};
  for(const path of ["/v1/archives?uuid=abc","/v1/archives/entries?key=abc",
                     "/v1/archives/zip?key=abc"]){
    const response=await handler.fetch(new Request("https://test.invalid"+path),env);
    assert.equal(response.status,401,path);
  }
});

test("valid owner token passes gate but unavailable coordinator fails closed",async()=>{
  const token="s".repeat(48);
  const response=await handler.fetch(new Request("https://test.invalid/v1/archives?uuid=x",{
    headers:{authorization:"Bearer "+token}
  }),{DIAGNOSTICS_READ_TOKEN:token});
  assert.equal(response.status,503);
});

test("unknown and unsupported methods never change stored state",async()=>{
  const unknown=await handler.fetch(new Request("https://test.invalid/"),{});
  assert.equal(unknown.status,404);
  const wrong=await handler.fetch(new Request("https://test.invalid/v1/archives",{
    method:"POST"
  }),{});
  assert.equal(wrong.status,405);
});
