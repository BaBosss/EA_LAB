# Owner Research Cockpit V1

**PRESENTATION ONLY / NO AUTHORITY.** Standalone static prototype for owner contract `QRESET-04-OWNER-WEB` (2026-09-12). One isolated frontend author; no accepted Monitor V3.1, Report V3, STATUS generator, Control Center, EA/core, MT5, VPS or deployment edits. No public hosting, live trading connection or push.

## Review locally

From this directory, with Node available:

```powershell
node serve.cjs
```

Open **http://127.0.0.1:4174**. The server binds loopback only, serves an explicit file allowlist, accepts GET/HEAD only and disables caching. There is no package installation, bundler, backend, service worker, analytics, external font or runtime API. Stop the local server with Ctrl+C when finished. Opening index.html directly with file:// does not support the module/data loading; use the local server.

On this desktop the bundled Node executable is:
`C:/Users/patip/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe`.

## Features

- Overview: READY/BLOCKED/PARKED/RUNNING counts, NEED BOSS, stage conveyor, next research sample, lane observations, missing monitor input and blocker heatmap.
- Research: searchable, intersecting status filters; current stage, MAIN/BWD, optimization, Model4, evidence, next step and blocker per card.
- Template readiness: eight illustrative families with separate semantics, build/set, source-review and packaging gates; horizontally scrollable matrix on phones.
- Optimization: prerequisites, search, stable region, center freeze, BWD use, untouched HOLDOUT and Model4 gate.
- Evidence: key parameters before graphs; CountBars parent 2 → child 3; frozen MACD 12/26/9; searchable displayed setup; exact historical MT5 asset with larger inspection, MISSING and REFUSED states.
- Blockers: A PRODUCT / B HARNESS / C ENVIRONMENT / D EXECUTION INCOMPLETE / E OWNER/EXTERNAL.
- Owner action: only explicit, qualified, unexpired, bound E-class fictional requests; no approval buttons.
- Source drawers: source/JSON pointer, full ref SHA, observation time, status, freshness and fixed presentation authority. Pinned source files also include SHA-256.

## Data contract

Exact boot base: `74dac79aadd1210c09b77e644f507a42bae1f570`, fetched from origin/master on 2026-09-12. This is a **pinned canonical snapshot**, not a continuous claim about current remote HEAD.

`fixtures.json` is the only runtime data input. All `FX-*` entities and readiness/optimization/blocker/action facts are **fictional UX fixtures**, including the sample owner request. The base SHA binds their design context, never their truth as project facts. Family names are used to exercise realistic information shapes; the rows are not a canonical project status import.

Every observation has `source`, `refSha`, `observedAt`, `status`, `authority`, and a grouped `data` payload. Payload fields inherit that observation's provenance. Aggregates explicitly identify their derivation and exclude unqualified rows. Source references are actual JSON pointers. The envelope and rows must use `PRESENTATION_ONLY_NO_AUTHORITY`; no presentation status is exported to canonical systems.

Freshness is recomputed using browser time: 24-hour maximum age, five-minute future tolerance, timezone required. Offline, stale, duplicate, unbound and invalid rows show UNKNOWN/PENDING with their data suppressed. The sample clock is fixed in the source fixture at `2026-09-12T07:00:00Z`; **it naturally becomes stale**. Reloading does not refresh its timestamp. The scenario picker can make the snapshot stale/unbound/offline, but cannot make an old snapshot fresh. Browser tests fix their own clock, explicitly recorded in the test result.

Owner action requires all row/envelope gates plus `state=BLOCKED`, exact class `E`, `explicit=true`, `qualified=true`, matching `boundTo`, nonempty action and future expiry. An attention flag or E-class alone is insufficient. Requests and open drawers disappear when evidence expires, even without reload. No response, signature, execution permission or promotion is stored.

Monitoring/process health stays UNKNOWN: a fixture lane record is not proof of a running worker. No local Registry or monitor collector is called by this app. The development lane's external Registry claim is coordination metadata only and is not ingested into the UI.

## Native asset and historical parameters

The single supplied original PNG comes from:

`factory/runs/b15_countbars_sens01_20260831/visuals/native/B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1.png`

It is copied byte-for-byte from the pinned Git blob by `prepare_fixture.cjs`. Its exact path/ref/SHA-256 are recorded in `fixtures.json.native`. Identity: B15 COUNT3, GBPUSD/H4, MAIN 2023–2025, Model1, **Meta5c**. It is never relabeled as a fictional EA's performance. Historical parameter declarations come from the pinned `docs/research/B15_COUNTBARS_SENS_01_RESULTS.md`, whose hash is also recorded. No performance numbers or new strategy verdicts are inferred from the graph.

The browser fetches this one allowlisted asset, checks full SHA-256 with Web Crypto, requires successful image decoding, and only then displays EXACT. Mismatch is REFUSED. The missing BWD panel means **this adapter supplies no bound BWD image**, not that all repository BWD evidence is absent. The separate REFUSED panel illustrates a negative fixture exercised by the browser test. There is no chart reconstruction, SVG graph substitute, generated equity curve, filename guessing or cross-lane comparison.

EXACT means verified historical asset bytes only. It does not validate an entire report package or confer Report V3 acceptance, current research validity, Candidate or Demo status. This adapter does not replace Report V3's package integrity pipeline.

## Validation

```powershell
node --test model.test.mjs
node browser.test.cjs artifacts
```

Browser tests require installed Playwright plus Microsoft Edge. On this desktop set `NODE_PATH` to `C:/Users/patip/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules`. Tests start/close a temporary loopback server and an isolated headless Edge context, never MT5. Each browser run checks seven screens at 390x844 and 1280x900 and writes screenshots/results to `artifacts/`. Source-contract tests use Node's built-in test runner.

Coverage: no page overflow; search/filter intersection and empty state; UNKNOWN and stale rows; source drawer and Escape dismissal; native EXACT/MISSING/REFUSED; real poisoned-asset hash refusal; parameter search; qualified owner request suppression under stale/unbound/offline and actual network offline; time-based expiration and drawer closure; malformed data and authority escalation; no console errors, external connections or mutation requests.

`artifacts/browser-results.json` records actual executed checks. Screenshots are real browser captures at the explicitly simulated test clock. Screenshots are test evidence, not current operational observations. Desktop/mobile overview viewport images show exactly 1280x900 / 390x844; other screenshots are full-page captures at those widths.

## Boot sources and scope

`fixtures.json.sources` records hashes for START_HERE, PROJECT_STATE, AGENTS, central/P03 taskboards, Monitor V3.1 source/docs, Report V3 source/docs, report schema/ladder, Template readiness docs and Lane Registry metadata source. These were read without modifying the accepted systems. The owner's message is the exact task contract; no canonical taskboard or governance row is added.

Development DAG: exact-ref boot and lane isolation → static data model → seven-screen renderer → model/browser negative checks → visual inspection → one prototype commit. Acceptance-critical UI/data work remained with one author. Only the prototype subtree is staged. No high-risk code was authored; implementation checks are not an independent product acceptance review.

## Integration options and limits

1. Review this as a standalone local design artifact, using the committed screenshots after its fixture expires.
2. Under a separate approved task, implement a static read-only adapter from accepted source DTOs. Preserve source authority, duplicate handling, snapshot age, exact bindings and fail-closed owner qualification.
3. If selected for the accepted mobile hub, extract visual components under a separately reviewed contract and run Monitor/Report regression cages; use the accepted native graph verifier rather than replacing it with this prototype verifier.

No integration, public hosting, production data connection, mobile PWA installation, phone hardware testing, Safari/Firefox coverage or independent acceptance review is claimed. Accessibility checks here are keyboard/focus, readable responsive layout and basic semantics, not a full accessibility audit. Readiness/optimization fixtures are examples only, not a project-authoritative answer to which EA should actually run next.
