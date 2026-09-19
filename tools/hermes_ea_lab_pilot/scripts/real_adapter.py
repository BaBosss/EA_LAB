"""V2-B controller-only NO-MT5 qualification boundary.

There is deliberately no CLI, default executor, argv builder or process launcher.
All callables are trusted, injected qualification seams, not manifest input.
Paths live only in the controller's pinned resource contract. A dispatched cell
is immutable canonical JSON and contains identities, never executable paths.
"""
from __future__ import annotations

import hashlib
import inspect
import json
import os
import re
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import safe_tester_executor_mcp as safe


LANES = {"MT5_PRIMARY": r"D:\Meta 5", "MT5_AGENT": r"D:\Meta 5b",
         "MT5_LIGHT": r"D:\Meta 5c"}
FIELDS = frozenset({"cell_id", "expert", "build_receipt", "artifact_sha256", "set_sha256",
                    "symbol", "tester_symbol", "tf", "window", "from_date", "to_date",
                    "model", "deposit", "leverage", "report_name", "lane"})
CONTRACT_FIELDS = {"schema", "mode", "head", "manifest", "manifest_sha256",
                   "set", "receipt", "artifact", "lane"}


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique)


def checked_file(root, relative, expected=None):
    if not isinstance(relative, str) or "\\" in relative or ":" in relative:
        raise ValueError("noncanonical resource path")
    path = safe.resolve_set_inside(root, relative)
    if path.stat().st_nlink != 1 or (root / relative).is_symlink():
        raise ValueError("aliased resource")
    if expected is not None:
        if not isinstance(expected, str) or not re.fullmatch("[0-9a-f]{64}", expected):
            raise ValueError("invalid SHA256")
        safe.verify_sha(path, expected, "frozen resource")
    return path


@dataclass(frozen=True)
class FrozenCell:
    payload: bytes

    def __post_init__(self):
        if type(self.payload) is not bytes:
            raise ValueError("frozen payload must be immutable bytes")

    def identity(self):
        return json.loads(self.payload)


def retain(path, data):
    with path.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())


def validate_year_split(data, identity):
    """Check canonical stdout structure, without interpreting strategy quality."""
    if type(data) is not bytes:
        raise ValueError("missing year split bytes")
    lines = data.decode("utf-8").splitlines()
    if len(lines) < 2 or lines[0] != "=== " + identity["report_name"] + ".htm":
        raise ValueError("year split report identity mismatch")
    pattern = (r"  (FULL|[0-9]{4})   trades= *([0-9]+)  PF= *(?:[0-9]+\.[0-9]{2}|inf)"
               r"  net= *[+-][0-9]+\.[0-9]{2}  balDD= *[0-9]+\.[0-9]{2}%"
               r"(?:  <-- LOSING YEAR|  <-- thin)?")
    entries = []
    for line in lines[1:]:
        match = re.fullmatch(pattern, line)
        if match is None:
            raise ValueError("unparsable canonical year split")
        entries.append((match[1], int(match[2])))
    if not entries:
        raise ValueError("missing FULL year split row")
    labels = [label for label, _ in entries]
    years = labels[1:]
    full_trades = entries[0][1]
    yearly_trades = sum(count for _, count in entries[1:])
    if (labels[0] != "FULL" or years != sorted(set(years))
            or any(y == "FULL" or not identity["from_date"][:4] <= y <= identity["to_date"][:4] for y in years)
            or (full_trades == 0 and years)
            or (full_trades > 0 and (not years or yearly_trades != full_trades))):
        raise ValueError("year split calendar/trade reconciliation mismatch")


class QualificationAdapter:
    """Trusted controller constructs this with externally retained contract SHA.

    executor(cell, evidence_directory) returns exactly exit_code/report_sha256.
    It supplies fresh report, execution identity, leverage, truncation and lane
    files at the fixed names below. parse_report(report) returns normalized
    report identity. year_split(report) returns canonical report_year_split.py
    stdout bytes; its source and canonical script are checkpoint-fingerprinted.
    None of these seams is exposed through the V2-A CLI or untrusted cell data.
    """

    def __init__(self, root, contract_path, contract_sha256, *, executor, parse_report,
                 year_split, head_reader):
        self.root = safe.workspace_root(root)
        self.contract_path = contract_path
        self.contract_sha256 = contract_sha256
        self.executor = executor
        self.parse_report = parse_report
        self.year_split = year_split
        self.head_reader = head_reader
        for seam in (executor, parse_report, year_split, head_reader):
            if not callable(seam):
                raise ValueError("qualification requires injected callables")
        self.contract = read_json(checked_file(self.root, contract_path, contract_sha256))
        self._contract_bytes = encoded(self.contract)
        self._rows = self.validate_batch(self.root, self.contract, head_reader)
        self._row_bytes = encoded(self._rows)

    def fingerprint(self):
        files = [Path(__file__), Path(safe.__file__), self.root / "scripts/report_year_split.py"]
        # Pin implementations, including injected executor/parser/year-split source.
        seams = {}
        for role, seam in (("executor", self.executor), ("parser", self.parse_report),
                           ("year_split", self.year_split), ("head_reader", self.head_reader)):
            source = inspect.getsourcefile(seam)
            if source is None:
                raise ValueError("qualification seam source unavailable")
            files.append(Path(source))
            seams[role] = {"module": seam.__module__, "name": seam.__qualname__,
                           "source_sha256": sha(inspect.getsource(seam).encode())}
        return {"contract_sha256": self.contract_sha256,
                "seams": seams,
                "sources": {str(p.resolve()): safe.sha256_path(p) for p in files}}

    def validate_batch(self, root, contract, head_reader):
        if Path(root).resolve() != self.root or encoded(contract) != self._contract_bytes:
            raise ValueError("controller contract mismatch")
        checked_file(self.root, self.contract_path, self.contract_sha256)
        if (set(contract) != CONTRACT_FIELDS or contract["schema"] != "hermes-adapter/1"
                or contract["mode"] != "QUALIFICATION_NO_MT5"):
            raise ValueError("NO-MT5 qualification contract required")
        if (not re.fullmatch("[0-9a-f]{40}", contract["head"])
                or self.head_reader(self.root) != contract["head"]
                or head_reader(self.root) != contract["head"]):
            raise ValueError("HEAD mismatch")
        if contract["lane"] not in LANES:
            raise ValueError("unknown lane")
        resources = {}
        for name in ("set", "receipt", "artifact"):
            ref = contract[name]
            if not isinstance(ref, dict) or set(ref) != {"path", "sha256"}:
                raise ValueError("resource schema mismatch")
            resources[name] = checked_file(self.root, ref["path"], ref["sha256"])
        rows = read_json(checked_file(self.root, contract["manifest"], contract["manifest_sha256"]))
        if not isinstance(rows, list) or not rows:
            raise ValueError("empty manifest")
        receipts = [json.loads(line, object_pairs_hook=unique)
                    for line in resources["receipt"].read_text(encoding="utf-8-sig").splitlines() if line.strip()]
        cells, reports = set(), set()
        for row in rows:
            if not isinstance(row, dict) or set(row) != FIELDS or any(type(v) is not str for v in row.values()):
                raise ValueError("cell schema mismatch; overrides denied")
            for key in ("cell_id", "report_name", "symbol", "tester_symbol", "build_receipt"):
                if not re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9._-]{0,95}", row[key]):
                    raise ValueError("invalid cell identity")
            if not re.fullmatch(r"[A-Za-z0-9_-]+(?:\\[A-Za-z0-9_-]+)*", row["expert"]):
                raise ValueError("invalid expert identity")
            if row["cell_id"].casefold() in cells or row["report_name"].casefold() in reports:
                raise ValueError("duplicate cell/report identity")
            cells.add(row["cell_id"].casefold())
            reports.add(row["report_name"].casefold())
            if row["window"] not in {"MAIN", "BWD"}:
                raise ValueError("HOLDOUT/window denied")
            dates = [datetime.strptime(row[k], "%Y.%m.%d") for k in ("from_date", "to_date")]
            if any(d.strftime("%Y.%m.%d") != row[k] for d, k in zip(dates, ("from_date", "to_date"))) or dates[0] >= dates[1]:
                raise ValueError("invalid window")
            if row["model"] not in {"0", "1", "4"} or (row["model"] == "4" and row["lane"] != "MT5_PRIMARY"):
                raise ValueError("unqualified model/lane")
            if row["tf"] not in {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"}:
                raise ValueError("invalid timeframe")
            if any(not re.fullmatch(r"[1-9][0-9]{0,8}", row[k]) for k in ("deposit", "leverage")):
                raise ValueError("invalid deposit/leverage")
            if (row["lane"] != contract["lane"] or row["artifact_sha256"] != contract["artifact"]["sha256"]
                    or row["set_sha256"] != contract["set"]["sha256"]):
                raise ValueError("lane/build/set mismatch")
            matches = [r for r in receipts if r.get("build_receipt") == row["build_receipt"]]
            if (len(matches) != 1 or matches[0].get("artifact_sha256") != row["artifact_sha256"]
                    or matches[0].get("ea_logical_identity") != row["expert"].split("\\")[-1]):
                raise ValueError("build receipt/expert mismatch")
        return rows

    def freeze(self, row):
        rows = json.loads(self._row_bytes)
        if row not in rows:
            raise ValueError("cell not in frozen controller manifest")
        return FrozenCell(encoded({**row, "head": self.contract["head"],
                                   "manifest_sha256": self.contract["manifest_sha256"],
                                   "contract_sha256": self.contract_sha256}))

    def __call__(self, cell, state):
        if type(cell) is not FrozenCell or cell not in [self.freeze(r) for r in json.loads(self._row_bytes)]:
            raise ValueError("controller-built frozen cell required")
        self.validate_batch(self.root, self.contract, self.head_reader)
        pins = self.fingerprint()
        identity = cell.identity()
        cell_id = identity["cell_id"]
        state = Path(state).resolve(strict=True)
        state.relative_to(self.root)
        evidence = state / (cell_id + ".evidence")
        evidence.mkdir()  # Existing evidence is ambiguous, never overwrite/replay.
        started = time.time_ns()
        failure = {"cell_id": cell_id, "status": "MECHANICAL_FAIL",
                   "reason": "ADAPTER_EVIDENCE_FAILURE", "artifacts": []}
        try:
            result = self.executor(cell, evidence)
            if (not isinstance(result, dict) or set(result) != {"exit_code", "report_sha256"}
                    or type(result["exit_code"]) is not int or result["exit_code"] != 0):
                return failure
            report_name = identity["report_name"]
            names = [report_name + suffix for suffix in
                     (".htm", ".execution.json", ".leverage_check.json", ".truncation_check.json", ".lane.json")]
            paths = [checked_file(evidence, name) for name in names]
            if any(p.stat().st_mtime_ns < started for p in paths):
                raise ValueError("stale evidence")
            report, execution, leverage, truncation, lane = paths
            checked_file(evidence, report.name, result["report_sha256"])
            report_sha = safe.sha256_path(report)
            snapshots = {p: p.read_bytes() for p in paths}
            if read_json(execution) != {"identity": identity, "report_sha256": report_sha}:
                raise ValueError("execution identity mismatch")
            expected_report = {k: identity[k] for k in
                               ("expert", "tester_symbol", "tf", "from_date", "to_date", "model", "deposit", "leverage")}
            if self.parse_report(report) != expected_report:
                raise ValueError("parsed report identity mismatch")
            if encoded(read_json(leverage)) != encoded({"report_name": report_name, "requested_leverage": int(identity["leverage"]),
                                      "actual_leverage": int(identity["leverage"]), "match": True, "status": "MATCH"}):
                raise ValueError("leverage mismatch")
            trunc = read_json(truncation)
            trunc_keys = {"schema_version", "check_status", "checker_exit_code", "truncated", "report_sha256", "report_name"}
            if (not isinstance(trunc, dict) or not trunc_keys <= set(trunc)
                    or set(trunc) - trunc_keys - {"detail"}
                    or not safe.full_window_evidence_eligibility(trunc)[0]
                    or type(trunc.get("schema_version")) is not int
                    or trunc.get("report_sha256") != report_sha
                    or trunc.get("report_name") != report_name):
                raise ValueError("truncation evidence mismatch")
            if read_json(lane) != {"lane": identity["lane"], "install": LANES[identity["lane"]]}:
                raise ValueError("lane identity mismatch")
            years = self.year_split(report)
            validate_year_split(years, identity)
            if years != self.year_split(report):
                raise ValueError("missing or nondeterministic year split")
            year_path = evidence / (report_name + ".years.txt")
            retain(year_path, years)
            snapshots[year_path] = years
            # Retain exact build/set/contract inputs as evidence, not mutable pointers.
            for name in ("set", "receipt", "artifact"):
                ref = self.contract[name]
                data = checked_file(self.root, ref["path"], ref["sha256"]).read_bytes()
                path = evidence / ("bound-" + name)
                retain(path, data)
                snapshots[path] = data
            self.validate_batch(self.root, self.contract, self.head_reader)
            if self.fingerprint() != pins or any(p.read_bytes() != data for p, data in snapshots.items()):
                raise ValueError("evidence or implementation changed during execution")
            return {"cell_id": cell_id, "status": "COMPLETE", "reason": "ADAPTER_OK",
                    "artifacts": [{"path": p.relative_to(state).as_posix(), "sha256": sha(data)}
                                  for p, data in snapshots.items()]}
        except Exception:
            return failure
