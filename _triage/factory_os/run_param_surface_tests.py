# -*- coding: utf-8 -*-
"""run_param_surface_tests.py -- ORDER-1020 (S7). The cage for the design 5.4 state-table checker.

HOW THE ATTACKS WORK, AND WHY THEY ARE NOT MUTATIONS OF THE CHECKER. Each case corrupts a COPY of
the real `factory/parameter_bindings.jsonl` text -- the thing the checker reads -- and requires the
named criterion to fire. That is the right direction here: `check_param_surface` exists to catch a
store that has gone wrong, so the attack has to BE a store that has gone wrong. Mutating the
checker instead would only prove the code is reachable.

Nothing on disk is touched. The corrupted text is handed to `check()` through a stub source, which
is possible only because the checker takes its `EvidenceSource` as an argument -- the same seam
that lets the tier judge the index instead of the worktree.

EVERY criterion appears TWICE (`docs/GUARD_SHAPES.md` shape 5):
    ATTACK       the store this criterion exists to refuse. It must be RED.
    SPECIFICITY  the REAL store, which must stay green.

The specificity half is not symmetry: **a checker that refused every store would pass all six
attacks.** The real store passing is the only thing that makes the attacks mean anything, and it is
asserted once per criterion rather than once per file so no attack can be quoted without it.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_param_surface_tests.py
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import check_param_surface as C                                             # noqa: E402
import gen_registry_rows as gen                                             # noqa: E402
import preset                                                               # noqa: E402

REV = 'B14-H01-r1'


def _disk(rel):
    return io.open(os.path.join(ROOT, rel.replace('/', os.sep)),
                   encoding='utf-8-sig').read()                 # snapshot: worktree


class StubSource(object):
    """An EvidenceSource-shaped stand-in whose bytes the case chooses.

    It implements exactly the one method `check()` uses. A stub that implemented more would be
    claiming to be an EvidenceSource, and the next person would use it as one.
    """

    mode = 'stub'

    def __init__(self, overrides):
        self._overrides = overrides

    def read_committed(self, rel, errors='strict'):
        if rel in self._overrides:
            return self._overrides[rel]
        return _disk(rel)

    def marker(self, component):
        return '##EVIDENCE-MODE## %s stub git_index=none' % component


def _rows(text):
    out = []
    for line in text.replace('\r\n', '\n').split('\n'):
        if line.strip():
            out.append(json.loads(line))
    return out


def _render(rows):
    import registry
    return '\n'.join(registry.canonical_line(r) if r.get('entity') else json.dumps(r)
                     for r in rows) + '\n'


def mutate_bindings(fn):
    """-> the bindings text with `fn` applied to the parsed row list."""
    rows = _rows(_disk(gen.BINDINGS_REL))
    fn(rows)
    return _render(rows)


def run_check(bindings_text=None, hyp_text=None):
    over = {}
    if bindings_text is not None:
        over[gen.BINDINGS_REL] = bindings_text
    if hyp_text is not None:
        over[gen.HYPOTHESES_REL] = hyp_text
    return C.check(source=StubSource(over))


def fired(problems, tag):
    return [p for p in problems if p.startswith(tag)]


# --- the attacks ---------------------------------------------------------------------------------

def _first_of(rows, rev, pred):
    for r in rows:
        if r.get('hypothesis_revision') == rev and pred(r):
            return r
    raise AssertionError('fixture found no row matching its predicate')


def a_p1_missing(rows):
    rows.remove(_first_of(rows, REV, lambda r: r.get('parameter') == '_22_TP_ATRmult'))


def a_p1_dupe(rows):
    rows.append(dict(_first_of(rows, REV, lambda r: r.get('parameter') == '_22_TP_ATRmult')))


def a_p2_locked_no_value(rows):
    r = _first_of(rows, REV, lambda x: x.get('role') == 'LOCKED')
    r['locked_value'] = None


def a_p2_inactive_shown(rows):
    r = _first_of(rows, REV, lambda x: x.get('role') == 'INACTIVE')
    r['surface'] = 'OPERATOR'


def a_p3_unknown_stage(rows):
    r = _first_of(rows, REV, lambda x: x.get('surface') == 'OPERATOR')
    r['optimize_stage'] = 'UNKNOWN'


def a_p4_over_target(rows):
    n = 0
    for r in rows:
        if r.get('hypothesis_revision') == REV and r.get('surface') == 'HIDDEN' \
                and r.get('role') == 'INACTIVE':
            r['surface'] = 'OPERATOR'
            r['optimize_stage'] = 'SIGNAL'
            n += 1
            if n >= 30:
                break


def a_p6_dangling(rows):
    for r in rows:
        if r.get('hypothesis_revision') == REV:
            r['hypothesis_revision'] = 'B14-H97-r1'


def a_p5_coherent_but_stale(rows):
    """The ONLY attack that is INTERNALLY COHERENT. It edits a `safe_range` bound -- a value no
    other criterion has an opinion about -- so P1/P2/P3/P4/P6 all stay silent and P5 has to carry
    the case alone. That is the whole reason P5 exists: the five checks above are equally happy
    with a store that has quietly stopped matching its source."""
    r = _first_of(rows, REV, lambda x: x.get('safe_range'))
    r['safe_range'] = dict(r['safe_range'])
    r['safe_range']['stop'] = r['safe_range']['stop'] + 1


def a_p5_wrong_pin(rows):
    """/scrutinize round 2. P5 first excluded the WHOLE OwnerRef from its comparison, to avoid
    demanding that a historical pin track HEAD. It excluded too much: a `definition_ref` rewritten
    to point at a file that owns none of these semantics produced ZERO problems. Only the three
    git-resolved fields are excluded now, so `path` -- the STATEMENT the pin makes about what it
    pins -- is compared like everything else."""
    r = _first_of(rows, REV, lambda x: x.get('definition_ref'))
    r['definition_ref'] = dict(r['definition_ref'])
    r['definition_ref']['path'] = 'docs/NOT_THE_REGISTRY.csv'


CASES = (
    ('P5', 'a store that is COHERENT but no longer what the generator produces',
     a_p5_coherent_but_stale),
    ('P5', 'a definition_ref pointing at a file that owns none of these semantics',
     a_p5_wrong_pin),
    ('P1', 'an input the build exposes with no binding row', a_p1_missing),
    ('P1', 'one parameter bound twice under one revision', a_p1_dupe),
    ('P2', 'role=LOCKED carrying no locked_value', a_p2_locked_no_value),
    ('P2', 'role=INACTIVE shown on the OPERATOR surface', a_p2_inactive_shown),
    ('P3', 'an OPERATOR row whose optimize_stage is UNKNOWN', a_p3_unknown_stage),
    ('P4', 'an Operator surface past design 5.3 target', a_p4_over_target),
    ('P6', 'bindings naming a revision no Hypothesis registers', a_p6_dangling),
)


def _p5_vintage_case():
    """/scrutinize round 3, and it is a criterion about the MESSAGE rather than the verdict.

    `check()` reads the stores through its source but imports the generator from disk, so under
    the hook it compares INDEX bytes against a WORKTREE generator. Probed by editing
    `hypothesis_b14.py` without staging it: the run reported `P5 ... is not what
    gen_registry_rows.py produces` and told the author to REGENERATE -- which would have staged
    a change they had not decided to make. Both diagnoses go red; only one is true, and the
    wrong one sends the reader to fix a file that is correct."""
    target = "_triage/factory_os/gen_registry_rows.py"

    class _MixedSource(StubSource):
        mode = 'index'      # the only mode the vintage question exists in

        def read_committed(self, rel, errors='strict'):
            if rel == target:
                return _disk(rel) + chr(10) + '# not the committed bytes'
            return StubSource.read_committed(self, rel, errors)

    # the store must ALSO differ, or there is nothing for the wrong message to be attached to
    return C.check(source=_MixedSource(
        {gen.BINDINGS_REL: mutate_bindings(a_p5_coherent_but_stale)}))


def _p5_stale_import_case():
    """The one that nearly shipped a decision nobody made: a same-length edit restored inside one
    second leaves a `.pyc` CPython still considers valid, so `import` and the FILE disagree --
    and P5 cannot see it, because it regenerates through that same import. Simulated by handing
    the checker a source text that differs from what it imported."""
    rel = '_triage/factory_os/hypothesis_b14.py'

    class _StaleSource(StubSource):
        def read_committed(self, rel_, errors='strict'):
            if rel_ == rel:
                return _disk(rel_).replace(
                    "'_14_DistAtrMult':    ('TUNABLE', 'OPERATOR'",
                    "'_14_DistAtrMult':    ('TUNABLE', 'RESEARCH'")
            return StubSource.read_committed(self, rel_, errors)

    return C.check(source=_StaleSource({}))


def _registration_specificity():
    hyps = [r for _n, r in C._rows_of(_disk(gen.HYPOTHESES_REL), 'Hypothesis')]
    binds = [r for _n, r in C._rows_of(_disk(gen.BINDINGS_REL), 'ParameterBinding')]
    problems = []

    prereg = '82fb2d06f8b6a6240ff1aa222d14e4438fead1e4'
    anchor = 'FACTORY-B11-16-PROSPECTIVE-H01-PREREGISTRATION:'
    expected_counts = {11:139, 12:143, 13:145, 15:145, 16:161}
    for number, expected_count in sorted(expected_counts.items()):
        revision = 'B%d-H01-r1' % number
        hs = [h for h in hyps if h.get('revision_id') == revision]
        rows = [r for r in binds if r.get('hypothesis_revision') == revision]
        if len(hs) != 1:
            problems.append('%s hypothesis count is %d, expected 1' % (revision, len(hs)))
        else:
            h = hs[0]
            ref = h.get('preregistration_ref') or {}
            if ref.get('commit_oid') != prereg:
                problems.append('%s prereg commit drifted to %r' % (revision, ref.get('commit_oid')))
            if ref.get('anchor') != anchor:
                problems.append('%s prereg anchor drifted to %r' % (revision, ref.get('anchor')))
            if h.get('status') != 'REGISTERED':
                problems.append('%s lifecycle status is not REGISTERED' % revision)
        if len(rows) != expected_count:
            problems.append('%s binding count is %d, expected %d logical rows'
                            % (revision, len(rows), expected_count))
        if any(r.get('role') == 'TUNABLE' for r in rows):
            problems.append('%s exposes a TUNABLE row despite fixed-config H01 authority' % revision)
        if any(r.get('optimize_stage') not in (None, 'FREEZE') for r in rows):
            problems.append('%s exposes non-FREEZE optimize_stage under fixed-config H01' % revision)
        if any(r.get('safe_range') is not None for r in rows):
            problems.append('%s exposes a safe_range under zero optimizer authority' % revision)

    b17h = [h for h in hyps if h.get('revision_id') == 'B17-H01-r1']
    b17 = [r for r in binds if r.get('hypothesis_revision') == 'B17-H01-r1']
    if len(b17h) != 1:
        problems.append('B17-H01-r1 hypothesis count is %d, expected 1' % len(b17h))
    else:
        h = b17h[0]
        if h.get('architecture_digest') != '52921084a24c3ea9':
            problems.append('B17 digest drifted to %r' % h.get('architecture_digest'))
        ref = h.get('preregistration_ref') or {}
        if ref.get('commit_oid') != '0e9cebb1e87f155656c479055ea0e94212f51384':
            problems.append('B17 prereg commit drifted')
        if ref.get('anchor') != 'Entry_Wave5:':
            problems.append('B17 prereg anchor drifted')
        if h.get('status') != 'REGISTERED':
            problems.append('B17 lifecycle status is not REGISTERED')
    if len(b17) != 147:
        problems.append('B17 binding count is %d, expected 147 logical rows' % len(b17))
    counts = {}
    for row in b17:
        counts[row.get('role')] = counts.get(row.get('role'), 0) + 1
    expected = {'INACTIVE':106,'LOCKED':31,'SAFETY':7,'SIZING':1,'RUNTIME':2}
    if counts != expected:
        problems.append('B17 role counts %r != %r' % (counts, expected))
    if sum(1 for r in b17 if r.get('surface') == 'OPERATOR') != 7:
        problems.append('B17 Operator surface is not exactly 7 rows')
    if any(r.get('role') == 'TUNABLE' for r in b17):
        problems.append('B17 historical frozen registration exposes a TUNABLE row')
    b18h = [h for h in hyps if h.get('revision_id') == 'B18-H01-r1']
    b18 = [r for r in binds if r.get('hypothesis_revision') == 'B18-H01-r1']
    if len(b18h) != 1:
        problems.append('B18-H01-r1 hypothesis count is %d, expected 1' % len(b18h))
    else:
        h = b18h[0]; ref = h.get('preregistration_ref') or {}
        if h.get('architecture_digest') != '7e3ca0ad95500570': problems.append('B18 digest drifted')
        if ref.get('commit_oid') != '44adcd3fd02b8e5edc77842951f96b017e2a0d59': problems.append('B18 prereg commit drifted')
        if ref.get('anchor') != 'FACTORY-B18-H01-PREREGISTRATION': problems.append('B18 prereg anchor drifted')
        if h.get('status') != 'REGISTERED': problems.append('B18 lifecycle status is not REGISTERED')
    if len(b18) != 147: problems.append('B18 binding count is %d, expected 147 logical rows' % len(b18))
    counts18 = {}
    for row in b18: counts18[row.get('role')] = counts18.get(row.get('role'), 0) + 1
    expected18 = {'INACTIVE':102,'LOCKED':35,'SAFETY':7,'SIZING':1,'RUNTIME':2}
    if counts18 != expected18: problems.append('B18 role counts %r != %r' % (counts18, expected18))
    for name in ('_18_DirMode','_18_Direction'):
        rows18 = [r for r in b18 if r.get('parameter') == name]
        if len(rows18) != 1 or rows18[0].get('role') != 'LOCKED' or str(rows18[0].get('locked_value')) != '1':
            problems.append('B18 %s is not exactly LOCKED=1' % name)
    if any(r.get('role') == 'TUNABLE' for r in b18): problems.append('B18 fixed H01 exposes a TUNABLE row')
    return problems


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-1020 design 5.4 state table: %d attacks, each with the real store as its '
          'specificity half ===' % len(CASES))

    # The specificity half, computed ONCE and asserted against every criterion below: the REAL
    # store must produce no problem at all. Without this a checker that refuses everything passes
    # every attack in this file.
    try:
        clean = run_check()
    except (preset.PresetRefusal, Exception) as exc:              # noqa: BLE001
        print('  [BAD] the REAL store could not be checked at all: %s: %s'
              % (type(exc).__name__, str(exc)[:160]))
        return 1
    if clean:
        print('  [BAD] specificity the REAL store is not clean, so no attack below means anything')
        for p in clean:
            print('        -> %s' % p[:170])
        return 1
    print('  [OK ] specificity the REAL store produces ZERO problems')
    registration = _registration_specificity()
    if registration:
        print('  [BAD] B11-17/B18 registration specificity failed: %s' % '; '.join(registration))
        return 1
    print('  [OK ] B11/B12/B13/B15/B16/B18 fixed H01 registrations expose 0 tunables; B17 preserved')

    for label, fn, needle, miss in (
            ('a generator whose COMMITTED bytes are not the ones python imported',
             _p5_vintage_case, 'CANNOT BE PERFORMED',
             'NOT CAUGHT -- it would have told the author to regenerate'),
            ('a stale .pyc: the IMPORT and the FILE disagree, and P5 shares the import',
             _p5_stale_import_case, 'is not the DECISIONS in the file',
             'NOT CAUGHT -- a decision nobody made would regenerate into the canonical store')):
        got = fn()
        hit = [p for p in got if needle in p]
        ok = bool(hit)
        bad += 0 if ok else 1
        print('  [%s] P5  attack %s' % ('OK ' if ok else 'BAD', label))
        print('        -> %s' % (hit or got or [miss])[0][:150])

    for tag, label, fn in CASES:
        try:
            problems = run_check(bindings_text=mutate_bindings(fn))
        except Exception as exc:                                  # noqa: BLE001
            print('  [BAD] %-3s %-52s raised %s: %s'
                  % (tag, label[:52], type(exc).__name__, str(exc)[:90]))
            bad += 1
            continue
        hit = fired(problems, tag)
        ok = bool(hit)
        bad += 0 if ok else 1
        print('  [%s] %-3s attack %s' % ('OK ' if ok else 'BAD', tag, label))
        if ok:
            print('        -> %s' % hit[0][:150])
        else:
            print('        -> NOT CAUGHT. Other problems reported: %s'
                  % ('; '.join(p[:70] for p in problems) or 'none at all'))

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, and the real store stayed clean ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
