---
name: ea-live-monitor
description: >
  Monitor a LIVE multi-EA portfolio after deployment — parse MT5 account
  history by magic number into per-EA P&L, compare live performance vs the
  backtest expectation, flag underperformers against kill-switch criteria, and
  produce the keep/kill judgment report. Use when the user wants to check how
  the live EAs are doing, attribute account P&L to individual EAs, run a
  monthly/judge-date review, or decide whether to keep, pause, or remove a
  deployed EA. Trigger on /ea-monitor and whenever reviewing live trading
  results.
---

# EA Live Monitor

After deployment the pipeline goes quiet — but a live portfolio still needs a verdict. MT5 reports **combined account P&L only**; every trade carries a magic number, so per-EA attribution is recoverable. This skill turns raw account history into a per-EA scorecard, compares it against what the backtest promised, and issues **KEEP / WATCH / PAUSE / KILL** per EA.

## Core stance
- **The account number lies; the magic number tells the truth.** Never judge an EA by the account equity curve — isolate its own trades by magic number first.
- **Live underperformance vs backtest is expected; the question is how much.** A live PF that is 0.7× the backtest PF is normal noise on a small sample. 0.3× or negative on a meaningful sample is a real signal.
- **Sample size gates every verdict.** < 10 live trades on an EA = INCONCLUSIVE, never KILL. State the trade count beside every metric.
- **One bad month ≠ kill.** Judge against the EA's own backtest max-consecutive-loss and max-DD, not against a flat "it's losing" reaction.

---

## The current live portfolio (as of 2026-06-22 deploy)

8 EAs on ONE 10,000-cent account. Judge date: **2026-09-22** (3-month forward review). Magic numbers are the attribution keys:

| # | EA | Symbol/TF | Magic | Backtest OOS PF | Notes |
|---|---|---|---|---|---|
| 1 | MG_v1_locked | CHFJPY M15 | (read .set) | 2.08 | Core |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | (read .set) | 2.00 | Core |
| 3 | ST_EA03 MACD | GBPUSD H1 | (read .set) | 2.47 | Lots_div=100k |
| 4 | ST_EA03 MACD | USDCAD H1 | (read .set) | 2.62 | Lots_div=100k |
| 5 | Gold Reaper 4.3 | XAUUSD H1 | (read .set) | 2.07 | ruin 1.9% |
| 6 | EA_BREAKOUT_XAU | XAUUSD H1 | **991001** | 1.77 M4 | Candidate |
| 7 | LondonConsoBreakout | GBPUSD H1 | **990005** | 2.08 | Candidate |
| 8 | LondonConsoBreakout | EURUSD H1 | **990005** | 1.25 | Conditional ⚠️ |

Magics #6–#8 verified from the live `.set` files in `_vps_deploy/`. #1–#5 live elsewhere — read their magic from the locked `.set` before the first run and fill them in here.

⚠️ **Magic collision (verified):** EA #7 and #8 share magic **990005** (same binary, different symbol — the `.set` comment even notes it: "EA filters by _Symbol internally"). ST_EA03 (#3,#4) is the same binary on two symbols → likely also one shared magic. Attribution MUST group by the **(magic, symbol)** pair, never magic alone, or their P&L merges into one number.

---

## The workflow (in order)

### Step 1 — Get per-deal data WITH magic **[critical — verify the source first]**
The whole skill depends on deal records carrying the **magic number**. The plain MT5 account **Report (HTML/XLSX) export does NOT reliably include magic per deal** — do not assume it does. Two reliable sources, in preference order:

1. **MT5 script via the HistoryDeal API (preferred — built & tested).** Run **`D:\EA_LAB\scripts\report_deals.mq5`** on the live/VPS terminal: copy it into `<DataDir>\MQL5\Scripts\`, refresh the Navigator, drag onto any chart, set `InpFromDate` = deploy date (2026.06.22), run. It walks the deal history via `HistoryDealGetInteger(t, DEAL_MAGIC)` — the field the HTML export drops — and writes `live_deals.csv` to the **Common\Files** folder (full path printed to the Experts log). Columns: `time,ticket,magic,symbol,type,entry,volume,price,profit,swap,commission,net,comment`. This is the canonical input.
2. **HTML/XLSX export fallback — only if it actually shows magic.** Inspect one exported file first: if the Deals table has a magic/comment column, parse it; if not, use source #1. (`extract_deals.py` parses the *Tester* Deals table but emits only `time,profit` — **no magic** — so it does NOT solve attribution; not a drop-in. No Python on this box anyway.)

> Both tools exist and are tested: `report_deals.mq5` (export) + **`parse_live_deals.ps1`** (roll-up by magic,symbol) in `D:\EA_LAB\scripts\`. Verified the (magic,symbol) split correctly separates CB_GBP/CB_EUR which share magic 990005.

**If no magic source is available at all:** fall back to grouping by **(symbol, comment-prefix)** — but flag that two EAs on the same symbol (e.g. both XAU EAs #5 and #6) cannot be separated without magic, so report them as a combined bucket and say so.

### Step 2 — Attribute by (magic, symbol) **[Q runs / C reads]**
Run **`parse_live_deals.ps1 -Path <Common\Files\live_deals.csv> [-Csv out.csv]`** — it filters realized (OUT/INOUT) deals, groups by `(magic, symbol)`, and prints/exports per group:
- **net profit** (incl. swap+commission), **trade count**
- **live PF** = gross_profit ÷ |gross_loss| (shows `Inf` if no losers yet)
- **win%**, **avg win : avg loss**, **max consecutive losses**, **realized DD** (running peak-to-trough of the group's own equity)

Balance/deposit/correction deals are reported separately and excluded from per-EA P&L. Delegate the run to qwen (`claude-9arm`); verify the deal count matches the export and that an un-mapped magic (manual trade / not-in-table EA) is listed, not silently dropped.

### Step 3 — Compare live vs backtest expectation **[C judgment]**
For each EA build the comparison row:

| metric | backtest | live | ratio | flag |
|---|---|---|---|---|
| PF | OOS PF | live PF | live÷BT | <0.5 ⚠ |
| trades/month | BT freq | live freq | | <0.5× ⚠ (signal not firing) |
| max DD | BT maxDD | live realized DD | | >1.2× ⚠ |
| max consec loss | BT | live | | BT+2 exceeded ⚠ |

⚠️ **Do NOT hardcode decision numbers into this skill.** The bars below MUST be read from their canonical
owners at run time. This skill previously carried its own copies (`ALERT_PF = BT_PF × 0.7`, PAUSE @25t,
KILL @40t) which had silently drifted away from the ratified criteria — see
`D:\EA_LAB\_triage\ORDER169_JUDGE_CRITERIA_RECONCILIATION.md` (2026-07-23) for the full drift map.
Copying numbers here is what caused the drift; read them instead.

**Read these two, every run, before judging anything:**
1. `D:\EA_LAB\docs\JUDGE_DAY_RUNBOOK.md` §2 (absolute-PF ladder) and §2.1 (tracking-error ratios)
2. `D:\EA_LAB\CLAUDE.md` VERDICT GATE bar table (demo-kill + demo→LIVE bars)

**Both axes must be evaluated — they are independent and an EA can fail either:**
- **Absolute PF** (runbook §2) — the primary decision ladder. An EA can sit inside its tracking-error
  band and still be an outright kill on absolute PF; the reverse also happens. Never skip this axis.
- **Tracking-error ratios** (runbook §2.1) — `PF_live / PF_expected` and the trade-rate ratio, which
  answer "is it behaving as validated", not "is it profitable". Expectations come from
  `D:\EA_LAB\portfolio\expectations.csv` (pre-registered at attach; `UNKNOWN` there means the ratio
  axis genuinely cannot be evaluated for that magic — say so, don't substitute a guess).

⚠️ **Unresolved and awaiting the owner's decision (do not pick one yourself):** `CLAUDE.md`'s demo-kill
bar and the runbook §2 kill bar use different numbers at different trade counts. They may be
deliberately different stages (in-flight demo vs judge-day) or an unreconciled duplicate. If a given EA
falls between them, report both readings explicitly and flag the ambiguity rather than resolving it.

The supplementary alerts below are additive to the above and are NOT in conflict with any canonical
source, so they stay defined here: ALERT_DD = BT_DD × 1.2, ALERT_CONSEC = BT_consec + 2,
ALERT_FREQ = BT_freq × 0.5 (mirrors `live-deployment-controller` SECTION 4).

### Step 4 — Per-EA verdict **[C judgment]**
Apply the canonical ladders read above. Structure the call as:
```
KEEP   : passes the runbook §2 absolute ladder AND inside the §2.1 ratio bands AND no supplementary
         alert breached — OR sample below the runbook's trade-count gate and not catastrophic
WATCH  : one axis breached but sample still under the canonical trade-count gate — keep running,
         re-check next cycle
PAUSE  : a canonical bar breached on a qualifying sample, OR realized DD > 1.2× BT maxDD
         → SOFT kill-switch (live-deployment-controller KS-5/KS-6)
KILL   : the runbook §2 kill condition is met on a qualifying sample with no regime explanation
         → remove from portfolio
```
Always state which axis triggered (absolute vs ratio vs supplementary alert) and the trade count —
"PAUSE" without naming the breached bar and its sample size is not an actionable verdict.
- Always pair the verdict with the **trade count** and a one-line mechanism ("CB_EUR was the conditional one — OOS2 already failed, so a live PF dip is consistent with the known weakness, not a surprise").
- **Frequency alert is special:** an EA placing far fewer trades than expected may be silently mis-configured (cent lot below min → 0 fills, tester-gate, wrong session hours), NOT a losing edge. Check config before judging edge. See [[live-deployment-controller]] cent-account pitfall.

### Step 5 — Portfolio roll-up & judge report **[C]**
- Combined live P&L, combined realized DD vs portfolio expected DD (`portfolio-selector` output).
- Symbol concentration check (>80% exposure single symbol → flag).
- For the **judge-date review (2026-09-22)**: produce the keep/kill table, note which EAs graduate from Candidate→Core, which get removed, and whether portfolio composition should be re-run through `portfolio-selector`.

---

## Delegation map (save tokens)
| Delegate to **qwen [Q]** | Keep in **Claude [C]** |
|---|---|
| Run `report_deals.mq5` → deals CSV, roll up by (magic,symbol) | Verify the magic source actually carries magic |
| Sum profit / count / win% per group | Decide verdict per EA |
| Run `parse_live_deals.ps1`, return CSV path | Judge live-vs-backtest ratio significance; freq-anomaly (config vs edge) |
| | Portfolio roll-up + judge report |

Verify qwen's CSV: row count = closed deals, every deal mapped to one EA, no group silently dropped.

## Connection to other skills
- Alert thresholds & kill-switches: **live-deployment-controller** (SECTION 4 & 5 — reuse, don't reinvent).
- If an EA is KILLed or PAUSEd and a replacement is sought: back to **portfolio-selector** to re-weight, or **signal-scanner** for a fresh candidate.
- A KEEP that graduates Candidate→Core may warrant a fresh **robustness-validator** pass on the accumulated live trades.

## One-line reminders
- Get magic from the HistoryDeal API (DEAL_MAGIC), NOT the HTML export — the export drops it.
- Group by (magic, symbol) — never magic alone (990005 collision).
- < 10 trades = INCONCLUSIVE; never kill on a thin sample.
- Low frequency = check config (cent lot / tester-gate / hours) BEFORE blaming the edge.
- Use live-deployment-controller's alert thresholds; don't invent new ones.
- Pair every verdict with trade count + a one-line mechanism.

## FINAL RULE
```
NEXT STEP:
Per-EA verdicts issued above.
KEEP → continue monitoring; re-check at next cycle / judge date.
PAUSE/KILL → disable in MT5, then return to portfolio-selector to re-weight
             or signal-scanner for a replacement candidate.
```
