"""ORDER-731 -- the cage for check_attested_pin_staged.py.

GUARD_SHAPES shape 5 says a REPAIR TO A GUARD IS WRITING A GUARD, so this runs that pre-flight
on itself. A repair ships because the counter-example that demanded it stops firing -- and the
counter-example is a POINT while the invariant is a REGION. So every case below is one of:

    ATTACK       the defect's own shape -- must be REFUSED
    ENGAGEMENT   fails if the new mechanism is INERT (the "fail-closed and broken point the same
                 way" trap: if `pinned_expectations` ever returns {}, every commit passes and a
                 suite that only asserts "no problems" goes green for the wrong reason)
    SPECIFICITY  fails if the repair over-reaches onto inputs the counter-example never touched
    CONTROL      the REPAIR commit itself must be allowed to land, or the guard recreates the
                 trap it was written to close

Every criterion this checker can emit is named in a string literal here, which is what L2 of
run_guard_shape_lint.py parses for: P1, P2, P3, P4.

TWO KINDS OF CASE, and the split is the point:

  * `run_rule_cases` drives `evaluate` with an INJECTED resolver. What is proved is the RULE, with
    no git state to arrange.
  * `run_snapshot_cases` proves the rule is fed the RIGHT BYTES, by staging a tampered log into a
    TEMPORARY index and demanding the index and worktree sources DISAGREE.

The second one exists because the first was, for a while, all there was -- and mutating
`_index_source` to return a worktree source left every case green. "The rule is correct" and
"the rule is applied to the commit" are different claims and they need different evidence.

WHAT THIS SUITE STILL DOES NOT DO: it never runs `git commit`. That the guard is WIRED -- that
`.githooks/pre-commit` actually calls it and acts on its exit code -- is proved by the real
end-to-end run recorded in the ORDER-731 board row, not here.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_attested_pin_staged as guard  # noqa: E402
import check_s2a_attestation as att  # noqa: E402
import check_s2a_migration as chk  # noqa: E402
import evidence  # noqa: E402

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(os.path.dirname(_HERE))

PIN = '02c1d0edfa9123d88427e44f66c70583d1da61bb'
OTHER = '0740c0eac9bc303807eeb9ff585fa70ccd0b8e53'
PATH = 'MASTER_BACKLOG.md'

# ORDER-731 option A. The SECTION fixtures, and every one of them is TEXT the test owns: the
# approved region's digest is COMPUTED below from `BOARD_APPROVED` by the checker's own rule, never
# typed as a constant. A typed digest here would be guard shape 4 -- a claim stated without
# measuring it -- inside the cage written to catch exactly that.
SECTION = '## 2. COVERAGE MATRIX'
BOARD_APPROVED = '\n'.join([
    '# BOARD', '', '## 1. FIRST', '', 'row one', '',
    SECTION, '', '| cell | value |', '| A | 1 |', '',
    '## 3. BACKLOG', '', '| D30 | an existing row |', '',
])
# §2 BYTE-IDENTICAL, §3 changed. This is the commit option A was bought to allow.
BOARD_S3_APPENDED = BOARD_APPROVED.replace(
    '| D30 | an existing row |',
    '| D30 | an existing row |\n| D33 | a row appended by another lane |')
# §2 CHANGED. This is the commit option A must still refuse.
BOARD_S2_EDITED = BOARD_APPROVED.replace('| A | 1 |', '| A | 2 |')
BOARD_NO_ANCHOR = BOARD_APPROVED.replace(SECTION, '## 2. COVERAGE MATRIX RENAMED')
BOARD_ANCHOR_TWICE = BOARD_APPROVED + '\n' + SECTION + '\n\n| A | 9 |\n'
BOARD_UNTERMINATED = BOARD_APPROVED + '\n```\nnobody closed this fence\n'

RESULTS = []


def case(kind, name, ok, detail=''):
    RESULTS.append((kind, name, bool(ok), detail))
    print('  [%s] %-11s %s%s' % ('OK ' if ok else 'FAIL', kind, name,
                                 ('' if ok else '  <- ' + detail)))


def fired(problems, code):
    return any(p.startswith(code + ' ') for p in problems)


def run_rule_cases():
    pins = {PATH: guard.Pin('blob', PIN, 'expected_post_state.blob', None)}

    # ATTACK -- 78a93129 exactly: the pinned board is carried by the commit at a different blob.
    p = guard.evaluate(pins, {PATH}, resolve=lambda _p: OTHER)
    case('ATTACK', 'a commit that moves the pinned blob is refused with P1',
         fired(p, 'P1') and len(p) == 1, repr(p))

    # CONTROL -- and this one is load-bearing rather than decorative. If the guard refused every
    # commit that touches the pinned path, the REPAIR commit (restore the pinned bytes) would be
    # refused too, and the guard would have rebuilt the trap: a gate that blocks its own repair.
    p = guard.evaluate(pins, {PATH}, resolve=lambda _p: PIN)
    case('CONTROL', 'restoring the pinned blob is ALLOWED to land',
         p == [], repr(p))

    # SPECIFICITY -- a commit that does not carry the pinned path cannot move it.
    p = guard.evaluate(pins, {'docs/SESSION_LEDGER.md'}, resolve=lambda _p: OTHER)
    case('SPECIFICITY', 'an unrelated commit is not refused',
         p == [], repr(p))

    # P2, both branches. A deletion cannot satisfy a pin, and a pin whose value is the literal
    # MISSING approves the file being ABSENT -- so carrying it is the violation.
    p = guard.evaluate(pins, {PATH}, resolve=lambda _p: None)
    case('ATTACK', 'deleting the pinned path is refused with P2',
         fired(p, 'P2') and len(p) == 1, repr(p))

    missing_pin = {PATH: guard.Pin('blob', 'MISSING',
                                   'stale_pin_acknowledgement.current_blob', None)}
    p = guard.evaluate(missing_pin, {PATH}, resolve=lambda _p: OTHER)
    case('ATTACK', 'adding a path pinned to the literal MISSING is refused with P2',
         fired(p, 'P2') and len(p) == 1, repr(p))

    # SPECIFICITY for the MISSING branch: absent is what that pin approves.
    p = guard.evaluate(missing_pin, set(), resolve=lambda _p: None)
    case('SPECIFICITY', 'a MISSING pin does not fire when the commit leaves the path alone',
         p == [], repr(p))


def run_section_cases():
    """ORDER-731 option A: the pin is now a SECTION, and this is where that is proved.

    The digest is COMPUTED from the fixture the test owns, so the cage cannot pass by agreeing
    with a number somebody typed. `read` is injected for the same reason `resolve` already was:
    what is proved here is the RULE, with no index to arrange.
    """
    approved, err = att.section_digest(BOARD_APPROVED, SECTION)
    if err:
        case('ATTACK', 'the section fixture is extractable at all', False, err)
        return
    pins = {PATH: guard.Pin('section', approved,
                            'expected_post_state.section_sha256', SECTION)}

    def ev(text, staged=(PATH,)):
        return guard.evaluate(pins, set(staged), resolve=lambda _p: OTHER,
                              read=lambda _p: text)

    # ATTACK -- the approved region itself moved. This is 78a93129's shape, narrowed.
    p = ev(BOARD_S2_EDITED)
    case('ATTACK', 'a commit whose staged section hashes differently is refused with P1',
         fired(p, 'P1') and len(p) == 1, repr(p))

    # CONTROL -- THE POINT OF THE WHOLE AMENDMENT. An append to an UNPINNED section must land.
    # This is what goes red if a future repair re-widens the pin to the whole file, hashes the
    # file instead of the region, or walks the region end off by one and swallows section 3.
    p = ev(BOARD_S3_APPENDED)
    case('CONTROL', 'appending a row to section 3 with section 2 byte-identical LANDS',
         p == [], repr(p))

    # CONTROL -- the ORDER-731 item-1 semantics, section-scoped: the REPAIR commit must land, or
    # the guard has rebuilt the trap it was written to close.
    p = ev(BOARD_APPROVED)
    case('CONTROL', 'restoring the approved section after a bad edit is ALLOWED to land',
         p == [], repr(p))

    # FAIL CLOSED, all three branches. "I could not find the section" must never share an outcome
    # with "the section is unchanged": each of these must be a REFUSAL naming P4, and a refusal is
    # what makes main() exit non-zero.
    p = ev(BOARD_NO_ANCHOR)
    case('ATTACK', 'an anchor absent from the staged bytes is refused with P4',
         fired(p, 'P4') and len(p) == 1, repr(p))

    p = ev(BOARD_ANCHOR_TWICE)
    case('ATTACK', 'an anchor present TWICE is refused with P4 (no first-match-wins)',
         fired(p, 'P4') and len(p) == 1, repr(p))

    p = ev(BOARD_UNTERMINATED)
    case('ATTACK', 'staged bytes ending inside an unterminated fence are refused with P4',
         fired(p, 'P4') and len(p) == 1, repr(p))

    # SPECIFICITY -- a section pin still cannot fire for a commit that does not carry the path.
    p = ev(BOARD_S2_EDITED, staged=('docs/SESSION_LEDGER.md',))
    case('SPECIFICITY', 'a section pin does not fire for a commit that does not carry the path',
         p == [], repr(p))


def run_engagement_cases():
    """Fails if the mechanism is INERT -- read against the REAL attestation log, not a fixture.

    This is the case that would have caught shape 5's third sub-form: a checker that finds no
    pins passes everything, and "fail-closed and broken point the same way".
    """
    src = evidence.EvidenceSource('worktree', root=_ROOT)
    try:
        pins = guard.pinned_expectations(src)
    except Exception as exc:  # noqa: BLE001
        case('ENGAGEMENT', 'the real log yields at least one blob pin', False, repr(exc))
        return
    case('ENGAGEMENT', 'the real log yields at least one blob pin',
         len(pins) >= 1, 'pins=%r' % (pins,))
    case('ENGAGEMENT', 'the pin found carries a value of its KIND, not a placeholder',
         all((len(v.value) == 64 if v.kind == 'section'
              else (len(v.value) == 40 or v.value.upper() == 'MISSING'))
             for v in pins.values()),
         'pins=%r' % (pins,))

    # ORDER-731 option A, and this is the case that fails if `pinned_expectations` silently
    # returns {} for the NEW form -- the "fail-closed and broken point the same way" trap this
    # suite's header names. It is driven from a FIXTURE log rather than the real one on purpose:
    # the real log only carries a section-form record after the owner signs one, and a case whose
    # outcome depends on mutable repo state is not a case (the same rule the G5 fixtures state).
    import tempfile
    fd, tmp = tempfile.mkstemp(prefix='order731_sec_', suffix='.jsonl')
    saved_path = att.ATTESTATION_PATH
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps({
                'bundle_sha256': 'probe', 'current_owner': PATH, 'decision': 'APPROVED',
                'signer': 'run_attested_pin_staged_tests', 'decided_at': '2026-08-01T00:00',
                'reason': 'ORDER-731 section-form engagement fixture -- never committed',
                'expected_post_state': {'path': PATH, 'section': SECTION,
                                        'section_sha256': 'c' * 64},
            }, sort_keys=True) + '\n')
        att.ATTESTATION_PATH = tmp
        sec_pins = guard.pinned_expectations(src)
    finally:
        att.ATTESTATION_PATH = saved_path
        try:
            os.unlink(tmp)
        except OSError:
            pass
    got = sec_pins.get(PATH)
    case('ENGAGEMENT', 'a SECTION-form record yields a section-KIND pin naming its heading',
         got is not None and got.kind == 'section' and got.section == SECTION
         and got.value == 'c' * 64
         and got.field == 'expected_post_state.section_sha256', 'pins=%r' % (sec_pins,))

    # ORDER-731 review M3, both directions. An ack pin predicts F5, and F5 can only fire for a
    # path some D1 row PINS -- an ack naming anything else is validated by nobody (note=None skips
    # F3-F5), so enforcing it would predict a criterion that cannot fire. The measured attack:
    # copy the superseded line 8's ack (MASTER_BACKLOG.md, un-pinned since option 2) into a new
    # record -- checker green, and the un-fixed guard resurrected the whole-file toll.
    fd, tmp = tempfile.mkstemp(prefix='order731_m3_', suffix='.jsonl')
    saved_path = att.ATTESTATION_PATH
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps({
                'bundle_sha256': 'probe', 'current_owner': PATH, 'decision': 'APPROVED',
                'signer': 'run_attested_pin_staged_tests', 'decided_at': '2026-08-01T00:00',
                'reason': 'ORDER-731 M3 fixture: ack naming a path NO D1 row pins -- never committed',
                'stale_pin_acknowledged': True,
                'stale_pin_acknowledgement': {'path': PATH, 'pinned_blob': '0' * 40,
                                              'current_blob': '1' * 40,
                                              'reason': 'resurrection attempt'},
            }, sort_keys=True) + '\n')
        att.ATTESTATION_PATH = tmp
        m3_pins = guard.pinned_expectations(src)
    finally:
        att.ATTESTATION_PATH = saved_path
        try:
            os.unlink(tmp)
        except OSError:
            pass
    case('SPECIFICITY', 'an ack naming a path NO D1 row pins installs NO pin (F5 cannot fire for it)',
         PATH not in m3_pins, 'pins=%r' % (m3_pins,))
    # The other direction, or this case is the inert-guard trap itself: the SAME ack shape on a
    # path D1 DOES pin must still be enforced. factory/coverage.jsonl is D1-pinned (CoverageCell).
    fd, tmp = tempfile.mkstemp(prefix='order731_m3b_', suffix='.jsonl')
    saved_path = att.ATTESTATION_PATH
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps({
                'bundle_sha256': 'probe', 'current_owner': PATH, 'decision': 'APPROVED',
                'signer': 'run_attested_pin_staged_tests', 'decided_at': '2026-08-01T00:00',
                'reason': 'ORDER-731 M3 control: ack naming the D1-pinned path -- never committed',
                'stale_pin_acknowledged': True,
                'stale_pin_acknowledgement': {'path': 'factory/coverage.jsonl',
                                              'pinned_blob': '0' * 40,
                                              'current_blob': '1' * 40,
                                              'reason': 'legitimate ack shape'},
            }, sort_keys=True) + '\n')
        att.ATTESTATION_PATH = tmp
        m3b_pins = guard.pinned_expectations(src)
    finally:
        att.ATTESTATION_PATH = saved_path
        try:
            os.unlink(tmp)
        except OSError:
            pass
    got_b = m3b_pins.get('factory/coverage.jsonl')
    case('ENGAGEMENT', 'the SAME ack shape on a D1-pinned path IS still enforced (blob pin installed)',
         got_b is not None and got_b.kind == 'blob' and got_b.value == '1' * 40,
         'pins=%r' % (m3b_pins,))


def run_selection_cases():
    """The in-force selection is SHARED with check_s2a_attestation, and these prove the sharing.

    If a future edit gave this guard its own copy, one of these fails: a malformed trailing row
    must not displace the decision in force (the hole /scrutinize found in ORDER-613), and a
    SUPERSEDED row's pin must not be enforced -- history is not a live claim.
    """
    owners = ['MASTER_BACKLOG.md']
    good = {'bundle_sha256': 'x', 'current_owner': PATH, 'decision': 'APPROVED',
            'signer': 's', 'decided_at': 'd', 'reason': 'r', '_line': 1,
            'expected_post_state': {'path': PATH, 'blob': PIN}}
    older = dict(good, _line=0, expected_post_state={'path': PATH, 'blob': OTHER})
    malformed = {'signer': '', '_line': 2,
                 'expected_post_state': {'path': PATH, 'blob': OTHER}}

    m = att.in_force_map([older, good], owners)
    case('SPECIFICITY', 'a superseded row does not get to pin anything',
         m.get(PATH) is good, repr(m))

    m = att.in_force_map([older, good, malformed], owners)
    case('ATTACK', 'a malformed trailing row cannot displace the record in force',
         m.get(PATH) is good, repr(m))


def run_snapshot_cases():
    """🔴 ATTACK: the guard must read the INDEX, and NOTHING here proved that until now.

    Found by mutating the guard rather than by review. Changing `_index_source` to return a
    WORKTREE source left all eleven earlier cases green -- so the guard could approve bytes the
    commit does not contain, and its own cage would have said the repair was fine. That is
    GUARD_SHAPES shape 1 INSIDE the guard written to close a shape-1 defect, which is shape 5:
    the repair graded by the finding it closes.

    The fix is a DIFFERENTIAL, not an assertion about the mode string -- checking
    `_index_source().mode == 'index'` would be shape 2 (a name where a value is what matters).
    A tampered log is staged into a TEMPORARY index; the index source must see the tampered pin
    and the worktree source must see the real one. If both sources agree, the guard is not
    reading what it claims to read.

    The real `.git/index` and the working tree are never written: the tampered blob goes into the
    object database via `hash-object -w` (unreferenced, harmless) and only a COPY of the index is
    updated. `GIT_INDEX_FILE` is restored in `finally` -- memory `git-index-file-poisons-fixture-repos`
    is about leaking it into another repo, and it is why this is scoped and restored rather than set
    for the run.
    """
    import shutil
    import subprocess
    import tempfile

    TAMPERED = 'a' * 39 + '0'
    rc, gitdir, _ = chk._git('rev-parse', '--git-dir')
    real_index = os.path.join(gitdir, 'index')
    if rc != 0 or not os.path.isfile(real_index):
        case('ATTACK', 'index-vs-worktree differential', False, 'cannot locate .git/index')
        return

    worktree_src = evidence.EvidenceSource('worktree', root=_ROOT)
    try:
        base = worktree_src.read_committed(att.ATTESTATION_PATH)
    except Exception as exc:  # noqa: BLE001
        case('ATTACK', 'index-vs-worktree differential', False, repr(exc))
        return

    # A row that is ELIGIBLE by R4/R5/R6/R7 and therefore becomes the one in force, pinning a
    # DIFFERENT blob. Nothing else about it needs to be valid: this suite is asking which BYTES
    # the guard read, not whether the log is acceptable.
    extra = json.dumps({
        'bundle_sha256': 'probe', 'current_owner': PATH, 'decision': 'APPROVED',
        'signer': 'run_attested_pin_staged_tests', 'decided_at': '2026-08-01T00:00',
        'reason': 'ORDER-731 snapshot differential probe -- never committed',
        'expected_post_state': {'path': PATH, 'blob': TAMPERED},
    }, sort_keys=True)
    tampered = base.rstrip('\n') + '\n' + extra + '\n'

    p = subprocess.run(['git', 'hash-object', '-w', '--stdin'],
                       input=tampered.encode('utf-8'), capture_output=True)
    if p.returncode != 0:
        case('ATTACK', 'index-vs-worktree differential', False, p.stderr.decode('utf-8', 'replace'))
        return
    oid = p.stdout.decode('ascii').strip()

    tmp = tempfile.mkdtemp(prefix='order731_idx_')
    saved = os.environ.get('GIT_INDEX_FILE')
    try:
        tmp_index = os.path.join(tmp, 'index')
        shutil.copyfile(real_index, tmp_index)
        os.environ['GIT_INDEX_FILE'] = tmp_index
        rc, _o, err = chk._git('update-index', '--cacheinfo',
                               '100644,%s,%s' % (oid, att.ATTESTATION_PATH))
        if rc != 0:
            case('ATTACK', 'index-vs-worktree differential', False, err)
            return
        from_index = guard.pinned_expectations(guard._index_source())
        from_worktree = guard.pinned_expectations(worktree_src)
    finally:
        if saved is None:
            os.environ.pop('GIT_INDEX_FILE', None)
        else:
            os.environ['GIT_INDEX_FILE'] = saved
        shutil.rmtree(tmp, ignore_errors=True)

    idx_blob = getattr(from_index.get(PATH), 'value', '')
    wt_blob = getattr(from_worktree.get(PATH), 'value', '')
    case('ATTACK', 'the guard reads the INDEX: a log staged behind a clean worktree moves the pin',
         idx_blob == TAMPERED, 'index saw %r, expected the tampered %r' % (idx_blob, TAMPERED))
    case('SPECIFICITY', 'a worktree source still sees the real pin -- the two sources DISAGREE',
         wt_blob != TAMPERED and wt_blob != '' and idx_blob != wt_blob,
         'index=%r worktree=%r' % (idx_blob, wt_blob))


def run_tooling_cases():
    """P3 -- "I could not read it" must never share an exit path with "it is fine"."""
    saved = guard.pinned_expectations
    saved_staged = guard.staged_paths
    saved_exists = evidence.EvidenceSource.exists_committed
    try:
        guard.staged_paths = lambda: {PATH}
        evidence.EvidenceSource.exists_committed = lambda self, rel: True
        guard.pinned_expectations = lambda src: (_ for _ in ()).throw(
            evidence.ToolFailure('simulated unreadable index'))
        buf = []
        rc = _capture(guard.main, ['x'], buf)
        case('ATTACK', 'P3 an unreadable index exits 2, never 0',
             rc == 2 and any('P3' in l for l in buf), 'rc=%r out=%r' % (rc, buf))
    finally:
        guard.pinned_expectations = saved
        guard.staged_paths = saved_staged
        evidence.EvidenceSource.exists_committed = saved_exists


def _capture(fn, argv, buf):
    import io
    import contextlib
    s = io.StringIO()
    with contextlib.redirect_stdout(s):
        rc = fn(argv)
    buf.extend(s.getvalue().split('\n'))
    return rc


def main():
    print('=== ORDER-731: check_attested_pin_staged cage ===')
    print('    criteria this checker can emit: P1, P2, P3, P4')
    cwd = os.getcwd()
    os.chdir(_ROOT)
    try:
        run_rule_cases()
        run_section_cases()
        run_selection_cases()
        run_engagement_cases()
        run_snapshot_cases()
        run_tooling_cases()
    finally:
        os.chdir(cwd)
        chk._REVPARSE_MEMO.clear()

    failed = [r for r in RESULTS if not r[2]]
    kinds = {}
    for kind, _n, ok, _d in RESULTS:
        kinds[kind] = kinds.get(kind, 0) + (1 if ok else 0)
    print('\n  %d case(s): %s' % (len(RESULTS),
                                  ', '.join('%s %d' % (k, v) for k, v in sorted(kinds.items()))))
    if failed:
        print('=== %d FAILED ===' % len(failed))
        return 1
    print('=== ATTESTED-PIN GUARD: every criterion driven red for its own reason, and the '
          'REPAIR commit still lands ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
