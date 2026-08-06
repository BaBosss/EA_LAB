# ORDER-236 STAGE 3 — pre-registration

> Written **2026-08-06, before any STAGE 3 run existed**, by lane `S-2026-08-06-CLEARALL`.
> Committed before the runner is dispatched; that ordering is the point, and it is verifiable from
> the commit graph. Nothing in this file may be edited after the first STAGE 3 report lands —
> corrections go in a block below it, dated.

## Why STAGE 3 exists

`STAGE 1` classified **four** axes LIVE. `STAGE 2` crossed the top two (`StackConfirm`,
`_9_PA_MinBodyRatio`) under Model 4 and no cell passed. **`_50_RegimeMode` and `_50_AllowTrendDown`
have never been run under Model 4 on this host** — each was measured once under Model 1, which this
row's own bar says is not evidence. `DEAD-OPTIMIZED` cannot be earned until they are, and the
VERDICT GATE's last-optimize clause says so explicitly.

## 🔴 The finding that changes the shape of this stage, read out of the code rather than the comments

Both remaining axes are **conditional**, and one of them is conditional on a lever this order is
itself testing. Read from the functions that run, not from the input comments:

| file:line | what it establishes |
|---|---|
| `ea_template/core/Regime.mqh:31` | `Regime_Enabled()` ⇔ `_50_RegimeMode == 1 \|\| == 2`. **At mode 0 the entire regime module is off.** |
| `ea_template/core/Regime.mqh:100-105` | `_50_AllowTrendDown` is read **only** inside the `_50_RegimeMode == 1` branch. |
| `ea_template/core/Regime.mqh:107-108` | the `mode == 2` branch returns on `state == REGIME_RANGE` alone and **never reads `_50_AllowTrendDown`**. |
| `ea_template/core/Stack.mqh:280-285` | `_9_RegimeGateAdds` does exactly one thing: call `Regime_AllowsEntryDirection`. |
| `ea_template/core/Regime.mqh:114` | that function's first line is `if(!Regime_Enabled()) return true;` |

⇒ **`_9_RegimeGateAdds` is provably inert at `_50_RegimeMode = 0`.** It has nothing to gate, because
the module it defers to is switched off. This is a claim about two specific call sites, and it is
falsifiable by one pair of runs — which is why one pair below exists to try.

⇒ **`_50_AllowTrendDown` is live at `_50_RegimeMode = 1` and provably inert at 0 and 2.**

**Why this matters for the bar and not only for the cell count:** turning `_50_RegimeMode` on with
`_9_RegimeGateAdds` left `false` would gate only the flat seed and never the grid adds, so STAGE 1
probed both regime axes at `_9_RegimeGateAdds = true`. Carrying that into STAGE 3 means every regime
cell moves **two** inputs away from the `B14_AB_off` CTRL, and a naive delta would confound them. The
cell list below resolves that by measurement rather than by argument: `C1` holds
`_9_RegimeGateAdds = true` at `_50_RegimeMode = 0` and is predicted to reproduce the CTRL exactly. If
it does, the confound does not exist and every regime cell's delta is attributable to the regime axes
alone. **If it does not, STAGE 3's comparison is invalid and must stop** — that is the real job of
`C1`, and it is stated before the run precisely so it cannot be reinterpreted afterwards.

## Cells — 6 configurations × 2 windows = 12 Model-4 runs

Host **EURJPY H1** · lane **`D:\Meta 5b`** · **Model 4 real ticks, mandatory** · MAIN
`2023.01.01-2025.12.31` · BWD `2020.01.01-2022.12.31` · all cells derived from the same
`B14_AB_off` lineage as every earlier stage on this row.

| # | `_50_RegimeMode` | `_50_AllowTrendDown` | `_9_RegimeGateAdds` | role |
|---|---|---|---|---|
| **C0** | 0 | true | **false** | **CTRL re-run in this lane** — the delta bar's only legitimate reference |
| **C1** | 0 | true | **true** | 🔬 **FALSIFIER** — predicted identical to `C0` to the cent |
| **C2** | 1 | true | true | regime filter, downtrend permitted |
| **C3** | 1 | **false** | true | regime filter, downtrend blocked (this is the config cell `A` used) |
| **C4** | 2 | true | true | regime as direction |
| **C5** | 2 | **false** | true | 🔬 **FALSIFIER** — predicted identical to `C4` to the cent |

## 🔬 Predictions, committed before the runs

1. **`C1` ≡ `C0`** on PF, trade count, drawdown — every digit, both windows.
2. **`C5` ≡ `C4`** on PF, trade count, drawdown — every digit, both windows.
3. ⚠️ **The nets may differ, and that is NOT a failed prediction.** `ORDER-1330` is reproduced and
   named: this engine's net moves across sessions on a byte-identical configuration (measured
   0.5 % to a PF crossing 1.0, and on this exact host/`.set`: MAIN `+2344.20 → +2353.69`, BWD
   `+567.24 → +599.32`). **PF, trade count and drawdown are the comparison surface. Net is not.**
   Predictions 1 and 2 are therefore stated on those three fields and not on money.

**If prediction 1 fails, STAGE 3 stops and reports** — the delta bar has no valid reference.
**If prediction 2 fails**, `Regime.mqh:107` does not say what it appears to say, which is a code
finding worth more than this stage's result; report it and do not average the two cells.

<sub>The same falsifier shape was pre-registered in STAGE 2 and **held on every digit** — `(0,1.5)`
reproduced `(0,1.0)` and `(1,1.5)` reproduced `(1,1.0)` to the cent. It is repeated here because it
worked, not as ceremony: two of these six cells exist to be wrong, and duplicates that are *predicted*
are evidence, where duplicates that are *discovered* are how a fake plateau gets built.</sub>

## 🚦 The bar — unchanged, and not weakened by anything in this file

- **`pass`** = better than **`C0`** on **BOTH** MAIN and BWD · **`dead`** = worse on either ·
  **`กลาง`** = better on one ⇒ **lever not accepted**.
- **PLUS the `≥ 100 closed trades per window` floor** (owner, 2026-08-05, hard, retroactive). A cell
  under the floor **does not clear its bar whatever its PF**. STAGE 2's `SC1` already failed here at
  84 trades, and the regime filter cells are the most likely in this order to do the same — a filter
  that helps BWD by cutting exposure is the shape this host keeps producing.
- 🔴 **The plateau rule is WITHDRAWN for this grid, for the same reason as STAGE 2 and stated before
  the run.** `_50_RegimeMode` is an enum: `0`=off, `1`=filter, `2`=direction are **three different
  mechanisms**, not three magnitudes of one. `_50_AllowTrendDown` is boolean. Neither axis can express
  contiguity, so "≥3 contiguous points above baseline" has no meaning on either. **A `pass` here says
  *this configuration beat control on both windows* — never *a neighbourhood does*. Nobody may
  describe a STAGE 3 result as a plateau, a ridge, or robust.**

## Axes NOT swept, named as the order requires

- **`_50_AllowTrendUp`** and **`_50_AllowRange`** — left at their defaults (`true`). They were
  **never probed by STAGE 1**, so they are **UNMEASURED, not INERT**, and this stage does not license
  any statement about them. (`Regime.mqh:102,104` shows both are live at `_50_RegimeMode = 1`, so this
  is a real gap and not a formality.)
- **`StackConfirm`** and **`_9_PA_MinBodyRatio`** — held at their CTRL values (`0`, `1.0`) throughout.
  STAGE 2 measured them; crossing all four axes is not what a last-optimize owes.

## Prohibitions for the runner

🚫 Write a verdict, or the words pass / dead / good / bad / best / edge · 🚫 change the bar after
seeing a number · 🚫 report any Model 1 or Model 2 number as evidence, or compare a STAGE 3 Model-4
number to a STAGE 1 Model-1 number · 🚫 quote an earlier day's CTRL instead of running `C0` in this
lane · 🚫 add cells or values to make a plateau possible · 🚫 touch the 2026 window · 🚫 edit
`ea_template/sets/*.set` in place — copy out · 🚫 touch any `.mq5`, `ea_template/core/`,
`_vps_deploy/`, or any board / scorecard / state file · 🚫 `git commit` or `push` · 🚫 recompile.

**Any run failing twice** → report `BLOCKED(<cell> — <last error line> + the exact command)` and
continue to the next cell. Do not stall the stage on one cell.

## Pre-flight the runner must complete before cell 1

1. **Pin every input the cells vary, in every `.set`** — `_50_RegimeMode`, `_50_AllowTrendUp`,
   `_50_AllowTrendDown`, `_50_AllowRange`, `_9_RegimeGateAdds`, `StackConfirm`,
   `_9_PA_MinBodyRatio` must each appear **by name with an explicit value in all six files**, including
   where the value equals the source default. An input a `.set` omits is filled from the per-terminal
   tester cache, not from the source default (memory `mt5-tester-cache-nondeterminism`).
2. **Read the values back from the reports, not from the files** — `check_sweep_inputs.ps1` across all
   six cells: **6 reports, 6 distinct configurations expected.** ⚠️ Two pairs here are *predicted* to
   produce identical RESULTS (`C0`/`C1` and `C4`/`C5`) while having **distinct CONFIGURATIONS**. The
   checker asserts distinct configurations and must still pass on all six; identical results with
   identical configs would mean the edits did not land, which is the failure that voided 15 reports on
   2026-08-04.
3. ⚠️ **State it in the report rather than let a reader assume otherwise:** `order430`-lineage `.set`
   files carry **no surface declaration**, so inputs they do not name come from the terminal cache.
   The cell-to-cell comparison is like-for-like — same file, same lane, named lines changed — but the
   absolute numbers are **not reproducible on another machine**.

## Report format — one table, nothing else

| cell | RegimeMode | AllowTrendDown | RegimeGateAdds | MAIN PF | MAIN trades | MAIN eqDD% | MAIN net | BWD PF | BWD trades | BWD eqDD% | BWD net |

Plus one line per falsifier stating **HELD** or **FAILED** on PF / trades / drawdown, and the
`check_sweep_inputs.ps1` verdict. **eqDD, not balance DD** — `ORDER-1420`'s worker reported balance
drawdown on all six rows and understated by 0.8-1.5 points; for a grid carrying floating losses the
balance figure only moves when a basket closes.
