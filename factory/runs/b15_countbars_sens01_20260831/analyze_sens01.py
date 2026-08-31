#!/usr/bin/env python3
import csv, gzip, hashlib, html, json, re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
WT=ROOT.parents[2]
PAIR=WT/'docs/factory/BOSS11_16_H02_PAIR_MATRIX.csv'
SYMS=('GBPUSD','USDJPY','EURUSD')
COUNTS=(1,3)
WINDOWS=('MAIN','BWD')

def text_gz(p):
    b=gzip.decompress(Path(p).read_bytes())
    return b.decode('utf-16',errors='replace') if b[:2] in (b'\xff\xfe',b'\xfe\xff') else b.decode('utf-8',errors='replace')

def parts(p):
    s=re.sub(r'<[^>]+>','|',text_gz(p))
    return [html.unescape(x).strip() for x in s.split('|') if html.unescape(x).strip()]

def num(s): return float(str(s).replace(' ','').replace(',',''))
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
            'report_sha256':hashlib.sha256(gzip.decompress(Path(p).read_bytes())).hexdigest()}
def deals(p):
    rows=re.findall(r'<tr[^>]*>(.*?)</tr>',text_gz(p),re.S); out=[]
    for row in rows:
        c=[html.unescape(re.sub('<[^>]+>','',x)).strip() for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        if len(c)!=13 or c[4].lower()!='out': continue
        try:
            t=datetime.strptime(c[0],'%Y.%m.%d %H:%M:%S')
            pnl=sum(num(c[i] or '0') for i in (8,9,10))
        except (ValueError,IndexError): continue
        out.append((t,pnl))
    return out

def year_stats(rows):
    gp=sum(max(x,0) for _,x in rows); gl=sum(max(-x,0) for _,x in rows)
    return {'trades':len(rows),'pf':gp/gl if gl else None,'net':round(sum(x for _,x in rows),2)}

def load_parent():
    out={}
    def dd_pct(v):
        m=re.search(r'\(([-+0-9., ]+)%\)',v)
        if not m: raise ValueError(f'unparseable parent DD: {v}')
        return num(m.group(1))
    with PAIR.open(encoding='utf-8-sig',newline='') as f:
        for r in csv.DictReader(f):
            if r['boss']=='15' and r['symbol'] in SYMS and r['tf']=='H4':
                out[r['symbol']]={'MAIN':{'pf':float(r['main_pf']),'net':None,'eqdd_pct':dd_pct(r['main_dd']),'trades':int(r['main_trades'])},
                                  'BWD':{'pf':float(r['bwd_pf']),'net':None,'eqdd_pct':dd_pct(r['bwd_dd']),'trades':int(r['bwd_trades'])}}
    assert set(out)==set(SYMS)
    bt6=json.loads((WT/'factory/runs/bt6_20260830/b15_edge_port01/evidence_summary.json').read_text(encoding='utf-8'))
    for sym in ('USDJPY','EURUSD'):
        for win in WINDOWS:
            src=bt6['homes'][f'{sym}_H4']['PARENT'][win]
            assert abs(src['pf']-out[sym][win]['pf'])<1e-9 and src['trades']==out[sym][win]['trades']
            out[sym][win]['net']=src['net']
    return out

def main():
    parent=load_parent(); cells=[]; years=[]; mechanical=[]
    for count in COUNTS:
        for sym in SYMS:
            for win in WINDOWS:
                name=f'B15_COUNTBARS_SENS01_COUNT{count}_{sym}_H4_{win}_M1'
                d=RAW/name; rp=d/'report.htm.gz'
                lev=json.loads((d/'leverage_check.json').read_text(encoding='utf-8-sig'))
                trunc=json.loads((d/'truncation_check.json').read_text(encoding='utf-8-sig'))
                ok=rp.exists() and lev.get('match') is True and trunc.get('truncated') is False
                m=metrics(rp) if rp.exists() else {}
                mechanical.append({'countbars':count,'symbol':sym,'window':win,'eligible':ok,'leverage':lev.get('status'),'truncated':trunc.get('truncated')})
                cells.append({'countbars':count,'symbol':sym,'tf':'H4','window':win,**m,'eligible':ok})
                by=defaultdict(list)
                for t,pnl in deals(rp): by[t.year].append((t,pnl))
                for y in sorted(by): years.append({'countbars':count,'symbol':sym,'window':win,'year':y,**year_stats(by[y])})
    all_ok=len(mechanical)==12 and all(x['eligible'] for x in mechanical)
    by_child={}
    for count in COUNTS:
        home={}
        for sym in SYMS:
            rows=[x for x in cells if x['countbars']==count and x['symbol']==sym]
            w={x['window']:x for x in rows}
            home[sym]=bool(w['MAIN']['eligible'] and w['BWD']['eligible'] and w['MAIN']['pf']>1 and w['BWD']['pf']>1)
        by_child[str(count)]={'homes':home,'dual_positive_count':sum(home.values())}
    parent_home={s:(parent[s]['MAIN']['pf']>1 and parent[s]['BWD']['pf']>1) for s in SYMS}
    parent_count=sum(parent_home.values())
    if not all_ok: classification='UNKNOWN_MECHANICAL'
    elif max(v['dual_positive_count'] for v in by_child.values())>=2: classification='TIMING_PORTABILITY_IMPROVED'
    elif any(v['dual_positive_count']==1 and v['homes']!=parent_home for v in by_child.values()): classification='HOME_ROTATION_ONLY'
    else: classification='TIMING_NOT_IMPROVED'
    routing='STEP6_TIMING_CONTRACT_MAY_BE_PROPOSED' if classification=='TIMING_PORTABILITY_IMPROVED' else ('BLOCKED_MECHANICAL' if classification=='UNKNOWN_MECHANICAL' else 'PARK_COUNTBARS_TIMING_PATH')
    summary={'schema':'ea-lab-b15-countbars-sens01/1','hypothesis_id':'HYP-B15-COUNTBARS-SENS-01','authority':'RESEARCH_ONLY','holdout':'UNSPENT',
             'parent_countbars':2,'parent_dual_positive':{'homes':parent_home,'dual_positive_count':parent_count},
             'children':by_child,'classification':classification,'routing':routing,'cells':cells,'mechanical':mechanical}
    (ROOT/'evidence_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    (ROOT/'mechanical_acceptance.json').write_text(json.dumps({'all_12_eligible':all_ok,'cells':mechanical},indent=2),encoding='utf-8')
    for fn,rows,fields in [('cell_summary.csv',cells,list(cells[0])),('year_split.csv',years,list(years[0]))]:
        with (ROOT/fn).open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)
    pc=[]
    for count in COUNTS:
        for sym in SYMS:
            for win in WINDOWS:
                c=next(x for x in cells if x['countbars']==count and x['symbol']==sym and x['window']==win); p=parent[sym][win]
                pc.append({'countbars':count,'symbol':sym,'window':win,'parent_pf':p['pf'],'child_pf':c['pf'],'delta_pf':round(c['pf']-p['pf'],6),'parent_net':p['net'],'child_net':c['net'],'delta_net':round(c['net']-p['net'],2) if p['net'] is not None else None,'parent_eqdd_pct':p['eqdd_pct'],'child_eqdd_pct':c['eqdd_pct'],'parent_trades':p['trades'],'child_trades':c['trades']})
    with (ROOT/'parent_child.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(pc[0])); w.writeheader(); w.writerows(pc)
    y=46; svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="390">',
        '<text x="20" y="25" font-size="17">B15 CountBars H4 timing sensitivity - PF by window</text>']
    for count in COUNTS:
        for sym in SYMS:
            m=next(x for x in cells if x['countbars']==count and x['symbol']==sym and x['window']=='MAIN')
            b=next(x for x in cells if x['countbars']==count and x['symbol']==sym and x['window']=='BWD')
            ph=parent[sym]
            svg.append(f'<text x="20" y="{y}" font-size="12">CountBars {count} {sym}: parent PF {ph["MAIN"]["pf"]:.2f}/{ph["BWD"]["pf"]:.2f} -> child PF {m["pf"]:.2f}/{b["pf"]:.2f} (MAIN/BWD)</text>')
            y+=42
    svg.append(f'<text x="20" y="330" font-size="12">Classification: {classification}; parent dual-positive homes={parent_count}/3; child1={by_child["1"]["dual_positive_count"]}/3; child3={by_child["3"]["dual_positive_count"]}/3</text>')
    svg.append('<text x="20" y="365" font-size="11">VISUAL_ONLY_NO_AUTHORITY; exact values in evidence_summary.json and cell_summary.csv</text>')
    svg.append('</svg>')
    (ROOT/'countbars_dual_positive.svg').write_text('\n'.join(svg),encoding='utf-8')
    print(json.dumps({'status':'PASS' if all_ok else 'BLOCKED','classification':classification,'routing':routing,'parent_dual':parent_count,'count1_dual':by_child['1']['dual_positive_count'],'count3_dual':by_child['3']['dual_positive_count']},sort_keys=True))

if __name__=='__main__': main()
