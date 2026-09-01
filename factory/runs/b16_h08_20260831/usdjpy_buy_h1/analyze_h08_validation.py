import csv, importlib.util, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
RUN = Path(__file__).resolve().parent
PARSER = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'
spec = importlib.util.spec_from_file_location('b16p', PARSER)
pmod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pmod)

parent = {
    'MAIN': {'pf': 1.53, 'net': 252.53, 'trades': 275, 'eqdd_pct': 3.85},
    'BWD': {'pf': 1.11, 'net': 44.10, 'trades': 267, 'eqdd_pct': 2.40},
}
opt_rows = {}
with (RUN / 'optimizer_surface.csv').open(newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        opt_rows[(int(r['rsi_period']), int(r['rsi_low']))] = r
center_opt = opt_rows[(14, 35)]
results, cells, years = {}, [], []
for window in ('MAIN', 'BWD'):
    cell = RUN / 'validation' / window
    report, ini = cell / 'report.htm', cell / 'tester.ini'
    a = pmod.analyze(report, ini)
    results[window.lower()] = a
    rv = a['identity']['report']
    m = re.match(r'([-0-9.]+)%', rv['equity_drawdown_relative'])
    eqdd = float(m.group(1)) if m else None
    pf_state = 'UNDEFINED_NO_GROSS_LOSS' if rv['gross_loss'] == 0 else 'FINITE'
    pf_value = None if rv['gross_loss'] == 0 else rv['profit_factor']
    trunc = json.loads((cell / 'truncation_check.json').read_text(encoding='utf-8-sig'))
    lev = json.loads((cell / 'leverage_check.json').read_text(encoding='utf-8-sig'))
    eligible = (not trunc['truncated']) and bool(lev['match'])
    bars_pf = (pf_value is not None and pf_value >= (1.20 if window == 'MAIN' else 1.00))
    bars_trades = rv['total_trades'] >= 100
    row = {
        'window': window, 'eligible': eligible, 'pf': pf_value,
        'pf_mt5_field': rv['profit_factor'], 'pf_state': pf_state,
        'trades': rv['total_trades'], 'net': rv['net_profit'], 'eqdd_pct': eqdd,
        'cycles': len(a['cycles']), 'max_depth': a['exposure']['max_basket_depth'],
        'max_lots': a['exposure']['max_aggregate_lots'],
        'active_time_share': a['exposure']['active_time_share_full_window'],
        'multi_entry_gp_share': a['concentration']['multi_entry_positive_gross_profit_share'],
        'gross_profit': rv['gross_profit'], 'gross_loss': rv['gross_loss'],
        'report_sha256': a['input']['report_sha256'], 'truncated': trunc['truncated'],
        'leverage_match': lev['match'], 'selection_bar_pf_pass': bars_pf,
        'selection_bar_trades_pass': bars_trades,
    }
    cells.append(row)
    for b in a['bins']:
        if b['bin'].isdigit():
            years.append({
                'window': window, 'year': int(b['bin']),
                'trades': b['closed_ticket_count'], 'pf': b['profit_factor'],
                'net': b['net_profit'], 'cycles': b['cycle_count'],
                'active_time_share': b['active_time_share_full_window'],
            })

main = next(r for r in cells if r['window'] == 'MAIN')
main_reproduces = (
    abs(main['net'] - float(center_opt['net'])) <= 0.01
    and main['trades'] == int(center_opt['trades'])
    and abs(main['pf'] - float(center_opt['pf'])) <= 0.01
    and abs(main['eqdd_pct'] - float(center_opt['eqdd_pct'])) <= 0.01
)
mechanical = all(r['eligible'] for r in cells)
bars_pass = all(r['selection_bar_pf_pass'] and r['selection_bar_trades_pass'] for r in cells)
classification = (
    'UNKNOWN_MECHANICAL' if not mechanical else
    'FIXED_VALIDATION_PASS' if (main_reproduces and bars_pass) else
    'FIXED_VALIDATION_FAIL'
)
summary = {
    'schema': 'ea-lab-b16-h08-validation-evidence/1',
    'hypothesis_revision': 'B16-H08-r1',
    'selected_center': {'_16_RsiPeriod': 14, '_16_RsiLow': 35.0},
    'mechanical_validation': mechanical,
    'main_reproduces_optimizer_cell': main_reproduces,
    'selection_bars_pass_both_windows': bars_pass,
    'classification': classification,
    'cells': cells, 'accepted_parent_headline': parent,
    'holdout': 'UNSPENT', 'bwd_role': 'VALIDATION_ONLY_NO_RETUNING',
}
(RUN / 'validation_analysis.json').write_text(json.dumps(results, indent=2, sort_keys=True) + '\n', encoding='utf-8')
(RUN / 'validation_summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n', encoding='utf-8')
with (RUN / 'validation_cell_summary.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(cells[0]))
    w.writeheader(); w.writerows(cells)
with (RUN / 'validation_year_split.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(years[0]))
    w.writeheader(); w.writerows(years)
print(json.dumps({'classification': classification, 'cells': cells, 'years': years}, indent=2))
