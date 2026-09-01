from pathlib import Path
import csv, hashlib, json, subprocess

ROOT = Path(__file__).resolve().parent
WT = ROOT.parents[3]
sel_path = ROOT / "selection.json"
sel = json.loads(sel_path.read_text(encoding="utf-8"))
selected = sel.get("selected")
assert sel["grid_complete"] is True and sel["grid_rows"] == 20
assert selected and selected["eligible"] is True
assert (selected["rsi_period"], selected["rsi_low"]) == (14, 35)
assert selected["min_trades"] >= 100 and selected["min_net"] > 0

parent_path = ROOT / "B16_USDJPY_BUY_H1_PARENT.set"
parent = parent_path.read_bytes()
old = b"_16_RsiLow=30.0\n"
new = b"_16_RsiLow=35.0\n"
assert parent.count(old) == 1
child = parent.replace(old, new, 1)
assert b"||Y" not in child
fixed_path = ROOT / "B16_USDJPY_BUY_H1_OPT01_CENTER_14_35.set"
fixed_path.write_bytes(child)
pl = parent.decode("utf-8").splitlines()
cl = child.decode("utf-8").splitlines()
diffs = [(i + 1, a, b) for i, (a, b) in enumerate(zip(pl, cl)) if a != b]
assert diffs == [(28, "_16_RsiLow=30.0", "_16_RsiLow=35.0")], diffs

head = subprocess.check_output(["git", "-C", str(WT), "rev-parse", "HEAD"], text=True).strip()
base = subprocess.check_output(["git", "-C", str(WT), "rev-parse", "HEAD~3"], text=True).strip()
opt_receipt = json.loads((ROOT / "optimization_receipt.json").read_text(encoding="utf-8"))
lock = {
    "schema": "ea-lab-b16-h08-center-lock/1",
    "hypothesis_revision": "B16-H08-r1",
    "reanchor_head_before_lock": head,
    "reanchor_canonical_base": base,
    "source_execution_head": opt_receipt["head_sha"],
    "selection_sha256": hashlib.sha256(sel_path.read_bytes()).hexdigest(),
    "optimizer_xml_sha256": hashlib.sha256((ROOT / "optimizer.xml").read_bytes()).hexdigest(),
    "parent_set_sha256": hashlib.sha256(parent).hexdigest(),
    "fixed_set_sha256": hashlib.sha256(child).hexdigest(),
    "selected": {"_16_RsiPeriod": 14, "_16_RsiLow": 35.0},
    "selection_basis": "preregistered participation-qualified five-cell cross max-min MAIN net rule",
    "bwd_role": "validation_only_no_retuning",
    "holdout": "UNSPENT",
    "optimization_search_closed": True,
}
(ROOT / "center_lock.json").write_text(json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8")
with (ROOT / "validation_manifest.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["window", "symbol", "tf", "from", "to", "report_name"])
    w.writerow(["MAIN", "USDJPY", "H1", "2023.01.01", "2025.12.31", "B16_H08_CENTER14_35_USDJPY_H1_MAIN_M1"])
    w.writerow(["BWD", "USDJPY", "H1", "2020.01.01", "2022.12.31", "B16_H08_CENTER14_35_USDJPY_H1_BWD_M1"])
print("FIXED_SHA=" + lock["fixed_set_sha256"])
print("SELECTION_SHA=" + lock["selection_sha256"])
print("OPT_XML_SHA=" + lock["optimizer_xml_sha256"])
print("DIFFS=" + repr(diffs))
