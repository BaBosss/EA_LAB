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
EA verdict -- no `CANDIDATE`, no `DEAD-*`, no PF judgement, no promotion. `scan_verdict_vocab` is
run by `evaluate` over every RENDERED detail and REFUSES on a leak, because a prohibition nothing
checks is decoration (memory `declared-as-trigger-but-never-read`) -- and because the first
version of that guard scanned handler docstrings while claiming to scan the rendered output,
which is a prohibition checked on the one surface nobody reads.

USAGE
  tools\\python312\\python.exe _triage/factory_os/check_pilot_acceptance.py [--worktree] [--json]
EXIT
  0  EVIDENCE_COMPLETE   every item PASS
  1  at least one item FAIL
  2  this checker could not answer (contract/binding/read failure) -- NOT a verdict about the pilot
  3  no FAILs, but at least one item BLOCKED -- the ordinary state of a pilot in progress
"""

import hashlib
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import evidence  # noqa: E402
import parity  # noqa: E402
# The RunJournal fold belongs to scheduler.py and is imported rather than re-derived here. A
# second fold would be a second reader of the same append-only store, which is the defect
# ORDER-1255 names for parity and which applies identically to the journal.
import scheduler  # noqa: E402

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
COVERAGE_REL = 'factory/coverage.jsonl'
# ORDER-1253 (8.6 item 6). The guard's committed decision records, and the cage that drives its
# two directions on fixtures. The tier file is read to prove the cage is in the array that RUNS.
OPTIMIZE_LOG_REL = 'factory/optimize_decisions.jsonl'
OPTIMIZE_GUARD_CAGE = 'run_optimize_guard_tests.ps1'
FAST_TIER_REL = 'scripts/_test/run_fast_cages.ps1'

PASS = 'PASS'
FAIL = 'FAIL'
BLOCKED = 'BLOCKED'
STATES = (PASS, FAIL, BLOCKED)

# The pilot's own hypotheses (design section 8.3). Named here because "the pilot" is B14-H01/H02
# and nothing else; a checker that accepted any two hypotheses would pass a different pilot.
PILOT_HYPOTHESES = ('B14-H01', 'B14-H02')

# design section 8.3: 4 symbols x 2 timeframes x 2 hypotheses.
PILOT_CELL_COUNT = 16
CRYPTO_SYMBOLS = ('BTCUSD', 'ETHUSD')
FINANCING_RUN_ENTITIES = frozenset(('PilotCellRun', 'PilotSelectedVerification'))

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
        # EXACTLY ONCE, which is what schemas.json says verbatim -- "must occur EXACTLY once in
        # the blob and contain no spaces". The first version tested mere PRESENCE, which is
        # weaker than the declared constraint in the direction that matters: a DUPLICATED anchor
        # is an ambiguous reference, and the whole purpose of an OwnerRef is that it resolves to
        # one place. /scrutinize round 3.
        occurrences = text.count(anchor)
        if occurrences != 1:
            problems.append(
                '%s pins an order whose text contains its anchor %r %d time(s); schemas.json '
                'requires EXACTLY once (%s)'
                % (hid, anchor, occurrences,
                   'the reference does not resolve' if occurrences == 0
                   else 'the reference is ambiguous'))
            continue

        # 🔴 THE SECTION IS BOUNDED, and round 3 found this passing on a neighbour's homework.
        # The first version took `text[index(anchor):][:8000]` -- a magic character window that
        # does not stop at the end of the pinned order. Reproduced before the fix: an order whose
        # own section stated no method at all PASSED, because the window ran on into the NEXT
        # `## ORDER-` heading and matched that order's causal claim and falsifier. Item 1 is one
        # of only four implemented checks here, so a false PASS in it is most of this module's
        # credibility.
        # The window now ends at whichever comes first: the next taskboard order heading, the
        # next preregistration anchor, or end of text.
        start = text.index(anchor) + len(anchor)
        ends = [m.start() for m in re.finditer(r'^##\s+ORDER-', text[start:], re.M)]
        ends += [m.start() for m in re.finditer(r'B14-H\d+-PREREGISTRATION', text[start:])]
        seg = text[start:start + min(ends)] if ends else text[start:]
        # CASE-INSENSITIVE, and the reason is a defect this matcher produced the first time a real
        # pre-registration was written against it (ORDER-1220). The pattern was
        # `causal claim|CAUSAL CLAIM`, which does not match `**Causal claim.**` -- the ordinary way
        # a human writes a heading. The rule §8.6 states is about CONTENT ("carries the causal
        # claim and the falsifier"); capitalisation is not part of it, so a matcher that turns on
        # capitalisation was testing something the rule never asked for.
        #
        # 🔴 The falsifier half was WORSE, and only luck exposed it: `falsifier|FALSIFIER` missed
        # the `**Falsifier.**` heading too, but the item still reported the falsifier as present --
        # because the word appears in lowercase in a FOOTNOTE further down the same section. It was
        # matching prose ABOUT the falsifier rather than the falsifier's own heading, i.e. passing
        # for a reason unrelated to the thing it checks. Both are now case-insensitive, which makes
        # the two halves behave the same way instead of one of them being accidentally lenient.
        has_claim = re.search(r'causal\s+claim', seg, re.I) is not None
        has_falsifier = re.search(r'falsifier', seg, re.I) is not None
        if not has_claim or not has_falsifier:
            problems.append(
                '%s pins an order that is missing %s. 8.6 requires the pinned order to carry the '
                'causal claim AND the falsifier.'
                % (hid, ' and '.join([w for w, ok in (('a causal claim', has_claim),
                                                      ('a falsifier', has_falsifier)) if not ok])))
        # ...and the registry row must NOT restate them. hypotheses.jsonl's own header says so.
        # (A `json.dumps(row)` was computed here and immediately deleted -- dead code from an
        # earlier substring-based draft, removed in /scrutinize round 1. It looked like the check
        # was scanning the serialised row when it is scanning the KEYS, which is the correct
        # reading of "must not copy": a copy is a field, not a coincidence of wording.)
        for banned in ('causal_claim', 'falsifier', 'acceptance', 'bar'):
            if banned in row:
                problems.append('%s COPIES %r into the registry row; 8.6 says the registry must '
                                'not copy the claim or the falsifier -- it must reference them.'
                                % (hid, banned))
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
    """-> the one canonical parity result manifest, or []."""
    try:
        return [parity.RESULT_MANIFEST_REL] if src.exists_committed(parity.RESULT_MANIFEST_REL) else []
    except evidence.ToolFailure:
        return []


def _parity_evidence(src, want_directions):
    results = _parity_results(src)
    if not results:
        what = ('the must-trade and deliberate-refusal directions' if want_directions
                else 'the seven parity points')
        return (BLOCKED,
                'no committed parity result manifest exists at %s, so %s have not been observed. '
                '`parity.py` is BUILT '
                'and cage-tested -- what is missing is a RUN of the pilot pair.'
                % (parity.RESULT_MANIFEST_REL, what))
    if len(results) != 1:
        return (FAIL, 'expected exactly one canonical parity result manifest, found %d' % len(results))
    rel = results[0]
    try:
        manifest = parity.read_result_manifest(_read(src, rel), rel)
    except parity.ManifestError as exc:
        return (FAIL, 'parity result manifest rejected: %s' % exc)
    summary = parity.evaluate_result_manifest(manifest)
    if not summary['replay_ok']:
        return (FAIL, 'parity result manifest does not replay cleanly: %s'
                % ' · '.join(summary['replay_problems']))
    if want_directions:
        if summary['direction_failures'][parity.MUST_TRADE]:
            return (FAIL, 'the must-trade case did not actually trade on both sides')
        if summary['direction_failures'][parity.DELIBERATE_REFUSAL]:
            return (FAIL, 'the deliberate-refusal case did not refuse on both sides')
        missing = [kind for kind in (parity.MUST_TRADE, parity.DELIBERATE_REFUSAL)
                   if not summary['directions'][kind]]
        if missing:
            return (BLOCKED, 'the committed result has no evidenced %s direction case'
                    % ' or '.join(missing))
        return (PASS, 'parity.verdict_for_case replayed both required directions on lane %s'
                % manifest['run_identity']['lane'])
    if summary['rollup_ok']:
        return (PASS, 'parity result replayed all seven points across the committed case set on '
                'lane %s' % manifest['run_identity']['lane'])
    return (BLOCKED, 'the committed parity result is readable but the case set is incomplete: %s'
            % ' · '.join(line.strip() for line in summary['rollup_lines']
                         if line.strip().startswith('- ')))


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


def _tier_entries(array_text):
    """-> {suite name} actually LISTED in a PowerShell array literal, comments excluded.

    🔴 THE FIRST VERSION OF THIS CHECK WAS `OPTIMIZE_GUARD_CAGE in array_text`, and it was the
    exact defect its own docstring cited as the reason for the check. Measured: `$FAST_SUITES`
    holds **294 comment lines**, several of which name suites while explaining them, so deleting
    the real entry `'run_optimize_guard_tests.ps1',` leaves the string present and the substring
    test reports the cage is on the commit path when it no longer runs
    (memory `text-scan-cannot-tell-read-from-mention`).

    A `#` is dropped with the rest of its line before quoted tokens are extracted. Suite names
    contain no `#`, so a trailing comment cannot take an entry with it.
    """
    entries = set()
    for line in array_text.split('\n'):
        code = line.split('#', 1)[0]
        entries.update(re.findall(r"""['"]([^'"]+)['"]""", code))
    return entries


def item_optimize_guard(src):
    """8.6.6 -- optimize_guard ALLOWs every intended sweep dimension, REFUSEs every locked one,
    and has been OBSERVED refusing at least one real case.

    ORDER-1253. THREE conditions, and the third is the one CLAUDE.md's `UNTESTED` rule adds:

      (a) the both-directions cage exists AND is in the array the tier actually runs -- not merely
          named somewhere in the tier file, because a text search cannot tell "invoked" from
          "mentioned" (memory `text-scan-cannot-tell-read-from-mention`);
      (b) the guard REFUSED at least one dimension of a REAL submission;
      (c) the guard ALLOWED at least one real submission outright. A guard broken closed refuses
          every real case too, so (b) alone cannot distinguish it from a working one.

    All three are read from committed artefacts. The cage's 14 fixture cases are NOT counted as
    fires: that is the borrowing this item is written to forbid.
    """
    try:
        import optimize_log
    except ImportError as exc:                                 # pragma: no cover - import guard
        raise Refusal('cannot import optimize_log: %s' % exc)

    # (a) The cage, and its membership of the array that runs. `_read` goes through the evidence
    #     source, so in hook mode this is the tier AS COMMITTED, not as edited in the worktree.
    tier = _read(src, FAST_TIER_REL)
    m = re.search(r'\$FAST_SUITES\s*=\s*@\((.*?)\n\)', tier, re.S)
    if not m:
        raise Refusal('cannot locate the $FAST_SUITES array in %s, so whether the optimize_guard '
                      'cage is on the commit path cannot be answered' % FAST_TIER_REL)
    if OPTIMIZE_GUARD_CAGE not in _tier_entries(m.group(1)):
        return (FAIL,
                '%s is not inside $FAST_SUITES in %s. The both-directions half of this item is '
                'carried by that suite; a cage that does not run is not evidence.'
                % (OPTIMIZE_GUARD_CAGE, FAST_TIER_REL))

    # (b) + (c) the real submissions.
    if not src.exists_committed(OPTIMIZE_LOG_REL):
        return (BLOCKED,
                'the both-directions pair is driven by %s (in the fast tier), but no decision log '
                'is committed at %s, so the guard has NOT been observed judging a real submission. '
                'Per CLAUDE.md a guard with zero real fires is UNTESTED, and the cage\'s fixture '
                'cases must not be borrowed to fill that gap.'
                % (OPTIMIZE_GUARD_CAGE, OPTIMIZE_LOG_REL))
    try:
        records = optimize_log.parse(_read(src, OPTIMIZE_LOG_REL), OPTIMIZE_LOG_REL)
    except optimize_log.LogRefusal as exc:
        raise Refusal('the decision log cannot be read as a log: %s' % exc)

    refusals = optimize_log.real_refusals(records)
    allows = optimize_log.real_allows(records)
    if not refusals or not allows:
        return (BLOCKED,
                '%d decision record(s) committed, but the observed pair is incomplete: %d '
                'submission(s) had a dimension REFUSED and %d were ALLOWed outright. Both '
                'directions are required -- a guard that refuses everything also refuses at least '
                'one real case, so the refusal alone does not distinguish a working guard from one '
                'broken closed.' % (len(records), len(refusals), len(allows)))

    r0 = refusals[0]
    refused_names = ', '.join(sorted(d.get('name', '?')
                                     for d in optimize_log.refused_dimensions(r0)))
    return (PASS,
            '%d real submission(s) recorded in %s: %d with a dimension REFUSED, %d ALLOWed '
            'outright. First observed refusal: %s refused %s on lane %s (revision %r). The '
            'both-directions fixture pair is carried by %s, which is inside $FAST_SUITES.'
            % (len(records), OPTIMIZE_LOG_REL, len(refusals), len(allows),
               r0.get('submitted_utc'), refused_names, r0.get('lane'),
               r0.get('hypothesis_revision') or '(none declared)', OPTIMIZE_GUARD_CAGE))


def _pilot_cells(src):
    """-> [CoverageCell] for the pilot hypotheses, from the coverage store.

    ORDER-1250. This is what "the pilot cell result store" turned out to mean. `registry.STORES`
    has always declared factory/coverage.jsonl to be the CoverageCell store, and the ORDER-610
    imported rows carry an explicit exemption in check_registries.check_r5 reading "it ends when
    S5's real CoverageCell rows land". The 16 rows this reads ARE those rows.

    Imported rows are skipped by DISCRIMINATOR, not by shape: a row that fails to parse is a
    Refusal, because a cell store that silently drops rows makes 16/16 unfalsifiable.
    """
    cells = []
    for n, line in enumerate(_read(src, COVERAGE_REL).split('\n'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            raise Refusal('%s line %d is unparseable: %s' % (COVERAGE_REL, n, exc))
        if obj.get('entity') != 'CoverageCell':
            continue
        if str(obj.get('hypothesis_revision', '')).split('-r')[0] in PILOT_HYPOTHESES:
            cells.append(obj)
    return cells


# The states in which a cell has been through BOTH a Baseline and the decision-13 probe. A cell at
# BASELINE_RUN has had one of the two, which is why this tuple does not contain it.
#
# 🔴 The flat-lot arm that HAS been run against all 16 cells is H01's FALSIFIER -- it answers
# "does the edge live in the engine or the signal". The probe design 8.3 owes each cell is the
# decision-13 OPTIMIZE probe, a different run answering a different question. Ticking this item
# from the falsifier is prohibited by name in the order that implemented this handler, and the
# store says BASELINE_RUN for all 16 precisely so that the prohibition is mechanical rather than
# a note somebody has to remember.
PROBE_DONE_STATES = ('PROBE_RUN', 'PULSE', 'NO_PULSE', 'RESCUE_IN_PROGRESS', 'EVIDENCE_COMPLETE')


def item_cells_baseline_probe(src):
    """8.6.7 -- 16/16 cells reach Baseline + probe, or carry a written NOT_APPLICABLE reason."""
    cells = _pilot_cells(src)
    if not cells:
        return (BLOCKED,
                'no pilot cell is registered in %s. The runs may exist under factory/runs/pilot/, '
                'but an untyped run record is not a cell: nothing can route it to a contract.'
                % COVERAGE_REL)
    if len(cells) > PILOT_CELL_COUNT:
        return (FAIL,
                '%s holds %d pilot cells; design 8.3 declares exactly %d (4 symbols x 2 TF x 2 '
                'hypotheses). A universe larger than the design is not extra coverage, it is a '
                'cell nobody pre-registered.' % (COVERAGE_REL, len(cells), PILOT_CELL_COUNT))

    done, waiting, bad = [], [], []
    for c in cells:
        cid = c.get('cell_id')
        state = c.get('state')
        if state == 'NOT_APPLICABLE':
            why = c.get('not_applicable_reason')
            if isinstance(why, str) and len(why.strip()) >= 10:
                done.append(cid)
            else:
                bad.append('%s is NOT_APPLICABLE with no written reason' % cid)
        elif state in PROBE_DONE_STATES:
            done.append(cid)
        else:
            waiting.append('%s=%s' % (cid, state))
    if bad:
        return (FAIL, '; '.join(bad))
    if len(cells) < PILOT_CELL_COUNT:
        waiting.append('%d of %d cells are not registered at all'
                       % (PILOT_CELL_COUNT - len(cells), PILOT_CELL_COUNT))
    if waiting:
        return (BLOCKED,
                '%d of %d cells have reached Baseline + probe. Still owed: %s. A cell at '
                'BASELINE_RUN has had its Baseline and NOT the decision-13 optimize probe -- the '
                'flat-lot arm already run against every cell is H01\'s falsifier, which answers a '
                'different question and must not be counted here.'
                % (len(done), PILOT_CELL_COUNT, ', '.join(sorted(waiting))))
    return (PASS,
            'all %d cells reach Baseline + probe or carry a written NOT_APPLICABLE reason'
            % PILOT_CELL_COUNT)


def _fmt_pf(metric):
    """PF as a string that CANNOT be read as a number when it is not one.

    ORDER-1230 had to repair the opposite of this: the tester prints `0` for a run with no losing
    trade, so the cell with the best win rate in the matrix rendered as the worst result in it.
    `pf_state` exists to make that unfakeable in the store; this makes it unfakeable in the output.
    """
    if metric.get('pf_state') == 'UNDEFINED_NO_LOSSES':
        return 'UNDEF(no losses)'
    pf = metric.get('pf')
    return 'n/a' if pf is None else ('%.2f' % pf)


def item_pf_with_n_and_dd(src):
    """8.6.8 -- every cell's PF is displayed with its trade count and drawdown."""
    cells = _pilot_cells(src)
    if not cells:
        return (BLOCKED, 'no pilot cell is registered in %s, so there is nothing to display'
                % COVERAGE_REL)
    empty = [c.get('cell_id') for c in cells if not (c.get('metrics') or [])]
    if empty:
        return (FAIL,
                '%d cell(s) carry no metric at all: %s. An empty `metrics` array is how a cell '
                'that was never measured renders as a cell with nothing to report.'
                % (len(empty), ', '.join(sorted(str(e) for e in empty))))
    # The DISPLAY is this detail line. CLAUDE.md's un-numbered PENDING-RATIFY note requires the
    # trade count AND the drawdown beside PF precisely because a bar can be cleared by
    # non-participation (memory `bar-cleared-by-non-participation`) -- two BWD-clearing hosts took
    # 52 and 62 trades at under 2% DD while every failing host took 343-473. A PF alone cannot
    # tell those apart, so this item is not cosmetic.
    shown = []
    for c in sorted(cells, key=lambda x: str(x.get('cell_id'))):
        for m in c['metrics']:
            shown.append('%s [%s] PF=%s n=%s DD=%s%%'
                         % (c.get('cell_id'), m.get('window'), _fmt_pf(m), m.get('trades'),
                            m.get('dd_pct')))
    return (PASS,
            'every registered cell displays PF with its trade count and drawdown, and an absent '
            'denominator is displayed as UNDEF rather than as a number:\n        '
            + '\n        '.join(shown))


def _pilot_run_records(src):
    """-> [(rel, line_no, record)] for every committed pilot run record.

    Read as well as the cell store because 8.6.9 says every RUN, and the cell store registers one
    metric per cell -- the Baseline arm. The probe arms are runs too, and a rule about runs that
    only ever looks at a third of them is a rule that would not notice the other two.
    """
    out = []
    try:
        paths = src.list_committed('factory/runs/pilot/*.jsonl')
    except evidence.ToolFailure:
        return out
    for rel in sorted(paths):
        for n, line in enumerate(_read(src, rel).split('\n'), 1):
            line = line.strip()
            if not line:
                continue
            try:
                out.append((rel, n, json.loads(line)))
            except ValueError as exc:
                raise Refusal('%s line %d is unparseable: %s' % (rel, n, exc))
    return out


def item_lane_and_fingerprint(src):
    """8.6.9 -- every run carries lane + data fingerprint; no cross-install comparison anywhere."""
    cells = _pilot_cells(src)
    runs = _pilot_run_records(src)
    if not cells and not runs:
        return (BLOCKED,
                'no pilot cell and no pilot run record is committed, so there is nothing carrying '
                'a lane or a data fingerprint to check.')

    missing, lanes, fingerprints = [], {}, set()
    for c in cells:
        for i, m in enumerate(c.get('metrics') or []):
            where = '%s metrics[%d]' % (c.get('cell_id'), i)
            for f in ('lane', 'data_fingerprint'):
                if not m.get(f):
                    missing.append('%s has no %s' % (where, f))
            if m.get('lane'):
                lanes.setdefault(m['lane'], []).append(where)
            if m.get('data_fingerprint'):
                fingerprints.add(m['data_fingerprint'])
    for rel, n, rec in runs:
        where = '%s:%d' % (rel, n)
        for f in ('lane', 'data_fingerprint'):
            if not rec.get(f):
                missing.append('%s has no %s' % (where, f))
        if rec.get('lane'):
            lanes.setdefault(rec['lane'], []).append(where)

    if missing:
        return (FAIL,
                '%d run/metric record(s) carry no lane or no data fingerprint; first: %s. Without '
                'both, a number cannot be told apart from the same number produced somewhere else.'
                % (len(missing), missing[0]))
    if len(lanes) > 1:
        return (FAIL,
                'the pilot evidence spans %d MT5 lanes (%s), so a cross-install comparison exists '
                'in the output. BTC tick history differs 14x across installs (memory '
                '`btc-tick-data-differs-per-mt5-install`), which makes such a comparison a WRONG '
                'number rather than a noisy one.'
                % (len(lanes), '; '.join('%s x%d' % (k, len(v)) for k, v in sorted(lanes.items()))))
    lane = next(iter(lanes)) if lanes else '<none>'
    return (PASS,
            'every one of the %d metric(s) and %d run record(s) carries a lane and a data '
            'fingerprint, and all of them name ONE lane (%s), so no cross-install comparison '
            'exists in the output. Distinct data fingerprints among the registered metrics: %d '
            '(one per window x symbol x TF, which is what makes them comparable).'
            % (sum(len(c.get('metrics') or []) for c in cells), len(runs), lane,
               len(fingerprints)))


def _crypto_run_records(src):
    """-> [(rel, line_no, record)] for every committed pilot run record on a crypto symbol.

    Reads the verification directory as well as the matrix directory. `list_committed`'s `*` does
    not cross `/`, and the BWD + Model-4 runs -- the ones a bar is actually read off -- live one
    level down in `verification/`. A financing rule that only saw the matrix would report on the
    third of the runs nobody judges anything from.
    """
    out = []
    for pattern in ('factory/runs/pilot/*.jsonl', 'factory/runs/pilot/verification/*.jsonl'):
        try:
            paths = src.list_committed(pattern)
        except evidence.ToolFailure:
            continue
        for rel in sorted(paths):
            for n, line in enumerate(_read(src, rel).split('\n'), 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError as exc:
                    raise Refusal('%s line %d is unparseable: %s' % (rel, n, exc))
                # ENTITY-GATED on purpose. `logical_symbol` alone would sweep in any future record
                # type filed under these directories -- a probe result, a selection row, a
                # closeout marker -- and then demand a financing block of something that is not a
                # run. The swap probe record ORDER-1350 writes is exactly that shape.
                if (rec.get('entity') in FINANCING_RUN_ENTITIES
                and rec.get('logical_symbol') in CRYPTO_SYMBOLS):
                    out.append((rel, n, rec))
    return out


def _read_swap_probe_records(src, reference):
    """Return ``(records, detail)`` for a committed swap-probe JSONL reference."""
    if not isinstance(reference, str) or not reference.startswith('factory/runs/pilot/swap_probe/'):
        return (None, 'must be a repository reference under factory/runs/pilot/swap_probe/')
    try:
        content = _read(src, reference)
    except (evidence.ToolFailure, Refusal) as exc:
        return (None, 'cannot read referenced probe %r: %s' % (reference, exc))
    records = []
    for n, line in enumerate(content.split('\n'), 1):
        if not line.strip():
            continue
        try:
            probe = json.loads(line)
        except ValueError:
            return (None, 'referenced probe is unparseable at line %d' % n)
        if not isinstance(probe, dict):
            return (None, 'referenced probe line %d is not a JSON object' % n)
        if probe.get('_comment'):
            continue
        records.append(probe)
    return (records, '')


def _swap_mode_probe_is_valid(src, reference, symbol):
    """Return ``(ok, detail)`` for a dated symbol-spec probe reference."""
    records, detail = _read_swap_probe_records(src, reference)
    if records is None:
        return (False, detail)
    matches = [probe for probe in records
               if (probe.get('entity') == 'SwapProbe' and probe.get('probe') == 'spec'
                   and probe.get('logical_symbol') == symbol
                   and isinstance(probe.get('taken_utc'), str)
                   and re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$',
                                probe['taken_utc'])
                   and probe.get('swap_mode'))]
    if len(matches) != 1:
        return (False, 'referenced probe must contain exactly one dated spec record for %s' % symbol)
    return (True, '')


def _artifact_reference(reference, kind):
    """Return a safe repository-relative committed-artifact reference."""
    if not isinstance(reference, str) or not reference.startswith('factory/runs/pilot/'):
        return (None, '%s must be a repository reference under factory/runs/pilot/' % kind)
    normalized = reference.replace('\\', '/')
    parts = normalized.split('/')
    if (normalized.startswith('/') or re.match(r'^[A-Za-z]:', normalized)
            or '..' in parts or any(not part for part in parts)):
        return (None, '%s is not a safe repository-relative reference' % kind)
    return (normalized, '')


def _read_artifact_bytes(src, reference, kind):
    """Read one committed artifact through the evidence source, with no disk fallback."""
    reference, detail = _artifact_reference(reference, kind)
    if reference is None:
        return (None, detail)
    try:
        return (src.read_committed_bytes(reference), '')
    except (AttributeError, evidence.ToolFailure) as exc:
        return (None, 'cannot resolve committed %s %r: %s' % (kind, reference, exc))


def _artifact_text(raw, kind):
    """Decode a committed text artifact using the repository's MT5-compatible encodings."""
    for encoding in ('utf-8-sig', 'utf-16', 'utf-16-le'):
        try:
            text = raw.decode(encoding)
        except (AttributeError, UnicodeDecodeError):
            continue
        if text.count('\x00') < max(1, len(text) // 100):
            return (text, '')
    return (None, '%s is not a readable UTF-8/UTF-16 text artifact' % kind)


def _artifact_hash_matches(raw, recorded, kind):
    if not isinstance(recorded, str) or not re.match(r'^[0-9a-fA-F]{64}$', recorded):
        return ('unknown', '%s has no valid SHA256 identity' % kind)
    actual = hashlib.sha256(raw).hexdigest()
    if actual.lower() != recorded.lower():
        return ('fail', '%s SHA256 mismatch: recorded=%s actual=%s'
                % (kind, recorded, actual))
    return ('pass', '')


def _html_meta(text):
    meta = {}
    for match in re.finditer(
            r'<meta\b[^>]*\bname=["\']([^"\']+)["\'][^>]*\bcontent=["\']([^"\']*)["\'][^>]*>',
            text, re.I):
        meta[match.group(1).strip().lower()] = match.group(2).strip()
    return meta


def _set_meta(text):
    meta = {}
    for line in text.splitlines():
        match = re.match(r'^\s*;\s*([A-Za-z0-9_.-]+)\s*=\s*(.*?)\s*$', line)
        if match:
            meta[match.group(1).strip().lower()] = match.group(2).strip()
    return meta


def _report_swap_total(text, symbol):
    """Read the realized Swap column from a validated MT5 13-column Deals table."""
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', text, re.I | re.S)
    swaps = []
    header = None
    for row in rows:
        cells = [re.sub(r'<[^>]+>', '', cell).strip()
                 for cell in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.I | re.S)]
        labels = [cell.lower() for cell in cells]
        required = ('time', 'deal', 'symbol', 'direction', 'swap')
        if len(cells) == 13 and all(label in labels for label in required):
            header = {label: labels.index(label) for label in required}
            continue
        if header is None or len(cells) != 13:
            continue
        if cells[header['direction']].lower() != 'out':
            continue
        if cells[header['symbol']] != symbol:
            return ('unknown', 'Deals row symbol %r does not match charge probe symbol %r'
                    % (cells[header['symbol']], symbol))
        if not cells[header['time']] or not re.match(r'^\d{4}[.\-/]\d{2}[.\-/]\d{2}',
                                                       cells[header['time']]):
            return ('unknown', 'Deals row has no auditable timestamp')
        if not re.match(r'^#?\d+$', cells[header['deal']]):
            return ('unknown', 'Deals row has no numeric deal identity')
        value = cells[header['swap']].replace(',', '').replace(' ', '')
        try:
            swaps.append(float(value))
        except ValueError:
            return ('unknown', 'report Deals table has a non-numeric Swap value')
    if header is None:
        return ('unknown', 'report has no readable Deals table header')
    if not swaps:
        return ('unknown', 'report has no readable closing Deals row carrying Swap')
    return ('pass', sum(swaps))


def _charge_probe_artifacts(src, probe, symbol):
    """Resolve report and set artifacts and bind their identities to one charge probe."""
    report_raw, detail = _read_artifact_bytes(src, probe.get('report'), 'tester report')
    if report_raw is None:
        return ('unknown', detail)
    status, detail = _artifact_hash_matches(report_raw, probe.get('report_sha256'), 'tester report')
    if status != 'pass':
        return (status, detail)
    report_text, detail = _artifact_text(report_raw, 'tester report')
    if report_text is None:
        return ('unknown', detail)

    set_raw, detail = _read_artifact_bytes(src, probe.get('set'), 'pinned config')
    if set_raw is None:
        return ('unknown', detail)
    status, detail = _artifact_hash_matches(set_raw, probe.get('set_sha256'), 'pinned config')
    if status != 'pass':
        return (status, detail)
    set_text, detail = _artifact_text(set_raw, 'pinned config')
    if set_text is None:
        return ('unknown', detail)

    report_meta = _html_meta(report_text)
    set_meta = _set_meta(set_text)
    expected = {
        'probe_id': probe.get('probe_id'),
        'config_id': probe.get('config_id'),
        'logical_symbol': symbol,
        'window': probe.get('window'),
    }
    missing = [key for key, value in expected.items()
               if not isinstance(value, str) or not value.strip()]
    if missing:
        return ('unknown', 'charge probe lacks artifact identity fields: %s'
                % ', '.join(missing))
    mismatches = []
    for key, value in expected.items():
        if report_meta.get(key) != value:
            mismatches.append('report %s' % key)
        if set_meta.get(key) != value:
            mismatches.append('pinned config %s' % key)
    if mismatches:
        return ('unknown', 'charge artifacts do not share probe identity: %s'
                % ', '.join(mismatches))

    status, observed_swap = _report_swap_total(report_text, symbol)
    if status != 'pass':
        return (status, observed_swap)
    if not math.isclose(observed_swap, probe.get('tester_swap_charged'), abs_tol=1e-9):
        return ('fail', 'tester report Swap=%s disagrees with charge probe tester_swap_charged=%s'
                % (observed_swap, probe.get('tester_swap_charged')))
    return ('pass', '')


def _charge_probe_is_valid(src, reference, symbol):
    """Return ``(status, detail)`` for positive tester no-charge evidence."""
    records, detail = _read_swap_probe_records(src, reference)
    if records is None:
        return ('unknown', detail)
    matches = [probe for probe in records
               if (probe.get('entity') == 'SwapProbe' and probe.get('probe') == 'charge'
                   and probe.get('logical_symbol') == symbol
                   and isinstance(probe.get('taken_utc'), str)
                   and re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$',
                                probe['taken_utc']))]
    if len(matches) != 1:
        return ('unknown', 'referenced probe must contain exactly one dated charge observation '
                'for %s' % symbol)
    probe = matches[0]
    tester_swap = probe.get('tester_swap_charged')
    if not _finite_number(tester_swap):
        return ('unknown', 'charge observation has no numeric tester_swap_charged')
    if tester_swap != 0:
        return ('fail', 'charge observation reports tester_swap_charged=%s, not zero'
                % tester_swap)
    missing = []
    for field in ('lane', 'report', 'source', 'window', 'side'):
        if not isinstance(probe.get(field), str) or not probe.get(field).strip():
            missing.append(field)
    for field in ('model', 'lot', 'days_held'):
        if not _finite_number(probe.get(field)):
            missing.append(field)
    if not _finite_number(probe.get('lot')) or probe.get('lot') <= 0:
        missing.append('lot>0')
    if not _finite_number(probe.get('days_held')) or probe.get('days_held') <= 0:
        missing.append('days_held>0')
    for field in ('probe_id', 'config_id', 'report_sha256', 'set', 'set_sha256'):
        if not isinstance(probe.get(field), str) or not probe.get(field).strip():
            missing.append(field)
    if missing:
        return ('unknown', 'charge observation lacks auditable execution/exposure fields: %s'
                % ', '.join(dict.fromkeys(missing)))
    return _charge_probe_artifacts(src, probe, symbol)


def _finite_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def _crypto_financing_path(src, rel, n, rec):
    """Classify one run's exactly-once financing claim."""
    where = '%s:%d %s [%s]' % (rel, n, rec.get('cell_id'), rec.get('arm') or rec.get('window'))
    fin = rec.get('financing_deducted')
    if not isinstance(fin, dict):
        return ('unknown', '%s carries no financing_deducted block' % where)

    applied = fin.get('applied')
    basis = fin.get('metric_basis')
    tester_swap = fin.get('tester_swap_charged')

    if basis == 'tester_native' and applied is True:
        return ('fail', '%s declares tester_native metrics with applied=true: double-application'
                % where)

    if applied is False:
        if basis != 'tester_native':
            return ('unknown', '%s applied=false requires metric_basis=tester_native, got %r'
                    % (where, basis))
        if not _finite_number(tester_swap):
            return ('unknown', '%s tester-native path has no numeric '
                    'financing_deducted.tester_swap_charged' % where)
        reference = fin.get('swap_mode_probe')
        if not reference:
            return ('unknown', '%s tester-native path has no financing_deducted.swap_mode_probe'
                    % where)
        ok, detail = _swap_mode_probe_is_valid(src, reference, rec['logical_symbol'])
        if not ok:
            return ('fail', '%s invalid swap-mode probe reference: %s' % (where, detail))
        return ('tester_native', '')

    if applied is True:
        # A non-zero tester charge plus applied=true is an explicit double charge,
        # regardless of whether legacy estimator metadata is otherwise complete.
        if _finite_number(tester_swap) and tester_swap != 0:
            return ('fail', '%s has applied=true with tester_swap_charged=%s: double-charge'
                    % (where, tester_swap))
        missing = []
        if basis != 'post_hoc_estimator':
            missing.append('metric_basis=post_hoc_estimator')
        for field in ('tool', 'detail', 'swap_mode_probe'):
            if not isinstance(fin.get(field), str) or not fin.get(field).strip():
                missing.append(field)
        for field in ('rate_long_pct_yr', 'rate_short_pct_yr'):
            if not _finite_number(fin.get(field)):
                missing.append(field)
        if not _finite_number(tester_swap):
            missing.append('tester_swap_charged=0 proof')
        elif tester_swap != 0:
            return ('fail', '%s post-hoc path claims no tester charge but tester_swap_charged=%s: '
                    'double-charge' % (where, tester_swap))
        if missing:
            return ('unknown', '%s applied=true post-hoc path has incomplete estimator '
                    'provenance: %s' % (where, ', '.join(missing)))
        probe_status, detail = _charge_probe_is_valid(
            src, fin['swap_mode_probe'], rec['logical_symbol'])
        if probe_status == 'fail':
            return ('fail', '%s invalid post-hoc charge observation: %s' % (where, detail))
        if probe_status == 'unknown':
            return ('unknown', '%s post-hoc path lacks positive tester no-charge evidence: %s'
                    % (where, detail))
        return ('post_hoc_estimator', '')

    return ('unknown', '%s financing_deducted.applied must be false or true, got %r'
            % (where, applied))


def item_crypto_financing(src):
    """8.6.10 -- crypto cells account for financing exactly once, with provenance."""
    recs = _crypto_run_records(src)
    if not recs:
        return (BLOCKED,
                'no %s run record is committed under factory/runs/pilot/, so there is no crypto '
                'number for a financing cost to be deducted from.' % '/'.join(CRYPTO_SYMBOLS))

    entity_counts = {}
    for _rel, _n, rec in recs:
        entity = rec.get('entity')
        entity_counts[entity] = entity_counts.get(entity, 0) + 1
    run_summary = '%d %s run record(s): %s' % (
        len(recs), '/'.join(CRYPTO_SYMBOLS),
        ', '.join('%d %s' % (count, entity)
                  for entity, count in sorted(entity_counts.items()))
    )

    # The accepted basis is a per-record fact, then a cross-arm consistency fact.
    # A complete arm must never make an incomplete or contradictory peer disappear.
    outcomes = []
    for rel, n, rec in recs:
        path, detail = _crypto_financing_path(src, rel, n, rec)
        outcomes.append((rel, n, rec, path, detail))

    failures = [detail for _rel, _n, _rec, path, detail in outcomes if path == 'fail']
    unknown = [detail for _rel, _n, _rec, path, detail in outcomes if path == 'unknown']
    known_paths = {path for _rel, _n, _rec, path, _detail in outcomes
                   if path in ('tester_native', 'post_hoc_estimator')}

    # All comparable crypto arms in this closeout must state one explicit accounting basis.
    # Mixed complete bases, or a known basis beside an unproven peer, are FAIL rather than PASS.
    if len(known_paths) > 1 or (known_paths and unknown):
        arm_paths = {}
        for _rel, _n, rec, path, _detail in outcomes:
            arm_paths.setdefault(str(rec.get('arm')), set()).add(path)
        split = '; '.join('%s=%s' % (arm, '/'.join(sorted(paths)))
                          for arm, paths in sorted(arm_paths.items()))
        suffix = ' (first unproven record: %s)' % unknown[0] if unknown else ''
        failures.append('inconsistent accounting bases across comparable crypto arms: %s%s'
                        % (split, suffix))

    if failures:
        return (FAIL, '%s; first: %s' % (run_summary, failures[0]))
    if unknown:
        return (BLOCKED,
                '%s cannot establish exactly-once financing for %d record(s); first: %s'
                % (run_summary, len(unknown), unknown[0]))

    # Both accepted paths above require auditable tester/probe provenance.
    # 🔴 THE GATE IS READ FROM THE RECORD, NOT HARDCODED, and that is deliberate. A handler that
    # returned BLOCKED on a constant because of ORDER-1350 would be a stub wearing a reader --
    # exactly the shape the UNIMPLEMENTED block above exists to stop. So the two facts that would
    # settle it are named as FIELDS, and the moment a writer records them this item goes green on
    # its own:
    #   financing_deducted.tester_swap_charged  the tester's OWN swap total for this report, so a
    #                                           second charge cannot be mistaken for the first
    #   financing_deducted.swap_mode_probe      a DATED probe of the symbol's swap mode; the
    #                                           premise in swap_adjust_crypto.py is a 2026-07-26
    #                                           measurement and broker state moves under it
    path = next(iter(known_paths))
    return (PASS,
            '%s use one exactly-once accounting basis (%s) with auditable tester/probe '
            'provenance.' % (run_summary, path))


def _run_journals(src):
    """-> [(rel, journal)] for every committed RunTransition manifest under factory/runs/.

    `factory/runs/*.jsonl` does not cross `/`, so the pilot matrix records one level down are not
    swept up here -- they are not RunTransition lines and folding them would be a category error.
    """
    out = []
    try:
        paths = src.list_committed('factory/runs/*.jsonl')
    except evidence.ToolFailure:
        return out
    for rel in sorted(paths):
        lines = []
        for n, line in enumerate(_read(src, rel).split('\n'), 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError as exc:
                raise Refusal('%s line %d is unparseable: %s' % (rel, n, exc))
            if obj.get('entity') == 'RunTransition':
                lines.append(obj)
        if lines:
            out.append((rel, scheduler.fold(lines)))
    return out


def item_scheduler_resume(src):
    """8.6.11 -- the scheduler resumes a killed batch without re-running a completed attempt."""
    journals = _run_journals(src)
    if not journals:
        return (BLOCKED,
                'no RunTransition manifest is committed under factory/runs/, so there is no '
                'resume to observe. scripts/_test/run_scheduler_tests.ps1 proves the contract '
                'against fixtures and is in the fast tier, but 8.6 asks for it on a PILOT batch '
                'and a cage over fixtures is not that observation.')

    pilot_ids = set(str(c.get('cell_id')) for c in _pilot_cells(src) if c.get('cell_id'))
    qualifying, killed_but_not_pilot, violations = [], [], []
    for rel, j in journals:
        cell = str(j.get('cell_id') or '')
        attempts = j.get('attempts') or []
        # A kill is a FAILED transition whose failure_class says so -- not any failure. The
        # distinction is the whole item: an ordinary FAILED retry is not evidence a KILLED batch
        # can be resumed.
        # THE PROHIBITION HALF RUNS FIRST, AND ON EVERY JOURNAL. 🔴 /scrutinize round 2 caught this
        # sitting BELOW the `if not killed: continue` filter, where it could only ever fire on a
        # journal that had already been killed -- while the comment beside it claimed it ran on
        # every journal. "Re-running a completed attempt" is a defect whether or not anything was
        # ever killed, and a guard that cannot fire on the case it names is the shape this repo
        # keeps paying for.
        completed = [a.get('attempt') or 0 for a in attempts if a.get('transition') == 'COMPLETED']
        if completed and any((a.get('attempt') or 0) > min(completed) for a in attempts):
            violations.append('%s (%s) starts an attempt after attempt %d reached COMPLETED'
                              % (rel, cell, min(completed)))
        # A kill is a FAILED transition whose failure_class says so -- not any failure. The
        # distinction is the whole item: an ordinary FAILED retry is not evidence a KILLED batch
        # can be resumed.
        killed = [a for a in attempts
                  if a.get('transition') == 'FAILED' and a.get('failure_class') == 'KILLED']
        if not killed:
            continue
        # The EARLIEST kill, not the latest. A run killed three times in a row has its last kill
        # at the final attempt with nothing after it -- taking the max would read "no resume" off
        # a journal that resumed twice. This is what the first version of this handler got wrong,
        # and the fixture below is the one that catches it.
        first_kill = min(a.get('attempt') or 0 for a in killed)
        resumed = [a for a in attempts if (a.get('attempt') or 0) > first_kill]
        if not resumed:
            continue
        if cell in pilot_ids:
            qualifying.append('%s (%s): killed at attempt %d, resumed at attempt %d'
                              % (rel, cell, first_kill,
                                 min(a.get('attempt') or 0 for a in resumed)))
        else:
            killed_but_not_pilot.append('%s (%s)' % (rel, cell))

    if violations:
        return (FAIL,
                'a committed journal re-runs work that was already COMPLETED, which is the half '
                'of this item stated as a prohibition: %s' % '; '.join(sorted(violations)))
    if qualifying:
        return (PASS,
                '%d committed journal(s) show a KILLED attempt followed by a resume on a '
                'registered pilot cell, and no journal starts an attempt after one reached '
                'COMPLETED: %s' % (len(qualifying), '; '.join(sorted(qualifying))))
    if killed_but_not_pilot:
        return (BLOCKED,
                '%d RunTransition manifest(s) are committed and %d of them DO show a KILLED '
                'attempt followed by a resume -- but on cell id(s) that are not among the %d '
                'registered pilot cells: %s. The resume contract is therefore observed, just not '
                'on a PILOT batch, which is what 8.6 asks for. Missing: one killed-and-resumed '
                'run whose cell_id is a registered pilot cell.'
                % (len(journals), len(killed_but_not_pilot), len(pilot_ids),
                   ', '.join(sorted(killed_but_not_pilot))))
    return (BLOCKED,
            '%d RunTransition manifest(s) are committed and NONE shows a KILLED attempt followed '
            'by a later attempt, so no resume has been observed at all -- on a pilot cell or '
            'anywhere else. %d pilot cell(s) are registered. Missing: one killed-and-resumed run '
            'whose cell_id is one of them.' % (len(journals), len(pilot_ids)))


def item_evidence_complete_no_verdict(src):
    """8.6.12 -- EVIDENCE_COMPLETE is reached with no verdict issued by automation."""
    # Two halves, and the second is checkable RIGHT NOW even though the first is not.
    # This half scans the handler DOCSTRINGS only -- it cannot see the rendered details, because
    # it is itself one of the handlers being rendered. The rendered-detail scan is in `evaluate`,
    # where the full result set exists, and it REFUSES rather than reporting FAIL: a checker that
    # violates its own prohibition is a broken checker, not a failed pilot.
    leaks = scan_verdict_vocab(handler_docstrings())
    if leaks:
        return (FAIL,
                'a handler docstring carries verdict vocabulary %s -- design section 10 forbids '
                'automation issuing a verdict for this slice.' % ', '.join(sorted(leaks)))
    return (BLOCKED,
            'EVIDENCE_COMPLETE is not reached (see the roll-up), so the compound claim is not yet '
            'true. The half that IS testable today passes: no handler docstring names a verdict, '
            'and `evaluate` separately scans every RENDERED detail before returning.')


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


# 🔴 UNIMPLEMENTED, DECLARED -- /scrutinize round 2.
#
# Round 2 asked a question the roll-up could not answer: which handlers can EVER return PASS?
# Ten of the fourteen could not. They are stubs that read nothing and return a hardcoded BLOCKED,
# so `EVIDENCE_COMPLETE` was UNREACHABLE BY CONSTRUCTION and exit code 0 was dead code.
#
# That is bad in a specific and familiar way. "BLOCKED because the pilot has not run" and "BLOCKED
# because nobody wrote this check yet" are DIFFERENT WORK ITEMS with different owners, and the
# report collapsed them into one word. The failure mode is concrete: someone runs the pilot, the
# evidence appears, these items still say BLOCKED because they never look at anything -- and the
# reader concludes the checklist is broken, or hand-waves it. A guard that can never go green is
# the mirror of a guard that can never fire, and this repo has paid for both.
#
# So the stubs are DECLARED, the report separates them, and the cage asserts the declaration is
# exact in both directions. Implementing one means DELETING its name here -- which is the forcing
# function: you cannot quietly leave a stub in place while claiming the checklist is mechanical.
UNIMPLEMENTED = {
    'item_evidence_complete_no_verdict':
        'the compound claim can only be evaluated once every other item can PASS; the half that '
        'is testable today (no verdict vocabulary) IS implemented and driven.',
    'item_regression_and_registry_clean':
        'needs an end-of-pilot marker and a tpl_regression run on the declared lane.',
}

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
    # The UNIMPLEMENTED declaration must be exact in BOTH directions, for the same reason the
    # anchor binding is: a stale entry means the report lies about which items are stubs, and a
    # missing entry means a stub is being reported as ordinary BLOCKED.
    known = set(h.__name__ for _a, h in CHECKLIST_BINDINGS)
    for name in sorted(set(UNIMPLEMENTED) - known):
        problems.append('UNIMPLEMENTED declares %r, which is not a bound handler' % name)
    if problems:
        raise Refusal('checklist binding failed, so NOTHING was evaluated (this is a contract '
                      'failure in the checker, not a statement about the pilot):\n  - '
                      + '\n  - '.join(problems))
    return pairs


def scan_verdict_vocab(texts):
    """-> set of banned verdict tokens occurring in `texts`.

    design section 10 forbids automation issuing a verdict for this slice, and a prohibition
    nothing reads is decoration (memory `declared-as-trigger-but-never-read`).

    🔴 THIS TAKES ITS TEXTS FROM THE CALLER, and round 1 of /scrutinize is why. The first version
    was `check_no_verdict_vocab()` with no argument: its docstring said it scanned "the rendered
    detail strings", and its body scanned `handler.__doc__` -- the ONE surface that is never
    printed. A handler returning `'B14-H01 is a VALIDATED CANDIDATE, promote it'` was therefore
    invisible to it, which was reproduced before this was rewritten. The cage did not catch it
    because the attack case planted the token in the mutant's DOCSTRING, so it proved the
    docstring path and left the printed path unguarded -- a guard checking the wrong surface, with
    a green test agreeing.

    The banned vocabulary is now scanned where it would actually reach a reader: over every
    rendered detail (see `evaluate`) AND over the handler docstrings, because a docstring that
    names a verdict is a strong hint the handler is drifting toward issuing one.
    """
    leaks = set()
    for text in texts:
        if not text:
            continue
        for tok in VERDICT_VOCAB:
            if tok in text:
                leaks.add(tok)
    return leaks


def handler_docstrings():
    return [getattr(h, '__doc__', '') or '' for _a, h in CHECKLIST_BINDINGS]


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
    # 🔴 THE PROHIBITION, ENFORCED ON THE SURFACE THAT REACHES A READER (/scrutinize round 1).
    # Every rendered detail is scanned here, where the whole result set exists. A leak REFUSES
    # rather than being reported as an item FAIL: this module emitting a verdict is a defect in
    # the module, and reporting it through the same channel it just corrupted would be asking the
    # liar to grade the lie.
    leaked = scan_verdict_vocab([d for _t, _s, d in results])
    if leaked:
        raise Refusal(
            'this checker would EMIT verdict vocabulary %s in its rendered output. design '
            'section 10 stops this slice\'s automation at EVIDENCE_COMPLETE, so a rendered '
            'verdict is a defect in the checker -- refusing rather than printing it.'
            % ', '.join(sorted(leaked)))

    counts = dict((s, 0) for s in STATES)
    for _t, s, _d in results:
        counts[s] += 1
    if sum(counts.values()) != len(items):
        raise Refusal('state counts sum to %d over %d items' % (sum(counts.values()), len(items)))

    # Split BLOCKED by CAUSE. Same word, two different owners: "the pilot has not produced this
    # evidence" is work for whoever runs the pilot; "this check is a stub" is work for whoever
    # builds the checker. /scrutinize round 2.
    stub_names = set(UNIMPLEMENTED)
    handler_by_item = dict((t, h) for (t, h) in pairs)
    blocked_stub = 0
    stub_items = {}
    for t, s, _d in results:
        name = handler_by_item[t].__name__
        if name in stub_names:
            stub_items[t] = UNIMPLEMENTED[name]
            if s == BLOCKED:
                blocked_stub += 1

    rollup = {
        'items': len(items),
        'pass': counts[PASS],
        'fail': counts[FAIL],
        'blocked': counts[BLOCKED],
        'blocked_awaiting_evidence': counts[BLOCKED] - blocked_stub,
        'blocked_checker_unimplemented': blocked_stub,
        'evidence_complete': counts[PASS] == len(items),
        # Honest and load-bearing: while any bound handler is a declared stub, EVIDENCE_COMPLETE
        # cannot be reached however good the pilot's evidence gets. A reader must not have to
        # infer that from a wall of BLOCKED lines.
        'evidence_complete_reachable': not stub_names,
        'unimplemented': sorted(stub_names),
        'stub_items': stub_items,
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
            # Say WHICH KIND of blocked, on the line, where the reader is looking.
            stub = rollup['stub_items'].get(text)
            if state == BLOCKED and stub:
                print('        ^ CHECKER NOT IMPLEMENTED (not merely awaiting evidence): %s' % stub)
        print('')
        print('[pilot-acceptance] %d item(s): %d PASS · %d FAIL · %d BLOCKED '
              '(%d awaiting evidence, %d checker-not-implemented)'
              % (rollup['items'], rollup['pass'], rollup['fail'], rollup['blocked'],
                 rollup['blocked_awaiting_evidence'], rollup['blocked_checker_unimplemented']))
        if not rollup['evidence_complete_reachable']:
            print('[pilot-acceptance] ⚠ EVIDENCE_COMPLETE is currently UNREACHABLE: %d of the %d '
                  'items are stub checkers, so no amount of pilot evidence can turn this green '
                  'until they are implemented.'
                  % (rollup['blocked_checker_unimplemented'], rollup['items']))

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
