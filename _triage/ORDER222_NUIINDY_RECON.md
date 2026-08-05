# ORDER-222 — NuiIndy recon (read-only, no backtests run)

**Purpose:** inventory everything that already exists on NuiIndy before ORDER-222 tests whether
`CutLoss_Percent=30` actually fires. Both backtests behind the ORDER-212 provenance check peaked at
15.4%/16.6% DD against a 30% threshold — the switch has never been observed to trip.

All facts below are things I *read* directly (file path + line quoted). Anywhere I could not find a
value, it says **NOT FOUND** — nothing here is inferred/guessed.

---

## 1. EA source / binary — where it lives

Source is **available**, not closed-source (a prior doc calling it "locked" was false — see ORDER-095
verdict line 11-13, quoted in §3 below).

- `D:\EA_LAB\...` — **no copy of the NuiIndy .mq5/.ex5 exists inside the EA_LAB repo itself.** Only
  derived artifacts (`.set`, `.ini`, `.htm` reports) live under repo control.
- Real source + compiled binary live in the MT5 roaming terminal data folder (terminal ID
  `9CA16B8382AE4CF692710FB36B9DA355`, the same non-portable install `scripts\mt5_run.ps1` points at
  by default):
  - `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\(NuiIndy) Dynamic RSI+ADX Style (4).mq5`
  - `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\(NuiIndy) Dynamic RSI+ADX Style (4).ex5`
  - (sibling, not the EA in question) `...\Experts\(NuiIndy) Perfect Tri Arbitrage Any Symbols.mq5/.ex5`
- Tester `Expert=` string used in every `.ini`: `(NuiIndy) Dynamic RSI+ADX Style (4)` — exact match
  required by `mt5_run.ps1 -Expert`.
- Provenance note (`_triage\ORDER095_NUIINDY_EXPAND_VERDICT.md:11-13`): "The `.mq5` source sits in
  roaming Experts (`9CA16B…\MQL5\Experts`, fxDreema-generated, 16.6k lines) — 'locked' was false; full
  behavioural + code confirmation available." I did not re-open/re-read the 16.6k-line source myself
  in this recon (out of scope — read-only inventory, not a code audit); this line is quoted from the
  existing verdict doc, not independently re-verified line-by-line here.

## 2. Inputs — CutLoss and lot-escalation, literal names + values

Confirmed directly from `.set` files (`D:\EA_LAB\_mt5_auto\ab_sets\nuiindy_sets\*.set`) and `.ini`
files (`D:\EA_LAB\_mt5_auto\ini\NUI_EURUSD_cut30only_2022.ini` / `..._2425.ini`):

| Input (literal name) | Meaning | As-shipped default | "cut30-only" recommended value |
|---|---|---|---|
| `CutLoss_Percent` | basket/equity-level DD-kill (% of account) | `100.0` (`NUI_baseline.set`, `NUI_flatlot.set`, `NUI_single.set`) | `30` (`NUI_cut30only.set`, both `NUI_EURUSD_cut30only_*.ini`) |
| `Multiple1` | lot multiplier, tier 1 (order_count ≤ 4) | `1.0` | `1.0` (unchanged) |
| `Multiple2` | lot multiplier, tier 2 (order_count 4–12) | `1.0` | `1.0` (unchanged) |
| `Multiple3` | lot multiplier, tier 3 (order_count > 12) — **this is the escalation lever** | `1.2` | `1.2` (unchanged) |
| `MAX_Order` | max simultaneous grid orders (depth cap) | `99999.0` (uncapped) | `99999.0` (uncapped — cut30-only leaves this uncapped on purpose) |
| `Lot_Divided` | base lot = equity / this value | `500000.0` | same |
| `Near_by_Pips` | grid spacing | `10.0` | same |
| `MagicStart` | magic number | `1524` | same |

Lot law per the verdict doc (`_triage\ORDER095_NUIINDY_EXPAND_VERDICT.md:17-20`, citing source lines
7710/7816/7959, not re-verified against source in this recon): `lots = MathPow(Multiple_tier,
order_count)`, tier selected by simultaneous open-order count. With Multiple1=Multiple2=1.0, all
escalation lives on `Multiple3=1.2`: 1.2^12≈8.9x, 1.2^20≈38x, 1.2^30≈237x base lot.

Full `.set` inventory (all in `D:\EA_LAB\_mt5_auto\ab_sets\nuiindy_sets\`), CutLoss/MAX_Order/Multiple3
column read directly from each file:

| File | MAX_Order | Multiple1/2/3 | CutLoss_Percent |
|---|---|---|---|
| `NUI_baseline.set` | 99999.0 | 1.0/1.0/1.2 | 100.0 |
| `NUI_flatlot.set` | 99999.0 | 1.0/1.0/**1.0** | 100.0 |
| `NUI_single.set` | **1.0** | 1.0/1.0/1.2 | 100.0 |
| `NUI_cut30only.set` | 99999.0 | 1.0/1.0/1.2 | **30** |
| `NUI_cut40only.set` | 99999.0 | 1.0/1.0/1.2 | **40** |
| `NUI_cap12_cut30.set` | **12** | 1.0/1.0/1.2 | 30 |
| `NUI_cap20_cut40.set` | **20** | 1.0/1.0/1.2 | 40 |
| `NUI_cap8_cut25.set` | **8** | 1.0/1.0/1.2 | 25 |

## 3. Every existing artifact mentioning NuiIndy

### `.set` files — `D:\EA_LAB\_mt5_auto\ab_sets\nuiindy_sets\` (8 files, listed in §2 table above).

### `.ini` files — `D:\EA_LAB\_mt5_auto\ini\` (NuiIndy-related, non-exhaustive list; 55 total per
ORDER-212 recon). Full `[Tester]` block read for the two that matter most:

**`NUI_EURUSD_cut30only_2022.ini`** (full contents):
```
Expert=(NuiIndy) Dynamic RSI+ADX Style (4)
Symbol=EURUSD
Period=H1
Model=4
FromDate=2022.01.01
ToDate=2023.01.01
Deposit=10000
Currency=USD
Leverage=100          <- numeric form (see gotcha in §6)
Report=NUI_EURUSD_cut30only_2022
```
plus the `[TesterInputs]` block matching `NUI_cut30only.set` exactly (CutLoss_Percent=30,
MAX_Order=99999.0, Multiple3=1.2, MagicStart=1524).

**`NUI_EURUSD_cut30only_2425.ini`** — identical except `FromDate=2024.01.01`, `ToDate=2025.01.01`,
`Report=NUI_EURUSD_cut30only_2425`.

Other NuiIndy inis present in `_mt5_auto\ini\` (not re-read line-by-line this pass, listed for
completeness): `NUI_EURUSD_cap12cut30_2022.ini`, `NUI_EURUSD_cap12cut30_2425.ini`,
`NUI_EURUSD_H1_base_2425.ini`, `NUI_EURUSD_H1_flat_2425.ini`, `NUI_EURUSD_H1_single_2326.ini`,
`NUI_EURUSD_H1_base_2326.ini`, `DIAG_NuiIndy_H4.ini`, `NuiIndy_center_OOS.ini`,
`NuiIndy_robust_IS.ini`, `NuiIndy_robust_OOS.ini`, `NuiIndy_RSI_ADX_IS.ini`, `NuiIndy_RSI_ADX_OOS.ini`,
`OOS_NuiIndy_GBPUSD.ini`, `OPT_NuiIndy.ini`, `RIGOR_NuiIndy_M4_OOS.ini`,
`SMOKE_B4_NuiIndy_TriArb_EURUSD.ini`, `SMOKE_B4_NuiIndy_TriArb_XAUUSD.ini`, several
`SMOKE_C5_NuiIndy_*.ini` (AUDCAD/AUDUSD/GBPCHF/GBPUSD/NZDUSD/USDCHF),
`SMOKE_NEW_NuiIndy_RSI_ADX_{EURUSD,XAUUSD}.ini`, several `smoke_NuiIndy_*.ini`
(AUDCAD/AUDCHF/AUDNZD/AUDUSD/CADJPY/EURCHF/GBPUSD/NZDUSD/USDCAD/USDCHF), `VERIFY_NuiIndy_IS.ini`,
`VERIFY_NuiIndy_OOS.ini`.

### `.htm` MT5 reports — the two that produced the CutLoss=30 numbers, metrics extracted directly
from the report HTML (`iconv -f UTF-16LE`, no re-run performed):

**`D:\EA_LAB\_mt5_auto\reports\NUI_EURUSD_cut30only_2022.htm`**
| Field | Value (read from report) |
|---|---|
| Symbol | EURUSD |
| Period | H1 (2022.01.01 - 2023.01.01) |
| Model | 4 (from the sibling `.ini`; report HTML itself doesn't restate Model=) |
| Initial Deposit | 10 000.00 |
| Leverage (report's own line) | **1:2000** |
| Total Trades | 933 |
| Profit Factor | 1.19 |
| Balance Drawdown Maximal | 2 005.74 (15.33%) |
| Equity Drawdown Maximal | 1 965.12 (**15.40%**) |

**`D:\EA_LAB\_mt5_auto\reports\NUI_EURUSD_cut30only_2425.htm`**
| Field | Value (read from report) |
|---|---|
| Symbol | EURUSD |
| Period | H1 (2024.01.01 - 2025.01.01) |
| Model | 4 |
| Initial Deposit | 10 000.00 |
| Leverage (report's own line) | **1:2000** |
| Total Trades | 836 |
| Profit Factor | 2.20 |
| Balance Drawdown Maximal | 656.76 (5.10%) |
| Equity Drawdown Maximal | 1 992.74 (**16.56%**) |

**⚠️ Leverage gotcha found in this recon (not previously flagged in ORDER-212):** both `.ini` files
write `Leverage=100` — the **numeric** form. Per `scripts\mt5_run.ps1` lines 32-40 (its own header
comment, ORDER-165 2026-07-23), the numeric form is *silently ignored* by the tester, which instead
uses whatever leverage is cached from the last GUI/tester session on that terminal. Consistent with
that: both reports came back at **1:2000**, not the requested 1:100. This means the two `CutLoss=30`
runs behind the "clean" provenance verdict ran at **2000:1 leverage, not 100:1** — margin headroom
(and therefore how much room there is before a margin-call truncates the run before the DD-kill can
even fire) is 20x more permissive than a 1:100 account would give. Neither `NUI_EURUSD_cut30only_*.ini`
carries the corrected `Leverage=1:N` string form that later `mt5_run.ps1` versions require. This is a
fact read from the files, not a re-run — flagging it because ORDER-222 needs to decide what leverage
to test at, and re-running at the account's real leverage may change both the PF and the DD ceiling.

### `.htm` reports for the other lever-isolation runs (baseline / flat-lot / single-order), cited by
the verdict doc but not re-parsed in this pass since ORDER-212 already extracted the cut30 pair and
the doc quotes these numbers directly: `NUI_EURUSD_H1_base_2425.htm` (PF 2.20, not independently
re-read here), `NUI_EURUSD_H1_flat_2425.htm` (PF 0.72), `NUI_EURUSD_H1_single_2326.htm` (PF 0.90).

### `_triage/*.md` verdict docs mentioning NuiIndy
- `D:\EA_LAB\_triage\ORDER095_NUIINDY_EXPAND_VERDICT.md` — the primary verdict: EXPANSION REJECTED
  (structural martingale, no entry edge), + the CutLoss=30 LIVE guardrail recommendation.
- `D:\EA_LAB\_triage\_archive\audits_and_investigations\ORDER212_NUIINDY_GUARDRAIL_PROVENANCE.md` — provenance audit of the 1.19/2.20
  numbers (CLEAN, but notes the DD-kill was never empirically triggered in either tested window).
- Downstream citations of the same two numbers (no new evidence): `EA_SCORECARD_AND_REGISTRY.md:157`
  and `EDGE_CATALOG.md:54-63`.

## 4. Magic number(s) / account(s)

From `D:\EA_LAB\portfolio\DEPLOYMENTS.csv:7`:
```
159475669,Boss - Trend Swing,REAL_CENT,MT5,VPS 66.212.22.7,NuiIndy Dynamic RSI+ADX,1524,EURUSD,ACTIVE,closedDD 25%,,2026-05-26,user mix - lab does not certify this account
```
- **Account:** `159475669` ("Boss - Trend Swing"), type `REAL_CENT` (real-money **cent** account), MT5,
  VPS `66.212.22.7`.
- **Magic:** `1524`.
- **Symbol:** `EURUSD` (matches every backtest artifact above).
- **Status:** `ACTIVE`. **kill_rule column says `closedDD 25%`** — this is the DEPLOYMENTS.csv registry
  kill-rule field, a *separate* number from the EA's own internal `CutLoss_Percent` input; I did not
  find anything reconciling whether "closedDD 25%" is meant to be the same guardrail as
  `CutLoss_Percent` or an independent portfolio-level rule layered on top.
- **Row note:** "user mix - lab does not certify this account" — i.e. this account is user-managed,
  not lab-attested.
- Cross-check, `D:\EA_LAB\portfolio\ATTESTATION_MAP.csv:6`:
  ```
  159475669,1524,,,,none,USER_EA NuiIndy - user mix account; lab does not own artifacts
  ```
  Attestation confidence = `none`. **This means the lab does not have a confirmed record of which
  `.set` is actually loaded on the live VPS terminal right now** — we know what we *recommended*
  (`NUI_cut30only.set`, `CutLoss_Percent=30`), not what's *deployed*. No file found that confirms the
  live terminal was actually updated to CutLoss=30 after the 2026-07-17 recommendation.

No other magic number found for NuiIndy anywhere in `DEPLOYMENTS.csv` or `EA_SCORECARD_AND_REGISTRY.md`
— magic `1524` on account `159475669` is the only live instance.

## 5. Lot/deposit relationship — backtest deposit vs. live account balance

- Every backtest reviewed above used **Initial Deposit = 10,000.00 (USD)** at **Model=4**, per the
  report HTML (`Initial Deposit:` row) and the `.ini` (`Deposit=10000`, `Currency=USD`).
- Live account `159475669` is `REAL_CENT` — a cent account (native currency almost certainly USC/cent,
  not USD 1:1) per `DEPLOYMENTS.csv:7`.
- **Live balance: NOT FOUND.** I searched `portfolio\DEPLOYMENTS.csv`, `portfolio\ATTESTATION_MAP.csv`,
  `EA_SCORECARD_AND_REGISTRY.md`, and `portfolio\monthly\2026-{03..07}.md/.csv` — none records an
  account balance or equity figure for `159475669`. The monthly P&L tables give magic-1524 **net
  profit**, not balance: `portfolio\monthly\2026-07.csv:12` → `1524,NuiIndy Dynamic RSI+ADX,159475669,
  92.77,51,8.82,88.2,7.45` (net +$92.77 over 51 trades that month, realized_DD $7.45) and
  `portfolio\monthly\2026-06.csv:3` → net +$60.23/33 trades/realized_DD $13.43. These are small-dollar
  figures consistent with (but not proof of) a lightly-funded cent account, nowhere near the $10,000
  backtest deposit.
- Why this matters (as the task brief notes): %DD scales with lot-size-vs-deposit, not with PF. A
  `CutLoss_Percent=30` measured against a $10,000 backtest deposit is a **percentage of equity**, so
  in principle it should be deposit-invariant *if* lot sizing also scales with equity
  (`Lot_Divided=500000` base-lot formula suggests it does — lots = equity/500000 — but I did not
  verify this arithmetic against source in this recon). Still, since the live balance is unknown, I
  cannot confirm the backtest's implied lot-vs-deposit ratio matches what's actually running live.

## 6. How backtests are launched — `D:\EA_LAB\scripts\mt5_run.ps1`

**Signature** (lines 19-56):
```powershell
mt5_run.ps1 -Expert <string> -Symbol <string> [-Period H1] -FromDate <yyyy.mm.dd> -ToDate <yyyy.mm.dd> `
            [-SetFile <path>] [-Model 4] [-Deposit 10000] [-Leverage 100] -ReportName <string> `
            [-Terminal "D:\Meta 5\terminal64.exe"] `
            [-DataDir "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"] `
            [-TimeoutSec 1800] [-ReserveCores 4] [-Portable] [-Force]
```
Example invocation from the script's own header (lines 10-17), which for NuiIndy would look like:
```powershell
& .\scripts\mt5_run.ps1 -Expert "(NuiIndy) Dynamic RSI+ADX Style (4)" -Symbol EURUSD -Period H1 `
    -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 4 -Deposit 10000 -Leverage 100 `
    -SetFile "_mt5_auto\ab_sets\nuiindy_sets\NUI_cut30only.set" -ReportName ORDER222_NuiIndy_MAIN
```
`-Leverage` is passed as a plain integer *N*; the script itself converts it to the `1:N` string form
when writing the `.ini` (`$lines` block, line 108: `"Leverage=1:$Leverage"`) — callers should NOT
write `Leverage=100` directly into a hand-made `.ini` the way the two 2026-07-17 cut30 inis did (see
§3 gotcha).

**Gotchas the script's own comments call out** (verbatim, condensed):
1. **No `-Spread` param, on purpose** (lines 27-30): MT5 build 5836 silently ignores `Spread=`/
   `TestSpread=` in `[Tester]` — tester spread always comes from recorded history/ticks. Don't re-add
   without re-verifying.
2. **Leverage must be `1:N` string form** (lines 32-40): numeric form is silently ignored and the
   tester falls back to its cached last-used leverage — non-reproducible. The script now writes `1:N`
   and asserts the report's leverage post-run (exit code 3 on mismatch).
3. **Per-terminal input cache** (lines 41-47): `[TesterInputs]` only overrides inputs you explicitly
   list; every input *not* listed comes from `MQL5\Profiles\Tester\<Expert>.set` (last-used values,
   overwritten by any GUI/run session touching that EA in that terminal). A run without a **full**
   `-SetFile` is not reproducible and not comparable across runs. The script WARNs (not hard-fails) if
   `-SetFile` is omitted (lines 94-101).
4. **Truncation from the safety cage** (lines 151-158): if a hard equity-DD kill halts the EA mid-run,
   the report still looks like a normal full-window report — PF is computed over whatever fraction of
   the window ran before the kill, and the kill point moves with `-Deposit`. The script writes a
   sidecar `*.truncation_check.json` and prints a `WARN TRUNCATED-RUN` line, but never changes its own
   exit code. **This is directly relevant to ORDER-222**: if `CutLoss_Percent=30` actually fires during
   a test run, the resulting report may look like an ordinary complete-window report unless the
   truncation sidecar is checked.
5. **Stale destination report guard** (lines 81-86): both the terminal's own data-dir copy and the
   repo's `_mt5_auto\reports\<ReportName>*` are deleted before launch, so a run that produces no fresh
   report can't be mistaken for a stale pass.
6. **Freeze/timeout guard** (lines 118-146): process runs at `BelowNormal` priority with cores reserved
   (desktop stays responsive under Model-4 every-tick load); a run that exceeds `-TimeoutSec` (default
   1800s) gets its `terminal64.exe` killed rather than left to peg the CPU.
7. **Leverage assertion sidecar** (lines 170-210): every run writes
   `_mt5_auto\reports\<ReportName>.leverage_check.json` recording requested vs. actual leverage and a
   MATCH/MISMATCH/NOT_RECORDED/NO_LEVERAGE_LINE status — worth checking for any new ORDER-222 run,
   given the mismatch already found in §3 on the existing cut30 reports.
8. **Guard scope** (lines 59-64): the "already running" abort is scoped to the specific `-Terminal`
   exe path, not the global process name, so a second portable instance can run in parallel.

I did not find `-Report=<ReportName>.truncation_check.json` or `.leverage_check.json` sidecars for the
two existing `NUI_EURUSD_cut30only_*` reports — those sidecars appear to be a feature the script grew
after ORDER-165 (2026-07-23), and the cut30 runs were made 2026-07-17, predating the guard. **NOT
FOUND**: no truncation/leverage sidecar exists for either of the two reports that produced 1.19/2.20.

## Summary of key facts for ORDER-222

- Source: available, plain text, at
  `9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\(NuiIndy) Dynamic RSI+ADX Style (4).mq5` (+ `.ex5`).
- Inputs: `CutLoss_Percent` (basket DD-kill %, currently recommended 30, as-shipped 100),
  `Multiple1`/`Multiple2`/`Multiple3` (lot escalation, `Multiple3=1.2` is the live lever),
  `MAX_Order=99999` (uncapped, deliberately left uncapped in the cut30-only config).
- Every existing DD number (15.40% and 16.56% equity DD) is well under the 30% threshold — the switch
  has never fired in any evidence on file, confirming the task's premise.
- **New finding this recon:** both existing cut30 runs were at **1:2000 leverage** (report-confirmed),
  not the `Leverage=100` the `.ini` files requested — a numeric-form leverage bug documented in
  `mt5_run.ps1`'s own comments. Any ORDER-222 run should use the corrected `1:N` string form and check
  the `.leverage_check.json` sidecar.
- Live deployment: magic `1524`, account `159475669` (REAL_CENT, "Boss - Trend Swing"), attestation
  confidence `none` — the lab does not have confirmed evidence of which `.set` is actually loaded on
  the VPS right now, only what was recommended.
- Live account balance/currency: **NOT FOUND** anywhere in the repo.
- Launch mechanism: `scripts\mt5_run.ps1`, documented gotchas above — most relevant to ORDER-222 is the
  truncation-on-DD-kill behavior (a report can look complete-window even when the safety cage cut it
  short) and the leverage string-format requirement.
