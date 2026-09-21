# EA_LAB Monitor Owner Webapp — 2026-09-21

Authority: `READ_ONLY_PRESENTATION`. This is an owner-facing extension of the existing Monitor, not a new source of truth, Registry, Control Tower, runtime controller, or trading surface.

## Owner entrypoint

The installed owner copy is opened from:

`D:\\OneDrive\\Monitor\\OPEN_MONITOR.cmd`

The launcher starts one loopback-only viewer on `127.0.0.1:8768`. It installs no service or Scheduled Task, never binds a wildcard interface, and has no write/command endpoint. If another unknown process owns the requested port, it refuses instead of killing or replacing it.

## Source ownership

| View | Existing source | Interpretation |
| --- | --- | --- |
| Project status | exact Git `origin/master` + `PROJECT_STATE.md` | canonical project declaration |
| Work | Lane Registry + existing lease/job state/result | lane/job observations; not ChatGPT-window liveness |
| Balance / Equity | existing DailyMonitor account snapshots | sampled account observations; broker clock timezone remains unqualified |
| EA deployment rows | snapshot MAGIC rows + canonical `DEPLOYMENTS.csv` | inventory mapping only; runtime identity remains separately gated |
| Research | existing Monitor `report_index.json` | source-bound report evidence; separate from live account performance |
| Template | canonical top-level `ea_template/*.mq5` wrappers with `LAB_ENTRY_N` | source presence only |
| News | existing DailyMonitor `news_week.csv` | calendar observation; impact/guard window not invented |
| Macro | existing MRIS `regime_state.json` | MRIS observation; EA-effective MacroGate remains separate |
| Knowledge | accepted Second Brain static reader manifest/index | hash-pinned research navigation, not project status |

## Refresh semantics

Browser auto-refresh / Refresh now only rereads approved local outputs. It does not fetch broker data, update NewsGuard, run MRIS, launch jobs, refresh Git, run MT5, or mutate Registry state. The UI shows source observation times separately from the browser refresh event.

The self-contained `index.html` delivery is an offline snapshot. When opened directly from OneDrive it keeps the same source provenance embedded at build time and must not be interpreted as a live local server.

## Performance rules

- Account IDs are masked and exported as stable presentation hashes plus the last three digits.
- Balance/equity lines join existing samples only; no tick-level continuity is claimed.
- The source broker clock has no qualified timezone in the snapshot schema, so account-series freshness is `UNKNOWN` rather than inferred.
- No deposit/withdrawal-adjusted return is calculated.
- Per-MAGIC floating P/L, lots and position counts are observed values. They are not promoted to realized EA performance.
- Raw lots by symbol are not summed into economic exposure or a portfolio risk score.
- PF/win-rate/MAIN/BWD metrics appear only from source-bound research records and remain separate from live account tracking.

## News / Macro rules

The current calendar source does not carry an authoritative impact level or effective NewsGuard stop-open window. The UI therefore displays those values as unavailable/unknown rather than copying the visual mockup's example values. Unplanned geopolitical news is not synthesized from the economic calendar.

MRIS regime/barometer rows retain their producer timestamp and freshness. They do not prove that a deployed EA consumed MacroGate at that time.

## Extension contract

Future feeds must arrive through a named read-only adapter with: exact source owner, schema/version, entity identity, source timestamp/clock basis, stable-before/after read or immutable hash, freshness rule, missing/malformed/future handling, redaction rules, and a direct UI consumer. Missing fields remain `UNKNOWN`/`UNAVAILABLE`; no adapter may silently create strategy, risk, runtime, promotion or trading authority.

## Observation V1.1 additions — 2026-09-21

The owner view now consumes the existing `control_room_snapshot.json` as an explicitly separate observation source. It projects masked account identity, deployment/magic name, closed-deal-row count, observed/expected trade rate, judge-readiness state, current floating P/L/open lots/open positions where present, verification state, producer timestamp, producer Git head and reconciliation verdict.

These rows keep the producer's own binding visible. `DIFFERENT_REPO_HEAD`, stale mandatory inputs, failed runtime identity coverage, or `reconciliation_clear=false` are not converted into a green Monitor status. The UI labels this section **Forward / live decision readiness** instead of scoring an EA good/bad.

NewsGuard now exposes the dated canonical runbook reference `PreNewsMin=30` and `PostNewsMin=15`. The same runbook explicitly says to regenerate/re-verify when `DEPLOYMENTS.csv` changes, therefore Monitor marks the reference configuration historical and leaves **effective live guard state = UNKNOWN** without attachment/log evidence. Calendar rows still do not receive invented impact labels.

No VPS attach, NewsGuard/MacroGate activation, terminal global-variable mutation, news fetch, trading change, scheduler change or public/private hosting change is performed by this addition.
