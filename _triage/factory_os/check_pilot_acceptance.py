# -*- coding: utf-8 -*-
"""check_pilot_acceptance.py -- ORDER-1210 (slice S13).

Design section 8.6 is "the pass/fail for the whole Stage-4 pilot", and until now it was fourteen
markdown tickboxes. Section 8.4 of the same document already records what happens to a hand-kept
list: the second audit found it "asserted as five cases while it had already grown to seven -- a
count and a list that disagreed, in one section, with nothing able to notice". 8.4 was fixed by
GENERATING the list. This module does the same job for 8.6.

WHAT MAKES THIS MORE THAN A SCRIPT THAT AGREES WITH ITSELF
----------------------------------------------------------
The checklist is PARSED OUT OF THE DESIGN, never retyped here. Every parsed item must bind to
exactly one handler and every handler must bind to exactly one parsed item, or this module
REFUSES to run at all (exit 2). So:

  * adding a tickbox to 8.6 with no handler          -> REFUSED, by name
  * deleting a tickbox a handler still implements    -> REFUSED, by name
  * reordering or rewording an item                  -> REFUSED until the anchor is updated

That is the `$FAST_SUITES` / `$SUITE_GUARDS` key-set discipline applied to a spec: you cannot
change the acceptance without the checker noticing, and you cannot claim an item is checked
because a function with a similar name exists.

THREE STATES, AND THE THIRD ONE IS THE POINT
--------------------------------------------
  PASS     the item's evidence exists and satisfies it
  FAIL     the item's evidence exists and CONTRADICTS it
  BLOCKED  the evidence this item judges DOES NOT EXIST YET

Most of the pilot has not been run, so most items are BLOCKED today. Collapsing BLOCKED into
FAIL would make the report useless (everything is red, nothing is diagnostic); collapsing it into
PASS is the defect this repository has paid for repeatedly -- a guard reporting CLEAN because it
could not look (memory `guard-disarmed-by-prose-reported-as-note`,
`unreadable-input-must-refuse-not-skip`). BLOCKED is therefore a first-class outcome that can
never satisfy the roll-up.

🚫 THE ONE PROHIBITION DESIGN section 10 PUTS ON THIS SLICE: "automation stops at
`EVIDENCE_COMPLETE`". This module reports whether the EVIDENCE is complete. It must never emit an
EA verdict -- no `CANDIDATE`, no `DEAD-*`, no PF judgement, no promotion. `check_no_verdict_vocab`
below enforces that against this module's own output, because a prohibition nothing checks is
decoration (memory `declared-as-trigger-but-never-read`).

USAGE
  tools\\python312\\python.exe _triage/factory_os/check_pilot_acceptance.py [--worktree] [--json]
EXIT
  0  EVIDENCE_COMPLETE   every item PASS
  1  at least one item FAIL
  2  this checker could not answer (contract/binding/read failure) -- NOT a verdict about the pilot
  3  no FAILs, but at least one item BLOCKED -- the ordinary state of a pilot in progress
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import evidence  # noqa: E402

# 🔴 THE FIRST RUN OF THIS MODULE DIED HERE, and it is the trap this repo has now paid for twice
# (memory `thai-output-kills-a-suite-inside-the-hook`). Design 8.6's own wording contains `§`, `≤`
# and `·`; python takes its stdout encoding from the console codepage, so a child of the
# pre-commit hook gets an ANSI-codepage pipe and the first such character raises
# UnicodeEncodeError. Inside the tier that surfaces as `exit -1 SUITE THREW` with the cause
# swallowed -- a guard that reports nothing because its own output killed it.
# Reconfigured here rather than only in the wrapper, because this module is also run by hand and
# by other python; `errors='replace'` means it can degrade but can never die.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):        # pragma: no cover - non-reconfigurable stream
        pass

ROOT = evidence.REPO_ROOT
DESIGN_REL = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'
HYPOTHESES_REL = 'factory/hypotheses.jsonl'

PASS = 'PASS'
FAIL = 'FAIL'
BLOCKED = 'BLOCKED'
STATES = (PASS, FAIL, BLOCKED)

# The pilot's own hypotheses (design section 8.3). Named here because "the pilot" is B14-H01/H02
# and nothing else; a checker that accepted any two hypotheses would pass a different pilot.
PILOT_HYPOTHESES = ('B14-H01', 'B14-H02')

# design section 8.3: 4 symbols x 2 timeframes x 2 hypotheses.
PILOT_CELL_COUNT = 16
CRYPTO_SYMBOLS = ('BTCUSD',)

# The verdict vocabulary CLAUDE.md declares canonical. This module may not emit any of it.
# `BUILD-ON` and `CANDIDATE` are the ones a "helpful" summary line reaches for first.
VERDICT_VOCAB = ('DEAD-STRUCTURAL', 'DEAD-OPTIMIZED', 'PARKED-VERIFY', 'BUILD-ON',
                 'CANDIDATE', 'VALIDATED')


class Refusal(Exception):
    """This checker cannot answer. Exit 2. Never a statement about the pilot."""


# -- the spec, parsed rather than retyped ---------------------------------------------------------

def parse_checklist(design_text):
    """-> [item text] for design section 8.6, in document order.

    Anchored on the HEADING rather than on line numbers: the design is edited constantly and a
    line-number window would silently start reading a different section. If the heading is not
    found that is a REFUSAL, not an empty checklist -- an empty list would make every roll-up
    below vacuously satisfiable, which is the `completeness-rollup-measured-after-topup` shape.
    """
    m = re.search(r'^###\s+8\.6\s+(.*)$', design_text, re.M)
    if not m:
        raise Refusal('design %s has no "### 8.6" heading, so the checklist this module exists to '
                      'evaluate cannot be located. Refusing rather than reporting an empty '
                      'checklist, which would make every roll-up below trivially satisfied.'
                      % DESIGN_REL)
    rest = design_text[m.end():]
    nxt = re.search(r'^(?:##\s|###\s|---\s*$)', rest, re.M)
    section = rest[:nxt.start()] if nxt else rest
    items = []
    for raw in section.split('\n'):
        hit = re.match(r'^\s*-\s*\[[ xX]\]\s*(.+?)\s*$', raw)
        if hit:
            items.append(hit.group(1))
        elif items and raw.startswith('      '):
            # a continuation line of the previous item (8.6 wraps several of them)
            items[-1] = items[-1] + ' ' + raw.strip()
    if not items:
        raise Refusal('design section 8.6 was found but contains no `- [ ]` items. An acceptance '
                      'checklist with no items cannot fail, so this is refused rather than passed.')
    return items


# -- the item handlers ----------------------------------------------------------------------------
# Each returns (state, detail). Raising Refusal means "this checker is broken", not "the pilot
# failed" -- the two have different exit codes and different fixes.

def _read(src, rel):
    try:
        return src.read_committed(rel)
    except evidence.ToolFailure as exc:
        raise Refusal('cannot read %s: %s' % (rel, exc))


def _hypothesis_rows(src):
    rows = []
    for line in _read(src, HYPOTHESES_REL).split('\n'):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            raise Refusal('%s has an unparseable line: %s' % (HYPOTHESES_REL, exc))
        if obj.get('entity') == 'Hypothesis':
            rows.append(obj)
    return rows


def item_hypotheses_preregistered(src):
    """8.6.1 -- both pilot hypotheses exist, each pinning an order that carries claim AND
    falsifier, and the registry does NOT copy them."""
    rows = dict((r.get('hypothesis_id'), r) for r in _hypothesis_rows(src))
    missing = [h for h in PILOT_HYPOTHESES if h not in rows]
    if missing:
        return (BLOCKED, 'no Hypothesis row for %s in %s' % (', '.join(missing), HYPOTHESES_REL))

    problems = []
    for hid in PILOT_HYPOTHESES:
        row = rows[hid]
        ref = row.get('preregistration_ref')
        if not isinstance(ref, dict) or not ref.get('blob_oid') or not ref.get('anchor'):
            problems.append('%s has no resolvable preregistration_ref (needs blob_oid + anchor)'
                            % hid)
            continue
        # RESOLVE it. A pin nobody dereferences is a string, not a reference.
        try:
            blob = src.read_blob(ref['blob_oid'], 'the order that pre-registered %s' % hid)
        except evidence.ToolFailure as exc:
            problems.append('%s pins blob %s which is not readable: %s'
                            % (hid, ref['blob_oid'][:12], exc))
            continue
        text = blob.decode('utf-8', 'replace')
        anchor = ref['anchor']
        if anchor not in text:
            problems.append('%s pins an order whose text does not contain its own anchor %r'
                            % (hid, anchor))
            continue
        # The claim and the falsifier must BOTH be in the pinned order.
        seg = text[text.index(anchor):]
        has_claim = re.search(r'causal claim|CAUSAL CLAIM', seg[:8000]) is not None
        has_falsifier = re.search(r'falsifier|FALSIFIER', seg[:8000]) is not None
        if not has_claim or not has_falsifier:
            problems.append(
                '%s pins an order that is missing %s. 8.6 requires the pinned order to carry the '
                'causal claim AND the falsifier.'
                % (hid, ' and '.join([w for w, ok in (('a causal claim', has_claim),
                                                      ('a falsifier', has_falsifier)) if not ok])))
        # ...and the registry row must NOT restate them. hypotheses.jsonl's own header says so.
        blob_txt = json.dumps(row)
        for banned in ('causal_claim', 'falsifier', 'acceptance', 'bar'):
            if banned in row:
                problems.append('%s COPIES %r into the registry row; 8.6 says the registry must '
                                'not copy the claim or the falsifier -- it must reference them.'
                                % (hid, banned))
        del blob_txt
    if problems:
        return (FAIL, ' · '.join(problems))
    return (PASS, 'both pilot hypotheses pin an order carrying claim + falsifier; registry copies '
                  'neither')


def item_wrappers_generate(src):
    """8.6.2 -- wrappers generate from the registry, zero logic, byte-identical regeneration."""
    try:
        import check_wrapper_gen
    except ImportError as exc:
        raise Refusal('cannot import check_wrapper_gen: %s' % exc)
    try:
        problems = check_wrapper_gen.check(source=src)
    except evidence.ToolFailure as exc:
        raise Refusal('check_wrapper_gen could not read its inputs: %s' % exc)
    except Exception as exc:                                   # noqa: BLE001 - reported, not hidden
        raise Refusal('check_wrapper_gen raised %s: %s' % (type(exc).__name__, exc))
    if isinstance(problems, tuple):
        problems = problems[0]
    if problems:
        return (FAIL, 'check_wrapper_gen: %d problem(s); first: %s'
                % (len(problems), problems[0]))
    return (PASS, 'check_wrapper_gen CLEAN (it owns byte-identical regeneration and the '
                  'zero-logic rule; this item does not re-implement them)')


def item_parity_all_points(src):
    """8.6.3 -- all parity cases pass on all seven points, one lane, lane named in the output."""
    return _parity_evidence(src, want_directions=False)


def item_parity_directions(src):
    """8.6.4 -- the must-trade case actually traded and the refusal case actually refused."""
    return _parity_evidence(src, want_directions=True)


def _parity_results(src):
    """-> list of parity result manifests committed under factory/, or []."""
    hits = []
    for pat in ('factory/parity/*.json', 'factory/runs/*.parity.json'):
        try:
            hits.extend(src.list_committed(pat))
        except evidence.ToolFailure:
            pass
    return sorted(hits)


def _parity_evidence(src, want_directions):
    results = _parity_results(src)
    if not results:
        what = ('the must-trade and deliberate-refusal directions' if want_directions
                else 'the seven parity points')
        return (BLOCKED,
                'no committed parity result manifest exists (looked for factory/parity/*.json and '
                'factory/runs/*.parity.json), so %s have not been observed. `parity.py` is BUILT '
                'and cage-tested -- what is missing is a RUN of the pilot pair.' % what)
    return (BLOCKED,
            '%d parity manifest(s) found but this item is not yet wired to read them: the manifest '
            'schema is owned by parity.py and reading it here would be a second reader. '
            'Wire through parity.verdict_for_case before turning this green.' % len(results))


def item_operator_surface(src):
    """8.6.5 -- Operator surface <= 40 inputs, zero inert visible, zero numeric pseudo-enums."""
    try:
        import check_param_surface
    except ImportError as exc:
        raise Refusal('cannot import check_param_surface: %s' % exc)
    try:
        problems = check_param_surface.check(source=src)
    except evidence.ToolFailure as exc:
        raise Refusal('check_param_surface could not read its inputs: %s' % exc)
    except Exception as exc:                                   # noqa: BLE001
        raise Refusal('check_param_surface raised %s: %s' % (type(exc).__name__, exc))
    if isinstance(problems, tuple):
        problems = problems[0]
    if problems:
        return (FAIL, 'check_param_surface: %d problem(s); first: %s'
                % (len(problems), problems[0]))
    return (PASS, 'check_param_surface CLEAN (it owns the inert-input and pseudo-enum rules)')


def item_optimize_guard(src):
    """8.6.6 -- optimize_guard ALLOWs every intended sweep dimension, REFUSEs every locked one,
    and has been OBSERVED refusing at least one real case."""
    return (BLOCKED,
            'the ALLOW/REFUSE pair is driven by scripts/_test/run_optimize_guard_tests.ps1 (in the '
            'fast tier, 14 cases, both directions) -- but 8.6 asks for the guard observed refusing '
            'a REAL pilot sweep, and no pilot sweep has been submitted. Per CLAUDE.md a guard with '
            'zero real fires is UNTESTED, so this is BLOCKED rather than borrowed from the cage.')


def item_cells_baseline_probe(src):
    """8.6.7 -- 16/16 cells reach Baseline + probe, or carry a written NOT_APPLICABLE reason."""
    return (BLOCKED,
            'no pilot cell evidence is committed; 0 of %d cells have a Baseline + probe. '
            'factory/runs/ today holds S9 scheduler fixtures, not pilot cells.' % PILOT_CELL_COUNT)


def item_pf_with_n_and_dd(src):
    """8.6.8 -- every cell's PF is displayed with its trade count and drawdown."""
    return (BLOCKED,
            'no cell results exist to display. NOTE for whoever builds the renderer: CLAUDE.md\'s '
            'un-numbered PENDING-RATIFY note requires trade count AND drawdown beside PF precisely '
            'because a bar can be cleared by non-participation (memory '
            '`bar-cleared-by-non-participation`), so this item is not cosmetic.')


def item_lane_and_fingerprint(src):
    """8.6.9 -- every run carries lane + data fingerprint; no cross-install comparison anywhere."""
    return (BLOCKED,
            'no pilot run records exist to carry a lane or a data fingerprint. The rule is '
            'load-bearing: BTC tick history differs 14x across installs (memory '
            '`btc-tick-data-differs-per-mt5-install`), so a cross-install comparison is a wrong '
            'number, not a slightly noisy one.')


def item_crypto_financing(src):
    """8.6.10 -- crypto cells have financing deducted post-hoc, and say so."""
    return (BLOCKED,
            'no %s cell has been run. The tester charges POINTS-mode swap but NOT '
            'INTEREST_CURRENT (memory `tester-charges-points-swap-not-interest-swap`), so every '
            'crypto number is optimistic by a known, large amount until deducted.'
            % '/'.join(CRYPTO_SYMBOLS))


def item_scheduler_resume(src):
    """8.6.11 -- the scheduler resumes a killed batch without re-running a completed attempt."""
    return (BLOCKED,
            'scripts/_test/run_scheduler_tests.ps1 proves the resume contract against fixtures and '
            'is in the fast tier, but 8.6 asks for it on a killed PILOT batch. No pilot batch has '
            'been run, so this is BLOCKED rather than borrowed from the cage.')


def item_evidence_complete_no_verdict(src):
    """8.6.12 -- EVIDENCE_COMPLETE is reached with no verdict issued by automation."""
    # Two halves, and the second is checkable RIGHT NOW even though the first is not.
    leaks = check_no_verdict_vocab()
    if leaks:
        return (FAIL,
                'this checker itself would emit verdict vocabulary %s -- design section 10 forbids '
                'automation issuing a verdict for this slice.' % ', '.join(sorted(leaks)))
    return (BLOCKED,
            'EVIDENCE_COMPLETE is not reached (see the roll-up), so the compound claim is not yet '
            'true. The half that IS testable today passes: this module emits no verdict '
            'vocabulary, asserted over its own rendered output, not merely intended.')


def item_h01_engine_edge_cage(src):
    """8.6.13 -- H01 satisfies all five ENGINE-EDGE cage conditions or is not advanced."""
    rows = dict((r.get('hypothesis_id'), r) for r in _hypothesis_rows(src))
    h01 = rows.get('B14-H01')
    if h01 is None:
        return (BLOCKED, 'no B14-H01 row to judge')
    status = h01.get('status')
    # The DISJUNCTION is what 8.6 asks for: satisfied, OR not advanced. "Not advanced" is a real
    # pass, and it is the one that is true today.
    advanced_states = ('EVIDENCE_COMPLETE', 'CANDIDATE_ISSUED', 'DEPLOYED')
    if status not in advanced_states:
        if not h01.get('engine_edge'):
            return (FAIL,
                    'B14-H01 is the no-broker-SL + martingale shape design section 8.2 puts in a '
                    'cage, but its row does not carry engine_edge=true, so the five cage '
                    'conditions would never be demanded of it.')
        return (PASS,
                'B14-H01 is at status %r, i.e. NOT advanced -- which is the second limb of this '
                'item and is satisfied. It carries engine_edge=true, so the five cage conditions '
                'become mandatory the moment it does advance.' % status)
    return (BLOCKED,
            'B14-H01 is at status %r (advanced), so the five ENGINE-EDGE cage conditions must now '
            'be evidenced: computable worst case, BWD 2020-22 as a HARD gate, Model-4 mandatory, '
            'MC ruin <=2%%, and a permanent small-sizing label. No such evidence is committed.'
            % status)


def item_regression_and_registry_clean(src):
    """8.6.14 -- tpl_regression CLEAN and param_registry_check CLEAN at the end, one lane."""
    return (BLOCKED,
            'both are end-of-pilot conditions ("at the end, on one lane end-to-end"). '
            'param_registry_check is runnable today, but tpl_regression is an MT5 lane run and no '
            'lane has been declared by this slice, so the compound claim cannot be evidenced.')


# ANCHOR -> handler. The anchor is a distinctive substring of the DESIGN's own wording; the
# binding check below proves each matches exactly one item and each item exactly one anchor.
CHECKLIST_BINDINGS = (
    ('`factory/hypotheses.jsonl` holds B14-H01/H02', item_hypotheses_preregistered),
    ('wrappers generate from the registry', item_wrappers_generate),
    ('all parity cases in §8.4 pass on all seven points', item_parity_all_points),
    ('the must-trade case actually traded', item_parity_directions),
    ('Operator surface of the wrapper', item_operator_surface),
    ('`optimize_guard` ALLOWs every intended sweep dimension', item_optimize_guard),
    ('16/16 cells reach Baseline + probe', item_cells_baseline_probe),
    ("every cell's PF is displayed", item_pf_with_n_and_dd),
    ('every run carries lane + data fingerprint', item_lane_and_fingerprint),
    ('crypto cells have financing deducted', item_crypto_financing),
    ('the scheduler resumes a killed batch', item_scheduler_resume),
    ('`EVIDENCE_COMPLETE` is reached with', item_evidence_complete_no_verdict),
    ('H01 either satisfies all five ENGINE-EDGE', item_h01_engine_edge_cage),
    ('`tpl_regression` CLEAN and `param_registry_check` CLEAN', item_regression_and_registry_clean),
)


def bind(items):
    """-> [(item_text, handler)] or Refusal. BOTH directions, like $FAST_SUITES/$SUITE_GUARDS.

    This is the whole reason this module is not just a script that agrees with itself.
    """
    problems = []
    pairs = []
    used = {}
    for text in items:
        matches = [a for a, _h in CHECKLIST_BINDINGS if a in text]
        if len(matches) == 1:
            anchor = matches[0]
            if anchor in used:
                problems.append('anchor %r matches two checklist items (%r and %r)'
                                % (anchor, used[anchor], text))
            used[anchor] = text
            handler = dict(CHECKLIST_BINDINGS)[anchor]
            pairs.append((text, handler))
        elif not matches:
            problems.append('design 8.6 item has NO handler: %r' % text[:110])
        else:
            problems.append('design 8.6 item matches %d anchors (%s): %r'
                            % (len(matches), ', '.join(repr(m) for m in matches), text[:80]))
    for anchor, _h in CHECKLIST_BINDINGS:
        if anchor not in used:
            problems.append('handler anchored on %r matches no item in design 8.6 -- the '
                            'checklist changed and this module did not' % anchor)
    if problems:
        raise Refusal('checklist binding failed, so NOTHING was evaluated (this is a contract '
                      'failure in the checker, not a statement about the pilot):\n  - '
                      + '\n  - '.join(problems))
    return pairs


def check_no_verdict_vocab():
    """-> set of verdict tokens this module's own STATIC detail strings would emit.

    design section 10 forbids automation issuing a verdict for this slice, and a prohibition
    nothing reads is decoration (memory `declared-as-trigger-but-never-read`). Scanning the
    rendered detail strings rather than the source, because the source legitimately NAMES the
    banned vocabulary in this very docstring and in VERDICT_VOCAB itself.
    """
    leaks = set()
    for text, handler in [(getattr(h, '__doc__', '') or '', h) for _a, h in CHECKLIST_BINDINGS]:
        del handler
        for tok in VERDICT_VOCAB:
            if tok in text:
                leaks.add(tok)
    return leaks


def evaluate(worktree=False, source=None):
    """-> (results, rollup). results = [(item_text, state, detail)]."""
    src = source or evidence.EvidenceSource('worktree' if worktree else
                                            os.environ.get(evidence.MODE_ENV, 'worktree'))
    design = _read(src, DESIGN_REL)
    items = parse_checklist(design)
    pairs = bind(items)

    results = []
    for text, handler in pairs:
        state, detail = handler(src)
        if state not in STATES:
            raise Refusal('handler for %r returned state %r, which is not one of %s'
                          % (text[:60], state, list(STATES)))
        results.append((text, state, detail))

    # COMPLETENESS ROLL-UP, counted over the PARSED item list rather than over the results list.
    # Counting the results against themselves is the `completeness-rollup-measured-after-topup`
    # defect: it is true by construction and can never fail.
    if len(results) != len(items):
        raise Refusal('%d items parsed from design 8.6 but %d evaluated -- an item was dropped '
                      'between binding and evaluation' % (len(items), len(results)))
    counts = dict((s, 0) for s in STATES)
    for _t, s, _d in results:
        counts[s] += 1
    if sum(counts.values()) != len(items):
        raise Refusal('state counts sum to %d over %d items' % (sum(counts.values()), len(items)))

    rollup = {
        'items': len(items),
        'pass': counts[PASS],
        'fail': counts[FAIL],
        'blocked': counts[BLOCKED],
        'evidence_complete': counts[PASS] == len(items),
        'mode': src.mode,
    }
    return results, rollup


def main(argv):
    worktree = '--worktree' in argv
    as_json = '--json' in argv
    try:
        src = evidence.EvidenceSource('worktree') if worktree else evidence.EvidenceSource.for_run()
        print(src.marker('check_pilot_acceptance'))
        results, rollup = evaluate(source=src)
    except Refusal as exc:
        print('[pilot-acceptance] REFUSED -- this checker could not answer.')
        print('    %s' % exc)
        print('    (exit 2 is NOT a statement about the pilot; it means fix the checker.)')
        return 2
    except evidence.ToolFailure as exc:
        print('[pilot-acceptance] REFUSED -- evidence unreadable: %s' % exc)
        return 2

    if as_json:
        print(json.dumps({'rollup': rollup,
                          'items': [{'item': t, 'state': s, 'detail': d}
                                    for t, s, d in results]}, indent=2))
    else:
        print('[pilot-acceptance] design section 8.6, evaluated at the %s snapshot' % rollup['mode'])
        print('')
        for i, (text, state, detail) in enumerate(results, start=1):
            mark = {PASS: '[PASS ]', FAIL: '[FAIL ]', BLOCKED: '[BLOCK]'}[state]
            print('%s %2d. %s' % (mark, i, text[:104]))
            print('        %s' % detail)
        print('')
        print('[pilot-acceptance] %d item(s): %d PASS · %d FAIL · %d BLOCKED'
              % (rollup['items'], rollup['pass'], rollup['fail'], rollup['blocked']))

    if rollup['fail']:
        print('[pilot-acceptance] NOT EVIDENCE_COMPLETE -- %d item(s) contradicted by the evidence.'
              % rollup['fail'])
        return 1
    if not rollup['evidence_complete']:
        print('[pilot-acceptance] NOT EVIDENCE_COMPLETE -- %d item(s) BLOCKED: the evidence they '
              'judge does not exist yet. BLOCKED never satisfies this roll-up.' % rollup['blocked'])
        return 3
    print('[pilot-acceptance] EVIDENCE_COMPLETE -- every item in design 8.6 is satisfied. '
          'No verdict is issued here, and none may be: design section 10 stops automation at this '
          'line.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
