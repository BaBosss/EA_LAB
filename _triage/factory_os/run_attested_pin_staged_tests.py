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

WHAT THIS SUITE DOES NOT DO, said plainly: it does not construct a git repository. `evaluate` is
driven with an injected resolver, so what is proved is the RULE. That the rule is fed the right
bytes is proved separately -- by `_index_source` being pinned to the index and by the real run
in the tier, which reads the real log.
"""
from __future__ import annotations

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
