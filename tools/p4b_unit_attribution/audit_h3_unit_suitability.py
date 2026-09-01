#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "BOSS19_P4_H3_UNIT_SUITABILITY_V1"
BLOCKED = "BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)"
EXPECTED_H3_SHA = "3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2"
EXPECTED_H3_MANIFEST_SHA = "56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd"
EXPECTED_TIMELINE_SHA = "5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d"
EXPECTED_TIMELINE_MANIFEST_SHA = "858f4d02d1ae30511dd1f38ffab347c85c06a4a25df4bedf901dc169c2847916"
FORBIDDEN_INFERENCES = ["FIFO", "TEMPORAL_PROXIMITY", "VOLUME_MATCH", "ORDER_SEQUENCE", "P_AND_L_MATCH"]
def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def normalize_text(parts: list[str]) -> str:
    return re.sub(r"\s+", " ", "".join(parts)).strip()


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tables: list[list[list[str]]] = []
        self.table: list[list[str]] | None = None
        self.row: list[str] | None = None
        self.cell_parts: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag == "table":
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in {"td", "th"} and self.row is not None:
            self.cell_parts = []
    def handle_data(self, data: str) -> None:
        if self.cell_parts is not None:
            self.cell_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self.cell_parts is not None and self.row is not None:
            self.row.append(normalize_text(self.cell_parts))
            self.cell_parts = None
        elif tag == "tr" and self.row is not None and self.table is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == "table" and self.table is not None:
            self.tables.append(self.table)
            self.table = None


def parse_report_tables(report_bytes: bytes) -> dict[str, list[list[str]]]:
    text = report_bytes.decode("utf-16")
    parser = TableParser()
    parser.feed(text)
    found: dict[str, list[list[str]]] = {}
    for table in parser.tables:
        for idx, row in enumerate(table):
            vals = [v for v in row if v]
            if vals == ["Orders"]:
                found["Orders"] = table[idx + 1 :]
            if vals == ["Deals"]:
                found["Deals"] = table[idx + 1 :]
    return found
EXPECTED_ORDER_HEADER = [
    "Open Time", "Order", "Symbol", "Type", "Volume", "Price",
    "S / L", "T / P", "Time", "State", "Comment",
]
EXPECTED_DEAL_HEADER = [
    "Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price",
    "Order", "Commission", "Swap", "Profit", "Balance", "Comment",
]


def split_table(rows: list[list[str]], expected: list[str]) -> tuple[list[str], list[list[str]]]:
    if not rows:
        return [], []
    header = rows[0]
    body = [r for r in rows[1:] if len(r) == len(expected)]
    return header, body


def report_filename(symbol: str, tf: str, window: str) -> str:
    return f"H3_B19_{symbol}_{tf}_{window}_M1.htm"


def assess_report(path: Path, matrix_row: dict[str, str]) -> dict[str, Any]:
    raw = path.read_bytes()
    report_sha = hashlib.sha256(raw).hexdigest()
    text = raw.decode("utf-16")
    tables = parse_report_tables(raw)
    oh, orders = split_table(tables.get("Orders", []), EXPECTED_ORDER_HEADER)
    dh, deals = split_table(tables.get("Deals", []), EXPECTED_DEAL_HEADER)
    header_ok = oh == EXPECTED_ORDER_HEADER and dh == EXPECTED_DEAL_HEADER
    in_deals = [r for r in deals if r[4] == "in"] if header_ok else []
    out_deals = [r for r in deals if r[4] == "out"] if header_ok else []
    in_orders = {r[7] for r in in_deals}
    out_orders = {r[7] for r in out_deals}
    expected_trades = int(float(matrix_row["trades"]))
    return {
        "cell_id": matrix_row["cell_id"],
        "report_file": path.name,
        "report_sha256": report_sha,
        "report_sha256_matches_matrix": report_sha == matrix_row["report_sha256"],
        "orders_header": oh,
        "deals_header": dh,
        "header_schema_matches": header_ok,
        "realized_out_deals": len(out_deals),
        "h3_matrix_trades": expected_trades,
        "out_deal_count_matches_h3_trades": len(out_deals) == expected_trades,
        "opening_in_deals": len(in_deals),
        "out_deal_has_source_deal_id": all(bool(r[1]) for r in out_deals),
        "out_deal_has_close_time": all(bool(r[0]) for r in out_deals),
        "out_deal_has_realized_profit": all(bool(r[10]) for r in out_deals),
        "deal_header_has_position_identity": any("position" in x.lower() for x in dh),
        "order_header_has_position_identity": any("position" in x.lower() for x in oh),
        "source_basket_id_token_present": bool(re.search(r"basket[ _-]?id", text, re.I)),
        "in_out_order_id_overlap_count": len(in_orders & out_orders),
        "out_deal_comments_nonempty": sum(bool(r[12]) for r in out_deals),
    }
def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def audit(args: argparse.Namespace) -> dict[str, Any]:
    package_path = Path(args.h3_package)
    matrix_path = Path(args.h3_matrix)
    reports_dir = Path(args.reports_dir)
    timeline_manifest_path = Path(args.timeline_manifest)
    timeline_path = timeline_manifest_path.parent / "classifier_timeline.csv"
    h3_package = load_json(package_path)
    timeline_manifest = load_json(timeline_manifest_path)
    matrix = list(csv.DictReader(matrix_path.open(encoding="utf-8-sig", newline="")))
    if sha256_file(package_path) != EXPECTED_H3_SHA:
        raise SystemExit("H3 package SHA mismatch")
    if h3_package.get("manifest_sha256") != EXPECTED_H3_MANIFEST_SHA:
        raise SystemExit("H3 manifest identity mismatch")
    if sha256_file(timeline_manifest_path) != EXPECTED_TIMELINE_MANIFEST_SHA:
        raise SystemExit("timeline manifest SHA mismatch")
    if timeline_manifest.get("timeline_sha256") != EXPECTED_TIMELINE_SHA:
        raise SystemExit("timeline identity mismatch")
    if sha256_file(timeline_path) != EXPECTED_TIMELINE_SHA:
        raise SystemExit("timeline bytes SHA mismatch")
    if len(matrix) != 36:
        raise SystemExit("expected 36 H3 matrix rows")
    reports: list[dict[str, Any]] = []
    for row in matrix:
        fn = report_filename(row["symbol"], row["tf"], row["window"])
        path = reports_dir / fn
        if not path.is_file():
            raise SystemExit(f"missing H3 report: {fn}")
        reports.append(assess_report(path, row))
    all_hash = all(r["report_sha256_matches_matrix"] for r in reports)
    all_schema = all(r["header_schema_matches"] for r in reports)
    all_counts = all(r["out_deal_count_matches_h3_trades"] for r in reports)
    total_out = sum(r["realized_out_deals"] for r in reports)
    total_in = sum(r["opening_in_deals"] for r in reports)
    position_identity = any(
        r["deal_header_has_position_identity"] or r["order_header_has_position_identity"]
        for r in reports
    )
    order_overlap = sum(r["in_out_order_id_overlap_count"] for r in reports)
    basket_id_present = any(r["source_basket_id_token_present"] for r in reports)
    if not (all_hash and all_schema and all_counts):
        raise SystemExit("H3 report identity/schema/reconciliation precheck failed")
    if position_identity or order_overlap:
        linkage_verdict = "REQUIRES_SEPARATE_LINKAGE_REVIEW"
    else:
        linkage_verdict = "NO_SOURCE_EMITTED_ENTRY_LINK_FIELD"
    return {
        "schema_version": SCHEMA_VERSION,
        "status": BLOCKED,
        "blocker_reason": "NO_DURABLE_REALIZED_DEAL_TO_OPENING_TIMESTAMP_LINKAGE_IN_H3_REPORT_BYTES",
        "canonical_base_sha": args.base_sha,
        "created_utc": args.created_utc,
        "authority": "RESEARCH_ONLY_NO_HOLDOUT_NO_OPTIMIZATION_NO_RUNTIME_RISK_DEPLOYMENT",
        "provenance": {
            "h3_result_package_sha256": EXPECTED_H3_SHA,
            "h3_manifest_sha256": EXPECTED_H3_MANIFEST_SHA,
            "h3_contract_head": h3_package.get("canonical_head"),
            "timeline_sha256": EXPECTED_TIMELINE_SHA,
            "timeline_manifest_sha256": EXPECTED_TIMELINE_MANIFEST_SHA,
            "market_input_manifest_sha256": timeline_manifest.get("raw_market_input_manifest_sha256"),
            "timeline_rows": timeline_manifest.get("row_count"),
            "holdout": h3_package.get("holdout"),
            "optimization": h3_package.get("optimization"),
        },
        "report_audit": {
            "reports_expected": 36, "reports_verified": len(reports),
            "all_report_hashes_match_h3_matrix": all_hash,
            "all_order_and_deal_schemas_match": all_schema,
            "all_realized_out_counts_match_h3_trade_counts": all_counts,
            "total_opening_in_deals": total_in,
            "total_realized_out_deals": total_out,
            "position_identity_field_present": position_identity,
            "opening_and_closing_order_id_overlap_count": order_overlap,
            "source_basket_id_token_present": basket_id_present,
            "linkage_verdict": linkage_verdict,
        },
        "deal_unit_suitability": {
            "status": "BLOCKED_NO_DURABLE_ENTRY_LINKAGE",
            "source_deal_id_available": True,
            "close_timestamp_available": True,
            "realized_profit_available": True,
            "opening_timestamps_exist_on_separate_in_deals": True,
            "source_emitted_position_or_opening_link_field_available": False,
            "closing_order_id_links_to_opening_order_id": False,
            "durable_entry_utc_derivable_without_inference": False,
            "forbidden_inferences_not_used": FORBIDDEN_INFERENCES,
        },
        "basket_suitability": {
            "status": "UNAVAILABLE_NO_SOURCE_BASKET_ID",
            "durable_source_emitted_basket_id_available": basket_id_present,
            "temporal_or_order_based_basket_reconstruction_used": False,
        },
        "reports": reports,
        "next_safe_action": (
            "Acquire a source-bound timestamped H3 unit export carrying durable realized-deal/position "
            "identity linked to its opening timestamp; do not infer FIFO, order-sequence, volume, time-proximity, or P&L linkage."
        ),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--h3-package", required=True)
    ap.add_argument("--h3-matrix", required=True)
    ap.add_argument("--reports-dir", required=True)
    ap.add_argument("--timeline-manifest", required=True)
    ap.add_argument("--base-sha", required=True)
    ap.add_argument("--created-utc", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.base_sha):
        raise SystemExit("base-sha must be lowercase 40-hex")
    result = audit(args)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    out.write_text(payload, encoding="utf-8", newline="\n")
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    print(f"P4_H3_UNIT_SUITABILITY_BLOCKED reports={len(result['reports'])} out_deals={result['report_audit']['total_realized_out_deals']} sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
