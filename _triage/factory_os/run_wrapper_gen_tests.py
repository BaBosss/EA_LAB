# -*- coding: utf-8 -*-
"""run_wrapper_gen_tests.py -- ORDER-1021 (S8). The cage for the Thin Wrapper generator's guard.

THE ATTACKS ARE CORRUPTED ARTIFACTS, not mutated code. `check_wrapper_gen` exists to catch a
generated file that has stopped being generated, so each case hands it a file that has -- through a
stub source, so nothing on disk is touched. That is possible only because the checker takes its
`EvidenceSource` as an argument, the same seam that lets the tier judge the index.

EVERY criterion appears TWICE (`docs/GUARD_SHAPES.md` shape 5):
    ATTACK       the artifact this criterion exists to refuse. It must be RED.
    SPECIFICITY  the REAL tree, which must stay green -- asserted once and gating the whole file,
                 because a checker that refused everything would pass every attack below.

🔴 W2's attack is the one worth reading. It adds a single line of MQL5 -- `int x = 0;` -- to a
wrapper. W1 catches that too (the file no longer matches the generator), so the pair could look
redundant. It is not: **W1 says "regenerate", W2 says "you put logic in a wrapper"**, and those are
different conversations with different next steps. The case therefore asserts W2 specifically
fired, not merely that something did.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_wrapper_gen_tests.py
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import check_wrapper_gen as C                                               # noqa: E402
import gen_registry_rows as grr                                            # noqa: E402
import gen_wrapper as gw                                                   # noqa: E402

REV = 'B14-H01-r1'
# Derived from the generator's own constants rather than spelled out: the wrapper and the allowlist
# live in DIFFERENT directories, and that split was settled by a compile (see gen_wrapper's note on
# WRAPPER_OUT_DIR). A literal path here would have gone stale the moment it moved, in the suite
# whose job is to notice things going stale.
WRAPPER = '%s/B14_H01_r1.mq5' % gw.WRAPPER_OUT_DIR
ALLOWLIST = '%s/B14_H01_r1_allowlist.mqh' % gw.GENERATED_DIR


def _disk(rel):
    # NEWLINES NORMALISED, because the real `EvidenceSource.read_committed` does it and a stub
    # that does not is not a stub, it is a different reader. It cost two cases: git's autocrlf
    # gives the worktree copy CRLF, so a fixture searching for a line ending in LF matched
    # nothing, the mutation silently did not happen, and both attacks reported "nothing at all"
    # -- a green-looking no-op rather than a failure anyone could read.
    raw = io.open(os.path.join(ROOT, rel.replace('/', os.sep)),
                  encoding='utf-8-sig').read()                 # snapshot: worktree
    return raw.replace(chr(13) + chr(10), chr(10))


class StubSource(object):
    """An EvidenceSource-shaped stand-in. `missing` names paths it must report as ABSENT, so the
    "the wrapper was never generated" branch can be exercised without deleting a real file."""

    mode = 'stub'

    def __init__(self, overrides=None, missing=()):
        self._overrides = overrides or {}
        self._missing = set(missing)

    def read_committed(self, rel, errors='strict'):
        if rel in self._missing:
            raise C.ToolFailure('%s is absent in the stub snapshot' % rel)
        if rel in self._overrides:
            return self._overrides[rel]
        return _disk(rel)

    def exists_committed(self, rel):
        return rel not in self._missing

    def marker(self, component):
        return '##EVIDENCE-MODE## %s stub git_index=none' % component


def run_check(**kw):
    return C.check(source=StubSource(**kw))


def fired(problems, tag):
    return [p for p in problems if p.startswith(tag)]


def _mutate(rel, old, new):
    """-> the file's text with `old` -> `new`, REFUSING if `old` was not there.

    🔴 THIS ASSERTION IS THE WHOLE POINT AND IT WAS ADDED AFTER IT WAS NEEDED. Two fixtures below
    used a bare `str.replace` against an include path that had MOVED. `replace` on a string that
    does not contain the needle is a silent no-op, so the "corrupted" artifact was byte-identical
    to the real one, `check()` correctly found nothing wrong with it, and the suite reported
    `NOT CAUGHT BY W2 ... nothing at all`. That reads as "the checker is broken" and the checker was
    fine. A fixture that quietly mutates nothing is the same defect class as a guard that quietly
    checks nothing -- and it is worse here, because it accuses working code.
    """
    text = _disk(rel)
    if old not in text:
        raise AssertionError(
            'fixture anchor not present in %s: %r. The attack would have mutated NOTHING and the '
            'case would have blamed the checker for finding nothing wrong.' % (rel, old[:60]))
    return text.replace(old, new)


# --- attacks --------------------------------------------------------------------------------------

def w1_drift():
    return {'overrides': {WRAPPER: _mutate(WRAPPER, '#property version   "2.00"',
                                           '#property version   "2.01"')}}


def w1_absent():
    return {'missing': (WRAPPER,)}


def w2_logic():
    """One line of real MQL5 in a wrapper. W1 fires as well -- the assertion is that W2 fires."""
    return {'overrides': {WRAPPER: _mutate(WRAPPER, '#include "../core/LabCore.mqh"',
                                           'int g_leak = 0;\n#include "../core/LabCore.mqh"')}}


def w3_token_mismatch():
    """The allowlist gains a token the Hypothesis row does not declare. Nothing else notices: the
    file still regenerates differently (W1), but W3 is the one that names the DISAGREEMENT."""
    return {'overrides': {ALLOWLIST: _mutate(ALLOWLIST, '#define LAB_CAP_STACK',
                                             '#define LAB_CAP_STACK\n#define LAB_CAP_HEDGE')}}


def w3_unregistered():
    """The wrapper exists; the Hypothesis row does not."""
    rows = []
    for line in _disk(grr.HYPOTHESES_REL).replace('\r\n', '\n').split('\n'):
        if not line.strip():
            continue
        rec = json.loads(line)
        if rec.get('revision_id') == REV:
            continue
        rows.append(line)
    return {'overrides': {grr.HYPOTHESES_REL: '\n'.join(rows) + '\n'}}


def w4_no_allowlist():
    return {'overrides': {WRAPPER: _mutate(WRAPPER,
                                           '#include "B14_H01_r1_allowlist.mqh"\n', '')}}


def w4_two_builds():
    return {'overrides': {WRAPPER: _mutate(WRAPPER, '#define LAB_ENTRY_14',
                                           '#define LAB_ENTRY_14\n#define LAB_ENTRY_16')}}


def w2_smuggled_include():
    """/scrutinize round 2. `#include "../core/Evil.mqh"` is trading logic BY REFERENCE -- the
    statement lives one file away and the wrapper still reads as sixteen clean lines. W1 fires
    too, but it says "regenerate"; only W2 says which RULE was broken."""
    keep = '#include "../core/LabCore.mqh"'
    return {'overrides': {WRAPPER: _mutate(WRAPPER, keep,
                                           '#include "../core/Evil.mqh"' + chr(10) + keep)}}


def w5_status_rolled_back():
    """The lifecycle field left behind by the artifact. Both rows said `status: DRAFT` while
    their wrappers existed on disk, which is the state this criterion was written from."""
    rows = []
    for line in _disk(grr.HYPOTHESES_REL).split(chr(10)):
        if not line.strip():
            continue
        rec = json.loads(line)
        if rec.get('entity') == 'Hypothesis':
            rec['status'] = 'DRAFT'
        rows.append(json.dumps(rec, sort_keys=True, ensure_ascii=False,
                               separators=(', ', ': ')))
    return {'overrides': {grr.HYPOTHESES_REL: chr(10).join(rows) + chr(10)}}


CASES = (
    ('W2', 'a smuggled include -- logic by reference, which W1 alone only calls drift',
     w2_smuggled_include),
    ('W5', 'a lifecycle field left behind by the artifact it describes', w5_status_rolled_back),
    ('W1', 'a wrapper edited by hand no longer regenerates byte-identically', w1_drift),
    ('W1', 'a registered revision whose wrapper was never generated', w1_absent),
    ('W2', 'a single statement added to a wrapper -- W2 names the RULE, not just the drift',
     w2_logic),
    ('W3', 'the allowlist declares a token the Hypothesis row does not', w3_token_mismatch),
    ('W3', 'a wrapper for a revision no Hypothesis row registers', w3_unregistered),
    ('W4', 'a wrapper that includes no allowlist -- current, and engaging nothing', w4_no_allowlist),
    ('W4', 'two LAB_ENTRY_* build tokens in one wrapper', w4_two_builds),
)


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-1021 generated Thin Wrappers: %d attacks, with the real tree as the '
          'specificity half ===' % len(CASES))

    try:
        clean = run_check()
    except Exception as exc:                                      # noqa: BLE001
        print('  [BAD] the REAL tree could not be checked at all: %s: %s'
              % (type(exc).__name__, str(exc)[:160]))
        return 1
    if clean:
        print('  [BAD] specificity the REAL tree is not clean, so no attack below means anything')
        for p in clean:
            print('        -> %s' % p[:170])
        return 1
    print('  [OK ] specificity the REAL generated tree produces ZERO problems')

    for tag, label, fn in CASES:
        try:
            problems = run_check(**fn())
        except Exception as exc:                                  # noqa: BLE001
            print('  [BAD] %-3s %-56s raised %s: %s'
                  % (tag, label[:56], type(exc).__name__, str(exc)[:80]))
            bad += 1
            continue
        hit = fired(problems, tag)
        ok = bool(hit)
        bad += 0 if ok else 1
        print('  [%s] %-3s attack %s' % ('OK ' if ok else 'BAD', tag, label))
        if ok:
            print('        -> %s' % hit[0][:150])
        else:
            print('        -> NOT CAUGHT BY %s. Reported instead: %s'
                  % (tag, '; '.join(p[:70] for p in problems) or 'nothing at all'))

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, and the real generated tree stayed clean ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
