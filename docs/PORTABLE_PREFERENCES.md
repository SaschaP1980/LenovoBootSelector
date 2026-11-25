# Portable user preferences — format v1 (LBS-180)

The portable preference document is separate from internal settings schema 6 and diagnostics ZIPs. It is a manually exported UTF-8 JSON document (optional UTF-8 BOM accepted on import), with a 262144-byte limit, maximum 512 array elements, maximum 512 object keys, maximum nested depth 5 and strict v1 field names/types. Unknown or duplicate decoded keys (including case variants) and duplicate normalized GUIDs are rejected. No comments, trailing content, floating point or non-UTF-8 encodings are accepted. A structurally valid edited document is not cryptographically authenticated.

```json
{
  "format": "LenovoBootSelector.Preferences",
  "version": 1,
  "locale": "en-US",
  "entries": [
    {
      "guid": "{aaaaaaaa-1111-1111-1111-111111111111}",
      "alias": "Example",
      "hidden": false
    }
  ]
}
```

All four root keys and all three per-entry keys are required; order within objects is immaterial, while array order is the desired presentation order. Locale is exactly en-US or de-DE. The GUID is a canonical braced hexadecimal GUID, normalized case-insensitively solely for local presentation reconciliation. Alias is a trimmed string (empty means clear); hidden is a JSON boolean. Control characters and invalid Unicode are rejected. The parser bounds a legacy alias at 4096 UTF-16 code units; current new/changed aliases retain the existing 30-unit admission limit. An unchanged overlength alias is preserved; a differing overlength alias is explicitly skipped. Existing internal saved metadata for unavailable entries is not exported and remains untouched. No guessing by name, title, disk model or path; no physical-device identity claim from a matching GUID.

Included: effective locale, aliases, visibility, order of currently discovered entries (including hidden). Excluded: installation identity, source machine metadata, disk models/serials, paths, raw firmware state, BootNext, persistent default, legacy default migration input, TaskBroker definitions/provenance, autostart registry state, secrets and diagnostic data. The file may still identify entries or personal aliases, so store privately. No automatic upload.

The import requires ready current entries, no pending boot/default/refresh/maintenance operation or Manage draft, no unresolved local language migration or corrupted/unsupported settings. Read-only validation creates an immutable-in-practice local preview snapshot (the UI does not mutate it). Apply recomputes the plan from the validated document, checks exact local file bytes and current runtime/entry snapshot, and writes only the approved presentation fields plus explicit local language provenance. Match order is substituted into existing matched slots; local-only/unavailable state and relative order are preserved. No-match or unchanged effective order does not materialize implicit local order. The existing legacy migration field is preserved. Unknown local settings fields or future schema fail closed, rather than being discarded.

On the unelevated UI thread a unique same-directory temporary file is flushed, the local byte fingerprint rechecked, and File.Replace (with rollback copy) or File.Move for a missing target commits. Runtime state is updated after successful IO. On failed IO the original bytes are checked; uncertain outcome blocks future settings persistence and requires checking/reloading the file. Recovery never overwrites unrelated observed external data. The application singleton and admission gates serialize its own workflows; they do not create an OS-wide lock against arbitrary external writers between final check and replacement. An existing export destination must already contain a valid portable document; internal settings-directory targets are rejected. The native chooser prompts before replacement. Cancel, stale plan, invalid file and ordinary IO failure do not apply new settings. A successful commit followed by UI refresh failure reports saved state and asks for restart, not a false rollback claim.

The confirmation dialog is read-only and scrollable, Cancel is the initial/default action, and Apply must be deliberate. The app-owned settings/tray routes share one UI action owner, localize in DE/EN and preserve main popup geometry, dark tooltip style and firmware/task boundaries. Native hosted tests use isolated temp files and mock or no privileged action owners; physical user acceptance remains separate.
