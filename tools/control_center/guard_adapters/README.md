# News / Macro read adapters v1

Direct consumer: owner and later Market Radar. Implementation candidate; CT review
and intake pending. These are historical feed observations with no runtime authority.

```powershell
. ./scripts/use_python.ps1
python tools/control_center/guard_adapters/feeds.py --repo . --sha <exact-pushed-SHA> --as-of 2026-09-12T12:00:00Z --out <new-outside-repo-file.json>
python -m unittest discover -s tools/control_center/guard_adapters -p 'test_*.py' -v
```

Only the three sources listed in `SOURCES` are consumed. Exact producer hashes must
match the inspected CC00 source map; changed producer semantics are UNQUALIFIED
until separately inspected. Parsing is read-only from exact regular Git blobs.
There is no default runtime checkout, CSV glob, filesystem mtime, collector,
terminal, external feed/API call, account/magic mapping or global-variable reader.

News exposes the source's High-filtered events, exact currency, safe title and
Bangkok-to-UTC event timestamp. Producer observation and available-at are unknown.
Future calendar events are legitimate events, not proof of feed freshness.
MRIS exposes its producer timestamp/age, literal regime, dimensionless risk_index
and active_count. Timeline exposes the latest as-of row, counts and future rows
withheld. Its producer can substitute export time when upstream time is missing,
so row time is not promoted into proof of fresh source data.

All three Git captures are HISTORICAL. Valid data is guard state UNKNOWN, missing
input MISSING, malformed input MALFORMED; future classifier payload is withheld.
The shared contract can represent CURRENT/STALE/DISABLED, but these producers
cannot qualify those live states without a separate source-bound observation
clock, policy and runtime enabled-state export. There is deliberately no fabricated
BLOCK/ALLOW or DISABLED fixture masquerading as an existing production contract.
Injecting such extra fields is rejected. A stale MacroGate input cannot establish
an active multiplier. A missing NewsGuard value cannot establish healthy ALLOW.

The exact existing bridge/watchdog behavior is recorded in CC00 SOURCE_MAP.md.
Nothing changes its missing-GV no-veto behavior, stale-GV 3600s bridge policy,
watchdog file/row policies, or reduce-lot semantics. Watchdog NewsGuard C policy
is distinct from B policy; no blanket Pause label is introduced. Eight action
categories remain explicit and all runtime effectiveness stays UNKNOWN.

Scope limit for review: qualified runtime GV/health telemetry is absent, so this
module completes the feed-read slice only. No current feed/runtime effectiveness
qualification or new safety policy is claimed. No runtime probe should be added
just to make the read-only presentation green.
