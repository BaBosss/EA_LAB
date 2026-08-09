# OPENING PROMPT — the operator session (paste this whole file as the first message)

> Written 2026-08-02 by `S-2026-08-02-OPENER` at the user's request, closing the
> `TEMPLATE` → `CONSTFP` → `SCRUT730` run of lanes.
>
> **Why this session is different from the last four.** Those were seat-only: read the repo, write
> code, run cages, close orders. Everything they could finish alone **is** finished. What is left
> is blocked on one thing the seat cannot supply — **you, at a terminal**. Three of the four items
> below need a human to open a window and read a number; the fourth needs a human to make a call
> about money-shaped tradeoffs. **If you are not able to sit at MT5 for ~30 minutes, open the
> Factory OS session instead (`_triage/PROMPT_NEXT_SESSION_FACTORY_S7_S8.md`) — it is seat-only
> and will not waste the trip.**

---

## Read first, in this order

1. `_triage/HANDOFF_2026-08-02_CONSTFP.md` — the shift-change note this session continues from
2. `PROJECT_STATE.md` — §0.5 anti-drift, §2 (the two newest entries are `ORDER-710`/`ORDER-730`), §3 decision log
3. `CLAUDE.md` — the VERDICT GATE. No EA verdict is due in this session, but the guard clause is:
   **a guard reported without a fire count is `UNTESTED` and must not be written up as passed**
4. `docs/SESSION_LEDGER.md` — reserve a lane and **commit that row** before touching anything
5. The four items below, on `AGENT_TASKBOARD.md`

## Reserve like this

- One lane, one order block of 10 — parse `## ORDER-<n>` out of **all four** board files yourself;
  the ledger's foot-of-page summary has been repaired by hand ten times and is not evidence.
  Blocks up to **999** are spoken for as of 2026-08-02.
- **`owns paths` must name `portfolio/DEPLOYMENTS.csv` if item 2 changes a row**, plus the specific
  board rows. 🚫 Never `MASTER_BACKLOG.md` §2, `s2a_attestations.jsonl`, `AGENTS.md`, or any S2a
  bundle member.
- **Declare the MT5 lane only if you actually run the tester.** Items 1-3 need a *terminal*, which
  is not the same thing as a tester lane.

---

## The work, in the order it should be done

### 1. 🔴 `ORDER-510` STEP 2 — the F3 census, and it is the one item with real money behind it

**Four accounts have never been checked, and three of them are `REAL_CENT`.** The one account that
*has* been cleared is a demo. Until a census exists per terminal, **no `Boss_*.ex5` may be copied to
any chart** — a new binary meeting pre-132 state returns `INIT_FAILED`, and on screen that reads as
*"the EA is quiet"*, not as a refusal.

| account | type | template magics | status |
|---|---|---|---|
| `463666728` | DEMO | 14 | ✅ cleared 2026-07-28 |
| `415573666` | DEMO | 9 | 🔴 UNCHECKED ← **start here**, it is the cheap one |
| `141049900` | **REAL_CENT** | 4 | 🔴 UNCHECKED |
| `159475669` | **REAL_CENT** | 2 | 🔴 UNCHECKED |
| `159503454` | **REAL_CENT** | 1 | 🔴 UNCHECKED |

**Your part, per terminal:** Tools → Global Variables (**F3**) → save/copy the list to a text file.
Nothing else. It is read-only; do not delete anything.

**Then the seat runs one command per account:**

```bash
powershell -File scripts/check_persist_legacy.ps1 -GvDump census_415573666.txt -Account 415573666
```

`exit 0` = nothing fires the fail-closed gate · `exit 1` = at least one magic does, with the trigger
named · `exit 2` = the check could not be performed, **including a census that parsed nothing** —
that is refused rather than certified, because it is indistinguishable from a wrong path.

> ⚠️ **This checker has never run on real data. Its 30 green cases are all fixtures.** Treat the
> first real run as evidence about the checker as much as about the account: if it says something
> surprising, verify by eye against the F3 window before acting on it.
> The procedure it feeds is `_triage/ORDER510_ADOPT_ONCE_PROCEDURE.md` — **read §11 before STEP 2**,
> it corrects two things the original §6 got wrong about what the journal prints.

### 2. `ORDER-941` — four IchiADX legs at 0-1 trades against ~1/week expected

`990066` · `990067` · `990069` show **0 closed trades in 16 days**; `990068` shows 1 against ~2.3
expected. Three legs of one EA silent together is not thinness — it is the `990025`
`AllowLive=false` shape.

**Your part:** on each of the four charts, the Inputs tab — **`_06_AllowLive` and `_06_Magic`
first** (a wrong magic has *no symptom at all*). **Ask for one log export covering all four rather
than four screenshots** — memory `proving-a-set-was-loaded-on-a-chart`.

### 3. `ORDER-950` routes 2/3 — optional, and only if you want a SIGHTING

Route 1 is done: `SYMBOL_TRADE_STOPS_LEVEL=1 point` against a smallest buffered SL distance of
`0.919` = **91.86×**, so guard G4's minimum-distance branch is unreachable at the shipped buffer and
`sl_invalid=0` is *explained*. It is still `UNTESTED` — an explanation for why something never fires
is not a sighting. Route 2 (the BWD 2020-22 window, owed anyway) may contain the gap events the MAIN
window did not. **Route 3 is a labelled synthetic probe and must never be reported as evidence about
the deployed config.** Skip this item entirely if the other three fill the session.

### 4. `ORDER-761` — a DECISION, not a build. Do not start coding it

C1 is measured: the `GUARDED_INPUTS` mechanism would demand **102 new declarations** across the six
real suites. The order's own C2 says *if it lands near 66 again it has not solved anything*. It
landed **above**. Its premise — that declaring is cheaper than guessing because a text scan
over-counts — does not survive the number.

**The question for you:** is 102 more declarations, each widening the pathspec and pulling suites
onto more commits against a 90.0s tier budget, worth buying over the five hand-widenings it would
replace? The table and the measurement's stated limits are on the `ORDER-761` row.
**Answer this before any code is written**; discovering the number halfway through is how it
becomes sunk cost.

---

## Cage discipline (non-negotiable, unchanged)

- **`scripts/tpl_regression.ps1` after every `ea_template/core/**` edit**, on an explicitly pinned
  lane, binaries asserted fresh first. CLEAN 8/8 or the change does not land.
  <sub>⚠️ Older prompts say `scripts/_test/tpl_regression.ps1`. **That path does not exist.**</sub>
- Compile must be **0 errors / 0 warnings on 9 targets**.
- **Never report or decide from Model 2.** Model 1 minimum; Model 4 for anything fill-sensitive.
- An MT5 headless run without `-SetFile` may carry values from the previous run — always send a
  `.set` specifying **every** value (memory `mt5-tester-cache-nondeterminism`).
- A guard you add comes with **how many times it fired**. Zero fires = `UNTESTED`, written up as
  `UNTESTED`.

## Do NOT do in this session

- 🚫 Copy any `Boss_*.ex5` to the VPS before `ORDER-510` closes — **this is the whole point of item 1**
- 🚫 Delete a `Boss_<magic>_*` GlobalVariable to "make it pass". §7 of the procedure is the only
  route, and it needs your explicit approval per magic
- 🚫 Any `--no-verify`
- 🚫 Touch the S2a bundle, `MASTER_BACKLOG.md` §2, or `AGENTS.md` — each costs an owner signature
- 🚫 Start building `ORDER-761` before item 4 is answered
- 🚫 Issue an EA verdict — nothing here is a funnel decision

## Definition of done

Each item either **closed with its numbers stated**, or handed on with the exact next step and what
was measured. Then: ledger row `CLOSED`, `scripts/check_state.ps1` CLEAN, working tree clean of this
session's work, handoff written in `_triage/` with its `<!-- HANDOFF-ROUTING -->` table.

Open with: **"อ่านไฟล์นี้แล้วเริ่มจาก ORDER-510 STEP 2 — ผมอยู่หน้าเครื่อง MT5 แล้ว"**
(หรือถ้าเปิดเครื่องไม่ได้ตอนนี้: **"ยังไม่ได้อยู่หน้า MT5 — ขอทำข้อ 4 ก่อน"**)
