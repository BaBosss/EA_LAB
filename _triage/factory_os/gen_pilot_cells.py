# -*- coding: utf-8 -*-
"""ORDER-1250 -- register the 16 pilot cells as real `CoverageCell` rows.

WHY THIS EXISTS
  `check_pilot_acceptance.py` reports item 7 of design 8.6 -- "16/16 cells reach Baseline +
  probe, or carry a written NOT_APPLICABLE reason" -- as BLOCKED with the reason
  "needs the pilot cell result store ... factory/runs/ has no cell entity". The runs DO exist
  (`factory/runs/pilot/pilot_cells_MAIN_lot0p03_*.jsonl`, 48 rows = 16 cells x 3 arms) and they
  are typed `PilotCellRun`, which is not an entity `schemas.json` knows. Nothing could route
  them to a contract, so nothing could judge them.

  `registry.STORES` has always declared `factory/coverage.jsonl` to be the CoverageCell store,
  and both `check_registries.check_r5` and `run_schema_fixtures`' live-row block carry an
  explicit exemption for the ORDER-610 imported rows that reads, verbatim, "it ends when S5's
  real CoverageCell rows land". These are those rows.

WHAT IT DOES *NOT* DO
  It writes no verdict and it does not decide whether a cell is any good. `state` is the
  furthest point the cell's OWN evidence reaches, and for every cell today that is
  `BASELINE_RUN` -- NOT `PROBE_RUN`. The probe design 8.3 means is the decision-13 optimize
  probe, and it has not been run. The flat-lot arm that HAS been run is H01's FALSIFIER, a
  different thing that answers a different question, and ticking item 7 from it is prohibited by
  name in the handoff this order came from.

  It also registers ONE metric per cell -- the BASELINE arm's. `MetricRef` has no field naming
  which arm produced it, so two MAIN-window metrics in one cell would be two numbers a reader
  cannot tell apart. Widening MetricRef to carry an arm is not what the owner ratified; the
  falsifier arms stay in the run store, which is where the comparison is made.

DETERMINISM
  Every field is derived from the source run record. `--check` regenerates and compares against
  the committed store, so a hand edit to either side is a diff rather than a silent divergence.

USAGE
  tools\\python312\\python.exe _triage/factory_os/gen_pilot_cells.py --check
  tools\\python312\\python.exe _triage/factory_os/gen_pilot_cells.py --apply
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import registry as reg                                                       # noqa: E402

# The source of truth for the cell facts: the run store the pilot matrix wrote. Pinned by NAME
# rather than by "the newest file in the directory" -- a generator that picks up whatever ran
# last would silently re-point at a different sizing, and the whole reason this file exists is
# that the matrix has already been run at two different first lots with different answers.
SOURCE = 'factory/runs/pilot/pilot_cells_MAIN_lot0p03_20260803_123147.jsonl'
COVERAGE = 'factory/coverage.jsonl'

# The universe these cells belong to. It is NOT 'v1': `factory/universe.jsonl` does not exist --
# `registry.STORES_BLOCKED` records that creating it costs an owner signature -- so there is no
# registered TestUniverse to name. This string names the universe DESIGN 8.3 declares
# (XAUUSD/EURUSD/USDJPY/BTCUSD x H1/H4), and the mismatch is deliberate and visible rather than
# a 'v1' that would imply a store behind it.
UNIVERSE_VERSION = 'design-8.3-pilot'

# The arm whose numbers become the cell's registered metric. See the docstring.
REGISTERED_ARM = 'baseline'


def load_source(path=None):
    path = path or os.path.join(ROOT, SOURCE)
    rows = []
    with io.open(path, encoding='utf-8') as fh:
        for line in fh:
            if line.strip():
                rows.append(json.loads(line))
    return rows


def build_cells(runs):
    """-> [CoverageCell], one per cell_id, ordered as the source orders them.

    REFUSES rather than guessing. A cell whose baseline arm is missing, or whose metric fields
    are absent, is not registered as a cell with a hole in it: this generator's output feeds a
    checker that reports evidence completeness, and a row that quietly omits a drawdown would
    be read as a cell that was measured.
    """
    by_cell = {}
    order = []
    for r in runs:
        cid = r.get('cell_id')
        if cid is None:
            raise SystemExit('gen_pilot_cells: a source row has no cell_id: %r' % (r,))
        if cid not in by_cell:
            by_cell[cid] = {}
            order.append(cid)
        arm = r.get('arm')
        if arm in by_cell[cid]:
            raise SystemExit('gen_pilot_cells: cell %s has two %r arms; the source is ambiguous '
                             'about which run the cell was measured on' % (cid, arm))
        by_cell[cid][arm] = r

    cells = []
    for cid in order:
        arms = by_cell[cid]
        base = arms.get(REGISTERED_ARM)
        if base is None:
            raise SystemExit('gen_pilot_cells: cell %s has no %r arm, so it has no baseline to '
                             'register' % (cid, REGISTERED_ARM))

        # pf and pf_state, the ORDER-1250 pair. The source already distinguishes the two states
        # honestly -- it writes `pf: null` with `pf_undefined: true` -- so this is a rename into
        # the schema's vocabulary, not a re-derivation. Both halves are asserted anyway, because
        # a mismatch here would put a number under the "no denominator" label, which is the
        # single inversion the whole field exists to prevent.
        pf = base.get('pf')
        undef = base.get('pf_undefined')
        if undef is None:
            raise SystemExit('gen_pilot_cells: cell %s baseline has no pf_undefined flag; the '
                             'source predates the honest-PF fix and must not be registered' % cid)
        if bool(undef) != (pf is None):
            raise SystemExit('gen_pilot_cells: cell %s baseline has pf=%r with pf_undefined=%r. '
                             'The source contradicts itself about whether the profit factor has '
                             'a denominator; registering either reading would be a guess.'
                             % (cid, pf, undef))
        pf_state = 'UNDEFINED_NO_LOSSES' if undef else 'DEFINED'

        for field in ('trades', 'dd_pct', 'data_fingerprint', 'lane', 'model', 'window', 'report'):
            if base.get(field) is None:
                raise SystemExit('gen_pilot_cells: cell %s baseline has no %r' % (cid, field))

        # `run_id` is the tester REPORT this metric was read out of -- the artifact, not a
        # minted identifier. A `RUN-YYYYMMDD-NNN` string would look like a RunJournal id and
        # resolve to nothing; the report basename joins straight back to the run store row and
        # to the file on disk.
        run_id = os.path.splitext(os.path.basename(base['report']))[0]

        metric = {
            'window': base['window'],
            'pf': pf,
            'pf_state': pf_state,
            'trades': base['trades'],
            'dd_pct': base['dd_pct'],
            'run_id': run_id,
            'lane': base['lane'],
            'data_fingerprint': base['data_fingerprint'],
            'model': base['model'],
        }
        cells.append({
            'entity': 'CoverageCell',
            'cell_id': cid,
            'hypothesis_revision': base['hypothesis_revision'],
            'logical_symbol': base['logical_symbol'],
            'tf': base['tf'],
            'universe_version': UNIVERSE_VERSION,
            # BASELINE_RUN, never PROBE_RUN. See the module docstring: the probe design 8.3 owes
            # each cell is the decision-13 OPTIMIZE probe, and it has not been run.
            'state': 'BASELINE_RUN',
            'metrics': [metric],
            # Zero parameter trials have been spent on these cells. The first lot was resolved by
            # a mechanical criterion that never reads a PF, which is a sizing pin and not a trial.
            'trial_count': 0,
        })
    return cells


def read_store(path=None):
    """-> (meta_lines, imported_rows, native_rows) with the raw text of each line kept."""
    path = path or os.path.join(ROOT, COVERAGE)
    meta, imported, native = [], [], []
    with io.open(path, encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            obj = json.loads(line)
            if reg.classify_record(obj, where=COVERAGE) == 'META':
                meta.append(line.rstrip('\n'))
            elif obj.get('entity') == 'CoverageCell':
                native.append(obj)
            else:
                imported.append(line.rstrip('\n'))
    return meta, imported, native


def write_store(cells, path=None):
    path = path or os.path.join(ROOT, COVERAGE)
    meta, imported, _native = read_store(path)
    out = meta + imported + [reg.canonical_line(c) for c in cells]
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(out) + '\n')


def main(argv):
    mode = argv[1] if len(argv) > 1 else '--check'
    if mode not in ('--check', '--apply'):
        print('usage: gen_pilot_cells.py [--check|--apply]')
        return 2
    cells = build_cells(load_source())
    if mode == '--apply':
        write_store(cells)
        print('[pilot-cells] wrote %d CoverageCell row(s) to %s' % (len(cells), COVERAGE))
        return 0

    _meta, _imported, native = read_store()
    want = [json.loads(reg.canonical_line(c)) for c in cells]
    if native == want:
        print('[pilot-cells] %s holds exactly the %d CoverageCell row(s) derivable from %s'
              % (COVERAGE, len(want), SOURCE))
        return 0
    print('[pilot-cells] DRIFT: the store does not match what the run evidence generates')
    print('  committed native rows: %d   generated: %d' % (len(native), len(want)))
    by_id = {c.get('cell_id'): c for c in native}
    for w in want:
        got = by_id.get(w['cell_id'])
        if got is None:
            print('  MISSING %s' % w['cell_id'])
        elif got != w:
            for k in sorted(set(got) | set(w)):
                if got.get(k) != w.get(k):
                    print('  %s.%s committed=%r generated=%r'
                          % (w['cell_id'], k, got.get(k), w.get(k)))
    extra = [c.get('cell_id') for c in native if c.get('cell_id') not in {w['cell_id'] for w in want}]
    for e in extra:
        print('  UNDERIVABLE %s -- in the store, not generated by the run evidence' % e)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
