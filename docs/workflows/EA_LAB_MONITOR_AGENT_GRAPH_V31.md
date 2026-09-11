# Monitor V3.1 Agent Graph integration

Implementation/test result only: REVIEW REQUIRED. No self-review verdict, push,
public deployment, runtime, MT5 or VPS mutation is authorized by this work.

Base canonical: `f46bb53a142c8b87ac7b79e3f58dbc1068d2be62`.
Reviewed foundation entered this checkout through `0edf5eb4` from `cdaa02d4`.
Blocked operationalization commits `4b3a694d` and `2e57e3cf` were not imported.

## Existing Monitor integration

Navigation remains Overview | Work | Runtime | EA Lab | Alerts. Work contains
Summary, Agent Graph, and Detailed lanes. The dependency-free local
`agent_graph.js` and `agent_graph.css` load before the existing app. There is no
GraphCode dependency, new product, source of truth or execution surface.

Graph state columns are separately rendered under GIT_CANONICAL and
LANE_REGISTRY_NONCANONICAL authority groups. Each source has an internal horizontal
scroll region. Node buttons are keyboard/touch accessible and open the Inspect
panel, which retains full IDs and shows task/objective, worker/role, state and
freshness, ref/full head, safe worktree identity, blocker, review, dependencies,
owner derivation, and provenance. Unknown evidence is explicitly UNKNOWN.

COPY STEERING CONTEXT, COPY TASK CONTEXT and COPY REVIEW CONTEXT generate quoted
read-only text and call only the browser clipboard. A denied/unavailable clipboard
leaves selectable text. Copy rebuilds the projection at click time. There are no
Run/Kill/Launch/Resume/Send-to-Codex controls, commands or network mutations.

## Evidence contract and limits

The Registry Audit exports head SHA, writer boolean, explicit dependencies,
classification, blocker class and updated observation time. The builder now
projects only these consumed fields in addition to the existing fields:

| DTO field | Qualification / direct consumer |
|---|---|
| head_sha | Exactly 40 lowercase hex characters, otherwise UNKNOWN; Inspect/context |
| role | Boolean writer maps to WRITER or READ_ONLY; otherwise UNKNOWN; node/Inspect |
| registry_classification | Fixed classification allowlist; node inspection |
| blocker_class | Only A-E class prefix with existing separator rule; no raw prose; Inspect |
| direct_dependencies | Only explicitly supplied Audit dependencies list; safe exact IDs; graph/Inspect/context |

Missing dependencies are UNKNOWN, distinct from an explicit empty list. Unsafe or
malformed dependency entries become UNKNOWN, never a guessed or redacted matching
identity. Dependencies use exact Lane Registry IDs only. An unavailable or
ambiguous endpoint remains an UNRESOLVED relation with its supplied endpoint and
no invented node/state. Audit preserves the dependency field without coercing a
malformed scalar into a list. The safe projection accepts lists only from current,
eligible observations. Cached/offline display suppresses dependency claims, and
stale or conflicting endpoints cannot resolve an edge. Regression tests start
with Registry-shaped files, invoke the actual Audit, project its output and render
the graph, including unresolved, duplicate, stale and hostile dependency cases.

Audit does not export objective. Worker, branch, worktree basename, reviewer and
reviewed head use the existing bounded metadata projection; missing or unsafe
values remain UNKNOWN. No raw Registry lookup or new
collector was added. No local worktree paths, raw blocker prose, arbitrary Registry
free text or account identities are added to the DTO. Provider/model/PID/session
and process health remain UNKNOWN. READ_ONLY describes writer classification;
it is not evidence of a reviewer assignment. Full Git provenance remains separate
from noncanonical Registry metadata; absent Registry content hashes stay UNKNOWN.

The existing full-SHA Git canonical identity is retained. Equal Git/Lane IDs can
create OBSERVATION_CORRELATION only, never dependency or authority merge. Duplicate
IDs within a source remain separate CONFLICT nodes and suppress owner derivation.
Cycles retain explicit relation evidence and use the foundation conflict fallback.
NEED BOSS retains the exact qualified current E-class derivation; attention alone
and generic prose create no owner request. Global DEGRADED_MONITORING is unchanged.

Browser display rechecks project, Registry envelope and row timestamps. Cached,
offline, stale/future/unknown observations cannot claim current lane state or owner
action. Git states remain explicitly pinned header declarations, never process
health. Declared historical states are retained separately for inspection.

## Acceptance evidence

- Existing data tests plus five new DTO/identity/privacy cases: 46/46 PASS.
- Reviewed foundation deterministic fixtures: 15/15 PASS, unchanged test file.
- Existing static Monitor UI checks: PASS.
- Real headless Edge/Playwright: 390x844 and 1280x900 PASS, all five tabs, zero
  whole-document horizontal overflow and zero uncaught browser errors.
- Browser fixtures exercise empty/unknown, stale Registry and project, aging row,
  cached/offline, duplicate IDs, Git/Lane conflict, explicit and missing dependency,
  owner blocker, unresolved historical rows, hostile HTML, long IDs/titles, Inspect,
  three text-copy modes, copy after aging, and denied clipboard fallback.
- Service-worker v3.1 shell references both local graph assets and retains existing
  cache behavior. Browser tests block workers and inject cached-response headers;
  real PWA installation/activation and public deployment are not claimed.

Commands: `node tools/mobile_report_hub/tests/agent_graph_v31.cjs`,
`powershell -File scripts/_test/run_mobile_report_hub_data_tests.ps1`,
`powershell -File scripts/_test/run_mobile_report_hub_ui_tests.ps1`, and
`node tools/mobile_report_hub/tests/browser_v3.cjs <evidence-directory>`.
The browser harness requires installed Playwright, AJV, and Edge, and
`preview/report_index.json` generated by the existing builder at the pinned base.

Local browser results and screenshots:
`D:/EA_LAB_CONTROL/evidence/monitor-v31-final-integration-20260911`.
Clipboard success is captured through an isolated browser stub; actual system
clipboard contents are not modified. Required hooks run on commit; their output
and the exact resulting SHA are reported in the implementation handoff.
