from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

THIS_DIR = Path(__file__).resolve().parent
REPO = THIS_DIR.parents[1]
NORMALIZER_DIR = REPO / "tools" / "P4BMarketDataExporter"
sys.path.insert(0, str(NORMALIZER_DIR))
from normalize_ohlc import is_dst_transition_server_date, server_to_utc

SOURCE_SCHEMA = "BOSS19_P4B_UNIT_SOURCE_V1"
UNIT_SCHEMA = "BOSS19_P4B_SOURCE_BOUND_DEAL_V1"
ENTRY_IN = 0
ENTRY_OUT = 1
ENTRY_INOUT = 2
ENTRY_OUT_BY = 3
TRADING_TYPES = {0, 1}

REQUIRED_HEADER = [
    "schema_version", "symbol", "period", "period_name", "magic", "account_margin_mode",
    "deal_id", "position_id", "order_id", "deal_entry", "deal_type", "deal_time_server",
    "deal_time_msc", "volume", "price", "commission", "swap", "profit",
]

from decimal import Decimal, InvalidOperation


class UnitSourceError(ValueError):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_int(row: dict[str, str], key: str) -> int:
    try:
        return int(row[key])
    except (KeyError, TypeError, ValueError) as e:
        raise UnitSourceError(f"invalid integer {key}: {row.get(key)!r}") from e


def parse_decimal(row: dict[str, str], key: str) -> Decimal:
    try:
        return Decimal(row[key])
    except (KeyError, TypeError, InvalidOperation) as e:
        raise UnitSourceError(f"invalid decimal {key}: {row.get(key)!r}") from e

def read_source(path: Path) -> list[dict]:
    with path.open(newline="", encoding="ascii") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != REQUIRED_HEADER:
            raise UnitSourceError(f"unexpected header: {reader.fieldnames}")
        rows = list(reader)
    if not rows:
        raise UnitSourceError("source export contains no trading deals")

    seen: set[int] = set()
    parsed: list[dict] = []
    identity = None
    for raw in rows:
        if raw.get("schema_version") != SOURCE_SCHEMA:
            raise UnitSourceError(f"unexpected source schema: {raw.get('schema_version')!r}")
        deal_id = parse_int(raw, "deal_id")
        position_id = parse_int(raw, "position_id")
        order_id = parse_int(raw, "order_id")
        entry = parse_int(raw, "deal_entry")
        deal_type = parse_int(raw, "deal_type")
        time_msc = parse_int(raw, "deal_time_msc")
        if deal_id <= 0 or deal_id in seen:
            raise UnitSourceError(f"duplicate/nonzero deal_id violation: {deal_id}")
        if position_id <= 0:
            raise UnitSourceError(f"missing source position_id on deal {deal_id}")
        if deal_type not in TRADING_TYPES:
            raise UnitSourceError(f"unsupported non-trading deal_type={deal_type} deal={deal_id}")
        if entry not in {ENTRY_IN, ENTRY_OUT, ENTRY_INOUT, ENTRY_OUT_BY}:
            raise UnitSourceError(f"unsupported deal_entry={entry} deal={deal_id}")
        if time_msc <= 0:
            raise UnitSourceError(f"invalid deal_time_msc deal={deal_id}")

        row_identity = (raw["symbol"], raw["period"], raw["period_name"], raw["magic"], raw["account_margin_mode"])
        if identity is None:
            identity = row_identity
        elif row_identity != identity:
            raise UnitSourceError(f"mixed run identity: {identity!r} vs {row_identity!r}")
        seen.add(deal_id)
        parsed.append({
            **raw,
            "deal_id_i": deal_id,
            "position_id_i": position_id,
            "order_id_i": order_id,
            "deal_entry_i": entry,
            "deal_type_i": deal_type,
            "deal_time_msc_i": time_msc,
            "volume_d": parse_decimal(raw, "volume"),
            "price_d": parse_decimal(raw, "price"),
            "commission_d": parse_decimal(raw, "commission"),
            "swap_d": parse_decimal(raw, "swap"),
            "profit_d": parse_decimal(raw, "profit"),
        })
    return parsed


def normalized_utc(time_server: str) -> tuple[str | None, str | None]:
    raw = datetime.strptime(time_server, "%Y.%m.%d %H:%M:%S")
    if is_dst_transition_server_date(raw):
        return None, "UNKNOWN_DST_TRANSITION"
    utc = server_to_utc(time_server)
    return utc.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), None

def build_units(rows: list[dict], run_id: str) -> tuple[list[dict], dict]:
    by_position: dict[int, list[dict]] = defaultdict(list)
    for row in rows:
        by_position[row["position_id_i"]].append(row)

    units: list[dict] = []
    open_positions = 0
    unknown_time_units = 0
    for position_id, group in sorted(by_position.items()):
        if any(r["deal_entry_i"] == ENTRY_INOUT for r in group):
            raise UnitSourceError(f"unsupported INOUT/reversal position_id={position_id}")
        ins = [r for r in group if r["deal_entry_i"] == ENTRY_IN]
        outs = [r for r in group if r["deal_entry_i"] in {ENTRY_OUT, ENTRY_OUT_BY}]
        if not outs:
            open_positions += 1
            continue
        if len(ins) != 1 or len(outs) != 1:
            raise UnitSourceError(
                f"unsupported multi-deal position_id={position_id} in={len(ins)} out={len(outs)}"
            )
        entry, out = ins[0], outs[0]
        if entry["volume_d"] != out["volume_d"]:
            raise UnitSourceError(f"unsupported volume mismatch position_id={position_id} in={entry['volume_d']} out={out['volume_d']}")
        entry_utc, entry_reason = normalized_utc(entry["deal_time_server"])
        exit_utc, exit_reason = normalized_utc(out["deal_time_server"])
        time_status = "COMPLETE" if entry_utc and exit_utc else "UNKNOWN_TIMEZONE"
        if time_status != "COMPLETE":
            unknown_time_units += 1
        source_net = entry["commission_d"] + entry["swap_d"] + entry["profit_d"]
        source_net += out["commission_d"] + out["swap_d"] + out["profit_d"]

        units.append({
            "schema_version": UNIT_SCHEMA,
            "h3_run_id": run_id,
            "symbol": out["symbol"],
            "period": out["period"],
            "period_name": out["period_name"],
            "magic": out["magic"],
            "account_margin_mode": out["account_margin_mode"],
            "source_position_id": str(position_id),
            "source_open_deal_id": str(entry["deal_id_i"]),
            "source_deal_id": str(out["deal_id_i"]),
            "source_open_order_id": str(entry["order_id_i"]),
            "source_close_order_id": str(out["order_id_i"]),
            "entry_time_server": entry["deal_time_server"],
            "exit_time_server": out["deal_time_server"],
            "entry_time_msc": str(entry["deal_time_msc_i"]),
            "exit_time_msc": str(out["deal_time_msc_i"]),
            "entry_utc": entry_utc or "",
            "exit_utc": exit_utc or "",
            "time_status": time_status,
            "time_unknown_reason": entry_reason or exit_reason or "",
            "entry_volume": str(entry["volume_d"]),
            "exit_volume": str(out["volume_d"]),
            "entry_price": str(entry["price_d"]),
            "exit_price": str(out["price_d"]),
            "entry_commission": str(entry["commission_d"]),
            "exit_commission": str(out["commission_d"]),
            "exit_swap": str(out["swap_d"]),
            "exit_profit": str(out["profit_d"]),
            "source_net_realized": str(source_net),
        })

    manifest = {
        "schema_version": "BOSS19_P4B_SOURCE_BOUND_UNIT_MANIFEST_V1",
        "h3_run_id": run_id,
        "source_row_count": len(rows),
        "source_in_count": sum(r["deal_entry_i"] == ENTRY_IN for r in rows),
        "source_out_count": sum(r["deal_entry_i"] in {ENTRY_OUT, ENTRY_OUT_BY} for r in rows),
        "source_position_count": len(by_position),
        "realized_unit_count": len(units),
        "open_position_count": open_positions,
        "unknown_time_unit_count": unknown_time_units,
        "linkage_basis": "EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT",
        "forbidden_inference_used": False,
        "basket_status": "UNAVAILABLE_NO_SOURCE_BASKET_ID",
        "timezone_rule": "REUSE_P4B_LOCAL_OHLC_THINKMARKETS_GMT2_GMT3_US_DST_TRANSITION_QUARANTINE",
    }
    return units, manifest


UNIT_FIELDS = [
    "schema_version", "h3_run_id", "symbol", "period", "period_name", "magic", "account_margin_mode",
    "source_position_id", "source_open_deal_id", "source_deal_id", "source_open_order_id", "source_close_order_id",
    "entry_time_server", "exit_time_server", "entry_time_msc", "exit_time_msc", "entry_utc", "exit_utc",
    "time_status", "time_unknown_reason", "entry_volume", "exit_volume", "entry_price", "exit_price",
    "entry_commission", "exit_commission", "exit_swap", "exit_profit", "source_net_realized",
]

def write_units(path: Path, units: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=UNIT_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(units)


def run(source: Path, run_id: str, output: Path, manifest_path: Path) -> dict:
    rows = read_source(source)
    units, manifest = build_units(rows, run_id)
    write_units(output, units)
    manifest.update({
        "source_file": source.name,
        "source_sha256": sha256(source),
        "unit_file": output.name,
        "unit_sha256": sha256(output),
    })
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, required=True)
    args = ap.parse_args()
    try:
        manifest = run(args.source, args.run_id, args.output, args.manifest)
    except (UnitSourceError, ValueError) as exc:
        print(f"P4B_UNIT_REFUSE: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
