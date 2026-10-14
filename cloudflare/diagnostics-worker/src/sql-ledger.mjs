// Persisted ledger for one globally selected SQLite-backed Durable Object.
// SQL writes inside transactionSync are strongly consistent. KV is the external
// blob store and must never be treated as the source of truth for membership.
const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS archives (
    key TEXT PRIMARY KEY, uuid TEXT NOT NULL, size_bytes INTEGER NOT NULL,
    received_at_ms INTEGER NOT NULL, sha256 TEXT NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS archives_by_uuid
    ON archives(uuid, received_at_ms, key)`,
  `CREATE TABLE IF NOT EXISTS pending_uploads (
    key TEXT PRIMARY KEY, uuid TEXT NOT NULL, size_bytes INTEGER NOT NULL,
    received_at_ms INTEGER NOT NULL, sha256 TEXT NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS garbage (
    key TEXT PRIMARY KEY, size_bytes INTEGER NOT NULL,
    received_at_ms INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS rate_buckets (
    key TEXT PRIMARY KEY, expires_at_ms INTEGER NOT NULL, events INTEGER NOT NULL)`,
];
const COLUMNS = "key, uuid, size_bytes AS sizeBytes, received_at_ms AS receivedAtMillis, sha256";

export class SqlArchiveLedger {
  constructor(storage) {
    if (!storage?.sql?.exec || !storage?.transactionSync) {
      throw new Error("sqlite_storage_required");
    }
    this.storage = storage;
    this.sql = storage.sql;
    for (const query of SCHEMA) this.sql.exec(query);
  }

  archives() {
    return this.sql.exec(`SELECT ${COLUMNS} FROM archives`).toArray();
  }

  pending() {
    return this.sql.exec(`SELECT ${COLUMNS} FROM pending_uploads`).toArray();
  }

  garbage() {
    return this.sql.exec(
      "SELECT key, size_bytes AS sizeBytes, received_at_ms AS receivedAtMillis FROM garbage ORDER BY received_at_ms, key"
    ).toArray();
  }

  isCommitted(key) {
    return Boolean(this.sql.exec("SELECT key FROM archives WHERE key = ? LIMIT 1", key).toArray().length);
  }

  hasKey(key) {
    return Boolean(this.sql.exec(
      "SELECT 1 AS found FROM archives WHERE key = ? UNION ALL " +
      "SELECT 1 AS found FROM pending_uploads WHERE key = ? UNION ALL " +
      "SELECT 1 AS found FROM garbage WHERE key = ? LIMIT 1",
      key, key, key
    ).toArray().length);
  }

  prepare(record) {
    this.sql.exec(
      "INSERT INTO pending_uploads(key,uuid,size_bytes,received_at_ms,sha256) VALUES(?,?,?,?,?)",
      record.key, record.uuid, record.sizeBytes, record.receivedAtMillis, record.sha256
    );
  }

  forgetPending(key) {
    this.sql.exec("DELETE FROM pending_uploads WHERE key = ?", key);
  }

  forgetGarbage(key) {
    this.sql.exec("DELETE FROM garbage WHERE key = ?", key);
  }


  consumeUploadRate(ipHash, nowMillis) {
    if (!/^[a-f0-9]{64}$/.test(ipHash) || !Number.isSafeInteger(nowMillis)) {
      throw new Error("invalid_upload_rate_key");
    }
    const hour=Math.floor(nowMillis / 3600000);
    const day=Math.floor(nowMillis / 86400000);
    const keys=[
      {key:`ip:${ipHash}:${hour}`,expiry:(hour+1)*3600000,max:6},
      {key:`global:${day}`,expiry:(day+1)*86400000,max:30}
    ];
    return this.storage.transactionSync(()=>{
      this.sql.exec("DELETE FROM rate_buckets WHERE expires_at_ms <= ?",nowMillis);
      for (const entry of keys) {
        const [state]=this.sql.exec(
          "SELECT events FROM rate_buckets WHERE key = ? LIMIT 1",entry.key
        ).toArray();
        if(state && state.events>=entry.max) return false;
      }
      for(const entry of keys){
        this.sql.exec(
          "INSERT INTO rate_buckets(key,expires_at_ms,events) VALUES(?,?,1) " +
          "ON CONFLICT(key) DO UPDATE SET events = events + 1",
          entry.key,entry.expiry
        );
      }
      return true;
    });
  }

  commit(record, deleteKeys) {
    this.storage.transactionSync(() => {
      // Fail closed if the durable intent is missing or does not match the
      // expected payload. Avoid consuming unrelated keys as evictions.
      const [intent] = this.sql.exec(
        "SELECT uuid, size_bytes AS sizeBytes, sha256 FROM pending_uploads WHERE key = ? LIMIT 1",
        record.key
      ).toArray();
      if (!intent || intent.uuid !== record.uuid ||
          intent.sizeBytes !== record.sizeBytes || intent.sha256 !== record.sha256) {
        throw new Error("missing_or_mismatched_upload_intent");
      }
      for (const key of deleteKeys) {
        const [old] = this.sql.exec(
          "SELECT size_bytes AS sizeBytes, received_at_ms AS receivedAtMillis FROM archives WHERE key = ? LIMIT 1",
          key
        ).toArray();
        if (!old) throw new Error("missing_eviction_record");
        this.sql.exec(
          "INSERT INTO garbage(key,size_bytes,received_at_ms) VALUES(?,?,?)",
          key, old.sizeBytes, old.receivedAtMillis
        );
        this.sql.exec("DELETE FROM archives WHERE key = ?", key);
      }
      this.sql.exec(
        "INSERT INTO archives(key,uuid,size_bytes,received_at_ms,sha256) VALUES(?,?,?,?,?)",
        record.key, record.uuid, record.sizeBytes, record.receivedAtMillis, record.sha256
      );
      this.sql.exec("DELETE FROM pending_uploads WHERE key = ?", record.key);
    });
  }
}
