# Control Center READ source map v1

Implementation base: `b0df07ee776acd8450c1d06deba37cb63fbeb02f`.
The accompanying JSON pins the inspected owners' exact bytes. This is an adapter
inventory, not a second source of truth or acceptance record. Owner authorization
is the 2026-09-12 CODEX LONG IMPLEMENTATION RUN contract in chat; the external
planning package is checksum-verified planning input, not canonical intake.

| Observation | Existing owner / reader | Clock, identity and limits |
| --- | --- | --- |
| Research EA/family/variant/home/basis/model/status/metrics | `tools/mobile_report_hub/build_index.py`: existing extractors and `build` | Exact Git SHA and per-record provenance. Preserve exact metric names; UNKNOWN fields remain UNKNOWN. Report presence does not establish acceptance. No Model2 performance. |
| Factory report package / native graphs | `tools/reporting/report_package_integrity.py`, `tools/reporting/mt5_report_assets.py`, existing `add_native_reports` / `project_native_graphs` | Existing manifest and MAIN/BWD identity/hash/window binding. Never find an image by similar filename. Missing native bytes remain MISSING, refused package remains REFUSED. |
| B16 H08 setup/config/parent/parameters | Existing `b16_h08_record`, `factory/runs/b16_h08_20260831/usdjpy_buy_h1_opt01/final_artifacts.sha256` | Existing integrity closure verifies receipts, set hashes, runner lineage and metric windows. Package integrity does not establish independent review. No new historical report regeneration. |
| News calendar | `scripts/news_calendar.ps1` -> `portfolio/news_week.csv` | Exact six-column schema. Producer filters High impact and converts US Eastern to Bangkok with Windows timezone rules. BkkTime is UTC+07 event time, NOT production/available-at time. TimeRaw is display provenance only. No producer observation timestamp: feed freshness UNKNOWN even for upcoming events. |
| MRIS classifier snapshot | `scripts/mris/mris_classify.ps1` -> `portfolio/mris/regime_state.json` | generated_utc is producer UTC; risk_index is a dimensionless weighted score. This snapshot has no execution TTL or runtime version/attachment binding. Age is reported without adopting Monitor 24h/26h TTL. Runtime effectiveness UNKNOWN. |
| MacroGate input timeline | `scripts/mris/mris_export_regime.ps1` -> `portfolio/EA_LAB_mris_regime.csv` | datetime,state,ri,flags; UTC minute rows. Exporter can fall back to now if source timestamp is absent, and may fold crisis state. Therefore timeline alone is not proof of classifier data freshness. Require strictly ordered unique rows; never borrow filesystem mtime. |
| NewsGuard control | `ea_projects/(Boss)_NewsGuard/NewsGuard_Core.mqh`; `ea_template/core/Execution.mqh` | Terminal-local NEWSGUARD_BLOCK_ magic value >=0.5 vetoes new opens and pending placement. Missing GV means no bridge veto, not healthy ALLOW. Watchdog C/B/N policies are distinct; C can close positions. No qualified safe GV/health export found: block and affected EA UNKNOWN. |
| MacroGate control | `ea_template/core/MacroGate_Core.mqh`; `ea_template/core/Execution.mqh` | MACROGATE_BLOCK_ and MACROGATE_LOTMULT_; live bridge ignores values older than 3600s, absent/invalid multiplier becomes 1.0, only (0,1) reduces lot. Watchdog file and row age policies are configured separately (defaults 48h). None is a new presentation TTL. No qualified GV export: actual block/multiplier UNKNOWN. |
| Existing Monitor health / accounts | `tools/mobile_report_hub/build_index.py`, SafeProjection | Existing strict allowlists remain owned there. Neither supplies qualified NewsGuard/MacroGate execution observations. This module does not parse raw account snapshots or map symbols to EAs. |

Capabilities are explicit: READ evidence and feed observations supported; NEW MARKET
ENTRY, ADD, NEW PENDING, CANCEL EXISTING PENDING, MANAGE BASKET, FLATTEN, HEDGE and
CLOSE effectiveness are all UNKNOWN without source-bound runtime evidence. There
is no control function, runtime probe, collector, job runner, ranking or verdict.

Contracts distinguish missing, malformed, future, stale, disabled, unknown and
historical inputs. CURRENT requires a named domain policy and qualified UTC
observation clock. SourceObservation's generic policy argument is an internal
adapter boundary; callers must not deserialize an arbitrary TTL as source authority.
Timestamps use UTC seconds in envelopes; source-specific conversions belong to
adapters. Unknown available-at times stay null. Error reasons are fixed codes;
raw source strings, local paths, account IDs and exception messages are not echoed.

Run focused tests from the worktree:

```powershell
. ./scripts/use_python.ps1
python -m unittest discover -s tools/control_center/fixtures -p 'test_*.py' -v
```
