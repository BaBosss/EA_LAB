"""Focused deterministic cage for R4 Batch A1/A2/A3."""

import csv
import io
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import registry as reg
import activation
import gen_registry_rows as gen_rows
import hypothesis_b14 as hb14
import preset


ROOT = reg.REPO_ROOT

EXPECTED_NEW = {
    19113: '_50_ADX_TrendMin_Exit',
    19114: '_50_RegimeConfirmBars',
    70000: '_EVT_BucketATRmult',
    70001: '_EVT_BucketSeconds',
    70002: '_EVT_PreemptMargin',
    70003: '_EVT_RevengeBlockBars',
    71000: '_HEAT_Enable',
    71001: '_HEAT_MaxClusterLots',
    71002: '_HEAT_MaxPortfolioLots',
    71003: '_HEAT_ClusterCorr',
    71004: '_HEAT_DefaultCorr',
    71005: '_HEAT_UseDynamicCorr',
    71006: '_HEAT_CorrWindowBars',
    72000: 'UseMiddlePathVeto',
    72001: '_MID_LineSource',
    72002: 'MID_LOW',
    72003: 'MID_HIGH',
    72004: 'MIN_CHANNEL_ATR',
    72005: 'MIN_LINE_WEIGHT',
    72006: '_MID_DonchianBars',
    72007: '_MID_PivotDepth',
    72008: '_MID_LineLookbackBars',
    72009: '_MID_MaxLines',
    72010: '_MID_ClusterATRmult',
    72011: '_MID_UseRoomCheck',
    72012: '_MID_MinRR',
}

SMC_KEYS = {
    '_SMC_Enable', '_SMC_SwingLookback', '_SMC_MinImpulseATR',
    '_SMC_OBLookback', '_SMC_FVGMinGapATR', '_SMC_UseFVG',
    '_SMC_UseOrderBlock', '_SMC_RequireLiquiditySweep', '_SMC_MaxAgeBars',
}

R4_ACTIVATION_KEYS = {
    '_50_ADX_TrendMin_Exit', '_50_RegimeConfirmBars',
    '_EVT_BucketATRmult', '_EVT_BucketSeconds', '_EVT_PreemptMargin',
    '_EVT_RevengeBlockBars',
    '_HEAT_Enable', '_HEAT_MaxClusterLots', '_HEAT_MaxPortfolioLots',
    '_HEAT_ClusterCorr', '_HEAT_DefaultCorr', '_HEAT_UseDynamicCorr',
    '_HEAT_CorrWindowBars',
    'UseMiddlePathVeto', '_MID_LineSource', 'MID_LOW', 'MID_HIGH',
    'MIN_CHANNEL_ATR', 'MIN_LINE_WEIGHT', '_MID_DonchianBars',
    '_MID_PivotDepth', '_MID_LineLookbackBars', '_MID_MaxLines',
    '_MID_ClusterATRmult', '_MID_UseRoomCheck', '_MID_MinRR',
}


def check(label, condition, detail=''):
    if not condition:
        raise AssertionError('%s: %s' % (label, detail))
    print('[PASS] ' + label)


def refuses(label, fn):
    try:
        fn()
    except reg.RegistryRefusal:
        print('[PASS] ' + label)
        return
    raise AssertionError(label + ': accepted')


def csv_fixture(rows, headers=None):
    headers = headers or reg.PARAM_REGISTRY_REQUIRED_HEADERS
    out = io.StringIO(newline='')
    writer = csv.writer(out, lineterminator='\n')
    writer.writerow(headers)
    writer.writerows(rows)
    return '> fixture\n' + out.getvalue()


def binding(parameter, pid, role='TUNABLE', classification='ACTIVE'):
    return {
        'entity': 'ParameterBinding',
        'hypothesis_revision': 'B14-H01-r1',
        'parameter': parameter,
        'parameter_pid': pid,
        'build_tag': None,
        'role': role,
        'surface': 'OPERATOR',
        'definition_ref': {
            'entity': 'OwnerRef', 'owner_type': 'param_registry',
            'path': 'docs/PARAM_REGISTRY.csv', 'commit_oid': '0' * 40,
            'blob_oid': '0' * 40, 'raw_sha256': '0' * 64,
        },
        '_classification_fixture': classification,
    }


def write_root(rows, bindings):
    root = tempfile.mkdtemp(prefix='r4_batch_a_')
    os.makedirs(os.path.join(root, 'docs'))
    os.makedirs(os.path.join(root, 'factory'))
    with io.open(os.path.join(root, 'docs', 'PARAM_REGISTRY.csv'), 'w', encoding='utf-8', newline='') as fh:
        fh.write(csv_fixture(rows))
    for rel in reg.STORES:
        path = os.path.join(root, rel.replace('/', os.sep))
        if rel in reg.STORES_BLOCKED:
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with io.open(path, 'w', encoding='utf-8', newline='') as fh:
            if rel == 'factory/parameter_bindings.jsonl':
                fh.write(json.dumps({'_comment': 'fixture'}, sort_keys=True) + '\n')
                for row in bindings:
                    row = dict(row)
                    row.pop('_classification_fixture', None)
                    fh.write(json.dumps(row, sort_keys=True) + '\n')
            else:
                fh.write(json.dumps({'_comment': 'synthetic empty store'}, sort_keys=True) + '\n')
    return root


def main():
    rows = reg.read_parameter_registry(root=ROOT)
    by_name = {row['name']: row for row in rows}
    logical = {reg.bare_registry_name(row['name']) for row in rows}
    pids = {row['parameter_pid'] for row in rows}
    check('A1 logical registry coverage is 196/196', len(logical) == 196, len(logical))
    check('A1 PID coverage is unique 196/196', len(pids) == 196, len(pids))
    check('A1 exact 26 R4 allocations are present',
          {row['parameter_pid']: reg.bare_registry_name(row['name']) for row in rows}
          .items() >= EXPECTED_NEW.items())
    check('A1 nine SMC Module 5A keys remain absent', not (logical & SMC_KEYS))

    check('A4 activation relation vocabulary is closed',
          set(activation.RELATION_KINDS) ==
          {'PARENT', 'GATES', 'REQUIRES', 'COUPLED_WITH', 'SUPERSEDES'})
    revenge = activation.relation_metadata('_EVT_RevengeBlockBars')
    check('A4 revenge remains explicit inactive truth',
          revenge['state'] == 'HIDDEN_INACTIVE' and
          revenge['reason_code'] == 'OUTCOME_LEDGER_NOT_IMPLEMENTED' and
          revenge['effective'] is False)
    for name in ('_EVT_BucketATRmult', '_EVT_BucketSeconds', '_EVT_PreemptMargin'):
        check('A4 %s remains unwired/inactive' % name,
              activation.relation_metadata(name)['state'] == 'HIDDEN_INACTIVE')
    inputs_text = open(os.path.join(ROOT, preset.INPUTS_REL), encoding='utf-8').read()
    surface = preset.parse_surface(inputs_text, 'LAB_ENTRY_14')
    cfg = gen_rows.pinned_config(hb14.HYPOTHESES['B14-H01'], surface)
    # The accepted logical A5 surface excludes legacy SMC/5B declarations that remain in
    # Inputs.mqh for compatibility; activation owns the 196-parameter table domain.
    states = activation.effective_state('LAB_ENTRY_14', cfg)
    check('A4 exact 26 R4 identities have activation metadata',
          R4_ACTIVATION_KEYS <= set(states) and
          all(activation.relation_metadata(name)['name'] == name
              for name in R4_ACTIVATION_KEYS))
    check('A5 effective state keeps revenge ineffective',
          states['_EVT_RevengeBlockBars']['effective'] is False and
          states['_EVT_RevengeBlockBars']['reason_code'] == 'OUTCOME_LEDGER_NOT_IMPLEMENTED')
    check('A5 effective state exposes Heat master gate',
          states['_HEAT_Enable']['state'] == 'ACTIVE' and
          states['_HEAT_MaxClusterLots']['reason_code'] == 'GATE_CLOSED')
    check('A5 effective state exposes MiddlePath master gate',
          states['UseMiddlePathVeto']['state'] == 'ACTIVE' and
          states['_MID_LineSource']['reason_code'] == 'GATE_CLOSED')

    base_headers = list(reg.PARAM_REGISTRY_REQUIRED_HEADERS)
    base_row = ['Alpha', 'owner', 'unit', 'context', 'always', 'none', '1', 'UNKNOWN',
                'UNKNOWN', 'question, with comma', 'ACTIVE', 'quoted "note"', '10123']
    values = dict(zip(base_headers, base_row))
    headers = ['parameter_pid', 'name', 'classification_note'] + [
        h for h in base_headers if h not in ('parameter_pid', 'name', 'classification_note')
    ] + ['future_note']
    row = [values.get(h, 'x') for h in headers]
    parsed = reg.parse_parameter_registry_text(csv_fixture([row], headers=headers), 'fixture')
    check('A2 reordered/appended CSV headers parse by name', parsed[0]['parameter_pid'] == 10123)
    missing_headers = [h for h in headers if h != 'classification_note']
    missing_row = [values.get(h, 'x') for h in missing_headers]
    refuses('A2 missing required header refuses', lambda: reg.parse_parameter_registry_text(
        csv_fixture([missing_row], headers=missing_headers), 'missing'))
    duplicate = list(reg.PARAM_REGISTRY_REQUIRED_HEADERS) + ['parameter_pid']
    refuses('A2 duplicate required header refuses', lambda: reg.parse_parameter_registry_text(
        csv_fixture([[values[h] for h in reg.PARAM_REGISTRY_REQUIRED_HEADERS]], headers=duplicate),
        'duplicate'))
    malformed = '> fixture\n' + ','.join(reg.PARAM_REGISTRY_REQUIRED_HEADERS) + '\n"Alpha,"broken\n'
    refuses('A2 malformed CSV row refuses', lambda: reg.parse_parameter_registry_text(malformed, 'malformed'))

    rows = [['Alpha', 'owner', 'unit', 'context', 'always', 'none', '1', 'UNKNOWN',
             'UNKNOWN', 'question', 'ACTIVE', '', '10123'],
            ['Retired', 'owner', 'unit', 'context', 'never', 'none', '0', 'UNKNOWN',
             'UNKNOWN', 'retired', 'INACTIVE', 'retired identity', '10124']]
    root = write_root(rows, [binding('Alpha', 10123), binding('Retired', 10124)])
    try:
        check('A3 PID-only resolves exact binding',
              reg.resolve('B14-H01-r1', parameter_pid=10123, root=root)['parameter'] == 'Alpha')
        check('A3 name-only resolves exact binding',
              reg.resolve('B14-H01-r1', parameter='Alpha', root=root)['parameter_pid'] == 10123)
        check('A3 agreeing PID+name resolves',
              reg.resolve('B14-H01-r1', parameter='Alpha', parameter_pid=10123, root=root)['source'] == 'BOUND')
        refuses('A3 disagreeing PID+name refuses', lambda: reg.resolve(
            'B14-H01-r1', parameter='Alpha', parameter_pid=10124, root=root))
        refuses('A3 unknown PID refuses', lambda: reg.resolve(
            'B14-H01-r1', parameter_pid=999, root=root))
        refuses('A3 unknown name refuses', lambda: reg.resolve(
            'B14-H01-r1', parameter='Missing', root=root))
        retired = reg.resolve('B14-H01-r1', parameter='Retired', root=root)
        check('A3 inactive identity never resolves optimizable', retired['optimizable'] is False)
        duplicate = write_root(rows, [binding('Alpha', 10123), binding('Retired', 10123)])
        try:
            refuses('A3 duplicate PID refuses', lambda: reg.resolve(
                'B14-H01-r1', parameter_pid=10123, root=duplicate))
        finally:
            shutil.rmtree(duplicate, ignore_errors=True)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    print('BATCH A TESTS: PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
