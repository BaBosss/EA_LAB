#!/usr/bin/env python3
"""Migrate pilot crypto financing metadata from the original MT5 reports.

ORDER-1350/1370: MT5's BTCUSD reports already include a non-zero Swap column.
Pilot metrics are copied straight from those reports, so a post-hoc financing estimate
must be retained only as provenance and must never be represented as having changed a
tester-native PF/gross/net metric.  This migration adds the tester's actual aggregate
swap and a reference to the dated swap-mode probe to every intended crypto run record.

The tool is deliberately narrow: only PilotCellRun and PilotSelectedVerification records with an
explicitly requested symbol are eligible; probe/selection/closeout entities remain excluded;
missing report/probe evidence refuses before any file is written; and a second application is a
no-op.
"""
from __future__ import annotations

import argparse
import html
import json
import math
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "factory" / "runs" / "pilot"
DEFAULT_PROBE = "factory/runs/pilot/swap_probe/swap_probe_20260804.jsonl"
FINANCING_RUN_ENTITIES = frozenset(("PilotCellRun", "PilotSelectedVerification"))
TARGET_METRICS = ("pf", "gross_profit", "gross_loss", "net_profit", "trades", "dd_pct")
STALE_FINANCING_PREFIX = "CRYPTO FINANCING:"
STALE_FINANCING_MARKERS = ("until deducted", "not financing-adjusted", "deduct again",
                           "deducted again")
CORRECTED_FINANCING_NOTE = (
    "CRYPTO FINANCING: the MT5 tester's Swap column is included in the stored tester-native "
    "metrics. financing_deducted records the report-derived tester swap for provenance; no "
    "post-hoc deduction is applied."
)
LEGACY_INVALID_DISPOSITION = "double-adjusted / invalid derived evidence"
LEGACY_INVALID_REASON = (
    "Legacy financing_deducted.applied=true described a post-hoc charge on metrics whose raw "
    "tester aggregates already included Swap; the raw tester metrics are retained and no "
    "deterministic regeneration is required."
)
ROW = re.compile(r"<tr[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
CELL = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.IGNORECASE | re.DOTALL)
TAG = re.compile(r"<[^>]+>")


class Refusal(RuntimeError):
    pass


def clean_cell(value: str) -> str:
    return html.unescape(TAG.sub("", value)).replace("\xa0", " ").strip()


def parse_number(value: str, *, where: str) -> float:
    text = value.replace("\xa0", "").replace(" ", "").replace(",", "")
    try:
        number = float(text)
    except ValueError as exc:
        raise Refusal(f"malformed tester swap value at {where}: {value!r}") from exc
    if not math.isfinite(number):
        raise Refusal(f"malformed tester swap value at {where}: {value!r}")
    return number


def read_report(path: Path, symbol: str) -> float:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise Refusal(f"cannot read report {path}: {exc}") from exc
    for encoding in ("utf-16", "utf-8-sig", "cp1252"):
        try:
            text = raw.decode(encoding)
            # UTF-8 bytes can legally decode as UTF-16 into gibberish.  A decoder merely not
            # throwing is not evidence that it read an HTML report.
            if "<" in text and text.count("\x00") < max(1, len(text) // 100):
                break
        except UnicodeDecodeError:
            continue
    else:
        raise Refusal(f"cannot decode report {path}")

    header = None
    swap_total = 0.0
    found_symbol = False
    seen_deal = False
    for row in ROW.findall(text):
        cells = [clean_cell(cell) for cell in CELL.findall(row)]
        if not cells:
            continue
        lowered = [cell.lower() for cell in cells]
        if {"time", "deal", "symbol", "swap"}.issubset(lowered):
            header = {name: index for index, name in enumerate(lowered)}
            continue
        if not header or len(cells) <= max(header.values()):
            continue
        if not re.match(r"^\d{4}\.\d{2}\.\d{2}", cells[header["time"]]):
            continue
        if not cells[header["deal"]].isdigit():
            continue
        row_symbol = cells[header["symbol"]]
        if row_symbol != symbol:
            continue
        found_symbol = True
        seen_deal = True
        swap_total += parse_number(
            cells[header["swap"]], where=f"{path} deal {cells[header['deal']]}"
        )
    if not header:
        raise Refusal(f"report has no Deals header with a Swap column: {path}")
    if not found_symbol or not seen_deal:
        raise Refusal(f"report has no {symbol} deal rows: {path}")
    return round(swap_total, 8)


def repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError as exc:
        raise Refusal(f"probe must be inside the repository: {path}") from exc


def load_probe(path: Path, symbol: str) -> str:
    if not path.is_file():
        raise Refusal(f"dated swap-mode probe is missing: {path}")
    try:
        records = []
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            record = json.loads(line)
            if not isinstance(record, dict):
                raise Refusal(f"probe line {line_no} is not a JSON object: {path}")
            if not record.get("_comment"):
                records.append(record)
    except (OSError, ValueError) as exc:
        raise Refusal(f"cannot parse dated swap-mode probe {path}: {exc}") from exc
    matches = [record for record in records
               if record.get("entity") == "SwapProbe"
               and record.get("probe") == "spec"
               and record.get("logical_symbol") == symbol
                and isinstance(record.get("taken_utc"), str)
                and re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",
                             record["taken_utc"])
               and record.get("swap_mode")]
    if len(matches) != 1:
        raise Refusal(
            f"probe must contain exactly one dated spec record for {symbol}: {path}"
        )
    return repo_relative(path)


def resolve_report(value: object) -> Path:
    if not isinstance(value, str) or not value:
        raise Refusal("crypto run record has no report path")
    path = Path(value)
    if not path.is_file():
        raise Refusal(f"source report is missing: {path}")
    return path


def migrated_block(old: object, *, tester_swap: float, probe: str) -> dict:
    prior = old if isinstance(old, dict) else {}
    block = dict(prior)
    # `applied` now describes a post-hoc change to the stored tester metrics. There was none.
    block.update({
        "applied": False,
        "metric_basis": "tester_native",
        "tester_swap_charged": tester_swap,
        "swap_mode_probe": probe,
    })
    # The first migration already changed `applied` to false. The explicit disposition is the
    # durable classification marker; do not infer legacy invalidity from ordinary provenance
    # fields that a future tester-native writer may also carry.
    if (prior.get("applied") is True
            or prior.get("legacy_disposition") == LEGACY_INVALID_DISPOSITION):
        block.update({
            "legacy_disposition": LEGACY_INVALID_DISPOSITION,
            "legacy_disposition_reason": LEGACY_INVALID_REASON,
        })
    return block


def corrected_notes(old: object) -> tuple[object, bool]:
    """Replace only notes that still claim tester-native metrics need a second deduction."""
    if not isinstance(old, list):
        return old, False
    changed = False
    notes = []
    for note in old:
        lowered = note.casefold() if isinstance(note, str) else ""
        if (isinstance(note, str) and note.startswith(STALE_FINANCING_PREFIX)
                and any(marker in lowered for marker in STALE_FINANCING_MARKERS)):
            notes.append(CORRECTED_FINANCING_NOTE)
            changed = True
        else:
            notes.append(note)
    return notes, changed


def target_files(root: Path):
    return sorted(path for path in root.rglob("*.jsonl") if "swap_probe" not in path.parts)


def plan(root: Path, *, symbol: str, probe: str):
    probe_path = (ROOT / probe).resolve() if not Path(probe).is_absolute() else Path(probe)
    probe_ref = load_probe(probe_path, symbol)
    planned = []
    skipped = 0
    migrated = 0
    notes_changed = 0
    for path in target_files(root):
        try:
            original = path.read_text(encoding="utf-8")
        except OSError as exc:
            raise Refusal(f"cannot read record file {path}: {exc}") from exc
        lines = original.splitlines(keepends=True)
        changed = False
        targets = 0
        rendered = []
        for line_no, line in enumerate(lines, 1):
            if not line.strip():
                rendered.append(line)
                continue
            try:
                record = json.loads(line)
            except ValueError as exc:
                raise Refusal(f"unparseable JSONL {path}:{line_no}: {exc}") from exc
            if (not isinstance(record, dict)
                    or record.get("entity") not in FINANCING_RUN_ENTITIES
                    or record.get("logical_symbol") != symbol):
                rendered.append(line)
                continue
            targets += 1
            report = resolve_report(record.get("report"))
            tester_swap = read_report(report, symbol)
            block = migrated_block(record.get("financing_deducted"), tester_swap=tester_swap,
                                   probe=probe_ref)
            notes, note_changed = corrected_notes(record.get("notes"))
            block_changed = record.get("financing_deducted") != block
            if not block_changed and not note_changed:
                skipped += 1
                rendered.append(line)
                continue
            before = {name: record.get(name) for name in TARGET_METRICS}
            record["financing_deducted"] = block
            if note_changed:
                record["notes"] = notes
            if before != {name: record.get(name) for name in TARGET_METRICS}:
                raise Refusal(f"metric mutation attempted at {path}:{line_no}")
            if block_changed:
                migrated += 1
            if note_changed:
                notes_changed += 1
            newline = "\n" if line.endswith("\n") else ""
            rendered.append(json.dumps(record, separators=(",", ":"), ensure_ascii=False) + newline)
            changed = True
        if targets and changed:
            planned.append((path, original, "".join(rendered), targets))
    return planned, skipped, migrated, notes_changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--probe", default=DEFAULT_PROBE)
    parser.add_argument("--apply", action="store_true", help="write planned evidence migration")
    args = parser.parse_args()
    try:
        planned, skipped, migrated, notes_changed = plan(
            args.root, symbol=args.symbol, probe=args.probe
        )
    except Refusal as exc:
        print(f"REFUSE: {exc}")
        return 2
    if not args.apply:
        print(
            f"DRY-RUN: {migrated} {args.symbol} record(s) would migrate; "
            f"{skipped} already migrated; {notes_changed} stale financing note(s) would be corrected"
        )
        return 0
    for path, _old, rendered, _targets in planned:
        path.write_text(rendered, encoding="utf-8", newline="")
    print(
        f"MIGRATED: {migrated} {args.symbol} record(s); {skipped} already migrated; "
        f"corrected {notes_changed} stale financing note(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
