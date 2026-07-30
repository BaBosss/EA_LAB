"""
run_snapshot_validator_tests.py - ORDER-601 part 2. The computation suite for
snapshot_validator, plus the mutation analysis that decides whether this suite is real.

WHAT MAKES THIS DIFFERENT FROM run_schema_fixtures.py
  That suite asks "does ajv accept this instance". This one asks "is the verdict the CORRECT
  verdict" -- which is not a schema property and cannot be. Keeping them apart is deliberate:
  claiming the schema suite covers the computation is the "x-enforced-by names a validator
  nobody wrote" defect, and this repo has shipped it.

THE FIVE DISCIPLINES, from ORDER-601, and how each is mechanised here
  1. ONE-FIELD MINIMAL PAIR. Every negative is a declared delta from a known-good positive.
     A negative that is also broken in an unrelated way gets credited to the rule it names
     while never reaching it -- and with a boolean-returning harness you cannot tell.
  2. ASSERT THE REASON. Each negative declares the exact (code, detail) set it must produce.
     "It was rejected" is not an assertion; every negative is rejected by something.
  3. PAIRED REPAIR. Each negative declares a REPAIR DELTA, applied to the BROKEN instance --
     not a revert to the base object. Reverting to the base and finding it healthy proves
     only that the base is healthy. Applying the stated repair proves the negative was broken
     in exactly the one way it claims, because anything else left behind stays red.
  4. REFUSAL IS A THIRD STATE. An input the validator cannot decide must RAISE, and a raise
     satisfies no verdict expectation. "Cannot tell" collapsing into "all clear" is the
     defect class this repo pays for most often.
  5. MUTATION ANALYSIS, RUN ON EVERY INVOCATION. Each predicate is disabled in turn and the
     set of fixtures that go red must EQUAL the set that declared a dependency on it. A
     predicate whose removal reddens nothing is not tested, and a fixture that reddens for a
     predicate it never named is not the minimal pair it claims to be. --write-table emits
     the artifact; the assertion itself is not optional.

PROVING THE HARNESS CAN FAIL
  A mutation harness that reports success unconditionally is worth less than no harness,
  because it looks like one. `--prove-harness` plants a predicate that no fixture exercises
  and asserts the analysis NAMES it. Run it; it is two seconds and it is the only reason to
  believe the table below.

USAGE  python _triage/factory_os/run_snapshot_validator_tests.py [--write-table] [--prove-harness]
EXIT   0 = every case and every mutation behaved as declared - 1 = at least one did not
"""
import ast
import collections
import copy
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import snapshot_validator as SV  # noqa: E402

SCHEMA_PATH = '_triage/factory_os/schemas.json'
TABLE_PATH = '_triage/factory_os/SNAPSHOT_VALIDATOR_MUTATION_TABLE.md'

NC = SV.NO_SCHEMA_CHECK


def clone(x):
    return json.loads(json.dumps(x))


# ---------------------------------------------------------------------------------------
# POSITIVE 1. Two mandatory sources, so "one of them is missing" is expressible as a delta
# rather than as an empty array (which is also tested, separately, as its own attack).

def row(name, mandatory=True, read_ok=True, fresh=True, age_hours=1.0, **compat):
    r = {'name': name, 'mandatory': mandatory, 'read_ok': read_ok, 'fresh': fresh,
         'age_hours': age_hours}
    r.update(compat)
    return r


EV_1 = {
    'discovered': 3, 'categorized': 3,
    'categories': {'actionable': 0, 'running': 1, 'waiting': 1, 'review_audit': 0,
                   'completed': 1, 'cancelled_by_user': 0},
    'coverage': {'cells_in_universe': 4, 'tested': 2, 'untested': 2, 'not_applicable': 0},
    'duplicates': 0, 'conflicts': 0, 'unclassified': 0,
}

BASE = {
    'entity': SV.BUILDER_ENTITY,
    'meta': {
        'schema': 'ControlRoomSnapshot', 'version': 5, 'build_id': 'B-0001',
        'generated_at': '2026-07-30T00:00:00Z',
        'stale_bar_hours': 26, 'decision_bar_trades': 30,
        'counting_method': 'MT5 cumulative deals, entry=1 rows per magic',
        'mandatory_sources': ['live_deals', 'dashboard'],
        'sources': [row('live_deals', age_hours=1.0), row('dashboard', age_hours=2.0)],
        'reconciliation': EV_1,
    },
    'system_health': [], 'floating_risk': [], 'deployments': {}, 'unknown_magics': [],
    'attestation': [], 'judge_readiness': [], 'judge_cohorts': {}, 'summary': {},
}

# POSITIVE 2, constructed independently rather than derived from POSITIVE 1: different
# non-zero counts on every axis, a different staleness bar, the registry and the source array
# in DIFFERENT orders, and a legitimate optional source that is absent from the registry.
# ORDER-601: one positive only rules out a constant-false implementation. Two rule out an
# implementation that memorised the first.
BASE_2 = {
    'entity': SV.BUILDER_ENTITY,
    'meta': {
        'schema': 'ControlRoomSnapshot', 'version': 6, 'build_id': 'B-9902',
        'generated_at': '2026-07-31T12:00:00Z', 'git_head': 'abc1234',
        'stale_bar_hours': 12.5, 'decision_bar_trades': 12, 'counting_method': 'MT4 orders csv',
        'mandatory_sources': ['dashboard', 'attestation', 'live_deals'],
        'sources': [row('attestation', age_hours=12.5), row('live_deals', age_hours=0.25),
                    row('aux_notes', mandatory=False, age_hours=400.0, fresh=False),
                    row('dashboard', age_hours=3.0)],
        'reconciliation': {
            'discovered': 7, 'categorized': 7,
            'categories': {'actionable': 0, 'running': 2, 'waiting': 3, 'review_audit': 1,
                           'completed': 1, 'cancelled_by_user': 0},
            'coverage': {'cells_in_universe': 9, 'tested': 5, 'untested': 3,
                         'not_applicable': 1},
            'duplicates': 0, 'conflicts': 0, 'unclassified': 0,
        },
    },
    'system_health': [{'x': 1}], 'floating_risk': [], 'deployments': {'rows': []},
    'unknown_magics': [], 'attestation': [], 'judge_readiness': [], 'judge_cohorts': {},
    'summary': {'orders': 7},
}

# A builder input carrying the REAL v4 source-row metadata (scripts/control_room_snapshot.ps1
# FileMeta returns {path, sha256, mtime, age_hours}) plus the three meta compatibility fields.
# Until part 2 these three row fields were not even expressible: the closed row schema had no
# place to put them, so "the boundary preserves them" could not be tested, let alone true.
BASE_COMPAT = clone(BASE)
BASE_COMPAT['meta']['sources'] = [
    row('live_deals', age_hours=1.0, path='portfolio\\DEPLOYMENTS.csv', sha256='a' * 64,
        mtime='2026-07-28T23:44:11'),
    row('dashboard', age_hours=2.0, path='portfolio\\dash.csv', sha256='b' * 64,
        mtime='2026-07-28T22:00:00'),
]


# ---------------------------------------------------------------------------------------
# Delta helpers. A delta is applied to a COPY and returns the whole instance, so a fixture's
# broken instance and its repaired instance are produced by the same machinery.

def at_meta(base, **kw):
    d = clone(base)
    d['meta'].update(kw)
    return d


def at_ev(base, **kw):
    d = clone(base)
    d['meta']['reconciliation'].update(kw)
    return d


def at_row(base, name, **kw):
    """Change EXISTING fields on one source row. Unknown field names are an error.

    MEASURED, in this file, before it was measured anywhere else: the first version took
    `age=26.1` and dict-updated it straight onto the row, which ADDED a key called `age` and
    left `age_hours` untouched. Four negatives were therefore identical to the healthy
    positive and computed reconciliation_clear=true, and the only reason it surfaced is that they
    asserted an exact reason set instead of "was rejected". A fixture builder that accepts a
    field the subject has never heard of manufactures probes that cannot fail, which is the
    one thing worse here than no probe at all.
    """
    d = clone(base)
    hit = False
    for r in d['meta']['sources']:
        if r['name'] != name:
            continue
        hit = True
        unknown = [k for k in kw if k not in r]
        if unknown:
            raise KeyError('source row %r has no field(s) %s -- refusing to invent one, '
                           'because a delta that lands nowhere leaves the fixture identical '
                           'to the positive it was derived from' % (name, sorted(unknown)))
        r.update(kw)
    if not hit:
        raise KeyError('no source row named %r to change' % name)
    return d


def drop_row(base, name):
    d = clone(base)
    d['meta']['sources'] = [r for r in d['meta']['sources'] if r['name'] != name]
    return d


def add_row(base, r):
    d = clone(base)
    d['meta']['sources'] = d['meta']['sources'] + [r]
    return d


# ---------------------------------------------------------------------------------------
# Fixtures.
#
# kind:
#   'verdict'  compute() over a builder input -> assert (reconciliation_clear, exact reason set)
#   'refusal'  compute()/build_snapshot() must RAISE SnapshotRefusal, message asserted
#   'output'   a hand-authored PERSISTED document -> verify_snapshot() must refuse
#   'roundtrip' build_snapshot() then verify_snapshot() must both succeed
#   'preserve' build_snapshot() must carry declared fields through unchanged
#
# depends_on: the reason codes whose REMOVAL must turn this fixture red. Declared per fixture
# and checked against measurement by the mutation analysis, so a wrong declaration here is a
# suite failure rather than a silent hole.

F = collections.namedtuple(
    'F', 'name kind guards instance expect_clear expect_reasons repair must_say depends_on')


def verdict(name, guards, instance, reasons, repair, depends_on=None):
    codes = set(c for c, _d in reasons)
    return F(name, 'verdict', guards, instance, not reasons, set(reasons), repair, None,
             codes if depends_on is None else set(depends_on))


def positive(name, guards, instance):
    return F(name, 'verdict', guards, instance, True, set(), None, None, set())


def refusal(name, guards, instance, must_say):
    return F(name, 'refusal', guards, instance, None, None, None, must_say, set())


def output(name, guards, doc, must_say, depends_on=()):
    return F(name, 'output', guards, doc, None, None, None, must_say, set(depends_on))


FIXTURES = [
    # ---- the two independently built healthy positives ------------------------------
    positive('healthy-positive-1', 'ORDER-601: two independent positives; one only blocks a '
             'constant-false implementation', BASE),
    positive('healthy-positive-2', 'ORDER-601: different counts on every axis, a different '
             'staleness bar, registry and sources in different orders, plus a legitimate '
             'optional source absent from the registry', BASE_2),

    # ---- the freshness boundary, both sides, one step apart --------------------------
    positive('stale-boundary-age-equals-bar', 'ORDER-601: age_hours must be varied ACROSS the '
             'supplied bar. age == bar is the oldest ACCEPTABLE age and must stay clear, or '
             'the bar means something other than what it says',
             at_row(BASE, 'dashboard', age_hours=26)),
    verdict('stale-boundary-one-step-over', 'ORDER-601: the same row one step past the bar',
            at_row(BASE, 'dashboard', age_hours=26.1),
            [(SV.MANDATORY_SOURCE_STALE, 'dashboard')],
            repair=lambda d: at_row(d, 'dashboard', age_hours=26.1 - 1.0)),
    verdict('stale-while-the-caller-says-fresh',
            'ORDER-601 + the prohibition on a caller-supplied `fresh`: this row is 400h old '
            'and asserts fresh=true. If the validator trusted the flag this would be clear',
            at_row(BASE, 'dashboard', age_hours=400.0, fresh=True),
            [(SV.MANDATORY_SOURCE_STALE, 'dashboard')],
            repair=lambda d: at_row(d, 'dashboard', age_hours=2.0)),

    # ---- the source registry ---------------------------------------------------------
    verdict('mandatory-source-missing',
            'ORDER-601: a registry entry with no row. FileMeta returns $null for a file that '
            'does not exist and the pipeline filters it out, so a missing source VANISHES '
            'from the array rather than appearing as a failure',
            drop_row(BASE, 'dashboard'),
            [(SV.MANDATORY_SOURCE_MISSING, 'dashboard')],
            repair=lambda d: add_row(d, row('dashboard', age_hours=2.0))),
    verdict('builder-sources-empty-attack-a',
            'ORDER-601 sources=[] attack (a): the builder input side. Computed false with '
            'MANDATORY_SOURCE_MISSING for every registry entry',
            at_meta(BASE, sources=[]),
            [(SV.MANDATORY_SOURCE_MISSING, 'live_deals'),
             (SV.MANDATORY_SOURCE_MISSING, 'dashboard')],
            repair=lambda d: at_meta(d, sources=[row('live_deals', age_hours=1.0),
                                                 row('dashboard', age_hours=2.0)])),
    # Codex audit 6 (MAJOR 4), reproduced: it replaced the membership predicate with a COUNT test
    # (`len(rows) >= len(mandatory) -> []`) and the entire suite AND the whole mutation table stayed
    # green, because every existing negative either drops a row or empties the array -- both of
    # which change the count. This fixture holds the count constant and swaps the identity, so a
    # count-based rewrite goes red. It is the one attack the mutation table structurally cannot see:
    # deleting a wrong predicate still reddens exactly the fixtures it declared.
    verdict('mandatory-source-swapped-for-an-optional-one-same-count',
            'Codex audit 6 MAJOR 4: same number of rows, one mandatory identity replaced by an '
            'unrelated optional name. A predicate that counts rows instead of checking membership '
            'passes everything else in this file',
            at_meta(BASE, sources=[row('live_deals', age_hours=1.0),
                                   row('aux_notes', mandatory=False, age_hours=2.0)]),
            [(SV.MANDATORY_SOURCE_MISSING, 'dashboard')],
            repair=lambda d: at_meta(d, sources=[row('live_deals', age_hours=1.0),
                                                 row('dashboard', age_hours=2.0)])),
    verdict('mandatory-source-unreadable',
            'ORDER-601: UNREADABLE must be a code of its own, not the same state as MISSING. '
            '"cannot read it" and "it is not there" have opposite fixes',
            at_row(BASE, 'dashboard', read_ok=False),
            [(SV.MANDATORY_SOURCE_UNREADABLE, 'dashboard')],
            repair=lambda d: at_row(d, 'dashboard', read_ok=True)),
    verdict('source-claims-mandatory-outside-the-registry',
            'ORDER-601 source identity: membership the other way. The registry is the '
            'authority; a row that promotes itself is a second copy of the fact',
            add_row(BASE, row('rogue', mandatory=True)),
            [(SV.SOURCE_REGISTRY_MISMATCH, 'rogue')],
            repair=lambda d: at_row(d, 'rogue', mandatory=False)),
    verdict('duplicate-source-name',
            'ORDER-601 source identity: uniqueItems cannot express "two objects with the same '
            'name", so this is the validator\'s job',
            add_row(BASE, row('dashboard', age_hours=2.0)),
            [(SV.DUPLICATE_SOURCE_NAME, 'dashboard')],
            # the delta was an appended row, so the repair removes exactly that row -- and
            # `drop_row` by name would remove BOTH copies, which would silently repair by
            # deleting a mandatory source instead
            repair=lambda d: at_meta(d, sources=d['meta']['sources'][:-1])),
    verdict('row-flag-contradicts-the-registry',
            'ORDER-601: a row whose own mandatory:false contradicts the registry. ORDER-601 '
            'prefers deleting the redundant flag, but the real v4 consumers read it, so until '
            'that migration a contradiction that cannot be REPORTED is one that ships',
            at_row(BASE, 'dashboard', mandatory=False),
            [(SV.SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY, 'dashboard')],
            repair=lambda d: at_row(d, 'dashboard', mandatory=True)),

    # ---- the arithmetic --------------------------------------------------------------
    verdict('discovered-not-equal-categorized', 'ORDER-601 acceptance: discovered != categorized',
            at_ev(BASE, discovered=4),
            [(SV.DISCOVERED_CATEGORIZED_MISMATCH, 'discovered=4 categorized=3')],
            repair=lambda d: at_ev(d, discovered=3)),
    verdict('category-sum-mismatch', 'ORDER-601 acceptance: the category sum must equal '
            'categorized, and the equation must be ENCODED rather than implied in prose',
            at_ev(BASE, categories={'actionable': 0, 'running': 1, 'waiting': 1,
                                    'review_audit': 0, 'completed': 2,
                                    'cancelled_by_user': 0}),
            [(SV.CATEGORY_SUM_MISMATCH, 'categorized=3 category_sum=4')],
            repair=lambda d: at_ev(d, categories=clone(EV_1['categories']))),
    verdict('coverage-sum-mismatch', 'ORDER-601 acceptance: coverage sum mismatch',
            at_ev(BASE, coverage={'cells_in_universe': 4, 'tested': 3, 'untested': 2,
                                  'not_applicable': 0}),
            [(SV.COVERAGE_SUM_MISMATCH, 'cells_in_universe=4 parts_sum=5')],
            repair=lambda d: at_ev(d, coverage=clone(EV_1['coverage']))),
    verdict('duplicates-present', 'ORDER-601 acceptance: duplicates > 0', at_ev(BASE, duplicates=1),
            [(SV.DUPLICATES_PRESENT, 'duplicates=1')], repair=lambda d: at_ev(d, duplicates=0)),
    verdict('conflicts-present', 'ORDER-601 acceptance: conflicts > 0', at_ev(BASE, conflicts=1),
            [(SV.CONFLICTS_PRESENT, 'conflicts=1')], repair=lambda d: at_ev(d, conflicts=0)),
    verdict('unclassified-present', 'ORDER-601 acceptance: unclassified > 0',
            at_ev(BASE, unclassified=1),
            [(SV.UNCLASSIFIED_PRESENT, 'unclassified=1')],
            repair=lambda d: at_ev(d, unclassified=0)),
    # ISOLATING this one needs a COMPENSATING move, not a single field: bumping actionable
    # alone also unbalances the category sum, and the fixture would then be credited to
    # ACTIONABLE_PRESENT while CATEGORY_SUM_MISMATCH did the rejecting. Reclassifying one item
    # from completed to actionable keeps every equation balanced, so the only thing left to
    # reject it is the predicate it names. Minimal in the sense that matters.
    verdict('actionable-present-with-every-equation-balanced',
            'ORDER-601: categories.actionable > 0 => false. Omitted from rev 1 although the '
            'schema states it. Balanced on purpose so it cannot be credited to the sum check',
            at_ev(BASE, categories={'actionable': 1, 'running': 1, 'waiting': 1,
                                    'review_audit': 0, 'completed': 0,
                                    'cancelled_by_user': 0}),
            [(SV.ACTIONABLE_PRESENT, 'actionable=1')],
            repair=lambda d: at_ev(d, categories=clone(EV_1['categories']))),

    # ---- refusals: an undecidable input must never become a verdict -------------------
    refusal('refuse-no-staleness-bar',
            'ORDER-601 prohibition: inventing a freshness threshold. With no bar supplied the '
            'verdict is not derivable, and "cannot tell" must not resolve to "all clear"',
            at_meta(BASE, stale_bar_hours=None), 'stale_bar_hours'),
    refusal('refuse-null-age-on-a-readable-source',
            'read_ok=true with age_hours=null: read, but of unknown age. Refused rather than '
            'reported STALE - "unknown age" and "too old" have different fixes',
            at_row(BASE, 'dashboard', age_hours=None), 'age_hours'),
    refusal('refuse-empty-registry',
            'an empty registry makes every missing source unexpected, which is how 0 == 0 '
            'produced an reconciliation_clear in the first place',
            at_meta(BASE, mandatory_sources=[]), 'mandatory_sources'),
    refusal('refuse-a-supplied-verdict',
            'the closed input schema refuses this too, but build_snapshot is reachable with '
            'NO_SCHEMA_CHECK, and a supplied verdict silently overwritten is '
            'indistinguishable from one that was honoured',
            dict(clone(BASE), verdict={'reconciliation_clear': True, 'reasons': []}), 'verdict'),
    # /scrutinize 2026-07-30. THE hole this review found: build_snapshot checked only for a
    # top-level `verdict`, so this instance was accepted and a verdict computed for it under
    # NO_SCHEMA_CHECK -- which is what every fixture in this file uses, so the fast tier was
    # enforcing part 1's central guarantee not at all. The closed schema does refuse it, but a
    # guarantee that holds only when the optional gate is on is not the guarantee that was claimed.
    refusal('refuse-all-clear-supplied-inside-the-evidence',
            'ORDER-601 part 1 made a supplied answer unrepresentable in the SCHEMA; this asserts '
            'the validator refuses it on its own, with the schema gate skipped',
            at_ev(BASE, reconciliation_clear=True), 'reconciliation_clear'),
    refusal('refuse-reasons-supplied-inside-the-evidence',
            'the same attack one word over: `reasons` is validator-owned too, and the next place '
            'somebody puts the answer is the place nobody enumerated',
            at_ev(BASE, reasons=[]), 'reasons'),
    refusal('refuse-a-non-integer-count',
            'a string where a count belongs must not be compared as a number',
            at_ev(BASE, discovered='3'), 'must be an integer'),
    # /scrutinize 2026-07-30. `at_row` cannot express this (it refuses unknown fields and this
    # DELETES a known one), so the row is rebuilt without it -- still a one-field delta.
    refusal('refuse-a-row-with-no-read_ok-field',
            'an ABSENT read_ok used to be reported as MANDATORY_SOURCE_UNREADABLE, which states '
            '"the file could not be read" about a collector that simply did not report. Rule 1 '
            'of the validator, running backwards',
            at_meta(BASE, sources=[row('live_deals', age_hours=1.0),
                                   {'name': 'dashboard', 'mandatory': True, 'fresh': True,
                                    'age_hours': 2.0}]),
            'no `read_ok` field at all'),
]


# ---- output-side fixtures: hand-authored PERSISTED documents ------------------------
# Built by taking a real validator output and editing it, so each one differs from a document
# that verifies by exactly the thing it is testing.

def persisted(base=BASE, **edits):
    doc = SV.build_snapshot(base, NC)
    for k, v in edits.items():
        doc[k] = v
    return doc


AUDIT5_ATTACK = SV.build_snapshot(BASE, NC)
AUDIT5_ATTACK['meta']['sources'] = []
AUDIT5_ATTACK['verdict'] = {'reconciliation_clear': True, 'reasons': []}

_TRIPLED_REASON = SV.build_snapshot(drop_row(BASE, 'dashboard'), NC)
# an HONEST verdict, then the one true reason repeated. Both the boolean and the reason SET
# still agree with the evidence; only the multiset does not.
_TRIPLED_REASON['verdict']['reasons'] = _TRIPLED_REASON['verdict']['reasons'] * 3

_STALE_LYING_ROW = SV.build_snapshot(at_row(BASE, 'dashboard', age_hours=400.0), NC)
# the verdict is CORRECT here; only the row's own derived field is falsified
for _r in _STALE_LYING_ROW['meta']['sources']:
    if _r['name'] == 'dashboard':
        _r['fresh'] = True

FIXTURES += [
    output('persisted-sources-empty-with-all-clear-true-attack-b',
           'ORDER-601 sources=[] attack (b), and audit 5\'s surviving instance: a complete '
           'persisted document, structurally valid against every schema here, whose verdict '
           'is simply typed. JSON Schema cannot prove authorship; only recomputation refuses '
           'this', AUDIT5_ATTACK,
           must_say=['reconciliation_clear', 'MANDATORY_SOURCE_MISSING'],
           depends_on=[SV.MANDATORY_SOURCE_MISSING]),
    output('persisted-verdict-invents-a-reason',
           'the mismatch must name reasons the document does NOT produce, not merely count '
           'them', persisted(verdict={'reconciliation_clear': False,
                                      'reasons': [{'code': SV.CONFLICTS_PRESENT,
                                                   'detail': 'conflicts=9'}]}),
           must_say=['does not produce', SV.CONFLICTS_PRESENT]),
    output('persisted-verdict-false-with-no-reasons',
           'the schema says reasons is empty if and only if reconciliation_clear is true; this is the '
           'half of that the schema cannot check',
           persisted(verdict={'reconciliation_clear': False, 'reasons': []}),
           must_say=['reconciliation_clear']),
    output('persisted-verdict-triples-one-true-reason',
           '/scrutinize 2026-07-30: the comparison was set-based, so a document listing the same '
           'reason three times verified CLEAN. The reason list is what a reader counts to say '
           '"3 sources are missing", so tripling one misstates the evidence while agreeing with '
           'the boolean', _TRIPLED_REASON,
           # (x2), not (x3): three stored minus the one the evidence really produces. Asserting
           # x3 failed, which is the assertion doing its job -- the number in the message is the
           # SURPLUS, and a reader who saw x3 would think the document claimed three more than
           # it does. With MANDATORY_SOURCE_MISSING disabled the surplus becomes x3, which is
           # why this fixture still declares a dependency on it.
           must_say=['does not produce', '(x2)'],
           depends_on=[SV.MANDATORY_SOURCE_MISSING]),
    output('persisted-row-lies-about-its-own-freshness',
           'the verdict here is CORRECT (false, STALE) while the row still asserts fresh=true '
           'for every consumer that reads the row instead of the verdict. Derived fields are '
           'recomputed too, not just the headline boolean', _STALE_LYING_ROW,
           must_say=['fresh', 'stale_bar_hours']),
]


# ---------------------------------------------------------------------------------------
# Checking one fixture. Returns (ok, detail).

def check(f):
    try:
        if f.kind == 'verdict':
            clear, reasons = SV.compute(f.instance)
            if clear is not f.expect_clear:
                return False, 'reconciliation_clear=%r, expected %r' % (clear, f.expect_clear)
            got = set(reasons)
            if got != f.expect_reasons:
                return False, 'reasons %s, expected %s' % (
                    sorted('%s:%s' % p for p in got),
                    sorted('%s:%s' % p for p in f.expect_reasons))
            if f.repair is not None:
                rclear, rreasons = SV.compute(f.repair(f.instance))
                if not rclear:
                    return False, ('the stated repair did not make it clear again, so the '
                                   'negative was broken in more than the one way it claims: %s'
                                   % sorted('%s:%s' % p for p in rreasons))
            return True, ''

        if f.kind == 'refusal':
            try:
                SV.build_snapshot(f.instance, NC)
            except SV.SnapshotRefusal as exc:
                if f.must_say not in str(exc):
                    return False, 'refused, but the message never mentions %r: %s' % (
                        f.must_say, exc)
                return True, ''
            return False, 'produced a verdict for an input it cannot decide'

        if f.kind == 'output':
            try:
                SV.verify_snapshot(f.instance, NC)
            except SV.VerdictMismatch as exc:
                missing = [s for s in f.must_say if s not in str(exc)]
                if missing:
                    return False, 'refused, but the message never names %s: %s' % (missing, exc)
                return True, ''
            except SV.SnapshotRefusal as exc:
                return False, ('refused as UNDECIDABLE rather than as a verdict mismatch, so '
                               'this case never reached the recomputation: %s' % exc)
            return False, 'accepted a document whose verdict its own evidence contradicts'
    except SV.SnapshotRefusal as exc:
        return False, 'unexpected refusal: %s' % exc
    return False, 'unknown fixture kind %r' % f.kind


# ---------------------------------------------------------------------------------------
# The parts that are about the validator as a whole rather than about one input.

def check_codes_match_the_schema():
    with io.open(SCHEMA_PATH, encoding='utf-8') as fh:
        schema = json.load(fh)
    enum = set(schema['$defs']['SnapshotVerdict']['properties']['reasons']['items']
               ['properties']['code']['enum'])
    preds = set(SV.PREDICATES)
    problems = []
    for code in sorted(enum - preds):
        problems.append('the schema accepts reason %s but no predicate emits it - an '
                        'unreachable contract reads as a covered one' % code)
    for code in sorted(preds - enum):
        problems.append('predicate %s emits a code the closed enum rejects, so its own output '
                        'would not validate' % code)
    return problems


FIXTURE_IDENTIFIERS = sorted(set(
    ['B-0001', 'B-9902', 'live_deals', 'dashboard', 'attestation', 'aux_notes', 'rogue']
    + [f.name for f in FIXTURES]))


def check_no_test_only_identifiers():
    """ORDER-601 discipline 6: `build_id == "fixture-healthy"` passes everything cheaply."""
    with io.open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              'snapshot_validator.py'), encoding='utf-8') as fh:
        src = fh.read()

    # Scan EXECUTABLE source, not the whole file. The first version searched raw text, so it
    # flagged the word `attestation` the moment a docstring listed the top-level domains this
    # verdict does NOT cover -- a false positive that penalises explaining the scope, which is
    # the opposite of what should be encouraged. A docstring cannot special-case an input.
    # String literals OTHER than docstrings are still scanned, because `build_id == "fixture-x"`
    # is precisely a string literal, and that is the defect being hunted. `ast` drops comments
    # for free.
    tree = ast.parse(src)
    docstrings = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = getattr(node, 'body', None)
            if (body and isinstance(body[0], ast.Expr)
                    and isinstance(body[0].value, ast.Constant)
                    and isinstance(body[0].value.value, str)):
                docstrings.add(id(body[0].value))
    live_strings = [n.value for n in ast.walk(tree)
                    if isinstance(n, ast.Constant) and isinstance(n.value, str)
                    and id(n) not in docstrings]
    live_names = [n.id for n in ast.walk(tree) if isinstance(n, ast.Name)]
    live_names += [n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)]
    haystack = live_strings + live_names
    problems = ['snapshot_validator.py uses the fixture identifier %r in executable code' % ident
                for ident in FIXTURE_IDENTIFIERS
                if any(ident in h for h in haystack)]

    # The static scan only catches the literals THIS suite happens to use. The behavioural
    # check is the one that generalises: relabel every identity field and the verdict must be
    # bit-identical. A validator keyed on any name at all fails here.
    for f in FIXTURES:
        if f.kind != 'verdict':
            continue
        relabelled = clone(f.instance)
        relabelled['meta']['build_id'] = 'ZZ-relabelled-9999'
        relabelled['meta']['generated_at'] = '1999-01-01T00:00:00Z'
        try:
            before = SV.compute(f.instance)
            after = SV.compute(relabelled)
        except SV.SnapshotRefusal as exc:
            problems.append('%s: refused during the relabelling check: %s' % (f.name, exc))
            continue
        if before != after:
            problems.append('%s: the verdict changed when build_id/generated_at were '
                            'relabelled, so identity is reaching the logic' % f.name)
    return problems


def check_compat_fields_survive():
    """ORDER-601 acceptance: the boundary must PRESERVE the real v4 fields, not drop them."""
    out = SV.build_snapshot(BASE_COMPAT, NC)
    problems = []
    for key in ('stale_bar_hours', 'decision_bar_trades', 'counting_method'):
        if out['meta'].get(key) != BASE_COMPAT['meta'][key]:
            problems.append('meta.%s did not survive: %r -> %r'
                            % (key, BASE_COMPAT['meta'][key], out['meta'].get(key)))
    src_in = dict((r['name'], r) for r in BASE_COMPAT['meta']['sources'])
    src_out = dict((r['name'], r) for r in out['meta']['sources'])
    for name, r_in in src_in.items():
        for key in ('path', 'sha256', 'mtime'):
            if src_out.get(name, {}).get(key) != r_in[key]:
                problems.append('meta.sources[%r].%s did not survive: %r -> %r'
                                % (name, key, r_in[key], src_out.get(name, {}).get(key)))
    if out['entity'] != SV.OUTPUT_ENTITY:
        problems.append('the output entity is %r' % out['entity'])
    if out['verdict']['reconciliation_clear'] is not True:
        problems.append('the compat input should be healthy; got %r' % out['verdict'])
    # And the round trip: what build_snapshot writes must be what verify_snapshot accepts.
    # If these two ever disagree, every document this pipeline produces is unreadable by it.
    try:
        SV.verify_snapshot(out, NC)
    except SV.SnapshotRefusal as exc:
        problems.append('build_snapshot produced a document verify_snapshot refuses: %s' % exc)
    return problems


def check_roundtrip():
    problems = []
    for name, base in (('healthy-positive-1', BASE), ('healthy-positive-2', BASE_2)):
        out = SV.build_snapshot(base, NC)
        if out['verdict']['reconciliation_clear'] is not True or out['verdict']['reasons']:
            problems.append('%s: expected a clear verdict, got %r' % (name, out['verdict']))
            continue
        try:
            SV.verify_snapshot(out, NC)
        except SV.SnapshotRefusal as exc:
            problems.append('%s: its own output does not verify: %s' % (name, exc))
        if 'verdict' in base:
            problems.append('%s: the base input was mutated by build_snapshot' % name)
    return problems


# ---------------------------------------------------------------------------------------
# The mutation analysis.

ORIGINAL_PREDICATES = collections.OrderedDict(SV.PREDICATES)


def red_set_without(code, baseline):
    """Disable one predicate; return the names of the fixtures that stop behaving.

    `baseline` is explicit rather than read from ORIGINAL_PREDICATES, and that is not a style
    choice: the first version rebuilt from the import-time snapshot on every call, so
    --prove-harness planted its never-exercised predicate into a set nothing ever looked at.
    The self-proof reported BAD and the harness was correct -- the PROOF was broken. A proof
    that cannot see what it planted is the same class of thing it exists to detect.
    """
    SV.PREDICATES = collections.OrderedDict(
        (k, v) for k, v in baseline.items() if k != code)
    try:
        return set(f.name for f in FIXTURES if not check(f)[0])
    finally:
        SV.PREDICATES = collections.OrderedDict(ORIGINAL_PREDICATES)


def mutation_analysis(baseline=None):
    """-> (rows, problems). Each row: (code, declared, measured_red)."""
    baseline = ORIGINAL_PREDICATES if baseline is None else baseline
    rows, problems = [], []
    for code in baseline:
        declared = set(f.name for f in FIXTURES if code in f.depends_on)
        measured = red_set_without(code, baseline)
        rows.append((code, declared, measured))
        if not measured:
            problems.append('disabling %s turns NOTHING red: the predicate runs but nothing '
                            'in this suite depends on it, so it is not tested' % code)
        for extra in sorted(measured - declared):
            problems.append('disabling %s turns %s red, but that fixture never declared a '
                            'dependency on it - so it is not the minimal pair it claims, or '
                            'the declaration is wrong' % (code, extra))
        for missing in sorted(declared - measured):
            problems.append('%s declares it depends on %s, but disabling that predicate '
                            'leaves it green - the fixture does not exercise the rule it names'
                            % (missing, code))
    return rows, problems


def write_table(rows):
    lines = [
        '# snapshot_validator - mutation table',
        '',
        'GENERATED by `run_snapshot_validator_tests.py --write-table`. Do not hand-edit: the',
        'same analysis runs as an ASSERTION on every invocation of that suite, so a table',
        'edited to look better than the code would be contradicted on the next run.',
        '',
        'ORDER-601 discipline 5: each predicate is disabled in turn and only that predicate\'s',
        'own fixtures may go red. Two failures are being hunted at once -- **a predicate whose',
        'removal reddens nothing is not tested**, and **a fixture that reddens for a predicate',
        'it never named is not the minimal pair it claims to be** (it is also broken in some',
        'unrelated way, and was being credited to a rule it never reached).',
        '',
        'Positives appear in NO row: disabling a check cannot make a healthy input unhealthy.',
        'That is the asymmetry that makes this table readable -- every name below is a negative',
        'or an output-side attack.',
        '',
        '| predicate disabled | fixtures that go red (measured) | count |',
        '|---|---|---|',
    ]
    for code, _declared, measured in rows:
        lines.append('| `%s` | %s | %d |'
                     % (code, ' · '.join('`%s`' % n for n in sorted(measured)), len(measured)))
    lines += [
        '',
        '## What this table does NOT say',
        '',
        'It does not say the predicates are the RIGHT set. It says each one is load-bearing',
        'against this suite. Whether the thirteen together mean "all clear" is the design\'s',
        'claim, and the design is bound to the schema by `gen_design_contracts.py --check` --',
        'which is a different guard, deliberately.',
        '',
        'It also does not cover the two checks that are not predicates and therefore cannot be',
        'mutated this way: the refusal of an undecidable input (`assert_decidable`, which runs',
        'BEFORE any predicate precisely so that disabling one cannot silence it) and the',
        'recomputation of derived per-row `fresh` in `verify_snapshot`. Both have their own',
        'fixtures; neither appears above.',
        '',
    ]
    with io.open(TABLE_PATH, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines))
    return TABLE_PATH


def prove_harness_can_fail():
    """Plant a predicate no fixture exercises; the analysis MUST name it."""
    print('=== proving the mutation analysis can fail ===')
    planted = 'PLANTED_NEVER_EXERCISED'
    baseline = collections.OrderedDict(ORIGINAL_PREDICATES)
    baseline[planted] = lambda f: []
    try:
        _rows, problems = mutation_analysis(baseline)
    finally:
        SV.PREDICATES = collections.OrderedDict(ORIGINAL_PREDICATES)
    named = [p for p in problems if planted in p and 'NOTHING red' in p]
    if not named:
        print('  [BAD] the analysis did not notice a predicate with no fixture behind it.')
        print('        Every row of the committed table is worthless until this passes.')
        return 1
    print('  [OK ] the analysis named it: %s' % named[0])
    other = [p for p in problems if planted not in p]
    if other:
        print('  [BAD] it also reported %d unrelated problem(s), so the real suite is not '
              'clean: %s' % (len(other), other[0]))
        return 1
    print('  [OK ] and reported nothing else, so the real thirteen are all accounted for')

    # Codex audit 6 (MAJOR 4): --prove-harness proved only the "predicate with no fixture"
    # detector. The three mechanisms the mutation table cannot reach -- because they are not
    # predicates -- were verified once, by hand, in a throwaway script. A check that lives in
    # somebody's shell history is not a check. They are sabotaged here instead, and the assertion
    # is that each reddens AT LEAST ONE fixture; the exact counts are printed rather than pinned,
    # so adding a fixture does not turn this red for the wrong reason.
    print('\n=== proving the three NON-predicate mechanisms are not inert ===')
    saboteurs = [
        ('assert_decidable -> no-op (an undecidable input answers anyway)',
         'assert_decidable', lambda f: None),
        ('derive_fresh -> always fresh (a guard that is present but inert)',
         'derive_fresh', lambda f, row: True),
        ('verify_snapshot -> trusts whatever it is handed (recompute-on-read removed)',
         'verify_snapshot', lambda doc, sv: doc),
    ]
    failed = 0
    for label, attr, replacement in saboteurs:
        original = getattr(SV, attr)
        setattr(SV, attr, replacement)
        try:
            red = sorted(f.name for f in FIXTURES if not check(f)[0])
        finally:
            setattr(SV, attr, original)
        if not red:
            print('  [BAD] %s -> NOTHING went red. That mechanism is untested.' % label)
            failed += 1
        else:
            print('  [OK ] %s -> %d red (%s)' % (label, len(red), ', '.join(red[:3])
                                                 + ('...' if len(red) > 3 else '')))
    if failed:
        return 1
    baseline_red = sorted(f.name for f in FIXTURES if not check(f)[0])
    if baseline_red:
        print('  [BAD] after restoring, %d fixture(s) are still red: %s' % (len(baseline_red),
                                                                           baseline_red))
        return 1
    print('  [OK ] all three restored cleanly, so the sabotage did not leak')
    return 0


def main(argv):
    if '--prove-harness' in argv:
        return prove_harness_can_fail()

    print('=== snapshot_validator: is the verdict the CORRECT verdict? ===')
    print('validator: _triage/factory_os/snapshot_validator.py\n')
    bad = 0
    for f in FIXTURES:
        ok, detail = check(f)
        if not ok:
            bad += 1
        print('  [%s] %-52s %-9s (%s)' % ('OK ' if ok else 'BAD', f.name, f.kind, f.guards))
        if not ok:
            print('        -> %s' % detail)

    print('')
    for label, fn in (('reason codes match the closed schema enum', check_codes_match_the_schema),
                      ('no test-only identifier reaches the logic', check_no_test_only_identifiers),
                      ('v4 compatibility fields survive input -> output', check_compat_fields_survive),
                      ('build_snapshot output verifies as its own input', check_roundtrip)):
        problems = fn()
        print('  [%s] %s' % ('OK ' if not problems else 'BAD', label))
        for p in problems:
            print('        -> %s' % p)
        bad += len(problems)

    print('\n--- mutation analysis: disable each predicate, only its own fixtures may go red ---')
    rows, problems = mutation_analysis()
    for code, _declared, measured in rows:
        print('  [%s] %-46s %d fixture(s) red' % ('OK ' if measured else 'BAD', code,
                                                  len(measured)))
    for p in problems:
        print('        -> %s' % p)
    bad += len(problems)

    if '--write-table' in argv:
        print('\n[WROTE] %s' % write_table(rows))

    total = len(FIXTURES) + len(rows)
    print('\n=== %s ===' % ('ALL %d FIXTURES AND %d MUTATIONS BEHAVED AS DECLARED'
                            % (len(FIXTURES), len(rows)) if bad == 0
                            else '%d PROBLEM(S) ACROSS %d CHECKS' % (bad, total)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
