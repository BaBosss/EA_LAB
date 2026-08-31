from pathlib import Path
import gzip, json, importlib.util, statistics, tempfile, math, csv
ROOT=Path(__file__).resolve().parents[4]
SRC=ROOT/'factory/runs/b16_characterization_20260830'
OUT=Path(__file__).resolve().parent
PARSER=ROOT/'scripts/research/b16_h03/parse_h02_reports.py'
spec=importlib.util.spec_from_file_location('b16p',PARSER); p=importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
variants={'MATCHED_OUTPUT_CONTROL':'DEEP_SPACING_EQUAL','SINGLETP_OFF':'SINGLETP_OFF','BASKETTP_OFF':'BASKETTP_OFF'}
parent=json.loads((SRC/'aggregate/parent_contexts.json').read_text())['USDJPY_H1']
rows=[]; years=[]; detail={}

def pct(vals,q):
    if not vals: return None
    vals=sorted(vals); pos=(len(vals)-1)*q; lo=math.floor(pos); hi=math.ceil(pos)
    return vals[lo] if lo==hi else vals[lo]+(vals[hi]-vals[lo])*(pos-lo)

for label,folder in variants.items():
  detail[label]={}
  for window in ('MAIN','BWD'):
    cell=SRC/'evidence'/folder/'USDJPY_H1'/window
    raw=gzip.decompress((cell/'report.htm.gz').read_bytes())
    with tempfile.NamedTemporaryFile(suffix='.htm',delete=False) as f:
      f.write(raw); tmp=Path(f.name)
    try: a=p.analyze(tmp,cell/'tester.ini')
    finally: tmp.unlink(missing_ok=True)
    cycles=a['cycles']; durs=[c['duration_seconds']/86400 for c in cycles]
    gps=sorted([c['gross_profit'] for c in cycles if c['gross_profit']>0],reverse=True)
    gp=sum(gps)
    top1=(gps[0]/gp if gp and gps else None); top3=(sum(gps[:3])/gp if gp else None)
    rv=a['identity']['report']
    row={'variant':label,'source_variant':folder,'window':window,'net':rv['net_profit'],'pf':(None if rv['gross_loss']==0 else rv['profit_factor']),'pf_mt5_field':rv['profit_factor'],'pf_state':('UNDEFINED_NO_GROSS_LOSS' if rv['gross_loss']==0 else 'FINITE'),'gross_profit':rv['gross_profit'],'gross_loss':rv['gross_loss'],'trades':rv['total_trades'],'eqdd':rv['equity_drawdown_relative'],'cycles':len(cycles),'active_time_share':a['exposure']['active_time_share_full_window'],'max_depth':a['exposure']['max_basket_depth'],'duration_mean_days':statistics.mean(durs) if durs else None,'duration_p50_days':pct(durs,.5),'duration_p90_days':pct(durs,.9),'duration_max_days':max(durs) if durs else None,'top1_gp_share':top1,'top3_gp_share':top3}
    rows.append(row); detail[label][window]={'row':row,'reconciliation':a['reconciliation']}
    for b in a['bins']:
      if b['bin'].isdigit(): years.append({'variant':label,'window':window,'year':int(b['bin']),'trades':b['closed_ticket_count'],'cycles':b['cycle_count'],'net':b['net_profit'],'active_time_share':b['active_time_share_full_window']})

with (OUT/'diagnostic_summary.csv').open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
with (OUT/'year_participation.csv').open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(years[0])); w.writeheader(); w.writerows(years)
result={'schema':'ea-lab-b16-usdjpy-exitdiag/1','parent_exact_aggregate':parent,'parent_raw_available':False,'behavior_control':'DEEP_SPACING_EQUAL','behavior_control_scope':'matched headline output only; not asserted byte-identical to parent raw','rows':rows,'years':years,'holdout':'UNSPENT','mt5_rerun':False,'optimization':'NONE'}
(OUT/'diagnostic.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))

