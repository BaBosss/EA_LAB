#!/usr/bin/env python3
from pathlib import Path
import csv, json, gzip, hashlib
import xml.etree.ElementTree as ET

WT = Path(r"D:\EA_LAB_CONTROL\worktrees\b16-characterization-final-20260830")
ROOT = WT / "factory/runs/b16_characterization_20260830"
AGG = ROOT / "aggregate"
EVIDENCE = ROOT / "evidence"
FINAL = ROOT / "final_report"

with (AGG / "cell_summary.csv").open(encoding="utf-8-sig", newline="") as f:
    cells = list(csv.DictReader(f))
assert len(cells) == 88
assert len({(r["variant"], r["context"], r["window"]) for r in cells}) == 88
for row in cells:
    d = EVIDENCE / row["variant"] / row["context"] / row["window"]
    for name in ("report.htm.gz", "tester.ini", "leverage_check.json", "truncation_check.json"):
        assert (d / name).is_file(), (row, name)
    raw = gzip.decompress((d / "report.htm.gz").read_bytes())
    assert hashlib.sha256(raw).hexdigest() == row["report_sha256"], row

with (AGG / "pair_falsifier_summary.csv").open(encoding="utf-8-sig", newline="") as f:
    pairs = list(csv.DictReader(f))
assert len(pairs) == 45
counts = {}
for row in pairs:
    counts[row["verdict"]] = counts.get(row["verdict"], 0) + 1
assert counts == {"HYPOTHESIS_FALSIFIED": 18, "HYPOTHESIS_NOT_FALSIFIED": 24, "UNKNOWN_MECHANICAL_INELIGIBLE": 3}
mech = json.loads((AGG / "mechanical_acceptance.json").read_text(encoding="utf-8"))
assert mech["new_cells"] == 88
assert mech["full_window_eligible_cells"] == 84
assert mech["cage_kill_ineligible_cells"] == 4
assert mech["unresolved_suspect_cells"] == 0
kills = json.loads((AGG / "cage_kill_evidence.json").read_text(encoding="utf-8"))
assert len(kills) == 4
assert sum(1 for r in cells if r["full_window_eligible"].lower() == "false") == 4
svgs = list(FINAL.glob("*.svg"))
assert len(svgs) == 14
for path in svgs:
    ET.parse(path)
    assert path.stat().st_size > 500
summary = json.loads((FINAL / "final_summary.json").read_text(encoding="utf-8"))
assert summary["mechanism_value"] == "STRONG" and summary["new_cells"] == 88
report = (WT / "docs/research/B16_MECHANISM_CHARACTERIZATION_REPORT_20260830.md").read_text(encoding="utf-8")
for token in ("88 unique Strategy Tester reports", "84/88 full-window eligible", "MECHANISM_VALUE = STRONG", "HOLDOUT: `UNSPENT`", "GBPUSD/H4", "UNKNOWN_MECHANICAL_INELIGIBLE"):
    assert token in report, token
recon = (AGG / "source_byte_reconciliation_final.txt").read_text(encoding="utf-8")
assert "result=IDENTICAL_RELEVANT_EXECUTION_BYTES" in recon
print("RAW_HASH_PASS=88/88")
print("PAIR_VERDICTS=" + json.dumps(counts, sort_keys=True))
print("SVG_XML_PASS=14")
print("REPORT_QA_PASS")
