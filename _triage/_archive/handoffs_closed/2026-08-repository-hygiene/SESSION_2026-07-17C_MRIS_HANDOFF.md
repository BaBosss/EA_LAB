# SESSION HANDOFF — 2026-07-17C — ORDER-073 NewsGuard attach-ready + MRIS macro layer

**Seat:** Claude Opus 4.8 · **Focus:** ORDER-073 (news/macro risk system) end-to-end
**Landed commits (both ON master, verified):**
- `874347f` — ORDER-073/083 NewsGuard attach-ready (runbook rclone fix + GuardConfig draft + Phase-3 stub)
- `3d5d1ac` — ORDER-073 Phase-2.5 MRIS macro-regime intelligence layer (runnable prototype)

> ⚠️ Shared-worktree note: during this session HEAD moved several times (concurrent
> ORDER-098 / ORDER-105 sessions integrating). Both commits above briefly showed
> "off master" mid-integration but settled ON master. If a future check shows them
> missing, they are intact objects — `git merge-base --is-ancestor 3d5d1ac HEAD`.

## What is DONE and usable now

### 1. NewsGuard (event-block layer) — BUILT, awaiting USER attach
- `.ex5`/`.ex4` already compiled in `ea_projects\(Boss)_NewsGuard\`.
- **GuardConfig draft** (paste-and-go, per account): `ea_projects\(Boss)_NewsGuard\GUARDCONFIG_2026-07-17.md`
  - 141049900 (MT4, no-SL/mart): `7777:C;1112:C;1113:C;1114:C;1115:C`
  - 159503454 (MT5, has SL): `990103:B;990101:B;991001:B;991004:B;991002:B`
  - 159475669 (MT5, user-mix): `1524:B;9398:B;939721:B;990005:B;990010:B`
  - Demo accounts: DO NOT ATTACH (keeps forward-test vs backtest comparison clean)
- **Transport runbook fixed to rclone** (VPS = Server 2012 R2, OneDrive client won't
  install): `ea_projects\(Boss)_NewsGuard\VPS_TRANSPORT_AND_ATTACH.md`
- **Blocked on USER:** (a) approve/adjust GuardConfig — esp. `C` on 141049900 WILL
  realize floating grid losses when a news window opens (intended). (b) attach on VPS.

### 2. MRIS (macro-regime layer, #073 reimagined) — PROTOTYPE runs
Run: `& D:\EA_LAB\scripts\mris\mris_run.ps1` → outputs to `portfolio\mris\`
- `mris_classify.ps1` — barometers (AUDJPY/USDJPY/VIX/DXY/XAUUSD/BTCUSD) + RELATIVE
  tripwires (SMA200/ATR; `110` is an optional `user_pin`, not a rule constant) →
  state RISK_ON/NEUTRAL/RISK_OFF/STRESS + Risk Index + confidence. **Verified: state
  machine flips RISK_ON↔STRESS correctly** (carry-unwind scenario → STRESS, conf HIGH).
- `mris_exposure.ps1` — joins DEPLOYMENTS.csv → tags 8 JPY-cross legs DIRECT_CARRY +
  8 RISK_ON → per-state action (reduce-lot ×0.5 + block-new; **never auto-close**).
- `mris_brief.ps1` — Thai whisper brief (md + html dashboard fragment). Thai/emoji live
  in `brief_templates.json` (keeps .ps1 pure-ASCII; PS5.1 mis-reads non-BOM non-ASCII).
- `mris_run.ps1` — one-shot orchestrator. `README.md` — full architecture.
- Feeder: `_mt5_auto\mris\Export_Barometers.mq5` (broker-priced barometers → CSV).
- **Seed snapshot** `portfolio\mris\barometer_snapshot.csv` (real 2026-07-16 spot +
  trend-context SMA/ATR) reads **NEUTRAL, 2 loaded lines**: AUDJPY ~3% above 110 pin,
  USDJPY 161 crowded/extreme. Matches the AUD/JPY north-star article's warning setup.

## What is NOT done (next session)

1. **Web feeder for VIX / DXY / US10Y-JP10Y spread / copper** — broker has none; they
   are `data_status=PENDING` and excluded from the Risk Index. Build a PowerShell web
   feeder (same pattern as `scripts\news_calendar.ps1`) to fill them → completes the
   "parallel warning lines" signal. **This is the single highest-value next step.**
2. **User locks tripwire thresholds** — every threshold in `scripts\mris\barometers.json`
   is currently Claude's default. Per #073, the USER owns these numbers (110, ATR
   mults, VIX bands). Needs a short MRIS session with the user.
3. **Wire MRIS brief into LIVE_DASHBOARD gist** (mobile morning view) + add to daily chain.
4. **Phase-3 MacroGate** (STUB in taskboard) — NewsGuard-style watchdog that reduce-lot/
   block-new on carry legs during RISK_OFF. **Do NOT build until (1)+(2) done** and the
   trigger rule passes A/B backtest on the 2024-08-05 carry-unwind window + 2020-03.

## Pointers
- Taskboard: `AGENT_TASKBOARD.md` → ORDER-073 (Phase-2 NewsGuard / Phase-2.5 MRIS / Phase-3 stub)
- #073 original design prompt: `_triage\MACRO_REGIME_SYSTEM_PROMPT.md`
- New-session prompt to continue: `handoff\NEXT_SESSION_MRIS_PROMPT.md`
