# ORDER-1330 — pre-registration of the second-cell reproduction

> Written 2026-08-04 by lane `S-2026-08-04-S13G` **before the runner was started**, and committed
> before it was started, so that the predictions below cannot be edited to fit what came back.
> `ORDER-1330` owed item 3: *"reproduce it on a second cell before generalising"* — memory
> `phantom-regression-from-two-single-samples`.

## What is already measured (not re-measured here)

`B14-H01-r1/BTCUSD/H4`, baseline arm, lot `0.03`, MAIN, Model 1, lane `D:\Meta 5`:

| | 2026-08-03 12:31 | 2026-08-04 08:19 and 08:20 |
|---|---|---|
| `net_profit` | 332.50 | 324.75 |
| `gross_loss` | −1838.85 | −1850.78 |
| `dd_pct` | 15.12 | 15.22 |
| `pf` · `trades` · long/short | 1.18 · 55 · 55/0 | 1.18 · 55 · 55/0 |

Same `effective_config_hash`, same `data_fingerprint`, same `.set` bytes, same `.ex5` mtime, same
`bars`/`ticks`. The two 08-04 runs are byte-identical to each other. **One cell, one pair of days.**

## The runs this lane will make

One invocation, identical to the one that produced the 08-03 records except that it is restricted
to H4:

```
powershell -NoProfile -File scripts\pilot_cells.ps1 -Symbols BTCUSD,XAUUSD,EURUSD,USDJPY -Periods H4 -FirstLot 0.03
```

MAIN · `2023.01.01..2025.12.31` · Model 1 · lane `D:\Meta 5` — every one of these is the default and
none is being changed. 8 cells × 2 arms (baseline + flat-lot) = 16 tester runs.

🚫 Nothing here is hypothesis evidence and no cell is being re-judged. These records exist to
measure the **pipeline**, and every one of them will be filed with that stated.

⚠️ The report names carry no date (`S13CELL_<rev>_<symbol>_<tf>_MAIN_lot0p03_<arm>.htm`), so this
run overwrites the 08-03 artefacts the committed 08-03 records cite, and `_mt5_auto/reports/` is
gitignored — overwriting them is irreversible. **All 336 `S13CELL_*lot0p03*` files were copied to
`_mt5_auto/reports/_preserved/20260804_S13G_prerun/` before the runner was started.** That copy is
the only surviving 08-03 artefact for seven of the eight cells; for `B14-H01-r1/BTCUSD/H4` the
preserved file is already the 08-04 vintage, because that overwrite happened this morning.

## Predictions, written before the result

- **P1 — replication.** `B14-H01-r1/BTCUSD/H4` returns `324.75 / −1850.78 / 15.22` again, i.e. it
  matches 08-04 and not 08-03. *If it returns a third value*, the drift is continuous rather than a
  single step between two states, and the "same session reproducible" finding needs restating.
- **P2 — second cell, same symbol.** `B14-H02-r1/BTCUSD/H4` differs from its 08-03 record
  (`299.37 / −1871.98 / 15.39`). This is the prediction `ORDER-1330` item 3 actually asks for; if it
  reproduces exactly, **the finding does not generalise beyond one cell and must be said so.**
- **P3 — symbol scope.** If XAUUSD / EURUSD / USDJPY H4 also drift, the mechanism is not BTC-specific
  and not about crypto financing. If only BTCUSD drifts, it is scoped to the symbol whose data the
  live terminal was updating.
- **P4 — trade-count invariance.** In the measured case the *trade count and its long/short split
  were identical* while the money moved. If the re-runs move money without moving trade counts, the
  mechanism is a **cost/specification** difference (swap, commission, contract spec), not different
  price history. If trade counts move too, it is the price series.

## The state marker §6.4 names is not in the directory the design implies — measured before running

Design §6.4 defines `data_fingerprint` as `hash(lane · symbol · tf · from · to · model · bars ·
ticks · server · Bases\ state marker)`, and `Get-PilotDataFingerprint` says the `Bases\` marker is
computed by nothing. Two directories were inspected:

| directory | newest file | changed between the 08-03 and 08-04 runs? |
|---|---|---|
| `D:\Meta 5\Bases` — the **pinned lane's own** Bases | 2026-07-21 | **no — not one file modified since 2026-08-01** |
| `…\Terminal\9CA16B83…\bases` — the **DataDir the runner passes** | 2026-08-04 08:47 | **yes**: `symbols-146237.dat` 08-04 **08:13:59** (six minutes before the 08:19 run) · `ticks\BTCUSD\202607.tkc` 08:39 · `ticks\BTCUSD\202608.tkc` + `history\BTCUSD\2026.hcc` 08:47 · `history\EURUSD\2026.hcc` 08-03 20:32 · `history\USDJPY\2026.hcc` 08-03 21:58 · `history\XAUUSD\cache\Daily.hc` 08-03 16:36 |

So a fingerprint that hashed `Bases\` **under the terminal path** — the reading the design text
invites — would have hashed an inert directory and told the two runs apart on nothing. The mutable
state is in the **DataDir**, which the live terminal keeps writing to while it is connected.
`symbols-146237.dat` is the symbol-specification store; a changed contract/swap/margin spec moves
money without moving entries, which is exactly the shape P4 tests for.

🚫 This is a candidate mechanism, not a conclusion. Nothing is being hashed in, and the design text
is not being amended from this lane — `ORDER-1330` item 1 says that decision carries a migration.
