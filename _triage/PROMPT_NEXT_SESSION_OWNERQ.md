# OPENING PROMPT — the session that was sent to delegate two finished orders, and ended up rewriting a bar

> Written 2026-08-05 by lane `S-2026-08-05-OWNERQ` (block `1420-1429`). It opened on *"give 1411/236
> to qwen, then do 1132, then the decisions"* and found the first two had been executed overnight.
> ⚠️ **Read `docs/SESSION_LEDGER.md` first.** At this writing **no lane is ACTIVE**.

---

## §0 — 🔴 READ FIRST: check the destination before you dispatch

The owner's instruction was to hand `ORDER-1411` and `ORDER-236` to a worker. Both had been run to
completion by the lane that closed at 06:50 the same morning. Dispatching them would have re-run
finished work and produced a second, conflicting set of numbers.

**One `grep` of the two rows was the whole cost of finding that out.** It is the same habit §0 of the
previous handoff asked for, arriving from the other direction: that one said *measure at HEAD before
building a repair*, this one says *read the row before delegating it*.

The useful move once that was known: the three questions parked in §2 of the previous handoff were put
to the owner instead, and all three came back — so the session converted a dead instruction into the
thing that was actually blocking.

---

## §1 — 👤 THREE OWNER RULINGS, all recorded in `PROJECT_STATE.md` §3

| ruling | reach |
|---|---|
| **Participation floor = `≥ 100 closed trades per window`, hard, alongside `n≥30`** | 🔴 **retroactive.** `ORDER-430`'s two qualifications (52 and 62 trades) are **void**, and `ORDER-236`'s un-parking rested on one of them |
| **Re-measure the `Boss_14` chassis with shorts, across the whole `ORDER-430` screen** | became `ORDER-1420` — but not in the shape the instruction assumed, see §2 |
| **Re-point `ORDER-236` at EURJPY and run the lever last-optimize now** | STAGE 1 + STAGE 2 both executed this session |

A fourth was ratified mid-session: **`ORDER-236` STAGE 2 runs the 3×2 distinct-outcome grid**, not the
25-value cross. The `PENDING-RATIFY(user)` note that had stood in `CLAUDE.md` since 2026-07-28 is now a
numbered row in the bar table.

---

## §2 — 🔴 THE CORRECTION THAT MATTERS MOST: `TradeDir` was the wrong input

The previous handoff (§1.3) reported the whole `Boss_14` evidence base as long-only and named
`TradeDir=60` as the cause. **The conclusion is right. The mechanism is not, and the difference decides
what work is even possible.**

```
ea_template/core/Inputs.mqh:113      TRADEDIR_BOTH = 60          <- 60 is BOTH. Shorts were permitted.
ea_template/core/Inputs.mqh:497      _14_Direction = 1           // 1=BUY only, 2=SELL only, fixed, never both
ea_template/core/entries/Entry_GridLog.mqh:70   int dir = (_14_Direction == 1 ? 1 : 2);
```

`Entry_GridLog` **cannot run both directions in one instance**, deliberately, to hold parity with the
standalone it was ported from. So *"enable shorts"* does not exist as a flag. What is available is the
**mirror screen** at `_14_Direction=2`, which is what `ORDER-1420` ran.

👤 **Still with the owner: a genuinely two-sided `Boss_14` needs an `ea_template/core/` change that
breaks that parity.** Not folded into the ruling above, because it is a different decision.

---

## §3 — What was measured, and the one shape that repeats

### `ORDER-1420` — the short side, 7 of 7, **0 qualify**

| | PF | trades |
|---|---|---|
| USDJPY · EURJPY · EURUSD | 0.71 · 0.70 · 0.56 | **111 · 254 · 192** |
| CADJPY · GBPJPY · XAUUSD · AUDCAD | 1.07 · 5.17 · 16.74 · UNDEFINED | **84 · 30 · 4 · 5** |

**Every symbol that made money was barely in the market; every symbol genuinely in the market lost.
There is nothing in between.** Without the floor ratified that morning, this screen hands back
`XAUUSD 16.74` and `GBPJPY 5.17` as the best short hosts — on 4 and 30 trades over three years.

### `ORDER-236 STEP 3` — the lever last-optimize, 12 probe + 12 grid runs

STAGE 1 found all four axes LIVE and then found something below that: **the axes collapse.**
`StackConfirm` has five values and **three** outcomes (`SigValid`/`Retrigger`/`PriceAction` return the
same numbers to the cent); `_9_PA_MinBodyRatio` has five values and **two**. A 5×5 grid would have been
25 cells holding 6 distinct results, and the plateau rule reads duplicates as a plateau.

STAGE 2, on the ratified 3×2 grid: **no cell passes.** But two of three *improve* BWD (`1.06 → 1.16`,
`→ 1.10`) while costing MAIN (`1.82 → 1.47`, `→ 1.37`) and participation (`184 → 84`, `→ 112`).
⇒ **these confirms are defensive filters** — they cut exposure, helping where exposure hurts. Real
mechanism, not a pass; the bar is *better on both*.

🚫 **`DEAD-OPTIMIZED` is NOT earned.** STAGE 2 crossed the top two of four LIVE axes; `_50_RegimeMode`
and `_50_AllowTrendDown` have **never been run under Model 4 on this host.**

---

## §4 — 🎯 The lesson this session paid for twice: a guard sees what it compares, and nothing else

`ORDER-1132` shipped `scripts/check_csv_roundtrip.py` and a `check_state.ps1` arity check, both proven
red before green. **Both then failed to see two defects in this lane's own work:**

1. the repair script **stripped `portfolio/DEPLOYMENTS.csv`'s BOM** (44 non-ASCII bytes in the file;
   PS 5.1 reads a BOM-less UTF-8 file as CP1252);
2. a `csv.writer` defaulting to `QUOTE_MINIMAL` **stripped the quotes from all 158 lines of
   `EA_MASTER_INDEX.csv`**, and the same approach would have rewritten the **append-only**
   `B1_DATASET.csv` wholesale.

Every guard stayed green throughout, correctly: **they compare parsed fields, and neither a BOM nor a
quoting convention is a field.** Both were caught by `git diff --cached`.
⇒ **Stage in one call, read the diff in another, commit in a third.** That is not ceremony; it is the
only thing that caught either one.

---

## §5 — What is OWED

- **`ORDER-430` must be re-read against the `≥100` floor.** Its two qualifications are void and this
  lane did not do the re-read. It owns the file path in the ledger for exactly this reason.
- **`ORDER-236`'s two unmeasured LIVE axes** (`_50_RegimeMode`, `_50_AllowTrendDown`) under Model 4.
- **`ORDER-1050`: the fix, and the numeric reproduction.** Diagnosed — the recompute omitted
  `locked_constants`, so `_constant_scope` returned `surface_only` while the EA hardcodes
  `surface+constants`, and the scope is preimage line 1. `compile_preset` should **refuse** rather than
  silently relabel. 🔴 The two `415573666` `.set` files were never located, so the digests were **not**
  reproduced — the mechanism was demonstrated with a control, which is a weaker claim.
- **`ORDER-501`** — deliberately not run: it measures behaviour under load, and two MT5 lanes were
  busy all session. Run it on an idle machine or the result is uninterpretable.
- **`ORDER-1000`** — needs an `.mq5` edit and a recompile, which this lane's ledger row prohibits.
- **`ORDER-1330` items 1 and 2**, now with a stronger case: see §6.

---

## §6 — An unsought reproduction, worth more than the order it came from

`ORDER-236`'s CTRL re-run reproduced the previous day's EURJPY numbers **exactly on PF and trade count
and not on the money** — MAIN `+2344.20 → +2353.69`, BWD `+567.24 → +599.32`, same `.set`, same lane.

Every earlier instance of `ORDER-1330` was BTCUSD H4 under `pilot_cells.ps1`, which left open the
reading that it was a crypto-financing artefact of one pipeline. **This is EURJPY H1 under
`mt5_run.ps1`, found by a lane that was not looking for it.** The effect is neither crypto-specific nor
pipeline-specific.

---

## §7 — Standing rules that did not change

- 🚫 No EA verdict from automation. 🚫 `$FullTierBudgetSeconds` stays pinned at 120.0s.
- 🚫 `AGENTS.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite.
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` is **`1420`**;
  highest block held by a lane row is **`1420-1429`**. That sentence is stale the moment it is written.
- **The delegated tier died twice more** on the identical `input_tokens = 99073`, once after finishing
  all 12 runs and once before producing anything. `docs/WORKER_BRIEF_RULES.md` §3b records both, and
  records that neither run count nor number-of-files-to-build explains them. **A batch that dies having
  produced zero artefacts must not be re-dispatched unchanged** — run it from the orchestrator.
- ⚠️ **Neither `ORDER-430`'s screen nor `ORDER-1420`'s is pinned.** `mt5_run.ps1` prints it on every
  launch: `order430\CTRL.set` is a legacy 55-key file with **no surface declaration**, so inputs it
  omits come from that terminal's tester cache. The long-vs-short comparison is like-for-like; the
  absolute numbers are not reproducible on another machine.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the participation floor, and the two selections it voids | `ORDER-430` |
| the short screen, 7 of 7, nothing qualifies | `ORDER-1420` |
| the axis collapse, the 3×2 grid, and the two unmeasured LIVE axes | `ORDER-236` |
| the verdict filed, and the inert axes that replicate across symbols | `ORDER-1411` · `EDGE_CATALOG` |
| the fingerprint scope-label diagnosis, and the refusal it still owes | `ORDER-1050` |
| the EURJPY net drift on an identical config | `ORDER-1330` |
| the CSV round-trip guard, its two blind spots, and the repaired inventory | `ORDER-1132` (DONE) |
| a two-sided `Boss_14` requiring a `core/` parity break | 👤 the owner |

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_OWNERQ.md` — จองบล็อกใหม่ก่อน (derive เอง) · stage/อ่าน diff/commit แยก 3 step · เริ่มที่อ่าน ORDER-430 ใหม่ใต้บาร์ ≥100 แล้วไป ORDER-236 สองแกนที่เหลือ · §5 มีของค้าง 6 ข้อ"**
