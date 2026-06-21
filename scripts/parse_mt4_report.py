#!/usr/bin/env python3
"""parse_mt4_report.py — extract key metrics from an MT4 Strategy Tester HTML report.

MT4 report layout differs from MT5: metrics are <td> label/value pairs in a flat
table, and drawdown is rendered as "3.20 (0.03%)". This pulls the screen-relevant
fields and emits JSON (default) or a one-line CSV row (--csv).

Usage:
  python parse_mt4_report.py "<report.htm>"
  python parse_mt4_report.py "<report.htm>" --csv
"""
import sys, re, json, html as _html

def _text(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        raw = f.read()
    t = re.sub(r"<[^>]+>", " ", raw)
    t = _html.unescape(t)
    t = re.sub(r"\s+", " ", t)
    return t

def _num(s):
    if s is None:
        return None
    s = s.replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None

def parse(path):
    t = _text(path)
    d = {"report": path}

    def grab(label, pat):
        m = re.search(re.escape(label) + r"\s*" + pat, t)
        return m.group(1) if m else None

    d["expert"]   = (re.search(r"Strategy Tester Report\s+(.+?)\s+[A-Za-z0-9_\-]+\s*\(Build", t) or [None, None])[1]
    d["symbol"]   = grab("Symbol", r"([A-Za-z0-9_.]+)")
    d["broker"]   = (re.search(r"\(Build [\d]+\)", t) and (re.search(r"Report\s+.+?\s+([\w\-]+)\s*\(Build", t) or [None,None])[1])
    d["period"]   = (re.search(r"Period\s+(.+?)\s+\d{4}\.\d{2}\.\d{2}", t) or [None, None])[1]
    d["bars"]            = _num(grab("Bars in test", r"([\d ]+)"))
    d["ticks"]           = _num(grab("Ticks modelled", r"([\d ]+)"))
    d["quality"]         = grab("Modelling quality", r"([\d.]+%|n/a)")
    d["mismatch_errors"] = _num(grab("Mismatched charts errors", r"([\d ]+)"))
    d["deposit"]         = _num(grab("Initial deposit", r"([\d. ]+)"))
    d["net_profit"]      = _num(grab("Total net profit", r"(-?[\d. ]+)"))
    d["gross_profit"]    = _num(grab("Gross profit", r"(-?[\d. ]+)"))
    d["gross_loss"]      = _num(grab("Gross loss", r"(-?[\d. ]+)"))
    d["profit_factor"]   = _num(grab("Profit factor", r"([\d.]+)"))
    d["expected_payoff"] = _num(grab("Expected payoff", r"(-?[\d.]+)"))
    d["abs_drawdown"]    = _num(grab("Absolute drawdown", r"([\d. ]+)"))

    m = re.search(r"Maximal drawdown\s+([\d. ]+)\s*\(([\d.]+)%\)", t)
    if m:
        d["max_drawdown"] = _num(m.group(1))
        d["max_drawdown_pct"] = _num(m.group(2))
    m = re.search(r"Relative drawdown\s+([\d.]+)%", t)
    if m:
        d["rel_drawdown_pct"] = _num(m.group(1))

    d["total_trades"] = _num(grab("Total trades", r"([\d ]+)"))
    m = re.search(r"Profit trades \(% of total\)\s+[\d ]+\s*\(([\d.]+)%\)", t)
    if m:
        d["win_pct"] = _num(m.group(1))

    # capture EA input parameters (records strategy + flags pip-denominated inputs)
    pm = re.search(r"Parameters\s+(.+?)\s+Bars in test", t, re.S)
    if pm:
        params, pip_suspect = {}, []
        _pipkeys = ("tp","takeprofit","sl","stop","trail","distance","dist","step",
                    "gap","nearby","pip","points","breakeven","grid","range","offset")
        _skip = ("lot","magic","color","font","size","deviation","slippage","comm",
                 "telegram","website","url","percent","number","multiplier","hour")
        for tok in pm.group(1).split(";"):
            tok = tok.strip()
            if "=" in tok:
                k, v = tok.split("=", 1)
                k, v = k.strip(), v.strip()
                params[k] = v
                kl = k.lower()
                if (re.fullmatch(r"-?\d+(\.\d+)?", v) and float(v) != 0
                        and any(x in kl for x in _pipkeys)
                        and not any(s in kl for s in _skip)):
                    pip_suspect.append(f"{k}={v}")
        d["params"] = params
        if pip_suspect:
            d["pip_suspect"] = pip_suspect

    # verdict helper for the screen gate
    pf = d.get("profit_factor"); tr = d.get("total_trades")
    if pf is None or tr is None:
        d["screen"] = "NO_DATA"
    elif tr < 10:
        d["screen"] = "THIN"        # too few trades to judge
    elif pf >= 1.40:
        d["screen"] = "PASS"
    elif pf >= 1.10:
        d["screen"] = "WATCH"
    else:
        d["screen"] = "REJECT"
    return d

CSV_COLS = ["expert","symbol","period","total_trades","profit_factor",
            "net_profit","max_drawdown_pct","win_pct","quality","screen"]

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    as_csv = "--csv" in sys.argv
    if not args:
        print("usage: parse_mt4_report.py <report.htm> [--csv]"); sys.exit(1)
    d = parse(args[0])
    if as_csv:
        print(",".join(str(d.get(c, "")) for c in CSV_COLS))
    else:
        print(json.dumps(d, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
