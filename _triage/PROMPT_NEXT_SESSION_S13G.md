# OPENING PROMPT — the two cells are fully measured, and the measurement moved four orders of magnitude

> ⚠️ **SUPERSEDED ON TWO POINTS by `_triage/PROMPT_NEXT_SESSION_S13H.md`** — the order of work (start
> at `ORDER-1256`/`1255`, which need no tester) and **`ORDER-1302`, whose premise in this file and on
> the board is WRONG**: `safe_range` is a pre-registered *starting grid*, not a safety declaration,
> and design §6.3 + decision 19 already require expand-and-re-run. Everything else here stands.
>
> Written 2026-08-04 by lane `S-2026-08-04-S13F` (block `1330-1339`).
> `ORDER-1273` **DONE end to end** · `ORDER-1254` **DONE for the two verified cells** ·
> `ORDER-1330` **opened** · nothing else touched.
> ⚠️ Lane `S-2026-08-04-CORRECT4` (block `1320-1329`) was live throughout and closed `ORDER-1310`
> (all nine). **Read `docs/SESSION_LEDGER.md` before assuming either state.**

---

## ✅ What is now measured, so you do not re-run it

All four commands are read-only:

```bash
tools/python312/python.exe scripts/pilot_verify_check.py
tools/python312/python.exe scripts/_test/run_pilot_verify_tests.py
tools/python312/python.exe scripts/pilot_selected_surface_row.py factory/runs/pilot/selection/selection_20260804_064906.jsonl
powershell -NoProfile -File scripts/_test/run_s13_tests.ps1
```

**Four runs exist per cell** — MAIN and BWD, each under Model 1 and Model 4 — same lane, same `.set`
hashes, `_41_FixedLot=0.03`. Records in `factory/runs/pilot/verification/`.

| `B14-H01-r1/BTCUSD/H4` | MAIN M1 | **MAIN M4** | BWD M1 | **BWD M4** |
|---|---|---|---|---|
| PF | 15,408.74 | **2.09** | 0.76 | **0.95** |
| PF, financing deducted | — | **1.63** | — | **0.84** |
| trades · DD % | 94 · 7.90 | 75 · 14.85 | 49 · 16.01 | 51 · 15.12 |

| `B14-H02-r1/BTCUSD/H4` | MAIN M1 | **MAIN M4** | BWD M1 | **BWD M4** |
|---|---|---|---|---|
| PF | UNDEF | 1,126.56 | 1.61 | **1.44** |
| PF, financing deducted | — | **4.63** | 1.31 | **1.20** |
| trades · DD % | 78 · 12.38 | 82 · 10.49 | 57 · 15.63 | 49 · 15.22 |

1. 🔴 **Model 1 was not measuring the same quantity.** `B14-H01-r1`'s MAIN PF falls **15,408.74 →
   2.09**: under 1-minute OHLC the basket realises **38 cents** of gross loss across three years,
   under 143.6 M real ticks it realises **2,188.32**. 🚫 **No Model-1 number anywhere in this corpus
   may be quoted as a quality figure.**
2. 🔴 **`B14-H02-r1` does not come back to earth even on real ticks** — 5.38 of gross loss against
   6,060.88 of gross profit, while the crypto financing the tester never charges on that same run is
   **1,304.25, i.e. 242× the entire realised loss.** That is `ORDER-1301` at its sharpest.
3. **`B14-H01-r1` misses the BWD gate under BOTH models** (0.76 · 0.95 · **0.84** after financing).
   Consistent across models ⇒ a robust miss, not a modelling artefact. Its MAIN M4 of 2.09 clears
   its own bar; the **both-window** requirement is what it does not meet.
4. **`B14-H02-r1` clears every numeric bar** and every caveat travels with it: **49 BWD trades**,
   DD **15.22 %** vs `RC_AcctDDLimitPct=12.0`, 99 % BWD history quality, **100 % LONG in all four
   runs**, financing-adjusted BWD margin **1.20**.
5. **`ORDER-1273` step 6 was not optional and the evidence says so:** `B14-H01-r1`'s selected point
   appears in **0 of 3,991 rows** of the surface it was selected from.

🚫 **No verdict was issued for either cell** — design §10 stops at `EVIDENCE_COMPLETE`, and
**issuing one is not an automation step.**

---

## 👤 THE ONE THING THAT NEEDS THE OWNER, and it is the next action

`B14-H02-r1/BTCUSD/H4` clears every bar in the table **on 49 BWD trades over a three-year window.**
That is precisely `CLAUDE.md`'s un-numbered **`PENDING-RATIFY(user)`** case: `n ≥ 30` screens out
*having no trades*, not *having too few to interpret*, and a bar can be cleared by **not
participating** rather than by surviving (memory `bar-cleared-by-non-participation`).

**Ask the owner, do not decide it from the seat, and do not re-run anything to make it go away:**

> `B14-H02-r1/BTCUSD/H4` ผ่านทุกบาร์ตัวเลข (MAIN M4 PF 4.63 · BWD M4 PF 1.20 หลังหักค่า financing ·
> both-window ≥ 1.0 · ไม่มี model-switch cliff) **แต่ BWD มีแค่ 49 ไม้ใน 3 ปี · DD 15.22% เกินเพดาน
> 12% · และ 100% LONG ทั้ง 4 รัน** — จะนับว่าผ่าน BWD hard gate ไหม หรือจะตั้ง participation floor
> ก่อน (บาร์ใหม่ต้องให้ owner เคาะตามกฎ ORDER-235)

🚫 Do not set a participation floor yourself — **changing a bar requires the owner** (`ORDER-235`
precedent, stated in `CLAUDE.md`).

---

## 🔴 `ORDER-1330` — the finding that was not in anyone's diff

The same configuration produced **net 332.50 on 2026-08-03 and 324.75 on 2026-08-04 (−2.3 %)**, with
`dd_pct` 15.12 → 15.22, while **`effective_config_hash`, `data_fingerprint`, the tracked `.set`
bytes, the `.ex5` mtime, the terminal build and the bar/tick counts were all identical** — each
checked, none assumed. **It is not run-to-run noise:** the two 08-04 runs are byte-identical to each
other, and the step-6 verification runs also reproduced exactly when re-run the same session.
**Same session reproducible; across sessions not.**

Design §6.4 declares a `Bases\` state marker in the fingerprint recipe that **nothing in this repo
computes** — `Get-PilotDataFingerprint` says so in its own comment. First candidate.

🚫 **Do not quietly start hashing it in** — that silently reclassifies every fingerprint already
recorded. It needs a decision plus a migration. 🚫 And do not generalise from one cell and one pair
of days: reproduce it on a second cell first (memory `phantom-regression-from-two-single-samples`).

**Why it is not academic:** `B14-H02-r1`'s BWD margin is **1.20** against a **1.0** hard gate. ±2.3 %
does not close that today, but the next cell need not be so far from the line.

---

## The work, in order

1. 👤 **Take the 49-trade question to the owner** (above). Everything about `B14-H02-r1` waits on it.
2. **`ORDER-1330`** — decide the fingerprint question, or reproduce it on a second cell first.
3. **`ORDER-1302`** — the fourteen `BOUNDARY` cells, and the unresolved conflict inside "expand the
   grid": the declared grid **is** `safe_range` in `factory/parameter_bindings.jsonl`, and four
   edges cannot be widened in the direction the median points at all. **Settle whether a boundary at
   the edge of a safe range is a finding or a re-run before spending the 3–12 hours.** Untouched.
4. **`ORDER-1301`** — now has its sharpest evidence (item 2 above). Still open.
5. 🔴 **`ORDER-1300`'s remaining debt is still owed and is still nobody's:** amend
   `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §6.2 to say **which floor governs which step** (base 100/60
   governs the decision-13 probe · doubled governs an optimize campaign). ⚠️ `check_s2a_migration`
   reads a design claim, so touching that file means running `run_s2a_conformance.py` + the
   schema/contract cages too.
6. `ORDER-1270` / `1271` / `1255` / `1256` / `1274` — untouched, blocked by nothing, and the ones to
   take if the MT5 lane is busy.

## Baseline before you touch anything

`run_fast_cages.ps1 -Hook` (**29 suites, 0 failed, 97.9s of the pinned 120.0s — 22.1s headroom**) ·
⚠️ two intermediate readings of `100.5s / 2 failed` and `98.6s / 1 failed` were taken while the
concurrent lane was committing (`.git/index was rewritten during this run`); **the 1 real failure
was `run_guard_trigger_tests` and it is fixed** — see the traps. Do not quote a tier number from a
run whose transcript says the index moved. · `run_s13_tests.ps1`
(now also runs the 16-case pilot-verify cage + `pilot_verify_check.py`; 1.67/1.68/1.69s) ·
`run_selection_tests.ps1` · `run_optimize_guard_tests.ps1` · `run_schema_cages.ps1` ·
`check_state.ps1` · `_triage/factory_os/run_s2a_gate.py`.
⚠️ **~20s of tier headroom, shared with the other lane. Measure before adding a suite; never raise
`$FullTierBudgetSeconds`.**

**Re-derive your order block from BOTH tests.** At close: highest `## ORDER-<n>` across all four
board files = **1330**; highest block reserved in the ledger = **1330-1339**. **Commit the
reservation before using a number.**

## Traps this lane paid for (the new ones)

- 🔴 **Committing a tool is what arms the trigger guard on its CALLER.** `run_s13_tests` called two
  new scripts for a whole session with `run_guard_trigger_tests` green, because that guard's question
  is about **tracked** paths — it went red only after the tools were committed, i.e. after the tier
  had already been measured and written into a handoff as green. **A green tier measured before your
  new files are tracked is not a measurement of the tier you are shipping.** (And declaring an input
  without re-running `scripts/gen_fast_tier_pathspec.ps1` leaves it declared and unselected — a
  second, separate failure the guard names by hand.)
- 🔴 **An equivalence proof that never runs the migrated caller proves the library, not the
  migration.** 4,904 comparisons said the extraction was clean; the forwarders in `pilot_cells.ps1`
  had still never executed. Running them once is what surfaced `ORDER-1330`.
- 🔴 **`io.TextIOWrapper(sys.stdout.buffer, …)` closes that buffer when collected**, so the first
  in-process caller silently kills stdout for every caller after it. The cage died on its own second
  case with a `ValueError` instead of a result. **Reconfigure the stream; never wrap the buffer.**
- 🔴 **A "newest record" sort over `verification_<WINDOW><lot>_<stamp>.jsonl` orders by WINDOW, not
  by time** — every `MAIN` beats every `BWD` whatever the dates say, and `ORDER-1254` writes BWD
  beside MAIN. Caught by a cage written before a BWD record existed to get wrong. Sort by the parsed
  stamp; a filename without one is skipped **and named**.
- 🔴 **A report name that omits a variable you are about to change destroys the evidence it
  separates.** The name carried the window and the lot but not the **model**, so the Model-4 MAIN run
  would have overwritten the Model-1 MAIN report and left the committed Model-1 record pointing at a
  Model-4 artefact. Caught before it fired, and only because the lot tag's own comment warns of the
  identical trap one variable along.
- 🔴 **A comparison that drops the columns which disagree is not a comparison.** The reference-row
  lookup carried `Result` and `Trades` while `Profit` sat in the same row, making "78 trades against
  78" read as a reproduced row when `Profit` differed by 18.22.
- ⚠️ **Third generated store with nothing re-deriving it.** `ORDER-1272` closed it for
  `coverage.jsonl`, the next lane recreated it for `selection/`, this lane made it three with
  `verification/`. **Ask it of every generated artefact: what re-derives it, and what runs that?**
- ⚠️ **Losing the board race is symmetric.** This lane's rows rode into `CORRECT4`'s commit
  `3da7e578` — the mirror of the usual scar. Content intact, provenance wrong, **not rewritten**.
  Reverting the other lane's line first to protect attribution was rejected: holding their edit
  reverted while they may commit is how work actually gets destroyed.
- ⚠️ **Bash ate a commit message containing `$0.38`.** `$0` expands inside double quotes. Use
  `git commit -F <file>` for any message carrying dollar amounts.

## Do NOT do in this session

- 🚫 Issue a verdict for either cell from automation · 🚫 quote any **Model-1** PF as a quality
  number · 🚫 quote a crypto number with financing not deducted · 🚫 set a participation floor
  without the owner.
- 🚫 Re-run the selector under a different floor · 🚫 re-rank the existing surfaces · 🚫 search on
  BWD · 🚫 shorten the window · 🚫 run any pilot cell on a second install.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 hand-edit `factory/coverage.jsonl` or any
  `factory/runs/pilot/**` record (both are generated and both now have a `--check`).
- 🚫 Touch `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any
  `check_s2a_attestation.py:BUNDLE` member · any `.set` migration · any magic renumber.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| step 6 executed; the selected point of H01 is on 0 of 3,991 rows | ORDER-1273 — **DONE** |
| BWD + Model 4 on both verified cells; H01 misses the hard gate under both models | ORDER-1254 — **DONE for these two cells** |
| 👤 a BWD pass on 49 trades over three years — participation floor | ORDER-1254 → **owner** |
| the same config, different money on two days, every identity field identical | ORDER-1330 |
| PF 1,126 on 5.38 of realised loss, against 1,304 of uncharged financing | ORDER-1301 |
| 14 BOUNDARY cells; expanding the grid edits a `safe_range` | ORDER-1302 |
| 🔴 amend §6.2 to say which floor governs which step | ORDER-1300 |
| the guard layers still off for every non-pilot caller | ORDER-1270 / 1271 |
| §8.6 items 3-4, and the last four stubs | ORDER-1255 / 1256 |
| the fine half of the §6.2 ladder | ORDER-1274 |

Open with: **"อ่านไฟล์นี้ แล้วเริ่มได้เลย — ถ้า owner ยังไม่เคาะเรื่อง 49 ไม้ ให้ไปทำ ORDER-1330 / 1302 ก่อน"**
