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

# ORDER-1253 acceptance 3: the decision-13 optimize probe. Its records live in their own directory,
# one file per invocation, and they are read as a SET rather than pinned by name -- the baseline
# source is pinned because two matrices exist at two different first lots and picking "the newest"
# would silently re-point at the other sizing. That risk does not transfer: every probe record
# carries the configuration it ran under, so this reads them all and REFUSES any whose
# configuration disagrees with the baseline it is being attached to. Validating beats trusting.
PROBE_DIR = 'factory/runs/pilot/probe'
PROBE_ARM = 'optimize-probe'


def load_source(path=None):
    path = path or os.path.join(ROOT, SOURCE)
    rows = []
    with io.open(path, encoding='utf-8') as fh:
        for line in fh:
            if line.strip():
                rows.append(json.loads(line))
    return rows


def load_probe_runs(root=None):
    """-> [PilotProbeRun] across every file in the probe directory. Order is filename order."""
    import glob
    base = os.path.join(root or ROOT, PROBE_DIR.replace('/', os.sep))
    rows = []
    for path in sorted(glob.glob(os.path.join(base, '*.jsonl'))):
        name = os.path.basename(path)
        # ROUTE BY PREFIX, and REFUSE an unrecognised one. Narrowing this glob to `probe_runs_*`
        # would have been the one-character fix and it is the wrong one: a third file family
        # appearing in this directory would then be read by nobody, which is how a store grows a
        # population nothing validates (the exact shape `factory/coverage.jsonl` already had to be
        # taught). The prefixes are closed; adding one is a decision, not an accident.
        if name.startswith('xml_backfill_'):
            continue                       # read by load_xml_backfill(), deliberately separate
        if not name.startswith('probe_runs_'):
            raise SystemExit('gen_pilot_cells: %s is in %s and matches no known file family '
                             '(probe_runs_* | xml_backfill_*). Refusing rather than ignoring it.'
                             % (name, PROBE_DIR))
        with io.open(path, encoding='utf-8') as fh:
            for n, line in enumerate(fh, 1):
                if not line.strip():
                    continue
                try:
                    rec = json.loads(line)
                except ValueError as exc:
                    raise SystemExit('gen_pilot_cells: %s line %d is unparseable: %s'
                                     % (os.path.basename(path), n, exc))
                rec['_source_file'] = os.path.basename(path)
                rows.append(rec)
    return rows


def load_xml_backfill(root=None):
    """-> {xml path} asserted to exist by scripts/pilot_probe_verify_xml.py.

    A SEPARATE FILE, DELIBERATELY. The records these cover were written by a launcher that could
    exit 0 with no XML, and they predate the field that would say otherwise. Editing them to add
    the field would make the store claim an observation the instrument never made; assuming in
    their favour is the silent pass this transition exists to prevent. So the measurement is taken
    after the fact, by a named tool, and kept as its own evidence that a reader can weigh
    differently from a record the runner wrote about itself.
    """
    import glob
    base = os.path.join(root or ROOT, PROBE_DIR.replace('/', os.sep))
    out = set()
    for path in sorted(glob.glob(os.path.join(base, 'xml_backfill_*.jsonl'))):
        with io.open(path, encoding='utf-8') as fh:
            for n, line in enumerate(fh, 1):
                if not line.strip():
                    continue
                try:
                    rec = json.loads(line)
                except ValueError as exc:
                    raise SystemExit('gen_pilot_cells: %s line %d is unparseable: %s'
                                     % (os.path.basename(path), n, exc))
                if rec.get('entity') != 'PilotProbeXmlBackfill':
                    raise SystemExit('gen_pilot_cells: %s line %d is entity=%r in a back-fill file'
                                     % (os.path.basename(path), n, rec.get('entity')))
                if rec.get('xml'):
                    out.add(rec['xml'])
    return out


def probed_cells(probe_runs, baseline_by_cell, backfilled=frozenset()):
    """-> ({cell_id: record}, [excluded note]) for cells whose optimize probe DEMONSTRABLY ran.

    THE BAR IS `xml_present is True`, AND NOTHING ELSE WILL DO. `launcher_exit_code == 0` is not
    sufficient evidence for any record written before ORDER-1253's second fix, because
    mt5_optimize.ps1 printed "NO XML" and exited 0 -- a launcher reporting success with none of the
    output it exists to produce. A record from that era cannot say whether its probe ran, so it is
    not counted, and the cell stays at BASELINE_RUN until a run that CAN say so replaces it. Five
    such records exist and the honest repair is to re-run those cells, not to assume in their
    favour: the whole point of this transition is that a cell reaching PROBE_RUN was probed.

    EXACTLY ONE qualifying record per cell. Two would make "which run is this cell's probe" a
    question this generator answers by picking, and picking the newest is how a generator silently
    re-points at a different configuration -- the exact risk the pinned baseline SOURCE avoids.
    """
    qualifying, excluded = {}, []
    for rec in probe_runs:
        where = '%s (%s)' % (rec.get('cell_id'), rec.get('_source_file'))
        if rec.get('entity') != 'PilotProbeRun':
            raise SystemExit('gen_pilot_cells: %s is in the probe store but is entity=%r'
                             % (where, rec.get('entity')))
        cid = rec.get('cell_id')
        if rec.get('arm') != PROBE_ARM:
            # The deliberate-refusal arm is design 8.6 ITEM 6's evidence, not item 7's. Named, not
            # dropped: a store that silently ignores rows is a store that can hide one.
            excluded.append('%s: arm=%r is not the optimize probe' % (where, rec.get('arm')))
            continue
        if cid not in baseline_by_cell:
            # The one real occurrence: `B14-H01-r1/EURUSD,USDJPY,BTCUSD/H1,H4`, produced by the
            # `powershell -File` comma trap. It is KEPT in the store as the evidence that the
            # guard-rail was missing, so this must neither refuse forever nor skip in silence.
            excluded.append('%s: names no cell in the design 8.3 universe' % where)
            continue
        if rec.get('xml_present') is not True and rec.get('xml') not in backfilled:
            excluded.append('%s: xml_present=%r and no back-fill row names its XML, so this record '
                            'cannot demonstrate the probe produced anything (exit_code=%r is not '
                            'sufficient -- the launcher reported success without an XML until '
                            'ORDER-1253)'
                            % (where, rec.get('xml_present'), rec.get('launcher_exit_code')))
            continue
        if rec.get('launcher_exit_code') != 0:
            excluded.append('%s: launcher_exit_code=%r' % (where, rec.get('launcher_exit_code')))
            continue
        base = baseline_by_cell[cid]
        for field in ('lane', 'window', 'from_date', 'to_date', 'first_lot', 'model'):
            if rec.get(field) != base.get(field):
                raise SystemExit(
                    'gen_pilot_cells: probe %s ran with %s=%r but its baseline used %r. A probe '
                    'measured under a different configuration is not this cell\'s probe.'
                    % (where, field, rec.get(field), base.get(field)))
        if cid in qualifying:
            raise SystemExit(
                'gen_pilot_cells: cell %s has TWO qualifying optimize-probe records (%s and %s). '
                'Choosing between them is a decision, and picking the newest is how a generator '
                'silently re-points at a different run.'
                % (cid, qualifying[cid]['_source_file'], rec['_source_file']))
        qualifying[cid] = rec
    return qualifying, excluded


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

    # ORDER-1253 acceptance 3. The probe evidence, resolved ONCE for the whole matrix so that the
    # per-cell loop below only reads an answer. `excluded` is carried out to the caller and
    # PRINTED: rows the probe store holds and this generator does not count are stated by name,
    # because a store that silently ignores rows is a store that can hide one.
    baseline_by_cell = {cid: by_cell[cid][REGISTERED_ARM]
                        for cid in order if REGISTERED_ARM in by_cell[cid]}
    probed, probe_excluded = probed_cells(load_probe_runs(), baseline_by_cell, load_xml_backfill())

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
            # PROBE_RUN only when the decision-13 optimize probe DEMONSTRABLY produced a search
            # surface for THIS cell, under the same configuration the baseline measured.
            # BASELINE_RUN otherwise -- and "otherwise" includes a probe that ran but cannot show
            # it produced anything. 🚫 The flat-lot arm can never satisfy this: it is H01's
            # FALSIFIER, it is not in the probe store, and it answers a different question.
            'state': 'PROBE_RUN' if cid in probed else 'BASELINE_RUN',
            'metrics': [metric],
            # The trials the probe SPENT are not counted here, and the omission is deliberate
            # rather than an oversight. Design 6.7 defines trial_count as "the total number of
            # configurations that were ever scored", and that number lives in the optimizer XML --
            # which is not committed, so deriving it here would make this generator's output
            # depend on one machine's disk. The number belongs in the probe RECORD, written by the
            # runner that has the XML in hand, and then read from there. Until it is, 0 is the
            # honest value for "this generator has not been told", and a reader can see it has
            # not moved. Tracked with the rest of ORDER-1253.
            'trial_count': 0,
        })
    return cells, probe_excluded


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
    """Rewrite the native population from `cells`, keeping meta and imported rows verbatim.

    🔴 REFUSES TO DROP A ROW IT DID NOT GENERATE. Measured before this guard existed: adding one
    native `CoverageCell` the run evidence does not derive and calling `--apply` took the store
    from 26 rows to 25 and said nothing. `--check` calls that row UNDERIVABLE and prints it, but
    nothing forces anyone to run `--check` first, and `--apply` is the command someone reaches for
    when they already believe the store is behind. A generator that silently deletes what it
    cannot re-derive is a generator that turns "I did not understand this row" into "this row
    never existed".
    """
    path = path or os.path.join(ROOT, COVERAGE)
    meta, imported, _native = read_store(path)
    generated_ids = {c.get('cell_id') for c in cells}
    orphans = sorted(c.get('cell_id') for c in _native
                     if c.get('cell_id') not in generated_ids)
    if orphans:
        raise SystemExit(
            'gen_pilot_cells: --apply would DELETE %d native row(s) the run evidence does not '
            'derive: %s. Refusing. Either the source that produced them is missing, or they were '
            'hand-written into a generated store -- both are decisions, and neither is this '
            'command\'s to make silently. Run --check to see the full diff.'
            % (len(orphans), ', '.join(orphans)))
    out = meta + imported + [reg.canonical_line(c) for c in cells]
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(out) + '\n')


def main(argv):
    mode = argv[1] if len(argv) > 1 else '--check'
    if mode not in ('--check', '--apply'):
        print('usage: gen_pilot_cells.py [--check|--apply]')
        return 2
    cells, probe_excluded = build_cells(load_source())
    probed = sum(1 for c in cells if c['state'] == 'PROBE_RUN')
    print('[pilot-cells] %d of %d cell(s) at PROBE_RUN' % (probed, len(cells)))
    for note in probe_excluded:
        print('[pilot-cells] probe row NOT counted -- %s' % note)
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
