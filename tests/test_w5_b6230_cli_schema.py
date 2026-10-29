"""CLI exit semantics and proposed schema package smoke, stdlib only."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

BASE=Path(__file__).resolve().parents[1]
TOOL=BASE/'tools'/'w5_b6230_v4'
FIX=BASE/'tests'

class ToolSmoke(unittest.TestCase):
    def run_gate(self, mode, source, *args):
        return subprocess.run([sys.executable, str(TOOL/'gate.py'),mode,str(source),*args],
                              capture_output=True,text=True,check=False)

    def test_historical_fails_closed_exit_two(self):
        p=self.run_gate('historical',FIX/'w5_b6230_historical_receipt_fixture.json')
        self.assertEqual(p.returncode,2,p.stderr)
        self.assertEqual(json.loads(p.stdout)['historical_verdict'],'POSTCONDITION_FAIL')

    def test_synthetic_only_never_exit_zero(self):
        p=self.run_gate('prospective',FIX/'w5_b6230_SYNTHETIC_DO_NOT_USE_FOR_NATIVE.json')
        self.assertEqual(p.returncode,3,p.stderr)
        v=json.loads(p.stdout)
        self.assertEqual(v['classification'],'OFFLINE_STRUCTURAL_READY_NOT_NATIVE_ACCEPTED')
        self.assertIs(v['native_acceptance'],False)

    def test_bad_input_returns_nonzero(self):
        from tempfile import TemporaryDirectory
        with TemporaryDirectory() as t:
            p=Path(t)/'bad.json';p.write_text('{"kind":"a","kind":"b"}')
            r=self.run_gate('prospective',p)
            self.assertNotEqual(r.returncode,0)

    def test_schema_has_full_stage_identity(self):
        p=TOOL/'schema'/'W5_B6230_STAGE_V4.schema.json'
        v=json.loads(p.read_text(encoding='utf-8'))
        self.assertEqual(v['properties']['version']['const'],'W5_B6230_STAGE_V4')
        self.assertEqual(v['properties']['data_inventory']['minItems'],106)
        self.assertEqual(v['properties']['data_inventory']['maxItems'],106)
        for key in ('capture','source','broker','agent','data_inventory','evidence_sha256'):
            self.assertIn(key,v['required'])
        for key in ('pid','created_utc','exe_sha256','owner_t3_reference','lease_id'):
            self.assertIn(key,v['properties']['capture']['required'])

if __name__=='__main__':unittest.main()
