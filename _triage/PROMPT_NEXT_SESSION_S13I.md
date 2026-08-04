# OPENING PROMPT — the money in the pilot corpus is a snapshot of a cost that moves

> Written 2026-08-04 by lane `S-2026-08-04-S13G` (block `1350-1359`).
> **Read `_triage/PROMPT_NEXT_SESSION_S13H.md` too** — it was written by a concurrent lane while this
> one ran, it owns the ORDER OF WORK (`ORDER-1256` → `ORDER-1255`, no MT5 needed), and it corrected a
> ruling this lane got wrong. Nothing here supersedes it.
> `ORDER-1330` **item 3 DONE** · `ORDER-1350` **opened** · `ORDER-1302` — this lane's ruling
> **WITHDRAWN**, see below.

---

## 🔴 The finding that changes what every other pilot number means

Eight H4 cells re-run on the **identical** invocation that produced the 2026-08-03 matrix — MAIN ·
Model 1 · lot 0.03 · same lane, same `.set`, same `effective_config_hash`, same `data_fingerprint`.
**All eight moved.** In the five whose deal lists are otherwise identical, **the entire difference is
the `Swap` column**: the profit column matches to the cent and net profit moves by exactly the swap
delta.

| cell (baseline) | 08-03 | today | what moved |
|---|---|---|---|
| `H01/EURUSD/H4` | PF **0.62** | PF **1.06** | swap +204.78, profit identical to the cent |
| `H01/USDJPY/H4` | PF **12.46** | PF **111.77** | swap +163.31, gross loss −92.69 → −11.06 |
| `H02/USDJPY/H4` | PF **0.89** | PF **1.10** | swap +268.80 |
| `H02/BTCUSD/H4` | net 299.37 | net 314.65 | swap +15.28 — exactly the net delta |

**Three cells cross or move around a PF bar with no configuration change of any kind.** The tester
charges swap from the broker's **current** symbol specification: not in any `.set`, not in the config
hash, not in the fingerprint, not in the history.

Mechanism reached by **elimination**: the BTCUSD tick and 2026 history files were rewritten *after*
the 08:19 run, and today's run — later than all of them — reproduced 08:19 **byte-identically at deal
level**, so data updates are ruled out. What remains before 08:19 is `symbols-146237.dat` at
08:13:59, where swap rates live. `D:\Meta 5\Bases`, the directory §6.4's marker names, **has not had
one file modified since 2026-08-01** — hashing it would have separated nothing.

Write-up `_triage/ORDER-1330_reproduction_result_S13G.md`; predictions committed **before** the runner
started (`6953bfea`, `_triage/ORDER-1330_reproduction_prereg_S13G.md`).

## 👤 TWO THINGS FOR THE OWNER

1. **Inherited and still unanswered — the 49-trade participation question** on `B14-H02-r1/BTCUSD/H4`
   (49 BWD trades over three years · DD 15.22 % vs a 12 % limit · 100 % LONG in all four runs).
   Not decidable from the seat; `ORDER-235` precedent.
2. **New, and it moves that question's number — `ORDER-1350`.** The tester **is** charging BTCUSD
   swap (implied mean **14.3 %/yr** against the broker's stated 14.67 %) and
   `scripts/swap_adjust_crypto.py` deducts the cost **again** on top, on the strength of a probe run
   2026-07-26. **The financing-adjusted figures are too PESSIMISTIC** — the BWD margin of **1.20**
   the participation question rests on is understated. Nothing was recomputed; the first owed step is
   a **dated** probe of the symbol's current swap mode.

## The work, in order

1. **`ORDER-1256` → `ORDER-1255`** — S13H's order of work, no MT5 lane needed. Start there.
2. **`ORDER-1350`** — probe `ea_projects/(TST)_SymbolSwapProbe/` on the pinned lane, record the swap
   mode **as of a dated run**, then decide what happens to every record carrying
   `financing_deducted.applied = true`.
3. **`ORDER-1330` items 1 and 2** — the missing fingerprint component is now specific: **the symbol
   specification in force at run time** (swap long/short + mode at minimum), not a `Bases\` marker.
   🚫 Do not quietly hash it in — it reclassifies every existing record and needs a migration.
4. **`ORDER-1302`** — read S13H, not this lane's withdrawn ruling. The live owner question is **how
   far down do we widen**, pre-registered before the sweep. Whatever the answer, the surfaces are not
   reproducible across days today, so booking the 3–12 hours is premature.
5. `ORDER-1301` · `ORDER-1300` · `1270` / `1271` / `1274` — untouched.

## 🔴 The mistake this lane made, kept because the shape repeats

It ruled that `safe_range` is a safety envelope and that a boundary at its edge is a **finding rather
than a re-run** (`69283002`), then **withdrew it in full** (`af013563`) after the concurrent lane
raised it and the source was checked here. The premise was *"the field has no stated meaning"* —
verified in `schemas.json` (no description), the design (never names the string) and
`docs/PARAM_REGISTRY.csv` (a **same-named but different** column). All three were the wrong place to
look: the values are authored in `_triage/factory_os/hypothesis_b14.py:151`, which says a
`safe_range` **is** the pre-registered starting grid and that a bound is *"the start of that
procedure, never the end of it"*.

🔴 **Read the writer of a value before ruling on what the value means.** Three stores that omit a
definition are not three votes that the definition is missing. And a same-named column in a different
store is not the same field.

## Traps this lane paid for

- 🔴 **A cost field can move a PF across a bar while every identity field says it is the same run.**
  Diff the **deal columns**, not the aggregates: the aggregate says *that* two runs differ, the deal
  list says *which field*, and only the second names a cause.
- 🔴 **A report name without a date destroys the artefact a committed record cites**, and
  `_mt5_auto/reports/` is gitignored, so the overwrite is irreversible. 336 files were copied to
  `_mt5_auto/reports/_preserved/20260804_S13G_prerun/` before the runner started — **that copy is the
  only surviving 08-03 artefact for seven of the eight cells** and is what made the deal-level diff
  possible. For `H01/BTCUSD/H4` it was already too late.
- 🔴 **`powershell -File script.ps1 -Symbols A,B,C` binds the whole string as ONE element** — it ran a
  cell literally named `BTCUSD,XAUUSD,EURUSD,USDJPY`. Loop the invocation per symbol.
- ⚠️ **A premise measured nine days ago is not a measurement of today.** `swap_adjust_crypto.py`'s
  docstring is careful, specific, dated — and wrong now. Anything a tool asserts about **broker
  state** needs re-probing, not citing.

## Baseline

`check_state.ps1` CLEAN · pre-commit fast-cages green on every commit this lane made
(`run_s13_tests` 3.4s · `run_front_guard_evidence_tests` 22.1–22.5s · `run_order_collision_tests`
0.7s; per-path budget 90.0s, worst observed 25.7s). The full 29-suite tier was **not** re-measured
here — 🚫 do not quote a tier number this handoff does not contain.

**Re-derive your order block from BOTH tests.** At close: highest `## ORDER-<n>` across all four
board files = **1350**; highest block reserved = **1360-1369**. **Commit the reservation first.**

## Do NOT do in this session

- 🚫 Quote any 2026-08-03 pilot money figure as current · 🚫 quote a financing-adjusted BTCUSD number
  until `ORDER-1350` is settled · 🚫 issue a verdict for either cell from automation · 🚫 quote any
  **Model-1** PF as a quality number · 🚫 set a participation floor without the owner.
- 🚫 Hash the symbol spec into `data_fingerprint` without the migration decision · 🚫 widen any
  `safe_range` before the floor question is answered · 🚫 widen only the cheap dimensions · 🚫 book
  the 14 BOUNDARY re-runs.
- 🚫 Re-run the selector under a different floor · 🚫 search on BWD · 🚫 shorten the window · 🚫 run
  any pilot cell on a second install.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 hand-edit any generated store under `factory/` · 🚫 touch
  `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `check_s2a_attestation.py:BUNDLE`
  member · any `.set` migration · any magic renumber.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| eight cells re-run; five differ by the swap column alone; mechanism named by elimination | ORDER-1330 — **item 3 DONE** |
| the fingerprint's missing component is the symbol spec, and the migration it implies | ORDER-1330 |
| the tester charges BTCUSD swap and the post-hoc tool charges it again | ORDER-1350 |
| 👤 a BWD pass on 49 trades over three years — participation floor | ORDER-1254 → **owner** |
| this lane's ruling withdrawn; the live question is how far down to widen | ORDER-1302 |
| §8.6 stubs and the parity manifest — S13H's order of work | ORDER-1256 / ORDER-1255 |
| PF 1,126 on 5.38 of realised loss | ORDER-1301 |
| 🔴 amend §6.2 to say which floor governs which step | ORDER-1300 |
| the guard layers still off for every non-pilot caller | ORDER-1270 / 1271 |
| the fine half of the §6.2 ladder | ORDER-1274 |

Open with: **"อ่านไฟล์นี้ + S13H — เริ่มที่ ORDER-1256/1255 (ไม่ต้องใช้ MT5) แล้วค่อย ORDER-1350"**
