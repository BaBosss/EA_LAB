# ORDER — BRK_XAU live-trade forensic replay (v2 vs v3)

> ## 🔒 CLOSED INCONCLUSIVE — do not re-run this replay (Claude/Opus 2026-07-26)
> The run below is honest and well-controlled, but the method was **structurally incapable of
> answering the question** and I should have caught that before spending the machine time:
>
> **v3's entries are a strict subset of v2's.** A 55-bar Donchian high is by definition ≥ the
> 40-bar high, so every v3 entry is also a v2 entry. Observing that a trade *happened* therefore
> discriminates nothing. Only v2-trades-that-v3-would-skip carry information — and the live
> account produced **one** trade in 17 days. Even with perfect data this replay could not have
> reached a conclusion.
>
> Two independent blockers on top of that: this machine has no Exness **XAUUSDc** tick history
> (only ThinkMarkets XAUUSD, whose prices are not comparable — Jan fills ~4483/5427 vs the live
> 4156 in July), and the H1 history cache ends 2026.06.30 while ticks run to 07-24, which is why
> every probe returned 0 trades.
>
> **Settled instead by documentary evidence → `portfolio/ATTESTATION_MAP.csv` (991001, confidence
> raised low→medium, presumed v2).** The residual gap is closable only by a direct Inputs-tab read
> on account 159503454 — a user action, not a lab action.
>
> Kept as the record of *why* the tester route is closed, so nobody re-opens it.

**Run date:** 2026-07-26 · **Operator:** mechanical tester job (no verdict issued, no doc/CSV edited)
**Question:** which config (v2 or v3) reproduces the single live trade of account 159503454 (magic 991001)?

Live log to reproduce (Exness cent account, symbol **XAUUSDc**):

| | |
|---|---|
| OPEN | 2026.07.22 14:00:48 · BUY 0.01 @ 4156.298 · comment `BRKOUT_BUY` |
| CLOSE | 2026.07.22 19:54:13 @ 4130.569 · comment `[sl 4130.569]` · profit −25.70 |

---

## 0. Environment / symbol actually used — READ THIS FIRST

The terminal used for the replay (`D:\Meta 5`, data dir
`...\Terminal\9CA16B8382AE4CF692710FB36B9DA355`) is logged into **ThinkMarkets-Live**
(`config\common.ini`: `Login=146237`, `Server=ThinkMarkets-Live`).

Tick history on this machine:

| broker base | XAU symbol | tick data |
|---|---|---|
| `bases\Exness-MT5Real20\ticks\XAUUSDc` | XAUUSDc | **none** — only a 56 KB `ticks.dat` stub (last write 2026-06-03), no `.tkc` month files |
| `bases\ThinkMarkets-Live\ticks\XAUUSD` | XAUUSD | full `202001.tkc` … `202607.tkc` (202607 written 2026-07-25) |

→ The live account's own symbol (**XAUUSDc**) has **no real-tick history on this machine**, so it
could not be tested. **Symbol actually used: `XAUUSD` (ThinkMarkets-Live / TF Global Markets).**
Prices from this feed are NOT the same series the live account traded (see §5).

Binary: `_vps_deploy\EA_BREAKOUT_XAU.ex5` SHA256 `4EC90DB8…C512F40` — **identical** to the
`MQL5\Experts\EA_BREAKOUT_XAU.ex5` the tester loaded (no copy needed).
Stray `terminal64.exe` / `metatester64.exe`: none running before the job (checked).
No report newer than this job's appeared in `_mt5_auto\reports` afterwards (no parallel-session collision).
Harness: repo-standard `scripts\mt5_run.ps1` (writes ini, launches `/config`, asserts leverage).

---

## 1. v2 run

**Command**

```powershell
& "D:\EA_LAB\scripts\mt5_run.ps1" -Expert "EA_BREAKOUT_XAU" -Symbol XAUUSD -Period H1 `
  -FromDate 2026.07.01 -ToDate 2026.07.26 -Model 4 `
  -SetFile "D:\EA_LAB\_vps_deploy\BRK_XAU_live_v2.set" -Leverage 100 `
  -ReportName BRKXAU_REPLAY_V2 -TimeoutSec 900
```

**ini used** (`_mt5_auto\ini\BRKXAU_REPLAY_V2.ini`) — full .set passed, all 14 inputs listed:

```
[Tester]
Expert=EA_BREAKOUT_XAU
Symbol=XAUUSD
Period=H1
Model=4
Optimization=0
FromDate=2026.07.01
ToDate=2026.07.26
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=1:100
ExecutionMode=0
Visual=0
Report=BRKXAU_REPLAY_V2
ReplaceReport=1
ShutdownTerminal=1
[TesterInputs]
_00_OptimizeMode=false
_01_BreakoutBars=40
_02_SlAtrMult=1.5
_02_TpAtrMult=5.0
_03_AtrPeriod=14
_03_AtrMaPeriod=20
_03_AtrExpandRatio=1.0
_04_UseDailyEma=true
_04_EmaPeriod=200
_05_BuyOnly=true
_05_LotSize=0.01
_06_Magic=991001
_06_Deviation=20
_06_AllowLive=true
```

**Leverage assert (quoted verbatim)** — `_mt5_auto\reports\BRKXAU_REPLAY_V2.leverage_check.json`:

```json
{ "report_name": "BRKXAU_REPLAY_V2", "requested_leverage": 100,
  "actual_leverage": 100, "match": true, "status": "MATCH" }
```
mt5_run stdout: `OK REPORT: ...\BRKXAU_REPLAY_V2.htm (leverage verified 1:100)`

**Report header** (`BRKXAU_REPLAY_V2.htm`): Symbol `XAUUSD` · Company `TF Global Markets (Aust) Pty Ltd` ·
Leverage `1:100` · History Quality `100% real ticks` · Bars `410` · Ticks `6 552 188`

**Trade list in window:** *(empty)*

| open time | dir | open price | close time | close price | reason | profit |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

**2026.07.22 14:00 entry present?** NO.
**Total trades: 0** (Total Deals: 0, Total Net Profit 0.00)
Expert log for the run contains only the init line
`2026.07.01 00:00:00 EA_BREAKOUT_XAU init | AllowLive=YES OptMode=off Bars=40 SL×1.5 TP×5.0 EMA200=ON`
— no order attempt, no `ORDER FAILED`, no min-lot refusal.

---

## 2. v3 run

**Command** — identical except the .set:

```powershell
& "D:\EA_LAB\scripts\mt5_run.ps1" -Expert "EA_BREAKOUT_XAU" -Symbol XAUUSD -Period H1 `
  -FromDate 2026.07.01 -ToDate 2026.07.26 -Model 4 `
  -SetFile "D:\EA_LAB\_vps_deploy\BRK_XAU_live_v3.set" -Leverage 100 `
  -ReportName BRKXAU_REPLAY_V3 -TimeoutSec 900
```

**ini used** (`_mt5_auto\ini\BRKXAU_REPLAY_V3.ini`): identical `[Tester]` block
(`Symbol=XAUUSD`, `Model=4`, `Leverage=1:100`, `FromDate=2026.07.01`, `ToDate=2026.07.26`),
`[TesterInputs]` differing only in `_01_BreakoutBars=55`, `_02_TpAtrMult=8.0`, `_04_EmaPeriod=150`.

**Leverage assert (quoted verbatim)** — `BRKXAU_REPLAY_V3.leverage_check.json`:

```json
{ "report_name": "BRKXAU_REPLAY_V3", "requested_leverage": 100,
  "actual_leverage": 100, "match": true, "status": "MATCH" }
```
mt5_run stdout: `OK REPORT: ...\BRKXAU_REPLAY_V3.htm (leverage verified 1:100)`

**Report header:** Symbol `XAUUSD` · Leverage `1:100` · History Quality `100% real ticks` ·
Bars `410` · Ticks `6 552 188`

**Trade list in window:** *(empty)*

| open time | dir | open price | close time | close price | reason | profit |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

**2026.07.22 14:00 entry present?** NO.
**Total trades: 0**
Expert log: only `... init | AllowLive=YES OptMode=off Bars=55 SL×1.5 TP×8.0 EMA150=ON`.

---

## 3. Comparison table

| | live log (159503454, XAUUSDc) | v2 replay (XAUUSD) | v3 replay (XAUUSD) |
|---|---|---|---|
| trade count in 2026.07.01–07.26 | 1 | **0** | **0** |
| 2026.07.22 14:00 BUY | yes @ 4156.298 | **absent** | **absent** |
| exit | SL @ 4130.569, −25.70 | n/a | n/a |
| matches live log? | — | **NO** | **NO** |

**NEITHER config matches. The result is INCONCLUSIVE — this replay cannot discriminate v2 from v3.**

---

## 4. Diagnostic probes (why the window produced nothing) — labelled diagnostics, not verdict evidence

All on `XAUUSD`, same 2026.07.01–2026.07.26 window, leverage asserted 1:100 each time.
Probe .set files live in the session scratchpad (not in the repo).

| # | report | change vs v2 | trades |
|---|---|---|---|
| P1 | `BRKXAU_DIAG_V2_NOEMA` | v2 with `_04_UseDailyEma=false` | 0 |
| P2 | `BRKXAU_DIAG_V3_NOEMA` | v3 with `_04_UseDailyEma=false` | 0 |
| P3 | `BRKXAU_DIAG_BARS8` | EMA off + `_01_BreakoutBars=8` | 0 |
| P4 | `BRKXAU_DIAG_BARS8_BOTHDIR` | P3 + `_05_BuyOnly=false` | 0 |
| P5 | `BRKXAU_DIAG_ALLOPEN` | P4 + `_03_AtrExpandRatio=0.0` (every gate open) | 0 |
| P6 | `BRKXAU_DIAG_M2_BARS8` | P4 but `Model=2` (1-min OHLC) | 0 |
| P7 | `BRKXAU_DIAG_M2_V2` | v2 but `Model=2` | 0 |

Control runs proving harness + binary + feed are functional outside this window:

| # | report | window / config | result |
|---|---|---|---|
| C1 | `BRKXAU_SANITY_2025H2` | 2025.07.01–2025.12.31, v2 verbatim, M4 | **8 entry deals**, eqDD 1.3% |
| C2 | `BRKXAU_DIAG_BARS8_2025JUL` | 2025.07.01–2025.07.26, P3 config, M4 | 1 entry (2025.07.03), position held to window end |
| C3 | `BRKXAU_DIAG_LONG_V2` | 2026.01.01–2026.07.26, v2 verbatim, M4 | **7 entry deals**, all in Jan–Mar; last deal 2026.03.02 03:01, then 145.9 idle days |

Reading of the probes, stated factually:
- The EA fires normally on this feed in other windows (C1/C2/C3), so binary, harness, ini, inputs and
  leverage are all working.
- Inside 2026.07.01–07.26 the EA produced **zero orders under every relaxation tried** — trend filter
  off, 8-bar channel instead of 40/55, both directions, ATR gate wide open, and under a different tick
  model. A both-direction 8-bar Donchian break with all gates open producing 0 entries over 410 H1 bars
  is not consistent with ordinary price action; it points at the July-2026 XAUUSD series inside this
  terminal (the tester log reports the H1 history cache as `contains 8822 bars from 2025.01.02 01:00 to
  **2026.06.30 23:00**`, i.e. no cached H1 bars beyond 2026-06-30, while ticks are present to 07-24).
  Root-causing that is outside this job's scope and no verdict is drawn from it.

## 5. Price-level honesty note

The live account traded gold at **4156.298** on 2026-07-22. The ThinkMarkets XAUUSD feed used here shows
(from C3's deal list) fills at **4483.14** (2026-01-09), **5427.55** (2026-01-29), **5357.10** (2026-03-02).
So the two series are not just spread-different, they sit at different levels/period highs; any price
delta between this replay and the live log would not be a meaningful "broker feed differs slightly"
comparison. Reproducing the live fill would require the **Exness XAUUSDc** tick history, which this
machine does not have.

## 6. Artifacts

- Reports: `D:\EA_LAB\_mt5_auto\reports\BRKXAU_REPLAY_V2.htm`, `…\BRKXAU_REPLAY_V3.htm`
  (+ `BRKXAU_DIAG_*`, `BRKXAU_SANITY_2025H2.htm`)
- Ini files: `D:\EA_LAB\_mt5_auto\ini\BRKXAU_REPLAY_V2.ini`, `…\BRKXAU_REPLAY_V3.ini`
- Leverage asserts: `…\reports\BRKXAU_REPLAY_V{2,3}.leverage_check.json` — both `MATCH` at 1:100
- Tester log: `…\Terminal\9CA16B8382AE4CF692710FB36B9DA355\Tester\logs\20260726.log`
