# OPENING PROMPT — the selection ran, and it asks a question before it answers one

> Written 2026-08-04 by lane `S-2026-08-04-S13E` (`ORDER-1273` DONE · `ORDER-1272` DONE ·
> `1300`-`1302` opened). **`ORDER-1254` is NOT next**, and that is the whole point of this file.
> ⚠️ A second lane, `S-2026-08-04-CORRECT3` (block `1310-1319`), was live throughout and may still
> be. Read `docs/SESSION_LEDGER.md` first. It owns `ORDER-1269`/`1267`/`1266`/`1257` and the
> `_triage/factory_os/check_s2a_*` files; it declares 🚫 on `factory/**`, `scripts/pilot_probe_*`
> and `scripts/_test/**`, so the two lanes do not overlap except on `AGENT_TASKBOARD.md` — where
> **this lane lost the race once, so read the trap section before staging that file.**

---

## ✅ What changed, so you do not rebuild it

Verify, do not assume — all four commands are read-only:

```bash
tools/python312/python.exe scripts/pilot_probe_select.py --dry-run
tools/python312/python.exe _triage/factory_os/gen_pilot_cells.py --check
tools/python312/python.exe _triage/factory_os/run_pilot_cells_tests.py
powershell -NoProfile -File scripts/_test/run_selection_tests.ps1
```

1. **`ORDER-1273` is EXECUTED, verbatim, as `scripts/pilot_probe_select.py`.** The record is
   `factory/runs/pilot/selection/selection_20260804_051809.jsonl` — one row per cell, carrying the
   floor, the plateau size, the rounding rules, and the boundary dimensions by name.
2. **The answer is `SELECTED` 2 · `BOUNDARY` 14 · `NO_ADMISSIBLE_PASS` 0.** Only
   `B14-H01-r1/BTCUSD/H4` and `B14-H02-r1/BTCUSD/H4` produced a configuration.
3. **The order's own prediction was wrong and nothing was adjusted to fit.** It said *"expect ~1
   cell in 16 to clear its floor"*; all sixteen do. The prediction came from the **baseline** trade
   counts, while the floor applies to the **swept surface**, where thousands of configurations trade
   far more than the baseline one did (`B14-H01-r1/BTCUSD/H4`: 3,030 admissible of 3,991). The rule
   held; the guess about what it would return did not, and it was a guess about the wrong population.
4. **`ORDER-1272` is closed: `gen_pilot_cells.py --check` runs on the commit path**, inside
   `run_s13_tests.ps1`, with its own 11-case cage running first. The READ side went through
   `evidence.EvidenceSource`; `--apply` stays pinned to the worktree and is byte-stable.
5. **The one-character control was run against the LIVE store**, not only against fixtures: the
   commit was refused, `--check` printed `DRIFT ... dd_pct 15.73 vs 15.72` naming the cell, HEAD
   never moved, and the store was byte-identical to HEAD before and after. It took three attempts
   and the first two failed for reasons that were mine — see the traps.

**Tier:** 27 → 28 suites. `93.2 / 93.6 / 94.0s of 120.0s` under
`powershell -NoProfile -File scripts/_test/run_fast_cages.ps1 -Hook` on a quiet lane
(≈26s headroom). The budget stays **pinned at 120.0s**.
**`check_pilot_acceptance` is unchanged at `8 PASS · 0 FAIL · 6 BLOCKED (0 awaiting evidence, 6
checker-not-implemented)`** — this lane produced no new acceptance evidence, deliberately.

---

## 🔴 THE THING TO SETTLE FIRST — `ORDER-1300`, and it needs the owner

Design §6.2, one sentence: *"`Criterion` 0→7 (Complex), **engine-edge uses PF + double trade
floor** · trade floors H4/D1 ≥60, H1/M30 ≥100"*. `pilot_probe.ps1` quotes the first half of that
sentence to justify launching with `-Criterion 1`. Both pilot hypotheses carry `engine_edge=true`.
**`ORDER-1273` pinned the undoubled floor** — H1 ≥ 100, H4 ≥ 60 — while its own prohibition list
opens with *"relaxing the floor"*.

Measured over all sixteen surfaces, base (100/60) against doubled (200/120):

| | base | doubled |
|---|---|---|
| cells with an admissible pass | 16/16 | 14/16 (both `EURUSD` cells of H01 fall to zero) |
| cells whose selected configuration is IDENTICAL | — | **2 of 16** |

So the floor decides what fourteen cells hand to BWD, and whether two hand anything.
**Do not decide this from the seat.** `ORDER-1220` is precisely about who may change a criterion
after the surfaces have been read; the doubled floor being *stricter* and *design-ratified* makes it
the likely answer, not a licence to apply it unilaterally. 🚫 Do not re-run the selector under the
doubled floor and record the output as *the* selection. 🚫 Do not settle it by counting how many
cells each floor leaves alive.

---

## The work, in the order the evidence forces

1. **`ORDER-1300` — the floor.** Owner decision. Everything downstream reads differently depending
   on it, so nothing below is worth tester wall-clock until it lands.
2. **`ORDER-1302` — the fourteen BOUNDARY cells, and the conflict inside "expand the grid".** The
   declared grid *is* `safe_range` in `factory/parameter_bindings.jsonl` — the range the store calls
   **safe**. Widening it to satisfy §6.3 widens a safety declaration, and four edges cannot be
   widened in the direction the median points at all (`_2_BasketTP_BalPct` 0.5 · `_14_MinDistPips` 5
   · `_H_Ratio` 0.5 · `_0_ATR_Period` 7). **Either the grid and the safe range are two different
   things and the store must carry both, or a boundary at the edge of a safe range is a finding
   rather than a re-run.** Settle that first; the re-runs are second, and they cost **3–12 hours**
   (the coarse pass measured 675–3,211 s/cell).
3. **`ORDER-1301` — the ranking column.** `Result` equals `Profit Factor` to the digit;
   **303 of 303** plateau rows on the cleanest cell have PF > 100, with a median implied gross loss
   of **$0.68** over the whole three-year window (`Profit / (PF-1)`, both committed columns) against
   6.6–14.3 % equity drawdown. On a basket martingale, PF-max ranks by how long a loss can be
   deferred, not by edge (memory `guard-bounds-floating-not-episode`). No verdict follows from this
   and no re-ranking may be done on the existing surfaces — but nobody should quote a plateau PF of
   12,211 as a quality number.
4. **`ORDER-1273` step 6 — re-run each selected configuration once.** Blocked on item 1: a
   verification run of a configuration that may not be the selected one buys nothing.
5. **`ORDER-1254` — BWD then Model 4.** Re-blocked on 1300 + 1302 and marked so on the board.
6. `ORDER-1270` / `1271` (the guard layers still off for every non-pilot caller) · `ORDER-1255` ·
   `ORDER-1256` · `ORDER-1274` (the fine half of the §6.2 ladder) are untouched and unblocked by
   any of the above — **these are the ones to take if the owner is not available.**

🚫 **Still: no verdict from automation.** Design §10 stops this slice at `EVIDENCE_COMPLETE`.
Everything measured is **Model 1 on MAIN**, so nothing produced so far is verdict-grade.

## Baseline before you touch anything

- `run_fast_cages.ps1 -Hook` **on a quiet lane** (28 suites) · `run_s13_tests.ps1` (76 cases + the
  pilot-cells cage + the real `--check`) · `run_selection_tests.ps1` (16) ·
  `run_optimize_guard_tests.ps1` (32) · `run_schema_cages.ps1` · `check_state.ps1` ·
  `_triage/factory_os/run_s2a_gate.py`.
- ⚠️ **`run_contract_binding_tests.ps1` is RED and it is not yours.** It was red at this lane's
  baseline for the `ORDER-1257` stale pin, and it is *still* red at close but with a **different**
  message (`recording a decision needs no guard edit`) — `S-2026-08-04-CORRECT3` is mid-flight on
  `ORDER-1269`. `run_s2a_gate.py` went from RED to **all 7 steps green** during this lane, by their
  work and not by mine. Re-read both before concluding anything about either.
- **Re-derive your order block from BOTH tests.** At close: highest `## ORDER-<n>` across all four
  board files = **1302**; highest four-digit block reserved in the ledger table = **1310-1319**
  (`CORRECT3`) → **1320-1329** is next. **Commit the reservation before using a number.**
- `git log --oneline -15`, and read `docs/SESSION_LEDGER.md` for lanes still `ACTIVE`.

## Traps this lane paid for (the new ones)

- 🔴 **A cage whose fixture quotes the live repository goes red on the exact change it exists to
  describe.** `run_pilot_cells_tests` pinned `'"dd_pct": 15.72'`; the moment the real store was
  mutated to test the wiring, the cage THREW looking for a string that was no longer there, and the
  tier reported `exit -1 SUITE THREW` with the cause truncated. Every anchor — cell id, value, arm,
  row count — is derived from the copied rows at run time now.
- 🔴 **Two questions must not ride on one artefact.** The cage's baseline was a photograph of the
  working tree, so with the store drifted its CONTROL case ("an untouched copy re-derives") was
  false and the tier called the *cage* broken instead of reporting the *drift*. Fixed by running
  `--apply` against the **copy**: "does the checker notice a change" is now answerable regardless of
  whether the live store happens to be correct — which is the separate question `--check` answers.
- 🔴 **`write_store` defaulted its path to the MODULE's `ROOT`, not the source's** — so `--apply`
  with an injected source would have read a temp root and **overwritten the real store**. Nothing
  had ever called it that way, so it had never been wrong in practice and would have looked correct
  until the first time it mattered. Found only because a cage needed to normalise its own copy.
- 🔴 **A test hook the code under test discards is worse than none.** The cage first injected its
  `EvidenceSource` through a module global, and `main()` overwrote it two lines later — so every
  mutation case ran against the REAL repository and passed by not happening. All eleven were green.
  The source is an explicit parameter of `main` now.
- 🔴 **A cross-check between two readers of the same bytes is a tautology.** `pilot_probe_select`
  first compared its row count against `pilot_probe_verify_xml` — same regex, same file, same
  count — which reads as cross-validation and can never come out unequal. It compares the live
  artefact against the committed `trial_count` instead, which can.
- 🔴 **`refuses()` must catch more than `SystemExit`.** Deleting the missing-dimension refusal from
  `pilot_probe_select` produced a `ValueError` that travelled straight out of the suite: exit 1,
  raw traceback, **zero `[FAIL]` lines**. The mutation was caught by the process dying, not by the
  case that exists to catch it. A crash is now reported AS the case it broke.
- ⚠️ **Staging a shared board at the index does not win a race.** This lane's `AGENT_TASKBOARD.md`
  edits were staged when `CORRECT3` committed its lane reservation, and git carried **128 lines of
  this lane's work into their commit**. Nothing was lost and nothing was rewritten — history surgery
  on a shared worktree costs more than a wrong commit message — but the provenance is wrong, and
  it is recorded in `B1_DATASET.csv` as `wrong_order_file_scope=1`. **Commit the board within
  seconds of staging it, or expect this.**

## Do NOT do in this session

- 🚫 Decide `ORDER-1300` from the seat · 🚫 re-run the selector under a different floor and record it
  as the selection · 🚫 re-rank the existing surfaces on a different column · 🚫 relax either floor.
- 🚫 Close a BOUNDARY cell by widening only the dimensions that are cheap to widen · 🚫 shorten the
  window to save time (§6.2) · 🚫 run any pilot cell on a second install (§8.3 pins `BTCUSD`) ·
  🚫 search on BWD.
- 🚫 Issue any EA verdict from automation · 🚫 quote a plateau PF as a quality number · 🚫 quote a
  crypto number with financing not deducted.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 edit a cage to make its own FAIL go away · 🚫 hand-edit
  `factory/coverage.jsonl` (it is generated, and as of `c772b12f` the hook will now refuse it).
- 🚫 Touch `AGENTS.md` · `PROJECT_STATE.md` · `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §8.6 ·
  `s2a_attestations.jsonl` · any `.set` migration · any magic allocate/renumber/retire.
- 🚫 Pick up `CORRECT3`'s orders (`1269` · `1267` · `1266` · `1257`) while that lane is `ACTIVE`.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| the pre-registered criterion, executed; 2 SELECTED / 14 BOUNDARY / 0 empty | ORDER-1273 — **DONE** |
| `gen_pilot_cells --check` on the commit path + its cage + the live one-character control | ORDER-1272 — **DONE** |
| 🔴 the pinned floor is §6.2's BASE floor while both revisions are engine-edge, which doubles it | ORDER-1300 |
| the PF-max plateau is entirely configurations with no realised loss | ORDER-1301 |
| 14 of 16 cells are BOUNDARY, and expanding the grid edits a `safe_range` | ORDER-1302 |
| re-run each selected configuration once, and BWD 2020-22 then Model 4 | ORDER-1254 |
| the guard's build + ParameterBinding layers are off for every non-pilot caller | ORDER-1270 |
| enumerate every path by which a parameter value is SELECTED | ORDER-1271 |
| the parity result manifest; §8.6 items 3-4 | ORDER-1255 |
| the last four stubs — §8.6 items 10, 11, 12, 14 | ORDER-1256 |
| the fine half of the §6.2 ladder, blocked on the plateau `ORDER-1273` selects | ORDER-1274 |
| `run_s10_tests.py:769` asserts its own suite is on the commit path with a SUBSTRING test | ORDER-1272 |

Open with: **"อ่านไฟล์นี้ แล้วเริ่มได้เลย — ถ้า owner ยังไม่เคาะ ORDER-1300 ให้ไปทำ 1270/1271/1255/1256 ก่อน"**
