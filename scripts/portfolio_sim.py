#!/usr/bin/env python
"""Combined-portfolio monthly simulation from per-EA closed-trade CSVs (time,profit).
Normalizes each EA to EQUAL profit-weight over the common window (so no single EA's
lot scale dominates), sums to a portfolio series, and reports combined max drawdown,
worst month, % positive months. Also reports the gold-pair (Zeus+BRK) sub-portfolio
since they share XAUUSD. Answers: is the 6-EA cohort safe to run together, and does
the gold pair stack dangerously?

Usage: python portfolio_sim.py NAME=csv ... [--gold NAME1,NAME2]
"""
import sys, csv, re
from collections import defaultdict

def load_monthly(path):
    m=defaultdict(float)
    with open(path,encoding='utf-8') as f:
        for row in csv.DictReader(f):
            t=row.get('time','').strip(); mm=re.match(r'(\d{4})[.\-/](\d{2})',t)
            if not mm: continue
            try: p=float(row.get('profit','') or 0)
            except: continue
            m[f"{mm.group(1)}-{mm.group(2)}"]+=p
    return m

def maxdd(equity):
    peak=equity[0]; dd=0.0
    for e in equity:
        peak=max(peak,e); dd=max(dd,peak-e)
    return dd

def stats(name, months, series):
    # series: dict ym->value over `months`
    vals=[series.get(m,0.0) for m in months]
    eq=[]; c=0.0
    for v in vals: c+=v; eq.append(c)
    dd=maxdd([0.0]+eq)
    total=sum(vals); pos=sum(1 for v in vals if v>0)
    worst=min(vals) if vals else 0
    # express DD as % of total gain (portfolio-relative, lot-agnostic since normalized)
    ddpct = (dd/total*100) if total>0 else float('inf')
    print(f"{name:<16} months={len(months)}  total={total:6.2f}  maxDD={dd:6.2f} ({ddpct:5.1f}% of gain)  worstMo={worst:6.2f}  pos={100*pos/len(months):3.0f}%")

def main():
    args=[a for a in sys.argv[1:] if not a.startswith('--')]
    gold=None
    for a in sys.argv[1:]:
        if a.startswith('--gold'): gold=a.split('=',1)[1].split(',') if '=' in a else None
    eas={}
    for a in args:
        n,p=a.split('=',1); eas[n]=load_monthly(p)
    # common window = union of months (portfolio runs all together; missing EA-month = 0)
    allm=sorted(set().union(*[set(m) for m in eas.values()]))
    # normalize each EA to equal positive-total (unit profit-weight) over its active months
    norm={}
    for n,m in eas.items():
        s=sum(v for v in m.values() if v>0) or 1.0
        norm[n]={k:v/s for k,v in m.items()}   # each EA's winning months sum to 1.0
    print("=== per-EA (normalized to equal profit-weight) ===")
    for n in eas: stats(n, sorted(eas[n].keys()), norm[n])
    print("\n=== COMBINED 6-EA portfolio (equal-weight, all months) ===")
    port={ym: sum(norm[n].get(ym,0.0) for n in eas) for ym in allm}
    stats("PORTFOLIO", allm, port)
    if gold:
        print(f"\n=== GOLD PAIR ({'+'.join(gold)}) — shared XAUUSD ===")
        gm=sorted(set().union(*[set(eas[g]) for g in gold]))
        gp={ym: sum(norm[g].get(ym,0.0) for g in gold) for ym in gm}
        stats("GOLD-PAIR", gm, gp)

if __name__=='__main__': main()
