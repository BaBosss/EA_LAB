"""Did the SELECTED configuration ever get evaluated on the surface it was selected from?

WHY (ORDER-1273 step 6)
  `pilot_probe_select.py` picks the per-dimension MEDIAN of the plateau set and snaps it to the
  declared grid. A per-dimension median need not correspond to any row that was actually evaluated
  -- the selected point can be a corner of the grid that the genetic optimizer never visited. That
  is the whole reason step 6 exists, and it is a question about the surface, answerable offline,
  BEFORE any tester time is spent.

  This tool answers exactly that and nothing else:
      does a row exist whose swept dimensions all equal the selected values, and if so what did the
      optimizer record for it?

  It issues no verdict and computes no criterion. If the answer is "no row", the selection is an
  interpolated point and the verification run is the ONLY source of a number for it. If the answer
  is "here is the row", the verification run has something to be checked against -- and a
  disagreement between the two is a finding about the harness, not about the strategy.

READ-ONLY, AND NOT A SECOND PARSER
  The surface is read through `pilot_probe_select.read_surface`, which owns that format and already
  refuses a file whose header does not start with `Pass`. Nothing here re-implements it.

NUMERIC COMPARISON, NOT STRING COMPARISON
  The XML writes `21` where the record holds `21.0`, and `2.75` may be written `2.750000`. Comparing
  the text would report "never evaluated" for a row that is sitting right there -- a false negative
  that points the reader at exactly the wrong conclusion. Values are compared as floats with an
  absolute tolerance well below the smallest declared grid step in `parameter_bindings.jsonl`
  (0.1 for _55_LogPowerFactor), so two distinct grid points can never collapse into one.

USAGE
  python scripts/pilot_selected_surface_row.py <selection_record.jsonl> [--cell CELL_ID]
  -> one JSON object per SELECTED cell on stdout.
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot_probe_select as SEL  # noqa: E402  (path set above; single owner of the surface format)

# Well below the smallest declared grid step (0.1). Two distinct grid points cannot collapse into
# one at this tolerance, and float-repr noise cannot separate a point from itself.
TOL = 1e-6


def _num(text):
    """-> float, or None when the cell is not numeric. None never compares equal to anything."""
    try:
        return float(str(text).strip().replace(',', ''))
    except (TypeError, ValueError):
        return None


def find_row(xml_path, selected):
    header, rows = SEL.read_surface(xml_path)
    missing = [d for d in selected if d not in header]
    if missing:
        # A dimension the record names but the surface does not carry means these two artefacts are
        # not about the same sweep. Refused rather than reported as "not evaluated", which would
        # read as a fact about the optimizer instead of a mismatch between two files.
        raise SystemExit('pilot_selected_surface_row: %s has no column(s) %s -- the record and the '
                         'surface disagree about which dimensions were swept, so "was this row '
                         'evaluated" is not a question this pair can answer.'
                         % (os.path.basename(xml_path), ', '.join(sorted(missing))))
    idx = {d: header.index(d) for d in selected}
    result_i = header.index('Result') if 'Result' in header else None
    trades_i = header.index('Trades') if 'Trades' in header else None
    hits = []
    for row in rows:
        ok = True
        for d, want in selected.items():
            got = _num(row[idx[d]])
            if got is None or abs(got - float(want)) > TOL:
                ok = False
                break
        if ok:
            hits.append({
                'pass': row[0],
                'result': _num(row[result_i]) if result_i is not None else None,
                'trades': _num(row[trades_i]) if trades_i is not None else None,
            })
    return len(rows), hits


def main(argv):
    if not argv:
        raise SystemExit('usage: pilot_selected_surface_row.py <selection_record.jsonl> [--cell ID]')
    record = argv[0]
    want_cell = None
    if '--cell' in argv:
        want_cell = argv[argv.index('--cell') + 1]
    out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
    n = 0
    for line in io.open(record, encoding='utf-8'):
        line = line.strip()
        if not line:
            continue
        rec = json.loads(line)
        if rec.get('status') != 'SELECTED':
            continue
        if want_cell and rec.get('cell_id') != want_cell:
            continue
        total, hits = find_row(rec['xml'], rec['selected'])
        n += 1
        out.write(json.dumps({
            'cell_id': rec['cell_id'],
            'xml': rec['xml'],
            'surface_rows': total,
            'selected': rec['selected'],
            'evaluated_on_surface': len(hits) > 0,
            'matching_rows': hits,
            'why': ('the selected point IS a row the optimizer evaluated; the verification run has '
                    'something to be checked against'
                    if hits else
                    'the selected point was NEVER evaluated on this surface -- it is the '
                    'per-dimension median snapped to the grid, so the verification run is the only '
                    'source of a measured number for this configuration'),
            'no_verdict': ('This states whether a configuration appears in a search surface. It is '
                           'not a criterion, not a quality claim, and not evidence the cell passes '
                           'anything.'),
        }, sort_keys=True) + '\n')
    if n == 0:
        raise SystemExit('pilot_selected_surface_row: no SELECTED row matched in %s -- refusing to '
                         'exit 0 having answered nothing.' % record)
    out.flush()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
