# OPENING PROMPT — close S13's acceptance without touching the tester, and repair one premise first

> Written 2026-08-04 by lane `S-2026-08-04-S13F` as an addendum to
> `_triage/PROMPT_NEXT_SESSION_S13G.md` (which stays valid for everything it says about the two
> verified cells). **This file supersedes S13G only on the ORDER OF WORK and on `ORDER-1302`.**

---

## Start here: `ORDER-1256` then `ORDER-1255`. No MT5 lane needed.

**Why these two first, measured rather than assumed.** `§8.6` is the pass/fail for the whole S13
slice and it currently reads **8 PASS · 0 FAIL · 6 BLOCKED**. The checker says of itself:

```
[pilot-acceptance] ⚠ EVIDENCE_COMPLETE is currently UNREACHABLE: 6 of the 14 items are stub
checkers, so no amount of pilot evidence can turn this green until they are implemented.
```

🔴 **The six are not waiting for evidence. They are hardcoded returns that never read anything.**
Open `_triage/factory_os/check_pilot_acceptance.py:627` — `item_crypto_financing(src)` ignores `src`
entirely and returns a constant string. **And that string is now false:**

> *"no BTCUSD cell has been run"*

while the **same checker**, in items 7-9, prints `B14-H02-r1/BTCUSD/H4 [MAIN] PF=1.16 n=58` and four
more BTCUSD cells. `item_scheduler_resume` has the same shape (*"No pilot batch has been run"* —
also false). **The acceptance report is currently telling its reader that this project is further
behind than it is**, which is the `guard-disarmed-by-prose-reported-as-note` family exactly.

| §8.6 item | what it still needs | order |
|---|---|---|
| 3 · 4 — parity on all seven points of §5.5 | the parity result manifest — **no tester** | `ORDER-1255` |
| **10 — crypto financing deducted** | 🟢 **the evidence already exists** — `factory/runs/pilot/verification/*.jsonl` carries `financing_deducted` with tool, rates and amount on all four BTCUSD runs. **Checker only.** | `ORDER-1256` |
| 11 — scheduler resumes a killed batch | one kill-and-resume of a **pilot** batch (small MT5 job) | `ORDER-1256` |
| 12 — `EVIDENCE_COMPLETE`, no verdict from automation | turns green on its own once the others do | — |
| 14 — `tpl_regression` + `param_registry_check` CLEAN end-to-end | one closing run on the pinned lane | `ORDER-1256` |

**So four of the six are desk work and one already has its evidence sitting committed.** Do those
first; they move §8.6 from 8/14 to roughly 12/14 without booking the tester.

⚠️ When you implement a stub, **delete its entry from the not-implemented list too** — the roll-up
distinguishes `awaiting evidence` from `checker-not-implemented`, and a checker that starts reading
while still declared a stub makes that distinction lie in the other direction.

---

## 🔴 BEFORE `ORDER-1302`: its premise is wrong, and so was the advice given on it

`ORDER-1302`'s row says expanding the grid *"means editing a `safe_range`… widening it widens a
safety declaration"*, and a recommendation was made to the owner on that basis to treat a boundary
as a **finding** rather than a re-run. **Both are wrong. Do not act on either.** The correction was
made before the owner ratified anything, and it is written here so the next reader does not
re-derive the same mistake.

**What `safe_range` actually is** — `_triage/factory_os/hypothesis_b14.py:151`, in its own words:

> 🔴 *WHAT A `safe_range` IS AND IS NOT. It is the **PRE-REGISTERED STARTING GRID** for a sweep — the
> span it is safe to explore — **not a measured optimum and not a claim that the answer is inside
> it**. `backtest-optimize-rigor` and memory `grid-answer-outside-the-grid` both require the grid to
> be EXPANDED when a result lands on a boundary, **so a bound here is the start of that procedure,
> never the end of it**.*

**Ratifying "boundary = finding" would have contradicted four separate places at once:**

1. **design §6.3** — *"Best result on a grid boundary ⇒ **expand the range and re-run** (decision 19),
   refuse to close the cell."*
2. **decision 19** itself, which §6.3 cites.
3. the skill **`backtest-optimize-rigor`**.
4. memory **`grid-answer-outside-the-grid`** — *เห็น monotone ถึงขอบ ⇒ ขยายกริดก่อนสรุป*.

It would also have created the identical debt `ORDER-1300` is still carrying: a ratified rule whose
design text says the opposite, which the next reader re-opens.

**And the blast radius is smaller than the row implies:** these ranges live in `hypothesis_b14.py`,
scoped to the B14 pilot hypotheses. Widening them does **not** loosen anything for any other EA.

### What actually needs the owner on `ORDER-1302` — measured, not the question that was asked

14 cells, **32 boundary hits**, and the direction matters:

| dimension | hits | declared grid | note |
|---|---|---|---|
| `_14_DistAtrMult` | 8 | 0.5 · 0.25 · 3.0 | |
| `_9_StepATRmult` | 7 | 0.5 · 0.25 · 3.0 | ⚠️ **down = tighter grid = more positions** |
| `_2_BasketTP_BalPct` | 6 | 0.5 · 0.5 · 5.0 | ⚠️ **down = TP sooner = more baskets** |
| `_0_ATR_Period` | 5 | 7 · 7 · 28 | |
| `_22_TP_ATRmult` | 4 | 1.0 · 0.5 · 6.0 | |
| `_14_MinDistPips` | 1 | 5 · 5 · 50 | |
| `_H_Ratio` | 1 | **`None` — no declared range at all** | |

**23 of the 32 hits are at the LOW edge (`first`), 9 at the high edge (`last`).** So the honest
question is not *"finding or re-run"* — that is already answered — it is:

> 👤 **How far down do we widen, given that for `_9_StepATRmult` and `_2_BasketTP_BalPct` "further
> down" means a tighter grid and faster take-profit, i.e. MORE positions and deeper martingale
> exposure on an ENGINE-EDGE class?** A floor has to be pre-registered before the sweep, or the
> expansion becomes a search for leverage (memory `pyramid-depth-is-leverage-not-edge`).

🚫 Do not pick that floor from the seat, and 🚫 do not widen only the dimensions that are cheap to
widen — the row already prohibits that and it is still correct.

**Correct `ORDER-1302`'s premise on the board before anyone plans work from it.**

---

## Still open and unchanged from S13G

- 👤 **The 49-trade question on `B14-H02-r1`** — clears every numeric bar (MAIN M4 `4.63` · BWD M4
  `1.20` after financing) on **49 BWD trades across three years**, DD `15.22 %` vs a 12 % limit,
  **100 % LONG in all four runs**. `CLAUDE.md`'s un-numbered `PENDING-RATIFY(user)` case. **No
  verdict was issued and none may be.**
- **`ORDER-1330`** — the same configuration produced different money on two different days while
  every recorded identity field matched. Not run-to-run noise. `B14-H02-r1`'s BWD margin of `1.20`
  sits close enough to the `1.0` hard gate for this to matter.
- **`ORDER-1301`** — now has its sharpest evidence: PF 1,126 on **5.38** of realised loss against
  **1,304** of financing the tester never charges.
- **`ORDER-1274`** — the fine half of the ladder, 20-30 h of tester time, blocked on the plateau.
  ⚠️ Note the interaction: while 14 cells stay `BOUNDARY` they have no plateau, so `ORDER-1274`
  can currently only run on the **two** SELECTED cells. Its cost estimate assumes 16.

## Baseline before you touch anything

`run_fast_cages.ps1 -Hook` (**29 suites, 0 failed, 97.9s of the pinned 120.0s**) · `run_s13_tests.ps1`
· `run_selection_tests.ps1` · `run_optimize_guard_tests.ps1` · `run_schema_cages.ps1` ·
`check_state.ps1` · `_triage/factory_os/run_s2a_gate.py`.
⚠️ **Do not quote a tier number from a run whose transcript says the index moved** — a concurrent
lane committing produces phantom failures.
⚠️ **A green tier measured before your new files are tracked is not the tier you are shipping:**
`run_guard_trigger_tests` only fires on TRACKED paths, so committing a tool is what arms the check on
its caller.

**Re-derive your order block from BOTH tests.** At close: highest `## ORDER-<n>` across all four
board files = **1330**; highest block reserved = **1330-1339**. **Commit the reservation first.**

## Do NOT do in this session

- 🚫 Ratify "boundary = finding" · 🚫 widen any `safe_range` before the floor question is answered ·
  🚫 widen only the cheap dimensions.
- 🚫 Issue a verdict for either cell from automation · 🚫 quote any **Model-1** PF as a quality
  number · 🚫 quote a crypto number with financing not deducted · 🚫 set a participation floor
  without the owner.
- 🚫 Mark a stub implemented while leaving it in the not-implemented list · 🚫 make a checker PASS by
  weakening what it asks.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 hand-edit any generated store under `factory/` (all now have
  a `--check`) · 🚫 touch `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any
  `check_s2a_attestation.py:BUNDLE` member · any `.set` migration · any magic renumber.

Open with: **"อ่านไฟล์นี้ แล้วเริ่มที่ ORDER-1256 ต่อด้วย 1255 — แก้ premise ของ ORDER-1302 บนบอร์ดก่อน แล้วอย่าเพิ่งแตะ MT5"**
