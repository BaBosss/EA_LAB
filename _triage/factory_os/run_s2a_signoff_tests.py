"""
run_s2a_signoff_tests.py - ORDER-602 A + D: prove the sign-off log accepts a real approval and
refuses every malformed or stale one.

THE CASE THAT MATTERS MOST IS THE POSITIVE ONE. The entire justification for this artifact is that an
owner can now record `APPROVED` **without editing any guard, generator or proposal byte** -- so the
first assertion below appends a real approval and requires it to be accepted with
`check_s2a_migration.py` and `gen_s2a_migration.py` untouched. If that ever goes red the deadlock is
back, whatever the negatives say.

Every case runs against a TEMPORARY copy of the log. The real
`_triage/factory_os/s2a_signoff.jsonl` is never written by this suite, and that is asserted at the end
-- a test that can approve the proposal it is testing would be its own worst finding.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s2a_signoff_tests.py
"""
import io
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk      # noqa: E402
import check_s2a_signoff as so         # noqa: E402


def run_with(lines, vintage=()):
    """Point the checker at a temp log and return its problems."""
    saved = so.SIGNOFF_PATH
    fd, tmp = tempfile.mkstemp(suffix='.jsonl')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            for obj in lines:
                fh.write(json.dumps(obj, sort_keys=True) + '\n')
        so.SIGNOFF_PATH = tmp
        rows, problems = so.load_signoffs()
        d1 = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
        owners = sorted({r['current_owner'] for r in d1})
        current = so.check(rows, problems, so.proposal_digest(), owners, vintage)
        return current, '\n'.join(problems)
    finally:
        so.SIGNOFF_PATH = saved
        try:
            os.unlink(tmp)
        except OSError:
            pass


def good(**over):
    row = {'proposal_sha256': so.proposal_digest(),
           'current_owner': 'MASTER_BACKLOG.md',
           'decision': 'APPROVED',
           'signer': 'user (Boss)',
           'decided_at': '2026-07-30T23:30',
           'reason': 'coverage transfer accepted, banner change ships with the first generation'}
    row.update(over)
    return row


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    before = io.open(so.SIGNOFF_PATH, encoding='utf-8').read() if os.path.exists(so.SIGNOFF_PATH) else None
    bad = 0

    print('=== THE POINT: an owner can APPROVE with no guard, generator or proposal edit ===')
    current, problems = run_with([good()])
    ok = (not problems) and current.get('MASTER_BACKLOG.md', {}).get('decision') == 'APPROVED'
    print('  [%s] a well-formed APPROVED for the Coverage owner is ACCEPTED' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (problems or 'not recorded as the current decision'))
        bad += 1
    # ...and prove the guard that refuses APPROVED *inside D1* is still armed, since that is the
    # protection this artifact was allowed to keep rather than replace.
    d1_rows = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    probe = [dict(r) for r in d1_rows]
    probe[0]['signoff_state'] = 'APPROVED'
    p2 = []
    chk.c2_no_approved(probe, p2)
    ok = any('APPROVED' in x for x in p2)
    print('  [%s] and C2 still REFUSES signoff_state=APPROVED inside D1 (unchanged)'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1

    print('\n=== negatives: each must be refused BY NAME ===')
    cases = [
        ('S1 a missing required field',
         [good(signer='')], 'is missing'),
        ('S1 an invented decision value',
         [good(decision='MAYBE')], 'not one of'),
        ('S2 a signature bound to different bytes',
         [good(proposal_sha256='a' * 64)], 'the proposal changed'),
        ('S4 a decision for an owner not in D1',
         [good(current_owner='no/such/owner.md')], 'not a current_owner'),
        ('S5 REFUSED with no reason',
         [good(decision='REFUSED', reason='')], 'is missing'),
        ('S6 signing an owner whose pin has gone stale',
         [good()], 'pin is STALE'),
        # /scrutinize ORDER-602 H3
        ('S4 a decision for an EMBEDDED pseudo-owner',
         [good(current_owner='EMBEDDED:RunTransition')], 'follows its parent'),
    ]
    for label, lines, expect in cases:
        vintage = ([{'entity': 'CoverageCell', 'path': 'MASTER_BACKLOG.md', 'kind': 'STALE',
                     'text': 'stale'}],) if 'S6' in label else ()
        _, problems = run_with(lines, vintage[0] if vintage else ())
        ok = expect in problems
        print('  [%s] %-46s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                  'RED ' if problems else 'GREEN'))
        if not ok:
            bad += 1
            print('        -> wanted %r; got: %s'
                  % (expect, (problems.split('\n')[0] if problems else 'NOTHING AT ALL')))

    print('\n=== controls ===')
    # S6 must NOT fire when the stale owner is a DIFFERENT one...
    _, problems = run_with([good()], [{'entity': 'MagicAllocation', 'path': 'portfolio/DEPLOYMENTS.csv',
                                       'kind': 'STALE', 'text': 'stale'}])
    ok = not problems
    print('  [%s] CONTROL a stale pin on an UNRELATED owner does not block this signature'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    # ...nor when a DIFFERENT path merely CONTAINS the owner's name (/scrutinize H4: this used to
    # block, because the gate matched the owner against the note's prose instead of its path).
    _, problems = run_with([good()], [{'entity': 'X', 'path': 'docs/MASTER_BACKLOG.md.bak',
                                       'kind': 'STALE', 'text': 'stale'}])
    ok = not problems
    print('  [%s] CONTROL a stale pin on a path that merely CONTAINS the owner name does not block'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    # ...and an explicit acknowledgement must let a stale signature through, on the record.
    _, problems = run_with([good(stale_pin_acknowledged=True)],
                           [{'entity': 'CoverageCell', 'path': 'MASTER_BACKLOG.md',
                             'kind': 'STALE', 'text': 'stale'}])
    ok = not problems
    print('  [%s] CONTROL an explicit stale_pin_acknowledged signature is allowed'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    # append-only semantics: the LAST decision for an owner wins, the earlier one stays visible
    current, problems = run_with([good(decision='REFUSED', reason='not yet', decided_at='2026-07-30T10:00'),
                                  good(decided_at='2026-07-30T23:30')])
    ok = (not problems) and current['MASTER_BACKLOG.md']['decision'] == 'APPROVED'
    print('  [%s] CONTROL append-only: a later decision supersedes an earlier one'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (problems or current))
        bad += 1

    after = io.open(so.SIGNOFF_PATH, encoding='utf-8').read() if os.path.exists(so.SIGNOFF_PATH) else None
    if after != before:
        print('\n  [BAD] this suite MODIFIED the real sign-off log -- a test that can approve the '
              'proposal it tests is its own worst finding')
        bad += 1
    else:
        print('  [OK ] the real sign-off log is byte-unchanged')

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== SIGN-OFF LOG: APPROVAL WORKS WITH NO GUARD EDIT, AND EVERY NEGATIVE IS CAUGHT ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
