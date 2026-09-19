# OF02 — Value-Edge Acceptance / Continuation

Status: `ORDER_FREE_RESEARCH_COMPONENT / TEMPLATE_EXIT_BINDING_REQUIRED`

- Family/Variant: unallocated; no FamilyID or Boss wrapper.
- Parent: source-derived Context → Location → Evidence → Trigger → Risk concept.
- Change: EA_LAB numeric V1 proposal; not original-source parity.
- Direction: mirrored long/short.
- Context: latest causally available completed M15 close strictly beyond prior completed-session VAH/VAL; unknown earlier context is unavailable.
- Acceptance: two consecutive completed M5 closes beyond the exterior frozen zone; second bar executed volume `>= 1.50 * median(previous20)` and directional executed-side delta at least `0.20`.
- Frozen geometry: `0.20 * preceding ATR14` at the first breakout close.
- Retest: within next 6 completed M5 bars, overlaps frozen zone and closes on breakout side of the profile edge.
- Trigger: within next 3 completed M5 bars, close beyond retest extreme with strictly directional delta.
- Cancel: close past the value-side boundary of the frozen zone; expiry; source/profile revision; malformed/stale/future/unqualified input. Ordinary M15 progression is not a reset.
- Prospective entry: explicitly pinned execution-source/instrument ask for long / bid for short, observed strictly after confirmation inside the current-closed-bar decision envelope; not a fill.
- Stop: adverse extreme from retest through confirmation plus frozen buffer.
- Target: prospective 2R from supplied quote and structural stop.
- Time exit: proposed 12 M5 bars after actual fill; consumer-owned, not implemented.
- Orders/sizing/stack/recovery/hedge: none.
- Strength/confidence: not invented and not emitted.
- Session/profile/Home/symbol mapping: explicit upstream pins required; unresolved here.
- Performance/optimization/HOLDOUT: not run.
- Consumer gate: geometry-owning Template exit/execution contract plus qualified data and recipe.

See `docs/research/ORDERFLOW_COMPONENTS_V1.md` for the full contract and evidence boundary.
