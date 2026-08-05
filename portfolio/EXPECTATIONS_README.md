# portfolio/expectations.csv — pre-registered expectation baseline

## Purpose

`expectations.csv` captures, **at (or shortly after) attach time**, the backtest/validation numbers a
deployed EA was actually judged on — one row per magic in `portfolio/DEPLOYMENTS.csv`. It exists so that
a later live-vs-expected comparison (PQ-03, once unlocked) is measured against a number that was written
down *before* live results came in, not reconstructed afterward from memory or from whichever backtest
looks best in hindsight. A number recorded after seeing live P&L is not an "expectation" — it is
hindsight dressed up as one, and this file must never be allowed to become that.

This is a **data-capture order only** (ORDER-153). It does not implement any flagging, alert, kill, or
probation logic — that is PQ-03's other half and stays LOCKED until judge day (fastest 2026-09-22) or a
portfolio #1 goes live, whichever the user unlocks first.

## Rule: no DEPLOYMENTS row goes ACTIVE without an expectations row

From now on, before a `portfolio/DEPLOYMENTS.csv` row is marked `ACTIVE`, a matching row must already
exist in `expectations.csv` (even if every metric field in it is `UNKNOWN` — an honest UNKNOWN row still
satisfies the rule; a missing row does not). Pre-existing ACTIVE/REMOVED/PENDING_ATTACH rows as of
2026-07-23 are **grandfathered** — they are all listed below, backfilled from whatever real evidence
could be found and cited, with `UNKNOWN` written wherever no cited number exists. Rows with
`status=UNVERIFIED` or a blank `magic` in DEPLOYMENTS.csv get an expectations row with every metric field
`UNKNOWN` and `source_evidence=UNVERIFIED_ROW` — there is nothing to pre-register for an EA that hasn't
even been magic-enumerated yet.

## Coverage summary (as of 2026-07-23, backfill pass)

- **48 rows total** (one per DEPLOYMENTS.csv data row, including REMOVED/PENDING_ATTACH/UNVERIFIED).
- **45 rows have a real, cited `pf_expected`** (a genuine backtest/validation number, not invented).
- **3 rows are `UNVERIFIED_ROW`** (blank magic in DEPLOYMENTS.csv, all metric fields `UNKNOWN`):
  - `159475669` — unenumerated user EAs (LondonConso/GoldReaper/MatchaGrid/BRK-XAU)
  - `69424711` — ClevrFX_EA (magic unknown, Trial8 investor login failing)
  - `146237` — unenumerated user EAs (~10, Exness demo user pool)
- **`trades_per_month_expected`**: 24 of 48 rows have a derived value (both a trade count AND a window
  length were explicitly stated in the source — e.g. "~100/yr" or "280t over MAIN 2023.01-2025.12"). The
  other 24 are `UNKNOWN` because the source cited a PF/trade-count without a paired window length, and
  guessing the window would be exactly the kind of invented number rule 1 forbids.
- **`dd95_expected`**: only **5 of 48 rows** have a real value — this field is held to a strict reading
  (an actual MC-derived 95th-percentile drawdown, explicitly labeled as such in the source), not just
  "whatever drawdown number was lying around." Many rows have a *backtest max-DD* or *MC PF_5th* cited
  instead — those are different metrics from a DD95 and were **deliberately left `UNKNOWN`** rather than
  substituted in (see the temptation log in the closing session report). The 5 with a real DD95:
  `990067`/`990066` (IchiADX USDJPY basket, 10.77%), `990068`/`990069` (IchiADX XAU basket, 22.19%),
  `990984` (PairSpread, 19.65% bootstrap), `992004` (TrendRider XAU, 4.15).
- Several rows are **combined-basket figures, not separable per single magic** (flagged explicitly in
  `pf_expected` and `source_evidence`): IchiADX USDJPY basket (990066+990067), IchiADX XAU basket
  (990068+990069), and Gold_Kangaroo L1-L4 (1112-1115, one EA spawning 4 magic streams from
  `MagicStart=1111` — the evidence has no per-leg split, only the combined 4-stream total).

## TWO COMPETING BAND FORMULAS — UNRESOLVED

Found during this inventory pass, recorded here verbatim per ORDER-153's instruction. **This is a
record of a conflict, not a resolution — do not pick a winner in this file or in any code.** The choice
belongs to Claude/user when PQ-03's flagging/kill-band half is unlocked.

**Formula A — `ea-live-monitor/SKILL.md` (embedded as prose in the skill, not code):**
- `ALERT_PF = BT_PF × 0.7`
- `ALERT_DD = BT_DD × 1.2`
- `ALERT_CONSEC = BT_consec + 2`
- `ALERT_FREQ = BT_freq × 0.5`
- plus a KEEP/WATCH/PAUSE/KILL ladder built on those four thresholds.

**Formula B — `AGENT_TASKBOARD_PQUANT.md` PQ-03:**
- PF ratio normal band: **[0.6, 1.8]**
- rate (frequency) band: **[0.5, 2.0]**
- 🔴 red trigger: PF ratio **< 0.6** at **≥ 20 trades**

PQ-03 explicitly states its own intent as *"นิยามเดียวกับ runbook §2.1 เพื่อไม่ให้มีสองสูตร"* ("same
definition as runbook §2.1, so there is only one formula") — but as of this inventory, **there are
actually two formulas live in the repo, and they do not match** (e.g. formula A's `ALERT_PF = BT_PF×0.7`
is a single 0.7 floor with no upper band, while formula B is a two-sided `[0.6, 1.8]` band with a
separate ≥20-trade sample-size gate). Nothing in this order resolves that conflict — it is logged here
so it isn't silently rediscovered later, and left untouched until PQ-03 is unlocked.
