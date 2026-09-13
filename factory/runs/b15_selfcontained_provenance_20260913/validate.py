"""Read-only, Python-stdlib, package-local B15 validation. No Git or runtime probe.

python -B validate.py --audit
Historical locator strings are never resolved. All evidence reads use Package.read.
The manifest deliberately cannot authenticate itself; candidate Git identity is the
outer trust anchor. Integrity protects against accidental/tampered artifact bytes,
not a hostile replacement of both this program and its entire trust anchor.
"""
import ast
import codecs
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT))
import evidence_parsers as P

# Finish lazy stdlib initialization before the evidence-read audit begins.
P.datetime.strptime('2023.01.01', '%Y.%m.%d')
for _encoding in ('utf-8-sig', 'utf-16', 'utf-16-le', 'utf-16-be'):
    codecs.lookup(_encoding)

SET_SHA = '405956b20848e1d346654c2eb67140a5bb5a1a71386ec44460c88187b84cad52'
EX5_SHA = '2c8ce48431dea995661e149edf064d4b33faec9c883a0eb9e0209625bb7ffa9f'
RECEIPT = 'br-7ee5343c5278419fa6dfafbd3a1db100'
MANIFEST = 'report_package_manifest.json'
VIEWS = ('pf_home_window', 'opportunity_participation', 'pf_vs_participation', 'native_eqdd')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def json_bytes(raw):
    def unique(pairs):
        result = {}
        for k, v in pairs:
            require(k not in result, 'duplicate JSON key: ' + k)
            result[k] = v
        return result
    return json.loads(P.decode(raw), object_pairs_hook=unique,
                      parse_constant=lambda s: (_ for _ in ()).throw(ValueError(s)))


def relative(value):
    require(isinstance(value, str) and value != '', 'empty evidence path')
    require('\\' not in value and ':' not in value and not value.startswith('/'),
            'absolute or nonportable evidence path: ' + value)
    require(all(s not in ('', '.', '..') for s in value.split('/')),
            'traversal/empty path segment: ' + value)
    return value


class Package:
    def __init__(self, root):
        self.root = Path(root).resolve(strict=True)

    def path(self, rel):
        relative(rel)
        path = self.root
        for part in rel.split('/'):
            path = path / part
            require(not path.is_symlink() and not (path.exists() and
                    getattr(path.lstat(), 'st_file_attributes', 0) & 0x400),
                    'reparse evidence path: ' + rel)
        require(path.resolve().is_relative_to(self.root), 'path escapes package')
        return path

    def read(self, rel):
        return self.path(rel).read_bytes()

    def json(self, rel):
        return json_bytes(self.read(rel))

    def ref(self, item):
        raw = self.read(item['path'])
        require(type(item['size_bytes']) is int and len(raw) == item['size_bytes'],
                'size mismatch: ' + item['path'])
        require(P.sha(raw) == item['sha256'], 'hash mismatch: ' + item['path'])
        return raw

    def files(self):
        result = []
        def walk(directory):
            for p in sorted(directory.iterdir()):
                rel = p.relative_to(self.root).as_posix()
                self.path(rel)  # refuse symlinks/junctions before recursion
                if p.is_dir():
                    walk(p)
                else:
                    require(p.is_file(), 'non-file package artifact')
                    result.append(rel)
        walk(self.root)
        return sorted(result)


def inventory(pkg):
    manifest = pkg.json(MANIFEST)
    require(manifest['manifest_version'] == 'EA_LAB_REPORT_PACKAGE_INTEGRITY_V1', 'manifest schema')
    require(manifest['package_id'] == 'b15_selfcontained_provenance_20260913', 'package ID')
    require(manifest['authority'] == 'PACKAGING_ONLY_NO_STRATEGY_AUTHORITY', 'package authority')
    refs = manifest['artifacts']
    paths = [relative(r['path']) for r in refs]
    require(len(paths) == len(set(p.casefold() for p in paths)), 'duplicate inventory path')
    require(MANIFEST not in paths, 'manifest self-hash forbidden')
    require(sorted(paths + [MANIFEST]) == pkg.files(), 'exact package inventory mismatch')
    for r in refs:
        require(bool(r['role']), 'artifact role')
        pkg.ref(r)
    return len(refs)


def check_inputs(set_raw, ini_raw, report_raw):
    declared = P.assignment_map(P.decode(set_raw))
    tester, observed = P.ini_maps(ini_raw)
    reported = P.report_inputs(report_raw)
    P.check_maps(declared, observed, reported)
    return tester, dict(declared_set=declared, observed_tester_inputs=observed,
                        observed_report_inputs=reported,
                        comparison='SET_INI_EXACT; REPORT_NUMERIC_LEXICAL_NORMALIZATION_ONLY')


def native_scan(pkg, rel, raw):
    refs = re.findall(r'<img\b[^>]*\bsrc=[\"\']([^\"\']+)[\"\']', P.decode(raw), re.I)
    expected = sorted(Path(rel).stem + suffix for suffix in
                      ('-holding.png', '-hst.png', '-mfemae.png', '.png'))
    require(len(refs) == 4 and sorted(refs) == expected, 'exact four native references')
    for name in refs:
        require(not pkg.path('raw/' + relative(name)).exists(), 'native image must remain MISSING')
    return dict(assets=[], graph_asset_state='GRAPH ASSET MISSING', image_references_found=4,
                missing=expected, refused=[], report=Path(rel).name, report_sha256=P.sha(raw),
                require_images=True, schema_version='EA_LAB_MT5_NATIVE_ASSET_CLOSURE_V1',
                status='INCOMPLETE', unique_local_images=0)


def static_boundary(pkg):
    """Closed import surface; pure parser has zero filesystem/process/network calls."""
    allowed = {'ast', 'codecs', 'configparser', 'hashlib', 'json', 'os', 'pathlib', 're', 'sys',
               'xml', 'evidence_parsers', 'html', 'math', 'datetime', 'decimal'}
    for name in ('validate.py', 'evidence_parsers.py'):
        tree = ast.parse(pkg.read(name))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                require(all(a.name.split('.')[0] in allowed for a in node.names), 'external import')
            if isinstance(node, ast.ImportFrom):
                require(node.module.split('.')[0] in allowed, 'external import-from')
            if isinstance(node, ast.Call):
                called = node.func.id if isinstance(node.func, ast.Name) else getattr(node.func, 'attr', '')
                require(called not in {'eval', 'exec', '__import__', 'system', 'popen', 'spawn', 'connect'},
                        'dynamic/process/network call')
                if name == 'evidence_parsers.py':
                    require(called not in {'open', 'read_bytes', 'read_text', 'Path'}, 'parser filesystem read')


def validate(root=OUT):
    pkg = Package(root)
    count = inventory(pkg)
    static_boundary(pkg)
    acquisition = pkg.json('provenance_manifest.json')
    acquired = acquisition['artifacts']
    require(len(acquired) == len({r['path'] for r in acquired}), 'duplicate acquisition record')
    for r in acquired:
        require(isinstance(r['source_path'], str) and isinstance(r['acquisition_locator'], str), 'locator strings')
        pkg.ref(r)  # only path, hash and size: never source_path/acquisition_locator
    origins = pkg.json('provenance/raw_origins.json')
    require(len(origins) == 9, 'nine preserved raw B15 artifacts')
    for r in origins:
        pkg.ref(dict(r, path=r['preserved_path']))
    pins = pkg.json('provenance/source_pins.json')
    for key in ('source_manifest', 'build_registry', 'run_identity', 'log_excerpt_origin', 'wrapper'):
        r = pins[key]
        pkg.ref(dict(r, path='provenance/acquired/' + r['path'].rsplit('/', 1)[-1]))
    receipt = pkg.json('provenance/build_receipt_b15.json')
    registry = [json_bytes(line) for line in pkg.read('provenance/acquired/build_receipts.jsonl').splitlines() if line.strip()]
    require([r for r in registry if r['build_receipt'] == RECEIPT] == [receipt], 'unique B15 receipt extraction')
    identity = pkg.json('provenance/acquired/run_identity.json')
    source = pkg.json('provenance/acquired/source_manifest.json')
    require(identity['canonical_source_commit'] == P.SOURCE and identity['B15'] == pins['B15_identity'], 'source identity')
    require(receipt['artifact_sha256'] == identity['B15']['ex5_sha256'].lower() == EX5_SHA, 'EX5 identity')
    require(receipt['build_receipt'] == identity['B15']['build_receipt'] == RECEIPT, 'receipt identity')
    require(P.sha(pkg.read('provenance/acquired/Boss_15_ST03.mq5')) == receipt['source_sha256'] == source['Boss_15_ST03.mq5'].lower(), 'wrapper identity')
    require(P.sha(pkg.read('provenance/acquired/build_receipts.jsonl')) == source['build_receipts'].lower(), 'registry pin')
    require(P.sha(pkg.read('raw/B15_00_SCREEN_GBPUSD_H4.set')) == source['B15_set'].lower() == identity['B15']['set_sha256'].lower() == SET_SHA, 'set pin')
    log = '\n'.join(s for s in P.decode(pkg.read('provenance/acquired/tester_log_extract.txt')).splitlines()
                    if s.startswith('# SOURCE') or 'Boss_15_ST03 (GBPUSD,H4)' in s) + '\n'
    require(log.encode() == pkg.read('provenance/tester_log_b15_excerpt.txt'), 'B15 log extraction')
    obs = pkg.json('ex5_observation.json')
    require(obs['declared_sha256'] == EX5_SHA and obs['historical_loaded_memory'] == 'UNKNOWN', 'EX5 semantics')
    if obs['status'] == 'PACKAGING_TIME_RETAINED_ARTIFACT_MATCH':
        require(obs['observed_sha256'] == P.sha(pkg.read(obs['artifact'])) == EX5_SHA, 'packaged EX5')
    else:
        require(obs['status'] in ('ABSENT', 'MISMATCH', 'UNAVAILABLE') and obs['artifact'] is None, 'EX5 unavailable observation')
        require(obs['observed_sha256'] != EX5_SHA, 'false EX5 mismatch')
    cells = pkg.json('cells.json')
    require(len(cells) == 2 and [c['window'] for c in cells] == ['MAIN', 'BWD'], 'two unique ordered cells')
    historical = pkg.json('historical/cells.json')
    all_missing = []
    for c, old in zip(cells, historical):
        w = c['window']; name = P.expected_tester(w)['Report']
        require(c['cell_id'] == name and c['family'] == 'B15' and c['entry_family'] == 'ST03' and c['variant'] == 'xx-00', 'cell identity')
        require(c['source_sha'] == P.SOURCE and c['build_receipt_id'] == RECEIPT, 'cell source/build')
        require(c['lane'] == 'MT5-lane3' and c['historical_install'] == 'D:\\Meta 5c' and c['historical_device'] == 'BaBoss' and c['model_label'] == 'M1_M1_OHLC_RESEARCH', 'lane identity')
        require(c['original_launch_ini_path'] == 'UNKNOWN', 'launch INI provenance')
        require(c['strategy_status'] == 'NOT_ASSESSED_NO_VERDICT_CHANGE', 'strategy unchanged')
        require(c['mechanical_status'] == old['mechanical_status'], 'mechanical status preservation')
        ev = c['evidence']
        data = {k: pkg.ref(v) for k, v in ev.items()}
        require(c['report'] == ev['report'], 'view report binding')
        require(c['ex5_observation']['path'] == 'ex5_observation.json', 'observation binding')
        pkg.ref(c['ex5_observation'])
        require(ev['tester_ini']['path'] == 'raw/' + name + '.ini' and c['tester_ini_name'] == name + '.ini', 'explicit INI name/path')
        require(ev['report']['path'] == 'raw/' + name + '.htm', 'report path')
        tester, maps = check_inputs(data['set'], data['tester_ini'], data['report'])
        require(c['input_counts'] == dict(set=157, ini=157, report=157), 'serialized 157/157/157')
        require(maps == json_bytes(data['input_maps']), 'input map reconciliation')
        parsed = P.parse_report(data['report'])
        P.check_identity(tester, parsed, w)
        require(tester == c['tester'] == old['tester'], 'tester exact identity')
        require(parsed == c['metrics'] == json_bytes(data['parser_output']) == old['metrics'], 'canonical parser reconciliation')
        headline = tuple(parsed[k] for k in ('profit_factor', 'net_profit', 'total_trades', 'equity_drawdown_maximal_pct'))
        require(headline == {'MAIN': (.28, -357.84, 13, 5.83), 'BWD': (2.12, 137.96, 24, 6.37)}[w], 'headline reconciliation')
        participation, years, deals = P.derive(data['report'], parsed, w)
        require(participation == c['participation'] == json_bytes(data['participation_output']), 'participation reconciliation')
        require(years == json_bytes(data['year_split']) and deals == json_bytes(data['deals'])['rows'], 'years/deals reconciliation')
        lev = json_bytes(data['leverage_sidecar']); trunc = json_bytes(data['truncation_sidecar'])
        require(lev['status'] == 'MATCH' and lev['match'] is True and lev['requested_leverage'] == lev['actual_leverage'] == 100, 'leverage sidecar')
        require(trunc['check_status'] == 'CHECK_PASS' and trunc['truncated'] is False and trunc['checker_exit_code'] == 0, 'truncation sidecar')
        require(lev['report_name'] == trunc['report_name'] == name, 'sidecar identity')
        require(P.WINDOWS[w][0] + ' 00:00:00' in P.decode(data['log_excerpt']), 'cell log selector')
        native = native_scan(pkg, ev['report']['path'], data['report'])
        require(native == json_bytes(data['native_scan']), 'native scan reconciliation')
        require(c['native_graphs']['status'] == 'INCOMPLETE' and c['native_graphs']['references'] == [dict(reference=r, status='MISSING') for r in native['missing']], 'native statuses')
        pkg.ref(c['native_graphs']['asset_scan'])
        all_missing.extend(native['missing'])
    require(len(all_missing) == len(set(all_missing)) == 8, 'eight unique MISSING images')
    for view in VIEWS:
        raw = pkg.read('views/' + view + '.svg')
        ET.fromstring(raw)
        require(raw == P.svg(view, cells).encode(), 'source-bound deterministic R1 view: ' + view)
    return dict(status='PASS', inventory_artifacts=count, raw_artifacts=9, cells=2,
                input_maps='157/157/157 PASS x2', headlines='PASS', parser_year_participation='PASS',
                missing_native_images=8, native_graph_closure='INCOMPLETE', independent_baskets='UNKNOWN',
                independent_episodes='UNKNOWN', ex5=obs['status'], static_external_evidence_check='PASS',
                MT5_runs=0, repair_budget='0/1', strategy_status='UNCHANGED')


def install_read_guard(root):
    """Audit all validation I/O; deny writes, external opens, process/network calls."""
    base = Path(root).resolve()
    observed = []
    def guard(event, args):
        if event == 'open':
            path, mode, flags = args
            require(not isinstance(path, int), 'file descriptor evidence read denied')
            target = Path(os.fsdecode(path)).resolve()
            require(target.is_relative_to(base), 'external evidence read denied: ' + str(target))
            require(not flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND), 'validation write denied')
            observed.append(target.relative_to(base).as_posix())
        if event.startswith(('subprocess.', 'socket.')) or event in ('os.system', 'os.exec', 'os.spawn'):
            raise ValueError('process/network denied: ' + event)
    sys.addaudithook(guard)
    return observed


if __name__ == '__main__':
    try:
        require(sys.argv[1:] in ([], ['--audit']), 'usage: validate.py [--audit]')
        reads = install_read_guard(OUT) if '--audit' in sys.argv else None
        result = validate()
        if reads is not None:
            result['runtime_external_evidence_check'] = 'PASS'
            result['package_relative_files_read'] = sorted(set(reads))
        print(json.dumps(result, indent=2, sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError, StopIteration, configparser.Error) as exc:
        print(json.dumps({'status': 'REFUSE', 'error': str(exc)}))
        sys.exit(2)
