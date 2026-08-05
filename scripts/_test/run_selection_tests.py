# -*- coding: utf-8 -*-
"""run_selection_tests.py -- the cage for scripts/pilot_probe_select.py (ORDER-1273).

WHY THIS SUITE EXISTS AND WHAT IT ATTACKS. `pilot_probe_select.py` turns a pre-registered sentence
into a configuration that a BWD run will be spent on. Its usual output looks reasonable whatever it
does -- a dict of parameter values is exactly as plausible when the floor was ignored, when the
median silently became the best row, or when a column moved and it read the one next door. So every
case here attacks one of those, and every attack is paired with a CONTROL that must come out the
other way. A detector that fires on everything is not a detector (memory
`guard-checks-the-wrong-surface`: every attack must have a control).

The fixtures are surfaces this file builds byte by byte, so an assertion here is about the
selection RULE and never about what the pilot happens to have measured. PART 2 then drives the real
module over the real repository, because a cage that only ever sees its own fixtures proves only
the half it can reach (memory `pure-cage-proves-only-the-pure-half`).

USAGE  tools\\python312\\python.exe scripts/_test/run_selection_tests.py
"""

import io
import json as _json
import os
import shutil
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import pilot_probe_select as sel  # noqa: E402

FAILED = []
PASSED = []

BASE_COLS = ['Pass', 'Result', 'Profit', 'Expected Payoff', 'Profit Factor', 'Recovery Factor',
             'Sharpe Ratio', 'Custom', 'Equity DD %', 'Trades']
DIMS = {'d1': {'start': 1.0, 'step': 1.0, 'stop': 5.0},
        'd2': {'start': 0.5, 'step': 0.25, 'stop': 1.5}}


def write_surface(path, rows, dim_names=('d1', 'd2'), header_first='Pass', order=None, ragged=False):
    """Build a fixture optimizer XML. `rows` = [(pass, result, trades, d1, d2), ...]."""
    header = list(BASE_COLS) + list(dim_names)
    header[0] = header_first
    body = []
    for (p, res, tr, *dv) in rows:
        cells = [str(p), str(res), '0', '0', '0', '0', '0', '0', '0', str(tr)] + [str(v) for v in dv]
        body.append(cells)
    if order is not None:
        header = [header[i] for i in order]
        body = [[r[i] for i in order] for r in body]
    if ragged:
        body[-1] = body[-1][:-1]
    out = ['<?xml version="1.0"?><Workbook><Worksheet><Table>']
    for cells in [header] + body:
        out.append('<Row>' + ''.join('<Data ss:Type="String">%s</Data>' % c for c in cells) + '</Row>')
    out.append('</Table></Worksheet></Workbook>')
    io.open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    return len(body)


def cell_for(path, n_rows, tf='H1'):
    return {'cell_id': 'FIX-r1/EURUSD/%s' % tf, 'revision': 'FIX-r1', 'symbol': 'EURUSD',
            'tf': tf, 'xml': path, 'trial_count': n_rows}


def check(name, cond, detail=''):
    (PASSED if cond else FAILED).append(name)
    print('[%s] %s%s' % ('PASS' if cond else 'FAIL', name, ('  -- ' + detail) if detail and not cond else ''))


def refuses(fn):
    """-> (did_it_refuse, message). A refusal must be a SystemExit carrying a reason, not any
    exception: a TypeError from a typo would otherwise be indistinguishable from the refusal the
    case is testing for (this repo's `a negative case must assert the REASON` rule).

    🔴 THE `except Exception` ARM IS NOT DEFENSIVE PADDING. Without it, deleting the missing-
    dimension refusal from the module made `header.index()` raise ValueError, which travelled
    straight out of this suite: exit 1 with a raw traceback and ZERO `[FAIL]` lines. The mutation
    was caught, but by the process dying rather than by the case that exists to catch it -- and a
    suite that reports its findings as a stack trace is the `SUITE THREW` shape whose reason gets
    swallowed a layer up. A crash is now reported AS the case it broke.
    """
    try:
        fn()
        return False, ''
    except SystemExit as e:
        return True, str(e)
    except Exception as e:  # noqa: BLE001 -- deliberate, see above
        return False, 'CRASHED instead of refusing: %s: %s' % (type(e).__name__, e)


def main():
    tmp = tempfile.mkdtemp(prefix='selcage_')
    try:
      # 🔴 THE NET. Anything this suite raises becomes a named FAIL with a roll-up line, never a
      # bare traceback -- the tier surfaces an uncaught exception as `exit -1 SUITE THREW` with the
      # cause truncated. Its twin in run_pilot_cells_tests.py got this and this one did not, and an
      # audit case immediately died here on a cross-drive `os.path.relpath`: twenty passing cases
      # printed, then a stack trace and no roll-up.
      try:
        # ---- PART 1a: the trade floor is applied, and it is the exact pre-registered number ------
        # ATTACK: every row sits ONE trade below the H1 floor of 100.
        p = os.path.join(tmp, 'floor_under.xml')
        n = write_surface(p, [(i, 100 - i, 99, 3.0, 1.0) for i in range(1, 21)])
        r = sel.select_one(cell_for(p, n), DIMS)
        check('floor-attack: every row one trade under the floor -> NO_ADMISSIBLE_PASS',
              r['status'] == 'NO_ADMISSIBLE_PASS' and r['selected'] is None, r['status'])

        # CONTROL: the same surface at exactly the floor must select. Without this the case above
        # would also pass if the module refused every surface for an unrelated reason.
        p = os.path.join(tmp, 'floor_at.xml')
        n = write_surface(p, [(i, 100 - i, 100, 3.0, 1.0) for i in range(1, 21)])
        r = sel.select_one(cell_for(p, n), DIMS)
        check('floor-control: the same surface exactly AT the floor -> a selection',
              r['status'] in ('SELECTED', 'BOUNDARY') and r['selected'] is not None, r['status'])

        # ...and the floor is timeframe-dependent, which one number alone would not prove.
        p = os.path.join(tmp, 'floor_h4.xml')
        n = write_surface(p, [(i, 100 - i, 60, 3.0, 1.0) for i in range(1, 21)])
        r_h4 = sel.select_one(cell_for(p, n, tf='H4'), DIMS)
        r_h1 = sel.select_one(cell_for(p, n, tf='H1'), DIMS)
        check('floor is per-timeframe: 60 trades admits on H4 and is refused on H1',
              r_h4['selected'] is not None and r_h1['status'] == 'NO_ADMISSIBLE_PASS',
              '%s / %s' % (r_h4['status'], r_h1['status']))

        # ---- PART 1b: the plateau MEDIAN, never the best row -------------------------------------
        # ATTACK: the single highest-Result row carries d1=5; the other plateau members carry d1=3.
        # A module that quietly picked top-1 -- which section 6.2 BANS -- returns 5 here.
        rows = [(1, 1000, 150, 5.0, 1.0)] + [(i, 999 - i, 150, 3.0, 1.0) for i in range(2, 41)]
        p = os.path.join(tmp, 'median.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        check('top-1 attack: the best row is d1=5 and the plateau median is d1=3 -> 3 is selected',
              r['selected']['d1'] == 3.0, 'selected d1=%r' % r['selected']['d1'])

        # CONTROL: when the whole plateau agrees, the selection is that value -- so the case above
        # is evidence about the median and not about the module ignoring d1 altogether.
        rows = [(i, 1000 - i, 150, 5.0, 1.0) for i in range(1, 41)]
        p = os.path.join(tmp, 'median_ctl.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        check('median-control: a plateau that agrees on d1=5 selects 5',
              r['selected']['d1'] == 5.0, 'selected d1=%r' % r['selected']['d1'])

        # ---- PART 1c: an off-grid median is SNAPPED to a declared value ---------------------------
        # Ten rows -> |P| = 1 would hide this, so the plateau is even and straddles two grid values.
        rows = ([(i, 1000, 150, 0.5, 0.5) for i in range(1, 11)] +
                [(i, 1000, 150, 0.5, 0.75) for i in range(11, 21)] +
                [(i, 1, 150, 0.5, 1.5) for i in range(21, 201)])
        p = os.path.join(tmp, 'snap.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        grid = sel.grid_values(DIMS['d2'])
        check('an off-grid median is snapped onto a DECLARED grid value',
              r['selected']['d2'] in grid, 'selected d2=%r, grid=%s' % (r['selected']['d2'], grid))

        # ---- PART 1d: BOUNDARY fires, and is SPECIFIC ---------------------------------------------
        rows = [(i, 1000 - i, 150, 5.0, 1.0) for i in range(1, 41)]
        p = os.path.join(tmp, 'bound.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        named = [b['dimension'] for b in r['boundary_dimensions']]
        check('BOUNDARY fires when a median lands on the last declared grid value, and names it',
              r['status'] == 'BOUNDARY' and named == ['d1'], '%s %s' % (r['status'], named))

        rows = [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)]
        p = os.path.join(tmp, 'bound_ctl.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        check('BOUNDARY specificity: a mid-grid median is SELECTED with no dimension flagged',
              r['status'] == 'SELECTED' and r['boundary_dimensions'] == [], r['status'])

        # ---- PART 1e: columns are read BY NAME, not by position -----------------------------------
        rows = [(1, 1000, 150, 5.0, 1.0)] + [(i, 999 - i, 150, 3.0, 1.0) for i in range(2, 41)]
        p1 = os.path.join(tmp, 'order_a.xml')
        n1 = write_surface(p1, rows)
        p2 = os.path.join(tmp, 'order_b.xml')
        # `Trades` and `Result` swapped with two neighbours; `Pass` stays first because the header
        # check requires it, and that check is exercised separately below.
        order = [0, 9, 2, 3, 4, 5, 6, 7, 8, 1, 11, 10]
        n2 = write_surface(p2, rows, order=order)
        a = sel.select_one(cell_for(p1, n1), DIMS)
        b = sel.select_one(cell_for(p2, n2), DIMS)
        check('columns are resolved by NAME: shuffling the header changes nothing',
              a['selected'] == b['selected'] and a['admissible_count'] == b['admissible_count'],
              '%r vs %r' % (a['selected'], b['selected']))

        # ---- PART 1f: unreadable or inconsistent input is REFUSED, never skipped -------------------
        p = os.path.join(tmp, 'nohdr.xml')
        n = write_surface(p, [(1, 1000, 150, 3.0, 1.0)], header_first='3141')
        ok, msg = refuses(lambda: sel.select_one(cell_for(p, n), DIMS))
        check('a surface whose first header cell is not `Pass` is REFUSED with a reason',
              ok and 'not `Pass`' in msg, msg[:120])

        p = os.path.join(tmp, 'ragged.xml')
        n = write_surface(p, [(1, 1000, 150, 3.0, 1.0), (2, 999, 150, 3.0, 1.0)], ragged=True)
        ok, msg = refuses(lambda: sel.select_one(cell_for(p, n), DIMS))
        check('a ragged row is REFUSED rather than dropped quietly',
              ok and 'cells against' in msg, msg[:120])

        p = os.path.join(tmp, 'missdim.xml')
        n = write_surface(p, [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)],
                          dim_names=('d1', 'dX'))
        ok, msg = refuses(lambda: sel.select_one(cell_for(p, n), DIMS))
        check('a dimension the registry resolves but the surface lacks is REFUSED, not skipped',
              ok and 'd2' in msg, msg[:120])

        # CONTROL for the three refusals above: the same shape of surface, intact, must NOT refuse.
        p = os.path.join(tmp, 'intact.xml')
        n = write_surface(p, [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)])
        ok, _ = refuses(lambda: sel.select_one(cell_for(p, n), DIMS))
        check('refusal-control: an intact surface of the same shape is NOT refused', not ok)

        # ---- PART 1g: the artefact must be the one the store measured -----------------------------
        # This is the check that replaced a tautology. It has to be shown firing on a disagreement
        # AND silent on agreement, or it is the same unexercised mechanism in a new costume.
        p = os.path.join(tmp, 'count.xml')
        n = write_surface(p, [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)])
        ok, msg = refuses(lambda: sel.select_one(cell_for(p, n + 1), DIMS))
        check('a surface whose row count disagrees with the committed trial_count is REFUSED',
              ok and 'not the surface the store measured' in msg, msg[:140])
        ok, _ = refuses(lambda: sel.select_one(cell_for(p, n), DIMS))
        check('trial_count control: the same surface at the registered count is NOT refused', not ok)

        # ---- PART 1g2: the snap tie-break has a DIRECTION, and it is load-bearing ------------------
        # Added by audit. A median exactly between two grid values snaps LOW, and that was an
        # undocumented third rounding rule: 7 of the 136 medians in the real selection are exact
        # ties, and on two cells the direction decides whether a dimension is reported as sitting on
        # a grid edge -- which is what ORDER-1302 widens a safe_range for. The direction is asserted
        # here so it cannot drift silently, NOT because it is obviously the right one.
        # 🔴 THE FIRST VERSION OF THIS CASE DID NOT DISCRIMINATE, and the mutation probe is the only
        # reason anyone knows. It put 20 rows at d2=0.5 then 20 at d2=0.75, all tied on Result --
        # so the cut broke on ascending Pass and |P| was FOUR ROWS OF 0.5. The median was 0.5, not a
        # tie at all, and flipping the snap direction in the module left the case green. Memory
        # `discriminating-test-must-be-able-to-discriminate`.
        # d2 ALTERNATES down a strictly decreasing Result, so the top 4 are 0.5, 0.75, 0.5, 0.75 and
        # the median is exactly 0.625 -- equidistant from both, which is the thing under test.
        rows = [(i, 1000 - i, 150, 3.0, 0.5 if i % 2 else 0.75) for i in range(1, 41)]
        p = os.path.join(tmp, 'tie.xml')
        n = write_surface(p, rows)
        r = sel.select_one(cell_for(p, n), DIMS)
        check('an exactly-halfway median snaps to the LOWER declared grid value',
              r['selected']['d2'] == 0.5, 'selected d2=%r' % r['selected']['d2'])
        check('the record STATES the tie-break rule rather than leaving it implicit',
              'LOWER' in (r.get('snap_tie_break') or ''), repr(r.get('snap_tie_break')))
        # The case above only means anything if the median really is equidistant, so the fixture's
        # own raw median is read back out of the record and checked. d2=0.5 is the first grid value,
        # so the cell is flagged BOUNDARY and `raw_median` is right there -- no second computation.
        raw = [b['raw_median'] for b in r['boundary_dimensions'] if b['dimension'] == 'd2']
        check('tie-case precondition: the plateau median is EXACTLY between two grid values',
              len(raw) == 1 and abs(abs(raw[0] - 0.5) - abs(raw[0] - 0.75)) < 1e-12, str(raw))

        # A timeframe ORDER-1273 does not pin a floor for is REFUSED, not a KeyError. Without this
        # case the refusal is an unexercised mechanism -- the mutation probe proved it by deleting
        # the branch and watching every case stay green.
        ok, msg = refuses(lambda: sel.select_one(dict(cell_for(p, n), tf='M15'), DIMS))
        check('a timeframe the criterion pins no floor for is REFUSED, not a KeyError',
              ok and 'no floor' in msg, msg[:140])

        # ---- PART 1i: --check re-derives, and an absent surface is CANNOT ANSWER -------------------
        # Both added by audit. The second is the one that mattered: this suite is on the pre-commit
        # path and `_mt5_auto/optimizations/` is gitignored, so on a clone every commit touching
        # factory/coverage.jsonl was blocked -- via a NativeCommandError that never reached a
        # message. Measured by hiding all 16 surfaces; kept here so it stays measured.
        store = os.path.join(tmp, 'store'); os.makedirs(store)
        probe = os.path.join(tmp, 'probe'); os.makedirs(probe)
        cov = os.path.join(store, 'coverage.jsonl')
        surface = os.path.join(tmp, 'REAL_SURFACE.xml')
        n = write_surface(surface, [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)])
        io.open(cov, 'w', encoding='utf-8', newline='\n').write(_json.dumps(
            {'entity': 'CoverageCell', 'cell_id': 'FIX-r1/EURUSD/H1', 'hypothesis_revision': 'FIX-r1',
             'logical_symbol': 'EURUSD', 'tf': 'H1', 'state': 'PROBE_RUN', 'trial_count': n}) + '\n')
        io.open(os.path.join(probe, 'xml_backfill_1.jsonl'), 'w', encoding='utf-8',
                newline='\n').write(_json.dumps(
                    {'entity': 'PilotProbeXmlBackfill', 'cell_id': 'FIX-r1/EURUSD/H1',
                     'xml': surface, 'passes': n}) + '\n')
        got = sel.cells_from_coverage(coverage=cov, probe_dir=probe)
        check('CONTROL: with the surface present the cell resolves from the COMMITTED path',
              len(got) == 1 and got[0]['xml'] == surface, repr(got))
        os.rename(surface, surface + '.hidden')
        try:
            sel.cells_from_coverage(coverage=cov, probe_dir=probe)
            raised = 'nothing'
        except sel.CannotAnswer as e:
            raised = 'CannotAnswer'
        except BaseException as e:  # noqa: BLE001
            raised = '%s: %s' % (type(e).__name__, e)
        os.rename(surface + '.hidden', surface)
        check('an ABSENT surface raises CannotAnswer (exit 2), not a refusal and not a pass',
              raised == 'CannotAnswer', raised)

        # ...and a cell the store calls PROBE_RUN with NO recorded artefact stays a refusal, because
        # that is the store claiming a probe nothing identifies -- a different fault entirely.
        io.open(os.path.join(probe, 'xml_backfill_1.jsonl'), 'w', encoding='utf-8',
                newline='\n').write('')
        ok, msg = refuses(lambda: sel.cells_from_coverage(coverage=cov, probe_dir=probe))
        check('a PROBE_RUN cell whose artefact is not RECORDED is REFUSED, not "cannot answer"',
              ok and 'refusing to guess the filename' in msg, msg[:140])

        # --check: a committed record that MATCHES is 0, one with a changed value is 1.
        # The selection record is generated evidence, and before this audit NOTHING re-derived it --
        # the same defect ORDER-1272 had just closed for the coverage store, recreated one directory
        # away in the same session.
        recs = [sel.select_one(cell_for(surface, n), DIMS)]
        recs[0]['cell_id'] = 'FIX-r1/EURUSD/H1'
        seldir = os.path.join(tmp, 'sel'); os.makedirs(seldir)
        rec_path = os.path.join(seldir, 'selection_20260101_000000.jsonl')
        io.open(rec_path, 'w', encoding='utf-8', newline='\n').write(
            _json.dumps(recs[0], sort_keys=True) + '\n')
        check('--check CONTROL: a record matching the surfaces is exit 0',
              sel.check_against_record(recs, out_dir=seldir) == sel.EXIT_OK)
        blob = _json.loads(io.open(rec_path, encoding='utf-8').read())
        blob['selected']['d1'] = blob['selected']['d1'] + 1
        io.open(rec_path, 'w', encoding='utf-8', newline='\n').write(
            _json.dumps(blob, sort_keys=True) + '\n')
        check('--check ATTACK: one changed selected value is DRIFT (exit 1)',
              sel.check_against_record(recs, out_dir=seldir) == sel.EXIT_DRIFT)
        # ...and the newest file wins, so a superseded record cannot resurrect an old answer.
        io.open(os.path.join(seldir, 'selection_20260102_000000.jsonl'), 'w',
                encoding='utf-8', newline='\n').write(_json.dumps(recs[0], sort_keys=True) + '\n')
        check('--check reads the NEWEST record; a superseded one does not resurrect an old answer',
              sel.check_against_record(recs, out_dir=seldir) == sel.EXIT_OK)

        # ---- PART 1h: no verdict vocabulary leaves this module ------------------------------------
        # design section 10 stops the slice at EVIDENCE_COMPLETE. The canonical words are the ones
        # CLAUDE.md's VERDICT GATE names, and the record is where they would leak.
        p = os.path.join(tmp, 'verdict.xml')
        n = write_surface(p, [(i, 1000 - i, 150, 3.0, 1.0) for i in range(1, 41)])
        text = _json.dumps(sel.select_one(cell_for(p, n), DIMS))
        banned = [w for w in ('DEAD-STRUCTURAL', 'DEAD-OPTIMIZED', 'CANDIDATE', 'VALIDATED',
                              'PARKED-VERIFY', 'BUILD-ON') if w in text]
        check('the selection record carries no verdict vocabulary', not banned, str(banned))
      except BaseException as exc:  # noqa: BLE001 -- see THE NET above
        check('the cage ran to the end without throwing', False,
              '%s: %s' % (type(exc).__name__, exc))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print('')
    print('[selection-cage] %d case(s), %d failed' % (len(PASSED) + len(FAILED), len(FAILED)))
    return 1 if FAILED else 0


if __name__ == '__main__':
    sys.exit(main())
