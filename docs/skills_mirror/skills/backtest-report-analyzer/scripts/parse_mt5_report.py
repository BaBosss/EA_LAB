#!/usr/bin/env python3
"""Parse MT5 Strategy Tester reports into JSON.

Supports:
  - Single backtest HTML report (MT5 exports these as UTF-16LE HTML tables)
  - Optimizer XML report (SpreadsheetML "Excel XML" format, ReportOptimizer-*.xml)
  - Optional trade list CSV for derived stats (monthly distribution, concentration)

Usage:
  python parse_mt5_report.py report.html -o out.json
  python parse_mt5_report.py ReportOptimizer-146237.xml -o passes.json [--top 100]
  python parse_mt5_report.py report.html --trades trades.csv -o out.json

Stdlib only — no external dependencies.
"""
import argparse
import csv
import html as html_mod
import io
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


def read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    if raw[:2] in (bytes([255, 254]), bytes([254, 255])):  # UTF-16 BOM
        return raw.decode("utf-16")
    for enc in ("utf-8-sig", "cp1252", "utf-16-le"):
        try:
            text = raw.decode(enc)
            if text.count("\x00") < max(1, len(text) // 100):
                return text
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def to_number(s):
    if s is None:
        return None
    s = str(s).strip().replace("\xa0", " ")
    # MT5 uses space as thousands separator: "1 234.56"; also handle "12.34%"
    s = s.replace(" ", "").replace("%", "")
    s = s.replace(",", "")  # some locales
    m = re.match(r"^-?\d+(\.\d+)?$", s)
    if not m:
        return None
    f = float(s)
    return int(f) if f.is_integer() and "." not in s else f


# ---------------------------------------------------------------- HTML report

# Map of MT5 report labels (EN) -> canonical keys. Value cell may contain
# extra text like "12 345.67 (12.34%)".
HTML_FIELDS = {
    "profit factor": "profit_factor",
    "expected payoff": "expected_payoff",
    "total net profit": "net_profit",
    "gross profit": "gross_profit",
    "gross loss": "gross_loss",
    "sharpe ratio": "sharpe_ratio",
    "recovery factor": "recovery_factor",
    "balance drawdown maximal": "balance_drawdown_maximal",
    "balance drawdown relative": "balance_drawdown_relative",
    "equity drawdown maximal": "equity_drawdown_maximal",
    "equity drawdown relative": "equity_drawdown_relative",
    "total trades": "total_trades",
    "total deals": "total_deals",
    "profit trades": "profit_trades",
    "loss trades": "loss_trades",
    "largest profit trade": "largest_profit_trade",
    "largest loss trade": "largest_loss_trade",
    "average profit trade": "average_profit_trade",
    "average loss trade": "average_loss_trade",
    "initial deposit": "initial_deposit",
    "history quality": "history_quality",
    "bars": "bars",
    "ticks": "ticks",
    "symbol": "symbol",
    "period": "period",
    "expert": "ea_name",
    "broker": "broker",
    "currency": "currency",
    "leverage": "leverage",
}

CONSEC_FIELDS = {
    "maximum consecutive wins": "max_consecutive_wins",
    "maximum consecutive losses": "max_consecutive_losses",
    "maximal consecutive profit": "max_consecutive_profit",
    "maximal consecutive loss": "max_consecutive_loss",
}


def parse_html_report(path: Path) -> dict:
    text = read_text_auto(path)
    # strip tags but keep cell boundaries
    text = re.sub(r"<(td|th)[^>]*>", "\n|CELL|", text, flags=re.I)
    text = re.sub(r"<tr[^>]*>", "\n|ROW|", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = html_mod.unescape(text)

    rows = []
    for row_chunk in text.split("|ROW|"):
        cells = [c.strip() for c in row_chunk.split("|CELL|")]
        cells = [c for c in cells if c]
        if cells:
            rows.append(cells)

    out = {"report_type": "single_backtest", "source_file": str(path)}
    fields = {**HTML_FIELDS, **CONSEC_FIELDS}
    for cells in rows:
        for i, cell in enumerate(cells):
            key = cell.rstrip(":").strip().lower()
            if key in fields and i + 1 < len(cells):
                canon = fields[key]
                value = cells[i + 1]
                if canon in ("symbol", "period", "ea_name", "broker", "currency"):
                    if canon not in out:  # first-wins: settings block precedes deal/order tables
                        out[canon] = value
                    continue
                # split off the "(xx.xx%)" companion ONLY; to_number handles the
                # space/comma thousands separators ("7 497.37" must stay 7497.37)
                num = to_number(value.split("(")[0])
                out[canon] = num if num is not None else value
                # capture "(xx.xx%)" companions
                pct = re.search(r"\(([-\d.,\s]+)%\)", value)
                if pct:
                    out[canon + "_percent"] = to_number(pct.group(1))

    # win rate
    pt, tt = out.get("profit_trades"), out.get("total_trades")
    if isinstance(out.get("profit_trades_percent"), (int, float)):
        out["win_rate_percent"] = out["profit_trades_percent"]
    elif isinstance(pt, (int, float)) and isinstance(tt, (int, float)) and tt:
        out["win_rate_percent"] = round(100.0 * pt / tt, 2)
    return out


# ------------------------------------------------------------- Optimizer XML

def _local(tag):
    return tag.rsplit("}", 1)[-1]


def parse_optimizer_xml(path: Path, top: int = 0) -> dict:
    root = ET.fromstring(path.read_bytes())  # expat honors the declared encoding

    rows = []
    for row in root.iter():
        if _local(row.tag) != "Row":
            continue
        cells = []
        for cell in row:
            if _local(cell.tag) != "Cell":
                continue
            data = None
            for d in cell:
                if _local(d.tag) == "Data":
                    data = d.text
            cells.append(data)
        if cells:
            rows.append(cells)

    if not rows:
        raise ValueError("No rows found — is this an MT5 optimizer XML export?")
    return _optimizer_records(rows, path, top)


def parse_optimizer_csv(path: Path, top: int = 0) -> dict:
    text = read_text_auto(path)
    try:
        dialect = csv.Sniffer().sniff(text[:4000], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    rows = [r for r in csv.reader(io.StringIO(text), dialect=dialect) if r]
    return _optimizer_records(rows, path, top)


def _optimizer_records(rows, path: Path, top: int = 0) -> dict:
    header = [str(h).strip() if h else f"col{i}" for i, h in enumerate(rows[0])]
    passes = []
    for cells in rows[1:]:
        rec = {}
        for h, v in zip(header, cells):
            num = to_number(v)
            rec[h] = num if num is not None else v
        passes.append(rec)

    # canonical aliases (MT5 EN headers)
    alias = {
        "Pass": "pass_id", "Result": "result", "Profit": "net_profit",
        "Expected Payoff": "expected_payoff", "Profit Factor": "profit_factor",
        "Recovery Factor": "recovery_factor", "Sharpe Ratio": "sharpe_ratio",
        "Custom": "custom", "Equity DD %": "max_drawdown_percent",
        "Trades": "total_trades",
    }
    param_cols = [h for h in header if h not in alias]
    for rec in passes:
        for src, dst in alias.items():
            if src in rec:
                rec[dst] = rec[src]

    def sort_key(r):
        v = r.get("net_profit")
        return v if isinstance(v, (int, float)) else float("-inf")

    passes.sort(key=sort_key, reverse=True)
    out = {
        "report_type": "optimizer",
        "source_file": str(path),
        "total_passes": len(passes),
        "columns": header,
        "parameter_columns": param_cols,
        "passes": passes[:top] if top else passes,
    }
    return out


# ----------------------------------------------------------- Trade list CSV

def parse_trades_csv(path: Path) -> dict:
    text = read_text_auto(path)
    sniff = csv.Sniffer()
    try:
        dialect = sniff.sniff(text[:4000], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    profit_col = None
    time_col = None
    rows = list(reader)
    if not rows:
        raise ValueError("empty trade CSV")
    for col in rows[0]:
        lc = (col or "").strip().lower()
        if profit_col is None and lc in ("profit", "net profit", "pnl", "p/l", "result"):
            profit_col = col
        if time_col is None and lc in ("time", "close time", "date", "open time"):
            time_col = col
    if profit_col is None:
        raise ValueError(f"no profit column found in {list(rows[0])}")

    profits, monthly = [], defaultdict(float)
    for r in rows:
        p = to_number(r.get(profit_col))
        if p is None:
            continue
        profits.append(float(p))
        if time_col and r.get(time_col):
            m = re.match(r"(\d{4})[.\-/](\d{2})", str(r[time_col]).strip())
            if m:
                monthly[f"{m.group(1)}-{m.group(2)}"] += float(p)

    net = sum(profits)
    wins = sorted((p for p in profits if p > 0), reverse=True)
    out = {
        "trade_count": len(profits),
        "net_profit": round(net, 2),
        "top5_concentration_pct": round(100 * sum(wins[:5]) / net, 2) if net > 0 and wins else None,
        "largest_win_pct_of_net": round(100 * wins[0] / net, 2) if net > 0 and wins else None,
    }
    if monthly:
        vals = list(monthly.values())
        pos = sum(1 for v in vals if v > 0)
        mean = sum(vals) / len(vals)
        stdev = math.sqrt(sum((v - mean) ** 2 for v in vals) / len(vals)) if len(vals) > 1 else 0.0
        out["monthly"] = {k: round(v, 2) for k, v in sorted(monthly.items())}
        out["profitable_months_pct"] = round(100 * pos / len(vals), 1)
        out["monthly_stdev_over_mean"] = round(stdev / abs(mean), 2) if mean else None
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("report", help="MT5 HTML report or optimizer XML")
    ap.add_argument("--trades", help="optional trade list CSV for derived stats")
    ap.add_argument("--top", type=int, default=0, help="keep only top N optimizer passes in output (0 = all)")
    ap.add_argument("-o", "--output", help="output JSON path (default: stdout)")
    args = ap.parse_args()

    path = Path(args.report)
    if not path.exists():
        sys.exit(f"file not found: {path}")

    suffix = path.suffix.lower()
    head = read_text_auto(path)[:2000]
    head_l = head.lower()
    if suffix == ".xml" or "<workbook" in head_l or "spreadsheetml" in head_l:
        result = parse_optimizer_xml(path, top=args.top)
    elif suffix == ".csv" and re.match(r"^﻿?(pass|set)\b", head_l):
        result = parse_optimizer_csv(path, top=args.top)
    else:
        result = parse_html_report(path)

    if args.trades:
        result["trade_stats"] = parse_trades_csv(Path(args.trades))

    text = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        npass = result.get("total_passes")
        print(f"wrote {args.output} ({result['report_type']}" + (f", {npass} passes" if npass else "") + ")")
    else:
        print(text)


if __name__ == "__main__":
    main()
