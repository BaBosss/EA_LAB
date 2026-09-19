# OF01 — Value-Edge Rejection / Reversal

Status: `ORDER_FREE_RESEARCH_COMPONENT / TEMPLATE_EXIT_BINDING_REQUIRED`

- Family/Variant: unallocated; no FamilyID or Boss wrapper.
- Parent: source-derived Context → Location → Evidence → Trigger → Risk concept.
- Change: EA_LAB numeric V1 proposal; not original-source parity.
- Direction: mirrored long/short.
- Context: latest completed M15 close strictly inside prior completed-session value area.
- Location: M5 test at VAL (long) or VAH (short), frozen zone `0.20 * preceding ATR14`.
- Evidence: executed total volume `>= 1.50 * median(previous20)`; genuine executed-side delta opposing the test by at least `0.20`; rejection wick `>= 0.40` of range.
- Trigger: completed M5 close beyond test high/low within next 3 bars.
- Cancel: two consecutive completed closes beyond the exterior frozen zone; expiry; source/profile/context identity change; malformed/stale/future/unqualified input.
- Prospective entry: caller-observed ask for long / bid for short; not a fill.
- Stop: adverse extreme from test through confirmation plus frozen buffer.
- Target: frozen prior-session POC.
- Cost/RR: caller-supplied all-in price cost; net RR must be `>= 1.50`.
- Orders/sizing/stack/recovery/hedge: none.
- Strength/confidence: not invented and not emitted.
- Session/profile/Home/symbol mapping: explicit upstream pins required; unresolved here.
- Performance/optimization/HOLDOUT: not run.
- Consumer gate: geometry-owning Template exit/execution contract plus qualified data and recipe.

See `docs/research/ORDERFLOW_COMPONENTS_V1.md` for the full contract and evidence boundary.
