"""Deterministic positive, physical-artifact negative, and semantic refusal tests.

All temporary writes/removal are confined to a newly created order-owned fixture
inside this package. Existing files are read only. No Git, MT5 or network calls.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT))
import validate as V


def run_tests():
    baseline = V.validate(OUT)
    source = V.Package(OUT)
    saved = {p: source.read(p) for p in source.files()}
    checks = []
    def refused(label, call, expected=None):
        try:
            call()
        except (ValueError, OSError, KeyError, V.configparser.Error) as exc:
            if expected:
                V.require(expected in str(exc), label + ': unexpected refusal: ' + str(exc))
            checks.append(label)
            return
        raise AssertionError('did not REFUSE: ' + label)

    with tempfile.TemporaryDirectory(prefix='.b15-negative-', dir=OUT) as tmp:
        fixture = Path(tmp)
        for rel, raw in saved.items():
            p = fixture / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(raw)
        V.validate(fixture)
        checks.append('relocated package-only copy PASS')
        raw_rel = 'raw/XX00_B15_GBPUSD_H4_MAIN_M1.htm'
        target = fixture / raw_rel
        target.write_bytes(saved[raw_rel][:-2] + b'XX')
        refused('physical raw byte mutation', lambda: V.validate(fixture), 'hash mismatch')
        target.write_bytes(saved[raw_rel])
        target.unlink()
        refused('physical raw deletion', lambda: V.validate(fixture), 'inventory mismatch')
        target.write_bytes(saved[raw_rel])

        def reseal(rel):
            manifest = V.json_bytes(saved[V.MANIFEST])
            for r in manifest['artifacts']:
                if r['path'] == rel:
                    raw = (fixture / rel).read_bytes()
                    r.update(sha256=V.P.sha(raw), size_bytes=len(raw))
            (fixture / V.MANIFEST).write_text(json.dumps(manifest), encoding='utf-8')

        # Refresh the outer hash to ensure path refusal is semantic, not just stale integrity.
        for bad in ('D:/Meta 5c/evidence.htm', '/etc/passwd', '../outside.htm',
                    'raw/../../outside.htm', 'raw\\..\\outside.htm', '//server/share/x'):
            cells = V.json_bytes(saved['cells.json'])
            cells[0]['evidence']['report']['path'] = bad
            (fixture / 'cells.json').write_text(json.dumps(cells), encoding='utf-8')
            reseal('cells.json')
            refused('evidence path ' + bad, lambda: V.validate(fixture), 'path')
        (fixture / 'cells.json').write_bytes(saved['cells.json'])
        (fixture / V.MANIFEST).write_bytes(saved[V.MANIFEST])
        target.write_bytes(saved[raw_rel][:-2] + b'XX')
        reseal(raw_rel)
        refused('raw mutation with refreshed outer manifest', lambda: V.validate(fixture), 'hash mismatch')
        target.write_bytes(saved[raw_rel])
        (fixture / V.MANIFEST).write_bytes(saved[V.MANIFEST])
        (fixture / 'undeclared.txt').write_bytes(b'not inventoried')
        refused('undeclared package artifact', lambda: V.validate(fixture), 'inventory mismatch')
        (fixture / 'undeclared.txt').unlink()

        c = V.json_bytes(saved['cells.json'])[0]
        evidence = c['evidence']
        set_raw, ini_raw, report_raw = [saved[evidence[k]['path']] for k in ('set', 'tester_ini', 'report')]
        # All three input representations are parsed from bytes, including duplicate detection.
        set_text = V.P.decode(set_raw)
        ini_text = V.P.decode(ini_raw)
        report_text = V.P.decode(report_raw)
        key = next(iter(V.P.assignment_map(set_text)))
        assignment = next(s for s in set_text.splitlines() if s.startswith(key + '='))
        reported_assignment = key + '=' + V.P.report_inputs(report_raw)[key]
        for kind in ('duplicate', 'missing', 'value', 'key'):
            replacement = {'duplicate': assignment + '\n' + assignment, 'missing': '',
                           'value': key + '=999999', 'key': 'UnexpectedInput=' + assignment.split('=', 1)[1]}[kind]
            wrong = set_text.replace(assignment, replacement, 1).encode('utf-8')
            refused('set ' + kind, lambda wrong=wrong: V.check_inputs(wrong, ini_raw, report_raw))
            wrong = ini_text.replace(assignment, replacement, 1).encode('utf-8')
            refused('INI ' + kind, lambda wrong=wrong: V.check_inputs(set_raw, wrong, report_raw))
            report_replacement = {'duplicate': reported_assignment + '</b></td></tr><tr><td><b>' + reported_assignment,
                                  'missing': '', 'value': key + '=999999',
                                  'key': 'UnexpectedInput=' + reported_assignment.split('=', 1)[1]}[kind]
            wrong = report_text.replace(reported_assignment, report_replacement, 1).encode('utf-16')
            V.require(wrong != report_raw, 'report mutation must change bytes')
            refused('report ' + kind, lambda wrong=wrong: V.check_inputs(set_raw, ini_raw, wrong))

        refused('duplicate JSON key', lambda: V.json_bytes(b'{"a":1,"a":2}'), 'duplicate JSON key')
        tester = copy.deepcopy(c['tester']); tester['Symbol'] = 'EURUSD'
        refused('tester symbol mismatch', lambda: V.P.check_identity(tester, c['metrics'], 'MAIN'))
        observed = subprocess.run([sys.executable, '-B', str(fixture / 'validate.py'), '--audit'],
                                  cwd=fixture, capture_output=True, text=True)
        V.require(observed.returncode == 0, 'runtime I/O guard failed: ' + observed.stdout + observed.stderr)
        audit = json.loads(observed.stdout)
        V.require(audit['runtime_external_evidence_check'] == 'PASS', 'runtime audit result')
        checks.append('relocated runtime external-evidence/process/network/write denial PASS')
    V.validate(OUT)
    V.require(saved == {p: source.read(p) for p in source.files()}, 'tests altered original package')
    return dict(status='PASS', tests=len(checks), checks=checks, original_package_unchanged=True,
                baseline=baseline)


if __name__ == '__main__':
    print(json.dumps(run_tests(), indent=2, sort_keys=True))
