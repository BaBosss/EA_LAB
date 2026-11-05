#!/usr/bin/env python3
"""recipe_check.py -- OptimizeRecipe validator + AcceptanceReceipt checker.

Implements docs/workflows/EA_OPTIMIZE_RECIPE_RECEIPT_SPEC.md (rules V1-V8, A1-A9) for the
template + optimize standard (docs/workflows/EA_TEMPLATE_OPTIMIZE_STANDARD.md section 9, v2).

  python scripts/recipe_check.py validate factory/recipes/<rev>.json
  python scripts/recipe_check.py accept --recipe factory/recipes/<rev>.json --stage MODEL4 \
      --window BWD --report <report.htm> --set <full.set> --binary <ea.ex5> [--ini <ini>] \
      --lane <mt5 lane> [--write]

Without --write nothing is appended; the receipt is printed. With --write the receipt row is
appended to factory/acceptance_receipts.jsonl, and a REFUSE is ALSO appended to
factory/optimize_decisions.jsonl as a record_version 1 row (R21: every refusal is recorded there).

It picks no parameters and issues no verdict word. An input it cannot read or resolve is a
refusal, never a skip (A9).
"""
import argparse
import hashlib
import json
import math
import os
import re
import sys
from datetime import datetime, timezone

STAGE_ORDER = ('SMOKE', 'COARSE', 'FINE', 'FREEZE', 'BOTH_WINDOW', 'MODEL4', 'HOLDOUT')
OPTIMIZE_STAGES = ('COARSE', 'FINE')
CLASSES = ('trend', 'reversion', 'breakout', 'escalation')
# R6: any grid or lot-progression module makes the class escalation, whatever the author wrote.
ESCALATION_TOKEN = re.compile(r'GRID|PROG|LOTLOG|MARTING|RECOVER|LADDER|PYRAMID|DCA', re.I)
DD_CAP_MAX = 12.0                 # R17
SCORE_FORMULA_ID = 'R15_F5_v1'    # R15 (rule table v2)
# The frozen formula text; a recipe pins its sha256 (V2), so a silent formula edit breaks every recipe.
SCORE_FORMULA_TEXT = ('R15_F5_v1: score = recovery_factor * confidence_multiplier(A=1.0,B=0.75,C=0.5,D=0.0); '
                      'excluded when equity_dd_pct > dd_cap_equity_pct')
SCORE_FORMULA_SHA256 = hashlib.sha256(SCORE_FORMULA_TEXT.encode('utf-8')).hexdigest()
CONF_MULT = {'A': 1.0, 'B': 0.75, 'C': 0.5, 'D': 0.0}
CHECKER_VERSION = 'recipe_check/1'
RECEIPTS_REL = 'factory/acceptance_receipts.jsonl'
DECISIONS_REL = 'factory/optimize_decisions.jsonl'


class Unreadable(Exception):
    """An input could not be read or resolved. Always becomes a refusal (A9)."""


def sha256_file(path):
    try:
        with open(path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError as exc:
        raise Unreadable('cannot read %s: %s' % (path, exc))


def read_jsonl(path, allow_missing=False):
    if not os.path.exists(path):
        if allow_missing:
            return []
        raise Unreadable('missing %s' % path)
    rows = []
    try:
        with open(path, encoding='utf-8-sig') as f:
            lines = f.read().split('\n')
    except (OSError, UnicodeDecodeError) as exc:
        raise Unreadable('cannot read %s: %s' % (path, exc))
    if True:
        for n, line in enumerate(lines, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError as exc:
                raise Unreadable('%s line %d unparseable: %s' % (path, n, exc))
            if isinstance(row, dict) and '_comment' in row and len(row) == 1:
                continue
            rows.append(row)
    return rows


def finite(x):
    """float(x) if x is a finite number, else None (NaN / inf / text never pass a numeric gate)."""
    try:
        v = float(x)
    except (TypeError, ValueError):
        return None
    return v if math.isfinite(v) else None


def has_null(obj):
    """True if obj or anything nested in it is None or an empty string."""
    if obj is None or obj == '':
        return True
    if isinstance(obj, dict):
        return any(has_null(v) for v in obj.values())
    if isinstance(obj, list):
        return any(has_null(v) for v in obj)
    return False


# R8: the broker specs a symbol preset must pin, as written by tools/mt5/SymbolSpecDump.mq5.
PROFILE_SPEC_KEYS = ('spec_digits', 'spec_point', 'spec_tick_value', 'spec_contract_size')

# Roles whose value must be frozen in the recipe when the binding fixes none (R13).
FROZEN_VALUE_ROLES = ('SAFETY', 'SIZING')


def confidence(trades):
    """R19 evidence-confidence letter for one window."""
    if trades is None:
        return None
    t = int(trades)
    return 'A' if t >= 100 else 'B' if t >= 50 else 'C' if t >= 20 else 'D'


def score_f5(recovery_factor, eq_dd_pct, trades, dd_cap):
    """R15 = F5: recovery factor x confidence multiplier; excluded (None) above the DD cap."""
    rf, dd, cap = finite(recovery_factor), finite(eq_dd_pct), finite(dd_cap)
    if rf is None or dd is None or cap is None or trades is None:
        return None
    if not dd <= cap:
        return None
    recovery_factor = rf
    return float(recovery_factor) * CONF_MULT[confidence(trades)]


def parse_window(w):
    if not (isinstance(w, list) and len(w) == 2):
        raise Unreadable('window must be [from, to]: %r' % (w,))
    try:
        return tuple(datetime.strptime(x, '%Y.%m.%d').date() for x in w)
    except (TypeError, ValueError):
        raise Unreadable('window dates must be YYYY.MM.DD: %r' % (w,))


def overlaps(a, b):
    return a[0] <= b[1] and b[0] <= a[1]


def parse_set(path):
    """-> {name: (value, swept)}; swept = the line ends in ||Y."""
    out = {}
    try:
        with open(path, encoding='utf-8-sig', errors='strict') as f:
            lines = f.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise Unreadable('cannot read set %s: %s' % (path, exc))
    for line in lines:
        if not line.strip() or line.lstrip().startswith(';'):
            continue
        if '=' not in line:
            raise Unreadable('set line without "=": %r' % line)
        k, v = line.split('=', 1)
        parts = v.split('||')
        out[k.strip()] = (parts[0].strip(), len(parts) >= 5 and parts[-1].strip().upper() == 'Y')
    return out


def norm_symbol(s):
    return re.sub(r'[^A-Z0-9]', '', (s or '').upper())


# --------------------------------------------------------------------------------------------
# Recipe validity V1-V8
# --------------------------------------------------------------------------------------------

def pinned_rows(root, ref_obj, default_path, label):
    """Rows of a pinned store. The recipe's raw_sha256 must equal the file's bytes now (V2/A1):
    a store edited after freezing must not change what an unchanged recipe accepts."""
    ref_obj = ref_obj or {}
    path = os.path.join(root, ref_obj.get('path') or default_path)
    want = ref_obj.get('raw_sha256')
    if not want:
        raise Unreadable('%s.raw_sha256 is null (the store is not pinned)' % label)
    if sha256_file(path) != want:
        raise Unreadable('%s pin differs from %s bytes now' % (label, ref_obj.get('path') or default_path))
    return read_jsonl(path)


def load_bindings(recipe, root):
    rev = (recipe.get('bindings_ref') or {}).get('hypothesis_revision') or recipe.get('recipe_id')
    rows = pinned_rows(root, recipe.get('bindings_ref'), 'factory/parameter_bindings.jsonl', 'bindings_ref')
    return rev, [b for b in rows if b.get('hypothesis_revision') == rev]


def validate_recipe(recipe, root):
    """-> list of refusal strings (empty = valid)."""
    ref = []
    try:
        rev, bindings = load_bindings(recipe, root)
    except Unreadable as exc:
        return ['V2 ' + str(exc)]
    by_param = {b.get('parameter'): b for b in bindings}

    stages = recipe.get('stages')
    if not isinstance(stages, list) or not stages:
        return ['V2 stages missing or empty']
    names = [s.get('stage') for s in stages]
    unknown = [n for n in names if n not in STAGE_ORDER]
    if unknown:
        ref.append('V2 unknown stage(s): %s' % unknown)
    win_keys = set((recipe.get('windows') or {}).keys())
    for s in stages:
        if s.get('stage') in STAGE_ORDER and s.get('stage') != 'FREEZE':
            sw = stage_windows(s)
            if not sw:
                ref.append('V2 stage %s names no window' % s.get('stage'))
            elif not set(sw) <= win_keys:
                ref.append('V2 stage %s names unknown window(s) %s' % (s.get('stage'), sorted(set(sw) - win_keys)))

    # V1 every swept parameter is TUNABLE in this revision
    for s in stages:
        for sw in s.get('sweep') or []:
            p = sw.get('parameter')
            b = by_param.get(p)
            if b is None:
                ref.append('V1 swept %s has no ParameterBinding in %s' % (p, rev))
            elif b.get('role') != 'TUNABLE':
                ref.append('V1 swept %s is %s in %s, not TUNABLE' % (p, b.get('role'), rev))
            for k in ('from', 'to', 'step'):
                if sw.get(k) is None:
                    ref.append('V2 sweep %s has no %s' % (p, k))

    # V2 frozen fields
    score = recipe.get('score') or {}
    if not score.get('formula_id'):
        ref.append('V2 score.formula_id is null')
    elif score.get('formula_id') != SCORE_FORMULA_ID:
        ref.append('V2 score.formula_id=%r is not the frozen R15 formula %s' % (score.get('formula_id'), SCORE_FORMULA_ID))
    if score.get('formula_sha256') != SCORE_FORMULA_SHA256:
        ref.append('V2 score.formula_sha256 does not pin the frozen R15 formula text')
    plateau = recipe.get('plateau_rule') or {}
    if not plateau.get('id') or not plateau.get('text') or has_null(plateau):
        ref.append('V2 plateau_rule has a null or empty field')
    fixed = recipe.get('fixed_inputs')
    if fixed is not None and not isinstance(fixed, dict):
        ref.append('V2 fixed_inputs must be an object')
        fixed = {}
    fixed = fixed or {}
    for b in bindings:
        if b.get('role') in FROZEN_VALUE_ROLES and b.get('locked_value') is None and fixed.get(b.get('parameter')) in (None, ''):
            ref.append('V9 %s input %s has no bound value and no fixed_inputs entry' % (b.get('role'), b.get('parameter')))
    tb = recipe.get('tie_breaks')
    if not isinstance(tb, list) or not tb or not all(isinstance(x, str) and x.strip() for x in tb):
        ref.append('V2 tie_breaks must be a non-empty list of non-empty strings')
    for k in ('frozen_utc', 'frozen_by'):
        if not recipe.get(k):
            ref.append('V2 %s is null (recipe not frozen, R13)' % k)

    # V3 windows: MAIN and BWD never touch HOLDOUT
    wins = recipe.get('windows') or {}
    try:
        main = parse_window(wins.get('MAIN'))
        hold = parse_window(wins.get('HOLDOUT'))
        if overlaps(main, hold):
            ref.append('V3 MAIN overlaps HOLDOUT')
        if wins.get('BWD') is not None and overlaps(parse_window(wins['BWD']), hold):
            ref.append('V3 BWD overlaps HOLDOUT')
    except Unreadable as exc:
        ref.append('V3 ' + str(exc))

    # V4 class derived from modules
    cls = recipe.get('class')
    if cls not in CLASSES:
        ref.append('V4 class %r is not one of %s' % (cls, CLASSES))
    else:
        hyp_key = (recipe.get('hypothesis_ref') or {}).get('key') or rev
        if not (recipe.get('class_derivation') or '').strip():
            ref.append('V4 class_derivation is empty (a non-escalation class must say which modules make it %s)' % cls)
        try:
            hyps = [h for h in pinned_rows(root, recipe.get('hypothesis_ref'), 'factory/hypotheses.jsonl', 'hypothesis_ref')
                    if hyp_key in (h.get('hypothesis_revision'), h.get('hypothesis_id'), h.get('key'))
                    or (h.get('hypothesis_id') and hyp_key.startswith(h['hypothesis_id'] + '-'))]
        except Unreadable as exc:
            hyps = []
            ref.append('A9 ' + str(exc))
        if not hyps:
            ref.append('V4 no hypothesis row for %s, so the class cannot be derived' % hyp_key)
        else:
            tokens = [m.get('token', '') for h in hyps for m in (h.get('module_set') or [])]
            esc = any(ESCALATION_TOKEN.search(t) for t in tokens)
            if esc and cls != 'escalation':
                ref.append('V4 modules include grid/lot progression (%s) but class=%s' %
                           ([t for t in tokens if ESCALATION_TOKEN.search(t)], cls))
            if not esc and cls == 'escalation':
                ref.append('V4 class=escalation but no grid/lot-progression module was found')

    # V5 at most one extra round, approved by someone other than the author
    er = recipe.get('extra_round')
    if er is not None:
        if isinstance(er, list):
            ref.append('V5 extra_round must be one object or null (at most one round)')
        elif not all(er.get(k) for k in ('reason', 'lever', 'approved_by', 'approved_utc')):
            ref.append('V5 extra_round lacks reason/lever/approved_by/approved_utc')
        elif er.get('approved_by') == recipe.get('frozen_by'):
            ref.append('V5 extra_round approved by its own author')

    # V6 symbol presets resolve and pin broker specs
    syms = recipe.get('symbols') or []
    prefs = {norm_symbol(p.get('symbol')): p for p in (recipe.get('symbol_preset_refs') or [])}
    for s in syms:
        p = prefs.get(norm_symbol(s))
        if p is None:
            ref.append('V6 no symbol_preset_ref for %s' % s)
            continue
        path = os.path.join(root, p.get('path') or '')
        try:
            if not p.get('raw_sha256'):
                ref.append('V6 %s preset ref has no raw_sha256' % s)
            elif sha256_file(path) != p['raw_sha256']:
                ref.append('V6 %s preset file hash differs from raw_sha256' % s)
            rows = [r for r in read_jsonl(path) if norm_symbol(r.get('symbol')) == norm_symbol(s)]
        except Unreadable as exc:
            ref.append('V6 ' + str(exc))
            continue
        lane = p.get('lane')
        if not lane:
            ref.append('V6 %s preset ref names no lane (profiles are BROKER_LANE rows)' % s)
            continue
        rows = [r for r in rows if r.get('layer') == 'BROKER_LANE' and r.get('lane') == lane]
        if len(rows) != 1:
            ref.append('V6 %s has %d BROKER_LANE rows for lane %r in %s (need exactly 1)' % (s, len(rows), lane, p.get('path')))
            continue
        vals = rows[0].get('values') if isinstance(rows[0].get('values'), dict) else {}
        want = hashlib.sha256(json.dumps(vals, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()
        if rows[0].get('content_hash') != want:
            ref.append('V6 %s profile content_hash does not match its values' % s)
        if not all(finite(vals.get(k)) is not None for k in PROFILE_SPEC_KEYS):
            ref.append('V6 %s profile does not pin %s' % (s, '/'.join(PROFILE_SPEC_KEYS)))

    # V7 Model 4 on MAIN+BWD before anything that could lead to CANDIDATE
    if 'MODEL4' not in names:
        ref.append('V7 no MODEL4 stage')
    else:
        m4 = stages[names.index('MODEL4')]
        if not {'MAIN', 'BWD'} <= set(m4.get('windows') or []):
            ref.append('V7 MODEL4 stage must cover MAIN and BWD')
        if int(m4.get('model', 0)) != 4:
            ref.append('V7 MODEL4 stage model is not 4')
        if 'HOLDOUT' in names and names.index('HOLDOUT') < names.index('MODEL4'):
            ref.append('V7 HOLDOUT precedes MODEL4')
    known = [n for n in names if n in STAGE_ORDER]
    if known != sorted(known, key=STAGE_ORDER.index):
        ref.append('V7 stages out of order: %s' % known)

    # V8 DD cap never looser than 12 %
    raw_cap = score.get('dd_cap_equity_pct')
    cap = finite(raw_cap) if isinstance(raw_cap, (int, float)) and not isinstance(raw_cap, bool) else None
    if cap is None or cap <= 0 or cap > DD_CAP_MAX:
        ref.append('V8 score.dd_cap_equity_pct=%r must be <= %.1f' % (cap, DD_CAP_MAX))
    return ref


# --------------------------------------------------------------------------------------------
# Acceptance A1-A9
# --------------------------------------------------------------------------------------------

def stage_windows(stage):
    if stage.get('windows'):
        return list(stage['windows'])
    return [stage['window']] if stage.get('window') else []


def accept(recipe_path, stage_name, window, report_path, set_path, binary_path, root, lane,
           ini_path=None, read_report=None, now=None):
    """-> receipt dict (result ACCEPT or REFUSE). Never raises for bad input: an unexpected error is
    itself a refusal, so a receipt row is always produced (A9)."""
    try:
        return _accept(recipe_path, stage_name, window, report_path, set_path, binary_path, root, lane,
                       ini_path, read_report, now)
    except Exception as exc:  # noqa: BLE001
        receipt = {'entity': 'AcceptanceReceipt', 'recipe_id': None, 'recipe_sha256': None,
                   'stage': stage_name, 'window': window, 'lane': lane, 'symbol': None, 'timeframe': None,
                   'result': 'REFUSE', 'refusals': ['A9 checker error: %s: %s' % (type(exc).__name__, exc)],
                   'checker_version': CHECKER_VERSION,
                   'checked_utc': (now or datetime.now(timezone.utc)).strftime('%Y-%m-%dT%H:%M:%SZ')}
        body = json.dumps(receipt, sort_keys=True)
        receipt['receipt_id'] = hashlib.sha256(body.encode('utf-8')).hexdigest()
        return receipt


def _accept(recipe_path, stage_name, window, report_path, set_path, binary_path, root, lane,
            ini_path, read_report, now):
    refusals = []
    receipt = {
        'entity': 'AcceptanceReceipt', 'recipe_id': None, 'recipe_sha256': None,
        'stage': stage_name, 'symbol': None, 'timeframe': None, 'window': window, 'model': None,
        'report': {'path': report_path, 'raw_sha256': None},
        'set': {'path': set_path, 'raw_sha256': None},
        'binary': {'path': binary_path, 'raw_sha256': None, 'mtime_utc': None},
        'tester': {}, 'metrics': {}, 'evidence_confidence': None, 'preflight_ref': None,
        'lane': lane, 'result': None, 'refusals': refusals, 'checker_version': CHECKER_VERSION,
        'checked_utc': (now or datetime.now(timezone.utc)).strftime('%Y-%m-%dT%H:%M:%SZ'),
    }

    def done():
        receipt['result'] = 'REFUSE' if refusals else 'ACCEPT'
        body = json.dumps({k: v for k, v in receipt.items() if k != 'receipt_id'}, sort_keys=True)
        receipt['receipt_id'] = hashlib.sha256(body.encode('utf-8')).hexdigest()
        return receipt

    # A1 recipe identity + validity
    try:
        receipt['recipe_sha256'] = sha256_file(recipe_path)
        with open(recipe_path, encoding='utf-8-sig') as f:
            recipe = json.load(f)
    except (Unreadable, ValueError, OSError) as exc:
        refusals.append('A9 recipe unreadable: %s' % exc)
        return done()
    receipt['recipe_id'] = recipe.get('recipe_id')
    for r in validate_recipe(recipe, root):
        refusals.append('A1 recipe invalid: ' + r)

    stages = recipe.get('stages') or []
    names = [s.get('stage') for s in stages]
    if stage_name not in names or stage_name == 'FREEZE':
        refusals.append('A2 stage %s is not a runnable stage of this recipe' % stage_name)
        return done()
    st = stages[names.index(stage_name)]
    if window not in stage_windows(st):
        refusals.append('A2 window %s is not in stage %s %s' % (window, stage_name, stage_windows(st)))

    # A4 hashes read from the files
    for key, path in (('report', report_path), ('set', set_path), ('binary', binary_path)):
        try:
            receipt[key]['raw_sha256'] = sha256_file(path)
        except Unreadable as exc:
            refusals.append('A9 ' + str(exc))
    if os.path.exists(binary_path):
        receipt['binary']['mtime_utc'] = datetime.fromtimestamp(
            os.path.getmtime(binary_path), timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # report
    rep = None
    if stage_name in OPTIMIZE_STAGES:
        refusals.append('A2 %s produces an optimizer XML; this checker accepts single-test reports '
                        'only (optimize stages are covered by the A3 preflight + pass count, not yet built)' % stage_name)
    else:
        try:
            if read_report is None:
                sys.path.insert(0, os.path.join(root, 'scripts'))
                import parse_mt5_report
                read_report = parse_mt5_report.parse_report
            rep = read_report(report_path)
        except Exception as exc:  # noqa: BLE001 -- any parser failure is an unreadable input
            refusals.append('A9 report unreadable: %s: %s' % (type(exc).__name__, exc))
    if rep is not None:
        receipt['symbol'] = rep.get('symbol')
        receipt['timeframe'] = rep.get('period')
        hq = str(rep.get('history_quality') or '')
        receipt['model'] = 4 if 'real ticks' in hq.lower() else 'not-4'
        receipt['tester'] = {'leverage': rep.get('leverage'), 'deposit': rep.get('initial_deposit'),
                             'currency': rep.get('currency'), 'build': rep.get('report_build'),
                             'history_quality': hq}
        # A2 run identity vs the stage
        if norm_symbol(rep.get('symbol')) not in [norm_symbol(s) for s in recipe.get('symbols') or []]:
            refusals.append('A2 report symbol %r not in recipe symbols' % rep.get('symbol'))
        if rep.get('period') not in (recipe.get('timeframes') or []):
            refusals.append('A2 report timeframe %r not in recipe timeframes' % rep.get('period'))
        want_m4 = int(st.get('model', 1)) == 4
        if want_m4 != (receipt['model'] == 4):
            refusals.append('A2 stage wants model %s but report history quality is %r' % (st.get('model'), hq))
        try:
            w = parse_window((recipe.get('windows') or {}).get(window))
            got = (rep.get('from_date'), rep.get('to_date'))
            if got != tuple(d.strftime('%Y.%m.%d') for d in w):
                refusals.append('A2 report window %s..%s != recipe %s %s..%s' %
                                (got[0], got[1], window, w[0].strftime('%Y.%m.%d'), w[1].strftime('%Y.%m.%d')))
        except Unreadable as exc:
            refusals.append('A2 ' + str(exc))
        # A5 leverage asserted
        if not re.fullmatch(r'1:\d+', str(rep.get('leverage') or '')):
            refusals.append('A5 tester leverage %r is not asserted as 1:N' % rep.get('leverage'))
        # metrics + A6
        dd = rep.get('equity_drawdown_relative_pct')
        if dd is None:
            dd = rep.get('equity_drawdown_maximal_pct')
        trades = rep.get('total_trades')
        cap = (recipe.get('score') or {}).get('dd_cap_equity_pct', DD_CAP_MAX)
        receipt['metrics'] = {'net': rep.get('net_profit'), 'pf': rep.get('profit_factor'),
                              'trades': trades, 'equity_dd_pct': dd,
                              'recovery_factor': rep.get('recovery_factor'),
                              'worst_basket_depth': None, 'worst_basket_hold_s': None,
                              'score': score_f5(rep.get('recovery_factor'), dd, trades, cap)}
        receipt['evidence_confidence'] = confidence(trades)
        if finite(dd) is None or finite(cap) is None:
            refusals.append('A9 equity drawdown %r or cap %r is not a finite number' % (dd, cap))
        elif not finite(dd) <= finite(cap):
            refusals.append('A6 equity DD %.2f%% > cap %.2f%%' % (finite(dd), finite(cap)))
        # A7 escalation needs the in-EA basket log (R18) -- never estimated from deals
        if recipe.get('class') == 'escalation':
            refusals.append('A7 escalation: worst-basket depth/hold not available (no in-EA basket log yet, R18)')

    # A4 set: only TUNABLE swept, everything else at its locked value; A5 full surface
    try:
        sv = parse_set(set_path)
        rev, binds = load_bindings(recipe, root)
        if not binds:
            refusals.append('A4 no ParameterBinding rows for %s' % rev)
        bound = {b.get('parameter'): b for b in binds}
        for p, (val, swept) in sv.items():
            if swept and (stage_name not in OPTIMIZE_STAGES or (bound.get(p) or {}).get('role') != 'TUNABLE'):
                refusals.append('A4 %s is swept in a %s run' % (p, stage_name))
        fixed = recipe.get('fixed_inputs') if isinstance(recipe.get('fixed_inputs'), dict) else {}
        for b in binds:
            p = b.get('parameter')
            if p not in sv:
                if b.get('surface') != 'HIDDEN':
                    refusals.append('A5 set omits bound input %s (not a full .set)' % p)
                continue
            val, _swept = sv[p]
            # Every non-TUNABLE input must sit at its fixed value: the binding's locked_value, else (for
            # SAFETY/SIZING) the recipe's frozen fixed_inputs. A single-test stage has no preflight (A3 is
            # optimize-only), so this is its parameter guarantee.
            role = b.get('role')
            want = b.get('locked_value')
            if want is None and role in FROZEN_VALUE_ROLES:
                want = fixed.get(p)
                if want in (None, ''):
                    refusals.append('A4 %s input %s has no fixed value to check against' % (role, p))
                    continue
            if role != 'TUNABLE' and want is not None and val != str(want):
                refusals.append('A4 %s=%s but its %s value is fixed at %s' % (p, val, role, want))
    except Unreadable as exc:
        refusals.append('A9 ' + str(exc))

    # A2 stage order: every earlier runnable stage has ACCEPT receipts for all its windows
    try:
        prior = read_jsonl(os.path.join(root, RECEIPTS_REL), allow_missing=True)
    except Unreadable as exc:
        prior = []
        refusals.append('A9 ' + str(exc))
    mine = [r for r in prior if r.get('recipe_id') == receipt['recipe_id']
            and r.get('recipe_sha256') == receipt['recipe_sha256']
            and norm_symbol(r.get('symbol')) == norm_symbol(receipt['symbol'])
            and r.get('timeframe') == receipt['timeframe']]
    for earlier in stages[:names.index(stage_name)]:
        en = earlier.get('stage')
        if en == 'FREEZE':
            continue
        for ew in stage_windows(earlier):
            if not any(r.get('stage') == en and r.get('window') == ew and r.get('result') == 'ACCEPT' for r in mine):
                refusals.append('A2 earlier stage %s/%s has no ACCEPT receipt' % (en, ew))

    # A3 optimize stages need an enforcing ALLOW preflight on the same .ini
    if stage_name in OPTIMIZE_STAGES:
        try:
            dec = read_jsonl(os.path.join(root, DECISIONS_REL), allow_missing=True)
        except Unreadable as exc:
            dec = []
            refusals.append('A9 ' + str(exc))
        ok = [d for d in dec if d.get('result') == 'ALLOW' and d.get('warn_only') is False
              and d.get('exit_code') == 0 and ini_path and d.get('ini_path') == ini_path]
        if not ok:
            refusals.append('A3 no enforcing ALLOW preflight for ini %r' % ini_path)
        else:
            receipt['preflight_ref'] = {'path': DECISIONS_REL, 'submitted_utc': ok[-1].get('submitted_utc'), 'result': 'ALLOW'}

    # A8 the holdout is spent by its first receipt
    if stage_name == 'HOLDOUT':
        if any(r.get('recipe_id') == receipt['recipe_id'] and r.get('stage') == 'HOLDOUT' for r in prior):
            refusals.append('A8 holdout already spent for recipe %s' % receipt['recipe_id'])
    return done()


def refusal_decision_row(receipt):
    """A record_version 1 row for factory/optimize_decisions.jsonl (readable by optimize_log.parse)."""
    dims = [{'name': r.split(' ', 1)[0], 'verdict': 'REFUSE', 'facts': [{'text': r, 'refuse': True}]}
            for r in receipt['refusals']]
    return {
        'record_version': 1, 'submitted_utc': receipt['checked_utc'], 'lane': receipt['lane'],
        'hypothesis_revision': receipt['recipe_id'], 'result': 'REFUSE', 'checked': len(dims),
        'allow_count': 0, 'refuse_count': len(dims), 'dimensions': dims, 'exit_code': 1,
        'warn_only': False, 'build': None, 'expert': 'acceptance:' + str(receipt['stage']),
        'ini_path': 'acceptance-receipt:' + receipt['receipt_id'], 'source': CHECKER_VERSION,
    }


def append_jsonl(path, row):
    with open(path, 'a', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(row, sort_keys=True, ensure_ascii=False) + '\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    sub = ap.add_subparsers(dest='cmd', required=True)
    v = sub.add_parser('validate')
    v.add_argument('recipe')
    a = sub.add_parser('accept')
    for k in ('recipe', 'stage', 'window', 'report', 'set', 'binary', 'lane'):
        a.add_argument('--' + k, required=True)
    a.add_argument('--ini')
    a.add_argument('--write', action='store_true')
    args = ap.parse_args(argv)
    if args.cmd == 'validate':
        try:
            with open(args.recipe, encoding='utf-8-sig') as f:
                recipe = json.load(f)
        except (OSError, ValueError) as exc:
            print('REFUSE A9 recipe unreadable: %s' % exc)
            return 1
        ref = validate_recipe(recipe, args.root)
        for r in ref:
            print('REFUSE ' + r)
        print('VALID' if not ref else 'INVALID (%d)' % len(ref))
        return 0 if not ref else 1
    rec = accept(args.recipe, args.stage, args.window, args.report, args.set, args.binary,
                 args.root, args.lane, ini_path=args.ini)
    print(json.dumps(rec, indent=1, sort_keys=True))
    if args.write:
        # Both records are attempted independently, so one unwritable store cannot lose the other.
        failed = []
        targets = [(RECEIPTS_REL, rec)]
        if rec['result'] == 'REFUSE':
            targets.insert(0, (DECISIONS_REL, refusal_decision_row(rec)))
        for rel, row in targets:
            try:
                append_jsonl(os.path.join(args.root, rel), row)
            except OSError as exc:
                failed.append('%s: %s' % (rel, exc))
        if failed:
            print('WRITE FAILED (record not durable): ' + '; '.join(failed), file=sys.stderr)
            return 2
    return 0 if rec['result'] == 'ACCEPT' else 1


if __name__ == '__main__':
    sys.exit(main())
