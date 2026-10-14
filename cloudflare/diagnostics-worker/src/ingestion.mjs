import { LIMITS, requireUploadIdentity, planArchiveAdmission } from "./policy.mjs";
import { newDiagnosisId, diagnosisReferenceKey, diagnosisReference } from "./diagnosis-id.mjs";

// All mutating calls are serialized by one Durable Object. The SQL ledger is
// authoritative; KV holds immutable ZIP bytes only. Never KV.list for admission.
export class ArchiveIngestion {
  constructor({ ledger, kv, now = () => Date.now(), randomBytes }) {
    this.ledger = ledger;
    this.kv = kv;
    this.now = now;
    this.randomBytes = randomBytes;
  }

  async repairPending() {
    // A process can stop between KV.put and the SQL commit. Pending intents
    // survive restarts. Never delete an object that was actually committed.
    for (const item of this.ledger.pending()) {
      if (!this.ledger.isCommitted(item.key)) {
        if(item.diagnosisId) await this.kv.delete(diagnosisReferenceKey(item.diagnosisId));
        await this.kv.delete(item.key);
      }
      this.ledger.forgetPending(item.key);
    }
  }

  async drainGarbage() {
    // Tombstoned keys cannot be served to readers. Failed KV deletions remain
    // in this durable queue, and their bytes count against physical headroom.
    for (const item of this.ledger.garbage()) {
      if(item.diagnosisId) await this.kv.delete(diagnosisReferenceKey(item.diagnosisId));
      await this.kv.delete(item.key);
      this.ledger.forgetGarbage(item.key);
    }
  }

  nextArchiveKey(uuid, receivedAtMillis) {
    let timestamp = receivedAtMillis;
    for (let attempt = 0; attempt < 100; attempt++, timestamp++) {
      const suffix = new Date(timestamp).toISOString()
        .replace(/[-:]/g, "").replace(".","").replace("Z","Z");
      // The project is fixed by the backend; clients cannot select folders.
      const key = `Diagnose/LBS/${uuid}/${suffix}.zip`;
      if (!this.ledger.hasKey(key)) return { key, receivedAtMillis: timestamp };
    }
    throw new Error("archive_filename_collision");
  }

  nextDiagnosisId() {
    for(let i=0;i<8;i++){
      const id=newDiagnosisId(this.randomBytes);
      if(!this.ledger.hasDiagnosisId(id))return id;
    }
    throw Error("diagnosis_id_collision");
  }
  async ingest({ uuid, zipBytes, sha256 }) {
    // Validate before touching retained data (including before expiry cleanup).
    const sizeBytes = zipBytes?.byteLength;
    const normalizedUuid = requireUploadIdentity(uuid, sizeBytes);
    if (!(zipBytes instanceof Uint8Array)) throw new Error("invalid_archive_body");
    if (typeof sha256 !== "string" || !/^[a-f0-9]{64}$/i.test(sha256)) {
      throw new Error("invalid_archive_digest");
    }

    await this.repairPending();
    // A failed tombstone deletion must prevent growth, not leak KV capacity.
    await this.drainGarbage();
    const nowMillis = this.now();
    const existing = this.ledger.archives();
    const plan = planArchiveAdmission(existing,
      { uuid: normalizedUuid, sizeBytes }, nowMillis);
    const { key, receivedAtMillis } = this.nextArchiveKey(normalizedUuid, nowMillis);

    // SQL journal is persisted *before* the external KV write.
    const record = { key, uuid: normalizedUuid, sizeBytes,
      receivedAtMillis, sha256: sha256.toLowerCase(), diagnosisId: this.nextDiagnosisId() };
    const ref = diagnosisReference(record);
    this.ledger.prepare(record);
    try {
      await this.kv.put(key, zipBytes);
      await this.kv.put(diagnosisReferenceKey(record.diagnosisId),JSON.stringify(ref),
        {expiration:Math.floor(ref.expiresAtMillis/1000)});
    } catch (err) {
      // A timeout may mean KV accepted the write. Leave the intent for a
      // later retry to delete it; do not accidentally discard an old ZIP.
      throw new Error("kv_write_unconfirmed", { cause: err });
    }

    // Atomically switch visible ledger ownership only after KV.put succeeds.
    // commit() must insert the new archive, tombstone evictions, and clear the
    // pending intent in *one local SQLite transaction*.
    this.ledger.commit(record, plan.deleteKeys);
    try {
      await this.drainGarbage();
    } catch {
      // Existing records were retired in the SQL commit; failed physical
      // cleanup stays journaled and blocks the next write until repaired.
    }
    return { key, sha256: record.sha256, sizeBytes, diagnosisId: record.diagnosisId,
      deletedArchiveCount: plan.deleteKeys.length };
  }

  list(uuid, limit = 20) {
    const normalized = requireUploadIdentity(uuid, 1);
    if (!Number.isSafeInteger(limit) || limit < 1 || limit > 20) {
      throw new Error("invalid_listing_limit");
    }
    return this.ledger.archives()
      .filter(item => item.uuid === normalized)
      .sort((a,b) => b.receivedAtMillis-a.receivedAtMillis ||
        b.key.localeCompare(a.key))
      .slice(0,limit);
  }

  get(key) {
    if (typeof key !== "string" || key.length > 256) {
      throw new Error("invalid_archive_key");
    }
    const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
    const projectKey = new RegExp("^Diagnose/LBS/(" + uuid + ")/\\d{8}T\\d{9}Z\\.zip$", "i");
    const legacyKey = new RegExp("^Diagnose/(" + uuid + ")/\\1_\\d{8}T\\d{9}Z\\.zip$", "i");
    const match = projectKey.exec(key) || legacyKey.exec(key);
    if (!match) throw new Error("invalid_archive_key");
    const record = this.ledger.archives().find(item => item.key === key);
    return record && record.uuid === match[1].toLowerCase() ? record : null;
  }
}
