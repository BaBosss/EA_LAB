#!/usr/bin/env python3
"""gen_plan_set.py - generate an MT5 optimize .set for a Boss Lab V2 strategy plan.

Plans (A-E) encode the V2 dropdown codes + coarse 3-step optimize ranges from
OPTIMIZE_GUIDE.md. Because risk params are ATR-multiples, the ranges are mostly
instrument-agnostic; only `lot` and the entry param differ.

MT5 optimize line format:  name=current||start||step||stop||Y   (Y=optimize, N=fixed)
Fixed value line:          name=value

Usage:
  python gen_plan_set.py --plan D --out BossV2_12_PlanD.set [--lot 0.01]
  python gen_plan_set.py --plan C --out BossV2_11_PlanC.set
  python gen_plan_set.py --list
"""
import argparse
import sys

# each plan: fixed mode selectors + optimize ranges (param -> (start, step, stop))
# codes per DESIGN_V2 numbering. ATR-mult ranges are instrument-agnostic.
PLANS = {
    "A_SCALP": {
        "desc": "Scalp - small ATR TP, tight SL, single (FX M5-M15)",
        "fixed": {"ExitMode": 22, "SLMode": 33, "StackMode": 90, "StackConfirm": 0,
                  "TrendFilter": 70, "FirstLotMode": 41, "LotProg": 50, "ProtectLevel": 1},
        "opt": {"_22_TP_ATRmult": (0.5, 0.5, 1.5),
                "_33_SL_ATRmult": (1.0, 0.5, 2.0)},
    },
    "B_SWING": {
        "desc": "Swing - large ATR TP, wide SL, single (Gold, FX trend)",
        "fixed": {"ExitMode": 22, "SLMode": 33, "StackMode": 90, "StackConfirm": 0,
                  "TrendFilter": 70, "FirstLotMode": 41, "LotProg": 50, "ProtectLevel": 2},
        "opt": {"_22_TP_ATRmult": (4.0, 2.0, 8.0),
                "_33_SL_ATRmult": (2.0, 1.0, 4.0)},
    },
    "C_TREND": {
        "desc": "Trend - run-trend exit, grid-trend stack, ATR-expand filter (entry 11)",
        "fixed": {"ExitMode": 24, "SLMode": 33, "StackMode": 91, "StackConfirm": 1,
                  "TrendFilter": 71, "FirstLotMode": 41, "LotProg": 50, "ProtectLevel": 2},
        "opt": {"_0_SlowMA":     (30, 20, 100),
                "_33_SL_ATRmult": (2.0, 1.0, 3.0),
                "_9_MaxLevels":   (3, 2, 8)},
    },
    "D_BREAKOUT": {
        "desc": "Breakout - ATR TP, ATR SL, single (entry 12; Gold/WTI/session)",
        "fixed": {"ExitMode": 22, "SLMode": 33, "StackMode": 90, "StackConfirm": 0,
                  "TrendFilter": 70, "FirstLotMode": 41, "LotProg": 50, "ProtectLevel": 1},
        "opt": {"_12_Bars":       (20, 20, 60),
                "_22_TP_ATRmult": (3.0, 1.0, 5.0),
                "_33_SL_ATRmult": (1.5, 0.5, 2.0)},
    },
    "E_GRID": {
        "desc": "Grid - basket exit, DCA/grid stack, NO per-order SL (WARN: MC ruin first)",
        "fixed": {"ExitMode": 21, "SLMode": 30, "StackMode": 91, "StackConfirm": 3,
                  "TrendFilter": 70, "FirstLotMode": 41, "LotProg": 50, "ProtectLevel": 3,
                  "_9_StepUseATR": 1},
        "opt": {"_9_StepATRmult": (0.5, 0.5, 2.0),
                "_9_MaxLevels":   (3, 2, 8),
                "_52_ProgMult":   (1.0, 0.15, 1.3)},
    },
}

ALIASES = {"A": "A_SCALP", "B": "B_SWING", "C": "C_TREND", "D": "D_BREAKOUT", "E": "E_GRID"}


def fmt(v):
    if isinstance(v, float):
        s = ("%.4f" % v).rstrip("0").rstrip(".")
        return s if s else "0"
    return str(v)


def gen(plan_key, lot):
    p = PLANS[plan_key]
    lines = [f"; Boss Lab V2 - Plan {plan_key} : {p['desc']}",
             f"; ATR-mult ranges are instrument-agnostic. lot={lot}",
             ";"]
    for k, v in p["fixed"].items():
        lines.append(f"{k}={fmt(v)}")
    lines.append(f"_41_FixedLot={fmt(lot)}||{fmt(lot)}||0||{fmt(lot)}||N")
    for name, (start, step, stop) in p["opt"].items():
        cur = start
        lines.append(f"{name}={fmt(cur)}||{fmt(start)}||{fmt(step)}||{fmt(stop)}||Y")
    n_combos = 1
    for (s, st, sp) in p["opt"].values():
        steps = int(round((sp - s) / st)) + 1 if st else 1
        n_combos *= max(steps, 1)
    lines.append(f"; combos ~= {n_combos}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", help="A-E or full key (A_SCALP..E_GRID)")
    ap.add_argument("--out", help="output .set path")
    ap.add_argument("--lot", type=float, default=0.01, help="fixed lot (gold/crypto: 0.01)")
    ap.add_argument("--list", action="store_true", help="list plans")
    a = ap.parse_args()

    if a.list or not a.plan:
        print("Plans:")
        for k, v in PLANS.items():
            opt = ", ".join(v["opt"].keys())
            print(f"  {k:12s} {v['desc']}\n               optimize: {opt}")
        return

    key = ALIASES.get(a.plan.upper(), a.plan.upper())
    if key not in PLANS:
        sys.exit(f"unknown plan '{a.plan}' (use --list)")
    content = gen(key, a.lot)
    if a.out:
        with open(a.out, "w", encoding="ascii") as f:
            f.write(content)
        print(f"wrote {a.out}")
    print(content)


if __name__ == "__main__":
    main()
