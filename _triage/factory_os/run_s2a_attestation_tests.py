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

def _coverage_row():
    """The Coverage owner's D1 row. Both the path it PINS and the owner it decides for are
    DERIVED from it, never hardcoded -- ORDER-1310 #3 made the OWNER load-bearing too, and a
    hardcoded owner is the same drift hazard the path already paid for once below.

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
            return r
    raise SystemExit('CoverageCell has no owner_ref path in D1 -- this suite cannot build its '
                     'stale-pin fixtures against nothing')


_COV_ROW = _coverage_row()
PIN_PATH = _COV_ROW['owner_ref']['path']
COV_OWNER = _COV_ROW['current_owner']
STALE_NOTE = {'entity': 'CoverageCell', 'path': PIN_PATH, 'kind': 'STALE', 'text': 'stale'}


def run_with(lines, vintage=(), d1_override=None):
    """Drive `check()` over a TEMPORARY attestation log.

    `d1_override` (ORDER-1310 #3) injects a D1 the real file does not contain, so the end-to-end
    case for a defect that is LATENT in today's data can still be driven. `None` means "read the
    real D1", which is what every pre-existing caller gets.
    """
    saved = att.ATTESTATION_PATH
    fd, tmp = tempfile.mkstemp(suffix='.jsonl')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            for obj in lines:
                fh.write(json.dumps(obj, sort_keys=True) + '\n')
        att.ATTESTATION_PATH = tmp
        rows, problems = att.load_records()
        d1 = (list(d1_override) if d1_override is not None else
              [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()])
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


def _derived_section_eps(path, exclude=None):
    """A section post-state claim for `path` that REALLY reproduces at HEAD, built at run time.

    The anchor is the first `## ` heading that occurs exactly once, so this cannot rot as the
    file changes -- which for AGENT_TASKBOARD.md is every few minutes.

    `exclude` (ORDER-1310 #1) skips a heading, so the attack fixture can be "a DIFFERENT
    section of the SAME file, correctly hashed" -- derived at run time for the same reason the
    rest is: a hand-typed heading is a fixture of filler values that would go green the day
    the file is reorganised (memory `fixture-of-filler-values-cannot-test-resolution`).

    MODULE SCOPE since ORDER-1310 #9, because the F14 case that needs it runs BEFORE the block
    this used to be nested in -- and being unable to reach a real section is exactly how that case
    ended up anchored on a heading that does not exist.
    """
    text = att._head_text(path)
    lines = [l.rstrip() for l in text.replace('\r\n', '\n').split('\n')]
    heads = [l for l in lines if l.startswith('## ')]
    for h in heads:
        if h != exclude and heads.count(h) == 1:
            sha, err = att.section_digest(text, h)
            if not err:
                return {'path': path, 'section': h, 'section_sha256': sha}
    raise SystemExit('no uniquely-occurring "## " heading in %s (excluding %r) -- this suite '
                     'cannot build a reproducing section claim against nothing'
                     % (path, exclude))


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

    # ---- ORDER-1269 #3 (owner-ratified): "a record whose pin failed must print UNVERIFIED, not
    # ---- APPROVED". The exit code was already honest; the line a human reads was not, and this
    # ---- file is the record of who approved what.
    #
    # Why this needs its own block rather than one more row in `cases` above: every case up there
    # asserts on `problems`, and #3 is not about `problems` at all -- it is about what `current`
    # SAYS while `problems` is non-empty. A checker can be perfectly red and still report the
    # failing row as the approved decision, which is exactly what it did.
    print('\n=== ORDER-1269 #3: what the reported decision SAYS when its own checks failed ===')

    def _reported(lines, vintage=()):
        """(printed decision, what check() returns) for the in-force Coverage record.

        BOTH halves are asserted on every case below, and that is the point of this helper. The
        first version of this repair demoted what `check()` RETURNS, which broke 29 canonical
        vectors in `S2A_ATTESTATION_VECTORS.jsonl` -- a BUNDLE MEMBER, so repairing them would
        have cost the owner a signature to fix a display bug. The ratified wording is narrower
        than the obvious fix: "the line a HUMAN READS". So the pair is held apart deliberately,
        and a future seat that "tidies" them back together will find out here rather than from a
        red bundle digest.
        """
        cur, probs = run_with(lines, vintage)
        row = cur.get('MASTER_BACKLOG.md', {})
        shown, _ = att.reported_decision(row, 'MASTER_BACKLOG.md')
        return shown, row.get('decision'), probs

    _shown, _returned, _p = _reported([good()], [STALE_NOTE])
    ok = _shown == 'UNVERIFIED'
    print('  [%s] a record whose F2 pin check FAILED is not PRINTED as APPROVED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> printed %r, four lines above its own F2 failure' % _shown)
        bad += 1
    ok = _returned == 'APPROVED'
    print('  [%s] ...while what check() RETURNS is untouched, so the signed vector corpus and the '
          'bundle digest are not disturbed' % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> check() returned %r; 29 canonical vectors declare APPROVED here' % _returned)
        bad += 1
    # F14 as well as F2, because they reach the report by the same fall-through: neither of them
    # `continue`s, which is the actual mechanism. One case would leave the other free to regress.
    #
    # 🔴 ORDER-1310 #9 -- THIS CASE COULD NOT DISCRIMINATE, AND THE ONLY THING WRONG WITH IT WAS
    # ITS FIXTURE. It claimed section 'S2a coverage transfer', which is not an exact heading of
    # MASTER_BACKLOG.md, so it always died at F13 and the hash comparison was never reached. The
    # independent review proved it with a mutation: `elif got != eps['section_sha256']` -> `elif
    # False` SURVIVED. The other wrong-hash fixture in this file is masked by F2 and asserts only
    # 'pin is STALE', so nothing anywhere required F14 to fire. The section is now DERIVED so it
    # really resolves, only the digest is wrong -- and the assertion names F14 alone and requires
    # F13 to be ABSENT, so a case that falls back to "could not locate the section" is a failure
    # rather than a pass by a different criterion.
    _shown, _returned, _p = _reported([good(expected_post_state=dict(
        _derived_section_eps('MASTER_BACKLOG.md'), section_sha256='c' * 64))])
    ok = 'F14' in _p and 'F13' not in _p and _shown == 'UNVERIFIED'
    print('  [%s] and so is one whose expected_post_state DIGEST did not reproduce (F14 itself)'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> printed=%r problems=%r'
              % (_shown, _p.split('\n')[0] if _p else 'NOTHING AT ALL'))
        bad += 1
    # ...and the F13 half, which the case above used to be testing by accident. It is kept as its
    # OWN case rather than folded back into a disjunction: two criteria reach the report by the
    # same fall-through and each must be observed doing it, or one of them is free to regress
    # behind the other (which is precisely what happened).
    _shown, _returned, _p = _reported([good(expected_post_state={
        'path': 'MASTER_BACKLOG.md', 'section': '## no such heading in this file',
        'section_sha256': 'c' * 64})])
    ok = 'F13' in _p and 'F14' not in _p and _shown == 'UNVERIFIED'
    print('  [%s] and so is one whose expected_post_state SECTION could not be located (F13)'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> printed=%r problems=%r'
              % (_shown, _p.split('\n')[0] if _p else 'NOTHING AT ALL'))
        bad += 1
    # CONTROL. Without this the block above is satisfiable by demoting every row unconditionally,
    # which would be a checker that cannot say APPROVED at all -- green for the wrong reason.
    _shown, _returned, _p = _reported([good()])
    ok = (not _p) and _shown == 'APPROVED'
    print('  [%s] CONTROL a record whose checks all PASSED still prints APPROVED'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> printed=%r problems=%r' % (_shown, _p))
        bad += 1
    # SPECIFICITY, and it is the one that separates the correct fix from the cheap one. "Demote if
    # `problems` is non-empty" passes both cases above and is WRONG: `problems` is shared, so a
    # malformed line appended AFTER a good decision -- or a complaint raised by load_records for a
    # different owner entirely -- would silently un-approve a record that verified. The count has to
    # be snapshotted PER ROW.
    _shown, _returned, _p = _reported([good(), {'current_owner': 'MASTER_BACKLOG.md', 'signer': ''}])
    ok = bool(_p) and _shown == 'APPROVED'
    print('  [%s] SPECIFICITY a malformed SEPARATE line does not un-approve a record that verified'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> printed=%r problems=%r'
              % (_shown, _p.split('\n')[0] if _p else 'NOTHING AT ALL'))
        bad += 1

    # ---- ORDER-1269 #1 = ORDER-1257 option (b), owner-ratified: CHANGE THE INSTRUMENT.
    # ---- The whole-store pin on an already-executed transfer's DESTINATION stops being enforced.
    # ---- Every case below exists to bound that exemption, because an exemption is only as good as
    # ---- the list of things it still refuses.
    # The count used to be typed into this heading ("the six things"). It is DERIVED from the list
    # below now, because ORDER-1310 #1 added one and a hand-typed tally is a number that rots into
    # a claim nobody re-checks -- memory `measurement-table-needs-its-harness`, one size down.
    print('\n=== ORDER-1269 #1: the pin instrument, and what the exemption still refuses ===')

    def _real_eps(owner):
        """The in-force record's own expected_post_state -- DERIVED from the live log, never typed.

        A hand-written section_sha256 is a fixture of filler values: it is green whether or not the
        section resolver works, so it cannot test resolution at all (memory
        `fixture-of-filler-values-cannot-test-resolution`). The reproducer has to be the real thing.

        LAST wins, and that is not a detail. The first version of this helper returned the FIRST
        matching record and picked up a WHOLE-FILE claim left by an earlier signature, whose blob is
        long stale -- so THE POINT failed on F11 while every refusal case passed. The log is
        append-only and the record in force is the last one for that owner; anything else is
        history.
        """
        found = None
        with io.open(att.ATTESTATION_PATH, encoding='utf-8') as fh:
            for raw in fh:
                if raw.strip():
                    rec = json.loads(raw)
                    if (rec.get('current_owner') == owner
                            and isinstance(rec.get('expected_post_state'), dict)):
                        found = rec['expected_post_state']
        return found

    COV_EPS = _real_eps('MASTER_BACKLOG.md')
    MISSING_NOTE = {'entity': 'CoverageCell', 'path': PIN_PATH, 'kind': 'MISSING', 'text': 'gone'}
    _rc_mb, _mb_blob, _ = chk._rev_parse_cached('%s:MASTER_BACKLOG.md' % chk.head_oid())

    if COV_EPS is None:
        print('  [BAD] the in-force record carries no expected_post_state to derive from')
        bad += 1
    else:
        _, _p = run_with([good(expected_post_state=COV_EPS)], [STALE_NOTE])
        _notes = list(att.PIN_NOTES)
        ok = (not _p) and len(_notes) == 1 and PIN_PATH in _notes[0]
        print('  [%s] THE POINT a legitimate store change on the transfer DESTINATION costs no '
              'owner signature' % ('OK ' if ok else 'BAD'))
        if not ok:
            print('        -> problems=%r pin_notes=%r' % (_p, _notes))
            bad += 1
        # ...and it is PRINTED. A pin that is not enforced and says nothing is
        # `guard-disarmed-by-prose-reported-as-note`, the shape this same order fixes elsewhere.
        ok = bool(_notes) and 'NOT enforced' in _notes[0] and 'already executed' in _notes[0]
        print('  [%s] and the un-enforced pin is REPORTED with the instruments that replaced it'
              % ('OK ' if ok else 'BAD'))
        if not ok:
            bad += 1

        exemption_attacks = [
            ('no post-state claim at all leaves nothing to replace the pin',
             [good()], [STALE_NOTE]),
            ('a section claim that does NOT reproduce is not a working instrument',
             [good(expected_post_state=dict(COV_EPS, section_sha256='c' * 64))], [STALE_NOTE]),
            ('a MISSING note -- the destination DELETED -- is not the approval succeeding',
             [good(expected_post_state=COV_EPS)], [MISSING_NOTE]),
            ('a WHOLE-FILE claim is the granularity ORDER-731 measured at ~2 signatures/day',
             [good(expected_post_state={'path': 'MASTER_BACKLOG.md', 'blob': _mb_blob})],
             [STALE_NOTE]),
            # THE discriminating case. Every other TRANSFER row pins its SOURCE, where a change
            # really is the owner's reading going out of date. If the exemption keyed on
            # "disposition == TRANSFER" alone, this would go green and 12 rows would lose their pin.
            ('SPECIFICITY a SOURCE-pinned transfer row still demands the acknowledgement',
             [good(current_owner='AGENT_TASKBOARD.md',
                   expected_post_state=_derived_section_eps('AGENT_TASKBOARD.md'))],
             [{'entity': 'Hypothesis', 'path': 'AGENT_TASKBOARD.md', 'kind': 'STALE',
               'text': 'stale'}]),
            # ORDER-1310 #1, REPRODUCED by the independent review before it was written here: a
            # CORRECTLY HASHED claim on a DIFFERENT section of the SAME owner file bought the
            # exemption. F7 forced the right FILE and F13/F14 forced the claim to reproduce, and
            # both were satisfied -- nothing asked WHICH section. The heading is derived at run
            # time, excluding the one the destination store declares.
            ('ORDER-1310 #1 a correctly-hashed claim on an UNRELATED section of the owner file',
             [good(expected_post_state=_derived_section_eps(
                 'MASTER_BACKLOG.md', exclude=att.declared_owner_section(PIN_PATH)))],
             [STALE_NOTE]),
        ]
        print('  (%d refusals below, counted from the list, not from this sentence)'
              % len(exemption_attacks))
        for label, lines, vintage in exemption_attacks:
            _, _ap = run_with(lines, vintage)
            ok = 'pin is STALE' in _ap
            print('  [%s] %-72s expect=RED got=%s'
                  % ('OK ' if ok else 'BAD', label, 'RED ' if _ap else 'GREEN'))
            if not ok:
                bad += 1
                print('        -> %s' % (_ap.split('\n')[0] if _ap else 'NOTHING AT ALL'))

    # The predicate on its own. The end-to-end cases above cannot separate "KEEP rows are excluded"
    # from "that KEEP row had no usable section anyway", so the conjunct is held here instead.
    real_dests = att.executed_transfer_destinations(d1_rows, COV_OWNER)
    ok = real_dests == {PIN_PATH}
    print('  [%s] against the REAL D1 the predicate selects exactly the one executed transfer'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> selected %r, wanted {%r}' % (sorted(real_dests), PIN_PATH))
        bad += 1
    _synth_rows = [
        {'current_owner': 'o1', 'disposition': 'TRANSFER',
         'proposed_owner': 'a', 'owner_ref': {'path': 'a'}},                              # in
        {'current_owner': 'o1', 'disposition': 'KEEP',
         'proposed_owner': 'b', 'owner_ref': {'path': 'b'}},                              # out
        {'current_owner': 'o1', 'disposition': 'TRANSFER',
         'proposed_owner': 'c2', 'owner_ref': {'path': 'c1'}},                            # out
        {'current_owner': 'o1', 'disposition': 'TRANSFER',
         'proposed_owner': 'd', 'owner_ref': None},                                       # out
    ]
    synth = att.executed_transfer_destinations(_synth_rows, 'o1')
    ok = synth == {'a'}
    print('  [%s] and on synthetic rows only TRANSFER-with-path==proposed_owner is selected'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %r' % sorted(synth))
        bad += 1

    print('\n=== ORDER-1310 #1: WHICH section is "the approved one", asked of the store ===')
    # The end-to-end attack is in `exemption_attacks` above. These hold the resolver itself,
    # because the attack case alone cannot separate "it named the wrong section" from
    # "declared_owner_section returns None for everything", which would also make THE POINT red
    # -- but only if somebody is still running THE POINT.
    _declared = att.declared_owner_section(PIN_PATH)
    ok = bool(_declared) and _declared.startswith('## ')
    print('  [%s] the destination store DECLARES the owner section it projects into'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %r' % _declared)
        bad += 1
    # ...and it is the SAME string the in-force record binds. This is the assertion that makes
    # the exemption an agreement between two independently-written artifacts rather than a name
    # this checker knows: neither side is typed here.
    ok = COV_EPS is not None and _declared == COV_EPS.get('section')
    print('  [%s] and it is the section the in-force record binds -- nothing is hardcoded here'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> store=%r record=%r' % (_declared, (COV_EPS or {}).get('section')))
        bad += 1
    # FAIL CLOSED. A destination that is not a store declaring a section declares nothing, and
    # "nothing" must not read as "any section will do".
    ok = att.declared_owner_section('MASTER_BACKLOG.md') is None
    print('  [%s] a destination that is not a JSONL store declares NOTHING, not anything'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1
    ok = att.declared_owner_section('no/such/path/at/head.jsonl') is None
    print('  [%s] and neither does a path that is not at HEAD' % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1

    print('\n=== ORDER-1310 #3: the exemption is ROW-scoped, and it used to be PATH-scoped ===')
    # REPRODUCED by the independent review and again here. `executed_transfer_destinations` used
    # to return a set of paths gathered from EVERY D1 row, so any owner whose note named a path
    # some OTHER row had donated inherited the exemption -- while the comment beside it called it
    # "for that row only". Today's D1 has no such pair, which is why nothing was red.
    _donor_recipient = _synth_rows[:1] + [
        # a DIFFERENT owner, KEEP, pinning the very path o1's executed transfer donated
        {'current_owner': 'o2', 'disposition': 'KEEP',
         'proposed_owner': 'a', 'owner_ref': {'path': 'a'}},
    ]
    ok = att.executed_transfer_destinations(_donor_recipient, 'o2') == set()
    print('  [%s] a KEEP row pinning ANOTHER owner\'s executed destination inherits nothing'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> selected %r for o2, which owns no executed transfer'
              % sorted(att.executed_transfer_destinations(_donor_recipient, 'o2')))
        bad += 1
    # CONTROL, in the same fixture: the owner that DOES own the transfer still gets it. Without
    # this the negative above is satisfiable by a predicate that returns the empty set forever.
    ok = att.executed_transfer_destinations(_donor_recipient, 'o1') == {'a'}
    print('  [%s] CONTROL ...and the owner whose OWN row it is still gets the exemption'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        bad += 1
    # END TO END, because the predicate-level case cannot prove `check()` actually asks it per
    # row -- the destination set used to be computed ONCE outside the loop, which is a place the
    # scoping can be lost again without this failing. A real second owner, a real reproducing
    # section claim, and a D1 injected with one extra KEEP row pinning the Coverage destination.
    _borrowed = [dict(r) for r in d1_rows] + [
        {'entity': 'BorrowedPin', 'current_owner': 'AGENT_TASKBOARD.md', 'disposition': 'KEEP',
         'proposed_owner': PIN_PATH, 'owner_ref': {'path': PIN_PATH, 'blob_oid': 'b' * 40}},
    ]
    _, _bp = run_with([good(current_owner='AGENT_TASKBOARD.md',
                            expected_post_state=_derived_section_eps('AGENT_TASKBOARD.md'))],
                      [STALE_NOTE], d1_override=_borrowed)
    ok = 'pin is STALE' in _bp
    print('  [%s] END TO END a second owner borrowing the Coverage destination is still asked'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %s' % (_bp.split('\n')[0] if _bp else 'NOTHING AT ALL -- exempted'))
        bad += 1

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
    # ORDER-1269 #1: the COMPARISON below is unchanged; its STATED REASON was false and is deleted.
    # It read "no note today, so the template emits NO ack skeleton" -- an assertion about the state
    # of the world, not about the code, and a legitimate 16-row append to the coverage store made it
    # RED without anything being wrong. (Measured at HEAD before this order: `--template` emitted
    # the skeleton because three vintage notes genuinely exist.) What the template must actually do
    # is AGREE WITH F2: emit a skeleton exactly when an acknowledgement is owed. Narrowed, not
    # flipped -- a session that met this red and "repaired" it by asserting the skeleton IS present
    # would have written the deadlock back into the owner's handout.
    ok = 'stale_pin_acknowledgement' not in tline
    print('  [%s] M1: the template emits NO ack skeleton, because F2 demands none for this owner'
          % ('OK ' if ok else 'BAD'))
    if not ok:
        print('        -> %r' % (tline.get('stale_pin_acknowledgement'),))
        bad += 1
    # The fire direction: force a synthetic note on the D1-pinned path and re-run. The ack
    # skeleton must name THAT path (the mapping), never current_owner -- F3 refuses the other.
    #
    # ORDER-1269 #1 changed this fixture from STALE to MISSING, and the ASSERTION is untouched.
    # The property under test is the MAPPING (which path the skeleton names), and a STALE note on
    # this particular path is now exempt, so the old fixture would have tested the mapping through
    # a door that no longer opens -- green or red for a reason that is not the mapping. MISSING is
    # never exempt (deleting the destination is not the approval succeeding), so an acknowledgement
    # is genuinely owed here and the mapping is exercised exactly as before. The exempt direction is
    # not lost: it is asserted two cases below, against BOTH surfaces at once.
    pin_path = PIN_PATH
    saved_notes = chk.pin_vintage_notes
    try:
        chk.pin_vintage_notes = lambda rows: [{'path': pin_path, 'kind': 'MISSING'}]
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
    # ORDER-1269 #1: THE TWO HUMAN SURFACES MUST AGREE, asserted from ONE forced condition rather
    # than from whatever notes the repository happens to have today. A checker that stops demanding
    # an acknowledgement while the handout keeps asking for one is this order's own defect #2
    # pointing the other way: the owner is told to spend a signature nothing will read.
    if COV_EPS is not None:
        saved_notes2 = chk.pin_vintage_notes
        try:
            chk.pin_vintage_notes = lambda rows: [{'path': pin_path, 'kind': 'STALE'}]
            buf3 = io.StringIO()
            with contextlib.redirect_stdout(buf3):
                rc_t3 = att.main(['--template'])
            tline3 = json.loads([l for l in buf3.getvalue().splitlines() if l.startswith('{')][0])
        finally:
            chk.pin_vintage_notes = saved_notes2
        _, probs_ag = run_with([good(expected_post_state=COV_EPS)],
                               [{'entity': 'CoverageCell', 'path': pin_path, 'kind': 'STALE',
                                 'text': 'stale'}])
        template_asks = 'stale_pin_acknowledgement' in tline3
        checker_demands = 'pin is STALE' in probs_ag
        ok = rc_t3 == 0 and template_asks is False and checker_demands is False
        print('  [%s] AGREEMENT under one forced STALE note the template and F2 give the SAME '
              'answer (neither asks)' % ('OK ' if ok else 'BAD'))
        if not ok:
            print('        -> template_asks=%s checker_demands=%s' % (template_asks, checker_demands))
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
