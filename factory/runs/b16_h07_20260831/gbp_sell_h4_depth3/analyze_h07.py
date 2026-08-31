import csv, gzip, hashlib, importlib.util, json, re, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
RUN = Path(__file__).resolve().parent
PARSER = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'
spec = importlib.util.spec_from_file_location('b16p', PARSER)
pmod = importlib.util.module_from_spec(spec); spec.loader.exec_module(pmod)

PARENT = ROOT / 'factory/runs/b16_characterization_20260830/evidence/SELL_DIRECTION/GBP_H4'
D2 = ROOT / 'factory/runs/b16_h06_20260831/gbp_sell_h4_depth2/runtime/GBP_H4'


def parse_cell(cell: Path, cap: int):
    ini = cell / 'tester.ini'
    report = cell / 'report.htm'
    if report.exists():
        a = pmod.analyze(report, ini)
        storage = 'RAW_HTM'
    else:
        gz = cell / 'report.htm.gz'
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td) / 'report.htm'
            tmp.write_bytes(gzip.decompress(gz.read_bytes()))
            a = pmod.analyze(tmp, ini)
        a['input']['report_gzip_sha256'] = hashlib.sha256(gz.read_bytes()).hexdigest()
        storage = 'DETERMINISTIC_GZIP'
    a['input']['report_storage'] = storage
    a['exposure']['configured_orders_per_side_cap'] = cap
    a['exposure']['cap_contact'] = a['exposure']['max_basket_depth'] == cap
    return a


def metric_row(variant, window, a, eligible=True):
    rv = a['identity']['report']
    m = re.match(r'([-0-9.]+)%', rv['equity_drawdown_relative'])
    eqdd = float(m.group(1)) if m else None
    no_loss = rv['gross_loss'] == 0
    return {
        'variant': variant, 'window': window, 'eligible': eligible,
        'pf': None if no_loss else rv['profit_factor'],
        'pf_mt5_field': rv['profit_factor'],
        'pf_state': 'UNDEFINED_NO_GROSS_LOSS' if no_loss else 'FINITE',
        'trades': rv['total_trades'], 'net': rv['net_profit'], 'eqdd_pct': eqdd,
        'cycles': len(a['cycles']), 'max_depth': a['exposure']['max_basket_depth'],
        'max_lots': a['exposure']['max_aggregate_lots'],
        'active_time_share': a['exposure']['active_time_share_full_window'],
        'multi_entry_gp_share': a['concentration']['multi_entry_positive_gross_profit_share'],
        'gross_profit': rv['gross_profit'], 'gross_loss': rv['gross_loss'],
        'report_sha256': a['input']['report_sha256'],
    }


def year_rows(variant, window, a):
    by_bin = {b['bin']: b for b in a['bins'] if b['bin'].isdigit()}
    out = []
    for year in sorted(int(y) for y in by_bin):
        b = by_bin[str(year)]
        members = [c for c in a['cycles'] if int(c['end'][:4]) == year]
        out.append({
            'variant': variant, 'window': window, 'year': year,
            'trades': b['closed_ticket_count'], 'pf': b['profit_factor'],
            'net': b['net_profit'], 'cycles': b['cycle_count'],
            'active_time_share': b['active_time_share_full_window'],
            'max_depth': max((c['max_basket_depth'] or 0) for c in members) if members else 0,
            'depth3_contact_cycles': sum(1 for c in members if (c['max_basket_depth'] or 0) >= 3),
            'depth4_contact_cycles': sum(1 for c in members if (c['max_basket_depth'] or 0) >= 4),
        })
    return out


analyses = {'PARENT10': {}, 'DEPTH2': {}, 'DEPTH3': {}}
rows, years = [], []
for window in ('MAIN', 'BWD'):
    analyses['PARENT10'][window] = parse_cell(PARENT / window, 10)
    analyses['DEPTH2'][window] = parse_cell(D2 / window, 2)
    analyses['DEPTH3'][window] = parse_cell(RUN / 'runtime' / 'GBP_H4' / window, 3)

    trunc = json.loads((RUN / 'runtime' / 'GBP_H4' / window / 'truncation_check.json').read_text(encoding='utf-8-sig'))
    lev = json.loads((RUN / 'runtime' / 'GBP_H4' / window / 'leverage_check.json').read_text(encoding='utf-8-sig'))
    eligible = (not trunc['truncated']) and bool(lev['match'])

    for variant in ('PARENT10', 'DEPTH2', 'DEPTH3'):
        is_eligible = eligible if variant == 'DEPTH3' else True
        rows.append(metric_row(variant, window, analyses[variant][window], is_eligible))
        years.extend(year_rows(variant, window, analyses[variant][window]))

child_rows = [r for r in rows if r['variant'] == 'DEPTH3']
y2025 = next(r for r in years if r['variant'] == 'DEPTH3' and r['year'] == 2025)
all_eligible = all(r['eligible'] for r in child_rows)
contact_2025 = y2025['depth3_contact_cycles'] > 0

if not all_eligible:
    classification = 'UNKNOWN_MECHANICAL'
elif not contact_2025:
    classification = 'UNKNOWN_NO_2025_DEPTH3_CONTACT'
elif any(r['net'] <= 0 for r in child_rows) or y2025['net'] <= 0:
    classification = 'DEPTH3_DOES_NOT_RECOVER_REQUIRED_SIGN'
else:
    classification = 'DEPTH3_RECOVERS_2025_SIGN'


summary = {
    'schema': 'ea-lab-b16-h07-depth3-evidence/1',
    'hypothesis_id': 'HYP-B16-GBP-SELL-H4-DEPTH3-01',
    'prereg_head': 'e2cf21e2a0c9f95559b88ebb92d9a520832b7126',
    'classification': classification,
    'hypothesis_falsified': classification == 'DEPTH3_DOES_NOT_RECOVER_REQUIRED_SIGN',
    'contact_2025_depth3': contact_2025,
    'depth3_cells': child_rows,
    'depth3_2025': y2025,
    'holdout': 'UNSPENT', 'optimization': 'NONE',
}

(RUN / 'depth_ladder_evidence.json').write_text(json.dumps(analyses, indent=2, sort_keys=True) + '\n', encoding='utf-8')
(RUN / 'evidence_summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n', encoding='utf-8')
with (RUN / 'depth_ladder.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
with (RUN / 'year_depth_ladder.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(years[0])); w.writeheader(); w.writerows(years)
with (RUN / 'cell_summary.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(child_rows[0])); w.writeheader(); w.writerows(child_rows)
with (RUN / 'year_split.csv').open('w', newline='', encoding='utf-8') as f:
    child_years = [r for r in years if r['variant'] == 'DEPTH3']
    w = csv.DictWriter(f, fieldnames=list(child_years[0])); w.writeheader(); w.writerows(child_years)

print(json.dumps({
    'classification': classification,
    'contact_2025_depth3': contact_2025,
    'depth3_cells': child_rows,
    'depth3_years': [r for r in years if r['variant'] == 'DEPTH3'],
    'parent_2025': next(r for r in years if r['variant'] == 'PARENT10' and r['year'] == 2025),
    'depth2_2025': next(r for r in years if r['variant'] == 'DEPTH2' and r['year'] == 2025),
}, indent=2))
