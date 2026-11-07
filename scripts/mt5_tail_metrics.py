#!/usr/bin/env python3
"""mt5_tail_metrics.py — downside / tail-risk metrics from an MT5 Strategy Tester report.

REPORTING ONLY. These numbers sit beside PF / trade count / DD in a results file.
They are NOT a selection objective and NOT a verdict bar: no bar in the CLAUDE.md
VERDICT GATE references them, and adding one requires the owner (ORDER-235 precedent).
Optimizing directly on Sortino/CVaR would re-open the peak-picking failure the
ladder's plateau-center rule exists to prevent.

What it computes (closed-deal basis):
  per trade  : n, mean, VaR95, CVaR95 (mean of the worst 5% closed trades),
               worst trade — money and % of initial deposit
  per month  : every calendar month in the tested window (idle months = 0 return),
               monthly return on start-of-month balance, worst month, CVaR95 month,
               % losing months, Sortino and Sharpe (monthly, annualized x sqrt(12),
               target/risk-free = 0, downside deviation over ALL months)

CAVEAT — closed deals only. Floating loss inside an open grid/basket is invisible
here until the basket closes; for grid/martingale EAs the report's EQUITY drawdown
(printed alongside) is the honest tail number, and these figures are a lower bound
on how bad it got. Monthly Sortino with < 24 months is flagged LOW-N.

Integrity guard: the sum of every non-balance deal's profit+commission+swap must
reconcile with the report's Total Net Profit, otherwise the run aborts (exit 2).

Usage:
  python scripts/mt5_tail_metrics.py <report.htm> [<report2.htm> ...] [--json]
"""
import argparse
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from parse_mt5_report import parse_report  # noqa: E402  (validates the report)

DEAL_HEADER = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price",
               "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]
CLOSE_DIRECTIONS = {"out", "in/out", "out by"}
LOW_N_MONTHS = 24


class TailMetricsError(ValueError):
    pass


def _read_text(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def _num(s):
    s = str(s).replace("\xa0", "").replace(" ", "").replace(",", "").strip()
    if s == "":
        return 0.0
    return float(s)


def extract_deals(path):
    """Rows of the Deals table only (anchored on its header row)."""
    text = _read_text(path)
    deals, in_table = [], False
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S):
        cells = [re.sub("<[^>]+>", "", c).replace("&nbsp;", " ").strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.S)]
        if cells == DEAL_HEADER:
            in_table = True
            continue
        if not in_table:
            continue
        if len(cells) != 13:
            if any(cells):
                in_table = False  # left the Deals table
            continue
        if not cells[0]:
            continue
        try:
            t = datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S")
        except ValueError:
            continue
        typ = cells[3].lower()
        if typ == "balance":
            continue
        pl = _num(cells[8]) + _num(cells[9]) + _num(cells[10])
        deals.append({"time": t, "direction": cells[4].lower(), "pl": pl})
    if not deals:
        raise TailMetricsError("no Deals table rows found")
    return deals


def _months(start, end):
    y, m = start.year, start.month
    out = []
    while (y, m) <= (end.year, end.month):
        out.append(f"{y:04d}-{m:02d}")
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return out


def _cvar(values, q=0.05):
    """Mean of the worst ceil(q*n) values (at least one)."""
    v = sorted(values)
    k = max(1, math.ceil(q * len(v)))
    return sum(v[:k]) / k, v[k - 1]


def compute(path):
    rep = parse_report(path)
    deposit = float(rep["initial_deposit"])
    net = float(rep["net_profit"])
    deals = extract_deals(path)

    total = sum(d["pl"] for d in deals)
    tol = max(1.0, 0.001 * (abs(rep.get("gross_profit") or 0) + abs(rep.get("gross_loss") or 0)))
    if abs(total - net) > tol:
        raise TailMetricsError(
            f"deal sum {total:.2f} does not reconcile with Total Net Profit {net:.2f} (tol {tol:.2f})")

    closes = [d["pl"] for d in deals if d["direction"] in CLOSE_DIRECTIONS]
    out = {
        "report": str(path), "ea": rep.get("ea_name"), "symbol": rep.get("symbol"),
        "period": rep.get("period"), "from": rep.get("from_date"), "to": rep.get("to_date"),
        "initial_deposit": deposit, "net_profit": net, "profit_factor": rep.get("profit_factor"),
        "total_trades": rep.get("total_trades"),
        "equity_dd_max_pct": rep.get("equity_drawdown_maximal_pct"),
        "balance_dd_max_pct": rep.get("balance_drawdown_maximal_pct"),
        "closed_deals": len(closes),
    }
    if closes:
        cvar_t, var_t = _cvar(closes)
        out.update({
            "trade_mean": sum(closes) / len(closes),
            "trade_var95": var_t, "trade_cvar95": cvar_t, "trade_worst": min(closes),
            "trade_cvar95_pct_dep": 100 * cvar_t / deposit,
            "trade_worst_pct_dep": 100 * min(closes) / deposit,
        })

    start = datetime.strptime(rep["from_date"], "%Y.%m.%d")
    end = datetime.strptime(rep["to_date"], "%Y.%m.%d")
    last_deal = max(d["time"] for d in deals)
    if last_deal > end:
        end = last_deal
    months = _months(start, end)
    # MT5's to_date is exclusive: a window ending YYYY.MM.01 has no trading in that month.
    if len(months) > 1 and end.day == 1 and end.month != last_deal.month and last_deal < end:
        months = months[:-1]
    pl_by_month = {m: 0.0 for m in months}
    for d in deals:
        pl_by_month[d["time"].strftime("%Y-%m")] = pl_by_month.get(d["time"].strftime("%Y-%m"), 0.0) + d["pl"]

    bal, rets, monthly = deposit, [], []
    for m in sorted(pl_by_month):
        pl = pl_by_month[m]
        r = pl / bal if bal > 0 else float("nan")
        monthly.append({"month": m, "pl": round(pl, 2), "ret_pct": round(100 * r, 4)})
        rets.append(r)
        bal += pl
    n = len(rets)
    mean = sum(rets) / n
    downside = math.sqrt(sum(min(r, 0.0) ** 2 for r in rets) / n)
    sd = math.sqrt(sum((r - mean) ** 2 for r in rets) / (n - 1)) if n > 1 else 0.0
    cvar_m, _ = _cvar(rets)
    worst = min(monthly, key=lambda x: x["ret_pct"])
    out.update({
        "months": n, "low_n_months": n < LOW_N_MONTHS,
        "sortino_monthly_ann": (mean / downside * math.sqrt(12)) if downside > 0 else None,
        "sharpe_monthly_ann": (mean / sd * math.sqrt(12)) if sd > 0 else None,
        "worst_month": worst["month"], "worst_month_pct": worst["ret_pct"],
        "month_cvar95_pct": 100 * cvar_m,
        "losing_months_pct": 100 * sum(1 for r in rets if r < 0) / n,
        "monthly": monthly,
    })
    return out


def _f(v, fmt="{:.2f}"):
    return "n/a" if v is None else fmt.format(v)


def render(m):
    lines = [
        f"== {m['ea']} {m['symbol']} {m['period']}  {m['from']} -> {m['to']}",
        f"   PF {_f(m['profit_factor'])} · trades {int(m['total_trades'] or 0)} · "
        f"net {_f(m['net_profit'])} · equityDD {_f(m['equity_dd_max_pct'])}% "
        f"(balanceDD {_f(m['balance_dd_max_pct'])}%)",
    ]
    if m.get("closed_deals"):
        lines.append(
            f"   trade : CVaR95 {_f(m['trade_cvar95'])} ({_f(m['trade_cvar95_pct_dep'])}% dep) · "
            f"VaR95 {_f(m['trade_var95'])} · worst {_f(m['trade_worst'])} "
            f"({_f(m['trade_worst_pct_dep'])}% dep) · n={m['closed_deals']}")
    flag = "  [LOW-N: <%d months]" % LOW_N_MONTHS if m["low_n_months"] else ""
    lines.append(
        f"   month : Sortino {_f(m['sortino_monthly_ann'])} · Sharpe {_f(m['sharpe_monthly_ann'])} · "
        f"worst {m['worst_month']} {_f(m['worst_month_pct'])}% · CVaR95 {_f(m['month_cvar95_pct'])}% · "
        f"losing {_f(m['losing_months_pct'], '{:.0f}')}% of {m['months']}{flag}")
    lines.append("   (closed-deal basis; reporting only — not a selection objective or bar)")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("reports", nargs="+")
    ap.add_argument("--json", action="store_true", help="emit JSON (includes the monthly series)")
    a = ap.parse_args(argv)
    results, rc = [], 0
    for p in a.reports:
        try:
            results.append(compute(p))
        except Exception as e:  # report-level failure must be loud, never a silent skip
            print(f"ERROR {p}: {e}", file=sys.stderr)
            rc = 2
    if a.json:
        print(json.dumps(results, indent=2, default=str))
    else:
        print("\n\n".join(render(m) for m in results))
    return rc


if __name__ == "__main__":
    sys.exit(main())
