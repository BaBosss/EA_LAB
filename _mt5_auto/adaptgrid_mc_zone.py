#!/usr/bin/env python3
"""
adaptgrid_mc_zone.py — offline MC block-bootstrap zone generator for (EXP)_AdaptGridMC_rev01.

Method (FINDYOUR8 catalog #1, Adaptive Grid: Zero to Hero):
  - input: CSV of D1 bars (columns: close required; high/low optional) — last 1000 rows used
  - 10,000 paths x 60 days, sampled as 24-day blocks of log-returns (block bootstrap
    preserves vol clustering / momentum autocorrelation)
  - pool ALL simulated prices across paths+days -> ZoneLo = P10, ZoneHi = P90
  - ATR(30) RMA over real bars (true range if high/low present, else |dClose| proxy)
  - spacing = 0.3 * ATR ; N = floor((ZoneHi-ZoneLo)/spacing) clamped to <= 40
  - emits a .set snippet for the EA

usage: python adaptgrid_mc_zone.py --csv BTCUSD_D1.csv [--paths 10000] [--horizon 60]
       [--block 24] [--hist 1000] [--spacing-atr 0.3] [--seed 42] [--out zone.set]
CSV export from MT5: right-click chart -> save, or scripts/export_rates (any file with
a 'close' header column works; delimiter auto , or ;).
"""
import argparse, csv, math, random, sys

def read_bars(path):
    with open(path, newline='', encoding='utf-8-sig') as f:
        sample = f.read(4096); f.seek(0)
        delim = ';' if sample.count(';') > sample.count(',') else ','
        rows = list(csv.DictReader(f, delimiter=delim))
    if not rows: sys.exit("empty csv")
    keys = {k.lower().strip('<>'): k for k in rows[0]}
    def col(name): return keys.get(name)
    ck = col('close');
    if not ck: sys.exit("no close column")
    hk, lk = col('high'), col('low')
    bars = []
    for r in rows:
        try: c = float(r[ck])
        except (ValueError, TypeError): continue
        h = float(r[hk]) if hk and r.get(hk) else c
        l = float(r[lk]) if lk and r.get(lk) else c
        bars.append((h, l, c))
    return bars

def atr_rma(bars, period=30):
    trs = []
    for i in range(1, len(bars)):
        h, l, c = bars[i]; pc = bars[i-1][2]
        trs.append(max(h - l, abs(h - pc), abs(l - pc)))
    if len(trs) < period: sys.exit("not enough bars for ATR")
    a = sum(trs[:period]) / period
    for tr in trs[period:]:
        a = (a * (period - 1) + tr) / period   # RMA/Wilder
    return a

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--csv', required=True)
    p.add_argument('--paths', type=int, default=10000)
    p.add_argument('--horizon', type=int, default=60)
    p.add_argument('--block', type=int, default=24)
    p.add_argument('--hist', type=int, default=1000)
    p.add_argument('--spacing-atr', type=float, default=0.3)
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--out', default=None)
    a = p.parse_args()

    bars = read_bars(a.csv)[-a.hist:]
    closes = [b[2] for b in bars]
    if len(closes) < a.block + 2: sys.exit("history too short")
    rets = [math.log(closes[i] / closes[i-1]) for i in range(1, len(closes))]
    last = closes[-1]
    atr = atr_rma(bars, 30)

    rng = random.Random(a.seed)
    max_start = len(rets) - a.block
    pooled = []
    for _ in range(a.paths):
        px, steps = last, 0
        while steps < a.horizon:
            s = rng.randrange(max_start + 1)
            for r in rets[s:s + a.block]:
                if steps >= a.horizon: break
                px *= math.exp(r); pooled.append(px); steps += 1
    pooled.sort()
    def pct(q): return pooled[min(len(pooled) - 1, int(q * len(pooled)))]
    lo, hi = pct(0.10), pct(0.90)
    spacing = a.spacing_atr * atr
    n = max(2, min(40, int((hi - lo) / spacing)))

    print(f"last_close={last:.2f}  ATR30(RMA)={atr:.2f}")
    print(f"ZoneLo(P10)={lo:.2f}  ZoneHi(P90)={hi:.2f}  width={hi-lo:.2f}")
    print(f"spacing({a.spacing_atr}xATR)={spacing:.2f}  N_levels={n} (clamp<=40)")
    snippet = (f"_01_ZoneLo={lo:.2f}\n_01_ZoneHi={hi:.2f}\n"
               f"_01_SpacingAtrMult={a.spacing_atr}\n_01_MaxLevels={n}\n")
    if a.out:
        with open(a.out, 'w', encoding='ascii') as f: f.write(snippet)
        print(f"wrote {a.out}")
    else:
        print("--- .set snippet ---\n" + snippet)

if __name__ == '__main__':
    main()
