# HANDOFF — `S-2026-07-27-QUEUE` (block 430-439)

> Read `PROJECT_STATE.md` first, then this. **Do not trust this file over the repo** — if they disagree,
> trust the repo plus the pre-commit guards, then fix this file. That is the anti-drift system working.

**Session shape:** the user asked for a full survey of what is outstanding — taskboard, triage handoffs,
orders, and long batch work — because the token window was running low and the work needed planning
rather than doing. The output of the survey is the four sections below. Then the user picked four items
and this lane executed them. **No MT5 lane was used and no EA number was produced or judged in this
session.** Nothing here is a verdict.

---

## 1. What this lane actually did

**(a) Fixed the ledger summary that would have collided the next session** (`a37d0e7a`).
`docs/SESSION_LEDGER.md` still declared *highest used = 280, next block available = 420-429* while the
rows directly above it showed **412 · 420 · 421** already in use, and 420-429 belonged to CAGERUN. Those
two lines exist for exactly one purpose — telling the next session which block is safe — so a session
that trusted them, which is the intended behaviour, would have reserved a taken block and been blocked
by the collision hook on its first commit. Corrected to *max = 421, next = 440-449*, with the full block
list rebuilt from the rows.

**(b) Wrote two runnable orders so the cheap lanes have work** (`cc624318`) — see §2.

**(c) Filed `BACKLOG-D29`.** While fixing (a) I looked for other hand-maintained IDs and found that
`MASTER_BACKLOG.md` **has two different rows both numbered `D28`** — the slow-cages row (CAGERUN) and
the stale-citation row (DOCS-EN), written hours apart into the same table. Same family as the detector
bugs this repo has been collecting (ORDER-260 · 341 · 390 · 411 · D27), with one difference worth
naming: **those were parsers misreading correct data; these are correct parsers reading data a human
forgot to update.** A guard that only checks format passes both. Neither instance is fixed at the
mechanism level — (a) was corrected by hand, and the duplicate D28 still stands.

**(d) Dispatched the three queued Codex audits** — see §4. They are **in flight, not finished.**

---

## 2. The two new orders (both `OPEN`, both for oc-qwen / ZCode, neither started)

**`ORDER-430` — host search, unblocks ORDER-236.** ORDER-236's lever pair (`_9_RegimeGateAdds` +
`CONF_PA_ENGULF`) is built, caged and byte-identical when off, but has been `BLOCKED` since this morning
because the host it was aimed at measured **BWD 0.84** and the pre-registered gate stopped the run —
correctly, saving six Model-4 runs. ORDER-430 walks seven Boss_14 legs, **control runs only**, and
**runs BWD before MAIN** because BWD is the gate: a MAIN run on a host about to fail BWD is a wasted
Model-4 run. If no host qualifies, that is the answer to ORDER-236 — the lever has no home, park it.

> 🔴 **Finding made while writing that order, worth someone's attention:** `_9_RegimeGateAdds` is
> **absent from every Boss_14 `.set` on disk — including `B14_AB_off.set`, the file ORDER-236 used as its
> control.** MT5 fills an unlisted input from the per-terminal cache, not from the source default
> (memory `mt5-tester-cache-nondeterminism`). **Calibrating this honestly: the exposure is small.** The
> source defaults are `_9_RegimeGateAdds=false` and `_50_RegimeMode=0`, and `core/Inputs.mqh:179`
> documents the regime lever as inert unless `_50_RegimeMode != 0` — so the cache would have had to hold
> *both* at a non-default value for that control run to be contaminated. It is not zero either, and it
> costs four lines per file to close, so ORDER-430 STEP 0 pins all four values and checks them on the
> Inputs page **by value**. ORDER-236 checked that the input *names* appeared and stopped there, which is
> why the check now reads values. **I did not go back and re-verify ORDER-236's own CTRL report** — if
> anyone wants the 0.84 to be load-bearing, open its Inputs page and read the value.

**`ORDER-431` — optimize MacdDiv_Naked on USDJPY H4.** From ORDER-205 (REVIEWED, `BUILD-ON`): USDJPY came
back MAIN 1.08 / BWD 1.09 at n=250/221 — flat-looking numbers that are the most interesting result of
that order, because they stand above 1.0 in *both* regimes at large n. It has **never had a single axis
optimized**; all three JPY crosses were run on the XAU-tuned set. The order starts with the two
default-off entry-timing gates already built into the EA and never once exercised, then fans
`_01_SwingRadius` around its own centre. `_01_LookbackBars` is excluded — ORDER-204 proved it inert.
Both orders re-run their own baseline rather than quoting a prior number.

---

## 3. The survey — everything outstanding, grouped by who is actually blocking it

### 🔴 The real bottleneck is the user, not compute
Eight items are waiting on a human and nothing else. The SYSTEMS lane already said this outright and it
is still true. Ordered by unlock-per-minute-spent:

| item | what the user must do | why it matters |
|---|---|---|
| `ORDER-400` | one `/portable` login each for `463666728` (MT5) and `69424711` (MT4) | **two accounts are floating-BLIND right now**; closing this gives 6/6 |
| `ORDER-410` | read hash + mtime of the `.ex5` on 4 VPS terminals | 13 of 23 bundles are older than source; **no rebuild until this is done — some are attached to real money with open positions** |
| `ORDER-230` | open the `463666728` terminal, read cent-vs-USD | `base_equity` moved 10k→100k; guessing is forbidden |
| `ORDER-234` | walk the PERSIST_MIGRATION checklist | blocks Boss_14 GBPJPY going live; has floated across three handoffs |
| `ORDER-232` | decide MacroGate 990120: sensor / move to AUDJPY / remove | two contradictory recommendations on file |
| `ORDER-235` | ratify that the 30-trade bar is unusable for 4 EAs | it changes a number in the VERDICT GATE, so it needs explicit ratification, not drift |
| `ORDER-137` | fork: demo-isolate 991075 + try the ADX gate, or shelve | parked 8 days |
| — | 5 built bundles are `PENDING_ATTACH` | Boss_16 Kangaroo ×2 · TsMom 992001 · Wave5 XAU/XAG · MacdDiv XAU |

### 🟢 Long batch work, ready for a cheap lane
`ORDER-431` (ready) · `ORDER-430` (ready) · GEN-STANDING Matrix-2 cells #20 BRENT #21 NAS100 #22 DE40
#23 XAU H1 #24 US30 H1 (ready, largest single block on the board, one cell ≈ one session) ·
`ORDER-215` MatchaGrid funnel (heavy; closed-source, and Model-4 hits the memory ceiling so it must be
sub-windowed) · `ORDER-280` (still `CLAIMED` with **zero numbers** — a successor must restart at STEP 0
parity) · ORDER-141 AdaptGridMC (needs a real D1 CSV export first).

### 🟡 Evidence debt with no ticket — larger than it looks
- **`BACKLOG-D11`: PF-5th cannot fail under the current Monte Carlo.** Order-resampling leaves net and PF
  invariant, so every verdict that cited PF-5th cited a number that could not have moved. Only the DD
  and ruin columns were ever readable.
- **`BACKLOG-D8`: 1088 of 1540 correlation pairs are still at the default 1.0**, which systematically
  over-states portfolio risk.
- **`ORDER-231`: TsMom 992001 is registered at PF 3.72 but re-runs at 2.75** on the same 26 trades.
  Unreconciled.
- **`ORDER-373` cannot close**: 12 rows in `portfolio/DEPLOYMENTS.csv` still have an empty `kill_rule`.

### ⚪ Reading the older handoffs — three traps
`_triage/HANDOFF_2026-07-27_MONITORING_CR-P0.md`'s `§OPEN` list is contradicted by its own routing table
further down (its diagnosis of 463666728 is recorded there as wrong). `HANDOFF_2026-07-27_CUTLOSS_VERIFY.md`'s
ORDER-370 item was closed by the SYSTEMS lane. `HANDOFF_2026-07-27_GREENYELLOW.md`'s ORDER-206 fan became
ORDER-340 and is closed. **Reading any `§OPEN` section without its routing table produces stale work.**

---

## 4. Codex audits — dispatched, NOT collected

The queue in `_triage/CODEX_REVIEW_QUEUE_2026-07-25.md` had been waiting on ChatGPT quota since 07-25.
The user confirmed quota is back and all three were sent **blind** — each brief carries the mechanics and
the question, and deliberately withholds the Claude-side conclusion, so the second opinion stays
independent.

| # | subject | Codex task id |
|---|---|---|
| 1 | `portfolio_risk_admission.py` `--resolve-single-leg-baskets` (73.04% vs 38.36%) → `ORDER-233` | `task-ms3274w9-ojqwj2` |
| 2 | `ORDER-187` fail-closed first-lot sizing + Wave5 naked-order guard — **money path, mandatory** | `task-ms327ah8-0mtnut` |
| 3 | `ORDER-200` Phase A/C MRIS crisis models — gates Phase D | `task-ms327laa-b45mly` |

**Collect with `/codex:status <task-id>`.** They were dispatched at ~17:05 and **no result had come back
before this handoff was written — do not assume any of them passed.**

🔴 **Two rules that survive whatever Codex says:** the `--resolve-single-leg-baskets` default **must not
be flipped on Codex's word alone** (user ratification required, same precedent as ORDER-200 Phase D), and
ORDER-200 **Phase D stays gated** on this audit *plus* user ratification. An ACCEPT from Codex unblocks
the conversation, not the change.

---

## 5. Next session should start here

1. **Collect the three Codex tasks** in §4 before starting anything new. Judge them yourself — Codex
   produces evidence, not verdicts.
2. **Hand the user the §3 red table.** It is the highest-value thing in this document; ORDER-400 alone is
   about ten minutes of their time and un-blinds two accounts.
3. **Route `ORDER-430` and `ORDER-431` to oc-qwen or ZCode.** Both are self-contained with pre-registered
   bars, both need a free MT5 lane — 430 needs `D:\Meta 5b` (Model 4), 431 needs `D:\Meta 5c` (Model 1
   only; 5c has no tick cache).
4. `BACKLOG-D29` is a two-minute fix if the board is quiet: renumber one of the duplicate `D28` rows.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Host search that unblocks the caged lever pair | ORDER-430 |
| MacdDiv_Naked USDJPY H4 optimize | ORDER-431 |
| Lever A/B, still blocked until 430 finds a host | ORDER-236 |
| Codex audit 1 — single-leg-basket correlation resolution | ORDER-233 |
| Codex audit 2 — fail-closed first-lot sizing (money path) | ORDER-187 |
| Codex audit 3 — MRIS crisis models, gates Phase D | ORDER-200 |
| User: `/portable` logins for the two blind accounts | ORDER-400 |
| User: read VPS binary hash + mtime before any rebuild | ORDER-410 |
| User: cent-vs-USD on account 463666728 | ORDER-230 |
| User: MacroGate 990120 disposition | ORDER-232 |
| User: PERSIST_MIGRATION checklist | ORDER-234 |
| User: ratify the 30-trade bar exception | ORDER-235 |
| User: StoMultiTap demo-isolate or shelve | ORDER-137 |
| MatchaGrid re-measure funnel, still open | ORDER-215 |
| Tick-history divergence, still open | ORDER-371 |
| Hand-maintained IDs and summaries drift and collide | BACKLOG-D29 |
| Ledger summary corrected; two orders written; three Codex audits dispatched | DONE |
