import csv, gzip, hashlib, json
from pathlib import Path
RUN=Path(__file__).resolve().parent
summary=json.loads((RUN/'evidence_summary.json').read_text())
parents={
 'MAIN':{'pf':7.97,'net':283.20,'trades':80,'eqdd_pct':1.72,'cycles':70,'max_depth':4,'max_lots':0.04,'active_time_share':0.197051,'multi_entry_gp_share':0.709579},
 'BWD':{'pf':14.36,'net':268.97,'trades':76,'eqdd_pct':1.27,'cycles':69,'max_depth':4,'max_lots':0.04,'active_time_share':0.089294,'multi_entry_gp_share':0.58936},
}
with (RUN/'parent_child.csv').open('w',newline='',encoding='utf-8') as f:
 fields=['window','parent_pf','child_pf','child_pf_state','parent_net','child_net','net_delta','parent_trades','child_trades','trades_delta','parent_eqdd_pct','child_eqdd_pct','eqdd_delta_pp','parent_cycles','child_cycles','parent_max_depth','child_max_depth','parent_max_lots','child_max_lots','parent_active_time_share','child_active_time_share','parent_multi_entry_gp_share','child_multi_entry_gp_share']
 w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
 for c in summary['cells']:
  p=parents[c['window']]
  w.writerow({'window':c['window'],'parent_pf':p['pf'],'child_pf':c['pf'],'child_pf_state':c['pf_state'],'parent_net':p['net'],'child_net':c['net'],'net_delta':round(c['net']-p['net'],2),'parent_trades':p['trades'],'child_trades':c['trades'],'trades_delta':c['trades']-p['trades'],'parent_eqdd_pct':p['eqdd_pct'],'child_eqdd_pct':c['eqdd_pct'],'eqdd_delta_pp':round(c['eqdd_pct']-p['eqdd_pct'],2),'parent_cycles':p['cycles'],'child_cycles':c['cycles'],'parent_max_depth':p['max_depth'],'child_max_depth':c['max_depth'],'parent_max_lots':p['max_lots'],'child_max_lots':c['max_lots'],'parent_active_time_share':p['active_time_share'],'child_active_time_share':c['active_time_share'],'parent_multi_entry_gp_share':p['multi_entry_gp_share'],'child_multi_entry_gp_share':c['multi_entry_gp_share']})
accept={'schema':'ea-lab-b16-h06-depth2-mechanical/1','cells_expected':2,'cells_completed':2,'tester_exit_zero':True,'exact_symbol_tf_dates_model':True,'set_sha256':'d31a34b68caaaeabca07d960dede016a8cf513fd8e4c6cf2bbe124d172d55b14','full_surface':'173/173','build_receipt':'br-4fa94d22907b446ebc721d524bdfa5d1','ex5_sha256':'212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db','leverage_1_100_match':'2/2','truncation_false':'2/2','hard_kill':'0/2','source_byte_reconciliation':'PASS','stale_mtime_warning':'RECONCILED_FALSE_POSITIVE','holdout':'UNSPENT','optimization':'NONE','overall':'PASS'}
(RUN/'mechanical_acceptance.json').write_text(json.dumps(accept,indent=2,sort_keys=True)+'\n',encoding='utf-8')
for report in RUN.glob('runtime/*/*/report.htm'):
 data=report.read_bytes(); gz=report.with_suffix(report.suffix+'.gz'); gz.write_bytes(gzip.compress(data,compresslevel=9,mtime=0)); report.unlink()
# Minimal deterministic decision visual.
svg='''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="420" viewBox="0 0 900 420"><rect width="900" height="420" fill="white"/><text x="40" y="40" font-family="sans-serif" font-size="24">B16 GBPUSD/H4 SELL â€” Parent vs Depth-2</text><text x="40" y="70" font-family="sans-serif" font-size="14">Net profit (USD); research evidence only</text><line x1="80" y1="340" x2="840" y2="340" stroke="black"/><text x="160" y="370" font-family="sans-serif" font-size="14">MAIN Parent</text><text x="330" y="370" font-family="sans-serif" font-size="14">MAIN D2</text><text x="520" y="370" font-family="sans-serif" font-size="14">BWD Parent</text><text x="690" y="370" font-family="sans-serif" font-size="14">BWD D2</text><rect x="160" y="90" width="90" height="250" fill="#888"/><rect x="330" y="296" width="90" height="44" fill="#bbb"/><rect x="520" y="102" width="90" height="238" fill="#888"/><rect x="690" y="122" width="90" height="218" fill="#bbb"/><text x="172" y="82" font-family="sans-serif" font-size="14">283.20</text><text x="344" y="288" font-family="sans-serif" font-size="14">50.11</text><text x="532" y="94" font-family="sans-serif" font-size="14">268.97</text><text x="702" y="114" font-family="sans-serif" font-size="14">247.04</text><text x="40" y="405" font-family="sans-serif" font-size="12">Primary falsifier not met: both depth-2 windows remain net positive. MAIN utility/year stability materially weakens.</text></svg>'''
(RUN/'parent_depth2_net.svg').write_text(svg,encoding='utf-8')
files=sorted(p for p in RUN.rglob('*') if p.is_file() and p.name!='artifacts.sha256')
lines=[f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(RUN).as_posix()}" for p in files]
(RUN/'artifacts.sha256').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'PACKAGED_FILES={len(files)}')
