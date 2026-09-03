#!/usr/bin/env python3
import csv, gzip, hashlib, html, json, re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
BASE='ff8b8200f8f789c46bc6f852a8985fc9594127da'
HYP='HYP-B15-EDGE-PORT-02'

def read_bytes(p):
    b=Path(p).read_bytes()
    return gzip.decompress(b) if str(p).endswith('.gz') else b

def text(p):
    b=read_bytes(p)
    return b.decode('utf-16',errors='replace') if b[:2] in (b'\xff\xfe',b'\xfe\xff') else b.decode('utf-8',errors='replace')

def parts(p):
    s=re.sub(r'<[^>]+>','|',text(p))
    return [html.unescape(x).strip() for x in s.split('|') if html.unescape(x).strip()]

def num(s): return float(s.replace(' ','').replace(',',''))

def metric(p,label):
    a=parts(p)
    for i,v in enumerate(a[:-1]):
        if v==label: return a[i+1]
    return ''

def metrics(p):
    eq=metric(p,'Equity Drawdown Maximal:')
    m=re.search(r'\(([-+0-9., ]+)%\)',eq)
    return {'pf':num(metric(p,'Profit Factor:')),'net':num(metric(p,'Total Net Profit:')),
            'eqdd_pct':num(m.group(1)) if m else None,'trades':int(num(metric(p,'Total Trades:'))),
            'quality':metric(p,'History Quality:') or metric(p,'Modelling Quality:'),
            'report_sha256':hashlib.sha256(read_bytes(p)).hexdigest()}

def deals(p):
    rows=re.findall(r'<tr[^>]*>(.*?)</tr>',text(p),re.S); out=[]
    for row in rows:
        c=[html.unescape(re.sub('<[^>]+>','',x)).strip() for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        if len(c)!=13 or c[4].lower()!='out': continue
        try:
            t=datetime.strptime(c[0],'%Y.%m.%d %H:%M:%S')
            pnl=sum(num(c[i] or '0') for i in (8,9,10))
        except ValueError: continue
        out.append((t,pnl))
    return out

def stats(rows):
    gp=sum(max(p,0) for _,p in rows); gl=sum(max(-p,0) for _,p in rows)
    eq=peak=10000.0; dd=0.0
    for _,p in rows:
        eq+=p; peak=max(peak,eq); dd=max(dd,(peak-eq)/peak*100 if peak else 0)
    return {'trades':len(rows),'pf':gp/gl if gl else None,'net':sum(p for _,p in rows),'balance_dd_pct':dd}

def main():
    homes=[('AUDUSD','H4')]
    summary={'schema':'ea-lab-r2-evidence/1','hypothesis_id':HYP,'canonical_base_sha':BASE,
             'intervention':'_15_EdgeTrigger=true -> false','authority':'RESEARCH_ONLY','homes':{}}
    year_rows=[]; pc_rows=[]
    for symbol,tf in homes:
        hk=f'{symbol}_{tf}'; summary['homes'][hk]={}
        for variant in ('PARENT','CHILD'):
            summary['homes'][hk][variant]={}
            for window in ('MAIN','BWD'):
                p=RAW/f'BT9_B15_EDGE_PORT02_{variant}_{symbol}_{tf}_{window}_M1.htm.gz'
                m=metrics(p); summary['homes'][hk][variant][window]=m
                by=defaultdict(list)
                for t,pnl in deals(p): by[t.year].append((t,pnl))
                for y in sorted(by):
                    s=stats(by[y]); year_rows.append([symbol,tf,variant,window,y,s['trades'],s['pf'],s['net'],s['balance_dd_pct']])
        for window in ('MAIN','BWD'):
            p=summary['homes'][hk]['PARENT'][window]; c=summary['homes'][hk]['CHILD'][window]
            d={'pf':c['pf']-p['pf'],'net':c['net']-p['net'],'eqdd_pp':c['eqdd_pct']-p['eqdd_pct'],'trades':c['trades']-p['trades']}
            summary['homes'][hk].setdefault('delta',{})[window]=d
            pc_rows.append([symbol,tf,window,p['pf'],c['pf'],p['net'],c['net'],p['eqdd_pct'],c['eqdd_pct'],p['trades'],c['trades']])
    (ROOT/'evidence_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    with (ROOT/'year_split.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['symbol','tf','variant','window','year','trades','pf','net','balance_dd_pct']); w.writerows(year_rows)
    with (ROOT/'parent_child.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['symbol','tf','window','parent_pf','child_pf','parent_net','child_net','parent_eqdd_pct','child_eqdd_pct','parent_trades','child_trades']); w.writerows(pc_rows)
    y=44; chunks=['<svg xmlns="http://www.w3.org/2000/svg" width="980" height="330">',
        '<text x="20" y="24" font-size="17">HYP-B15-EDGE-PORT-02 parent vs level-mode child</text>']
    for r in pc_rows:
        symbol,tf,window,pp,cp,pn,cn,pd,cd,pt,ct=r
        chunks.append(f'<text x="20" y="{y}" font-size="12">{symbol}/{tf} {window}: PF {pp:.2f}â†’{cp:.2f} | net {pn:+.2f}â†’{cn:+.2f} | EqDD {pd:.2f}%â†’{cd:.2f}% | trades {pt}â†’{ct}</text>')
        y+=34
    chunks.append('<text x="20" y="310" font-size="11">VISUAL_ONLY_NO_AUTHORITY; exact values in evidence_summary.json and parent_child.csv</text>')
    chunks.append('</svg>')
    (ROOT/'r2_parent_child.svg').write_text('\n'.join(chunks),encoding='utf-8')
    print(json.dumps({'status':'PASS','summary':str(ROOT/'evidence_summary.json')},sort_keys=True))

if __name__=='__main__': main()
