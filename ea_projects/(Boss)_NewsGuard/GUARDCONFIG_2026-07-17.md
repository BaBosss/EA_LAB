# NewsGuard — Attach Config per Account (2026-07-17)

Paste-and-go runbook for attaching **(Boss)_NewsGuard** (ORDER-083). NewsGuard places **no trades of its own** — it only CLOSEs/BLOCKs the magics you list in `GuardConfig` around high-impact news. **Attach ONE chart per ACCOUNT** (any symbol/TF — it guards every listed magic across all symbols).

- **Source of truth:** `portfolio\DEPLOYMENTS.csv`. Every magic below was verified against it on 2026-07-17.
- **GuardConfig format:** `"magic:C;magic:B;magic:N"` — `C`=CLOSE_ALL, `B`=BLOCK_NEW, `N`=NONE.
- Accounts NOT listed here get NO NewsGuard (see §4).

---

## Shared inputs (same on every account)

Set these once per attach; only `GuardConfig` differs per account.

| Input | Value | Note |
|---|---|---|
| `PreNewsMin` | `30` | default — window opens 30 min before event |
| `PostNewsMin` | `15` | default — window closes 15 min after event |
| `NewsFile` | `EA_LAB_news_week.csv` | default; copied to Common\Files daily by `scripts\daily_monitor.ps1` |
| `UseCommonFiles` | `true` | read from Terminal\Common\Files (daily-chain target) |
| `AutoDetectServerOffset` | `true` | derive offset from TimeGMT |
| `ServerToBkkOffsetHours` | `4` | manual fallback (only used if AutoDetect off) |

**Offset check (quoted from the EA header — do not invent a new method):**
> ServerToBkkOffsetHours: Bangkok = server + N hours. How to check: open Market Watch, compare its clock to a Bangkok clock; N = Bkk hour - server hour. Exness MT5 is usually UTC+3 (summer) -> N = 4; UTC+2 (winter) -> N = 5. Re-check after US/EU DST switches.

AutoDetect is on, so `ServerToBkkOffsetHours` is only a fallback — leave it at `4` and re-check per the header if AutoDetect is ever turned off.

---

## 1. Account 141049900 — "01. Celestial Woodfire" (REAL_CENT, MT4)

- **Attach:** `(Boss)_NewsGuard_MT4.ex4`
- **Policy:** CLOSE_ALL — no-SL grid + not-validated capped-martingale basket; realizing a small floating loss beats a news-spike blowout.

```
7777:C;1112:C;1113:C;1114:C;1115:C
```

| magic | EA | symbol | policy | reason |
|---|---|---|---|---|
| 7777 | Zeus Gold Hedge V1.2_fix | EURUSDc | C | no-SL grid; DEPLOYMENTS: "NewsGuard policy C recommended" |
| 1112 | Gold_Kangaroo L1 | XAUUSDc | C | capped-mart, not validated; XAU very news-sensitive |
| 1113 | Gold_Kangaroo L2 | XAUUSDc | C | capped-mart, not validated |
| 1114 | Gold_Kangaroo L3 | XAUUSDc | C | capped-mart, not validated |
| 1115 | Gold_Kangaroo L4 | XAUUSDc | C | capped-mart, not validated |

> ⚠️ **WARNING — C will realize floating losses.** When the news window opens, CLOSE_ALL will close every open position on these magics, realizing whatever the grid/martingale basket is floating at that moment. **This is intended:** a controlled small realized loss beats an uncontrolled news-spike blowup on a no-SL basket. Expect to see it happen — it is not a malfunction.

---

## 2. Account 159503454 — "08. Blazing Arrow" (REAL_CENT, MT5)

- **Attach:** `(Boss)_NewsGuard.ex5`
- **Policy:** BLOCK_NEW — all legs have SL + closedDD kill rules, so blocking new entries around red news is enough (no need to close existing protected positions).

```
990103:B;990101:B;991001:B;991004:B;991002:B
```

| magic | EA | symbol | policy | reason |
|---|---|---|---|---|
| 990103 | (Boss)_RSI_MR_GridLog | EURUSD | B | PENDING_REMOVE — keep entry until EA actually removed |
| 990101 | (Boss)_ZeusInspired_GridLog | XAUUSD | B | SL + closedDD 15% |
| 991001 | EA_BREAKOUT_XAU | XAUUSD | B | SL + closedDD 10% |
| 991004 | (BRK)_SqueezeBreakout | XAUUSD | B | SL + closedDD 10% |
| 991002 | (BRK)_TrendlineBreakout | XAUUSD | B | SL + closedDD 8% (EXPERIMENTAL) |

> Note: 990103 is **PENDING_REMOVE**. Keep it in the string until the EA is actually removed from the account, then drop it. Leaving it in after removal is harmless (NewsGuard just won't find positions for that magic).

---

## 3. Account 159475669 — "Boss - Trend Swing" (REAL_CENT, MT5)

- **Attach:** `(Boss)_NewsGuard.ex5`
- **Policy:** BLOCK_NEW on known magics — user-mix account (lab does not certify it), but B on enumerated magics is cheap protection.

```
1524:B;9398:B;939721:B;990005:B;990010:B
```

| magic | EA | symbol | policy | reason |
|---|---|---|---|---|
| 1524 | NuiIndy Dynamic RSI+ADX | EURUSD | B | user mix; block new around red news |
| 9398 | ST_EA03 Count-MACD | USDCAD | B | PENDING_REMOVE; user optimizing by hand |
| 939721 | ST_EA03 Count-MACD user config | GBPUSD | B | PENDING_REMOVE; uncapped-ruin confirmed |
| 990005 | CB_GBP ConsoBreakout | GBPUSD | B | user mix |
| 990010 | ST03 replica | GBPUSD | B | PENDING_REMOVE; WATCH OOS 0.86 |

> ⚠️ **CAVEAT — not full coverage.** This account also runs **unenumerated user EAs (LondonConso / GoldReaper / MatchaGrid / BRK-XAU)** whose magics are UNKNOWN (see ORDER-092, DEPLOYMENTS row `magic=VARIOUS`). **NewsGuard only acts on magics listed in `GuardConfig`** — those EAs are NOT protected until their magics are enumerated (from the AccountSnapshot exporter after VPS attach) and added to the string above.

---

## 4. Demo accounts — DO NOT ATTACH NewsGuard

**Accounts 415573666 (Demo Mt5-2), 69424711 (Demo EA3), 463666728 (Demo bundle 10): do NOT attach NewsGuard — on any of them.**

Reason: these demo legs are **forward tests judged against backtests that had no news filter**. Adding a news filter now would corrupt the live-vs-backtest comparison at judge date. Leave them unguarded on purpose. If someone "helpfully" attaches NewsGuard to a demo account later, remove it and re-note this.

---

## Regenerate when DEPLOYMENTS.csv changes

This file is a snapshot of `portfolio\DEPLOYMENTS.csv` as of 2026-07-17. **Whenever DEPLOYMENTS.csv changes** (new magic, removed EA, account moved, status flip), regenerate this file and re-verify every magic string against the CSV before pasting into a terminal.
