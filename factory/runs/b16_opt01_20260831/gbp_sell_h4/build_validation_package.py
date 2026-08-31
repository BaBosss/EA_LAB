from pathlib import Path
import hashlib, json, csv
root = Path(r"D:/EA_LAB_CONTROL/worktrees/b16-gbp-sell-opt01-reanchor-20260831/factory/runs/b16_opt01_20260831/gbp_sell_h4")
parent = Path(r"D:/EA_LAB_CONTROL/worktrees/b16-gbp-sell-opt01-reanchor-20260831/factory/runs/b16_step5_20260830/gbp_sell_tfport01/B16_GBP_SELL_TFPORT_01.set")
b = parent.read_bytes()
old = b"_16_RsiPeriod=14\n"
new = b"_16_RsiPeriod=21\n"
assert b.count(old) == 1
child = b.replace(old, new, 1)
assert child.count(b"||Y") == 0
fixed = root / "B16_GBP_SELL_H4_OPT01_CENTER_21_70.set"
fixed.write_bytes(child)
pl = parent.read_text(encoding="utf-8").splitlines()
cl = fixed.read_text(encoding="utf-8").splitlines()
diffs = [(i + 1, a, c) for i, (a, c) in enumerate(zip(pl, cl)) if a != c]
assert diffs == [(27, "_16_RsiPeriod=14", "_16_RsiPeriod=21")], diffs
sel = root / "selection.json"
s = json.loads(sel.read_text(encoding="utf-8"))
assert s["selected"]["rsi_period"] == 21 and s["selected"]["rsi_high"] == 70 and s["selected"]["eligible"] is True
lock = {"schema":"ea-lab-b16-opt01-center-lock/1","hypothesis_revision":"B16-H05-r1","coarse_head":"0c0d35d5422e85115947e882694f73740766eebe","selection_sha256":hashlib.sha256(sel.read_bytes()).hexdigest(),"fixed_set_sha256":hashlib.sha256(child).hexdigest(),"parent_sell_set_sha256":hashlib.sha256(b).hexdigest(),"selected":{"_16_RsiPeriod":21,"_16_RsiHigh":70.0},"selection_basis":"sole preregistered five-cell orthogonal cross with MAIN net>0 in all five cells","bwd_role":"validation_only_no_retuning","holdout":"UNSPENT","optimization_search_closed":True}
(root / "center_lock.json").write_text(json.dumps(lock, indent=2, sort_keys=True)+"\n", encoding="utf-8")
with (root / "validation_manifest.csv").open("w", newline="", encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["window","symbol","tf","from","to","report_name"]); w.writerow(["MAIN","GBPUSD","H4","2023.01.01","2025.12.31","B16_OPT01_CENTER21_70_GBPUSD_H4_MAIN_M1"]); w.writerow(["BWD","GBPUSD","H4","2020.01.01","2022.12.31","B16_OPT01_CENTER21_70_GBPUSD_H4_BWD_M1"])
print("FIXED_SHA="+lock["fixed_set_sha256"]); print("PARENT_SHA="+lock["parent_sell_set_sha256"]); print("SELECTION_SHA="+lock["selection_sha256"]); print("DIFFS="+repr(diffs))