# MacroGate — attach-once runbook (do all of this in one pass)

> **AS-DEPLOYED 2026-07-18:** the user attached via the simpler **manual-weekly** mode in
> `_vps_deploy/MACROGATE_READY/README_TH.md` (copy the regime CSV to Common\Files on each RDP,
> `InpStaleMaxHours=200` + `InpRowStaleMaxHours=200`). That is the live method — follow READY
> for re-attach/reboot. STEP 1 below (rclone daily automation) is the **future** upgrade, not
> what is running now. STEPs 2-5 are identical to what was done.

Everything on the lab/dev side is DONE (export script wired, both EAs compiled+bundled).
Below is the full manual sequence for you. It reuses the existing NewsGuard rclone pipe —
no new OneDrive/rclone setup needed.

Bundles:
- `_vps_deploy/MACROGATE/(Boss)_MacroGate.ex5`      — the watchdog
- `_vps_deploy/MACROGATE_DEMOLEG/Boss_12_Breakout.ex5` — the demo carry-leg to gate

---

## STEP 1 — get the regime CSV onto the VPS (rides the NewsGuard pipe)

The lab daily chain now writes `D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv` (verified) and
copies it to the lab's local `Common\Files`. To reach the VPS, add it to the SAME lab→VPS
OneDrive folder used for the news CSV:

1. **Lab side:** in your `lab-to-vps` publish task (the one that stages `EA_LAB_news_week.csv`),
   add a second atomic copy of `D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv` →
   `lab-to-vps\news\EA_LAB_mris_regime.csv` (same folder is fine; one writer).
2. **VPS side:** in the 5-min rclone pull task, add `EA_LAB_mris_regime.csv` to the pulled
   file list and copy it (atomic `.tmp`→rename) into the terminal's `Common\Files`.
   Reject if missing / zero bytes / older than 48 h (MacroGate's staleness gate).

> Reference for the pipe details, security boundaries, atomic publish, task settings:
> `ea_projects/(Boss)_NewsGuard/VPS_TRANSPORT_AND_ATTACH.md` — the regime CSV follows it
> verbatim, just a second filename.

**Check before moving on:** open the VPS terminal → File → Open Data Folder →
`...\Common\Files\` and confirm `EA_LAB_mris_regime.csv` is there and fresh.

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
   `InpRegimeInCommon = true`, rest default → OK.
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
