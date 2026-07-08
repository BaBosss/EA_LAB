#!/usr/bin/env python
"""Extract (close_time, profit) per closed trade from an MT4 tester report HTML,
for correlation analysis. MT4 trade rows: the closing rows (type close/s/l/t/p)
carry the Profit in a known column. We pair by emitting one row per closing deal
with its time + profit.

Usage: python mt4_deals_to_csv.py <report.htm> <out.csv>
"""
import sys, re, csv

def read_text(p):
    b=open(p,'rb').read()
    if b[:2] in (b'\xff\xfe', b'\xfe\xff'):   # explicit UTF-16 BOM only
        return b.decode('utf-16')
    for e in ('utf-8','cp1252','latin-1'):    # MT4 reports are usually ansi/cp1252
        try: return b.decode(e)
        except: pass
    return b.decode('utf-8','replace')

def num(s):
    s=re.sub(r'<[^>]+>','',s).replace('&nbsp;',' ').strip().replace(' ','')
    if s in ('','-'): return None
    try: return float(s)
    except: return None

def main():
    html=read_text(sys.argv[1])
    trs=re.findall(r'<tr bgcolor[^>]*>(.*?)</tr>',html,re.S)
    out=[]
    for r in trs:
        tds=[re.sub(r'<[^>]+>','',c).replace('&nbsp;',' ').strip() for c in re.findall(r'<td[^>]*>(.*?)</td>',r,re.S)]
        if len(tds)<9: continue
        typ=tds[2].lower()
        if typ.startswith('close') or typ in ('s/l','t/p','close'):
            t=tds[1]
            prof=num(tds[8]) if len(tds)>8 else None
            # MT4 profit column position varies; scan last few cells for a signed number
            if prof is None:
                for c in tds[::-1]:
                    v=num(c)
                    if v is not None: prof=v; break
            if prof is not None and t:
                out.append((t,prof))
    if not out:
        print("no closed deals parsed"); return
    with open(sys.argv[2],'w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['time','profit']); w.writerows(out)
    print(f"wrote {len(out)} closed trades, sum={sum(p for _,p in out):.2f} -> {sys.argv[2]}")

if __name__=='__main__': main()
