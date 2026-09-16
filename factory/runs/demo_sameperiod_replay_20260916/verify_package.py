"""Read-only, package-specific evidence/claim checks; never starts a tester."""
from pathlib import Path
import csv, hashlib, io, json, copy
from decimal import Decimal as D
P=Path(__file__).resolve().parent
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=load(P/'replay_comparison.json');m=load(P/'source_manifest.json')
def validate_claims(v):
 assert v['demo_row_reconciliation']['original_row_identity_proven'] is False
 assert v['demo_row_reconciliation']['append_only_proven'] is False
 assert v['acceptance']['exact_parity_certified'] is False
 assert v['acceptance']['historical_postcheck_certified'] is False
 assert v['timing_method']['independently_qualified_clock'] is False
 assert v['timing_method']['classification']=='EXPLORATORY_POST_OUTCOME_ALIGNMENT'
 for c in v['cells']:
  ok=c['cell'] in ['DSPR-C01','DSPR-C02','DSPR-C05']
  assert c['full_window_eligible_under_truncation_gate']==ok
  if not ok:assert c['classification']=='BLOCKED_TRUNCATION_UNRESOLVED' and c['comparison_use']=='DESCRIPTIVE_INELIGIBLE_FOR_FULL_WINDOW_CONCLUSION'
  assert c['historical_postcheck_status']=='NOT_DURABLY_PRESERVED'
 assert v['ichi_xau_basket']['full_window_eligible'] is False
validate_claims(a);checks=1
for x in m['preserved_evidence']:
 p=P/x['path'];assert p.stat().st_size==x['bytes'] and sha(p)==x['sha256'];checks+=1
for x in m['method_sources']:assert sha(Path(x['path']))==x['sha256'];checks+=1
for x in m['execution_receipt']['cells']:
 p=Path(x['report']);assert sha(p).upper()==x['report_sha256'];assert sha(Path(x['run_log'])).upper()==x['run_log_sha256']
 t=p.with_suffix('.truncation_check.json');assert sha(t).upper()==x['truncation_sha256'];j=load(t)
 assert j['check_status']==x['truncation'] and j['truncated'] is x['truncated'];checks+=3
rows=list(csv.DictReader(io.StringIO((P/m['demo_subset_path']).read_text(encoding='utf-8-sig'))))
assert len(rows)==120 and len({r['ticket'] for r in rows})==120
assert sha(P/m['demo_subset_path']).upper()==m['demo_subset_sha256'];checks+=2
for c in a['cells']:
 xs=[r for r in rows if r['magic']==c['magic'] and r['entry'] in ['1','3']]
 vs=[sum((D(r[k]) for k in ['profit','swap','commission']),D(0)) for r in xs]
 gp=sum((v for v in vs if v>0),D(0));gl=-sum((v for v in vs if v<0),D(0))
 assert len(xs)==c['demo_exit_count'] and sum(vs)==D(str(c['demo_net']))
 assert abs(gp/gl-D(str(c['demo_pf'])))<D('0.000001');checks+=2
pre=load(P/m['preflight']['path']);assert len(pre)==5 and len({p['alias'] for p in pre})==5
assert all(x['preexisting_cache_matches']==0 and x['source_sha256']==x['destination_sha256'] for x in pre);checks+=1
csvrows=list(csv.DictReader((P/'replay_comparison.csv').open(encoding='utf-8-sig',newline='')))
for x,c in zip(csvrows,a['cells']):
 assert x['cell']==c['cell'] and x['classification']==c['classification'] and x['comparison_use']==c['comparison_use'];checks+=1
negative=0
for key in ['original_row_identity_proven','append_only_proven']:
 b=copy.deepcopy(a);b['demo_row_reconciliation'][key]=True
 try:validate_claims(b)
 except AssertionError:negative+=1
 else:raise AssertionError('Unsafe provenance accepted')
for idx in [2,3]:
 b=copy.deepcopy(a);b['cells'][idx]['full_window_eligible_under_truncation_gate']=True
 try:validate_claims(b)
 except AssertionError:negative+=1
 else:raise AssertionError('UNKNOWN upgraded to PASS')
print(json.dumps({'status':'PASS','positive_checks':checks,'negative_checks':negative,'new_mt5_runs':0,'scope':'package evidence and claim-boundary checks, not strategy acceptance'}))
