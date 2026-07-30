"""
snapshot_validator.py - ORDER-601 part 2. The builder-input/persisted-output boundary.

WHY THIS EXISTS
  `all_clear` is REQUIRED in the persisted control-room snapshot, and a writer-supplied
  value MUST be rejected. Those two sentences cannot both be checked against one document:
  the builder has to write the field, so no validator inspecting the persisted file alone
  can tell "computed" from "typed". ORDER-601 part 1 split the entities so the SCHEMA can
  refuse a supplied answer at the input side (`ReconciliationEvidence` is closed and has no
  `all_clear` property). This file is the other half:

    build_snapshot()   SnapshotBuilderInput -> ControlRoomSnapshotV5, computing the verdict.
    verify_snapshot()  recomputes the verdict from a PERSISTED document and refuses it if
                       the stored verdict disagrees.

  The second one is the load-bearing part. Audit 5's surviving attack was a hand-authored
  output with `sources: []` and `all_clear: true` -- structurally valid against every schema
  in this repo, because JSON Schema can prove a boolean is well-typed and cannot prove who
  wrote it. Recomputation at the trust boundary is the only defence, which is why readers
  must obtain the document through load_verified() and never through json.load().

THREE RULES THIS FILE IS WRITTEN AGAINST, each one paid for elsewhere in this repo
  1. "cannot read it" must never collapse into "nothing to report". A source that cannot be
     read is MANDATORY_SOURCE_UNREADABLE, a source that is not there is
     MANDATORY_SOURCE_MISSING, and neither is silence. (memory: prove-the-instrument-can-see-the-file)
  2. "cannot decide" must never become "all clear". If freshness cannot be derived -- no
     threshold supplied, or a readable source with a null age -- this file RAISES rather
     than returning a verdict. A guard that cannot read its input is not a guard that found
     nothing. (memory: guard-disarmed-by-prose-reported-as-note)
  3. Freshness is DERIVED, never accepted. `meta.sources[].fresh` is overwritten on the way
     out from `age_hours` vs `meta.stale_bar_hours`. No threshold is hardcoded anywhere in
     this file; there is no number to grep for because there is no number.

RELATIONSHIP TO THE SCHEMA
  The 13 predicates below correspond ONE-TO-ONE with the closed `SnapshotVerdict.reasons.code`
  enum in _triage/factory_os/schemas.json. A code the enum accepts that no predicate emits is
  an unreachable contract; a predicate whose code the enum rejects makes the output invalid.
  run_snapshot_validator_tests.py asserts the two sets are equal, so they cannot drift.

  Schema validation is NOT performed here by default and NOT by accident: ajv is a subprocess
  per instance (~0.35s), and the fast pre-commit tier has ~1s of its 15s budget left. So the
  gate is a REQUIRED, EXPLICIT argument -- pass a validator, or pass the named sentinel
  NO_SCHEMA_CHECK. There is no default. Skipping the gate is therefore a visible, greppable
  act rather than something a caller gets for free by not knowing about it.

USAGE   python _triage/factory_os/snapshot_validator.py verify <path-to-snapshot.json>
TESTS   python _triage/factory_os/run_snapshot_validator_tests.py
"""
import collections
import copy
import io
import json
import os
import subprocess
import sys
import tempfile

SCHEMA_PATH = '_triage/factory_os/schemas.json'

BUILDER_ENTITY = 'SnapshotBuilderInput'
OUTPUT_ENTITY = 'ControlRoomSnapshotV5'

# --- the closed reason-code vocabulary -------------------------------------------------
# These strings must equal the enum in schemas.json $defs.SnapshotVerdict.reasons.items
# .properties.code.enum. The suite asserts set equality both ways.
MANDATORY_SOURCE_MISSING = 'MANDATORY_SOURCE_MISSING'
MANDATORY_SOURCE_UNREADABLE = 'MANDATORY_SOURCE_UNREADABLE'
MANDATORY_SOURCE_STALE = 'MANDATORY_SOURCE_STALE'
SOURCE_REGISTRY_MISMATCH = 'SOURCE_REGISTRY_MISMATCH'
DUPLICATE_SOURCE_NAME = 'DUPLICATE_SOURCE_NAME'
SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY = 'SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY'
DISCOVERED_CATEGORIZED_MISMATCH = 'DISCOVERED_CATEGORIZED_MISMATCH'
CATEGORY_SUM_MISMATCH = 'CATEGORY_SUM_MISMATCH'
COVERAGE_SUM_MISMATCH = 'COVERAGE_SUM_MISMATCH'
DUPLICATES_PRESENT = 'DUPLICATES_PRESENT'
CONFLICTS_PRESENT = 'CONFLICTS_PRESENT'
UNCLASSIFIED_PRESENT = 'UNCLASSIFIED_PRESENT'
ACTIONABLE_PRESENT = 'ACTIONABLE_PRESENT'

CATEGORY_KEYS = ('actionable', 'running', 'waiting', 'review_audit', 'completed',
                 'cancelled_by_user')
COVERAGE_PARTS = ('tested', 'untested', 'not_applicable')


class SnapshotRefusal(Exception):
    """The validator will not produce a verdict for this input.

    Deliberately NOT a verdict of `all_clear: false`. A false verdict is a statement about
    the fleet; this is a statement about the input. Collapsing the two is how "the tool could
    not read its own input" gets reported as "nothing to report" -- the defect class that has
    cost this repo more than any other.
    """


class VerdictMismatch(SnapshotRefusal):
    """A persisted document's stored verdict disagrees with the recomputed one."""


class _NoSchemaCheck(object):
    """Named sentinel, so `build_snapshot(inp, NO_SCHEMA_CHECK)` reads as a decision."""

    def __repr__(self):
        return 'NO_SCHEMA_CHECK'


NO_SCHEMA_CHECK = _NoSchemaCheck()


# ---------------------------------------------------------------------------------------
# Facts: the subset of a document the verdict is computed from. Extracted identically from a
# builder input and from a persisted document -- that identity is what makes recomputation on
# read meaningful. If the two extraction paths differed, a document could satisfy the reader
# and not the writer, which is the drift this whole slice exists to close.

Facts = collections.namedtuple('Facts', 'mandatory rows stale_bar_hours ev')


def _refuse(msg):
    raise SnapshotRefusal(msg)


def _int(container, key, where):
    v = container.get(key)
    # bool is an int subclass in Python; `True` arriving where a count belongs is a type
    # confusion that must not silently compute as 1.
    if isinstance(v, bool) or not isinstance(v, int):
        _refuse('%s.%s must be an integer, got %r -- refusing to compute an equation over a '
                'value that is not a number' % (where, key, v))
    return v


def facts_of(doc):
    """Pull the verdict-relevant facts out of a builder input or a persisted document."""
    if not isinstance(doc, dict):
        _refuse('document is %s, not an object' % type(doc).__name__)
    meta = doc.get('meta')
    if not isinstance(meta, dict):
        _refuse('meta is absent or not an object -- nothing to compute a verdict from')
    reg = meta.get('mandatory_sources')
    if not isinstance(reg, list) or not reg:
        # An empty registry makes every missing source "unexpected", which is exactly how the
        # original 0 == 0 all_clear passed. The schema also refuses this (minItems: 1); it is
        # re-checked here because this function is reachable without ajv.
        _refuse('meta.mandatory_sources is absent or empty -- with no registry, a missing '
                'source is indistinguishable from one that was never expected')
    rows = meta.get('sources')
    if not isinstance(rows, list):
        _refuse('meta.sources is absent or not an array')
    ev = meta.get('reconciliation')
    if not isinstance(ev, dict):
        _refuse('meta.reconciliation is absent or not an object')
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('name'), str):
            _refuse('every meta.sources row needs a string `name`; got %r' % (row,))
    bar = meta.get('stale_bar_hours')
    if bar is not None and not isinstance(bar, (int, float)):
        _refuse('meta.stale_bar_hours must be a number or null, got %r' % (bar,))
    return Facts(mandatory=list(reg), rows=list(rows), stale_bar_hours=bar, ev=ev)


def assert_decidable(f):
    """Refuse inputs whose verdict cannot be DERIVED. Runs before any predicate.

    This is deliberately not a predicate: the mutation harness disables predicates one at a
    time, and a refusal that could be disabled along with a predicate would mean a mutant
    that silently answers questions it cannot answer.

    FOUND BY THAT HARNESS, 2026-07-30: the type checks used to live only inside the
    predicates, so `discovered: "3"` was refused as a side effect of
    p_discovered_categorized_mismatch happening to call _int() on it. Disabling that one
    predicate left a string count flowing through every remaining equation unchecked. A guard
    that only holds while an unrelated guard is present is not a guard; the checks moved here.
    """
    cats = f.ev.get('categories')
    if not isinstance(cats, dict):
        _refuse('reconciliation.categories is absent or not an object')
    cov = f.ev.get('coverage')
    if not isinstance(cov, dict):
        _refuse('reconciliation.coverage is absent or not an object')
    for key in ('discovered', 'categorized', 'duplicates', 'conflicts', 'unclassified'):
        _int(f.ev, key, 'reconciliation')
    for key in CATEGORY_KEYS:
        _int(cats, key, 'reconciliation.categories')
    for key in ('cells_in_universe',) + COVERAGE_PARTS:
        _int(cov, key, 'reconciliation.coverage')

    for row in f.rows:
        if row['name'] not in f.mandatory:
            continue
        if not row.get('read_ok'):
            # Unreadable is already a reason; its age is meaningless and must not be
            # demanded. Refusing here would turn a REPORTABLE condition into a crash.
            continue
        if f.stale_bar_hours is None:
            _refuse('cannot derive freshness for mandatory source %r: meta.stale_bar_hours is '
                    'absent or null. Inventing a threshold is prohibited by ORDER-601, and '
                    'treating unknown freshness as fresh would turn "cannot tell" into "all '
                    'clear".' % row['name'])
        if row.get('age_hours') is None:
            _refuse('mandatory source %r reports read_ok=true with age_hours=null: the file '
                    'was read but its age is unknown, so freshness cannot be derived. This is '
                    'refused rather than reported STALE -- "unknown age" and "too old" have '
                    'different fixes.' % row['name'])


def derive_fresh(f, row):
    """Freshness from the age and the SUPPLIED threshold. Never from row['fresh'].

    Boundary: age == bar is FRESH. The bar is the oldest ACCEPTABLE age, so equality passes;
    only `>` is stale. The suite tests both sides of this, one step apart.
    """
    age = row.get('age_hours')
    if age is None or f.stale_bar_hours is None:
        return None
    return age <= f.stale_bar_hours


# ---------------------------------------------------------------------------------------
# The predicates. One per reason code, in the order their reasons are emitted.
#
# Each returns a list of (code, detail). `detail` is the SOURCE NAME for the source-level
# codes and THE NUMBERS THAT FAILED TO MATCH for the arithmetic ones, which is what the
# schema's own description of the field says it carries. Fixtures assert on the exact
# (code, detail) pair -- asserting merely "something was rejected" is what let a negative
# fixture get credited to a rule it never reached.


def p_mandatory_source_missing(f):
    present = set(r['name'] for r in f.rows)
    return [(MANDATORY_SOURCE_MISSING, n) for n in f.mandatory if n not in present]


def p_mandatory_source_unreadable(f):
    return [(MANDATORY_SOURCE_UNREADABLE, r['name']) for r in f.rows
            if r['name'] in f.mandatory and not r.get('read_ok')]


def p_mandatory_source_stale(f):
    out = []
    for r in f.rows:
        if r['name'] not in f.mandatory or not r.get('read_ok'):
            continue
        if derive_fresh(f, r) is False:
            out.append((MANDATORY_SOURCE_STALE, r['name']))
    return out


def p_source_registry_mismatch(f):
    # A row claiming mandatory status the registry does not grant. The registry is the
    # authority; a row that promotes itself is the same drift as a second copy of a fact.
    return [(SOURCE_REGISTRY_MISMATCH, r['name']) for r in f.rows
            if r.get('mandatory') and r['name'] not in f.mandatory]


def p_duplicate_source_name(f):
    seen, dupes = set(), []
    for r in f.rows:
        if r['name'] in seen and r['name'] not in dupes:
            dupes.append(r['name'])
        seen.add(r['name'])
    return [(DUPLICATE_SOURCE_NAME, n) for n in dupes]


def p_source_mandatory_flag_contradicts_registry(f):
    # The registry says mandatory, the row says it is not. Kept as a reason rather than
    # "preferring to remove the redundant flag" (ORDER-601's stated preference) because the
    # real v4 consumers read the per-row flag; removing it is an S4 migration, and until then
    # a contradiction that cannot be reported is a contradiction that ships.
    return [(SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY, r['name']) for r in f.rows
            if r['name'] in f.mandatory and r.get('mandatory') is False]


def p_discovered_categorized_mismatch(f):
    d = _int(f.ev, 'discovered', 'reconciliation')
    c = _int(f.ev, 'categorized', 'reconciliation')
    if d != c:
        return [(DISCOVERED_CATEGORIZED_MISMATCH, 'discovered=%d categorized=%d' % (d, c))]
    return []


def p_category_sum_mismatch(f):
    cats = f.ev.get('categories')
    if not isinstance(cats, dict):
        _refuse('reconciliation.categories is absent or not an object')
    total = sum(_int(cats, k, 'reconciliation.categories') for k in CATEGORY_KEYS)
    c = _int(f.ev, 'categorized', 'reconciliation')
    if total != c:
        return [(CATEGORY_SUM_MISMATCH, 'categorized=%d category_sum=%d' % (c, total))]
    return []


def p_coverage_sum_mismatch(f):
    cov = f.ev.get('coverage')
    if not isinstance(cov, dict):
        _refuse('reconciliation.coverage is absent or not an object')
    parts = sum(_int(cov, k, 'reconciliation.coverage') for k in COVERAGE_PARTS)
    universe = _int(cov, 'cells_in_universe', 'reconciliation.coverage')
    if parts != universe:
        return [(COVERAGE_SUM_MISMATCH,
                 'cells_in_universe=%d parts_sum=%d' % (universe, parts))]
    return []


def _positive(f, key, code):
    n = _int(f.ev, key, 'reconciliation')
    return [(code, '%s=%d' % (key, n))] if n > 0 else []


def p_duplicates_present(f):
    return _positive(f, 'duplicates', DUPLICATES_PRESENT)


def p_conflicts_present(f):
    return _positive(f, 'conflicts', CONFLICTS_PRESENT)


def p_unclassified_present(f):
    return _positive(f, 'unclassified', UNCLASSIFIED_PRESENT)


def p_actionable_present(f):
    cats = f.ev.get('categories')
    if not isinstance(cats, dict):
        _refuse('reconciliation.categories is absent or not an object')
    n = _int(cats, 'actionable', 'reconciliation.categories')
    return [(ACTIONABLE_PRESENT, 'actionable=%d' % n)] if n > 0 else []


# Module-level on purpose: the mutation harness rebinds THIS name to a subset to disable one
# predicate at a time. compute() reads the global at call time, so the production signature
# carries no injection seam a caller could use to quietly run fewer checks.
PREDICATES = collections.OrderedDict([
    (MANDATORY_SOURCE_MISSING, p_mandatory_source_missing),
    (MANDATORY_SOURCE_UNREADABLE, p_mandatory_source_unreadable),
    (MANDATORY_SOURCE_STALE, p_mandatory_source_stale),
    (SOURCE_REGISTRY_MISMATCH, p_source_registry_mismatch),
    (DUPLICATE_SOURCE_NAME, p_duplicate_source_name),
    (SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY, p_source_mandatory_flag_contradicts_registry),
    (DISCOVERED_CATEGORIZED_MISMATCH, p_discovered_categorized_mismatch),
    (CATEGORY_SUM_MISMATCH, p_category_sum_mismatch),
    (COVERAGE_SUM_MISMATCH, p_coverage_sum_mismatch),
    (DUPLICATES_PRESENT, p_duplicates_present),
    (CONFLICTS_PRESENT, p_conflicts_present),
    (UNCLASSIFIED_PRESENT, p_unclassified_present),
    (ACTIONABLE_PRESENT, p_actionable_present),
])


def compute(doc):
    """-> (all_clear, [(code, detail), ...]). Raises SnapshotRefusal if undecidable.

    all_clear is `not reasons` BY CONSTRUCTION rather than by a separate expression, so the
    boolean and the reason list cannot be made to disagree -- the schema says "reasons is
    empty if and only if all_clear is true" and this is where that becomes true.
    """
    f = facts_of(doc)
    assert_decidable(f)
    reasons = []
    for _code, fn in PREDICATES.items():
        reasons.extend(fn(f))
    return (not reasons), reasons


def _as_reason_objects(reasons):
    return [{'code': c, 'detail': d} for c, d in reasons]


def build_snapshot(inp, schema_validator):
    """SnapshotBuilderInput -> ControlRoomSnapshotV5 with the verdict COMPUTED.

    `schema_validator` is required and has no default: pass a callable(instance, entity) that
    raises on an invalid instance, or the sentinel NO_SCHEMA_CHECK. See the module docstring
    for why there is no default.
    """
    if schema_validator is not NO_SCHEMA_CHECK:
        schema_validator(inp, BUILDER_ENTITY)
    if not isinstance(inp, dict) or inp.get('entity') != BUILDER_ENTITY:
        _refuse('build_snapshot expects entity=%r, got %r' % (
            BUILDER_ENTITY, (inp or {}).get('entity') if isinstance(inp, dict) else inp))
    if 'verdict' in inp:
        # The closed input schema already refuses this. Re-checked because build_snapshot is
        # reachable with NO_SCHEMA_CHECK, and a supplied verdict silently overwritten is
        # indistinguishable from one that was honoured.
        _refuse('the builder input carries a `verdict`; the answer is computed here and a '
                'supplied one is refused rather than overwritten')

    all_clear, reasons = compute(inp)

    # deepcopy carries every compatibility field through untouched -- meta.stale_bar_hours,
    # decision_bar_trades, counting_method, and the real v4 source-row metadata
    # (path/sha256/mtime). Enumerating fields to copy instead would drop the next one added.
    out = copy.deepcopy(inp)
    out['entity'] = OUTPUT_ENTITY
    f = facts_of(out)
    for row in out['meta']['sources']:
        derived = derive_fresh(f, row)
        if derived is not None:
            row['fresh'] = derived
    out['verdict'] = {'all_clear': all_clear, 'reasons': _as_reason_objects(reasons)}
    return out


def verify_snapshot(doc, schema_validator):
    """Recompute the verdict from a PERSISTED document; refuse it if the stored one differs.

    This is the defence against a hand-authored output. It does not ask whether the document
    is well-formed -- the schema does that -- it asks whether the document's answer is the
    answer its own evidence produces.
    """
    if schema_validator is not NO_SCHEMA_CHECK:
        schema_validator(doc, OUTPUT_ENTITY)
    if not isinstance(doc, dict) or doc.get('entity') != OUTPUT_ENTITY:
        _refuse('verify_snapshot expects entity=%r, got %r' % (
            OUTPUT_ENTITY, (doc or {}).get('entity') if isinstance(doc, dict) else doc))
    stored = doc.get('verdict')
    if not isinstance(stored, dict) or 'all_clear' not in stored or 'reasons' not in stored:
        _refuse('the persisted document carries no usable `verdict` to check')

    all_clear, reasons = compute(doc)
    problems = []

    if bool(stored['all_clear']) is not bool(all_clear):
        problems.append('verdict.all_clear is %r but the evidence in this document computes '
                        '%r' % (bool(stored['all_clear']), bool(all_clear)))

    stored_pairs = set()
    for r in (stored['reasons'] or []):
        if not isinstance(r, dict):
            _refuse('verdict.reasons contains a non-object entry: %r' % (r,))
        stored_pairs.add((r.get('code'), r.get('detail')))
    computed_pairs = set(reasons)
    if stored_pairs != computed_pairs:
        invented = sorted('%s:%s' % p for p in stored_pairs - computed_pairs)
        omitted = sorted('%s:%s' % p for p in computed_pairs - stored_pairs)
        if invented:
            problems.append('verdict.reasons states reasons this document does not produce: '
                            + ', '.join(invented))
        if omitted:
            problems.append('verdict.reasons omits reasons this document does produce: '
                            + ', '.join(omitted))

    # The verdict can agree while a row still lies about its own freshness -- the verdict is
    # derived from `age_hours`, so a stale row with `fresh: true` produces the right reason
    # and leaves a false field behind for every consumer that reads the row instead.
    f = facts_of(doc)
    for row in f.rows:
        derived = derive_fresh(f, row)
        if derived is not None and bool(row.get('fresh')) is not bool(derived):
            problems.append('meta.sources[%r].fresh is %r but age_hours=%r against '
                            'stale_bar_hours=%r derives %r'
                            % (row['name'], bool(row.get('fresh')), row.get('age_hours'),
                               f.stale_bar_hours, derived))

    if problems:
        raise VerdictMismatch(
            'this document\'s stored verdict does not match its own evidence:\n  - '
            + '\n  - '.join(problems))
    return doc


def load_verified(path, schema_validator):
    """The only sanctioned way for a reader to obtain a snapshot. Wiring readers is S4."""
    with io.open(path, encoding='utf-8-sig') as fh:
        doc = json.load(fh)
    return verify_snapshot(doc, schema_validator)


# ---------------------------------------------------------------------------------------
# The optional ajv gate. Lives here so callers do not each grow their own copy, and is not
# invoked by the fast tier -- see the module docstring on the budget.

def ajv_schema_validator(instance, entity):
    """callable(instance, entity) for build_snapshot/verify_snapshot. Raises on invalid."""
    if instance.get('entity') != entity:
        _refuse('expected entity=%r, got %r' % (entity, instance.get('entity')))
    fd, path = tempfile.mkstemp(suffix='.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as fh:
            json.dump(instance, fh)
        p = subprocess.run(['ajv', 'validate', '-s', SCHEMA_PATH, '-d', path,
                            '--spec=draft2020', '--strict=false', '--errors=line'],
                           capture_output=True, text=True, shell=True)
        out = (p.stdout + p.stderr).strip()
        if p.returncode == 0:
            return instance
        # Same three-state discipline as run_schema_fixtures.py: a tool failure is NOT a
        # rejection. Reporting "invalid" when ajv is simply absent is how a suite reports
        # 14 of 17 cases OK with the schema file deleted.
        if p.returncode == 1 and ' invalid' in out:
            _refuse('%s failed schema validation: %s' % (entity, out.splitlines()[0]))
        raise SnapshotRefusal('ajv could not run, so nothing was validated (exit %s): %s'
                              % (p.returncode, out.splitlines()[0] if out else '<no output>'))
    finally:
        os.unlink(path)


def main(argv):
    if len(argv) != 3 or argv[1] != 'verify':
        print(__doc__.strip().splitlines()[-2])
        return 2
    try:
        load_verified(argv[2], ajv_schema_validator)
    except SnapshotRefusal as exc:
        print('[REFUSED] %s' % exc)
        return 1
    print('[OK] %s: stored verdict matches the verdict recomputed from its own evidence'
          % argv[2])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
