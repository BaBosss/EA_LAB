#!/usr/bin/env python3
import csv, gzip, hashlib, html, json, re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
AGG = ROOT / "aggregate"
OUT = ROOT / "final_report"
OUT.mkdir(parents=True, exist_ok=True)
CONTEXTS = ["XAU_H4", "USDJPY_H1", "XAU_M15", "EUR_H4", "GBP_H4"]
VARIANTS = ["DEPTH2", "DEPTH4", "DEPTH5", "SINGLETP_OFF", "BASKETTP_OFF",
            "OVERLAP_OFF", "PIPFLOOR_OFF", "DEEP_SPACING_EQUAL", "SELL_DIRECTION"]

def rows(name):
    with (AGG / name).open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def num(v):
    if v is None or v == "": return None
    return float(str(v).replace(" ", "").replace(",", ""))

def esc(v): return html.escape(str(v))

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def svg_start(w, h, title):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">',
            '<rect width="100%" height="100%" fill="white"/>',
            f'<text x="20" y="28" font-size="18" font-family="sans-serif">{esc(title)}</text>']

def svg_end(chunks, note="VISUAL_ONLY_NO_AUTHORITY"):
    chunks.append(f'<text x="20" y="98%" font-size="10" font-family="sans-serif">{esc(note)}</text>')
    chunks.append('</svg>')
    return "\n".join(chunks)

def build_matrix(pairs):
    lookup={(r['variant'],r['context']):r for r in pairs}
    w,h=1180,390; x0,y0=170,70; cw,ch=105,48
    chunks=svg_start(w,h,"B16 mechanism falsifier matrix")
    for j,v in enumerate(VARIANTS):
        x=x0+j*cw+6
        chunks.append(f'<text x="{x}" y="55" font-size="10" font-family="sans-serif" transform="rotate(-35 {x} 55)">{esc(v)}</text>')
    legend={"HYPOTHESIS_FALSIFIED":"F","HYPOTHESIS_NOT_FALSIFIED":"N","UNKNOWN_MECHANICAL_INELIGIBLE":"U"}
    for i,c in enumerate(CONTEXTS):
        y=y0+i*ch
        chunks.append(f'<text x="20" y="{y+29}" font-size="13" font-family="sans-serif">{esc(c)}</text>')
        for j,v in enumerate(VARIANTS):
            r=lookup[(v,c)]; x=x0+j*cw
            code=legend[r['verdict']]
            shade={"F":"#dddddd","N":"#ffffff","U":"#999999"}[code]
            chunks.append(f'<rect x="{x}" y="{y}" width="{cw-4}" height="{ch-4}" fill="{shade}" stroke="black"/>')
            chunks.append(f'<text x="{x+45}" y="{y+28}" font-size="16" text-anchor="middle" font-family="sans-serif">{code}</text>')
    chunks.append('<text x="20" y="345" font-size="11" font-family="sans-serif">F=falsified by preregistered rule; N=not falsified; U=mechanically ineligible full-window pair.</text>')
    (OUT/'r2_mechanism_verdict_matrix.svg').write_text(svg_end(chunks),encoding='utf-8')

def polyline_plot(path,title,series,ylabel):
    w,h=980,420; left,top,right,bottom=70,55,30,70
    allv=[v for _,pts in series for _,v in pts if v is not None]
    lo=min(allv+[0]); hi=max(allv+[1]); span=max(1e-9,hi-lo)
    chunks=svg_start(w,h,title); plotw=w-left-right; ploth=h-top-bottom
    chunks.append(f'<line x1="{left}" y1="{top+ploth}" x2="{left+plotw}" y2="{top+ploth}" stroke="black"/>')
    chunks.append(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+ploth}" stroke="black"/>')
    if lo < 0 < hi:
        zy=top+ploth-(0-lo)/span*ploth
        chunks.append(f'<line x1="{left}" y1="{zy:.1f}" x2="{left+plotw}" y2="{zy:.1f}" stroke="#888" stroke-dasharray="4,4"/>')
    maxn=max(len(pts) for _,pts in series)
    for sidx,(name,pts) in enumerate(series):
        coords=[]
        for i,(label,v) in enumerate(pts):
            x=left+(i/max(1,maxn-1))*plotw
            y=top+ploth-(v-lo)/span*ploth
            coords.append(f'{x:.1f},{y:.1f}')
            chunks.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="black"/>')
            if sidx==0 and (i==0 or i==len(pts)-1): chunks.append(f'<text x="{x:.1f}" y="{top+ploth+20}" font-size="10" text-anchor="middle" font-family="sans-serif">{esc(label)}</text>')
        dash='' if sidx%2==0 else ' stroke-dasharray="7,4"'
        chunks.append(f'<polyline points="{" ".join(coords)}" fill="none" stroke="black" stroke-width="1.5"{dash}/>')
        chunks.append(f'<text x="{left+10}" y="{top+18+sidx*16}" font-size="11" font-family="sans-serif">{esc(name)}</text>')
    chunks.append(f'<text x="20" y="{h-35}" font-size="11" font-family="sans-serif">{esc(ylabel)}; solid/dashed lines distinguish window/context series only.</text>')
    Path(path).write_text(svg_end(chunks),encoding='utf-8')

def build_depth(pairs,entry,parent):
    pmap={(r['variant'],r['context']):r for r in pairs}; emap={r['context']:r for r in entry}
    series=[]
    for c in ['XAU_H4','USDJPY_H1','XAU_M15']:
        for window,key in [('MAIN','main'),('BWD','bwd')]:
            pts=[]
            if c in emap: pts.append(('1',num(emap[c][f'{key}_net'])))
            else: pts.append(('1',0.0))
            for d in ('DEPTH2','DEPTH4','DEPTH5'): pts.append((d[-1],num(pmap[(d,c)][f'child_{key}_net'])))
            pts.append(('10',num(parent[c][window]['net'])))
            series.append((f'{c} {window}',pts))
    polyline_plot(OUT/'r2_depth_ladder_net.svg','B16 depth ladder: closed-window net',series,'Net USD at depth cap 1/2/4/5/10')

def build_compare_table(filename,title,pairs,variants,parent):
    lookup={(r['variant'],r['context']):r for r in pairs}
    w=1180; rowh=24; rows_out=[]
    for c in CONTEXTS:
        rows_out.append((c,'PARENT',parent[c]['MAIN']['net'],parent[c]['BWD']['net'],parent[c]['MAIN']['dd'],parent[c]['BWD']['dd'],'BASE'))
        for v in variants:
            r=lookup[(v,c)]
            rows_out.append((c,v,num(r['child_main_net']),num(r['child_bwd_net']),num(r['child_main_dd']),num(r['child_bwd_dd']),r['verdict']))
    h=90+rowh*len(rows_out)+35; chunks=svg_start(w,h,title)
    heads=['Context','Variant','MAIN net','BWD net','MAIN EqDD%','BWD EqDD%','Verdict']
    xs=[20,130,350,470,590,720,850]
    for x,t in zip(xs,heads): chunks.append(f'<text x="{x}" y="58" font-size="11" font-family="sans-serif">{esc(t)}</text>')
    y=82
    for row in rows_out:
        for x,val in zip(xs,row): chunks.append(f'<text x="{x}" y="{y}" font-size="10" font-family="sans-serif">{esc(val)}</text>')
        y+=rowh
    Path(OUT/filename).write_text(svg_end(chunks),encoding='utf-8')

def build_verdict_counts(pairs):
    counts=defaultdict(lambda:defaultdict(int))
    for r in pairs: counts[r['variant']][r['verdict']]+=1
    w,h=820,330; chunks=svg_start(w,h,'Falsifier outcomes by mechanism (5 contexts)')
    y=60
    for v in VARIANTS:
        f=counts[v]['HYPOTHESIS_FALSIFIED']; n=counts[v]['HYPOTHESIS_NOT_FALSIFIED']; u=counts[v]['UNKNOWN_MECHANICAL_INELIGIBLE']
        chunks.append(f'<text x="20" y="{y}" font-size="12" font-family="sans-serif">{esc(v)}</text>')
        chunks.append(f'<text x="260" y="{y}" font-size="12" font-family="sans-serif">F={f}  N={n}  U={u}</text>')
        y+=27
    Path(OUT/'r2_falsifier_counts.svg').write_text(svg_end(chunks),encoding='utf-8')

def report_text(path):
    raw=Path(path).read_bytes()
    if str(path).endswith('.gz'): raw=gzip.decompress(raw)
    return raw.decode('utf-16',errors='replace') if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else raw.decode('utf-8',errors='replace')

def closed_deals(path,deposit=10000.0):
    out=[]; bal=deposit; peak=deposit
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>',report_text(path),re.S):
        cells=[html.unescape(re.sub('<[^>]+>','',c)).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        if len(cells)!=13 or cells[4].lower()!='out': continue
        try:
            t=datetime.strptime(cells[0],'%Y.%m.%d %H:%M:%S')
            pnl=sum(num(cells[i] or '0') for i in (8,9,10))
        except Exception: continue
        bal+=pnl; peak=max(peak,bal); dd=(peak-bal)/peak*100 if peak else 0
        out.append({'time':t,'balance':bal,'dd':dd,'pnl':pnl})
    return out

def build_selected_series(filename,title,selections,key,ylabel):
    series=[]
    for label,variant,context,window in selections:
        p=ROOT/'evidence'/variant/context/window/'report.htm.gz'
        ds=closed_deals(p)
        series.append((label,[(str(i+1),r[key]) for i,r in enumerate(ds)]))
    polyline_plot(OUT/filename,title,series,ylabel)

def build_years(years):
    selected=[('SELL_DIRECTION','GBP_H4'),('SINGLETP_OFF','USDJPY_H1'),('BASKETTP_OFF','USDJPY_H1'),('DEPTH5','XAU_H4'),('DEPTH5','XAU_M15')]
    items=[]
    for v,c in selected:
        vals=[r for r in years if r['variant']==v and r['context']==c]
        for r in vals: items.append((f'{c} {v} {r["window"]} {r["year"]}',num(r['net'])))
    w,h=1120,690; chunks=svg_start(w,h,'Selected year-by-year closed-deal net')
    maxabs=max(abs(v) for _,v in items) or 1; base=330; left=30; step=(w-60)/len(items)
    chunks.append(f'<line x1="{left}" y1="{base}" x2="{w-left}" y2="{base}" stroke="black"/>')
    for i,(lab,v) in enumerate(items):
        x=left+i*step+2; bh=abs(v)/maxabs*250; y=base-bh if v>=0 else base
        chunks.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{max(3,step-4):.1f}" height="{bh:.1f}" fill="#777"/>')
        chunks.append(f'<text x="{x:.1f}" y="610" font-size="8" transform="rotate(65 {x:.1f} 610)" font-family="sans-serif">{esc(lab)}</text>')
    Path(OUT/'r2_selected_year_distribution.svg').write_text(svg_end(chunks,'Closed-deal year net; blank-PF years can be all-win/no-loss. VISUAL_ONLY_NO_AUTHORITY'),encoding='utf-8')

def build_exposure(exposure):
    wanted={'DEPTH2','DEPTH4','DEPTH5','SELL_DIRECTION','DEEP_SPACING_EQUAL'}
    rs=[r for r in exposure if r['variant'] in wanted]
    w,h=1180,650; chunks=svg_start(w,h,'Selected exposure / cycle diagnostics')
    heads=['Context','Variant','Win','Eligible','Cycles','MaxDepth','Cap','CapHit','MaxLots','ActiveShare','MultiEntryGP']
    xs=[20,110,300,350,420,480,555,605,665,735,835]
    for x,t in zip(xs,heads): chunks.append(f'<text x="{x}" y="55" font-size="10" font-family="sans-serif">{esc(t)}</text>')
    y=76
    for r in rs[:22]:
        vals=[r['context'],r['variant'],r['window'],r['full_window_eligible'],r['cycle_count'],r['max_basket_depth'],r['configured_cap_overlay'],r['cap_contact_overlay'],r['max_aggregate_lots'],r['active_time_share'],r['multi_entry_gp_share']]
        for x,v in zip(xs,vals): chunks.append(f'<text x="{x}" y="{y}" font-size="9" font-family="sans-serif">{esc(v)}</text>')
        y+=24
    chunks.append('<text x="20" y="620" font-size="10" font-family="sans-serif">Table is intentionally selected/compact; full 88-cell exposure data is cycle_exposure_summary.csv.</text>')
    Path(OUT/'r2_exposure_selected.svg').write_text(svg_end(chunks),encoding='utf-8')

def build_cage(kills):
    w,h=980,230; chunks=svg_start(w,h,'Confirmed hard-cage events in characterization batch')
    y=65
    for name,d in sorted(kills.items()):
        chunks.append(f'<text x="20" y="{y}" font-size="11" font-family="sans-serif">{esc(name)} | market={esc(d["market_time"])} | DD={d["dd_pct"]:.2f}%</text>')
        y+=32
    chunks.append('<text x="20" y="205" font-size="10" font-family="sans-serif">These cells are full-window ineligible; pre-kill PF/net are not used for pair verdicts.</text>')
    Path(OUT/'r2_cage_kills.svg').write_text(svg_end(chunks),encoding='utf-8')

def build_workflow():
    w,h=1280,320; chunks=svg_start(w,h,'B16 source-bound research workflow')
    boxes=[('RSI last closed bar','fixed BUY<Low / SELL>High'),('Bar-open first entry','market + per-order ATR SL'),('Adverse grid add','max(ATRÃ—mult, pip floor)'),('Flat lot default','cap depth / lot cages'),('Exit owner','single TP â†’ basket TP â†’ overlap'),('Safety first','hard DD cage / halt')]
    x=20; y=95
    for i,(a,b) in enumerate(boxes):
        bw=185; chunks.append(f'<rect x="{x}" y="{y}" width="{bw}" height="82" fill="white" stroke="black"/>')
        chunks.append(f'<text x="{x+8}" y="{y+25}" font-size="12" font-family="sans-serif">{esc(a)}</text>')
        chunks.append(f'<text x="{x+8}" y="{y+50}" font-size="10" font-family="sans-serif">{esc(b)}</text>')
        if i<len(boxes)-1: chunks.append(f'<line x1="{x+bw}" y1="{y+41}" x2="{x+bw+24}" y2="{y+41}" stroke="black"/><polygon points="{x+bw+24},{y+41} {x+bw+17},{y+37} {x+bw+17},{y+45}" fill="black"/>')
        x+=209
    chunks.append('<text x="20" y="225" font-size="11" font-family="sans-serif">Changed modules in this milestone: direction, max depth, single TP, basket TP, overlap threshold, pip floor, post-four ATR spacing.</text>')
    chunks.append('<text x="20" y="250" font-size="11" font-family="sans-serif">Frozen: RSI thresholds/period, base lot/ladder, per-order SL, emergency/risk cages, dormant flatten, optimization, HOLDOUT.</text>')
    Path(OUT/'b16_mechanism_workflow.svg').write_text(svg_end(chunks),encoding='utf-8')

def main():
    pairs=rows('pair_falsifier_summary.csv'); entry=rows('entry_only_reused_summary.csv')
    exposure=rows('cycle_exposure_summary.csv'); years=rows('year_split.csv')
    parent=json.loads((AGG/'parent_contexts.json').read_text(encoding='utf-8'))
    kills=json.loads((AGG/'cage_kill_evidence.json').read_text(encoding='utf-8'))
    mech=json.loads((AGG/'mechanical_acceptance.json').read_text(encoding='utf-8'))
    assert len(pairs)==45 and len(rows('cell_summary.csv'))==88 and len(exposure)==88
    assert mech['full_window_eligible_cells']==84 and mech['cage_kill_ineligible_cells']==4
    build_matrix(pairs); build_depth(pairs,entry,parent); build_verdict_counts(pairs)
    build_compare_table('r2_direction_comparison.svg','Direction: accepted BUY parent vs SELL child',pairs,['SELL_DIRECTION'],parent)
    build_compare_table('r2_spacing_comparison.svg','Spacing: parent vs pip-floor-off / post-four equal spacing',pairs,['PIPFLOOR_OFF','DEEP_SPACING_EQUAL'],parent)
    build_compare_table('r2_exit_comparison.svg','Exit/recovery: parent vs single TP / basket TP / overlap disabled',pairs,['SINGLETP_OFF','BASKETTP_OFF','OVERLAP_OFF'],parent)
    build_years(years); build_exposure(exposure); build_cage(kills); build_workflow()
    build_selected_series('r2_gbp_sell_balance_proxy.svg','GBPUSD/H4 SELL closed-deal balance proxy',[("MAIN","SELL_DIRECTION","GBP_H4","MAIN"),("BWD","SELL_DIRECTION","GBP_H4","BWD")],'balance','Closed-deal balance proxy, not native intratrade equity')
    build_selected_series('r2_gbp_sell_underwater_proxy.svg','GBPUSD/H4 SELL closed-deal underwater proxy',[("MAIN","SELL_DIRECTION","GBP_H4","MAIN"),("BWD","SELL_DIRECTION","GBP_H4","BWD")],'dd','Closed-deal balance DD %, not native EqDD')
    build_selected_series('r2_usdjpy_exit_balance_proxy.svg','USDJPY/H1 exit ablations closed-deal balance proxy',[("SingleTP MAIN","SINGLETP_OFF","USDJPY_H1","MAIN"),("SingleTP BWD","SINGLETP_OFF","USDJPY_H1","BWD"),("BasketTP MAIN","BASKETTP_OFF","USDJPY_H1","MAIN"),("BasketTP BWD","BASKETTP_OFF","USDJPY_H1","BWD")],'balance','Closed-deal balance proxy, not native intratrade equity')
    build_selected_series('r2_depth_underwater_proxy.svg','Depth-5 selected underwater proxy',[("XAU H4 MAIN","DEPTH5","XAU_H4","MAIN"),("XAU H4 BWD","DEPTH5","XAU_H4","BWD"),("XAU M15 MAIN","DEPTH5","XAU_M15","MAIN"),("XAU M15 BWD","DEPTH5","XAU_M15","BWD")],'dd','Closed-deal balance DD %, not native EqDD')
    verdicts=defaultdict(int)
    for r in pairs: verdicts[r['verdict']]+=1
    summary={'schema':'ea-lab-b16-mechanism-characterization-final/1','new_cells':88,'full_window_eligible':84,'hard_kill_cells':4,'pair_evaluations':45,'verdict_counts':dict(verdicts),'mechanism_value':'STRONG','holdout':'UNSPENT','optimization':'NONE','authority':'RESEARCH_ONLY'}
    (OUT/'final_summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(json.dumps(summary,sort_keys=True))

if __name__=='__main__': main()
