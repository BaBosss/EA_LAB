# Owner Control Tower Monitor V3.1

Read-only, repository-only implementation candidate. Deployment is NOT PERFORMED.
Independent review is REQUIRED; implementation tests are not independent review.
This is a presentation extension of V2, not a new Control Tower or monitoring source of truth.

## Views

- Overview: canonical global monitoring declaration, pinned SHA, snapshot age, lane observation counts, NEED BOSS, current plan and ordered next context.
- Work: Summary + Agent Graph + Detailed lanes, with touch/keyboard Inspect and three presentation-only copy-context actions. Canonical taskboard header declarations and Lane Registry observations in separate groups. WAITING, REVIEW, INTEGRATING, PAUSED and FROZEN retain their names. DONE and other large groups are disclosed on demand.
- Runtime: existing monitor-health source observations; workers/jobs, Long Jobs, MT5, VPS and scheduler health remain UNKNOWN without qualified inputs.
- EA Lab: existing portfolio, masked SafeProjection accounts, research filters, detail pages and compatible comparisons.
- Alerts: owner attention, conflicts/freshness warnings and unchanged SafeProjection severities.

## Data contract and authority

The existing index gains one `control_tower` object, version 3, described by
`control_tower.schema.json`. The enclosing index remains schema version 1 for its existing V2 fields.

| Field | Exact source | Authority / derivation | Freshness / failure |
|---|---|---|---|
| project.global_state | `PROJECT_STATE.md` at exact requested Git SHA | Only the dedicated `Global state` declaration; never historical narrative | Pinned Git statement; missing pattern UNKNOWN |
| project.current / next | `PROJECT_STATE.md`, `### 5.1 NOW` | Literal bold bullet titles and numbered plan items, source order; PLAN_CONTEXT_ONLY | Missing section UNAVAILABLE; includes completed/constrained work, never executable readiness |
| work | `AGENT_TASKBOARD.md` plus its declared `TASKBOARD-ACTIVE-PARTS` | First status-leading code span of ORDER headers only; OPEN is UNKNOWN; multiple state tokens or duplicate IDs CONFLICT | Exact Git provenance; historical header status is not current process proof; missing declared part stops build |
| registry | Output of canonical `scripts/lane_registry.ps1 -Command Audit -Json` against `D:\EA_LAB_CONTROL\lanes\registry-v1` | Operational, NONCANONICAL; no raw objective, worker paths, account IDs or free-text blocker content copied | Explicit audit and per-row timezone-aware timestamps; 24h ceiling, 5min future tolerance; unknown/malformed/stale timestamps suppress current state |
| need_boss | Current qualified audit rows with exact E-class blocker (`E` or E followed by separator) | Explicit OWNER_EXTERNAL only; attention_required alone is not an owner request; owner action UNKNOWN because audit has no qualified action field | Stale, conflicting or unavailable rows cannot create current owner action |
| runtime | No qualified worker/Long Job/MT5/VPS/scheduler observation DTO supplied | UNKNOWN placeholders; lane ownership is not process health | No probes, launches or mutations performed |
| monitoring | Existing optional `EA_LAB_MONITOR_HEALTH_V1` via `--monitor-health` | LOCAL_MONITORING_NONCANONICAL; existing exact repo-head binding and allowlist preserved | Browser recalculates 30h age and rejects future/missing time for current display; unbound/stale coverage hidden |
| accounts/findings | Existing optional `SafeProjection` via `--safe-projection` | Existing strict masked/public-ID DTO; severity and research verdicts unchanged | Its timestamp has no timezone: freshness remains UNKNOWN; sensor/DD values explicitly historical observations, not current health |

Git text is escaped in the browser; local paths, URLs and long numeric identities are redacted
from new plan/header excerpts. Source path, content hash and canonical SHA remain inspectable.
Equal canonical/lane IDs with incompatible states remain separate CONFLICT rows, never an override.
Different identifiers are not guessed to mean the same task.

NEED BOSS's empty message is exactly “No owner action currently derived.” This does **not**
assert that the owner has no outstanding decisions. Canonical prose has no structured owner-action
list; generic hard-stop instructions and historic approval mentions are deliberately not requests.

The browser checks collection shapes and canonical provenance before rendering. A malformed
index, missing required V3 object, SHA disagreement or missing required Git source fails visibly.
Missing Lane Registry / monitor / SafeProjection is distinct from a valid empty observation.
Snapshots age after 24h, future timestamps beyond 5min are invalid, and offline/cached views
cannot claim current operational state. The pinned SHA is not a continuous remote fetch.
The V3 service-worker cache generation replaces V2 shell cache only on later authorized activation.

## Local build and preview

Run from an isolated checkout. Dot-source `scripts/use_python.ps1`, then call
`Assert-PortablePython -Root <worktree> -Provision` for the executable. Use the existing builder:

```text
python tools/mobile_report_hub/build_index.py --repo <worktree> --ref <exact-canonical-SHA> --expected-sha <same-SHA> --out <outside-repo-preview-directory> --lane-registry <audit.json>
```

Omit optional observation inputs to exercise UNAVAILABLE. Supply `--monitor-health` and
`--safe-projection` only for existing qualified outputs; do not run production collectors to
make a preview green. Export the canonical registry Audit using Windows PowerShell 5.1:
PowerShell 7 can coerce JSON dates to culture-specific strings in the existing audit script;
these are intentionally UNKNOWN, not interpreted heuristically. UTF-8 BOM input is accepted.

Copy the static assets from `mobile_report_hub/` into the outside-repo preview directory
alongside the generated index. Serve that directory on loopback only using a local static server.
Do not publish it or change any publication target. `?fixture=1` retains the explicitly labeled
V2 research fixture for historical display; it does not become production data.

## Verification

```text
powershell -File scripts/_test/run_mobile_report_hub_data_tests.ps1
powershell -File scripts/_test/run_mobile_report_hub_ui_tests.ps1
node tools/mobile_report_hub/tests/browser_v3.cjs <outside-repo-evidence-directory>
```

The browser harness expects `preview/report_index.json` under that evidence directory and
installed Playwright, AJV and Edge. Resolve dependencies through the installed workspace runtime
and existing AJV CLI module directories with NODE_PATH. It binds a temporary loopback server,
uses an isolated headless browser context and stops both when complete. Schema positive/negative,
five-view 390x844 rendering, one-row navigation, overflow, owner-attention fixture, stale/future,
cached/offline, missing/malformed JSON and canonical mismatch are checked. Service workers are
blocked in this harness: cached-response behavior is injected explicitly; real PWA installation
and production cache activation remain untested/unperformed.

No trading/core/risk code, research result, registry source record (other than this task's own lane),
Scheduled Task, VPS, MT5, publication destination or governance file is changed by V3.

## V3.1 Agent Graph integration

Graph JS/CSS are local service-worker shell assets under cache generation v3.1.
Git and Lane Registry have structurally separate graphs with internal scrolling.
No whole-page horizontal overflow is accepted at 390x844 or 1280x900. The builder
adds only consumed allowlisted Audit metadata: full head SHA, writer classification,
Registry classification, class-only blocker and explicit dependency evidence.
Missing Audit fields remain UNKNOWN; raw Registry free text is not exported.
Audit carries explicit dependencies and structured worker/ref/worktree/review
metadata through the existing safe projection; objective remains UNKNOWN.
Dependency regression starts from Registry-shaped files through actual Audit,
safe DTO and graph rendering, including stale/cached/offline and unsafe input.

See `docs/workflows/EA_LAB_MONITOR_AGENT_GRAPH_V31.md` for the exact field contract,
acceptance coverage and limitations. Run the unchanged foundation suite with
`node tools/mobile_report_hub/tests/agent_graph_v31.cjs` in addition to the commands
above. Browser coverage now includes source separation, Inspect, context generation,
clipboard-denial fallback, stale/cached/offline graph behavior and dependency edges.
This is an implementation candidate: REVIEW REQUIRED, no deployment or push.
