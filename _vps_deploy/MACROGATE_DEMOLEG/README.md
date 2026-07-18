# MACROGATE demo carry-leg — Boss_12_Breakout (validation vehicle)

**Purpose:** give MacroGate a real chassis breakout leg to gate on DEMO, so you can watch the
gate actually fire during the next risk-off before committing anything on live money. This is
the exact EA that was A/B-validated (eqDD −54..−56% on USDJPY/AUDJPY full-year 2024). It is a
demo plumbing-validation, **not** a new live-edge bet — deploy small, demo only.

## Files
- `Boss_12_Breakout.ex5` — recompiled 2026-07-18, 0/0, against the current core (GV bridge
  `Exec_Open → Exec_MacroBlocked` is compiled in; confirmed via source chain).

## Attach (on a DEMO MT5 account only)
1. Copy `Boss_12_Breakout.ex5` into the terminal's `MQL5\Experts\` (refresh Navigator).
2. Attach it to **USDJPY H1** (the validated carry symbol). "Allow Algo Trading" ON.
3. In Inputs, set **`_0_Magic = 990120`** (free magic; reserved for this leg).
   Leave every other input at chassis default — the A/B validation used defaults.
4. Click **Save** (bottom of the Inputs tab) → save as `Boss12_Breakout_USDJPY_H1_demoleg.set`.
   > Saving on the target terminal guarantees a broker-valid .set (correct lot step / digits).
   > Do NOT hand-edit a .set from another broker — the LabCore chassis has many numbered
   > params and a wrong one changes behavior silently.
5. OK. It now trades USDJPY H1 breakouts on demo and reads the MacroGate GVs.

## Then wire the gate to it
In the MACROGATE bundle, set `InpMagicsCsv = 990120`. When the regime CSV shows RISK_OFF/
STRESS, the Experts log prints `gate ON magic=990120 ...` and this leg's new entries get
vetoed / lot-shrunk. That's the end-to-end proof.

## Register after attach
Add to `portfolio/DEPLOYMENTS.csv`:
`<demo-acct>,<name>,DEMO,MT5,VPS 66.212.22.7,Boss_12_Breakout,990120,USDJPY,ACTIVE,closedDD 25%,<judge+3mo>,<attach-date>,MacroGate demo carry-leg (ORDER-073 P3 gate validation)`
