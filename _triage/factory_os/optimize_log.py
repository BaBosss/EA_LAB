# -*- coding: utf-8 -*-
"""optimize_log.py -- ORDER-1253 (slice S13). The shape of an `optimize_guard` decision record.

WHY THIS MODULE EXISTS AT ALL
-----------------------------
Design 8.6 item 6 asks for `optimize_guard` "observed refusing at least one real case", and
CLAUDE.md's rule is blunter: **a guard with zero real fires is `UNTESTED`**. Until ORDER-1253 the
guard wrote its verdicts to the console and lost them, so there was nothing an acceptance checker
could read even after a real sweep had been judged. `scripts/optimize_guard.ps1` now appends one
JSON object per submission; this module is the ONE place that says what such an object must
contain.

THE WRITER IS POWERSHELL AND THE READER IS PYTHON, WHICH IS A SEAM
------------------------------------------------------------------
Two languages cannot share a constant, so the shape is necessarily stated twice -- once by the
writer that builds the hashtable and once by `REQUIRED` below. That is exactly the arrangement
this repo has been burned by (a rule written down in two places is one rule and one liability),
so the two ends are NOT bound by this docstring: `scripts/_test/run_optimize_guard_tests.ps1`
RUNS the real guard into a temp file and hands the result to `parse()`. If the writer drops a
field or renames one, that case goes red. A cage that drove only this module would prove only
this module (memory `pure-cage-proves-only-the-pure-half`).

THIS MODULE READS NOTHING FROM DISK, ON PURPOSE
-----------------------------------------------
`parse()` takes TEXT. The caller owns the read and therefore owns which snapshot it read -- in
`check_pilot_acceptance` that is the evidence source, so the checker judges the COMMIT rather
than whatever happens to be lying in the worktree.

REFUSAL, NOT SKIPPING
---------------------
A line that will not parse, or a record missing a required field, raises `LogRefusal`. A decision
log that silently drops the rows it cannot read would answer "was the guard ever observed
refusing?" from a subset it chose itself -- and it would answer in the flattering direction,
because the rows it drops are the ones it did not understand (memory
`unreadable-input-must-refuse-not-skip`).
"""

import json

# The result vocabulary is CLOSED. `NOTHING_TO_CHECK` is a real outcome the writer emits -- a
# submission that named no sweep dimension -- and it exists so that "the guard refused nothing"
# and "the guard was never asked anything" cannot be the same reading of the same file.
RESULTS = ('ALLOW', 'REFUSE', 'NOTHING_TO_CHECK')

# Per-record. `lane` is here because design 8.6 item 9 is "every run carries lane + data
# fingerprint": a decision record that cannot name the install it authorised is not evidence
# about any particular install, and the guard refuses to write one.
REQUIRED = (
    'record_version',
    'submitted_utc',
    'lane',
    'hypothesis_revision',
    'result',
    'checked',
    'allow_count',
    'refuse_count',
    'dimensions',
    'exit_code',
)

# Per-dimension. `binding` is the resolver's answer kept as FIELDS rather than left inside the
# fact prose: asking "did the binding layer refuse this" of a free-text blob is the shape
# ORDER-1251 exists to repair, and it is not worth building a second instance of it here.
DIMENSION_REQUIRED = ('name', 'verdict', 'facts')

SUPPORTED_VERSION = 1

# M1-A A-F6 (2026-08-20). ARTEFACT IDENTITY -- the join key that ties a decision record back to
# the exact .ini sweep-configuration it judged, so a decision is not merely "some submission that
# happened", it is THIS submission, about THIS file.
#
# WHY NOT `hypothesis_revision` OR `lane` ALONE. Measured against the committed log: one
# `hypothesis_revision` (e.g. `B14-H01-r1`) covers every symbol x TF sweep of that revision --
# 13 of the 18 committed records share just two revision strings -- and `lane` names the whole MT5
# install, shared by all 18. Neither distinguishes one submission's ARTEFACT from another's; using
# either as a join key would be exactly the shape memory `identity-fields-that-do-not-identify-the-
# run` warns about -- a field that looks like an identifier but does not.
#
# `expert` + `ini_path` are the two fields the writer (scripts/optimize_guard.ps1) ALREADY emits
# that name the specific build and the specific .ini file the decision read. Verified against all
# 18 committed records in factory/optimize_decisions.jsonl: (lane, expert, ini_path) is unique on
# every one of them -- 18 records, 18 distinct keys.
#
# THIS IS A PATH IDENTITY, NOT A BYTE IDENTITY, AND THE LIMIT IS NAMED RATHER THAN HIDDEN. The
# writer does not hash the .ini's bytes the way scripts/lib/pilot_run.ps1's
# Get-PilotXmlArtefactVerdict does for the optimizer XML (A-F7) -- `ini_path` only proves the
# decision NAMED this file, not that the file's bytes at decision time are the bytes a later reader
# finds at the same path. Closing that residual gap needs the writer to record a digest, and
# scripts/optimize_guard.ps1 is out of this lane's owned path family (never touched by M1-A's P0
# commits) -- so ARTEFACT_KEY_FIELDS is the strongest join buildable from what the writer emits
# today, and `artefact_key_collisions` below is the mechanical check that the path-identity is
# actually holding (no two DIFFERENT decisions are silently sharing one key).
ARTEFACT_KEY_FIELDS = ('lane', 'expert', 'ini_path')


class LogRefusal(Exception):
    """The log could not be read as a log. Never a verdict about the guard."""


class ArtefactKeyError(Exception):
    """A record cannot be joined to the artefact it judged -- it is missing one of
    ARTEFACT_KEY_FIELDS. Raised rather than silently building a partial key: a key with a hole
    filled by `None` would still compare equal to another hole-filled key, which is the same
    "I cannot check" -> "checked, fine" shape memory `guard-disarmed-by-prose-reported-as-note`
    names, one field down from candidate.py's C9."""


def parse(text, where='factory/optimize_decisions.jsonl'):
    """-> [record]. Raises LogRefusal on anything it cannot read as a decision record."""
    records = []
    for n, line in enumerate((text or '').split('\n'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except ValueError as exc:
            raise LogRefusal('%s line %d is unparseable: %s' % (where, n, exc))
        if not isinstance(rec, dict):
            raise LogRefusal('%s line %d is a %s, not a decision record'
                             % (where, n, type(rec).__name__))
        missing = [f for f in REQUIRED if f not in rec]
        if missing:
            raise LogRefusal('%s line %d is missing required field(s): %s'
                             % (where, n, ', '.join(missing)))
        if rec.get('record_version') != SUPPORTED_VERSION:
            # Fail closed. A future writer version may mean the SAME key with a different meaning,
            # and reading it under today's rules is how a checker reports a number it did not
            # understand as a number it did.
            raise LogRefusal('%s line %d is record_version=%r; this reader understands %d only'
                             % (where, n, rec.get('record_version'), SUPPORTED_VERSION))
        if rec.get('result') not in RESULTS:
            raise LogRefusal('%s line %d has result=%r, which is not one of %s'
                             % (where, n, rec.get('result'), ', '.join(RESULTS)))
        if not isinstance(rec.get('lane'), str) or not rec['lane'].strip():
            raise LogRefusal('%s line %d names no lane. The guard refuses to write one, so a '
                             'record without a lane was not written by the guard.' % (where, n))
        dims = rec.get('dimensions')
        if not isinstance(dims, list):
            raise LogRefusal('%s line %d has dimensions=%s, which is not a list'
                             % (where, n, type(dims).__name__))
        for d in dims:
            if not isinstance(d, dict):
                raise LogRefusal('%s line %d holds a dimension that is a %s, not an object'
                                 % (where, n, type(d).__name__))
            dmissing = [f for f in DIMENSION_REQUIRED if f not in d]
            if dmissing:
                raise LogRefusal('%s line %d dimension %r is missing %s'
                                 % (where, n, d.get('name'), ', '.join(dmissing)))
            if d.get('verdict') not in ('ALLOW', 'REFUSE'):
                raise LogRefusal('%s line %d dimension %r has verdict=%r'
                                 % (where, n, d.get('name'), d.get('verdict')))
        # THE COUNTS AND THE LIST MUST AGREE. The writer derives both from the same variables, so
        # they can only disagree in a record nobody's guard produced -- and this repo has a
        # section of its own design (8.4) whose whole lesson is a count and a list that disagreed
        # "in one section, with nothing able to notice". A reader that trusts `refuse_count`
        # while a reader that trusts `dimensions` disagrees is two answers to one question.
        # Verified against all 11 live records before this was added: zero disagreements, so it
        # is a floor under the current writer rather than a rule the store already breaks.
        allow = sum(1 for d in dims if d.get('verdict') == 'ALLOW')
        refuse = sum(1 for d in dims if d.get('verdict') == 'REFUSE')
        for field, counted in (('allow_count', allow), ('refuse_count', refuse),
                               ('checked', len(dims))):
            if rec.get(field) != counted:
                raise LogRefusal('%s line %d says %s=%r but lists %d matching dimension(s). A '
                                 'count that disagrees with the list it summarises makes the '
                                 'answer depend on which one the reader trusts.'
                                 % (where, n, field, rec.get(field), counted))
        records.append(rec)
    return records


def refused_dimensions(rec):
    """-> [dimension] that the guard actually refused in this submission."""
    return [d for d in rec.get('dimensions', []) if d.get('verdict') == 'REFUSE']


def allowed_dimensions(rec):
    return [d for d in rec.get('dimensions', []) if d.get('verdict') == 'ALLOW']


def real_refusals(records):
    """Submissions where the guard REFUSED at least one dimension.

    `result == 'REFUSE'` alone is NOT the test: -WarnOnly makes the exit code 0 while the
    dimension verdicts stay REFUSE, and the question 8.6 asks is whether the guard was observed
    REFUSING, not whether a caller chose to let the exit code through.
    """
    return [r for r in records if refused_dimensions(r)]


def real_allows(records):
    """Submissions where the guard ALLOWED at least one dimension and refused none.

    THIS HALF IS NOT DECORATION. A guard that refuses everything also "refuses at least one real
    case", so the refusal evidence alone cannot distinguish a working guard from a broken-closed
    one. 8.6 item 6 asks for both directions and this is the ALLOW direction, measured on real
    submissions rather than on the fixture suite.
    """
    return [r for r in records if allowed_dimensions(r) and not refused_dimensions(r)]


def artefact_key(record):
    """-> (lane, expert, ini_path): the join key tying `record` to the artefact it judged.

    Raises ArtefactKeyError, never builds a key with a hole in it, if any of ARTEFACT_KEY_FIELDS is
    absent or blank -- a caller that wants "every record, best effort" must catch it per-record and
    say so, the way `artefact_key_collisions` below does; a caller must never receive a key that
    silently stands in for "cannot tell".
    """
    missing = [f for f in ARTEFACT_KEY_FIELDS if not record.get(f)]
    if missing:
        raise ArtefactKeyError(
            'decision record (hypothesis_revision=%r, submitted_utc=%r) names no %s, so it cannot '
            'be tied to the artefact it judged'
            % (record.get('hypothesis_revision'), record.get('submitted_utc'), ', '.join(missing)))
    return tuple(record[f] for f in ARTEFACT_KEY_FIELDS)


def _verdict_signature(rec):
    """-> a hashable summary of WHAT the guard decided, for comparing two records that share one
    artefact_key. Built from `result` and the (name, verdict) pairs, sorted so two records that
    list the same dimensions in a different order still compare equal -- the question is whether
    the DECISION differs, not whether the writer's dict order did."""
    return (rec.get('result'),
           tuple(sorted((d.get('name'), d.get('verdict')) for d in rec.get('dimensions') or [])))


def artefact_key_collisions(records):
    """-> [(key, [record, ...])] for every artefact_key shared by two or more records whose
    verdicts DISAGREE.

    A key that is a genuine per-artefact identity may legitimately see the SAME (lane, expert,
    ini_path) submitted more than once with the SAME verdict -- the guard re-run for provenance, or
    invoked twice in one pipeline stage. What a sound identity must never show is the same key
    carrying two DIFFERENT verdicts, because that means the .ini at that path changed content
    between two decisions without the path itself changing -- exactly the residual risk
    ARTEFACT_KEY_FIELDS' own docstring names (path identity, not byte identity). A caller that
    joined on this key alone would then be unable to say which decision governs the artefact a
    later run actually used, which is the ambiguity this function exists to surface rather than
    hide.

    Records that cannot build a key (ArtefactKeyError) are left out of the grouping, not treated as
    a silent match on some default key -- `parse()`'s caller sees those via `artefact_key` raising,
    not via a false negative here.
    """
    groups = {}
    for rec in records:
        try:
            key = artefact_key(rec)
        except ArtefactKeyError:
            continue
        groups.setdefault(key, []).append(rec)
    collisions = []
    for key, group in groups.items():
        if len(group) < 2:
            continue
        if len(set(_verdict_signature(r) for r in group)) > 1:
            collisions.append((key, group))
    return collisions
