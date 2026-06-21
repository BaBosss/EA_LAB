#!/usr/bin/env python3
"""mt4_pipfix_set.py — build a pip-corrected .set from an MT4 report.

On a 3-digit XAUUSD broker (Exness cent), point=0.001. EAs whose SL/TP/distance
inputs were authored for 2-digit gold (point=0.01) are then 10x too tight with
default params — they churn/die and look edgeless. This reads the EA's parameter
list (printed in the Strategy Tester report), multiplies the pip-denominated
inputs by a factor (default 10), and writes a full .set for a corrected re-test.

Auto-detect picks numeric inputs whose name matches pip-ish keywords; you can
override with --fields to be exact. String/bool/color inputs are passed through.

Usage:
  python mt4_pipfix_set.py <report.htm> <out.set>                 # auto-detect, x10
  python mt4_pipfix_set.py <report.htm> <out.set> --mult 10 \
        --fields TP,iTS,iTD,dML,Fix_Distance,Dynamic_distance_start
  python mt4_pipfix_set.py <report.htm> --list                    # just list params
"""
import sys, re, html as _html

PIP_KEYS = ("tp", "takeprofit", "sl", "stop", "stoploss", "trail", "trailing",
            "distance", "dist", "step", "gap", "nearby", "pip", "points",
            "breakeven", "ts", "td", "ml", "range", "offset", "grid",
            "spread")  # MaxSpread/Spread_contr filters block gold EAs on 3-digit brokers

def report_params(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        raw = f.read()
    t = re.sub(r"<[^>]+>", " ", raw)
    t = _html.unescape(t)
    t = re.sub(r"[ \t]+", " ", t)
    m = re.search(r"Parameters\s+(.+?)\s+Bars in test", t, re.S)
    if not m:
        return []
    out = []
    for tok in m.group(1).split(";"):
        tok = tok.strip()
        if "=" in tok:
            k, v = tok.split("=", 1)
            out.append((k.strip(), v.strip()))
    return out

def is_pip_field(name):
    n = name.lower()
    # whole-name or token match against keywords (avoid matching 'lot','magic','color')
    if any(bad in n for bad in ("lot", "magic", "color", "font", "size", "deviation",
                                "slippage", "comm", "telegram", "website", "url",
                                "percent", "number", "multiplier", "hour", "_h", "_mm")):
        return False
    return any(k in n for k in PIP_KEYS)

def is_number(v):
    return re.fullmatch(r"-?\d+(\.\d+)?", v) is not None

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if len(args) < 1:
        print(__doc__); sys.exit(1)
    report = args[0]
    params = report_params(report)
    if not params:
        print("ERROR: no parameters found in report"); sys.exit(2)

    if "--list" in flags:
        for k, v in params:
            tag = "PIP?" if (is_number(v) and is_pip_field(k)) else ""
            print(f"{k}={v}\t{tag}")
        return

    mult = 10.0
    for f in flags:
        if f.startswith("--mult="):
            mult = float(f.split("=", 1)[1])
    if "--mult" in sys.argv:
        i = sys.argv.index("--mult")
        if i + 1 < len(sys.argv):
            mult = float(sys.argv[i + 1])

    explicit = None
    if "--fields" in sys.argv:
        i = sys.argv.index("--fields")
        explicit = set(sys.argv[i + 1].split(","))

    out_set = args[1] if len(args) > 1 else None
    if not out_set:
        print("ERROR: need <out.set>"); sys.exit(1)

    changed = []
    lines = []
    for k, v in params:
        target = (k in explicit) if explicit is not None else (is_number(v) and is_pip_field(k))
        if target and is_number(v):
            nv = float(v) * mult
            nv = int(nv) if nv == int(nv) else nv
            lines.append(f"{k}={nv}")
            changed.append(f"{k}: {v} -> {nv}")
        else:
            lines.append(f"{k}={v}")
    with open(out_set, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {out_set} (x{mult} on {len(changed)} fields):")
    for c in changed:
        print("  " + c)

if __name__ == "__main__":
    main()
