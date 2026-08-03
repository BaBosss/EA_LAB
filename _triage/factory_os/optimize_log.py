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


class LogRefusal(Exception):
    """The log could not be read as a log. Never a verdict about the guard."""


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
