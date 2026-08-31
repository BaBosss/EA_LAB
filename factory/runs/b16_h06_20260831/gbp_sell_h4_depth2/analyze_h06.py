import csv, gzip, hashlib, importlib.util, json, re, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
RUN=Path(__file__).resolve().parent
PARSER=ROOT/'scripts/research/b16_h03/parse_h02_reports.py'
spec=importlib.util.spec_from_file_location('b16p',PARSER); pmod=importlib.util.module_from_spec(spec); spec.loader.exec_module(pmod)
results={}; rows=[]; years=[]
for window in ('MAIN','BWD'):
    cell=RUN/'runtime'/'GBP_H4'/window; gz=cell/'report.htm.gz'; ini=cell/'tester.ini'
    with tempfile.TemporaryDirectory() as td:
        report=Path(td)/'report.htm'; report.write_bytes(gzip.decompress(gz.read_bytes())); a=pmod.analyze(report,ini)
    a['input']['report_path']=str(gz.relative_to(RUN)); a['input']['report_storage']='DETERMINISTIC_GZIP'; a['input']['report_gzip_sha256']=hashlib.sha256(gz.read_bytes()).hexdigest()
    a['exposure']['configured_orders_per_side_cap']=2; a['exposure']['cap_contact']=a['exposure']['max_basket_depth']==2
    results[window.lower()]=a; rv=a['identity']['report']
    m=re.match(r'([-0-9.]+)%',rv['equity_drawdown_relative']); eqdd=float(m.group(1)) if m else None
    pf_state='UNDEFINED_NO_GROSS_LOSS' if rv['gross_loss']==0 else 'FINITE'; pf_value=None if rv['gross_loss']==0 else rv['profit_factor']
    trunc=json.loads((cell/'truncation_check.json').read_text(encoding='utf-8-sig')); lev=json.loads((cell/'leverage_check.json').read_text(encoding='utf-8-sig'))
    rows.append({'window':window,'eligible':(not trunc['truncated']) and bool(lev['match']),'pf':pf_value,'pf_mt5_field':rv['profit_factor'],'pf_state':pf_state,'trades':rv['total_trades'],'net':rv['net_profit'],'eqdd_pct':eqdd,'cycles':len(a['cycles']),'max_depth':a['exposure']['max_basket_depth'],'max_lots':a['exposure']['max_aggregate_lots'],'active_time_share':a['exposure']['active_time_share_full_window'],'multi_entry_gp_share':a['concentration']['multi_entry_positive_gross_profit_share'],'gross_profit':rv['gross_profit'],'gross_loss':rv['gross_loss'],'report_sha256':a['input']['report_sha256'],'report_gzip_sha256':a['input']['report_gzip_sha256'],'truncated':trunc['truncated'],'leverage_match':lev['match']})
    for b in a['bins']:
        if b['bin'].isdigit(): years.append({'window':window,'year':int(b['bin']),'trades':b['closed_ticket_count'],'pf':b['profit_factor'],'net':b['net_profit'],'cycles':b['cycle_count'],'active_time_share':b['active_time_share_full_window']})
classification='UNKNOWN_MECHANICAL' if not all(r['eligible'] for r in rows) else ('DEPTH2_DUAL_WINDOW_POSITIVE' if all(r['net']>0 for r in rows) else 'DEPTH_GT2_REQUIRED_FOR_DUAL_WINDOW_POSITIVITY')
summary={'schema':'ea-lab-b16-h06-depth2-evidence/1','hypothesis_id':'HYP-B16-GBP-SELL-H4-DEPTH2-01','prereg_head':'9f6471aaf8c759130a29d9bc215a258dbff51a6f','classification':classification,'hypothesis_falsified':classification=='DEPTH_GT2_REQUIRED_FOR_DUAL_WINDOW_POSITIVITY','cells':rows,'holdout':'UNSPENT','optimization':'NONE'}
(RUN/'cycle_exposure.json').write_text(json.dumps(results,indent=2,sort_keys=True)+'\n',encoding='utf-8'); (RUN/'evidence_summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n',encoding='utf-8')
with (RUN/'cell_summary.csv').open('w',newline='',encoding='utf-8') as f: w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
with (RUN/'year_split.csv').open('w',newline='',encoding='utf-8') as f: w=csv.DictWriter(f,fieldnames=list(years[0])); w.writeheader(); w.writerows(years)
print(json.dumps({'classification':classification,'cells':rows,'years':years},indent=2))