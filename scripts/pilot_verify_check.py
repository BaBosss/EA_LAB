"""Re-derive everything in a verification record that CAN be re-derived, and report drift.

WHY THIS EXISTS
  `factory/runs/pilot/verification/` is generated evidence. ORDER-1272 closed exactly this defect
  for `factory/coverage.jsonl` ("nothing re-derives this store"), and the very next lane recreated
  it one directory away for `factory/runs/pilot/selection/`. This store was the third instance. The
  question to ask of every generated artefact is: WHAT RE-DERIVES IT, AND WHAT RUNS THAT?

WHAT CAN AND CANNOT BE RE-DERIVED, stated rather than blurred
  The tester run itself cannot be: reproducing it needs MT5, hours, and -- as this lane measured --
  does not even reproduce across days (see below). What CAN be re-derived is everything the record
  claims to have READ out of that run:
      * every metric, through scripts/parse_mt5_report.py, from the .htm the record names
      * the carried-at-end figures, through scripts/pilot_carried.py
      * the PF-undefined judgement, which is a pure function of gross_loss and total_trades
      * the surface reference row, through scripts/pilot_selected_surface_row.py
  So this answers "does the record still say what those artefacts say", which is the half that rots.

  🔴 IT DOES NOT ANSWER "would the tester produce these numbers again", and must never be read as
  if it did. Measured by this lane on B14-H01-r1/BTCUSD/H4 with the config hash, the data
  fingerprint, the .set bytes, the .ex5 mtime, the terminal build and the bar/tick counts ALL
  identical: net profit 332.50 on 2026-08-03 against 324.75 on 2026-08-04, twice, the two 08-04
  runs byte-identical to each other. Same-session reproducible, cross-session not.

THREE EXIT CODES, BECAUSE THERE ARE THREE ANSWERS
  0 = the record matches what the artefacts say now.
  1 = DRIFT: an artefact is readable and disagrees with the record.
  2 = the artefacts are NOT ON THIS MACHINE. `_mt5_auto/reports/` is gitignored by design (3-4 MB
      per report), so on any clone that legitimately lacks them this must be reported and skipped,
      never merged with "the evidence is wrong" and never with a pass. A suite on the commit path
      that asserts against gitignored artefacts blocks every commit on such a clone, through an
      error that prints none of its own messages -- this repo has already paid for that once.

USAGE
  python scripts/pilot_verify_check.py [--record PATH] [--dir DIR]
"""
import glob
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PY = os.path.join(ROOT, 'tools', 'python312', 'python.exe')

# Compared with a tolerance rather than by equality: these are floats that made a round trip through
# JSON. The tolerance is far below the smallest difference that would matter (the smallest drift
# this lane measured on a real artefact is 0.02 on a percentage).
TOL = 1e-6

# The fields re-read from the report. `pf` is deliberately NOT here -- it is re-derived from
# gross_loss/total_trades below through the same rule the runner used, because the point is to catch
# a record that says PF where the report says no denominator.
METRIC_FIELDS = {
    'trades': 'total_trades',
    'dd_pct': 'equity_drawdown_maximal_pct',
    'gross_profit': 'gross_profit',
    'gross_loss': 'gross_loss',
    'net_profit': 'net_profit',
    'long_trades': 'long_trades',
    'short_trades': 'short_trades',
    'bars': 'bars',
    'ticks': 'ticks',
}


def _stdout():
    """utf-8 stdout that survives being called twice in one process.

    A child of the pre-commit hook inherits an ANSI pipe and the first non-cp1252 glyph raises
    UnicodeEncodeError, which surfaces as an unexplained non-zero exit with the cause swallowed
    (memory thai-output-kills-a-suite-inside-the-hook) -- so the encoding has to be forced. It is
    forced by reconfiguring the existing stream rather than by wrapping sys.stdout.buffer, because
    a wrapper closes that buffer when it is collected.
    """
    try:
        sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    except (AttributeError, ValueError):
        pass
    return sys.stdout


def _num(text):
    if text is None:
        return None
    s = str(text).strip()
    if s == '':
        return None
    keep = ''.join(c for c in s if c.isdigit() or c in '.-')
    try:
        return float(keep)
    except ValueError:
        return None


def _run(args):
    p = subprocess.run([PY] + args, capture_output=True, text=True, encoding='utf-8')
    if p.returncode != 0:
        raise RuntimeError('%s failed (%d): %s' % (os.path.basename(args[0]), p.returncode,
                                                   (p.stderr or p.stdout or '').strip()[:400]))
    return p.stdout


def parse_report(htm):
    out = _run([os.path.join(ROOT, 'scripts', 'parse_mt5_report.py'), htm])
    m = {}
    for line in out.splitlines():
        if ':' in line:
            k, v = line.split(':', 1)
            m[k.strip()] = v.strip()
    return m


STAMP = re.compile(r'_(\d{8}_\d{6})\.jsonl$')


def newest_record(directory):
    """-> the record with the latest TIMESTAMP, or None.

    🔴 NOT lexicographic on the filename, and the difference is not cosmetic. Records are named
    `verification_<WINDOW><lottag>_<YYYYMMDD_HHMMSS>.jsonl`, so a plain sort orders by WINDOW first:
    `verification_MAIN_...` sorts after `verification_BWD_...` whatever the dates say, and the
    moment ORDER-1254 writes a BWD record beside a MAIN one, "the newest record" would silently
    mean "the alphabetically last window". Caught by run_pilot_verify_tests.py, before a BWD record
    existed to be got wrong.

    A filename carrying no timestamp is NAMED and skipped rather than sorted by fallback -- a
    silent fallback is how the lexicographic rule would come back.
    """
    cands, unstamped = [], []
    for p in glob.glob(os.path.join(directory, 'verification_*.jsonl')):
        m = STAMP.search(os.path.basename(p))
        if m:
            cands.append((m.group(1), p))
        else:
            unstamped.append(os.path.basename(p))
    if unstamped:
        sys.stderr.write('[verify-check] ignoring %d record(s) with no _YYYYMMDD_HHMMSS stamp: %s\n'
                         % (len(unstamped), ', '.join(sorted(unstamped))))
    if not cands:
        return None
    return max(cands)[1]


def check(record_path):
    """-> (problems, skipped, checked_rows). `skipped` non-empty means exit 2, not exit 0."""
    problems, skipped, checked = [], [], 0
    rows = []
    for line in io.open(record_path, encoding='utf-8'):
        if line.strip():
            rows.append(json.loads(line))
    if not rows:
        problems.append('%s has no rows -- an empty record must not pass as "nothing drifted"'
                        % os.path.basename(record_path))
        return problems, skipped, checked

    for rec in rows:
        cell = rec.get('cell_id', '<no cell_id>')
        htm = rec.get('report')
        if not htm or not os.path.exists(htm):
            skipped.append('%s: report not on this machine (%s)' % (cell, htm))
            continue
        checked += 1
        m = parse_report(htm)

        for field, key in METRIC_FIELDS.items():
            want, got = rec.get(field), _num(m.get(key))
            if want is None and got is None:
                continue
            if want is None or got is None or abs(float(want) - float(got)) > TOL:
                problems.append('%s: %s recorded %r, report says %r' % (cell, field, want, got))

        # The PF rule, re-applied rather than re-read. A record claiming a PF where the report has
        # no losing trade is the single most invertible error in this pipeline.
        gl, tr = _num(m.get('gross_loss')), _num(m.get('total_trades'))
        undefined = (gl is not None and gl == 0 and tr is not None and tr > 0)
        if bool(rec.get('pf_undefined')) != undefined:
            problems.append('%s: pf_undefined recorded %r, the report implies %r (gross_loss=%r, '
                            'trades=%r)' % (cell, rec.get('pf_undefined'), undefined, gl, tr))
        if undefined:
            if rec.get('pf') is not None:
                problems.append('%s: pf recorded %r but the report has no losing trade, so PF has '
                                'no denominator' % (cell, rec.get('pf')))
        else:
            want, got = rec.get('pf'), _num(m.get('profit_factor'))
            if want is None or got is None or abs(float(want) - float(got)) > TOL:
                problems.append('%s: pf recorded %r, report says %r' % (cell, want, got))

        carried = json.loads(_run([os.path.join(ROOT, 'scripts', 'pilot_carried.py'), htm]))
        if not carried.get('readable'):
            problems.append('%s: pilot_carried.py cannot read the Deals table of %s' % (cell, htm))
        else:
            for field, key in (('carried_at_end_count', 'carried_count'),
                               ('carried_at_end_profit', 'carried_profit')):
                want, got = rec.get(field), carried.get(key)
                if want is None or got is None or abs(float(want) - float(got)) > TOL:
                    problems.append('%s: %s recorded %r, the report says %r'
                                    % (cell, field, want, got))

        # The surface side. Re-asked from the surface rather than trusted from the record, because
        # it is the half that decides whether the number had anything to be checked against.
        sel_rec = rec.get('selection_record')
        if sel_rec and os.path.exists(sel_rec):
            out = _run([os.path.join(ROOT, 'scripts', 'pilot_selected_surface_row.py'),
                        sel_rec, '--cell', cell])
            sr = json.loads(out.splitlines()[0])
            if bool(sr['evaluated_on_surface']) != bool(rec.get('selected_point_evaluated_on_surface')):
                problems.append('%s: selected_point_evaluated_on_surface recorded %r, the surface '
                                'says %r' % (cell, rec.get('selected_point_evaluated_on_surface'),
                                             sr['evaluated_on_surface']))
            if json.dumps(sr['matching_rows'], sort_keys=True) != \
               json.dumps(rec.get('surface_reference_rows') or [], sort_keys=True):
                problems.append('%s: surface_reference_rows recorded %r, the surface says %r'
                                % (cell, rec.get('surface_reference_rows'), sr['matching_rows']))
        else:
            skipped.append('%s: selection record not on this machine (%s)' % (cell, sel_rec))

    return problems, skipped, checked


def main(argv):
    record = None
    directory = os.path.join(ROOT, 'factory', 'runs', 'pilot', 'verification')
    if '--record' in argv:
        record = argv[argv.index('--record') + 1]
    if '--dir' in argv:
        directory = argv[argv.index('--dir') + 1]
    if record is None:
        record = newest_record(directory)
    # RECONFIGURE, DO NOT WRAP. `io.TextIOWrapper(sys.stdout.buffer, ...)` closes the underlying
    # buffer when it is collected, so the FIRST in-process caller of main() silently kills stdout
    # for everything after it -- which is exactly how run_pilot_verify_tests.py died on its own
    # second case, reporting a ValueError instead of the case's result. Found by the cage, on the
    # cage's first run.
    out = _stdout()
    if record is None or not os.path.exists(record):
        out.write('[verify-check] no verification record under %s -- nothing to check\n' % directory)
        out.flush()
        return 2
    problems, skipped, checked = check(record)
    for s in skipped:
        out.write('[verify-check] SKIPPED %s\n' % s)
    if problems:
        out.write('[verify-check] DRIFT in %s\n' % record)
        for p in problems:
            out.write('  %s\n' % p)
        # THE REMEDY IS PRINTED BY THE TOOL THAT KNOWS IT, not by each caller. Callers that repeated
        # the runner's path in their own prose tripped the trigger-map guard, which cannot tell a
        # path that is READ from a path that is merely MENTIONED -- and the fix of declaring a
        # dependency that does not exist would have been worse than the message.
        out.write('  REMEDY: this store is GENERATED. Re-run scripts/pilot_verify_selected.ps1 to '
                  'rebuild it, or explain the row. Do not hand-edit it.\n')
        out.flush()
        return 1
    if checked == 0:
        # NOT a pass. Zero rows checked with rows present means every artefact is missing, and a 0
        # here would report "nothing drifted" about a file nobody was able to open.
        out.write('[verify-check] %s: 0 row(s) could be checked -- the reports are not on this '
                  'machine\n' % record)
        out.flush()
        return 2
    out.write('[verify-check] %s: %d row(s) still match their report, their carried figures and '
              'their surface reference\n' % (os.path.relpath(record, ROOT).replace('\\', '/'), checked))
    if skipped:
        out.write('[verify-check] %d row(s) skipped as not-on-this-machine (see above)\n' % len(skipped))
        out.flush()
        return 2
    out.flush()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
