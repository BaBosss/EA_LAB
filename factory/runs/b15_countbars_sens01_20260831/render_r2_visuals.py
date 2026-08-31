#!/usr/bin/env python3
import csv, gzip, html, json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
VIS=ROOT/'visuals'
VIS.mkdir(exist_ok=True)

def text_gz(p):
    b=gzip.decompress(Path(p).read_bytes())
    return b.decode('utf-16',errors='replace') if b[:2] in (b'\xff\xfe',b'\xfe\xff') else b.decode('utf-8',errors='replace')

def num(s): return float(str(s).replace(' ','').replace(',',''))

def deals(p):
    rows=re.findall(r'<tr[^>]*>(.*?)</tr>',text_gz(p),re.S); out=[]
    for row in rows:
        c=[html.unescape(re.sub('<[^>]+>','',x)).strip() for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        if len(c)!=13 or c[4].lower()!='out': continue
        try: out.append((c[0],sum(num(c[i] or '0') for i in (8,9,10))))
        except (ValueError,IndexError): pass
    return out

def esc(s): return html.escape(str(s),quote=True)

def line_svg(path,title,values,footer):
    w,h=1000,360; ml,mr,mt,mb=70,30,55,55
    lo=min(values); hi=max(values); span=(hi-lo) or 1.0
    pts=[]
    for i,v in enumerate(values):
        x=ml+(w-ml-mr)*(i/max(1,len(values)-1))
        y=mt+(h-mt-mb)*(hi-v)/span
        pts.append(f'{x:.1f},{y:.1f}')
    y0=mt+(h-mt-mb)*(hi-0)/span if lo<=0<=hi else None
    s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">',
       f'<text x="20" y="28" font-size="18">{esc(title)}</text>',
       f'<line x1="{ml}" y1="{mt}" x2="{ml}" y2="{h-mb}" stroke="black"/>',
       f'<line x1="{ml}" y1="{h-mb}" x2="{w-mr}" y2="{h-mb}" stroke="black"/>']
    if y0 is not None: s.append(f'<line x1="{ml}" y1="{y0:.1f}" x2="{w-mr}" y2="{y0:.1f}" stroke="gray" stroke-dasharray="5,5"/>')
    s += [f'<polyline points="{" ".join(pts)}" fill="none" stroke="black" stroke-width="2"/>',
          f'<text x="20" y="{mt+10}" font-size="11">max {hi:.2f}</text>',
          f'<text x="20" y="{h-mb}" font-size="11">min {lo:.2f}</text>',
          f'<text x="20" y="{h-18}" font-size="11">{esc(footer)}</text>','</svg>']
    path.write_text('\n'.join(s),encoding='utf-8')

def bars_svg(path,title,labels,values,footer):
    w,h=1000,390; ml,mr,mt,mb=80,30,60,75
    maxabs=max([abs(v) for v in values]+[1.0]); zero=(mt+h-mb)/2
    step=(w-ml-mr)/len(values); scale=(h-mt-mb)/2/maxabs
    s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">',f'<text x="20" y="28" font-size="18">{esc(title)}</text>',f'<line x1="{ml}" y1="{zero:.1f}" x2="{w-mr}" y2="{zero:.1f}" stroke="black"/>']
    for i,(lab,v) in enumerate(zip(labels,values)):
        x=ml+i*step+step*.15; bw=step*.7; bh=abs(v)*scale; y=zero-bh if v>=0 else zero
        s.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw:.1f}" height="{bh:.1f}" fill="none" stroke="black"/>')
        s.append(f'<text x="{x:.1f}" y="{zero + (16 if v>=0 else -6):.1f}" font-size="10">{esc(lab)}</text>')
        s.append(f'<text x="{x:.1f}" y="{y-5 if v>=0 else y+bh+14:.1f}" font-size="10">{v:+.2f}</text>')
    s += [f'<text x="20" y="{h-18}" font-size="11">{esc(footer)}</text>','</svg>']
    path.write_text('\n'.join(s),encoding='utf-8')

def main():
    rp=RAW/'B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1'/'report.htm.gz'
    ds=deals(rp); bal=10000.0; balances=[]; dd=[]; peak=bal
    for _,pnl in ds:
        bal+=pnl; balances.append(bal); peak=max(peak,bal); dd.append((peak-bal)/peak*100 if peak else 0.0)
    line_svg(VIS/'r2_closed_deal_balance_proxy.svg','B15 CountBars=3 GBPUSD/H4 MAIN — closed-deal balance proxy',balances,'CLOSED_DEAL_BALANCE_PROXY / VISUAL_ONLY_NO_AUTHORITY; native MT5 floating-equity series was not exported in the HTML.')
    line_svg(VIS/'r2_closed_deal_underwater_proxy.svg','B15 CountBars=3 GBPUSD/H4 MAIN — closed-deal underwater proxy',[-x for x in dd],'CLOSED_DEAL_DD_PROXY / VISUAL_ONLY_NO_AUTHORITY; canonical EqDD remains the MT5 report field.')
    yrs=[]
    with (ROOT/'year_split.csv').open(encoding='utf-8',newline='') as f:
        for r in csv.DictReader(f):
            if r['countbars']=='3' and r['symbol']=='GBPUSD': yrs.append(r)
    labels=[f"{r['window']}-{r['year']}" for r in yrs]; values=[float(r['net']) for r in yrs]
    bars_svg(VIS/'r2_year_distribution.svg','B15 CountBars=3 GBPUSD/H4 — yearly closed-deal net',labels,values,'VISUAL_ONLY_NO_AUTHORITY; values from year_split.csv.')
    summary=json.loads((ROOT/'evidence_summary.json').read_text(encoding='utf-8'))
    gb={2:{'MAIN':1.10,'BWD':1.07}}
    for count in (1,3):
        gb[count]={}
        for win in ('MAIN','BWD'):
            gb[count][win]=next(x['pf'] for x in summary['cells'] if x['countbars']==count and x['symbol']=='GBPUSD' and x['window']==win)
    labels=[]; vals=[]
    for count in (1,2,3):
        for win in ('MAIN','BWD'): labels.append(f'C{count}-{win}'); vals.append(gb[count][win]-1.0)
    bars_svg(VIS/'r2_countbars_mechanism_compare.svg','GBPUSD/H4 CountBars 1 / parent 2 / 3 — PF minus 1.0',labels,vals,'MECHANISM_COMPARE / VISUAL_ONLY_NO_AUTHORITY; parent from accepted H02, children from this experiment.')
    pc=[]
    with (ROOT/'parent_child.csv').open(encoding='utf-8',newline='') as f: pc=list(csv.DictReader(f))
    labels=[f"C{r['countbars']}-{r['symbol']}-{r['window']}" for r in pc]
    vals=[float(r['delta_pf']) for r in pc]
    bars_svg(VIS/'r2_parent_child_pf_delta.svg','B15 CountBars sensitivity — child minus parent PF',labels,vals,'PARENT_CHILD_DELTA / VISUAL_ONLY_NO_AUTHORITY; exact values in parent_child.csv.')
    manifest={'selected_cell':'COUNT3_GBPUSD_H4_MAIN','native_balance_graph':'visuals/native/B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1.png','visuals':[
      'visuals/r2_closed_deal_balance_proxy.svg','visuals/r2_closed_deal_underwater_proxy.svg','visuals/r2_year_distribution.svg','visuals/r2_countbars_mechanism_compare.svg','visuals/r2_parent_child_pf_delta.svg'],
      'native_equity_series':'UNAVAILABLE_IN_EXPORTED_HTML','authority':'VISUAL_ONLY_NO_AUTHORITY'}
    (VIS/'visual_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'PASS','visuals':len(manifest['visuals']),'selected_cell':manifest['selected_cell']},sort_keys=True))

if __name__=='__main__': main()
