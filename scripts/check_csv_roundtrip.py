#!/usr/bin/env python3
"""Refuse a CSV that does not survive being read and written back.

ORDER-1132. `portfolio/DEPLOYMENTS.csv` is the single inventory for real money, and
`scripts/check_state.ps1` runs `ConvertFrom-Csv` over it on EVERY commit. On 2026-08-02
a writer using `csv.DictWriter` truncated it from 65 lines to 9, because 13 rows carried
UNQUOTED commas inside `notes`: every reader parsed them as extra fields, and the writer
either dropped the tail or died.

The truncation was the symptom. The defect is that a row the guard cannot parse faithfully
is a row whose content the guard is not really reading -- the `unreadable-input-must-refuse-
not-skip` family, on the highest-value file in the repo.

Two checks, and they are not the same check:

  ARITY      every row has exactly as many fields as the header.
             Catches the unquoted-comma defect directly.

  ROUNDTRIP  read(write(read(f))) == read(f), compared field by field.
             Catches everything arity cannot: a quote style the writer would change, an
             embedded newline, a trailing-whitespace difference that survives one pass and
             not the next. A file can pass ARITY and still not survive a rewrite.

Exit codes deliberately distinguish three outcomes, because conflating the third with the
first is how a guard goes quiet:

  0  every file checked, every file clean
  1  a real defect -- reported with file, line number, and what was seen
  2  COULD NOT CHECK (no file matched, unreadable, undecodable). Never conflated with 0.

Usage:
    python scripts/check_csv_roundtrip.py portfolio/DEPLOYMENTS.csv
    python scripts/check_csv_roundtrip.py --glob "portfolio/live_deals/*.csv"
    python scripts/check_csv_roundtrip.py --default      # the ORDER-1132 D4 set
"""
from __future__ import annotations

import argparse
import csv
import glob as globmod
import io
import sys
from pathlib import Path

# The D4 set: the inventory, the expectations table beside it, and the exported deal
# history. Nothing suggests DEPLOYMENTS.csv is special, so nothing here treats it as such.
DEFAULT_TARGETS = [
    "portfolio/DEPLOYMENTS.csv",
    "portfolio/expectations.csv",
    "portfolio/live_deals/*.csv",
]


def read_rows(text: str) -> list[list[str]]:
    return list(csv.reader(io.StringIO(text)))


def write_rows(rows: list[list[str]]) -> str:
    buf = io.StringIO()
    # newline='' semantics: StringIO already stores what the writer emits verbatim.
    w = csv.writer(buf, lineterminator="\n")
    w.writerows(rows)
    return buf.getvalue()


def check_file(path: Path) -> tuple[int, list[str]]:
    """Return (worst_exit_code, messages) for one file."""
    msgs: list[str] = []
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as e:
        return 2, [f"{path}: COULD NOT CHECK -- not valid UTF-8 ({e})"]
    except OSError as e:
        return 2, [f"{path}: COULD NOT CHECK -- unreadable ({e})"]

    rows = read_rows(text)
    data = [r for r in rows if r]
    if not data:
        return 2, [f"{path}: COULD NOT CHECK -- no rows"]

    header = data[0]
    n = len(header)
    failed = False

    # --- ARITY -------------------------------------------------------------
    # Enumerate over `rows`, not `data`, so the reported line number is the line
    # number in the file. A message that points at the wrong line costs more than
    # no message: it sends the next reader to a row that is fine.
    for i, r in enumerate(rows, start=1):
        if not r:
            continue
        if len(r) != n:
            failed = True
            tail = ",".join(r[n:])[:80] if len(r) > n else ""
            msgs.append(
                f"{path}:{i}: {len(r)} fields, header has {n}"
                + (f" -- overflow begins: {tail!r}" if tail else "")
            )

    # --- ROUNDTRIP ---------------------------------------------------------
    # Run this even when ARITY failed: the two answer different questions, and a
    # reader who fixes only what the first check named should still be told the
    # file does not survive a rewrite.
    reparsed = read_rows(write_rows(rows))
    if reparsed != rows:
        failed = True
        for i, (before, after) in enumerate(zip(rows, reparsed), start=1):
            if before != after:
                msgs.append(f"{path}:{i}: does not round-trip\n    read : {before}\n    wrote: {after}")
        if len(rows) != len(reparsed):
            msgs.append(f"{path}: row COUNT changed on rewrite: {len(rows)} -> {len(reparsed)}")

    if failed:
        return 1, msgs
    return 0, [f"{path}: OK ({len(data)} rows, {n} cols)"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", help="CSV files to check")
    ap.add_argument("--glob", action="append", default=[], help="glob pattern (repeatable)")
    ap.add_argument("--default", action="store_true", help="check the ORDER-1132 D4 target set")
    ap.add_argument("-q", "--quiet", action="store_true", help="print only failures")
    args = ap.parse_args()

    patterns = list(args.paths) + list(args.glob)
    if args.default:
        patterns += DEFAULT_TARGETS
    if not patterns:
        print("check_csv_roundtrip: COULD NOT CHECK -- no path or pattern given", file=sys.stderr)
        return 2

    targets: list[Path] = []
    for pat in patterns:
        hits = [Path(p) for p in sorted(globmod.glob(pat))]
        if not hits:
            # An empty glob is NOT clean. A pattern that stops matching is exactly how
            # a guard silently stops guarding anything.
            print(f"check_csv_roundtrip: COULD NOT CHECK -- no file matched {pat!r}", file=sys.stderr)
            return 2
        targets += hits

    worst = 0
    failures = 0
    for path in targets:
        code, msgs = check_file(path)
        worst = max(worst, code)
        if code != 0:
            failures += 1
        if code != 0 or not args.quiet:
            for m in msgs:
                print(m)

    print(f"\ncheck_csv_roundtrip: {len(targets)} file(s), {failures} failing")
    return worst


if __name__ == "__main__":
    sys.exit(main())
