# -*- coding: utf-8 -*-
"""pilot_probe_select.py -- ORDER-1273. EXECUTE the pre-registered selection criterion.

WHAT THIS IS. `ORDER-1273` was committed to `AGENT_TASKBOARD.md` before any probe surface had been
read, and it pins every constant of the selection: the trade floor, the plateau fraction, the
column each is read from, the statistic, and what happens at a grid boundary. This file is that
order rendered as code and NOTHING ELSE. Every number below is quoted from the order; none is
chosen here.

  1. Admissible set `A` = passes whose `Trades` column clears the section 6.2 MAIN floor for the
     cell's timeframe: H1 >= 100, H4 >= 60. The floor is never lowered to produce a selection.
  2. `A` empty => the cell has NO selected configuration. Recorded and said plainly. It is NOT a
     verdict about the EA; it is the statement that this surface contains nothing interpretable at
     the participation the policy requires. The order predicts this for most cells IN ADVANCE.
  3. Plateau set `P` = the top 10 % of `A` by the `Result` column -- the value of the optimization
     criterion the run was launched with (`-Criterion 1`, named from the LAUNCHER's argument in
     `pilot_probe.ps1`, not picked by comparing columns here).
  4. The selected configuration is the per-dimension MEDIAN of `P`, snapped to that dimension's
     nearest declared grid value. Not the best row: the centre of the plateau.
  5. BOUNDARY: a median landing on the first or last declared grid value of ANY dimension flags the
     cell `BOUNDARY`; the grid is expanded and re-run, and the cell is NOT closed on it.
  6. (not this file) The selected configuration is RE-RUN once before it reaches `ORDER-1254`.

THE GRID IS THE STORE'S, NOT THIS FILE'S. The declared grid per dimension is
`safe_range{start, step, stop}` read from `_triage/factory_os/registry.py` -- the same one resolver
`pilot_probe.ps1` swept from, invoked the same way. Hardcoding the grid here would let a later edit
move a boundary without touching the store, which is the whole defence.

WHAT THIS DOES NOT DO. It reads no profit factor, no profit, no drawdown, and it issues no verdict.
`Result` and `Trades` are the only two result-bearing columns it touches, and the order names both
in advance. Design section 10 stops this slice at EVIDENCE_COMPLETE.

THREE ROUNDING RULES THE ORDER DID NOT PIN, STATED HERE RATHER THAN LEFT TO A READER:
  * |P| = ceil(0.10 * |A|). Ceiling, because floor would make `P` EMPTY for any `A` smaller than
    ten and turn "few admissible passes" into "no selection" through arithmetic rather than through
    the pre-registered rule.
  * ties at the 10 % cut are broken by ascending `Pass` number, so the plateau set is a function of
    the surface and not of dict ordering.
  * 🔴 a median landing EXACTLY BETWEEN two declared grid values snaps to the LOWER one. This was
    the third rule and it was undocumented until an audit measured it: **7 of the 136 dimension
    medians in the committed selection are exact ties**, and on `B14-H01-r1/EURUSD/H1` and
    `B14-H02-r1/EURUSD/H4` the direction decides whether `_14_DistAtrMult` is reported as sitting on
    a grid edge -- which is what `ORDER-1302` widens a `safe_range` for. Neither cell's overall
    status changes (both are `BOUNDARY` either way), so nothing already committed is wrong; but an
    unstated rule was choosing which ranges get widened. The direction is NOT changed here --
    changing it now would be choosing a rule after seeing the surfaces, which is `ORDER-1220` --
    it is documented, recorded in every row as `snap_tie_break`, and asserted by the cage.
All three are recorded in every output row so a reader never has to infer them.

EXIT CODES, and the third one is not an error condition:
  0  the selection was derived (and, under --check, matches the committed record)
  1  --check found DRIFT between the committed record and what the surfaces now generate
  2  CANNOT ANSWER -- the probe XMLs are not on this machine. `_mt5_auto/optimizations/` is
     GITIGNORED (.gitignore:74) and each surface is 3-4 MB, so a clone legitimately does not carry
     them. That is a different thing from "the store is wrong" and must never be reported as one,
     and it must never be reported as a pass either.

USAGE
  tools\\python312\\python.exe scripts/pilot_probe_select.py            # write the selection record
  tools\\python312\\python.exe scripts/pilot_probe_select.py --dry-run  # print, write nothing
  tools\\python312\\python.exe scripts/pilot_probe_select.py --check    # re-derive, diff, write nothing
"""

import glob
import io
import json
import math
import os
import re
import statistics
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

PY = os.path.join(ROOT, 'tools', 'python312', 'python.exe')
RESOLVER = os.path.join(ROOT, '_triage', 'factory_os', 'registry.py')
COVERAGE = os.path.join(ROOT, 'factory', 'coverage.jsonl')
PROBE_DIR = os.path.join(ROOT, 'factory', 'runs', 'pilot', 'probe')
OUT_DIR = os.path.join(ROOT, 'factory', 'runs', 'pilot', 'selection')
ENTITY = 'PilotProbeSelection'

# The exit codes the docstring pins. Named so a caller reads intent instead of an integer.
EXIT_OK, EXIT_DRIFT, EXIT_CANNOT_ANSWER = 0, 1, 2


class CannotAnswer(Exception):
    """The surfaces are not on THIS machine. Not a violation -- see the exit-code block."""

# ORDER-1273 item 1, quoted. Not a default and not tunable from the command line: a floor that can
# be passed as an argument is a floor that can be lowered to produce a selection.
TRADE_FLOOR = {'H1': 100, 'H4': 60}
PLATEAU_FRACTION = 0.10
CRITERION_COLUMN = 'Result'
FLOOR_COLUMN = 'Trades'


def resolve_dimensions(revision):
    """-> {name: {'start','step','stop'}} for the revision's swept dimensions.

    THE SAME QUERY `pilot_probe.ps1` MAKES, so the dimensions selected from are exactly the
    dimensions swept. A dimension the sweep produced but the store no longer calls TUNABLE would
    be a store edit, and it must surface as a mismatch rather than be silently selected over.
    """
    out = subprocess.run([PY, RESOLVER, 'resolve', revision, '--build-tag=14'],
                         cwd=ROOT, capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit('pilot_probe_select: the ParameterBinding resolver refused for %s: %s'
                         % (revision, (out.stderr or out.stdout).strip()[:400]))
    dims = {}
    for name, b in json.loads(out.stdout).items():
        if b.get('role') == 'TUNABLE' and b.get('optimizable') is True and b.get('safe_range'):
            r = b['safe_range']
            dims[name] = {'start': float(r['start']), 'step': float(r['step']),
                          'stop': float(r['stop'])}
    if not dims:
        raise SystemExit('pilot_probe_select: %s resolves ZERO sweepable dimensions, so there is '
                         'no surface to select a configuration out of.' % revision)
    return dims


def grid_values(rng):
    """-> the declared grid, start..stop by step, as floats rounded to the step's precision.

    Accumulating `start + k*step` in binary floats puts 1.7000000000000002 next to a declared 1.7
    and a nearest-value snap would then never be exact. The rounding is to the number of decimals
    the declaration itself carries, so the grid this returns is the grid as WRITTEN.
    """
    dec = max(_decimals(rng['start']), _decimals(rng['step']), _decimals(rng['stop']))
    vals, k = [], 0
    while True:
        v = round(rng['start'] + k * rng['step'], dec)
        if (rng['step'] > 0 and v > rng['stop'] + 1e-9) or k > 100000:
            break
        vals.append(v)
        k += 1
        if rng['step'] <= 0:
            raise SystemExit('pilot_probe_select: a declared step of %r cannot enumerate a grid'
                             % rng['step'])
    return vals


def _decimals(x):
    s = repr(float(x))
    return len(s.split('.')[1].rstrip('0')) if '.' in s and not s.endswith('.0') else 0


def read_surface(xml_path):
    """-> (header, rows) where rows are lists of raw strings, header VERIFIED to be a header.

    Structural only. The header's first cell must read `Pass`, exactly as
    `pilot_probe_verify_xml.count_passes` requires -- if it does not, this refuses rather than
    treating a result row as column names, which would shift every column by one and select on
    whatever landed under the name `Trades`.
    """
    raw = io.open(xml_path, 'rb').read()
    text = raw.decode('utf-16' if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8', 'replace')
    blocks = re.findall(r'<Row[^>]*>(.*?)</Row>', text, re.S)
    if not blocks:
        raise SystemExit('pilot_probe_select: %s contains no <Row> elements'
                         % os.path.basename(xml_path))
    header = [c.strip() for c in re.findall(r'<Data[^>]*>(.*?)</Data>', blocks[0], re.S)]
    if not header or header[0] != 'Pass':
        raise SystemExit('pilot_probe_select: %s row 0 starts with %r, not `Pass`.'
                         % (os.path.basename(xml_path), (header or ['<empty>'])[0][:40]))
    rows = []
    for b in blocks[1:]:
        cells = [c.strip() for c in re.findall(r'<Data[^>]*>(.*?)</Data>', b, re.S)]
        if len(cells) != len(header):
            # A ragged row is not dropped quietly: the count would then disagree with
            # `count_passes` and nothing would say why.
            raise SystemExit('pilot_probe_select: %s has a row with %d cells against a %d-cell '
                             'header. Refusing to guess which column is which.'
                             % (os.path.basename(xml_path), len(cells), len(header)))
        rows.append(cells)
    return header, rows


def select_one(cell, dims):
    """-> the selection record for ONE cell. Pure: it reads a surface and returns a dict."""
    xml = cell['xml']
    header, rows = read_surface(xml)

    # THE ARTEFACT MUST STILL BE THE ONE THAT WAS MEASURED. `trial_count` in the coverage store is
    # a COMMITTED number, written by `pilot_probe_verify_xml.py` from this file at a known time;
    # `len(rows)` is what the file says now. A silent disagreement means the XML on disk is not the
    # surface the store registered -- overwritten by a later run, or a different cell's report at
    # the same path -- and a selection made out of it would carry a cell_id it does not belong to.
    #
    # 🔴 The first version of this check compared `len(rows)` to `pilot_probe_verify_xml`'s own
    # count. That was a TAUTOLOGY: both count `<Row>` minus the header with the same regex over the
    # same bytes, so it could never fire, and it read as cross-validation while validating nothing
    # (memory `falsifier-satisfied-by-unexercised-mechanism`). This compares the live file against a
    # committed number instead, which is a comparison that can actually come out unequal.
    if cell['trial_count'] != len(rows):
        raise SystemExit('pilot_probe_select: %s carries %d scored configurations, but the '
                         'coverage store registered %d for %s. The artefact is not the surface the '
                         'store measured; refusing to select out of it.'
                         % (os.path.basename(xml), len(rows), cell['trial_count'], cell['cell_id']))

    for col in (CRITERION_COLUMN, FLOOR_COLUMN, 'Pass'):
        if col not in header:
            raise SystemExit('pilot_probe_select: %s has no `%s` column. Columns present: %s'
                             % (os.path.basename(xml), col, ', '.join(header)))
    missing = [d for d in dims if d not in header]
    if missing:
        raise SystemExit('pilot_probe_select: %s does not carry the swept dimension(s) %s that the '
                         'registry resolves for %s. The surface and the store disagree about what '
                         'was swept, so no configuration can be read out of it.'
                         % (os.path.basename(xml), ', '.join(sorted(missing)), cell['revision']))

    i_res, i_tr, i_pass = header.index(CRITERION_COLUMN), header.index(FLOOR_COLUMN), header.index('Pass')
    if cell['tf'] not in TRADE_FLOOR:
        # A REFUSAL, not a KeyError. ORDER-1273 pins a floor per timeframe and names two; a cell on
        # a third has no pre-registered floor, and inventing one here -- or dying with a traceback
        # that a caller reads as "the tool is broken" -- are both worse than saying so.
        raise SystemExit('pilot_probe_select: %s is on timeframe %r and ORDER-1273 pins a trade '
                         'floor only for %s. A cell on a timeframe the criterion does not name has '
                         'no floor, and this will not invent one.'
                         % (cell['cell_id'], cell['tf'], ', '.join(sorted(TRADE_FLOOR))))
    floor = TRADE_FLOOR[cell['tf']]

    admissible = []
    for r in rows:
        try:
            trades = int(float(r[i_tr]))
        except ValueError:
            continue
        if trades >= floor:
            admissible.append(r)

    rec = {
        'entity': ENTITY,
        'cell_id': cell['cell_id'],
        'hypothesis_revision': cell['revision'],
        'logical_symbol': cell['symbol'],
        'tf': cell['tf'],
        'xml': xml.replace(os.sep, '/'),
        'artefact_resolved_by': cell.get('artefact_resolved_by', 'recorded path'),
        'criterion_order': 'ORDER-1273',
        'criterion_column': CRITERION_COLUMN,
        'floor_column': FLOOR_COLUMN,
        'trade_floor': floor,
        'plateau_fraction': PLATEAU_FRACTION,
        'plateau_size_rule': 'ceil(0.10 * |A|); ties at the cut broken by ascending Pass',
        # RECORDED, because it is a rule the order did not pin and it decides which dimensions
        # ORDER-1302 widens a safe_range for. See the module docstring: 7 of 136 medians here are
        # exact ties.
        'snap_tie_break': 'a median exactly between two declared grid values snaps to the LOWER',
        'scored_configurations': len(rows),
        'admissible_count': len(admissible),
        'dimensions': sorted(dims),
        'selected_by': 'scripts/pilot_probe_select.py',
        'selected_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'no_verdict': ('This record states which configuration the pre-registered criterion picks '
                       'out of a Model-1 MAIN search surface. It is not a verdict, not a claim of '
                       'edge, and not evidence the cell passes anything: design 6.2 makes BWD the '
                       'hard gate for this class and ORDER-1254 owns it.'),
    }

    if not admissible:
        rec['status'] = 'NO_ADMISSIBLE_PASS'
        rec['selected'] = None
        rec['why'] = ('no pass in this surface reaches %d trades, so the cell has NO selected '
                      'configuration. ORDER-1273 item 2: this is not a verdict about the EA, it is '
                      'the statement that the surface contains nothing interpretable at the '
                      'participation the policy requires. The order predicted this outcome for '
                      'most cells before any surface was read.' % floor)
        return rec

    # Sort by criterion DESC, then Pass ASC so the cut is deterministic.
    admissible.sort(key=lambda r: (-float(r[i_res]), int(float(r[i_pass]))))
    k = int(math.ceil(PLATEAU_FRACTION * len(admissible)))
    plateau = admissible[:k]

    selected, boundary = {}, []
    for name in sorted(dims):
        i = header.index(name)
        med = statistics.median([float(r[i]) for r in plateau])
        grid = grid_values(dims[name])
        snapped = min(grid, key=lambda g: (abs(g - med), g))
        selected[name] = snapped
        if snapped == grid[0] or snapped == grid[-1]:
            boundary.append({'dimension': name, 'value': snapped, 'raw_median': med,
                             'edge': 'first' if snapped == grid[0] else 'last',
                             'grid': [grid[0], grid[-1]], 'step': dims[name]['step']})

    rec['plateau_size'] = k
    rec['plateau_cut_result'] = float(plateau[-1][i_res])
    rec['plateau_trades_min'] = min(int(float(r[i_tr])) for r in plateau)
    rec['plateau_trades_max'] = max(int(float(r[i_tr])) for r in plateau)
    rec['selected'] = selected
    rec['boundary_dimensions'] = boundary
    rec['status'] = 'BOUNDARY' if boundary else 'SELECTED'
    rec['why'] = ('%d of %d scored configurations clear the %s floor of %d; the plateau set is the '
                  'top %d by %s; the configuration is the per-dimension median of that set snapped '
                  'to the declared grid.'
                  % (len(admissible), len(rows), cell['tf'], floor, k, CRITERION_COLUMN))
    if boundary:
        rec['why'] += (' %d dimension(s) landed on a declared grid edge, so ORDER-1273 item 5 '
                       'applies: the grid is EXPANDED and re-run, and this cell is not closed on '
                       'the value below.' % len(boundary))
    return rec


def artefact_by_cell(probe_dir=None):
    """-> {cell_id: xml path} from the COMMITTED back-fill records, not from a naming rule.

    🔴 THIS USED TO REBUILD THE PATH: `'S13PROBE_%s.xml' % slug`, which is a SECOND implementation
    of `pilot_probe.ps1`'s report-naming rule living four directories away from the first. Two
    copies of a naming convention drift, and the failure is silent in the bad direction -- rename
    the convention on the producer side and this reads a stale file whose name still matches.
    `factory/runs/pilot/probe/xml_backfill_*.jsonl` already records, per cell, WHICH artefact was
    measured; that is committed evidence and it is what `gen_pilot_cells` counts passes from. Read
    it instead of re-deriving it.

    The recorded path is absolute and machine-specific (`D:\\EA_LAB\\...`), so a clone elsewhere is
    also tried at `<this repo>/_mt5_auto/optimizations/<basename>` -- stated rather than silent, and
    the row records which of the two answered.
    """
    out = {}
    for path in sorted(glob.glob(os.path.join(probe_dir or PROBE_DIR, 'xml_backfill_*.jsonl'))):
        with io.open(path, encoding='utf-8') as fh:
            for line in fh:
                if not line.strip():
                    continue
                rec = json.loads(line)
                if rec.get('cell_id') and rec.get('xml') and rec.get('passes') is not None:
                    out[rec['cell_id']] = rec['xml']
    return out


def cells_from_coverage(coverage=None, probe_dir=None):
    """-> the pilot cells, from the coverage store, joined to the artefact each probe produced.

    `coverage` / `probe_dir` are for the cage: without them the absent-artefact path could only be
    exercised by hiding files from the real repository, which is not a repeatable test.

    The cell list is READ, never typed: `factory/coverage.jsonl` is the canonical store and a cell
    that is not in it has no probe to select out of.

    An artefact that is ABSENT raises `CannotAnswer`, not `SystemExit`. `_mt5_auto/optimizations/`
    is gitignored (.gitignore:74) and the surfaces are 3-4 MB each, so a clone legitimately does not
    carry them -- and this module is driven by a suite on the pre-commit path. Conflating "not on
    this machine" with "the store is wrong" would block every commit in a fresh clone with a message
    blaming the coverage store. An artefact whose PATH is not recorded at all is a different thing
    and stays a refusal: that means the store says PROBE_RUN while no back-fill row names what it
    was probed from.
    """
    known = artefact_by_cell(probe_dir)
    cells, absent = [], []
    with io.open(coverage or COVERAGE, encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            row = json.loads(line)
            if row.get('entity') != 'CoverageCell' or row.get('state') != 'PROBE_RUN':
                continue
            cid = row['cell_id']
            if cid not in known:
                raise SystemExit('pilot_probe_select: %s is at PROBE_RUN but no back-fill record '
                                 'names the artefact it was probed from. The store claims a probe '
                                 'that nothing identifies; refusing to guess the filename.' % cid)
            if not isinstance(row.get('trial_count'), int) or row['trial_count'] <= 0:
                raise SystemExit('pilot_probe_select: %s is at PROBE_RUN with trial_count=%r. A '
                                 'cell that scored nothing is not a probe, and the artefact check '
                                 'has nothing to compare against.'
                                 % (cid, row.get('trial_count')))
            xml, how = known[cid], 'recorded path'
            if not os.path.isfile(xml):
                alt = os.path.join(ROOT, '_mt5_auto', 'optimizations', os.path.basename(xml))
                if os.path.isfile(alt):
                    xml, how = alt, 'this repo, by basename (the recorded path is another machine)'
                else:
                    absent.append('%s -> %s' % (cid, os.path.basename(xml)))
                    continue
            cells.append({'cell_id': cid, 'revision': row['hypothesis_revision'],
                          'symbol': row['logical_symbol'], 'tf': row['tf'],
                          'xml': xml, 'artefact_resolved_by': how,
                          'trial_count': row['trial_count']})
    if absent:
        raise CannotAnswer(
            '%d probe surface(s) are not on this machine: %s. `_mt5_auto/optimizations/` is '
            'gitignored and each file is 3-4 MB, so a clone does not carry them. This is NOT a '
            'statement that the coverage store or the selection record is wrong -- it is this '
            'reader saying it cannot see what it would have to read.'
            % (len(absent), '; '.join(absent)))
    return sorted(cells, key=lambda c: c['cell_id'])


def _rel(path):
    """-> `path` relative to the repo, or the path itself when that is not expressible.

    `os.path.relpath` RAISES on Windows when the two are on different drives -- it does not fall
    back. Found by the cage, whose temp root is on C: while the repo is on D:; the same throw would
    hit anyone whose repo and record live on different mounts, and it would arrive as a ValueError
    traceback out of a function whose job is to print a filename.
    """
    try:
        return os.path.relpath(path, ROOT).replace(os.sep, '/')
    except ValueError:
        return path.replace(os.sep, '/')


def committed_record(out_dir=None):
    """-> (path, [rows]) for the CURRENT selection record, or (None, []) if none exists.

    SUPERSESSION IS STATED, not left to a reader. Each run writes a new timestamped file, so the
    directory accumulates; the CURRENT record is the newest by filename (the stamp is
    `%Y%m%d_%H%M%S`, so lexical order is chronological order). Without this rule a reader facing two
    files has to guess which one the repo means, and `--check` would have to guess the same thing.
    """
    hits = sorted(glob.glob(os.path.join(out_dir or OUT_DIR, 'selection_*.jsonl')))
    if not hits:
        return None, []
    rows = []
    with io.open(hits[-1], encoding='utf-8') as fh:
        for line in fh:
            if line.strip():
                rows.append(json.loads(line))
    return hits[-1], rows


# Fields that are provenance rather than result: a re-derivation on another day or another clone
# legitimately differs on these, and diffing them would make --check permanently red for reasons
# that say nothing about the selection.
VOLATILE = ('selected_utc', 'xml', 'artefact_resolved_by')


def check_against_record(records, out_dir=None):
    """-> exit code. Re-derived selections vs the committed record, field by field."""
    path, committed = committed_record(out_dir)
    if path is None:
        print('[selection] no committed selection record exists yet; nothing to check against')
        return EXIT_DRIFT
    want = {r['cell_id']: {k: v for k, v in r.items() if k not in VOLATILE} for r in records}
    got = {r['cell_id']: {k: v for k, v in r.items() if k not in VOLATILE} for r in committed}
    problems = []
    for cid in sorted(set(want) | set(got)):
        if cid not in got:
            problems.append('MISSING %s -- derivable from the surfaces, not in the record' % cid)
        elif cid not in want:
            problems.append('UNDERIVABLE %s -- in the record, not derivable from the surfaces' % cid)
        else:
            for k in sorted(set(want[cid]) | set(got[cid])):
                if want[cid].get(k) != got[cid].get(k):
                    problems.append('%s.%s committed=%r generated=%r'
                                    % (cid, k, got[cid].get(k), want[cid].get(k)))
    rel = _rel(path)
    if problems:
        print('[selection] DRIFT: %s does not match what the surfaces now generate' % rel)
        for p in problems:
            print('  %s' % p)
        return EXIT_DRIFT
    print('[selection] %s holds exactly the %d row(s) the surfaces generate'
          % (rel, len(committed)))
    return EXIT_OK


def main(argv):
    dry = '--dry-run' in argv
    check = '--check' in argv
    cells = cells_from_coverage()
    if not cells:
        print('no cell is at PROBE_RUN; nothing to select')
        return EXIT_DRIFT
    dim_cache, records = {}, []
    for c in cells:
        if c['revision'] not in dim_cache:
            dim_cache[c['revision']] = resolve_dimensions(c['revision'])
        records.append(select_one(c, dim_cache[c['revision']]))

    for r in records:
        print('%-24s %-9s %5d/%-5d admissible  %s'
              % (r['cell_id'], r['status'], r['admissible_count'], r['scored_configurations'],
                 '' if r['selected'] is None else
                 ' '.join('%s=%g' % (k, v) for k, v in sorted(r['selected'].items()))))
        for b in r.get('boundary_dimensions', []):
            print('      BOUNDARY %s = %g (%s edge of %g..%g)'
                  % (b['dimension'], b['value'], b['edge'], b['grid'][0], b['grid'][1]))

    counts = {}
    for r in records:
        counts[r['status']] = counts.get(r['status'], 0) + 1
    print('')
    print('%d cell(s): %s' % (len(records),
                              ' | '.join('%s %d' % (k, counts[k]) for k in sorted(counts))))
    if check:
        return check_against_record(records)
    if dry:
        print('--dry-run: nothing written')
        return EXIT_OK
    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)
    out = os.path.join(OUT_DIR, 'selection_%s.jsonl' % time.strftime('%Y%m%d_%H%M%S'))
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        for r in records:
            fh.write(json.dumps(r, sort_keys=True) + '\n')
    print('wrote %d row(s) -> %s' % (len(records), _rel(out)))
    return EXIT_OK


if __name__ == '__main__':
    # EXIT 2 IS NOT EXIT 1. "The surfaces are not on this machine" and "the record disagrees with
    # the surfaces" send a reader to two different places, and the first is a legitimate state of
    # any clone because `_mt5_auto/optimizations/` is gitignored.
    try:
        sys.exit(main(sys.argv[1:]))
    except CannotAnswer as exc:
        print('[selection] CANNOT ANSWER: %s' % exc)
        sys.exit(EXIT_CANNOT_ANSWER)
