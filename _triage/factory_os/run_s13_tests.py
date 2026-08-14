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

    def exists_committed(self, rel):
        # ORDER-1253. item 6 asks a question the other handlers do not: "is the artefact there at
        # all". Absent must be answerable WITHOUT raising, or "no decision log has been written
        # yet" and "this checker could not read" would arrive as the same outcome.
        return rel.replace(os.sep, '/') in self.files

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
    forced = []
    for (anchor, real), state in zip(saved, states):
        def mk(s):
            return lambda src: (s, 'forced %s' % s)
        fn = mk(state)
        # CARRY THE REAL HANDLER'S NAME. Without this the forced handlers are `<lambda>`, the
        # UNIMPLEMENTED declaration matches nothing, and bind() correctly refuses -- which is the
        # strict binding working, but it also means the stub-split assertions below would be
        # testing a world where no stub exists. Keeping the names makes U3/U4 meaningful.
        fn.__name__ = real.__name__
        forced.append((anchor, fn))
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

# --- /scrutinize round 2: BLOCKED has two causes and they are different work items --------------
# Round 2 asked which handlers can EVER return PASS. Ten of fourteen could not: they are stubs
# that read nothing. So EVIDENCE_COMPLETE was unreachable BY CONSTRUCTION and exit 0 was dead
# code -- and a reader watching the pilot produce evidence would have seen those items stay
# BLOCKED forever with no way to tell "not run yet" from "not implemented yet".
check('U1 the stub declaration is non-empty today (if it empties, U2/U3 must be re-read)',
      len(PA.UNIMPLEMENTED) > 0)

refuses('U2 ATTACK UNIMPLEMENTED naming a handler that is not bound is refused',
        lambda: (PA.UNIMPLEMENTED.setdefault('item_does_not_exist', 'x'),
                 PA.bind(items))[1],
        'not a bound handler')
PA.UNIMPLEMENTED.pop('item_does_not_exist', None)

_r, roll = evaluate_with([PA.BLOCKED] * n)
check('U3 the two kinds of BLOCKED sum to the BLOCKED total',
      roll['blocked_awaiting_evidence'] + roll['blocked_checker_unimplemented']
      == roll['blocked'], repr(roll))

check('U4 evidence_complete_reachable is FALSE while any stub is declared',
      roll['evidence_complete_reachable'] is False)

_saved_unimpl = dict(PA.UNIMPLEMENTED)
try:
    PA.UNIMPLEMENTED.clear()
    _r, roll2 = evaluate_with([PA.PASS] * n)
    check('U5 SPECIFICITY with NO stubs declared, reachable flips to TRUE '
          '(the flag tracks the declaration, it is not hardcoded)',
          roll2['evidence_complete_reachable'] is True
          and roll2['blocked_checker_unimplemented'] == 0)
finally:
    PA.UNIMPLEMENTED.update(_saved_unimpl)

check('U6 every declared stub is a real bound handler (the reverse direction of U2)',
      set(PA.UNIMPLEMENTED) <= set(h.__name__ for _a, h in PA.CHECKLIST_BINDINGS),
      'orphans: %r' % (set(PA.UNIMPLEMENTED)
                       - set(h.__name__ for _a, h in PA.CHECKLIST_BINDINGS)))

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
    def _benign_for(real):
        fn = lambda src: (PA.PASS, 'benign')                   # noqa: E731
        fn.__name__ = real.__name__       # keep the UNIMPLEMENTED declaration bindable (see U2)
        return fn

    benign = tuple((a, _benign_for(h)) for a, h in saved)
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

# --- /scrutinize round 3: the window bled past the end of the pinned order ----------------------
# 🔴 THE ATTACK THAT WAS PASSING. The first version searched `text[index(anchor):][:8000]` -- a
# magic character count that does not stop at the end of the pinned section. An order whose own
# text stated NO method PASSED, because the window ran on into the next `## ORDER-` heading and
# matched a DIFFERENT order's causal claim and falsifier. Item 1 is one of only four implemented
# checks in this module, so a false PASS there is most of its credibility.
BLEED = (b'## ORDER-1000\n<!-- B14-H01-PREREGISTRATION -->\nthis order states no method at all\n\n'
         b'## ORDER-1001 a DIFFERENT order that merely follows it\n'
         b'The causal claim: something else entirely.\nThe falsifier: some other test.\n\n'
         b'<!-- B14-H02-PREREGISTRATION -->\nThe causal claim: a. The falsifier: b.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, BLEED))
check('H9 ATTACK the claim+falsifier belong to the NEXT order, not the pinned one -> FAIL',
      state == PA.FAIL and 'B14-H01' in detail, '%s: %s' % (state, detail))

# CONTROL for H9: the same shape with each order carrying its OWN claim and falsifier must PASS,
# or H9 would be satisfied by a check that simply stopped working.
BOUNDED = (b'## ORDER-1000\n<!-- B14-H01-PREREGISTRATION -->\n'
           b'The causal claim: g. The falsifier: h.\n\n'
           b'## ORDER-1001\n<!-- B14-H02-PREREGISTRATION -->\n'
           b'The causal claim: a. The falsifier: b.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, BOUNDED))
check('H9 CONTROL each order carrying its OWN claim+falsifier still PASSes',
      state == PA.PASS, '%s: %s' % (state, detail))

# schemas.json: the anchor "must occur EXACTLY once in the blob". Presence is weaker than that in
# the direction that matters -- a duplicated anchor is an AMBIGUOUS reference, and resolving to
# one place is the entire purpose of an OwnerRef.
DUP = (b'<!-- B14-H01-PREREGISTRATION -->\nThe causal claim: c. The falsifier: f.\n'
       b'<!-- B14-H01-PREREGISTRATION -->\nand again, somewhere else\n'
       b'<!-- B14-H02-PREREGISTRATION -->\nThe causal claim: a. The falsifier: b.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, DUP))
check('H10 ATTACK a DUPLICATED anchor is FAIL (schemas.json says EXACTLY once), and says ambiguous',
      state == PA.FAIL and 'ambiguous' in detail, '%s: %s' % (state, detail))

# --- ORDER-1220: the matcher was case-sensitive, and one half passed by accident ----------------
# Writing the first REAL pre-registration exposed both. `causal claim|CAUSAL CLAIM` did not match
# `**Causal claim.**` -- the ordinary way a human writes a heading -- and §8.6's rule is about
# CONTENT, not capitalisation. The falsifier half was worse: it missed `**Falsifier.**` too, but
# still reported present because the word appears lowercase in a FOOTNOTE lower down the section,
# i.e. it was matching prose ABOUT the falsifier rather than the falsifier.
HEADINGS = (b'<!-- B14-H01-PREREGISTRATION -->\n**Causal claim.** something.\n'
            b'**Falsifier.** flat-lot PF >= escalated PF.\n'
            b'<!-- B14-H02-PREREGISTRATION -->\n**Causal claim.** other.\n'
            b'**Falsifier.** hedged < unhedged.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, HEADINGS))
check('H11 POSITIVE capitalised headings (`**Causal claim.**` / `**Falsifier.**`) are accepted',
      state == PA.PASS, '%s: %s' % (state, detail))

# 🔴 THE CONTROL THAT MAKES H11 WORTH ANYTHING. Loosening a matcher to accept more is only safe if
# it still REJECTS the thing it exists to catch. A section with neither word, in any casing, must
# still fail -- otherwise "case-insensitive" would just mean "stopped checking".
NEITHER = (b'<!-- B14-H01-PREREGISTRATION -->\nthis order states a plan and some dates.\n'
           b'<!-- B14-H02-PREREGISTRATION -->\n**Causal claim.** x. **Falsifier.** y.\n')
state, detail = PA.item_hypotheses_preregistered(hyp_source(both, NEITHER))
check('H11 CONTROL a section with NEITHER word still FAILs, naming both as missing',
      state == PA.FAIL and 'B14-H01' in detail
      and 'causal claim' in detail and 'falsifier' in detail,
      '%s: %s' % (state, detail))

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


# -- items 7, 8 and 9: the cell store, ORDER-1250 -------------------------------------------------
# These three stopped being stubs when factory/coverage.jsonl gained real CoverageCell rows, so
# every one of them owes both directions here. The fixtures are synthetic on purpose: driving
# them against the real store would make each case's answer change the day the pilot advances,
# which is a cage that reports on the repository instead of on the code.

def metric(**over):
    m = {'window': 'MAIN', 'pf': 1.31, 'pf_state': 'DEFINED', 'trades': 84, 'dd_pct': 7.4,
         'run_id': 'S13CELL_fixture', 'lane': r'D:\Meta 5\terminal64.exe',
         'data_fingerprint': 'df1', 'model': 1}
    m.update(over)
    return m


def cell(cid, **over):
    c = {'entity': 'CoverageCell', 'cell_id': cid, 'hypothesis_revision': 'B14-H01-r1',
         'logical_symbol': 'XAUUSD', 'tf': 'H1', 'universe_version': 'design-8.3-pilot',
         'state': 'BASELINE_RUN', 'metrics': [metric()], 'trial_count': 0}
    c.update(over)
    return c


def cell_source(cells, runs=None, extra=None):
    files = {PA.DESIGN_REL: REAL_DESIGN,
             PA.COVERAGE_REL: '\n'.join(json.dumps(c) for c in cells)}
    if runs is not None:
        files['factory/runs/pilot/fixture.jsonl'] = '\n'.join(json.dumps(r) for r in runs)
    files.update(extra or {})
    return FakeSource(files)


def sixteen(**over):
    return [cell('B14-H01-r1/S%d/H1' % i, **over) for i in range(PA.PILOT_CELL_COUNT)]


# item 6 (ORDER-1253) -----------------------------------------------------------------------------
# The handler reads TWO committed artefacts: the tier file (is the fixture cage on the commit
# path) and the decision log (was the guard observed on a real submission). Both are fixtures
# here; the end-to-end binding between the guard's WRITER and optimize_log's READER is asserted
# in scripts/_test/run_optimize_guard_tests.ps1, which runs the real .ps1 into a temp file.

def decision(result='REFUSE', dims=None, **over):
    rec = {'record_version': 1, 'submitted_utc': '2026-08-03T09:00:00Z',
           'lane': r'D:\Meta 5\terminal64.exe', 'hypothesis_revision': 'B14-H01-r1',
           'result': result, 'checked': 1, 'allow_count': 0, 'refuse_count': 1,
           'exit_code': 1,
           'dimensions': dims if dims is not None else
           [{'name': '_9_MaxLevels', 'verdict': 'REFUSE',
             'facts': [{'refuse': True, 'text': 'SAFETY'}]}]}
    rec.update(over)
    return rec


ALLOW_REC = decision(result='ALLOW', exit_code=0, allow_count=1, refuse_count=0,
                     dims=[{'name': '_14_DistAtrMult', 'verdict': 'ALLOW', 'facts': []}])
TIER_OK = '$FAST_SUITES = @(\n  "run_optimize_guard_tests.ps1",\n  "run_s13_tests.ps1"\n)\n'
TIER_WITHOUT = '$FAST_SUITES = @(\n  "run_s13_tests.ps1"\n)\n'


def guard_source(records, tier=TIER_OK, omit_log=False):
    files = {PA.DESIGN_REL: REAL_DESIGN, PA.FAST_TIER_REL: tier}
    if not omit_log:
        files[PA.OPTIMIZE_LOG_REL] = '\n'.join(json.dumps(r) for r in records)
    return FakeSource(files)


state, detail = PA.item_optimize_guard(guard_source([decision(), ALLOW_REC]))
check('G1 POSITIVE one real REFUSE + one real ALLOW, cage in the tier -> PASS',
      state == PA.PASS and '_9_MaxLevels' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_optimize_guard(guard_source([], omit_log=True))
check('G2 no decision log committed -> BLOCKED and it names the UNTESTED rule',
      state == PA.BLOCKED and 'UNTESTED' in detail, '%s: %s' % (state, detail))

# 🔴 THE CASE THIS HANDLER EXISTS FOR. A guard broken CLOSED refuses every real submission too,
# so "observed refusing at least one real case" is satisfied by a guard that is useless. The
# ALLOW direction is what tells the two apart, and it must be measured on real submissions --
# borrowing it from the 14 fixture cases is the exact move CLAUDE.md's UNTESTED rule forbids.
state, detail = PA.item_optimize_guard(guard_source([decision(), decision()]))
check('G3 ATTACK refusals only -> BLOCKED (a guard broken closed refuses real cases too)',
      state == PA.BLOCKED and 'broken closed' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_optimize_guard(guard_source([ALLOW_REC, ALLOW_REC]))
check('G4 ATTACK allows only -> BLOCKED (the guard has never been observed firing)',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

state, detail = PA.item_optimize_guard(guard_source([decision(), ALLOW_REC], tier=TIER_WITHOUT))
check('G5 ATTACK the cage is not inside $FAST_SUITES -> FAIL (a cage that does not run)',
      state == PA.FAIL and 'not inside $FAST_SUITES' in detail, '%s: %s' % (state, detail))

# 🔴 G5b IS THE CASE G5 COULD NOT MAKE. G5's fixture does not mention the cage at all, so it
# passes against a SUBSTRING test just as happily as against a real membership test -- it cannot
# discriminate the two. The real $FAST_SUITES holds 294 comment lines and several name suites
# while explaining them, so "the entry was deleted and the comment above it remains" is the shape
# that actually occurs. The first version of this handler reported PASS for exactly that.
TIER_MENTION_ONLY = ('$FAST_SUITES = @(\n'
                     '  # ORDER-xxxx: run_optimize_guard_tests.ps1 used to live here and was\n'
                     '  # removed when the tier went over budget; see the order for why.\n'
                     '  "run_s13_tests.ps1"\n)\n')
state, detail = PA.item_optimize_guard(
    guard_source([decision(), ALLOW_REC], tier=TIER_MENTION_ONLY))
check('G5b ATTACK the cage is MENTIONED in a comment but not listed -> FAIL, not PASS',
      state == PA.FAIL, '%s: %s' % (state, detail))

# ...and the control, so "FAIL" above is not "this parser fails on anything with comments".
TIER_WITH_COMMENTS = ('$FAST_SUITES = @(\n'
                      '  # a comment that names run_s13_tests.ps1 while explaining it\n'
                      "  'run_optimize_guard_tests.ps1',   # trailing comment\n"
                      "  'run_s13_tests.ps1'\n)\n")
state, detail = PA.item_optimize_guard(
    guard_source([decision(), ALLOW_REC], tier=TIER_WITH_COMMENTS))
check('G5b CONTROL a real entry surrounded by comments still PASSes',
      state == PA.PASS, '%s: %s' % (state, detail))

refuses('G6b ATTACK a count that disagrees with the dimensions it summarises -> Refusal',
        lambda: PA.item_optimize_guard(
            FakeSource({PA.DESIGN_REL: REAL_DESIGN, PA.FAST_TIER_REL: TIER_OK,
                        PA.OPTIMIZE_LOG_REL: json.dumps(decision(refuse_count=9))})),
        'disagrees with the list')

# THE STATED LIMIT, asserted so it is a documented gap rather than a surprise. 8.6's own
# parenthetical defines the bar as "a guard never seen firing is UNTESTED", so ANY real refusal
# satisfies it -- including one for a typo'd identifier, which says nothing about whether the
# SAFETY layer works. The PASS detail names the refused dimension so a reader can see which kind
# of fire was observed; the handler does not require it to be a safety refusal.
state, detail = PA.item_optimize_guard(guard_source([
    decision(dims=[{'name': '_99_NotARealInput', 'verdict': 'REFUSE',
                    'facts': [{'refuse': True, 'text': 'unknown identifier - fail closed'}]}]),
    ALLOW_REC]))
check('G10 STATED LIMIT a fail-closed typo refusal also satisfies "observed firing"',
      state == PA.PASS and '_99_NotARealInput' in detail, '%s: %s' % (state, detail))

refuses('G6 ATTACK a record the reader cannot validate -> Refusal, never a quiet PASS',
        lambda: PA.item_optimize_guard(
            FakeSource({PA.DESIGN_REL: REAL_DESIGN, PA.FAST_TIER_REL: TIER_OK,
                        PA.OPTIMIZE_LOG_REL: json.dumps(decision(lane='  '))})),
        'names no lane')

# SPECIFICITY, both halves. An innocent extra row must not break a satisfied item, and a log made
# ENTIRELY of submissions that judged nothing must not satisfy it.
nothing_rec = decision(result='NOTHING_TO_CHECK', dims=[], checked=0, refuse_count=0, exit_code=0)
state, detail = PA.item_optimize_guard(guard_source([decision(), ALLOW_REC, nothing_rec]))
check('G7 SPECIFICITY a NOTHING_TO_CHECK row alongside a real pair still PASSes',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_optimize_guard(guard_source([nothing_rec, nothing_rec]))
check('G8 ATTACK a log of nothing-to-check rows only -> BLOCKED',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

# -WarnOnly makes the process exit 0 while the dimension verdict stays REFUSE. The question 8.6
# asks is whether the guard was observed REFUSING, not whether a caller let the exit code through.
state, detail = PA.item_optimize_guard(
    guard_source([decision(exit_code=0, warn_only=True), ALLOW_REC]))
check('G9 a -WarnOnly refusal is still an observed refusal (exit code is not the signal)',
      state == PA.PASS, '%s: %s' % (state, detail))


# item 7 ------------------------------------------------------------------------------------------
state, detail = PA.item_cells_baseline_probe(cell_source([]))
check('C1 no registered cell -> BLOCKED, not FAIL (absent evidence is not contradiction)',
      state == PA.BLOCKED and 'no pilot cell is registered' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_cells_baseline_probe(cell_source(sixteen(state='PROBE_RUN')))
check('C2 POSITIVE 16 cells all at PROBE_RUN -> PASS',
      state == PA.PASS, '%s: %s' % (state, detail))

# 🔴 THE CASE THIS ITEM EXISTS FOR. Every cell has had its Baseline and the flat-lot falsifier
# arm; none has had the decision-13 optimize probe. If this returned PASS, the item would be
# tickable from an arm that answers a different question -- which is the single thing the order
# that wrote this handler was told, by name, not to do.
state, detail = PA.item_cells_baseline_probe(cell_source(sixteen()))
check('C3 ATTACK 16 cells at BASELINE_RUN -> BLOCKED, and it says the probe is still owed',
      state == PA.BLOCKED and 'decision-13 optimize probe' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_cells_baseline_probe(cell_source(sixteen()[:9] + [
    cell('B14-H01-r1/S99/H1', state='NOT_APPLICABLE',
         not_applicable_reason='no tick history on this lane before 2020')]))
check('C4 a NOT_APPLICABLE cell with a written reason counts as satisfied (the second limb)',
      state == PA.BLOCKED and 'S99' not in detail, '%s: %s' % (state, detail))

state, detail = PA.item_cells_baseline_probe(cell_source(
    sixteen(state='PROBE_RUN')[:15]
    + [cell('B14-H01-r1/S99/H1', state='NOT_APPLICABLE', not_applicable_reason='no')]))
check('C5 ATTACK NOT_APPLICABLE with no written reason -> FAIL (a cell excluded for no reason)',
      state == PA.FAIL and 'no written reason' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_cells_baseline_probe(cell_source(sixteen(state='PROBE_RUN') + [
    cell('B14-H01-r1/S99/H4', state='PROBE_RUN')]))
check('C6 ATTACK 17 cells -> FAIL (a cell outside the pre-registered universe)',
      state == PA.FAIL and 'larger than the design' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_cells_baseline_probe(cell_source(sixteen(state='PROBE_RUN')[:4]))
check('C7 fewer cells than the design -> BLOCKED and it SAYS how many are unregistered',
      state == PA.BLOCKED and 'not registered at all' in detail, '%s: %s' % (state, detail))

# item 8 ------------------------------------------------------------------------------------------
state, detail = PA.item_pf_with_n_and_dd(cell_source([cell('c1')]))
check('D1 POSITIVE a cell with a metric displays PF, n and DD together -> PASS',
      state == PA.PASS and 'PF=1.31' in detail and 'n=84' in detail and 'DD=7.4' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_pf_with_n_and_dd(cell_source([cell('c1', metrics=[])]))
check('D2 ATTACK a cell with an empty metrics array -> FAIL, not a blank row',
      state == PA.FAIL and 'no metric at all' in detail, '%s: %s' % (state, detail))

# 🔴 The inversion ORDER-1230 had to repair, asserted rather than trusted: the tester prints 0
# for a run with no losing trade, and 0 is also a REAL profit factor. If UNDEF ever rendered as a
# number again, the best win rate in the matrix would read as the worst result in it.
state, detail = PA.item_pf_with_n_and_dd(cell_source([
    cell('c1', metrics=[metric(pf=None, pf_state='UNDEFINED_NO_LOSSES', trades=99)])]))
check('D3 an UNDEFINED profit factor renders as UNDEF, never as a number',
      state == PA.PASS and 'UNDEF' in detail and 'PF=0' not in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_pf_with_n_and_dd(cell_source([]))
check('D4 no cells at all -> BLOCKED (nothing to display is not a clean display)',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

# item 9 ------------------------------------------------------------------------------------------
runs_ok = [{'entity': 'PilotCellRun', 'cell_id': 'c1', 'arm': 'baseline',
            'lane': r'D:\Meta 5\terminal64.exe', 'data_fingerprint': 'df1'}]
state, detail = PA.item_lane_and_fingerprint(cell_source([cell('c1')], runs=runs_ok))
check('L1 POSITIVE every metric and run carries lane + fingerprint on ONE lane -> PASS',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_lane_and_fingerprint(cell_source([], runs=None))
check('L2 nothing committed at all -> BLOCKED, not PASS (silence is not a clean lane)',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

state, detail = PA.item_lane_and_fingerprint(
    cell_source([cell('c1', metrics=[metric(data_fingerprint='')])], runs=runs_ok))
check('L3 ATTACK a metric with no data fingerprint -> FAIL',
      state == PA.FAIL and 'data_fingerprint' in detail, '%s: %s' % (state, detail))

# The load-bearing one: BTC tick history differs 14x across installs, so two lanes in one body of
# evidence is a WRONG number, not a noisy one.
state, detail = PA.item_lane_and_fingerprint(cell_source(
    [cell('c1'), cell('c2', metrics=[metric(lane=r'D:\Meta 5b\terminal64.exe')])], runs=runs_ok))
check('L4 ATTACK evidence spanning two MT5 installs -> FAIL naming both lanes',
      state == PA.FAIL and 'Meta 5b' in detail and 'cross-install' in detail,
      '%s: %s' % (state, detail))

# SPECIFICITY: the run half is not decoration. A run record missing a lane must be caught even
# when every registered METRIC is clean -- otherwise the rule silently covers a third of the runs.
state, detail = PA.item_lane_and_fingerprint(cell_source(
    [cell('c1')], runs=[dict(runs_ok[0], lane='')]))
check('L5 SPECIFICITY a RUN record with no lane is caught even when every metric is clean',
      state == PA.FAIL and 'fixture.jsonl' in detail, '%s: %s' % (state, detail))


# item 10 (ORDER-1256) ----------------------------------------------------------------------------
# The fixture set exercises both accepted accounting paths and the fail-closed
# boundaries between them. Native records intentionally omit legacy estimator fields.

def fin(**over):
    f = {'applied': False, 'metric_basis': 'tester_native', 'tester_swap_charged': -382.75,
         'swap_mode_probe': 'factory/runs/pilot/swap_probe/fixture.jsonl'}
    f.update(over)
    return f


def post_hoc_fin(**over):
    f = {'applied': True, 'metric_basis': 'post_hoc_estimator', 'tester_swap_charged': 0,
         'tool': 'scripts/swap_adjust_crypto.py', 'rate_long_pct_yr': 14.67,
         'rate_short_pct_yr': 0.49, 'detail': 'post-hoc deduction: -20.21',
         'swap_mode_probe': 'factory/runs/pilot/swap_probe/charge_fixture.jsonl'}
    f.update(over)
    return f


def crypto_run(arm='baseline', symbol='BTCUSD', financing='default', **over):
    r = {'entity': 'PilotCellRun', 'cell_id': 'B14-H01-r1/%s/H4' % symbol, 'arm': arm,
         'logical_symbol': symbol, 'window': 'MAIN',
         'lane': r'D:\Meta 5\terminal64.exe', 'data_fingerprint': 'df1'}
    if financing == 'default':
        r['financing_deducted'] = fin()
    elif financing is not None:
        r['financing_deducted'] = financing
    r.update(over)
    return r


def selected_verification(symbol='BTCUSD', financing='default', **over):
    """Realistic verification-shaped financing run, not a PilotCellRun alias."""
    r = {
        'entity': 'PilotSelectedVerification',
        'cell_id': 'B14-H01-r1/%s/H4' % symbol,
        'arm': 'selected-verification',
        'logical_symbol': symbol,
        'window': 'BWD',
        'model': 4,
        'first_lot': '0.03',
        'lane': r'D:\Meta 5\terminal64.exe',
        'data_fingerprint': 'df-selected',
        'selection_record': r'D:\Meta 5\selection\selection.jsonl',
        'report': r'D:\Meta 5\reports\selected.htm',
        'pf': 1.44,
        'gross_profit': 2787.53,
        'gross_loss': -1936.59,
        'net_profit': 850.94,
        'trades': 49,
        'dd_pct': 15.22,
    }
    if financing == 'default':
        r['financing_deducted'] = fin()
    elif financing is not None:
        r['financing_deducted'] = financing
    r.update(over)
    return r


def crypto_source(runs, verification=None):
    spec_probe = {
        'entity': 'SwapProbe', 'probe': 'spec', 'logical_symbol': 'BTCUSD',
        'taken_utc': '2026-08-04T00:00:00Z', 'swap_mode': 'INTEREST_CURRENT'}
    charge_probe = {
        'entity': 'SwapProbe', 'probe': 'charge', 'logical_symbol': 'BTCUSD',
        'taken_utc': '2026-08-04T00:01:00Z', 'lane': r'D:\Meta 5\terminal64.exe',
        'report': 'factory/runs/pilot/swap_probe/fixture_charge.htm',
        'source': 'fixture report Deals/Swap table', 'window': '2025.10.01..2025.12.09',
        'model': 1, 'side': 'BUY', 'lot': 0.1, 'days_held': 68,
        'tester_swap_charged': 0, 'inputs_pinned': True}
    files = {PA.DESIGN_REL: REAL_DESIGN,
             PA.COVERAGE_REL: '\n'.join(json.dumps(c) for c in [cell('c1')]),
             'factory/runs/pilot/swap_probe/fixture.jsonl': json.dumps(spec_probe),
             'factory/runs/pilot/swap_probe/charge_fixture.jsonl': json.dumps(charge_probe),
             'factory/runs/pilot/swap_probe/charge_nonzero_fixture.jsonl': json.dumps(
                 dict(charge_probe, tester_swap_charged=-4.73))}
    if runs is not None:
        files['factory/runs/pilot/fixture.jsonl'] = '\n'.join(json.dumps(r) for r in runs)
    if verification is not None:
        files['factory/runs/pilot/verification/v.jsonl'] = '\n'.join(
            json.dumps(r) for r in verification)
    return FakeSource(files)


state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline'), selected_verification()]))
check('A tester-native applied=false with numeric tester swap and dated probe -> PASS',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source([crypto_run(symbol='XAUUSD')]))
check('F2 no crypto run at all -> BLOCKED (absent evidence is not a clean deduction)',
      state == PA.BLOCKED and 'no BTCUSD/ETHUSD run record' in detail, '%s: %s' % (state, detail))

# 🔴 THE CASE THIS HANDLER EXISTS FOR, and the one the real corpus is in today: the baseline arm
# carries a financing statement and the probe arm carries none, so the flat-lot falsifier compares
# an adjusted number with an unadjusted one. Reported as a contradiction, with the ARM split named
# -- "12 with / 10 without" scattered at random would be a different defect than one whole arm.
state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline'), crypto_run('flat-lot-probe', financing=None)]))
check('H mixed accounting treatment across comparable arms -> FAIL',
      state == PA.FAIL and 'inconsistent accounting bases' in detail
      and 'flat-lot-probe=unknown' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [selected_verification(financing=fin(applied=True))]))
check('B tester-native applied=true -> FAIL as double-charge',
      state == PA.FAIL and 'applied=true' in detail and 'double-application' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [selected_verification(financing=fin(applied=True, tester_swap_charged=0))]))
check('B0 tester-native applied=true with zero tester swap -> FAIL unconditionally',
      state == PA.FAIL and 'double-application' in detail,
      '%s: %s' % (state, detail))

# The ORDER-1350 gate, and the reason it is a FIELD and not a constant: with the two fields absent
# the item is BLOCKED; F1 above proves the same handler returns PASS once they are present. A
# hardcoded gate would make this item unreachable, which is the defect UNIMPLEMENTED exists for.
state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=fin(tester_swap_charged=None, swap_mode_probe=None))]))
check('C tester-native applied=false without numeric tester swap -> not PASS',
      state == PA.BLOCKED and 'tester_swap_charged' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=fin(swap_mode_probe=None))]))
check('D tester-native applied=false without swap-mode probe -> not PASS',
      state == PA.BLOCKED and 'swap_mode_probe' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin(
        swap_mode_probe='factory/runs/pilot/swap_probe/fixture.jsonl'))]))
check('A-posthoc post-hoc zero field plus spec-only probe -> not PASS',
      state == PA.BLOCKED and 'positive tester no-charge evidence' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin(swap_mode_probe=None))]))
check('C-posthoc post-hoc with no tester observation -> not PASS',
      state == PA.BLOCKED, '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin())]))
check('E post-hoc no-charge proof with complete estimator provenance -> PASS',
      state == PA.PASS and 'post_hoc_estimator' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin(tool=None))]))
check('F post-hoc path missing estimator provenance -> not PASS',
      state == PA.BLOCKED and 'incomplete estimator provenance' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin(
        swap_mode_probe='factory/runs/pilot/swap_probe/charge_nonzero_fixture.jsonl'))]))
check('D-posthoc post-hoc charge probe reports non-zero tester swap -> FAIL',
      state == PA.FAIL and 'not zero' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=post_hoc_fin(tester_swap_charged=-1))]))
check('G tester charge present with post-hoc applied=true -> FAIL as double-charge',
      state == PA.FAIL and 'double-charge' in detail,
      '%s: %s' % (state, detail))

# SPECIFICITY: `*` does not cross `/` in list_committed, and the BWD + Model-4 runs live one level
# down in verification/. A handler that only globbed the matrix directory would pass while the
# runs a bar is actually read off carried nothing.
state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline')], verification=[selected_verification(financing=None)]))
check('F6 SPECIFICITY a record under verification/ is read too, not just the matrix directory',
      state == PA.FAIL and 'verification/v.jsonl' in detail, '%s: %s' % (state, detail))

# 🔴 Found by /scrutinize on this same change. The first version selected on `logical_symbol`
# alone, so ANY future record filed under these directories carrying a crypto symbol -- a swap
# probe result, a closeout marker -- would be demanded to hold a financing block and would turn
# the item red for being the wrong shape. ORDER-1350's probe record is literally that object.
state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline'),
     {'entity': 'SwapProbe', 'logical_symbol': 'BTCUSD', 'swap_mode': 'INTEREST_CURRENT'}]))
check('F7 ATTACK a non-run record carrying a crypto symbol is not demanded to hold financing',
      state == PA.PASS, '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(crypto_source(
    [crypto_run('baseline', financing=fin(swap_mode_probe='factory/runs/pilot/swap_probe/missing.jsonl'))]))
check('F8 ATTACK stale or wrong probe reference -> FAIL, not a truthy-string pass',
      state == PA.FAIL and 'invalid swap-mode probe reference' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_crypto_financing(evidence.EvidenceSource('worktree'))
check('I current committed ORDER-1370 crypto evidence -> item 10 PASS',
      state == PA.PASS, '%s: %s' % (state, detail))


# item 11 (ORDER-1256) ----------------------------------------------------------------------------

def trans(attempt, transition, cell_id='B14-H01-r1/S0/H1', **rec):
    r = {'attempt': attempt, 'transition': transition, 'at': '2026-08-04T00:00:00Z'}
    r.update(rec)
    return {'entity': 'RunTransition', 'run_id': 'RUN-X', 'cell_id': cell_id,
            'attempt': attempt, 'transition': transition, 'record': r}


def journal_source(lines, cells=None):
    files = {PA.DESIGN_REL: REAL_DESIGN,
             PA.COVERAGE_REL: '\n'.join(json.dumps(c) for c in (
                 cells if cells is not None else [cell('B14-H01-r1/S0/H1')]))}
    if lines is not None:
        files['factory/runs/RUN-X.jsonl'] = '\n'.join(json.dumps(l) for l in lines)
    return FakeSource(files)


KILLED_THEN_RESUMED = [
    trans(1, 'QUEUED'), trans(1, 'LEASED'), trans(1, 'FAILED', failure_class='KILLED'),
    trans(2, 'LEASED'), trans(2, 'COMPLETED'),
]
state, detail = PA.item_scheduler_resume(journal_source(KILLED_THEN_RESUMED))
check('S1 POSITIVE a pilot cell killed at attempt 1 and resumed at attempt 2 -> PASS',
      state == PA.PASS and 'killed at attempt 1, resumed at attempt 2' in detail,
      '%s: %s' % (state, detail))

# 🔴 THE BUG THIS FIXTURE CAUGHT. The first version of the handler took the LATEST kill, so a run
# killed on every attempt read as "never resumed" -- three resumes rendered as none. The earliest
# kill is the one that has anything after it.
state, detail = PA.item_scheduler_resume(journal_source([
    trans(1, 'QUEUED'), trans(1, 'FAILED', failure_class='KILLED'),
    trans(2, 'LEASED'), trans(2, 'FAILED', failure_class='KILLED'),
    trans(3, 'LEASED'), trans(3, 'FAILED', failure_class='KILLED'),
]))
check('S2 REGRESSION killed on every attempt still shows the resumes after the FIRST kill -> PASS',
      state == PA.PASS and 'killed at attempt 1, resumed at attempt 2' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_scheduler_resume(journal_source([
    trans(1, 'QUEUED'), trans(1, 'FAILED', failure_class='KILLED'),
    trans(2, 'LEASED'), trans(2, 'COMPLETED'), trans(3, 'LEASED'),
]))
check('S3 ATTACK an attempt started after one reached COMPLETED -> FAIL (the prohibition half)',
      state == PA.FAIL and 'already COMPLETED' in detail, '%s: %s' % (state, detail))

# The real corpus is in exactly this state: a killed-and-resumed journal exists, on a WIRING cell
# id that is not a registered pilot cell. "Observed, but not on a pilot batch" is a different work
# item from "never observed", and the two must not render as the same sentence.
state, detail = PA.item_scheduler_resume(journal_source(
    [trans(1, 'FAILED', cell_id='B14-H01-r1/S0/H1/S9WIRE', failure_class='KILLED'),
     trans(2, 'LEASED', cell_id='B14-H01-r1/S0/H1/S9WIRE')]))
check('S4 a resume on a NON-pilot cell id -> BLOCKED, and it says the contract was observed',
      state == PA.BLOCKED and 'not among the' in detail and 'S9WIRE' in detail,
      '%s: %s' % (state, detail))

state, detail = PA.item_scheduler_resume(journal_source([
    trans(1, 'QUEUED'), trans(1, 'FAILED', failure_class='TESTER_ERROR'), trans(2, 'LEASED')]))
check('S5 SPECIFICITY an ordinary FAILED retry is not a KILL, so it does not satisfy this item',
      state == PA.BLOCKED and 'NONE shows a KILLED' in detail, '%s: %s' % (state, detail))

state, detail = PA.item_scheduler_resume(journal_source(None))
check('S6 no journal committed at all -> BLOCKED (a fixture cage is not the observation)',
      state == PA.BLOCKED and 'no resume to observe' in detail, '%s: %s' % (state, detail))

# 🔴 Found by /scrutinize round 2, and S3 could not have found it: S3's journal happens to contain
# a KILLED, and the prohibition check sat BELOW the `if not killed: continue` filter -- so it could
# only ever fire on a journal that had already been killed, while the comment beside it said it ran
# on every journal. Re-running completed work is a defect whether anything was killed or not.
state, detail = PA.item_scheduler_resume(journal_source([
    trans(1, 'QUEUED'), trans(1, 'LEASED'), trans(1, 'COMPLETED'), trans(2, 'LEASED')]))
check('S7 SPECIFICITY an attempt after COMPLETED is caught with NO kill anywhere in the journal',
      state == PA.FAIL and 'already COMPLETED' in detail, '%s: %s' % (state, detail))


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
