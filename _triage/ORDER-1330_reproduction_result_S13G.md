# ORDER-1330 — the reproduction, and the mechanism it named

> Lane `S-2026-08-04-S13G`, 2026-08-04. Predictions were committed in
> `_triage/ORDER-1330_reproduction_prereg_S13G.md` (`6953bfea`) **before the runner started**.
> Run log `_triage/ORDER-1330_rerun_S13G.log` · records
> `factory/runs/pilot/pilot_cells_MAIN_lot0p03_20260804_11{0950,1101,1301,1509}.jsonl`.
> 🚫 No verdict is issued here and no cell is re-judged. This measures the **pipeline**.

## Result in one line

**All 8 re-run cells differ from their 2026-08-03 records, and in the 5 cells whose deal lists are
otherwise identical the ENTIRE difference is the `Swap` column.** The tester charges swap from the
broker's **current** symbol specification, which is not in the `.set`, not in
`effective_config_hash`, not in `data_fingerprint`, not in the price history, and not in any record.

## The eight cells (MAIN · Model 1 · lot 0.03 · lane `D:\Meta 5`, identical to the 08-03 invocation)

| cell (baseline arm) | 08-03 PF · net | today PF · net | deals | what moved in the deal list |
|---|---|---|---|---|
| `H01/BTCUSD/H4` | 1.18 · 332.50 | 1.18 · 324.75 | 111 = 111 | *(08-03 artefact already lost; see P1)* |
| `H02/BTCUSD/H4` | 1.16 · 299.37 | 1.17 · 314.65 | 117 = 117 | **swap only, +15.28** — profit column identical to the cent |
| `H01/EURUSD/H4` | **0.62** · −184.78 | **1.06** · +20.00 | 31 = 31 | **swap only, +204.78** — profit column identical to the cent |
| `H01/USDJPY/H4` | **12.46** · 1061.86 | **111.77** · 1225.17 | 95 = 95 | **swap only, +163.31** — gross loss −92.69 → −11.06 |
| `H02/USDJPY/H4` | **0.89** · −141.57 | **1.10** · +114.96 | 97 = 97 | swap +268.80 **and** profit −12.27 (time + price columns also moved) |
| `H01/XAUUSD/H4` | 0.25 · −1169.40 | 0.25 · −1163.66 | 23 = 23 | swap −2.99 and profit +8.73 |
| `H02/XAUUSD/H4` | 0.41 · −1007.32 | 0.44 · −901.06 | 33 = 33 | swap +154.83 and profit −48.57 |
| `H02/EURUSD/H4` | 0.17 · −1624.89 | 0.90 · −72.36 | **33 → 45** | deal count changed — behaviour diverged, not just cost |

**Three cells cross a PF bar on this alone**: `H01/EURUSD/H4` 0.62 → **1.06**, `H02/USDJPY/H4`
0.89 → **1.10**, and `H01/USDJPY/H4` moves by an order of magnitude, 12.46 → **111.77**, because its
gross loss is almost entirely financing (−92.69 → −11.06). A cell that failed a bar on 08-03 passes
it today with no configuration change of any kind.

## Against the pre-registered predictions

- **P1 — replication. CONFIRMED, and at deal level.** `H01/BTCUSD/H4` returned `324.75 / −1850.78 /
  15.22` again — matching 08-04, not 08-03 — and its 111 deals are **identical in every column** to
  the 08-04 report. So *"across sessions not reproducible"* was too strong: the runs reproduce
  exactly while the external state holds. The state changed **once** between 08-03 12:31 and 08-04
  08:19 and has held since.
- **P2 — second cell. CONFIRMED.** `H02/BTCUSD/H4` drifted, and so did the other six. The finding
  generalises well past one cell.
- **P3 — symbol scope. CONFIRMED, and wider than predicted.** Not BTC-specific and nothing to do
  with crypto: EURUSD, USDJPY and XAUUSD all moved.
- **P4 — trade-count invariance. CONFIRMED in 5 of 8, refuted in 2.** Where the deal count held, the
  cause is purely a cost field. `H02/EURUSD/H4` (33 → 45 deals) and the `H01/XAUUSD/H4` flat-lot arm
  (45 → 103) genuinely changed behaviour — both on symbols whose price history the live terminal
  rewrote (`XAUUSD` cache 08-03 16:36, `EURUSD 2026.hcc` 08-03 20:32). **Two mechanisms, not one.**

## The elimination that names the mechanism

The pre-registration listed every DataDir file written between the two runs. The re-run splits them:

- `ticks\BTCUSD\202607.tkc` (08-04 **08:39**), `ticks\BTCUSD\202608.tkc` and `history\BTCUSD\2026.hcc`
  (**08:47**) were written **after** the 08:19/08:20 runs — and today's 11:09 run, which is after all
  of them, reproduced 08:19 **exactly**. ⇒ **current-year tick and history updates are eliminated.**
- What remains before 08:19 is `symbols-146237.dat` at **08:13:59** — the symbol-specification
  store, which is where swap rates live. The deal-level diff points at the same field independently.

`D:\Meta 5\Bases` — the directory design §6.4's `Bases\` marker names — has **not had one file
modified since 2026-08-01**. A fingerprint that hashed it would have told these runs apart on
nothing. The mutable state is in the **DataDir**, and a live terminal rewrites it.

## What this costs, stated plainly

1. **Every money figure in the pilot corpus is a snapshot of a cost that moves.** Any comparison
   between two runs made on different days — including MAIN measured one day against BWD measured
   the next, which is what `ORDER-1254` did — is contaminated by an input no record carries.
2. **The `data_fingerprint` question in `ORDER-1330` item 1 is now specific**: the missing component
   is not "a `Bases\` state marker", it is **the symbol specification actually in force at run time**
   (swap long/short and mode at minimum). 🚫 Still not hashed in from this lane — item 1 says that
   decision carries a migration for every existing record.
3. Until it is, item 2 stands and is bigger than the ±2–3 % first measured: **on these eight cells
   the session-to-session move ranges from 0.5 % to a PF crossing 1.0.**

## The second finding: the crypto financing is charged twice — `ORDER-1350`

`scripts/swap_adjust_crypto.py` exists because a 2026-07-26 probe measured `BTCUSD
SYMBOL_SWAP_MODE_INTEREST_CURRENT -> swap is NOT charged`. **That premise does not hold on these
runs.** The BTCUSD reports carry a non-zero tester `Swap` column, and the post-hoc deduction is
applied on top of it:

| verification run behind the handoff's headline | tester already charged | deducted again post-hoc |
|---|---|---|
| `H02/BTCUSD/H4` BWD **M4** | **−218.96** | −379.08 |
| `H02/BTCUSD/H4` MAIN **M4** | **−762.57** | −1304.25 |
| `H01/BTCUSD/H4` BWD **M4** | **−134.80** | −239.94 |
| `H01/BTCUSD/H4` MAIN **M4** | **−356.91** | −620.97 |

The implied annual rate on the tester's own charges, taken per position over `H01/BTCUSD/H4` MAIN,
has a **mean of 14.3 %** against the broker's stated `SYMBOL_SWAP_LONG` of **14.67 %** (median 10.6 %;
the spread is my FIFO pairing across a grid basket and weekend handling, not the tester's). It is
charging the interest swap, not a token points swap.

**Direction of the error: the financing-adjusted numbers are too PESSIMISTIC.** `B14-H02-r1`'s
financing-adjusted BWD margin of **1.20** — the number the owner question rests on — is understated,
not overstated. 🚫 It is **not** recomputed here: the right fix is to re-probe the symbol's current
swap mode (`ea_projects/(TST)_SymbolSwapProbe/`) and then decide whether the tool applies, because
"the probe said otherwise nine days ago" is exactly how this got written in the first place.

## What it does to `ORDER-1302`

`ORDER-1302` asks whether the 14 `BOUNDARY` cells should have their grids widened and re-run.
Fourteen of those sixteen surfaces are Model-1 MAIN searches of the same kind measured here. **A
boundary found on a surface that is not reproducible across days is not a boundary that can be
chased by widening a range.** That is an argument for settling the grid-vs-`safe_range` question
first — which is what the order already says its first deliverable is — and against spending the
3–12 hours of tester time until the money in those surfaces is a stable quantity.
