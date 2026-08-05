#!/usr/bin/env python3
"""Charge the financing cost the MT5 tester silently skips on INTEREST-mode symbols.

WHY THIS EXISTS (measured 2026-07-26, not assumed):
  Probing the tester's own numbers with a 30-day single-position hold showed:
    XAUUSD  SYMBOL_SWAP_MODE_POINTS            -> swap IS charged (-29.25 measured vs -29.19 expected)
    BTCUSD  SYMBOL_SWAP_MODE_INTEREST_CURRENT  -> swap is NOT charged (net == price-only P&L to the cent)
    ETHUSD  SYMBOL_SWAP_MODE_INTEREST_CURRENT  -> same as BTC
  So every XAU backtest in this lab already carries its financing cost and must NOT be adjusted twice,
  while crypto results overstate profit until this script is applied.
  Probes live in ea_projects/(TST)_SymbolSwapProbe/ -- run them before trusting any new symbol.

METHOD (deliberately conservative):
  cost_per_position = notional * (annual_rate/100/360) * days_held
  notional uses the WORSE of entry/exit price, so the bill is never understated.
  Weekend triple-charging is NOT modelled, which understates the cost slightly -- stated, not hidden.

Usage:
  python swap_adjust_crypto.py --rate-long 14.67 --rate-short 0.49 report1.htm [report2.htm ...]
  python swap_adjust_crypto.py --rate-long 9.86 --rate-short 3.95 --deals in.csv --out adj.csv rep*.htm

  --deals/--out  optional: rewrite a trades CSV (time,profit from extract_deals.py) with the cost
                 applied per position, in report order, ready for monte_carlo.py.
Rates are the broker's SYMBOL_SWAP_LONG / SYMBOL_SWAP_SHORT as annual percentages (negative = you pay;
pass them as positive magnitudes).
"""
import argparse
import csv
import re
from datetime import datetime
from pathlib import Path

CELL = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.S | re.I)
ROW = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S | re.I)
TAG = re.compile(r"<[^>]+>")


def read_text_auto(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    for enc in ("utf-8-sig", "cp1252", "utf-16-le"):
        try:
            t = raw.decode(enc)
            if t.count("\x00") < max(1, len(t) // 100):
                return t
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def num(s):
    s = str(s).replace("\xa0", "").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def days_between(t0, t1):
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return max(0.0, (datetime.strptime(t1.strip(), fmt)
                             - datetime.strptime(t0.strip(), fmt)).total_seconds() / 86400.0)
        except ValueError:
            continue
    return None


def positions(path):
    """Pair in/out deals from an MT5 single-test report into positions.

    Yields (open_time, close_time, side, volume, price_open, price_close).
    Deals table layout: Time Deal Symbol Type Direction Volume Price Order Commission Swap Profit Balance
    """
    txt = read_text_auto(path)
    stack, out = [], []
    for row in ROW.findall(txt):
        c = [TAG.sub("", x).replace("&nbsp;", " ").strip() for x in CELL.findall(row)]
        if len(c) < 10 or not re.match(r"^\d{4}\.\d{2}\.\d{2}", c[0] or ""):
            continue
        side, direction, vol, price = c[3].lower(), c[4].lower(), num(c[5]), num(c[6])
        if side not in ("buy", "sell") or vol is None or price is None:
            continue
        if direction.startswith("in"):
            stack.append((c[0], side, vol, price))
        elif direction.startswith("out") and stack:
            t0, side0, vol0, px0 = stack.pop(0)
            out.append((t0, c[0], side0, vol0, px0, price))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("reports", nargs="+")
    ap.add_argument("--rate-long", type=float, required=True, help="annual %% paid on long notional")
    ap.add_argument("--rate-short", type=float, required=True, help="annual %% paid on short notional")
    ap.add_argument("--contract", type=float, default=1.0, help="SYMBOL_TRADE_CONTRACT_SIZE (crypto = 1.0)")
    ap.add_argument("--deals", help="trades CSV from extract_deals.py to adjust (time,profit)")
    ap.add_argument("--out", help="where to write the adjusted trades CSV")
    a = ap.parse_args()

    costs, total_days = [], 0.0
    for p in a.reports:
        for t0, t1, side, vol, px0, px1 in positions(p):
            d = days_between(t0, t1)
            if d is None:
                continue
            rate = a.rate_long if side == "buy" else a.rate_short
            costs.append(max(px0, px1) * a.contract * vol * (rate / 100.0 / 360.0) * d)
            total_days += d

    if not costs:
        print("no positions parsed -- is this a summary-only report?")
        return
    print(f"positions      : {len(costs)}")
    print(f"mean days held : {total_days/len(costs):.2f}")
    print(f"swap charged   : -{sum(costs):.2f}")

    if not (a.deals and a.out):
        return
    rows = list(csv.DictReader(open(a.deals, newline="", encoding="utf-8-sig")))
    if len(rows) != len(costs):
        raise SystemExit(f"MISMATCH deals={len(rows)} positions={len(costs)} -- "
                         "same reports in the same order must be passed to both")
    gp = gl = agp = agl = 0.0
    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["time", "profit"])
        for r, c in zip(rows, costs):
            p = float(r["profit"])
            adj = p - c
            w.writerow([r["time"], f"{adj:.2f}"])
            gp += p if p >= 0 else 0.0
            gl += -p if p < 0 else 0.0
            agp += adj if adj >= 0 else 0.0
            agl += -adj if adj < 0 else 0.0
    print(f"BEFORE  PF={gp/gl:.3f} net={gp-gl:+.2f}")
    print(f"AFTER   PF={agp/agl:.3f} net={agp-agl:+.2f}")
    print("wrote", a.out)


if __name__ == "__main__":
    main()
