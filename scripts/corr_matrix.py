#!/usr/bin/env python
"""Monthly-return correlation matrix across EAs from (time,profit) trade CSVs.
Buckets each EA's realized profit by calendar month, then Pearson-correlates the
monthly-P&L series over the COMMON months. Flags pairs per the project rule:
  >0.60 = redundant (reduce lot, don't cut) · 0.40-0.60 = watch · <=0.40 = additive.

Usage: python corr_matrix.py NAME1=csv1 NAME2=csv2 ...
"""
import sys, csv, re
from collections import defaultdict

def load_monthly(path):
    m=defaultdict(float)
    with open(path, encoding='utf-8') as f:
        r=csv.DictReader(f)
        for row in r:
            t=row.get('time','').strip()
            mm=re.match(r'(\d{4})[.\-/](\d{2})',t)
            if not mm: continue
            ym=f"{mm.group(1)}-{mm.group(2)}"
            try: p=float(row.get('profit','') or 0)
            except: continue
            m[ym]+=p
    return m

def pearson(xs,ys):
    n=len(xs)
    if n<3: return float('nan')
    mx=sum(xs)/n; my=sum(ys)/n
    num=sum((x-mx)*(y-my) for x,y in zip(xs,ys))
    dx=sum((x-mx)**2 for x in xs)**0.5; dy=sum((y-my)**2 for y in ys)**0.5
    if dx==0 or dy==0: return float('nan')
    return num/(dx*dy)

def main():
    eas={}
    for a in sys.argv[1:]:
        name,path=a.split('=',1)
        eas[name]=load_monthly(path)
    names=list(eas.keys())
    # header
    print("months per EA:", {n:len(eas[n]) for n in names})
    w=max(len(n) for n in names)+1
    print(" "*w + "".join(f"{n[:7]:>8}" for n in names))
    for a in names:
        row=f"{a:<{w}}"
        for b in names:
            common=sorted(set(eas[a])&set(eas[b]))
            if len(common)<3: row+=f"{'--':>8}"; continue
            xs=[eas[a][m] for m in common]; ys=[eas[b][m] for m in common]
            c=pearson(xs,ys)
            row+=f"{c:>8.2f}"
        print(row)
    print("\nflags (>0.60 = reduce lot; 0.40-0.60 = watch):")
    for i,a in enumerate(names):
        for b in names[i+1:]:
            common=sorted(set(eas[a])&set(eas[b]))
            if len(common)<3: continue
            c=pearson([eas[a][m] for m in common],[eas[b][m] for m in common])
            tag="REDUCE-LOT" if c>0.60 else ("watch" if c>0.40 else "additive")
            if c>0.40: print(f"  {a} x {b}: {c:.2f}  ({tag}, {len(common)}mo)")

if __name__=='__main__': main()
