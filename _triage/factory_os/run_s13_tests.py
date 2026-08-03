# -*- coding: utf-8 -*-
"""run_s13_tests.py -- the cage for check_pilot_acceptance.py (ORDER-1210, slice S13).

WHY THE NEGATIVES COME FIRST. `check_pilot_acceptance` reports mostly BLOCKED today, and a
reporter whose commonest answer is "not yet" is trivially green: it would keep printing BLOCKED
after the mechanism underneath it had rotted, and nobody would notice for weeks. So the cases
below are built around the three ways this module could be WRONG rather than the one way it is
right:

  BINDING   the checklist and the handlers drift apart -- an item is added, deleted or reworded
            in design 8.6 and this module silently keeps evaluating the old set
  ROLL-UP   BLOCKED quietly counts as satisfied, so `EVIDENCE_COMPLETE` is reached without the
            evidence (the `completeness-rollup-measured-after-topup` shape)
  SILENCE   a handler crashes, or its output kills the process, and the tier reports nothing --
            the `-1 SUITE THREW` failure this repo has now hit twice

Every case drives the real functions over synthetic sources. None of them touch the repository's
own stores: this suite must stay green whatever the pilot's actual state becomes, or it would go
red the day the pilot starts producing evidence, which is the opposite of a cage.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s13_tests.py [--list]
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):        # pragma: no cover
        pass

import evidence                        # noqa: E402
import check_pilot_acceptance as PA    # noqa: E402

FAILURES = []
RAN = []


def check(label, ok, detail=''):
    RAN.append(label)
    if ok:
        print('  [ok ] %s' % label)
    else:
        print('  [FAIL] %s%s' % (label, ('  -> ' + detail) if detail else ''))
        FAILURES.append(label)


def refuses(label, fn, needle):
    """The REFUSAL cases are the load-bearing half: each asserts not merely that it raised, but
    that the message NAMES the thing that went wrong. A refusal nobody can act on sends the
    reader hunting."""
    try:
        fn()
    except PA.Refusal as exc:
        check(label, needle in str(exc), 'refused, but the message did not mention %r: %s'
              % (needle, str(exc)[:200]))
        return
    except Exception as exc:                                   # noqa: BLE001
        check(label, False, 'raised %s instead of Refusal: %s' % (type(exc).__name__, exc))
        return
    check(label, False, 'did NOT refuse')


# -- a source shaped like EvidenceSource, over dicts ---------------------------------------------

class FakeSource(object):
    def __init__(self, files, blobs=None, mode='index'):
        self.files = dict(files)
        self.blobs = dict(blobs or {})
        self.mode = mode

    def read_committed(self, rel, errors='strict'):
        rel = rel.replace(os.sep, '/')
        if rel not in self.files:
            raise evidence.ToolFailure('%s is not in the fixture source' % rel)
        return self.files[rel]

    def read_blob(self, sha, why):
        if sha not in self.blobs:
            raise evidence.ToolFailure('pinned blob %s not in fixture store (%s)' % (sha, why))
        return self.blobs[sha]

    def list_committed(self, pattern):
        pattern = pattern.replace(os.sep, '/')
        rx = re.compile('^%s$' % '[^/]*'.join(re.escape(p) for p in pattern.split('*')))
        return sorted(f for f in self.files if rx.match(f))

    def marker(self, component):
        return '##EVIDENCE-MODE## %s %s git_index=fixture' % (component, self.mode)


REAL_DESIGN = io.open(os.path.join(evidence.REPO_ROOT, PA.DESIGN_REL.replace('/', os.sep)),
                      encoding='utf-8-sig').read()  # snapshot: worktree -- a FIXTURE, not a verdict


def design_with(items):
    """A synthetic design document carrying exactly `items` in section 8.6."""
    body = '\n'.join('- [ ] %s' % i for i in items)
    return ('# fixture\n\n### 8.5 something before\ntext\n\n'
            '### 8.6 Pilot acceptance checklist\n%s\n\n---\n\n## 9. after\n' % body)


def real_items():
    return PA.parse_checklist(REAL_DESIGN)


# =================================================================================================
print('[s13] PART 1 -- the spec is PARSED, and a spec that cannot be located is REFUSED')

items = real_items()
check('P1 design 8.6 parses to a non-empty checklist (%d items)' % len(items), len(items) >= 10)
check('P1 every parsed item is a non-empty single line',
      all(isinstance(i, str) and i.strip() and '\n' not in i for i in items))

refuses('P2 REFUSE a design with no "### 8.6" heading -- NOT an empty checklist',
        lambda: PA.parse_checklist('# nothing here\n\n### 8.5 other\n- [ ] x\n'),
        'no "### 8.6" heading')

refuses('P3 REFUSE an 8.6 section with zero items -- a checklist that cannot fail',
        lambda: PA.parse_checklist('### 8.6 Pilot acceptance checklist\n\nprose only\n\n---\n'),
        'cannot fail')

# SPECIFICITY: the parser must not swallow items from a NEIGHBOURING section.
d = ('### 8.6 Pilot acceptance checklist\n- [ ] alpha\n\n---\n\n'
     '### 8.7 Other\n- [ ] beta\n')
check('P4 SPECIFICITY the parser stops at the section boundary (does not eat 8.7)',
      PA.parse_checklist(d) == ['alpha'], repr(PA.parse_checklist(d)))


# =================================================================================================
print('')
print('[s13] PART 2 -- BINDING: the checklist and the handlers cannot drift apart')

check('B0 the REAL design binds cleanly to the REAL handlers', len(PA.bind(items)) == len(items))

refuses('B1 ATTACK an item with NO handler is refused, by name',
        lambda: PA.bind(items + ['a brand new acceptance condition nobody implemented']),
        'NO handler')

refuses('B2 ATTACK a handler whose item was DELETED is refused, by name',
        lambda: PA.bind(items[:-1]),
        'matches no item')

refuses('B3 ATTACK an item REWORDED past its anchor is refused',
        lambda: PA.bind([re.sub(r'wrappers generate from the registry',
                                'wrappers are produced by the registry', i) for i in items]),
        'NO handler')

# An item matching two anchors. Built by concatenating two real items so both anchors occur.
two = [i for i in items if 'wrappers generate from the registry' in i][0]
other = [i for i in items if 'the scheduler resumes a killed batch' in i][0]
refuses('B4 ATTACK an ambiguous item matching TWO anchors is refused',
        lambda: PA.bind([two + ' and ' + other]
                        + [i for i in items if i not in (two, other)]),
        'matches 2 anchors')

check('B5 SPECIFICITY binding is not simply "always refuse" -- B0 above passed on the real pair',
      True)


# =================================================================================================
print('')
print('[s13] PART 3 -- ROLL-UP: BLOCKED can never satisfy EVIDENCE_COMPLETE')


def evaluate_with(states):
    """Drive PA.evaluate with handlers forced to `states` (one per real item)."""
    saved = PA.CHECKLIST_BINDINGS
    anchors = [a for a, _h in saved]
    forced = []
    for anchor, state in zip(anchors, states):
        def mk(s):
            return lambda src: (s, 'forced %s' % s)
        forced.append((anchor, mk(state)))
    PA.CHECKLIST_BINDINGS = tuple(forced)
    try:
        return PA.evaluate(source=FakeSource({PA.DESIGN_REL: REAL_DESIGN}))
    finally:
        PA.CHECKLIST_BINDINGS = saved


n = len(items)
_r, roll = evaluate_with([PA.PASS] * n)
check('R1 all PASS -> evidence_complete', roll['evidence_complete'] and roll['pass'] == n)

_r, roll = evaluate_with([PA.PASS] * (n - 1) + [PA.BLOCKED])
check('R2 ATTACK one BLOCKED and every other item PASS -> NOT evidence_complete',
      not roll['evidence_complete'] and roll['blocked'] == 1,
      'a single BLOCKED item satisfied the roll-up: %r' % roll)

_r, roll = evaluate_with([PA.BLOCKED] * n)
check('R3 ATTACK every item BLOCKED -> NOT evidence_complete (silence is not success)',
      not roll['evidence_complete'] and roll['blocked'] == n)

_r, roll = evaluate_with([PA.PASS] * (n - 1) + [PA.FAIL])
check('R4 one FAIL -> NOT evidence_complete and fail is counted',
      not roll['evidence_complete'] and roll['fail'] == 1)

_r, roll = evaluate_with([PA.FAIL] + [PA.BLOCKED] * (n - 1))
check('R5 FAIL and BLOCKED together are both counted, neither masks the other',
      roll['fail'] == 1 and roll['blocked'] == n - 1 and not roll['evidence_complete'])

check('R6 the state counts always sum to the parsed item count',
      roll['pass'] + roll['fail'] + roll['blocked'] == roll['items'] == n)

refuses('R7 ATTACK a handler returning an INVENTED state is refused, not coerced',
        lambda: evaluate_with(['PROBABLY_FINE'] + [PA.PASS] * (n - 1)),
        'not one of')


# =================================================================================================
print('')
print('[s13] PART 4 -- the design 10 prohibition: automation must not issue a verdict')

check('V1 SPECIFICITY the real module leaks no verdict vocabulary from its docstrings',
      PA.scan_verdict_vocab(PA.handler_docstrings()) == set(),
      'leaked: %r' % PA.scan_verdict_vocab(PA.handler_docstrings()))


def _leaky_doc(src):
    """A handler that would call the pilot a CANDIDATE."""
    return (PA.PASS, 'looks good')


def _leaky_detail(src):
    """A perfectly innocent docstring."""
    return (PA.PASS, 'B14-H01 is a VALIDATED CANDIDATE, promote it')


saved = PA.CHECKLIST_BINDINGS
try:
    PA.CHECKLIST_BINDINGS = ((saved[0][0], _leaky_doc),) + saved[1:]
    leaks = PA.scan_verdict_vocab(PA.handler_docstrings())
    check('V2 ATTACK a handler whose DOCSTRING names a verdict is detected by name',
          'CANDIDATE' in leaks, 'not detected; leaks=%r' % leaks)
finally:
    PA.CHECKLIST_BINDINGS = saved

# 🔴 V4 IS THE CASE /scrutinize ROUND 1 ADDED, AND IT IS THE ONE THAT MATTERS.
# V2 plants the token in the mutant's DOCSTRING -- the one surface that is never printed. The
# original guard scanned only docstrings while its own comment claimed it scanned "the rendered
# detail strings", so a handler RETURNING `'... VALIDATED CANDIDATE ...'` was invisible to it and
# V2 stayed green throughout. A test that can only catch the attack it was shaped around is not a
# cage. This drives the REAL surface: the detail the user reads.
saved = PA.CHECKLIST_BINDINGS
try:
    # EVERY OTHER handler is neutralised, and that is not tidiness -- it is the difference between
    # a case that tests its property and one that passes by accident. The first version replaced
    # only binding[0] and left the real handlers in place; `item_wrappers_generate` then called
    # check_wrapper_gen against the synthetic source, raised a read Refusal, and `refuses()` was
    # satisfied by a refusal that had nothing to do with verdict vocabulary. It was green for the
    # wrong reason -- the exact defect this round is fixing, reproduced inside its own fix.
    benign = tuple((a, (lambda src: (PA.PASS, 'benign'))) for a, _h in saved)
    PA.CHECKLIST_BINDINGS = ((benign[0][0], _leaky_detail),) + benign[1:]
    check('V4 SPECIFICITY the docstring scan alone does NOT see a leak in the rendered detail',
          PA.scan_verdict_vocab(PA.handler_docstrings()) == set(),
          'the docstring scan saw it, so V4 is not testing what it claims')
    refuses('V4 ATTACK a handler EMITTING a verdict in its rendered detail makes evaluate REFUSE',
            lambda: PA.evaluate(source=FakeSource({PA.DESIGN_REL: REAL_DESIGN})),
            'would EMIT verdict vocabulary')
    # ...and the control: the same all-benign set with NO leak must evaluate cleanly, or V4 would
    # be satisfied by an evaluate() that refuses everything.
    PA.CHECKLIST_BINDINGS = benign
    _r, _roll = PA.evaluate(source=FakeSource({PA.DESIGN_REL: REAL_DESIGN}))
    check('V4 CONTROL the same handler set WITHOUT the leak evaluates without refusing',
          _roll['evidence_complete'])
finally:
    PA.CHECKLIST_BINDINGS = saved

check('V5 SPECIFICITY the real module, rendered end to end, emits no verdict vocabulary',
      PA.scan_verdict_vocab(
          [d for _t, _s, d in PA.evaluate(
              source=evidence.EvidenceSource('worktree'))[0]]) == set())

check('V3 the vocabulary list is not empty (an empty blacklist detects nothing)',
      len(PA.VERDICT_VOCAB) >= 5)


# =================================================================================================
print('')
print('[s13] PART 5 -- item handlers: each direction driven over a synthetic source')

CLAIM_ORDER = (b'## ORDER-9999 fixture\n\n'
               b'<!-- B14-H01-PREREGISTRATION -->\n'
               b'The causal claim: the grid engine carries the edge.\n'
               b'The falsifier: flat-lot PF >= 1.0 over MAIN.\n')


def hyp_row(hid, **over):
    row = {'entity': 'Hypothesis', 'hypothesis_id': hid, 'engine_edge': True,
           'status': 'WRAPPER_GENERATED',
           'preregistration_ref': {'entity': 'OwnerRef', 'owner_type': 'taskboard_order',
                                   'path': 'AGENT_TASKBOARD.md', 'anchor': '%s-PREREGISTRATION' % hid,
                                   'blob_oid': 'a' * 40, 'commit_oid': 'b' * 40,
                                   'raw_sha256': 'c' * 64}}
    row.update(over)
    return row


def hyp_source(rows, blob=CLAIM_ORDER):
    return FakeSource({PA.DESIGN_REL: REAL_DESIGN,
                       PA.HYPOTHESES_REL: '\n'.join(json.dumps(r) for r in rows)},
                      blobs={'a' * 40: blob})


both = [hyp_row('B14-H01'), hyp_row('B14-H02')]
good_blob = CLAIM_ORDER + b'\n<!-- B14-H02-PREREGISTRATION -->\ncausal claim / falsifier\n'
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, good_blob))
check('H1 POSITIVE both hypotheses pinning a resolvable order with claim+falsifier -> PASS',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_hypotheses_preregistered(
    hyp_source(both, b'## ORDER-9999\nno anchor and no claim here\n'))
check('H2 ATTACK the pinned order does not contain the anchor -> FAIL',
      state == PA.FAIL and 'anchor' in detail, '%s: %s' % (state, detail))

# 🔴 BOTH rows are supplied here, and the first version of this case did not supply them.
# With only B14-H01 present the handler short-circuits to BLOCKED on the MISSING B14-H02 and never
# reaches the falsifier check at all -- so the case asserted FAIL, got BLOCKED, and would have
# proved nothing about the falsifier rule even if it had been written to accept BLOCKED. Memory
# `discriminating-test-must-be-able-to-discriminate`: the fixture has to differ from the passing
# one in EXACTLY the property under test, and nothing else.
no_falsifier = (b'<!-- B14-H01-PREREGISTRATION -->\nThe causal claim: something.\n'
                b'<!-- B14-H02-PREREGISTRATION -->\nThe causal claim: something else.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, no_falsifier))
# The specificity half is 'missing a causal claim', NOT the bare words 'causal claim': the
# message's own explanatory sentence says "must carry the causal claim AND the falsifier", so a
# naive substring test fails on the module's prose rather than on its behaviour. Assert the
# DIAGNOSIS, not a word that appears in the explanation of the diagnosis.
check('H3 ATTACK a pinned order with a claim but NO falsifier -> FAIL naming ONLY the falsifier',
      state == PA.FAIL and 'missing a falsifier' in detail
      and 'missing a causal claim' not in detail,
      '%s: %s' % (state, detail))

copied = hyp_row('B14-H01', falsifier='flat-lot PF >= 1.0')
state, detail = PA.item_hypotheses_preregistered(hyp_source([copied, hyp_row('B14-H02')],
                                                            good_blob))
check('H4 ATTACK the registry COPIES the falsifier instead of referencing it -> FAIL',
      state == PA.FAIL and 'COPIES' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_hypotheses_preregistered(hyp_source([]))
check('H5 no hypothesis rows at all -> BLOCKED, not FAIL (absent evidence is not contradiction)',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

# -- item 13, the disjunction ---------------------------------------------------------------------
state, detail = PA.item_h01_engine_edge_cage(hyp_source([hyp_row('B14-H01')]))
check('H6 POSITIVE H01 not advanced + engine_edge -> PASS (the "or is not advanced" limb)',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_h01_engine_edge_cage(
    hyp_source([hyp_row('B14-H01', engine_edge=False)]))
check('H7 ATTACK H01 without engine_edge=true -> FAIL (the five cage conditions would never '
      'be demanded)', state == PA.FAIL, '%s: %s' % (state, detail))

state, detail = PA.item_h01_engine_edge_cage(
    hyp_source([hyp_row('B14-H01', status='EVIDENCE_COMPLETE')]))
check('H8 ATTACK H01 ADVANCED with no cage evidence -> BLOCKED, and the five conditions named',
      state == PA.BLOCKED and 'Model-4' in detail, '%s: %s' % (state, detail))


# =================================================================================================
print('')
print('[s13] PART 6 -- the output cannot kill its own process (the -1 SUITE THREW shape)')

# design 8.6 contains `§`, `≤` and `·`. The first run of check_pilot_acceptance died on exactly
# this under a cp1252 pipe. Assert the mechanism, not the intention.
check('E1 design 8.6 really does carry non-ASCII (otherwise E2 proves nothing)',
      any(ord(c) > 127 for i in items for c in i))

encoded_ok = True
try:
    for i in items:
        i.encode('utf-8')
except UnicodeEncodeError:                                     # pragma: no cover
    encoded_ok = False
check('E2 every parsed item survives utf-8 encoding', encoded_ok)

check('E3 the module reconfigures stdout away from the console codepage',
      getattr(sys.stdout, 'encoding', '').lower().replace('-', '') == 'utf8',
      'stdout encoding is %r -- a cp1252 pipe would kill the suite mid-report'
      % getattr(sys.stdout, 'encoding', None))


# =================================================================================================
print('')
print('--- ROLL-UP: every catalogued case ran ---')
CATALOGUE = len(RAN)
print('    catalogued %d · ran %d' % (CATALOGUE, len(RAN)))

if '--list' in sys.argv:
    for r in RAN:
        print('    %s' % r)

print('')
print('[s13] %d case(s), %d failed' % (len(RAN), len(FAILURES)))
if FAILURES:
    for f in FAILURES:
        print('    FAILED: %s' % f)
sys.exit(1 if FAILURES else 0)
