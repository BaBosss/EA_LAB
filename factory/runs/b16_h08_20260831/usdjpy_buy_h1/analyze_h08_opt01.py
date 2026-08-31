import csv, hashlib, json, math, pathlib, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parent
XML=ROOT/'optimizer.xml'
NS='{urn:schemas-microsoft-com:office:spreadsheet}'
PERIODS=[7,14,21,28]
LOWS=[20,25,30,35,40]
BASE=(14,30)
PARTICIPATION_FLOOR=100

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

def fnum(v):
    if v in (None,''): return None
    s=str(v).strip().upper()
    if 'INF' in s: return None
    return float(v)
rows=list(ET.parse(XML).getroot().iter(NS+'Row'))
raw=[row_values(r) for r in rows]
header=raw[0]; records=[]
for values in raw[1:]:
    values=values+[None]*(len(header)-len(values))
    d=dict(zip(header,values))
    records.append({
        'pass':int(d['Pass']), 'result':fnum(d['Result']), 'net':fnum(d['Profit']),
        'expected_payoff':fnum(d['Expected Payoff']), 'pf':fnum(d['Profit Factor']),
        'recovery_factor':fnum(d['Recovery Factor']), 'sharpe':fnum(d['Sharpe Ratio']),
        'custom':fnum(d['Custom']), 'eqdd_pct':fnum(d['Equity DD %']), 'trades':int(d['Trades']),
        'rsi_period':int(float(d['_16_RsiPeriod'])), 'rsi_low':int(float(d['_16_RsiLow']))})
expected={(p,l) for p in PERIODS for l in LOWS}
seen={(r['rsi_period'],r['rsi_low']) for r in records}
missing=sorted(expected-seen); extra=sorted(seen-expected)
if extra or len(seen)!=len(records):
    raise SystemExit(f'grid identity mismatch rows={len(records)} extra={extra} duplicates={len(records)-len(seen)}')
by={(r['rsi_period'],r['rsi_low']):r for r in records}
base=by.get(BASE)
baseline_ok=bool(base and abs(base['net']-252.53)<=0.05 and base['trades']==275 and abs(base['pf']-1.53)<=0.01 and abs(base['eqdd_pct']-3.85)<=0.03)
fields=['pass','result','net','expected_payoff','pf','recovery_factor','sharpe','custom','eqdd_pct','trades','rsi_period','rsi_low']
with (ROOT/'optimizer_surface.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(sorted(records,key=lambda r:(r['rsi_period'],r['rsi_low'])))
(ROOT/'missing_cells.json').write_text(json.dumps({'missing':[{'rsi_period':p,'rsi_low':l} for p,l in missing]},indent=2)+'\n',encoding='utf-8')
centers=[]
if not missing:
    for p in PERIODS[1:-1]:
        for low in LOWS[1:-1]:
            pts=[(p,low),(p-7,low),(p+7,low),(p,low-5),(p,low+5)]
            cells=[by[x] for x in pts]
            eligible=all(c['net']>0 and c['trades']>=PARTICIPATION_FLOOR for c in cells)
            centers.append({'rsi_period':p,'rsi_low':low,'eligible':eligible,
                'min_net':min(c['net'] for c in cells),'min_trades':min(c['trades'] for c in cells),
                'max_eqdd_pct':max(c['eqdd_pct'] for c in cells),
                'distance_steps':abs(p-BASE[0])/7+abs(low-BASE[1])/5,
                'cross':[{**{'rsi_period':x[0],'rsi_low':x[1]},**{k:by[x][k] for k in ('net','pf','trades','eqdd_pct')}} for x in pts]})
eligible=[c for c in centers if c['eligible']]
selected=None
if eligible:
    selected=sorted(eligible,key=lambda c:(-c['min_net'],-c['min_trades'],c['max_eqdd_pct'],c['distance_steps'],c['rsi_period'],c['rsi_low']))[0]
with (ROOT/'plateau_candidates.csv').open('w',newline='',encoding='utf-8') as f:
    names=['rsi_period','rsi_low','eligible','min_net','min_trades','max_eqdd_pct','distance_steps']
    w=csv.DictWriter(f,fieldnames=names); w.writeheader(); w.writerows([{k:c[k] for k in names} for c in centers])
classification='INCOMPLETE_LATTICE' if missing else ('MAIN_PLATEAU_FOUND' if selected else 'NO_PARTICIPATION_QUALIFIED_PLATEAU')
selection={'schema':'ea-lab-b16-h08-opt01-selection/1','hypothesis_revision':'B16-H08-r1',
 'xml_sha256':hashlib.sha256(XML.read_bytes()).hexdigest(),'grid_complete':not bool(missing),'grid_rows':len(records),
 'missing_cells':[{'rsi_period':p,'rsi_low':l} for p,l in missing],'baseline_reproduced':baseline_ok,
 'baseline_observed':base,'participation_floor':PARTICIPATION_FLOOR,'classification':classification,
 'hypothesis_falsified':(not missing and not bool(selected)),'selected':selected,
 'bwd_state':'AUTHORIZED_AFTER_LOCK_NOT_RUN' if selected else ('NOT_RUN_INCOMPLETE_LATTICE' if missing else 'NOT_RUN_GATE_STOP'),
 'holdout':'UNSPENT'}
(ROOT/'selection.json').write_text(json.dumps(selection,indent=2,sort_keys=True,allow_nan=False)+'\n',encoding='utf-8')
print(json.dumps(selection,indent=2,sort_keys=True,allow_nan=False))
if not baseline_ok: raise SystemExit(4)
if missing: raise SystemExit(3)
