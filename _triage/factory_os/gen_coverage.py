# -*- coding: utf-8 -*-
"""ORDER-610 E2 -- the CoverageCell generator.

S2 executes ONE edge of the ORDER-600 proposal: `MASTER_BACKLOG.md` section 2 stops being the
canonical home of coverage facts and `factory/coverage.jsonl` becomes it. The owner approved that
edge with two conditions (attestation log line 2, bundle aaa5998d7128238a), and both are mechanized
in check_coverage_transfer.py. This file only GENERATES; every judgement lives in the checker.

Three modes:

  --from-baseline   parse the PINNED pre-transfer blob of MASTER_BACKLOG.md and write
                    factory/coverage.jsonl. Run once, at migration time.
  --render          read factory/coverage.jsonl and print the section-2 block it owns.
  --apply           read factory/coverage.jsonl and rewrite MASTER_BACKLOG.md's banner + section 2.

WHY THE BASELINE IS A PINNED BLOB AND NOT THE WORKING TREE
----------------------------------------------------------
After the transfer, section 2 IS this generator's output. A generator that re-read the working tree
would then be reading its own output, and "did the migration lose anything?" would be answered by
comparing a file with itself -- it would pass unconditionally and forever. The repo has already paid
for this exact shape once: a drift guard that regenerated against HEAD while its data pinned
generation-time HEAD (memory `drift-guard-regenerating-against-head`). The migration source is
therefore an immutable git blob, named here and re-resolved from git on every run.

WHAT LOSSLESS MEANS HERE, MEASURED
----------------------------------
The owner's second condition is that the generated table may not be thinner than the hand table.
The strongest form of that available is byte equality: the first generation reproduces the hand
table's rows EXACTLY, and adds only the generated-banner the first condition requires. So every one
of the six columns is carried verbatim in `source_columns` -- including `Class`, `TF` and
`Optimized?`, which the existing section-2 parser drops -- and generation asserts that rejoining
them reproduces the source line byte for byte before anything is written.
"""

import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

# The pre-transfer blob of MASTER_BACKLOG.md: the last hand-authored revision of section 2.
# Pinned by ORDER-610 A2; also the blob D1's CoverageCell row pins as its owner_ref.
BASELINE_BLOB = 'ca909b693a4c747dc1347d48fa8b2507f6a4243f'
BASELINE_COMMIT = 'a7960e08a03616984db2e7cccb19342f0ee30ad7'

# The reconciliation is pinned by its OWN BLOB, not by BASELINE_COMMIT. MEASURED 2026-07-31 while
# fixing Codex Standards 2: it did not EXIST at a7960e08 -- that commit predates the whole S2a work
# -- so "both halves of the baseline from one commit" is not merely inconvenient here, it is
# impossible. A blob id is immutable in exactly the way the fix needs, and this is the same bytes
# attestation bundle aaa5998d binds, so changing the file invalidates the owner's approval as well.
RECONCILIATION_BLOB = '1fff12ce1dc36964507dbb902ed69edebbcd8213'

SECTION2_HEADING = '## 2. COVERAGE MATRIX'
BACKLOG_PATH = 'MASTER_BACKLOG.md'
COVERAGE_PATH = 'factory/coverage.jsonl'
RECONCILIATION_PATH = '_triage/factory_os/s2a_coverage_reconciliation.json'

# The owner's condition 1, as a literal. The checker requires this phrase (normalized) in BOTH the
# file's top banner and the section-2 header, and requires it to appear in the SAME commit as the
# first generated body. It is a constant here rather than a data field so that deleting it from the
# file makes the rendering diverge (A5) AND trips the phrase check (A1) -- two independent guards.
GENERATED_PHRASE = 'generated from factory/coverage.jsonl; edits here are overwritten'

TOP_BANNER = (
    '> \U0001f916 **§2 (COVERAGE MATRIX) is generated from `factory/coverage.jsonl`; '
    'edits here are overwritten.** Change the cell there and regenerate — '
    '`tools\\python312\\python.exe _triage\\factory_os\\gen_coverage.py --apply` '
    '(ORDER-610, owner-approved 2026-07-31).'
)

SECTION_BANNER = [
    '> \U0001f916 **GENERATED from `factory/coverage.jsonl`; edits here are overwritten.** '
    'This table was the canonical home of coverage facts until 2026-07-31; it is now a '
    'projection of the store.',
    '> The hand-authored original is blob `%s` (`%s`) and the first generation reproduces its rows '
    'byte-for-byte — nothing was dropped in the move.' % (BASELINE_BLOB[:12], BASELINE_COMMIT[:8]),
]


def _git(*args):
    p = subprocess.run(('git',) + args, capture_output=True, cwd=ROOT)
    return p.returncode, p.stdout, p.stderr


def baseline_text():
    """The pinned pre-transfer MASTER_BACKLOG.md, as text, straight from the object store."""
    rc, out, err = _git('cat-file', 'blob', BASELINE_BLOB)
    if rc != 0:
        raise SystemExit('gen_coverage: cannot read baseline blob %s: %s'
                         % (BASELINE_BLOB, err.decode('utf-8', 'replace')))
    return out.decode('utf-8').replace('\r\n', '\n')


def baseline_reconciliation():
    """The reconciliation AS IT WAS AT THE PINNED COMMIT, not as it is in the working tree.

    Codex audit, Standards 2: build_records() joined the pinned backlog blob with a working-tree
    read of the reconciliation, so the baseline it called immutable was mixed-vintage. An edit to
    the reconciliation could move the yardstick the store is measured against -- which is the same
    self-reference the pinned blob exists to prevent, arriving through the other input.

    Both halves of the baseline are now immutable git objects. Note they are pinned DIFFERENTLY and
    that is not sloppiness: the backlog by commit-resolved blob, the reconciliation by its own blob,
    because it did not exist at BASELINE_COMMIT. See the constant.
    """
    rc, out, err = _git('cat-file', 'blob', RECONCILIATION_BLOB)
    if rc != 0:
        raise SystemExit('gen_coverage: cannot read the pinned reconciliation blob %s: %s'
                         % (RECONCILIATION_BLOB[:12], err.decode('utf-8', 'replace')))
    return json.loads(out.decode('utf-8-sig'))


def section2_span(lines):
    """(start, end) line indices of the section-2 block: heading .. just before the next `## `."""
    try:
        start = next(i for i, l in enumerate(lines) if l.startswith(SECTION2_HEADING))
    except StopIteration:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith('## '):
            end = i
            break
    return start, end


def split_row(line):
    """`| a | b |` -> ['a', 'b']. The inverse of join_row."""
    return [c.strip() for c in line.strip().strip('|').split('|')]


def join_row(cols):
    return '| ' + ' | '.join(cols) + ' |'


def build_records():
    """Parse the pinned baseline into the store's records. Raises rather than guessing."""
    import check_s2a_migration as chk

    text = baseline_text()
    lines = text.split('\n')
    span = section2_span(lines)
    if span is None:
        raise SystemExit('gen_coverage: the baseline blob has no %r heading' % SECTION2_HEADING)
    start, end = span
    block = lines[start:end]

    heading = block[0]
    header_cols = None
    rows = []
    note = None
    for line in block[1:]:
        if line.startswith('|'):
            cols = split_row(line)
            if set(''.join(cols)) <= set('-: '):
                continue
            if header_cols is None:
                header_cols = cols
                continue
            if join_row(cols) != line:
                # Two derivations must agree before anything is written. If a row does not survive
                # split->join, the store cannot promise byte equality and must not claim to.
                raise SystemExit('gen_coverage: row does not round-trip, refusing to write a store '
                                 'that would silently reformat it:\n  src: %r\n  out: %r'
                                 % (line, join_row(cols)))
            rows.append((line, cols))
        elif line.startswith('**') and note is None:
            note = line

    if header_cols is None or not rows:
        raise SystemExit('gen_coverage: parsed 0 header or 0 rows out of the baseline')

    # Independent cross-check: the existing, already-reviewed section-2 parser must agree about the
    # source rows and their LIVE cells. Two derivations agreeing is the reason these numbers are
    # trusted; disagreeing means one of them is wrong and that has to be found out first.
    #
    # /scrutinize: this used to write `_triage/factory_os/__baseline_probe.md` -- a FIXED name
    # INSIDE the repo, 17 times per suite run. A crash left it behind as untracked litter, and two
    # lanes running at once would delete each other's copy mid-read. This repo has real history of
    # exactly that (memory `shared-worktree-concurrent-writers`). It is a private temp dir now.
    # parse_section2 takes a path and cannot be changed to take text: check_s2a_migration.py is
    # inside attestation bundle aaa5998d, so editing it would void the owner's approval.
    probedir = tempfile.mkdtemp(prefix='s2baseline_')
    try:
        tmp = os.path.join(probedir, 'baseline.md')
        io.open(tmp, 'w', encoding='utf-8', newline='\n').write(text)
        parsed = chk.parse_section2(tmp)
    finally:
        shutil.rmtree(probedir, ignore_errors=True)
    if parsed is None or len(parsed) != len(rows):
        raise SystemExit('gen_coverage: parse_section2 sees %s rows, this generator sees %s'
                         % (None if parsed is None else len(parsed), len(rows)))

    recon = baseline_reconciliation()
    by_row = {}
    for m in recon['mapping']:
        by_row.setdefault(m['source_row'], []).extend(m['cells'])

    records = []
    for idx, ((raw, cols), p) in enumerate(zip(rows, parsed)):
        if cols[0] != p['source_row']:
            raise SystemExit('gen_coverage: row %s label disagrees: %r vs %r'
                             % (idx, cols[0], p['source_row']))
        if cols[0] not in by_row:
            raise SystemExit('gen_coverage: row %r has no cells in the reconciliation -- the store '
                             'would be thinner than the reviewed mapping' % cols[0])
        records.append({
            'ea': cols[0],
            'imported_from': {
                'file': BACKLOG_PATH,
                'section': SECTION2_HEADING,
                'blob': BASELINE_BLOB,
                'commit': BASELINE_COMMIT,
                'row_index': idx,
            },
            # verbatim, all six columns -- this is what makes "no information lost" checkable
            'source_columns': cols,
            'live_cells': p['live_cells'],
            'cells': by_row[cols[0]],
        })
    return heading, header_cols, note, records


def write_store(path=None):
    heading, header_cols, note, records = build_records()
    path = path or os.path.join(ROOT, COVERAGE_PATH)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    comment = {'_comment':
               'ORDER-610 E1. CANONICAL store of CoverageCell facts. Section 2 of MASTER_BACKLOG.md '
               'is now a GENERATED projection of this file -- edit here, then run '
               '_triage/factory_os/gen_coverage.py --apply. Imported 2026-07-31 from the pinned '
               'pre-transfer blob %s (%s) under the owner attestation of 2026-07-31 (bundle '
               'aaa5998d7128238a), whose second condition was that this store must cover at least '
               'what the hand table covered. It does so by byte equality: source_columns carries '
               'all six columns verbatim and the first generation reproduces the hand rows exactly. '
               'This file carries COVERAGE facts and imported CLAIMS with their provenance. It '
               'carries NO verdict: a declared_status is always an outcome word transcribed from '
               'the source, always paired with the source_token and coordinates it came from, and '
               'never an assertion by this file. Enforced by check_coverage_transfer.py.'
               % (BASELINE_BLOB[:12], BASELINE_COMMIT[:8])}
    section = {'_section': {'heading': heading, 'header_columns': header_cols, 'note': note}}
    buf = io.StringIO()
    for obj in [comment, section] + records:
        buf.write(json.dumps(obj, ensure_ascii=False, sort_keys=True) + '\n')
    io.open(path, 'w', encoding='utf-8', newline='\n').write(buf.getvalue())
    return path, len(records)


def load_store(path=None):
    path = path or os.path.join(ROOT, COVERAGE_PATH)
    section = None
    records = []
    for n, line in enumerate(io.open(path, encoding='utf-8'), 1):
        if not line.strip():
            continue
        obj = json.loads(line)
        if '_comment' in obj:
            continue
        if '_section' in obj:
            section = obj['_section']
            continue
        records.append(obj)
    if section is None:
        raise ValueError('%s carries no _section record' % path)
    return section, records


def render_from(section, records):
    """The section-2 block this store owns, as the exact list of lines to splice into the file.

    ONE implementation. /scrutinize found this algorithm written twice -- here and in
    check_coverage_transfer.render_from -- differing only by namespace prefix, which is precisely
    the duplication the A8 downgrade design argues against ("a rule written twice will disagree
    with itself"). The checker now calls this.
    """
    out = [section['heading'], '']
    out.extend(SECTION_BANNER)
    out.append('')
    out.append(join_row(section['header_columns']))
    out.append('|' + '---|' * len(section['header_columns']))
    for r in records:
        out.append(join_row(r['source_columns']))
    out.append('')
    if section.get('note'):
        out.append(section['note'])
        out.append('')
    out.append('---')
    out.append('')
    return out


def render(path=None):
    section, records = load_store(path)
    return render_from(section, records)


def apply_to_backlog(path=None):
    """Rewrite MASTER_BACKLOG.md: the top banner, and the whole section-2 block."""
    target = os.path.join(ROOT, BACKLOG_PATH)
    blob = io.open(target, 'rb').read()
    # Preserve the file's existing encoding exactly. Writing utf-8-sig unconditionally ADDED a BOM
    # to a file that had none -- caught in the first --apply run, before it was committed. A
    # generator that quietly changes a byte outside the region it owns is a generator whose diff
    # nobody can read.
    bom = blob.startswith(b'\xef\xbb\xbf')
    raw = blob.decode('utf-8-sig')
    nl = '\r\n' if '\r\n' in raw else '\n'
    lines = raw.replace('\r\n', '\n').split('\n')

    span = section2_span(lines)
    if span is None:
        raise SystemExit('gen_coverage --apply: %s has no %r' % (BACKLOG_PATH, SECTION2_HEADING))
    start, end = span
    lines[start:end] = render(path)

    # The top banner: insert once, directly under the `canonical entry =` owner banner, which
    # check_state.ps1 asserts and this must not disturb.
    if not any(TOP_BANNER == l for l in lines):
        try:
            anchor = next(i for i, l in enumerate(lines) if 'canonical entry =' in l)
        except StopIteration:
            raise SystemExit('gen_coverage --apply: no owner banner to anchor the notice to')
        lines.insert(anchor + 1, TOP_BANNER)

    io.open(target, 'w', encoding='utf-8-sig' if bom else 'utf-8',
            newline='').write(nl.join(lines))
    return target


def sha256_file(path):
    h = hashlib.sha256()
    h.update(io.open(path, 'rb').read())
    return h.hexdigest()


def main(argv):
    if '--from-baseline' in argv:
        path, n = write_store()
        print('[gen_coverage] wrote %s -- %s EA records from baseline blob %s'
              % (COVERAGE_PATH, n, BASELINE_BLOB[:12]))
        print('[gen_coverage] sha256 %s' % sha256_file(path)[:16])
        return 0
    if '--render' in argv:
        out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
        out.write('\n'.join(render()) + '\n')
        out.flush()
        return 0
    if '--apply' in argv:
        t = apply_to_backlog()
        print('[gen_coverage] rewrote section 2 + banner in %s' % t)
        return 0
    print(__doc__)
    print('usage: gen_coverage.py [--from-baseline | --render | --apply]')
    return 2


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
