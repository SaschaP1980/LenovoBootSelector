import { ArchiveIngestion } from "./ingestion.mjs";
import { DEPLOYMENT_FINGERPRINT } from "./deployment-identity.mjs";
import { SqlArchiveLedger } from "./sql-ledger.mjs";
import { requireUploadIdentity, LIMITS } from "./policy.mjs";
import { inspectDiagnosticZip, extractDiagnosticText } from "./zip-format.mjs";

export const SERVICE_NAME = "lenovo-boot-selector-diagnostics";
const GLOBAL_COORDINATOR_NAME = "diagnostics-global-v1";

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}
function forbidden() { return jsonResponse(401,{error:"unauthorized"}); }

async function readAuthorized(request, env) {
  const secret=env.DIAGNOSTICS_READ_TOKEN;
  if (typeof secret!=="string" || secret.length<32) return false;
  const supplied=request.headers.get("authorization")||"";
  if (!supplied.startsWith("Bearer ") || supplied.length>512) return false;
  const provided=supplied.slice(7);
  if(provided.length<32) return false;
  const encoder=new TextEncoder();
  const [a,b]=await Promise.all([
    crypto.subtle.digest("SHA-256",encoder.encode(secret)),
    crypto.subtle.digest("SHA-256",encoder.encode(provided))
  ]);
  const x=new Uint8Array(a),y=new Uint8Array(b);
  let diff=0;
  for(let i=0;i<x.length;i++)diff|=x[i]^y[i];
  return diff===0;
}
async function readUploadBody(request) {
  const claimed=request.headers.get("content-length");
  if(claimed!==null && (!/^\d+$/.test(claimed) ||
     Number(claimed)>LIMITS.maxArchiveBytes)) {
    throw new Error("archive_too_large");
  }
  if(!request.body) throw new Error("invalid_archive_body");
  const chunks=[];
  let total=0;
  const reader=request.body.getReader();
  try {
    while(true) {
      const {done,value}=await reader.read();
      if(done)break;
      total+=value.byteLength;
      if(total>LIMITS.maxArchiveBytes) throw new Error("archive_too_large");
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes=new Uint8Array(total);
  let pos=0;
  for(const chunk of chunks){bytes.set(chunk,pos);pos+=chunk.length;}
  return bytes;
}
async function digestHex(bytes) {
  const hash=new Uint8Array(await crypto.subtle.digest("SHA-256",bytes));
  return Array.from(hash,x=>x.toString(16).padStart(2,"0")).join("");
}
function coordinator(env) {
  if (!env.DIAGNOSTICS_COORDINATOR) throw new Error("coordinator_not_bound");
  return env.DIAGNOSTICS_COORDINATOR.get(
    env.DIAGNOSTICS_COORDINATOR.idFromName(GLOBAL_COORDINATOR_NAME)
  );
}

export default {
  async fetch(request,env) {
    const url=new URL(request.url);
    if(request.method==="GET" && url.pathname==="/health"){
      return jsonResponse(200,{
        service:SERVICE_NAME,
        deploymentFingerprint: DEPLOYMENT_FINGERPRINT,
        ingestionEnabled: env.ENABLE_DIAGNOSTIC_UPLOAD==="true" &&
          typeof env.DIAGNOSTICS_READ_TOKEN==="string" &&
          env.DIAGNOSTICS_READ_TOKEN.length>=32
      });
    }
    if(url.pathname==="/v1/diagnostics" && request.method==="POST"){
      // This flag must be explicitly provisioned as a Worker setting, not
      // embedded in the public GitHub repository. No silent enablement.
      if(env.ENABLE_DIAGNOSTIC_UPLOAD!=="true" ||
          typeof env.DIAGNOSTICS_READ_TOKEN!=="string" ||
          env.DIAGNOSTICS_READ_TOKEN.length<32) {
        return jsonResponse(503,{error:"ingestion_not_enabled"});
      }
      if((request.headers.get("content-type")||"").split(";")[0].trim().toLowerCase()!=="application/zip"){
        return jsonResponse(415,{error:"zip_content_type_required"});
      }
      const uuid=request.headers.get("x-installation-uuid");
      try { requireUploadIdentity(uuid,1); }
      catch { return jsonResponse(400,{error:"invalid_installation_uuid"}); }
      let bytes;
      try{
        bytes=await readUploadBody(request);
        requireUploadIdentity(uuid,bytes.length);
        // Stronger than merely checking the PK header: no non-canonical
        // entries, encrypted files, traversal or decompression bombs.
        inspectDiagnosticZip(bytes);
        await extractDiagnosticText(bytes);
      }catch(err){
        const code=String(err?.message||"");
        return jsonResponse(code==="archive_too_large"||code==="invalid_archive_size" ? 413 : 400,
          {error:code==="archive_too_large"||code==="invalid_archive_size"
            ?"archive_too_large":"invalid_diagnostic_zip"});
      }
      try{
        const hash=await digestHex(bytes);
        const ip=(request.headers.get("cf-connecting-ip")||"unknown").slice(0,80);
        const ipHash=await digestHex(new TextEncoder().encode(ip));
        return await coordinator(env).fetch(new Request("https://internal/ingest",{
          method:"POST",
          headers:{
            "x-installation-uuid":uuid,
            "x-content-sha256":hash,
            "x-client-network-hash":ipHash
          },
          body:bytes
        }));
      }catch{
        return jsonResponse(503,{error:"upload_unavailable"});
      }
    }
    // Strictly read-only, owner-authorized ledger snapshot for explicit
    // offline retention backfill. No administrative mutation endpoint exists.
    if(url.pathname==="/v1/maintenance/inventory") {
      if(request.method!=="GET")return jsonResponse(405,{error:"method_not_allowed"});
      if(!await readAuthorized(request,env))return forbidden();
      const cursor=url.searchParams.get("cursor")||"";
      const rawLimit=url.searchParams.get("limit")||"100";
      if(cursor.length>256||!/^(?:[1-9]|[1-9][0-9]|100)$/.test(rawLimit))
        return jsonResponse(400,{error:"invalid_query"});
      try{
        return await coordinator(env).fetch(new URL(
          "https://internal/inventory?cursor="+encodeURIComponent(cursor)+
          "&limit="+encodeURIComponent(rawLimit)).toString());
      }catch{return jsonResponse(503,{error:"read_unavailable"});}
    }
    if(url.pathname==="/v1/archives" ||
       url.pathname==="/v1/archives/entries" ||
       url.pathname==="/v1/archives/zip"){
      if(request.method!=="GET")return jsonResponse(405,{error:"method_not_allowed"});
      if(!await readAuthorized(request,env))return forbidden();
      const mode=url.pathname.split("/").pop();
      const internalPath=mode==="archives"?"list":mode==="entries"?"entries":"zip";
      const query=internalPath==="list"?"uuid":"key";
      const val=url.searchParams.get(query)||"";
      if(val.length>256)return jsonResponse(400,{error:"invalid_query"});
      try {
        const internal=new URL("https://internal/"+internalPath);
        internal.searchParams.set(query,val);
        return await coordinator(env).fetch(internal.toString());
      }catch{
        return jsonResponse(503,{error:"read_unavailable"});
      }
    }
    return jsonResponse(404,{error:"not_found"});
  },
};

export class DiagnosticsCoordinator {
  constructor(state,env) {
    this.state=state;
    this.env=env;
    this.tail=Promise.resolve();
    this.ledger=new SqlArchiveLedger(state.storage);
    this.store=new ArchiveIngestion({ledger:this.ledger,kv:env.DIAGNOSTICS_KV});
  }
  async fetch(request) {
    const url=new URL(request.url);
    if(request.method==="POST" && url.pathname==="/ingest"){
      // Only the ingestion path is serialized across external KV requests.
      const operation=this.tail.then(()=>this.receive(request));
      this.tail=operation.then(()=>{},()=>{});
      return operation;
    }
    if(request.method==="GET" && url.pathname==="/inventory"){
      try {
        const data=this.ledger.inventory(url.searchParams.get("cursor")||"",
          Number(url.searchParams.get("limit")||"100"));
        return jsonResponse(200,data);
      }catch{return jsonResponse(400,{error:"invalid_query"});}
    }
    if(request.method==="GET" && url.pathname==="/list"){
      try{
        const uuid=url.searchParams.get("uuid")||"";
        return jsonResponse(200,{archives:this.store.list(uuid)});
      }catch{return jsonResponse(400,{error:"invalid_query"});}
    }
    if(request.method==="GET" &&
      (url.pathname==="/entries"||url.pathname==="/zip")){
      try{
        const key=url.searchParams.get("key")||"";
        const meta=this.store.get(key);
        if(!meta)return jsonResponse(404,{error:"not_found"});
        const bytes=await this.env.DIAGNOSTICS_KV.get(key,"arrayBuffer");
        // Read may await a remote KV fetch: re-check expiry before returning bytes.
        if(meta.receivedAtMillis <= this.store.now() - LIMITS.retentionMillis)
          return jsonResponse(404,{error:"not_found"});
        if(!bytes)return jsonResponse(503,{error:"temporarily_unavailable"});
        if(url.pathname==="/entries"){
          const contents=await extractDiagnosticText(new Uint8Array(bytes));
          if(meta.receivedAtMillis <= this.store.now() - LIMITS.retentionMillis)
            return jsonResponse(404,{error:"not_found"});
          return jsonResponse(200,{metadata:meta,files:contents});
        }
        return new Response(bytes,{status:200,headers:{
          "content-type":"application/zip",
          "content-disposition":"attachment",
          "cache-control":"no-store",
          "x-content-type-options":"nosniff",
        }});
      }catch{return jsonResponse(503,{error:"read_unavailable"});}
    }
    return jsonResponse(404,{error:"not_found"});
  }
  async receive(request) {
    const uuid=request.headers.get("x-installation-uuid");
    const hash=request.headers.get("x-content-sha256");
    const networkHash=request.headers.get("x-client-network-hash");
    try{
      // Apply a durable, globally coordinated rate limit *before* KV writes.
      if(!this.ledger.consumeUploadRate(networkHash,Date.now())){
        return jsonResponse(429,{error:"upload_rate_limit"});
      }
      const bytes=new Uint8Array(await request.arrayBuffer());
      const record=await this.store.ingest({uuid,zipBytes:bytes,sha256:hash});
      return jsonResponse(201,{status:"stored",key:record.key,
        diagnosisId:record.diagnosisId,sha256:record.sha256,sizeBytes:record.sizeBytes});
    }catch(err){
      const code=String(err?.message||"");
      if(code==="invalid_archive_size"||code==="invalid_installation_uuid"){
        return jsonResponse(400,{error:code});
      }
      return jsonResponse(503,{error:"storage_unavailable"});
    }
  }
}
