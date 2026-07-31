"""
snapshot_validator.py - ORDER-601 part 2. The builder-input/persisted-output boundary.

WHY THIS EXISTS
  `reconciliation_clear` is REQUIRED in the persisted control-room snapshot, and a writer-supplied
  value MUST be rejected. Those two sentences cannot both be checked against one document:
  the builder has to write the field, so no validator inspecting the persisted file alone
  can tell "computed" from "typed". ORDER-601 part 1 split the entities so the SCHEMA can
  refuse a supplied answer at the input side (`ReconciliationEvidence` is closed and has no
  `reconciliation_clear` property). This file is the other half:

    build_snapshot()   SnapshotBuilderInput -> ControlRoomSnapshotV5, computing the verdict.
    verify_snapshot()  recomputes the verdict from a PERSISTED document and refuses it if
                       the stored verdict disagrees.

  The second one is the load-bearing part. Audit 5's surviving attack was a hand-authored
  output with `sources: []` and `reconciliation_clear: true` -- structurally valid against every schema
  in this repo, because JSON Schema can prove a boolean is well-typed and cannot prove who
  wrote it. Recomputation at the trust boundary is the only defence, which is why readers
  must obtain the document through load_verified() and never through json.load().

  WHAT verify_snapshot PROVES, EXACTLY: that the stored verdict is the verdict this document's
  own evidence produces. It proves INTERNAL CONSISTENCY, not authenticity. Codex audit 6 made the
  distinction concrete by pointing every source row at a nonexistent drive path with
  `mtime: 2099-01-01`, `age_hours: 0`, `read_ok: true` -- accepted, because every fact being
  recomputed was itself supplied by the document. `read_ok`, `age_hours`, `path`, `sha256`,
  `mtime` and the reconciliation counts are all builder CLAIMS that this file takes at face value.
  Closing that means deriving them from the real file at build time and re-hashing (or verifying a
  content-addressed evidence manifest) at read time; that is S4 work, alongside wiring the readers.
  Until it exists, do not describe a verified snapshot as "honest" or "trustworthy" -- it is
  self-consistent, which is strictly weaker and is still worth having, because it closes the
  typed-verdict attack it was written for.

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

  Schema validation is NOT performed by default and NOT by accident: ajv is a subprocess per
  instance, and the fast pre-commit tier has no budget for it. So the gate is a REQUIRED,
  EXPLICIT argument on build_snapshot/verify_snapshot, and it accepts exactly two values --
  `ajv_schema_validator` or the named sentinel `NO_SCHEMA_CHECK`. Anything else raises TypeError.
  Codex audit 6 found the earlier version accepted ANY callable, which made "skipping is a
  visible, greppable act" false: `lambda i, e: i` skipped it and greps for nothing.

  `load_verified()` -- the PUBLIC reader boundary -- takes no such argument and always validates.
  A boundary whose caller chooses whether to check is not a boundary.

WHAT THIS VERDICT DOES *NOT* COVER -- read this before showing it to anyone
  `reconciliation_clear` is computed from `meta.reconciliation` and the source rows, and from
  NOTHING ELSE. It was called `all_clear` until Codex audit 6 built a document with a dead fleet
  sensor (NO_SENSOR), a blind floating-risk sensor, missing kill/judge controls, an unclassified
  unknown magic and missing attestation -- and it verified `true`, correctly, because none of
  those domains reach compute(). The name was the defect, not the arithmetic.

  So: `system_health`, `floating_risk`, `deployments.gaps`, `unknown_magics`, `attestation`,
  `judge_readiness` and `summary` are carried through this boundary UNCHECKED. This verdict means
  "the order/coverage reconciliation adds up and its mandatory sources were readable and fresh".
  It does not mean the fleet is healthy, and it must never be rendered as a headline that implies
  it. Making the verdict global is real work -- those domains are `array of arbitrary object`
  today and need health contracts of their own first -- and it belongs with S4, where the readers
  get wired.

USAGE   python _triage/factory_os/snapshot_validator.py verify <path-to-snapshot.json>
TESTS   python _triage/factory_os/run_snapshot_validator_tests.py
"""
import collections
import copy
import io
import json
import os
import re
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

    Deliberately NOT a verdict of `reconciliation_clear: false`. A false verdict is a statement about
    the fleet; this is a statement about the input. Collapsing the two is how "the tool could
    not read its own input" gets reported as "nothing to report" -- the defect class that has
    cost this repo more than any other.
    """


class VerdictMismatch(SnapshotRefusal):
    """A persisted document's stored verdict disagrees with the recomputed one."""


class MalformedDocument(SnapshotRefusal):
    """The bytes are not a ControlRoomSnapshotV5 at all -- unparseable, or a different kind of thing.

    MEASURED 2026-07-31 (ORDER-612 / S4): load_verified() called json.load() with no handler, so a
    CORRUPT snapshot came out of the command line as an unhandled JSONDecodeError traceback and
    Python's default exit 1 -- indistinguishable, to any caller, from "this document's verdict
    disagrees with its evidence". The two have completely different fixes: one means the writer
    truncated a file, the other means somebody typed an answer in.

    Kept separate from ToolFailure because it IS a statement about the document, and separate from
    a plain refusal because it says "we have no coverage data" rather than "we have data that does
    not add up". Exit code 4.
    """


class ToolFailure(SnapshotRefusal):
    """The checker could not run. NOT a statement about the document.

    MEASURED 2026-07-31 (ORDER-612 / S4) while building the reader boundary on top of this file.
    Every path in here raised plain SnapshotRefusal and main() returned 1 for all of them -- so
    "ajv is not installed" and "this document's verdict is a lie" left the same exit code, and the
    PowerShell reader about to consume it would have reported an uninstalled node as a refused
    snapshot. That is this module's own rule 1 ("cannot read it" must never collapse into a finding)
    holding for every caller EXCEPT its own command line.

    A subclass rather than a new hierarchy so every existing `except SnapshotRefusal` keeps
    working; the distinction is carried by the exit code (3, not 1) and by the printed prefix.
    """


class _NoSchemaCheck(object):
    """Named sentinel, so `build_snapshot(inp, NO_SCHEMA_CHECK)` reads as a decision."""

    def __repr__(self):
        return 'NO_SCHEMA_CHECK'


NO_SCHEMA_CHECK = _NoSchemaCheck()


def _resolve_gate(schema_validator):
    """Accept ONLY the canonical validator or the named sentinel. Nothing else.

    Codex audit 6 (MAJOR 3): the claim that skipping the gate was a "visible, greppable act" was
    false, because the parameter accepted any callable -- `lambda instance, entity: instance` was
    an equally valid argument and greps for nothing. A required argument that accepts an arbitrary
    no-op is ceremony, not a gate. Two values are legal now, one of which is named after what it
    gives up.
    """
    if schema_validator is NO_SCHEMA_CHECK or schema_validator is ajv_schema_validator:
        return schema_validator
    raise TypeError(
        'schema_validator must be snapshot_validator.ajv_schema_validator or the named sentinel '
        'snapshot_validator.NO_SCHEMA_CHECK, not %r. An arbitrary callable here silently disables '
        'the schema gate while looking like it supplies one.' % (schema_validator,))


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
    # Codex audit 6 (MAJOR 3, reproduced): the schema carries `minimum: 0` on every one of these,
    # but nothing here did -- so with the schema gate skipped, `duplicates: -1` computed
    # reconciliation_clear=true, because DUPLICATES_PRESENT asks `n > 0` and -1 is not. The same
    # held for conflicts and unclassified. That is audit 5's balanced-negative attack coming back
    # through the door the schema was guarding, which is exactly what a skippable gate means.
    # A count cannot be negative in any world this program models, so this is a refusal and not
    # a reason code: it is not a fact about the fleet, it is a broken input.
    if v < 0:
        _refuse('%s.%s is %d. A count cannot be negative; this is a malformed input, not a '
                'finding about the fleet, and a `> 0` test would silently pass it.'
                % (where, key, v))
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
        # original 0 == 0 reconciliation_clear passed. The schema also refuses this (minItems: 1); it is
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
        if 'read_ok' not in row:
            # MEASURED 2026-07-30 (/scrutinize): an absent `read_ok` used to fall through the
            # `not row.get('read_ok')` test below and be REPORTED as MANDATORY_SOURCE_UNREADABLE.
            # That is this module's own rule 1 running backwards: "the field is not there" was
            # being stated as "the file could not be read". Fail-closed is not enough when the
            # two have different fixes. The schema requires the field; reaching here without it
            # means no schema check ran, so the honest answer is that the input is undecidable.
            _refuse('mandatory source %r has no `read_ok` field at all. That is not the same fact '
                    'as read_ok=false: one means the collector did not report, the other means '
                    'the file could not be read, and they have different fixes.' % row['name'])
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
    """-> (reconciliation_clear, [(code, detail), ...]). Raises SnapshotRefusal if undecidable.

    reconciliation_clear is `not reasons` BY CONSTRUCTION rather than by a separate expression, so the
    boolean and the reason list cannot be made to disagree -- the schema says "reasons is
    empty if and only if reconciliation_clear is true" and this is where that becomes true.
    """
    f = facts_of(doc)
    assert_decidable(f)
    reasons = []
    for _code, fn in PREDICATES.items():
        reasons.extend(fn(f))
    return (not reasons), reasons


def _as_reason_objects(reasons):
    return [{'code': c, 'detail': d} for c, d in reasons]


# Keys that only the validator may write. Finding one in a BUILDER INPUT means somebody supplied
# the answer, which is the whole thing ORDER-601 exists to make impossible.
# `all_clear` is kept in this list even though nothing writes it any more. It was the name until
# Codex audit 6, and a builder written against the old contract would supply it; silently ignoring
# that is the exact failure this scan exists to prevent, and it would be invisible because the key
# no longer appears anywhere else. A retired name stays forbidden.
SUPPLIED_ANSWER_KEYS = ('verdict', 'reconciliation_clear', 'all_clear', 'reasons')


def _refuse_supplied_answer(node, path='input'):
    """Recursive forbidden-key scan over a builder input.

    /scrutinize 2026-07-30 measured the hole this closes. build_snapshot checked only for a
    top-level `verdict`, so an input whose `meta.reconciliation` carried `reconciliation_clear: true` was
    ACCEPTED under NO_SCHEMA_CHECK and a verdict computed for it -- the supplied answer silently
    ignored rather than refused. Part 1's guarantee ("a supplied answer has nowhere to sit") was
    therefore resting entirely on the closed schema, while the pre-commit computation suite runs
    every one of its fixtures with the schema gate skipped, so nothing in the fast tier was
    enforcing it at all.

    A recursive scan rather than two more `if` statements, for the reason SafeProjection's
    forbidden-key scan is recursive: the next place somebody puts the answer is a place nobody
    enumerated.
    """
    if isinstance(node, dict):
        for key, value in node.items():
            if key in SUPPLIED_ANSWER_KEYS:
                _refuse('%s.%s is present in a builder input. `%s` is written only by this '
                        'validator; a supplied answer is refused rather than overwritten, '
                        'because overwritten and honoured look identical afterwards.'
                        % (path, key, key))
            _refuse_supplied_answer(value, '%s.%s' % (path, key))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            _refuse_supplied_answer(item, '%s[%d]' % (path, i))


def build_snapshot(inp, schema_validator):
    """SnapshotBuilderInput -> ControlRoomSnapshotV5 with the verdict COMPUTED.

    `schema_validator` is required and has no default: pass a callable(instance, entity) that
    raises on an invalid instance, or the sentinel NO_SCHEMA_CHECK. See the module docstring
    for why there is no default.
    """
    if _resolve_gate(schema_validator) is not NO_SCHEMA_CHECK:
        schema_validator(inp, BUILDER_ENTITY)
    if not isinstance(inp, dict) or inp.get('entity') != BUILDER_ENTITY:
        _refuse('build_snapshot expects entity=%r, got %r' % (
            BUILDER_ENTITY, (inp or {}).get('entity') if isinstance(inp, dict) else inp))
    _refuse_supplied_answer(inp)

    reconciliation_clear, reasons = compute(inp)

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
    out['verdict'] = {'reconciliation_clear': reconciliation_clear, 'reasons': _as_reason_objects(reasons)}
    return out


def verify_snapshot(doc, schema_validator):
    """Recompute the verdict from a PERSISTED document; refuse it if the stored one differs.

    This is the defence against a hand-authored output. It does not ask whether the document
    is well-formed -- the schema does that -- it asks whether the document's answer is the
    answer its own evidence produces.
    """
    if _resolve_gate(schema_validator) is not NO_SCHEMA_CHECK:
        schema_validator(doc, OUTPUT_ENTITY)
    if not isinstance(doc, dict) or doc.get('entity') != OUTPUT_ENTITY:
        # MalformedDocument, not a plain refusal: valid JSON that is not one of these documents
        # carries no coverage data at all, which is a different finding from a document whose
        # numbers do not add up, and the two must reach a reader as different codes.
        raise MalformedDocument('verify_snapshot expects entity=%r, got %r' % (
            OUTPUT_ENTITY, (doc or {}).get('entity') if isinstance(doc, dict) else doc))
    stored = doc.get('verdict')
    if not isinstance(stored, dict) or 'reconciliation_clear' not in stored or 'reasons' not in stored:
        _refuse('the persisted document carries no usable `verdict` to check')

    reconciliation_clear, reasons = compute(doc)
    problems = []

    # Codex audit 6 (MAJOR 3, reproduced): this used to compare bool(stored) with bool(computed),
    # so `reconciliation_clear: "yes"` verified clean -- every non-empty string is truthy. Coercion at a trust
    # boundary reads the author's typo as the author's intent.
    if not isinstance(stored['reconciliation_clear'], bool):
        _refuse('verdict.reconciliation_clear is %r (%s), not a boolean. This is refused rather than coerced: '
                'bool("no") is True, so coercion here would read any string as a clear verdict.'
                % (stored['reconciliation_clear'], type(stored['reconciliation_clear']).__name__))
    if stored['reconciliation_clear'] is not bool(reconciliation_clear):
        problems.append('verdict.reconciliation_clear is %r but the evidence in this document computes '
                        '%r' % (stored['reconciliation_clear'], bool(reconciliation_clear)))

    # Counter, not set. MEASURED 2026-07-30 (/scrutinize): with sets, a document that listed the
    # same reason three times verified clean, because set equality collapses the duplicates. The
    # reason list is what a reader COUNTS to say "3 sources are missing", so a document that
    # triples one reason misstates its own evidence while agreeing with the boolean.
    stored_pairs = collections.Counter()
    for r in (stored['reasons'] or []):
        if not isinstance(r, dict):
            _refuse('verdict.reasons contains a non-object entry: %r' % (r,))
        stored_pairs[(r.get('code'), r.get('detail'))] += 1
    computed_pairs = collections.Counter(reasons)
    if stored_pairs != computed_pairs:
        def _render(counter):
            out = []
            for pair, n in sorted(counter.items()):
                out.append('%s:%s' % pair + ('' if n == 1 else ' (x%d)' % n))
            return out
        invented = _render(stored_pairs - computed_pairs)
        omitted = _render(computed_pairs - stored_pairs)
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
        if derived is not None and not isinstance(row.get('fresh'), bool):
            _refuse('meta.sources[%r].fresh is %r (%s), not a boolean -- refused rather than '
                    'coerced, for the same reason as verdict.reconciliation_clear'
                    % (row['name'], row.get('fresh'), type(row.get('fresh')).__name__))
        if derived is not None and row.get('fresh') is not bool(derived):
            problems.append('meta.sources[%r].fresh is %r but age_hours=%r against '
                            'stale_bar_hours=%r derives %r'
                            % (row['name'], bool(row.get('fresh')), row.get('age_hours'),
                               f.stale_bar_hours, derived))

    if problems:
        raise VerdictMismatch(
            'this document\'s stored verdict does not match its own evidence:\n  - '
            + '\n  - '.join(problems))
    return doc


def load_verified(path):
    """The only sanctioned way for a reader to obtain a snapshot. Wiring readers is S4.

    Takes NO validator parameter, per Codex audit 6: this is the PUBLIC trust boundary, and a
    boundary that lets its caller choose whether to check is not a boundary. The skip stays
    available on build_snapshot/verify_snapshot, which are the internal computation entry points
    the fast suite drives; a reader gets the checked path or writes its own, and writing its own
    is at least visible in a diff.
    """
    try:
        with io.open(path, encoding='utf-8-sig') as fh:  # snapshot: worktree
            doc = json.load(fh)
    except ValueError as exc:
        raise MalformedDocument('%s is not parseable JSON, so there is no document to verify: %s'
                                % (path, exc))
    except (IOError, OSError) as exc:
        # The file is there and could not be opened. That is the instrument, not the document.
        raise ToolFailure('%s could not be opened: %s' % (path, exc))
    return verify_snapshot(doc, ajv_schema_validator)


# ---------------------------------------------------------------------------------------
# The optional ajv gate. Lives here so callers do not each grow their own copy, and is not
# invoked by the fast tier -- see the module docstring on the budget.

def _describe_ajv_errors(out, entity):
    """Render ajv's errors as `keyword at 'instancePath' -> property`.

    No filtering, deliberately. The first version tried to pick out the errors "about this entity"
    by looking for the entity name in schemaPath, because validating against the 19-branch root
    produced ~20 errors from unrelated branches. That heuristic could not work -- a NESTED failure
    lives under #/$defs/ReconciliationEvidence, not under the builder's own $def, so the filter
    dropped exactly the errors worth reading and fell back to the noise. _focused_schema() removes
    the noise at the source instead, which leaves nothing here to be clever about: every error ajv
    returns is now about the instance. Removing the heuristic is part of the fix, not a tidy-up.
    """
    match = re.search(r'\[\{.*\}\]', out, re.S)
    if not match:
        return out.splitlines()[0] if out else '<no output>'
    try:
        errors = json.loads(match.group(0))
    except ValueError:
        return out.splitlines()[0]
    parts = []
    for e in errors[:4]:
        params = e.get('params') or {}
        named = (params.get('missingProperty') or params.get('unevaluatedProperty')
                 or params.get('additionalProperty') or '')
        parts.append('%s at %r%s' % (e.get('keyword'), e.get('instancePath', ''),
                                     ' -> ' + named if named else ''))
    return '; '.join(parts)


def _focused_schema(entity):
    """The real schema with its 19-branch `oneOf` replaced by a `$ref` to ONE entity.

    Codex audit 6 (MAJOR 3, sub-finding): validating against the root means ajv reports the first
    error from every branch, so the refusal for `duplicates: -1` read
    "required at '' -> owner_type; ... hypothesis_id; ... universe_version" and never named
    `duplicates` or `minimum`. _describe_ajv_errors tried to filter that heuristically by looking
    for the entity name in schemaPath, which cannot work for a NESTED failure: the error lives
    under #/$defs/ReconciliationEvidence, not under #/$defs/SnapshotBuilderInput.

    The fix is the one the audit recommended -- do not filter the noise, do not generate it. This
    gate already knows which entity it expects (it asserts it below), so it validates against that
    $def directly and every error is about the instance.

    Discriminator coverage is NOT lost: the root `required: [entity]` and the `entity` enum are
    kept, and the explicit equality check below is stricter than oneOf. run_schema_fixtures.py
    still validates against the real root, which is where the discriminator belongs.
    """
    with io.open(SCHEMA_PATH, encoding='utf-8') as fh:  # snapshot: worktree
        schema = json.load(fh)
    schema.pop('oneOf', None)
    schema.pop('$id', None)          # a derived schema must not claim the canonical id
    schema['$ref'] = '#/$defs/%s' % entity
    return schema


def ajv_schema_validator(instance, entity):
    """callable(instance, entity) for build_snapshot/verify_snapshot. Raises on invalid."""
    if not isinstance(instance, dict) or instance.get('entity') != entity:
        # MalformedDocument, for the reason given on that class: this gate runs BEFORE
        # verify_snapshot's own entity check, so leaving it as a plain refusal here made that
        # check unreachable and collapsed "not one of these documents" back into "refused".
        raise MalformedDocument('expected entity=%r, got %r'
                                % (entity, instance.get('entity')
                                   if isinstance(instance, dict) else instance))
    fd, path = tempfile.mkstemp(suffix='.json')
    sfd, spath = tempfile.mkstemp(suffix='.schema.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as fh:
            json.dump(instance, fh)
        try:
            with os.fdopen(sfd, 'w', encoding='utf-8') as fh:
                json.dump(_focused_schema(entity), fh)
        except (IOError, OSError, ValueError) as exc:
            # Cannot read/derive the schema is a TOOL failure, never a verdict on the instance.
            raise ToolFailure('could not run: the schema could not be read or derived (%s)'
                              % exc)
        p = subprocess.run(['ajv', 'validate', '-s', spath, '-d', path,
                            '--spec=draft2020', '--strict=false', '--errors=line'],
                           capture_output=True, text=True, shell=True)
        out = (p.stdout + p.stderr).strip()
        if p.returncode == 0:
            return instance
        # Same three-state discipline as run_schema_fixtures.py: a tool failure is NOT a
        # rejection. Reporting "invalid" when ajv is simply absent is how a suite reports
        # 14 of 17 cases OK with the schema file deleted.
        if p.returncode == 1 and ' invalid' in out:
            # /scrutinize 2026-07-30: this used to report out.splitlines()[0], which is ajv's
            # "<tempfile> invalid" line and names nothing. The caller then had a refusal that did
            # not say WHAT was wrong, about an instance in a temp file that is already deleted.
            _refuse('%s failed schema validation: %s' % (entity, _describe_ajv_errors(out, entity)))
        raise ToolFailure('ajv could not run, so nothing was validated (exit %s): %s'
                          % (p.returncode, out.splitlines()[0] if out else '<no output>'))
    finally:
        for tmp in (path, spath):
            try:
                os.unlink(tmp)
            except OSError:
                pass


USAGE = 'usage: python _triage/factory_os/snapshot_validator.py verify <path-to-snapshot.json>'


def main(argv):
    if len(argv) != 3 or argv[1] != 'verify':
        # A literal, not __doc__.strip().splitlines()[-2]. That indexed a specific line of the
        # docstring and would have printed an unrelated sentence the moment anyone added a line
        # to it -- a usage message that silently stops being the usage.
        print(USAGE)
        return 2
    try:
        load_verified(argv[2])
    except MalformedDocument as exc:
        print('[MALFORMED] %s' % exc)
        return 4
    except ToolFailure as exc:
        # Exit 3, and it must stay distinct from 1. A reader that cannot tell "the checker did not
        # run" from "the document was refused" will report an uninstalled tool as a bad snapshot --
        # or, worse, treat a real refusal as a tooling hiccup and render it anyway.
        print('[TOOL-FAILURE] %s' % exc)
        return 3
    except SnapshotRefusal as exc:
        print('[REFUSED] %s' % exc)
        return 1
    print('[OK] %s: stored verdict matches the verdict recomputed from its own evidence'
          % argv[2])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
