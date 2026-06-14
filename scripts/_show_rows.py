#!/usr/bin/env python3
"""Print RUN_REGISTRY rows whose file name contains <substring>. Clean stdout."""
import csv
import sys

code = sys.argv[1] if len(sys.argv) > 1 else ""
path = r"D:\EA_LAB\RUN_REGISTRY.csv"
rows = [r for r in csv.DictReader(open(path, encoding="utf-8")) if code in r["file"]]
for r in rows:
    print(f"{r['verdict']:7} score {r['score']:>5} | {r['symbol']} "
          f"PF {r['PF']} DD {r['DD%']} RF {r['RF']} trades {r['trades']} net {r['net']} "
          f"| {r['file'].split(chr(92))[-1]}")
if not rows:
    print(f"(no rows matching '{code}')")
