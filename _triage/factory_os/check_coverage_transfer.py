# -*- coding: utf-8 -*-
"""ORDER-610 E3 -- the acceptance validator for the S2 Coverage transfer.

The owner approved ONE edge of the ORDER-600 proposal and attached two conditions. This file is
those conditions, mechanized. Nothing here is a style check; every criterion below can go red and
each has a negative fixture in run_coverage_transfer_tests.py.

  A1  CONDITION 1, as a BICONDITIONAL.
      "section 2's body IS generator output"  <->  "the banner and the section-2 header say
      `generated from factory/coverage.jsonl; edits here are overwritten`".
      Both directions matter and only one of them is obvious. Generated-body-without-banner is the
      case the owner named. Banner-without-generated-body is the case that would let the notice be
      pre-armed one commit early: the file would then TELL a human it is generated while still being
      hand-written, which is the same harm arriving by the other door.

  A2  CONDITION 2, measured against immutable bytes.
      `factory/coverage.jsonl` must cover at least what the hand table covered. The baseline is the
      PINNED pre-transfer blob, re-resolved from git on every run -- never the working tree. After
      the transfer, section 2 IS the generator's output, so a baseline read from the working tree
      would compare the file with itself and pass unconditionally, forever.

  A3  No verdict lives here.
      A coverage store records what was covered, not whether it was any good. `declared_status` is
      the one field that carries an outcome word, and it is only ever a TRANSCRIPTION: it must
      always be paired with the `source_token` and coordinates it came from, may never sit on a LIVE
      cell, and its vocabulary is closed by the reviewed reconciliation. Minting a new outcome word
      therefore requires editing a file inside the attested bundle, which is exactly what should
      require a fresh owner decision rather than a commit.

  A4/A5  Determinism, and the hand-edit guard that makes the new banner true rather than decorative.

  A8  The transfer may not invalidate the approval that authorized it: the attested bundle must
      still verify.

WHICH BYTES THIS JUDGES
-----------------------
By default every judged repository input is read from the GIT INDEX (`git show :path`) -- the exact
bytes a commit would contain. This is deliberate. A pre-commit gate that reads the working tree can
be satisfied by content that is not being committed (ORDER-545, still open, is that defect one layer
up). `--worktree` judges the working tree instead, and the mode is printed either way, because a
checker that does not say which snapshot it read is a checker whose green cannot be interpreted.
"""

import io
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence  # noqa: E402  (path is set above)
import gen_coverage as gen  # noqa: E402  (path is set above)

BACKLOG_PATH = gen.BACKLOG_PATH
COVERAGE_PATH = gen.COVERAGE_PATH
RECON_PATH = gen.RECONCILIATION_PATH
PHRASE = gen.GENERATED_PHRASE

# Header region = everything before the first `## ` heading. That is where the owner banner lives
# and where a human forms their belief about the file before reading any section.
HEADING_RE = re.compile(r'^## ')

FORBIDDEN_KEYS = (
    'verdict', 'pf', 'profit_factor', 'profitfactor', 'bars', 'bar', 'judgement', 'judgment',
    'decision', 'approved', 'deploy', 'deployment', 'kill', 'pass', 'dead', 'candidate',
)


# ORDER-670 migration 9/9. ToolFailure IS the reader's ToolFailure, not a look-alike.
#
# This is an alias rather than a second class, and the reason is a bug it prevents: every caller
# and every fixture catches `chk.ToolFailure`, while the reader raises `evidence.ToolFailure`. Two
# unrelated exception types would mean a read failure sails straight past main()'s handler and
# out as a TRACEBACK -- exit 1 with a stack trace, which reads as a REJECTION of the file rather
# than an admission that the file was never read. That is the exact conflation the docstring
# below exists to prevent, reintroduced by the migration meant to honour it.
#
# Raised when the checker cannot READ what it is meant to judge. Kept distinct from a rejection
# on purpose: "I could not see the file" and "the file is wrong" are different facts, and
# collapsing them is how a guard reports CLEAN for a file it never opened (memory
# `guard-disarmed-by-prose-reported-as-note`).
ToolFailure = evidence.ToolFailure


def _git(*args):
    p = subprocess.run(('git',) + args, capture_output=True, cwd=ROOT)
    return p.returncode, p.stdout, p.stderr


_SRC = [None]


def _source(worktree=False):
    """The ONE EvidenceSource for this process (design section 3: a program chooses once).

    MODE: `--worktree` wins; otherwise the tier's `EA_LAB_EVIDENCE`; otherwise **index**.

    That last default is deliberately NOT `EvidenceSource.for_run()`, which falls back to
    `worktree`. This checker has had an explicit `--worktree` flag since it was written, so its
    unset default has always been the index, and adopting the library's default would have
    silently flipped a gate to preview semantics -- a loosening disguised as a refactor. The
    library's default is right for a caller with no flag; this caller has one.
    """
    if _SRC[0] is None:
        mode = 'worktree' if worktree else os.environ.get(evidence.MODE_ENV, 'index')
        _SRC[0] = evidence.EvidenceSource(mode, root=ROOT)
    return _SRC[0]


def read_input(relpath, worktree=False):
    """(text, source) for one judged input, through the shared reader.

    ORDER-670 migration 9/9, and it is a BEHAVIOUR change, not a move. What this used to do:
    try the index, and for a path absent from the index FALL BACK TO THE DISK, returning
    ('worktree') as if that were an answer. `evidence.read_committed` has no fallback -- an
    untracked path in index mode is a ToolFailure (ORDER-615 S1, then Spec4: paid for twice).

    The old code compensated for its own fallback AFTERWARDS, in check(), by refusing a mixed
    index/worktree pair and then -- one audit round later -- also refusing worktree/worktree.
    Both of those are now impossible by construction rather than detected after the fact: one
    source, one mode, chosen once. A second implementation of the reader is a second decider of
    which bytes count, which is precisely what this migration removes.
    """
    src = _source(worktree)
    return src.read_committed(relpath), src.mode


HTML_COMMENT = re.compile(r'<!--.*?-->', re.S)
# Markdown link/image REFERENCE DEFINITIONS render as nothing at all. Codex round 2 tested this and
# the checker passed with 0 problems: `[x]: /url "generated from ...; edits here are overwritten"`
# puts the phrase in the source and nothing on the page.
MD_REF_DEF = re.compile(r'^[ ]{0,3}\[[^\]]+\]:.*$', re.M)
# Elements whose CONTENT is never rendered.
HIDDEN_ELEMENT = re.compile(r'<(template|script|style)\b.*?</\1>', re.S | re.I)
# ...and elements hidden by attribute or inline style. The whole ELEMENT goes, not just its opening
# tag: the first version here stripped only the tag and left the text inside it, so
# `<div hidden>the phrase</div>` still read as visible. Caught by probing all seven techniques
# rather than by assuming the pattern was right -- two of the seven were still open.
HIDDEN_ATTR = re.compile(
    r'<(\w+)[^>]*\b(?:hidden\b|style\s*=\s*["\'][^"\']*display\s*:\s*none)[^>]*>.*?</\1>',
    re.S | re.I)
# An HTML TAG is not rendered text. `<img alt="generated from ...">` and
# `<div title="generated from ...">` both keep the phrase in source and off the page.
HTML_TAG = re.compile(r'<[^>]+>')


def strip_invisible(text):
    """Remove what Markdown does not render, before looking for a notice meant to be READ.

    Codex audit, Standards 3, REPRODUCED here before accepting: wrapping the top banner in
    `<!-- ... -->` made the rendered notice disappear while the checker returned 0 problems --
    the owner's condition 1 defeated by the exact mechanism memory
    `guard-disarmed-by-prose-reported-as-note` already records (an HTML comment under a table
    header made a ledger guard parse 0 rows and report NOTE). A known scar, repeated in the file
    written to stop a reader being told something untrue.

    The rule this encodes: a check about what a HUMAN sees must be evaluated on what Markdown
    RENDERS, not on the source bytes. Comments are removed across line boundaries, because that is
    how a multi-line banner would be hidden.

    ROUND 2 showed one regex was not the rule, only the first instance of it. Codex tested a
    Markdown REFERENCE DEFINITION -- `[x]: /url "the phrase"` -- and the checker passed with 0
    problems, and named `<template>`, `hidden`, `display:none`, HTML attributes and image `alt`
    as the same shape. So this is now a list, and the list is the honest statement of a limit:
    **it removes the ways currently known to hide text, not every way that exists.** Markdown has
    no canonical renderer here, so "what a human sees" is approximated, and the approximation is
    stated rather than implied. A new hiding place is a finding against this function, and the
    right response is to add it here -- not to argue the notice was technically present.
    """
    for pattern in (HTML_COMMENT, HIDDEN_ELEMENT, MD_REF_DEF, HIDDEN_ATTR, HTML_TAG):
        text = pattern.sub(' ', text)
    return text


def normalize(s):
    return re.sub(r'\s+', ' ', s.replace('`', '').replace('*', '')).strip().lower()


def load_store_text(text):
    """gen_coverage.load_store, but from bytes we already hold rather than from a path."""
    section = None
    records = []
    for n, line in enumerate(text.split('\n'), 1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            raise ToolFailure('%s line %s is not valid JSON: %s' % (COVERAGE_PATH, n, exc))
        if '_comment' in obj:
            continue
        if '_section' in obj:
            section = obj['_section']
            continue
        records.append(obj)
    if section is None:
        raise ToolFailure('%s carries no _section record' % COVERAGE_PATH)
    return section, records


def render_from(section, records):
    """Delegates. /scrutinize found this algorithm written twice, differing only by namespace
    prefix -- the same duplication the A8 downgrade design argues against. One implementation,
    in the generator, so the checker cannot drift away from what `--apply` actually writes."""
    return gen.render_from(section, records)


# --------------------------------------------------------------------------- criteria

def a1_banner_and_body(backlog_text, section, records, problems):
    # The BODY comparison uses the raw text -- it must match the generator byte for byte, and a
    # comment inserted into it is a difference the generator did not produce, so A5 catches it.
    # The NOTICE search uses the rendered view: see strip_invisible.
    lines = backlog_text.split('\n')
    span = gen.section2_span(lines)
    if span is None:
        problems.append('A1 %s has no %r heading at all' % (BACKLOG_PATH, gen.SECTION2_HEADING))
        return
    start, end = span
    body = lines[start:end]
    want = render_from(section, records)
    body_is_generated = (body == want)

    header_region = lines[:next((i for i, l in enumerate(lines) if HEADING_RE.match(l)), len(lines))]
    banner_ok = PHRASE in normalize(strip_invisible('\n'.join(header_region)))
    section_ok = PHRASE in normalize(strip_invisible('\n'.join(body)))

    # A1 first half, over the GENERATOR rather than over the file. The first fixture written for
    # this criterion proved the file-side version unreachable: the section-2 notice is emitted by
    # the renderer, so a generated body always contains it, and `body_is_generated and not
    # section_ok` could never fire. A branch that cannot fire is not protection -- it is the shape
    # of protection. What IS reachable, and is the thing actually worth guarding, is the generator's
    # own output: if someone edits SECTION_BANNER and drops the notice, every future generation
    # silently stops telling the reader anything.
    if PHRASE not in normalize('\n'.join(want)):
        problems.append(
            'A1 the generator no longer emits the required notice, so every future generation '
            'would produce a section that does not say it is generated. Required phrase '
            '(normalized): %r' % PHRASE)
    if body_is_generated and not banner_ok:
        problems.append(
            'A1 section 2 IS generated output but the notice is missing from the top banner. The '
            'owner\'s condition 1 is that a human opening this file is told it is generated IN THE '
            'SAME COMMIT as the first generation -- otherwise they hand-edit output that will be '
            'overwritten. Required phrase (normalized): %r' % PHRASE)
    if (banner_ok or section_ok) and not body_is_generated:
        first = next((i for i, (a, b) in enumerate(zip(body, want)) if a != b), None)
        where = ('line %s of the section: %r != %r' % (start + first, body[first], want[first])
                 if first is not None else
                 'the section is %s lines, the generator produces %s' % (len(body), len(want)))
        problems.append(
            'A1 the file SAYS section 2 is generated but its body is not generator output -- %s. '
            'A notice that arrives before the generation (or survives a hand edit after it) tells '
            'the reader a falsehood in the direction that costs them work.' % where)
    return body_is_generated


def a2_covers_the_hand_table(section, records, problems):
    """Recompute the baseline from the PINNED blob and require the store to cover all of it."""
    try:
        b_heading, b_header, b_note, b_records = gen.build_records()
    except SystemExit as exc:
        raise ToolFailure('A2 could not rebuild the baseline from blob %s: %s'
                          % (gen.BASELINE_BLOB[:12], exc))

    by_ea = {r.get('ea'): r for r in records}

    for b in b_records:
        ea = b['ea']
        r = by_ea.get(ea)
        if r is None:
            problems.append('A2 the hand table row %r is absent from %s -- the generated table '
                            'would be thinner than what it replaced' % (ea, COVERAGE_PATH))
            continue
        for i, col in enumerate(b['source_columns']):
            got = (r.get('source_columns') or [])
            if i >= len(got) or got[i] != col:
                problems.append('A2 row %r column %s lost or altered. baseline=%r store=%r'
                                % (ea, i, col, got[i] if i < len(got) else '<missing>'))
        # Codex audit round 1 P1: this compared only (cell, source_token), so every OTHER field of
        # an imported cell was unguarded. Round 2 then defeated the repair itself, twice, and both
        # defeats came from the same instinct -- comparing "the cells I can look up" instead of
        # "the cells that are there":
        #
        #   * the fix collapsed cells into a dict keyed by identity, so a DUPLICATE overwrote its
        #     twin and the LAST one won. Inserting a corrupted duplicate BEFORE the real cell was
        #     therefore invisible: the real cell satisfied A2 on the duplicate's behalf.
        #   * `.get()` made a key that is ABSENT and a key that is present-and-null compare equal,
        #     so reviewed evidence could be altered and still called identical.
        #
        # Both are closed by comparing the cell list POSITIONALLY against the reviewed evidence and
        # by comparing the key SETS before the values. An imported cell transcribes evidence the
        # owner approved; there is no legitimate reason for its shape, order or count to differ.
        got_cells = r.get('cells') or []
        if len(got_cells) != len(b['cells']):
            problems.append('A2 row %r carries %s cell(s) but the reviewed evidence has %s. An '
                            'imported cell list is a transcription -- an extra cell (a duplicate '
                            'is one) is a fact the owner never reviewed.'
                            % (ea, len(got_cells), len(b['cells'])))
        for i, c in enumerate(b['cells']):
            if i >= len(got_cells):
                problems.append('A2 row %r lost cell %r (source_token=%r)'
                                % (ea, c.get('cell'), c.get('source_token')))
                continue
            got = got_cells[i]
            if set(c) != set(got):
                problems.append('A2 row %r cell %s: field set differs from the reviewed evidence. '
                                'reviewed-only=%s store-only=%s -- a key present with a null value '
                                'is NOT the same as a key that is absent.'
                                % (ea, i, sorted(set(c) - set(got)), sorted(set(got) - set(c))))
            for k in sorted(set(c) & set(got)):
                if c[k] != got[k]:
                    problems.append('A2 row %r cell %s (%r) field %r was altered in the move. '
                                    'reviewed=%r store=%r -- an imported cell transcribes evidence '
                                    'the owner approved; it is not a field this file may revise.'
                                    % (ea, i, c.get('cell'), k, c[k], got[k]))
        b_live = set(b.get('live_cells') or [])
        r_live = set(r.get('live_cells') or [])
        for lc in b_live - r_live:
            problems.append('A2 row %r lost LIVE cell %r' % (ea, lc))

    if section.get('heading') != b_heading:
        problems.append('A2 the section heading changed: baseline=%r store=%r'
                        % (b_heading, section.get('heading')))
    if section.get('header_columns') != b_header:
        problems.append('A2 the table header changed: baseline=%r store=%r'
                        % (b_header, section.get('header_columns')))
    if b_note and section.get('note') != b_note:
        problems.append('A2 the reading note under the table was dropped or altered: baseline=%r '
                        'store=%r' % (b_note, section.get('note')))

    n_rows = len(b_records)
    n_cells = sum(len(b['cells']) for b in b_records)
    n_live = sum(len(b.get('live_cells') or []) for b in b_records)
    got_cells = sum(len(r.get('cells') or []) for r in records)
    got_live = sum(len(r.get('live_cells') or []) for r in records)
    if len(records) < n_rows or got_cells < n_cells or got_live < n_live:
        problems.append('A2 counts regressed: baseline %s rows / %s cells / %s LIVE, store %s / %s '
                        '/ %s' % (n_rows, n_cells, n_live, len(records), got_cells, got_live))
    return n_rows, n_cells, n_live


def _walk_keys(obj, path=''):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield k, path + '/' + str(k)
            for kk in _walk_keys(v, path + '/' + str(k)):
                yield kk
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            for kk in _walk_keys(v, path + '[%d]' % i):
                yield kk


# Codex audit P1: A3 was a BLACKLIST of key names, so a root field the list did not anticipate --
# it used `"outcome": "DEAD"` -- carried a verdict straight through. A blacklist answers "is this
# one of the bad names I thought of?"; the question that matters is "is this a field this store is
# allowed to have at all?". These are closed sets. Adding a field is a reviewable edit here, which
# is the point: the store's shape stops being whatever anyone last wrote into it.
RECORD_KEYS = {'ea', 'imported_from', 'source_columns', 'live_cells', 'cells'}
IMPORTED_FROM_KEYS = {'file', 'section', 'blob', 'commit', 'row_index'}
CELL_KEYS = {'cell', 'column', 'status', 'declared_status', 'source_token', 'source_coordinates',
             'why_unverified'}
COORD_KEYS = {'column_index', 'file', 'section', 'source_row'}
SECTION_KEYS = {'heading', 'header_columns', 'note'}
# The closed vocabulary for the field that CLASSIFIES a cell. Derived from the reviewed
# reconciliation's own two states -- not invented here, and widening it means editing a file inside
# the attested bundle, which is exactly what should need a fresh owner decision.
CELL_STATUS = {'LIVE', 'UNVERIFIED_IMPORT'}


def _closed(obj, allowed, where, problems):
    if not isinstance(obj, dict):
        problems.append('A3 %s is %s, expected an object' % (where, type(obj).__name__))
        return
    extra = sorted(set(obj) - allowed)
    if extra:
        problems.append('A3 %s carries undeclared field(s) %s. This store has a CLOSED shape -- a '
                        'field nothing declared is a fact nothing validates, and the audit reached '
                        'straight through the old name-blacklist with a root "outcome": "DEAD".'
                        % (where, extra))


def a3_closed_shape_and_no_verdict(section, records, problems, allowed_status):
    _closed(section, SECTION_KEYS, '_section', problems)
    for r in records:
        ea = r.get('ea')
        _closed(r, RECORD_KEYS, 'row %r' % ea, problems)
        _closed(r.get('imported_from') or {}, IMPORTED_FROM_KEYS,
                'row %r imported_from' % ea, problems)
        for c in (r.get('cells') or []):
            _closed(c, CELL_KEYS, 'row %r cell %r' % (ea, c.get('cell')), problems)
            # Codex audit round 2, Spec 1: A3 checked key NAMES and never VALUES, so a cell could
            # carry `"status": "DEAD-STRUCTURAL"` and pass -- a VERDICT, in the field that decides
            # what kind of cell this is, in the store whose whole acceptance says no verdict lives
            # here. ORDER-610 A3 was simply false. A closed shape is only half of a closed
            # contract: the fields that classify a record need closed vocabularies too.
            st = c.get('status')
            if st not in CELL_STATUS:
                problems.append('A3 row %r cell %r has status=%r, which is not one of %s. This is '
                                'the field that says what KIND of cell this is; leaving it open '
                                'let a VERDICT be carried in a coverage store.'
                                % (ea, c.get('cell'), st, sorted(CELL_STATUS)))
            if 'source_coordinates' in c:
                _closed(c['source_coordinates'], COORD_KEYS,
                        'row %r cell %r source_coordinates' % (ea, c.get('cell')), problems)
        for key, where in _walk_keys(r):
            if str(key).strip().lower() in FORBIDDEN_KEYS:
                problems.append('A3 row %r carries the field %r at %s. A coverage store records '
                                'what was covered, not whether it was any good -- verdicts live in '
                                'EA_SCORECARD_AND_REGISTRY.md and nowhere else.' % (ea, key, where))
        for c in (r.get('cells') or []):
            ds = c.get('declared_status')
            if ds is None:
                continue
            if c.get('status') == 'LIVE':
                problems.append('A3 row %r cell %r is LIVE and also carries declared_status=%r. A '
                                'LIVE cell is a positional fact; attaching an outcome word to it '
                                'turns the store into a place where quality is asserted.'
                                % (ea, c.get('cell'), ds))
            if not c.get('source_token') or not c.get('source_coordinates'):
                problems.append('A3 row %r cell %r declares status %r with no source_token/'
                                'source_coordinates -- an outcome word with no provenance is this '
                                'file making the claim itself.' % (ea, c.get('cell'), ds))
            if ds not in allowed_status:
                problems.append('A3 row %r cell %r declares status %r, which is not in the closed '
                                'vocabulary the reviewed reconciliation established (%s). Minting a '
                                'new outcome word means editing a file inside the attested bundle, '
                                'which needs a fresh owner decision, not a commit.'
                                % (ea, c.get('cell'), ds, ', '.join(sorted(allowed_status))))


def a4_renderer_is_deterministic(section, records, problems):
    """A4, RESTORED. Codex audit round 2, Spec 5: deleting it was not free.

    The argument for deleting it was that with one renderer, "the generator and the checker agree"
    is true by construction. That argument is sound and it is also not what A4 said. ORDER-610's
    A4 required TWO byte-identical renders -- a property of the renderer itself, not of who calls
    it. A1 renders exactly once, so a renderer that returned the committed body first and something
    else second would pass every check in this file.

    That is a criterion I removed instead of satisfying, which is the same amend-my-own-acceptance
    pattern the first audit caught. It is back, and it is now non-tautological for a reason the
    previous version was not: it perturbs nothing and compares nothing to itself -- it calls the
    REAL generator twice on the same inputs and requires the two calls to agree, which is exactly
    the property "deterministic" names.
    """
    once = gen.render_from(section, records)
    twice = gen.render_from(section, records)
    if once != twice:
        first = next((i for i, (a, b) in enumerate(zip(once, twice)) if a != b), None)
        problems.append('A4 the generator is NOT deterministic: two renders of identical inputs '
                        'differ%s. Section 2 would then depend on when it was generated, and A1 '
                        'could pass or fail by luck.'
                        % ((' first at line %s: %r vs %r' % (first, once[first], twice[first]))
                           if first is not None else ' in length (%s vs %s)' % (len(once),
                                                                               len(twice))))


# The PREVIOUS A4 is deleted, and that part of the fix stands.
#
# Codex audit, Standards 5, was right that it was tautological: it rendered the same in-memory
# objects twice through the same function and asserted they were equal -- a pure function of
# unchanged inputs, which cannot fail. The obvious repair was to make it call the GENERATOR instead
# of the checker's copy of the renderer. But /scrutinize had already found that those two renderers
# were the same algorithm written twice, and the right fix for THAT was to delete the copy and
# delegate. With one implementation, "the generator and the checker agree" is true by construction
# and A4 has no content left at all.
#
# What A4 was reaching for -- section 2 must BE what the generator produces from the store -- is
# already A1's body comparison, which reads the committed bytes from the git index and has
# fixtures that redden when the store is perturbed. Keeping a second criterion that restates it in
# a form that cannot fail is worse than having one: it reads as coverage. ORDER-610's promised
# perturbation fixture is now attached to A1, where it can actually fire.


def a8_attestation_still_valid(problems):
    """ORDER-610 A8, restored to what it actually said: the transfer may not invalidate the
    approval that authorized it, and `check_s2a_attestation.py` must exit 0.

    ORDER-613 D3 DELETED the downgrade that used to live here. It existed because the attestation
    contract could not express "the pinned bytes changed INTO the state this record approved", so
    an approved transfer permanently invalidated its own approval. D1 and D2 fixed that in the
    contract. A workaround kept past the repair of its cause stops being a workaround and becomes
    the rule -- and Codex was right that this one converted a FAILED pre-registered acceptance into
    a pass without the owner ever agreeing to the amendment.

    There is no exemption path here any more. If this reddens, something is wrong.
    """
    p = subprocess.run([sys.executable, os.path.join(HERE, 'check_s2a_attestation.py')],
                       capture_output=True, cwd=ROOT)
    if p.returncode != 0:
        problems.append('A8 the attested bundle no longer verifies (check_s2a_attestation.py exit '
                        '%s). The approval that authorized this transfer binds six files; if one '
                        'changed, the approval is void and the owner must decide again -- this '
                        'order does not get to decide that.\n%s'
                        % (p.returncode, p.stdout.decode('utf-8', 'replace')[-800:]))


# --------------------------------------------------------------------------- driver

def check(backlog_text=None, coverage_text=None, worktree=False, skip_a8=False):
    """Returns (problems, info). Raises ToolFailure when it cannot read what it must judge."""
    info = {}
    if backlog_text is None:
        backlog_text, info['backlog_source'] = read_input(BACKLOG_PATH, worktree)
    else:
        info['backlog_source'] = 'injected'
    if coverage_text is None:
        coverage_text, info['coverage_source'] = read_input(COVERAGE_PATH, worktree)
    else:
        info['coverage_source'] = 'injected'

    # ORDER-670 migration 9/9 DELETED TWO REFUSALS FROM HERE, and that deletion is the point of
    # the migration rather than a casualty of it. They were:
    #
    #   * MIXED-VINTAGE (Codex Standards 1) -- one input from the index, one from the disk.
    #   * WORKTREE/WORKTREE (Codex round 2, Spec 4) -- BOTH from the disk while not --worktree,
    #     which is the original defect doubled, not a weaker version of it.
    #
    # Both existed to catch, after the fact, a state that `read_input`'s own per-call worktree
    # fallback could produce. There is no fallback now and there is ONE source for the process,
    # so neither state can be constructed: an untracked path in index mode raises before any
    # verdict exists to be mixed. Keeping the checks would leave two branches that cannot fire --
    # shape 3, in the file whose header is about not reading the wrong bytes -- and the honest
    # move is to say the invariant became STRUCTURAL and show where it is enforced instead.
    #
    # WHAT IS NOT LOST: the diagnosis. `read_committed`'s refusal names the path, says whether it
    # exists in the working tree, and says why there is no fallback. The suite still drives every
    # one of these scenarios (Standards 1 block) and still expects a ToolFailure for each -- same
    # expectations, different mechanism, which is why the fixtures could be kept rather than
    # rewritten to match the new code.

    # ORDER-670 migration 8/9, and this was a MIXED-VINTAGE VERDICT hiding behind "vocabulary
    # only". `backlog_text` and `coverage_text` come from the INDEX; this came from the WORKING
    # TREE, and A3's allowed-status set is derived from it -- so a status vocabulary edited in the
    # worktree but not staged (or staged but not in the worktree) decided whether a COMMITTED row
    # was acceptable. One verdict, two moments. That is A2's crime, in the file that refuses
    # exactly that pairing eight lines above ("a verdict over bytes that are not staged says
    # nothing about the commit").
    #
    # It reads through the SAME read_input as the other two now, so all three inputs to one
    # verdict share one vintage by construction rather than by comment.
    try:
        recon_text, info['recon_source'] = read_input(RECON_PATH, worktree)
        recon = json.loads(recon_text)
    except ToolFailure:
        raise
    except (IOError, ValueError) as exc:
        raise ToolFailure('cannot read the reviewed reconciliation %s: %s' % (RECON_PATH, exc))
    # The recon-vs-coverage split check that stood here is gone for the same reason as the two
    # above: all three inputs now come from ONE EvidenceSource, so `recon_source` and
    # `coverage_source` are literally the same attribute read twice. Comparing a value to itself
    # is the purest form of shape 3 -- `a4_deterministic` rendered the same objects through the
    # same function and asserted equality, and that is a named instance in GUARD_SHAPES. Migration
    # 8/9 fixed the DEFECT (the reconciliation really was read from the worktree while the store
    # came from the index); 9/9 removes the need for the detector by removing the way to get there.
    allowed_status = {c['declared_status'] for m in recon['mapping'] for c in m['cells']
                      if 'declared_status' in c}

    section, records = load_store_text(coverage_text)
    problems = []
    info['body_is_generated'] = a1_banner_and_body(backlog_text, section, records, problems)
    info['baseline'] = a2_covers_the_hand_table(section, records, problems)
    a3_closed_shape_and_no_verdict(section, records, problems, allowed_status)
    a4_renderer_is_deterministic(section, records, problems)
    if not skip_a8:
        a8_attestation_still_valid(problems)
    info['records'] = len(records)
    info['cells'] = sum(len(r.get('cells') or []) for r in records)
    return problems, info


def main(argv):
    out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
    worktree = '--worktree' in argv
    out.write('=== ORDER-610 E3: the S2 Coverage transfer acceptance ===\n')
    try:
        problems, info = check(worktree=worktree)
    except ToolFailure as exc:
        out.write('[TOOL FAILURE] %s\n' % exc)
        out.write('This is NOT a rejection: the checker could not read what it judges. Exit 2.\n')
        out.flush()
        return 2
    out.write('judged bytes : %s=%s  %s=%s\n'
              % (BACKLOG_PATH, info['backlog_source'], COVERAGE_PATH, info['coverage_source']))
    out.write('baseline     : blob %s -> %s rows / %s cells / %s LIVE (recomputed, not stored)\n'
              % ((gen.BASELINE_BLOB[:12],) + info['baseline']))
    out.write('store        : %s rows / %s cells\n' % (info['records'], info['cells']))
    out.write('section 2    : %s\n' % ('GENERATED output' if info['body_is_generated']
                                       else 'still hand-written'))
    if problems:
        out.write('\n%s PROBLEM(S):\n' % len(problems))
        for p in problems:
            out.write('  - %s\n' % p)
        out.write('\n=== REJECTED ===\n')
        out.flush()
        return 1
    out.write('\n=== ACCEPTED: both owner conditions hold, and nothing was lost in the move ===\n')
    out.flush()
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
