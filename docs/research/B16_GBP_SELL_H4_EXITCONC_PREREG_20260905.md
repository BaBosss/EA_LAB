# B16 GBPUSD/H4 SELL Exit-Concentration — Preregistration (third-context replication)

Status: `PREREGISTERED / RESEARCH_ONLY / ZERO_NEW_MT5 / NOT_EXECUTED`
Hypothesis: `HYP-B16-GBP-H4-EXITCONC-01`
Author lane: `ct-ms-system02-r2-20260905` (scoped lane registry authorship only; no runtime/optimization/HOLDOUT/Candidate authority).

## Candidate set considered (small, source-traceable) and selection

Three candidates were generated from canonical Second Brain / negative-knowledge evidence already on
disk; exactly one is selected below.

1. **Selected — HYP-B16-GBP-H4-EXITCONC-01.** Apply the already-frozen, twice-replicated exit-off
   concentration diagnostic (USDJPY/H1: `docs/research/B16_USDJPY_H1_EXIT_CONCENTRATION_DIAGNOSTIC.md`;
   XAUUSD/H4 Repair01: `docs/research/B16_XAU_H4_EXIT_CONCENTRATION_REPAIR01_RESULTS_20260905.md`) to a
   third accepted parent, GBPUSD/H4 SELL `14/70`. Selected because the raw child evidence already
   exists on disk (zero new MT5 run needed at the gate stage), the methodology is frozen and requires
   no new metric, the falsifier is explicit, and the `knowledge/10_synthesis/SECOND_BRAIN_MILESTONE_B16_XAU_H4_REPAIR01_20260905.md`
   milestone's own "Current unknowns" section names exactly this open question ("whether the same
   exit-off concentration mechanism replicates on a third Symbol×TF context").
2. **Considered, not selected — stacking GBP/H4 depth-search evidence with exit-off evidence.**
   `docs/research/B16_GBP_SELL_H4_DEPTH3_01_RESULTS.md` and the exit-off child evidence are both
   real, but combining two independently-closed mechanisms (depth3 context-specific finding + exit
   removal) into one question is exactly what the negative-knowledge file's cross-path rule warns
   against ("re-open a closed path only when new evidence creates a **distinct** prospective causal
   question... not another search loop"). Rejected as not a distinct, single-logical-change question.
3. **Considered, not selected — Boss19 P4 deterministic prejoin/regime-join.** Named as the next
   admissible continuation in `knowledge/90_negative_knowledge/b16-b15-boss19-closed-paths.md`, but it
   is explicitly flagged there as "separately authorized" and is architectural in scope (a classifier/
   regime-join system), not a small bounded one-logical-change preregistration. Left to its own lane.

## Trigger

Two independent Symbol×TF contexts (USDJPY/H1, XAUUSD/H4) have now shown the same pattern: disabling
Single TP or Basket TP can produce attractive aggregate PF/net while collapsing realized participation
into a few extremely long-lived, highly concentrated cycles. Whether this is a general trait of the
B16 exit mechanics or specific to those two contexts is an open, explicitly-named unknown. GBPUSD/H4
SELL `14/70` is a third accepted parent with existing exit-off child evidence already captured in the
same characterization batch that produced the other two contexts' raw data
(`factory/runs/b16_characterization_20260830/`), so this question can be asked without a new MT5 run.

## Known risk carried forward from the XAUUSD/H4 attempt

The exact same batch (`b16_characterization_20260830`) is where the XAUUSD/H4 V1 attempt discovered
`BLOCKED_CONTROL_MISMATCH`: a `DEEP_SPACING_EQUAL` proxy that did not reproduce the accepted parent
headline. `factory/runs/b16_characterization_20260830/aggregate/parent_contexts.json` and any
`DEEP_SPACING_EQUAL` evidence directory carry the same suspicion for GBP/H4 and must not be trusted as
control without the same reproduction check that Repair01 used for XAU.

## Frozen control-derivation gate (must pass before any child dimension is computed)

The accepted parent `14/70` headline is already canonical in
`docs/research/B16_GBP_SELL_H4_OPT01_RESULTS.md`:

- MAIN: net `+283.20`, PF `7.97`, trades `80`, native EqDD `1.72%`.
- BWD: net `+268.97`, PF `14.36`, trades `76`, native EqDD `1.27%`.

Before any child (exit-off) dimension is computed, the candidate parent control source (whatever
object is proposed — `parent_contexts.json`, a re-parsed `report.htm.gz`, or otherwise) must
reproduce these four exact MAIN values and these four exact BWD values. If it does not reproduce them
exactly, stop `BLOCKED_CONTROL_MISMATCH` — exactly as the XAUUSD/H4 V1 attempt did — and do not
substitute an alternate proxy, threshold, or parent source without a separately authorized repair
(mirroring the Repair01 precedent; no automatic Repair-style follow-up is authorized by this
preregistration).

## Frozen methodology — unchanged from the XAU Repair01 precedent

No new metric is introduced. For MAIN and BWD separately, and for each eligible child window, derive
the same four dimensions from the validated control and from each child using the already-frozen
formulas (`docs/research/B16_XAU_H4_EXIT_CONCENTRATION_REPAIR01_PREREG_20260905.md`, "Frozen Repair01
control derivation"):

1. `max_cycle_holding_duration` (days);
2. `active_time_share` (full window);
3. `top1_positive_cycle_gp_share`;
4. `zero_closed_year_count`.

## Child evidence and eligibility

Raw MT5 reports already exist for all four combinations (zero new MT5 run):

- `factory/runs/b16_characterization_20260830/evidence/SINGLETP_OFF/GBP_H4/MAIN/report.htm.gz`
- `factory/runs/b16_characterization_20260830/evidence/SINGLETP_OFF/GBP_H4/BWD/report.htm.gz`
- `factory/runs/b16_characterization_20260830/evidence/BASKETTP_OFF/GBP_H4/MAIN/report.htm.gz`
- `factory/runs/b16_characterization_20260830/evidence/BASKETTP_OFF/GBP_H4/BWD/report.htm.gz`

Each candidate window remains subject to the same hard-cage mechanical-eligibility rule already
applied in the USDJPY/H1 and XAUUSD/H4 diagnostics (e.g. the XAUUSD/H4 `BASKETTP_OFF/BWD` window was
excluded at 25.00% DD): any window that breaches that same hard cap is mechanically ineligible and is
excluded from the verdict exactly as before — it is never rescued or re-thresholded to fit.

## Verdict rule

A window is `CONCENTRATION_SHIFT` only when at least 3 of the 4 dimensions are higher than the exact
same-window validated parent control (unchanged rule from both prior contexts). Let `E` = number of
mechanically eligible windows (0-4) and `C` = number of those classified `CONCENTRATION_SHIFT`:

- `C == E` and `E > 0` -> `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED` (third-context
  replication; strengthens the prior that this is a general B16 exit-mechanics trait, not a
  per-symbol artifact — still grants no exit-redesign, HOLDOUT, or deployment authority).
- `0 < C < E` -> `MIXED_CONCENTRATION_EVIDENCE`.
- `C == 0` and `E > 0` -> `HYPOTHESIS_FALSIFIED / NO_CONCENTRATION_REPLICATION` (the falsifier: the
  mechanism does not generalize to GBPUSD/H4 and remains a two-context, not a family-wide, finding).
- `E == 0` -> `BLOCKED_NO_ELIGIBLE_WINDOW` (report and stop; do not relax the hard-cage rule to
  manufacture an eligible window).

## Stop rule / loop breaker

This is a single bounded read-only diagnostic attempt, identical in shape to the XAU Repair01
precedent. If the control-derivation gate fails, or any required report artifact is missing/corrupt,
or the frozen formulas cannot be computed from the available data, stop at the corresponding `BLOCKED_*`
state. No automatic second attempt, alternate proxy, or new MT5 run is authorized by this
preregistration; a follow-up requires its own separately authorized, separately reviewed repair
contract, exactly as Repair01 was for XAUUSD/H4.

## Direct consumer

- Cross-symbol exit-concentration negative-knowledge deduplication: whichever result lands becomes a
  new dated entry in `knowledge/90_negative_knowledge/b16-b15-boss19-closed-paths.md`, preventing a
  future worker from re-asking "is this real on a third symbol" from scratch.
- If `EXIT_CONCENTRATION_REPLICATED` a third time, it raises (but does not by itself authorize) the
  evidentiary bar any future B16 exit-redesign preregistration would need to clear.
- No Factory, HOLDOUT, optimization, Candidate/Grade/KINT, DEMO/LIVE, deployment, trading, or
  risk/default authority follows from any outcome of this preregistration.

## Owner hard-stop

This preregistration is written but **not executed** in this author lane. Per lane scope
(`ct-ms-system02-r2-20260905`: lane registry authorship only, no runtime activation), implementing the
parser/comparison and producing a results document is left to a separately authorized lane/commit —
even though every input artifact already exists and no new MT5 run is required, actually running the
comparison and writing an accepted results doc is execution, not registration, and is out of scope
here. The independent reviewer should verify this preregistration was not silently executed before
review.
