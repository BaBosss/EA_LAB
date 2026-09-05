from pathlib import Path
import gzip, json, importlib.util, statistics, tempfile, math, csv, hashlib
ROOT = Path(__file__).resolve().parents[4]
SRC = ROOT / 'factory/runs/b16_characterization_20260830'
OUT = Path(__file__).resolve().parent
PARSER = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'
spec = importlib.util.spec_from_file_location('b16p', PARSER)
p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
parent = json.loads((SRC/'aggregate/parent_contexts.json').read_text(encoding='utf-8'))['XAU_H4']
expected_hashes = {
 ('SINGLETP_OFF','MAIN'):'6d21c76cf14303a137ccb2054e0204174e94b13a8ac0497591369db3a693fd0e',
 ('SINGLETP_OFF','BWD'):'0687487caed64405460479d9aab64cf542ef84ede4ef4202c1039586e5875002',
 ('BASKETTP_OFF','MAIN'):'d30337e734dfe9c5d9a42582dc533deceaf032b25aec2f9f64a158d5e2e3e063',
}
expected_years = {'MAIN':{2023,2024,2025}, 'BWD':{2020,2021,2022}}
def pct(vals, q):
    if not vals: return None
    vals=sorted(vals); pos=(len(vals)-1)*q; lo=math.floor(pos); hi=math.ceil(pos)
    return vals[lo] if lo==hi else vals[lo]+(vals[hi]-vals[lo])*(pos-lo)
def analyze_cell(folder, window):
    cell = SRC/'evidence'/folder/'XAU_H4'/window
    report = cell/'report.htm.gz'; ini = cell/'tester.ini'
    raw = gzip.decompress(report.read_bytes())
    report_sha = hashlib.sha256(raw).hexdigest()
    with tempfile.NamedTemporaryFile(suffix='.htm', delete=False) as f:
        f.write(raw); tmp = Path(f.name)
    try:
        a = p.analyze(tmp, ini)
    finally:
        tmp.unlink(missing_ok=True)
    cycles=a['cycles']; durs=[c['duration_seconds']/86400 for c in cycles]
    gps=sorted([c['gross_profit'] for c in cycles if c['gross_profit']>0], reverse=True)
    gp=sum(gps); rv=a['identity']['report']
    ys=[b for b in a['bins'] if str(b['bin']).isdigit()]
    seen={int(b['bin']) for b in ys}
    if seen != expected_years[window]:
        raise RuntimeError(f'year bins mismatch {folder}/{window}: {seen}')
    row={'variant':folder,'window':window,'report_sha256':report_sha,
         'net':rv['net_profit'],'pf':None if rv['gross_loss']==0 else rv['profit_factor'],
         'pf_mt5_field':rv['profit_factor'],'pf_state':'UNDEFINED_NO_GROSS_LOSS' if rv['gross_loss']==0 else 'FINITE',
         'trades':rv['total_trades'],'eqdd':rv['equity_drawdown_relative'],'cycles':len(cycles),
         'active_time_share':a['exposure']['active_time_share_full_window'],'max_depth':a['exposure']['max_basket_depth'],
         'duration_max_days':max(durs) if durs else None,'duration_p50_days':pct(durs,.5),'duration_p90_days':pct(durs,.9),
         'top1_gp_share':gps[0]/gp if gp and gps else None,'top3_gp_share':sum(gps[:3])/gp if gp else None,
         'zero_closed_years':sum(1 for b in ys if b['closed_ticket_count']==0)}
    year_rows=[{'variant':folder,'window':window,'year':int(b['bin']),'trades':b['closed_ticket_count'],
                'cycles':b['cycle_count'],'net':b['net_profit'],'active_time_share':b['active_time_share_full_window']} for b in ys]
    return row, year_rows, a['reconciliation']
controls={}; all_rows=[]; all_years=[]; reconciliations={}
for window in ('MAIN','BWD'):
    row, yrs, rec = analyze_cell('DEEP_SPACING_EQUAL', window)
    controls[window]=row; all_rows.append(row); all_years.extend(yrs); reconciliations[f'CONTROL_{window}']=rec
    ref=parent[window]
    ok=(round(float(row['net']),2)==round(float(ref['net']),2)
        and round(float(row['pf_mt5_field']),2)==round(float(ref['pf']),2)
        and int(row['trades'])==int(ref['trades'])
        and round(float(row['eqdd']),2)==round(float(ref['dd']),2))
    if not ok:
        blocked={'schema':'ea-lab-b16-xau-h4-exitdiag-acceptance/1','overall':'BLOCKED_CONTROL_MISMATCH',
                 'window':window,'observed':row,'expected_parent':ref,'holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False}
        (OUT/'diagnostic_acceptance.json').write_text(json.dumps(blocked,indent=2,sort_keys=True)+'\n',encoding='utf-8')
        raise SystemExit(2)

cage=json.loads((SRC/'aggregate/cage_kill_evidence.json').read_text(encoding='utf-8'))
cage_key='B16CHAR_BASKETTP_OFF_XAU_H4_BWD_M1'
if cage_key not in cage or round(float(cage[cage_key]['dd_pct']),2)!=25.00:
    raise RuntimeError('frozen BasketTP-off BWD cage evidence mismatch')

eligible=[('SINGLETP_OFF','MAIN'),('SINGLETP_OFF','BWD'),('BASKETTP_OFF','MAIN')]
results=[]
for folder,window in eligible:
    row, yrs, rec = analyze_cell(folder, window)
    if row['report_sha256'] != expected_hashes[(folder,window)]:
        raise RuntimeError(f'report hash mismatch {folder}/{window}')
    all_rows.append(row); all_years.extend(yrs); reconciliations[f'{folder}_{window}']=rec
    ctl=controls[window]
    required=(row['duration_max_days'],ctl['duration_max_days'],row['top1_gp_share'],ctl['top1_gp_share'])
    if any(v is None for v in required):
        blocked={'schema':'ea-lab-b16-xau-h4-exitdiag-acceptance/1','overall':'BLOCKED_METRIC_UNAVAILABLE',
                 'cell':f'{folder}/{window}','holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False}
        (OUT/'diagnostic_acceptance.json').write_text(json.dumps(blocked,indent=2,sort_keys=True)+'\n',encoding='utf-8')
        raise SystemExit(3)
    dims={
      'max_cycle_holding_duration_higher':row['duration_max_days']>ctl['duration_max_days'],
      'active_time_share_higher':row['active_time_share']>ctl['active_time_share'],
      'top1_positive_cycle_gp_share_higher':row['top1_gp_share']>ctl['top1_gp_share'],
      'zero_closed_year_count_higher':row['zero_closed_years']>ctl['zero_closed_years'],
    }
    score=sum(1 for v in dims.values() if v); shift=score>=3
    results.append({'variant':folder,'window':window,'dimensions':dims,'higher_count':score,'classification':'CONCENTRATION_SHIFT' if shift else 'NO_CONCENTRATION_SHIFT'})

shift_count=sum(1 for r in results if r['classification']=='CONCENTRATION_SHIFT')
if shift_count==3: overall='HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED'
elif shift_count==0: overall='HYPOTHESIS_FALSIFIED / NO_CONCENTRATION_REPLICATION'
else: overall='MIXED_CONCENTRATION_EVIDENCE'
result={'schema':'ea-lab-b16-xau-h4-exitdiag/1','preregistration_commit':'adada829b642f8f1691f0ca37fb88c338c8087d4',
        'parent_exact_aggregate':parent,'control':'DEEP_SPACING_EQUAL','control_reconciliation':'PASS',
        'rows':all_rows,'years':all_years,'eligible_classification':results,'eligible_shift_count':shift_count,
        'basket_tp_off_bwd':{'eligibility':'MECHANICALLY_INELIGIBLE_HARD_CAGE','evidence':cage[cage_key]},
        'overall':overall,'holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False,'new_strategy_test_runs':0}
(OUT/'diagnostic.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf-8')
with (OUT/'diagnostic_summary.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(all_rows[0].keys())); w.writeheader(); w.writerows(all_rows)
with (OUT/'year_participation.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(all_years[0].keys())); w.writeheader(); w.writerows(all_years)
accept={'schema':'ea-lab-b16-xau-h4-exitdiag-acceptance/1','overall':'PASS_READ_ONLY',
        'decision_classification':overall,'eligible_shift_count':shift_count,'eligible_windows':3,
        'control_reconciliation':'PASS','basket_tp_off_bwd':'MECHANICALLY_INELIGIBLE_HARD_CAGE',
        'holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False,'new_strategy_test_runs':0,
        'authority':'RESEARCH_ONLY_NO_EXIT_CHANGE_NO_OPTIMIZATION_NO_HOLDOUT_NO_CANDIDATE_NO_RUNTIME'}
(OUT/'diagnostic_acceptance.json').write_text(json.dumps(accept,indent=2,sort_keys=True)+'\n',encoding='utf-8')
recon=['B16 XAUUSD/H4 EXIT CONCENTRATION SOURCE RECONCILIATION',
       'preregistration_commit=adada829b642f8f1691f0ca37fb88c338c8087d4',
       'parent_raw_asserted=false','behavior_control=DEEP_SPACING_EQUAL','control_reconciliation=PASS',
       'SINGLETP_OFF_MAIN+BWD=canonical_tracked','BASKETTP_OFF_MAIN=canonical_tracked',
       'BASKETTP_OFF_BWD=mechanically_ineligible_hard_cage_not_used_for_verdict',
       'MT5_RERUN=false','HOLDOUT=UNSPENT','OPTIMIZATION=NONE','RESULT='+overall]
(OUT/'source_reconciliation.txt').write_text('\n'.join(recon)+'\n',encoding='utf-8')
artifact_names=['analyze_exitdiag.py','diagnostic.json','diagnostic_summary.csv','year_participation.csv','diagnostic_acceptance.json','source_reconciliation.txt']
lines=[]
for name in artifact_names:
    data=(OUT/name).read_bytes(); lines.append(hashlib.sha256(data).hexdigest()+'  '+str((OUT/name).relative_to(ROOT)).replace('\\','/'))
(OUT/'artifacts.sha256').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps(accept,indent=2,sort_keys=True))
print('ARTIFACTS='+str(OUT))