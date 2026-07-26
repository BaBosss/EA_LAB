# HANDOFF 2026-07-25C — evidence-integrity sweep (ORDER-203..222)

**Start here next session.** One-line summary: **nothing needed to be pulled off a real account,
but a lot of labels were wrong, and the machine had already written down several of the reasons.**

Seat: Opus. Ten orders closed, six raised. No real-money change made. No holdout spent.

---

## 1. The two things the user must decide (nothing else is blocked on them)

1. 🔴 **`EA_BREAKOUT_XAU` 991001 — remove the v3 config, keep v2.** The user reported both are
   installed. Running both is not diversification: same EA, same symbol, same TF, correlation ≈ 1,
   so it is double size on one edge. v2 (`_01_BreakoutBars=40`) is what clean evidence supports —
   Model-4 MAIN 1.98 / BWD 1.66 versus v3's 1.86 / **1.01**. A clean re-optimize (ORDER-210) then
   failed to find anything beating v2 on both windows, so v3 has no support left from any
   direction. Not urgent: v3 is not losing, it is unsupported.
2. 🟡 **MacroGate leg 990120 (demo) — keep, move, or drop.** Its "VALIDATED" standing was
   withdrawn today. If the gate is worth continuing to test, **move it to AUDJPY**: the timing
   value is real there and absent on USDJPY, which is what 990120 runs.

Still open from the previous handoff, untouched by this session: CR-P0 sensor `463666728` +
create `69424711`, Telegram token into `scripts/config.yaml`, currency confirmation on
`463666728`, and verifying which staged bundles are actually on a chart.

## 2. Ready to attach — read its README first

`_vps_deploy/BOSS16_KANGAROO_XAU/` — bundle built today (ORDER-213). The edge is real: clean
MAIN 1.46 / 205t, BWD 1.30 / 278t, both bars cleared comfortably.

**Three things the README pre-registers, all of which came out of this session:**
- **Verify the SHA256 before dragging it on a chart.** `ea_template/`'s copy was stale and did not
  contain `_16_BaseLotMode` at all — attaching it with the scaled `.set` would have run flat mode
  while looking balance-scaled.
- **Judge date = attach + 5.5 months, not 3.** At 5.7 trades/month, 30 trades needs ~5.3 months;
  a 3-month judge cannot clear the trade bar however well it performs.
- **Expected PF 1.46, not 1.57**; ~68 trades/yr, not ~81–90.
- Start at a **$10,000** balance or the scaled-vs-flat comparison is broken from the first trade.

Unresolved and deliberately not guessed: `EA_MASTER_INDEX` records this EA's home as **D1**; the
attach candidate and its evidence are **H1** (ORDER-077/078). D1 was a separate funnel that closed
no-edge. Ask before attaching D1.

## 3. What changed in the written record (no EA was moved)

| order | outcome |
|---|---|
| 203 | MRIS `AUDJPY user_pin` fixed — pin is advisory again, `-2` needs two relative conditions. calm-2019 88% → 47% risk-off. Live state byte-identical. |
| 204 | Genetic retro-audit: **fine-stage exists for only 10 of 66** genetic runs, fan for 5. |
| 210 | BRK_XAU clean re-optimize: challenger beats v2 on MAIN, loses BWD → **v2 stays**. |
| 211 | MacroGate **VALIDATED → advisory-only**. PF falls in all four cells on a correct timeline. |
| 212 | NuiIndy `CutLoss=30` provenance **CLEAN** — but see §4, the evidence proves something else. |
| 213 | Boss_16 bundle + corrected bars; **stale binary caught**. |
| 214 | Gold Reaper `CORE` → `REJECT` (user-mix, lab does not certify). |
| 215 | MatchaGrid `CORE` → `PARKED-VERIFY`; part 2 (re-measure) still OPEN. |
| 216 | MacdDiv "passed every stage" → `PARKED-VERIFY`; its plateau was counted on dead axes. |
| 217 | Signal-line lever built, works, **not deployed** — recorded in EDGE_CATALOG. |
| 218 | Error sweep — the detectors had been writing warnings nobody read. |

## 4. The three findings worth carrying forward

**(a) A verdict is only as safe as the input it was measured through.** MacroGate passed on a
regime timeline built by a broken classifier. When ORDER-203 fixed the classifier, the verdict
had to be re-opened — and it reversed. *Rule: when you fix a data or signal layer, immediately
sweep for verdicts that consumed it. Do not wait to be asked.*

**(b) An inert parameter manufactures a perfectly flat fake plateau.** MacdDiv's celebrated
"plateau, 9 neighbours, no losers" was counted across three axes that do nothing at the deployed
values — one of them (`_02_MacdSignal`) structurally dead in the source. Neighbours on a dead axis
return identical numbers, so "no losers" was true by construction. Gold Reaper has the same shape
(`StartLots` overridden by an internal risk mode). *Rule: probe every axis for inertness before
building a fine grid, and probe outside the deployed range — some axes are inert only in a band.*

**(c) The system detects things nobody reads.** The truncation detector flagged the Boss_16
lot-mode cage on 24 Jul; the bundle was assembled on 25 Jul with that file sitting on disk. The
detector even discards its own explanation (`detail: ""`). ORDER-219 wires a digest into the daily
chain.

**And a sharp instance of (c) worth its own line — ORDER-212.** The provenance came back clean,
but the two runs behind `CutLoss=30` peaked at **15.4% and 16.6% drawdown against a 30%
threshold**, so the kill never fired in either. The numbers show the switch *costs nothing*;
they show nothing about whether it *works*. On an uncapped-ruin martingale running real money,
where CutLoss is the only thing between it and a wipeout, that gap matters. ORDER-222 tests it.

## 5. Queue, in the order I would run it

| order | what | why this order |
|---|---|---|
| **219** | make the detectors readable (digest into daily chain, fill `detail`, fix `check_state` §7) | cheap, and everything else benefits from it working |
| **222** | prove NuiIndy's `CutLoss=30` actually cuts | real money, untested guardrail |
| **221** | stale-binary detector across the 4 directories holding `.ex5` | 3 instances found in one day; `.ex5` is gitignored so the repo is blind to it |
| **220** | re-run `MMLOT_E_unit_indep` at a size that does not trip the kill | closes the Boss_16 cage caveat before or during its demo |
| **215 part 2** | MatchaGrid clean-MAIN + fan + flat-lot probe + Model-4 | heavy M4 queue; real money but not urgent |

Two campaigns remain untouched and are lower priority than any of the above: ORDER-095 (symbol
expansion) and ORDER-098 (fxDreema corpus).

## 6. Operational notes for whoever picks this up

- **Model-4 is memory-blocked above ~18 months** on this box. ORDER-210 worked around it by
  splitting into sub-windows and merging deal CSVs — legitimate, but it means those trade counts
  are not strictly comparable to a continuous run. Say so whenever you use that method.
- **The working tree is shared.** This session lost a commit to another session's broad `git add`,
  hit `cannot lock ref HEAD` once, and had to renumber orders 205–208 → 210–213 after a collision.
  Always `git add` explicit paths; check `git log -1` before assuming HEAD is yours.
- **The scorecard↔index pre-commit pairing is correct and will block you** if only one of the two
  genuinely changed. Three EAs turned out to have no `EA_MASTER_INDEX` row at all
  (`EA_BREAKOUT_XAU` XAU H1, Gold Reaper, MatchaGrid) and Boss_16 had no scorecard row — filling
  those gaps was how the block got satisfied honestly rather than with filler edits.
- **`check_state` §7 false-positives on ordinary Thai prose.** It fired three times today,
  including on the report describing the bug. Workaround until ORDER-219: hyphenate the phrase.
