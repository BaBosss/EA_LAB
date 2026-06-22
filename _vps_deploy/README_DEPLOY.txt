VPS DEPLOY — EA_BREAKOUT_XAU param-rename update (2026-06-22)
=============================================================
Two files to ship to the VPS:
  EA_BREAKOUT_XAU.ex5      → VPS MQL5\Experts\   (overwrite old)
  BRK_XAU_live_v2.set      → load as the EA inputs after attaching

STEPS ON VPS:
  1. Copy EA_BREAKOUT_XAU.ex5 into the VPS terminal's MQL5\Experts\ folder.
  2. On the XAUUSD H1 chart: remove the old EA, re-attach EA_BREAKOUT_XAU.
  3. In the EA inputs dialog: Load → BRK_XAU_live_v2.set.
  4. Confirm _06_AllowLive = true and AutoTrading is ON.
  5. Verify in the Experts log: "init | AllowLive=YES".

WHY: source params were renamed Inp* → _NN_. The old .ex5 + old .set would
silently disable live orders if mismatched. This .ex5 + v2.set are the matched pair.
The 0.01 lot / magic 991001 / all validated params are unchanged.
