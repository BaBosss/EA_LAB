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
import evidence                        # noqa: E402

def _coverage_pin_path():
    """The path the Coverage owner's D1 row PINS -- DERIVED, never hardcoded.

    It was `'MASTER_BACKLOG.md'` here, which was the same string as the row's `current_owner` and
    so looked like one fact when it was two. ORDER-731 option 2 moved the pin to
    `factory/coverage.jsonl` (the file that now holds the canonical bytes) and left `current_owner`
    alone, and every fixture below that had typed the owner's name where it meant the PIN went
    green-but-meaningless in one commit: the synthetic note named a path this owner does not pin,
    so no note could ever match and five RED cases silently became GREEN. Deriving it is the only
    version of this fixture that cannot drift away from D1 again.
    """
    rows = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    for r in rows:
        if r.get('entity') == 'CoverageCell' and (r.get('owner_ref') or {}).get('path'):
            return r['owner_ref']['path']
    raise SystemExit('CoverageCell has no owner_ref path in D1 -- this suite cannot build its '
                     'stale-pin fixtures against nothing')


PIN_PATH = _coverage_pin_path()
STALE_NOTE = {'entity': 'CoverageCell', 'path': PIN_PATH, 'kind': 'STALE', 'text': 'stale'}


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
        ('R4 a missing required field',           [good(signer='')], 'is missing'),
        ('R5 an invented decision value',         [good(decision='MAYBE')], 'not one of'),
        ('F1 a record bound to different bytes',  [good(bundle_sha256='a' * 64)],
                                                  'the current bundle is'),
        ('R6 a decision for an owner not in D1',  [good(current_owner='no/such/owner.md')],
                                                  'not a current_owner'),
        ('R7 a decision for an EMBEDDED owner',   [good(current_owner='EMBEDDED:RunTransition')],
                                                  'follows its parent'),
        # A5 is DELETED (ORDER-614 OPEN-3, ratified): it was unreachable -- `reason` is in
        # REQUIRED, so this very case was green on R4's message ('is missing'), never A5's.
        # The input is kept because it is still a real negative; it now says what it tests.
        ('R4 a blank reason dies as MISSING-REQUIRED (the criterion the old A5 case actually exercised)',
                                                  [good(decision='REFUSED', reason='')], 'is missing'),
        ('F2 a stale pin with no acknowledgement', [good()], 'pin is STALE'),
        # audit 8 MAJOR 5 -- the string "false" used to GRANT the exemption
        ('F2 the STRING "false" as acknowledgement',
         [good(stale_pin_acknowledged='false')], 'JSON boolean, not a string'),
        ('F2 true but no structured acknowledgement',
         [good(stale_pin_acknowledged=True)], 'JSON boolean, not a string'),
        ('F3 an acknowledgement naming the wrong path',
         [good(stale_pin_acknowledged=True,
               stale_pin_acknowledgement={'path': 'other.md', 'pinned_blob': 'x',
                                          'current_blob': 'y'})], 'but the stale pin is on'),
        ('F4 an acknowledgement with a wrong pinned blob',
         [good(stale_pin_acknowledged=True,
               stale_pin_acknowledgement={'path': PIN_PATH, 'pinned_blob': 'b' * 40,
                                          'current_blob': 'y'})], 'but D1 pins'),
    ]
    for label, lines, expect in cases:
        vintage = [STALE_NOTE] if label.startswith(('F2','F3','F4','F5')) else []
        _, problems = run_with(lines, vintage)
        ok = expect in problems
        print('  [%s] %-46s expect=RED got=%s' % ('OK ' if ok else 'BAD', label,
                                                  'RED ' if problems else 'GREEN'))
        if not ok:
            bad += 1
            print('        -> wanted %r; got: %s'
                  % (expect, (problems.split('\n')[0] if problems else 'NOTHING AT ALL')))

    print('\n=== G5-G8 append-only, enforced against HEAD rather than asserted in prose ===')
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
    print('  [%s] the REAL log satisfies append-only (G5) as wired' % ('OK ' if not p else 'BAD'))
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
    # TWO different facts that used to be one string, and had to be split by ORDER-731 option 2:
    #   `live`       HEAD's blob for the path the owner's D1 row PINS -- what an acknowledgement
    #                names (F5), now `factory/coverage.jsonl`.
    #   `owner_live` HEAD's blob for the record's own `current_owner` -- what an
    #                `expected_post_state` names, because F7 forces eps.path == current_owner.
    # They were identical while every row pinned its own owner, so one name served both and the
    # difference was invisible. It is not invisible any more, and conflating them made two D2
    # CONTROL cases assert that MASTER_BACKLOG.md was at coverage.jsonl's blob.
    rc, live, _ = chk._rev_parse_cached('%s:%s' % (head, PIN_PATH))
    _rc_o, owner_live, _ = chk._rev_parse_cached('%s:MASTER_BACKLOG.md' % head)
    pinned = next((r['owner_ref']['blob_oid'] for r in d1_rows
                   if r.get('owner_ref') and r['owner_ref']['path'] == PIN_PATH), None)
    _, problems = run_with([good(stale_pin_acknowledged=True,
                                 stale_pin_acknowledgement={'path': PIN_PATH,
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
    ack_ok = {'path': PIN_PATH, 'pinned_blob': pinned, 'current_blob': live}
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
    ok = 'F2' in problems   # run_with joins problems into one string
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
    ok = 'F1' in problems and 'R4' in problems
    print('  [%s] D1 a MALFORMED trailing row cannot displace the decision in force'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # ---- ORDER-613 D2: a record may declare the state its approved action PRODUCES -------------
    _, problems = run_with([good(expected_post_state={'path': 'MASTER_BACKLOG.md', 'blob': owner_live},
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
    ok = 'F11' in problems and 'did not happen' in problems
    print('  [%s] D2 an expected_post_state naming a state that never arrived is REFUSED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    _, problems = run_with([good(expected_post_state='MASTER_BACKLOG.md')], [STALE_NOTE])
    ok = 'F6' in problems and 'not an object' in problems
    print('  [%s] D2 an expected_post_state that is a bare string is REFUSED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % problems)
        bad += 1

    # ---- Codex round 2: D2 bound ANY path to ANY value, so it never enforced "changed INTO the
    #      approved state" -- it enforced "some path is at some value", which is not a claim about
    #      this decision at all.
    # Each red case asserts its PRECISE criterion id -- 'some F fired' would let F7 pass on
    # F9's behalf, which is the exact wrong-reason conformance the runner refuses.
    for label, eps, want_id in (
            ('D2 CONTROL binding its OWN owner at the real blob',
             {'path': 'MASTER_BACKLOG.md', 'blob': owner_live}, None),
            ('F7 binding an UNRELATED file is refused',
             {'path': 'AGENT_TASKBOARD.md', 'blob': owner_live}, 'F7'),
            ('F8 MISSING as a blob id is refused before HEAD is even consulted',
             {'path': 'MASTER_BACKLOG.md', 'blob': 'MISSING'}, 'F8'),
            # F9 (path absent at HEAD) and F10 (path is a tree) are UNREACHABLE from this
            # suite: F7 pins eps.path to current_owner, and eligibility (R6) pins owners to
            # real D1 paths that exist as files. They are bound HERMETICALLY by the
            # conformance vectors V-F9-001 / V-F10-001 instead, where D1 and HEAD are both
            # synthetic. This case exercises the branch BELOW them (F11) and says so --
            # its first version was labelled F9/F10 and passed on F11, which is a label
            # asserting a criterion the input can never reach.
            ('F11 a wrong post-state blob on a real path (F9/F10 are vector-bound, unreachable here)',
             {'path': 'MASTER_BACKLOG.md', 'blob': 'a' * 40}, 'F11')):
        _, problems = run_with([good(expected_post_state=eps,
                                     stale_pin_acknowledged=True,
                                     stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
        if want_id is None:
            ok = 'F' not in problems
        elif '-or-' in want_id:
            ok = any(w in problems for w in want_id.split('-or-'))
        else:
            ok = want_id in problems
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            print('        -> %s' % problems)
            bad += 1

    # ---- ORDER-731 option A: the SECTION form, against the REAL MASTER_BACKLOG.md -------------
    # The anchor is DERIVED from HEAD (the one line starting '## 2. ') and the digest is
    # RECOMPUTED here by the checker's own rule. A typed constant for either would be guard
    # shape 4 -- a claim stated without measuring it -- in the suite that judges the real repo.
    _head = att._head_text('MASTER_BACKLOG.md')
    _anchors = [l.rstrip() for l in (_head or '').replace('\r\n', '\n').split('\n')
                if l.rstrip().startswith('## 2. ')]
    ok = len(_anchors) == 1
    print('  [%s] ORDER-731 the real MASTER_BACKLOG.md has EXACTLY ONE section-2 heading (the '
          'input the SECTION form needs)' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> found %d: %r' % (len(_anchors), _anchors[:3]))
        bad += 1
        _anchors = _anchors[:1] or ['## 2. NO SUCH HEADING']
    _anchor = _anchors[0]
    _sec_digest, _sec_err = att.section_digest(_head, _anchor)
    if _sec_err:
        print('  [BAD] ORDER-731 the real section 2 could not be extracted: %s' % _sec_err)
        bad += 1
        _sec_digest = 'd' * 64

    for label, eps, want_id in (
            ('F14 CONTROL a SECTION post-state recomputed from HEAD is ACCEPTED',
             {'path': 'MASTER_BACKLOG.md', 'section': _anchor,
              'section_sha256': _sec_digest}, None),
            ('F14 a SECTION post-state naming a digest that never arrived is REFUSED',
             {'path': 'MASTER_BACKLOG.md', 'section': _anchor,
              'section_sha256': 'a' * 64}, 'F14'),
            # F12 is reachable from THIS suite (unlike F9/F10), so it gets a real case rather than
            # a mention: a value sha256 would accept as an argument is not a statement about
            # content, and it is refused before HEAD is consulted at all.
            ('F12 a section_sha256 that is not 64-hex lowercase is REFUSED',
             {'path': 'MASTER_BACKLOG.md', 'section': _anchor,
              'section_sha256': 'MISSING'}, 'F12'),
            ('F13 a SECTION heading that is not in HEAD is REFUSED, never skipped',
             {'path': 'MASTER_BACKLOG.md', 'section': '## 2. NO SUCH HEADING',
              'section_sha256': _sec_digest}, 'F13'),
            ('F6 a post-state carrying BOTH forms at once is REFUSED',
             {'path': 'MASTER_BACKLOG.md', 'blob': owner_live, 'section': _anchor,
              'section_sha256': _sec_digest}, 'F6')):
        _, problems = run_with([good(expected_post_state=eps,
                                     stale_pin_acknowledged=True,
                                     stale_pin_acknowledgement=ack_ok)], [STALE_NOTE])
        if want_id is None:
            ok = not problems
        else:
            ok = want_id in problems
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            print('        -> %s' % (problems or 'NOTHING AT ALL'))
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
    print('  [%s] R2 a non-object JSON line is REPORTED, not a traceback' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % _probs)
        bad += 1

    # ---- R1: a line that is not JSON at all is reported by id and line, never raised ----------
    _fd, _tmp = _tf.mkstemp(suffix='.jsonl')
    os.close(_fd)
    io.open(_tmp, 'w', encoding='utf-8', newline=chr(10)).write('{not json' + chr(10))
    _saved = att.ATTESTATION_PATH
    try:
        att.ATTESTATION_PATH = _tmp
        _rows, _probs = att.load_records()
        ok = any(p.startswith('R1 line 1') for p in _probs)
    finally:
        att.ATTESTATION_PATH = _saved
        os.unlink(_tmp)
    print('  [%s] R1 an unparseable line is reported BY ID AND LINE (it was unprefixed until '
          'ORDER-614, so the conformance runner could not match it)' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % _probs)
        bad += 1

    # ---- G7: tracked but unreadable from the index is a TOOL FAILURE, never a worktree read ---
    # Driven through the same seams the conformance runner uses: git-show fails, ls-files says
    # tracked, `committed` supplied so no real git is consulted for the HEAD side.
    class _ShowFails(object):
        @staticmethod
        def run(cmd, **kw):
            class R(object):
                returncode, stdout, stderr = 128, b'', b'fatal: unreadable'
            return R()
    _saved_sub, _saved_git = att.subprocess, chk._git
    try:
        att.subprocess = _ShowFails
        chk._git = lambda *a2_: (0, '', '') if a2_ and a2_[0] == 'ls-files' else _saved_git(*a2_)
        _probs = []
        att.check_append_only(_probs, path='whatever.jsonl', committed=b'L1' + chr(10).encode())
        ok = any(p.startswith('G7') for p in _probs)
    finally:
        att.subprocess, chk._git = _saved_sub, _saved_git
    print('  [%s] G7 tracked-but-unreadable is a TOOL FAILURE by id, not a silent worktree '
          'fallback' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % _probs)
        bad += 1

    # ---- ORDER-670 migration: a log ABSENT from the index is a deletion, not "nothing to judge"
    # The pre-migration code read the WORKING TREE here, described as "reached ONLY for an
    # untracked log (nothing staged to judge)". The description was true of the code path and
    # false of the situation: control only reaches it when `committed` is non-empty, i.e. HEAD
    # HAS the log and the index does not -- the commit is DELETING append-only history, and
    # comparing HEAD to a working copy the commit is not keeping could pass.
    # No patching: a path that exists nowhere drives the real branch.
    p = []
    att.check_append_only(p, 'no/such/attestation_log.jsonl',
                          committed=b'{"decision": "REFUSED"}\n')
    ok = any('not append-only' in x for x in p)
    print('  [%s] a log present in HEAD but ABSENT from the index is refused (G5), not read off '
          'disk as if nothing were staged' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (p or 'NOTHING AT ALL'))
        bad += 1

    # ---- ORDER-670 migration: the DIGEST is a judged read ------------------------------------
    # Before the migration `bundle_digest()` read the disk unconditionally, under the reasoning
    # "the digest describes the bytes the signer is LOOKING AT". True of a manual run and FALSE
    # of the gate: stage a change to a bundle file, restore the worktree copy, and the digest
    # recomputes to the OLD value -- so the owner's record still validates and THE COMMIT LANDS
    # A BUNDLE CHANGE NO ATTESTATION COVERS. A7's shape at the highest-ceremony target here.
    #
    # Driven through EvidenceSource's `_git` seam rather than by staging into a real index: the
    # scenario is "index and worktree disagree", and a fake index expresses that without this
    # suite ever writing to `.git` (which ORDER-670's T6 refuses, correctly).
    _saved_src = att._SRC[0]
    try:
        _policy = '_triage/factory_os/S2A_ATTESTATION_POLICY.md'
        _real = evidence.EvidenceSource('worktree', root=att._ROOT)

        def _staged_git(*a):
            # `git show :<path>` answers with TAMPERED bytes for one bundle member and with the
            # real bytes for the rest, i.e. exactly a commit that stages a change to the bundle.
            if a[:1] == ('show',) and a[1] == ':%s' % _policy:
                return 0, b'TAMPERED BUNDLE MEMBER\n', b''
            if a[:1] == ('show',) and a[1].startswith(':'):
                return 0, _real.read_committed_bytes(a[1][1:]), b''
            return 0, b'', b''

        att._SRC[0] = evidence.EvidenceSource('index', root=att._ROOT, _git=_staged_git)
        _tampered = att.bundle_digest()
        att._SRC[0] = _real
        _clean = att.bundle_digest()
    finally:
        att._SRC[0] = _saved_src
    ok = _tampered != _clean
    print('  [%s] ATTACK a bundle member staged behind a clean worktree changes the digest, so '
          'F1 refuses the record instead of validating against bytes the commit does not have'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> both digests are %s; the digest is not reading the judged snapshot' % _clean)
        bad += 1

    # SPECIFICITY, and it is the one that keeps this migration free: with the index and the
    # working tree in AGREEMENT -- which is the state of every bundle path in this repo -- the
    # digest is UNCHANGED, so no existing attestation is voided and no owner signature is spent.
    # Measured rather than promised: the pre-migration implementation and this one produce the
    # same value on the real bundle, so the migration refuses zero recorded decisions.
    _saved_src = att._SRC[0]
    try:
        att._SRC[0] = evidence.EvidenceSource('index', root=att._ROOT,
                                              _git=lambda *a: (0, _real.read_committed_bytes(a[1][1:]), b'')
                                              if a[:1] == ('show',) and a[1].startswith(':')
                                              else (0, b'', b''))
        ok = att.bundle_digest() == _clean
    finally:
        att._SRC[0] = _saved_src
    print('  [%s] SPECIFICITY index and worktree agreeing give the SAME digest -- the migration '
          'voids no recorded decision and costs no signature' % ('OK ' if ok else 'BAD'))
    if not ok:
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

    # ---- ORDER-731 review M1+M2: the template is the surface a SIGNER reads, so it is tested
    # ---- like a guard: it must carry the claims forward (M2), guide to the RIGHT ack path when
    # ---- a note exists (M1), and stay silent when none does (specificity).
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc_t = att.main(['--template'])
    tline = json.loads([l for l in buf.getvalue().splitlines() if l.startswith('{')][0])
    in_force_eps = None
    with io.open(att.ATTESTATION_PATH, encoding='utf-8') as fh:
        for raw in fh:
            if raw.strip():
                rec = json.loads(raw)
                if list(rec.keys()) != ['_comment'] and rec.get('current_owner') == 'MASTER_BACKLOG.md':
                    in_force_eps = rec.get('expected_post_state')
    ok = rc_t == 0 and tline.get('expected_post_state') == in_force_eps and in_force_eps is not None
    print('  [%s] M2: --template carries the in-force expected_post_state forward verbatim'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> template=%r vs in-force=%r' % (tline.get('expected_post_state'), in_force_eps))
        bad += 1
    ok = 'stale_pin_acknowledgement' not in tline
    print('  [%s] M1 specificity: no note today, so the template emits NO ack skeleton'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %r' % (tline.get('stale_pin_acknowledgement'),))
        bad += 1
    # The fire direction: force a synthetic STALE note on the D1-pinned path and re-run. The ack
    # skeleton must name THAT path (the mapping), never current_owner -- F3 refuses the other.
    pin_path = _coverage_pin_path()
    saved_notes = chk.pin_vintage_notes
    try:
        chk.pin_vintage_notes = lambda rows: [{'path': pin_path, 'kind': 'STALE'}]
        buf2 = io.StringIO()
        with contextlib.redirect_stdout(buf2):
            rc_t2 = att.main(['--template'])
    finally:
        chk.pin_vintage_notes = saved_notes
    tline2 = json.loads([l for l in buf2.getvalue().splitlines() if l.startswith('{')][0])
    ack2 = tline2.get('stale_pin_acknowledgement') or {}
    ok = (rc_t2 == 0 and tline2.get('stale_pin_acknowledged') is True
          and ack2.get('path') == pin_path and ack2.get('path') != 'MASTER_BACKLOG.md')
    print('  [%s] M1: with a note on the pinned path, the ack skeleton names %s (not current_owner)'
          % (('OK ' if ok else 'BAD'), pin_path))
    if not ok:
        print('        -> %r' % (ack2,))
        bad += 1
    # And the F2 message itself must now name the pinned path (the other human surface).
    _cur_m1, probs_m1 = run_with([good()], vintage=[{'path': pin_path, 'kind': 'STALE'}])
    ok = 'F2' in probs_m1 and pin_path in probs_m1
    print('  [%s] M1: F2 names the PINNED path in its message, not only the owner'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (probs_m1,))
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
