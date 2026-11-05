#!/usr/bin/env python3
"""Cage for scripts/recipe_check.py (V1-V8, A1-A9). Self-contained: builds a temp factory root."""
import copy
import datetime as _dt
import json
import re
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
sys.path.insert(0, os.path.join(REPO, '_triage', 'factory_os'))
import recipe_check as rc  # noqa: E402
import optimize_log  # noqa: E402

RESULTS = []


def check(name, cond, detail=''):
    RESULTS.append(bool(cond))
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else '  -- ' + str(detail)))


def jl(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')


def make_root(escalation=False):
    root = tempfile.mkdtemp(prefix='recipe_check_')
    f = os.path.join(root, 'factory')
    jl(os.path.join(f, 'parameter_bindings.jsonl'), [
        {'_comment': 'fixture'},
        {'hypothesis_revision': 'B99-H01-r1', 'parameter': 'ExitMode', 'role': 'LOCKED', 'locked_value': '22', 'surface': 'HIDDEN'},
        {'hypothesis_revision': 'B99-H01-r1', 'parameter': '_99_Len', 'role': 'TUNABLE', 'locked_value': None, 'surface': 'OPERATOR'},
        {'hypothesis_revision': 'B99-H01-r1', 'parameter': '_99_Safety', 'role': 'SAFETY', 'locked_value': '25', 'surface': 'OPERATOR'},
    ])
    token = 'LAB_CAP_ENTRY_GRIDLOG' if escalation else 'LAB_CAP_ENTRY_MACD'
    jl(os.path.join(f, 'hypotheses.jsonl'), [
        {'_comment': 'fixture'},
        {'hypothesis_id': 'B99-H01', 'module_set': [{'token': 'LAB_CAP_CORE'}, {'token': token}]},
    ])
    vals = {'spec_digits': 5, 'spec_point': 0.00001, 'spec_tick_value': 1.0, 'spec_contract_size': 100000.0}
    vh = rc.hashlib.sha256(json.dumps(vals, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()
    jl(os.path.join(f, 'instrument_profiles.jsonl'), [
        {'_comment': 'fixture'},
        {'entity': 'InstrumentProfile', 'profile_id': 'GBPUSD_L1', 'profile_version': 1, 'content_hash': vh,
         'layer': 'BROKER_LANE', 'symbol': 'GBPUSD', 'lane': '1', 'values': vals},
    ])
    with open(os.path.join(root, 'ea.ex5'), 'wb') as fh:
        fh.write(b'EX5')
    with open(os.path.join(root, 'report.htm'), 'w') as fh:
        fh.write('report')
    with open(os.path.join(root, 'run.set'), 'w') as fh:
        fh.write('; full set\nExitMode=22\n_99_Len=14\n_99_Safety=25\n')
    return root


def base_recipe(root):
    prof = os.path.join(root, 'factory', 'instrument_profiles.jsonl')
    fac = os.path.join(root, 'factory')
    return {
        'entity': 'OptimizeRecipe', 'recipe_id': 'B99-H01-r1',
        'hypothesis_ref': {'key': 'B99-H01-r1', 'path': 'factory/hypotheses.jsonl',
                           'raw_sha256': rc.sha256_file(os.path.join(fac, 'hypotheses.jsonl'))},
        'class': 'trend', 'class_derivation': 'MACD crossover entry, no grid/lot progression',
        'ea': {'expert': 'EALabTpl\\Boss_99_Test'},
        'symbols': ['GBPUSD'], 'timeframes': ['H1'],
        'symbol_preset_refs': [{'symbol': 'GBPUSD', 'lane': '1', 'path': 'factory/instrument_profiles.jsonl', 'raw_sha256': rc.sha256_file(prof)}],
        'windows': {'MAIN': ['2023.01.01', '2025.12.31'], 'BWD': ['2020.01.01', '2022.12.31'],
                    'HOLDOUT': ['2026.01.01', '2026.06.30']},
        'stages': [
            {'stage': 'SMOKE', 'model': 1, 'window': 'MAIN', 'gate': {'pf_min': 1.0}},
            {'stage': 'COARSE', 'model': 1, 'window': 'MAIN', 'sweep': [{'parameter': '_99_Len', 'from': 8, 'to': 20, 'step': 2}]},
            {'stage': 'FREEZE'},
            {'stage': 'BOTH_WINDOW', 'model': 1, 'windows': ['MAIN', 'BWD']},
            {'stage': 'MODEL4', 'model': 4, 'windows': ['MAIN', 'BWD']},
            {'stage': 'HOLDOUT', 'model': 4, 'window': 'HOLDOUT'},
        ],
        'bindings_ref': {'hypothesis_revision': 'B99-H01-r1', 'path': 'factory/parameter_bindings.jsonl',
                         'raw_sha256': rc.sha256_file(os.path.join(fac, 'parameter_bindings.jsonl'))},
        'score': {'formula_id': 'R15_F5_v1', 'formula_sha256': rc.SCORE_FORMULA_SHA256, 'dd_cap_equity_pct': 12.0},
        'plateau_rule': {'id': 'R14-smoothed', 'text': 'neighbour-smoothed centre'},
        'tie_breaks': ['higher BWD PF'], 'extra_round': None,
        'frozen_utc': '2026-11-04T00:00:00Z', 'frozen_by': 'claude',
    }


def write_recipe(root, recipe):
    p = os.path.join(root, 'factory', 'recipes', 'B99-H01-r1.json')
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(recipe, f)
    return p


def rep(**kw):
    r = {'symbol': 'GBPUSD', 'period': 'H1', 'from_date': '2023.01.01', 'to_date': '2025.12.31',
         'history_quality': '100%', 'leverage': '1:100', 'initial_deposit': 10000, 'currency': 'USD',
         'report_build': 6230, 'equity_drawdown_relative_pct': 4.0, 'total_trades': 120,
         'net_profit': 500.0, 'profit_factor': 1.3, 'recovery_factor': 2.0}
    r.update(kw)
    return r


def write_ini(path, set_path, tester=None):
    """A launch .ini whose [TesterInputs] are exactly the given .set (what mt5_run/mt5_optimize write)."""
    t = {'Expert': 'EALabTpl\\Boss_99_Test', 'Symbol': 'GBPUSD', 'Period': 'H1', 'Model': '1', 'Optimization': '0',
         'FromDate': '2023.01.01', 'ToDate': '2025.12.31', 'Leverage': '1:100', 'Deposit': '10000'}
    t.update(tester or {})
    body = ['[Tester]'] + ['%s=%s' % kv for kv in t.items()] + ['[TesterInputs]']
    with open(set_path) as fh:
        body += [l.strip() for l in fh if l.strip() and not l.lstrip().startswith(';')]
    with open(path, 'w') as fh:
        fh.write('\n'.join(body) + '\n')
    return path


def run(root, recipe_path, stage, window, report=None, raises=None, write=True, set_path=None, ini_path=None):
    def reader(_):
        if raises:
            raise raises
        return report or rep()
    sp = set_path or os.path.join(root, 'run.set')
    ip = ini_path or write_ini(os.path.join(root, 'run_%s_%s.ini' % (stage, window)), sp)
    r = rc.accept(recipe_path, stage, window, os.path.join(root, 'report.htm'),
                  sp, os.path.join(root, 'ea.ex5'),
                  root, 'MT5-TEST', ini_path=ip, read_report=reader)
    if write:
        rc.append_jsonl(os.path.join(root, rc.RECEIPTS_REL), r)
    return r


def has(refusals, prefix):
    return any(x.startswith(prefix) for x in refusals)


def main():
    # ---- unit pieces
    check('confidence letters', [rc.confidence(n) for n in (100, 99, 50, 49, 20, 19)] == ['A', 'B', 'B', 'C', 'C', 'D'])
    check('F5 = RF x confidence', rc.score_f5(2.0, 5.0, 60, 12.0) == 1.5)
    check('F5 excludes DD above cap', rc.score_f5(2.0, 12.01, 200, 12.0) is None)
    check('F5 confidence D scores 0', rc.score_f5(3.0, 1.0, 10, 12.0) == 0.0)

    # ---- V rules
    root = make_root()
    good = base_recipe(root)
    check('V valid recipe has no refusals', rc.validate_recipe(good, root) == [], rc.validate_recipe(good, root))
    cases = [
        ('V1 SAFETY parameter swept', lambda r: r['stages'][1]['sweep'].append({'parameter': '_99_Safety', 'from': 1, 'to': 2, 'step': 1}), 'V1'),
        ('V1 unbound parameter swept', lambda r: r['stages'][1]['sweep'].append({'parameter': '_99_Nope', 'from': 1, 'to': 2, 'step': 1}), 'V1'),
        ('V2 wrong score formula', lambda r: r['score'].update(formula_id='F3_sharpe'), 'V2'),
        ('V2 not frozen', lambda r: r.update(frozen_utc=None), 'V2'),
        ('V3 MAIN overlaps HOLDOUT', lambda r: r['windows'].update(MAIN=['2023.07.01', '2026.03.31']), 'V3'),
        ('V4 hand-picked escalation without modules', lambda r: r.update({'class': 'escalation'}), 'V4'),
        ('V5 self-approved extra round', lambda r: r.update(extra_round={'reason': 'x', 'lever': 'y', 'approved_by': 'claude', 'approved_utc': 'z'}), 'V5'),
        ('V6 symbol without profile', lambda r: r['symbols'].append('XAUUSD'), 'V6'),
        ('V6 tampered profile hash', lambda r: r['symbol_preset_refs'][0].update(raw_sha256='0' * 64), 'V6'),
        ('V7 no MODEL4', lambda r: r.update(stages=[s for s in r['stages'] if s['stage'] != 'MODEL4']), 'V7'),
        ('V7 MODEL4 not covering BWD', lambda r: r['stages'][4].update(windows=['MAIN']), 'V7'),
        ('V8 DD cap looser than 12', lambda r: r['score'].update(dd_cap_equity_pct=15.0), 'V8'),
        ('V2 score formula hash missing', lambda r: r['score'].pop('formula_sha256'), 'V2'),
        ('V2 null tie-break entry', lambda r: r.update(tie_breaks=[None]), 'V2'),
        ('V2 bindings store not pinned', lambda r: r['bindings_ref'].pop('raw_sha256'), 'V2'),
        ('V2 runnable stage without a window', lambda r: r['stages'][0].pop('window'), 'V2'),
        ('V2 stage names an unknown window', lambda r: r['stages'][0].update(window='RECENT'), 'V2'),
        ('V4 non-escalation class without derivation', lambda r: r.update(class_derivation=''), 'V4'),
        ('V6 preset ref without hash', lambda r: r['symbol_preset_refs'][0].pop('raw_sha256'), 'V6'),
        ('V6 preset ref without lane', lambda r: r['symbol_preset_refs'][0].pop('lane'), 'V6'),
        ('V6 preset ref on a lane with no profile', lambda r: r['symbol_preset_refs'][0].update(lane='5b'), 'V6'),
        ('V7 MODEL4 windows MAIN+HOLDOUT (no BWD)', lambda r: r['stages'][4].update(windows=['MAIN', 'HOLDOUT']), 'V7'),
        ('V8 NaN DD cap', lambda r: r['score'].update(dd_cap_equity_pct='NaN'), 'V8'),
        ('V8 infinite DD cap', lambda r: r['score'].update(dd_cap_equity_pct=float('inf')), 'V8'),
        ('V2 nested null in plateau_rule', lambda r: r['plateau_rule'].update(decided_with_owner=None), 'V2'),
        ('V2 deeply nested null in plateau_rule', lambda r: r['plateau_rule'].update(metadata={'decided_with_owner': None}), 'V2'),
        ('V8 DD cap given as text', lambda r: r['score'].update(dd_cap_equity_pct='12'), 'V8'),
        ('V10 SMOKE without a gate', lambda r: r['stages'][0].pop('gate'), 'V10'),
        ('V10 SMOKE gate below 1.0', lambda r: r['stages'][0].update(gate={'pf_min': 0.9}), 'V10'),
        ('V10 unknown gate key', lambda r: r['stages'][0].update(gate={'pf_min': 1.0, 'sharpe_min': 1}), 'V10'),
        ('V10 gate value as text', lambda r: r['stages'][0].update(gate={'pf_min': '1.2'}), 'V10'),
        ('V10 gate on FREEZE', lambda r: r['stages'][2].update(gate={'pf_min': 1.0}), 'V10'),
    ]
    for name, mut, prefix in cases:
        r = copy.deepcopy(good)
        mut(r)
        out = rc.validate_recipe(r, root)
        check(name, has(out, prefix), out)
    # pinned stores: editing bindings after freezing refuses an unchanged recipe
    proot = make_root()
    prec = base_recipe(proot)
    with open(os.path.join(proot, 'factory', 'parameter_bindings.jsonl'), 'a') as fh:
        fh.write(json.dumps({'hypothesis_revision': 'B99-H01-r1', 'parameter': '_99_Safety', 'role': 'TUNABLE'}) + '\n')
    out = rc.validate_recipe(prec, proot)
    check('V2 bindings edited after freezing refuse', has(out, 'V2 bindings_ref pin differs'), out)
    shutil.rmtree(proot)
    # V6: a profile whose values no longer match its content_hash refuses
    hroot = make_root()
    pp = os.path.join(hroot, 'factory', 'instrument_profiles.jsonl')
    prow = rc.read_jsonl(pp)
    prow[0]['values']['spec_digits'] = 4
    jl(pp, prow)
    out = rc.validate_recipe(base_recipe(hroot), hroot)
    check('V6 profile values edited without re-hashing refuse', has(out, 'V6 GBPUSD profile content_hash'), out)
    shutil.rmtree(hroot)
    eroot = make_root(escalation=True)
    er = base_recipe(eroot)
    out = rc.validate_recipe(er, eroot)
    check('V4 grid module forces escalation', has(out, 'V4'), out)
    er['class'] = 'escalation'
    check('V4 escalation recipe with grid module is valid', rc.validate_recipe(er, eroot) == [], rc.validate_recipe(er, eroot))
    shutil.rmtree(eroot)

    # ---- A rules
    rp = write_recipe(root, good)
    r = run(root, rp, 'SMOKE', 'MAIN')
    check('A SMOKE accepted', r['result'] == 'ACCEPT', r['refusals'])
    check('A receipt carries F5 score and confidence', r['metrics']['score'] == 2.0 and r['evidence_confidence'] == 'A', r['metrics'])
    check('A receipt hashes read from files', r['binary']['raw_sha256'] == rc.sha256_file(os.path.join(root, 'ea.ex5')))
    r = run(root, rp, 'BOTH_WINDOW', 'MAIN', write=False)
    check('A2 BOTH_WINDOW refused while COARSE has no receipt', has(r['refusals'], 'A2 earlier stage COARSE'), r['refusals'])
    r = run(root, rp, 'COARSE', 'MAIN', write=False)
    check('COARSE through the single-run fixture refuses (not a grid run, no preflight)', has(r['refusals'], 'A2 ini Optimization=0') and has(r['refusals'], 'A3'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'BWD', write=False)
    check('A2 window not in stage', has(r['refusals'], 'A2 window BWD'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(symbol='EURUSD'), write=False)
    check('A2 wrong symbol', has(r['refusals'], 'A2 report symbol'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(to_date='2026.03.31'), write=False)
    check('A2 report window differs from recipe', has(r['refusals'], 'A2 report window'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(history_quality='99% real ticks'), write=False)
    check('A2 model mismatch (real ticks on a model-1 stage)', has(r['refusals'], 'A2 stage wants model'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(leverage='100'), write=False)
    check('A5 leverage not asserted', has(r['refusals'], 'A5'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(equity_drawdown_relative_pct=12.5), write=False)
    check('A6 DD above cap', has(r['refusals'], 'A6') and r['metrics']['score'] is None, r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', raises=ValueError('truncated'), write=False)
    check('A9 unreadable report refuses', has(r['refusals'], 'A9 report unreadable') and r['result'] == 'REFUSE', r['refusals'])
    bad_set = os.path.join(root, 'bad.set')
    with open(bad_set, 'w') as fh:
        fh.write('ExitMode=21\n_99_Len=14||8||2||20||Y\n_99_Safety=25\n')
    r = run(root, rp, 'SMOKE', 'MAIN', set_path=bad_set, write=False)
    check('A4 locked value changed', any('ExitMode=21' in x for x in r['refusals']), r['refusals'])
    check('A4 swept parameter in a single run', any('_99_Len is swept' in x for x in r['refusals']), r['refusals'])
    safety_set = os.path.join(root, 'safety.set')
    with open(safety_set, 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14\n_99_Safety=250\n')
    r = run(root, rp, 'SMOKE', 'MAIN', set_path=safety_set, write=False)
    check('A4 SAFETY value changed without a sweep', any('_99_Safety=250' in x for x in r['refusals']), r['refusals'])
    unb_set = os.path.join(root, 'unbound.set')
    with open(unb_set, 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14\n_99_Safety=25\nUnbound=1||0||1||2||Y\n')
    r = run(root, rp, 'SMOKE', 'MAIN', set_path=unb_set, write=False)
    check('A4 unbound swept input in a single run', any('Unbound is swept' in x for x in r['refusals']), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', report=rep(equity_drawdown_relative_pct=float('nan')), write=False)
    check('A6/A9 NaN equity DD refuses', r['result'] == 'REFUSE' and has(r['refusals'], 'A9 equity drawdown'), r['refusals'])
    other_ini = write_ini(os.path.join(root, 'other_single.ini'), bad_set)
    r = run(root, rp, 'SMOKE', 'MAIN', ini_path=other_ini, write=False)
    check('A4 single run whose launch ini inputs differ from --set refuses', has(r['refusals'], 'A4 --set differs from the launch ini'), r['refusals'])
    r = run(root, rp, 'SMOKE', 'MAIN', ini_path=os.path.join(root, 'nope.ini'), write=False)
    check('A9 single run without a launch ini refuses', has(r['refusals'], 'A9 cannot read ini'), r['refusals'])
    short_set = os.path.join(root, 'short.set')
    with open(short_set, 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14\n')
    r = run(root, rp, 'SMOKE', 'MAIN', set_path=short_set, write=False)
    check('A5 set omits a bound operator input', has(r['refusals'], 'A5 set omits'), r['refusals'])

    # A2: a REFUSE receipt never satisfies a prerequisite
    # (BOTH_WINDOW reads a report, so the prerequisite lookup runs on a known symbol/timeframe.)
    r2 = make_root()
    rec2 = base_recipe(r2)
    rec2['stages'] = [s for s in rec2['stages'] if s['stage'] != 'COARSE']
    rp2 = write_recipe(r2, rec2)
    run(r2, rp2, 'SMOKE', 'MAIN', report=rep(equity_drawdown_relative_pct=30.0))
    r = run(r2, rp2, 'BOTH_WINDOW', 'MAIN', write=False)
    check('A2 REFUSE receipt does not count as the earlier stage', has(r['refusals'], 'A2 earlier stage SMOKE'), r['refusals'])
    run(r2, rp2, 'SMOKE', 'MAIN')
    r = run(r2, rp2, 'BOTH_WINDOW', 'MAIN', write=False)
    check('A2 an ACCEPT receipt does satisfy the earlier stage', r['result'] == 'ACCEPT', r['refusals'])
    shutil.rmtree(r2)
    # V10/A2: a conforming SMOKE that fails its PF gate is ACCEPTed but blocks the next stage
    r2 = make_root()
    rec2 = base_recipe(r2)
    rec2['stages'] = [s for s in rec2['stages'] if s['stage'] != 'COARSE']
    rp2 = write_recipe(r2, rec2)
    sm = run(r2, rp2, 'SMOKE', 'MAIN', report=rep(profit_factor=0.8))
    check('gate: conforming SMOKE with PF 0.8 is ACCEPT with gate_passed False', sm['result'] == 'ACCEPT' and sm.get('gate_passed') is False, sm)
    r = run(r2, rp2, 'BOTH_WINDOW', 'MAIN', write=False)
    check('gate: a failed SMOKE gate blocks BOTH_WINDOW', has(r['refusals'], 'A2 earlier stage SMOKE/MAIN failed its gate'), r['refusals'])
    run(r2, rp2, 'SMOKE', 'MAIN', report=rep(profit_factor=1.05))
    r = run(r2, rp2, 'BOTH_WINDOW', 'MAIN', write=False)
    check('gate: a later passing SMOKE unblocks BOTH_WINDOW', r['result'] == 'ACCEPT', r['refusals'])
    shutil.rmtree(r2)

    # A8 holdout spent by its first receipt (with stage prerequisites forced via fake ACCEPT rows)
    r3 = make_root()
    rec3 = base_recipe(r3)
    rec3['stages'] = [s for s in rec3['stages'] if s['stage'] not in ('COARSE', 'SMOKE', 'BOTH_WINDOW')]
    rp3 = write_recipe(r3, rec3)
    for wn in ('MAIN', 'BWD'):
        run(r3, rp3, 'MODEL4', wn, report=rep(history_quality='99% real ticks',
            from_date=rec3['windows'][wn][0], to_date=rec3['windows'][wn][1]))
    hrep = rep(history_quality='99% real ticks', from_date='2026.01.01', to_date='2026.06.30')
    first = run(r3, rp3, 'HOLDOUT', 'HOLDOUT', report=hrep)
    second = run(r3, rp3, 'HOLDOUT', 'HOLDOUT', report=hrep, write=False)
    check('A8 first holdout accepted', first['result'] == 'ACCEPT', first['refusals'])
    check('A8 second holdout refused', has(second['refusals'], 'A8'), second['refusals'])
    shutil.rmtree(r3)

    # A7 escalation always refuses until the basket log exists
    r4 = make_root(escalation=True)
    rec4 = base_recipe(r4)
    rec4['class'] = 'escalation'
    rp4 = write_recipe(r4, rec4)
    r = run(r4, rp4, 'SMOKE', 'MAIN', write=False)
    check('A7 escalation refused without basket log', has(r['refusals'], 'A7'), r['refusals'])
    # refusal row is readable by the existing decision-log reader
    row = rc.refusal_decision_row(r)
    try:
        parsed = optimize_log.parse(json.dumps(row))
        check('refusal row parses under optimize_log record_version 1', parsed and parsed[0]['result'] == 'REFUSE')
    except Exception as exc:  # noqa: BLE001
        check('refusal row parses under optimize_log record_version 1', False, exc)
    shutil.rmtree(r4)

    # SAFETY without a bound value: the recipe must freeze it, and the set must match
    sroot = make_root()
    bp = os.path.join(sroot, 'factory', 'parameter_bindings.jsonl')
    rows = rc.read_jsonl(bp)
    for b in rows:
        if b['parameter'] == '_99_Safety':
            b['locked_value'] = None
    jl(bp, rows)
    srec = base_recipe(sroot)
    out = rc.validate_recipe(srec, sroot)
    check('V9 SAFETY without bound value needs fixed_inputs', has(out, 'V9 SAFETY input _99_Safety'), out)
    srec['fixed_inputs'] = {'_99_Safety': '25'}
    check('V9 fixed_inputs satisfies the SAFETY freeze', rc.validate_recipe(srec, sroot) == [], rc.validate_recipe(srec, sroot))
    srp = write_recipe(sroot, srec)
    with open(os.path.join(sroot, 'run.set'), 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14\n_99_Safety=250\n')
    r = run(sroot, srp, 'SMOKE', 'MAIN', write=False)
    check('A4 SAFETY value differs from the recipe freeze', any('_99_Safety=250' in x for x in r['refusals']), r['refusals'])
    shutil.rmtree(sroot)

    # --write: an unwritable receipts store must not lose the decision-log refusal
    wroot = make_root()
    wrp = write_recipe(wroot, base_recipe(wroot))
    os.makedirs(os.path.join(wroot, rc.RECEIPTS_REL))
    with open(os.path.join(wroot, 'factory', 'optimize_decisions.jsonl'), 'w') as fh:
        fh.write('')
    rc_code = rc.main(['--root', wroot, 'accept', '--recipe', wrp, '--stage', 'SMOKE', '--window', 'MAIN',
                       '--report', os.path.join(wroot, 'missing.htm'), '--set', os.path.join(wroot, 'run.set'),
                       '--binary', os.path.join(wroot, 'ea.ex5'), '--lane', 'MT5-TEST', '--write'])
    dec_rows = rc.read_jsonl(os.path.join(wroot, 'factory', 'optimize_decisions.jsonl'))
    check('--write keeps the decision-log refusal when the receipt store fails', rc_code == 2 and len(dec_rows) == 1 and dec_rows[0]['result'] == 'REFUSE', (rc_code, dec_rows))
    shutil.rmtree(wroot)

    # A9 an unreadable receipts store still yields a REFUSE receipt (never an exception)
    r5 = make_root()
    rp5 = write_recipe(r5, base_recipe(r5))
    os.makedirs(os.path.join(r5, rc.RECEIPTS_REL))  # a directory where the file should be
    try:
        r = run(r5, rp5, 'SMOKE', 'MAIN', write=False)
        check('A9 unreadable receipts store refuses instead of raising', r['result'] == 'REFUSE' and has(r['refusals'], 'A9'), r['refusals'])
    except Exception as exc:  # noqa: BLE001
        check('A9 unreadable receipts store refuses instead of raising', False, exc)
    shutil.rmtree(r5)

    # ---- optimize stages (COARSE): ini + set sweep + full-grid XML + preflight join
    CREATED_LOCAL = '2026-11-05T12:00:00Z'          # what MT5 writes: terminal-local time with a 'Z'
    CREATED_UTC = rc.created_local_to_utc(CREATED_LOCAL)
    BEFORE = (_dt.datetime.strptime(CREATED_UTC, '%Y-%m-%dT%H:%M:%SZ') - _dt.timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ')
    AFTER = (_dt.datetime.strptime(CREATED_UTC, '%Y-%m-%dT%H:%M:%SZ') + _dt.timedelta(minutes=1)).strftime('%Y-%m-%dT%H:%M:%SZ')

    def opt_root(preflight=True, warn_only=False, submitted=None, dims=('_99_Len',)):
        submitted = BEFORE if submitted is None else submitted
        o = make_root()
        orec = base_recipe(o)
        orp = write_recipe(o, orec)
        run(o, orp, 'SMOKE', 'MAIN')  # prerequisite
        with open(os.path.join(o, 'opt.set'), 'w') as fh:
            fh.write('ExitMode=22\n_99_Len=14||8||2||20||Y\n_99_Safety=25\n')
        write_ini(os.path.join(o, 'opt.ini'), os.path.join(o, 'opt.set'), {'Optimization': '1'})
        with open(os.path.join(o, 'opt.xml'), 'w') as fh:
            fh.write('<Title>Boss_99_Test GBPUSD,H1 2023.01.01-2025.12.31</Title><Created>%s</Created>' % CREATED_LOCAL)
        if preflight:
            jl(os.path.join(o, 'factory', 'optimize_decisions.jsonl'), [{
                'record_version': 1, 'submitted_utc': submitted, 'lane': 'L', 'hypothesis_revision': 'B99-H01-r1',
                'result': 'ALLOW', 'checked': len(dims), 'allow_count': len(dims), 'refuse_count': 0,
                'dimensions': [{'name': d, 'verdict': 'ALLOW', 'facts': []} for d in dims], 'exit_code': 0,
                'warn_only': warn_only, 'expert': 'EALabTpl\\Boss_99_Test', 'ini_path': 'C:\\tmp\\x.ini'}])
        return o, orp

    def full_passes(values=(8, 10, 12, 14, 16, 18, 20)):
        return {'passes': [{'pass_id': i, '_99_Len': v, 'max_drawdown_percent': 3.0} for i, v in enumerate(values)]}

    def opt(o, orp, xml=None, ini=None, set_name='opt.set', bind=True):
        sp = os.path.join(o, set_name)
        ip = ini or (write_ini(os.path.join(o, 'opt_%s.ini' % set_name), sp, {'Optimization': '1'}) if bind and set_name != 'opt.set'
                     else os.path.join(o, 'opt.ini'))
        return rc.accept(orp, 'COARSE', 'MAIN', os.path.join(o, 'opt.xml'), sp,
                         os.path.join(o, 'ea.ex5'), o, 'MT5-TEST', ini_path=ip,
                         read_xml=lambda _p: xml if xml is not None else full_passes())

    o, orp = opt_root()
    r = opt(o, orp)
    check('COARSE full grid with enforcing preflight is ACCEPT', r['result'] == 'ACCEPT', r['refusals'])
    check('COARSE receipt records pass count and grid', r['metrics'].get('pass_count') == 7 and r['metrics'].get('grid_points') == 7, r['metrics'])
    r = opt(o, orp, xml=full_passes((8, 10, 12, 14, 16, 18)))
    check('COARSE missing grid point refuses', has(r['refusals'], 'A2 optimizer XML has 6 passes'), r['refusals'])
    r = opt(o, orp, xml=full_passes((8, 10, 12, 14, 16, 18, 18)))
    check('COARSE repeated grid point refuses', has(r['refusals'], 'A2 optimizer XML repeats'), r['refusals'])
    r = opt(o, orp, xml=full_passes((8, 10, 12, 14, 16, 18, 22)))
    check('COARSE off-grid point refuses', has(r['refusals'], 'A2 optimizer XML has 7 passes'), r['refusals'])
    for key, val, frag in (('Optimization', '2', 'R12 requires 1'), ('Model', '4', 'ini Model=4'),
                           ('ToDate', '2026.03.31', 'ini window'), ('Expert', 'EALabTpl\\Other', 'ini Expert'),
                           ('Leverage', '100', 'A5 ini Leverage')):
        t = open(os.path.join(o, 'opt.ini')).read()
        bad_ini = os.path.join(o, 'bad_%s.ini' % key)
        with open(bad_ini, 'w') as fh:
            fh.write(re.sub(r'(?m)^%s=.*$' % key, lambda _m, k=key, v=val: '%s=%s' % (k, v), t))
        r = opt(o, orp, ini=bad_ini)
        check('COARSE ini %s=%s refuses' % (key, val), any(frag in x for x in r['refusals']), r['refusals'])
    with open(os.path.join(o, 'range.set'), 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14||8||4||20||Y\n_99_Safety=25\n')
    r = opt(o, orp, set_name='range.set')
    check('COARSE set range differs from recipe refuses', has(r['refusals'], 'A4 set sweeps _99_Len as'), r['refusals'])
    with open(os.path.join(o, 'extra.set'), 'w') as fh:
        fh.write('ExitMode=22\n_99_Len=14||8||2||20||Y\n_99_Safety=25||20||5||30||Y\n')
    r = opt(o, orp, set_name='extra.set')
    check('COARSE set sweeping a SAFETY input refuses', any('_99_Safety is swept' in x for x in r['refusals']), r['refusals'])
    r = opt(o, orp, ini=os.path.join(o, 'missing.ini'))
    check('COARSE without a readable ini refuses', has(r['refusals'], 'A9 cannot read ini'), r['refusals'])
    with open(os.path.join(o, 'other.set'), 'w') as fh:
        fh.write('ExitMode=21\n_99_Len=14||8||2||20||Y\n_99_Safety=25\n')
    r = opt(o, orp, ini=write_ini(os.path.join(o, 'other.ini'), os.path.join(o, 'other.set'), {'Optimization': '1'}))
    check('COARSE run launched with a different set than --set refuses', has(r['refusals'], 'A4 --set differs from the launch ini'), r['refusals'])
    hot = {'passes': [{'pass_id': i, '_99_Len': v, 'max_drawdown_percent': 30.0} for i, v in enumerate((8, 10, 12, 14, 16, 18, 20))]}
    r = opt(o, orp, xml=hot)
    check('COARSE where every pass exceeds the DD cap refuses (A6)', has(r['refusals'], 'A6 every optimizer pass'), r['refusals'])
    nodd = {'passes': [{'pass_id': i, '_99_Len': v} for i, v in enumerate((8, 10, 12, 14, 16, 18, 20))]}
    r = opt(o, orp, xml=nodd)
    check('COARSE passes without DD refuse (A9)', has(r['refusals'], 'A9 7 optimizer pass'), r['refusals'])
    shutil.rmtree(o)
    for name, kw, frag in (('no preflight', {'preflight': False}, 'A3'),
                           ('warn-only preflight', {'warn_only': True}, 'A3'),
                           ('preflight after the run ended', {'submitted': AFTER}, 'A3'),
                           ('preflight with no timestamp', {'submitted': ''}, 'A3'),
                           ('preflight with an impossible date', {'submitted': '2026-00-00T00:00:00Z'}, 'A3'),
                           ('preflight on other dimensions', {'dims': ('_99_Other',)}, 'A3')):
        o, orp = opt_root(**kw)
        r = opt(o, orp)
        check('COARSE %s refuses' % name, has(r['refusals'], frag), r['refusals'])
        shutil.rmtree(o)
    # a COARSE ACCEPT satisfies the next stage's prerequisite (symbol/timeframe come from the ini)
    o, orp = opt_root()
    rc.append_jsonl(os.path.join(o, rc.RECEIPTS_REL), opt(o, orp))
    r = run(o, orp, 'BOTH_WINDOW', 'MAIN', write=False)
    check('BOTH_WINDOW after an accepted COARSE is ACCEPT', r['result'] == 'ACCEPT', r['refusals'])
    shutil.rmtree(o)
    # V2: an optimize recipe must name its EA
    vr = copy.deepcopy(good)
    vr.pop('ea')
    check('V2 optimize recipe without ea.expert refuses', has(rc.validate_recipe(vr, root), 'V2 recipe has an optimize stage'), rc.validate_recipe(vr, root))

    # ---- V4: STACK token and multi-order inputs force escalation
    sroot2 = make_root()
    hp = os.path.join(sroot2, 'factory', 'hypotheses.jsonl')
    jl(hp, [{'hypothesis_id': 'B99-H01', 'module_set': [{'token': 'LAB_CAP_CORE'}, {'token': 'LAB_CAP_STACK'}]}])
    out = rc.validate_recipe(base_recipe(sroot2), sroot2)
    check('V4 STACK module forces escalation', has(out, 'V4 modules include'), out)
    shutil.rmtree(sroot2)
    mroot = make_root()
    bp2 = os.path.join(mroot, 'factory', 'parameter_bindings.jsonl')
    rows2 = rc.read_jsonl(bp2)
    rows2.append({'hypothesis_revision': 'B99-H01-r1', 'parameter': '_99_MaxOrdersPerSide', 'role': 'SAFETY', 'locked_value': None, 'surface': 'OPERATOR'})
    jl(bp2, rows2)
    mrec = base_recipe(mroot)
    mrec['fixed_inputs'] = {'_99_MaxOrdersPerSide': '3'}
    out = rc.validate_recipe(mrec, mroot)
    check('V4 MaxOrdersPerSide=3 forces escalation', has(out, 'V4 [\'_99_MaxOrdersPerSide\']'), out)
    mrec['fixed_inputs'] = {'_99_MaxOrdersPerSide': '1'}
    out = rc.validate_recipe(mrec, mroot)
    check('V4 MaxOrdersPerSide=1 stays non-escalation', not has(out, 'V4'), out)
    shutil.rmtree(mroot)

    # A1 recipe edited after receipts: the old receipts no longer count
    good2 = copy.deepcopy(good)
    good2['tie_breaks'] = ['lower DD']
    rp = write_recipe(root, good2)
    r = run(root, rp, 'COARSE', 'MAIN', write=False)
    check('A1 receipts of an older recipe hash do not satisfy prerequisites', has(r['refusals'], 'A2 earlier stage SMOKE'), r['refusals'])
    shutil.rmtree(root)

    n_ok = sum(RESULTS)
    print('TOTAL PASS=%d FAIL=%d' % (n_ok, len(RESULTS) - n_ok))
    return 0 if all(RESULTS) else 1


if __name__ == '__main__':
    sys.exit(main())
