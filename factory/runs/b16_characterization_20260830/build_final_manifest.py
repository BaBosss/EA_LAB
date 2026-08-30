#!/usr/bin/env python3
from pathlib import Path
import hashlib

WT = Path(r"D:\EA_LAB_CONTROL\worktrees\b16-characterization-final-20260830")
ROOT = WT / "factory/runs/b16_characterization_20260830"
OUT = ROOT / "artifacts.sha256"
files = []
for base in (ROOT / "aggregate", ROOT / "evidence", ROOT / "final_report"):
    files.extend(p for p in base.rglob("*") if p.is_file())
for rel in (
    "build_characterization_evidence.py", "build_final_visuals.py", "qa_final_characterization.py",
    "execution_console.log.gz", "run_receipts.jsonl",
    "extension_eurgbp_h4/execution_console.log.gz", "extension_eurgbp_h4/run_receipts.jsonl",
):
    files.append(ROOT / rel)
files.extend([
    WT / "docs/research/B16_MECHANISM_CHARACTERIZATION_REPORT_20260830.md",
    WT / "docs/research/B16_MECHANISM_WORKFLOW.md",
])
lines = []
for path in sorted(set(files), key=lambda p: p.as_posix().lower()):
    assert path.is_file(), path
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(f"{digest}  {path.relative_to(WT).as_posix()}")
OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"MANIFEST_FILES={len(lines)}")
print(f"MANIFEST_SHA256={hashlib.sha256(OUT.read_bytes()).hexdigest()}")
