import csv, importlib.util, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
RUN = Path(__file__).resolve().parent
PARSER = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'
spec = importlib.util.spec_from_file_location('b16p', PARSER)
pmod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pmod)

EXPECTED_SET = '7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782'
BARS = {'MAIN': 1.20, 'BWD': 1.00}
rows = list(csv.DictReader((RUN / 'execution_manifest.csv').open(newline='', encoding='utf-8')))

def eqdd_pct(rv):
    m = re.match(r'([-0-9.]+)%', rv['equity_drawdown_relative'])
    return float(m.group(1)) if m else None

def largest_ticket_loss(a):
    vals = []
    for cycle in a.get('cycles', []):
        for ticket in cycle.get('closed_tickets', []):
            try:
                vals.append(float(ticket['pnl']))
            except (KeyError, TypeError, ValueError):
                pass
    return min(vals) if vals else None

def parse_row(r):
    tag = f"M{r['model']}_{r['window']}"
    cell = RUN / 'runtime' / tag
    report, ini = cell / 'report.htm', cell / 'tester.ini'
    if not report.exists() or not ini.exists():
        return None, []
    a = pmod.analyze(report, ini)
    rv = a['identity']['report']
    trunc = json.loads((cell / 'truncation_check.json').read_text(encoding='utf-8-sig'))
    lev = json.loads((cell / 'leverage_check.json').read_text(encoding='utf-8-sig'))
    pf = None if rv['gross_loss'] == 0 else rv['profit_factor']
    pf_state = 'UNDEFINED_NO_GROSS_LOSS' if pf is None else 'FINITE'
    eligible = (not trunc['truncated']) and bool(lev['match'])
    bar_pass = eligible and pf is not None and pf >= BARS[r['window']] and rv['net_profit'] > 0 and rv['total_trades'] >= 100
    out = {
        'stage': r['stage'], 'model': int(r['model']), 'window': r['window'],
        'mechanical_eligible': eligible, 'pf': pf, 'pf_state': pf_state,
        'net': rv['net_profit'], 'trades': rv['total_trades'], 'eqdd_pct': eqdd_pct(rv),
        'gross_profit': rv['gross_profit'], 'gross_loss': rv['gross_loss'],
        'largest_closed_ticket_loss': largest_ticket_loss(a),
        'cycles': len(a['cycles']), 'max_depth': a['exposure']['max_basket_depth'],
        'max_aggregate_lots': a['exposure']['max_aggregate_lots'],
        'active_time_share': a['exposure']['active_time_share_full_window'],
        'multi_entry_gp_share': a['concentration']['multi_entry_positive_gross_profit_share'],
        'truncated': bool(trunc['truncated']), 'leverage_match': bool(lev['match']),
        'bar_pass': bar_pass, 'report_sha256': a['input']['report_sha256'],
    }
    years = []
    for b in a['bins']:
        if b['bin'].isdigit():
            years.append({
                'model': int(r['model']), 'window': r['window'], 'year': int(b['bin']),
                'trades': b['closed_ticket_count'], 'pf': b['profit_factor'],
                'net': b['net_profit'], 'cycles': b['cycle_count'],
                'active_time_share': b['active_time_share_full_window'],
            })
    return out, years

cells, years = [], []
for r in rows:
    cell, y = parse_row(r)
    if cell is not None:
        cells.append(cell)
        years.extend(y)

lookup = {(c['model'], c['window']): c for c in cells}
control_complete = all((1, w) in lookup for w in ('MAIN', 'BWD'))
control_pass = control_complete and all(lookup[(1, w)]['bar_pass'] for w in ('MAIN', 'BWD'))
model4_complete = all((4, w) in lookup for w in ('MAIN', 'BWD'))
model4_pass = model4_complete and all(lookup[(4, w)]['bar_pass'] for w in ('MAIN', 'BWD'))

if control_complete and not control_pass:
    classification = 'R4_CONTROL_FAIL_PARK'
elif control_pass and model4_complete and model4_pass:
    classification = 'R4_EXECUTION_FIDELITY_NOT_FALSIFIED'
elif control_pass and model4_complete and not model4_pass:
    classification = 'R4_FAIL_PARK'
elif control_pass:
    classification = 'CONTROL_PASS_MODEL4_PENDING'
else:
    classification = 'CONTROL_PENDING'

summary = {
    'schema': 'ea-lab-b16-r4-execution-fidelity/1',
    'hypothesis_revision': 'B16-R4-r1',
    'set_sha256_expected': EXPECTED_SET,
    'same_install': 'D:\\Meta 5',
    'historical_cross_install_numbers_used_for_acceptance': False,
    'control_complete': control_complete,
    'model1_control_pass': control_pass,
    'model4_complete': model4_complete,
    'model4_pass': model4_pass,
    'classification': classification,
    'cells': cells,
    'holdout': 'UNSPENT',
    'optimization': 'NONE',
    'quality_grade': 'UNRATIFIED',
    'kint_001': 'OPEN',
}
(RUN / 'evidence_summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n', encoding='utf-8')
if cells:
    with (RUN / 'cell_summary.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(cells[0]))
        w.writeheader(); w.writerows(cells)
if years:
    with (RUN / 'year_split.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(years[0]))
        w.writeheader(); w.writerows(years)
print(json.dumps({'classification': classification, 'cells': cells}, indent=2))
