"""Offline contract/evidence completeness seam. Never launches MT5 or grants authority."""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import ntpath
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools' / 'reporting'))
sys.path.insert(0, str(REPO / 'scripts'))
import report_package_integrity as integrity
import mt5_report_assets as assets
import parse_mt5_report as report_parser

SCHEMA = 'research-preflight/1'
SHA = re.compile(r'^[0-9a-f]{64}$')
GIT_SHA = re.compile(r'^[0-9a-f]{40}$')
FIELDS = {'symbol', 'tf', 'leverage', 'model', 'from_date', 'to_date',
          'optimization', 'forward', 'deposit', 'currency', 'expert',
          'installation', 'installation_lineage', 'account_identity', 'lane',
          'report_name', 'tester_report_path', 'launch_ini_path'}
INI_KEYS = {'symbol': 'Symbol', 'tf': 'Period', 'leverage': 'Leverage',
            'model': 'Model', 'from_date': 'FromDate', 'to_date': 'ToDate',
            'optimization': 'Optimization', 'forward': 'ForwardMode',
            'deposit': 'Deposit', 'currency': 'Currency', 'expert': 'Expert', 'report_name': 'Report'}
INPUT_ROLES = {'ini', 'set', 'ex5', 'build_receipt', 'source_manifest', 'identity'}
OUTPUT_ROLES = {'report', 'log', 'year_split', 'metrics', 'truncation'}


class Invalid(ValueError):
    def __init__(self, code):
        self.code = code


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise Invalid('DUPLICATE_JSON_KEY')
        value[key] = item
    return value


def load_json(raw):
    return json.loads(raw.decode('utf-8-sig'), object_pairs_hook=unique,
                      parse_constant=lambda _: (_ for _ in ()).throw(Invalid('NONFINITE_JSON')))


def text(value):
    return isinstance(value, str) and bool(value.strip())


def closed(value, keys, code):
    if not isinstance(value, dict) or set(value) != set(keys):
        raise Invalid(code)


def day(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}\.\d{2}\.\d{2}', value):
        raise Invalid('DATE_FORMAT')
    return date.fromisoformat(value.replace('.', '-'))


def normalized(value):
    if not text(value) or any(p in {'', '.', '..'} for p in value.replace('\\', '/').split('/')):
        raise Invalid('UNSAFE_PATH')
    return integrity._normalize_rel_path(value)


def read_bound(root, record, role):
    closed(record, {'path', 'sha256'}, role.upper() + '_BINDING_MISSING')
    path = normalized(record['path'])
    if not isinstance(record['sha256'], str) or not SHA.fullmatch(record['sha256']):
        raise Invalid(role.upper() + '_HASH_MISSING')
    try:
        absolute = integrity._resolve_artifact(root, path)
    except integrity.Refusal as exc:
        # A path/reparse refusal is never silently treated as optional absence.
        if 'missing:' in str(exc):
            raise Invalid(role.upper() + '_MISSING') from exc
        raise Invalid('UNSAFE_PATH') from exc
    raw = absolute.read_bytes()
    if hashlib.sha256(raw).hexdigest() != record['sha256']:
        raise Invalid(role.upper() + '_HASH_MISMATCH')
    return absolute, raw


def ini_values(raw):
    if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
        decoded = raw.decode('utf-16')
    else:
        decoded = raw.decode('utf-8-sig')
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(decoded)
    if not parser.has_section('Tester') or not parser.has_section('TesterInputs'):
        raise Invalid('INI_SECTIONS_MISSING')
    if parser.defaults() or set(parser.sections()) != {'Tester', 'TesterInputs'}:
        raise Invalid('INI_UNSUPPORTED_SECTIONS')
    if parser['Tester'].get('ExpertParameters', '').strip():
        raise Invalid('INI_EXTERNAL_PARAMETERS_UNSUPPORTED')
    return dict(parser['Tester']), dict(parser['TesterInputs'])


def set_values(raw):
    decoded = raw.decode('utf-16') if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else raw.decode('utf-8-sig')
    values = {}
    for line in decoded.splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if '=' not in line:
            raise Invalid('SET_MALFORMED')
        key, value = line.split('=', 1)
        key = key.strip()
        if not key or key in values:
            raise Invalid('SET_DUPLICATE_PARAMETER')
        values[key] = value.strip()
    return values


def head(repo):
    return subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'],
                                   stderr=subprocess.DEVNULL, text=True).strip()


def inspect(contract, root, actual_head, mode, observation=None, source_reader=None):
    """Trusted Python fixture seam; CLI additionally pins both input files by SHA."""
    issues, records = [], []

    def issue(status, code, cell=None):
        issues.append({'status': status, 'code': code, 'cell_id': cell})

    try:
        closed(contract, {'schema', 'contract_id', 'source_sha', 'source_path', 'hypothesis',
                          'revision', 'parent', 'holdout', 'cells'}, 'CONTRACT_SCHEMA')
        if contract['schema'] != SCHEMA or mode not in {'pre-run', 'post-run'}:
            raise Invalid('CONTRACT_SCHEMA')
        for field in ('contract_id', 'hypothesis', 'revision', 'parent'):
            if not text(contract[field]):
                raise Invalid('CONTRACT_IDENTITY_MISSING')
        if not GIT_SHA.fullmatch(contract['source_sha']):
            raise Invalid('SOURCE_SHA_INVALID')
        if contract['source_sha'] != actual_head:
            raise Invalid('SOURCE_HEAD_MOVED')
        normalized(contract['source_path'])
        closed(contract['holdout'], {'from_date', 'to_date'}, 'HOLDOUT_BOUNDARY_MISSING')
        hs, he = day(contract['holdout']['from_date']), day(contract['holdout']['to_date'])
        if hs > he:
            raise Invalid('DATE_ORDER')
        cells = contract['cells']
        if not isinstance(cells, list) or not cells:
            raise Invalid('CELLS_MISSING')
        seen, outputs, pairs = set(), set(), {}
        if mode == 'post-run':
            closed(observation, {'schema', 'contract_sha256', 'cells'}, 'OBSERVATION_MISSING')
            if observation['schema'] != 'research-preflight-observation/1':
                raise Invalid('OBSERVATION_SCHEMA')
            if not isinstance(observation['cells'], dict) or set(observation['cells']) != {c['cell_id'] for c in cells}:
                raise Invalid('OBSERVATION_CELL_SET')
        for cell in cells:
            cid = cell.get('cell_id') if isinstance(cell, dict) else None
            try:
                closed(cell, {'cell_id', 'pair_id', 'window', 'expected', 'parameters', 'effective_config', 'inputs',
                              'outputs', 'native_graph_required', 'graph_paths', 'end_condition'}, 'CELL_SCHEMA')
                if not text(cid) or not text(cell['pair_id']) or cid.casefold() in seen:
                    raise Invalid('DUPLICATE_CELL_IDENTITY')
                seen.add(cid.casefold())
                if cell['window'] not in {'MAIN', 'BWD'} or type(cell['native_graph_required']) is not bool:
                    raise Invalid('CELL_SCHEMA')
                if cell['end_condition'] != 'FULL_WINDOW':
                    raise Invalid('UNSUPPORTED_END_CONDITION')
                if not isinstance(cell['graph_paths'], list) or not cell['graph_paths']:
                    raise Invalid('GRAPH_OUTPUT_PATHS_MISSING')
                expected = cell['expected']
                closed(expected, FIELDS, 'EXPECTED_IDENTITY_MISSING')
                if not all(text(v) for v in expected.values()):
                    raise Invalid('EXPECTED_IDENTITY_MISSING')
                if not all(ntpath.isabs(expected[k]) for k in ('installation', 'tester_report_path', 'launch_ini_path')):
                    raise Invalid('ABSOLUTE_RUNTIME_PATH_MISSING')
                if expected['model'] not in {'0', '1', '4'}:
                    raise Invalid('NON_RESEARCH_MODEL')
                if expected['optimization'] not in {'0', '1', '2'} or expected['forward'] != '0':
                    raise Invalid('SEARCH_MODE_INVALID')
                if not re.fullmatch(r'1:[1-9]\d*', expected['leverage']):
                    raise Invalid('LEVERAGE_FORMAT')
                start, end = day(expected['from_date']), day(expected['to_date'])
                if start > end:
                    raise Invalid('DATE_ORDER')
                if start <= he and hs <= end:
                    raise Invalid('HOLDOUT_OVERLAP')
                if cell['window'] == 'BWD' and expected['optimization'] != '0':
                    raise Invalid('BWD_OPTIMIZATION')
                if mode == 'post-run' and expected['optimization'] != '0':
                    issue('UNKNOWN', 'OPTIMIZER_XML_POSTRUN_UNSUPPORTED', cid)
                pair = pairs.setdefault(cell['pair_id'], [])
                if any(w == cell['window'] for w, _, _, _, _ in pair):
                    raise Invalid('DUPLICATE_CELL_IDENTITY')
                if pair and any((inst, lineage) != (expected['installation'], expected['installation_lineage'])
                                for _, inst, lineage, _, _ in pair):
                    raise Invalid('CROSS_INSTALL_PAIR')
                if any(start <= oldend and oldstart <= end for _, _, _, oldstart, oldend in pair):
                    raise Invalid('MAIN_BWD_OVERLAP')
                pair.append((cell['window'], expected['installation'], expected['installation_lineage'], start, end))
                if expected['model'] == '4' and (expected['lane'] != 'MT5-lane1' or
                        expected['installation'].replace('/', '\\').rstrip('\\').casefold() != r'd:\meta 5'):
                    raise Invalid('MODEL4_LANE_ILLEGAL')
                closed(cell['inputs'], INPUT_ROLES, 'INPUT_ROLES_MISSING')
                closed(cell['outputs'], OUTPUT_ROLES, 'OUTPUT_ROLES_MISSING')
                blobs = {role: read_bound(root, cell['inputs'][role], role) for role in sorted(INPUT_ROLES)}
                for role, path in cell['outputs'].items():
                    key = normalized(path).casefold()
                    if key in outputs:
                        raise Invalid('DUPLICATE_OUTPUT_IDENTITY')
                    outputs.add(key)
                for path in cell['graph_paths']:
                    key = normalized(path).casefold()
                    if key in outputs:
                        raise Invalid('DUPLICATE_OUTPUT_IDENTITY')
                    outputs.add(key)
                tester, params = ini_values(blobs['ini'][1])
                for field, key in INI_KEYS.items():
                    if key not in tester:
                        raise Invalid('INI_' + field.upper() + '_MISSING')
                    if tester[key] != expected[field]:
                        raise Invalid('INI_' + field.upper() + '_MISMATCH')
                intended = cell['parameters']
                if not isinstance(intended, dict) or not intended or not all(text(k) and text(v) for k,v in intended.items()):
                    raise Invalid('PARAMETER_SURFACE_MISSING')
                setparams = set_values(blobs['set'][1])
                if (set(params) | set(setparams)) - set(intended):
                    raise Invalid('UNKNOWN_PARAMETER')
                if set(params) != set(intended) or set(setparams) != set(intended):
                    raise Invalid('PARAMETER_SURFACE_MISSING')
                if params != setparams or params != intended:
                    raise Invalid('PARAMETER_VALUE_MISMATCH')
                identity = load_json(blobs['identity'][1])
                closed(identity, {'source_sha', 'source_path', 'identity', 'lane_state', 'runtime_legal',
                                  'requested_config', 'effective_config'}, 'IDENTITY_RECEIPT_SCHEMA')
                if identity['source_sha'] != contract['source_sha'] or identity['source_path'] != contract['source_path']:
                    raise Invalid('SOURCE_BINDING_MISMATCH')
                if identity['identity'] != expected:
                    raise Invalid('OBSERVED_IDENTITY_MISMATCH')
                if identity['lane_state'] != 'RUNNING':
                    raise Invalid('LANE_OWNERSHIP_UNPROVEN')
                if identity['runtime_legal'] is not True:
                    issue('UNKNOWN', 'RUNTIME_LEGALITY_UNPROVEN', cid)
                if not isinstance(identity['requested_config'], dict) or not isinstance(identity['effective_config'], dict):
                    raise Invalid('EFFECTIVE_CONFIG_MISSING')
                if identity['requested_config'] != intended:
                    raise Invalid('REQUESTED_CONFIG_MISMATCH')
                if not identity['effective_config']:
                    issue('UNKNOWN', 'EFFECTIVE_CONFIG_UNPROVEN', cid)
                if not isinstance(cell['effective_config'], dict) or not cell['effective_config']:
                    issue('UNKNOWN', 'EFFECTIVE_CONFIG_EXPECTATION_MISSING', cid)
                elif identity['effective_config'] != cell['effective_config']:
                    raise Invalid('EFFECTIVE_CONFIG_MISMATCH')
                receipt = load_json(blobs['build_receipt'][1])
                if receipt.get('schema') != 'build_receipt/1' or not text(receipt.get('build_receipt')):
                    raise Invalid('BUILD_RECEIPT_SCHEMA')
                if receipt.get('artifact_sha256', '').lower() != cell['inputs']['ex5']['sha256']:
                    raise Invalid('BUILD_EX5_MISMATCH')
                source_manifest = load_json(blobs['source_manifest'][1])
                if source_manifest.get('source_sha') != contract['source_sha'] or source_manifest.get('source_path') != contract['source_path']:
                    raise Invalid('SOURCE_MANIFEST_MISMATCH')
                files = source_manifest.get('files')
                if not isinstance(files, dict) or contract['source_path'] not in files:
                    raise Invalid('SOURCE_GRAPH_MISSING')
                if receipt.get('source_sha256', '').lower() != files[contract['source_path']]:
                    raise Invalid('BUILD_SOURCE_MISMATCH')
                if source_reader is None:
                    issue('UNKNOWN', 'SOURCE_GRAPH_UNVERIFIED', cid)
                else:
                    for path, expected_hash in files.items():
                        normalized(path)
                        if not isinstance(expected_hash,str) or not SHA.fullmatch(expected_hash):
                            raise Invalid('SOURCE_GRAPH_HASH_INVALID')
                        if hashlib.sha256(source_reader(contract['source_sha'], path)).hexdigest() != expected_hash:
                            raise Invalid('SOURCE_GRAPH_HASH_MISMATCH')
                record = {'cell_id': cid, 'ini_path': cell['inputs']['ini']['path'],
                          'ini_resolved_path': str(blobs['ini'][0]),
                          'ini_sha256': cell['inputs']['ini']['sha256'], 'identity': expected,
                          'native_graph': 'NOT_RUN'}
                if mode == 'post-run':
                    bound = observation['cells'][cid]
                    closed(bound, OUTPUT_ROLES | {'graphs'}, 'POSTRUN_ROLES_MISSING')
                    post = {}
                    for role in sorted(OUTPUT_ROLES):
                        if bound[role].get('path') != cell['outputs'][role]:
                            raise Invalid(role.upper() + '_PATH_MISMATCH')
                        post[role] = read_bound(root, bound[role], role)
                    metrics = report_parser.parse_report(str(post['report'][0]))
                    supplied_metrics = load_json(post['metrics'][1])
                    for field, key in [('symbol','symbol'),('tf','period'),('leverage','leverage'),
                                       ('from_date','from_date'),('to_date','to_date'),('currency','currency')]:
                        if not metrics.get(key):
                            issue('UNKNOWN', 'REPORT_' + field.upper() + '_UNKNOWN', cid)
                        elif str(metrics[key]) != expected[field]:
                            raise Invalid('REPORT_' + field.upper() + '_MISMATCH')
                        if supplied_metrics.get(key) != metrics.get(key):
                            raise Invalid('METRICS_REPORT_MISMATCH')
                    if metrics.get('ea_name','').replace('\\','/').split('/')[-1] != expected['expert'].replace('\\','/').split('/')[-1]:
                        raise Invalid('REPORT_EXPERT_MISMATCH')
                    if str(metrics.get('initial_deposit')) != str(float(expected['deposit'])):
                        raise Invalid('REPORT_DEPOSIT_MISMATCH')
                    if supplied_metrics != metrics:
                        raise Invalid('METRICS_REPORT_MISMATCH')
                    trunc = load_json(post['truncation'][1])
                    if trunc.get('truncated') is True or trunc.get('check_status') == 'TRUNCATED':
                        raise Invalid('TRUNCATED_RUN')
                    if not (trunc.get('schema_version') == 2 and trunc.get('check_status') == 'CHECK_PASS'
                            and type(trunc.get('checker_exit_code')) is int and trunc['checker_exit_code'] == 0
                            and trunc.get('truncated') is False):
                        issue('UNKNOWN', 'TRUNCATION_UNKNOWN', cid)
                    try:
                        graph = assets.inspect_report(post['report'][0])
                    except assets.AssetRefusal as exc:
                        raise Invalid('UNSAFE_GRAPH') from exc
                    record['native_graph'] = graph['status']
                    if graph['status'] == 'REFUSED':
                        raise Invalid('UNSAFE_GRAPH')
                    if graph['status'] != 'PASS':
                        issue('REFUSE' if cell['native_graph_required'] else 'UNKNOWN', 'MISSING_GRAPH', cid)
                    else:
                        actual_graphs = {str((post['report'][0].parent / a['path']).relative_to(root)).replace('\\','/') for a in graph['assets']}
                        if actual_graphs != set(cell['graph_paths']):
                            raise Invalid('GRAPH_OUTPUT_PATH_MISMATCH')
                        if not isinstance(bound['graphs'], list) or len(bound['graphs']) != len(actual_graphs):
                            raise Invalid('GRAPH_BINDING_MISSING')
                        bound_graphs = set()
                        for graph_record in bound['graphs']:
                            graph_path, _ = read_bound(root, graph_record, 'graph')
                            bound_graphs.add(graph_path.relative_to(root).as_posix())
                        if bound_graphs != actual_graphs:
                            raise Invalid('GRAPH_OUTPUT_PATH_MISMATCH')
                    if not post['log'][1].strip() or not post['year_split'][1].strip():
                        raise Invalid('EMPTY_REQUIRED_OUTPUT')
                records.append(record)
            except Invalid as exc:
                issue('REFUSE', exc.code, cid)
            except (ValueError, OSError, KeyError, TypeError, AttributeError, configparser.Error, integrity.Refusal, subprocess.SubprocessError) as exc:
                issue('REFUSE', 'MALFORMED_OR_UNREADABLE_EVIDENCE', cid)
    except Invalid as exc:
        issue('REFUSE', exc.code)
    except (ValueError, OSError, KeyError, TypeError, AttributeError):
        issue('REFUSE', 'MALFORMED_CONTRACT')
    status = 'REFUSE' if any(x['status'] == 'REFUSE' for x in issues) else 'UNKNOWN' if issues else 'PASS'
    return {'schema': SCHEMA, 'status': status, 'mode': mode, 'authority_granted': False,
            'scope': 'OFFLINE_CONTRACT_CONSISTENCY_ONLY', 'live_lane_eligibility': 'UNKNOWN',
            'issues': issues, 'cells': records}


def pinned(path, expected):
    raw = path.read_bytes()
    if not SHA.fullmatch(expected) or hashlib.sha256(raw).hexdigest() != expected:
        raise Invalid('INPUT_ENVELOPE_HASH_MISMATCH')
    return load_json(raw)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode', choices=['pre-run', 'post-run'])
    p.add_argument('--contract', required=True, type=Path)
    p.add_argument('--contract-sha256', required=True)
    p.add_argument('--source-repo', required=True, type=Path)
    p.add_argument('--artifact-root', required=True, type=Path)
    p.add_argument('--observations', type=Path)
    p.add_argument('--observations-sha256')
    args = p.parse_args()
    try:
        contract = pinned(args.contract, args.contract_sha256)
        observed = None
        if args.mode == 'post-run':
            if not args.observations or not args.observations_sha256:
                raise Invalid('OBSERVATION_MISSING')
            observed = pinned(args.observations, args.observations_sha256)
            if observed.get('contract_sha256') != args.contract_sha256:
                raise Invalid('OBSERVATION_CONTRACT_MISMATCH')
        elif args.observations or args.observations_sha256:
            raise Invalid('UNEXPECTED_OBSERVATION')
        root = args.artifact_root.resolve(strict=True)
        source_reader = lambda ref, path: subprocess.check_output(
            ['git', '-C', str(args.source_repo), 'show', ref + ':' + path], stderr=subprocess.DEVNULL)
        before = head(args.source_repo)
        result = inspect(contract, root, before, args.mode, observed, source_reader)
        if head(args.source_repo) != before:
            raise Invalid('SOURCE_HEAD_MOVED')
    except (Invalid, OSError, ValueError, TypeError, AttributeError, subprocess.SubprocessError) as exc:
        result = {'schema': SCHEMA, 'status': 'REFUSE', 'authority_granted': False,
                  'issues': [{'status':'REFUSE','code':exc.code if isinstance(exc,Invalid) else 'INPUT_UNREADABLE','cell_id':None}]}
    print(json.dumps(result, sort_keys=True, ensure_ascii=True))
    return {'PASS':0,'REFUSE':2,'UNKNOWN':3}[result['status']]


if __name__ == '__main__':
    raise SystemExit(main())
