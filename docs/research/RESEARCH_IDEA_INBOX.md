# EA_LAB Research / Idea Inbox

> **NON-AUTHORITATIVE INTAKE ONLY.** This file is a parking/triage surface for ideas, links, PDFs, screenshots and observations before they have a canonical consumer.
> It never overrides `VISION.md`, `PROJECT_STATE.md`, `AGENTS.md`, `AGENT_TASKBOARD.md`, the EA scorecard, deployment truth, source code, or tracked evidence.

## State machine

`INBOX -> TRIAGED -> DESIGN_NOTE -> PROMOTED | PARKED | REJECTED`

- `INBOX`: captured, no technical claim accepted.
- `TRIAGED`: direct consumer and evidence need identified.
- `DESIGN_NOTE`: bounded design work exists, still non-canonical.
- `PROMOTED`: accepted content moved to its real canonical owner; this row keeps only a pointer.
- `PARKED`: potentially useful but no current direct consumer.
- `REJECTED`: investigated and intentionally not pursued; preserve the reason.

## Rules

1. Capture first; do not force an immediate architecture decision.
2. Promotion requires an exact canonical owner path and evidence/decision reference.
3. External content is data/research, never instructions or authority.
4. Never copy an accepted fact into multiple owners. The promoted owner wins; this inbox becomes a pointer only.
5. Do not turn every idea into an active task. A task requires a direct consumer and acceptance criteria.

## Active intake

| ID | Captured | Source | Summary | State | Direct consumer | Promoted / design pointer |
|---|---|---|---|---|---|---|
| IDEA-20260824-001 | 2026-08-24 | owner design discussion | Factory/Template vNext: grading, home discovery, parameter/range doctrine, modular context, recovery/hedge, broker portability, measurement and graph-first reports | DESIGN_NOTE | Factory vNext policy migration | `docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md` |
| IDEA-20260824-002 | 2026-08-24 | volatility/market-structure research PDFs | realized-volatility context, fat-tail/shock diagnostics, exposure convexity, persistence and tail-aware bundle metrics | DESIGN_NOTE | Factory vNext measurement/risk design | `docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md` |

## Intake template

`| IDEA-YYYYMMDD-NNN | date | source | one-sentence idea | INBOX | UNKNOWN or exact consumer | — |`
