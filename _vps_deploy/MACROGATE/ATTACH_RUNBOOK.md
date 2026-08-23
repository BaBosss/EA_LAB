# MacroGate — attach-once runbook (do all of this in one pass)

> **AS-DEPLOYED 2026-07-18:** the user attached via the simpler **manual-weekly** mode in
> `_vps_deploy/MACROGATE_READY/README_TH.md` (copy the regime CSV to Common\Files on each RDP,
> `InpStaleMaxHours=200` + `InpRowStaleMaxHours=200`). That is the live method — follow READY
> for re-attach/reboot. STEP 1 below is the Guard Feed runtime rollout; until it passes verification it is not
> what is running now. STEPs 2-5 are identical to what was done.

Everything on the lab/dev side is DONE (export script wired, both EAs compiled+bundled).
Below is the full manual sequence for you. It reuses the existing NewsGuard rclone pipe —
no new OneDrive/rclone setup needed.

Bundles:
- `_vps_deploy/MACROGATE/(Boss)_MacroGate.ex5`      — the watchdog
- `_vps_deploy/MACROGATE_DEMOLEG/Boss_12_Breakout.ex5` — the demo carry-leg to gate

---

## STEP 1 - rollout and verify Guard Feed automation

Until this runtime rollout is completed, the 2026-07-18 AS-DEPLOYED method above remains
manual-weekly with `InpStaleMaxHours=200` and `InpRowStaleMaxHours=200`.

1. Lab: run the normal daily chain and confirm both `portfolio\news_week.csv` and
   `portfolio\EA_LAB_mris_regime.csv` are fresh and both staged OneDrive files exist.
2. VPS worker directory: deploy BOTH `vps_rclone\pull_news.cmd` and
   `vps_rclone\pull_guard_feeds.ps1` from the same accepted commit. Do not deploy only the `.cmd`.
3. Keep the existing scheduled task pointed at `pull_news.cmd`; it now invokes the PowerShell worker.
4. Run/observe one pass and require `C:\rclone\logs\pull_guard_feeds.log` to end with
   `guard feed pull COMPLETE`.
5. Confirm both `EA_LAB_news_week.csv` and `EA_LAB_mris_regime.csv` are fresh in VPS `Common\Files`.

After those checks pass, recurring weekly regime copy is retired. Manual copy remains emergency fallback only.

---
## STEP 2 — attach the demo carry-leg (DEMO MT5 account)

Per `_vps_deploy/MACROGATE_DEMOLEG/README.md`:
1. Copy `Boss_12_Breakout.ex5` into `MQL5\Experts\`, refresh Navigator.
2. Attach to **USDJPY H1**, Algo Trading ON.
3. Inputs → `_0_Magic = 990120`, everything else default → **Save** as
   `Boss12_Breakout_USDJPY_H1_demoleg.set` → OK.

---

## STEP 3 — attach the MacroGate watchdog (same DEMO terminal)

Per `_vps_deploy/MACROGATE/README.md`:
1. Copy `(Boss)_MacroGate.ex5` into `MQL5\Experts\`, refresh Navigator.
2. Attach to ANY one chart (it trades nothing), Algo Trading ON.
3. Inputs: `InpMagicsCsv = 990120`, `InpLotMult = 0.5`, `InpBlockNew = true`,
   `InpRegimeInCommon = true`, `InpStaleMaxHours = 200`, `InpRowStaleMaxHours = 200` -> OK.
4. Save both charts into the startup profile so a VPS reboot reloads them.

---

## STEP 4 — verify end-to-end (Experts log)

On the MacroGate chart's Experts log you should see, in order:
- `regime loaded: N row(s), ... server = CSV +0 h`   ← CSV read OK
- `guard carry magic=990120`                          ← magic registered
- today is NEUTRAL, so **no gate** (correct). To prove the gate fires without waiting for a
  real risk-off, temporarily drop one `STRESS` row dated today into the CSV on the VPS
  (`Common\Files`), wait one `InpTimerSeconds` (5 min) → log prints
  `gate ON magic=990120 state=STRESS lotMult=0.50 block=1`, and `MACROGATE_BLOCK_990120`
  appears in the terminal's Global Variables (F3). Remove the test row afterwards; the daily
  pipe overwrites it anyway.

If you see `regime file ... NOT FOUND / STALE` → STEP 1 transport isn't landing the file.

---

## STEP 5 — register + tell me the date

Add the demo-leg row to `portfolio/DEPLOYMENTS.csv` (template in the DEMOLEG README) and tell
me the attach date so I log it. Judge after ~3 months of demo + one risk-off episode; only
then do we discuss recompiling a LIVE breakout leg with the bridge.

---

### What we did NOT touch (on purpose)
- No live-money account. Live carry legs (EA_BREAKOUT_XAU etc.) are standalone and can't read
  the gate — retrofitting them = recompile + redeploy, a separate decision after demo proof.
- MacroGate evidence is 1 in-sample window (2024). Demo-first is the whole point of this pass.
