# Recipe + Acceptance Receipt — spec draft v0 (2026-11-04)

- **Status:** draft for review. Implements rule table v1 R12–R16 and R21 (`TEMPLATE_OPTIMIZE_STANDARD_DESIGN.md` §9).
  Committed with `EA_TEMPLATE_OPTIMIZE_STANDARD.md` (2026-11-04).
- **Builds on (origin `b079587e`, local ref):**
  - `factory/hypotheses.jsonl` (hypothesis_revision)
  - `factory/parameter_bindings.jsonl` (1,648 rows; role LOCKED / TUNABLE / SAFETY per hypothesis revision)
  - `OwnerRef` pins: `commit_oid` + `blob_oid` + `raw_sha256`
  - `scripts/optimize_guard.ps1` (preflight → `factory/optimize_decisions.jsonl`)
  - `_triage/factory_os/candidate.py` C11 (Model-4 gate)
- **Principle:** no new identity system. A recipe pins existing rows by hash, and a receipt pins a recipe by hash.

## 1. Two new files, two new entities

| File | Entity | Written by | Mutable? |
|---|---|---|---|
| `factory/recipes/<hypothesis_revision>.json` | `OptimizeRecipe` | author, before any qualifying run (R13) | **No.** A change is a new revision `…-r2` with a reason. |
| `factory/acceptance_receipts.jsonl` | `AcceptanceReceipt` | the checker only | append-only |

Class templates (`trend`, `reversion`, `breakout`, `escalation`) are **defaults for drafting a recipe**, not a separate file
the checker reads. The checker reads only the frozen per-EA recipe. This follows R14/R15: plateau and score are frozen per EA.

## 2. `OptimizeRecipe` (one JSON object)

```json
{
  "entity": "OptimizeRecipe",
  "recipe_id": "B11-H02-r1",
  "hypothesis_ref": {"entity": "OwnerRef", "path": "factory/hypotheses.jsonl", "commit_oid": "…", "raw_sha256": "…", "key": "B11-H02-r1"},
  "class": "escalation",
  "class_derivation": "modules: GridStack + LotProg53 ⇒ escalation (R6)",
  "ea": {"wrapper": "ea_template/Boss_11-00_GridTrend.mq5", "source_sha256": "…", "magic": 0},
  "symbols": ["XAUUSD"],
  "symbol_preset_refs": [{"symbol": "XAUUSD", "path": "factory/instrument_profiles.jsonl", "raw_sha256": "…"}],
  "timeframes": ["M15", "M30", "H1"],
  "windows": {
    "MAIN": ["2023.01.01", "2025.12.31"],
    "BWD": ["2020.01.01", "2022.12.31"],
    "HOLDOUT": ["2026.01.01", "2026.06.30"],
    "RECENT": "descriptive_after_lock"
  },
  "stages": [
    {"stage": "SMOKE", "model": 1, "window": "MAIN", "params": "defaults", "gate": {"pf_min": 1.0}},
    {"stage": "COARSE", "model": 1, "window": "MAIN", "grid": "full",
     "sweep": [{"parameter": "_14_DistAtrMult", "from": 1.0, "to": 5.0, "step": 0.5}]},
    {"stage": "FINE", "model": 1, "window": "MAIN", "grid": "full", "around": "plateau_center", "step_divisor": 5},
    {"stage": "FREEZE"},
    {"stage": "BOTH_WINDOW", "model": 1, "windows": ["MAIN", "BWD"]},
    {"stage": "MODEL4", "model": 4, "windows": ["MAIN", "BWD"], "gate": "C11"},
    {"stage": "HOLDOUT", "model": 4, "window": "HOLDOUT"}
  ],
  "bindings_ref": {"path": "factory/parameter_bindings.jsonl", "raw_sha256": "…", "hypothesis_revision": "B11-H02-r1"},
  "score": {"formula_id": "SCORE_ESC_v1", "formula_sha256": "…", "dd_cap_equity_pct": 12.0,
            "escalation": {"worst_basket_depth_weight": null, "worst_basket_hold_weight": null, "mtm_at_end": "bid_ask_plus_costs"}},
  "plateau_rule": {"id": "…", "text": "…", "decided_with_owner": "2026-…"},
  "tie_breaks": ["higher BWD PF", "lower equity DD", "fewer parameters off default"],
  "extra_round": null,
  "frozen_utc": "2026-…Z",
  "frozen_by": "author id",
  "development_runs": ["paths of trial runs — labelled DEVELOPMENT_ONLY, never qualifying"]
}
```

**Recipe validity (checker refuses the recipe itself if any fails):**

| ID | Rule |
|---|---|
| V1 | Every swept parameter has a binding in `bindings_ref` with role `TUNABLE`. A `SAFETY` or `LOCKED` parameter in `sweep` = refuse (same logic as `optimize_guard` check 4). |
| V2 | `score.formula_sha256`, `plateau_rule`, `tie_breaks` and the sweep ranges are non-null **before** `frozen_utc`. A `null` anywhere in these = the recipe is not frozen (R13). |
| V3 | `windows.MAIN ∩ windows.HOLDOUT = ∅` (VERDICT GATE iron rule). |
| V4 | `class` equals the class derived from modules (R6). Today only escalation is derivable (any grid / lot-progression module ⇒ escalation, either direction refused). trend / reversion / breakout cannot yet be told apart from module tokens, so a non-escalation recipe must state `class_derivation`; that choice is the author's and is reviewed, not machine-checked. |
| V5 | `extra_round` is either `null` or `{reason, lever, approved_by, approved_utc}` with `approved_by ≠ frozen_by` (R20). At most one. |
| V6 | Each `symbol_preset_ref` names a `lane` and resolves to exactly one `BROKER_LANE` row of `factory/instrument_profiles.jsonl` for that symbol and lane, whose `content_hash` equals the sha256 of its canonical `values`, and whose `values` pin `spec_digits`, `spec_point`, `spec_tick_value` and `spec_contract_size` as finite numbers (R8). Rows are measured by `tools/mt5/SymbolSpecDump.mq5`. |
| V7 | `stages` contains `MODEL4` before any stage that would issue CANDIDATE (R16). |
| V8 | `score.dd_cap_equity_pct` is a finite number in (0, 12.0] (R17). A recipe may tighten the cap, never loosen it; NaN, ∞ or text refuse. |
| V9 | Every SAFETY or SIZING binding without a `locked_value` has an entry in the recipe's `fixed_inputs` (R13 freeze). A4 checks the run's set against it. No canonical SAFETY binding carries a value today, so the recipe is where those values are frozen. |

## 3. `AcceptanceReceipt` (one JSONL row per accepted stage result)

```json
{
  "entity": "AcceptanceReceipt",
  "receipt_id": "sha256 of the canonical row without this field",
  "recipe_id": "B11-H02-r1",
  "recipe_sha256": "…",
  "stage": "MODEL4",
  "symbol": "XAUUSD", "timeframe": "H1", "window": "BWD", "model": 4,
  "report": {"path": "…", "raw_sha256": "…"},
  "set": {"path": "…", "raw_sha256": "…"},
  "binary": {"path": "…ex5", "raw_sha256": "…", "mtime_utc": "…", "source_sha256": "…"},
  "tester": {"build": 6230, "leverage": "1:500", "deposit": 10000, "currency": "USD"},
  "metrics": {"net": 0, "pf": 0, "trades": 0, "equity_dd_pct": 0,
              "worst_basket_depth": null, "worst_basket_hold_s": null, "score": 0},
  "evidence_confidence": "…",
  "preflight_ref": {"path": "factory/optimize_decisions.jsonl", "submitted_utc": "…", "result": "ALLOW"},
  "result": "ACCEPT",
  "refusals": [],
  "checker_version": "…",
  "checked_utc": "…"
}
```

**Acceptance rules (any failure ⇒ `result: REFUSE`; the REFUSE row is written here **and** a refusal entry is appended to `factory/optimize_decisions.jsonl`, R21):**

| ID | Rule |
|---|---|
| A1 | `recipe_sha256` matches the frozen recipe file at check time. |
| A2 | The run's window, model, symbol and timeframe equal the recipe stage, and the stage order is respected: a receipt with `result: ACCEPT` exists for every earlier stage. A `REFUSE` receipt never satisfies a prerequisite. |
| A3 | **Optimize stages (COARSE/FINE):** `preflight_ref` is an `ALLOW` row of the same `hypothesis_revision` and the same `.ini`, made in **enforcing** mode. A `-WarnOnly` run or a missing row means no acceptance. Single-test stages have no preflight (`mt5_run`/`run_backtest` do not call `optimize_guard`); A4 is their parameter guarantee. |
| A4 | The report, set and binary hashes are read from the files, not copied from another record. The set swept only `TUNABLE` parameters (and only in an optimize stage), and every non-`TUNABLE` bound input (LOCKED, SAFETY, …) equals its binding's `locked_value`. The recipe pins `bindings_ref`, `hypothesis_ref` and each symbol preset by `raw_sha256`; a store whose bytes changed after freezing refuses. |
| A5 | The tester leverage is asserted as `1:N` from the report (memory: tester-cache nondeterminism). A full `.set` was used. |
| A6 | Equity DD ≤ `score.dd_cap_equity_pct` (R17). |
| A7 | Escalation class only: `worst_basket_*` is non-null and sourced from the in-EA equity/basket log or price replay (R18). If it is null, refuse; never estimate it from deals. |
| A8 | `HOLDOUT` stage: only one receipt per recipe may exist. A second run is refused as "holdout spent" (VERDICT GATE). |
| A9 | An input the checker cannot read or resolve means refuse, never skip (memory: unreadable-input-must-refuse-not-skip). |

## 4. What this does not do

- It does not pick parameters. Selection stays with the author and the plateau rule; the checker only verifies that the
  selection followed the frozen recipe.
- It does not replace `optimize_guard.ps1`. The preflight stays. The receipt cites it (A3).
- It issues no verdict word. CANDIDATE remains `candidate.py`'s decision. A complete receipt chain is an input to it.

## 5. Open before build

1. Score formula and escalation weights (R15): `null` until the trial runs.
2. Where the in-EA equity/basket log lives and its format (R18). This needs a core edit, so `tpl_regression` and review apply.
3. Whether `candidate.py` C11 reads receipts directly, or keeps its own frozen-M4 check and receipts are additional.
4. ~~Evidence-confidence levels (R19).~~ Accepted 2026-11-04 (A ≥100 · B 50–99 · C 20–49 · D <20, worst window). The checker writes `evidence_confidence` from the receipt's `metrics.trades`.
