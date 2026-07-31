"""
run_s2a_attestation_tests.py - ORDER-602 A (rescoped): prove the attestation log accepts a real
decision and refuses every malformed, unbound, stale or history-rewriting one.

THE CASE THAT MATTERS MOST IS STILL THE POSITIVE ONE. The reason this artifact exists is that a
decision can be recorded **without editing any guard, generator or proposal byte** -- so the first
assertion appends a real record and requires it to be accepted with `check_s2a_migration.py` and
`gen_s2a_migration.py` untouched. If that goes red the audit-7 deadlock is back.

Every case runs against a TEMPORARY copy. The real `_triage/factory_os/s2a_attestations.jsonl` is
never written by this suite, and that is asserted at the end -- a test that can approve the proposal
it is testing would be its own worst finding.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s2a_attestation_tests.py
"""
import io
import json
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk      # noqa: E402
import check_s2a_attestation as att    # noqa: E402

STALE_NOTE = {'entity': 'CoverageCell', 'path': 'MASTER_BACKLOG.md', 'kind': 'STALE',
              'text': 'stale'}


def run_with(lines, vintage=()):
    saved = att.ATTESTATION_PATH
    fd, tmp = tempfile.mkstemp(suffix='.jsonl')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            for obj in lines:
                fh.write(json.dumps(obj, sort_keys=True) + '\n')
        att.ATTESTATION_PATH = tmp
        rows, problems = att.load_records()
        d1 = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
        att._D1_ROWS[:] = d1
        owners = sorted({r['current_owner'] for r in d1})
        current = att.check(rows, problems, att.bundle_digest(), owners, vintage)
        return current, '\n'.join(problems)
    finally:
        att.ATTESTATION_PATH = saved
        try:
            os.unlink(tmp)
        except OSError:
            pass


def good(**over):
    row = {'bundle_sha256': att.bundle_digest(),
           'current_owner': 'MASTER_BACKLOG.md',
           'decision': 'APPROVED',
           'signer': 'user (Boss)',
           'decided_at': '2026-07-31T00:30',
           'reason': 'coverage transfer accepted; banner change ships with the first generation'}
    row.update(over)
    return row


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    before = (io.open(att.ATTESTATION_PATH, encoding='utf-8').read()
              if os.path.exists(att.ATTESTATION_PATH) else None)
    bad = 0

    print('=== THE POINT: a decision is recordable with no guard, generator or proposal edit ===')
    current, problems = run_with([good()])
    ok = (not problems) and current.get('MASTER_BACKLOG.md', {}).get('decision') == 'APPROVED'
    print('  [%s] a well-formed APPROVED for the Coverage owner is ACCEPTED' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (problems or 'not recorded as the current decision'))
        bad += 1
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
        ('A1 a missing required field',           [good(signer='')], 'is missing'),
        ('A1 an invented decision value',         [good(decision='MAYBE')], 'not one of'),
        ('A2 a record bound to different bytes',  [good(bundle_sha256='a' * 64)],
                                                  'the current bundle is'),
        ('A4 a decision for an owner not in D1',  [good(current_owner='no/such/owner.md')],
                                                  'not a current_owner'),
        ('A4 a decision for an EMBEDDED owner',   [good(current_owner='EMBEDDED:RunTransition')],
                                                  'follows its parent'),
        ('A5 REFUSED with no reason',             [good(decision='REFUSED', reason='')], 'is missing'),
        ('A6 a stale pin with no acknowledgement', [good()], 'pin is STALE'),
        # audit 8 MAJOR 5 -- the string "false" used to GRANT the exemption
        ('A6 the STRING "false" as acknowledgement',
         [good(stale_pin_acknowledged='false')], 'JSON boolean, not a string'),
        ('A6 true but no structured acknowledgement',
         [good(stale_pin_acknowledged=True)], 'JSON boolean, not a string'),
        ('A6 an acknowledgement naming the wrong path',
         [good(stale_pin_acknowledged=True,
               stale_pin_acknowledgement={'path': 'other.md', 'pinned_blob': 'x',
                                          'current_blob': 'y'})], 'but the stale pin is on'),
        ('A6 an acknowledgement with a wrong pinned blob',
         [good(stale_pin_acknowledged=True,
               stale_pin_acknowledgement={'path': 'MASTER_BACKLOG.md', 'pinned_blob': 'b' * 40,
                                          'current_blob': 'y'})], 'but D1 pins'),
    ]
    for label, lines, expect in cases:
        vintage = [STALE_NOTE] if label.startswith('A6') else []
        _, problems = run_with(lines, vintage)
        ok = expect in problems
        print('  [%s] %-46s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                  'RED ' if problems else 'GREEN'))
        if not ok:
            bad += 1
            print('        -> wanted %r; got: %s'
                  % (expect, (problems.split('\n')[0] if problems else 'NOTHING AT ALL')))

    print('\n=== A7 append-only, enforced against HEAD rather than asserted in prose ===')
    # audit 8 BLOCKER 3: deleting an earlier record used to stay green.
    # State-INDEPENDENT: the committed and working bytes are injected, so the rule is exercised
    # identically whether or not the real log happens to be in HEAD yet. Reading both from git
    # created a bootstrap deadlock -- the suite failed because the file was not committed, and the
    # file could not be committed because the suite failed.
    base = b'{"_comment": "header"}\n{"decision": "REFUSED"}\n'
    p = []
    att.check_append_only(p, 'x.jsonl', committed=base,
                          working=base + b'{"decision": "APPROVED"}\n')
    print('  [%s] CONTROL appending after the committed bytes is allowed' % ('OK ' if not p else 'BAD'))
    if p:
        print('        -> %s' % p)
        bad += 1
    p = []
    att.check_append_only(p, 'x.jsonl', committed=base,
                          working=b'{"_comment": "header"}\n{"decision": "APPROVED"}\n')
    ok = any('not append-only' in x for x in p)
    print('  [%s] NEGATIVE an earlier record EDITED is refused' % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1
    p = []
    att.check_append_only(p, 'x.jsonl', committed=base, working=b'{"_comment": "header"}\n')
    ok = any('not append-only' in x for x in p)
    print('  [%s] NEGATIVE an earlier record DELETED is refused' % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1
    # Codex round 2, Standards 1 (P0): A7 read the WORKING TREE, so staging a deletion of an
    # earlier line while restoring the working copy reported 0 problems -- a commit could rewrite
    # append-only history with the gate green. The rule is byte-prefix-against-what-is-COMMITTED,
    # so the fixture below is the one that distinguishes the two readings: `working` is injected
    # with the bytes A7 should be judging (the staged ones), and the working tree is irrelevant.
    staged_deletion = b'{"_comment": "header"}\n'          # line 2 removed from the STAGED copy
    p = []
    att.check_append_only(p, 'x.jsonl', committed=base, working=staged_deletion)
    ok = any('not append-only' in x and 'STAGED' in x for x in p)
    print('  [%s] NEGATIVE a deletion present only in the STAGED bytes is refused'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % p)
        bad += 1
    # ...and the real file, whatever state it is in, must satisfy the rule as actually wired --
    # which now means read from the index, not from disk.
    p = []
    att.check_append_only(p)
    print('  [%s] the REAL log satisfies A7 as wired' % ('OK ' if not p else 'BAD'))
    if p:
        print('        -> %s' % p)
        bad += 1

    print('\n=== controls ===')
    _, problems = run_with([good()], [{'entity': 'MagicAllocation',
                                       'path': 'portfolio/DEPLOYMENTS.csv',
                                       'kind': 'STALE', 'text': 'stale'}])
    ok = not problems
    print('  [%s] CONTROL a stale pin on an UNRELATED owner does not block' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    _, problems = run_with([good()], [{'entity': 'X', 'path': 'docs/MASTER_BACKLOG.md.bak',
                                       'kind': 'STALE', 'text': 'stale'}])
    ok = not problems
    print('  [%s] CONTROL a stale pin on a path merely CONTAINING the owner name does not block'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    # a fully correct structured acknowledgement must be accepted, on the record
    head = chk.head_oid()
    rc, live, _ = chk._rev_parse_cached('%s:MASTER_BACKLOG.md' % head)
    pinned = next((r['owner_ref']['blob_oid'] for r in d1_rows
                   if r.get('owner_ref') and r['owner_ref']['path'] == 'MASTER_BACKLOG.md'), None)
    _, problems = run_with([good(stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement={'path': 'MASTER_BACKLOG.md',
                                                            'pinned_blob': pinned,
                                                            'current_blob': live})], [STALE_NOTE])
    ok = not problems
    print('  [%s] CONTROL a CORRECT structured acknowledgement is accepted' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1
    # ---- ORDER-613 D1: the stale-pin rule judges the CURRENT record, not every historical one ----
    # Why this exists: A6 used to run for every row, while this artifact's own header promises the
    # latest line per owner wins. Because the log is append-only, an earlier row could never acquire
    # the acknowledgement it was being failed for, so one stale pin made that owner's records
    # permanently unrepairable -- the artifact could not be returned to green by ANY legal action.
    ack_ok = {'path': 'MASTER_BACKLOG.md', 'pinned_blob': pinned, 'current_blob': live}
    _, problems = run_with([good(decided_at='2026-07-30T10:00'),                     # no ack
                            good(decided_at='2026-07-31T04:30',
                                 stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
    ok = not problems
    print('  [%s] D1 a SUPERSEDED row with no acknowledgement does not block the current one'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # ...and the narrowing must not become a loophole: what is demanded of the CURRENT row is
    # unchanged. Same two rows, acknowledgement on the OLD one instead of the new one.
    _, problems = run_with([good(decided_at='2026-07-30T10:00',
                                 stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement=ack_ok),
                            good(decided_at='2026-07-31T04:30')], [STALE_NOTE])
    ok = 'A6' in problems   # run_with joins problems into one string
    print('  [%s] D1 the CURRENT row still must acknowledge -- an old ack does not carry forward'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # A2 had the SAME defect A6 did, and narrowing only A6 was not enough -- found by running it:
    # lines made under a previous bundle kept the log red, and append-only means they can never be
    # corrected. So the artifact could not survive its own evolution: any edit to a bundled file
    # reddened it permanently. Superseded records are history.
    _, problems = run_with([good(bundle_sha256='a' * 64, decided_at='2026-07-30T10:00'),
                            good(decided_at='2026-07-31T07:55',
                                 stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
    ok = not problems
    print('  [%s] D1 a SUPERSEDED row bound to an OLD bundle does not block the current one'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # /scrutinize: `latest` was built from EVERY row, including ones that fail A1 -- so appending a
    # single malformed line made THAT line "in force" and demoted the real decision to superseded,
    # letting it skip A2 and A6 entirely. Probed: a row with a wrong bundle AND a stale pin was
    # reported for neither. Both lists come from one eligibility predicate now.
    _, problems = run_with([good(bundle_sha256='a' * 64, decided_at='2026-07-31T07:00'),
                            good(signer='', decided_at='2026-07-31T07:10')], [STALE_NOTE])
    ok = 'A2' in problems and 'A1' in problems
    print('  [%s] D1 a MALFORMED trailing row cannot displace the decision in force'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # ---- ORDER-613 D2: a record may declare the state its approved action PRODUCES -------------
    _, problems = run_with([good(expected_post_state={'path': 'MASTER_BACKLOG.md', 'blob': live},
                                 stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
    ok = not problems
    print('  [%s] D2 CONTROL an expected_post_state that matches HEAD is accepted'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    _, problems = run_with([good(expected_post_state={'path': 'MASTER_BACKLOG.md', 'blob': 'f' * 40},
                                 stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
    ok = 'A8' in problems and 'did not happen' in problems
    print('  [%s] D2 an expected_post_state naming a state that never arrived is REFUSED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    _, problems = run_with([good(expected_post_state='MASTER_BACKLOG.md')], [STALE_NOTE])
    ok = 'A8' in problems and 'not an object' in problems
    print('  [%s] D2 an expected_post_state that is a bare string is REFUSED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # ---- Codex round 2: D2 bound ANY path to ANY value, so it never enforced "changed INTO the
    #      approved state" -- it enforced "some path is at some value", which is not a claim about
    #      this decision at all.
    for label, eps, want_red in (
            ('D2 CONTROL binding its OWN owner at the real blob',
             {'path': 'MASTER_BACKLOG.md', 'blob': live}, False),
            ('D2 binding an UNRELATED file is refused',
             {'path': 'AGENT_TASKBOARD.md', 'blob': live}, True),
            ('D2 binding a path that does not exist at HEAD is refused',
             {'path': 'NO_SUCH_PATH', 'blob': 'MISSING'}, True),
            ('D2 binding a DIRECTORY (a tree oid, not content) is refused',
             {'path': 'portfolio', 'blob': 'a' * 40}, True)):
        _, problems = run_with([good(expected_post_state=eps,
                                     stale_pin_acknowledged=True,
                                     stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
        got = 'A8' in problems
        ok = (got == want_red)
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            print('        -> %s' % problems)
            bad += 1

    # ---- Codex round 2, Spec 8: a JSON line that is not an object crashed the loader ----------
    import tempfile as _tf
    _fd, _tmp = _tf.mkstemp(suffix='.jsonl')
    os.close(_fd)
    io.open(_tmp, 'w', encoding='utf-8', newline='\n').write('"string-row"\n')
    _saved = att.ATTESTATION_PATH
    try:
        att.ATTESTATION_PATH = _tmp
        _rows, _probs = att.load_records()
        ok = any('not an object' in p for p in _probs)
    except Exception as exc:                                   # noqa: BLE001 - that IS the finding
        ok = False
        _probs = ['CRASHED: %s' % type(exc).__name__]
    finally:
        att.ATTESTATION_PATH = _saved
        os.unlink(_tmp)
    print('  [%s] a non-object JSON line is REPORTED, not a traceback' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % _probs)
        bad += 1

    current, problems = run_with([good(decision='REFUSED', reason='not yet',
                                       decided_at='2026-07-30T10:00'),
                                  good(decided_at='2026-07-31T00:30')])
    ok = (not problems) and current['MASTER_BACKLOG.md']['decision'] == 'APPROVED'
    print('  [%s] CONTROL append-only: a later record supersedes an earlier one'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (problems or current))
        bad += 1

    after = (io.open(att.ATTESTATION_PATH, encoding='utf-8').read()
             if os.path.exists(att.ATTESTATION_PATH) else None)
    if after != before:
        print('\n  [BAD] this suite MODIFIED the real attestation log')
        bad += 1
    else:
        print('  [OK ] the real attestation log is byte-unchanged')

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== ATTESTATION LOG: RECORDING WORKS WITH NO GUARD EDIT, EVERY NEGATIVE CAUGHT ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
