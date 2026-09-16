import csv, hashlib, json, math, re, struct, subprocess
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
DEMO=ROOT/'factory/runs/demo_sameperiod_replay_20260916/evidence/demo_5magic_rows_through_20260914.csv'
BT=Path(r'D:\EA_LAB_CONTROL\worktrees\ct-demo-replay-exec-20260916\_mt5_auto\reports\DSPR_C04_990016_20260728_20260914.htm')
EX=Path(r'D:\Monitor\MT5 - 463666728\Bases\Exness-MT5Trial17\history\XAUUSDm\2026.hcc')
TM=Path(r'D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\Bases\ThinkMarkets-Live\history\XAUUSD\2026.hcc')
ATR_SRC=Path(r'D:\Meta 5\MQL5\Indicators\Examples\ATR.mq5')
TICK_DIR=Path(r'D:\Monitor\MT5 - 463666728\Bases\Exness-MT5Trial17\ticks\XAUUSDm')
TICKS=TICK_DIR/'ticks.dat'
SET=ROOT/'ea_template/sets/Boss16_Kangaroo_XAU_21_30.set'
KANG=ROOT/'ea_template/core/entries/Kangaroo.mqh'
DEPLOY_REF='d96df9763ac70a2a4af773b4a27d0fa48a0f7661'
FMT='<qddddqiq'; REC=struct.calcsize(FMT)
SCAN_START=int(datetime(2026,8,25,tzinfo=timezone.utc).timestamp())
SCAN_END=int(datetime(2026,9,3,tzinfo=timezone.utc).timestamp())

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def git(*args):
    r=subprocess.run(['git','-C',str(ROOT),*args],capture_output=True,text=True,check=True)
    return r.stdout.strip()
class P(HTMLParser):
    def __init__(self): super().__init__(); self.rows=[]; self.row=None; self.cell=None
    def handle_starttag(self,t,a):
        if t=='tr': self.row=[]
        elif t in ('td','th') and self.row is not None: self.cell=[]
    def handle_data(self,d):
        if self.cell is not None: self.cell.append(d)
    def handle_endtag(self,t):
        if t in ('td','th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split())); self.cell=None
        elif t=='tr' and self.row is not None: self.rows.append(self.row); self.row=None

def html_rows(path):
    b=path.read_bytes(); enc='utf-16' if b[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8'
    p=P(); p.feed(b.decode(enc,errors='replace')); return p.rows

def val(rows,label):
    for r in rows:
        for i,c in enumerate(r[:-1]):
            if c==label: return r[i+1]
    return None

def num(v): return float(str(v).replace(' ','').replace(',',''))
def dt(s): return datetime.strptime(s,'%Y.%m.%d %H:%M:%S')
def read_demo():
    with DEMO.open(encoding='utf-8-sig',newline='') as f:
        rows=[r for r in csv.DictReader(f) if r['magic']=='990016']
    assert len(rows)==24
    return rows

def read_bt():
    rows=html_rows(BT); di=next(i for i,r in enumerate(rows) if r==['Deals']); hdr=rows[di+1]
    deals=[]
    for r in rows[di+2:]:
        if len(r)>=len(hdr) and r[0][:4].isdigit():
            d=dict(zip(hdr,r[:len(hdr)]))
            if d.get('Symbol')=='XAUUSD': deals.append(d)
    assert len(deals)==20
    return rows,deals

def episodeize_demo(rows):
    out=[]; cur=None; open_n=0
    for r in rows:
        net=sum(num(r[k] or '0') for k in ('profit','swap','commission'))
        if r['entry']=='0':
            if open_n==0: cur={'start':r['time'],'entries':0,'exits':0,'net':0.0,'max_open':0}
            open_n+=1; cur['entries']+=1; cur['max_open']=max(cur['max_open'],open_n)
        elif r['entry'] in ('1','3'):
            open_n=max(0,open_n-1); cur['exits']+=1; cur['net']+=net
            if open_n==0: cur['end']=r['time']; cur['net']=round(cur['net'],2); out.append(cur); cur=None
    assert open_n==0 and len(out)==5
    return out
def episodeize_bt(rows):
    out=[]; cur=None; open_n=0
    for r in rows:
        direction=r.get('Direction',''); net=sum(num(r.get(k,'0') or '0') for k in ('Commission','Swap','Profit'))
        if direction=='in':
            if open_n==0: cur={'start':r['Time'],'entries':0,'exits':0,'net':0.0,'max_open':0}
            open_n+=1; cur['entries']+=1; cur['max_open']=max(cur['max_open'],open_n)
        elif direction.startswith('out'):
            open_n=max(0,open_n-1); cur['exits']+=1; cur['net']+=net
            if open_n==0: cur['end']=r['Time']; cur['net']=round(cur['net'],2); out.append(cur); cur=None
    assert open_n==0 and len(out)==1
    return out

def valid_record(b,off):
    if off<0 or off+REC>len(b): return None
    t,o,h,l,c,tv,sp,rv=struct.unpack_from(FMT,b,off)
    if not (SCAN_START<=t<=SCAN_END and t%60==0): return None
    if not all(math.isfinite(x) for x in (o,h,l,c)): return None
    if not (1000<l<=min(o,c)<=max(o,c)<=h<10000): return None
    if not (0<=tv<10000000 and 0<=sp<100000): return None
    return (t,off,o,h,l,c,tv,sp,rv)

def find_anchor(b,t):
    pat=struct.pack('<q',t); pos=[]; p=0
    while True:
        p=b.find(pat,p)
        if p<0: break
        r=valid_record(b,p)
        if r: pos.append(r)
        p+=1
    if not pos: raise RuntimeError(f'no HCC anchor {t}')
    return max(pos,key=lambda x:x[1])
def scan_local(path,anchor_t):
    b=path.read_bytes(); anchor=find_anchor(b,anchor_t); a=anchor[1]
    lo=max(0,a-900000); hi=min(len(b)-REC,a+250000); rows=[]
    for off in range(lo,hi):
        r=valid_record(b,off)
        if r: rows.append(r)
    by={}
    for r in rows: by.setdefault(r[0],[]).append(r)
    chosen={t:max(rs,key=lambda x:x[1]) for t,rs in by.items()}
    return b,anchor,rows,by,chosen

def aggregate_h1(chosen):
    hours={}
    for t,r in chosen.items(): hours.setdefault(t-t%3600,[]).append(r)
    out={}
    for h,rs in hours.items():
        rs=sorted(rs)
        out[h]={'open':rs[0][2],'high':max(x[3] for x in rs),'low':min(x[4] for x in rs),'close':rs[-1][5],'m1_count':len(rs)}
    return out

def atr14(hours,event_ts):
    cur=event_ts-event_ts%3600
    keys=[k for k in sorted(hours) if k<cur and hours[k]['m1_count']>=58]
    keys=keys[-15:]; assert len(keys)==15
    trs=[]
    for i,k in enumerate(keys[1:]):
        prev=hours[keys[i]]['close']; x=hours[k]
        tr=max(x['high'],prev)-min(x['low'],prev)
        trs.append({'hour':k,'open':x['open'],'high':x['high'],'low':x['low'],'close':x['close'],'m1_count':x['m1_count'],'prev_close':prev,'tr':tr})
    return trs,sum(x['tr'] for x in trs)/14

def minute_window(chosen,start,end):
    return [chosen[t] for t in sorted(chosen) if start-start%60<=t<=end-end%60]
def parse_set():
    vals={}
    for line in SET.read_text(encoding='utf-8-sig').splitlines():
        s=line.strip()
        if not s or s.startswith(';') or '=' not in s: continue
        k,v=s.split('=',1); vals[k.strip()]=v.strip()
    return vals

def parse_report_inputs(rows):
    b=BT.read_bytes(); text=b.decode('utf-16' if b[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8',errors='replace')
    keys=set(parse_set())|{'_16_BaseLotMode','RC_AdoptLegacyHalt'}
    vals={}
    for k in keys:
        m=re.search(re.escape(k)+r'=([^<\s]+)',text)
        if m: vals[k]=m.group(1)
    return vals

def write_csv(path,fieldnames,rows):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fieldnames); w.writeheader(); w.writerows(rows)

demo=read_demo(); report_rows,bt_deals=read_bt()
demo_ep=episodeize_demo(demo); bt_ep=episodeize_bt(bt_deals)
setvals=parse_set(); reportvals=parse_report_inputs(report_rows)
set_mismatch={k:(v,reportvals.get(k)) for k,v in setvals.items() if reportvals.get(k)!=v}
assert not set_mismatch and reportvals.get('_16_BaseLotMode')=='0'

demo_in=[r for r in demo if r['entry']=='0']; bt_in=[r for r in bt_deals if r['Direction']=='in']
assert demo_in[2]['comment']=='16_KangarooGrid L2' and demo_in[3]['comment']=='16_KangarooGrid L3'
assert bt_in[2]['Comment']=='16_KangarooGrid L2'
ex_l2=int(demo_in[2]['time_unix']); ex_l3=int(demo_in[3]['time_unix']); tm_l2=int(dt(bt_in[2]['Time']).replace(tzinfo=timezone.utc).timestamp())
ex_b,ex_anchor,ex_hits,ex_by,ex_chosen=scan_local(EX,ex_l2-ex_l2%60)
tm_b,tm_anchor,tm_hits,tm_by,tm_chosen=scan_local(TM,tm_l2-tm_l2%60)
ex_h1=aggregate_h1(ex_chosen); tm_h1=aggregate_h1(tm_chosen)
ex_tr,ex_atr=atr14(ex_h1,ex_l2); tm_tr,tm_atr=atr14(tm_h1,tm_l2)
ex_step=max(0.8*ex_atr,1.5); tm_step=max(0.8*tm_atr,1.5)
ex_ref=float(demo_in[2]['price']); tm_ref=num(bt_in[2]['Price'])
ex_trigger=ex_ref-ex_step; tm_trigger=tm_ref-tm_step
tm_elapsed_end=tm_l2+(ex_l3-ex_l2)
ex_win=minute_window(ex_chosen,ex_l2,ex_l3); tm_win=minute_window(tm_chosen,tm_l2,tm_elapsed_end)
assert ex_win and tm_win
ex_min_low=min(r[4] for r in ex_win); tm_min_low=min(r[4] for r in tm_win)
demo_l3_fill=float(demo_in[3]['price'])
assert demo_l3_fill<=ex_trigger
assert tm_min_low>tm_trigger

aligned=[]
for er in [demo_in[0],demo_in[1],demo_in[2],demo_in[3]]:
    ets=int(er['time_unix'])-int(er['time_unix'])%60
    tts=ets+3*3600
    if ets in ex_chosen and tts in tm_chosen:
        e=ex_chosen[ets]; t=tm_chosen[tts]
        aligned.append({'demo_time':er['time'],'demo_comment':er['comment'],'exness_m1_time':ets,'thinkmarkets_m1_time':tts,
                        'exness_ohlc':[e[2],e[3],e[4],e[5]],'thinkmarkets_ohlc':[t[2],t[3],t[4],t[5]],
                        'abs_ohlc_delta':[abs(e[i]-t[i]) for i in range(2,6)]})

kang_blob=git('hash-object',str(KANG)); deploy_blob=git('rev-parse',f'{DEPLOY_REF}:ea_template/core/entries/Kangaroo.mqh')
assert kang_blob==deploy_blob
atr_formula_sha=sha(ATR_SRC)
source_manifest={'schema':'boss16_demo_path_rca_sources/1','observed_at_utc':datetime.now(timezone.utc).isoformat(),
 'canonical_head':git('rev-parse','HEAD'),'external_sources':[
  {'role':'EXNESS_HCC_MUTABLE_CACHE','path':str(EX),'sha256':sha(EX),'bytes':EX.stat().st_size,'mtime_unix':EX.stat().st_mtime},
  {'role':'THINKMARKETS_HCC_MUTABLE_CACHE','path':str(TM),'sha256':sha(TM),'bytes':TM.stat().st_size,'mtime_unix':TM.stat().st_mtime},
  {'role':'C04_TESTER_REPORT','path':str(BT),'sha256':sha(BT),'bytes':BT.stat().st_size},
  {'role':'MT5_ATR_EXAMPLE_SOURCE','path':str(ATR_SRC),'sha256':atr_formula_sha,'bytes':ATR_SRC.stat().st_size},
  {'role':'EXNESS_TICK_CACHE_OBSERVED','path':str(TICKS),'sha256':sha(TICKS),'bytes':TICKS.stat().st_size,'mtime_unix':TICKS.stat().st_mtime}],
 'repo_sources':[{'role':'DEMO_FROZEN_ROWS_SOURCE','path':str(DEMO.relative_to(ROOT)),'sha256':sha(DEMO)},
                 {'role':'BOSS16_SET','path':str(SET.relative_to(ROOT)),'sha256':sha(SET)},
                 {'role':'KANGAROO_MECHANICS','path':str(KANG.relative_to(ROOT)),'git_blob':kang_blob,'deploy_ref_blob':deploy_blob}]}
rca={
 'schema':'boss16_demo_model1_path_rca/2','authority':'RESEARCH_DIAGNOSTIC_ONLY_ZERO_NEW_MT5',
 'classification':'MODEL1_INTRAMINUTE_FILL_PATH_CONFOUND_SUPPORTED_NOT_CAUSALLY_CERTIFIED',
 'demo':{'account':'463666728','magic':'990016','symbol':'XAUUSDm','tf':'H1','episodes':demo_ep,'net':round(sum(x['net'] for x in demo_ep),2)},
 'model1':{'symbol':'XAUUSD','tf':'H1','episodes':bt_ep,'net':round(sum(x['net'] for x in bt_ep),2),'pf':num(val(report_rows,'Profit Factor:')),'trades':int(val(report_rows,'Total Trades:'))},
 'identity':{'set_overrides':len(setvals),'set_overrides_matching_report':len(setvals)-len(set_mismatch),'set_mismatches':set_mismatch,
             'report_BaseLotMode':reportvals.get('_16_BaseLotMode'),'kangaroo_blob_equal_to_deploy_ref':kang_blob==deploy_blob,
             'legacy_identity_ceiling':'Full Demo effective input surface was not durably captured; exact configuration continuity is not certified.'},
 'hcc_decode':{'layout':'empirical local 60-byte record <qddddqiq>; not asserted as an official HCC specification',
               'dedup':'latest valid record per minute offset within local scan','selected_h1_min_m1_records':58,
               'exness_anchor_offset':ex_anchor[1],'thinkmarkets_anchor_offset':tm_anchor[1],
               'exness_local_valid_hits':len(ex_hits),'exness_local_duplicates':sum(len(v)-1 for v in ex_by.values()),
               'thinkmarkets_local_valid_hits':len(tm_hits),'thinkmarkets_local_duplicates':sum(len(v)-1 for v in tm_by.values())},
 'atr14':{'algorithm':'MT5 rolling SMA of True Range; formula independently checked against installed Examples/ATR.mq5',
          'exness':ex_atr,'thinkmarkets':tm_atr,'exness_step':ex_step,'thinkmarkets_step':tm_step,
          'exness_tr14':ex_tr,'thinkmarkets_tr14':tm_tr},
 'path_test':{'demo_l2_fill':ex_ref,'model1_l2_fill':tm_ref,'l2_fill_delta_demo_minus_model1':ex_ref-tm_ref,
              'demo_trigger_after_l2':ex_trigger,'model1_trigger_after_l2':tm_trigger,
              'demo_l3_fill':demo_l3_fill,'demo_l3_fill_crosses_trigger':demo_l3_fill<=ex_trigger,
              'exness_m1_min_low_l2_to_l3':ex_min_low,'thinkmarkets_m1_min_low_same_elapsed':tm_min_low,
              'thinkmarkets_bid_low_stays_above_trigger':tm_min_low>tm_trigger,
              'aligned_m1_examples':aligned},
 'limitations':['C04 typed truncation remains UNKNOWN / truncated=null.','No qualified historical Exness tick stream was replayed.',
                'The +3h alignment is descriptive from observed trade timing, not a qualified broker-clock model.',
                'HCC caches are mutable; the package binds source hashes at extraction time and freezes only the decision-critical extracted records.',
                'This RCA does not grant strategy PASS/FAIL, Candidate, DEMO->LIVE, risk/default, runtime or trading authority.'],
 'next':'QUALIFY_HISTORICAL_EXNESS_REAL_TICK_SOURCE_BEFORE_ANY_MODEL4_GRADE_DIAGNOSTIC'
}
(OUT/'rca.json').write_text(json.dumps(rca,indent=2),encoding='utf-8')
(OUT/'source_manifest.json').write_text(json.dumps(source_manifest,indent=2),encoding='utf-8')
(OUT/'input_surface.json').write_text(json.dumps({'set_values':setvals,'report_values':{k:reportvals.get(k) for k in sorted(set(setvals)|{'_16_BaseLotMode','RC_AdoptLegacyHalt'})},'mismatches':set_mismatch},indent=2),encoding='utf-8')
write_csv(OUT/'demo_990016.csv',list(demo[0].keys()),demo)
write_csv(OUT/'bt_c04_deals.csv',list(bt_deals[0].keys()),bt_deals)
write_csv(OUT/'trigger_comparison.csv',
          ['surface','l2_fill','atr14','step','trigger','observed_value','test','result'],[
 {'surface':'DEMO_EXNESS','l2_fill':ex_ref,'atr14':ex_atr,'step':ex_step,'trigger':ex_trigger,'observed_value':demo_l3_fill,'test':'actual L3 fill <= trigger','result':demo_l3_fill<=ex_trigger},
 {'surface':'MODEL1_THINKMARKETS','l2_fill':tm_ref,'atr14':tm_atr,'step':tm_step,'trigger':tm_trigger,'observed_value':tm_min_low,'test':'M1 bid low > trigger over same elapsed window','result':tm_min_low>tm_trigger}])

extract={'exness_tr14':ex_tr,'thinkmarkets_tr14':tm_tr,'aligned_m1_examples':aligned,
         'exness_window_rows':[{'t':x[0],'o':x[2],'h':x[3],'l':x[4],'c':x[5],'tick_volume':x[6],'spread_points':x[7]} for x in ex_win],
         'thinkmarkets_window_rows':[{'t':x[0],'o':x[2],'h':x[3],'l':x[4],'c':x[5],'tick_volume':x[6],'spread_points':x[7]} for x in tm_win]}
(OUT/'hcc_extract.json').write_text(json.dumps(extract,indent=2),encoding='utf-8')
tick_bytes=TICKS.read_bytes(); probes=[int(r['time_unix']) for r in demo_in[:4]]
tick_pre={'schema':'boss16_exness_tick_source_preflight/1','tick_dir':str(TICK_DIR),'files':[x.name for x in TICK_DIR.iterdir() if x.is_file()],
          'tkc_count':len(list(TICK_DIR.glob('*.tkc'))),'ticks_dat_sha256':sha(TICKS),'ticks_dat_bytes':TICKS.stat().st_size,
          'probes':[{'time_unix':t,'seconds_hits':tick_bytes.count(struct.pack('<q',t)),'milliseconds_hits':tick_bytes.count(struct.pack('<q',t*1000))} for t in probes],
          'classification':'NO_QUALIFIED_HISTORICAL_EXNESS_TICK_STREAM_FROM_OBSERVED_CACHE'}
(OUT/'tick_source_preflight.json').write_text(json.dumps(tick_pre,indent=2),encoding='utf-8')
print(json.dumps({'status':'BUILT','classification':rca['classification'],'demo_trigger':ex_trigger,'model1_trigger':tm_trigger,
                  'demo_l3_fill':demo_l3_fill,'model1_min_bid_low':tm_min_low,'demo_episodes':len(demo_ep),'bt_episodes':len(bt_ep)},indent=2))
