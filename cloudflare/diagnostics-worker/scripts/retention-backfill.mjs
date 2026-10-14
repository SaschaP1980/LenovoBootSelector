// LBS-103 owner-only backfill. This script is NEVER deployed as a Worker route.
// Dry-run by default; --apply requires uploads disabled and a quiescent window.
// Secrets live solely in the operator environment and are never printed.
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

const UUID="[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
const NEW=new RegExp("^Diagnose/LBS/("+UUID+")/[0-9]{8}T[0-9]{9}Z\\.zip$");
const OLD=new RegExp("^Diagnose/("+UUID+")/\\1_[0-9]{8}T[0-9]{9}Z\\.zip$");
const ID=/^LBS-(?:[0-9A-HJKMNP-TV-Z]{5}-){3}[0-9A-HJKMNP-TV-Z]{5}$/;
const RETENTION=90*86400000;
export const isLbsArchiveKey=(key)=>typeof key==="string"&&(NEW.test(key)||OLD.test(key));

export function classifyInventory(records, keyObjects, nowMillis) {
  if(!Number.isSafeInteger(nowMillis)||!Array.isArray(records)||!Array.isArray(keyObjects))
    throw Error("invalid_backfill_input");
  const listed=new Map(),refs=new Map(),owned=new Set(),plans=[];
  for(const item of keyObjects){
    const key=item?.name;
    if(typeof key!=="string")throw Error("unrecognized_KV_key");
    if(key.startsWith("Diagnose/LBS/")&&!isLbsArchiveKey(key))
      throw Error("unrecognized_LBS_key");
    if(key.startsWith("Diagnose/Refs/LBS/")) {
      if(refs.has(key))throw Error("duplicate_reference_key");
      refs.set(key,item);
      continue;
    }
    if(!isLbsArchiveKey(key))continue; // foreign projects are out of scope
    if(listed.has(key))throw Error("duplicate_KV_key");
    listed.set(key,item);
  }
  for(const x of records){
    if(!x||!isLbsArchiveKey(x.key)||!Number.isSafeInteger(x.receivedAtMillis)||
       !Number.isSafeInteger(x.sizeBytes)||x.sizeBytes<1||!/^[0-9a-f]{64}$/.test(x.sha256||""))
      throw Error("invalid_ledger_record");
    if(owned.has(x.key))throw Error("duplicate_ledger_key");
    const uuid=(NEW.exec(x.key)||OLD.exec(x.key))[1];
    if(uuid!==x.uuid)throw Error("archive_uuid_mismatch");
    if(x.diagnosisId!=null&&!ID.test(x.diagnosisId))throw Error("invalid_ledger_diagnosis_id");
    owned.add(x.key);
    const expiresAtMillis=x.receivedAtMillis+RETENTION;
    if(!Number.isSafeInteger(expiresAtMillis))throw Error("invalid_expiration");
    const seconds=Math.ceil(expiresAtMillis/1000);
    const exists=listed.has(x.key);
    let action;
    if(!exists){
      if(expiresAtMillis>nowMillis)throw Error("missing_active_ledger_archive");
      action="already-gone";
    }else if(expiresAtMillis<=nowMillis) action="retire";
    else if(expiresAtMillis-nowMillis<60000) action="near-expiry";
    else {
      const kvExpiry=listed.get(x.key)?.expiration;
      const refExpiry=x.diagnosisId?refs.get("Diagnose/Refs/LBS/"+x.diagnosisId)?.expiration:seconds;
      action=kvExpiry===seconds && refExpiry===seconds?"compliant":"reexpire";
    }
    plans.push({...x,expiresAtMillis,expiresSeconds:seconds,action});
  }
  for(const key of listed.keys())if(!owned.has(key))throw Error("unowned_orphan_LBS_blob");
  return plans;
}

const sha256=bytes=>createHash("sha256").update(bytes).digest("hex");
async function requireJson(response,context){
  if(!response.ok)throw Error(context+"_http_"+response.status);
  const json=await response.json();
  if(json?.success===false)throw Error(context+"_api_failure");
  return json;
}
export async function fetchOwnerInventory(fetcher,origin,token){
  const all=[],seen=new Set();let cursor="";
  for(let n=0;n<200;n++){
    const u=new URL("/v1/maintenance/inventory",origin);
    u.searchParams.set("limit","100");
    if(cursor)u.searchParams.set("cursor",cursor);
    const j=await requireJson(await fetcher(u,{headers:{authorization:"Bearer "+token}}),"inventory");
    if(!Array.isArray(j.archives)||j.archives.length>100)throw Error("bad_inventory_page");
    for(const row of j.archives){if(seen.has(row.key))throw Error("duplicate_inventory");seen.add(row.key);all.push(row);}
    if(!j.nextCursor)return all;
    if(typeof j.nextCursor!=="string"||j.nextCursor<=cursor)throw Error("invalid_inventory_cursor");
    cursor=j.nextCursor;
  }
  throw Error("inventory_page_limit");
}
export async function fetchKvKeys(fetcher,apiBase,token){
  const all=[];let cursor="";
  for(let n=0;n<200;n++){
    const u=new URL(apiBase+"/keys");
    u.searchParams.set("prefix","Diagnose/");
    u.searchParams.set("limit","1000");
    if(cursor)u.searchParams.set("cursor",cursor);
    const j=await requireJson(await fetcher(u,{headers:{authorization:"Bearer "+token}}),"list");
    if(!Array.isArray(j.result))throw Error("bad_kv_list");
    all.push(...j.result);
    if(!j.result_info?.cursor)return all;
    if(j.result_info.cursor===cursor)throw Error("nonprogressing_kv_cursor");
    cursor=j.result_info.cursor;
  }
  throw Error("kv_list_page_limit");
}
export async function performBackfill({fetcher=fetch,env=process.env,args=process.argv.slice(2),writeOutput=console.log,now=Date.now}={}){
  const apply=args.includes("--apply");
  const quiesced=args.includes("--uploads-paused-120s");
  const maxArg=args.find(x=>x.startsWith("--max-mutations="));
  const maxMutations=maxArg?Number(maxArg.split("=")[1]):100;
  if(!Number.isSafeInteger(maxMutations)||maxMutations<1||maxMutations>200)throw Error("invalid_mutation_budget");
  if(apply&&!quiesced)throw Error("apply_requires_confirmed_120s_upload_pause");
  const account=env.CLOUDFLARE_ACCOUNT_ID,ns=env.CLOUDFLARE_KV_NAMESPACE_ID;
  const apiToken=env.CLOUDFLARE_API_TOKEN,readToken=env.DIAGNOSTICS_READ_TOKEN,origin=env.DIAGNOSTICS_WORKER_URL;
  if(!/^[a-f0-9]{32}$/.test(account||"")||!/^[a-f0-9]{32}$/.test(ns||"")||
     typeof apiToken!=="string"||apiToken.length<16||
     typeof readToken!=="string"||readToken.length<32||
     !origin?.startsWith("https://"))throw Error("missing_or_invalid_operator_environment");
  const u=new URL(origin);
  if(u.username||u.password||u.search||u.hash||u.pathname!=="/")throw Error("invalid_worker_origin");
  const health=await requireJson(await fetcher(new URL("/health",u)),"health");
  if(health.ingestionEnabled!==false)throw Error("pause_uploads_before_backfill");
  const apiBase="https://api.cloudflare.com/client/v4/accounts/"+account+"/storage/kv/namespaces/"+ns;
  const records=await fetchOwnerInventory(fetcher,u,readToken);
  const keys=await fetchKvKeys(fetcher,apiBase,apiToken);
  const plan=classifyInventory(records,keys,now());
  const counts=Object.fromEntries(["reexpire","retire","near-expiry","already-gone","compliant"].map(x=>[x,plan.filter(y=>y.action===x).length]));
  const needed=plan.reduce((n,x)=>n+(x.action==="reexpire"||x.action==="retire"?(x.diagnosisId?2:1):0),0);
  // No details about keys, UUIDs, Diagnosis IDs or ZIP bytes go to stdout.
  writeOutput(JSON.stringify({mode:apply?"apply":"dry-run",archives:plan.length,counts,plannedMaxKvMutations:needed}));
  if(!apply)return {applied:false,counts,mutations:0};
  if(counts["near-expiry"]>0)throw Error("near_expiry_wait_until_deadline_then_retry");
  // A bounded tranche is resumable: completed objects acquire their exact
  // expiry metadata and become 'compliant' on the next invocation.
  let budgetRemaining=maxMutations;
  let deferred=0;
  let mutations=0;
  const kvPath=k=>apiBase+"/values/"+encodeURIComponent(k);
  async function get(k){
    const r=await fetcher(kvPath(k),{headers:{authorization:"Bearer "+apiToken}});
    if(r.status===404)return null;
    if(!r.ok)throw Error("kv_get_http_"+r.status);
    return new Uint8Array(await r.arrayBuffer());
  }
  async function remove(k){
    const r=await fetcher(kvPath(k),{method:"DELETE",headers:{authorization:"Bearer "+apiToken}});
    await requireJson(r,"delete");
    mutations++;
  }
  async function rewrite(k,bytes,expiration){
    const url=new URL(kvPath(k));url.searchParams.set("expiration",String(expiration));
    const response=await fetcher(url,{method:"PUT",headers:{authorization:"Bearer "+apiToken,"content-type":"application/octet-stream"},body:bytes});
    await requireJson(response,"rewrite");
    mutations++;
    const after=await get(k);
    if(!after||sha256(after)!==sha256(bytes))throw Error("post_write_integrity_failed");
  }
  for(const item of plan){
    if(item.action==="already-gone"||item.action==="compliant")continue;
    const cost=item.diagnosisId?2:1;
    if(cost>budgetRemaining){deferred++;continue;}
    budgetRemaining-=cost;
    const verifyPause=await requireJson(await fetcher(new URL("/health",u)),"health");
    if(verifyPause.ingestionEnabled!==false)throw Error("upload_pause_lost");
    const blob=await get(item.key);
    if(!blob){
      if(item.action==="retire")continue;
      throw Error("previously_present_archive_disappeared");
    }
    if(blob.byteLength!==item.sizeBytes||sha256(blob)!==item.sha256)
      throw Error("archive_integrity_mismatch");
    let refBytes=null,refKey=null;
    if(item.diagnosisId){
      refKey="Diagnose/Refs/LBS/"+item.diagnosisId;
      refBytes=await get(refKey);
      // An already expired reference may be legitimately absent; a live one must match.
      if(refBytes){
        let ref;try{ref=JSON.parse(new TextDecoder().decode(refBytes));}catch{throw Error("invalid_reference_json");}
        if(ref.diagnosisId!==item.diagnosisId||ref.key!==item.key||ref.sha256!==item.sha256||
           ref.expiresAtMillis!==item.expiresAtMillis)throw Error("reference_mismatch");
      }else if(item.action==="reexpire")throw Error("missing_live_reference");
    }
    if(item.action==="retire"){
      if(refBytes)await remove(refKey);
      await remove(item.key);
    }else {
      await rewrite(item.key,blob,item.expiresSeconds);
      if(refBytes)await rewrite(refKey,refBytes,item.expiresSeconds);
    }
  }
  writeOutput(JSON.stringify({mode:"apply",completed:deferred===0,archives:plan.length,mutations,deferred}));
  return {applied:true,completed:deferred===0,counts,mutations,deferred};
}

if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
  performBackfill().catch(err=>{console.error("Retention backfill stopped: "+String(err?.message||"unknown_error"));process.exitCode=1;});
}
