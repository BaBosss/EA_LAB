---
artifact_type: SECOND_BRAIN_MILESTONE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
canonical_base_sha: fc1189277dd9690a1970b8f5f5dd00a75507a3ce
direct_consumers:
  - future XAUUSD/H4 exit-redesign preregistration (if one is ever opened)
  - cross-symbol exit-concentration negative-knowledge deduplication
---

# Second Brain Milestone — B16 XAUUSD/H4 Exit-Concentration Repair01

This milestone makes the already-accepted Repair01 result directly discoverable from the Second
Brain index. It does not replace the canonical result owner and grants no Factory, runtime,
HOLDOUT, Candidate, risk, deployment, trading, KINT, or Grade authority.

## Evidence

Canonical result owner: `docs/research/B16_XAU_H4_EXIT_CONCENTRATION_REPAIR01_RESULTS_20260905.md`.
Preregistration: `docs/research/B16_XAU_H4_EXIT_CONCENTRATION_REPAIR01_PREREG_20260905.md`.
Frozen diagnostic SHA256 `5194fa5986767d9c47a4c4220b70699e8a21ac6e31aa14457d74837c46acf7b1`;
acceptance record `factory/runs/b16_exitdiag_20260905/xau_h4/repair01_acceptance.json`.

Repair01 replaced the mismatched control source with the already-accepted H03 parsed parent
object. All three mechanically eligible windows (SingleTP-off MAIN, SingleTP-off BWD, BasketTP-off
MAIN) satisfied the preregistered `>=3 of 4` concentration rule on all four dimensions (max hold,
active share, top-1 positive-cycle GP share, zero-close years); every eligible window scored higher
than its control on all four. `BasketTP-off / BWD` remains mechanically ineligible hard-cage
evidence at 25.00% DD and is excluded from the verdict exactly as preregistered. HOLDOUT remained
`UNSPENT`; optimization remained `NONE`; no MT5 rerun occurred.

## Interpretation

Classification: `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED`. The result replicates
the previously observed USDJPY/H1 exit-off mechanism pattern on a second Symbol×TF context:
disabling Single TP or Basket TP can produce attractive aggregate PF/net in some windows while
collapsing realized participation into a few extremely long-lived, highly concentrated cycles (max
holds up to ~1,029 days, zero-close years present). This shows aggregate PF/net alone is not
sufficient evidence for removing either exit on XAUUSD/H4 — it does not show the current exits are
optimal, and it does not show an exit redesign is impossible.

## Decision support

Decision: `RETAIN_CURRENT_EXITS_FROZEN` (see canonical result owner for the full statement).

- Do not open an exit-parameter search/removal from XAUUSD/H4 headline PF/net alone.
- Do not treat the BasketTP-off MAIN `UNDEFINED_NO_GROSS_LOSS` PF (MT5 displays 0.00) as a clean
  result without checking cycle count and concentration.
- Do not rerun Repair01 or open Repair02 — Repair01 is the single bounded research repair for this
  diagnostic and no automatic follow-up is authorized.
- Reopen only with a separately preregistered XAUUSD/H4 exit-redesign hypothesis that explicitly
  includes participation/holding/concentration guardrails in addition to aggregate PF/net/DD.

## Negative evidence preserved

Full detail lives in `knowledge/90_negative_knowledge/b16-b15-boss19-closed-paths.md` under
"B16 XAUUSD/H4 exit-off paths — Repair01 replicates the exit-concentration mechanism". This
milestone does not duplicate that entry's "do not repeat" list; it is a discoverability pointer
into it plus the Second Brain's own evidence/interpretation/decision separation.

## Current unknowns

Whether the same exit-off concentration mechanism replicates on a third Symbol×TF context is
unknown. A bounded, zero-new-MT5 preregistration for exactly this question now exists —
`docs/research/B16_GBP_SELL_H4_EXITCONC_PREREG_20260905.md` (`HYP-B16-GBP-H4-EXITCONC-01`) — but it
is **preregistered only, not executed**; no result exists yet. No exit-redesign hypothesis exists yet
for XAUUSD/H4.

## Milestone scrutiny

This work was necessary because the accepted Repair01 evidence was reachable only through the
negative-knowledge file's generic bullet, not a direct index entry naming the finding. No accepted
experiment was replayed, no source corpus was reread, and no new parameter hypothesis was created.
