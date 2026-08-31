from pathlib import Path
import csv, json, hashlib, html
ROOT = Path(r"D:/EA_LAB_CONTROL/worktrees/b16-gbp-sell-opt01-reanchor-20260831")
RUN = ROOT / "factory/runs/b16_opt01_20260831/gbp_sell_h4"
analysis = json.loads((RUN / "validation_analysis.json").read_text(encoding="utf-8"))

def parent_rows(path, pred):
    with path.open(newline="", encoding="utf-8-sig") as f:
        return [r for r in csv.DictReader(f) if pred(r)]
parent_head = parent_rows(ROOT / "factory/runs/b16_characterization_20260830/aggregate/cell_summary.csv", lambda r: r["variant"]=="SELL_DIRECTION" and r["context"]=="GBP_H4")
parent_exp = parent_rows(ROOT / "factory/runs/b16_characterization_20260830/aggregate/cycle_exposure_summary.csv", lambda r: r["variant"]=="SELL_DIRECTION" and r["context"]=="GBP_H4")
parent_year = parent_rows(ROOT / "factory/runs/b16_characterization_20260830/aggregate/year_split.csv", lambda r: r["variant"]=="SELL_DIRECTION" and r["context"]=="GBP_H4" and r["year"].isdigit())
ph={r['window']:r for r in parent_head}; pe={r['window']:r for r in parent_exp}
rows=[]
for window,key in [("MAIN","main"),("BWD","bwd")]:
    a=analysis[key]; rep=a['identity']['report']; exp=a['exposure']
    parent=ph[window]; pexp=pe[window]
    row={
      'window':window,
      'parent_net':float(parent['net']),'center_net':float(rep['net_profit']),
      'net_delta':round(float(rep['net_profit'])-float(parent['net']),2),
      'parent_pf':float(parent['pf']),'center_pf':float(rep['profit_factor']),
      'pf_delta':round(float(rep['profit_factor'])-float(parent['pf']),2),
      'parent_trades':int(parent['trades']),'center_trades':int(rep['total_trades']),
      'trades_delta':int(rep['total_trades'])-int(parent['trades']),
      'parent_eqdd_pct':float(parent['native_eqdd_pct']),'center_eqdd_pct':float(rep['equity_drawdown_relative'].split('%')[0]),
      'eqdd_delta_pp':round(float(rep['equity_drawdown_relative'].split('%')[0])-float(parent['native_eqdd_pct']),2),
      'parent_cycles':int(pexp['cycle_count']),'center_cycles':len(a['cycles']),
      'parent_max_depth':int(pexp['max_basket_depth']),'center_max_depth':int(exp['max_basket_depth']),
      'parent_max_lots':float(pexp['max_aggregate_lots']),'center_max_lots':float(exp['max_aggregate_lots']),
      'parent_active_share':float(pexp['active_time_share']),'center_active_share':float(exp['active_time_share_full_window']),
      'parent_multi_entry_gp_share':float(pexp['multi_entry_gp_share']),'center_multi_entry_gp_share':float(a['concentration']['multi_entry_positive_gross_profit_share']),
    }
    rows.append(row)
with (RUN/'parent_center_comparison.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
years=[]
for window,key in [("MAIN","main"),("BWD","bwd")]:
    for b in analysis[key]['bins']:
        if str(b['bin']).isdigit():
            years.append({'window':window,'year':b['bin'],'center_net':b['net_profit'],'center_trades':b['closed_ticket_count'],'center_cycles':b['cycle_count'],'center_pf':b['profit_factor'],'center_active_share':b['active_time_share_full_window']})
parent_map={(r['window'],r['year']):r for r in parent_year}
for y in years:
    p=parent_map[(y['window'],y['year'])]; y['parent_net']=float(p['net']); y['parent_trades']=int(p['trades']); y['parent_cycles']=int(p['cycles'])
with (RUN/'validation_year_split.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(years[0])); w.writeheader(); w.writerows(years)
all_years_positive=all(float(y['center_net'])>0 for y in years)
summary={
 'schema':'ea-lab-b16-opt01-final-summary/1','hypothesis_revision':'B16-H05-r1',
 'mechanical_validation':'PASS_2_OF_2_FULL_WINDOW','coarse_classification':'MAIN_PLATEAU_FOUND',
 'hypothesis':'NOT_FALSIFIED_STABLE_MAIN_ENTRY_REGION_EXISTS','selected_center':{'_16_RsiPeriod':21,'_16_RsiHigh':70.0},
 'bwd_positive': analysis['bwd']['identity']['report']['net_profit']>0,
 'all_calendar_years_positive_2020_2025':all_years_positive,
 'adoption_decision':'DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE',
 'adoption_reason':'selected center is positive and lower-DD but materially reduces net profit, closed trades, cycles and BWD realized position-engine participation versus accepted 14/70 parent in both windows',
 'medium_refine':'NOT_RUN_NO_DIRECT_CONSUMER_AFTER_NON_IMPROVING_CENTER',
 'fine_neighbor':'NOT_RUN_NO_DIRECT_CONSUMER_AFTER_NON_IMPROVING_CENTER',
 'holdout':'UNSPENT','candidate_authority':'NONE','risk_default_change':'NONE',
 'comparison':rows,
 'known_unknowns':['Model4 not run','Monte Carlo not run','HOLDOUT not run','KINT-001 sample-floor conflict remains OPEN','exit type not identifiable from report deal history'],
}
(RUN/'final_summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n',encoding='utf-8')
# Minimal source-backed SVG comparison; visual only.
width,height=920,360
lines=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="white"/>', '<text x="30" y="35" font-family="Arial" font-size="22" font-weight="bold">B16 OPT01 Parent 14/70 vs Selected Center 21/70</text>', '<text x="30" y="58" font-family="Arial" font-size="12">VISUAL_ONLY_NO_AUTHORITY · Meta5b · Model1 · fixed validation</text>']
y=95
for r in rows:
    lines.append(f'<text x="30" y="{y}" font-family="Arial" font-size="17" font-weight="bold">{html.escape(r["window"])}</text>'); y+=28
    metrics=[('Net',r['parent_net'],r['center_net']),('Trades',r['parent_trades'],r['center_trades']),('PF',r['parent_pf'],r['center_pf']),('EqDD %',r['parent_eqdd_pct'],r['center_eqdd_pct']),('Max depth',r['parent_max_depth'],r['center_max_depth'])]
    for name,pv,cv in metrics:
        lines.append(f'<text x="55" y="{y}" font-family="Consolas" font-size="14">{name:10s} parent={pv}   center={cv}</text>'); y+=21
    y+=14
lines.append('</svg>')
(RUN/'parent_center_comparison.svg').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2,sort_keys=True))