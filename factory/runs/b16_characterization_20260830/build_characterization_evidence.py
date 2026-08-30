#!/usr/bin/env python3
from __future__ import annotations
import csv, gzip, hashlib, importlib.util, json, re, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUN = ROOT / 'factory/runs/b16_characterization_20260830'
AGG = RUN / 'aggregate'
EVID = RUN / 'evidence'
PARSER_PATH = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'

spec = importlib.util.spec_from_file_location('b16_h03_parser', PARSER_PATH)
parser = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(parser)

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def dd_pct(text: str) -> float:
    m = re.search(r'\((\d+(?:\.\d+)?)%\)', text)
    if not m: raise ValueError(f'cannot parse EqDD percent: {text}')
    return float(m.group(1))

def dump_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + '\n', encoding='utf-8')

PARENTS = {
 'XAU_H4': {'symbol':'XAUUSD','tf':'H4','MAIN':{'pf':4.08,'trades':79,'net':707.78,'dd':6.27,'report_sha':'aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e'},'BWD':{'pf':1.44,'trades':148,'net':512.69,'dd':8.29,'report_sha':'df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3'}},
 'USDJPY_H1': {'symbol':'USDJPY','tf':'H1','MAIN':{'pf':1.53,'trades':275,'net':252.53,'dd':3.85,'report_sha':'45ac54affa7635cf350ba69492102d58557d54373424d802a3e2b57cdc562c64'},'BWD':{'pf':1.11,'trades':267,'net':44.10,'dd':2.40,'report_sha':'745cb0a465fbcb1b864e3e117e4ac1ce3de698606b100eb514adb110739a1893'}},
 'XAU_M15': {'symbol':'XAUUSD','tf':'M15','MAIN':{'pf':1.25,'trades':1577,'net':2643.64,'dd':11.88,'report_sha':'2aeb5f6c0de9a517b3a49c2ca62b75e87938edc457e7adac2317a0a7b5afb728'},'BWD':{'pf':1.10,'trades':1463,'net':1002.69,'dd':14.86,'report_sha':'27149f0074c81e70b086a31dbf722eafa2920c281f05adaaf9022dd8a8bc2644'}},
 'EUR_H4': {'symbol':'EURUSD','tf':'H4','MAIN':{'pf':6.39,'trades':64,'net':126.54,'dd':1.42,'report_sha':'72dad125e39571057c1614e02632ceadf7cd6ef93720ce399aaa3b2439741fca'},'BWD':{'pf':0.25,'trades':51,'net':-553.81,'dd':8.46,'report_sha':'e170deb421f404619589b5b20518d3277b10f73f4baa606ebd895ba92fce6602'}},
 'GBP_H4': {'symbol':'GBPUSD','tf':'H4','MAIN':{'pf':2.46,'trades':60,'net':115.98,'dd':1.93,'report_sha':'711a641ef2a35c69688133a3d8ac13b80b3a239d2e30625d3dffe6e3db4b1588'},'BWD':{'pf':0.44,'trades':61,'net':-736.29,'dd':10.61,'report_sha':'1127be2db9c18c84cbdd8487c7bdf82c5888f7cc33ec9eff34e4cfb18d780eee'}},
}
CAPS = {'DEPTH2':2,'DEPTH4':4,'DEPTH5':5}
POSITIVE_RULE = {'DEPTH2','DEPTH4','DEPTH5','SELL_DIRECTION'}
VARIANTS = ['DEPTH2','DEPTH4','DEPTH5','SINGLETP_OFF','BASKETTP_OFF','OVERLAP_OFF','PIPFLOOR_OFF','DEEP_SPACING_EQUAL','SELL_DIRECTION']
PARENT_SET_SHA = '7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782'
BUILD_RECEIPT = 'br-4fa94d22907b446ebc721d524bdfa5d1'
EX5_SHA = '212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db'

CAGE_KILLS = {
 'B16CHAR_BASKETTP_OFF_XAU_H4_BWD_M1': {'tester_wallclock':'20:59:14.865','market_time':'2022.07.13 15:41:40','dd_pct':25.00},
 'B16CHAR_OVERLAP_OFF_XAU_M15_BWD_M1': {'tester_wallclock':'21:01:20.771','market_time':'2022.09.15 07:54:40','dd_pct':25.01},
 'B16CHAR_SELL_DIRECTION_XAU_M15_MAIN_M1': {'tester_wallclock':'21:05:43.953','market_time':'2025.02.11 03:13:40','dd_pct':25.08},
 'B16CHAR_SELL_DIRECTION_XAU_M15_BWD_M1': {'tester_wallclock':'21:05:59.436','market_time':'2020.08.07 01:20:40','dd_pct':25.18},
}

def load_receipts(path: Path, source: str, runtime_root: Path):
    rows=[]
    for raw in path.read_text(encoding='utf-8-sig').splitlines():
        if not raw.strip(): continue
        r=json.loads(raw); r['_source']=source; r['_runtime_root']=str(runtime_root); rows.append(r)
    return rows

receipts = load_receipts(RUN/'run_receipts.jsonl','MAIN_MATRIX',RUN/'runtime')
receipts += load_receipts(RUN/'extension_eurgbp_h4/run_receipts.jsonl','EURGBP_EXTENSION',RUN/'extension_eurgbp_h4/runtime')
if len(receipts) != 88 or len({r['report_name'] for r in receipts}) != 88:
    raise SystemExit(f'receipt completeness failure: {len(receipts)} / {len({r["report_name"] for r in receipts})}')

AGG.mkdir(parents=True, exist_ok=True)
EVID.mkdir(parents=True, exist_ok=True)
cell_rows=[]; cycle_rows=[]; year_rows=[]; parsed_by_pair={}

for r in sorted(receipts, key=lambda x:(x['variant'],x['context'],x['window'])):
    runtime=Path(r['_runtime_root']); cell=runtime/r['variant']/r['context']/r['window']
    report=cell/'report.htm'; ini=cell/'tester.ini'; levp=cell/'leverage_check.json'; truncp=cell/'truncation_check.json'
    for p in (report,ini,levp,truncp):
        if not p.is_file(): raise SystemExit(f'missing evidence: {p}')
    if sha256(report) != r['report_sha256']: raise SystemExit(f'report hash mismatch: {r["report_name"]}')
    lev=json.loads(levp.read_text(encoding='utf-8-sig')); trunc=json.loads(truncp.read_text(encoding='utf-8-sig'))
    if not lev.get('match'): raise SystemExit(f'leverage mismatch: {r["report_name"]}')
    killed=r['report_name'] in CAGE_KILLS
    eligible=(not killed) and (not bool(trunc.get('truncated')))
    try:
        a=parser.analyze(report,ini); rv=a['identity']['report']; parse_error=''
    except Exception as exc:
        a=None; parse_error=f'{type(exc).__name__}: {exc}'
        rows=parser.parse_html(report)
        rv={'profit_factor':parser.number(parser.find_value(rows,'Profit Factor:')),
            'net_profit':parser.number(parser.find_value(rows,'Total Net Profit:')),
            'total_trades':int(parser.number(parser.find_value(rows,'Total Trades:'))),
            'equity_drawdown_maximal':parser.find_value(rows,'Equity Drawdown Maximal:')}
    native_dd=dd_pct(rv['equity_drawdown_maximal'])
    outdir=EVID/r['variant']/r['context']/r['window']; outdir.mkdir(parents=True,exist_ok=True)
    with report.open('rb') as src, (outdir/'report.htm.gz').open('wb') as rawdst:
        with gzip.GzipFile(filename='',mode='wb',fileobj=rawdst,mtime=0) as dst: shutil.copyfileobj(src,dst)
    shutil.copy2(ini,outdir/'tester.ini'); shutil.copy2(levp,outdir/'leverage_check.json'); shutil.copy2(truncp,outdir/'truncation_check.json')
    cell_rows.append({'variant':r['variant'],'context':r['context'],'symbol':r['symbol'],'tf':r['tf'],'window':r['window'],
      'pf':rv['profit_factor'],'net':rv['net_profit'],'trades':rv['total_trades'],'native_eqdd_pct':native_dd,
      'report_sha256':r['report_sha256'],'set_sha256':r['set_sha256'],'build_receipt':r['build_receipt'],'ex5_sha256':r['ex5_sha256'],
      'source':r['_source'],'sidecar_truncated':bool(trunc.get('truncated')),'cage_kill_confirmed':killed,'full_window_eligible':eligible,'parse_error':parse_error})
    if a is not None:
        recon=a['reconciliation']
        required=['net_profit_matches','gross_profit_matches','gross_loss_matches','profit_factor_matches_rounded','closed_ticket_count_matches_total_trades']
        if not all(recon.get(k) for k in required): raise SystemExit(f'cycle reconciliation failure: {r["report_name"]} {recon}')
        ex=a['exposure']; cap=CAPS.get(r['variant'],10); maxdepth=ex['max_basket_depth']
        top=a['concentration']['top_profitable_cycles']
        cycle_rows.append({'variant':r['variant'],'context':r['context'],'window':r['window'],'full_window_eligible':eligible,
          'cycle_count':len(a['cycles']),'closed_ticket_count':a['reconstructed']['closed_ticket_count'],
          'max_simultaneous_positions':ex['max_simultaneous_positions'],'max_basket_depth':maxdepth,
          'configured_cap_overlay':cap,'cap_contact_overlay':bool(maxdepth is not None and maxdepth >= cap),
          'parser_configured_cap_raw':ex['configured_orders_per_side_cap'],'parser_cap_contact_raw':ex['cap_contact'],
          'max_aggregate_lots':ex['max_aggregate_lots'],'max_entry_price_span':ex['max_entry_price_span'],
          'active_time_share':ex['active_time_share_full_window'],
          'multi_entry_gp_share':a['concentration']['multi_entry_positive_gross_profit_share'],
          'top_profitable_cycle_gp_share':None if not top else top[0]['gross_profit_share'],
          'directions':'|'.join(x['direction'] for x in a['direction'])})
        for b in a['bins']:
            if str(b['bin']).isdigit():
                year_rows.append({'variant':r['variant'],'context':r['context'],'window':r['window'],'year':b['bin'],
                  'full_window_eligible':eligible,'cycles':b['cycle_count'],'trades':b['closed_ticket_count'],
                  'pf':b['profit_factor'],'net':b['net_profit'],'active_share':b['active_time_share_full_window'],
                  'realized_balance_dd':b['realized_balance_dd']})
    parsed_by_pair[(r['variant'],r['context'],r['window'])]=cell_rows[-1]

def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    if not rows: path.write_text('',encoding='utf-8'); return
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

REUSED_OVERLAP_XAU_H4 = {
 'MAIN': {'pf':0.51,'net':-924.01,'trades':72,'native_eqdd_pct':22.28,'report_sha256':'f401bd17d564a984209df4dda069011a3fb98bcf3910ebd32ad2862e5467501e'},
 'BWD': {'pf':1.94,'net':890.51,'trades':141,'native_eqdd_pct':7.70,'report_sha256':'d819e6b76824961a37a7702c640abe3794485bd2bcfc0b2a1d6a2ec55f57997e'},
}
pair_rows=[]
for variant in VARIANTS:
    for context,parent in PARENTS.items():
        if variant=='OVERLAP_OFF' and context=='XAU_H4':
            cm=dict(REUSED_OVERLAP_XAU_H4['MAIN'],full_window_eligible=True,cage_kill_confirmed=False)
            cb=dict(REUSED_OVERLAP_XAU_H4['BWD'],full_window_eligible=True,cage_kill_confirmed=False)
            source='REUSED_BT1_ACCEPTED'
        else:
            cm=parsed_by_pair.get((variant,context,'MAIN')); cb=parsed_by_pair.get((variant,context,'BWD'))
            if cm is None or cb is None: continue
            source='NEW_MATRIX_OR_EXTENSION'
        eligible=bool(cm['full_window_eligible'] and cb['full_window_eligible'])
        if not eligible: verdict='UNKNOWN_MECHANICAL_INELIGIBLE'
        elif variant in POSITIVE_RULE:
            verdict='HYPOTHESIS_FALSIFIED' if (cm['net'] <= 0 or cb['net'] <= 0) else 'HYPOTHESIS_NOT_FALSIFIED'
        else:
            dominates=(cm['net'] >= parent['MAIN']['net'] and cm['native_eqdd_pct'] <= parent['MAIN']['dd'] and
                       cb['net'] >= parent['BWD']['net'] and cb['native_eqdd_pct'] <= parent['BWD']['dd'])
            verdict='HYPOTHESIS_FALSIFIED' if dominates else 'HYPOTHESIS_NOT_FALSIFIED'
        pair_rows.append({'variant':variant,'context':context,'symbol':parent['symbol'],'tf':parent['tf'],'source':source,
          'mechanically_eligible':eligible,'verdict':verdict,
          'parent_main_net':parent['MAIN']['net'],'child_main_net':cm['net'],'delta_main_net':round(cm['net']-parent['MAIN']['net'],2),
          'parent_bwd_net':parent['BWD']['net'],'child_bwd_net':cb['net'],'delta_bwd_net':round(cb['net']-parent['BWD']['net'],2),
          'parent_main_dd':parent['MAIN']['dd'],'child_main_dd':cm['native_eqdd_pct'],'delta_main_dd_pp':round(cm['native_eqdd_pct']-parent['MAIN']['dd'],2),
          'parent_bwd_dd':parent['BWD']['dd'],'child_bwd_dd':cb['native_eqdd_pct'],'delta_bwd_dd_pp':round(cb['native_eqdd_pct']-parent['BWD']['dd'],2),
          'child_main_pf':cm['pf'],'child_bwd_pf':cb['pf'],'child_main_trades':cm['trades'],'child_bwd_trades':cb['trades'],
          'cage_kill_main':bool(cm.get('cage_kill_confirmed',False)),'cage_kill_bwd':bool(cb.get('cage_kill_confirmed',False))})

ENTRY_ONLY = [
 {'context':'XAU_H4','source':'BT1','main_pf':2.41,'main_net':149.08,'main_trades':49,'main_dd':1.18,'bwd_pf':0.90,'bwd_net':-32.09,'bwd_trades':76,'bwd_dd':2.42,'verdict':'HYPOTHESIS_FALSIFIED'},
 {'context':'USDJPY_H1','source':'BT2','main_pf':2.87,'main_net':172.87,'main_trades':290,'main_dd':0.57,'bwd_pf':1.22,'bwd_net':33.22,'bwd_trades':260,'bwd_dd':0.70,'verdict':'HYPOTHESIS_NOT_FALSIFIED'},
 {'context':'XAU_M15','source':'BT3','main_pf':1.15,'main_net':213.52,'main_trades':783,'main_dd':3.15,'bwd_pf':1.07,'bwd_net':80.64,'bwd_trades':814,'bwd_dd':2.22,'verdict':'HYPOTHESIS_NOT_FALSIFIED'},
]

write_csv(AGG/'cell_summary.csv',cell_rows)
write_csv(AGG/'pair_falsifier_summary.csv',pair_rows)
write_csv(AGG/'cycle_exposure_summary.csv',cycle_rows)
write_csv(AGG/'year_split.csv',year_rows)
write_csv(AGG/'entry_only_reused_summary.csv',ENTRY_ONLY)
dump_json(AGG/'parent_contexts.json',PARENTS)
dump_json(AGG/'cage_kill_evidence.json',CAGE_KILLS)

eligible=sum(1 for r in cell_rows if r['full_window_eligible'])
killed=sum(1 for r in cell_rows if r['cage_kill_confirmed'])
suspect=sum(1 for r in cell_rows if r['sidecar_truncated'] and not r['cage_kill_confirmed'])
mechanical={'schema':'ea-lab-b16-characterization-mechanical/1','new_cells':len(cell_rows),'unique_reports':len({r['report_sha256'] for r in cell_rows}),
 'full_window_eligible_cells':eligible,'cage_kill_ineligible_cells':killed,'unresolved_suspect_cells':suspect,
 'leverage':'1:100 MATCH all 88','build_receipt':BUILD_RECEIPT,'ex5_sha256':EX5_SHA,'parent_set_sha256':PARENT_SET_SHA,
 'holdout':'UNSPENT','optimization':'NONE','model':1}
dump_json(AGG/'mechanical_acceptance.json',mechanical)

shutil.copy2(RUN/'run_receipts.jsonl',AGG/'main_run_receipts.jsonl')
shutil.copy2(RUN/'execution_console.log',AGG/'main_execution_console.log')
shutil.copy2(RUN/'extension_eurgbp_h4/run_receipts.jsonl',AGG/'extension_run_receipts.jsonl')
shutil.copy2(RUN/'extension_eurgbp_h4/execution_console.log',AGG/'extension_execution_console.log')
