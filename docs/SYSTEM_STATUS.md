# System Status (LBS-182)

The read-only side popup is opened using the header Info button, immediately left of Refresh. The normal main surface dimensions and action gates remain unchanged. No status-open task invocation, firmware read, repair, elevation or USB scan. Only existing observations and a local presentation timer are used.

## Source, authority and freshness

| Field | Authority | Freshness and unavailable semantics |
| --- | --- | --- |
| Saved default | Existing TaskBroker default-file reader, valid allowlisted identity or explicitly empty content | Read result distinct from firmware. Missing file represents no default only under the valid installed metadata contract (installer removes the file when no target is configured); missing metadata, failed read or ambiguous value is not assumed to be no default. Unavailable target is identified without exposing GUID. |
| Next restart | Existing independently verified firmware-manager readback, paired with observation time carried from actual acquisition, including background/default workers | Unknown until verified with timestamp; pending selection/default change is not proof. No one-time target is distinct from read failure. A difference from the stored default is allowed. Earlier read is not a guarantee of future firmware state. |
| Readiness | Existing capability model snapshot from normal header updates, existing readiness-probe result | Separate timestamp from actual probe, not cache sync. Ready means configuration/readiness checks, not successful execution of every task or a firmware write. |
| Boot target comparison | Existing BootTargetDriftState and evaluated/failed evidence, actual entries-read provenance | Last evaluated comparison only. Unknown if not evaluated or failed; a cached comparison is not a fresh scan. |
| Last refresh | Existing synchronous/background completion paths | Actual success/error or active; failure cannot be presented as freshly verified. Worker observation timestamps are retained only when captured content hashes match the adopted cache; mismatched or missing provenance is unknown. Read/check timestamps are displayed individually with age; unknown if no provenance. |
| Action guidance | Existing SetupRequired, RepairRequired, ReinitializeRequired capability states | Text only, directs to existing Further settings; never invokes repair or writes automatically. |

Status is explicitly historical observation, not a continuous health guarantee. The app-wide pale-red hover migration is deferred to LBS-270. The startup Refresh glyph uses a visible muted disabled ink; both header actions retain existing red hover.
