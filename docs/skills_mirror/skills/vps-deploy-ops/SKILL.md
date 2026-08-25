---
name: vps-deploy-ops
description: >
  Mechanical deployment operations for shipping a validated standalone MT5 EA
  from the dev machine to the live VPS — headless compile of the .mq5 to .ex5,
  building the _vps_deploy bundle (.ex5 + locked .set + README), and the
  silent-stop danger checklist that catches the ways an EA backtests fine then
  refuses to trade live. Use when the user wants to compile an EA, build a
  deploy bundle, ship to VPS, or asks why a deployed EA isn't trading. Trigger
  on /vps-deploy.
---

# VPS Deploy Ops

**Requires the live-deployment-controller GATE's output (judge criteria + DEPLOYMENTS.csv row) before shipping anything to an account — this skill is the SHIP step, not the gate.**

The validation pipeline says an EA has edge. This skill is the **mechanical bridge** from `.mq5` source to a running VPS chart — and the catalog of silent failures that make a perfectly-validated EA place zero trades live. These failures are quiet: no error, no log, just nothing happening.

## Core stance
- **Live trading is on a SEPARATE VPS, not the dev machine.** Recompiling on dev is safe (it does not touch the running EAs). Ship artifacts to `_vps_deploy/`; the user moves them to the VPS.
- **A compile that opens the GUI is a failed compile.** Headless compile must run on a path INSIDE the MT5 DataDir.
- **The dangerous failures are silent.** Tester-gate, cent-lot-below-min, param-rename-on-recompile, expiry — all backtest fine and trade nothing. Run the checklist BEFORE shipping, not after the user notices no trades.

---

## Environment (this box)
- **MT5 portable install:** `D:\Meta 5` (terminal64.exe)
- **DataDir (where compile must happen):** `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\`
- **Experts folder:** `<DataDir>\MQL5\Experts\`
- **Standalone EA sources:** `D:\EA_Project\CURRENT_BUILD\TEMPLATE\`
- **Deploy bundles out:** `D:\EA_LAB\_vps_deploy\<EA_SHORT>\`
- ⚠️ Deploy the **.ex5 to AppData**, NOT to MetaTraderData (see [[feedback_mt5_deploy_path]]).

---

## Step 1 — Headless compile (.mq5 → .ex5)

The trap: running `/compile` on a source path OUTSIDE the DataDir makes MT5 **open the GUI** and never terminate — no .ex5 produced. Fix: copy the source into the DataDir Experts folder first.

```powershell
$src   = "D:\EA_Project\CURRENT_BUILD\TEMPLATE\(Boss)_MyEA_rev01.mq5"
$ddir  = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts"
Copy-Item $src $ddir -Force
# compile on the in-DataDir path:
& "D:\Meta 5\terminal64.exe" "/compile:$ddir\(Boss)_MyEA_rev01.mq5"
```
- **The terminal process lingers ~45s after compiling — this is normal.** The .ex5 appears in the Experts folder even while the process is still alive. Wait, then check for the .ex5 by size/timestamp; don't assume failure because the process didn't exit.
- Verify: the `.ex5` exists, timestamp is fresh, size is plausible (a real EA is tens of KB — e.g. LondonConsoBreakout = 42,534 bytes; a few-hundred-byte file = compile error stub).
- If include files (`.mqh`, e.g. `STANDALONE_RISK_BUNDLE.mqh`) are referenced, copy those into the DataDir Include path too, or the compile fails.

## Step 2 — Build the deploy bundle

Actual on-disk convention in `D:\EA_LAB\_vps_deploy\` (match it — don't invent a new one):
```
_vps_deploy\
  EA_BREAKOUT_XAU.ex5            ┐ single-symbol EA → files sit FLAT at the root
  BRK_XAU_live_v2.set           │ (no per-EA subfolder)
  README_DEPLOY.txt             ┘
  CB_GBP\                       ┐ binary reused across symbols → ONE subfolder
    (Boss)_LondonConsoBreakout_rev01.ex5   │ per SYMBOL, same .ex5 copied in each,
    CB_GBP_H1_live_v1.set                  │ symbol-specific .set
    README_DEPLOY.txt                      │
  CB_EUR\  (same .ex5, CB_EUR .set)        ┘
```
- README filename is **`README_DEPLOY.txt`** (plain text), not `README.md`.
- The `.set` must be the **exact locked set the validation used** — never a fresh export with defaults. Copy it verbatim; do not re-key params by hand.
- README must record: source .mq5 path + git commit, the IS/OOS PF numbers that justify deploy, magic number, symbol/TF, and the silent-stop checklist below as a pre-attach gate.
- **Same binary, multiple symbols** (e.g. LondonConsoBreakout → CB_GBP + CB_EUR): one subfolder per symbol, same .ex5 copied into each, symbol-specific .set. They share a magic safely BECAUSE the EA filters `PositionGetString(POSITION_SYMBOL) == _Symbol`. Single-symbol EAs stay flat at the root.

## Step 3 — Silent-stop danger checklist (run BEFORE attaching on VPS)

This is the **consolidated pre-flight list** — it intentionally re-lists a few items that
`live-deployment-controller` also checks ([E1] magic, [E2] symbol, [E3] lot) because a single
deploy-day checklist is more useful than cross-referencing mid-attach. Where a full mechanism
explanation exists elsewhere (cent-lot → live-deployment-controller; tester-gate → mql-code-generator),
this list is the trigger, not the source of truth. Every item is a way the EA backtests perfectly then
trades nothing. ALL must be cleared:

```
[S1] TESTER-GATE — EA uses  _06_AllowLive || MQLInfoInteger(MQL_TESTER).
     On the LIVE chart MQL_TESTER is false, so _06_AllowLive MUST be set true
     in the live .set. Default is false. ← #1 cause of "deployed, no trades".

[S2] RECOMPILE RESET — recompiling a running EA's source auto-reloads it on the
     chart → inputs revert to compiled DEFAULTS → _06_AllowLive flips to false →
     EA silently stops. After ANY recompile, re-attach in a market-quiet window
     and re-load the live .set. Never recompile the binary a live chart is using
     without planning the re-attach. (EA_BREAKOUT_XAU param-rename trap.)

[S3] CENT LOT BELOW MIN — for balance-derived sizing, compute lot on the CENT
     balance. balance / Lots_divided must be ≥ broker min (0.01). On 10,000 cent
     with Lots_divided=10,000,000 → 0.001 < min → zero fills. Fix Lots_divided.
     Fixed-lot EAs (0.01) are fine. See live-deployment-controller cent pitfall.

[S4] EXPIRY / ACCOUNT-LOCK — a time-expired or demo-locked .ex5 backtests
     beautifully then refuses live. Confirm the EA has no expiry / account lock
     BEFORE shipping (learned the hard way — an expired EA wasted full validation).

[S5] MAGIC UNIQUENESS — magic unique per (EA, or (magic,symbol) pair if a binary
     is reused across symbols). No two DIFFERENT strategies share a magic.

[S6] SYMBOL NAME — broker's symbol string matches (EURUSD vs EURUSD.r vs EURUSDm).
     A mismatched symbol = no chart = no trades.

[S7] SESSION HOURS / GMT OFFSET — session-based EAs (London breakout) read server
     time. If the VPS broker's GMT offset differs from the backtest broker, the
     ConsoStart/End hours point at the wrong session. Verify offset or the signal
     never arms.
```

## Step 4 — Record & remind
- Update `D:\EA_LAB\DEMO_DEPLOYMENT_PLAN.md` with the new EA row (symbol, TF, magic, .set, status).
- If deploy is deferred to a "quiet window tonight" task, leave the bundle staged + verified so the user only has to copy-to-VPS + attach.

---

## Delegation map
| Delegate to **qwen [Q]** | Keep in **Claude [C]** |
|---|---|
| Copy source to DataDir, run compile, report .ex5 size | Decide the EA is validated enough to ship |
| Assemble bundle folder, copy .set + .ex5 | Author the README provenance + PF justification |
| | Run the silent-stop checklist (judgment per item) |

## One-line reminders
- Compile path must be INSIDE the DataDir or MT5 opens the GUI and hangs.
- Process lingers ~45s — the .ex5 still appears; check by size, not exit.
- _06_AllowLive=true in the live .set, or it trades nothing.
- Recompile = inputs reset → re-attach in quiet window + reload .set.
- Cent lot must clear broker min; expiry/lock check before shipping.

## FINAL RULE
```
NEXT STEP:
Bundle staged + verified at _vps_deploy/<EA>/.
Copy to VPS, attach in a market-quiet window, load the live .set,
confirm _06_AllowLive=true and the silent-stop checklist before going live.
User attaches the EA on the VPS, then hand off to ea-live-monitor for
ongoing tracking.
```

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.
