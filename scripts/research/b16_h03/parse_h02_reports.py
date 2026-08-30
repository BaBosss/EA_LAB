#!/usr/bin/env python3
"""Deterministically decompose frozen B16 H02 Strategy Tester HTML reports.

This parser intentionally consumes only report bytes and their matching tester INIs.
It does not invoke MT5 or alter an EA/configuration.  A cycle is reconstructed only
from a transition of the report's own `in` deal ledger from flat to non-flat and
back to flat.  Any unsupported field is represented as UNKNOWN, never estimated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


DATE_FMT = "%Y.%m.%d %H:%M:%S"


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self.row: list[str] | None = None
        self.cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []

    def handle_data(self, data: str) -> None:
        if self.cell is not None:
            text = data.strip()
            if text:
                self.cell.append(text)

    def handle_endtag(self, tag: str) -> None:
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join(self.cell))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            if self.row:
                self.rows.append(self.row)
            self.row = None


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def number(value: str) -> float:
    return float(value.replace(" ", "").replace("%", ""))


def parse_html(path: Path) -> list[list[str]]:
    parser = TableParser()
    parser.feed(path.read_text(encoding="utf-16", errors="strict"))
    return parser.rows


def find_value(rows: list[list[str]], label: str) -> str:
    for row in rows:
        for index, item in enumerate(row[:-1]):
            if item == label:
                return row[index + 1]
    raise ValueError(f"required report label absent: {label}")


def parse_ini(path: Path) -> dict[str, str]:
    output: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in raw and not raw.lstrip().startswith(";"):
            key, value = raw.split("=", 1)
            output[key.strip()] = value.strip()
    return output


def effective_inputs_sha256(ini: dict[str, str]) -> str:
    tester_keys = {
        "Expert", "Symbol", "Period", "Model", "Optimization", "FromDate", "ToDate",
        "ForwardMode", "Deposit", "Currency", "Leverage", "ExecutionMode", "Visual",
        "Report", "ReplaceReport", "ShutdownTerminal",
    }
    payload = {key: ini[key] for key in sorted(ini) if key not in tester_keys}
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def date_from_period(value: str) -> tuple[str, str, str]:
    match = re.fullmatch(r"(\w+) \((\d{4}\.\d{2}\.\d{2}) - (\d{4}\.\d{2}\.\d{2})\)", value)
    if not match:
        raise ValueError(f"unparseable Period: {value!r}")
    return match.group(1), match.group(2), match.group(3)


def pf(gross_profit: float, gross_loss: float) -> float | None:
    return None if gross_loss == 0 else gross_profit / abs(gross_loss)


def pnl_summary(items: list[dict[str, Any]]) -> dict[str, Any]:
    values = [item["pnl"] for item in items]
    gp = sum(value for value in values if value > 0)
    gl = sum(value for value in values if value < 0)
    return {
        "count": len(items),
        "net_profit": round(sum(values), 2),
        "gross_profit": round(gp, 2),
        "gross_loss": round(gl, 2),
        "profit_factor": None if pf(gp, gl) is None else round(pf(gp, gl), 4),
    }


def closed_ticket_summary(cycles: list[dict[str, Any]]) -> dict[str, Any]:
    """Source convention: report gross P/L is over individual closed out-deals."""
    tickets = [ticket for cycle in cycles for ticket in cycle["closed_tickets"]]
    values = [ticket["pnl"] for ticket in tickets]
    gp = sum(value for value in values if value > 0)
    gl = sum(value for value in values if value < 0)
    return {
        "closed_ticket_count": len(tickets),
        "net_profit": round(sum(values), 2),
        "gross_profit": round(gp, 2),
        "gross_loss": round(gl, 2),
        "profit_factor": None if pf(gp, gl) is None else round(pf(gp, gl), 4),
    }


def realized_drawdown(cycles: list[dict[str, Any]], initial_balance: float) -> dict[str, Any]:
    balance = initial_balance
    peak = balance
    peak_time: str | None = None
    maximum = 0.0
    interval: dict[str, str | None] = {"peak_time": None, "trough_time": None}
    for cycle in cycles:
        balance += cycle["pnl"]
        if balance >= peak:
            peak = balance
            peak_time = cycle["end"]
        dd = peak - balance
        if dd > maximum:
            maximum = dd
            interval = {"peak_time": peak_time, "trough_time": cycle["end"]}
    return {"realized_balance_dd_peak": round(maximum, 2), **interval}


def parse_deals(rows: list[list[str]]) -> list[dict[str, Any]]:
    marker = next(index for index, row in enumerate(rows) if row == ["Deals"])
    header = rows[marker + 1]
    if header != ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]:
        raise ValueError(f"unexpected deal header: {header!r}")
    deals: list[dict[str, Any]] = []
    for row in rows[marker + 2 :]:
        if len(row) != len(header):
            continue
        record = dict(zip(header, row))
        if record["Type"] == "balance":
            continue
        if record["Direction"] not in {"in", "out"}:
            raise ValueError(f"unsupported deal direction: {record['Direction']!r}")
        record["time"] = datetime.strptime(record["Time"], DATE_FMT)
        record["deal"] = int(record["Deal"])
        record["volume"] = number(record["Volume"])
        record["price"] = number(record["Price"])
        record["commission"] = number(record["Commission"])
        record["swap"] = number(record["Swap"])
        record["profit"] = number(record["Profit"])
        record["pnl"] = round(record["commission"] + record["swap"] + record["profit"], 2)
        deals.append(record)
    return sorted(deals, key=lambda deal: (deal["time"], deal["deal"]))


def reconstruct_cycles(deals: list[dict[str, Any]]) -> list[dict[str, Any]]:
    open_deals: list[dict[str, Any]] = []
    cycles: list[dict[str, Any]] = []
    current: list[dict[str, Any]] = []
    maximum_positions = 0
    maximum_lots = 0.0
    for deal in deals:
        if deal["Direction"] == "in":
            if not open_deals:
                current = []
                maximum_positions = 0
                maximum_lots = 0.0
            open_deals.append(deal)
            current.append(deal)
            maximum_positions = max(maximum_positions, len(open_deals))
            maximum_lots = max(maximum_lots, sum(item["volume"] for item in open_deals))
            continue
        if not open_deals:
            raise ValueError(f"out deal {deal['deal']} occurs while flat")
        current.append(deal)
        remaining = deal["volume"]
        while remaining > 1e-9 and open_deals:
            first = open_deals[0]
            consumed = min(first["volume"], remaining)
            first = dict(first)
            first["volume"] -= consumed
            remaining -= consumed
            if first["volume"] <= 1e-9:
                open_deals.pop(0)
            else:
                open_deals[0] = first
        if remaining > 1e-9:
            raise ValueError(f"out deal {deal['deal']} exceeds source open volume")
        if not open_deals:
            entries = [item for item in current if item["Direction"] == "in"]
            exits = [item for item in current if item["Direction"] == "out"]
            entry_prices = [item["price"] for item in entries]
            levels = [int(match.group(1)) + 1 for item in entries if (match := re.search(r"\bL(\d+)\b", item["Comment"]))]
            direction_types = sorted({item["Type"] for item in entries})
            cycles.append(
                {
                    "cycle": len(cycles) + 1,
                    "start": entries[0]["Time"],
                    "end": exits[-1]["Time"],
                    "duration_seconds": int((exits[-1]["time"] - entries[0]["time"]).total_seconds()),
                    "entry_count": len(entries),
                    "closed_ticket_count": len(exits),
                    "direction": "+".join(direction_types),
                    "pnl": round(sum(item["pnl"] for item in exits), 2),
                    "gross_profit": round(sum(item["pnl"] for item in exits if item["pnl"] > 0), 2),
                    "gross_loss": round(sum(item["pnl"] for item in exits if item["pnl"] < 0), 2),
                    "max_simultaneous_positions": maximum_positions,
                    "max_aggregate_lots": round(maximum_lots, 4),
                    "max_basket_depth": max(levels) if levels and len(levels) == len(entries) else None,
                    "entry_price_span": round(max(entry_prices) - min(entry_prices), 5),
                    "exit_type": "UNKNOWN",
                    "deal_ids": [item["deal"] for item in current],
                    "closed_tickets": [{"deal": item["deal"], "pnl": item["pnl"]} for item in exits],
                }
            )
    if open_deals:
        raise ValueError("source deal ledger ends non-flat")
    return cycles


def bin_cycles(cycles: list[dict[str, Any]], start: str, end: str) -> list[dict[str, Any]]:
    start_dt = datetime.strptime(start, "%Y.%m.%d")
    end_dt = datetime.strptime(end, "%Y.%m.%d")
    boundaries = [
        (str(year), datetime(year, 1, 1), datetime(year + 1, 1, 1))
        for year in range(start_dt.year, end_dt.year + 1)
    ]
    fold_mid = datetime(start_dt.year + 1, 7, 1)
    boundaries.extend([
        ("FOLD_1", start_dt, fold_mid),
        ("FOLD_2", fold_mid, datetime(end_dt.year + 1, 1, 1)),
    ])
    result: list[dict[str, Any]] = []
    window_seconds = (datetime(end_dt.year + 1, 1, 1) - start_dt).total_seconds()
    for label, left, right in boundaries:
        members = [cycle for cycle in cycles if left <= datetime.strptime(cycle["end"], DATE_FMT) < right]
        summary = closed_ticket_summary(members)
        active_seconds = sum(cycle["duration_seconds"] for cycle in members)
        result.append({
            "bin": label,
            **summary,
            "cycle_count": len(members),
            "active_seconds_sum": active_seconds,
            "active_time_share_full_window": round(active_seconds / window_seconds, 6),
            "realized_balance_dd": realized_drawdown(members, 0.0)["realized_balance_dd_peak"],
        })
    return result


def direction_summary(cycles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    overall = closed_ticket_summary(cycles)
    all_gross_profit = overall["gross_profit"]
    all_gross_loss = abs(overall["gross_loss"])
    for direction in sorted({cycle["direction"] for cycle in cycles}):
        members = [cycle for cycle in cycles if cycle["direction"] == direction]
        summary = closed_ticket_summary(members)
        output.append({
            "direction": direction,
            **summary,
            "gross_profit_share": None if not all_gross_profit else round(summary["gross_profit"] / all_gross_profit, 6),
            "gross_loss_share": None if not all_gross_loss else round(abs(summary["gross_loss"]) / all_gross_loss, 6),
        })
    return output


def analyze(report: Path, ini_path: Path) -> dict[str, Any]:
    rows = parse_html(report)
    ini = parse_ini(ini_path)
    period, start, end = date_from_period(find_value(rows, "Period:"))
    deals = parse_deals(rows)
    cycles = reconstruct_cycles(deals)
    report_values = {
        "expert": find_value(rows, "Expert:"),
        "symbol": find_value(rows, "Symbol:"),
        "period": period,
        "window_start": start,
        "window_end": end,
        "initial_deposit": find_value(rows, "Initial Deposit:"),
        "leverage": find_value(rows, "Leverage:"),
        "net_profit": number(find_value(rows, "Total Net Profit:")),
        "gross_profit": number(find_value(rows, "Gross Profit:")),
        "gross_loss": number(find_value(rows, "Gross Loss:")),
        "profit_factor": number(find_value(rows, "Profit Factor:")),
        "total_trades": int(number(find_value(rows, "Total Trades:"))),
        "total_deals": int(number(find_value(rows, "Total Deals:"))),
        "equity_drawdown_maximal": find_value(rows, "Equity Drawdown Maximal:"),
        "equity_drawdown_relative": find_value(rows, "Equity Drawdown Relative:"),
        "largest_profit_trade": number(find_value(rows, "Largest profit trade:")),
        "largest_loss_trade": number(find_value(rows, "Largest loss trade:")),
    }
    reconstructed = closed_ticket_summary(cycles)
    reconstructed["deal_history_count"] = len(deals)
    # Report Total Trades is the number of exit-side closed tickets in this report convention.
    reconciliation = {
        "net_profit_matches": reconstructed["net_profit"] == report_values["net_profit"],
        "gross_profit_matches": reconstructed["gross_profit"] == report_values["gross_profit"],
        "gross_loss_matches": reconstructed["gross_loss"] == report_values["gross_loss"],
        "profit_factor_matches_rounded": round(reconstructed["profit_factor"] or 0, 2) == round(report_values["profit_factor"], 2),
        "closed_ticket_count_matches_total_trades": reconstructed["closed_ticket_count"] == report_values["total_trades"],
        "report_convention": "closed out-deal P&L includes Profit + Swap + Commission; Total Trades equals out-deal count",
    }
    top_profit = sorted((cycle for cycle in cycles if cycle["pnl"] > 0), key=lambda cycle: (-cycle["pnl"], cycle["cycle"]))[:5]
    top_loss = sorted((cycle for cycle in cycles if cycle["pnl"] < 0), key=lambda cycle: (cycle["pnl"], cycle["cycle"]))[:5]
    total_gp = reconstructed["gross_profit"]
    total_gl = abs(reconstructed["gross_loss"])
    multi_entry_gp = sum(cycle["gross_profit"] for cycle in cycles if cycle["entry_count"] > 1)
    cap_depth_cycles = [cycle for cycle in cycles if cycle["max_basket_depth"] == 10]
    active_seconds = sum(cycle["duration_seconds"] for cycle in cycles)
    full_seconds = (datetime.strptime(end, "%Y.%m.%d").replace(year=datetime.strptime(end, "%Y.%m.%d").year + 1) - datetime.strptime(start, "%Y.%m.%d")).total_seconds()
    return {
        "input": {"report_path": str(report), "report_sha256": sha256(report), "ini_path": str(ini_path), "ini_sha256": sha256(ini_path)},
        "identity": {"report": report_values, "ini": {key: ini.get(key) for key in ("Expert", "Symbol", "Period", "Model", "Optimization", "FromDate", "ToDate", "Deposit", "Currency", "Leverage", "Report")}, "effective_tester_inputs_sha256": effective_inputs_sha256(ini)},
        "reconstructed": reconstructed,
        "reconciliation": reconciliation,
        "cycles": cycles,
        "bins": bin_cycles(cycles, start, end),
        "direction": direction_summary(cycles),
        "exposure": {
            "cycle_reconstruction": "DERIVED_FROM_FLAT_TO_NONFLAT_TO_FLAT_DEAL_LEDGER",
            "first_cycle_start": cycles[0]["start"],
            "last_cycle_end": cycles[-1]["end"],
            "max_simultaneous_positions": max(cycle["max_simultaneous_positions"] for cycle in cycles),
            "max_basket_depth": max(cycle["max_basket_depth"] for cycle in cycles if cycle["max_basket_depth"] is not None),
            "max_aggregate_lots": max(cycle["max_aggregate_lots"] for cycle in cycles),
            "max_entry_price_span": max(cycle["entry_price_span"] for cycle in cycles),
            "configured_orders_per_side_cap": 10,
            "cap_contact": bool(cap_depth_cycles),
            "flat_lots_observed": len({cycle["max_aggregate_lots"] / cycle["max_simultaneous_positions"] for cycle in cycles}) == 1,
            "optional_ladder_use": "UNKNOWN_FROM_REPORT_HISTORY",
            "exit_type": "UNKNOWN_FROM_REPORT_HISTORY",
            "active_seconds_sum": active_seconds,
            "union_active_seconds": active_seconds,
            "active_time_share_full_window": round(active_seconds / full_seconds, 6),
        },
        "concentration": {
            "top_profitable_cycles": [{**cycle, "gross_profit_share": round(cycle["gross_profit"] / total_gp, 6)} for cycle in top_profit],
            "top_losing_cycles": [{**cycle, "gross_loss_share": round(abs(cycle["gross_loss"]) / total_gl, 6)} for cycle in top_loss],
            "multi_entry_positive_gross_profit_share": round(multi_entry_gp / total_gp, 6),
        },
        "tail": {
            "source_equity_drawdown_maximal": report_values["equity_drawdown_maximal"],
            "source_equity_drawdown_relative": report_values["equity_drawdown_relative"],
            "intratrade_equity_series": "UNKNOWN_NOT_PRESENT_IN_HTML_TABLES",
            "underwater_series": "UNKNOWN_NOT_PRESENT_IN_HTML_TABLES",
            "realized_balance_drawdown": realized_drawdown(cycles, number(report_values["initial_deposit"])),
            "largest_realized_cycle_loss": min(cycle["pnl"] for cycle in cycles),
            "source_largest_realized_ticket_loss": report_values["largest_loss_trade"],
            "hard_kill_or_emergency_close": "UNKNOWN_NOT_IDENTIFIABLE_FROM_REPORT_HISTORY",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--main-report", type=Path, required=True)
    parser.add_argument("--main-ini", type=Path, required=True)
    parser.add_argument("--bwd-report", type=Path, required=True)
    parser.add_argument("--bwd-ini", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"parser": "b16_h03.parse_h02_reports.v1", "main": analyze(args.main_report, args.main_ini), "bwd": analyze(args.bwd_report, args.bwd_ini)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
