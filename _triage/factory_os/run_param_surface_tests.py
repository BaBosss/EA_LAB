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
