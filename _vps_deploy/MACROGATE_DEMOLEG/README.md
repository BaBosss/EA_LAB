# MACROGATE demo carry-leg — Boss_12_Breakout (plumbing sensor)

> ## ⚠️ EVIDENCE WITHDRAWN 2026-07-25 (ORDER-211) — read before citing anything here
> The **"eqDD −54..−56%"** figure this README used to lead with is **dead and must not be quoted
> anywhere again.** It was measured through the broken MRIS classifier, which flagged 82 risk-off
> days in 2024 where the corrected one flags 47 — the old gate closed the door ~75% too often, so
> the benefit was overstated. Re-measured on the corrected timeline: **PF drops in all four cells**
> and USDJPY full-2024 eqDD falls from −55.7% to **−7.1%**.
>
> MacroGate's standing is now **ADVISORY-ONLY**, not a validated deploy-candidate.
>
> **This leg is on the wrong symbol to answer anything.** The timing value that survived is on
> **AUDJPY** (blocks 19–32% of trades, cuts eqDD 44–53% = more than its share), not USDJPY
> (blocks 16–35%, cuts eqDD only 7–21% = less than its share). The attached leg is USDJPY.
>
> **Do not "fix" that by moving it to AUDJPY** (Claude/Opus 2026-07-26): the host itself loses
> money with the gate both ON and OFF, on both symbols (2024 net −8.82 / −58.36). On a losing host
> you cannot separate "gated the right moments" from "simply traded less" — the symbol is not the
> binding constraint, the host is. Judge the gate on a host with positive expectancy, or not at all.
>
> **What this leg is still good for, and the only reason to keep it:** we have never seen the
> GlobalVariable bridge fire on a live terminal during a real risk-off (only in the tester —
> `regime loaded: 262 row(s)`, 25,105 block events). Keep it attached as a **plumbing sensor**.
> It is **not** gathering edge evidence. Cost to keep = one demo chart.

**Purpose (as originally written — the validation framing below is superseded by the banner):**
give MacroGate a real chassis breakout leg to gate on DEMO, so you can watch the gate actually
fire during the next risk-off before committing anything on live money. It is a demo
plumbing-validation, **not** a new live-edge bet — deploy small, demo only.

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
