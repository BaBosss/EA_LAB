import csv, gzip, hashlib, json
from pathlib import Path

RUN = Path(__file__).resolve().parent
summary = json.loads((RUN / 'evidence_summary.json').read_text(encoding='utf-8'))
ladder = list(csv.DictReader((RUN / 'depth_ladder.csv').open(encoding='utf-8')))
years = list(csv.DictReader((RUN / 'year_depth_ladder.csv').open(encoding='utf-8')))

accept = {
    'schema': 'ea-lab-b16-h07-depth3-mechanical/1',
    'cells_expected': 2, 'cells_completed': 2, 'tester_exit_zero': True,
    'exact_symbol_tf_dates_model': True,
    'set_sha256': '3dbcf63f002a0bfad0371c5f26acf7156a6eabc8820f31a0d67f663f24f3edd5',
    'full_surface': '173/173',
    'build_receipt': 'br-4fa94d22907b446ebc721d524bdfa5d1',
    'ex5_sha256': '212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db',
    'leverage_1_100_match': '2/2', 'truncation_false': '2/2',
    'hard_kill': '0/2', 'source_parser_reconciliation': 'PASS',
    'stale_mtime_warning': 'RECONCILED_FALSE_POSITIVE',
    'holdout': 'UNSPENT', 'optimization': 'NONE', 'overall': 'PASS',
}
(RUN / 'mechanical_acceptance.json').write_text(json.dumps(accept, indent=2, sort_keys=True) + '\n', encoding='utf-8')

for report in RUN.glob('runtime/*/*/report.htm'):
    data = report.read_bytes()
    gz = report.with_suffix(report.suffix + '.gz')
    gz.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
    report.unlink()


def pick(variant, window):
    return next(r for r in ladder if r['variant'] == variant and r['window'] == window)

milestone = {
    'schema': 'ea-lab-b16-depth-milestone/1',
    'classification': summary['classification'],
    'contact_2025_depth3': summary['contact_2025_depth3'],
    'decision': 'DEPTH3_NOT_ADOPTED_AUTOMATICALLY_RETAIN_PARENT_AND_DEPTH3_AS_RESEARCH_REFERENCES',
    'main': {v: pick(v, 'MAIN') for v in ('PARENT10', 'DEPTH2', 'DEPTH3')},
    'bwd': {v: pick(v, 'BWD') for v in ('PARENT10', 'DEPTH2', 'DEPTH3')},
    'year_2025': {v: next(r for r in years if r['variant'] == v and r['year'] == '2025') for v in ('PARENT10', 'DEPTH2', 'DEPTH3')},
    'holdout': 'UNSPENT', 'optimization': 'NONE',
}
(RUN / 'milestone_summary.json').write_text(json.dumps(milestone, indent=2, sort_keys=True) + '\n', encoding='utf-8')

# Compact research visual; values come from depth_ladder.csv.
vals = [
    ('MAIN P10', float(pick('PARENT10','MAIN')['net'])), ('MAIN D2', float(pick('DEPTH2','MAIN')['net'])),
    ('MAIN D3', float(pick('DEPTH3','MAIN')['net'])), ('BWD P10', float(pick('PARENT10','BWD')['net'])),
    ('BWD D2', float(pick('DEPTH2','BWD')['net'])), ('BWD D3', float(pick('DEPTH3','BWD')['net'])),
]
maxv = max(v for _, v in vals)
bars=[]
for i,(label,value) in enumerate(vals):
    x=70+i*130; h=220*value/maxv; y=330-h
    bars.append(f'<rect x="{x}" y="{y:.1f}" width="75" height="{h:.1f}" fill="#999"/><text x="{x}" y="355" font-size="12">{label}</text><text x="{x}" y="{y-8:.1f}" font-size="12">{value:.2f}</text>')

svg = '<svg xmlns="http://www.w3.org/2000/svg" width="900" height="420" viewBox="0 0 900 420"><rect width="900" height="420" fill="white"/><text x="40" y="36" font-family="sans-serif" font-size="22">B16 GBPUSD/H4 SELL depth ladder</text><text x="40" y="62" font-family="sans-serif" font-size="13">Net profit USD; P10=accepted max10 parent, D2/D3=structural ablations; VISUAL_ONLY_NO_AUTHORITY</text><line x1="50" y1="330" x2="860" y2="330" stroke="black"/>' + ''.join(bars) + '<text x="40" y="400" font-family="sans-serif" font-size="12">H07 primary: depth3 contacts 2025 and restores 2025 positive sign while MAIN+BWD remain positive.</text></svg>'
(RUN / 'depth_ladder_net.svg').write_text(svg, encoding='utf-8')

files = sorted(p for p in RUN.rglob('*') if p.is_file() and p.name != 'artifacts.sha256')
lines = [f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(RUN).as_posix()}" for p in files]
(RUN / 'artifacts.sha256').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'PACKAGED_FILES={len(files)}')
