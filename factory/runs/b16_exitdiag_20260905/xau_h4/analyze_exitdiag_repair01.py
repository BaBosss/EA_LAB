from pathlib import Path
import gzip, json, importlib.util, tempfile, hashlib, csv
ROOT=Path(r'D:\EA_LAB_CONTROL\worktrees\ct-msnext-converge-20260905')
SRC=ROOT/'factory/runs/b16_characterization_20260830'
OUT=ROOT/'factory/runs/b16_exitdiag_20260905/xau_h4'
PARENT_PARSED=ROOT/'_mt5_auto/b16_h03/B16_H03_PARSED.json'
PARENT_PARSED_SHA='3639c9abcc8c299cf11ce1eb310ed9e721f43831870e213baafeb2e59f6a0fb6'
PARENT_REPORT_SHA={'MAIN':'aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e','BWD':'df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3'}
EXPECTED_YEARS={'MAIN':{2023,2024,2025},'BWD':{2020,2021,2022}}
CHILD_SHA={('SINGLETP_OFF','MAIN'):'6d21c76cf14303a137ccb2054e0204174e94b13a8ac0497591369db3a693fd0e',('SINGLETP_OFF','BWD'):'0687487caed64405460479d9aab64cf542ef84ede4ef4202c1039586e5875002',('BASKETTP_OFF','MAIN'):'d30337e734dfe9c5d9a42582dc533deceaf032b25aec2f9f64a158d5e2e3e063'}
PARSER=ROOT/'scripts/research/b16_h03/parse_h02_reports.py'
spec=importlib.util.spec_from_file_location('b16p',PARSER); p=importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def positive_gp_share(cycles):
    vals=[float(c['gross_profit']) for c in cycles if float(c.get('gross_profit',0))>0]
    return max(vals)/sum(vals) if vals and sum(vals)>0 else None
def parent_control(obj,window,expected):
    d=obj[window.lower()]
    if d['input']['report_sha256']!=PARENT_REPORT_SHA[window]: raise RuntimeError(f'parent report SHA mismatch {window}')
    r=d['identity']['report']
    if round(float(r['net_profit']),2)!=round(float(expected['net']),2): raise RuntimeError(f'parent net mismatch {window}')
    if round(float(r['profit_factor']),2)!=round(float(expected['pf']),2): raise RuntimeError(f'parent PF mismatch {window}')
    if int(r['total_trades'])!=int(expected['trades']): raise RuntimeError(f'parent trades mismatch {window}')
    dd=float(str(r['equity_drawdown_relative']).split('%')[0])
    if round(dd,2)!=round(float(expected['dd']),2): raise RuntimeError(f'parent DD mismatch {window}')
    if not all(bool(v) for v in d['reconciliation'].values() if isinstance(v,bool)): raise RuntimeError(f'parent reconciliation false {window}')
    bins=[b for b in d['bins'] if str(b['bin']).isdigit()]
    if {int(b['bin']) for b in bins}!=EXPECTED_YEARS[window]: raise RuntimeError(f'parent year bins mismatch {window}')
    cycles=d['cycles']; top1=positive_gp_share(cycles)
    if top1 is None: raise RuntimeError(f'parent top1 unavailable {window}')
    return {'variant':'ACCEPTED_PARENT','window':window,'report_sha256':PARENT_REPORT_SHA[window],'net':r['net_profit'],'pf':r['profit_factor'],'trades':r['total_trades'],'eqdd':dd,'cycles':len(cycles),'active_time_share':d['exposure']['active_time_share_full_window'],'duration_max_days':max(float(c['duration_seconds']) for c in cycles)/86400,'top1_gp_share':top1,'zero_closed_years':sum(1 for b in bins if int(b['closed_ticket_count'])==0)}, bins

def analyze_child(folder,window):
    cell=SRC/'evidence'/folder/'XAU_H4'/window; report=cell/'report.htm.gz'; ini=cell/'tester.ini'
    raw=gzip.decompress(report.read_bytes()); report_sha=hashlib.sha256(raw).hexdigest()
    if report_sha!=CHILD_SHA[(folder,window)]: raise RuntimeError(f'child report SHA mismatch {folder}/{window}')
    with tempfile.NamedTemporaryFile(suffix='.htm',delete=False) as f: f.write(raw); tmp=Path(f.name)
    try: a=p.analyze(tmp,ini)
    finally: tmp.unlink(missing_ok=True)
    bins=[b for b in a['bins'] if str(b['bin']).isdigit()]
    if {int(b['bin']) for b in bins}!=EXPECTED_YEARS[window]: raise RuntimeError(f'child year bins mismatch {folder}/{window}')
    cycles=a['cycles']; top1=positive_gp_share(cycles)
    if top1 is None: raise RuntimeError(f'child top1 unavailable {folder}/{window}')
    r=a['identity']['report']
    row={'variant':folder,'window':window,'report_sha256':report_sha,'net':r['net_profit'],'pf':None if r['gross_loss']==0 else r['profit_factor'],'pf_mt5_field':r['profit_factor'],'pf_state':'UNDEFINED_NO_GROSS_LOSS' if r['gross_loss']==0 else 'FINITE','trades':r['total_trades'],'eqdd':r['equity_drawdown_relative'],'cycles':len(cycles),'active_time_share':a['exposure']['active_time_share_full_window'],'duration_max_days':max(float(c['duration_seconds']) for c in cycles)/86400,'top1_gp_share':top1,'zero_closed_years':sum(1 for b in bins if int(b['closed_ticket_count'])==0)}
    yrs=[{'variant':folder,'window':window,'year':int(b['bin']),'trades':int(b['closed_ticket_count']),'cycles':int(b['cycle_count']),'net':float(b['net_profit']),'active_time_share':float(b['active_time_share_full_window'])} for b in bins]
    if not all(bool(v) for v in a['reconciliation'].values() if isinstance(v,bool)): raise RuntimeError(f'child reconciliation false {folder}/{window}')
    return row,yrs

if sha(PARENT_PARSED)!=PARENT_PARSED_SHA: raise RuntimeError('parent parsed package SHA mismatch')
parent_agg=json.loads((SRC/'aggregate/parent_contexts.json').read_text(encoding='utf-8'))['XAU_H4']
parent_obj=json.loads(PARENT_PARSED.read_text(encoding='utf-8-sig'))
controls={}; parent_rows=[]; parent_years=[]
for w in ('MAIN','BWD'):
    row,bins=parent_control(parent_obj,w,parent_agg[w]); controls[w]=row; parent_rows.append(row)
    parent_years.extend([{'variant':'ACCEPTED_PARENT','window':w,'year':int(b['bin']),'trades':int(b['closed_ticket_count']),'cycles':int(b['cycle_count']),'net':float(b['net_profit']),'active_time_share':float(b['active_time_share_full_window'])} for b in bins])
cage=json.loads((SRC/'aggregate/cage_kill_evidence.json').read_text(encoding='utf-8'))
cage_key='B16CHAR_BASKETTP_OFF_XAU_H4_BWD_M1'
if cage_key not in cage or round(float(cage[cage_key]['dd_pct']),2)!=25.00: raise RuntimeError('frozen BASKETTP_OFF/BWD cage mismatch')
eligible=[('SINGLETP_OFF','MAIN'),('SINGLETP_OFF','BWD'),('BASKETTP_OFF','MAIN')]
rows=[]; years=[]; classifications=[]
for folder,w in eligible:
    row,yrs=analyze_child(folder,w); rows.append(row); years.extend(yrs); ctl=controls[w]
    dims={'max_cycle_holding_duration_higher':row['duration_max_days']>ctl['duration_max_days'],'active_time_share_higher':row['active_time_share']>ctl['active_time_share'],'top1_positive_cycle_gp_share_higher':row['top1_gp_share']>ctl['top1_gp_share'],'zero_closed_year_count_higher':row['zero_closed_years']>ctl['zero_closed_years']}
    score=sum(1 for v in dims.values() if v); classifications.append({'variant':folder,'window':w,'dimensions':dims,'higher_count':score,'classification':'CONCENTRATION_SHIFT' if score>=3 else 'NO_CONCENTRATION_SHIFT'})
shift_count=sum(1 for x in classifications if x['classification']=='CONCENTRATION_SHIFT')
if shift_count==3: overall='HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED'
elif shift_count==0: overall='HYPOTHESIS_FALSIFIED / NO_CONCENTRATION_REPLICATION'
else: overall='MIXED_CONCENTRATION_EVIDENCE'
result={'schema':'ea-lab-b16-xau-h4-exitdiag-repair01/1','repair01_preregistration_commit':'f7421ea425d9f15dfa8561045fa88b136313ba58','parent_control_source':'_mt5_auto/b16_h03/B16_H03_PARSED.json','parent_control_sha256':PARENT_PARSED_SHA,'parent_controls':controls,'rows':rows,'years':years,'eligible_classification':classifications,'eligible_shift_count':shift_count,'basket_tp_off_bwd':{'eligibility':'MECHANICALLY_INELIGIBLE_HARD_CAGE','evidence':cage[cage_key]},'overall':overall,'holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False,'new_strategy_test_runs':0}
(OUT/'repair01_diagnostic.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf-8')
with (OUT/'repair01_diagnostic_summary.csv').open('w',newline='',encoding='utf-8') as f:
    all_rows=parent_rows+rows; w=csv.DictWriter(f,fieldnames=list(all_rows[0].keys())); w.writeheader(); w.writerows(all_rows)
with (OUT/'repair01_year_participation.csv').open('w',newline='',encoding='utf-8') as f:
    all_years=parent_years+years; w=csv.DictWriter(f,fieldnames=list(all_years[0].keys())); w.writeheader(); w.writerows(all_years)
accept={'schema':'ea-lab-b16-xau-h4-exitdiag-repair01-acceptance/1','overall':'PASS_READ_ONLY','decision_classification':overall,'eligible_shift_count':shift_count,'eligible_windows':3,'parent_control':'EXACT_ACCEPTED_H03_PARSED_PARENT','parent_control_sha256':PARENT_PARSED_SHA,'basket_tp_off_bwd':'MECHANICALLY_INELIGIBLE_HARD_CAGE','holdout':'UNSPENT','optimization':'NONE','mt5_rerun':False,'new_strategy_test_runs':0,'authority':'RESEARCH_ONLY_NO_EXIT_CHANGE_NO_OPTIMIZATION_NO_HOLDOUT_NO_CANDIDATE_NO_RUNTIME'}
(OUT/'repair01_acceptance.json').write_text(json.dumps(accept,indent=2,sort_keys=True)+'\n',encoding='utf-8')
recon=['B16 XAUUSD/H4 EXIT CONCENTRATION REPAIR01 SOURCE RECONCILIATION','repair01_preregistration_commit=f7421ea425d9f15dfa8561045fa88b136313ba58','parent_control=_mt5_auto/b16_h03/B16_H03_PARSED.json','parent_control_sha256='+PARENT_PARSED_SHA,'parent_main_report_sha='+PARENT_REPORT_SHA['MAIN'],'parent_bwd_report_sha='+PARENT_REPORT_SHA['BWD'],'parent_reconciliation=PASS','eligible_children=SINGLETP_OFF_MAIN,SINGLETP_OFF_BWD,BASKETTP_OFF_MAIN','BASKETTP_OFF_BWD=mechanically_ineligible_hard_cage_not_used_for_verdict','MT5_RERUN=false','HOLDOUT=UNSPENT','OPTIMIZATION=NONE','RESULT='+overall]
(OUT/'repair01_source_reconciliation.txt').write_text('\n'.join(recon)+'\n',encoding='utf-8')
print(json.dumps(accept,indent=2,sort_keys=True))
