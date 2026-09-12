# QRESET-04 verification

Base: `74dac79aadd1210c09b77e644f507a42bae1f570` (exact fetched origin/master).

Author: Codex. Scope: `prototypes/owner_research_cockpit_v1/` only. No independent product acceptance is claimed.

## Executed evidence

- Node model/provenance checks: 7 tests covering typed fixture envelopes, per-row provenance, qualified readiness, UNKNOWN/stale suppression, duplicate/future observations, owner qualification/expiry, authority rejection, and byte-for-byte native asset / pinned source hashes.
- Playwright with installed Microsoft Edge: 9 acceptance groups, all PASS. Full result: `artifacts/browser-results.json`.
- Seven screens rendered at both 390x844 and 1280x900 with no whole-page horizontal overflow.
- Nineteen real screenshots: 14 full-page screen captures, 2 exact viewport overview captures, 3 owner failure-condition captures. Browser clock explicitly fixed at `2026-09-12T07:05:00Z`.
- Reviewed mobile/desktop overview and mobile evidence images visually. Key CountBars parent→child change appears before the graph; native graph is the supplied original, never redrawn.
- No browser console errors, external requests or mutation requests during acceptance. Tests use an ephemeral loopback server and stop their own browser/server.

## Failures found and repaired before final acceptance

1. The poisoned-asset test originally changed only the URL fragment, so the browser retained its document and did not fetch the poisoned asset. Unique query URLs now force a document reload. The real mismatched-byte path passes with REFUSED and no image.
2. The empty data-URL favicon violated the restrictive image CSP and generated console errors. Removed that favicon; the local server returns 204 for favicon requests. Console-error assertions remain enabled and pass.

## Practical limits

The static fixture naturally expires after 24 hours; its clock is never relabeled as current. After expiration, positive sample states are available in the dated screenshots or repeatable browser tests. A new actual data adapter needs a separate contract.

Only a historical native image and historical parameter declarations are source-bound project artifacts. Sample readiness, lanes, optimization and owner requests are invented. The historical document is not a current readiness decision. EXACT verifies asset bytes/decoding, not the complete Report V3 package gate. Phone hardware, Safari/Firefox and a formal accessibility audit are outside this check.

No accepted-system code, risk/defaults, taskboard, PROJECT_STATE, AGENTS, deployment, MT5/VPS or public hosting is changed by this prototype. Repository hooks run on the prototype commit; their output is separate from these UI tests.
