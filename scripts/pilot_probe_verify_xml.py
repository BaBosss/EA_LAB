# -*- coding: utf-8 -*-
"""pilot_probe_verify_xml.py -- ORDER-1253. Back-fill the artefact check the records could not make.

WHY THIS EXISTS, AND WHY IT IS A SEPARATE FILE RATHER THAN AN EDIT

`mt5_optimize.ps1` printed "NO XML" and exited 0 until ORDER-1253 fixed it, so
`launcher_exit_code == 0` in a `PilotProbeRun` written before that fix does NOT establish that the
optimizer produced anything. `pilot_probe.ps1` now records `xml_present` itself, measured
independently of the launcher's verdict -- but the field was added while a batch was already
running, and PowerShell loads a script once per invocation. So every record from that batch is
silent on the one question that matters.

There are three ways to resolve that and only one of them is honest:

  * assume in their favour -> the exact silent pass this whole transition exists to prevent;
  * EDIT the committed records to add the field -> rewriting evidence to say something the
    instrument that produced it never observed. A run store that gets edited is not a run store;
  * MEASURE the artefacts now and record the measurement as its OWN evidence, saying plainly that
    it was taken after the fact and by what. That is this file.

Re-running the affected cells was the fourth option and it was costed rather than dismissed: ~5
hours of tester wall-clock to re-derive a fact that is verifiable in milliseconds. Wall-clock is
cheap, but an unnecessary re-run also re-opens every question about determinism that the existing
records already answer.

WHAT THIS DOES NOT DO. It does not say the probe was CORRECT, that the search converged, or that
the surface means anything. It says one thing: a file exists at the path the record names, with
this many bytes, at this mtime. `gen_pilot_cells.py` treats that as satisfying `xml_present` and
nothing more.

USAGE
  tools\\python312\\python.exe scripts/pilot_probe_verify_xml.py            # write the back-fill
  tools\\python312\\python.exe scripts/pilot_probe_verify_xml.py --dry-run  # print, write nothing
"""

import glob
import io
import json
import os
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PROBE_DIR = os.path.join(ROOT, 'factory', 'runs', 'pilot', 'probe')
ENTITY = 'PilotProbeXmlBackfill'


def main(argv):
    dry = '--dry-run' in argv
    rows, missing, already = [], [], 0
    seen = set()

    # Any back-fill already recorded, so re-running this is idempotent rather than additive.
    for path in sorted(glob.glob(os.path.join(PROBE_DIR, 'xml_backfill_*.jsonl'))):
        with io.open(path, encoding='utf-8') as fh:
            for line in fh:
                if line.strip():
                    seen.add(json.loads(line).get('xml'))

    for path in sorted(glob.glob(os.path.join(PROBE_DIR, 'probe_runs_*.jsonl'))):
        with io.open(path, encoding='utf-8') as fh:
            for n, line in enumerate(fh, 1):
                if not line.strip():
                    continue
                rec = json.loads(line)
                if rec.get('arm') != 'optimize-probe':
                    continue
                if rec.get('xml_present') is not None:
                    already += 1          # the record speaks for itself; leave it alone
                    continue
                xml = rec.get('xml')
                if not xml:
                    print('REFUSED: %s line %d has no xml path' % (os.path.basename(path), n))
                    return 2
                if xml in seen:
                    already += 1
                    continue
                if not os.path.isfile(xml):
                    # NOT an error and NOT skipped silently. A record whose artefact is absent is
                    # a probe that did not produce one, which is exactly what the strict rule is
                    # for -- it stays unqualified and its cell stays at BASELINE_RUN.
                    missing.append('%s -> %s' % (rec.get('cell_id'), xml))
                    continue
                st = os.stat(xml)
                rows.append({
                    'entity': ENTITY,
                    'cell_id': rec.get('cell_id'),
                    'hypothesis_revision': rec.get('hypothesis_revision'),
                    'xml': xml,
                    'bytes': st.st_size,
                    'mtime_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(st.st_mtime)),
                    'measured_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    'measured_by': 'scripts/pilot_probe_verify_xml.py',
                    'source_record': os.path.basename(path),
                    'why': ('the PilotProbeRun predates the xml_present field, and its '
                            'launcher_exit_code cannot be trusted because mt5_optimize.ps1 exited '
                            '0 on a missing XML until ORDER-1253. This row asserts ONLY that the '
                            'file exists, measured after the fact.'),
                })

    for m in missing:
        print('NO ARTEFACT (cell stays at BASELINE_RUN): %s' % m)
    print('%d record(s) already self-describing or back-filled' % already)
    if not rows:
        print('nothing to back-fill')
        return 1 if missing else 0
    out = os.path.join(PROBE_DIR, 'xml_backfill_%s.jsonl' % time.strftime('%Y%m%d_%H%M%S'))
    for r in rows:
        print('  %-40s %9d bytes  %s' % (r['cell_id'], r['bytes'], r['mtime_utc']))
    if dry:
        print('--dry-run: nothing written')
        return 0
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        for r in rows:
            fh.write(json.dumps(r, sort_keys=True) + '\n')
    print('wrote %d row(s) -> %s' % (len(rows), os.path.relpath(out, ROOT).replace(os.sep, '/')))
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
