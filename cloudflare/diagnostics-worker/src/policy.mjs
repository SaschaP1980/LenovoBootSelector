// Pure storage-admission policy. This module never deletes files or performs network I/O.
export const LIMITS = Object.freeze({
  maxArchiveBytes: 2 * 1024 * 1024,
  maxTotalBytes: 500 * 1024 * 1024,
  maxPerInstallation: 20,
  retentionMillis: 90 * 24 * 60 * 60 * 1000,
});

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function requireUploadIdentity(uuid, sizeBytes) {
  if (typeof uuid !== "string" || !UUID_PATTERN.test(uuid)) {
    throw new Error("invalid_installation_uuid");
  }
  if (!Number.isSafeInteger(sizeBytes) || sizeBytes <= 0 || sizeBytes > LIMITS.maxArchiveBytes) {
    throw new Error("invalid_archive_size");
  }
  return uuid.toLowerCase();
}

function compareOldest(a, b) {
  return a.receivedAtMillis - b.receivedAtMillis || a.key.localeCompare(b.key);
}

function requireArchiveRecord(record) {
  if (!record || typeof record.key !== "string" || !record.key ||
      !UUID_PATTERN.test(record.uuid || "") ||
      !Number.isSafeInteger(record.sizeBytes) || record.sizeBytes < 0 ||
      !Number.isSafeInteger(record.receivedAtMillis)) {
    throw new Error("invalid_archive_ledger");
  }
}

/**
 * Calculate the minimum oldest-first deletion plan before admitting a new ZIP.
 * The caller must first durably stage/validate the new ZIP and then commit this
 * plan with recoverable metadata; never execute deletions on an uncommitted upload.
 */
export function planArchiveAdmission(existing, incoming, nowMillis) {
  if (!Array.isArray(existing) || !Number.isSafeInteger(nowMillis)) {
    throw new Error("invalid_admission_input");
  }
  const normalizedUuid = requireUploadIdentity(incoming && incoming.uuid, incoming && incoming.sizeBytes);
  const seen = new Set();
  const records = existing.map((record) => {
    requireArchiveRecord(record);
    if (seen.has(record.key)) throw new Error("duplicate_archive_ledger_key");
    seen.add(record.key);
    return { ...record, uuid: record.uuid.toLowerCase() };
  });
  const removal = new Set();
  const cutoff = nowMillis - LIMITS.retentionMillis;

  // Retention expiry is global; never create an incoming ZIP solely to trigger deletes.
  for (const record of records) {
    if (record.receivedAtMillis <= cutoff) removal.add(record.key);
  }

  const survivors = () => records.filter((record) => !removal.has(record.key));
  const sameInstallation = survivors()
    .filter((record) => record.uuid === normalizedUuid)
    .sort(compareOldest);
  while (sameInstallation.length >= LIMITS.maxPerInstallation) {
    removal.add(sameInstallation.shift().key);
  }

  let remaining = survivors();
  let total = remaining.reduce((sum, record) => sum + record.sizeBytes, 0);
  remaining = remaining.sort(compareOldest);
  while (total + incoming.sizeBytes > LIMITS.maxTotalBytes && remaining.length > 0) {
    const oldest = remaining.shift();
    removal.add(oldest.key);
    total -= oldest.sizeBytes;
  }
  if (total + incoming.sizeBytes > LIMITS.maxTotalBytes) {
    throw new Error("insufficient_global_capacity");
  }

  const toDelete = records.filter((record) => removal.has(record.key)).sort(compareOldest);
  return Object.freeze({
    installationUuid: normalizedUuid,
    deleteKeys: Object.freeze(toDelete.map((record) => record.key)),
    deletedBytes: toDelete.reduce((sum, record) => sum + record.sizeBytes, 0),
    projectedTotalBytes: total + incoming.sizeBytes,
    projectedInstallationCount: records.filter((r) => r.uuid === normalizedUuid && !removal.has(r.key)).length + 1,
  });
}
