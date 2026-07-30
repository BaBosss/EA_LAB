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


class ToolFailure(Exception):
    """Raised when the checker cannot READ what it is meant to judge.

    Kept distinct from a rejection on purpose: "I could not see the file" and "the file is wrong"
    are different facts, and collapsing them is how a guard reports CLEAN for a file it never
    opened (memory `guard-disarmed-by-prose-reported-as-note`).
    """


def _git(*args):
    p = subprocess.run(('git',) + args, capture_output=True, cwd=ROOT)
    return p.returncode, p.stdout, p.stderr


def read_input(relpath, worktree=False):
    """(text, source) for one judged input. Index by default; working tree on request."""
    if not worktree:
        rc, out, err = _git('show', ':' + relpath)
        if rc == 0:
            return out.decode('utf-8-sig').replace('\r\n', '\n'), 'index'
        # Not in the index: either untracked, or staged for deletion. Both are worth naming.
        rc2, out2, _ = _git('ls-files', '--error-unmatch', relpath)
        if rc2 == 0:
            raise ToolFailure('%s is tracked but not readable from the index: %s'
                              % (relpath, err.decode('utf-8', 'replace').strip()))
    full = os.path.join(ROOT, relpath)
    if not os.path.exists(full):
        raise ToolFailure('%s does not exist in %s' % (relpath, 'the working tree'))
    return io.open(full, encoding='utf-8-sig').read().replace('\r\n', '\n'), 'worktree'


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
    out = [section['heading'], '']
    out.extend(gen.SECTION_BANNER)
    out.append('')
    out.append(gen.join_row(section['header_columns']))
    out.append('|' + '---|' * len(section['header_columns']))
    for r in records:
        out.append(gen.join_row(r['source_columns']))
    out.append('')
    if section.get('note'):
        out.append(section['note'])
        out.append('')
    out.append('---')
    out.append('')
    return out


# --------------------------------------------------------------------------- criteria

def a1_banner_and_body(backlog_text, section, records, problems):
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
    banner_ok = any(PHRASE in normalize(l) for l in header_region)
    section_ok = any(PHRASE in normalize(l) for l in body)

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
        have = {(c.get('cell'), c.get('source_token')) for c in (r.get('cells') or [])}
        for c in b['cells']:
            key = (c.get('cell'), c.get('source_token'))
            if key not in have:
                problems.append('A2 row %r lost cell %r (source_token=%r)'
                                % (ea, c.get('cell'), c.get('source_token')))
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


def a3_no_verdict(records, problems, allowed_status):
    for r in records:
        ea = r.get('ea')
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


def a4_deterministic(section, records, problems):
    once = render_from(section, records)
    twice = render_from(section, records)
    if once != twice:
        problems.append('A4 rendering is not deterministic -- two renders of the same store differ')


def a8_attestation_still_valid(problems):
    py = sys.executable
    p = subprocess.run([py, os.path.join(HERE, 'check_s2a_attestation.py')],
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

    try:
        recon = json.load(io.open(os.path.join(ROOT, RECON_PATH), encoding='utf-8'))
    except (IOError, ValueError) as exc:
        raise ToolFailure('cannot read the reviewed reconciliation %s: %s' % (RECON_PATH, exc))
    allowed_status = {c['declared_status'] for m in recon['mapping'] for c in m['cells']
                      if 'declared_status' in c}

    section, records = load_store_text(coverage_text)
    problems = []
    info['body_is_generated'] = a1_banner_and_body(backlog_text, section, records, problems)
    info['baseline'] = a2_covers_the_hand_table(section, records, problems)
    a3_no_verdict(records, problems, allowed_status)
    a4_deterministic(section, records, problems)
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
