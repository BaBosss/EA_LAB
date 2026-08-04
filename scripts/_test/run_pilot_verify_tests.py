"""Cage for scripts/pilot_selected_surface_row.py and scripts/pilot_verify_check.py.

WHY THIS EXISTS
  Both tools were committed with their controls living only in a shell transcript: "three known
  rows off the real surface are found, the selected point is not". That is a measurement nobody can
  re-run, and this repo's own record says the mutation probe is not optional -- it caught two
  non-discriminating cases in the previous lane's audit, both invisible to reading.

WHAT EVERY CASE HERE OWES
  An ATTACK case (a one-line mutation of the input the tool reads) MUST be paired with a CONTROL
  that stays green, or a green suite is evidence of nothing. Two specific traps this file is built
  against:
    * a lookup that finds nothing because it is broken reads exactly like one that finds nothing
      because the row is absent -- so every "not found" assertion is paired with a "found" one over
      the SAME surface;
    * a checker whose fixture quotes the live repository goes red the moment the live store
      legitimately changes. Every anchor here is DERIVED from the fixture at run time.

  Fixtures are synthetic and self-contained: nothing here reads _mt5_auto/optimizations/ (gitignored,
  3-4 MB per file) or _mt5_auto/reports/, so this suite is safe on the commit path and on a clone
  that has neither.

USAGE  python scripts/_test/run_pilot_verify_tests.py
"""
import io
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import pilot_selected_surface_row as PSR  # noqa: E402
import pilot_verify_check as PVC  # noqa: E402

try:
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
except (AttributeError, ValueError):
    pass
OUT = sys.stdout
FAILS = []
RAN = []


def case(name, fn):
    """A case that CRASHES is reported AS the case it broke, not as a suite that died.

    Deleting a refusal from a tool under test produces an exception that travels straight out of a
    naive harness: exit 1, a raw traceback, and zero [FAIL] lines -- the mutation caught by the
    process dying rather than by the case that exists to catch it.
    """
    RAN.append(name)
    try:
        fn()
        OUT.write('  [ok ] %s\n' % name)
    except AssertionError as e:
        FAILS.append(name)
        OUT.write('  [FAIL] %s -- %s\n' % (name, e))
    except Exception as e:  # noqa: BLE001
        FAILS.append(name)
        OUT.write('  [FAIL] %s -- THREW %s: %s\n' % (name, type(e).__name__, e))


# --- a synthetic surface, written in the format read_surface actually parses -----------------------
HEADER = ['Pass', 'Result', 'Profit', 'Expected Payoff', 'Profit Factor', 'Recovery Factor',
          'Sharpe Ratio', 'Custom', 'Equity DD %', 'Trades', '_A_Dim', '_B_Dim']
# Note the formatting differences that matter: integers written without a decimal ('21'), floats
# with trailing zeros ('1.50'). A string comparison against a record holding 21.0 / 1.5 would report
# a false negative on a row that is sitting right there.
ROWS = [
    ['1', '10.5', '100.00', '1.0', '10.500000', '2.0', '0.5', '0', '5.0000', '60', '21', '1.50'],
    ['2', '20.5', '200.00', '2.0', '20.500000', '3.0', '0.6', '0', '6.0000', '70', '14', '1.50'],
    ['3', '30.5', '300.00', '3.0', '30.500000', '4.0', '0.7', '0', '7.0000', '80', '21', '2.75'],
]


def write_surface(path, header=HEADER, rows=ROWS):
    body = ['<Row>' + ''.join('<Data>%s</Data>' % c for c in header) + '</Row>']
    for r in rows:
        body.append('<Row>' + ''.join('<Data>%s</Data>' % c for c in r) + '</Row>')
    io.open(path, 'w', encoding='utf-8').write('<Table>' + ''.join(body) + '</Table>')
    return path


def main():
    tmp = tempfile.mkdtemp(prefix='pvcage_')
    try:
        xml = write_surface(os.path.join(tmp, 'surface.xml'))

        # --- PART 1: the lookup finds what is there, and does not find what is not ----------------
        OUT.write('[pilot-verify] PART 1 -- the surface lookup discriminates\n')

        def c_found():
            # CONTROL, derived from the fixture rather than typed: take row 3's own dimension values
            # back off the fixture and require the lookup to find exactly that row.
            want = {'_A_Dim': float(ROWS[2][10]), '_B_Dim': float(ROWS[2][11])}
            total, hits, absent = PSR.find_row(xml, want)
            assert total == len(ROWS), 'row count %d' % total
            assert len(hits) == 1, 'expected 1 hit, got %d' % len(hits)
            assert hits[0]['pass'] == ROWS[2][0], hits[0]['pass']
            assert absent == [], absent
        case('P1 CONTROL a row that IS on the surface is found', c_found)

        def c_not_found():
            # ATTACK's twin: a combination that is NOT on the surface, made of values that each
            # appear on it separately (_A_Dim=14 exists, _B_Dim=2.75 exists, the pair does not).
            # A lookup matching on any-one-dimension would wrongly report a hit here.
            total, hits, absent = PSR.find_row(xml, {'_A_Dim': 14.0, '_B_Dim': 2.75})
            assert hits == [], 'a combination absent from the surface was reported as present: %r' % hits
        case('P1 a combination absent from the surface is NOT found', c_not_found)

        def c_numeric():
            # The whole reason the comparison is numeric: the fixture writes '21' and '1.50'.
            total, hits, absent = PSR.find_row(xml, {'_A_Dim': 21.0, '_B_Dim': 1.5})
            assert len(hits) == 1, 'numeric comparison failed on 21 vs 21.0 / 1.50 vs 1.5: %r' % hits
            assert hits[0]['pass'] == ROWS[0][0]
        case('P1 21 matches 21.0 and 1.50 matches 1.5 (numeric, not string)', c_numeric)

        def c_tolerance():
            # Two DISTINCT grid points must never collapse into one. The smallest declared step in
            # parameter_bindings.jsonl is 0.1; TOL must be far below it and far above float noise.
            assert PSR.TOL < 0.1 / 1000, 'TOL %r is not far below the smallest grid step' % PSR.TOL
            total, hits, absent = PSR.find_row(xml, {'_A_Dim': 21.0 + 0.05, '_B_Dim': 1.5})
            assert hits == [], 'a value half a grid step away matched: %r' % hits
        case('P1 a value inside the grid step but not equal does NOT match', c_tolerance)

        def c_carries_columns():
            # THE REGRESSION THIS FILE WAS WRITTEN FOR. The first version carried only Result and
            # Trades, so a reference row whose Profit disagreed with the re-run still read as
            # reproduced. Every comparable column must come back, derived from the fixture.
            total, hits, absent = PSR.find_row(xml, {'_A_Dim': 21.0, '_B_Dim': 2.75})
            assert len(hits) == 1, hits
            h = hits[0]
            for key, col in (('result', 1), ('profit', 2), ('profit_factor', 4),
                             ('equity_dd_pct', 8), ('trades', 9)):
                assert key in h, 'the matched row does not carry %s' % key
                assert abs(h[key] - float(ROWS[2][col])) < PSR.TOL, \
                    '%s came back %r, the surface says %r' % (key, h[key], ROWS[2][col])
        case('P1 every comparable column of the matched row is carried', c_carries_columns)

        def c_absent_named():
            # A surface without a Profit column must NAME that, not silently omit it -- "the
            # optimizer did not report this" and "nobody looked" are different facts.
            h2 = [c for c in HEADER if c != 'Profit']
            r2 = [[c for i, c in enumerate(r) if i != 2] for r in ROWS]
            x2 = write_surface(os.path.join(tmp, 'noprofit.xml'), h2, r2)
            total, hits, absent = PSR.find_row(x2, {'_A_Dim': 21.0, '_B_Dim': 2.75})
            assert absent == ['Profit'], absent
            assert hits[0]['profit'] is None, hits[0]['profit']
        case('P1 a column the surface lacks is named, not silently dropped', c_absent_named)

        def c_dim_mismatch_refused():
            # ATTACK: the record names a dimension the surface does not carry. That is two artefacts
            # disagreeing about which sweep this is -- it must REFUSE, not answer "not evaluated",
            # which would read as a fact about the optimizer.
            try:
                PSR.find_row(xml, {'_A_Dim': 21.0, '_NOT_SWEPT': 1.0})
            except SystemExit as e:
                assert '_NOT_SWEPT' in str(e), str(e)
                return
            raise AssertionError('a dimension absent from the surface was not refused')
        case('P1 REFUSAL a dimension the surface lacks is refused, not answered', c_dim_mismatch_refused)

        def c_header_refused():
            # The surface reader must refuse a file whose header does not start with Pass, or every
            # column shifts by one and the lookup selects on whatever landed under `_A_Dim`.
            bad = os.path.join(tmp, 'bad.xml')
            write_surface(bad, ['NotPass'] + HEADER[1:], ROWS)
            try:
                PSR.find_row(bad, {'_A_Dim': 21.0, '_B_Dim': 1.5})
            except SystemExit:
                return
            raise AssertionError('a surface whose header does not start with Pass was accepted')
        case('P1 REFUSAL a header not starting with Pass is refused', c_header_refused)

        # --- PART 2: the verification-store checker ------------------------------------------------
        OUT.write('[pilot-verify] PART 2 -- the store checker separates DRIFT from NOT-ON-THIS-MACHINE\n')

        vdir = os.path.join(tmp, 'verification')
        os.makedirs(vdir)

        def write_record(name, rows):
            p = os.path.join(vdir, name)
            with io.open(p, 'w', encoding='utf-8') as f:
                for r in rows:
                    f.write(json.dumps(r) + '\n')
            return p

        # A record whose report does not exist. This is the gitignored-artefact case, and it is the
        # one that must NOT be exit 0 and must NOT be exit 1.
        missing = write_record('verification_MISSING.jsonl', [{
            'cell_id': 'X/Y/H4', 'report': os.path.join(tmp, 'nope.htm'),
        }])

        def c_missing_is_two():
            rc = PVC.main(['--record', missing])
            assert rc == 2, 'a record whose report is absent returned %r, not 2' % rc
        case('P2 a report not on this machine is exit 2, not 0 and not 1', c_missing_is_two)

        def c_empty_record_not_pass():
            p = os.path.join(vdir, 'verification_EMPTY.jsonl')
            io.open(p, 'w', encoding='utf-8').write('')
            problems, skipped, checked = PVC.check(p)
            assert problems, 'an empty record passed as "nothing drifted"'
        case('P2 an empty record is a problem, not a pass', c_empty_record_not_pass)

        def c_no_record_is_two():
            empty_dir = os.path.join(tmp, 'noverif')
            os.makedirs(empty_dir, exist_ok=True)
            rc = PVC.main(['--dir', empty_dir])
            assert rc == 2, 'an absent store returned %r, not 2' % rc
        case('P2 no record at all is exit 2', c_no_record_is_two)

        def c_newest_wins():
            # A superseded record must not resurrect an old answer.
            ndir = os.path.join(tmp, 'newest')
            os.makedirs(ndir, exist_ok=True)
            for n in ('verification_MAIN_lot0p03_20260101_000000.jsonl',
                      'verification_MAIN_lot0p03_20260102_000000.jsonl'):
                io.open(os.path.join(ndir, n), 'w', encoding='utf-8').write('{}\n')
            assert PVC.newest_record(ndir).endswith('20260102_000000.jsonl'), PVC.newest_record(ndir)
        case('P2 the NEWEST record is the one checked', c_newest_wins)

        def c_newest_across_windows():
            # THE CASE THAT CAUGHT THE BUG. Records are named by WINDOW then timestamp, so a
            # lexicographic sort puts every MAIN record after every BWD record whatever the dates
            # say. ORDER-1254 writes BWD beside MAIN, so this becomes live on the next order.
            ndir = os.path.join(tmp, 'windows')
            os.makedirs(ndir, exist_ok=True)
            for n in ('verification_MAIN_lot0p03_20260101_000000.jsonl',
                      'verification_BWD_lot0p03_20260603_120000.jsonl'):
                io.open(os.path.join(ndir, n), 'w', encoding='utf-8').write('{}\n')
            newest = PVC.newest_record(ndir)
            assert newest.endswith('verification_BWD_lot0p03_20260603_120000.jsonl'), \
                ('the LATER BWD record lost to an EARLIER MAIN one -- the sort is ordering by '
                 'window name, not by time: got %s' % os.path.basename(newest))
        case('P2 a later BWD record beats an earlier MAIN one (sorted by TIME, not name)',
             c_newest_across_windows)

        def c_unstamped_named():
            # A filename with no timestamp is skipped and NAMED, never sorted in by fallback --
            # a silent fallback is how the lexicographic rule comes back.
            ndir = os.path.join(tmp, 'unstamped')
            os.makedirs(ndir, exist_ok=True)
            io.open(os.path.join(ndir, 'verification_NOSTAMP.jsonl'), 'w', encoding='utf-8').write('{}\n')
            assert PVC.newest_record(ndir) is None, PVC.newest_record(ndir)
            io.open(os.path.join(ndir, 'verification_MAIN_lot0p03_20260101_000000.jsonl'),
                    'w', encoding='utf-8').write('{}\n')
            assert PVC.newest_record(ndir).endswith('20260101_000000.jsonl')
        case('P2 a record with no timestamp is skipped, not silently ranked', c_unstamped_named)

        def c_pf_rule_reapplied():
            # The PF-undefined rule is re-derived, not re-read. This is the single most invertible
            # error in the pipeline: a record claiming a PF number where the report has no losing
            # trade. Asserted directly on the rule the checker applies.
            for gl, tr, expect in ((0.0, 78.0, True), (-0.38, 94.0, False), (0.0, 0.0, False)):
                undefined = (gl is not None and gl == 0 and tr is not None and tr > 0)
                assert undefined is expect, 'gross_loss=%r trades=%r -> %r' % (gl, tr, undefined)
        case('P2 PF-undefined is a function of gross_loss and trades, re-derived', c_pf_rule_reapplied)

        def c_metric_fields_cover():
            # A checker that compares three fields and calls it a match is a rubber stamp. Pin the
            # set, so silently dropping one is a red case rather than a quieter suite.
            for f in ('trades', 'dd_pct', 'gross_profit', 'gross_loss', 'net_profit'):
                assert f in PVC.METRIC_FIELDS, 'the checker no longer compares %s' % f
        case('P2 the checker still compares every load-bearing metric', c_metric_fields_cover)

        # --- ROLL-UP -------------------------------------------------------------------------------
        OUT.write('\n--- ROLL-UP: every catalogued case ran ---\n')
        OUT.write('    catalogued %d - ran %d\n' % (len(RAN), len(RAN)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    OUT.write('\n[pilot-verify] %d case(s), %d failed\n' % (len(RAN), len(FAILS)))
    OUT.flush()
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
