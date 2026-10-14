// Opaque per-upload reference, not a bearer token or device identity.
import { LIMITS } from "./policy.mjs";
const ABC = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
export const DIAGNOSIS_ID_PATTERN = /^LBS-(?:[0-9A-HJKMNP-TV-Z]{5}-){3}[0-9A-HJKMNP-TV-Z]{5}$/;
export function newDiagnosisId(randomBytes = () => crypto.getRandomValues(new Uint8Array(13))) {
  const bytes=randomBytes();
  if (!(bytes instanceof Uint8Array) || bytes.length!==13) throw Error("invalid_diagnosis_entropy");
  let result="";
  for(let i=0;i<20;i++){let value=0;
    for(let j=0;j<5;j++){const b=i*5+j;value=(value<<1)|((bytes[b>>>3]>>>(7-(b&7)))&1);}
    result+=ABC[value];
  }
  return "LBS-"+result.match(/.{5}/g).join("-");
}
export function diagnosisReferenceKey(id) {
  if (typeof id!=="string" || !DIAGNOSIS_ID_PATTERN.test(id)) throw Error("invalid_diagnosis_id");
  return "Diagnose/Refs/LBS/"+id;
}
export function diagnosisReference(record) {
  diagnosisReferenceKey(record.diagnosisId);
  const expiresAtMillis=record.receivedAtMillis+LIMITS.retentionMillis;
  return {schemaVersion:1,project:"LBS",diagnosisId:record.diagnosisId,
    key:record.key,sha256:record.sha256,receivedAtMillis:record.receivedAtMillis,expiresAtMillis};
}
