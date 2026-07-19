# ORDER-138 — Codex blind-audit triage (Opus judge, 2026-07-19)

Audit: `CODEX_ORDER138_AUDIT.md` (9 findings: 4 SEV-1 / 5 SEV-2). Every finding verified
against code before judging. Fix pack = **138b** (same working set, re-verified full loop).

## ✅ FIXED (138b) — 4 findings

| # | Finding | Fix |
|---|---|---|
| F1 SEV-1 | `rc_peak_eq` not benign — foreign higher-equity legacy peak migrates in → KillDD liquidates the current account on tick 1 (cross-account kill via a second door; my spec's "benign keys" classification was wrong, Codex caught it) | Consent gate widened to **every legacy key the init would read**: active kill/halt + `rc_peak_eq` (any value) + `acct_hwm` (when acct gate on). `RiskControl.mqh` gate rewritten; `Inputs.mqh` + migration doc corrected; tests S8 (foreign peak) + S9 (halt branch, mixed-key preservation) added |
| F3 SEV-1 | Mid-reconcile `Kangaroo_PairPersist()` rewrite drops the marker first — a failed leg write destroys the only durable copy of the pair intent; both callers ignored the return | **No mid-flight rewrite**: the committed record stays on disk untouched while any leg is live (restore revalidates tickets, so a closed leg inside the old record is harmless); checked clear only when both legs are broker-confirmed gone |
| F4 SEV-1 | `Persist_Del` unchecked — a failed delete leaves `*_closeall=1`; restart later liquidates an unrelated future basket | New `Persist_DelChecked()`; both CloseBasket paths keep the latch armed + own the tick until the delete is confirmed (retry every tick; blocks new entries meanwhile = under-exposure direction) |
| F9 SEV-2 | TTL keep-alive never touches intent keys — unresolved liquidation on a quiet symbol could expire out of the GVs (~4 weeks) | Intent keys re-touched every ~60s while the liquidation retries (`exit_closeall` / `k16_closeall` / pair record). No-tick limitation documented (no ticks = no retries either) |

## ✅ FIXED via F7 (test gaps) — partial F6

- S9: active `rc_halted` no-consent branch + mixed-key "nothing migrated or deleted" atomicity.
- S8: foreign-peak fail-closed.

## ❌ REJECTED — 2 findings

- **F2 SEV-1 (closeall proceeds when arm persist fails):** deliberate degraded mode, now
  documented explicitly. Full-basket closes are SAFETY exits (money-stop / emergency-DD /
  kill) — refusing to flatten a losing basket because a GlobalVariable write failed holds
  exposure hostage to persistence. Asymmetry with #2 pair-close (which DOES abort) is
  intentional: pair-close is profit-taking, aborting costs opportunity not safety.
  Degraded mode = loud log + loss of restart-resumption only; the cage (KillDD) remains
  supreme over any residual.
- **F5 SEV-2 (ticket >2^53 double precision):** real broker tickets are ~1e9-1e10;
  2^53≈9e15 — ~6 orders of magnitude of headroom. Same encoding pre-dates 138 (132b
  `k16_pair_a/b`), not a regression. No machinery without a plausible failure mode
  (132b P3/R1-full precedent).

## ⏭ DEFERRED — F6 (fault-injection seams)

Deterministic persistence/execution fault injection in the money path = added complexity
inside the code being protected, with no known real failure mode it would catch beyond
what F1/F3/F4 fixes + S1-S9/PersistIntent scenarios already assert. Revisit if a live
incident ever implicates an untested failure path.

## F8 (doc understated pre-138 pair window) — ✅ FIXED

Migration doc now requires a pre-upgrade F3/journal check for an in-flight
`k16_pair_a/b` intent on Boss_16 instances; "window is nil" claim removed.

## Evidence (138 + 138b full loop)

- compile 0/0 ×9 wrappers + tests (zero-warning)
- unit tests 7/7 PASS — `PersistMigrate_Test` 9 scenarios · `PersistIntent_Test` (new) 6 scenarios
- regression cage 8/8 CLEAN (Boss_18 6020 trades exact) — post-138b run = final proof
