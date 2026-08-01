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
run_guard_shape_lint.py parses for: P1, P2, P3.

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

RESULTS = []


def case(kind, name, ok, detail=''):
    RESULTS.append((kind, name, bool(ok), detail))
    print('  [%s] %-11s %s%s' % ('OK ' if ok else 'FAIL', kind, name,
                                 ('' if ok else '  <- ' + detail)))


def fired(problems, code):
    return any(p.startswith(code + ' ') for p in problems)


def run_rule_cases():
    pins = {PATH: (PIN, 'expected_post_state.blob')}

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

    p = guard.evaluate({PATH: ('MISSING', 'stale_pin_acknowledgement.current_blob')},
                       {PATH}, resolve=lambda _p: OTHER)
    case('ATTACK', 'adding a path pinned to the literal MISSING is refused with P2',
         fired(p, 'P2') and len(p) == 1, repr(p))

    # SPECIFICITY for the MISSING branch: absent is what that pin approves.
    p = guard.evaluate({PATH: ('MISSING', 'stale_pin_acknowledgement.current_blob')},
                       set(), resolve=lambda _p: None)
    case('SPECIFICITY', 'a MISSING pin does not fire when the commit leaves the path alone',
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
    case('ENGAGEMENT', 'the pin found is a 40-hex oid, not a placeholder',
         all(len(v[0]) == 40 or v[0].upper() == 'MISSING' for v in pins.values()),
         'pins=%r' % (pins,))


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

    idx_blob = (from_index.get(PATH) or ('', ''))[0]
    wt_blob = (from_worktree.get(PATH) or ('', ''))[0]
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
    print('    criteria this checker can emit: P1, P2, P3')
    cwd = os.getcwd()
    os.chdir(_ROOT)
    try:
        run_rule_cases()
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
