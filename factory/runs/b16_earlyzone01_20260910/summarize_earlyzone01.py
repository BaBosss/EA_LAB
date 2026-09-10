from __future__ import annotations
import csv, hashlib, json, re
from pathlib import Path

RUN = Path(__file__).resolve().parent
EXPECTED = {
    "parent_set": "7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782",
    "child_set": "551385b8a1b16141f3924315988bdf101d12a6aee2246ac1eb59ff1ba16ad88f",
    "ex5": "212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db",
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def loadj(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def pct_from_relative(text: str) -> float:
    m = re.search(r"([-+0-9.]+)%", text)
    if not m:
        raise ValueError(f"cannot parse EqDD%: {text!r}")
    return float(m.group(1))

def tester_inputs(ini: Path) -> dict[str, str]:
    out = {}
    section = None
    for raw in ini.read_text(encoding="utf-8-sig").splitlines():
        s = raw.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s
            continue
        if section == "[TesterInputs]" and "=" in s and not s.startswith(";"):
            k, v = s.split("=", 1); out[k] = v
    return out

parent = loadj(RUN / "parent_analysis.json")
child = loadj(RUN / "child_analysis.json")
receipts = [json.loads(x) for x in (RUN / "run_receipts.jsonl").read_text(encoding="utf-8").splitlines() if x.strip()]
if len(receipts) != 4:
    raise SystemExit(f"expected 4 receipts, got {len(receipts)}")

parent_set = RUN / "B16_XAU_M15_EARLYZONE01_PARENT.set"
child_set = RUN / "B16_XAU_M15_EARLYZONE01_CHILD.set"
if sha(parent_set) != EXPECTED["parent_set"] or sha(child_set) != EXPECTED["child_set"]:
    raise SystemExit("set hash mismatch")

mechanical = {"state": "PASS", "cells": [], "sole_executed_input_change": None, "source_mtime_warning": "RECONCILE_BY_HASH"}
rows = []
years = []
for arm_name, data in (("PARENT", parent), ("CHILD", child)):
    for window in ("MAIN", "BWD"):
        node = data[window.lower()]
        rpt = node["identity"]["report"]
        ini_id = node["identity"]["ini"]
        cell = RUN / "runtime" / arm_name / window
        lev = loadj(cell / "leverage_check.json")
        trunc = loadj(cell / "truncation_check.json")
        receipt = next(r for r in receipts if r["arm"] == arm_name and r["window"] == window)
        checks = {
            "symbol": rpt["symbol"] == "XAUUSD" and ini_id["Symbol"] == "XAUUSD",
            "period": rpt["period"] == "M15" and ini_id["Period"] == "M15",
            "model": ini_id["Model"] == "1", "optimization": ini_id["Optimization"] == "0",
            "deposit": ini_id["Deposit"] == "10000", "leverage": lev.get("status") == "MATCH",
            "truncation": trunc.get("checker_exit_code") == 0,
            "report_hash": sha(cell / "report.htm") == receipt["report_sha256"],
            "set_hash": receipt["set_sha256"] == EXPECTED[arm_name.lower() + "_set"],
            "ex5_hash": receipt["ex5_sha256"] == EXPECTED["ex5"],
        }
        if not all(checks.values()):
            mechanical["state"] = "FAIL"
        metrics = {
            "arm": arm_name, "window": window,
            "net": rpt["net_profit"], "pf": rpt["profit_factor"],
            "trades": rpt["total_trades"], "eqdd_pct": pct_from_relative(rpt["equity_drawdown_relative"]),
            "max_depth": node["exposure"]["max_basket_depth"],
            "report_sha256": receipt["report_sha256"], "checks": checks,
        }
        rows.append(metrics)
        mechanical["cells"].append(metrics)
        for b in node["bins"]:
            if re.fullmatch(r"20\d\d", b["bin"]):
                years.append({"arm": arm_name, "window": window, "year": int(b["bin"]),
                              "net": b["net_profit"], "pf": b["profit_factor"],
                              "trades": b["closed_ticket_count"], "cycles": b["cycle_count"]})

for window in ("MAIN", "BWD"):
    p = tester_inputs(RUN / "runtime" / "PARENT" / window / "tester.ini")
    c = tester_inputs(RUN / "runtime" / "CHILD" / window / "tester.ini")
    diffs = {k: [p.get(k), c.get(k)] for k in sorted(set(p) | set(c)) if p.get(k) != c.get(k)}
    if diffs != {"_16_AtrMultFirst4": ["0.8", "1.4"]}:
        mechanical["state"] = "FAIL"
        raise SystemExit(f"unexpected executed-input diff {window}: {diffs}")
mechanical["sole_executed_input_change"] = {"_16_AtrMultFirst4": [0.8, 1.4]}

by = {(r["arm"], r["window"]): r for r in rows}
comparison = {"mechanical_state": mechanical["state"], "windows": {}, "classification": None, "pareto_nonworse": None}
for window in ("MAIN", "BWD"):
    p, c = by[("PARENT", window)], by[("CHILD", window)]
    comparison["windows"][window] = {
        "parent": p, "child": c,
        "delta": {"net": round(c["net"]-p["net"],2), "pf": round(c["pf"]-p["pf"],4),
                  "trades": c["trades"]-p["trades"], "eqdd_pp": round(c["eqdd_pct"]-p["eqdd_pct"],2)}
    }
if mechanical["state"] != "PASS":
    comparison["classification"] = "BLOCKED_MECHANICAL_ACCEPTANCE"
elif any(by[("CHILD", w)]["net"] <= 0 for w in ("MAIN", "BWD")):
    comparison["classification"] = "HYPOTHESIS_FALSIFIED / EARLY_COMPRESSION_SIGN_RELEVANT"
else:
    comparison["classification"] = "HYPOTHESIS_NOT_FALSIFIED / DUAL_WINDOW_SIGN_SURVIVES_WIDER_EARLY_ZONE"
comparison["pareto_nonworse"] = all(
    by[("CHILD", w)]["net"] >= by[("PARENT", w)]["net"] and
    by[("CHILD", w)]["eqdd_pct"] <= by[("PARENT", w)]["eqdd_pct"]
    for w in ("MAIN", "BWD")
)
comparison["decision"] = (
    "SYMMETRIC_WIDER_SPACING_SIGN_ADMISSIBLE_BUT_NOT_IMPROVEMENT_DIRECTION"
    if comparison["classification"].startswith("HYPOTHESIS_NOT_FALSIFIED") and not comparison["pareto_nonworse"]
    else "SEE_CLASSIFICATION"
)

(RUN / "mechanical_acceptance.json").write_text(json.dumps(mechanical, indent=2, sort_keys=True)+"\n", encoding="utf-8")
(RUN / "comparison.json").write_text(json.dumps(comparison, indent=2, sort_keys=True)+"\n", encoding="utf-8")
with (RUN / "cell_summary.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["arm","window","net","pf","trades","eqdd_pct","max_depth","report_sha256"])
    w.writeheader(); w.writerows({k:r[k] for k in w.fieldnames} for r in rows)
with (RUN / "year_split.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["arm","window","year","net","pf","trades","cycles"])
    w.writeheader(); w.writerows(years)
print(json.dumps({"mechanical": mechanical["state"], "classification": comparison["classification"],
                  "pareto_nonworse": comparison["pareto_nonworse"], "decision": comparison["decision"]}, sort_keys=True))
