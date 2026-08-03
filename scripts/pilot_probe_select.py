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

TWO ROUNDING RULES THE ORDER DID NOT PIN, STATED HERE RATHER THAN LEFT TO A READER:
  * |P| = ceil(0.10 * |A|). Ceiling, because floor would make `P` EMPTY for any `A` smaller than
    ten and turn "few admissible passes" into "no selection" through arithmetic rather than through
    the pre-registered rule.
  * ties at the 10 % cut are broken by ascending `Pass` number, so the plateau set is a function of
    the surface and not of dict ordering.
Both are recorded in every output row so a reader never has to infer them.

USAGE
  tools\\python312\\python.exe scripts/pilot_probe_select.py            # write the selection record
  tools\\python312\\python.exe scripts/pilot_probe_select.py --dry-run  # print, write nothing
"""

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
OUT_DIR = os.path.join(ROOT, 'factory', 'runs', 'pilot', 'selection')
ENTITY = 'PilotProbeSelection'

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
        'criterion_order': 'ORDER-1273',
        'criterion_column': CRITERION_COLUMN,
        'floor_column': FLOOR_COLUMN,
        'trade_floor': floor,
        'plateau_fraction': PLATEAU_FRACTION,
        'plateau_size_rule': 'ceil(0.10 * |A|); ties at the cut broken by ascending Pass',
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


def cells_from_coverage():
    """-> the pilot cells, from the coverage store, with the XML path each probe produced.

    The cell list is READ, never typed: `factory/coverage.jsonl` is the canonical store and a cell
    that is not in it has no probe to select out of. The XML path is rebuilt from the same naming
    rule `pilot_probe.ps1` writes with, and its existence is checked -- a selection made against a
    missing artefact would be a selection out of nothing.
    """
    cells = []
    with io.open(COVERAGE, encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            row = json.loads(line)
            if row.get('entity') != 'CoverageCell' or row.get('state') != 'PROBE_RUN':
                continue
            rev, symbol, tf = row['hypothesis_revision'], row['logical_symbol'], row['tf']
            slug = '%s_%s_%s' % (rev.replace('-', '_'), symbol, tf)
            xml = os.path.join(ROOT, '_mt5_auto', 'optimizations', 'S13PROBE_%s.xml' % slug)
            if not os.path.isfile(xml):
                raise SystemExit('pilot_probe_select: %s is at PROBE_RUN but %s does not exist. A '
                                 'cell cannot be selected out of an artefact that is not there.'
                                 % (row['cell_id'], os.path.relpath(xml, ROOT)))
            if not isinstance(row.get('trial_count'), int) or row['trial_count'] <= 0:
                raise SystemExit('pilot_probe_select: %s is at PROBE_RUN with trial_count=%r. A '
                                 'cell that scored nothing is not a probe, and the artefact check '
                                 'below has nothing to compare against.'
                                 % (row['cell_id'], row.get('trial_count')))
            cells.append({'cell_id': row['cell_id'], 'revision': rev, 'symbol': symbol,
                          'tf': tf, 'xml': xml, 'trial_count': row['trial_count']})
    return sorted(cells, key=lambda c: c['cell_id'])


def main(argv):
    dry = '--dry-run' in argv
    cells = cells_from_coverage()
    if not cells:
        print('no cell is at PROBE_RUN; nothing to select')
        return 1
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
    if dry:
        print('--dry-run: nothing written')
        return 0
    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)
    out = os.path.join(OUT_DIR, 'selection_%s.jsonl' % time.strftime('%Y%m%d_%H%M%S'))
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        for r in records:
            fh.write(json.dumps(r, sort_keys=True) + '\n')
    print('wrote %d row(s) -> %s' % (len(records), os.path.relpath(out, ROOT).replace(os.sep, '/')))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
