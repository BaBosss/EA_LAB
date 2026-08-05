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
import preset                                                              # noqa: E402

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


def w6_input_without_guard_pair():
    """An input added to `Inputs.mqh` the way anyone would add one -- a plain `input` line, no
    guard pair. This is the attack that matters most in the whole suite, because NOTHING ELSE SEES
    IT: the allowlist regenerates perfectly (W1 green), it names exactly the right modules (W3
    green), the wrapper is wired (W4 green) -- and the new input can never be compiled away, so it
    sits on every generated wrapper's Inputs page forever no matter what the registry decides
    about it. The rollout's whole mechanism is opt-in per declaration, and an opt-in mechanism
    fails by omission, silently, in the direction of doing nothing."""
    anchor = '#ifndef LAB_CONST__0_Slippage'
    return {'overrides': {preset.INPUTS_REL: _mutate(
        preset.INPUTS_REL, anchor,
        'input int _0_UnguardedProbe = 3;' + chr(10) + anchor)}}


def w7_const_without_value():
    """`#define LAB_CONST_x` with no `LAB_CONSTVAL_x`. The const branch in Inputs.mqh reads
    `= LAB_CONSTVAL_x`, so this is an undefined identifier -- it fails at COMPILE time, loudly,
    which is the good case. The reason it is still caged is that the compiler is not in the fast
    tier: without W7 the first thing that notices is a MetaEditor run somebody has to remember to
    do, and design 5.2's include bug is the precedent for how long that can take."""
    return {'overrides': {ALLOWLIST: _mutate(
        ALLOWLIST, '#define LAB_CONSTVAL__31_SL_Pip 1000' + chr(10), '')}}


def w7_const_for_a_name_nothing_declares():
    """`#define LAB_CONST_NotAnInput`. The dangerous twin of the case above: there is no guard
    pair to switch, so it compiles to NOTHING -- no error, no warning, no effect -- while reading
    in every review as a decision that was applied. Silent-and-inert beats loud-and-broken in
    every way except the one that matters."""
    return {'overrides': {ALLOWLIST: _mutate(
        ALLOWLIST, '#define LAB_CONST_ExitMode',
        '#define LAB_CONST_NotAnInput' + chr(10) + '#define LAB_CONSTVAL_NotAnInput 1'
        + chr(10) + '#define LAB_CONST_ExitMode')}}


def w8_registry_hides_what_the_binary_exposes():
    """A ParameterBinding row moved from OPERATOR to HIDDEN without the const plan changing. The
    registry then says the operator cannot see the dial and the binary still offers it -- and
    before W8 the two halves of the surface had no line of communication at all: the HIDDEN count
    lived in `check_param_surface`, the const count lived in the allowlist header's comment, and
    nothing subtracted one from the other."""
    rows = []
    for line in _disk(grr.BINDINGS_REL).split(chr(10)):
        if not line.strip():
            continue
        rec = json.loads(line)
        if (rec.get('entity') == 'ParameterBinding' and rec.get('hypothesis_revision') == REV
                and rec.get('parameter') == '_14_DistAtrMult'):
            rec['surface'] = 'HIDDEN'
            rows.append(json.dumps(rec, sort_keys=True))
            continue
        rows.append(line)
    return {'overrides': {grr.BINDINGS_REL: chr(10).join(rows) + chr(10)}}


def w9_const_soundness_sweep():
    """ADDED BY THE THIRD AUDIT ROUND, and it is the strongest case in this suite: a BRUTE-FORCE
    soundness sweep of every const decision, not an example-based attack. For every input
    const_plan compiles away whose capability IS in the binary and which is not LOCKED by
    decision, enumerate every combination of values the still-live selectors its gate reads can
    take (enum members, both booleans, {0,1,100} for numerics) and assert the gate stays CLOSED
    under all of them. The input's OWN value is deliberately NOT an axis: const-ing is precisely
    what fixes it, so SELF_GT0-off is off forever -- the audit round first ran this sweep WITH
    the self axis, got 17 hits, and every one was that convention misread as unsoundness (all 17
    are INACTIVE/HIDDEN in the registry; none is advertised TUNABLE, which W8 checks separately).
    A real hit here means a LIVE DIAL WAS COMPILED TO A CONSTANT -- the one failure the whole
    rollout must never produce."""
    import itertools
    import hypothesis_b14 as HB
    import activation
    import capability
    import preset as pr
    surf = pr.parse_surface(_disk(pr.INPUTS_REL), HB.BUILD_TAG)
    TB = activation.TABLE[HB.BUILD_TAG]

    def candidates(sel):
        d = surf.by_name[sel]
        if d.mql_type.startswith('ENUM_') and d.mql_type in surf.enums:
            return list(surf.enums[d.mql_type].keys())
        if d.mql_type == 'bool':
            return ['true', 'false']
        return ['0', '1', '100']

    def sels(g):
        k = g[0]
        if k in ('EQ', 'NE', 'GT0'):
            return [g[1]]
        if k == 'AND':
            out = []
            for s in g[1:]:
                out.extend(sels(s))
            return out
        return []

    unsound = []
    for hyp_id in sorted(HB.HYPOTHESES):
        hyp = HB.HYPOTHESES[hyp_id]
        cfg = grr.pinned_config(hyp, surf)
        plan = gw.const_plan(HB.BUILD_TAG, hyp, surf, cfg)
        tokens = set(capability.enabled_tokens(HB.BUILD_TAG, cfg, surface=surf))
        live = set(plan.live)
        for name in plan.const_values:
            tok, gate = TB[name]
            if tok not in tokens or name in HB.LOCKED_SELECTORS:
                continue
            axes = [(s, candidates(s)) for s in sorted(set(sels(gate))) if s in live]
            if not axes:
                continue
            for combo in itertools.product(*[v for _s, v in axes]):
                probe = dict(cfg)
                for (s, _v), val in zip(axes, combo):
                    probe[s] = val
                if activation._eval(gate, name, probe, surf):
                    unsound.append((hyp_id, name, dict(zip([s for s, _v in axes], combo))))
                    break
    return (not unsound,
            '%d const-ed input(s) whose gate a live selector can OPEN: %r'
            % (len(unsound), unsound[:4]))


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
    ('W6', 'an input added to Inputs.mqh with no guard pair -- the ONLY case in this suite that '
           'every other criterion is blind to', w6_input_without_guard_pair),
    ('W7', 'LAB_CONST_ without its LAB_CONSTVAL_ -- an undefined identifier at compile time',
     w7_const_without_value),
    ('W7', 'LAB_CONST_ for a name nothing declares -- compiles to nothing, reads as applied',
     w7_const_for_a_name_nothing_declares),
    ('W8', 'the registry hides a dial the binary still exposes',
     w8_registry_hides_what_the_binary_exposes),
)

# Not attack-shaped -- a PROPERTY sweep, run after the attacks. Each returns (ok, why).
PROPERTY_CASES = (
    ('W9', 'brute-force: no const-ed gate can be opened by ANY assignment of the live selectors',
     w9_const_soundness_sweep),
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

    for tag, label, fn in PROPERTY_CASES:
        ok, why = fn()
        bad += 0 if ok else 1
        print('  [%s] %-3s property %s' % ('OK ' if ok else 'BAD', tag, label))
        if not ok:
            print('        -> %s' % why)

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, and the real generated tree stayed clean ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
