from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Iterable

SCHEMA = "BOSS19_P5_SESSION_ATTRIBUTION_V1"
EXPECTED_INPUT_SHA256 = "e54f1cfaf58df97acb8fb39c1e6e8bf4614f1ff3a7c9bcbc1b5acff762665dd6"
EXPECTED_UNIT_COUNT = 1549
EXPECTED_NET = Decimal("17718.78")
EXPECTED_PACKAGE_SHA256 = "1330a822ed66149ba07d693d8732ced5b9e9ce66d15f34ce8d21ef70894b760c"
NAMED_SESSIONS = ("ASIA", "LONDON", "LONDON_NY_OVERLAP", "NEW_YORK_ONLY")
ALL_SESSIONS = NAMED_SESSIONS + ("OUTSIDE_DEFINED_SESSION",)
WINDOWS = ("MAIN", "BWD")
REVIEW_SCHEMA = "BOSS19_P5_SESSION_SEMANTICS_REVIEW_RECEIPT_V1"
REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_REL = "docs/research/BOSS19_P5_SESSION_CONTEXT_CONTRACT.md"
CLASSIFIER_REL = "tools/boss19_p5_session_attribution/build_session_attribution.py"
TESTS_REL = "tools/boss19_p5_session_attribution/tests/test_session_attribution.py"

REQUIRED = {
    "evidence_package_sha256", "h3_run_id", "window", "year", "symbol", "tf",
    "source_position_id", "source_deal_id", "entry_utc", "exit_utc",
    "source_net_realized", "macro_state", "local_state", "vol_state",
    "classification_status",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_z(text: str) -> datetime:
    return datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ")


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _git_blob(reviewed_head: str, rel: str) -> bytes:
    proc = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "show", f"{reviewed_head}:{rel}"],
        capture_output=True, check=False,
    )
    if proc.returncode != 0:
        raise ValueError(f"reviewed Git blob unavailable: {rel}")
    return proc.stdout


def validate_review_receipt(path: Path) -> dict:
    if not path.is_file():
        raise ValueError("semantics review receipt missing")
    receipt = json.loads(path.read_text(encoding="utf-8"))
    required = {
        "schema_version", "verdict", "reviewer_family", "reviewed_head", "reviewed_utc",
        "contract_sha256", "classifier_sha256", "tests_sha256", "review_output_sha256",
    }
    if not required.issubset(receipt):
        raise ValueError("semantics review receipt missing required fields")
    if receipt["schema_version"] != REVIEW_SCHEMA or receipt["verdict"] != "PASS":
        raise ValueError("semantics review receipt is not PASS")
    if str(receipt["reviewer_family"]).lower() != "anthropic":
        raise ValueError("semantics reviewer is not different-family")
    reviewed_head = str(receipt["reviewed_head"])
    if not re.fullmatch(r"[0-9a-f]{40}", reviewed_head):
        raise ValueError("invalid reviewed_head")
    parse_z(str(receipt["reviewed_utc"]))
    if not re.fullmatch(r"[0-9a-f]{64}", str(receipt["review_output_sha256"])):
        raise ValueError("invalid review_output_sha256")
    bindings = ((CONTRACT_REL, "contract_sha256"), (CLASSIFIER_REL, "classifier_sha256"), (TESTS_REL, "tests_sha256"))
    for rel, field in bindings:
        expected = str(receipt[field])
        if not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError(f"invalid {field}")
        current = sha256(REPO_ROOT / rel)
        reviewed = _sha256_bytes(_git_blob(reviewed_head, rel))
        if current != expected or reviewed != expected:
            raise ValueError(f"semantics review binding mismatch: {rel}")
    return {
        "receipt_sha256": sha256(path), "reviewed_head": reviewed_head,
        "reviewer_family": receipt["reviewer_family"], "reviewed_utc": receipt["reviewed_utc"],
        "review_output_sha256": receipt["review_output_sha256"],
    }


def sign(value: Decimal) -> str:
    if value > 0:
        return "POSITIVE"
    if value < 0:
        return "NEGATIVE"
    return "ZERO"


def classify_session(entry_utc: str) -> str:
    dt = parse_z(entry_utc)
    minute = dt.hour * 60 + dt.minute + dt.second / 60.0
    if minute < 7 * 60:
        return "ASIA"
    if minute < 12 * 60:
        return "LONDON"
    if minute < 16 * 60:
        return "LONDON_NY_OVERLAP"
    if minute < 21 * 60:
        return "NEW_YORK_ONLY"
    return "OUTSIDE_DEFINED_SESSION"


def load_rows(path: Path) -> list[dict[str, str]]:
    if sha256(path) != EXPECTED_INPUT_SHA256:
        raise ValueError("input SHA-256 does not match preregistered accepted detail")
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or not REQUIRED.issubset(reader.fieldnames):
            raise ValueError("input schema missing required fields")
        rows = list(reader)
    if len(rows) != EXPECTED_UNIT_COUNT:
        raise ValueError(f"unit count {len(rows)} != {EXPECTED_UNIT_COUNT}")
    return rows


def validate_rows(rows: list[dict[str, str]]) -> None:
    keys: set[tuple[str, str]] = set()
    total = Decimal("0")
    package_ids = set()
    for row in rows:
        key = (row["h3_run_id"], row["source_deal_id"])
        if key in keys:
            raise ValueError(f"duplicate DEAL key: {key}")
        keys.add(key)
        if row["window"] not in WINDOWS:
            raise ValueError(f"unexpected window: {row['window']}")
        if row["classification_status"] != "CLASSIFIED":
            raise ValueError(f"non-classified accepted input: {key}")
        entry, exit_at = parse_z(row["entry_utc"]), parse_z(row["exit_utc"])
        if entry.year < 2020 or entry.year > 2025 or exit_at.year > 2025:
            raise ValueError(f"HOLDOUT/time boundary violation: {key}")
        if str(entry.year) != row["year"]:
            raise ValueError(f"entry year mismatch: {key}")
        if entry > exit_at:
            raise ValueError(f"entry after exit: {key}")
        total += Decimal(row["source_net_realized"])
        package_ids.add(row["evidence_package_sha256"])
    if total.quantize(Decimal("0.01")) != EXPECTED_NET:
        raise ValueError(f"realized net {total} != {EXPECTED_NET}")
    if package_ids != {EXPECTED_PACKAGE_SHA256}:
        raise ValueError(f"evidence package identity drift: {sorted(package_ids)}")


def money(v: Decimal) -> str:
    return f"{v.quantize(Decimal('0.01')):.2f}"


def pf(gp: Decimal, gl: Decimal) -> str:
    return "" if gl == 0 else f"{(gp / gl):.6f}"


def max_drawdown(rows: Iterable[dict]) -> Decimal:
    ordered = sorted(rows, key=lambda r: (r["exit_dt"], int(r["source_deal_id"])))
    equity = peak = Decimal("0")
    worst = Decimal("0")
    for row in ordered:
        equity += row["net"]
        peak = max(peak, equity)
        worst = max(worst, peak - equity)
    return worst


def metrics(rows: list[dict], denominator: int) -> dict[str, str]:
    gp = sum((r["net"] for r in rows if r["net"] > 0), Decimal("0"))
    gl = -sum((r["net"] for r in rows if r["net"] < 0), Decimal("0"))
    net = gp - gl
    return {
        "eligible_unit_count": str(len(rows)),
        "participation_share": f"{(Decimal(len(rows)) / Decimal(denominator)):.8f}" if denominator else "",
        "gross_profit": money(gp), "gross_loss": money(gl), "net_realized": money(net),
        "profit_factor": pf(gp, gl),
        "winning_unit_count": str(sum(r["net"] > 0 for r in rows)),
        "losing_unit_count": str(sum(r["net"] < 0 for r in rows)),
        "zero_unit_count": str(sum(r["net"] == 0 for r in rows)),
        "partition_realized_equity_dd": money(max_drawdown(rows)),
    }


def enrich(rows: list[dict[str, str]], created_utc: str) -> list[dict]:
    out = []
    for row in rows:
        entry_dt, exit_dt = parse_z(row["entry_utc"]), parse_z(row["exit_utc"])
        out.append({
            "schema_version": SCHEMA, "created_utc": created_utc,
            "input_sha256": EXPECTED_INPUT_SHA256,
            "h3_run_id": row["h3_run_id"], "window": row["window"], "year": row["year"],
            "symbol": row["symbol"], "tf": row["tf"],
            "source_position_id": row["source_position_id"], "source_deal_id": row["source_deal_id"],
            "entry_utc": row["entry_utc"], "exit_utc": row["exit_utc"],
            "source_net_realized": row["source_net_realized"],
            "session_state": classify_session(row["entry_utc"]),
            "macro_state": row["macro_state"], "local_state": row["local_state"], "vol_state": row["vol_state"],
            "entry_dt": entry_dt, "exit_dt": exit_dt, "net": Decimal(row["source_net_realized"]),
            "entry_month": entry_dt.strftime("%Y-%m"), "home": f"{row['symbol']}|{row['tf']}",
        })
    return out


def write_csv(path: Path, fields: list[str], rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def public_detail(rows: list[dict]) -> list[dict]:
    return [{k: v for k, v in r.items() if k not in {"entry_dt", "exit_dt", "net", "entry_month", "home"}} for r in rows]


def affinity_rows(rows: list[dict], created_utc: str) -> list[dict]:
    specs = [
        ("ALL", lambda r: (r["session_state"],), lambda r: ("ALL", "ALL", "ALL", "ALL", "ALL")),
        ("WINDOW", lambda r: (r["window"], r["session_state"]), lambda r: (r["window"], "ALL", "ALL", "ALL", "ALL")),
        ("YEAR", lambda r: (r["window"], r["year"], r["session_state"]), lambda r: (r["window"], r["year"], "ALL", "ALL", "ALL")),
        ("ENTRY_MONTH", lambda r: (r["window"], r["entry_month"], r["session_state"]), lambda r: (r["window"], "ALL", r["entry_month"], "ALL", "ALL")),
        ("SYMBOL", lambda r: (r["window"], r["symbol"], r["session_state"]), lambda r: (r["window"], "ALL", "ALL", r["symbol"], "ALL")),
        ("SYMBOL_TF", lambda r: (r["window"], r["symbol"], r["tf"], r["session_state"]), lambda r: (r["window"], "ALL", "ALL", r["symbol"], r["tf"])),
    ]
    out: list[dict] = []
    for view, key_fn, dims_fn in specs:
        groups: dict[tuple, list[dict]] = defaultdict(list)
        denominators: dict[tuple, int] = defaultdict(int)
        for r in rows:
            groups[key_fn(r)].append(r)
            denominators[dims_fn(r)] += 1
        for key in sorted(groups):
            g = groups[key]
            sample = g[0]
            window, year, entry_month, symbol, tf = dims_fn(sample)
            rec = {
                "schema_version": SCHEMA, "created_utc": created_utc, "view_type": view,
                "window": window, "year": year, "entry_month": entry_month, "symbol": symbol, "tf": tf,
                "session_state": sample["session_state"],
            }
            rec.update(metrics(g, denominators[(window, year, entry_month, symbol, tf)]))
            out.append(rec)
    return out


def cross_window_direction(rows: list[dict], session: str) -> str:
    nets = {}
    for window in WINDOWS:
        nets[window] = sum((r["net"] for r in rows if r["window"] == window and r["session_state"] == session), Decimal("0"))
    if nets["MAIN"] > 0 and nets["BWD"] > 0:
        return "POSITIVE"
    if nets["MAIN"] < 0 and nets["BWD"] < 0:
        return "NEGATIVE"
    return "MIXED_OR_ZERO"


def loo_rows(rows: list[dict], created_utc: str) -> tuple[list[dict], dict[str, dict]]:
    out: list[dict] = []
    summary: dict[str, dict] = {}
    dimensions = (("YEAR", "year"), ("ENTRY_MONTH", "entry_month"), ("SYMBOL", "symbol"), ("SYMBOL_TF", "home"))
    for session in NAMED_SESSIONS:
        direction = cross_window_direction(rows, session)
        checks: dict[str, bool] = {}
        for window in WINDOWS:
            base = [r for r in rows if r["session_state"] == session and r["window"] == window]
            base_net = sum((r["net"] for r in base), Decimal("0"))
            for dim_name, field in dimensions:
                values = sorted({r[field] for r in base})
                preserved = []
                for value in values:
                    remaining = [r for r in base if r[field] != value]
                    rem_net = sum((r["net"] for r in remaining), Decimal("0"))
                    rem_sign = sign(rem_net)
                    keep = bool(remaining) and direction in {"POSITIVE", "NEGATIVE"} and rem_sign == direction
                    preserved.append(keep)
                    out.append({
                        "schema_version": SCHEMA, "created_utc": created_utc, "window": window,
                        "session_state": session, "target_direction": direction,
                        "exclusion_dimension": dim_name, "excluded_group": value,
                        "base_unit_count": len(base), "base_net_realized": money(base_net),
                        "remaining_unit_count": len(remaining), "remaining_net_realized": money(rem_net),
                        "remaining_sign": rem_sign, "preserves_direction": str(keep).lower(),
                    })
                checks[f"{window}_{dim_name}"] = bool(preserved) and all(preserved)
        candidate = direction in {"POSITIVE", "NEGATIVE"} and all(checks.values())
        summary[session] = {"direction": direction, "checks": checks, "context_candidate": candidate}
    return out, summary


def decide(summary: dict[str, dict]) -> tuple[str, list[dict]]:
    candidates = [
        {"session_state": session, "direction": data["direction"]}
        for session, data in summary.items() if data["context_candidate"]
    ]
    if not candidates:
        return "P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK", candidates
    if len(candidates) == 1:
        return "P5_SESSION_CONTEXT_CANDIDATE_FOUND_SINGLE", candidates
    return "P5_SESSION_CONTEXT_INFORMATION_FOUND_MULTIPLE_NO_PERFORMANCE_SELECTION", candidates


def dump_json(path: Path, obj: dict) -> None:
    path.write_text(json.dumps(obj, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")


def run(input_path: Path, out_dir: Path, created_utc: str, review_receipt: Path) -> dict:
    parse_z(created_utc)
    review = validate_review_receipt(review_receipt)
    source = load_rows(input_path)
    validate_rows(source)
    rows = enrich(source, created_utc)
    if any(r["session_state"] not in ALL_SESSIONS for r in rows):
        raise ValueError("unassigned session state")

    out_dir.mkdir(parents=True, exist_ok=True)
    detail_path = out_dir / "session_attribution_detail.csv"
    affinity_path = out_dir / "session_affinity.csv"
    loo_path = out_dir / "session_leave_one_out.csv"
    recon_path = out_dir / "reconciliation.json"
    package_path = out_dir / "package.json"

    detail_fields = [
        "schema_version", "created_utc", "input_sha256", "h3_run_id", "window", "year", "symbol", "tf",
        "source_position_id", "source_deal_id", "entry_utc", "exit_utc", "source_net_realized",
        "session_state", "macro_state", "local_state", "vol_state",
    ]
    write_csv(detail_path, detail_fields, public_detail(rows))

    affinity = affinity_rows(rows, created_utc)
    affinity_fields = [
        "schema_version", "created_utc", "view_type", "window", "year", "entry_month", "symbol", "tf", "session_state",
        "eligible_unit_count", "participation_share", "gross_profit", "gross_loss", "net_realized", "profit_factor",
        "winning_unit_count", "losing_unit_count", "zero_unit_count", "partition_realized_equity_dd",
    ]
    write_csv(affinity_path, affinity_fields, affinity)

    loo, summary = loo_rows(rows, created_utc)
    loo_fields = [
        "schema_version", "created_utc", "window", "session_state", "target_direction",
        "exclusion_dimension", "excluded_group", "base_unit_count", "base_net_realized",
        "remaining_unit_count", "remaining_net_realized", "remaining_sign", "preserves_direction",
    ]
    write_csv(loo_path, loo_fields, loo)

    total_net = sum((r["net"] for r in rows), Decimal("0"))
    session_counts = {s: sum(r["session_state"] == s for r in rows) for s in ALL_SESSIONS}
    recon = {
        "schema_version": SCHEMA,
        "created_utc": created_utc,
        "status": "PASS_ATTRIBUTION_RECONCILIATION",
        "input_sha256": sha256(input_path),
        "input_unit_count": len(rows),
        "unique_deal_key_count": len({(r["h3_run_id"], r["source_deal_id"]) for r in rows}),
        "assigned_unit_count": sum(session_counts.values()),
        "session_counts": session_counts,
        "input_net_realized": money(total_net),
        "expected_net_realized": money(EXPECTED_NET),
        "holdout_row_count": sum(parse_z(r["entry_utc"]).year >= 2026 or parse_z(r["exit_utc"]).year >= 2026 for r in rows),
        "unknown_session_count": sum(r["session_state"] not in ALL_SESSIONS for r in rows),
        "session_timezone": "UTC",
        "dst_mode": "FIXED_UTC_SOURCE_WINDOWS",
        "semantics_review": review,
        "exclusive_partition": "ASIA[00,07);LONDON[07,12);LONDON_NY_OVERLAP[12,16);NEW_YORK_ONLY[16,21);OUTSIDE[21,24)",
    }
    dump_json(recon_path, recon)

    decision, candidates = decide(summary)
    package = {
        "schema_version": SCHEMA,
        "created_utc": created_utc,
        "status": "PASS",
        "decision": decision,
        "candidates": candidates,
        "session_summary": summary,
        "input": {"path": str(input_path), "sha256": sha256(input_path), "unit_count": len(rows)},
        "outputs": {},
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "semantics_review": review,
        "does_not_authorize": ["STRATEGY_FILTER", "CANDIDATE", "GRADE_KINT", "RISK_DEFAULT", "RUNTIME", "DEPLOYMENT", "TRADING"],
    }

    for path in (detail_path, affinity_path, loo_path, recon_path):
        package["outputs"][path.name] = {"sha256": sha256(path), "bytes": path.stat().st_size}
    dump_json(package_path, package)
    return package


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--created-utc", required=True)
    ap.add_argument("--review-receipt", type=Path, required=True)
    args = ap.parse_args()
    package = run(args.input, args.out_dir, args.created_utc, args.review_receipt)
    print(json.dumps({"status": package["status"], "decision": package["decision"], "candidates": package["candidates"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
