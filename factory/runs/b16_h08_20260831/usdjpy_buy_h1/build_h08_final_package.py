from pathlib import Path
import csv, hashlib, json, html

RUN = Path(__file__).resolve().parent
val = json.loads((RUN / 'validation_summary.json').read_text(encoding='utf-8'))
sel = json.loads((RUN / 'selection.json').read_text(encoding='utf-8'))
lock = json.loads((RUN / 'center_lock.json').read_text(encoding='utf-8'))
receipt = json.loads((RUN / 'optimization_receipt.json').read_text(encoding='utf-8'))
parent = val['accepted_parent_headline']
center = {r['window']: r for r in val['cells']}

rows = []
for window in ('MAIN', 'BWD'):
    p, c = parent[window], center[window]
    rows.append({
        'window': window,
        'parent_pf': p['pf'], 'center_pf': c['pf'], 'pf_delta': round(c['pf'] - p['pf'], 2),
        'parent_net': p['net'], 'center_net': c['net'], 'net_delta': round(c['net'] - p['net'], 2),
        'parent_trades': p['trades'], 'center_trades': c['trades'], 'trades_delta': c['trades'] - p['trades'],
        'parent_eqdd_pct': p['eqdd_pct'], 'center_eqdd_pct': c['eqdd_pct'],
        'eqdd_delta_pp': round(c['eqdd_pct'] - p['eqdd_pct'], 2),
        'center_cycles': c['cycles'], 'center_max_depth': c['max_depth'],
        'center_active_time_share': c['active_time_share'],
    })
with (RUN / 'parent_center_comparison.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)

mechanical = {
    'schema': 'ea-lab-b16-h08-mechanical-acceptance/1',
    'hypothesis_revision': 'B16-H08-r1',
    'optimizer_guard': {'allow': 2, 'refuse': 0},
    'optimizer_grid_complete': sel['grid_complete'],
    'optimizer_rows': sel['grid_rows'],
    'baseline_reproduced': sel['baseline_reproduced'],
    'fixed_validation_cells': 2,
    'fixed_validation_mechanical_pass': val['mechanical_validation'],
    'fixed_main_reproduces_optimizer_cell': val['main_reproduces_optimizer_cell'],
    'leverage_match_2_of_2': all(r['leverage_match'] for r in val['cells']),
    'truncated_0_of_2': not any(r['truncated'] for r in val['cells']),
    'build_receipt': receipt['build_receipt'],
    'ex5_sha256': receipt['ex5_sha256'],
    'fixed_set_sha256': lock['fixed_set_sha256'],
    'holdout': 'UNSPENT',
}
(RUN / 'mechanical_acceptance.json').write_text(json.dumps(mechanical, indent=2, sort_keys=True) + '\n', encoding='utf-8')
final = {
    'schema': 'ea-lab-b16-h08-final-summary/1',
    'hypothesis_revision': 'B16-H08-r1',
    'coarse_classification': sel['classification'],
    'selected_center': {'_16_RsiPeriod': 14, '_16_RsiLow': 35.0},
    'main_plateau_hypothesis': 'NOT_FALSIFIED',
    'fixed_main_reproduction': 'PASS',
    'bwd_validation': 'FAIL',
    'bwd_failure_basis': 'PF 0.66 < preregistered 1.00 validation bar and net profit -229.49; trade count 230 remains above 100',
    'adoption_decision': 'DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE',
    'decision_reason': 'selected MAIN plateau center improves MAIN net/trades but fails frozen BWD validation materially; BWD is validation-only and cannot retune the lattice',
    'search_status': 'CLOSED_NO_RETUNING',
    'medium_refine': 'NOT_RUN_NO_DIRECT_CONSUMER_AFTER_BWD_FAIL',
    'fine_neighbor': 'NOT_RUN_NO_DIRECT_CONSUMER_AFTER_BWD_FAIL',
    'holdout': 'UNSPENT', 'model4': 'NOT_RUN', 'monte_carlo': 'NOT_RUN',
    'candidate_authority': 'NONE', 'risk_default_change': 'NONE',
    'comparison': rows,
    'known_unknowns': ['HOLDOUT not run', 'Model4 not run', 'Monte Carlo not run', 'KINT-001 remains OPEN'],
}
(RUN / 'final_summary.json').write_text(json.dumps(final, indent=2, sort_keys=True) + '\n', encoding='utf-8')
surface = []
with (RUN / 'optimizer_surface.csv').open(newline='', encoding='utf-8') as f:
    surface = list(csv.DictReader(f))
periods, lows = [7,14,21,28], [20,25,30,35,40]
by = {(int(r['rsi_period']), int(r['rsi_low'])): r for r in surface}
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="760" height="430" viewBox="0 0 760 430">',
         '<style>text{font-family:Arial,sans-serif;font-size:13px}.t{font-size:18px;font-weight:bold}.cell{fill:#eee;stroke:#666}.sel{fill:#ddd;stroke:#000;stroke-width:4}</style>',
         '<text x="20" y="28" class="t">B16-H08 USDJPY/H1 BUY MAIN RSI surface</text>',
         '<text x="20" y="48">VISUAL_ONLY_NO_AUTHORITY; net profit / trades; selected center 14/35.</text>']
x0,y0,cw,ch=135,75,115,72
for j,low in enumerate(lows): parts.append(f'<text x="{x0+j*cw+28}" y="{y0-14}">Low {low}</text>')
for i,p in enumerate(periods):
    parts.append(f'<text x="20" y="{y0+i*ch+38}">Period {p}</text>')
    for j,low in enumerate(lows):
        r=by[(p,low)]; x=x0+j*cw; y=y0+i*ch; cls='sel' if (p,low)==(14,35) else 'cell'
        parts.append(f'<rect x="{x}" y="{y}" width="{cw-5}" height="{ch-5}" class="{cls}"/>')
        parts.append(f'<text x="{x+7}" y="{y+26}">net {float(r["net"]):+.2f}</text>')
        parts.append(f'<text x="{x+7}" y="{y+48}">tr {int(r["trades"])}</text>')
parts.append('</svg>')
(RUN/'h08_main_surface.svg').write_text('\n'.join(parts)+'\n',encoding='utf-8')
cmp = ['<svg xmlns="http://www.w3.org/2000/svg" width="860" height="330" viewBox="0 0 860 330">',
       '<style>text{font-family:Arial,sans-serif;font-size:14px}.t{font-size:19px;font-weight:bold}.h{font-weight:bold}</style>',
       '<text x="25" y="30" class="t">B16-H08 parent 14/30 vs selected 14/35</text>',
       '<text x="25" y="52">VISUAL_ONLY_NO_AUTHORITY; accepted parent headline vs fixed validation center.</text>']
y=88
for r in rows:
    cmp.append(f'<text x="25" y="{y}" class="h">{html.escape(r["window"])}</text>'); y+=26
    for label,pk,ck in [('PF','parent_pf','center_pf'),('Net','parent_net','center_net'),('Trades','parent_trades','center_trades'),('EqDD %','parent_eqdd_pct','center_eqdd_pct')]:
        cmp.append(f'<text x="50" y="{y}">{label}: parent {r[pk]} | center {r[ck]}</text>'); y+=22
    y+=12
cmp.append('</svg>')
(RUN/'h08_parent_center_compare.svg').write_text('\n'.join(cmp)+'\n',encoding='utf-8')
print(json.dumps(final, indent=2, sort_keys=True))
