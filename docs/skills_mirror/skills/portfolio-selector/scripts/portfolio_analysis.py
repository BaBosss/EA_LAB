#!/usr/bin/env python3
"""Portfolio analysis: correlation + drawdown overlap across EAs.

Input CSV: column `month` (YYYY-MM) + one column per EA.
Values are monthly returns in percent (--mode pct, default) or monthly P/L in
account currency (--mode money, requires --deposit).

Outputs JSON: Pearson correlation matrix, DD overlap %, severe-DD overlap %,
worst same-month weighted loss, crisis months, combined-equity max DD.

Usage:
  python portfolio_analysis.py returns.csv [--weights "EA_A=0.5,EA_B=0.5"]
         [--mode pct|money] [--deposit 10000] [--loss-target 10] [-o out.json]
"""
import argparse
import csv
import io
import json
import math
import sys
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


def pearson(xs, ys):
    n = len(xs)
    if n < 3:
        return None
    mx, my = sum(xs) / n, sum(ys) / n
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    sy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if sx == 0 or sy == 0:
        return None
    return cov / (sx * sy)


def corr_level(c):
    a = abs(c)
    if a < 0.3:
        return "LOW"
    if a < 0.6:
        return "MEDIUM"
    if a <= 0.8:
        return "HIGH"
    return "VERY_HIGH"


def dd_flags(returns_pct, severe_dd_pct):
    """Monthly cumulative equity → (in_dd, in_severe_dd) flags per month."""
    equity = 1.0
    peak = 1.0
    flags = []
    for r in returns_pct:
        equity *= (1 + r / 100.0)
        peak = max(peak, equity)
        dd = (peak - equity) / peak * 100.0 if peak > 0 else 100.0
        flags.append((dd > 1e-9, dd >= severe_dd_pct))
    return flags


def max_dd(returns_pct):
    equity, peak, worst = 1.0, 1.0, 0.0
    for r in returns_pct:
        equity *= (1 + r / 100.0)
        peak = max(peak, equity)
        if peak > 0:
            worst = max(worst, (peak - equity) / peak * 100.0)
    return worst


def overlap_color(pct, severe=False):
    bands = [(10, "GREEN"), (20, "YELLOW"), (35, "ORANGE")] if severe else \
            [(25, "GREEN"), (40, "YELLOW"), (60, "ORANGE")]
    for limit, color in bands:
        if pct < limit:
            return color
    return "RED"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("returns_csv")
    ap.add_argument("--weights", default="", help='e.g. "EA_A=0.5,EA_B=0.5" (default: equal)')
    ap.add_argument("--mode", choices=["pct", "money"], default="pct")
    ap.add_argument("--deposit", type=float, default=None, help="required for --mode money")
    ap.add_argument("--loss-target", type=float, default=10.0,
                    help="max portfolio monthly loss target %% (default 10)")
    ap.add_argument("-o", "--output")
    args = ap.parse_args()

    text = read_text_auto(Path(args.returns_csv))
    try:
        dialect = csv.Sniffer().sniff(text[:4000], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    rows = list(csv.DictReader(io.StringIO(text), dialect=dialect))
    if not rows:
        sys.exit("empty CSV")

    month_col = next((c for c in rows[0] if (c or "").strip().lower() in ("month", "date")), None)
    if month_col is None:
        sys.exit("need a 'month' column (YYYY-MM)")
    ea_names = [c for c in rows[0] if c != month_col and c]

    months, series = [], {ea: [] for ea in ea_names}
    for r in rows:
        try:
            vals = {ea: float(str(r[ea]).replace(",", "").replace("%", "").strip() or 0)
                    for ea in ea_names}
        except ValueError:
            continue
        months.append(r[month_col].strip())
        for ea, v in vals.items():
            series[ea].append(v)

    if args.mode == "money":
        if not args.deposit:
            sys.exit("--mode money requires --deposit")
        series = {ea: [100.0 * v / args.deposit for v in vs] for ea, vs in series.items()}

    # weights
    weights = {ea: 1.0 / len(ea_names) for ea in ea_names}
    if args.weights:
        for pair in args.weights.split(","):
            k, _, v = pair.partition("=")
            if k.strip() in weights:
                weights[k.strip()] = float(v)
        total = sum(weights.values())
        weights = {k: v / total for k, v in weights.items()}

    # correlation + DD overlap
    pairs = []
    per_ea_maxdd = {ea: round(max_dd(series[ea]), 2) for ea in ea_names}
    per_ea_flags = {ea: dd_flags(series[ea], per_ea_maxdd[ea] * 0.5) for ea in ea_names}
    for i, a in enumerate(ea_names):
        for b in ea_names[i + 1:]:
            c = pearson(series[a], series[b])
            both = sum(1 for (fa, _), (fb, _) in zip(per_ea_flags[a], per_ea_flags[b]) if fa and fb)
            sev = sum(1 for (_, sa), (_, sb) in zip(per_ea_flags[a], per_ea_flags[b]) if sa and sb)
            n = len(months)
            ov = round(100.0 * both / n, 1)
            sev_ov = round(100.0 * sev / n, 1)
            pairs.append({
                "ea_a": a, "ea_b": b,
                "correlation": round(c, 3) if c is not None else None,
                "correlation_level": corr_level(c) if c is not None else "N/A",
                "dd_overlap_pct": ov, "dd_overlap_color": overlap_color(ov),
                "severe_overlap_pct": sev_ov, "severe_overlap_color": overlap_color(sev_ov, severe=True),
            })

    # combined portfolio
    combined = [sum(weights[ea] * series[ea][m] for ea in ea_names) for m in range(len(months))]
    worst_idx = min(range(len(combined)), key=lambda m: combined[m]) if combined else None
    crisis = [
        {"month": months[m], "combined_return_pct": round(combined[m], 2),
         "eas_down_gt5": [ea for ea in ea_names if series[ea][m] < -5.0]}
        for m in range(len(months))
        if combined[m] < -args.loss_target
        or sum(1 for ea in ea_names if series[ea][m] < -5.0) >= 2
    ]

    out = {
        "source_file": args.returns_csv,
        "months": len(months),
        "period": f"{months[0]}..{months[-1]}" if months else "",
        "ea_names": ea_names,
        "weights": {k: round(v, 4) for k, v in weights.items()},
        "per_ea_max_dd_pct": per_ea_maxdd,
        "pairs": pairs,
        "combined": {
            "max_dd_pct": round(max_dd(combined), 2),
            "worst_same_month_loss_pct": round(combined[worst_idx], 2) if worst_idx is not None else None,
            "worst_month": months[worst_idx] if worst_idx is not None else None,
            "mean_monthly_return_pct": round(sum(combined) / len(combined), 3) if combined else None,
        },
        "crisis_months": crisis,
        "loss_target_pct": args.loss_target,
        "blocking_flags": {
            "correlation_gt_0_7": [f"{p['ea_a']}~{p['ea_b']}" for p in pairs
                                   if p["correlation"] is not None and p["correlation"] > 0.7],
            "dd_overlap_red": [f"{p['ea_a']}~{p['ea_b']}" for p in pairs
                               if p["dd_overlap_color"] == "RED" or p["severe_overlap_color"] == "RED"],
        },
    }

    text_out = json.dumps(out, indent=2)
    if args.output:
        Path(args.output).write_text(text_out, encoding="utf-8")
        print(f"wrote {args.output}")
    else:
        print(text_out)


if __name__ == "__main__":
    main()
