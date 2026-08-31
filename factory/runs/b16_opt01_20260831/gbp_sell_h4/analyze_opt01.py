import csv, json, math, pathlib, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parent
XML=ROOT/'optimizer.xml'
NS='{urn:schemas-microsoft-com:office:spreadsheet}'
PERIODS=[7,14,21,28]
HIGHS=[60,65,70,75,80]
BASE=(14,70)

def row_values(row):
    out=[]; pos=1
    for cell in list(row):
        idx=cell.attrib.get(NS+'Index')
        if idx: pos=int(idx)
        data=cell.find(NS+'Data')
        while len(out)<pos-1: out.append(None)
        out.append(None if data is None else data.text)
        pos += 1
    return out

rows=list(ET.parse(XML).getroot().iter(NS+'Row'))
raw=[row_values(r) for r in rows]
header=raw[0]
records=[]
for values in raw[1:]:
    values=values+[None]*(len(header)-len(values))
    d=dict(zip(header,values))
    rec={
        'pass':int(d['Pass']), 'result':float(d['Result']), 'net':float(d['Profit']),
        'expected_payoff':float(d['Expected Payoff']),
        'pf':None if d['Profit Factor'] in (None,'') else float(d['Profit Factor']),
        'recovery_factor':float(d['Recovery Factor']), 'sharpe':float(d['Sharpe Ratio']),
        'custom':float(d['Custom']), 'eqdd_pct':float(d['Equity DD %']),
        'trades':int(d['Trades']), 'rsi_period':int(d['_16_RsiPeriod']),
        'rsi_high':int(float(d['_16_RsiHigh']))}
    records.append(rec)
expected={(p,h) for p in PERIODS for h in HIGHS}
seen={(r['rsi_period'],r['rsi_high']) for r in records}
if len(records)!=20 or seen!=expected or len(seen)!=len(records):
    raise SystemExit(f'grid mismatch rows={len(records)} missing={sorted(expected-seen)} extra={sorted(seen-expected)}')
by={(r['rsi_period'],r['rsi_high']):r for r in records}
base=by[BASE]
if not (abs(base['net']-283.20)<1e-9 and base['trades']==80 and abs(base['eqdd_pct']-1.7184)<1e-9):
    raise SystemExit(f'accepted baseline reproduction mismatch: {base}')
fields=['pass','result','net','expected_payoff','pf','recovery_factor','sharpe','custom','eqdd_pct','trades','rsi_period','rsi_high']
with (ROOT/'optimizer_surface.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(sorted(records,key=lambda r:(r['rsi_period'],r['rsi_high'])))
centers=[]
for p in PERIODS[1:-1]:
    for h in HIGHS[1:-1]:
        pts=[(p,h),(p-7,h),(p+7,h),(p,h-5),(p,h+5)]
        cells=[by[x] for x in pts]
        eligible=all(c['net']>0 for c in cells)
        centers.append({'rsi_period':p,'rsi_high':h,'eligible':eligible,
                        'min_net':min(c['net'] for c in cells),
                        'min_trades':min(c['trades'] for c in cells),
                        'max_eqdd_pct':max(c['eqdd_pct'] for c in cells),
                        'distance_steps':abs(p-BASE[0])/7+abs(h-BASE[1])/5,
                        'cross':[{**{'rsi_period':x[0],'rsi_high':x[1]},**{k:by[x][k] for k in ('net','pf','trades','eqdd_pct')}} for x in pts]})
eligible=[c for c in centers if c['eligible']]
selected=None
if eligible:
    selected=sorted(eligible,key=lambda c:(-c['min_net'],-c['min_trades'],c['max_eqdd_pct'],c['distance_steps'],c['rsi_period'],c['rsi_high']))[0]
selection={'schema':'ea-lab-b16-opt01-selection/1','hypothesis_revision':'B16-H05-r1',
           'xml_sha256':__import__('hashlib').sha256(XML.read_bytes()).hexdigest(),
           'grid_complete':True,'grid_rows':len(records),'baseline_reproduced':True,
           'classification':'MAIN_PLATEAU_FOUND' if selected else 'NO_STABLE_ENTRY_PLATEAU',
           'hypothesis_falsified':not bool(selected),'selected':selected,
           'bwd_state':'AUTHORIZED_AFTER_LOCK_NOT_RUN' if selected else 'NOT_RUN_GATE_STOP',
           'holdout':'UNSPENT'}
with (ROOT/'plateau_candidates.csv').open('w',newline='',encoding='utf-8') as f:
    names=['rsi_period','rsi_high','eligible','min_net','min_trades','max_eqdd_pct','distance_steps']
    w=csv.DictWriter(f,fieldnames=names); w.writeheader(); w.writerows([{k:c[k] for k in names} for c in centers])
(ROOT/'selection.json').write_text(json.dumps(selection,indent=2,sort_keys=True)+'\n',encoding='utf-8')
# Compact VISUAL_ONLY_NO_AUTHORITY heatmap-like SVG using text and neutral fills.
W,H=760,430; x0,y0=145,70; cw,ch=115,70
parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
       '<style>text{font-family:Arial,sans-serif;font-size:14px}.t{font-size:18px;font-weight:bold}.s{font-size:12px}.pos{fill:#eeeeee}.neg{fill:#cccccc}.sel{stroke:#000;stroke-width:4}.cell{stroke:#666;stroke-width:1}</style>',
       '<text x="20" y="28" class="t">B16-H05 GBPUSD/H4 SELL MAIN — RSI entry surface</text>',
       '<text x="20" y="48" class="s">Net profit per cell; VISUAL_ONLY_NO_AUTHORITY; selection governed by preregistered 5-cell cross rule.</text>']
for j,h in enumerate(HIGHS): parts.append(f'<text x="{x0+j*cw+35}" y="{y0-15}">High {h}</text>')
for i,p in enumerate(PERIODS):
    parts.append(f'<text x="20" y="{y0+i*ch+38}">Period {p}</text>')
    for j,h in enumerate(HIGHS):
        r=by[(p,h)]; cls='pos' if r['net']>0 else 'neg'; extra=' sel' if selected and (p,h)==(selected['rsi_period'],selected['rsi_high']) else ''
        x=x0+j*cw; y=y0+i*ch
        parts.append(f'<rect x="{x}" y="{y}" width="{cw-5}" height="{ch-5}" class="cell {cls}{extra}"/>')
        parts.append(f'<text x="{x+8}" y="{y+26}">net {r["net"]:+.2f}</text>')
        parts.append(f'<text x="{x+8}" y="{y+48}" class="s">tr {r["trades"]} · DD {r["eqdd_pct"]:.2f}%</text>')
parts.append('</svg>')
(ROOT/'opt01_surface.svg').write_text('\n'.join(parts)+'\n',encoding='utf-8')
print(json.dumps(selection,indent=2,sort_keys=True))