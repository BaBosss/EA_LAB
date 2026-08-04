# OPENING PROMPT — the checklist is no longer green-by-not-looking, and one item went red

> Written 2026-08-04 by lane `S-2026-08-04-S13H` (block `1370-1379`).
> `ORDER-1256` **items 10 and 11 DONE** · `ORDER-1370` **opened** · `ORDER-1255` **not started, and
> the reason is a lane conflict** · no tester run was made.
> Read `_triage/PROMPT_NEXT_SESSION_S13I.md` for the `ORDER-1330` / `ORDER-1350` findings this row
> depends on. ⚠️ Other lanes were ACTIVE throughout — **read `docs/SESSION_LEDGER.md` first.**

---

## What moved, and the arithmetic the previous handoff got wrong

`§8.6` did **not** go `8/14 → ~12/14`. It went:

```
before   8 PASS · 0 FAIL · 6 BLOCKED (0 awaiting evidence, 6 checker-not-implemented)
after    8 PASS · 1 FAIL · 5 BLOCKED (1 awaiting evidence, 4 checker-not-implemented)
```

**The PASS count is unchanged and that is the correct outcome.** Two stubs that returned a hardcoded
`BLOCKED` now read the committed evidence, and neither one's evidence is clean. A checklist that
moved to 12/14 here would have moved because nobody looked.

## 🔴 The FAIL — `ORDER-1370`

Item 10 was described as *"the evidence already exists — checker only"*. It does exist. Reading it
turns up a contradiction: **the financing statement splits by ARM.**

| arm | with a financing statement | without |
|---|---|---|
| `baseline` | **12** | 0 |
| `selected-verification` | **10** | 0 |
| `flat-lot-probe` | 0 | **10** |
| `probe-escalated` | 0 | **6** |

`B14-H01`'s pre-registered falsifier is *"flat-lot PF ≥ escalated PF"*, and on `BTCUSD/H4` it has
been quoted as **1.82 vs 1.18** — an unadjusted number against an adjusted one, on a symbol where
financing moves a gross loss from −92.69 to −11.06 on a neighbouring cell.

🚫 **Do not repair it by adding the deduction to the probe arms.** `ORDER-1350` measured that the
tester may already be charging the cost, which would make the **twelve baselines** the wrong side.
**Settle `ORDER-1350` first** — one dated probe of the symbol's swap mode on the pinned lane.

## The work, in order

1. **`ORDER-1350`** — the dated swap-mode probe. Everything crypto waits on it, including the
   owner's 49-trade question, whose `1.20` margin is understated while the double charge stands.
2. **`ORDER-1370`** — apply that answer to every arm. Item 10 then goes green **by reading**, with no
   edit to the checker: case `F1` already proves that path, and the two fields it wants are
   `financing_deducted.tester_swap_charged` and `financing_deducted.swap_mode_probe`.
3. **`ORDER-1255`** — take it whole, in a lane that owns `_triage/factory_os/schemas.json`. It was
   not started here because acceptance (1) is a schema entity and `S-2026-08-04-CORRECT5` holds that
   file. Building the `parity.py` half alone would leave a manifest nothing describes.
4. **`ORDER-1256` items 12 and 14** — 12 is compound on every other item being able to pass, which is
   its honest state. 14 needs an end-of-pilot marker plus a `tpl_regression` run on the declared
   lane: **an MT5 run**, and inventing the artefact's path from the seat is guessing at a contract.
5. **`ORDER-1330` items 1-2** · **`ORDER-1302`** (owner: how far down to widen) · `ORDER-1301` ·
   `ORDER-1300` · `1270` / `1271` / `1274`.

## 👤 Still with the owner, neither urgent

- **How far down do we widen the grids** — 23 of 32 boundary hits are at the LOW edge, and low on
  `_9_StepATRmult` / `_2_BasketTP_BalPct` means a tighter grid and faster take-profit, i.e. more
  positions on an ENGINE-EDGE class. A floor must be pre-registered before the sweep.
- **The 49-trade participation question** on `B14-H02-r1/BTCUSD/H4`. ⚠️ Its numbers move when
  `ORDER-1350` lands, in the cell's favour.

## Traps this lane paid for

- 🔴 **A handler that reads evidence but is gated on a hardcoded known-defect is still a stub.** Item
  10's `ORDER-1350` gate is read from two named record fields precisely so the item can go green
  without another edit to the module. If you find yourself writing `return BLOCKED` because of an
  open order, name the field that would settle it instead.
- 🔴 **Take the EARLIEST kill, not the latest.** Item 11's first version used `max(attempt)` over
  killed attempts, so a run killed on every attempt read as *never resumed* — three resumes rendering
  as none. The live corpus produced the wrong answer before the fixture did; case `S2` is that
  regression, written after the fact and honest about it.
- ⚠️ **`list_committed`'s `*` does not cross `/`.** The BWD and Model-4 runs live in
  `factory/runs/pilot/verification/`, so a handler globbing only the matrix directory would report
  cleanly on the third of the runs nobody judges anything from. Case `F6` is that specificity check.
- ⚠️ **A red checklist item with no order behind it becomes background noise** — hence `ORDER-1370`
  exists in the same commit as the `FAIL` that produced it.

## Baseline

`check_state.ps1` CLEAN · `run_s13_tests` **88 cases, 0 failed** (12 new) · pre-commit fast-cages
green on every commit (`run_s13_tests` 3.7s · `run_front_guard_evidence_tests` 22.4s; per-path budget
90.0s). The full 29-suite tier was **not** re-measured — 🚫 do not quote a tier number from here.

**Re-derive your order block from BOTH tests, and do not trust this sentence.** At close: highest
`## ORDER-<n>` across all four board files = **1370**; highest block reserved = **1370-1379**. Three
lanes reserved blocks between the previous handoff being written and being read.

## Do NOT do in this session

- 🚫 Add the financing deduction to the probe arms before `ORDER-1350` · 🚫 quote a financing-adjusted
  BTCUSD number · 🚫 quote any 2026-08-03 pilot money figure as current · 🚫 quote a **Model-1** PF as
  a quality number · 🚫 issue a verdict for any cell from automation.
- 🚫 Delete an `UNIMPLEMENTED` entry without implementing its handler · 🚫 make a checker PASS by
  weakening what it asks · 🚫 wire the parity checker to re-read `_mt5_auto/reports/**`.
- 🚫 Set a participation floor or a grid-widening floor without the owner · 🚫 widen any `safe_range`
  · 🚫 book the 14 BOUNDARY re-runs.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 hand-edit any generated store under `factory/` · 🚫 touch
  `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `check_s2a_attestation.py:BUNDLE`
  member · any `.set` migration · any magic renumber.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| items 10 and 11 read committed evidence; 12 and 14 are still stubs | ORDER-1256 |
| the financing statement splits by arm, and the falsifier compares across it | ORDER-1370 |
| the dated swap-mode probe every crypto number waits on | ORDER-1350 |
| not started: acceptance (1) is a schema entity another ACTIVE lane holds | ORDER-1255 |
| the fingerprint's missing component is the symbol spec | ORDER-1330 |
| 👤 how far down to widen the grids | ORDER-1302 → **owner** |
| 👤 a BWD pass on 49 trades over three years | ORDER-1254 → **owner** |
| PF 1,126 on 5.38 of realised loss | ORDER-1301 |
| 🔴 amend §6.2 to say which floor governs which step | ORDER-1300 |
| the guard layers still off for every non-pilot caller | ORDER-1270 / 1271 |
| the fine half of the §6.2 ladder | ORDER-1274 |

Open with: **"อ่านไฟล์นี้ — เริ่มที่ ORDER-1350 (probe swap mode พร้อมวันที่) แล้วต่อ ORDER-1370 · จองบล็อกใหม่ก่อน derive เองจากทั้ง 2 test"**
