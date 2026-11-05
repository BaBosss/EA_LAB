# First recipe end-to-end — B15-H01 ST03, GBPUSD H1, declared defaults (2026-11-05)

**Purpose:** a pipeline test of the optimize standard (`EA_TEMPLATE_OPTIMIZE_STANDARD.md` rule table v2,
`EA_OPTIMIZE_RECIPE_RECEIPT_SPEC.md`). It proves that a frozen recipe, real MT5 runs and `scripts/recipe_check.py`
work together and leave a receipt chain.

**This is not a verdict and selects nothing.** Under the VERDICT GATE, these numbers are defaults evidence for one
cell, which can only close that cell.

## Chain

- **Recipe:** `factory/recipes/B15-H01-r1.json`, frozen 2026-11-05. It pins hypotheses, bindings and the GBPUSD lane-1
  profile by sha256.
- **SAFETY/SIZING inputs** are frozen in `fixed_inputs` at the declared defaults.
- **Runs:** `scripts/mt5_run.ps1` on lane 1 (`D:\Meta 5`, ThinkMarkets-Live, Build 6230), with the full declared-defaults
  set `ea_template/sets/regression/Boss_15_ST03_defaults.set`.
  - Identity PASS on every run: build receipt `br-079f971c…`, ex5 sha256 `e64f31f8…`.
  - The binary was compiled from `4d9ea6f9`. `ea_template/` is byte-identical at this lane's base, so the stale-check's
    mtime warning comes from the fresh checkout, not from different source.
- **Receipts:** `factory/acceptance_receipts.jsonl`, written by `recipe_check.py accept --write`.

| Stage / window | Model | Result | PF | Trades | Eq DD % | Confidence | F5 score |
|---|---|---|---|---|---|---|---|
| SMOKE / MAIN | 1 | ACCEPT | 0.80 | 824 | 3.65 | A | −0.98 |
| BOTH_WINDOW / MAIN | 1 | ACCEPT | 0.80 | 824 | 3.65 | A | −0.98 |
| BOTH_WINDOW / BWD | 1 | ACCEPT | 1.00 | 786 | 1.35 | A | 0.01 |
| MODEL4 / MAIN | 4 | ACCEPT | 0.76 | 828 | 4.51 | A | −0.98 |
| MODEL4 / BWD | 4 | ACCEPT | 0.99 | 784 | 1.38 | A | −0.16 |

`ACCEPT` means only that the run followed the recipe. It says nothing about quality.

## What the test found

1. **The chain works end to end.** Recipe validation, run identity, report parsing, model detection from
   history quality, window and symbol matching, the full-set and binding check, and append-only receipts all worked.
2. **Gap: stage gates were missing.** Nothing stopped the chain after SMOKE PF 0.80, although R11 says full optimize
   only where smoke PF ≥ 1.0.
   - Fixed in `6388f93a`: V10 requires a SMOKE `pf_min ≥ 1.0` gate, and A2g blocks every later stage until the gate passes.
   - This recipe was frozen before V10. **The current checker refuses it** (no SMOKE gate), and with a gate the chain
     would stop at SMOKE.
   - It is kept unchanged because the five receipts pin its exact bytes.
3. **Result, consistent with R15 trial 2:** ST03 on defaults has no edge in either window (MAIN PF 0.76–0.80,
   BWD 0.99–1.00). Model 4 is slightly below Model 1 in both windows.

## Next

- Optimize stages (COARSE/FINE) in the checker: preflight receipt plus optimizer-XML pass count.
- TUNABLE bindings for the non-escalation Boss builds. Today only B14 and B16 have any, so no other recipe can sweep.
- The in-EA basket log (R18), so escalation recipes can be accepted at all.
