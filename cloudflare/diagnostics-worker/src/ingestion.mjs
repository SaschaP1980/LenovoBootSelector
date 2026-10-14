import { LIMITS, requireUploadIdentity, planArchiveAdmission } from "./policy.mjs";

// All mutating calls are serialized by one Durable Object. The SQL ledger is
// authoritative; KV holds immutable ZIP bytes only. Never KV.list for admission.
export class ArchiveIngestion {
  constructor({ ledger, kv, now = () => Date.now() }) {
    this.ledger = ledger;
    this.kv = kv;
    this.now = now;
  }

  async repairPending() {
    // A process can stop between KV.put and the SQL commit. Pending intents
    // survive restarts. Never delete an object that was actually committed.
    for (const item of this.ledger.pending()) {
      if (!this.ledger.isCommitted(item.key)) {
        await this.kv.delete(item.key);
      }
      this.ledger.forgetPending(item.key);
    }
  }

  async drainGarbage() {
    // Tombstoned keys cannot be served to readers. Failed KV deletions remain
    // in this durable queue, and their bytes count against physical headroom.
    for (const item of this.ledger.garbage()) {
      await this.kv.delete(item.key);
      this.ledger.forgetGarbage(item.key);
    }
  }

  nextArchiveKey(uuid, receivedAtMillis) {
    let timestamp = receivedAtMillis;
    for (let attempt = 0; attempt < 100; attempt++, timestamp++) {
      const suffix = new Date(timestamp).toISOString()
        .replace(/[-:]/g, "").replace(".","").replace("Z","Z");
      const key = `Diagnose/${uuid}/${uuid}_${suffix}.zip`;
      if (!this.ledger.hasKey(key)) return { key, receivedAtMillis: timestamp };
    }
    throw new Error("archive_filename_collision");
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
      receivedAtMillis, sha256: sha256.toLowerCase() };
    this.ledger.prepare(record);
    try {
      await this.kv.put(key, zipBytes);
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
    return { key, sha256: record.sha256, sizeBytes,
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
    if (typeof key !== "string" || key.length > 256 ||
        !/^Diagnose\/[0-9a-f-]{36}\/[0-9a-f-]{36}_[0-9TZ]+\.zip$/.test(key)) {
      throw new Error("invalid_archive_key");
    }
    const archived = this.ledger.archives().find(item => item.key === key);
    return archived || null;
  }
}
