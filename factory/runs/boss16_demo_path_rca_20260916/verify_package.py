import argparse, copy, csv, hashlib, json
from pathlib import Path
P=Path(__file__).resolve().parent; ROOT=P.parents[2]

def loadj(n): return json.loads((P/n).read_text(encoding='utf-8'))
def rows(n):
    with (P/n).open(encoding='utf-8-sig',newline='') as f: return list(csv.DictReader(f))
def num(v): return float(str(v).replace(' ','').replace(',',''))
def close(a,b,t=1e-8): return abs(float(a)-float(b))<=t
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()

def episodes(rs,demo=True):
    out=[]; cur=None; open_n=0
    for r in rs:
        ent=r['entry'] if demo else r['Direction']
        if (demo and ent=='0') or ((not demo) and ent=='in'):
            if open_n==0: cur={'entries':0,'exits':0,'net':0.0,'max_open':0}
            open_n+=1; cur['entries']+=1; cur['max_open']=max(cur['max_open'],open_n)
        elif (demo and ent in ('1','3')) or ((not demo) and ent.startswith('out')):
            keys=('profit','swap','commission') if demo else ('Profit','Swap','Commission')
            open_n=max(0,open_n-1); cur['exits']+=1; cur['net']+=sum(num(r.get(k,'0') or 0) for k in keys)
            if open_n==0: cur['net']=round(cur['net'],2); out.append(cur); cur=None
    return out,open_n
def validate(data,extract,input_surface,demo_rows,bt_rows):
    e=[]
    if data.get('schema')!='boss16_demo_model1_path_rca/2': e.append('schema')
    if data.get('classification')!='MODEL1_INTRAMINUTE_FILL_PATH_CONFOUND_SUPPORTED_NOT_CAUSALLY_CERTIFIED': e.append('classification')
    se=input_surface['set_values']; rv=input_surface['report_values']
    if input_surface.get('mismatches'): e.append('input_mismatch_declared')
    if any(rv.get(k)!=v for k,v in se.items()): e.append('input_42_recompute')
    if rv.get('_16_BaseLotMode')!='0': e.append('base_lot_mode')
    de,do=episodes(demo_rows,True); be,bo=episodes(bt_rows,False)
    if do or len(de)!=5 or not close(sum(x['net'] for x in de),117.56): e.append('demo_episodes')
    if bo or len(be)!=1 or not close(sum(x['net'] for x in be),-318.44): e.append('bt_episodes')
    ex=extract['exness_tr14']; tm=extract['thinkmarkets_tr14']
    if len(ex)!=14 or len(tm)!=14: e.append('tr14_count')
    if any(int(x['m1_count'])<58 for x in ex+tm): e.append('selected_h1_minute_count')
    ex_atr=sum(float(x['tr']) for x in ex)/14 if len(ex)==14 else float('nan')
    tm_atr=sum(float(x['tr']) for x in tm)/14 if len(tm)==14 else float('nan')
    if not close(ex_atr,data['atr14']['exness']): e.append('ex_atr')
    if not close(tm_atr,data['atr14']['thinkmarkets']): e.append('tm_atr')
    ex_step=max(.8*ex_atr,1.5); tm_step=max(.8*tm_atr,1.5)
    p=data['path_test']; ex_trig=p['demo_l2_fill']-ex_step; tm_trig=p['model1_l2_fill']-tm_step
    if not close(ex_trig,p['demo_trigger_after_l2']): e.append('ex_trigger')
    if not close(tm_trig,p['model1_trigger_after_l2']): e.append('tm_trigger')
    if not (p['demo_l3_fill']<=ex_trig): e.append('demo_cross')
    tm_min=min(float(x['l']) for x in extract['thinkmarkets_window_rows'])
    if not close(tm_min,p['thinkmarkets_m1_min_low_same_elapsed']): e.append('tm_min_low')
    if not (tm_min>tm_trig): e.append('tm_no_cross')
    return e
def check_external(man):
    e=[]
    for x in man['external_sources']:
        p=Path(x['path'])
        if not p.exists(): e.append('missing:'+x['role']); continue
        if p.stat().st_size!=x['bytes']: e.append('size:'+x['role'])
        if sha(p)!=x['sha256']: e.append('sha:'+x['role'])
    for x in man['repo_sources']:
        if 'sha256' in x:
            p=ROOT/x['path']
            if not p.exists() or sha(p)!=x['sha256']: e.append('repo_sha:'+x['role'])
    return e

def negative_tests(data,extract,input_surface,demo_rows,bt_rows):
    passed=0
    d=copy.deepcopy(data); d['path_test']['demo_trigger_after_l2']+=1
    passed+=bool(validate(d,extract,input_surface,demo_rows,bt_rows))
    d=copy.deepcopy(data); d['classification']='BAD'
    passed+=bool(validate(d,extract,input_surface,demo_rows,bt_rows))
    x=copy.deepcopy(extract); x['exness_tr14']=x['exness_tr14'][:-1]
    passed+=bool(validate(data,x,input_surface,demo_rows,bt_rows))
    i=copy.deepcopy(input_surface); k=next(iter(i['set_values'])); i['report_values'][k]='MUTANT'
    passed+=bool(validate(data,extract,i,demo_rows,bt_rows))
    return passed

ap=argparse.ArgumentParser(); ap.add_argument('--external',action='store_true'); ap.add_argument('--receipt')
a=ap.parse_args(); data=loadj('rca.json'); extract=loadj('hcc_extract.json'); inp=loadj('input_surface.json'); man=loadj('source_manifest.json'); tick=loadj('tick_source_preflight.json')
demo_rows=rows('demo_990016.csv'); bt_rows=rows('bt_c04_deals.csv')
errs=validate(data,extract,inp,demo_rows,bt_rows)
if tick.get('classification')!='NO_QUALIFIED_HISTORICAL_EXNESS_TICK_STREAM_FROM_OBSERVED_CACHE': errs.append('tick_classification')
if tick.get('tkc_count')!=0: errs.append('tick_tkc_count')
if any(x.get('seconds_hits') or x.get('milliseconds_hits') for x in tick.get('probes',[])): errs.append('tick_probe_hits')
if a.external: errs+=check_external(man)
neg=negative_tests(data,extract,inp,demo_rows,bt_rows)
receipt={'status':'PASS' if not errs and neg==4 else 'FAIL','errors':errs,'negative_mutants_rejected':neg,'negative_mutants_total':4,
         'external_hash_check':bool(a.external),'classification':data['classification'],'no_new_mt5':True}
if a.receipt: Path(a.receipt).write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt,indent=2)); raise SystemExit(0 if receipt['status']=='PASS' else 2)
