"""
mt4_monthly.py - extract per-month realized P&L from an MT4 Strategy Tester report .htm,
with a built-in self-validation gate (sum of extracted trade profits MUST equal the report's
own "Total Net Profit", else the parse is rejected — no silently-wrong corr inputs).

MT4 tester trade table columns: # | Time | Type | Order | Size | Price | S/L | T/P | Profit | Balance
Closing rows (Type in close/s/l/t/p/close at stop/close by) carry the realized Profit; open
(buy/sell) and modify rows have an empty Profit cell. We sum Profit by close-time year-month.

Usage:
    from mt4_monthly import extract_monthly_mt4
    monthly, ok, net_extracted, net_reported = extract_monthly_mt4(path)
    # monthly: {'2024-11': 123.4, ...}; ok=True only if extracted≈reported net.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from robust_text import read_text_robust

_CLOSE_TYPES = {"close", "s/l", "t/p", "close at stop", "close by"}

def _num(s):
    s = s.replace(" ", "").replace(",", "").strip()
    try:
        return float(s)
    except ValueError:
        return None

def extract_monthly_mt4(path):
    t = read_text_robust(path)
    net_reported = None
    m = re.search(r"Total\s*Net\s*Profit[^0-9\-]*([\-0-9 .,]+)", t, re.I)
    if m:
        net_reported = _num(m.group(1))

    monthly = {}
    net_extracted = 0.0
    n_trades = 0
    for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", t, re.S | re.I):
        cells = [re.sub(r"<[^>]+>", "", c).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S | re.I)]
        if len(cells) != 10:
            continue
        time_s, typ, profit_s = cells[1], cells[2].lower(), cells[8]
        if typ not in _CLOSE_TYPES:
            continue
        dm = re.match(r"(\d{4})\.(\d{2})\.(\d{2})", time_s)
        p = _num(profit_s)
        if not dm or p is None:
            continue
        ym = f"{dm.group(1)}-{dm.group(2)}"
        monthly[ym] = monthly.get(ym, 0.0) + p
        net_extracted += p
        n_trades += 1

    ok = (net_reported is not None
          and abs(net_extracted - net_reported) <= max(1.0, abs(net_reported) * 0.01))
    return monthly, ok, round(net_extracted, 2), net_reported, n_trades


def pearson(a, b):
    keys = sorted(set(a) | set(b))
    xs = [a.get(k, 0.0) for k in keys]
    ys = [b.get(k, 0.0) for k in keys]
    n = len(keys)
    if n < 2:
        return None
    mx, my = sum(xs) / n, sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = sum((x - mx) ** 2 for x in xs) ** 0.5
    dy = sum((y - my) ** 2 for y in ys) ** 0.5
    if dx == 0 or dy == 0:
        return None
    return num / (dx * dy)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        mo, ok, ne, nr, nt = extract_monthly_mt4(p)
        flag = "OK" if ok else "FAIL-VALIDATION"
        print(f"{flag:16s} extracted_net={ne:>12} reported_net={nr} trades={nt} months={len(mo)}  {os.path.basename(p)}")
