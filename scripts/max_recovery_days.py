#!/usr/bin/env python
"""Measure the LONGEST time a basket stayed open before closing (recovery duration)
from an MT5 report's deal list. A "basket" = the span from when position count goes
0->1 (first entry) until it returns to 0 (all closed / TP). Reports max & distribution
of basket durations in DAYS. Answers: "how long, worst case, until it recovers to TP?"

Usage: python max_recovery_days.py <report.htm>
"""
import sys, re
from datetime import datetime

def read_text(p):
    b=open(p,'rb').read()
    if b[:2] in (b'\xff\xfe',b'\xfe\xff'): return b.decode('utf-16')
    for e in ('utf-8','cp1252','latin-1'):
        try: return b.decode(e)
        except: pass
    return b.decode('utf-8','replace')

def main():
    html=read_text(sys.argv[1])
    di=html.find('>Deals<'); sec=html[di:] if di!=-1 else html
    rows=re.findall(r'<tr[^>]*>(.*?)</tr>',sec,re.S)
    header=None; deals=[]
    for r in rows:
        cells=re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',r,re.S)
        if not cells: continue
        txt=[re.sub(r'<[^>]+>','',c).replace('&nbsp;',' ').strip() for c in cells]
        low=[t.lower() for t in txt]
        if header is None and 'time' in low and ('direction' in low or 'volume' in low):
            header=low; continue
        if header is None or len(cells)<len(header): continue
        rec=dict(zip(header,txt))
        t=rec.get('time','').strip()
        dr=rec.get('direction','').strip().lower()   # in / out
        vol=rec.get('volume','') or '0'
        try: dt=datetime.strptime(t,'%Y.%m.%d %H:%M:%S')
        except:
            try: dt=datetime.strptime(t,'%Y.%m.%d %H:%M')
            except: continue
        try: v=float(re.sub(r'[^0-9.]','',vol) or 0)
        except: v=0.0
        deals.append((dt,dr,v))
    if not deals:
        print("no deals parsed"); return
    # walk: net open volume; basket start when 0->positive, end when back to ~0
    net=0.0; start=None; durs=[]
    for dt,dr,v in deals:
        if dr=='in':
            if net<=1e-9: start=dt
            net+=v
        elif dr=='out':
            net-=v
            if net<=1e-9 and start is not None:
                durs.append((dt-start).total_seconds()/86400.0); start=None
    if not durs:
        print("no completed baskets"); return
    durs.sort()
    n=len(durs)
    print(f"baskets: {n}")
    print(f"max recovery: {durs[-1]:.1f} days")
    print(f"95th pct: {durs[int(n*0.95)-1]:.1f} days")
    print(f"median: {durs[n//2]:.1f} days")
    over7=sum(1 for d in durs if d>7); over30=sum(1 for d in durs if d>30)
    print(f">7 days: {over7} ({100*over7/n:.0f}%)  |  >30 days: {over30} ({100*over30/n:.0f}%)")

if __name__=='__main__': main()
