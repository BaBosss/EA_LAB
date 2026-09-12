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

## Report V3 native MT5 EA Detail

Phase B extends this same index and EA Detail with `READ_ONLY_PRESENTATION`
authority. Implementation gates are not independent milestone review. No MT5
execution, report regeneration, promotion, or research verdict change is performed.

Detail order: tested setup; separate MAIN/BWD graphs and compact metrics;
evidence/execution/research/package status; source explanation; changed parameters;
key parameters; searchable full parameters. Model2/unknown/diagnostic models do not
expose research performance cards. `eqdd_pct` explicitly labels equity DD; legacy
DD retains its original label. Cycles are not relabeled as source-emitted baskets.

### Binding contract in the existing pipeline

The builder discovers existing `factory/runs/**/report_package_manifest.json`
objects at the exact requested Git commit. A manifest opts an **existing EA
record** into graph presentation through its existing metadata field:

```json
{"metadata":{"native_graphs":{
  "ea_id":"exact-existing-record-id",
  "basis_id":"exact-existing-evidence-basis",
  "main":{"role":"MAIN","from":"2023.01.01","to":"2025.12.31",
          "report":"MAIN/report.htm","report_sha256":"<64 lowercase hex>",
          "asset_ref":"exact-img-src.png"},
  "bwd":{"role":"BWD","from":"2020.01.01","to":"2022.12.31",
         "report":"BWD/report.htm","report_sha256":"<64 lowercase hex>",
         "asset_ref":"exact-img-src.png"}
}}}
```

Report paths are package-relative; asset_ref is relative to that report. There is
no filename search or positional selection. Report and available dependencies
must be manifest artifacts. MAIN/BWD cannot share a report or resolved asset path.
Multiple packages claiming one EA are refused. Metadata cannot create EA records,
metrics or conclusions. Legacy records without graph fields remain compatible.

Regular Git blobs are copied into a private temporary closure, inspected through
the unchanged Phase A helper, then validated by the existing authority
`tools/reporting/report_package_integrity.py`. Missing expected images display
`GRAPH ASSET MISSING`; unsafe references, untrusted identity or failed package
integrity display `GRAPH ASSET REFUSED`. A declared artifact absent from Git fails
integrity and is REFUSED. Unidentifiable malformed manifests are never attached
by a guess. Git symlinks, traversal, absolute/external references, hostile paths,
output reparse components, overwrite collisions and hash mismatch fail closed.

Per-record `native_graphs.main/bwd` has state/reason and, when bound, role/window,
EA/basis, canonical SHA, package identity/hash, report hash and closure counts.
AVAILABLE adds asset_ref, asset_sha256, allowlisted media_type and href:

`artifacts/native/<canonical SHA>/<128-bit package+EA digest>/<role>/<full asset SHA256>.<raster extension>`

Full package hashes remain in the DTO. The shortened directory digest avoids
Windows path-length failures in normal preview roots. The browser validates this
binding and namespace, fetches without redirects, checks the full SHA256, and
requires successful decoding before exposing a raster Blob URL. Tapping opens
that verified image larger. Wrong HTTP/cache bytes and signature-only undecodable
images remain visible REFUSED/unavailable; no image interpretation is performed.

`sw.js` needs the `v3.2-native` generation to replace the old cached UI; native
asset requests bypass cached shell responses. Only isolated loopback tests activate
it. No production rollout occurs. Existing Monitor cached/offline semantics stay
unchanged. A stale snapshot may show its own pinned historical report only; missing
offline asset bytes remain visible and never substitute another package/version.

### B16 H08 legacy adapter

The explicit adapter reads the existing `final_artifacts.sha256` and its canonical
artifact bytes. Declared hashes feed a temporary manifest for the same package
validator; no new index/SOT is persisted. Window/report/set hashes join the existing
validation manifest, run receipts, metric summary, center lock and tester inputs.
Both MAIN and BWD have four references and zero assets at canonical base
`346175b42e68405aea0bc099a67009090bfedc0e`: two `GRAPH ASSET MISSING` panels and
graph evidence `INCOMPLETE`. No H08 graph selection is invented; merely adding
images does not authorize selecting one without a future explicit binding.

Canonical metrics and `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE` remain
unchanged. Package integrity and unknown independent review status are separate.
The explicit center/parent set hashes permit the textual diff
`_16_RsiLow: 30.0 -> 35.0`; source-selected RSI fields supply key parameters.
All frozen set parameters remain searchable. Neither parameter effectiveness nor
strategy explanation is inferred from parameter names.

### Phase B acceptance

Run the existing data/UI, reporting and Monitor V3.1 cages, plus:

```text
python -m unittest discover -s tools/mobile_report_hub/tests -p test_native_graphs.py -v
python tools/mobile_report_hub/tests/test_native_graphs.py --export-browser-fixture <evidence>/preview
node tools/mobile_report_hub/tests/browser_native_graphs.cjs <evidence>
```

Build the normal index into `<evidence>/preview` first. The fixture exporter uses
the existing native B15 PNG with two explicit test-role bindings in a disposable
Git repository. Metrics/parameters in that clearly labeled fixture are test values,
never production H08 evidence. Coverage includes valid/missing permutations,
identity/window/hash refusals, unsafe paths, integrity failures, Git links,
output reparse/collision refusal, legacy records, H08 preservation, decoding,
390x844 and 1280x900 rendering, larger inspection, search, and an actual service
worker with a poisoned old cache. No test launches MT5.
