import csv, importlib.util, json
from pathlib import Path

ROOT=Path(r'D:\EA_LAB_CONTROL\worktrees\b16-gbp-sell-tfport01-20260830')
RUN=ROOT/'factory/runs/b16_step5_20260830/gbp_sell_tfport01'
PARSER=ROOT/'factory/runs/bt4_20260830/b13_bb_port01/build_r2_bundle.py'
spec=importlib.util.spec_from_file_location('r2',PARSER); r2=importlib.util.module_from_spec(spec); spec.loader.exec_module(r2)

rows=[]; yearly=[]
for context in ('GBP_H1','GBP_M15'):
    for window in ('MAIN','BWD'):
        cell=RUN/'runtime'/context/window
        report=cell/'report.htm'
        m=r2.report_metrics(report); ds=r2.deals(report); ys=r2.yearly(ds)
        trunc=json.loads((cell/'truncation_check.json').read_text(encoding='utf-8-sig'))
        lev=json.loads((cell/'leverage_check.json').read_text(encoding='utf-8-sig'))
        eligible=(not trunc['truncated']) and bool(lev['match'])
        row={'context':context,'tf':context.split('_')[1],'window':window,'eligible':eligible,
             'pf':m['pf_num'],'trades':m['trades_num'],'net':m['net_num'],'eqdd_pct':m['eqdd_pct'],
             'report_sha256':m['report_sha256'],'truncated':trunc['truncated'],'leverage_match':lev['match']}
        rows.append(row)
        for year,v in ys.items(): yearly.append({'context':context,'window':window,'year':int(year),**v})

def dual_positive(context):
    c=[r for r in rows if r['context']==context]
    return len(c)==2 and all(r['eligible'] and r['net']>0 for r in c)

if not all(r['eligible'] for r in rows): classification='UNKNOWN_MECHANICAL'
elif dual_positive('GBP_H1') and dual_positive('GBP_M15'): classification='PORTABLE_MULTI_TF'
elif dual_positive('GBP_H1') or dual_positive('GBP_M15'): classification='PORTABLE_ONE_ADJACENT_TF'
else: classification='H4_LOCAL'
summary={'schema':'ea-lab-b16-step5-evidence/1','hypothesis_id':'HYP-B16-GBP-SELL-TFPORT-01',
         'prereg_head':'97c1210010a2174486842680632bee25b2b4105a','classification':classification,
         'hypothesis_falsified':classification=='H4_LOCAL','cells':rows,'holdout':'UNSPENT','optimization':'NONE'}
(RUN/'evidence_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
with (RUN/'year_split.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=['context','window','year','trades','pf','net','balance_dd_pct'])
    w.writeheader(); w.writerows(yearly)
with (RUN/'cell_summary.csv').open('w',newline='',encoding='utf-8') as f:
    fields=['context','tf','window','eligible','pf','trades','net','eqdd_pct','report_sha256','truncated','leverage_match']
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)
print(json.dumps({'classification':classification,'cells':rows,'years':yearly},sort_keys=True))